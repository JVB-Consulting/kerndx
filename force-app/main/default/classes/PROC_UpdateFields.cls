// SPDX-License-Identifier: Apache-2.0
/**
 * @description Processor for bulk field updates using the adaptive async framework.
 * Implements IF_Async.Processable to enable automatic selection between Queueable and Batch execution.
 * Supports the REPLACE, PREFIX, SUFFIX and COPY_FROM_FIELD update methods for flexible field value manipulation.
 *
 * @see PROC_UpdateFields_TEST
 * @see IF_Async.Processable
 * @see UTIL_AsynchronousJobLauncher
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
 * PROC_UpdateFields.DTO_Parameters params = new PROC_UpdateFields.DTO_Parameters();
 * params.objectName = 'Account';
 * PROC_UpdateFields.DTO_Field field = new PROC_UpdateFields.DTO_Field();
 * field.name = 'Description';
 * field.value = 'Updated via bulk processor';
 * params.updateFields.add(field);
 * PROC_UpdateFields processor = new PROC_UpdateFields(params);
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class PROC_UpdateFields implements IF_Async.Processable
{
	/**
	 * @description Enum defining methods for updating SObject fields.
	 *
	 * @since 1.0
	 */
	global enum FieldUpdateMethod
	{
		/**
		 * @description The new value is written as it is and the current value is not kept, so a null value clears
		 * the field. This is the default.
		 */
		REPLACE,

		/**
		 * @description Prepends the provided value to the current field value.
		 */
		PREFIX,

		/**
		 * @description Appends the provided value to the current field value.
		 */
		SUFFIX,

		/**
		 * @description Copies another field of the same row into the field. Here the value is not written itself: it is
		 * the API name of the field to copy from, the source field. Each row gets its own source value. The field must
		 * be able to take the source value: when Salesforce will not put the source value into the field, for example a
		 * decimal number into a whole number field, the error stops the whole chunk of rows and none of them is saved.
		 * `UTIL_BulkUpdates.copyField` refuses such pairs before it starts the job. Field lengths are not checked: a
		 * value too long for the field fails its row when the row is saved.
		 *
		 * @since 1.12
		 */
		COPY_FROM_FIELD
	}

	/**
	 * @description Parameters for the field update operation.
	 */
	private final DTO_Parameters parameters;

	/**
	 * @description DTO representing a field to update on an SObject.
	 *
	 * @since 1.0
	 */
	global inherited sharing class DTO_Field
	{
		/**
		 * @description API name of the field to update (e.g., 'Name').
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * String value = instance.name;
		 * ```
		 */
		global String name;

		/**
		 * @description Value to apply to the field. With `FieldUpdateMethod.COPY_FROM_FIELD`, the API name of the field on
		 * the same row to copy from.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Object value = instance.value;
		 * ```
		 */
		global Object value;

		/**
		 * @description Method to use for updating the field (default: REPLACE).
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * FieldUpdateMethod value = instance.updateMethod;
		 * ```
		 */
		global FieldUpdateMethod updateMethod = FieldUpdateMethod.REPLACE;

		/**
		 * @description Sets the field value on an SObject based on the specified update method.
		 *
		 * @param currentSObject The SObject to update.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * instance.setObjectValue(record);
		 * ```
		 */
		global void setObjectValue(SObject currentSObject)
		{
			if(updateMethod == FieldUpdateMethod.COPY_FROM_FIELD)
			{
				copySourceValue(currentSObject);
				return;
			}

			Object fieldValue = currentSObject.get(name);
			switch on updateMethod
			{
				when PREFIX
				{
					fieldValue = String.valueOf(value) + String.valueOf(fieldValue);
				}
				when SUFFIX
				{
					fieldValue = String.valueOf(fieldValue) + String.valueOf(value);
				}
				when else
				{
					fieldValue = value;
				}
			}
			currentSObject.put(name, fieldValue);
		}

		/**
		 * @description Copies the source field named in `value` into this field on the same row. The value is not
		 * checked here. When Salesforce will not put it into this field, the error stops the whole chunk of rows, so
		 * `UTIL_BulkUpdates.copyField` refuses such a pair of fields before any job starts.
		 *
		 * @param currentSObject The row to update. It must have been read with the source field.
		 */
		private void copySourceValue(SObject currentSObject)
		{
			currentSObject.put(name, currentSObject.get(String.valueOf(value)));
		}
	}

	/**
	 * @description DTO for parameters to query and update records.
	 *
	 * @since 1.0
	 */
	global inherited sharing class DTO_Parameters
	{
		/**
		 * @description Indicates if the update requires all-or-nothing behavior (default: false).
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Boolean value = instance.allOrNothing;
		 * ```
		 */
		global Boolean allOrNothing = false;

		/**
		 * @description API name of the SObject to update (e.g., 'Account').
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * String value = instance.objectName;
		 * ```
		 */
		global String objectName;

		/**
		 * @description List of field updates to apply to the SObjects.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<DTO_Field> value = instance.updateFields;
		 * ```
		 */
		global List<DTO_Field> updateFields = new List<DTO_Field>();

		/**
		 * @description Conditions to filter records for updating.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * QRY_Condition.Evaluable value = instance.searchConditions;
		 * ```
		 */
		global QRY_Condition.Evaluable searchConditions;

		/**
		 * @description The access level for the query and the save, or `null` to use the package default. The default
		 * runs with the running user's object, field and sharing access (user mode), unless the package's feature
		 * settings turn it off. `UTIL_BulkUpdates` leaves this `null`, so its jobs use the default too. Set
		 * `AccessLevel.SYSTEM_MODE` to skip those checks, only after your own code has checked that the user may make the
		 * change. Set `AccessLevel.USER_MODE` to always check the running user's access. A user mode level that adds a
		 * permission set, built with `AccessLevel.USER_MODE.withPermissionSetId(...)`, is used as it is for the query and
		 * the save, so the running user also gets the access that permission set gives.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * AccessLevel mode = instance.accessLevel;
		 * ```
		 */
		global AccessLevel accessLevel;
	}

	/**
	 * @description Constructs a field update processor with the specified parameters.
	 *
	 * @param parameters The parameters defining which fields to update and how.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * PROC_UpdateFields.DTO_Parameters params = new PROC_UpdateFields.DTO_Parameters();
	 * params.objectName = 'Account';
	 * PROC_UpdateFields processor = new PROC_UpdateFields(params);
	 * ```
	 */
	global PROC_UpdateFields(DTO_Parameters parameters)
	{
		this.parameters = parameters;
	}

	/**
	 * @description Applies the field updates to the given records and saves them. All updates are applied to each
	 * record first, so two updates of one field build on each other. Then only the record's Id and the fields in the
	 * update list are saved. Other fields on the record, such as the field a copy reads from, are not saved.
	 *
	 * Because the save does not hold the field a copy reads from, the save does not check whether the user may read
	 * that field. The read that found the records decides it. If the user's access to that field must count, read the
	 * records with the user's access (user mode), as buildQueryable does by default.
	 *
	 * @param items The list of SObject records to update.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * PROC_UpdateFields.DTO_Parameters params = new PROC_UpdateFields.DTO_Parameters();
	 * PROC_UpdateFields.DTO_Field field = new PROC_UpdateFields.DTO_Field();
	 * field.name = 'Name';
	 * field.value = 'Updated';
	 * params.updateFields.add(field);
	 * List<Account> accounts = [SELECT Id, Name FROM Account LIMIT 100];
	 * new PROC_UpdateFields(params).execute(accounts);
	 * ```
	 */
	global void execute(List<Object> items)
	{
		List<SObject> records = new List<SObject>();
		for(Object item : items)
		{
			SObject readRecord = (SObject)item;
			applyFieldUpdates(readRecord);
			records.add(newRecordWithUpdatedFields(readRecord));
		}

		// System mode goes through withSystemMode(), so the bypass audit records it. Any other level is passed on as it is,
		// so a level that names a permission set keeps it; null keeps the flag-driven default. The comparator, not ==,
		// because a level rebuilt inside an async job is a new object. If the comparator cannot read a rebuilt system mode
		// level, that level is passed on as it is, so the save runs in system mode with no audit entry.
		DML_Builder builder = DML_Builder.newTransaction();
		if(DML_SharingProxy.matchesAccessLevel(parameters.accessLevel, System.AccessLevel.SYSTEM_MODE))
		{
			builder.withSystemMode();
		}
		else
		{
			builder.withAccessLevelInternal(parameters.accessLevel);
		}
		builder.doUpdate(records);
		if(!parameters.allOrNothing)
		{
			builder.allowPartial();
		}
		builder.execute();
	}

	/**
	 * @description Applies configured field updates to a single record.
	 *
	 * @param record The SObject record to update.
	 */
	private void applyFieldUpdates(SObject record)
	{
		for(DTO_Field fieldUpdate : parameters.updateFields)
		{
			fieldUpdate.setObjectValue(record);
		}
	}

	/**
	 * @description Builds the record to save: a new record of the same object, with the read record's Id and only the
	 * fields named in the update list, holding the values the updates gave them. A field the updates did not set, such
	 * as the field a copy reads from, is never saved.
	 *
	 * @param readRecord The record as it was read, with every update already applied to it.
	 *
	 * @return The record to save.
	 */
	private SObject newRecordWithUpdatedFields(SObject readRecord)
	{
		SObject recordToSave = readRecord.getSObjectType().newSObject(readRecord.Id);
		for(DTO_Field fieldUpdate : parameters.updateFields)
		{
			recordToSave.put(fieldUpdate.name, readRecord.get(fieldUpdate.name));
		}
		return recordToSave;
	}

	/**
	 * @description Builds a queryable for the configured object and fields.
	 *
	 * @return An IF_Queryable instance for retrieving records to update.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * PROC_UpdateFields.DTO_Parameters params = new PROC_UpdateFields.DTO_Parameters();
	 * params.objectName = 'Account';
	 * PROC_UpdateFields.DTO_Field field = new PROC_UpdateFields.DTO_Field();
	 * field.name = 'Name';
	 * params.updateFields.add(field);
	 * IF_Queryable query = new PROC_UpdateFields(params).buildQueryable();
	 * ```
	 */
	global IF_Queryable buildQueryable()
	{
		List<String> fieldNames = new List<String>();
		for(DTO_Field fieldUpdate : parameters.updateFields)
		{
			fieldNames.add(fieldUpdate.name);
			if(fieldUpdate.updateMethod == FieldUpdateMethod.COPY_FROM_FIELD)
			{
				fieldNames.add(String.valueOf(fieldUpdate.value));
			}
		}

		// System mode goes through withSystemMode(), so the bypass audit records it. Any other level is passed on as it is,
		// so a level that names a permission set keeps it; null keeps the flag-driven default. If the comparator cannot read
		// a rebuilt system mode level, that level is passed on as it is, so the query runs in system mode with no audit entry.
		QRY_Builder.Builder query = QRY_Builder.selectFrom(UTIL_SObjectDescribe.getSObjectTypeByName(parameters.objectName))
				.fields(fieldNames);
		if(DML_SharingProxy.matchesAccessLevel(parameters.accessLevel, System.AccessLevel.SYSTEM_MODE))
		{
			query.withSystemMode();
		}
		else
		{
			query.withAccessLevelInternal(parameters.accessLevel);
		}

		if(parameters.searchConditions != null)
		{
			query.addCondition(parameters.searchConditions);
		}

		return query;
	}
}