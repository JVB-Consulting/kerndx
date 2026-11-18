# Elastic limits probe

This probe shows what Kern's background work does once an org has used up its 24-hour allowance of background Apex
jobs (the `DailyAsyncApexExecutions` limit), with Salesforce elastic limits (beta) off and then on. It lowers the
allowance to 50 with `asyncApexExecutionsOverride` (non-production orgs only), so the wall is reached in minutes.

Run it only on the subscriber scratch org `YourSubscriberOrgAlias`, and only while nothing else uses that org. Never copy
these files into `release-testing/subscriber/` or `/tmp/kern-subscriber/`: every release-test org deploys those, and
the override must never reach one by accident.

## Files

| File | What it does | Tokens |
|---|---|---|
| `classes/ElasticProbeFiller.cls` | A background job that does nothing. Queued many times to use up the allowance. | none |
| `classes/ElasticProbeSlowFiller.cls` | A background job that keeps the processor busy for about 4 seconds and does nothing else. Used to see whether jobs wait (are throttled) in the elastic band. | none |
| `classes/ElasticProbeSlowBatch.cls` | A batch job over 3 numbers, run with a size of 1. Each of its 3 parts keeps the processor busy for about 4 seconds. Used to see whether a second batch waits for the first. | none |
| `settings/Apex.settings-meta.xml` | Allowance 50, elastic limits off. | none |
| `settings-1b/Apex.settings-meta.xml` | Allowance 160, elastic limits off. For the throttling run, which started with 100 executions already in the window: the allowance is the next multiple of 10 at or above the used count plus 60. | none |
| `settings-1b-elastic-on/Apex.settings-meta.xml` | Allowance 160, elastic limits on (so the elastic limit is 320). | none |
| `settings-1c/Apex.settings-meta.xml` | Allowance 189, elastic limits off. For the refused-retry run, which started with 179 executions already in the window: the allowance is the used count plus 10. Before each later deploy in that run, the allowance in the copy in the temporary project is set again from the used count at that moment (219 to free room, then 200); the file here keeps the first value. | none |
| `settings-1c-elastic-on/Apex.settings-meta.xml` | The same allowance, elastic limits on (so the elastic limit is twice the allowance). In the run it was deployed with the allowance 200, so the elastic limit read 400. | none |
| `settings-elastic-on/Apex.settings-meta.xml` | Allowance 50, elastic limits on (so the elastic limit is 100). | none |
| `settings-restore/Apex.settings-meta.xml` | Allowance back to the licensed limit, elastic limits off. The override is left blank (`xsi:nil="true"`): the org refuses 0 ("Enter a number between 1 and 250000"), and a blank value removes the override. | none |
| `read-budget.apex` | Prints the allowance used, maximum and remaining, every org limit whose name contains `Async`, every schedule, every probe call and issue with the start of its error text (and, for an issue, whether it is marked External System May Have Acted), today's log entries of `FLOW_CallApiAsync`, of `SCHED_OutboundRetryWatchdog` and of a refused next job (`enqueueNextHop`), every chain run and runner row, the outbound flows' interviews, the live jobs by class and the last 20 jobs. Ends with a `PROBE GATE` line. Changes nothing. | none |
| `spend-budget.apex` | Queues `ElasticProbeFiller` jobs until `__LEAVE__` executions remain, at most `__BATCH__` per run. Prints remaining before, the number queued, and remaining again in the same transaction (a count that moved there moved when the jobs were queued). | `__LEAVE__` (executions to leave remaining; it can be negative, see Order step 5), `__BATCH__` (50 with elastic limits off, at most 10 with them on) |
| `burst.apex` | Starts a burst of slow jobs in one transaction and prints the time, the remaining count before and after, and every job id with its first status. The jobs' own `AsyncApexJob` rows are the measurement. | `__KIND__`: `queueables` (10 `ElasticProbeSlowFiller` jobs) or `batches` (2 `ElasticProbeSlowBatch` jobs back to back) |
| `launch-three-step-chain.apex` | Launches one chain of three `SubscriberChainSteps.WriteContextStep` steps. | `__HANDLER__`: `none`, or a step class such as `SubscriberChainSteps.ErrorHandlerStep` |
| `insert-outbound-call.apex` | Saves one `RetryLiveGet` outbound call: `queued` starts the first send, `retry` puts it at Retry with a time one minute out, `retrying` leaves it at Retrying with a retry time five minutes ago, which no flow picks up (the state the outbound retry watchdog deals with). Prints the save's exception, whether the row exists and its status, time, count and error text. | `__MODE__`: `queued`, `retry` or `retrying` |
| `seed-redrivable-chain.apex` | Seeds two stuck chain runs, 45 minutes old: one the watchdog can re-drive (its job is a Completed `ElasticProbeFiller` job), one it marks Stalled and notifies (no job, an `onError` handler). Needs one Completed filler job first. | none |
| `seed-job-runner-row.apex` | Seeds one due job-runner row named `Elastic Probe Runner Job` that runs `SCHED_SubscriberJob`. A copy of section 80's seed, changed as its header says. | none |
| `schedule-once.apex` | Schedules one chain watchdog pass, one outbound retry watchdog pass or one runner check to fire once. | `__JOB__`: `watchdog` (`kern.SCHED_ChainWatchdog`), `outboundWatchdog` (`kern.SCHED_OutboundRetryWatchdog`) or `runner`; `__THRESHOLD__`: either watchdog's stale threshold in minutes; `__SECONDS__`: `0` for the next minute boundary, or seconds from now |
| `launch-adaptive-processor.apex` | Hands `AccountArchiveProcessor` a list of Accounts through `kern.UTIL_AsynchronousJobLauncher`. A copy of section 49's launch, changed as its header says. Prints one `PROBE LAUNCHER items=` line per launch with its Account ids in order. | `__ITEMS__`: `49` (queueable) or `51` (batch), or any number with `chainable`; `__DELAY__`: `0` or minutes (with `auto`, the launcher's dispatch delay, so the launch queues a `UTIL_AsynchronousJobLauncher` handler that starts the work later; with `chainable`, a minimum delay on every job of the chain through `AsyncOptions`, so the launch queues the chain's first `UTIL_AdaptiveAsynchronousProcessor` job); `__RUNS__`: `1` or `2` (back to back); `__STRATEGY__`: `auto` (the launcher chooses, as for row 88) or `chainable` (a chain of Queueables, each starting the next from its Finalizer); `__JOB_SIZE__`: the items per job with `chainable`, `0` with `auto` |
| `clean-up.apex` | Deletes every row the probe made and aborts every probe schedule, then prints how many are left per category. It deletes a paused outbound-flow interview only when the record it waits on is a probe call or an API call that no longer exists; other interviews in the org are left alone. Safe to run again. | `__KEEP__`: an `ApiCall__c` id to leave in place, or `none` |

A token is replaced by plain text before the script runs: copy the script to a scratch file, replace the token, and
run the copy.

Runbook section 89 (`release-testing/RUNBOOK.md`, "Section 89 note") runs some of these scripts on every release leg,
through one driver, `node release-testing/scripts/section-89-outbound-at-the-daily-limit.js`: it fills the tokens, rewrites
`kern.` and `kern__` for the org's namespace, builds its own temporary project and puts the org back. This probe's own
order below is for row 88 only, run by hand.

## Before you start

1. The org has Kern installed, the subscriber classes (`SubscriberChainSteps`, `SCHED_SubscriberJob`,
   `AccountArchiveProcessor`, `API_RetryLiveGet` and its `kern__ApiSetting.RetryLiveGet` record), and
   `SubscriberTestAccess` and `KernE2EAuditFieldAccess` assigned to the running user.
2. Build a temporary project and deploy from there, never with `--source-dir` from the repository:

   ```bash
   mkdir -p /tmp/kern-elastic-probe/force-app/main/default/classes /tmp/kern-elastic-probe/force-app/main/default/settings
   ```

   Give it a `sfdx-project.json` of
   `{"packageDirectories":[{"path":"force-app","default":true}],"name":"KernElasticProbe","sourceApiVersion":"68.0"}`
   and a `.forceignore` holding `**/__tests__/**`. Copy `classes/` into its `force-app/main/default/classes/` and
   deploy from inside the folder:

   ```bash
   sf project deploy start -o YourSubscriberOrgAlias -d force-app --ignore-conflicts --wait 3
   ```

3. Assign `kern__JobRunnerManagement` to the running user if it is not assigned, and note that you did.

## The state gate

Before every group of paths, run `read-budget.apex` twice, two minutes apart. Go on only when both reads show the same
remaining count and the second read's `PROBE GATE` line shows no probe schedule, no pending probe call, no outbound
flow interview, no Running probe chain and no live job (except one you are watching on purpose). With elastic limits
off, wait at most 20 minutes; with them on, see the plan's rules about throttled filler jobs.

## Order

1. Run `read-budget.apex` and record the licensed maximum. Copy `settings/` into the temporary project and deploy
   `Settings:Apex`. Run `read-budget.apex` again: the maximum must read 50.
2. Elastic limits off, under the wall: run each path once, with the gate between paths.
3. Elastic limits off, at the wall: `spend-budget.apex` with `__LEAVE__` 1, then the chain; then `__LEAVE__` 0, and
   every path again.
4. Deploy `settings-elastic-on/` and run `read-budget.apex`. On 2026-11-06 `DailyAsyncApexExecutions` still read
   maximum 50 with elastic limits on (not 100), and its used count went past 50, so its remaining count went negative.
   Record every `PROBE ASYNC LIMIT` line: the elastic ceiling may be reported under another limit name, and on
   2026-11-06 only `DailyAsyncApexExecutions` was read. Run the paths again in the throttled band.
5. Spend to 1 and then 0 of 100 left, and run the delayed dispatch, a chain and a queued call. While
   `DailyAsyncApexExecutions` shows maximum 50, `__LEAVE__` counts against that 50, so 1 of 100 left is `__LEAVE__`
   -49 and 0 of 100 left is `__LEAVE__` -50.
6. Put the org back: `clean-up.apex` with `__KEEP__` none, deploy `settings-restore/`, run `read-budget.apex` and
   check the licensed maximum is back. Unassign `kern__JobRunnerManagement` if you assigned it. The clean-up read-back
   ends with `PROBE LEFT probe flow interviews=` (`unknown` when the read failed) and then
   `PROBE LEFT outbound flow interviews with no record link=`. A number above 0 on that second line is interviews the
   script could not tie to a record and left alone. Read Setup's Paused and Failed Flow Interviews page by hand before
   recording 0.
7. Remove the filler class from the org. From inside the temporary project (with `classes/` still copied in), run:

   ```bash
   sf project delete source -o YourSubscriberOrgAlias -m ApexClass:ElasticProbeFiller --no-prompt
   ```

   Never run it with `--source-dir` from the repository. Read back that the class is gone: this query must return 0
   rows.

   ```bash
   sf data query -o YourSubscriberOrgAlias -q "SELECT Id FROM ApexClass WHERE Name = 'ElasticProbeFiller'"
   ```

8. Delete `/tmp/kern-elastic-probe/`.

## Throttling run

This run checks whether jobs wait in the elastic band, with jobs that take seconds. Deploy all three classes.

1. Run `read-budget.apex` and note the used count U. Set the allowance to the next multiple of 10 at or above U + 60
   (call it O) in `settings-1b/` and `settings-1b-elastic-on/`, and deploy `settings-1b/`.
2. Elastic limits off, under the wall: after the state gate, run `burst.apex` with `queueables`, wait until all 10
   jobs have ended, then run it with `batches`. Save the job rows with `sf data query --json`.
3. Bring remaining to 0 with `spend-budget.apex` (`__LEAVE__` 0), and run the state gate.
4. Deploy `settings-1b-elastic-on/` and run `read-budget.apex`: record every `PROBE ASYNC LIMIT` line. Then run
   `burst.apex` `queueables`, `burst.apex` `batches` and `launch-three-step-chain.apex` `none`, with the state gate
   between them, and compare their job times with step 2.
5. Put the org back as in Order steps 6 to 8, and remove all three classes:
   `sf project delete source -o YourSubscriberOrgAlias -m ApexClass:ElasticProbeFiller -m ApexClass:ElasticProbeSlowFiller -m ApexClass:ElasticProbeSlowBatch --no-prompt`.
   The read-back query is then
   `SELECT Id, Name FROM ApexClass WHERE Name LIKE 'ElasticProbe%'`, and it must return 0 rows.

The executions the probe spends stay in the org's rolling 24-hour window from the time the last one ran.
