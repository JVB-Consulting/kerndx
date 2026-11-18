// =============================================================================
// Section 90: Your trigger action rows on the framework's own objects
// =============================================================================
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Package: kern (managed)
// Prerequisites:
//   - The subscriber metadata of Phase 1.4 is deployed: the subscriber's own trigger setting for the API Issue object
//     kern__TriggerSetting.ReleaseTestApiIssue, the class TRG_RecordApiIssueAfterInsert, the trigger action
//     kern__TriggerAction.RecordApiIssueAfterInsert, the post-trigger action kern__PostTriggerAction.TST_PostActionRecorderApiIssue,
//     the class TST_PostActionRecorder and the feature flag kern__FeatureFlag.EnableFrameworkObjectEventsReleaseTest (shipped off).
//   - The two rows hang on the subscriber's own setting, not on the framework's API Issue setting: the framework ships
//     its settings protected, and a subscriber row cannot refer to a protected setting. The subscriber's setting keeps
//     Apply Masking checked, so the framework's masking of API issues stays on.
//   - Turn the flag on BEFORE this script:
//       node release-testing/runner/cmdt-deployer.js framework-object-events-enabled
//   - Turn the flag off again AFTER this script:
//       node release-testing/runner/cmdt-deployer.js framework-object-events-disabled
//
// Run with:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-90-framework-object-trigger-events.apex
//
// The trigger action row runs after insert on the framework's API Issue object. Its entry formula reads
// newRecord.kern__ServiceName__c and names no context class, so the framework must find the API Issue context class
// itself. Every check prints one line; a failing line says which piece did not work:
//   - the after-insert event: the action was not called at all;
//   - the context: the action was called for the issue the formula should leave out, or the insert failed with an
//     error that names the context class;
//   - a count: the number of calls, records or post-trigger action runs is not the one expected;
//   - the framework's own action: a second setting for the object must add the subscriber's rows next to the
//     framework's rows, never replace them. The framework's before-insert action SetApiIssueTriggeringIndex_BeforeInsert
//     copies Triggering Record ID into Triggering Record Index, so the saved issue shows whether it ran.
//
// Section list (6 PASS expected):
//   90a: the after-insert event runs your action on an API issue insert
//   90b: the entry formula, with no context class name, lets only the matching issue through
//   90c: 201 matching issues in one insert call the action twice (one call for each group of up to 200 records)
//   90d: those two calls receive the 201 issues in all
//   90e: one API issue insert runs the post-trigger action scoped to API issues 2 times (once after each trigger pass)
//   90f: on that same insert, the framework's own action still filled Triggering Record Index, beside your action
//
// Nothing is kept: every insert is rolled back at the end, so no API issue is left on the org.
// Cannot run before Kern 1.12. On 1.11 the Phase 1.4 subscriber deploy refuses the trigger action row (a formula with no
// context class name), and this script does not compile (the Triggering Record Index field comes in 1.12), so the
// section scores 0/6.
// =============================================================================

// Must match the value in the entry formula of kern__TriggerAction.RecordApiIssueAfterInsert.
final String MATCHING_SERVICE_NAME = 'Section90Match';
final String OTHER_SERVICE_NAME = 'Section90Other';
final String STATUS_OPEN = 'Open';
final String DIRECTION_OUTBOUND = 'Outbound';
final String POST_ACTION_NAME = 'Recorder';
final Integer BULK_ISSUE_COUNT = 201;
final Integer EXPECTED_BULK_CALLS = 2;
final Integer EXPECTED_POST_ACTION_RUNS = 2;
// Any text works: the framework's action copies the value as written. The running user's Id is 18 characters, the
// field's full length.
final String TRIGGERING_RECORD_ID = UserInfo.getUserId();

kern.TRG_Base.clearAllBypasses();
kern.TRG_Base.clearAllActionBypasses();
System.Savepoint beforeSection = Database.setSavepoint();

try
{
	// 90a + 90b: one insert of a matching and a non-matching issue
	TRG_RecordApiIssueAfterInsert.reset();
	List<kern__ApiIssue__c> pair = new List<kern__ApiIssue__c> {
			new kern__ApiIssue__c(kern__ServiceName__c = MATCHING_SERVICE_NAME, kern__Status__c = STATUS_OPEN, kern__Direction__c = DIRECTION_OUTBOUND),
			new kern__ApiIssue__c(kern__ServiceName__c = OTHER_SERVICE_NAME, kern__Status__c = STATUS_OPEN, kern__Direction__c = DIRECTION_OUTBOUND)
	};
	String pairInsertError;
	try
	{
		insert pair;
	}
	catch(Exception insertException)
	{
		pairInsertError = insertException.getMessage();
	}

	if(pairInsertError != null)
	{
		System.debug('90a FAIL: not checked, because the insert of two API issues failed');
		System.debug('90b FAIL: the context: the insert failed. If the error names a context class, the framework did not find the API Issue context: '
				+ pairInsertError);
	}
	else if(TRG_RecordApiIssueAfterInsert.callCount == 0)
	{
		System.debug('90a FAIL: the after-insert event: the action was not called at all. The API Issue trigger does not run after-insert rows,'
				+ ' or the formula left the matching issue out (look for an error log entry that names a context class)');
		System.debug('90b FAIL: not checked, because the action was not called');
	}
	else
	{
		System.debug('90a PASS: the after-insert event ran the subscriber action on an API issue insert');
		Boolean onlyMatchingIssue = TRG_RecordApiIssueAfterInsert.callCount == 1
				&& TRG_RecordApiIssueAfterInsert.recordCount == 1
				&& TRG_RecordApiIssueAfterInsert.receivedServiceNames.equals(new Set<String> {MATCHING_SERVICE_NAME});
		if(onlyMatchingIssue)
		{
			System.debug('90b PASS: the entry formula, with no context class name, let only the matching issue through');
		}
		else
		{
			System.debug('90b FAIL: the context: expected 1 call with only the matching issue, got ' + TRG_RecordApiIssueAfterInsert.callCount
					+ ' call(s) with ' + TRG_RecordApiIssueAfterInsert.recordCount + ' record(s) and service names '
					+ TRG_RecordApiIssueAfterInsert.receivedServiceNames);
		}
	}

	// 90c + 90d: 201 matching issues in one insert
	TRG_RecordApiIssueAfterInsert.reset();
	List<kern__ApiIssue__c> bulkIssues = new List<kern__ApiIssue__c>();
	for(Integer index = 0; index < BULK_ISSUE_COUNT; index++)
	{
		bulkIssues.add(new kern__ApiIssue__c(kern__ServiceName__c = MATCHING_SERVICE_NAME, kern__Status__c = STATUS_OPEN,
				kern__Direction__c = DIRECTION_OUTBOUND));
	}
	String bulkInsertError;
	try
	{
		insert bulkIssues;
	}
	catch(Exception insertException)
	{
		bulkInsertError = insertException.getMessage();
	}

	if(bulkInsertError != null)
	{
		System.debug('90c FAIL: not counted, because the insert of 201 API issues failed: ' + bulkInsertError);
	}
	else if(TRG_RecordApiIssueAfterInsert.callCount == EXPECTED_BULK_CALLS)
	{
		System.debug('90c PASS: 201 matching issues in one insert called the action twice, once for each group of up to 200 records');
	}
	else if(TRG_RecordApiIssueAfterInsert.callCount == 0)
	{
		System.debug('90c FAIL: the after-insert event: the action was not called at all for 201 matching issues');
	}
	else
	{
		System.debug('90c FAIL: the count: expected ' + EXPECTED_BULK_CALLS + ' calls for 201 issues, got ' + TRG_RecordApiIssueAfterInsert.callCount);
	}

	if(bulkInsertError != null)
	{
		System.debug('90d FAIL: not counted, because the insert of 201 API issues failed');
	}
	else if(TRG_RecordApiIssueAfterInsert.recordCount == BULK_ISSUE_COUNT)
	{
		System.debug('90d PASS: the calls received the 201 issues in all');
	}
	else
	{
		System.debug('90d FAIL: the count: expected ' + BULK_ISSUE_COUNT + ' records in all, got ' + TRG_RecordApiIssueAfterInsert.recordCount);
	}

	// 90e + 90f: one insert, read twice: the post-trigger action scoped to the subscriber's API Issue setting, and the
	// framework's own before-insert action, which runs from the framework's protected setting beside the subscriber's
	TST_PostActionRecorder.reset();
	TRG_RecordApiIssueAfterInsert.reset();
	kern__ApiIssue__c singleIssue = new kern__ApiIssue__c(kern__ServiceName__c = MATCHING_SERVICE_NAME, kern__Status__c = STATUS_OPEN,
			kern__Direction__c = DIRECTION_OUTBOUND, kern__TriggeringRecordId__c = TRIGGERING_RECORD_ID);
	String singleInsertError;
	try
	{
		insert singleIssue;
	}
	catch(Exception insertException)
	{
		singleInsertError = insertException.getMessage();
	}

	if(singleInsertError != null)
	{
		System.debug('90e FAIL: not counted, because the insert of one API issue failed: ' + singleInsertError);
		System.debug('90f FAIL: not checked, because the insert of one API issue failed');
	}
	else
	{
		Integer postActionRuns = TST_PostActionRecorder.invocationCounts.get(POST_ACTION_NAME) ?? 0;
		if(postActionRuns == EXPECTED_POST_ACTION_RUNS)
		{
			System.debug('90e PASS: one API issue insert ran the post-trigger action scoped to API issues 2 times, once after each trigger pass');
		}
		else
		{
			System.debug('90e FAIL: the count: expected the post-trigger action scoped to API issues to run ' + EXPECTED_POST_ACTION_RUNS
					+ ' times for one API issue insert, got ' + postActionRuns + ' (0 means the row on the subscriber setting never matched,'
					+ ' 1 means only the before pass ran)');
		}

		String savedIndex = [SELECT kern__TriggeringRecordIndex__c FROM kern__ApiIssue__c WHERE Id = :singleIssue.Id].kern__TriggeringRecordIndex__c;
		Boolean frameworkActionRan = savedIndex == TRIGGERING_RECORD_ID;
		Boolean subscriberActionRan = TRG_RecordApiIssueAfterInsert.callCount == 1;
		if(frameworkActionRan && subscriberActionRan)
		{
			System.debug('90f PASS: the framework\'s own action filled Triggering Record Index, and the subscriber action ran on the same insert');
		}
		else if(!frameworkActionRan)
		{
			System.debug('90f FAIL: the framework\'s own action: Triggering Record Index is ' + savedIndex + ', expected ' + TRIGGERING_RECORD_ID
					+ '. The subscriber setting for the API Issue object replaced the framework\'s rows instead of adding to them');
		}
		else
		{
			System.debug('90f FAIL: the after-insert event: the framework\'s own action ran, but the subscriber action was called '
					+ TRG_RecordApiIssueAfterInsert.callCount + ' time(s) on the same insert, expected 1');
		}
	}

	System.debug('========================================');
	System.debug('Section 90: all checks completed (6 expected)');
	System.debug('========================================');
}
finally
{
	Database.rollback(beforeSection);
	kern.TRG_Base.clearAllBypasses();
	kern.TRG_Base.clearAllActionBypasses();
}
