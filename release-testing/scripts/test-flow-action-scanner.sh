#!/usr/bin/env bash
# =============================================================================
# Scanner self-test: scan-flow-references regression smoke
# =============================================================================
# Phase 5B Layer 3 (flow-reference scanner) — runs the deploy-time flow-reference scanner against
# the current force-app working tree and asserts a clean exit. Catches regressions
# in the Phase 5A scanner shape and CMDT field-name bindings.
#
# The misconfiguration cases (missing flow / inactive flow / variable-contract
# violation) are covered by the 1026 Jest unit tests under
# scripts/__tests__/scan-flow-references.test.js — this shell script proves the
# end-to-end scanner pipeline exits cleanly on the shipped state.
#
# Run with:
#   bash release-testing/scripts/test-flow-action-scanner.sh
#
# Exit codes:
#   0 — scanner clean
#   1 — scanner found violations (regression in shipped state)
#   2 — Jest test suite failed (regression in scanner internals)
# =============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${REPO_ROOT}"

echo "========================================"
echo "Flow-Action Scanner Self-Test"
echo "========================================"

echo ""
echo "1/2 — scan-flow-references against current force-app working tree:"
if ! npm run --silent scan:flow-references; then
    echo "FAIL: scanner reported violations on the shipped state. Either fix the regression"
    echo "      or update the shipped CMDT records to point at deployed flows."
    exit 1
fi
echo "PASS: scanner reports 0 violations on shipped state"

echo ""
echo "2/2 — Jest unit-test suite for scan-flow-references:"
if ! npx jest scripts/__tests__/scan-flow-references.test.js --silent; then
    echo "FAIL: Jest tests failed. Review scripts/__tests__/scan-flow-references.test.js output."
    exit 2
fi
echo "PASS: Jest unit-test suite green"

echo ""
echo "========================================"
echo "Scanner Self-Test: All checks passed (2/2)"
echo "========================================"
