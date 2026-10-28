// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Proves, on a subscriber org and through the global API only, when a service answers from mock data
 * because its API Setting has Mocking Enabled ticked. The box picks the service, and the Mock Selected APIs feature flag
 * turns mocking on for the users it is on for. The box on its own mocks nothing. Each test checks the Mocked Response box
 * on the saved call, because in a unit test a call that is not mocked also gets an answer.
 *
 * The tests where the flag is off read the org's own Mock Selected APIs record: a subscriber test cannot register a
 * flag as off. So run this class only while Mock Selected APIs, Mock All APIs and Mock All Inbound APIs are all off for
 * the running user. In release testing that is the section27-mock-disabled state: before section 27 applies its
 * enabled state, or after it puts the disabled state back. Each test first checks the three flags and fails with a
 * clear message when one of them is on.
 *
 * @see API_EchoSubscriber
 * @see API_SubscriberCreateAccount
 * @see kern.API_Dispatcher
 * @see kern.SEL_ApiCall
 * @see kern.UTIL_FeatureFlag
 *
 * @author your.name@company.com
 *
 * @group Web Services
 *
 * @date October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=true)
private class SubscriberSelectedMocking_TEST
{
	/**
	 * @description The outgoing service each outgoing test sends through. Its calls carry this name.
	 */
	private static final String OUTBOUND_SERVICE_NAME = API_EchoSubscriber.class.getName();

	/**
	 * @description The developer name of the outgoing service's API Setting. The org's API Mock records for this service
	 * point at a setting with this name, so the registered setting carries it too.
	 */
	private static final String OUTBOUND_SETTING_DEVELOPER_NAME = 'EchoSubscriber';

	/**
	 * @description The incoming service each incoming test runs. Its calls carry this name.
	 */
	private static final String INBOUND_SERVICE_NAME = API_SubscriberCreateAccount.class.getName();

	/**
	 * @description The developer name of the incoming service's API Setting. The org's API Mock records for this service
	 * point at a setting with this name, so the registered setting carries it too.
	 */
	private static final String INBOUND_SETTING_DEVELOPER_NAME = 'SubscriberCreateAccount';

	/**
	 * @description The endpoint path of the incoming setting each incoming test registers.
	 */
	private static final String INBOUND_ENDPOINT_PATH = '/subscriber/accounts';

	/**
	 * @description The routing priority of the incoming setting. Any value works, because each test registers one setting.
	 */
	private static final Integer INBOUND_ROUTE_PRIORITY = 100;

	/**
	 * @description The industry each incoming request sends. The service requires one.
	 */
	private static final String INDUSTRY = 'Technology';

	/**
	 * @description A phone number short enough for the Account field. The subscriber org's Account rule asks for a phone or
	 * a website, so each incoming request sends one.
	 */
	private static final String VALID_PHONE = '555-0100';

	/**
	 * @description The developer name of the feature flag that turns on mocking for the services whose API Setting has
	 * Mocking Enabled ticked.
	 */
	private static final String FLAG_MOCK_SELECTED_APIS = 'MockSelectedAPIs';

	/**
	 * @description The developer name of the feature flag that makes every outgoing service answer from mock data.
	 */
	private static final String FLAG_MOCK_ALL_APIS = 'MockAllAPIs';

	/**
	 * @description The developer name of the feature flag that makes every incoming service answer from mock data.
	 */
	private static final String FLAG_MOCK_ALL_INBOUND_APIS = 'MockAllInboundAPIs';

	/**
	 * @description The message a test fails with when one of the three mocking flags is already on for the running user.
	 */
	private static final String MESSAGE_MOCKING_FLAG_ON = 'Mock Selected APIs, Mock All APIs or Mock All Inbound APIs is on for the running user: '
			+ 'run this class outside section 27\'s enabled state';

	/**
	 * @description An outgoing service whose API Setting has Mocking Enabled ticked, while Mock Selected APIs is off,
	 * calls the real system. Its saved call is not marked as mocked.
	 */
	@IsTest
	private static void shouldNotMockOutboundWhenOnlyTheBoxIsTicked()
	{
		assertNoMockingFlagIsOn();
		registerOutboundSetting();

		Test.startTest();
		kern.API_Dispatcher.execute(kern.TST_Factory.newOutboundApiCall(OUTBOUND_SERVICE_NAME));
		Test.stopTest();

		Assert.isFalse(readIsMockedResponse(OUTBOUND_SERVICE_NAME), 'Expected the outgoing call not to be marked as mocked with only the box ticked');
	}

	/**
	 * @description An outgoing service whose API Setting has Mocking Enabled ticked answers from mock data once Mock
	 * Selected APIs is on for the running user. Its saved call is marked as mocked.
	 */
	@IsTest
	private static void shouldMockOutboundWhenTheBoxIsTickedAndTheFlagIsOn()
	{
		assertNoMockingFlagIsOn();
		registerOutboundSetting();
		kern.TST_Factory.newFeatureFlag(FLAG_MOCK_SELECTED_APIS);

		Test.startTest();
		kern.API_Dispatcher.execute(kern.TST_Factory.newOutboundApiCall(OUTBOUND_SERVICE_NAME));
		Test.stopTest();

		Assert.isTrue(readIsMockedResponse(OUTBOUND_SERVICE_NAME), 'Expected the outgoing call to be marked as mocked with the box ticked and the flag on');
	}

	/**
	 * @description An incoming service whose API Setting has Mocking Enabled ticked, while Mock Selected APIs is off, runs
	 * its own code. Its saved call is not marked as mocked.
	 */
	@IsTest
	private static void shouldNotMockInboundWhenOnlyTheBoxIsTicked()
	{
		assertNoMockingFlagIsOn();
		registerInboundSetting();
		setupRequest();

		Test.startTest();
		kern.API_Dispatcher.processInboundService(INBOUND_SERVICE_NAME);
		Test.stopTest();

		Assert.isFalse(readIsMockedResponse(INBOUND_SERVICE_NAME), 'Expected the incoming call not to be marked as mocked with only the box ticked');
	}

	/**
	 * @description An incoming service whose API Setting has Mocking Enabled ticked answers from mock data once Mock
	 * Selected APIs is on for the running user. Its saved call is marked as mocked.
	 */
	@IsTest
	private static void shouldMockInboundWhenTheBoxIsTickedAndTheFlagIsOn()
	{
		assertNoMockingFlagIsOn();
		registerInboundSetting();
		kern.TST_Factory.newFeatureFlag(FLAG_MOCK_SELECTED_APIS);
		setupRequest();

		Test.startTest();
		kern.API_Dispatcher.processInboundService(INBOUND_SERVICE_NAME);
		Test.stopTest();

		Assert.isTrue(readIsMockedResponse(INBOUND_SERVICE_NAME), 'Expected the incoming call to be marked as mocked with the box ticked and the flag on');
	}

	/**
	 * @description Checks, before anything else is set up, that Mock Selected APIs, Mock All APIs and Mock All Inbound APIs
	 * are all off for the running user. The tests where the flag is off read the org's own records, so one of these flags
	 * being on would make them fail for the wrong reason. Mock All Inbound APIs on its own would make the incoming service
	 * answer from mock data.
	 */
	private static void assertNoMockingFlagIsOn()
	{
		for(String flagName : new List<String> {FLAG_MOCK_SELECTED_APIS, FLAG_MOCK_ALL_APIS, FLAG_MOCK_ALL_INBOUND_APIS})
		{
			if(kern.UTIL_FeatureFlag.isEnabled(flagName))
			{
				Assert.fail(MESSAGE_MOCKING_FLAG_ON);
			}
		}
	}

	/**
	 * @description Registers the outgoing service's API Setting in memory for this test only (no record is saved), with
	 * Mocking Enabled ticked and the developer name the org's API Mock records point at.
	 */
	private static void registerOutboundSetting()
	{
		kern.TST_Factory.newOutboundApiSetting(OUTBOUND_SERVICE_NAME, new Map<SObjectField, Object>
		{
				kern__ApiSetting__mdt.DeveloperName => OUTBOUND_SETTING_DEVELOPER_NAME,
				kern__ApiSetting__mdt.kern__MockingEnabled__c => true
		});
	}

	/**
	 * @description Registers the incoming service's API Setting in memory for this test only (no record is saved), routed
	 * to the endpoint path, with Mocking Enabled ticked and the developer name the org's API Mock records point at.
	 */
	private static void registerInboundSetting()
	{
		kern.TST_Factory.newInboundApiSetting(INBOUND_SERVICE_NAME, INBOUND_ENDPOINT_PATH, INBOUND_ROUTE_PRIORITY, new Map<SObjectField, Object>
		{
				kern__ApiSetting__mdt.DeveloperName => INBOUND_SETTING_DEVELOPER_NAME,
				kern__ApiSetting__mdt.kern__MockingEnabled__c => true
		});
	}

	/**
	 * @description Sets up a POST request to the endpoint with a JSON body that creates one Account with a random name.
	 */
	private static void setupRequest()
	{
		API_SubscriberCreateAccount.DTO_Request request = new API_SubscriberCreateAccount.DTO_Request();
		request.accountName = kern.UTIL_Random.randomName();
		request.industry = INDUSTRY;
		request.phone = VALID_PHONE;
		kern.API_InboundTestHelper.setupRestContext(request);
	}

	/**
	 * @description Reads the one call the service saved and returns its Mocked Response box.
	 *
	 * @param serviceName The name of the service.
	 *
	 * @return Whether the saved call is marked as mocked.
	 */
	private static Boolean readIsMockedResponse(String serviceName)
	{
		List<kern__ApiCall__c> calls = new kern.SEL_ApiCall().query
				.addFields(new List<SObjectField> {kern__ApiCall__c.kern__IsMockedResponse__c})
				.condition(kern__ApiCall__c.kern__ServiceName__c).equals(serviceName)
				.toList();
		Assert.areEqual(1, calls.size(), 'Expected one saved call for ' + serviceName + ', got ' + calls.size());
		return calls.iterator().next().kern__IsMockedResponse__c;
	}
}
