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

## [1.11.0-1] — 2026-10-30

**Subscriber package version id:** `04tfj000000gMFRAA2`

KernDX is now open source under the Apache License 2.0. 1.11 also lets a test turn a feature flag off, lets the pipeline set
itself up from a file without asking questions, and fixes a few things that went wrong in saves, masking and the admin
screens. Most of 1.11 needs nothing from you; the box at the top of the
[1.11 release note](https://github.com/JVB-Consulting/kerndx/blob/main/release-notes/Release%20Notes%20-%20Kern%201.11.md#the-headlines)
lists the few things you may want to do.

### Added

- **`kern.TST_Factory.newDisabledFeatureFlag(String flagName)`** turns a feature flag off for the rest of a test, including a
  flag your org ships on.
- **`kerndx init --answers-file <path>`** sets up the pipeline from a JSON file without questions; every answer is checked
  before anything is written.
- **`kerndx/no-jest-mock-component-module`**, an ESLint rule that flags `jest.mock('c/...')` and `jest.mock('lightning/...')`
  in Jest tests, which can silently stop replacing the module; the install guide's ESLint snippet adds it as a warning.

### Changed

- **KernDX is licensed under the Apache License 2.0.** It is approved by the Open Source Initiative and carries a patent grant, and
  you can use KernDX for anything, including in a product that competes with it. Versions 1.10 and earlier keep the Business Source
  License 1.1, and each becomes Apache 2.0 no later than four years after it was first published. See `LICENSING.md`.
- **Plainer wording** in three Health Check messages about API mocking, three query builder messages, and the help text of API
  Call Status and API Setting Mocking Enabled. If a test of yours checks the exact text of one of these messages, update the
  text it expects. An upgrade does not change a field's help text, so an upgraded org keeps the earlier text on those two
  fields unless an administrator edits it in Setup.
- **A new logo and description for the Kern app, on a new install.** An upgraded org keeps the earlier logo and description.
- **The query builder's aggregate examples now use `toAggregateList()`.** If you copied one of the old examples, which read
  totals with `toList()`, change it the same way: in a test that registers aggregate rows, `toList()` throws.

### Fixed

- **`kern.DML_Builder.TransactionResult.getFailureCount()`** no longer ends the transaction for a suppressed save refused by an
  error from Apex code.
- **A masking rule in JsonKey mode (one that masks the value under a named JSON key) now finds a key name of up to 512
  characters** anywhere in a long value. Before, a key name
  longer than 64 characters could be missed, and the value under it was not masked.
- **Clearing the create form** also clears the values it would save.
- **The scheduled job editor window** opens for an admin who cannot read the job runner fields, and keeps their values.
- **The cron editor** refuses unknown day names and never loads a refused expression into a preset.
- **The bundled d3 static resource carries its licence notice.** Nothing in KernDX loads it; earlier packages kept only d3's
  copyright line, and the file now opens with the full ISC notice. The KernDX ESLint plugin now ships its MIT licence text.

Backward-compatible: no global Apex member is removed or changed in signature. Added: `TST_Factory.newDisabledFeatureFlag(String)`.
Six released labels have new wording, with the same placeholders.

For the full tour and every upgrade note, see [Kern 1.11 Release Notes](https://github.com/JVB-Consulting/kerndx/blob/main/release-notes/Release%20Notes%20-%20Kern%201.11.md).

## [1.10.0-4] — 2026-10-28

**Subscriber package version id:** `04tfj000000fkuvAAA`

1.10 closes two security gaps and makes several saves work that used to fail. Text passed where the query builder expects a field name can no longer change the query, and `bypassSharing()` now does what its description always said: it reads and saves records whatever their sharing, while the user's object and field permissions still apply. You can now mock one service at a time, outgoing or incoming, for chosen users only, and a test can hand an aggregate query the rows it returns. A chain started from a trigger inside a background job now runs, and create forms, the scheduled job editor and the chain monitor's Abort save what the user saw.

### Security

- **Text passed where the query builder expects a field name can no longer change the query.** The methods that take a field name as text for a condition, a sort or a grouping accept only a field name, a path through a lookup, a date or distance expression of the kind `kern.QRY_Function` writes, an aggregate or `toLabel()` where SOQL allows one, and in a sort the direction and null order. Other text throws an `IllegalArgumentException` before a query runs. A subquery passed to `isIn()` or `notIn()` may select only a field name or a relationship path.
- **The masking text search no longer misses a secret in a long value.** Under a `JsonKey` rule, a value the search cannot read whole is saved as `[MASKING_FAILURE]` instead of as it is, and a `Regex` rule now hides a secret that 1.9 could leave unmasked. Records saved on 1.9.0-4 keep what they held, so review the records your masking rules cover.

### Added

- **Mock one service at a time.** Tick Mocking Enabled on a service's API Setting, then turn on the new Mock Selected APIs feature flag for the users who should get mock answers. For them the service answers from its API Mock records, outgoing or incoming; for everyone else it works for real. The flag record arrives active but switched off for everyone: Is Enabled By Default is unticked and it has no strategy records. A new last Health Check row, Selected API Mocking, lists the services with the box ticked and says whether they mock for you.
- **`kern.API_Outbound.onCommitWorkStarting()`.** An outbound handler can now run code just before the framework saves a call's changes, as an inbound handler already could. Call `super.onCommitWorkStarting()` first, and make the work safe to run twice.
- **Aggregate queries can be mocked in tests.** `kern.TST_Mock.registerAggregateRows`, `kern.TST_Mock.registerNextAggregateRows` and `kern.QRY_Builder.setAggregateMock` register the rows a count, total or grouped query returns, keyed by the aliases your code reads.
- **A new code-scan rule, `KernJsonReadClassNeedsJsonAccess`,** flags a class the framework reads from JSON that has no `@JsonAccess`, so validation message merge fields never come back blank without a reason. `KernNoRawEmail`, `KernNoRawHttp` and `KernNoCoverageTheatre` now catch forms they missed.
- **`searchLookup` and `sObjectLookup` accept `default-record-id`**, so a lookup can open with a record already chosen.
- **The jobs that Health Check schedules now describe themselves.** When Health Check schedules a job (one that deletes old records, the chain watchdog, or one of the job runner's hourly checks), the job's row in Scheduled Jobs gets a plain description of what it does.
- **A context class that cannot be read logs a warning** naming the class, instead of leaving a validation message's merge fields blank with no trace.

### Changed

Each change below has a row, with what to do, in the "Behaviour changes at a glance" table of the 1.10 release note.

- **`bypassSharing()` ignores record sharing and keeps the user's object and field permissions.** On a query, on `kern.DML_Builder`, and with `kern.DML_Transaction.commitWork(false)`, in user mode, a read now finds records whatever their sharing and removes the fields the user cannot read, and a save leaves out the fields the user cannot create or edit, with one warning. A read or save the user has no object permission for is refused. In 1.9 these calls kept the user's own sharing. Code that must read or write a hidden field adds `withSystemMode()`.
- **A locator, a cursor, or a read of totals or groups with `bypassSharing()` alone throws** `kern.UTIL_Exceptions.IllegalStateException` before any query runs, because Kern cannot remove hidden fields from them. A batch class whose start method returns such a locator fails as soon as it starts; add `withSystemMode()`. `getPage()` with `bypassSharing()` alone returns a null `page.cursor`.
- **`suppressExceptions()` returns a failed result** when a save in user mode is refused for lack of the object permission, where it used to throw `System.TypeException`.
- **An incoming service with Mocking Enabled ticked runs its own code** until Mock Selected APIs is on for the user the caller signs in as. If you rely on inbound mocking, turn the flag on for those callers straight after the upgrade.
- **Record mocks never answer an aggregate query.** A test that registers only records for an object and runs an aggregate query on it now fails with a message that says what to register.
- **A scheduled retry with exponential backoff waits twice as long each time**, up to 300 seconds, and **a call's Retries count adds up across runs.** A call that has used its whole retry budget ends Failed and Dead Lettered, so calls that were retrying in a loop stop on their next run.
- **A list of numbers, dates or booleans in `isIn`, `isInStrict`, `notInSet` and `notInSetStrict` is passed as a bind variable**, so very large and very small numbers match ([#63](https://github.com/JVB-Consulting/kerndx/issues/63)). A list that holds a fraction now fails on a whole-number field.
- **`isIn(records, field)` and `isInStrict(records, field)` skip a record whose key is blank**, so they no longer match blank rows.
- **`kern.UTIL_SObjectDescribe.getRecordTypeByDeveloperName()` and `isRecordTypeAvailable()` match the developer name in any case.**
- **A trigger action's entry formula runs its context class's `preLoad()`** once for each batch, so the formula sees what `preLoad()` loads. Its queries count towards the save's query limit, and an error it throws stops the save.
- **A test that builds a permission set group with DML must call `Test.calculatePermissionSetGroup`** before it checks a custom permission, because Kern now reads the permission set Salesforce keeps for the group.
- **A component that extends `ComponentBuilder` runs its teardown once** and closes its message channel subscriptions when it is removed. An override of `disconnectedCallback` calls `super.disconnectedCallback()` first.
- **`paginatedTable` sends `pagechange`** when it moves back to the last page, and a selected row stays selected after a sort.
- **`insertCharacterAtInterval` returns the text unchanged** for an interval that is not a whole number of 1 or more, and inserts a `$` separator as written.
- **The Data Masking Advisor's Configuration health** no longer counts an object-wide target switched off together with its rule, and now counts a target left on while its rule is off.
- **The help on a validation rule's error message, Mocking Enabled, Retries, the API Setting fields and the masking rule descriptions** now match what the code does. A new installation gets the new text; an upgraded org gets new field descriptions but keeps the old help text, and keeps its masking rule descriptions.

### Fixed

- A chain started from a trigger inside a Queueable job, your own or another package's, or inside a chain step's save, now starts. A launch that fails saves nothing, so no run is left stuck in Running ([#64](https://github.com/JVB-Consulting/kerndx/issues/64)).
- A create form saves a checkbox the user never touched, an edit form's update saves, and a create form that copies a record saves a new record.
- Saving a job in the scheduled job editor window that Health Check opens keeps its Execution Mode, Run Priority and Overlap Policy, and editing only a job's description leaves its platform scheduled job, and the user it runs as, alone.
- The chain monitor's Abort stops only the run its confirmation named.
- `kern.QRY_Function.distanceInMiles` and `distanceInKilometers` work with a very small or very large coordinate.
- Kern's consoles and components behave as their guides describe: lookups, tables, the cron and scheduled job editors, the log console, the streaming monitor, the Data Masking Advisor, the API Test Harness, and Retry and Dismiss on an API issue.
- `kerndx-pipeline init --check` writes nothing, and Code Analyzer runs get their arguments right on Windows.
- The guides, the API reference and the help in Setup were checked against the code and corrected, including samples that did not compile.

Backward-compatible: no global Apex member is removed or changed in signature. Added: `API_Outbound.onCommitWorkStarting()`; for tests, `QRY_Builder.setAggregateMock` and two forms each of `TST_Mock.registerAggregateRows` and `TST_Mock.registerNextAggregateRows`; and, for the package's own tests only, the class `UTIL_FormulaContext.FoobarBulkContext`. The metadata surface is additive, with one changed label value (the API Test Harness toggle's text when mocking is off): the Mock Selected APIs feature flag record, new Custom Labels, and the `Foobar__c.Formula__c` test field, with nothing removed or renamed. On the component side, both lookups now accept a `defaultRecordId` (`default-record-id`) property.

**Upgrading from 1.9 or earlier?** If an incoming service of yours relies on Mocking Enabled, turn on Mock Selected APIs for its callers straight after the upgrade. Then run your tests: text the query builder now refuses, `bypassSharing()` reads that now throw, aggregate queries on record mocks and permission set groups built in a test show up there. Follow [Upgrading & compatibility in the 1.10 release notes](https://github.com/JVB-Consulting/kerndx/blob/main/release-notes/Release%20Notes%20-%20Kern%201.10.md#upgrading--compatibility).

For the full tour and every upgrade note, see [Kern 1.10 Release Notes](https://github.com/JVB-Consulting/kerndx/blob/main/release-notes/Release%20Notes%20-%20Kern%201.10.md).

## [1.9.0-4] — 2026-10-21

**Subscriber package version id:** `04tfj000000drajAAA`

1.9 does two main things. First, when a request another system sends to your org fails, you can now see it: once you tick Log Issues on the service it leaves an API issue, and the issue closes itself when the same caller's retry succeeds with the same `Idempotency-Key` (a key the caller sends so a repeat can be spotted), if the service also has Idempotency Enabled and Resolve Issues ticked. Running such a request again yourself is now something you switch on per service, and it is checked against what originally came in. Second, data masking is more dependable: it masks the same fields whoever saves the record, it is much faster on large data (up to 30 times faster on bulk payloads in our tests), it masks each API payload only once, and on a new installation its shipped rules never let a value through unmasked when they fail. Separately, the package's profile settings no longer grant access to Kern objects.

### Added

- **API issues for failed incoming requests.** Tick Log Issues on an inbound service's API setting, and a request that fails in your code, whose changes cannot be saved, or that the service's checks refuse leaves one Open API issue linked to its call. The caller's HTTP status is the same as before, and a caller that retries a failing request many times leaves one open issue, not one for each try.
- **The caller's retry closes the issue.** With Idempotency Enabled on the service, a retry of the same body with the same `Idempotency-Key` is linked to the failed call through the new Previous Attempt field (the earlier call lists it under Later Attempts). With Resolve Issues ticked too, any later successful request from the same user with that key resolves the earlier issues. A key belongs to the user who sent it: the same key from another user links nothing and resolves nothing.
- **A failure that can never work is marked.** Throw `UTIL_Exceptions.PermanentFailureException` from `processRequest()`, `onSuccess()` or `getValidationErrors()` and the call is ticked Permanent Failure, a new field. Retry never runs such a call again, whether it came in or went out. A `RequestRefusedException` does not tick the box, so a refused call stays open to Retry.
- **Dismiss on an API issue.** A new Dismiss action on the API issue record page marks an issue Resolved without running anything, for an issue nobody will run again. It needs the Retry API Issue permission.
- **Outbound Retry links its new call** to the one that failed, through Previous Attempt.
- **JSON Web Tokens are masked on API calls and issues.** On a new installation, `MaskJwt` ships active. It skips values shorter than 20 characters, and its pattern limits the length of each part of the token, so a long text cannot stop the save. Two new object-wide targets, `ApiCall_All_Jwt` and `Issue_All_Jwt`, save a token in a request, a response or an issue payload as `[JWT_REDACTED]`. An upgraded org gets the two targets but keeps `MaskJwt` off until you switch it on in the upgrade step. Until you do, Health Check warns that the two targets point at an inactive rule; if you decide not to mask tokens, deactivate the two targets instead.
- **`API_Base.onDMLFinished()`.** One new global member, so a handler class that extends `API_Outbound` or `API_Inbound` can override that hook as it could in 1.8.

### Fixed

- A masking target that names no field (one that covers every text field of its object) now masks the same fields whoever saves the record. In 1.8 and earlier the list of fields came from what the saving user could edit, so a save by a user who could not edit them, such as an integration user or the Automated Process user, was not masked: secrets in API calls, outbound API issues, chain runs and log entries were stored as received. Records saved before the upgrade keep what was stored.
- Masking with the shipped rules no longer breaks a save on the very large or unusual data we tested. Deeply nested JSON no longer ends the save at the stack limit, a list of 7,700 card numbers that took 4.5 seconds masks in about 0.14 seconds, and the worst API save measured, which used to stop at the 10-second CPU limit, now takes about a second, partly because each payload is masked once instead of up to three times. These are CPU times measured on a development org. A pattern of your own, or the older card rule (which an upgraded org keeps on until the upgrade step), can still end such a save.
- A Write Failure Marker rule (a rule that, when it cannot mask a value, saves `[MASKING_FAILURE]` in its place so the original is never stored) now keeps running after a failure and marks each value it fails on; before, every later value it covered in the transaction was saved unmasked ([#50](https://github.com/JVB-Consulting/kerndx/issues/50)).
- A masking target that names one field, such as `Account.Phone`, now masks that field, and the Data Masking Advisor shows the rule on the field's row.
- A masking target with a Caller Class now fires on API calls and API issues: the calling class is the handler class the API setting names for the record's service ([#51](https://github.com/JVB-Consulting/kerndx/issues/51)). Targets with a Caller Class on any other object, log entries included, still do not fire.
- A request whose `Idempotency-Key` matched a completed call of a different service no longer gets that other service's stored answer.
- The shipped `MaskJwt` pattern no longer ends a save on a long run of text such as `eyJ-eyJ-eyJ-`, and finds a token whose signature ends in a hyphen; an upgraded org sets the new pattern by hand (see the upgrade step below).
- Masking writes fewer warning log rows. A rule that fails on a log entry or a log event no longer writes a warning about itself. For each of the three masking warnings, the first time it happens is written as a full log row, and the repeats are counted in one row per day. A Block DML rule (one that refuses the whole save when it cannot mask a value) warns once per rule in a transaction, not once for every value it refused.

### Changed

Each change below has a row, with what to do, in the "Behaviour changes at a glance" table of the 1.9 release note.

- **Inbound services that already have Log Issues ticked start writing issues** as soon as you upgrade, and with Resolve Issues and Idempotency Enabled ticked too, they start resolving them. Before you upgrade, untick Log Issues where you do not want issues.
- **A stored answer belongs to one service and one caller.** With Idempotency Enabled, a request that repeats a key gets the earlier call's stored response instead of running again. That stored response is now given only when the same user sends the key to the same service; otherwise the request runs. Ask callers to send a fresh key, such as a UUID (a long random identifier), for each new request.
- **You choose which services can run a failed incoming request again, and each run is checked first.** To let Retry, Retry Selected or `FLOW_RetryApiIssues` run an inbound issue again, tick Retry Issues on its service; do this for services whose callers never retry on their own. The request is read from the issue's call, and it is not run when:
  - the service is paused or switched off;
  - the call is marked Permanent Failure;
  - the call no longer holds an exact copy of the request (masking changed the body, or the request was cut to fit its field);
  - the issue has neither a call nor a request of its own;
  - the request is kept only as a file on the call and you cannot see the call's files (it is refused as altered; run it as a user who can).

  A run that fails does not create another issue. For an issue on a call saved by 1.8 or earlier, check the call's Request before you press Retry: masking changes cannot be detected there, and such an issue is refused when the call kept the whole body only in a file.
- **Retry on an outbound issue refuses a call marked Permanent Failure.** Dismiss the issue, or set the call's Status to Queued to send it on purpose.
- **A call with an Open API issue cannot be deleted or purged** by any user, System Administrators and the scheduled purge included. Resolve or dismiss the issue first. The purge leaves these calls out only when the user it runs as can read every open issue, and it does not start for API calls at all when that user cannot read API issues, so schedule it as a user with the Kern Administrator permission set. Code or tools that delete calls with their issues delete the issues first. Bypassing the API Call trigger with `TRG_Base.bypass(...)` turns this check off too.
- **`SEL_ApiCall.getFields()` returns two more fields**, `IsPermanentFailure__c` and `PreviousAttempt__c`, and so does a selector of yours that extends it.
- **The sample Echo service no longer logs issues.**
- **The package's profile settings no longer grant object, field or tab access.** An upgrade does not take away access an earlier install gave: if you installed Kern for all users or for chosen profiles, remove Kern object access those profiles' users should not have, and give access through Kern's permission sets.
- **Shipped masking rules fail closed: a rule that fails never lets the value through unmasked.** Twelve rules move from Log and Continue (which saves the value unmasked, writes a warning and skips the rule for the rest of the transaction) to Write Failure Marker, the two card rules move from Block DML to Write Failure Marker, and a rule you create on a new installation starts at Write Failure Marker. An upgraded org keeps its own values until you follow the upgrade step.
- **A changed failure action no longer counts as customising a card rule.** The newer card rule, `MaskPaymentCard`, replaces the older `MaskCreditCard` on the framework's own objects unless you customised one of them; changing only a failure action no longer counts, so `MaskPaymentCard` alone does the work there.
- **The older card rule, `MaskCreditCard`, and its four targets ship switched off** on a new installation; an upgraded org keeps them on until the upgrade step. The Data Masking Advisor then shows "1 object-wide rule inactive" and marks the rule Superseded; that is expected.
- **Only the first 50 numbers in one value that look like card numbers get the card checksum** (the arithmetic test every real card number passes). Later ones are hidden as `[CARD_REDACTED]` without it, so a long list of numbers that are not cards can be partly hidden. If a field of yours holds long lists of numbers you need to read later, check how it looks after a save.
- **Masking targets that name a field, and targets with a Caller Class on API calls and API issues, start masking on upgrade.** A target whose rule uses Block DML now refuses the save when that rule fails, where before it did nothing: review those targets before the upgrade reaches production, and deactivate any you no longer want. Write the class name exactly as the API setting writes it.
- **An API save masks each payload once.** If a handler overrides `onDMLFinished`, call `super.onDMLFinished()` first in it, or that handler keeps masking each payload more than once. With masker performance logging on, you may see two new kinds of log entry, `UTIL_MaskerPerformanceTimer/<object>.<field>` and `UTIL_MaskerPerformanceTimer/ContentVersion`. Both are expected and need no action.
- **Very long JSON is masked by a quicker text search when someone is waiting on the save.** When such a save holds a JSON value longer than 196,608 characters, masking searches it as text for key and value pairs instead of reading it as JSON. Reading a value that long as JSON takes several seconds, and a request that runs longer than 5 seconds counts toward a platform limit after which new requests are refused. Background jobs (Queueable, Batch, future and Scheduled) still read JSON in full, so run calls that receive large payloads in a Queueable job if the detail matters. In the text search:
  - numbers, `true`, `false` and `null` under a matching key are now masked too;
  - an object or a list under a matching key saves the whole field as `[MASKING_FAILURE]`;
  - a text in quotes with other text right after its closing quote, or a key with a backslash that JSON cannot read, saves the whole field as `[MASKING_FAILURE]`;
  - if a key pattern is open-ended (a repeat with no upper limit, or an upper count of three or more digits), any value holding a quote also saves the whole field as `[MASKING_FAILURE]`. Narrow such a pattern, for example to `^(secret|client_secret)$`.
- **The help text of Dead Lettered and Manual Dead Letter in an upgraded org still names a Recover action that does not exist.** Permanent Failure decides whether Retry runs a call; to run an outgoing call again, untick Manual Dead Letter and set Status to Queued.

Backward-compatible: no global Apex member is removed or changed in signature, and one is added, `API_Base.onDMLFinished()`; what `FLOW_RetryApiIssues.retryApiIssues`, `API_Dispatcher.processInboundService`, `API_Dispatcher.execute` and `SEL_ApiCall.getFields()` do changes as described above. The metadata surface is additive too: two new fields on API Call (Permanent Failure, and Previous Attempt with its Later Attempts related list), the Dismiss quick action with its component, a trigger action that refuses deleting a call with an open issue, new Custom Labels and two new masking targets, with nothing removed or renamed; the Kern Administrator and Kern API Issue Resolver sets grant Read on both new fields.

**Upgrading from 1.8 or earlier?** Before you upgrade, check which inbound services have Log Issues ticked, and review masking targets that name a field or a Caller Class. After you upgrade, make three changes in Setup: add the new fields to the API Call page layout, add the Dismiss action to the API Issue page layout, and switch the masking rules to the new defaults. If you installed Kern for all users or for chosen profiles, also check those profiles. Follow [Upgrading & compatibility in the 1.9 release notes](https://github.com/JVB-Consulting/kerndx/blob/main/release-notes/Release%20Notes%20-%20Kern%201.9.md#upgrading--compatibility).

For the full tour and every upgrade note, see [Kern 1.9 Release Notes](https://github.com/JVB-Consulting/kerndx/blob/main/release-notes/Release%20Notes%20-%20Kern%201.9.md).

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
[1.9.0-4]: https://github.com/JVB-Consulting/kerndx/tree/v1.9.0-4
[1.10.0-4]: https://github.com/JVB-Consulting/kerndx/tree/v1.10.0-4
[1.11.0-1]: https://github.com/JVB-Consulting/kerndx/tree/v1.11.0-1
