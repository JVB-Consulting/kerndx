#!/usr/bin/env bash
# Create the upgrade subscriber org against the Dev Hub's rolling daily scratch-org limit: retry every
# thirty minutes until a signup slot frees (failed signups consume nothing), then install the released
# base version with the standard propagation-retry loop.
# Use this instead of create-subscriber-orgs.sh when only the upgrade org needs rebuilding.
#
# Usage: bash release-testing/scripts/release-cycle/create-upgrade-org-with-retry.sh <tag e.g. rc6>
# Run from the repository root.
#
# Required variables: SF_UPGRADE_ORG_ALIAS, RELEASE_EVIDENCE_DIR,
#                     RELEASED_BASE_PACKAGE_VERSION_ID (the 04t of the released version the upgrade leg starts from)
# Optional variables: SF_DEV_HUB_ALIAS (default DevHub), SUBSCRIBER_STAGING_DIRECTORY (default /tmp/kern-subscriber)
set -u
export SF_SKIP_NEW_VERSION_CHECK=true
: "${SF_UPGRADE_ORG_ALIAS:?SF_UPGRADE_ORG_ALIAS is not set}"
: "${RELEASE_EVIDENCE_DIR:?RELEASE_EVIDENCE_DIR is not set}"
: "${RELEASED_BASE_PACKAGE_VERSION_ID:?RELEASED_BASE_PACKAGE_VERSION_ID is not set (the 04t the upgrade leg starts from)}"
TAG="${1:?tag (e.g. rc6) required}"
# Stop before the org is created and the base installed when the alias is the development org.
node scripts/lib/development-org-guard.js "$SF_UPGRADE_ORG_ALIAS" || exit 1
DEV_HUB="${SF_DEV_HUB_ALIAS:-DevHub}"
REPOSITORY_ROOT="$(pwd)"
mkdir -p "$RELEASE_EVIDENCE_DIR"
EVIDENCE="$(cd "$RELEASE_EVIDENCE_DIR" && pwd)"
STAGING="${SUBSCRIBER_STAGING_DIRECTORY:-/tmp/kern-subscriber}"
SCRATCH_DEFINITION_FILE="$REPOSITORY_ROOT/config/project-scratch-def.json"
LOG="$EVIDENCE/create-upgrade-retry-$TAG.log"

: > "$LOG"
log() { echo "$(date +%H:%M:%S) $*" | tee -a "$LOG"; }
log "=== create-upgrade-org-with-retry $TAG start"

mkdir -p "$STAGING/force-app"
CREATED=0
for ATTEMPT in $(seq 1 32); do
  ( cd "$STAGING" && sf org create scratch -f "$SCRATCH_DEFINITION_FILE" -a "$SF_UPGRADE_ORG_ALIAS" -v "$DEV_HUB" -y 7 --wait 15 --json > "$EVIDENCE/create-$SF_UPGRADE_ORG_ALIAS-$TAG.json" 2>&1 )
  EXIT_CODE=$?
  SUMMARY=$(node -e 'const s=require("fs").readFileSync(process.argv[1],"utf8");const r=JSON.parse(s.slice(s.indexOf("{")));console.log(r.status===0?("OK "+(r.result&&r.result.username)):("ERR "+String(r.name||r.message||"").slice(0,120)))' "$EVIDENCE/create-$SF_UPGRADE_ORG_ALIAS-$TAG.json" 2>/dev/null)
  log "create attempt $ATTEMPT exit=$EXIT_CODE $SUMMARY"
  if [ $EXIT_CODE -eq 0 ] && [[ "$SUMMARY" == OK* ]]; then CREATED=1; break; fi
  if [[ "$SUMMARY" != *LIMIT_EXCEEDED* ]]; then
    log "non-limit failure — retrying once after 5 minutes"; sleep 300
  else
    sleep 1800
  fi
done
if [ $CREATED -ne 1 ]; then log "ABORT: could not create $SF_UPGRADE_ORG_ALIAS after $ATTEMPT attempts"; exit 1; fi

log "--- install released base $RELEASED_BASE_PACKAGE_VERSION_ID"
INSTALL_OK=0
for ATTEMPT in $(seq 1 12); do
  sf package install -o "$SF_UPGRADE_ORG_ALIAS" --package "$RELEASED_BASE_PACKAGE_VERSION_ID" --wait 20 --no-prompt --json > "$EVIDENCE/install-released-base-$TAG.json" 2>&1
  EXIT_CODE=$?
  SUMMARY=$(node -e 'const s=require("fs").readFileSync(process.argv[1],"utf8");const r=JSON.parse(s.slice(s.indexOf("{")));console.log(r.status===0?("OK "+(r.result&&r.result.Status)):("ERR "+String(r.message||JSON.stringify(r)).slice(0,160)))' "$EVIDENCE/install-released-base-$TAG.json" 2>/dev/null)
  log "install released base attempt $ATTEMPT exit=$EXIT_CODE $SUMMARY"
  if [ $EXIT_CODE -eq 0 ] && [[ "$SUMMARY" == *SUCCESS* ]]; then INSTALL_OK=1; break; fi
  if [[ "$SUMMARY" == *"No record found"* ]]; then sleep 60; else sleep 30; fi
done
if [ $INSTALL_OK -ne 1 ]; then log "ABORT: released base install failed"; exit 1; fi
log "=== create-upgrade-org-with-retry $TAG DONE — org ready with the released base"
