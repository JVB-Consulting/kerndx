# KernDX Release Testing Runbook

> **Who runs this?** This runbook documents the test cycle KernDX maintainers run before tagging a managed-package build — it is the gate every Kern release candidate must clear
> before being promoted to a published `04t` subscriber package version. It is shipped publicly so subscribers can see exactly what gauntlet a Kern version cleared on its way to
> becoming an installable release. **Subscribers do not need to run this themselves**; treat it as a reference for what "shipped" means in this project. The
`release-testing/subscriber/` tree (Apex/LWC test fixtures used by these runs) is reusable if you want to anchor your own org-level regression suite against the framework, but the
> four phases below are the maintainers' workflow.

> **`<repo-root>` placeholder.** Commands below reference `<repo-root>` where the absolute path to your project clone goes. Substitute mentally with the output of `pwd` from your
> project's root directory, or set an env var (`REPO_ROOT=$(pwd)`) and run `cd "$REPO_ROOT"`. The placeholder convention keeps this runbook portable across maintainer machines and
> CI
> runners.

## Table of Contents

- [Configuration](#configuration)
- [Overview](#overview)
- [Phase 1 — Environment Setup](#phase-1--environment-setup)
- [Phase 2 — Automated Tests](#phase-2--automated-tests)
    - [Run a single load test in isolation](#run-a-single-load-test-in-isolation)
- [Phase 2.5 — Perf History Harvest](#phase-25--perf-history-harvest)
- [Phase 3 — Visual Tests (Playwright E2E)](#phase-3--visual-tests-playwright-e2e)
- [Phase 4 — Results Recording](#phase-4--results-recording)
- [Phase 5 — Extended Load (pre-tag only)](#phase-5--extended-load-pre-tag-only)
- [Knowledge Org Setup](#knowledge-org-setup)
- [Enhanced Usage Metrics Setup](#enhanced-usage-metrics-setup)

## Configuration

`SF_SUBSCRIBER_ORG_ALIAS` is required. The runner scripts under `release-testing/runner/` resolve it via `release-testing/runner/subscriber-config.js` and throw a clear error if it
is unset. Export it before running any command in this runbook:

```bash
export SF_SUBSCRIBER_ORG_ALIAS=MySubscriberOrg
```

If you leave it unset, the runner scripts fail fast with a message telling you which env var to set. The bash snippets in this runbook use `$SF_SUBSCRIBER_ORG_ALIAS` directly —
your exported value is substituted automatically by your shell.

## Overview

This runbook defines the promotion gate for every KernDX release candidate. It combines automated Apex scripts, test
class execution, and AI-orchestrated browser checks into a single versioned test cycle.

**Wall-clock estimates:**

- **Standard run (Phases 1-4):** ~85 min (setup ~15 min, automated tests ~45 min, visual tests ~20 min, recording ~5 min)
- **Extended load (Phase 5, pre-tag only):** ~45-60 min additional

**Test infrastructure lives in `release-testing/`:**

```
release-testing/
  RUNBOOK.md                          # This file
  subscriber/                         # Deployable artifacts for subscriber scratch org
    cachePartitions/                  # Platform Cache allocation for kern__Library
    classes/                          # Apex classes, triggers, meta XML
    customMetadata/                   # CMDT records
    layouts/                          # Account layout (with AccountSource field)
    lwc/                              # LWC test components
    flexipages/                       # SubscriberLwcTestPage
    tabs/                             # Tab definition
    permissionsets/                   # SubscriberTestAccess
  scanner/                            # Static analysis validation fixtures
    classes/                          # Apex: deliberate violations + compliant class
    lwc/                              # LWC: violation, compliant, suppressed components
  scripts/                            # Anonymous Apex test scripts (111 files) + Node probes
  e2e/                                # Playwright visual tests (79 checks)
    specs/                            # 10 spec files (part1 through part10) + capture specs
    pages/                            # Page objects for Salesforce UI
    helpers/                          # Auth, CLI, navigation, and wait helpers
    fixtures/cmdt-states/             # CMDT state XML for sections 3, 11, 27
    fixtures/audit-fields/            # Two-step audit-field back-dating enablement (part10 seeds)
  runner/                             # Phase 2 orchestrator and CMDT deployer
  results/                            # Version-stamped result files
```

---

## Phase 1 — Environment Setup

### 1.1 Build Package

```bash
node scripts/build-package.js --skip-validation
```

Note the `SubscriberPackageVersionId` (04t...) from the output.

### 1.2 Create Subscriber Scratch Org

```bash
sf org delete scratch -o $SF_SUBSCRIBER_ORG_ALIAS --no-prompt
```

**CRITICAL:** Create the scratch org from `/tmp/kern-subscriber/` — NOT the dev project (has `"namespace":"kern"`).

```bash
mkdir -p /tmp/kern-subscriber/force-app
cat > /tmp/kern-subscriber/sfdx-project.json << 'TMPEOF'
{"packageDirectories":[{"path":"force-app","default":true}],"name":"KernSubscriber","sourceApiVersion":"67.0"}
TMPEOF
cat > /tmp/kern-subscriber/.forceignore << 'TMPEOF'
# Jest specs are not deployable LWC bundle content
**/__tests__/**
TMPEOF
cd /tmp/kern-subscriber && sf org create scratch \
  -f <repo-root>/config/project-scratch-def.json \
  -a ${SF_SUBSCRIBER_ORG_ALIAS} -v DevHub -y 30 --wait 10
```

Without the `.forceignore`, any harness LWC bundle that ships Jest specs (e.g. `accountCard/__tests__/`) deploys the
spec as component code and fails compile with `LWC1702: Invalid LWC imported identifier "createElement"`.

### 1.3 Install Package

```bash
sf package install -o $SF_SUBSCRIBER_ORG_ALIAS --package <SubscriberPackageVersionId> --wait 15 --no-prompt
```

### 1.4 Deploy Subscriber Test Artifacts

```bash
cd <repo-root>

mkdir -p /tmp/kern-subscriber/force-app/main/default/{classes,triggers,customMetadata,customPermissions,cachePartitions,layouts,labels,flows,objects,platformEventChannels,platformEventChannelMembers}
cp release-testing/subscriber/classes/*.cls release-testing/subscriber/classes/*.cls-meta.xml \
  /tmp/kern-subscriber/force-app/main/default/classes/
cp release-testing/subscriber/classes/*.trigger release-testing/subscriber/classes/*.trigger-meta.xml \
  /tmp/kern-subscriber/force-app/main/default/triggers/
cp release-testing/subscriber/customMetadata/* /tmp/kern-subscriber/force-app/main/default/customMetadata/
cp release-testing/subscriber/customPermissions/* /tmp/kern-subscriber/force-app/main/default/customPermissions/
cp release-testing/subscriber/cachePartitions/* /tmp/kern-subscriber/force-app/main/default/cachePartitions/
cp release-testing/subscriber/layouts/* /tmp/kern-subscriber/force-app/main/default/layouts/
cp release-testing/subscriber/flows/* /tmp/kern-subscriber/force-app/main/default/flows/
cp -r release-testing/subscriber/objects/* /tmp/kern-subscriber/force-app/main/default/objects/
cp release-testing/subscriber/platformEventChannels/* /tmp/kern-subscriber/force-app/main/default/platformEventChannels/
cp release-testing/subscriber/platformEventChannelMembers/* /tmp/kern-subscriber/force-app/main/default/platformEventChannelMembers/
cp release-testing/subscriber/labels/* /tmp/kern-subscriber/force-app/main/default/labels/
```

Without the `labels/` copy, any harness LWC that imports a custom label (e.g. `accountCard` imports
`c.AccountCard_LoadFailed`) fails the deploy with `Invalid reference ... of type label`.

Deploy LWC, FlexiPages, tabs, and permission sets:

```bash
mkdir -p /tmp/kern-subscriber/force-app/main/default/{lwc,flexipages,tabs,permissionsets}
cp -r release-testing/subscriber/lwc/* /tmp/kern-subscriber/force-app/main/default/lwc/
cp release-testing/subscriber/flexipages/* /tmp/kern-subscriber/force-app/main/default/flexipages/
cp release-testing/subscriber/tabs/* /tmp/kern-subscriber/force-app/main/default/tabs/
cp release-testing/subscriber/permissionsets/* /tmp/kern-subscriber/force-app/main/default/permissionsets/
```

Generate CSP Trusted Site for the scratch org domain:

```bash
ORG_URL=$(sf org display -o $SF_SUBSCRIBER_ORG_ALIAS --json | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['instanceUrl'])")
mkdir -p /tmp/kern-subscriber/force-app/main/default/cspTrustedSites
cat > /tmp/kern-subscriber/force-app/main/default/cspTrustedSites/${SF_SUBSCRIBER_ORG_ALIAS}.cspTrustedSite-meta.xml << XMLEOF
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
```

Clear source tracking and deploy:

```bash
rm -rf /tmp/kern-subscriber/.sf/orgs
cd /tmp/kern-subscriber && sf project deploy start -o $SF_SUBSCRIBER_ORG_ALIAS -d force-app/main/default --ignore-conflicts
cd <repo-root>
```

Assign permission sets to the admin user:

```bash
sf org assign permset -o $SF_SUBSCRIBER_ORG_ALIAS -n SubscriberTestAccess
```

**Do NOT assign `StrictValidationAccess` here.** It enables the `EnableStrictValidation` feature flag which activates the
`AccountStrictValidation` rule group, causing sections 4-6 to fail with "Rating is required in strict mode". Section 22's
setup/cleanup scripts manage this permission set when needed.

**Data Masking Advisor tab (Phase-3 `part9` e2e):** The `kern__DataMaskingAdvisor` tab and its FlexiPage ship inside the
managed package — they install with §1.3 and need no separate deploy. `SubscriberTestAccess` grants the test user
visibility of that tab, so the `part9` advisor e2e (which navigates to `/lightning/n/kern__DataMaskingAdvisor`) resolves
on the subscriber. `SubscriberTestAccess` also grants field-level security on the `SubscriberCdcProbe__c` and
`SubscriberCdcMarker__c` fields so the CDC sections (71-72) can read the recorded change-event markers.

**Log Console tab (Phase-3 `part10` e2e):** The `kern__LogConsole` tab and its FlexiPage also ship inside the managed
package. `SubscriberTestAccess` grants the test user visibility of that tab (same pattern as the advisor tab), so
`part10` — which navigates to `/lightning/n/kern__LogConsole`, launches the Kern Home tile, and drives the Chain
Monitor "View logs" cross-link — resolves on the subscriber.

**Audit-field back-dating (Phase-3 `part10` prerequisite):** The Log Console e2e seed
(`release-testing/scripts/seed-log-console.apex`) back-dates `CreatedDate`/`LastModifiedDate` so the date-range checks
have rows spread across every window. A fresh scratch org silently ignores back-dated audit fields until BOTH steps
below are applied — **in this order, as two separate deploys** (deploying them together fails silently):

```bash
sf project deploy start --metadata-dir release-testing/e2e/fixtures/audit-fields/step1-security-settings/metadata -o $SF_SUBSCRIBER_ORG_ALIAS
sf project deploy start --metadata-dir release-testing/e2e/fixtures/audit-fields/step2-audit-permset/metadata -o $SF_SUBSCRIBER_ORG_ALIAS
sf org assign permset -o $SF_SUBSCRIBER_ORG_ALIAS -n KernE2EAuditFieldAccess
```

The seed probes its own back-dating and reports `auditBackdate=OK` or `auditBackdate=FAILED_ENABLE_AUDIT_FIELDS` in its
debug output; `part10`'s date-range check (V108) hard-fails on the latter with a pointer back to this recipe. The
`CreateAuditFields` permission alone is NOT sufficient, and neither step is available as a Setup UI toggle.

Verify post-install configuration:

```bash
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f /dev/stdin <<< "
Boolean org = kern.UTIL_Cache.isOrgAllocated();
Boolean session = kern.UTIL_Cache.isSessionAllocated();
String orgUrl = Url.getOrgDomainUrl().toExternalForm();
List<CspTrustedSite> sites = [SELECT Id FROM CspTrustedSite WHERE IsActive = true AND EndpointUrl = :orgUrl];
System.debug('Org Cache: ' + org + ' | Session Cache: ' + session + ' | Trusted Site: ' + !sites.isEmpty());
" 2>&1 | grep USER_DEBUG
```

All three Health Check indicators should show `true`.

---

## Phase 2 — Automated Tests

### 2.1 Anonymous Apex Scripts

Run each script sequentially against the org named by `SF_SUBSCRIBER_ORG_ALIAS`. Each outputs `PASS`/`FAIL` via `System.debug`.
Filter output with: `sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f <script> 2>&1 | grep 'USER_DEBUG'`

**Sections with pre-conditions beyond a vanilla subscriber scratch org:**

- **Section 33** requires a **Knowledge-enabled** subscriber scratch org and pre-published Knowledge articles with assigned data categories —
  see [Knowledge Org Setup](#knowledge-org-setup) below for the full enablement recipe (use `config/km-scratch-def.json` instead of the standard scratch def, then deploy Knowledge
  settings + data category groups before running Phase 2). If your subscriber org doesn't have Knowledge enabled, skip Section 33; the rest of Phase 2 is unaffected.
- **Sections 3, 11, 22, 27, 35, 42, 43** require CMDT state changes (fixture deploys) between runs — see the per-section notes immediately after the table.

| #   | Script                                                                        | Description                                                                                                                                                                                                                                                                                                                               | Expected |
|-----|-------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------|
| 1   | `release-testing/scripts/section-1-trigger-lifecycle.apex`                    | Trigger handler lifecycle                                                                                                                                                                                                                                                                                                                 | 5/5      |
| 2   | `release-testing/scripts/section-2-trigger-bypass.apex`                       | Trigger bypass mechanisms                                                                                                                                                                                                                                                                                                                 | 6/6      |
| 3   | `release-testing/scripts/section-3-trigger-feature-flags.apex`                | Trigger + feature flags (requires CMDT state changes)                                                                                                                                                                                                                                                                                     | 8/8      |
| 4   | `release-testing/scripts/section-4-validation-lifecycle.apex`                 | Validation rule lifecycle                                                                                                                                                                                                                                                                                                                 | 6/6      |
| 5   | `release-testing/scripts/section-5-validation-bypass.apex`                    | Validation bypass                                                                                                                                                                                                                                                                                                                         | 8/8      |
| 6   | `release-testing/scripts/section-6-complex-formulas.apex`                     | Complex validation formulas                                                                                                                                                                                                                                                                                                               | 7/7      |
| 7   | `release-testing/scripts/section-7-outbound-api.apex`                         | Outbound API                                                                                                                                                                                                                                                                                                                              | 4/4      |
| 8   | `release-testing/scripts/section-8-api-feature-flags.apex`                    | API feature flags                                                                                                                                                                                                                                                                                                                         | 5/5      |
| 9   | `release-testing/scripts/section-9-cross-framework.apex`                      | Cross-framework integration                                                                                                                                                                                                                                                                                                               | 6/6      |
| 10  | `release-testing/scripts/section-10-shadow-mode.apex`                         | Shadow mode                                                                                                                                                                                                                                                                                                                               | 5/5      |
| 11  | `release-testing/scripts/section-11-execution-strategies.apex`                | Execution strategies (requires CMDT deployments)                                                                                                                                                                                                                                                                                          | 8/8      |
| 12  | `release-testing/scripts/section-12-after-triggers.apex`                      | After triggers                                                                                                                                                                                                                                                                                                                            | 6/6      |
| 13  | `release-testing/scripts/section-13-inbound-api.apex`                         | Inbound API                                                                                                                                                                                                                                                                                                                               | 6/6      |
| 14  | `release-testing/scripts/section-14-dml-builder.apex`                         | DML Builder                                                                                                                                                                                                                                                                                                                               | 6/6      |
| 15  | `release-testing/scripts/section-15-qry-builder.apex`                         | QRY Builder                                                                                                                                                                                                                                                                                                                               | 10/10    |
| 16  | `release-testing/scripts/section-16-log-builder.apex`                         | LOG Builder                                                                                                                                                                                                                                                                                                                               | 9/9      |
| 17  | `release-testing/scripts/section-17-flow-invocables.apex`                     | Flow invocables                                                                                                                                                                                                                                                                                                                           | 8/8      |
| 19  | `release-testing/scripts/section-19-lwc-logger-persistence.apex`              | LWC logger persistence                                                                                                                                                                                                                                                                                                                    | 6/6      |
| 20  | `release-testing/scripts/section-20-flow-logger.apex`                         | Flow logger                                                                                                                                                                                                                                                                                                                               | 7/7      |
| 21  | `release-testing/scripts/section-21-scheduler.apex`                           | Scheduler framework                                                                                                                                                                                                                                                                                                                       | 8/8      |
| 22  | `release-testing/scripts/section-22-*.apex`                                   | Advanced strategies (Custom Permission flags, Fail Fast + flag-gated groups)                                                                                                                                                                                                                                                              | 8/8      |
| 23  | `release-testing/scripts/section-23-trigger-action-ordering.apex`             | Trigger action ordering + feature flag fix verification                                                                                                                                                                                                                                                                                   | 4/4      |
| 24  | `release-testing/scripts/section-24-delegation-overrides.apex`                | Delegation mode caller overrides                                                                                                                                                                                                                                                                                                          | 5/5      |
| 25  | `release-testing/scripts/section-25-scheduler-timezone.apex`                  | Scheduler timezone awareness                                                                                                                                                                                                                                                                                                              | 4/4      |
| 26  | `release-testing/scripts/section-26-log-correlation.apex`                     | Log correlation — end-to-end traceability                                                                                                                                                                                                                                                                                                 | 7/7      |
| 27  | `release-testing/scripts/section-27-mock-selection.apex`                      | Multi-mock selection — priority, pattern, catch-all                                                                                                                                                                                                                                                                                       | 8/8      |
| 28  | `release-testing/scripts/section-28-util-cache.apex`                          | UTIL_Cache — platform cache from subscriber                                                                                                                                                                                                                                                                                               | 7/7      |
| 29  | `release-testing/scripts/section-29-log-scope.apex`                           | LOG_Builder.scope() — scoped logging                                                                                                                                                                                                                                                                                                      | 5/5      |
| 30  | `release-testing/scripts/section-30-resilience-strategies.apex`               | Circuit breaker state machine & retry backoff math                                                                                                                                                                                                                                                                                        | 10/10    |
| 31  | `release-testing/scripts/section-31-failure-handling.apex`                    | Failure handling, retry persistence, failure rate injection, ApiIssue logging                                                                                                                                                                                                                                                             | 8/8      |
| 32  | `release-testing/scripts/section-32-load-test.js`                             | Circuit breaker load test — parallel HTTP via Node (not Apex)                                                                                                                                                                                                                                                                             | 5/5      |
| 33  | `release-testing/scripts/section-33-knowledge-data-category.apex`             | Knowledge WITH DATA CATEGORY queries (requires Knowledge org)                                                                                                                                                                                                                                                                             | 5/5      |
| 34  | `release-testing/scripts/section-34-async-chain.apex`                         | Async chain orchestration (DML, context flow, handlers, callout isolation)                                                                                                                                                                                                                                                                | 9/9      |
| 35  | `release-testing/scripts/section-35-secure-by-default.apex`                   | Secure-by-default USER_MODE posture (flag state, QRY + DML defaults, overrides, systemModeRequired hook)                                                                                                                                                                                                                                  | 8/8      |
| 35  | `release-testing/scripts/section-35-kill-switch.apex`                         | Secure-by-default kill switch (both flags off → SYSTEM_MODE fallback)                                                                                                                                                                                                                                                                     | 4/4      |
| 36  | `release-testing/scripts/section-36-masking-applicable-field-types.apex`      | Masking `ApplicableFieldTypes__c` narrowing — rule skips fields whose DisplayType is outside the list                                                                                                                                                                                                                                     | 4/4      |
| 37  | `release-testing/scripts/section-37-masking-min-input-length.apex`            | Masking `MinInputLength__c` short-circuit + successor-floor probe — sub-13 values skip pattern eval; a 13-digit Luhn-valid card redacts via `MaskPaymentCard` (the old rule's floor of 15 would have skipped it)                                                                                                                          | 3/3      |
| 38  | `release-testing/scripts/section-38-masking-transactionid-preservation.apex`  | Regression guard for the original parent-transaction-ID false-redaction bug (Luhn checksum gate)                                                                                                                                                                                                                                          | 3/3      |
| 39  | `release-testing/scripts/section-39-masking-type-filter-warn.apex`            | Explicit-field `MaskingTarget__mdt` dropped by type filter emits a one-time warn LogEntry (P12)                                                                                                                                                                                                                                           | 2/2      |
| 40  | `release-testing/scripts/section-40-masking-inactive-rule-validation.apex`    | Every shipped masking rule's `Pattern__c` compiles + matches a curated positive + negative sample (active + inactive)                                                                                                                                                                                                                     | 45/45    |
| 41  | `release-testing/scripts/section-41-flow-action-subscriber.apex`              | Cross-namespace `kern__TRG_InvokeFlow` dispatch — flow runs, output applied, LogAndContinue, recursion-identity, mock harness, variable contract                                                                                                                                                                                          | 6/6      |
| 42  | `release-testing/scripts/section-42-flow-action-blockdml.apex`                | `FailureAction__c = BlockDml` halts DML when bound flow throws (requires `section-flow-blockdml-active` fixture before; restore via `section-flow-blockdml-default`)                                                                                                                                                                      | 1/1      |
| 43  | `release-testing/scripts/section-43-flow-action-feature-flag.apex`            | `RequiredFeatureFlag__c` gating disables flow action when flag is off (requires `section-flow-flag-disabled` fixture before; restore via `section-flow-flag-default`)                                                                                                                                                                     | 1/1      |
| 44  | `release-testing/scripts/section-44-flow-action-upgrade.apex`                 | Managed-package upgrade compatibility — pre-existing Apex-only `TriggerAction__mdt` rows still resolve after the new flow fields land                                                                                                                                                                                                     | 3/3      |
| 44  | `release-testing/scripts/section-44-load-masker.apex`                         | Load test — `UTIL_FrameworkMasker` bulk: 200 `ApiCall__c` records via `TRG_Dispatcher` inline masking pre-step (emits `PERF_ROW`)                                                                                                                                                                                                         | 2/2      |
| 45  | `release-testing/scripts/section-45-load-qry-aggregate.apex`                  | Load test — `QRY_Builder` aggregate cardinality: GROUP BY + ROLLUP across high-row counts (emits `PERF_ROW`)                                                                                                                                                                                                                              | 2/2      |
| 46  | `release-testing/scripts/section-46-load-trigger-fanout.apex`                 | Load test — `TRG_Dispatcher` fan-out + per-action filter under bulk DML (emits `PERF_ROW`)                                                                                                                                                                                                                                                | 2/2      |
| 47  | `release-testing/scripts/section-47-load-validation-bulk.apex`                | Load test — `UTIL_ValidationRule.executeForTrigger()` bulk: high-row validation group evaluation (emits `PERF_ROW`)                                                                                                                                                                                                                       | 2/2      |
| 48  | `release-testing/scripts/section-48-load-async-chain-ser.apex`                | Load test — `UTIL_AsyncChain` context serialization launch: enqueues a multi-step chain with large shared context (emits `PERF_ROW`)                                                                                                                                                                                                      | 1/1      |
| 48b | `release-testing/scripts/section-48b-load-async-chain-ser-verify.apex`        | Verify — chain from section 48 completed successfully (query `AsyncApexJob`)                                                                                                                                                                                                                                                              | 1/1      |
| 49  | `release-testing/scripts/section-49-load-async-launcher.apex`                 | Load test — `UTIL_AsynchronousJobLauncher` Queueable/Batch: enqueues multiple async jobs in burst (emits `PERF_ROW`)                                                                                                                                                                                                                      | 1/1      |
| 49b | `release-testing/scripts/section-49b-load-async-launcher-verify.apex`         | Verify — async jobs from section 49 completed successfully                                                                                                                                                                                                                                                                                | 1/1      |
| 50  | `release-testing/scripts/section-50-load-logger-pe-quota.apex`                | Load test — Logger platform event quota: emits ≥150 `LogEntryEvent__e` in one transaction using `LOG_Builder.scope()` (emits `PERF_ROW`)                                                                                                                                                                                                  | 1/1      |
| 50b | `release-testing/scripts/section-50b-load-logger-pe-quota-verify.apex`        | Verify — `LogEntry__c` records from section 50 persisted (polls with delay)                                                                                                                                                                                                                                                               | 1/1      |
| 51  | `release-testing/scripts/section-51-load-callout-storm.js`                    | Load test — `UTIL_HttpClient` callout storm: parallel HTTP via Node.js against `REST_LoadProbe` (emits `PERF_ROW`)                                                                                                                                                                                                                        | 5/5      |
| 52  | `release-testing/scripts/section-52-edge-dml-builder.apex`                    | Edge cases — `DML_Builder`: partial-save flag, parent-child chain, mixed DML types, error aggregation                                                                                                                                                                                                                                     | 6/6      |
| 53  | `release-testing/scripts/section-53-edge-qry-builder.apex`                    | Edge cases — `QRY_Builder`: semi-join subqueries, NOT IN, pagination, field set, scope, all rows, for update                                                                                                                                                                                                                              | 7/7      |
| 54  | `release-testing/scripts/section-54-edge-inbound-api.apex`                    | Edge cases — inbound API: duplicate headers, malformed JSON body, validation-phase abort, missing required fields                                                                                                                                                                                                                         | 5/5      |
| 55  | `release-testing/scripts/section-55-edge-outbound-failure.apex`               | Edge cases — outbound API failure composition: circuit breaker open → abort, retry exhaustion, failure rate injection                                                                                                                                                                                                                     | 5/5      |
| 56  | `release-testing/scripts/section-56-edge-async-chain.apex`                    | Edge cases — `UTIL_AsyncChain`: `continueOnError`, max-steps guard, error handler context, correlation ID threading (Launch)                                                                                                                                                                                                              | 1/1      |
| 56b | `release-testing/scripts/section-56b-edge-async-chain-verify.apex`            | Verify — chain from section 56 completed (checks error handler ran + step count correct)                                                                                                                                                                                                                                                  | 3/3      |
| 57  | `release-testing/scripts/section-57-edge-cache-ttl.apex`                      | Edge cases — `UTIL_Cache`: TTL expiry, missing partition graceful fallback, `AUTO` mode selection                                                                                                                                                                                                                                         | 5/5      |
| 58  | `release-testing/scripts/section-58-edge-logger.apex`                         | Edge cases — `LOG_Builder`: scope batching, context chain, forRecord, summary, multi-level, PE governor limit                                                                                                                                                                                                                             | 6/6      |
| 59  | `release-testing/scripts/section-59-edge-scheduler.apex`                      | Edge cases — `SCHED_Base`: missing required parameter, type mismatch, default value fallback, cron expression building                                                                                                                                                                                                                    | 5/5      |
| 60  | `release-testing/scripts/section-60-edge-mock-regex.apex`                     | Edge cases — `API_MockFactory` + `API_MockMatcher`: regex mode priority, catch-all, pattern specificity ordering                                                                                                                                                                                                                          | 5/5      |
| 61  | `release-testing/scripts/section-61-edge-masking-rollback.apex`               | Edge cases — `UTIL_FrameworkMasker`: DML rollback isolation (masking log survives rolled-back DML), field-length, idempotency                                                                                                                                                                                                             | 5/5      |
| 62  | `release-testing/scripts/section-62-edge-type-resolver.apex`                  | Edge cases — `UTIL_TypeResolver`: interface mismatch error, `Order__c` ties, subscriber-first resolution, missing class                                                                                                                                                                                                                   | 5/5      |
| 63  | `release-testing/scripts/section-63-edge-resilience-comp.apex`                | Edge cases — `UTIL_CircuitBreaker` + `UTIL_Retry` composition: retry feeds into open breaker, exponential backoff math                                                                                                                                                                                                                    | 5/5      |
| 64  | `release-testing/scripts/section-64-edge-asyncjob-launcher.apex`              | Edge cases — `UTIL_AsynchronousJobLauncher`: max concurrent guard, re-enqueue after failure, job type selection (Launch)                                                                                                                                                                                                                  | 1/1      |
| 65  | `release-testing/scripts/section-65-bypass-audit-framework-wide.apex`         | Framework-wide bypass audit — bypass events persist to `kern__LogEntry__c` from trigger / query / DML / validation surfaces; query/DML entries carry object-qualified targets (`system-mode:Account` / `sharing:Account`) with `object`/`operation`/`rowCount` context naming the operation that ran under the bypass; `BypassAudit_Enabled` kill-switch is default-on; flood-control detail/rollup shape. Orchestrated: the audit trail persists asynchronously, so a single-transaction script raced platform-event delivery (launch 65 (2) + 30s persistence wait + verify 65b (6)); see "Section 65 notes" | 8/8      |
| 66  | `release-testing/scripts/section-66-log-fingerprint.apex`                     | Log-fingerprint flood control (subscriber API) — `kern.LOG_Builder...withFingerprint(key)` collapses repeated entries into one `detail:` sample row + a per-UTC-day `rollup:` counter (`OccurrenceCount__c`); covers flood economy (5 → 2 rows), distinct keys, oversized-key SHA-256 hashing + `fingerprintSource` breadcrumb, reserved-prefix anti-spoofing, and the plain-entry opt-in regression (launch 66 + verify 66b); see "Section 66 notes"                       | 10/10    |
| 67  | `release-testing/scripts/section-67-post-trigger-actions.apex`                | Post-trigger actions — core behaviour: fires once per dispatch (not per record), `Order__c` ascending, touched-SObject context, object-scope filter (Foobar dispatch), entry-criteria skip                                                                                                                                                | 6/6      |
| 68  | `release-testing/scripts/section-68-post-trigger-actions-flag-gate.apex`      | Post-trigger actions — `RequiredFeatureFlag__c` gate: dormant when off (68), fires when on (68b)                                                                                                                                                                                                                                          | 2/2      |
| 69  | `release-testing/scripts/section-69-post-trigger-actions-no-dml.apex`         | Post-trigger actions — no-DML contract guard: exception names synchronous DML + the offending action class, originating DML rolls back                                                                                                                                                                                                    | 2/2      |
| 70  | `release-testing/scripts/section-70-post-trigger-actions-failure-policy.apex` | Post-trigger actions — `FailureAction__c` policy: LogAndContinue commits + swallows (70), BlockDml rolls back + surfaces the exception (70b)                                                                                                                                                                                              | 4/4      |
| 71  | `release-testing/scripts/section-71-cdc-header-recorder.apex`                 | CDC change-event header recorder — probe inserts deliver change events; the recorder Flow receives the typed `DTO_ChangeEventHeader` and the sink records one marker per delivered event; record ids audited back to the source probes (launch 71 + verify 71b)                                                                           | 3/3      |
| 72  | `release-testing/scripts/section-72-cdc-blockdml-degrade.apex`                | CDC BlockDml degrade — on a change-event dispatch the `BlockDml` failure action degrades to LogAndContinue (a committed change cannot be rolled back): a WARN log records the degrade-exclusive `cdc-block-dml-degraded` errorKind (the proof), and the Order-10 recorder co-action + the source rows are intact (launch 72 + verify 72b) | 4/4      |
| 75  | `release-testing/scripts/section-75-queueable-unhandled-exception.apex`       | Queueable unhandled-exception surfacing — a global async step launched via `kern.UTIL_AsynchronousJobLauncher.process(...)` that throws uncaught surfaces as a Failed `AsyncApexJob` with the exception identity preserved in `ExtendedStatus` (launch 75 + verify 75b); see "Section 75 notes"                                           | 3/3      |
| 76  | `release-testing/scripts/section-76-masking-advisor-roundtrip.apex`           | Masking advisor round-trip baseline — namespace-safe CMDT + dynamic key-prefix resolution, shipped rule catalogue, posture baseline (the Health Check masking inputs: Pass(4))                                                                                                                                                            | 3/3      |
| 76b | `release-testing/scripts/section-76b-masking-advisor-verify-created.apex`     | Verify — advisor-format create bundle: probe targets re-read field-for-field (packaged-rule references resolve), posture recomputes to 5 objects / 1 dead → Health Check input flips to Warn; the packaged MaskPhoneUS rule is activated via its namespace-qualified record name (rule-activation round-trip)                             | 3/3      |
| 76c | `release-testing/scripts/section-76c-masking-advisor-verify-disabled.apex`    | Verify — disable bundle: probes persist inactive (disable IS the advisor's removal story), MaskPhoneUS dormant again, posture back to Pass(4); re-run once more as the cleanup verification                                                                                                                                               | 3/3      |
| 76d | `release-testing/scripts/section-76d-masking-advisor-verify-reenabled.apex`   | Verify — re-enable bundle: healthy probe active again (dead probe + MaskPhoneUS untouched → bundle-scoped upserts), posture Pass(5) — the PASS-branch Health Check value change                                                                                                                                                           | 2/2      |
| 77  | `release-testing/scripts/section-77-masking-cmdt-collision.apex`              | Masking CMDT name-collision tolerance — an org-local clone of a packaged rule's DeveloperName (seeded by the runner) must NOT brick framework DML: inserts survive on the engine's fallback read and mask identically; after the clone is deleted the fast path resumes and the collision WARN (`detail:masking:cmdt-collision:%`) has persisted (orchestrated: seeded 2 + recovered 3)                                                    | 5/5      |

**Section 65 forensic query** for subscribers grepping the audit channel — `kern__ContextData__c` is a
Long Text Area, which SOQL `LIKE` cannot filter, so pull a window and match client-side:

```sql
SELECT kern__ContextData__c, kern__Message__c, kern__ClassMethod__c, CreatedDate, kern__UserId__c
FROM kern__LogEntry__c
WHERE CreatedDate = LAST_N_DAYS:7
AND kern__UserId__c = '<the user under investigation>'
ORDER BY CreatedDate DESC LIMIT 200
```

Match `'"category":"BypassEvent"'` in `kern__ContextData__c` client-side, then scope by surface
(`'"surface":"query"'`, `'"surface":"dml"'`, `'"surface":"validation"'`, `'"surface":"trigger-object"'`,
`'"surface":"trigger-action"'`, `'"surface":"reason-latch"'`) or by object-qualified target
(`'"target":"system-mode:Account"'`, `'"target":"sharing:Account"'`) to find which object a query or DML
operation ran against under the bypass; the `object`/`operation`/`rowCount` context keys name the
suppressed operation itself.

**Section 3 note:** Requires 4 CMDT state changes between runs (deploy State A → run → State B → run → etc.).
**Section 11 note:** Requires 2 CMDT deployments (Fail Fast → run → Accumulate → run).
**Section 22 note:** Run 3 scripts in order: `section-22-setup.apex` → `section-22-advanced-strategies.apex` → `section-22-cleanup.apex`.
Must run AFTER sections 4-6 (setup assigns `StrictValidationAccess` which adds strict validation rules).
**Section 26 note:** 7 PASS total (26a-26g). Tests 26f-26g query LogEntry__c for async platform event data — run AFTER sections 16-20
to ensure log entries exist. If 26f shows "No correlated entries found", wait a few seconds and re-run.
**Section 27 note:** Requires CMDT state changes: deploy `section27-mock-enabled` (sets `MockingEnabled__c = true` on
SubscriberCreateAccount and `IsEnabledByDefault__c = true` on MockAllAPIs), run script, then deploy `section27-mock-disabled`
to restore defaults.
**Section 33 note:** Requires a Knowledge-enabled subscriber scratch org. See [Knowledge Org Setup](#knowledge-org-setup)
below. Run `section-33-knowledge-setup.apex` first to create and publish test articles, then assign data categories
to articles before running the test script.

**Section 35 note:** Three-step flag-flip dance that proves secure-by-default is real end-to-end. Run
`section-35-secure-by-default.apex` against the shipped defaults (both `UserModeQueries_Enabled` and
`UserModeDml_Enabled` on). Then deploy `section35-flags-disabled` fixture
(`node release-testing/runner/cmdt-deployer.js section35-flags-disabled`) and run
`section-35-kill-switch.apex` to prove the emergency kill switch returns the framework to SYSTEM_MODE. Finally
deploy `section35-flags-default` to restore the shipped posture for the rest of Phase 2.

**Section 39 note:** Depends on the subscriber CMDT fixtures
`kern__MaskingRule.TestTypeFilterWarn` and `kern__MaskingTarget.TestTypeFilterWarnOnApiCallUrl` (both in
`release-testing/subscriber/customMetadata/`) being deployed as part of Phase 1.4. The rule scopes to
STRING;TEXTAREA with a never-match sentinel pattern and wires to `ApiCall__c.URL__c` (DisplayType URL) —
the type-filter mismatch is what the framework warns on. Using a dedicated test rule (instead of
MaskSecretKeys) because specific-field targets shadow rule-matched wildcards by rule+caller key — wiring a
specific target for a shipped rule would break that rule's masking on other fields.

**Section 76 note:** Orchestrated round-trip — the runner deploys advisor-format CMDT bundles from
`release-testing/e2e/fixtures/masking-advisor-bundles/` between scripts using the Data Masking Advisor
Export modal's own deploy command (`sf project deploy start --metadata-dir metadata -o <alias>`, run
project-free from the bundle root). Order: baseline → deploy `create` → verify (76b) → deploy `disable` →
verify (76c) → deploy `reenable` → verify (76d) → deploy `disable` again → re-verify (76c, cleanup).
The `create`/`disable` bundles also carry a packaged-rule **activation** (`kern__MaskingRule.kern__MaskPhoneUS`,
named for the namespace-qualified record) so the round-trip exercises the advisor's rule-activation path too:
76j proves the activation resolves to the shipped rule (not a phantom subscriber record), 76k/76h prove it
returns to dormant and that the `reenable` bundle — which omits it — leaves it untouched. 14 PASS total.
`npm run release:phase2` handles the whole dance (`runSection76`); manually:

```bash
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-76-masking-advisor-roundtrip.apex 2>&1 | grep USER_DEBUG
(cd release-testing/e2e/fixtures/masking-advisor-bundles/create && sf project deploy start --metadata-dir metadata -o $SF_SUBSCRIBER_ORG_ALIAS)
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-76b-masking-advisor-verify-created.apex 2>&1 | grep USER_DEBUG
(cd release-testing/e2e/fixtures/masking-advisor-bundles/disable && sf project deploy start --metadata-dir metadata -o $SF_SUBSCRIBER_ORG_ALIAS)
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-76c-masking-advisor-verify-disabled.apex 2>&1 | grep USER_DEBUG
(cd release-testing/e2e/fixtures/masking-advisor-bundles/reenable && sf project deploy start --metadata-dir metadata -o $SF_SUBSCRIBER_ORG_ALIAS)
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-76d-masking-advisor-verify-reenabled.apex 2>&1 | grep USER_DEBUG
(cd release-testing/e2e/fixtures/masking-advisor-bundles/disable && sf project deploy start --metadata-dir metadata -o $SF_SUBSCRIBER_ORG_ALIAS)
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-76c-masking-advisor-verify-disabled.apex 2>&1 | grep USER_DEBUG
```

The probe records persist disabled after cleanup (CustomMetadata deploys cannot delete) — the baseline
script asserts that steady state, keeping re-runs idempotent. Case is the probe object deliberately: no
shipped targets (the masked-object count moves 4↔5) and no Kern trigger configuration (an active probe
never changes runtime masking for other sections).

**Section 77 note:** Orchestrated collision-tolerance gate (model: section 66's launch/verify split — log
persistence is asynchronous through the platform-event pipeline, so the WARN emitted while the collision is
live is only queryable on the second invocation). The runner deploys `cmdt-states/collision-clone/` — an
org-local `MaskingRule` record named `MaskPaymentCard` with NO namespace prefix, exactly the state a
subscriber creates by cloning a shipped rule in Setup — runs the script (77a/77b: framework inserts survive
on the engine's fallback read and mask identically; the seeded invocation also purges collision-WARN rows
from previous runs so 77c proves THIS run's emission), deletes the clone, waits 30s for log-event
persistence, and re-runs the script (77a/77b on the restored fast path + 77c: the persisted collision
WARN). Against any build WITHOUT the engine fallback the seeded half fails with
`CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY … System.ListException: Row with duplicate DeveloperName` — that red
run is this gate's reason to exist. Runs LAST among the orchestrated sections so the deliberately degraded
state never overlaps another section's window; if the runner aborts mid-section, delete the clone manually
(step 3 below) before anything else touches the org. `npm run release:phase2` handles the dance
(`runSection77`); manually:

```bash
node release-testing/runner/cmdt-deployer.js collision-clone
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-77-masking-cmdt-collision.apex 2>&1 | grep USER_DEBUG
(cd ~/.kern-cmdt-staging && sf project delete source -o $SF_SUBSCRIBER_ORG_ALIAS -m "CustomMetadata:kern__MaskingRule.MaskPaymentCard" --no-prompt)
sleep 30
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-77-masking-cmdt-collision.apex 2>&1 | grep USER_DEBUG
```

**Section 67-70 notes (post-trigger actions):** Serial CMDT-state-fixture sections (model: sections 42/43)
gated behind `RequiredFeatureFlag__c = EnablePostActionReleaseTest`, which ships OFF so the release-test
post-actions stay dormant during the parallel pool (sections 1-64). The base CMDT
(`kern__PostTriggerAction.TST_PostAction*` + `kern__FeatureFlag.EnablePostActionReleaseTest`) and the six
`TST_PostAction*` subscriber classes deploy as part of Phase 1.4; the Dml/Failing rows additionally ship
`BypassExecution__c = true` so only their own fixture activates them. The Account-scoped post-actions fire
on Account DML; the object-scope filter is proven by inserting `kern__Foobar__c` (the packaged `TRG_Foobar`
dispatches through the framework but never marks Account as touched). `npm run release:phase2` handles the
fixture cycle (`runSection67`-`runSection70`); manually:

```bash
# 67 — core behaviour (ordering, dispatch-scope, touched types, object-scope filter, entry-criteria)
node release-testing/runner/cmdt-deployer.js postaction-enabled
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-67-post-trigger-actions.apex 2>&1 | grep USER_DEBUG
node release-testing/runner/cmdt-deployer.js postaction-disabled
# 68 — required-feature-flag gate (off leg, then on leg)
node release-testing/runner/cmdt-deployer.js postaction-disabled
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-68-post-trigger-actions-flag-gate.apex 2>&1 | grep USER_DEBUG
node release-testing/runner/cmdt-deployer.js postaction-enabled
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-68b-post-trigger-actions-flag-gate.apex 2>&1 | grep USER_DEBUG
node release-testing/runner/cmdt-deployer.js postaction-disabled
# 69 — no-DML contract guard
node release-testing/runner/cmdt-deployer.js dml-active
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-69-post-trigger-actions-no-dml.apex 2>&1 | grep USER_DEBUG
node release-testing/runner/cmdt-deployer.js postaction-disabled
# 70 — failure-action policy (LogAndContinue leg, then BlockDml leg)
node release-testing/runner/cmdt-deployer.js failing-logandcontinue
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-70-post-trigger-actions-failure-policy.apex 2>&1 | grep USER_DEBUG
node release-testing/runner/cmdt-deployer.js failing-blockdml
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-70b-post-trigger-actions-failure-policy.apex 2>&1 | grep USER_DEBUG
node release-testing/runner/cmdt-deployer.js postaction-disabled
```

**Section 71-72 notes (CDC change-event header):** Launch + verify sections (model: sections 34/56) gated behind
`RequiredFeatureFlag__c = EnableCdcHeaderReleaseTest`, which ships OFF so the CDC actions stay dormant during the
parallel pool. The CDC foundation — the `SubscriberCdcProbe__c` object (selected for Change Data Capture on the standard
`ChangeEvents` channel plus the `SubscriberCdcProbe__chn` custom channel), the non-CDC `SubscriberCdcMarker__c` sink
object, `TRG_SubscriberCdcProbeChangeEvent`, `TST_SubscriberFlow_CdcHeaderRecorder`, `TST_SubscriberFlow_CdcAlwaysFail`,
`TST_CdcHeaderSink`, the `kern__TriggerSetting.SubscriberCdcProbeChangeEvent` setting (registered via
`ObjectApiNameOverride__c`), the gated `SubscriberCdcProbe_Recorder` + `SubscriberCdcProbe_BlockDmlDegrade` actions, and
`kern__FeatureFlag.EnableCdcHeaderReleaseTest` — deploys as part of Phase 1.4, and `SubscriberTestAccess` grants
field-level security on the probe + marker fields. Apex change-event triggers fire only for entities selected on the
standard `ChangeEvents` channel (a custom channel alone reaches streaming subscribers, not Apex), so the standard-channel
member is the enabler. If the Phase-1.4 deploy ever fails to compile `TRG_SubscriberCdcProbeChangeEvent`
("Invalid type: SubscriberCdcProbe__ChangeEvent"), deploy `objects/` + `platformEventChannels/` +
`platformEventChannelMembers/` first so the change-event entity exists, then re-run the full deploy. Change events
deliver asynchronously after the inserting transaction commits, so each section splits into a launch (insert probes) and
a verify (assert the delivered markers ~30s later). `npm run release:phase2` handles the fixture cycle
(`runSection71`/`runSection72`); manually:

```bash
# 71 — change-event header recorder (launch, wait ~30s, verify)
node release-testing/runner/cmdt-deployer.js cdc-header-enabled
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-71-cdc-header-recorder.apex 2>&1 | grep USER_DEBUG
sleep 30
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-71b-cdc-header-verify.apex 2>&1 | grep USER_DEBUG
node release-testing/runner/cmdt-deployer.js cdc-header-disabled
# 72 — BlockDml degrade (launch, wait ~30s, verify)
node release-testing/runner/cmdt-deployer.js cdc-blockdml-degrade-active
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-72-cdc-blockdml-degrade.apex 2>&1 | grep USER_DEBUG
sleep 30
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-72b-cdc-blockdml-degrade-verify.apex 2>&1 | grep USER_DEBUG
node release-testing/runner/cmdt-deployer.js cdc-header-disabled
```

**Section 75 notes (queueable unhandled-exception surfacing):** A launch + verify section (model: sections
34/56) with **no CMDT fixture** — the throwing step (`TST_UnhandledThrowStep`, a `global` class implementing
`kern.IF_Async.Processable` that throws from `execute()`) is inert until explicitly launched, so it never bleeds
into the parallel pool. Section 75 enqueues it through `kern.UTIL_AsynchronousJobLauncher.process(...)`; the
queueable's uncaught exception leaves the job Failed with the exception captured in `AsyncApexJob.ExtendedStatus`,
and section 75b (after ~30s) asserts that Failed job carries the step's failure message. This guards the v67
queueable error path in `UTIL_AdaptiveAsynchronousProcessor` — a managed-subscriber async job that throws is
coverage @IsTest cannot reach (a queueable's unhandled exception in test context surfaces as a test failure, not
the real Finalizer/AsyncApexJob path).

> **Finalizer-log observation (validated build):** the framework Finalizer additionally calls
> `logUnhandledException`, which emits an ERROR `kern__LogEntry__c` via a PublishImmediately `LogEntryEvent__e`
> for the failed AsyncApexJob. On the validated subscriber build that finalizer-context log **did not persist** in
> real async execution, even though plain anonymous `LOG_Builder` emissions and synchronous trigger-error logs
> persist normally. Section 75 therefore asserts the reliable `AsyncApexJob` signal rather than the error log.
> Worth confirming whether the framework's queueable-error `LogEntry` is expected to persist in real subscriber
> async context.

`npm run release:phase2` handles the launch + 30s wait + verify (`runSection75`); manually:

```bash
# 75 — queueable unhandled-exception surfacing (launch, wait ~30s, verify)
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-75-queueable-unhandled-exception.apex 2>&1 | grep USER_DEBUG
sleep 30
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-75b-queueable-unhandled-exception-verify.apex 2>&1 | grep USER_DEBUG
```

**Section 65 notes (framework-wide bypass audit):** A launch + verify section (model: section 66) with
**no CMDT fixture**. Bypass audit entries persist asynchronously (`LogEntryEvent__e` → `TRG_PersistLogEntry`),
so emission and verification run in separate transactions — the old single-transaction form raced
platform-event delivery and was historically flaky inside the Phase 2 suite. Section 65 exercises the four
global bypass surfaces (trigger / query / DML / validation), checks the `BypassAudit_Enabled` kill-switch
synchronously, and persists a `Section65BypassAudit_<ms>` handoff row; section 65b reads the handoff ~30s
later and asserts the object-qualified audit shape. **The verify CONSUMES the handoff row** — after a failed
verify, re-launch section 65 before retrying. All anonymous Apex resolves to caller `AnonymousBlock`, so
bypass fingerprints collide across suite sections: a full-suite run typically yields a rollup-only window
for `dml|system-mode:Account` (section 35g emits the same identity earlier), in which case 65b/65d relax to
target/object presence — flood-control rollup bumps keep the FIRST occurrence's `operation`/`rowCount`
context, so those values are only asserted when the window holds a fresh `detail:bypass:` row for the key.

`npm run release:phase2` handles the launch + 30s wait + verify (`runSection65`); manually:

```bash
# 65 — framework-wide bypass audit (launch, wait ~30s, verify; verify consumes the handoff)
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-65-bypass-audit-framework-wide.apex 2>&1 | grep USER_DEBUG
sleep 30
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-65b-bypass-audit-verify.apex 2>&1 | grep USER_DEBUG
```

**Section 66 notes (log-fingerprint flood control — subscriber API):** A launch + verify section (model:
sections 34/50) with **no CMDT fixture**. Section 65 already proves the framework-internal consumer (bypass
audit, which subscribers cannot call directly); section 66 proves the documented **subscriber-facing** contract —
the global `kern.LOG_Builder.build()...withFingerprint(key)` API. `kern__LogEntry__c` rows are persisted
asynchronously by the `LogEntryEvent__e` subscriber (`TRG_PersistLogEntry`), which does not run until the
publishing transaction commits, so the work is split. Section 66 publishes 5 identical + 3 other fingerprinted
entries + 1 plain entry and persists a `Section66Fingerprint_<runStamp>` handoff row; section 66b (after ~30s)
reads the handoff and asserts the persisted shape: 5 occurrences collapse to **1 detail + 1 rollup**
(`OccurrenceCount__c = 5`), a distinct key gets its own rows, an oversized (>200-char) key is SHA-256 hashed with
the original recoverable via the `fingerprintSource` breadcrumb, a subscriber-supplied reserved `bypass:` key is
hashed (no verbatim `detail:bypass:` row — anti-spoofing), and a plain entry persists with blank `Fingerprint__c`.
Every key carries a per-run timestamp so concurrent / repeated runs never collide, and 66b deletes its rows +
handoff on completion.

`npm run release:phase2` handles the launch + 30s wait + verify (`runSection66`); manually:

```bash
# 66 — log-fingerprint flood control (launch, wait ~30s, verify)
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-66-log-fingerprint.apex 2>&1 | grep USER_DEBUG
sleep 30
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-66b-log-fingerprint-verify.apex 2>&1 | grep USER_DEBUG
```

**Section 41-44 notes (flow-as-trigger-action work):** Sections 41-44 share three subscriber flows
(`TST_SubscriberFlow_SetDefaults`, `TST_SubscriberFlow_AdditionalDefaults`, `TST_SubscriberFlow_AlwaysFail` —
all under `release-testing/subscriber/flows/`), four CMDT records (three TriggerAction rows + one FeatureFlag),
and four fixture states under `release-testing/e2e/fixtures/cmdt-states/section-flow-*/`. Run order:

```bash
# 41 — runs against shipped defaults (no fixture deploy needed)
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-41-flow-action-subscriber.apex 2>&1 | grep USER_DEBUG

# 42 — BlockDml (deploy active fixture, run, restore default)
node release-testing/runner/cmdt-deployer.js section-flow-blockdml-active
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-42-flow-action-blockdml.apex 2>&1 | grep USER_DEBUG
node release-testing/runner/cmdt-deployer.js section-flow-blockdml-default

# 43 — RequiredFeatureFlag gating (deploy disabled fixture, run, restore default)
node release-testing/runner/cmdt-deployer.js section-flow-flag-disabled
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-43-flow-action-feature-flag.apex 2>&1 | grep USER_DEBUG
node release-testing/runner/cmdt-deployer.js section-flow-flag-default

# 44 — runs against shipped defaults (no fixture deploy needed)
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-44-flow-action-upgrade.apex 2>&1 | grep USER_DEBUG
```

Plus the benchmark and scanner-self-test:

```bash
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/benchmark-flow-action.apex 2>&1 | grep USER_DEBUG
bash release-testing/scripts/test-flow-action-scanner.sh
```

The `TRG_InvokeFlow_SUBTEST` Apex test class lives in `release-testing/subscriber/classes/`; it runs as part
of the standard 2.2 test-class sweep.

**Sections 48/49/50 (async launch+verify pairs):** Run the launch script first, wait for async jobs to process (typically
5-30 s), then run the corresponding verify script (`*-verify.apex`). The verify scripts poll `AsyncApexJob` and
`LogEntry__c` — if they report 0 completed jobs, wait a few seconds and re-run.

**Section 51 note:** Node.js load test — requires credentials for the org named by `SF_SUBSCRIBER_ORG_ALIAS` accessible to the Salesforce CLI.
Run from the project root: `node release-testing/scripts/section-51-load-callout-storm.js`. The script authenticates
via `sf org display -o $SF_SUBSCRIBER_ORG_ALIAS --json` and fires parallel HTTP callouts against `REST_LoadProbe`.

**Section 56 (async chain edge, launch+verify):** Run `section-56-edge-async-chain.apex` first (enqueues the chain),
then run `section-56b-edge-async-chain-verify.apex` after async processing completes.

**Section 64 (AsyncJobLauncher edge, launch+verify):** Similar pattern — run `section-64-edge-asyncjob-launcher.apex`
to enqueue, wait for completion, then check results inline (verify queries embedded in same script via polling).

**Load test sections 44-51:** Each emits `PERF_ROW` lines to the debug log for the Phase 2.5 perf history harvester.
Capture the raw log file path if you intend to update baselines (see `release-testing/Testing Protocol.md` for the
`--logfile` flag). Behaviour assertions are the hard gate — timing warnings are advisory.

### Run a single load test in isolation

```bash
sf apex run --file release-testing/scripts/section-45-load-qry-aggregate.apex -o $SF_SUBSCRIBER_ORG_ALIAS
```

Each load script is self-contained (creates + tears down its own data). See `release-testing/Testing Protocol.md` for the
isolation guarantee, the `PERF_ROW` emission convention, and the per-baseline-update commands.

### 2.2 Test Classes

Run all subscriber test classes:

```bash
sf apex run test -o $SF_SUBSCRIBER_ORG_ALIAS --test-level RunLocalTests --result-format human --code-coverage
```

**Expected:** all subscriber test classes pass at 100% org-wide coverage. (The class/method totals are captured
during the full Phase-5 RunLocalTests run — the inline list below predates several `runAs` companions.) Newest this
cycle: `SubscriberPlatformEventAccessLevel_TEST` — 4 tests covering the v67 SYSTEM_MODE always-emit + USER_MODE
publish-enforcement platform-event AccessLevel guards (the runtime-enforcement layer the anonymous-Apex sections
16/65 cannot reach). Kern 1.1 reconciliation: 180 tests / 0 failures / 97% org-wide coverage.

Test classes deployed in `release-testing/subscriber/classes/`:
`AccountArchiveProcessor_TEST`, `API_ContactFormSubmit_TEST`, `API_GetPost_TEST`, `CTRL_SubscriberLwcTest_TEST`,
`REST_ContactForm_TEST`, `SCHED_SubscriberJob_TEST`, `SubscriberAsyncDml_TEST`, `SubscriberChainSteps_TEST`,
`SubscriberHttpClient_TEST`, `SubscriberMockSelection_TEST`, `SVC_AccountOnboarding_TEST`,
`SVC_AccountValidator_TEST`, `SVC_PricingCalculator_TEST`, `SubscriberMockPatterns_TEST`,
`SubscriberResilience_TEST`, `SubscriberPlatformEventAccessLevel_TEST`, `TRG_AccountHandlers_TEST`,
`TRG_InvokeFlow_SUBTEST`, `UTIL_AccountClassifier_TEST`,
`VAL_AccountRules_TEST`,
`FastStart_AsyncChain_DEMO_TEST`, `FastStart_DML_DEMO_TEST`, `FastStart_E2E_DEMO_TEST`,
`FastStart_FeatureFlag_DEMO_TEST`, `FastStart_InboundAPI_DEMO_TEST`, `FastStart_Logging_DEMO_TEST`,
`FastStart_OutboundAPI_DEMO_TEST`, `FastStart_Selectors_DEMO_TEST`, `FastStart_TestData_DEMO_TEST`,
`FastStart_TriggerAction_DEMO_TEST`, `FastStart_Validation_DEMO_TEST`

### 2.2b Managed Package Test Execution (subscriber context)

Run the package's own test suite inside the subscriber org. `RunLocalTests` excludes managed tests, so this is a
separate, mandatory gate:

```bash
sf apex run test -o $SF_SUBSCRIBER_ORG_ALIAS --test-level RunAllTestsInOrg --result-format human -w 60
```

**Expected:** zero failures across the entire run (local + managed; the managed portion was 3,724 tests at the start of
Kern 1.1 and the count grows with the package — the Kern 1.1.0-11 fresh leg ran 3,955 tests total at 100%). Managed-class
coverage percentages are not visible in a subscriber org; the gate is pass/fail only.

**Why this gate exists.** The subscriber org is a third execution context that neither the development org nor the
packaging build org can reproduce, and it has caught real defects the other two validated cleanly:

- **Stack-frame obfuscation:** managed-package stack frames collapse to a single `(namespace)` line in subscriber
  orgs, so any code or assertion that parses stack frames behaves differently than in the packaging org (where frames
  render fully qualified).
- **Org-local metadata alongside managed rows:** subscriber-deployed CMDT (e.g. flag-gated `TriggerAction__mdt` rows
  from this harness — or any real customer's) participates in framework dispatch during managed test transactions,
  exercising paths the bare packaging org never runs.

**Test-convention corollary:** package tests must never assert unfiltered org-wide counts (`getAll().size()` and the
like). Subscriber orgs legitimately persist their own rows (e.g. flood-controlled trigger-action skip logs) during
kern test transactions, so count assertions must be scoped to the test's own `ClassMethod__c` or fingerprint key —
a genuine regression still fails the scoped count because duplicated rows share the test's key.

**Shipped-default caveat (tuned-org pins).** Package tests pin shipped CMDT defaults at two strictness levels:

- The **card-rule pair** (`MaskPaymentCard` / the `MaskCreditCard` it replaces) uses *guarded* pins: strict
  shipped-value assertions apply only while the live record still matches its shipped fingerprint; in a tuned org
  those tests assert the cross-generation invariant instead, so they pass in every org state.
- The **other 16 masking rules** (and other shipped CMDT defaults) carry *unguarded* strict pins. In an org where
  the subscriber tuned one of those records, the corresponding pins fail **by design** — the failure means "this
  org diverged from shipped defaults", not "the package regressed". Confirm the org's tuning explains the failure
  before treating it as a defect. Converting the remaining pins to the guarded shape is a tracked follow-up.

### 2.2c Upgrade-Path Gate (upgraded-org context)

The upgraded org is the **fourth execution context** (after the dev org, the packaging build, and the fresh
subscriber org). CMDT upgrade semantics make it unreproducible anywhere else: field values the subscriber has
touched on pre-existing records never upgrade, while new records and new fields always arrive. This gate is
permanent — its first run caught a real product gap (improved card masking never reached upgrading subscribers),
which is what the successor-rule mechanism it now verifies was built to solve.

**Scope differentiation — the two legs deliberately do NOT run the same cycle:**

| Leg | What it proves | What runs |
|-----|----------------|-----------|
| **Fresh install** (new org, target build installed directly) | Steady-state behaviour: both card rules at shipped values, the successor doing the work from the first transaction | The full standard cycle: §2.2b → Phase 2 scripts (sections 36/37/40/44/61/76 carry the successor census; section 37 Case B is the takeover-effective probe) → Phase 3 visual |
| **Upgrade** (install 1.0.0-121, seed states, upgrade to the target build) | State transitions — where the replacement risk actually lives | §2.2b (zero failures) + the succession matrix below + the advisor picker/annotation spot-check. NOT the full Phase 3 visual suite — the fresh leg owns it |

**Succession matrix (upgrade leg only — these seeded states cannot exist on a fresh install):**

1. **Pristine predecessor.** Upgrade, then assert: `MaskPaymentCard` + its 4 targets arrived AND each target's
   `Rule__c` resolves to the successor record (closes the dangling-reference failure mode); `MaskCreditCard` still
   carries its 1.0 values; a 2-series Mastercard PAN masks on a framework surface; a pre-created subscriber target
   on a custom object still masks; the advisor hides the predecessor from the picker and annotates applied rows;
   `RunAllTestsInOrg` zero failures.
2. **Tuned predecessor.** Tune `MaskCreditCard` (e.g. `Replacement__c`) before the upgrade. Post-upgrade the tuned
   rule still fires on framework surfaces and the successor coexists (no takeover); `RunAllTestsInOrg` zero
   failures in the tuned org (the guarded pins flip to the cross-generation invariant).
3. **Successor deactivation.** Deactivate `MaskPaymentCard` after the upgrade → the predecessor's targets resume
   the framework-object work on their own (no coverage hole). Verify with a targeted probe (a 16-digit Luhn-valid
   card on a framework surface still redacts via the resumed `MaskCreditCard`) and re-run `RunAllTestsInOrg`.
   Do NOT run the full Phase 2 masking sections in this state — sections that pin the successor active fail by
   design while it is deactivated (37 Case B, 61e, 76b, 76c). Re-activate `MaskPaymentCard`, confirm the takeover
   resumes (section 37 goes green again), then continue.
4. **Deactivated predecessor seeded pre-upgrade.** The upgrade re-activates card masking through the successor
   (accepted behaviour, release-noted with the opt-out path: deactivate `MaskPaymentCard` too); consciously verify
   the BlockDml availability impact.
5. **DeveloperControlled value-change probe.** Pin the platform's CMDT upgrade semantics empirically:
   subscriber-touched values stay, untouched values and new records/fields arrive.

**Record-name discipline for the upgrade legs' state deploys:** subscriber-side edits to MANAGED CMDT records
MUST use the namespace-qualified record name (`kern__MaskingRule.kern__MaskPaymentCard`). The unprefixed form
(`kern__MaskingRule.MaskPaymentCard`) does not edit the packaged record — it CREATES an org-local clone whose
duplicate DeveloperName is precisely the collision state section 77 seeds deliberately. A state deploy that
accidentally uses the unprefixed form bricks every framework insert on builds without the engine fallback,
and on current builds it silently moves the org onto the degraded read path until the clone is deleted.

### 2.3 Static Code Analysis (Scanner Ruleset)

Validates the KernDX PMD ruleset (`scanner/kerndx-pmd-ruleset.xml`) against test fixtures and framework source.

> **PMD floor vs. Code Analyzer bundle (updated 2026-07-12).** The kern rulesets now carry no
> standard-category rule references and load on the PMD apex module >= 7.19.0, which includes the
> pmd-apex 7.25.0 the current `code-analyzer` plugin (5.14.0) bundles — the `sf code-analyzer`
> commands in 2.3a–2.3c work again. (Until 2026-07-12 the rulesets referenced
> `InvocableClassNoArgConstructor`, a rule PMD added in 7.26.0, and one unresolvable reference fails
> the whole ruleset load with `UninstantiableEngineError`; `kerndx doctor` surfaced this as the
> `below` verdict.) The standalone `pmd` CLI legs below remain the reference counts and an
> equivalent alternative:
>
> ```bash
> pmd check -d release-testing/scanner/classes/    -R scanner/kerndx-pmd-ruleset.xml       -f text --no-cache   # 2.3a
> pmd check -d force-app/                          -R scanner/kerndx-framework-ruleset.xml -f text --no-cache   # 2.3b
> pmd check -d release-testing/subscriber/classes/ -R scanner/kerndx-pmd-ruleset.xml       -f text --no-cache   # 2.3c
> ```
>
> The `npm run release:phase2` scanner step (which drives `sf code-analyzer` against the fixture
> config) passes the same way. The expected counts below are unchanged by the standard-rule removal:
> the dropped reference never fired on the fixtures (re-verified 2026-07-12: 2.3a = 40, 2.3b = 0).

#### 2.3a Violation Detection

Run the scanner against the test fixtures that contain deliberate violations:

```bash
sf code-analyzer run --target release-testing/scanner/classes/ --rule-selector pmd:KernDXFrameworkCompliance --config-file code-analyzer.yml --view detail
```

**Expected:** 40 violations across 4 files (0 from `ScannerTestCompliant.cls`):

| File                             | Rule                       | Count |
|----------------------------------|----------------------------|-------|
| `ScannerTestTrigger.trigger`     | KernTriggerMustDelegate    | 1     |
| `ScannerTestRestViolation.cls`   | KernRestResourceNaming     | 1     |
| `ScannerTestViolations.cls`      | KernNoInlineSOQL           | 4     |
| `ScannerTestViolations.cls`      | KernNoDirectDML            | 4     |
| `ScannerTestViolations.cls`      | KernNoSystemDebug          | 2     |
| `ScannerTestViolations.cls`      | KernNoRawHttp              | 3     |
| `ScannerTestViolations.cls`      | KernNoRawHttpMock          | 1     |
| `ScannerTestViolations.cls`      | KernNoRawCache             | 2     |
| `ScannerTestViolations.cls`      | KernNoRawDescribe          | 1     |
| `ScannerTestViolations.cls`      | KernNoRawTypeForName       | 1     |
| `ScannerTestViolations.cls`      | KernNoRawEnqueueJob        | 1     |
| `ScannerTestViolations.cls`      | KernNoRawSchedule          | 1     |
| `ScannerTestViolations.cls`      | KernNoRawEventPublish      | 1     |
| `ScannerTestViolations.cls`      | KernNoRawRestContext       | 2     |
| `ScannerTestViolations.cls`      | KernNoRawEmail             | 1     |
| `ScannerTestViolations.cls`      | KernUseSchedulerBase       | 1     |
| `ScannerTestViolations.cls`      | KernNoRawCrypto            | 1     |
| `ScannerTestViolations.cls`      | KernNoRawFeatureManagement | 1     |
| `ScannerTestViolations_TEST.cls` | KernNoInlineSOQL           | 1     |
| `ScannerTestViolations_TEST.cls` | KernNoDirectDML            | 1     |
| `ScannerTestViolations_TEST.cls` | KernNoInlineDmlInTests     | 1     |
| `ScannerTestViolations_TEST.cls` | KernNoLegacyAssert         | 3     |
| `ScannerTestViolations_TEST.cls` | KernNoCoverageTheatre      | 3     |
| `ScannerTestViolations_TEST.cls` | KernUseTestBuilder         | 2     |

If a new framework wrapper is added, add a corresponding violation method to `ScannerTestViolations.cls` and update
the expected count.

#### 2.3b Framework Clean Scan

Run the package-side ruleset against the framework source to verify no unintended violations remain in production
classes:

```bash
sf code-analyzer run --target force-app/ --rule-selector pmd:KernDXFrameworkPackageSide --config-file code-analyzer.yml --view table
```

**Expected:** 0 violations in production (non-`_TEST`) classes. Test class violations (KernUseTestBuilder,
KernNoDirectDML) are expected — framework tests legitimately test raw APIs.

Do **not** use `pmd:KernDXFrameworkCompliance` for this scan — that is the subscriber-facing "use the framework API"
lens, and it fires by design on the framework's own wrapper implementations (`UTIL_Crypto`, `UTIL_Cache`,
`API_Dispatcher`, the `SEL_*`/`QRY_*` inline-SOQL-by-design classes) plus the informational
`KernSecurityBypassCallSite` inventory rule. `pmd:KernDXFrameworkPackageSide` is the lens built for `force-app/`.

#### 2.3c Subscriber Code Scan

Run the scanner against the subscriber test code to confirm compliant subscriber code passes clean:

```bash
sf code-analyzer run --target release-testing/subscriber/classes/ --rule-selector pmd:KernDXFrameworkCompliance --config-file code-analyzer.yml --view detail
```

**Expected:** Subscriber code follows framework patterns — all violations should be justified and documented.

#### 2.3d ESLint LWC Fixture Scan

Run the ESLint `kerndx/use-component-builder` rule against the scanner LWC test fixtures:

```bash
cd release-testing/scanner/lwc && npx eslint "**/*.js"
```

**Expected:** 1 violation in `scannerTestViolation.js`, 0 violations in `scannerTestCompliant.js` and `scannerTestSuppressed.js`.

| File                                             | Expected                               |
|--------------------------------------------------|----------------------------------------|
| `scannerTestViolation/scannerTestViolation.js`   | 1 `kerndx/use-component-builder` error |
| `scannerTestCompliant/scannerTestCompliant.js`   | 0 errors (uses ComponentBuilder)       |
| `scannerTestSuppressed/scannerTestSuppressed.js` | 0 errors (eslint-disable suppression)  |

#### 2.3e ESLint LWC Framework Scan

Run the ESLint rule against all framework LWC source to verify no components bypass ComponentBuilder:

```bash
cd force-app/main/default/lwc && npx eslint --rule "kerndx/use-component-builder: error" "**/*.js" --ignore-pattern "**/*.test.js"
```

**Expected:** 0 `kerndx/use-component-builder` errors. Framework infrastructure components (streaming monitor, notice, validationErrors) have
justified `// eslint-disable-next-line` suppressions. Any new component extending `LightningElement` without suppression is a violation.

#### 2.3f GitHub Code Quality Review (JS/TS)

Review the GitHub Code Quality (CodeQL) findings on the repo before promotion. This is a **repo-level, JavaScript/TypeScript-only** lens
(the `pipeline/` CLI, `scripts/`, and LWC `.js`) — it does **not** cover Apex, which 2.3a–2.3c handle. Confirm the feature is still configured:

```bash
gh api /repos/JVB-Consulting/Kern/code-quality/setup
```

**Expected:** `state: configured`, `languages: ["javascript-typescript"]`. Then open the repo **Quality** view (Security → Code quality, or the
inline findings on the release PR) and triage every open finding: fix true positives, and dismiss false positives with a reason. There is no
REST/`gh` endpoint for the findings themselves yet (only this setup endpoint), so the triage is done in the web UI. No unresolved true-positive
finding should remain when the release candidate is promoted.

---

## Phase 2.5 — Perf History Harvest

After Phase 2 completes, harvest `PERF_ROW:` lines from the Phase 2 log output and update the rolling baselines:

```bash
node release-testing/runner/perf-history.js --logfile <phase2-log-path>
```

This phase NEVER fails the build on timing alone. Behaviour assertions in each section script are the only hard gate;
this step prints WARN/WARN! lines for regressions ≥1.3×/≥1.5× off the rolling 5-run median for human review.

**Sections covered** (the 8 load tests that emit `PERF_ROW` lines):

| Section | Short name      | What it measures                                     |
|---------|-----------------|------------------------------------------------------|
| 44      | masker          | `UTIL_FrameworkMasker` bulk throughput (200 records) |
| 45      | qry-aggregate   | `QRY_Builder` GROUP BY + ROLLUP cardinality          |
| 46      | trigger-fanout  | `TRG_Dispatcher` fan-out under bulk DML              |
| 47      | validation-bulk | `UTIL_ValidationRule.executeForTrigger()` bulk       |
| 48      | async-chain-ser | `UTIL_AsyncChain` context serialization enqueue time |
| 49      | async-launcher  | `UTIL_AsynchronousJobLauncher` burst enqueue time    |
| 50      | logger-pe-quota | Logger PE flood wall-clock (scoped emit batch)       |
| 51      | callout-storm   | `UTIL_HttpClient` parallel callout throughput (Node) |

**Per-section invocation** (when iterating on one load test in isolation):

```bash
node release-testing/runner/perf-history.js --section=45 --logfile <log>
```

**Inspect baselines without modifying:**

```bash
node release-testing/runner/perf-history.js --report
```

**Reset a baseline after intentional perf change** (e.g. after a masker optimisation lands):

```bash
node release-testing/runner/perf-history.js --reset --section=44
```

The `release-testing/results/perf-history.json` file is committed as the source of truth for the package's current
performance shape. When a perf change is intentional, the commit shipping the optimisation should also commit the new
baseline.

See `release-testing/Testing Protocol.md` for the isolation guarantee, `PERF_ROW` emission convention, and per-baseline-update
commands.

---

## Phase 3 — Visual Tests (Playwright E2E)

Phase 3 is fully automated by Playwright. The 80 visual checks (numbered V1 through V114, with gaps between
part groups) run in a headless browser against the subscriber scratch org.

### Running Phase 3

```bash
npm run test:e2e
```

Or with visible browser for debugging:

```bash
npm run test:e2e:headed
```

Or a single part:

```bash
npm run test:e2e:part3
```

### Test Specs

| Spec file                          | Checks            | What it tests                                                                                                                                                                                   |
|------------------------------------|-------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `part1-app-core.spec.js`           | V1-V5, V1b-V1i    | App Home, Health Check sections + customize flow, Log Entries, Scheduled Jobs, API Harness, API Calls                                                                                           |
| `part2-api-config.spec.js`         | V6-V10            | Echo results, API Issues, Streaming Monitor UI, CMDT, Login Frequencies                                                                                                                         |
| `part3-lwc-integration.spec.js`    | V11-V14           | LWC components, module tests, Account triggers, log entries                                                                                                                                     |
| `part4-scheduler-exec.spec.js`     | V15-V18           | Job execution (Purge, Login History), cleanup verification                                                                                                                                      |
| `part5-streaming-setup.spec.js`    | V19-V24, V104-V105, V114 | Subscribe to LogEntryEvent, CDC, Standard PE, trigger events; Org Limits card grid (worst-first bands, sort + search); native-SVG timeline dots/tooltip/select contract                                                                          |
| `part6-streaming-advanced.spec.js` | V25-V29, V99-V103 | Generic channel (stale cache), publish, download, cleanup; Event usage metrics (prototype contract, view states, seeded-data roundtrip, Enhanced Usage Metrics toggle, CDC channel-list purity) |
| `part7-async-chain.spec.js`        | V10-V17           | Async chain execution, polling, record verification, API callout, handler isolation                                                                                                             |
| `part8-chain-monitor.spec.js`      | V30-V39           | Chain Monitor UI: split panel, columns, detail metadata, step timeline, failed-chain error, filters, sorting, launched-chain and record-page timelines                                          |
| `part9-masking-advisor.spec.js`    | V90-V98           | Data Masking Advisor: landing, add-object flow, rule detail, export, health-check masking posture                                                                                               |
| `part10-log-console.spec.js`       | V106-V113         | Log Console: launcher tile + namespaced tab, ribbon summary + severity filter, date ranges (needs audit back-dating), endless scroll, sorting, debounced search incl. SOSL body leg, Chain Monitor cross-links, detail drawer + chain-gated timeline |

**Expected:** 79/79 tests passing (13 in part1 after subsequent additions added V1f–V1i and extended V1/V1e).

Run part10 on its own with:

```bash
npx playwright test --config release-testing/e2e/playwright.config.js part10-log-console
```

part10 seeds its own Log Console fixtures in `beforeAll` (`seed-log-console.apex` + `seed-log-console-bulk.apex`)
and tears them down in `afterAll`; it needs no manual data staging beyond the Phase 1 audit-field recipe.

**Out of Playwright scope:** Flow Builder rendering of the packaged invocable actions (the Setup-UI picklists) is not
browser-tested; the actions' runtime behaviour is covered by Phase 2 sections 17, 20, and 41-44.

**Part 1 detail (post-Phase 0):**

- V1 — App nav, tool cards, health check fail-above-warn section ordering, Apply + Customize buttons present.
- V1b — Health check adapts as purge jobs are configured (4-of-4 turns card green).
- V1c — Admin tool cards launch namespaced tabs.
- V1d — Apply Recommended Retention creates all 4 purge jobs.
- V1e — Customize flow per-object save, 4→3 sub-row transition, singular/plural meta labels.
- V1f — Customize-mode headline interpolates proposal count; help paragraph and back-to-apply link work.
- V1g — Set-up modal renders with usable dimensions (>300px height; guards against the 32px `lightning-layout`-inside-modal regression).
- V1h — Locked Class Name renders read-only `lightning-input`, not a combobox with placeholder.
- V1i — Customize + Set-up flow does not emit "Unable to access Apex type" errors (guards `schedulerClassName` namespace-agnostic wiring).
- V2-V5 — Log Entries, Scheduled Jobs lifecycle, API Test Harness, API Call records.

### Prerequisites

- KernDX package installed in subscriber scratch org (alias: the value of `SF_SUBSCRIBER_ORG_ALIAS`)
- Subscriber test code deployed (classes, triggers, CMDT, LWC components, FlexiPage, tab)
- Health Check prerequisites configured (org cache partition, session cache partition, trusted URL)
- Audit-field back-dating enabled (Phase 1 two-step recipe) — `part10`'s date-range check hard-fails without it

### Debugging Failures

1. **Screenshot:** `release-testing/test-results/<test-name>/test-failed-1.png`
2. **Video:** `release-testing/test-results/<test-name>/video.webm`
3. **Trace:** `npx playwright show-trace release-testing/test-results/<test-name>/trace.zip`
4. **Headed mode:** `npm run test:e2e:headed` to watch the browser in real time
5. **Debug mode:** `npm run test:e2e:debug` for Playwright Inspector with step-through

### Dependency Chain

Parts 1-4 are mostly independent. Parts 5 and 6 MUST run in order (Part 5 creates streaming state,
Part 6 consumes and cleans it up). Part 10 runs in the `independent` Playwright project, which depends on
the `scheduler-serial` project — that ordering guarantees part1's fire-and-forget `kern__LogEntry__c` purge
batch is launched before part10 seeds, and part10's `beforeAll` additionally waits out any still-running
kern batch before inserting its fixtures.

---

## Phase 4 — Results Recording

After completing all phases, create a result file in `release-testing/results/` named after the package version
(e.g., `1.0.0-37.md`).

### Result File Format

```markdown
# Release Test Results — Kern 1.0.0-XX

**Package Version:** 1.0.0-XX
**SubscriberPackageVersionId:** 04tXXXXXXXXXXXXXXX
**Test Date:** YYYY-MM-DD
**Tested By:** [name or agent]

## Summary

| Phase | Result | Details |
|-------|--------|---------|
| Phase 2 — Automated Tests | PASS/FAIL | XX/XX scripts passed, XXX/XXX test methods passed |
| Phase 2 — Scanner Ruleset | PASS/FAIL | XX/24 expected violations, 0 production violations |
| Phase 2 — ESLint LWC Scan | PASS/FAIL | 0 kerndx/use-component-builder violations |
| Phase 3 — Visual Tests    | PASS/FAIL | XX/79 Playwright tests passed |

## Phase 2 — Automated Test Results

| Script | Result | Pass/Total |
|--------|--------|------------|
| section-1-trigger-lifecycle | PASS/FAIL | X/5 |
| section-2-trigger-bypass | PASS/FAIL | X/6 |
| ... | ... | ... |
| RunLocalTests | PASS/FAIL | XXX/XXX |

## Phase 3 — Visual Test Results

[Generated by Playwright reporter — see current-run.json]

## Findings

- [List any issues, warnings, or observations]

## Promotion Decision

- [ ] **PROMOTE** — All tests passed. Ready for `sf package version promote`.
- [ ] **HOLD** — Issues found. See findings above.
```

### Recording Steps

1. Copy the template above into `release-testing/results/<version>.md`
2. Fill in results from Phase 2 and Phase 3
3. Record any findings or deviations
4. Check the promotion decision box
5. Verify the `packageVersion` header in `results/current-run.json` matches the cycle under test (the reporter
   preserves whatever header it finds — a stale value from the previous cycle must be corrected by hand)
6. Commit the result file

---

## Phase 5 — Extended Load (pre-tag only)

Run only when promoting beta to GA. Adds ~45-60 min wall-clock.

**Pre-conditions:**

- Fresh scratch org under `SF_SUBSCRIBER_ORG_ALIAS` (cumulative load consumes governor headroom)
- Org Cache + Session Cache + Trusted URL configured (per Health Check)
- All Phase 1-4 phases passed first

**Run:**

```bash
npm run test:load:extended
```

This sequences:

- `sustained-masker-soak.apex` (~30 min via Schedulable cron)
- `sustained-logger-pe-flood.apex` (~30 min via Schedulable cron)
- `parallel-callout-burst-100.js` (~5 min)
- `parallel-cache-contention.js` (~5 min)

Smoke-test mode (single iteration via direct fire) is documented in each script's header.

**Failure of any extended script blocks GA promotion.**

See `release-testing/Testing Protocol.md` for the load-test isolation guarantee + per-baseline-update commands.

---

## Knowledge Org Setup

Section 33 tests require a Knowledge-enabled subscriber scratch org. This is **optional** — only run when testing
Knowledge/Data Category features. The standard subscriber org (created with `config/project-scratch-def.json`) does NOT
have Knowledge enabled.

### Create Knowledge-Enabled Subscriber Org

Use `config/km-scratch-def.json` instead of `project-scratch-def.json` when creating the scratch org in Phase 1.2:

```bash
cd /tmp/kern-subscriber && sf org create scratch \
  -f <repo-root>/config/km-scratch-def.json \
  -a ${SF_SUBSCRIBER_ORG_ALIAS} -v DevHub -y 30 --wait 10
```

### Deploy Knowledge Test Artifacts

After deploying the standard subscriber artifacts (Phase 1.4), also deploy Knowledge settings and data category groups:

```bash
mkdir -p /tmp/kern-subscriber/force-app/main/default/{settings,datacategorygroups}
cp release-testing/subscriber/settings/* /tmp/kern-subscriber/force-app/main/default/settings/
cp release-testing/subscriber/datacategorygroups/* /tmp/kern-subscriber/force-app/main/default/datacategorygroups/
cd /tmp/kern-subscriber && sf project deploy start -o $SF_SUBSCRIBER_ORG_ALIAS -d force-app/main/default --ignore-conflicts
cd <repo-root>
```

### Create Test Data

Run the setup script to insert and publish Knowledge articles:

```bash
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-33-knowledge-setup.apex
```

After running setup, assign data categories to the published articles. This requires manual assignment via the
Knowledge tab or the Data Category Selection API. Assign:

- "KDX Test Alpha North" → KM_TestCategory: Alpha, KM_TestRegion: North
- "KDX Test Alpha South" → KM_TestCategory: Alpha, KM_TestRegion: South
- "KDX Test Beta North" → KM_TestCategory: Beta, KM_TestRegion: North

### Run Section 33

```bash
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-33-knowledge-data-category.apex 2>&1 | grep 'USER_DEBUG'
```

**Expected:** 5/5 PASS

## Enhanced Usage Metrics Setup

The Streaming Event Monitor's "Event usage metrics" view adapts to the org's Enhanced Usage Metrics
capability. Orgs **without** the feature — the scratch-org default — report **daily totals only**: the
Hourly and 15-minute granularity buttons are disabled and an inline notice explains the limitation.
That daily-only posture is the expected default render for a fresh subscriber scratch org, and V99/V100
assert it directly — do not pre-enable the feature before Phase 3.

To exercise Hourly and 15-minute granularity live, enable the feature by deploying the checked-in
`PlatformEventSettings` bundle:

```bash
sf project deploy start --metadata-dir release-testing/e2e/fixtures/platform-event-settings/enhanced-usage-metrics-enabled/metadata -o $SF_SUBSCRIBER_ORG_ALIAS
```

Restore the default afterwards (the daily-only assertions in V99/V100 and the gap-finder's
capability-aware notice branch depend on it):

```bash
sf project deploy start --metadata-dir release-testing/e2e/fixtures/platform-event-settings/enhanced-usage-metrics-disabled/metadata -o $SF_SUBSCRIBER_ORG_ALIAS
```

Verification probe — with the feature enabled, `PlatformEventUsageMetric` exposes a `TimeSegment` field
and **requires** it as a query filter; without the feature the field does not exist:

```bash
sf data query -o $SF_SUBSCRIBER_ORG_ALIAS -q "SELECT Name, Value FROM PlatformEventUsageMetric WHERE TimeSegment = 'Daily' LIMIT 3"
```

Notes:

- The capability flips as soon as the settings deploy completes; the usage-metrics view re-probes it on
  every load, so a page reload is enough to pick up the change.
- Part 6's V102 performs this enable → assert → restore round-trip automatically via the same fixture
  bundles, so a standard Phase 3 run needs no manual toggling.
- `PlatformEventUsageMetric` rows are aggregated by the platform on a lag — daily rows can take hours to
  materialise after events are published; 15-minute buckets surface fastest. An empty usage screen right
  after seeding events is platform latency, not a defect: V101 annotates and passes in that case rather
  than failing the run.

### Usage-Metrics + Org-Limits Probes (development org)

Four standalone Playwright probes exercise deployed Streaming Event Monitor views directly against a
development org (they do not need the subscriber harness):

```bash
node release-testing/scripts/usage-metrics-gapfinder.mjs            # prototype data-spec-id contract
node release-testing/scripts/usage-metrics-robustness-probe.mjs     # 10 hostile-interaction scenarios
node release-testing/scripts/org-limits-gapfinder.mjs               # Org Limits card-grid prototype contract
node release-testing/scripts/timeline-gapfinder.mjs                 # streamingTimeline native-SVG mockup contract
```

The usage-metrics gap-finder verifies every `data-spec-id` from the validated prototype exists in the live DOM.
The robustness probe drives hostile interaction patterns (refresh spam, granularity storms,
mid-fetch chip toggles, forced fetch failures, hostile custom-range input through the real pickers)
and fails on any HIGH-severity anomaly — run it after any change to the Event Monitor LWC surface.
The org-limits gap-finder does the same prototype-contract check for the "Org limits" card grid,
driving the empty state (no-match search) and the error state (aborted Aura XHRs) live and
self-recovering afterwards — coverage the subscriber-org V104/V105 checks cannot produce naturally.
The timeline gap-finder round-trips the `data-spec-id`s from the validated before/after mockup to
the live timeline: it subscribes to LogEntryEvent, publishes a probe log entry, waits for the first
native-SVG dot, and hovers it to drive the detail tooltip (pinned to the `.data` variant so the
crosshair tooltip cannot stand in for it).
All four accept `--org=<alias>` and `--headed`; the robustness probe also accepts `--only=A,B` to
run a scenario subset.
