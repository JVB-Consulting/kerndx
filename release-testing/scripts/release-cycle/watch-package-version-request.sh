#!/usr/bin/env bash
# Attach to an in-flight Package2VersionCreateRequest after a command-line poll death (poll death is not
# build death). Polls every five minutes until the request reaches a terminal state; prints the 04t on success.
#
# Usage: bash release-testing/scripts/release-cycle/watch-package-version-request.sh <08c id> <tag e.g. rc6>
# Run from the repository root.
#
# Required variables: RELEASE_EVIDENCE_DIR
# Optional variables: SF_DEV_HUB_ALIAS (default DevHub)
set -u
export SF_SKIP_NEW_VERSION_CHECK=true
: "${RELEASE_EVIDENCE_DIR:?RELEASE_EVIDENCE_DIR is not set}"
REQUEST="${1:?08c id required}"
TAG="${2:?tag (e.g. rc6) required}"
DEV_HUB="${SF_DEV_HUB_ALIAS:-DevHub}"
mkdir -p "$RELEASE_EVIDENCE_DIR"
EVIDENCE="$(cd "$RELEASE_EVIDENCE_DIR" && pwd)"
OUTPUT="$EVIDENCE/package-version-create-request-$TAG.json"

for POLL in $(seq 1 60); do
  sf package version create report -i "$REQUEST" -v "$DEV_HUB" --json > "$OUTPUT" 2>&1
  STATE=$(node -e 'const s=require("fs").readFileSync(process.argv[1],"utf8");const r=JSON.parse(s.slice(s.indexOf("{")));const x=(r.result&&r.result[0])||r.result||{};console.log((x.Status||"parse-error")+" "+(x.SubscriberPackageVersionId||""))' "$OUTPUT" 2>/dev/null)
  echo "$(date +%H:%M:%S) poll $POLL: $STATE"
  case "$STATE" in
    Success*|Error*|parse-error*) break ;;
    *) sleep 300 ;;
  esac
done
node -e 'const s=require("fs").readFileSync(process.argv[1],"utf8");const r=JSON.parse(s.slice(s.indexOf("{")));const x=(r.result&&r.result[0])||r.result||{};console.log("FINAL:",x.Status,x.SubscriberPackageVersionId||"");(x.Error||[]).slice(0,20).forEach(e=>console.log("  ERR",typeof e==="string"?e:JSON.stringify(e)))' "$OUTPUT"
