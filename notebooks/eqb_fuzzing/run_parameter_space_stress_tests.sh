#!/usr/bin/env bash
set -u
set -o pipefail

# Driver for large-box / high-Re equilibrium discovery stress tests.
#
# Safe defaults:
#   - DRY_RUN=true, so the first run only prints commands and preflight estimates.
#   - MAX_N_GB=4, so cases whose dense N tensor estimate exceeds this are skipped.
#   - Hugebox suites start with symmetry F, the smallest symmetry-restricted model.
#
# Common usage:
#   SUITE=huge_probe DRY_RUN=true  bash notebooks/eqb_fuzzing/run_parameter_space_stress_tests.sh
#   SUITE=huge_probe DRY_RUN=false bash notebooks/eqb_fuzzing/run_parameter_space_stress_tests.sh
#   SUITE=highre     DRY_RUN=false ONLY_CASE=highre_10x6_re1000 bash notebooks/eqb_fuzzing/run_parameter_space_stress_tests.sh
#   bash notebooks/eqb_fuzzing/run_parameter_space_stress_tests.sh help
#
# Override examples:
#   MAX_N_GB=10 ALLOW_LARGE_N=true SUITE=huge_expand DRY_RUN=false bash notebooks/eqb_fuzzing/run_parameter_space_stress_tests.sh
#   SYMMETRIES=E,F ATTEMPTS=10000 SUITE=huge_probe DRY_RUN=false bash notebooks/eqb_fuzzing/run_parameter_space_stress_tests.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

SUITE="${SUITE:-huge_probe}"
if [[ "$#" -gt 0 ]]; then
  SUITE="$1"
fi
DRY_RUN="${DRY_RUN:-true}"
ONLY_CASE="${ONLY_CASE:-}"
START_AT_CASE="${START_AT_CASE:-}"
JULIA_NUM_THREADS="${JULIA_NUM_THREADS:-8}"
MAX_N_GB="${MAX_N_GB:-4}"
ALLOW_LARGE_N="${ALLOW_LARGE_N:-false}"
CONTINUE_ON_ERROR="${CONTINUE_ON_ERROR:-true}"
RUN_ROOT="${RUN_ROOT:-${SCRIPT_DIR}/stress_tests/${SUITE}}"

ATTEMPTS="${ATTEMPTS:-}"
SYMMETRIES="${SYMMETRIES:-}"
EQB_RESUME="${EQB_RESUME:-false}"
EQB_APPEND_ATTEMPTS="${EQB_APPEND_ATTEMPTS:-0}"
EQB_LADDER_PERTURB_TRIALS_EARLY="${EQB_LADDER_PERTURB_TRIALS_EARLY:-2000}"
EQB_LADDER_PERTURB_TRIALS_LATE="${EQB_LADDER_PERTURB_TRIALS_LATE:-200}"
EQB_LADDER_PERTURB_SWITCH_JKL="${EQB_LADDER_PERTURB_SWITCH_JKL:-2x4x5}"
EQB_LADDER_PERTURB_SCALE="${EQB_LADDER_PERTURB_SCALE:-0.05}"

SUMMARY_CSV="${RUN_ROOT}/stress_test_queue_summary.csv"
start_reached="true"
if [[ -n "${START_AT_CASE}" ]]; then
  start_reached="false"
fi

timestamp() {
  date "+%Y-%m-%dT%H:%M:%S"
}

usage() {
  cat <<'EOF'
Available suites:
  huge_probe       Lz=120, Re=400, K=10/20/40/60, symmetry F by default
  huge_expand      Lz=120, Re=400, K=20/40/60, symmetries E,F by default
  largebox_scaling Lz=12/24/48/120 with K~=Lz/2, symmetry F by default
  highre           Known boxes at Re=500/700/1000/1500/2000, all groups by default
  shear_bands      Representative high-Re and hugebox shear-band coverage
  controls         Small controls on known boxes
  minimal_low_shear GHC/HKW minimal cells at Re=400, JKL=1x3x5, all groups, shear [1,3]

Important env vars:
  DRY_RUN=false        actually execute jobs; default true
  ONLY_CASE=name       run one case
  START_AT_CASE=name   skip cases until name
  MAX_N_GB=4           skip if estimated dense N tensor is above this GB
  ALLOW_LARGE_N=true   run even if the preflight exceeds MAX_N_GB
  SYMMETRIES=E,F       override suite default symmetries
  ATTEMPTS=10000       override suite default attempts
  RUN_ROOT=path        override output directory
EOF
}

preflight_case() {
  local label="$1"
  local ladder="$2"
  local symmetries="$3"

  julia --startup-file=no --project="${ROOT_DIR}" -e '
      using CloudAtlas
      using Printf

      function main()
          ladder = ARGS[1]
          sym_raw = ARGS[2]
          max_gb = parse(Float64, ARGS[3])

          sx, sy, sz, tx, tz = CloudAtlas.halfbox_symmetries()
          groups = Dict(
              "A" => [sx * sy * sz, tx * tz],
              "B" => [sx * sy, sz],
              "C" => [sx * sy * tz, sz],
              "D" => [sx * sy, sz * tx],
              "E" => [sx * sy * sz, sz * tx * tz],
              "F" => [sx * sy, sz, tx * tz],
              "G" => [sx * sy * sz],
          )

          max_seen = 0.0
          for token in split(ladder, ",")
              isempty(strip(token)) && continue
              parts = split(lowercase(strip(token)), "x")
              length(parts) == 3 || error("Bad JKL token: $token")
              J, K, L = parse.(Int, parts)
              for name in split(sym_raw, ",")
                  name = strip(name)
                  isempty(name) && continue
                  haskey(groups, name) || error("Unknown symmetry group: $name")
                  m = size(CloudAtlas.basisIndices(J, K, L, groups[name]), 1)
                  dense_gb = 8.0 * m^3 / 1e9
                  max_seen = max(max_seen, dense_gb)
                  @printf("    %s JKL=%dx%dx%d m=%d dense_N_est=%.3f GB\n", name, J, K, L, m, dense_gb)
              end
          end
          if max_seen > max_gb
              @printf("    preflight: exceeds MAX_N_GB=%.3f (max %.3f GB)\n", max_gb, max_seen)
              exit(3)
          end
      end
      main()
  ' -- "${ladder}" "${symmetries}" "${MAX_N_GB}"
}

run_case() {
  local label="$1"
  local re="$2"
  local lx="$3"
  local lz="$4"
  local ladder="$5"
  local default_symmetries="$6"
  local default_attempts="$7"
  local shear_min="$8"
  local shear_max="$9"

  local symmetries="${SYMMETRIES:-${default_symmetries}}"
  local attempts="${ATTEMPTS:-${default_attempts}}"

  if [[ -n "${ONLY_CASE}" && "${label}" != "${ONLY_CASE}" ]]; then
    echo "[skip] ${label} (ONLY_CASE=${ONLY_CASE})"
    return 0
  fi
  if [[ "${start_reached}" != "true" ]]; then
    if [[ "${label}" == "${START_AT_CASE}" ]]; then
      start_reached="true"
    else
      echo "[skip] ${label} (waiting for START_AT_CASE=${START_AT_CASE})"
      return 0
    fi
  fi

  local out_dir="${RUN_ROOT}/${label}"
  local log_path="${out_dir}/run.log"

  echo ""
  echo "== ${label} =="
  echo "Re=${re} Lx=${lx} Lz=${lz} ladder=${ladder} symmetries=${symmetries} attempts=${attempts} shear=[${shear_min},${shear_max}]"
  echo "out_dir=${out_dir}"
  echo "preflight:"

  preflight_case "${label}" "${ladder}" "${symmetries}"
  local preflight_status="$?"
  if [[ "${preflight_status}" -ne 0 ]]; then
    if [[ "${ALLOW_LARGE_N}" == "true" ]]; then
      echo "[warn] preflight failed/exceeded limit, but ALLOW_LARGE_N=true, continuing"
    else
      echo "[skip] ${label} due to preflight status ${preflight_status}; set ALLOW_LARGE_N=true to override"
      printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n" \
        "$(timestamp)" "${SUITE}" "${label}" "${re}" "${lx}" "${lz}" "${ladder}" "${symmetries}" "${attempts}" "${shear_min}" "${shear_max}" "skipped_preflight_${preflight_status}" >> "${SUMMARY_CSV}"
      return 0
    fi
  fi

  local cmd=(
    env
    "EQB_RE=${re}"
    "EQB_LX=${lx}"
    "EQB_LZ=${lz}"
    "EQB_OUT_DIR=${out_dir}"
    "EQB_RESUME=${EQB_RESUME}"
    "EQB_ATTEMPTS=${attempts}"
    "EQB_APPEND_ATTEMPTS=${EQB_APPEND_ATTEMPTS}"
    "EQB_SYMMETRIES=${symmetries}"
    "EQB_LADDER=${ladder}"
    "EQB_SHEAR_MIN=${shear_min}"
    "EQB_SHEAR_MAX=${shear_max}"
    "EQB_LADDER_PERTURB_TRIALS_EARLY=${EQB_LADDER_PERTURB_TRIALS_EARLY}"
    "EQB_LADDER_PERTURB_TRIALS_LATE=${EQB_LADDER_PERTURB_TRIALS_LATE}"
    "EQB_LADDER_PERTURB_SWITCH_JKL=${EQB_LADDER_PERTURB_SWITCH_JKL}"
    "EQB_LADDER_PERTURB_SCALE=${EQB_LADDER_PERTURB_SCALE}"
    "CLOUDATLAS_SKIP_ACTIVATE=true"
    "JULIA_PKG_PRECOMPILE_AUTO=0"
    "JULIA_NUM_THREADS=${JULIA_NUM_THREADS}"
    julia --startup-file=no --project="${ROOT_DIR}" "${SCRIPT_DIR}/eqb_discovery.jl"
  )

  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "[dry-run] command:"
    printf "  %q" "${cmd[@]}"
    echo ""
    printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n" \
      "$(timestamp)" "${SUITE}" "${label}" "${re}" "${lx}" "${lz}" "${ladder}" "${symmetries}" "${attempts}" "${shear_min}" "${shear_max}" "dry_run" >> "${SUMMARY_CSV}"
    return 0
  fi

  mkdir -p "${out_dir}"
  (
    cd "${ROOT_DIR}" || exit 1
    "${cmd[@]}"
  ) 2>&1 | tee "${log_path}"

  local exit_code="${PIPESTATUS[0]}"
  local status="ok"
  if [[ "${exit_code}" -ne 0 ]]; then
    status="failed_${exit_code}"
  fi

  printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n" \
    "$(timestamp)" "${SUITE}" "${label}" "${re}" "${lx}" "${lz}" "${ladder}" "${symmetries}" "${attempts}" "${shear_min}" "${shear_max}" "${status}" >> "${SUMMARY_CSV}"

  if [[ "${exit_code}" -ne 0 && "${CONTINUE_ON_ERROR}" != "true" ]]; then
    echo "[stop] ${label} failed and CONTINUE_ON_ERROR=false"
    exit "${exit_code}"
  fi
}

case "${SUITE}" in
  help|--help|-h)
    usage
    exit 0
    ;;
esac

mkdir -p "${RUN_ROOT}"
if [[ ! -f "${SUMMARY_CSV}" ]]; then
  printf "timestamp,suite,case_label,Re,Lx,Lz,ladder,symmetries,attempts,shear_min,shear_max,status\n" > "${SUMMARY_CSV}"
fi

echo "stress-test driver"
echo "  SUITE=${SUITE}"
echo "  DRY_RUN=${DRY_RUN}"
echo "  RUN_ROOT=${RUN_ROOT}"
echo "  MAX_N_GB=${MAX_N_GB}"
echo "  ALLOW_LARGE_N=${ALLOW_LARGE_N}"
echo "  JULIA_NUM_THREADS=${JULIA_NUM_THREADS}"

case "${SUITE}" in
  controls)
    run_case "ctrl_re400_lx10_lz6" "400" "10.0" "6.0" "1x3x5" "A,B,C,D,E,F,G" "5000" "3.0" "7.0"
    run_case "ctrl_re400_lx2pi_lzpi" "400" "6.283185307179586" "3.141592653589793" "1x3x5" "A,B,C,D,E,F,G" "5000" "3.0" "7.0"
    ;;
  minimal_low_shear)
    run_case "ghc_re400_alpha1p14_gamma2p5_low_shear" "400" "5.511566576198634" "2.5132741228718345" "1x3x5" "A,B,C,D,E,F,G" "100000" "1.0" "3.0"
    run_case "hkw_re400_alpha1p14_gamma1p67_low_shear" "400" "5.511566576198634" "3.762386411812926" "1x3x5" "A,B,C,D,E,F,G" "100000" "1.0" "3.0"
    ;;
  huge_probe)
    run_case "huge_re400_lx10_lz120_k10_F" "400" "10.0" "120.0" "1x10x5" "F" "5000" "3.0" "7.0"
    run_case "huge_re400_lx10_lz120_k20_F" "400" "10.0" "120.0" "1x20x5" "F" "5000" "3.0" "7.0"
    run_case "huge_re400_lx10_lz120_k40_F" "400" "10.0" "120.0" "1x40x5" "F" "5000" "3.0" "7.0"
    run_case "huge_re400_lx10_lz120_k60_F" "400" "10.0" "120.0" "1x60x5" "F" "5000" "3.0" "7.0"
    ;;
  huge_expand)
    run_case "huge_re400_lx10_lz120_k20_EF" "400" "10.0" "120.0" "1x20x5" "E,F" "5000" "3.0" "7.0"
    run_case "huge_re400_lx10_lz120_k40_EF" "400" "10.0" "120.0" "1x40x5" "E,F" "5000" "3.0" "7.0"
    run_case "huge_re400_lx10_lz120_k60_EF" "400" "10.0" "120.0" "1x60x5" "E,F" "5000" "3.0" "7.0"
    ;;
  largebox_scaling)
    run_case "lz12_k6_re400_F" "400" "10.0" "12.0" "1x6x5" "F" "10000" "3.0" "7.0"
    run_case "lz24_k12_re400_F" "400" "10.0" "24.0" "1x12x5" "F" "10000" "3.0" "7.0"
    run_case "lz48_k24_re400_F" "400" "10.0" "48.0" "1x24x5" "F" "10000" "3.0" "7.0"
    run_case "lz120_k60_re400_F" "400" "10.0" "120.0" "1x60x5" "F" "10000" "3.0" "7.0"
    ;;
  highre)
    for re in 500 700 1000 1500 2000; do
      run_case "highre_10x6_re${re}" "${re}" "10.0" "6.0" "1x3x5" "A,B,C,D,E,F,G" "25000" "3.0" "7.0"
      run_case "highre_2pi_pi_re${re}" "${re}" "6.283185307179586" "3.141592653589793" "1x3x5" "A,B,C,D,E,F,G" "25000" "3.0" "7.0"
    done
    ;;
  shear_bands)
    for band in "low:0.05:1.0" "medium:1.0:3.0" "current:3.0:7.0" "very_high:7.0:15.0"; do
      IFS=":" read -r band_name shear_min shear_max <<< "${band}"
      run_case "shear_${band_name}_re1000_lx10_lz6_F" "1000" "10.0" "6.0" "1x3x5" "F" "10000" "${shear_min}" "${shear_max}"
      run_case "shear_${band_name}_re400_lx10_lz120_k60_F" "400" "10.0" "120.0" "1x60x5" "F" "10000" "${shear_min}" "${shear_max}"
    done
    ;;
  help|--help|-h)
    usage
    ;;
  *)
    echo "Unknown SUITE=${SUITE}"
    usage
    exit 2
    ;;
esac

echo ""
echo "Queue summary: ${SUMMARY_CSV}"
