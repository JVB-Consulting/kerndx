// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests behaviour that belongs directly to `API_Outbound` — specifically the
 * framework-validation branches that are difficult to reach through subclass test helpers
 * because real `ApiSetting__mdt` records exist for every shipped subclass.
 *
 * @see API_Outbound
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date April 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
public class API_Outbound_TEST
{
	/**
	 * @description Service name pointing at the inner `TestableOutbound` class — chosen because
	 * no `ApiSetting__mdt` record ships for this name, so `setting == null` inside
	 * `performValidation()` is guaranteed to fire.
	 */
	private static final String SERVICE_NAME = API_Outbound_TEST.TestableOutbound.class.getName();

	/**
	 * @description Expected error fragment emitted by `performValidation()` when no
	 * `ApiSetting__mdt` record matches the service name.
	 */
	private static final String EXPECTED_ERROR_FRAGMENT = 'API setting record not found for service';

	/**
	 * @description Dispatching an outbound ApiCall__c whose ServiceName__c points at a handler
	 * class with no matching `ApiSetting__mdt` record should abort with the "API setting record
	 * not found" error — covering the framework-validation branch at API_Outbound L297-L301.
	 */
	@IsTest
	private static void shouldAbortCallWhenApiSettingRecordIsMissing()
	{
		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(SERVICE_NAME, UserInfo.getUserId());

		Test.startTest();

		List<API_Base> handlers = API_Dispatcher.execute(new List<ApiCall__c> {apiCall});

		Test.stopTest();

		Assert.areEqual(1, handlers.size(), 'Dispatcher should return a single handler');

		API_Base handler = handlers.iterator().next();
		Boolean hasExpectedError = false;
		for(String errorText : handler.result.errors)
		{
			if(errorText.contains(EXPECTED_ERROR_FRAGMENT))
			{
				hasExpectedError = true;
				break;
			}
		}

		Assert.isTrue(hasExpectedError, 'Missing ApiSetting__mdt should surface "API setting record not found" error. Got: ' + handler.result.errors);
	}

	/**
	 * @description Test-only outbound handler with no `ApiSetting__mdt` record. Deliberately
	 * minimal — `configure()` only sets the request/response DTOs the validation pipeline expects
	 * before it reaches the setting-lookup branch.
	 */
	public class TestableOutbound extends API_Outbound
	{
		/**
		 * @description Initialises the handler — identical to `API_Outbound.configure()` plus DTO
		 * setup, so the validation pipeline advances to the `setting == null` check instead of
		 * aborting earlier on a missing payload.
		 */
		public override void configure()
		{
			super.configure();
			requestPayload = new DTO_Payload();
			responsePayload = new DTO_Payload();
		}
	}

	/**
	 * @description Minimal DTO — any payload satisfies the base-level DTO check. Its contents are
	 * irrelevant because the test aborts at the setting-lookup branch before any HTTP work fires.
	 */
	@JsonAccess(Serializable='always' Deserializable='always')
	public class DTO_Payload extends DTO_JsonBase
	{
	}
}