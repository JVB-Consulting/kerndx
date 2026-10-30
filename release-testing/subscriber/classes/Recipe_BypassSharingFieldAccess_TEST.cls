// SPDX-License-Identifier: Apache-2.0
/**
 * @description Proof, from a class outside the package, that bypassSharing() ignores record sharing and nothing else.
 * Record sharing decides which records a user may see. Field permissions decide which fields of a record the user may
 * read or edit.
 *
 * Each test gives a Standard User a permission set made only for the test. It lets the user read and edit Foobar
 * records and their Text field, but not their Email field. An administrator owns the record, and Foobar records are
 * private, so the user cannot see the record without the bypass. The tests run with the package's default settings,
 * where queries and saves run in user mode (with the user's own permissions).
 *
 * The tests show that:
 * - a read with bypassSharing() finds the record, without the Email field;
 * - a cursor with bypassSharing() alone is refused, because the fields of the rows it fetches later cannot be removed;
 * - a filter on the Email field with bypassSharing() alone is refused, because the result would show its values;
 * - a save with bypassSharing(), and a commit with commitWork(false), save the Text field and leave out the Email field.
 *
 * @see kern.QRY_Builder
 * @see kern.DML_Builder
 * @see kern.DML_Transaction
 * @see kern.TST_Builder
 * @see kern.TST_Factory
 * @see kern.UTIL_Exceptions
 *
 * @author your.name@company.com
 *
 * @group Security
 *
 * @date October 2026
 */
@IsTest(seeAllData=false isParallel=false)
private class Recipe_BypassSharingFieldAccess_TEST
{
	/**
	 * @description The profile of the user who reads and saves. It gives no access to Foobar records, so the test's
	 * permission set decides what the user has.
	 */
	private static final String PROFILE_STANDARD_USER = 'Standard User';

	/**
	 * @description The start of the name of the permission set each test makes. A random ending follows it.
	 */
	private static final String PERMISSION_SET_PREFIX = 'BypassSharingProof';

	/**
	 * @description How many random letters and digits end the name of the permission set each test makes.
	 */
	private static final Integer PERMISSION_SET_RANDOM_LENGTH = 12;

	/**
	 * @description The Email value the administrator saves on the record.
	 */
	private static final String ORIGINAL_EMAIL = 'owner@example.com';

	/**
	 * @description The Email value the user tries to save. The user cannot edit the Email field, so it is left out.
	 */
	private static final String CHANGED_EMAIL = 'reader@example.com';

	/**
	 * @description The Text value the user saves. The user can edit the Text field, so it is saved.
	 */
	private static final String CHANGED_TEXT = 'Saved by the reader';

	/**
	 * @description A read with bypassSharing() finds a record that record sharing hides from the user. The Email field,
	 * which the user cannot read, is removed from the row. The Text field, which the user can read, is kept.
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	@IsTest
	private static void shouldReadAHiddenRecordWithoutTheFieldTheUserCannotRead()
	{
		User reader = insertReaderWithoutEmailAccess();
		kern__Foobar__c hiddenRecord = insertRecordOwnedByTheAdministrator();
		List<kern__Foobar__c> rows;

		Test.startTest();
		System.runAs(reader)
		{
			assertTheUserCannotSeeTheRecordOrItsEmail(hiddenRecord.Id);
			rows = (List<kern__Foobar__c>)selectRecordBypassingSharing(hiddenRecord.Id).toList();
		}
		Test.stopTest();

		Assert.areEqual(1, rows.size(), 'Expected bypassSharing() to find the record that sharing hides, got ' + rows.size());
		Assert.areEqual(hiddenRecord.Id, rows[0].Id, 'Expected bypassSharing() to return the hidden record');
		Assert.isTrue(rows[0].isSet(kern__Foobar__c.kern__Text__c), 'Expected the Text field, which the user can read, to be kept');
		Assert.isFalse(rows[0].isSet(kern__Foobar__c.kern__Email__c), 'Expected the Email field, which the user cannot read, to be removed');
	}

	/**
	 * @description A cursor with bypassSharing() alone is refused before any query runs. The rows of a cursor are
	 * fetched later, so the fields the user cannot read could not be removed from them.
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	@IsTest
	private static void shouldRefuseACursorWithBypassSharingAlone()
	{
		User reader = insertReaderWithoutEmailAccess();
		kern__Foobar__c hiddenRecord = insertRecordOwnedByTheAdministrator();
		Exception refusal;

		Test.startTest();
		System.runAs(reader)
		{
			try
			{
				selectRecordBypassingSharing(hiddenRecord.Id).toCursor();
				Assert.fail('Expected a cursor with bypassSharing() alone to be refused');
			}
			catch(Exception error)
			{
				refusal = error;
			}
		}
		Test.stopTest();

		Assert.isInstanceOfType(refusal, kern.UTIL_Exceptions.IllegalStateException.class, 'Expected the cursor to be refused');
	}

	/**
	 * @description A filter on the Email field with bypassSharing() alone is refused before any query runs. The user
	 * cannot read that field, and the rows the filter lets through would show its values.
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	@IsTest
	private static void shouldRefuseAFilterOnAFieldTheUserCannotRead()
	{
		User reader = insertReaderWithoutEmailAccess();
		insertRecordOwnedByTheAdministrator();
		Exception refusal;

		Test.startTest();
		System.runAs(reader)
		{
			try
			{
				kern.QRY_Builder.selectFrom(kern__Foobar__c.SObjectType)
						.condition(kern__Foobar__c.kern__Email__c).equals(ORIGINAL_EMAIL)
						.bypassSharing()
						.toList();
				Assert.fail('Expected a filter on a field the user cannot read to be refused');
			}
			catch(Exception error)
			{
				refusal = error;
			}
		}
		Test.stopTest();

		Assert.isInstanceOfType(refusal, kern.UTIL_Exceptions.IllegalStateException.class, 'Expected the filter to be refused');
	}

	/**
	 * @description A save with bypassSharing() updates a record that record sharing hides from the user. The Text
	 * field, which the user can edit, is saved. The Email field, which the user cannot edit, is left out of the save.
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	@IsTest
	private static void shouldSaveAHiddenRecordWithoutTheFieldTheUserCannotEdit()
	{
		User reader = insertReaderWithoutEmailAccess();
		kern__Foobar__c hiddenRecord = insertRecordOwnedByTheAdministrator();
		kern.DML_Builder.TransactionResult result;

		Test.startTest();
		System.runAs(reader)
		{
			result = kern.DML_Builder.newTransaction().doUpdate(newChange(hiddenRecord.Id)).bypassSharing().execute();
		}
		Test.stopTest();

		Assert.isTrue(result.isSuccess(), 'Expected the save with bypassSharing() to succeed, got ' + result.getErrors());
		assertTextSavedAndEmailLeftOut(hiddenRecord.Id);
	}

	/**
	 * @description commitWork(false) on a transaction updates a record that record sharing hides from the user. The
	 * Text field, which the user can edit, is saved. The Email field, which the user cannot edit, is left out.
	 */
	@IsTest
	private static void shouldCommitAHiddenRecordWithoutTheFieldTheUserCannotEdit()
	{
		User reader = insertReaderWithoutEmailAccess();
		kern__Foobar__c hiddenRecord = insertRecordOwnedByTheAdministrator();

		Test.startTest();
		System.runAs(reader)
		{
			kern.DML_Transaction changes = new kern.DML_Transaction();
			changes.doUpdate(newChange(hiddenRecord.Id));
			changes.commitWork(false);
		}
		Test.stopTest();

		assertTextSavedAndEmailLeftOut(hiddenRecord.Id);
	}

	/**
	 * @description Builds a read of one record, by its Id, that selects the Name, Text and Email fields and ignores
	 * record sharing.
	 *
	 * @param recordId The Id of the record to read.
	 *
	 * @return The read, ready to run.
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	private static kern.QRY_Builder.Builder selectRecordBypassingSharing(Id recordId)
	{
		return kern.QRY_Builder.selectFrom(kern__Foobar__c.SObjectType)
				.fields(new List<SObjectField> {kern__Foobar__c.Name, kern__Foobar__c.kern__Text__c, kern__Foobar__c.kern__Email__c})
				.condition(kern__Foobar__c.Id).equals(recordId)
				.bypassSharing();
	}

	/**
	 * @description Checks that the test is set up as it needs to be, so that a failure later points at the framework
	 * and not at the org. Without the bypass the user finds no record, and the user cannot read the Email field.
	 *
	 * @param recordId The Id of the record the administrator owns.
	 */
	private static void assertTheUserCannotSeeTheRecordOrItsEmail(Id recordId)
	{
		Integer visibleRecords = kern.QRY_Builder.selectFrom(kern__Foobar__c.SObjectType).condition(kern__Foobar__c.Id).equals(recordId).count();
		Assert.areEqual(0, visibleRecords, 'Expected record sharing to hide the record from the user; check that Foobar records are private');
		Assert.isFalse(kern__Foobar__c.kern__Email__c.getDescribe().isAccessible(), 'Expected the user to have no read access to the Email field');
	}

	/**
	 * @description Builds the change the user tries to save: new Text and Email values for the record.
	 *
	 * @param recordId The Id of the record to change.
	 *
	 * @return The unsaved change.
	 */
	private static kern__Foobar__c newChange(Id recordId)
	{
		return (kern__Foobar__c)kern.TST_Builder.of(kern__Foobar__c.SObjectType)
				.withOverride(kern__Foobar__c.Id, recordId)
				.withOverride(kern__Foobar__c.kern__Text__c, CHANGED_TEXT)
				.withOverride(kern__Foobar__c.kern__Email__c, CHANGED_EMAIL)
				.withoutInsertion()
				.build();
	}

	/**
	 * @description Reads the record back as the administrator, with no checks, and checks that the user's Text value
	 * was saved and the owner's Email value was kept.
	 *
	 * @param recordId The Id of the record the user changed.
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	private static void assertTextSavedAndEmailLeftOut(Id recordId)
	{
		kern__Foobar__c saved = (kern__Foobar__c)kern.QRY_Builder.selectFrom(kern__Foobar__c.SObjectType)
				.fields(new List<SObjectField> {kern__Foobar__c.kern__Text__c, kern__Foobar__c.kern__Email__c})
				.condition(kern__Foobar__c.Id).equals(recordId)
				.withSystemMode()
				.getFirst();

		Assert.areEqual(CHANGED_TEXT, saved.kern__Text__c, 'Expected the Text field, which the user can edit, to be saved');
		Assert.areEqual(ORIGINAL_EMAIL, saved.kern__Email__c, 'Expected the Email field, which the user cannot edit, to be left out of the save');
	}

	/**
	 * @description Saves, as the administrator, a Foobar record with a known Email value. Foobar records are
	 * private, so only the administrator can see it.
	 *
	 * @return The saved record.
	 */
	private static kern__Foobar__c insertRecordOwnedByTheAdministrator()
	{
		return (kern__Foobar__c)kern.TST_Builder.of(kern__Foobar__c.SObjectType)
				.withOverride(kern__Foobar__c.Name, kern.UTIL_Random.randomName())
				.withOverride(kern__Foobar__c.kern__Email__c, ORIGINAL_EMAIL)
				.build();
	}

	/**
	 * @description Saves a Standard User and a permission set made only for this test, and assigns it. The permission
	 * set lets the user read and edit Foobar records and their Text field. It gives nothing on the Email field, and no
	 * View All or Modify All, so record sharing still applies. The setup records are saved as the running
	 * administrator inside System.runAs, so the test can also save the Foobar record in the same test.
	 *
	 * @return The saved user, with the permission set assigned.
	 */
	private static User insertReaderWithoutEmailAccess()
	{
		User reader;
		System.runAs(new User(Id = UserInfo.getUserId()))
		{
			String permissionSetName = PERMISSION_SET_PREFIX + kern.UTIL_Random.randomAlphanumeric(PERMISSION_SET_RANDOM_LENGTH);
			PermissionSet permissionSet = (PermissionSet)insertWithOnlyTheseValues(PermissionSet.SObjectType, new Map<SObjectField, Object>
			{
					PermissionSet.Name => permissionSetName,
					PermissionSet.Label => permissionSetName
			});

			// ObjectPermissions and FieldPermissions each have a field named SobjectType, so their type tokens come from instances.
			insertWithOnlyTheseValues(new ObjectPermissions().getSObjectType(), new Map<SObjectField, Object>
			{
					ObjectPermissions.ParentId => permissionSet.Id,
					ObjectPermissions.SobjectType => String.valueOf(kern__Foobar__c.SObjectType),
					ObjectPermissions.PermissionsRead => true,
					ObjectPermissions.PermissionsEdit => true
			});
			insertWithOnlyTheseValues(new FieldPermissions().getSObjectType(), new Map<SObjectField, Object>
			{
					FieldPermissions.ParentId => permissionSet.Id,
					FieldPermissions.SobjectType => String.valueOf(kern__Foobar__c.SObjectType),
					FieldPermissions.Field => String.valueOf(kern__Foobar__c.SObjectType) + '.' + String.valueOf(kern__Foobar__c.kern__Text__c),
					FieldPermissions.PermissionsRead => true,
					FieldPermissions.PermissionsEdit => true
			});

			reader = kern.TST_Factory.insertUser(PROFILE_STANDARD_USER);
			kern.TST_Factory.createPermissionSetAssignments(new List<User> {reader}, permissionSet.Id);
		}
		return reader;
	}

	/**
	 * @description Saves a setup record with only the values given. Every other field is marked optional, so the test
	 * builder fills none of them in. A permission set or a permission row must not get a permission the test did not
	 * ask for.
	 *
	 * @param objectType The type of the record to save.
	 * @param values The field values to save on it.
	 *
	 * @return The saved record.
	 */
	private static SObject insertWithOnlyTheseValues(SObjectType objectType, Map<SObjectField, Object> values)
	{
		List<Object> everyField = new List<Object>();
		everyField.addAll(kern.UTIL_SObjectDescribe.getDescribe(objectType).getFieldsMap().values());
		return kern.TST_Builder.of(objectType).withOptionalFields(everyField).withOverrides(values).build();
	}
}
