// SPDX-License-Identifier: Apache-2.0
/**
 * @description Test class for the API_GetPwndPasswords handler, which checks passwords against a breach database.
 *
 * @see API_GetPwndPasswords
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=false)
private class API_GetPwndPasswords_TEST
{
	/**
	 * @description Company name given to the admin user created in test setup. It is unique to this class, so getTestAdmin
	 * can find that one user again by company name.
	 */
	private static final String TEST_ADMIN_COMPANY = 'API_GetPwndPasswords_TEST-admin';

	/**
	 * @description Failure message for the check that the service reported the password as found in the breach list.
	 * The placeholder {0} is filled with the value the handler actually returned.
	 */
	private static final String MSG_PASSWORD_FOUND = 'Expected password to be found in response, but found {0}';

	/**
	 * @description Failure message for the checks that the password does not appear in what was saved.
	 * The placeholder {0} is filled with the saved text, so a failing run shows what leaked.
	 */
	private static final String MSG_SENSITIVE_DATA_MASKED = 'Expected sensitive data to be masked, but found {0}';

	/**
	 * @description Name of the request parameter that carries the password, taken from the handler so the tests send
	 * the password under the same name the handler reads.
	 */
	private static final String PARAMETER_PASSWORD = API_GetPwndPasswords.PARAMETER_PASSWORD;

	/**
	 * @description Name of the service under test. It selects the handler to call and finds the saved ApiCall__c record
	 * for that call.
	 */
	private static final String SERVICE_NAME = API_GetPwndPasswords.class.getName();

	/**
	 * @description The password the tests send, taken from the handler. The tests search the saved record and stored
	 * files for this exact text to prove it was masked.
	 */
	private static final String TEST_PASSWORD = API_GetPwndPasswords.TEST_PASSWORD;

	/**
	 * @description Creates a dedicated test admin user so System.runAs in each test starts a fresh
	 * permission-evaluation context, bypassing the synthetic-org permission-cache staleness issue
	 * that affected mutating the running user's permissionSet mid-transaction.
	 */
	@TestSetup
	private static void setupTestAdmin()
	{
		TST_Factory.newUserWithPermissionSet
				(
						SEL_Profile.PROFILE_SYSTEM_ADMIN,
						TEST_ADMIN_COMPANY,
						SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME
				);
	}

	/**
	 * @description Tests a successful API call, verifying that sensitive data (password) is
	 * masked on the persisted ApiCall__c record. Masking happens via the trigger dispatcher's
	 * before-insert pre-step, which mutates the record's RequestParameters__c field in place —
	 * the in-memory `inputs` DTO on the handler stays as submitted.
	 */
	@IsTest
	private static void successful()
	{
		System.runAs(getTestAdmin())
		{
			assertSuccessful(createParameters(TEST_PASSWORD));
			ApiCall__c persistedCall = new SEL_ApiCall().findByServiceName(SERVICE_NAME).iterator().next();
			Assert.isFalse
					(
							persistedCall.RequestParameters__c.contains(TEST_PASSWORD),
							String.format(MSG_SENSITIVE_DATA_MASKED, new List<Object> {persistedCall.RequestParameters__c})
					);
		}
	}

	/**
	 * @description Tests that ContentVersion files created when the payload exceeds field
	 * length inherit the same masking applied to the ApiCall__c record fields. Uses the
	 * API_Base.simulateStoreToFile test hook to force file storage regardless of payload
	 * size, then reads the stored blob and asserts the raw password does not appear.
	 */
	@IsTest
	private static void shouldMaskSensitiveDataInStoredFiles()
	{
		System.runAs(getTestAdmin())
		{
			API_Base.simulateStoreToFile = true;

			API_GetPwndPasswords handler = assertSuccessful(createParameters(TEST_PASSWORD));

			List<ContentVersion> storedFiles = new SEL_ContentVersion().findByFirstPublishLocationId(handler.apiCall.Id);

			Assert.isFalse(storedFiles.isEmpty(), 'Expected ContentVersion files to be stored when simulateStoreToFile is on');

			for(ContentVersion version : storedFiles)
			{
				String storedContent = version.VersionData.toString();
				Assert.isFalse(storedContent.contains(TEST_PASSWORD), String.format(MSG_SENSITIVE_DATA_MASKED, new List<Object> {version.Title + ': ' + storedContent}));
			}
		}
	}

	/**
	 * @description Calls the API and asserts it completed successfully, verifying password is found.
	 *
	 * @param parameters The request parameters, including the password.
	 *
	 * @return The API_GetPwndPasswords handler instance.
	 */
	private static API_GetPwndPasswords assertSuccessful(Map<String, String> parameters)
	{
		API_GetPwndPasswords handler = (API_GetPwndPasswords)API_OutboundTestHelper.assertCallSuccessful(SERVICE_NAME, null, parameters);
		Assert.isTrue(handler.passwordFound, String.format(MSG_PASSWORD_FOUND, new List<Object> {handler.passwordFound}));
		return handler;
	}

	/**
	 * @description Creates request parameters with the specified password.
	 *
	 * @param password The password to include in the parameters.
	 *
	 * @return Map of request parameters.
	 */
	private static Map<String, String> createParameters(String password)
	{
		return new Map<String, String> {PARAMETER_PASSWORD => password};
	}

	/**
	 * @description Retrieves the committed test admin user set up in @TestSetup for use with
	 * System.runAs, so each test body runs with a fresh permission-evaluation context.
	 *
	 * @return The test admin User record.
	 */
	private static User getTestAdmin()
	{
		return new SEL_User().findByCompanyName(TEST_ADMIN_COMPANY);
	}
}