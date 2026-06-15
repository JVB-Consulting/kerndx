/**
 * Section 72b: CDC BlockDml-to-LogAndContinue Degrade (Verify)
 *
 * Verification half of the section-72 launch + verify split. Section 72 inserts PROBE_COUNT_72
 * probes (stamped ProbeLabel__c = 'Section72_<runId>') with both the recorder (Order 10,
 * LogAndContinue) and the BlockDml degrade action (Order 20, BlockDml → TST_SubscriberFlow_CdcAlwaysFail)
 * active. This script asserts the delivered state after ~30s.
 *
 * The load-bearing proof of the degrade is scenario 72d: a WARN log whose errorKind is
 * `cdc-block-dml-degraded`. That errorKind is emitted ONLY on the framework's change-event degrade
 * path (a synchronous BlockDml failure logs errorKind=runtime and rethrows; the change-event path
 * recognises the commit cannot be rolled back, swallows the fault, and logs the degrade WARN). So
 * its presence is specific, sufficient proof that BlockDml degraded to LogAndContinue.
 *
 * Scenarios 72b and 72c are SUPPORTING, not proof of the degrade: because the recorder writes into
 * a separate non-CDC object, its markers survive whether or not the degrade fires, and a change
 * event is delivered after the source has already committed, so the source rows survive regardless.
 * They confirm the dispatch completed end-to-end (the Order-10 recorder co-action ran and the
 * source is intact) — useful regression coverage, but it is 72d that distinguishes "degraded" from
 * "did not degrade".
 *
 * Scenario coverage:
 *   - 72b (recorder co-action ran): every probe this run inserted has a delivered CREATE marker —
 *     the Order-10 recorder ran in each dispatch and the dispatch was not aborted.
 *   - 72c (source survived): the source probes whose change events were delivered still exist.
 *   - 72d (degrade was logged — THE proof): a WARN kern__LogEntry__c from kern.TRG_InvokeFlow.run
 *     carries errorKind=cdc-block-dml-degraded, failureAction=BlockDml, flowName=TST_SubscriberFlow_CdcAlwaysFail.
 *     The degrade logs are not stamped per run, but the errorKind is degrade-path-exclusive, and the
 *     section-72 launch cleared markers and 72b confirms this cycle delivered, so >= 1 such WARN
 *     proves the degrade fired this cycle.
 *
 * Cleanup deletes the delivered markers (non-CDC object; never re-fires the dispatch). Probes are
 * left in place (see section 71b header).
 *
 * Prerequisites:
 *   - Section 72 launch executed in this org within the last few minutes (blockdml degrade fixture active)
 *   - At least ~30 seconds of wall-clock time elapsed since launch
 *
 * Run:
 *   sf apex run --file release-testing/scripts/section-72b-cdc-blockdml-degrade-verify.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 */

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, '=== Section 72b: CDC BlockDml Degrade (Verify) ===');

Integer pass = 0;
Integer fail = 0;
List<String> failures = new List<String>();

final Integer EXPECTED_PROBES_72 = 3;
final String CHANGE_TYPE_CREATE = 'CREATE';
final String PROBE_STAMP_PREFIX = 'Section72_';
final String DEGRADE_ERROR_KIND = 'cdc-block-dml-degraded';
final String DEGRADE_FAILURE_ACTION = 'BlockDml';
final String DEGRADE_FLOW_NAME = 'TST_SubscriberFlow_CdcAlwaysFail';
final String INVOKE_FLOW_CLASS_METHOD = 'kern.TRG_InvokeFlow.run';
final String LOG_LEVEL_WARN = 'WARN';

// This run's probes (most-recent Section72 batch) and the markers correlated to them by source id.
Set<Id> runProbeIds = new Map<Id, SubscriberCdcProbe__c>(
[
		SELECT Id
		FROM SubscriberCdcProbe__c
		WHERE ProbeLabel__c LIKE :(PROBE_STAMP_PREFIX + '%')
		ORDER BY CreatedDate DESC
		LIMIT 3
]).keySet();
Map<Id, SubscriberCdcMarker__c> markerByProbeId = new Map<Id, SubscriberCdcMarker__c>();
for(SubscriberCdcMarker__c marker :
[
		SELECT HeaderChangeType__c,
				HeaderRecordIds__c
		FROM SubscriberCdcMarker__c
		ORDER BY CreatedDate DESC
])
{
	if(String.isBlank(marker.HeaderRecordIds__c))
	{
		continue;
	}
	for(String capturedId : marker.HeaderRecordIds__c.split(';'))
	{
		Id probeId;
		try
		{
			probeId = Id.valueOf(capturedId);
		}
		catch(Exception ignored)
		{
			continue;
		}
		if(runProbeIds.contains(probeId))
		{
			markerByProbeId.put(probeId, marker);
		}
	}
}

// Verify 72b — the Order-10 recorder co-action ran in each dispatch (a CREATE marker per source
// probe). Supporting: confirms the dispatch was not aborted; not proof of the degrade itself.
try
{
	Assert.areEqual(EXPECTED_PROBES_72, runProbeIds.size(),
			'72b-verify: expected this run\'s ' + EXPECTED_PROBES_72 + ' Section72 probes; found ' + runProbeIds.size() + ' (was section 72 launched first?)');
	Assert.areEqual(EXPECTED_PROBES_72, markerByProbeId.size(),
			'72b-verify: expected a recorder marker for each of the ' + EXPECTED_PROBES_72 + ' source probes, got ' + markerByProbeId.size()
			+ ' (change events may still be delivering — wait longer between launch and verify)');
	for(SubscriberCdcMarker__c marker : markerByProbeId.values())
	{
		Assert.areEqual(CHANGE_TYPE_CREATE, marker.HeaderChangeType__c, '72b-verify: recorder markers should be CREATE change events');
	}
	System.debug(LoggingLevel.INFO, '72b-verify PASS: the Order-10 recorder co-action ran for all ' + markerByProbeId.size() + ' source probes (dispatch completed)');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '72b-verify FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('72b-verify: ' + scenarioError.getMessage());
	fail++;
}

// Verify 72c — the source rows survived: the probes whose change events were delivered still exist
// (a change event is delivered after commit; BlockDml degrade does not roll back the source).
try
{
	Assert.areEqual(EXPECTED_PROBES_72, markerByProbeId.size(), '72c-verify: expected ' + EXPECTED_PROBES_72 + ' correlated markers (depends on 72b delivery)');
	List<SubscriberCdcProbe__c> survivingProbes =
	[
			SELECT Id
			FROM SubscriberCdcProbe__c
			WHERE Id IN :markerByProbeId.keySet()
	];
	Assert.areEqual(EXPECTED_PROBES_72, survivingProbes.size(),
			'72c-verify: every source probe whose change event was delivered should still exist (the BlockDml degrade does not roll back an already-committed change)');
	System.debug(LoggingLevel.INFO, '72c-verify PASS: all ' + survivingProbes.size() + ' source probes survived the BlockDml degrade');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '72c-verify FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('72c-verify: ' + scenarioError.getMessage());
	fail++;
}

// Verify 72d (THE degrade proof) — a WARN kern__LogEntry__c from kern.TRG_InvokeFlow.run carries the
// degrade-exclusive errorKind=cdc-block-dml-degraded, failureAction=BlockDml, flowName=TST_SubscriberFlow_CdcAlwaysFail.
// (ContextData__c is a long text area and cannot be filtered in SOQL, so we filter on the indexed
// class-method + level fields and parse the most-recent rows in memory.)
try
{
	List<kern__LogEntry__c> warnLogs =
	[
			SELECT kern__ContextData__c
			FROM kern__LogEntry__c
			WHERE kern__ClassMethod__c = :INVOKE_FLOW_CLASS_METHOD
			AND kern__LogLevel__c = :LOG_LEVEL_WARN
			ORDER BY CreatedDate DESC
			LIMIT 30
	];
	Integer degradeLogs = 0;
	for(kern__LogEntry__c warnLog : warnLogs)
	{
		if(String.isBlank(warnLog.kern__ContextData__c))
		{
			continue;
		}
		Map<String, Object> envelope = (Map<String, Object>)JSON.deserializeUntyped(warnLog.kern__ContextData__c);
		Object contextDataObj = envelope.get('contextData');
		if(!(contextDataObj instanceof Map<String, Object>))
		{
			continue;
		}
		Map<String, Object> contextData = (Map<String, Object>)contextDataObj;
		if(DEGRADE_ERROR_KIND.equals(contextData.get('errorKind'))
				&& DEGRADE_FAILURE_ACTION.equals(contextData.get('failureAction'))
				&& DEGRADE_FLOW_NAME.equals(contextData.get('flowName')))
		{
			degradeLogs++;
		}
	}
	Assert.isTrue(degradeLogs >= 1,
			'72d-verify: expected at least one WARN log with the degrade-exclusive errorKind=' + DEGRADE_ERROR_KIND + ', failureAction=' + DEGRADE_FAILURE_ACTION
			+ ', flowName=' + DEGRADE_FLOW_NAME + ' from ' + INVOKE_FLOW_CLASS_METHOD + '; found ' + degradeLogs
			+ ' (its absence would mean BlockDml did NOT degrade on the change-event dispatch)');
	System.debug(LoggingLevel.INFO, '72d-verify PASS: ' + degradeLogs + ' BlockDml-degrade WARN log(s) found (degrade-exclusive errorKind=' + DEGRADE_ERROR_KIND + ') — the framework degraded BlockDml to LogAndContinue');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '72d-verify FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('72d-verify: ' + scenarioError.getMessage());
	fail++;
}

// Cleanup — delete the delivered markers (non-CDC object; never re-fires the dispatch).
delete
[
		SELECT Id
		FROM SubscriberCdcMarker__c
		LIMIT 9000
];

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, 'Section 72b (Verify): ' + pass + ' passed, ' + fail + ' failed');
if(fail > 0)
{
	System.debug(LoggingLevel.ERROR, '=== Section 72b (Verify) FAILED ===');
	for(String message : failures)
	{
		System.debug(LoggingLevel.ERROR, '  - ' + message);
	}
	throw new System.AssertException('Section 72b (Verify) failed: ' + fail + ' scenarios');
}
else
{
	System.debug(LoggingLevel.INFO, '=== Section 72b (Verify) COMPLETE: All scenarios verified ===');
}
