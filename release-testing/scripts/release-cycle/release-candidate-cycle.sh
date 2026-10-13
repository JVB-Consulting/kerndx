#!/usr/bin/env bash
# The full two-leg release-test cycle for one candidate, unattended, in the runbook's mandated order:
#   1. candidate install into both orgs (install-candidate.sh)
#   2. RUNBOOK 1.4-1.6 on both orgs (deploy-subscriber-artifacts.sh) — sequential, they share the staging project
#   3. fresh current-run.json header for the candidate (previous file backed up)
#   4. upgrade-leg Apex gates start in the background (upgrade-leg-apex-gates.sh) — different org, no shared files
#   5. fresh Phase 2 → snapshot            (never two Phase 2s at once: shared ~/.kern-cmdt-staging)
#   6. fresh Phase 3, ALL parts → snapshot (never a Playwright run over a Phase 2: both write current-run.json)
#   6b. full-org gate on the fresh org (RunAllTestsInOrg, org-verified), plus the optional targeted classes
#   7. wait for step 4 → drain the async queue → upgrade Phase 2 → snapshot
#   8. upgrade e2e: part1 --no-deps, part7+part8 (V32 needs part7 chains), part10 → snapshot
# Test failures do NOT abort (they are recorded for the maintainer) and the cycle exits non-zero at the end
# when any gate failed; infrastructure failures (install/deploy) abort immediately.
#
# Every Apex test verdict comes from apex-test-verdict.js reading the org's own ApexTestRunResult and
# ApexTestResult rows: it waits out any run already in flight on the org, resolves the run its own launch
# started, and never reads "the newest run".
#
# Usage: bash release-testing/scripts/release-cycle/release-candidate-cycle.sh <candidate 04t> <version e.g. 1.8.0-1> <tag e.g. rc6>
# Run from the repository root.
#
# Required variables: SF_SUBSCRIBER_ORG_ALIAS, SF_UPGRADE_ORG_ALIAS, RELEASE_EVIDENCE_DIR
# Optional variables: SKIP_INSTALL=1 (candidate already verified installed in both orgs),
#                     RELEASE_RUN_SCOPE (the scope sentence written into the results header),
#                     RELEASE_API_VERSION (default 68.0),
#                     RELEASE_TARGETED_TEST_CLASSES (comma-separated classes for the artifact-specific gate)
set -u
export SF_SKIP_NEW_VERSION_CHECK=true
: "${SF_SUBSCRIBER_ORG_ALIAS:?SF_SUBSCRIBER_ORG_ALIAS is not set}"
: "${SF_UPGRADE_ORG_ALIAS:?SF_UPGRADE_ORG_ALIAS is not set}"
: "${RELEASE_EVIDENCE_DIR:?RELEASE_EVIDENCE_DIR is not set}"
CANDIDATE="${1:?candidate 04t required}"
VERSION="${2:?version (e.g. 1.8.0-1) required}"
TAG="${3:?tag (e.g. rc6) required}"
REPOSITORY_ROOT="$(pwd)"
mkdir -p "$RELEASE_EVIDENCE_DIR"
EVIDENCE="$(cd "$RELEASE_EVIDENCE_DIR" && pwd)"
SCRIPTS="$(dirname "$0")"
RESULTS="$REPOSITORY_ROOT/release-testing/results/current-run.json"
PLAYWRIGHT_CONFIGURATION_FILE="release-testing/e2e/playwright.config.js"
VERDICT="$REPOSITORY_ROOT/release-testing/runner/apex-test-verdict.js"
API_VERSION="${RELEASE_API_VERSION:-68.0}"
RUN_SCOPE="${RELEASE_RUN_SCOPE:-Full two-leg cycle: fresh leg (direct install of the candidate) and upgrade leg (released base, then the candidate).}"
LOG="$EVIDENCE/rc-cycle-$TAG.log"

FAILED_GATES=0
log() { echo "$(date +%H:%M:%S) $*" | tee -a "$LOG"; }
snapshot() { cp "$RESULTS" "$EVIDENCE/$1" && log "snapshot -> $1"; }
phase2_summary() {
  local SUMMARY
  SUMMARY=$(node -e 'const r=require(process.argv[1]);const p=r.phase2||{};const s=Object.values(p.scripts||{});console.log("phase2:",s.length,"sections,",s.filter(x=>x.result==="PASS").length,"pass,",s.filter(x=>x.result!=="PASS").length,"fail; testClasses",JSON.stringify(p.testClasses),"; scanner",JSON.stringify(p.scanner));s.filter(x=>x.result!=="PASS").forEach(x=>console.log("  FAIL section",x.section||x.name||"?",String(x.error||x.message||"").slice(0,200)))' "$RESULTS" 2>/dev/null)
  log "$SUMMARY"
}
log "=== release-candidate-cycle $TAG start candidate=$CANDIDATE version=$VERSION"

if [ "${SKIP_INSTALL:-0}" = "1" ]; then
  log "--- step 1: SKIPPED (SKIP_INSTALL=1) — candidate already verified installed in both orgs"
else
  log "--- step 1: candidate install (both orgs)"
  bash "$SCRIPTS/install-candidate.sh" "$CANDIDATE" "$TAG" > "$EVIDENCE/phase1-install-$TAG.out" 2>&1
  if ! grep -q "candidate install $SF_SUBSCRIBER_ORG_ALIAS result=0" "$EVIDENCE/phase1-install-$TAG.log" || ! grep -q "candidate install $SF_UPGRADE_ORG_ALIAS result=0" "$EVIDENCE/phase1-install-$TAG.log"; then
    log "ABORT: candidate install failed — see $EVIDENCE/phase1-install-$TAG.log"; exit 1
  fi
  log "candidate installed in both orgs"
fi

log "--- step 2: RUNBOOK 1.4-1.6 on both orgs"
for ORG in "$SF_SUBSCRIBER_ORG_ALIAS" "$SF_UPGRADE_ORG_ALIAS"; do
  bash "$SCRIPTS/deploy-subscriber-artifacts.sh" "$ORG" > "$EVIDENCE/phase1-deploy-$ORG-$TAG.out" 2>&1
  if ! grep -q "Org Cache: true .* Session Cache: true .* Trusted Site: true" "$EVIDENCE/verify-postinstall-$ORG.log"; then
    log "ABORT: Phase 1.4-1.6 verify not true/true/true on $ORG — see phase1-deploy-$ORG-$TAG.out"; exit 1
  fi
  if ! grep -q "deploy status: 0 Succeeded" "$EVIDENCE/phase1-deploy-$ORG-$TAG.out"; then
    log "ABORT: artifact deploy did not succeed on $ORG — see phase1-deploy-$ORG-$TAG.out"; exit 1
  fi
  log "$ORG: artifacts deployed, permission sets assigned, verify true/true/true"
done

log "--- step 3: fresh current-run.json header for $VERSION"
cp "$RESULTS" "$EVIDENCE/current-run-before-$VERSION.json"
HEADER_SUMMARY=$(node -e '
const fs=require("fs");const [path,version,candidate,apiVersion,scope]=process.argv.slice(1);
const header={packageVersion:version,subscriberPackageVersionId:candidate,testDate:new Date().toISOString().slice(0,10),apiVersion:apiVersion,scope:scope};
fs.writeFileSync(path,JSON.stringify(header,null,2)+"\n");console.log("header written:",JSON.stringify(header).slice(0,160));' "$RESULTS" "$VERSION" "$CANDIDATE" "$API_VERSION" "$RUN_SCOPE")
log "$HEADER_SUMMARY"

log "--- step 4: upgrade-leg Apex gates start in the background"
nohup bash "$SCRIPTS/upgrade-leg-apex-gates.sh" "$TAG" > "$EVIDENCE/upgrade-apex-tests-$TAG.out" 2>&1 &
UPGRADE_APEX_PROCESS_ID=$!
log "upgrade Apex gates pid=$UPGRADE_APEX_PROCESS_ID"

log "--- step 5: fresh Phase 2"
SF_SUBSCRIBER_ORG_ALIAS="$SF_SUBSCRIBER_ORG_ALIAS" npm run release:phase2 > "$EVIDENCE/phase2-fresh-$TAG.log" 2>&1
log "fresh Phase 2 exit=$? — $(grep -E 'Scripts:|Test classes:' "$EVIDENCE/phase2-fresh-$TAG.log" | sed 's/\x1b\[[0-9;]*m//g' | tr '\n' ' ')"
phase2_summary
snapshot "current-run-fresh-phase2-$TAG.json"

log "--- step 6: fresh Phase 3 (all parts)"
SF_SUBSCRIBER_ORG_ALIAS="$SF_SUBSCRIBER_ORG_ALIAS" npm run test:e2e > "$EVIDENCE/phase3-fresh-$TAG.log" 2>&1
log "fresh Phase 3 exit=$? — $(grep -E '^ +[0-9]+ (passed|failed|flaky|skipped)' "$EVIDENCE/phase3-fresh-$TAG.log" | tr '\n' ' ')"
snapshot "current-run-fresh-$VERSION.json"

log "--- step 6b: full-org gate on the fresh org (RunAllTestsInOrg, org-verified)"
node "$VERDICT" --org "$SF_SUBSCRIBER_ORG_ALIAS" --label "fullorg-fresh-$TAG" --evidence-dir "$EVIDENCE" --test-level RunAllTestsInOrg --wait-minutes 120 >> "$LOG" 2>&1
FULLORG_EXIT=$?
log "fresh full-org verdict exit=$FULLORG_EXIT"
[ "$FULLORG_EXIT" -eq 0 ] || FAILED_GATES=$((FAILED_GATES+1))
if [ -n "${RELEASE_TARGETED_TEST_CLASSES:-}" ]; then
  log "--- step 6c: targeted classes on the fresh org: $RELEASE_TARGETED_TEST_CLASSES"
  node "$VERDICT" --org "$SF_SUBSCRIBER_ORG_ALIAS" --label "targeted-fresh-$TAG" --evidence-dir "$EVIDENCE" --tests "$RELEASE_TARGETED_TEST_CLASSES" --wait-minutes 30 >> "$LOG" 2>&1
  TARGETED_EXIT=$?
  log "targeted classes verdict exit=$TARGETED_EXIT"
  [ "$TARGETED_EXIT" -eq 0 ] || FAILED_GATES=$((FAILED_GATES+1))
fi

log "--- step 7: wait for the upgrade Apex gates, then upgrade Phase 2"
wait "$UPGRADE_APEX_PROCESS_ID"
UPGRADE_APEX_EXIT=$?
log "upgrade Apex gates finished exit=$UPGRADE_APEX_EXIT"
[ "$UPGRADE_APEX_EXIT" -eq 0 ] || FAILED_GATES=$((FAILED_GATES+1))
log "--- step 7b: drain the org's async queue before upgrade Phase 2 (a section-34 verify raced it once)"
for POLL in $(seq 1 20); do
  sf data query -o "$SF_UPGRADE_ORG_ALIAS" -q "SELECT COUNT(Id) c FROM AsyncApexJob WHERE Status IN ('Queued','Processing','Preparing','Holding')" --json > "$EVIDENCE/async-queue-$TAG.json" 2>&1
  ACTIVE=$(node -e 'const s=require("fs").readFileSync(process.argv[1],"utf8");const r=JSON.parse(s.slice(s.indexOf("{")));const x=((r.result||{}).records||[])[0]||{};console.log(x.c===undefined?"-1":String(x.c))' "$EVIDENCE/async-queue-$TAG.json" 2>/dev/null)
  log "async queue active=$ACTIVE (poll $POLL)"
  [ "$ACTIVE" = "0" ] && break
  sleep 30
done
SF_SUBSCRIBER_ORG_ALIAS="$SF_UPGRADE_ORG_ALIAS" npm run release:phase2 > "$EVIDENCE/phase2-upgrade-$TAG.log" 2>&1
log "upgrade Phase 2 exit=$? — $(grep -E 'Scripts:|Test classes:' "$EVIDENCE/phase2-upgrade-$TAG.log" | sed 's/\x1b\[[0-9;]*m//g' | tr '\n' ' ')"
phase2_summary
snapshot "current-run-upgrade-phase2-$TAG.json"

log "--- step 8: upgrade e2e (part1 --no-deps, part7+part8, part10)"
SF_SUBSCRIBER_ORG_ALIAS="$SF_UPGRADE_ORG_ALIAS" npx playwright test --config "$PLAYWRIGHT_CONFIGURATION_FILE" part1-app-core --no-deps > "$EVIDENCE/phase3-upgrade-part1-$TAG.log" 2>&1
log "upgrade part1 exit=$? — $(grep -E '^ +[0-9]+ (passed|failed|flaky|skipped)' "$EVIDENCE/phase3-upgrade-part1-$TAG.log" | tr '\n' ' ')"
SF_SUBSCRIBER_ORG_ALIAS="$SF_UPGRADE_ORG_ALIAS" npx playwright test --config "$PLAYWRIGHT_CONFIGURATION_FILE" part7-async-chain part8-chain-monitor --project=independent --no-deps > "$EVIDENCE/phase3-upgrade-part8-$TAG.log" 2>&1
log "upgrade part7+part8 exit=$? — $(grep -E '^ +[0-9]+ (passed|failed|flaky|skipped)' "$EVIDENCE/phase3-upgrade-part8-$TAG.log" | tr '\n' ' ')"
SF_SUBSCRIBER_ORG_ALIAS="$SF_UPGRADE_ORG_ALIAS" npx playwright test --config "$PLAYWRIGHT_CONFIGURATION_FILE" part10-log-console --project=independent --no-deps > "$EVIDENCE/phase3-upgrade-part10-$TAG.log" 2>&1
log "upgrade part10 exit=$? — $(grep -E '^ +[0-9]+ (passed|failed|flaky|skipped)' "$EVIDENCE/phase3-upgrade-part10-$TAG.log" | tr '\n' ' ')"
snapshot "current-run-upgrade-e2e-$TAG.json"

log "=== release-candidate-cycle $TAG COMPLETE — failed Apex gates=$FAILED_GATES"
[ "$FAILED_GATES" -eq 0 ]
