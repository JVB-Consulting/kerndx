// ============================================================================
// Section 7: Outbound API Lifecycle — Configuration Verification
// ============================================================================
// Tests outbound API configuration and framework readiness in the subscriber
// org. Since anonymous Apex cannot use Test.startTest/stopTest or
// HttpCalloutMock, these tests verify metadata configuration, record creation,
// and feature flag states rather than executing actual callouts.
//
// Prerequisites:
//   - kern managed package installed
//   - API_EchoSubscriber class deployed
//   - kern__ApiSetting__mdt records configured for the echo service
//   - kern__FeatureFlag__mdt records deployed
//
// Run:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f scripts/section-7-outbound-api.apex
// ============================================================================

List<Id> cleanupIds = new List<Id>();

try
{
	// -----------------------------------------------------------------------
	// Test 7a: Verify ApiSetting__mdt configuration exists for echo service
	// -----------------------------------------------------------------------
	{
		List<kern__ApiSetting__mdt> settings =
		[
				SELECT
						DeveloperName,
						kern__ClassName__c,
						kern__Direction__c,
						kern__IsActive__c,
						kern__EndpointPath__c,
						kern__MockingEnabled__c
				FROM kern__ApiSetting__mdt
				WHERE kern__ClassName__c = 'API_EchoSubscriber'
		];

		System.assert(!settings.isEmpty(), '7a FAIL: No ApiSetting__mdt found for API_EchoSubscriber');

		kern__ApiSetting__mdt setting = settings[0];
		System.assert(
				setting.kern__Direction__c == 'Outbound',
				'7a FAIL: Direction should be Outbound, got: ' + setting.kern__Direction__c
		);
		System.assert(
				setting.kern__IsActive__c == true,
				'7a FAIL: ApiSetting should be active'
		);
		System.debug('7a PASS: ApiSetting__mdt exists for API_EchoSubscriber (Direction=Outbound, IsActive=true)');
	}

	// -----------------------------------------------------------------------
	// Test 7b: Create an ApiCall__c record and verify it persists
	// -----------------------------------------------------------------------
	// This tests that the ApiCall__c custom object is accessible in the
	// subscriber org and records can be created with package-prefixed fields.
	{
		kern__ApiCall__c apiCall = new kern__ApiCall__c(
				kern__ServiceName__c = 'API_EchoSubscriber',
				kern__Status__c = 'Queued',
				kern__Direction__c = 'Outbound',
				kern__HttpMethod__c = 'POST'
		);
		insert apiCall;
		cleanupIds.add(apiCall.Id);

		kern__ApiCall__c result =
		[
				SELECT Id,
						kern__ServiceName__c,
						kern__Status__c,
						kern__Direction__c
				FROM kern__ApiCall__c
				WHERE Id = :apiCall.Id
		];

		System.assert(result != null, '7b FAIL: ApiCall record should exist after insert');
		System.assert(
				result.kern__ServiceName__c == 'API_EchoSubscriber',
				'7b FAIL: ServiceName should be API_EchoSubscriber, got: ' + result.kern__ServiceName__c
		);
		System.assert(
				result.kern__Status__c == 'Queued',
				'7b FAIL: Status should be Queued, got: ' + result.kern__Status__c
		);
		System.debug('7b PASS: ApiCall__c record created and verified with correct field values');
	}

	// -----------------------------------------------------------------------
	// Test 7c: Verify DisableAllOutboundAPIs feature flag is not enabled
	// -----------------------------------------------------------------------
	// In a healthy subscriber org, outbound APIs should not be globally
	// disabled. This flag should either not exist or be disabled.
	{
		Boolean isDisabled = kern.UTIL_FeatureFlag.isEnabled('DisableAllOutboundAPIs');

		System.assert(
				!isDisabled,
				'7c FAIL: DisableAllOutboundAPIs should not be enabled in a test subscriber org'
		);
		System.debug('7c PASS: DisableAllOutboundAPIs is not enabled — outbound APIs are operational');
	}

	// -----------------------------------------------------------------------
	// Test 7d: Check MockAllAPIs feature flag status
	// -----------------------------------------------------------------------
	// MockAllAPIs may or may not be enabled depending on subscriber config.
	// This test verifies the flag can be queried without error and reports
	// its current state.
	{
		Boolean isMockEnabled = kern.UTIL_FeatureFlag.isEnabled('MockAllAPIs');

		// This is informational — both states are valid for a subscriber org
		System.debug('7d INFO: MockAllAPIs is ' + (isMockEnabled ? 'ENABLED' : 'DISABLED'));

		// Verify the API is callable and returns a Boolean (not null/exception)
		System.assert(
				isMockEnabled == true || isMockEnabled == false,
				'7d FAIL: UTIL_FeatureFlag.isEnabled should return a non-null Boolean'
		);
		System.debug('7d PASS: MockAllAPIs feature flag is queryable (current state: ' + isMockEnabled + ')');
	}

	System.debug('=== Section 7 COMPLETE: All outbound API configuration tests passed ===');
}
finally
{
	// Cleanup: delete test ApiCall records
	if(!cleanupIds.isEmpty())
	{
		delete
		[
				SELECT Id
				FROM kern__ApiCall__c
				WHERE Id IN :cleanupIds
		];
		System.debug('Cleanup: Deleted ' + cleanupIds.size() + ' test ApiCall record(s)');
	}
}
