#!/usr/bin/env bash
set -u
set -o pipefail

# Sequential overnight runner for eqb_discovery.jl
# Cases:
#   (Lx, Lz) = (10, 6), (2pi, pi)
#   Re = 400, 300
#
# Outputs:
#   notebooks/eqb_fuzzing/overnight_runs/<case>/run.log
#   notebooks/eqb_fuzzing/overnight_runs/run_queue_summary.csv
#
# Optional env overrides:
#   JULIA_NUM_THREADS=...
#   EQB_ATTEMPTS=...
#   EQB_LADDER_PERTURB_TRIALS_EARLY=...
#   EQB_LADDER_PERTURB_TRIALS_LATE=...
#   EQB_LADDER_PERTURB_SWITCH_JKL=...
#   EQB_LADDER_PERTURB_SCALE=...
#   CONTINUE_ON_ERROR=true|false   (default true)
#   START_AT_CASE=<case_label>     (resume queue from this case label)
#   ONLY_CASE=<case_label>         (run one case only)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
RUN_ROOT="${SCRIPT_DIR}/overnight_runs_updated"
SUMMARY_CSV="${RUN_ROOT}/run_queue_summary.csv"

JULIA_NUM_THREADS="${JULIA_NUM_THREADS:-8}"
CONTINUE_ON_ERROR="${CONTINUE_ON_ERROR:-true}"
START_AT_CASE="${START_AT_CASE:-}"
ONLY_CASE="${ONLY_CASE:-}"

EQB_ATTEMPTS="${EQB_ATTEMPTS:-100000}"
EQB_LADDER_PERTURB_TRIALS_EARLY="${EQB_LADDER_PERTURB_TRIALS_EARLY:-10000}"
EQB_LADDER_PERTURB_TRIALS_LATE="${EQB_LADDER_PERTURB_TRIALS_LATE:-500}"
EQB_LADDER_PERTURB_SWITCH_JKL="${EQB_LADDER_PERTURB_SWITCH_JKL:-2x4x5}"
EQB_LADDER_PERTURB_SCALE="${EQB_LADDER_PERTURB_SCALE:-0.05}"

mkdir -p "${RUN_ROOT}"

if [[ ! -f "${SUMMARY_CSV}" ]]; then
  printf "timestamp,case_label,Re,Lx,Lz,status,log_path,out_dir\n" > "${SUMMARY_CSV}"
fi

start_reached="true"
if [[ -n "${START_AT_CASE}" ]]; then
  start_reached="false"
fi

timestamp() {
  date "+%Y-%m-%dT%H:%M:%S"
}

run_case() {
  local case_label="$1"
  local re="$2"
  local lx="$3"
  local lz="$4"

  if [[ -n "${ONLY_CASE}" && "${case_label}" != "${ONLY_CASE}" ]]; then
    echo "[skip] ${case_label} (ONLY_CASE=${ONLY_CASE})"
    return 0
  fi
  if [[ "${start_reached}" != "true" ]]; then
    if [[ "${case_label}" == "${START_AT_CASE}" ]]; then
      start_reached="true"
    else
      echo "[skip] ${case_label} (waiting for START_AT_CASE=${START_AT_CASE})"
      return 0
    fi
  fi

  local out_dir="${RUN_ROOT}/${case_label}"
  local log_path="${out_dir}/run.log"

  mkdir -p "${out_dir}"

  echo ""
  echo "== Running ${case_label} =="
  echo "Re=${re}, Lx=${lx}, Lz=${lz}"
  echo "out_dir=${out_dir}"
  echo "log=${log_path}"

  (
    cd "${SCRIPT_DIR}" || exit 1
    EQB_RE="${re}" \
    EQB_LX="${lx}" \
    EQB_LZ="${lz}" \
    EQB_OUT_DIR="${out_dir}" \
    EQB_RESUME="${EQB_RESUME:-true}" \
    EQB_ATTEMPTS="${EQB_ATTEMPTS}" \
    EQB_LADDER_PERTURB_TRIALS_EARLY="${EQB_LADDER_PERTURB_TRIALS_EARLY}" \
    EQB_LADDER_PERTURB_TRIALS_LATE="${EQB_LADDER_PERTURB_TRIALS_LATE}" \
    EQB_LADDER_PERTURB_SWITCH_JKL="${EQB_LADDER_PERTURB_SWITCH_JKL}" \
    EQB_LADDER_PERTURB_SCALE="${EQB_LADDER_PERTURB_SCALE}" \
    JULIA_NUM_THREADS="${JULIA_NUM_THREADS}" \
    julia --project=../../. eqb_discovery.jl
  ) 2>&1 | tee "${log_path}"

  local exit_code="${PIPESTATUS[0]}"
  local status="ok"
  if [[ "${exit_code}" -ne 0 ]]; then
    status="failed(${exit_code})"
  fi

  printf "%s,%s,%s,%s,%s,%s,%s,%s\n" \
    "$(timestamp)" "${case_label}" "${re}" "${lx}" "${lz}" "${status}" "${log_path}" "${out_dir}" >> "${SUMMARY_CSV}"

  if [[ "${exit_code}" -ne 0 && "${CONTINUE_ON_ERROR}" != "true" ]]; then
    echo "[stop] ${case_label} failed and CONTINUE_ON_ERROR=false"
    exit "${exit_code}"
  fi
}

# Requested sequence:
# Re = 400, then 300; each with (10,6) and (2pi,pi)
run_case "re400_lx10_lz6" "400" "10.0" "6.0"
run_case "re400_lx2pi_lzpi" "400" "6.283185307179586" "3.141592653589793"
run_case "re300_lx10_lz6" "300" "10.0" "6.0"
run_case "re300_lx2pi_lzpi" "300" "6.283185307179586" "3.141592653589793"

echo ""
echo "All queued runs completed. Summary: ${SUMMARY_CSV}"
