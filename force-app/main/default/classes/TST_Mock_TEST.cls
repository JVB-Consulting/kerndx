// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for TST_Mock.
 *
 * @see TST_Mock
 *
 * @author Jason van Beukering
 *
 * @group Testing
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class TST_Mock_TEST
{
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
}