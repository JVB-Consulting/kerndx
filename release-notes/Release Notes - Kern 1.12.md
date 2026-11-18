# Kern 1.12 Release Notes

**Platform:** Salesforce API 68.0 (Winter '27) · **Namespace:** `kern` (rebrandable via [Installation](../docs/Installation.md))
**Release status:** released. Kern 1.12.0-3 is the production-installable 1.12 line.

## The headlines

> **What to check before and after the upgrade**
>
> Most of 1.12 works when you upgrade, with nothing to do. Check these, in case one applies to you:
>
> **Check before you upgrade**
>
> 1. **If a KernDX validation rule on API Call or API Issue has no context class, on the rule or on its group:** check it
>    before you upgrade. Such a rule was skipped; it now runs, and an Error rule whose formula is true stops the save.
>    [Details](#trigger-actions-on-kerndxs-own-objects)
> 2. **If you copied a validation rule example from the guides that compares a picklist field with `=` or `<>`:** wrap
>    the field in `TEXT()`, for example `TEXT(newRecord.Type) = 'Enterprise'`.
>    - KernDX cannot build such a formula, so the rule never ran.
>    - Each save went through and wrote an ERROR log entry saying the rule's formula evaluation failed.
>      [Details](#guides-corrected)
> 3. **If a Public Group strategy's Target holds a group's label:** put the group's API name (Group Name in Setup) there
>    instead.
>    - A label shared by two public groups, or the label of a queue, no longer matches.
>    - A Target that is the API name of one public group and the label of another now follows the group with that API
>      name, with no warning. [Details](#feature-flags-a-public-group-is-found-by-its-api-name)
> 4. **If an object has more than one trigger setting:** check Apply Masking on all of them before you upgrade. From
>    1.12, masking runs when any of them has it ticked, so an object whose masking stayed off only because of the order
>    the settings were read is masked after the upgrade. [Details](#fixed-masking-with-more-than-one-trigger-setting)
> 5. **If you have trigger code or post-trigger actions on API Call, API Issue, Scheduled Job or Async Chain Execution:**
>    - If you wrote your own trigger on one of these objects that hands its work to the framework, delete it when you
>      upgrade and move its logic to trigger action rows. Otherwise its after-event actions run twice.
>    - Check that each post-trigger action is safe to run more than once: one save now runs each of them 2 times.
>      [Details](#trigger-actions-on-kerndxs-own-objects)
> 6. **If a post-trigger action row names the trigger setting of a custom object, or a change event with no SObject
>    Type:** check it before you upgrade. Such a row has never run; from 1.12 it runs on every save (or change event) of
>    that object. Tick Bypass Execution on, or delete, any row you no longer want.
>    [Details](#fixed-post-trigger-actions-scoped-to-a-custom-object-or-a-change-event)
> 7. **If a post-trigger action row names a change-event trigger setting whose SObject Type holds a standard object:**
>    check it before you upgrade.
>    - Until now it ran after saves of that object and never after a change event.
>    - From 1.12 it runs after the change event named in Object API Name Override, and no longer after those saves, as
>      the setting's trigger actions do. [Details](#fixed-post-trigger-actions-scoped-to-a-custom-object-or-a-change-event)
>
> **Permissions and configuration**
>
> 8. **If people or automation without Manage Job Runner look after jobs on the job runner:** give them the permission.
>    - Changing such a job, or deleting one that is on the job runner, now needs it.
>    - This also holds when a trigger action, or a flow that one started, saves the job. Automation that did this quietly
>      in 1.11 is now refused. [Details](#every-change-to-a-job-on-the-job-runner-needs-manage-job-runner)
> 9. **If a trigger action, or a flow it started, saves a Scheduled Job with its own schedule (not on the job runner):**
>    the job is now scheduled by that save, where 1.11 skipped it. Check that you want such jobs to run.
>    [Details](#every-change-to-a-job-on-the-job-runner-needs-manage-job-runner)
> 10. **If a job with its own schedule (not on the job runner) was saved from another time zone before the upgrade:** save
>     it again with a change, for example switch Active off and then on. Until then it keeps its old times. That save can
>     now be refused. [Details](#a-job-keeps-its-times-in-another-time-zone-or-is-refused)
> 11. **If you purge chain runs by Completed At:** the purge now also deletes runs that have stayed Stalled for longer than
>     its number of days, so check that you do not need old stalled runs.
>     - If the purge runs as a user without Kern Administrator, give that user read access to Status and Stalled At on the
>       chain run object. [Details](#async-chains-a-run-that-stays-stalled-is-purged)
>
> **Security changes that can refuse working code**
>
> 12. **If a read uses `bypassSharing()` without `withSystemMode()`:** check it. Such a read can now be refused in
>     three cases.
>     - **A filter or sort on a field the user cannot read, inside a function or through a parent.** Do not filter or
>       sort on such a field, or add `withSystemMode()`.
>       [Details](#bypasssharing-checks-fields-inside-functions-and-through-parents)
>     - **Selected fields or a child query through a lookup field or an object the user cannot read.** These reads
>       returned rows in 1.10 and 1.11:
>       - a selected path through a lookup field, such as `What.Name` without read on `WhatId`;
>       - a selected path through a parent object, such as `Account.Name` on a contact without read on Account;
>       - a `TYPEOF` whose lookup, or an object after `WHEN`, the user cannot read;
>       - a child query added with `subselect()` whose relationship's lookup field the user cannot read.
>
>       Give the user read access to that field or object, take the related fields (or the child query) out of the
>       read, or add `withSystemMode()`.
>     - **Selected text KernDX cannot check, for every user.** Add a child query with `subselect()`, not as text, and
>       write each `TYPEOF` as a field of its own.
>       [Details](#bypasssharing-refuses-a-read-through-a-lookup-the-user-cannot-read)
> 13. **If you build `kern.PROC_ExecuteDML` or `kern.PROC_UpdateFields` with an access level that names a permission set:**
>     check that the running user, with that set, may read the rows and make the save. It no longer works with more access
>     than you asked for.
>     [Details](#a-queued-save-keeps-an-access-level-that-names-a-permission-set)
> 14. **If an active masking target names a Caller Class on an object other than API Call or API Issue:** clear the Caller
>     Class, or make the target inactive. Such a target masked nothing, and saving it is now refused.
>     [Details](#data-masking-a-caller-class-only-where-it-can-apply)
> 15. **If you wrote a pattern (`Regex`) masking rule with `^`, `$`, `\A`, `\Z`, `\z` or `\G` on an API request or
>     response field:** to have your rule mask long bodies again, write `(?s).+` for a whole value, or take the anchor out.
>     - Bodies longer than 131,072 characters are now saved as `[MASKING_FAILURE]`.
>       [Details](#data-masking-an-anchored-pattern-on-a-long-api-body)
>
> **Your Apex code**
>
> 16. **If your code reads the result of a save made with `allowPartial()`:** check that it handles a failed result. When
>     an error stops such a save, `isSuccess()` is now `false`.
>     [Details](#a-partial-save-stopped-by-an-error-now-reports-a-failure)
> 17. **If your code bypasses a trigger action by its bare class name:** check that each such bypass is one you mean. It
>     now takes effect on the actions the package ships.
>     [Details](#a-bypass-by-the-bare-class-name-reaches-a-packaged-trigger-action)
> 18. **If your code or a flow moves a chain run into Stalled:** set Stalled At in the same save. Without it the save is
>     now refused.
>     - The Kern Administrator permission set can set Stalled At.
>     - Any other user the save runs as needs edit access to Stalled At from a permission set of your own, or the save
>       must run in system mode. [Details](#async-chains-a-run-that-stays-stalled-is-purged)
> 19. **If a processor implements `kern.IF_Async.Finishable` and runs under `BATCH`:** its fields now keep their values
>     from one chunk to the next, and `finish` is skipped when a chunk fails. Clear a list or map that `execute` fills at
>     its start, or mark it `transient`. Do any work a failed chunk needs in `execute`.
>     [Details](#finish-runs-only-when-every-chunk-succeeded)
> 20. **If you force `PARALLEL_QUEUEABLES` for a `kern.IF_Async.Finishable` processor:** use `BATCH`, `CHAINABLE` or
>     `AUTO`. Such a request now throws an `IllegalArgumentException` and starts no job.
>     [Details](#a-finishable-processor-cannot-be-forced-to-run-as-parallel-jobs)
> 21. **If your code catches a specific Salesforce exception from `kern.UTIL_AsynchronousJobLauncher.process`:** catch
>     `Exception` and read `getCause()`. A queueable job Salesforce refuses to start now arrives as a KernDX exception.
>     [Details](#a-job-salesforce-refuses-to-start-arrives-as-a-kerndx-exception)
> 22. **If your code calls `execute` on `kern.PROC_UpdateFields` itself and sets other fields on the records:** save
>     those fields yourself. It now saves only each record's Id and the fields in its list of updates.
>     [Details](#field-updates-save-only-the-fields-they-set)
>
> **Outbound calls**
>
> 23. **If your code or flow calls the Invoke Callout Asynchronously action
>     (`kern.FLOW_CallApiAsync.invokeApiCallAsynchronously`):** do not rely on a refused start throwing an error, or on a
>     call at Retry staying at Retry. The action now saves such a call as Retrying before the send starts.
>     [Details](#a-refused-outbound-send-waits-at-retry-and-the-flow-action-writes-retrying)
> 24. **If your automation counts on a save failing when Salesforce refuses to start an outbound send:** it no longer
>     fails. The calls are saved at Retry with a Next Retry time, and the Retry Outbound Api Call flow sends them at that
>     time. [Details](#outbound-calls-at-the-daily-background-job-limit)
> 25. **If a report or integration reads Triggering Record ID on API issues:** it can now hold up to 80 characters, where
>     it held 18. [Details](#find-the-api-calls-and-issues-of-one-record)
> 26. **If a flow or Apex code reads `queuedCount`, `success` or `jobId` from the Retry API Issues action:** `queuedCount`
>     can now be lower. When no request is left to send, `success` is false and `jobId` is empty. A flow that branches on
>     them can now take another path. [Details](#bulk-retry-skips-a-request-with-an-issue-that-failed-permanently)
>
> **Logging**
>
> 27. **If your log level is ERROR in production:** bypass entries are now saved. Each one publishes a platform event. To
>     stop them, turn off the `BypassAudit_Enabled` feature flag. [Details](#bypass-audit-kept-at-every-log-level)
> 28. **If your code calls `kern.DML_Transaction.setAccessLevel(AccessLevel.SYSTEM_MODE)`, `commitWork(false)`, or builds
>     `kern.PROC_ExecuteDML` with `AccessLevel.SYSTEM_MODE`:** expect bypass entries.
>     - A commit writes one for each object it saves, and only when it saves records.
>     - The processor writes one when it is built, naming the operation but no object.
>     - A test of yours that sets `kern.LOG_Builder.ignoreTestMode = true` and counts warning log rows after one of these
>       saves finds more rows. Other tests write no bypass entries.
>     - To keep the old count in that test, call `kern.TST_Factory.newDisabledFeatureFlag('BypassAudit_Enabled');` first.
>       [Details](#the-three-lower-level-saves-now-write-a-bypass-entry)
> 29. **If a report, list view, alert or monitor looks for KernDX text in the log or on the Apex Jobs page:** check that
>     it still finds what it looks for.
>     - The warnings a bulk retry writes start "N API issue(s)" where they started "N failure replay(s)".
>     - A chunk of the daily login job (`kern.SCHED_ProcessLoginHistory`) that fails with an error Apex can catch no
>       longer fails the batch: watch for its ERROR entry.
>     - A launch with a delay that Salesforce refuses when the delay ends writes one error entry, in a new place and with
>       a new message.
>     - A chain run no longer gets the text `Parked: no query budget`.
>     - The Apex Jobs page lists the batch job of a `kern.IF_Async.Finishable` processor under `BATCH` as
>       `UTIL_StatefulAsynchronousBatch`.
>     - [Details](#behaviour-changes-at-a-glance), in the API issues, Async processing and Async chains rows.
>
> **Tests**
>
> 30. **If your tests mock API calls or API issues with `kern.TST_Mock`:** set Triggering Record Index, and every other
>     value the read searches for, on each mock.
>     - A read with conditions now returns only the mocks that match, an answer scripted with `registerNext` included.
>     - On every object with a formula context, a condition on a picklist field is now checked too.
>       [Details](#your-tests-mocked-api-calls-and-api-issues-are-filtered)
>
> **Trigger actions**
>
> 31. **If you set a performance threshold on a trigger setting, a trigger action or a post-trigger action, or ticked
>     both Suppress and Force Performance Logging on one trigger action:** check the slow-action log entries you get
>     after the upgrade.
>     - A threshold on a trigger setting: its actions now follow it, so they can log more or less.
>     - A threshold on an action, with Enable Trigger Performance Logging in Log Setting off: that action now logs.
>     - Both Suppress and Force ticked: that action no longer logs. [Details](#trigger-performance-logging-thresholds-work-and-suppress-wins)
>
> **Pipeline**
>
> 32. **If you turned on the pipeline's ingress-bypass alert or the reviewers-file check:** run `kerndx upgrade` with the
>     new pipeline bundle. Until you do, the alert fires on every merge, and the reviewers-file check takes the newest
>     `ajv-cli` 5.x release on each run. [Details](#the-pipeline)

**Kern 1.12 closes gaps in sharing checks, data masking and job runner permissions: read the upgrade list before you
install.** Some code and settings that worked in 1.11 are now refused. The masking, job runner and `bypassSharing()`
items in the box above say what to check.

- A read with `bypassSharing()` and no `withSystemMode()` now refuses a filter or sort on a field the user cannot read,
  even inside a function or reached through a parent, and refuses related fields through a lookup field or an object the
  user cannot read.
- Masking now runs on an object when any of its trigger settings has Apply Masking ticked.
- A pattern masking rule with a start or end anchor no longer runs on an API body longer than 131,072 characters: the
  field is saved as `[MASKING_FAILURE]`.
- An active masking target that names a Caller Class on an object other than API Call or API Issue is refused.
- Every change to a job on the job runner now needs the Manage Job Runner permission.

Read more: [Queries: bypassSharing() checks more of your filters](#queries-bypasssharing-checks-more-of-your-filters),
[Fixed: masking with more than one trigger setting](#fixed-masking-with-more-than-one-trigger-setting),
[Data masking: an anchored pattern on a long API body](#data-masking-an-anchored-pattern-on-a-long-api-body),
[Data masking: a Caller Class only where it can apply](#data-masking-a-caller-class-only-where-it-can-apply) and
[Every change to a job on the job runner needs Manage Job Runner](#every-change-to-a-job-on-the-job-runner-needs-manage-job-runner).

**Kern 1.12: when Salesforce refuses to start the send of an outbound call, most often at the daily job limit, the save
that queued the call no longer fails.** The call waits and is sent once Salesforce starts jobs again. There is nothing to
do unless your code or flow calls the Invoke Callout Asynchronously action, or your automation counts on the save
failing.

- The call is saved at Retry with a Next Retry time, and the Retry Outbound Api Call flow sends it at that time.
- The wait starts at 15 minutes and doubles with each refusal, up to 240 minutes.
- When Salesforce refuses a later job of a chained send, or a send run as one batch job, the call is only logged.
- The new Outbound Retry Watchdog, a scheduled job you turn on yourself, finds calls that are never sent again. Read its
  section before you turn it on: its first runs give old calls left at Retry a new Next Retry time, and the Retry
  Outbound Api Call flow then sends them.

Read more: [Outbound calls at the daily background-job limit](#outbound-calls-at-the-daily-background-job-limit) and
[The Outbound Retry Watchdog](#the-outbound-retry-watchdog).

**Kern 1.12: your own trigger actions run on every trigger event of API Call, API Issue, Scheduled Job and Async Chain
Execution.** Until now a row of yours for an after event on these objects never ran. Now, for example, an action can
tell a team when an outbound call fails.

- API Call and API Issue have built-in formula contexts, so an entry formula there works with the context class name left
  blank.
- One save now runs each post-trigger action on these objects 2 times, where it ran once.

What to check:

- Put your rows on a trigger setting of your own for the object: the package's trigger settings are protected.
- A KernDX validation rule on API Call or API Issue with no context class used to be skipped. It now runs, and an Error
  rule whose formula is true stops the save: check such rules before you upgrade.
- Check that each post-trigger action on these objects is safe to run more than once.
- If you wrote your own trigger on one of these objects that hands its work to the framework, delete it when you upgrade
  and move its logic to trigger action rows, or its after-event actions run twice.

Read more: [Trigger actions on KernDX's own objects](#trigger-actions-on-kerndxs-own-objects).

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [The headlines](#the-headlines)
2. [At a glance](#at-a-glance)
3. [Behaviour changes at a glance](#behaviour-changes-at-a-glance)

**Changes that can stop working code or need you to act**

4. [Bypass audit: kept at every log level](#bypass-audit-kept-at-every-log-level)
5. [Scheduled jobs](#scheduled-jobs)
    - [Every change to a job on the job runner needs Manage Job Runner](#every-change-to-a-job-on-the-job-runner-needs-manage-job-runner)
    - [A job keeps its times in another time zone, or is refused](#a-job-keeps-its-times-in-another-time-zone-or-is-refused)
    - [A job restored from the Recycle Bin comes back switched off](#a-job-restored-from-the-recycle-bin-comes-back-switched-off)
    - [The editor keeps a job's time zone](#the-editor-keeps-a-jobs-time-zone)
    - [Health Check shows the job runner's times in your time zone](#health-check-shows-the-job-runners-times-in-your-time-zone)
6. [Trigger actions on KernDX's own objects](#trigger-actions-on-kerndxs-own-objects)
    - [Your tests: mocked API calls and API issues are filtered](#your-tests-mocked-api-calls-and-api-issues-are-filtered)
7. [Outbound calls at the daily background-job limit](#outbound-calls-at-the-daily-background-job-limit)
    - [The Outbound Retry Watchdog](#the-outbound-retry-watchdog)
    - [What KernDX recovers, and what it only logs](#what-kerndx-recovers-and-what-it-only-logs)
    - [A refused launch with a delay has one error entry](#a-refused-launch-with-a-delay-has-one-error-entry)
8. [Async chains: a run that stays Stalled is purged](#async-chains-a-run-that-stays-stalled-is-purged)
9. [Feature flags: a Public Group is found by its API name](#feature-flags-a-public-group-is-found-by-its-api-name)
10. [Queries: bypassSharing() checks more of your filters](#queries-bypasssharing-checks-more-of-your-filters)
    - [Fixed: a read through a lookup the user cannot read is refused](#fixed-a-read-through-a-lookup-the-user-cannot-read-is-refused)
11. [A queued save keeps its permission set](#a-queued-save-keeps-its-permission-set)
12. [Saves tell you why they failed](#saves-tell-you-why-they-failed)
13. [Custom labels in a validation error message](#custom-labels-in-a-validation-error-message)
14. [Bulk retry skips a request with an issue that failed permanently](#bulk-retry-skips-a-request-with-an-issue-that-failed-permanently)
15. [Fixed: masking with more than one trigger setting](#fixed-masking-with-more-than-one-trigger-setting)
16. [Data masking: an anchored pattern on a long API body](#data-masking-an-anchored-pattern-on-a-long-api-body)
17. [Data masking: a Caller Class only where it can apply](#data-masking-a-caller-class-only-where-it-can-apply)
18. [Fixed: post-trigger actions scoped to a custom object or a change event](#fixed-post-trigger-actions-scoped-to-a-custom-object-or-a-change-event)
19. [Trigger performance logging: thresholds work, and Suppress wins](#trigger-performance-logging-thresholds-work-and-suppress-wins)
20. [The pipeline](#the-pipeline)

**Your code**

21. [Changes that can affect code you have written](#changes-that-can-affect-code-you-have-written)
    - [A queued save keeps an access level that names a permission set](#a-queued-save-keeps-an-access-level-that-names-a-permission-set)
    - [bypassSharing() checks fields inside functions and through parents](#bypasssharing-checks-fields-inside-functions-and-through-parents)
    - [bypassSharing() refuses a read through a lookup the user cannot read](#bypasssharing-refuses-a-read-through-a-lookup-the-user-cannot-read)
    - [A call answered by mock data no longer resolves earlier issues](#a-call-answered-by-mock-data-no-longer-resolves-earlier-issues)
    - [A partial save stopped by an error now reports a failure](#a-partial-save-stopped-by-an-error-now-reports-a-failure)
    - [A label in a validation error message is filled](#a-label-in-a-validation-error-message-is-filled)
    - [Field updates save only the fields they set](#field-updates-save-only-the-fields-they-set)
    - [Counts keep the data category filter](#counts-keep-the-data-category-filter)
    - [The epoch date is 1970-01-01 in every time zone](#the-epoch-date-is-1970-01-01-in-every-time-zone)
    - [UTIL_List.partition returns every item](#util_listpartition-returns-every-item)
    - [A bypass by the bare class name reaches a packaged trigger action](#a-bypass-by-the-bare-class-name-reaches-a-packaged-trigger-action)
    - [A job Salesforce refuses to start arrives as a KernDX exception](#a-job-salesforce-refuses-to-start-arrives-as-a-kerndx-exception)
    - [finish() runs only when every chunk succeeded](#finish-runs-only-when-every-chunk-succeeded)
    - [A Finishable processor cannot be forced to run as parallel jobs](#a-finishable-processor-cannot-be-forced-to-run-as-parallel-jobs)
    - [A refused outbound send waits at Retry, and the Flow action writes Retrying](#a-refused-outbound-send-waits-at-retry-and-the-flow-action-writes-retrying)
    - [The batched-call job moves every Batched call](#the-batched-call-job-moves-every-batched-call)
    - [The three lower-level saves now write a bypass entry](#the-three-lower-level-saves-now-write-a-bypass-entry)
    - [getDescribe and getSObjectTypeByName return null for a name that is not an object](#getdescribe-and-getsobjecttypebyname-return-null-for-a-name-that-is-not-an-object)

**New features**

22. [Find the API calls and issues of one record](#find-the-api-calls-and-issues-of-one-record)
    - [Optional: fill Triggering Record Index on rows saved before the upgrade](#optional-fill-triggering-record-index-on-rows-saved-before-the-upgrade)
23. [A read-only permission set for the Log Console](#a-read-only-permission-set-for-the-log-console)

**Other fixes**

24. [Faster saves in an org with many objects](#faster-saves-in-an-org-with-many-objects)
25. [Retry leaves an issue open when mock data answers it](#retry-leaves-an-issue-open-when-mock-data-answers-it)
26. [Async chains: the whole-run performance entry follows Log Setting](#async-chains-the-whole-run-performance-entry-follows-log-setting)
27. [Async chains: the watchdog keeps a query in hand](#async-chains-the-watchdog-keeps-a-query-in-hand)
28. [Code scanning: the inline SOQL rule points to a selector](#code-scanning-the-inline-soql-rule-points-to-a-selector)
29. [Fixed: a formula with no context class name on API Call and API Issue](#fixed-a-formula-with-no-context-class-name-on-api-call-and-api-issue)
30. [Data masking: two JSON values in one value](#data-masking-two-json-values-in-one-value)

**Guides and docs**

31. [Guides corrected](#guides-corrected)
32. [Outbound calls: the breaker default and the longest retry wait](#outbound-calls-the-breaker-default-and-the-longest-retry-wait)
33. [Outbound calls: keep a queued send within 120 seconds](#outbound-calls-keep-a-queued-send-within-120-seconds)
34. [Corrected: commitWork(false) with a permission set](#corrected-commitworkfalse-with-a-permission-set)
35. [Find what you need in the docs faster](#find-what-you-need-in-the-docs-faster)

**The upgrade**

36. [Upgrading & compatibility](#upgrading--compatibility)
</details>

---

## At a glance

Find your row, read across, and follow the link for more. The order is not final; it is set at release.

| # | What's new | Who it's for | In one line |
|---|-----------|--------------|-------------|
| 1 | **[Bypass audit at every log level](#bypass-audit-kept-at-every-log-level)** | Admins · Security | A record of who turned a safety check off is saved at every log level, ERROR included, while logging is on |
| 2 | **[Scheduled jobs](#scheduled-jobs)** | Admins · Developers | A job moved to another time zone keeps its times or is refused. Every change to a job on the job runner, and deleting it, needs Manage Job Runner |
| 3 | **[Trigger actions on KernDX's own objects](#trigger-actions-on-kerndxs-own-objects)** | Developers · Admins | Your trigger action rows on API Call, API Issue, Scheduled Job and Async Chain Execution run on all seven trigger events, and API Call and API Issue have built-in formula contexts |
| 4 | **[Trigger bypass by the bare name](#a-bypass-by-the-bare-class-name-reaches-a-packaged-trigger-action)** | Developers | `bypassAction` with the bare class name of an action the package ships now bypasses that action in an installed org |
| 5 | **[Outbound calls at the daily job limit](#outbound-calls-at-the-daily-background-job-limit)** | Admins · Developers | When Salesforce refuses to start the background send of an outbound call, the save no longer fails: the call waits at Retry and is sent once Salesforce starts jobs again. The new Outbound Retry Watchdog finds calls that are never sent again |
| 6 | **[Async chains](#async-chains-a-run-that-stays-stalled-is-purged)** | Admins | The chain-run purge also deletes runs that have stayed Stalled for longer than its number of days |
| 7 | **[Feature flags](#feature-flags-a-public-group-is-found-by-its-api-name)** | Admins | The Public Group strategy finds a group by its API name, and never picks between two groups with the same label |
| 8 | **[Safer queries with bypassSharing()](#queries-bypasssharing-checks-more-of-your-filters)** | Developers · Security | A filter or sort on a field the user cannot read is refused also inside a function or through a parent, and a read through a lookup or parent object the user cannot read is refused, as Salesforce refuses it |
| 9 | **[A queued save keeps its permission set](#a-queued-save-keeps-its-permission-set)** | Developers · Security | `kern.PROC_ExecuteDML` and `kern.PROC_UpdateFields` built with an access level that names a permission set now save with that level, not with more access than you asked for |
| 10 | **[Saves tell you why they failed](#saves-tell-you-why-they-failed)** | Developers | The new `getFailureMessage()` on a save's result gives the reason. A partial save stopped by an error no longer reports success |
| 11 | **[Labels in validation messages](#custom-labels-in-a-validation-error-message)** | Admins · Developers | Write `{!$Label.MyLabel}` in a KernDX validation rule's error message, and each user sees the label in their own language |
| 12 | **[Bulk retry and permanent failures](#bulk-retry-skips-a-request-with-an-issue-that-failed-permanently)** | Admins · Support · Developers | Retry Selected and the Retry API Issues action skip a request when any of its open issues is on a call that failed permanently or has External System May Have Acted ticked |
| 13 | **[Masking with more than one trigger setting](#fixed-masking-with-more-than-one-trigger-setting)** | Admins · Security | Masking runs on an object when any of its trigger settings has Apply Masking ticked, where the setting read last decided |
| 14 | **[Masking long API bodies](#data-masking-an-anchored-pattern-on-a-long-api-body)** | Admins · Security | A pattern rule with a start or end anchor saves a value longer than 131,072 characters as `[MASKING_FAILURE]`, where it could leave a long API body unmasked |
| 15 | **[Data masking](#data-masking-a-caller-class-only-where-it-can-apply)** | Admins · Security | An active masking target with a Caller Class on an object other than API Call or API Issue is refused when you save it |
| 16 | **[Post-trigger actions on a custom object or a change event](#fixed-post-trigger-actions-scoped-to-a-custom-object-or-a-change-event)** | Admins · Developers | A post-trigger action row scoped to a custom object, or to a change event with no SObject Type, now runs, where it never ran |
| 17 | **[Trigger performance logging](#trigger-performance-logging-thresholds-work-and-suppress-wins)** | Admins · Developers | A trigger setting's performance threshold now works, a threshold you set logs even with Enable Trigger Performance Logging off, and Suppress beats Force |
| 18 | **[The pipeline](#the-pipeline)** | Release managers · DevOps | The ingress-bypass alert no longer fires on every merge, so a real bypass stands out |
| 19 | **[Faster saves in an org with many objects](#faster-saves-in-an-org-with-many-objects)** | Admins · Developers | The first trigger action and the first validation rule check of a transaction no longer read the list of every object in your org. Two object lookups return null for a name that is not an object |
| 20 | **[Retry and mock data](#retry-leaves-an-issue-open-when-mock-data-answers-it)** | Admins · Support · Developers | When mock data answers a retried call, the API issue stays open, and Retry tells you why |
| 21 | **[Chain performance entries](#async-chains-the-whole-run-performance-entry-follows-log-setting)** | Admins | The performance entry for a whole chain run follows the performance settings in Log Setting, and the new Async Chain Performance Threshold (ms) gives chain runs a threshold of their own |
| 22 | **[The chain watchdog](#async-chains-the-watchdog-keeps-a-query-in-hand)** | Admins | When the watchdog runs low on queries, the chains it did not reach keep their status and their place in the queue |
| 23 | **[Code scanning](#code-scanning-the-inline-soql-rule-points-to-a-selector)** | Developers | The KernNoInlineSOQL message tells you to read through a selector |
| 24 | **[A formula with no context class name](#fixed-a-formula-with-no-context-class-name-on-api-call-and-api-issue)** | Admins · Developers | A trigger action row with an entry formula and a blank context class name is accepted on API Call and API Issue |
| 25 | **[Data masking: two JSON values in one value](#data-masking-two-json-values-in-one-value)** | Admins · Security | A JsonKey rule masks every plain value under a matching key in a value that holds two JSON objects one after the other, such as one object per line, where a secret after the first object was saved as it came |
| 26 | **[Find the API calls and issues of one record](#find-the-api-calls-and-issues-of-one-record)** | Developers · Support | Two finders on each of `kern.SEL_ApiCall` and `kern.SEL_ApiIssue` read one record's calls and issues through an indexed field, and an optional script fills it on rows saved before the upgrade |
| 27 | **[A read-only Log Console](#a-read-only-permission-set-for-the-log-console)** | Admins · Support · Security | The new **Kern Log Console Read Only** permission set lets someone read every log entry without being able to change any Kern setting |
| 28 | **[Guides corrected](#guides-corrected)** | Everyone | Samples that did not compile or run in your org are fixed, other guide text is corrected, and every guide is shorter and opens with the task you came for |
| 29 | **[The breaker default and the longest retry wait](#outbound-calls-the-breaker-default-and-the-longest-retry-wait)** | Admins · Developers | The field help and the guides now say that a blank Circuit Breaker Failure Threshold means 5, and that a Retry Backoff (sec) above 300 works as 300 |
| 30 | **[A queued send within 120 seconds](#outbound-calls-keep-a-queued-send-within-120-seconds)** | Admins · Developers | Keep the job size times your longest handler timeout under 120 seconds, and set a timeout on every handler. Known issue: Retry Selected on many inbound issues ([kerndx#39](https://github.com/JVB-Consulting/kerndx/issues/39)) |
| 31 | **[commitWork(false) with a permission set](#corrected-commitworkfalse-with-a-permission-set)** | Developers · Security | The DML and Security guides now say that `commitWork(false)` does not ignore record sharing for a save with a permission set. Nothing changes in what your org does |
| 32 | **[Find what you need in the docs faster](#find-what-you-need-in-the-docs-faster)** | Everyone | Search finds a method by name, each docs area has its own menu, and a new page maps plain Apex to KernDX |

---

## Behaviour changes at a glance

Every change that can affect code, configuration or a check you own, and what to do about it. Each row links to the full explanation.

| Area | What changed | What to do | Read more |
|---|---|---|---|
| Logging | Bypass entries are saved at every log level while logging is on. At ERROR, where none was saved, each bypass now saves an entry and publishes one `LogEntryEvent__e` platform event. The framework's own saves of API issues and scheduled jobs no longer write one | Nothing, if you want the record. To stop it, turn off the `BypassAudit_Enabled` feature flag | [Bypass audit: kept at every log level](#bypass-audit-kept-at-every-log-level) |
| Logging | `kern.DML_Transaction.setAccessLevel(AccessLevel.SYSTEM_MODE)`, `kern.DML_Transaction.commitWork(false)` and `kern.PROC_ExecuteDML` built with `AccessLevel.SYSTEM_MODE` now write a bypass entry, as the builders do: a commit writes one for each object it saves, only when it saves records, and the processor writes one when it is built, with the operation and no object | Expect more bypass entries and platform events if your code calls them often. A test that sets `kern.LOG_Builder.ignoreTestMode = true` and counts warning log rows after one of these saves finds more rows: to keep the old count, call `kern.TST_Factory.newDisabledFeatureFlag('BypassAudit_Enabled')` first in that test | [The three lower-level saves now write a bypass entry](#the-three-lower-level-saves-now-write-a-bypass-entry) |
| Scheduled jobs | A user without **Manage Job Runner** can no longer change or take off a job that is, or was, on the job runner, or delete a job that is on it. This also holds when a trigger action, or a flow that one started, saves the job. A job with its own schedule that such automation saves is now scheduled, where it was skipped | Give the permission to the people who manage such jobs, and to the user your automation runs as | [Every change needs Manage Job Runner](#every-change-to-a-job-on-the-job-runner-needs-manage-job-runner) |
| Scheduled jobs | A job with its own schedule, saved from another time zone before the upgrade, keeps the times it had: the fix applies when the job is saved | Save such a job again with a change, for example switch Active off and then on | [A job keeps its times in another time zone](#a-job-keeps-its-times-in-another-time-zone-or-is-refused) |
| Scheduled jobs | A job written for one time zone and saved by a user in another is refused when one cron expression cannot keep its times | Save it as a user in the job's time zone, or use a simpler schedule | [A job keeps its times in another time zone](#a-job-keeps-its-times-in-another-time-zone-or-is-refused) |
| Scheduled jobs | A job restored from the Recycle Bin now comes back switched off, with no platform job. Until now it came back marked Active: a job with its own schedule did not run, and a job on the job runner started running again | Open each job you restore and switch Active on | [A job restored from the Recycle Bin](#a-job-restored-from-the-recycle-bin-comes-back-switched-off) |
| Trigger actions | The triggers on API Call, API Issue, Scheduled Job and Async Chain Execution run all seven trigger events. Your own trigger on one of them that hands its work to the framework now runs each after-event action twice | Delete such a trigger and move its logic to trigger action rows | [Trigger actions on KernDX's own objects](#trigger-actions-on-kerndxs-own-objects) |
| Trigger actions | One save of an API call, API issue, scheduled job or chain run now runs each post-trigger action 2 times, once after each pass, where it ran once | Nothing, if your post-trigger actions are safe to run more than once, as the Triggers guide asks | [Trigger actions on KernDX's own objects](#trigger-actions-on-kerndxs-own-objects) |
| Validation rules | A KernDX validation rule on API Call or API Issue with no context class, on the rule or on its group, was skipped. It now runs with the built-in context, so an Error rule whose formula is true stops the save | Check such rules before you upgrade | [Trigger actions on KernDX's own objects](#trigger-actions-on-kerndxs-own-objects) |
| Testing | Mocked API calls and API issues are now filtered by the query's conditions, as are long IN lists and picklist conditions on every object with a formula context | Give your mocks the values the read searches for, or read fewer values at a time | [Your tests: mocked API calls and API issues are filtered](#your-tests-mocked-api-calls-and-api-issues-are-filtered) |
| Testing | On every object with a formula context, a mocked `count()` or `exists()` now counts only the mocks that match the query's conditions, an answer scripted with `kern.TST_Mock.registerNext` included. A condition on a date-and-time field is now checked, where before every mock came back, and is compared at whole seconds, as the database does | Give your mocks the values the read searches for, and check a test that counted every mock | [Your tests: mocked API calls and API issues are filtered](#your-tests-mocked-api-calls-and-api-issues-are-filtered) |
| Trigger actions | A bypass by the bare class name of an action the package ships now bypasses it in an installed org | Check that every bypass by a bare name is one you mean | [A bypass by the bare class name reaches a packaged trigger action](#a-bypass-by-the-bare-class-name-reaches-a-packaged-trigger-action) |
| Outbound calls | When Salesforce refuses to start the background send of an outbound call, the save that queued it no longer fails: the call waits at Retry with a Next Retry time and the reason. `kern.FLOW_CallApiAsync.invokeApiCallAsynchronously` now saves each call it gets at Retry as Retrying before the send starts | If your code or flow calls that action, do not rely on a refused start throwing an error, or on a call at Retry staying at Retry | [A refused outbound send waits at Retry, and the Flow action writes Retrying](#a-refused-outbound-send-waits-at-retry-and-the-flow-action-writes-retrying) |
| Async processing | A launch with a delay that Salesforce refuses when the delay ends now writes one error entry, in a new place and with a new message, where it wrote two | Nothing, unless a list view, report or alert looks for either old entry: check that it finds the new one | [A refused launch with a delay has one error entry](#a-refused-launch-with-a-delay-has-one-error-entry) |
| Async processing | When Salesforce refuses to start a queueable job or a launch with a delay that `kern.UTIL_AsynchronousJobLauncher.process` asks for, the error arrives as a KernDX exception with Salesforce's error as its cause | Catch `Exception` and read `getCause()`, not a specific Salesforce exception | [A job Salesforce refuses to start arrives as a KernDX exception](#a-job-salesforce-refuses-to-start-arrives-as-a-kerndx-exception) |
| Async processing | Under `BATCH`, the `finish` of a `kern.IF_Async.Finishable` processor runs once, only when every chunk succeeded, and sees the values `execute` set. The processor's fields keep their values from one chunk to the next | Do any work a failed chunk needs in `execute`, not in `finish`. Clear a list or map that `execute` fills at its start, or mark it `transient` | [finish() runs only when every chunk succeeded](#finish-runs-only-when-every-chunk-succeeded) |
| Async processing | Under `BATCH`, the Apex Jobs page lists the batch job of a processor that implements `kern.IF_Async.Finishable` as `UTIL_StatefulAsynchronousBatch` | Nothing, unless a report or monitor picks out KernDX jobs by class name: add that name | [finish() runs only when every chunk succeeded](#finish-runs-only-when-every-chunk-succeeded) |
| Async processing | A chunk of the daily login job (`kern.SCHED_ProcessLoginHistory`) that fails with an error Apex can catch no longer fails the batch or raises the batch error event. The log gets an ERROR entry | Nothing, unless a monitor watches failed batch jobs for this job: watch for the ERROR entry | [finish() runs only when every chunk succeeded](#finish-runs-only-when-every-chunk-succeeded) |
| Async processing | A request that forces `PARALLEL_QUEUEABLES` for a `kern.IF_Async.Finishable` processor throws an `IllegalArgumentException` and starts no job | Use `BATCH`, `CHAINABLE` or `AUTO` for such a processor | [A Finishable processor cannot be forced to run as parallel jobs](#a-finishable-processor-cannot-be-forced-to-run-as-parallel-jobs) |
| Async chains | A purge of chain runs by Completed At now also deletes runs that have stayed Stalled for longer than its number of days | Nothing, unless you need old stalled runs: they are now deleted like finished runs. If the purge's user cannot read Status and Stalled At, give it read access | [Async chains](#async-chains-a-run-that-stays-stalled-is-purged) |
| Async chains | A save by your code or a flow that moves a chain run into Stalled must also set Stalled At; without it the save is refused, with an error that names the missing time. The Kern Administrator permission set can set Stalled At | If your code or flow moves a chain run into Stalled, set Stalled At in the same save. A user without the Kern Administrator permission set needs edit access to Stalled At from a permission set of your own, or the save must run in system mode | [Async chains](#async-chains-a-run-that-stays-stalled-is-purged) |
| Feature flags | A Public Group strategy whose target is a label shared by two public groups, or the label of a queue, no longer matches. A target that is the API name of one public group and the label of another now follows the group with that API name | Put the group's API name (Group Name in Setup) in the strategy's Target | [Feature flags](#feature-flags-a-public-group-is-found-by-its-api-name) |
| Queries | A read with `bypassSharing()` and no `withSystemMode()` is refused when a filter or sort uses a field the user cannot read inside a function or through a parent | Do not filter or sort on such a field, or add `withSystemMode()` | [bypassSharing() checks fields inside functions and through parents](#bypasssharing-checks-fields-inside-functions-and-through-parents) |
| Queries | A read with `bypassSharing()` and no `withSystemMode()` that selects a path through a lookup field or a parent object the user cannot read, or adds a child query through such a lookup, is refused. In 1.10 and 1.11 it returned the related values. Selected text KernDX cannot check, such as a child query written as text, is refused for every user | Give the user read access to the field or object, take the related fields out of the read, or add `withSystemMode()`. Add child queries with `subselect()` and write each `TYPEOF` as a field of its own | [bypassSharing() refuses a read through a lookup the user cannot read](#bypasssharing-refuses-a-read-through-a-lookup-the-user-cannot-read) |
| Saves | `kern.PROC_ExecuteDML` and `kern.PROC_UpdateFields` built with an access level that names a permission set use that level, not the default of the `UserModeDml_Enabled` flag (or, for the query of `kern.PROC_UpdateFields`, of the `UserModeQueries_Enabled` flag) | Check that the running user, with the permission set, may read the rows and make the save | [A queued save keeps an access level that names a permission set](#a-queued-save-keeps-an-access-level-that-names-a-permission-set) |
| Saves | When an error stops a save made with `allowPartial()`, `isSuccess()` on the result is `false`, where it used to be `true`, and `getFailureCount()` is at least 1 | If your code reads the result of a partial save, check that it handles a failed result | [A partial save stopped by an error now reports a failure](#a-partial-save-stopped-by-an-error-now-reports-a-failure) |
| Validation rules | `{!$Label.Name}` in an error message is filled with the label. A label that does not exist stays as written. Until now the merge field came back blank | Update a test that expects the old text | [A label in a validation error message is filled](#a-label-in-a-validation-error-message-is-filled) |
| Saves | `kern.PROC_UpdateFields` saves only each record's Id and the fields in its update list. Until now `execute` saved the whole record it was given, so other fields set on it were saved too | If your code calls `execute` directly and sets other fields on the records, save those fields yourself | [Field updates save only the fields they set](#field-updates-save-only-the-fields-they-set) |
| Queries | On a read with `withDataCategory`, `count()`, `exists()`, the total of a `getPage()` read that cannot use a cursor, and the count `getRandomItems` starts from keep the data category filter. Until now they counted every article that met the other conditions | Nothing, unless your code relied on the larger number | [Counts keep the data category filter](#counts-keep-the-data-category-filter) |
| Utilities | `kern.UTIL_Date.toIso8601` of a null `Date` returns `1970-01-01` in every time zone, and `kern.UTIL_Random.randomDate()` and `randomDateTime()` never go back past 1970-01-01. Until now a user west of GMT got `1969-12-31` | Check a test that expects `1969-12-31` | [The epoch date is 1970-01-01 in every time zone](#the-epoch-date-is-1970-01-01-in-every-time-zone) |
| Utilities | `kern.UTIL_List.partition` returns every item. For some list sizes, such as 201 items in parts of 200, it left out the last items, and so did a launch of parallel queueable jobs that split its items with it | Nothing, unless your code made up for the lost items | [UTIL_List.partition returns every item](#util_listpartition-returns-every-item) |
| Outbound calls | The saves of `kern.FLOW_CallApiAsync.invokeApiCallAsynchronously` ignore record sharing. A call at Retry whose save as Retrying is refused is not sent, and one warning names it | Nothing, unless your flow relied on the running user's sharing to keep the action away from some calls | [A refused outbound send waits at Retry, and the Flow action writes Retrying](#a-refused-outbound-send-waits-at-retry-and-the-flow-action-writes-retrying) |
| Outbound calls | The save of `kern.SCHED_PerformBatchedCallouts` ignores record sharing and saves only the status, so every Batched call moves to Queued, whoever scheduled the job. One warning counts the calls whose save was refused | Nothing, unless you counted on the job leaving some users' Batched calls alone | [The batched-call job moves every Batched call](#the-batched-call-job-moves-every-batched-call) |
| API issues | Retry Selected and the **Retry API Issues** action no longer queue a request when any of its open issues, selected or not, is on a call that failed permanently or has **External System May Have Acted** ticked. Its issues stay open, and `queuedCount` does not count them | Nothing, unless your flow or Apex code relies on `queuedCount`, `success` or `jobId` | [Bulk retry and permanent failures](#bulk-retry-skips-a-request-with-an-issue-that-failed-permanently) |
| Data masking | When an object has more than one trigger setting, masking runs when any of them has Apply Masking ticked. Until now the setting read last decided | Check Apply Masking on every setting for such an object | [Masking with more than one trigger setting](#fixed-masking-with-more-than-one-trigger-setting) |
| Data masking | A pattern (`Regex`) rule with `^`, `$`, `\A`, `\Z`, `\z` or `\G` no longer runs on a value longer than 131,072 characters: the whole field is saved as `[MASKING_FAILURE]`. Until now such a rule left part or all of a long API body unmasked, or stopped the save | If such a rule targets an API request or response field, write `(?s).+` for a whole value, or take the anchor out | [Data masking: an anchored pattern on a long API body](#data-masking-an-anchored-pattern-on-a-long-api-body) |
| Data masking | An active masking target that names a Caller Class on an object other than API Call or API Issue is refused when you save it | Clear the Caller Class, or make the target inactive | [Data masking](#data-masking-a-caller-class-only-where-it-can-apply) |
| Data masking | A JsonKey rule on a value that holds two JSON values one after the other, such as one object per line, masks every plain value under a matching key and keeps every object. When a matching key holds an object or a list, or the key pattern is one the text search cannot run safely, the whole field is saved as `[MASKING_FAILURE]`. Until now a secret in a later object was saved as it came, and a secret in the first object dropped the objects after it. A JsonKey rule also no longer reads Min Input Length, on any value, as the field's description says. Until now a value shorter than the rule's Min Input Length that was not read as JSON, such as plain text with `"key":"value"` pairs, was saved as it came | Nothing to change. If such a field now shows `[MASKING_FAILURE]`, the section explains why | [Two JSON values in one value](#data-masking-two-json-values-in-one-value) |
| Trigger actions | A post-trigger action row that names the trigger setting of a custom object, or a change event with no SObject Type, never ran. It now runs when that object is saved, or its change event arrives | Check such rows; tick Bypass Execution on, or delete, any you no longer want | [Post-trigger actions scoped to a custom object](#fixed-post-trigger-actions-scoped-to-a-custom-object-or-a-change-event) |
| Trigger actions | A post-trigger action on a change-event setting whose SObject Type holds a standard object ran after saves of that object. It now runs after the change event, not after those saves | Check such rows before you upgrade | [Post-trigger actions scoped to a custom object](#fixed-post-trigger-actions-scoped-to-a-custom-object-or-a-change-event) |
| Logging | A trigger setting's Performance Threshold (ms) now applies to the trigger actions and post-trigger actions registered under it, where it was never read. A threshold set on an action or a trigger setting logs a run that takes that long or longer, even when Enable Trigger Performance Logging in Log Setting is off | If you set such thresholds, check the slow-action entries you get. To stop every slow-action entry, turn off Is Enabled in Log Setting (this stops all logging except errors), or set its Log Level Threshold above DEBUG (this also stops your other DEBUG entries) | [Trigger performance logging: thresholds work, and Suppress wins](#trigger-performance-logging-thresholds-work-and-suppress-wins) |
| Logging | When Suppress Performance Logging and Force Performance Logging are both ticked on one trigger action, Suppress wins and the action no longer logs. Until now Force won | Untick Suppress on any such action you want logged | [Trigger performance logging: thresholds work, and Suppress wins](#trigger-performance-logging-thresholds-work-and-suppress-wins) |
| Pipeline | The ingress-bypass alert workflow fired on every merge to an ingress branch. It now fires only when a required check did not pass | If you turned on the ingress-bypass alert or the reviewers-file check, run `kerndx upgrade` with the new pipeline bundle so those workflow files get the fix | [The pipeline](#the-pipeline) |
| Object lookups | `kern.UTIL_SObjectDescribe.getDescribe(name)` and `kern.UTIL_SObjectDescribe.getSObjectTypeByName(name)` return null for a name that is not an object. Until now the name of an Apex class, of a system type such as `String`, or `SObject` failed with a `System.TypeException` | If your code catches that exception to find out that a name is not an object, check for null instead. If a test expects that exception from `kern.TST_Builder.of(name)`, expect an `IllegalArgumentException` | [getDescribe and getSObjectTypeByName return null for a name that is not an object](#getdescribe-and-getsobjecttypebyname-return-null-for-a-name-that-is-not-an-object) |
| API issues | A successful outbound call answered by mock data no longer resolves earlier open issues for the same request, and a retry answered by mock data leaves its issue open | To check in a sandbox that issues get resolved, turn mocking off first | [A call answered by mock data no longer resolves earlier issues](#a-call-answered-by-mock-data-no-longer-resolves-earlier-issues) |
| API issues | The warnings a bulk retry writes to the log count API issues and now say so: they start "N API issue(s)" where they started "N failure replay(s)". A new warning counts the issues that mock data answered | Nothing, unless a report, list view or automation looks for "failure replay(s)" in log entries | [Retry and mock data](#retry-leaves-an-issue-open-when-mock-data-answers-it) |
| Async chains | The performance entry for a whole chain run now follows Enable Performance Logging and Performance Threshold (ms) in Log Setting, until you set the new Async Chain Performance Threshold (ms). With the defaults, only a run of 10 seconds or more gets one, and none does with Enable Performance Logging off. A run that stops on a failed step now gets one too | Nothing, unless a report or dashboard reads these entries: to get one for every such run again, set Async Chain Performance Threshold (ms) to 0 | [Chain performance entries](#async-chains-the-whole-run-performance-entry-follows-log-setting) |
| Async chains | When the watchdog runs low on queries, it no longer sets chains aside with "Parked: no query budget"; the chains it did not reach keep their status and their place | Nothing, unless a report, list view or automation looks for that text | [Async chains](#async-chains-the-watchdog-keeps-a-query-in-hand) |
| API issues | Triggering Record ID on API Issue holds up to 80 characters, where it held 18, and keeps the call's whole value | Check any report or integration that expects 18 characters | [Find the API calls and issues of one record](#find-the-api-calls-and-issues-of-one-record) |
| Outbound calls | The field help and the guides now say what KernDX does: a blank Circuit Breaker Failure Threshold on an API setting means 5, and a Retry Backoff (sec) above 300 works as 300, unless the handler overrides `createRetryStrategy()`. An upgrade keeps the old help text in your org | Enter a threshold if you want a number other than 5. To wait longer than 300 seconds between retries, override `createRetryStrategy()` in your handler | [Outbound calls: the breaker default and the longest retry wait](#outbound-calls-the-breaker-default-and-the-longest-retry-wait) |

---

## Bypass audit: kept at every log level

**Fixed: bypass entries are saved at every log level while logging is on.** A bypass entry records who turned a safety
check off, what they turned off, and why.

- It is saved as a warning. Until now it passed the same log level check as your application logs.
- So an org whose log level (Log Level Threshold, `LogLevelThreshold__c` on Log Setting) was ERROR, as the field's help
  text suggests for production, saved no bypass entry at all.
- The log level now applies to application logs only. Bypass entries are saved whatever the log level is: DEBUG, INFO, WARN or ERROR.
- Two switches still turn them off: logging itself (Is Enabled unchecked on Log Setting) and the `BypassAudit_Enabled`
  feature flag.
- The Class Filter and Suppress Class Method fields of Log Setting still apply. If one of them leaves out a class, the
  bypass entries made from that class are not saved either. A caller that carries a namespace is matched by its
  namespace: `kern.UTIL_BypassAudit.emit`, the framework's own audit class, is matched as `kern`.
- In an org at ERROR, bypass entries now start to be saved, and each one publishes one `LogEntryEvent__e` platform event,
  which uses up your event allocations. Repeats of one bypass are combined into one row and a daily count, as before, so
  the saved rows stay few.
- The framework's own saves of API issues (when it logs or resolves one) and of the scheduled jobs the Health Check sets up
  write no bypass entry any more. So the rows for those saves, with the caller `kern.UTIL_BypassAudit.emit`, stop.
- Three of the framework's own reads also write none: the **Send Email (Flow-Delegated) and Log Activity** Flow action
  reading recipient addresses, and two internal reads.
- The help text of the Log Level Threshold field now says that bypass entries are kept at every level. It changes on new
  installs only: an upgrade keeps the earlier help text, which suggests ERROR for production and does not mention bypass
  entries.

**What to do:** if your log level is ERROR in production, expect bypass entries in the log after the upgrade. To stop
them, turn off the `BypassAudit_Enabled` feature flag.

Read more: [How do I see who turned a check off?](../docs/Security%20-%20Guide.md#how-do-i-see-who-turned-a-check-off) in
the Security guide, and [Log Grouping & Flood Control](../docs/Logging%20-%20Guide.md#log-grouping--flood-control) in the
Logging guide.

## Scheduled jobs

Changing a job on the job runner now needs Manage Job Runner, a job saved from another time zone keeps its times or is
refused, and a restored job comes back switched off. Each change has its own part below.

Read more: [Scheduler Framework](../docs/Async%20Processing%20-%20Guide.md#scheduler-framework) in the Async Processing
guide.

### Every change to a job on the job runner needs Manage Job Runner

**Fixed: every change to a job on the job runner needs the Manage Job Runner permission.** Until now, the check ran only when a
job went onto the job runner or its class or parameters changed.

- A user without the permission could still take a job off the job runner, or change its priority, overlap policy, schedule,
  time zone, name or active flag. Each of these is now refused on a job that is, or was, on the job runner.
- A user without the permission could also delete a job that is on the job runner. That delete is now refused too.
- Still open to everyone who can edit the job: its description, jobs that were never on the job runner, and the job runner's own
  writes of run times and outcomes.
- Only Health Check can delete one of the job runner's own records. Until now, a delete from anywhere else stopped the job
  runner without a refusal. **Deactivate** and **Repair** in Health Check keep working.
- Health Check's one-click watchdog schedule can still move the watchdog off a stopped job runner for an administrator without
  the permission.
- The refusal now reads "Only a user with the Manage Job Runner permission can put a job on the job runner, change a job that is
  on it, or take a job off it."
- These checks now also run when a job is saved by another trigger action, or by a flow that a trigger action started. Until
  now, such a save skipped them, and it also skipped the scheduling of the job.

**What to do:**

- Give Manage Job Runner to the people who manage jobs on the job runner, and to the user your automation runs as when a
  trigger action or a flow saves such jobs.
- If a trigger action, or a flow it started, saves a job with its own schedule (not on the job runner), that save now
  schedules the job. Check that you want such jobs to run.

### A job keeps its times in another time zone, or is refused

**Fixed: a scheduled job written for one time zone and saved by a user in another keeps its times, or is refused.**

- Until now, the job could fire at other times with no warning. An hour step such as every third hour was not moved, even
  between ordinary time zones. Days that depend on the month, or on its length, moved wrongly.
- The hours are now moved one by one and written out, so the saved cron expression can show a list of hours where you wrote a
  step.
- A schedule that one cron expression cannot hold in the new time zone is refused. The message names both time zones and says
  what to do: save the job as a user in the first time zone, or use a simpler schedule.

**What to do:**

- If a job's save is refused because of its time zone, save the job as a user in the job's time zone, or use a simpler
  schedule.
- The times are worked out when the job is saved. So a job with its own schedule (not on the job runner) that was saved
  from another time zone before the upgrade keeps its old times.
- Save such a job again with a change, for example switch Active off and then on. A save with no change does not
  schedule the job again. That save can now be refused, as above.

### A job restored from the Recycle Bin comes back switched off

**Fixed: a job restored from the Recycle Bin comes back switched off.**

- Until now, a restored job came back marked Active. A job with its own schedule did not run, because deleting it had
  stopped its platform job. A job on the job runner ran again, even when the user who restored it did not hold Manage Job
  Runner.
- Now Active is off and no platform job is kept. Switching it on in the editor runs every normal check and schedules the
  job.
- One of the job runner's own records cannot be restored from the Recycle Bin. To bring the job runner back, use Activate
  or Repair in Health Check.
- If a restored job cannot be switched off, for example because one of your validation rules refuses the change, the
  restore is refused and the job stays in the Recycle Bin.

**What to do:** after you restore a job, open it and switch Active on.

### The editor keeps a job's time zone

**Fixed: editing a scheduled job keeps its time zone.** The editor now keeps the job's time zone, and shows it in the
schedule heading and the next-run preview.

- Until now, saving a job from the editor moved it to your own time zone, and the editor showed your time zone, not the
  job's.
- A new job still gets your time zone.
- A user without Manage Job Runner in another time zone can still change the description of a job on the job runner: the
  save no longer changes the time zone, which needs the permission.
- A job saved without a time zone, for example by a script, still takes your time zone the first time you edit it. On a
  job on the job runner this changes the time zone, so it needs Manage Job Runner.

### Health Check shows the job runner's times in your time zone

**Fixed: Health Check's job runner check shows its times in your own time zone.** Its messages printed the time of the
last check in UTC with no time zone, so it read as your local time and was hours off outside UTC. The time now shows in
your own locale and time zone. Nothing to do.

## Trigger actions on KernDX's own objects

**New: your trigger action rows run on every trigger event of API Call, API Issue, Scheduled Job and Async Chain
Execution.** Until now these four triggers ran before events only, so a row of yours for an after event never ran.

- For example, an after-insert action on API Issue can now update the related business record and tell a team when an
  outbound call fails.
- The four triggers run before insert, before update, before delete, after insert, after update, after delete and after
  undelete. The package's own actions on these objects still run on the before events only, and do what they did before,
  except on Scheduled Job, where an after-undelete action switches a restored job off.
- The package's trigger settings for these objects are protected, so a row of yours cannot name them. Create a trigger
  setting of your own for the object (for example with SObject Type set to `kern__ApiIssue__c`) and put your rows on it.
- The package runs the actions of both settings. The order between its actions and yours is not defined; `Order__c` sorts the
  actions within one setting only.
- Your action runs inside the package's own save. Leave its Failure Action blank (Log and Continue): with Block DML, or on
  a governor-limit error, the save rolls back, and that removes the very record that started your action.
- `kern.UTIL_FormulaContext.ApiCallContext` and `kern.UTIL_FormulaContext.ApiIssueContext` are new built-in formula
  contexts. An entry formula on API Call or API Issue now works with the context class name left blank. Scheduled Job and
  Async Chain Execution still need a context class you write.
- Status and Direction on these two objects are picklist fields. A formula cannot compare a picklist with `=` or `<>`,
  so write `TEXT(newRecord.Status__c) = "Failed"`, not `newRecord.Status__c = "Failed"`. A formula that compares a
  picklist directly is refused, and the save of the record fails.
- A KernDX validation rule on API Call or API Issue that names no context class, on the rule or on its group, now runs
  with the built-in context. Until now such a rule was skipped, and the log got an error entry. An Error rule whose
  formula is true now stops the save. Check such rules before you upgrade.
- **Post-trigger actions run once after each pass.** One save of a record on these objects now has a before pass and an
  after pass, so one insert of an API issue runs each post-trigger action 2 times, where it ran once.
- In your tests, mocked API calls and API issues are now filtered by the query's conditions, as saved ones are. See
  [Your tests: mocked API calls and API issues are filtered](#your-tests-mocked-api-calls-and-api-issues-are-filtered).

**What to do:**

- If you wrote your own trigger on one of these objects that hands its work to the framework, delete it when you upgrade
  and move its logic to trigger action rows. Otherwise its after-event actions run twice.
- Check that each post-trigger action on these objects is safe to run more than once.
- Check any KernDX validation rule on API Call or API Issue with no context class, on the rule or on its group, before
  you upgrade.
- If your tests mock API calls or API issues, give the mocks the values the read searches for, as described below.

Read more: [How do I add actions to KernDX's own objects?](../docs/Triggers%20-%20Guide.md#how-do-i-add-actions-to-kerndxs-own-objects)
in the Triggers guide.

### Your tests: mocked API calls and API issues are filtered

**Changed: in your tests, mocked API calls and API issues are now filtered by the query's conditions, as saved ones are.**
A test that mocked them with `kern.TST_Mock` and expected every mock back from a filtered read now gets only the mocks that
match.

- A mock is never saved, so its Triggering Record Index is not filled for you. Set it on the mock yourself: a mock
  that sets only Triggering Record Id is not found.
- On a text field the match in a test is exact. A mock whose value differs from the searched one only in upper or
  lower case is left out, where a saved record would be found. On a picklist field the match ignores case, as for a
  saved record.
- An answer scripted with `kern.TST_Mock.registerNext` is filtered the same way, so give its mocks the values the
  read searches for too.

Mocked records are filtered only on objects with a formula context (a class that lets a formula read the record's
fields, such as the two built-in ones for API Call and API Issue). On those objects:

- A long IN or NOT IN list is now filtered, where before every mock came back. The mocks are checked in several
  steps, so the list is filtered up to a size, and the size is smaller on a field with a long name.
  - With 200 mocks or fewer, that is one list of 4,000 Ids on a field with a short name such as `Id`, or about 3,000
    on a field with a long name such as Triggering Record Index; or two lists of 280 Ids each (about 210 each on
    fields with long names).
  - With more mocks the size is smaller: with 1,000 mocks, one list of 800 Ids (about 600 on a long name).
- At the largest size, filtering one read takes about 3 seconds of the 10 seconds of processing time a test may use.
- Past that size, and for a condition too long to split (with no list in it, or with one value too long on its
  own), every mock comes back, as before.
- A searched value with a backslash is now matched.
- A condition on a picklist field, such as Status or Direction, or Industry on Account, is now checked too, where
  before every mock came back.
  - Greater than and less than on a picklist field, and a condition that compares a multi-select picklist field with
    a value, still return every mock.
  - A test of whether a multi-select picklist field is blank, or not blank, returns only the matching mocks.
- In a real query, a `_` or `%` inside a `contains()` value stands for any characters. In a test it is matched as
  that character, so `contains('ACME_West')` finds a mock named ACME_West and not one named ACMEXWest.
- A mocked `count()` or `exists()` now checks the mocks against the query's conditions, as a read of the rows does, an
  answer scripted with `kern.TST_Mock.registerNext` included. Until now a count counted every mock. So `count()`,
  `exists()` and `toList().size()` agree for a read with no limit or offset. A limit or offset never changes a count.
- A condition on a date-and-time field, such as Next Retry at or before now, is now checked, where before every mock
  came back. The values are compared at whole seconds, as the database does, so a mock stamped with `System.now()` is
  found by a condition "at or before now" taken just after it.

**What to do:** give your mocks the values the read searches for, or read fewer values at a time. If a test counted
every mock, check that it counts only the ones that match.

## Outbound calls at the daily background-job limit

**Fixed: when Salesforce refuses to start the background send of an outbound call, the save that queued the call no longer
fails.** The call waits at Retry and is sent once Salesforce starts jobs again.

An outbound call is sent by a background job (a queueable job). Salesforce can refuse to start that job, most often when the
org has used its daily allowance of background jobs. Until now the refusal was an error in the flow that starts the send, so
the whole save failed, the record that queued the call included.

- Each call whose job did not start is saved at **Retry**, with a **Next Retry** time and the reason in **Error Messages**.
  - **Error Messages** reads "Salesforce refused to start the background send, so the request was not sent: *the
    reason*. It will be tried again at *the time*. The Next Retry field shows this time in your own time zone."
  - The time in that message is in UTC, in the ISO 8601 form, such as `2026-11-08T12:15:42.000Z`.
- The **Retry Outbound Api Call** flow sends the call at that time.
- A new call waits 15 minutes. A call already waiting at Retry waits twice its last wait.
- Each new refusal of the same call doubles the wait again, never less than 15 and never more than 240 minutes: for a
  new call, 15, 30, 60, 120, 240, then 240 again.
- The daily allowance counts the last 24 hours, so room always comes back.
- **Retries** does not change and no API issue is raised, because the request never left your org.
- A call whose job did start is sent as usual. It is never sent twice.
- The log gets one warning for each refused start. It says how many calls wait, when the first one is tried again and how many
  calls had already started. This warning is the only log entry for the refused start: no error entry is written for it,
  because the calls are not lost.
- This covers the jobs the save starts. Two kinds of send are only logged, and their calls are not changed:
  - a send split into a chain of jobs, when Salesforce refuses a later job of the chain. KernDX uses a chain, for
    example, when more calls than one job sends are saved from inside a batch, queueable or future job. One error entry
    lists the calls;
  - a send that runs as one batch job. At the limit the batch fails before it sends any call. One error entry gives
    Salesforce's reason.
- In those two cases, a call at **Queued** stays Queued, and the Outbound Retry Watchdog, if you schedule it, names it
  in its warning. A call that was at **Retry** stays **Retrying**, and the watchdog later sets it to **Failed**.
- A call you passed that was not saved yet (it has no Id) is lost in those two cases: it is never saved, the watchdog
  cannot find it, and the error entry shows it only as `null`. Inside a batch, queueable or future job, save your calls
  before you pass them.
- **Such a Failed call was never sent**, although its **Error Messages**, and its API issue when the service's API setting
  logs issues, say the request may have been sent. Check the log for the error entry of the refused job before you send
  it again.
- The scheduled path of the Retry Outbound Api Call flow now holds only the Apex action. The action sets the call to
  **Retrying** itself, before it starts the send.

**What to do:** nothing, unless your own code or flow calls the **Invoke Callout Asynchronously** action
(`kern.FLOW_CallApiAsync.invokeApiCallAsynchronously`). Then read
[A refused outbound send waits at Retry, and the Flow action writes Retrying](#a-refused-outbound-send-waits-at-retry-and-the-flow-action-writes-retrying).

Read more: [What happens to your background work at the 24-hour job limit?](../docs/Async%20Processing%20-%20Guide.md#what-happens-to-your-background-work-at-the-24-hour-job-limit)
in the Async Processing guide.

### The Outbound Retry Watchdog

**New: the Outbound Retry Watchdog finds outbound calls that are never sent again.** It is a scheduled job you turn on
yourself. It never sends a request on its own.

- Schedule `kern.SCHED_OutboundRetryWatchdog` through the job runner (a **Scheduled Job** record), for example every hour,
  under the name "Outbound Retry Watchdog".
- Each run looks at calls whose time is older than **StaleThresholdMinutes** (60 by default).
- It takes at most **BatchSize** (50 by default, never more than 50) of each kind, and leaves the rest for the next run.

What a run does with each kind of call:

- **Retry** with a **Next Retry** time that has passed: the call gets a new **Next Retry** time, so the Retry Outbound Api Call
  flow sends it again. **Retries** does not change. The log gets one warning.
- **Retrying** with a **Next Retry** time that has passed: the background job that was sending it again has not finished.
  - While any background send job created after that time is still waiting or running, the call is left alone, for up
    to one day.
  - After that, or when no such job is live, the call is set to **Failed**. **Error Messages** says the request may have
    been sent and its result could not be confirmed.
  - If the service's API setting logs issues, an API issue is raised, marked **External System May Have Acted**.
  - Check with the other system before you send the call again.
- **Queued** with no change for longer than the limit: nothing is changed. The log gets one warning that names the calls.
- **Retry** with no **Next Retry** time: left alone.

The watchdog changes the calls of every user, whichever user the job runs as. It logs a warning, or raises an API issue,
only for a call whose change was saved.

**What to do:**

- **Before you schedule it,** look at the calls at **Retry** whose **Next Retry** time is older than
  **StaleThresholdMinutes**. The first runs give each of them a new **Next Retry** time, at most **BatchSize** (50 by
  default) a run, however old the call is, and
  the Retry Outbound Api Call flow then sends it. A call an earlier version left at Retry weeks ago is sent then too.
  Set any call you no longer want sent to another status first, for example **Failed**.
- **After you schedule it,** look at the API issues and the failed calls before you send any of them again. The first
  run can set calls that an earlier version left at **Retrying** to **Failed**, with the text above. Those requests may
  have been sent.

Read more: [Turn on the Outbound Retry Watchdog](../docs/Web%20Services%20-%20Guide.md#turn-on-the-outbound-retry-watchdog)
in the Web Services guide.

### What KernDX recovers, and what it only logs

When Salesforce refuses to start background work, only outbound calls are sent again on their own. For the rest, KernDX
logs what was not done, and you decide what to do next:

| Work Salesforce refused to start | What KernDX does |
|---|---|
| Sending an outbound call, the first time or as a retry | **Recovered**, when Salesforce refuses a job the save starts. The call waits at Retry and is sent once Salesforce starts jobs again |
| A later job of a chained outbound send, or an outbound send that runs as a batch job | **Logged.** One error entry, and the calls are not changed. A call at Queued stays Queued. A call at Retrying stays Retrying, and the Outbound Retry Watchdog later marks it Failed, though it was never sent |
| An outbound call whose retry job was lost | **Found** by the Outbound Retry Watchdog and marked Failed. The request may have been sent, so you decide whether to send it again |
| Queueable jobs that `kern.UTIL_AsynchronousJobLauncher.process` starts | **Logged.** Your code gets the exception at once, and the log gets an error entry |
| A batch job that fails before its first chunk | **Logged.** The log's error entry now reads "This batch failed before its first chunk ran:" followed by Salesforce's reason for the job. The items are not processed |
| The next queueable job of a `CHAINABLE` launch | **Logged.** One error entry lists the items not processed. `finish` is not called |
| A launch with a delay, when the delay ends | **Logged.** One error entry names your class, the number of items, the delay and Salesforce's error. The items are not processed: start the work again yourself |
| A scheduled job, such as a watchdog or the job runner's check | **Not handled.** The scheduled job ends Failed before any KernDX code runs |

### A refused launch with a delay has one error entry

**Changed: a launch with a delay that Salesforce refuses when the delay ends now has one error entry, in a new place.**

- **Before:** the job that waits out the delay crashed, and the log got two error entries. Their message was Salesforce's
  error.
- **Now:** that job ends normally and writes one error entry, the one described in the table above. Its location and its
  message are different. It is still an error, so it shows at any log level.

**What to do:** if a list view, report or alert of yours finds these failures by the class, method or message of either
old entry, check that it finds the new one.

## Async chains: a run that stays Stalled is purged

**Fixed: a purge of chain runs keyed on Completed At also deletes a run that has stayed Stalled for longer than the same number
of days.** A stalled run never gets an end time, so a run that stalled and was never aborted was kept for ever.

- A new field on a chain run, **Stalled At**, records when the run last became Stalled. It is cleared if the run starts running
  again. The Kern Administrator permission set can read and edit it, and Kern Async Chain Monitor Read Only can read it.
- A run that was already Stalled before the upgrade gets its Stalled At at the watchdog's next sweep. Its Stalled At is
  the time of that sweep, so the purge deletes such a run only once its number of days has passed after that sweep,
  not at the first purge after the upgrade.
- A purge you already scheduled this way needs no change.
- When your code or a flow moves a chain run into Stalled, it must also set Stalled At in the same save. Without
  it the save is refused, and the error says Stalled At is missing.
- The Kern Administrator permission set can set Stalled At. Any other user the save runs as needs edit access to it
  from a permission set of your own, or the save must run in system mode.
- If the user the purge runs as cannot read the Status and Stalled At fields of a chain run, the purge deletes by end time only,
  as before, and logs one warning that says why stalled runs were kept.

**What to do:**

- If the purge runs as a user without Kern Administrator, give that user read access to Status and Stalled At on the chain
  run object. An upgrade does not add the new field to your profiles or to your own permission sets.
- If your code or a flow moves a chain run into Stalled, set Stalled At in the same save. If that save runs as a user
  without Kern Administrator, give the user edit access to Stalled At in a permission set of your own, or run the save
  in system mode.

Read more: the [Async Processing guide](../docs/Async%20Processing%20-%20Guide.md).

## Feature flags: a Public Group is found by its API name

**Fixed: the Public Group strategy matches the group's API name (Group Name in Setup), not its label.** Until now, two groups
with the same label, or a queue with that label, could turn a flag on for the wrong people.

- A label still works when exactly one public group has it, and the log shows a warning that asks for the API name.
- Two public groups with the same label, or a queue, no longer match. The log shows a warning instead of a guess, and the user is
  treated as not in the group.
- A Target that is the API name of one public group and the label of another now follows the group with that API name.
  Until now it followed the group with that label. No warning is logged for this case, so check your strategy targets
  before you upgrade.
- Each warning is logged once per transaction.
- A Public Group check finds the group, then reads its members: about 4 SOQL queries for a group of users, as before.
  Nested groups add more. A label as the Target adds 1, and a Target that matches no group costs 2. The Feature Flags
  guide said 1 query; it now gives the true cost.

**What to do:** put the group's API name in the strategy's **Target** field. In a new installation, the field's help text says
so. An upgrade keeps the earlier help text.

Read more: the [Feature Flags guide](../docs/Feature%20Flags%20-%20Guide.md#strategy-types).

## Queries: bypassSharing() checks more of your filters

**Fixed: a read with `bypassSharing()` and no `withSystemMode()` now also checks a field inside a function or reached through
a parent.**

- Such a read ignores record sharing, and a filter or sort on a field the user cannot read is refused.
- Until now a field inside a function, or reached through a parent, was not checked, so the rows could tell the user
  something about a field they cannot read.

**What to do:** in such a read, do not filter or sort on a field the user cannot read inside a function or through a
parent, or add `withSystemMode()`.

Read more:
[bypassSharing() checks fields inside functions and through parents](#bypasssharing-checks-fields-inside-functions-and-through-parents),
for what is checked.

### Fixed: a read through a lookup the user cannot read is refused

**Fixed: a read with `bypassSharing()` and no `withSystemMode()` no longer returns a related record's fields through a
lookup field, a parent object or a child query through a lookup field the user cannot read.** This was a defect in 1.10
and 1.11.

- In 1.10 and 1.11 such a read returned the related values, such as `What.Name` for a user without read on `WhatId`, or an
  account's Id on a contact for a user who cannot read accounts.
- A query in user mode refuses such a read. The read is now refused too, before any query runs. `bypassSharing()` alone
  still keeps the user's object and field permissions.
- Selected text that KernDX cannot check, such as a child query written as text, is now refused for every user.

**What to do:** give the user read access to the lookup field or the object, take the related fields (or the child query)
out of the read, or add `withSystemMode()`. Add a child query with `subselect()`, not as text.

Read more:
[bypassSharing() refuses a read through a lookup the user cannot read](#bypasssharing-refuses-a-read-through-a-lookup-the-user-cannot-read),
for each case and the message you see.

## A queued save keeps its permission set

**Fixed: a queued save built with an access level that names a permission set now saves with that access level.** Until
now it could save with more access than you asked for.

- **`kern.PROC_ExecuteDML`** saves with that access level. Until now it saved with the default that the
  `UserModeDml_Enabled` flag sets.
- **`kern.PROC_UpdateFields`** uses that access level as it is, both to find the rows and to save them. Until now the save
  used the default of the `UserModeDml_Enabled` flag, and the query the default of the `UserModeQueries_Enabled` flag. An
  access level of `AccessLevel.SYSTEM_MODE` is still recorded in the bypass audit.

**What to do:** check that the running user, with that set, may make the save (and, for `kern.PROC_UpdateFields`, read
the rows).

Read more:
[A queued save keeps an access level that names a permission set](#a-queued-save-keeps-an-access-level-that-names-a-permission-set).

## Saves tell you why they failed

**New: `kern.DML_Builder.TransactionResult.getFailureMessage()` gives the reason a save failed when no error reached your
code.** There are two such cases:

- a failure that `suppressExceptions()` turned into a failed result;
- an error that stopped a save made with `allowPartial()`.

Neither case gives row results, so `getErrors()` does not show it. When a partial save only refuses some rows,
`getFailureMessage()` returns null: read each row's reason from `getErrors()`.

Until now, an error that stopped a partial save was logged and then lost, and the result said the save succeeded.

**What to do:** if your code reads the result of a save made with `allowPartial()`, check that it handles a failed result.

Read more:
[A partial save stopped by an error now reports a failure](#a-partial-save-stopped-by-an-error-now-reports-a-failure).

## Custom labels in a validation error message

**New: a KernDX validation rule's error message fills `{!$Label.MyLabel}` with your org's custom label, in the saving user's
language.** Until now, the only way to show a label was a property on the context class that returned it.

- Write `{!$Label.ns__MyLabel}` for a label from the managed package with the namespace `ns`.
- A label needs no property on your context class.
- A label that does not exist stays in the message as written, so the mistake shows, and one warning names it in the log for
  each transaction.
- Every other merge field works as before.
- The Error Message field's description and help text say this on new installs. An upgrade keeps the earlier help text,
  which says that Custom Labels are not resolved.

Read more: [Multi-Language Support](../docs/Validation%20-%20Guide.md#multi-language-support) in the Validation guide. See
also: [A label in a validation error message is filled](#a-label-in-a-validation-error-message-is-filled).

## Bulk retry skips a request with an issue that failed permanently

**Fixed: a bulk retry no longer sends a request again when one of its open issues is on a call that failed
permanently.**

- This applies to Retry Selected and the Retry API Issues flow action. A request is not sent again when any open issue
  of that request is on a call that failed permanently or has External System May Have Acted ticked, even one you did
  not select.
- Several open issues can be logged for one request. Before, the issue on the permanent failure stayed open, but
  another open issue of the same request was queued, and the request was sent again.
- The open issues are grouped by request first. Every open issue of the request counts, selected or not.
- A request is skipped as a whole when any of its open issues is refused, for example because its call is ticked
  **Permanent Failure**, or when any of them has **External System May Have Acted** ticked.
- Every issue of a skipped request stays open.
- `queuedCount`, and the count the API Issues list shows, leave out every issue of a skipped request. An issue you did
  not select is never queued or counted. The count of selected issues does not change.

**What to do:** nothing, unless a flow or Apex code reads `queuedCount`, `success` or `jobId` from the Retry API Issues
action. `queuedCount` can now be lower. When no request is left to send, `success` is false and `jobId` is empty.

## Fixed: masking with more than one trigger setting

**Masking now runs on an object when any of its trigger settings has Apply Masking ticked.** Until now the setting read
last decided, and the order the settings were read was not fixed, so the result could change from one save to the next.

- A setting's Required Feature Flag and Bypass Feature Flag switch its actions only. They never change masking.
- A setting with Bypass Execution ticked is left out, so its Apply Masking does not count.
- To switch masking off for one object, untick Apply Masking on every one of its settings. To switch it off for every
  object, turn off the Masking Framework Enabled feature flag.
- An upgrade keeps the earlier help text of the Apply Masking field, which does not mention more than one setting. The
  field's description, the Triggers Guide and the Data Masking Guide carry the current rule.

**What to do:** if an object has more than one trigger setting, check Apply Masking on all of them before you upgrade. An
object whose masking stayed off only because of the read order is masked after the upgrade.

Read more: the [Data Masking guide](../docs/Data%20Masking%20-%20Guide.md#an-object-with-more-than-one-trigger-setting) and
the [Triggers guide](../docs/Triggers%20-%20Guide.md).

## Data masking: an anchored pattern on a long API body

**Fixed: a pattern rule with a start or end anchor no longer leaves a long API body unmasked.** A value longer than
131,072 characters is searched in pieces, and an anchor such as `^` or `$` cannot be read correctly in a piece.

What changed:

- In 1.11, such a rule on a long value masked nothing, masked only the first 131,072 characters, or stopped the save
  with an error no code can catch, depending on the pattern.
- In 1.12, a pattern (`Regex`) rule whose pattern holds `^`, `$`, `\A`, `\Z`, `\z` or `\G` does not run on a value
  longer than 131,072 characters. The whole field is saved as `[MASKING_FAILURE]`, nothing secret is stored, and the
  save goes on. The rule's Failure Action does not change this.
- This holds in line mode (`(?m)`) too. A `^` or `$` inside square brackets, such as `[^&]`, and an escaped `\^` or
  `\$`, are not anchors.
- Only an API request or response body can be that long. Values of up to 131,072 characters, and rules without an
  anchor, are masked as before. No pattern rule the package ships holds an anchor.
- A look-around that stands for the start or end of the value, such as `(?![\s\S])`, is not read as an anchor, and
  works as it did in 1.11. The guide explains what that means on a long value.

**What to do:** if you wrote a pattern rule with one of those six anchors and it targets an API
request or response field, bodies over 131,072 characters now show `[MASKING_FAILURE]`, even a body the pattern would
not have matched. To mask a whole value, write `(?s).+`; otherwise, take the anchor out.

Read more: [Performance](../docs/Data%20Masking%20-%20Guide.md#performance) in the Data Masking Guide, under "Long
values are searched in pieces".

## Data masking: a Caller Class only where it can apply

**Fixed: an active masking target that names a Caller Class on an object other than API Call or API Issue is refused when you
save it.** Only API call and API issue records know which handler class made them, so on any other object such a target masked
nothing, without telling you.

- The message reads "Caller Class works only on API Call and API Issue targets. Leave it blank on any other object, or make the
  target inactive."
- An inactive target is accepted, so you can switch off a target saved before this check.
- The Data Masking Advisor and Health Check count a target like that, saved before the check, as one that masks nothing. The
  Advisor does not export a change that makes one active again until its Caller Class is cleared.

**What to do:** clear the Caller Class on such a target, or make it inactive.

Read more: the [Data Masking guide](../docs/Data%20Masking%20-%20Guide.md).

## Fixed: post-trigger actions scoped to a custom object or a change event

**A post-trigger action row whose Trigger Setting is for a custom object, or for a change event with no SObject Type,
now runs.** Until now it never ran: the framework could not work out the setting's object, so it always skipped the row.

- It now runs when that object's records are saved, or its change event arrives.
- Rows scoped to a standard object, and rows with no Trigger Setting, are unchanged.
- A row on a change-event setting whose SObject Type holds a standard object ran after saves of that object until now;
  it now runs after the change event instead, and no longer after those saves. With a custom object there, it never ran.

**What to do:** check such rows before you upgrade. Tick Bypass Execution on, or delete, any row you no longer want.

Read more: the [Triggers guide](../docs/Triggers%20-%20Guide.md).

## Trigger performance logging: thresholds work, and Suppress wins

**Fixed: a trigger setting's Performance Threshold (ms) now works, and a threshold you set logs even when Enable Trigger
Performance Logging in Log Setting is off.** The trigger setting's two performance fields were described in the guides,
but KernDX never read them.

What changed:

- A trigger setting's threshold applies to the trigger actions and post-trigger actions registered under it. An
  action's own threshold wins over it.
- A threshold set on an action or a trigger setting logs a run that takes that long or longer, even when Enable Trigger
  Performance Logging is off. A blank threshold follows Log Setting, as before.
- When Suppress Performance Logging and Force Performance Logging are both ticked on one action, Suppress now wins and
  the action never logs. Until now Force won.
- The trigger setting's Enable Performance Logging checkbox never had an effect. It is now labelled **Enable Performance
  Logging (Deprecated)**. Use Performance Threshold (ms) instead.
- The trigger settings that ship with KernDX are protected, so you cannot set their threshold. KernDX's own actions
  follow Log Setting.

Turning off Enable Trigger Performance Logging does not stop every slow-action entry: a set threshold now logs with it
off, as Force always did. To stop them all, do one of these in Log Setting:

- Turn off Is Enabled. This stops all logging except errors.
- Set Log Level Threshold above DEBUG. This also stops your other DEBUG entries.

Do not set a low threshold on your own trigger setting or action for a log object such as `LogEntryEvent__e`: each
entry can run that trigger again.

**What to do:** nothing, unless one of these applies. Then check the slow-action entries you get after the upgrade.

- You set a threshold on a trigger setting: its actions now follow it, so you may see more or fewer entries.
- You set a threshold on an action and turned off Enable Trigger Performance Logging: that action now logs.
- You ticked both Suppress and Force on one action: it no longer logs.

Read more: [Performance Logging](../docs/Triggers%20-%20Guide.md#performance-logging) and
[How do I stop every slow-action entry?](../docs/Triggers%20-%20Guide.md#how-do-i-stop-every-slow-action-entry) in the
Triggers guide.

## The pipeline

**Fixed: the ingress-bypass alert fires only when a pull request is merged with a required check that did not pass.** The
workflow passed its list of required checks to bash as one name, so it found none of them and sent an alert on every merge.
A real bypass was lost among them.

- The workflow now reads each required check by its own name.
- The workflow that checks your reviewers file runs `ajv-cli` at exactly version 5.0.0. Until now it took the newest 5.x release on
  each run.

**What to do:** both workflows are ones you choose to turn on, so this applies only if you turned on the ingress-bypass alert
or the reviewers-file check. Those workflow files keep the old text until you refresh them.

- Replace your `.kerndx-pipeline` folder with the pipeline bundle that ships with Kern 1.12, install its dependencies again
  and run `kerndx upgrade`, as the pipeline README describes.
- `upgrade` keeps your `.kerndx/config.yml`, writes the workflow files again and backs up each one to `.bak` first.

Read more: [Upgrading](../pipeline/README.md#upgrading) in the pipeline README, and the pipeline
[changelog](../pipeline/CHANGELOG.md).

---

## Changes that can affect code you have written

### A queued save keeps an access level that names a permission set

**What to do:** if you build `kern.PROC_ExecuteDML` or `kern.PROC_UpdateFields` with an access level that names a permission
set, check that the running user, with that set, may make the save (and, for `kern.PROC_UpdateFields`, read the rows).

Until now the job turned such an access level into the default that the `UserModeDml_Enabled` flag sets:

- user mode without the permission set, or
- system mode when the flag is off, which is more access than you asked for.

For the query of `kern.PROC_UpdateFields`, the default came from the `UserModeQueries_Enabled` flag in the same way. Both
now use the access level you give them, unchanged.

### bypassSharing() checks fields inside functions and through parents

**What to do:** in a read with `bypassSharing()` and no `withSystemMode()`, do not filter or sort on a field the user may not
read inside a function or through a parent.

If the code must use such a field, add `withSystemMode()`, which also turns off the object and field permission checks.

Under `bypassSharing()` alone, the read ignores record sharing, and a filter or sort on a field the user cannot read is refused.
Until now a field inside a function, or reached through a parent, was not checked, so the rows could tell the user something
about a field they cannot read. Now:

- The check reads inside the date functions, `convertTimezone`, `toLabel` and `DISTANCE`.
- It follows a parent path up to five levels. The user must be able to read every object on the path, every lookup on the way,
  and the last field.
- A lookup that can point to several objects, such as `What`, `Who` or `Owner`, is read through a shared Name record, as a
  query in user mode reads it. The Name record is one Salesforce record (the `Name` object) that stands for the related
  record, whatever its object. It holds only a few values, such as the record's name and its type. A filter or sort
  through it, such as `What.Name`, needs read on the lookup field (`WhatId`) only, not on the objects it can point to.
  - For some users Salesforce hides the Name record's `ProfileId`, `UserRoleId` and `RecordTypeId`. For them a filter or
    sort on those fields, such as `What.ProfileId`, and a path through them, such as `Owner.Profile.Name` or
    `What.RecordType.Name`, is refused.
  - Because the read ignores sharing, it covers every record of the queried object in the org: for `What` and `Who`,
    every task and event. It can return the name of the related record, or find a row by that name, even when the user
    cannot open that record or read its object. For a person that includes the first and last name, and for a lead the
    company.
- A parent object the user cannot read throws a `QueryException`. A field the user cannot read throws
  `kern.UTIL_Exceptions.IllegalStateException`, as for a plain field.
- A filter written in your own `kern.QRY_Condition.Evaluable` is still not checked.

The Security and Selectors guides describe the check.

### bypassSharing() refuses a read through a lookup the user cannot read

**What to do:** if a read with `bypassSharing()` and no `withSystemMode()` is now refused, do one of these:

- give the user read access to the lookup field or the object named in the message;
- take the related fields, or the child query, out of the read;
- add `withSystemMode()`, which also turns off the object and field permission checks for that read.

In 1.10 and 1.11, such a read returned a related record's fields through a lookup field, a parent object or a child query
through a lookup field the user cannot read. A query in user mode refuses it. The read is now refused too, before any query runs. This affects
`toList()`, `getFirst()`, the `as` methods such as `asMap()`, `getPage()` and `getRandomItems()`:

- **A selected path through a lookup field the user cannot read**, a lookup of your own, such as `Parent__r.Name` without read on `Parent__c`,
  or `What.Name`, `What.Type`, `What.Id` or `Who.Name` without read on `WhatId` or `WhoId`, also inside a function such
  as `toLabel()`.
- **A selected path through a parent object the user cannot read**, such as `Account.Name` on a contact for a user who
  cannot read accounts. In 1.10 and 1.11 the account came back with its Id.
- **A `TYPEOF` in the selected fields**, when the user cannot read its lookup or an object after `WHEN`.
- **A child query added with `subselect()`**, when the user cannot read the lookup behind its relationship, such as
  `WhatId` for the `Events` of an account, even when the child query selects only `Id`. Where one relationship name stands
  for two lookups, the user must be able to read both.
- **Any of these inside a child query**, a selector's default fields, a field set, or `relatedField()`.
- **A path past the shared Name record** (explained in the entry above) of a lookup such as `Owner` or `What`, through
  `ProfileId`, `UserRoleId` or `RecordTypeId`, such as `Owner.Profile.Name`, for a user from whom Salesforce hides that
  field.

In every case, a lookup field the user cannot read throws `kern.UTIL_Exceptions.IllegalStateException` with the message of
the Custom Label `QueryBuilder_BypassSharingLookup_NotReadable`. It names the field and the path, or for a child query the
relationship name. An object the user cannot read throws a `QueryException` that names the object.

A hidden last field, such as `Phone` in `Account.Phone`, is still removed from the rows and not reported, as before. Only
a hidden lookup or parent object on the way refuses the read.

**Selected text KernDX cannot check is refused for every user,** even one who can read everything. Here KernDX is
stricter than a query in user mode, which answers a child query written as text and a `TYPEOF` joined to other fields.
Once functions are taken off, each selected item must be a field name or a path such as `Account.Name`.
This throws `kern.UTIL_Exceptions.IllegalStateException` with the message of the Custom Label
`QueryBuilder_BypassSharingSelectedText_NotCheckable`. It covers:

- a child query written as text, such as `addField('(SELECT Id FROM Contacts)')`: add it with `subselect()`;
- a `TYPEOF` joined to other fields in one text, or not in the form
  `TYPEOF relationship WHEN object THEN fields ELSE fields END`, or naming a relationship or an object that does not
  exist: write each `TYPEOF` as a field of its own;
- a `subselect()` relationship name the parent object does not have. Until now the query failed when it ran.

Two smaller changes come with this:

- `subselect()` accepts the relationship name with the parent object in front, such as `Account.Contacts`, as SOQL does,
  and removes spaces around the name. This holds for every read.
- `count()` and `exists()` read no fields and no child rows, so none of the cases above refuses them. They still check a
  child query's object and its filters and sorts, now as the object its relationship reads. So a child query built for
  another object can be refused there. The same holds for `toList()` and the other reads above: they too check a child
  query as the object its relationship reads.

### A call answered by mock data no longer resolves earlier issues

**What to do:** to check in a sandbox that a successful call resolves earlier issues, turn mocking off first.

A successful outbound call resolves the earlier open issues for the same request. When mock data answers the call, those
issues now stay open, because the request never reached the other system. Mock data answers when one of these feature flags
is on for the user who makes the call:

- **Mock All APIs**; or
- **Mock Selected APIs**, together with **Mocking Enabled** on the service's API setting.

Inbound calls already worked this way. Apex tests that mock a service through `kern.API_MockFactory.forService` are not
affected: those calls still resolve earlier issues.

### A partial save stopped by an error now reports a failure

**What to do:** if your code reads the result of a save made with `allowPartial()`, check that it handles a failed result. Read
the reason with `getFailureMessage()`.

When an error stops a save made with `kern.DML_Builder.allowPartial()`, the `TransactionResult` now reports it:

- `isSuccess()` is `false`, where it used to be `true`;
- `getFailureCount()` is at least 1. It adds the failed rows to the records with no result, so it is an estimate. It can be too
  low when a child record has the same object type as its parent;
- `getFailureMessage()` gives the reason.

A partial save still never rolls back: the statements already done stay saved, and the statements not yet run do not run.

### A label in a validation error message is filled

**What to do:** if a test checks the text of a KernDX validation rule's error message that holds `{!$Label...}`, update the text
it expects.

`{!$Label.MyLabel}` in an error message is now filled with the label's text. Until now it came back blank. A label that does
not exist now stays in the message as written. See
[Custom labels in a validation error message](#custom-labels-in-a-validation-error-message).

### Field updates save only the fields they set

**What to do:** if your code calls `execute` on `kern.PROC_UpdateFields` itself, and sets other fields on the records it
passes, save those other fields yourself.

`kern.PROC_UpdateFields` changes fields on many records in a background job, and the `kern.UTIL_BulkUpdates` methods use
it. It now saves a record that holds only the Id and the fields in its list of updates, with the values the updates gave
them.

- Until now `execute` saved the whole record it was given, so any other field set on that record was saved too.
- Every update still applies to the record as it was read first, so two updates of one field still build on each other.
- The read that finds the records still decides what the user may read.

### Counts keep the data category filter

**What to do:** nothing, unless your code relied on the larger number.

A read of articles can be limited by data category with `withDataCategory` on `kern.QRY_Builder.Builder`. Until now these
counts left that filter out, so they counted every article that met the other conditions:

- `count()` and `exists()`;
- the total (`totalRecords`) of a `getPage()` read that cannot use a cursor;
- the count that `getRandomItems` starts from.

They now keep the data category filter, so they count the same articles the read returns.

### The epoch date is 1970-01-01 in every time zone

**What to do:** if a test or your code expects `1969-12-31` from the methods below, for a user west of GMT, expect
`1970-01-01`.

The Unix epoch is 1 January 1970, the day Unix time starts. KernDX worked it out from a date and time, so for a user in a
time zone west of GMT, such as America/New_York, it was 31 December 1969. It is now 1970-01-01 in every time zone:

- `kern.UTIL_Date.toIso8601(Date)` given null returns `1970-01-01`. Until now a user west of GMT got `1969-12-31`.
- `kern.UTIL_Random.randomDate()` and `kern.UTIL_Random.randomDateTime()` pick from a range that starts on 1970-01-01. West
  of GMT the range started one day earlier.
- `kern.UTIL_Date.toIso8601(Datetime)` given null is unchanged.

### UTIL_List.partition returns every item

**What to do:** nothing, unless your code made up for items it lost. This fixes
[kerndx#75](https://github.com/JVB-Consulting/kerndx/issues/75).

`kern.UTIL_List.partition(list, size)` splits a list into parts of at most `size` items. For some list sizes it left out the
last items: 201 items in parts of 200 gave one part of 200, and 52 items in parts of 50 gave one part of 50. It now returns
every item once, in order.

- A null list gives an empty list, with no parts.
- An empty list gives one empty part.
- A size of zero or less gives one part that holds the whole list.
- `kern.UTIL_AsynchronousJobLauncher.process` uses it to split items across parallel queueable jobs (`PARALLEL_QUEUEABLES`).
  Those items were lost the same way, so a launch of 201 items in jobs of 200 processed 200. Every item now reaches a job.

### A bypass by the bare class name reaches a packaged trigger action

**What to do:** check that every bypass of a trigger action by its bare class name is one you mean. It now takes effect in an
installed org.

A trigger action record holds its class name the way your org sees it:

- in an installed org, `kern.` followed by the bare name;
- in a deploy without a namespace, the bare name alone.

Until now a bypass used the name exactly as given, so the bare name of an action the package ships bypassed nothing in an
installed org, with no error and no log line.

`kern.TRG_Base.bypassAction`, `isActionBypassed` and `clearActionBypass`, and the overloads and Flow actions that call them, now
find the action a name stands for, in this order:

1. a trigger action with exactly that name, so your own action always wins;
2. otherwise, the name with your org's package namespace in front, when a packaged action has it;
3. otherwise, the name as given.

The bypass record now holds the class name that was found. The Triggers guide has a table of what each spelling bypasses.

**Right after an upgrade, bypass a packaged action by its full name.** KernDX keeps the list of trigger actions in a
cache for up to five minutes. For up to five minutes after an upgrade adds a new trigger action to the package, that
list may not hold it yet. In that time a bypass by its bare class name does not stop it. Write the full name, `kern.`
followed by the class name, and the bypass works at once.

### A job Salesforce refuses to start arrives as a KernDX exception

**What to do:** if your code catches a specific Salesforce exception from `kern.UTIL_AsynchronousJobLauncher.process`, catch
`Exception` instead, and read Salesforce's own error with `getCause()`.

This applies when `process` starts queueable jobs, as `CHAINABLE` or `PARALLEL_QUEUEABLES`, and when it starts a launch with a
delay. Salesforce can refuse to start such a job when:

- the org has used its daily allowance of background jobs;
- two jobs carry the same duplicate signature, set through `withAsyncOptions`;
- an `AsyncOptions` value set through `withAsyncOptions` is rejected.

Until now that error reached your code as Salesforce's own exception. It now arrives as a KernDX exception with Salesforce's
error as its cause. A `catch` that names a Salesforce exception, such as `System.DuplicateMessageException`, no longer matches
it, and a `catch` on `Exception` still does.

A `BATCH` launch still passes Salesforce's own exception to your code.

When `process` asked for several parallel jobs, the jobs queued before the refused one run only if your code catches the
exception and your transaction goes on. If you let the exception through, the transaction rolls back, no job runs, and you can
start the whole request again.

### finish() runs only when every chunk succeeded

**What to do:** if your processor implements `kern.IF_Async.Finishable` and runs under `BATCH`:

- if its `finish` must react to a failed chunk, do that work in `execute` instead;
- if `execute` fills a list or map in a field, clear it at the start of `execute`, or mark it `transient`.

A batch hands your processor its items in chunks: groups of items, one `execute` call each. `BATCH` and the other strategies
named here are values of `kern.IF_Async.AsynchronousExecutionStrategy`.

Under `BATCH`:

- **Before:** `finish` ran after the last chunk even when a chunk had thrown, and it did not see the values your `execute` had set.
- **Now:** `finish` runs once, only when every chunk ran without throwing, and it sees the fields your `execute` set. When a chunk
  fails, `finish` is skipped and the log gets a warning that says so.

Your processor's fields now keep their values from one chunk to the next. Until now each chunk started from the values
the fields had at launch.

- So a list or map that `execute` fills now keeps every earlier chunk's items, and grows with every chunk.
- Clear it at the start of `execute`, or mark it `transient` and build it again in each chunk.

Keep the fields you want in `finish` small, such as a count or a list of record Ids, and mark any cache `transient`. Under
`CHAINABLE`, `finish` already ran only in the last job of the chain.

Salesforce now saves your processor's fields after every chunk, so each field must hold a value Salesforce can save.
Some values cannot be saved, such as a compiled `Pattern`, a `Matcher`, an `HttpRequest` or a describe result. If a
field that is not `static` holds one of them, the batch can fail. Build such a value inside `execute`, or mark the field
`transient`.

Two smaller changes come with it, for a processor that implements `Finishable` and runs under `BATCH`:

- The Apex Jobs page lists its batch job as `UTIL_StatefulAsynchronousBatch`. A report or monitor that picks out KernDX jobs by
  class name needs that name added.
- Before calling `finish`, KernDX reads the batch's job record, which uses one query.

The daily login job you schedule as `kern.SCHED_ProcessLoginHistory` now goes on after a failed chunk:

- **A chunk fails with an error Apex can catch:** the job writes an ERROR entry to the log (filed under
  `kern.PROC_LoginFrequencyAggregator.execute`) and goes on. `finish` still runs, so the next run does not count the same
  logins again.
- **That chunk's logins:** are not counted.
- **What you see:** the chunk no longer shows as a failed batch on the Apex Jobs page, and it no longer raises the batch error
  event. The ERROR log entry is the sign to look for.
- **A limit error or a CPU time-out:** `finish` is still skipped. The next run then counts the other chunks of that job a second
  time.

### A Finishable processor cannot be forced to run as parallel jobs

**What to do:** if you force `PARALLEL_QUEUEABLES` for a processor that implements `kern.IF_Async.Finishable`, choose `BATCH`,
`CHAINABLE` or `AUTO` instead.

Parallel jobs would each call `finish`, and it must run once. So `process` now throws an `IllegalArgumentException` for that
request and starts no job. `AUTO` never picks parallel jobs for such a processor: where it used to pick them, it now picks
`CHAINABLE`.

### A refused outbound send waits at Retry, and the Flow action writes Retrying

**What to do:** if your code calls `kern.FLOW_CallApiAsync.invokeApiCallAsynchronously`, or your flow uses the **Invoke Callout
Asynchronously** action, check two things:

- your code does not expect an error when Salesforce refuses to start the send. The method now returns normally, and the calls
  wait at Retry;
- your code does not expect a call you pass at Retry to stay at Retry. The method now saves it as Retrying before the send starts.

Until now a refused start reached your code as an error, and your transaction rolled back unless you caught it. Now:

- each call whose job did not start is saved at Retry, with a Next Retry time and the reason in Error Messages. Retries does not
  change and no API issue is raised;
- a call you pass that is not saved yet is saved as a new call at Retry in the same way, so its request is still sent later;
- a call at any other status, such as Queued, is not changed before the send. If its start is refused, it waits 15 minutes;
- the Retry Outbound Api Call flow no longer sets Retrying itself. The action does, for every call it gets at Retry;
- this covers the jobs the action starts itself. A later job of a chained send, and a send that runs as one batch job,
  are only logged, and their calls are not changed.

The action's own saves of the calls ignore record sharing, as the Outbound Retry Watchdog's do, so they work whoever the
flow runs as. The action trusts the calls it is given: it changes them even when the running user cannot see or edit
them.

- If the save of a call to Retrying is refused anyway, for example by a validation rule, that call is not sent this
  time. It stays at Retry, and one warning log entry lists the calls that were not sent. Where the Outbound Retry
  Watchdog is scheduled, it gives them a new Next Retry time.
- If that save is refused for every call at Retry, and the action got no other call, no job starts.
- After a refused start, the warning counts only the calls whose save at Retry worked. It names the Ids of the calls
  whose save was refused, and each refused save has its own error entry.

See [Outbound calls at the daily background-job limit](#outbound-calls-at-the-daily-background-job-limit) for the waits
and for the sends that are only logged.

### The batched-call job moves every Batched call

**What to do:** nothing, unless you counted on the job leaving some users' Batched calls alone.

`kern.SCHED_PerformBatchedCallouts` is the scheduled job that moves outbound calls at Batched to Queued, so they are sent.
Since 1.0 its save applied record sharing for the user who scheduled it, and it never read the result. A Batched call
that user could not edit stayed at Batched. Now:

- the save ignores record sharing, so the job moves every Batched call, whoever scheduled it;
- it saves only the status of each call and leaves every other field as it is;
- a call whose save is refused anyway, for example by a validation rule, stays at Batched with its own error entry, and
  one warning says how many Batched calls were not moved to Queued.

### The three lower-level saves now write a bypass entry

**What to do:** if your code calls one of these three methods often, expect more bypass entries in the log, and more
`LogEntryEvent__e` platform events.

- Code that calls `commitWork(false)` writes one entry for each object it saves, on every commit that saves records.
- If a test of yours sets `kern.LOG_Builder.ignoreTestMode = true` and counts warning log rows after one of these saves,
  it finds more rows after the upgrade (a test that leaves it unset writes no bypass entries).
- To keep the old count in that test, call `kern.TST_Factory.newDisabledFeatureFlag('BypassAudit_Enabled');` first.

Until now these three methods turned a check off without writing a bypass entry. Now each one writes one:

| Your code calls | The entry it writes |
|---|---|
| `kern.DML_Transaction.setAccessLevel(AccessLevel.SYSTEM_MODE)`, then `commitWork` while the level is still system mode | `system-mode:` and the object, such as `system-mode:Account`, for each object the commit saves |
| `kern.DML_Transaction.commitWork(false)`, in user mode or system mode | `sharing:` and the object, such as `sharing:Account`, for each object the commit saves |
| `new kern.PROC_ExecuteDML(operation, allOrNothing, AccessLevel.SYSTEM_MODE)` | `system-mode`, with the operation (`insert`, `update` and so on) and no object, because the records arrive later, often in a background job |

- A commit writes its entries once for each `commitWork` call, before its first statement, even when it is retried after a
  row lock. A commit that saves nothing writes none. If you set another level before the commit, no `system-mode` entry is
  written.
- An entry names the class and method that called `commitWork`, or that built the processor.
- A service class of yours that extends `kern.API_Inbound` or `kern.API_Outbound` and calls `setAccessLevel` does not
  commit its own save: the framework commits it later. So the entry does not name your service class, and you cannot
  tell from it which service chose system mode.
- Repeats of one bypass from the same caller and user are combined into one row and a daily count, so the saved rows stay
  few. Each entry still publishes one platform event.
- A save through `kern.DML_Builder` still writes one entry, never two: the builder's own entry, and none from the
  transaction or the background job beneath it. The framework's own saves through these classes write none.

Read more: [How do I see who turned a check off?](../docs/Security%20-%20Guide.md#how-do-i-see-who-turned-a-check-off) in
the Security guide.

### getDescribe and getSObjectTypeByName return null for a name that is not an object

**What to do:** if your code catches a `System.TypeException` from `kern.UTIL_SObjectDescribe.getDescribe(name)` or
`kern.UTIL_SObjectDescribe.getSObjectTypeByName(name)` to find out that a name is not an object, check the result for null
instead.

- Both methods now return null for the name of an Apex class, of a system type such as `String`, and for `SObject`.
- Both now find an object whose name is also the name of a system type, such as `Location`, where they failed.
- A read with `bypassSharing()` and no `withSystemMode()` whose `TYPEOF` names an object such as `Location` after `WHEN`
  is now checked like any other object, where it was refused.
- Every name that found an object still finds the same object.
- `kern.TST_Builder.of(name)` follows them: for the name of an Apex class or a system type, it now throws an
  `IllegalArgumentException`, as it does for a name of no object, where it threw a `System.TypeException`.

See [Faster saves in an org with many objects](#faster-saves-in-an-org-with-many-objects).

---

## Find the API calls and issues of one record

**New: find the API calls and issues of one record through an indexed field, with no lookup field and no code of your own to
fill it.** Until now the only link was Triggering Record ID, which has no index, so a search for one record read every call.

- **A new field, Triggering Record Index (`kern__TriggeringRecordIndex__c`),** on API Call and on API Issue.
  - It is an External ID field, so Salesforce keeps an index on it.
  - A trigger action fills it on every save with Triggering Record ID exactly as written: a record Id, an order number or
    any other text, with no check and no change.
  - It is blank when Triggering Record ID is blank.
- **Triggering Record ID can hold text that is not a record Id,** such as an order number from another system, of up to
  80 characters.
  - Such a value works for inbound calls, for rows your own code saves, and for outbound calls whose class sets
    `requiresTriggeringRecord` to false. An outbound call whose class needs a triggering record, the default, is still
    stopped before it is sent when the value is not a record Id.
  - The API issue of a failed call keeps the whole value. Triggering Record ID on API Issue now holds up to 80
    characters, where it held 18. A report or integration that expected 18 characters can now see longer values.
  - Some values of exactly 15 letters and digits, those shaped like a short record Id, are read as a record Id.
- **Two finders on each selector:**
  - `new kern.SEL_ApiCall().findByTriggeringRecordIds(Set<Id> recordIds, Integer rowLimit)`, and the same on
    `kern.SEL_ApiIssue`, find the rows of record Ids. They search the 18-character form of each Id, the form the framework
    writes. If your code sets Triggering Record ID itself, write `String.valueOf(recordId)`.
  - `findByTriggeringRecordValues(Set<String> values, Integer rowLimit)` on both selectors finds rows by any other value,
    such as an order number. It ignores upper and lower case, so do not use it for 15-character record Ids.
  - Both return at most `rowLimit` rows, newest first, with summary fields only: `Id`, `kern__ServiceName__c`,
    `kern__Status__c`, `CreatedDate` and `kern__TriggeringRecordIndex__c`. They never return the request or the response.
- **A copy option for bulk updates:** `kern.UTIL_BulkUpdates.copyField` copies one field into another on every matching row,
  in a background job. The optional script below uses it.
  - Before any job starts, it refuses a target field the running user cannot change, such as a formula, roll-up summary
    or auto number field, a field Salesforce sets (for example `CreatedDate`), or a field the user can only read.
  - It also refuses, before any job starts, a source field the running user cannot read, so a copy never shows values
    the user may not see. Both checks apply whatever the package's feature settings say.
  - The job saves only each row's Id and the target field, so the user needs no edit access to the source field.
- **What we measured.** On a test org holding about 100,000 API calls, with Salesforce's statistics counting 34,000 of them:
  - Salesforce's query plan for the finder's own query, with its sort order and a limit of 25, starts with the database
    index on Triggering Record Index, for one Id and for 200 Ids.
  - Salesforce rated that plan at under a tenth of the cost of its other plan, which reads the whole table.

**What to do:**

- If a report or integration reads Triggering Record ID on API issues, check that it can take up to 80 characters, where
  the field held 18.
- When your code, a report or a list view searches API calls or issues by record, filter on Triggering Record Index, as
  described below.
- If you want API calls and issues saved before the upgrade found by the finders, run the optional script below once, as
  a user with the Kern Administrator permission set.

**Who can use the finders?** The finders check the running user's access: object permissions, field permissions and record
sharing all apply. A user who should see a record's calls needs:

- read on API Call (and on API Issue, for the issue finder);
- read on `kern__ServiceName__c`, `kern__Status__c` and `kern__TriggeringRecordIndex__c` of that object;
- record sharing that shows them the rows. Both objects are private, so a user sees only the rows they own unless sharing
  shows them more.

A user without the object or field access gets an error (a `QueryException`), not an empty list.

- The upgrade adds read on the new field to the **Kern Administrator** permission set (with edit, which the script needs)
  and to the **Kern API Issue Resolver** permission set.
- **Kern Read Only** grants neither object, so it gains nothing.
- Give your own users, such as order users, the access in a permission set of your own.

**Your own code, reports and list views.** When your code, a report or a list view searches API calls or issues by record,
filter on Triggering Record Index (`kern__TriggeringRecordIndex__c`), not Triggering Record ID.

- It has an index, so the search stays fast on a large org.
- Fill the rows saved before the upgrade first, with the script below, or those rows are not found.

**Some KernDX checks still search Triggering Record ID.** They must find every row, including rows saved before the upgrade
whose Triggering Record Index is still blank. These are:

- after a successful outbound call to a service whose API Setting has **Resolve Issues** ticked, the search for the open
  issues that the call closes;
- in a bulk retry, the check for a call still open for the same record;
- in a bulk retry, the check for another open issue of the same request.

Triggering Record ID has no index, so on an org with a very large number of API calls or issues, these searches can be
slow.

- If they are, ask Salesforce Support to add an index on Triggering Record ID (`kern__TriggeringRecordId__c`) on API
  Call and on API Issue.
- Salesforce adds such an index on request, and then a search on the field no longer needs to read every row.

### Optional: fill Triggering Record Index on rows saved before the upgrade

The upgrade does not fill Triggering Record Index on calls and issues that already exist, so the finders do not find
them. If you want them found, run this script once in the Developer Console (Debug, Open Execute Anonymous Window):

```apex
// Fills Triggering Record Index on API calls and API issues saved before Kern 1.12, so the finders by triggering record
// find them. It copies Triggering Record Id into Triggering Record Index on every row where the Id is filled and the field is blank.
// Run it as a user with the Kern Administrator permission set, or with Modify All on both objects: any other user fills only
// the rows they own. It starts one background job per object. Check that both have ended under Setup, Apex Jobs.
// Running it again is safe: it only picks rows where Triggering Record Index is still blank.
kern.QRY_Condition.Evaluable callsToFill = new kern.QRY_Condition.AndCondition()
		.add(new kern.QRY_Condition.FieldCondition('kern__TriggeringRecordId__c', kern.QRY_Condition.Operator.NOT_EQUALS, null))
		.add(new kern.QRY_Condition.FieldCondition('kern__TriggeringRecordIndex__c', kern.QRY_Condition.Operator.EQUALS, null));
kern.UTIL_BulkUpdates.copyField('kern__ApiCall__c', 'kern__TriggeringRecordId__c', 'kern__TriggeringRecordIndex__c', callsToFill, 200, false);

kern.QRY_Condition.Evaluable issuesToFill = new kern.QRY_Condition.AndCondition()
		.add(new kern.QRY_Condition.FieldCondition('kern__TriggeringRecordId__c', kern.QRY_Condition.Operator.NOT_EQUALS, null))
		.add(new kern.QRY_Condition.FieldCondition('kern__TriggeringRecordIndex__c', kern.QRY_Condition.Operator.EQUALS, null));
kern.UTIL_BulkUpdates.copyField('kern__ApiIssue__c', 'kern__TriggeringRecordId__c', 'kern__TriggeringRecordIndex__c', issuesToFill, 200, false);
```

Before you run it:

- **Run it as a user with the Kern Administrator permission set, or with Modify All on both objects.** The jobs run as the user
  who starts them, and both objects are private. Any other user fills only the rows they own, and the jobs still end without an
  error, so the rest stay blank with no warning.
- **Run it out of hours on a large org.** Each row the script updates runs the object's trigger actions, masking included, the
  same as any other save.
- **It does not send a call that waits at Retry.** The script changes only Triggering Record Index. A call at Retry keeps
  its status and its Next Retry time, and the save does not start the Retry Outbound Api Call flow again, even when that
  time has passed. Such a call waits for the Outbound Retry Watchdog, where you schedule it.

After you run it:

- **It is finished when both jobs have ended,** under Setup, Apex Jobs.
- **Running it again is safe.** It picks only rows where the field is still blank, so a second run changes no row it already filled.
- **Some rows can stay blank:** rows with no Triggering Record ID, and rows the user who ran it could not edit. A list view on
  Triggering Record Index equals blank shows them; the Objects & Metadata guide has the steps.

Read more: [How do I find the calls made for one record?](../docs/Web%20Services%20-%20Guide.md#how-do-i-find-the-calls-made-for-one-record)
in the Web Services guide, [The Triggering Record Index](../docs/Objects%20%26%20Metadata%20-%20Guide.md#the-triggering-record-index)
in the Objects & Metadata guide, and [How do I copy one field into another on many records?](../docs/Utilities%20-%20Guide.md#how-do-i-copy-one-field-into-another-on-many-records)
in the Utilities guide.

## A read-only permission set for the Log Console

**New: the Kern Log Console Read Only permission set lets someone read every log entry in the Log Console without changing
anything.** Until now, reading the log needed Kern Administrator, which also lets the holder change every Kern setting.
Nothing to do unless you want to use it.

- It grants read and View All on log entries, read on the fields that hold their data, and the Log Console tab, and nothing
  else. A holder cannot create, edit or delete a log entry.
- It ships assigned to nobody. Assign it to a reviewer or an operator who only needs to read the log.
- A holder sees whatever every user's code logged, and each chain's name and status. Masking removes only what its rules name.

Read more: the [Logging guide](../docs/Logging%20-%20Guide.md) and the [Security guide](../docs/Security%20-%20Guide.md).

## Faster saves in an org with many objects

**Fixed: the first trigger action and the first validation rule check of a transaction no longer read the list of every
object in your org.** Saves are faster, most of all in an org with many objects. Nothing to do, unless your code catches
a `System.TypeException` from the two lookups below: see the link at the end.

- To find the built-in formula context of an object, KernDX now looks the object up by its name alone.
- In your tests, `kern.TST_Builder` no longer reads that list when it fills a lookup field with a default record.
- `kern.UTIL_SObjectDescribe.getDescribe(name)` and `kern.UTIL_SObjectDescribe.getSObjectTypeByName(name)` now return null
  for a name that is not an object, as their reference pages say.
- Until now the name of an Apex class, of a system type such as `String`, or `SObject` failed with a
  `System.TypeException`. For some class names, KernDX first created an instance of that class.
- The two lookups now find an object whose name is also the name of a system type, such as `Location`. Until now they
  failed for it.
- Every name that found an object still finds the same object.

Read more: [getDescribe and getSObjectTypeByName return null for a name that is not an object](#getdescribe-and-getsobjecttypebyname-return-null-for-a-name-that-is-not-an-object).

## Retry leaves an issue open when mock data answers it

**Fixed: when mock data answers a retried call, the API issue stays open.** This applies when you retry an API issue, replay
an inbound call, or retry issues in bulk. Before, the issue was marked Resolved, although the request was never processed.

- For an outbound call, Retry shows a message that says mock data answered the call: "The call was answered with mock data, not
  by the other system, so the issue stays open. Turn mocking off and try again."
- For a replayed inbound call (mocked by **Mock All Inbound APIs**, or by **Mock Selected APIs** with **Mocking Enabled** on the
  service's API setting), the message reads "The request was answered with mock data and was not processed, so the issue stays
  open. Turn mocking off and try again."
- A bulk retry leaves such an issue open and writes a warning to the log that counts the issues mock data answered,
  outbound and inbound alike.
- Dismiss works as before.

**What to do:** turn mocking off before you retry an issue you want resolved.

Read more:
[A call answered by mock data no longer resolves earlier issues](#a-call-answered-by-mock-data-no-longer-resolves-earlier-issues).

## Async chains: the whole-run performance entry follows Log Setting

**Fixed: the performance entry for a whole chain run now follows the performance settings in Log Setting, and a new
field gives chain runs a threshold of their own.** Nothing to do, unless a report or dashboard reads these entries: set
the new field to 0 to keep them all. Until now this entry was written whatever those settings said.

- **A new field on Log Setting, Async Chain Performance Threshold (ms)** (`AsyncChainPerformanceThresholdMs__c`). It is
  blank by default, and blank on your existing Log Setting records after the upgrade.
- **While it is blank,** the entry follows Enable Performance Logging and Performance Threshold (ms), as the entry for
  each step does. With the default threshold, a run shorter than 10 seconds gets no entry. With Enable Performance
  Logging off, no run gets one.
- **When it holds a number,** a run that took that long or longer gets the entry, even with Enable Performance Logging
  off. Set 0 to get an entry for every such run again. Set a very high number to stop the entries.
- **Only four endings write it:** a run that finishes all its steps, a run that stops because a step failed and is not
  retried, a run that fails because the data its steps share grew past its limit, and a run stopped because the
  `AsyncChain` feature flag is off.
- **A run that stops because a step failed now gets the entry too,** where it got none.
- The entry is still a DEBUG entry, so it is saved only when logging is on and the log level allows DEBUG.

Read more: [How are async chain runs timed?](../docs/Logging%20-%20Guide.md#how-are-async-chain-runs-timed) in the
Logging guide.

## Async chains: the watchdog keeps a query in hand

**Fixed: when the chain watchdog runs low on queries, it now leaves the chains it did not reach untouched.** Before, it
set them aside one at a time until no query was left, and each chain it set aside lost its place in the queue.

- The chains a sweep does not reach keep their status and their place, so the next sweep starts with the ones that have
  waited longest.
- A chain run no longer gets the text `Parked: no query budget`. A chain is still set aside, with `Parked: no async budget`,
  when your org has no background-job capacity left.
- Before each chain, a sweep checks that enough queries are left for that chain's own work and one more, so its own
  work never uses the last query. A trigger or flow of yours on chain run records spends queries from the same limit of
  100, and the sweep cannot keep them back for it.

**What to do:** nothing, unless a report, list view or automation looks for the text `Parked: no query budget`.

Read more: the [Async Processing guide](../docs/Async%20Processing%20-%20Guide.md#monitoring).

## Code scanning: the inline SOQL rule points to a selector

**Changed: the `KernNoInlineSOQL` rule's message tells you to read through a selector.** It used to say "Use a selector
(SEL_*) or QRY_Builder", and the guides no longer teach the second choice. Nothing to do.

- The message now reads "Inline SOQL is not allowed. Read through a selector (SEL_*), or its query property for a custom
  query."
- The rule's description says what it flags: every `[SELECT ...]` query and every Database query method, such as
  `Database.query()`, in any class, test classes included.
- It names the only two cases for plain SOQL: a query the framework cannot express (raise it with the KernDX team), or code
  the framework does not reach. Keep that query in one place, mark it with `@SuppressWarnings('PMD.KernNoInlineSOQL')`, and
  say in a comment why it cannot use a selector.
- Only the text changes. The rule's name, what it flags and its priority are the same, so a scan finds what it found before.

Read more: the [Code Scanning guide](../docs/Code%20Scanning%20-%20Guide.md).

## Fixed: a formula with no context class name on API Call and API Issue

**A trigger action row with an entry formula and a blank context class name is accepted on API Call and API Issue**,
which have built-in contexts. Nothing to do.

- Until now the rule that checks it never recognised these objects.
- Every other custom object still needs a context class name.

Read more: [How do I add actions to KernDX's own objects?](../docs/Triggers%20-%20Guide.md#how-do-i-add-actions-to-kerndxs-own-objects)
in the Triggers guide.

## Data masking: two JSON values in one value

**Fixed: a JsonKey rule now masks a value that holds two JSON values one after the other.** Some systems write one JSON
object per line (often called JSON Lines), and a field or an API body can hold such a value. Nothing to do.

- Until now only the first object was read. A secret in a later object, such as `{"user":"a"} {"password":"x"}`, was
  saved as it came. When the first object held a secret, the objects after it were dropped from the saved value.
- Now such a value is searched as text for `"key":"value"` pairs, the same way as text that is not JSON. Every plain
  value under a matching key is masked, and every object is kept.
- When a matching key holds an object or a list, the text search cannot hide it safely, so the whole field is saved as
  `[MASKING_FAILURE]`. The same happens when the rule's key pattern is one the text search cannot run safely, such as
  `.*secret.*`, and the value holds a quote. The field loses its detail, but no secret is stored.
- A JsonKey rule does not read Min Input Length, as the field's description says. From 1.12 this holds for every
  value. Until now a value that was not read as JSON (two JSON values, broken JSON, or plain text with
  `"key":"value"` pairs) was saved as it came when it was shorter than the minimum. Now a short value is masked too.
- The same holds for a value that starts with a whole JSON object and goes on after it, such as
  `{"user":"a"}, "password":"x"}`, and for JSON that the platform's reader refuses.
- A value with more than 500 opening brackets was already read to its end, one piece at a time, and every object in it
  is masked.

Read more: [How does a JSON-key rule read a value?](../docs/Data%20Masking%20-%20Guide.md#how-does-a-json-key-rule-read-a-value)
in the Data Masking guide.

## Guides corrected

If you copied a sample from the guides, check the first part below: some samples did not compile or run in your org.
The rest corrects what the guides said, or makes them shorter.

**If you copied one of these samples, change it**

- **The formula examples turn a picklist into text first.** The examples for `kern.UTIL_FormulaContext` and
  `kern.UTIL_FormulaFilter`, and in the Triggers, Validation, Utilities and Objects & Metadata guides, compared a
  picklist field with `=` or `<>`, which Salesforce refuses. They now write `TEXT(newRecord.Industry) = "Technology"`. If
  you copied one, change it the same way.
- **The `kern.UTIL_BulkUpdates` examples now compile in your org.** They build each condition with the
  `kern.QRY_Condition.FieldCondition` constructor that takes an operator.
- **DTO and async samples now compile and run.** If you copied one of these samples, make the same change to your copy:
  - The DTO samples in the DTOs and Web Services guides and the `kern.DTO_JsonBase` examples overrode `getObjectType()` as
    `protected`, which does not compile in your org; they are now `public`.
  - The Async Processing Fast Start cast its items in a way that throws a `TypeException`; the casts are fixed.

**Corrected statements**

- **The front page counts the masking templates correctly.** It said 15 inactive rule templates, JWT among them. KernDX ships
  14 inactive templates, and JWT is masked from the moment you install.
- **The Data Masking guide says up front that masking needs the trigger.** An object is masked only when it is on the KernDX
  trigger framework, with a trigger setting that has **Apply Masking** checked.
- **The Logging guide says when a log entry is undone.** Inside a platform-event or change-event trigger, the entry is saved
  as part of the trigger's own transaction, so an error that undoes that transaction undoes the entry too.
- **The logging pages say that DEBUG entries are kept** unless you raise the log level threshold, as the field's default
  shows.
- **The Logging Fast Start's test says who can read log entries:** a System Administrator, or a user with the
  `kern.Administrator` permission set. Keep the read outside `System.runAs`, where the user Id field still holds the user who
  started the test.
- **The Logging Fast Start no longer says** that the query builder cannot filter on a KernDX field of a KernDX object. The same
  query runs in an org with the package installed.
- **The Execute Validation Rules Flow action no longer promises ISCHANGED.** Its reference now says that a rule compares the
  old and new values, with a picklist turned into text first, and that ISCHANGED and PRIORVALUE are not available.
- **The Security guide answers "How do I see who turned a check off?"** with a query proven on an installed package. The
  Triggers and Validation guides point to it instead of an example that read the wrong user.
  [Read it](../docs/Security%20-%20Guide.md#how-do-i-see-who-turned-a-check-off).
- **The strategic guides match the latest comparison of 26 frameworks**, including two new ones, ApexKit and apex-dml-mocking.
  They now state a gap: KernDX does not fake the writes of the code under test, and apex-dml-mocking and apex-fluently-dml do.
  Several older errors are corrected, and the Adoption guide's claim about the ApexDoc of the Trigger Actions Framework
  (taf) now matches its evidence.
- **The Data Masking guide no longer promises an order** for the names in a masked message. Salesforce does not guarantee one.
- **The Async Processing guide asks you to keep queries and saves out of your automation on chain run records.**
  - A trigger or record-triggered flow that runs a query or saves a record there spends the chain watchdog's limits.
  - At volume, an Apex trigger like that can stop the watchdog recovering stuck chains, and a flow makes each sweep
    recover fewer.
  - Use an `onError` handler to act on a failed or stalled chain.
    [Read it](../docs/Async%20Processing%20-%20Guide.md#monitoring).
- **The circuit breaker default and the longest retry wait.** The Objects & Metadata and Web Services guides now say what
  KernDX does. See [the breaker default and the longest retry wait](#outbound-calls-the-breaker-default-and-the-longest-retry-wait).
- **Post-trigger actions run once at the end of each trigger pass,** not once per save, and a nested pass (a save that a
  trigger action makes) runs none. The Objects & Metadata guide now says so.
- **The selector samples declare `with sharing`.** The samples of selectors of your own in the Selectors, Triggers, Async
  Processing and Security guides now declare `with sharing`, the default for selectors you write.
- **The Selectors guide says where a space may go in a DISTANCE expression.** A space before a comma is refused, and a
  space after one is fine.
- **A field with the same name as a package field.** On a KernDX object, a field of yours with the same name as a package
  field cannot be read through a selector or the query builder, by name or by token. Give your field another name. The
  Selectors guide now says so.
- **The user-mode queries flag.** The Feature Flags guide now says never to give `UserModeQueries_Enabled` a strategy
  that runs a query, and what to use instead.
- **`getFailureMessage()` in the DML pages.** The DML Fast Start lists it among the readers of a save's result. The DML
  guide's error-handling sample says to read it when an error stops a partial save.
- **The LWC samples:**
  - The JavaScript samples in the LWC guide and Fast Start - LWC take the text a user reads from custom labels of your
    own, and say to create those labels before you deploy. The first tier of Fast Start - LWC now creates its label in
    Setup.
  - The save samples show the success toast only after the save works. Your Apex method must return a value; for one
    that returns nothing, use `{isThrow: true}` with `try` and `catch`.

**Rewritten guides**

- **Every guide is shorter and opens with the task you came for.**
  - Each section leads with the answer, in tables, bullets and code, and a fact said on several pages is said once, with
    a link.
  - Every code block, name and number is kept. Old links to a moved or renamed section open at its new place.
  - The Selectors guide no longer compares KernDX with plain Salesforce or has a capability table: the Why KernDX front
    page explains why the framework is worth using, and old links to those sections open it.
- **Every read goes through a selector.** Every page now says the same: read through a selector.
  - The guides used to call the query builder the everyday default and a selector the choice for a read you reuse, and
    one page listed reasons to write plain SOQL.
  - A selector's default fields cover the usual case, and one call on its query property adds fields (`addField`,
    `addFields`, `addFieldSet`, `relatedFields`) or replaces them (`fields`, `fieldSet`).
  - Plain SOQL is only for a query the framework cannot express (raise it with the KernDX team) or code the framework
    does not reach.
  - The AI agent instructions your tools read say the same, and the Adoption guide's integration test finds a record's
    API calls with `findByTriggeringRecordIds`.
- **Seventeen guides open with a "Copy this first" sample:** a short working example, one line on what it does, and links to
  read next. Each sample uses the `kern.` prefix and only global members, and runs in a test on an org with the package
  installed.

## Outbound calls: the breaker default and the longest retry wait

**Corrected: the field help and the guides now say what KernDX does with two API setting fields. Nothing changes in how
your calls run.** Nothing to do unless you want other values, as below.

- **Circuit Breaker Failure Threshold** (`CircuitBreakerFailureThreshold__c`): a blank value means 5 failures in a row,
  whatever the field help in your org says. The field help and the Objects & Metadata guide said 10.
- **Retry Backoff (sec)** (`RetryBackoffSeconds__c`): the wait worked out from this value is never longer than 300
  seconds, so a value above 300 works as 300. While the circuit breaker is open, a retry waits for the breaker's
  cool-off if that is longer.
- A handler that overrides `createRetryStrategy()` sets its own longest wait. The Web Services guide shows how to wait
  longer than 300 seconds.
- The two fields' descriptions and help text say this now, on new installs only. An upgrade keeps the old help text in
  your org.

**What to do:**

- If you want a threshold other than 5, enter it in Circuit Breaker Failure Threshold.
- If you want to wait longer than 300 seconds between retries, override `createRetryStrategy()` in your handler.

Read more: [Automatic Retries](../docs/Web%20Services%20-%20Guide.md#automatic-retries) and
[Custom Retry Strategies](../docs/Web%20Services%20-%20Guide.md#custom-retry-strategies) in the Web Services guide.

## Outbound calls: keep a queued send within 120 seconds

**Guidance, and one known issue. Nothing changes in how your calls run.**

- **Size the queued send.** A queued send has 120 seconds of callout time, the limit Salesforce gives one job. A call
  the job cannot send in that time still uses up one of its retries, so with a large job size and slow services, calls
  can become API issues without being sent. Keep the job size (an Asynchronous Job Setting named
  `kern_FLOW_CallApiAsync`, 20 by default) times your longest handler timeout under 120 seconds.
- **Set a timeout on every handler.** Override `getTimeout()`. A handler that sets none waits up to 120 seconds, the
  whole callout time of a job.
- **Known issue: Retry Selected on many inbound issues.** Retry Selected runs as many requests in one job as the job
  size, 20 by default. Twenty inbound replays can pass the save limit of one job, and the job then fails and undoes what it did, so its issues
  stay Open; outbound calls in the same job that were already sent can be sent again by a later retry.
  ([kerndx#39](https://github.com/JVB-Consulting/kerndx/issues/39))

**What to do:**

- Check the job size against your handlers' timeouts, and set `getTimeout()` on each handler.
- Until the known issue is fixed, create an Asynchronous Job Setting named `kern_FLOW_CallApiAsync` with a Batch Size of
  10 or less, or select 10 or fewer inbound issues per Retry Selected.

Read more: [Building Outbound APIs](../docs/Web%20Services%20-%20Guide.md#building-outbound-apis) in the Web Services guide.

## Corrected: commitWork(false) with a permission set

**Corrected: the 1.10 release note and the reference said that Kern checks a `commitWork(false)` save with a permission set
first, and then sends it to Salesforce again with the set.** That never ran. Nothing changes in what your org does.

- A save whose access level is `AccessLevel.USER_MODE.withPermissionSetId(...)` goes to Salesforce as it is.
- Salesforce applies the user's permissions plus the permission set's, and record sharing.
- So `commitWork(false)` does not ignore record sharing for that save.
- The DML and Security guides now say so.

Read more: [Operation-Level Sharing](../docs/DML%20-%20Guide.md#operation-level-sharing) in the DML guide, and the
[Security guide](../docs/Security%20-%20Guide.md).

## Find what you need in the docs faster

The docs site is easier to search and to find your way around, and the guides answer more of the questions people ask.
Nothing to do.

**Search**

- **Search finds a method by name.** A reference page is now found by its method headings, so a search for `withSystemMode`
  finds it. Guides, Fast Starts and reference pages rank above release notes and the strategic guides.
- **Search finds a feature from the words you already use.** A guide section can list the words a Salesforce developer would
  type for it, and search treats common spellings as one word, such as end-to-end and e2e, or flag and flags. A word in a
  guide's title ranks that guide first, so "feature flag" finds the Feature Flags guide.

**Finding your way**

- **Each docs area has its own menu.** The top menu gains **Guides**, and Why KernDX, Get Started, Fast Starts, Guides and
  Reference each show only their own pages. Each guide has a "Reference for this page" list of the classes it uses most.
- **Reference pages link to their teaching pages.** Each Apex class page opens with a "Learn it:" line that links the Fast
  Start and guide that teach it.
- **Nine reference pages group their methods by task.**
  - The `kern.QRY_Builder.Builder` reference page opens with a "Methods by task" table (choose fields, filter, sort and
    limit, count and total, run the query, security and row locking), each with a link to a worked example.
  - `kern.UTIL_SObjectDescribe`, `kern.UTIL_HttpClient.RequestBuilder`, `kern.API_Outbound`, `kern.UTIL_Limits`,
    `kern.SEL_Base`, `kern.QRY_Builder.ConditionBuilder`, `kern.API_Inbound` and `kern.DML_Builder` now list their methods
    the same way, each group linked to its worked example where a guide has one.
- **The reference opens with its task table, and every type is filed under its area.** Inner types and triggers show the
  area they belong to, so the reference index no longer has an "Uncategorized" section.
- **The Why KernDX front page covers every feature.**
  - It has twenty before-and-after examples in four groups, a jump list to each one, what you write and configure for
    each, and the full list of gains per example.
  - New examples cover outbound calls, Flow actions, test data, Lightning web components, DTOs (small classes that turn
    themselves into JSON and back), feature flags, scheduled jobs, sharing and security, the consoles, Platform Cache and
    code scanning.
  - Its code uses the managed package's `kern.` and `kern__` prefixes.
- **New page: From Plain Apex to KernDX.** It shows seven everyday jobs in plain Apex beside the KernDX version: reading and
  saving records, logging, background work, triggers, callouts and testing. A table on the landing page and on Fast Starts maps
  "I need to..." to a Fast Start, a guide and a reference page.
- **The page contents open at the section you are reading.** On the eight longest guides, "On this page" shows the main
  headings and opens the section you are in, with a "Show all headings" button.
- **A plain Markdown copy of every page, for AI tools.** Add `.md` to a page's address. `llms.txt` tells tools where to find
  them.
- **Pages respond sooner, on a phone most of all.** The sidebar builds only the groups that are open, and it opens your group
  before the page reaches the browser, so reference pages no longer shift as they load.
- **The site keeps the docs of the three most recent earlier versions.** A link into a version the site no longer keeps opens
  the same page in the current docs.

**New answers in the guides**

- **The Triggers guide shows how to move your own trigger handler into trigger actions.** Its first warning: a blank
  Failure Action means an exception no longer stops the save, so choose Block DML where your old code relied on one.
  [Read it](../docs/Triggers%20-%20Guide.md#moving-your-own-trigger-handler-into-trigger-actions).
- **A search for the query limit error finds the fix.** The Triggers guide quotes
  `System.LimitException: Too many SOQL queries: 101` and shows how trigger actions stay under the limit. It also says
  that `Trigger.oldMap` is null when a test calls an action directly, and how to pass the old records yourself.
  [Read it](../docs/Triggers%20-%20Guide.md#issue-governor-limits-exceeded).
- **The Test Data guide explains the mixed DML error** (`MIXED_DML_OPERATION`): when it happens, and how `System.runAs`
  avoids it in a test. It also explains how to run test code as another user. The DML guide says that its "Mixed
  Operations and Rollback" is not that error.
  [Read it](../docs/Test%20Data%20-%20Guide.md#users-and-permission-sets).
- **The Objects & Metadata guide answers "Why did a setting not change after an upgrade?"** The custom metadata values
  your org controls keep your values on upgrade, and a changed help text reaches only new installs.
  [Read it](../docs/Objects%20%26%20Metadata%20-%20Guide.md#why-did-a-setting-not-change-after-an-upgrade).
- **The Async Processing guide says that chains have no rate limits or failure alerts,** and what to use instead.
  - To protect a service, use a retry strategy and a circuit breaker.
  - To hear about failures, use the run status, the ERROR log entries, an `onError` handler and the watchdog.
  - The guide also says when `onError` does not run, and the Resilience guide links to it.
    [Read it](../docs/Async%20Processing%20-%20Guide.md#chains-have-no-rate-limits-or-failure-alerts).
- **The LWC guide explains wire adapters** under "ComponentBuilder Pattern".
  [Read it](../docs/LWC%20-%20Guide.md#componentbuilder-pattern).

---

## Upgrading & compatibility

**The global Apex signatures are unchanged.** No global member is removed or changed in signature. Added:

- `kern.DML_Builder.TransactionResult.getFailureMessage()`;
- `findByTriggeringRecordIds` and `findByTriggeringRecordValues` on `kern.SEL_ApiCall` and on `kern.SEL_ApiIssue`;
- `kern.UTIL_BulkUpdates.copyField`;
- the `COPY_FROM_FIELD` value of the `kern.PROC_UpdateFields.FieldUpdateMethod` enum;
- `kern.SCHED_OutboundRetryWatchdog`;
- `kern.UTIL_FormulaContext.ApiCallContext` and `kern.UTIL_FormulaContext.ApiIssueContext`.

These global members keep their signatures but change behaviour, as described in
[Changes that can affect code you have written](#changes-that-can-affect-code-you-have-written):

- `kern.PROC_ExecuteDML` and `kern.PROC_UpdateFields`, built with an access level that names a permission set;
- the reads of `kern.QRY_Builder.Builder` after `bypassSharing()` without `withSystemMode()`;
- `kern.API_Outbound`: a successful call answered by mock data no longer resolves earlier open issues for the same request;
- `isSuccess()` and `getFailureCount()` on `kern.DML_Builder.TransactionResult`, after a save made with `allowPartial()`;
- `kern.TRG_Base.bypassAction`, `isActionBypassed` and `clearActionBypass`;
- `kern.UTIL_AsynchronousJobLauncher.process`: a refused queueable launch arrives as a KernDX exception, and a request that
  forces `PARALLEL_QUEUEABLES` for a `Finishable` processor is refused;
- `kern.IF_Async.Finishable`: under `BATCH`, `finish` runs once, only when every chunk succeeded;
- `kern.FLOW_CallApiAsync.invokeApiCallAsynchronously`: a refused send waits at Retry instead of failing the save, and the
  action writes Retrying on the Retry calls it is given before it starts them. Its saves ignore record sharing, and a call
  whose save as Retrying is refused is not sent;
- `kern.SCHED_PerformBatchedCallouts.execute`: its save ignores record sharing and saves only the status, so every Batched
  call moves to Queued;
- `kern.PROC_UpdateFields.execute`: it saves only each record's Id and the fields in its list of updates;
- `count()`, `exists()`, `getPage()` and `getRandomItems` of `kern.QRY_Builder.Builder`: their counts keep a data category
  filter;
- `kern.UTIL_Date.toIso8601(Date)`, `kern.UTIL_Random.randomDate()` and `kern.UTIL_Random.randomDateTime()`: the epoch
  date is 1970-01-01 in every time zone;
- `kern.UTIL_List.partition`: it returns every item;
- `kern.FLOW_RetryApiIssues.retryApiIssues`: a request is no longer queued when any of its open issues, selected or not,
  is on a call that failed permanently or has **External System May Have Acted** ticked, and
  `queuedCount` leaves them out (see
  [Bulk retry skips a request with an issue that failed permanently](#bulk-retry-skips-a-request-with-an-issue-that-failed-permanently));
- `kern.DML_Transaction.setAccessLevel`, `kern.DML_Transaction.commitWork(Boolean)` and the `kern.PROC_ExecuteDML`
  constructor that takes an access level: they write a bypass entry for a save in system mode or without record sharing;
- `kern.UTIL_SObjectDescribe.getDescribe(String)` and `kern.UTIL_SObjectDescribe.getSObjectTypeByName`: a name that is not an
  object returns null, and an object whose name is also a system type, such as `Location`, is found;
- `kern.TST_Builder.of(String)`: for the name of an Apex class or a system type, it throws an
  `IllegalArgumentException`, where it threw a `System.TypeException`;
- reads of mocked API calls and API issues through `kern.TST_Mock` in your tests: a read with conditions returns only the
  mocks that match, an answer scripted with `registerNext` included. On every object with a formula context, a mocked
  `count()` or `exists()` counts only the matching mocks, and a date-and-time condition is checked at whole seconds (see
  [Your tests: mocked API calls and API issues are filtered](#your-tests-mocked-api-calls-and-api-issues-are-filtered)).

**The metadata surface mostly adds.** Nothing is removed or renamed. These existing items change:

- The **Retry Outbound Api Call** flow (`RetryOutboundApiCall`) no longer has its "Set Status to Retrying" step. Its
  scheduled path holds only the Apex action, which sets the call to Retrying itself before it starts the send.
- Triggering Record ID (`TriggeringRecordId__c`) on API Issue now holds up to 80 characters, where it held 18. Its
  description and help text change, and so do those of Triggering Record ID on API Call. An upgrade keeps the earlier
  help text.
- The validation rule `EntryCriteriaContext_RequiredForFormula` on Trigger Action now accepts a blank context class name
  on API Call and API Issue, and its error message names them among the objects with built-in contexts.
- The triggers on API Call, API Issue, Scheduled Job and Async Chain Execution register all seven trigger events.
- Two label values change: the job runner refusal (`ScheduledJob_ManageJobRunnerPermissionRequired`) and the bulk retry
  result (`RetryApiIssues_Queued`), which now also names a call that failed permanently. Both keep their placeholders. If
  you translated them, your translations keep the earlier words.
- The description and help text change on the Target field of Feature Flag Strategy, the Caller Class field of Masking Target
  and the Apply Masking field of Trigger Setting. An upgrade keeps the earlier help text.
- The help text changes on the Log Level Threshold field of Log Setting, on new installs only. An upgrade keeps the earlier
  help text.
- The description and help text change on the Circuit Breaker Failure Threshold and Retry Backoff (sec) fields of API
  Setting (`ApiSetting__mdt`). They reach new installs only; an upgrade keeps the earlier help text.
- Enable Performance Logging (`EnablePerformanceLogging__c`) on Trigger Setting is deprecated and has no effect.
  - Its new label, **Enable Performance Logging (Deprecated)**, and its new description reach your org with the upgrade.
  - Its new help text, and its removal from the Trigger Setting page layout, reach new installs only. An upgraded org
    still shows the checkbox on the layout, with its earlier help text. It has no effect either way.
- The description and help text change on the performance fields of Trigger Setting, Trigger Action and Post-Trigger
  Action (Performance Threshold (ms), Force Performance Logging, Suppress Performance Logging), and on Enable Trigger
  Performance Logging of Log Setting. An upgrade keeps the earlier help text.
- The description and help text change on Enable Performance Logging and Performance Threshold (ms) of Log Setting:
  they now say that they also decide the entries for async chain steps, and for whole chain runs while Async Chain
  Performance Threshold (ms) is blank. An upgrade keeps the earlier help text.
- The description and help text change on the Error Message field of Validation Rule. An upgrade keeps the earlier help text,
  which still says that Custom Labels are not resolved.

Added:

- A new permission set, **Kern Log Console Read Only** (`LogConsoleReadOnly`), assigned to nobody.
- A new field on API Call and on API Issue, **Triggering Record Index** (`TriggeringRecordIndex__c`). It is an External ID, so
  Salesforce indexes it, and it holds a copy of Triggering Record ID.
- Five new trigger action records. `ScheduleJob_AfterUndelete` switches off a job restored from the Recycle Bin. Four fill
  Triggering Record Index when an API call or an API issue is inserted or updated: `SetApiCallTriggeringIndex_BeforeInsert`,
  `SetApiCallTriggeringIndex_BeforeUpdate`, `SetApiIssueTriggeringIndex_BeforeInsert` and
  `SetApiIssueTriggeringIndex_BeforeUpdate`.
- The Kern Administrator permission set can read and edit Triggering Record Index on both objects. The Kern API Issue Resolver
  permission set can read it.
- A new field on the chain run object, **Stalled At** (`StalledAt__c`). The Kern Administrator permission set can read and
  edit it, and Kern Async Chain Monitor Read Only can read it.
- A new field on Log Setting, **Async Chain Performance Threshold (ms)** (`AsyncChainPerformanceThresholdMs__c`). It
  reads blank on your existing Log Setting records, so the whole-run performance entry of a chain follows Enable
  Performance Logging and Performance Threshold (ms) until you set it.
- A new validation rule on Masking Target, `CallerClassOnlyForApiRecords`.
- Seventeen new Custom Labels carry the new messages:
  - the two `bypassSharing()` refusals of a read through a lookup the user cannot read
    (`QueryBuilder_BypassSharingLookup_NotReadable`) and of selected text KernDX cannot check
    (`QueryBuilder_BypassSharingSelectedText_NotCheckable`);
  - the time zone refusal;
  - the refusal to restore a job that could not be switched off (`ScheduledJob_RestoreNotSwitchedOff`);
  - the purge warning;
  - the refusal of a move into Stalled without Stalled At (`AsyncChain_StallTimeRequired`);
  - two Data Masking Advisor messages about a Caller Class;
  - the two Retry messages for a call answered by mock data;
  - the text on an outbound call whose send was refused (`OutboundCall_LaunchRefused`);
  - the two Outbound Retry Watchdog texts;
  - four log messages about background jobs (a skipped `finish`, a refused parallel launch, a refused delayed start and a
    batch that failed before its first chunk).

An upgrade does not add the new fields to your profiles or to your org's own permission sets. Only the Kern permission sets
named above grant them.

**Nothing to remove.** These changes reach your org with the package.
