// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for PROC_UpdateFields processor.
 *
 * @see PROC_UpdateFields
 *
 * @author Jason van Beukering
 *
 * @group Bulk DML
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=false)
private class PROC_UpdateFields_TEST
{
	private static final String TEST_ADMIN_COMPANY = 'PROC_UpdateFields_TEST-admin';

	/**
	 * @description Number of test records to create.
	 */
	private static final Integer NUMBER_OF_RECORDS = 5;

	/**
	 * @description Test value for replacement operations.
	 */
	private static final String TEST_REPLACEMENT_VALUE = 'ReplacedValue';

	/**
	 * @description Test prefix value.
	 */
	private static final String TEST_PREFIX = 'PREFIX_';

	/**
	 * @description Test suffix value.
	 */
	private static final String TEST_SUFFIX = '_SUFFIX';

	/**
	 * @description Error message for unexpected field value.
	 */
	private static final String MSG_FIELD_NOT_UPDATED = 'Field was not updated as expected';

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
	 * @description Tests field replacement using the REPLACE update method.
	 */
	@IsTest
	private static void shouldReplaceFieldValue()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> records = TST_Factory.insertFoobars(NUMBER_OF_RECORDS);

			PROC_UpdateFields.DTO_Parameters parameters = new PROC_UpdateFields.DTO_Parameters();
			parameters.objectName = SEL_Foobar.OBJECT_NAME;

			PROC_UpdateFields.DTO_Field fieldUpdate = new PROC_UpdateFields.DTO_Field();
			fieldUpdate.name = SEL_Foobar.FIELD_TEXT;
			fieldUpdate.value = TEST_REPLACEMENT_VALUE;
			fieldUpdate.updateMethod = PROC_UpdateFields.FieldUpdateMethod.REPLACE;

			parameters.updateFields.add(fieldUpdate);

			Test.startTest();

			new PROC_UpdateFields(parameters).execute(records);

			Test.stopTest();

			List<Foobar__c> updatedRecords = new SEL_Foobar().getAll();
			for(Foobar__c record : updatedRecords)
			{
				Assert.areEqual(TEST_REPLACEMENT_VALUE, record.Text__c, MSG_FIELD_NOT_UPDATED);
			}
		}
	}

	/**
	 * @description Tests field update using the PREFIX update method.
	 */
	@IsTest
	private static void shouldPrefixFieldValue()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> records = TST_Factory.insertFoobars(NUMBER_OF_RECORDS);

			PROC_UpdateFields.DTO_Parameters parameters = new PROC_UpdateFields.DTO_Parameters();
			parameters.objectName = SEL_Foobar.OBJECT_NAME;

			PROC_UpdateFields.DTO_Field fieldUpdate = new PROC_UpdateFields.DTO_Field();
			fieldUpdate.name = SEL_Foobar.FIELD_TEXT;
			fieldUpdate.value = TEST_PREFIX;
			fieldUpdate.updateMethod = PROC_UpdateFields.FieldUpdateMethod.PREFIX;

			parameters.updateFields.add(fieldUpdate);

			Test.startTest();

			new PROC_UpdateFields(parameters).execute(records);

			Test.stopTest();

			List<Foobar__c> updatedRecords = new SEL_Foobar().getAll();
			for(Foobar__c record : updatedRecords)
			{
				Assert.isTrue(record.Text__c.startsWith(TEST_PREFIX), MSG_FIELD_NOT_UPDATED);
			}
		}
	}

	/**
	 * @description Tests field update using the SUFFIX update method.
	 */
	@IsTest
	private static void shouldSuffixFieldValue()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> records = TST_Factory.insertFoobars(NUMBER_OF_RECORDS);

			PROC_UpdateFields.DTO_Parameters parameters = new PROC_UpdateFields.DTO_Parameters();
			parameters.objectName = SEL_Foobar.OBJECT_NAME;

			PROC_UpdateFields.DTO_Field fieldUpdate = new PROC_UpdateFields.DTO_Field();
			fieldUpdate.name = SEL_Foobar.FIELD_TEXT;
			fieldUpdate.value = TEST_SUFFIX;
			fieldUpdate.updateMethod = PROC_UpdateFields.FieldUpdateMethod.SUFFIX;

			parameters.updateFields.add(fieldUpdate);

			Test.startTest();

			new PROC_UpdateFields(parameters).execute(records);

			Test.stopTest();

			List<Foobar__c> updatedRecords = new SEL_Foobar().getAll();
			for(Foobar__c record : updatedRecords)
			{
				Assert.isTrue(record.Text__c.endsWith(TEST_SUFFIX), MSG_FIELD_NOT_UPDATED);
			}
		}
	}

	/**
	 * @description Tests that the default update method is REPLACE.
	 */
	@IsTest
	private static void shouldDefaultToReplace()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> records = TST_Factory.insertFoobars(NUMBER_OF_RECORDS);

			PROC_UpdateFields.DTO_Parameters parameters = new PROC_UpdateFields.DTO_Parameters();
			parameters.objectName = SEL_Foobar.OBJECT_NAME;

			PROC_UpdateFields.DTO_Field fieldUpdate = new PROC_UpdateFields.DTO_Field();
			fieldUpdate.name = SEL_Foobar.FIELD_TEXT;
			fieldUpdate.value = TEST_REPLACEMENT_VALUE;

			parameters.updateFields.add(fieldUpdate);

			Test.startTest();

			new PROC_UpdateFields(parameters).execute(records);

			Test.stopTest();

			List<Foobar__c> updatedRecords = new SEL_Foobar().getAll();
			for(Foobar__c record : updatedRecords)
			{
				Assert.areEqual(TEST_REPLACEMENT_VALUE, record.Text__c, MSG_FIELD_NOT_UPDATED);
			}
		}
	}

	/**
	 * @description Tests all-or-nothing transaction behavior.
	 */
	@IsTest
	private static void shouldUseAllOrNothingBehavior()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> records = TST_Factory.insertFoobars(NUMBER_OF_RECORDS);

			PROC_UpdateFields.DTO_Parameters parameters = new PROC_UpdateFields.DTO_Parameters();
			parameters.objectName = SEL_Foobar.OBJECT_NAME;
			parameters.allOrNothing = true;

			PROC_UpdateFields.DTO_Field fieldUpdate = new PROC_UpdateFields.DTO_Field();
			fieldUpdate.name = SEL_Foobar.FIELD_TEXT;
			fieldUpdate.value = TEST_REPLACEMENT_VALUE;

			parameters.updateFields.add(fieldUpdate);

			Test.startTest();

			new PROC_UpdateFields(parameters).execute(records);

			Test.stopTest();

			List<Foobar__c> updatedRecords = new SEL_Foobar().getAll();
			for(Foobar__c record : updatedRecords)
			{
				Assert.areEqual(TEST_REPLACEMENT_VALUE, record.Text__c, MSG_FIELD_NOT_UPDATED);
			}
		}
	}

	/**
	 * @description Tests that buildQueryable returns a valid queryable with fields and conditions.
	 */
	@IsTest
	private static void shouldBuildQueryable()
	{
		System.runAs(getTestAdmin())
		{
			PROC_UpdateFields.DTO_Parameters parameters = new PROC_UpdateFields.DTO_Parameters();
			parameters.objectName = SEL_Foobar.OBJECT_NAME;
			parameters.searchConditions = new QRY_Condition.FieldCondition(SEL_Foobar.FIELD_TEXT).notEquals(null);

			PROC_UpdateFields.DTO_Field fieldUpdate = new PROC_UpdateFields.DTO_Field();
			fieldUpdate.name = SEL_Foobar.FIELD_TEXT;
			fieldUpdate.value = TEST_REPLACEMENT_VALUE;

			parameters.updateFields.add(fieldUpdate);

			PROC_UpdateFields processor = new PROC_UpdateFields(parameters);

			Test.startTest();

			IF_Queryable queryable = processor.buildQueryable();

			Test.stopTest();

			Assert.isNotNull(queryable, 'Queryable should not be null');
		}
	}

	/**
	 * @description Tests that `buildQueryable` honours an explicit `AccessLevel.SYSTEM_MODE` on
	 * the parameters by calling `withSystemMode()` on the underlying `QRY_Builder.Builder`. Paired
	 * with `shouldBuildQueryableWithExplicitUserMode` to cover the tri-state (null / SYSTEM_MODE /
	 * USER_MODE) branching in `buildQueryable`.
	 */
	@IsTest
	private static void shouldBuildQueryableWithExplicitSystemMode()
	{
		System.runAs(getTestAdmin())
		{
			PROC_UpdateFields.DTO_Parameters parameters = new PROC_UpdateFields.DTO_Parameters();
			parameters.objectName = SEL_Foobar.OBJECT_NAME;
			parameters.accessLevel = System.AccessLevel.SYSTEM_MODE;

			PROC_UpdateFields.DTO_Field fieldUpdate = new PROC_UpdateFields.DTO_Field();
			fieldUpdate.name = SEL_Foobar.FIELD_TEXT;
			fieldUpdate.value = TEST_REPLACEMENT_VALUE;
			parameters.updateFields.add(fieldUpdate);

			Test.startTest();

			IF_Queryable queryable = new PROC_UpdateFields(parameters).buildQueryable();

			Test.stopTest();

			Assert.isNotNull(queryable, 'Queryable should not be null when SYSTEM_MODE is set explicitly');
		}
	}

	/**
	 * @description Tests that `buildQueryable` honours an explicit `AccessLevel.USER_MODE` on
	 * the parameters by calling `withUserMode()` on the underlying `QRY_Builder.Builder`. Paired
	 * with `shouldBuildQueryableWithExplicitSystemMode` to cover the tri-state branching.
	 */
	@IsTest
	private static void shouldBuildQueryableWithExplicitUserMode()
	{
		System.runAs(getTestAdmin())
		{
			PROC_UpdateFields.DTO_Parameters parameters = new PROC_UpdateFields.DTO_Parameters();
			parameters.objectName = SEL_Foobar.OBJECT_NAME;
			parameters.accessLevel = System.AccessLevel.USER_MODE;

			PROC_UpdateFields.DTO_Field fieldUpdate = new PROC_UpdateFields.DTO_Field();
			fieldUpdate.name = SEL_Foobar.FIELD_TEXT;
			fieldUpdate.value = TEST_REPLACEMENT_VALUE;
			parameters.updateFields.add(fieldUpdate);

			Test.startTest();

			IF_Queryable queryable = new PROC_UpdateFields(parameters).buildQueryable();

			Test.stopTest();

			Assert.isNotNull(queryable, 'Queryable should not be null when USER_MODE is set explicitly');
		}
	}

	/**
	 * @description Tests integration with UTIL_AsynchronousJobLauncher.
	 */
	@IsTest
	private static void shouldWorkWithAsynchronousJobLauncher()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobars(NUMBER_OF_RECORDS);

			PROC_UpdateFields.DTO_Parameters parameters = new PROC_UpdateFields.DTO_Parameters();
			parameters.objectName = SEL_Foobar.OBJECT_NAME;

			PROC_UpdateFields.DTO_Field fieldUpdate = new PROC_UpdateFields.DTO_Field();
			fieldUpdate.name = SEL_Foobar.FIELD_TEXT;
			fieldUpdate.value = TEST_REPLACEMENT_VALUE;

			parameters.updateFields.add(fieldUpdate);

			PROC_UpdateFields processor = new PROC_UpdateFields(parameters);
			IF_Queryable queryable = processor.buildQueryable();

			Test.startTest();

			UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request =
					new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(queryable)
							.withBatchSize(NUMBER_OF_RECORDS);

			UTIL_AsynchronousJobLauncher.process(request, processor);

			Test.stopTest();

			List<Foobar__c> updatedRecords = new SEL_Foobar().getAll();
			for(Foobar__c record : updatedRecords)
			{
				Assert.areEqual(TEST_REPLACEMENT_VALUE, record.Text__c, MSG_FIELD_NOT_UPDATED);
			}
		}
	}

	/**
	 * @description Tests multiple field updates in a single execution.
	 */
	@IsTest
	private static void shouldUpdateMultipleFields()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> records = TST_Factory.insertFoobars(NUMBER_OF_RECORDS);

			PROC_UpdateFields.DTO_Parameters parameters = new PROC_UpdateFields.DTO_Parameters();
			parameters.objectName = SEL_Foobar.OBJECT_NAME;

			PROC_UpdateFields.DTO_Field textFieldUpdate = new PROC_UpdateFields.DTO_Field();
			textFieldUpdate.name = SEL_Foobar.FIELD_TEXT;
			textFieldUpdate.value = TEST_REPLACEMENT_VALUE;

			PROC_UpdateFields.DTO_Field integerFieldUpdate = new PROC_UpdateFields.DTO_Field();
			integerFieldUpdate.name = SEL_Foobar.FIELD_INTEGER;
			integerFieldUpdate.value = 999;

			parameters.updateFields.add(textFieldUpdate);
			parameters.updateFields.add(integerFieldUpdate);

			Test.startTest();

			new PROC_UpdateFields(parameters).execute(records);

			Test.stopTest();

			List<Foobar__c> updatedRecords = new SEL_Foobar().getAll();
			for(Foobar__c record : updatedRecords)
			{
				Assert.areEqual(TEST_REPLACEMENT_VALUE, record.Text__c, 'Text field not updated');
				Assert.areEqual(999, record.NumberInteger__c, 'Integer field not updated');
			}
		}
	}

	/**
	 * @description Explicit SYSTEM_MODE on DTO_Parameters pins the commit to SYSTEM_MODE
	 * regardless of the UserModeDml_Enabled flag. Preserves the admin-mandate behaviour that
	 * UTIL_BulkUpdates relies on.
	 */
	@IsTest
	private static void shouldCommitWithExplicitSystemMode()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> records = TST_Factory.insertFoobars(NUMBER_OF_RECORDS);

			PROC_UpdateFields.DTO_Parameters parameters = new PROC_UpdateFields.DTO_Parameters();
			parameters.objectName = SEL_Foobar.OBJECT_NAME;
			parameters.accessLevel = System.AccessLevel.SYSTEM_MODE;

			PROC_UpdateFields.DTO_Field fieldUpdate = new PROC_UpdateFields.DTO_Field();
			fieldUpdate.name = SEL_Foobar.FIELD_TEXT;
			fieldUpdate.value = TEST_REPLACEMENT_VALUE;
			parameters.updateFields.add(fieldUpdate);

			Test.startTest();

			new PROC_UpdateFields(parameters).execute(records);

			Test.stopTest();

			for(Foobar__c record : new SEL_Foobar().getAll())
			{
				Assert.areEqual(TEST_REPLACEMENT_VALUE, record.Text__c, 'SYSTEM_MODE update should commit');
			}
		}
	}

	/**
	 * @description Explicit USER_MODE on DTO_Parameters honours the caller's secure-by-default
	 * opt-in; the running user (test user with FLS) commits successfully. End-to-end denial for an
	 * FLS-lacking user is exercised by the subscriber-side tests.
	 */
	@IsTest
	private static void shouldCommitWithExplicitUserModeWhenUserHasFls()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> records = TST_Factory.insertFoobars(NUMBER_OF_RECORDS);

			PROC_UpdateFields.DTO_Parameters parameters = new PROC_UpdateFields.DTO_Parameters();
			parameters.objectName = SEL_Foobar.OBJECT_NAME;
			parameters.accessLevel = System.AccessLevel.USER_MODE;

			PROC_UpdateFields.DTO_Field fieldUpdate = new PROC_UpdateFields.DTO_Field();
			fieldUpdate.name = SEL_Foobar.FIELD_TEXT;
			fieldUpdate.value = TEST_REPLACEMENT_VALUE;
			parameters.updateFields.add(fieldUpdate);

			Test.startTest();

			new PROC_UpdateFields(parameters).execute(records);

			Test.stopTest();

			for(Foobar__c record : new SEL_Foobar().getAll())
			{
				Assert.areEqual(TEST_REPLACEMENT_VALUE, record.Text__c, 'USER_MODE update should commit for FLS-endowed user');
			}
		}
	}

	/**
	 * @description Null access level inherits the flag-driven default — an FLS-endowed running
	 * user commits regardless of whether UserModeDml_Enabled resolves to USER_MODE or SYSTEM_MODE.
	 */
	@IsTest
	private static void shouldInheritFlagDrivenDefaultWhenAccessLevelNull()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> records = TST_Factory.insertFoobars(NUMBER_OF_RECORDS);

			PROC_UpdateFields.DTO_Parameters parameters = new PROC_UpdateFields.DTO_Parameters();
			parameters.objectName = SEL_Foobar.OBJECT_NAME;

			PROC_UpdateFields.DTO_Field fieldUpdate = new PROC_UpdateFields.DTO_Field();
			fieldUpdate.name = SEL_Foobar.FIELD_TEXT;
			fieldUpdate.value = TEST_REPLACEMENT_VALUE;
			parameters.updateFields.add(fieldUpdate);

			Test.startTest();

			new PROC_UpdateFields(parameters).execute(records);

			Test.stopTest();

			for(Foobar__c record : new SEL_Foobar().getAll())
			{
				Assert.areEqual(TEST_REPLACEMENT_VALUE, record.Text__c, 'Default-mode update should commit');
			}
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