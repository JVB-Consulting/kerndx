// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Processor for bulk field updates using the adaptive async framework.
 * Implements IF_Async.Processable to enable automatic selection between Queueable and Batch execution.
 * Supports REPLACE, PREFIX, and SUFFIX update methods for flexible field value manipulation.
 *
 * @see PROC_UpdateFields_TEST
 * @see IF_Async.Processable
 * @see UTIL_AsynchronousJobLauncher
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
		 * @description Replaces the field value with the provided value.
		 */
		REPLACE,

		/**
		 * @description Prepends the provided value to the current field value.
		 */
		PREFIX,

		/**
		 * @description Appends the provided value to the current field value.
		 */
		SUFFIX
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
		 * @description Value to apply to the field.
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
		 * @description Explicit `AccessLevel` for the bulk update commit, or `null` to inherit the
		 * flag-driven default resolved by `DML_SharingProxy.defaultAccessLevel()`. Framework utilities
		 * that own their lifecycle (e.g. `UTIL_BulkUpdates`) set this to `AccessLevel.SYSTEM_MODE`
		 * explicitly so the bulk commit is not gated on the invoking user's FLS. Subscribers calling
		 * `PROC_UpdateFields` directly may pass `AccessLevel.USER_MODE` to enforce their secure-by-default
		 * opt-in.
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
	 * @description Executes the field update operation on the provided list of records.
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
			SObject record = (SObject)item;
			applyFieldUpdates(record);
			records.add(record);
		}

		DML_Builder builder = DML_Builder.newTransaction();
		// Tri-state: SYSTEM_MODE and USER_MODE override explicitly; null inherits the flag-driven default.
		if(parameters.accessLevel == System.AccessLevel.SYSTEM_MODE)
		{
			builder.withSystemMode();
		}
		else if(parameters.accessLevel == System.AccessLevel.USER_MODE)
		{
			builder.withUserMode();
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
		}

		QRY_Builder.Builder query = QRY_Builder.selectFrom(UTIL_SObjectDescribe.getSObjectTypeByName(parameters.objectName))
				.fields(fieldNames);

		// Tri-state: SYSTEM_MODE and USER_MODE override explicitly; null inherits the flag-driven default.
		if(parameters.accessLevel == System.AccessLevel.SYSTEM_MODE)
		{
			query.withSystemMode();
		}
		else if(parameters.accessLevel == System.AccessLevel.USER_MODE)
		{
			query.withUserMode();
		}

		if(parameters.searchConditions != null)
		{
			query.addCondition(parameters.searchConditions);
		}

		return query;
	}
}