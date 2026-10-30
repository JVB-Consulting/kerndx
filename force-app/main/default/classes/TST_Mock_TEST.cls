// SPDX-License-Identifier: Apache-2.0
/**
 * @description Unit tests for TST_Mock.
 *
 * @see TST_Mock
 *
 * @author Jason van Beukering
 *
 * @group Testing
 *
 * @date February 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CyclomaticComplexity')
@IsTest(seeAllData=false isParallel=true)
private class TST_Mock_TEST
{
	/**
	 * @description Message on the exception the precedence test registers, so the failure asserted is this test's own.
	 */
	private static final String REGISTERED_FAILURE = 'Registered before the queued answer';

	/**
	 * @description Text every refusal of a null next answer must carry, pointing the caller at the empty list.
	 */
	private static final String EMPTY_LIST_HINT = 'empty list';

	/**
	 * @description Text the refusal of a record of another type must carry.
	 */
	private static final String TYPE_MISMATCH_HINT = 'type mismatch';

	/**
	 * @description Alias the aggregate tests give the count, and the key of the registered rows that holds it.
	 */
	private static final String TOTAL_ALIAS = 'total';

	/**
	 * @description Alias the aggregate tests give the sum, and the key of the registered row that holds it.
	 */
	private static final String SUM_ALIAS = 'sum';

	/**
	 * @description Total held by the first registered aggregate row, or by the first next answer.
	 */
	private static final Integer FIRST_GROUP_TOTAL = 3;

	/**
	 * @description Total held by the second registered aggregate row, or by the second next answer.
	 */
	private static final Integer SECOND_GROUP_TOTAL = 2;

	/**
	 * @description Total held by the rows registered with registerAggregateRows. It differs from every real count in
	 * these tests, so a registered row that should have been cleared is told apart from the database answer.
	 */
	private static final Integer REGISTERED_TOTAL = 7;

	/**
	 * @description Sum held by the one registered row of the getFirstAggregate test.
	 */
	private static final Integer REGISTERED_SUM = 10;

	/**
	 * @description Number of record mocks the count test registers. It differs from the one aggregate row registered
	 * beside them, so a count that read the aggregate rows would show.
	 */
	private static final Integer RECORD_MOCK_COUNT = 2;

	/**
	 * @description Name held by the first registered aggregate row.
	 */
	private static final String FIRST_GROUP_NAME = 'A';

	/**
	 * @description Name held by the second registered aggregate row.
	 */
	private static final String SECOND_GROUP_NAME = 'B';

	/**
	 * @description Tests that registering a single record makes it retrievable.
	 */
	@IsTest
	private static void shouldRegisterSingleRecord()
	{
		Foobar__c mock = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withoutInsertion(true)
				.build();

		TST_Mock.register(Foobar__c.SObjectType, mock);

		List<SObject> result = TST_Mock.get(Foobar__c.SObjectType);

		Assert.areEqual(1, result.size(), 'Should contain one registered record');
		Assert.areEqual(mock.Id, result[0].Id, 'Should contain the registered record');
	}

	/**
	 * @description Tests that registering a list of records makes them all retrievable.
	 */
	@IsTest
	private static void shouldRegisterMultipleRecords()
	{
		List<SObject> mocks = TST_Builder.of(Foobar__c.SObjectType)
				.withCount(3)
				.withoutInsertion(true)
				.buildList();

		TST_Mock.register(Foobar__c.SObjectType, mocks);

		List<SObject> result = TST_Mock.get(Foobar__c.SObjectType);

		Assert.areEqual(3, result.size(), 'Should contain all registered records');
	}

	/**
	 * @description Tests that multiple register calls append to existing mocks.
	 */
	@IsTest
	private static void shouldAppendOnSubsequentRegistrations()
	{
		Foobar__c first = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withoutInsertion(true)
				.build();

		Foobar__c second = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withoutInsertion(true)
				.build();

		TST_Mock.register(Foobar__c.SObjectType, first);
		TST_Mock.register(Foobar__c.SObjectType, second);

		List<SObject> result = TST_Mock.get(Foobar__c.SObjectType);

		Assert.areEqual(2, result.size(), 'Should contain both registered records');
	}

	/**
	 * @description Tests that get returns an empty list for unregistered types.
	 */
	@IsTest
	private static void shouldReturnEmptyListForUnregisteredType()
	{
		List<SObject> result = TST_Mock.get(Account.SObjectType);

		Assert.isTrue(result.isEmpty(), 'Should return empty list for unregistered type');
	}

	/**
	 * @description Tests that clear() removes all registered mocks.
	 */
	@IsTest
	private static void shouldClearAllRegisteredMocks()
	{
		TST_Mock.register(Foobar__c.SObjectType, TST_Builder.of(Foobar__c.SObjectType)
				.withoutInsertion(true)
				.build());

		TST_Mock.register(Account.SObjectType, TST_Builder.of(Account.SObjectType)
				.withoutInsertion(true)
				.build());

		TST_Mock.clear();

		Assert.isTrue(TST_Mock.get(Foobar__c.SObjectType).isEmpty(), 'Foobar mocks should be cleared');
		Assert.isTrue(TST_Mock.get(Account.SObjectType).isEmpty(), 'Account mocks should be cleared');
	}

	/**
	 * @description Tests that clear(SObjectType) only removes mocks for the specified type.
	 */
	@IsTest
	private static void shouldClearMocksForSpecificType()
	{
		TST_Mock.register(Foobar__c.SObjectType, TST_Builder.of(Foobar__c.SObjectType)
				.withoutInsertion(true)
				.build());

		TST_Mock.register(Account.SObjectType, TST_Builder.of(Account.SObjectType)
				.withoutInsertion(true)
				.build());

		TST_Mock.clear(Foobar__c.SObjectType);

		Assert.isTrue(TST_Mock.get(Foobar__c.SObjectType).isEmpty(), 'Foobar mocks should be cleared');
		Assert.areEqual(1, TST_Mock.get(Account.SObjectType).size(), 'Account mocks should remain');
	}

	/**
	 * @description Tests that throwsException(SObjectType, Exception) registers an exception that fires
	 * on a real selector-driven query.
	 */
	@IsTest
	private static void shouldThrowRegisteredExceptionViaThrowsException()
	{
		TST_Mock.throwsException(Foobar__c.SObjectType, new QueryException('Custom failure'));

		try
		{
			QRY_Builder.selectFrom(Foobar__c.SObjectType).toList();
			Assert.fail('Should throw the registered QueryException via TST_Mock.throwsException');
		}
		catch(QueryException error)
		{
			Assert.areEqual('Custom failure', error.getMessage(), 'Should rethrow the exact registered exception');
		}

		TST_Mock.clear();
	}

	/**
	 * @description Tests that throwsException(SObjectType, String) wraps the message in QueryException.
	 */
	@IsTest
	private static void shouldThrowQueryExceptionWithMessageViaStringOverload()
	{
		TST_Mock.throwsException(Foobar__c.SObjectType, 'Message overload failure');

		try
		{
			QRY_Builder.selectFrom(Foobar__c.SObjectType).toList();
			Assert.fail('Should throw a QueryException via the message overload');
		}
		catch(QueryException error)
		{
			Assert.areEqual('Message overload failure', error.getMessage(), 'Should attach the supplied message');
		}

		TST_Mock.clear();
	}

	/**
	 * @description Tests that throwsException(SObjectType) throws a generic QueryException with
	 * an auto-generated message that names the SObjectType.
	 */
	@IsTest
	private static void shouldThrowGenericQueryExceptionViaSingleArgOverload()
	{
		TST_Mock.throwsException(Foobar__c.SObjectType);

		try
		{
			QRY_Builder.selectFrom(Foobar__c.SObjectType).toList();
			Assert.fail('Should throw a generic QueryException via the single-arg overload');
		}
		catch(QueryException error)
		{
			Assert.isTrue
					(
							error.getMessage().contains(String.valueOf(Foobar__c.SObjectType)),
							'Auto-generated message should name the SObjectType'
					);
		}

		TST_Mock.clear();
	}

	/**
	 * @description Tests that TST_Mock.clear() also wipes the QRY_Engine exception registry so a
	 * subsequent query against the previously-throwing type proceeds normally.
	 */
	@IsTest
	private static void shouldClearExceptionsWhenClearCalled()
	{
		TST_Mock.throwsException(Foobar__c.SObjectType, new QueryException('Should clear'));
		Assert.isNotNull(QRY_Engine.getMockException(Foobar__c.SObjectType), 'Exception should be registered');

		TST_Mock.clear();

		Assert.isNull
				(
						QRY_Engine.getMockException(Foobar__c.SObjectType),
						'TST_Mock.clear() should wipe the exception registry'
				);

		List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType).toList();
		Assert.areEqual(0, results.size(), 'Subsequent query should proceed normally after clear');
	}

	/**
	 * @description Tests that TST_Mock.clear(SObjectType) wipes the exception for the specified type
	 * while leaving exceptions for other types in place.
	 */
	@IsTest
	private static void shouldClearExceptionsWhenClearTypeCalled()
	{
		TST_Mock.throwsException(Foobar__c.SObjectType, new QueryException('Foobar failure'));
		TST_Mock.throwsException(Account.SObjectType, new QueryException('Account failure'));

		TST_Mock.clear(Foobar__c.SObjectType);

		Assert.isNull
				(
						QRY_Engine.getMockException(Foobar__c.SObjectType),
						'Foobar exception should be cleared'
				);
		Assert.isNotNull
				(
						QRY_Engine.getMockException(Account.SObjectType),
						'Account exception should remain'
				);

		TST_Mock.clear();
	}

	/**
	 * @description Tests that registered mocks are returned by SEL_* queries via QRY_Builder mock layer.
	 */
	@IsTest
	private static void shouldInterceptSelectorQueries()
	{
		Foobar__c mock = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withoutInsertion(true)
				.build();

		TST_Mock.register(Foobar__c.SObjectType, mock);

		Foobar__c result = (Foobar__c)new SEL_Foobar().findById(mock.Id);

		Assert.areEqual(mock.Id, result.Id, 'Selector should return the mocked record');
	}

	/**
	 * @description Tests that build() creates a mock record with an Id and registers it.
	 */
	@IsTest
	private static void shouldBuildAndRegisterSingleRecord()
	{
		Foobar__c mock = (Foobar__c)TST_Mock.of(Foobar__c.SObjectType).build();

		Assert.isNotNull(mock.Id, 'Mock should have an Id');

		List<SObject> registered = TST_Mock.get(Foobar__c.SObjectType);

		Assert.areEqual(1, registered.size(), 'Should have one registered mock');
		Assert.areEqual(mock.Id, registered[0].Id, 'Registered mock should match built record');
	}

	/**
	 * @description Tests that build() succeeds for an SObject whose creatable-required fields include a
	 * standard Integer-typed field (ApexClass.LengthWithoutComments): the auto-generated default must be
	 * a genuine Integer, because SObject.put rejects a Decimal on standard Integer-typed fields.
	 */
	@IsTest
	private static void shouldBuildMockForSObjectWithStandardIntegerField()
	{
		ApexClass mock = (ApexClass)TST_Mock.of(ApexClass.SObjectType).build();

		Assert.isNotNull(mock.Id, 'Mock should have an Id');
		Assert.isNotNull(mock.LengthWithoutComments, 'The standard Integer-typed field should carry an auto-generated default');
	}

	/**
	 * @description Tests that buildList() creates multiple mock records and registers them.
	 */
	@IsTest
	private static void shouldBuildAndRegisterMultipleRecords()
	{
		List<SObject> mocks = TST_Mock.of(Foobar__c.SObjectType)
				.withCount(3)
				.buildList();

		Assert.areEqual(3, mocks.size(), 'Should build 3 records');

		List<SObject> registered = TST_Mock.get(Foobar__c.SObjectType);

		Assert.areEqual(3, registered.size(), 'Should have 3 registered mocks');
	}

	/**
	 * @description Tests that withOverride applies the field value to the built mock.
	 */
	@IsTest
	private static void shouldApplyFieldOverride()
	{
		Foobar__c mock = (Foobar__c)TST_Mock.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.NumberInteger__c, 42)
				.build();

		Assert.areEqual(42, mock.NumberInteger__c, 'Should apply the field override');
	}

	/**
	 * @description Tests that withOverrides applies multiple field values to the built mock.
	 */
	@IsTest
	private static void shouldApplyMultipleFieldOverrides()
	{
		Foobar__c mock = (Foobar__c)TST_Mock.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.NumberInteger__c, 42)
				.withOverride(Foobar__c.Checkbox__c, true)
				.build();

		Assert.areEqual(42, mock.NumberInteger__c, 'Should apply integer override');
		Assert.isTrue(mock.Checkbox__c, 'Should apply checkbox override');
	}

	/**
	 * @description Tests that withOverrides(Map<SObjectField, Object>) applies all map entries to the built mock.
	 */
	@IsTest
	private static void shouldApplySObjectFieldMapOverrides()
	{
		Foobar__c mock = (Foobar__c)TST_Mock.of(Foobar__c.SObjectType)
				.withOverrides(new Map<SObjectField, Object>
				{
						Foobar__c.NumberInteger__c => 88,
						Foobar__c.Checkbox__c => true
				})
				.build();

		Assert.areEqual(88, mock.NumberInteger__c, 'Should apply integer override from typed-field map');
		Assert.isTrue(mock.Checkbox__c, 'Should apply checkbox override from typed-field map');
	}

	/**
	 * @description Tests that built mocks are intercepted by SEL_* queries.
	 */
	@IsTest
	private static void shouldInterceptSelectorQueriesViaMockBuilder()
	{
		Foobar__c mock = (Foobar__c)TST_Mock.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.NumberInteger__c, 99)
				.build();

		Foobar__c result = (Foobar__c)new SEL_Foobar().findById(mock.Id);

		Assert.areEqual(mock.Id, result.Id, 'Selector should return the mocked record');
	}

	/**
	 * @description Tests that withOverride(String, Object) applies the field value.
	 */
	@IsTest
	private static void shouldApplyStringFieldOverride()
	{
		Foobar__c mock = (Foobar__c)TST_Mock.of(Foobar__c.SObjectType)
				.withOverride(SEL_Foobar.FIELD_INTEGER, 77)
				.build();

		Assert.areEqual(77, mock.NumberInteger__c, 'Should apply the string field override');
	}

	/**
	 * @description Tests that withOverrides(Map<String, Object>) applies multiple field values.
	 */
	@IsTest
	private static void shouldApplyStringMapOverrides()
	{
		Foobar__c mock = (Foobar__c)TST_Mock.of(Foobar__c.SObjectType)
				.withOverrides(new Map<String, Object>
				{
						SEL_Foobar.FIELD_INTEGER => 88,
						SEL_Foobar.FIELD_CHECK_BOX => true
				})
				.build();

		Assert.areEqual(88, mock.NumberInteger__c, 'Should apply integer override');
		Assert.isTrue(mock.Checkbox__c, 'Should apply checkbox override');
	}

	/**
	 * @description Tests that withRecordType sets the RecordTypeId on the mock.
	 */
	@IsTest
	private static void shouldApplyRecordType()
	{
		Foobar__c mock = (Foobar__c)TST_Mock.of(Foobar__c.SObjectType)
				.withRecordType(SEL_Foobar.RT_DEFAULT)
				.build();

		Assert.isNotNull(mock.RecordTypeId, 'Should have a RecordTypeId');
	}

	/**
	 * @description Tests that withDefaultedField(String) populates a non-required field.
	 */
	@IsTest
	private static void shouldApplyDefaultedStringField()
	{
		Foobar__c mock = (Foobar__c)TST_Mock.of(Foobar__c.SObjectType)
				.withDefaultedField(SEL_Foobar.FIELD_EMAIL)
				.build();

		Assert.isNotNull(mock.Email__c, 'Defaulted field should be populated');
	}

	/**
	 * @description Tests that withDefaultedField(SObjectField) populates a non-required field.
	 */
	@IsTest
	private static void shouldApplyDefaultedTokenField()
	{
		Foobar__c mock = (Foobar__c)TST_Mock.of(Foobar__c.SObjectType)
				.withDefaultedField(Foobar__c.Email__c)
				.build();

		Assert.isNotNull(mock.Email__c, 'Defaulted field should be populated');
	}

	/**
	 * @description Tests that withDefaultedFields populates multiple non-required fields.
	 */
	@IsTest
	private static void shouldApplyDefaultedFields()
	{
		Foobar__c mock = (Foobar__c)TST_Mock.of(Foobar__c.SObjectType)
				.withDefaultedFields(new List<Object> {SEL_Foobar.FIELD_EMAIL, Foobar__c.Phone__c})
				.build();

		Assert.isNotNull(mock.Email__c, 'Email should be populated');
		Assert.isNotNull(mock.Phone__c, 'Phone should be populated');
	}

	/**
	 * @description Tests that withOptionalField(String) prevents auto-population of a required field.
	 */
	@IsTest
	private static void shouldApplyOptionalStringField()
	{
		Foobar__c mock = (Foobar__c)TST_Mock.of(Foobar__c.SObjectType)
				.withOptionalField(SEL_Foobar.FIELD_NAME)
				.build();

		Assert.isNull(mock.Name, 'Optional field should not be populated');
	}

	/**
	 * @description Tests that withOptionalField(SObjectField) prevents auto-population of a required field.
	 */
	@IsTest
	private static void shouldApplyOptionalTokenField()
	{
		Foobar__c mock = (Foobar__c)TST_Mock.of(Foobar__c.SObjectType)
				.withOptionalField(Foobar__c.Name)
				.build();

		Assert.isNull(mock.Name, 'Optional field should not be populated');
	}

	/**
	 * @description Tests that withOptionalFields prevents auto-population of multiple required fields.
	 */
	@IsTest
	private static void shouldApplyOptionalFields()
	{
		Foobar__c mock = (Foobar__c)TST_Mock.of(Foobar__c.SObjectType)
				.withOptionalFields(new List<Object> {SEL_Foobar.FIELD_NAME, Foobar__c.Name})
				.build();

		Assert.isNull(mock.Name, 'Optional field should not be populated');
	}

	/**
	 * @description Tests that withCycle distributes values cyclically across mock records using an SObjectField token.
	 */
	@IsTest
	private static void shouldCycleValuesAcrossMockRecords()
	{
		List<SObject> mocks = TST_Mock.of(Foobar__c.SObjectType)
				.withCycle(Foobar__c.Text__c, new List<Object> {'Alpha', 'Beta', 'Gamma'})
				.withCount(6)
				.buildList();

		Assert.areEqual(6, mocks.size(), 'Should build 6 mock records');
		Assert.areEqual('Alpha', ((Foobar__c)mocks[0]).Text__c, 'Index 0 should be Alpha');
		Assert.areEqual('Beta', ((Foobar__c)mocks[1]).Text__c, 'Index 1 should be Beta');
		Assert.areEqual('Gamma', ((Foobar__c)mocks[2]).Text__c, 'Index 2 should be Gamma');
		Assert.areEqual('Alpha', ((Foobar__c)mocks[3]).Text__c, 'Index 3 should cycle back to Alpha');
		Assert.areEqual('Beta', ((Foobar__c)mocks[4]).Text__c, 'Index 4 should cycle back to Beta');
		Assert.areEqual('Gamma', ((Foobar__c)mocks[5]).Text__c, 'Index 5 should cycle back to Gamma');

		List<SObject> registered = TST_Mock.get(Foobar__c.SObjectType);

		Assert.areEqual(6, registered.size(), 'Should have 6 registered mocks');
	}

	/**
	 * @description Tests that withCycle distributes values cyclically using a String field name.
	 */
	@IsTest
	private static void shouldCycleValuesAcrossMockRecordsWithString()
	{
		List<SObject> mocks = TST_Mock.of(Foobar__c.SObjectType)
				.withCycle(SEL_Foobar.FIELD_INTEGER, new List<Object> {10, 20})
				.withCount(4)
				.buildList();

		Assert.areEqual(4, mocks.size(), 'Should build 4 mock records');
		Assert.areEqual(10, ((Foobar__c)mocks[0]).NumberInteger__c, 'Index 0 should be 10');
		Assert.areEqual(20, ((Foobar__c)mocks[1]).NumberInteger__c, 'Index 1 should be 20');
		Assert.areEqual(10, ((Foobar__c)mocks[2]).NumberInteger__c, 'Index 2 should cycle back to 10');
		Assert.areEqual(20, ((Foobar__c)mocks[3]).NumberInteger__c, 'Index 3 should cycle back to 20');
	}

	/**
	 * @description Tests that withChildren(SObjectType, Integer) creates child records on the mock.
	 */
	@IsTest
	private static void shouldBuildWithChildrenNoOverrides()
	{
		Foobar__c mock = (Foobar__c)TST_Mock.of(Foobar__c.SObjectType)
				.withChildren(Foobar__c.SObjectType, 2)
				.build();

		Assert.isNotNull(mock.Id, 'Parent should have a mock Id');

		List<SObject> registered = TST_Mock.get(Foobar__c.SObjectType);

		Assert.isFalse(registered.isEmpty(), 'Should have registered mocks');
	}

	/**
	 * @description Tests that withChildren with SObjectField overrides creates properly configured children.
	 */
	@IsTest
	private static void shouldBuildWithChildrenTokenOverrides()
	{
		Foobar__c mock = (Foobar__c)TST_Mock.of(Foobar__c.SObjectType)
				.withChildren(Foobar__c.SObjectType, 3, new Map<SObjectField, Object>
				{
						Foobar__c.NumberInteger__c => 10
				})
				.build();

		Assert.isNotNull(mock.Id, 'Parent should have a mock Id');
	}

	/**
	 * @description Tests that withChildren with String overrides creates properly configured children.
	 */
	@IsTest
	private static void shouldBuildWithChildrenStringOverrides()
	{
		Foobar__c mock = (Foobar__c)TST_Mock.of(Foobar__c.SObjectType)
				.withChildren(Foobar__c.SObjectType, 2, new Map<String, Object>
				{
						SEL_Foobar.FIELD_INTEGER => 20
				})
				.build();

		Assert.isNotNull(mock.Id, 'Parent should have a mock Id');
	}

	/**
	 * @description Tests that withChildren(Builder) creates children using a pre-configured builder.
	 */
	@IsTest
	private static void shouldBuildWithChildrenBuilder()
	{
		Foobar__c mock = (Foobar__c)TST_Mock.of(Foobar__c.SObjectType)
				.withChildren(
						TST_Builder.of(Foobar__c.SObjectType)
								.withCount(2)
								.withOverride(Foobar__c.NumberInteger__c, 55)
				)
				.build();

		Assert.isNotNull(mock.Id, 'Parent should have a mock Id');
	}

	/**
	 * @description Tests that withChildren(String, Builder) creates children with an explicit relationship name.
	 */
	@IsTest
	private static void shouldBuildWithChildrenExplicitRelationship()
	{
		Foobar__c mock = (Foobar__c)TST_Mock.of(Foobar__c.SObjectType)
				.withChildren(
						SEL_Foobar.RELATIONSHIP_FOOBARS,
						TST_Builder.of(Foobar__c.SObjectType)
								.withCount(2)
								.withOverride(Foobar__c.NumberInteger__c, 33)
				)
				.build();

		Assert.isNotNull(mock.Id, 'Parent should have a mock Id');
	}

	/**
	 * @description Tests that registerNext serves its answer to exactly one selector query, after which the
	 * records registered with register answer again.
	 */
	@IsTest
	private static void shouldServeTheNextAnswerOnceThenTheRegisteredRecords()
	{
		Foobar__c registered = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion(true).build();
		TST_Mock.register(Foobar__c.SObjectType, registered);
		TST_Mock.registerNext(Foobar__c.SObjectType, new List<SObject>());

		Assert.isNull(new SEL_Foobar().findById(registered.Id), 'The queued empty answer makes the first query find nothing');
		Foobar__c found = (Foobar__c)new SEL_Foobar().findById(registered.Id);
		Assert.areEqual(registered.Id, found?.Id, 'The second query falls back to the registered records');
	}

	/**
	 * @description Tests that queued answers serve in registration order, a one-record answer through the
	 * single-record overload, and that the registered records answer once the queue is used up.
	 */
	@IsTest
	private static void shouldServeQueuedAnswersInRegistrationOrder()
	{
		Foobar__c registered = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion(true).build();
		Foobar__c scripted = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion(true).build();
		TST_Mock.register(Foobar__c.SObjectType, registered);
		TST_Mock.registerNext(Foobar__c.SObjectType, new List<SObject>());
		TST_Mock.registerNext(Foobar__c.SObjectType, scripted);

		List<SObject> first = QRY_Builder.selectFrom(Foobar__c.SObjectType).toList();
		List<SObject> second = QRY_Builder.selectFrom(Foobar__c.SObjectType).toList();
		List<SObject> third = QRY_Builder.selectFrom(Foobar__c.SObjectType).toList();

		Assert.isTrue(first.isEmpty(), 'The first answer is the empty one');
		Assert.areEqual(scripted.Id, second[0].Id, 'The second answer is the scripted record');
		Assert.areEqual(registered.Id, third[0].Id, 'After the queue the registered records answer');
	}

	/**
	 * @description Tests that with nothing registered, the query after the last queued answer reads the
	 * database: the row stored for real is found on the second read. The read sequence: the first read is the
	 * queued empty answer, the second reads the database.
	 */
	@IsTest
	private static void shouldReadTheDatabaseOnceTheQueuedAnswersAreUsed()
	{
		Foobar__c stored = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
		TST_Mock.registerNext(Foobar__c.SObjectType, new List<SObject>());

		Assert.isNull(new SEL_Foobar().findById(stored.Id), 'The queued empty answer blinds the first read to the stored row');
		Foobar__c found = (Foobar__c)new SEL_Foobar().findById(stored.Id);
		Assert.areEqual(stored.Id, found?.Id, 'With nothing queued or registered, the second read finds the stored row');
	}

	/**
	 * @description Tests that a count consumes a queued answer and returns its size, then the registered records' size.
	 */
	@IsTest
	private static void shouldServeTheNextAnswerToACount()
	{
		TST_Mock.register(Foobar__c.SObjectType, TST_Builder.of(Foobar__c.SObjectType).withCount(2).withoutInsertion(true).buildList());
		TST_Mock.registerNext(Foobar__c.SObjectType, TST_Builder.of(Foobar__c.SObjectType).withCount(3).withoutInsertion(true).buildList());

		Assert.areEqual(3, QRY_Builder.selectFrom(Foobar__c.SObjectType).count(), 'A count consumes the queued answer and returns its size');
		Assert.areEqual(2, QRY_Builder.selectFrom(Foobar__c.SObjectType).count(), 'The next count returns the registered records');
	}

	/**
	 * @description Tests that the rows registered with registerAggregateRows answer a grouped count, in the order they
	 * were registered, and that each value is read back under the alias it was registered with.
	 */
	@IsTest
	private static void shouldReturnRegisteredAggregateRows()
	{
		TST_Mock.registerAggregateRows(Foobar__c.SObjectType, new List<Map<String, Object>>
		{
				new Map<String, Object> {TOTAL_ALIAS => FIRST_GROUP_TOTAL, SEL_Foobar.FIELD_NAME => FIRST_GROUP_NAME},
				new Map<String, Object> {TOTAL_ALIAS => SECOND_GROUP_TOTAL, SEL_Foobar.FIELD_NAME => SECOND_GROUP_NAME}
		});

		List<QRY_Builder.AggregateRow> rows = QRY_Builder.selectFrom(Foobar__c.SObjectType)
				.count(Foobar__c.Id, TOTAL_ALIAS)
				.groupBy(Foobar__c.Name)
				.toAggregateList();

		Assert.areEqual(2, rows.size(), 'Expected one row for each registered map');
		Assert.areEqual(FIRST_GROUP_TOTAL, rows[0].getInteger(TOTAL_ALIAS), 'Expected the first row to hold the first registered total');
		Assert.areEqual(FIRST_GROUP_NAME, rows[0].getString(SEL_Foobar.FIELD_NAME), 'Expected the first row to hold the first registered name');
		Assert.areEqual(SECOND_GROUP_TOTAL, rows[1].getInteger(TOTAL_ALIAS), 'Expected the second row to hold the second registered total');
		Assert.areEqual(SECOND_GROUP_NAME, rows[1].getString(SEL_Foobar.FIELD_NAME), 'Expected the second row to hold the second registered name');
	}

	/**
	 * @description Tests that the one-row overload of registerAggregateRows answers getFirstAggregate, and that a whole
	 * number registered for a sum can be read as a Decimal, as a real sum row allows.
	 */
	@IsTest
	private static void shouldReturnTheSingleRegisteredAggregateRowFromGetFirstAggregate()
	{
		TST_Mock.registerAggregateRows(Foobar__c.SObjectType, new Map<String, Object> {SUM_ALIAS => REGISTERED_SUM});

		QRY_Builder.AggregateRow row = QRY_Builder.selectFrom(Foobar__c.SObjectType)
				.sum(Foobar__c.NumberInteger__c, SUM_ALIAS)
				.getFirstAggregate();

		Assert.isNotNull(row, 'Expected the registered row to answer getFirstAggregate');
		Assert.areEqual(Decimal.valueOf(REGISTERED_SUM), row.getDecimal(SUM_ALIAS), 'Expected the whole number to be read as the same Decimal');
	}

	/**
	 * @description Tests that rows set with registerNextAggregateRows each answer one aggregate query, in the order they
	 * were added and before the rows set with registerAggregateRows. Once they are used up, the registered rows answer
	 * every query.
	 */
	@IsTest
	private static void shouldServeTheNextAggregateRowsOnceThenTheRegisteredRows()
	{
		TST_Mock.registerAggregateRows(Foobar__c.SObjectType, new Map<String, Object> {TOTAL_ALIAS => REGISTERED_TOTAL});
		TST_Mock.registerNextAggregateRows(Foobar__c.SObjectType, new List<Map<String, Object>> {new Map<String, Object> {TOTAL_ALIAS => FIRST_GROUP_TOTAL}});
		TST_Mock.registerNextAggregateRows(Foobar__c.SObjectType, new Map<String, Object> {TOTAL_ALIAS => SECOND_GROUP_TOTAL});

		Assert.areEqual(FIRST_GROUP_TOTAL, readFoobarTotal(), 'Expected the first query to get the first next answer');
		Assert.areEqual(SECOND_GROUP_TOTAL, readFoobarTotal(), 'Expected the second query to get the second next answer');
		Assert.areEqual(REGISTERED_TOTAL, readFoobarTotal(), 'Expected the registered rows once the next answers are used up');
		Assert.areEqual(REGISTERED_TOTAL, readFoobarTotal(), 'Expected the registered rows to keep answering');
	}

	/**
	 * @description Tests that a second call to registerAggregateRows adds its rows after the rows registered earlier for
	 * the type, the way register adds records. One aggregate query returns both sets, the first registered first.
	 */
	@IsTest
	private static void shouldAddAggregateRowsToTheRowsRegisteredEarlier()
	{
		TST_Mock.registerAggregateRows(Foobar__c.SObjectType, new List<Map<String, Object>> {new Map<String, Object> {TOTAL_ALIAS => FIRST_GROUP_TOTAL}});
		TST_Mock.registerAggregateRows(Foobar__c.SObjectType, new Map<String, Object> {TOTAL_ALIAS => SECOND_GROUP_TOTAL});

		List<QRY_Builder.AggregateRow> rows = QRY_Builder.selectFrom(Foobar__c.SObjectType).count(Foobar__c.Id, TOTAL_ALIAS).toAggregateList();

		Assert.areEqual(2, rows.size(), 'Expected the rows of both calls');
		Assert.areEqual(FIRST_GROUP_TOTAL, rows[0].getInteger(TOTAL_ALIAS), 'Expected the rows registered first to come first');
		Assert.areEqual(SECOND_GROUP_TOTAL, rows[1].getInteger(TOTAL_ALIAS), 'Expected the rows registered second to come after them');
	}

	/**
	 * @description Tests that QRY_Builder.setAggregateMock replaces the rows that TST_Mock.registerAggregateRows registered
	 * earlier for the type, so only the rows set last answer.
	 */
	@IsTest
	private static void shouldReplaceRegisteredAggregateRowsWhenSetAggregateMockFollows()
	{
		TST_Mock.registerAggregateRows(Foobar__c.SObjectType, new Map<String, Object> {TOTAL_ALIAS => FIRST_GROUP_TOTAL});
		QRY_Builder.setAggregateMock(Foobar__c.SObjectType, new List<Map<String, Object>> {new Map<String, Object> {TOTAL_ALIAS => SECOND_GROUP_TOTAL}});

		List<QRY_Builder.AggregateRow> rows = QRY_Builder.selectFrom(Foobar__c.SObjectType).count(Foobar__c.Id, TOTAL_ALIAS).toAggregateList();

		Assert.areEqual(1, rows.size(), 'Expected only the rows set last');
		Assert.areEqual(SECOND_GROUP_TOTAL, rows[0].getInteger(TOTAL_ALIAS), 'Expected the rows set with setAggregateMock to replace the registered ones');
	}

	/**
	 * @description Tests that the count() that ends a query counts the record mocks and never the aggregate rows, when
	 * both are registered for the same type. An aggregate query on the same type still reads the aggregate row.
	 */
	@IsTest
	private static void shouldCountRecordMocksAndNeverAggregateRows()
	{
		TST_Mock.register(Foobar__c.SObjectType, TST_Builder.of(Foobar__c.SObjectType).withCount(RECORD_MOCK_COUNT).withoutInsertion(true).buildList());
		TST_Mock.registerAggregateRows(Foobar__c.SObjectType, new Map<String, Object> {TOTAL_ALIAS => REGISTERED_TOTAL});

		Integer recordCount = QRY_Builder.selectFrom(Foobar__c.SObjectType).count();
		List<QRY_Builder.AggregateRow> rows = QRY_Builder.selectFrom(Foobar__c.SObjectType).count(Foobar__c.Id, TOTAL_ALIAS).toAggregateList();

		Assert.areEqual(RECORD_MOCK_COUNT, recordCount, 'Expected count() to count the record mocks, not the aggregate row');
		Assert.areEqual(1, rows.size(), 'Expected the aggregate query to read the one aggregate row');
		Assert.areEqual(REGISTERED_TOTAL, rows[0].getInteger(TOTAL_ALIAS), 'Expected the aggregate row to hold the registered total');
	}

	/**
	 * @description Tests that clear() removes the aggregate rows of every type, the registered ones and the next answers,
	 * so aggregate queries read the database again. The registered totals differ from the real counts, so a row left
	 * behind would show.
	 */
	@IsTest
	private static void shouldClearAggregateRowsOnClear()
	{
		TST_Factory.insertFoobar();
		TST_Mock.registerAggregateRows(Foobar__c.SObjectType, new Map<String, Object> {TOTAL_ALIAS => REGISTERED_TOTAL});
		TST_Mock.registerNextAggregateRows(Foobar__c.SObjectType, new Map<String, Object> {TOTAL_ALIAS => FIRST_GROUP_TOTAL});
		TST_Mock.registerAggregateRows(Account.SObjectType, new Map<String, Object> {TOTAL_ALIAS => SECOND_GROUP_TOTAL});

		TST_Mock.clear();

		Assert.areEqual(1, readFoobarTotal(), 'Expected the Foobar count to come from the one stored row');
		QRY_Builder.AggregateRow accountRow = QRY_Builder.selectFrom(Account.SObjectType).count(Account.Id, TOTAL_ALIAS).getFirstAggregate();
		Assert.areEqual(0, accountRow.getInteger(TOTAL_ALIAS), 'Expected the Account count to come from the database, which holds no account');
	}

	/**
	 * @description Tests that clear(SObjectType) removes the aggregate rows of that type only: the cleared type reads the
	 * database again, and the rows registered for another type still answer.
	 */
	@IsTest
	private static void shouldClearOnlyThatTypesAggregateRows()
	{
		TST_Factory.insertFoobar();
		TST_Mock.registerAggregateRows(Foobar__c.SObjectType, new Map<String, Object> {TOTAL_ALIAS => REGISTERED_TOTAL});
		TST_Mock.registerNextAggregateRows(Foobar__c.SObjectType, new Map<String, Object> {TOTAL_ALIAS => FIRST_GROUP_TOTAL});
		TST_Mock.registerAggregateRows(Account.SObjectType, new Map<String, Object> {TOTAL_ALIAS => SECOND_GROUP_TOTAL});

		TST_Mock.clear(Foobar__c.SObjectType);

		Assert.areEqual(1, readFoobarTotal(), 'Expected the Foobar count to come from the one stored row');
		List<QRY_Builder.AggregateRow> accountRows = QRY_Builder.selectFrom(Account.SObjectType).count(Account.Id, TOTAL_ALIAS).toAggregateList();
		Assert.areEqual(1, accountRows.size(), 'Expected the Account rows to still answer');
		Assert.areEqual(SECOND_GROUP_TOTAL, accountRows[0].getInteger(TOTAL_ALIAS), 'Expected the registered Account total');
	}

	/**
	 * @description Tests that null rows, or a null row, are refused with IllegalArgumentException by registerAggregateRows
	 * and by the one-row overload of registerNextAggregateRows, and that the error points at the empty list. A silent
	 * null would leave the test reading something other than what it meant to register.
	 */
	@IsTest
	private static void shouldRefuseNullAggregateRows()
	{
		List<Map<String, Object>> nullRows = null;
		Map<String, Object> nullRow = null;
		try
		{
			TST_Mock.registerAggregateRows(Foobar__c.SObjectType, nullRows);
			Assert.fail('Expected null rows to be refused');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Expected IllegalArgumentException for null rows: ' + error.getMessage());
			Assert.isTrue(error.getMessage().contains(EMPTY_LIST_HINT), 'Expected the refusal to point at the empty list: ' + error.getMessage());
		}
		try
		{
			TST_Mock.registerAggregateRows(Foobar__c.SObjectType, nullRow);
			Assert.fail('Expected a null row to be refused');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Expected IllegalArgumentException for a null row: ' + error.getMessage());
			Assert.isTrue(error.getMessage().contains(EMPTY_LIST_HINT), 'Expected the refusal to point at the empty list: ' + error.getMessage());
		}
		try
		{
			TST_Mock.registerNextAggregateRows(Foobar__c.SObjectType, nullRow);
			Assert.fail('Expected a null next row to be refused');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Expected IllegalArgumentException for a null next row: ' + error.getMessage());
			Assert.isTrue(error.getMessage().contains(EMPTY_LIST_HINT), 'Expected the refusal to point at the empty list: ' + error.getMessage());
		}
	}

	/**
	 * @description Tests that a registered exception fires before any queued answer and consumes nothing: once
	 * the exception alone is cleared, the queued answer serves.
	 */
	@IsTest
	private static void shouldFireARegisteredExceptionBeforeAQueuedAnswer()
	{
		Foobar__c scripted = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion(true).build();
		TST_Mock.registerNext(Foobar__c.SObjectType, scripted);
		TST_Mock.throwsException(Foobar__c.SObjectType, REGISTERED_FAILURE);

		try
		{
			QRY_Builder.selectFrom(Foobar__c.SObjectType).toList();
			Assert.fail('The registered exception fires before any queued answer');
		}
		catch(QueryException error)
		{
			Assert.areEqual(REGISTERED_FAILURE, error.getMessage(), 'The registered exception is the one thrown');
		}

		QRY_Engine.clearMockException(Foobar__c.SObjectType);

		List<SObject> served = QRY_Builder.selectFrom(Foobar__c.SObjectType).toList();
		Assert.areEqual(scripted.Id, served[0].Id, 'The queued answer was not consumed by the query that threw');
	}

	/**
	 * @description Tests that clear(SObjectType) drops that type's queued answers and leaves another type's, and
	 * that clear() drops every queued answer.
	 */
	@IsTest
	private static void shouldDropQueuedAnswersOnClear()
	{
		Foobar__c scriptedFoobar = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion(true).build();
		Account scriptedAccount = (Account)TST_Builder.of(Account.SObjectType).withoutInsertion(true).build();
		TST_Mock.registerNext(Foobar__c.SObjectType, scriptedFoobar);
		TST_Mock.registerNext(Account.SObjectType, scriptedAccount);

		TST_Mock.clear(Foobar__c.SObjectType);

		Assert.isTrue(QRY_Builder.selectFrom(Foobar__c.SObjectType).toList().isEmpty(), 'clear(type) drops that type\'s queued answers, so the query reads the empty database');
		Assert.areEqual(scriptedAccount.Id, QRY_Builder.selectFrom(Account.SObjectType).toList()[0].Id, 'clear(type) leaves the other type\'s queue intact');

		TST_Mock.registerNext(Account.SObjectType, scriptedAccount);
		TST_Mock.clear();

		Assert.isTrue(QRY_Builder.selectFrom(Account.SObjectType).toList().isEmpty(), 'clear() drops every queued answer');
	}

	/**
	 * @description Tests the clear fix: a cleared type no longer intercepts. While a mock is registered the stored
	 * row is hidden; after clear(type) and after clear() the registration is gone and the database answers.
	 */
	@IsTest
	private static void shouldQueryTheDatabaseAgainOnceAMockIsCleared()
	{
		Foobar__c stored = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
		Foobar__c registered = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion(true).build();
		TST_Mock.register(Foobar__c.SObjectType, registered);
		Assert.isNull(new SEL_Foobar().findById(stored.Id), 'While registered, the mock hides the stored row');

		TST_Mock.clear(Foobar__c.SObjectType);

		Assert.isFalse(QRY_Engine.hasMock(Foobar__c.SObjectType), 'clear(type) removes the registration outright');
		Foobar__c found = (Foobar__c)new SEL_Foobar().findById(stored.Id);
		Assert.areEqual(stored.Id, found?.Id, 'A cleared type reads the database again');

		TST_Mock.register(Foobar__c.SObjectType, registered);
		TST_Mock.clear();

		Assert.isFalse(QRY_Engine.hasMock(Foobar__c.SObjectType), 'clear() removes every registration outright');
	}

	/**
	 * @description Tests that a null list is refused as the next answer, with the empty list named as the way to
	 * script a query that finds nothing.
	 */
	@IsTest
	private static void shouldRefuseANullListAsTheNextAnswer()
	{
		try
		{
			TST_Mock.registerNext(Foobar__c.SObjectType, (List<SObject>)null);
			Assert.fail('A null list should be refused as the next answer');
		}
		catch(IllegalArgumentException error)
		{
			Assert.isTrue(error.getMessage().contains(EMPTY_LIST_HINT), 'The refusal points at the empty list: ' + error.getMessage());
		}
	}

	/**
	 * @description Tests that a null record is refused as the next answer rather than queued as a one-null answer.
	 */
	@IsTest
	private static void shouldRefuseANullRecordAsTheNextAnswer()
	{
		try
		{
			TST_Mock.registerNext(Foobar__c.SObjectType, (SObject)null);
			Assert.fail('A null record should be refused as the next answer');
		}
		catch(IllegalArgumentException error)
		{
			Assert.isTrue(error.getMessage().contains(EMPTY_LIST_HINT), 'The refusal points at the empty list: ' + error.getMessage());
		}
	}

	/**
	 * @description Tests that a record of another type is refused as the next answer by the mock validation.
	 */
	@IsTest
	private static void shouldRefuseARecordOfAnotherTypeAsTheNextAnswer()
	{
		Account account = (Account)TST_Builder.of(Account.SObjectType).withoutInsertion(true).build();
		try
		{
			TST_Mock.registerNext(Foobar__c.SObjectType, account);
			Assert.fail('A record of another type should be refused');
		}
		catch(IllegalArgumentException error)
		{
			Assert.isTrue(error.getMessage().contains(TYPE_MISMATCH_HINT), 'The refusal names the mismatch: ' + error.getMessage());
		}
	}

	/**
	 * @description Tests that get returns registered records only, never queued answers.
	 */
	@IsTest
	private static void shouldNotIncludeQueuedAnswersInGet()
	{
		TST_Mock.registerNext(Foobar__c.SObjectType, TST_Builder.of(Foobar__c.SObjectType).withoutInsertion(true).buildList());

		Assert.isTrue(TST_Mock.get(Foobar__c.SObjectType).isEmpty(), 'get returns registered records only, never queued answers');

		TST_Mock.clear();
	}

	/**
	 * @description Counts the Foobar__c rows through an aggregate query and returns the total, read under TOTAL_ALIAS.
	 * A registered aggregate row answers the query when there is one; otherwise the database does.
	 *
	 * @return The total the aggregate query returned.
	 */
	private static Integer readFoobarTotal()
	{
		return QRY_Builder.selectFrom(Foobar__c.SObjectType).count(Foobar__c.Id, TOTAL_ALIAS).getFirstAggregate().getInteger(TOTAL_ALIAS);
	}
}