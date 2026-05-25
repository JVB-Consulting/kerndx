// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Selector for the RecordType SObject. Provides query methods for retrieving
 * record types by object type, and person account record type detection.
 *
 * @see SEL_Base
 * @see SEL_RecordType_TEST
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date February 2026, May 2026
 */
public inherited sharing class SEL_RecordType extends SEL_Base
{
	/**
	 * @description Object API name.
	 */
	public static final String OBJECT_NAME = 'RecordType';

	/**
	 * @description Lazy-loaded set of person account record type Ids (if person accounts are enabled).
	 */
	public static final Set<Id> personAccountRecordTypes
	{
		get
		{
			if(personAccountRecordTypes == null)
			{
				personAccountRecordTypes = UTIL_SObject.extractIds(new SEL_RecordType().getAllPersonAccountRecordTypes());
			}
			return personAccountRecordTypes;
		}

		private set;
	}

	/**
	 * @description Constructs a RecordType selector using dynamic SObjectType resolution,
	 * since RecordType.SObjectType is not available as a compile-time token.
	 */
	public SEL_RecordType()
	{
		super(UTIL_SObjectDescribe.getSObjectTypeByName(OBJECT_NAME));
	}

	/**
	 * @description Returns the core fields for RecordType queries.
	 *
	 * @return List of RecordType SObjectField tokens
	 *
	 * @example
	 * ```apex
	 * List<SObjectField> result = instance.getFields();
	 * ```
	 */
	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>
		{
				RecordType.BusinessProcessId,
				RecordType.Description,
				RecordType.DeveloperName,
				RecordType.IsActive,
				RecordType.Name,
				RecordType.NamespacePrefix
		};
	}

	/**
	 * @description Returns the core field paths for RecordType queries. Uses string-based
	 * field paths because RecordType fields like SobjectType are not standard SObjectField tokens.
	 *
	 * @return List of field path strings
	 */
	public override List<String> getFieldPaths()
	{
		return new List<String>
		{
				'SobjectType'
		};
	}

	/**
	 * @description Framework-internal schema selector — always runs in `AccessLevel.SYSTEM_MODE`
	 * regardless of the `UserModeQueries_Enabled` feature flag. RecordType lookups power framework
	 * trigger / validation dispatch, and running users may not have access to every record type
	 * referenced in configuration, so USER_MODE reads would return incomplete results and rule
	 * dispatch would silently miss configured record-type filters.
	 *
	 * @return `true` — this selector requires SYSTEM_MODE.
	 */
	public override Boolean systemModeRequired()
	{
		return true;
	}

	/**
	 * @description Finds all record types for the given SObjectType.
	 *
	 * @param objectType The SObjectType to filter by
	 *
	 * @return List of matching RecordType records
	 */
	@TestVisible
	private List<RecordType> findByObjectType(SObjectType objectType)
	{
		return query
				.condition(RecordType.SobjectType).equals(objectType.getDescribe(SObjectDescribeOptions.DEFERRED).name)
				.toList();
	}

	/**
	 * @description Returns all person account record types. Returns an empty list if person
	 * accounts are not enabled in the org.
	 *
	 * @return List of person account RecordType records
	 */
	private List<RecordType> getAllPersonAccountRecordTypes()
	{
		return UTIL_SObjectDescribe.isPersonAccountEnabled() ? query.condition('isPersonType').equals(true).toList() : new List<RecordType>();
	}
}