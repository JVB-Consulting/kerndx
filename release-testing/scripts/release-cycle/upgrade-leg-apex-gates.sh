#!/usr/bin/env bash
# Upgrade-leg Apex gates on the upgrade org (RUNBOOK 2.2 + 2.2b): RunLocalTests (with coverage), then
# RunAllTestsInOrg (a pass/fail gate; managed-package coverage is not visible in a subscriber org).
# Runs independently of the fresh leg (a different org, and it writes nothing shared) — but the upgrade
# org's Phase 2 must wait for this to finish.
#
# Both verdicts come from apex-test-verdict.js, which reads ApexTestRunResult and ApexTestResult from the
# org itself: the command-line wrapper's JSON is empty when its wait expires and has reported a failing
# run as clean. This script exits non-zero when either gate fails.
#
# Usage: bash release-testing/scripts/release-cycle/upgrade-leg-apex-gates.sh <tag e.g. rc6>
# Run from the repository root.
#
# Required variables: SF_UPGRADE_ORG_ALIAS, RELEASE_EVIDENCE_DIR
set -u
export SF_SKIP_NEW_VERSION_CHECK=true
: "${SF_UPGRADE_ORG_ALIAS:?SF_UPGRADE_ORG_ALIAS is not set}"
: "${RELEASE_EVIDENCE_DIR:?RELEASE_EVIDENCE_DIR is not set}"
TAG="${1:?tag (e.g. rc6) required}"
REPOSITORY_ROOT="$(pwd)"
mkdir -p "$RELEASE_EVIDENCE_DIR"
EVIDENCE="$(cd "$RELEASE_EVIDENCE_DIR" && pwd)"
ORG="$SF_UPGRADE_ORG_ALIAS"
VERDICT="$REPOSITORY_ROOT/release-testing/runner/apex-test-verdict.js"
LOG="$EVIDENCE/upgrade-apex-tests-$TAG.log"

: > "$LOG"
log() { echo "$*" | tee -a "$LOG"; }
FAILED_GATES=0
log "=== upgrade-leg-apex-gates $TAG start $(date -u +%Y-%m-%dT%H:%M:%SZ)"

log "--- RunLocalTests (subscriber classes, coverage on)"
node "$VERDICT" --org "$ORG" --label "upgrade-runlocaltests-$TAG" --evidence-dir "$EVIDENCE" --test-level RunLocalTests --code-coverage --wait-minutes 90 >> "$LOG" 2>&1
RUNLOCAL_EXIT=$?
log "RunLocalTests verdict exit=$RUNLOCAL_EXIT"
[ "$RUNLOCAL_EXIT" -eq 0 ] || FAILED_GATES=$((FAILED_GATES+1))

log "--- RunAllTestsInOrg (local + managed; pass/fail gate)"
node "$VERDICT" --org "$ORG" --label "upgrade-runalltests-$TAG" --evidence-dir "$EVIDENCE" --test-level RunAllTestsInOrg --wait-minutes 240 >> "$LOG" 2>&1
RUNALL_EXIT=$?
log "RunAllTestsInOrg verdict exit=$RUNALL_EXIT"
[ "$RUNALL_EXIT" -eq 0 ] || FAILED_GATES=$((FAILED_GATES+1))

log "=== upgrade-leg-apex-gates $TAG end $(date -u +%Y-%m-%dT%H:%M:%SZ) failed gates=$FAILED_GATES"
[ "$FAILED_GATES" -eq 0 ]
