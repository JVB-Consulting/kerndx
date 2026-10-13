# Release-cycle scripts

The unattended two-leg release test for one package candidate. Every script runs from the repository
root and writes its logs and JSON files into the folder `RELEASE_EVIDENCE_DIR` names.

## The scripts

| Script | What it does |
| --- | --- |
| `create-subscriber-orgs.sh <tag>` | Deletes and recreates both subscriber orgs, then installs the released base version into the upgrade org. |
| `create-upgrade-org-with-retry.sh <tag>` | Rebuilds only the upgrade org, retrying around the Dev Hub's daily scratch-org limit. |
| `install-candidate.sh <04t> <tag>` | Installs the candidate into both orgs, retrying through the package propagation delay. |
| `deploy-subscriber-artifacts.sh <org alias>` | Runbook 1.4 to 1.6 for one org: stage the subscriber artifacts, trusted site, deploy, permission sets, audit-field back-dating, post-install verify. |
| `upgrade-leg-apex-gates.sh <tag>` | The upgrade org's Apex gates: RunLocalTests with coverage, then RunAllTestsInOrg. Exits non-zero if either fails. |
| `release-candidate-cycle.sh <04t> <version> <tag>` | The whole cycle, in the runbook's order. Exits non-zero if any Apex gate failed. |
| `watch-package-version-request.sh <08c> <tag>` | Attaches to a package build still running after the command line stopped polling. |

## Variables

| Variable | Meaning |
| --- | --- |
| `SF_SUBSCRIBER_ORG_ALIAS` | The fresh-leg subscriber org. |
| `SF_UPGRADE_ORG_ALIAS` | The upgrade-leg subscriber org. |
| `RELEASE_EVIDENCE_DIR` | Where every log, snapshot and JSON file lands. An absolute path is safest; a relative one is resolved from the repository root. |
| `RELEASED_BASE_PACKAGE_VERSION_ID` | The released `04t` the upgrade leg starts from. |
| `SF_DEV_HUB_ALIAS` | Dev Hub alias (defaults to `DevHub`). |
| `SUBSCRIBER_STAGING_DIRECTORY` | The staging project the subscriber artifacts deploy from (defaults to `/tmp/kern-subscriber`). |
| `SKIP_INSTALL=1` | Cycle only: the candidate is already installed in both orgs. |
| `RELEASE_RUN_SCOPE` | Cycle only: the scope sentence written into the results header. |
| `RELEASE_API_VERSION` | The API version (default 68.0): the results header, and the staging project's `sourceApiVersion`. |
| `RELEASE_TARGETED_TEST_CLASSES` | Cycle only: comma-separated classes to run as an extra artifact-specific gate. |

Each script stops immediately with a clear message when a variable it needs is missing.

## The order

1. `create-subscriber-orgs.sh` (or `create-upgrade-org-with-retry.sh` when only the upgrade org is stale).
2. `release-candidate-cycle.sh`, which runs the rest in order: `install-candidate.sh`,
   `deploy-subscriber-artifacts.sh` for each org, the results header, `upgrade-leg-apex-gates.sh` in the
   background, fresh Phase 2, fresh Phase 3, the fresh org's full-org gate, the async-queue drain, the
   upgrade org's Phase 2, and the upgrade end-to-end parts.

## Test outcomes

No script here decides for itself whether a test run passed. Every Apex verdict comes from one call to
`release-testing/runner/apex-test-verdict.js`, which reads the run's own rows back from the org, waits out
any run already in flight, and returns zero only for a completed run with nothing failing. The command
line's own JSON summary is not trusted: it comes back empty when its wait expires, and a run with
twenty-five failures once read as clean. When a gate passes `--code-coverage`, the verdict line also
carries the org-wide coverage percentage.
