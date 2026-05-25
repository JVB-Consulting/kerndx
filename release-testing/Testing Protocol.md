# Release Testing

> **`<repo-root>` placeholder.** Commands below reference `<repo-root>` where the absolute path to your project clone goes. Substitute mentally with the output of `pwd` from your project's root directory, or set an env var (`REPO_ROOT=$(pwd)`) and run `cd "$REPO_ROOT"`.

## Configuration

Set `SF_SUBSCRIBER_ORG_ALIAS` to the alias of your subscriber test scratch org before running any runner script. The runners read this env var via `release-testing/runner/subscriber-config.js` and throw a clear error if it is unset.

```bash
export SF_SUBSCRIBER_ORG_ALIAS=YourSubscriberScratchAlias
```

## Subscriber Test Cycle

Run steps in order — each depends on the previous.

```bash
# Step 1: Build package, note SubscriberPackageVersionId (04t...)
node scripts/build-package.js --skip-validation

# Step 2: Delete existing scratch org (ignore error if none)
sf org delete scratch -o $SF_SUBSCRIBER_ORG_ALIAS --no-prompt

# Step 3: Create non-namespaced scratch org
# CRITICAL: Must run from /tmp/kern-subscriber/ — NOT dev project (has "namespace":"kern")
mkdir -p /tmp/kern-subscriber/force-app
cat > /tmp/kern-subscriber/sfdx-project.json << 'TMPEOF'
{"packageDirectories":[{"path":"force-app","default":true}],"name":"KernSubscriber","sourceApiVersion":"66.0"}
TMPEOF
cd /tmp/kern-subscriber && sf org create scratch -f <repo-root>/config/project-scratch-def.json -a $SF_SUBSCRIBER_ORG_ALIAS -v DevHub -y 30 --wait 10

# Step 4: Install package (use 04t... from step 1)
sf package install -o $SF_SUBSCRIBER_ORG_ALIAS --package <SubscriberPackageVersionId> --wait 15 --no-prompt

# Step 5: Return to project
cd <repo-root>
```

## Package Upgrade

Always use a fresh scratch org — beta packages cannot be upgraded in-place. Re-run steps 2-5 with the new `SubscriberPackageVersionId`.

```bash
sf org delete scratch -o $SF_SUBSCRIBER_ORG_ALIAS --no-prompt
cd /tmp/kern-subscriber && sf org create scratch -f <repo-root>/config/project-scratch-def.json -a $SF_SUBSCRIBER_ORG_ALIAS -v DevHub -y 30 --wait 10
sf package install -o $SF_SUBSCRIBER_ORG_ALIAS --package <NewSubscriberPackageVersionId> --wait 15 --no-prompt
cd <repo-root>
rm -f release-testing/e2e/.auth/state.json release-testing/e2e/.auth/instance.json
```

The `.auth/` file clear is defence-in-depth: Playwright's `globalSetup` refreshes both files on the next `npm run test:e2e` run, but dev workflows that hand-invoke helpers via `node` before the next runner invocation would otherwise see a stale instance URL or expired session cookies from the old org.

## Load Test Isolation Guarantee

Each load test script (Apex or Node) is self-contained. Three explicit rules apply:

1. **Self-contained setup and cleanup per script** — no script depends on state left by a prior section. Each script creates and tears down its own data.
2. **perf-history harvester accepts `--section=NN`** — updating one baseline never touches other sections' records.
3. **Behaviour assertions are deterministic in isolation** — pass/fail outcomes do not depend on execution order or previously run sections.

## Running a Single Load Test in Isolation

```bash
sf apex run --file release-testing/scripts/section-44-load-masker.apex -o $SF_SUBSCRIBER_ORG_ALIAS
sf apex run --file release-testing/scripts/section-45-load-qry-aggregate.apex -o $SF_SUBSCRIBER_ORG_ALIAS
node release-testing/scripts/section-51-load-callout-storm.js
```

Each script emits `PERF_ROW` lines to debug log / stdout. Capture the log file path for baseline updates (see below).

## Updating a Single Perf Baseline

After a run that produces a log file:

```bash
node release-testing/runner/perf-history.js --section=45 --logfile <log>
```

Only the specified section's entry in the baseline JSON is updated. All other sections are untouched.

## Resetting a Baseline After an Intentional Perf Change

```bash
node release-testing/runner/perf-history.js --reset --section=44
```

This clears the stored baseline for section 44 so the next run establishes a new baseline from scratch. The baseline JSON file (`release-testing/runner/perf-history.json`) is committed to source control — after resetting and re-running, commit the updated JSON alongside the code change that caused the intentional perf shift.

## PERF_ROW Emission Convention

All load scripts emit structured rows that `perf-history.js` parses. The prefix `PERF_ROW: ` (including the trailing space) is required.

**Apex form:**

```apex
System.debug(LoggingLevel.INFO, 'PERF_ROW: ' + JSON.serialize(new Map<String,Object>{
	'section' => 44, 'metric' => 'wallMs', 'value' => wallMs
}));
```

**Node form:**

```javascript
console.log('PERF_ROW: ' + JSON.stringify({section: 51, metric: 'wallMsTotal', value: wallMs}));
```

Keys: `section` (integer, matches script section number), `metric` (string, e.g. `wallMs`, `wallMsTotal`, `throughputRps`), `value` (number).

## Extended Load Suite Cadence

```bash
npm run test:load:extended
```

Runs four extended scripts:

- `sustained-masker-soak.apex`
- `sustained-logger-pe-flood.apex`
- `parallel-callout-burst-100.js`
- `parallel-cache-contention.js`

**Pre-tag only.** This suite runs exclusively when promoting beta to GA. It adds approximately 30-60 minutes of wall-clock time and is NOT part of every release-test cycle.

## Common Subscriber Pitfalls

- **`kern__LogEntry__c` queries: use `kern__UserId__c`, NOT `CreatedById`** (A37) — `TRG_PersistLogEntry` runs as the Automated Process user. Querying by `CreatedById` will miss all log entries.
- **PE flood >150 emits per transaction hits the PublishImmediate governor** (A18) — non-scoped `LOG_Builder.build()...emit()` calls bypass batching. Use `LOG_Builder.scope()` to batch emits within a single transaction.
- **Cache get-modify-put loses ~85-94% of writes under 100-parallel contention** (A40) — Platform Cache has no compare-and-swap. Design for eventual consistency or use a different concurrency strategy for high-contention keys.
- **`TST_Factory.newTriggerAction` is `@TestVisible private`** (A31) — callable only from `@IsTest` classes, not from anonymous Apex. Use `CustomMetadata UPSERT` in anonymous Apex setup scripts instead.
- **Anonymous Apex sync CPU governor is 10 s, not 60 s** — keep busy-waits short; split long-running setup across multiple anonymous Apex executions if needed.
