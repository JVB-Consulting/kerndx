// SPDX-License-Identifier: BUSL-1.1
//
// Chain Monitor REALISM seed — one batch of realistic async-chain scenarios.
//
// WHAT: launches 30 chains per run across seven shapes (happy path, mid-chain failure with an error
// handler, continue-past-optional-failure, idempotent recovery, non-idempotent restart, a 30-step long
// run, and a delayed start) plus, on batch 1 only, ten SYNTHESIZED stalled executions that no live run
// can produce inside a test window.
//
// WHY: the release orgs only ever held trivial e2e chains (one step, immediate failure), so the Chain
// Monitor list, its status filters and the operator actions (Retry / Restart / Abort) were never seen
// against the shapes a real subscriber produces. Every operator-action gate needs a chain in the right
// state: Retry needs a Failed chain whose step declares itself idempotent, Restart needs a Failed chain
// that allowed restart, and the watchdog view needs Running-but-silent and Stalled rows.
//
// RUN IT THROUGH seed-chain-scenarios.sh — never directly. The wrapper substitutes the two placeholders
// below, spaces the batches so the flex queue never overflows, and records the run start time that
// `seed-log-volume.mjs --teardown` needs to scope its marker cleanup.
//
// PREREQUISITES:
//   - The managed package installed on a subscriber org and SubscriberChainSteps deployed
//     (release-testing/subscriber/classes/SubscriberChainSteps.cls).
//   - FeatureFlag AsyncChain active — with the flag off, every launch is aborted.
//   - Audit-field back-dating enabled (RUNBOOK Phase 1.4) for the synthesized stalled rows, whose whole
//     point is a CreatedDate/LastModifiedDate older than the watchdog's stale threshold.
//
// TRANSACTION BUDGET: a launch costs 4 DML statements and 1 queueable, so 30 launches sit at 120 of the
// 150-DML and 30 of the 50-enqueue ceilings. Do not raise the per-shape counts without re-measuring.
//
// TEARDOWN MARKER: every chain is named `Seed_<Scenario>` and every correlation id starts with
// `seed-scenario-`. `node release-testing/scripts/seed-log-volume.mjs --teardown` removes them.

Integer batch = __BATCH__;
String run = '__RUN__';

// Each chain carries its own correlation id. Launching two chains under ONE adopted correlation fails
// with a DUPLICATE_VALUE on the execution's unique CorrelationId__c (defect U8), so nothing here starts
// a log correlation and every execute() is handed a distinct id.
//
// The run token the wrapper substitutes is ALL LETTERS on purpose. The shipped Chain_All_PaymentCard
// masking target covers every AsyncChainExecution__c field, CorrelationId__c included, and its pattern
// reads hyphens as card-number separators — so a digit-based token makes the whole id look like a card
// number, the platform stores the constant redaction text instead, and the next chain redacted the same
// way collides on the unique index. Keep the token free of long digit runs.
Integer sequence = 0;
Integer launched = 0;

// (a) Seed_OrderSync — the happy path, four steps and a completion handler. VerifyContextStep reads the
// apiResponse key a live CallApiStep would have written, so the initial context seeds it directly rather
// than making every seeded chain fire a real callout.
for(Integer i = 0; i < 9; i++)
{
	kern.UTIL_AsyncChain.newChain('Seed_OrderSync')
			.withInitialContext(SubscriberChainSteps.KEY_API_RESPONSE, 'seeded')
			.then(new SubscriberChainSteps.CreateFoobarStep())
			.then(new SubscriberChainSteps.UpdateFoobarStep())
			.then(new SubscriberChainSteps.VerifyContextStep())
			.onComplete(new SubscriberChainSteps.CompletionHandlerStep())
			.execute('seed-scenario-' + run + '-' + batch + '-' + sequence++);
	launched++;
}

// (b) Seed_InvoiceExport — five steps that break at step three, with an error handler. The shape an
// operator most often has to read: a partial step log with two green steps above the failure.
for(Integer i = 0; i < 6; i++)
{
	kern.UTIL_AsyncChain.newChain('Seed_InvoiceExport')
			.withInitialContext(SubscriberChainSteps.KEY_API_RESPONSE, 'seeded')
			.then(new SubscriberChainSteps.CreateFoobarStep())
			.then(new SubscriberChainSteps.UpdateFoobarStep())
			.then(new SubscriberChainSteps.FailingStep())
			.then(new SubscriberChainSteps.UpdateFoobarStep())
			.then(new SubscriberChainSteps.VerifyContextStep())
			.onError(new SubscriberChainSteps.ErrorHandlerStep())
			.execute('seed-scenario-' + run + '-' + batch + '-' + sequence++);
	launched++;
}

// (c) Seed_PartialSync — a tolerated failure: the chain completes with a red step in its log.
for(Integer i = 0; i < 4; i++)
{
	kern.UTIL_AsyncChain.newChain('Seed_PartialSync')
			.then(new SubscriberChainSteps.CreateFoobarStep())
			.then(new SubscriberChainSteps.OptionalFailingStep(), true)
			.then(new SubscriberChainSteps.UpdateFoobarStep())
			.execute('seed-scenario-' + run + '-' + batch + '-' + sequence++);
	launched++;
}

// (d) Seed_RecoverableImport — Failed, and its step declares itself idempotent, so the operator Retry
// action is offered AND actually recovers the chain on the second run.
for(Integer i = 0; i < 4; i++)
{
	kern.UTIL_AsyncChain.newChain('Seed_RecoverableImport')
			.then(new SubscriberChainSteps.RecoveringStep())
			.allowRestart()
			.execute('seed-scenario-' + run + '-' + batch + '-' + sequence++);
	launched++;
}

// (e) Seed_RestartableLoad — Failed and restartable, but the step is NOT idempotent: Restart is enabled
// and Retry is refused. The pair (d)/(e) is what makes the operator-action gating visible.
for(Integer i = 0; i < 3; i++)
{
	kern.UTIL_AsyncChain.newChain('Seed_RestartableLoad')
			.then(new SubscriberChainSteps.FailingStep())
			.allowRestart()
			.execute('seed-scenario-' + run + '-' + batch + '-' + sequence++);
	launched++;
}

// (f) Seed_NightlyReconciliation — a thirty-step run that grows the chain context to about 30 KB, so the
// step-log renderer and the progress indicator are exercised well past the two or three steps the e2e
// battery produces.
for(Integer i = 0; i < 2; i++)
{
	kern.UTIL_AsyncChain.ChainBuilder longRun = kern.UTIL_AsyncChain.newChain('Seed_NightlyReconciliation');
	for(Integer step = 0; step < 30; step++)
	{
		longRun.then(new SubscriberChainSteps.WriteContextStep());
	}
	longRun.execute('seed-scenario-' + run + '-' + batch + '-' + sequence++);
	launched++;
}

// (g) Seed_DeferredNotification — a delayed start, so the list always holds a run that has not begun.
// withDelayMinutes clamps to the platform ceiling of ten minutes for a Queueable enqueue delay.
for(Integer i = 0; i < 2; i++)
{
	kern.UTIL_AsyncChain.newChain('Seed_DeferredNotification')
			.then(new SubscriberChainSteps.CreateFoobarStep())
			.withDelayMinutes(10)
			.execute('seed-scenario-' + run + '-' + batch + '-' + sequence++);
	launched++;
}

// ---- Batch 1 only: SYNTHESIZED stalled executions. ----
// A chain the platform silently drops mid-run cannot be produced on demand, so these rows are written
// directly with back-dated audit fields — the same shape section-79-watchdog-sweep.apex uses. Six are
// Running with 45 minutes of silence (what the watchdog sweep should pick up) and four are already
// Stalled with no CompletedAt__c (what the operator sees after a sweep has run).
Integer synthesized = 0;
if(batch == 1)
{
	String ns = '';
	for(String key : Schema.getGlobalDescribe().keySet())
	{
		if(key.endsWith('asyncchainexecution__c'))
		{
			ns = key.substring(0, key.length() - 'asyncchainexecution__c'.length());
			break;
		}
	}
	SObjectType chainType = Schema.getGlobalDescribe().get(ns + 'AsyncChainExecution__c');
	Datetime now = Datetime.now();

	List<Map<String, Object>> stalledSpecifications = new List<Map<String, Object>>
	{
			new Map<String, Object>{'name' => 'Seed_StalledOrderSync', 'status' => 'Running', 'step' => 'Capture Payment', 'silentMinutes' => 45},
			new Map<String, Object>{'name' => 'Seed_StalledOrderSync', 'status' => 'Running', 'step' => 'Allocate Stock', 'silentMinutes' => 52},
			new Map<String, Object>{'name' => 'Seed_StalledOrderSync', 'status' => 'Running', 'step' => 'Publish Audit Event', 'silentMinutes' => 61},
			new Map<String, Object>{'name' => 'Seed_StalledLedgerPost', 'status' => 'Running', 'step' => 'Post Journal Lines', 'silentMinutes' => 47},
			new Map<String, Object>{'name' => 'Seed_StalledLedgerPost', 'status' => 'Running', 'step' => 'Recalculate Balance', 'silentMinutes' => 88},
			new Map<String, Object>{'name' => 'Seed_StalledLedgerPost', 'status' => 'Running', 'step' => 'Lock Period', 'silentMinutes' => 140},
			new Map<String, Object>{'name' => 'Seed_StalledArchiveSweep', 'status' => 'Stalled', 'step' => 'Archive Chunk 4', 'silentMinutes' => 190},
			new Map<String, Object>{'name' => 'Seed_StalledArchiveSweep', 'status' => 'Stalled', 'step' => 'Archive Chunk 9', 'silentMinutes' => 260},
			new Map<String, Object>{'name' => 'Seed_StalledCatalogRefresh', 'status' => 'Stalled', 'step' => 'Rebuild Price Book', 'silentMinutes' => 420},
			new Map<String, Object>{'name' => 'Seed_StalledCatalogRefresh', 'status' => 'Stalled', 'step' => 'Reindex Products', 'silentMinutes' => 1450}
	};

	List<SObject> stalledRows = new List<SObject>();
	for(Map<String, Object> specification : stalledSpecifications)
	{
		Integer silentMinutes = (Integer)specification.get('silentMinutes');
		String currentStep = (String)specification.get('step');
		List<Map<String, Object>> stepLog = new List<Map<String, Object>>
		{
				new Map<String, Object>{'className' => 'ReconciliationValidate', 'stepName' => 'Validate Payload', 'success' => true, 'durationMs' => 312},
				new Map<String, Object>{'className' => 'ReconciliationEnrich', 'stepName' => 'Enrich From Source', 'success' => true, 'durationMs' => 1187},
				new Map<String, Object>{'className' => 'ReconciliationUpsert', 'stepName' => 'Upsert Records', 'success' => true, 'durationMs' => 904},
				new Map<String, Object>{'className' => 'ReconciliationFinalise', 'stepName' => currentStep}
		};
		SObject stalled = chainType.newSObject();
		stalled.put(ns + 'ChainName__c', (String)specification.get('name'));
		stalled.put(ns + 'Status__c', (String)specification.get('status'));
		stalled.put(ns + 'CorrelationId__c', 'seed-stalled-' + run + '-' + synthesized);
		stalled.put(ns + 'CurrentStepName__c', currentStep);
		stalled.put(ns + 'TotalSteps__c', 4);
		stalled.put(ns + 'CompletedSteps__c', 3);
		stalled.put(ns + 'StartedAt__c', now.addMinutes(-(silentMinutes + 1)));
		stalled.put(ns + 'StepLog__c', JSON.serialize(stepLog));
		stalled.put('CreatedDate', now.addMinutes(-(silentMinutes + 1)));
		stalled.put('LastModifiedDate', now.addMinutes(-silentMinutes));
		stalledRows.add(stalled);
		synthesized++;
	}
	insert stalledRows;

	String probeQuery = 'SELECT LastModifiedDate FROM ' + ns + 'AsyncChainExecution__c'
			+ ' WHERE ' + ns + 'CorrelationId__c = \'seed-stalled-' + run + '-0\'';
	Datetime oldestSynthesized = (Datetime)Database.query(probeQuery)[0].get('LastModifiedDate');
	Boolean backDated = oldestSynthesized < Datetime.now().addMinutes(-40);
	System.debug('SEED_CHAIN_SCENARIOS_SYNTHESIS synthesized=' + synthesized + ' auditBackdate=' + (backDated ? 'OK' : 'FAILED_ENABLE_AUDIT_FIELDS'));
}

System.debug('SEED_CHAIN_SCENARIOS batch=' + batch + ' run=' + run + ' launched=' + launched + ' synthesized=' + synthesized
		+ ' dmlStatements=' + Limits.getDmlStatements() + '/' + Limits.getLimitDmlStatements()
		+ ' queueable=' + Limits.getQueueableJobs() + '/' + Limits.getLimitQueueableJobs()
		+ ' queries=' + Limits.getQueries() + '/' + Limits.getLimitQueries());
