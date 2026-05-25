// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Utility methods used to initialize adaptive async jobs to update fields on multiple objects.
 * Provides methods for bulk updating Salesforce records, such as invalidating email fields, updating ownership,
 * and deactivating users. Operations are performed using adaptive async processing which automatically selects
 * between Queueable and Batch execution based on data volume and governor limits.
 *
 * All entry points inherit the flag-driven default `AccessLevel` resolved by
 * `DML_SharingProxy.defaultAccessLevel()` — under the secure-by-default posture this is
 * `USER_MODE`, so the invoking user must have CRUD and FLS on the target object and fields for the
 * bulk update to succeed. This is deliberate: `UTIL_BulkUpdates` is `global`, and silently elevating
 * to SYSTEM_MODE would let a low-privilege subscriber Apex caller mutate records and fields they
 * have no native right to edit. Integrations that genuinely need admin-mandate semantics should
 * construct a `PROC_UpdateFields` directly with `DTO_Parameters.accessLevel = AccessLevel.SYSTEM_MODE`
 * behind a caller-side permission check; the framework declines to make that elevation implicit.
 *
 * @see PROC_UpdateFields
 * @see UTIL_BulkUpdates_TEST
 *
 * @author Jason van Beukering
 *
 * @group Bulk DML
 *
 * @date February 2026, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * UTIL_BulkUpdates.invalidateEmailFields(Contact.Email);
 * UTIL_BulkUpdates.updateOwner('Opportunity', 'Sales Rep', 'admin@example.com');
 * UTIL_BulkUpdates.deactivateUsers(new Set<String>{'Chatter Free User'}, 365);
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier,PMD.AvoidBooleanMethodParameters')
global inherited sharing class UTIL_BulkUpdates
{
	/**
	 * @description Search condition used to identify records with valid email addresses.
	 * Checks for email addresses that do not contain the substring 'invalid'.
	 */
	@TestVisible
	private static final String INVALID_EMAIL_FIELD_CONDITION = '%@%invalid%';

	/**
	 * @description Invalidates all valid email addresses for the specified email field.
	 * Uses the maximum batch size for efficient processing.
	 *
	 * @param emailFieldToInvalidate The email field to query and invalidate in records.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * SObjectField emailField = Account.Email;
	 * UTIL_BulkUpdates.invalidateEmailFields(emailField);
	 * ```
	 */
	global static void invalidateEmailFields(SObjectField emailFieldToInvalidate)
	{
		invalidateEmailFields(emailFieldToInvalidate, UTIL_SObjectDescribe.MAXIMUM_BATCH_SIZE);
	}

	/**
	 * @description Invalidates all valid email addresses for the specified email field, with a custom batch size.
	 *
	 * @param emailFieldToInvalidate The email field to query and invalidate.
	 * @param recordsPerBatch The number of records to process in each batch.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * SObjectField emailField = Contact.Email;
	 * UTIL_BulkUpdates.invalidateEmailFields(emailField, 200);
	 * ```
	 */
	global static void invalidateEmailFields(SObjectField emailFieldToInvalidate, Integer recordsPerBatch)
	{
		invalidateEmailFields(emailFieldToInvalidate, recordsPerBatch, false);
	}

	/**
	 * @description Invalidates all valid email addresses for the specified email field, with batch size and transaction control.
	 * If isAllOrNothing is true, the entire transaction is rolled back if any record fails.
	 *
	 * @param emailFieldToInvalidate The email field to query and invalidate.
	 * @param recordsPerBatch The number of records to process in each batch.
	 * @param isAllOrNothing Whether to abort the transaction on failure (true = abort on any failure).
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * SObjectField emailField = Lead.Email;
	 * UTIL_BulkUpdates.invalidateEmailFields(emailField, 100, true);
	 * ```
	 */
	global static void invalidateEmailFields(SObjectField emailFieldToInvalidate, Integer recordsPerBatch, Boolean isAllOrNothing)
	{
		DescribeFieldResult fieldDescribe = emailFieldToInvalidate.getDescribe();
		invalidateEmailFields
				(
						UTIL_SObjectDescribe.getObjectNameFromType(fieldDescribe.SObjectType),
						fieldDescribe.name,
						recordsPerBatch,
						isAllOrNothing
				);
	}

	/**
	 * @description Invalidates all valid email addresses for the specified field in a Salesforce object.
	 * Uses the maximum batch size for processing.
	 *
	 * @param sObjectName The name of the Salesforce object (e.g., 'Account').
	 * @param fieldApiName The API name of the field (e.g., 'Email') to check and invalidate.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_BulkUpdates.invalidateEmailFields('Account', 'Email');
	 * ```
	 */
	global static void invalidateEmailFields(String sObjectName, String fieldApiName)
	{
		invalidateEmailFields(sObjectName, fieldApiName, false);
	}

	/**
	 * @description Invalidates all valid email addresses for the specified field in a Salesforce object, with transaction control.
	 *
	 * @param sObjectName The name of the Salesforce object (e.g., 'Opportunity').
	 * @param fieldApiName The API name of the field (e.g., 'Email') to check and invalidate.
	 * @param isAllOrNothing Whether to abort the transaction on failure.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_BulkUpdates.invalidateEmailFields('Opportunity', 'Email', true);
	 * ```
	 */
	global static void invalidateEmailFields(String sObjectName, String fieldApiName, Boolean isAllOrNothing)
	{
		invalidateEmailFields(sObjectName, fieldApiName, UTIL_SObjectDescribe.MAXIMUM_BATCH_SIZE, isAllOrNothing);
	}

	/**
	 * @description Invalidates all valid email addresses for the specified field in a Salesforce object, with custom batch size and transaction control.
	 *
	 * @param sObjectName The name of the Salesforce object (e.g., 'Case').
	 * @param fieldApiName The API name of the field (e.g., 'Email') to check and invalidate.
	 * @param recordsPerBatch The number of records to process in each batch.
	 * @param isAllOrNothing Whether to abort the transaction on failure.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_BulkUpdates.invalidateEmailFields('Case', 'Email', 500, false);
	 * ```
	 */
	global static void invalidateEmailFields(String sObjectName, String fieldApiName, Integer recordsPerBatch, Boolean isAllOrNothing)
	{
		PROC_UpdateFields.DTO_Parameters parameters = new PROC_UpdateFields.DTO_Parameters();

		parameters.objectName = sObjectName;
		parameters.allOrNothing = isAllOrNothing ?? false;

		PROC_UpdateFields.DTO_Field fieldUpdate = new PROC_UpdateFields.DTO_Field();

		fieldUpdate.name = fieldApiName;
		fieldUpdate.value = SEL_User.INVALID_EMAIL_SUFFIX;
		fieldUpdate.updateMethod = PROC_UpdateFields.FieldUpdateMethod.SUFFIX;

		parameters.updateFields.add(fieldUpdate);

		parameters.searchConditions = new QRY_Condition.AndCondition()
				.add(new QRY_Condition.NotCondition(new QRY_Condition.FieldCondition(fieldApiName).likeX(INVALID_EMAIL_FIELD_CONDITION)))
				.add(new QRY_Condition.FieldCondition(fieldApiName).notEquals(null));

		PROC_UpdateFields processor = new PROC_UpdateFields(parameters);
		IF_Queryable queryable = processor.buildQueryable();

		UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request =
				new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(queryable)
						.withBatchSize(recordsPerBatch ?? UTIL_SObjectDescribe.MAXIMUM_BATCH_SIZE);

		UTIL_AsynchronousJobLauncher.process(request, processor);
	}

	/**
	 * @description Updates the ownership of records based on the existing owner profile name and new owner username.
	 * Uses the maximum batch size for processing.
	 *
	 * @param sObjectName The name of the Salesforce object (e.g., 'Opportunity').
	 * @param existingOwnerProfileName The profile name of the current record owners.
	 * @param newOwnerUsername The username of the new owner to assign to the records.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_BulkUpdates.updateOwner('Opportunity', 'Sales Rep', 'john.doe@example.com');
	 * ```
	 */
	global static void updateOwner(String sObjectName, String existingOwnerProfileName, String newOwnerUsername)
	{
		updateOwner(sObjectName, existingOwnerProfileName, newOwnerUsername, UTIL_SObjectDescribe.MAXIMUM_BATCH_SIZE, false);
	}

	/**
	 * @description Updates the ownership of records based on the current owner profile, new owner username, batch size, and transaction control.
	 *
	 * @param sObjectName The name of the Salesforce object (e.g., 'Account').
	 * @param existingOwnerProfileName The profile name of the current record owners.
	 * @param newOwnerUsername The username of the new owner to assign to the records.
	 * @param recordsPerBatch The number of records to process in each batch.
	 * @param isAllOrNothing Whether to abort the transaction on failure.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_BulkUpdates.updateOwner('Account', 'Support Rep', 'jane.smith@example.com', 200, true);
	 * ```
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	global static void updateOwner
			(
					String sObjectName,
					String existingOwnerProfileName,
					String newOwnerUsername,
					Integer recordsPerBatch,
					Boolean isAllOrNothing
			)
	{
		List<User> activeUsers = new SEL_User().findActiveByProfileName(existingOwnerProfileName);

		QRY_Condition.Evaluable searchConditions = new QRY_Condition.AndCondition()
				.add(new QRY_Condition.SetCondition('OwnerId').inX(UTIL_SObject.extractValues(activeUsers, 'Id')));

		updateField(
				sObjectName,
				'OwnerId',
				new SEL_User().findByUsername(new Set<String> {newOwnerUsername}).iterator().next().Id,
				searchConditions,
				recordsPerBatch,
				isAllOrNothing
		);
	}

	/**
	 * @description Updates a specific field on records in a Salesforce object based on the given search conditions.
	 * Processes updates in batches with control over partial transaction behavior.
	 *
	 * @param sObjectName The name of the Salesforce object (e.g., 'Opportunity').
	 * @param fieldApiName The API name of the field to update.
	 * @param fieldValue The new value to set for the field.
	 * @param searchConditions The conditions used to find the records to update.
	 * @param recordsPerBatch The number of records to process in each batch.
	 * @param isAllOrNothing Whether to abort the transaction on failure.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * QRY_Condition.Evaluable condition = new QRY_Condition.AndCondition()
	 * 		.add(new QRY_Condition.FieldCondition('Status').equals('Closed'));
	 * UTIL_BulkUpdates.updateField('Opportunity', 'OwnerId', '005D0000001ABCD', condition, 100, false);
	 * ```
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	global static void updateField(
			String sObjectName,
			String fieldApiName,
			Object fieldValue,
			QRY_Condition.Evaluable searchConditions,
			Integer recordsPerBatch,
			Boolean isAllOrNothing
	)
	{
		PROC_UpdateFields.DTO_Parameters parameters = new PROC_UpdateFields.DTO_Parameters();

		parameters.allOrNothing = isAllOrNothing ?? false;
		parameters.objectName = sObjectName;
		parameters.searchConditions = searchConditions;

		PROC_UpdateFields.DTO_Field fieldUpdate = new PROC_UpdateFields.DTO_Field();

		fieldUpdate.name = fieldApiName;
		fieldUpdate.value = fieldValue;

		parameters.updateFields.add(fieldUpdate);

		PROC_UpdateFields processor = new PROC_UpdateFields(parameters);
		IF_Queryable queryable = processor.buildQueryable();

		UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request =
				new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(queryable)
						.withBatchSize(recordsPerBatch);

		UTIL_AsynchronousJobLauncher.process(request, processor);
	}

	/**
	 * @description Deactivates users based on their profile names and the number of days since their last login or creation.
	 * Uses the maximum batch size for processing.
	 *
	 * @param profileNames The profile names of the users to deactivate.
	 * @param minimumDaysInactive The minimum number of days since their last login or creation.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Set<String> profiles = new Set<String>{'Sales Rep', 'Support Rep'};
	 * UTIL_BulkUpdates.deactivateUsers(profiles, 365);
	 * ```
	 */
	global static void deactivateUsers(Set<String> profileNames, Integer minimumDaysInactive)
	{
		deactivateUsers(profileNames, minimumDaysInactive, false);
	}

	/**
	 * @description Deactivates users based on their profile names and last login or creation date, with transaction control.
	 *
	 * @param profileNames The profile names of the users to deactivate.
	 * @param minimumDaysInactive The minimum number of days since their last login or creation.
	 * @param isAllOrNothing Whether to abort the operation if any record fails.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Set<String> profiles = new Set<String>{'Support Rep'};
	 * UTIL_BulkUpdates.deactivateUsers(profiles, 180, true);
	 * ```
	 */
	global static void deactivateUsers(Set<String> profileNames, Integer minimumDaysInactive, Boolean isAllOrNothing)
	{
		deactivateUsers(profileNames, minimumDaysInactive, UTIL_SObjectDescribe.MAXIMUM_BATCH_SIZE, isAllOrNothing);
	}

	/**
	 * @description Deactivates users based on their profile names and last login or creation date, with custom batch size and transaction control.
	 *
	 * @param profileNames The profile names of the users to deactivate.
	 * @param minimumDaysInactive The minimum number of days since their last login or creation.
	 * @param recordsPerBatch The number of records to process in each batch.
	 * @param isAllOrNothing Whether to abort the operation if any record fails.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Set<String> profiles = new Set<String>{'Sales Rep'};
	 * UTIL_BulkUpdates.deactivateUsers(profiles, 90, 200, false);
	 * ```
	 */
	global static void deactivateUsers
			(
					Set<String> profileNames,
					Integer minimumDaysInactive,
					Integer recordsPerBatch,
					Boolean isAllOrNothing
			)
	{
		QRY_Condition.DateLiteral minimumDate = new QRY_Condition.DateLiteral().last(
				minimumDaysInactive - 1,
				QRY_Condition.UnitOfTime.DAY
		);
		QRY_Condition.Evaluable searchConditions = new QRY_Condition.AndCondition()
				.add(new QRY_Condition.FieldCondition('CreatedDate').lessThan(minimumDate))
				.add(new QRY_Condition.SetCondition(SEL_User.FIELD_PROFILE_NAME).inX(UTIL_Set.toList(profileNames)))
				.add(new QRY_Condition.FieldCondition(SEL_User.FIELD_IS_ACTIVE).equals(true))
				.add(new QRY_Condition.OrCondition()
						.add(new QRY_Condition.FieldCondition(SEL_User.FIELD_LAST_LOGIN_DATE).equals(null))
						.add(new QRY_Condition.FieldCondition(SEL_User.FIELD_LAST_LOGIN_DATE).lessThan(minimumDate))
				);

		updateField
				(
						SEL_User.OBJECT_NAME,
						SEL_User.FIELD_IS_ACTIVE,
						false,
						searchConditions,
						recordsPerBatch,
						isAllOrNothing
				);
	}
}