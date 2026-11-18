# Kern 1.9 Release Notes

**Platform:** Salesforce API 68.0 (Winter '27) · **Namespace:** `kern` (rebrandable via [Installation](../docs/Installation.md))
**Release status:** released. Kern 1.9.0-4 is the production-installable 1.9 line.

## The headlines

**Masking now works the same, whoever saves the record.**
In 1.8 and earlier, a record saved by a user who could not edit its fields, such as an integration user, could skip masking altogether:
secrets in API calls, outbound API issues, chain runs and log entries could be stored as received. 1.9 masks the same fields
whoever saves. Records saved before the upgrade keep what was stored.
[What changed](#a-target-that-names-no-field-masks-the-same-fields-whoever-saves-the-record)

**Masking is much faster on bulk data, up to 30 times in our tests, and with the shipped rules the large payloads we tested no longer break a save.**
A list of 7,700 card numbers that took 4.5 seconds to mask now takes about 0.14 seconds. An API call carrying large bulk data, which used to
stop at the platform's CPU limit and fail, now takes about a second of CPU time: the rules are faster, and each payload is masked once
instead of up to three times. One trade-off: in a long list of numbers, only the first 50 that look like card numbers get the card
checksum (the arithmetic test every real card number passes), and the rest are hidden without it, so numbers that are not cards can be hidden too.
[The numbers](#masking-copes-with-very-large-and-unusual-data-and-runs-once-per-save)

**A failed incoming request now leaves an API issue, and the caller's retry closes it.**
When a request another system sends to your org fails, you can now see it as an API issue (a Kern record that flags a failed call for
someone to look at), like a failed outgoing call, once you tick **Log Issues** on that service. When the same caller retries with the
same `Idempotency-Key` (a value the caller sends with a request so that a resend can be recognised as the same request) and succeeds, the
issue closes itself, if the service also has **Idempotency Enabled** and **Resolve Issues** ticked.
[How it works](#a-failed-incoming-request-leaves-an-api-issue-and-the-callers-retry-closes-it)

**Running a failed incoming request again is safe by default.**
You switch Retry on per service, and it runs a request only when it can prove it is an exact copy of what came in. A call with an open
issue can no longer be deleted.
[Retry, step by step](#running-an-incoming-request-again-is-opt-in-and-checked)

**The package's profile settings no longer grant object access.**
An install for all users or for chosen profiles could give those users full access to Kern's log, API and chain records. From 1.9 the
profile settings grant none; access comes from Kern's permission sets. An upgrade does not take away access an earlier install gave, so
check those profiles.
[Check your profiles](#the-packages-profile-settings-no-longer-grant-object-access)

> **Upgrading from 1.8? A few checks before, and some Setup steps after.** Before you upgrade, check which inbound services have **Log
> Issues** ticked, and review masking targets that name a field or a Caller Class, above all those on Block DML. After you upgrade, switch
> the shipped masking rules to the new defaults, because an upgrade keeps your org's own values for them
> ([the upgrade step](#upgrade-step-from-18-or-earlier-switch-your-masking-rules-to-the-new-defaults)); add the new API fields and the
> Dismiss action to your page layouts ([Upgrading & compatibility](#upgrading--compatibility)); and, if you installed Kern for all users or
> for chosen profiles, [check your profiles](#the-packages-profile-settings-no-longer-grant-object-access).
>
> **Your code keeps compiling.** No global Apex member is removed or changed in signature. One is added, `kern.API_Base.onDMLFinished()`,
> so that a handler class that extends `kern.API_Outbound` or `kern.API_Inbound` can override that hook as it could in 1.8. If yours does,
> call `super.onDMLFinished()` first in it (see [An API save masks each payload once](#an-api-save-masks-each-payload-once)). What some
> members do changes, as listed under
> [Changes that can affect code you have written](#changes-that-can-affect-code-you-have-written). Before you upgrade, read the
> [behaviour changes at a glance](#behaviour-changes-at-a-glance): one row per change, with what to do.

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [The headlines](#the-headlines)
2. [At a glance](#at-a-glance)
3. [Behaviour changes at a glance](#behaviour-changes-at-a-glance)
4. [A failed incoming request leaves an API issue, and the caller's retry closes it](#a-failed-incoming-request-leaves-an-api-issue-and-the-callers-retry-closes-it)
5. [The package's profile settings no longer grant object access](#the-packages-profile-settings-no-longer-grant-object-access)
6. [Data masking](#data-masking)
7. [Changes that can affect code you have written](#changes-that-can-affect-code-you-have-written)
8. [Upgrading & compatibility](#upgrading--compatibility)
</details>

---

## At a glance

Ordered by impact. Find your row, read across, and follow the link for more.

| # | What's new | Who it's for | In one line |
|---|-----------|--------------|-------------|
| 1 | **[Issues for failed incoming requests](#a-failed-incoming-request-leaves-an-api-issue-and-the-callers-retry-closes-it)** | Developers · Support · Admins | A failed incoming request can leave an API issue, the caller's retry with the same key closes it, and Dismiss closes one nobody will run again |
| 2 | **[Data masking](#data-masking)** | Admins · Developers · Security | Masking copes with very large and unusual data (a list of 7,700 card numbers that took 4.5 s masks in 0.14 s, and saves that hit the CPU limit now complete) and masks each API payload once; a target that names no field now masks the same fields whoever saves, shipped rules never save a value unmasked when they fail, JSON Web Tokens are masked on API calls and issues, and an upgraded org needs one set of Setup changes |

---

## Behaviour changes at a glance

Every change that can affect code, configuration or a check you own, with what to do. Each row links to its explanation.

| Area | What changed | What to do | Read more |
|---|---|---|---|
| Inbound | An inbound service with **Log Issues** ticked starts writing an API issue when a request fails (one open issue per request, however many times the caller retries it) | Untick Log Issues on inbound services where you do not want issues | [Inbound settings that already have Log Issues ticked start writing issues](#inbound-settings-that-already-have-log-issues-ticked-start-writing-issues) |
| Inbound | With **Resolve Issues** and **Idempotency Enabled** ticked, a successful request with a key resolves the open issues of the same user's earlier failed requests with that key | Nothing, unless a report counts open issues | [Inbound settings that already have Log Issues ticked start writing issues](#inbound-settings-that-already-have-log-issues-ticked-start-writing-issues) |
| Inbound | With **Idempotency Enabled**, a request that repeats a key gets the earlier call's saved response (the stored answer) only when the same user sends the same key to the same service | Ask callers to send a fresh `Idempotency-Key` for each new request | [A stored answer belongs to one service and one caller](#a-stored-answer-belongs-to-one-service-and-one-caller) |
| API issues | Retry on an inbound issue needs **Retry Issues**. It refuses a call marked Permanent Failure, a request that is no longer an exact copy of what came in, and an issue with neither a call nor a request of its own | Tick Retry Issues on inbound services whose callers never retry | [Running an incoming request again is opt-in and checked](#running-an-incoming-request-again-is-opt-in-and-checked) |
| API issues | Retry on an outbound issue refuses a call marked Permanent Failure | Dismiss the issue, or set the call's Status to Queued to send it on purpose | [Retry never sends a permanent failure again](#retry-never-sends-a-permanent-failure-again) |
| API calls | A call with an Open API issue cannot be deleted or purged by any user, unless Apex turns off the API Call trigger with `kern.TRG_Base.bypass(...)` | Resolve or dismiss the issue first; run the scheduled purge, the job that deletes old API calls, as a user with the Kern Administrator permission set | [A call with an open issue cannot be deleted](#a-call-with-an-open-issue-cannot-be-deleted) |
| API calls | `SEL_ApiCall.getFields()` returns two more fields | Nothing, unless code compares the list | [The API call selector reads two more fields](#the-api-call-selector-reads-two-more-fields) |
| Inbound | The sample Echo service no longer logs issues | Nothing | [The sample Echo service no longer logs issues](#the-sample-echo-service-no-longer-logs-issues) |
| API calls | The help text of Dead Lettered and Manual Dead Letter in an upgraded org still names a Recover action that does not exist | Read the correction | [Dead Lettered and Manual Dead Letter: there is no Recover action](#dead-lettered-and-manual-dead-letter-there-is-no-recover-action) |
| Access | The package's profile settings no longer grant access to Kern objects | If you installed Kern for all users or for chosen profiles, check Kern object access on those profiles | [The package's profile settings no longer grant object access](#the-packages-profile-settings-no-longer-grant-object-access) |
| API handlers | A handler class can override `onDMLFinished()` again, as it could in 1.8 | Nothing for the override itself. An override calls `super.onDMLFinished()` first: see the row on API saves below | [Changes that can affect code you have written](#changes-that-can-affect-code-you-have-written) |
| Masking | A target that names no field covers every text field of its object whoever saves the record; in 1.8 and earlier, a save by a user who could not edit those fields, such as an integration user, was not masked | Nothing. Records saved before the upgrade are not re-masked | [A target that names no field masks the same fields whoever saves the record](#a-target-that-names-no-field-masks-the-same-fields-whoever-saves-the-record) |
| Masking | A Write Failure Marker rule (one that saves `[MASKING_FAILURE]` in place of a value it cannot mask) keeps running after a failure and marks each value it fails on | Nothing | [A Write Failure Marker rule keeps running and marks each value it fails on](#a-write-failure-marker-rule-keeps-running-and-marks-each-value-it-fails-on) |
| Masking | Shipped rules fail closed: a rule that cannot mask a value saves `[MASKING_FAILURE]` instead (Write Failure Marker). `MaskJwt`, the JSON Web Token rule, is on. An upgraded org keeps its own values | Follow the upgrade step | [Upgrade step: from 1.8 or earlier, switch your masking rules to the new defaults](#upgrade-step-from-18-or-earlier-switch-your-masking-rules-to-the-new-defaults) |
| Masking | The card rules ship with Write Failure Marker, and the older card rule and its four targets ship switched off | Follow the upgrade step | [The older card rule and its four targets ship switched off](#the-older-card-rule-and-its-four-targets-ship-switched-off) |
| Masking | A target that names a field, and a target with a Caller Class on API calls and issues, start masking | Review those targets, above all those on Block DML, before you upgrade | [A masking target that names a field now masks that field](#a-masking-target-that-names-a-field-now-masks-that-field) and [A masking target scoped to a caller class now fires on stored API calls](#a-masking-target-scoped-to-a-caller-class-now-fires-on-stored-api-calls) |
| Masking | In one value, only the first 50 numbers that look like card numbers get the card checksum (the arithmetic test every real card number passes); every later one is hidden as `[CARD_REDACTED]` without it, so a long list of numbers that are not cards (a fixed-width file, a table of codes, IDs in a log) can be partly hidden | If a field of yours holds long lists of numbers you need to read later, check how it looks after a save | [Masking copes with very large and unusual data, and runs once per save](#masking-copes-with-very-large-and-unusual-data-and-runs-once-per-save) |
| Masking | An API save masks each payload once | If a handler overrides `onDMLFinished`, call `super.onDMLFinished()` first | [An API save masks each payload once](#an-api-save-masks-each-payload-once) |
| Masking | In a save someone waits for, a JSON value longer than 196,608 characters is searched as plain text for key and value pairs (the quick text search) instead of being read as JSON | If a rule of yours masks values under matching JSON keys, narrow its key pattern when it has a repeat with no upper limit (such as `.*`) or an upper limit of 100 or more (such as `{1,100}`) | [Long JSON in a synchronous save goes through the quick text search](#long-json-in-a-synchronous-save-goes-through-the-quick-text-search) |
| Masking | Masking writes fewer warning log rows: repeats are counted in one row per day | Nothing, unless a report or alert counts masking warnings | [Fewer warning log rows from masking](#fewer-warning-log-rows-from-masking) |

---

## A failed incoming request leaves an API issue, and the caller's retry closes it

**Who it's for:** developers who build inbound services; support users who resolve API issues; admins who set up the services.

Until now, a request another system sent to your org left an API call record when it failed, but no API issue: nobody was told, and
nothing tied the caller's own retry back to the failure. From 1.9 you can ask for an issue, and the caller's retry closes it.

- **Failed incoming requests can leave an API issue.** Tick **Log Issues** on an inbound service's API setting. A request that fails
  in your code, whose changes cannot be saved, or that the service's checks refuse then leaves one Open API issue, linked to its call.
  The issue holds no copy of the request: the call keeps it. The caller's HTTP status is the same as before.
- **A failure that can never work is marked.** Throw `kern.UTIL_Exceptions.PermanentFailureException` from `processRequest()`,
  `onSuccess()` or `getValidationErrors()`, and the call is ticked **Permanent Failure** (a new field). Retry never runs such a call
  again, in either direction. A `kern.UTIL_Exceptions.RequestRefusedException` does not tick the box, so a refused call stays open to
  Retry, as before.
- **The caller's retry is linked, and its success closes the issue.** A later successful request with the same `Idempotency-Key`
  resolves the earlier issues, and a same-body retry is linked to the failed call through **Previous Attempt** (a new field; the earlier
  call lists it under **Later Attempts**). This needs **Idempotency Enabled** on the service, and resolving also needs **Resolve Issues**.
  Without a key nothing is linked. A key belongs to the user who sent it: the same key from another user is a new request, which links
  nothing and resolves nothing. A caller that retries a failing request many times leaves one open issue, not one for each try.
- **Running a failed request again is opt-in, and it reads the request from its call.** Retry on an inbound issue now needs **Retry
  Issues** on the service, and never runs a permanent or altered request (see
  [Running an incoming request again is opt-in and checked](#running-an-incoming-request-again-is-opt-in-and-checked)). A replay runs
  as the person who pressed Retry, but its key is checked as the user who sent the request. If that caller already completed the request
  with the same key, the replay gets the stored answer (the saved response of the earlier call) and runs nothing. Once a replay works,
  the caller's own later retry gets the replay's answer. So nothing runs twice.
- **Outbound Retry links its new call.** Retry on an outbound issue links the new call to the one that failed, through **Previous
  Attempt**, and refuses a call marked Permanent Failure.
- **Dismiss closes an issue.** A new **Dismiss** action on the API issue record page marks an issue Resolved without running anything,
  for an issue nobody will run again. It needs the **Retry API Issue** permission.
- **A call with an open issue is kept.** No user can delete or purge an API call that has an Open API issue, until the issue is resolved
  or dismissed (Apex that turns off the API Call trigger also turns this check off).
- **A key reused across services no longer returns another service's answer.** Until now, a request whose key matched a completed call
  of a different service was answered with that other service's stored response.
- **The sample Echo service no longer logs issues.**

**What to do.** Check your inbound services' settings before you upgrade (see
[Inbound settings that already have Log Issues ticked start writing issues](#inbound-settings-that-already-have-log-issues-ticked-start-writing-issues)).
Ask the owners of each calling system to send a fresh `Idempotency-Key` for every new request and to reuse it only when they resend that
same request from the same integration user.

**Read more.** The Web Services guide's [When a request fails](../docs/Web%20Services%20-%20Guide.md#when-a-request-fails) and
[Failures and retries](../docs/Web%20Services%20-%20Guide.md#failures-and-retries) sections.

---

## The package's profile settings no longer grant object access

When you install a package, Salesforce can copy the package's profile settings onto profiles in your org. Which profiles depends on how
you installed it: for admins only, onto System Administrator; for all users, onto System Administrator and every profile you cloned from a
standard one; for chosen profiles, onto the profiles you picked. Up to 1.8, Kern's profile settings gave full access to eight Kern objects,
including View All and Modify All on log entries, API calls, API issues and chain runs, and access to Kern's Apex classes. On an admins-only
install that changes nothing, because System Administrator has that access anyway. On an all-users or chosen-profiles install, users of
those profiles may have received access you did not intend.

From 1.9 the package's profile settings grant no object, field or tab access. An upgrade does not take away access an earlier install
gave. **If you installed Kern for all users or for chosen profiles,** open each of those profiles in Setup and remove access to Kern
objects that its users should not have; give access through Kern's permission sets instead.

---

## Data masking

**Who it's for:** admins who set up masking rules and targets; developers whose code saves API calls, API issues or log entries.

Data masking hides sensitive values, such as card numbers and secret keys, before a record is saved. Each masking rule has a **Failure Action** that decides what happens when the rule cannot mask a value: **Write
Failure Marker** saves `[MASKING_FAILURE]` in place of the value and the save goes ahead; **Log and Continue** saves the value unmasked
and writes a warning log entry; **Block DML** refuses the whole save. These changes make masking cover more,
fail safely and run less often. Most of them reach your org with the package. The ones that depend on values you control are collected in
[Upgrade step: from 1.8 or earlier, switch your masking rules to the new defaults](#upgrade-step-from-18-or-earlier-switch-your-masking-rules-to-the-new-defaults).
Two more masking changes can affect code or targets you wrote; they are under
[Changes that can affect code you have written](#changes-that-can-affect-code-you-have-written).

### Masking copes with very large and unusual data, and runs once per save

In 1.8, some values could end a save outright, and then the whole save failed, not only the masking. Deeply nested JSON ended any save at
the platform's stack limit (the limit on how deeply code can call into itself). A list of tokens or a dump of thousands of card numbers in an API call's payloads took the save past the
10-second CPU limit, partly because each payload was masked up to three times in one save.

1.9 reworks the shipped rules for that kind of data and masks each payload once. We measured the times below on a development org, with each field filled to
its full length of 131,072 characters (the JSON nested 2,000 levels deep is shorter: 12,003 characters). Times in your org will differ
with its data and setup. Each time is the CPU time masking took for one field, or for the whole save in the last two rows:

| What the field held | What that looks like in real life | 1.8 | 1.9 |
|---|---|---|---|
| About 7,700 card numbers, one space apart | a payment batch, a card export or a test file pasted into a request | about 4,500 ms | about 140 ms |
| About 6,500 numbers of 19 digits (the longest a card number can be) that pass the card checksum | a list of gift-card or loyalty numbers | about 840 ms | about 125 ms |
| One long run of single digits with a space or a hyphen between each | a fixed-width file, a table of quantities or codes: no card in it, but a card number may contain spaces and hyphens, so every digit could be where one starts | about 460 ms | about 80 ms; past the first 50 numbers that look like card numbers, each one is hidden as a card, so most of this field becomes `[CARD_REDACTED]` |
| A JSON list of about 9,000 entries, each holding a value under the key `token` | an API response that lists access tokens or keys | about 1,740 ms | about 500 ms |
| The same list, cut short | a long response stored cut to the length of its field, which is no longer valid JSON | about 2,500 ms for one pass; a second pass in the same save ends it at the CPU limit (in 1.8 an API save made up to three passes) | about 150 ms; the whole field is saved as `[MASKING_FAILURE]` |
| JSON nested 2,000 or 21,000 levels deep | rarely real data: a broken payload, or one built to break the receiver | the save ends ("Maximum stack depth") | 21 to 41 ms |
| A whole API save with a request, parameters and response each holding one of the inputs above (the worst mix measured) | an integration that sends or receives bulk data | the save ends at the 10,000 ms CPU limit | about 990 ms |
| A whole API save with the 19-digit list in its request, parameters and response | the same, with long reference numbers | 7,871 ms | about 505 ms |

Each payload is now masked once per save instead of up to three times (see
[An API save masks each payload once](#an-api-save-masks-each-payload-once)). A 2 MB request body masks in about 1 to 3 seconds in a
synchronous save (one someone waits for), and the shipped rules left no secret in the bodies we tested (the limits below name the one
kind of text they do not reach).

**Where the limits still are.**

- These figures are for the rules and patterns the package ships. A pattern you write, or the older card rule if you switch it back on,
  can still end the save on such data.
- In one value, only the first 50 numbers that look like card numbers get the card checksum. Every later one is hidden without the check, so a long list
  of numbers that are not cards can be partly hidden too.
- Two outbound calls in one synchronous transaction, each with a 2 MB response, can end the transaction at the platform's 10 MB memory
  (heap) limit. A Queueable job, a background job with higher limits, has 25 MB: two such responses fit, and three reach the limit. If
  your integrations receive large responses, make fewer calls in each transaction or job, and run them in a Queueable job.
- The secret-key rule does not mask a key and its value written as JSON inside another JSON text value, with each quote escaped as `\"`
  (for example `{"title":"{\"password\":\"x\"}"}`). This is true in every field and in the attached file, as it was in 1.8. Card numbers
  in such text are still masked.

Nothing to do on upgrade: the change is in the code, so it reaches your org with the package.

### A target that names no field masks the same fields whoever saves the record

A masking target that names no field covers every text field of its object. In 1.8 and earlier, the list of fields was built from the
fields the user saving the record could edit. When that user could not edit those fields, such as an integration user or the Automated
Process user, nothing was masked. On the framework's own records, secrets in API call requests, responses, addresses (the web addresses called) and error messages (in
both directions), in outbound API issues, in async chain run records and in log entries were stored as received. A user with the Kern
Administrator permission set was not affected. Every target the package ships names no field, so every shipped target was affected. A
target of your own that names no field was affected in the same way, whenever your code saved its object for a user who could not edit
those fields.

From 1.9 the list no longer depends on who saves. It covers every text field that is not a formula, a roll-up summary or an auto-number, and not
a field that identifies the record (a unique field or an external id). On a platform event, it covers custom fields only. A text field the
platform will not let anyone write is skipped
for the rest of the transaction, with one warning, and the save goes ahead.

Records saved before the upgrade keep what was stored. 1.9 does not re-mask them.

### A Write Failure Marker rule keeps running and marks each value it fails on

A masking rule set to Write Failure Marker now saves `[MASKING_FAILURE]` in place of each value it fails on, and keeps running on every
other value in the transaction. Until now, after the first failure the rule was skipped for the rest of the transaction, so every later
value it covered was saved unmasked, which is the opposite of what the setting promises
([#50](https://github.com/JVB-Consulting/kerndx/issues/50)).

| Situation | Until now | From 1.9 |
|---|---|---|
| The rule fails on one value | that value saved as `[MASKING_FAILURE]` | unchanged |
| Later values the same rule covers, in the same transaction | saved unmasked | masked as normal |
| The rule's pattern cannot compile | first value marked, later values saved unmasked | every value the rule covers saved as `[MASKING_FAILURE]` |
| A value already holding the marker | later rules could still run on it | no later rule changes it |

Log and Continue and Block DML behave as before: a Log and Continue rule saves the value unmasked and is skipped for the rest of the
transaction; a Block DML rule refuses the save and keeps refusing every later save it meets. The warning log entry is written once for each
rule in a transaction.

Nothing to do on upgrade: the change is in the masking code, so it reaches your org with the package.

### No shipped rule lets a value through unmasked when it fails, and the JSON Web Token rule is on

The shipped rules now fail closed, which means a rule that fails never lets the value through unmasked. Twelve rules (`MaskAddress`,
`MaskAuthHeader`, `MaskAwsAccessKey`, `MaskEmail`, `MaskFreeText`, `MaskIpv4Private`, `MaskJwt`, `MaskPhoneInternational`, `MaskPhoneUS`,
`MaskSecretKeys`, `MaskSsn`, `MaskUrlBasicAuth`) move from Log and Continue to Write Failure Marker, the two card rules move from Block DML
to Write Failure Marker (see the card rule entry below), and the other four keep Block DML. On a new installation, a rule you create starts at
Write Failure Marker too.

`MaskJwt`, the JSON Web Token rule, now ships active, with a minimum input length of 20 characters so short values are not checked, and a
pattern with a length limit on each part of the token, so a long text cannot stop the save. Two new object-wide targets wire it to API call records and API issues
(`ApiCall_All_Jwt` on `ApiCall__c`, `Issue_All_Jwt` on `ApiIssue__c`), so a token that appears in a request, a response or an issue payload
is saved as `[JWT_REDACTED]`.

These are the values a new installation gets. An upgraded org keeps its own values for these fields: see
[Upgrade step: from 1.8 or earlier, switch your masking rules to the new defaults](#upgrade-step-from-18-or-earlier-switch-your-masking-rules-to-the-new-defaults).

### The card rules ship with Write Failure Marker, and a changed failure action no longer counts as a customisation

On a new installation, both card rules (`MaskPaymentCard` and `MaskCreditCard`) now ship with the failure action Write Failure Marker. Until
now they shipped with Block DML. If a card rule fails on a value, the field now holds `[MASKING_FAILURE]`, which means masking failed on
that value and the original was not stored, and the save goes ahead. Until now the save was refused: for an API call, the call's log record
was refused and the whole save that carried it failed.

The newer card rule replaces the older one on the framework's own objects as long as neither rule is customised. Until now, changing only a
card rule's failure action counted as a customisation: a changed failure action on `MaskCreditCard` kept the older rule running beside the
newer one, and a changed failure action on `MaskPaymentCard` switched the takeover off, so both rules ran. From 1.9 a changed failure action
does not count, because it decides what happens when a rule fails, not what the rule masks. Only a change to the pattern, mode, replacement,
case setting, minimum input length or field types still counts.

| Situation | Until now | From 1.9 |
|---|---|---|
| A card rule fails on a value (new installation) | save refused | `[MASKING_FAILURE]` saved, save goes ahead |
| You changed only the failure action of `MaskCreditCard` | older and newer rule both ran | the newer rule does the work |
| You changed only the failure action of `MaskPaymentCard` | both rules ran | the newer rule does the work |

What to check: if you changed only the failure action of a card rule, the older rule stops running on the framework's own objects after the
upgrade. The newer rule finds the same cards, so nothing is left unmasked. An upgraded org keeps Block DML on its card rules until you change
it: see the
[upgrade step](#upgrade-step-from-18-or-earlier-switch-your-masking-rules-to-the-new-defaults).

### The older card rule and its four targets ship switched off

On a new installation, `MaskCreditCard` (the original card rule that `MaskPaymentCard` replaces) now ships switched off, and so do its four
targets (`ApiCall_All_Card`, `Chain_All_Card`, `Event_All_Card` and `Issue_All_Card`). Until now all five shipped switched on. The newer rule
finds the same cards, and on a long text full of digits the older rule's pattern can use so much processing time that the save stops with an
error no code can catch. An upgraded org keeps them switched on until you switch them off: see the
[upgrade step](#upgrade-step-from-18-or-earlier-switch-your-masking-rules-to-the-new-defaults).

While the older rule is switched off, the Data Masking Advisor's **Configuration health** shows "1 object-wide rule inactive" on a
framework object that carries one of its targets, and the object-wide banner shows **Mask Credit Card Numbers** unticked and marked
**Superseded**. That is expected: the newer rule masks the same cards, so leave the older rule off and ignore that line.

### An API save masks each payload once

Until now an API save could mask the same request or response up to three times: when the call record was inserted, again on the update
after the callout, and once more to build the file for a payload too long for its field. From 1.9 each payload is masked once on a save. A
payload that fits its field is masked by the trigger as the record is saved. A payload too long for its field is masked before the save that
first writes it to the call record: the field gets the masked text cut to fit, and the file gets the whole masked text, so the file carries
the same redaction as the record. On an outbound call that save comes after the callout, because the request and the response are written to
the record only then. On an inbound call, the response is masked once too.

If masker performance logging is on, you may see two more kinds of log entry: one named after the payload field (for example
`UTIL_MaskerPerformanceTimer/ApiCall__c.Request__c`), written when a payload too long for its field is masked, and one named
`UTIL_MaskerPerformanceTimer/ContentVersion`, written when the file step has to mask a payload again. Both are expected and need no action.

Nothing to do on upgrade: the change is in the code, so it reaches your org with the package. If an API handler of yours overrides
`onDMLFinished`, call `super.onDMLFinished()` first in it, or that handler keeps masking each payload more than once.

### Long JSON in a synchronous save goes through the quick text search

In a save that someone waits for (a user's click, or an API request), a JSON value longer than 196,608 characters is now searched as text
for `"key":"value"` pairs instead of being read as JSON. Reading a value that long as JSON takes several seconds, and a request that runs
longer than 5 seconds counts toward a platform limit on long-running requests, after which new requests are refused. With the text search, a
2 MB JSON body masks in about 3 seconds in a synchronous save.

The text search masks every plain value under a matching key (a text, a number, `true`, `false` or `null`). When a matching key holds an
object or a list, the whole field is saved as `[MASKING_FAILURE]`: the field loses its detail, but no secret is stored. Queueable, Batch,
future and Scheduled jobs still read JSON as JSON at any length.

The same text search now handles text that is not a JSON object or list, including JSON followed by other text such as `{"password":"x"}.`
or `{"password":{"pin":"1234"}} and more`. Until now that search masked only text values in quotes, and left everything else under a
matching key as it was. From 1.9:

| What the text search finds | Until now | From 1.9 |
|---|---|---|
| A text in quotes under a matching key, then a comma, a closing brace or bracket, a space or the end (for example `{"password":"x"}.`) | masked in place | masked in place |
| A text in quotes under a matching key with other text right after its closing quote (for example `{"password":"x".}`) | masked in place | the whole field saved as `[MASKING_FAILURE]` |
| A number, `true`, `false` or `null` under a matching key | left unmasked | masked in place |
| An object or a list under a matching key | left unmasked | the whole field saved as `[MASKING_FAILURE]` |
| Any key with a backslash JSON cannot read (for example `"C:\path": 1`) | ignored | the whole field saved as `[MASKING_FAILURE]` |

A key pattern with a repeat that has no upper limit, such as `.*secret.*`, can take so many steps on text full of quotes that the platform
stops the save. A repeat whose upper count has three or more digits, such as `{1,100}`, is treated the same way, because the search cannot
tell how many steps it takes. So the text search no longer runs with such a pattern: every value that goes to the text search and holds a
quote is saved as `[MASKING_FAILURE]`. The shipped `MaskSecretKeys` pattern has neither kind of repeat.

Nothing to do on upgrade, unless a JSON-key rule of yours has such a repeat in its key pattern: then give the rule a narrower pattern, such
as `^(secret|client_secret)$`. If large payloads matter to you, run the calls that receive them in a Queueable job, where JSON keeps being
read in full.

### Fewer warning log rows from masking

Two changes reduce the warning rows masking writes, with nothing to do on upgrade:

- A masking rule that fails on a log entry or a log event no longer writes a warning about itself. Until now, once such a target was deployed,
  that warning was written for every failing save. 1.9 no longer writes it.
- The three warnings masking can write (a rule failed; a rule names a field type that does not exist; a target wires a rule to a field whose
  type the rule excludes) now use flood control: the first occurrence is kept as a full log row and the repeats are counted in one row per
  day, instead of one row for every transaction. A rule on Block DML now writes its warning once per rule in a transaction, instead of once
  for every value it refused.

---

## Changes that can affect code you have written

**Who it's for:** developers and admins planning the upgrade.

Read the ones that touch code or configuration you own. Each change is listed again under
[Upgrading & compatibility](#upgrading--compatibility), and the [Behaviour changes at a glance](#behaviour-changes-at-a-glance) table
groups them by area.

### Inbound settings that already have Log Issues ticked start writing issues

An upgrade never changes your own API setting records. So an inbound service whose setting already has **Log Issues** ticked starts
writing an API issue for a failed request as soon as you upgrade (one open issue per request, however many times the caller retries it). One that also has **Resolve Issues** and **Idempotency Enabled**
ticked starts resolving those issues when the same user's later request with the same key succeeds (a status from 200 to 299).

`kern.API_Dispatcher.processInboundService` and `kern.API_Dispatcher.execute` write these issues and the **Previous Attempt** link.
Before you upgrade, open each inbound API setting and untick **Log Issues** where you do not want issues.

### A stored answer belongs to one service and one caller

With **Idempotency Enabled**, a repeat of a key is answered from the earlier call's stored response, without running again. That stored
answer is now given only when the same user sends the same key to the same service. Until now, a request whose key matched a completed
call of any service, sent by any user whose calls the running user could see, got that call's answer. Now a key sent to another service,
or by another user, is a new request and runs. Ask callers to send a fresh value, such as a UUID (a long random identifier), for each new
request.

### Running an incoming request again is opt-in and checked

**Retry**, **Retry Selected** and the **Retry API Issues** flow action (`kern.FLOW_RetryApiIssues.retryApiIssues`) change for
inbound issues. Until now they replayed an incoming request whatever the service's **Retry Issues** setting said. Now:

- they replay only when **Retry Issues** is ticked on the service, and the service is not paused or switched off;
- they read the request from the issue's call, and send it to the service the issue names;
- they refuse, with a message and nothing run, a call marked **Permanent Failure**, a call that no longer holds an exact copy of the
  request (masking changed the body, or it was cut), and an issue with neither a call nor a copy of the request of its own;
- a replay that fails writes no new issue.

A request too long for the call's **Request** field is kept whole only as a file on the call, which a user with only the Kern API Issue
Resolver permission set cannot read. Such a replay is refused as altered; replay it as a user who can see the call's files.

**Issues on calls saved by 1.8 or earlier.** Before 1.9 the framework wrote no issue for a failed incoming request, and a call kept a
fingerprint of its body (a short code worked out from the body, which changes if the body changes) only when the request carried an `Idempotency-Key`. So an inbound issue whose call has neither a key nor a
fingerprint was made by a person or by your own automation. Retry treats such an issue this way:

- when the call kept the whole request in its own fields (the body fits in **Request**, and the address and the parameters were not
  cut), Retry runs the request from the call. The call has no fingerprint, so a body that masking changed cannot be detected: check
  the call's **Request** before you press Retry;
- otherwise, when the issue holds a request of its own (its **Request Path** is filled in), Retry runs the request the issue holds, as
  1.8 did;
- otherwise the issue is refused as altered and nothing is run. This includes a call that kept the whole body in a file, because
  without a fingerprint nothing proves the file holds the body that came in.

**What to do.** Tick **Retry Issues** on the inbound services whose callers never send a failed request again, and leave it off where
the caller retries.

### Retry never sends a permanent failure again

For outbound issues, **Retry**, **Retry Selected** and `kern.FLOW_RetryApiIssues.retryApiIssues` refuse a call marked **Permanent
Failure** with the message "This call failed in a way that running it again cannot fix, so it was not run again. The issue stays open."
They link each new call to the original through **Previous Attempt**. To send such a call on purpose, an administrator sets the call's
**Status** back to **Queued**: that is the deliberate override. Otherwise, dismiss the issue. A call that failed with
`kern.UTIL_Exceptions.RequestRefusedException` is not marked, so Retry Selected still runs it once you have fixed the cause.

### A call with an open issue cannot be deleted

Deleting an API call that has an Open API issue is refused for every user, including holders of the **Delete API Records** permission,
System Administrators and the scheduled purge, with the message "This API call has an open API issue. Resolve or dismiss the issue
first, then delete the call." The purge reads as the user who runs it: it leaves these calls out when that user can read every open
issue (the Kern Administrator permission set gives this), and it does not start for API calls when that user cannot read API issues at
all. When an earlier call is deleted, the **Previous Attempt** of a later call that pointed at it is cleared. Apex that turns off the
API Call trigger with `kern.TRG_Base.bypass(...)` turns this check off too.

**What to do.** Schedule the purge of API calls as a user with the Kern Administrator set, and resolve or dismiss issues you no longer
need. Code, jobs or data tools that delete API calls together with their issues delete the issues first, then the calls.

### The API call selector reads two more fields

`kern.SEL_ApiCall.getFields()` now also returns the two new fields, `IsPermanentFailure__c` and `PreviousAttempt__c`. A selector of
your own that extends it reads them too.

### The sample Echo service no longer logs issues

The packaged `Echo` API setting now ships with **Log Issues** unticked, so the sample endpoint that is live in every org writes no
issues.

### Dead Lettered and Manual Dead Letter: there is no Recover action

The help text of these two fields names a Recover action that does not exist. 1.9 corrects it, but a changed help text reaches new
installs only: in an org that upgraded, the old text stays until you edit it. What is true:

- there is no Recover action;
- **Dead Lettered** does not decide whether Retry runs a call; **Permanent Failure** does;
- to run an outgoing call again, untick **Manual Dead Letter** and set **Status** to **Queued**.

### A masking target that names a field now masks that field

Until now, a masking target that named one field (for example `Account.Phone`) never masked it once the target was deployed: only a target
that covered a whole object did its work. The field-naming target was stored in a form the masking code could not read back, so the field
was saved unmasked and the Data Masking Advisor did not list the rule on that field. From 1.9 such a target works as the Data Masking guide
has always described: the field is masked, and the Advisor shows the rule on the field's row.

What to check: every field-naming target you created starts masking on upgrade. A target whose rule uses Block DML now refuses a save when
that rule fails, where before it did nothing, so review those targets before the upgrade reaches production, and deactivate any you no
longer want. Nothing to do for object-wide targets: they already worked.

### A masking target scoped to a caller class now fires on stored API calls

Until now a masking target with a class name in **Caller Class** (`CallerClass__c`) never fired on a stored API call or API issue, because
neither the save nor the trigger said which class was saving ([#51](https://github.com/JVB-Consulting/kerndx/issues/51)). From 1.9 the
calling class of an API call or an API issue is the handler class that the API setting names for the record's service. A target scoped to
that class masks that service's calls and issues, and no others. A service with no API setting, or a setting with no class name, is masked
with no calling class, so only targets with a blank Caller Class apply to it. Saves of every other object still have no calling class.

What to check: every target you created with a Caller Class on API calls or API issues starts masking on upgrade, when its class is the
handler class an API setting names. Targets with a Caller Class on any other object still do not fire when its records are saved.

- Write the class name the same way your API setting's class name writes it, or the target does not fire.
- A target whose rule uses Block DML now refuses the save when that rule fails, where before it did nothing. Review those targets before
  the upgrade reaches production, and deactivate any you no longer want.

---

## Upgrading & compatibility

**The global Apex signatures are unchanged.** No global member is removed or changed in signature. One is added:
`kern.API_Base.onDMLFinished()`, so that a handler class extending `kern.API_Outbound` or `kern.API_Inbound` can override that hook as it
could in 1.8. What some members do changes: `kern.FLOW_RetryApiIssues.retryApiIssues`, `kern.API_Dispatcher.processInboundService`,
`kern.API_Dispatcher.execute` and `kern.SEL_ApiCall.getFields()`, each described above. A handler that overrides `onDMLFinished` calls
`super.onDMLFinished()` first, or it keeps masking each payload more than once.

**The metadata surface is additive.** Two new fields on `ApiCall__c`: `IsPermanentFailure__c` (Permanent Failure) and
`PreviousAttempt__c` (Previous Attempt, with the related list Later Attempts). Neither is an external ID. One new quick action
(**Dismiss**, on API Issue) with its component, one new trigger action that refuses deleting an API call with an open issue, and new
Custom Labels for the new messages. Two new masking target records, `ApiCall_All_Jwt` and `Issue_All_Jwt`, and changed values on shipped masking
rules and targets that reach new installations only (see the masking upgrade step). Nothing is removed or renamed. The Kern Administrator and
Kern API Issue Resolver permission sets
grant Read on both new fields.

**After the upgrade: two short steps in Setup for the new API fields.** Page layouts belong to your org once installed, and an upgrade never overwrites them.
The Lightning record pages the package ships already show the new items; the layouts matter where a page is built from the layout,
such as a page of your own.

1. **The new fields on the API Call layout.** Open Object Manager, then API Call, then Page Layouts, and add Permanent Failure and
   Previous Attempt, and the Later Attempts related list.
2. **Dismiss on the API Issue layout.** The same for API Issue: add the Dismiss action beside Retry.

Masking has its own Setup step for every org that upgrades from 1.8 or earlier: see [Upgrade step: from 1.8 or earlier, switch your masking rules
to the new defaults](#upgrade-step-from-18-or-earlier-switch-your-masking-rules-to-the-new-defaults).

**Behaviour changes to note on upgrade** (each links to its explanation):

- **[Inbound settings that already have Log Issues ticked start writing issues.](#inbound-settings-that-already-have-log-issues-ticked-start-writing-issues)**
  With Resolve Issues and Idempotency Enabled ticked too, they start resolving them.
- **[A stored answer belongs to one service and one caller.](#a-stored-answer-belongs-to-one-service-and-one-caller)** A key reused
  across services, or by another user, no longer gets another request's answer.
- **[Running an incoming request again is opt-in and checked.](#running-an-incoming-request-again-is-opt-in-and-checked)** It needs
  Retry Issues, and never replays a permanent or altered request.
- **[Retry never sends a permanent failure again.](#retry-never-sends-a-permanent-failure-again)** It links the new call to the
  original.
- **[A call with an open issue cannot be deleted.](#a-call-with-an-open-issue-cannot-be-deleted)** By any user, the purge included, unless Apex turns off the API Call trigger.
- **[The API call selector reads two more fields.](#the-api-call-selector-reads-two-more-fields)**
- **[The sample Echo service no longer logs issues.](#the-sample-echo-service-no-longer-logs-issues)**
- **[Dead Lettered and Manual Dead Letter: there is no Recover action.](#dead-lettered-and-manual-dead-letter-there-is-no-recover-action)**
  Whatever the fields' help says in an upgraded org.
- **[The package's profile settings no longer grant object access.](#the-packages-profile-settings-no-longer-grant-object-access)** An
  upgrade does not take away access an earlier install gave: if you installed Kern for all users or for chosen profiles, check those
  profiles.
- **[A target that names no field masks the same fields whoever saves the record.](#a-target-that-names-no-field-masks-the-same-fields-whoever-saves-the-record)**
  Records saved before the upgrade are not re-masked.
- **[A Write Failure Marker rule keeps running and marks each value it fails on.](#a-write-failure-marker-rule-keeps-running-and-marks-each-value-it-fails-on)**
- **[No shipped rule lets a value through unmasked when it fails, and the JSON Web Token rule is on.](#no-shipped-rule-lets-a-value-through-unmasked-when-it-fails-and-the-json-web-token-rule-is-on)**
  An upgraded org keeps its own values: follow the upgrade step below.
- **[The card rules ship with Write Failure Marker.](#the-card-rules-ship-with-write-failure-marker-and-a-changed-failure-action-no-longer-counts-as-a-customisation)**
  A changed failure action no longer counts as a customisation.
- **[The older card rule and its four targets ship switched off.](#the-older-card-rule-and-its-four-targets-ship-switched-off)**
- **[Only the first 50 numbers in a value that look like card numbers get the card checksum.](#masking-copes-with-very-large-and-unusual-data-and-runs-once-per-save)**
  Later ones are hidden without it, so a long list of numbers that are not cards can be partly hidden.
- **[An API save masks each payload once.](#an-api-save-masks-each-payload-once)** A handler that overrides `onDMLFinished` calls
  `super.onDMLFinished()` first.
- **[Long JSON in a synchronous save goes through the quick text search.](#long-json-in-a-synchronous-save-goes-through-the-quick-text-search)**
- **[A masking target that names a field now masks that field.](#a-masking-target-that-names-a-field-now-masks-that-field)**
- **[A masking target scoped to a caller class now fires on stored API calls.](#a-masking-target-scoped-to-a-caller-class-now-fires-on-stored-api-calls)**
- **[Fewer warning log rows from masking.](#fewer-warning-log-rows-from-masking)**

### Upgrade step: from 1.8 or earlier, switch your masking rules to the new defaults

A package upgrade never changes a value you control. The masking rule and masking target settings these changes edit are ones you control
once the package is installed, so that you can tune a rule, and Salesforce never overwrites them on upgrade; that way a value you changed on
purpose is never lost. So an org that upgrades from 1.8 or earlier keeps its old values:

- the twelve rules listed in [No shipped rule lets a value through unmasked when it fails](#no-shipped-rule-lets-a-value-through-unmasked-when-it-fails-and-the-json-web-token-rule-is-on) stay on Log and Continue, and a rule you created in 1.8 or earlier keeps the Log and Continue it started with;
- the older card rule, `MaskCreditCard`, stays active with Block DML, and `MaskPaymentCard` keeps Block DML too;
- the JSON Web Token rule, `MaskJwt`, stays off, with its old pattern. Its two new targets (`ApiCall_All_Jwt` and `Issue_All_Jwt`) are new
  records, so they do arrive, but they point at an inactive rule and mask nothing;
- the four older card targets (`ApiCall_All_Card`, `Chain_All_Card`, `Event_All_Card` and `Issue_All_Card`) stay active.

A new installation gets the new values and needs no step. In an upgraded org, make these changes in Setup, under **Custom Metadata Types →
Masking Rule → Manage Records** (and **Masking Target → Manage Records** for the targets):

1. **Set Failure Action to Write Failure Marker on the shipped rules and on your own.** List the rules that still use Log and Continue, active or not. Run
   this query in the Developer Console or with the Salesforce CLI:

   ```sql
   SELECT DeveloperName, kern__IsActive__c FROM kern__MaskingRule__mdt WHERE kern__FailureAction__c = 'LogAndContinue'
   ```

   For each rule it returns, click **Edit** next to the rule, set **Failure Action** to **Write Failure Marker** (or **Block DML** if a
   refused save suits that data better), and save. Leave a rule on Log and Continue only if you chose that on purpose. An inactive shipped rule (a template you can switch on later)
   keeps Log and Continue too, so change it now, or, if you switch a shipped template on later, set its Failure Action in the same edit.
   Also edit **Mask Payment Card Numbers** and set it to **Write Failure Marker**, because it keeps Block DML: while it does, the Data
   Masking Advisor shows a finding whose message starts with `Masking rule "MaskPaymentCard" has the failure action Block DML`. Keep Block
   DML only if a refused save is what you want when a card number cannot be masked. When you create a rule of your own, check that Failure
   Action says Write Failure Marker.
2. **Switch on `MaskJwt`.** Edit **Mask JSON Web Tokens**, tick **Active**, set **Failure Action** to **Write Failure Marker** and
   **Min Input Length** to `20`, and set **Pattern** to the shipped value:

   ```text
   (?<![A-Za-z0-9_-])eyJ[A-Za-z0-9_-]{2,4000}+\.eyJ[A-Za-z0-9_-]{2,16000}+\.[A-Za-z0-9_-]{1,2000}+(?![A-Za-z0-9_-])
   ```

   Do this step even if you had already switched `MaskJwt` on: the pattern it had until now can end a save with an error no code can catch
   when a field holds a long run of text such as `eyJ-eyJ-eyJ-`, and it misses a token whose signature ends in a hyphen. The shipped value
   fixes both. Until `MaskJwt` is active, the Masking Configuration check in Health Check warns that the two JSON Web Token targets point at
   an inactive rule. The warning clears once you switch the rule on; if you decide not to mask tokens, deactivate the two targets instead.
3. **Switch off the older card rule and its four targets, together.** `MaskCreditCard` and the four `*_All_Card` targets ship switched off
   on a new installation, because the newer rule finds the same cards and the older rule's pattern can use so much processing time on a long
   text full of digits that the save stops with an error no code can catch. While `MaskPaymentCard` is on and neither card rule is
   customised, the older rule does not run on the framework's own objects anyway. Open the Data Masking Advisor and look at **Configuration
   health**. If it shows a finding whose message starts with `Masking rule "MaskCreditCard" is the older card number rule, and it still
   runs`, the older rule is running: switch `MaskCreditCard` and its four targets off together. To match a new installation, switch them off
   together even when there is no finding. If you decide to keep the older rule, keep the rule and its four targets on together. Never
   switch off only the rule: a target left on while its rule is off masks nothing, and Health Check and the Advisor both flag it.
