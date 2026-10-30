// SPDX-License-Identifier: Apache-2.0
/**
 * @description Subscriber-side proof that the global members added in 1.8 can be reached and used from a class outside
 * the package. A member that compiles inside the package can still be hidden from, or unusable by, a subscriber class;
 * these tests call each one from here and check what it does through the real call path.
 *
 * Covered: a selector's cacheScope() and cacheTimeToLiveSeconds() overrides, a query's withoutCache() and
 * withCache(scope, time), TST_Mock.registerNext in both forms, TST_Factory.insertUser and insertUsers in all four forms,
 * DML_Builder.expectRefusal and withRetryOnLock() without a count, LOG_Builder.rootCorrelationId, UTIL_String.joinSorted,
 * the five UTIL_Limits cursor checks, an outbound handler's getRetryableStatusCodes() override, and the flowName field of
 * the Log Flow Event action.
 *
 * The last test reads a record that record sharing hides from the running user, in the three ways the conventions
 * guide lists: system mode alone keeps the record sharing of the calling class, so it finds nothing; withoutSecurity()
 * turns off object access checks and record sharing in one call; and system mode with bypassSharing() does the same in
 * two calls.
 *
 * @see kern.SEL_Base
 * @see kern.QRY_Builder
 * @see kern.TST_Mock
 * @see kern.TST_Factory
 * @see kern.DML_Builder
 * @see kern.LOG_Builder
 * @see kern.UTIL_String
 * @see kern.UTIL_Limits
 * @see kern.API_Outbound
 * @see kern.FLOW_LoggerLog
 *
 * @author your.name@company.com
 *
 * @group Testing
 *
 * @date October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=false)
private class SubscriberApi18Surface_TEST
{
	/**
	 * @description How long the caching selector says its rows may be kept in Platform Cache; ignored for rows kept in
	 * memory for the transaction.
	 */
	private static final Integer CACHE_TIME_TO_LIVE_SECONDS = 300;

	/**
	 * @description How many records the cache tests read.
	 */
	private static final Integer RECORD_COUNT = 3;

	/**
	 * @description The profile of every user a test runs as.
	 */
	private static final String PROFILE_STANDARD_USER = 'Standard User';

	/**
	 * @description The profile of the users a test saves but never runs as. Its licence has far more free seats in a
	 * scratch org than the Salesforce licence of the Standard User profile.
	 */
	private static final String PROFILE_CHATTER_FREE_USER = 'Chatter Free User';

	/**
	 * @description Company name of the user the user-insert test creates with a name, by which it finds the user again.
	 */
	private static final String NAMED_USER_COMPANY = 'SubscriberApi18Surface_TEST-named';

	/**
	 * @description HTTP status code an external system answers with when the request clashes with the current state of
	 * the record (409). It is not in the framework's default retryable set.
	 */
	private static final Integer HTTP_CONFLICT = 409;

	/**
	 * @description The body every mock answers with.
	 */
	private static final String EMPTY_BODY = '{}';

	/**
	 * @description Retry budget the outbound tests leave, so a refusal comes from the framework, never from an exhausted
	 * budget.
	 */
	private static final Integer RETRY_BUDGET = 3;

	/**
	 * @description The retry wait, in seconds.
	 */
	private static final Integer RETRY_BACKOFF_SECONDS = 30;

	/**
	 * @description The status of an ApiCall record that waits for its next attempt.
	 */
	private static final String STATUS_RETRY = 'Retry';

	/**
	 * @description The status of an ApiCall record that ended in failure.
	 */
	private static final String STATUS_FAILED = 'Failed';

	/**
	 * @description The name of the Flow the flow log test files its entry under.
	 */
	private static final String FLOW_NAME = 'Subscriber_Api18_Surface_Flow';

	/**
	 * @description The step of the Flow the flow log test names.
	 */
	private static final String FLOW_STEP = 'Check_Order';

	/**
	 * @description A selector that overrides cacheScope() and cacheTimeToLiveSeconds() keeps its rows for the transaction:
	 * a second read of the same rows costs no query. A read through the same selector with withoutCache() goes to the
	 * database and costs one query.
	 */
	@IsTest
	private static void shouldServeTheSecondSelectorReadFromTheTransactionCache()
	{
		List<kern__Foobar__c> seeded = insertFoobars();

		Test.startTest();
		List<kern__Foobar__c> firstRead = (List<kern__Foobar__c>)new SubscriberCachingSelector().toList();
		Integer queriesAfterFirstRead = kern.UTIL_Limits.soqlQueries().used();
		List<kern__Foobar__c> secondRead = (List<kern__Foobar__c>)new SubscriberCachingSelector().toList();
		Integer queriesAfterSecondRead = kern.UTIL_Limits.soqlQueries().used();
		List<kern__Foobar__c> uncachedRead = (List<kern__Foobar__c>)new SubscriberCachingSelector().query.withoutCache().toList();
		Integer queriesAfterUncachedRead = kern.UTIL_Limits.soqlQueries().used();
		Test.stopTest();

		Assert.areEqual(seeded.size(), firstRead.size(), 'Expected the first read to find every seeded record');
		Assert.areEqual(firstRead, secondRead, 'Expected the second read to return the same rows');
		Assert.areEqual(queriesAfterFirstRead, queriesAfterSecondRead, 'Expected the second read to be served from the transaction cache');
		Assert.areEqual(seeded.size(), uncachedRead.size(), 'Expected the uncached read to find every seeded record');
		Assert.areEqual(queriesAfterSecondRead + 1, queriesAfterUncachedRead, 'Expected withoutCache() to send exactly one query to the database');
	}

	/**
	 * @description A one-off query that asks for withCache(IN_TRANSACTION, null) costs one query the first time and none
	 * the second.
	 */
	@IsTest
	private static void shouldServeARepeatedOneOffQueryFromTheTransactionCache()
	{
		insertFoobars();

		Test.startTest();
		Integer queriesBefore = kern.UTIL_Limits.soqlQueries().used();
		List<kern__Foobar__c> firstRead = readFoobarsWithTransactionCache();
		Integer queriesAfterFirstRead = kern.UTIL_Limits.soqlQueries().used();
		List<kern__Foobar__c> secondRead = readFoobarsWithTransactionCache();
		Integer queriesAfterSecondRead = kern.UTIL_Limits.soqlQueries().used();
		Test.stopTest();

		Assert.areEqual(RECORD_COUNT, firstRead.size(), 'Expected the first read to find every seeded record');
		Assert.areEqual(firstRead, secondRead, 'Expected the second read to return the same rows');
		Assert.isTrue(queriesAfterFirstRead > queriesBefore, 'Expected the first read to reach the database');
		Assert.areEqual(queriesAfterFirstRead, queriesAfterSecondRead, 'Expected the second read to be served from the transaction cache');
	}

	/**
	 * @description Answers queued with registerNext are used once each, in the order they were added: the first read
	 * finds nothing, the second finds the queued record, and the third reads the database again.
	 */
	@IsTest
	private static void shouldAnswerQueuedReadsInOrderThenReadTheDatabase()
	{
		kern__Foobar__c stored = (kern__Foobar__c)kern.TST_Builder.of(kern__Foobar__c.SObjectType).withOverride(kern__Foobar__c.Name, kern.UTIL_Random.randomName()).build();
		kern__Foobar__c queued = (kern__Foobar__c)kern.TST_Builder.of(kern__Foobar__c.SObjectType)
				.withOverride(kern__Foobar__c.Name, kern.UTIL_Random.randomName())
				.withoutInsertion(true)
				.build();
		kern.TST_Mock.registerNext(kern__Foobar__c.SObjectType, new List<SObject>());
		kern.TST_Mock.registerNext(kern__Foobar__c.SObjectType, queued);

		Test.startTest();
		List<kern__Foobar__c> firstRead = readFoobars();
		List<kern__Foobar__c> secondRead = readFoobars();
		List<kern__Foobar__c> thirdRead = readFoobars();
		Test.stopTest();

		Assert.isTrue(firstRead.isEmpty(), 'Expected the first queued answer, an empty list, to find nothing, got ' + firstRead.size());
		Assert.areEqual(1, secondRead.size(), 'Expected the second queued answer to return one record, got ' + secondRead.size());
		Assert.areEqual(queued.Id, secondRead[0].Id, 'Expected the second read to return the queued record');
		Assert.areEqual(1, thirdRead.size(), 'Expected the third read to reach the database once the queue was used up, got ' + thirdRead.size());
		Assert.areEqual(stored.Id, thirdRead[0].Id, 'Expected the third read to return the stored record');
	}

	/**
	 * @description The four user-insert methods save their users inside their own guard, so the test saves ordinary
	 * records before and after them in the same transaction without the platform's mixed-save error, and runs as one of
	 * the users afterwards. Only that user is a Standard User; the other three are Chatter Free users, so the test needs
	 * one Salesforce licence seat.
	 */
	@IsTest
	private static void shouldSaveOrdinaryRecordsAroundUserInserts()
	{
		kern__Foobar__c savedBefore = (kern__Foobar__c)kern.TST_Builder.of(kern__Foobar__c.SObjectType).build();

		Test.startTest();
		User singleUser = kern.TST_Factory.insertUser(PROFILE_STANDARD_USER);
		User namedUser = kern.TST_Factory.insertUser(PROFILE_CHATTER_FREE_USER, NAMED_USER_COMPANY);
		List<User> countedUsers = kern.TST_Factory.insertUsers(PROFILE_CHATTER_FREE_USER, 1);
		List<User> shapedUsers = kern.TST_Factory.insertUsers(new List<User> {kern.TST_Factory.newUser(PROFILE_CHATTER_FREE_USER)});
		kern__Foobar__c savedAfter = (kern__Foobar__c)kern.TST_Builder.of(kern__Foobar__c.SObjectType).build();
		Test.stopTest();

		Assert.isNotNull(savedBefore.Id, 'Expected the record saved before the users to have an id');
		Assert.isNotNull(savedAfter.Id, 'Expected the record saved after the users to have an id');
		Assert.isNotNull(singleUser.Id, 'Expected insertUser(profile) to save the user');
		Assert.areEqual(namedUser.Id, new kern.SEL_User().findByCompanyName(NAMED_USER_COMPANY).Id, 'Expected the named user to be found by its company');
		Assert.isNotNull(countedUsers[0].Id, 'Expected insertUsers(profile, count) to save the user');
		Assert.isNotNull(shapedUsers[0].Id, 'Expected insertUsers(users) to save the user it was given');
		System.runAs(singleUser)
		{
			Assert.areEqual(singleUser.Id, UserInfo.getUserId(), 'Expected the test to run as the saved user');
		}
	}

	/**
	 * @description A partial save that declares DUPLICATE_VALUE as an expected refusal: the duplicate row still fails and
	 * counts as a failure, the other row is saved, and the refusal is logged at WARN instead of ERROR. The entries are
	 * found by a correlation id the test starts just before the save, never by the message: in a subscriber org the
	 * platform's duplicate-value wording withholds the packaged field's name and the record id.
	 */
	@IsTest
	private static void shouldLogADeclaredRefusalAtWarnInstead()
	{
		String uniqueKey = kern.UTIL_Random.randomName();
		kern.TST_Builder.of(kern__LoginFrequency__c.SObjectType).withOverride(kern__LoginFrequency__c.kern__CompositeKey__c, uniqueKey).build();
		List<kern__LoginFrequency__c> pair = (List<kern__LoginFrequency__c>)kern.TST_Builder.of(kern__LoginFrequency__c.SObjectType)
				.withCount(2)
				.withCycle(kern__LoginFrequency__c.kern__CompositeKey__c, new List<Object> {uniqueKey, kern.UTIL_Random.randomName()})
				.withoutInsertion()
				.buildList();
		kern.LOG_Builder.ignoreTestMode = true;
		String correlationId = kern.LOG_Builder.startCorrelation();

		Test.startTest();
		kern.DML_Builder.TransactionResult result = kern.DML_Builder.newTransaction()
				.doInsert(pair)
				.allowPartial()
				.expectRefusal(StatusCode.DUPLICATE_VALUE)
				.execute();
		Test.stopTest();

		Assert.isFalse(result.isSuccess(), 'Expected the save to report the refused row');
		Assert.areEqual(1, result.getSuccessCount(), 'Expected the row with a fresh key to be saved');
		Assert.areEqual(1, result.getFailureCount(), 'Expected the duplicate row to count as a failure');
		Assert.areEqual(StatusCode.DUPLICATE_VALUE, result.getErrors()[0].getStatusCode(), 'Expected the refusal to be a duplicate value');
		Integer warningCount = countEntriesAtLevel(findEntriesByCorrelationId(correlationId), LoggingLevel.WARN.name());
		Assert.areEqual(1, warningCount, 'Expected the declared refusal to be logged once at WARN under the correlation id, got ' + warningCount);
		Integer errorCount = countEntriesAtLevel(findEntriesByCorrelationId(correlationId), LoggingLevel.ERROR.name());
		Assert.areEqual(0, errorCount, 'Expected no ERROR entry for a declared refusal, got ' + errorCount);
	}

	/**
	 * @description Outside a background chain the root correlation id is the first correlation id the transaction
	 * started; a later change of the correlation id keeps the root, and a log entry carries both.
	 */
	@IsTest
	private static void shouldKeepTheRootCorrelationIdWhenTheCorrelationIdMoves()
	{
		kern.LOG_Builder.ignoreTestMode = true;

		Test.startTest();
		String startedId = kern.LOG_Builder.startCorrelation();
		String rootWhileUnchanged = kern.LOG_Builder.rootCorrelationId;
		String laterId = kern.UTIL_Random.randomUUID();
		kern.LOG_Builder.setCorrelationId(laterId);
		kern.LOG_Builder.build().warn(kern.UTIL_Random.randomName()).emit();
		Test.stopTest();

		Assert.areEqual(startedId, rootWhileUnchanged, 'Expected the root to equal the correlation id the transaction started');
		Assert.areEqual(laterId, kern.LOG_Builder.correlationId, 'Expected the correlation id to move to the later id');
		Assert.areEqual(startedId, kern.LOG_Builder.rootCorrelationId, 'Expected the root to stay when the correlation id moves');
		List<kern__LogEntry__c> entries = findEntriesByCorrelationId(laterId);
		Assert.areEqual(1, entries.size(), 'Expected one entry under the later correlation id, got ' + entries.size());
		Assert.areEqual(startedId, entries[0].kern__RootCorrelationId__c, 'Expected the entry to carry the root correlation id');
	}

	/**
	 * @description joinSorted joins the members of a set in ascending order, so the text reads the same on every run, and
	 * answers null for a null set.
	 */
	@IsTest
	private static void shouldJoinASetInAscendingOrder()
	{
		Test.startTest();
		String joined = kern.UTIL_String.joinSorted(new Set<String> {'pear', 'apple', 'fig'}, ', ');
		String joinedNothing = kern.UTIL_String.joinSorted(null, ', ');
		Test.stopTest();

		Assert.areEqual('apple, fig, pear', joined, 'Expected the members in ascending order');
		Assert.isNull(joinedNothing, 'Expected null for a null set');
	}

	/**
	 * @description The five cursor checks each answer with a label and a budget that is not negative, and the check for
	 * fetch calls counts the one fetch the test makes on a cursor the query builder opened.
	 */
	@IsTest
	private static void shouldReportTheApexCursorLimits()
	{
		insertFoobars();

		Test.startTest();
		Integer fetchCallsBefore = kern.UTIL_Limits.fetchCallsOnApexCursor().used();
		Database.Cursor cursor = kern.QRY_Builder.selectFrom(kern__Foobar__c.SObjectType).toCursor();
		List<SObject> fetched = cursor.fetch(0, 1);
		Integer fetchCallsAfter = kern.UTIL_Limits.fetchCallsOnApexCursor().used();
		List<kern.UTIL_Limits.LimitCheck> checks = new List<kern.UTIL_Limits.LimitCheck>
		{
				kern.UTIL_Limits.apexCursors(),
				kern.UTIL_Limits.apexCursorRows(),
				kern.UTIL_Limits.apexPaginationCursors(),
				kern.UTIL_Limits.apexPaginationCursorRows(),
				kern.UTIL_Limits.fetchCallsOnApexCursor()
		};
		Test.stopTest();

		Assert.areEqual(1, fetched.size(), 'Expected the cursor to fetch one record');
		Assert.areEqual(fetchCallsBefore + 1, fetchCallsAfter, 'Expected the fetch call check to count the one fetch');
		for(kern.UTIL_Limits.LimitCheck check : checks)
		{
			Assert.isTrue(String.isNotBlank(check.label), 'Expected every cursor check to carry a label');
			Assert.isTrue(check.remaining() >= 0, 'Expected ' + check.label + ' to have a budget that is not negative, got ' + check.remaining());
		}
	}

	/**
	 * @description A POST handler that adds 409 to its retryable set through getRetryableStatusCodes(): a 409 answer
	 * waits for a scheduled retry, Retry with a time, even though a POST without a key is not safe to repeat, because a
	 * code the handler adds is its own choice.
	 */
	@IsTest
	private static void shouldScheduleARetryForAStatusTheHandlerAdds()
	{
		String serviceName = SurfaceConflictRetrying.class.getName();
		registerRetryingSetting(serviceName);
		kern.API_MockFactory.forService(serviceName).body(EMPTY_BODY).statusCode(HTTP_CONFLICT).register();

		Test.startTest();
		kern.API_Dispatcher.execute(new List<kern__ApiCall__c> {kern.TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId())});
		Test.stopTest();

		List<kern__ApiCall__c> rows = new kern.SEL_ApiCall().findByServiceName(serviceName);
		Assert.areEqual(1, rows.size(), 'Expected one call stored for ' + serviceName + ', got ' + rows.size());
		kern__ApiCall__c row = rows[0];
		Assert.areEqual(STATUS_RETRY, row.kern__Status__c, 'Expected a 409 the handler added to wait for a retry, got ' + row.kern__Status__c);
		Assert.isNotNull(row.kern__NextRetry__c, 'Expected a Retry row to carry a time');
	}

	/**
	 * @description The same POST handler without the override: a 409 is not in the default retryable set, so the call
	 * ends Failed with no retry time.
	 */
	@IsTest
	private static void shouldFailAStatusOutsideTheDefaultRetryableSet()
	{
		String serviceName = SurfacePost.class.getName();
		registerRetryingSetting(serviceName);
		kern.API_MockFactory.forService(serviceName).body(EMPTY_BODY).statusCode(HTTP_CONFLICT).register();

		Test.startTest();
		kern.API_Dispatcher.execute(new List<kern__ApiCall__c> {kern.TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId())});
		Test.stopTest();

		List<kern__ApiCall__c> rows = new kern.SEL_ApiCall().findByServiceName(serviceName);
		Assert.areEqual(1, rows.size(), 'Expected one call stored for ' + serviceName + ', got ' + rows.size());
		kern__ApiCall__c row = rows[0];
		Assert.areEqual(STATUS_FAILED, row.kern__Status__c, 'Expected a 409 outside the default set to end Failed, got ' + row.kern__Status__c);
		Assert.isNull(row.kern__NextRetry__c, 'Expected no retry time on a Failed row');
	}

	/**
	 * @description withRetryOnLock() with no count saves a record that no other transaction holds at the first attempt.
	 */
	@IsTest
	private static void shouldSaveWithTheDefaultRowLockRetry()
	{
		kern__Foobar__c record = (kern__Foobar__c)kern.TST_Builder.of(kern__Foobar__c.SObjectType)
				.withOverride(kern__Foobar__c.Name, kern.UTIL_Random.randomName())
				.withoutInsertion()
				.build();

		Test.startTest();
		kern.DML_Builder.TransactionResult result = kern.DML_Builder.newTransaction().doInsert(record).withRetryOnLock().execute();
		Test.stopTest();

		Assert.isTrue(result.isSuccess(), 'Expected the save to succeed, got ' + result.getErrors());
		Assert.areEqual(1, result.getInsertedIds().size(), 'Expected one inserted id');
		Integer savedCount = kern.QRY_Builder.selectFrom(kern__Foobar__c.SObjectType).condition(kern__Foobar__c.Name).equals(record.Name).count();
		Assert.areEqual(1, savedCount, 'Expected the record to be saved once, got ' + savedCount);
	}

	/**
	 * @description The Log Flow Event action, given a Flow name, files its entry under that Flow: the entry's source is
	 * the Flow name.
	 */
	@IsTest
	private static void shouldFileAFlowLogEntryUnderTheFlowName()
	{
		kern.LOG_Builder.ignoreTestMode = true;
		kern.FLOW_LoggerLog.DTO_Request request = new kern.FLOW_LoggerLog.DTO_Request();
		request.correlationId = kern.UTIL_Random.randomUUID();
		request.message = kern.UTIL_Random.randomName();
		request.logLevel = LoggingLevel.INFO.name();
		request.flowStep = FLOW_STEP;
		request.flowName = FLOW_NAME;

		Test.startTest();
		kern.FLOW_LoggerLog.execute(new List<kern.FLOW_LoggerLog.DTO_Request> {request});
		Test.stopTest();

		List<kern__LogEntry__c> entries = findEntriesByCorrelationId(request.correlationId);
		Assert.areEqual(1, entries.size(), 'Expected one entry for the Flow, got ' + entries.size());
		Assert.areEqual(FLOW_NAME, entries[0].kern__Source__c, 'Expected the entry to be filed under the Flow name');
	}

	/**
	 * @description A Standard User with no permission set reads an API call that an administrator owns. The object's
	 * default is Private and the reads run in a class declared with sharing. withSystemMode() turns off object and field
	 * access checks but keeps the record sharing of that class, so it finds nothing. withoutSecurity() turns off both
	 * in one call, and withSystemMode() with bypassSharing() turns off both in two calls, so each finds the record.
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	@IsTest
	private static void shouldReadAHiddenRecordOnlyWhenRecordSharingIsBypassed()
	{
		User reader = kern.TST_Factory.insertUser(PROFILE_STANDARD_USER);
		kern__ApiCall__c hiddenCall = kern.TST_Factory.newInboundApiCall(kern.UTIL_Random.randomName());
		kern.DML_Builder.newTransaction().doInsert(hiddenCall).execute();

		List<kern__ApiCall__c> systemModeRows;
		List<kern__ApiCall__c> withoutSecurityRows;
		List<kern__ApiCall__c> bypassedRows;
		System.runAs(reader)
		{
			Test.startTest();
			SharingRespectingReader sharingReader = new SharingRespectingReader();
			systemModeRows = sharingReader.readInSystemMode();
			withoutSecurityRows = sharingReader.readWithoutSecurity();
			bypassedRows = sharingReader.readInSystemModeBypassingSharing();
			Test.stopTest();
		}

		Assert.isTrue(systemModeRows.isEmpty(), 'Expected system mode alone to keep record sharing and find nothing, got ' + systemModeRows.size());
		Assert.areEqual(1, withoutSecurityRows.size(), 'Expected withoutSecurity() to find the hidden record, got ' + withoutSecurityRows.size());
		Assert.areEqual(hiddenCall.Id, withoutSecurityRows[0].Id, 'Expected withoutSecurity() to return the hidden record');
		Assert.areEqual(1, bypassedRows.size(), 'Expected system mode with bypassSharing() to find the hidden record, got ' + bypassedRows.size());
		Assert.areEqual(hiddenCall.Id, bypassedRows[0].Id, 'Expected system mode with bypassSharing() to return the hidden record');
	}

	/**
	 * @description Inserts the records the cache and cursor tests read.
	 *
	 * @return The saved records.
	 */
	private static List<kern__Foobar__c> insertFoobars()
	{
		return (List<kern__Foobar__c>)kern.TST_Builder.of(kern__Foobar__c.SObjectType).withCount(RECORD_COUNT).buildList();
	}

	/**
	 * @description Reads every Foobar record with a one-off query that asks for the transaction cache.
	 *
	 * @return The records.
	 */
	private static List<kern__Foobar__c> readFoobarsWithTransactionCache()
	{
		return (List<kern__Foobar__c>)kern.QRY_Builder.selectFrom(kern__Foobar__c.SObjectType)
				.fields(new List<SObjectField> {kern__Foobar__c.Name})
				.withCache(kern.UTIL_Cache.Scope.IN_TRANSACTION, null)
				.toList();
	}

	/**
	 * @description Reads every Foobar record with a one-off query and no cache.
	 *
	 * @return The records.
	 */
	private static List<kern__Foobar__c> readFoobars()
	{
		return (List<kern__Foobar__c>)kern.QRY_Builder.selectFrom(kern__Foobar__c.SObjectType).fields(new List<SObjectField> {kern__Foobar__c.Name}).toList();
	}

	/**
	 * @description Counts the saved log entries at the given level whose message names the unique field. The message is
	 * a long text field, which a query cannot filter on, so the level is filtered in the query and the message here.
	 * The entry carries the platform's own error message, and the platform's wording for a duplicate value names the
	 * field ("duplicate value found: kern__CompositeKey__c duplicates value on record with id: ..."); the framework adds
	 * no field name of its own.
	 *
	 * @param logLevel The level to count, as the log entry stores it.
	 *
	 * @return How many entries at that level name the field.
	 */
	private static Integer countEntriesAtLevel(List<kern__LogEntry__c> entries, String logLevel)
	{
		Integer matchingCount = 0;
		for(kern__LogEntry__c entry : entries)
		{
			if(entry.kern__LogLevel__c == logLevel)
			{
				matchingCount++;
			}
		}
		return matchingCount;
	}

	/**
	 * @description Reads the saved log entries that carry the given correlation id, with their level, root correlation id
	 * and source.
	 *
	 * @param correlationId The correlation id to look for.
	 *
	 * @return The entries.
	 */
	private static List<kern__LogEntry__c> findEntriesByCorrelationId(String correlationId)
	{
		return (List<kern__LogEntry__c>)kern.QRY_Builder.selectFrom(kern__LogEntry__c.SObjectType)
				.fields(new List<SObjectField> {kern__LogEntry__c.kern__LogLevel__c, kern__LogEntry__c.kern__RootCorrelationId__c, kern__LogEntry__c.kern__Source__c})
				.condition(kern__LogEntry__c.kern__CorrelationId__c).equals(correlationId)
				.toList();
	}

	/**
	 * @description Registers the mocked setting the outbound handlers read: retries on, a wait, issues logged.
	 *
	 * @param serviceName The handler class.
	 */
	private static void registerRetryingSetting(String serviceName)
	{
		kern.TST_Factory.newOutboundApiSetting(serviceName, new Map<SObjectField, Object>
		{
				kern__ApiSetting__mdt.kern__MaxRetryCount__c => RETRY_BUDGET,
				kern__ApiSetting__mdt.kern__RetryBackoffSeconds__c => RETRY_BACKOFF_SECONDS,
				kern__ApiSetting__mdt.kern__LogIssues__c => true
		});
	}

	/**
	 * @description A selector that keeps every read for the rest of the transaction.
	 */
	public with sharing class SubscriberCachingSelector extends kern.SEL_Base
	{
		/**
		 * @description Selects Foobar records.
		 */
		public SubscriberCachingSelector()
		{
			super(kern__Foobar__c.SObjectType);
		}

		/**
		 * @description The fields every read returns.
		 *
		 * @return The Name field.
		 */
		public override List<SObjectField> getFields()
		{
			return new List<SObjectField> {kern__Foobar__c.Name};
		}

		/**
		 * @description Keeps every read in memory for the current transaction.
		 *
		 * @return IN_TRANSACTION.
		 */
		public override kern.UTIL_Cache.Scope cacheScope()
		{
			return kern.UTIL_Cache.Scope.IN_TRANSACTION;
		}

		/**
		 * @description How long a read may be kept in Platform Cache; a read kept in memory ignores it.
		 *
		 * @return The time in seconds.
		 */
		public override Integer cacheTimeToLiveSeconds()
		{
			return CACHE_TIME_TO_LIVE_SECONDS;
		}
	}

	/**
	 * @description Reads API calls in the three ways the conventions guide lists. It is declared with sharing, so a read
	 * that keeps the record sharing of the calling class applies the running user's sharing.
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	private with sharing class SharingRespectingReader
	{
		/**
		 * @description Reads in system mode: no object or field access checks, record sharing of this class kept.
		 *
		 * @return The rows the running user's sharing lets through.
		 */
		public List<kern__ApiCall__c> readInSystemMode()
		{
			return (List<kern__ApiCall__c>)kern.QRY_Builder.selectFrom(kern__ApiCall__c.SObjectType).withSystemMode().toList();
		}

		/**
		 * @description Reads with every check off: no object or field access checks and no record sharing.
		 *
		 * @return Every row.
		 */
		public List<kern__ApiCall__c> readWithoutSecurity()
		{
			return (List<kern__ApiCall__c>)kern.QRY_Builder.selectFrom(kern__ApiCall__c.SObjectType).withoutSecurity().toList();
		}

		/**
		 * @description Reads in system mode and bypasses record sharing: the same as withoutSecurity(), in two calls.
		 *
		 * @return Every row.
		 */
		public List<kern__ApiCall__c> readInSystemModeBypassingSharing()
		{
			return (List<kern__ApiCall__c>)kern.QRY_Builder.selectFrom(kern__ApiCall__c.SObjectType).withSystemMode().bypassSharing().toList();
		}
	}

	/**
	 * @description The payload both directions use; any JSON-capable DTO satisfies the handler.
	 */
	@JsonAccess(serializable='always' deserializable='always')
	public class SurfacePayload extends kern.DTO_JsonBase
	{
	}

	/**
	 * @description A POST handler with no idempotency key, in-memory payloads and no triggering record.
	 */
	public virtual inherited sharing class SurfacePost extends kern.API_Outbound
	{
		/**
		 * @description Sets the payloads and clears the triggering-record requirement.
		 */
		public override void configure()
		{
			super.configure();
			requestPayload = new SurfacePayload();
			responsePayload = new SurfacePayload();
			requiresTriggeringRecord = false;
		}

		/**
		 * @description A POST, which is not safe to repeat without a key.
		 *
		 * @return POST.
		 */
		public override kern.API_Base.HttpMethod getHttpMethod()
		{
			return kern.API_Base.HttpMethod.POST;
		}
	}

	/**
	 * @description The same POST handler, adding 409 to the statuses a retry may follow.
	 */
	public inherited sharing class SurfaceConflictRetrying extends SurfacePost
	{
		/**
		 * @description The default retryable statuses with 409 added.
		 *
		 * @return The statuses a retry may follow.
		 */
		public override Set<Integer> getRetryableStatusCodes()
		{
			Set<Integer> statusCodes = super.getRetryableStatusCodes();
			statusCodes.add(HTTP_CONFLICT);
			return statusCodes;
		}
	}
}
