#!/usr/bin/env bash
set -u
set -o pipefail

# Server-oriented pipeline for direct literature-box equilibrium searches.
#
# Target:
#   Re = 400
#   Lx = 5.511566576198634
#   Lz = 2.5132741228718345
#
# Stages:
#   1. ODE fuzzing at the lowest JKL level.
#   2. ODE promotion up the configured JKL ladder.
#   3. DNS promotion with optional skip of candidates already present in catalog.
#   4. DNS-level dedup/summarization.
#
# Start with:
#   DRY_RUN=true bash notebooks/eqb_fuzzing/run_ghc_re400_fuzz_pipeline.sh
#
# Run on a server:
#   DRY_RUN=false JULIA_NUM_THREADS=16 DNS_PARALLEL=2 \
#     bash notebooks/eqb_fuzzing/run_ghc_re400_fuzz_pipeline.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

CASE_LABEL="${CASE_LABEL:-ghc_re400_literature_fuzz}"
RUN_ROOT="${RUN_ROOT:-${SCRIPT_DIR}/literature_target_runs/ghc_re400}"
CASE_DIR="${RUN_ROOT}/${CASE_LABEL}"
QUEUE_CSV="${RUN_ROOT}/run_queue_summary.csv"

RE="${RE:-400}"
LX="${LX:-5.511566576198634}"
LZ="${LZ:-2.5132741228718345}"

DRY_RUN="${DRY_RUN:-true}"
PHASES="${PHASES:-discover,promote,summarize}"
JULIA_NUM_THREADS="${JULIA_NUM_THREADS:-8}"

ATTEMPTS="${ATTEMPTS:-100000}"
SYMMETRIES="${SYMMETRIES:-A,B,C,D,E,F,G}"
LADDER="${LADDER:-1x3x5,1x4x5,2x4x5,2x4x6,2x4x7,2x4x8,2x4x9,3x4x9,3x5x9,3x5x10,3x5x11}"
SHEAR_MIN="${SHEAR_MIN:-0.05}"
SHEAR_MAX="${SHEAR_MAX:-3.2}"
EQB_RESUME="${EQB_RESUME:-true}"
EQB_APPEND_ATTEMPTS="${EQB_APPEND_ATTEMPTS:-0}"
EQB_LADDER_PERTURB_TRIALS_EARLY="${EQB_LADDER_PERTURB_TRIALS_EARLY:-5000}"
EQB_LADDER_PERTURB_TRIALS_LATE="${EQB_LADDER_PERTURB_TRIALS_LATE:-500}"
EQB_LADDER_PERTURB_SWITCH_JKL="${EQB_LADDER_PERTURB_SWITCH_JKL:-2x4x5}"
EQB_LADDER_PERTURB_SCALE="${EQB_LADDER_PERTURB_SCALE:-0.05}"

DNS_PARALLEL="${DNS_PARALLEL:-1}"
DNS_T="${DNS_T:-10.0}"
DNS_RESUME="${DNS_RESUME:-true}"
DNS_STOP_ON_FIRST="${DNS_STOP_ON_FIRST:-true}"
SKIP_CATALOG_KNOWN="${SKIP_CATALOG_KNOWN:-true}"
CATALOG_MANIFEST="${CATALOG_MANIFEST:-${ROOT_DIR}/catalog/catalog_manifest.csv}"
CATALOG_L2_TOL="${CATALOG_L2_TOL:-0.002}"
CATALOG_SHEAR_TOL="${CATALOG_SHEAR_TOL:-0.005}"
REFERENCE_FIELD="${REFERENCE_FIELD:-${SCRIPT_DIR}/../tw_discovery/TW1-2pi1piRe200-40x49x40.nc}"

timestamp() {
  date "+%Y-%m-%dT%H:%M:%S"
}

usage() {
  cat <<'EOF'
GHC Re=400 literature-box equilibrium fuzzing pipeline.

Common env vars:
  DRY_RUN=false              actually run commands; default true
  PHASES=discover,promote,summarize
  RUN_ROOT=path              output root
  ATTEMPTS=100000            low-JKL fuzz attempts per symmetry group
  SYMMETRIES=A,B,C,D,E,F,G   groups to search
  LADDER=1x3x5,...           ODE promotion ladder
  JULIA_NUM_THREADS=16       Julia threads for ODE work
  DNS_PARALLEL=2             concurrent DNS findsoln trajectories
  SKIP_CATALOG_KNOWN=true    skip DNS promotion for scalar matches in catalog
  CATALOG_L2_TOL=0.002
  CATALOG_SHEAR_TOL=0.005
  REFERENCE_FIELD=path       base NetCDF used by coeff2field

Examples:
  DRY_RUN=true bash notebooks/eqb_fuzzing/run_ghc_re400_fuzz_pipeline.sh
  DRY_RUN=false PHASES=discover SYMMETRIES=E ATTEMPTS=200000 bash notebooks/eqb_fuzzing/run_ghc_re400_fuzz_pipeline.sh
  DRY_RUN=false PHASES=promote,summarize DNS_PARALLEL=2 bash notebooks/eqb_fuzzing/run_ghc_re400_fuzz_pipeline.sh
EOF
}

has_phase() {
  local phase="$1"
  [[ ",${PHASES}," == *",${phase},"* ]]
}

run_or_print() {
  local log_path="$1"
  shift
  if [[ "${DRY_RUN}" == "true" ]]; then
    printf "[dry-run]"
    printf " %q" "$@"
    echo ""
    return 0
  fi
  mkdir -p "$(dirname "${log_path}")"
  (
    cd "${ROOT_DIR}" || exit 1
    "$@"
  ) 2>&1 | tee "${log_path}"
  return "${PIPESTATUS[0]}"
}

write_queue() {
  mkdir -p "${RUN_ROOT}"
  printf "case_label,Re,Lx,Lz,out_dir\n" > "${QUEUE_CSV}"
  printf "%s,%s,%s,%s,%s\n" "${CASE_LABEL}" "${RE}" "${LX}" "${LZ}" "${CASE_DIR}" >> "${QUEUE_CSV}"
}

if [[ "${1:-}" == "help" || "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

mkdir -p "${RUN_ROOT}"
write_queue

echo "GHC Re=400 literature fuzz pipeline"
echo "  generated=$(timestamp)"
echo "  root=${ROOT_DIR}"
echo "  run_root=${RUN_ROOT}"
echo "  case=${CASE_LABEL}"
echo "  Re=${RE} Lx=${LX} Lz=${LZ}"
echo "  phases=${PHASES} dry_run=${DRY_RUN}"
echo "  symmetries=${SYMMETRIES}"
echo "  attempts=${ATTEMPTS}"
echo "  ladder=${LADDER}"
echo "  shear_band=[${SHEAR_MIN},${SHEAR_MAX}]"
echo "  skip_catalog_known=${SKIP_CATALOG_KNOWN}"

if has_phase "discover"; then
  discover_cmd=(
    env
    "EQB_RE=${RE}"
    "EQB_LX=${LX}"
    "EQB_LZ=${LZ}"
    "EQB_OUT_DIR=${CASE_DIR}"
    "EQB_RESUME=${EQB_RESUME}"
    "EQB_ATTEMPTS=${ATTEMPTS}"
    "EQB_APPEND_ATTEMPTS=${EQB_APPEND_ATTEMPTS}"
    "EQB_SYMMETRIES=${SYMMETRIES}"
    "EQB_LADDER=${LADDER}"
    "EQB_SHEAR_MIN=${SHEAR_MIN}"
    "EQB_SHEAR_MAX=${SHEAR_MAX}"
    "EQB_LADDER_PERTURB_TRIALS_EARLY=${EQB_LADDER_PERTURB_TRIALS_EARLY}"
    "EQB_LADDER_PERTURB_TRIALS_LATE=${EQB_LADDER_PERTURB_TRIALS_LATE}"
    "EQB_LADDER_PERTURB_SWITCH_JKL=${EQB_LADDER_PERTURB_SWITCH_JKL}"
    "EQB_LADDER_PERTURB_SCALE=${EQB_LADDER_PERTURB_SCALE}"
    "CLOUDATLAS_SKIP_ACTIVATE=true"
    "JULIA_PKG_PRECOMPILE_AUTO=0"
    "JULIA_NUM_THREADS=${JULIA_NUM_THREADS}"
    julia --startup-file=no --project="${ROOT_DIR}" "${SCRIPT_DIR}/eqb_discovery.jl"
  )
  run_or_print "${CASE_DIR}/discovery.log" "${discover_cmd[@]}" || exit "$?"
fi

if has_phase "promote"; then
  promote_cmd=(
    env
    "CLOUDATLAS_SKIP_ACTIVATE=true"
    "JULIA_PKG_PRECOMPILE_AUTO=0"
    "JULIA_NUM_THREADS=${JULIA_NUM_THREADS}"
    julia --startup-file=no --project="${ROOT_DIR}" "${SCRIPT_DIR}/promote_eqb_discovery_to_findsoln.jl"
    --runs-root "${RUN_ROOT}"
    --cases "${CASE_LABEL}"
    --groups "${SYMMETRIES}"
    --parallel "${DNS_PARALLEL}"
    --T "${DNS_T}"
    --resume "${DNS_RESUME}"
    --stop-on-first "${DNS_STOP_ON_FIRST}"
    --skip-catalog-known "${SKIP_CATALOG_KNOWN}"
    --catalog-manifest "${CATALOG_MANIFEST}"
    --catalog-l2-tol "${CATALOG_L2_TOL}"
    --catalog-shear-tol "${CATALOG_SHEAR_TOL}"
    --reference "${REFERENCE_FIELD}"
  )
  run_or_print "${RUN_ROOT}/promote_findsoln.log" "${promote_cmd[@]}" || exit "$?"
fi

if has_phase "summarize"; then
  summarize_cmd=(
    env
    "CLOUDATLAS_SKIP_ACTIVATE=true"
    "JULIA_PKG_PRECOMPILE_AUTO=0"
    julia --startup-file=no --project="${ROOT_DIR}" "${SCRIPT_DIR}/unique_converged_dns_vs_ode.jl"
    --runs-root "${RUN_ROOT}"
    --cases "${CASE_LABEL}"
    --out-dir "${RUN_ROOT}/analysis/findsoln_unique"
  )
  run_or_print "${RUN_ROOT}/summarize_unique.log" "${summarize_cmd[@]}" || exit "$?"
fi

echo ""
echo "Outputs:"
echo "  discovery: ${CASE_DIR}"
echo "  queue: ${QUEUE_CSV}"
echo "  DNS summary: ${RUN_ROOT}/findsoln_jobs_summary.csv"
echo "  known skips: ${RUN_ROOT}/findsoln_catalog_known_skips.csv"
echo "  unique DNS: ${RUN_ROOT}/analysis/findsoln_unique"
