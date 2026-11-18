// SPDX-License-Identifier: Apache-2.0
/**
 * @description Utility methods used to initialize adaptive async jobs to update fields on multiple objects.
 * Provides methods for bulk updating Salesforce records, such as invalidating email fields, updating ownership,
 * and deactivating users. Operations are performed using adaptive async processing which automatically selects
 * between Queueable and Batch execution based on data volume and governor limits.
 *
 * Every method here uses the default access level that `DML_SharingProxy.defaultAccessLevel()` returns. That level
 * comes from the package's feature settings, and by default it is `USER_MODE`. In user mode, the user who calls the
 * method must be able to edit the object and each field it changes, or the bulk update fails. This is on purpose:
 * `UTIL_BulkUpdates` is `global`, and if it moved to `SYSTEM_MODE` on its own, Apex code run by a user with few
 * rights could change records and fields that the user cannot edit. Code that must change records whatever the
 * user's rights should first check the user's permission itself, then build a `PROC_UpdateFields` with
 * `DTO_Parameters.accessLevel = AccessLevel.SYSTEM_MODE`. The package never makes that change for you.
 *
 * copyField also needs the user to be able to read the field it copies from, and to edit the field it copies into,
 * whatever the feature settings say.
 *
 * @see PROC_UpdateFields
 * @see UTIL_BulkUpdates_TEST
 *
 * @author Jason van Beukering
 *
 * @group Bulk DML
 *
 * @date February 2026, November 2026
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
@SuppressWarnings('PMD.AvoidGlobalModifier,PMD.AvoidBooleanMethodParameters,PMD.CognitiveComplexity')
global inherited sharing class UTIL_BulkUpdates
{
	/**
	 * @description Search condition used to identify records with valid email addresses.
	 * Checks for email addresses that do not contain the substring 'invalid'.
	 */
	@TestVisible
	private static final String INVALID_EMAIL_FIELD_CONDITION = '%@%invalid%';

	/**
	 * @description The message when copyField is given a field that the object does not have. It is for developers only.
	 * {0} is the field name and {1} the object name.
	 */
	private static final String MESSAGE_MISSING_FIELD = 'copyField cannot find the field {0} on the object {1}.';

	/**
	 * @description The message when copyField is given a target field that cannot take a value of the source field's type.
	 * It is for developers only. {0} is the source field name and {1} the target field name.
	 */
	private static final String MESSAGE_VALUE_CANNOT_BE_COPIED = 'copyField cannot copy the field {0} into the field {1}: '
			+ 'the target cannot take a value of that type, and the save of every row in the chunk would fail. A text field takes '
			+ 'text or a record Id, as does a lookup field, a decimal number field takes any number, a whole number field takes only a '
			+ 'whole number, and a date, date and time, or checkbox field takes only its own type.';

	/**
	 * @description The message when copyField is given the same field to copy from and to copy into. It is for developers
	 * only. {0} is the field name.
	 */
	private static final String MESSAGE_SAME_FIELD = 'copyField cannot copy the field {0} into itself: the source and the target '
			+ 'must be two different fields.';

	/**
	 * @description The message when copyField is given a target field that the running user cannot change, such as a
	 * formula field, a roll-up summary field, an auto number field or a field set by Salesforce. It is for developers
	 * only. {0} is the target field name.
	 */
	private static final String MESSAGE_TARGET_NOT_WRITABLE = 'copyField cannot copy into the field {0}: the running user cannot '
			+ 'change that field, and the save of every row in the chunk would fail.';

	/**
	 * @description The message when copyField is given a source field that the running user cannot read. It is for
	 * developers only. {0} is the source field name.
	 */
	private static final String MESSAGE_SOURCE_NOT_READABLE = 'copyField cannot copy from the field {0}: the running user cannot '
			+ 'read that field, so the copy would show its values in a field the user can read.';

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
		PROC_UpdateFields.DTO_Field fieldUpdate = new PROC_UpdateFields.DTO_Field();

		fieldUpdate.name = fieldApiName;
		fieldUpdate.value = SEL_User.INVALID_EMAIL_SUFFIX;
		fieldUpdate.updateMethod = PROC_UpdateFields.FieldUpdateMethod.SUFFIX;

		QRY_Condition.Evaluable searchConditions = new QRY_Condition.AndCondition()
				.add(new QRY_Condition.NotCondition(new QRY_Condition.FieldCondition(fieldApiName).likeX(INVALID_EMAIL_FIELD_CONDITION)))
				.add(new QRY_Condition.FieldCondition(fieldApiName).notEquals(null));

		startFieldUpdate(newParameters(sObjectName, searchConditions, isAllOrNothing), fieldUpdate, recordsPerBatch ?? UTIL_SObjectDescribe.MAXIMUM_BATCH_SIZE);
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
	@SuppressWarnings('PMD.ExcessiveParameterList,PMD.GlobalMethodParameterCap')
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
	 * 		.add(new QRY_Condition.FieldCondition('StageName', QRY_Condition.Operator.EQUALS, 'Closed Won'));
	 * UTIL_BulkUpdates.updateField('Opportunity', 'OwnerId', '005D0000001ABCD', condition, 100, false);
	 * ```
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList,PMD.GlobalMethodParameterCap')
	global static void updateField(
			String sObjectName,
			String fieldApiName,
			Object fieldValue,
			QRY_Condition.Evaluable searchConditions,
			Integer recordsPerBatch,
			Boolean isAllOrNothing
	)
	{
		PROC_UpdateFields.DTO_Field fieldUpdate = new PROC_UpdateFields.DTO_Field();

		fieldUpdate.name = fieldApiName;
		fieldUpdate.value = fieldValue;

		startFieldUpdate(newParameters(sObjectName, searchConditions, isAllOrNothing), fieldUpdate, recordsPerBatch);
	}

	/**
	 * @description Copies one field into another field of the same row, on every record that matches the search
	 * conditions. Each row gets its own source value. The work runs in a background job, as with updateField.
	 *
	 * Before the job starts, the method checks that both fields exist on the object and are two different fields. It
	 * also refuses a pair of fields when the target cannot take a value of the source field's type. A text field or a
	 * lookup field takes text or a record Id. A decimal number field (number, currency or percent) takes any number. A
	 * whole number field takes only a whole number: Salesforce will not put a decimal number into it, and that error
	 * would fail every row in the chunk, not only one row. A date, a date and time, or a checkbox field takes only its
	 * own type. It refuses a source field that the running user cannot read. It also refuses a target field that the
	 * running user cannot change, such as a formula field, a roll-up summary field, an auto number field, a field set
	 * by Salesforce (for example CreatedDate), or a field the user has read-only access to. Field lengths are not
	 * compared, so you can copy a longer text field into a shorter one. A value that does not fit fails its own row
	 * when the row is saved, and so does a text value copied into a lookup field that is not a valid record Id. A
	 * failed row fails every row read with it only when isAllOrNothing is true. When that happens, a Batch run goes on
	 * with its other chunks of rows, while a run chained through queued jobs, one after another, stops at that chunk.
	 *
	 * The job runs as the user who calls this method, with that user's object, field and sharing access, unless your
	 * org has turned that check off in the package's feature settings. A row the user cannot edit is not changed.
	 *
	 * The user needs read access to the source field and edit access to the target field. These two field checks do
	 * not follow that setting: they apply either way.
	 *
	 * @param sObjectName The API name of the object (e.g., 'Contact').
	 * @param sourceFieldApiName The API name of the field to copy from.
	 * @param targetFieldApiName The API name of the field to copy into.
	 * @param searchConditions The conditions used to find the records to update, or null for every record.
	 * @param recordsPerBatch The number of records to process in each batch.
	 * @param isAllOrNothing Whether one failed row fails every row read with it.
	 *
	 * @throws IllegalArgumentException When either field does not exist on the object, both names are the same field,
	 * the target field cannot take a value of the source field's type, the running user cannot read the source field,
	 * or the running user cannot change the target field.
	 *
	 * @since 1.12
	 *
	 * @example
	 * ```apex
	 * QRY_Condition.Evaluable condition = new QRY_Condition.AndCondition()
	 * 		.add(new QRY_Condition.FieldCondition('MobilePhone', QRY_Condition.Operator.EQUALS, null))
	 * 		.add(new QRY_Condition.FieldCondition('Phone', QRY_Condition.Operator.NOT_EQUALS, null));
	 * UTIL_BulkUpdates.copyField('Contact', 'Phone', 'MobilePhone', condition, 200, false);
	 * ```
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList,PMD.GlobalMethodParameterCap')
	global static void copyField(
			String sObjectName,
			String sourceFieldApiName,
			String targetFieldApiName,
			QRY_Condition.Evaluable searchConditions,
			Integer recordsPerBatch,
			Boolean isAllOrNothing
	)
	{
		checkFieldsCanBeCopied(sObjectName, sourceFieldApiName, targetFieldApiName);

		PROC_UpdateFields.DTO_Field fieldUpdate = new PROC_UpdateFields.DTO_Field();

		fieldUpdate.name = targetFieldApiName;
		fieldUpdate.value = sourceFieldApiName;
		fieldUpdate.updateMethod = PROC_UpdateFields.FieldUpdateMethod.COPY_FROM_FIELD;

		startFieldUpdate(newParameters(sObjectName, searchConditions, isAllOrNothing), fieldUpdate, recordsPerBatch);
	}

	/**
	 * @description Builds the settings of a field update job: the object, the records to update, and what happens to
	 * the other rows when one row fails.
	 *
	 * @param sObjectName The API name of the object.
	 * @param searchConditions The conditions used to find the records to update, or null for every record.
	 * @param isAllOrNothing Whether one failed row fails every row read with it.
	 *
	 * @return The job settings, with no field update yet.
	 */
	private static PROC_UpdateFields.DTO_Parameters newParameters(String sObjectName, QRY_Condition.Evaluable searchConditions, Boolean isAllOrNothing)
	{
		PROC_UpdateFields.DTO_Parameters parameters = new PROC_UpdateFields.DTO_Parameters();

		parameters.allOrNothing = isAllOrNothing ?? false;
		parameters.objectName = sObjectName;
		parameters.searchConditions = searchConditions;

		return parameters;
	}

	/**
	 * @description Starts the background job that applies one field update to every record that matches the search
	 * conditions. invalidateEmailFields, updateField and copyField all start their jobs here.
	 *
	 * @param parameters The job settings, from newParameters.
	 * @param fieldUpdate The field to update and how.
	 * @param recordsPerBatch The number of records to process in each batch.
	 */
	private static void startFieldUpdate(PROC_UpdateFields.DTO_Parameters parameters, PROC_UpdateFields.DTO_Field fieldUpdate, Integer recordsPerBatch)
	{
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

	/**
	 * @description Checks, for copyField and before any job starts, that both fields exist on the object, are two
	 * different fields, that the target field can take a value of the source field's type, that the running user can
	 * read the source field, and that the running user can change the target field. Field lengths are not compared.
	 *
	 * The two checks on the running user's access apply whatever the package's feature settings say.
	 *
	 * @param sObjectName The API name of the object.
	 * @param sourceFieldApiName The API name of the field to copy from.
	 * @param targetFieldApiName The API name of the field to copy into.
	 *
	 * @throws IllegalArgumentException When either field does not exist on the object, both names are the same field,
	 * the target field cannot take a value of the source field's type, the running user cannot read the source field,
	 * or the running user cannot change the target field.
	 */
	private static void checkFieldsCanBeCopied(String sObjectName, String sourceFieldApiName, String targetFieldApiName)
	{
		UTIL_SObjectDescribe objectDescribe = UTIL_SObjectDescribe.getDescribe(sObjectName);
		SObjectField sourceField = getExistingField(objectDescribe, sObjectName, sourceFieldApiName);
		SObjectField targetField = getExistingField(objectDescribe, sObjectName, targetFieldApiName);

		if(sourceField == targetField)
		{
			throw new IllegalArgumentException(String.format(MESSAGE_SAME_FIELD, new List<Object> {sourceFieldApiName}));
		}

		if(!UTIL_SObjectDescribe.canCopyValue(sourceField, targetField))
		{
			throw new IllegalArgumentException(String.format(MESSAGE_VALUE_CANNOT_BE_COPIED, new List<Object> {sourceFieldApiName, targetFieldApiName}));
		}

		if(!UTIL_SObjectDescribe.isFieldAccessible(sourceField))
		{
			throw new IllegalArgumentException(String.format(MESSAGE_SOURCE_NOT_READABLE, new List<Object> {sourceFieldApiName}));
		}

		if(!UTIL_SObjectDescribe.isFieldUpdateable(targetField))
		{
			throw new IllegalArgumentException(String.format(MESSAGE_TARGET_NOT_WRITABLE, new List<Object> {targetFieldApiName}));
		}
	}

	/**
	 * @description Finds a field of the object for copyField.
	 *
	 * @param objectDescribe The describe of the object, or null when the object does not exist.
	 * @param sObjectName The API name of the object, for the error message.
	 * @param fieldApiName The API name of the field.
	 *
	 * @return The field.
	 *
	 * @throws IllegalArgumentException When the object does not have the field.
	 */
	private static SObjectField getExistingField(UTIL_SObjectDescribe objectDescribe, String sObjectName, String fieldApiName)
	{
		SObjectField field = objectDescribe?.getField(fieldApiName);

		if(field == null)
		{
			throw new IllegalArgumentException(String.format(MESSAGE_MISSING_FIELD, new List<Object> {fieldApiName, sObjectName}));
		}

		return field;
	}
}