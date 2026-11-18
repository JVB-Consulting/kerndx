---
navOrder: 16
---

# KernDX - Choosing a Framework

> A capability-by-capability guide to choosing between KernDX and the Salesforce Apex frameworks it is most often compared against: the established [`fflib`](https://github.com/apex-enterprise-patterns/fflib-apex-common), [`taf`](https://github.com/mitchspano/trigger-actions-framework), [`rflib`](https://github.com/j-fischer/rflib), [`nebula-logger`](https://github.com/jongpie/NebulaLogger), [`apex-libra`](https://github.com/pkozuchowski/Apex-Opensource-Library),
> the [Apex Fluently libraries](https://github.com/beyond-the-cloud-dev), the newer foundation library [`sf-bedrock`](https://github.com/force-creators/sf-bedrock), and others. Written by the KernDX team. Every claim about another framework is checkable against its public
> source.

- **What this is:** a side-by-side comparison of KernDX against the Apex frameworks teams most often already use or ask about, judged on the things that actually drive a production decision.
- **Why it exists:** picking a framework is a long-term commitment. The differences that matter (what each one does by default, how much it covers, what you have to wire together yourself) are easy to miss when you choose on familiarity alone.
- **Who should read it:** architects and tech leads making the call, plus the delivery managers and executives who sign off on it.
- **When to use it:** when your team is asking "why KernDX instead of the framework we already know?"

Where another framework is the better fit, this guide says so plainly.

## Table of contents

- [How to use this guide](#how-to-use-this-guide)
- [What actually separates these frameworks](#what-actually-separates-these-frameworks)
- [Pick by capability](#pick-by-capability)
- [The integration trade-off](#the-integration-trade-off)
- [Head-to-head](#head-to-head)
    - [vs. fflib](#vs-fflib)
    - [vs. taf](#vs-taf)
    - [vs. apex-libra](#vs-apex-libra)
    - [vs. rflib](#vs-rflib)
    - [vs. nebula-logger](#vs-nebula-logger)
    - [vs. the Apex Fluently libraries](#vs-the-apex-fluently-libraries)
    - [vs. fflib-mocks](#vs-fflib-mocks)
    - [vs. sf-bedrock](#vs-sf-bedrock)
- [Other frameworks](#other-frameworks)
- [Organisational fit](#organisational-fit)
- [Spotted something wrong?](#spotted-something-wrong)

---

## How to use this guide

If your team is asking *"why KernDX instead of the framework we already know?"*, or weighing a newer arrival such as `sf-bedrock`, this is the answer. Here is the fastest route through it:

- Start with [What actually separates these frameworks](#what-actually-separates-these-frameworks) for the differences that matter most.
- Use [Pick by capability](#pick-by-capability) to find the right tool for a specific need.
- Read the [head-to-head](#head-to-head) section for whichever framework you're weighing.
- Check [Organisational fit](#organisational-fit) for when KernDX is the right call, and when it isn't.

Two honest notes up front, stated once:

- **Licensing.** KernDX is open source under the Apache License 2.0, a licence approved by the Open Source Initiative (OSI). You can read, change, and deploy the source, and
  use it for anything, including inside products you sell.
- **Maintainer model.** KernDX is currently maintained by a single primary developer, with an issues-only contribution model. One maintainer carrying most of the work is common across the Apex
  ecosystem rather than unique to KernDX. The `fflib` family is among the few examples of genuinely distributed maintainership.

Both are covered in depth in [Risks](Strategic%20Guide%20-%20Risks.md). They are not repeated throughout this guide.

This guide names other frameworks because you cannot make a real choice without naming the alternatives. Where another framework is the better fit for a need, it says so plainly.
Every comparison is a present-tense fact about each framework's published source, which you can verify yourself. Frameworks evolve, so treat this as a snapshot and check the
current source if your decision depends on a detail. Where this guide says no alternative does something, that is scoped to the frameworks compared here, not a claim about
the entire Apex ecosystem.

This guide compares frameworks on the dimensions that drive a real production decision:

- **what each does by default for security**
- **how much it covers**
- **how much wiring you have to do yourself**
- **how extensible it is**
- **its testing tooling**
- **what it lets you see in production**
- **how sustainably it is maintained**
- **its licensing**

**Comparison baseline:** each framework's published source as of November 2026. Two of them are recent arrivals whose repositories only began in June 2026 (`sf-bedrock` and `revenant`), so there is less published history behind their entries than behind the rest.

---

## What actually separates these frameworks

Apex frameworks are not interchangeable, and the differences that matter most are not syntax preferences. They are what the framework does *by default* when a developer is moving fast
under a deadline. Three differences do most of the separating.

### Security defaults

This is one of the biggest differences, and the easiest to underestimate when picking on familiarity alone. The question it answers: when a developer writes a query or a save under time pressure, does data security get enforced for them, or do they have to remember to ask for it?

KernDX enforces field- and object-level security on every read and write by default (FLS = field-level security; CRUD = object create/read/update/delete permissions). Every read and write runs with the current user's permissions and record sharing enforced (USER_MODE) unless a call explicitly opts out.

Each opt-out made through the builders, triggers and validation rules writes an audit log entry, as do the three lower-level save methods named below. So a bypass made during a top-priority (`P1`) production incident and an accidental bypass inside a loop can both be traced. Bypass entries are saved at every log level (`LogLevelThreshold__c`), so an org that logs only errors in production still keeps them, as long as logging is on. The benefit: security is the default outcome rather than something each developer has to remember.

Most alternatives instead leave access control to the developer on each call and run in standard execution contexts that keep no audit trail. Three are partial exceptions: SOQL Lib (`apex-fluently-soql`) runs reads with the user's permissions by default, DML Lib (`apex-fluently-dml`) does the same for writes, and `rflib` checks permissions on reads (not writes) by default. None of them records it when a call opts out. A fourth, ApexKit, comes last in this list. How the others compare:

- **`fflib`** selectors check object read access by default; field permissions, sharing and writes are not checked by default on its Query/DML classes. Beyond that, access mode is the developer's responsibility per call (its query factory accepts an access level per call), and `SimpleDML` writes run without FLS/CRUD.
- **`apex-libra`** defaults to *system mode* on DML writes, so you must override per call to get FLS/CRUD enforcement on writes.
- **`sf-bedrock`** ships no permission enforcement in its packaged library: reads run through `Database.query` and writes through bare DML statements, with no user-mode option anywhere in the packaged directory.
- **`taf`, the other Apex Fluently libraries, `fflib`, and most others** rely on standard platform execution contexts. In all of them, and in the partial exceptions above, elevated access leaves no automated audit trail.
- **ApexKit** is the fourth partial exception, and on one path it is stricter: its `Safely` write path checks object permissions and strips fields the user cannot edit before every write, and that check cannot be switched off. Its other write path checks by default, but its system-mode methods leave no record, and some of its reads (`getQueryLocator`, aggregate queries, SOSL) skip the check without saying so. So the check is strict where it applies, but stepping outside it means using a path that leaves no record.

In KernDX, each opt-out made through the builders, triggers and validation rules writes an audit entry. So do the three lower-level save methods your code can call directly:

- `DML_Transaction.setAccessLevel(AccessLevel.SYSTEM_MODE)`
- `DML_Transaction.commitWork(false)`
- `PROC_ExecuteDML` built with `AccessLevel.SYSTEM_MODE`

The practical difference is the audit record: a missed or deliberate elevation in those libraries leaves no record, whereas KernDX logs it. So you depend less on every developer applying access control consistently. All of this is checkable in each framework's source.

This is not a claim that explicit access control is wrong. Some enterprise architectures deliberately centralise elevated access inside controlled service boundaries, which is a
legitimate pattern. The difference is the *default*: KernDX enforces security up front and makes each elevation through the builders, triggers and validation rules an audited, per-call decision, rather than relying on each
developer to opt in.

### One deployment, opt-in at runtime

A common worry about any bundled framework is that installing it takes over your org. With KernDX it doesn't. KernDX installs as a single managed package, but it is **dormant by default**. Installing it adds the toolset to your org without attaching to your objects, changing your existing
triggers, or running on your transactions. Each capability activates only when you wire it in: a trigger-registration record, a builder call, a feature flag. You can adopt the
outbound-HTTP tools today and leave your existing `fflib` domains or hand-rolled triggers completely untouched.

So the usual "monolith" objection mostly dissolves. KernDX is **one deployment footprint with a modular runtime footprint**: a suite of tools available in your org, not a
framework that takes over your org.

One honest caveat: the managed package's install footprint and dependency are real whether or not a capability is active. What stays dormant is
the runtime behaviour, not the on-org footprint. That footprint is inert code: when you install the managed package, it does not count against your 6 MB Apex limit and is not copied into your org as your own source. The flip side of bundling is covered in [The integration trade-off](#the-integration-trade-off) below.

### Quality discipline

When you adopt a framework, you also inherit how well it is tested and documented, because that determines how much safety net you get for free and how much you have to build yourself.

KernDX enforces **100% per-file Apex coverage and 95% LWC statement/branch coverage at every release build** (LWC = Lightning web components), ships ApexDoc on every class and method, and is clean against shipped
PMD and ESLint rulesets. How much testing and static analysis (checking code without running it) the alternatives apply varies widely.

None of this guarantees a framework is bug-free: coverage targets
improve resistance to regressions, but they are not a proxy for whether the behaviour is actually correct. What they tell you is how much regression safety net you inherit and how much you'll be adding
yourself.

---

## Pick by capability

Got a specific need? This is the fast lookup. The "Consider an alternative when…" column names the cases where another framework genuinely fits better, so you can see at a glance where KernDX is the right answer and where it isn't.

| Capability                     | KernDX gives you                                                                                                                                                                                                                                                                                                                 | Consider an alternative when                                                                                                                    |
|--------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------|
| **Trigger framework**          | Configuration-driven registration, four-level bypass (per-object / per-action / per-flow / framework-wide) with an audit log entry when code turns a bypass on (the metadata switch is recorded by Setup Audit Trail, not by KernDX's bypass record), automatic recursion control, a stable action order (actions that share an order value always run in the same sequence), a searchable record of what each trigger actually did, reacting to record-change events (Change Data Capture, with the change header available to Flow and Apex actions), and follow-up work that runs after the transaction commits (post-trigger finalizers) | `taf` has one piece KernDX lacks: its Flow trigger actions can take a typed collection input, where KernDX runs Flow actions one record at a time because of a platform limit (see [Risks: Potential Drawbacks](Strategic%20Guide%20-%20Risks.md#potential-drawbacks)). That is not a reason to choose `taf`: KernDX covers everything else it does, and more. For a team already on `taf`, moving means porting each action class and its registration to a KernDX record; staying keeps trigger bypasses that leave no record |
| **Query builder**              | A SOQL query API you set up with short chained calls, with no string concatenation, FLS/CRUD enforced by default, an audit log entry when a call opts out, a subclassable builder, and query-result caching that keeps users apart (the cache key carries the sharing setting and, for reads that enforce sharing, the running user, so one user's cached rows are never handed to another)                                                                                                                                                                       | `apex-fluently-soql` has a few pieces KernDX lacks, such as condition logic written as text (`'1 OR (2 AND 3)'`); none is a reason to choose it. Deployed as source, it has no namespace prefix (its package uses the `btcdev` namespace); KernDX has its other features (semi-joins, cursor paging, ROLLUP/CUBE). Both run reads with the user's permissions by default; only KernDX records it when a call opts out. Already using it? Moving means rewriting queries; staying means an opt-out from permission checks leaves no record. Installed as the managed package, KernDX's code does not count against your 6 MB Apex limit |
| **DML**                        | Transactional batching, FLS/CRUD enforced on writes by default, audited bypass, async DML, and saves related records in the right multi-level order (parents before children), catching impossible loops | `apex-fluently-dml` when your unit tests must fake record writes (`DML.mock`), which KernDX does not ship. Both save multi-level record graphs in the right order; its record-builder syntax is a difference in shape, not depth. It writes with the user's permissions by default, but an opt-out leaves no record, and it has no async DML |
| **Inbound REST**               | A two-class routing pattern that keeps REST plumbing out of business logic, small response classes that convert themselves to and from JSON (DTO marshalling), validation hooks, and a paired test harness                                                                                                                        | No alternative covers all of this among those compared. [`sf-bedrock`](https://github.com/force-creators/sf-bedrock) ships the routing layer at a basic level (a configuration-driven gateway, with no DTO layer, no validation hooks, no call record, and no paired test harness), so beyond basic routing you still hand-roll the rest per endpoint, or adopt KernDX |
| **Outbound HTTP**              | Production callouts with retry/backoff, a circuit breaker (after repeated failures it stops calling the failing system for a cool-off, then resumes), idempotency keys (the same request arriving twice returns the first result instead of re-running), a dead-letter queue (messages that fail after all retries are set aside for inspection, not lost), named-credential resolution, and a mock library | None of the other libraries compared ships production callouts with retry, a circuit breaker, idempotency keys and a dead-letter queue. ApexKit ships a basic REST client, a step below KernDX's; `rflib` and `apex-libra` ship a basic callout class (`apex-libra` also basic retry). `revenant` has retry, a circuit breaker, idempotency and a dead-letter queue for its own workflow steps (the last two as complete as KernDX's), but no HTTP client. Its queue that releases work only after your transaction commits is credited in the Async row |
| **Logging**                    | A lean Apex/LWC/Flow logging API that writes log records in the background by default, integrated with triggers/query/DML/async, plus the Log Console: past entries filtered by level, context and date range, searched by text, recurring problems grouped with occurrence counts, and a drilldown that walks one operation across every trigger, job and callout it touched | `nebula-logger` if you need to choose how each log is saved (event bus, queueable, REST or synchronous DML), all seven platform log levels, a retention date per log entry or per scenario, or archiving old entries to a Big Object for long-term storage |
| **Testing**                    | A builder-pattern test-data factory with parent-child wiring, query mocking that needs no database, and framework-object assertion helpers                                                                                                                                                                                                     | `fflib-mocks` if you need Mockito-style behaviour verification (checking which methods your code called, through argument matchers and verification modes); KernDX has no equivalent. `apex-dml-mocking` or `apex-fluently-dml` if your unit tests must fake the record writes of the code under test: KernDX fakes query results and can build test records without saving them, but does not fake writes. For HTTP mocks, KernDX's `API_MockFactory` and `apex-fluently-httpmock` are equal: `apex-fluently-httpmock` fits HTTP code that does not go through KernDX's outbound stack, or tests that need its four ways of matching a request |
| **Resilience / feature flags** | A feature-flag framework you can extend (custom metadata + per-user/profile settings) consumable from Apex/Flow/LWC, with pluggable resolution strategies and retry utilities                                                                                                                                             | `rflib` for retryable trigger actions (a failed platform-event trigger action is retried automatically, up to 8 times), which KernDX does not ship. Its fixed switch order (user, then group, then profile, then org-wide) is not a capability KernDX lacks: for a team already on `rflib`, moving means admins relearn where a switch is set; staying keeps no permission checks on writes and bypass warnings that are not saved by default |
| **Security**                   | FLS/CRUD enforced on reads and writes by default, an org-wide kill switch (a master off-switch you can flip without a deployment), per-call bypass, and an audit entry for each opt-out made through the builders, triggers and validation rules                                                                                                                                                                                                   | None of the frameworks compared here ship both an org-wide kill switch *and* a record of each bypass at run time                                            |
| **Data masking**               | Runtime masking on the call path (regex + credit-card detection + literal + JSON-key), four modes, three failure actions, caller scoping, and shipped rules                                                                                                                                                                      | `mask-sobject` for *batch* anonymisation of existing data (sandbox refresh): a complementary, different job                                    |
| **LWC**                        | A component base with five built-in modules (toast / Apex controller / navigation / Lightning Message / Flow navigation) and opt-in activation                                                                                                                                                                                          | No comparable alternative ships a coherent LWC component framework                                                                              |
| **Async**                      | Chained queueables with shared state across transactions, recovery work that runs after the transaction commits (finalizer recovery), a kill switch, and an error handler and a completion handler for the whole chain. More protections, two opt-in features and two operator capabilities are listed below the table | `apex-fluently-async` if you want its job card on the record page (a record's background jobs, with a button to requeue a failed step); KernDX has no Promise-style API (then / catch / finally); `apex-promisify` offers that shape, but with no shared state, no recovery and no stop switch, so it is a difference in style, not a capability. `revenant` if you put its queue in front of your own work, or if you need long-running workflows that pause and resume against platform limits (more on `revenant` below the table) |

**The Async row in detail.** Three more protections are on from the moment you use KernDX's chains:

- Each run carries its own key, so a superseded or duplicate copy of a job cannot write over the live run.
- Every chain that ends, however it ends, writes a final log entry.
- A failed run records why it failed.

Two more are opt-in:

- Give a chain a deduplication key (one builder call in code) and a duplicate start of a run already in flight is refused.
- A step can also opt into a bounded number of retries with a widening delay.

Two operator capabilities sit on top, and each needs one deliberate setup step first:

- **A scheduled recovery job.** It checks whether a chain's work is genuinely still running and recovers the ones it can prove died. It runs a stalled step again only when that is safe, and otherwise ends the chain as failed so nothing is done twice. Anything it cannot prove dead is left untouched and flagged for a person instead. An admin schedules that job once, and the health check offers a one-click way to do it. A restarted run picks up under the framework's default settings rather than the ones its original builder set.
- **A stop action in the Chain Monitor.** It sits behind a permission set that ships assigned to nobody, and lands at the next step boundary. Retry from the failed step and restart sit behind a second permission set, which also ships assigned to nobody.

**`revenant` in the Async row.** Its queue releases your work only once the transaction that queued it commits, so a rollback leaves nothing to send. Its basic chaining (state carried between transactions, recovery, an org-wide stop switch) is as complete as KernDX's, though it has no completion handler, step-count cap, typed schedule parameters or automatic switch to batch processing.

---

## The integration trade-off

Single-capability libraries stay out of each other's way. Each one is replaced and upgraded on its own, you can review each library on its own, and the risk of one maintainer stepping away is spread across several projects.

The cost of that isolation is that **your team becomes the systems integrator**. As you install more libraries side by side, four kinds of ongoing work pile up, even when each library is free:

1. **Making the libraries work together.** Lining up namespaces, settings hierarchies, a shared tracking ID across them, and coordinating who is bypassed where is your job.
   Say you combine a trigger library with a separate logger: you wire the trigger-bypass events into the logger yourself, because neither library ships that bridge.
2. **Security review, repeated per library.** Each library is its own thing to review. Co-install four (triggers, query, DML, logging) and every upgrade means four separate review cycles: you re-check sharing
   declarations, FLS/CRUD defaults, audit behaviour, and where each dependency came from, once per library.
3. **Upgrades and maintenance, repeated per library.** Each library releases on its own schedule, so every time any one of them tags a release you pin versions, track breaking changes, and test that they all still work together.
4. **Code you own.** A library you deploy as source puts every one of its classes, used or not, into your org as your own code: you cover it with tests, scan it, and it counts against your 6 MB Apex limit. When you install the managed package, KernDX's unused code is inert, does not count against that limit, and is not copied in as your own source.

KernDX makes the opposite trade: **integration that's already done for you**. What is fixed is the framework's own wiring: KernDX's triggers, queries and jobs log and trace through KernDX. Your own code can still use another library in any area. The capabilities share one namespace, one set of security defaults, one tracking ID that follows a user action across them,
one record of the bypasses made through its builders, triggers and validation rules, and one release cadence. The wiring you'd otherwise do is done.

Neither side is free, and the honest framing is even-handed. An integrated package concentrates dependency ownership and widens how much one upgrade touches. A library stack
spreads that out, but it multiplies the work of integrating and reviewing the pieces. Because KernDX is [opt-in at runtime](#one-deployment-opt-in-at-runtime), you can also split the difference:
adopt it for most capabilities and keep a specialised library where that library is the better fit.

---

## Head-to-head

Eight frameworks come up most often when teams compare against KernDX. Each entry below follows the same shape: what it is, where it wins, where KernDX diverges, how they coexist, and the
migration cost. The migration-cost line says in words what moving would mean for code you already have: what you would port or re-point, and what can stay where it is. It assumes you already have a codebase rather than starting from scratch.

### vs. fflib

**The library.** `fflib` ("Apex Enterprise Patterns" / `fflib-apex-common`) is the standard implementation of the Service / Selector / Domain / Unit-of-Work pattern in Apex (Unit of Work means you register related records and save them together: all commit or all roll back). It is the
framework that established that architectural style on the platform. Licence: BSD 3-Clause. Mature, in maintenance mode: as of 2026-10-30, when the comparison evidence was taken, it had 48 commits in the last 12 months and no versioned release (its one tag, from 2020-04-05, marks a change of source format, not a version).

**Where it wins.** You specifically want the Application/Service factory pattern (`fflib_Application`), which KernDX does not ship, and you accept hand-rolling the areas
it doesn't cover. A team already trained on `fflib` weighs two costs: moving means re-pointing its Domain, Service and Selector layers; staying means its selectors check object read access by default, but field permissions, sharing and writes are not checked by default, and no bypass is recorded. Its Unit of Work also saves related records in the right order (parents first, each child given its parent's Id) as completely as KernDX's DML layer does.

**The KernDX divergence.** `fflib` ships no trigger framework, no default check of field permissions, sharing or writes on Query/DML (its selectors check object read access by default), no outbound HTTP framework, no data masking, no health check, no LWC
framework, and no shipped scanner or coverage gate. KernDX covers those areas with security enforced by default and audited bypass.

**Coexistence.** Strong. The two ship in separate namespaces and don't collide, so you can let `fflib_Application` supply the Service/Domain factory while KernDX handles triggers, query,
DML, outbound, async, security, and masking.

**Migration cost.** Moving means re-pointing your established Domain, Service and Selector layers to KernDX. That is real work, so you can keep the domain layer on `fflib` and run the two side by side.

> **Pick:** Start fresh on KernDX. Keep `fflib` for an existing Domain layer that depends on its factory patterns: the hybrid is supported.

### vs. taf

**The library.** `taf` ("Trigger Actions Framework") is a single-capability trigger framework that uses metadata-driven registration. It scopes to triggers only. Licence: Apache 2.0.

**Where it wins.** Little over KernDX on capability. `taf` does as much as KernDX on switching individual trigger actions on and off: each action can require, or be skipped by, a custom permission, checked for the running user every time the trigger runs.

KernDX covers everything else `taf` does, including Change Data Capture dispatch and post-trigger finalizers. It adds a record of each trigger bypass made in code, a stable order for actions that share an order value, per-action performance logging, a coverage gate, fuller documentation, and the other framework areas.

`taf` has one piece KernDX lacks: its Flow trigger actions can take a typed collection input, where KernDX runs Flow actions one record at a time because of a platform limit. That piece is not a reason to choose `taf`.

For a team already on `taf`, moving means porting each action class and its registration to a KernDX record; staying keeps trigger bypasses that leave no record. (Licence does not separate them: both are under the Apache License 2.0.)

**The KernDX divergence.** `taf` bypasses run unaudited: no log, no platform event, no other record. You cannot plug your own registration logic into it, and it ships no coverage
gate. KernDX writes an audit entry for each trigger bypass made in code and covers the capability areas beyond triggers.

Both frameworks dispatch trigger actions on Change Data Capture events (with the
change header available to Flow and Apex actions) and run post-trigger / transaction-finalizer actions; KernDX additionally writes a bypass record and a per-action performance log on
those paths.

(For teams already fluent in `taf`'s registration style the metadata shape is similar, but the cost is still porting each action class and its registration;
see [Adoption](Strategic%20Guide%20-%20Adoption.md#migration-narratives).)

**Coexistence.** Not typical. Both occupy the trigger scope, and running two trigger dispatchers at once invites unpredictable order-of-execution and recursion conflicts. Pick
one.

**Migration cost.** Moving means porting each action class and its registration to a KernDX record. The metadata-driven registration concepts map closely.

> **Pick:** KernDX. `taf` is a well-regarded focused trigger framework (KernDX's own trigger layer evolved from it), and KernDX covers everything else it does. Its one piece KernDX lacks, typed collection input for Flow trigger actions, is not a reason to choose it. For a team already on `taf`,
> moving means porting each action class and its registration to a KernDX record, and staying keeps trigger bypasses that leave no record.

### vs. apex-libra

**The library.** `apex-libra` is a multi-capability framework covering trigger registration, DML, logging, resilience, security, testing, and utilities. Of the frameworks here, it ships the most capabilities after KernDX, counting every capability compared. Counted only on the core capabilities every org needs (22 in all), though, ApexKit (a source-only suite listed below) ships more: 17 against `apex-libra`'s 15. Licence: MIT.

**Where it wins.** Your primary need is its functional / lambda utilities (`IFunction` / `IConsumer` / `IPredicate`), which KernDX does not ship. It also ships a basic stub helper for tests that KernDX lacks; for checking how your code was called, `fflib-mocks` goes further. (Licence does not decide the choice: KernDX is under the Apache License 2.0, also a permissive open-source licence.)

**The KernDX divergence.** `apex-libra` defaults to *system mode* on DML writes, so you override per call to enforce FLS/CRUD on writes. Its bypasses are unaudited, it ships no
recursion-suppression mechanism, and it has no inbound REST framework, no outbound HTTP framework with retry or a circuit breaker, no masking engine of KernDX's depth, no health check, and no LWC component framework (it ships a basic callout class and a toast helper). KernDX defaults to user mode on reads and writes, audits
each opt-out made through its builders, triggers and validation rules, and suppresses recursion automatically.

**Coexistence.** Possible (separate namespaces), but the overlap on triggers/query/DML/testing means most teams pick one.

**Migration cost.** Moving means re-pointing the areas the two share (triggers, query, DML and testing) to KernDX's default-on equivalents.

> **Pick:** KernDX when secure defaults and integrated capability breadth are priorities. Adopt `apex-libra` if functional/lambda utilities are your primary need and you accept
> default-system-mode writes plus unaudited bypasses.

### vs. rflib

**The library.** `rflib` is a multi-capability framework focused on logging, trigger orchestration, feature switches, and a few utilities. Of the multi-capability alternatives here, it is the most actively released (306 commits in 12 months and 84 tagged releases as of 2026-10-30, the latest in October 2026). `revenant` has more commits but has never tagged a release. Licence: BSD 3-Clause.

**Where it wins.** Retryable trigger actions: a failed platform-event trigger action is retried automatically, up to 8 times, which KernDX does not ship. Or its log browser, which does as much as KernDX's Log Console on browsing and goes further on reading archived entries back from a Big Object and exporting them to CSV; or its
admin per-row declarative-bypass shape.

It also ships Flow actions that forward its log events out of Salesforce to an OpenTelemetry collector (the vendor-neutral standard most
monitoring tools now read), to Azure Application Insights, or to Slack, Teams and Google Chat, so log entries can land in the tooling your operations team already watches. KernDX
ships no equivalent forwarder.

**The KernDX divergence.** `rflib` checks permissions on reads by default but has no permission checks on writes, saves no record of a bypass by default (it writes a warning when its org-wide or per-user trigger switch is on, but that warning is not saved by default, and no other bypass is recorded), and its feature-switch is sealed against extension.

It ships no inbound REST, outbound HTTP, async-chain orchestration, health check, or scanner, and no masking engine of KernDX's depth (it masks at a basic level). KernDX covers those with
default-on security and a record of each opt-out made through the builders, triggers and validation rules.

**Coexistence.** Good for log archival (`rflib`'s viewer reads archived entries back from a Big Object and exports CSV, which KernDX's Log Console does not), since the two run
in separate namespaces. (Logging is parallel, not merged: entries emitted via KernDX are not picked up by `rflib`'s viewer, and `rflib` entries do not appear in the Log Console.)

**Migration cost.** You can keep `rflib` beside KernDX for its log archival rather than moving off it; the cost is then running the two side by side, with two log stores that stay separate.

> **Pick:** KernDX for full coverage. Keep `rflib` when you rely on its retryable trigger actions, its Big Object log archival with CSV export, or its admin per-row bypass: they co-install cleanly.

### vs. nebula-logger

**The library.** `nebula-logger` is a single-capability logging framework, and by number of features it is the deepest dedicated Salesforce logging implementation. Licence: MIT. Long,
mature release history.

**Where it wins.** Four logging capabilities KernDX does not ship: a choice of how each log is saved (event bus / queueable / REST / synchronous DML), all seven platform log levels, per-record and
per-scenario retention overrides, and archiving old entries to a Big Object for long-term storage. KernDX's logging is leaner (single platform-event transport, four levels, no
per-record retention field); its Log Console browses past entries filtered by level, context and date range, searched by text, with recurring problems grouped and a per-operation
drilldown.

**The KernDX divergence.** `nebula-logger` is logging-only. It has no trigger framework, query/DML framework, web services, async orchestration, or security defaults, and its
logging is not wired into a trigger/query/DML bypass record or an async status record, because those don't exist outside an integrated framework.

**Coexistence.** Strong, among the cleanest hybrids available. (Logging is parallel, not merged: KernDX's own entries, including bypass records, flow through its
`LogEntryEvent__e` / `LogEntry__c` channel and are not picked up by `nebula-logger`'s store. Bridging the two is custom work.)

**Migration cost.** You co-install `nebula-logger` beside KernDX for the one thing you need from it, so no code has to move; the cost is two log stores that stay separate.

> **Pick:** KernDX's logging by default; its entries, including the framework's own audit and timing logs, read together in the Log Console. Co-install `nebula-logger` only
> when you need a selectable save method, seven levels, per-entry retention or Big Object archiving, and keep KernDX for everything else: triggers, query, DML, web services,
> async, security, masking, LWC, health, continuous integration (CI). Separate namespaces, no collision; the two log stores stay separate.

### vs. the Apex Fluently libraries

**The library.** A family of eight focused single-purpose libraries ([`-soql`](https://github.com/beyond-the-cloud-dev/soql-lib), [`-dml`](https://github.com/beyond-the-cloud-dev/dml-lib), [`-cache`](https://github.com/beyond-the-cloud-dev/cache-manager), [`-async`](https://github.com/beyond-the-cloud-dev/async-lib), [`-httpmock`](https://github.com/beyond-the-cloud-dev/http-mock-lib), [`-consts`](https://github.com/beyond-the-cloud-dev/apex-consts), [`-test`](https://github.com/beyond-the-cloud-dev/test-lib), [`-lwc`](https://github.com/beyond-the-cloud-dev/lwc-utils)): a "pick what you need" collection of libraries, each with its own chained syntax (a DSL, or domain-specific language), generally actively maintained, with `-async`, `-soql` and `-dml` at the highest cadence. Licence: MIT across the family.

**Where it wins.** You need your unit tests to fake record writes (`apex-fluently-dml`'s `DML.mock`, which KernDX does not ship). Each library's own syntax (its DSL, for example `apex-fluently-dml`'s record-builder
relationship syntax over KernDX's call-site registration; both resolve multi-level dependency graphs) is a difference in style, not a capability.

For a team already on one of the libraries, moving means rewriting that code. Staying means no shared bypass record or tracking ID across the libraries, and an opt-out from the permission checks of `apex-fluently-soql` or `apex-fluently-dml` leaves no record.

Needing one capability is not a reason on its own: KernDX is adopted one feature at a time, and when you install the managed package its unused code is inert and outside your 6 MB Apex limit.

Most Apex Fluently libraries install as released unlocked packages in the shared `btcdev` namespace (`apex-fluently-cache` and `apex-fluently-consts` are source only); none is a managed package. (Licence does not decide the choice: KernDX is under the Apache License 2.0, also a permissive open-source licence.)

**The KernDX divergence.** `apex-fluently-soql` runs reads with the user's permissions by default (`apex-fluently-dml` does the same for writes). Only KernDX records it when a call opts out, with the user and the reason; `apex-fluently-soql`'s opt-out is a per-call method that leaves no record, and it has no org-wide off-switch, so access is unaudited across the family.

`apex-fluently-soql`'s executor is sealed (you can't subclass to extend the builder),
`apex-fluently-dml` ships no async DML path, and `apex-fluently-httpmock` is mock-only with no production callout path. Adopt several pieces and you get no shared bypass record or
tracking ID across them, because the libraries don't know about each other. KernDX provides audited bypass, an org-wide kill switch, async DML, production callouts, and cross-capability integration.

**Coexistence.** Technically possible (separate namespaces) but usually redundant where the two overlap. Keep one whose capability KernDX lacks (`DML.mock`). Where your code already uses a library, weigh the two costs: moving means rewriting that code; staying means two sets of conventions, two upgrade schedules, and opt-outs that leave no record.

**Migration cost.** Each library can be replaced on its own: moving means rewriting the code that uses that library's syntax against KernDX's equivalent.

> **Pick:** KernDX for integrated guarantees. Adopt an individual Apex Fluently library when your unit tests must fake record writes (`DML.mock`), accepting that an opt-out from its
> permission checks leaves no record. Running one today is a migration cost to weigh, not a reason on its own. (Licence does not decide the choice: KernDX is under the Apache License 2.0, also a permissive open-source licence.)

### vs. fflib-mocks

**The library.** [`fflib-mocks`](https://github.com/apex-enterprise-patterns/fflib-apex-mocks) (`fflib-apex-mocks`) is the standard Mockito-style mocking library for Apex (named after Mockito, a well-known Java mocking library):
behaviour-verification mocking via stubs, argument matchers, and verification modes. Licence: BSD 3-Clause. Long-established, lightly maintained now.

**Where it wins.** You need Mockito-style behaviour verification: rich argument matchers, `times`/`atLeast`/`atMost`/`between`/`never` verification modes, sequence verification,
argument capture. **KernDX has no equivalent.**

**The KernDX divergence.** KernDX's testing scope is a builder-pattern test-data factory, selector mocking that needs no database, and test helpers for async / Flow / outbound / framework-object
assertions: a different and complementary set of tools.

**Coexistence.** Recommended, since the two are complementary.

**Migration cost.** Nothing moves: you co-install the two, and neither replaces the other.

> **Pick:** Adopt both side-by-side. `fflib-mocks` for Mockito-style verification; KernDX's test-data builder and selector mocks for the rest.

### vs. sf-bedrock

**The library.** [`sf-bedrock`](https://github.com/force-creators/sf-bedrock) is a multi-capability Apex foundation library organised as sixteen single-purpose modules, including async work queues, scheduling, platform-event relay, platform caching, feature flags, selectors, a DML wrapper, an inbound REST gateway, test data, a trigger-handler base, and a governor-limit gate, plus an operations-console Lightning app.

It distributes as an unlocked package (its only published version is a beta, not promoted), with documentation hosted at sfbedrock.com. Licence: MPL-2.0 (Mozilla Public License 2.0). Activity when we last read its source: 187 commits and 2 tags, all since its first commit on 2026-06-02, one of the two shortest recorded histories of the frameworks compared here (only `revenant`, in the specialty table below, started later). The capability notes below are read from that published source, not from its age.

**Where it wins.** Two of its modules cover ground KernDX does not, and both are genuine wins:

- **The governor-limit gate (`Limiter`).** It answers "is this limit still under my threshold?" in one Apex call, across both per-transaction limits and org-wide daily limits such as daily async executions and daily platform events. KernDX's `UTIL_Limits` ships the same per-transaction checks but no Apex check for org-wide daily limits, which KernDX shows on its monitoring screens instead.
- **The durable platform-event relay (`EventRelay`).** It stores platform-event or generic payloads as work records and drains them in first-in-first-out lanes through retryable publisher and handler classes, with a per-item status you can inspect, retry, or delete. KernDX ships no general-purpose durable event relay.

Its async operations console is also wider: eight monitoring views over its work queue with retry and delete row actions. KernDX's Chain Monitor is a single console instead, a searchable, filterable, sortable list of chain runs beside a per-execution detail panel carrying a step-by-step timeline, a timing breakdown, error detail, and a permission-gated stop action.

KernDX goes deeper per execution, and `sf-bedrock` spans more views and lets an operator retry a failed row straight from the console, which KernDX does not offer at all. (Licence does not decide the choice: both are open-source licences.)

**The KernDX divergence.** `sf-bedrock` ships no permission enforcement in its packaged library: reads run through `Database.query` and writes through bare DML statements, with no field- or object-permission checks and no user-mode option, so there is no bypass to record. Where its modules stop short:

- **Triggers:** a virtual handler base class only, with no configuration-driven registration, no recursion control, no bypass mechanism, and no record of what ran.
- **Feature flags:** org-wide only, with no per-user scoping and no swappable resolution rules.
- **Chains:** steps cannot pass state to the next step, with no off-switch for the chain engine.
- **Not shipped:** no logging framework, no query builder, no outbound HTTP framework, no data masking, no CI scanner suite, and no published coverage report.
- **Health:** a console that shows scheduled-job state and error counts, with no next step to fix a problem and no checks on caching, permissions, or setup.
- **Inbound REST:** its gateway stops at basic routing (no DTO layer, validation hooks, call record, or paired test harness).
- **Testing:** narrower scaffolding, with a data builder that defaults to a single record with no parent-child auto-wiring, query mocking opted into per call site, and no outbound, inbound, or Flow test helpers.

KernDX covers all of those areas with security enforced by default and an audit entry for each opt-out made through its builders, triggers and validation rules.

**Coexistence.** Possible but overlapping. It installs as an unlocked package alongside KernDX's managed package, and the two overlap on triggers, selectors, DML, async, caching, feature flags, and test data, so most teams pick one. The one module that fills a gap KernDX leaves is the platform-event relay: mix it in if durable, ordered platform-event work is a hard requirement.

**Migration cost.** Moving means re-pointing the overlapping pieces (selector base classes, a static DML facade, work-queue steps) to KernDX's default-on equivalents, and moving trigger handlers from subclassing its handler base to configuration-driven registration.

> **Pick:** KernDX. `sf-bedrock` spans many of the same areas, but everywhere the two overlap KernDX covers the ground as fully or more fully, and it adds the security defaults, audited bypass, logging, outbound HTTP, data masking, query builder, and CI tooling that `sf-bedrock` does not ship. Mix in its event relay only if durable platform-event work with ordered lanes is a hard requirement.

---

## Other frameworks

Beyond the eight above, these frameworks are compared more briefly. Most are single-purpose libraries that cover one specialty; two cover more: ApexKit is a multi-capability suite, and `revenant` is a workflow engine. In most cases KernDX already covers the same ground as part of its integrated scope; the table flags the exceptions where a specialty library is still worth reaching for.

<details>
<summary>Full comparison of the other frameworks (17)</summary>

| Library                  | What it does                                                               | KernDX equivalent                                                                                                                   | Recommendation                                                                                                         |
|--------------------------|----------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------|
| `apex-async-linkable`    | Standalone queueable-link library                                          | `UTIL_AsyncChain` adds shared state, finalizer recovery, kill switch, orchestration, plus a per-run key so a superseded or duplicate copy of a job cannot overwrite the live run, an opt-in refusal of a duplicate start while a run is already in flight, opt-in per-step retry with a widening delay, a final log entry however a run ends, and a recorded reason on a failed run, with an admin-scheduled recovery job and a permission-gated operator stop on top                                                 | Use KernDX. Where your code already uses it, moving means rewriting each chain; staying means no shared state, recovery or stop switch |
| `apex-chainable`         | Queueable-chaining with chain-runtime exceptions                           | `UTIL_AsyncChain` chains at greater depth: shared state, recovery, kill switch, plus a per-run key so a superseded or duplicate copy of a job cannot overwrite the live run, an opt-in refusal of a duplicate start while a run is already in flight, opt-in per-step retry with a widening delay, a final log entry however a run ends, and a recorded reason on a failed run, with an admin-scheduled recovery job and a permission-gated operator stop on top                                                                                           | Use KernDX                                                                                                             |
| `apex-dml-mocking` | Query and write wrappers with in-memory fakes for both in tests; source only, presented by its author as an example pattern | KernDX does as much or more on every feature both ship. KernDX fakes query results and builds test records without saving them, but does not fake the writes of the code under test; this library does. Its reads and writes run in system mode by default | Use KernDX; use this pattern alongside only if your tests must fake writes, knowing those writes then skip KernDX's permission checks on writes, and KernDX keeps no bypass entry for them |
| `apex-fluently-async`    | Async-chain library with a job card on the record page (requeue a failed step, behind its own permission) | Both offer per-step retry and record why a step failed. `UTIL_AsyncChain` adds shared state, recovery, kill switch, one error handler and one completion handler for the whole chain, a per-run key so a superseded or duplicate copy of a job cannot overwrite the live run, an opt-in refusal of a duplicate start while a run is already in flight, a final log entry however a run ends, an admin-scheduled recovery job, and an org-wide Chain Monitor where operators with the right permission can stop, retry from the failed step, or restart a chain | Use KernDX                                                                                                             |
| `apex-fluently-cache`    | Single-class platform-cache wrapper, three storage tiers, no auto-dispatch | `UTIL_Cache` adds auto-scope dispatch (`Scope.AUTO` picks the cache tier for you)                                                   | Use KernDX                                                                                                             |
| `apex-fluently-consts`   | Constant-organisation utility                                              | Covered by KernDX utility helpers                                                                                                   | Use KernDX utilities                                                                                                   |
| `apex-fluently-dml`      | DML library with its own chained syntax, record-builder relationships and graph resolution | `DML_Builder` ships the same graph algorithm plus audited bypass and async DML; both write with the user's permissions by default, but only KernDX records an opt-out | Use KernDX for general DML; consider this when your unit tests must fake record writes (`DML.mock`) |
| `apex-fluently-httpmock` | HTTP-callout mock library, several resolution strategies                   | `API_MockFactory` ties on mocking; KernDX adds production outbound infrastructure                                                   | Use KernDX; consider this for HTTP code outside KernDX's outbound stack, or its four ways of matching a request. Where your tests already use it, staying means a second mock style in the same test suite; moving means rewriting those tests |
| `apex-fluently-lwc`      | LWC toast-helper library                                                   | `ComponentBuilder` adds four more modules                                                                                           | Use KernDX                                                                                                             |
| `apex-fluently-soql`     | SOQL query library with its own chained syntax                             | `QRY_Builder` adds audited bypass, an org-wide kill switch, and a wider feature set; both run reads with the user's permissions by default, but only KernDX records an opt-out | Use KernDX. Where your code already uses it, moving means rewriting queries; staying means an opt-out from permission checks leaves no record |
| `apex-fluently-test`     | Focused test-data builder                                                  | `TST_Builder` adds parent-child wiring and cyclic overrides; KernDX's wider testing tools add selector mocks and async/Flow/outbound helpers | Use KernDX                                                                                                             |
| `apex-promisify`         | Promise-style API for queueables                                           | `UTIL_AsyncChain` adds shared state, recovery, kill switch, plus a per-run key so a superseded or duplicate copy of a job cannot overwrite the live run, an opt-in refusal of a duplicate start while a run is already in flight, opt-in per-step retry with a widening delay, a final log entry however a run ends, and a recorded reason on a failed run, with an admin-scheduled recovery job and a permission-gated operator stop on top                                                                          | Use KernDX `UTIL_AsyncChain`. Its then / catch / finally shape is a difference in style, not a capability: it gives up shared state, recovery and a stop switch |
| `ApexKit` | A multi-capability suite you copy in as source, never released as a package: triggers, a query builder, two write paths, logging, a basic REST client, feature flags, async and test helpers | KernDX goes further on 36 of the 37 features both ship and is equal on 1; ApexKit's one lead is a behaviour-verification test helper. Its `Safely` write path checks permissions on every write and cannot be switched off, a real strength; but its other write path's system-mode methods record nothing, some read paths (`getQueryLocator`, aggregate queries, SOSL) skip the check, and the only bypass it logs is one kind of trigger bypass, as free text with no user | Use KernDX; consider ApexKit if you want writes that cannot skip the check and accept that its ways round the checks are not recorded |
| `mask-sobject`           | Batch anonymisation of existing org data                                   | `UTIL_FrameworkMasker` does runtime masking on the call path; batch scrub is the differentiator                                     | Use KernDX for runtime masking; use this for batch sandbox scrub (complementary)                                       |
| `nebula-triggers`        | Single-class metadata-driven trigger dispatcher                            | KernDX trigger framework adds recursion control, four-level audited bypass, a record of what each trigger did                                           | Use KernDX                                                                                                             |
| `promise`                | Promise-style queueable chaining, no shared state                          | `UTIL_AsyncChain` adds shared state, recovery, kill switch, plus a per-run key so a superseded or duplicate copy of a job cannot overwrite the live run, an opt-in refusal of a duplicate start while a run is already in flight, opt-in per-step retry with a widening delay, a final log entry however a run ends, and a recorded reason on a failed run, with an admin-scheduled recovery job and a permission-gated operator stop on top                                                                          | Use KernDX `UTIL_AsyncChain`. Its then / catch shape is a difference in style, not a capability: it gives up shared state, recovery and a stop switch |
| [`revenant`](https://github.com/madmax983/revenant)              | Durable workflow engine: long-running workflows whose steps pause when they run out of platform capacity and pick up where they left off, plus waits and timeouts, splitting work into parallel branches and gathering the results, undo steps that run when a later step fails, alerting as a workflow progresses, and a queue that only releases work once the transaction that queued it commits. You deploy it from source rather than installing a package | `UTIL_AsyncChain` covers the same chain features with the protections and operator tooling listed above (`revenant`'s basic chaining is as complete as KernDX's; KernDX goes further on orchestration, scheduling, batch work and monitoring), and KernDX adds the production outbound HTTP framework `revenant` has no equivalent for. Three things run the other way or tie: the commit-safe queue covers ground KernDX does not; its System Doctor screen checks the health of its own engine, with one-click fixes, as completely as KernDX's health check covers KernDX; and KernDX has deliberately chosen not to build progress alerting | Use KernDX; consider `revenant` when you need a commit-safe queue in front of your own work, or workflows that run long enough to pause and resume against platform limits |

</details>

---

## Organisational fit

Capability fit is only half the decision. Organisational fit is the other half. The questions here are about your team and your constraints, not your code.

**KernDX fits well when:**

- **Greenfield or standardisation.** You're starting fresh, or standardising a codebase that lacks a consistent framework.
- **Governance by default.** Security governance is a priority and you want it enforced automatically rather than left to each developer's discipline.
- **Unified maintenance.** You want one integrated toolset with one thing to review and one upgrade cadence.
- **Lean platform teams.** When no dedicated architecture team is enforcing conventions in review, having governance on by default does *more* work for you, not less. A small
  team is a reason *for* built-in governance, not against it.

**Prefer specialised libraries when:**

- **A capability KernDX lacks.** You need something no KernDX feature ships, such as Mockito-style behaviour verification (`fflib-mocks`), a choice of how each log is saved (`nebula-logger`), a queue that releases work only after your transaction commits (`revenant`), or an Application/Service factory that an established `fflib` Domain layer depends on (`fflib`).
- **An org that will not accept the trade-offs of installing KernDX unmanaged.** KernDX can also be installed unmanaged, as plain source. Its code then counts toward your org's 6 MB Apex limit, and upgrades mean redeploying source. If your org cannot install managed packages and will not accept those two trade-offs, a library that fits your install policy is the better fit.

An existing investment in another library is a cost to weigh, not a reason on its own. Moving costs the migration; staying costs what that library leaves out, such as permission checks that are off by default or bypasses that leave no record.

Needing only one capability is not a reason on its own either. KernDX is adopted one feature at a time, and when you install the managed package its unused code is inert and outside your 6 MB Apex limit.

These are not mutually exclusive. Because KernDX is opt-in at runtime, a team can adopt it for the capabilities it wants and keep a specialised library where that library is the
better fit. See the per-framework coexistence notes above.

**Support.** KernDX support is issue-based: bug reports and questions go through GitHub issues, with no formal service-level agreement (SLA). Hands-on help, direct source delivery, and
handover are available through consulting engagements. [Risks](Strategic%20Guide%20-%20Risks.md) and [Operations](Strategic%20Guide%20-%20Operations.md) cover the support and
survivability model in full.

---

## Spotted something wrong?

This guide is written by the KernDX team, and frameworks change. If you maintain or use one of the frameworks here and believe an assessment is inaccurate (a misread feature, a
detail that's changed since this was written, or a recommendation that doesn't match the current source),
please [open a GitHub issue](https://github.com/JVB-Consulting/kerndx/issues/new/choose). We'll re-check against the current source, correct the guide, and credit you in the
changelog.

---

[< Risks](Strategic%20Guide%20-%20Risks.md) | [Overview >](Strategic%20Guide%20-%20Overview.md)
