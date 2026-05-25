// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Selector for the ClassTypeResolver__mdt custom metadata type. Provides query methods
 * for resolving class type overrides.
 *
 * @see SEL_Base
 * @see SEL_ClassTypeResolver_TEST
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date March 2025, May 2026
 */
public inherited sharing class SEL_ClassTypeResolver extends SEL_Base
{
	/**
	 * @description Constructs a ClassTypeResolver selector.
	 */
	public SEL_ClassTypeResolver()
	{
		super(ClassTypeResolver__mdt.SObjectType);
	}

	/**
	 * @description Returns the core fields for ClassTypeResolver__mdt queries.
	 *
	 * @return List of ClassTypeResolver__mdt SObjectField tokens
	 */
	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>
		{
				ClassTypeResolver__mdt.ClassName__c,
				ClassTypeResolver__mdt.DeveloperName,
				ClassTypeResolver__mdt.Order__c
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
	 * @description Queries metadata records and returns the first record with a non-blank class name.
	 *
	 * @return Null or the first found item
	 */
	public ClassTypeResolver__mdt findFirst()
	{
		return (ClassTypeResolver__mdt)query
				.condition(ClassTypeResolver__mdt.ClassName__c).notEquals((Object)null)
				.getFirst();
	}

	/**
	 * @description Queries all metadata records with a non-blank class name, ordered by execution priority.
	 * Adds DeveloperName as a stable secondary sort so ties on Order__c are deterministic
	 * across orgs (otherwise the platform decides the tiebreaker).
	 *
	 * @return List of ClassTypeResolver__mdt records ordered by Order__c then DeveloperName ascending
	 */
	public List<ClassTypeResolver__mdt> findAll()
	{
		return query
				.condition(ClassTypeResolver__mdt.ClassName__c).notEquals((Object)null)
				.orderBy(ClassTypeResolver__mdt.Order__c).ascending()
				.orderBy(ClassTypeResolver__mdt.DeveloperName).ascending()
				.toList();
	}
}