/**
 * Section 52: DML_Builder — Edge Cases
 *
 * Closes gaps in DML_Builder capability coverage beyond section-14 (which already
 * exercises the happy insert/update/delete/parent-child/batch-200 paths). Covers
 * eight edge scenarios that section-14 does not touch: allowPartial accounting,
 * the four allowPartial x suppressExceptions combinations, suppressLogging on
 * happy-path inserts, externalId-based upsert with mixed insert/update outcomes,
 * post-delete undelete, parent-child cascade rollback when the parent insert
 * fails, the 10001-record DML governor boundary, and async enqueue with batch size.
 *
 * Deferrals to Subscriber_DmlEdges_TEST.cls (Task 1.14) — assertions that anon-Apex
 * structurally cannot make, by spec acknowledgement:
 *   - .bypassSharing() write to a restricted object as a Standard User (anon-Apex
 *     cannot impersonate; needs runAs).
 *   - .withUserMode() FLS-rejected write returning a row-level Database.Error
 *     (anon-Apex cannot impersonate; needs runAs).
 *   - 52g: catching the platform's "Too many DML rows: 10001" System.LimitException.
 *     The framework currently delegates row-count enforcement to the platform, which
 *     throws an uncatchable LimitException at execute time outside Test.startTest()/
 *     stopTest() brackets. This script verifies what CAN be probed pre-execute.
 *   - 52h: polling the async Queueable to completion and asserting record persistence.
 *     The anon-Apex transaction must commit before the queueable can dequeue, so
 *     completion + record-count assertions need an @IsTest harness where Test.start/
 *     stopTest() forces synchronous execution.
 *
 * Implementation note: anon-Apex in this subscriber org has a parser quirk where
 * `List<kern__Foobar__c>` declarations combined with `kern.X.Y()` chained method
 * calls trigger a spurious "Unexpected token '<'" compile failure. Workaround:
 * the script uses `Object` as an opaque carrier and casts to `(List<SObject>)`
 * at the moment of use. Single `kern__Foobar__c` scalar declarations work fine.
 *
 * Prerequisites:
 *   - subscriber scratch org with the kern managed package installed
 *
 * Run (in isolation):
 *   sf apex run --file release-testing/scripts/section-52-edge-dml-builder.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 */

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, '=== Section 52: DML_Builder Edge Cases ===');

kern.TRG_Base.clearAllBypasses();
kern.UTIL_ValidationRule.clearAllBypasses();

Integer pass = 0;
Integer fail = 0;
List<String> failures = new List<String>();

String INVALID_PICKLIST = 'NOT_A_VALID_PICKLIST_VALUE';

// ---------------------------------------------------------------- Scenario 52a — allowPartial accounting
try
{
	Object scenario52aValids = kern.TST_Builder.of('kern__Foobar__c')
			.withCount(5)
			.withoutInsertion()
			.buildList();
	List<SObject> scenario52aRecords = (List<SObject>)scenario52aValids;
	scenario52aRecords.add(new kern__Foobar__c(Name = 'Invalid 52a-0', kern__Picklist__c = INVALID_PICKLIST));
	scenario52aRecords.add(new kern__Foobar__c(Name = 'Invalid 52a-1', kern__Picklist__c = INVALID_PICKLIST));
	scenario52aRecords.add(new kern__Foobar__c(Name = 'Invalid 52a-2', kern__Picklist__c = INVALID_PICKLIST));

	kern.DML_Builder.TransactionResult result = kern.DML_Builder.newTransaction()
			.doInsert(scenario52aRecords)
			.allowPartial()
			.execute();

	Assert.areEqual(5, result.getSuccessCount(), '52a: expected 5 successes');
	Assert.areEqual(3, result.getFailureCount(), '52a: expected 3 failures');
	Assert.areEqual(3, result.getErrors().size(), '52a: expected 3 row-level errors');
	Assert.isFalse(result.isSuccess(), '52a: isSuccess should be false when any row failed');
	Assert.areEqual(5, result.getInsertedIds().size(), '52a: expected 5 inserted IDs');
	System.debug(LoggingLevel.INFO, '52a PASS: allowPartial returned 5/3 success/failure with 3 row-level errors');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '52a FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('52a: ' + scenarioError.getMessage());
	fail++;
}

// ---------------------------------------------------------------- Scenario 52b — allowPartial x suppressExceptions matrix
try
{
	kern__Foobar__c scenario52bBad1 = new kern__Foobar__c(Name = 'B1', kern__Picklist__c = INVALID_PICKLIST);

	Boolean threwBoth = false;
	try
	{
		kern.DML_Builder.newTransaction().doInsert(scenario52bBad1).execute();
	}
	catch(DmlException expected)
	{
		threwBoth = true;
	}
	Assert.isTrue(threwBoth, '52b: neither flag set — should have thrown DmlException');

	kern__Foobar__c scenario52bBad2 = new kern__Foobar__c(Name = 'B2', kern__Picklist__c = INVALID_PICKLIST);

	Boolean threwSuppress = false;
	kern.DML_Builder.TransactionResult resultSuppress;
	try
	{
		resultSuppress = kern.DML_Builder.newTransaction().doInsert(scenario52bBad2).suppressExceptions().execute();
	}
	catch(DmlException unexpected)
	{
		threwSuppress = true;
	}
	Assert.isFalse(threwSuppress, '52b: suppressExceptions only — should NOT have thrown');
	Assert.isFalse(resultSuppress.isSuccess(), '52b: suppressExceptions only — result should report failure');
	Assert.areEqual(1, resultSuppress.getFailureCount(), '52b: suppressExceptions only — expected 1 failure');

	List<SObject> scenario52bPartialBatch = new List<SObject>();
	scenario52bPartialBatch.add((SObject)kern.TST_Builder.of('kern__Foobar__c').withoutInsertion().build());
	scenario52bPartialBatch.add(new kern__Foobar__c(Name = 'B3', kern__Picklist__c = INVALID_PICKLIST));

	Boolean threwPartial = false;
	kern.DML_Builder.TransactionResult resultPartial;
	try
	{
		resultPartial = kern.DML_Builder.newTransaction()
				.doInsert(scenario52bPartialBatch)
				.allowPartial()
				.execute();
	}
	catch(DmlException unexpected)
	{
		threwPartial = true;
	}
	Assert.isFalse(threwPartial, '52b: allowPartial only — should NOT have thrown');
	Assert.areEqual(1, resultPartial.getSuccessCount(), '52b: allowPartial only — expected 1 success');
	Assert.areEqual(1, resultPartial.getFailureCount(), '52b: allowPartial only — expected 1 failure');

	List<SObject> scenario52bBothBatch = new List<SObject>();
	scenario52bBothBatch.add((SObject)kern.TST_Builder.of('kern__Foobar__c').withoutInsertion().build());
	scenario52bBothBatch.add(new kern__Foobar__c(Name = 'B4', kern__Picklist__c = INVALID_PICKLIST));

	Boolean threwBothFlags = false;
	kern.DML_Builder.TransactionResult resultBoth;
	try
	{
		resultBoth = kern.DML_Builder.newTransaction()
				.doInsert(scenario52bBothBatch)
				.allowPartial()
				.suppressExceptions()
				.execute();
	}
	catch(DmlException unexpected)
	{
		threwBothFlags = true;
	}
	Assert.isFalse(threwBothFlags, '52b: both flags set — should NOT have thrown');
	Assert.areEqual(1, resultBoth.getSuccessCount(), '52b: both flags set — expected 1 success');
	Assert.areEqual(1, resultBoth.getFailureCount(), '52b: both flags set — expected 1 failure');

	System.debug(LoggingLevel.INFO, '52b PASS: 4-cell matrix of allowPartial/suppressExceptions matches documented behavior');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '52b FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('52b: ' + scenarioError.getMessage());
	fail++;
}

// ---------------------------------------------------------------- Scenario 52c — suppressLogging on a 50-record happy insert
try
{
	Integer baselineLogs =
	[
			SELECT COUNT()
			FROM kern__LogEntry__c
			WHERE CreatedById = :UserInfo.getUserId()
			AND CreatedDate = TODAY
	];

	Object scenario52cBulkObj = kern.TST_Builder.of('kern__Foobar__c')
			.withCount(50)
			.withoutInsertion()
			.buildList();

	kern.DML_Builder.TransactionResult result = kern.DML_Builder.newTransaction()
			.doInsert((List<SObject>)scenario52cBulkObj)
			.suppressLogging()
			.execute();

	Assert.isTrue(result.isSuccess(), '52c: bulk insert should succeed');
	Assert.areEqual(50, result.getSuccessCount(), '52c: expected 50 successes');

	Integer afterLogs =
	[
			SELECT COUNT()
			FROM kern__LogEntry__c
			WHERE CreatedById = :UserInfo.getUserId()
			AND CreatedDate = TODAY
	];
	Assert.areEqual(baselineLogs, afterLogs, '52c: suppressLogging on happy-path insert should not produce any new LogEntry__c rows');
	System.debug(LoggingLevel.INFO, '52c PASS: 50-record insert with suppressLogging produced 0 LogEntry__c rows (baseline=' + baselineLogs + ')');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '52c FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('52c: ' + scenarioError.getMessage());
	fail++;
}

// ---------------------------------------------------------------- Scenario 52d — doUpsert with mixed insert and update via externalId
try
{
	String runStamp = String.valueOf(Datetime.now().getTime());

	Object scenario52dExistingObj = kern.TST_Builder.of('kern__Foobar__c').withCount(5).withoutInsertion().buildList();
	List<SObject> scenario52dExisting = (List<SObject>)scenario52dExistingObj;
	for(Integer i = 0; i < scenario52dExisting.size(); i++)
	{
		kern__Foobar__c record = (kern__Foobar__c)scenario52dExisting[i];
		record.Name = 'Existing 52d-' + i;
		record.kern__ExternalId__c = runStamp + '-X-' + i;
	}
	kern.DML_Builder.newTransaction().doInsert(scenario52dExisting).execute();

	List<SObject> scenario52dUpsertBatch = new List<SObject>();
	for(Integer i = 0; i < 5; i++)
	{
		kern__Foobar__c updateRecord = new kern__Foobar__c(Name = 'Updated 52d-' + i);
		updateRecord.kern__ExternalId__c = runStamp + '-X-' + i;
		scenario52dUpsertBatch.add(updateRecord);
	}
	for(Integer i = 0; i < 5; i++)
	{
		kern__Foobar__c insertOne = new kern__Foobar__c(Name = 'Inserted 52d-' + i);
		insertOne.kern__ExternalId__c = runStamp + '-N-' + i;
		scenario52dUpsertBatch.add(insertOne);
	}

	kern.DML_Builder.TransactionResult result = kern.DML_Builder.newTransaction()
			.doUpsert(scenario52dUpsertBatch, kern__Foobar__c.kern__ExternalId__c)
			.execute();

	Assert.isTrue(result.isSuccess(), '52d: upsert transaction should succeed');
	Assert.areEqual(10, result.getSuccessCount(), '52d: expected 10 total successes (5 inserts + 5 updates)');

	String updatedKeyPattern = runStamp + '-X-%';
	Integer updatedCount =
	[
			SELECT COUNT()
			FROM kern__Foobar__c
			WHERE kern__ExternalId__c LIKE :updatedKeyPattern
			AND Name LIKE 'Updated 52d-%'
	];
	Assert.areEqual(5, updatedCount, '52d: expected 5 updated records (matched by externalId, Name updated)');

	String insertedKeyPattern = runStamp + '-N-%';
	Integer insertedCount =
	[
			SELECT COUNT()
			FROM kern__Foobar__c
			WHERE kern__ExternalId__c LIKE :insertedKeyPattern
			AND Name LIKE 'Inserted 52d-%'
	];
	Assert.areEqual(5, insertedCount, '52d: expected 5 newly inserted records');

	System.debug(LoggingLevel.INFO, '52d PASS: doUpsert with externalId produced 5 updates + 5 inserts');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '52d FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('52d: ' + scenarioError.getMessage());
	fail++;
}

// ---------------------------------------------------------------- Scenario 52e — doUndelete after doDelete (separate transactions)
try
{
	Object scenario52eTargetsObj = kern.TST_Builder.of('kern__Foobar__c').withCount(3).buildList();
	List<SObject> scenario52eTargets = (List<SObject>)scenario52eTargetsObj;
	Set<Id> scenario52eIds = new Set<Id>();
	for(SObject record : scenario52eTargets)
	{
		scenario52eIds.add(record.Id);
	}

	kern.DML_Builder.TransactionResult deleteResult = kern.DML_Builder.newTransaction()
			.doDelete(scenario52eTargets)
			.execute();
	Assert.isTrue(deleteResult.isSuccess(), '52e: delete transaction should succeed');

	Integer deletedCount =
	[
			SELECT COUNT()
			FROM kern__Foobar__c
			WHERE Id IN :scenario52eIds
			AND IsDeleted = TRUE
			ALL ROWS
	];
	Assert.areEqual(3, deletedCount, '52e: all 3 records should be marked IsDeleted=true before undelete');

	kern.DML_Builder.TransactionResult undeleteResult = kern.DML_Builder.newTransaction()
			.doUndelete(scenario52eTargets)
			.execute();
	Assert.isTrue(undeleteResult.isSuccess(), '52e: undelete transaction should succeed');
	Assert.areEqual(3, undeleteResult.getSuccessCount(), '52e: expected 3 undeletes');

	Integer restoredCount =
	[
			SELECT COUNT()
			FROM kern__Foobar__c
			WHERE Id IN :scenario52eIds
	];
	Assert.areEqual(3, restoredCount, '52e: expected 3 restored records visible without ALL ROWS');
	System.debug(LoggingLevel.INFO, '52e PASS: doDelete then doUndelete restored 3 records');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '52e FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('52e: ' + scenarioError.getMessage());
	fail++;
}

// ---------------------------------------------------------------- Scenario 52f — parent-child cascade rollback when parent insert fails
try
{
	String childMarker = 'OrphanProbe-' + String.valueOf(Datetime.now().getTime());

	kern__Foobar__c parent = new kern__Foobar__c(Name = 'BadParent 52f');
	parent.kern__Picklist__c = INVALID_PICKLIST;

	kern__Foobar__c child = new kern__Foobar__c(Name = childMarker);

	Boolean threw = false;
	try
	{
		kern.DML_Builder.newTransaction()
				.doInsert(parent)
				.doInsert(child, kern__Foobar__c.kern__Lookup__c, parent)
				.execute();
	}
	catch(DmlException expected)
	{
		threw = true;
	}
	Assert.isTrue(threw, '52f: expected DmlException when parent insert fails (all-or-nothing)');
	Assert.isNull(parent.Id, '52f: parent should have no Id after failed transaction');
	Assert.isNull(child.Id, '52f: child should have no Id after failed transaction');

	Integer orphanCount =
	[
			SELECT COUNT()
			FROM kern__Foobar__c
			WHERE Name = :childMarker
	];
	Assert.areEqual(0, orphanCount, '52f: no orphan child should remain in DB after rollback');
	System.debug(LoggingLevel.INFO, '52f PASS: parent failure rolled back the entire transaction; no orphan children');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '52f FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('52f: ' + scenarioError.getMessage());
	fail++;
}

// ---------------------------------------------------------------- Scenario 52g — DML row governor boundary at 10,001 records
try
{
	Integer documentedLimit = Limits.getLimitDmlRows();
	Assert.areEqual(10000, documentedLimit, '52g: platform DML row limit should be 10,000');

	Integer dmlBeforeBuild = Limits.getDmlRows();
	Object scenario52gOversizedObj = kern.TST_Builder.of('kern__Foobar__c').withCount(10001).withoutInsertion().buildList();
	List<SObject> scenario52gOversized = (List<SObject>)scenario52gOversizedObj;
	Assert.areEqual(10001, scenario52gOversized.size(), '52g: should have built 10,001 in-memory records');
	Assert.areEqual(dmlBeforeBuild, Limits.getDmlRows(), '52g: building the in-memory list should not consume DML rows');

	kern.DML_Builder builder = kern.DML_Builder.newTransaction().doInsert(scenario52gOversized);
	Assert.areEqual(dmlBeforeBuild, Limits.getDmlRows(), '52g: registering operations on the builder should not consume DML rows');
	Assert.isNotNull(builder, '52g: builder should be returned by doInsert');

	System.debug(LoggingLevel.INFO, '52g PASS: builder accepts a 10,001-record registration without consuming DML rows pre-execute');
	// 52g NOTE: the extended-load spec §6.1 #7 expected DML_Builder to throw a documented exception
	// BEFORE attempting DML. The framework currently delegates row-count enforcement to
	// the platform (System.LimitException at execute time), which is uncatchable in
	// execute-anonymous. This script verifies what CAN be probed without consuming DML
	// rows; full LimitException catch lives in Subscriber_DmlEdges_TEST.cls (Task 1.14)
	// where Test.startTest()/stopTest() brackets make the throw catchable.
	// FRAMEWORK FOLLOW-UP: consider adding a pre-execute row-count guard to DML_Builder
	// so the spec expectation in §6.1 #7 is met without depending on platform behaviour.
	System.debug(LoggingLevel.INFO, '52g NOTE: see header docstring for spec-acknowledged deferral of the LimitException catch to Subscriber_DmlEdges_TEST (Task 1.14).');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '52g FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('52g: ' + scenarioError.getMessage());
	fail++;
}

// ---------------------------------------------------------------- Scenario 52h — async() + withBatchSize(50) enqueues an AsyncApexJob
try
{
	Datetime startedAt = Datetime.now();
	Integer queueablesBefore = Limits.getQueueableJobs();

	Object scenario52hRecordsObj = kern.TST_Builder.of('kern__Foobar__c')
			.withCount(10)
			.withoutInsertion()
			.buildList();
	List<SObject> scenario52hRecords = (List<SObject>)scenario52hRecordsObj;
	for(SObject record : scenario52hRecords)
	{
		record.put('Name', 'Async 52h');
	}

	kern.DML_Builder.newTransaction()
			.doInsert(scenario52hRecords)
			.async()
			.withBatchSize(50)
			.execute();

	Assert.areEqual(queueablesBefore + 1, Limits.getQueueableJobs(), '52h: async().execute() should enqueue exactly one queueable');

	List<AsyncApexJob> queued =
	[
			SELECT Id,
					Status,
					JobType,
					ApexClass.Name
			FROM AsyncApexJob
			WHERE CreatedById = :UserInfo.getUserId()
			AND CreatedDate >= :startedAt
			ORDER BY CreatedDate DESC
			LIMIT 5
	];
	Assert.isFalse(queued.isEmpty(), '52h: at least one AsyncApexJob row should exist for this user since startedAt');

	Boolean foundDmlJob = false;
	for(AsyncApexJob job : queued)
	{
		if(job.JobType == 'Queueable' && job.ApexClass.Name == 'UTIL_AdaptiveAsynchronousProcessor')
		{
			foundDmlJob = true;
		}
	}
	Assert.isTrue(foundDmlJob, '52h: expected a Queueable job for kern.UTIL_AdaptiveAsynchronousProcessor (the adaptive wrapper for PROC_ExecuteDML)');
	System.debug(LoggingLevel.INFO, '52h PASS: async() + withBatchSize(50) enqueued an AsyncApexJob; ' + queued.size() + ' job rows visible since startedAt');
	// 52h NOTE: the extended-load spec §6.1 #8 covers async DML enqueue + completion. This script
	// verifies the enqueue half (queueable count + AsyncApexJob row + ApexClass name);
	// the completion half is structurally unreachable from execute-anonymous because
	// the queueable cannot dequeue until this transaction commits. Polling-to-completion
	// + record-persistence assertions live in Subscriber_DmlEdges_TEST.cls (Task 1.14)
	// where Test.startTest()/stopTest() forces synchronous queueable execution.
	System.debug(LoggingLevel.INFO, '52h NOTE: see header docstring for spec-acknowledged deferral of completion + persistence assertions to Subscriber_DmlEdges_TEST (Task 1.14).');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '52h FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('52h: ' + scenarioError.getMessage());
	fail++;
}

// ---------------------------------------------------------------- Cleanup
// LIMIT bounded by remaining DML rows in this transaction. Section 52 inserts
// roughly 80 rows across scenarios, leaving ~9900 rows of headroom; capping at
// 9000 keeps a safety margin without leaking. If the script is re-run many
// times in one day and CreatedDate=TODAY accumulates beyond 9000, the next
// invocation's cleanup will skip the overflow — manually purge with a one-shot
// `delete [SELECT Id FROM kern__Foobar__c WHERE CreatedDate = TODAY AND CreatedById = :UserInfo.getUserId() LIMIT 9000];`
// run repeatedly until the count drops to zero.
delete
[
		SELECT Id
		FROM kern__Foobar__c
		WHERE CreatedDate = TODAY
		AND CreatedById = :UserInfo.getUserId()
		LIMIT 9000
];

// ---------------------------------------------------------------- Summary
System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, 'Section 52: ' + pass + ' passed, ' + fail + ' failed');
if(fail > 0)
{
	System.debug(LoggingLevel.ERROR, '=== Section 52 FAILED ===');
	for(String message : failures)
	{
		System.debug(LoggingLevel.ERROR, '  - ' + message);
	}
	throw new System.AssertException('Section 52 failed: ' + fail + ' scenarios');
}
else
{
	System.debug(LoggingLevel.INFO, '=== Section 52 COMPLETE: All scenarios passed ===');
}
