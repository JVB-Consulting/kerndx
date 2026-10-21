# Kern 1.8 Release Notes

**Builds on:** [Kern 1.7 Release Notes](./Release%20Notes%20-%20Kern%201.7.md), [Kern 1.6 Release Notes](./Release%20Notes%20-%20Kern%201.6.md), [Kern 1.5 Release
Notes](./Release%20Notes%20-%20Kern%201.5.md), [Kern 1.4 Release Notes](./Release%20Notes%20-%20Kern%201.4.md), [Kern 1.3 Release Notes](./Release%20Notes%20-%20Kern%201.3.md),
[Kern 1.2 Release Notes](./Release%20Notes%20-%20Kern%201.2.md), [Kern 1.1 Release Notes](./Release%20Notes%20-%20Kern%201.1.md), and the
[Kern 1.0 Feature Reference](./Release%20Notes%20-%20Kern%201.0.md), which together remain the full reference for everything 1.8 carries forward.
**Platform:** Salesforce API 68.0 (Winter '27), up from API 67.0 (Summer '26) in 1.7 · [What Winter '27 changes](#ready-for-winter-27)
· **Namespace:** `kern` (rebrandable via [Installation](../docs/Installation.md))
**Release status:** released. Kern 1.8.0-11 is the production-installable 1.8 line.

> **What 1.8 is.** 1.8 moves KernDX to Salesforce Winter '27 (API 68.0) and brings 147 improvements
> since 1.7, split by area in the table below. They include 51 behaviour changes, listed under
> [Upgrading & compatibility](#upgrading--compatibility), and 43 smaller fixes. The release also adds 27 global Apex members and
> 19 fields. It changes one security default: on a new install, API issues and log entries are private. It also closes a security
> hole in the CI workflows the pipeline writes, which you close in your own repository by writing the workflows again from the
> updated templates (one command, `node .kerndx-pipeline/bin/kerndx upgrade`).
>
> | Area | Improvements |
> |---|---|
> | Outbound and inbound calls, API issues | 28 |
> | Documentation | 16 |
> | Logging and the Log Console | 16 |
> | Async chains and the Chain Monitor | 15 |
> | Queries and caching | 13 |
> | Consoles, masking, Flow and other smaller fixes | 13 |
> | Code scanning and the pipeline | 11 |
> | Scheduled jobs and the job runner | 8 |
> | Following one action across chains | 7 |
> | Saving data | 5 |
> | Batch and queueable jobs | 5 |
> | Testing | 5 |
> | Utilities, platform and release testing | 5 |
>
> **The headline changes**, each with its own section below:
>
> - **A job runner**: many scheduled jobs share one to twelve scheduled-job slots, as often as every five minutes.
> - **Private API issues and log entries**: on a new install people see only their own, and only an administrator deletes
>   call history.
> - **Pipeline users: write your workflows again**: the templates no longer let a branch name or a pull-request title run as code.
> - **Safe outbound retries**: a failed call is sent again only when the failure can pass and a second send cannot make the
>   other system act twice.
> - **Retry Selected**: support users run many failed calls again from the API Issues list in one job.
> - **The whole action in one view**: one tracking ID brings back an action's entries and those of every chain it launched.
> - **Chains that never repeat work by surprise**: a stalled step runs again only when that is safe, and a run that has ended
>   stays ended.
> - **Who wrote each entry**: every log entry records whether the framework, Apex, a Flow or a component wrote it, and which one.
> - **A selector caches its reads** with one override, so a repeated read in a transaction queries once.
> - **Retry on a row lock**: the DML builder tries a commit again when another transaction holds a row, and logs a refusal you expect below ERROR.
> - **Tests**: a test can give each query its own answer, and save users beside its ordinary records.
> - **Ready for Winter '27**: built on API 68.0, tested on the Winter '27 preview, with every Winter '27 change that touches
>   your code in one section.
>
> **Safe to upgrade, after one read.** The global Apex surface is purely additive, with no global member removed or changed in
> signature; the new members are in [New in the Apex API](#new-in-the-apex-api). The metadata surface is additive too: nineteen
> new fields, three new custom permissions, two new permission sets (assigned to nobody), one new trigger, ten new configuration
> records, one new list view, one new list action with its flow, and 183 new Custom Labels, with nothing removed or renamed. Before
> you upgrade, read the [behaviour changes at a glance](#behaviour-changes-at-a-glance): one row per change, with what to do.
> For the per-build log, see the CHANGELOG.

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [At a glance](#at-a-glance)
2. [Behaviour changes at a glance](#behaviour-changes-at-a-glance)
3. [Run many scheduled jobs from a few scheduled-job slots](#run-many-scheduled-jobs-from-a-few-scheduled-job-slots)
4. [API issues and log entries are private, and only an administrator deletes call history](#api-issues-and-log-entries-are-private-and-only-an-administrator-deletes-call-history)
5. [Follow one action across every chain it launched](#follow-one-action-across-every-chain-it-launched)
6. [An async chain never repeats a step that may already have done its work](#an-async-chain-never-repeats-a-step-that-may-already-have-done-its-work)
7. [Every log entry says who wrote it](#every-log-entry-says-who-wrote-it)
8. [The Log Console pages, searches literally and fits a narrow screen](#the-log-console-pages-searches-literally-and-fits-a-narrow-screen)
9. [The Chain Monitor marks manual retries and sorts by elapsed time](#the-chain-monitor-marks-manual-retries-and-sorts-by-elapsed-time)
10. [Saving data: retry on a row lock, expected refusals, failures that log](#saving-data-retry-on-a-row-lock-expected-refusals-failures-that-log)
11. [Queries: a selector caches its reads with one override](#queries-a-selector-caches-its-reads-with-one-override)
12. [Testing: saved users and a different answer for each query](#testing-saved-users-and-a-different-answer-for-each-query)
13. [Batch jobs: platform-reported failures and batch sizes that fit](#batch-jobs-platform-reported-failures-and-batch-sizes-that-fit)
14. [Outbound calls: an answer every time, and no stored credentials](#outbound-calls-an-answer-every-time-and-no-stored-credentials)
15. [A failed outbound call is sent again only when that is safe](#a-failed-outbound-call-is-sent-again-only-when-that-is-safe)
16. [Run many failed calls again from the API Issues list](#run-many-failed-calls-again-from-the-api-issues-list)
17. [Ready for Winter '27](#ready-for-winter-27)
18. [Changes that can affect code you have written](#changes-that-can-affect-code-you-have-written)
19. [New in the Apex API](#new-in-the-apex-api)
20. [Easier to use with assistive technology](#easier-to-use-with-assistive-technology)
21. [Smaller fixes](#smaller-fixes)
22. [How this release was tested](#how-this-release-was-tested)
23. [Documentation](#documentation)
24. [Known issues](#known-issues)
25. [Upgrading & compatibility](#upgrading--compatibility)
</details>

---

## At a glance

Ordered by impact. Find your row, read across, and follow the link for more.

| # | What's new | Who it's for | In one line |
|---|-----------|--------------|-------------|
| 1 | **[Job runner](#run-many-scheduled-jobs-from-a-few-scheduled-job-slots)** | Admins · Developers | Many scheduled jobs share one to twelve scheduled-job slots, and can run as often as every five minutes |
| 2 | **[Private API issues and log entries](#api-issues-and-log-entries-are-private-and-only-an-administrator-deletes-call-history)** | Admins · Security | On a new install people see only their own API issues and log entries, and only an administrator deletes call history |
| 3 | **[Safer pipeline workflows](#the-ci-workflows-the-pipeline-writes-no-longer-let-pull-request-text-run-as-code)** | Developers · Security | The workflows the pipeline writes no longer let a branch name or pull-request title run as code; write yours again from the new templates to get the fix |
| 4 | **[Safe outbound retries](#a-failed-outbound-call-is-sent-again-only-when-that-is-safe)** | Developers · Operations | A failed call is sent again only when the failure can pass and a second send cannot make the other system act twice |
| 5 | **[Retry Selected](#run-many-failed-calls-again-from-the-api-issues-list)** | Support · Operations | Pick API issues on the list and run their failed calls again in one background job |
| 6 | **[The whole action in one view](#follow-one-action-across-every-chain-it-launched)** | Operations · Developers | One search for an action's ID brings back its own entries and those of every chain it launched |
| 7 | **[Chains never repeat a step by surprise](#an-async-chain-never-repeats-a-step-that-may-already-have-done-its-work)** | Developers · Operations | A stalled step runs again only when that is safe, and a run that has ended stays ended |
| 8 | **[Ready for Winter '27](#ready-for-winter-27)** | Everyone | Built on API 68.0 and tested on the Winter '27 preview; every Winter '27 change that touches your code, in one place |
| 9 | **[Who wrote each entry](#every-log-entry-says-who-wrote-it)** | Admins · Developers | Every entry records its origin (Framework, Apex, Flow or Component) and the class, Flow or component that wrote it |
| 10 | **[A selector caches its reads](#queries-a-selector-caches-its-reads-with-one-override)** | Developers | A selector opts in once, and a read repeated in a transaction queries once |
| 11 | **[Retry on a row lock](#saving-data-retry-on-a-row-lock-expected-refusals-failures-that-log)** | Developers | The DML builder tries a commit again when another transaction holds a row |
| 12 | **[Log Console paging and search](#the-log-console-pages-searches-literally-and-fits-a-narrow-screen)** | Admins | Numbered pages, a search box that looks for exactly what you typed, and a layout that still fits when the entry's detail panel is open |
| 13 | **[Chain Monitor timing](#the-chain-monitor-marks-manual-retries-and-sorts-by-elapsed-time)** | Operations | Manual retries are marked, a running chain sorts by how long it has run, and steps that never ran say so |
| 14 | **[Scripted query answers and saved test users](#testing-saved-users-and-a-different-answer-for-each-query)** | Developers | A test can give each query its own answer, and save users beside its ordinary records |
| 15 | **[Batch failure logging](#batch-jobs-platform-reported-failures-and-batch-sizes-that-fit)** | Developers · Admins | A batch failure the job's own code cannot catch now leaves an ERROR entry, for the framework's jobs and for any batch class of yours that opts in |
| 16 | **[An outbound call always gets an answer](#outbound-calls-an-answer-every-time-and-no-stored-credentials)** | Developers | `send()` always returns a response, and a credential header set by hand is never stored in clear text |
| 17 | **[Bypassing security now also bypasses record sharing](#withoutsecurity-now-also-bypasses-record-sharing)** | Developers | Turning security off on a query now waives object, field and record-sharing checks together |
| 18 | **[Assistive-technology support](#easier-to-use-with-assistive-technology)** | Accessibility | Every copy button names what it copies, and the drawer's symbols are standard icons |

---

## Behaviour changes at a glance

Every change that can affect code, configuration or a check you own, with what to do. Each row links to its explanation.

| Area | What changed | What to do | Read more |
|---|---|---|---|
| Queries | Turning security off on a query also bypasses record sharing | If you relied on it keeping the class's sharing, use `withSystemMode()` | [withoutSecurity() now also bypasses record sharing](#withoutsecurity-now-also-bypasses-record-sharing) |
| Queries | A cursor or a query locator follows the query's sharing setting | Nothing, unless you relied on a bypass being ignored | [toCursor() now honours the sharing setting](#tocursor-now-honours-the-sharing-setting) |
| Queries | A cached system-mode read that does not state its sharing is not cached, and one that bypasses sharing is kept per user when its rows depend on the user | Add `.withSharing()` or `.bypassSharing()` to cache it again; cache a translated value through `toLabel` or `.withSharing()` | [A cached read must state its sharing setting](#a-cached-read-must-state-its-sharing-setting) |
| Queries | A cached read in user mode is kept for the transaction | Where you write outside `DML_Builder` and read back, use `withoutCache()` | [A user-mode withCache read is now cached for the transaction](#a-user-mode-withcache-read-is-now-cached-for-the-transaction) |
| Health Check | The Platform Cache checks' detail text is longer | Update a check that matches the text exactly | [The Platform Cache health checks say what happens to query caching](#the-platform-cache-health-checks-say-what-happens-to-query-caching) |
| Caching | Saving several cache values at once saves all of them or none | Store a large value on its own | [Saving several cache values at once saves none when one is too large](#saving-several-cache-values-at-once-saves-none-when-one-is-too-large) |
| Outbound | A hand-set credential header is stored redacted; a later retry is parked | Move the credential to a Named or External Credential | [Hand-set credential headers are not stored with the call record](#hand-set-credential-headers-are-not-stored-with-the-call-record) |
| Outbound | A call always returns a response; status 0 means none came back | Do not retry on status 0 yourself | [send() never returns null](#send-never-returns-null) |
| Outbound | An idempotency key given to a handler call is now sent | Nothing; a keyed POST is now retried after a server error | [A key you give withIdempotencyKey() is sent when a handler makes the call](#a-key-you-give-withidempotencykey-is-sent-when-a-handler-makes-the-call) |
| Outbound | A call uses the circuit breaker you name | Nothing, unless two names were meant to share one breaker | [withCircuitBreaker(name) uses the breaker you name](#withcircuitbreakername-uses-the-breaker-you-name) |
| Outbound | Only 408, 425, 429, 500, 502, 503 and 504 retry by default, and a status list you give also limits the scheduled retry | Add a "try later" status in `getRetryableStatusCodes()` | [Only the "try later" statuses are retried by default](#only-the-try-later-statuses-are-retried-by-default) |
| Outbound | A 500, 502 or 504 on a POST or PATCH with no key is not sent again | Give the call an idempotency key | [A server error on a request that is not safe to repeat is not sent again](#a-server-error-on-a-request-that-is-not-safe-to-repeat-is-not-sent-again) |
| Outbound | A failure after a successful response is not sent again, unless you listed the exception type and the request is safe to repeat | Nothing; check the issue's External System May Have Acted box | [A failure after a successful response is not sent again](#a-failure-after-a-successful-response-is-not-sent-again) |
| Outbound | A call that fails in your own code reads Failed, not Retry | Change a report, Flow or list view that looks for Retry | [A call that fails in your own code reads Failed, not Retry](#a-call-that-fails-in-your-own-code-reads-failed-not-retry) |
| Outbound | An open circuit makes a call with retries left wait | Nothing, unless you counted Aborted calls | [An open circuit schedules a call with retry budget left](#an-open-circuit-schedules-a-call-with-retry-budget-left) |
| Outbound | Three messages that stop a call before it is sent come from Custom Labels, with new wording | Read the label in code or tests that match the old text | [Three messages that stop an outbound call before it is sent now come from labels](#three-messages-that-stop-an-outbound-call-before-it-is-sent-now-come-from-labels) |
| Outbound | A call made through a handler records one issue, not two | Nothing, unless you counted issues | [A failed outbound call is sent again only when that is safe](#a-failed-outbound-call-is-sent-again-only-when-that-is-safe) |
| Outbound | Calls an earlier version left at Retry with no Next Retry are not changed | Retry or resolve them, or run the script | [Calls an earlier version left waiting for a retry are not changed by the upgrade](#calls-an-earlier-version-left-waiting-for-a-retry-are-not-changed-by-the-upgrade) |
| Saving data | Commit hooks run once per attempt when a row lock is retried | Make an override that counts, sends or writes safe to run twice | [Your commit hooks run once per attempt when a row lock is retried](#your-commit-hooks-run-once-per-attempt-when-a-row-lock-is-retried) |
| Saving data | DML failures log once, filed under one class and method | Point a filter or alert on the old class and method at `DML_Transaction.commitWork` | [DML failures now log once, from one place](#dml-failures-now-log-once-from-one-place) |
| API issues | Retry and Retry Selected need the Retry API Issue permission | Assign Kern API Issue Resolver or Kern Administrator | [Retry on an API issue needs the Retry API Issue permission](#retry-on-an-api-issue-needs-the-retry-api-issue-permission) |
| API issues | Retry on an issue whose service is paused or switched off is refused with a message, and the issue stays open; until now the call was tried again and stopped before it was sent, and, when the service logs issues, a new open issue was logged | Switch the service back on, then press Retry | [Run many failed calls again from the API Issues list](#run-many-failed-calls-again-from-the-api-issues-list) |
| API issues | The Resolved Date is filled on every path that resolves an issue; until now only a request run again in your org filled it | Nothing; a report or list view on Resolved Date now counts these issues too, and issues resolved before the upgrade keep a blank date | [Run many failed calls again from the API Issues list](#run-many-failed-calls-again-from-the-api-issues-list) |
| Security | API issues and log entries Private on a new install; deletes need Delete API Records | Schedule purges as an administrator; choose your sharing default | [API issues and log entries are private on a new install](#api-issues-and-log-entries-are-private-on-a-new-install) |
| Testing | A handler's canned answer stands in only inside a unit test | Name a credential, or rely on the metadata record | [A handler's canned answer no longer stands in for a real call outside a unit test](#a-handlers-canned-answer-no-longer-stands-in-for-a-real-call-outside-a-unit-test) |
| Testing | A callout inside an Apex integration test reaches the real endpoint | Register a mock through `kern.API_MockFactory` where you want one | [A callout through the framework reaches the real endpoint inside an Apex integration test](#a-callout-through-the-framework-reaches-the-real-endpoint-inside-an-apex-integration-test) |
| Testing | Permission set assignments from one factory call save together | Nothing, unless a test expected a partial save | [Permission set assignments from one call save together](#permission-set-assignments-from-one-call-save-together) |
| Testing | A cleared mock queries the database again | Register an empty list if a test needs an empty answer | [A cleared mock queries the database again](#a-cleared-mock-queries-the-database-again) |
| Async chains | The first chain in an action no longer carries the action's ID | Use Launched Under or the root correlation ID | [Every chain run has a tracking ID of its own](#every-chain-run-has-a-tracking-id-of-its-own) |
| Async chains | The typed status reports elapsed time as the Chain Monitor does | Nothing, unless a test asserts a live millisecond count | [The typed chain status reports an elapsed time the way the Chain Monitor does](#the-typed-chain-status-reports-an-elapsed-time-the-way-the-chain-monitor-does) |
| Async chains | A stalled step runs again only when that is safe | Override `isIdempotent()` on steps safe to run twice | [A stalled chain runs a step again only when that is safe](#a-stalled-chain-runs-a-step-again-only-when-that-is-safe) |
| Async chains | A run that has ended stays ended | Run the repair script for runs left Stalled with an end time | [A chain run that has ended stays ended](#a-chain-run-that-has-ended-stays-ended) |
| Async chains | An API step stops retrying when the external system may have acted | Name the status in the step's `retryOn(...)` to keep retrying | [An API step stops retrying when the external system may have acted](#an-api-step-stops-retrying-when-the-external-system-may-have-acted) |
| Async chains | Two new chain fields, Last Manual Retry At and Elapsed (ms), are not readable through a cloned permission set or a profile until you grant Read | Grant Read on the two fields | [Two new chain fields need Read for a cloned permission set or a profile](#two-new-chain-fields-need-read-for-a-cloned-permission-set-or-a-profile) |
| Async chains | The Chain Monitor's Restarted from row is gone | Nothing; Launched under links the restart | [The Chain Monitor marks manual retries and sorts by elapsed time](#the-chain-monitor-marks-manual-retries-and-sorts-by-elapsed-time) |
| Hierarchies | A hierarchy deeper than its depth limit throws | Raise the limit with `withMaxDepth` | [A hierarchy deeper than its depth limit stops with an error](#a-hierarchy-deeper-than-its-depth-limit-stops-with-an-error) |
| Batch jobs | A batch-size record is found by your handler's name | Rename a record named after the old internal key | [A batch-size record is found by your handler's name](#a-batch-size-record-is-found-by-your-handlers-name) |
| Batch jobs | A failure your code already logged now logs twice | Expect the extra ERROR entry in counts and alerts | [Batch failures now log twice when your code already logged them](#batch-failures-now-log-twice-when-your-code-already-logged-them) |
| Batch jobs | A batch size that does not fit its chunk writes a WARN entry | Pick a size that fits | [Batch jobs: platform-reported failures and batch sizes that fit](#batch-jobs-platform-reported-failures-and-batch-sizes-that-fit) |
| Logging | The Log Console's body search is literal | Search for the words themselves, not wildcards | [The Log Console pages, searches literally and fits a narrow screen](#the-log-console-pages-searches-literally-and-fits-a-narrow-screen) |
| Logging | Lines from the Write Detailed Log Messages action start with a Flow marker | Update a filter that matches the text exactly; the lines now start with `[Flow]` | [Every log entry says who wrote it](#every-log-entry-says-who-wrote-it) |
| Logging | A line logged while a handler is still being set up has no HTTP method | Nothing | [Outbound calls: an answer every time, and no stored credentials](#outbound-calls-an-answer-every-time-and-no-stored-credentials) |
| Flow | Logging an email to a User through standard activity logging is refused | Use custom activity logging for Users | [The Flow email action refuses to log an email to a User through standard activity logging](#the-flow-email-action-refuses-to-log-an-email-to-a-user-through-standard-activity-logging) |
| Inbound | An inbound handler whose `handleError()` override throws answers 500, not a 200 with an empty body | Tell the owners of a calling system that treated the empty 200 as success | [Smaller fixes](#smaller-fixes) |
| Health Check | The Trusted Site row is gone, and the Health Check now runs eleven checks | Update a runbook that expects the Trusted Site row | [The Health Check no longer asks for a Trusted URL](#the-health-check-no-longer-asks-for-a-trusted-url) |
| Scheduled jobs | A job in its own mode no longer offers "Every N Minutes" | Put such a job on the job runner | [A job in its own mode no longer offers "Every N Minutes"](#a-job-in-its-own-mode-no-longer-offers-every-n-minutes) |
| Code scanning | The trigger delegation rule checks the whole trigger body | Move top-level trigger logic into a trigger action (rule `KernTriggerMustDelegate`) | [KernTriggerMustDelegate checks the whole trigger body](#kerntriggermustdelegate-checks-the-whole-trigger-body) |
| Code scanning | A new informational rule reports a governor limit read directly (priority 5) | Read limits through `kern.UTIL_Limits` (rule `KernLimitsThroughWrapper`) | [A new scanner rule reports a governor limit read directly](#a-new-scanner-rule-reports-a-governor-limit-read-directly) |
| Code scanning | Scans with the framework-side ruleset run the Kern rules again under Code Analyzer 5.16 and later, so a gate may report findings it missed | Fix the findings, or adjust the gate | [The framework ruleset runs the Kern rules again under Code Analyzer 5.16 and later](#the-framework-ruleset-runs-the-kern-rules-again-under-code-analyzer-516-and-later) |
| Pipeline | The CI workflows no longer let a branch name or pull-request title run as code; workflows already written keep the hole until written again from the new templates | Run `node .kerndx-pipeline/bin/kerndx upgrade` | [The CI workflows the pipeline writes no longer let pull-request text run as code](#the-ci-workflows-the-pipeline-writes-no-longer-let-pull-request-text-run-as-code) |
| Components | The Validation Errors component's field-click event no longer travels up the page | Listen for `fieldclick` on the component's own tag | [The Validation Errors component's click event stays with the component](#the-validation-errors-components-click-event-stays-with-the-component) |

---

## Run many scheduled jobs from a few scheduled-job slots

**Who it's for:** admins who schedule work, and developers whose jobs need to run more often than hourly.

Any number of your scheduled jobs can now share one to twelve of the org's scheduled-job slots, and run as often as every five minutes.

A Salesforce org has 100 scheduled-job slots, and a job scheduled the usual way takes one of them and fires at most once an hour. Until now each `ScheduledJob__c` record
took its own slot. 1.8 adds a **job runner**: a small number of platform scheduled jobs that check for due work and start it, so any number of your jobs can share them.

- **Put a job on the runner.** Set a job's **Execution Mode** to **Job runner** and it no longer takes a platform slot of its own. Activate the runner from the **Job
  runner** card in Health Check (on Kern Home), and choose how often it checks for due jobs: every hour, 30, 15, 10 or 5 minutes, which takes one, two, four, six or twelve
  slots. Every job you add after that takes no slot of its own. The record shows the job's next run, last run and outcome, and **Run now** starts it on the spot.
- **Health Check watches the runner with three checks.** **Job Runner** reports whether the runner is checking for due jobs, whether its scheduled jobs are all in
  place, and whether the user who activated it is still active; **Repair** fixes it. **Jobs Waiting for the Job Runner** reports any job set to the runner while the
  runner is not active; **Activate** fixes it. **Job Runner Capacity** always reports how many of the org's 100 scheduled-job slots are in use, and says what to change
  when the last check left jobs waiting.
- **The cron editor tells the truth about how often a job can run.** For a job in its own mode the minutes field takes one number, because a scheduled job fires at most
  once an hour; on the job runner it takes steps, ranges and lists, and the preview states the effective interval.
- **The Class Name field takes a name you type.** It still suggests the org's schedulable classes, and it also takes a class the suggestions do not show yet, such as one
  you have just deployed: the list is kept for eight hours, down from 24. A name is checked as soon as you leave the field, and one that cannot be scheduled is explained
  under the field, with Save closed until it is fixed.
- **A job that builds an async chain works unchanged on the runner.** Salesforce limits how many queued jobs can follow one another in a row. A chain launched from a
  job on the runner starts counting from where that job sits, so it can still use the full number of steps it would have had.
- **Dates on the scheduled-job screens and the job runner card read in your Salesforce locale and time zone**: the next-run preview in the editor, the last-run and
  next-run dates on the detail view, and the runner card's last-check sentence, so they match the record's own date fields beside them.

**What ships for it.** Eight new fields on `ScheduledJob__c`: `ExecutionMode__c`, `RunPriority__c` and `OverlapPolicy__c`, which you set (the overlap policy either skips
a run while the previous one is still running or lets runs overlap), and `NextRunAt__c`, `LastRunAt__c`, `LastRunOutcome__c`, `LastRunReason__c` and `LastRunJobId__c`,
which the framework writes. The new `SCHED_JobRunner` class is the scheduled job Health Check creates for you. A `ScheduledJobRunner` feature flag is the runner's off
switch, and a `JobRunnerCheckLimit` job setting record sets the most jobs one check may start (25 as shipped).

**Who can manage it.** The new **Kern Job Runner Management** permission set carries the new **Manage Job Runner** custom permission. It lets a user put a job on the runner,
run it now, and activate, repair or deactivate the runner in Health Check. The set also gives access to scheduled job records (create, read and edit, no delete)
and the Scheduled Jobs tab, so it works on its own for managing schedules; activating the runner also needs access to Health Check, which the set does not give.
Jobs on the runner run as the user who activated it, and a check refuses to run for a user without the permission, so assign the set to that user and to whoever
manages schedules. It ships assigned to nobody.

## API issues and log entries are private, and only an administrator deletes call history

**Who it's for:** admins who decide who sees what; support teams who work through API issues.

On a new install, a person now sees only their own API issues and log entries, and only a user who holds the new Delete API
Records permission (administrators, through the Kern Administrator set) can delete the record of a call to another system. An
API issue or a log entry can carry what a request held, or what an error said about a customer's record. Until now every user
could read every one, and anyone with Delete on API issues could remove the record of what went wrong.

- **Private on a new install.** API Issue and Log Entry ship with a **Private** sharing default, like API Call and the async
  chain run already did. A person sees a record they own, a record owned by someone below them in the role hierarchy, or every
  record when they hold View All Records on the object. You need no sharing rule or group.
- **The people who resolve issues still see all of them.** The new **Kern API Issue Resolver** permission set includes View All
  Records on API issues and API calls, with no edit or delete. A resolver's Retry, resolve action and Retry Selected work on any
  issue, whoever owns it. Administrators see every record through the **Kern Administrator** set, and the Log Console and the
  Chain Monitor's log stream read every entry, as before.
- **Only a user the Bypass API Record Delete Guard flag is on for can delete an API call or an API issue.** Out of the box,
  that is anyone with the new **Delete API Records** custom permission, which is in the Kern Administrator set. Anyone else,
  a resolver included, is told why and nothing is deleted, whether they try from a record page, a flow, your own Apex or the
  scheduled purge.
- **One feature flag makes that decision.** `BypassApiRecordDeleteGuard` is on for every holder of Delete API Records through a
  built-in rule. Add a `FeatureFlagStrategy__mdt` record to let a profile, a permission set or a public group delete too, or one
  user through a hierarchical custom setting.
- **Health Check warns before a purge deletes nothing.** The Data Retention check says who must schedule the purge of API calls
  and API issues, and warns when the flag record is deactivated, because then nobody can delete them.

**What to do.** An upgrade never changes your org's sharing default, so an upgraded org keeps Public Read/Write until you change
it in **Sharing Settings**. Give the Kern API Issue Resolver set to your support team. Schedule a purge of API calls or API issues
as an administrator. If your own Apex deletes them, run it as a user who holds Delete API Records.

**Read more.** [API issues and log entries are private on a new install](#api-issues-and-log-entries-are-private-on-a-new-install)
has the detail, including what `kern.SEL_ApiIssue.findByFailedApiCall` returns; the Security Guide's
[Who can see the framework's own records?](../docs/Security%20-%20Guide.md#who-can-see-the-frameworks-own-records) explains the
access model.

## Follow one action across every chain it launched

**Who it's for:** operations users tracing a problem; developers who launch chains.

One search now brings back everything one action did, including the work of every chain it launched. An **action** is one thing that starts work in your org, such as a
user saving a record, a Flow running or a scheduled job firing, together with everything it sets off. Its **tracking ID** (a correlation ID) is stamped on every log
entry the action writes.

Until now a chain launched inside an action took the action's own tracking ID. So a second chain in the same action, or a chain launched from a step, could not be
found by the ID on its own record, and a chain launched outside any action logged its steps with no ID at all.

**Every chain run now has a tracking ID of its own**, shown on its tracking record and in the Chain Monitor, and every one of its log entries carries it. **Every log entry
also carries a root correlation ID**: the tracking ID of the action that started everything, however many chains deep the entry was written. One search in the Log Console
for an action's ID brings back the whole action, the chains it launched included, and a search for a run's ID brings back that run alone. The run record shows the ID it was
launched under (the new **Launched Under** field), the Chain Monitor's detail panel shows it with a copy button, and `kern.LOG_Builder.rootCorrelationId` answers the
action's ID anywhere in your Apex.

**A step or a completion handler may now launch one chain of its own.** Chains nest up to five deep, and a step that is retried after launching a chain gets the same chain
back rather than a second one.

**The Log Console shows the whole action.** Open any entry and press **Show the whole action**, or paste an action's tracking ID, and the console shows everything that action
did: its own entries beside the entries of every chain it launched, oldest first, on a date range set to the action's lifetime. One banner says when it ran, how many chains
ran under it and how many failed, shows each chain as a small button (failed chains first) that narrows the list to that chain, and offers a button that lists them all
in the Chain Monitor. When the entry's own chain is the one that started the action, the drawer's Action row says so. Each step you take to narrow the console (to the
action, to one of its chains, or to one run) is kept in the page's address. Back undoes one step at a time, a refresh keeps your place, and you can share the address.

**The Chain Monitor lists an action's chains.** Scoped to an action, it shows a **Launched under** column that says what launched each chain, and links back to the
action's logs. At 1280 pixels and below the list keeps three columns (Chain Name, Status and Started), and adds Launched under only while it is scoped to an action.

The one change to look for in your own code is under
[Every chain run has a tracking ID of its own](#every-chain-run-has-a-tracking-id-of-its-own).

## An async chain never repeats a step that may already have done its work

**Who it's for:** developers who build async chains; operations users who watch them in the Chain Monitor.

A stalled chain now runs a step again only when that is safe, and a chain run that has ended stays ended. The watchdog (the
scheduled job that revives stalled chains) used to restart a stalled chain at the first step with no saved result: if that step
had already made its callout before the chain stalled, the restart made it again, and its work could happen twice. A run that
had ended could also be rewritten later as Stalled, and then nothing moved it.

- **A stalled step runs again only when it never started, or declares itself safe to repeat.** Otherwise the chain ends
  `Failed`, and its message names the step and tells you to check whether its work landed. A step declares itself safe when
  `isIdempotent()` returns `true`.
- **API steps declare it for you.** An API step whose request is safe to send twice (a GET, PUT or DELETE, or a setting with
  Idempotency Enabled) counts as safe without any code. A POST or PATCH step with no key is not sent again after no response,
  a 500, 502 or 504, or a success followed by a failure.
- **A run that has ended stays ended.** If its completion or error handler could not be started, the run keeps its Completed or
  Failed status and its end time, its message names the handler, and an ERROR entry in the Log Console says the same. The
  framework refuses a direct edit that would move a run back to a live status.
- **The Chain Monitor shows each step's state from the run record**: Running, No result recorded or Did not run.

**What to do.** On every step whose work is safe to run twice, override `isIdempotent()` to return `true`, so the watchdog keeps
recovering it and an operator can retry it after it fails. If your org's queue is slow, raise the watchdog's
`StaleThresholdMinutes` above the longest wait you see. If the Chain Monitor shows runs as Stalled with an end time, run the repair
script under [A chain run that has ended stays ended](#a-chain-run-that-has-ended-stays-ended).

**Read more.** [A stalled chain runs a step again only when that is safe](#a-stalled-chain-runs-a-step-again-only-when-that-is-safe)
has the full rules; the Async Processing guide's
[What happens to a stalled step?](../docs/Async%20Processing%20-%20Guide.md#what-happens-to-a-stalled-step) walks through them.

## Every log entry says who wrote it

**Who it's for:** admins and developers deciding where an error came from.

You can now tell from an entry itself where it came from, and report on it. Every log entry now says who wrote it (**Origin**: Framework, Apex, Flow or Component) and
what wrote it (**Source**: the class, Flow or component as a plain name), stamped when the entry is written and stored as two fields on `LogEntry__c`, `Origin__c` and
`Source__c`, that you can report on.

- **The Top sources card names each writer with its origin**, clicking a writer narrows the list to exactly its entries, and an **Origin** filter joins the filter row
  beside Context.
- **The Source column names the class, Flow or component that wrote each entry**, shows who wrote it, and sorts by it. A Flow whose name holds a dot, such as
  `Order v1.2`, shows its whole name.
- **An entry logged without a location still names its writer.** When an entry is emitted with no `.at()`, no exception and no stack trace passed in from a component,
  the framework takes the calling class and method from the top of the call stack it already records for that entry, so the entry is attributed like one given a
  location by hand. A trigger is stored by its name.
- **Entries from Flow name the Flow.** Start Flow Correlation and End Flow Correlation file their entries under the Flow. The Log Flow Event action gains an
  optional **Flow Name** input. When you fill it in, the entry is filed under the Flow and the step stays in the location text. When you leave it blank, the entry is filed
  under the step, as before, so no Flow changes what it reports when you upgrade. The Write Detailed Log Messages action now marks its entries with the Flow origin, and
  its messages start with the same `[Flow]` marker. Every entry written from Flow now carries that marker, whichever action wrote it.
- **An org with a namespace of its own ranks each class separately.** In such an org a location such as `acme.OrderService.submit` used to rank one writer, `acme`, for every
  class. The framework now drops the namespace from the location before it names the writer, so each class ranks on its own.

Entries written before the upgrade carry neither value and are left out of the card. See [Known issues](#known-issues) for how that shows while older entries age out.

**What to do.** Add Origin and Source to your log entry reports and list views; the Kern Administrator set grants Read on both. Fill in Flow Name on the Log Flow
Event action to file a Flow's entries under the Flow. The Logging guide's
[Who wrote an entry](../docs/Logging%20-%20Guide.md#who-wrote-an-entry) explains each value.

## The Log Console pages, searches literally and fits a narrow screen

**Who it's for:** admins running the console against a busy org.

The Log Console now pages through a busy org, finds exactly what you type, and stays usable beside its detail panel on a laptop screen.

- **Numbered pages instead of endless scroll.** Both views page, with a position line, page numbers for up to seven pages, and 25, 50 or 100 entries a page.
- **A narrow screen keeps what matters.** With the drawer open at 1280 pixels and below, the entries list keeps four columns, the counts above it scroll, and at 820 pixels a
  **Back to the list** control returns you. The Problems view keeps four columns with the drawer open.
- **The search box looks for exactly what you typed, in both places it searches.** The message search was already literal. The search over long message bodies now treats
  `*`, `?`, and the search operators AND, OR and AND NOT as ordinary text too. A body still matches on whole words through the platform's search index. Two consequences:
  several words are now found as a phrase (together, in order, as the message search already required), and a two-character term no longer matches every entry's body.
- **A body search under a source filter stays within that source.** Until now the source filter was dropped from the body search, so it could surface entries from every
  source.
- **The Stack trace tab explains an empty trace correctly.** It means the entry came from inside the framework, from a Flow, or from a component that reported no error, not
  that the entry was logged without an exception.
- **The drawer's timeline uses standard icons**, and each copy button says what it copies. See [Easier to use with assistive technology](#easier-to-use-with-assistive-technology).

**What to do.** If a saved search relied on `*` or `?` as a wildcard in message bodies, search for the words themselves. The Logging guide covers the console.

## The Chain Monitor marks manual retries and sorts by elapsed time

**Who it's for:** operations users working through failed and long-running chains.

The Chain Monitor now shows when a person retried a chain, sorts running chains by how long they have run, and says which steps never ran.

- **The Chain Monitor marks a manual retry.** The step timeline shows "Retried manually after 37m" above a step someone retried, and the run record's new **Last Manual Retry
  At** field says when Retry was last used, for list views, reports and Flows. Only the Chain Monitor's Retry sets it: a step's own automatic retries and the recovery of a
  stalled run leave it alone, and a restart begins a new run with the field empty.
- **The Duration column sorts the way it reads.** A run that is still going sorts by how long it has been going, between finished runs, instead of sorting as empty. The new
  **Elapsed (ms)** field holds that number and works in list views and reports. A run that ended without storing a duration (a background job that hit a limit it could not
  catch, a handler's own failure, or a run with no steps) shows the time between its start and its end.
- **The object's own screens show the same number.** The chain execution **All** list view, the record page's highlights panel and the search results now show Elapsed
  (ms) where they showed the stored duration, which is blank for a running or stalled run.
- **Steps that never ran say "Did not run"** once the run has ended, and the one step the run may have been working on when it ended says "No result recorded".
- **Fixed: a run going for more than about 115 days could not end.** Its duration no longer overflows the field, so the run can now end however it ends: finishing,
  failing, being aborted, or being given up on after a stall. Its stored duration is capped at 9,999,999,999 ms, about 115.7 days.
- **The detail panel describes the run you selected now, whatever answered last.** The panel used to show whichever load finished last, so after a quick change of
  selection you could see one run's detail while Retry, Restart and Abort acted on another. A new selection now clears the previous run's panel, and an answer is taken only
  for the run still selected.
- **The status filter shows a Status heading and two actions**, **Select All** and **Clear All**.
- **On a phone-width screen the list sits above the detail** at full width, and each action in the detail toolbar keeps its label whole. The detail's Restarted from
  row is gone: the Launched under row reads a restart as a link to the run it was restarted from.

**What to do.** If your users reach the Chain Monitor through a cloned permission set or a profile, grant them Read on Last Manual Retry At and Elapsed (ms). The
Async Processing guide's [Monitoring](../docs/Async%20Processing%20-%20Guide.md#monitoring) section covers the screen.

## Saving data: retry on a row lock, expected refusals, failures that log

**Who it's for:** developers who write records through `kern.DML_Builder`.

A save that another transaction briefly blocks no longer has to fail, or be wrapped in a retry loop of your own, and a DML failure that used to leave no trace now writes a log
entry.

**The DML builder retries a commit refused for a row lock.** `withRetryOnLock()` tries the commit once more, and `withRetryOnLock(retries)` up to the number of extra
attempts you give, from 1 to 5, when Salesforce refuses it because another transaction holds a row: the whole commit in all-or-nothing mode, only the refused rows in partial
mode. Any other refusal surfaces at once. One WARN entry records a retried commit, and the setting travels with `.async()`. A commit that never asked for it behaves exactly
as before.

| You wrote | Until now | From 1.8 |
|---|---|---|
| a hand-rolled loop catching `UNABLE_TO_LOCK_ROW` around `execute()` | the only way to retry, and it had to clear rolled-back Ids itself | `.withRetryOnLock()`; the loop, the Id clearing and the limit check are the builder's |
| `.doUpdate(records).execute()` on a row a job holds | refused after the platform's ten-second wait | unchanged unless you add `.withRetryOnLock()` |

**A refusal you expect can log below ERROR.** When you allow partial success, you can now declare a refusal you expect, such as a duplicate blocked by a unique field:
`.expectRefusal(StatusCode.DUPLICATE_VALUE)` logs that row at WARN instead of ERROR. Everything else about the write is unchanged: other failures still log at ERROR, and the
refused row still counts as a failure in the result. The declaration travels with `.async()`, so a background job logs the same refusal at WARN.

**Failures that used to leave no trace now log.** An all-or-nothing DML failure now rolls back and writes one ERROR entry before the exception reaches you, and an exception
that a partial-mode commit swallows (a hook that throws, or a statement-level platform failure) writes one ERROR entry too, recording that statements already committed stand
and operations not yet performed never ran. Both respect `suppressLogging`. See
[DML failures now log once, from one place](#dml-failures-now-log-once-from-one-place) for what that changes in your log.

## Queries: a selector caches its reads with one override

**Who it's for:** developers whose triggers, services or Flow actions read the same records more than once in a transaction.

A selector can now answer a repeated read from memory, so a read that three trigger actions make costs one query instead of three.

The same read often runs several times in one transaction: three trigger actions each look up the same parent accounts, and each repeat costs a query against the limit
of 100. A selector built on `kern.SEL_Base` can now opt into caching once. Override `cacheScope()`, and the first read goes to the database while every repeat of the same
read in the transaction comes back from memory, as a copy of its own for each caller.

```apex
public override kern.UTIL_Cache.Scope cacheScope()
{
	return kern.UTIL_Cache.Scope.IN_TRANSACTION;
}
```

- **Where the rows are kept is up to you.** `IN_TRANSACTION` keeps them in memory for the transaction. `AUTO`, `SESSION` and `ORG` also let a system-mode read whose
  method states its sharing (`withSharing()` or `bypassSharing()`) use Platform Cache where your org has space for it, for the number of seconds
  `cacheTimeToLiveSeconds()` returns (900 when it returns
  null). A user-mode read is only ever kept in memory for the transaction.
- **One query can change it.** `withCache(scope, ttlSeconds)` caches a single read, and `withoutCache()` sends one read to the database whatever the selector asked for.
  The last caching call on a builder wins.
- **Writes through the framework empty it.** Every write through `kern.DML_Builder` empties the whole in-memory cache before the save starts and again when it
  ends, saved or rolled back, even for a write to an unrelated object; so do inbound web services, the test data builders and the Flow email action. Logging normally
  publishes a platform event, which saves nothing in your transaction and leaves the cache alone; inside a platform-event or change-event trigger, most log entries
  are saved through `kern.DML_Builder` and empty it like any other write (entries dropped because too many arrived at once do not). Writes the framework does not make (a Flow,
  a plain DML statement, another package) are not seen, and rows kept in Platform Cache can stay until their time-to-live runs out.
- **Some reads are never kept in memory:** results over 200 rows, aggregate queries, queries with a child subquery, and new results once the transaction has used 40%
  of its heap (memory) limit; the oldest kept results are dropped first. Rows take a little more memory after their query returns, so a transaction that caches a lot
  can reach about half the limit. Row-locking, `ALL ROWS`, random, paged and cursor reads, counts and query locators are never cached at all. Declining is silent and
  costs one query.
- **The performance log says what happened.** A query's logged performance entry carries a cache status that names where the read came from, or why it was not cached.

A selector that overrides neither method behaves exactly as before. The Selectors guide's
[Caching Queries](../docs/Selectors%20-%20Guide.md#caching-queries) section covers the scopes, what empties the cache, how a
selector tells its callers how old its rows may be, and what to do in tests.

## Testing: saved users and a different answer for each query

**Who it's for:** developers writing Apex tests with `kern.TST_Factory` and `kern.TST_Mock`.

A test that needs saved users beside ordinary records, or a query that answers differently the second time, no longer needs a workaround of its own.

**Saved test users from the factory.** `kern.TST_Factory.insertUser(profileName)`, `insertUser(profileName, companyName)`, `insertUsers(profileName, count)` and
`insertUsers(users)` hand back saved users, ready for `System.runAs`, and keep their writes apart from the ordinary records your test saves before or after them. `newUser`
and `newUsers` still return unsaved users, and `insertUsers(users)` saves users you shaped yourself, a role included.

**Factory calls that save users or assign permission sets no longer collide with your test's other records.** In a test, `newUserWithPermissionSet` and
`createPermissionSetAssignments` now save inside the factory's own guard, so an ordinary record saved before or after them in the same method no longer fails with the
platform's mixed-DML error (its refusal to save users and ordinary records in one transaction). Outside a test the guard does not apply. One change reaches every
caller, in tests and out; it has its own heading under
[Changes that can affect code you have written](#permission-set-assignments-from-one-call-save-together).

| You wrote | Until now | From 1.8 |
|---|---|---|
| `newUserWithPermissionSet(...)`, then an ordinary insert in the same method | mixed-DML error | works |
| an ordinary insert, then `createPermissionSetAssignments(...)` | mixed-DML error | works |
| `System.runAs(new User(Id = UserInfo.getUserId())) { ... }` around a factory call | needed | no longer needed; the factory owns the guard |

**A test can script a different answer for each query.** `kern.TST_Mock.registerNext(SObjectType, records)` queues an answer for the next query on that object; each answer
serves one query, in order, and once they are used up the object goes back to the records you registered, or to the database. Use it to set up "the first read finds
nothing, the second finds the row", the shape of a retry, a find-or-create, or the losing side of a race between two transactions. A count uses up an answer too. An
exception registered with `throwsException` still fires first and leaves the queue in place.

**The test user builder no longer sets every preference checkbox at random.** Building a `User` through `kern.TST_Factory.newUser` or `kern.TST_Builder` used to give each of
roughly a hundred `UserPreferences*` fields a random value, which in some orgs failed the insert with `INVALID_FIELD_FOR_INSERT_UPDATE` naming a preference field. Those
fields are now left at the platform's defaults, as the `UserPermissions*` fields already were.

## Batch jobs: platform-reported failures and batch sizes that fit

**Who it's for:** developers running batch and queueable work through the framework; admins watching the log.

A batch job that fails in a way its own code cannot catch now leaves an entry in the log, a batch size that wastes runs now warns you, and a batch size you set in
configuration now takes effect.

**A batch job failure the platform reports now leaves a log entry.** When a batch job fails in a way its own code cannot catch, such as a governor limit or an error while it
starts or finishes, the platform publishes a `BatchApexErrorEvent`. The framework now listens to that event and writes one ERROR log entry per failure, for the framework's
own background jobs and for any batch class of yours that opts in by implementing `Database.RaisesPlatformEvents`. The entry names the class that failed and the phase,
carries the platform's message, exception type and stack trace, links to the job, and lists the records the failed run was working on. Nothing alerts and nothing else
changes: a failure the job's own code already caught and logged now appears twice, once from the job and once from the platform's report. The listener is a new trigger on
the event, with its own trigger setting and trigger action records.

**A warning when a batch size makes the platform work in short runs.** A query-backed batch reads its records in fixed chunks of 100, 400 or 2,000, picked by the batch size,
and one run of your code never spans two chunks. A batch size that does not divide its chunk leaves a short run at the end of every chunk: at 75, a job over 290 records makes
six runs instead of four. The framework now writes one WARN entry when a batch is launched with such a size, naming the size, the chunk, the short run and the nearest sizes
that fit, folded into one problem however often the job runs. The sizes the framework uses by default all fit; only a size you set yourself can miss. The Async Processing
guide has a new [Choosing a Batch Size](../docs/Async%20Processing%20-%20Guide.md#choosing-a-batch-size) section.

**A batch size in configuration now applies.** A batch size configured in an `AsynchronousJobSetting__mdt` record named after your handler class now applies. Before, the
framework looked the record up under an internal name that could never match, so every job ran 200 items at a time unless a size was passed in code. See
[A batch-size record is found by your handler's name](#a-batch-size-record-is-found-by-your-handlers-name) if you named a record after the old key.

The Async Processing guide covers both the failure listener and the batch sizes.

## Outbound calls: an answer every time, and no stored credentials

**Who it's for:** developers who call outside systems through `kern.UTIL_HttpClient` or a `kern.API_Outbound` service.

Code that calls another system can now count on an answer from every call, and a credential set by hand no longer sits in clear text on the call record.

- **Sending a call no longer returns null.** `send()` always returns a response, and a status code of `0` means no response came back. Details are under
  [`send()` never returns null](#send-never-returns-null).
- **Sending a call answers even when a masking rule blocks.** When a data-masking rule set to block DML fails while the framework redacts a failed call's attachments, the block is
  recorded on the call's result and nothing unmasked is written. The same rule can no longer fail your whole transaction from inside a log entry: the entry is dropped with
  a diagnostic instead. Every failure the framework handles for a call still ends in a response from `send()`, so a try/catch around it has nothing to catch on those
  paths; a governor limit remains the platform's exception.
- **A hand-set credential header is stored redacted**, and a retry in a later transaction no longer replays it. Details are under
  [Hand-set credential headers are not stored with the call record](#hand-set-credential-headers-are-not-stored-with-the-call-record).
- **A key you give a handler call is now sent**, so a keyed POST through `useHandler(...).invoke()` is safe to repeat. Details are
  under [A key you give `withIdempotencyKey()` is sent when a handler makes the call](#a-key-you-give-withidempotencykey-is-sent-when-a-handler-makes-the-call).
- **The API Test Harness shows and copies credential headers redacted.** The value of every credential-bearing request and response header is replaced with a redaction
  marker before it is displayed or copied, so a shared screenshot or a pasted result no longer carries a live token. Ordinary operational headers such as `Idempotency-Key`
  and `traceparent` are still shown in full, and credential merge-field text is shown as written.
- **The API Test Harness shows what a service needs before you press Execute.** The inputs a service declares as required are listed in the form, and the Record ID field
  says whether the service needs a triggering record, rather than either appearing only after Execute refuses. The harness also sits in a card, with status colours on its
  result.
- **Aborted calls get their own list view.** A call refused before it left your org (by a validation rule, or by an open circuit breaker when the call's setting allows
  no retries) is recorded as Aborted. The new **Aborted** list view on API Calls shows those rows on their own, with the service, direction, error messages and
  triggering record beside each.
- **A stored call built with a correlation ID links its later run back to your transaction.** When you build a call with `kern.UTIL_HttpClient` and give it a correlation ID
  with `.withCorrelationId()`, the call record now stores your transaction's logger context, the same document every call record built by `kern.TST_Factory` carries. Until
  now it stored the bare correlation ID, which the logger could not read back, so when the stored call ran again later (a scheduled retry) its log entries carried no parent
  transaction and none of your global context. Call records stored before 1.8 keep the bare ID until they age out.
- **Entries written after a call built and sent in one transaction keep that transaction's parent.** When your code builds a call and the framework sends it in the same
  transaction (a Flow action, the Retry button on an API issue, a call built with `kern.TST_Factory`, or a `kern.UTIL_HttpClient` call given a correlation ID), the log
  entries that transaction wrote after the call named the transaction itself as their parent transaction. They now keep the parent the transaction already had: a
  transaction started by a background job still links back to that job, and a transaction with no parent stays without one. A stored call that runs again in a later
  transaction is unchanged: its entries name the transaction that built the call as their parent.
- **Every line of a web-service call's log names the right service.** Before, a handler that failed left its service name on the lines logged after it for the rest of
  the transaction, and in a batch of calls the first call's save could be logged under a later call's name. Each call's lines now carry that call's service names and HTTP
  method, whatever happened to the calls around it.
- **One exception: a line logged while a handler is still being set up** carries the batch's service names but not the HTTP method. Every other line of the call carries both, as
  before.
- **The Health Check no longer asks for a Trusted URL.** Details are under
  [The Health Check no longer asks for a Trusted URL](#the-health-check-no-longer-asks-for-a-trusted-url).

How the framework decides whether to send a failed call again, and the new External System May Have Acted box, are under
[A failed outbound call is sent again only when that is safe](#a-failed-outbound-call-is-sent-again-only-when-that-is-safe). Running many failed calls again at once
is under [Run many failed calls again from the API Issues list](#run-many-failed-calls-again-from-the-api-issues-list).

## A failed outbound call is sent again only when that is safe

**Who it's for:** developers who build `kern.API_Outbound` services or call through `kern.UTIL_HttpClient`; operations users
who read API issues.

A failed outbound call is now sent again only when the failure can pass and a second send cannot make the other system act
twice. A retry helps after a timeout or a busy server; it does harm when the other system already acted, because a second POST
can create a second order. Until now the framework retried any failed status and never retried a call that got no response.
From 1.8 it looks first at where the call failed, then at whether the request is **safe to repeat**: a GET, PUT or DELETE, or a
call that carried an `Idempotency-Key` (a key the other system uses to spot a repeat).

| The call | From 1.8 | What you can change |
|---|---|---|
| answered 408, 425, 429 or 503 | retried, whatever the method | nothing to do |
| answered 500, 502 or 504 | retried when safe to repeat; otherwise `Failed`, and its issue says the other system may have acted | give a POST or PATCH an idempotency key to keep it retried |
| answered any other 3xx, 4xx or 5xx | `Failed` at once, with its issue | add a status in `getRetryableStatusCodes()` |
| got no response (a timeout, a dropped connection) | retried when safe to repeat; otherwise `Failed`, with the same warning | give a POST or PATCH an idempotency key |
| was refused by the platform before it left your org (for example, unsaved work was pending) | retried, whatever the method, while retries remain | nothing to do |
| was refused by the framework before sending (a validation rule, or an open circuit breaker when the setting allows no retries) | `Aborted`, as before | nothing to do |
| failed in your own handler code | `Failed`, with one issue, unless you listed the exception type | list the type in `getRetryableExceptionTypes()` |
| succeeded, then `parseResponse()` or `onSuccess()` threw | `Failed`, with the same warning, unless you listed the exception type and the request is safe to repeat | check the external system before pressing Retry |
| met an open circuit breaker with retries left | waits for the breaker's cool-off, then tries again | nothing to do |

A new **External System May Have Acted** box on the API issue is ticked whenever the other system may already have done the
work, so a support user checks there before pressing Retry.

**In detail:**

- **A failure in your own handler code no longer leaves the call waiting for a retry that never comes.** When `prepareRequest()`, a request DTO's `populate()`,
  `createRequest()` and the methods it calls, or `onSuccess()` throws, or the save of the records you registered is refused, the call ends `Failed` with one issue. Before,
  such a call was left at `Retry` with no retry time, and nothing ever picked it up. To let the framework retry a failure from your own code, override
  `getRetryableExceptionTypes()` and list each concrete type; a type is matched by its exact name, so a parent type such as `Exception` matches nothing.
- **A callout that got no response is retried when the request is safe to repeat.** A timeout or a dropped connection on a GET, PUT or DELETE, or on any call that
  carried an `Idempotency-Key` (Idempotency Enabled on the setting, or `withIdempotencyKey()`), is retried within the setting's retry budget. A POST or PATCH without a
  key ends `Failed` at once, and its issue says the request may have reached the external system and was not sent again. Before, a call that got no response was never
  retried. A callout the platform refused before it left your org (for example because unsaved work was pending in the transaction) reached nobody, so it is retried
  whatever its method while retries remain.
- **Only the statuses that mean "try later" are retried by default.** A 3xx or 400-class status is no longer retried, and a 500, 502 or 504 on a POST or PATCH with no
  key is not sent again. Details are under [Only the "try later" statuses are retried by default](#only-the-try-later-statuses-are-retried-by-default) and
  [A server error on a request that is not safe to repeat is not sent again](#a-server-error-on-a-request-that-is-not-safe-to-repeat-is-not-sent-again).
- **A failure in your own code after a successful response no longer sends the request again.** When `parseResponse()` or `onSuccess()` throws, the call ends
  `Failed`, unless you listed the exception type and the request is safe to repeat. Details are under
  [A failure after a successful response is not sent again](#a-failure-after-a-successful-response-is-not-sent-again).
- **"Was a key sent?" is judged from the request that actually went out.** A `createRequest()` override that removes the `Idempotency-Key` header means the call is sent
  without a key, and one that sets the header itself means it is sent with one; the method is read from the same request. The key recorded on the call, on its issue and
  in the logged request headers is the one that was sent, and a sent request with no key clears a key stamped on the call, so the Retry button does not replay a key
  that was never sent.
- **The two exception filters of a retry strategy now take effect.** `dontRetryOnException` and `retryOnlyOnException`, used in your `createRetryStrategy()`, now see
  the caught exception: the framework passes it to your strategy for every exception failure it may retry (a throw from your own code you listed, a callout that got
  no response). A failure the external system reported with a status carries no exception, so neither filter sees it; choose statuses with
  `getRetryableStatusCodes()`.
- **Refuse a retry from your handler.** Throw `kern.UTIL_Exceptions.PermanentFailureException` from `prepareRequest()`, a request DTO's `populate()`, `createRequest()`,
  `parseResponse()` (for a 200 response whose body carries a refusal, use its subclass `RequestRefusedException`, below), `onSuccess()` or `createRetryStrategy()`
  to end the call `Failed` at once, whatever the retry settings say. Thrown from `getValidationErrors()` it ends the call `Aborted`, as every validation refusal
  does. `createRetryStrategy()` now has a documented order: it runs after the response is in hand, on the same handler instance, and may read `response`,
  `result.statusCode` and `result.responseBody`.
- **On a service whose circuit breaker is turned on, a callout that got no response counts as a failure, and an open circuit makes a call wait instead of ending it.**
  The circuit breaker stays off until you tick Circuit Breaker Enabled on the service's API setting. Details are under
  [An open circuit schedules a call with retry budget left](#an-open-circuit-schedules-a-call-with-retry-budget-left).
- **A half-open circuit recovers when its trial requests end with no result.** After a circuit's cool-off, a few trial requests test whether the external system is
  back. When every trial was used and none reported a result, the circuit used to refuse every call until its stored state expired. Once the cool-off has passed again,
  it now starts a new round of trials, with one info line in the log per round. A call a half-open circuit refuses waits at least the cool-off before its scheduled
  retry, not the shorter base backoff, and working that wait out uses no trial request.
- **A row lock while saving a successful call's records retries the save once.** The callout is not sent again. The same holds for an inbound handler's save. If your
  handler overrides the commit hooks, read [Your commit hooks run once per attempt when a row lock is retried](#your-commit-hooks-run-once-per-attempt-when-a-row-lock-is-retried).
- **One failing call no longer costs the others in its batch.** When the framework's own handling of a failed call threw (recording the issue, saving the call, or
  deciding the retry), the whole batch of calls failed with it. That call now ends `Failed` on its own and the rest of the batch is saved. A call record that was
  already saved and whose save then fails for good is updated in place, instead of gaining a second record beside the first.
- **The API issue says when the external system may already have acted.** A new **External System May Have Acted** box at the top of the API issue page is ticked when
  a request that is not safe to repeat got no response or a 500, 502 or 504, or when the external system accepted the request before the call failed in your org. Its
  error messages carry a line that says why. Retry still sends the request again when you press it, so check with the external system first; **Retry Selected** on
  the API Issues list skips those issues and leaves them open.
- **A call your code sends through a handler class records one issue when it fails.** That covers `useHandler(...).invoke()` and every API step of an async chain. The
  issue comes from your handler and says whether the external system may have acted on the request. Before, such a call recorded a second issue that never said so, or,
  when your handler's own code threw, only that second issue. Such a call also now keeps the failure your handler hit, as a dispatched call does: a handler that lists
  `System.CalloutException` in `getRetryableExceptionTypes()` is retried after no response, and `PermanentFailureException` is honoured on a plain `invoke()` too.
- **Setting texts say what the settings do.** Retry Issues governs the Retry action and Retry Selected, not the automatic retry. Idempotency Enabled builds an
  outbound key as a SHA-256 hash of the endpoint, the request parameters and the body. A Retry Backoff (sec) of 0 turns automatic retries off, as a Max Retry Count of
  0 does; a backoff of 0 still waits for the breaker's cool-off while the circuit is open.

**What to do.** If your external system uses another status to mean "try later", add it in `getRetryableStatusCodes()`. To let a
failure from your own code be retried, list its type in `getRetryableExceptionTypes()`. To refuse a retry, throw
`kern.UTIL_Exceptions.PermanentFailureException`, or `RequestRefusedException` from `parseResponse()` when a 200 body says the
request was refused. To keep retrying a POST or PATCH after a server error, give it an idempotency key. Calls an earlier version
left waiting are covered under
[Calls an earlier version left waiting for a retry are not changed by the upgrade](#calls-an-earlier-version-left-waiting-for-a-retry-are-not-changed-by-the-upgrade).
If the External System May Have Acted box does not show on your API Issue page after upgrading, add it to the API Issue compact
layout or to your page layout; an upgrade does not change a layout you already have.

**Read more.** Each change has its own heading under
[Changes that can affect code you have written](#changes-that-can-affect-code-you-have-written), and the Web Services guide's
[Failures and retries](../docs/Web%20Services%20-%20Guide.md#failures-and-retries) section has the full table.

## Run many failed calls again from the API Issues list

**Who it's for:** support and operations users who resolve API issues; admins who give them access.

A support user can now select API issues on the list and run all their failed calls again in one go. When another system is
down for an hour, every call to it fails and each leaves an API issue; until now Retry ran those calls one issue at a time, and
only an administrator could press it.

- **Retry Selected on the API Issues list.** Select the issues and press **Retry Selected**. Their failed calls run again in one
  background job, and the screen says how many of the open issues you selected were queued. Calls your org sent out are sent
  again first; requests another system sent in are run again after them, because the platform does not allow a callout after
  data has been saved in the same step.
- **Each request is sent once.** When several issues were logged for the same request, the job sends it once and marks every
  issue of that request Resolved when the call succeeds.
- **It leaves alone what it must not send.** An issue stays open, unsent, when the external system may have acted on its
  request, when it is for a call your org sent out and its service is paused or does not allow retries (Retry Issues off, the
  setting inactive, its required feature flag off, its bypass feature flag on, or all APIs or all outbound APIs switched off),
  or when its own call, or a call for its record, is still in progress; the job counts that last kind in a warning in the log.
  A request another system sent in is run again whatever its service's Retry Issues setting says.
- **The same from a flow or from Apex.** The **Retry API Issues** flow action (category **Api Callouts**), also
  `kern.FLOW_RetryApiIssues.retryApiIssues`, takes one request holding **API Issue Ids**. It answers with **Job Id** (empty when
  nothing was queued), **Queued Count**, **Success** (true when you hold the Retry API Issue permission and at least one issue was
  queued) and **Message**, a sentence you can show the person who asked.
- **A permission of its own.** Retry and Retry Selected need the new **Retry API Issue** permission. The new **Kern API Issue
  Resolver** permission set grants it, with read access to every API issue and API call, the API Issues tab and the Kern app,
  and no edit or delete. Kern Administrator grants it too. The Kern API Issue Resolver and Kern Administrator sets each give
  access to the flow behind the button.
- **Retry on one issue runs the call the issue is about.** For a call your org sent out, **Retry** on the API issue sends it
  again. For a request another system sent in to your org, Retry runs that request again in your org, keeps the changes it
  makes, and marks the issue resolved when it works.
- **Retry on one issue checks that its service is running.** For a call your org sent out, when the issue's service is paused
  or switched off (the setting inactive, its required feature flag off, its bypass feature flag on, or all APIs or all outbound
  APIs switched off), **Retry** sends nothing, the issue stays open, and you are told: "This service is paused or switched off,
  so the call was not sent and the issue stays open. Ask your administrator to check the service's API setting and its feature
  flags." Until now the call was tried again and stopped before it was sent, and, when the service logs issues, a new open issue
  was logged beside the old one. Retry Selected leaves such issues alone too.
- **A resolved issue always records when it was resolved.** The **Resolved Date** on an API issue is now filled whenever the
  issue is resolved: by **Retry**, by **Retry Selected** and its background job, or by a later successful call for the same
  request when the service has Resolve Issues on. Until now only a request run again in your org filled it. Issues resolved
  before the upgrade keep a blank date.
- **The Retry action's refusals are reworded and can be translated.** They now come from Custom Labels: "The call was not
  sent: this service has no API setting, or Retry Issues is off in its API setting. Ask your administrator to add the setting or
  turn on Retry Issues, then run the call again.", "The inbound request could not be
  replayed.", and, new, "You need the Retry API Issue permission to run this call again. Ask your administrator for the Kern
  API Issue Resolver permission set." Until now the first two read "Retry Failure is not enabled for this API call" and
  "Inbound replay failed".

**What to do.** Assign the Kern API Issue Resolver set to the people who resolve issues; neither set is assigned to anyone by
the install. If someone could press Retry before the upgrade only because of their profile, and is refused after it, assign
them the Kern API Issue Resolver or Kern Administrator set.

**Read more.** [Retry on an API issue needs the Retry API Issue permission](#retry-on-an-api-issue-needs-the-retry-api-issue-permission)
for the permission, and the Web Services guide's [Failures and retries](../docs/Web%20Services%20-%20Guide.md#failures-and-retries)
section for the job.

## Ready for Winter '27

**Who it's for:** everyone whose org is moving to Winter '27, and every developer who raises their own classes to API 68.0.

1.8 is the KernDX release for Winter '27. It is built on Salesforce API 68.0, up from API 67.0 (Summer '26), and it was tested on
the Winter '27 preview, as a fresh install and as an upgrade from 1.7.0-13. You do not need to change anything for the upgrade
itself. This section says what 1.8 changed for Winter '27, then what the framework does about each Winter '27 change that
touches code you write beside it.

**What 1.8 changes for Winter '27**

- **Every metadata file is on API 68.0.** Every class, trigger and other metadata file in the package moved from API 67.0 to
  API 68.0, so the framework compiles and runs under Winter '27's rules. The production build is compiled from the same source
  as the preview build the release tests ran on. See [How this release was tested](#how-this-release-was-tested).
- **Apex integration tests reach your real endpoints.** Inside an `@IntegrationTest` (a Developer Preview in Winter '27), a
  callout through `kern.UTIL_HttpClient` or a `kern.API_Outbound` service now reaches the endpoint, unless you registered a mock
  through `kern.API_MockFactory`. A unit test is unchanged. Details are under
  [A callout through the framework reaches the real endpoint inside an Apex integration
  test](#a-callout-through-the-framework-reaches-the-real-endpoint-inside-an-apex-integration-test).
- **The release tests run with Profile Filtering on.** Every release test pass now keeps the Enable Profile Filtering release
  update turned on, the way Winter '27 orgs run.

**Winter '27 platform changes, and what the framework does about each**

- **A flow started from a trigger action can be held to the user's own access.** A flow the framework starts from a trigger
  action runs in system context, as any flow started from automation does, so it can change records the user could not. On
  API 68.0, Flow Builder's User Context–Enforces User Permissions option makes a screen flow or an autolaunched flow run with
  the running user's access, whatever started it. Choose it when the flow must never do more than the user could do on screen.
  The Triggers guide's
  [Which user's permissions does the flow run with?](../docs/Triggers%20-%20Guide.md#which-users-permissions-does-the-flow-run-with)
  explains the choice.
- **Profile Filtering hides other users' profiles.** With the Enable Profile Filtering release update, which Winter '27
  enforces, a user without View All Profiles sees only their own profile. The framework reads profiles in system mode, so
  profile-based feature flags and its user and profile selectors see what they saw before. Your own user-mode Apex that reads
  another user's profile name gets no row or a null, silently: to read it whatever the user may see, use `kern.SEL_User` or
  read it in system mode. The Security guide has the details.
- **A state manager can fetch fresh data on request.** In a Lightning web component, call `refresh()` on one of the platform's
  state managers for list or query data, such as related list records, once its status is `loaded`, and it fetches the latest
  data without reloading the page. The framework's cacheable Apex calls are unchanged and still refresh the way the LWC guide
  describes.
- **The record index fits Winter '27's heap limits.** The Utilities guide measures `kern.MAP_SObject`, the framework's
  in-memory record index, against the heap (memory) limits of 10 MB for a synchronous transaction and 25 MB for an asynchronous
  one: even its worst case, about 6 MB for 10,000 records indexed on three fields, fits a synchronous transaction.
- **The log subscriber's settings can be edited in Setup.** The settings that control how the framework's log trigger receives
  log events, such as the most events it is handed in one run, can now be seen and edited in Setup, in Event Studio, labelled
  Apex Trigger Details (in Developer, Enterprise, Performance and Unlimited edition orgs). The framework ships no such record,
  so your org's platform defaults apply until you add one. The Logging guide says which settings these are.

**Also new on the platform, with no framework change.** A Named Credential can reach a server behind your own certificate
authority once you upload its root certificate to your org's trust store (not in every org), so a call through
`kern.UTIL_HttpClient` to an internal service needs no publicly trusted certificate; the Web Services guide has the details.
ApexGuru now also reports duplicated code; it judges how your code behaves in the org and the KernDX rules judge whether it
follows the framework's conventions, so run both when you have both, as the Code Scanning guide explains.

**What to do.** Nothing for the upgrade itself. Before you raise your own classes to API 68.0, look for inline queries on
`Profile` or on other users' profile names. If you use Apex integration tests, register a mock through `kern.API_MockFactory`
wherever you do not want the real endpoint called.

**Read more.** One more guide note came with this release, though it is not tied to Winter '27: the Objects & Metadata guide
says to give a field you add to a framework object a name the framework does not use on that object, because a query the
framework runs for you reads the framework's own field of that name and never yours.

---

## Changes that can affect code you have written

**Who it's for:** developers and admins planning the upgrade.

Read the ones that touch code or configuration you own. Each change under the headings below is listed again under
[Upgrading & compatibility](#upgrading--compatibility), and the [Behaviour changes at a glance](#behaviour-changes-at-a-glance) table groups them by area.
The two short platform notes just below are not framework changes, so they are not listed there.

**If your own classes are on API 66.0 or earlier**, raising them to 68.0 also brings the Summer '26 change: a query or DML
statement written straight in Apex checks the running user's object and field permissions unless it says otherwise. Code that
goes through KernDX's query and DML builders already works this way.

**Sharing recalculation can run in the background.** A Salesforce release update, available since Spring '26 and enforced in
Spring '27, lets the platform build new share records after your transaction ends. The framework's own share records are
unaffected; the Security guide's [Share Object Management](../docs/Security%20-%20Guide.md#share-object-management) says what to check in
your own code and tests.

### `withoutSecurity()` now also bypasses record sharing

If you call `withoutSecurity()` expecting every row, you now get every row; if you relied on it keeping the calling class's sharing, it may now return rows the running
user cannot see. `kern.QRY_Builder`'s `withoutSecurity()` now waives object and field permission checks and also record sharing in one call, matching its name. Until now it
set aside object and field checks but left record sharing following the calling class, and its documentation said so; the guides now describe the new meaning.

| You wrote | You wanted | From 1.8 |
|---|---|---|
| `.withoutSecurity()` | every row, no checks at all | nothing to change: from 1.8 that is what it does |
| `.withoutSecurity()` | object and field checks off, but the calling class's sharing kept | switch to `.withSystemMode()` |

Two further corrections ship with it: `toQueryLocator()` now honours `bypassSharing()` for batch work, and the query cache is keyed by sharing setting and, where sharing
applies, by user; paged and cursor reads are never cached. That last point also fixes a cached paged read that served page 1 for every page number.

### `toCursor()` now honours the sharing setting

A cursor from `toCursor()` is now opened under the builder's sharing setting, so `bypassSharing()` genuinely reaches every row on every later fetch, in the same transaction
or a later one. Until now the cursor followed the sharing of the code that created it and silently ignored the builder's setting, while the bypass audit still recorded a
bypass as taken; both halves are now truthful. Registered mock exceptions also reach `toCursor()` in tests now, like every other read.

| You wrote | You saw until now | From 1.8 |
|---|---|---|
| `.bypassSharing().toCursor()` | only rows the running user could see, plus a bypass audit entry | every row, and the audit entry is true |
| `.toCursor()` with no sharing call | rows per the creating code's sharing | unchanged |

### A cached read must state its sharing setting

`withCache(ttl)` no longer caches a read that leaves the sharing setting to the calling class, because the cache cannot tell one calling class's sharing from another's: the
same user could otherwise be served rows cached under a different class's sharing. Reads that state `.withSharing()` or `.bypassSharing()` cache exactly as before. This
applies to system-mode reads; a read in user mode, the default, is covered under
[A user-mode `withCache` read is now cached for the transaction](#a-user-mode-withcache-read-is-now-cached-for-the-transaction).

| You wrote | Until now | From 1.8 |
|---|---|---|
| `.withSystemMode().withCache(300)` with `.withSharing()` or `.bypassSharing()` | cached | unchanged: cached |
| `.withSystemMode().withCache(300)` with no sharing call | cached, keyed per user | not cached; add the sharing call to cache again |

**A cached read with sharing bypassed is kept per user when its rows or values depend on the user.** A read with `.bypassSharing()` is cached once
for the whole org, which is right when every user would get the same rows. Some reads differ by user even with sharing bypassed: a scope
other than everything (`usingScope(kern.QRY_Builder.Scope.MINE)` and the like), the SOQL functions `toLabel`, `FORMAT`,
`convertCurrency` or `convertTimezone`, or a relative date such as `TODAY`, `LAST_N_DAYS:7` or `THIS_FISCAL_QUARTER`, which is read in the user's time zone.
Until now one user's cached result for such a read could be served to another user until it expired. From 1.8 those reads are cached per
user; every other bypassed read keeps its single shared entry. A value the platform translates with nothing in the query to say so, such as
a record type's name, is not detected: cache that read with `.withSharing()`, or select it through `toLabel`.

### A user-mode `withCache` read is now cached for the transaction

A repeated user-mode read that asks for `withCache` now saves its query, and a repeat that follows a write the framework does not make can return the rows from before
that write. `withCache(ttl)` on a user-mode read, the default mode, used to be ignored: the read went to the database every time. From 1.8 the rows are kept in memory
for the rest of the transaction, so a repeat of the same read costs no query. They never reach Platform Cache, because a user-mode read's rows depend on the running
user's permissions and sharing. In the same way, a system-mode `withCache(ttl)` read in an org whose Platform Cache keeps nothing is now kept in memory for the
transaction instead of querying again each time.

| You wrote | Until now | From 1.8 |
|---|---|---|
| `.withCache(300)` on a user-mode read | not cached: every read queried | kept in memory for the transaction |
| `.withSystemMode().withSharing().withCache(300)`, Platform Cache allocated | kept in Platform Cache | unchanged |
| the same, with no Platform Cache space to keep it | not cached: every read queried | kept in memory for the transaction |

What can change for you is a read that follows a write in the same transaction. A write through `kern.DML_Builder` empties the cache before the save starts and again
when it ends, so the read sees it. A write the framework does not make (a Flow, a plain `insert` or `update` statement, another package) is not seen, so a repeat of the
same read returns the rows from before it.

**Upgrade check.** Search your code for `withCache(` on user-mode reads. Where the same object is written outside `DML_Builder` and read back through the same call in
one transaction, change the call to `withoutCache()` or remove it.

### A feature flag reads its setting or metadata target once per transaction

Until now, a feature flag strategy whose target is a hierarchical custom setting, a list custom setting or a custom metadata record ran a query for that target on
every `isEnabled(...)` call. From 1.8 the rows are read once and kept in memory for the rest of the transaction, so a flag checked for every record of a selection
costs one query. Retry Selected on the API Issues list checks the Disable All APIs flag for each outbound issue it is given, so a selection of 100 outbound issues
used to run out of queries. It no longer does: a selection of 450 issues now goes through. Every other strategy type costs the same as before: a profile, public
group, permission set or local custom permission strategy still queries on every check, as the cost table in the Feature Flags guide shows. This applies to every
flag of those three target types, your own as well as the packaged ones.

| You wrote | Until now | From 1.8 |
|---|---|---|
| `kern.UTIL_FeatureFlag.isEnabled('My_Flag')` twice in one transaction, setting or metadata target | two queries | one query |
| check the flag, flip its setting through `kern.DML_Builder`, check again | the new value | the new value (unchanged) |
| check the flag, flip its setting with a plain `insert` or `update`, check again | the new value | the value from before the write |

**Upgrade check.** Search your Apex and tests for a flag check that follows a plain DML statement on the flag's setting in the same transaction. Write that setting
through `kern.DML_Builder`, which clears the kept rows before and after the save, or move the second check to its own transaction.

### The Platform Cache health checks say what happens to query caching

The two checks now tell you what query caching loses without an allocation, so you can decide whether to allocate one. The Org Cache and Session Cache checks keep
their results: a missing Org Cache allocation still fails, and a missing Session Cache allocation still warns. Their detail
text now adds what happens to query caching without the allocation. Without Org Cache, cached queries still work within a single request but, unless Session Cache
keeps them, are read again from the database on every new request. Without Session Cache, queries a selector asks to keep for the session are kept for the current
request only. If a runbook or a check of your own matches that text exactly, update it.

### Saving several cache values at once saves none when one is too large

A `false` from `putAll` now means the cache holds none of that call's values, never a part of them. `putAll` on a `kern.UTIL_Cache` store now saves none of its
values when one value is too large to cache. Until now the values placed before the large
one were already saved, even though the call returned `false`.

| You wrote | Until now | From 1.8 |
|---|---|---|
| `putAll(values)` where one value is too large to cache | `false`, and the values before it stayed in the cache | `false`, and none of that call's values are in the cache |

Store the large value on its own, or make it smaller.

### Hand-set credential headers are not stored with the call record

A token your code sets by hand no longer sits in clear text where anyone who can read the call record can copy it. When your code sets an authorisation header
itself (for example `.header('Authorization', 'Bearer ' + token)`), the value is now stored redacted with the call record
instead of in clear text. The call still sends the real value, so nothing changes for the send itself. What changes is what happens afterwards: a retry that runs in a later
transaction has no credential to send, so instead of sending a request that would only fail to authenticate, the call is parked and the API issue says why. The
issue's message reads: "This call set the {0} header itself, so its value is not stored with the call record and a retry cannot send it. Store the credential in a
Named Credential or External Credential, then run the call again." (`{0}` is the header's name.)

| Scenario | Until now | From 1.8 |
|---|---|---|
| Hand-set credential header, first send | sends | sends (unchanged) |
| Retries inside the same transaction | send | send (unchanged) |
| Scheduled retry of a failed call | replayed the stored credential | not scheduled; the issue says why |
| Retry from the issue list | replayed the stored credential | stops before sending, with the same message |
| Credential in a Named or External Credential (merge field included) | works | works (unchanged, and now the documented path) |

The fix: move the credential to a Named Credential or External Credential, then run the call again.

One more thing to expect after upgrading: an API issue opened before 1.8 for a call with a hand-set credential header will not be matched by the same failure once you are on
1.8, because the stored request now differs, so the recurrence opens a new issue and you close the old one by hand.

### `send()` never returns null

Code that calls another system now always gets a response back, so it never has to guard against a missing one. `kern.UTIL_HttpClient`'s `send()` no longer
returns null. If your code crashed when it dereferenced that null, it was never relying on the null as a signal, so nothing you built
on purpose changes.

What is worth checking: a status code of `0` means no response came back. That happens in two ways: the call was refused before it ever left your org (a credential problem,
an open circuit breaker, another configuration refusal), or it did go out and nothing came back (a timeout, a transport failure). It is not a success, and it is not a
signal to try the call again yourself: don't build retry logic that keys off it. To see why a call reads `0`, look at `response.getStatus()` first, then the handler's result
(returned from `invoke()`) or the call record in the **API Calls** tab, where the reason is recorded alongside the rest of that call's history.

This also closes the one outbound failure that used to leave no record at all: a running user without access to an External Credential's principal. The call now fails with
a recorded reason instead of a null the caller could not survive.

### A key you give `withIdempotencyKey()` is sent when a handler makes the call

A key you set on a handler call now reaches the external system, so it can spot a repeated request, and the framework treats the call as safe to retry.
`kern.UTIL_HttpClient.useHandler(...).withIdempotencyKey(key).invoke()` never sent the key: the handler sent an `Idempotency-Key` header only when its own API setting had
Idempotency Enabled, while the same builder call on `send()` always sent it. The key is now sent and recorded on the call on both paths, whatever the setting says. Two
things change for a call you keyed this way: the external system receives the header, and a POST or PATCH that gets no response or a 500, 502 or 504 is now retried as
safe to repeat, where without the key it ends Failed. If your handler sets its own `Idempotency-Key` in a `createRequest()` override after calling
`super.createRequest()`, its key is the one sent, as before.

### `withCircuitBreaker(name)` uses the breaker you name

You can now choose which calls share a circuit breaker by the name you give it. `kern.UTIL_HttpClient`'s `withCircuitBreaker(name)` now uses the breaker you
name: calls that give the same name share one breaker whatever credential
or handler they use, and calls that give different names keep separate breakers on one credential. Until now the name was
ignored and the call used the credential's (or the handler's) own breaker, so a call that passes a name now keeps its own failure
count and cool-off, and its open-circuit error line names that breaker. Calls that pass no name are unchanged, including the
scheduled retries of calls recorded before the upgrade.

### Only the "try later" statuses are retried by default

A call the external system refused outright is no longer sent again and again, failing the same way each time. An outbound call whose external system responds
with an error status is now retried only for the statuses that mean "try later": 408, 425, 429, 500, 502, 503 and
504. Every other status ends the call `Failed` at once, with its issue. Until now the scheduled retry ran for any failed status while retries remained, so a 400 or a
404 was sent again up to Max Retry Count times and failed the same way each time.

| The external system responds with | Until now | From 1.8 |
|---|---|---|
| 408, 425, 429 or 503 | retried | retried, whatever the method |
| 500, 502 or 504 | retried | retried when the request is safe to repeat; see the next heading |
| any other 3xx, 4xx or 5xx | retried | `Failed` at once |

If your external system uses another status to mean "try later", add it in your handler's `getRetryableStatusCodes()` override; a status you add yourself is retried
whatever the method.

Calls you make with `kern.UTIL_HttpClient` change in two more ways:

- **The statuses you name for an immediate re-send now also limit the scheduled retry.** A status you did not name in `retryOn(...)` ends the call
  `Failed`, where until now the call was scheduled for a later retry once you gave a backoff. A status you name is re-sent at once, as before (425
  and 429 included), and retried later on a schedule.
- **When you name no statuses, the ones re-sent at once change.** Without `retryOn(...)`, until now a 500, 502, 503 or 504
  was re-sent within the same call. From 1.8 a 408 or 503 is, and a 500, 502 or 504 only when the request is safe to repeat;
  a 425 or 429 waits for the scheduled retry.

### A server error on a request that is not safe to repeat is not sent again

A 500, 502 or 504 can arrive after the external system has already done the work. So when a POST or PATCH that carried no `Idempotency-Key` gets one of those three, the
call now ends `Failed`, its issue has **External System May Have Acted** ticked, and the call and the issue carry a line that begins: "{service} responded with status
{status} to a request that is not safe to repeat. The external system may have processed it, so it was not sent again." Until now the call was retried.

A GET, PUT or DELETE, a call with an idempotency key, and a call whose setting has Idempotency Enabled are retried after a 500, 502 or 504 as before, and 408, 425, 429
and 503 are still retried for every method. A `kern.UTIL_HttpClient` call follows the same rule when it re-sends at once.

**To keep retrying such a call**, give it an idempotency key (`withIdempotencyKey(...)`, or Idempotency Enabled on its setting) if the external system honours the header.
On a `kern.UTIL_HttpClient` call or an async chain's API step, naming the status in `retryOn(...)` is your choice to send it again: it is re-sent at once and retried
later, whatever the method, and its issue still says the external system may have acted. Name 500, 502 or 504 there only when sending the request twice is safe. Adding
one of the three in `getRetryableStatusCodes()` does not change this rule.

### A failure after a successful response is not sent again

When `parseResponse()` or `onSuccess()` throws after the external system responded with success, the external system has already acted. The call now ends `Failed` with
the success status kept on the call record, and its issue has **External System May Have Acted** ticked. Until now the request was sent again, up to Max Retry Count
times, so the external system could act on it again each time. A type you list in `getRetryableExceptionTypes()` is retried after a success only when the request is
safe to repeat (a GET, PUT or DELETE, or a request that carried an `Idempotency-Key`).

### A call that fails in your own code reads Failed, not Retry

The status of such a call now says what really happened to it. When your handler's own code throws while the request is being prepared, before anything is sent (for
example in a `createRequest()` override), and the exception is not a type you list in `getRetryableExceptionTypes()`, the call's Status is now `Failed`, where it used
to read `Retry`. Nothing was sent and nothing would ever have retried it, so `Failed` is what it always was in effect. A Flow, report, list view or check of your own
that looks for `Retry` to find these calls should look for `Failed`. A failure after the external system responded is covered under
[A failure after a successful response is not sent again](#a-failure-after-a-successful-response-is-not-sent-again).

### An open circuit schedules a call with retry budget left

A short outage no longer ends calls that could have gone through once the other system was back. On a service whose circuit breaker is turned on, a call refused
by an open circuit while its setting allows retries now waits: it is scheduled at `Retry` with its next
retry at the end of the breaker's cool-off, and the wait spends one of its retries. Once its retries are used up it ends `Failed` with an issue. `Aborted` stays for a call
whose setting allows no retries, and for every other refusal before sending. Until now every call an open circuit refused ended `Aborted`.

A callout that got no response now also counts as a failure towards opening the circuit, as a 5xx status already did. A service whose circuit breaker is off is not
affected.

### Your commit hooks run once per attempt when a row lock is retried

A successful call's records now get a second try at saving when a row lock refuses the first. A handler saves the records it registered in its own commit after the call.
That commit now tries once more when the platform refuses it for a row lock; the callout
is never sent again by it. If your handler overrides the commit hooks, each override runs once for each attempt: `onDMLStarting()`, `onDMLFinished()` and
`onCommitWorkFinishing()` on an outbound handler, and on an inbound handler `onCommitWorkStarting()` as well. An override that counts, sends or writes something outside
the commit should expect to run twice when a lock is retried.

### Three messages that stop an outbound call before it is sent now come from labels

Three messages your users can see on a refused call can now be translated. When the framework refuses to send a call because the triggering record ID is missing or not
valid, a required parameter is missing or blank, or the service has no API setting record, the message on the call's error line now comes from a Custom Label
(`OutboundCall_TriggeringRecordIdRequired`, `OutboundCall_RequiredParametersMissing`, `OutboundCall_ApiSettingNotFound`) and its wording changed. Your users can
translate them. The old texts were "A valid Triggering Object Id is required.", "All required parameters {0} were not provided or were provided blank" and "API setting
record not found for service "{0}"". The new texts are "A valid triggering record Id is required.", "The required parameters {0} were not provided or were
blank." and "No API setting record was found for the service {0}." If your code or tests match them, read the label instead.

### Retry on an API issue needs the Retry API Issue permission

You now decide who can run a failed call again. Until now anyone who could open an API issue and run its **Retry** action could run the call again. From 1.8 the user
also needs the new **Retry API Issue** custom permission. **Retry Selected** on the API Issues list checks it the same way. A user without it is told: "You need the
Retry API Issue permission to run this call again. Ask your administrator for the Kern API Issue Resolver permission set." Retry Selected pressed without it queues
nothing, and its background job checks again when it runs, as the user who started it.

Two permission sets grant it: the new **Kern API Issue Resolver** set, which also gives read access to API issues and every API call, the API Issues tab and the Kern app,
and the **Kern Administrator** set. Both are assigned to nobody by the install.

**Retry Selected also needs the Run Flows user permission.** The list action runs a flow, and Lightning offers a flow action only to a user who holds **Run Flows**.
A managed package cannot carry user permissions in its permission sets, so neither Kern set grants it: give it to your resolvers through a permission set or
profile of your own. A user without it sees no Retry Selected button once rows are selected; Retry on an issue's record page does not need it. Administrators with
Modify All Data see the action either way.

| Your users get Retry through | What to do |
|---|---|
| The Kern Administrator permission set | nothing: the set grants the permission |
| A profile alone, such as System Administrator | if Retry is refused after the upgrade, assign the Kern API Issue Resolver or Kern Administrator set |
| A permission set you built that grants access to the Apex class `kern.CTRL_RetryApiIssue` (the name Setup shows under Apex Class Access) | add the Retry API Issue custom permission to it, or assign the Kern API Issue Resolver set |

A fresh install for admins only gives the permission to the System Administrator profile too. An upgrade is not guaranteed to add a new permission to a profile, which
is why a user who works through a profile alone may be refused after upgrading.

### API issues and log entries are private on a new install

An API issue or a log entry can hold what a request carried; on a new install, only the people who need to see one can. `ApiIssue__c` and `LogEntry__c` now ship
with a **Private** sharing default, like `ApiCall__c` and `AsyncChainExecution__c`. On a new install, a person sees an API
issue or a log entry only when they own it, sit above the owner in the role hierarchy, or hold View All Records on the object. You need no sharing rule or group:

- The new **Kern API Issue Resolver** permission set carries View All Records on API issues and API calls, but no edit or delete access. A resolver sees every
  issue, and Retry, the resolve action and **Retry Selected** mark an issue resolved for them, whoever owns it, after checking the Retry API Issue permission.
- The **Kern Administrator** permission set includes View All Records, so administrators see every record.

With **Resolve Issues** on, a later successful call for the same request still resolves every user's open issue for that request.

**For developers:** `kern.SEL_ApiIssue.findByFailedApiCall` returns every user's open issues for the request, whatever your org's sharing default. That is what it
returned in effect before, while API issues were Public Read/Write; on an org where they are Private it still does. To ask, your code must already hold
the record Id, the service name and the request parameters hash, so it is asking about a request it knows. If you show the returned issues to a person,
check first that they may see them.

An upgrade never changes your org's sharing default, so an upgraded org keeps **Public Read/Write** on both objects until you change it. The resolver set arrives
with the upgrade, View All Records included, either way. To move to Private, open **Sharing Settings** and, under **Organization-Wide Defaults**, set **API Issue** and
**Log Entry** to **Private**.

**Only a user the Bypass API Record Delete Guard flag is on for can delete an API call or an API issue (out of the box, a holder
of Delete API Records).** Deleting either now needs the new **Delete API Records** permission, which the Kern Administrator
permission set grants. Anyone else who tries, a resolver included, gets a message that says so and nothing is deleted. If you schedule a purge of old API calls or
API issues, schedule it as a person who holds the permission, for example an administrator with the Kern Administrator set: a purge scheduled by anyone else
deletes nothing and writes one warning with the same message to the log. If your own Apex deletes API calls
or API issues, it now fails with that same message whenever it runs as a user without the Delete API Records permission.

One new feature flag, `BypassApiRecordDeleteGuard`, makes that decision for every way in: a record page, a flow, your own Apex and the scheduled purge
alike. A built-in rule turns it on for every holder of the Delete API Records permission. To let more people delete, add a `FeatureFlagStrategy__mdt`
record for a profile, a permission set or a public group, or one user through a hierarchical custom setting; to let everyone delete, set **Result On No
Match** on the flag record to true (**Is Enabled By Default** has no effect here, because the flag always has the built-in rule). If you deactivate the
flag record, nobody can delete an API call or an API issue, your administrators included, and the Data Retention check on the Health Check page warns
you.

The Log Console reads every log entry whatever the default, as it always has: a log entry is owned by the background process that saved it, and the console is open
only to the Kern Administrator permission set, which already includes View All on log entries. The Chain Monitor's log stream reads the same way. See
[Who can see the framework's own records?](../docs/Security%20-%20Guide.md#who-can-see-the-frameworks-own-records) in the Security Guide.

### A handler's canned answer no longer stands in for a real call outside a unit test

A handler with a canned answer now reaches the other system in production and sandboxes, where it used to answer itself and never make the call. A handler that
declares a `defaultMockBody` and is run through `kern.UTIL_HttpClient.useHandler(...)` with no credential named on the builder answered its canned body outside
tests too: in production and in a sandbox the call never left the org and the call record was marked as mocked, even when the handler's own metadata record named a
credential or, for a handler built on `kern.API_CallCurrentOrg`, when no credential is needed at all. The canned answer is now used only inside a unit test. Outside one, the
handler makes its real call, with the credential named on the builder, else the one on its metadata record, else its own endpoint. An asynchronous chain's HTTP step runs
through the same path and changes the same way. Unit tests are unchanged.

### A callout through the framework reaches the real endpoint inside an Apex integration test

An Apex integration test that calls through the framework now tests the real endpoint, as it is meant to. Apex integration tests (a Developer Preview in Winter '27,
`@IntegrationTest`) may call real endpoints. Until now, a callout made through `kern.UTIL_HttpClient` or a `kern.API_Outbound` service from inside one answered a mock
body, as it does in a unit test (the framework's built-in mock body for a plain client call, or your service's `defaultMockBody` for a service), so the test never
reached the endpoint. It now reaches the endpoint unless you registered a mock through `kern.API_MockFactory`, which still answers instead. A mock configured in metadata
alone does not stand in there: register one in the test if you want it to. Unit tests are unchanged. The feature is a preview, so its rules may still change before it is
generally available.

This is one of the Winter '27 changes gathered under [Ready for Winter '27](#ready-for-winter-27).

### Every chain run has a tracking ID of its own

What this adds is described under [Follow one action across every chain it launched](#follow-one-action-across-every-chain-it-launched). The one change to look for in your
own code: **the first chain in an action no longer has the action's ID in its Correlation ID field.** Each run's Correlation ID is now its own. Code that finds a chain
run by `kern__CorrelationId__c = <the action's ID>` should match on **Launched Under** (`kern__LaunchCorrelationId__c`) or **Root Correlation ID**
(`kern__RootCorrelationId__c`) instead. Log entries written before this release have no root correlation ID and are still found by their correlation ID.

### The typed chain status reports an elapsed time the way the Chain Monitor does

Your code now reads the same elapsed time for a chain run as the Chain Monitor shows, including for a run that is stalled or ended without a stored duration.
`kern.UTIL_AsyncChain.getChainStatus` and `getChainStatuses` fill `durationMs` from the same Elapsed (ms) value the Chain Monitor shows, so there is one definition of elapsed
time. That makes the released description of `durationMs`, which has always said the live value matches the Chain Monitor, true again. The untyped `getStatus(Id)` map has
never carried a duration and is unchanged.

| Kind of run | Until now | From 1.8 |
|---|---|---|
| Completed, Failed or Aborted, with a stored duration | the stored duration | unchanged |
| Running, with no end | a live count in milliseconds | a live value in milliseconds that moves in whole-second steps, as the screen shows it |
| Stalled, with no end | null | a live value |
| Completed, Failed or Aborted, with no stored duration | null | the time between its start and its end |
| A mocked Running row with no stored duration, in your test | a live count | null (a mocked row has no clock) |

A row you register yourself through `kern.TST_Mock` carries no formula value, so the status falls back to its stored duration, and a test written against an earlier
version that asserts the stored duration keeps passing.

### A stalled chain runs a step again only when that is safe

A step's work, such as a callout that creates an order, no longer happens twice because its chain stalled. The watchdog (the scheduled job that revives stalled
chains) used to restart a stalled chain at the first step with no saved result. When that step had already
started, for example it had made its callout and the chain stalled before the result was saved, the restart ran it a second time, so its work could happen twice. From
1.8 the watchdog runs a step again only when the step never started, or when it declares itself safe to repeat (`isIdempotent()` returns `true`). Otherwise the chain
ends `Failed` instead, and the step is not run again. A step counts as started once the framework has handed it to the platform
to run, so a step still waiting in the queue counts as started.

| The step the chain stalled on | Until now | From 1.8 |
|---|---|---|
| Never started | run again | run again (unchanged) |
| Started, and `isIdempotent()` returns `true` | run again | run again (unchanged) |
| Started, with no such declaration | run again | the chain ends `Failed` and the step is not run again |

A chain that ends this way carries this message, which the Chain Monitor shows and your `onError` handler, if the chain has one, is told about: "Recovery stopped at
step {name}. The step had started when the chain stalled and no result was saved, so it may already have done its work. It was not run again. Check whether its work
landed, then start a replacement." The **Clear stalled** button in the Chain Monitor follows the same rule.

One step that never ran can end the chain this way: a step whose queued job waited longer than the watchdog's stale threshold before the platform could run it. The
watchdog used to start it again; it now ends the chain `Failed` with the same message. If your org's queue is slow, raise the watchdog's `StaleThresholdMinutes`
(30 by default) above the longest wait you see.

Chains running when you upgrade keep the earlier recovery for the step they are on.

**Upgrade check.** Look through your chain steps, and on every step whose work is safe to run twice, override `isIdempotent()` to return `true`, so the watchdog keeps
recovering it automatically. The same declaration lets an operator retry the step from the Chain Monitor after it fails.

**API steps declare this for you.** An API step whose request is safe to send twice counts as safe to repeat without any code from you: the watchdog runs it again
after a stall, and an operator can retry it from the Chain Monitor after it fails. A request counts as safe when the handler's method is GET, PUT or DELETE, or when
the service's API setting has Idempotency Enabled, so each attempt carries an Idempotency-Key worked out from the request (a request whose body changes between
attempts gets a different key). An API step whose request is not safe, a POST or PATCH with no key, still ends the chain `Failed` with the message that names the
step. The step decides when the chain is built, so it cannot see a handler whose `createRequest()` override removes the Idempotency-Key header: for such a handler,
do not rely on Idempotency Enabled. Building a chain now creates each API step's handler once, so its `configure()` runs and its API setting is read at build time;
a handler that cannot be created or read counts as not safe to repeat.

### A chain run that has ended stays ended

A run that has finished now keeps the status it finished with, so the Chain Monitor no longer shows a finished run as Stalled with nothing left to move it.

- A chain run that has ended stays ended. If its completion or error handler could not be started, the run keeps its Completed or Failed status and its end time, and its
  message names the handler that did not run. The handler is not run later. There are two signs. The Log Console holds an ERROR entry that names the chain, its status
  and the handler, and the run's message carries the note.
- A run the watchdog starts again no longer shows the earlier stall as its failure category.
- A run that completed and then had its completion handler fail now shows the Step Exception failure category. A run that failed keeps its own failure category when its
  error handler fails too.
- A run's end time is the moment it ended. A completion or error handler that fails afterwards no longer moves it.
- The framework refuses a direct edit that moves a chain run from an ended status back to a live one, or into a status the run cannot reach from where it is, and says
  why.
- If the Chain Monitor shows a run as Stalled with an end time, that run ended on an earlier version and nothing will start it again. The script below sets each such run
  back to the status it really ended with; you can also leave the rows as a record or delete them.

**How the script decides.** It reads each run's step log. A run whose steps all succeeded is set to Completed and its failure category is cleared. Any other run is set to
Failed with the Step Exception failure category. Either way, the script clears the run's Active Deduplication Key. It keeps each run's end time and adds "Repaired on"
and the date to the start of its message, so the earlier text stays readable. A run whose step log cannot be read is not changed. A repaired run is no longer Stalled, so
the script leaves it alone if you run it again.

To run it, sign in as a user who holds the Kern Administrator permission set and save the script below as `repair-ended-chain-runs.apex`. Then open a terminal in the
folder you saved it in and run the command below, or paste the script into the Developer Console's Execute Anonymous window. The script writes one line per run to the
debug log (in the Developer Console, tick Debug Only to see just those lines):

- `Repaired`, the run's ID and the status it was given, for each run it changed.
- `Not repaired`, the run's ID and the reason, for each run the save refused.
- `Skipped`, the run's ID and the reason, for each run whose step log could not be read.

The command, the same in Command Prompt on Windows and in a Mac terminal (`YourOrgAlias` is the alias you gave your org when you logged in):

```shell
sf apex run --file repair-ended-chain-runs.apex -o YourOrgAlias
```

The script:

```apex
// Sets each chain run that an earlier version left at Stalled with an end time back to the status it really ended with.
// A run whose steps all succeeded becomes Completed; any other run becomes Failed. The end time is kept.
List<kern__AsyncChainExecution__c> endedRuns = [SELECT Id, kern__StepLog__c, kern__ErrorMessage__c FROM kern__AsyncChainExecution__c WHERE kern__Status__c = 'Stalled' AND kern__CompletedAt__c != null];
Integer messageLength = Schema.SObjectType.kern__AsyncChainExecution__c.fields.kern__ErrorMessage__c.getLength();
List<kern__AsyncChainExecution__c> repairs = new List<kern__AsyncChainExecution__c>();
for(kern__AsyncChainExecution__c run : endedRuns)
{
    List<Map<String, Object>> entries = new List<Map<String, Object>>();
    try
    {
        for(Object item : (List<Object>)JSON.deserializeUntyped(run.kern__StepLog__c))
        {
            entries.add((Map<String, Object>)item);
        }
    }
    catch(Exception error)
    {
        System.debug(LoggingLevel.ERROR, 'Skipped ' + run.Id + ': its step log could not be read (' + error.getMessage() + ')');
        continue;
    }
    Boolean allStepsSucceeded = true;
    for(Map<String, Object> entry : entries)
    {
        Boolean isHandler = entry.get('isErrorHandler') == true || entry.get('isCompletionHandler') == true;
        if(!isHandler && entry.get('success') != true)
        {
            allStepsSucceeded = false;
        }
    }
    kern__AsyncChainExecution__c repair = new kern__AsyncChainExecution__c(Id = run.Id);
    repair.kern__Status__c = allStepsSucceeded ? 'Completed' : 'Failed';
    repair.kern__FailureCategory__c = allStepsSucceeded ? null : 'StepException';
    repair.kern__ActiveDeduplicationKey__c = null;
    String earlierMessage = run.kern__ErrorMessage__c == null ? '' : run.kern__ErrorMessage__c;
    repair.kern__ErrorMessage__c = ('Repaired on ' + Date.today().format() + ': ' + earlierMessage).left(messageLength);
    repairs.add(repair);
}
List<Database.SaveResult> saveResults = Database.update(repairs, false);
for(Integer index = 0; index < saveResults.size(); index++)
{
    if(saveResults[index].isSuccess())
    {
        System.debug(LoggingLevel.ERROR, 'Repaired ' + repairs[index].Id + ': ' + repairs[index].kern__Status__c);
    }
    else
    {
        System.debug(LoggingLevel.ERROR, 'Not repaired ' + repairs[index].Id + ': ' + saveResults[index].getErrors()[0].getMessage());
    }
}
```

### An API step stops retrying when the external system may have acted

An API step whose request may already have reached the external system is no longer sent again on its own, so a POST cannot make that system act twice. An async
chain's API step with `withRetry(...)` used to run again after every failure. From 1.8, when the step's request is a POST or PATCH with no idempotency key, the
step is not run again after a callout that got no response, after a 500, 502 or 504, or after the external system accepted the request and the step then failed in your
org. The step fails for good instead, and its message starts with the reason, so the Chain Monitor shows why. A status you name in the step's own `retryOn(...)` is still
retried, as your choice. A request that is safe to repeat (a GET, PUT or DELETE, or one that carried an `Idempotency-Key`) retries as before, and every other failure the
chain retried until now is still retried, a 400 on a GET included.

A handler that throws `kern.UTIL_Exceptions.PermanentFailureException` now fails its API step at once, whatever the method or key.

### A hierarchy deeper than its depth limit stops with an error

A hierarchy too deep to search now stops with an error instead of quietly leaving records out of the result. `kern.SEL_Hierarchy` searches at most 20 levels by
default. `propagateToDescendants`, and `calculateUltimateParents` with descendants included, used to stop at that
limit and silently leave the deeper records out of their result. They now throw an error instead. `findAllDescendants` changes the other way: it used to throw even
for a hierarchy exactly as deep as the limit, and now succeeds. All three now throw only when a hierarchy goes deeper than the limit. If yours does, raise the limit with
`withMaxDepth`, for example `kern.SEL_Hierarchy.forField(Account.ParentId).withMaxDepth(40)`.

### Permission set assignments from one call save together

`kern.TST_Factory.createPermissionSetAssignments` saves all the assignments of one call in a single all-or-none statement, in tests and out, so a failing assignment leaves
none of that call's assignments saved, where until now the ones before it stayed.

| You wrote | Until now | From 1.8 |
|---|---|---|
| `createPermissionSetAssignments(users, ...)` where one assignment fails | the assignments before it stayed saved | none of that call's assignments are saved |

### A cleared mock queries the database again

After a clear, a test now reads what the database holds instead of an empty answer it never asked for. `kern.TST_Mock.clear()` and `clear(SObjectType)` now
remove the mock registration. Until now they left an empty list registered, so a cleared object kept intercepting
queries and answered every one with no rows.

| You wrote | Until now | From 1.8 |
|---|---|---|
| `kern.TST_Mock.clear(Account.SObjectType)`, then a query on Account | no rows, whatever the database holds | the rows the database holds |
| the same, in a test that stored no Account rows | no rows | no rows (unchanged) |
| `kern.TST_Mock.clear(User.SObjectType)`, then a query on User | no rows | the org's users, which every test can see |

A test that relied on the old shape, registered rows then cleared and expected an empty answer while rows of that type were visible to it (its own data, or a setup or
metadata object such as User, Profile or a custom metadata type, which every test sees whatever its SeeAllData setting), now reads those rows; register an empty list instead
if that is the answer you want. The query a cleared object now runs is a real one, so it is subject to the running user's permissions where the old empty answer never reached
the database.

### DML failures now log once, from one place

Each DML failure now leaves one ERROR entry, under one class and method you can filter on. An all-or-nothing DML failure used to roll back and rethrow with no log
entry of its own. It now writes one ERROR entry from `DML_Transaction.commitWork` before the exception
reaches you, and a partial-mode commit that swallows an exception writes one too. The duplicate entries written further up are gone: failures that used to be logged with
`DML_Builder.execute` as their class and method (when exceptions were suppressed), or by the asynchronous DML job, now carry `DML_Transaction.commitWork`, and each failure
logs once. If you filter, alert or report on the class and method of DML failures, update the filter. `kern.DML_Builder`'s `suppressLogging()` silences the new
entries.

### A batch-size record is found by your handler's name

A batch size you configure in metadata now takes effect. A batch size in `AsynchronousJobSetting__mdt` is now looked up under the name of the handler class you
wrote. A record named
`UTIL_AdaptiveAsynchronousProcessor_DTO_ProcessSettings` (the old internal key) no longer matches; rename it after your handler class. Any other record that was being
ignored starts applying, so a job whose record named a size
other than 200 now runs at that size.

### Batch failures now log twice when your code already logged them

The new batch failure listener writes one ERROR entry per failure the platform reports, for the framework's own jobs and for any batch class of yours that implements
`Database.RaisesPlatformEvents`. A failure your job's own code already caught and logged now appears twice. If you count or alert on ERROR entries, expect that.

### The Health Check no longer asks for a Trusted URL

You no longer spend a setup step on a Trusted URL your org never needed. The Health Check's Trusted Site row asked you to add a Trusted URL for your org's own domain
and said Salesforce blocks calls back into your org without one. It does not: an Apex call to your own domain needs neither a Remote Site Setting nor a Trusted URL, and
none of the framework's components call your org's API from the browser. The row is gone, and the installation guide no longer lists the step. With the job runner's
three checks added, the Health Check runs eleven checks. A Trusted URL you already added does no harm; keep it or remove it as you prefer. The same correction reaches
the `kern.API_CallCurrentOrg` documentation and the Web Services guide, which no longer ask for a Remote Site Setting.

### A job in its own mode no longer offers "Every N Minutes"

The editor no longer offers a schedule it cannot save. For a job that runs as its own scheduled job, the Scheduled Job editor no longer offers an "Every N Minutes"
preset. A Salesforce scheduled job runs at most once an hour, so those presets could never be saved; the editor now says so before you save. To run a job more often
than hourly, put it on the [job runner](#run-many-scheduled-jobs-from-a-few-scheduled-job-slots): there the same presets are real, and the job takes no scheduled-job
slot of its own.

### `KernTriggerMustDelegate` checks the whole trigger body

Logic written straight in a trigger body no longer slips past the scan. The rule used to see only statements nested inside a loop or branch, so a trigger that ran a
query, or wrapped its dispatcher call in an `if`, at the top level passed unnoticed. It now reports every top-level statement other than the call that hands the trigger
to the dispatcher, `new TRG_Dispatcher().run()` (or the `kern.`-prefixed form; the rule accepts any `run()` call there). A trigger that never calls the dispatcher at
all, such as a freshly generated trigger whose body is still empty, is reported too. A trigger that has been carrying logic at its top level, or one that was never
wired to the dispatcher, will start failing this priority-1 rule; move that logic into a trigger action, or add the dispatcher call.

### Calls an earlier version left waiting for a retry are not changed by the upgrade

Calls an earlier version stranded stay stranded until you act, because nothing will ever retry them on its own. Before 1.8, a failure in your own handler code
while the request was being prepared, or a
callout that got no response could leave an outbound call at **Retry** with no **Next Retry** time, a call nothing would ever pick up. The upgrade does not touch those
rows. To find them, open the API Calls tab and filter on Status equals Retry and Next Retry is empty (or query `kern__ApiCall__c` where `kern__Status__c = 'Retry'` and
`kern__NextRetry__c = null`). For each, open its API issue and press Retry to run the call again, or resolve the issue. A call has an issue when its setting had Log
Issues on; a call without one is left as it is, or its Status is set to Failed by hand. If there are many, you can mark them **Failed** in one go instead. Triage the
issues you want to run again first. Then, as a user who holds the Kern Administrator permission set, save the script below as
`mark-stranded-outbound-calls-failed.apex`, open a terminal in the folder you saved it in and run the command below until the last debug line reads
`Marked Failed: 0 of 0`; or paste the script into the Developer Console's Execute Anonymous window. If the same rows keep showing `Not marked`, fix what their
message names before you run it again. As with the chain script, the lines are in the debug log (in the Developer Console, tick Debug Only). It sends nothing and does
not change the API issues: an Open issue stays Open, and Retry on it still runs the call again.

The command, the same in Command Prompt on Windows and in a Mac terminal (`YourOrgAlias` is the alias you gave your org when you logged in):

```shell
sf apex run --file mark-stranded-outbound-calls-failed.apex -o YourOrgAlias
```

The script:

```apex
// Marks outbound API calls an earlier version left at Retry with no Next Retry time as Failed, 2000 at a time.
// Run it again until it reports 0 rows. It sends nothing and changes no API issue.
List<kern__ApiCall__c> stranded = [SELECT Id FROM kern__ApiCall__c WHERE kern__Direction__c = 'Outbound' AND kern__Status__c = 'Retry' AND kern__NextRetry__c = null LIMIT 2000];
for(kern__ApiCall__c item : stranded)
{
    item.kern__Status__c = 'Failed';
}
List<Database.SaveResult> saveResults = Database.update(stranded, false);
Integer marked = 0;
for(Integer index = 0; index < saveResults.size(); index++)
{
    if(saveResults[index].isSuccess())
    {
        marked++;
    }
    else
    {
        System.debug(LoggingLevel.ERROR, 'Not marked ' + stranded[index].Id + ': ' + saveResults[index].getErrors()[0].getMessage());
    }
}
System.debug(LoggingLevel.ERROR, 'Marked Failed: ' + marked + ' of ' + stranded.size());
```

### Two new chain fields need Read for a cloned permission set or a profile

People who reach the Chain Monitor through a permission set you cloned, or through a profile, cannot see Last Manual Retry At and Elapsed (ms) on the record page, in
list views or in reports until you grant Read on both. The packaged Kern Administrator and Kern Async Chain Monitor Read Only sets grant Read on both after the
upgrade; a set you cloned from them, and a profile, do not gain it. The Chain Monitor itself needs nothing. Runs retried before the upgrade keep a blank date and show
no line; the field records retries from this version on.

### The Flow email action refuses to log an email to a User through standard activity logging

A flow that asks for this now gets a clear message instead of an unhandled flow fault. Salesforce does not log emails sent to Users, so the Flow email action now refuses
to log one through standard activity logging, and says why. To keep a record of an email to a User, use custom activity logging: with Save as Activity on, the email is
sent and its Task is logged against the related record.

### A new scanner rule reports a governor limit read directly

A scan through the full or combined ruleset now finds every place your code reads a governor limit straight from `Limits`, so you can read every limit one way. The new
rule, `KernLimitsThroughWrapper`, is informational (priority 5) and ships in the full ruleset and in the combined single-file ruleset, which is meant for an IDE that
takes one ruleset file (IntelliJ with Illuminated Cloud, or the VS Code Apex PMD extension), not for Code Analyzer; the hygiene and framework tiers leave it out. Each
direct read of `Limits.getQueries()` or one of its siblings gains one finding. Read the limit through `kern.UTIL_Limits` instead. The framework's own code now reads
every limit through the wrapper.

### The framework ruleset runs the Kern rules again under Code Analyzer 5.16 and later

A scan that uses the framework-side ruleset runs the Kern rules again, so a CI gate that has been passing with no Kern findings may now report some. Salesforce Code
Analyzer 5.16 runs the code scanner (PMD) from its own install folder. `kerndx-framework-ruleset.xml` pointed at the rule definitions in the full ruleset by a relative
path, which stopped resolving there, so every scan that used the file ran no Kern rule at all and still exited 0. The file now carries its own rule definitions. Nothing
changes in what the rules check. If a gate starts failing once you use the 1.8 file, the findings were already in your code: fix them, or adjust the gate.

### The CI workflows the pipeline writes no longer let pull-request text run as code

A crafted branch name or pull-request title can no longer run commands in your CI jobs or ping a whole Slack channel. The CI workflows `kerndx init` writes put a pull
request's branch name and title straight into shell scripts and into Slack messages, so anyone who could open a pull request could pick a branch name that ran commands
in the job, or a title that pinged a whole channel or hid a link. The new templates pass that text to scripts only as quoted variables and build Slack messages as JSON
with `<`, `>` and `&` removed; the full list is under [Smaller fixes](#smaller-fixes).

Workflows already in your repository keep the old form until you write them again from the new templates: run
`node .kerndx-pipeline/bin/kerndx upgrade`, which saves each file it replaces as `.bak` first. Until then
`node .kerndx-pipeline/bin/kerndx doctor` reports them as changed.

### The Validation Errors component's click event stays with the component

The Validation Errors component's `fieldclick` event no longer reaches components that have nothing to do with it. When you click a message, the component fires
`fieldclick` so the matching field can be focused. The event used to travel up through every component to the page. It now stops at the component's own tag, where a
parent that listens on that tag still hears it. If your own component listens for it on an element above the `<kern-validation-errors>` tag, move the listener onto
that tag itself.

---

## New in the Apex API

**Who it's for:** developers writing against the framework.

Twenty-seven new global members: twenty-five on eleven existing classes and two new global classes. Nothing was removed or changed in signature. Each carries `@since 1.8`
in its ApexDoc; the two new classes say so on their reference pages.

### `API_Outbound`

**`global protected virtual Set<Integer> getRetryableStatusCodes()`**

The HTTP statuses a failed call may be retried after: 408, 425, 429, 500, 502, 503 and 504 by default, with 500, 502 and 504 retried only when the request is safe to
repeat. Override it to add a status your external system uses to mean "try later", which is then retried whatever the method, or to remove one.

**`global protected virtual Set<Type> getRetryableExceptionTypes()`**

The exception types from your own handler code that may be retried, empty by default. A type is matched by its exact name, so list each type you throw; a parent
type such as `Exception` matches nothing. After a successful response a listed type is retried only when the request is safe to repeat.

In a `global` handler class, declare an override such as the one below `global`; in a `public` one, declare it `public`.

```apex
global override Set<Integer> getRetryableStatusCodes()
{
	Set<Integer> codes = super.getRetryableStatusCodes();
	codes.add(409);
	return codes;
}
```

### `DML_Builder`

**`global DML_Builder withRetryOnLock()`**
**`global DML_Builder withRetryOnLock(Integer retries)`**

Try a commit again when the platform refuses it because another transaction holds a row. The first form retries once; the second takes the number of extra attempts, from 1
to 5. There is no pause between attempts, because the platform already waits up to about ten seconds for the lock before it refuses. Keep the default on interactive paths
and use larger counts in background work.

```apex
kern.DML_Builder.newTransaction()
	.doUpdate(records)
	.withRetryOnLock()
	.execute();
```

**`global DML_Builder expectRefusal(StatusCode statusCode)`**

Declares a refusal you expect and handle, so a row refused for that reason is logged at WARN instead of ERROR when the transaction allows partial success. You can call it
more than once, one status code each time.

### `FLOW_LoggerLog.DTO_Request`

**`global String flowName`**

The **Flow Name** input on the Log Flow Event action. Filled in, the entry names the Flow as its source and keeps the step in its location text; left blank, the entry names
the step, as before.

### `FLOW_RetryApiIssues` (new class)

**`global inherited sharing class FLOW_RetryApiIssues`**
**`global static List<DTO_Response> retryApiIssues(List<DTO_Request> requests)`**

The **Retry API Issues** Flow action (category **Api Callouts**), the action behind **Retry Selected** on the API Issues list. It runs the failed calls of the open
API issues you name again, in one background job, and needs the Retry API Issue permission. An issue is left open, and not run, when the external system may already
have acted on it, when it is for a call your org sent out and its service is paused or allows no retries, or when its own call, or a call for its record, is still
in progress; the message says how many were queued. A request another system sent in is run again whatever its service's setting says. Pass exactly one
request; any other number throws an `IllegalArgumentException`.
`DTO_Request` holds `apiIssueIds`; `DTO_Response` answers with `jobId` (null when nothing was queued), `queuedCount`, `success` and `message`.

```apex
kern.FLOW_RetryApiIssues.DTO_Request request = new kern.FLOW_RetryApiIssues.DTO_Request();
request.apiIssueIds = new List<String> {issueId};
kern.FLOW_RetryApiIssues.DTO_Response response = kern.FLOW_RetryApiIssues.retryApiIssues(new List<kern.FLOW_RetryApiIssues.DTO_Request> {request}).get(0);
```

### `LOG_Builder`

**`global static String rootCorrelationId`**

The tracking ID of the action that started everything the current transaction belongs to. It equals the correlation ID until a background chain continues the action under
a tracking ID of its own; then the correlation ID names that run and the root still names the action. Search the Log Console for it to see every entry the action produced.

```apex
String actionId = kern.LOG_Builder.rootCorrelationId;
```

### `QRY_Builder.Builder`

**`global virtual QRY_Builder.Builder withCache(UTIL_Cache.Scope scope, Integer ttlSeconds)`**

Caches this read's rows in the given scope. `AUTO` asks for the most durable place that is safe for the read when it runs: Platform Cache for a system-mode
read when a partition has room, and memory for the transaction otherwise. A user-mode read is only ever kept in memory for the transaction. A system-mode read must
state its sharing with `withSharing()` or `bypassSharing()`; without one it is not cached at all. A null time-to-live uses the default of 900 seconds; the
time-to-live does not apply in memory.

**`global virtual QRY_Builder.Builder withoutCache()`**

Makes this read go to the database, whatever caching the selector or an earlier call asked for. The last caching call on a builder wins.

Here `SEL_Accounts` stands for your own selector:

```apex
List<Account> fresh = new SEL_Accounts().query.withoutCache().condition(Account.Id).isIn(new List<Id>(accountIds)).toList();
```

### `SCHED_JobRunner` (new class)

**`global inherited sharing class SCHED_JobRunner extends SCHED_Base`**

The job runner's scheduled job. Health Check schedules it for you, once for each minute of the hour you choose (one to twelve times an hour); each time it fires it
runs one check, which starts every due job that is set to run on the job runner. It holds no state and takes no parameters, so a package upgrade never invalidates
the scheduled job that points at it.

### `SEL_Base`

**`global virtual UTIL_Cache.Scope cacheScope()`**
**`global virtual Integer cacheTimeToLiveSeconds()`**

Override `cacheScope()` to cache every list or record read your selector makes (counts and query locators always query); `IN_TRANSACTION` keeps the rows in
memory for the transaction only. A system-mode selector caches only in the methods that call `withSharing()` or `bypassSharing()`. Override
`cacheTimeToLiveSeconds()` to say how long Platform Cache may keep them; overriding it alone caches those reads with the `AUTO` scope. Return a constant from
both: they are called each time the selector's `query` builder is built. The scope and time-to-live are part of what the selector promises its callers about how
old the rows may be.

### `TST_Factory`

**`global static User insertUser(String profileName)`**
**`global static User insertUser(String profileName, String companyName)`**
**`global static List<User> insertUsers(String profileName, Integer numberOfUsers)`**
**`global static List<User> insertUsers(List<User> users)`**

Create and save users inside the factory's own guard, ready for `System.runAs`, so your test can save ordinary records before or after the call without a mixed-DML error
and without a `System.runAs` block of its own. The company name can serve as a unique value to find that user again. The list form saves users you built yourself with
`newUser` or `newUsers`, with any field your org needs set first.

### `TST_Mock`

**`global static void registerNext(SObjectType objectType, List<SObject> records)`**
**`global static void registerNext(SObjectType objectType, SObject record)`**

Set the answer to the next query the framework runs against that object. Each call answers one query, or one count, and the answers are used in the order you added them.
An empty list means the next query finds nothing. `clear()` and `clear(SObjectType)` remove answers still waiting.

```apex
kern.TST_Mock.registerNext(Account.SObjectType, new List<SObject>());
```

### `UTIL_Exceptions`

**`global virtual inherited sharing class PermanentFailureException extends Exception`**

Throw it from your outbound handler's code to say a failure is permanent and sending the same request again cannot help. The call ends `Failed` at once, with one
issue and no retry, whatever the retry settings say; an async chain's API step fails for good the same way. Thrown from `getValidationErrors()`, it ends the
call `Aborted`, as any refusal in validation does.

```apex
throw new kern.UTIL_Exceptions.PermanentFailureException('The external system rejected the order; sending it again cannot help.');
```

**`global inherited sharing class RequestRefusedException extends PermanentFailureException`**

Throw it from `parseResponse()` when the external system answered with a success status but its body says it refused the request, for example an order answered
200 with status `REJECTED`. The call ends `Failed` at once with one issue and no retry, and because a refusal means the external system did not act, the issue's
External System May Have Acted box stays clear, so Retry Selected can run the call again once you have fixed the cause. Thrown anywhere else, it behaves exactly as
`PermanentFailureException`.

```apex
throw new kern.UTIL_Exceptions.RequestRefusedException('The external system rejected the order; fix the order and run the call again.');
```

### `UTIL_Limits`

**`global static LimitCheck apexCursors()`**
**`global static LimitCheck apexCursorRows()`**
**`global static LimitCheck apexPaginationCursors()`**
**`global static LimitCheck apexPaginationCursorRows()`**
**`global static LimitCheck fetchCallsOnApexCursor()`**

Read the five Apex cursor limits the way you already read the other fifteen: cursors created, rows returned by cursors, pagination cursors created (the kind of
cursor built for paging a list on screen), rows returned by pagination cursors, and fetch calls made on cursors. The platform counts cursor creation over a
trailing 24 hours, unlike the limits that reset with each transaction.

### `UTIL_String`

**`global static String joinSorted(Set<String> values, String separator)`**

Joins the members of a set in sorted order, so a message or log line that lists them reads the same every time and an exact-text assertion on it holds. Apex does not
promise the order a set is read in, and the existing `join(Set<String>, String)` keeps that order. Null in, null out, like its siblings.

---

## Easier to use with assistive technology

**Who it's for:** orgs with accessibility requirements, and anyone working by keyboard or screen reader.

A screen reader now tells you what each copy button copies and what the drawer's clock and warning icons mean, and more of the screens' text can be
translated.

- **Every copy button says what it copies.** The Log Console drawer's seven copy buttons carry six names ("Copy message", "Copy action ID", "Copy correlation ID", "Copy
  code", "Copy stack trace" and "Copy context"), and the Chain Monitor's two read "Copy correlation ID" and "Copy action ID". Each name is both what a screen reader
  announces and the tooltip. None of them is a bare "Copy" any more.
- **The drawer's timeline uses standard icons** instead of text symbols. The clock on the overview line and the warning pin carry spoken names; the other three icons are
  decorative, because the text beside each already says what it means.
- **The DEBUG level filter shows clearly when it is pressed.** Its pressed and unpressed states were near-identical in colour.
- **The Chain Monitor's step timeline takes its "Loading steps" text** from a Custom Label, so it can be translated.
- **The API Test Harness's ten icon descriptions** (copy summary, copy request headers, and the others) are now Custom Labels, so they can be translated. Nothing else
  changes on screen.

## Smaller fixes

**Who it's for:** anyone who uses the area named in bold. These fixes need nothing from you, except two in Code scanning and tooling: rename one key
in a `code-analyzer.yml` that the pipeline's `init` command wrote earlier, and write the CI workflows it wrote again from the new templates.

**Async chains**

- **A wildcard masking target no longer disturbs a chain run's internal keys.** A masking target that names no field (a wildcard) could rewrite a chain run's internal run
  key or job ID when their digits happened to pass a card-number check, leaving about one run in several thousand stuck as Running with no steps done until the
  framework's check for stuck chains started it again. Masking now leaves those two internal fields alone in every wildcard decision; a target that names one of them
  explicitly is still honoured.
- **A step the watchdog would not run again reads as the step the chain stopped at, even when it was added with continueOnError.** When the watchdog stops a
  stalled chain at a step that had already started and never declared itself safe to repeat, the Chain Monitor now shows that step as failed rather than as a warning,
  the steps after it read Did not run, and the retry message says the step was never declared safe to run again, instead of saying there is no failed step to retry from.
  Retry is refused either way, as before. A chain the watchdog stopped before you upgraded keeps the old wording.
- **A background job that chains itself into several runs no longer loses its remaining work after the first run** when it was launched with no job options
  (the optional settings, such as a delay, that the platform applies when the next run is queued). Queueing the next run failed with an error, and the rest of the
  work never ran. The next run is now queued the same way as the first.
- **A queueable job whose work items are plain values logs its failure.** When such a job fails, the failure is now logged with those items listed as text. Before,
  composing that log entry itself failed with an "Invalid id" error, which hid the exception the job had actually failed with.
- **The step timeline no longer guesses a step's state from where the step sits in the list.** A step shows Running, No result recorded or Did not run from what
  the run record says.
- **A run started on 1.7 shows its unfinished step from what its record holds.** If such a run was still running at the upgrade, the step it was on shows Pending
  until it records a result. If such a run ended with a step in flight, that step shows Did not run.

**Scheduled jobs**

- **A job on the job runner that is due in the minute the clocks jump forward now runs that day.** The schedule reader behind the job runner and the editor's
  preview dropped the one run that lands exactly on a spring-forward clock change, so such a job ran a day late (seen with New York and Auckland time). Each
  possible run time is now turned into a moment in time before it is compared, and only that moment decides.
- **A day-of-week field that holds only the letter L now means Saturday.** `L` on its own is how the platform's own
  scheduler reads it. The schedule reader used to refuse such a schedule as unreadable.

**Logging**

- **An entry logged from inside an inner class keeps that frame in a namespaced org.** Every entry records the code that led to it, with or without an exception. In an org
  with a namespace, the trace of an entry logged from inside an inner class dropped the inner class's own frame, the one that names where the entry was written, and kept only
  the outer frames. The trace now keeps every frame of your own code.
- **Log entries keep their origin when logging contexts nest more than ten deep.** Past ten, a new context is not added, and ending it used to remove the caller's context
  instead, so the caller's later lines lost their origin. Ending it now removes nothing.
- **A line logged inside a web-service call that arrived with a trace header carries the call's endpoint, status code and callout duration.** A trace header
  (the `traceparent` header) carries one tracking ID across systems. Those details were written under one tracking ID and read under another when the caller sent
  a trace header, so they never reached the entry. The lines from a batch's own final save now carry the batch's context
  only, never the last call's, and a handler whose `process()` override fails before calling the base class records that failure on its call record instead of raising a
  second error.
- **A misconfigured masking rule on the log objects no longer disturbs the entry being written.** Its warning was written from inside the entry being built, took over
  the entry's fingerprint (the key that groups repeats of the same problem), and left the entry's later messages without it. The warning is now skipped when the
  target is a log entry or the log event, as a third warning already was. The trade-off: such a rule stays silent in the log, and the masking console's check and test
  still show it.
- **A summary set on an entry that also carries an exception is written.** When both were set, the summary was silently dropped and the entry's short message became
  the exception's own text. Both now land on the one entry.
- **An entry from a Lightning component that cannot be read no longer leaves its context on the lines logged after it** in the same request. The exception, and the
  entries stored before it, are as they were.
- **The debug line written when a job cannot restore its logging context is masked.** When a background job could not read the logging context handed to it, the
  framework wrote a warning to the debug log holding the error and the whole stored context, unmasked. The context in that line now passes through the masking rules
  for log entries, the same ones a log entry's context data passes through. If a rule blocks it, or masking fails, the line holds the error alone. With masking switched
  off, the context is written as stored, as a log entry's would be.

**Log Console**

- **Refresh keeps up with a run or an action that is still going when you arrive from a link.** The end of the date range moves to now on each refresh, then
  settles on the real end once the source finishes; a range you set yourself stays exactly where you put it. Until now the end was fixed at the moment the link opened,
  so entries written afterwards needed the range widening by hand. This closes the known issue listed in the 1.7 notes.
- **A Flow's entries are named after the Flow, and a class in another namespace after the class.** Wherever the console names the class behind an entry or a group
  of entries (a grouped or tagged problem in the problems ribbon, an entry row's summary, the detail panel, the nodes of the trace tree, and the fallback detail of a
  problem whose entries were purged), a row written from a Flow used to read the literal `Flow`, and a row logged from a class in another namespace read the namespace
  rather than the class. Each now reads the entry's stored source. A row written before the upgrade stored no source and is named as before; the Source column and its
  location pill were already right and do not change.
- **A search of only brackets or only quotes no longer fails the entries list.** Typing `()` or `""` into the search box made the full-text search refuse the term, and
  the list and its summary failed with it. Such a term now counts as having no full-text matches, while the literal match on the message text still applies, so you see
  the entries whose text holds the term, or none. The problems ribbon never searched and is unchanged.
- **The detail panel's action buttons keep their labels whole.** On a narrow panel the buttons now wrap onto a second row instead of breaking a label across
  two lines.

**Chain Monitor**

- **Leaving the Chain Monitor while its live stream was on no longer raises an error in the browser.** The stream was unsubscribed without the acknowledgement the
  platform requires.

**Event Monitor**

- **The list view event uses the platform's spelling.** The Event Monitor offered the list view event as `ListviewEventStream`,
  which does not match the platform event `ListViewEventStream`. Its channel now uses the platform's name, and the choice reads
  List View Event Stream.

**Kern Home**

- **The Open buttons on the tool tiles sit level along each row.** The tile grid now keeps every tile in a row the same height,
  so each row's buttons line up.

**Data masking**

- **A rule set to block stays in force for the whole transaction.** Now that `send()` and the logger carry on after a blocking rule refuses something (see
  [Outbound calls](#outbound-calls-an-answer-every-time-and-no-stored-credentials)), every later record, attachment or log entry that meets the same rule is refused or
  dropped in turn: the trigger refuses the record, the attachment step drops the files, the logger drops the entry. A rule set to warn is set aside after its first
  failure, as before.

**Health Check**

- **A user who is not a System Administrator can open the Health Check and the API Test Harness with the Kern Administrator permission set.** The set granted
  every Kern tab but not the Apex classes behind those two pages, so such a user was refused with "You do not have access to the Apex class named
  'CTRL_HealthCheck'". The set now grants both classes. Switching the job runner on or off, and repairing it, still need the Manage Job Runner permission. The same
  refusal met any other user whose page used a component of yours built on the package's modules and components (`kern/featureFlag`, `kern/utilityLogger`,
  `searchLookup`, `createForm`, `sObjectLookup`), or whose screen flow called one of the package's everyday Flow actions (the feature flag check, the logging
  actions, Get PickList Values, Check Object Permissions), because only Kern Administrator granted the classes behind them. A new **Kern Component Access**
  permission set grants those thirteen classes and nothing else; assign it to every user of such a page or flow. An org on 1.7 can close both gaps until it upgrades,
  with Apex class access in a permission set of its own (the names are the ones Setup shows under Apex Class Access): a Kern Administrator who is not a System
  Administrator needs `kern.CTRL_HealthCheck` and `kern.CTRL_ApiTestHarness`; and every user of a page or flow built on the components, administrators included,
  needs `kern.CTRL_FeatureFlag`, `kern.CTRL_Logger`, `kern.CTRL_ExecuteSearch`, `kern.CTRL_FieldSet`, `kern.CTRL_SObjectInformation`, `kern.CTRL_Search`,
  `kern.FLOW_CheckFeatureFlag`, `kern.FLOW_LoggerStart`, `kern.FLOW_LoggerLog`, `kern.FLOW_LoggerEnd`, `kern.FLOW_WriteLog`, `kern.FLOW_GetPicklistValues` and
  `kern.FLOW_CheckObjectPermissions` (on 1.7 the Kern Administrator set already grants twelve of these; a Kern Administrator needs only `kern.CTRL_FeatureFlag` added).
- **The type resolver the Health Check generates finds a class with one lookup.** The resolver class it writes for you, and the same example in the Web Services, DTOs,
  Objects & Metadata, Utilities and Administration Tools guides, now looks a class up once by its whole name, which finds a namespaced name (`ns.ClassName`) and a
  nested one (`Outer.Inner`) alike. The old body tried a first lookup that never found a namespaced class, then a second that did all the work, so a resolver you
  already generated keeps working; copy the new body if you want the simpler code.

**Testing**

- **Mock child records point to their parent.** With `withoutInsertion(true)`, `kern.TST_Builder` gives the parent and its children mock Ids, but a child added through
  `withChildren` was left with an empty lookup to its parent. The lookup now holds the parent's mock Id, as the `withoutInsertion(Boolean)` documentation already said.
  Without mock Ids the lookup stays empty, because the parent has no Id to point to.
- **A log written while a test delivers another entry keeps its own details.** In a unit test the framework delivers the log
  events it has just published at once. A log written during that delivery, such as the line the trigger framework writes when
  it skips an action that is switched off, was saved with the other entry's exception type and stack trace. It now carries only
  its own. Outside tests nothing changes, because the immediate delivery happens only in a test.

**Saving data**

- **A commit with nothing registered no longer hides the failure of your hook.** A transaction commit with nothing registered still runs your `onCommitWorkStarting` hook.
  Until now, when that hook threw, the commit's own error handling replaced your exception with a `NullPointerException` and wrote no log entry. The hook's exception now
  reaches you as itself, and one ERROR entry at the commit records it, as it already did for a commit with registered work.
- **Work your hook registers on an empty commit is rolled back when a later statement fails.** Until now such a commit took no savepoint, so when one of the hook's
  statements failed after another had already saved, the saved rows stayed in place while the exception reached you, and a commit retried for a row lock
  (`withRetryOnLock()`) ran the hook's work again beside them. The commit now takes its savepoint once the hook has registered work, so a failure rolls all of it back and a
  retry starts clean. A commit that registers nothing still takes no savepoint. A commit with registered work is unchanged: its savepoint is taken before the hook runs.

**Flow email action**

- **Sending to a Contact, Lead or User record** with standard activity logging selected but Save as Activity off no longer fails with an unhandled flow fault; the email goes
  to the record's address. Asking to log an email to a User through standard activity logging is now refused with a clear message (see
  [its heading](#the-flow-email-action-refuses-to-log-an-email-to-a-user-through-standard-activity-logging)). With custom activity logging, an email
  to a User with Save as Activity on now succeeds and logs its Task against the related record;
  before, the email was sent and the response then reported a failure.

**Inbound web services**

- **Retry on an API issue for a call your org received now replays that call.** The **Retry** action on such an issue replays the call in your org, keeps the
  changes the replay makes, and marks the issue resolved when it works. Before, it was refused, or it tried to send the call out again as if your org had made it.
- **Request headers are found whatever case the caller sends their names in.** Node and every HTTP/2 client send header names in lower case, such as
  `idempotency-key` and `content-type`. The framework looked those headers up by their exact spelling, so such a caller got no idempotency (a retried request ran a
  second time) and the request's content type read as empty. The framework now finds its headers whatever their case. Your own handler reads its headers the same way
  through the case-insensitive map: `String partner = (String)new kern.UTIL_Map.CaseInsensitiveMap(request.headers).get('X-Partner-Id');`
- **An inbound handler whose own error handling throws answers 500.** When a `handleError()` override threw, the caller got a 200 with an empty body, as if the request
  had succeeded. It now gets a 500.

**Code scanning and tooling**

- **The framework-side ruleset works with Code Analyzer 5.16 and later.** See
  [its heading](#the-framework-ruleset-runs-the-kern-rules-again-under-code-analyzer-516-and-later) for what a CI gate may now report.
- **The trigger-delegation rule checks the whole trigger body.** `KernTriggerMustDelegate` now reads every top-level
  statement. See [its heading](#kerntriggermustdelegate-checks-the-whole-trigger-body) for what starts failing.
- **The pipeline tools run on Windows.** `kerndx doctor` and `kerndx scan` now find the Salesforce CLI on Windows, the shipped npm scripts run under Command Prompt, and
  the hard-coded-text scanner and three ESLint rules (component naming, tests that assert nothing real, mutating a shared fixture) work there too, where the rules used
  to report nothing.
- **The pipeline's doctor command no longer warns about PMD's Apex module 7.27.0.** `kerndx doctor` now counts it as
  tested, because the rules were checked against it; the warning starts at 7.28.0, and the 7.26.0 that Code Analyzer
  bundles still reads as fine.
- **The Code Analyzer settings file the pipeline scaffolds names the flow engine's after-save rule as Code Analyzer does.** In `code-analyzer.yml` the key
  is now `SameRecordUpdate`. The old key matched no rule, so Code Analyzer ignored the override without a warning and ran the rule at Moderate instead of
  the intended Info. `kerndx init` keeps an existing file, so a configuration scaffolded earlier needs the key renamed by hand.
- **The namespace swap script checks where it runs, verifies its result and cleans up after a failure.** Run from the wrong folder it names what is missing and where
  to run it; `--verify` scans the swapped tree for any leftover reference to the original namespace; and the printed next steps are one pasteable command per line,
  with the build command naming your Dev Hub. A swap that cannot finish, such as when an editor or antivirus holds a file open on Windows, removes what it was
  preparing, never deletes a backup folder that still holds your files, and names the file to close; a second run on a swapped tree is refused for that reason; and
  the stack-trace frame a managed package shows is rewritten with the rest.
- **A new scanner rule reports a governor limit read straight from the platform.** `KernLimitsThroughWrapper` reports each direct read of `Limits`. See
  [its heading](#a-new-scanner-rule-reports-a-governor-limit-read-directly).
- **The CI workflows the pipeline writes keep pull-request text out of scripts and Slack messages.** `kerndx init` writes them. A branch name or a pull
  request's title used to go straight into a shell script and into a Slack message: a crafted branch name could run commands in
  the job, and a crafted title could ping a whole channel or hide a link. Branch names and titles now reach scripts only as
  quoted variables, and Slack messages are built as JSON with `<`, `>` and `&` removed, as the `slack-payload` command now does
  too. With Slack off, no workflow refers to a Slack secret. Every action is pinned to an exact commit, the Salesforce CLI and
  the Code Analyzer plugin to exact versions, and the pipeline's own steps run on Node 22. Two template faults are fixed as
  well: a `runs-on:` line no longer joins the next line into a workflow that cannot run, and answering yes to the auto-assign
  reviewer question now writes that workflow. To get the fix, write your workflows again from the new templates: see
  [its heading](#the-ci-workflows-the-pipeline-writes-no-longer-let-pull-request-text-run-as-code).
- **The pipeline prints one form of its command, which runs in every terminal.** That form is `node .kerndx-pipeline/bin/kerndx`. The
  `./.kerndx-pipeline/bin/kerndx` form it printed before does not run in Command Prompt. The `doctor` message, the Husky hook,
  the scaffolded workflows and the pipeline README now use the portable form.
- **The ESLint rule for the component base class names the package import.** The `use-component-builder` rule's message told every reader to import from
  `c/componentBuilder`. In an org with the package installed the import comes from the package, so the message now names both,
  the package's first. The bundle's ESLint example and the plugin README now set `enforce-component-naming` to `error`, as the
  Code Scanning guides already did, and the `KernLimitsThroughWrapper` description says what the wrapper gives: every limit
  read one way, with the near-limit check in one place.
- **The pipeline package's dependencies move past published security advisories.** `fast-uri`, which the package's schema
  validator uses, moves from 3.1.5 to 3.1.8, closing advisories on host confusion and server-side request forgery, and
  `js-yaml` moves from 4.3.1 to 4.3.2.

## How this release was tested

**Who it's for:** anyone who needs to know what stands behind the release before installing it.

1.8 ships with Winter '27, so it was tested the way a platform preview window allows: one installed-package pass on a preview build, installed into scratch orgs on the Winter
'27 preview release. That pass has two legs, a **fresh install** into a clean org and an **upgrade** from Kern 1.7.0-13, so both the first-time and the existing-customer
paths are proved on the same build. The production build that follows is compiled from the same source once Salesforce's packaging service has moved to Winter '27.

On each leg the Apex test suite and every scanner rule set run in the installed package. The browser-driven end-to-end suite, written in Playwright, drives the packaged
screens the way a person would; for 1.8 it grew to **<N, filled in at release testing> test files** and **<N, filled in at release testing> automated checks**, with new
journeys for the job runner, the whole-action view, the Source column and the Chain Monitor's timing. The two consoles were also run at volume: an org loaded with
realistic data, the chain engine run in bulk, and exploratory browser sessions that test what the screens assume about the data behind them. Seven of those checks
are now fixed journeys, run on every release pass against a staged load, and the Log Console's controller is measured in an Apex test over two thousand nested,
stepped runs.

The commands in the installation guide were proved on Windows as well as on a Mac; see [Documentation](#documentation).

## Documentation

**Who it's for:** everyone who reads the guides, and any AI coding assistant you point at KernDX.

- **A new Fast Start for scheduled jobs and the job runner.** Fast Start - Scheduled Jobs schedules a class with a record, moves it onto the job runner, runs it now,
  reads a succeeded and a failed run and the log entry the failed one links to, and switches it off, in about 25 minutes.
- **The guides cover Winter '27.** Every Winter '27 note in the guides is listed, with what it means for you, under [Ready for Winter '27](#ready-for-winter-27).
- **Every global member says when it arrived, in its ApexDoc.** Each global class, method and property carries an `@since` version in its source comments, and 70
  members that lacked one gained it.
- **The Test Data guide shows how to seed a sandbox or scratch org from anonymous Apex**, in a new section, "How do I seed a sandbox or scratch org?". `TST_Builder` and
  `TST_Factory` are production classes, so the recipe works in any sandbox today, with the caveats that come with it: only required fields are filled, a user needs a free
  licence seat and a profile with that exact name, and deactivating users runs in a script of its own.
- **The comparison guides credit Nebula Logger accurately.** They no longer credit `nebula-logger` with a log-browser interface that the Log Console
  already gives you, no longer count its dashboards as a KernDX gap (you build the same on `LogEntry__c`), and add its Big Object archiving as a credit. Two
  credits with no basis were dropped.
- **The Strategic Guides send you to the Metrics guide for every count**, so no guide states a figure that the next recount can leave out of date.
- **The Async Processing guide has a "Choosing a Batch Size" section**, with the chunk sizes, the divisibility rule and the sizes that fit.
- **The Selectors guide explains query caching**, in a rewritten "Caching Queries" section: opting a selector in, where rows are kept, what empties the cache, how a
  selector tells its callers how old its rows may be, and what to do in tests. The Triggers guide's "Caching with Trigger Actions" now leads with a caching selector
  that every action reads through.
- **System mode on a query is described correctly.** Fourteen guide statements said `withSystemMode()` bypassed record sharing. It sets aside object and field
  permissions only; record sharing follows the calling class unless you also call `bypassSharing()`. The Selectors guide shows the three combinations measured on a
  private object as another user: no dial fails loudly, system mode alone returns nothing without an exception, and system mode with the sharing bypass returns the
  rows.
- **A log scope batches entries and times nothing.** Three passages said wrapping code in a scope recorded when the work started and finished. They now show how to
  time your own code, and the Log Buffering section says what a scope is for: its entries publish together, in chunks of 50, instead of one immediate publish each.
- **The guides name only members you can call.** Passages in the Web Services, Utilities and Strategic Guides that named members visible only inside the package now
  describe what the framework does for you, show the documented way to do the same, or spell the literal.
- **The generated API reference covers the new surface**, including the twenty-seven new global members and the new fields.
- **Every command the guides print runs as printed in Windows Command Prompt and on a Mac.** The installation guide is restructured around its three paths. The
  seventeen Fast Starts share one step shape: generate a class, paste it, deploy it, read the one line that proves it worked, and find any failure in the guide's own
  list, grouped by the step where you see it. A new page, Set Up Your Computer, holds the one-time setup and the readiness check every Fast Start links to. The seven
  other guides with commands print them in the same portable form. Every quoted screen line comes from a real run. Before each release, two runs on Windows machines,
  started by hand, check every command in Command Prompt and in both PowerShells. For this release, every command was also run in zsh and bash on a Mac, by a
  local script.
- **Run the framework's Apex tests on your own computer.** If you deploy KernDX from source, under your own namespace or with
  none, the installation guide's new optional section, "Run the tests on your computer with aer (optional)", shows how to run the Apex tests with aer,
  a local test runner from October Swimmer, with no org: how to install it on Windows and on macOS or Linux, run one class or a
  group, and run every test in batches within its free tier. It is plain about the limits: aer is a paid product with a free
  tier, a real org stays the final word, and testing your own code against an installed KernDX does not work with it yet.
- **The Apex reference describes every member, every enum value and every override.** Descriptions in about half the
  framework's classes were rewritten in shorter sentences, with a term explained where it first appears.
- **The Selectors guide's comparison table is corrected.** It describes result caching as it ships, instead of naming a per-user
  cache option that no longer exists.
- **The public repository's README and environment example name the scripts that exist.** They listed four npm scripts the
  shipped `package.json` does not carry. They now list `docs:build`, `scan:flow-references` and `coverage:gate`, and the two
  scripts you run with `node` directly, `build-package.js` and `setup-scratch-org.js`, and the environment example tells you to
  set those variables in your terminal.
- **The example classes in the public repository do what they claim.** The example trigger actions save through the DML builder
  and read through the query builder, the example chain step no longer fails on an empty value, the example scheduled job
  applies its parameter defaults, their messages come from Custom Labels, and every example test asserts the outcome its name
  describes.

## Known issues

Each of these is tracked as an issue on the public repository, linked after its heading, and a release that fixes one closes its issue.

- **Retry Selected on more than 10 inbound issues at once can fail some of its jobs.** ([#39](https://github.com/JVB-Consulting/kerndx/issues/39)) The same applies to the Retry API Issues Flow action. Retry Selected runs
  the selection in jobs of 20 requests. An inbound replay re-runs the original request through the whole inbound pipeline, so each one writes several times (the
  call record, your handler's own records, the issue, the log entries). In our tests, a job of twenty inbound replays went over the limit of 150 database writes
  (DML statements) that Salesforce gives a job, and a job of ten did not. How many fit depends on what your handler and your triggers write. A job that hits the
  limit fails, and nothing it saved in Salesforce is kept, so its issues stay Open. If that job also held outbound issues, their requests were already sent to the
  other system before the job failed, and those issues stay Open too. A selection with no inbound issues is not affected, whatever its size. To retry many inbound
  issues at once, create an Asynchronous Job Setting record with the record name `kern_FLOW_CallApiAsync` and a Batch Size of 10 or less, or select 10 or fewer
  inbound issues per retry.
- **The Top sources card and the list it opens can show different counts while older entries age out.** ([#40](https://github.com/JVB-Consulting/kerndx/issues/40)) Entries written before the upgrade carry no origin and no
  source. Until they age out of your retention window, a problem with entries from both before and after the upgrade can show one count for a source on the Top sources
  card and a different count in the list you get by clicking that source, higher or lower; the two agree once the older entries are gone.
- **An upgraded org may keep the old duration column on the chain execution list view, highlights panel and search results.** ([#41](https://github.com/JVB-Consulting/kerndx/issues/41)) A fresh install shows Elapsed (ms) there. How an
  upgrade treats a list view, compact layout and search layout the earlier version installed was not verified; an org that keeps the stored duration there has lost nothing it
  had, and you can add Elapsed (ms) yourself.
- **The manual-retry line can be left off a very long chain.** ([#42](https://github.com/JVB-Consulting/kerndx/issues/42)) When the chain record has no room left to note 100 characters for each step still to run, the timeline's
  "Retried manually" line is left off. The retry still happens, and Last Manual Retry At is written either way: on such a run, read that field on the run record to see
  when it was retried.
- **Two job-runner checks at the same instant, on an org whose runner was never activated, can stop the runner.** ([#43](https://github.com/JVB-Consulting/kerndx/issues/43)) Both can create the runner's `JobRunner` row in the
  Schedule Setting custom setting, and every later check then fails. Repair does not heal it: delete the extra row under Setup, Custom Settings, Schedule Setting, Manage.
  Activating the runner through Health Check creates the row first, which avoids it.
- **A scheduled job can fire at the wrong time when it is written in one time zone and activated in another that is half an hour apart.** ([#44](https://github.com/JVB-Consulting/kerndx/issues/44)) It affects a job that runs as its own scheduled job, not one on the
  job runner, and two kinds of schedule:
  one that lists several minutes (a job at 14:00 and 14:30 India time, activated by a user on GMT, fires at 08:30 and 08:00 and not at 09:00), and one that runs every
  minute of an hour (it runs thirty minutes late). A schedule with a single minute converts correctly, and so does any schedule between zones a whole number of hours
  apart. Until it is fixed, have a user in the job's own time zone activate it, or give each minute its own job.
- **A chain that stalls and is never aborted is never purged** (carried from the 1.7 notes; [#45](https://github.com/JVB-Consulting/kerndx/issues/45)). The retention job ages chain records on their completion timestamp, and
  only a terminal outcome (including abort) sets it. This is deliberate: it protects the recovery state of a chain that may still be resumable. Abort a permanently
  stalled chain if you want it cleaned up. In 1.8, a stalled chain the watchdog will not run again ends `Failed` with a completion timestamp, so it ages out like any
  other ended run; a chain left Stalled, for example while the watchdog is not scheduled, is still kept.

One known issue from the 1.7 notes is fixed: a deep link into a still-running chain no longer freezes the end of its log window (see the Log Console fixes under
[Smaller fixes](#smaller-fixes)).

## Upgrading & compatibility

1.8 is **backward-compatible at the API level**. The upgrade is the standard package upgrade: nothing has to be done before you install, and no data is migrated.
Some behaviour changes below ask you to change code, settings or records after the upgrade; each says what. Read them before you upgrade.

**The platform moves to Winter '27.** 1.8 is built on API 68.0 (Winter '27), up from API 67.0 (Summer '26). What that changes for your code is under
[Ready for Winter '27](#ready-for-winter-27).

**The global Apex signatures are purely additive.** No existing global member is removed or changed in signature; what some of them do changes, as listed
below. The twenty-seven additions are in
[New in the Apex API](#new-in-the-apex-api): `API_Outbound.getRetryableStatusCodes()` and `getRetryableExceptionTypes()`, `DML_Builder.withRetryOnLock()` in two
forms and `DML_Builder.expectRefusal(StatusCode)`, `FLOW_LoggerLog.DTO_Request.flowName`, the new `FLOW_RetryApiIssues` class, `LOG_Builder.rootCorrelationId`,
`QRY_Builder.Builder.withCache(UTIL_Cache.Scope, Integer)` and `withoutCache()`, the new `SCHED_JobRunner` class,
`SEL_Base.cacheScope()` and `cacheTimeToLiveSeconds()`, `TST_Factory.insertUser` and `insertUsers` in two forms each, `TST_Mock.registerNext` in two forms,
`UTIL_Exceptions.PermanentFailureException` and `RequestRefusedException`, five cursor-limit factories on `UTIL_Limits`, and `UTIL_String.joinSorted`.

**The metadata surface is additive.** Nineteen new fields: one on `ApiIssue__c` (`ExternalSystemMayHaveActed__c`), four on `AsyncChainExecution__c` (`ElapsedMs__c`,
`LastManualRetryAt__c`, `LaunchCorrelationId__c`, `RootCorrelationId__c`), three on `LogEntry__c` (`Origin__c`, `Source__c`, `RootCorrelationId__c`), the same
three on the `LogEntryEvent__e` platform event, and eight on
`ScheduledJob__c` (`ExecutionMode__c`, `RunPriority__c`, `OverlapPolicy__c`, `NextRunAt__c`, `LastRunAt__c`, `LastRunOutcome__c`, `LastRunReason__c`, `LastRunJobId__c`).
Three new custom permissions (`ManageJobRunner`, `RetryApiIssue`, `DeleteApiRecords`), three new permission sets
(`JobRunnerManagement`, `ApiIssueResolver` and `ComponentAccess`, all assigned to nobody), one new trigger (on `BatchApexErrorEvent`), ten new
configuration records (the `ScheduledJobRunner` and `BypassApiRecordDeleteGuard` feature flags, the built-in rule that turns
the second on for holders of Delete API Records, the `JobRunnerCheckLimit` job setting, the trigger setting and trigger action
for the batch failure listener, two trigger actions that refuse deleting an API call or an API issue, and two that refuse a
chain run status change the framework would not make), one new list view (**Aborted**, on API Calls), one new list action
(**Retry Selected**, on API Issues) with the `RetrySelectedApiIssues` flow behind it, and 183 new Custom Labels. Nothing is
removed or renamed. On a new install, `ApiIssue__c` and `LogEntry__c` default to Private; an upgrade keeps your org's default.
The packaged Kern Administrator permission set grants Read on every new field on the chain execution, log entry and scheduled
job objects, Read and Edit on `ApiIssue__c.ExternalSystemMayHaveActed__c`, the `RetryApiIssue` and `DeleteApiRecords`
permissions, and the Apex classes behind the Health Check, the API Test Harness and the `kern/featureFlag` module; Kern API Issue
Resolver grants Read on the new API issue field and View All Records on API issues and API calls;
both grant access to the `RetrySelectedApiIssues` flow; and Kern Async Chain Monitor Read Only grants Read on the four new chain
fields.

**After the upgrade: six short steps in Setup.** A package upgrade delivers code, fields, actions, flows and permission sets, but page layouts,
list view columns, search layouts and sharing defaults belong to your org once the object is first installed, and a later version never overwrites
them. A fresh 1.8 install has all of the following; an org upgraded from 1.7 has them only once you do them. Each is a minute's work.

1. **Retry Selected on the API Issues list.** Open Object Manager, then API Issue, then Search Layouts for Salesforce Classic, edit the List View
   layout, and add Retry Selected to its quick actions. In source it is one line in the object's search layouts:
   `<massQuickActions>kern__RetrySelected</massQuickActions>`. Until then, Retry on each issue's record page works as before. Resolvers who are not
   administrators also need the Run Flows user permission to see the action; see
   [Retry on an API issue needs the Retry API Issue permission](#retry-on-an-api-issue-needs-the-retry-api-issue-permission).
2. **API Issue and Log Entry sharing defaults.** 1.8 installs both objects Private; an upgrade keeps your Public Read/Write. Open Sharing Settings,
   edit the Organization-Wide Defaults, set API Issue and Log Entry to Private, and save. Sharing recalculates in a few minutes on a small org.
3. **The new fields on the Async Chain Execution layout.** Open Object Manager, then Async Chain Execution, then Page Layouts, and add Elapsed (ms),
   Last Manual Retry At, Launch Correlation Id and Root Correlation Id to the layout.
4. **The new fields on the Log Entry layout.** The same for Log Entry: add Origin, Source and Root Correlation Id.
5. **The new field on the API Issue layout.** The same for API Issue: add External System May Have Acted. The Lightning record page the package
   ships already shows it; the layout matters where a page is built from the layout, such as a page of your own.
6. **Elapsed (ms) in place of Duration (ms) on the chain execution list.** On the Async Chain Executions tab, open the All list view, choose Select
   Fields to Display under the list view controls, and swap Duration (ms) for Elapsed (ms); then, in Object Manager, Async Chain Execution, Search
   Layouts, make the same swap in the Default Layout and Search Results.

**Behaviour changes to note on upgrade** (each links to its explanation):

- **[withoutSecurity() now also bypasses record sharing.](#withoutsecurity-now-also-bypasses-record-sharing)** If you relied on it to keep the calling class's sharing,
  switch to `withSystemMode()`. With it, `toQueryLocator()` honours `bypassSharing()`, and paged and cursor reads are never served from the query cache.
- **[toCursor() now honours the sharing setting.](#tocursor-now-honours-the-sharing-setting)** `.bypassSharing().toCursor()` now reaches every row.
- **[A cached read must state its sharing setting.](#a-cached-read-must-state-its-sharing-setting)** A system-mode read with `withCache` and no sharing call is no longer
  cached.
- **[A user-mode withCache read is now cached for the transaction.](#a-user-mode-withcache-read-is-now-cached-for-the-transaction)** Search for `withCache(` on
  user-mode reads; where the same object is written outside `DML_Builder` and read back through the same call in one transaction, use `withoutCache()` or remove the call.
  A system-mode `withCache` read with no Platform Cache space to keep it is now kept in memory for the transaction.
- **[The Platform Cache health checks say what happens to query caching.](#the-platform-cache-health-checks-say-what-happens-to-query-caching)** The results are
  unchanged; the detail text is longer.
- **[Saving several cache values at once saves none when one is too large.](#saving-several-cache-values-at-once-saves-none-when-one-is-too-large)** When `putAll` returns
  `false` because a value is too large, none of that call's values are cached; store the large value on its own.
- **[Hand-set credential headers are not stored with the call record.](#hand-set-credential-headers-are-not-stored-with-the-call-record)** A retry in a later transaction
  parks instead of replaying the credential; an API issue opened before 1.8 for such a call is not matched again, so close it by hand.
- **[send() never returns null.](#send-never-returns-null)** A status of `0` means no response came back.
- **[A key you give withIdempotencyKey() is sent when a handler makes the call.](#a-key-you-give-withidempotencykey-is-sent-when-a-handler-makes-the-call)**
  A keyed POST or PATCH through `useHandler(...).invoke()` now sends the key and is retried after a 500, 502 or 504.
- **[withCircuitBreaker(name) uses the breaker you name.](#withcircuitbreakername-uses-the-breaker-you-name)** A call that passes a name now keeps its own breaker;
  calls with no name are unchanged.
- **[Only the "try later" statuses are retried by default.](#only-the-try-later-statuses-are-retried-by-default)** Only 408, 425, 429, 500, 502, 503 and
  504 retry; add your external system's "try later" status in `getRetryableStatusCodes()`. On a `kern.UTIL_HttpClient` call, `retryOn(...)` now also limits the
  scheduled retry.
- **[A server error on a request that is not safe to repeat is not sent again.](#a-server-error-on-a-request-that-is-not-safe-to-repeat-is-not-sent-again)** A 500,
  502 or 504 on a POST or PATCH with no idempotency key ends `Failed`; give the call a key if the external system honours one.
- **[A failure after a successful response is not sent again.](#a-failure-after-a-successful-response-is-not-sent-again)** A throw in `parseResponse()` or
  `onSuccess()` after a success ends the call `Failed` instead of sending the request again, unless you listed the exception type and the request is safe to repeat.
- **[A call that fails in your own code reads Failed, not Retry.](#a-call-that-fails-in-your-own-code-reads-failed-not-retry)** Anything that looks for `Retry` to
  find these calls should look for `Failed`.
- **[An open circuit schedules a call with retry budget left.](#an-open-circuit-schedules-a-call-with-retry-budget-left)** Such a call waits for the cool-off instead
  of ending `Aborted`; a callout that got no response counts towards opening the circuit.
- **[Your commit hooks run once per attempt when a row lock is retried.](#your-commit-hooks-run-once-per-attempt-when-a-row-lock-is-retried)** An override that counts,
  sends or writes outside the commit can run twice.
- **[Three messages that stop an outbound call before it is sent now come from labels.](#three-messages-that-stop-an-outbound-call-before-it-is-sent-now-come-from-labels)** Code or
  tests that match the old English text of those three messages should read the label instead.
- **[Retry on an API issue needs the Retry API Issue permission.](#retry-on-an-api-issue-needs-the-retry-api-issue-permission)** A user who is refused after the
  upgrade needs the Kern API Issue Resolver or Kern Administrator set, or your own set with the permission added.
- **[Retry on one issue checks that its service is running.](#run-many-failed-calls-again-from-the-api-issues-list)** Pressing Retry on an API issue whose service is
  paused or switched off now sends nothing and leaves the issue open, with a message, where it used to try the call and, when the service logs issues, log a new open
  issue. Switch the service back on, then press Retry.
- **[A resolved issue always records when it was resolved.](#run-many-failed-calls-again-from-the-api-issues-list)** The Resolved Date on an API issue is now filled
  by Retry, Retry Selected and a later successful call for the same request, not only by a request run again in your org. A report or list view on it now counts those issues;
  issues resolved before the upgrade keep a blank date.
- **[API issues and log entries are private on a new install.](#api-issues-and-log-entries-are-private-on-a-new-install)** An upgraded org keeps
  Public Read/Write until you change it, and resolvers see every issue through their permission set. Only a user for whom the `BypassApiRecordDeleteGuard` flag is
  on can delete an API call or an API issue; out of the box that is anyone with the Delete API Records permission, which Kern Administrator gives. Run a scheduled
  purge of those records as such a user. `kern.SEL_ApiIssue.findByFailedApiCall` returns every user's open issues for the request, whatever your org's sharing
  default.
- **A call made through a handler records one issue when it fails**, where it used to record a second issue as well. That covers `useHandler(...).invoke()`. See
  [Outbound calls](#outbound-calls-an-answer-every-time-and-no-stored-credentials).
- **[A handler's canned answer no longer stands in outside a unit test.](#a-handlers-canned-answer-no-longer-stands-in-for-a-real-call-outside-a-unit-test)** A
  `useHandler(...)` call with a `defaultMockBody` now makes its real call in production and sandboxes.
- **[A callout reaches the real endpoint inside an Apex integration test.](#a-callout-through-the-framework-reaches-the-real-endpoint-inside-an-apex-integration-test)**
  Register a mock through `kern.API_MockFactory` if you want one there.
- **[Every chain run has a tracking ID of its own.](#every-chain-run-has-a-tracking-id-of-its-own)** The first chain in an action no longer has the action's ID in its
  Correlation ID field; match on Launched Under or Root Correlation ID instead.
- **[The typed chain status reports elapsed time the way the Chain Monitor does.](#the-typed-chain-status-reports-an-elapsed-time-the-way-the-chain-monitor-does)**
  `durationMs` gains values for stalled runs and runs that ended without a stored duration, and a live value moves in whole-second steps.
- **[A stalled chain runs a step again only when that is safe.](#a-stalled-chain-runs-a-step-again-only-when-that-is-safe)** A stalled step that had started is run
  again only if `isIdempotent()` returns `true`; otherwise the chain ends `Failed` with a message saying what to check. Declare `isIdempotent()` on every step that is safe
  to run twice, and on an org with a slow queue raise the watchdog's `StaleThresholdMinutes`.
- **[A chain run that has ended stays ended.](#a-chain-run-that-has-ended-stays-ended)** A run whose completion or error handler could not be started keeps its
  Completed or Failed status and its end time, and the handler is not run later. A run left Stalled with an end time by an earlier version can be repaired with the
  script in that section.
- **[An API step stops retrying when the external system may have acted.](#an-api-step-stops-retrying-when-the-external-system-may-have-acted)** A POST or PATCH step
  sent without an idempotency key is not run again after no response, a 500, 502 or 504, or a success followed by a failure; name the status in the step's
  `retryOn(...)` to keep retrying it.
- **[A hierarchy deeper than its depth limit stops with an error.](#a-hierarchy-deeper-than-its-depth-limit-stops-with-an-error)** `propagateToDescendants` and
  `calculateUltimateParents` with descendants throw instead of leaving the deepest records out; raise the limit with `withMaxDepth`.
- **[Permission set assignments from one call save together.](#permission-set-assignments-from-one-call-save-together)** One failing assignment leaves none of that call's
  saved.
- **[A cleared mock queries the database again.](#a-cleared-mock-queries-the-database-again)** Register an empty list if a test needs an empty answer.
- **[DML failures now log once, from one place.](#dml-failures-now-log-once-from-one-place)** New ERROR entries for all-or-nothing failures and swallowed partial-mode
  exceptions, filed under `DML_Transaction.commitWork`.
- **[A batch-size record is found by your handler's name.](#a-batch-size-record-is-found-by-your-handlers-name)** Rename a record named after the old internal key.
- **[Batch failures now log twice when your code already logged them.](#batch-failures-now-log-twice-when-your-code-already-logged-them)** Expect the extra ERROR entry.
- **A batch size that does not fit its chunk writes a WARN entry** when the batch is launched. See
  [Batch jobs](#batch-jobs-platform-reported-failures-and-batch-sizes-that-fit).
- **An inbound handler whose own error handling throws answers 500.** When a `handleError()` override throws, the caller now gets a 500 where it used to get a 200
  with an empty body. If a system that calls your org treated that empty 200 as success, tell its owners to expect a 500. See [Smaller fixes](#smaller-fixes).
- **[The Health Check no longer asks for a Trusted URL.](#the-health-check-no-longer-asks-for-a-trusted-url)** Scripts or runbooks that expect a Trusted Site row need
  updating.
- **[A job in its own mode no longer offers "Every N Minutes".](#a-job-in-its-own-mode-no-longer-offers-every-n-minutes)** Put such a job on the job runner.
- **[KernTriggerMustDelegate checks the whole trigger body.](#kerntriggermustdelegate-checks-the-whole-trigger-body)** Triggers with top-level logic, or no dispatcher
  call, start failing this priority-1 rule.
- **[A new scanner rule reports a governor limit read directly.](#a-new-scanner-rule-reports-a-governor-limit-read-directly)** A scan through the full or
  combined ruleset gains one priority-5 finding for each direct read of `Limits.getQueries()` or one of its siblings; read the limit through `kern.UTIL_Limits`.
- **The Log Console's body search is literal.** Several words are found as a phrase, and a two-character term no longer matches every entry's body. See
  [The Log Console pages, searches literally and fits a narrow screen](#the-log-console-pages-searches-literally-and-fits-a-narrow-screen).
- **Messages from the Write Detailed Log Messages Flow action start with a Flow marker**, as the other Flow actions' already did: `[Flow]`. Update any filter that
  matches the message text exactly.
- **A line logged while a web-service handler is still being set up no longer carries the HTTP method.** Every other line of the call carries both the service and
  the method.
- **[The Flow email action refuses to log an email to a User through standard activity
  logging.](#the-flow-email-action-refuses-to-log-an-email-to-a-user-through-standard-activity-logging)** A flow that asks
  for it gets a clear message, rather than failing with a flow fault.
- **The Chain Monitor's Restarted from row is gone.** The Launched under row links a restart to the run it was restarted from. See
  [The Chain Monitor marks manual retries and sorts by elapsed time](#the-chain-monitor-marks-manual-retries-and-sorts-by-elapsed-time).
- **[Two new chain fields need Read for a cloned permission set or a profile.](#two-new-chain-fields-need-read-for-a-cloned-permission-set-or-a-profile)** If
  your users get Chain Monitor access that way, grant them Read on Last Manual Retry At and Elapsed (ms) to see the two fields on the record page, in list views and in
  reports.
- **[Write your pipeline workflows again from the new templates.](#the-ci-workflows-the-pipeline-writes-no-longer-let-pull-request-text-run-as-code)** Until you
  do, a crafted branch name or pull-request title can still run commands in the workflows an earlier version wrote. The new templates keep pull-request text out
  of scripts and Slack messages and pin every action to an exact commit. Run `node .kerndx-pipeline/bin/kerndx upgrade`, which backs each file up to `.bak`
  first; until then `node .kerndx-pipeline/bin/kerndx doctor` reports them as changed.
- **[The framework ruleset runs the Kern rules again under Code Analyzer 5.16 and later.](#the-framework-ruleset-runs-the-kern-rules-again-under-code-analyzer-516-and-later)**
  A CI gate that scans with the framework-side file and has been passing with no Kern findings may now report some.
- **[The Validation Errors component's click event stays with the component.](#the-validation-errors-components-click-event-stays-with-the-component)** If your own
  component listens for `fieldclick` on an element above the `<kern-validation-errors>` tag, move the listener onto that tag itself.
- **[Calls an earlier version left waiting for a retry are not changed by the upgrade.](#calls-an-earlier-version-left-waiting-for-a-retry-are-not-changed-by-the-upgrade)**
  Find them, then retry or resolve each, or mark them Failed with the script in that section.

**Log entries written before the upgrade** carry no origin, no source and no root correlation ID. They are still found by their correlation ID, and are left out of the Top
sources card until they age out.

**One optional post-install step activates the job runner:** assign the Kern Job Runner Management permission set to the user who will activate the runner and to whoever
manages schedules. The user who activates it also needs access to Health Check, which the set does not give. Then activate it from Health Check. Until you do,
every scheduled job keeps running as its own scheduled job, exactly as before.

**Choose Install for Admins Only when installing or upgrading**, as in 1.7. Installing for All Users writes packaged custom permissions into every profile, which silently
grants capabilities you meant to hand out deliberately.

Everything in the [Kern 1.7 Release Notes](./Release%20Notes%20-%20Kern%201.7.md) and earlier still applies; 1.8 changes only what is on this page.
