// SPDX-License-Identifier: BUSL-1.1
//
// Log Console e2e seed fixture (PLAN-106 Phase 0 / R0 — one coherent, internally-consistent dataset).
//
// Tells ONE coherent story plus the supporting scenarios every Log Console surface needs:
//   - A REGISTERED async chain (the 4-step fulfilment incident that ends in a payment-callout timeout):
//     four correlated forensic LogEntry__c hops PLUS a matching AsyncChainExecution__c record, so
//     "Open in Chain Monitor" is live and the chain timeline renders.
//   - A NON-chain correlated request (a synchronous quote validation): three forensic rows that share a
//     CorrelationId__c but have NO AsyncChainExecution__c, so the chain-gating ("button only for a
//     registered chain") is demonstrable.
//   - A STANDALONE entry with no correlation.
//   - Recurring problems BOTH ways: fingerprinted (detail: + rollup: -> "Tagged") AND plain forensic
//     rows (Fingerprint__c = null -> the read-time derived fold groups them as "Grouped from logs").
//   - Every level (ERROR/WARN/INFO/DEBUG) and a spread of execution contexts.
//   - A full date spread for every range type: minute/hour/day offsets for the rolling presets, plus
//     local-timezone CALENDAR anchors (Today / Yesterday / This week / Last week / This month) and a
//     midnight-STRADDLE pair (23:30 yesterday + 00:30 today) that proves the presets are UTC-correct.
//   - Detail-pane variations (with/without stack, governor-limit bars, context JSON) and the empty state.
//
// TEARDOWN MARKER: fingerprinted rows carry an 'e2e-' Fingerprint__c; the null-fingerprint forensic rows
// (chain hops, correlated request, derived-fold input, calendar rows) are instead marked by an 'e2e-'
// CorrelationId__c or TransactionId__c. teardown-log-console.apex removes all three (and the chain record).
// This script's own idempotent clear is SCOPED to the shaped rows and deliberately spares the
// 'e2e-bulk-' rows from seed-log-console-bulk.apex.
//
// NAMESPACE-ROBUST: the namespace prefix is detected from the global describe and every SObject/field is
// built dynamically, so the SAME script seeds the no-namespace developer org (LogEntry__c) and the managed
// subscriber org (kern__LogEntry__c) without edits.
//
// PREREQUISITE - audit-field back-dating must be enabled in the target org, or the back-dated
// CreatedDate/LastModifiedDate silently fall to "now" and the time-window/calendar cases become invalid:
//   1. Deploy Settings:Security with <enableAuditFieldsInactiveOwner>true</enableAuditFieldsInactiveOwner>.
//   2. THEN (separately - doing both at once fails silently) deploy + assign a permission set granting the
//      CreateAuditFields user permission to the seeding user.
// Probe after enabling: insert one row with CreatedDate = now-3d and confirm the date stuck.

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

// Local-timezone calendar anchors (Datetime.newInstance(Date, Time) is interpreted in the running user's
// timezone) so the calendar presets and the midnight straddle are exercised in the viewer's own day.
Date today = Date.today();
Datetime todayMidnight = Datetime.newInstance(today, Time.newInstance(0, 0, 0, 0));
Datetime todayEarly = Datetime.newInstance(today, Time.newInstance(0, 30, 0, 0));         // 00:30 local TODAY
Datetime yesterdayLate = todayMidnight.addMinutes(-30);                                    // 23:30 local YESTERDAY (straddle)
Datetime yesterdayNoon = Datetime.newInstance(today.addDays(-1), Time.newInstance(12, 0, 0, 0));
Datetime lastWeekRow = Datetime.newInstance(today.addDays(-8), Time.newInstance(12, 0, 0, 0));
Datetime monthStartRow = Datetime.newInstance(today.toStartOfMonth(), Time.newInstance(9, 0, 0, 0));

// Idempotent: clear only THIS script's shaped rows (e2e- markers, but never the e2e-bulk- rows), and the
// shaped chain record. NOTE (load-bearing): SOQL evaluates `null LIKE 'x'` as FALSE (not UNKNOWN), so
// `NOT field LIKE '%e2e-bulk%'` is TRUE when that field is null — which is exactly why a shaped row whose
// Fingerprint__c is null still survives the bulk-exclusion via its CorrelationId__c / TransactionId__c
// marker. Do NOT "simplify" these three NOT-clauses to a single field or the null-fingerprint shaped rows
// would either leak or wrongly spare the bulk rows.
String fp = ns + 'Fingerprint__c';
String corr = ns + 'CorrelationId__c';
String txn = ns + 'TransactionId__c';
String shapedWhere = '((' + fp + ' LIKE \'%e2e-%\' OR ' + corr + ' LIKE \'e2e-%\' OR ' + txn + ' LIKE \'e2e-%\')'
		+ ' AND (NOT ' + fp + ' LIKE \'%e2e-bulk%\') AND (NOT ' + corr + ' LIKE \'%e2e-bulk%\') AND (NOT ' + txn + ' LIKE \'%e2e-bulk%\'))';
List<SObject> priorRows = Database.query('SELECT Id FROM ' + ns + 'LogEntry__c WHERE ' + shapedWhere);
if(!priorRows.isEmpty())
{
	delete priorRows;
}
List<SObject> priorChains = Database.query('SELECT Id FROM ' + ns + 'AsyncChainExecution__c WHERE ' + ns + 'CorrelationId__c LIKE \'e2e-%\'');
if(!priorChains.isEmpty())
{
	delete priorChains;
}

// Shared payloads for the fulfilment incident.
String CORR_CHAIN = 'e2e-corr-fulfil';
String CORR_SYNC = 'e2e-corr-sync';
Datetime c0 = t.addMinutes(-7);   // chain starts 7 minutes ago, so the whole incident sits inside the 15m preset
String STACK_TIMEOUT = 'System.CalloutException: Read timed out\n'
		+ '  at PaymentGateway.capture(PaymentGateway.cls:64)\n'
		+ '  at OrderService.finalisePayment(OrderService.cls:188)\n'
		+ '  at OrderService.processFulfilment(OrderService.cls:151)\n'
		+ '  at OrderFulfilmentQueueable.execute(OrderFulfilmentQueueable.cls:42)';
String CTX_TIMEOUT = '{"contextData":{"orderId":"a0H5g000004ZkLmEAK","amount":249.00,"currency":"USD","gateway":"stripe","attempt":3,"endpoint":"/v1/charges","timeoutMs":10000}}';
String LIMITS_TIMEOUT = '\nSOQL Queries: 32 of 100\nCPU Time: 4200 of 10000\nCallouts: 1 of 100\nDML Statements: 6 of 150\nHeap Size: 0 of 6000000';

// Each spec: custom-field shortnames -> values, plus optional _cd (CreatedDate) and _lmd (LastModifiedDate).
List<Map<String, Object>> specs = new List<Map<String, Object>>();

// ---- Severity paint: one detail exemplar per level, all in-window. ----
specs.add(new Map<String, Object>{'Fingerprint__c' => 'detail:e2e-paint-error', 'LogLevel__c' => 'ERROR', 'ShortMessage__c' => 'Severity paint check ERROR', 'ExceptionType__c' => 'System.NullPointerException', 'ClassMethod__c' => 'PaintProbe.error', 'LineNumber__c' => 10, 'ExecutionEvent__c' => 'SYNCHRONOUS', 'UserId__c' => me, '_cd' => t.addMinutes(-3)});
specs.add(new Map<String, Object>{'Fingerprint__c' => 'detail:e2e-paint-warn', 'LogLevel__c' => 'WARN', 'ShortMessage__c' => 'Severity paint check WARN', 'ClassMethod__c' => 'PaintProbe.warn', 'LineNumber__c' => 11, 'ExecutionEvent__c' => 'SYNCHRONOUS', 'UserId__c' => me, '_cd' => t.addMinutes(-3)});
specs.add(new Map<String, Object>{'Fingerprint__c' => 'detail:e2e-paint-info', 'LogLevel__c' => 'INFO', 'ShortMessage__c' => 'Severity paint check INFO', 'ClassMethod__c' => 'PaintProbe.info', 'LineNumber__c' => 12, 'ExecutionEvent__c' => 'SYNCHRONOUS', 'UserId__c' => me, '_cd' => t.addMinutes(-3)});
specs.add(new Map<String, Object>{'Fingerprint__c' => 'detail:e2e-paint-debug', 'LogLevel__c' => 'DEBUG', 'ShortMessage__c' => 'Severity paint check DEBUG', 'ClassMethod__c' => 'PaintProbe.debug', 'LineNumber__c' => 13, 'ExecutionEvent__c' => 'SYNCHRONOUS', 'UserId__c' => me, '_cd' => t.addMinutes(-3)});

// ---- Recurring TAGGED problems (detail sample + rollup counters) -> provenance "Tagged". ----
// High-occurrence ERROR with full detail-pane payload (count 240 across two days).
specs.add(new Map<String, Object>{'Fingerprint__c' => 'detail:e2e-npe-afterupdate', 'LogLevel__c' => 'ERROR', 'ShortMessage__c' => 'Attempt to de-reference a null object', 'Message__c' => 'System.NullPointerException: Attempt to de-reference a null object at AccountTriggerHandler.handleAfterUpdate line 142', 'StackTrace__c' => 'Class.AccountTriggerHandler.handleAfterUpdate: line 142, column 1\nClass.TriggerDispatcher.run: line 58, column 1', 'ExceptionType__c' => 'System.NullPointerException', 'ClassMethod__c' => 'AccountTriggerHandler.handleAfterUpdate', 'LineNumber__c' => 142, 'ExecutionEvent__c' => 'BATCH_APEX', 'RecordId__c' => '001000000000ABC', 'UserId__c' => me, 'DurationMs__c' => 1820, 'ContextData__c' => '{"contextData":{"recordCount":50,"sObjectType":"Account","operation":"AfterUpdate"}}', 'Limits__c' => '\nSOQL Queries: 47 of 100\nCPU Time: 8200 of 10000\nCallouts: 0 of 100\nDML Statements: 12 of 150', '_cd' => t.addDays(-3)});
specs.add(new Map<String, Object>{'Fingerprint__c' => 'rollup:e2e-npe-afterupdate:' + t.addDays(-3).formatGmt('yyyyMMdd'), 'LogLevel__c' => 'ERROR', 'OccurrenceCount__c' => 100, '_cd' => t.addDays(-3), '_lmd' => t.addDays(-3)});
specs.add(new Map<String, Object>{'Fingerprint__c' => 'rollup:e2e-npe-afterupdate:' + t.addHours(-5).formatGmt('yyyyMMdd'), 'LogLevel__c' => 'ERROR', 'OccurrenceCount__c' => 140, '_cd' => t.addHours(-5), '_lmd' => t.addHours(-2)});

// The fulfilment incident's payment timeout is ALSO a recurring Tagged problem (count 181) — the same
// signature the chain's terminal hop belongs to.
specs.add(new Map<String, Object>{'Fingerprint__c' => 'detail:e2e-pay-timeout', 'LogLevel__c' => 'ERROR', 'ShortMessage__c' => 'System.CalloutException: Read timed out', 'Message__c' => 'Read timed out after 10000ms calling the payment gateway', 'StackTrace__c' => STACK_TIMEOUT, 'ExceptionType__c' => 'System.CalloutException', 'ClassMethod__c' => 'PaymentGateway.capture', 'LineNumber__c' => 64, 'ExecutionEvent__c' => 'TRANSACTION_FINALIZER_QUEUEABLE', 'UserId__c' => me, 'DurationMs__c' => 10000, 'ContextData__c' => CTX_TIMEOUT, 'Limits__c' => LIMITS_TIMEOUT, '_cd' => t.addHours(-1)});
specs.add(new Map<String, Object>{'Fingerprint__c' => 'rollup:e2e-pay-timeout:' + t.addDays(-1).formatGmt('yyyyMMdd'), 'LogLevel__c' => 'ERROR', 'OccurrenceCount__c' => 70, '_cd' => t.addDays(-1), '_lmd' => t.addDays(-1)});
specs.add(new Map<String, Object>{'Fingerprint__c' => 'rollup:e2e-pay-timeout:' + t.addHours(-1).formatGmt('yyyyMMdd'), 'LogLevel__c' => 'ERROR', 'OccurrenceCount__c' => 111, '_cd' => t.addHours(-1), '_lmd' => t.addMinutes(-7)});

// Low-occurrence WARN (count 7) and an INFO signature (count 18) so the per-level cards render.
specs.add(new Map<String, Object>{'Fingerprint__c' => 'detail:e2e-slowquery', 'LogLevel__c' => 'WARN', 'ShortMessage__c' => 'Query exceeded soft time budget', 'Message__c' => 'Query took 4200ms (budget 2000ms)', 'ClassMethod__c' => 'AccountTriggerHandler.recalcRollups', 'LineNumber__c' => 88, 'ExecutionEvent__c' => 'QUEUEABLE', 'UserId__c' => me, 'DurationMs__c' => 4200, 'Limits__c' => '\nSOQL Queries: 12 of 100\nCPU Time: 9600 of 10000', '_cd' => t.addHours(-5)});
specs.add(new Map<String, Object>{'Fingerprint__c' => 'rollup:e2e-slowquery:' + t.addHours(-5).formatGmt('yyyyMMdd'), 'LogLevel__c' => 'WARN', 'OccurrenceCount__c' => 7, '_cd' => t.addHours(-5), '_lmd' => t.addHours(-4)});
specs.add(new Map<String, Object>{'Fingerprint__c' => 'detail:e2e-info-sync', 'LogLevel__c' => 'INFO', 'ShortMessage__c' => 'Integration sync completed', 'ClassMethod__c' => 'IntegrationService.sync', 'LineNumber__c' => 33, 'ExecutionEvent__c' => 'REST', 'UserId__c' => me, '_cd' => t.addHours(-2)});
specs.add(new Map<String, Object>{'Fingerprint__c' => 'rollup:e2e-info-sync:' + t.addHours(-2).formatGmt('yyyyMMdd'), 'LogLevel__c' => 'INFO', 'OccurrenceCount__c' => 18, '_cd' => t.addHours(-2), '_lmd' => t.addMinutes(-30)});

// Window-correctness regression: exemplar back-dated 3 days, rollup TODAY -> must appear in the 24h window.
specs.add(new Map<String, Object>{'Fingerprint__c' => 'detail:e2e-longlived', 'LogLevel__c' => 'ERROR', 'ShortMessage__c' => 'Recurring callout timeout (long-lived)', 'Message__c' => 'Read timed out after 30000ms', 'ExceptionType__c' => 'System.CalloutException', 'ClassMethod__c' => 'PaymentGateway.charge', 'LineNumber__c' => 210, 'ExecutionEvent__c' => 'FUTURE', 'UserId__c' => me, '_cd' => t.addDays(-3)});
specs.add(new Map<String, Object>{'Fingerprint__c' => 'rollup:e2e-longlived:' + t.addMinutes(-30).formatGmt('yyyyMMdd'), 'LogLevel__c' => 'ERROR', 'OccurrenceCount__c' => 9, '_cd' => t.addMinutes(-30), '_lmd' => t.addMinutes(-5)});

// All-old negative case: every rollup > 7 days ago -> must NOT appear in any rolling preset window.
specs.add(new Map<String, Object>{'Fingerprint__c' => 'detail:e2e-allold', 'LogLevel__c' => 'WARN', 'ShortMessage__c' => 'Stale signature from 10 days ago', 'ClassMethod__c' => 'LegacyJob.run', 'LineNumber__c' => 5, 'ExecutionEvent__c' => 'SCHEDULED', 'UserId__c' => me, '_cd' => t.addDays(-10)});
specs.add(new Map<String, Object>{'Fingerprint__c' => 'rollup:e2e-allold:' + t.addDays(-10).formatGmt('yyyyMMdd'), 'LogLevel__c' => 'WARN', 'OccurrenceCount__c' => 50, '_cd' => t.addDays(-10), '_lmd' => t.addDays(-9)});

// Detail-pane variation: no stack, class-only ClassMethod, no Limits -> empty stack tab + bare class source.
specs.add(new Map<String, Object>{'Fingerprint__c' => 'detail:e2e-nostack', 'LogLevel__c' => 'INFO', 'ShortMessage__c' => 'Feature flag evaluated', 'Message__c' => 'Flag EnableX = true', 'ClassMethod__c' => 'FeatureFlagService', 'ExecutionEvent__c' => 'AURA', 'UserId__c' => me, '_cd' => t.addMinutes(-20)});

// ---- DERIVED-fold input (Fingerprint__c = null, >= 2 occurrences each) -> provenance "Grouped from logs".
// These are the rows the read-time GROUP BY folds; null fingerprint is REQUIRED for the fold to see them,
// so they are marked for teardown by an 'e2e-derived-*' TransactionId__c instead.
List<Map<String, Object>> derivedSigs = new List<Map<String, Object>>
{
		new Map<String, Object>{'lvl' => 'WARN', 'cls' => 'InventoryService.reserve', 'line' => 210, 'ctx' => 'QUEUEABLE', 'msg' => 'Low stock — partial reserve', 'exc' => null, 'n' => 3},
		new Map<String, Object>{'lvl' => 'WARN', 'cls' => 'PaymentGateway.retry', 'line' => 45, 'ctx' => 'ANONYMOUS', 'msg' => 'Retry scheduled after gateway 503', 'exc' => null, 'n' => 3},
		new Map<String, Object>{'lvl' => 'INFO', 'cls' => 'CartController.checkout', 'line' => 44, 'ctx' => 'AURA', 'msg' => 'Checkout completed', 'exc' => null, 'n' => 3},
		new Map<String, Object>{'lvl' => 'ERROR', 'cls' => 'SyncScheduler.run', 'line' => 276, 'ctx' => 'SCHEDULED', 'msg' => 'System.LimitException: Apex CPU time limit exceeded', 'exc' => 'System.LimitException', 'n' => 2}
};
Integer derivedSeq = 0;
for(Map<String, Object> sig : derivedSigs)
{
	Integer occurrences = (Integer)sig.get('n');
	for(Integer i = 0; i < occurrences; i++)
	{
		specs.add(new Map<String, Object>{'LogLevel__c' => (String)sig.get('lvl'), 'ShortMessage__c' => (String)sig.get('msg'), 'Message__c' => (String)sig.get('msg') + ' (occurrence ' + (i + 1) + ')', 'ExceptionType__c' => (String)sig.get('exc'), 'ClassMethod__c' => (String)sig.get('cls'), 'LineNumber__c' => (Integer)sig.get('line'), 'ExecutionEvent__c' => (String)sig.get('ctx'), 'TransactionId__c' => 'e2e-derived-' + derivedSeq, 'UserId__c' => me, '_cd' => t.addMinutes(-(15 + derivedSeq * 7))});
		derivedSeq++;
	}
}

// ---- REGISTERED async chain (the fulfilment incident): four correlated forensic hops (Fingerprint null).
// hop 4 is the terminal payment-callout timeout. A matching AsyncChainExecution__c is inserted below.
specs.add(new Map<String, Object>{'LogLevel__c' => 'DEBUG', 'ShortMessage__c' => 'Order submission received', 'ClassMethod__c' => 'OrderController.submit', 'LineNumber__c' => 88, 'ExecutionEvent__c' => 'AURA', 'CorrelationId__c' => CORR_CHAIN, 'TransactionId__c' => 'e2e-fulfil-0', 'UserId__c' => me, 'DurationMs__c' => 40, '_cd' => c0});
specs.add(new Map<String, Object>{'LogLevel__c' => 'INFO', 'ShortMessage__c' => 'Enqueued fulfilment job', 'ClassMethod__c' => 'OrderService.enqueueFulfilment', 'LineNumber__c' => 142, 'ExecutionEvent__c' => 'QUEUEABLE', 'CorrelationId__c' => CORR_CHAIN, 'TransactionId__c' => 'e2e-fulfil-1', 'ParentTransactionId__c' => 'e2e-fulfil-0', 'UserId__c' => me, 'DurationMs__c' => 95, '_cd' => c0.addSeconds(24)});
// Distinct method ('reserveForOrder') so this one incident hop does NOT fold into the recurring
// 'InventoryService.reserve' derived signature below (which must stay an exact count of 3).
specs.add(new Map<String, Object>{'LogLevel__c' => 'WARN', 'ShortMessage__c' => 'Low stock — partial reserve (8 of 12 units)', 'ClassMethod__c' => 'InventoryService.reserveForOrder', 'LineNumber__c' => 214, 'ExecutionEvent__c' => 'QUEUEABLE', 'CorrelationId__c' => CORR_CHAIN, 'TransactionId__c' => 'e2e-fulfil-2', 'ParentTransactionId__c' => 'e2e-fulfil-1', 'UserId__c' => me, 'DurationMs__c' => 120, 'ContextData__c' => '{"contextData":{"sku":"WIDGET-8821","requested":12,"reserved":8}}', '_cd' => c0.addSeconds(120)});
specs.add(new Map<String, Object>{'LogLevel__c' => 'ERROR', 'ShortMessage__c' => 'System.CalloutException: Read timed out', 'Message__c' => 'Read timed out after 10000ms calling the payment gateway', 'StackTrace__c' => STACK_TIMEOUT, 'ExceptionType__c' => 'System.CalloutException', 'ClassMethod__c' => 'PaymentGateway.capture', 'LineNumber__c' => 64, 'ExecutionEvent__c' => 'TRANSACTION_FINALIZER_QUEUEABLE', 'CorrelationId__c' => CORR_CHAIN, 'TransactionId__c' => 'e2e-fulfil-3', 'ParentTransactionId__c' => 'e2e-fulfil-2', 'RecordId__c' => 'a0H5g000004ZkLm', 'UserId__c' => me, 'DurationMs__c' => 10000, 'ContextData__c' => CTX_TIMEOUT, 'Limits__c' => LIMITS_TIMEOUT, '_cd' => c0.addSeconds(240)});

// ---- NON-chain correlated request (synchronous quote validation): shares a CorrelationId__c but has NO
// AsyncChainExecution__c, so the redesigned console must show the timeline yet HIDE "Open in Chain Monitor".
Datetime s0 = t.addMinutes(-20);
specs.add(new Map<String, Object>{'LogLevel__c' => 'DEBUG', 'ShortMessage__c' => 'Validating quote line items', 'ClassMethod__c' => 'QuoteController.validate', 'LineNumber__c' => 55, 'ExecutionEvent__c' => 'AURA', 'CorrelationId__c' => CORR_SYNC, 'TransactionId__c' => 'e2e-sync-0', 'UserId__c' => me, 'DurationMs__c' => 12, '_cd' => s0});
specs.add(new Map<String, Object>{'LogLevel__c' => 'INFO', 'ShortMessage__c' => 'All line items valid', 'ClassMethod__c' => 'QuoteController.validate', 'LineNumber__c' => 71, 'ExecutionEvent__c' => 'AURA', 'CorrelationId__c' => CORR_SYNC, 'TransactionId__c' => 'e2e-sync-1', 'ParentTransactionId__c' => 'e2e-sync-0', 'UserId__c' => me, 'DurationMs__c' => 3, '_cd' => s0.addSeconds(1)});
specs.add(new Map<String, Object>{'LogLevel__c' => 'WARN', 'ShortMessage__c' => 'Discount exceeds threshold, capped at 20%', 'ClassMethod__c' => 'DiscountEngine.apply', 'LineNumber__c' => 140, 'ExecutionEvent__c' => 'SYNCHRONOUS', 'CorrelationId__c' => CORR_SYNC, 'TransactionId__c' => 'e2e-sync-2', 'ParentTransactionId__c' => 'e2e-sync-1', 'UserId__c' => me, 'ContextData__c' => '{"contextData":{"requested":"35%","cap":"20%","quoteId":"0Q05g00000ABCdE"}}', '_cd' => s0.addSeconds(2)});

// ---- Standalone, no-correlation forensic rows (the "stands alone" branch). ----
specs.add(new Map<String, Object>{'LogLevel__c' => 'WARN', 'ShortMessage__c' => 'Plain warn, no correlation', 'ClassMethod__c' => 'StandaloneCheck.verify', 'LineNumber__c' => 3, 'ExecutionEvent__c' => 'SYNCHRONOUS', 'TransactionId__c' => 'e2e-standalone-1', 'UserId__c' => me, '_cd' => t.addHours(-5)});
specs.add(new Map<String, Object>{'LogLevel__c' => 'DEBUG', 'ShortMessage__c' => 'Plain debug entry A', 'ClassMethod__c' => 'AdhocScript.run', 'LineNumber__c' => 1, 'ExecutionEvent__c' => 'ANONYMOUS', 'TransactionId__c' => 'e2e-standalone-2', 'UserId__c' => me, '_cd' => t.addMinutes(-8)});

// ---- Calendar + midnight-straddle rows (local timezone) so every date-range TYPE is verifiable. ----
specs.add(new Map<String, Object>{'LogLevel__c' => 'INFO', 'ShortMessage__c' => 'Calendar probe — today 00:30 local', 'ClassMethod__c' => 'CalendarProbe.today', 'LineNumber__c' => 1, 'ExecutionEvent__c' => 'BATCH_APEX', 'TransactionId__c' => 'e2e-cal-today', 'UserId__c' => me, '_cd' => todayEarly});
specs.add(new Map<String, Object>{'LogLevel__c' => 'INFO', 'ShortMessage__c' => 'Calendar probe — yesterday 23:30 local (midnight straddle)', 'ClassMethod__c' => 'CalendarProbe.midnight', 'LineNumber__c' => 2, 'ExecutionEvent__c' => 'BATCH_APEX', 'TransactionId__c' => 'e2e-cal-straddle', 'UserId__c' => me, '_cd' => yesterdayLate});
specs.add(new Map<String, Object>{'LogLevel__c' => 'INFO', 'ShortMessage__c' => 'Calendar probe — yesterday noon local', 'ClassMethod__c' => 'CalendarProbe.yesterday', 'LineNumber__c' => 3, 'ExecutionEvent__c' => 'REST', 'TransactionId__c' => 'e2e-cal-yesterday', 'UserId__c' => me, '_cd' => yesterdayNoon});
specs.add(new Map<String, Object>{'LogLevel__c' => 'INFO', 'ShortMessage__c' => 'Calendar probe — eight days ago (last week)', 'ClassMethod__c' => 'CalendarProbe.lastWeek', 'LineNumber__c' => 4, 'ExecutionEvent__c' => 'SCHEDULED', 'TransactionId__c' => 'e2e-cal-lastweek', 'UserId__c' => me, '_cd' => lastWeekRow});
specs.add(new Map<String, Object>{'LogLevel__c' => 'INFO', 'ShortMessage__c' => 'Calendar probe — start of month 09:00 local', 'ClassMethod__c' => 'CalendarProbe.monthStart', 'LineNumber__c' => 5, 'ExecutionEvent__c' => 'FUTURE', 'TransactionId__c' => 'e2e-cal-month', 'UserId__c' => me, '_cd' => monthStartRow});

// ---- Build + insert the LogEntry__c rows. ----
List<SObject> rows = new List<SObject>();
for(Map<String, Object> spec : specs)
{
	SObject r = leType.newSObject();
	for(String k : spec.keySet())
	{
		if(k.startsWith('_') || spec.get(k) == null)
		{
			continue;
		}
		r.put(ns + k, spec.get(k));
	}
	if(spec.containsKey('_cd'))
	{
		r.put('CreatedDate', (Datetime)spec.get('_cd'));
	}
	if(spec.containsKey('_lmd'))
	{
		r.put('LastModifiedDate', (Datetime)spec.get('_lmd'));
	}
	rows.add(r);
}
insert rows;

// ---- Build + insert the registered chain record for the fulfilment incident. ----
List<Map<String, Object>> stepLog = new List<Map<String, Object>>
{
		new Map<String, Object>{'className' => 'OrderController', 'stepName' => 'Submit order', 'success' => true, 'continueOnError' => false, 'durationMs' => 40},
		new Map<String, Object>{'className' => 'OrderService', 'stepName' => 'Enqueue fulfilment', 'success' => true, 'continueOnError' => false, 'durationMs' => 95},
		new Map<String, Object>{'className' => 'InventoryService', 'stepName' => 'Reserve stock', 'success' => false, 'continueOnError' => true, 'durationMs' => 120, 'message' => 'Low stock — partial reserve (8 of 12 units)'},
		new Map<String, Object>{'className' => 'PaymentGateway', 'stepName' => 'Capture payment', 'success' => false, 'continueOnError' => false, 'durationMs' => 10000, 'message' => 'System.CalloutException: Read timed out'}
};
SObject chain = chainType.newSObject();
chain.put(ns + 'ChainName__c', 'Order Fulfilment');
chain.put(ns + 'Status__c', 'Failed');
chain.put(ns + 'CorrelationId__c', CORR_CHAIN);
chain.put(ns + 'TotalSteps__c', 4);
chain.put(ns + 'CompletedSteps__c', 2);   // framework counts only successful steps (Submit + Enqueue); Reserve warned, Capture failed
chain.put(ns + 'StartedAt__c', c0);
chain.put(ns + 'CompletedAt__c', c0.addSeconds(240));
chain.put(ns + 'DurationMs__c', 240000);
chain.put(ns + 'ErrorMessage__c', 'System.CalloutException: Read timed out');
chain.put(ns + 'ContextData__c', '{"orderId":"a0H5g000004ZkLmEAK","amount":249.00,"currency":"USD","gateway":"stripe"}');
chain.put(ns + 'StepLog__c', JSON.serialize(stepLog));
chain.put('CreatedDate', c0);
insert chain;

// ---- Audit-field probe: confirm the back-date stuck (else every time-window/calendar case is invalid).
Datetime oldest = (Datetime)Database.query('SELECT CreatedDate FROM ' + ns + 'LogEntry__c WHERE ' + ns + 'Fingerprint__c = \'detail:e2e-allold\'')[0].get('CreatedDate');
Boolean backdated = (Datetime.now().getTime() - oldest.getTime()) / 86400000L >= 7;
System.debug('SEED_LOG_CONSOLE ns=[' + ns + '] logRows=' + rows.size() + ' chainRows=1 auditBackdate=' + (backdated ? 'OK' : 'FAILED_ENABLE_AUDIT_FIELDS'));
