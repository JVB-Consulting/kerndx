# Kern 1.7 Release Notes

**Builds on:** [Kern 1.6 Release Notes](./Release%20Notes%20-%20Kern%201.6.md), [Kern 1.5 Release Notes](./Release%20Notes%20-%20Kern%201.5.md), [Kern 1.4 Release
Notes](./Release%20Notes%20-%20Kern%201.4.md), [Kern 1.3 Release Notes](./Release%20Notes%20-%20Kern%201.3.md), [Kern 1.2 Release Notes](./Release%20Notes%20-%20Kern%201.2.md),
[Kern 1.1 Release Notes](./Release%20Notes%20-%20Kern%201.1.md), and the [Kern 1.0 Feature Reference](./Release%20Notes%20-%20Kern%201.0.md), which together remain the full
reference for everything 1.7 carries forward.
**Platform:** Salesforce API 67.0 (Summer '26), unchanged from 1.6 · **Namespace:** `kern` (rebrandable via [Installation](../docs/Installation.md))
**Release status:** released. Kern 1.7.0-13 is the production-installable 1.7 line.

> **What's new since 1.6**, grouped by capability and ordered by impact. 1.6 taught async chains to look after themselves. 1.7 hands the controls to the people watching them:
> re-run a failed chain from the step that failed, restart one from the beginning, sweep the stalled ones, and stop every chain in the org, all from the Chain Monitor and none
> of it needing a deployment. The Log Console gets the matching upgrade on the diagnosis side: it works out which errors are repeating on its own, with no code changes and no
> configuration. Around those two: a step can declare a failure permanent so retry budget is never spent on a bug, search boxes match exactly what you typed, paged reads handle
> tables of any size, and a long tail of correctness fixes lands across logging, masking, queries, and test data.
>
> **Safe to upgrade:** 1.7 is **backward-compatible**. The global Apex surface is purely additive: ten new members across four existing classes, with no global member removed or
> changed in signature, all explained in [New in the Apex API](#new-in-the-apex-api). The metadata surface is additive too: eight new fields, one new custom setting, two new
> custom permissions, three new permission sets (all three ship assigned to nobody), five new configuration records, and a set of new Custom Labels, with nothing removed or
> renamed. Two behaviour changes deserve a read before you upgrade: the org-wide chain on/off switch is now driven by a custom setting rather than by editing a configuration
> record directly, and system-mode asynchronous DML now enforces record sharing unless you opt out. Those and the rest are under
> [Upgrading & compatibility](#upgrading--compatibility). For the per-build log, see the [CHANGELOG](../CHANGELOG.md).

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [At a glance](#at-a-glance)
2. [Re-run a failed chain from the step that failed](#re-run-a-failed-chain-from-the-step-that-failed)
3. [Restart a chain from the beginning](#restart-a-chain-from-the-beginning)
4. [Clear stalled chains on demand](#clear-stalled-chains-on-demand)
5. [Stop and restart all chain processing](#stop-and-restart-all-chain-processing)
6. [Watch a chain's activity as it happens](#watch-a-chains-activity-as-it-happens)
7. [Who can do what: three new permission sets](#who-can-do-what-three-new-permission-sets)
8. [The Log Console finds repeating errors on its own](#the-log-console-finds-repeating-errors-on-its-own)
9. [The Log Console at volume](#the-log-console-at-volume)
10. [What's new in the Query Builder](#whats-new-in-the-query-builder)
11. [Steps can declare a failure permanent](#steps-can-declare-a-failure-permanent)
12. [Recovery now reaches a chain that dies on its first step](#recovery-now-reaches-a-chain-that-dies-on-its-first-step)
13. [New in the Apex API](#new-in-the-apex-api)
14. [Easier to use with assistive technology](#easier-to-use-with-assistive-technology)
15. [Built to stay responsive as your data grows](#built-to-stay-responsive-as-your-data-grows)
16. [Four proven ways to compose chains](#four-proven-ways-to-compose-chains)
17. [Smaller fixes](#smaller-fixes)
18. [How this release was tested](#how-this-release-was-tested)
19. [Documentation](#documentation)
20. [Known issues](#known-issues)
21. [Upgrading & compatibility](#upgrading--compatibility)
</details>

---

## At a glance

Ordered by impact. Find your row, read across, and follow the link for more.

| # | What's new | Who it's for | In one line |
|---|-----------|--------------|-------------|
| 1 | **[Retry from the failed step](#re-run-a-failed-chain-from-the-step-that-failed)** | Operations · Admins | Re-run a failed chain from the step that failed, on the same record, without a deployment |
| 2 | **[Restart from the beginning](#restart-a-chain-from-the-beginning)** | Operations · Admins | Re-run a failed or aborted chain from step 1 as a fresh run, with the original record kept for audit |
| 3 | **[Clear stalled chains](#clear-stalled-chains-on-demand)** | Operations · Admins | Run the recovery sweep on demand instead of waiting for the next scheduled pass |
| 4 | **[Suspend and resume chains](#stop-and-restart-all-chain-processing)** | Operations · Admins | One switch stops all chain processing org-wide during an incident, and one switch starts it again |
| 5 | **[Problem grouping in the Log Console](#the-log-console-finds-repeating-errors-on-its-own)** | Admins · Developers | Repeating errors are grouped into "this error, N times" rows with no code changes and no configuration |
| 6 | **[Live activity stream](#watch-a-chains-activity-as-it-happens)** | Operations · Developers | Watch a selected chain's log entries arrive while it runs |
| 7 | **[Paged reads at any table size](#whats-new-in-the-query-builder)** | Developers | `getPage` reads past the old row ceilings, with a clear error instead of a platform failure |
| 8 | **[Permanent failures](#steps-can-declare-a-failure-permanent)** | Developers | A step can say "this will never succeed", so retry budget is never spent on a deterministic failure |
| 9 | **[Retry only the statuses you list](#steps-can-declare-a-failure-permanent)** | Developers | A web-service step retries a 503 and gives up immediately on a 400 |
| 10 | **[Three new permission sets](#who-can-do-what-three-new-permission-sets)** | Admins | Re-drive rights, stop-everything rights, and read-only monitoring are three separate grants |
| 11 | **[Literal search](#whats-new-in-the-query-builder)** | Developers | `containsLiteral()` treats `%` and `_` as ordinary characters, so a search box matches what was typed |
| 12 | **[Assistive-technology support](#easier-to-use-with-assistive-technology)** | Admins · Accessibility | Greyed-out actions state their reason, the drawer closes on Escape, and headings and button names read correctly |
| 13 | **[Steady behaviour at volume](#built-to-stay-responsive-as-your-data-grows)** | Admins · Developers | Large windows and large tables degrade with an explanation rather than failing the screen |
| 14 | **[First-step recovery](#recovery-now-reaches-a-chain-that-dies-on-its-first-step)** | Developers · Admins | A chain that dies before its first step finishes can now be proved dead and restarted |

---

## Re-run a failed chain from the step that failed

**Who it's for:** operations users and admins clearing up after an incident; developers who write chains.

When a chain fails at step 4 of 6, the work in steps 1 to 3 is already done. Until now, your only option was to start the whole thing again, which meant either repeating that
work or writing a one-off script to skip it. 1.7 adds a **Retry** action to the Chain Monitor's detail header that re-runs the chain from the step that failed, on the same
record, behind a confirmation dialog.

The run keeps its history. It is the same chain execution record, so its correlation, its earlier step log, and its audit trail all continue rather than starting over.

**A chain author opts each step in.** Retry only appears when the author of the failed step has declared that step safe to run again, by overriding `isIdempotent()` on the
step and returning `true`:

```apex
public class ChargeCardStep extends kern.UTIL_AsyncChain.ChainStep
{
	public override Boolean isIdempotent()
	{
		return true;
	}

	public override kern.UTIL_AsyncChain.StepResult work(kern.UTIL_AsyncChain.ChainContext context)
	{
		// ...
	}
}
```

The default is `false`, so nothing is re-runnable until someone who knows the step says it is. That is deliberate: a step that charges a card, sends an email, or posts to an
outside system should not be replayed because an operator was in a hurry. Pair `isIdempotent()` with a step idempotency key when the step writes to an outside system.

**Your step class needs to be re-creatable.** Resuming a chain rebuilds each remaining step from its class name, so a step class must declare no constructor of its own (only a
global class may declare a global one). A step that declares its own constructor cannot be rebuilt, and the refusal message says so by name rather than failing obscurely.

**When Retry is not offered, the panel says why.** The chain has not failed, the failed step was never declared re-runnable, you do not hold the permission, chain processing is
currently suspended, or the failure record no longer carries the context needed to resume. Each of those appears as visible text beneath the toolbar, and is wired to the action
for screen readers, rather than leaving you guessing.

## Restart a chain from the beginning

**Who it's for:** operations users and admins; developers who write chains.

Sometimes resuming is wrong and you want the whole thing to run again from step 1, with fresh data. The **Restart** action does that for a Failed *or* Aborted chain, so an
aborted chain is no longer the end of the line.

Restart never touches the original record. It creates a new chain execution record, with its own tracking ID and the original starting context, and leaves the source run exactly
as it was for audit. Both records carry a link to each other, so you can follow a run back through every restart to the one that first failed, and the link is queryable through
the `SourceExecution__c` lookup if you want to report on it.

**A chain author opts in per chain**, with one call on the builder:

```apex
kern.UTIL_AsyncChain.newChain('NightlyAccountSync')
	.then(new SyncAccountsStep())
	.allowRestart()
	.execute();
```

Without `allowRestart()`, the action stays hidden. Re-running an entire chain nobody declared restartable could double every side effect it has, so the default is off.

**Deduplication keys are honoured.** If the chain declared a deduplication key, Retry and Restart re-claim that key. When a live run still holds it, the action refuses with a
message saying so and telling you to wait for the run in flight, rather than starting a second overlapping run.

## Clear stalled chains on demand

**Who it's for:** operations users handling an incident.

The Chain Watchdog introduced in 1.6 sweeps for stalled chains on a schedule, typically hourly. During an incident, an hour is a long time. The Chain Monitor header gains a
**Clear stalled** action that runs the same sweep immediately, over up to 40 stalled chains in one pass, and reports back what it did: how many were checked, how many were
re-driven, how many were marked failed, and how many are still waiting.

"Still waiting" is not a failure. It means the platform could not yet prove the chain's background job is dead, so the framework left it alone rather than risk running the same
work twice. The next sweep looks again.

## Stop and restart all chain processing

**Who it's for:** operations users and admins during an incident.

When background processing is making a bad situation worse, you want it to stop now, org-wide, without a deployment and without hunting through configuration. The Chain
Monitor header gains **Suspend** and **Resume**, behind a dialog that spells out the impact, plus a badge that always states which way the switch currently sits.

Behind the button is a new hierarchy custom setting, `AsyncChainRuntimeSwitch__c`, with a single checkbox, `ChainsEnabled__c`. Because it is a hierarchy setting you can also set
it at the profile or user level in Setup, which is the same shape the framework already uses for the org-wide API switch. It ships ticked, so chains run.

**Abort deliberately stays available while chains are suspended.** Suspending stops new work, and you may still need to end a specific runaway chain. Retry, Restart, and Clear
stalled all refuse while processing is suspended, and say that suspension is the reason.

## Watch a chain's activity as it happens

**Who it's for:** operations users and developers watching a chain run.

The Chain Monitor's detail panel gains a live activity stream: the selected chain's log entries as they arrive, each with its timestamp, a level badge, and a short message. It
opens with the most recent 20 entries already on file and then follows along, holding the most recent 100 rows on screen.

Two honest caveats are on screen rather than buried here. First, if the live connection drops, the panel says "Live stream disconnected" instead of quietly showing a stale
list. Second, only error-level entries are guaranteed to be delivered; everything else depends on your configured logging threshold and on the platform's event delivery, so a
quiet stream is not proof that nothing happened. Successful steps do not log anything on their own.

## Who can do what: three new permission sets

**Who it's for:** admins deciding who gets which controls.

The new actions ship switched off, and the rights are split rather than bundled, because an operator you trust to re-run one chain is not automatically an operator you trust to
stop every chain in the org.

| Permission set | Label | What it grants |
|---|---|---|
| `AsyncChainRedrive` | Kern Async Chain Redrive | Retry, Restart, and Clear stalled |
| `AsyncChainKillSwitch` | Kern Async Chain Kill Switch | Suspend and Resume chain processing |
| `AsyncChainMonitorReadOnly` | Kern Async Chain Monitor Read Only | View-only access to the Chain Monitor and the chain records behind it, including a View All Records grant on chain executions, so an operator sees every chain regardless of sharing |

All three ship assigned to nobody, and the packaged Administrator permission set deliberately does **not** carry the two action permissions: granting them is a decision you make
per person, not something an install makes for you. The read-only set fills a real gap: until now, letting someone see chain records meant giving them the full Administrator
permission set, because the abort operator's set carried the abort right but no chain visibility, and the packaged read-only set did not cover chain records. Kern Async Chain
Monitor Read Only is the first view-only path to the Chain Monitor, which makes pairing it with the existing Kern Async Chain Abort set the sensible starting point for an
operations user.

Every action is checked in Apex on the server, so the button state is a convenience rather than the control. A user without the permission cannot drive the action by any route.

## The Log Console finds repeating errors on its own

**Who it's for:** admins and developers triaging errors.

The Log Console's **Problem summary** shows the problems your developers have explicitly named in code with a fingerprint. In an org where nobody had done that, the view was
empty, which is precisely the org that most needs it.

From 1.7 the console works the grouping out for itself. When you open Problem summary, it collapses ordinary log rows that share the same exception type, class and method, and
level into a single "this error, N times" row. Nothing is written, stored, or deleted to make this happen: the grouping is worked out as the list is read, so switching it off
returns you exactly to the view you had before.

**Reading the list.** Problems your developers named in code carry a **Tagged** pill and a log number; problems the console grouped for itself carry neither, and are labelled
with their newest occurrence's message, so the text you triage by is the same text you see when you open it. Rows sort by severity, worst first, and by frequency within a
severity.

**Opening a problem.** Clicking a grouped problem opens the entry that best represents it inside the range you are viewing, with a "View occurrences" link that drills into
Individual entries filtered to that problem. If every occurrence has been purged since the list loaded, the drawer says so plainly instead of erroring, and the open-latest
button is disabled with an explanation.

**Errors from your Lightning components group too.** A failure caught in a component now records the error's type alongside its message, so component failures form proper
groups in this view instead of scattering as untyped one-offs.

**Naming a problem permanently.** The drawer offers a copyable Apex snippet that turns a grouped problem into a named one, using `withFingerprint(...)` on the log builder, with
the namespace already resolved so it compiles as pasted. Naming a problem gives it a stable identity across deploys and a log number.

**Three settings on `LogSetting__c` control it**, all of them optional:

| Field | Default | What it does |
|---|---|---|
| `ProblemGroupingMinimumOccurrences__c` | `2` | How many times an error must repeat before it is listed as a problem. One-offs stay in Individual entries. |
| `ProblemGroupingLogLevels__c` | `ERROR;WARN` | Which levels may be grouped. The console's own level filter narrows within this list and can never widen it. |
| `ProblemGroupingDisabled__c` | unticked | Tick it to switch automatic grouping off entirely, leaving only the problems named in code. No deployment needed. |

**The list always says what it is showing.** A one-line status bar states whether grouping ran, is switched off in settings, is suppressed because a search term is active, is
outside the configured level scope, or declined because the range holds too much data, and it offers the single action that changes that. Blue means the view reflects a choice
somebody made, and takes you to Log Settings; amber means the list is genuinely missing problems that exist, and takes you to the in-console filters. A quiet caption states
which levels the tab covers, and an empty list explains which of three reasons it is empty for, so a narrow filter never reads as lost data.

## The Log Console at volume

**Who it's for:** admins running the console against a busy org.

Two limits used to turn a large log window into an error. Both now degrade in the open.

**Very large windows.** Grouping is a database aggregation, and above roughly **35,000 matching entries** in the selected window the platform cannot complete it. Rather than
failing the view, the console counts first, declines to group above that figure, and tells you so in the status bar, with the fix: narrow the date range, or tighten the level
scope. Problems named in code still list normally. This ceiling applies to the Problems view only; Individual entries is unaffected.

**Very large reads.** Reading past 100,000 matching rows used to fail the list outright. Paged reads now serve large sets a different way when the platform will not open a
pagination cursor, and if a list read does fail it shows its own error state rather than the misleading "No logs match these filters". That change is visible to your own code
if you use paged queries; see [What's new in the Query Builder](#whats-new-in-the-query-builder).

Elsewhere in the console: a capped result set says it was capped wherever the cap was hit, the Log Number column sorts server-side as advertised, the approximate-totals
explanation is a proper help control reachable by keyboard and touch rather than a hover-only tooltip, and the counts above Individual entries stay correct under level toggles
even though the list loads by endless scroll.

## What's new in the Query Builder

**Who it's for:** developers who write queries directly against `kern.QRY_Builder` and `kern.QRY_Condition`.

Three changes, all of them things the Log Console now relies on and your own code can use the same way.

**Paged reads work at any table size.** `QRY_Builder.getPage(pageNumber, pageSize)` previously ran out of road on very large tables. It now serves a page through whichever
mechanism the platform allows for that query, so a read past 100,000 matching rows returns a page instead of failing. Three parts of its contract are worth knowing before you
upgrade:

- **`QueryPage.cursor` can be null.** When a page is served without a pagination cursor, there is no cursor to hand back. Check for null before passing it on.
- **A page size outside 1 to 2,000 is rejected at the call**, with an `IllegalArgumentException`, because 2,000 rows is the most a cursor will return in one fetch. You get a
  clear argument error at the API boundary instead of a platform error partway through the read.
- **`kern.UTIL_Exceptions.IllegalStateException` is raised** only when a transaction has spent its cursor capacity (roughly fifty diverted paged reads in one transaction) *and*
  the requested page also sits past the 2,000-row offset a plain query can reach. Spread the paged reads across transactions, or narrow the query.

**Search boxes can match exactly what someone typed.** A `contains()` filter treats `%` and `_` as wildcards, which is right when the pattern is yours and wrong when it came
from a search box: searching for `100%` matched every value containing `100`, and searching for `UTIL_HttpClient` also matched `UTILxHttpClient`. The new `containsLiteral()`
treats `%`, `_`, and `\` as ordinary characters:

```apex
kern.QRY_Condition.OrCondition userSearch = new kern.QRY_Condition.OrCondition();
userSearch.add(new kern.QRY_Condition.FieldCondition(Account.Name).containsLiteral(searchBoxValue));
userSearch.add(new kern.QRY_Condition.FieldCondition(Account.Website).containsLiteral(searchBoxValue));
```

`contains()` is unchanged and keeps its wildcards, so nothing you have written behaves differently. One boundary is worth knowing: the escaping travels with the bound value,
which is the form every `QRY_Builder` query executes, but it is not preserved if you render the query to a SOQL string with `QRY_Builder.Builder.toSoql()` and run that string
yourself.

The Log Console's own search uses the literal form now. Its message and correlation matching is exact; its search over long message bodies still goes through the platform's word
index, which splits terms on punctuation, so that leg can still match a source name word by word.

**A count query honours `bypassSharing()`.** The setting was accepted and then ignored on the count path, so a count ran under whatever record sharing its caller happened to
have while the identical row query did not. A bypassed count could therefore return fewer rows than the query it was sizing, which is the dangerous direction when you use a
count to decide whether a query is safe to issue. Counts now run through exactly the same path as row queries.

## Steps can declare a failure permanent

**Who it's for:** developers whose steps retry.

Per-step retry arrived in 1.6. The gap it left is that retry could not tell a temporary problem from a permanent one, so a step that failed because of a validation error or a
malformed payload burned its whole retry budget re-proving the same failure. 1.7 closes that in three ways.

**A step can say "this will never work".** Return `kern.UTIL_AsyncChain.failedPermanently(message)` or `failedPermanently(exception)` from `work()` and the chain fails on that
attempt without consulting the retry strategy, whatever budget remains. A later step reading `context.getPreviousStepResult().permanentFailure` still sees `true`, because the
flag survives the hop between transactions.

**A web-service step can list the statuses worth retrying.** `ApiStep.retryOn(new Set<Integer> {500, 503})` restricts chain-level retry to those statuses; a failure carrying any
other status is treated as permanent and consumes no further budget. Never calling it keeps the released retry-any behaviour exactly as it was. A failure with no status at all,
such as a transport failure, stays retryable under every `retryOn` value, because a call that never reached the server tells you nothing about whether it would succeed.
`retryOn` has no effect unless the step also calls `withRetry(...)`.

**A step can ask whether this really is the last attempt.** The existing `isFinalAttempt()` reads the attempt budget alone. The new `isFinalAttempt(error)` overload consults the
strategy's exception filters with the exception you are about to fail with, so a last-chance side effect (releasing a lock, alerting someone) fires on the attempt that genuinely
is the last one.

Two related corrections ship with it. `isFinalAttempt()` reads `true` inside an `onError` handler for every failure that was in fact final, including a retry denied by an
exception filter while budget remained. And a failure declared permanent records its failure category as **Step Exception** regardless of attempt count, so **Retries
Exhausted** continues to mean the budget was actually consumed.

For tests, `API_MockFactory.forService(...).withTransportFailure()` simulates a call that never reaches the server, so you can prove your retry behaviour handles the no-status
case:

```apex
kern.API_MockFactory.forService('API_SendEmail').withTransportFailure().register();
```

## Recovery now reaches a chain that dies on its first step

**Who it's for:** developers running async chains; admins who keep production healthy.

1.6's recovery could only restart a chain it could prove was dead, and proving that needs the ID of the background job carrying it. Until now that ID was written on the first
progress update, which meant a chain that died before finishing its first step, and every single-step chain, could be marked Stalled but never restarted automatically.

The job ID is now stamped when the chain starts, in the same transaction, so recovery can prove death and re-drive from the first hop onward. The field is populated earlier than
before and stays populated after the run ends, so anything reporting on it sees a value sooner. Recovery also refreshes the ID when it re-drives, so the record shows the job
actually carrying the work rather than its dead predecessor.

## New in the Apex API

**Who it's for:** developers writing against the framework.

Ten new global members, grouped by the problem each one solves. Nothing was removed or changed, so none of this affects code you have already written.

### Spending retry budget only where retrying helps

Before 1.7 a retrying step treated every failure the same way. A validation error and a temporary lock both consumed the same budget, and the only way to stop that was to switch
retry off for the whole step.

**`global static StepResult failedPermanently(String message)`**
**`global static StepResult failedPermanently(Exception error)`** on `UTIL_AsyncChain`

Return one of these from `work()` and the chain fails on that attempt without consulting the retry strategy, however much budget is left. Use it the moment your step knows the
input is wrong rather than the system is busy.

```apex
if(String.isBlank(payload.accountNumber))
{
	return kern.UTIL_AsyncChain.failedPermanently('No account number on the payload; retrying cannot fix this.');
}
```

**`global Boolean permanentFailure {get; private set;}`** on `UTIL_AsyncChain.StepResult`

Lets a later step see that decision. It is never null, reads `false` on every result except one built by `failedPermanently()`, and survives the hop between transactions, so
`context.getPreviousStepResult().permanentFailure` still reads `true` in the next step.

**`global ApiStep retryOn(Set<Integer> statusCodes)`** on `UTIL_AsyncChain.ApiStep`

For a step that calls a web service, this is the same idea expressed as a list: retry these HTTP statuses and treat everything else as permanent. A 503 is worth another attempt,
a 400 never will be. Passing an empty set means no status-bearing failure retries; never calling it leaves the released retry-any behaviour untouched. It needs `withRetry(...)`
on the same step to do anything, and a failure with no status at all stays retryable whatever you list.

```apex
new kern.UTIL_AsyncChain.ApiStep(API_ChargePayment.class)
	.withRetry(3, 30)
	.retryOn(new Set<Integer> {500, 503});
```

**`global Boolean isFinalAttempt(Exception error)`** on `UTIL_AsyncChain.ChainContext`

The existing zero-argument `isFinalAttempt()` counts attempts, so it cannot know that the exception in your hand is one your filters will refuse to retry. This overload consults
those filters with the actual exception, which is what you want before firing a last-chance side effect such as releasing a lock or alerting someone.

```apex
catch(Exception caught)
{
	if(context.isFinalAttempt(caught)) { releaseLock(); }
	return kern.UTIL_AsyncChain.failed(caught);
}
```

### Letting an operator re-run your chain safely

Re-running someone else's chain is only safe if its author said so. Two declarations carry that consent from the code to the Chain Monitor, and both default to off.

**`global virtual Boolean isIdempotent()`** on `UTIL_AsyncChain.ChainStep`

Override it and return `true` to declare that this step is safe to run a second time. That is what puts the Retry action in front of an operator when the chain fails on this
step. Leave it alone and the action stays hidden, so a step that charges a card is never replayed by someone who could not know better.

**`global ChainBuilder allowRestart()`** on `UTIL_AsyncChain.ChainBuilder`

One call at build time declares the whole chain safe to run again from step 1, which is what enables the Restart action. It also tells the framework to keep the chain's starting
context, so the new run begins with the data the original had.

### Giving a separate run its own logging identity

**`global static String serializeContext(String correlationId)`** on `LOG_Builder`

The existing zero-argument `serializeContext()` captures the transaction you are in. This overload builds a minimal logging context for a correlation ID you supply, for handing
a *different* execution its own identity without touching the live one. It is what lets a restarted chain start a clean trace instead of inheriting the failed run's, and you can
use it the same way whenever you hand work to something that should be traceable in its own right.

```apex
String cloneLogContext = kern.LOG_Builder.serializeContext(cloneCorrelationId);
```

### Searching for exactly what someone typed

**`global virtual FieldCondition containsLiteral(String compareValue)`** on `QRY_Condition.FieldCondition`

`contains()` treats `%` and `_` as wildcards, so text taken straight from a search box could match far more than the user meant. `containsLiteral()` matches character for
character. Full explanation and its one boundary are in [What's new in the Query Builder](#whats-new-in-the-query-builder).

```apex
new kern.QRY_Condition.FieldCondition(Account.Name).containsLiteral(searchBoxValue)
```

### Testing a call that never reaches the server

**`global MockBuilder withTransportFailure()`** on `API_MockFactory.MockBuilder`

Mocking used to mean choosing a status code, so there was no way to rehearse the case where the call never arrives and no status exists at all. This registers exactly that: the
callout throws instead of responding. It is the case that proves your retry logic behaves when there is nothing to inspect, and any body, status, or headers on the same
registration are ignored.

```apex
kern.API_MockFactory.forService('API_SendEmail').withTransportFailure().register();
```

## Easier to use with assistive technology

**Who it's for:** orgs with accessibility requirements, and anyone working by keyboard or screen reader.

- **A greyed-out action tells you why it is greyed out.** Every unavailable Chain Monitor action states its reason in visible text beneath the toolbar, and the reason is wired
  to the button for screen readers. A disabled button cannot be focused, so the visible note is the path that always works.
- **The action toolbar is a named group**, so a screen reader announces the chain's actions as a set rather than a run of loose buttons.
- **Escape closes the Log Console drawer from anywhere in the console**, and focus returns to the list you were reading rather than to the top of the page. An Escape a child
  control has already handled, such as a combobox closing its own dropdown, is left alone.
- **Kern Home has a real heading outline.** Tool tiles are third-level headings under the page heading, so heading-based navigation walks the page in order.
- **Every tool tile's button has its own name.** Five buttons still read "Open" on screen, but each now carries the tool's title in the name a screen reader announces, so the
  list of buttons is usable.
- **Tool names wrap instead of truncating**, so a longer name stays readable at 1024, 1280, and 1600 pixels wide.
- **The Health Check's passing-checks list is labelled**, so its chips are announced as the passing set rather than as loose text.
- **Small text meets the contrast floor.** The Log Console's filter-group label was below the 4.5:1 minimum for small text and now clears it.
- **The approximate-totals explanation is reachable without a mouse**, as a standard help control rather than a hover-only tooltip.

## Built to stay responsive as your data grows

**Who it's for:** admins and developers running the framework against large volumes.

The design rule through this release: when a screen cannot do the whole job at your data volume, it says what it can still tell you and how to get the rest, rather than
failing.

- **Paged reads no longer hit a table-size ceiling.** `QRY_Builder.getPage` serves a page whichever way the platform allows for that query, so large tables read normally. See
  [What's new in the Query Builder](#whats-new-in-the-query-builder) for the contract.
- **Grouping measures before it runs.** The Problems view counts the rows it would need to scan with one cheap count, and declines above roughly 35,000, because the failure it
  would otherwise hit cannot be caught and takes the whole view down with it. Declining costs one count; not declining cost you the screen.
- **The counts above Individual entries decline honestly.** Above roughly 22,000 entries in the window, the ribbon skips the breakdown by level and source and still shows the
  exact total its pre-flight count measured, rather than either guessing or failing.
- **A capped list says it was capped**, wherever the cap was reached, instead of quietly returning a short list.
- **A deep link loads once.** Arriving by deep link used to issue two full loads because the page-reference wire fires before the component mounts. It now makes two controller
  calls where it used to make four.
- **The list appends as you scroll** rather than re-reading the window, and refreshing returns you to the first page so a deeply-scrolled list does not collapse to its last
  slice.

## Four proven ways to compose chains

**Who it's for:** developers designing chains for real workloads.

The Async Processing Guide gains four worked patterns, each proved end to end in a real org rather than sketched:

- **Calling an external system only after the transaction commits**, so you never tell an outside system about a record that then rolls back.
- **Pausing for an approval**, as two chains with a hand-off anchored to the record, which is the shape that works when a human step sits in the middle.
- **Protecting a struggling integration with a circuit breaker**, so repeated failures stop hammering a system that is already down.
- **Running a chain on a schedule**, as a recurring scheduled chain.

Two code fixes came out of proving them, both in [Smaller fixes](#smaller-fixes): a chain step calling one of your own web-service handlers no longer fails at the background hop,
and a chain step's own class-recreation rule is now stated where you hit it.

## Smaller fixes

**Async chains**

- **A chain step can call your own web-service handler.** A step wrapping an `API_Outbound` handler from your namespace survived being added to the chain but died at the
  background hop with "Handler class not found", because the class was looked up inside the framework's namespace only. Handlers in your own namespace now resolve correctly.
- **Scheduled clean-up no longer deletes live chains.** The Health Check's one-click data-retention fix for chain execution records passed no date field, so the purge aged
  records on their created date and deleted Stalled and even Running chains at 90 days, destroying the state recovery depends on. It now ages them on the completion timestamp,
  so only finished chains are ever purged.
- **A chain that fails with an oversized context stores no context at all** and appends a note to its error message saying that retry from the failed step is unavailable,
  instead of persisting truncated, unreadable data.
- **A first-step delay no longer discards custom async options**, and the framework's default queueable stack depth now applies to the first step of a chain that specifies no
  options. The delay is still limited to 0 to 10 minutes and still applies to the first step only.
- **Every Chain Monitor action, including the existing Abort, guards against a double click**: the button disables on confirm and re-enables when the server responds.
- **The chain list says what it is showing when it is empty**, distinguishing "no chains at all" from "none in this status".

**Logging**

- **Logging from a post-trigger action inside platform-event processing no longer throws.** An error-level entry (or one that crossed the buffer cap) written from a post-action
  in that context tripped the framework's own no-DML guard, from the exact pattern the shipped example teaches. The guard now discounts the logging framework's own writes; a
  post-action's own DML still trips it, as intended.
- **A failing post-trigger action no longer poisons the rest of the transaction.** When a post-action threw inside platform-event processing, the framework skipped its own
  teardown, leaving buffered entries unflushed for the remainder of the transaction. Teardown now always runs. The action's exception is still raised, so a platform-event
  subscriber trigger still fails delivery and the platform's retry behaviour applies.
- **Grouping keys are tidied where the stored key is built**, so a key with stray edge whitespace or one longer than the field allows is normalised at the point of storage
  rather than silently failing to group.
- **Grouped logging survives a database-level clash.** If two processes record the same grouping key at the same moment, or a key the database cannot store, only the affected
  row is involved and the rest of the batch still lands. Anything that cannot be filed under its key is kept as an ordinary entry, its occurrences are added to the entry already
  on file, and one warning entry beginning "flood-control fallback:" records what happened and why.
- **An error caught by a component's error boundary logs its own words.** The entry reads `Component error: <the error's message>` rather than a bare phrase with the real
  message reachable only through the context data, and it records the error's type and the component it came from.
- **Bypass-audit summary rows name their surface.** A clear-all row reads `CLEAR_ALL ALL (trigger-object)` or `(trigger-action)` rather than two identical rows. Detail rows
  written before the upgrade keep their old wording until they age out.

**Data masking**

- **A wildcard masking target no longer rewrites unique keys and external IDs.** A masking target that names no specific field now skips text fields marked unique or external
  ID, so a card-shaped correlation ID or idempotency key is never redacted into a duplicate-value failure. This narrows what a wildcard target covers; see
  [Upgrading & compatibility](#upgrading--compatibility).

**Chain Monitor and Log Console interface**

- **Operator actions sit on their own row** under the chain name, so the buttons no longer overlap or clip at 1280 and 1024 pixels.
- **The Timing card tells the truth about a run that stopped short.** It shows active run time beside elapsed duration, reads Aborted, Failed, or Stalled rather than Completed,
  and says how many steps ran. Restart lineage shows the whole source ID, correlation IDs no longer clip, and the live activity says "retried" for an operator retry rather than
  repeating itself.
- **The stack-trace tab names the class, method, and line** an entry came from when it has no trace, so an entry logged without an exception still tells you where to look.
- **Every relative time carries its exact instant**, the Context cell shows display labels, the timeline states that it shows every level regardless of your filter, the Context
  empty state speaks plainly, and "Open Log Settings" lands on the Log Settings page. Chain log stream times are correct.
- **The source filter filters everywhere.** After "View occurrences" pins a problem's source, switching back to Problem summary narrows the problem list and the counts above it
  to that source.
- **A deep link into the console** clears a stale search term and context filter, returns to page one on refresh, and accepts seconds in a custom range.
- **Scheduled Job record pages render.** Opening a Scheduled Job record page threw a component error on every view, and logged two error entries each time. The page's detail
  card now orders its layout sizing so the platform's size validation passes.

**Testing framework**

- **Generated mock record IDs no longer collide.** The mock ID provider drew from a four-character random suffix, which collides at realistic build volumes (measured at ten
  duplicates in twenty thousand generated IDs). The provider now re-rolls against the IDs already issued in the transaction.
- **A registered default-value provider is no longer replaced behind your back.** The test factory's initialiser could silently replace whatever provider you had registered on
  the documented extension point, depending on class load order. See [Upgrading & compatibility](#upgrading--compatibility) if you subclass the provider.

## How this release was tested

**Who it's for:** anyone who needs to know what stands behind the release before installing it.

Every release goes through a two-leg subscriber cycle in real Salesforce orgs: a **fresh install** into a clean org, and an **upgrade** from the previously released version, so
that both the first-time and the existing-customer paths are proved on the same build.

Alongside the Apex test suite, the framework ships with a browser-driven end-to-end suite written in Playwright that drives the packaged screens the way a person would. For 1.7
it grew from 12 spec files to **13**, and from 83 to **103 automated checks** across the ten release-verification specs, with the growth concentrated on the Chain Monitor and
Log Console screens. The remaining three spec files sit outside that count: two capture the documentation screenshots, and one checks the Log Console's shipped screens against
the agreed design.

## Documentation

**Who it's for:** everyone who reads the guides, and any AI coding assistant you point at KernDX.

- **The Async Processing Guide covers the operator actions end to end**: re-driving a failed chain, restarting one from the start, clearing stalled chains, the operations
  control, the live activity stream, and the four composition patterns above, each with the conditions under which it is offered.
- **An exception filter applies to a failure your step returns, not only one it throws.** A `failed(exception)` result is filtered exactly as a thrown exception is, so a step
  that returns its failures gets the same retry decisions as one that throws them, and the guides show it that way throughout. (Earlier editions said filters applied only to
  thrown exceptions.)
- **The Web Services Guide shows how to handle a 401 from a background job.** Calling back into your own org with `API_CallCurrentOrg` signs the call with the current user's
  session, and a queueable, scheduled job, batch, or chain step has none, so the call returns HTTP 401 every time. The guide gives the Named Credential route instead, and shows
  why retry cannot heal it: the 401 arrives as an ordinary response with no exception attached, so keep 401 out of your `retryOn(...)` set, or leave `withRetry` off for that
  step, and check the service's own `ApiSetting` retry configuration as well.
- **The guides point only at the API surface you can call.** A build check fails the documentation build when a guide writes a `kern.`-qualified class name that has no reference
  page behind it, which is the signal that your org cannot call it. The check reads class names, not their methods or properties, so this release's examples were hand-verified
  as well.
- **The documentation site is faster and fully accessible**, scoring 100 on accessibility, with an audit we run before each release to keep it there: diagram support loads only
  on pages that have a diagram, walkthrough recordings no longer download during first paint, and each header carries one sidebar control rather than two.
- **The generated API reference covers the new surface**, including the new custom setting, the new fields, and the ten new global members.

## Known issues

- **Installing 1.6.0-3 fresh can fail; install 1.7 instead.** To keep a standard button off the chain-execution page, the 1.6.0-3 page layout named that button (`SmartFillEnrich`)
  in order to exclude it. An org that does not have the button rejects a layout that names it at all, so a *fresh* install of 1.6.0-3 fails there with an error naming the action.
  1.7 no longer names it, so install 1.7 or later rather than 1.6.0-3. Orgs already running 1.6.0-3 are unaffected: they could only have installed where the button exists, and
  they upgrade normally.
- **A deep link into a still-running chain freezes the end of its log window** at the moment the link was followed, and Refresh keeps that bound, so entries written afterwards
  need the range widening by hand. The bounds are visible and editable in the custom-range inputs.
- **A chain that stalls and is never aborted is never purged.** The retention job ages chain records on their completion timestamp, and only a terminal outcome (including
  abort) sets it. This is deliberate: it protects the recovery state of a chain that may still be resumable. Abort a permanently stalled chain if you want it cleaned up.

## Upgrading & compatibility

1.7 is a **backward-compatible** release. Upgrading from 1.6 is the standard package upgrade with no migration steps, and chains in flight during the upgrade complete normally.
The platform baseline is unchanged (Summer '26, API 67.0).

**The global Apex surface is purely additive.** No existing global member is removed or changed in signature. The ten additions, with what each is for, are in
[New in the Apex API](#new-in-the-apex-api): five that make retry spend its budget only where retrying helps (`failedPermanently` in two forms, `StepResult.permanentFailure`,
`ApiStep.retryOn`, `ChainContext.isFinalAttempt(Exception)`), two that let an operator re-run your chain safely (`ChainStep.isIdempotent()`, `ChainBuilder.allowRestart()`),
`LOG_Builder.serializeContext(String)`, `QRY_Condition.FieldCondition.containsLiteral(String)`, and `API_MockFactory.MockBuilder.withTransportFailure()`.

**The metadata surface is additive.** Four new fields on `AsyncChainExecution__c` (`AllowRestart__c`, `DeclaredDeduplicationKey__c`, `InitialContextData__c`,
`SourceExecution__c`), three new settings on `LogSetting__c` (`ProblemGroupingDisabled__c`, `ProblemGroupingLogLevels__c`, `ProblemGroupingMinimumOccurrences__c`), the new
`AsyncChainRuntimeSwitch__c` hierarchy custom setting with its `ChainsEnabled__c` checkbox, two new custom permissions, three new permission sets (all assigned to nobody), five
new configuration records, and a set of new Custom Labels. Nothing is removed or renamed. The packaged chain-execution layout and record page surface the four new fields as
read-only.

**Behaviour changes to note on upgrade** (deliberate, reviewed):

- **The org-wide chain switch moves to a custom setting. Check the `AsyncChain` feature-flag record before you upgrade.** Chain processing is now driven by
  `AsyncChainRuntimeSwitch__c.ChainsEnabled__c`, through a new strategy attached to the existing `AsyncChain` feature flag. **An org that never edited that flag record is
  unaffected**: with no setting record present, the flag resolves exactly as it does today and chains run. **An org that did edit it can change behaviour on upgrade.** If you
  set the flag's *result when nothing matches* to false, chains stop running after the upgrade until you write the hierarchy setting. If you set its *enabled by default* to
  false in order to stop chains, that stop inverts and your chains start running again. Only deactivating the flag outright is unaffected. If either applies to you, decide
  before upgrading which state you want, and use the new Suspend control (or the custom setting directly) as the supported way to stop chains from now on.
- **Asynchronous DML honours your access-mode and sharing choices end-to-end.** A `kern.DML_Builder` chain ending in `.async()` used to lose the access mode you set on it
  when the background job started, so the job fell back to whatever the `UserModeDml_Enabled` feature flag decided. With the flag on (the shipped default), a
  `.withSystemMode()` async write (system mode skips the current user's permission checks) was wrongly rejected as a permissions failure, even when you asked for
  `.bypassSharing()`. With the flag off, the same write silently skipped record sharing you never asked to skip. After this upgrade, the choices you set are the choices the
  job runs with: a system-mode async write runs with record sharing enforced by default, and `.bypassSharing()` is the explicit opt-out, now carried across to the job. If
  your org relied on the old behaviour in either direction, review your async `.withSystemMode()` writes before upgrading: writes that were being rejected can start succeeding
  (with record sharing enforced), and writes that were skipping record sharing stop doing so unless the chain calls `.bypassSharing()`. The scheduled record purge
  (`kern.UTIL_PurgeRecords`) runs through the same processor and is unaffected: it never asks for a sharing bypass, so its behaviour is unchanged.
- **Reusing a correlation ID across chains now raises a different exception.** When one transaction starts several chains under a single log correlation, only the first is
  recorded under it; the others each get a correlation of their own, and the framework logs one entry under your original correlation naming the new ID. Deliberately reusing a
  correlation ID that another chain already holds now raises `kern.UTIL_Exceptions.IllegalStateException`, naming the ID, the holder where known, and the fix. It previously
  surfaced a `DmlException`, so **code that catches `DmlException` around a chain launch for this case will no longer catch it.**
- **Wildcard masking targets narrow.** A masking target that names no specific field no longer rewrites text fields marked unique or external ID. If you rely on a
  wildcard target of your own to mask an identifier field, that field stops being masked on upgrade; add an explicit target naming the field to restore it on purpose.
- **Paged queries can return a null cursor, and reject an out-of-range page size.** `QRY_Builder.getPage(...)` serves some pages without a pagination cursor, so
  `QueryPage.cursor` can be null; check for null before passing it back. A requested page size outside 1 to 2,000 is now rejected at the call with an `IllegalArgumentException`
  rather than failing partway through the read, and `kern.UTIL_Exceptions.IllegalStateException` is raised when a transaction has spent its cursor capacity and the requested
  page also sits past the 2,000-row offset a plain query can reach.
- **Call `super.defineSObjectOptionalFields` if you subclass the test-data default provider.** A `UTIL_SObjectBuilderDefaultProvider` subclass that overrides
  `defineSObjectOptionalFields` *without* calling `super` previously inherited the framework's User permission-field handling by accident, in one particular class load order.
  It now behaves exactly as written, in every order. If your override does not call `super`, add the call to keep User records buildable without licence-related failures.
- **An unhandled stall now logs at error level rather than warning.** A chain that genuinely transitions to Stalled with no error handler registered emits one entry at error
  level instead of warning. It is an elevation of the existing entry, never a second one, and every other stall path keeps its warning. **Orgs that page on error-level entries
  should review their filters.**
- **The logging framework's background persistence runs with the sharing of the code that logged it**, rather than defaulting to full system access. This is a tightening, so
  nothing gains access it did not have.
- **Count queries honour `bypassSharing()`**, where the setting was previously accepted and ignored. Nothing in the framework paired a sharing bypass with a count, so this
  changes nothing unless your own code does.
- **The Chain Monitor's "View logs" link opens the chain's own run window**, with a one-minute margin either side, instead of the previous flat 30-day view. When no bounds are
  available it falls back to the old behaviour.
- **A permanently-declared failure records Step Exception**, not Retries Exhausted, so that category continues to mean the retry budget was genuinely consumed. This is reachable
  only through the new surface, so no existing chain's recorded category changes.
- **Three Health Check rows are named differently.** "Organisation Cache" is now **Org Cache**, which is the name Setup itself uses. Two more changed only in capitalisation:
  "Masking configuration" is now **Masking Configuration**, and "Masking coverage (custom objects)" is now **Masking Coverage (Custom Objects)**. If you have scripts, reports,
  or runbooks that match check names exactly, update them.
- **Some existing Custom Label wording improved.** A number of released labels had their English text corrected or clarified, with their placeholder counts unchanged. If your
  org has translated them, those translations keep working and keep displaying, but show the older wording until you re-translate.

**A standing note about configuration-record help text.** Guidance text carried on the shipped `FeatureFlagStrategy__mdt` records belongs to your org once installed, so a
correction made in a later release does not reach an org that already has those records. The current explanation always lives in the
[Feature Flags guide](../docs/Feature%20Flags%20-%20Guide.md); treat that as authoritative when it differs from the text on the record in your org.

**Two optional post-install steps activate the new operational capabilities:** assign the Kern Async Chain Redrive permission set to the people who should re-run chains, and
the Kern Async Chain Kill Switch set to the smaller group who should be able to stop chain processing org-wide. Neither is required for the upgrade itself; until you assign
them, the new actions stay hidden. Pair either with the new Kern Async Chain Monitor Read Only set for operations users who need to watch chains without changing them.

**Choose Install for Admins Only when installing or upgrading**, as in 1.6. Installing for All Users writes packaged custom permissions into every profile, which silently grants
capabilities you meant to hand out deliberately.

Everything in the [Kern 1.6 Release Notes](./Release%20Notes%20-%20Kern%201.6.md) and earlier still applies; 1.7 changes only what is on this page.
