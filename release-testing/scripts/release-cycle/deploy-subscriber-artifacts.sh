#!/usr/bin/env bash
# RUNBOOK 1.4 to 1.6 for one subscriber org: restage release-testing/subscriber into the staging project,
# write the org-specific CSP trusted site, deploy, assign SubscriberTestAccess, enable audit-field
# back-dating (TWO separate deploys, then the permission set), then run the post-install verify.
#
# Usage: bash release-testing/scripts/release-cycle/deploy-subscriber-artifacts.sh <org alias>
# Run from the repository root. The org alias is passed in so the cycle can run this for each leg in turn.
#
# Required variables: RELEASE_EVIDENCE_DIR
# Optional variables: SUBSCRIBER_STAGING_DIRECTORY (default /tmp/kern-subscriber)
set -u
export SF_SKIP_NEW_VERSION_CHECK=true
: "${RELEASE_EVIDENCE_DIR:?RELEASE_EVIDENCE_DIR is not set}"
ORG="${1:?org alias required}"
# Stop before any deploy when the org is the development org (by alias, username or a second alias).
node scripts/lib/development-org-guard.js "$ORG" || exit 1
REPOSITORY_ROOT="$(pwd)"
mkdir -p "$RELEASE_EVIDENCE_DIR"
EVIDENCE="$(cd "$RELEASE_EVIDENCE_DIR" && pwd)"
STAGING="${SUBSCRIBER_STAGING_DIRECTORY:-/tmp/kern-subscriber}"
SOURCE_DIRECTORY="$REPOSITORY_ROOT/release-testing/subscriber"
DESTINATION_DIRECTORY="$STAGING/force-app/main/default"
LOG="$EVIDENCE/phase1-deploy-$ORG.log"

: > "$EVIDENCE/verify-postinstall-$ORG.log"
log() { echo "$*" | tee -a "$LOG"; }
log "=== deploy-subscriber-artifacts $ORG start $(date -u +%Y-%m-%dT%H:%M:%SZ)"

log "--- restage $DESTINATION_DIRECTORY from release-testing/subscriber"
rm -rf "$DESTINATION_DIRECTORY"
mkdir -p "$DESTINATION_DIRECTORY"/{classes,triggers,customMetadata,customPermissions,cachePartitions,layouts,labels,flows,objects,platformEventChannels,platformEventChannelMembers,lwc,flexipages,tabs,permissionsets,cspTrustedSites}
cp "$SOURCE_DIRECTORY"/classes/*.cls "$SOURCE_DIRECTORY"/classes/*.cls-meta.xml "$DESTINATION_DIRECTORY/classes/"
cp "$SOURCE_DIRECTORY"/classes/*.trigger "$SOURCE_DIRECTORY"/classes/*.trigger-meta.xml "$DESTINATION_DIRECTORY/triggers/"
cp "$SOURCE_DIRECTORY"/customMetadata/* "$DESTINATION_DIRECTORY/customMetadata/"
cp "$SOURCE_DIRECTORY"/customPermissions/* "$DESTINATION_DIRECTORY/customPermissions/"
cp "$SOURCE_DIRECTORY"/cachePartitions/* "$DESTINATION_DIRECTORY/cachePartitions/"
cp "$SOURCE_DIRECTORY"/layouts/* "$DESTINATION_DIRECTORY/layouts/"
cp "$SOURCE_DIRECTORY"/flows/* "$DESTINATION_DIRECTORY/flows/"
cp -r "$SOURCE_DIRECTORY"/objects/* "$DESTINATION_DIRECTORY/objects/"
cp "$SOURCE_DIRECTORY"/platformEventChannels/* "$DESTINATION_DIRECTORY/platformEventChannels/"
cp "$SOURCE_DIRECTORY"/platformEventChannelMembers/* "$DESTINATION_DIRECTORY/platformEventChannelMembers/"
cp "$SOURCE_DIRECTORY"/labels/* "$DESTINATION_DIRECTORY/labels/"
cp -r "$SOURCE_DIRECTORY"/lwc/* "$DESTINATION_DIRECTORY/lwc/"
cp "$SOURCE_DIRECTORY"/flexipages/* "$DESTINATION_DIRECTORY/flexipages/"
cp "$SOURCE_DIRECTORY"/tabs/* "$DESTINATION_DIRECTORY/tabs/"
cp "$SOURCE_DIRECTORY"/permissionsets/* "$DESTINATION_DIRECTORY/permissionsets/"
log "staged: $(find "$DESTINATION_DIRECTORY" -type f | wc -l | tr -d ' ') files"

log "--- CSP trusted site for the org domain"
sf org display -o "$ORG" --json > "$EVIDENCE/orgdisplay-$ORG.json" 2>&1
ORG_URL=$(node -e 'const s=require("fs").readFileSync(process.argv[1],"utf8");const r=JSON.parse(s.slice(s.indexOf("{")));console.log(r.result.instanceUrl)' "$EVIDENCE/orgdisplay-$ORG.json")
log "org url: $ORG_URL"
cat > "$DESTINATION_DIRECTORY/cspTrustedSites/${ORG}.cspTrustedSite-meta.xml" << XMLEOF
<?xml version="1.0" encoding="UTF-8"?>
<CspTrustedSite xmlns="http://soap.sforce.com/2006/04/metadata">
    <endpointUrl>${ORG_URL}</endpointUrl>
    <description>Trusted URL for subscriber scratch org</description>
    <isActive>true</isActive>
    <isApplicableToConnectSrc>true</isApplicableToConnectSrc>
    <isApplicableToFrameSrc>false</isApplicableToFrameSrc>
    <isApplicableToImgSrc>false</isApplicableToImgSrc>
    <isApplicableToStyleSrc>false</isApplicableToStyleSrc>
    <isApplicableToFontSrc>false</isApplicableToFontSrc>
    <isApplicableToMediaSrc>false</isApplicableToMediaSrc>
</CspTrustedSite>
XMLEOF
log "csp file written"

log "--- deploy staged artifacts"
rm -rf "$STAGING/.sf/orgs"
( cd "$STAGING" && sf project deploy start -o "$ORG" -d force-app/main/default --ignore-conflicts --wait 30 --json > "$EVIDENCE/deploy-artifacts-$ORG.json" 2>&1 )
log "deploy exit=$?"
DEPLOY_SUMMARY=$(node -e 'const r=require(process.argv[1]);const x=r.result||{};console.log("deploy status:",r.status,x.status,"components",x.numberComponentsDeployed,"/",x.numberComponentsTotal,"errors",x.numberComponentErrors);(x.details&&x.details.componentFailures?[].concat(x.details.componentFailures):[]).slice(0,20).forEach(f=>console.log("  FAIL",f.fullName,f.problem))' "$EVIDENCE/deploy-artifacts-$ORG.json" 2>/dev/null)
log "$DEPLOY_SUMMARY"

log "--- permission set: SubscriberTestAccess"
sf org assign permset -o "$ORG" -n SubscriberTestAccess --json > "$EVIDENCE/permset-SubscriberTestAccess-$ORG.json" 2>&1
log "exit=$?"

log "--- audit-field back-dating: step 1 (security settings), then step 2 (permission set), then assign"
sf project deploy start --metadata-dir release-testing/e2e/fixtures/audit-fields/step1-security-settings/metadata -o "$ORG" --wait 10 --json > "$EVIDENCE/audit-step1-$ORG.json" 2>&1
log "step1 exit=$?"
AUDIT_SUMMARY=$(node -e 'const r=require(process.argv[1]);console.log("step1:",r.status,r.result&&r.result.status)' "$EVIDENCE/audit-step1-$ORG.json" 2>/dev/null)
log "$AUDIT_SUMMARY"
sf project deploy start --metadata-dir release-testing/e2e/fixtures/audit-fields/step2-audit-permset/metadata -o "$ORG" --wait 10 --json > "$EVIDENCE/audit-step2-$ORG.json" 2>&1
log "step2 exit=$?"
AUDIT_SUMMARY=$(node -e 'const r=require(process.argv[1]);console.log("step2:",r.status,r.result&&r.result.status)' "$EVIDENCE/audit-step2-$ORG.json" 2>/dev/null)
log "$AUDIT_SUMMARY"
sf org assign permset -o "$ORG" -n KernE2EAuditFieldAccess --json > "$EVIDENCE/permset-KernE2EAuditFieldAccess-$ORG.json" 2>&1
log "assign exit=$?"

log "--- post-install verify (Org Cache / Session Cache / Trusted Site)"
cat > "$EVIDENCE/verify-postinstall.apex" << 'APEXEOF'
Boolean org = kern.UTIL_Cache.isOrgAllocated();
Boolean session = kern.UTIL_Cache.isSessionAllocated();
String orgUrl = Url.getOrgDomainUrl().toExternalForm();
List<CspTrustedSite> sites = [SELECT Id FROM CspTrustedSite WHERE IsActive = true AND EndpointUrl = :orgUrl];
System.debug('Org Cache: ' + org + ' | Session Cache: ' + session + ' | Trusted Site: ' + !sites.isEmpty());
APEXEOF
sf apex run -o "$ORG" -f "$EVIDENCE/verify-postinstall.apex" > "$EVIDENCE/verify-postinstall-$ORG.log" 2>&1
log "verify exit=$?"
VERIFY_LINE=$(grep "USER_DEBUG" "$EVIDENCE/verify-postinstall-$ORG.log")
log "$VERIFY_LINE"
log "=== deploy-subscriber-artifacts $ORG end $(date -u +%Y-%m-%dT%H:%M:%SZ)"
