// SPDX-License-Identifier: Apache-2.0
//
// Log Console e2e seed fixture, second part: the whole-action rows. Runs right after seed-log-console.apex,
// which lays down the rest of the story. The two are split because anonymous Apex refuses a script over
// 32,000 characters, and one file no longer fit.
//
// What it seeds: the checkout click's own two entries and its three chains (Ledger nested under Reserve), the
// nightly job that started its own action and its restart, and a legacy action recorded before roots existed.
// Every id starts with 'e2ee2ee2', the shape the framework mints; teardown-log-console.apex removes them all.
//
// Idempotent: it first clears every log row and chain run in the 'e2ee2ee2' family, so it can run again on its
// own. NAMESPACE-ROBUST and audit-field PREREQUISITE: as seed-log-console.apex.

String ns = '';
for(String key : Schema.getGlobalDescribe().keySet())
{
	if(key.endsWith('logentry__c'))
	{
		ns = key.substring(0, key.length() - 'logentry__c'.length());
		break;
	}
}
SObjectType leType = Schema.getGlobalDescribe().get(ns + 'LogEntry__c');
SObjectType chainType = Schema.getGlobalDescribe().get(ns + 'AsyncChainExecution__c');
String me = UserInfo.getUserId();
Datetime t = Datetime.now();

List<SObject> priorRows = Database.query('SELECT Id FROM ' + ns + 'LogEntry__c WHERE ' + ns + 'CorrelationId__c LIKE \'e2ee2ee2%\''
		+ ' OR ' + ns + 'RootCorrelationId__c LIKE \'e2ee2ee2%\'');
if(!priorRows.isEmpty())
{
	delete priorRows;
}
List<SObject> priorChains = Database.query('SELECT Id FROM ' + ns + 'AsyncChainExecution__c WHERE ' + ns + 'CorrelationId__c LIKE \'e2ee2ee2%\'');
if(!priorChains.isEmpty())
{
	delete priorChains;
}

// ---- Whole-action fixture ids, in the shape the framework mints. ----
String ACTION_CHECKOUT = 'e2ee2ee2-0000-4000-8000-000000000a01';   // a click: entries, two chains, one nested
String CHAIN_RESERVE = 'e2ee2ee2-0000-4000-8000-000000000a0a';     // launched by the click
String CHAIN_NOTIFY = 'e2ee2ee2-0000-4000-8000-000000000a0b'; // launched by the click, failed
String CHAIN_LEDGER = 'e2ee2ee2-0000-4000-8000-000000000a0c'; // launched by a step of Reserve
String ACTION_NIGHTLY = 'e2ee2ee2-0000-4000-8000-000000000b01';    // a scheduled job: its own id is the root
String CHAIN_NIGHTLY_RESTART = 'e2ee2ee2-0000-4000-8000-000000000b02';
String ACTION_LEGACY = 'e2ee2ee2-0000-4000-8000-000000000c01';     // recorded before roots: no root anywhere
Datetime a0 = t.addMinutes(-40);
Datetime n0 = t.addHours(-3);
Datetime l0 = t.addHours(-2);

// ---- The whole action's log rows. Columns: level, short message, class.method, line, execution context,
// correlation, root (null for the legacy pair), transaction, created; the failed hop carries two more, its
// message and its exception type.
List<List<Object>> actionRows = new List<List<Object>>
{
		new List<Object>{'INFO', 'Checkout submitted', 'CheckoutController.submit', 30, 'AURA', ACTION_CHECKOUT, ACTION_CHECKOUT, 'e2e-action-0', a0},
		new List<Object>{'INFO', 'Checkout launched three chains', 'CheckoutController.submit', 48, 'AURA', ACTION_CHECKOUT, ACTION_CHECKOUT, 'e2e-action-0', a0.addSeconds(2)},
		new List<Object>{'INFO', 'Reserving stock for the checkout', 'ReserveStep.execute', 12, 'QUEUEABLE', CHAIN_RESERVE, ACTION_CHECKOUT, 'e2e-action-1', a0.addSeconds(20)},
		new List<Object>{'ERROR', 'Notification gateway refused the checkout', 'NotifyStep.execute', 40, 'QUEUEABLE', CHAIN_NOTIFY, ACTION_CHECKOUT, 'e2e-action-2',
				a0.addSeconds(45), 'HTTP 503 from the notification gateway', 'System.CalloutException'},
		new List<Object>{'INFO', 'Ledger posted for the checkout', 'LedgerStep.execute', 9, 'QUEUEABLE', CHAIN_LEDGER, ACTION_CHECKOUT, 'e2e-action-3', a0.addSeconds(70)},
		new List<Object>{'ERROR', 'Nightly sync failed at the ledger', 'NightlySyncStep.execute', 77, 'SCHEDULED', ACTION_NIGHTLY, ACTION_NIGHTLY, 'e2e-action-4', n0},
		new List<Object>{'INFO', 'Nightly sync restarted and completed', 'NightlySyncStep.execute', 77, 'QUEUEABLE', CHAIN_NIGHTLY_RESTART, ACTION_NIGHTLY, 'e2e-action-5',
				n0.addMinutes(30)},
		new List<Object>{'INFO', 'Legacy fulfilment started', 'LegacyFulfilment.start', 5, 'AURA', ACTION_LEGACY, null, 'e2e-action-6', l0},
		new List<Object>{'WARN', 'Legacy fulfilment step warned', 'LegacyFulfilment.step', 21, 'QUEUEABLE', ACTION_LEGACY, null, 'e2e-action-7', l0.addSeconds(30)}
};
// Each row takes the attribution the first script gives a row with a class.method: origin APEX, and the class as
// its source.
List<SObject> rows = new List<SObject>();
for(List<Object> actionRow : actionRows)
{
	SObject r = leType.newSObject();
	r.put(ns + 'LogLevel__c', actionRow[0]);
	r.put(ns + 'ShortMessage__c', actionRow[1]);
	r.put(ns + 'ClassMethod__c', actionRow[2]);
	r.put(ns + 'LineNumber__c', actionRow[3]);
	r.put(ns + 'ExecutionEvent__c', actionRow[4]);
	r.put(ns + 'CorrelationId__c', actionRow[5]);
	if(actionRow[6] != null)
	{
		r.put(ns + 'RootCorrelationId__c', actionRow[6]);
	}
	r.put(ns + 'TransactionId__c', actionRow[7]);
	r.put(ns + 'UserId__c', me);
	r.put(ns + 'Origin__c', 'APEX');
	r.put(ns + 'Source__c', ((String)actionRow[2]).substringBefore('.'));
	if(actionRow.size() > 9)
	{
		r.put(ns + 'Message__c', actionRow[9]);
		r.put(ns + 'ExceptionType__c', actionRow[10]);
	}
	r.put('CreatedDate', (Datetime)actionRow[8]);
	rows.add(r);
}
insert rows;

// ---- The whole-action runs: three under the checkout (one nested), the nightly job and its restart, the legacy adopter.
List<SObject> actionChains = new List<SObject>();
Map<String, SObject> chainsByCorrelation = new Map<String, SObject>();
List<List<Object>> runSpecs = new List<List<Object>>
{
		new List<Object>{'E2E Checkout Reserve', 'Completed', CHAIN_RESERVE, ACTION_CHECKOUT, ACTION_CHECKOUT, a0.addSeconds(10), a0.addSeconds(30)},
		new List<Object>{'E2E Checkout Notify', 'Failed', CHAIN_NOTIFY, ACTION_CHECKOUT, ACTION_CHECKOUT, a0.addSeconds(12), a0.addSeconds(45)},
		new List<Object>{'E2E Checkout Ledger', 'Completed', CHAIN_LEDGER, ACTION_CHECKOUT, CHAIN_RESERVE, a0.addSeconds(25), a0.addSeconds(70)},
		new List<Object>{'E2E Nightly Sync', 'Failed', ACTION_NIGHTLY, ACTION_NIGHTLY, null, n0, n0.addMinutes(2)},
		new List<Object>{'E2E Legacy Fulfilment', 'Completed', ACTION_LEGACY, null, null, l0, l0.addSeconds(40)}
};
for(List<Object> runSpec : runSpecs)
{
	SObject run = chainType.newSObject();
	run.put(ns + 'ChainName__c', runSpec[0]);
	run.put(ns + 'Status__c', runSpec[1]);
	run.put(ns + 'CorrelationId__c', runSpec[2]);
	if(runSpec[3] != null)
	{
		run.put(ns + 'RootCorrelationId__c', runSpec[3]);
	}
	if(runSpec[4] != null)
	{
		run.put(ns + 'LaunchCorrelationId__c', runSpec[4]);
	}
	run.put(ns + 'TotalSteps__c', 1);
	run.put(ns + 'CompletedSteps__c', runSpec[1] == 'Completed' ? 1 : 0);
	run.put(ns + 'StartedAt__c', (Datetime)runSpec[5]);
	run.put(ns + 'CompletedAt__c', (Datetime)runSpec[6]);
	if(runSpec[1] == 'Failed')
	{
		run.put(ns + 'FailureCategory__c', 'StepException');
	}
	run.put(ns + 'StepLog__c', '[{"className":"E2EActionStep","success":' + (runSpec[1] == 'Completed' ? 'true' : 'false') + ',"durationMs":500}]');
	run.put('CreatedDate', (Datetime)runSpec[5]);
	actionChains.add(run);
	chainsByCorrelation.put((String)runSpec[2], run);
}
insert actionChains;
// The nightly job's restart clone: no launch id, the job as its source, the job's id as its root.
SObject nightlyRestart = chainType.newSObject();
nightlyRestart.put(ns + 'ChainName__c', 'E2E Nightly Sync');
nightlyRestart.put(ns + 'Status__c', 'Completed');
nightlyRestart.put(ns + 'CorrelationId__c', CHAIN_NIGHTLY_RESTART);
nightlyRestart.put(ns + 'RootCorrelationId__c', ACTION_NIGHTLY);
nightlyRestart.put(ns + 'SourceExecution__c', chainsByCorrelation.get(ACTION_NIGHTLY).Id);
nightlyRestart.put(ns + 'TotalSteps__c', 1);
nightlyRestart.put(ns + 'CompletedSteps__c', 1);
nightlyRestart.put(ns + 'StartedAt__c', n0.addMinutes(30));
nightlyRestart.put(ns + 'CompletedAt__c', n0.addMinutes(31));
nightlyRestart.put(ns + 'StepLog__c', '[{"className":"E2EActionStep","success":true,"durationMs":500}]');
nightlyRestart.put('CreatedDate', n0.addMinutes(30));
insert nightlyRestart;

System.debug('SEED_LOG_CONSOLE_ACTIONS ns=[' + ns + '] logRows=' + rows.size() + ' chainRows=' + (actionChains.size() + 1));
