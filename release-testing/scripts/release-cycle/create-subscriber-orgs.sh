#!/usr/bin/env bash
# RUNBOOK 1.2 / 1.3b (part 1) for one release candidate: delete and recreate BOTH subscriber orgs
# (beta package versions can never be upgraded, and the Dev Hub caps active scratch orgs) and install
# the released base version into the upgrade org.
# The candidate install is a separate step (install-candidate.sh) so this part can run before a build ends.
#
# Usage: bash release-testing/scripts/release-cycle/create-subscriber-orgs.sh <tag e.g. rc6>
# Run from the repository root.
#
# Required variables: SF_SUBSCRIBER_ORG_ALIAS, SF_UPGRADE_ORG_ALIAS, RELEASE_EVIDENCE_DIR,
#                     RELEASED_BASE_PACKAGE_VERSION_ID (the 04t of the released version the upgrade leg starts from)
# Optional variables: SF_DEV_HUB_ALIAS (default DevHub), SUBSCRIBER_STAGING_DIRECTORY (default /tmp/kern-subscriber),
#                     RELEASE_API_VERSION (default 68.0, used for the staging project's sourceApiVersion)
set -u
export SF_SKIP_NEW_VERSION_CHECK=true
: "${SF_SUBSCRIBER_ORG_ALIAS:?SF_SUBSCRIBER_ORG_ALIAS is not set}"
: "${SF_UPGRADE_ORG_ALIAS:?SF_UPGRADE_ORG_ALIAS is not set}"
: "${RELEASE_EVIDENCE_DIR:?RELEASE_EVIDENCE_DIR is not set}"
: "${RELEASED_BASE_PACKAGE_VERSION_ID:?RELEASED_BASE_PACKAGE_VERSION_ID is not set (the 04t the upgrade leg starts from)}"
TAG="${1:?tag (e.g. rc6) required}"
# Stop before any delete or install when either alias is the development org (by alias, username or a second alias).
node scripts/lib/development-org-guard.js "$SF_SUBSCRIBER_ORG_ALIAS" "$SF_UPGRADE_ORG_ALIAS" || exit 1
DEV_HUB="${SF_DEV_HUB_ALIAS:-DevHub}"
REPOSITORY_ROOT="$(pwd)"
mkdir -p "$RELEASE_EVIDENCE_DIR"
EVIDENCE="$(cd "$RELEASE_EVIDENCE_DIR" && pwd)"
STAGING="${SUBSCRIBER_STAGING_DIRECTORY:-/tmp/kern-subscriber}"
LOG="$EVIDENCE/phase1-create-$TAG.log"
SCRATCH_DEFINITION_FILE="$REPOSITORY_ROOT/config/project-scratch-def.json"

log() { echo "$*" | tee -a "$LOG"; }
log "=== create-subscriber-orgs $TAG start $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Staging project (RUNBOOK 1.2) — recreate the loose files macOS may have purged.
mkdir -p "$STAGING/force-app"
if [ ! -f "$STAGING/sfdx-project.json" ]; then
  printf '%s\n' '{"packageDirectories":[{"path":"force-app","default":true}],"name":"KernSubscriber","sourceApiVersion":"'"${RELEASE_API_VERSION:-68.0}"'"}' > "$STAGING/sfdx-project.json"
  log "staging sfdx-project.json recreated"
fi
if [ ! -f "$STAGING/.forceignore" ]; then
  printf '%s\n%s\n' '# Jest specs are not deployable LWC bundle content' '**/__tests__/**' > "$STAGING/.forceignore"
  log "staging .forceignore recreated"
fi

for ORG in "$SF_SUBSCRIBER_ORG_ALIAS" "$SF_UPGRADE_ORG_ALIAS"; do
  log "--- delete $ORG"
  sf org delete scratch -o "$ORG" --no-prompt --json > "$EVIDENCE/delete-$ORG-$TAG.json" 2>&1
  log "delete $ORG exit=$?"
done

log "--- create fresh $SF_SUBSCRIBER_ORG_ALIAS (30d)"
( cd "$STAGING" && sf org create scratch -f "$SCRATCH_DEFINITION_FILE" -a "$SF_SUBSCRIBER_ORG_ALIAS" -v "$DEV_HUB" -y 30 --wait 15 --json > "$EVIDENCE/create-$SF_SUBSCRIBER_ORG_ALIAS-$TAG.json" 2>&1 )
log "create $SF_SUBSCRIBER_ORG_ALIAS exit=$?"
CREATE_SUMMARY=$(node -e 'const r=require(process.argv[1]);console.log(process.argv[2]+":",r.status,(r.result&&r.result.username)||JSON.stringify(r).slice(0,300))' "$EVIDENCE/create-$SF_SUBSCRIBER_ORG_ALIAS-$TAG.json" "$SF_SUBSCRIBER_ORG_ALIAS" 2>/dev/null)
log "$CREATE_SUMMARY"

log "--- create $SF_UPGRADE_ORG_ALIAS (7d)"
( cd "$STAGING" && sf org create scratch -f "$SCRATCH_DEFINITION_FILE" -a "$SF_UPGRADE_ORG_ALIAS" -v "$DEV_HUB" -y 7 --wait 15 --json > "$EVIDENCE/create-$SF_UPGRADE_ORG_ALIAS-$TAG.json" 2>&1 )
log "create $SF_UPGRADE_ORG_ALIAS exit=$?"
CREATE_SUMMARY=$(node -e 'const r=require(process.argv[1]);console.log(process.argv[2]+":",r.status,(r.result&&r.result.username)||JSON.stringify(r).slice(0,300))' "$EVIDENCE/create-$SF_UPGRADE_ORG_ALIAS-$TAG.json" "$SF_UPGRADE_ORG_ALIAS" 2>/dev/null)
log "$CREATE_SUMMARY"

log "--- install released base $RELEASED_BASE_PACKAGE_VERSION_ID into $SF_UPGRADE_ORG_ALIAS"
sf package install -o "$SF_UPGRADE_ORG_ALIAS" --package "$RELEASED_BASE_PACKAGE_VERSION_ID" --wait 20 --no-prompt --json > "$EVIDENCE/install-released-base-$TAG.json" 2>&1
log "install released base exit=$?"
INSTALL_SUMMARY=$(node -e 'const r=require(process.argv[1]);console.log("install released base:",r.status,(r.result&&r.result.Status)||String(r.message||"").slice(0,200))' "$EVIDENCE/install-released-base-$TAG.json" 2>/dev/null)
log "$INSTALL_SUMMARY"

log "--- org list"
sf org list --json > "$EVIDENCE/orglist-$TAG.json" 2>&1
ORG_LIST=$(node -e 'const r=require(process.argv[1]).result;(r.scratchOrgs||[]).forEach(o=>console.log("scratch",o.alias,o.username,o.expirationDate,o.status))' "$EVIDENCE/orglist-$TAG.json" 2>/dev/null)
log "$ORG_LIST"
log "=== create-subscriber-orgs $TAG end $(date -u +%Y-%m-%dT%H:%M:%SZ)"
