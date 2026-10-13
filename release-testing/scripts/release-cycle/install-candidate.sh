#!/usr/bin/env bash
# RUNBOOK 1.3 / 1.3b (part 2): install the candidate into BOTH subscriber orgs (the fresh leg, then the
# upgrade leg on top of the released base), retrying through the roughly five-minute per-instance
# propagation delay ("No record found for SELECT ... SubscriberPackageVersion").
#
# Usage: bash release-testing/scripts/release-cycle/install-candidate.sh <candidate 04t> <tag e.g. rc6>
# Run from the repository root.
#
# Required variables: SF_SUBSCRIBER_ORG_ALIAS, SF_UPGRADE_ORG_ALIAS, RELEASE_EVIDENCE_DIR
set -u
export SF_SKIP_NEW_VERSION_CHECK=true
: "${SF_SUBSCRIBER_ORG_ALIAS:?SF_SUBSCRIBER_ORG_ALIAS is not set}"
: "${SF_UPGRADE_ORG_ALIAS:?SF_UPGRADE_ORG_ALIAS is not set}"
: "${RELEASE_EVIDENCE_DIR:?RELEASE_EVIDENCE_DIR is not set}"
CANDIDATE="${1:?candidate SubscriberPackageVersionId (04t...) required}"
TAG="${2:?tag (e.g. rc6) required}"
# Stop before any install when either alias is the development org (by alias, username or a second alias).
node scripts/lib/development-org-guard.js "$SF_SUBSCRIBER_ORG_ALIAS" "$SF_UPGRADE_ORG_ALIAS" || exit 1
mkdir -p "$RELEASE_EVIDENCE_DIR"
EVIDENCE="$(cd "$RELEASE_EVIDENCE_DIR" && pwd)"
LOG="$EVIDENCE/phase1-install-$TAG.log"

: > "$LOG"
log() { echo "$*" | tee -a "$LOG"; }
log "=== install-candidate $TAG start $(date -u +%Y-%m-%dT%H:%M:%SZ) candidate=$CANDIDATE"

install_candidate() {
  local ORG="$1"
  local ORG_LOG="$EVIDENCE/install-$TAG-$ORG.log"
  local attempt=1
  while [ $attempt -le 12 ]; do
    sf package install -o "$ORG" --package "$CANDIDATE" --wait 20 --no-prompt --json > "$EVIDENCE/install-$TAG-$ORG.json" 2>&1
    local exitCode=$?
    local summary
    summary=$(node -e 'const s=require("fs").readFileSync(process.argv[1],"utf8");const r=JSON.parse(s.slice(s.indexOf("{")));console.log(r.status===0?("OK "+(r.result&&r.result.Status)):("ERR "+String(r.message||JSON.stringify(r)).slice(0,160)))' "$EVIDENCE/install-$TAG-$ORG.json" 2>/dev/null)
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $ORG attempt $attempt exit=$exitCode $summary" | tee -a "$ORG_LOG" "$LOG"
    if [ $exitCode -eq 0 ] && [[ "$summary" == *SUCCESS* ]]; then return 0; fi
    if [[ "$summary" == *"No record found"* ]]; then sleep 60; else sleep 30; fi
    attempt=$((attempt+1))
  done
  return 1
}

log "--- install candidate $CANDIDATE into $SF_SUBSCRIBER_ORG_ALIAS (fresh leg)"
install_candidate "$SF_SUBSCRIBER_ORG_ALIAS"
log "candidate install $SF_SUBSCRIBER_ORG_ALIAS result=$?"

log "--- install candidate $CANDIDATE into $SF_UPGRADE_ORG_ALIAS (upgrade leg: released base -> candidate)"
install_candidate "$SF_UPGRADE_ORG_ALIAS"
log "candidate install $SF_UPGRADE_ORG_ALIAS result=$?"

log "--- installed packages per org"
for ORG in "$SF_SUBSCRIBER_ORG_ALIAS" "$SF_UPGRADE_ORG_ALIAS"; do
  sf package installed list -o "$ORG" --json > "$EVIDENCE/installed-$TAG-$ORG.json" 2>&1
  INSTALLED=$(node -e 'const r=require(process.argv[1]);(r.result||[]).forEach(p=>console.log(process.argv[2],p.SubscriberPackageName,p.SubscriberPackageVersionNumber,p.SubscriberPackageVersionId))' "$EVIDENCE/installed-$TAG-$ORG.json" "$ORG" 2>/dev/null)
  log "$INSTALLED"
done
log "=== install-candidate $TAG end $(date -u +%Y-%m-%dT%H:%M:%SZ)"
