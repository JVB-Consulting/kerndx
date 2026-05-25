// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Selector for the FieldSetGroup__mdt custom metadata type. Provides query methods
 * for retrieving field set group configurations.
 *
 * @see SEL_Base
 * @see SEL_FieldSetGroup_TEST
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date February 2026, May 2026
 */
public inherited sharing class SEL_FieldSetGroup extends SEL_Base
{
	/**
	 * @description API name for the field containing the default active sections.
	 */
	public static final String FIELD_DEFAULT_ACTIVE_SECTIONS = FieldSetGroup__mdt.DefaultActiveSections__c.getDescribe().name;

	/**
	 * @description API name for the field containing fieldset API names.
	 */
	public static final String FIELD_FIELDSET_API_NAMES = FieldSetGroup__mdt.FieldSetApiNames__c.getDescribe().name;

	/**
	 * @description API name for the FieldSetGroup__mdt object.
	 */
	public static final String OBJECT_NAME = FieldSetGroup__mdt.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).name;

	/**
	 * @description Constructs a FieldSetGroup selector.
	 */
	public SEL_FieldSetGroup()
	{
		super(FieldSetGroup__mdt.SObjectType);
	}

	/**
	 * @description Returns the core fields for FieldSetGroup__mdt queries.
	 *
	 * @return List of FieldSetGroup__mdt SObjectField tokens
	 */
	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>
		{
				FieldSetGroup__mdt.DefaultActiveSections__c,
				FieldSetGroup__mdt.DeveloperName,
				FieldSetGroup__mdt.FieldSetApiNames__c
		};
	}

	/**
	 * @description Framework-internal CMDT selector — always runs in `AccessLevel.SYSTEM_MODE`
	 * regardless of the `UserModeQueries_Enabled` feature flag. Subscribers typically grant
	 * running users no CRUD on `kern__*__mdt` records by design, so USER_MODE reads would
	 * return empty and framework behaviour would silently break.
	 *
	 * @return `true` — this selector requires SYSTEM_MODE.
	 */
	public override Boolean systemModeRequired()
	{
		return true;
	}

	/**
	 * @description Finds a FieldSetGroup__mdt record by its DeveloperName.
	 *
	 * @param developerName The DeveloperName to match
	 *
	 * @return The matching record or null if not found
	 */
	public FieldSetGroup__mdt findByDeveloperName(String developerName)
	{
		return (FieldSetGroup__mdt)findFirstByField(FieldSetGroup__mdt.DeveloperName, developerName);
	}

	/**
	 * @description Returns all FieldSetGroup__mdt records. Intended for test context only.
	 *
	 * @return List of all FieldSetGroup__mdt records
	 */
	@TestVisible
	private List<FieldSetGroup__mdt> getAll()
	{
		return query.toList();
	}
}