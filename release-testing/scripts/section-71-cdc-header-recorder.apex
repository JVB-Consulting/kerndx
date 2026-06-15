/**
 * Section 71: CDC Change-Event Header Recorder (Launch)
 *
 * Proves the subscriber-side Change Data Capture contract end-to-end: inserting records into a
 * CDC-enabled custom object (SubscriberCdcProbe__c) emits change events that the harness change-
 * event trigger (TRG_SubscriberCdcProbeChangeEvent) routes through kern.TRG_Dispatcher, which
 * resolves the SubscriberCdcProbeChangeEvent TriggerSetting (registered via ObjectApiNameOverride__c)
 * and invokes the recorder Flow. kern.TRG_InvokeFlow projects the platform EventBus.ChangeEventHeader
 * onto a typed kern.DTO_ChangeEventHeader and injects it into the subscriber Flow, which hands the
 * whole header to the TST_CdcHeaderSink Apex invocable. The sink records one SubscriberCdcMarker__c
 * per delivered change event, capturing the header scalars (change type, entity, record ids).
 *
 * This exercises the genuinely-new subscriber real-CDC path: the framework's
 * (EventBus.ChangeEventHeader)record.get('ChangeEventHeader') projection only works on real change
 * events (the simulateChangeEventHeaderForTest seam covers the unit-test path), so a real change-
 * event delivery in a managed subscriber org is coverage that @IsTest cannot reach.
 *
 * Launch + verify split (mirrors section-34 / 56): change events are delivered asynchronously by
 * the platform AFTER the inserting transaction commits — a single execute-anonymous transaction
 * cannot both insert the probes and observe the delivered markers. Section 71 launches the probe
 * inserts here (with the recorder flag ON — the runner deploys cdc-header-enabled first); section
 * 71b asserts the markers after ~30s of delivery time. The dormant-gate direction (flag OFF →
 * no markers) is the same RequiredFeatureFlag mechanism proven synchronously by section 68, and
 * the CDC base CMDT ships the recorder gated OFF so it stays dormant during the parallel pool.
 *
 * Run-isolation: clears stale markers at launch (non-CDC object — deleting a marker never re-fires
 * the dispatch). Probes accumulate harmlessly across re-runs; section 71b correlates each delivered
 * marker's record id back to the probes this run inserted via the ProbeLabel__c stamp.
 *
 * Prerequisites:
 *   - subscriber scratch org with the kern managed package installed
 *   - CDC foundation deployed: SubscriberCdcProbe__c (selected for CDC on the standard ChangeEvents
 *     channel), TRG_SubscriberCdcProbeChangeEvent, TST_SubscriberFlow_CdcHeaderRecorder, TST_CdcHeaderSink
 *   - base CMDT: kern__TriggerSetting.SubscriberCdcProbeChangeEvent + the gated Recorder action
 *   - SubscriberTestAccess assigned (field-level security on the probe + marker fields)
 *   - the cdc-header-enabled fixture deployed (RequiredFeatureFlag EnableCdcHeaderReleaseTest ON)
 *
 * Run (in two stages — separated by ~30s of change-event delivery time):
 *   sf apex run --file release-testing/scripts/section-71-cdc-header-recorder.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 *   (wait ~30 seconds for change events to deliver and the recorder to write markers)
 *   sf apex run --file release-testing/scripts/section-71b-cdc-header-verify.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 */

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, '=== Section 71: CDC Header Recorder (Launch) ===');

Integer pass = 0;
Integer fail = 0;
List<String> failures = new List<String>();

final String RUN_STAMP_71 = String.valueOf(Datetime.now().getTime());
final Integer PROBE_COUNT_71 = 3;

// Scenario 71a (launch) — clear any prior markers, then insert PROBE_COUNT_71 CDC probes with the
// recorder flag ON. The async change-event delivery fires the recorder once per probe →
// TST_CdcHeaderSink → one SubscriberCdcMarker__c per delivered change event. Terminal assertions
// (marker count + header scalars + record-id correlation) live in section 71b after delivery time.
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
	for(Integer i = 0; i < PROBE_COUNT_71; i++)
	{
		probes.add(new SubscriberCdcProbe__c(
				Name = 'Section71 Probe ' + i + ' ' + RUN_STAMP_71,
				ProbeLabel__c = 'Section71_' + RUN_STAMP_71,
				ProbeSequence__c = i
		));
	}
	insert probes;

	Assert.areEqual(PROBE_COUNT_71, probes.size(), '71a-launch: expected ' + PROBE_COUNT_71 + ' probes constructed');
	for(SubscriberCdcProbe__c probe : probes)
	{
		Assert.isNotNull(probe.Id, '71a-launch: each inserted probe should have an Id (the change-event record id the header carries)');
	}
	System.debug(LoggingLevel.INFO, '71a-launch PASS: inserted ' + probes.size()
			+ ' SubscriberCdcProbe__c (stamp Section71_' + RUN_STAMP_71 + ') with the recorder flag ON; change-event delivery will fire the recorder');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '71a-launch FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('71a-launch: ' + scenarioError.getMessage());
	fail++;
}

// No cleanup here — section 71b needs the delivered markers to exist for verification, and cleans
// up the markers after asserting. If section 71b is skipped, manual cleanup:
//   delete [SELECT Id FROM SubscriberCdcMarker__c LIMIT 9000];

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, 'Section 71 (Launch): ' + pass + ' passed, ' + fail + ' failed');
if(fail > 0)
{
	System.debug(LoggingLevel.ERROR, '=== Section 71 (Launch) FAILED ===');
	for(String message : failures)
	{
		System.debug(LoggingLevel.ERROR, '  - ' + message);
	}
	throw new System.AssertException('Section 71 (Launch) failed: ' + fail + ' scenarios');
}
else
{
	System.debug(LoggingLevel.INFO, '=== Section 71 (Launch) COMPLETE: probes inserted. Run section 71b after ~30s to verify delivered markers. ===');
}
