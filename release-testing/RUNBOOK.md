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
- [Phase 4.5 — Doc Media Staleness Check (pre-promotion)](#phase-45--doc-media-staleness-check-pre-promotion)
- [Phase 4.6 — The Windows proof (after promotion, before the mirror sync)](#phase-46--the-windows-proof-after-promotion-before-the-mirror-sync)
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

The Playwright journeys check the org before the browser starts. If the alias names an org that cannot be opened (a
scratch org that has expired or been deleted, an alias the Salesforce CLI does not know, an org whose connection has
lapsed), the run stops at once with a message that names the org, says why, and names this variable.

Journey results are recorded by the kind of org they ran against. A run against an org that has the package installed
adds its results to `release-testing/results/current-run.json`, the record of the release-testing cycle. A run against
any other org, such as a development org that holds the source with no namespace, writes to
`release-testing/results/development-run.json` instead, which git ignores, so trying a journey during development
never rewrites the cycle's record. One thing to know when you run a journey by hand: a `--reporter` flag on the
command line replaces the configured reporters, so that run records nothing in either file.

The two runner scripts that write the same record, `run-all.js` and `run-phase2.js`, make the same check and go no
further against an org without the package. Every Phase 2 script is written against the installed package, so they
stop before anything is run in the org, deployed to it or written down, with a message that names the org and this
variable. They stop the same way when the org cannot be asked at all, and repeat the first line of what the failure
said when it said anything. To try the journeys on an org without the package, run `npm run test:e2e`.

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
    permissionsets/                   # SubscriberTestAccess, SubscriberRunFlows, StrictValidationAccess
  scanner/                            # Static analysis validation fixtures
    classes/                          # Apex: deliberate violations + compliant class
    lwc/                              # LWC: violation, compliant, suppressed components
  scripts/                            # Anonymous Apex test scripts + Node probes (167 files, 153 of them .apex, and 3 folders)
  e2e/                                # Playwright visual tests (131 journeys)
    specs/                            # 12 part specs (part1 through part12) + 2 capture specs + 1 gap-finder spec
    pages/                            # Page objects for Salesforce UI
    helpers/                          # Auth, CLI, navigation, and wait helpers
    fixtures/cmdt-states/             # CMDT state XML for sections 3, 11, 27
    fixtures/audit-fields/            # Two-step audit-field back-dating enablement (part10 seeds)
    fixtures/profile-filtering/       # Profile Filtering on for every run (section 1.4)
  runner/                             # Phase 2 orchestrator and CMDT deployer
  results/                            # Version-stamped result files
```

---

## Phase 1 — Environment Setup

### 1.1 Build the package: one build, or two inside a preview window

**Before any validated build, run the test classes the cycle changed on a namespaced scratch org** (maintainer ruling
2026-10-11, after a validated build failed 24 tests that were green on the no-namespace development org). The org
must receive exactly what the build ships, so work from a copy, never from the working tree: `git archive HEAD
force-app sfdx-project.json .forceignore config/project-scratch-def.json` into a folder under `tmp/`, then apply the
build's own namespace rewrite to that copy by calling `scripts/prepare-package-build.js` as `main({projectRoot: <copy>})`.
Do not hand-write prefixed records: the build rewrites about 27 files (custom metadata class and credential fields,
flows, component tab names and Apex types), and a partial set produces false failures (34 of them on 2026-10-11 from
three hand-written records). From the copy, create a one-day scratch org (its project file gives it the `kern`
namespace; confirm with `SELECT NamespacePrefix FROM Organization`), deploy `force-app`, run the changed classes with
`--result-format json --wait 40` into a file, read the file, and delete the org. The development org stays
un-namespaced on purpose (it is the only continuous proof of the clone-and-rename install path); the namespaced run
is where the managed-context defects show, at a quarter of the cost of a failed build. A failure here that the
development org does not show is a namespace or field-permission defect to fix before building; the usual cause is a
test read of package fields without `withSystemMode()`. Mind the Dev Hub's active-scratch-org limit.

Ask the packaging pool which API version it compiles before building anything:

```bash
sf api request rest /services/data -o DevHub
```

The last entry is the newest version the pool compiles. When it lists the version `sfdx-project.json` declares as
`sourceApiVersion`, one build carries the whole cycle. It is the build that gets promoted, so it is validated (a version
built with `--skip-validation` cannot be promoted):

```bash
node scripts/build-package.js
```

Note the `SubscriberPackageVersionId` (04t...) from the output.

When it does not, the source is written for a release the pool has not reached yet (1.8 on API 68 while the pool sat
on Summer '26, until about 2026-10-11), and the cycle takes two builds:

| | The preview build | The production build |
|---|---|---|
| When | As soon as the last change to the package has landed | Once the pool lists the source's API version |
| Definition | `config/project-scratch-def-preview.json`, which carries `"release": "preview"` | The default, as every release before it |
| Installs into | Preview scratch orgs only (1.2 and 1.3b create theirs from the same definition); anywhere else refuses with `MISMATCHING_VERSIONS` | Any org |
| Carries | Phases 1 to 4: the one subscriber-org pass, the upgrade leg included | Phase 1 again, from the default definition (a fresh org and the upgrade leg), then Phase 5 and the promotion decision |
| Promoted | Never | Yes |

The preview build:

```bash
node scripts/build-package.js --skip-validation --definition-file config/project-scratch-def-preview.json
```

The build forwards the definition to `sf package version create`, which compiles the version on the preview release.
If the CLI's definition validator refuses the file for its `ApexIntegrationTests` feature (1.2 records it printing
`features.2: Invalid input` at org creation), build from a copy of the definition without that feature: the package
has no integration test of its own. Note the 04t. `sf package version create` adds the version's `packageAliases` entry
to `sfdx-project.json`, and the build's last step rewrites the install references from it (`docs/Installation.md`,
`docs/Strategic Guide - Metrics.md`, `CLAUDE.md`, the two mirror runbooks). Keep the alias: it
is the cycle's record. Set the rest aside with `git stash push -m "preview build references" -- <those files>` (never
`git checkout`, which
discards edits), because a reader who follows those references cannot install a preview version. The production build
writes them again with its own 04t, and that rewrite is the one committed, after promotion.

The production build, validated, from the commit the preview build was made from or a later one whose changes have been
through the phases they touch:

```bash
node scripts/build-package.js
```

Phases 2 to 4 are not repeated on it: they ran on the preview build against the same source. A fix that changes the
package after the preview build repeats the preview build and the phases it touches first.

Between the platform's general-availability cutover and the pool's move, neither build works: `release: preview` is
refused for a package version and the pool cannot compile the newer API yet. Wait for the probe to list the version.

Before either build, on a clean tree: the drift audit (`org-source-drift-audit` skill), the coverage-baseline recapture
(`npm run coverage:gate -- --fix-baseline`, which also adds every bundle and class new since the last capture), and, for
the first build of a new line, `versionNumber` and `versionName` in `sfdx-project.json` opened to the new line in a
commit of their own (the 1.7 line: `16ae60d6`). Keep `ancestorVersion` at `HIGHEST` and never pass
`--skip-ancestor-check` to a cycle build: the upgrade leg needs the lineage.

### 1.2 Create Subscriber Scratch Org

```bash
sf org delete scratch -o $SF_SUBSCRIBER_ORG_ALIAS --no-prompt
```

**CRITICAL:** Create the scratch org from `/tmp/kern-subscriber/` — NOT the dev project (has `"namespace":"kern"`).

```bash
mkdir -p /tmp/kern-subscriber/force-app
cat > /tmp/kern-subscriber/sfdx-project.json << 'TMPEOF'
{"packageDirectories":[{"path":"force-app","default":true}],"name":"KernSubscriber","sourceApiVersion":"68.0"}
TMPEOF
cat > /tmp/kern-subscriber/.forceignore << 'TMPEOF'
# Jest specs are not deployable LWC bundle content
**/__tests__/**
TMPEOF
cd /tmp/kern-subscriber && sf org create scratch \
  -f <repo-root>/config/project-scratch-def.json \
  -a ${SF_SUBSCRIBER_ORG_ALIAS} -v DevHub -y 30 --wait 10
```

**Inside a preview window (1.1; the Winter '27 window, until about 2026-10-11):** create the org from
`config/project-scratch-def-preview.json` instead, which carries `"release": "preview"` and the `ApexIntegrationTests`
feature the [Integration callout probe](#integration-callout-probe) needs. The preview build of 1.1 installs nowhere
else. The CLI's definition validator prints one line it should not, `features.2: Invalid input`, because its bundled
schema predates the feature; the platform
honours the feature and creates the org. That line is the only expected warning: anything else printed at creation
is drift. Drop this caveat once a CLI upgrade stops printing it.

Without the `.forceignore`, any harness LWC bundle that ships Jest specs (e.g. `accountCard/__tests__/`) deploys the
spec as component code and fails compile with `LWC1702: Invalid LWC imported identifier "createElement"`.

### 1.3 Install Package

```bash
sf package install -o $SF_SUBSCRIBER_ORG_ALIAS --package <SubscriberPackageVersionId> --wait 15 --no-prompt
```

From 1.8 on, record whether Retry Selected appears on the API Issues list once rows are selected, whether a Standard
User with Kern API Issue Resolver and the user permission Run Flows can run it, and the largest number of rows the list
lets you select. Retry Selected is a flow, and the list offers it only to a user with Run Flows. A managed package
cannot grant that permission through its own sets (the installed Kern sets hold none), so a subscriber grants it with
a set or profile of their own; this org uses `SubscriberRunFlows` from 1.4. A user with Kern API Issue Resolver alone
does not see Retry Selected (2026-10-11, measured on a fresh install).

From 1.8 on, the sharing default a fresh install gives the framework's objects is a PASS line: after the 1.4
artifacts are deployed, run `release-testing/scripts/section-85-sharing-defaults.apex` as shipped. It must print one
`85a PASS` line: **API Issue**, **Log Entry**, **API Call** and **Async Chain Execution** all read **Private**
(`npm run release:phase2` runs it too). V158 and V159 (Phase 3) seed their issues as the administrator; the Standard
User holding only Kern API Issue Resolver sees and retries them through the set's View All Records, with no sharing
rule. The Delete checks are PASS lines too: `SubscriberApiRecordDeleteGuard_TEST` (2.2) proves that a Standard User
holding only Kern API Issue Resolver is refused **Delete** on an API issue with the Delete API Records message, and that
an administrator can delete one. The package is installed for administrators only (the command above); the refusal
tests hold only on such an install.

### 1.3b Upgrade Leg (release-day path — required before every promotion)

The fresh install above cannot prove what every EXISTING subscriber experiences on release day: the
upgrade from the last released version. Upgrades deliver metadata differently from fresh installs —
new CMDT records, new fields, and supersession semantics (subscriber-controlled CMDT field values are
never updated in place; changed values ship as successor records) only get exercised on this path.
The 1.6 line initially skipped this leg because it lived in cycle notes rather than here; it is now a
hard prerequisite for the promotion decision.

Create a second org and walk the real path — the last RELEASED version first, then the candidate
(an org already on a beta cannot take another beta, so the leg always starts from the released 04t):

```bash
cd /tmp/kern-subscriber && sf org create scratch \
  -f <repo-root>/config/project-scratch-def.json \
  -a KernUpgradeSubscriber -v DevHub -y 7 --wait 10
sf package install -o KernUpgradeSubscriber --package <last released 04t> --wait 15 --no-prompt
```

Inside a preview window (1.1) this org too comes from `config/project-scratch-def-preview.json`: the candidate is the
preview build, and the released version installs into a preview org as into any org on a newer release. On the
production build, both legs run again from the default definition.

**Between the two installs:** the part8 block "Manual retry record checks" (Phase 3) needs a CLONE of the Kern Async
Chain Monitor Read Only permission set, created and assigned while the org is still on the released version. Make it
now, before the second install, or that check cannot be run without repeating the leg.

**Sections 84i and 84j run only on a leg that starts on 1.8.0-11.** A leg that starts on 1.9 or later (the 1.10 leg
starts on 1.9.0-4) skips both, and the results file records them as skipped for that reason. They test how a call that
1.8 saved is handled after the upgrade, and only a 1.8 org saves such a call: from 1.9 on, a request without an
Idempotency-Key is saved with a hash of its body and writes an issue, so 84i fails on a 1.9 org, as it should.

On a leg that starts on 1.8.0-11, also between the two installs, run section 84i. It saves one inbound call while the
org is still on 1.8.0-11, for a request sent without an Idempotency-Key: 1.8 saves such a call with no key and no hash
of its body. Section 84j runs it again after the upgrade. Assign the Kern Administrator set to the administrator,
deploy only the one test service, its setting, and the org's class resolver with its record (the released version finds a class of
the org only through that resolver; the 1.4 deploy later replaces all of them with the same files), and run the script:

```bash
sf org assign permset -o KernUpgradeSubscriber -n kern__Administrator
cd /tmp/kern-subscriber && mkdir -p force-app/main/default/classes force-app/main/default/customMetadata
cp <repo-root>/release-testing/subscriber/classes/*RetryLiveOnHold.cls* force-app/main/default/classes/
cp <repo-root>/release-testing/subscriber/classes/CustomTypeResolver.cls* force-app/main/default/classes/
cp <repo-root>/release-testing/subscriber/customMetadata/kern__ApiSetting.RetryLiveOnHold.md-meta.xml force-app/main/default/customMetadata/
cp <repo-root>/release-testing/subscriber/customMetadata/kern__ClassTypeResolver.CurrentOrgResolver.md-meta.xml force-app/main/default/customMetadata/
sf project deploy start -o KernUpgradeSubscriber -m ApexClass:API_RetryLiveOnHold -m ApexClass:REST_RetryLiveOnHold \
  -m ApexClass:CustomTypeResolver -m CustomMetadata:kern__ApiSetting.RetryLiveOnHold \
  -m CustomMetadata:kern__ClassTypeResolver.CurrentOrgResolver
cd <repo-root> && SF_SUBSCRIBER_ORG_ALIAS=KernUpgradeSubscriber node release-testing/scripts/section-84i-keyless-inbound-call-before-upgrade.js
```

It must print `SECTION84 PASS` for 84i-1 and 84i-2, then a `SECTION84 PENDING 84j` line with the command for 84j.
Keep that line: 84j needs its time and call id. When 84i fails,
it deletes its own rows; fix the cause and run it again before installing the candidate. Skip 84j only if 84i cannot pass.

Before you upgrade, do the before-the-upgrade step of item 3 in "Owed at 1.10 release testing" (section 2.1): Mock Selected APIs on the upgrade leg.

```bash
sf package install -o KernUpgradeSubscriber --package <candidate 04t> --wait 15 --no-prompt
```

Before 1.4, send the after-the-upgrade request of item 3 in "Owed at 1.10 release testing": the 1.4 deploy unticks the
box that request depends on. Then deploy the test artifacts (1.4), and run at minimum on the upgraded org:
`RunLocalTests`, the cache check at the end of 1.4, and the delta-focused sections and e2e parts covering the release's
new surface (they double as proof the upgrade delivered the new CMDT records, permission sets, and labels). Record the
outcome as the upgrade-leg block in the versioned results file. Mind the DevHub's active-scratch-org limit — free a
superseded org first if creation fails with `LIMIT_EXCEEDED`.

On a leg that started on 1.8.0-11 and ran 84i, on the upgraded org, run section 84j with the command 84i printed
(a leg that started on 1.9 or later skips 84j, as it skipped 84i), after the 1.4 deploy (it needs the
upgraded package and the 1.4 test service) and before sections 84g and 84h, or after 84h has deleted its rows: 84j
counts every row of the same test service since 84i started, so it must not run while 84g's rows are there. It saves an
Open issue by hand on the call 1.8 saved, runs it again through Retry Selected's Flow action, and waits up to three
minutes for the job. It must print `SECTION84 PASS` for 84j-1 to 84j-4 and for 84j-cleanup. When it prints
`SECTION84 PENDING`, run the command it prints 30 seconds later.

From 1.8 on, on the upgraded org, the upgrade delivers the Retry Selected action and its flow but never the list view's
own action list: search layouts belong to the org once the object is installed, so the API Issues list on an upgraded
org shows no Retry Selected until the release note's upgrader step is applied (2026-10-11, two upgraded orgs). Apply it
as the subscriber would, before the e2e parts: retrieve `CustomObject:kern__ApiIssue__c` from the org, add
`<massQuickActions>kern__RetrySelected</massQuickActions>` as the first line of its `searchLayouts`, deploy the object
back (a file holding only the search layout is refused), and record that the step was needed. Then record whether Retry
Selected appears on the API Issues list once rows are selected, whether a Standard User with Kern API Issue Resolver
and `SubscriberRunFlows` (Run Flows, see 1.3) can run it, and the largest number of rows the list lets you select.

From 1.8 on, on the upgraded org, the sharing default is a PASS line: an upgrade never changes it, so the upgraded org
keeps what the released version installed. A leg that starts on 1.8 or later starts Private (1.8 installs **API Issue**
and **Log Entry** Private): run the script as shipped, right after the upgrade; it must print `85a PASS`, and steps (b)
and the second run below do not apply (record that). A leg that starts on 1.7 or earlier starts **Public Read/Write**:
right after the upgrade, set the constant `EXPECTED_API_ISSUE_AND_LOG_ENTRY_DEFAULT` at the top of
`release-testing/scripts/section-85-sharing-defaults.apex` to `'ReadWrite'` and run the script: it must print `85a PASS`. Run `RunLocalTests` and the e2e parts on the org as the
upgrade left it. Then walk the step the release note gives ("API issues and log entries are private on a new install")
and record each outcome: (a) confirm the upgrade gave Kern API Issue Resolver **View All** on API Issue and API Call
(Setup, Permission Sets, Object Settings); (b) set **API Issue** and **Log Entry** to **Private** and wait for the
sharing recalculation email, then set the constant back to `'Private'` and run section 85 again: it must print
`85a PASS`; (c) as an administrator, save one open API issue; (d) signed in as a Standard User holding only Kern API
Issue Resolver, confirm that issue shows on the API Issues list and that **Retry** on its record page runs and marks it
resolved; with `SubscriberRunFlows` assigned too, confirm that **Retry Selected** counts it; (e) and (f) are PASS lines: run `SubscriberApiRecordDeleteGuard_TEST`
on the upgraded org (the same user's **Delete** refused with the Delete API Records message, the administrator's
allowed), and record whether the upgrade gave the System Administrator profile the Delete API Records permission or
the administrator needs the Kern Administrator set. Record the time the recalculation took (by hand). Leave the
constant at `'Private'`, as shipped.

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

The copy takes whole folders, so a class or record added to `release-testing/subscriber/` deploys with no change here.
The 1.8 cycle added the support classes `SubscriberWhoWroteIt` (2.2), `SubscriberLogVolumeEmitter` (section 50),
`TST_RaisingBatch` and `TST_SizeProbeHandler` (section 75c), and the records `kern__ApiSetting.RetryLiveNoRetry` (the
V158 toast step and `SubscriberBulkRetry_TEST`) and `kern__AsynchronousJobSetting.TST_SizeProbeHandler` (section 75c).
If the deploy reports one of them missing, the copy above did not run in full.

Deploy LWC, FlexiPages, tabs, and permission sets:

```bash
mkdir -p /tmp/kern-subscriber/force-app/main/default/{lwc,flexipages,tabs,permissionsets}
cp -r release-testing/subscriber/lwc/* /tmp/kern-subscriber/force-app/main/default/lwc/
cp release-testing/subscriber/flexipages/* /tmp/kern-subscriber/force-app/main/default/flexipages/
cp release-testing/subscriber/tabs/* /tmp/kern-subscriber/force-app/main/default/tabs/
cp release-testing/subscriber/permissionsets/* /tmp/kern-subscriber/force-app/main/default/permissionsets/
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

**Do NOT assign `SubscriberRunFlows` to the admin user.** It grants only the user permission Run Flows, which a managed
package cannot grant through its own sets. V158 and V159 assign it to the Standard User they create, beside Kern API
Issue Resolver, as a subscriber would; without it that user sees no Retry Selected on the API Issues list.

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
sf org assign permset -o $SF_SUBSCRIBER_ORG_ALIAS -n kern__JobRunnerManagement
```

The job runner's journeys and sections 80, 81 and 82 run as this user; putting a job on the runner, running it now
and the runner's own check all need the permission.

The seed probes its own back-dating and reports `auditBackdate=OK` or `auditBackdate=FAILED_ENABLE_AUDIT_FIELDS` in its
debug output; `part10`'s date-range check (V108) hard-fails on the latter with a pointer back to this recipe. The
`CreateAuditFields` permission alone is NOT sufficient, and neither step is available as a Setup UI toggle.

**Profile Filtering on (Phase 2 and Phase 3 regression guard):** Winter '27 enforces the Enable Profile Filtering
release update, and a fresh scratch org may still have it off. Turn it on before Phase 2 so every run exercises the
framework's profile reads under the filter (the framework's selectors and profile-targeted flags read profiles in
system mode and are unaffected; the fixture proves it stays that way):

```bash
sf project deploy start --metadata-dir release-testing/e2e/fixtures/profile-filtering/metadata -o $SF_SUBSCRIBER_ORG_ALIAS
```

Then, from Setup, Release Updates, Get Started, enable the two updates enforced in Spring '27, "Roll Back Platform
Event Trigger Transactions on Unhandled Exceptions" and "Remove Non-Public Fields from Custom Object Data in Aura
Action Responses", before Phase 2 (no metadata deploy sets them). Note all three under Findings in the Phase 4 result
file.

Verify post-install configuration:

```bash
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f /dev/stdin <<< "
Boolean org = kern.UTIL_Cache.isOrgAllocated();
Boolean session = kern.UTIL_Cache.isSessionAllocated();
System.debug('Org Cache: ' + org + ' | Session Cache: ' + session);
" 2>&1 | grep USER_DEBUG
```

Both Health Check indicators should show `true`. The command above is for a person's shell; an agent, whose tools
refuse that form, writes the three Apex lines to a file and runs `sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f <file>`.

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

The **Runner** column says who runs each row. `runner` rows are run by `npm run release:phase2`
(`release-testing/runner/run-phase2.js`), which scores each section against the count in the Expected column. A
`by hand` row is never run by the runner: a person runs it with the commands in its note. The by-hand rows are 32, 33,
40, the load tests 44 to 51, 80 to 84d, 84g to 84j, 86, 87 and the section 83 load, plus the lock-retry, integration callout and
nested chain launch probes below the table. When a row has two or more counts (`1/1 + 3/3`), they are its scripts'
counts in the order they run: the launch script first, then its verify script (76c runs twice, so it has two).

| #   | Script                                                                        | Description                                                                                                                                                                                                                                                                                                                               | Runner | Expected |
|-----|-------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------|----------|
| 1   | `release-testing/scripts/section-1-trigger-lifecycle.apex`                    | Trigger handler lifecycle                                                                                                                                                                                                                                                                                                                 | runner | 6/6 |
| 2   | `release-testing/scripts/section-2-trigger-bypass.apex`                       | Trigger bypass mechanisms                                                                                                                                                                                                                                                                                                                 | runner | 7/7 |
| 3   | `release-testing/scripts/section-3-trigger-feature-flags.apex`                | Trigger + feature flags (requires CMDT state changes)                                                                                                                                                                                                                                                                                     | runner | 8/8      |
| 4   | `release-testing/scripts/section-4-validation-lifecycle.apex`                 | Validation rule lifecycle                                                                                                                                                                                                                                                                                                                 | runner | 7/7 |
| 5   | `release-testing/scripts/section-5-validation-bypass.apex`                    | Validation bypass                                                                                                                                                                                                                                                                                                                         | runner | 8/8      |
| 6   | `release-testing/scripts/section-6-complex-formulas.apex`                     | Complex validation formulas                                                                                                                                                                                                                                                                                                               | runner | 7/7      |
| 7   | `release-testing/scripts/section-7-outbound-api.apex`                         | Outbound API                                                                                                                                                                                                                                                                                                                              | runner | 4/4      |
| 8   | `release-testing/scripts/section-8-api-feature-flags.apex`                    | API feature flags                                                                                                                                                                                                                                                                                                                         | runner | 5/5      |
| 9   | `release-testing/scripts/section-9-cross-framework.apex`                      | Cross-framework integration                                                                                                                                                                                                                                                                                                               | runner | 7/7 |
| 10  | `release-testing/scripts/section-10-shadow-mode.apex`                         | Shadow mode                                                                                                                                                                                                                                                                                                                               | runner | 5/5      |
| 11  | `release-testing/scripts/section-11-execution-strategies.apex`                | Execution strategies (requires CMDT deployments)                                                                                                                                                                                                                                                                                          | runner | 8/8      |
| 12  | `release-testing/scripts/section-12-after-triggers.apex`                      | After triggers                                                                                                                                                                                                                                                                                                                            | runner | 7/7 |
| 13  | `release-testing/scripts/section-13-inbound-api.apex`                         | Inbound API                                                                                                                                                                                                                                                                                                                               | runner | 6/6      |
| 14  | `release-testing/scripts/section-14-dml-builder.apex`                         | DML Builder                                                                                                                                                                                                                                                                                                                               | runner | 7/7 |
| 15  | `release-testing/scripts/section-15-qry-builder.apex`                         | QRY Builder                                                                                                                                                                                                                                                                                                                               | runner | 13/13 |
| 16  | `release-testing/scripts/section-16-log-builder.apex`                         | LOG Builder                                                                                                                                                                                                                                                                                                                               | runner | 10/10 |
| 17  | `release-testing/scripts/section-17-flow-invocables.apex`                     | Flow invocables                                                                                                                                                                                                                                                                                                                           | runner | 8/8      |
| 19  | `release-testing/scripts/section-19-lwc-logger-persistence.apex`              | LWC logger persistence                                                                                                                                                                                                                                                                                                                    | runner | 6/6      |
| 20  | `release-testing/scripts/section-20-flow-logger.apex`                         | Flow logger                                                                                                                                                                                                                                                                                                                               | runner | 7/7      |
| 21  | `release-testing/scripts/section-21-scheduler.apex`                           | Scheduler framework                                                                                                                                                                                                                                                                                                                       | runner | 8/8      |
| 22  | `release-testing/scripts/section-22-*.apex`                                   | Advanced strategies (Custom Permission flags, Fail Fast + flag-gated groups)                                                                                                                                                                                                                                                              | runner | 8/8      |
| 23  | `release-testing/scripts/section-23-trigger-action-ordering.apex`             | Trigger action ordering + feature flag fix verification                                                                                                                                                                                                                                                                                   | runner | 4/4      |
| 24  | `release-testing/scripts/section-24-delegation-overrides.apex`                | Delegation mode caller overrides                                                                                                                                                                                                                                                                                                          | runner | 5/5      |
| 25  | `release-testing/scripts/section-25-scheduler-timezone.apex`                  | Scheduler timezone awareness                                                                                                                                                                                                                                                                                                              | runner | 4/4      |
| 26  | `release-testing/scripts/section-26-log-correlation.apex`                     | Log correlation — end-to-end traceability                                                                                                                                                                                                                                                                                                 | runner | 7/7      |
| 27  | `release-testing/scripts/section-27-mock-selection.apex`                      | Multi-mock selection — priority, pattern, catch-all                                                                                                                                                                                                                                                                                       | runner | 8/8      |
| 28  | `release-testing/scripts/section-28-util-cache.apex`                          | UTIL_Cache — platform cache from subscriber                                                                                                                                                                                                                                                                                               | runner | 7/7      |
| 29  | `release-testing/scripts/section-29-log-scope.apex`                           | LOG_Builder.scope() — scoped logging                                                                                                                                                                                                                                                                                                      | runner | 5/5      |
| 30  | `release-testing/scripts/section-30-resilience-strategies.apex`               | Circuit breaker state machine & retry backoff math                                                                                                                                                                                                                                                                                        | runner | 11/11 |
| 31  | `release-testing/scripts/section-31-failure-handling.apex`                    | Failure handling, retry persistence, failure rate injection, ApiIssue logging; the finally block deletes what it created and proves it by query. Runs inside a MockAllAPIs window (fixture `mock-all-apis-enabled`, restored to `mock-all-apis-disabled`; `npm run release:phase2` does both): each scenario registers its answer through `kern.API_MockFactory`, which stands in for the callout outside a unit test only while the flag is on. | runner | 9/9 |
| 31  | `release-testing/scripts/section-31-failure-handling-cleanup.apex` | 30 seconds after section 31: deletes the log entries section 31 wrote (they land after its transaction ends) with any API_EchoSubscriber call and issue of today, and proves by query that none is left | runner | 1/1 |
| 32  | `release-testing/scripts/section-32-load-test.js`                             | Circuit breaker load test — parallel HTTP via Node (not Apex)                                                                                                                                                                                                                                                                             | by hand | 5/5      |
| 33  | `release-testing/scripts/section-33-knowledge-data-category.apex`             | Knowledge WITH DATA CATEGORY queries (requires Knowledge org)                                                                                                                                                                                                                                                                             | by hand | 5/5      |
| 34  | `release-testing/scripts/section-34-async-chain.apex`                         | Async chain orchestration (DML, context flow, handlers, callout isolation) (launch 34 + verify 34b, `section-34b-async-chain-verify.apex`, 30 seconds later)                                                                                                                                                                         | runner | 11/11 + 9/9 |
| 35  | `release-testing/scripts/section-35-secure-by-default.apex`                   | Secure-by-default USER_MODE posture (flag state, QRY + DML defaults, overrides, systemModeRequired hook)                                                                                                                                                                                                                                  | runner | 8/8      |
| 35  | `release-testing/scripts/section-35-kill-switch.apex`                         | Secure-by-default kill switch (both flags off → SYSTEM_MODE fallback)                                                                                                                                                                                                                                                                     | runner | 4/4      |
| 36  | `release-testing/scripts/section-36-masking-applicable-field-types.apex`      | Masking `ApplicableFieldTypes__c` narrowing — rule skips fields whose DisplayType is outside the list                                                                                                                                                                                                                                     | runner | 4/4      |
| 37  | `release-testing/scripts/section-37-masking-min-input-length.apex`            | Masking `MinInputLength__c` short-circuit + successor-floor probe — sub-13 values skip pattern eval; a 13-digit Luhn-valid card redacts via `MaskPaymentCard` (the old rule's floor of 15 would have skipped it)                                                                                                                          | runner | 3/3      |
| 38  | `release-testing/scripts/section-38-masking-transactionid-preservation.apex`  | Regression guard for the original parent-transaction-ID false-redaction bug (Luhn checksum gate)                                                                                                                                                                                                                                          | runner | 3/3      |
| 39  | `release-testing/scripts/section-39-masking-type-filter-warn.apex`            | Explicit-field `MaskingTarget__mdt` dropped by type filter emits a one-time warn LogEntry (P12)                                                                                                                                                                                                                                           | runner | 1/1 |
| 40  | `release-testing/scripts/section-40-masking-inactive-rule-validation.apex`    | Every shipped masking rule's `Pattern__c` compiles + matches a curated positive + negative sample (active + inactive), and the three whole-value rules (`MaskAddress`, `MaskFreeText`, `MaskPhoneInternational`) mask their sample to the rule's token. The first line reports 18 rules, 3 active and 15 inactive on a fresh install (`MaskCreditCard` ships inactive); 18 PASS lines and no SKIP line; the summary reads `57 passed, 0 failed; 15 inactive rules` | by hand | 57/57    |
| 41  | `release-testing/scripts/section-41-flow-action-subscriber.apex`              | Cross-namespace `kern__TRG_InvokeFlow` dispatch — flow runs, output applied, LogAndContinue, recursion-identity, mock harness, variable contract                                                                                                                                                                                          | runner | 6/6      |
| 42  | `release-testing/scripts/section-42-flow-action-blockdml.apex`                | `FailureAction__c = BlockDml` halts DML when bound flow throws (requires `section-flow-blockdml-active` fixture before; restore via `section-flow-blockdml-default`)                                                                                                                                                                      | runner | 1/1      |
| 43  | `release-testing/scripts/section-43-flow-action-feature-flag.apex`            | `RequiredFeatureFlag__c` gating disables flow action when flag is off (requires `section-flow-flag-disabled` fixture before; restore via `section-flow-flag-default`)                                                                                                                                                                     | runner | 1/1      |
| 44  | `release-testing/scripts/section-44-flow-action-upgrade.apex`                 | Managed-package upgrade compatibility — pre-existing Apex-only `TriggerAction__mdt` rows still resolve after the new flow fields land                                                                                                                                                                                                     | runner | 3/3      |
| 44  | `release-testing/scripts/section-44-load-masker.apex`                         | Load test — `UTIL_FrameworkMasker` bulk: 200 `ApiCall__c` records via `TRG_Dispatcher` inline masking pre-step (emits `PERF_ROW`)                                                                                                                                                                                                         | by hand | 1/1      |
| 45  | `release-testing/scripts/section-45-load-qry-aggregate.apex`                  | Load test — `QRY_Builder` aggregate cardinality: GROUP BY + ROLLUP across high-row counts (emits `PERF_ROW`)                                                                                                                                                                                                                              | by hand | 1/1      |
| 46  | `release-testing/scripts/section-46-load-trigger-fanout.apex`                 | Load test — `TRG_Dispatcher` fan-out + per-action filter under bulk DML (emits `PERF_ROW`)                                                                                                                                                                                                                                                | by hand | 1/1      |
| 47  | `release-testing/scripts/section-47-load-validation-bulk.apex`                | Load test — `UTIL_ValidationRule.executeForTrigger()` bulk: high-row validation group evaluation (emits `PERF_ROW`)                                                                                                                                                                                                                       | by hand | 1/1      |
| 48  | `release-testing/scripts/section-48-load-async-chain-ser.apex`                | Load test — `UTIL_AsyncChain` context serialization launch: enqueues a multi-step chain with large shared context (emits `PERF_ROW`)                                                                                                                                                                                                      | by hand | 1/1      |
| 48b | `release-testing/scripts/section-48b-load-async-chain-ser-verify.apex`        | Verify — chain from section 48 completed successfully (query `AsyncApexJob`)                                                                                                                                                                                                                                                              | by hand | 1/1      |
| 49  | `release-testing/scripts/section-49-load-async-launcher.apex`                 | Load test — `UTIL_AsynchronousJobLauncher` Queueable/Batch: enqueues multiple async jobs in burst (emits `PERF_ROW`); three PASS lines: Queueable side, Batch side, handoff                                                                                                                                                                | by hand | 3/3      |
| 49b | `release-testing/scripts/section-49b-load-async-launcher-verify.apex`         | Verify — async jobs from section 49 completed successfully                                                                                                                                                                                                                                                                                | by hand | 1/1      |
| 50  | `release-testing/scripts/section-50-load-logger-pe-quota.apex`                | Load test — Logger platform event quota: emits ≥150 `LogEntryEvent__e` in one transaction using `LOG_Builder.scope()` (emits `PERF_ROW`); three PASS lines: emit, emitter, handoff                                                                                                                                                         | by hand | 3/3      |
| 50b | `release-testing/scripts/section-50b-load-logger-pe-quota-verify.apex`        | Verify — `LogEntry__c` records from section 50 persisted (polls with delay), and the 50 entries `SubscriberLogVolumeEmitter` wrote in the same transaction persisted too (`50b-emitter`). Its check that the current user raised no API issue today needs the cleanups of 84 and 86 to have run first | by hand | 2/2      |
| 51  | `release-testing/scripts/section-51-load-callout-storm.js`                    | Load test — `UTIL_HttpClient` callout storm: parallel HTTP via Node.js against `REST_LoadProbe` (emits `PERF_ROW`)                                                                                                                                                                                                                        | by hand | 8/8      |
| 52  | `release-testing/scripts/section-52-edge-dml-builder.apex`                    | Edge cases — `DML_Builder`: partial-save flag, parent-child chain, mixed DML types, error aggregation                                                                                                                                                                                                                                     | runner | 8/8 |
| 53  | `release-testing/scripts/section-53-edge-qry-builder.apex`                    | Edge cases — `QRY_Builder`: semi-join subqueries, NOT IN, pagination, field set, scope, all rows, for update                                                                                                                                                                                                                              | runner | 10/10 |
| 54  | `release-testing/scripts/section-54-edge-inbound-api.apex`                    | Edge cases — inbound API: duplicate headers, malformed JSON body, validation-phase abort, missing required fields                                                                                                                                                                                                                         | runner | 4/4 |
| 55  | `release-testing/scripts/section-55-edge-outbound-failure.apex`               | Edge cases — outbound API failure composition: 4xx and 5xx classification, a 502 to a POST without a key not sent again, retry queueing on 503, status 0, failure-rate injection, RETRY_THEN_LOG; cleanup proves by query that no call or issue is left. Runs inside a MockAllAPIs window (fixture `mock-all-apis-enabled`, restored to `mock-all-apis-disabled`; `npm run release:phase2` does both): each scenario registers its answer through `kern.API_MockFactory`, which stands in for the callout outside a unit test only while the flag is on. | runner | 10/10 |
| 55  | `release-testing/scripts/section-55-edge-outbound-failure-cleanup.apex` | 30 seconds after section 55: deletes the log entries section 55 wrote (they land after its transaction ends) with any API_EchoSubscriber call and issue of today, and proves by query that none is left. Section 55's header now names the deferrals SubscriberOutboundRetry_TEST and section 84 fulfil, and 55e asserts that a 502 to a POST without a key is not sent again | runner | 1/1 |
| 56  | `release-testing/scripts/section-56-edge-async-chain.apex`                    | Edge cases — `UTIL_AsyncChain`: `continueOnError`, max-steps guard, error handler context, correlation ID threading (Launch)                                                                                                                                                                                                              | runner | 4/4      |
| 56b | `release-testing/scripts/section-56b-edge-async-chain-verify.apex`            | Verify — chain from section 56 completed (checks error handler ran + step count correct)                                                                                                                                                                                                                                                  | runner | 3/3      |
| 57  | `release-testing/scripts/section-57-edge-cache-ttl.apex`                      | Edge cases — `UTIL_Cache`: TTL expiry, missing partition graceful fallback, `AUTO` mode selection                                                                                                                                                                                                                                         | runner | 5/5      |
| 58  | `release-testing/scripts/section-58-edge-logger.apex`                         | Edge cases — `LOG_Builder`: scope batching, context chain, forRecord, summary, multi-level, PE governor limit                                                                                                                                                                                                                             | runner | 7/7 |
| 59  | `release-testing/scripts/section-59-edge-scheduler.apex`                      | Edge cases — `SCHED_Base`: missing required parameter, type mismatch, default value fallback, cron expression building                                                                                                                                                                                                                    | runner | 4/4 |
| 60  | `release-testing/scripts/section-60-edge-mock-regex.apex`                     | Edge cases — `API_MockFactory` + `API_MockMatcher`: regex mode priority, catch-all, pattern specificity ordering Cleanup proves by query that no call or issue is left. Runs inside a MockAllAPIs window (fixture `mock-all-apis-enabled`, restored to `mock-all-apis-disabled`; `npm run release:phase2` does both): a handler's canned answer and a registered answer stand in for the callout outside a unit test only while the flag is on. | runner | 5/5      |
| 60  | `release-testing/scripts/section-60-edge-mock-regex-cleanup.apex` | 30 seconds after section 60: deletes the API_EchoSubscriber issues and calls of today (the section's mocked answers with statuses 211, 212, 221 and 222 open issues) and proves by query that none is left | runner | 1/1 |
| 61  | `release-testing/scripts/section-61-edge-masking-rollback.apex`               | Edge cases — `UTIL_FrameworkMasker`: DML rollback isolation (masking log survives rolled-back DML), field-length, idempotency                                                                                                                                                                                                             | runner | 5/5      |
| 62  | `release-testing/scripts/section-62-edge-type-resolver.apex`                  | Edge cases — `UTIL_TypeResolver`: interface mismatch error, `Order__c` ties, subscriber-first resolution, missing class                                                                                                                                                                                                                   | runner | 4/4 |
| 63  | `release-testing/scripts/section-63-edge-resilience-comp.apex`                | Edge cases — `UTIL_CircuitBreaker` + `UTIL_Retry` composition: HALF_OPEN regress, the exception filter, retry exhaustion, LOG_FAILURE, breaker + retry composition, backoff math; cleanup proves by query that no call or issue is left. Runs inside a MockAllAPIs window (fixture `mock-all-apis-enabled`, restored to `mock-all-apis-disabled`; `npm run release:phase2` does both): each scenario registers its answer through `kern.API_MockFactory`, which stands in for the callout outside a unit test only while the flag is on. | runner | 7/7 |
| 63  | `release-testing/scripts/section-63-edge-resilience-comp-cleanup.apex` | 30 seconds after section 63: deletes the log entries section 63 wrote (the handler's and its S63_ circuit breakers') with any API_EchoSubscriber call and issue of today, and proves by query that none is left. Section 63's header and scenario 63b now prove the exception filter (`UTIL_Retry.dontRetryOnException`) directly | runner | 1/1 |
| 64  | `release-testing/scripts/section-64-edge-asyncjob-launcher.apex`              | Edge cases — `UTIL_AsynchronousJobLauncher`: max concurrent guard, re-enqueue after failure, job type selection (Launch)                                                                                                                                                                                                                  | runner | 6/6 |
| 65  | `release-testing/scripts/section-65-bypass-audit-framework-wide.apex`         | Framework-wide bypass audit — bypass events persist to `kern__LogEntry__c` from trigger / query / DML / validation surfaces; query/DML entries carry object-qualified targets (`system-mode:Account` / `sharing:Account`) with `object`/`operation`/`rowCount` context naming the operation that ran under the bypass; `BypassAudit_Enabled` kill-switch is default-on; flood-control detail/rollup shape. Orchestrated: the audit trail persists asynchronously, so a single-transaction script raced platform-event delivery (launch 65 (2) + 30s persistence wait + verify 65b (6)); see "Section 65 notes" | runner | 8/8      |
| 66  | `release-testing/scripts/section-66-log-fingerprint.apex`                     | Log-fingerprint flood control (subscriber API) — `kern.LOG_Builder...withFingerprint(key)` collapses repeated entries into one `detail:` sample row + a per-UTC-day `rollup:` counter (`OccurrenceCount__c`); covers flood economy (5 → 2 rows), distinct keys, oversized-key SHA-256 hashing + `fingerprintSource` breadcrumb, reserved-prefix anti-spoofing, and the plain-entry opt-in regression (launch 66 + verify 66b); see "Section 66 notes"                       | runner | 10/10    |
| 67  | `release-testing/scripts/section-67-post-trigger-actions.apex`                | Post-trigger actions — core behaviour: fires once per dispatch (not per record), `Order__c` ascending, touched-SObject context, object-scope filter (Foobar dispatch), entry-criteria skip                                                                                                                                                | runner | 6/6      |
| 68  | `release-testing/scripts/section-68-post-trigger-actions-flag-gate.apex`      | Post-trigger actions — `RequiredFeatureFlag__c` gate: dormant when off (68), fires when on (68b)                                                                                                                                                                                                                                          | runner | 2/2      |
| 69  | `release-testing/scripts/section-69-post-trigger-actions-no-dml.apex`         | Post-trigger actions — no-DML contract guard: exception names synchronous DML + the offending action class, originating DML rolls back                                                                                                                                                                                                    | runner | 2/2      |
| 70  | `release-testing/scripts/section-70-post-trigger-actions-failure-policy.apex` | Post-trigger actions — `FailureAction__c` policy: LogAndContinue commits + swallows (70), BlockDml rolls back + surfaces the exception (70b)                                                                                                                                                                                              | runner | 4/4      |
| 71  | `release-testing/scripts/section-71-cdc-header-recorder.apex`                 | CDC change-event header recorder — probe inserts deliver change events; the recorder Flow receives the typed `DTO_ChangeEventHeader` and the sink records one marker per delivered event; record ids audited back to the source probes (launch 71 + verify 71b)                                                                           | runner | 3/3      |
| 72  | `release-testing/scripts/section-72-cdc-blockdml-degrade.apex`                | CDC BlockDml degrade — on a change-event dispatch the `BlockDml` failure action degrades to LogAndContinue (a committed change cannot be rolled back): a WARN log records the degrade-exclusive `cdc-block-dml-degraded` errorKind (the proof), and the Order-10 recorder co-action + the source rows are intact (launch 72 + verify 72b) | runner | 4/4      |
| 75  | `release-testing/scripts/section-75-queueable-unhandled-exception.apex`       | Queueable unhandled-exception surfacing — a global async step launched via `kern.UTIL_AsynchronousJobLauncher.process(...)` that throws uncaught surfaces as a Failed `AsyncApexJob` with the exception identity preserved in `ExtendedStatus`, and the framework's finalizer writes one ERROR log entry for the job (launch 75 + verify 75b: `75b-verify`, `75b-identity`, `75b-error-log`); see "Section 75 notes" | runner | 1/1 + 3/3 |
| 75c | `release-testing/scripts/section-75c-batch-failure-listener.apex` | Batch failure listener and the launcher's batch size: 75c starts a batch job that throws in one chunk (290 rows) and a job the job launcher sizes from its setting (`kern__AsynchronousJobSetting.TST_SizeProbeHandler`, size 75); verify `section-75d-batch-failure-listener-verify.apex` 60 seconds later: the throwing job's result, its ERROR log entries, the size warning and the launcher job's call count (at least 4; the line prints the real count). 75d reads only rows changed since 75c started, so the pair can be run again | runner | 2/2 + 4/4 |
| 76  | `release-testing/scripts/section-76-masking-advisor-roundtrip.apex`           | Masking advisor round-trip baseline — namespace-safe CMDT + dynamic key-prefix resolution, shipped rule catalogue, posture baseline (the Health Check masking inputs: Pass(4))                                                                                                                                                            | runner | 3/3      |
| 76b | `release-testing/scripts/section-76b-masking-advisor-verify-created.apex`     | Verify — advisor-format create bundle: probe targets re-read field-for-field (packaged-rule references resolve), posture recomputes to 5 objects / 1 dead → Health Check input flips to Warn; the packaged MaskPhoneUS rule is activated via its namespace-qualified record name (rule-activation round-trip)                             | runner | 3/3      |
| 76c | `release-testing/scripts/section-76c-masking-advisor-verify-disabled.apex`    | Verify — disable bundle: probes persist inactive (disable IS the advisor's removal story), MaskPhoneUS dormant again, posture back to Pass(4); re-run once more as the cleanup verification                                                                                                                                               | runner | 3/3 + 3/3 |
| 76d | `release-testing/scripts/section-76d-masking-advisor-verify-reenabled.apex`   | Verify — re-enable bundle: healthy probe active again (dead probe + MaskPhoneUS untouched → bundle-scoped upserts), posture Pass(5) — the PASS-branch Health Check value change                                                                                                                                                           | runner | 2/2      |
| 77  | `release-testing/scripts/section-77-masking-cmdt-collision.apex`              | Masking CMDT name-collision tolerance — an org-local clone of a packaged rule's DeveloperName (seeded by the runner) must NOT brick framework DML: inserts survive on the engine's fallback read and mask identically; after the clone is deleted the fast path resumes and the collision WARN (`detail:masking:cmdt-collision:%`) has persisted (orchestrated: seeded 2 + recovered 3)                                                    | runner | 5/5      |
| 78  | `release-testing/scripts/section-78-abort-gate.apex`                          | Abort gate: core.-prefixed custom-permission strategy resolves against the installed package (78), then re-checks in a fresh transaction after the grant plus the contradictory-row isTerminal probe (78b)                                                                                                                                | runner | 1/1 + 2/2|
| 79  | `release-testing/scripts/section-79-watchdog-sweep.apex`                      | Chain Watchdog sweep: a probe chain seeded as silently-stuck Running (audit-back-dated 45 min) is picked up by a watchdog scheduled through the real platform scheduler and marked Stalled; verify + cleanup in a second execution after the one-off CronTrigger fires (79b)                                                              | runner | 2/2 + 1/1|
| 79c | `release-testing/scripts/section-79c-watchdog-started-step.apex` | Chain Watchdog at a started step: a stuck chain whose current step has started and is not safe to run twice (audit-back-dated 45 minutes, a job id that matches no job) and a one-off watchdog on the next minute; verify `section-79d-watchdog-started-step-verify.apex` after the same 100-second wait as 79: the chain ended Failed with an end time and the `AsyncChain_RecoveryStoppedAtStartedStep` message, then cleanup. 79d prints one FAIL line and deletes nothing while the watchdog has not fired yet | runner | 2/2 + 1/1 |
| 80  | `release-testing/scripts/section-80-job-runner-concurrency.apex`              | Job runner concurrency: one due job, then two job runner checks launched at the very same instant from the shell; the row is claimed once, exactly one run is started, and the second check exits without starting anything (seed 80 + verify 80b)                                                                                       | by hand | 1/1 + 2/2|
| 81  | `release-testing/scripts/section-81-watchdog-and-recipe-on-runner.apex`       | The watchdog and a subscriber recipe both run from the job runner instead of owning a scheduled job each: the watchdog marks a stuck chain Stalled and the recipe starts its chain, neither holding a scheduled-job slot (seed 81 + verify 81b)                                                                                          | by hand | 4/4 + 3/3|
| 82  | `release-testing/scripts/section-82-job-runner-at-volume.apex`                | The job runner at volume: with more jobs due than one check may start, the check starts them in run-priority order up to its per-check limit, leaves the rest untouched, warns once, and the next check picks the rest up (seed 82 + verify 82b + catch-up 82c)                                                                          | by hand | 1/1 + 4/4 + 2/2|
| 83  | `node release-testing/scripts/consoles-at-volume.js run --mode staged`, then `--mode full` (teardown between, see the note) | The consoles at volume: the chain engine loads the org with more than 3,300 runs (one action of 2,028 runs nested three levels deep, 200 small actions, the operator wave pressed through the Chain Monitor, dead-job stalls the scheduled watchdog re-drives when their step is safe to repeat and ends Failed when it is not, and in a release cycle 250 started-step rows it must end Failed); staged mode in about twenty minutes, then full mode in about an hour; verify prints one line per claim and the drain rate; see "Section 83 note" | by hand | every claim PASS, both modes |
| 84  | `release-testing/scripts/section-84-outbound-retry-live.apex` | Outbound retry classification live: three handlers at a Named Credential that does not exist (GET, unkeyed POST, keyed POST); the GET and keyed POST rest at Retry with a time, the unkeyed POST fails at once with the labelled issue; a callout refused after a save rests at Retry unmarked, with no retry left it ends Failed unmarked; a half-open circuit starts a new round of trials; queues the Queueable and after-a-delete refusals (Launch). None of these Named Credentials may exist on the org: `RetryLiveDoesNotExist`, `RetryLiveNeverSentSave`, `RetryLiveNeverSentNoBudget`, `RetryLiveNeverSentQueueable`, `RetryLiveNeverSentDelete`, `RetryLiveSeparateCounts`. 84 and 86 share the `RetryLive` rows: run one after the other, never interleaved | by hand | 5/5 |
| 84b | `release-testing/scripts/section-84b-outbound-retry-live-verify.apex` | Verify, at least 90 seconds later: the two scheduled rows ended Failed with one retry spent, the queued refusals rest at Retry unmarked with no breaker failure, nothing rests at Retry without a time, the breaker counted every callout that left the org; 84f-1: two breaker names on one credential keep separate failure counts; 84f-2: an open circuit with retry budget left rests at Retry with the circuit's wait and one retry counted; then resets the breakers, deletes every RetryLive call, issue, log entry and Foobar and proves by query that no call, issue or Foobar is left (prints SECTION84 PENDING and is run again 30 seconds later while a retry or job is still running). 84f-1 and 84f-2 print a PASS line and skip when no org cache is allocated | by hand | 7/7 |
| 84  | `release-testing/scripts/section-84-outbound-retry-live-log-cleanup.apex` | 30 seconds after 84b (and after 84e on the development org): deletes the RetryLive log entries, which land after each script's transaction ends (a breaker reset writes one), and proves by query that none is left | by hand | 1/1 |
| 84c | `node release-testing/scripts/section-84c-inbound-error-handling-live.js` | An inbound handler whose processing throws and whose handleError override throws too, called over a real REST call: answered 500 with both messages, one Failed call record, and exactly one Open inbound issue linked to it that keeps no copy of the request (84c-3); then checks it finds exactly that call and that issue (a missing or extra row is a FAIL and nothing is deleted), deletes the issue before the call, then the log entries, and proves it by query. Needs Kern Administrator on the running user (Delete API Records) | by hand | 4/4 |
| 84d | `release-testing/scripts/section-84d-bulk-retry-development-org.apex` | The development-org rehearsal. Section 84d starts the bulk retry through the per-service `CTRL_RetryApiIssue.scheduleBulkRetry(service, delay)`, which is not global, so it runs on the development org; on the subscriber org the same background job is started through the global Flow action `kern.FLOW_RetryApiIssues.retryApiIssues`, which section 86 runs at volume. 84d seeds three Open issues, one marked External System May Have Acted, and schedules the bulk retry; verify 84e 30 seconds later: both unmarked issues sent as one batch with none refused for pending work, the marked issue skipped and the skip logged; then deletes and proves by query; then the 84 log cleanup 30 seconds later | by hand | 1/1 + 3/3 |
| 84g | `node release-testing/scripts/section-84g-inbound-issue-live.js` | An inbound request that fails, then succeeds when the caller sends it again, over real REST calls to `API_RetryLiveOnHold` (it fails while an Account named "RetryLive hold" exists, the script creates and deletes it). Every request is sent by the running user, because an Idempotency-Key belongs to the user who sent it: a keyed request that failed and its retry with the same body link (Previous Attempt) and resolve the issue; a corrected body with the same key resolves the issue and links to nothing, and the first body sent again is answered 409; deleting a call whose issue is Open is refused with the `DeleteApiCall_OpenIssue` label; a request without a key fails, and the global Flow action `kern.FLOW_RetryApiIssues.retryApiIssues` queues its replay (Launch). Prints `SECTION84 PENDING` and the 84h command with the ids. When a check fails it starts no replay and deletes its own rows, issues first. Needs Kern Administrator on the running user, `API_RetryLiveOnHold`, `REST_RetryLiveOnHold` and `kern__ApiSetting.RetryLiveOnHold` | by hand | 7/7 |
| 84h | `node release-testing/scripts/section-84h-inbound-replay-live-verify.js` with the arguments 84g printed | Verify, at least 60 seconds after 84g: the replay made one Completed call that holds the body of the failed call and links to it (Previous Attempt), the replayed issue is Resolved and the replay wrote no issue; then checks it finds exactly the calls and issues 84g listed plus the replay's call (a missing or extra row is a FAIL and nothing is deleted), deletes the issues before the calls, then the log entries, and proves it by query. Prints `SECTION84 PENDING`, deletes nothing and exits with code 2 while the replay's job runs (run it again 30 seconds later) | by hand | 3/3 |
| 84i | `node release-testing/scripts/section-84i-keyless-inbound-call-before-upgrade.js` | Upgrade leg that starts on 1.8.0-11 only (1.3b; a leg starting on 1.9 or later skips it), between the two installs, while the org is on the released version: a request without an Idempotency-Key sent to `API_RetryLiveOnHold` while it is on hold fails, and exactly one Failed call is saved with no key, no hash of its body and the body whole; no issue is written. Prints `SECTION84 PENDING` and the 84j command with the time and the call id. When a check fails it deletes its own rows. Needs Kern Administrator on the running user, and only `API_RetryLiveOnHold`, `REST_RetryLiveOnHold` and `kern__ApiSetting.RetryLiveOnHold` deployed before the upgrade | by hand | 2/2 |
| 84j | `node release-testing/scripts/section-84j-keyless-inbound-replay-after-upgrade.js` with the arguments 84i printed | Upgrade leg that starts on 1.8.0-11 only (1.3b; a leg starting on 1.9 or later skips it), after the upgrade and the 1.4 deploy, not while 84g's rows are there: saves an Open inbound issue by hand on the call 84i saved (no copy of the request) and runs it through the global Flow action `kern.FLOW_RetryApiIssues.retryApiIssues`; the job Completed, the replay made one Completed call that holds the body of the call 1.8 saved and links to it (Previous Attempt), the issue is Resolved and the replay wrote no issue; then checks it finds exactly those calls and that issue (a missing or extra row is a FAIL and nothing is deleted), deletes the issue before the calls, then the log entries and any hold Account, and proves it by query. Waits up to three minutes for the job; while it still runs, prints `SECTION84 PENDING` with a command to run 30 seconds later, deletes nothing and exits with code 2 | by hand | 5/5 |
| 85  | `release-testing/scripts/section-85-sharing-defaults.apex` | The sharing default of the four framework objects: API Issue, Log Entry, API Call and Async Chain Execution all read Private on a fresh install (one check, `85a`). Phase 1.3 runs it as shipped; on the upgrade leg (1.3b) a person edits the constant `EXPECTED_API_ISSUE_AND_LOG_ENTRY_DEFAULT` at the top of the script and runs it twice (see 1.3b). The runner runs it as shipped on the fresh-install org | runner | 1/1 |
| 86  | `release-testing/scripts/section-86-bulk-retry-at-volume.apex` | Bulk retry at volume on the subscriber org, through the global Flow action `kern.FLOW_RetryApiIssues.retryApiIssues`: seeds 450 Open issues (outbound at a Named Credential that does not exist, some marked External System May Have Acted, some whose call is still in progress, and inbound issues of `API_SubscriberCreateAccount`, each linked to a Failed inbound call that holds its request and the SHA-256 hex of its body, as a failed request leaves them) and presses the action once (Launch). Run first. Needs Kern Administrator on the running user, the `RetryLive` handlers and settings of section 84 and no Named Credential `RetryLiveDoesNotExist`, `SubscriberCreateAccount` active with Retry Issues on and Mocking Enabled off (section 27 turns it on and back off), no active masking rule that changes the inbound bodies (76b turns MaskPhoneUS on, 76c off), the RetryOutboundApiCall flow active, and no `RetryLive` rows left from section 84 | by hand | 2/2 |
| 86b | `release-testing/scripts/section-86b-bulk-retry-at-volume-verify.apex` | Verify, at least 3 minutes after 86: one call per request, each ended Failed with its one retry spent; the issues held back and the ones whose call is in progress stay Open, with the "still in progress" warnings adding up to 10; the 14 Queueables Completed, nothing deferred, no call refused before it left the org. Prints `SECTION86 PENDING` and deletes nothing while a job runs or a call waits for its retry (run it again 30 seconds later); prints the section 86 `PERF_ROW` lines; then deletes the outbound leg | by hand | 7/7 |
| 86c | `release-testing/scripts/section-86c-bulk-retry-inbound-leg.apex` | After 86b: the inbound issues were replayed and resolved, one Account per replay, and the 240 inbound calls are the 120 seeded calls, still Failed, and one Completed replay call per issue, each linked to a different seeded call (86c-3); then deletes the inbound leg, issues before calls. Precondition for the whole family: an Asynchronous Job Setting record `kern_FLOW_CallApiAsync` with a batch size of 10 on the org before 86 (at the default of 20, twenty inbound replays in one job reach the 150-DML limit: the 1.8 known issue), removed after 86c. Then run `section-84-outbound-retry-live-log-cleanup.apex` for the log entries | by hand | 4/4 |
| 87  | `release-testing/scripts/section-87-purge-at-volume.apex` | Purge at volume: tops up a seed of 5,000 API calls back-dated more than 365 days (needs the audit-field recipe of Phase 1.4 and Kern Administrator) and, on the run that completes the seed, schedules the purge job. Earlier runs print one `SECTION87 PENDING` line: run it again until the two PASS lines print. **Destructive:** the purge deletes every API call older than 365 days on the org; run it only on a fresh scratch org | by hand | 2/2 |
| 87b | `release-testing/scripts/section-87b-purge-at-volume-verify.apex` | Verify, at least 4 minutes after the run of 87 that scheduled the job: no API call older than 365 days is left, the purge's batches all Completed, and no "Delete API Records" refusal was logged; prints `SECTION87 PENDING` and deletes nothing until the job has fired and its batches ended (run it again 30 seconds later), for at most about 10 minutes after the job's time; after that it prints its FAIL lines; prints the section 87 `PERF_ROW` lines; then deletes the scheduled job row and any seeded row left | by hand | 4/4 |

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
SubscriberCreateAccount and `IsEnabledByDefault__c = true` on MockAllAPIs and on MockSelectedAPIs), run script, then deploy
`section27-mock-disabled` to restore defaults (all three back to false). Mocking Enabled on an API Setting only picks the
service: it answers from mock data when Mock Selected APIs is also on for the running user, in both directions, so the
inbound tests of section 27 need the flag on. Every fixture file for a packaged flag is named `kern__FeatureFlag.kern__<flag>`
(the section 27, `mock-all-apis-*` and `section35-flags-*` states), so a deploy changes the packaged record. A file named
without the second `kern__` creates a record of the same name in the subscriber's own namespace instead. The flag index keeps
one record per name and the last one read wins, so that copy would decide the flag in place of the packaged one. An org that
ran these states before the files were renamed may hold such copies. To delete them, save copies of the two fixture files
under their old names (the record names `kern__FeatureFlag.MockSelectedAPIs` and `kern__FeatureFlag.MockAllAPIs`, each with the
metadata file ending), in a
scratch project, and run `sf project delete source -o <alias> -m CustomMetadata:kern__FeatureFlag.MockSelectedAPIs -m
CustomMetadata:kern__FeatureFlag.MockAllAPIs --no-prompt` from it (the command deletes those local copies too; add the two
`UserModeDml_Enabled` and `UserModeQueries_Enabled` names the same way for section 35). Only the section 27 states change
the packaged Mock Selected APIs record's Enabled By Default, and `section27-mock-disabled` sets it back.
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

**Section 78 note:** run `section-78-abort-gate.apex` then `section-78b-abort-gate-granted.apex` in a SECOND execution — the grant is not visible to permission checks inside the granting transaction. Requires the 1.6.0+ managed package (the `AsyncChainAbort` permission set + `AsyncChainAbort_Enabled` flag). `npm run release:phase2` handles the two executions (`runSection78`); manually:

```bash
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-78-abort-gate.apex 2>&1 | grep USER_DEBUG
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-78b-abort-gate-granted.apex 2>&1 | grep USER_DEBUG
```

**Section 79 note:** launch + verify split. `section-79-watchdog-sweep.apex` seeds the stale probe
(requires the Phase 1.4 audit-field back-dating — the probe's `CreatedDate`/`LastModifiedDate` are
back-dated 45 minutes to satisfy the shipped stale predicate without a real 30-minute wait) and
schedules a one-off watchdog via `System.schedule` on the next minute boundary, exercising the real
scheduler path with the recommended typed parameters. Run `section-79b-watchdog-sweep-verify.apex`
after the fire time the launch debugs (~90 seconds). 79b hard-gates only the Stalled flip; the
stall-notification trail is reported observationally (the probe carries no persisted onError handler
and log persistence is event-driven). 79b's cleanup aborts any lingering CronTrigger and deletes the
probe + its log entries, returning the org to the watchdog-unscheduled baseline:

```bash
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-79-watchdog-sweep.apex 2>&1 | grep USER_DEBUG
sleep 100
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-79b-watchdog-sweep-verify.apex 2>&1 | grep USER_DEBUG
```

**Section 79c note (the watchdog at a started step):** the same launch + verify shape and the same audit-field
prerequisite as 79. 79c seeds a chain stuck as Running whose current step has started (its step log says so, and the
step does not say it is safe to run twice) with a job id that matches no job, and schedules a one-off watchdog on the
next minute. 79d, after the same 100-second wait, checks the watchdog did not run the step again: the chain ended
Failed, with an end time and the `AsyncChain_RecoveryStoppedAtStartedStep` message in its error message, then it
cleans up. While the watchdog has not fired, 79d prints one FAIL line and deletes nothing: wait and run 79d again. If
79 and 79c run close together each watchdog also sweeps the other's probe, with the same result.
`npm run release:phase2` runs the pair after section 79 (`runSection79c`); manually:

```bash
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-79c-watchdog-started-step.apex 2>&1 | grep USER_DEBUG
sleep 100
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-79d-watchdog-started-step-verify.apex 2>&1 | grep USER_DEBUG
```

**Section 80, 81 and 82 note (the job runner):** three launch + verify sections, all three needing the
`kern__JobRunnerManagement` permission set on the runbook user (Phase 1.4) — putting a job on the runner, running
one now and the runner's own check all refuse without it. Section 80 proves that two checks starting at the very
same instant never start one occurrence twice: the seed leaves one job due, two checks are launched in parallel
from the shell (`wait` joins them), and 80b asserts the row was claimed once, that exactly one run was queued, and
cleans up. The seed also creates the `JobRunner` row of `kern__ScheduleSetting__c` when the org has none: every check
records its time on that row, Activate creates it before it schedules the first check, and this section launches its
checks without activating the runner, so it puts the org in the state a real runner's checks meet. The row stays
afterwards, as it does on any org whose runner was once activated. Section 81 proves the framework's own jobs run
from the runner without each holding a scheduled-job slot: a stale chain, a watchdog record and the
`Recipe_ScheduledChain_DEMO` record all set to job-runner mode, one check scheduled through the platform, then 81b
asserts the chain went Stalled, the watchdog record succeeded with no slot of its own, and the recipe's chain
started. Section 82 proves the volume promise: with ten more jobs due than one check may start, the check starts
exactly the per-check limit in run-priority order, leaves the rest untouched, writes one warning naming how many
were left, and the next check picks them up in silence. Each section's last script cleans up after itself,
returning the org to the no-runner baseline.

Four timing rules. Section 82 looks for its left-waiting warning inside a time window (five minutes in 82b, ten in
82c), so run its five commands back to back as listed; if a run is abandoned part-way, run 82c once before seeding
again (its cleanup removes the checks' log entries and the probe rows). Do not run the three sections in parallel
with each other. Log persistence is platform-event-driven, so the short `sleep` before each verify gives
the check's own warning time to land; 82b says so in its failure message, and re-running a verify once is the
right response before treating a missing log entry as a product failure. Section 81 waits 120 seconds rather than
79's 100, because it has one asynchronous hop more (scheduler, check, run, then the watchdog's own work); 81b
cleans up whether or not it passed, so a too-short wait is answered by re-running the whole of section 81, never
by re-running 81b alone. Do not start section 82 in the two minutes before midnight UTC: its probes run daily at
that instant, and a started one would fall due again.

```bash
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-80-job-runner-concurrency.apex 2>&1 | grep USER_DEBUG
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-80-check.apex > tmp/section-80-check-a.log 2>&1 &
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-80-check.apex > tmp/section-80-check-b.log 2>&1 &
wait
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-80b-job-runner-concurrency-verify.apex 2>&1 | grep USER_DEBUG

sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-81-watchdog-and-recipe-on-runner.apex 2>&1 | grep USER_DEBUG
sleep 120
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-81b-watchdog-and-recipe-on-runner-verify.apex 2>&1 | grep USER_DEBUG

sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-82-job-runner-at-volume.apex 2>&1 | grep USER_DEBUG
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-80-check.apex > tmp/section-82-check-1.log 2>&1
sleep 20
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-82b-job-runner-at-volume-verify.apex 2>&1 | grep USER_DEBUG
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-80-check.apex > tmp/section-82-check-2.log 2>&1
sleep 20
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-82c-job-runner-at-volume-catchup.apex 2>&1 | grep USER_DEBUG
```

**Section 86 and 87 notes (bulk retry and purge at volume, run by hand):** each script's header lists its
preconditions in full; the table rows give the short form. Order and timing:

- Run sections 84, 84b and the 84 log cleanup first, then 86, 86b, 86c and the 84 log cleanup again. 84 and 86 read
  the same `RetryLive` rows, so never interleave them; 86 refuses to start while `RetryLive` rows are left.
- Run section 50b after the cleanups of 84 and 86: its check that the current user raised no API issue today fails
  while their issues are still there.
- Section 87 is destructive by design: its purge deletes every API call older than 365 days on the org. Run it on the
  fresh scratch org only, never on an org whose old API calls you want to keep.

```bash
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-86-bulk-retry-at-volume.apex 2>&1 | grep USER_DEBUG
sleep 180
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-86b-bulk-retry-at-volume-verify.apex 2>&1 | grep USER_DEBUG
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-86c-bulk-retry-inbound-leg.apex 2>&1 | grep USER_DEBUG
sleep 30
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-84-outbound-retry-live-log-cleanup.apex 2>&1 | grep USER_DEBUG

sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-87-purge-at-volume.apex 2>&1 | grep USER_DEBUG
sleep 240
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-87b-purge-at-volume-verify.apex 2>&1 | grep USER_DEBUG
```

Run 86b again every 30 seconds while it prints `SECTION86 PENDING`, and 86c the same way. Run 87 again while it prints
`SECTION87 PENDING` (each run tops the seed up); the 4-minute wait starts at the run that prints its two PASS lines.
87b waits for at most about 10 minutes after the job's time; after that it prints its FAIL lines instead of PENDING.
Harvest the `PERF_ROW` lines of 86b and 87b with Phase 2.5.

**Owed at 1.8 release testing (recorded 2026-09-19):** sections 80, 81 and 82 and the journeys V138 to V141 were
written and reviewed before the 1.8 package was built, and have never run against an installed package; so was V155
(added 2026-10-01), in which a Standard User holding only the Kern Job Runner Management permission set creates a job,
puts it on the runner and runs it now, and finds no Delete and no edit on the platform job id; so was V156 (added
2026-10-03), in which a class deployed after the editor stored its list is typed in and accepted, and a name no
deployed class has is refused under the field; and V157 (added 2026-10-03), which walks the Scheduled Jobs Fast
Start's screen steps by the labels the guide names; it needs FastStart_ScheduledJob_DEMO from Phase 1.4. They are
owed in the first 1.8 release-testing cycle, in this order: `npm run test:e2e:part1` (V1's eleven checks on a
fresh org, the three job-runner rows among them), `npm run test:e2e:part4 -- --grep "V138|V156" --no-deps`, `npm run test:e2e:part11`,
then the three Apex sections above. Every assertion in them was proved for logic on the development org against
no-namespace copies; what the cycle still has to prove is the namespaced package: the `kern.` and `kern__` names
the scripts and journeys use, the `kern__JobRunnerManagement` assignment, and section 81's
`Recipe_ScheduledChain_DEMO` record, whose class is a Phase 1.4 subscriber artifact and so is absent from the
development org.

**Owed at 1.8 release testing (recorded 2026-10-06):** `SubscriberOutboundRetry_TEST`, `SubscriberBulkRetry_TEST`,
sections 84 to 84c, V158 and V159 (added 2026-10-06): the outbound retry classification, the Kern API Issue Resolver
set, the External System May Have Acted field and Retry Selected on the API Issues list, proved for logic on the
development org against no-namespace copies and owed on the namespaced 1.8 install, in this order:
`npm run test:e2e:part2 -- --grep "V158|V159" --no-deps` (without `--no-deps` Playwright first runs the
scheduler-serial journeys the part depends on, and part 1 purges every log entry on the org), section 84, then 84b at least 90 seconds later (again
every 30 seconds while it prints SECTION84 PENDING), then `section-84-outbound-retry-live-log-cleanup.apex` 30 seconds after 84b, then section 84c; and sections 31, 55, 60 and 63, each inside a
MockAllAPIs window and followed 30 seconds later by its cleanup script (`npm run release:phase2` runs all four that way;
since 1.8 a registered answer stands in for a callout outside a unit test only while MockAllAPIs is on). Sections 84d
and 84e are the development-org rehearsal: 84d starts the bulk retry through the per-service
`CTRL_RetryApiIssue.scheduleBulkRetry(service, delay)`, which is not global. On the subscriber org the same background
job is started through the global Flow action `kern.FLOW_RetryApiIssues.retryApiIssues`, which section 86 runs at
volume (450 issues, 14 Queueables). Three checks belong to the first
1.7.0-13 to 1.8 upgrade leg (Phase 1.3b) and to nothing else, because a fresh install cannot make them: (a) before the
upgrade, run `release-testing/scripts/upgrade-stranded-call-baseline.apex` on the 1.7 install and note the stranded row's id (the
row is stored under `kern.UTIL_HttpClient.DefaultOutboundHandler`, its address names the credential); after the
upgrade, confirm the row still reads `Retry` with no `Next Retry` and that the release note's filter (Status equals
Retry, Next Retry empty) finds it, then run the release note's script
(`release-testing/scripts/mark-stranded-outbound-calls-failed.apex`, the note's script byte for byte; first run
`node release-testing/runner/note-script-check.js`, which exits 0 and prints one `SAME` line per copy when the pack's
copies match the release note, and exits 1 naming the first line that differs when one does not; refresh the copy from the
note before going on) on the upgraded org, confirm the row reads `Failed` with no
time and no issue appeared, and delete it with `release-testing/scripts/upgrade-stranded-call-verify.apex` and, at least 30 seconds after the
baseline, its log entry with `release-testing/scripts/upgrade-stranded-call-log-cleanup.apex`; (b) after the upgrade, query `SetupEntityAccess` joined to
`CustomPermission` for `RetryApiIssue` and record which profiles hold it (the release note's advice to an administrator
who works through a profile alone rests on this); (c) open an API issue on the upgraded org and record whether
**External System May Have Acted** shows in the highlights (the compact layout) and beside Status (the flexipage):
which of the flexipage, the compact layout and the page layout an upgrade delivers to an existing org is unverified,
and this check is the measurement; if the field shows in neither place, the release note's line telling an
administrator to add it stands, otherwise the line is struck or narrowed to the layout that did not arrive.

**Owed at 1.8 release testing (recorded 2026-10-10):** two chain run checks for the 1.7.0-13 to 1.8 upgrade leg
(Phase 1.3b), and one API issue check for both legs. (a) On the 1.7.0-13 install, before the upgrade, run
`release-testing/scripts/upgrade-repair-ended-chain-runs-seed.apex`: it inserts two chain runs left Stalled with an
end time, one whose steps all succeeded and one with a failed step. After the upgrade, run
`node release-testing/runner/note-script-check.js` (exit 0 and one `SAME` line per copy; on exit 1 refresh the copy
from the release note first), then `release-testing/scripts/upgrade-repair-ended-chain-runs.apex` (the release note's
script in "A chain run that has ended stays ended", byte for byte; it must print two `Repaired` lines), then
`release-testing/scripts/upgrade-repair-ended-chain-runs-verify.apex`. Expected: three `REPAIRSEED ... PASS` lines:
one run set back to Completed and one to Failed with Step Exception, both end times unchanged, and a direct edit of the
Completed run back to Running refused with the `AsyncChain_TransitionRefused` message. The verify deletes both rows;
the refused edit leaves one ERROR log entry, which stays as the record. (b) Optional once the verify's refusal line
passes: on the upgraded org, try the same direct edit from a run's record page. Expected: the save is refused, and the
error shows the refusal label's text. (c) The inbound replay is now proved by
`SubscriberBulkRetry_TEST.shouldReplayAnInboundIssueAndResolveItThroughTheFlowAction` (2.2) and section 86c. On each
leg, still open an API issue raised by a failed inbound call and press **Retry** on its record page. Expected: Retry
on an inbound API issue's record page replays the inbound call; it is not refused, and it is not sent out as an
outbound call.
Record each outcome in the results file.

**Also owed (recorded 2026-09-20):** V143 and V144 (`part10-log-console.spec.js`), written after this paragraph, are owed in the same first 1.8 release-testing cycle; they cover
the Source column's writer and sort and the detail drawer's icons and copy button names.

Two things only the installed package can show, and what to do if either bites. **If
`section-80-check.apex` will not compile** on its `Schedulable` cast, that is a defect in the script, never a
reason to widen the class: replace the two shell launches with two one-off `System.schedule` calls for the same
minute in the section 80 seed, named `Section 80 Job Runner Check A` and `Section 80 Job Runner Check B` (the
section 81 shape), wait 100 seconds, then run 80b with both scheduled jobs aborted in its cleanup; record the
change here and re-run the section. **If a seed fails with a field-access error on `kern__NextRunAt__c`**, that
is a script matter too: all three seeds back-date that cursor by an update from anonymous Apex, and the
Administrator permission set grants the field read-only because it is framework-owned by design, so the write
rests on the installing administrator's own field access. Grant it for the run, or seed the cursor another way:
it is not a product failure.

**Section 83 note (the consoles at volume):** one command loads the org in five stages (preflight,
launch, drain, operate, verify) and records each in `tmp/consoles-at-volume/manifest.json`; running the command
again skips the stages the manifest records as done, except verify, which always runs again. Run it after the
Phase 1.4 artifacts and after `seed-log-volume.mjs`, in its own window: staged mode first (about twenty minutes),
where the engine runs one of the thirteen roots, twelve of the 200 small actions and a smaller operator wave, and
the rest of the rows are copied from what the engine wrote. When every claim reads PASS, tear the staged load down
and run full mode, where the engine runs everything (about an hour at size 1). The teardown is needed because the
driver refuses a run whose mode differs from the manifest's. It is the step between the two modes, and before
any re-run in a different mode, never the last step. A release cycle's full run lays 250 started-step rows
(`--stalled-started 250`, described below).

```shell
node release-testing/scripts/consoles-at-volume.js run --mode staged
node release-testing/scripts/consoles-at-volume.js teardown --mode staged
node release-testing/scripts/consoles-at-volume.js run --mode full --stalled-started 250 > tmp/consoles-at-volume/full-run.log 2>&1
```

**`--org <alias>`** points the whole run at an org other than the runbook's subscriber org: the queries, the class
deploy the preflight makes on an org without the package, and the browser that presses the Chain Monitor's buttons.
Without it, every part uses `SF_SUBSCRIBER_ORG_ALIAS`.

The full run writes its output to `tmp/consoles-at-volume/full-run.log` (the folder the staged run created) and
keeps its exit code, so read the log for the claim lines when the command ends.

What preflight checks. The run user needs the AsyncChainRedrive, AsyncChainAbort and AsyncChainKillSwitch
permission sets; preflight assigns any of the three that is missing. It refuses to start when the run user lacks
`KernE2EAuditFieldAccess` (the audit-field recipe, Phase 1.4), when the org's `SubscriberChainSteps` lacks the
volume steps (deploy the Phase 1.4 artifacts again), when an INFO entry does not persist within thirty seconds
(raise the org's log level to INFO), and when the org's remaining data storage is below what the run projects.
It also refuses when rows of an earlier load are in the org with no verified manifest to reuse: run
`node release-testing/scripts/consoles-at-volume.js teardown --mode <the manifest's mode>` first, adding
`--size <the manifest's size>` when that load was laid at a size other than 1. Teardown needs that earlier
load's manifest on disk to run at all, so keep `manifest.json` in place until the load is torn down; orphan
rows with no manifest on disk at all have no documented remedy yet (a driver follow-up, board row 147).

What the operate stage leaves behind. It schedules twelve platform jobs named `Consoles At Volume Watchdog 00` to
`Consoles At Volume Watchdog 55`, one every five minutes, each with a 3-minute stale threshold. They stay until a
teardown aborts them or the org is discarded. The probe of 2026-09-24 found no in-engine cause for a genuine
`Stalled` row, so the operate stage lays ten synthesized `Stalled` rows instead (two in staged mode), and the
manifest marks them `synthesized`. If the operate stage fails half-way, it cannot resume: tear down and run
again.

**The dead-job stalls** (twenty in full mode, two in staged). The operate stage launches chains with a ten-minute
delay and aborts their queued first hop. Half of them (the odd one included) start on a step that declares itself safe
to run twice, and the watchdog must re-drive each of those and see it end Completed. The other half start on a step
that is not safe to run twice. A step counts as started once it is handed to the platform, and an aborted job looks
the same whether it died in the queue or mid-work. So the watchdog must end each of these Failed with the "Recovery
stopped at step" reason and an end time, and write one ERROR entry for it. Since 1.8 the watchdog re-drives a dead
job's run only when its step is marked safe to repeat. Verify waits up to twenty minutes for both outcomes.

**The started-step rows (`--stalled-started <n>`, none by default; 250 for a release cycle).** The operate stage also
lays `<n>` Stalled rows whose current step had started and saved no result, without saying it is safe to run twice.
Each row names a background job that does not exist. The watchdog must end every row Failed with the "Recovery
stopped at step Create Foobar" reason and an end time, and write one ERROR entry for it. It must never run the step
again. One sweep looks at fifty rows at most and ends about thirty (32 on the development org on 2026-10-11), so 250
rows take about nine sweeps. Verify waits twenty minutes plus five for every twenty-five rows (seventy at 250). Verify
adds three claims for these rows: they ended Failed at the started step, one ERROR entry each, and no backstop refusal
on them. For the whole run, it adds that the watchdog logged no failure since the load started: no ERROR entry whose
short message starts `Watchdog re-drive failed` or `Watchdog stall DML failed`. A sweep that dies on a platform limit
logs nothing; its rows stay Stalled, which the claims above catch. A failed started-step or dead-job claim is a
finding for the engine, to raise before promotion.

What verify prints. One `PASS:` or `FAIL:` line per claim, then four `EVIDENCE:` lines (`engine`, the runs the
engine wrote and any genuine `Stalled` rows; `operator`, the retries, restarts, aborts, kill-switch aborts, the
dead-job re-drives by the watchdog and the dead-job runs it ended Failed at the started step; `clone`, the rows
copied in staged mode; `fixture`, the synthesized `Stalled` rows), so a synthesized row is never read as engine
behaviour. Then its `PERF_ROW` lines, one line for each measure it has: runs, `jobsPerMinute`, `peakActive`,
`peakHolding`, `samplesAboveFifty`, `watchdogRowsPerSweep` (the most started-step rows one sweep ended),
`backstopRefusals` and `lockRefusals`. A `verify:` line gives the busiest sweep's queries, DML statements and CPU
time, read from its log entries. The platform keeps no record of one sweep's wall time, so none is measured.

**The harvest names the package version**, so a release starts its own baseline. Phase 2.5's harvest reads the
rows from the full run's log, the same way it reads the other sections' rows:

```shell
node release-testing/runner/perf-history.js --logfile tmp/consoles-at-volume/full-run.log --package-version <the installed version>
```

On the development org, which has no package, `--development-org` in place of `--package-version` files the rows
under the version line of `sfdx-project.json` with `-dev` added, for example `1.8.0.NEXT-dev` once the line is bumped.

Each harvest that finds a `PERF_ROW` line adds it to `release-testing/results/perf-history.json` and saves that
file, so harvest each full run's log once. The driver exits 1 while any claim fails, and this command prints
every stage with its outcome and reason:

```shell
node release-testing/scripts/consoles-at-volume.js status
```

What verify also counts. The verify stage counts two kinds of log line made since the load started, and records
both in the manifest (`stages.verify.counts`) and in its output line `verify: <n> backstop refusals, <m> lock
refusals`. `backstopRefusals` counts the times the framework tried to change a chain run's status and was refused,
because another process changed the same run after the framework read it; the check that refuses such a change is
called the status backstop. `lockRefusals` is the number of the framework's saves that failed because another
transaction held a row lock. Read it as "at least this many": per-row failures of a partial save are logged in
another form and are not counted. Both are expected to read 0 or close to it. They never fail a run: the numbers
feed the next release's decision on a row lock for chain runs. Copy both into the results row.

Two timing rules. Run one load at a time, and never beside sections 34, 48, 49, 79 or 81: 34 and 48 enqueue
chains of their own, which the drain stage counts in its queue depth and its jobs per minute, 49 enqueues
Queueables through the job launcher, which its queue depth counts, and 79 and 81 run a watchdog over stuck
chains, while this load's watchdog jobs sweep every chain in the org with a 3-minute threshold, so each would
re-drive or mark the other's rows. Log persistence is platform-event-driven, so a
verify can read a log entry before it lands: re-run verify once before treating a missing log entry as a
product failure.

After the full run, the loaded org stays for the exploration at volume (Phase 3) and the consoles' hero capture
(Phase 4.5, step 5), both of which run on it before Phase 3's battery. Phase 3 then replaces it with a staged
load of its own (see "Exploration at volume"). Teardown after the full run is not a step of this runbook; if it
is ever needed, it is `node release-testing/scripts/consoles-at-volume.js teardown --mode full`. Teardown also removes
the watchdog's own log entries for the rows it acted on.

**Owed at 1.8 release testing (recorded 2026-09-26):** section 83 and the journeys V147 to V153 were written and
rehearsed on the development org against no-namespace copies of the step classes; the first 1.8 cycle is the
first run against the installed package.

**Owed at 1.10 release testing (recorded 2026-10-23), all before the 1.10 mirror sync:**
1. `SubscriberOutboundRetry_TEST` proves that outbound and inbound handlers can override `onCommitWorkStarting()` (board
   row 126): `shouldRunTheHandlersCommitHooksOncePerAttempt` and `shouldRunTheInboundHandlersCommitWorkStartingOverrideOnce`
   must pass in `RunLocalTests`. The class does not compile while either hook is hidden from subscribers, so a deploy error
   on it means the widening did not reach the package, not a flaky test.
2. The LWC guide's custom datatable subclass example (board row 148, section "Your Own Column Types" in
   `docs/LWC - Guide.md`) has never run in a namespaced org. Build the guide's `myRecordTable` component, its
   `statusBadge` HTML cell template and one column definition as written, in the fresh-install subscriber org against the installed
   package, put it on a page with one `statusBadge` column and one built-in column, and confirm both cells render. If the
   example needs any change to work, correct the guide before the sync and record the change on row 148.
3. Mock Selected APIs on the upgrade leg (1.3b). In 1.10 a service with Mocking Enabled ticked on its API Setting
   answers from mock data only when the Mock Selected APIs feature flag is on for the running user, in both directions.
   On the org upgraded from the last released version, check each of these, and stop the release if one fails:
   - The packaged `kern__FeatureFlag.kern__MockSelectedAPIs` record arrived Active, with Enabled By Default off and no
     strategy. If it arrived with Enabled By Default on, outgoing services mock without anyone turning the flag on; if
     it arrived inactive, the upgrade step below cannot work until the record is activated. Either way, raise it before
     going on.
   - An outgoing service with the box ticked (`API_GetPost` or `EchoSubscriber`) calls the real system after the
     upgrade, as it did before, until the flag is turned on; with the flag on, its new call has Mocked Response ticked.
   - An incoming service with the box ticked answers from mock data before the upgrade and runs its own code after it,
     until the flag is turned on for the caller's user; with the flag on, it answers from mock data again. This is the
     behaviour change the 1.10 release note states. No incoming setting ships ticked, so before the upgrade, while the
     org is still on the released version, tick it with `SF_SUBSCRIBER_ORG_ALIAS=KernUpgradeSubscriber node
     release-testing/runner/cmdt-deployer.js upgrade-inbound-mocking-ticked` (it deploys the one
     `kern__ApiSetting.SubscriberCreateAccount` file and no flag file), and send one request to `REST_SubscriberApi`.
     After the upgrade, send the same request again before the 1.4 deploy and confirm it runs the service's own code:
     1.4 deploys the subscriber's own `kern__ApiSetting.SubscriberCreateAccount` file, which unticks the box, so a
     request sent after it runs the service's own code whatever the flag says and proves nothing. Tick it again with
     `upgrade-inbound-mocking-ticked` after 1.4 for the flag-on check. Untick it after the last check below that needs
     it ticked (the Health Check row) with `SF_SUBSCRIBER_ORG_ALIAS=KernUpgradeSubscriber node
     release-testing/runner/cmdt-deployer.js upgrade-inbound-mocking-unticked`.
   - The Health Check's Selected API Mocking row warns and names the ticked settings by label, and says whether the
     flag is on for you.
   - Read the description and help text of Mocking Enabled on API Setting in Setup. Record whether the 1.10 text reached
     the upgraded org (the description reaches the upgraded org; the help text does not, measured on the 1.10.0-1 beta
     over 1.9.0-4). The release note says what this check finds.
   - Build the Custom Handler strategy example from the 1.10 guide as written, attach it to Mock Selected APIs, and
     confirm it decides the flag. Send one incoming request and confirm the strategy sees the user the caller signs in
     as, as the Health Check text says. If either needs a change, correct the guide or the label before the sync.
   - No FeatureFlag record named MockSelectedAPIs exists in the subscriber's own namespace (see the section 27 note).
   - `SubscriberSelectedMocking_TEST` passes on both legs, run in the `section27-mock-disabled` state.
4. `SubscriberQueryGuideExamples_TEST` proves the 1.10 Selectors guide's examples for aggregate-query mocks, TYPEOF and
   blank record keys as a customer writes them, with the `kern.` prefix. It must pass in `RunLocalTests` on both
   legs. A compile error on it means a name the guide uses is not `global`, or its signature differs from the guide:
   correct the guide (or raise the framework gap) before the sync, not the test. A failed assertion means the code does not do
   what the guide says: correct the guide or the code before the sync.
5. The masking text search on long values (board row 138, recorded 2026-10-26): in the namespaced run of the classes 1.10
   changed (1.1), `UTIL_String_TEST` and `UTIL_FrameworkMasker_TEST` pass in full, including the six long-value tests whose names
   start `shouldNotReturnASecret`, `shouldMarkAPair`, `shouldMaskAMatchThatStarts` and `shouldMatchOneReplaceAll`. A failure in one
   of them stops the release.
6. `bypassSharing()` ignores record sharing and keeps field permissions (board row 141, recorded 2026-10-26):
   `sf apex run test -o $SF_SUBSCRIBER_ORG_ALIAS -t Recipe_BypassSharingFieldAccess_TEST --result-format human -w 10` passes
   all 5 tests on both legs. A Standard User with a test-only permission set (read and edit on `kern__Foobar__c` and its
   Text field, nothing on its Email field) reads and saves a private record an administrator owns: the read returns it
   without Email, a cursor and a filter on Email are refused with `kern.UTIL_Exceptions.IllegalStateException`, and a save
   through `kern.DML_Builder` or `kern.DML_Transaction.commitWork(false)` saves Text and leaves Email out. It needs the
   shipped defaults (`UserModeQueries_Enabled` and `UserModeDml_Enabled` on, `kern__Foobar__c` Private), the package
   installed for administrators only, and a free Salesforce licence seat (each test creates one Standard User). A failed setup check
   ("Expected record sharing to hide the record", "Expected the user to have no read access") points at the org, not the
   package. Any other failure stops the release.
7. The query builder's field-name check under a namespace (recorded 2026-10-27): in the namespaced run of the classes 1.10
   changed (1.1), `QRY_Builder_TEST.shouldKeepTheQueryTextForReleasedFieldNameShapes` passes. Its cases include a field name
   that carries the package namespace in a condition, a sort and a grouping, and parent field paths, so it proves the check
   accepts every name shape a namespaced org writes. A failure in it stops the release.

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
and section 75b (after ~30s) checks three things: the job is Failed (`75b-verify`), it carries the step's failure
message (`75b-identity`), and the framework's finalizer wrote one ERROR `kern__LogEntry__c` for the job, filed under
the job's id (`75b-error-log`). This guards the v67 queueable error path in `UTIL_AdaptiveAsynchronousProcessor`: a
managed-subscriber async job that throws is coverage @IsTest cannot reach (a queueable's unhandled exception in test
context surfaces as a test failure, not the real Finalizer/AsyncApexJob path).

An earlier subscriber build saw the finalizer's ERROR entry not persist. From 1.8, 75b asserts it: a `75b-error-log`
FAIL at the pass is a framework defect to raise before promotion, not a note to record.

`npm run release:phase2` handles the launch + 30s wait + verify (`runSection75`); manually:

```bash
# 75 — queueable unhandled-exception surfacing (launch, wait ~30s, verify)
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-75-queueable-unhandled-exception.apex 2>&1 | grep USER_DEBUG
sleep 30
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-75b-queueable-unhandled-exception-verify.apex 2>&1 | grep USER_DEBUG
```

**Section 75c note (the batch failure listener and the launcher's batch size):** a launch + verify pair with no
fixture. 75c starts `TST_RaisingBatch`, a batch job over 290 rows that throws in one chunk, and asks the job launcher
to start `TST_SizeProbeHandler`, whose size the launcher reads from the subscriber record
`kern__AsynchronousJobSetting.TST_SizeProbeHandler` (size 75). 75d, a minute later, checks the throwing job's result,
the ERROR entries the framework's batch failure listener filed for it, the size warning, and the launcher job's call
count. The count line asserts at least 4 and prints the real number; write the number in the results file (6 would
mean each 100-row chunk was split into 75 and 25). 75d reads only rows changed since the time 75c saved, so the pair can
be run again. `npm run release:phase2` runs the pair with a 60-second wait (`runSection75c`); manually:

```bash
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-75c-batch-failure-listener.apex 2>&1 | grep USER_DEBUG
sleep 60
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-75d-batch-failure-listener-verify.apex 2>&1 | grep USER_DEBUG
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
via `sf org display -o $SF_SUBSCRIBER_ORG_ALIAS --json` (and reads the token from `sf org auth show-access-token`, because the CLI
hides it in `org display`) and fires parallel HTTP callouts against `REST_LoadProbe`. The probe's success path relies on the
handler's canned answer, which since 1.8 stands in for the callout outside a unit test only while MockAllAPIs is on. Run the
script inside a MockAllAPIs window, and turn the flag off after it, even when the script fails:
`node release-testing/runner/cmdt-deployer.js mock-all-apis-enabled`, then the script (8 of 8), then
`node release-testing/runner/cmdt-deployer.js mock-all-apis-disabled`. Without the window, 51e fails (7 of 8). No helper script
wraps this window; the runner's `cmdt-deployer.js` is the by-hand route.

**Section 56 (async chain edge, launch+verify):** Run `section-56-edge-async-chain.apex` first (enqueues the chain),
then run `section-56b-edge-async-chain-verify.apex` after async processing completes.

**Section 64 (AsyncJobLauncher edge, launch+verify):** Similar pattern — run `section-64-edge-asyncjob-launcher.apex`
to enqueue, wait for completion, then check results inline (verify queries embedded in same script via polling).

**Load test sections 44-51:** Each emits `PERF_ROW` lines to the debug log for the Phase 2.5 perf history harvester.
Capture the raw log file path if you intend to update baselines (see `release-testing/Testing Protocol.md` for the
`--logfile` flag). Behaviour assertions are the hard gate — timing warnings are advisory.

**Pending 1.6.0 sections (registered before scripting; author the section scripts with the 1.6.0
runbook pass):**

- **Active-run deduplication (registered 2026-07-21):** in the subscriber org,
  observe the three deduplication invariants from the subscriber side —
  1. a double-start with the same `withDeduplicationKey` value yields ONE run, and the second
     `execute()` returns the SAME `AsyncChainExecution__c` Id as the first (active-run guard);
  2. after the first run reaches a terminal status, a same-key re-run starts a FRESH run
     (key released at every terminal transition — sequential re-runs are deliberately allowed);
  3. a Stalled chain still blocks a same-key start (the key is state-scoped, not time-scoped —
     no expiry clock releases it while the run is recoverable).
  Model: a launch + verify split if the terminal-release leg needs async settling (sections 48-50
  pattern); otherwise a single orchestrated script.

- **Guaranteed terminal-log emission (registered 2026-07-22):** in the subscriber
  org, observe that every chain now leaves exactly one terminal `kern__LogEntry__c` —
  1. a chain that COMPLETES leaves one INFO entry whose `kern__ClassMethod__c` ends
     `handleChainCompletion` (or `ChainBuilder.execute` for a zero-step chain) and whose
     `kern__RecordId__c` is the run's `AsyncChainExecution__c` Id — but ONLY when
     `LogSetting__c.IsEnabled__c` is true and `LogLevelThreshold__c` is at or below INFO;
  2. a chain that FAILS leaves one ERROR entry (`...handleStepFailure`) that appears at ANY
     threshold — set `LogLevelThreshold__c = WARN` and confirm the completion entry is ABSENT
     while the failure entry still appears (the threshold contract);
  3. the terminal write itself always commits regardless of the signal (best-effort).
  CAVEAT: hold the exact-delivery assertions under DML-heavy transactions until the silent-loss
  investigation resolves — script the healthy-transaction cases first.

**Pending 1.7.0 sections (registered before scripting; author the section scripts with the 1.7.0
runbook pass):**

- **Composition-pattern proof suites (registered 2026-08-10):** the five `Recipe_*` suites
  (`Recipe_ChainCircuitBreaker_DEMO_TEST`, `Recipe_ApprovalHandOff_DEMO_TEST`,
  `Recipe_ScheduledChain_DEMO_TEST`, `Recipe_CaseDelivery_SERVICE_TEST`,
  `Recipe_CommittedDelivery_DEMO_TEST`) ride the standard 1.4 artifact deploy (their classes, the
  `TRG_Case` trigger, and the three `Recipe`/`Case` CMDT records are in `release-testing/subscriber/`)
  and must run green on the 1.7 candidate — the committed-delivery suite is the binding re-proof of
  the ApiStep subscriber-handler resolution fix (`02152683`), first proven 12/12 on the third 1.7
  beta.

- **Operator re-drive actions (registered 2026-08-09):** in the subscriber org, with a
  user holding **Kern Async Chain Redrive** + **Kern Async Chain Monitor Read Only**, observe —
  1. **Retry from failed step:** a Failed chain whose failed step answers `true` from `isIdempotent()`
     offers Retry; completed steps do not re-run; the run keeps its record and `CorrelationId__c`;
     a chain without the declaration, a `failedPermanently` failure, and a context-unavailable row
     each refuse with their labelled reason (disabled button + tooltip; server re-check on confirm).
  2. **Restart from start:** a Failed or Aborted chain built with `.allowRestart()` restarts as a
     NEW run (fresh `CorrelationId__c` + `RunKey__c`, `SourceExecution__c` lineage, monitor
     re-points at the clone); the source row stays terminal and untouched; a non-declared chain
     refuses `RestartNotDeclared`.
  3. **Clear stalled:** seeded stalled chains are checked and the toast reports the four buckets
     (checked / re-driven / marked failed / still waiting); the action refuses while processing is
     suspended; a chain the sweeping user cannot read stays untouched and counts as still waiting.
  4. **Kill-switch toggle:** a user holding **Kern Async Chain Kill Switch** can Suspend/Resume;
     suspend flips running chains to `Aborted` (`FailureCategory__c = 'KillSwitch'`) at their next
     step boundary and new chains abort before their first step; resume leaves the stopped chains
     stopped; a user-level `AsyncChainRuntimeSwitch__c` record overrides the org default for that
     user's chain transactions.
  5. **Live activity stream:** the detail panel seeds the newest entries (cap 20) through BOTH
     reference legs (correlation id + record reference — watchdog/abort entries appear), streams
     ERROR-level entries regardless of threshold, and needs `kern__LogEntry__c` read (the
     **Kern Administrator** set) — without it the stream is empty, not an error.
  Namespace leg: repeat 1-5 in the subscriber org (`SF_SUBSCRIBER_ORG_ALIAS`; kern__ prefixes throughout); uses
  `SubscriberChainSteps.RecoveringStep` (kern.-referencing, declares idempotency by overriding
  `isIdempotent()` — never in a constructor, which the framework cannot reach across the package
  boundary — marker-based like `EndToEndChainSteps.RecoveringStep`; covered by
  `SubscriberChainSteps_TEST`). Note: e2e parts 8-10 still have no npm aliases (run the spec files
  by name).
  Model: launch + verify split (async settling), sections 48-50 pattern.

### Lock-retry probe (two transactions)

Proves `withRetryOnLock` against a real row lock, which no Apex test can produce (every transaction a test
starts shares the test's own lock). Two transactions take part: the holder, `LockRetryProbeHolder` (a queueable
in the subscriber tree, deployed with the 1.4 artifacts), selects an Account `FOR UPDATE` and keeps its
transaction alive for about 30 seconds; the caller, `release-testing/scripts/lock-retry-caller.apex`, updates the
same row with `withRetryOnLock(2)`. The platform refuses the caller twice, about ten seconds each, and the third
attempt saves once the holder lets go. The runner then reads the WARN entry the retried commit wrote.

```bash
node release-testing/runner/lock-retry-probe.js --org $SF_SUBSCRIBER_ORG_ALIAS
node release-testing/runner/lock-retry-probe.js --org <dev org alias> --no-namespace   # unmanaged deploy
```

Expected: one line `PASS: success=true elapsedMs=<about 25000> retriesUsed=2 account=<Id>` and exit 0; the
elapsed time is the hold minus the few seconds the CLI spends before the caller starts. The hold has to end
after the caller's second lock wait and before its third, roughly 20 to 30 seconds after the caller starts, and
30000 ms sits in the middle of that window. A `FAIL` with `retriesUsed` below 2 means the holder let go before
the second wait ended: raise the hold in `lock-retry-holder.apex` by two or three seconds, never past about
34000 ms, and run again. A `FAIL` reading `the caller transaction did not report a result` means every attempt
was refused, so the hold ran past the third wait: lower it the same way. A `FAIL` with `retriesUsed=none` means
the retried commit's WARN entry was not readable within five seconds (check the org's log settings). The probe
leaves its Account and log rows in the org. Never run the holder script by hand alongside the caller.

### Integration callout probe

Proves that a callout made through the framework from inside an Apex integration test reaches the real endpoint,
which no unit test can show: in a unit test the framework answers its own mock. Apex integration tests are a
Developer Preview (Winter '27): the annotation compiles only in a scratch org created with the
`ApexIntegrationTests` feature (an org without it refuses the class with `Annotation is not valid in your org:
IntegrationTest`), so the class `SubscriberRealCallout_INTEGRATION` lives apart from the other subscriber artifacts,
in `release-testing/subscriber/integration/`, and is deployed here rather than in 1.4. Run this section only against
an org created with the feature (section 1.2's window rule); the upgrade-leg org of 1.3b is created from the standard
definition and does not take part. The class calls the org's own REST API version list through a named credential
generated for the org (a legacy credential with no authentication; it needs no remote site setting). It also deploys
`API_VersionList`, a handler with a canned answer and no credential, and expects it to reach the same endpoint through
`kern.UTIL_HttpClient.useHandler(...)`, so the result lists three methods.

```bash
ORG_URL=$(sf org display -o $SF_SUBSCRIBER_ORG_ALIAS --json | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['instanceUrl'])")
rm -rf /tmp/kern-subscriber-integration && cp -r release-testing/subscriber/integration /tmp/kern-subscriber-integration
mkdir -p /tmp/kern-subscriber-integration/namedCredentials
cat > /tmp/kern-subscriber-integration/namedCredentials/SubscriberIntegrationEndpoint.namedCredential << XMLEOF
<?xml version="1.0" encoding="UTF-8"?>
<NamedCredential xmlns="http://soap.sforce.com/2006/04/metadata">
    <endpoint>${ORG_URL}</endpoint>
    <label>SubscriberIntegrationEndpoint</label>
    <principalType>Anonymous</principalType>
    <protocol>NoAuthentication</protocol>
</NamedCredential>
XMLEOF
sf project deploy start --metadata-dir /tmp/kern-subscriber-integration -o $SF_SUBSCRIBER_ORG_ALIAS --wait 10
sf apex run test -o $SF_SUBSCRIBER_ORG_ALIAS -t SubscriberRealCallout_INTEGRATION --result-format human --wait 10
```

Expected: the deploy creates the class and the credential; the run reports `Tests Ran 2`, `Pass Rate 100%`. A deploy
refused with `Annotation is not valid in your org` means the org was created without the feature.
`calloutReachesTheEndpointWhenNoMockIsRegistered` failing on the body (`Same value: {"success":true}`) means the
package under test predates the guard, or a platform release changed the integration-test quiddity the guard
recognises; failing on the status means the generated credential does not carry this org's URL (regenerate and
redeploy). `registeredMockKeepsPrecedence` failing means a registered mock no longer takes precedence inside an
integration test. The probe leaves its class, its credential and its call records in the org; it writes no log rows,
because the log engine holds its events inside an integration test as in a unit test. A legacy named credential
cannot be deleted through the Metadata API, which does not matter for a scratch org.

### Nested chain launch probe

Proves, in the subscriber org, the part of a launch from inside a running chain that the platform does not document
and no unit test can show: a chain launched from a step runs its first step under the launching chain's queueable
stack depth and sets its own from its second step on, and a completion handler runs with the run's logging context and
may launch a chain too. `release-testing/scripts/nested-launch-probe.apex` launches three parents in one action:
`SubscriberNestedParent`, given a maximum stack depth of 2 so that its child's second step runs only if the child set
its own depth, whose step launches the two-step `SubscriberNestedChild`; `SubscriberNestedHandlerParent`, under the
framework default, whose completion handler launches the same child; and `SubscriberNestedUncappedParent`, given
options that set no maximum at all, whose step launches the same child from a lineage without a maximum (the one shape
no unit test can stage, because in a test such a lineage cannot chain). Both step classes are in
`SubscriberChainSteps`, deployed with the 1.4 artifacts.

```bash
sf apex run --file release-testing/scripts/nested-launch-probe.apex -o $SF_SUBSCRIBER_ORG_ALIAS
sleep 60
sf data query -o $SF_SUBSCRIBER_ORG_ALIAS -q "SELECT kern__ChainName__c, kern__Status__c, kern__CompletedSteps__c, kern__CorrelationId__c, kern__LaunchCorrelationId__c, kern__RootCorrelationId__c, kern__DeclaredDeduplicationKey__c, kern__ErrorMessage__c FROM kern__AsyncChainExecution__c WHERE kern__ChainName__c IN ('SubscriberNestedParent', 'SubscriberNestedHandlerParent', 'SubscriberNestedUncappedParent', 'SubscriberNestedChild') ORDER BY CreatedDate DESC LIMIT 6"
```

Expected: six rows, all `Completed`. The three children show `kern__CompletedSteps__c` 2, a `kern__LaunchCorrelationId__c`
equal to their parent's `kern__CorrelationId__c`, the same `kern__RootCorrelationId__c` as the parents (the action's),
and a `kern__DeclaredDeduplicationKey__c` of the parent's record id followed by `:0` (a step's child) or `:onComplete`
(the completion handler's child). The child of `SubscriberNestedParent` at 1 completed step and `Stalled` with "Finalizer failed
to enqueue next step" means the platform no longer lets a chain's Finalizer set a stack depth under a lineage it
borrowed, the measured behaviour the feature rests on: stop the release and raise it. A `SubscriberNestedParent` that
is `Failed` with "leaving no level" means the framework's check refused a launch that had room. A handler's child with
a blank launch id means the handler's transaction ran without the run's logging context. No child at all, with the
parent `Failed` on "Cannot reset Maximum Queueable Stack Depth", means the launch passed a depth from inside a job. The
probe leaves its six runs and their log rows in the org.

### Chain launch from a trigger inside a Queueable

Proves, in the subscriber org, that a chain started by a Kern trigger action fired by a queueable job's save starts
and completes. The probe checks three kinds of job: a job of another managed package, the subscriber's own job, and
a chain step. The trigger action starts the chain with `execute()` and no `AsyncOptions`, and is set to Log and
Continue, as in the subscriber org where the fault was found. The cause is a platform rule: code that runs in a
trigger fired inside a running queueable job may not ask the platform how deep the job's line of jobs is
(`System.AsyncInfo`). The platform throws `System.AsyncException`, although `System.isQueueable()` is true. The rule
holds for every queueable job, not only for another package's. The probe still uses another package because that is
the shape seen in the subscriber org; the other two cases have the same cause. On 1.9.0-4 the launch asked, so the
logged error either left a `Running` run with no job or stopped the launch before the run was saved. No Apex test can
stage this; it needs a real queueable job and a real trigger.

The other package is a small fixture, **Queued Marker Writer** (namespace `kerndxqa`, compiled at API 56.0, source in
`release-testing/fixtures/foreign-queueable-package/`). It holds the object Queued Marker (`kerndxqa__QueuedMarker__c`,
Name only) and the global queueable job `kerndxqa.QueuedMarkerWriter`, whose `enqueueMarker(String)` queues a job that
saves one marker with that name. Beta 1.0.0-1: `04tfj000000eptRAAQ` (package `0Hofj0000004s3RCAQ`, built 2026-10-25).
The subscriber side is in `release-testing/fixtures/foreign-queueable-subscriber/`, apart from
`release-testing/subscriber/` because it names the fixture's object and would break the 1.4 deploy in an org without
the fixture: the trigger `TRG_QueuedMarker`, the trigger action `QueuedMarkerChainLauncher` (After Insert, Log and
Continue; it starts a two-step chain named after the saved marker) with its `kern__TriggerSetting` and
`kern__TriggerAction` records, `SubscriberQueuedMarkerWriter`, the subscriber's own queueable job that saves a marker
the same way, and `QueuedMarkerWriterStep`, a chain step that saves the marker `ChainStepChain`. Both fixture folders
stay in the internal repository and are not published: they serve only this probe.

Setup, after 1.3 and the 1.4 artifacts (the trigger action is found through the 1.4 `CustomTypeResolver` and its
`kern__ClassTypeResolver.CurrentOrgResolver` record):

```bash
sf package install -o $SF_SUBSCRIBER_ORG_ALIAS --package 04tfj000000eptRAAQ --wait 15 --no-prompt
cd release-testing/fixtures/foreign-queueable-subscriber && sf project deploy start -o $SF_SUBSCRIBER_ORG_ALIAS -d force-app --ignore-conflicts
cd <repo-root>
```

Run:

```bash
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/foreign-queueable-chain-launch.apex
sleep 60
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/foreign-queueable-chain-launch-verify.apex > tmp/foreign-queueable-verify.log 2>&1
grep USER_DEBUG tmp/foreign-queueable-verify.log
```

The first script starts three jobs, one for each case, and each saved marker's trigger starts the chain of the same
name:

1. The fixture's job saves the marker `OtherPackageQueueableChain`.
2. The subscriber's job saves `SubscriberQueueableChain`.
3. The two-step chain `ChainStepParentChain` starts; its first step, `QueuedMarkerWriterStep`, saves `ChainStepChain`,
   so the chain `ChainStepChain` is started from inside the parent chain's job.

Expected from 1.10 on: three `foreign-queueable-verify PASS` lines. For cases 1 and 2, the newest run of the chain is
`Completed` with 2 completed steps, and no run of either chain is `Running` without a job id. For case 3, the newest
`ChainStepParentChain` run is `Completed` with 2 steps, and the newest `ChainStepChain` run is `Completed` with 2
steps, with a `kern__LaunchCorrelationId__c` equal to the parent's `kern__CorrelationId__c` and a
`kern__DeclaredDeduplicationKey__c` of the parent's record id followed by `:0` (the key a step's child gets, as in the
nested chain launch probe above).

What a wrong result means:

- A `WAIT` line means the jobs have not finished. Wait a minute and run the verify script again. It is safe to rerun
  in the same org, because only the runs of this attempt count.
- A run `Running` with 0 completed steps and a blank job id, and an ERROR Log Entry from `TRG_Dispatcher` with
  `System.AsyncException` "getCurrentQueueableStackDepth is not allowed outside a Queueable of Finalizer execution":
  the build does not have the fix, or the platform now refuses another `AsyncInfo` read. Stop the release and raise it.
- "no run found" for case 1 or 2, with an ERROR Log Entry from `TRG_Dispatcher`: the launch was refused and its run
  deleted, so no run was left behind, but the chain did not start. The platform refused the first job itself. Raise it.
- `FAIL` for `OtherPackageQueueableChain` only: the other package's job (its namespace or its older API version)
  changes the result. Raise it.
- Case 3 "no child run found" with the parent `Completed`, and an ERROR Log Entry from `TRG_Dispatcher` with
  `System.AsyncException` "hasMaxStackDepth is not allowed outside a Queueable of Finalizer execution": the launch
  from inside the chain step was refused before its run was saved. The build does not have the fix. Stop the release
  and raise it.
- Case 3 with a child run that is `Completed` but has a blank or different launch id, or a different key: the child
  started but is not linked to the chain whose step saved the marker. Raise it.
- Case 3 with the parent not `Completed`: the step's save failed, or the parent stopped because of the launch inside
  it. Read the parent's `kern__ErrorMessage__c` and raise it.
- "no run found" and no ERROR Log Entry: the trigger action did not run. A failed fixture job whose status reads
  `Unable to resolve type for class "QueuedMarkerChainLauncher"` means the 1.4 `CustomTypeResolver` is missing.

Measured on 1.9.0-4, org `KernForeignQueueable`:

- Cases 1 and 2 (2026-10-25): both `FAIL`. Both runs were `Running` with 0 of 2 steps and a blank job id, both
  queueable jobs `Completed`, and each left one ERROR Log Entry from `TRG_Dispatcher.dispatchAction`,
  `System.AsyncException`, "getCurrentQueueableStackDepth is not allowed outside a Queueable of Finalizer execution".
  In the same org, the same chain started directly in a subscriber job's `execute` (no trigger) completed, and that job
  read its depth as 1; a plain trigger on Account fired inside a subscriber job was refused the same read.
- Case 3 (2026-10-25, parent run `a03QL000022J7DJYA0`): the launch inside the step was refused before the run was
  saved, with one ERROR Log Entry from `TRG_Dispatcher.dispatchAction`, "hasMaxStackDepth is not allowed outside a
  Queueable of Finalizer execution". The marker was saved, no child run exists, and the parent chain is `Completed`
  with 2 steps.
- The three cases together through the scripts (2026-10-26 01:50 UTC, parent run `a03QL000022ISBTYA4`): three `FAIL`
  lines, the same three ERROR Log Entries, and all three markers saved:

```text
foreign-queueable-verify FAIL: OtherPackageQueueableChain: newest run Running with 0 completed step(s), job id null, error null; runs Running without a job: 2
foreign-queueable-verify FAIL: SubscriberQueueableChain: newest run Running with 0 completed step(s), job id null, error null; runs Running without a job: 2
foreign-queueable-verify FAIL: ChainStepChain: no child run found; parent Completed with 2 completed step(s)
```

So the refusal belongs to trigger code inside any queueable job, a chain's own job included, not only to another
package's job.

The probe leaves its markers, runs and log rows in the org. To rebuild the fixture (a beta never upgrades, so install
the new version in a fresh org and record its 04t here):

```bash
cd release-testing/fixtures/foreign-queueable-package
sf package version create --package "Queued Marker Writer" --skip-validation --installation-key-bypass -v DevHub --wait 30
cd <repo-root>
```

The package already exists in the Dev Hub. Only a Dev Hub without it first needs
`sf package create --name "Queued Marker Writer" --package-type Managed --path force-app -v DevHub`, run from the same
folder. Both commands write their ids into that folder's `sfdx-project.json`.

### Custom permission muted in a permission set group

Proves, once per release in the subscriber org, that Kern gives the same answer as Salesforce when you ask whether
another user holds a custom permission that a permission set group grants and then mutes. A muting permission set
inside a group takes a permission away from the group, even though a permission set in the group grants it. The
check runs as the administrator and asks about a second user, through the global method
`kern.UTIL_FeatureFlag.isEnabled(flagName, userId)`. It uses the packaged flag `AsyncChainAbort_Enabled`, whose one
strategy is the custom permission `core.AbortAsyncChain` (the packaged permission `kern__AbortAsyncChain`, Abort Async
Chain). For a user other than the running one, Kern answers by reading the user's permission set assignments. This
step checks that answer in a real subscriber org, under the `kern` namespace, with a group whose permissions
Salesforce has calculated.

The fixture is in `release-testing/fixtures/custom-permission-group/`. It holds three components, all release testing
only:

- the permission set `CustomPermissionGroupProbeGrant`, which grants `kern__AbortAsyncChain`;
- the muting permission set `CustomPermissionGroupProbeMute`, which mutes `kern__AbortAsyncChain`;
- the permission set group `CustomPermissionGroupProbe`, which holds both.

The script `release-testing/scripts/custom-permission-group-probe.apex` creates the second user: a Standard User
named `custom-permission-probe.<org id>@example.com`. The script gives that user the group. It needs one free
Salesforce licence seat, and an org where the package was installed for administrators only (1.3's install command).
Installed for all users, the Standard User profile holds the permission itself, and the script stops with a `SETUP`
line.

Setup, after 1.3:

```bash
cd release-testing/fixtures/custom-permission-group && sf project deploy start -o $SF_SUBSCRIBER_ORG_ALIAS -d force-app --ignore-conflicts
cd <repo-root>
sf data query -o $SF_SUBSCRIBER_ORG_ALIAS -q "SELECT DeveloperName, Status FROM PermissionSetGroup WHERE DeveloperName = 'CustomPermissionGroupProbe'"
```

Salesforce works out what a group grants after each change to the group. Run the query every 30 seconds until
`Status` reads `Updated`. This usually takes less than a minute. If it still reads `Outdated` or `Updating` after
10 minutes, open Setup, Permission Set Groups, and recalculate the group there. `Failed` means the group could not
be worked out: read the error on the group's page in Setup.

Run 1, with the muting set in the group:

```bash
sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/custom-permission-group-probe.apex > tmp/custom-permission-group-probe.log 2>&1
grep USER_DEBUG tmp/custom-permission-group-probe.log
```

Expected: one line that starts with `custom-permission-group-probe PASS: muting set in the group: true; expected from the group: false; Kern answers:
false`. The expected value is the rule for a muting set: a muted permission is not granted. On this result the script
takes the muting set out of the group, and Salesforce works out the group again.

Run 2, once the group can grant the permission: run the same query until `Status` reads `Updated` again, and wait at
least one minute after run 1. Then run the same two commands again. Expected: one line that starts with
`custom-permission-group-probe PASS: muting set in the group: false; expected from the group: true; Kern answers:
true`. On this result the script takes the group away from the user and makes the user inactive.

What a wrong result means:

- `WAIT`: the group status is not `Updated` yet. Wait 30 seconds and run the script again.
- `SETUP`: the org is not ready for the check, and the line says what is missing: the fixture is not deployed, the
  flag `AsyncChainAbort_Enabled` is inactive or has a strategy added in this org, or the Standard User profile holds the
  permission. Correct the org and run the script again. This is not a result about Kern.
- `FAIL` in run 1, `Kern answers: true`: Kern says the user holds a permission that the group mutes, and Salesforce
  does not give it to the user. First confirm the mute in Setup. Open Permission Set Groups, Custom Permission Group
  Probe, Muting Permission Set, Custom Permissions: Abort Async Chain must be muted. If it is muted, Kern's answer
  differs from Salesforce's: stop the release and raise it. The script changes nothing on a `FAIL`, so the group and
  the user stay as they were, for the investigation.
- `FAIL` in run 2, `Kern answers: false`: Kern says the user lacks a permission that the group now grants. If run 2
  started less than a minute after run 1, wait one more minute and run it again. If it still fails, Kern's answer
  differs from Salesforce's: stop the release and raise it.
- A platform licence error on the user insert: no Salesforce licence seat is free. Make another release-testing user
  inactive and run the script again.

To run the check again from the start, deploy the fixture again (this puts the muting set back in the group), wait
for `Updated`, and run the script. It makes the same user active again.

Clean-up, after run 2 passed (the script has already taken the group from the user, and a group that is still
assigned cannot be deleted):

```bash
cd release-testing/fixtures/custom-permission-group && sf project deploy start -o $SF_SUBSCRIBER_ORG_ALIAS --manifest clean-up/package.xml --pre-destructive-changes clean-up/destructiveChangesPre.xml --post-destructive-changes clean-up/destructiveChangesPost.xml
cd <repo-root>
```

After a `FAIL`, when the investigation is done, first take the group from the user in Setup (Users, Custom Permission
Probe, Permission Set Group Assignments, Edit Assignments), then run the clean-up deploy.

The deploy deletes the group first and then the muting set and the permission set, and leaves the fixture's files in
place. Salesforce does not delete users, so the inactive user stays in the org. In a scratch org that does not matter.

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

**Expected:** all subscriber test classes pass at 100% org-wide coverage. `Tests Ran` should read 289 or a little
more: the list below counts test methods in the tree, and the platform also counts setup rows. Earlier this
cycle: `SubscriberPlatformEventAccessLevel_TEST` — 4 tests covering the v67 SYSTEM_MODE always-emit + USER_MODE
publish-enforcement platform-event AccessLevel guards (the runtime-enforcement layer the anonymous-Apex sections
16/65 cannot reach). Kern 1.1 reconciliation: 180 tests / 0 failures / 97% org-wide coverage.

Test classes deployed in `release-testing/subscriber/classes/` (56 classes, 289 test methods, counted from the tree on
2026-10-23; the number after each name is its test methods):

| Area | Classes |
|---|---|
| Framework surface | `SubscriberApi18Surface_TEST` 13, `SubscriberApiRecordDeleteGuard_TEST` 3, `SubscriberAsyncDml_TEST` 3, `SubscriberBulkRetry_TEST` 5, `SubscriberChainSteps_TEST` 45, `SubscriberHttpClient_TEST` 8, `SubscriberInboundIssue_TEST` 2, `SubscriberMockPatterns_TEST` 27, `SubscriberMockSelection_TEST` 2, `SubscriberOutboundRetry_TEST` 20, `SubscriberPlatformEventAccessLevel_TEST` 4, `SubscriberResilience_TEST` 8, `SubscriberSecureByDefault_TEST` 8, `SubscriberSelectedMocking_TEST` 4, `SubscriberWhoWroteIt_TEST` 1, `Subscriber_DmlEdges_TEST` 3, `Subscriber_FlowLoggerRecordId_TEST` 2, `Subscriber_QryEdges_TEST` 10, `Subscriber_TriggerActionTiebreak_TEST` 1, `Subscriber_TypeResolver_TEST` 4, `CustomTypeResolver_TEST` 8 |
| Sample application | `AccountArchiveProcessor_TEST` 2, `API_ContactFormSubmit_TEST` 3, `API_GetPost_TEST` 4, `CTRL_SubscriberLwcTest_TEST` 4, `REST_ContactForm_TEST` 1, `SCHED_SubscriberJob_TEST` 4, `SVC_AccountOnboarding_TEST` 3, `SVC_AccountValidator_TEST` 4, `SVC_ContactDirectory_TEST` 3, `SVC_PricingCalculator_TEST` 2, `SVC_ResilientSync_TEST` 2, `TRG_AccountHandlers_TEST` 2, `TRG_InvokeFlow_SUBTEST` 5, `UTIL_AccountClassifier_TEST` 5, `VAL_AccountRules_TEST` 5 |
| Fast Starts and recipes | `FastStart_AsyncChain_DEMO_TEST` 2, `FastStart_Cache_DEMO_TEST` 4, `FastStart_DML_DEMO_TEST` 3, `FastStart_E2E_DEMO_TEST` 3, `FastStart_FeatureFlag_DEMO_TEST` 2, `FastStart_InboundAPI_DEMO_TEST` 2, `FastStart_Logging_DEMO_TEST` 2, `FastStart_MockException_DEMO_TEST` 5, `FastStart_OutboundAPI_DEMO_TEST` 4, `FastStart_QueryMapTerminals_DEMO_TEST` 4, `FastStart_ScheduledJob_DEMO_TEST` 3, `FastStart_Selectors_DEMO_TEST` 4, `FastStart_TestData_DEMO_TEST` 4, `FastStart_TriggerAction_DEMO_TEST` 2, `FastStart_Validation_DEMO_TEST` 2, `Recipe_ApprovalHandOff_DEMO_TEST` 2, `Recipe_BypassSharingFieldAccess_TEST` 5, `Recipe_CaseDelivery_SERVICE_TEST` 1, `Recipe_ChainCircuitBreaker_DEMO_TEST` 4, `Recipe_CommittedDelivery_DEMO_TEST` 3, `Recipe_ScheduledChain_DEMO_TEST` 3 |

New in the 1.8 cycle: `SubscriberApiRecordDeleteGuard_TEST` (3: a resolver's Delete refused, an administrator's
allowed, a resolver's purge deletes nothing and warns once), `SubscriberApi18Surface_TEST` (13: the members added to
the global API in 1.8, and a hidden record read only when record sharing is bypassed) and `SubscriberWhoWroteIt_TEST`
(1: an entry written with no `.at()` names the subscriber class and method and the APEX origin; with its support class
`SubscriberWhoWroteIt`). Tests added to classes already listed: `SubscriberBulkRetry_TEST` +3 (the Flow action refused
to a user without the permission, an issue of a service that does not accept retries stays open, an inbound issue
replayed and resolved), `Subscriber_QryEdges_TEST` +2, `Subscriber_DmlEdges_TEST` +1, `SubscriberHttpClient_TEST` +1.

Four preconditions these tests need, all met by the Phase 1 steps as written:

- **The package installed for administrators only** (1.3's install command). Installed for all users, the Standard User
  profile holds the framework's permissions and the refusal tests of `SubscriberApiRecordDeleteGuard_TEST` and
  `SubscriberBulkRetry_TEST` fail; their messages say so.
- **The user-mode query default on** (`UserModeQueries_Enabled`, on as shipped). With it off, the two cache tests of
  `SubscriberApi18Surface_TEST` fail.
- **Free licence seats.** `SubscriberApi18Surface_TEST` creates five Standard Users across two tests; an org with no
  free Salesforce licence seats fails those two tests with the platform's licence error.
- **The three mocking flags off** (Mock Selected APIs, Mock All APIs and Mock All Inbound APIs, all off as shipped).
  `SubscriberSelectedMocking_TEST` (4: an outgoing and an incoming service with Mocking Enabled ticked mock nothing
  while Mock Selected APIs is off, and answer from mock data once it is on) reads the org's own Mock Selected APIs
  record in its flag-off tests, because a subscriber test cannot register a flag as off. Run it only in the
  `section27-mock-disabled` state, and outside the Mock All APIs windows of sections 31, 55, 60 and 63: never between
  section 27's enabled state and its restore. Each test first checks the three flags and fails with the message "Mock
  Selected APIs, Mock All APIs or Mock All Inbound APIs is on for the running user: run this class outside section 27's
  enabled state".

### 2.2b Managed Package Test Execution (subscriber context)

Run the package's own test suite inside the subscriber org. `RunLocalTests` excludes managed tests, so this is a
separate, mandatory gate:

```bash
sf apex run test -o $SF_SUBSCRIBER_ORG_ALIAS --test-level RunAllTestsInOrg --result-format human -w 60
```

**Expected:** zero failures across the entire run (local + managed; the managed portion was 3,724 tests at the start of
Kern 1.1 and the count grows with the package — the Kern 1.1.0-11 fresh leg ran 3,955 tests total at 100%). Managed-class
coverage percentages are not visible in a subscriber org; the gate is pass/fail only.

Run it on both legs, and on the upgrade leg twice: once with the cycle's release updates disabled and once with them
enabled, because subscribers exist in both states while an update is an opt-in test run. Run it a third time on a bare
install: a new scratch org with the candidate installed and nothing else, no Phase 1.4 setup and no Platform Cache
partition. The 1.4 setup allocates a cache partition, which hid 23 package tests that assumed one until the 1.8 cycle
ran them on a bare install; many customer orgs allocate no Platform Cache. The 1.8 cycle (2026-10-12)
found five package tests that pass on the development, packaging and namespaced orgs and fail only here, each on one of
the three things a managed install changes: the subscriber's own customisations on standard objects (an Account
validation rule from Phase 1.4 refused two inserts), the install's writes of the package's custom permissions into the
System Administrator profile (a test's "administrator without the permission" held it), and the masking of the package's
stack frames to `(kern)` (a caller derived from the stack was null). Package tests therefore write packaged objects only
(the Kern scanner rule on standard-object writes in `_TEST` classes enforces it), take a Standard User as the user without
a package permission, never depend on readable package frames, and report their stage on failure so a masked org still
says where a test died.

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
| **Upgrade** (install the released 1.7.0-13, seed states, upgrade to the target build; see 1.3b) | State transitions — where the replacement risk actually lives | §2.2b (zero failures) + the succession matrix below + the advisor picker/annotation spot-check. NOT the full Phase 3 visual suite — the fresh leg owns it |

**Succession matrix (upgrade leg only — these seeded states cannot exist on a fresh install):**

The matrix below proves the arrival of `MaskPaymentCard` beside `MaskCreditCard`, so it applies to a leg that starts on 1.7
or earlier. A leg that starts on 1.8 already has both rules; from 1.9 on, the upgrade leg instead proves that the upgraded
org keeps its own masking values (the rules on Log and Continue, the card rules on Block DML, `MaskJwt` off, the card targets
active) and that the release note's upgrade step switches them to the shipped defaults, and it records each outcome (first
run 2026-10-20, 1.8.0-11 to 1.9.0-4, PASS).

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
   design while it is deactivated (37 Case B, 61e, and section 76 from 76b on). Re-activate `MaskPaymentCard`, confirm the takeover
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

> **PMD floor vs. Code Analyzer bundle (updated 2026-07-15).** The kern rulesets carry no
> standard-category rule references (removed by policy on 2026-07-12) and load on the PMD apex
> module >= 7.19.0, which includes the pmd-apex 7.25.0 the current `code-analyzer` plugin (5.14.0)
> bundles — `sf code-analyzer` loads and fires all 27 Kern rules. Two things to know when running
> it: passing `code-analyzer.yml` via the `--config-file` flag is REQUIRED (run from outside the repository root
> without it, `custom_rulesets` never loads and 0 Kern rules run, silently; from the root Code Analyzer reads the
> file on its own), and sfca is report-by-default (exit 0 even with
> violations; only `--severity-threshold <n>` makes it fail). (Historical: until 2026-07-12 the
> rulesets referenced `InvocableClassNoArgConstructor`, a rule PMD added in 7.26.0, and that one
> unresolvable reference failed the whole ruleset load with `UninstantiableEngineError`;
> `kerndx doctor` surfaced this as the `below` verdict.) The standalone `pmd` CLI legs below
> remain the reference counts — an equivalent alternative by choice, not a constraint (the pmd
> CLI exits 4 on violations by default):
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

**Expected:** 42 violations across 4 files (0 from `ScannerTestCompliant.cls`):

| File                             | Rule                       | Count |
|----------------------------------|----------------------------|-------|
| `ScannerTestTrigger.trigger`     | KernTriggerMustDelegate    | 2     |
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
| `ScannerTestViolations.cls`      | KernLimitsThroughWrapper   | 1     |
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
classes. First prove the rules loaded, because Code Analyzer reports "0 violations" just the same when no Kern rule
ran at all:

```bash
sf code-analyzer rules --rule-selector pmd:KernDXFrameworkPackageSide --config-file code-analyzer.yml --view table
```

**Expected:** `Found 7 rule(s)`, listing `KernCoverageExemptRequiresReason`, `KernInvocableClassNeedsNoArgConstructor`,
`KernNoBooleanExceptionThrown`, `KernNoCoverageTheatre`, `KernNoLegacyAssert`, `KernRestResourceNaming` and
`KernTriggerMustDelegate` (the rules of `scanner/kerndx-framework-ruleset.xml`; counted 2026-10-11). The 27 of 2.3's
note are the full `pmd:KernDXFrameworkCompliance` set that 2.3a uses, whose 42 violations already prove it loaded. Any
other number, or none, means the rulesets did not load: stop and fix the configuration before reading 2.3b's result. On
a machine without Python 3.10 the command also prints an error for the `flow` engine; it does not affect the PMD rules.
Then run the scan:

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

**Expected:** `kerndx/use-component-builder` errors only in the framework components listed in
`release-testing/runner/lightning-element-components.json` (17 on 1.10), which extend `LightningElement` on purpose and carry no
inline disable. An error in any other component is a violation; the runner records that count as `eslint.frameworkViolations`
(expected 0) and names any listed component the rule no longer reports, so it can come off the list.

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
node release-testing/runner/perf-history.js --logfile <phase2-log-path> --package-version <the installed version>
```

Older keys in `release-testing/results/perf-history.json` end in `-unknown` (`section-44-unknown` and so on): those
harvests were not given the package version they measured, so their rows cannot be told apart by release. Give every
harvest `--package-version <the installed version>`, so each release starts its own baseline; on the development org,
which has no package, use `--development-org` instead (the section 83 note says how it names the rows).

This phase NEVER fails the build on timing alone. Behaviour assertions in each section script are the only hard gate;
this step prints WARN/WARN! lines for regressions ≥1.3×/≥1.5× off the rolling 5-run median for human review.

**Sections covered** (the 8 load tests, section 83 and sections 86 and 87 that emit `PERF_ROW` lines):

| Section | Short name         | What it measures                                                    |
|---------|--------------------|-----------------------------------------------------------------------|
| 44      | masker             | `UTIL_FrameworkMasker` bulk throughput (200 records)                 |
| 45      | qry-aggregate      | `QRY_Builder` GROUP BY + ROLLUP cardinality                          |
| 46      | trigger-fanout     | `TRG_Dispatcher` fan-out under bulk DML                              |
| 47      | validation-bulk    | `UTIL_ValidationRule.executeForTrigger()` bulk                       |
| 48      | async-chain-ser    | `UTIL_AsyncChain` context serialization enqueue time                 |
| 49      | async-launcher     | `UTIL_AsynchronousJobLauncher` burst enqueue time                    |
| 50      | logger-pe-quota    | Logger PE flood wall-clock (scoped emit batch)                       |
| 51      | callout-storm      | `UTIL_HttpClient` parallel callout throughput (Node)                 |
| 83      | consoles-at-volume | `runs`, `jobsPerMinute`, `peakActive`, `peakHolding`, `samplesAboveFifty`, `watchdogRowsPerSweep`, `backstopRefusals` and `lockRefusals` from the full run's log (see the section 83 note) |
| 86      | bulk-retry-at-volume | Printed by 86b: `issuesSelected`, `callsSent`, `jobsRun`, `wallMsToDrain`, `issuesPerMinute` |
| 87      | purge-at-volume    | Printed by 87b: `rowsPurged`, `wallMs`, `rowsPerSecond`, `batches`                                  |

Section 50's row also carries `cpuMsPerEntry` (printed by 50b) beside its earlier measures.

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

Phase 3 is fully automated by Playwright. The 131 visual checks (numbered V1 through V159, with gaps between
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

### Exploration at volume

Run this after section 83's full run and before the Phase 3 battery (`npm run test:e2e`), while the full load is
still in the org. The order matters: part 1's `beforeAll` purges every log entry in the org, and part 12 then
tears down the load whose entries are gone and lays a staged load of its own, so a load laid before Phase 3 does
not survive it. Walk both consoles against the full load:

```shell
node release-testing/e2e/explore-consoles.js --manifest tmp/consoles-at-volume/manifest.json
```

The walk covers both consoles against the load the manifest describes. On the Chain Monitor: the unscoped and
scoped lists, every status filter, the name filter, every sortable column, every page, the detail of a run three
levels down and of a restart clone, Launched under, the operator buttons' gates and the live stream. On the Log
Console: entries and problems, levels, origins, the six date presets and a custom range, id and body search, the
pills, the action banner with its chips and "N more", page sizes 25, 50 and 100, and the drawer with its
timeline. Then the three hand-offs between the two consoles. Every count is checked against the database.

Every server read is timed in the browser, and every console open is timed until the list settles. Each kind is
judged at the 75th percentile against 1 second per read and 3 seconds per open (`--timing-budget-read` and
`--timing-budget-page` change the two budgets, in milliseconds). A breach is a finding with its measured number.

On the subscriber org, the findings (`exploration-findings.md`), the `screenshots` folder, `timings.json` and a
copy of the manifest land under `release-testing/results/<version>/consoles-at-volume/`, where `<version>` is the
last `Kern@` alias in `sfdx-project.json`; commit them with the results file. On the development org they land
under `tmp/consoles-at-volume/exploration/`, and `--output-directory <folder>` sends them elsewhere. The command
exits 1 while any reportable finding stands (observations alone do not count) or the walk was cut short, so this
step stays red until the maintainer rules on each finding: fix it, park it to the board, or accept it.

Part 12 lays its own staged load inside the battery, about twenty minutes of its `beforeAll`: it waits for the
framework's batches to finish, tears down a verified load that has lost its chain rows or its log entries (part
1 purges every log entry), and runs the driver in staged mode, reusing a verified staged load that is still whole.
Run on its own through `npm run test:e2e:part12`, part 12 reseeds: Playwright runs the parts it depends on first,
part 1 purges the log entries, and the guard tears the old load down, whatever its mode. Only a run with
Playwright's `--no-deps` over an intact load of another mode fails in its `beforeAll`, because the driver refuses
a staged run over a full manifest; tear that load down first with the manifest's own mode
(`node release-testing/scripts/consoles-at-volume.js teardown --mode full`).

**Journeys only the installed package can prove** (masked stack frames, install-time permission writes, the
namespace echoed in page action references, the upgrade leg and version gates) are meant to use `skipUnlessPackaged`
from `release-testing/e2e/helpers/skip-guard.js`, which skips a journey with its reason on the development org. No
spec calls it yet. Two journeys carry their own check instead: V98 (part9) skips itself on an org with no namespace,
and V142 (part10) runs but skips its Framework-origin branch there and says so in a note. Part 12 needs neither.

### Test Specs

| Spec file                          | Checks            | What it tests                                                                                                                                                                                   |
|------------------------------------|-------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `part1-app-core.spec.js`           | V1-V5, V1b-V1k    | App Home, Health Check sections + customize flow, Chain Watchdog one-click schedule and its editor, Log Entries, Scheduled Jobs, API Harness, API Calls and the Aborted list view |
| `part2-api-config.spec.js`         | V6-V10, V158-V159 | Echo results, API Issues, Streaming Monitor UI, CMDT, Login Frequencies; V158 a Standard User holding Kern API Issue Resolver (and, from the subscriber's own `SubscriberRunFlows`, the user permission Run Flows, which a managed package cannot grant) opens an API issue, sees External System May Have Acted beside Status, presses Retry and opens the issue's API call; an administrator keeps Retry; V159 the same user selects three API issues of the packaged example service on the list and presses Retry Selected: the screen says 2 of 3 were queued, the unflagged issue resolves beside a Completed call (one real POST to the public test API), and the flagged issue and the one whose record has a call in progress stay Open; nothing is mocked or purged |
| `part3-lwc-integration.spec.js`    | V11-V14           | LWC components, module tests, Account triggers, log entries                                                                                                                                     |
| `part4-scheduler-exec.spec.js`     | V15-V18, V138, V156 | Job execution (Purge, Login History), cleanup verification; V138 the editor refuses a sub-hourly cron before save; V156 a class missing from the cached list can be typed, and a name that cannot be scheduled is refused at the field |
| `part5-streaming-setup.spec.js`    | V19-V24, V104-V105, V114 | Subscribe to LogEntryEvent, CDC, Standard PE, trigger events; Org Limits card grid (worst-first bands, sort + search); native-SVG timeline dots/tooltip/select contract                                                                          |
| `part6-streaming-advanced.spec.js` | V25-V29, V99-V103 | Generic channel (stale cache), publish, download, cleanup; Event usage metrics (prototype contract, view states, seeded-data roundtrip, Enhanced Usage Metrics toggle, CDC channel-list purity) |
| `part7-async-chain.spec.js`        | V10-V17           | Async chain execution, polling, record verification, API callout, handler isolation                                                                                                             |
| `part8-chain-monitor.spec.js`      | V30-V39, V115-V125, V36 extended, V145, V146 | Chain Monitor UI: split panel, columns, detail metadata, step timeline, failed-chain error, filters, sorting, launched-chain and record-page timelines, operator retry, restart, clear-stalled, kill switch and abort, the live activity stream, empty states, status panel legend and two actions, a manually retried step's marker and its step words ("Did not run" before the retry), the Duration sort with a stalled run and a run that ended without storing a duration |
| `part9-masking-advisor.spec.js`    | V90-V98           | Data Masking Advisor: landing, add-object flow, rule detail, export, health-check masking posture                                                                                               |
| `part10-log-console.spec.js`       | V106-V113, V122-V137, V142, V143, V144, V154 | Log Console: launcher tile + namespaced tab, ribbon summary + severity filter, date ranges (needs audit back-dating), endless scroll, sorting, debounced search incl. SOSL body leg, Chain Monitor cross-links, detail drawer + chain-gated timeline, origin badge, exact source pin, Origin filter, Framework attribution in a managed install; the Source column's writer and sort and the detail drawer's icons and copy button names |
| `part11-job-runner.spec.js`        | V139-V141, V155, V157 | Job runner: Activate every 15 minutes, Deactivate flags a waiting job, Repair; a job on the runner shows its effective cadence, runs at a tick and records the outcome; Run now keeps the cursor and refuses under Skip while the previous run is live; a Standard User holding only the Job Runner Management set creates, schedules and runs a job but cannot delete it or edit its platform job id; the Scheduled Jobs Fast Start's screen steps as written: a record schedules the demo class, it moves onto the runner, Run now succeeds, a failed run's View log, switch off |
| `part12-consoles-at-volume.spec.js` | V147-V153 | The consoles at volume on the staged load: a page turn loses and repeats no row among chains started in the same second; the scoped list, the banner and the database agree on the 2,000-run action; a run three levels down and a restart clone read correctly; a retry pressed on a real failed run; the console pager past page 7 at page size 100; both deep links |

**Expected:** 131/131 tests passing (the `test(` blocks across the twelve part specs, counted 2026-10-11: part1 15,
part2 7, part3 4, part4 6, part5 9, part6 10, part7 8, part8 23, part9 9, part10 28, part11 5, part12 7). Part11 needs
`ManageJobRunner` assigned to the e2e admin; the spec assigns and removes it itself.

**V158 toast step (by hand at the pass, until the journey takes it):** V158 proves Retry on an issue of a service that
accepts retries. The other answer needs the subscriber record `kern__ApiSetting.RetryLiveNoRetry` (Retry Issues on,
Active off; deployed in 1.4). Save one Open outbound issue for it as a plain row, without sending a call:

```bash
sf data create record -o $SF_SUBSCRIBER_ORG_ALIAS -s kern__ApiIssue__c -v "kern__ServiceName__c=API_RetryLiveNoRetry kern__Direction__c=Outbound kern__Status__c=Open"
```

Open the new issue's record page as the administrator and press **Retry**. Expected: the toast reads "This service is
paused or switched off, so the call was not sent and the issue stays open. ..." (label
`RetryApiIssue_ServiceNotAcceptingRetries`), and the issue still reads Open after a page reload. The older text "The
call was not sent: this service has no API setting, or Retry Issues is off ..." (`RetryApiIssue_RetryNotEnabled`)
means the record arrived with Retry Issues off. Delete the issue afterwards and write the outcome in the results file.

Run part10 on its own with:

```bash
npx playwright test --config release-testing/e2e/playwright.config.js part10-log-console
```

part10 seeds its own Log Console fixtures in `beforeAll` (`seed-log-console.apex` + `seed-log-console-bulk.apex`)
and tears them down in `afterAll`; it needs no manual data staging beyond the Phase 1 audit-field recipe.

**Eyes-on check after the part10 seed (no test number):** open the Log Console and read the Top sources card. It
should name a class with the **Framework** badge, and it should never show the bare namespace (`kern`) as a writer.

**Who-wrote-it record checks (no test number; first owed on the first 1.8 subscriber build):** an entry's
Framework origin exists only where the framework has its namespace, so the development org can never show it and the
installed package is the first place these run for real. V142's framework branch (a `kern.`-prefixed class-method
reads Framework unless a Flow or component context was on top of the stack when it was written, which is why the
write-log action's own default label is excluded) is skipped on a no-namespace org and executes for the first time
here; its annotation must report a positive count of rows checked. Save each query's output with the run's evidence.

1. **Origins present.** On the fresh-install leg, after part10 has finished (its `afterAll` removes its fixtures) and
   with the volume seed in place:
   `sf data query -o "$SF_SUBSCRIBER_ORG_ALIAS" -q "SELECT kern__Origin__c, COUNT(Id) FROM kern__LogEntry__c GROUP BY kern__Origin__c" --json`.
   Expected: `FRAMEWORK` is present with a count above zero, and no group has a blank origin: every seed stamps both
   fields on every row it writes, and part1 deletes the one entry it inserts directly. A blank group means a row was
   written outside the logger or a seed missed the two fields: name its writer before accepting it. On the upgrade
   leg every entry from before the upgrade is blank by design, so there the check is only that `FRAMEWORK` is present.
2. **The ranking at volume.** With `seed-log-volume.mjs` loaded, open the Log Console in **Individual entries**,
   switch every level on, leave every other filter clear (the card counts only what the filters let through), and pick
   **Custom range…** over a window narrow enough to stay under the 22,000 rows the breakdown will scan (the volume
   seed's default writes about 4,000 rows a day on average, so a day or two; over the ceiling the card is not shown).
   Note the Top sources card's first writer, its origin badge and its row count; the card ranks three. Then run the
   same window as absolute instants:
   `SELECT kern__Origin__c, kern__Source__c, COUNT(Id) FROM kern__LogEntry__c WHERE kern__OccurrenceCount__c = null AND CreatedDate >= <from> AND CreatedDate <= <to> GROUP BY kern__Origin__c, kern__Source__c ORDER BY COUNT(Id) DESC LIMIT 5`.
   Expected: the query's first row that has both an origin and a source is the card's first writer, with the same
   origin and the same count (the card leaves rows without a writer out, and on a tie it orders by writer name). The
   presets are rolling windows measured in minutes, so `LAST_N_DAYS` never matches one; only a custom range gives
   instants a query can repeat. Click that writer: the list's total equals the count, and the Origin filter follows
   the writer's origin.
3. **The capture seed's first run.** `release-testing/scripts/capture-seed.apex` compiles only in the installed
   package's org, so its block that stamps origin and source has so far been proven through a no-namespace copy. On
   its first run here (the media re-capture step below seeds with it), confirm that the seed's own rows all carry a
   writer:
   `SELECT COUNT(Id) FROM kern__LogEntry__c WHERE kern__ClassMethod__c != null AND kern__Origin__c = null AND (kern__Fingerprint__c LIKE '%demo-%' OR kern__TransactionId__c LIKE 'demo-%' OR kern__CorrelationId__c = '7f3a9c14b8d2e5f6a0c1b2d3e4f50617')`
   returns 0. The three markers are the seed's own (`capture-seed.apex` clears its prior run by them); the correlation
   id is the `DEMO_CORR` constant at the top of that script, so re-read it if the script changes. Without them the
   query answers about the whole org, where any entry from before an upgrade matches too.
4. **A writer worked out from the stack.** An entry emitted with no `.at()` takes its class and method from the top
   frame of the stack. The development org can only half prove this: there the framework's own classes are ordinary
   Apex, while in an installed package they are masked to `(kern)` and carry no location at all. This check is now a
   test: `SubscriberWhoWroteIt_TEST` (2.2) writes such an entry from the subscriber class `SubscriberWhoWroteIt` and
   asserts that `kern__ClassMethod__c` reads `SubscriberWhoWroteIt.write`, `kern__Source__c` reads
   `SubscriberWhoWroteIt` and `kern__Origin__c` reads `APEX`. Its failure, a row that names a `kern` class or one with
   all three fields empty, means a framework frame reached the top of the stack where the masked frames of an
   installed package should have left the subscriber's own on top. Nothing to do here by hand.

**Manual retry record checks (part8; no test number; first owed on the first 1.8 subscriber build):** V145 and V146
were written against the development org, where the package has no namespace and the field history of a retry was not
read, so the record side of the manual retry marker runs here for the first time. Save each query's
output with the run's evidence.

1. **The two fields on the record.** After V145 has passed, in the subscriber org:
   `sf data query -o "$SF_SUBSCRIBER_ORG_ALIAS" -q "SELECT kern__LastManualRetryAt__c, kern__ElapsedMs__c, kern__DurationMs__c FROM kern__AsyncChainExecution__c WHERE kern__ChainName__c = 'E2E_ManualRetryMarker' ORDER BY CreatedDate DESC LIMIT 1" --json`.
   Expected: `kern__LastManualRetryAt__c` holds the instant the retry was pressed, and `kern__ElapsedMs__c` equals
   `kern__DurationMs__c` now that the run has finished.
2. **The record page.** Open that run's record page. Expected: **Last Manual Retry At** and **Elapsed (ms)** are both
   shown, read-only, after **Duration (ms)**. "Did not run" is automated: V145 reads the step words of its run and
   asserts "Failed" then "Did not run" before the retry and "Completed" on both steps after it. By eye only: open the
   Chain Monitor and on an aborted or crashed run confirm the first step with no result of its own reads "No result
   recorded"; "Running" on a step still going is by eye too, when a run is caught in that state.
3. **Field history (namespaced org only).** Open the field history related list on that run and read what the retry
   recorded: `Status__c` and `CompletedAt__c`, the two tracked fields the retry writes, are two of the four the object
   tracks, so read what the related list shows for them. Write what it shows into the run's results: the spec could not verify this on
   the development org.
4. **The upgrade leg.** **PREREQUISITE, set up BEFORE the upgrade leg:** while the org is still on the released
   version (between the two installs in 1.3b), clone the **Kern Async Chain Monitor Read Only** permission set and
   give a test user on a profile other than System Administrator that clone as their only Chain Monitor access. The
   installs above use the default AdminsOnly security type, which grants the administrator profile the new fields'
   access at upgrade, so an admin user cannot show what this check is looking for. A clone made after the upgrade
   already carries the new fields and proves nothing, so the leg has to be repeated.
   First run V145 against the upgraded org (`SF_SUBSCRIBER_ORG_ALIAS=KernUpgradeSubscriber`), so a run retried on the
   new version exists there; a run retried before the upgrade carries no marker.
   After the upgrade, sign in as that user, open the Chain Monitor, sort by Duration and open a retried run.
   Expected: the list sorts and the retry marker appears (the monitor's own reads do not check field access), and the
   two new fields are absent from the record page. Then, as an admin, grant Read on **Last Manual Retry At** and
   **Elapsed (ms)** to that cloned permission set, and reload the run's record page as the test user. Expected: both
   fields now appear, after **Duration (ms)**. The two halves together are the upgrade note in the 1.8 release copy,
   proven on the real path.
5. **The package's own screens, on both legs.** 1.8 swaps **Duration (ms)** for **Elapsed (ms)** in three places the
   Chain Monitor does not draw: the **All** list view on the Async Chain Executions tab, the strip at the top of a
   run's record page (the compact layout), and the tab's recent-records list with global search results (the search
   layouts). On the fresh-install org, with a run still going (a stalled fixture run will do), open all three.
   Expected: each shows **Elapsed (ms)**, and the run still going carries a number where **Duration (ms)** was empty.
   Then open the same three on the upgraded org and WRITE DOWN what each one shows. Whether an upgrade replaces a list
   view, a compact layout and a search layout that the released version installed was not verified when the swap was
   made, so either outcome passes: an upgraded org that keeps **Duration (ms)** there has lost nothing it had. The
   answer goes into the run's evidence and onto 1.8 board row 112. One thing to look for if the upgrade does replace
   them: a user whose access comes from a cloned permission set loses the column until Read on **Elapsed (ms)** is
   granted, which is the same grant item 4 proves.

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
- V2-V5 — Log Entries, Scheduled Jobs lifecycle, API Test Harness, API Call records. V5 also checks that the API
  Calls tab's list-view picker offers the **Aborted** list view (no by-eye check left for it).
- The Health Check's longer Platform Cache texts (labels `HealthCheck_OrgCache_NotAllocated`, "...Cached queries still
  work within a single request but...", and `HealthCheck_SessionCache_NotAllocated`, "...Queries a selector asks to
  keep for the session are kept for the current request only.") show only on an org without the cache partitions.
  The pass org has both partitions (1.4), so these texts never show there and no check here looks for them.
- V4 also asserts the harness seeds a service's declared required inputs as locked rows (`password` for Query Pwnd
  Passwords (REST)), keeps Execute disabled until each one has a value, and labels Record ID "(optional)" for services
  that need no triggering record. Those assertions have never run against an org: they were added after the 1.7 build,
  so the first 1.8 subscriber build owes this run plus an `api-harness` hero re-capture (BACKLOG-1.8 §33).

### Prerequisites

- KernDX package installed in subscriber scratch org (alias: the value of `SF_SUBSCRIBER_ORG_ALIAS`)
- Subscriber test code deployed (classes, triggers, CMDT, LWC components, FlexiPage, tab)
- Health Check prerequisites configured (org cache partition, session cache partition)
- Audit-field back-dating enabled (Phase 1 two-step recipe) — `part10`'s date-range check hard-fails without it
- Profile Filtering on (Phase 1.4 fixture) and the two Spring '27 release updates enabled — the run then
  exercises the framework's profile reads the way a Winter '27 org does
- **Realism and volume seeded** with the `release-testing/scripts/` tooling: `seed-log-volume.mjs`
  (back-dated `LogEntry__c` volume via Bulk API 2.0; `--rows 120000 --days 30` default, `--teardown` to
  purge) and `seed-chain-scenarios.sh` (real multi-step chains across failure/recovery shapes plus
  synthesized Running/Stalled rows). The consoles behave differently at volume — a run against a
  near-empty org proves far less than it appears to.
- **The consoles-at-volume full load laid and explored before the battery** (section 83 in full mode, then
  "Exploration at volume" and the consoles' hero capture, Phase 4.5 step 5). The battery does not keep that
  load: part 1 purges its log entries, and part 12 tears it down and lays a staged load of its own (about twenty
  minutes).
- **Running any part against a different org than the runbook's subscriber org** (for example the
  development org while iterating on a fix): `export SF_SUBSCRIBER_ORG_ALIAS=<that alias>` first. The
  local runner configuration falls back to the standing subscriber alias when the variable is unset, so
  an un-exported run silently tests the installed package version, not your working tree — the symptom
  is a "stale bundle" that no redeploy fixes.

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
| Phase 2 — Scanner Ruleset | PASS/FAIL | XX/42 expected violations, 7 package-side rules loaded, 0 production violations |
| Phase 2 — ESLint LWC Scan | PASS/FAIL | 0 kerndx/use-component-builder violations |
| Phase 3 — Visual Tests    | PASS/FAIL | XX/131 Playwright tests passed |
| Phase 3 — Exploration at volume | PASS/FAIL | findings ruled: N fixed, N parked, N accepted; drain rate NN jobs per minute, peak active NN; P75 reads NNN ms, opens NNN ms; evidence: engine N runs (genuine Stalled N or none), operator N retries, N restarts, N aborts, N kill-switch aborts, N dead-job re-drives, N dead-job runs ended Failed at the started step, clone N rows, fixture N Stalled rows |

## Phase 2 — Automated Test Results

| Script | Result | Pass/Total |
|--------|--------|------------|
| section-1-trigger-lifecycle | PASS/FAIL | X/6 |
| section-2-trigger-bypass | PASS/FAIL | X/7 |
| ... | ... | ... |
| RunLocalTests | PASS/FAIL | XXX/XXX |

## Phase 3 — Visual Test Results

[Generated by Playwright reporter — see current-run.json]

## Findings

- [List any issues, warnings, or observations]

## Promotion Decision

- [ ] **PROMOTE** — All tests passed. Ready for `node scripts/promote-package.js --version <X.Y.Z-N>`.
- [ ] **HOLD** — Issues found. See findings above.
- Heavy Windows proof: run <id>
- Real-Windows stage: run <id>
```

### Recording Steps

1. Copy the template above into `release-testing/results/<version>.md`
2. Fill in results from Phase 2 and Phase 3
3. Record any findings or deviations
4. Check the promotion decision box
5. Verify the `packageVersion` header in `results/current-run.json` matches the cycle under test (the reporter
   preserves whatever header it finds — a stale value from the previous cycle must be corrected by hand)
6. Commit the result file
7. Inside a preview window (1.1) there are two files, one per build: the preview build's carries Phases 1 to 4, the
   production build's carries Phase 1, Phase 5 and the promotion decision, and names the preview build's file for the
   pass it rests on.
8. Promote with `node scripts/promote-package.js --version <X.Y.Z-N>`, never a bare `sf package version promote`
   (add `--dry-run` first to see the changes). The script promotes the build and, only when the promotion succeeds,
   writes the released state in one pass: the version's entry in the record of promoted versions, the release note's
   `**Release status:**` line, the Package status sentence in `CLAUDE.md` and the Metrics guide's latest-version rows.
   Commit the files it printed. `node scripts/validate-docs.js` fails CI while any of those lines disagrees with the
   record, and the mirror sync refuses to publish a release note that still says "in release testing" for a promoted
   version.

---

## Phase 4.5 — Doc Media Staleness Check (pre-promotion)

The docs site ships screenshots and hero-loop recordings captured from a live org. UI changes silently
invalidate them — this check runs before **every** promotion / mirror sync so stale media never reaches the
live site. (Origin: the 1.6.0-2 cycle found 6 of 13 media surfaces stale, including a July-1 full redesign
of the org-limits panel that no one had flagged.)

**Canonical media location:** `docs-site/assets/stills/` and `docs-site/assets/recordings/` (each loop =
`.webm` + `.mp4` + `-poster.jpg`). `docs-site/scripts/prepare.mjs` copies `assets/` into the gitignored
`src/public/` at site build — only ever edit/commit `assets/`.

**Run the guard first:** `node scripts/check-media-staleness.js` reads the table below and prints, per asset, its
capture commit, the newest commit on its sources and a verdict; under each STALE asset it lists the commits of
step 2 with test files and metadata descriptions already left out. Exit 0 means every asset passes; `--json`
prints the same for tooling. Steps 1 to 3 are what it does and how to judge what it lists. It takes the asset's
last commit as the capture, so a re-encode without a reshoot hides staleness: reshoot, do not re-encode.

### Procedure (per asset)

1. Capture date: `git log -1 --format='%h %ad' -- docs-site/assets/<file>` (a re-encode without a reshoot
   does not reset the clock — use the last commit that actually re-captured the frame).
2. Candidate commits: `git log --oneline <capture-commit>..HEAD -- <source paths from the table>`.
3. Empty log → PASS. Otherwise inspect each commit's diff and classify:
   - **NON-VISUAL** (no re-capture): test/jest files, `@date` headers, `.js-meta.xml` descriptions,
     formatter reflow, EOF-newline serializer noise, eslint suppressions, aria-only attributes,
     Custom Label externalisation whose values are byte-identical to the removed literals,
     error-path-only changes the captured flow never shows.
   - **VISIBLE** (re-capture required): template/structure changes, new or removed buttons/rows/columns/
     cards, CSS that changes appearance, label **value** changes, new modals reachable in the captured
     flow, check-count or card-grid changes on the surface.
4. Sweep the whole frame, not just the headline bundle: composed child components (read the templates),
   Custom Label values the frame renders, and the chrome — the hosting FlexiPage, CustomTab, and the
   `CustomApplication` nav-tab list are all in shot.
5. Re-capture stale assets against a subscriber org running the release candidate: stills via the e2e
   `[stills]` project (`release-testing/e2e/specs/capture-stills.spec.js`, seeded by
   `release-testing/scripts/capture-seed.apex`), hero loops via the hero-loop recording flow. Commit the
   media **with** the doc changes they illustrate, **before** the mirror sync. The consoles' hero capture is
   the exception to this step's place in the order: it runs on section 83's full load, after the
   exploration at volume and before Phase 3, because Phase 3 replaces that load with a staged one.

**Capture-state nuance:** a pristine install shows **three** health-check warnings (Chain Abort
Capability — the `AsyncChainAbort` permission set ships assigned to nobody — plus Chain Watchdog and Data
Retention). Assign the runner the `AsyncChainAbort` permission set before capturing if the two-warning
configured-org baseline is wanted in frame.

### Asset → source mapping

The guard reads this table, so every cell in the Asset, Source paths and Reviewed through columns is a
comma-separated list of backticked paths (globs allowed) and nothing else; the script refuses a cell with other
words. A source path sits under `force-app/main/default/` unless it starts with `force-app/`. **Reviewed
through** is filled only when every commit the guard listed for that asset is NON-VISUAL: it holds the newest of
them, and the next run hides it and everything before it. If any listed commit is VISUAL, re-capture and leave the
cell empty; the cell is cleared whenever the asset is re-captured.

| Asset | What the frame shows | Source paths to diff (under `force-app/main/default/` unless noted) | Reviewed through |
| --- | --- | --- | --- |
| `stills/kern-home.jpg` | Kern Home tile page + readiness banner | `lwc/kernHome`, `lwc/healthCheck`, `classes/CTRL_HealthCheck.cls` | |
| `stills/org-limits.jpg` | Org limits panel | `lwc/orgLimits` | |
| `stills/event-usage.jpg` | Streaming monitor shell, Event Usage panel (the controller's usage methods) | `lwc/streamingUsageMetrics`, `lwc/streamingUsageFilters`, `lwc/streamingMonitor`, `lwc/streamingSidebar`, `lwc/streamingSubscriptions`, `lwc/notice`, `classes/CTRL_EventMonitor.cls` | |
| `stills/async-timeline.jpg` | `AsyncChainExecution__c` record page (highlights + Step Timeline) | `lwc/chainStepTimeline`, `flexipages/AsyncChainExecution*`, `layouts/AsyncChainExecution*`, `objects/AsyncChainExecution__c/compactLayouts/*` | |
| `stills/api-calls-picker.jpg`, `stills/api-issues-queue.jpg`, `stills/log-entry.jpg` | Record pages / list views (standard components only; the objects' list views, layouts and flexipages) | `objects/ApiCall__c`, `objects/ApiIssue__c`, `objects/LogEntry__c`, `layouts/ApiCall__c*`, `layouts/ApiIssue__c*`, `layouts/LogEntry__c*`, `flexipages/ApiCall.*`, `flexipages/ApiIssue.*`, `flexipages/LogEntry.*`, `lwc/retryApiIssue` | |
| `recordings/health-check.*` | Readiness banner, apply-retention flow | `lwc/healthCheck`, `lwc/kernHome`, `lwc/applyRetentionModal`, `lwc/scheduleChainWatchdogModal`, `classes/CTRL_HealthCheck.cls` | |
| `recordings/chain-monitor.*` | Chain Monitor, open-a-failed-run flow | `lwc/chainMonitor`, `lwc/chainMonitorDetail`, `lwc/chainMonitorList`, `lwc/chainStepTimeline`, `lwc/chainAbortModal`, `classes/CTRL_ChainMonitor.cls` | |
| `recordings/streaming-monitor.*` | Subscribe → publish → arrive flow (every streaming bundle) | `lwc/streaming*`, `lwc/utilityStreaming`, `classes/CTRL_EventMonitor.cls` | |
| `recordings/api-harness.*` | Outbound + inbound harness run | `lwc/apiTestHarnessForm`, `lwc/jsonViewer`, `classes/CTRL_ApiTestHarness.cls` | |
| `recordings/log-console.*` | Grouped problems → filter → correlation timeline | `lwc/logConsole`, `lwc/logConsoleContext`, `lwc/logConsoleDetail`, `lwc/logConsoleTable`, `lwc/jsonViewer`, `classes/CTRL_LogConsole.cls` | |
| `recordings/masking-advisor.*` | Scan → drill-into-an-object flow (every masking bundle) | `lwc/dataMaskingAdvisor`, `lwc/masking*`, `classes/CTRL_MaskingAdvisor.cls` | |
| `recordings/scheduled-jobs.*` | Cron builder flow (plain-English schedule, invalid-time rejection) | `lwc/scheduledJobEditor`, `lwc/scheduledJobEditorModal`, `lwc/scheduledJobDetail`, `lwc/cronExpressionEditor`, `lwc/utilityScheduledJob`, `classes/CTRL_ScheduledJob.cls` | |
| `recordings/class-type-resolver.*` | Setup helper opened from the readiness banner (with its host page) | `lwc/classTypeResolverSetupModal`, `lwc/kernHome`, `lwc/healthCheck` | |

`*-poster.jpg` files are the first frame of their loop — they go stale with the recording and are
re-captured together with it. Shared plumbing bundles (`componentBuilder`, `baseComponent`,
`moduleNotification`, `utilityString`, `utilitySystem`) rarely change rendered output, but a label-value
change to toast titles or shared text would show in several loops — check them when their `git log` since
capture is non-empty.

---

## Phase 4.6 — The Windows proof (after promotion, before the mirror sync)

**First, before promotion day: a fresh throwaway org and its login secret.** The real-Windows stage below signs in to a
throwaway scratch org through the repository secret `THROWAWAY_ORG_SFDX_AUTH_URL`. A scratch org lives 30 days, so the
org and the secret are recreated for every release, and the login has expired on release day before (1.9, 1.10). The
maintainer does this step, because it writes a login into a repository secret, and does it while release testing
runs, so that it never holds up the sync. It needs a free scratch-org slot on the Dev Hub (the Dev Hub allows three):
delete a finished release-testing org first if all three are in use. Create the org from the definition Phase 1 uses
(the preview one inside a preview window), then hand its login to the secret without the value ever touching a file:

```bash
sf org create scratch -f config/project-scratch-def.json -a throwaway -v DevHub -y 30 --wait 15 --no-namespace
sf org auth show-sfdx-auth-url -o throwaway --json | jq -r .result.sfdxAuthUrl | gh secret set THROWAWAY_ORG_SFDX_AUTH_URL
```

Two workflow runs, both started by hand from this repository, both green before the mirror sync. They cost Windows
runner minutes (billed double), which is why neither starts on a push here; a push here starts at most the light
depth, and only when a terminal block in a shipped guide, or a tool a reader runs, changed. The real-Windows stage
runs only in this private repository: the mirror carries neither the throwaway org's secret nor its workflow. The
heavy proof also runs on the public repository, where its minutes are free: the mirror's `ci.yml` starts it after every
push to `main`, so a mirror commit that lacks a Windows fix from source shows red there until the next sync carries
the fix.

**The heavy proof.** Every shipped npm script that needs no org, the pipeline's own tests, the pipeline bundle build,
Path 3 of the install guide run for real with the real CLI, then the light proof (the guides' commands in every
Windows terminal and the Path 2 journey):

```bash
gh workflow run windows.yml --ref master -f depth=heavy
gh run watch
```

Green means: the "shipped npm scripts" summary table shows every script as pass or excused with a reason, both
`doctor` steps found `sf`, and the light steps passed. Read the two first-run-claims tables: they carry the exact
wording the failure FAQ quotes.

**The real-Windows stage.** The real CLI installed from nothing, the released package installed or upgraded in the
throwaway org, and one command of each documented kind run against it:

```bash
gh workflow run windows-real-org.yml --ref master -f package_version_id=<the promoted 04t>
gh run watch
```

Green means: the journey passed and the shapes table shows no `NOT REACHED` and no `DEAD ROW`. Record both run ids
in the Phase 4 result file.

`sf org display` prints the auth URL as `[REDACTED]`; only `sf org auth show-sfdx-auth-url` gives it. When the login
step fails, the org is gone (expired, or its secret revoked) and the step after it says so in the log and the job
summary: recreate the org, refresh the secret, start the workflow again. A later step failing with the org unreachable
means the same. The subscriber test org is not used for this stage because the journey deletes at its end the same
sample classes and configuration records that Phase 1 deploys there.

---

## Phase 5 — Extended Load (pre-tag only)

Run only when promoting beta to GA. Adds ~45-60 min wall-clock.

**Pre-conditions:**

- Fresh scratch org under `SF_SUBSCRIBER_ORG_ALIAS` (cumulative load consumes governor headroom)
- Org Cache + Session Cache configured (per Health Check)
- All Phase 1-4 phases passed first

**Run:**

```bash
npm run test:load:extended
```

The command (`release-testing/runner/load-extended-runner.js`) runs each of the four files in
`release-testing/scripts/load-extended/` once, in this order: `sustained-masker-soak.apex` and
`sustained-logger-pe-flood.apex` through `sf apex run`, then `parallel-callout-burst-100.js` and
`parallel-cache-contention.js` through `node`. For the two Apex files one `sf apex run` is a single iteration, the
smoke test, not the soak. The 30-minute soaks are a hand procedure: each Apex file's header ("OPERATIONAL PATTERN") says how
to schedule its Schedulable once a minute, what to query afterwards and how to stop a job that did not stop itself at
its thirtieth run. Run both soaks by hand before GA promotion,
one after the other.

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
