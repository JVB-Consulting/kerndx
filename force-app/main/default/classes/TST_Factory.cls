// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Factory class that builds test data for your unit tests.
 *
 * It has helpers for: users (new or inserted, with or without a permission set), permission set assignments, feature flag records,
 * API call records (inbound and outbound), API setting records (inbound and outbound), and content versions (files).
 *
 * @see TST_Factory_TEST
 *
 * @author Jason van Beukering
 *
 * @group Testing
 *
 * @date February 2026, October 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * User testUser = TST_Factory.insertUser('Standard User');
 * ```
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.ExcessivePublicCount,PMD.ExcessiveClassLength,PMD.AvoidGlobalModifier')
global without sharing class TST_Factory
{
	/**
	 * @description How many users getDtoLoginHistories makes. The users get made-up Ids and are never saved. Each
	 * user gets two login history entries.
	 */
	@TestVisible
	private static final Integer NUMBER_OF_MOCK_USERS_FOR_LOGIN_HISTORY = 3;

	/**
	 * @description Marker value used to identify users created by TST_Factory in tests.
	 */
	@TestVisible
	private static final String TEST_USER_MARKER = '17f0e4b4-e3f5-4861-95c8-ce8cdbb6545';

	/**
	 * @description The default cron expression for scheduling jobs.
	 */
	private static final String DEFAULT_CHRON_EXPRESSION = '0 0 * * * ?';

	/**
	 * @description Maps TriggerOperation enum values to Event__c picklist values.
	 * Delegates to the canonical map in SEL_TriggerAction.
	 */
	private static final Map<TriggerOperation, String> OPERATION_TO_EVENT = SEL_TriggerAction.OPERATION_TO_EVENT;

	/**
	 * @description The record name of the trigger action that blocks a new chain-run record whose fields do not match its
	 * status. Tests that must save such a record read the class name from this record, see getRunTransitionActionClassName.
	 */
	private static final String RUN_TRANSITION_ACTION_RECORD = 'AsyncChainRunTransition_BeforeInsert';

	/**
	 * @description The start of the name of each permission set that insertUserWithOneHiddenField saves. A random
	 * ending follows it, so two calls in one test never use the same name.
	 */
	private static final String HIDDEN_FIELD_PERMISSION_SET_PREFIX = 'OneHiddenField';

	/**
	 * @description How many random letters and digits end the name of a permission set that
	 * insertUserWithOneHiddenField saves.
	 */
	private static final Integer PERMISSION_SET_NAME_RANDOM_LENGTH = 12;

	/**
	 * @description The JSON key that holds how many child records a query result carries.
	 */
	private static final String JSON_TOTAL_SIZE = 'totalSize';

	/**
	 * @description The JSON key that says a query result carries all its child records.
	 */
	private static final String JSON_DONE = 'done';

	/**
	 * @description The JSON key that holds the child records of a query result.
	 */
	private static final String JSON_RECORDS = 'records';

	/**
	 * @description Disables all inbound APIs by activating the DisableAllInboundAPIs feature flag.
	 *
	 * @example
	 * ```apex
	 * TST_Factory.disableAllInboundApis();
	 * ```
	 */
	@TestVisible
	private static void disableAllInboundApis()
	{
		newFeatureFlag('DisableAllInboundAPIs');
	}

	/**
	 * @description Disables all outbound APIs by activating the DisableAllOutboundAPIs feature flag.
	 *
	 * @example
	 * ```apex
	 * TST_Factory.disableAllOutboundApis();
	 * ```
	 */
	@TestVisible
	private static void disableAllOutboundApis()
	{
		newFeatureFlag('DisableAllOutboundAPIs');
	}

	/**
	 * @description Disables all APIs by activating the DisableAllAPIs feature flag.
	 *
	 * @example
	 * ```apex
	 * TST_Factory.disableAllApis();
	 * ```
	 */
	@TestVisible
	private static void disableAllApis()
	{
		newFeatureFlag('DisableAllAPIs');
	}

	/**
	 * @description Enables mocking for all outbound APIs by activating the MockAllAPIs feature flag.
	 *
	 * @example
	 * ```apex
	 * TST_Factory.mockAllApis();
	 * ```
	 */
	@TestVisible
	private static void mockAllApis()
	{
		newFeatureFlag('MockAllAPIs');
	}

	/**
	 * @description Enables mocking for all inbound APIs by activating the MockAllInboundAPIs feature flag.
	 *
	 * @example
	 * ```apex
	 * TST_Factory.mockAllInboundApis();
	 * ```
	 */
	@TestVisible
	private static void mockAllInboundApis()
	{
		newFeatureFlag(API_Inbound.FLAG_MOCK_ALL_INBOUND_APIS);
	}

	/**
	 * @description Creates a list of uncommitted User records with the specified profile.
	 *
	 * @param profileName The name of the profile to assign to the users.
	 * @param numberOfUsers The number of users to create.
	 *
	 * @return A list of uncommitted User records.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<User> mockUsers = TST_Factory.newUsers('Standard User', 5);
	 * insert mockUsers;
	 * for (User u : mockUsers)
	 * {
	 * Assert.isNotNull(u.Id, 'Expected each user to be saved');
	 * }
	 * ```
	 */
	global static List<User> newUsers(String profileName, Integer numberOfUsers)
	{
		return getUserBuilder(profileName)
				.withCount(numberOfUsers)
				.withoutInsertion()
				.buildList();
	}

	/**
	 * @description Creates a single uncommitted User record with the specified profile.
	 *
	 * @param profileName The name of the profile to assign to the user.
	 *
	 * @return An uncommitted User record.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * User testUser = TST_Factory.newUser('System Administrator');
	 * insert testUser;
	 * Assert.isNotNull(testUser.Id, 'Expected the user to be saved');
	 * ```
	 */
	global static User newUser(String profileName)
	{
		return newUsers(profileName, 1).iterator().next();
	}

	/**
	 * @description Creates an uncommitted User record with a custom company name.
	 *
	 * The company name can be used as a unique identifier to later retrieve this specific user
	 *
	 * @param profileName The Profile name to assign to the user.
	 * @param companyName A unique company name for this user.
	 *
	 * @return An uncommitted User record with the specified company name.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * @TestSetup
	 * private static void setupTestData()
	 * {
	 *     User testUser = TST_Factory.newUser('Standard User', 'my-test-user');
	 *     insert testUser;
	 * }
	 * private static User getTestUser()
	 * {
	 *     return new SEL_User().findByCompanyName('my-test-user');
	 * }
	 * ```
	 */
	global static User newUser(String profileName, String companyName)
	{
		User user = newUser(profileName);
		user.CompanyName = companyName;
		return user;
	}

	/**
	 * @description Saves the given User records inside the factory's own guard, so a test can save ordinary records
	 * before or after this call in the same transaction without a System.runAs block of its own. Build the users with
	 * newUser or newUsers, set any field your org's User rules need (a role, a required custom field), then hand them
	 * here. Each user needs a free licence seat for its profile's licence; the platform's own error is thrown when there
	 * is none.
	 *
	 * @param users The unsaved User records to save.
	 *
	 * @return The same records, saved, with Ids.
	 *
	 * @throws DmlException If a user cannot be saved, for example when no licence seat is free for its profile's licence.
	 *
	 * @since 1.8
	 *
	 * @example
	 * ```apex
	 * User manager = TST_Factory.newUser('Standard User');
	 * manager.Title = 'Regional Manager';
	 * TST_Factory.insertUsers(new List<User> {manager});
	 * ```
	 */
	global static List<User> insertUsers(List<User> users)
	{
		insertSetupRecords(users);
		return users;
	}

	/**
	 * @description Creates and saves a list of User records with the specified profile, inside the factory's own guard.
	 *
	 * @param profileName The name of the profile to assign to the users.
	 * @param numberOfUsers The number of users to create and save.
	 *
	 * @return A list of saved User records.
	 *
	 * @throws DmlException If a user cannot be saved, for example when no licence seat is free for its profile's licence.
	 *
	 * @since 1.8
	 *
	 * @example
	 * ```apex
	 * List<User> users = TST_Factory.insertUsers('Standard User', 3);
	 * ```
	 */
	global static List<User> insertUsers(String profileName, Integer numberOfUsers)
	{
		return insertUsers(newUsers(profileName, numberOfUsers));
	}

	/**
	 * @description Creates and saves a single User record with the specified profile, inside the factory's own guard,
	 * ready for System.runAs.
	 *
	 * @param profileName The name of the profile to assign to the user.
	 *
	 * @return A saved User record.
	 *
	 * @throws DmlException If the user cannot be saved, for example when no licence seat is free for its profile's licence.
	 *
	 * @since 1.8
	 *
	 * @example
	 * ```apex
	 * User testUser = TST_Factory.insertUser('Standard User');
	 * System.runAs(testUser)
	 * {
	 *     // test body
	 * }
	 * ```
	 */
	global static User insertUser(String profileName)
	{
		return insertUsers(profileName, 1).iterator().next();
	}

	/**
	 * @description Creates and saves a User record with a custom company name, inside the factory's own guard. The
	 * company name can be used as a unique identifier to later retrieve this specific user.
	 *
	 * @param profileName The Profile name to assign to the user.
	 * @param companyName A unique company name for this user.
	 *
	 * @return A saved User record with the specified company name.
	 *
	 * @throws DmlException If the user cannot be saved, for example when no licence seat is free for its profile's licence.
	 *
	 * @since 1.8
	 *
	 * @example
	 * ```apex
	 * @TestSetup
	 * private static void setupTestData()
	 * {
	 *     TST_Factory.insertUser('Standard User', 'my-test-user');
	 * }
	 * private static User getTestUser()
	 * {
	 *     return new SEL_User().findByCompanyName('my-test-user');
	 * }
	 * ```
	 */
	global static User insertUser(String profileName, String companyName)
	{
		return insertUsers(new List<User> {newUser(profileName, companyName)}).iterator().next();
	}

	/**
	 * @description Creates and inserts a User with the specified profile + company name, then assigns
	 * the named permission set (or permission set group). Composes insertUser(profileName, companyName) and
	 * createPermissionSetAssignments(List<User>, String), so both setup writes run inside the factory's own guard
	 * and the test can save ordinary records before or after this call in the same transaction.
	 *
	 * Intended for use in @TestSetup as a committed test admin that test methods reach via
	 * System.runAs. Because runAs re-evaluates permissions for the inner scope, the test admin
	 * receives a fresh permission cache, bypassing the stale-cache issue that affects mutation
	 * of the currently-running user's permission set mid-transaction (the failure mode that made
	 * assignAdministratorPermissionSet() unreliable in the 2GP synthetic validation org).
	 *
	 * @param profileName The Profile name to assign to the user.
	 * @param companyName A unique company name for this user. Used as the retrieval discriminator
	 *                    via SEL_User.findByCompanyName.
	 * @param permissionSetName The API name of the permission set (or permission set group) to assign.
	 *
	 * @return The committed User record with the permission set assigned.
	 *
	 * @throws AssertException If the profile or permission set cannot be resolved for the target org.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * private static final String TEST_ADMIN_COMPANY = 'MyClass_TEST-admin';
	 * @TestSetup
	 * private static void setupTestAdmin()
	 * {
	 *     TST_Factory.newUserWithPermissionSet(
	 *             'System Administrator',
	 *             TEST_ADMIN_COMPANY,
	 *             'Administrator'
	 *     );
	 * }
	 * private static User getTestAdmin()
	 * {
	 *     return new SEL_User().findByCompanyName(TEST_ADMIN_COMPANY);
	 * }
	 * @IsTest
	 * private static void shouldDoX()
	 * {
	 *     System.runAs(getTestAdmin())
	 *     {
	 *         // test body
	 *     }
	 * }
	 * ```
	 */
	global static User newUserWithPermissionSet(String profileName, String companyName, String permissionSetName)
	{
		Profile profile = new SEL_Profile().findByName(profileName);
		Assert.isNotNull(profile, 'Profile not found: ' + profileName);
		User user = insertUser(profileName, companyName);
		createPermissionSetAssignments(new List<User> {user}, permissionSetName);
		return user;
	}

	/**
	 * @description Creates an uncommitted User with the Minimum Access - Salesforce profile and the
	 * given company name. The returned user lacks FLS on almost every object — ideal for tier-A
	 * in-package tests that wrap framework calls in System.runAs(lowPrivilegeUser) to prove the
	 * framework's "subscribers-without-internal-FLS" contract holds because framework-internal
	 * selectors elevate via systemModeRequired().
	 *
	 * Returns uncommitted so the caller controls the insertion (matching newUser semantics). The
	 * typical pattern is to insert inside @TestSetup alongside a committed test admin user.
	 *
	 * Fails loudly (AssertException) if the profile cannot be resolved in the target org — prevents
	 * the silent "Required fields missing: [ProfileId]" DML error that otherwise masks the root cause
	 * when the profile is deactivated, renamed, or unlicensed.
	 *
	 * @param companyName A unique company name for this user. Used as the retrieval discriminator
	 *                    via SEL_User.findByCompanyName.
	 *
	 * @return An uncommitted User record with the Minimum Access - Salesforce profile.
	 *
	 * @throws AssertException If the 'Minimum Access - Salesforce' profile cannot be resolved.
	 *
	 * @example
	 * ```apex
	 * private static final String LOW_PRIVILEGE_COMPANY = 'MyClass_TEST-low-privilege';
	 * @TestSetup
	 * private static void setupUsers()
	 * {
	 *     TST_Factory.insertUsers(new List<User> {TST_Factory.newMinimumAccessUser(LOW_PRIVILEGE_COMPANY)});
	 * }
	 * @IsTest
	 * private static void shouldWorkForLowPrivilegeUser()
	 * {
	 *     User lowPrivilegeUser = new SEL_User().findByCompanyName(LOW_PRIVILEGE_COMPANY);
	 *     System.runAs(lowPrivilegeUser)
	 *     {
	 *         // framework call under test
	 *     }
	 * }
	 * ```
	 */
	@TestVisible
	private static User newMinimumAccessUser(String companyName)
	{
		Profile profile = new SEL_Profile().findByName(SEL_Profile.PROFILE_MINIMUM_ACCESS);
		Assert.isNotNull(profile, 'Profile not found: ' + SEL_Profile.PROFILE_MINIMUM_ACCESS);
		return newUser(SEL_Profile.PROFILE_MINIMUM_ACCESS, companyName);
	}

	/**
	 * @description Saves a user who can read and edit every field of the given objects except one, for tests that
	 * check a read or a save keeps field permissions. The method saves, in this order:
	 * 1. A new permission set, made only for this test, with a random name.
	 * 2. On each given object, the given object permissions. Pass the permission fields to turn on, for example
	 *    ObjectPermissions.PermissionsRead or ObjectPermissions.PermissionsEdit. Never pass View All or Modify All:
	 *    they would let the user see every record, so record sharing could not be tested.
	 * 3. Read and edit on every field of those objects that can carry a field permission, except hiddenField. Edit is
	 *    left off a field the platform calculates (a formula or an auto number). A field the platform never lets
	 *    anyone set stays read only for the user, even with edit on its row. Which fields get read and edit depends
	 *    only on the fields themselves, so the user gets the same access whoever runs the tests, even a user who
	 *    cannot see or edit those fields.
	 * 4. A user on the named profile, and the assignment of the permission set to that user.
	 *
	 * A permission set can only add access, so the profile decides what the user has before it. Pick a profile that
	 * gives no access to the hidden field. The users and permission records are saved in a way that lets a test also
	 * save ordinary records in the same test, before or after this call. Everything is undone when the test ends.
	 *
	 * @param profileName The name of the profile the user is on.
	 * @param objectTypes The objects the permission set gives access to.
	 * @param permissionFields The ObjectPermissions fields to set to true on each object.
	 * @param hiddenField The one field the user gets no field permission on.
	 *
	 * @return The saved user, with the permission set assigned.
	 *
	 * @throws AssertException If the profile cannot be found.
	 * @throws IllegalArgumentException If permissionFields holds View All or Modify All.
	 *
	 * @example
	 * ```apex
	 * User readOnlyUser = TST_Factory.insertUserWithOneHiddenField
	 *         (
	 *                 SEL_Profile.PROFILE_STANDARD_USER,
	 *                 new List<SObjectType> {Foobar__c.SObjectType},
	 *                 new List<SObjectField> {ObjectPermissions.PermissionsRead},
	 *                 Foobar__c.Email__c
	 *         );
	 * ```
	 */
	public static User insertUserWithOneHiddenField(String profileName, List<SObjectType> objectTypes, List<SObjectField> permissionFields, SObjectField hiddenField)
	{
		Profile profile = new SEL_Profile().findByName(profileName);
		Assert.isNotNull(profile, 'Profile not found: ' + profileName);

		if(permissionFields.contains(ObjectPermissions.PermissionsViewAllRecords) || permissionFields.contains(ObjectPermissions.PermissionsModifyAllRecords))
		{
			throw new IllegalArgumentException('View All and Modify All would let the user see every record, so they cannot be given here');
		}

		String permissionSetName = HIDDEN_FIELD_PERMISSION_SET_PREFIX + UTIL_Random.randomAlphanumeric(PERMISSION_SET_NAME_RANDOM_LENGTH);
		PermissionSet permissionSet = (PermissionSet)TST_Builder.of(PermissionSet.SObjectType)
				.withOptionalFields(new List<String>(UTIL_SObjectDescribe.getDescribe(PermissionSet.SObjectType).getCreatableRequiredFields()))
				.withOverride(PermissionSet.Name, permissionSetName)
				.withOverride(PermissionSet.Label, permissionSetName)
				.withoutInsertion()
				.build();
		insertSetupRecords(new List<SObject> {permissionSet});

		List<SObject> grants = new List<SObject>();
		List<SObject> fieldGrants = new List<SObject>();

		for(SObjectType objectType : objectTypes)
		{
			grants.add(newObjectPermissions(permissionSet.Id, objectType, permissionFields));
			fieldGrants.addAll(newFieldPermissions(permissionSet.Id, objectType, hiddenField));
		}

		grants.addAll(fieldGrants);
		insertSetupRecords(grants);

		User user = insertUsers(new List<User> {newUser(profileName)})[0];
		createPermissionSetAssignments(new List<User> {user}, permissionSet.Id);
		return user;
	}

	/**
	 * @description Builds an unsaved object permission row that turns on the given permissions on one object.
	 *
	 * @param permissionSetId The permission set the row belongs to.
	 * @param objectType The object the row gives access to.
	 * @param permissionFields The ObjectPermissions fields to set to true.
	 *
	 * @return The unsaved object permission row.
	 *
	 * @example
	 * ```apex
	 * SObject grant = newObjectPermissions(permissionSetId, Foobar__c.SObjectType, new List<SObjectField> {ObjectPermissions.PermissionsRead});
	 * ```
	 */
	private static SObject newObjectPermissions(Id permissionSetId, SObjectType objectType, List<SObjectField> permissionFields)
	{
		// ObjectPermissions has a field named SobjectType, so the type token comes from an instance.
		SObjectType objectPermissionsType = new ObjectPermissions().getSObjectType();
		Map<SObjectField, Object> overrides = new Map<SObjectField, Object>
		{
				ObjectPermissions.ParentId => permissionSetId,
				ObjectPermissions.SobjectType => UTIL_SObjectDescribe.getObjectNameFromType(objectType)
		};

		for(SObjectField permission : permissionFields)
		{
			overrides.put(permission, true);
		}

		return TST_Builder.of(objectPermissionsType)
				.withOptionalFields(new List<String>(UTIL_SObjectDescribe.getDescribe(objectPermissionsType).getCreatableRequiredFields()))
				.withOverrides(overrides)
				.withoutInsertion()
				.build();
	}

	/**
	 * @description Builds unsaved field permission rows that give read, and edit unless the platform calculates the
	 * field, on every field of one object that can carry a field permission, except the hidden field. Fields the
	 * platform always shows or always controls itself (the Name field, required fields, system fields) cannot carry a
	 * field permission and are skipped. So are the parts of a compound field, such as the latitude of a geolocation field: the row for
	 * the whole field covers its parts.
	 *
	 * @param permissionSetId The permission set the rows belong to.
	 * @param objectType The object whose fields the rows give access to.
	 * @param hiddenField The field that gets no row.
	 *
	 * @return The unsaved field permission rows.
	 *
	 * @example
	 * ```apex
	 * List<SObject> grants = newFieldPermissions(permissionSetId, Foobar__c.SObjectType, Foobar__c.Email__c);
	 * ```
	 */
	private static List<SObject> newFieldPermissions(Id permissionSetId, SObjectType objectType, SObjectField hiddenField)
	{
		// FieldPermissions has a field named SobjectType, so the type token comes from an instance.
		SObjectType fieldPermissionsType = new FieldPermissions().getSObjectType();
		List<String> requiredFields = new List<String>(UTIL_SObjectDescribe.getDescribe(fieldPermissionsType).getCreatableRequiredFields());
		String objectName = UTIL_SObjectDescribe.getObjectNameFromType(objectType);
		List<SObject> grants = new List<SObject>();

		for(SObjectField field : UTIL_SObjectDescribe.getObjectFieldMap(objectType).values())
		{
			DescribeFieldResult fieldDescribe = UTIL_SObjectDescribe.getCachedFieldDescribe(field);

			if(field != hiddenField && fieldDescribe.isPermissionable() && fieldDescribe.getCompoundFieldName() == null)
			{
				grants.add(TST_Builder.of(fieldPermissionsType)
						.withOptionalFields(requiredFields)
						.withOverride(FieldPermissions.ParentId, permissionSetId)
						.withOverride(FieldPermissions.SobjectType, objectName)
						.withOverride(FieldPermissions.Field, objectName + '.' + UTIL_SObjectDescribe.getCachedFieldName(field))
						.withOverride(FieldPermissions.PermissionsRead, true)
						.withOverride(FieldPermissions.PermissionsEdit, isFieldEditable(fieldDescribe))
						.withoutInsertion()
						.build());
			}
		}

		return grants;
	}

	/**
	 * @description Whether a field permission row should give edit on a field. It never gives edit on a formula or an
	 * auto number. The check reads only what kind of field it is, never whether the user who runs the tests can edit
	 * the field: that user may have no access to the field at all, and the answer must be the same whoever runs the
	 * tests. The platform accepted a row that gives edit on a field no one can set on every Foobar__c and Account
	 * field in the framework's own tests; the field stays read only for the user. The framework's own objects have no
	 * auto-number field that can carry a field permission (their auto numbers are Name fields, and a standard auto
	 * number never can), so its tests reach only the formula case; the auto-number case is kept for any other object
	 * a caller passes.
	 *
	 * @param fieldDescribe The describe of the field.
	 *
	 * @return True when the row should give edit on the field.
	 *
	 * @example
	 * ```apex
	 * Boolean canGrantEdit = isFieldEditable(UTIL_SObjectDescribe.getCachedFieldDescribe(Foobar__c.Email__c));
	 * ```
	 */
	private static Boolean isFieldEditable(DescribeFieldResult fieldDescribe)
	{
		return !fieldDescribe.isCalculated() && !fieldDescribe.isAutoNumber();
	}

	/**
	 * @description Creates an uncommitted ContentVersion record from file data.
	 *
	 * @param linkToObjectId The Id of the object to link the content version to.
	 * @param fileName The name of the file.
	 * @param body The binary data of the file.
	 *
	 * @return An uncommitted ContentVersion record.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Account account = (Account)TST_Builder.of(Account.SObjectType).build();
	 * ContentVersion version = TST_Factory.newContentVersion(account.Id, 'test.pdf', Blob.valueOf('Test data'));
	 * insert version;
	 * Assert.areEqual('test.pdf', version.Title, 'Expected the file name to be the title');
	 * ```
	 */
	global static ContentVersion newContentVersion(Id linkToObjectId, String fileName, Blob body)
	{
		ContentVersion newContentVersion = new ContentVersion();
		newContentVersion.FirstPublishLocationId = linkToObjectId;
		newContentVersion.PathOnClient = fileName;
		newContentVersion.Title = fileName;
		newContentVersion.VersionData = body;
		return newContentVersion;
	}

	/**
	 * @description Creates a non-inserted ScheduledJob__c record with parameters. Use for mock registration.
	 *
	 * @param schedulerClassName The fully qualified class name to schedule.
	 * @param parameters The parameter name-value pairs, stored as JSON in Parameters__c.
	 *
	 * @return A non-inserted ScheduledJob__c record with default fields populated.
	 *
	 * @example
	 * ```apex
	 * DTO_NameValues parameters = new DTO_NameValues(new Map<String, String>{'objectName' => 'LogEntry__c'});
	 * ScheduledJob__c job = TST_Factory.newScheduledJob(SCHED_PurgeRecords.class.getName(), parameters);
	 * TST_Mock.register(ScheduledJob__c.SObjectType, new List<ScheduledJob__c>{job});
	 * ```
	 */
	@TestVisible
	private static ScheduledJob__c newScheduledJob(String schedulerClassName, DTO_NameValues parameters)
	{
		return (ScheduledJob__c)getScheduledJobBuilder()
				.withOverride(ScheduledJob__c.ClassName__c, schedulerClassName)
				.withOverride(ScheduledJob__c.Parameters__c, parameters.serialize())
				.withoutInsertion(true)
				.build();
	}

	/**
	 * @description Creates and inserts a ScheduledJob__c record for scheduling a job.
	 *
	 * @param schedulerClassName The name of the class to schedule.
	 *
	 * @return A committed ScheduledJob__c record.
	 *
	 * @example
	 * ```apex
	 * ScheduledJob__c scheduler = TST_Factory.insertScheduledJob('MySchedulerClass');
	 * Assert.isNotNull(scheduler.Id, 'Expected the job record to be saved');
	 * ```
	 */
	@TestVisible
	private static ScheduledJob__c insertScheduledJob(String schedulerClassName)
	{
		return (ScheduledJob__c)getScheduledJobBuilder()
				.withOverride(ScheduledJob__c.ClassName__c, schedulerClassName)
				.build();
	}

	/**
	 * @description Creates and inserts a ScheduledJob__c record with parameters.
	 *
	 * @param schedulerClassName The name of the class to schedule.
	 * @param parameters Map of parameter name-value pairs, stored as JSON in Parameters__c.
	 *
	 * @return A committed ScheduledJob__c record.
	 *
	 * @example
	 * ```apex
	 * ScheduledJob__c scheduler = TST_Factory.insertScheduledJob('SCHED_PurgeRecords', new Map<String, String>{'objectName' => 'Foobar__c'});
	 * ```
	 */
	@TestVisible
	private static ScheduledJob__c insertScheduledJob(String schedulerClassName, Map<String, String> parameters)
	{
		return (ScheduledJob__c)getScheduledJobBuilder()
				.withOverride(ScheduledJob__c.ClassName__c, schedulerClassName)
				.withOverride(ScheduledJob__c.Parameters__c, new DTO_NameValues(parameters).serialize())
				.build();
	}

	/**
	 * @description Creates and inserts an inactive ScheduledJob__c record (IsActive__c = false).
	 *
	 * @param schedulerClassName The name of the class to schedule.
	 *
	 * @return A committed inactive ScheduledJob__c record.
	 *
	 * @example
	 * ```apex
	 * ScheduledJob__c scheduler = TST_Factory.insertInactiveScheduledJob('MySchedulerClass');
	 * ```
	 */
	@TestVisible
	private static ScheduledJob__c insertInactiveScheduledJob(String schedulerClassName)
	{
		return (ScheduledJob__c)getScheduledJobBuilder()
				.withOverride(ScheduledJob__c.ClassName__c, schedulerClassName)
				.withOverride(ScheduledJob__c.IsActive__c, false)
				.build();
	}

	/**
	 * @description Creates an uncommitted ApiCall__c record for a web service call.
	 *
	 * @return An uncommitted ApiCall__c record.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * ApiCall__c apiCall = TST_Factory.newApiCall();
	 * insert apiCall;
	 * Assert.isNotNull(apiCall.Id, 'Expected the call record to be saved');
	 * ```
	 */
	global static ApiCall__c newApiCall()
	{
		return (ApiCall__c)getApiCallBuilder()
				.withoutInsertion()
				.build();
	}

	/**
	 * @description Creates an uncommitted ApiCall__c record with a specified service name.
	 *
	 * @param serviceName The name of the web service class.
	 *
	 * @return An uncommitted ApiCall__c record.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * ApiCall__c apiCall = TST_Factory.newApiCall('MyService');
	 * insert apiCall;
	 * Assert.areEqual('MyService', apiCall.ServiceName__c, 'Expected the given service name');
	 * ```
	 */
	global static ApiCall__c newApiCall(String serviceName)
	{
		Map<SObjectField, Object> overrides = new Map<SObjectField, Object>
		{
				ApiCall__c.ServiceName__c => serviceName
		};

		return (ApiCall__c)getApiCallBuilder()
				.withOverrides(overrides)
				.withoutInsertion()
				.build();
	}

	/**
	 * @description Creates an uncommitted ApiCall__c record for an inbound web service call.
	 *
	 * @param serviceName The name of the web service class.
	 *
	 * @return An uncommitted ApiCall__c record.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * ApiCall__c inboundApiCall = TST_Factory.newInboundApiCall('InboundService');
	 * insert inboundApiCall;
	 * Assert.isNotNull(inboundApiCall.Id, 'Expected the inbound call record to be saved');
	 * ```
	 */
	global static ApiCall__c newInboundApiCall(String serviceName)
	{
		Map<SObjectField, Object> inboundOverrides = new Map<SObjectField, Object>
		{
				ApiCall__c.Request__c => RestContext.request?.requestBody?.toString() ?? UTIL_String.EMPTY,
				ApiCall__c.ServiceName__c => serviceName,
				ApiCall__c.Status__c => SEL_ApiCall.STATUS_COMPLETED,
				ApiCall__c.Direction__c => SEL_ApiCall.TYPE_INBOUND
		};

		return (ApiCall__c)getApiCallBuilder()
				.withOverrides(inboundOverrides)
				.withoutInsertion()
				.build();
	}

	/**
	 * @description Creates an uncommitted ApiCall__c record for an outbound web service call.
	 *
	 * @param serviceName The name of the web service class.
	 *
	 * @return An uncommitted ApiCall__c record.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * ApiCall__c outboundApiCall = TST_Factory.newOutboundApiCall('OutboundService');
	 * insert outboundApiCall;
	 * Assert.isNotNull(outboundApiCall.Id, 'Expected the outbound call record to be saved');
	 * ```
	 */
	global static ApiCall__c newOutboundApiCall(String serviceName)
	{
		Map<SObjectField, Object> outboundOverrides = new Map<SObjectField, Object>
		{
				ApiCall__c.ServiceName__c => serviceName,
				ApiCall__c.Direction__c => SEL_ApiCall.TYPE_OUTBOUND
		};

		return (ApiCall__c)getApiCallBuilder()
				.withOverrides(outboundOverrides)
				.withoutInsertion()
				.build();
	}

	/**
	 * @description Creates an uncommitted ApiCall__c record for an outbound web service call with a triggering object.
	 *
	 * @param serviceName The name of the web service class.
	 * @param recordId The Id of the object triggering the service.
	 *
	 * @return An uncommitted ApiCall__c record.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Account account = (Account)TST_Builder.of(Account.SObjectType).build();
	 * ApiCall__c apiCall = TST_Factory.newOutboundApiCall('OutboundService', account.Id);
	 * insert apiCall;
	 * Assert.isNotNull(apiCall.Id, 'Expected the call record to be saved');
	 * ```
	 */
	global static ApiCall__c newOutboundApiCall(String serviceName, Id recordId)
	{
		Map<SObjectField, Object> outboundOverrides = new Map<SObjectField, Object>
		{
				ApiCall__c.ServiceName__c => serviceName,
				ApiCall__c.TriggeringRecordId__c => recordId,
				ApiCall__c.Direction__c => SEL_ApiCall.TYPE_OUTBOUND
		};

		return (ApiCall__c)getApiCallBuilder()
				.withOverrides(outboundOverrides)
				.withoutInsertion()
				.build();
	}

	/**
	 * @description Creates an uncommitted ApiCall__c record for an outbound web service call with parameters.
	 *
	 * @param serviceName The name of the web service class.
	 * @param recordId The Id of the object triggering the service.
	 * @param requestParameters A map of name-value pairs for request parameters.
	 *
	 * @return An uncommitted ApiCall__c record.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Account account = (Account)TST_Builder.of(Account.SObjectType).build();
	 * Map<String, String> params = new Map<String, String>
	 * {
	 *     'key' => 'value'
	 * };
	 * ApiCall__c apiCall = TST_Factory.newOutboundApiCall('OutboundService', account.Id, params);
	 * insert apiCall;
	 * Assert.isNotNull(apiCall.Id, 'Expected the call record to be saved');
	 * ```
	 */
	global static ApiCall__c newOutboundApiCall(String serviceName, Id recordId, Map<String, String> requestParameters)
	{
		DTO_NameValues dtoNameValues = new DTO_NameValues(requestParameters);
		String requestParams = dtoNameValues.isEmpty() ? null : dtoNameValues.serialize();

		Map<SObjectField, Object> outboundOverrides = new Map<SObjectField, Object>
		{
				ApiCall__c.RequestParameters__c => requestParams,
				ApiCall__c.ServiceName__c => serviceName,
				ApiCall__c.TriggeringRecordId__c => recordId,
				ApiCall__c.Direction__c => SEL_ApiCall.TYPE_OUTBOUND
		};

		return (ApiCall__c)getApiCallBuilder()
				.withOverrides(outboundOverrides)
				.withoutInsertion()
				.build();
	}

	/**
	 * @description Creates an uncommitted ApiCall__c record for an outbound web service call with a single parameter.
	 *
	 * @param serviceName The name of the web service class.
	 * @param recordId The Id of the object triggering the service.
	 * @param parameterName The name of the additional parameter.
	 * @param parameterValue The value of the additional parameter.
	 *
	 * @return An uncommitted ApiCall__c record.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Account account = (Account)TST_Builder.of(Account.SObjectType).build();
	 * ApiCall__c apiCall = TST_Factory.newOutboundApiCall('OutboundService', account.Id, 'key', 'value');
	 * insert apiCall;
	 * Assert.isNotNull(apiCall.Id, 'Expected the call record to be saved');
	 * ```
	 */
	global static ApiCall__c newOutboundApiCall(String serviceName, Id recordId, String parameterName, String parameterValue)
	{
		return newOutboundApiCall(serviceName, recordId, new Map<String, String>
		{
				parameterName => parameterValue
		});
	}

	/**
	 * @description Creates a mock outbound ApiSetting__mdt record via TST_Mock for query interception.
	 * The setting defaults to active and Outbound direction; overrides can replace any field value
	 * including IsActive__c. Pass null when no overrides are needed.
	 *
	 * @param className The fully qualified name of the outbound API handler class
	 * @param overrides Additional field values to apply on top of the defaults (may be null)
	 *
	 * @return A mock ApiSetting__mdt record
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * ApiSetting__mdt setting = TST_Factory.newOutboundApiSetting('API_SendEmail', null);
	 * ```
	 */
	global static ApiSetting__mdt newOutboundApiSetting(String className, Map<SObjectField, Object> overrides)
	{
		return newApiSetting(className, SEL_ApiSetting.DIRECTION_OUTBOUND, overrides);
	}

	/**
	 * @description Creates a mock inbound ApiSetting__mdt record via TST_Mock for test routing.
	 * The setting is registered in the mock cache and will be returned by SEL_ApiSetting queries.
	 *
	 * @param className The fully qualified name of the inbound API handler class
	 * @param endpointPath The URL path pattern for routing (e.g., '/echo/*')
	 *
	 * @return A mock ApiSetting__mdt record
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * ApiSetting__mdt setting = TST_Factory.newInboundApiSetting('API_Echo', '/echo/*');
	 * ```
	 */
	global static ApiSetting__mdt newInboundApiSetting(String className, String endpointPath)
	{
		return newInboundApiSetting(className, endpointPath, 100);
	}

	/**
	 * @description Creates a mock inbound ApiSetting__mdt record with a custom priority, registered
	 * with TST_Mock for query interception.
	 *
	 * @param className The API handler class name
	 * @param endpointPath The URL path pattern for routing (e.g., '/echo/*')
	 * @param priority The routing priority (lower number wins when paths are equal)
	 *
	 * @return A mock ApiSetting__mdt record
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * ApiSetting__mdt setting = TST_Factory.newInboundApiSetting('API_Echo', '/echo/*', 50);
	 * ```
	 */
	global static ApiSetting__mdt newInboundApiSetting(String className, String endpointPath, Integer priority)
	{
		return newInboundApiSetting(className, endpointPath, priority, null);
	}

	/**
	 * @description Creates a mock inbound ApiSetting__mdt record with a custom priority and additional
	 * field overrides, registered with TST_Mock for query interception.
	 *
	 * @param className The API handler class name
	 * @param endpointPath The URL path pattern for routing (e.g., '/echo/*')
	 * @param priority The routing priority (lower number wins when paths are equal)
	 * @param overrides Additional field values to apply on top of the defaults (may be null)
	 *
	 * @return A mock ApiSetting__mdt record
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * ApiSetting__mdt setting = TST_Factory.newInboundApiSetting('API_Echo', '/echo/*', 100, new Map<SObjectField, Object>
	 * {
	 *     ApiSetting__mdt.LogIssues__c => true
	 * });
	 * ```
	 */
	global static ApiSetting__mdt newInboundApiSetting(String className, String endpointPath, Integer priority, Map<SObjectField, Object> overrides)
	{
		Map<SObjectField, Object> inboundDefaults = new Map<SObjectField, Object>
		{
				ApiSetting__mdt.EndpointPath__c => endpointPath,
				ApiSetting__mdt.Priority__c => priority
		};

		if(overrides != null)
		{
			inboundDefaults.putAll(overrides);
		}

		return newApiSetting(className, SEL_ApiSetting.DIRECTION_INBOUND, inboundDefaults);
	}

	/**
	 * @description Creates a mock ApiSetting__mdt record with common defaults (ClassName, Direction, IsActive)
	 * and optional field overrides, registered with TST_Mock for query interception.
	 *
	 * @param className The API handler class name
	 * @param direction The API direction (use SEL_ApiSetting.DIRECTION_OUTBOUND or DIRECTION_INBOUND)
	 * @param overrides Additional field values to apply on top of the defaults (may be null)
	 *
	 * @return A mock ApiSetting__mdt record
	 */
	private static ApiSetting__mdt newApiSetting(String className, String direction, Map<SObjectField, Object> overrides)
	{
		return (ApiSetting__mdt)TST_Mock.of(ApiSetting__mdt.SObjectType)
				.withOverride(ApiSetting__mdt.ClassName__c, className)
				.withOverride(ApiSetting__mdt.Direction__c, direction)
				.withOverride(ApiSetting__mdt.IsActive__c, true)
				.withOverrides(overrides)
				.build();
	}

	/**
	 * @description Creates a mock ApiMock__mdt record via TST_Mock for query interception.
	 * The mock defaults to active with priority 100, status 200, and no pattern (catch-all).
	 * Overrides can replace any field value including IsActive__c and Priority__c.
	 *
	 * @param overrides Additional field values to apply on top of the defaults (may be null)
	 *
	 * @return A mock ApiMock__mdt record
	 *
	 * @example
	 * ```apex
	 * TST_Factory.newApiMock(new Map<SObjectField, Object>
	 * {
	 *     ApiMock__mdt.Priority__c => 10,
	 *     ApiMock__mdt.MatchRequestBodyPattern__c => 'urgent',
	 *     ApiMock__mdt.StatusCode__c => 201,
	 *     ApiMock__mdt.ResponseBody__c => '{"mock":"urgent"}'
	 * });
	 * ```
	 */
	@TestVisible
	private static ApiMock__mdt newApiMock(Map<SObjectField, Object> overrides)
	{
		TST_Mock.MockBuilder builder = TST_Mock.of(ApiMock__mdt.SObjectType)
				.withOverride(ApiMock__mdt.IsActive__c, true)
				.withOverride(ApiMock__mdt.Priority__c, 100)
				.withOverride(ApiMock__mdt.StatusCode__c, 200)
				.withOverride(ApiMock__mdt.IsRegex__c, false);

		if(overrides != null)
		{
			builder = builder.withOverrides(overrides);
		}

		return (ApiMock__mdt)builder.build();
	}

	/**
	 * @description Activates a feature flag for testing by injecting it into the selector cache.
	 * `UTIL_FeatureFlag.isEnabled(flagName)` will return `true` after this call.
	 *
	 * @param flagName The developer name of the feature flag to activate.
	 *
	 * @return The activated FeatureFlag__mdt record.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * TST_Factory.newFeatureFlag('MyFeatureFlag');
	 * ```
	 */
	global static FeatureFlag__mdt newFeatureFlag(String flagName)
	{
		return newFeatureFlag(flagName, true);
	}

	/**
	 * @description Builds an in-memory `FeatureFlag__mdt` record for `flagName`, optionally
	 * registering it in `SEL_FeatureFlag.activeFlags` with `IsEnabledByDefault__c = true`.
	 * When `registerAsActive = false`, the returned record can be used to populate a
	 * `MetadataRelationship` lookup field (e.g., `ValidationRule__mdt.BypassFeatureFlag__c`)
	 * without affecting `UTIL_FeatureFlag.isEnabled` evaluations elsewhere in the transaction.
	 *
	 * @param flagName The developer name of the feature flag.
	 * @param registerAsActive When true, puts the record into `SEL_FeatureFlag.activeFlags` so
	 *        `UTIL_FeatureFlag.isEnabled(flagName)` returns true; when false, the record is
	 *        returned without registration.
	 *
	 * @return The FeatureFlag__mdt record (registered when `registerAsActive = true`).
	 */
	@TestVisible
	private static FeatureFlag__mdt newFeatureFlag(String flagName, Boolean registerAsActive)
	{
		return newFeatureFlag(flagName, registerAsActive, true);
	}

	/**
	 * @description Builds an in-memory `FeatureFlag__mdt` record for `flagName` with explicit
	 * registration and enabled-state control. Register+disabled is the combination tests use
	 * to explicitly override a subscriber-shipped flag's default (e.g., to assert "when flag X
	 * is disabled" behaviour regardless of the CMDT record's `IsEnabledByDefault__c` value).
	 *
	 * @param flagName The developer name of the feature flag.
	 * @param registerAsActive When true, puts the record into `SEL_FeatureFlag.activeFlags`.
	 * @param isEnabled The `IsEnabledByDefault__c` value to stamp on the record. When this record
	 *        is registered, `UTIL_FeatureFlag.isEnabled(flagName)` returns this value (assuming
	 *        no strategies are attached).
	 *
	 * @return The FeatureFlag__mdt record (registered when `registerAsActive = true`).
	 */
	@TestVisible
	private static FeatureFlag__mdt newFeatureFlag(String flagName, Boolean registerAsActive, Boolean isEnabled)
	{
		FeatureFlag__mdt flag = (FeatureFlag__mdt)TST_Builder.of(FeatureFlag__mdt.SObjectType)
				.withOverride(FeatureFlag__mdt.DeveloperName, flagName)
				.withOverride(FeatureFlag__mdt.IsActive__c, true)
				.withOverride(FeatureFlag__mdt.IsEnabledByDefault__c, isEnabled)
				.withoutInsertion(true)
				.build();
		if(registerAsActive)
		{
			SEL_FeatureFlag.activeFlags.put(flagName, flag);
		}
		return flag;
	}

	/**
	 * @description Builds an in-memory `MaskingRule__mdt` with a mock Id, applying the given field overrides.
	 * Custom metadata cannot be inserted via DML, so the record is built without insertion; the mock Id lets a
	 * `MaskingTarget__mdt.Rule__c` reference it. Pass an empty map for an all-defaults rule.
	 *
	 * @param overrides Field overrides to stamp on the rule. An `Id` override is ignored — the builder assigns
	 *        the mock Id.
	 *
	 * @return The in-memory rule with a mock Id.
	 */
	public static MaskingRule__mdt newMaskingRule(Map<SObjectField, Object> overrides)
	{
		return (MaskingRule__mdt)TST_Builder.of(MaskingRule__mdt.SObjectType)
				.withOverrides(overrides)
				.withoutInsertion(true)
				.build();
	}

	/**
	 * @description Builds an in-memory `MaskingTarget__mdt` with a mock Id, applying the given field overrides.
	 * Built without insertion (custom metadata cannot be inserted via DML). Pass an empty map for an
	 * all-defaults target.
	 *
	 * @param overrides Field overrides to stamp on the target. An `Id` override is ignored.
	 *
	 * @return The in-memory target with a mock Id.
	 */
	public static MaskingTarget__mdt newMaskingTarget(Map<SObjectField, Object> overrides)
	{
		return (MaskingTarget__mdt)TST_Builder.of(MaskingTarget__mdt.SObjectType)
				.withOverrides(overrides)
				.withoutInsertion(true)
				.build();
	}

	/**
	 * @description Builds an in-memory `MaskingTarget__mdt` linked to the given rule — the `Rule__c` lookup Id
	 * is taken from the rule's mock Id and the `Rule__r` relationship is wired after the build, so the target
	 * resolves its rule in-memory without a query. Custom-metadata relationships cannot be set through the
	 * builder, which is why this overload wires `Rule__r` post-build.
	 *
	 * @param overrides Field overrides to stamp on the target. `Rule__c` is set from `rule`.
	 * @param rule The rule the target references.
	 *
	 * @return The in-memory target linked to the rule.
	 */
	public static MaskingTarget__mdt newMaskingTarget(Map<SObjectField, Object> overrides, MaskingRule__mdt rule)
	{
		Map<SObjectField, Object> withRule = overrides == null ? new Map<SObjectField, Object>() : overrides.clone();
		withRule.put(MaskingTarget__mdt.Rule__c, rule.Id);

		MaskingTarget__mdt target = newMaskingTarget(withRule);
		target.Rule__r = rule;
		return target;
	}

	/**
	 * @description Creates and inserts a list of Foobar__c records with initialized fields.
	 * Uses TST_Builder for record creation and insertion.
	 *
	 * @param numberOfItems The number of Foobar__c records to create.
	 *
	 * @return A list of committed Foobar__c records.
	 *
	 * @example
	 * ```apex
	 * List<Foobar__c> foobars = TST_Factory.insertFoobars(3);
	 * Assert.areEqual(3, foobars.size(), 'Expected three Foobar records');
	 * ```
	 */
	public static List<Foobar__c> insertFoobars(Integer numberOfItems)
	{
		return getFoobarBuilder()
				.withCount(numberOfItems)
				.buildList();
	}

	/**
	 * @description Creates a list of uncommitted Foobar__c records with initialized fields.
	 * Uses TST_Builder for record creation in memory.
	 *
	 * @param numberOfItems The number of Foobar__c records to create.
	 *
	 * @return A list of uncommitted Foobar__c records.
	 *
	 * @example
	 * ```apex
	 * List<Foobar__c> foobars = TST_Factory.newFoobars(3);
	 * insert foobars;
	 * Assert.areEqual(3, foobars.size(), 'Expected three Foobar records');
	 * ```
	 */
	public static List<Foobar__c> newFoobars(Integer numberOfItems)
	{
		return getFoobarBuilder()
				.withCount(numberOfItems)
				.withoutInsertion()
				.buildList();
	}

	/**
	 * @description Creates and inserts a single Foobar__c record with initialized fields.
	 * Uses TST_Builder for record creation and insertion.
	 *
	 * @return A committed Foobar__c record.
	 *
	 * @example
	 * ```apex
	 * Foobar__c foobar = TST_Factory.insertFoobar();
	 * Assert.isNotNull(foobar.Id, 'Expected the Foobar record to be saved');
	 * ```
	 */
	public static Foobar__c insertFoobar()
	{
		return (Foobar__c)getFoobarBuilder().build();
	}

	/**
	 * @description Creates an uncommitted Foobar__c record with random field values.
	 * Uses TST_Builder for record creation in memory.
	 *
	 * @return An uncommitted Foobar__c record.
	 *
	 * @example
	 * ```apex
	 * Foobar__c foobar = TST_Factory.newFoobar();
	 * insert foobar;
	 * Assert.isNotNull(foobar.Id, 'Expected the Foobar record to be saved');
	 * ```
	 */
	public static Foobar__c newFoobar()
	{
		return (Foobar__c)getFoobarBuilder().withoutInsertion().build();
	}

	/**
	 * @description Creates an uncommitted Foobar__c record with a generated mock ID.
	 * Use this when you need a record with an ID for query mocking scenarios
	 * without performing DML operations.
	 *
	 * @return An uncommitted Foobar__c record with a generated mock ID.
	 *
	 * @example
	 * ```apex
	 * Foobar__c foobar = TST_Factory.newFoobarWithMockId();
	 * Assert.isNotNull(foobar.Id, 'Expected a made-up Id although nothing was saved');
	 * QRY_Builder.setMock(Foobar__c.SObjectType, new List<Foobar__c>{foobar});
	 * ```
	 */
	public static Foobar__c newFoobarWithMockId()
	{
		return (Foobar__c)getFoobarBuilder().withoutInsertion(true).build();
	}

	/**
	 * @description Creates an uncommitted Foobar__c record with a specific name.
	 *
	 * @param name The name to assign to the Foobar record.
	 *
	 * @return An uncommitted Foobar__c record with the specified name.
	 *
	 * @example
	 * ```apex
	 * Foobar__c foobar = TST_Factory.newFoobarWithName('Parent Record');
	 * Assert.areEqual('Parent Record', foobar.Name, 'Expected the given name');
	 * ```
	 */
	public static Foobar__c newFoobarWithName(String name)
	{
		return (Foobar__c)getFoobarBuilder()
				.withOverride(Foobar__c.Name, name)
				.withoutInsertion()
				.build();
	}

	/**
	 * @description Creates an uncommitted Foobar__c record with a specific email address. Pass a value the
	 * platform refuses to build a record whose insert fails with INVALID_EMAIL_ADDRESS.
	 *
	 * @param email The email address to assign to the Foobar record.
	 *
	 * @return An uncommitted Foobar__c record with the specified email address.
	 *
	 * @example
	 * ```apex
	 * Foobar__c refused = TST_Factory.newFoobarWithEmail('not-a-valid-email');
	 * ```
	 */
	public static Foobar__c newFoobarWithEmail(String email)
	{
		return (Foobar__c)getFoobarBuilder()
				.withOverride(Foobar__c.Email__c, email)
				.withoutInsertion()
				.build();
	}

	/**
	 * @description Creates an uncommitted ContentVersion record with random data.
	 *
	 * @return An uncommitted ContentVersion record.
	 *
	 * @example
	 * ```apex
	 * ContentVersion version = TST_Factory.newContentVersion();
	 * insert version;
	 * Assert.isNotNull(version.Id, 'Expected the file to be saved');
	 * ```
	 */
	@TestVisible
	private static ContentVersion newContentVersion()
	{
		return newContentVersion(null);
	}

	/**
	 * @description Creates an uncommitted ContentVersion record with a specified title.
	 *
	 * @param title The title of the content version, or random if blank.
	 *
	 * @return An uncommitted ContentVersion record.
	 *
	 * @example
	 * ```apex
	 * ContentVersion version = TST_Factory.newContentVersion('TestDocument');
	 * insert version;
	 * Assert.areEqual('TestDocument', version.Title, 'Expected the given title');
	 * ```
	 */
	@TestVisible
	private static ContentVersion newContentVersion(String title)
	{
		return newContentVersion(null, String.isBlank(title) ? UTIL_Random.randomName() : title, Blob.valueOf(UTIL_Random.randomDescription()));
	}

	/**
	 * @description Publishes log events for testing purposes.
	 *
	 * @param numberOfItems The number of log events to publish.
	 *
	 * @example
	 * ```apex
	 * TST_Factory.publishLogEvents(5);
	 * ```
	 */
	@TestVisible
	private static void publishLogEvents(Integer numberOfItems)
	{
		for(Integer i = 0; i < numberOfItems; i++)
		{
			LOG_Builder.build().info(String.valueOf(i)).at(TST_Factory.class.getName() + '/publishLogEvents').emit();
		}
	}

	/**
	 * @description Creates an uncommitted share record for a specified object.
	 *
	 * @param dtoShareDescribe A DTO containing share object metadata.
	 * @param relatedRecordId The Id of the record to share.
	 * @param accessLevel The access level for the share (e.g., Read, Edit).
	 * @param userOrGroupId The Id of the user or group to grant access to.
	 *
	 * @return An uncommitted share SObject record.
	 *
	 * @example
	 * ```apex
	 * Account account = (Account)TST_Builder.of(Account.SObjectType).build();
	 * User user = TST_Factory.newUser('Standard User');
	 * insert user;
	 * SEL_ObjectShare.DTO_ObjectShareDescribe shareDescribe = SEL_ObjectShare.getShareDescribe(account.Id);
	 * SObject share = TST_Factory.newSObjectShare(shareDescribe, account.Id, 'Edit', user.Id);
	 * insert share;
	 * Assert.isNotNull(share.Id, 'Expected the share record to be saved');
	 * ```
	 */
	public static SObject newSObjectShare(SEL_ObjectShare.DTO_ObjectShareDescribe dtoShareDescribe, Id relatedRecordId, String accessLevel, Id userOrGroupId)
	{
		SObject shareObject = dtoShareDescribe.newShareObject();

		shareObject.put(SEL_ObjectShare.FIELD_ROW_CAUSE, SEL_ObjectShare.ROW_CAUSE_MANUAL);
		shareObject.put(SEL_ObjectShare.FIELD_USER_OR_GROUP_ID, userOrGroupId);
		shareObject.put(dtoShareDescribe.accessLevel, accessLevel);
		shareObject.put(dtoShareDescribe.parentIdFieldName, relatedRecordId);
		if(SEL_ObjectShare.OBJECT_ACCOUNT_SHARE.equalsIgnoreCase(dtoShareDescribe.shareObjectName))
		{
			shareObject.put(SEL_ObjectShare.FIELD_OPPORTUNITY_ACCESS_LEVEL, SEL_ObjectShare.ACCESS_LEVEL_NONE);
		}

		return shareObject;
	}

	/**
	 * @description Creates an uncommitted share record for a specified record.
	 *
	 * @param relatedRecordId The Id of the record to share.
	 * @param accessLevel The access level for the share (e.g., Read, Edit).
	 * @param userOrGroupId The Id of the user or group to grant access to.
	 *
	 * @return An uncommitted share SObject record.
	 *
	 * @example
	 * ```apex
	 * Account account = (Account)TST_Builder.of(Account.SObjectType).build();
	 * User user = TST_Factory.newUser('Standard User');
	 * insert user;
	 * SObject share = TST_Factory.newSObjectShare(account.Id, 'Edit', user.Id);
	 * insert share;
	 * Assert.isNotNull(share.Id, 'Expected the share record to be saved');
	 * ```
	 */
	public static SObject newSObjectShare(Id relatedRecordId, String accessLevel, Id userOrGroupId)
	{
		return newSObjectShare(SEL_ObjectShare.getShareDescribe(relatedRecordId), relatedRecordId, accessLevel, userOrGroupId);
	}

	/**
	 * @description Creates PermissionSetAssignment records for a list of users and a permission set. The assignments
	 * are saved in one statement, inside the factory's own guard while a test runs, so ordinary records a test saves before
	 * or after this call in the same transaction do not collide with them.
	 *
	 * @param users The list of users to assign the permission set to.
	 * @param permissionSetOrGroupName The name of the permission set.
	 *
	 * @throws AssertException If no permission set is found for the specified name.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<User> users = TST_Factory.insertUsers('Standard User', 2);
	 * TST_Factory.createPermissionSetAssignments(users, 'CustomPermissionSet');
	 * ```
	 */
	global static void createPermissionSetAssignments(List<User> users, String permissionSetOrGroupName)
	{
		PermissionSet foundPermissionSet = new SEL_PermissionSet().findByName(permissionSetOrGroupName);
		Assert.isNotNull(foundPermissionSet, 'No permission set found for the following name: ' + permissionSetOrGroupName);

		PermissionSetGroup foundGroup;

		if(Test.isRunningTest() && SEL_PermissionSet.GROUP_TYPE.equalsIgnoreCase(foundPermissionSet.Type))
		{
			foundGroup = new SEL_PermissionSetGroup().findByName(permissionSetOrGroupName);
		}

		createPermissionSetAssignments(users, foundGroup?.Id ?? foundPermissionSet.Id);
	}

	/**
	 * @description Creates PermissionSetAssignment records for a list of users and a permission set Id. The assignments
	 * are saved in one statement, inside the factory's own guard while a test runs, so ordinary records a test saves before
	 * or after this call in the same transaction do not collide with them.
	 *
	 * @param users The list of users to assign the permission set to.
	 * @param permissionSetOrGroupId The Id of the permission set.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<User> users = TST_Factory.insertUsers('Standard User', 2);
	 * PermissionSet permissionSet = new SEL_PermissionSet().findByName('CustomPermissionSet');
	 * TST_Factory.createPermissionSetAssignments(users, permissionSet.Id);
	 * ```
	 */
	global static void createPermissionSetAssignments(List<User> users, Id permissionSetOrGroupId)
	{
		SObjectType assignmentObjectType = UTIL_SObjectDescribe.getSObjectTypeById(permissionSetOrGroupId);
		List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();

		for(User userRecord : users)
		{
			Map<SObjectField, Object> overrides = new Map<SObjectField, Object>
			{
					PermissionSetAssignment.AssigneeId => userRecord.Id
			};

			if(assignmentObjectType == PermissionSet.SObjectType)
			{
				overrides.put(PermissionSetAssignment.PermissionSetId, permissionSetOrGroupId);
			}
			else
			{
				overrides.put(PermissionSetAssignment.PermissionSetGroupId, permissionSetOrGroupId);
			}

			assignments.add((PermissionSetAssignment)getPermissionSetAssignmentBuilder()
					.withOverrides(overrides)
					.withoutInsertion()
					.build());
		}

		insertSetupRecords(assignments);
	}

	/**
	 * @description Saves setup records (users, permission set assignments) inside the factory's own guard: while a test
	 * runs, the insert happens inside System.runAs of the current user, so the platform never sees it in the same
	 * stretch of the transaction as the ordinary records the test saves before or after it. Outside a test the platform
	 * refuses System.runAs, so the records are saved by the same system-mode insert without the guard.
	 *
	 * @param records The unsaved setup records to save.
	 *
	 * @example
	 * ```apex
	 * insertSetupRecords(new List<User> {newUser('Standard User')});
	 * ```
	 */
	@SuppressWarnings('PMD.ApexCRUDViolation')
	private static void insertSetupRecords(List<SObject> records)
	{
		// A write can change any cached read, and this raw insert does not commit through DML_Transaction.
		QRY_Engine.clearQueryResultMemoryCache();
		if(Test.isRunningTest())
		{
			System.runAs(new User(Id = UserInfo.getUserId()))
			{
				Database.insert(records, true, AccessLevel.SYSTEM_MODE);
			}
			return;
		}
		// kern-coverage-exempt: the platform refuses System.runAs outside a test method, so this line runs only in production and no test can execute it
		Database.insert(records, true, AccessLevel.SYSTEM_MODE);
	}

	/**
	 * @description Assigns the Administrator permission set to the current running user if not already assigned.
	 * Intended for SeeAllData=true tests where the running user needs record type visibility
	 * or elevated permissions provided by the package Administrator permission set.
	 */
	public static void assignAdministratorPermissionSet()
	{
		PermissionSet adminPermissionSet = new SEL_PermissionSet().findByName(SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME);

		Boolean isAssigned = QRY_Builder.selectFrom(PermissionSetAssignment.SObjectType)
				.condition(PermissionSetAssignment.AssigneeId).equals(UserInfo.getUserId())
				.andCondition(PermissionSetAssignment.PermissionSetId).equals(adminPermissionSet.Id)
				.exists();

		if(!isAssigned)
		{
			createPermissionSetAssignments(new List<User> {new User(Id = UserInfo.getUserId())}, adminPermissionSet.Id);
		}
	}

	/**
	 * @description Creates a list of PROC_LoginFrequencyAggregator.DTO_LoginHistory records for testing login history processing.
	 *
	 * @return A list of uncommitted PROC_LoginFrequencyAggregator.DTO_LoginHistory records.
	 *
	 * @example
	 * ```apex
	 * List<PROC_LoginFrequencyAggregator.DTO_LoginHistory> loginHistories = TST_Factory.getDtoLoginHistories();
	 * Assert.areEqual(6, loginHistories.size(), 'Expected six login history entries');
	 * ```
	 */
	@TestVisible
	private static List<PROC_LoginFrequencyAggregator.DTO_LoginHistory> getDtoLoginHistories()
	{
		List<SObject> mockUsers = TST_Builder.of(User.SObjectType)
				.withCount(NUMBER_OF_MOCK_USERS_FOR_LOGIN_HISTORY)
				.withoutInsertion(true)
				.buildList();

		List<PROC_LoginFrequencyAggregator.DTO_LoginHistory> dtoLoginHistories = new List<PROC_LoginFrequencyAggregator.DTO_LoginHistory>();

		PROC_LoginFrequencyAggregator.DTO_LoginHistory loginHistory1 = new PROC_LoginFrequencyAggregator.DTO_LoginHistory();
		loginHistory1.userId = mockUsers[0].Id;
		loginHistory1.loginTime = UTIL_Date.dateTimeFromIso8601('2022-05-05T09:57:46.000+0000');
		dtoLoginHistories.add(loginHistory1);

		PROC_LoginFrequencyAggregator.DTO_LoginHistory loginHistory2 = new PROC_LoginFrequencyAggregator.DTO_LoginHistory();
		loginHistory2.userId = mockUsers[0].Id;
		loginHistory2.loginTime = UTIL_Date.dateTimeFromIso8601('2022-05-05T13:45:08.000+0000');
		dtoLoginHistories.add(loginHistory2);

		PROC_LoginFrequencyAggregator.DTO_LoginHistory loginHistory3 = new PROC_LoginFrequencyAggregator.DTO_LoginHistory();
		loginHistory3.userId = mockUsers[1].Id;
		loginHistory3.loginTime = UTIL_Date.dateTimeFromIso8601('2022-05-05T17:55:56.000+0000');
		dtoLoginHistories.add(loginHistory3);

		PROC_LoginFrequencyAggregator.DTO_LoginHistory loginHistory4 = new PROC_LoginFrequencyAggregator.DTO_LoginHistory();
		loginHistory4.userId = mockUsers[1].Id;
		loginHistory4.loginTime = UTIL_Date.dateTimeFromIso8601('2022-05-27T18:24:35.000+0000');
		dtoLoginHistories.add(loginHistory4);

		PROC_LoginFrequencyAggregator.DTO_LoginHistory loginHistory5 = new PROC_LoginFrequencyAggregator.DTO_LoginHistory();
		loginHistory5.userId = mockUsers[2].Id;
		loginHistory5.loginTime = UTIL_Date.dateTimeFromIso8601('2022-05-05T11:44:38.000+0000');
		dtoLoginHistories.add(loginHistory5);

		PROC_LoginFrequencyAggregator.DTO_LoginHistory loginHistory6 = new PROC_LoginFrequencyAggregator.DTO_LoginHistory();
		loginHistory6.userId = mockUsers[2].Id;
		loginHistory6.loginTime = UTIL_Date.dateTimeFromIso8601('2022-06-05T19:23:55.000+0000');
		dtoLoginHistories.add(loginHistory6);

		return dtoLoginHistories;
	}

	/**
	 * @description Creates and inserts LoginFrequency__c records with specified concatenated strings.
	 *
	 * @param numberOfRecords The number of records to create.
	 * @param concatenatedStrings A set of concatenated strings for the CompositeKey__c field.
	 *
	 * @return A list of committed LoginFrequency__c records.
	 *
	 * @example
	 * ```apex
	 * Set<String> strings = new Set<String>
	 * {
	 *     'user1_2022_05',
	 *     'user2_2022_06'
	 * };
	 * List<LoginFrequency__c> loginFrequencies = TST_Factory.createLoginFrequencyRecords(2, strings);
	 * Assert.areEqual(2, loginFrequencies.size(), 'Expected two login frequency records');
	 * ```
	 */
	@TestVisible
	@SuppressWarnings('PMD.ApexCRUDViolation')
	private static List<LoginFrequency__c> createLoginFrequencyRecords(Integer numberOfRecords, Set<String> concatenatedStrings)
	{
		// A write can change any cached read, and this raw insert does not commit through DML_Transaction.
		QRY_Engine.clearQueryResultMemoryCache();
		List<LoginFrequency__c> newLoginFrequencyRecords = new List<LoginFrequency__c>();
		Iterator<String> concatenatedString = concatenatedStrings.iterator();
		for(Integer i = 0; i < numberOfRecords; i++)
		{
			LoginFrequency__c loginFrequency = new LoginFrequency__c();

			loginFrequency.TotalLoginCount__c = UTIL_Random.randomDecimal(1, 0);
			loginFrequency.UniqueLoginCount__c = UTIL_Random.randomDecimal(1, 0);
			loginFrequency.CompositeKey__c = concatenatedString.next();

			newLoginFrequencyRecords.add(loginFrequency);
		}
		Database.insert(newLoginFrequencyRecords, true, AccessLevel.SYSTEM_MODE);
		return newLoginFrequencyRecords;
	}

	/**
	 * @description Creates and inserts an LogEntry__c record with random data.
	 *
	 * @return A committed LogEntry__c record.
	 *
	 * @example
	 * ```apex
	 * LogEntry__c logEntry = TST_Factory.insertLogEntry();
	 * Assert.isNotNull(logEntry.Id, 'Expected the log entry to be saved');
	 * ```
	 */
	@TestVisible
	private static LogEntry__c insertLogEntry()
	{
		return (LogEntry__c)getLogEntryBuilder().build();
	}

	/**
	 * @description Creates and inserts a ApiIssue__c record for a web service API call.
	 *
	 * @param apiCall The associated ApiCall__c record.
	 * @param itemHash A hash uniquely identifying the failure.
	 *
	 * @return A committed ApiIssue__c record.
	 *
	 * @example
	 * ```apex
	 * ApiCall__c apiCall = TST_Factory.newApiCall('TestService');
	 * insert apiCall;
	 * ApiIssue__c failure = TST_Factory.insertApiIssue(apiCall, 'uniqueHash');
	 * Assert.isNotNull(failure.Id, 'Expected the issue record to be saved');
	 * ```
	 */
	@TestVisible
	private static ApiIssue__c insertApiIssue(ApiCall__c apiCall, String itemHash)
	{
		return (ApiIssue__c)getApiIssueBuilder(apiCall, itemHash)
				.build();
	}

	/**
	 * @description Creates an uncommitted ApiIssue__c record for a web service API call. It is the record the outbound
	 * framework builds for a failed call (see API_Outbound.buildOutboundFailureRecord), so a test's issue and a real one
	 * cannot drift apart.
	 *
	 * @param apiCall The associated ApiCall__c record.
	 * @param itemHash A hash uniquely identifying the failure.
	 *
	 * @return An uncommitted ApiIssue__c record.
	 *
	 * @example
	 * ```apex
	 * ApiCall__c apiCall = TST_Factory.newApiCall('TestService');
	 * DML_Builder.newTransaction().doInsert(apiCall).execute();
	 * ApiIssue__c issue = TST_Factory.newApiIssue(apiCall, 'uniqueHash');
	 * DML_Builder.newTransaction().doInsert(issue).execute();
	 * ```
	 */
	public static ApiIssue__c newApiIssue(ApiCall__c apiCall, String itemHash)
	{
		return API_Outbound.buildOutboundFailureRecord(apiCall, itemHash);
	}

	/**
	 * @description Creates a list of FLOW_CheckObjectPermissions.DTO_Request records for checking object permissions.
	 *
	 * @param objectApiNames A list of object API names to check permissions for.
	 *
	 * @return A list of uncommitted FLOW_CheckObjectPermissions.DTO_Request records.
	 *
	 * @example
	 * ```apex
	 * List<String> apiNames = new List<String>
	 * {
	 *     'Account',
	 *     'Contact'
	 * };
	 * List<FLOW_CheckObjectPermissions.DTO_Request> requests = TST_Factory.createObjectPermissionCheckRequests(apiNames);
	 * ```
	 */
	@TestVisible
	private static List<FLOW_CheckObjectPermissions.DTO_Request> createObjectPermissionCheckRequests(List<String> objectApiNames)
	{
		List<FLOW_CheckObjectPermissions.DTO_Request> dtoRequests = new List<FLOW_CheckObjectPermissions.DTO_Request>();
		for(String objectApiName : objectApiNames)
		{
			FLOW_CheckObjectPermissions.DTO_Request dtoRequest = new FLOW_CheckObjectPermissions.DTO_Request();
			dtoRequest.objectApiName = objectApiName;
			dtoRequests.add(dtoRequest);
		}
		return dtoRequests;
	}

	/**
	 * @description Creates an uncommitted TriggerSetting__mdt record for testing.
	 *
	 * @param objectApiName The API name of the object this setting applies to
	 *
	 * @return An uncommitted TriggerSetting__mdt record
	 *
	 * @example
	 * ```apex
	 * TriggerSetting__mdt setting = TST_Factory.newTriggerSetting('Account');
	 * ```
	 */
	@TestVisible
	private static TriggerSetting__mdt newTriggerSetting(String objectApiName)
	{
		return newTriggerSetting(objectApiName, new Map<SObjectField, Object>());
	}

	/**
	 * @description Creates an uncommitted TriggerSetting__mdt record for testing with feature flag fields.
	 *
	 * @param objectApiName The API name of the object this setting applies to
	 * @param bypassPermission Optional bypass feature flag DeveloperName (null if not needed)
	 * @param requiredPermission Optional required feature flag DeveloperName (null if not needed)
	 *
	 * @return An uncommitted TriggerSetting__mdt record
	 *
	 * @example
	 * ```apex
	 * TriggerSetting__mdt setting = TST_Factory.newTriggerSetting('Account', 'Bypass_Account_Triggers', null);
	 * ```
	 */
	@TestVisible
	private static TriggerSetting__mdt newTriggerSetting(String objectApiName, String bypassPermission, String requiredPermission)
	{
		Map<SObjectField, Object> fieldOverrides = new Map<SObjectField, Object>();
		if(String.isNotBlank(bypassPermission))
		{
			fieldOverrides.put(TriggerSetting__mdt.BypassFeatureFlag__c, newFeatureFlag(bypassPermission, false));
		}
		if(String.isNotBlank(requiredPermission))
		{
			fieldOverrides.put(TriggerSetting__mdt.RequiredFeatureFlag__c, newFeatureFlag(requiredPermission, false));
		}
		return newTriggerSetting(objectApiName, fieldOverrides);
	}

	/**
	 * @description Creates an uncommitted TriggerSetting__mdt record for testing with additional field overrides.
	 * Base method that all other newTriggerSetting overloads delegate to.
	 *
	 * @param objectApiName The API name of the object this setting applies to
	 * @param fieldOverrides Map of additional field overrides to apply
	 *
	 * @return An uncommitted TriggerSetting__mdt record
	 *
	 * @example
	 * ```apex
	 * TriggerSetting__mdt setting = TST_Factory.newTriggerSetting('Account', new Map<SObjectField, Object>{
	 *     TriggerSetting__mdt.BypassFeatureFlag__c => TST_Factory.newFeatureFlag('Bypass_Account_Triggers'),
	 *     TriggerSetting__mdt.RequiredFeatureFlag__c => TST_Factory.newFeatureFlag('Required_Permission')
	 * });
	 * ```
	 */
	@TestVisible
	private static TriggerSetting__mdt newTriggerSetting(String objectApiName, Map<SObjectField, Object> fieldOverrides)
	{
		return (TriggerSetting__mdt)TST_Builder.of(TriggerSetting__mdt.SObjectType)
				.withOverride(TriggerSetting__mdt.SObjectType__c, objectApiName)
				.withOverrides(fieldOverrides)
				.withoutInsertion(true)
				.build();
	}

	/**
	 * @description Creates an uncommitted TriggerAction__mdt record for testing.
	 * The action is configured for Before Insert context by default.
	 *
	 * @param apexClassName The name of the Apex class that implements the trigger action
	 * @param triggerSetting The TriggerSetting__mdt record to associate with this action
	 *
	 * @return An uncommitted TriggerAction__mdt record
	 *
	 * @example
	 * ```apex
	 * TriggerSetting__mdt setting = TST_Factory.newTriggerSetting('Account');
	 * TriggerAction__mdt action = TST_Factory.newTriggerAction('TRG_AccountSetDefaults', setting);
	 * ```
	 */
	@TestVisible
	private static TriggerAction__mdt newTriggerAction(String apexClassName, TriggerSetting__mdt triggerSetting)
	{
		return newTriggerActionForContext(apexClassName, triggerSetting, TriggerOperation.BEFORE_INSERT);
	}

	/**
	 * @description Creates an uncommitted TriggerAction__mdt record for testing with feature flag fields.
	 * The action is configured for Before Insert context by default.
	 *
	 * @param apexClassName The name of the Apex class that implements the trigger action
	 * @param triggerSetting The TriggerSetting__mdt record to associate with this action
	 * @param bypassPermission Optional bypass feature flag DeveloperName
	 * @param requiredPermission Optional required feature flag DeveloperName
	 *
	 * @return An uncommitted TriggerAction__mdt record
	 *
	 * @example
	 * ```apex
	 * TriggerSetting__mdt setting = TST_Factory.newTriggerSetting('Account');
	 * TriggerAction__mdt action = TST_Factory.newTriggerAction('TRG_AccountSetDefaults', setting, 'Bypass_Set_Defaults', null);
	 * ```
	 */
	@TestVisible
	private static TriggerAction__mdt newTriggerAction(String apexClassName, TriggerSetting__mdt triggerSetting, String bypassPermission, String requiredPermission)
	{
		return newTriggerActionForContext(apexClassName, triggerSetting, TriggerOperation.BEFORE_INSERT, bypassPermission, requiredPermission);
	}

	/**
	 * @description Creates an uncommitted TriggerAction__mdt record for a specific trigger context.
	 * Use this when you need to specify the trigger context (before/after insert/update/delete/undelete).
	 *
	 * @param apexClassName The name of the Apex class that implements the trigger action
	 * @param triggerSetting The TriggerSetting__mdt record to associate with this action
	 * @param context The System.TriggerOperation enum value
	 *
	 * @return An uncommitted TriggerAction__mdt record
	 *
	 * @example
	 * ```apex
	 * TriggerSetting__mdt setting = TST_Factory.newTriggerSetting('Account');
	 * TriggerAction__mdt action = TST_Factory.newTriggerActionForContext('TRG_AccountAfterDelete', setting, TriggerOperation.AFTER_DELETE);
	 * ```
	 */
	@TestVisible
	private static TriggerAction__mdt newTriggerActionForContext(String apexClassName, TriggerSetting__mdt triggerSetting, TriggerOperation context)
	{
		return newTriggerActionForContext(apexClassName, triggerSetting, context, null, null);
	}

	/**
	 * @description Creates an uncommitted TriggerAction__mdt record for a specific trigger context with feature flag fields.
	 *
	 * @param apexClassName The name of the Apex class that implements the trigger action
	 * @param triggerSetting The TriggerSetting__mdt record to associate with this action
	 * @param context The System.TriggerOperation enum value
	 * @param bypassPermission Optional bypass feature flag DeveloperName
	 * @param requiredPermission Optional required feature flag DeveloperName
	 *
	 * @return An uncommitted TriggerAction__mdt record
	 */
	@TestVisible
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private static TriggerAction__mdt newTriggerActionForContext
			(
					String apexClassName,
					TriggerSetting__mdt triggerSetting,
					TriggerOperation context,
					String bypassPermission,
					String requiredPermission
			)
	{
		TST_Builder.Builder builder = TST_Builder.of(TriggerAction__mdt.SObjectType)
				.withOverride(TriggerAction__mdt.TriggerSetting__c, triggerSetting)
				.withOverride(TriggerAction__mdt.ApexClassName__c, apexClassName)
				.withOverride(TriggerAction__mdt.AllowRecursion__c, true)
				.withOverride(TriggerAction__mdt.AllowNonSelfInitiated__c, true)
				.withOverride(TriggerAction__mdt.Order__c, 1)
				.withOverride(TriggerAction__mdt.BypassExecution__c, false)
				.withOverride(TriggerAction__mdt.DeveloperName, apexClassName)
				.withOverride(TriggerAction__mdt.Event__c, OPERATION_TO_EVENT.get(context));
		if(String.isNotBlank(bypassPermission))
		{
			builder = builder.withOverride(TriggerAction__mdt.BypassFeatureFlag__c, newFeatureFlag(bypassPermission, false));
		}
		if(String.isNotBlank(requiredPermission))
		{
			builder = builder.withOverride(TriggerAction__mdt.RequiredFeatureFlag__c, newFeatureFlag(requiredPermission, false));
		}
		return (TriggerAction__mdt)builder.withoutInsertion().build();
	}

	/**
	 * @description Attaches trigger actions to an uncommitted trigger setting as its child records, in the shape a
	 * query of the setting with its actions returns. Register the result with TST_Mock.register, and the trigger
	 * framework runs those actions for the setting's object in the test.
	 *
	 * @param triggerSetting The uncommitted TriggerSetting__mdt record.
	 * @param triggerActions The uncommitted TriggerAction__mdt records to attach, in the order the trigger framework
	 * should see them.
	 *
	 * @return A new TriggerSetting__mdt record with the same fields that carries the actions as its child records.
	 *
	 * @example
	 * ```apex
	 * TriggerSetting__mdt setting = TST_Factory.newTriggerSetting('Account');
	 * TriggerAction__mdt action = TST_Factory.newTriggerActionForContext('TRG_AccountAfterInsert', setting, TriggerOperation.AFTER_INSERT);
	 * TST_Mock.register(TriggerSetting__mdt.SObjectType, TST_Factory.newTriggerSettingWithActions(setting, new List<TriggerAction__mdt> {action}));
	 * ```
	 */
	@TestVisible
	private static TriggerSetting__mdt newTriggerSettingWithActions(TriggerSetting__mdt triggerSetting, List<TriggerAction__mdt> triggerActions)
	{
		String relationshipName;
		for(ChildRelationship relationship : UTIL_SObjectDescribe.getDescribe(TriggerSetting__mdt.SObjectType).getDescribe().getChildRelationships())
		{
			if(relationship.getChildSObject() == TriggerAction__mdt.SObjectType)
			{
				relationshipName = relationship.getRelationshipName();
				break;
			}
		}
		Assert.isNotNull(relationshipName, 'TriggerSetting__mdt has no child relationship to TriggerAction__mdt');
		List<Object> actionRecords = new List<Object>();
		for(TriggerAction__mdt triggerAction : triggerActions)
		{
			actionRecords.add(triggerAction.getPopulatedFieldsAsMap());
		}
		Map<String, Object> settingFields = new Map<String, Object>(triggerSetting.getPopulatedFieldsAsMap());
		settingFields.put(relationshipName, new Map<String, Object>
		{
				JSON_TOTAL_SIZE => actionRecords.size(),
				JSON_DONE => true,
				JSON_RECORDS => actionRecords
		});
		return (TriggerSetting__mdt)JSON.deserialize(JSON.serialize(settingFields), TriggerSetting__mdt.class);
	}

	/**
	 * @description Creates a pre-configured SObjectBuilder for LogEntry__c.
	 *
	 * @return A TST_Builder.Builder instance.
	 */
	private static TST_Builder.Builder getLogEntryBuilder()
	{
		List<Object> fieldsToDefault = new List<Object>
		{
				LogEntry__c.ClassMethod__c
		};
		return TST_Builder.of(LogEntry__c.SObjectType)
				.withDefaultedFields(fieldsToDefault);
	}

	/**
	 * @description Builds and inserts a single LogEntry__c row with the given field overrides, so test
	 * classes seed forensic and rollup log rows through one place instead of repeating the builder chain.
	 *
	 * @param fieldValues The field overrides to apply to the row.
	 *
	 * @return The inserted LogEntry__c row, with its Id populated.
	 *
	 * @example
	 * ```apex
	 * LogEntry__c row = TST_Factory.seedLogEntry(new Map<SObjectField, Object> {LogEntry__c.LogLevel__c => 'ERROR'});
	 * ```
	 */
	@TestVisible
	private static LogEntry__c seedLogEntry(Map<SObjectField, Object> fieldValues)
	{
		return (LogEntry__c)TST_Builder.of(LogEntry__c.SObjectType).withOverrides(fieldValues).build();
	}

	/**
	 * @description Builds and inserts a rollup: counter LogEntry__c row for a base fingerprint and UTC day
	 * bucket, mirroring the production flood-control rollup key shape, so the rollup builder lives in one
	 * place rather than being repeated across the Log Console tests.
	 *
	 * @param base The base fingerprint (without the rollup: prefix or the day suffix).
	 * @param dayBucket The yyyyMMdd UTC day bucket.
	 * @param level The log level for the rollup row.
	 * @param occurrenceCount The OccurrenceCount__c carried by the rollup row.
	 *
	 * @return The inserted rollup LogEntry__c row, with its Id populated.
	 *
	 * @example
	 * ```apex
	 * LogEntry__c rollup = TST_Factory.seedLogRollup('NullPointer:MyClass.method', '20260626', 'ERROR', 9);
	 * ```
	 */
	@TestVisible
	private static LogEntry__c seedLogRollup(String base, String dayBucket, String level, Integer occurrenceCount)
	{
		return seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.Fingerprint__c => 'rollup:' + base + ':' + dayBucket,
				LogEntry__c.LogLevel__c => level,
				LogEntry__c.OccurrenceCount__c => occurrenceCount
		});
	}

	/**
	 * @description Creates a pre-configured SObjectBuilder for Foobar__c with common fields.
	 *
	 * @return A TST_Builder.Builder instance.
	 */
	@TestVisible
	private static TST_Builder.Builder getFoobarBuilder()
	{
		List<Object> fieldsToDefault = new List<Object>
		{
				Foobar__c.Checkbox__c,
				Foobar__c.Datetime__c,
				Foobar__c.Email__c,
				Foobar__c.ExternalId__c,
				Foobar__c.Name,
				Foobar__c.NumberInteger__c,
				Foobar__c.Phone__c,
				Foobar__c.Picklist__c,
				Foobar__c.Text__c
		};

		// Stamp DefaultFoobar only when it is available to the running user. A subscriber org may not
		// assign this packaged record type to the running profile; stamping it anyway fails the insert
		// with INVALID_CROSS_REFERENCE_KEY, so fall back to the master record type when it is unavailable.
		String recordTypeDeveloperName = UTIL_SObjectDescribe.isRecordTypeAvailable(Foobar__c.SObjectType, SEL_Foobar.RT_DEFAULT) ? SEL_Foobar.RT_DEFAULT : null;

		return TST_Builder.of(Foobar__c.SObjectType)
				.withDefaultedFields(fieldsToDefault)
				.withRecordType(recordTypeDeveloperName);
	}

	/**
	 * @description Creates a pre-configured SObjectBuilder for ScheduledJob__c.
	 *
	 * @return A TST_Builder.Builder instance.
	 */
	private static TST_Builder.Builder getScheduledJobBuilder()
	{
		List<Object> fieldsToDefault = new List<Object>
		{
				ScheduledJob__c.Description__c,
				ScheduledJob__c.SchedulerName__c
		};

		Map<SObjectField, Object> overrides = new Map<SObjectField, Object>
		{
				ScheduledJob__c.CronExpression__c => DEFAULT_CHRON_EXPRESSION
		};

		return TST_Builder.of(ScheduledJob__c.SObjectType)
				.withDefaultedFields(fieldsToDefault)
				.withOverrides(overrides);
	}

	/**
	 * @description Creates a pre-configured SObjectBuilder for PermissionSetAssignment.
	 *
	 * @return A TST_Builder.Builder instance.
	 */
	private static TST_Builder.Builder getPermissionSetAssignmentBuilder()
	{
		return TST_Builder.of(PermissionSetAssignment.SObjectType);
	}

	/**
	 * @description Creates a pre-configured SObjectBuilder for User.
	 *
	 * @param profileName The Name of the profile to assign to the user.
	 *
	 * @return A TST_Builder.Builder instance.
	 */
	private static TST_Builder.Builder getUserBuilder(String profileName)
	{
		final String emailSeparator = '@';
		Id profileId = new SEL_Profile().findByName(profileName)?.Id;

		// Create a unique base for email/username to avoid org-to-org collision
		String randomEmail = UTIL_Random.randomEmail().toLowerCase();

		String emailPrefix = randomEmail.substringBefore(emailSeparator);
		String emailSuffix = randomEmail.substringAfter(emailSeparator);

		// Create templates using [index] for uniqueness per record
		String emailTemplate = emailPrefix + UTIL_SObjectBuilderDefaultProvider.RECORD_INDEX_REPLACEMENT_TEXT + emailSeparator + emailSuffix;

		// These fields are required or must be set with specific values
		Map<SObjectField, Object> overrides = new Map<SObjectField, Object>
		{
				User.CompanyName => TEST_USER_MARKER,
				User.Email => emailTemplate,
				User.FederationIdentifier => emailTemplate,
				User.IsActive => true,
				User.ProfileId => profileId,
				User.Username => emailTemplate
		};

		return TST_Builder.of(User.SObjectType)
				.withOverrides(overrides);
	}

	/**
	 * @description Creates a pre-configured SObjectBuilder for ApiCall__c
	 * with common fields.
	 *
	 * @return A TST_Builder.Builder instance.
	 */
	@TestVisible
	private static TST_Builder.Builder getApiCallBuilder()
	{
		Map<SObjectField, Object> baseOverrides = new Map<SObjectField, Object>
		{
				ApiCall__c.Retries__c => 0,
				ApiCall__c.Status__c => SEL_ApiCall.STATUS_QUEUED,
				ApiCall__c.LoggerContext__c => captureLoggerContextForApiCall()
		};

		return TST_Builder.of(ApiCall__c.SObjectType)
				.withOverrides(baseOverrides);
	}

	/**
	 * @description Captures current logger context for transfer to async jobs.
	 * Auto-starts a correlation if none exists, ensuring every API call is traceable.
	 *
	 * @return String Serialized logger context JSON
	 */
	private static String captureLoggerContextForApiCall()
	{
		// Auto-start correlation if none exists
		// This ensures every API call has a correlation ID for tracing
		if(String.isBlank(LOG_Builder.correlationId))
		{
			LOG_Builder.startCorrelation();
		}

		return LOG_Builder.serializeContext();
	}

	/**
	 * @description Creates a pre-configured SObjectBuilder for ApiIssue__c, with every field the outbound framework sets
	 * on the issue of a failed call (see API_Outbound.buildOutboundFailureRecord).
	 *
	 * @param apiCall The associated ApiCall__c record.
	 * @param itemHash A hash uniquely identifying the failure.
	 *
	 * @return A TST_Builder.Builder instance.
	 */
	private static TST_Builder.Builder getApiIssueBuilder(ApiCall__c apiCall, String itemHash)
	{
		return TST_Builder.of(ApiIssue__c.SObjectType)
				.withOverrides(API_Outbound.buildOutboundFailureRecord(apiCall, itemHash).getPopulatedFieldsAsMap());
	}

	/**
	 * @description Creates an inserted AsyncChainExecution__c record with the given status and chain name.
	 *
	 * @param status The execution status value.
	 * @param chainName The chain name.
	 *
	 * @return The inserted AsyncChainExecution__c record.
	 *
	 * @example
	 * ```apex
	 * AsyncChainExecution__c execution = TST_Factory.newChainExecution('Running', 'MyChain');
	 * ```
	 */
	public static AsyncChainExecution__c newChainExecution(String status, String chainName)
	{
		return (AsyncChainExecution__c)getChainExecutionBuilder(status, chainName)
				.withOverride(AsyncChainExecution__c.CorrelationId__c, UTIL_Random.randomUUID())
				.build();
	}

	/**
	 * @description Creates an inserted AsyncChainExecution__c record with step log, timing, and step counts.
	 * Use this for tests that need to inspect parsed step data or verify duration computation.
	 *
	 * @param status The execution status value.
	 * @param chainName The chain name.
	 * @param stepLog The serialized StepLog JSON (from DTO_StepDefinition list).
	 * @param totalSteps Total number of steps defined in the chain.
	 * @param completedSteps Number of steps that completed successfully.
	 *
	 * @return The inserted AsyncChainExecution__c record.
	 *
	 * @example
	 * ```apex
	 * AsyncChainExecution__c execution = TST_Factory.newChainExecution('Completed', 'MyChain', stepLogJson, 3, 3);
	 * ```
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	public static AsyncChainExecution__c newChainExecution
			(
					String status,
					String chainName,
					String stepLog,
					Integer totalSteps,
					Integer completedSteps
			)
	{
		return (AsyncChainExecution__c)getChainExecutionBuilder(status, chainName)
				.withOverride(AsyncChainExecution__c.StepLog__c, stepLog)
				.withOverride(AsyncChainExecution__c.TotalSteps__c, totalSteps)
				.withOverride(AsyncChainExecution__c.CompletedSteps__c, completedSteps)
				.withOverride(AsyncChainExecution__c.StartedAt__c, Datetime.now().addMinutes(-5))
				.withOverride(AsyncChainExecution__c.CorrelationId__c, UTIL_Random.randomUUID())
				.build();
	}

	/**
	 * @description Creates an inserted AsyncChainExecution__c record with the given status and chain name,
	 * applying the given field overrides on top of the standard defaults. Use this for tests that seed
	 * bespoke execution shapes (timing fields, run keys, step logs, context data) through the shared
	 * builder route.
	 *
	 * @param status The execution status value.
	 * @param chainName The chain name.
	 * @param fieldOverrides Field values applied on top of the defaults. An entry for a defaulted field replaces the
	 * default value. The defaulted fields are TotalSteps__c, CompletedSteps__c and CorrelationId__c, and, depending on
	 * the status, CompletedAt__c and FailureCategory__c.
	 *
	 * @return The inserted AsyncChainExecution__c record.
	 *
	 * @example
	 * ```apex
	 * AsyncChainExecution__c execution = TST_Factory.newChainExecution('Failed', 'MyChain',
	 *         new Map<SObjectField, Object> {AsyncChainExecution__c.ErrorMessage__c => 'boom'});
	 * ```
	 */
	public static AsyncChainExecution__c newChainExecution(String status, String chainName, Map<SObjectField, Object> fieldOverrides)
	{
		return (AsyncChainExecution__c)getChainExecutionBuilder(status, chainName)
				.withOverride(AsyncChainExecution__c.CorrelationId__c, UTIL_Random.randomUUID())
				.withOverrides(fieldOverrides)
				.build();
	}

	/**
	 * @description Creates and inserts a list of AsyncChainExecution__c records with the given status
	 * and chain name through a single bulk insert. Each record receives its own random correlation ID
	 * because the field is unique. Use this for tests that seed many executions at once, such as the
	 * watchdog sweep's batch-clamp coverage, instead of spending one DML statement per row.
	 *
	 * @param numberOfExecutions The number of records to create.
	 * @param status The execution status value applied to every record.
	 * @param chainName The chain name applied to every record.
	 *
	 * @return The inserted AsyncChainExecution__c records.
	 *
	 * @example
	 * ```apex
	 * List<AsyncChainExecution__c> executions = TST_Factory.newChainExecutions(60, 'Running', 'MyChain');
	 * ```
	 */
	public static List<AsyncChainExecution__c> newChainExecutions(Integer numberOfExecutions, String status, String chainName)
	{
		List<Object> correlationIds = new List<Object>();
		for(Integer index = 0; index < numberOfExecutions; index++)
		{
			correlationIds.add(UTIL_Random.randomUUID());
		}

		return getChainExecutionBuilder(status, chainName)
				.withCycle(AsyncChainExecution__c.CorrelationId__c, correlationIds)
				.withCount(numberOfExecutions)
				.buildList();
	}

	/**
	 * @description Creates a pre-configured SObjectBuilder for AsyncChainExecution__c carrying the
	 * defaults shared by every chain-execution factory: chain name, status, one total step, and zero
	 * completed steps. The defaults also match the status, so a new row is one the chain engine could
	 * have written itself. A Completed, Failed or Aborted row gets an end time (CompletedAt__c) of now.
	 * A Failed row also gets the StepException failure category, and an Aborted row the OperatorAbort
	 * category. A Running or Stalled row gets neither. An explicit override from the caller replaces
	 * any of these defaults. Callers chain their own correlation strategy, extra overrides, and terminal call.
	 *
	 * @param status The execution status value.
	 * @param chainName The chain name.
	 *
	 * @return A TST_Builder.Builder instance.
	 */
	private static TST_Builder.Builder getChainExecutionBuilder(String status, String chainName)
	{
		TST_Builder.Builder builder = TST_Builder.of(AsyncChainExecution__c.SObjectType)
				.withOverride(AsyncChainExecution__c.ChainName__c, chainName)
				.withOverride(AsyncChainExecution__c.Status__c, status)
				.withOverride(AsyncChainExecution__c.TotalSteps__c, 1)
				.withOverride(AsyncChainExecution__c.CompletedSteps__c, 0);

		if(status == SEL_AsyncChainExecution.STATUS_COMPLETED || status == SEL_AsyncChainExecution.STATUS_FAILED
				|| status == SEL_AsyncChainExecution.STATUS_ABORTED)
		{
			builder.withOverride(AsyncChainExecution__c.CompletedAt__c, Datetime.now());
		}

		if(status == SEL_AsyncChainExecution.STATUS_FAILED)
		{
			builder.withOverride(AsyncChainExecution__c.FailureCategory__c, SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION);
		}
		else if(status == SEL_AsyncChainExecution.STATUS_ABORTED)
		{
			builder.withOverride(AsyncChainExecution__c.FailureCategory__c, SEL_AsyncChainExecution.FAILURE_CATEGORY_OPERATOR_ABORT);
		}

		return builder;
	}

	/**
	 * @description Reads the class name the chain-run check (TRG_AsyncChainRunTransition) is registered under, spelled
	 * exactly as its trigger action record carries it. A package build writes that name with the package namespace in
	 * front, and the trigger dispatcher turns an action off only when the bypass spells the class the same way. So a test
	 * that must save a chain run in an old, broken shape (a Stalled run with an end time, which real orgs still hold)
	 * hands this name to TRG_Base.bypassAction and TRG_Base.clearActionBypass instead of writing the class name out. The
	 * record is package metadata every org installs: it is read in system mode, so the read does not depend on the field
	 * permissions of the user running the test, and the read keeps only the record in this package's namespace, so a
	 * record of the same name from another package or from the org itself is never picked.
	 *
	 * @return The class name the AsyncChainRunTransition_BeforeInsert record carries.
	 *
	 * @example
	 * ```apex
	 * String actionClassName = TST_Factory.getRunTransitionActionClassName();
	 * TRG_Base.bypassAction(actionClassName);
	 * try
	 * {
	 *     TST_Factory.newChainExecution('Stalled', 'MyChain', new Map<SObjectField, Object> {AsyncChainExecution__c.CompletedAt__c => Datetime.now()});
	 * }
	 * finally
	 * {
	 *     TRG_Base.clearActionBypass(actionClassName);
	 * }
	 * ```
	 */
	public static String getRunTransitionActionClassName()
	{
		String packageNamespace = UTIL_System.getManagedPackageNamespace();
		TriggerAction__mdt action = (TriggerAction__mdt)QRY_Builder.selectFrom(TriggerAction__mdt.SObjectType)
				.fields(new List<SObjectField> {TriggerAction__mdt.ApexClassName__c})
				.condition(TriggerAction__mdt.DeveloperName).equals(RUN_TRANSITION_ACTION_RECORD)
				.andCondition(TriggerAction__mdt.NamespacePrefix).equals(String.isBlank(packageNamespace) ? null : packageNamespace)
				.withSystemMode()
				.getFirst();
		return action.ApexClassName__c;
	}

	/**
	 * @description Configures the logger for testing with default settings.
	 * Disables all performance logging by default for simple tests that just need
	 * the logger configured but don't need performance metrics.
	 *
	 * @example
	 * ```apex
	 * LOG_Builder.ignoreTestMode = true;
	 * TST_Factory.setupLoggerForTest();
	 * ```
	 */
	public static void setupLoggerForTest()
	{
		newLoggerSettings().apply();
	}

	/**
	 * @description Configures the logger for testing with performance logging enabled.
	 * Sets both query and webservice logging to the same values.
	 *
	 * @param enablePerformanceLogging Whether performance logging is enabled
	 * @param performanceThresholdMs The threshold in milliseconds
	 *
	 * @example
	 * ```apex
	 * LOG_Builder.ignoreTestMode = true;
	 * TST_Factory.setupLoggerForTest(true, 0);
	 * ```
	 */
	@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
	public static void setupLoggerForTest(Boolean enablePerformanceLogging, Integer performanceThresholdMs)
	{
		setupLoggerForTest(enablePerformanceLogging, performanceThresholdMs, enablePerformanceLogging, performanceThresholdMs);
	}

	/**
	 * @description Configures the logger for testing with separate query and webservice settings.
	 *
	 * @param enableQueryLogging Whether query performance logging is enabled
	 * @param queryThresholdMs The query threshold in milliseconds
	 * @param enableWebserviceLogging Whether webservice performance logging is enabled
	 * @param webserviceThresholdMs The webservice threshold in milliseconds
	 *
	 * @example
	 * ```apex
	 * LOG_Builder.ignoreTestMode = true;
	 * TST_Factory.setupLoggerForTest(true, 0, true, 10000);
	 * ```
	 */
	@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
	public static void setupLoggerForTest
			(
					Boolean enableQueryLogging,
					Integer queryThresholdMs,
					Boolean enableWebserviceLogging,
					Integer webserviceThresholdMs
			)
	{
		LoggerSettingsBuilder settings = newLoggerSettings();
		if(enableQueryLogging == true)
		{
			settings.withQueryLogging(queryThresholdMs);
		}
		if(enableWebserviceLogging == true)
		{
			settings.withWebserviceLogging(webserviceThresholdMs);
		}
		settings.apply();
	}

	/**
	 * @description Starts the logger settings a test applies with one call: every performance log is off until a
	 * with...Logging call turns it on at the given threshold, and apply() hands the finished settings to the logger.
	 *
	 * @return A builder for the logger settings.
	 *
	 * @example
	 * ```apex
	 * LOG_Builder.ignoreTestMode = true;
	 * TST_Factory.newLoggerSettings().withTriggerLogging(50).apply();
	 * ```
	 */
	public static LoggerSettingsBuilder newLoggerSettings()
	{
		return new LoggerSettingsBuilder();
	}

	/**
	 * @description Builds the LogSetting__c record a test runs under: the logger enabled at the DEBUG threshold, every
	 * performance log off until its with...Logging call turns it on at a threshold, and apply() registers the settings
	 * with the logger for the rest of the transaction.
	 *
	 * @date September 2026
	 *
	 * @example
	 * ```apex
	 * TST_Factory.newLoggerSettings().withQueryLogging(0).withTriggerLogging(10000).apply();
	 * ```
	 */
	public inherited sharing class LoggerSettingsBuilder
	{
		/**
		 * @description The settings under construction: logger on at the DEBUG threshold, every performance log off.
		 */
		private final LogSetting__c setting = new LogSetting__c
				(
						IsEnabled__c = true,
						LogLevelThreshold__c = LoggingLevel.DEBUG.name(),
						EnableQueryPerformanceLogging__c = false,
						QueryPerformanceThresholdMs__c = 0,
						EnablePerformanceLogging__c = false,
						PerformanceThresholdMs__c = 0,
						EnableTriggerPerformanceLogging__c = false,
						TriggerPerformanceThresholdMs__c = 0,
						EnableValidationPerformanceLogging__c = false,
						ValidationPerformanceThresholdMs__c = 0,
						EnableMaskerPerformanceLogging__c = false,
						MaskerPerformanceThresholdMs__c = 0
				);

		/**
		 * @description Turns query performance logging on.
		 *
		 * @param thresholdMilliseconds The duration from which a query is logged.
		 *
		 * @return This builder.
		 *
		 * @example
		 * ```apex
		 * TST_Factory.newLoggerSettings().withQueryLogging(0).apply();
		 * ```
		 */
		public LoggerSettingsBuilder withQueryLogging(Integer thresholdMilliseconds)
		{
			setting.EnableQueryPerformanceLogging__c = true;
			setting.QueryPerformanceThresholdMs__c = thresholdMilliseconds;
			return this;
		}

		/**
		 * @description Turns web service performance logging on.
		 *
		 * @param thresholdMilliseconds The duration from which a web service call is logged.
		 *
		 * @return This builder.
		 *
		 * @example
		 * ```apex
		 * TST_Factory.newLoggerSettings().withWebserviceLogging(100).apply();
		 * ```
		 */
		public LoggerSettingsBuilder withWebserviceLogging(Integer thresholdMilliseconds)
		{
			setting.EnablePerformanceLogging__c = true;
			setting.PerformanceThresholdMs__c = thresholdMilliseconds;
			return this;
		}

		/**
		 * @description Turns trigger performance logging on.
		 *
		 * @param thresholdMilliseconds The duration from which a trigger action is logged.
		 *
		 * @return This builder.
		 *
		 * @example
		 * ```apex
		 * TST_Factory.newLoggerSettings().withTriggerLogging(50).apply();
		 * ```
		 */
		public LoggerSettingsBuilder withTriggerLogging(Integer thresholdMilliseconds)
		{
			setting.EnableTriggerPerformanceLogging__c = true;
			setting.TriggerPerformanceThresholdMs__c = thresholdMilliseconds;
			return this;
		}

		/**
		 * @description Turns validation performance logging on.
		 *
		 * @param thresholdMilliseconds The duration from which a validation run is logged.
		 *
		 * @return This builder.
		 *
		 * @example
		 * ```apex
		 * TST_Factory.newLoggerSettings().withValidationLogging(0).apply();
		 * ```
		 */
		public LoggerSettingsBuilder withValidationLogging(Integer thresholdMilliseconds)
		{
			setting.EnableValidationPerformanceLogging__c = true;
			setting.ValidationPerformanceThresholdMs__c = thresholdMilliseconds;
			return this;
		}

		/**
		 * @description Turns masking performance logging on.
		 *
		 * @param thresholdMilliseconds The duration from which a masking pass is logged.
		 *
		 * @return This builder.
		 *
		 * @example
		 * ```apex
		 * TST_Factory.newLoggerSettings().withMaskerLogging(0).apply();
		 * ```
		 */
		public LoggerSettingsBuilder withMaskerLogging(Integer thresholdMilliseconds)
		{
			setting.EnableMaskerPerformanceLogging__c = true;
			setting.MaskerPerformanceThresholdMs__c = thresholdMilliseconds;
			return this;
		}

		/**
		 * @description Registers the settings with the logger for the rest of the transaction.
		 *
		 * @example
		 * ```apex
		 * TST_Factory.newLoggerSettings().apply();
		 * ```
		 */
		public void apply()
		{
			LOG_Engine.logSettingOverride = setting;
		}
	}

	/**
	 * @description Creates an uncommitted ValidationRuleGroup__mdt with defaults.
	 * Defaults: Before Insert, auto-generated name, empty child rules.
	 *
	 * @param triggerSetting The TriggerSetting__mdt record to associate with this group
	 *
	 * @return An uncommitted ValidationRuleGroup__mdt record
	 *
	 * @example
	 * ```apex
	 * TriggerSetting__mdt setting = TST_Factory.newTriggerSetting(SEL_Foobar.OBJECT_NAME);
	 * ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup(setting);
	 * ```
	 */
	@TestVisible
	private static ValidationRuleGroup__mdt newValidationRuleGroup(TriggerSetting__mdt triggerSetting)
	{
		return newValidationRuleGroup(triggerSetting, 'Before', 'Insert', new List<ValidationRule__mdt>());
	}

	/**
	 * @description Creates an uncommitted ValidationRuleGroup__mdt with child rules.
	 * Defaults: Before Insert, auto-generated name.
	 *
	 * @param triggerSetting The TriggerSetting__mdt record to associate with this group
	 * @param childRules List of ValidationRule__mdt records to include as children
	 *
	 * @return An uncommitted ValidationRuleGroup__mdt record with child rules
	 *
	 * @example
	 * ```apex
	 * ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup(setting, new List<ValidationRule__mdt> {rule});
	 * ```
	 */
	@TestVisible
	private static ValidationRuleGroup__mdt newValidationRuleGroup
			(
					TriggerSetting__mdt triggerSetting,
					List<ValidationRule__mdt> childRules
			)
	{
		return newValidationRuleGroup(triggerSetting, 'Before', 'Insert', childRules);
	}

	/**
	 * @description Creates an uncommitted ValidationRuleGroup__mdt record for testing.
	 *
	 * @param triggerSetting The TriggerSetting__mdt record to associate with this group
	 * @param triggerTiming The trigger timing ('Before' or 'After', can be semicolon-separated)
	 * @param triggerOperations The trigger operations ('Insert', 'Update', etc., can be semicolon-separated)
	 * @param childRules List of ValidationRule__mdt records to include as children
	 *
	 * @return An uncommitted ValidationRuleGroup__mdt record with child rules
	 *
	 * @example
	 * ```apex
	 * ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup(setting, 'After', 'Update', new List<ValidationRule__mdt> {rule});
	 * ```
	 */
	@TestVisible
	private static ValidationRuleGroup__mdt newValidationRuleGroup
			(
					TriggerSetting__mdt triggerSetting,
					String triggerTiming,
					String triggerOperations,
					List<ValidationRule__mdt> childRules
			)
	{
		TST_Builder.Builder builder = TST_Builder.of(ValidationRuleGroup__mdt.SObjectType)
				.withoutInsertion()
				.withOverride(SEL_ValidationRules.RELATIONSHIP_TRIGGER_SETTING, triggerSetting)
				.withOverride(ValidationRuleGroup__mdt.TriggerTiming__c, triggerTiming)
				.withOverride(ValidationRuleGroup__mdt.TriggerOperations__c, triggerOperations);

		if(childRules != null && !childRules.isEmpty())
		{
			builder = builder.withOverride(SEL_ValidationRules.RELATIONSHIP_VALIDATION_RULES, childRules);
		}

		return (ValidationRuleGroup__mdt)builder.build();
	}

	/**
	 * @description Creates an uncommitted ValidationRuleGroup__mdt record with a context class.
	 * Convenience overload for the common case of just setting ContextClassName__c.
	 *
	 * @param triggerSetting The TriggerSetting__mdt record to associate with this group
	 * @param contextClassName The formula context class name (e.g., 'UTIL_FormulaContext.FoobarContext')
	 *
	 * @return An uncommitted ValidationRuleGroup__mdt record
	 *
	 * @example
	 * ```apex
	 * TriggerSetting__mdt setting = TST_Factory.newTriggerSetting(SEL_Foobar.OBJECT_NAME);
	 * ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup(setting, UTIL_FormulaContext.FoobarContext.class.getName());
	 * ```
	 */
	@TestVisible
	private static ValidationRuleGroup__mdt newValidationRuleGroup(TriggerSetting__mdt triggerSetting, String contextClassName)
	{
		return newValidationRuleGroup
				(
						triggerSetting,
						new Map<SObjectField, Object>
						{
								ValidationRuleGroup__mdt.ContextClassName__c => contextClassName
						}
				);
	}

	/**
	 * @description Creates an uncommitted ValidationRuleGroup__mdt record with field overrides.
	 * Calls the base overload and then applies additional field overrides.
	 * Allows any field customization including ContextClassName__c.
	 *
	 * @param triggerSetting The TriggerSetting__mdt record to associate with this group
	 * @param fieldOverrides Map of additional fields to override from defaults
	 *
	 * @return An uncommitted ValidationRuleGroup__mdt record
	 *
	 * @example
	 * ```apex
	 * TriggerSetting__mdt setting = TST_Factory.newTriggerSetting(SEL_Foobar.OBJECT_NAME);
	 * ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup(setting, new Map<SObjectField, Object>{
	 *     ValidationRuleGroup__mdt.ContextClassName__c => 'UTIL_FormulaContext.FoobarContext'
	 * });
	 * ```
	 */
	@TestVisible
	private static ValidationRuleGroup__mdt newValidationRuleGroup(TriggerSetting__mdt triggerSetting, Map<SObjectField, Object> fieldOverrides)
	{
		return newValidationRuleGroup(triggerSetting, new List<ValidationRule__mdt>(), fieldOverrides);
	}

	/**
	 * @description Creates an uncommitted ValidationRuleGroup__mdt record with child rules and field overrides.
	 * Defaults: Before Insert, auto-generated name; the overrides win over the defaults, so a caller can set the
	 * timing, the operations or a feature-flag relationship alongside its rules.
	 *
	 * @param triggerSetting The TriggerSetting__mdt record to associate with this group
	 * @param childRules List of ValidationRule__mdt records
	 * @param fieldOverrides Field values that win over the defaults
	 *
	 * @return An uncommitted ValidationRuleGroup__mdt record
	 *
	 * @example
	 * ```apex
	 * ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup
	 *         (
	 *                 setting,
	 *                 new List<ValidationRule__mdt> {rule},
	 *                 new Map<SObjectField, Object> {ValidationRuleGroup__mdt.TriggerOperations__c => 'Update'}
	 *         );
	 * ```
	 */
	@TestVisible
	private static ValidationRuleGroup__mdt newValidationRuleGroup
			(
					TriggerSetting__mdt triggerSetting,
					List<ValidationRule__mdt> childRules,
					Map<SObjectField, Object> fieldOverrides
			)
	{
		TST_Builder.Builder builder = TST_Builder.of(ValidationRuleGroup__mdt.SObjectType)
				.withoutInsertion()
				.withOverride(SEL_ValidationRules.RELATIONSHIP_TRIGGER_SETTING, triggerSetting)
				.withOverride(ValidationRuleGroup__mdt.TriggerTiming__c, 'Before')
				.withOverride(ValidationRuleGroup__mdt.TriggerOperations__c, 'Insert')
				.withOverrides(fieldOverrides);

		if(childRules != null && !childRules.isEmpty())
		{
			builder = builder.withOverride(SEL_ValidationRules.RELATIONSHIP_VALIDATION_RULES, childRules);
		}

		return (ValidationRuleGroup__mdt)builder.build();
	}

	/**
	 * @description Creates an uncommitted ValidationRule__mdt with auto-generated defaults.
	 *
	 * @return An uncommitted ValidationRule__mdt record
	 *
	 * @example
	 * ```apex
	 * ValidationRule__mdt rule = TST_Factory.newValidationRule();
	 * ```
	 */
	@TestVisible
	private static ValidationRule__mdt newValidationRule()
	{
		return (ValidationRule__mdt)TST_Builder.of(ValidationRule__mdt.SObjectType)
				.withoutInsertion()
				.withOverride(ValidationRule__mdt.Severity__c, UTIL_ValidationRule.SEVERITY_ERROR)
				.build();
	}

	/**
	 * @description Creates an uncommitted ValidationRule__mdt record with overrides.
	 *
	 * @param fieldOverrides Map of fields to override from defaults
	 *
	 * @return An uncommitted ValidationRule__mdt record
	 *
	 * @example
	 * ```apex
	 * ValidationRule__mdt rule = TST_Factory.newValidationRule(new Map<SObjectField, Object>{
	 *     ValidationRule__mdt.RuleFormula__c => 'ISBLANK(Email)',
	 *     ValidationRule__mdt.ErrorMessage__c => 'Email is required'
	 * });
	 * ```
	 */
	@TestVisible
	private static ValidationRule__mdt newValidationRule(Map<SObjectField, Object> fieldOverrides)
	{
		TST_Builder.Builder builder = TST_Builder.of(ValidationRule__mdt.SObjectType)
				.withoutInsertion()
				.withOverride(ValidationRule__mdt.Severity__c, UTIL_ValidationRule.SEVERITY_ERROR);

		for(SObjectField field : fieldOverrides.keySet())
		{
			builder = builder.withOverride(field, fieldOverrides.get(field));
		}

		return (ValidationRule__mdt)builder.build();
	}

	/**
	 * @description Creates an uncommitted ValidationRule__mdt record for testing.
	 *
	 * @param developerName The developer name for the rule
	 * @param ruleFormula The formula expression to evaluate
	 * @param errorMessage The error message to display when rule fails
	 *
	 * @return An uncommitted ValidationRule__mdt record
	 *
	 * @example
	 * ```apex
	 * ValidationRule__mdt rule = TST_Factory.newValidationRule('RequireEmail', 'ISBLANK(Email)', 'Email is required');
	 * ```
	 */
	@TestVisible
	private static ValidationRule__mdt newValidationRule(String developerName, String ruleFormula, String errorMessage)
	{
		return newValidationRule
				(
						new Map<SObjectField, Object>
						{
								ValidationRule__mdt.DeveloperName => developerName,
								ValidationRule__mdt.RuleFormula__c => ruleFormula,
								ValidationRule__mdt.ErrorMessage__c => errorMessage
						}
				);
	}

}