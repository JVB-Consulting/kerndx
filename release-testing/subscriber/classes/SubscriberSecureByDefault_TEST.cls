// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Subscriber proof that secure-by-default enforcement is real. These tests
 * use `System.runAs` (only available in @IsTest context) to impersonate a Standard User who has
 * no kern__ApiCall__c CRUD, then invoke the managed-package QRY_Builder + DML_Builder to verify
 * USER_MODE rejects the operation and explicit `.withSystemMode()` / `.withUserMode()` overrides
 * behave as documented.
 *
 * The anonymous-Apex counterpart (section-35-secure-by-default.apex) validates the flag state and
 * the API surface; this test class exercises the runtime enforcement layer that anonymous Apex
 * cannot reach.
 *
 * @see kern.UTIL_FeatureFlag
 * @see kern.QRY_Builder
 * @see kern.DML_Builder
 *
 * @author Jason van Beukering
 *
 * @group Security
 *
 * @date April 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(IsParallel=false)
private class SubscriberSecureByDefault_TEST
{
	/**
	 * @description Developer name of the subscriber-overrideable USER_MODE query flag.
	 */
	private static final String FLAG_QUERIES = 'UserModeQueries_Enabled';

	/**
	 * @description Developer name of the subscriber-overrideable USER_MODE DML flag.
	 */
	private static final String FLAG_DML = 'UserModeDml_Enabled';

	/**
	 * @description `UserModeQueries_Enabled` should resolve to `true` against the shipped CMDT.
	 */
	@IsTest
	private static void queriesFlagShouldReportEnabledByDefault()
	{
		Test.startTest();

		Boolean enabled = kern.UTIL_FeatureFlag.isEnabled(FLAG_QUERIES);

		Test.stopTest();

		Assert.isTrue(enabled, FLAG_QUERIES + ' should resolve true in the shipped default state');
	}

	/**
	 * @description `UserModeDml_Enabled` should resolve to `true` against the shipped CMDT.
	 */
	@IsTest
	private static void dmlFlagShouldReportEnabledByDefault()
	{
		Test.startTest();

		Boolean enabled = kern.UTIL_FeatureFlag.isEnabled(FLAG_DML);

		Test.stopTest();

		Assert.isTrue(enabled, FLAG_DML + ' should resolve true in the shipped default state');
	}

	/**
	 * @description A Standard User without `kern__ApiCall__c` CRUD should be rejected by the
	 * default `QRY_Builder.selectFrom(...).toList()` path because the flag-driven default is
	 * USER_MODE.
	 */
	@IsTest
	private static void defaultQueryShouldRejectUserWithoutCrud()
	{
		User standardUser = createStandardUser();
		Boolean rejected = false;

		Test.startTest();

		System.runAs(standardUser)
		{
			try
			{
				kern.QRY_Builder.selectFrom(kern__ApiCall__c.SObjectType)
						.fields(new List<Schema.SObjectField> {kern__ApiCall__c.Id})
						.toList();
			}
			catch(Exception error)
			{
				rejected = true;
			}
		}

		Test.stopTest();

		Assert.isTrue(rejected, 'Default QRY_Builder query should reject a Standard User without kern__ApiCall__c read');
	}

	/**
	 * @description Explicit `.withSystemMode()` on `QRY_Builder` should bypass the flag-driven
	 * USER_MODE default and complete the query for a Standard User.
	 */
	@IsTest
	private static void withSystemModeShouldBypassQueryEnforcement()
	{
		User standardUser = createStandardUser();
		Boolean succeeded = false;

		Test.startTest();

		System.runAs(standardUser)
		{
			try
			{
				kern.QRY_Builder.selectFrom(kern__ApiCall__c.SObjectType)
						.fields(new List<Schema.SObjectField> {kern__ApiCall__c.Id})
						.withSystemMode()
						.toList();
				succeeded = true;
			}
			catch(Exception error)
			{
				System.debug('.withSystemMode() unexpected error: ' + error.getMessage());
			}
		}

		Test.stopTest();

		Assert.isTrue(succeeded, '.withSystemMode() on QRY_Builder should allow the query for a Standard User');
	}

	/**
	 * @description A Standard User without `kern__ApiCall__c` CRUD should be rejected by the
	 * default `DML_Builder.newTransaction().doInsert(...).execute()` path because the flag-driven
	 * default is USER_MODE.
	 */
	@IsTest
	private static void defaultDmlShouldRejectUserWithoutCrud()
	{
		User standardUser = createStandardUser();
		Boolean rejected = false;

		Test.startTest();

		System.runAs(standardUser)
		{
			try
			{
				kern__ApiCall__c record = new kern__ApiCall__c(kern__ServiceName__c = 'SubscriberSecureByDefault.DmlReject');
				kern.DML_Builder.TransactionResult result = kern.DML_Builder.newTransaction()
						.doInsert(record)
						.execute();
				if(!result.isSuccess())
				{
					rejected = true;
				}
			}
			catch(Exception error)
			{
				rejected = true;
			}
		}

		Test.stopTest();

		Assert.isTrue(rejected, 'Default DML_Builder insert should reject a Standard User without kern__ApiCall__c create');
	}

	/**
	 * @description Explicit `.withSystemMode()` on `DML_Builder` should bypass the flag-driven
	 * USER_MODE default and complete the insert for a Standard User.
	 */
	@IsTest
	private static void withSystemModeShouldBypassDmlEnforcement()
	{
		User standardUser = createStandardUser();
		Boolean succeeded = false;

		Test.startTest();

		System.runAs(standardUser)
		{
			try
			{
				kern__ApiCall__c record = new kern__ApiCall__c(kern__ServiceName__c = 'SubscriberSecureByDefault.DmlBypass');
				kern.DML_Builder.TransactionResult result = kern.DML_Builder.newTransaction()
						.doInsert(record)
						.withSystemMode()
						.execute();
				succeeded = result.isSuccess();
			}
			catch(Exception error)
			{
				System.debug('.withSystemMode() DML unexpected error: ' + error.getMessage());
			}
		}

		Test.stopTest();

		Assert.isTrue(succeeded, '.withSystemMode() on DML_Builder should allow the insert for a Standard User');
	}

	/**
	 * @description Explicit `.withUserMode()` on `QRY_Builder` should force USER_MODE regardless
	 * of the flag state — a Standard User without CRUD must still be rejected.
	 */
	@IsTest
	private static void withUserModeShouldEnforceIrrespectiveOfFlag()
	{
		User standardUser = createStandardUser();
		Boolean rejected = false;

		Test.startTest();

		System.runAs(standardUser)
		{
			try
			{
				kern.QRY_Builder.selectFrom(kern__ApiCall__c.SObjectType)
						.fields(new List<Schema.SObjectField> {kern__ApiCall__c.Id})
						.withUserMode()
						.toList();
			}
			catch(Exception error)
			{
				rejected = true;
			}
		}

		Test.stopTest();

		Assert.isTrue(rejected, 'Explicit .withUserMode() should reject a Standard User without CRUD');
	}

	/**
	 * @description Managed `SEL_Group` overrides `systemModeRequired()` to pin SYSTEM_MODE — a
	 * Standard User who would otherwise fail a USER_MODE `Group` read should succeed here.
	 */
	@IsTest
	private static void systemModeRequiredHookShouldPinManagedSelector()
	{
		User standardUser = createStandardUser();
		Boolean succeeded = false;

		Test.startTest();

		System.runAs(standardUser)
		{
			try
			{
				new kern.SEL_Group().findByName('SubscriberSecureByDefault_NonExistent');
				succeeded = true;
			}
			catch(Exception error)
			{
				System.debug('SEL_Group.findByName unexpected error: ' + error.getMessage());
			}
		}

		Test.stopTest();

		Assert.isTrue(succeeded, 'kern.SEL_Group.systemModeRequired() hook should pin SYSTEM_MODE and allow the query');
	}

	/**
	 * @description Creates a Standard User with no kern managed-package permission sets. The
	 * test context never commits this user — they exist only for the scope of `System.runAs`.
	 *
	 * @return The Standard User instance.
	 */
	private static User createStandardUser()
	{
		Profile standardProfile =
		[
				SELECT Id
				FROM Profile
				WHERE Name = 'Standard User'
				LIMIT 1
		];
		String suffix = String.valueOf(Crypto.getRandomInteger()).right(8);
		User user = new User
				(
						FirstName = 'Secure',
						LastName = 'ByDefault',
						Email = 'secure-by-default-' + suffix + '@kerndx.test',
						Username = 'secure-by-default-' + suffix + '@kerndx.test.invalid',
						Alias = 'sbd' + suffix.right(3),
						TimeZoneSidKey = 'America/New_York',
						LocaleSidKey = 'en_US',
						EmailEncodingKey = 'UTF-8',
						LanguageLocaleKey = 'en_US',
						ProfileId = standardProfile.Id
				);
		insert User;
		return User;
	}
}
