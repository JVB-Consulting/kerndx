// SPDX-License-Identifier: BUSL-1.1
//
// Log Console BULK + Phase-3 seed fixture.
//
// Layers high-volume data on top of (or independently of) the shaped seed-log-console.apex so the
// console can be exercised for PAGING and PERFORMANCE, and adds the Phase-3-specific scenarios:
//   - SOSL body-only matches (a token present ONLY in Message__c / StackTrace__c, never ShortMessage__c)
//   - correlation-searchable rows (a distinctive CorrelationId__c token)
//   - NEW (first-seen < 180m) and RISING (last-seen < 12m AND count >= 200) recency-badge candidates
//   - a suppressable non-ERROR class and an ERROR class whose suppression must be rejected
//   - custom-range-only rows (older than the 7d preset) that surface ONLY via a custom date range
//   - bulk distinct signatures (detail: + rollup:) and bulk plain "All entries" rows
//
// All fingerprints are 'e2e-bulk-' prefixed and the script first clears only its own rows, so it
// coexists with the shaped 'e2e-' seed. teardown-log-console.apex (LIKE '%e2e-%') removes both.
//
// NAMESPACE-ROBUST: prefix detected from the global describe; every SObject/field built dynamically.
// PREREQUISITE: audit-field back-dating enabled (see seed-log-console.apex header) or back-dated
// CreatedDate/LastModifiedDate silently fall to now and the window/recency cases become invalid.
// Inserts in batches of 1000 to keep heap bounded under the synchronous 6MB limit.

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
String me = UserInfo.getUserId();
Datetime t = Datetime.now();

// Idempotent: clear only this script's bulk rows — fingerprinted AND the null-fingerprint plain rows, the
// latter marked by an 'e2e-bulk-' TransactionId__c / CorrelationId__c so they stay teardown-safe.
String bfp = ns + 'Fingerprint__c';
String bcorr = ns + 'CorrelationId__c';
String btxn = ns + 'TransactionId__c';
List<SObject> prior = Database.query('SELECT Id FROM ' + ns + 'LogEntry__c WHERE ' + bfp + ' LIKE \'%e2e-bulk-%\' OR ' + bcorr + ' LIKE \'e2e-bulk-%\' OR ' + btxn + ' LIKE \'e2e-bulk-%\'');
if(!prior.isEmpty())
{
	delete prior;
}

List<String> levels = new List<String>{'ERROR', 'WARN', 'INFO', 'DEBUG'};
List<String> contexts = new List<String>{'SYNCHRONOUS', 'BATCH_APEX', 'QUEUEABLE', 'FUTURE', 'SCHEDULED', 'REST', 'AURA', 'ANONYMOUS', 'TRANSACTION_FINALIZER_QUEUEABLE'};
List<String> classes = new List<String>{'OrderService', 'AccountTriggerHandler', 'InvoiceBatch', 'PricingClient', 'IntegrationService', 'PaymentGateway', 'SyncScheduler', 'CartController', 'LedgerJob', 'NotificationService'};
List<Integer> minuteOffsets = new List<Integer>{2, 10, 40, 180, 540, 1200, 2880, 7200};   // 2m .. 5d, all within the 7d preset

List<Map<String, Object>> specs = new List<Map<String, Object>>();

// ---- Targeted Phase-3 scenarios (distinctive fingerprints for precise test assertions) ----

// SOSL body-only match: the token APRICOTSWIFT lives only in Message__c + StackTrace__c, never ShortMessage__c.
specs.add(new Map<String, Object>{'Fingerprint__c' => 'detail:e2e-bulk-sosl-body', 'LogLevel__c' => 'ERROR', 'ShortMessage__c' => 'Unhandled exception in handler', 'Message__c' => 'System.DmlException: APRICOTSWIFT constraint violated during upsert', 'StackTrace__c' => 'Class.OrderService.commitWork: line 77\nAPRICOTSWIFT_TRACE_MARKER', 'ExceptionType__c' => 'System.DmlException', 'ClassMethod__c' => 'OrderService.commitWork', 'LineNumber__c' => 77, 'ExecutionEvent__c' => 'SYNCHRONOUS', 'UserId__c' => me, '_cd' => t.addMinutes(-12)});
specs.add(new Map<String, Object>{'Fingerprint__c' => 'rollup:e2e-bulk-sosl-body:' + t.addMinutes(-12).formatGmt('yyyyMMdd'), 'LogLevel__c' => 'ERROR', 'OccurrenceCount__c' => 3, '_cd' => t.addMinutes(-12), '_lmd' => t.addMinutes(-6)});

// Correlation-searchable: a distinctive correlation token to test free-text correlation search.
specs.add(new Map<String, Object>{'Fingerprint__c' => 'e2e-bulk-corrsearch', 'LogLevel__c' => 'INFO', 'ShortMessage__c' => 'Checkout step recorded', 'ClassMethod__c' => 'CartController.checkout', 'LineNumber__c' => 21, 'ExecutionEvent__c' => 'AURA', 'CorrelationId__c' => 'e2e-bulk-corr-MANGOLARK', 'TransactionId__c' => 'e2e-bulk-txn-cs', 'UserId__c' => me, '_cd' => t.addMinutes(-9)});

// NEW signature: first-seen 30m ago (< 180m) -> NEW badge; modest count.
specs.add(new Map<String, Object>{'Fingerprint__c' => 'detail:e2e-bulk-new', 'LogLevel__c' => 'WARN', 'ShortMessage__c' => 'Newly appearing rate-limit warning', 'Message__c' => 'Throttled by downstream API (HTTP 429)', 'ClassMethod__c' => 'IntegrationService.push', 'LineNumber__c' => 144, 'ExecutionEvent__c' => 'FUTURE', 'UserId__c' => me, '_cd' => t.addMinutes(-30)});
specs.add(new Map<String, Object>{'Fingerprint__c' => 'rollup:e2e-bulk-new:' + t.addMinutes(-30).formatGmt('yyyyMMdd'), 'LogLevel__c' => 'WARN', 'OccurrenceCount__c' => 12, '_cd' => t.addMinutes(-30), '_lmd' => t.addMinutes(-10)});

// RISING signature: last-seen 5m ago AND count >= 200 -> RISING badge.
specs.add(new Map<String, Object>{'Fingerprint__c' => 'detail:e2e-bulk-rising', 'LogLevel__c' => 'ERROR', 'ShortMessage__c' => 'Spiking lock contention', 'Message__c' => 'UNABLE_TO_LOCK_ROW: rising contention on Account rollups', 'ExceptionType__c' => 'System.DmlException', 'ClassMethod__c' => 'LedgerJob.post', 'LineNumber__c' => 301, 'ExecutionEvent__c' => 'BATCH_APEX', 'UserId__c' => me, '_cd' => t.addHours(-2)});
specs.add(new Map<String, Object>{'Fingerprint__c' => 'rollup:e2e-bulk-rising:' + t.formatGmt('yyyyMMdd'), 'LogLevel__c' => 'ERROR', 'OccurrenceCount__c' => 260, '_cd' => t.addHours(-2), '_lmd' => t.addMinutes(-5)});

// Suppressable non-ERROR class (NoisyBatchJob) -> suppressClass('NoisyBatchJob','WARN') allowed.
specs.add(new Map<String, Object>{'Fingerprint__c' => 'detail:e2e-bulk-suppressable', 'LogLevel__c' => 'WARN', 'ShortMessage__c' => 'Noisy batch chatter', 'Message__c' => 'Processed chunk 17 of 200', 'ClassMethod__c' => 'NoisyBatchJob.execute', 'LineNumber__c' => 52, 'ExecutionEvent__c' => 'BATCH_APEX', 'UserId__c' => me, '_cd' => t.addMinutes(-25)});
specs.add(new Map<String, Object>{'Fingerprint__c' => 'rollup:e2e-bulk-suppressable:' + t.addMinutes(-25).formatGmt('yyyyMMdd'), 'LogLevel__c' => 'WARN', 'OccurrenceCount__c' => 95, '_cd' => t.addMinutes(-25), '_lmd' => t.addMinutes(-3)});

// ERROR class whose suppression must be rejected by the server guard.
specs.add(new Map<String, Object>{'Fingerprint__c' => 'detail:e2e-bulk-errorclass', 'LogLevel__c' => 'ERROR', 'ShortMessage__c' => 'Critical failure (never suppressible)', 'Message__c' => 'System.CalloutException: gateway down', 'ExceptionType__c' => 'System.CalloutException', 'ClassMethod__c' => 'CriticalHandler.run', 'LineNumber__c' => 9, 'ExecutionEvent__c' => 'SYNCHRONOUS', 'UserId__c' => me, '_cd' => t.addMinutes(-15)});

// Custom-range-only rows: older than the 7d preset (surface only via a custom date range).
specs.add(new Map<String, Object>{'Fingerprint__c' => 'detail:e2e-bulk-cr-15d', 'LogLevel__c' => 'INFO', 'ShortMessage__c' => 'Archived run 15 days ago', 'ClassMethod__c' => 'SyncScheduler.run', 'LineNumber__c' => 4, 'ExecutionEvent__c' => 'SCHEDULED', 'UserId__c' => me, '_cd' => t.addDays(-15)});
specs.add(new Map<String, Object>{'Fingerprint__c' => 'rollup:e2e-bulk-cr-15d:' + t.addDays(-15).formatGmt('yyyyMMdd'), 'LogLevel__c' => 'INFO', 'OccurrenceCount__c' => 30, '_cd' => t.addDays(-15), '_lmd' => t.addDays(-15)});
specs.add(new Map<String, Object>{'Fingerprint__c' => 'e2e-bulk-cr-40d', 'LogLevel__c' => 'DEBUG', 'ShortMessage__c' => 'Very old plain entry (40d)', 'ClassMethod__c' => 'SyncScheduler.run', 'LineNumber__c' => 5, 'ExecutionEvent__c' => 'SCHEDULED', 'UserId__c' => me, '_cd' => t.addDays(-40)});

// ---- Bulk distinct signatures: 260 signatures (detail sample + one rollup each) ----
for(Integer i = 0; i < 260; i++)
{
	String base = 'e2e-bulk-sig-' + i;
	String lvl = levels[Math.mod(i, levels.size())];
	String cls = classes[Math.mod(i, classes.size())];
	String ctx = contexts[Math.mod(i, contexts.size())];
	Integer off = minuteOffsets[Math.mod(i, minuteOffsets.size())];
	Datetime cd = t.addMinutes(-off);
	Integer count = 5 + Math.mod(i * 7, 180);
	specs.add(new Map<String, Object>{'Fingerprint__c' => 'detail:' + base, 'LogLevel__c' => lvl, 'ShortMessage__c' => 'Bulk signature ' + i + ' (' + cls + ')', 'Message__c' => 'Bulk signature ' + i + ' detail payload for ' + cls, 'ClassMethod__c' => cls + '.method' + Math.mod(i, 12), 'LineNumber__c' => 20 + Math.mod(i, 400), 'ExecutionEvent__c' => ctx, 'UserId__c' => me, 'DurationMs__c' => 50 + Math.mod(i * 13, 5000), '_cd' => cd});
	specs.add(new Map<String, Object>{'Fingerprint__c' => 'rollup:' + base + ':' + cd.formatGmt('yyyyMMdd'), 'LogLevel__c' => lvl, 'OccurrenceCount__c' => count, '_cd' => cd, '_lmd' => cd});
}

// ---- Bulk correlation chains: 15 chains x 4 hops (distinct CreatedDate, linked transactions) ----
for(Integer c = 0; c < 15; c++)
{
	String corr = 'e2e-bulk-chain-' + c;
	Datetime base = t.addHours(-Math.mod(c, 20) - 1);
	for(Integer h = 0; h < 4; h++)
	{
		specs.add(new Map<String, Object>{'Fingerprint__c' => 'e2e-bulk-chainhop-' + c + '-' + h, 'LogLevel__c' => levels[Math.mod(h, levels.size())], 'ShortMessage__c' => 'Chain ' + c + ' hop ' + h, 'ClassMethod__c' => classes[Math.mod(c, classes.size())] + '.hop' + h, 'LineNumber__c' => 100 + h, 'ExecutionEvent__c' => contexts[Math.mod(h, contexts.size())], 'CorrelationId__c' => corr, 'TransactionId__c' => corr + '-txn-' + h, 'ParentTransactionId__c' => h == 0 ? null : corr + '-txn-' + (h - 1), 'UserId__c' => me, 'DurationMs__c' => 40 * (h + 1), '_cd' => base.addSeconds(h * 30)});
	}
}

// ---- Bulk plain "All entries" rows: 2600 genuinely NON-fingerprinted rows (Fingerprint__c = null) spread
// across the window. Null fingerprint means they are BOTH endless-scroll volume for All entries AND
// derived-fold input at volume ("Grouped from logs" performance). Marked by an 'e2e-bulk-' TransactionId__c
// so teardown still finds them. ~10 classes x 4 levels -> ~40 high-count derived signatures.
for(Integer i = 0; i < 2600; i++)
{
	String lvl = levels[Math.mod(i, levels.size())];
	String cls = classes[Math.mod(i * 3, classes.size())];
	String ctx = contexts[Math.mod(i * 2, contexts.size())];
	Integer off = minuteOffsets[Math.mod(i, minuteOffsets.size())] + Math.mod(i, 59);
	specs.add(new Map<String, Object>{'TransactionId__c' => 'e2e-bulk-plain-' + i, 'LogLevel__c' => lvl, 'ShortMessage__c' => 'Bulk plain entry ' + i, 'ClassMethod__c' => cls + '.run', 'LineNumber__c' => 1 + Math.mod(i, 900), 'ExecutionEvent__c' => ctx, 'UserId__c' => me, '_cd' => t.addMinutes(-off)});
}

// Build + insert in batches of 1000 to keep heap bounded.
Integer total = 0;
List<SObject> batch = new List<SObject>();
for(Map<String, Object> spec : specs)
{
	SObject r = leType.newSObject();
	for(String k : spec.keySet())
	{
		if(k.startsWith('_'))
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
	batch.add(r);
	if(batch.size() == 1000)
	{
		insert batch;
		total += batch.size();
		batch = new List<SObject>();
	}
}
if(!batch.isEmpty())
{
	insert batch;
	total += batch.size();
}

Datetime oldest = (Datetime)Database.query('SELECT CreatedDate FROM ' + ns + 'LogEntry__c WHERE ' + ns + 'Fingerprint__c = \'e2e-bulk-cr-40d\'')[0].get('CreatedDate');
Boolean backdated = (Datetime.now().getTime() - oldest.getTime()) / 86400000L >= 35;
System.debug('SEED_LOG_CONSOLE_BULK ns=[' + ns + '] rows=' + total + ' auditBackdate=' + (backdated ? 'OK' : 'FAILED_ENABLE_AUDIT_FIELDS'));
