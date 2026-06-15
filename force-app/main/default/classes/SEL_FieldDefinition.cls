// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Selector for the FieldDefinition SObject. Reads native Data Classification
 * (`SecurityClassification` / `ComplianceGroup`) per field for a single SObject so the Data Masking
 * Advisor can surface which fields the org has already classified as sensitive. The platform requires
 * FieldDefinition queries to be bounded to one EntityDefinition, so every query filters on
 * `EntityDefinition.QualifiedApiName`. Routed through `QRY_Builder` (not raw SOQL) so both the happy
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
 * @date May 2026
 */
public inherited sharing class SEL_FieldDefinition extends SEL_Base
{
	/**
	 * @description Constructs a FieldDefinition selector with the FieldDefinition SObjectType.
	 */
	public SEL_FieldDefinition()
	{
		super(FieldDefinition.SObjectType);
	}

	/**
	 * @description Returns the core fields for FieldDefinition queries — the qualified API name plus
	 * the two native Data Classification fields the advisor surfaces.
	 *
	 * @return List of FieldDefinition SObjectField tokens.
	 */
	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>
		{
				FieldDefinition.ComplianceGroup,
				FieldDefinition.QualifiedApiName,
				FieldDefinition.SecurityClassification
		};
	}

	/**
	 * @description Framework-internal schema selector — always runs in `AccessLevel.SYSTEM_MODE`
	 * regardless of the `UserModeQueries_Enabled` feature flag. FieldDefinition is Setup metadata that
	 * running users typically can't read, so a USER_MODE read would return empty and the advisor's
	 * classification surfacing would silently break.
	 *
	 * @return `true` — this selector requires SYSTEM_MODE.
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
				.condition('EntityDefinition.QualifiedApiName').equals(sObjectApiName)
				.toList();
	}
}