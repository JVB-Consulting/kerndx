// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Abstract base class for all selectors. Provides lazy-loaded field management
 * and IF_Queryable implementation. Subclasses define their SObjectType and core fields;
 * the base class handles query builder creation with all configured fields.
 *
 * @see IF_Queryable
 * @see SEL_Base_TEST
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date February 2026, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * global class SEL_Account extends SEL_Base
 * {
 * global SEL_Account()
 * {
 * 	super(Account.SObjectType);
 * }
 * global override List<SObjectField> getFields()
 * {
 * 	return new List<SObjectField> { Account.Id, Account.Name };
 * }
 * global override List<String> getFieldPaths()
 * {
 * 	return new List<String> { 'Owner.Name', 'CreatedBy.Email' };
 * }
 * global List<Account> findByIndustry(String industry)
 * {
 * 	return query.condition(Account.Industry).equals(industry).toList();
 * }
 * }
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier,PMD.CognitiveComplexity')
global abstract inherited sharing class SEL_Base implements IF_Queryable
{
	/**
	 * @description The SObjectType this selector queries. Set via constructor.
	 */
	private final SObjectType objectType;

	/**
	 * @description Constructs a selector for the given SObjectType.
	 *
	 * @param objectType The SObjectType this selector queries
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * SEL_Account.SEL_Base instance = new SEL_Account.SEL_Base(Account.SObjectType);
	 * ```
	 */
	global SEL_Base(SObjectType objectType)
	{
		this.objectType = objectType;
	}

	/**
	 * @description Core SObjectField tokens for this selector. Lazy-loaded from getCoreFields()
	 * on first access. Subscribers can inspect a selector's field configuration via this property.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * SEL_Account selector = new SEL_Account();
	 * List<SObjectField> accountFields = selector.fields;
	 * System.debug('Selector includes ' + accountFields.size() + ' fields');
	 * ```
	 */
	global final List<SObjectField> fields
	{
		get
		{
			if(fields == null)
			{
				fields = getFields();
			}
			return fields;
		}
		private set;
	}

	/**
	 * @description Core field path strings for this selector, supporting relationship traversal
	 * syntax (e.g., 'Owner.Name'). Lazy-loaded from getCoreFieldPaths() on first access.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * SEL_Account selector = new SEL_Account();
	 * List<String> paths = selector.fieldPaths;
	 * System.debug('Relationship paths: ' + paths); // e.g., ['Owner.Name', 'CreatedBy.Email']
	 * ```
	 */
	global final List<String> fieldPaths
	{
		get
		{
			if(fieldPaths == null)
			{
				fieldPaths = getFieldPaths();
			}
			return fieldPaths;
		}
		private set;
	}

	/**
	 * @description Returns the core SObjectField tokens always included in queries from this selector.
	 * Override to define the default field set. Returns an empty list by default.
	 *
	 * @return List of core SObjectFields
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<SObjectField> result = instance.getFields();
	 * ```
	 */
	global virtual List<SObjectField> getFields()
	{
		return new List<SObjectField>();
	}

	/**
	 * @description Returns core field paths as strings, supporting relationship traversal
	 * syntax (e.g., 'Owner.Name', 'Contact.Email'). Override to include relationship
	 * fields in the default query. Returns an empty list by default.
	 *
	 * @return List of field path strings
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<String> result = instance.getFieldPaths();
	 * ```
	 */
	global virtual List<String> getFieldPaths()
	{
		return new List<String>();
	}

	/**
	 * @description Declares whether this selector's queries must run in `AccessLevel.SYSTEM_MODE`
	 * regardless of the `UserModeQueries_Enabled` feature flag. Framework-internal selectors that
	 * read CMDT, framework-owned sObjects, or system-schema tables override this to return `true`
	 * so they continue working when the running user lacks FLS/CRUD on those objects by design.
	 *
	 * Subscriber-reachable selectors should leave this at the default (`false`) so they inherit
	 * the flag-driven default — secure-by-default when the flag is enabled.
	 *
	 * @return `true` when this selector's queries must run in SYSTEM_MODE.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * public inherited sharing class SEL_Cases extends SEL_Base
	 * {
	 *     public SEL_Cases()
	 *     {
	 *         super(Case.SObjectType);
	 *     }
	 *     public override Boolean systemModeRequired()
	 *     {
	 *         return true;
	 *     }
	 * }
	 * ```
	 */
	global virtual Boolean systemModeRequired()
	{
		return false;
	}

	/**
	 * @description Returns a new query builder pre-configured with this selector's SObjectType
	 * and all field sources. Each access creates a fresh builder instance to prevent state
	 * leaking between queries. When `systemModeRequired()` returns `true`, the builder has
	 * `systemModeInternal()` applied so framework-internal reads (CMDT, framework-owned
	 * sObjects) run in SYSTEM_MODE without polluting the `BypassEvent` audit trail —
	 * a static `systemModeRequired()` design choice is not a runtime bypass. Selectors that
	 * leave `systemModeRequired()` at the default (`false`) inherit the `UserModeQueries_Enabled`
	 * flag-driven default.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<Account> accounts = new SEL_Account().query
	 *     .condition(Account.Industry).equals('Technology')
	 *     .toList();
	 * ```
	 */
	global QRY_Builder.Builder query
	{
		get
		{
			QRY_Builder.Builder builder = QRY_Builder.selectFrom(objectType)
					.fields(fields)
					.addFields(fieldPaths);
			if(systemModeRequired())
			{
				builder = builder.systemModeInternal();
			}
			return builder;
		}
	}

	/**
	 * @description Executes the default query and returns all matching records.
	 *
	 * @return List of all records with default fields
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<SObject> result = instance.toList();
	 * ```
	 */
	global List<SObject> toList()
	{
		return query.toList();
	}

	/**
	 * @description Executes the default query and returns the first record, or null.
	 *
	 * @return First matching record or null
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * SObject result = instance.getFirst();
	 * ```
	 */
	global SObject getFirst()
	{
		return query.getFirst();
	}

	/**
	 * @description Returns a random record matching the default query, or null if none exist.
	 *
	 * @return A random matching record or null
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * SObject result = instance.getRandomItem();
	 * ```
	 */
	global virtual SObject getRandomItem()
	{
		return query.getRandomItem();
	}

	/**
	 * @description Returns a QueryLocator for the default query. Suitable for batch processing.
	 *
	 * @return QueryLocator for the default query
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global class BatchProcessAccounts implements Database.Batchable<SObject>
	 * {
	 *     global Database.QueryLocator start(Database.BatchableContext context)
	 *     {
	 *         return new SEL_Account().toQueryLocator();
	 *     }
	 * }
	 * ```
	 */
	global Database.QueryLocator toQueryLocator()

	{
		return query.toQueryLocator();
	}

	/**
	 * @description Returns the count of all records matching the default query.
	 *
	 * @return Number of matching records
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Integer result = instance.count();
	 * ```
	 */
	global Integer count()
	{
		return query.count();
	}

	/**
	 * @description Returns true if any records match the default query.
	 *
	 * @return True if at least one record matches
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Boolean result = instance.exists();
	 * ```
	 */
	global Boolean exists()
	{
		return count() > 0;
	}

	/**
	 * @description Finds a single record by its Id.
	 *
	 * @param recordId The Id of the record to retrieve
	 *
	 * @return The matching record or null if not found
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * SObject result = instance.findById(recordId);
	 * ```
	 */
	global SObject findById(Id recordId)
	{
		return query.condition('Id').equals(recordId).getFirst();
	}

	/**
	 * @description Finds multiple records by their Ids.
	 *
	 * @param recordIds The set of Ids to retrieve
	 *
	 * @return List of matching records, or empty list if no Ids provided
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<SObject> result = instance.findById(recordIds);
	 * ```
	 */
	global List<SObject> findById(Set<Id> recordIds)
	{
		return recordIds?.isEmpty() == false ? query.condition('Id').isIn(new List<Id>(recordIds)).toList() : new List<SObject>();
	}

	/**
	 * @description Finds the first record matching a single field value, or null if not found.
	 *
	 * @param field The SObjectField to filter on
	 * @param value The value to match
	 *
	 * @return The first matching record or null
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * SObject result = instance.findFirstByField(Account.Name, 'value');
	 * ```
	 */
	global SObject findFirstByField(SObjectField field, Object value)
	{
		return query.condition(field).equals(value).getFirst();
	}

	/**
	 * @description Finds records matching a single field value.
	 *
	 * @param field The SObjectField to filter on
	 * @param value The value to match
	 *
	 * @return List of matching records
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<SObject> result = instance.findByField(Account.Name, 'value');
	 * ```
	 */
	global List<SObject> findByField(SObjectField field, Object value)
	{
		return query.condition(field).equals(value).toList();
	}

	/**
	 * @description Finds records matching multiple values on a field.
	 *
	 * @param field The SObjectField to filter on
	 * @param values The values to match
	 *
	 * @return List of matching records, or empty list if no values provided
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<SObject> result = instance.findByField(Account.Name, new Set<Object>{'value'});
	 * ```
	 */
	global List<SObject> findByField(SObjectField field, Set<Object> values)
	{
		return values?.isEmpty() == false ? query.condition(field).isIn(values).toList() : new List<SObject>();
	}

	/**
	 * @description Finds records matching multiple values on a field.
	 *
	 * @param field The SObjectField to filter on
	 * @param values The values to match
	 *
	 * @return List of matching records, or empty list if no values provided
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<SObject> result = instance.findByField(Account.Name, new List<Object>{'a', 'b'});
	 * ```
	 */
	global List<SObject> findByField(SObjectField field, List<Object> values)
	{
		return values?.isEmpty() == false ? query.condition(field).isIn(values).toList() : new List<SObject>();
	}

	/**
	 * @description Finds records matching multiple field-value pairs combined with AND logic.
	 *
	 * @param fieldValues Map of SObjectField tokens to their expected values
	 *
	 * @return List of matching records, or empty list if fieldValues is null or empty
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<SObject> records = new SEL_Foobar().findByFields
	 * (
	 *     new Map<SObjectField, Object>
	 *     {
	 *         Foobar__c.Text__c => 'Alpha',
	 *         Foobar__c.Email__c => 'test@example.com'
	 *     }
	 * );
	 * ```
	 */
	global List<SObject> findByFields(Map<SObjectField, Object> fieldValues)
	{
		if(fieldValues == null || fieldValues.isEmpty())
		{
			return new List<SObject>();
		}

		return buildFieldQuery(fieldValues).toList();
	}

	/**
	 * @description Finds the first record matching multiple field-value pairs combined with AND logic,
	 * or null if not found.
	 *
	 * @param fieldValues Map of SObjectField tokens to their expected values
	 *
	 * @return The first matching record or null
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * SObject record = new SEL_Foobar().findFirstByFields
	 * (
	 *     new Map<SObjectField, Object>
	 *     {
	 *         Foobar__c.Text__c => 'Alpha',
	 *         Foobar__c.Email__c => 'test@example.com'
	 *     }
	 * );
	 * ```
	 */
	global SObject findFirstByFields(Map<SObjectField, Object> fieldValues)
	{
		if(fieldValues == null || fieldValues.isEmpty())
		{
			return null;
		}

		return buildFieldQuery(fieldValues).getFirst();
	}

	/**
	 * @description Builds a query with AND conditions for each field-value pair.
	 *
	 * @param fieldValues Map of SObjectField tokens to their expected values
	 *
	 * @return Configured query builder
	 */
	private QRY_Builder.Builder buildFieldQuery(Map<SObjectField, Object> fieldValues)
	{
		QRY_Builder.Builder queryBuilder = query;

		for(SObjectField field : fieldValues.keySet())
		{
			queryBuilder.addCondition(new QRY_Condition.FieldCondition(field).equals(fieldValues.get(field)));
		}

		return queryBuilder;
	}

	/**
	 * @description Finds a single record by its Id, throwing NotFoundException if not found.
	 *
	 * @param recordId The Id of the record to retrieve
	 *
	 * @return The matching record
	 *
	 * @throws UTIL_Exceptions.NotFoundException If no record exists with the given Id
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Foobar__c record = (Foobar__c)new SEL_Foobar().findByIdOrThrow(recordId);
	 * ```
	 */
	global SObject findByIdOrThrow(Id recordId)
	{
		SObject result = findById(recordId);

		if(result == null)
		{
			throw new UTIL_Exceptions.NotFoundException(objectType.getDescribe().name + ' record not found: ' + recordId);
		}

		return result;
	}

	/**
	 * @description Finds multiple records by their Ids, throwing NotFoundException if any Id is missing.
	 *
	 * @param recordIds The set of Ids to retrieve
	 *
	 * @return List of matching records
	 *
	 * @throws UTIL_Exceptions.NotFoundException If any of the requested Ids were not found
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<Foobar__c> records = new SEL_Foobar().findByIdOrThrow(recordIds);
	 * ```
	 */
	global List<SObject> findByIdOrThrow(Set<Id> recordIds)
	{
		List<SObject> results = findById(recordIds);

		if(results.size() != recordIds.size())
		{
			Set<Id> foundIds = new Set<Id>();

			for(SObject each : results)
			{
				foundIds.add(each.Id);
			}

			Set<Id> missingIds = new Set<Id>(recordIds);
			missingIds.removeAll(foundIds);

			throw new UTIL_Exceptions.NotFoundException
					(
							objectType.getDescribe().name + ' records not found: ' + missingIds
					);
		}

		return results;
	}
}