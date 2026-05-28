#!/usr/bin/env bash
set -u
set -o pipefail

# Focused Re=400 GHC-box fuzzing for exact GHC/Sharma literature symmetry
# groups. This is a thin preset wrapper around run_ghc_re400_fuzz_pipeline.sh.
#
# Exact groups searched by default:
#   SigmaGHC = GHC S / Sharma Sigma, <sztx, sxy*txz>
#   ThetaGHC = GHC S x {e,tau_xz} / Sharma Theta, <sxy, sztx, txz>
#   Theta6   = Sharma Theta6, <sxyz*tz>
#   B        = Sharma K, <sxy, sz>
#   G        = GHC {e,sigma_xz}, <sxyz>
#
# Start with:
#   DRY_RUN=true bash notebooks/eqb_fuzzing/run_ghc_re400_literature_symmetry_fuzz.sh
#
# Run on a server:
#   DRY_RUN=false JULIA_NUM_THREADS=16 DNS_PARALLEL=2 \
#     bash notebooks/eqb_fuzzing/run_ghc_re400_literature_symmetry_fuzz.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CASE_LABEL="${CASE_LABEL:-ghc_re400_literature_exact_symmetry_fuzz}"
RUN_ROOT="${RUN_ROOT:-${SCRIPT_DIR}/literature_target_runs/ghc_re400_exact_symmetry}"

SYMMETRIES="${SYMMETRIES:-SigmaGHC,ThetaGHC,Theta6,B,G}"

# Keep this off by default for exact-literature searches. The ODE and DNS scalar
# norms are not reliable enough to skip DNS promotion before field comparison.
SKIP_CATALOG_KNOWN="${SKIP_CATALOG_KNOWN:-false}"

export CASE_LABEL
export RUN_ROOT
export SYMMETRIES
export SKIP_CATALOG_KNOWN

exec "${SCRIPT_DIR}/run_ghc_re400_fuzz_pipeline.sh" "$@"
