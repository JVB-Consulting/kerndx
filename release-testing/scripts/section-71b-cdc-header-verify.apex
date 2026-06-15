/**
 * Section 71b: CDC Change-Event Header Recorder (Verify)
 *
 * Verification half of the section-71 launch + verify split. Section 71 inserts PROBE_COUNT_71
 * SubscriberCdcProbe__c records (stamped ProbeLabel__c = 'Section71_<runId>') with the recorder
 * flag ON; this script asserts the delivered change-event markers after ~30s of asynchronous
 * delivery time. Mirrors the section-34 / 56 launch + verify pattern (change events deliver only
 * after the inserting transaction commits).
 *
 * Run-isolation is by source record id, not by a bare marker count: this run's probes are found
 * via the Section71 stamp (most-recent batch), and the delivered markers are correlated to them by
 * the record id each marker captured (HeaderRecordIds__c). A late-delivering marker from a prior
 * run, or an at-least-once duplicate delivery, cannot perturb the assertions because only markers
 * whose captured id belongs to THIS run's probes are considered, and coverage is measured per
 * distinct source probe.
 *
 * Scenario coverage:
 *   - 71b: every one of this run's PROBE_COUNT_71 probes has a delivered CREATE marker for
 *     SubscriberCdcProbe__c carrying a single record id. Proves the subscriber Flow received the
 *     typed DTO_ChangeEventHeader and handed it to subscriber Apex across the namespace boundary,
 *     once per source record.
 *   - 71c (record-id aggregate audit): the record ids captured on the delivered markers resolve
 *     back to the Section71-stamped probes, proving the platform header's underlying record ids
 *     survived the projection onto DTO_ChangeEventHeader and reached the sink as the genuine
 *     source identities.
 *
 * Cleanup deletes the markers (non-CDC object; deleting never re-fires the dispatch). Probes are
 * left in place (deleting them with the recorder flag still ON would emit DELETE change events and
 * record DELETE markers).
 *
 * Prerequisites:
 *   - Section 71 launch executed in this org within the last few minutes (recorder flag ON)
 *   - At least ~30 seconds of wall-clock time elapsed since launch (change-event delivery window)
 *
 * Run:
 *   sf apex run --file release-testing/scripts/section-71b-cdc-header-verify.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 */

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, '=== Section 71b: CDC Header Recorder (Verify) ===');

Integer pass = 0;
Integer fail = 0;
List<String> failures = new List<String>();

final Integer EXPECTED_PROBES_71 = 3;
final String CHANGE_TYPE_CREATE = 'CREATE';
final String PROBE_ENTITY_NAME = 'SubscriberCdcProbe__c';
final String PROBE_STAMP_PREFIX = 'Section71_';

// This run's probes (most-recent Section71 batch) and the markers correlated to them by source id.
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
				HeaderEntityName__c,
				HeaderRecordIds__c,
				HeaderRecordIdCount__c
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

// Verify 71b — every probe this run inserted has a delivered CREATE marker for SubscriberCdcProbe__c
// carrying a single record id (the recorder fired once per source record).
try
{
	Assert.areEqual(EXPECTED_PROBES_71, runProbeIds.size(),
			'71b-verify: expected to find this run\'s ' + EXPECTED_PROBES_71 + ' Section71 probes; found ' + runProbeIds.size() + ' (was section 71 launched first?)');
	Assert.areEqual(EXPECTED_PROBES_71, markerByProbeId.size(),
			'71b-verify: expected a delivered marker for each of the ' + EXPECTED_PROBES_71 + ' source probes, got markers for ' + markerByProbeId.size()
			+ ' (change events may still be delivering — wait longer between launch and verify, or the recorder flag may not be ON)');
	for(SubscriberCdcMarker__c marker : markerByProbeId.values())
	{
		Assert.areEqual(CHANGE_TYPE_CREATE, marker.HeaderChangeType__c, '71b-verify: every probe insert should record a CREATE change type');
		Assert.areEqual(PROBE_ENTITY_NAME, marker.HeaderEntityName__c, '71b-verify: the header entity name should be the source object SubscriberCdcProbe__c');
		Assert.areEqual(1, (Integer)marker.HeaderRecordIdCount__c, '71b-verify: each CREATE change event should carry exactly one record id');
	}
	System.debug(LoggingLevel.INFO, '71b-verify PASS: a CREATE marker was recorded for each of the ' + markerByProbeId.size() + ' source probes (typed DTO_ChangeEventHeader reached subscriber Apex)');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '71b-verify FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('71b-verify: ' + scenarioError.getMessage());
	fail++;
}

// Verify 71c (record-id aggregate audit) — the record ids captured on the markers resolve back to
// the Section71-stamped probes, proving the header's underlying record ids are the genuine source
// identities (not garbage) and survived projection onto DTO_ChangeEventHeader.
try
{
	Assert.areEqual(EXPECTED_PROBES_71, markerByProbeId.size(),
			'71c-verify: expected ' + EXPECTED_PROBES_71 + ' correlated markers (depends on 71b delivery)');
	List<SubscriberCdcProbe__c> auditedProbes =
	[
			SELECT Id,
					ProbeLabel__c
			FROM SubscriberCdcProbe__c
			WHERE Id IN :markerByProbeId.keySet()
	];
	Assert.areEqual(EXPECTED_PROBES_71, auditedProbes.size(),
			'71c-verify: every captured header record id should resolve to a real SubscriberCdcProbe__c row');
	for(SubscriberCdcProbe__c probe : auditedProbes)
	{
		Assert.isTrue(probe.ProbeLabel__c != null && probe.ProbeLabel__c.startsWith(PROBE_STAMP_PREFIX),
				'71c-verify: each audited probe should carry the Section71 stamp, got ProbeLabel__c=' + probe.ProbeLabel__c);
	}
	System.debug(LoggingLevel.INFO, '71c-verify PASS: all ' + auditedProbes.size() + ' captured header record ids resolve to Section71 probes (record-id aggregate audit intact)');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '71c-verify FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('71c-verify: ' + scenarioError.getMessage());
	fail++;
}

// Cleanup — delete the delivered markers (non-CDC object; never re-fires the dispatch). Probes are
// intentionally left in place (see header).
delete
[
		SELECT Id
		FROM SubscriberCdcMarker__c
		LIMIT 9000
];

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, 'Section 71b (Verify): ' + pass + ' passed, ' + fail + ' failed');
if(fail > 0)
{
	System.debug(LoggingLevel.ERROR, '=== Section 71b (Verify) FAILED ===');
	for(String message : failures)
	{
		System.debug(LoggingLevel.ERROR, '  - ' + message);
	}
	throw new System.AssertException('Section 71b (Verify) failed: ' + fail + ' scenarios');
}
else
{
	System.debug(LoggingLevel.INFO, '=== Section 71b (Verify) COMPLETE: All scenarios verified ===');
}
