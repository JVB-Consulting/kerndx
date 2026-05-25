// ============================================================================
// Section 24: Delegation Mode Caller Overrides — Setting Precedence
// ============================================================================
// Tests that caller-provided settings (credential, path, retry, circuit
// breaker, log failures) override subscriber handler ApiSetting__mdt
// defaults when using UTIL_HttpClient delegation mode. Since anonymous Apex
// cannot use Test.startTest/stopTest, these tests verify the CMDT
// configuration that supports override merging.
//
// Prerequisites:
//   - kern managed package installed
//   - API_EchoSubscriber class deployed
//   - kern__ApiSetting__mdt.EchoSubscriber record configured
//
// Run:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f scripts/section-24-delegation-overrides.apex
// ============================================================================

try
{
	// -----------------------------------------------------------------------
	// Test 24a: Verify EchoSubscriber CMDT has baseline values for override tests
	// -----------------------------------------------------------------------
	{
		List<kern__ApiSetting__mdt> settings =
		[
				SELECT
						kern__EndpointPath__c,
						kern__MaxRetryCount__c,
						kern__CircuitBreakerEnabled__c,
						kern__LogIssues__c,
						kern__MockingEnabled__c,
						kern__IsActive__c
				FROM kern__ApiSetting__mdt
				WHERE kern__ClassName__c = 'API_EchoSubscriber'
		];

		System.assert(!settings.isEmpty(), '24a FAIL: No ApiSetting__mdt found for API_EchoSubscriber');

		kern__ApiSetting__mdt setting = settings[0];
		System.assert(
				setting.kern__EndpointPath__c == '/echo',
				'24a FAIL: EndpointPath should be /echo, got: ' + setting.kern__EndpointPath__c
		);
		System.assert(
				setting.kern__CircuitBreakerEnabled__c == false,
				'24a FAIL: CircuitBreakerEnabled should be false'
		);
		System.assert(
				setting.kern__LogIssues__c == true,
				'24a FAIL: LogIssues should be true'
		);
		System.debug('24a PASS: EchoSubscriber CMDT has expected baseline values (path=/echo, CB=false, LogIssues=true)');
	}

	// -----------------------------------------------------------------------
	// Test 24b: Verify MaxRetryCount is null on CMDT (baseline for override test)
	// -----------------------------------------------------------------------
	{
		kern__ApiSetting__mdt setting =
		[
				SELECT kern__MaxRetryCount__c
				FROM kern__ApiSetting__mdt
				WHERE kern__ClassName__c = 'API_EchoSubscriber'
				LIMIT 1
		];

		System.assert(
				setting.kern__MaxRetryCount__c == null,
				'24b FAIL: MaxRetryCount should be null (baseline), got: ' + setting.kern__MaxRetryCount__c
		);
		System.debug('24b PASS: EchoSubscriber CMDT MaxRetryCount is null — overrides will apply cleanly');
	}

	// -----------------------------------------------------------------------
	// Test 24c: Verify RetryBackoffSeconds is null on CMDT (baseline)
	// -----------------------------------------------------------------------
	{
		kern__ApiSetting__mdt setting =
		[
				SELECT kern__RetryBackoffSeconds__c
				FROM kern__ApiSetting__mdt
				WHERE kern__ClassName__c = 'API_EchoSubscriber'
				LIMIT 1
		];

		System.assert(
				setting.kern__RetryBackoffSeconds__c == null,
				'24c FAIL: RetryBackoffSeconds should be null (baseline), got: ' + setting.kern__RetryBackoffSeconds__c
		);
		System.debug('24c PASS: EchoSubscriber CMDT RetryBackoffSeconds is null — overrides will apply cleanly');
	}

	// -----------------------------------------------------------------------
	// Test 24d: Verify ApiCredential is null on CMDT (enables auto-mock baseline)
	// -----------------------------------------------------------------------
	{
		kern__ApiSetting__mdt setting =
		[
				SELECT kern__ApiCredential__c
				FROM kern__ApiSetting__mdt
				WHERE kern__ClassName__c = 'API_EchoSubscriber'
				LIMIT 1
		];

		System.assert(
				setting.kern__ApiCredential__c == null,
				'24d FAIL: ApiCredential should be null (no Named Credential), got: ' + setting.kern__ApiCredential__c
		);
		System.debug('24d PASS: EchoSubscriber CMDT has no ApiCredential — credential override will be fresh');
	}

	// -----------------------------------------------------------------------
	// Test 24e: Verify MockingEnabled is true on CMDT (auto-mock active)
	// -----------------------------------------------------------------------
	{
		kern__ApiSetting__mdt setting =
		[
				SELECT kern__MockingEnabled__c
				FROM kern__ApiSetting__mdt
				WHERE kern__ClassName__c = 'API_EchoSubscriber'
				LIMIT 1
		];

		System.assert(
				setting.kern__MockingEnabled__c == true,
				'24e FAIL: MockingEnabled should be true for test environment'
		);
		System.debug('24e PASS: EchoSubscriber CMDT MockingEnabled=true — delegation auto-mock will activate');
	}

	System.debug('=== Section 24 COMPLETE: All delegation override baseline tests passed ===');
}
catch(Exception error)
{
	System.debug('Section 24 FAILED with exception: ' + error.getMessage());
	System.debug(error.getStackTraceString());
}
