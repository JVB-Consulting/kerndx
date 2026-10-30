// SPDX-License-Identifier: Apache-2.0
/**
 * @description Selector for the FieldDefinition SObject. Reads native Data Classification
 * (`SecurityClassification` / `ComplianceGroup`) per field for a single SObject so the Data Masking
 * Advisor can surface which fields the org has already classified as sensitive. The platform requires
 * a FieldDefinition query to be bounded, so `findByEntity` filters on one `EntityDefinition.QualifiedApiName`
 * and `findByDurableIds` filters on the durable Ids it is given. Routed through `QRY_Builder` (not raw SOQL) so both the happy
 * path and a caller's failure path are interceptable via `TST_Mock`.
 *
 * @see SEL_Base
 * @see SEL_FieldDefinition_TEST
 * @see FieldDefinition
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date May 2026, October 2026
 */
public inherited sharing class SEL_FieldDefinition extends SEL_Base
{
	/**
	 * @description The path from a field definition to the API name of its object. Used to filter fields by object and to return the
	 * object name with each field, so no second read is needed.
	 */
	private static final String PATH_ENTITY_QUALIFIED_API_NAME = 'EntityDefinition.QualifiedApiName';

	/**
	 * @description Constructs a FieldDefinition selector with the FieldDefinition SObjectType.
	 */
	public SEL_FieldDefinition()
	{
		super(FieldDefinition.SObjectType);
	}

	/**
	 * @description Returns the core fields for FieldDefinition queries: the durable Id, the qualified API
	 * name, and the two native Data Classification fields the advisor shows. The durable Id is the fixed key
	 * the platform gives each field. A masking target that names a field stores this key, not the field's name.
	 *
	 * @return List of FieldDefinition SObjectField tokens.
	 */
	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>
		{
				FieldDefinition.ComplianceGroup,
				FieldDefinition.DurableId,
				FieldDefinition.QualifiedApiName,
				FieldDefinition.SecurityClassification
		};
	}

	/**
	 * @description Framework-internal schema selector. It always runs in `AccessLevel.SYSTEM_MODE`
	 * regardless of the `UserModeQueries_Enabled` feature flag. FieldDefinition is Setup metadata that
	 * running users typically can't read, so a USER_MODE read would return empty and the advisor's
	 * classification surfacing would silently break.
	 *
	 * @return `true`, because this selector requires SYSTEM_MODE.
	 */
	public override Boolean systemModeRequired()
	{
		return true;
	}

	/**
	 * @description Finds the field definitions for one SObject, applying the bounded
	 * `EntityDefinition.QualifiedApiName` filter the platform requires for FieldDefinition queries.
	 * Returns every field; the caller decides which carry a classification.
	 *
	 * @param sObjectApiName The SObject whose fields to read (e.g. `Account`).
	 *
	 * @return Field definitions for the SObject, or an empty list when the name is blank.
	 */
	public List<FieldDefinition> findByEntity(String sObjectApiName)
	{
		if(String.isBlank(sObjectApiName))
		{
			return new List<FieldDefinition>();
		}

		return query
				.condition(PATH_ENTITY_QUALIFIED_API_NAME).equals(sObjectApiName)
				.toList();
	}

	/**
	 * @description Finds field definitions by durable Id, the fixed key the platform gives each field. A
	 * masking target that names a field stores this key. For a custom field it is the object's durable Id and
	 * the field's Id joined by a dot (for example `01I000000000001.00N000000000001`); for a standard field on a
	 * standard object it reads like the field's name (for example `Account.Name`). The filter takes durable Ids
	 * from many objects in one query. Each result also carries the API name of its object, so a caller can build
	 * the `Object.Field` name without a second read.
	 *
	 * @param durableIds The field durable Ids to find.
	 *
	 * @return The matching field definitions, or an empty list without a query when no durable Id is given.
	 */
	public List<FieldDefinition> findByDurableIds(Set<String> durableIds)
	{
		if(durableIds == null || durableIds.isEmpty())
		{
			return new List<FieldDefinition>();
		}

		return query
				.addField(PATH_ENTITY_QUALIFIED_API_NAME)
				.condition(FieldDefinition.DurableId).isIn(new List<String>(durableIds))
				.toList();
	}
}