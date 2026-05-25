// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Selector for the NamedCredential SObject. Provides query methods for retrieving
 * named credentials by developer name, with namespace-aware parsing.
 *
 * @see SEL_Base
 * @see SEL_NamedCredential_TEST
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date February 2026, May 2026
 */
public inherited sharing class SEL_NamedCredential extends SEL_Base
{
	/**
	 * @description Constructs a NamedCredential selector.
	 */
	public SEL_NamedCredential()
	{
		super(NamedCredential.SObjectType);
	}

	/**
	 * @description Returns the core fields for NamedCredential queries.
	 *
	 * @return List of NamedCredential SObjectField tokens
	 */
	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>
		{
				NamedCredential.Endpoint
		};
	}

	/**
	 * @description Framework-internal schema selector — always runs in `AccessLevel.SYSTEM_MODE`
	 * regardless of the `UserModeQueries_Enabled` feature flag. NamedCredential is Setup metadata
	 * that running users typically can't read, so USER_MODE reads would return empty and the
	 * API / callout dispatch machinery would silently fail to resolve credentials.
	 *
	 * @return `true` — this selector requires SYSTEM_MODE.
	 */
	public override Boolean systemModeRequired()
	{
		return true;
	}

	/**
	 * @description Returns a named credential by developer name. If the name contains a namespace
	 * prefix (e.g., 'kern__MyCredential'), the namespace and developer name are parsed and matched
	 * separately. Returns null if no match or multiple matches are found.
	 *
	 * @param developerName The developer name, optionally prefixed with namespace (e.g., 'kern__MyCredential')
	 *
	 * @return The matching NamedCredential or null
	 */
	public NamedCredential findByName(String developerName)
	{
		NamedCredential foundCredential;

		List<String> splitDeveloperNames = UTIL_String.splitByWholeSeparator(developerName, UTIL_String.DOUBLE_UNDERSCORE);

		if(splitDeveloperNames?.isEmpty() == false)
		{
			String name = splitDeveloperNames.size() > 1 ? splitDeveloperNames[1] : splitDeveloperNames[0];
			String namespacePrefix = splitDeveloperNames.size() > 1 ? splitDeveloperNames[0] : UTIL_String.EMPTY;

			List<NamedCredential> foundCredentials = query
					.condition(NamedCredential.DeveloperName).equals(name)
					.condition(NamedCredential.NamespacePrefix).equals(namespacePrefix)
					.toList();

			foundCredential = foundCredentials.size() == 1 ? foundCredentials.iterator().next() : null;
		}

		return foundCredential;
	}
}