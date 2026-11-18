// SPDX-License-Identifier: Apache-2.0
/**
 * @description Tests for TRG_SetTriggeringRecordIndex, the trigger action that copies the Triggering Record ID field
 * into the Triggering Record Index field on every save of an API call or an API issue.
 *
 * Every test saves real rows, so the trigger runs the action as it does in the org. The rows are saved and read back in
 * system mode, because field access is not what these tests check. The value is compared with a case-sensitive check,
 * because Triggering Record Index must hold the value exactly as written.
 *
 * @see TRG_SetTriggeringRecordIndex
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date November 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.ApexUnitTestClassShouldHaveAsserts,PMD.CyclomaticComplexity')
@IsTest(seeAllData=false isParallel=true)
private class TRG_SetTriggeringRecordIndex_TEST
{
	/**
	 * @description An order number from another system. It is not a Salesforce record Id, and Triggering Record Index
	 * must hold it too.
	 */
	private static final String ORDER_NUMBER = 'ORD-99182';

	/**
	 * @description The most characters the Triggering Record ID field of an API call can hold.
	 */
	private static final Integer API_CALL_SOURCE_LENGTH = 80;

	/**
	 * @description The number of rows in one bulk insert: the most a trigger receives at once.
	 */
	private static final Integer BATCH_SIZE = 200;

	/**
	 * @description The number of API calls each copy job works on in the tests that fill Triggering Record Index with
	 * the bulk update utility.
	 */
	private static final Integer ROWS_PER_JOB = 4;

	/**
	 * @description The service name of the API calls that the queued job fills.
	 */
	private static final String QUEUED_JOB_SERVICE = 'TRG_SetTriggeringRecordIndex_TEST-queued';

	/**
	 * @description The service name of the API calls that the batch job fills.
	 */
	private static final String BATCH_JOB_SERVICE = 'TRG_SetTriggeringRecordIndex_TEST-batch';

	/**
	 * @description The status of a job that has ended, as Salesforce stores it on the job record.
	 */
	private static final String JOB_STATUS_COMPLETED = 'Completed';

	/**
	 * @description The name of the saved login the HTTP client test sends its call with. The test answers the call with a
	 * prepared response, so no such login needs to exist.
	 */
	private static final String HTTP_CREDENTIAL = 'SetIndexTestCredential';

	/**
	 * @description The address path the HTTP client test sends its call to.
	 */
	private static final String HTTP_PATH = '/api/v1/resource';

	/**
	 * @description The prepared response body that answers the HTTP client test's call.
	 */
	private static final String HTTP_RESPONSE_BODY = '{"status":"ok"}';

	/**
	 * @description A new API call with a record Id in its source field gets the same value in its Triggering Record Index.
	 */
	@IsTest
	private static void shouldSetTheIndexFieldOnInsert()
	{
		String recordId = UTIL_Random.randomId(Foobar__c.SObjectType);

		SObject apiCall = insertRow(ApiCall__c.SObjectType, recordId);

		assertIndexFieldEquals(apiCall, recordId);
	}

	/**
	 * @description A new API issue with a record Id in its source field gets the same value in its Triggering Record Index.
	 */
	@IsTest
	private static void shouldSetTheIndexFieldOnInsertOfAnIssue()
	{
		String recordId = UTIL_Random.randomId(Foobar__c.SObjectType);

		SObject apiIssue = insertRow(ApiIssue__c.SObjectType, recordId);

		assertIndexFieldEquals(apiIssue, recordId);
	}

	/**
	 * @description A 15-character record Id goes into Triggering Record Index as it is. It is not changed into the
	 * 18-character form, and its upper and lower case letters stay as they were.
	 */
	@IsTest
	private static void shouldKeepAFifteenCharacterIdAsWritten()
	{
		String shortId = UTIL_Random.randomId(Foobar__c.SObjectType).to15();

		SObject apiCall = insertRow(ApiCall__c.SObjectType, shortId);

		assertIndexFieldEquals(apiCall, shortId);
	}

	/**
	 * @description On an API issue too, a 15-character record Id goes into Triggering Record Index as it is.
	 */
	@IsTest
	private static void shouldKeepAFifteenCharacterIdAsWrittenOnAnIssue()
	{
		String shortId = UTIL_Random.randomId(Foobar__c.SObjectType).to15();

		SObject apiIssue = insertRow(ApiIssue__c.SObjectType, shortId);

		assertIndexFieldEquals(apiIssue, shortId);
	}

	/**
	 * @description A value that is not a record Id, such as an order number, goes into Triggering Record Index as it is.
	 * The action does not check that the value is an Id.
	 */
	@IsTest
	private static void shouldCopyAValueThatIsNotARecordId()
	{
		SObject apiCall = insertRow(ApiCall__c.SObjectType, ORDER_NUMBER);

		assertIndexFieldEquals(apiCall, ORDER_NUMBER);
	}

	/**
	 * @description On an API issue too, a value that is not a record Id goes into Triggering Record Index as it is.
	 */
	@IsTest
	private static void shouldCopyAValueThatIsNotARecordIdOnAnIssue()
	{
		SObject apiIssue = insertRow(ApiIssue__c.SObjectType, ORDER_NUMBER);

		assertIndexFieldEquals(apiIssue, ORDER_NUMBER);
	}

	/**
	 * @description The longest value the source field of an API call can hold, 80 characters, fits in Triggering Record
	 * Index whole. Only the API call is checked: the source field of an API issue holds 18 characters.
	 */
	@IsTest
	private static void shouldCopyAnEightyCharacterValue()
	{
		String longValue = UTIL_Random.randomAlphanumeric(API_CALL_SOURCE_LENGTH);
		Assert.areEqual(API_CALL_SOURCE_LENGTH, longValue.length(), 'Expected the test value to fill the source field');

		SObject apiCall = insertRow(ApiCall__c.SObjectType, longValue);

		assertIndexFieldEquals(apiCall, longValue);
	}

	/**
	 * @description An API call saved with no value in its source field has no value in its Triggering Record Index.
	 */
	@IsTest
	private static void shouldLeaveTheIndexFieldBlankWhenTheSourceIsBlank()
	{
		SObject apiCall = insertRow(ApiCall__c.SObjectType, null);

		assertIndexFieldEquals(apiCall, null);
	}

	/**
	 * @description An API issue saved with no value in its source field has no value in its Triggering Record Index.
	 */
	@IsTest
	private static void shouldLeaveTheIndexFieldBlankWhenTheSourceIsBlankOnAnIssue()
	{
		SObject apiIssue = insertRow(ApiIssue__c.SObjectType, null);

		assertIndexFieldEquals(apiIssue, null);
	}

	/**
	 * @description When the source field of a saved API call changes, Triggering Record Index changes with it. It moves
	 * from a record Id to another record Id, then to an order number. The field never keeps an old value.
	 */
	@IsTest
	private static void shouldFollowTheSourceWhenItChangesToAnotherValue()
	{
		SObject apiCall = insertRow(ApiCall__c.SObjectType, UTIL_Random.randomId(Foobar__c.SObjectType));
		String otherRecordId = UTIL_Random.randomId(Foobar__c.SObjectType);

		updateSource(apiCall, otherRecordId);
		assertIndexFieldEquals(apiCall, otherRecordId);

		updateSource(apiCall, ORDER_NUMBER);
		assertIndexFieldEquals(apiCall, ORDER_NUMBER);
	}

	/**
	 * @description When the source field of a saved API issue changes, Triggering Record Index changes with it.
	 */
	@IsTest
	private static void shouldFollowTheSourceWhenItChangesToAnotherValueOnAnIssue()
	{
		SObject apiIssue = insertRow(ApiIssue__c.SObjectType, UTIL_Random.randomId(Foobar__c.SObjectType));
		String otherRecordId = UTIL_Random.randomId(Foobar__c.SObjectType);

		updateSource(apiIssue, otherRecordId);
		assertIndexFieldEquals(apiIssue, otherRecordId);

		updateSource(apiIssue, ORDER_NUMBER);
		assertIndexFieldEquals(apiIssue, ORDER_NUMBER);
	}

	/**
	 * @description When the source field of a saved API call is cleared, Triggering Record Index is cleared too.
	 */
	@IsTest
	private static void shouldBlankTheIndexFieldWhenTheSourceIsCleared()
	{
		SObject apiCall = insertRow(ApiCall__c.SObjectType, ORDER_NUMBER);

		updateSource(apiCall, null);

		assertIndexFieldEquals(apiCall, null);
	}

	/**
	 * @description When the source field of a saved API issue is cleared, Triggering Record Index is cleared too.
	 */
	@IsTest
	private static void shouldBlankTheIndexFieldWhenTheSourceIsClearedOnAnIssue()
	{
		SObject apiIssue = insertRow(ApiIssue__c.SObjectType, ORDER_NUMBER);

		updateSource(apiIssue, null);

		assertIndexFieldEquals(apiIssue, null);
	}

	/**
	 * @description A save that writes a different value into Triggering Record Index of an API call, and leaves the
	 * source alone, ends with the source value in the field. The field cannot be set apart from its source.
	 */
	@IsTest
	private static void shouldOverwriteAnIndexFieldWrittenDirectly()
	{
		String recordId = UTIL_Random.randomId(Foobar__c.SObjectType);
		SObject apiCall = insertRow(ApiCall__c.SObjectType, recordId);

		updateIndexField(apiCall, ORDER_NUMBER);

		assertIndexFieldEquals(apiCall, recordId);
	}

	/**
	 * @description A save that writes a different value into Triggering Record Index of an API issue ends with the
	 * source value in the field.
	 */
	@IsTest
	private static void shouldOverwriteAnIndexFieldWrittenDirectlyOnAnIssue()
	{
		String recordId = UTIL_Random.randomId(Foobar__c.SObjectType);
		SObject apiIssue = insertRow(ApiIssue__c.SObjectType, recordId);

		updateIndexField(apiIssue, ORDER_NUMBER);

		assertIndexFieldEquals(apiIssue, recordId);
	}

	/**
	 * @description The HTTP client saves an API call more than once while it sends it: first when the call starts, then
	 * again when the call ends. The first save copies the record's Id into Triggering Record Index. The later saves by
	 * the client do not lose it: at the end, the call still has that Id in both its source and the field. This test does
	 * not prove that a later save copies it again.
	 */
	@IsTest
	private static void shouldSetTheIndexFieldOnACallSavedSeveralTimesByTheHttpClient()
	{
		Id recordId = UTIL_Random.randomId(Foobar__c.SObjectType);
		API_MockFactory.forService(HTTP_CREDENTIAL).body(HTTP_RESPONSE_BODY).statusCode(API_Base.HTTP_OK).register();

		Test.startTest();

		API_Outbound handler = UTIL_HttpClient.get(HTTP_CREDENTIAL, HTTP_PATH).withTriggeringRecord(recordId).invoke();

		Test.stopTest();

		Assert.isTrue(handler.result.isSuccess, 'Expected the call to succeed, got ' + handler.result.errors);
		Assert.areEqual(SEL_ApiCall.STATUS_COMPLETED, handler.apiCall.Status__c, 'Expected the call to end as completed');
		assertIndexFieldEquals(handler.apiCall, String.valueOf(recordId));
	}

	/**
	 * @description While the trigger framework is turned off for API calls, a save does not run the action. Triggering
	 * Record Index keeps the value it had before the save, even though the source changed.
	 */
	@IsTest
	private static void shouldLeaveTheIndexFieldAsItWasWhenTheObjectIsBypassed()
	{
		String recordId = UTIL_Random.randomId(Foobar__c.SObjectType);
		SObject apiCall = insertRow(ApiCall__c.SObjectType, recordId);

		TRG_Base.bypass(ApiCall__c.SObjectType);
		updateSource(apiCall, ORDER_NUMBER);
		TRG_Base.clearBypass(ApiCall__c.SObjectType);

		SObject savedCall = readRows(new List<SObject> {apiCall})[0];
		Object sourceValue = savedCall.get(ApiCall__c.TriggeringRecordId__c);
		Object indexValue = savedCall.get(ApiCall__c.TriggeringRecordIndex__c);
		Assert.isTrue(ORDER_NUMBER.equals(sourceValue), 'Expected the source to change to ' + ORDER_NUMBER + ', got ' + sourceValue);
		Assert.isTrue(recordId.equals(indexValue), 'Expected Triggering Record Index to keep ' + recordId + ', got ' + indexValue);
	}

	/**
	 * @description A full batch of API calls with a mix of 18-character Ids, 15-character Ids, order numbers and long
	 * outside references gets Triggering Record Index on every row filled with that row's own source value.
	 */
	@IsTest
	private static void shouldSetEveryRowInABulkInsert()
	{
		List<SObject> apiCalls = TST_Factory.getApiCallBuilder()
				.withCount(BATCH_SIZE)
				.withCycle(ApiCall__c.TriggeringRecordId__c, buildMixedSourceValues())
				.buildList();

		List<SObject> savedCalls = readRows(apiCalls);
		Assert.areEqual(BATCH_SIZE, savedCalls.size(), 'Expected every API call in the batch to be saved');
		for(SObject savedCall : savedCalls)
		{
			String sourceValue = (String)savedCall.get(ApiCall__c.TriggeringRecordId__c);
			Assert.isNotNull(sourceValue, 'Expected every API call in the batch to have a source value');
			Assert.isTrue
					(
							sourceValue.equals(savedCall.get(ApiCall__c.TriggeringRecordIndex__c)),
							'Expected Triggering Record Index to equal the source exactly, got ' + savedCall.get(ApiCall__c.TriggeringRecordIndex__c)
					);
		}
	}

	/**
	 * @description API calls saved before Triggering Record Index existed have the field blank. The optional fill in the
	 * release note copies the Triggering Record ID field into the field with the bulk update utility, and every row then
	 * holds its value.
	 * The job runs as a user with the Administrator permission set, as the release note asks.
	 */
	@IsTest
	private static void shouldFillIndexFieldsThroughCopyField()
	{
		System.runAs(insertAdministrator())
		{
			List<SObject> apiCalls = insertRowsWithBlankIndexFields(QUEUED_JOB_SERVICE);

			Test.startTest();

			copyIndexFieldsWithTheBulkUpdateUtility(QUEUED_JOB_SERVICE);

			Test.stopTest();

			assertEveryIndexFieldEqualsItsSource(apiCalls);
		}
	}

	/**
	 * @description A fill run ends, whichever way the job runs, even when the rows hold values that are not record Ids.
	 * One set of rows is filled by a queued job and another by a batch job. At the end each job has ended without
	 * errors, each row holds its source value as written, and the release note's search for rows with a source value
	 * and a blank Triggering Record Index finds none, so a second run would have nothing to do.
	 */
	@IsTest
	private static void shouldEndARunOverNonIdRows()
	{
		System.runAs(insertAdministrator())
		{
			List<SObject> queuedRows = insertRowsWithBlankIndexFields(QUEUED_JOB_SERVICE);
			List<SObject> batchRows = insertRowsWithBlankIndexFields(BATCH_JOB_SERVICE);

			Test.startTest();

			Id queuedJobId = startIndexFieldCopy(QUEUED_JOB_SERVICE, IF_Async.AsynchronousExecutionStrategy.PARALLEL_QUEUEABLES);
			Id batchJobId = startIndexFieldCopy(BATCH_JOB_SERVICE, IF_Async.AsynchronousExecutionStrategy.BATCH);

			Test.stopTest();

			assertRunEnded(queuedJobId, QUEUED_JOB_SERVICE, queuedRows);
			assertRunEnded(batchJobId, BATCH_JOB_SERVICE, batchRows);
		}
	}

	/**
	 * @description Builds source values of every shape Triggering Record Index must hold as written: an 18-character
	 * record Id, a 15-character record Id, an order number and an 80-character outside reference.
	 *
	 * @return The source values, to share out across rows in turn.
	 */
	private static List<Object> buildMixedSourceValues()
	{
		return new List<Object>
		{
				String.valueOf(UTIL_Random.randomId(Foobar__c.SObjectType)),
				UTIL_Random.randomId(Foobar__c.SObjectType).to15(),
				ORDER_NUMBER,
				UTIL_Random.randomAlphanumeric(API_CALL_SOURCE_LENGTH)
		};
	}

	/**
	 * @description Creates a user with the System Administrator profile and the Administrator permission set, the access
	 * the release note asks for before the Triggering Record Index fields are filled.
	 *
	 * @return The saved user.
	 */
	private static User insertAdministrator()
	{
		return TST_Factory.newUserWithPermissionSet
				(
						SEL_Profile.PROFILE_SYSTEM_ADMIN,
						UTIL_Random.randomName(),
						SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME
				);
	}

	/**
	 * @description Saves API calls for one service with a mix of record Ids and other values in their source field, with
	 * the trigger turned off so their Triggering Record Index fields stay blank, as on rows saved before the field
	 * existed. Checks that the fields are blank.
	 *
	 * @param serviceName The service name that marks the rows of one test job.
	 *
	 * @return The saved rows.
	 */
	private static List<SObject> insertRowsWithBlankIndexFields(String serviceName)
	{
		TRG_Base.bypass(ApiCall__c.SObjectType);
		List<SObject> apiCalls = TST_Factory.getApiCallBuilder()
				.withCount(ROWS_PER_JOB)
				.withOverride(ApiCall__c.ServiceName__c, serviceName)
				.withCycle(ApiCall__c.TriggeringRecordId__c, buildMixedSourceValues())
				.buildList();
		TRG_Base.clearBypass(ApiCall__c.SObjectType);

		for(SObject savedCall : readRows(apiCalls))
		{
			Assert.isNotNull(savedCall.get(ApiCall__c.TriggeringRecordId__c), 'Expected every test row to have a source value');
			Assert.isNull(savedCall.get(ApiCall__c.TriggeringRecordIndex__c), 'Expected every test row to start with a blank Triggering Record Index');
		}

		return apiCalls;
	}

	/**
	 * @description Builds the search the release note uses: rows with a source value and a blank Triggering Record
	 * Index. It also limits the search to the rows of one test job.
	 *
	 * @param serviceName The service name that marks the rows of one test job.
	 *
	 * @return The search conditions.
	 */
	private static QRY_Condition.Evaluable buildBlankIndexFieldCondition(String serviceName)
	{
		return new QRY_Condition.AndCondition()
				.add(new QRY_Condition.FieldCondition(UTIL_SObjectDescribe.getCachedFieldName(ApiCall__c.TriggeringRecordIndex__c)).equals(null))
				.add(new QRY_Condition.FieldCondition(UTIL_SObjectDescribe.getCachedFieldName(ApiCall__c.TriggeringRecordId__c)).notEquals(null))
				.add(new QRY_Condition.FieldCondition(UTIL_SObjectDescribe.getCachedFieldName(ApiCall__c.ServiceName__c)).equals(serviceName));
	}

	/**
	 * @description Fills the Triggering Record Index fields of one test job's rows with the bulk update utility, as the
	 * release note does. The utility starts a queued job for this number of rows.
	 *
	 * @param serviceName The service name that marks the rows of one test job.
	 */
	private static void copyIndexFieldsWithTheBulkUpdateUtility(String serviceName)
	{
		UTIL_BulkUpdates.copyField
				(
						UTIL_SObjectDescribe.getObjectNameFromType(ApiCall__c.SObjectType),
						UTIL_SObjectDescribe.getCachedFieldName(ApiCall__c.TriggeringRecordId__c),
						UTIL_SObjectDescribe.getCachedFieldName(ApiCall__c.TriggeringRecordIndex__c),
						buildBlankIndexFieldCondition(serviceName),
						BATCH_SIZE,
						false
				);
	}

	/**
	 * @description Fills the Triggering Record Index fields of one test job's rows with the same copy the bulk update
	 * utility sets up, run the given way.
	 *
	 * @param serviceName The service name that marks the rows of one test job.
	 * @param executionStrategy How the job runs: as queued jobs or as a batch job.
	 *
	 * @return The Id of the job.
	 */
	private static Id startIndexFieldCopy(String serviceName, IF_Async.AsynchronousExecutionStrategy executionStrategy)
	{
		PROC_UpdateFields processor = buildIndexFieldCopy(serviceName);
		UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request =
				new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(processor.buildQueryable())
						.withBatchSize(BATCH_SIZE)
						.withExecutionStrategy(executionStrategy);

		return UTIL_AsynchronousJobLauncher.process(request, processor);
	}

	/**
	 * @description Builds the copy of the source field into Triggering Record Index that the bulk update utility sets
	 * up, for the rows of one test job that the release note's search finds.
	 *
	 * @param serviceName The service name that marks the rows of one test job.
	 *
	 * @return The copy, ready to run or to search with.
	 */
	private static PROC_UpdateFields buildIndexFieldCopy(String serviceName)
	{
		PROC_UpdateFields.DTO_Parameters parameters = new PROC_UpdateFields.DTO_Parameters();
		parameters.objectName = UTIL_SObjectDescribe.getObjectNameFromType(ApiCall__c.SObjectType);
		parameters.searchConditions = buildBlankIndexFieldCondition(serviceName);

		PROC_UpdateFields.DTO_Field fieldUpdate = new PROC_UpdateFields.DTO_Field();
		fieldUpdate.name = UTIL_SObjectDescribe.getCachedFieldName(ApiCall__c.TriggeringRecordIndex__c);
		fieldUpdate.value = UTIL_SObjectDescribe.getCachedFieldName(ApiCall__c.TriggeringRecordId__c);
		fieldUpdate.updateMethod = PROC_UpdateFields.FieldUpdateMethod.COPY_FROM_FIELD;
		parameters.updateFields.add(fieldUpdate);

		return new PROC_UpdateFields(parameters);
	}

	/**
	 * @description Asserts that one fill run has ended: its job ended without errors, each of its rows holds its source
	 * value as written in its Triggering Record Index field, and the release note's search finds no row of the run
	 * still to fill.
	 *
	 * @param jobId The Id of the job that ran the fill.
	 * @param serviceName The service name that marks the rows of the run.
	 * @param apiCalls The rows of the run.
	 */
	private static void assertRunEnded(Id jobId, String serviceName, List<SObject> apiCalls)
	{
		AsyncApexJob job = findJob(jobId);
		Assert.areEqual(JOB_STATUS_COMPLETED, job.Status, 'Expected the job to end');
		Assert.areEqual(0, job.NumberOfErrors, 'Expected the job to end without errors');

		assertEveryIndexFieldEqualsItsSource(apiCalls);

		Assert.areEqual(0, buildIndexFieldCopy(serviceName).buildQueryable().count(), 'Expected no row with a source value and a blank Triggering Record Index to be left');
	}

	/**
	 * @description Asserts that each of the given saved API calls holds its source value, exactly as written, in its
	 * Triggering Record Index field.
	 *
	 * @param apiCalls The saved rows.
	 */
	private static void assertEveryIndexFieldEqualsItsSource(List<SObject> apiCalls)
	{
		List<SObject> savedCalls = readRows(apiCalls);
		Assert.areEqual(apiCalls.size(), savedCalls.size(), 'Expected every test row to be read back');
		for(SObject savedCall : savedCalls)
		{
			String sourceValue = (String)savedCall.get(ApiCall__c.TriggeringRecordId__c);
			Assert.isTrue
					(
							sourceValue.equals(savedCall.get(ApiCall__c.TriggeringRecordIndex__c)),
							'Expected Triggering Record Index to equal the source ' + sourceValue + ', got ' + savedCall.get(ApiCall__c.TriggeringRecordIndex__c)
					);
		}
	}

	/**
	 * @description Reads one job by its Id.
	 *
	 * @param jobId The Id of the job.
	 *
	 * @return The job, with its status and its error count.
	 */
	private static AsyncApexJob findJob(Id jobId)
	{
		return (AsyncApexJob)QRY_Builder.selectFrom(AsyncApexJob.SObjectType)
				.fields(new List<SObjectField> {AsyncApexJob.Status, AsyncApexJob.NumberOfErrors})
				.condition(AsyncApexJob.Id).equals(jobId)
				.getFirst();
	}

	/**
	 * @description Saves one row of the given object with the given value in its source field.
	 *
	 * @param objectType The object to save: an API call or an API issue.
	 * @param sourceValue The value for the Triggering Record ID field, or null.
	 *
	 * @return The saved row.
	 */
	private static SObject insertRow(SObjectType objectType, String sourceValue)
	{
		if(objectType == ApiIssue__c.SObjectType)
		{
			ApiCall__c apiCall = (ApiCall__c)TST_Factory.getApiCallBuilder().build();
			ApiIssue__c apiIssue = TST_Factory.newApiIssue(apiCall, UTIL_Crypto.generateMD5Hash(UTIL_Random.randomName()));
			apiIssue.TriggeringRecordId__c = sourceValue;
			return TST_Builder.of(ApiIssue__c.SObjectType).withOverrides(apiIssue.getPopulatedFieldsAsMap()).build();
		}
		return TST_Factory.getApiCallBuilder().withOverride(ApiCall__c.TriggeringRecordId__c, sourceValue).build();
	}

	/**
	 * @description Saves the given row again with a new value in its source field, and nothing else changed.
	 *
	 * @param row The saved row.
	 * @param sourceValue The new value for the Triggering Record ID field, or null.
	 */
	private static void updateSource(SObject row, String sourceValue)
	{
		SObject change = row.getSObjectType().newSObject(row.Id);
		change.put(getSourceField(row.getSObjectType()), sourceValue);
		saveInSystemMode(change);
	}

	/**
	 * @description Saves the given row again with a new value in its Triggering Record Index field only, leaving the
	 * source alone.
	 *
	 * @param row The saved row.
	 * @param indexValue The value to write into the Triggering Record Index field.
	 */
	private static void updateIndexField(SObject row, String indexValue)
	{
		SObject change = row.getSObjectType().newSObject(row.Id);
		change.put(getIndexField(row.getSObjectType()), indexValue);
		saveInSystemMode(change);
	}

	/**
	 * @description Updates the given row in system mode, so field access cannot stop the save.
	 *
	 * @param change The row with the Id and the fields to update.
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	private static void saveInSystemMode(SObject change)
	{
		DML_Builder.newTransaction().withSystemMode().doUpdate(change).execute();
	}

	/**
	 * @description Reads the source and Triggering Record Index fields of the given saved rows of one object, in system mode.
	 *
	 * @param rows The saved rows, all of the same object.
	 *
	 * @return The rows as they are stored.
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	private static List<SObject> readRows(List<SObject> rows)
	{
		SObjectType objectType = rows[0].getSObjectType();
		return QRY_Builder.selectFrom(objectType)
				.fields(new List<SObjectField> {getSourceField(objectType), getIndexField(objectType)})
				.condition(getIdField(objectType)).isIn(rows)
				.withSystemMode()
				.toList();
	}

	/**
	 * @description Asserts that the stored row has the expected value in both its source field and its Triggering
	 * Record Index field. Text is compared with upper and lower case kept apart.
	 *
	 * @param row The saved row.
	 * @param expectedValue The value both fields must hold, or null when both must be blank.
	 */
	private static void assertIndexFieldEquals(SObject row, String expectedValue)
	{
		SObject savedRow = readRows(new List<SObject> {row})[0];
		String sourceValue = (String)savedRow.get(getSourceField(row.getSObjectType()));
		String indexValue = (String)savedRow.get(getIndexField(row.getSObjectType()));
		if(expectedValue == null)
		{
			Assert.isNull(sourceValue, 'Expected the source to be blank');
			Assert.isNull(indexValue, 'Expected Triggering Record Index to be blank, got ' + indexValue);
			return;
		}
		Assert.isTrue(expectedValue.equals(sourceValue), 'Expected the source to be ' + expectedValue + ', got ' + sourceValue);
		Assert.isTrue(expectedValue.equals(indexValue), 'Expected Triggering Record Index to be ' + expectedValue + ', got ' + indexValue);
	}

	/**
	 * @description Gives the Triggering Record ID field of the given object.
	 *
	 * @param objectType An API call or an API issue.
	 *
	 * @return The source field.
	 */
	private static SObjectField getSourceField(SObjectType objectType)
	{
		return objectType == ApiIssue__c.SObjectType ? ApiIssue__c.TriggeringRecordId__c : ApiCall__c.TriggeringRecordId__c;
	}

	/**
	 * @description Gives the Triggering Record Index field of the given object.
	 *
	 * @param objectType An API call or an API issue.
	 *
	 * @return The Triggering Record Index field.
	 */
	private static SObjectField getIndexField(SObjectType objectType)
	{
		return objectType == ApiIssue__c.SObjectType ? ApiIssue__c.TriggeringRecordIndex__c : ApiCall__c.TriggeringRecordIndex__c;
	}

	/**
	 * @description Gives the Id field of the given object.
	 *
	 * @param objectType An API call or an API issue.
	 *
	 * @return The Id field.
	 */
	private static SObjectField getIdField(SObjectType objectType)
	{
		return objectType == ApiIssue__c.SObjectType ? ApiIssue__c.Id : ApiCall__c.Id;
	}
}
