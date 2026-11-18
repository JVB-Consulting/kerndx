// SPDX-License-Identifier: Apache-2.0
/**
 * @description Unit tests for PROC_UpdateFields processor.
 *
 * @see PROC_UpdateFields
 *
 * @author Jason van Beukering
 *
 * @group Bulk DML
 *
 * @date February 2026, November 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=false)
private class PROC_UpdateFields_TEST
{
	/**
	 * @description Company name given to the admin user created in the test setup. It is unique to this class, so
	 * getTestAdmin can find that one user again by company name.
	 */
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
	private static final String MSG_FIELD_NOT_UPDATED = 'Expected the field of every test row to be updated';

	/**
	 * @description The access level of each update of test records that reached the database layer, in the order the
	 * updates ran. AccessLevelRecordingProxy adds to it.
	 */
	private static final List<AccessLevel> RECORDED_ACCESS_LEVELS = new List<AccessLevel>();

	/**
	 * @description The test records handed to each update, in the order the updates ran. SavedRecordsRecordingProxy
	 * adds to it.
	 */
	private static final List<SObject> RECORDED_SAVED_RECORDS = new List<SObject>();

	/**
	 * @description The start of the name of the permission set that lets a test user read the field a copy reads from,
	 * but not edit it. A random part follows, so the name is unique.
	 */
	private static final String READ_ONLY_SOURCE_PERMISSION_SET_PREFIX = 'ReadOnlyCopySource';

	/**
	 * @description The length of the random part of the permission set name.
	 */
	private static final Integer PERMISSION_SET_NAME_RANDOM_LENGTH = 12;

	/**
	 * @description Empty text, for a read of the text field that adds nothing before or after each value.
	 */
	private static final String NO_TEXT = '';

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

			Assert.areEqual(repeatForEveryRow(TEST_REPLACEMENT_VALUE), findTextValues(), MSG_FIELD_NOT_UPDATED);
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

			Assert.areEqual(repeatForEveryRow(TEST_REPLACEMENT_VALUE), findTextValues(), MSG_FIELD_NOT_UPDATED);
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

			Assert.areEqual(repeatForEveryRow(TEST_REPLACEMENT_VALUE), findTextValues(), MSG_FIELD_NOT_UPDATED);
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
	 * with `shouldBuildQueryableWithExplicitUserMode` to cover both ways `buildQueryable` applies the access level.
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
	 * the parameters by handing it to `withAccessLevelInternal` on the underlying `QRY_Builder.Builder`. Paired
	 * with `shouldBuildQueryableWithExplicitSystemMode` to cover both ways the access level is applied.
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

			Assert.areEqual(repeatForEveryRow(TEST_REPLACEMENT_VALUE), findTextValues(), MSG_FIELD_NOT_UPDATED);
		}
	}

	/**
	 * @description Proves that a queued job finds and updates every row when its caller gave an access level. The query
	 * is built before the job is queued. The job runs as a batch, so the batch job's start step runs the query on a
	 * builder the platform rebuilt, and the access level inside it is a new object. The query and the save must both
	 * work with that rebuilt level.
	 */
	@IsTest
	private static void queuedJobShouldUpdateEveryRowWithAGivenAccessLevel()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobars(NUMBER_OF_RECORDS);
			PROC_UpdateFields processor = new PROC_UpdateFields(newTextReplacement(AccessLevel.USER_MODE));
			IF_Queryable queryable = processor.buildQueryable();

			Test.startTest();
			UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request =
					new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(queryable)
							.withBatchSize(NUMBER_OF_RECORDS)
							.withExecutionStrategy(IF_Async.AsynchronousExecutionStrategy.BATCH);
			UTIL_AsynchronousJobLauncher.process(request, processor);
			Test.stopTest();

			Assert.areEqual(repeatForEveryRow(TEST_REPLACEMENT_VALUE), findTextValues(), MSG_FIELD_NOT_UPDATED);
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
	 * @description Explicit SYSTEM_MODE on DTO_Parameters forces the commit to SYSTEM_MODE
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

			Assert.areEqual(repeatForEveryRow(TEST_REPLACEMENT_VALUE), findTextValues(), 'Expected the update in system mode to be saved');
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

			Assert.areEqual(repeatForEveryRow(TEST_REPLACEMENT_VALUE), findTextValues(), 'Expected the update in user mode to be saved for a user who may edit the field');
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

			Assert.areEqual(repeatForEveryRow(TEST_REPLACEMENT_VALUE), findTextValues(), 'Expected the update with the default access level to be saved');
		}
	}

	/**
	 * @description For a copy, the query that finds the rows also reads the source field, so each row has the value to
	 * copy. Without it, the copy would have nothing to read.
	 */
	@IsTest
	private static void shouldQueryTheSourceField()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobars(NUMBER_OF_RECORDS);

			PROC_UpdateFields.DTO_Parameters parameters = new PROC_UpdateFields.DTO_Parameters();
			parameters.objectName = SEL_Foobar.OBJECT_NAME;

			PROC_UpdateFields.DTO_Field fieldUpdate = new PROC_UpdateFields.DTO_Field();
			fieldUpdate.name = UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Text__c);
			fieldUpdate.value = UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Email__c);
			fieldUpdate.updateMethod = PROC_UpdateFields.FieldUpdateMethod.COPY_FROM_FIELD;
			parameters.updateFields.add(fieldUpdate);

			Test.startTest();

			List<SObject> foundRecords = new PROC_UpdateFields(parameters).buildQueryable().toList();

			Test.stopTest();

			Assert.areEqual(NUMBER_OF_RECORDS, foundRecords.size(), 'Expected the query to find every test row');
			for(SObject foundRecord : foundRecords)
			{
				Assert.isTrue
						(
								foundRecord.getPopulatedFieldsAsMap().containsKey(UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Email__c)),
								'Expected the query to read the source field'
						);
			}
		}
	}

	/**
	 * @description A user who can read the field a copy reads from, but cannot edit it, can still copy it into a field
	 * they can edit. The save holds only the field the copy sets. The rows are found and saved as that user, in user
	 * mode.
	 */
	@IsTest
	private static void shouldCopyAFieldTheUserCanReadButNotEdit()
	{
		User copyingUser = insertUserWhoCanReadButNotEditTheCopySource();
		// Salesforce saves the domain of an email address in lower case, so the value is lower case from the start.
		String sourceValue = UTIL_Random.randomEmail().toLowerCase();
		System.runAs(getTestAdmin())
		{
			TST_Builder.of(Foobar__c.SObjectType)
					.withCount(NUMBER_OF_RECORDS)
					.withOverride(Foobar__c.OwnerId, copyingUser.Id)
					.withOverride(Foobar__c.Email__c, sourceValue)
					.buildList();
		}

		Test.startTest();
		System.runAs(copyingUser)
		{
			// A plain describe here, not the cached one, so it reflects this user's access and not the access of the
			// user who first asked for it.
			DescribeFieldResult sourceDescribe = Foobar__c.Email__c.getDescribe();
			Assert.isTrue(sourceDescribe.isAccessible(), 'Expected the user to be able to read the source field');
			Assert.isFalse(sourceDescribe.isUpdateable(), 'Expected the user not to be able to edit the source field');

			PROC_UpdateFields.DTO_Parameters parameters = newCopyFromEmailToText();
			parameters.accessLevel = AccessLevel.USER_MODE;
			PROC_UpdateFields processor = new PROC_UpdateFields(parameters);
			processor.execute(processor.buildQueryable().toList());
		}
		Test.stopTest();

		System.runAs(getTestAdmin())
		{
			Assert.areEqual(repeatForEveryRow(sourceValue), findTextValues(), 'Expected the source value to be copied into the target field');
		}
	}

	/**
	 * @description The save receives, for each row, a record that holds only its Id and the field the update sets. The
	 * field a copy reads from was read with the row, but it is not handed to the save.
	 */
	@IsTest
	private static void shouldSaveOnlyTheIdAndTheFieldItSets()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobars(NUMBER_OF_RECORDS);
			PROC_UpdateFields processor = new PROC_UpdateFields(newCopyFromEmailToText());
			List<SObject> readRecords = processor.buildQueryable().toList();
			DML_SharingProxy.sharingProxyForTest = new SavedRecordsRecordingProxy();

			try
			{
				Test.startTest();
				processor.execute(readRecords);
				Test.stopTest();
			}
			finally
			{
				DML_SharingProxy.sharingProxyForTest = null;
			}

			Set<String> expectedFieldNames = new Set<String>
			{
					UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Id),
					UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Text__c)
			};
			Assert.areEqual(NUMBER_OF_RECORDS, RECORDED_SAVED_RECORDS.size(), 'Expected one saved record for each test row');
			for(SObject savedRecord : RECORDED_SAVED_RECORDS)
			{
				Assert.areEqual(expectedFieldNames, savedRecord.getPopulatedFieldsAsMap().keySet(), 'Expected the save to hold only the Id and the target field');
			}
		}
	}

	/**
	 * @description A prefix and then a suffix on the same field build on each other: the suffix is added to the value
	 * the prefix gave, so the saved value has both around the old value.
	 */
	@IsTest
	private static void shouldComposeAPrefixAndASuffixOnOneField()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobars(NUMBER_OF_RECORDS);
			Map<Id, String> expectedTextById = findTextValueById(TEST_PREFIX, TEST_SUFFIX);

			PROC_UpdateFields.DTO_Parameters parameters = new PROC_UpdateFields.DTO_Parameters();
			parameters.objectName = SEL_Foobar.OBJECT_NAME;

			PROC_UpdateFields.DTO_Field prefixUpdate = new PROC_UpdateFields.DTO_Field();
			prefixUpdate.name = SEL_Foobar.FIELD_TEXT;
			prefixUpdate.value = TEST_PREFIX;
			prefixUpdate.updateMethod = PROC_UpdateFields.FieldUpdateMethod.PREFIX;
			parameters.updateFields.add(prefixUpdate);

			PROC_UpdateFields.DTO_Field suffixUpdate = new PROC_UpdateFields.DTO_Field();
			suffixUpdate.name = SEL_Foobar.FIELD_TEXT;
			suffixUpdate.value = TEST_SUFFIX;
			suffixUpdate.updateMethod = PROC_UpdateFields.FieldUpdateMethod.SUFFIX;
			parameters.updateFields.add(suffixUpdate);

			PROC_UpdateFields processor = new PROC_UpdateFields(parameters);

			Test.startTest();
			processor.execute(processor.buildQueryable().toList());
			Test.stopTest();

			Assert.areEqual(NUMBER_OF_RECORDS, expectedTextById.size(), 'Expected every test row to be found');
			Assert.areEqual(expectedTextById, findTextValueById(NO_TEXT, NO_TEXT), 'Expected the prefix and the suffix around the old value');
		}
	}

	/**
	 * @description The updates run in the order of the list, also when a copy reads a field that a later update changes.
	 * The copy reads the old value of the source field first. Then the later update replaces the source field. Both
	 * fields are saved.
	 */
	@IsTest
	private static void shouldCopyTheOldValueWhenALaterUpdateChangesTheSource()
	{
		System.runAs(getTestAdmin())
		{
			// Salesforce saves the domain of an email address in lower case, so the values are lower case from the start.
			String oldEmail = UTIL_Random.randomEmail().toLowerCase();
			String newEmail = UTIL_Random.randomEmail().toLowerCase();
			TST_Builder.of(Foobar__c.SObjectType)
					.withCount(NUMBER_OF_RECORDS)
					.withOverride(Foobar__c.Email__c, oldEmail)
					.buildList();

			PROC_UpdateFields.DTO_Parameters parameters = newCopyFromEmailToText();
			PROC_UpdateFields.DTO_Field emailUpdate = new PROC_UpdateFields.DTO_Field();
			emailUpdate.name = UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Email__c);
			emailUpdate.value = newEmail;
			parameters.updateFields.add(emailUpdate);
			PROC_UpdateFields processor = new PROC_UpdateFields(parameters);

			Test.startTest();
			processor.execute(processor.buildQueryable().toList());
			Test.stopTest();

			Assert.areEqual(repeatForEveryRow(oldEmail), findTextValues(), 'Expected the copy to read the source value from before the later update');
			List<String> savedEmails = new List<String>();
			for(Foobar__c record : new SEL_Foobar().getAll())
			{
				savedEmails.add(record.Email__c);
			}
			Assert.areEqual(repeatForEveryRow(newEmail), savedEmails, 'Expected the later update of the source field to be saved');
		}
	}

	/**
	 * @description A direct call to execute does not need the object name. It saves the records it is given. Only
	 * buildQueryable uses the object name, to find the records.
	 */
	@IsTest
	private static void shouldSaveRecordsGivenDirectlyWithoutAnObjectName()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> records = TST_Factory.insertFoobars(NUMBER_OF_RECORDS);
			PROC_UpdateFields.DTO_Parameters parameters = newTextReplacement(null);
			parameters.objectName = null;

			Test.startTest();
			new PROC_UpdateFields(parameters).execute(records);
			Test.stopTest();

			Assert.areEqual(repeatForEveryRow(TEST_REPLACEMENT_VALUE), findTextValues(), 'Expected the records to be saved without an object name');
		}
	}

	/**
	 * @description Proves that a queued job saves with the access level its caller gave, as it is. The platform saves
	 * the job when it is queued and rebuilds it when it runs, so the level inside the job is a new object that still
	 * means user mode. The save must receive that same rebuilt object. A processor that picked a mode again from the
	 * level would hand the save the shared AccessLevel.USER_MODE value instead. A user mode level that names a
	 * permission set matches neither mode, so only this path keeps it. An org without the ApexUserModeWithPermset
	 * scratch-org feature cannot build such a level, so the test uses the rebuilt user mode level to prove the path.
	 */
	@IsTest
	private static void queuedJobShouldSaveWithTheAccessLevelItCarried()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> records = TST_Factory.insertFoobars(NUMBER_OF_RECORDS);
			PROC_UpdateFields processor = new PROC_UpdateFields(newTextReplacement(AccessLevel.USER_MODE));
			DML_SharingProxy.sharingProxyForTest = new AccessLevelRecordingProxy();

			try
			{
				Test.startTest();
				UTIL_AsynchronousJobLauncher.process(records, processor);
				Test.stopTest();

				Assert.areEqual(1, RECORDED_ACCESS_LEVELS.size(), 'Expected one update of the test records');
				AccessLevel savedWith = RECORDED_ACCESS_LEVELS[0];
				Assert.isFalse(savedWith === AccessLevel.USER_MODE, 'Expected the rebuilt level the job carried, not the shared user mode value');
				Assert.isTrue(DML_SharingProxy.matchesAccessLevel(savedWith, AccessLevel.USER_MODE), 'Expected the carried level to still mean user mode');
				Assert.areEqual(repeatForEveryRow(TEST_REPLACEMENT_VALUE), findTextValues(), MSG_FIELD_NOT_UPDATED);
			}
			finally
			{
				DML_SharingProxy.sharingProxyForTest = null;
			}
		}
	}

	/**
	 * @description Proves that the query that finds the rows runs with the access level the caller gave, as it is. The
	 * query keeps the very object it was given, so a user mode level that names a permission set reaches the database
	 * with its permission set. A processor that picked a mode again from the level would leave the query to run with
	 * the shared user mode value, and the permission set would be lost.
	 */
	@IsTest
	private static void buildQueryableShouldQueryWithTheAccessLevelItWasGiven()
	{
		System.runAs(getTestAdmin())
		{
			PROC_UpdateFields.DTO_Parameters parameters = newTextReplacement(AccessLevel.USER_MODE);

			Test.startTest();
			QRY_Builder.Builder query = (QRY_Builder.Builder)new PROC_UpdateFields(parameters).buildQueryable();
			QRY_Engine.QueryParameters queryParameters = query.buildParameters(new QRY_BindRegistry());
			Test.stopTest();

			Assert.isTrue(queryParameters.userMode, 'Expected the query to run in user mode');
			Assert.isTrue(parameters.accessLevel === queryParameters.exactAccessLevel, 'Expected the query to run with the very level the caller gave');
		}
	}

	/**
	 * @description An explicit system mode still writes a bypass audit entry on both sides: one for the query that finds
	 * the rows and one for the save. The bypass audit is the log of each time code skips the user's object and field
	 * permissions, so system mode must never be passed on without it.
	 */
	@IsTest
	private static void shouldStillAuditAnExplicitSystemMode()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> records = TST_Factory.insertFoobars(NUMBER_OF_RECORDS);
			PROC_UpdateFields processor = new PROC_UpdateFields(newTextReplacement(AccessLevel.SYSTEM_MODE));
			holdAuditEntriesInMemory();

			Test.startTest();
			processor.buildQueryable().toList();
			processor.execute(records);
			Test.stopTest();

			String foobarSystemModeTarget = UTIL_BypassAudit.TARGET_SYSTEM_MODE + ':' + String.valueOf(Foobar__c.SObjectType);
			Assert.isFalse(UTIL_BypassAudit_TEST.findBufferedBypassEntries(UTIL_BypassAudit.SURFACE_QUERY, foobarSystemModeTarget).isEmpty(),
					'Expected the query in system mode to write a bypass audit entry for the test object');
			Assert.isFalse(UTIL_BypassAudit_TEST.findBufferedBypassEntries(UTIL_BypassAudit.SURFACE_DML, foobarSystemModeTarget).isEmpty(),
					'Expected the save in system mode to write a bypass audit entry for the test object');
		}
	}

	/**
	 * @description Builds parameters that replace the text field of every test record with TEST_REPLACEMENT_VALUE.
	 *
	 * @param accessLevel The access level for the query and the save.
	 *
	 * @return The parameters.
	 */
	private static PROC_UpdateFields.DTO_Parameters newTextReplacement(AccessLevel accessLevel)
	{
		PROC_UpdateFields.DTO_Parameters parameters = new PROC_UpdateFields.DTO_Parameters();
		parameters.objectName = SEL_Foobar.OBJECT_NAME;
		parameters.accessLevel = accessLevel;

		PROC_UpdateFields.DTO_Field fieldUpdate = new PROC_UpdateFields.DTO_Field();
		fieldUpdate.name = SEL_Foobar.FIELD_TEXT;
		fieldUpdate.value = TEST_REPLACEMENT_VALUE;
		parameters.updateFields.add(fieldUpdate);
		return parameters;
	}

	/**
	 * @description Builds the list of text values the test rows hold when every row holds the same value: the value once
	 * for each test row.
	 *
	 * @param value The value every row holds.
	 *
	 * @return The value, once for each test row.
	 */
	private static List<String> repeatForEveryRow(String value)
	{
		List<String> values = new List<String>();
		for(Integer index = 0; index < NUMBER_OF_RECORDS; index++)
		{
			values.add(value);
		}
		return values;
	}

	/**
	 * @description Reads every test row and returns the value of its text field.
	 *
	 * @return The text field value of each row.
	 */
	private static List<String> findTextValues()
	{
		return findTextValueById(NO_TEXT, NO_TEXT).values();
	}

	/**
	 * @description Reads every test row and returns its text field value by row Id, with the given text added before
	 * and after each value.
	 *
	 * @param textBefore The text to add before each value.
	 * @param textAfter The text to add after each value.
	 *
	 * @return The text field value of each row, with the added text, by row Id.
	 */
	private static Map<Id, String> findTextValueById(String textBefore, String textAfter)
	{
		Map<Id, String> textValueById = new Map<Id, String>();
		for(Foobar__c record : new SEL_Foobar().getAll())
		{
			textValueById.put(record.Id, textBefore + record.Text__c + textAfter);
		}
		return textValueById;
	}

	/**
	 * @description Builds parameters that copy the email field of every test record into its text field.
	 *
	 * @return The parameters, with no access level set.
	 */
	private static PROC_UpdateFields.DTO_Parameters newCopyFromEmailToText()
	{
		PROC_UpdateFields.DTO_Parameters parameters = new PROC_UpdateFields.DTO_Parameters();
		parameters.objectName = SEL_Foobar.OBJECT_NAME;

		PROC_UpdateFields.DTO_Field fieldUpdate = new PROC_UpdateFields.DTO_Field();
		fieldUpdate.name = UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Text__c);
		fieldUpdate.value = UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Email__c);
		fieldUpdate.updateMethod = PROC_UpdateFields.FieldUpdateMethod.COPY_FROM_FIELD;
		parameters.updateFields.add(fieldUpdate);
		return parameters;
	}

	/**
	 * @description Saves a user on the minimum access profile who can read and edit test records and their fields,
	 * except the email field, which the user can read but not edit. One permission set gives read and edit on every
	 * field but the email field. A second one, made here, gives read only on the email field.
	 *
	 * @return The saved user, with both permission sets assigned.
	 */
	private static User insertUserWhoCanReadButNotEditTheCopySource()
	{
		User copyingUser = TST_Factory.insertUserWithOneHiddenField
				(
						SEL_Profile.PROFILE_MINIMUM_ACCESS,
						new List<SObjectType> {Foobar__c.SObjectType},
						new List<SObjectField> {ObjectPermissions.PermissionsRead, ObjectPermissions.PermissionsEdit},
						Foobar__c.Email__c
				);

		// FieldPermissions has a field named SobjectType, so the type token comes from an instance.
		SObjectType fieldPermissionsType = new FieldPermissions().getSObjectType();
		String objectName = UTIL_SObjectDescribe.getObjectNameFromType(Foobar__c.SObjectType);
		String permissionSetName = READ_ONLY_SOURCE_PERMISSION_SET_PREFIX + UTIL_Random.randomAlphanumeric(PERMISSION_SET_NAME_RANDOM_LENGTH);
		PermissionSet readOnlySource;

		// Setup records are saved as the current user in their own block, so the test can save ordinary records after them.
		System.runAs(new User(Id = UserInfo.getUserId()))
		{
			readOnlySource = (PermissionSet)TST_Builder.of(PermissionSet.SObjectType)
					.withOptionalFields(new List<String>(UTIL_SObjectDescribe.getDescribe(PermissionSet.SObjectType).getCreatableRequiredFields()))
					.withOverride(PermissionSet.Name, permissionSetName)
					.withOverride(PermissionSet.Label, permissionSetName)
					.build();

			TST_Builder.of(fieldPermissionsType)
					.withOptionalFields(new List<String>(UTIL_SObjectDescribe.getDescribe(fieldPermissionsType).getCreatableRequiredFields()))
					.withOverride(FieldPermissions.ParentId, readOnlySource.Id)
					.withOverride(FieldPermissions.SobjectType, objectName)
					.withOverride(FieldPermissions.Field, objectName + '.' + UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Email__c))
					.withOverride(FieldPermissions.PermissionsRead, true)
					.withOverride(FieldPermissions.PermissionsEdit, false)
					.build();
		}

		TST_Factory.createPermissionSetAssignments(new List<User> {copyingUser}, readOnlySource.Id);
		return copyingUser;
	}

	/**
	 * @description Turns logging on for the bypass audit test and keeps the entries in memory instead of saving them,
	 * so the test can read them from the audit buffer.
	 */
	private static void holdAuditEntriesInMemory()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();
		LOG_Builder.suspendSaving();
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

	/**
	 * @description A database layer for tests that writes down the access level of every update of test records, then
	 * saves the records for real. Statements on any other object, such as the framework's own log rows, are not
	 * written down.
	 */
	@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
	private inherited sharing class AccessLevelRecordingProxy extends DML_SharingProxy.DatabaseProxy
	{
		/**
		 * @description Writes down the access level of an update of test records, then saves the records.
		 *
		 * @param records The records to update.
		 * @param allOrNothing Whether the statement is all-or-nothing.
		 * @param accessLevel The access level the save received.
		 *
		 * @return The results of the real update.
		 */
		public override List<Database.SaveResult> doUpdate(List<SObject> records, Boolean allOrNothing, AccessLevel accessLevel)
		{
			if(DML_ThrowingLockProxy_TEST.isTestObjectStatement(records))
			{
				RECORDED_ACCESS_LEVELS.add(accessLevel);
			}
			return super.doUpdate(records, allOrNothing, accessLevel);
		}
	}

	/**
	 * @description A database layer for tests that writes down every test record handed to an update, then saves the
	 * records for real. Statements on any other object, such as the framework's own log rows, are not written down.
	 */
	@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
	private inherited sharing class SavedRecordsRecordingProxy extends DML_SharingProxy.DatabaseProxy
	{
		/**
		 * @description Writes down the test records of an update, then saves them.
		 *
		 * @param records The records to update.
		 * @param allOrNothing Whether the statement is all-or-nothing.
		 * @param accessLevel The access level the save received.
		 *
		 * @return The results of the real update.
		 */
		public override List<Database.SaveResult> doUpdate(List<SObject> records, Boolean allOrNothing, AccessLevel accessLevel)
		{
			if(DML_ThrowingLockProxy_TEST.isTestObjectStatement(records))
			{
				RECORDED_SAVED_RECORDS.addAll(records);
			}
			return super.doUpdate(records, allOrNothing, accessLevel);
		}
	}
}