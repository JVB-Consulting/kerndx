# Changelog

> **Audience:** subscribers. Each entry describes a publicly-tagged
> release. **Evaluating an upgrade? Start with the Release Notes for the
> version you're moving to** — e.g.
> [Kern 1.1](release-notes/Release%20Notes%20-%20Kern%201.1.md) (what's new
> since 1.0, grouped by capability with upgrade notes). The
> [Kern 1.0 notes](release-notes/Release%20Notes%20-%20Kern%201.0.md) remain
> the full feature reference. This file is the sequential per-release log;
> pair it with the Release Notes for narrative context.

All notable changes to KernDX are recorded here. The format is based on [Keep a Changelog](https://keepachangelog.com/), and KernDX adheres to [Semantic Versioning](https://semver.org/) within each major release line.

---

## [1.8.0-11] — 2026-10-12

**Subscriber package version id:** `04tfj000000cIDdAAM`

The Winter '27 release. 1.8 moves KernDX to Salesforce API 68.0 and makes the framework's second attempts safe: a failed outbound call is sent again only when a second send cannot make the other system act twice, a stalled chain runs a step again only when that is safe, and a save that another transaction briefly blocks can be tried again instead of failing. Around that, any number of scheduled jobs share a few of the org's scheduled-job slots through a job runner, API issues and log entries are private on a new install, support users run many failed calls again from the API Issues list in one go, and one tracking ID brings back everything an action did, the chains it launched included.

### Added

- **A job runner.** Any number of your scheduled jobs share one to twelve of the org's 100 scheduled-job slots and run as often as every five minutes. Set a job's Execution Mode to Job runner and activate the runner from Health Check, where three new checks watch it. The new Kern Job Runner Management permission set, assigned to nobody, lets a user manage it; `SCHED_JobRunner` is the scheduled job behind it.
- **Retry Selected on the API Issues list.** Select issues and run their failed calls again in one background job; each request is sent once, and an issue the external system may have acted on is left open. The new `FLOW_RetryApiIssues` action does the same from a flow or Apex. Retry and Retry Selected need the new Retry API Issue permission, granted by the new Kern API Issue Resolver set (assigned to nobody) and by Kern Administrator; Retry Selected also needs the Run Flows user permission.
- **Safe outbound retries.** A failed call is sent again only when the failure can pass and a second send cannot make the other system act twice: a 408, 425, 429 or 503 is retried for any request, and a 500, 502, 504 or no response only when the request is safe to repeat (a GET, PUT or DELETE, or a call with an idempotency key, a key the other system uses to spot a repeat). Override `getRetryableStatusCodes()` or `getRetryableExceptionTypes()` on `API_Outbound` to widen that, throw `UTIL_Exceptions.PermanentFailureException` or `RequestRefusedException` to refuse a retry, and a new External System May Have Acted box on the API issue says when to check with the other system before pressing Retry.
- **The whole action in one view.** Every chain run has a tracking ID of its own, and every log entry also carries the root correlation ID of the action that started it, so one Log Console search for an action's ID brings back its entries and those of every chain it launched. `LOG_Builder.rootCorrelationId` answers the action's ID in Apex, and a step or completion handler may now launch one chain of its own, up to five deep.
- **Who wrote each entry.** Every log entry records its origin (Framework, Apex, Flow or Component) and the class, Flow or component that wrote it, in two new fields you can report on; the Log Console filters and sorts on them, and the Log Flow Event action gains an optional Flow Name input.
- **A selector caches its reads.** Override `cacheScope()` on `SEL_Base` and a read repeated in a transaction queries once; `withCache(scope, ttlSeconds)` and `withoutCache()` on `QRY_Builder.Builder` change it for one read. Every write through `DML_Builder` empties the in-memory cache.
- **Retry on a row lock, and refusals you expect.** `DML_Builder.withRetryOnLock()` tries a commit once more when another transaction holds a row, or up to five extra attempts with `withRetryOnLock(retries)`, and `expectRefusal(StatusCode)` logs a refusal you handle at WARN instead of ERROR when the commit allows partial success. Both travel with `.async()`.
- **Private API issues and log entries.** On a new install both objects ship with a Private sharing default, and out of the box only a holder of the new Delete API Records permission (in Kern Administrator) can delete an API call or an API issue, from a record page, a flow, your own Apex or the scheduled purge. An upgrade keeps your org's sharing default.
- **Scripted query answers and saved test users.** `TST_Mock.registerNext(...)` gives each query on an object its own answer, in order, and `TST_Factory.insertUser(...)` and `insertUsers(...)` save users inside the factory's own guard, so a test saves ordinary records before or after them without the platform's mixed-DML error.
- **Batch failure logging.** A batch failure the job's own code cannot catch, such as a governor limit, now leaves an ERROR entry, for the framework's jobs and for any batch class of yours that implements `Database.RaisesPlatformEvents`. A batch size that leaves a short run at the end of every chunk writes one WARN entry naming the sizes that fit.
- **An outbound call always gets an answer.** `send()` never returns null (a status of 0 means no response came back), a credential header set by hand is stored redacted and never replayed, the API Test Harness shows credential headers redacted, and calls refused before they left your org get their own Aborted list view on API Calls.
- **Log Console paging and literal search.** Numbered pages of 25, 50 or 100 entries, a body search that looks for exactly what you typed, a layout that keeps working beside the detail panel at 1280 pixels and below, and a Show the whole action view with a banner that lists the action's chains.
- **Chain Monitor timing.** A manual retry is marked on the step timeline and in a new Last Manual Retry At field, a running chain sorts by how long it has run through a new Elapsed (ms) field, and steps that never ran say "Did not run".
- **Five cursor limits and a sorted join.** `UTIL_Limits` gains the five Apex cursor limit checks, and `UTIL_String.joinSorted(Set<String>, String)` joins a set in sorted order so a message or log line reads the same every time.
- **Accessibility improvements.** Every copy button in the Log Console drawer and the Chain Monitor says what it copies, the drawer's timeline uses standard icons with spoken names, the DEBUG level filter shows clearly when it is pressed, and more of the screens' text comes from Custom Labels.
- **Documentation.** A new Fast Start for scheduled jobs and the job runner, a Set Up Your Computer page and seventeen Fast Starts whose commands run as printed in Command Prompt and on a Mac, a "Choosing a Batch Size" section and a rewritten "Caching Queries" section, a recipe to seed a sandbox from anonymous Apex, and an optional section on running the framework's Apex tests on your own computer with aer.

### Fixed

- The CI workflows the pipeline writes no longer let a branch name or a pull-request title run as code in the job or ping a whole Slack channel, and every action is pinned to an exact commit. Workflows an earlier version wrote keep the hole until written again from the new templates (see Changed).
- A failure in your own handler code no longer leaves a call at Retry with no retry time, where nothing ever picked it up: the call ends Failed with one issue, and a call made through a handler records one issue instead of two.
- A batch size configured in an `AsynchronousJobSetting__mdt` record named after your handler class now applies; before, the framework looked it up under an internal name that could never match, so every job ran 200 items at a time unless a size was passed in code.
- A wildcard masking target no longer rewrites a chain run's internal keys, which left about one run in several thousand stuck as Running with no steps done.
- A chain run going for more than about 115 days can now end, because its duration no longer overflows the field, and a queueable job launched with no job options no longer loses its remaining work after its first run.
- Retry on an API issue for a call your org received now replays that call in your org, and inbound request headers are found whatever case the caller sends them in, so a lower-case `idempotency-key` from a Node or HTTP/2 client is honoured.
- A key you give `withIdempotencyKey()` is now sent when a handler makes the call, `withCircuitBreaker(name)` uses the breaker you name, the two exception filters of a retry strategy now see the caught exception, and a half-open circuit (one letting a few trial requests through after its cool-off) recovers when its trial requests end with no result.
- One failing call no longer costs the others in its batch, and every line of a web-service call's log names the right service.
- The Kern Administrator set grants the Apex classes behind Health Check and the API Test Harness, so a user who is not a System Administrator can open them.
- A new Kern Component Access permission set grants the thirteen classes behind the package's components and everyday Flow actions.
- Logging: an entry logged from inside an inner class keeps that frame in a namespaced org, a summary set beside an exception is written instead of dropped, logging contexts nested past ten deep no longer lose the caller's origin, and a line logged inside a web-service call that arrived with a trace header carries the call's endpoint, status code and duration.
- The Log Console's Refresh keeps up with a run or an action still going when you arrive from a link (a 1.7 known issue), a search of only brackets or quotes no longer fails the list, a body search under a source filter stays within that source, and a Flow's entries are named after the Flow wherever the console names a writer.
- A job on the job runner that is due in the minute the clocks jump forward runs that day, and a day-of-week field holding only `L` means Saturday instead of being refused.
- Mock child records built with `withoutInsertion(true)` point to their parent's mock Id, and the test user builder no longer sets every preference checkbox at random, which in some orgs failed the insert.
- A commit with nothing registered no longer hides your `onCommitWorkStarting` hook's exception behind a `NullPointerException`, and work the hook registers is rolled back when a later statement fails.
- The Flow email action no longer fails with a flow fault when sending to a Contact, Lead or User with standard activity logging selected but Save as Activity off.
- The Chain Monitor's detail panel describes the run you selected now, whatever load answered last, and leaving the monitor with its live stream on no longer raises a browser error.
- The pipeline tools run on Windows, `kerndx doctor` no longer warns about PMD's Apex module 7.27.0, and the scaffolded `code-analyzer.yml` names the flow engine's after-save rule as `SameRecordUpdate`; a file scaffolded earlier needs that key renamed by hand.

### Changed

Each change below has a row, with what to do, in the "Behaviour changes at a glance" table of the 1.8 release note.

- **`withoutSecurity()` now also bypasses record sharing.** If you relied on it keeping the calling class's sharing, use `withSystemMode()`; `toCursor()` and `toQueryLocator()` now honour `bypassSharing()`.
- **Query caching rules.** A system-mode `withCache` read that does not state its sharing is no longer cached, and a user-mode `withCache` read is now kept for the transaction, so use `withoutCache()` where you write outside `DML_Builder` and read back. Saving several cache values at once saves none when one is too large.
- **A feature flag reads its custom setting or metadata target once per transaction.** A check that follows a plain `insert` or `update` of that setting in the same transaction sees the value from before the write; write the setting through `DML_Builder`, which clears the kept rows, or move the second check to its own transaction.
- **Only the "try later" statuses retry by default** (408, 425, 429, 500, 502, 503 and 504), a 500, 502 or 504 on a POST or PATCH with no idempotency key is not sent again, a failure after a successful response is not sent again, and a call that fails in your own code reads Failed, not Retry. Add statuses in `getRetryableStatusCodes()`, exception types in `getRetryableExceptionTypes()`, and change anything that looks for Retry.
- **An open circuit makes a call with retries left wait** for the cool-off instead of ending it Aborted, and a callout that got no response counts towards opening the circuit.
- **A hand-set credential header is stored redacted and a later retry is parked.** Move the credential to a Named or External Credential.
- **Calls an earlier version left at Retry with no Next Retry are not changed by the upgrade.** Retry or resolve each, or mark them Failed with the script in the release note.
- **Retry on an API issue needs the Retry API Issue permission**, is refused with a message when the issue's service is paused or switched off, and the Resolved Date is now filled on every path that resolves an issue.
- **Your commit hooks run once per attempt when a row lock is retried**, so an override that counts, sends or writes outside the commit must be safe to run twice, and DML failures now log once, filed under `DML_Transaction.commitWork`.
- **A stalled chain runs a step again only when that is safe.** Override `isIdempotent()` on every step safe to run twice; a run that has ended stays ended (a script repairs runs an earlier version left Stalled with an end time); an API step stops retrying when the external system may have acted; and the first chain in an action no longer carries the action's ID, so match on Launched Under or the root correlation ID.
- **The typed chain status reports elapsed time the way the Chain Monitor does**, and the two new chain fields, Last Manual Retry At and Elapsed (ms), need Read on a cloned permission set or a profile.
- **A hierarchy deeper than its depth limit throws** instead of leaving the deepest records out; raise the limit with `withMaxDepth`.
- **Testing:** a handler's canned answer stands in only inside a unit test, a callout inside an Apex integration test reaches the real endpoint unless you register a mock through `API_MockFactory`, permission set assignments from one factory call save together, and a cleared mock queries the database again.
- **A batch-size record is found by your handler's name**, so rename a record named after the old internal key; a failure your code already logged now logs twice, and a batch size that does not fit its chunk writes a WARN entry.
- **Logging text:** the Log Console's body search is literal, messages from the Write Detailed Log Messages action start with `[Flow]`, and a line logged while a web-service handler is still being set up has no HTTP method.
- **Three messages that stop an outbound call before it is sent, and the Retry action's refusals, come from Custom Labels** with new wording; read the label in code or tests that matched the old text.
- **Health Check:** the Trusted Site row is gone and the check now runs eleven checks, and the Platform Cache checks' detail text is longer.
- **A job in its own mode no longer offers "Every N Minutes".** Put such a job on the job runner.
- **An inbound handler whose `handleError()` override throws answers 500**, not a 200 with an empty body; tell the owners of a calling system that treated the empty 200 as success.
- **The Flow email action refuses to log an email to a User through standard activity logging.** Use custom activity logging for Users.
- **Code scanning:** `KernTriggerMustDelegate` checks the whole trigger body, the new informational rule `KernLimitsThroughWrapper` reports a governor limit read directly, and the framework ruleset runs the Kern rules again under Code Analyzer 5.16 and later, so a gate may report findings it missed.
- **Pipeline users: write your workflows again** with `node .kerndx-pipeline/bin/kerndx upgrade`, which backs each file up first. Until you do, workflows an earlier version wrote keep the hole described under Fixed.
- **The Validation Errors component's `fieldclick` event stays with the component.** Listen for it on the `<kern-validation-errors>` tag itself.
- **The Chain Monitor's Restarted from row is gone.** The Launched under row links a restart to the run it was restarted from.

**Known issues, each tracked on the public repository.** Retry Selected on more than 10 inbound issues at once can fail some of its jobs; create an Asynchronous Job Setting record named `kern_FLOW_CallApiAsync` with a Batch Size of 10 or less, or select 10 or fewer inbound issues per retry ([#39](https://github.com/JVB-Consulting/kerndx/issues/39)). The Top sources card and the list it opens can show different counts while entries written before the upgrade age out ([#40](https://github.com/JVB-Consulting/kerndx/issues/40)). An upgraded org may keep the old duration column on the chain execution list view, highlights panel and search results ([#41](https://github.com/JVB-Consulting/kerndx/issues/41)). The manual-retry line can be left off a very long chain; Last Manual Retry At is written either way ([#42](https://github.com/JVB-Consulting/kerndx/issues/42)). Two job-runner checks at the same instant, on an org whose runner was never activated, can stop the runner; delete the extra `JobRunner` row in the Schedule Setting custom setting, or activate the runner through Health Check, which avoids it ([#43](https://github.com/JVB-Consulting/kerndx/issues/43)). A job running as its own scheduled job, written in one time zone and activated in another that is half an hour apart, can fire at the wrong time ([#44](https://github.com/JVB-Consulting/kerndx/issues/44)). A chain that stalls and is never aborted is never purged ([#45](https://github.com/JVB-Consulting/kerndx/issues/45)).

Backward-compatible: the global Apex surface is purely additive (twenty-seven new members, twenty-five on eleven existing classes and two new classes, nothing removed or changed in signature), and the metadata surface is additive too, with nineteen new fields and nothing removed or renamed. Six short steps in Setup bring an upgraded org level with a fresh install, because page layouts, list view columns, search layouts and sharing defaults belong to your org once installed and an upgrade never overwrites them. Choose Install for Admins Only, as in 1.7. For the full tour and every upgrade note, see [Kern 1.8 Release Notes](https://github.com/JVB-Consulting/kerndx/blob/main/release-notes/Release%20Notes%20-%20Kern%201.8.md).

## [1.7.0-13] — 2026-08-18

**Subscriber package version id:** `04tfj000000ScTlAAK`

The operations release. 1.6 taught async chains to look after themselves; 1.7 hands the controls to the people watching them. An operator can re-run a failed chain from the step that failed, restart one from the beginning, sweep the stalled ones, and stop all chain processing org-wide, from the Chain Monitor and without a deployment. On the diagnosis side, the Log Console works out which errors are repeating on its own, with no code changes and no configuration.

### Added

- **Retry from the failed step.** Re-run a failed chain from the step that failed, on the same record, keeping its history. Offered only where the chain author declared that step re-runnable by overriding `isIdempotent()`.
- **Restart from the beginning.** Re-run a failed or aborted chain from step 1 as a fresh run with its own tracking ID, leaving the original record untouched for audit and linked to the new one. Offered only where the chain author called `allowRestart()`.
- **Clear stalled chains on demand.** Run the recovery sweep immediately over up to 40 stalled chains, with a counted result: how many were checked, re-driven, marked failed, and still waiting.
- **Suspend and resume chain processing.** One org-wide switch stops and restarts all chain processing during an incident, backed by the new `AsyncChainRuntimeSwitch__c` hierarchy custom setting. Abort deliberately stays available while processing is suspended.
- **Live activity stream.** Watch the selected chain's log entries arrive in the Chain Monitor's detail panel, seeded with the most recent 20 entries and holding 100 rows, with a visible disconnected state rather than a stale list.
- **Three new permission sets**, all assigned to nobody: Kern Async Chain Redrive, Kern Async Chain Kill Switch, and Kern Async Chain Monitor Read Only. Re-drive rights and stop-everything rights are deliberately separate grants, and the packaged Administrator set carries neither.
- **Problem grouping in the Log Console.** Problem summary collapses repeating errors that share an exception type, class and method, and level into one "this error, N times" row, with no code changes and no configuration. Three optional `LogSetting__c` settings tune it (occurrence floor, level scope, and an off switch), a status bar always states what the list is and is not showing, and the drawer offers a copyable snippet for naming a problem permanently.
- **Errors from Lightning components join problem grouping**, because a failure caught in a component now records the error's type alongside its message and the component it came from.
- **Paged reads at any table size.** `QRY_Builder.getPage` serves a page whichever way the platform allows for that query, so reads past 100,000 matching rows return a page instead of failing.
- **Permanent failures.** A step can return `failedPermanently(...)` so the chain fails on that attempt without spending retry budget on a deterministic failure, and the flag survives to later steps.
- **Retry only the statuses you list.** `ApiStep.retryOn(Set<Integer>)` restricts chain-level retry to specific HTTP statuses. A statusless failure stays retryable under every value.
- **Exception-aware finality.** `ChainContext.isFinalAttempt(Exception)` answers filter-aware finality from inside `work()`, so a last-chance side effect fires on the attempt that really is the last one.
- **Literal search.** `QRY_Condition.FieldCondition.containsLiteral(String)` treats `%`, `_` and `\` as ordinary characters, so a search box matches exactly what someone typed. `contains()` is unchanged.
- **A logging identity for a separate run.** `LOG_Builder.serializeContext(String)` builds a minimal logging context for a supplied correlation ID, so a restarted chain starts a clean trace.
- **Transport-failure mocking.** `API_MockFactory.forService(...).withTransportFailure()` simulates a call that never reaches the server.
- **Accessibility improvements across the packaged screens.** Unavailable Chain Monitor actions state their reason in visible text and to screen readers, the action toolbar is a named group, Escape closes the Log Console drawer and returns focus to the list, Kern Home has a correct heading outline with distinct button names and wrapping tool titles, the Health Check's passing-checks list is labelled, and small-text contrast meets the 4.5:1 floor.
- **Four proven composition patterns** in the Async Processing Guide: commit-coupled outbound delivery, a two-chain approval hand-off, a circuit breaker around a struggling integration, and a recurring scheduled chain.

### Fixed

- Scheduled clean-up no longer deletes live chains: the Health Check's one-click retention fix ages chain records on their completion timestamp instead of their created date, which previously purged Stalled and even Running chains at 90 days.
- A chain step wrapping one of your own web-service handlers no longer dies at the background hop with "Handler class not found".
- Recovery reaches a chain that dies before its first step finishes, and single-step chains, because the background job ID is stamped when the chain starts.
- Logging from a post-trigger action inside platform-event processing no longer throws, and a failing post-action no longer leaves the rest of the transaction unable to flush its log entries.
- Grouping keys are tidied where the stored key is built, so a key with stray edge whitespace or one longer than the field allows no longer fails to group silently.
- Grouped logging survives a database-level clash: only the affected row is involved, the rest of the batch still lands, and one warning entry records what happened.
- A count query honours `bypassSharing()`, which was previously accepted and ignored, so a bypassed count can no longer return fewer rows than the query it was sizing.
- A wildcard masking target no longer rewrites unique keys and external IDs, so an identifier field can no longer be redacted into a duplicate-value failure.
- The Log Console keeps working at volume: it declines to group above roughly 35,000 matching entries in the window and says so, the counts above Individual entries decline the per-level breakdown above their own ceiling while still reporting the exact total, a capped list says it was capped, a deep link loads once instead of twice, a failed read reports an error rather than "No logs match these filters", and the Log Number column sorts server-side.
- Opening a Scheduled Job record page no longer throws a component error on every view.
- An error caught by a component's error boundary logs its own message rather than a bare phrase.
- The chain list distinguishes "no chains at all" from "none in this status".
- Generated mock record IDs no longer collide at realistic build volumes, and the test factory no longer silently replaces a default-value provider you registered.
- `isFinalAttempt()` reads `true` in an `onError` handler for every failure that was final, including a retry denied by an exception filter while budget remained.
- A chain that fails with an oversized context stores no context rather than unreadable truncated data, a first-step delay no longer discards custom async options, and every Chain Monitor action guards against a double click.

### Changed

- **The org-wide chain switch moves to a custom setting.** Chain processing is driven by `AsyncChainRuntimeSwitch__c.ChainsEnabled__c` through a new strategy on the existing `AsyncChain` feature flag. An org that never edited that flag record is unaffected. An org that edited its *result when nothing matches* or *enabled by default* values can change behaviour on upgrade, in one direction or the other. Check that record before upgrading.
- **Asynchronous DML honours your access-mode and sharing choices end-to-end.** A `DML_Builder` chain ending in `.async()` no longer loses the access mode you set: a system-mode async write runs with record sharing enforced by default, and `.bypassSharing()` is the explicit opt-out carried across to the job. The scheduled record purge is unaffected.
- **Reusing a correlation ID across chains raises `UTIL_Exceptions.IllegalStateException`** where it previously surfaced a `DmlException`, so code catching `DmlException` around a chain launch for this case no longer catches it.
- **Paged queries can return a null `QueryPage.cursor`**, and a page size outside 1 to 2,000 is now rejected at the call with an `IllegalArgumentException`.
- **Wildcard masking targets narrow**, skipping unique and external-ID fields; add an explicit target to keep masking such a field.
- **An unhandled stall logs at error level** rather than warning. Orgs that page on error-level entries should review their filters.
- **The logging framework's background persistence runs with the sharing of the code that logged it**, rather than defaulting to full system access. A tightening, so nothing gains access it did not have.
- **Subclasses of `UTIL_SObjectBuilderDefaultProvider` must call `super.defineSObjectOptionalFields`** to keep User records buildable; an override that omitted it previously inherited the behaviour by accident.
- **Three Health Check rows are named differently.** "Organisation Cache" is now "Org Cache", matching Setup's own name; "Masking configuration" and "Masking coverage (custom objects)" changed capitalisation only, to "Masking Configuration" and "Masking Coverage (Custom Objects)". Update anything that matches check names exactly.
- **A step class must declare no constructor of its own** to be rebuilt when a chain resumes; the refusal names the rule instead of failing obscurely.
- The Chain Monitor's "View logs" link opens the chain's own run window instead of a flat 30-day view, operator actions sit on their own row, and the Timing card reports a run that stopped short honestly.
- Some released Custom Label wording was corrected, with placeholder counts unchanged; existing translations keep working but show the older wording until re-translated.

**Installing 1.6.0-3 fresh can fail.** To keep a standard button off the chain-execution page, the 1.6.0-3 layout named that button (`SmartFillEnrich`) in order to exclude it, and an org without the button rejects a layout that names it at all. 1.7 no longer names it, so install 1.7 or later. Orgs already running 1.6.0-3 upgrade normally.

Backward-compatible: the global Apex surface is purely additive (ten new members across four existing classes, nothing removed or changed in signature). For the full tour and every upgrade note, see [Kern 1.7 Release Notes](https://github.com/JVB-Consulting/kerndx/blob/main/release-notes/Release%20Notes%20-%20Kern%201.7.md).

## [1.6.0-3] — 2026-07-26

**Subscriber package version id:** `04tfj000000OKK9AAO`

The async release: chains now look after themselves. A chain that loses its background job is detected instead of sitting in Running forever, recovery restarts the ones that are provably safe to resume, and the people you nominate can stop a runaway chain from the Chain Monitor.

### Added

- **Stalled-chain detection and recovery.** A chain that loses its background job is marked `Stalled`, and the new Chain Watchdog scheduled job restarts a provably dead chain from the step where it stopped. The Health Check schedules the watchdog in one click. Run fencing guarantees a stale leftover job can never corrupt the resumed run.
- **Chain abort.** Operations users you nominate can abort a running or stalled chain from the Chain Monitor. Ships switched off: gated by a permission set assigned to nobody, plus an org-wide feature-flag off-switch.
- **Per-step retry.** A step can opt into automatic retry with backoff (a growing pause between attempts); the chain records `Retries Exhausted` when attempts run out.
- **Deduplication keys.** A keyed chain never runs twice at once; a second start lands on the run already in flight.
- **Failure Category.** Every chain that leaves the happy path records why (empty on healthy chains), and every ending writes a log entry.
- **Health Check grows to nine checks**, including a warning when an Install for All Users has silently granted the abort permission to every profile. Choose Install for Admins Only.

### Fixed

- Logging no longer throws in sessionless contexts such as login handlers and inbound email services.
- Partial-save DML no longer blanks a child's existing lookup when a parent insert fails.
- The Data Masking Advisor's inventory export now includes every actively masked field.
- All packaged dialogs render reliably after a platform update began requiring dialog titles.
- The test-data builder generates genuine Integer defaults.

### Changed

- The Chain Monitor list loads a far lighter query and caps page size at 100.
- Trigger action bypass names now match case-insensitively, so a bypass that never took effect because of a casing mismatch starts working. This is the one deliberate behaviour change.

Backward-compatible: the global Apex surface is purely additive (one new class and six new methods, nothing removed or changed in signature). For the full tour, see [Kern 1.6 Release Notes](https://github.com/JVB-Consulting/kerndx/blob/main/release-notes/Release%20Notes%20-%20Kern%201.6.md).

## [1.5.0-1] — 2026-07-13

**Subscriber package version id:** `04tfj000000MutBAAS`

A single-fix release for the Streaming Monitor. Its Change Data Capture list showed only custom-object change events; the standard ones, such as `AccountChangeEvent`, were missing because discovery looked for them under a publisher that no record on the platform uses. A single lookup now returns both, so the standard channels are back in the list, and every channel is labelled `Standard: <name>` or `Custom: <name>` (from two new Custom Labels) so you can tell them apart at a glance. KernDX publishes each release as a new minor version, so this standalone fix ships as 1.5 rather than a patch, and it carries nothing else. Backward-compatible: the Apex API and metadata surface are purely additive (two new Custom Labels, nothing removed or changed), so upgrading from 1.4 is the standard package upgrade with no migration steps. For the full context, see [Kern 1.5 Release Notes](https://github.com/JVB-Consulting/kerndx/blob/main/release-notes/Release%20Notes%20-%20Kern%201.5.md).

## [1.4.0-2] — 2026-07-12

**Subscriber package version id:** `04tfj000000MlrVAAS`

A quality release with two headlines: the framework's user interface is now translatable end to end (every display string across 28 component bundles moved to Custom Labels, 359 new labels, English rendering unchanged), and a systematic correctness sweep of every Lightning component fixed the defects it found, led by an async-chain fix where a continue-on-error chain could be marked Failed once its accumulated step messages grew long. Also in: Chain Monitor live refresh now works in unmanaged and renamed-namespace deploys, record forms report failed saves instead of looking saved, silent failures (clipboard copies, retention updates, job saves) now surface, the Streaming Monitor timeline is native SVG with no chart-library dependency, and lookups survive missing configuration. Backward-compatible: the Apex API and metadata surface are purely additive; a short list of deliberate behaviour changes is in the release notes. For the full tour, see [Kern 1.4 Release Notes](https://github.com/JVB-Consulting/kerndx/blob/main/release-notes/Release%20Notes%20-%20Kern%201.4.md).

## [1.3.0-3] — 2026-07-03

**Subscriber package version id:** `04tfj000000M0ZFAA0`

A purely additive release headlined by the Log Console: a dedicated screen for browsing past log entries, with recurring problems grouped by occurrence count, severity filtering, search, and a detail drawer that walks one operation end to end across triggers, jobs, and callouts, cross-linked both ways with the Chain Monitor. Alongside it: aliased multi-aggregate selections and aggregate ordering in the query builder (several aggregates in one query, read back by name), a contains filter and single-argument condition constructors, picklists on the Flow invocable-action inputs, a redesigned Org Limits view, and LWC logging that now persists the client's own error stack and context. Everything is additive, so upgrading from 1.2 is the standard package upgrade with no migration steps. For the full capability tour, see [Kern 1.3 Release Notes](https://github.com/JVB-Consulting/kerndx/blob/main/release-notes/Release%20Notes%20-%20Kern%201.3.md).

## [1.2.0-1] — 2026-06-27

**Subscriber package version id:** `04tfj000000LXH7AAO`

A purely additive release that hardens the async-chain framework and adds three smaller quick wins. Headlines: per-step idempotency keys so a chain step is safe to re-run without acting twice on an outbound call, a typed `getChainStatus()` accessor that returns a `ChainStatus` value object, and a first-step delay of up to ten minutes. Alongside those: deterministic ordering for trigger actions that share an order value, a record-id input on the Flow logging action, and fluent geolocation distance filtering in the query builder. Every change adds new surface, so upgrading from 1.1 is the standard package upgrade with no migration steps. For the full capability tour, see [Kern 1.2 Release Notes](https://github.com/JVB-Consulting/kerndx/blob/main/release-notes/Release%20Notes%20-%20Kern%201.2.md).

## [1.1.0-11] — 2026-06-15

**Subscriber package version id:** `04tfj000000KesXAAS`

First release of the Kern 1.1 line. Headlines: the Data Masking Advisor (a console to review, test, and deploy masking coverage), stronger payment-card masking via the new Mask Payment Card Numbers rule (it takes over from the original credit-card rule on framework objects automatically — see the upgrade notes), Change Data Capture and post-trigger actions in the trigger framework, a hardened Streaming Event Monitor, typed date functions in the query builder, Summer '26 (API 67.0) platform support, and a hosted documentation site. For the full capability tour with upgrade notes, see [Release Notes — Kern 1.1](https://github.com/JVB-Consulting/kerndx/blob/main/release-notes/Release%20Notes%20-%20Kern%201.1.md).

## [1.0.0-121] — 2026-05-22 (first public release)

**Subscriber package version id:** `04tfj000000JN0vAAG`

Initial publicly-tagged release. Every framework module, every Strategic Guide, every Fast Start, the full API reference, and the pipeline distribution flavor ship at this version. For a capability-by-capability tour of what's in v1.0, see [Release Notes — Kern 1.0](https://github.com/JVB-Consulting/kerndx/blob/main/release-notes/Release%20Notes%20-%20Kern%201.0.md).

[1.0.0-121]: https://github.com/JVB-Consulting/kerndx/tree/v1.0.0-121
[1.1.0-11]: https://github.com/JVB-Consulting/kerndx/tree/v1.1.0-11
[1.2.0-1]: https://github.com/JVB-Consulting/kerndx/tree/v1.2.0-1
[1.3.0-3]: https://github.com/JVB-Consulting/kerndx/tree/v1.3.0-3
[1.4.0-2]: https://github.com/JVB-Consulting/kerndx/tree/v1.4.0-2
[1.5.0-1]: https://github.com/JVB-Consulting/kerndx/tree/v1.5.0-1
[1.6.0-2]: https://github.com/JVB-Consulting/kerndx/tree/v1.6.0-2
[1.6.0-3]: https://github.com/JVB-Consulting/kerndx/tree/v1.6.0-3
[1.7.0-7]: https://github.com/JVB-Consulting/kerndx/tree/v1.7.0-7
[1.7.0-8]: https://github.com/JVB-Consulting/kerndx/tree/v1.7.0-8
[1.7.0-9]: https://github.com/JVB-Consulting/kerndx/tree/v1.7.0-9
[1.7.0-10]: https://github.com/JVB-Consulting/kerndx/tree/v1.7.0-10
[1.7.0-11]: https://github.com/JVB-Consulting/kerndx/tree/v1.7.0-11
[1.7.0-12]: https://github.com/JVB-Consulting/kerndx/tree/v1.7.0-12
[1.7.0-13]: https://github.com/JVB-Consulting/kerndx/tree/v1.7.0-13
[1.8.0-11]: https://github.com/JVB-Consulting/kerndx/tree/v1.8.0-11
