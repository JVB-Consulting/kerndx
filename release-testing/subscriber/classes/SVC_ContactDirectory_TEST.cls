// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for SVC_ContactDirectory.
 *
 * @see SVC_ContactDirectory
 *
 * @author your.name@company.com
 *
 * @group Services
 *
 * @date February 2026
 */
@IsTest(IsParallel=false)
private class SVC_ContactDirectory_TEST
{
	/** @description Tests that createContact inserts a Contact in USER_MODE. */
	@IsTest
	private static void shouldCreateContact()
	{
		kern.DML_Builder.TransactionResult result =
				new SVC_ContactDirectory().createContact('Test', 'Person');

		Assert.isTrue(result.isSuccess(), 'Create should succeed for an admin running the test');
		Assert.areEqual(1, result.getSuccessCount(), 'Should insert exactly one Contact');
	}

	/** @description Tests that findByLastName returns matching Contacts. */
	@IsTest
	private static void shouldFindContactsByLastName()
	{
		kern.TST_Builder.of(Contact.SObjectType)
				.withOverride(Contact.FirstName, 'Find')
				.withOverride(Contact.LastName, 'Target')
				.build();

		List<Contact> found = new SVC_ContactDirectory().findByLastName('Target');

		Assert.areEqual(1, found.size(), 'Should return the matching Contact');
		Assert.areEqual('Find', found[0].FirstName, 'Should return the correct Contact');
	}

	/**
	 * @description Proves USER_MODE enforces the *running user's* permissions. A minimum-access user
	 * with no Contact access is rejected by the secure read — the admin running the test would have
	 * sailed straight through, which is exactly the trap USER_MODE closes.
	 */
	@IsTest
	private static void shouldEnforceRunningUserPermissionsOnRead()
	{
		kern.TST_Builder.of(Contact.SObjectType)
				.withOverride(Contact.FirstName, 'Scoped')
				.withOverride(Contact.LastName, 'Reader')
				.build();

		User minimumAccessUser = buildMinimumAccessUser();
		Boolean rejected = false;

		System.runAs(minimumAccessUser)
		{
			try
			{
				new SVC_ContactDirectory().findByLastName('Reader');
			}
			catch(Exception error)
			{
				rejected = true;
			}
		}

		Assert.isTrue(rejected,
				'USER_MODE must reject a user without Contact access — proving the framework enforces '
				+ 'the running user\'s permissions, not the admin\'s');
	}

	/**
	 * @description Builds a minimum-access user for running-user enforcement tests.
	 *
	 * @return A User assigned the Minimum Access profile.
	 */
	private static User buildMinimumAccessUser()
	{
		Profile minimumAccess = (Profile)kern.QRY_Builder.selectFrom(Profile.SObjectType)
				.fields(new List<SObjectField> {Profile.Id})
				.condition(Profile.Name).equals('Minimum Access - Salesforce')
				.getFirst();

		return (User)kern.TST_Builder.of(User.SObjectType)
				.withOverride(User.ProfileId, minimumAccess.Id)
				.withOverride(User.LastName, 'Scoped')
				.withOverride(User.Alias, 'scoped')
				.withOverride(User.Email, 'scoped.reader@example.com')
				.withOverride(User.Username, 'scoped.reader.' + DateTime.now().getTime() + '@example.com')
				.withOverride(User.EmailEncodingKey, 'UTF-8')
				.withOverride(User.LanguageLocaleKey, 'en_US')
				.withOverride(User.LocaleSidKey, 'en_US')
				.withOverride(User.TimeZoneSidKey, 'America/Los_Angeles')
				.build();
	}
}
