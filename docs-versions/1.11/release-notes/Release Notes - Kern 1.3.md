# Kern 1.3 Release Notes

**Builds on:** [Kern 1.2 Release Notes](./Release%20Notes%20-%20Kern%201.2.md), [Kern 1.1 Release Notes](./Release%20Notes%20-%20Kern%201.1.md), and the [Kern 1.0 Feature Reference](./Release%20Notes%20-%20Kern%201.0.md), which together remain the full reference for everything 1.3 carries forward.
**Platform:** Salesforce API 67.0 (Summer '26), unchanged from 1.2 · **Namespace:** `kern` (rebrandable via [Installation](../docs/Installation.md))
**Release status:** the 1.3 feature set is complete, the build is validated, and end-to-end testing has passed. The package version id and release tag below are published with the release.

> **What's new since 1.2**, grouped by capability and ordered by impact. Each entry leads with the value, says **who it's for**, contrasts **before and now** where it helps, and links to a guide for the detail, so you can scan it in a minute and click through only where it's useful to you.
>
> **Safe to upgrade:** 1.3 is a **backward-compatible feature release**. Everything new is additive: the Apex API only gains methods, and the new console, Flow picklists, and permissions arrive alongside what you already have; no existing API member is removed or changed in signature. Three behaviour tightenings are worth a read before you upgrade; they are summarised under [Upgrading & compatibility](#upgrading--compatibility). The platform baseline is unchanged from 1.2 (Summer '26, API 67). For the per-build log, see the CHANGELOG.

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [At a glance](#at-a-glance)
2. [The Log Console: find and fix problems from one screen](#the-log-console-find-and-fix-problems-from-one-screen)
3. [Query builder: several aggregates in one query, read back by name](#query-builder-several-aggregates-in-one-query-read-back-by-name)
4. [Query conditions: contains matching without hand-built wildcards](#query-conditions-contains-matching-without-hand-built-wildcards)
5. [Flow Builder: picklists on the framework's Flow actions](#flow-builder-picklists-on-the-frameworks-flow-actions)
6. [Org limits: the busiest limits first](#org-limits-the-busiest-limits-first)
7. [LWC logging: the browser's error stack and context now reach the log](#lwc-logging-the-browsers-error-stack-and-context-now-reach-the-log)
8. [Test data: audit-field values stay in-memory mocks in every org](#test-data-audit-field-values-stay-in-memory-mocks-in-every-org)
9. [Smaller fixes](#smaller-fixes)
10. [Upgrading & compatibility](#upgrading--compatibility)

</details>

---

## At a glance

Ordered by impact. Find your row, read across, and follow the link for more.

| # | What's new | Who it's for | In one line |
|---|-----------|--------------|-------------|
| 1 | **[The Log Console](#the-log-console-find-and-fix-problems-from-one-screen)** | Admins · Support · Developers | Browse, group, and diagnose your logs from one screen: distinct problems, per-level counts, and a full-run timeline |
| 2 | **[Query builder: aliased aggregates](#query-builder-several-aggregates-in-one-query-read-back-by-name)** | Developers | Fold several named aggregates into one query and rank the grouped results by size |
| 3 | **[Query conditions: contains matching](#query-conditions-contains-matching-without-hand-built-wildcards)** | Developers | Text matching inside condition trees without hand-built wildcard patterns |
| 4 | **[Flow action picklists](#flow-builder-picklists-on-the-frameworks-flow-actions)** | Admins · Flow builders | Six framework Flow actions now offer their valid values as picklists instead of free text |
| 5 | **[Org limits redesign](#org-limits-the-busiest-limits-first)** | Admins | The limits view becomes a card grid with the most-consumed limits at the top and a visible error state |
| 6 | **[LWC logging keeps the client payload](#lwc-logging-the-browsers-error-stack-and-context-now-reach-the-log)** | Developers | Log entries from Lightning web components now keep the browser's error stack and context |
| 7 | **[Test data: audit fields](#test-data-audit-field-values-stay-in-memory-mocks-in-every-org)** | Developers | Audit-field values on built test records stay in-memory mocks in every org configuration |

---

## The Log Console: find and fix problems from one screen

**Who it's for:** Admins and support teams (answer "what broke, how often, and for whom") · Developers (trace one run end to end).

The framework keeps its log table small by rolling repeats of the same event into one row with an occurrence count. That is good for storage and awkward for browsing: raw list views leave you doing the grouping in your head. The new **Log Console** does that reading for you. Open it from its launch card on the Kern Home page or straight from the App Launcher.

- **A problem-first view.** The **Problem summary** view folds the selected window down to distinct problems: this error, this many occurrences, first and last seen. Switch to **Individual entries** when you need every event as its own row.
- **A summary ribbon.** Across the top: how many entries the window holds, counts per severity level, and the busiest sources, so you see where the noise comes from before you scroll. On a window too large to count exactly, the ribbon marks its totals as approximate rather than presenting a wrong number.
- **Filters that match how you scan.** One date-range picker covers rolling windows (the last 15 minutes up to the last 30 days), calendar presets (Today through This month), and a custom from/to; beside it sit per-level toggles and a free-text search that waits for you to stop typing before it queries. The console opens on the last 24 hours with errors and warnings selected. Results keep loading as you scroll, and the columns sort.
- **A detail drawer that reconstructs the run.** Selecting a row opens Overview, Timeline, Stack trace, and Context tabs. The timeline lays out every entry sharing the run's correlation ID (one tracking ID that follows a single user action across triggers, queries, callouts, and jobs) in time order, including the asynchronous steps. Usage bars show how close the transaction came to the platform's per-transaction resource caps (governor limits). The drawer names the user the entry came from rather than showing a raw id, and offers open-record and open-chain actions.
- **Connected to the Chain Monitor, both ways.** A chain step's **View logs** link opens the console already filtered to that run's correlation ID; from a log, you can jump to the chain it belongs to.

**Why it matters:** production diagnosis becomes a two-minute read: which problems are live, how often each fires, who hit them, and the full story of a single run, without building list views over raw log rows.

**Good to know:** the console reads every user's log rows, so it sits behind the **Kern Administrator** permission set; assignees see the new tab after the upgrade with nothing to enable. It is a read-only window onto your log data. The LogEntry tab keeps the raw rows, exactly as before.

**Learn more:** [Administration Tools - Guide](../docs/Administration%20Tools%20-%20Guide.md) · [Logging - Guide](../docs/Logging%20-%20Guide.md)

---

## Query builder: several aggregates in one query, read back by name

**Who it's for:** Developers.

The query builder's aggregate methods gain aliased forms, and grouped queries can now be ordered by group size.

- **Fold several aggregates into one query.** `count`, `countDistinct`, `sum`, `avg`, `min`, and `max` each gain a two-argument form taking the field and a result alias. Unlike the single-aggregate forms, the aliased calls accumulate: one query can count, sum, and take a minimum together, and you read each result back by its alias on the returned `AggregateRow`.
- **Rank groups by size.** `orderByCount(field, sortDescending)` orders grouped rows by how many records each group holds; combined with `withLimit(n)` it answers "the three biggest groups" in one query.
- **Aliases are checked where you write them.** An alias must be a bare identifier (a letter followed by letters, digits, or underscores); anything else throws an `IllegalArgumentException` at the builder call, and a duplicate alias is rejected when the query builds. The existing `addField(QRY_Function, alias)` projection now applies the same check, so an invalid alias fails at the call instead of surfacing later as a query error (see [Upgrading & compatibility](#upgrading--compatibility)).

**Why it matters:** a per-group summary read ("how many, the total, the oldest, per stage") is one typed query with named results, not several queries or auto-generated aliases.

**Learn more:** [Selectors - Guide](../docs/Selectors%20-%20Guide.md)

---

## Query conditions: contains matching without hand-built wildcards

**Who it's for:** Developers.

- **Text matching inside condition trees.** `QRY_Condition.FieldCondition` can now start from just the field (new single-argument constructors take a field name or an `SObjectField` token) and complete with `contains(value)`, which matches the value anywhere in the field. The framework owns the wildcards, so you never assemble `'%' + value + '%'` patterns by hand. The contract is the same as the query builder's own `contains()`.

**Why it matters:** a condition like "name or website contains acme" composes cleanly inside an OR tree, with the wildcard handling done for you.

**Learn more:** [Selectors - Guide](../docs/Selectors%20-%20Guide.md)

---

## Flow Builder: picklists on the framework's Flow actions

**Who it's for:** Admins and Flow builders.

Six of the framework's Flow actions used to take their choice-style inputs as free text: you had to know that a bypass wanted exactly `CLASS_NAME`, or a log level exactly `WARN`. Those inputs are now picklists in the Flow Builder property panel.

| Action | Input | Choices |
|---|---|---|
| **Trigger Bypass** (`FLOW_BypassTrigger`) | Action | Bypass, Clear, Clear All |
| | Bypass Type | Class, Object |
| **Is Bypassed** (`FLOW_CheckTriggerBypassed`) | Bypass Type | Class, Object |
| Validation bypass (`FLOW_BypassValidation`) | Bypass Type | Object, Rule Group, Rule |
| Validation-rules run (`FLOW_ExecuteValidationRules`) | Trigger Context | Before Insert, Before Update, Before Delete, After Insert, After Update, After Delete, After Undelete |
| **Log Flow Event** (`FLOW_LoggerLog`) | Log Level | Debug, Info, Warning, Error |
| Log write (`FLOW_WriteLog`) | Log Level | Debug, Info, Warning, Error |

**Why it matters:** the valid values sit right in the property panel, so a typo can no longer hide until the Flow runs.

**Good to know:** nothing changes at run time. The actions accept the same values as before, now picked instead of typed, and the Flows you have already built keep working as they are. The help text and placeholders in the property panel describe the choices in the same terms as the picklists, and each one also names the stored value (for example `OBJECT_NAME` for Object), because that stored value is what the field displays after you pick and what a Flow variable or formula must supply.

**Learn more:** [Triggers - Guide](../docs/Triggers%20-%20Guide.md) · [Validation - Guide](../docs/Validation%20-%20Guide.md) · [Logging - Guide](../docs/Logging%20-%20Guide.md)

---

## Org limits: the busiest limits first

**Who it's for:** Admins (watch capacity while you work) · Architects (spot a runaway consumer early).

- **A prioritised card grid replaces the bar chart.** The Org limits view in the Streaming Event Monitor now shows each limit as a card, sorted worst-first so the most-consumed limits lead. You can switch to a name sort or search the list, and a card changes colour as usage passes 70% and again at 90%, so a limit under pressure stands out at a glance.
- **A visible error state.** If the limits data cannot be loaded, the view now says so plainly; previously it could sit silently blank.

**Why it matters:** the question the view exists to answer, "which limits are close to their ceiling", is answered by the first row of cards.

**Learn more:** [Administration Tools - Guide](../docs/Administration%20Tools%20-%20Guide.md)

---

## LWC logging: the browser's error stack and context now reach the log

**Who it's for:** Developers building Lightning web components, and anyone reading the resulting logs.

The client-side logging module (`utilityLogger`) captures structured context in the browser and, on an error, the JavaScript stack trace. Fixed in 1.3: that payload now survives the trip to the server.

- **Client context is persisted.** The context attached in the browser lands in the log entry's `ContextData__c` field.
  - *Previously:* the context was read only to label the entry, so every LWC log persisted with an empty context.
- **The JavaScript error stack becomes the entry's stack trace.** A client error stack, when present, is promoted into `StackTrace__c`. A context value that cannot be promoted (blank, or not text) stays in the context instead, so no client data is silently lost.
  - *Previously:* the field held a stack trace of server-side logging plumbing, whatever the browser had captured.
- **No misleading traces.** When an entry arrives without a client stack, the framework strips its own internal frames from the stack trace it records rather than presenting plumbing as the source: your calling frames remain, or the trace stays empty. This holds whether the package runs under its namespace or your own.

**Why it matters:** a front-end failure is now diagnosable from the log alone: what the user was doing (the context) and where the JavaScript failed (the stack), both visible in the Log Console's detail drawer.

**Learn more:** [LWC - Guide](../docs/LWC%20-%20Guide.md) · [Logging - Guide](../docs/Logging%20-%20Guide.md)

---

## Test data: audit-field values stay in-memory mocks in every org

**Who it's for:** Developers writing Apex tests with the framework's test-data builder.

The test-data builder (`TST_Builder`) lets a test set the five system audit fields (`CreatedDate`, `CreatedById`, `LastModifiedDate`, `LastModifiedById`, `SystemModstamp`) on the records it builds. Those values are meant to be in-memory mocks, because the platform normally owns those fields.

- **Audit fields are now pinned as read-only mocks outright.** The builder no longer infers "read-only" for these fields by attempting a write; it registers them as mock values in every org configuration.
  - *Previously:* in an org where the running user held the **Set Audit Fields upon Record Creation** permission (`CreateAuditFields`), the write probe stopped failing, and mock audit values (fabricated user ids, back-dates) were written to the database through real DML.
  - *Now:* audit values you set through the builder stay on the in-memory records it hands back, in every org, whoever runs the test.

**Why it matters:** the same test builds the same data everywhere. Enabling audit-field back-dating in an org no longer changes what your test suite writes to the database.

**Learn more:** [Test Data - Guide](../docs/Test%20Data%20-%20Guide.md)

---

## Smaller fixes

- **Lookup search no longer errors on an unknown object name.** The search behind the framework's lookup components (such as `sObjectLookup` and the record-create form) resolves the object name through the schema first; a name that does not exist now returns no results instead of a failed search.
- **Streaming Event Monitor sidebar accessibility.** Screen readers now announce the sidebar's expand and collapse state correctly, and the "Org limits" navigation label can be translated through a Custom Label (the visible text is unchanged).

---

## Upgrading & compatibility

1.3 is a **backward-compatible feature release**. The Apex API only gains methods; no existing member is removed or changed in signature, so upgrading from 1.2 is the standard package upgrade with no migration steps. Users assigned the **Kern Administrator** permission set see the new Log Console tab after the upgrade, with nothing to enable. The platform baseline is unchanged from 1.2 (Summer '26, API 67).

Three behaviour notes:

1. **Query alias validation now fails fast.** `addField(QRY_Function, alias)` and the new aliased aggregate methods validate the alias at the builder call: an alias that is not a bare identifier throws an `IllegalArgumentException` immediately, where an invalid alias previously surfaced later as a query error. If a query stops at the builder after the upgrade, correct the alias to a bare identifier (a letter followed by letters, digits, or underscores).
2. **Test-data audit fields stay in memory under `CreateAuditFields`.** Audit-field values set through the test-data builder are now always in-memory mocks. If the running user holds **Set Audit Fields upon Record Creation**, those values previously reached the database; a test that asserted the persisted audit values in that configuration will now read the platform-set values instead.
3. **Lookup search returns empty instead of erroring on an unknown object name.** Code that relied on catching the search error should check for the empty result instead.

### Known issue: Salesforce Code Analyzer cannot load the scanner rulesets yet

The KernDX scanner rulesets now reference a rule that arrived in PMD 7.26.0 (PMD is the engine that checks Apex code without running it). Salesforce Code Analyzer currently bundles PMD 7.25.0, so a `sf code-analyzer` run pointed at the rulesets stops with an engine error instead of scanning. This is a Code Analyzer limitation, not a broken ruleset: the same rulesets load and run cleanly on the standalone PMD command line. `kerndx doctor` detects the situation and reports the bundled version against the required minimum.

Until Salesforce ships a Code Analyzer release that bundles PMD 7.26.0 or newer, run the rulesets with the standalone PMD CLI (7.26.0 or newer; on macOS, `brew install pmd`):

```bash
pmd check -d force-app -R scanner/kerndx-pmd-ruleset.xml -f text --no-cache
```

Point `-d` at the code you want scanned. Once a newer Code Analyzer arrives, `sf code-analyzer` works again with no change to the rulesets.

### Known issue: the Log Console's date presets follow the browser clock

The console's quick date filters (Today, Yesterday, Last Week, This Month) currently measure the day from your browser's clock. When your computer's timezone matches your Salesforce timezone, which is the usual case, they behave exactly as expected. When the two differ, the window shifts by that offset: an entry stamped late yesterday in your Salesforce timezone can appear under Today. The timestamp shown on each entry is always correct. Until a fix lands in a future version, use the custom date range when you need an exact window, or keep your computer's timezone aligned with your Salesforce one.
