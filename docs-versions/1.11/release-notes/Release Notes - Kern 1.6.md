# Kern 1.6 Release Notes

**Builds on:** [Kern 1.5 Release Notes](./Release%20Notes%20-%20Kern%201.5.md), [Kern 1.4 Release Notes](./Release%20Notes%20-%20Kern%201.4.md), [Kern 1.3 Release Notes](./Release%20Notes%20-%20Kern%201.3.md), [Kern 1.2 Release
Notes](./Release%20Notes%20-%20Kern%201.2.md), [Kern 1.1 Release Notes](./Release%20Notes%20-%20Kern%201.1.md), and the [Kern 1.0 Feature Reference](./Release%20Notes%20-%20Kern%201.0.md), which together remain the full
reference for everything 1.6 carries forward.
**Platform:** Salesforce API 67.0 (Summer '26), unchanged from 1.5 · **Namespace:** `kern` (rebrandable via [Installation](../docs/Installation.md))
**Release status:** the 1.6 feature set is complete, the build is validated, and end-to-end release testing has passed. The released 1.6 build is 1.6.0-3; its package version id
and release tag are published with the release.

> **What's new since 1.5**, grouped by capability and ordered by impact. 1.6 is the async release: chains now look after themselves. A chain that loses its background job is
> detected, marked Stalled, and, once you schedule the new Chain Watchdog, restarted from the step where it stopped. Steps can retry themselves, a deduplication key stops the same
> chain running twice at once, every ended chain records why it ended, and operations users you nominate can abort a runaway chain straight from the Chain Monitor. Around the
> async wave: the Health Check grows to nine checks with a new one-click fix, trigger bypasses now match case-insensitively, and a set of correctness fixes lands across logging,
> DML, dialogs, and test data.
>
> **Safe to upgrade:** 1.6 is **backward-compatible**. The global Apex surface is purely additive: one new class and six new methods, with no global member removed or changed in
> signature. The metadata surface is additive too: four new fields, one new permission set (which ships assigned to nobody), one new custom permission, two new configuration
> records, and 29 new Custom Labels, with nothing removed or renamed. A few deliberate behaviour changes are worth a read before you upgrade; they are summarised under
> [Upgrading & compatibility](#upgrading--compatibility). For the per-build log, see the CHANGELOG.

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [At a glance](#at-a-glance)
2. [Stalled chains recover themselves](#stalled-chains-recover-themselves)
3. [Stop a runaway chain from the Chain Monitor](#stop-a-runaway-chain-from-the-chain-monitor)
4. [Chain steps can retry themselves](#chain-steps-can-retry-themselves)
5. [One run at a time: deduplication keys](#one-run-at-a-time-deduplication-keys)
6. [Know why a chain ended: Failure Category and guaranteed final log entries](#know-why-a-chain-ended-failure-category-and-guaranteed-final-log-entries)
7. [One owner per chain run: fencing and terminal-state integrity](#one-owner-per-chain-run-fencing-and-terminal-state-integrity)
8. [Chain Monitor: faster lists, aligned timelines](#chain-monitor-faster-lists-aligned-timelines)
9. [Health Check: nine checks and a new one-click fix](#health-check-nine-checks-and-a-new-one-click-fix)
10. [Trigger bypasses: case-insensitive names, honest audit trail](#trigger-bypasses-case-insensitive-names-honest-audit-trail)
11. [Data Masking Advisor: the inventory export is complete](#data-masking-advisor-the-inventory-export-is-complete)
12. [Smaller fixes](#smaller-fixes)
13. [Documentation](#documentation)
14. [Upgrading & compatibility](#upgrading--compatibility)
</details>

---

## At a glance

Ordered by impact. Find your row, read across, and follow the link for more.

| # | What's new | Who it's for | In one line |
|---|-----------|--------------|-------------|
| 1 | **[Stalled-chain recovery](#stalled-chains-recover-themselves)** | Admins · Developers | A chain that loses its background job is spotted, marked Stalled, and restarted from where it stopped |
| 2 | **[Chain abort action](#stop-a-runaway-chain-from-the-chain-monitor)** | Admins · Operations | Stop a running or stalled chain from the Chain Monitor; ships switched off until you assign the permission set |
| 3 | **[Per-step retry](#chain-steps-can-retry-themselves)** | Developers | A step opts into automatic retry with backoff (a growing pause between attempts), and the chain records Retries Exhausted when attempts run out |
| 4 | **[Deduplication keys](#one-run-at-a-time-deduplication-keys)** | Developers | A keyed chain never runs twice at once; a second start lands on the run already in flight |
| 5 | **[Failure Category & final log entries](#know-why-a-chain-ended-failure-category-and-guaranteed-final-log-entries)** | Admins · Developers | Every ended chain says why it ended, on the record and in the log |
| 6 | **[Run fencing](#one-owner-per-chain-run-fencing-and-terminal-state-integrity)** | Developers | Exactly one job owns a chain run; a stale leftover job can never corrupt a resumed or finished chain |
| 7 | **[Chain Monitor performance](#chain-monitor-faster-lists-aligned-timelines)** | Admins | The chain list loads a far lighter query, and the server caps page size at 100 |
| 8 | **[Health Check grows to nine](#health-check-nine-checks-and-a-new-one-click-fix)** | Admins | New abort-capability and watchdog checks, plus one-click watchdog scheduling |
| 9 | **[Trigger bypass integrity](#trigger-bypasses-case-insensitive-names-honest-audit-trail)** | Developers · Admins | Bypass names now match case-insensitively, and the audit trail flags a bypass that matched nothing |
| 10 | **[Masking inventory export fix](#data-masking-advisor-the-inventory-export-is-complete)** | Admins · Compliance | The regulated-field export now includes every field you actively mask |

---

## Stalled chains recover themselves

**Who it's for:** developers running async chains; admins who keep production healthy.

An async chain runs as a series of background jobs, and on rare occasions the platform loses one: the job dies without ever calling back. Before 1.6 such a chain sat in Running
forever, and nothing told you. 1.6 closes that gap in three layers.

**Detection.** A chain now moves to the new `Stalled` status instead of silently sticking. The framework writes it in two ways: when the platform refuses to schedule the chain's
next step, the chain is marked Stalled on the spot; and a new scheduled recovery job, the **Chain Watchdog** (`SCHED_ChainWatchdog`), sweeps Running chains that have shown no
activity beyond an idle threshold (default 30 minutes) and marks them Stalled, up to 50 chains per sweep. Each chain's own error handler is notified once per stall; delivery is
at-least-once, so a handler should tolerate a rare duplicate.

**Recovery.** The watchdog does more than flag. Every chain records the background job currently carrying it, and the watchdog checks that job's real state. When it can prove the
job is dead, it restarts the chain from the step where it stopped, and the run's fence key rotates so any leftover job from the dead run is locked out (see
[fencing](#one-owner-per-chain-run-fencing-and-terminal-state-integrity)). When it cannot prove the job dead, perhaps it is only slow, it marks and notifies but does not
interfere. A chain it cannot safely restart is marked Failed with a reason that tells you what happened, and its error handler is notified.

**Care in the sweep.** The watchdog checks its remaining async budget before every restart and parks the rest of a large sweep for its next run, and each chain is handled in
isolation, so one problem chain cannot abort the sweep for the others.

**You schedule it once.** A managed package cannot ship a scheduled job, so the watchdog stays dormant until you schedule it. The quickest way is one click in the
[Health Check](#health-check-nine-checks-and-a-new-one-click-fix). To set it up yourself, create a `ScheduledJob__c` record whose class is `SCHED_ChainWatchdog`, running hourly
(cron `0 0 * * * ?`); two optional attributes tune it: `StaleThresholdMinutes` (idle minutes before a chain counts as stalled, default 30) and `BatchSize` (chains inspected per
sweep, default 50). Until it is scheduled, stalls at enqueue time are still detected and marked; the periodic sweep and the automatic restart are what the watchdog adds.

## Stop a runaway chain from the Chain Monitor

**Who it's for:** operations users and admins handling incidents.

Sometimes a chain is doing the wrong thing and you want it to stop now, not after you have tracked down the cause. The Chain Monitor's detail panel gains an **Abort** action for
exactly that, fronted by a confirmation dialog.

Abort takes effect at the next step boundary: the step that is running is allowed to finish, then the chain stops instead of starting the next step. It can also stop a stalled
chain that is waiting on recovery. An aborted chain is final and cannot be resumed; relaunch it from the start if the work still needs to run. The outcome is recorded like any
other ending: status `Aborted`, failure category `Operator Abort`, an operator-abort reason in the error message, and a log entry.

The action ships switched off, so no one can stop a chain by accident:

- **Turning it on** is one step: assign the **Kern Async Chain Abort** permission set, which ships assigned to nobody, to the users who should have the action. The governing
  feature flag ships active, so the permission set is the only switch you touch.
- **Turning it off for everyone** is also one step: deactivate the **Async Chain Abort Enabled** feature-flag record. That hides the action org-wide without a deployment and
  without touching anyone's permissions.
- **When the action is unavailable**, the panel says exactly why: the chain has already ended, the capability is switched off, or you do not hold the permission.

One caveat: installing the package for All Users writes the abort permission into every profile during the install, silently enabling the action for everyone. The Health Check's
new Chain Abort Capability row warns when that has happened; remove the profile grants and rely on the permission set instead. See
[Upgrading & compatibility](#upgrading--compatibility) for the install-mode recommendation.

## Chain steps can retry themselves

**Who it's for:** developers whose steps hit transient failures: a locked row, a flaky callout, a rate limit.

By default a step gets one attempt: if it throws, the chain fails. A step can now opt into automatic retry by overriding `createRetryStrategy()` and returning a `UTIL_Retry`
strategy. The default returns null, so nothing changes for existing steps, and a step that was never written to be safe to run twice is never retried behind your back.

Build the strategy with `UTIL_Retry.exponential()` or `linear()`, and prefer the allowlisted form (`UTIL_Retry.retryOnlyOnException(...)`) so only the failures you expect are
retried and a genuine bug still fails fast. Retries are scheduled through the platform's delayed-job window, which counts in whole minutes, so any backoff above zero waits at
least a full minute.

Inside the step, two new context accessors let your code adapt per attempt: `getAttempt()` (1 on the first try) and `isFinalAttempt()`, so a step can, for example, alert someone
only when it is about to give up for good. When a chain runs out of retries it is marked Failed with failure category `Retries Exhausted`, so the record distinguishes a step that
failed once from one that used up every attempt.

For steps that call web services, `ApiStep.withRetry(maxAttempts, baseBackoffSeconds)` configures the same behaviour in one builder call, and it switches off the HTTP layer's own
retry scheduling for that step, so exactly one retry schedule exists rather than two competing ones.

Before you turn retry on, make sure the step is safe to repeat; if it writes to an outside system, pair it with a step idempotency key so a repeat is not double-counted.

## One run at a time: deduplication keys

**Who it's for:** developers whose chains must never overlap: nightly syncs, double-clickable buttons, overlapping schedules.

Give a chain a deduplication key and the framework lets only one run with that key be active at a time:

```apex
UTIL_AsyncChain.newChain('NightlyAccountSync')
	.then(new SyncAccountsStep())
	.withDeduplicationKey('nightly-account-sync')
	.execute();
```

While that run is active, a second `execute()` with the same key does not start a new chain: it returns the Id of the run already in flight, so the caller gets a handle to the
live chain rather than a duplicate. Keys compare without regard to case, and a blank key or one longer than 255 characters is rejected when you build the chain, not later at run
time. The key is released in the same update that writes the chain's end state, so a sequential re-run is always free to start; a stalled chain keeps its key until recovery
resolves it, deliberately, because releasing it on a timer would reopen the very overlap the key prevents.

This is not the same as a step idempotency key: a deduplication key stops two runs of the *chain* from overlapping, while an idempotency key makes one *step's* external side
effect safe to replay. Use both together when a chain must not overlap and also writes to an outside system.

## Know why a chain ended: Failure Category and guaranteed final log entries

**Who it's for:** admins and developers diagnosing chain failures.

A new restricted picklist on the chain execution record, `FailureCategory__c`, records why a chain left the happy path: **Step Exception** (a step failed or crashed), **Retries
Exhausted** (a step kept failing after its configured retries), **Kill Switch** (the AsyncChain feature flag stopped it), **Stalled** (recovery acted on a chain that lost its
background job), or **Operator Abort** (someone stopped it from the Chain Monitor). It stays empty on healthy chains, its help text carries the glossary, and you can filter and
report on it to separate deliberate stops from code bugs and platform hiccups.

Chain endings are also reliably visible in the logging framework now: every end state writes a log record. Normal completion logs at info level and honours your configured
logging threshold; failures, retry overflow, and failure-handler crashes log at error level and are always recorded. The entry goes out as an immediate platform event, decoupled
from the database work, so announcing the ending can never roll back the status update it announces; when the platform's publish limits are exhausted, the entry is rerouted to a
background job rather than dropped.

The chain execution record page now surfaces all of this: Failure Category, Error Message, the current background job Id, and the deduplication key appear on the packaged layout
and record page, so an investigation starts from the record itself.

## One owner per chain run: fencing and terminal-state integrity

**Who it's for:** developers who rely on chain state being trustworthy.

With recovery able to restart a chain, the framework must guarantee that a stale job from the earlier, dead run can never corrupt the resumed one. Every chain run now stamps a
unique fence key on its execution record; every background job carries the key it captured when it was queued and re-checks the record's current key before every write. If
recovery has rotated the key, the stale job logs a warning and goes silent instead of writing. Progress writes are also sparse: each transition writes only the fields it owns, so
one actor can no longer overwrite another's.

Endings stick, too. A committed abort or completion can never be overwritten or resurrected: in-flight work re-reads the fresh record before any terminal write, recovery refuses
an aborted record, and the watchdog never treats a finished chain as stalled. A record whose fields disagree about whether it ended (an end timestamp alongside a non-terminal
status) is treated as ended everywhere, including a neutral badge in the Chain Monitor's detail header, so monitoring data stays truthful even in rare race conditions.

The fence is upgrade-safe: chains in flight while you upgrade from 1.5 pass the check and complete normally. The fence key and current job Id are visible read-only on the record
page for diagnostics.

## Chain Monitor: faster lists, aligned timelines

**Who it's for:** admins watching chains run.

The Chain Monitor's list view now queries exactly the fields the list shows, instead of hauling every chain's full context and step log (two long-text fields of up to 131 KB
each) plus a 32 KB error message per row. Lists load faster and stay fast as chain volume grows; the detail view still loads everything. The server also caps the page size a
client may request at 100, so the list endpoint can no longer be used to pull the entire chain-execution table in one call.

The step timeline now counts only the chain's real steps, so its numbering always matches the Total Steps and Completed Steps fields.

## Health Check: nine checks and a new one-click fix

**Who it's for:** admins configuring or auditing an org.

The Health Check on the Kern app's Home tab grows from seven to nine checks:

- **Chain Abort Capability** reports whether the [abort action](#stop-a-runaway-chain-from-the-chain-monitor) is usable and safely scoped. It warns while the feature flag is
  deactivated, while no user holds the Kern Async Chain Abort permission set, or while any profile beyond System Administrator holds the abort permission (the footprint of an
  Install for All Users), and each warning says how to fix it. The check looks at the whole org, not the viewing user, so a correctly configured org never warns just because the
  viewer is not a grantee.
- **Chain Watchdog** warns when no [stalled-chain recovery job](#stalled-chains-recover-themselves) is scheduled, and fixes it for you: the **Schedule** button proposes the
  recommended setup (hourly, a 30-minute stale threshold, up to 50 chains per sweep) and creates the job in one click, with a customise link if you want different values first.

## Trigger bypasses: case-insensitive names, honest audit trail

**Who it's for:** developers and admins using runtime action bypasses during incidents and migrations.

Two integrity changes to `TRG_Base` action bypasses. First, bypass names now match case-insensitively, mirroring how Apex treats class names. Previously, a casing mismatch
between your `bypassAction` call and the registered class name was a silent no-op: the call recorded an audit entry, but the action kept running. That trap is gone, and it is a
behaviour change to be aware of: a bypass that never took effect because of casing starts working after this upgrade (see
[Upgrading & compatibility](#upgrading--compatibility)).

Second, when a bypass or clear names a class that matches no registered trigger action at the time of the call (a typo, or the wrong namespace form), the bypass-audit entry now
carries an `unmatchedTarget` marker in its context, so an incident review can tell whether a recorded bypass actually disabled anything. The lookup is advisory only and never
blocks: bypassing an action you are about to deploy remains a legitimate move. The most robust idiom stays the compiler-checked one:
`TRG_Base.bypassAction(MyAction.class.getName())`.

## Data Masking Advisor: the inventory export is complete

**Who it's for:** admins and compliance teams exporting the regulated-field inventory.

The Advisor's inventory export is meant to be a complete picture of your org's masking posture. It now includes any field that carries its own active masking target, even when
the Advisor's sensitivity heuristic rates that field not sensitive: a field someone deliberately masks is inventory-worthy by definition, and its row now reads as masked today.
Previously such fields were silently left out, which understated your coverage in exactly the review the export exists for. The export dialog's description of what is included
was updated to match.

## Smaller fixes

- **Logging works in sessionless contexts.** A logging call in a context with no user session, such as an Auth registration handler, an inbound email service, or some Experience
  Cloud guest pages, threw an error and took the caller down with it. Logging now succeeds in those contexts; a logging call is never the thing that crashes your code.
- **Partial-save DML keeps existing lookups.** In partial-save mode, where a failed record returns an error instead of stopping the whole save, a parent whose insert failed could
  cause the framework to blank a child record's existing lookup value while resolving relationships. The child now keeps its existing value until a real parent Id exists. This
  was silent data loss; it cannot happen any more.
- **No more blank dialogs.** After a Salesforce platform update, every packaged dialog could open completely blank: none passed the dialog title the platform now requires on
  open, and one dialog also shadowed the title property with an internal naming clash. Every packaged dialog now opens reliably, with proper accessible titles throughout, across
  the Data Masking Advisor, the Scheduled Jobs editor, the Chain Monitor, and the Health Check.
- **The test-data builder handles Integer fields.** Building or mocking an SObject whose required fields include a standard Integer-typed field (for example
  `ApexClass.LengthWithoutComments`) failed with an assignment error, a defect present since 1.0. The builder now generates genuine Integer values sized to the field, and a new
  overridable default, `getIntegerDefaultValue`, lets you customise them.

## Documentation

**Who it's for:** everyone who reads the guides, and any AI coding assistant you point at KernDX.

- **Feature-flag strategies: permission sets match too.** The guides and the packaged help text implied the Permission Set Group strategy matched only permission set groups. In
  fact the target is matched by name against a user's direct permission set assignments, so it resolves a plain permission set and a group alike. The docs and help text now say
  so, and they document the one real limit: a permission set that reaches a user only through membership of an assigned group does not match under its own name, so target the
  group instead. No behaviour changed.
- **Trigger framework corrections.** The recursion-control documentation was wrong in ways that could cause real design mistakes, and is now corrected everywhere, including the
  packaged help text: unchecking Allow Recursion is a live re-entry guard (the action is skipped only while an earlier run of it is still in progress), not a once-per-transaction
  switch, and post-trigger actions run after every save, not once per transaction. New sections document how flow actions behave at bulk volume and the exact-name bypass
  contract.
- **Calling your own org from a background job.** The Web Services Guide now warns prominently that `API_CallCurrentOrg` only works from a live user session; a background job (a
  queueable, a scheduled job, or a chain step) gets a deterministic authentication failure that retry cannot heal, and the guide spells out the Named Credential alternative.
- **A docs map for AI coding agents.** The docs site now serves [llms.txt](https://docs.jvb-consulting.io/llms.txt), a machine-readable summary of KernDX and its code-generation
  rules, so coding agents that follow the convention (Claude, Cursor, Copilot, Gemini) discover the framework's secure defaults before writing Apex or LWC.
- **A privacy policy you can cite.** The public repository now ships PRIVACY.md: KernDX has no telemetry, licence server, analytics, or phone-home in any component; framework
  output lives as ordinary records in your org; outbound calls go only to endpoints you configure. Security reviewers get a citable answer to what data leaves the org.
- **The metrics guide is now checked by machine.** The counts the Metrics guide publishes (classes, tests, coverage figures) are validated against the source tree by a guard
  script, so a stale figure fails the build instead of quietly drifting.
- **The repository front page shows its evidence.** The public repository's README badges were rebuilt to link the claims they make: live latest-release and release-date badges,
  a labelled continuous-integration badge, and badges linking the AI-assistant support files it ships.
- **Everything above is documented on the docs site**, the generated API reference was regenerated for the new async surface, and the site's recordings and screenshots were
  re-captured at the 1.6 user interface.

## Upgrading & compatibility

1.6 is a **backward-compatible** release. Upgrading from 1.5 is the standard package upgrade with no migration steps, and chains in flight during the upgrade complete normally.
The platform baseline is unchanged (Summer '26, API 67.0).

**The global Apex surface is purely additive.** No existing global member is removed or changed in signature. The additions:

- `SCHED_ChainWatchdog`, the stalled-chain recovery job (new global class).
- On `UTIL_AsyncChain`: `ChainStep.createRetryStrategy()` (virtual, defaults to null so existing steps are unchanged), `ChainContext.getAttempt()`,
  `ChainContext.isFinalAttempt()`, `ChainBuilder.withDeduplicationKey(String)`, and `ApiStep.withRetry(Integer, Integer)`.
- `UTIL_SObjectBuilderDefaultProvider.getIntegerDefaultValue(...)` (virtual, overridable).

**The metadata surface is additive.** Four new fields on `AsyncChainExecution__c` (`FailureCategory__c`, `ActiveDeduplicationKey__c`, `CurrentJobId__c`, `RunKey__c`), the new
**AbortAsyncChain** custom permission, the new **Kern Async Chain Abort** permission set (ships assigned to nobody), two new feature-flag configuration records for the abort
capability, and 29 new Custom Labels with none removed or renamed. The packaged chain-execution layout and record page surface the new fields, and a handful of existing fields
gained clearer descriptions and help text. Nothing is removed.

**Behaviour changes to note on upgrade** (deliberate, reviewed):

- **Trigger action bypasses match case-insensitively.** A `bypassAction`, `isActionBypassed`, or `clearActionBypass` call whose casing did not exactly match the registered class
  name previously did nothing, while still recording an audit entry. It now takes effect. If such an inert call exists anywhere in your code base, the bypass starts working after
  this upgrade; search for bypass calls and confirm each one is intended.
- **Chains that lose their background job now go `Stalled`.** Previously they sat in Running indefinitely. `Stalled` is a new written status value your reports and filters may
  want to include, and once you schedule the watchdog, provably dead chains are restarted automatically.
- **Every chain ending now writes a log entry.** Completions log at info level, honouring your logging threshold; failures log at error level and are always recorded. Expect
  chain outcomes to appear in the Log Console.
- **The Chain Monitor list endpoint returns a lighter field set and caps page size at 100.** The detail view is unchanged.
- **Partial-save DML no longer blanks existing lookups** when a parent insert fails. This corrects silent data loss; nothing to do unless something relied on the old, defective
  clearing.

**Choose Install for Admins Only when installing or upgrading.** Installing for All Users writes the new abort custom permission into every profile, silently enabling the Chain
Monitor's abort action for everyone; the Health Check warns if that has happened, and the [Installation](../docs/Installation.md) guide now recommends the admins-only mode up front.

**Two optional post-install steps activate the new operational capabilities:** schedule the Chain Watchdog (one click in the Health Check) and assign the Kern Async Chain Abort
permission set to your operations users. Neither is required for the upgrade itself; until you do, stalled chains are detected and marked but not automatically restarted, and the
abort action stays hidden.

Everything in the [Kern 1.5 Release Notes](./Release%20Notes%20-%20Kern%201.5.md) and earlier still applies; 1.6 changes only what is on this page.
