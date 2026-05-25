// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for SEL_Base abstract selector class.
 * Uses a concrete test selector (TestSelector) extending SEL_Base
 * to verify constructor, field management, query building, singleton
 * caching, and IF_Queryable implementation.
 *
 * @see SEL_Base
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date February 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=false)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SEL_Base_TEST
{
	private static final String TEST_ADMIN_COMPANY = 'SEL_Base_TEST-admin';

	/**
	 * @description Concrete selector for testing SEL_Base with Foobar__c.
	 */
	private class TestSelector extends SEL_Base
	{
		/**
		 * @description Constructs a TestSelector for Foobar__c.
		 */
		public TestSelector()
		{
			super(Foobar__c.SObjectType);
		}

		/**
		 * @description Returns core fields for Foobar__c.
		 *
		 * @return The list of common field for the object
		 */
		public override List<SObjectField> getFields()
		{
			return new List<SObjectField>
			{
					Foobar__c.Name,
					Foobar__c.Text__c
			};
		}
	}

	/**
	 * @description Minimal selector with no field overrides for testing base defaults.
	 */
	private class DefaultSelector extends SEL_Base
	{
		/**
		 * @description Constructs a DefaultSelector for Foobar__c.
		 */
		public DefaultSelector()
		{
			super(Foobar__c.SObjectType);
		}
	}

	/**
	 * @description Creates a dedicated test admin user so System.runAs in each test starts a fresh
	 * permission-evaluation context, bypassing the synthetic-org permission-cache staleness issue
	 * that affected mutating the running user's permissionSet mid-transaction.
	 */
	@TestSetup
	private static void setupTestAdmin()
	{
		TST_Factory.newUserWithPermissionSet
				(
						SEL_Profile.PROFILE_SYSTEM_ADMIN,
						TEST_ADMIN_COMPANY,
						SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME
				);
	}

	/**
	 * @description Tests that field properties return empty lists when no overrides are provided.
	 */
	@IsTest
	private static void shouldReturnEmptyFieldsByDefault()
	{
		System.runAs(getTestAdmin())
		{
			DefaultSelector selector = new DefaultSelector();

			Assert.isTrue(selector.fields.isEmpty(), 'Should return empty fields by default');
			Assert.isTrue(selector.fieldPaths.isEmpty(), 'Should return empty fieldPaths by default');
		}
	}

	/**
	 * @description Tests that the fields property returns the fields defined by the subclass.
	 */
	@IsTest
	private static void shouldReturnFields()
	{
		System.runAs(getTestAdmin())
		{
			TestSelector selector = new TestSelector();

			List<SObjectField> result = selector.fields;

			Assert.areEqual(2, result.size(), 'Should contain 2 core fields');
			Assert.isTrue(result.contains(Foobar__c.Name), 'Should contain Name');
			Assert.isTrue(result.contains(Foobar__c.Text__c), 'Should contain Text__c');
		}
	}

	/**
	 * @description Tests that toList executes a query and returns records.
	 */
	@IsTest
	private static void shouldExecuteToList()
	{
		System.runAs(getTestAdmin())
		{
			TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, 'Test Record')
					.build();

			TestSelector selector = new TestSelector();

			List<SObject> results = selector.toList();

			Assert.isFalse(results.isEmpty(), 'Should return at least one record');
		}
	}

	/**
	 * @description Tests that getFirst executes a query and returns first record.
	 */
	@IsTest
	private static void shouldExecuteGetFirst()
	{
		System.runAs(getTestAdmin())
		{
			TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, 'First Record')
					.build();

			TestSelector selector = new TestSelector();

			SObject result = selector.getFirst();

			Assert.isNotNull(result, 'Should return a record');
		}
	}

	/**
	 * @description Tests that count returns the number of matching records.
	 */
	@IsTest
	private static void shouldReturnCount()
	{
		System.runAs(getTestAdmin())
		{
			TST_Builder.of(Foobar__c.SObjectType)
					.withCount(3)
					.buildList();

			TestSelector selector = new TestSelector();

			Integer result = selector.count();

			Assert.areEqual(3, result, 'Should return count of 3');
		}
	}

	/**
	 * @description Tests that exists returns true when records exist.
	 */
	@IsTest
	private static void shouldReturnTrueWhenRecordsExist()
	{
		System.runAs(getTestAdmin())
		{
			TST_Builder.of(Foobar__c.SObjectType).build();

			TestSelector selector = new TestSelector();

			Assert.isTrue(selector.exists(), 'Should return true when records exist');
		}
	}

	/**
	 * @description Tests that exists returns false when no records exist.
	 */
	@IsTest
	private static void shouldReturnFalseWhenNoRecordsExist()
	{
		System.runAs(getTestAdmin())
		{
			TestSelector selector = new TestSelector();

			Assert.isFalse(selector.exists(), 'Should return false when no records exist');
		}
	}

	/**
	 * @description Tests that toQueryLocator returns a valid QueryLocator.
	 */
	@IsTest
	private static void shouldReturnQueryLocator()
	{
		System.runAs(getTestAdmin())
		{
			TestSelector selector = new TestSelector();

			Database.QueryLocator locator = selector.toQueryLocator();

			Assert.isNotNull(locator, 'Should return a QueryLocator');
		}
	}

	/**
	 * @description Tests that a selector can be referenced as IF_Queryable.
	 */
	@IsTest
	private static void shouldBeUsableAsQueryable()
	{
		System.runAs(getTestAdmin())
		{
			TST_Builder.of(Foobar__c.SObjectType).build();

			IF_Queryable queryable = new TestSelector();

			Assert.isFalse(queryable.toList().isEmpty(), 'Should return records via interface');
			Assert.isTrue(queryable.count() > 0, 'Should return positive count via interface');
			Assert.isTrue(queryable.exists(), 'Should return true for exists via interface');
		}
	}

	/**
	 * @description Tests that getRandomItem returns a random record.
	 */
	@IsTest
	private static void shouldGetRandomItem()
	{
		System.runAs(getTestAdmin())
		{
			TST_Builder.of(Foobar__c.SObjectType).build();

			TestSelector selector = new TestSelector();

			SObject result = selector.getRandomItem();

			Assert.isNotNull(result, 'Should return a random record');
		}
	}

	/**
	 * @description Tests that the query includes core fields in the result.
	 */
	@IsTest
	private static void shouldIncludeCoreFieldsInQueryResults()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, 'Core Field Value')
					.build();

			TestSelector selector = new TestSelector();

			List<SObject> results = selector.toList();

			Foobar__c result = null;

			for(SObject each : results)
			{
				if(each.Id == record.Id)
				{
					result = (Foobar__c)each;
				}
			}

			Assert.isNotNull(result, 'Should return the inserted record');
			Assert.areEqual('Core Field Value', result.Name, 'Should include Name core field in result');
		}
	}

	/**
	 * @description Tests that the query property returns a builder that supports ad-hoc conditions.
	 */
	@IsTest
	private static void shouldSupportAdHocConditionsViaQueryBuilder()
	{
		System.runAs(getTestAdmin())
		{
			TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, 'Match')
					.build();

			TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, 'No Match')
					.build();

			TestSelector selector = new TestSelector();

			List<SObject> results = selector.query
					.condition(Foobar__c.Name).equals('Match')
					.toList();

			Assert.areEqual(1, results.size(), 'Should return only matching record');
			Assert.areEqual('Match', ((Foobar__c)results[0]).Name, 'Should return the correct record');
		}
	}

	/**
	 * @description Tests that findById returns the matching record.
	 */
	@IsTest
	private static void shouldFindById()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, 'FindMe')
					.build();

			TestSelector selector = new TestSelector();

			Foobar__c result = (Foobar__c)selector.findById(record.Id);

			Assert.isNotNull(result, 'Should return the record');
			Assert.areEqual('FindMe', result.Name, 'Should return the correct record');
		}
	}

	/**
	 * @description Tests that findById returns null for a non-existent Id.
	 */
	@IsTest
	private static void shouldReturnNullForNonExistentId()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c mockRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion(true)
					.build();

			TestSelector selector = new TestSelector();

			SObject result = selector.findById(mockRecord.Id);

			Assert.isNull(result, 'Should return null for non-existent Id');
		}
	}

	/**
	 * @description Tests that findById with a set of Ids returns all matching records.
	 */
	@IsTest
	private static void shouldFindByIdWithMultipleIds()
	{
		System.runAs(getTestAdmin())
		{
			List<SObject> records = TST_Builder.of(Foobar__c.SObjectType)
					.withCount(3)
					.buildList();

			Set<Id> recordIds = new Set<Id>();

			for(SObject each : records)
			{
				recordIds.add(each.Id);
			}

			TestSelector selector = new TestSelector();

			List<SObject> results = selector.findById(recordIds);

			Assert.areEqual(3, results.size(), 'Should return all 3 records');
		}
	}

	/**
	 * @description Tests that findById with an empty set returns an empty list.
	 */
	@IsTest
	private static void shouldReturnEmptyListForEmptyIdSet()
	{
		System.runAs(getTestAdmin())
		{
			TestSelector selector = new TestSelector();

			List<SObject> results = selector.findById(new Set<Id>());

			Assert.isTrue(results.isEmpty(), 'Should return empty list for empty Id set');
		}
	}

	/**
	 * @description Tests that findFirstByField returns the first matching record.
	 */
	@IsTest
	private static void shouldFindFirstByField()
	{
		System.runAs(getTestAdmin())
		{
			TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, 'Target')
					.build();

			TestSelector selector = new TestSelector();

			Foobar__c result = (Foobar__c)selector.findFirstByField(Foobar__c.Name, 'Target');

			Assert.isNotNull(result, 'Should return the matching record');
			Assert.areEqual('Target', result.Name, 'Should return the correct record');
		}
	}

	/**
	 * @description Tests that findFirstByField returns null when no records match.
	 */
	@IsTest
	private static void shouldReturnNullWhenFindFirstByFieldHasNoMatch()
	{
		System.runAs(getTestAdmin())
		{
			TestSelector selector = new TestSelector();

			SObject result = selector.findFirstByField(Foobar__c.Name, 'NonExistent');

			Assert.isNull(result, 'Should return null when no records match');
		}
	}

	/**
	 * @description Tests that findByField returns records matching a single value.
	 */
	@IsTest
	private static void shouldFindByFieldWithSingleValue()
	{
		System.runAs(getTestAdmin())
		{
			TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, 'Target')
					.build();

			TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, 'Other')
					.build();

			TestSelector selector = new TestSelector();

			List<SObject> results = selector.findByField(Foobar__c.Name, 'Target');

			Assert.areEqual(1, results.size(), 'Should return 1 matching record');
			Assert.areEqual('Target', ((Foobar__c)results[0]).Name, 'Should return the correct record');
		}
	}

	/**
	 * @description Tests that findByField returns records matching multiple string values.
	 */
	@IsTest
	private static void shouldFindByFieldWithMultipleValues()
	{
		System.runAs(getTestAdmin())
		{
			TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, 'Alpha')
					.build();

			TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, 'Beta')
					.build();

			TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, 'Gamma')
					.build();

			TestSelector selector = new TestSelector();

			List<SObject> results = selector.findByField(Foobar__c.Name, new Set<Object> {'Alpha', 'Beta'});

			Assert.areEqual(2, results.size(), 'Should return 2 matching records');
		}
	}

	/**
	 * @description Tests that findByField with an empty set returns an empty list.
	 */
	@IsTest
	private static void shouldReturnEmptyListForEmptyValueSet()
	{
		System.runAs(getTestAdmin())
		{
			TestSelector selector = new TestSelector();

			List<SObject> results = selector.findByField(Foobar__c.Name, new Set<Object>());

			Assert.isTrue(results.isEmpty(), 'Should return empty list for empty value set');
		}
	}

	/**
	 * @description Tests that findByField with a null set returns an empty list.
	 */
	@IsTest
	private static void shouldReturnEmptyListForNullValueSet()
	{
		System.runAs(getTestAdmin())
		{
			TestSelector selector = new TestSelector();

			List<SObject> results = selector.findByField(Foobar__c.Name, (Set<Object>)null);

			Assert.isTrue(results.isEmpty(), 'Should return empty list for null value set');
		}
	}

	/**
	 * @description Tests that findByField with an empty List of Object returns an empty list.
	 */
	@IsTest
	private static void shouldReturnEmptyListForEmptyValueList()
	{
		System.runAs(getTestAdmin())
		{
			TestSelector selector = new TestSelector();

			List<SObject> results = selector.findByField(Foobar__c.Name, new List<Object>());

			Assert.isTrue(results.isEmpty(), 'Should return empty list for empty value list');
		}
	}

	/**
	 * @description Tests that findByField with a List of Object returns matching records.
	 */
	@IsTest
	private static void shouldFindByFieldWithValueList()
	{
		System.runAs(getTestAdmin())
		{
			TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, 'Alpha')
					.build();

			TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, 'Beta')
					.build();

			TestSelector selector = new TestSelector();

			List<SObject> results = selector.findByField(Foobar__c.Name, new List<Object> {'Alpha', 'Beta'});

			Assert.areEqual(2, results.size(), 'Should return 2 matching records');
		}
	}

	/**
	 * @description Tests that findByFields returns records matching multiple field criteria.
	 */
	@IsTest
	private static void shouldFindByFields()
	{
		System.runAs(getTestAdmin())
		{
			TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Email__c, 'compound@example.com')
					.withOverride(Foobar__c.Phone__c, '555-0001')
					.build();

			TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Email__c, 'other@example.com')
					.withOverride(Foobar__c.Phone__c, '555-0002')
					.build();

			TestSelector selector = new TestSelector();

			List<SObject> results = selector.findByFields
					(
							new Map<SObjectField, Object> {Foobar__c.Email__c => 'compound@example.com', Foobar__c.Phone__c => '555-0001'}
					);

			Assert.areEqual(1, results.size(), 'Should return only the record matching both fields');
		}
	}

	/**
	 * @description Tests that findByFields returns an empty list for null input.
	 */
	@IsTest
	private static void shouldReturnEmptyListForNullFieldValues()
	{
		System.runAs(getTestAdmin())
		{
			TestSelector selector = new TestSelector();

			List<SObject> results = selector.findByFields(null);

			Assert.isTrue(results.isEmpty(), 'Should return empty list for null field values');
		}
	}

	/**
	 * @description Tests that findByFields returns an empty list for empty map input.
	 */
	@IsTest
	private static void shouldReturnEmptyListForEmptyFieldValues()
	{
		System.runAs(getTestAdmin())
		{
			TestSelector selector = new TestSelector();

			List<SObject> results = selector.findByFields(new Map<SObjectField, Object>());

			Assert.isTrue(results.isEmpty(), 'Should return empty list for empty field values');
		}
	}

	/**
	 * @description Tests that findFirstByFields returns the first matching record.
	 */
	@IsTest
	private static void shouldFindFirstByFields()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Email__c, 'first@example.com')
					.withOverride(Foobar__c.Phone__c, '555-0099')
					.build();

			TestSelector selector = new TestSelector();

			Foobar__c result = (Foobar__c)selector.findFirstByFields
					(
							new Map<SObjectField, Object> {Foobar__c.Email__c => 'first@example.com', Foobar__c.Phone__c => '555-0099'}
					);

			Assert.isNotNull(result, 'Should return the matching record');
			Assert.areEqual(record.Id, result.Id, 'Should return the correct record');
		}
	}

	/**
	 * @description Tests that findFirstByFields returns null for null input.
	 */
	@IsTest
	private static void shouldReturnNullForNullFieldValuesOnFindFirst()
	{
		System.runAs(getTestAdmin())
		{
			TestSelector selector = new TestSelector();

			SObject result = selector.findFirstByFields(null);

			Assert.isNull(result, 'Should return null for null field values');
		}
	}

	/**
	 * @description Tests that findByIdOrThrow returns the record when found.
	 */
	@IsTest
	private static void shouldFindByIdOrThrowWhenRecordExists()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, 'Found')
					.build();

			TestSelector selector = new TestSelector();

			Foobar__c result = (Foobar__c)selector.findByIdOrThrow(record.Id);

			Assert.areEqual('Found', result.Name, 'Should return the correct record');
		}
	}

	/**
	 * @description Tests that findByIdOrThrow throws NotFoundException for a non-existent Id.
	 */
	@IsTest
	private static void shouldThrowNotFoundExceptionForNonExistentId()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c mockRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion(true)
					.build();

			TestSelector selector = new TestSelector();

			try
			{
				selector.findByIdOrThrow(mockRecord.Id);
				Assert.fail('Should throw NotFoundException');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, UTIL_Exceptions.NotFoundException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests that findByIdOrThrow with a set returns all records when found.
	 */
	@IsTest
	private static void shouldFindByIdOrThrowWithSetWhenAllExist()
	{
		System.runAs(getTestAdmin())
		{
			List<SObject> records = TST_Builder.of(Foobar__c.SObjectType)
					.withCount(3)
					.buildList();

			Set<Id> recordIds = new Set<Id>();

			for(SObject each : records)
			{
				recordIds.add(each.Id);
			}

			TestSelector selector = new TestSelector();

			List<SObject> results = selector.findByIdOrThrow(recordIds);

			Assert.areEqual(3, results.size(), 'Should return all 3 records');
		}
	}

	/**
	 * @description Tests that findByIdOrThrow with a set throws NotFoundException when Ids are missing.
	 */
	@IsTest
	private static void shouldThrowNotFoundExceptionForMissingIds()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c insertedRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
			Foobar__c mockRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion(true)
					.build();

			Set<Id> recordIds = new Set<Id> {insertedRecord.Id, mockRecord.Id};

			TestSelector selector = new TestSelector();

			try
			{
				selector.findByIdOrThrow(recordIds);
				Assert.fail('Should throw NotFoundException');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, UTIL_Exceptions.NotFoundException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Framework-internal test double — selector that opts into SYSTEM_MODE regardless of flag.
	 */
	private class SystemModeRequiredSelector extends SEL_Base
	{
		/**
		 * @description Constructs a SystemModeRequiredSelector for Foobar__c.
		 */
		public SystemModeRequiredSelector()
		{
			super(Foobar__c.SObjectType);
		}

		/**
		 * @description Declares SYSTEM_MODE — simulates a framework-internal CMDT/system-schema selector.
		 *
		 * @return Always `true`.
		 */
		public override Boolean systemModeRequired()
		{
			return true;
		}
	}

	/**
	 * @description Default hook returns false; subscriber selector inherits flag-driven default.
	 */
	@IsTest
	private static void shouldInheritFlagDefaultWhenHookReturnsFalse()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);

			TestSelector selector = new TestSelector();

			Assert.isTrue(selector.query.userModeEnabled, 'Default selector must inherit USER_MODE when flag enabled');
		}
	}

	/**
	 * @description Selector override systemModeRequired()=true forces SYSTEM_MODE regardless of flag.
	 */
	@IsTest
	private static void shouldForceSystemModeWhenHookReturnsTrue()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);

			SystemModeRequiredSelector selector = new SystemModeRequiredSelector();

			Assert.isFalse(selector.query.userModeEnabled, 'systemModeRequired()=true must force SYSTEM_MODE even when flag enabled');
		}
	}

	/**
	 * @description Selector hook and flag both off → SYSTEM_MODE (framework default pre-flip).
	 */
	@IsTest
	private static void shouldUseSystemModeWhenFlagAndHookBothDefault()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true, false);

			TestSelector selector = new TestSelector();

			Assert.isFalse(selector.query.userModeEnabled, 'Flag disabled + hook default should yield SYSTEM_MODE');
		}
	}

	/**
	 * @description Retrieves the committed test admin user set up in @TestSetup for use with
	 * System.runAs, so each test body runs with a fresh permission-evaluation context.
	 *
	 * @return The test admin User record.
	 */
	private static User getTestAdmin()
	{
		return new SEL_User().findByCompanyName(TEST_ADMIN_COMPANY);
	}
}