// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Selector for the EmailTemplate SObject. Provides default field configuration
 * and query methods for EmailTemplate records.
 *
 * @see SEL_Base
 * @see SEL_EmailTemplate_TEST
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
 * List<EmailTemplate> templates = new SEL_EmailTemplate().findByName(new Set<String>{'WelcomeTemplate'});
 * EmailTemplate template = (EmailTemplate)new SEL_EmailTemplate().findById(templateId);
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class SEL_EmailTemplate extends SEL_Base
{
	/**
	 * @description DeveloperName of the standard test email template.
	 */
	@TestVisible
	private static final String TEST_EMAIL_TEMPLATE = 'ExampleForTesting';

	/**
	 * @description DeveloperName of the custom test email template.
	 */
	@TestVisible
	private static final String CUSTOM_TEST_EMAIL_TEMPLATE = 'CustomExampleForTesting';

	/**
	 * @description Constructs an EmailTemplate selector with the EmailTemplate SObjectType.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * SEL_EmailTemplate instance = new SEL_EmailTemplate();
	 * ```
	 */
	global SEL_EmailTemplate()
	{
		super(EmailTemplate.SObjectType);
	}

	/**
	 * @description Returns the core fields for EmailTemplate queries.
	 *
	 * @return List of EmailTemplate SObjectField tokens
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<SObjectField> result = instance.getFields();
	 * ```
	 */
	global override List<SObjectField> getFields()
	{
		return new List<SObjectField>
		{
				EmailTemplate.DeveloperName,
				EmailTemplate.Name
		};
	}

	/**
	 * @description Framework-internal schema selector — always runs in `AccessLevel.SYSTEM_MODE`
	 * regardless of the `UserModeQueries_Enabled` feature flag. Running users typically can't read
	 * EmailTemplate records they don't own, so USER_MODE reads would return empty and framework-
	 * initiated email dispatch would silently fail to find templates.
	 *
	 * @return `true` — this selector requires SYSTEM_MODE.
	 */
	public override Boolean systemModeRequired()
	{
		return true;
	}

	/**
	 * @description Retrieves a list of EmailTemplate records by their DeveloperName field values.
	 *
	 * @param uniqueNames A set of DeveloperName values for the EmailTemplate records to retrieve
	 *
	 * @return A list of EmailTemplate records that match the specified DeveloperName values
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Set<String> templateNames = new Set<String>{'WelcomeTemplate', 'ReminderTemplate'};
	 * List<EmailTemplate> templates = new SEL_EmailTemplate().findByName(templateNames);
	 * ```
	 */
	global List<EmailTemplate> findByName(Set<String> uniqueNames)
	{
		return findByField(EmailTemplate.DeveloperName, UTIL_Set.stringToObject(uniqueNames));
	}
}