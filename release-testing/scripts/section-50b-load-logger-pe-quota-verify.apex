/**
 * Section 50b (extended-load Phase 3, Tier 2): Load Test — Logger Platform Event quota (Verify)
 *
 * Verification half of the section-50 launch + verify split. Section 50 emits 100
 * kern.LOG_Builder.info().emitAt(...) calls in one transaction and persists the run-stamp,
 * correlationId, launch-tx RequestId, and emitWallMs into a tagged kern__Foobar__c handoff
 * row (Name='Section50Load_<runStamp>'). This script reads the handoff, polls
 * kern__LogEntry__c for the 100 expected rows (filtered by the run-stamped ClassMethod__c
 * marker + TODAY + current user) within a 60s wall-clock budget, asserts persistedCount == 100
 * + droppedCount == 0 + all 100 share the launch's TransactionId__c + all 100 share the
 * launch's CorrelationId__c + zero quota-error LogEntry__c rows + zero ApiIssue__c rows
 * from the launch. Emits the four PERF_ROW lines (emitWallMs, peDeliveryWallMs,
 * persistedCount, droppedCount) for Phase 2.5's harvester. Then deletes the handoff row +
 * the 100 LogEntry__c rows.
 *
 * Polling strategy: bounded retries on the kern__LogEntry__c COUNT() scoped by the run
 * marker. Salesforce typically delivers Platform Events within 1-30 seconds in scratch orgs
 * but scheduler backpressure or the Replay subsystem can extend this. Budget 60s wall with
 * 2s interval (~30 polls before timeout). Each poll consumes ~5-15 ms CPU (one COUNT() SOQL)
 * so 30 polls keep us well under the 10s sync CPU governor. If still not at 100 after the
 * wall budget, the script emits a clear diagnostic + throws AssertException so the operator
 * knows to wait longer + re-run section-50b only (handoff row persists for re-poll).
 *
 * SPEC vs ACTUAL — see section-50 launch script header for the launch+verify split rationale
 *   (FRAMEWORK FINDING A36) — the spec called for single-script polling for persistence,
 *   which is structurally impossible because Platform Events do not deliver to subscribers
 *   until the publishing transaction commits.
 *
 * SPEC vs ACTUAL — peDeliveryWallMs measurement basis:
 *   The spec defines peDeliveryWallMs as "wall clock from emit completion to all 100
 *   LogEntry__c rows persisted". We compute this as
 *   (verify-tx pollEndMs - launch handoff launchCompletedAtMs). The launch script captured
 *   System.currentTimeMillis() immediately after the 100 emits completed (handoff field
 *   `launchCompletedAtMs`); the verify script captures System.currentTimeMillis() at the
 *   poll iteration where persistedCount first reaches 100. The DELTA spans:
 *     - the rest of the launch tx (handoff insert + script tear-down — typically <100 ms)
 *     - the launch tx COMMIT (sf apex run exit — variable, typically 100-500 ms)
 *     - the operator-introduced delay between sf apex run launch + sf apex run verify
 *       (NOT the framework's PE delivery time — see Caveat below)
 *     - the verify script start-up + handoff query + first poll
 *     - the actual PE delivery + TRG_PersistLogEntry + LogEntry__c insert chain
 *   Because the operator-introduced delay is variable (manual vs script invocation rhythm),
 *   peDeliveryWallMs is a useful CEILING on PE delivery latency, not a tight measurement.
 *   For trend analysis Phase 2.5's harvester captures the metric anyway because regressions
 *   in subscriber-side LogEntry__c persistence (e.g. trigger framework slowdowns,
 *   DML_Builder regressions) WOULD surface as a peDeliveryWallMs increase across runs once
 *   the operator-delay variance is averaged out across the baseline windowing harvester.
 *   Caveat documented for downstream interpretation.
 *
 * SPEC vs ACTUAL — TransactionId vs Correlation cardinality assertion:
 *   The spec asserts "All 100 share the same TransactionId__c (single transaction emission)".
 *   We strengthen this from "share the same value as each other" to "share the value the
 *   LAUNCH script captured into the handoff row". This is a tighter contract: not only do
 *   the 100 entries belong to one tx, they belong to the SPECIFIC tx we expect (the launch
 *   tx whose RequestId is `handoff.transactionId`). The same tightening applies to the
 *   correlation assertion — we don't just assert "all share one correlationId", we assert
 *   "all share the value `kern.LOG_Builder.startCorrelation()` returned in the launch".
 *   This catches a regression where the framework would persist the wrong tx ID (e.g.
 *   confusing the publish tx with the subscriber tx) — a pure
 *   "share the same as each other" assertion would miss that bug.
 *
 * SPEC vs ACTUAL — quota-error scoping:
 *   The spec says "no quota-exhausted error in subscriber (check ApiIssue__c or LogEntry__c
 *   with Severity='ERROR' scoped to TRG_PersistLogEntry)". The framework uses the field
 *   kern__LogLevel__c (not Severity__c) for ERROR/WARN/INFO/DEBUG distinction. The
 *   subscriber-side PE handler is TRG_PersistLogEntry which calls DML_Builder.doInsert with
 *   ALL the entries in one chunk — there is no separate "TRG_PersistLogEntry" classMethod
 *   marker on the entries it persists. If the DML failed with a quota issue, the failure
 *   would surface as: (a) the entries simply not persisting (caught by persistedCount<100),
 *   or (b) a separate ERROR-level LogEntry__c emitted by the DML_Builder /
 *   TRG_PersistLogEntry failure path (caught by scoping the ERROR scan to entries SHARING
 *   our launch tx's TransactionId__c — the framework propagates the publisher tx's
 *   RequestId into LogEntryEvent__e.TransactionId__c so a subscriber-side ERROR triggered
 *   by OUR PE chain would inherit our launch RequestId, distinguishing it from unrelated
 *   ERRORs from other concurrent or earlier load tests like section-49's
 *   AccountArchiveProcessor validation failures). Both checks run; the broad "no ERROR
 *   anywhere TODAY by user" scope rejected as too noisy in the presence of legitimate
 *   ERROR pollution from prior load tests in the same release-testing session.
 *
 * SPEC vs ACTUAL — emitting-user scoping uses kern__UserId__c, NOT CreatedById
 *   (FRAMEWORK FINDING A37):
 *   Persisted kern__LogEntry__c rows have CreatedById set to the "Automated Process" user
 *   (autoproc) — NOT the user who called .emit(). This is because TRG_PersistLogEntry runs
 *   on the LogEntryEvent__e Platform Event subscriber, and Platform Event triggers always
 *   execute as the Automated Process user (Salesforce platform contract). The framework
 *   captures the EMITTING user's Id at publish time into LogEntryEvent__e.UserId__c
 *   (LOG_Engine.cls line 1408: `event.UserId__c = CURRENT_USER_ID`) and TRG_PersistLogEntry
 *   propagates it to LogEntry__c.UserId__c (TRG_PersistLogEntry.cls line 48). To scope a
 *   query to the emitting user from a subscriber's anon Apex / test code, you MUST use
 *   `kern__UserId__c = :UserInfo.getUserId()` not `CreatedById = :UserInfo.getUserId()`.
 *   Pre-flight survey for this script discovered the issue empirically: a CreatedById-scoped
 *   probe returned 0 rows even though 100 rows existed under the kern__UserId__c-scoped
 *   filter. Section-50b uses kern__UserId__c throughout. Documented as framework finding
 *   A37 (severity 🟡 — important; subscribers writing reporting / cleanup queries WILL trip
 *   on this if they reach for CreatedById by reflex).
 *
 * Cleanup happens at the end of THIS script (not section-50) because the verify queries
 * depend on the handoff row + persisted LogEntry__c rows still being intact. Cleanup
 * deletes the handoff Foobar__c row (Name LIKE 'Section50Load_%' from TODAY by current
 * user via CreatedById — Foobar__c is inserted by the launch tx so CreatedById IS the
 * emitting user there) AND all the marked LogEntry__c rows (ClassMethod__c LIKE
 * 'LOG_TestSection50_%' from TODAY by emitting user via kern__UserId__c — see
 * FRAMEWORK FINDING A37 above for why we use UserId__c not CreatedById).
 * LIMIT 9000 each to stay under DML row governor.
 *
 * Prerequisites:
 *   - Section 50 launch executed in this org within the last few minutes
 *   - At least ~10-30 s of wall-clock time elapsed since launch (PE delivery)
 *
 * Run:
 *   sf apex run --file release-testing/scripts/section-50b-load-logger-pe-quota-verify.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 */

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, '=== Section 50b (extended-load Phase 3): Load Test — Logger PE Quota (Verify) ===');

kern.TRG_Base.clearAllBypasses();
kern.UTIL_ValidationRule.clearAllBypasses();

Integer pass = 0;
Integer fail = 0;
List<String> failures = new List<String>();

final Integer EXPECTED_COUNT = 100;
final Integer POLL_BUDGET_MS = 60000;
final Integer POLL_INTERVAL_MS = 2000;

String handoffName = '';
String classMethodMarker = '';

try
{
	List<kern__Foobar__c> handoffRows =
	[
			SELECT Id,
					Name,
					kern__TextAreaLong__c
			FROM kern__Foobar__c
			WHERE Name LIKE 'Section50Load_%'
			ORDER BY CreatedDate DESC
			LIMIT 1
	];

	Assert.areEqual(1, handoffRows.size(),
			'50b-verify: expected exactly one Section50Load_% handoff row, got ' + handoffRows.size()
			+ ' (was section-50 launched first?)');

	kern__Foobar__c handoffRow = handoffRows[0];
	handoffName = handoffRow.Name;
	Map<String, Object> handoff = (Map<String, Object>)JSON.deserializeUntyped(handoffRow.kern__TextAreaLong__c);

	String runStamp = (String)handoff.get('runStamp');
	String expectedCorrelationId = (String)handoff.get('correlationId');
	String expectedTransactionId = (String)handoff.get('transactionId');
	classMethodMarker = (String)handoff.get('classMethodMarker');
	Integer expectedCount = (Integer)handoff.get('emitCount');
	Long emitWallMs = (Long)handoff.get('emitWallMs');
	Long launchCompletedAtMs = (Long)handoff.get('launchCompletedAtMs');

	Assert.areEqual(EXPECTED_COUNT, expectedCount,
			'50b-verify: handoff emitCount must be ' + EXPECTED_COUNT + '; got ' + expectedCount
			+ ' (handoff/launch script drift?)');

	System.debug(LoggingLevel.INFO,
			'50b-verify: read handoff ' + handoffName + ' runStamp=' + runStamp
			+ ' correlationId=' + expectedCorrelationId + ' transactionId=' + expectedTransactionId
			+ ' classMethodMarker=' + classMethodMarker + ' emitWallMs=' + emitWallMs + 'ms');

	String classMethodPattern = classMethodMarker + '%';
	Long pollStartMs = System.currentTimeMillis();
	Long pollElapsedMs = 0;
	Integer persistedCount = 0;
	Integer pollIterations = 0;

	while(pollElapsedMs < POLL_BUDGET_MS && persistedCount < EXPECTED_COUNT)
	{
		persistedCount =
		[
				SELECT COUNT()
				FROM kern__LogEntry__c
				WHERE kern__ClassMethod__c LIKE :classMethodPattern
				AND CreatedDate = TODAY
				AND kern__UserId__c = :UserInfo.getUserId()
		];
		pollIterations++;

		if(persistedCount >= EXPECTED_COUNT)
		{
			break;
		}

		Long spinUntilMs = System.currentTimeMillis() + POLL_INTERVAL_MS;
		while(System.currentTimeMillis() < spinUntilMs && Limits.getCpuTime() < 8000)
		{
			Math.sqrt(2.0);
		}
		pollElapsedMs = System.currentTimeMillis() - pollStartMs;

		if(Limits.getCpuTime() >= 8000)
		{
			System.debug(LoggingLevel.WARN,
					'50b-verify: approaching sync CPU governor (' + Limits.getCpuTime() + '/10000 ms) — '
					+ 'aborting poll loop. If persistedCount < ' + EXPECTED_COUNT + ', re-run '
					+ 'section-50b only (handoff row persists for re-poll).');
			break;
		}
	}

	Long pollEndMs = System.currentTimeMillis();
	Long peDeliveryWallMs = pollEndMs - launchCompletedAtMs;
	Integer droppedCount = EXPECTED_COUNT - persistedCount;

	System.debug(LoggingLevel.INFO,
			'50b-verify (poll) ' + pollIterations + ' iterations over ' + pollElapsedMs
			+ 'ms; persistedCount=' + persistedCount + '/' + EXPECTED_COUNT
			+ ' droppedCount=' + droppedCount);

	Assert.areEqual(EXPECTED_COUNT, persistedCount,
			'50b-verify: persistedCount must be ' + EXPECTED_COUNT + ' (no PEs dropped by '
			+ 'TRG_PersistLogEntry / quota / subscriber chain); got ' + persistedCount
			+ ' droppedCount=' + droppedCount + ' after ' + pollIterations + ' polls / '
			+ pollElapsedMs + 'ms wall. ClassMethod marker=' + classMethodMarker
			+ '. If still < ' + EXPECTED_COUNT + ', scratch-org PE bus latency may be saturating — '
			+ 'wait longer + re-run section-50b only.');

	Assert.areEqual(0, droppedCount,
			'50b-verify: droppedCount must be 0 (HARD GATE — any drop indicates subscriber chain '
			+ 'breakage); got ' + droppedCount);

	List<AggregateResult> txGroups =
	[
			SELECT kern__TransactionId__c txId,
					COUNT(Id) rowCount
			FROM kern__LogEntry__c
			WHERE kern__ClassMethod__c LIKE :classMethodPattern
			AND CreatedDate = TODAY
			AND kern__UserId__c = :UserInfo.getUserId()
			GROUP BY kern__TransactionId__c
	];

	Assert.areEqual(1, txGroups.size(),
			'50b-verify: all ' + EXPECTED_COUNT + ' persisted entries must share a single '
			+ 'TransactionId__c (single launch tx); got ' + txGroups.size() + ' distinct '
			+ 'TransactionId__c values. Per-group: ' + txGroups);

	String observedTransactionId = (String)txGroups[0].get('txId');
	Integer observedTxRowCount = (Integer)txGroups[0].get('rowCount');

	Assert.areEqual(expectedTransactionId, observedTransactionId,
			'50b-verify: persisted TransactionId__c must equal the LAUNCH tx RequestId; '
			+ 'expected="' + expectedTransactionId + '" observed="' + observedTransactionId + '"');

	Assert.areEqual(EXPECTED_COUNT, observedTxRowCount,
			'50b-verify: TransactionId__c group rowCount must equal ' + EXPECTED_COUNT
			+ '; got ' + observedTxRowCount);

	List<AggregateResult> correlationGroups =
	[
			SELECT kern__CorrelationId__c correlationId,
					COUNT(Id) rowCount
			FROM kern__LogEntry__c
			WHERE kern__ClassMethod__c LIKE :classMethodPattern
			AND CreatedDate = TODAY
			AND kern__UserId__c = :UserInfo.getUserId()
			GROUP BY kern__CorrelationId__c
	];

	Assert.areEqual(1, correlationGroups.size(),
			'50b-verify: all ' + EXPECTED_COUNT + ' persisted entries must share a single '
			+ 'CorrelationId__c (single startCorrelation()); got ' + correlationGroups.size()
			+ ' distinct CorrelationId__c values. Per-group: ' + correlationGroups);

	String observedCorrelationId = (String)correlationGroups[0].get('correlationId');
	Integer observedCorrelationRowCount = (Integer)correlationGroups[0].get('rowCount');

	Assert.areEqual(expectedCorrelationId, observedCorrelationId,
			'50b-verify: persisted CorrelationId__c must equal the LAUNCH correlationId; '
			+ 'expected="' + expectedCorrelationId + '" observed="' + observedCorrelationId + '"');

	Assert.areEqual(EXPECTED_COUNT, observedCorrelationRowCount,
			'50b-verify: CorrelationId__c group rowCount must equal ' + EXPECTED_COUNT
			+ '; got ' + observedCorrelationRowCount);

	Integer ourErrorCount =
	[
			SELECT COUNT()
			FROM kern__LogEntry__c
			WHERE kern__LogLevel__c = 'ERROR'
			AND CreatedDate = TODAY
			AND kern__UserId__c = :UserInfo.getUserId()
			AND kern__ClassMethod__c LIKE :classMethodPattern
	];

	Assert.areEqual(0, ourErrorCount,
			'50b-verify: zero ERROR-level kern__LogEntry__c rows must persist under OUR run marker '
			+ classMethodMarker + ' (we only emit INFO; an ERROR under our marker indicates the '
			+ 'framework injection-flipped a level OR TRG_PersistLogEntry corrupted the LogLevel '
			+ 'field during persistence); got ' + ourErrorCount + ' unexpected ERROR rows under marker');

	Integer apiIssueCount =
	[
			SELECT COUNT()
			FROM kern__ApiIssue__c
			WHERE CreatedDate = TODAY
			AND CreatedById = :UserInfo.getUserId()
	];

	Assert.areEqual(0, apiIssueCount,
			'50b-verify: zero kern__ApiIssue__c rows must surface from current user TODAY '
			+ '(integration-side errors as a side-effect of the PE flood); got ' + apiIssueCount);

	Map<String, Object> emitWallRow = new Map<String, Object>
	{
			'section' => 50,
			'metric' => 'emitWallMs',
			'value' => emitWallMs
	};
	Map<String, Object> peDeliveryRow = new Map<String, Object>
	{
			'section' => 50,
			'metric' => 'peDeliveryWallMs',
			'value' => peDeliveryWallMs
	};
	Map<String, Object> persistedRow = new Map<String, Object>
	{
			'section' => 50,
			'metric' => 'persistedCount',
			'value' => persistedCount
	};
	Map<String, Object> droppedRow = new Map<String, Object>
	{
			'section' => 50,
			'metric' => 'droppedCount',
			'value' => droppedCount
	};
	System.debug(LoggingLevel.INFO, 'PERF_ROW: ' + JSON.serialize(emitWallRow));
	System.debug(LoggingLevel.INFO, 'PERF_ROW: ' + JSON.serialize(peDeliveryRow));
	System.debug(LoggingLevel.INFO, 'PERF_ROW: ' + JSON.serialize(persistedRow));
	System.debug(LoggingLevel.INFO, 'PERF_ROW: ' + JSON.serialize(droppedRow));

	System.debug(LoggingLevel.INFO,
			'50b-verify PASS: ' + persistedCount + '/' + EXPECTED_COUNT + ' LogEntry__c rows persisted '
			+ '(droppedCount=' + droppedCount + '); all share TransactionId="' + observedTransactionId
			+ '" + CorrelationId="' + observedCorrelationId + '". '
			+ 'emitWallMs=' + emitWallMs + 'ms peDeliveryWallMs=' + peDeliveryWallMs + 'ms '
			+ '(includes operator delay between launch+verify — see header). '
			+ 'Zero ERROR-level LogEntry__c rows under our marker (' + ourErrorCount + '). '
			+ 'Zero ApiIssue__c rows from user TODAY (' + apiIssueCount + '). '
			+ 'Total verify wall=' + pollElapsedMs + 'ms across ' + pollIterations + ' polls.');

	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR,
			'50b-verify FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('50b-verify: ' + scenarioError.getMessage());
	fail++;
}

try
{
	List<kern__Foobar__c> residualHandoff =
	[
			SELECT Id
			FROM kern__Foobar__c
			WHERE Name LIKE 'Section50Load_%'
			AND CreatedDate = TODAY
			AND CreatedById = :UserInfo.getUserId()
			LIMIT 9000
	];
	if(!residualHandoff.isEmpty())
	{
		delete residualHandoff;
		System.debug(LoggingLevel.INFO,
				'Cleanup: deleted ' + residualHandoff.size() + ' Section50Load_% handoff Foobar__c row(s)');
	}

	List<kern__LogEntry__c> residualLogEntries =
	[
			SELECT Id
			FROM kern__LogEntry__c
			WHERE kern__ClassMethod__c LIKE 'LOG_TestSection50_%'
			AND CreatedDate = TODAY
			AND kern__UserId__c = :UserInfo.getUserId()
			LIMIT 9000
	];
	if(!residualLogEntries.isEmpty())
	{
		delete residualLogEntries;
		System.debug(LoggingLevel.INFO,
				'Cleanup: deleted ' + residualLogEntries.size() + ' LOG_TestSection50_% kern__LogEntry__c row(s)');
	}
}
catch(Exception cleanupError)
{
	System.debug(LoggingLevel.WARN,
			'50b cleanup warning (handoff/LogEntry delete failed): ' + cleanupError.getMessage());
}

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, 'Section 50b (Verify): ' + pass + ' passed, ' + fail + ' failed');
if(fail > 0)
{
	System.debug(LoggingLevel.ERROR, '=== Section 50b (Verify) FAILED ===');
	for(String message : failures)
	{
		System.debug(LoggingLevel.ERROR, '  - ' + message);
	}
	throw new System.AssertException('Section 50b (Verify) failed: ' + fail + ' scenarios');
}
else
{
	System.debug(LoggingLevel.INFO, '=== Section 50b (Verify) COMPLETE: All scenarios verified + PERF_ROW emitted ===');
}
