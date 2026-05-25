// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Test class for the API_PublishGenericEvent Handler class
 *
 * @see API_PublishGenericEvent
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date January 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class API_PublishGenericEvent_TEST
{
	private static final String SERVICE_NAME = API_PublishGenericEvent.class.getName();

	/**
	 * @description Emulates a successful call
	 */
	@IsTest
	private static void successfulCall()
	{
		API_OutboundTestHelper.assertCallSuccessful(SERVICE_NAME, UTIL_Random.randomId(StreamingChannel.SObjectType), API_PublishGenericEvent.REQUIRED_PARAMETER_PAYLOAD);
	}

	/**
	 * @description Emulates an aborted call due to an missing payload parameter
	 */
	@IsTest
	private static void abortedMissingPayloadParameter()
	{
		API_OutboundTestHelper.assertCallAborted(SERVICE_NAME, UTIL_Random.randomId(StreamingChannel.SObjectType));
	}
}