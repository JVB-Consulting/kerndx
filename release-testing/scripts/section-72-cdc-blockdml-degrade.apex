/**
 * Section 72: CDC BlockDml-to-LogAndContinue Degrade (Launch)
 *
 * Exercises the framework's BlockDml degrade path on a Change Data Capture dispatch. With the
 * cdc-blockdml-degrade-active fixture deployed (runner deploys it first), the
 * SubscriberCdcProbeChangeEvent setting has TWO active actions, both fired once per delivered
 * change event in Order ascending:
 *   - Order 10 — the recorder (FailureAction LogAndContinue), bound to TST_SubscriberFlow_CdcHeaderRecorder,
 *     records a SubscriberCdcMarker__c (succeeds).
 *   - Order 20 — the degrade probe (FailureAction BlockDml), bound to TST_SubscriberFlow_CdcAlwaysFail,
 *     which raises an unhandled runtime fault.
 *
 * On a normal (synchronous DML) dispatch, FailureAction BlockDml rethrows and rolls back the
 * originating DML. But a change event is delivered asynchronously AFTER the source change has
 * already committed — there is nothing to roll back. The framework recognises this and DEGRADES
 * BlockDml to LogAndContinue: it swallows the fault, emits a WARN log tagged
 * errorKind=cdc-block-dml-degraded, and lets the dispatch complete. Section 72b's load-bearing
 * proof is that degrade-exclusive WARN (the errorKind is emitted only on the change-event degrade
 * path); it additionally confirms the dispatch completed end-to-end — the Order-10 recorder
 * co-action ran and the source rows survived (both survive whether or not the degrade fires, so
 * they are supporting regression coverage, not proof of the degrade).
 *
 * Launch + verify split (mirrors section-34 / 56 / 71): change events deliver only after the
 * inserting transaction commits, so section 72 inserts the probes here and section 72b asserts the
 * delivered state after ~30s.
 *
 * Prerequisites:
 *   - CDC foundation + base CMDT deployed; SubscriberTestAccess assigned
 *   - the cdc-blockdml-degrade-active fixture deployed (recorder flag ON + the BlockDml degrade
 *     action un-bypassed)
 *
 * Run (two stages, ~30s apart):
 *   sf apex run --file release-testing/scripts/section-72-cdc-blockdml-degrade.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 *   (wait ~30 seconds for change-event delivery)
 *   sf apex run --file release-testing/scripts/section-72b-cdc-blockdml-degrade-verify.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 */

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, '=== Section 72: CDC BlockDml Degrade (Launch) ===');

Integer pass = 0;
Integer fail = 0;
List<String> failures = new List<String>();

final String RUN_STAMP_72 = String.valueOf(Datetime.now().getTime());
final Integer PROBE_COUNT_72 = 3;

// Scenario 72a (launch) — clear prior markers, then insert PROBE_COUNT_72 probes with both the
// recorder and the BlockDml degrade action active. The async dispatch runs the recorder (Order 10,
// succeeds) then the degrade probe (Order 20, faults → degrades to LogAndContinue). Terminal
// assertions (source survives, recorder markers persist, degrade WARN logged) live in section 72b.
try
{
	List<SubscriberCdcMarker__c> staleMarkers =
	[
			SELECT Id
			FROM SubscriberCdcMarker__c
			LIMIT 9000
	];
	if(!staleMarkers.isEmpty())
	{
		delete staleMarkers;
	}

	List<SubscriberCdcProbe__c> probes = new List<SubscriberCdcProbe__c>();
	for(Integer i = 0; i < PROBE_COUNT_72; i++)
	{
		probes.add(new SubscriberCdcProbe__c(
				Name = 'Section72 Probe ' + i + ' ' + RUN_STAMP_72,
				ProbeLabel__c = 'Section72_' + RUN_STAMP_72,
				ProbeSequence__c = i
		));
	}
	insert probes;

	Assert.areEqual(PROBE_COUNT_72, probes.size(), '72a-launch: expected ' + PROBE_COUNT_72 + ' probes constructed');
	for(SubscriberCdcProbe__c probe : probes)
	{
		Assert.isNotNull(probe.Id, '72a-launch: each inserted probe should have an Id');
	}
	System.debug(LoggingLevel.INFO, '72a-launch PASS: inserted ' + probes.size()
			+ ' SubscriberCdcProbe__c (stamp Section72_' + RUN_STAMP_72 + ') with the recorder + BlockDml degrade actions active');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '72a-launch FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('72a-launch: ' + scenarioError.getMessage());
	fail++;
}

// No cleanup here — section 72b needs the delivered state to verify, and cleans up after asserting.

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, 'Section 72 (Launch): ' + pass + ' passed, ' + fail + ' failed');
if(fail > 0)
{
	System.debug(LoggingLevel.ERROR, '=== Section 72 (Launch) FAILED ===');
	for(String message : failures)
	{
		System.debug(LoggingLevel.ERROR, '  - ' + message);
	}
	throw new System.AssertException('Section 72 (Launch) failed: ' + fail + ' scenarios');
}
else
{
	System.debug(LoggingLevel.INFO, '=== Section 72 (Launch) COMPLETE: probes inserted. Run section 72b after ~30s to verify the degrade. ===');
}
