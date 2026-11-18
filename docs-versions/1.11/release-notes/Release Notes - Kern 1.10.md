# Kern 1.10 Release Notes

**Platform:** Salesforce API 68.0 (Winter '27) · **Namespace:** `kern` (rebrandable via [Installation](../docs/Installation.md))
**Release status:** released. Kern 1.10.0-4 is the production-installable 1.10 line.

## The headlines

> **What you need to do after the upgrade**
>
> 1. **If an incoming service of yours has Mocking Enabled ticked so that it answers mock data:** turn on the new **Mock Selected
>    APIs** feature flag for its callers straight after the upgrade. [Upgrade step](#upgrade-step-if-you-rely-on-inbound-mocking)
> 2. **If your code overrides `onCommitWorkStarting()` in an outbound handler, or `disconnectedCallback` in a component that extends
>    `ComponentBuilder`:** call the `super` version first. [Details](#changes-that-can-affect-code-you-have-written)
> 3. **If a test of yours registers record mocks for an object and runs an aggregate query on it:** register aggregate rows too.
>    [Details](#record-mocks-never-answer-an-aggregate-query). **If a test builds a permission set group with DML and then checks
>    a custom permission:** call `Test.calculatePermissionSetGroup` after building the group.
>    [Details](#a-test-that-builds-a-permission-set-group-recalculates-it-first)
> 4. **If your code passes a field name to the query builder as text** for a condition, a sort or a grouping: run your tests after
>    the upgrade. Text that is not a field name, or one of the other forms SOQL allows there, now throws. [Details](#security-fixes)
> 5. **If your code calls `bypassSharing()` on a query or a save, or `commitWork(false)`, without `withSystemMode()`:** such a read
>    or save now reaches records whatever their sharing, and leaves out the fields the user cannot read or edit, without an error.
>    In 1.9 it kept the user's own sharing. Check that each call should do this. If one must reach a hidden field, add
>    `withSystemMode()`.
>    [Details](#reads-and-saves-with-bypasssharing-ignore-record-sharing-and-keep-field-permissions)
> 6. **If your code calls `bypassSharing()` on a query without `withSystemMode()`, and then `toQueryLocator()`, `toCursor()`,
>    `toAggregateList()`, `getFirstAggregate()`, or any read of a grouped query (`toList()` and `count()` included):** add
>    `withSystemMode()` to that read. It now throws before any query runs. A batch class whose start method returns such a
>    locator fails as soon as it starts.
>    [Details](#locators-cursors-and-totals-with-bypasssharing-alone-now-throw)
> 7. **If a trigger action's entry formula uses a context class that has a `preLoad()` method:** test a save that runs it. The
>    method now runs there, and an error it throws stops the save. [Details](#a-trigger-actions-entry-formula-runs-preload)
> 8. **If your masking rules cover API call records, log records or other records saved on 1.9.0-4:** review them. A secret in a
>    long value could be saved unmasked on 1.9.0-4; 1.10 masks it, but records already saved stay as they are.
>    [Details](#security-fixes)
> 9. **If your code catches `TypeException` around `suppressExceptions().execute()`:** read the result instead. A save refused
>    because the user lacks the object permission now returns a failed result rather than throwing, so a `catch` around it no
>    longer runs. [Details](#suppressexceptions-returns-a-result-when-the-user-lacks-the-object-permission)
>
> **Your code keeps compiling.** No global Apex member is removed or changed in signature. These are added:
> `kern.API_Outbound.onCommitWorkStarting()` and, for tests, `kern.QRY_Builder.setAggregateMock` and two forms each of
> `kern.TST_Mock.registerAggregateRows` and `kern.TST_Mock.registerNextAggregateRows`, and, for the package's own tests only, the class
> `kern.UTIL_FormulaContext.FoobarBulkContext` with seven properties. Other changes you may notice, and what each one needs, are in the [behaviour changes at a
> glance](#behaviour-changes-at-a-glance).

**Security fix: text passed where the query builder expects a field name can no longer change the query. Upgrade every org.**
The query builder's methods that take a field name as text for a condition, a sort or a grouping now accept only a field name or a
path through a lookup, a date or distance expression of the kind `kern.QRY_Function` writes, an aggregate or `toLabel()` where
SOQL allows one, and in a sort `ASC`/`DESC` and `NULLS FIRST`/`NULLS LAST`; `orderBy` and `groupBy` also take a list of those.
Other text throws an `IllegalArgumentException` before a query runs. Values you pass are sent as bind variables (beside the query
text, never inside it) or escaped (quote marks made harmless), as before. [What changed](#security-fixes)

**Security fix: `bypassSharing()` ignores record sharing, and keeps the user's object and field permissions.**
Record sharing decides which records a user may see, for example only the records they own. Under the default settings,
`bypassSharing()` on the query builder and on `kern.DML_Builder`, and `kern.DML_Transaction.commitWork(false)`, now read and save
records whatever their sharing, as their descriptions always said. The user's object and field permissions still apply: fields
the user cannot read are removed from the rows, and fields the user cannot edit are left out of the save. A locator, a cursor,
or a read of totals or groups with `bypassSharing()` alone now throws: add `withSystemMode()`.
[What changed](#reads-and-saves-with-bypasssharing-ignore-record-sharing-and-keep-field-permissions)

**Saves that used to fail or go wrong now work.**

- **Create forms.** A checkbox that you configure through the form's `fields` property, and that the user never touches, no longer
  makes the save fail. The form sends the checkbox as it shows it. An edit form's update now saves, and a create form that copies a
  record saves the copy as a new record.
- **Scheduled jobs.** Saving a job in the editor window that Health Check opens no longer moves a job that runs on the job runner back
  to its own schedule. It no longer empties the job's Run Priority either.
- **Chain monitor.** The chain monitor is the console for Kern's background job chains. Its **Abort** now stops only the run its
  confirmation named. If the selection changed while the confirmation was open, it stops nothing and shows a warning instead.

[What changed](#saves-that-used-to-fail-or-go-wrong-now-work)

**A chain started from a trigger inside a background job now runs.**
In 1.8 and 1.9 a chain started from a trigger that fired inside a Queueable job (a background job) failed: inside another managed
package's job, inside your own, and inside a chain step whose save fires the trigger. A caller that caught the error could be left with a chain
run stuck in the Running state and no job behind it, which the Chain Watchdog later marked Stalled. From 1.10 the chain starts, and a
launch that fails saves nothing. This fixes issue [#64](https://github.com/JVB-Consulting/kerndx/issues/64).
[What changed](#a-chain-launched-inside-a-queueable-job-starts-or-fails-and-saves-nothing)

**Mock one service at a time, outgoing or incoming.**
Tick **Mocking Enabled** on a service's API Setting, the record that configures the service. Then turn on the new **Mock Selected
APIs** feature flag for the users who should get mock answers. For those users, the service answers from its API Mock records. For
everyone else, it works for real. An incoming service with the box ticked now needs the flag too. This fixes issue
[#52](https://github.com/JVB-Consulting/kerndx/issues/52). [How to use it](#mock-one-service-at-a-time)

**Outbound handlers can now run code just before the framework saves a call's changes.**
A handler that extends `kern.API_Outbound` can now override `onCommitWorkStarting()`. This step runs just before the framework saves
the call's changes. Handlers that extend `kern.API_Inbound` already could. Inbound and outbound handlers now offer the same hooks.
[How to use it](#outbound-handlers-can-run-code-just-before-the-save)

**A new code-scan rule finds a class of yours that the framework cannot read.**
The framework reads some of your classes, such as a validation rule's context class, by turning them into JSON. Salesforce blocks this
when the class has no `@JsonAccess`. The merge fields in your validation messages can then come back blank, with no error. The new
rule, `KernJsonReadClassNeedsJsonAccess`, finds the missing annotation before you deploy.
[The rule](#a-new-rule-kernjsonreadclassneedsjsonaccess)

**Aggregate queries can be mocked in tests.**
An aggregate query counts, adds up or groups records. A test can now hand such a query the rows it returns, with
`kern.TST_Mock.registerAggregateRows`, so the code that reads the totals is tested without inserting records. One rule comes with it:
record mocks never answer an aggregate query. A test that registers only records for an object, and then runs an aggregate query on
it, now fails with a message that says what to register.
[How to use it](#mock-an-aggregate-query)

**A list of numbers, dates or booleans in `isIn` now works for very large and very small numbers.**
The list is passed to the database as a bind variable (a value sent beside the query text, as a list of Ids or text already was). So
`123456789012` and `0.000000001` match as written, where they used to make the query fail. This fixes issue
[#63](https://github.com/JVB-Consulting/kerndx/issues/63).
[What changed](#a-list-of-numbers-dates-or-booleans-is-passed-as-a-bind-variable)

**A record with a blank key no longer matches blank rows.**
`isIn(records, field)` and `isInStrict(records, field)` now skip a record whose key field is blank. Until now that record put a blank
value into the list, so `isIn` also matched every row whose field was blank. `notInSet` and `notInSetStrict` treat a blank key as before.
[What changed](#a-record-with-a-blank-key-no-longer-matches-blank-rows)

**A record type is found whatever the case of its developer name.**
`kern.UTIL_SObjectDescribe.getRecordTypeByDeveloperName()` and `isRecordTypeAvailable()` now match the developer name without regard
to case. Until now only the exact case was found.
[What changed](#a-record-type-is-found-whatever-the-case-of-its-developer-name)

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [The headlines](#the-headlines)
2. [At a glance](#at-a-glance)
3. [Behaviour changes at a glance](#behaviour-changes-at-a-glance)
4. [Saves that used to fail or go wrong now work](#saves-that-used-to-fail-or-go-wrong-now-work)
5. [Mock one service at a time](#mock-one-service-at-a-time)
6. [Outbound handlers can run code just before the save](#outbound-handlers-can-run-code-just-before-the-save)
7. [Mock an aggregate query](#mock-an-aggregate-query)
    - [The keys are the aliases your code reads](#the-keys-are-the-aliases-your-code-reads)
    - [Record mocks never answer an aggregate query](#record-mocks-never-answer-an-aggregate-query)
    - [Reading a mocked aggregate query](#reading-a-mocked-aggregate-query)
8. [The Data Masking Advisor's health count](#the-data-masking-advisors-health-count)
9. [Lightning component fixes](#lightning-component-fixes)
10. [The lookups can open with a record already chosen](#the-lookups-can-open-with-a-record-already-chosen)
11. [Code scanning](#code-scanning)
12. [The pipeline command line](#the-pipeline-command-line)
13. [The jobs Health Check schedules say what they do](#the-jobs-health-check-schedules-say-what-they-do)
14. [Guides, help text and descriptions corrected](#guides-help-text-and-descriptions-corrected)
15. [Changes that can affect code you have written](#changes-that-can-affect-code-you-have-written)
    - [Security fixes](#security-fixes)
    - [A list of numbers, dates or booleans is passed as a bind variable](#a-list-of-numbers-dates-or-booleans-is-passed-as-a-bind-variable)
    - [A record with a blank key no longer matches blank rows](#a-record-with-a-blank-key-no-longer-matches-blank-rows)
    - [A record type is found whatever the case of its developer name](#a-record-type-is-found-whatever-the-case-of-its-developer-name)
    - [A chain launched inside a Queueable job starts, or fails and saves nothing](#a-chain-launched-inside-a-queueable-job-starts-or-fails-and-saves-nothing)
    - [A trigger action's entry formula runs preLoad](#a-trigger-actions-entry-formula-runs-preload)
16. [Upgrading & compatibility](#upgrading--compatibility)
</details>

---

## At a glance

Ordered by impact. Find your row, read across, and follow the link for more.

| # | What's new | Who it's for | In one line |
|---|-----------|--------------|-------------|
| 1 | **[Saves that now work](#saves-that-used-to-fail-or-go-wrong-now-work)** | Admins · Support · Developers | Create forms save checkboxes the user never touched, edit forms update, and copies save as new records. The scheduled job editor window keeps a job on the job runner. The chain monitor aborts only the run it named |
| 2 | **[Mock one service at a time](#mock-one-service-at-a-time)** | Admins · Developers · Testers | Tick Mocking Enabled on a service's API Setting, and the service answers mock data, outgoing or incoming, for the users the new Mock Selected APIs feature flag is on for |
| 3 | **[A new hook for outbound handlers](#outbound-handlers-can-run-code-just-before-the-save)** | Developers | Override `onCommitWorkStarting()` in an outbound handler to run code just before the call's changes are saved |
| 4 | **[A new code-scan rule](#a-new-rule-kernjsonreadclassneedsjsonaccess)** | Developers · Tech leads | `KernJsonReadClassNeedsJsonAccess` flags a class the framework reads from JSON that has no `@JsonAccess`. Three other rules now catch forms they missed |
| 5 | **[The Data Masking Advisor's health count](#the-data-masking-advisors-health-count)** | Admins · Security | An object-wide target switched off together with its rule is no longer counted. A target left on while its rule is off now is |
| 6 | **[Lightning component fixes](#lightning-component-fixes)** | Admins · Developers | Lookups, tables, the cron and scheduled job editors, the log console, the streaming monitor and the Advisor behave as described |
| 7 | **[Lookups with a record already chosen](#the-lookups-can-open-with-a-record-already-chosen)** | Developers | `searchLookup` and `sObjectLookup` accept `default-record-id` |
| 8 | **[The pipeline command line](#the-pipeline-command-line)** | Developers · Release managers | `kerndx-pipeline init --check` writes nothing. Code Analyzer runs get their arguments right on Windows |
| 9 | **[Corrected guides and help text](#guides-help-text-and-descriptions-corrected)** | Everyone | The guides, field help and masking rule descriptions now match what the code does |
| 10 | **[Mock an aggregate query](#mock-an-aggregate-query)** | Developers · Testers | Register the rows a count, total or grouped query returns, and test the code that reads them without inserting records |

---

## Behaviour changes at a glance

Every change that can affect code, configuration or a check you own, and what to do about it. Each row links to the full explanation.

| Area | What changed | What to do | Read more |
|---|---|---|---|
| Create form | A checkbox now appears on the form. A checkbox you configure through the form's `fields` property, and the user never touches, is saved as the form shows it (`false` when unticked). An edit form sends the record Id, and a create form never sends one, not even in its `valuechanged` event | Nothing, unless your code reads an Id from a create form's `valuechanged` event | [A create form saves a checkbox the user never touched](#a-create-form-saves-a-checkbox-the-user-never-touched) |
| Scheduled jobs | Saving in the editor window that Health Check opens keeps the job's **Execution Mode**, **Run Priority** and **Overlap Policy** | Optional: if you saved a job in that window in 1.8 or 1.9, open it and check those three fields | [The scheduled job editor keeps a job on the job runner](#the-scheduled-job-editor-keeps-a-job-on-the-job-runner) |
| Chain monitor | If the selected run changed while the confirmation was open, Abort stops nothing and shows a warning | Select the run again and abort it | [The chain monitor aborts only the run its confirmation named](#the-chain-monitor-aborts-only-the-run-its-confirmation-named) |
| Masking | The Advisor's **Configuration health** no longer counts an object-wide target switched off together with its rule. It now counts a target left on while its rule is off | Switch such a target off, or switch its rule on | [The Data Masking Advisor's health count](#the-data-masking-advisors-health-count) |
| Queries | So that text from a page or a user can no longer change the query, a method that takes a field name as text for a condition, a sort or a grouping throws `IllegalArgumentException` for text that is not a field name. It accepts a field API name, a path through a lookup such as `Account.Owner.Name`, a date or distance expression of the kind `kern.QRY_Function` writes, and, where SOQL allows it, an aggregate such as `SUM(Amount)` or `toLabel()` around a field name. A sort item may end with `ASC` or `DESC` and `NULLS FIRST` or `NULLS LAST`, and `orderBy` and `groupBy` take a list of those joined by commas. One more thing is refused: a subquery passed to `isIn()` or `notIn()` that selects anything but a field name or a relationship path | Pass fields as tokens, such as `Account.Name`, or as a `kern.QRY_Function`. Write `orderBy('Name', true)`, not `orderBy('Name DESC', true)`. In a subquery for `isIn()` or `notIn()`, select one field, by its API name or a relationship path. Map a field that a page or a user picks through a list of the fields you allow | [Security fixes](#security-fixes) |
| Queries | So that your code can read records the user does not own while the user never sees a field they are not allowed to read, a read with `bypassSharing()` and no `withSystemMode()` now finds records whatever their sharing, and `count()` and `exists()` count them. Fields the user cannot read are removed from the rows, from parent fields, from child rows and from rows taken from the query cache. The read is refused before it runs when the user cannot read the object, or when a filter or a sort you build with the builder, in the main query or a child query, uses a field the user cannot read. A query inside `isIn()` or `notIn()` is refused the same way when it selects or filters on such a field. A field inside a function, a field through a parent, and a filter in your own `kern.QRY_Condition.Evaluable` are not checked | Do not filter or sort on a field the user may not read through a function, a parent path or your own `Evaluable`. If the code must read a field the user cannot read, add `withSystemMode()`, which also turns off the object and field permission checks | [Reads and saves with bypassSharing ignore record sharing and keep field permissions](#reads-and-saves-with-bypasssharing-ignore-record-sharing-and-keep-field-permissions) |
| Queries | So that rows Kern cannot clean of hidden fields are never handed out, `toQueryLocator()`, `toCursor()`, `toAggregateList()`, `getFirstAggregate()` and any read of a grouped query, `count()` included, throw `kern.UTIL_Exceptions.IllegalStateException` before any query runs when you call `bypassSharing()` without `withSystemMode()`. In 1.9 these reads ran under the user's own sharing. The likely place is a batch class whose start method returns such a locator: it fails as soon as it starts | Add `withSystemMode()` to that read, or remove `bypassSharing()` to keep the user's sharing | [Locators, cursors and totals with bypassSharing alone now throw](#locators-cursors-and-totals-with-bypasssharing-alone-now-throw) |
| Queries | So that a later page cannot bring back a field the user may not read, `getPage()` after `bypassSharing()` alone returns rows without hidden fields and a null `page.cursor`. The records, `totalRecords` and the paging flags stay right | If your code or a component passes `page.cursor` back, check it for null and ask for each later page with `getPage()` | [Reads and saves with bypassSharing ignore record sharing and keep field permissions](#reads-and-saves-with-bypasssharing-ignore-record-sharing-and-keep-field-permissions) |
| Queries | So that `stripInaccessible()` works the same on every read, `getRandomItems` now removes the fields the user cannot read when you have called `stripInaccessible()` on the query | Nothing | [Reads and saves with bypassSharing ignore record sharing and keep field permissions](#reads-and-saves-with-bypasssharing-ignore-record-sharing-and-keep-field-permissions) |
| Saves | So that your code can save records the user does not own without writing a field the user may not edit, `bypassSharing()` on `kern.DML_Builder` and `commitWork(false)` on a `kern.DML_Transaction` or a service class in user mode now save records whatever their sharing. Fields the user cannot create or edit are left out of the save, without an error, and one warning names them. A save the user has no object permission for is refused, as in user mode | If the code must save a field the user cannot edit, add `withSystemMode()`, or call `setAccessLevel(AccessLevel.SYSTEM_MODE)` before `commitWork(false)`. Both also turn off the object and field permission checks | [Reads and saves with bypassSharing ignore record sharing and keep field permissions](#reads-and-saves-with-bypasssharing-ignore-record-sharing-and-keep-field-permissions) |
| Saves | So that `suppressExceptions()` keeps its promise to hand back a result instead of an error, a save in user mode refused because the user lacks the object permission now returns a failed result. Before, that one refusal was still thrown, as `System.TypeException` | If your code catches `TypeException` around `suppressExceptions().execute()`, read the result instead | [suppressExceptions returns a result when the user lacks the object permission](#suppressexceptions-returns-a-result-when-the-user-lacks-the-object-permission) |
| Masking | A long value that the masking text search cannot read whole under a `JsonKey` rule is saved as `[MASKING_FAILURE]`. A `Regex` rule now hides a secret in a long value that 1.9 could leave unmasked | Review the API call records, log records and any other records your masking rules cover, saved on 1.9.0-4 | [Security fixes](#security-fixes) |
| API handlers | An outbound handler can override `onCommitWorkStarting()` | In an override, call `super.onCommitWorkStarting()` first | [An outbound handler that overrides the new hook](#an-outbound-handler-that-overrides-the-new-hook) |
| Incoming services | A service whose API Setting has **Mocking Enabled** ticked runs its own code, until the **Mock Selected APIs** feature flag is on for the user the caller signs in as | If you rely on inbound mocking, turn the flag on for those callers straight after the upgrade | [An incoming service with Mocking Enabled ticked runs its own code again](#an-incoming-service-with-mocking-enabled-ticked-runs-its-own-code-again) |
| Outgoing services | **Mocking Enabled** now works for an outgoing service, for the users Mock Selected APIs is on for. The flag ships off, so nothing changes until you turn it on | Nothing | [Mock one service at a time](#mock-one-service-at-a-time) |
| Health Check | A new last row, **Selected API Mocking**, warns while an active API Setting has Mocking Enabled ticked, or while Mock All APIs or Mock All Inbound APIs is on for you | Untick the box on services you no longer mock. In a test org, read the warning and keep going | [What Health Check shows](#what-health-check-shows) |
| API calls | An outgoing call that mocks but finds no mock data fails with a longer message, which says how to fix it | Nothing, unless a report or your code matches the old message text | [When a service has no mock data](#when-a-service-has-no-mock-data) |
| API calls | A request built with `withExponentialBackoff` waits twice as long before each scheduled retry: the base wait, then double, up to 300 seconds. Retries in the same transaction are still sent again at once. A handler sent with `useHandler` and `withExponentialBackoff` gets the same waits for its scheduled retries, unless it overrides `createRetryStrategy`; such a handler is never sent again in the same transaction | Nothing, unless you worked around the old timing with a larger base wait: set the base back to the first wait you want. A handler sent with `useHandler` still needs an API Setting record, with its API Credential and Endpoint Path filled in, for its scheduled retries (as in 1.9) | [A scheduled retry with exponential backoff waits twice as long each time](#a-scheduled-retry-with-exponential-backoff-waits-twice-as-long-each-time) |
| API calls | A call's **Retries** count adds up across runs. A call that has used its whole retry budget ends Failed and shows as **Dead Lettered**. Before, a call that was sent again at once in a run could be retried for ever | Expect calls that were retrying in a loop to end Failed and Dead Lettered on their next run after the upgrade. To send one again, use **Retry** on its API Issue (needs **Log Issues** and **Retry Issues** ticked on the service), or send the request again from your code or flow. Either way the new call's count starts at zero | [A call stops retrying when its retry budget is used up](#a-call-stops-retrying-when-its-retry-budget-is-used-up) |
| Components | A component of yours that extends `ComponentBuilder` runs its teardown once, and closes its message channel subscriptions, when it is removed from the page | If it overrides `disconnectedCallback`, call `super.disconnectedCallback()` first | [A component that overrides disconnectedCallback](#a-component-that-overrides-disconnectedcallback) |
| Components | `paginatedTable` sends `pagechange` when it moves back to the last page. A selected row stays selected after a sort | Nothing, unless your code counts `pagechange` events | [The paginated table sends pagechange when it moves back a page](#the-paginated-table-sends-pagechange-when-it-moves-back-a-page) |
| Components | `insertCharacterAtInterval` returns the text unchanged for an interval that is not a whole number of 1 or more. It inserts a `$` separator as written | Check calls that pass 0 or a text interval | [insertCharacterAtInterval returns the text unchanged for an interval that is not a whole number](#insertcharacteratinterval-returns-the-text-unchanged-for-an-interval-that-is-not-a-whole-number) |
| Code scanning | One new rule, and three rules that catch more | Expect new findings when you take the 1.10 rulesets | [Your scans can report new findings](#your-scans-can-report-new-findings) |
| Validation rules | In a new installation, the help for a validation rule's error message says what was always true: Custom Labels in merge fields are not filled in. An upgraded org keeps the old help | To show a label, add a property to the context class that returns it | [Guides, help text and descriptions corrected](#guides-help-text-and-descriptions-corrected) |
| Queries | A list of numbers, dates, date-times or booleans given to `isIn`, `isInStrict`, `notInSet` or `notInSetStrict` is passed as a bind variable instead of being written into the query text. Very large and very small numbers now match | Nothing | [A list of numbers, dates or booleans is passed as a bind variable](#a-list-of-numbers-dates-or-booleans-is-passed-as-a-bind-variable) |
| Queries | `isIn(records, field)` and `isInStrict(records, field)` skip a record whose key field is blank, so they no longer match blank rows. `isInStrict` throws when every record's key is blank | To match blank rows as well, add `.orCondition(field).isNull()` | [A record with a blank key no longer matches blank rows](#a-record-with-a-blank-key-no-longer-matches-blank-rows) |
| Record types | `kern.UTIL_SObjectDescribe.getRecordTypeByDeveloperName()` and `isRecordTypeAvailable()` match the developer name without regard to case | Nothing, unless your code expects null or false for a name in a different case | [A record type is found whatever the case of its developer name](#a-record-type-is-found-whatever-the-case-of-its-developer-name) |
| Async chains | A chain launched inside a Queueable job starts, or fails and saves nothing. When the job was queued with a maximum stack depth, or runs in a chain of jobs that has one, the chain's first job runs under that maximum and your `AsyncOptions` apply from the second job on | Nothing, unless you pass your own `AsyncOptions` with a delay to a chain launched inside a Queueable job that has a maximum stack depth: use `withDelayMinutes` | [A chain launched inside a Queueable job starts, or fails and saves nothing](#a-chain-launched-inside-a-queueable-job-starts-or-fails-and-saves-nothing) |
| Tests | Kern reads a custom permission held through a permission set group from the permission set Salesforce keeps for the group, as Salesforce does. A test that builds a group with DML and then asks Kern whether a user holds a custom permission sees the permission only after the group is recalculated | In such a test, call `Test.calculatePermissionSetGroup` after building the group | [A test that builds a permission set group recalculates it first](#a-test-that-builds-a-permission-set-group-recalculates-it-first) |
| Trigger actions | A trigger action's entry formula now runs its context class's `preLoad()` once for each trigger action, on each batch of records, before the formula is checked. Before, it never ran, so the formula did not see the values `preLoad()` loads. A context class written for validation rules may run queries in `preLoad()`, so a save can now use more of the save's query limit (100 queries in a normal save). If `preLoad()` throws an error, the save now stops with that error | Check what your context class's `preLoad()` queries, and that it cannot throw an error on a trigger save | [A trigger action's entry formula runs preLoad](#a-trigger-actions-entry-formula-runs-preload) |
| Tests | An aggregate query on an object that has record mocks but no aggregate rows throws, whichever method reads it, `toList()` included. It used to return the record mocks, an empty list, or a type error | Register the rows with `kern.TST_Mock.registerAggregateRows`, an empty list for "finds nothing" | [Record mocks never answer an aggregate query](#record-mocks-never-answer-an-aggregate-query) |

---

## Saves that used to fail or go wrong now work

**Who it's for:** admins and support users who use these screens; developers who place the create form in their own pages.

### A create form saves a checkbox the user never touched

**What to do:** nothing.

In 1.9 a checkbox on a create form did not appear at all, and a required one could never be filled in. A checkbox configured through
the form's `fields` property was sent as empty text. Salesforce refuses empty text for a checkbox, so the save failed.

From 1.10:

- A checkbox appears on the form. A click ticks or unticks it.
- A checkbox the user never touches is sent as the form shows it: the value the form loaded for it, or `false` when it shows unticked.
  So the record saves what the user saw.
- Every other field you configure through `fields` and the user never touches is still sent blank, as in 1.9. The form does not show
  the default values Salesforce gives a new record, so it does not save a default the user never saw.
- A value set on the field in your configuration, or the existing record's value on an edit form, still comes first. The user's own
  change still wins over everything.

A field that comes from a field set (a named list of fields set up on the object), a checkbox included, still saves the default
Salesforce gives a new record, whatever the form showed. This is the same as in 1.9.

More create form fixes:

- **An edit form's update saves.** Until now an edit form sent no record Id, so Salesforce could not tell which record to update, and
  the update failed.
- **A create form never sends a record Id.** A create form given a record to copy, for example on a record page, sent that record's
  Id, and Salesforce refuses an Id on a new record. A field list that names `Id` put it back in too. Both now save a new record. The
  form's `valuechanged` event on a create form no longer carries an Id either.
- On an edit form, a lookup field now shows the record it holds, instead of an empty box. Loading that record no longer sends a
  `valuechanged` event, because the user changed nothing.
- A field that passes a check you wrote now stays valid. Until now the first save worked, and every later check then marked the field
  invalid without saying why.
- Clearing the form also unticks its checkboxes.
- A field set that cannot be read leaves the form empty, instead of stopping it with an error.

### The scheduled job editor keeps a job on the job runner

**What to check (optional).** The jobs kept running, so this is a tidy-up. If you saved a job in the editor window that Health Check
opens (Health Check is on the Kern Home page), in 1.8 or 1.9, open the job and check that:

1. **Execution Mode** says **Job runner**, if it should.
2. **Run Priority** still holds the value you chose. A save from the window emptied it.
3. **Overlap Policy** still holds the value you chose. A save from the window set it back to **Skip this run while the previous one is
   still running**.

**Why.** A scheduled job can run on its own platform scheduled job, or on the job runner. The job runner is Kern's shared runner: it
checks the job every few minutes and starts it when it is due. The **Execution Mode** field decides which one the job uses.

In 1.8 and 1.9, the window that Health Check opens over the page did not read the job's Execution Mode, and every save sent none. The
framework reads a missing Execution Mode as **Its own scheduled job**. So each save silently moved a job runner job off the runner. The
save also emptied Run Priority and set Overlap Policy back to its default. The window also checked the job's schedule as if the job ran
on its own.

From 1.10 the window reads the job's **Execution Mode**, **Run Priority** and **Overlap Policy**. It checks the schedule for the right
mode, and saves the three values back as they were.

### Editing only a job's description leaves its schedule alone

**What to check (optional).** This applies to jobs whose **Execution Mode** is **Its own scheduled job**; a job on the job runner
has no platform scheduled job of its own. If you changed only the **Description** of such a job in 1.9 or earlier, check who the job
now runs as: Setup's **Scheduled Jobs** page shows that user under **Submitted By**. To make it run as someone else again, have that
user untick **Is Active** on the job, save, then tick it again and save.

**Why.** In 1.9 and earlier, saving a change to only the Description of an active job that runs on its own platform scheduled job
stopped that platform job and scheduled it again. The job kept its timing, but from then on it ran as the user who saved the edit.

From 1.10, a change to only the Description saves the text and leaves the platform job as it is, in every execution mode.

### The chain monitor aborts only the run its confirmation named

**What to do:** if you see the warning below, select the run again and abort it.

Until now the chain monitor's **Abort** read the selected run after you confirmed. If another row was selected while the confirmation
was open, the run that was aborted was not the one the confirmation named.

From 1.10 the monitor notes the run before the confirmation opens, and a confirm aborts that run only. If the selection changed while
the confirmation was open, nothing is aborted. A warning says: "The selected run changed while the confirmation was open. Nothing was
aborted; select the run again and try again."

---

## Mock one service at a time

**Who it's for:** admins, developers and testers who want one service to answer test data (mock data) in a sandbox or a demo org, while
the other services work for real.

**What to do:** if an incoming service of yours has **Mocking Enabled** ticked so that it answers mock data, take the [upgrade
step](#upgrade-step-if-you-rely-on-inbound-mocking). To start mocking a service, see [The flag ships
off](#the-flag-ships-off-how-to-turn-it-on) below.

**Before 1.10.** The only switch for outgoing services was all or nothing: the **Mock All APIs** feature flag mocked every outgoing
service. **Mocking Enabled** on an API Setting did nothing for an outgoing service. On an incoming service, it mocked the service for
every caller, even in production.

**From 1.10, one rule decides both directions:**

- **Mocking Enabled** on the service's API Setting picks the service.
- The new **Mock Selected APIs** feature flag (`MockSelectedAPIs`) decides which users get mock answers from those services: only the
  users the flag is on for. A feature flag is a switch that can be on for the whole org or for some users only.

A service answers mock data only when its active API Setting has the box ticked *and* the flag is on for the user the call runs as. The
box alone, or the flag alone, mocks nothing. **Mock All APIs** and **Mock All Inbound APIs** work as before.

| Direction | With the box ticked and the flag on for the user |
|---|---|
| Outgoing | The service answers a matching API Mock record, or the handler's canned body (`defaultMockBody`), instead of calling the real system |
| Incoming | The request is answered from a matching API Mock record instead of running the handler's own code, or with a default body when no record matches |

**Which user the flag checks.** Each call checks the flag for the user it runs as:

- a scheduled flow or a retry: the user who runs it;
- an incoming request: the user the caller signs in as.

### The flag ships off: how to turn it on

Mock Selected APIs arrives active, with Is Enabled By Default unticked and no strategies, so it mocks nothing until you turn it on. An
incoming service with Mocking Enabled ticked does change: unless Mock All Inbound APIs is on, it stops answering mock data at the
upgrade. See [Upgrade step: if you rely on inbound mocking](#upgrade-step-if-you-rely-on-inbound-mocking).

- **For the whole org:** tick **Is Enabled By Default** on the record.
- **For some users only:** add a strategy record to it. A strategy record is a rule that decides which users the flag is on for, for
  example one that matches a permission set you assign to your testers.

The [Web Services guide](../docs/Web%20Services%20-%20Guide.md#declarative-mock-mode) shows both, and a short custom handler class for
a rule you decide in code.

**Do not create a feature flag of your own named `MockSelectedAPIs`.** A record of yours with that name would decide the flag in place
of the packaged one.

### What Health Check shows

**What to do:** untick Mocking Enabled on services you no longer mock. In a test org, read the warning and keep going.

Health Check has a new last row, **Selected API Mocking**. It:

- lists every active API Setting with Mocking Enabled ticked;
- says, for you (the person viewing the page), whether those services answer mock data or work for real;
- warns when Mock All APIs or Mock All Inbound APIs is on for you.

The row passes only when no active API Setting has the box ticked and both of those flags are off for you. The row has no action
button.

The API Test Harness toggle's text when mocking is off now reads "Real endpoint responses, unless the service's API Setting has Mocking
Enabled ticked and the Mock Selected APIs feature flag is on for you, or Mock All APIs is on for you".

### When a service has no mock data

**What to do:** nothing, unless a report or your code matches the old message text.

An outgoing service can mock but find nothing to answer with: no mock registered in Apex, no matching API Mock record and no canned
body. It then fails, as it always has under Mock All APIs. This is a configuration error, and the circuit breaker counts it as a
failure. (The circuit breaker stops calling a failing system for a cool-off after repeated failures, then tries again.)

The message now says how to fix it: "No mock response is set up for (the service class). Add an API Mock record for this service, or
clear Mocking Enabled on its API Setting. In Apex, register a mock with API_MockFactory.forService() or set defaultMockBody in
configure()."

An incoming service with no matching record answers a default body, as before.

**The help on Mocking Enabled.** The field's description and help now give the rule above. A new installation gets both. An upgraded
org shows the new description in Setup, but keeps the old help, which does not mention the flag.

---

## Outbound handlers can run code just before the save

**Who it's for:** developers who write outbound API handlers.

**What to do:** nothing, unless you want to use the hook. If you override it, follow the two rules below.

`onCommitWorkStarting()` runs just before the framework saves a call's changes to the database. A handler that extends
`kern.API_Inbound` could already override it. From 1.10 a handler that extends `kern.API_Outbound` can too, so inbound and outbound
handlers offer the same hooks.

```apex
global override void onCommitWorkStarting()
{
    super.onCommitWorkStarting();
    // work to do before the save
}
```

Two rules for an override:

- **Call `super.onCommitWorkStarting()` first.** It prepares the save and the logging for the call.
- **Make the work safe to run more than once.** The method runs once for each attempt at the save. If the platform refuses the save
  because another process has locked a row, the save is tried once more, and the method runs again for the new attempt.

---

## Mock an aggregate query

**Who it's for:** developers and testers who write unit tests for code that reads counts, totals or grouped results.

**What to do:** nothing, unless a test of yours registers record mocks for an object and runs an aggregate query on it. See [Record
mocks never answer an aggregate query](#record-mocks-never-answer-an-aggregate-query).

An aggregate query counts, adds up or groups records, for example the number of opportunities in each stage. Until now such a query
could not be mocked: a test had to insert real records for it. From 1.10 a test registers the rows the query returns:

```apex
kern.TST_Mock.registerAggregateRows(Opportunity.SObjectType, new List<Map<String, Object>>
{
    new Map<String, Object>{ 'total' => 3, 'StageName' => 'Prospecting' },
    new Map<String, Object>{ 'total' => 2, 'StageName' => 'Closed Won' }
});

List<kern.QRY_Builder.AggregateRow> rows = kern.QRY_Builder.selectFrom(Opportunity.SObjectType)
    .count(Opportunity.Id, 'total')
    .groupBy(Opportunity.StageName)
    .toAggregateList();
```

Each map is one row. The rows come back in the order you registered them. Only the query's limit applies to them: its conditions and its
order never filter or sort them.

- One map instead of a list registers a single row, for a query you read with `getFirstAggregate()`.
- `kern.TST_Mock.registerNextAggregateRows` answers only the next aggregate query on the object, then the registered rows answer again.
- A second `kern.TST_Mock.registerAggregateRows` call for the same object adds its rows after the first ones, as `register` adds records.
- `kern.QRY_Builder.setAggregateMock` registers rows from the query builder, beside `setMock`. Like `setMock`, it replaces the rows set
  earlier for the object.
- `kern.TST_Mock.clear()` and `kern.TST_Mock.clear(SObjectType)` remove the rows. On the query builder, `setAggregateMock(type, null)`
  and `clearMocks()` remove them.

The [Selectors guide](../docs/Selectors%20-%20Guide.md#mocking-an-aggregate-query) has the full rules.

### The keys are the aliases your code reads

A key in a row is the name your code reads the value back by: the alias you gave the aggregate, such as `'total'` in
`count(Opportunity.Id, 'total')`, or a grouped field's API name, such as `StageName`. Give each aggregate its own alias in a query a test
will mock. Without one, the builder names the value `<function>_<field API name>` (`count_Id`, `sum_Amount`), and in a namespaced
package that name carries the field's namespace prefix.

Keys are matched without regard to case, as on a real row. Reading an alias the row does not hold throws, and the message lists the
aliases it does hold, so a spelling mistake shows at once. A row with two keys that differ only in case, such as `'Total'` and
`'total'`, throws an `IllegalArgumentException` that names both when the row is read, because a real query cannot return such a row.

### Record mocks never answer an aggregate query

If an object has record mocks (from `kern.TST_Mock` or `kern.QRY_Builder.setMock`) and no aggregate rows, an aggregate query on it
throws a `kern.UTIL_Exceptions.IllegalStateException`. The message says to register the rows with `kern.TST_Mock.registerAggregateRows`.

Until now an empty record mock answered an aggregate query with an empty list, and a record mock with records failed with a type error
that was hard to read. `toList()` on an aggregate query returned the record mocks. The fix is one line: register the rows the query should return, or an empty list for a query that finds nothing.

```apex
kern.TST_Mock.registerAggregateRows(Opportunity.SObjectType, new List<Map<String, Object>>());
```

### Reading a mocked aggregate query

Read it with `toAggregateList()` or `getFirstAggregate()`. A read that returns records, such as `toList()` or `getFirst()`, throws on a
query that aggregate rows answer, and the message points to `toAggregateList()`.

The `count()` that ends a query and returns a number is not an aggregate read. Like `toList()` on a query that does not aggregate, it is
answered by record mocks or by the database, never by aggregate rows.

---

## The Data Masking Advisor's health count

**Who it's for:** admins who set up masking rules and targets.

**What to do:** if the Advisor counts a target whose rule is off, switch the rule on, or switch the target off.

A masking target connects a masking rule to an object or a field. A target masks something only while both the target and its rule are
switched on. The Data Masking Advisor's **Configuration health** counts the targets that mask nothing, so you can fix them. 1.10
changes two cases.

| The rule is | The target is | In 1.9 | From 1.10 |
|---|---|---|---|
| off | off | counted as "1 object-wide rule inactive" | an object-wide target is not counted. On the object-wide banner the target still shows unticked, and the older card rule also shows **Superseded**. A field-level target is still counted as a field target masking nothing, as in 1.9 |
| on | off | counted | counted, as before |
| off | on | not counted in Configuration health | counted, for example "1 target whose rule is off" |

**An object-wide target switched off together with its rule is no longer counted.** 1.9 ships the older card rule, **Mask Credit Card
Numbers** (`MaskCreditCard`), switched off together with its four targets, and asks upgraded orgs to do the same. On a 1.9 org with the
pair switched off, the Advisor showed "1 object-wide rule inactive" on each framework object that carries one of those targets. The 1.9
note told you to ignore that line. From 1.10 that line is gone, because nothing is set up to mask when the target is off too.

**A target left on while its rule is off is now counted.** Such a target masks nothing. Until now Configuration health said nothing
about it. From 1.10 the Advisor counts it, for object-wide and field-level targets alike.

The object-wide banner still lists the rule as active, because that banner reads only the target's own switch. The Configuration health
line is where the problem now shows. The detail line reads, for example, "1 object-wide target is on, but its rule is off, so it masks
nothing", or "The field-level target for rule ... on ... is on, but that rule is off, so it masks nothing."

**What you may see after the upgrade.** Your org may have upgraded from 1.8 or earlier and not yet switched on the JSON Web Token rule,
`MaskJwt` (the 1.9 upgrade step). If so, its two targets `ApiCall_All_Jwt` and `Issue_All_Jwt` are on while the rule is off, and the
Advisor now shows them. Health Check already warned about these two targets. Switch the rule on, or switch the two targets off.
Likewise, if you switched off a rule but not its targets, switch them off together.

---

## Lightning component fixes

**Who it's for:** admins who use Kern's consoles and record pages; developers who build with Kern's components.

**What to do:** nothing for most of these. Two of them can affect a component of yours: see [A component that overrides
disconnectedCallback](#a-component-that-overrides-disconnectedcallback) and [The paginated table sends pagechange when it moves back a
page](#the-paginated-table-sends-pagechange-when-it-moves-back-a-page).

Each of these components now does what its guide describes.

| Component | What you see now |
|---|---|
| `searchLookup`, `sObjectLookup` | A lookup given its record before it first appears shows the record, instead of failing to appear at all. Pressing Enter with no result highlighted no longer clears the field. A lookup whose display field is a number can be searched. A custom object's icon waits until the object's details have loaded, instead of first asking for a standard icon that does not exist |
| `paginatedTable` | When the rows shrink or the page size grows, the table moves back to the last page that exists (or the first, when there are no rows). Until now it could show, for example, "Page 5 of 2" over an empty table. A selected row stays selected when a sort moves it to another page |
| `customDataTable` | The built-in column types are ready before the first table on the page is created. The [LWC guide](../docs/LWC%20-%20Guide.md#customdatatable) now shows how to give a table its own column types: a small component that extends `customDataTable` with its own `customTypes` map. Column types passed in the `types` property reach only tables created after the one that passes them |
| `ComponentBuilder` | When your component is removed from the page, its teardown runs once, and its message channel subscriptions are closed. Until now, a component added again ran each teardown twice. `consoleLog` logs a value that refers to itself or holds a BigInt as it is, instead of throwing an error |
| Cron editor | The description keeps the day, weekday and month: `0 30 * ? * MON` no longer reads "Every hour at minute 30". A job runner schedule that runs every few minutes names its hours and days, such as "Every weekday (Monday through Friday) at 15-minute intervals from 9:00 AM to 5:45 PM" |
| Scheduled job editor | Switching between a job's own schedule and the job runner checks the expression again, so Save no longer accepts an expression the scheduler then refuses. Picking a class twice in a row shows the parameters of the class picked last. The next-run preview always answers for the expression you typed last |
| `scheduledJobDetail` | Changing the class twice in a row shows the parameters of the second class, and no error from the first |
| `logConsole` | The detail card of an entry you had already opened no longer stays on "Loading". After a failed read, a second click on the row tries again. A failed page read clears the counts instead of showing the old ones, and each view keeps its own summary |
| `chainMonitor` | The run list no longer shows runs your filter leaves out after a slow refresh. A failed clear of stalled runs shows its error once |
| `streamingMonitor`, `streamingActions` | When one channel fails to subscribe, the other channels keep working, and an error names the channels that failed. The view moves to the monitor only when at least one channel subscribed. Clicking **Publish** again after a publish moved the view now works |
| `dataMaskingAdvisor` and the masking rule screens | A failed list of objects no longer leaves the page on a spinner. A failed field read no longer leaves the previous object's fields beside the error. An answer for an object you have already left is ignored, and the spinner stays until the answer for your latest choice arrives. Two new targets no longer get the same name, so neither is dropped when you deploy them; an existing target is never renamed. **Apply** in the Review window with the level already shown changes nothing. The rule picker keeps the rule you chose when a slow search answers late, and a rule's test preview shows the answer for the value it tested |
| `flowFooter` | A **Next** button state the parent sets before the footer appears is kept |

Also fixed:

- **Cron editor.** Day lists such as `MON-WED,FRI`, ranges that wrap round such as `FRI-MON`, the `L` (last) shortcut, month steps
  and month names are read and checked correctly. A schedule limited to one year names the year, and a one-off job whose year has
  passed is still described. An expression the editor refuses, such as one with a step of 0, shows as written instead of being
  described.
- **`streamingMonitor`, `streamingActions`.** Replay ids are sent as numbers, as Salesforce expects. A failed channel load stops
  the spinner, and **Subscribe All** after it still subscribes to the change event channel. Each error shows once, and leaving the
  page unsubscribes without a message. The timeline leaves out an event with no time, instead of drawing it off the chart and
  stretching the time range back to 1970. The actions panel fills in the payload for the event you picked last.
- **`jsonViewer`.** Before it gets any text, the viewer shows nothing, instead of the word "undefined".
- **`apiTestHarnessForm`.** A list of services that arrives late, for the direction you have just left, is ignored.
- **The org limits view** in the streaming monitor shows its empty message when there is nothing to show.
- **Retry and Dismiss on an API issue.** An action that worked says so and closes, even when the page refresh after it fails.

---

## The lookups can open with a record already chosen

**Who it's for:** developers who place Kern's lookups in their own components.

`searchLookup` and `sObjectLookup` now accept a record id through the `default-record-id` attribute (the `defaultRecordId` property).
They show that record as the field's value. Use it, for example, to show the saved value when the lookup sits on an edit form.

The create form already passed this value, but the lookup did not accept it, so an edit form showed an empty lookup.

---

## Code scanning

**Who it's for:** developers and tech leads who run the KernDX scanner rules in their pipeline.

**What to do:** expect new findings when you take the 1.10 rulesets (the files that list the rules a scan runs). See [Your scans can
report new findings](#your-scans-can-report-new-findings).

### A new rule: KernJsonReadClassNeedsJsonAccess

The framework reads some of your classes by turning them into JSON from inside its own namespace. These are DTOs (data transfer
objects: small classes that carry fields and convert to and from JSON) and formula evaluation contexts, such as the context class of a
validation rule. Salesforce allows this only when your class says so with `@JsonAccess`. Without it, the conversion fails quietly. The
merge fields that read the class, for example in a validation message, can then come back blank with no error.

The rule flags a class, inner classes included, that:

- extends `kern.DTO_JsonBase` without `@JsonAccess(serializable='always' deserializable='always')`;
- implements `kern.UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext` without `@JsonAccess(serializable='always')`.

It also checks a class that reaches either type through a base class of yours in the same file, up to three levels down. It reads one
file at a time, so it cannot follow a base class in another file: annotate those subclasses yourself.

The rule is priority 3 (Should Fix). It is in `kerndx-pmd-ruleset.xml` only, not in the smaller ruleset for code that does not use
Kern. Details: [KernJsonReadClassNeedsJsonAccess](../docs/Code%20Scanning%20-%20Guide.md#kernjsonreadclassneedsjsonaccess) in the Code
Scanning guide.

### Three rules catch what they missed

- **`KernNoRawEmail`** now catches `new Messaging.SingleEmailMessage()` as well as `new SingleEmailMessage()`, in any letter case.
- **`KernNoRawHttp`** now catches `new System.HttpRequest()` and `new System.Http()`, and the type names in any letter case.
- **`KernNoCoverageTheatre`** now catches its fourth case, `Assert.isNotNull` on a record just returned by `TST_Builder.build()`. Until
  now that case never fired. The same fix is in the hygiene and framework rulesets.

The messages of `KernCoverageExemptRequiresReason`, `KernNoBooleanExceptionThrown` and `KernSecurityBypassCallSite` show their quote
marks again. So the code they suggest, such as `@SuppressWarnings('PMD.KernSecurityBypassCallSite')`, can be copied as written.

---

## The pipeline command line

**Who it's for:** developers and release managers who use `kerndx-pipeline`.

- **`kerndx-pipeline init --check` writes nothing.** It promised a dry run, but wrote the configuration, the workflow files and the
  hook anyway. It now prints each path it would write, and writes none of them.
- **Code Analyzer runs get their arguments right on Windows.** On Windows, tools such as `sf`, `npm` and `npx` are `.cmd` files, and
  Command Prompt reads each argument twice. Some arguments were passed on wrongly: those with a quote before an `&`, a backslash at the
  end of a quoted value, an empty value or a `%NAME%`. They now arrive as written.

---

## The jobs Health Check schedules say what they do

**Who it's for:** administrators who open Scheduled Jobs.

Health Check can schedule three kinds of job for you: the jobs that delete old records, the chain watchdog, and the job runner's
regular checks. Until now these jobs had an empty **Description**, so you had to look in the guides to learn what each one was for.

From 1.10, each job Health Check schedules gets a description in plain words. A job that deletes old records says which records
and how old they must be, the chain watchdog says how long a chain may go without progress before it is marked Stalled, and each
job runner check says which minute of the hour it runs.

Jobs that Health Check scheduled before you upgraded keep their empty description.

---

## Guides, help text and descriptions corrected

**Who it's for:** everyone who reads the guides or the help in Setup.

The developer guides, the API reference and the help in Setup were checked against the code. The statements that disagreed with it were
corrected, including samples that did not compile. Some corrections you may act on:

- **A validation rule's error message does not fill in Custom Labels.** The old help said `{$Label.CustomLabel}` works in a merge
  field; it never did. In a new installation the help now says what was always true: Custom Labels in merge fields are not filled in.
  An upgraded org keeps the old help. Merge fields such as `{!PropertyName}` or `{!newRecord.Name}` are filled from your context class.
  To show a label, add a property to the context class that returns `System.Label.YourLabel`.
- **A context class you write needs `@JsonAccess(serializable='always')`.** Without it, every merge field from that class comes back
  blank. Until now nothing said why; from 1.10 the framework logs one warning that names the class. Add the annotation to each
  context class you use for a validation rule's error message (the [new scan rule](#a-new-rule-kernjsonreadclassneedsjsonaccess)
  finds the ones that lack it). The Validation guide says so, and so does the field help in a new installation.
- **A class the framework creates from its name**, such as a trigger action, a DTO or a scheduled job (a `SCHED_*` class), must be
  `global`, or `public` with a Type Resolver. The guides said a scheduled job must always be `global`; that was not true. A Type
  Resolver is how you tell the framework where to find the Apex classes in your namespace. A DTO has a third choice: override
  `getObjectType()`. Selectors, services, Flow invocables and utilities can stay `public`.
- **The circuit breaker opens when the failure count reaches its threshold**, not when it goes past it.
- **Field help.** The help on **Status** of an API call now names **Processing** and **Batched**. The help on a log entry's **Message**
  gives its size as 131,072 characters. The description of a feature flag's **Result On No Match** says plainly when the fallback
  applies. The help on an API call's **Retries** says that it counts every retry, added up across runs. On API Setting, **Is Active**,
  **Endpoint Path**, **Priority**, **Class Name**, **Max Retry Count**, **Idempotency Enabled** and **API Credential** now say what
  each does for outgoing and for incoming services: for example, **Priority** is read only for incoming services, and only to
  choose between matching paths of the same length. The **Caller Class** field on a masking target says that a class name limits
  the target to one service's API calls and API issues. A changed help text reaches a new installation; an org that upgraded
  keeps the old help until you edit the field in Setup.
- **The API reference** now says what each global class and method does beyond its name, and its examples show their results without
  debug output.
- **Masking rule descriptions.** The descriptions of the masking rules `MaskAddress`, `MaskFreeText` and `MaskPhoneInternational` now
  say "Inactive by default: tick Active on this rule and add an active masking target for the field", because a target alone does not
  switch a rule on. `MaskMedicareBeneficiaryId` now asks you to review with your HIPAA compliance team before activating it or changing
  Block DML. A masking rule's description is a value your org controls, so an upgraded org keeps its old descriptions; a new
  installation gets the new ones.
- **Also in the guides.** The guides now also describe how a masking target's **Caller Class** scopes it, and where each code scan
  runs. They also say that records an API handler saves in `onSuccess()` are saved in system mode (without the running user's
  permission checks).

---

## Changes that can affect code you have written

**Who it's for:** developers planning the upgrade.

### Security fixes

**Text passed where the query builder expects a field name can no longer change the query.** A field name is part of the query
text, so from 1.10 the query builder checks the field names you give it as text for a condition, a sort or a grouping. The methods
`condition`, `andCondition`, `orCondition`, `orderBy` and `groupBy`, and `kern.QRY_Condition.FieldCondition`, accept only:

- a field API name, such as `Name`;
- a path through a lookup to a related record's field, such as `Account.Owner.Name`;
- a date or distance expression of the kind `kern.QRY_Function` writes, such as `CALENDAR_YEAR(CloseDate)`;
- where SOQL allows it, an aggregate such as `SUM(Amount)`, or `toLabel()`, around a field name;
- in a sort, any of these followed by `ASC` or `DESC`, and by `NULLS FIRST` or `NULLS LAST`;
- for `orderBy` and `groupBy`, a list of those, joined by commas.

Methods that take one name, such as `count`, `relatedField`, `subselect` and the data category filters, accept one name, or names
joined by dots. Any other text throws an `IllegalArgumentException` when you call the method, before a query runs. The message
names the method and does not repeat the text. A query that uses only these forms keeps its exact text.

One more check comes with it. A subquery passed to `isIn()` or `notIn()` may select only a field name or a relationship path
(SOQL also needs it to select exactly one field).

The check stops text from changing the shape of a query. It does not check whether the running user may see the field. So never let
a page or a user choose a field by its name, in these methods or in the fields you select with `fields()` and `addField()`. Pass
fields as field tokens, such as `Account.Name` (an `SObjectField`, which Apex checks when it compiles your code), or as constants
you wrote, and map a page's choice to a field through a list of the fields you allow. The [Selectors
guide](../docs/Selectors%20-%20Guide.md#field-names-from-a-page-or-a-user) shows how.

**What to do:** upgrade every org to 1.10, then run your tests. Change any text that now throws, as
[Behaviour changes at a glance](#behaviour-changes-at-a-glance) shows: for example, write `orderBy('Name', true)`, not
`orderBy('Name DESC', true)`, because that method adds the direction itself.

**Fixed with it: a distance from a very small or very large coordinate.** `kern.QRY_Function.distanceInMiles` and
`distanceInKilometers` now write each coordinate as plain digits, such as `0.0000001`, so a very small or very large coordinate no
longer makes the query fail.

**The masking of long values no longer misses a secret.** Kern searches some long values as text. In 1.9 the search could
miss a secret, and the record was then saved with that secret unmasked. From 1.10:

- Under a `JsonKey` rule, a value that the search cannot read whole is no longer saved as it is. The whole field is saved as
  `[MASKING_FAILURE]` instead, so no secret is stored. A value that holds no secret can get the marker too.
- Under a `Regex` rule, a secret in a long value that 1.9 could leave unmasked is now hidden.

**What to do:** upgrade to 1.10. Records saved on 1.9.0-4 keep what they held, so API call records, log records and any other
records your masking rules cover, saved before the upgrade, should be reviewed.

#### Reads and saves with bypassSharing ignore record sharing and keep field permissions

Record sharing decides which records a user may see or change, for example only the records they own. Object and field
permissions decide what the user may do with a kind of record, and with each of its fields. `bypassSharing()` on the query
builder and on `kern.DML_Builder`, and `kern.DML_Transaction.commitWork(false)`, now ignore record sharing under the default
settings, as their descriptions always said. The user's object and field permissions still apply.

**Why:** your code can read and save the records it needs, whoever owns them, and the user still never reads or writes a field
they are not allowed to.

Under the default settings, queries and saves run in user mode: with the running user's own permissions and record sharing.
Before 1.10, in user mode, these calls changed nothing, so the read or the save kept the user's record sharing. This now
changes in user mode, whether it comes from the default settings or from `withUserMode()`. Nothing changes for code that also
calls `withSystemMode()`, or sets system mode with `setAccessLevel(AccessLevel.SYSTEM_MODE)` before `commitWork(false)`: it
reads and saves without sharing and without object or field checks, as before. Nothing changes either in an org that has
turned off `UserModeQueries_Enabled` (for reads) or `UserModeDml_Enabled` (for saves), the feature flags that make
user mode the default.

**A read with `bypassSharing()`:**

- finds records whatever their sharing. `count()` and `exists()` count them too.
- removes the fields the user cannot read from the rows it returns: from each record, from parent fields such as
  `Account.Owner.Email`, from child rows, and from rows taken from the query cache.
- is refused before any query runs when the user cannot read the object, with a `QueryException`. The object of a child query,
  or of a query inside `isIn()` or `notIn()`, must be readable too.
- is refused before any query runs, with `kern.UTIL_Exceptions.IllegalStateException`, when a filter or a sort you build with
  the builder (`condition(...)`, `orderBy(...)`) uses a field of the object that the user cannot read. The same holds in a
  child query, and for the field that a query inside `isIn()` or `notIn()` selects or filters on. The rows such a filter lets
  through would show something about the field's values.
- through `getPage()`, returns the page without hidden fields and with `page.cursor` set to null, because rows fetched later
  through that cursor would keep them. The records, `totalRecords` and the paging flags stay right. Ask for each later page
  with `getPage()`.

**Not checked:** a field inside a function, such as `CALENDAR_YEAR(CloseDate)`, a field reached through a parent, such as
`Account.Owner.Email`, and a filter you write in your own `kern.QRY_Condition.Evaluable`. Such a filter or sort still runs on
the field, so the rows it returns can show something about a field the user cannot read. With `bypassSharing()`, do not filter
or sort on a field the user may not read in these ways.

**A save with `bypassSharing()`, or with `commitWork(false)`** on a `kern.DML_Transaction` or a service class in user mode:

- saves records whatever their sharing. A save you send to run later with `async()` keeps the same checks when it runs.
- leaves out the fields the user cannot create (on an insert) or edit (on an update), without an error. It logs one warning for
  each save call it sends, naming the object and the fields, never their values. The warning names only fields that some user
  could be allowed to write. Formula fields, auto-number fields and the system fields that Salesforce fills in itself
  (`CreatedDate`, `CreatedById`, `LastModifiedDate`, `LastModifiedById`, `SystemModstamp`, `IsDeleted`, `LastActivityDate`,
  `LastViewedDate`, `LastReferencedDate`) are left out without a warning, because no user can write them. With
  `suppressLogging()` no warning is written.
- is refused when the user lacks the object permission the save needs (create, edit, delete or undelete), when an upsert
  matches on a key field the user cannot read, or cannot edit, or when the user cannot write a lookup field that you registered with
  its parent record. The refusal is the one user mode gives: the same error in an all-or-nothing save, and a per-row error
  under `allowPartial()`.

A save the checks refuse is sent to Salesforce with the caller's own access level, so Salesforce takes a permission set given
through `AccessLevel.USER_MODE.withPermissionSetId(...)` into account when it accepts or refuses that save. A save the checks
accept uses only the user's own permissions, so a field that only the permission set lets the user edit is left out of it.

**What to do:** look at the code that calls `bypassSharing()`, or `commitWork(false)`, without system mode. If it must read or
save a field the user cannot read or edit, add `withSystemMode()` to the query or the save, or call
`setAccessLevel(AccessLevel.SYSTEM_MODE)` before `commitWork(false)`. That also turns off the object and field permission
checks. Otherwise, give the user the field permission.

**Fixed with it:** `getRandomItems` now removes the fields the user cannot read when you call `stripInaccessible()`, as the
other reads do.

#### Locators, cursors and totals with bypassSharing alone now throw

**What to do:** add `withSystemMode()` to such a read. It then reads without record sharing, and it also turns off the object
and field permission checks for that read. Or remove `bypassSharing()` to keep the user's record sharing.

`toQueryLocator()`, `toCursor()`, `toAggregateList()`, `getFirstAggregate()` and any read of a grouped query, `toList()` and
`count()` included, now throw `kern.UTIL_Exceptions.IllegalStateException` before any query runs when you call
`bypassSharing()` without `withSystemMode()` in user mode. A grouped query is one with `groupBy`, or with an aggregate such as
`SUM(Amount)`. In 1.9 the bypass did nothing in user mode, so these reads ran under the user's own sharing.

**Why:** Kern cannot remove hidden fields from these reads. A locator and a cursor hand their rows over later, and totals and
group values are not records. Kern refuses them so that a user never sees a field they are not allowed to read.

The place you are most likely to meet this: a batch class whose start method returns such a locator. It fails as soon as the
batch starts after the upgrade. Add `withSystemMode()`:

```apex
Database.QueryLocator locator = kern.QRY_Builder.selectFrom(Case.SObjectType)
		.withSystemMode()
		.bypassSharing()
		.toQueryLocator();
```

#### suppressExceptions returns a result when the user lacks the object permission

**What to do:** if your code catches `TypeException` around `suppressExceptions().execute()`, read the result instead.

`DML_Builder.suppressExceptions()` now also returns a failed result when a save in user mode is refused because the user lacks
the object permission (create, edit, delete or undelete). Before, that one refusal was still thrown, as `System.TypeException`.
`allowPartial()` is unchanged: the refusal is a per-row error (status `CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY` for an insert or an
update, `DELETE_FAILED` for a delete).

**Why:** `suppressExceptions()` promises a result instead of an error when a save fails. Now it keeps that promise for this
refusal too, with or without `bypassSharing()`.

### An incoming service with Mocking Enabled ticked runs its own code again

**What to do:** if you rely on inbound mocking, take the [upgrade step](#upgrade-step-if-you-rely-on-inbound-mocking) straight after
the upgrade. Update unit tests that expect a mock answer, as shown below.

In 1.9 an incoming service whose API Setting had **Mocking Enabled** ticked answered mock data for every caller. From 1.10 it runs its
own code, unless the **Mock Selected APIs** feature flag is on for the user the caller signs in as (or Mock All Inbound APIs is on).

A unit test of yours that ticks the box on an inbound API Setting and expects a mock answer now also turns the flag on:

```apex
kern.TST_Factory.newFeatureFlag('MockSelectedAPIs');
```

### An outbound handler that overrides the new hook

**What to do:** if an outbound handler of yours overrides `onCommitWorkStarting()`, call `super.onCommitWorkStarting()` first. Make the
work safe to run twice, because a save that hits a row lock is tried once more. See [Outbound handlers can run code just before the
save](#outbound-handlers-can-run-code-just-before-the-save).

### A scheduled retry with exponential backoff waits twice as long each time

**What to do:** nothing, unless you worked around the old timing with a larger base wait: set the base back to the first wait you
want. If you send a handler of your own with `useHandler` and `withRetry` or `withExponentialBackoff`, make sure the handler has an
active API Setting record whose API Credential and Endpoint Path are filled in. This was already so in 1.9. This fixes issue
[#65](https://github.com/JVB-Consulting/kerndx/issues/65).

In 1.9 and earlier, a request built with `withExponentialBackoff(maxRetries, baseBackoffSeconds)` was retried on the same timing as
one built with `withRetry`. From 1.10 a scheduled retry waits the base first, then twice as long each time, up to 300 seconds: for a
base of 2 seconds, 2, 4, 8 and 16 seconds. Every retry already made counts towards the doubling, the ones sent again at once in the
same transaction included, so a retry scheduled after three of those waits 16 seconds. Retries in the same transaction are still sent
again at once, because Apex cannot pause. `withRetry` keeps its timing: the base, then the base times the number of retries made.

The scheduled waits are the same for a handler of your own sent with
`kern.UTIL_HttpClient.useHandler(...).withExponentialBackoff(...)`, unless the handler overrides `createRetryStrategy()`: then its
own strategy decides, as before. Such a handler is never sent again in the same transaction; every one of its retries is scheduled.
The base wait and the maximum number of retries you pass now apply on every run of the call, the scheduled retries included. A
scheduled retry runs from the handler class alone, so it needs an API Setting record for the handler, and takes its credential and
path from that record, not from the request: without the record, the first run sends the request, but the retry it schedules ends
Aborted instead of being sent. This has not changed.

Such a handler may now see three extra inputs, `__maxRetries`, `__backoffSeconds` and (after `withExponentialBackoff`)
`__exponentialBackoff`, in its inputs and in the call's Request Parameters. The framework never sends them to the external system;
only code of yours that copies every input into a request would.

### A call stops retrying when its retry budget is used up

**What to do:** after the upgrade, expect calls that were retrying in a loop to end Failed and show as **Dead Lettered** on their next
run. Their saved count is already at or past their maximum (1.9 saved the last run's re-sends plus the retry it scheduled), so their
budget is used up: this is the limit being applied, not a new failure. To send such a call again, use **Retry** on its API Issue.
The issue is recorded when the service's API Setting has **Log Issues** ticked, and Retry runs only when it also has **Retry Issues**
ticked and you hold the Retry API Issue permission. It sends a new call, whose count starts at zero. If the service records no API
Issue, send the request again the way your code or flow first sent it: that also makes a new call with a fresh count. To get a Retry
button for later failures, tick **Log Issues** and **Retry Issues**.

A call's **Retries** field now counts every retry: the ones sent again at once in the same transaction and the ones scheduled for
later, added up across runs, against its **Max Retries**, the budget. A call that runs again sends only what is left of its budget.
When nothing is left it is sent once more and, if that fails, ends Failed with no next retry time, and **Dead Lettered** is then true.

In 1.9 and earlier, a run that sent the call again at once overwrote the count with that run's re-sends, so a call answered 408 or
503, or 500, 502 or 504 when safe to repeat, could be retried for ever. The count of a first run is unchanged, and so is the count of a
call that is never sent again at once (a 425 or 429). A retry from an API Issue sends a new call with a fresh count.

### A test that builds a permission set group recalculates it first

**What to do:** in a unit test that builds a permission set group with DML and then asks Kern whether a user holds a custom
permission (for example through a feature flag with a custom permission strategy), call `Test.calculatePermissionSetGroup` after
building the group.

Kern answers whether a user holds a custom permission, for example when a feature flag has a custom permission strategy. For a
permission set group, it now reads the permission set Salesforce keeps for the group, which is how Salesforce itself answers the
question. Salesforce fills that permission set when it calculates the group, and a test does not do that on its own:

```apex
PermissionSet permissionSet = new kern.SEL_PermissionSet().findByName('My_Permission_Set');
PermissionSetGroup permissionSetGroup = (PermissionSetGroup)kern.TST_Builder.of(PermissionSetGroup.SObjectType).build();
kern.TST_Builder.of(PermissionSetGroupComponent.SObjectType)
		.withOverride(PermissionSetGroupComponent.PermissionSetGroupId, permissionSetGroup.Id)
		.withOverride(PermissionSetGroupComponent.PermissionSetId, permissionSet.Id)
		.build();
Test.calculatePermissionSetGroup(permissionSetGroup.Id);
kern.TST_Factory.createPermissionSetAssignments(new List<User> {testUser}, permissionSetGroup.Id);
```

A test that built a group and checked the permission without that call passed in 1.9 and can fail in 1.10. A test that assigns the
group by name through `kern.TST_Factory.createPermissionSetAssignments(users, 'GroupName')` needs no change: that call recalculates
the group for you.

### A component that overrides disconnectedCallback

**What to do:** if your component overrides `disconnectedCallback`, call `super.disconnectedCallback()` first, and keep your own
teardown after it.

When a component that extends `ComponentBuilder` is removed from the page, the base class does three things. It runs every operation
you registered with `addTearDownOperation`, empties that list, and closes the component's message channel subscriptions. That happens
only if the base class's `disconnectedCallback` runs. Five of Kern's own components did not call `super.disconnectedCallback()` first,
and now do.

### The paginated table sends pagechange when it moves back a page

**What to do:** nothing, unless your code counts `pagechange` events.

When the rows shrink and the current page no longer exists, `paginatedTable` moves back to the last page. It now sends one `pagechange`
event when it does, so a parent that tracks the page number stays right.

Selections are now kept by the row's key field rather than by page, so a sort no longer drops a selected row. The `rowselection`
event's contents are unchanged.

### insertCharacterAtInterval returns the text unchanged for an interval that is not a whole number

**What to do:** check calls that pass 0 or a text interval.

`insertCharacterAtInterval` in `kern/utilityString` gives the same result as before for every valid interval, and for any separator
without a `$`. What changes:

- An interval of 0, a range such as `'1,3'`, or any other value that is not a whole number of 1 or more returns the text as it was
  given. Until now 0 put the separator before every character, a range such as `'1,3'` changed how the text was split, and a text that
  is not a valid pattern threw an error.
- A separator that holds a `$` is inserted as written. Until now `$&`, `$$` or `$1` were read as replacement instructions.

### Your scans can report new findings

**What to do:** expect new findings when you take the 1.10 rulesets.

A scan can report findings it did not report before: `KernJsonReadClassNeedsJsonAccess` on classes
without `@JsonAccess`, and the wider matches of `KernNoRawEmail`, `KernNoRawHttp` and `KernNoCoverageTheatre`. See [Code
scanning](#code-scanning).

### A list of numbers, dates or booleans is passed as a bind variable

**What to do:** nothing, unless you compare a whole-number field such as `NumberOfEmployees`, or `COUNT()` after `havingCountOf`, with
a list that holds a fraction: give such a field whole numbers.

Until now `isIn`, `isInStrict`, `notInSet` and `notInSetStrict` passed a list as a bind variable (a value sent beside the query text)
only when it held Ids or text. Any other list was written into the query text. A number above 2,147,483,647, such as `123456789012`, or
a very small one, such as `0.000000001`, then made the query fail. This fixes issue
[#63](https://github.com/JVB-Consulting/kerndx/issues/63).

From 1.10 a list of numbers, dates, date-times or booleans is passed as a bind variable too, so those values match as written. The same
holds for a list given after `havingCountOf` or `havingSumOf`, and for the lists that `isIn(records, field)` and its siblings read from
records. A list that mixes kinds, such as a number beside a date, is still written into the query text, as before.

Whole numbers inside the Integer range are passed as a list of Integers, and any other number as a list of Decimals. The platform refuses
a list of Decimals on a whole-number field, so a list that holds a fraction, such as `10` and `20.5`, given for `NumberOfEmployees` now
fails where it used to run.

### A record with a blank key no longer matches blank rows

**What to do:** if you want blank rows to match as well, add `.orCondition(field).isNull()`.

`isIn(records, field)` and `isInStrict(records, field)` read the key field of each record you give them. Until now a record whose key
was blank put a blank value into the list, and `isIn` then matched every row whose field was blank too. From 1.10 such a record is
skipped, so blank rows no longer match.

When every record's key is blank, `isIn` gives a condition that matches nothing, and `isInStrict` throws its
`IllegalArgumentException`, "Records list contains no valid records".

`notInSet(records, field)` and `notInSetStrict(records, field)` treat a blank key as before: a record with a blank key still keeps the rows whose
field is blank out of the result.

### A record type is found whatever the case of its developer name

**What to do:** nothing, unless your code passes a developer name in a different case and expects null or false back.

`kern.UTIL_SObjectDescribe.getRecordTypeByDeveloperName()` and `isRecordTypeAvailable()` now find a record type whatever the case of
the developer name you pass, so `customer` finds the record type named `Customer`. Salesforce does not allow two record types on one
object whose developer names differ only in case, so the match is never ambiguous. Until now only the exact case was found, and any
other case returned null or false.

The framework builds its list of an object's record types once in a transaction and reuses it, so calling these methods for many
records, for example through `kern.TST_Builder.withRecordType`, adds very little work.

### A chain launched inside a Queueable job starts, or fails and saves nothing

**What to do:** nothing, unless you pass your own `AsyncOptions` with a delay to a chain launched inside a Queueable job that has a
maximum stack depth: that delay is not applied to the first job, so use `withDelayMinutes` instead. Until you install 1.10, use the
workaround in issue [#64](https://github.com/JVB-Consulting/kerndx/issues/64).

A Queueable job is a background job that Salesforce runs after the code that queued it. In 1.8.0-11 and 1.9.0-4, a chain started
inside a Queueable job failed in three cases:

- From a trigger fired by a save the job makes, with no `AsyncOptions`, the launch threw `System.AsyncException`. Salesforce does not
  let code in such a trigger read the job's stack depth (how many jobs deep the line of jobs is), whether the job is another managed
  package's or your own. The run record was already saved, so a caller that caught the error, for example a trigger action set to Log
  and Continue, was left with a chain run stuck in the Running state and no job behind it. The Chain Watchdog later marked it Stalled.
- From a trigger fired by a save that a chain step makes, with or without `AsyncOptions`, the launch threw the same
  `System.AsyncException` before anything was saved, so the chain never started. A trigger action set to Log and Continue logged the
  error and went on.
- In the own code of a Queueable job of yours (not a trigger) that was queued with a `maximumQueueableStackDepth`, a chain started with
  no `AsyncOptions` threw an error from Salesforce.

From 1.10 the chain starts and runs in all three cases. A job queued from a trigger like these starts a new line of jobs, so a chain
started there sets its own maximum stack depth, as a chain started outside any job does. A launch inside a Queueable job also behaves
differently in these ways:

- A line of jobs is the jobs started one from another. When the line already has a maximum stack depth (how many jobs deep it may
  go), the chain's first job is queued under that maximum, because a job inside the line cannot set a new one. If you passed your own
  `AsyncOptions`, its maximum, its duplicate signature and its delay are not applied to that first job. Later jobs use your options.
- When that maximum leaves no level for the first job, the launch is refused with `kern.UTIL_Exceptions.IllegalStateException` before
  anything is saved.
- When the Queueable job has already queued its one allowed job, the launch is refused with the same exception, before anything is saved. Until
  now Salesforce threw a `LimitException`, which your code cannot catch.
- If Salesforce refuses the chain's first job for any other reason, the run record is deleted and the original error reaches your code.
  Every launch now ends with a running chain and a queued job, or with an error and no run record.
- The launch log entry is written only after the first job is queued.

Launches from synchronous code, from a chain step's or handler's own code, and from a job on the job runner are unchanged.

### A trigger action's entry formula runs preLoad

**What to do:** check what your context class's `preLoad()` queries, and that it cannot throw an error on a trigger save. This fixes
issue [#66](https://github.com/JVB-Consulting/kerndx/issues/66).

A context class is the class that gives an entry formula its values. When it also implements
`kern.UTIL_ValidationRule.INT_BulkValidationContext`, validation rules call its `preLoad()` method once for each batch of records, so it
can load related data in one go. Until now a trigger action's entry formula never called `preLoad()`, so the values it loads were empty
there and the formula could give the wrong answer. From 1.10 each trigger action's entry formula calls `preLoad()` once for each batch, before any
record is checked, in the same way: the new records come first, and on a delete the deleted records come first. If `preLoad()` throws an
error, the save now stops with that error, whatever the trigger action's `FailureAction__c` says. This is not how validation rules
behave: there the error usually follows the `FailureAction__c` of the trigger action that runs the validation rules, and with the default,
`LogAndContinue`, it is logged and the save goes ahead. So a `preLoad()` that fails quietly in your validation rules today will stop the
save once a trigger action's entry formula uses the same class. Test a trigger save with each context class before you upgrade.

Any query in `preLoad()` counts towards the save's query limit (100 queries in a normal save). Each call's queries count, so two trigger
actions that share a context class query twice. A class written for validation rules may already query there, so a save that uses it in an
entry formula can now use more of that limit.

---

## Upgrading & compatibility

**The global Apex signatures are unchanged.** No global member is removed or changed in signature. These are added:
`kern.API_Outbound.onCommitWorkStarting()` and, for tests, `kern.QRY_Builder.setAggregateMock` and two forms each of
`kern.TST_Mock.registerAggregateRows` and `kern.TST_Mock.registerNextAggregateRows`, and, for the package's own tests only, the class
`kern.UTIL_FormulaContext.FoobarBulkContext` with seven properties. `onCommitWorkStarting()` lets an outbound handler override that
hook as an inbound handler already can.

Three global methods keep their signatures but change behaviour: `kern.API_Dispatcher.processInboundService`,
`kern.API_Dispatcher.execute` and `kern.UTIL_FormulaFilter.filter`. The two `API_Dispatcher` methods now mock a service only by the rule in
[Mock one service at a time](#mock-one-service-at-a-time). `filter` now calls the context class's `preLoad()` once per call, before it checks any
record; see [A trigger action's entry formula runs preLoad](#a-trigger-actions-entry-formula-runs-preload).

`kern.UTIL_HttpClient.RequestBuilder.withRetry`, `kern.UTIL_HttpClient.RequestBuilder.withExponentialBackoff` and the default
`kern.API_Outbound.createRetryStrategy()` keep their signatures but change behaviour, as described in
[Changes that can affect code you have written](#changes-that-can-affect-code-you-have-written).

The query builder's `isIn`, `isInStrict`, `notInSet` and `notInSetStrict` keep their signatures but change behaviour, as described in
[Changes that can affect code you have written](#changes-that-can-affect-code-you-have-written).

The query builder's methods that take a field, relationship or data category name as text for a condition, a sort, a grouping, a
count, a related field or a child query, and `kern.QRY_Condition.FieldCondition`, keep their signatures but refuse text that is
not such a name, as described in [Security fixes](#security-fixes). `kern.QRY_Function.distanceInMiles` and `distanceInKilometers`
keep their signatures and now write each coordinate as plain digits.

`bypassSharing()` on `kern.QRY_Builder.Builder` and on `kern.DML_Builder`, and `kern.DML_Transaction.commitWork(Boolean)`, keep
their signatures but now ignore record sharing in user mode and keep the user's object and field permissions. With them,
`withUserMode()` on both builders, `toQueryLocator()`, `toCursor()`, `toAggregateList()`, `getFirstAggregate()`, `toList()` (and
the reads built on it, such as `getFirst()`), `count()`, `exists()`, `getPage()` and `getRandomItems` keep their signatures but change behaviour, as described in
[Reads and saves with bypassSharing ignore record sharing and keep field permissions](#reads-and-saves-with-bypasssharing-ignore-record-sharing-and-keep-field-permissions)
and [Locators, cursors and totals with bypassSharing alone now throw](#locators-cursors-and-totals-with-bypasssharing-alone-now-throw).
`kern.DML_Builder.suppressExceptions()` keeps its signature and now returns a result for one more refusal, as described in
[suppressExceptions returns a result when the user lacks the object permission](#suppressexceptions-returns-a-result-when-the-user-lacks-the-object-permission).

`kern.UTIL_SObjectDescribe.getRecordTypeByDeveloperName` and `kern.UTIL_SObjectDescribe.isRecordTypeAvailable` keep their signatures but
now match the developer name without regard to case, as described in
[A record type is found whatever the case of its developer name](#a-record-type-is-found-whatever-the-case-of-its-developer-name).

`kern.UTIL_AsyncChain.ChainBuilder.execute()` and `execute(correlationId)` keep their signatures but change behaviour when a chain is
launched inside a Queueable job, as described in
[A chain launched inside a Queueable job starts, or fails and saves nothing](#a-chain-launched-inside-a-queueable-job-starts-or-fails-and-saves-nothing).

**The component surface is additive.** `searchLookup` and `sObjectLookup` gain the `defaultRecordId` property (`default-record-id`). No
component property or exposure is removed.

**The metadata surface is additive, with one changed label value.** Nothing is removed or renamed.

- One new packaged feature flag record, **Mock Selected APIs** (`MockSelectedAPIs`), arrives active and off by default.
- New Custom Labels carry the new messages: the chain monitor's abort warning, the Data Masking Advisor's lines for a target whose rule
  is off, and four cron descriptions.
- Eight new Custom Labels carry the Health Check row's texts and the no-mock-data message.
- Four new Custom Labels carry the descriptions of the jobs Health Check schedules.
- Two new Custom Labels carry the query builder's messages for text it refuses.
- Three new Custom Labels carry the query builder's messages for the reads it refuses with `bypassSharing()` alone:
  `QueryBuilder_BypassSharingRead_NeedsSystemMode`, `QueryBuilder_BypassSharingField_NotReadable` and
  `QueryBuilder_BypassSharingObject_NotReadable`.
- The test object `Foobar__c` gains one read-only field, `Formula__c`, which the Kern Administrator and Kern Read Only permission
  sets can read.
- Field descriptions and help text change on API Setting, API Call, Log Entry, Feature Flag, Masking Target and Validation Rule, and
  the API Mock object's description changes. See [Guides, help text and descriptions
  corrected](#guides-help-text-and-descriptions-corrected).
- One label value changes: the API Test Harness toggle's text when mocking is off (`ApiTestHarness_Mocking_ToggleInactive`).

**Nothing to remove.** These changes reach your org with the package. There is one Setup step, and only if you rely on inbound mocking.

### Upgrade step: if you rely on inbound mocking

This step is for you if an incoming service of yours has **Mocking Enabled** ticked so that it answers mock data.

1. Upgrade to 1.10. You cannot take this step before the upgrade: the Mock Selected APIs record arrives with 1.10, and a strategy
   record needs its flag to exist.
2. Straight after the upgrade, before traffic resumes, turn on the Mock Selected APIs feature flag for the users who call those
   services, or for the whole org. See [how to turn it on](#the-flag-ships-off-how-to-turn-it-on).

The services then keep answering mock data. Health Check's **Selected API Mocking** row lists the services with the box ticked.

### Every behaviour change

Each change to note on upgrade, with what to do, is in [Behaviour changes at a glance](#behaviour-changes-at-a-glance).
