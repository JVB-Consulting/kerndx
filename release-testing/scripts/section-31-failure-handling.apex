// =============================================================================
// Section 31: Failure Handling & Issue Logging
// =============================================================================
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Prerequisites:
//   - kern managed package installed
//   - Subscriber test code deployed (API_EchoSubscriber, ApiSetting.EchoSubscriber CMDT)
//   - Platform Cache partition allocated (kern__Library)
//
// Exercises the full API framework pipeline with mocked failures via
// UTIL_HttpClient delegation mode through API_EchoSubscriber. Tests failure
// persistence, retry config propagation, failure rate injection, and ApiIssue
// logging. Uses delegation mode (not ad-hoc) because in-memory mocks only
// intercept real callouts in test context.
//
// Run:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-31-failure-handling.apex
// =============================================================================

Set<Id> baselineCallIds = new Map<Id, kern__ApiCall__c>(
[
		SELECT Id
		FROM kern__ApiCall__c
]
).keySet();
Set<Id> baselineIssueIds = new Map<Id, kern__ApiIssue__c>(
[
		SELECT Id
		FROM kern__ApiIssue__c
]
).keySet();
Set<Id> trackingCallIds = baselineCallIds.clone();
Set<Id> trackingIssueIds = baselineIssueIds.clone();

String echoService = API_EchoSubscriber.class.getName();
Integer expectedTotal = 0;

try
{
	// Test 31a: 500 mock → delegation → ApiCall persisted with StatusCode 500
	{
		kern.API_MockFactory.forService(echoService).body('{"error":"server error"}').statusCode(500).register();
		kern.UTIL_HttpClient.useHandler(API_EchoSubscriber.class)
				.withParameter('message', 'fail-31a')
				.invoke();
		expectedTotal++;

		List<kern__ApiCall__c> newCalls =
		[
				SELECT kern__StatusCode__c
				FROM kern__ApiCall__c
				WHERE Id NOT IN :trackingCallIds
		];
		System.assert(!newCalls.isEmpty(), '31a FAIL: ApiCall record should be created');
		kern__ApiCall__c lastCall = newCalls[newCalls.size() - 1];
		System.assert(
				lastCall.kern__StatusCode__c == '500',
				'31a FAIL: StatusCode should be 500, got ' + lastCall.kern__StatusCode__c
		);
		for(kern__ApiCall__c c : newCalls)
		{
			trackingCallIds.add(c.Id);
		}
		for(kern__ApiIssue__c i :
		[
				SELECT Id
				FROM kern__ApiIssue__c
				WHERE Id NOT IN :trackingIssueIds
		])
		{
			trackingIssueIds.add(i.Id);
		}
		System.debug('31a PASS: Delegation 500 mock persisted ApiCall with StatusCode 500');
	}

	// Test 31b: 200 mock → delegation → ApiCall persisted with StatusCode 200
	{
		kern.API_MockFactory.forService(echoService).body('{"ok":true}').statusCode(200).register();
		kern.UTIL_HttpClient.useHandler(API_EchoSubscriber.class)
				.withParameter('message', 'success-31b')
				.invoke();
		expectedTotal++;

		List<kern__ApiCall__c> newCalls =
		[
				SELECT kern__StatusCode__c
				FROM kern__ApiCall__c
				WHERE Id NOT IN :trackingCallIds
		];
		System.assert(!newCalls.isEmpty(), '31b FAIL: ApiCall record should be created');
		kern__ApiCall__c lastCall = newCalls[newCalls.size() - 1];
		System.assert(
				lastCall.kern__StatusCode__c == '200',
				'31b FAIL: StatusCode should be 200, got ' + lastCall.kern__StatusCode__c
		);
		for(kern__ApiCall__c c : newCalls)
		{
			trackingCallIds.add(c.Id);
		}
		System.debug('31b PASS: Delegation 200 mock persisted ApiCall with StatusCode 200');
	}

	// Test 31c: 500 mock with retry(2) → ApiCall shows retry configuration
	{
		kern.API_MockFactory.forService(echoService).body('{"error":"retry me"}').statusCode(500).register();
		kern.UTIL_HttpClient.useHandler(API_EchoSubscriber.class)
				.withRetry(2)
				.withParameter('message', 'retry-31c')
				.invoke();
		expectedTotal++;

		List<kern__ApiCall__c> newCalls =
		[
				SELECT kern__Retries__c,
						kern__MaxRetries__c
				FROM kern__ApiCall__c
				WHERE Id NOT IN :trackingCallIds
		];
		System.assert(!newCalls.isEmpty(), '31c FAIL: ApiCall record should be created');
		kern__ApiCall__c retryCall = newCalls[newCalls.size() - 1];
		System.assert(
				retryCall.kern__MaxRetries__c != null && retryCall.kern__MaxRetries__c >= 1,
				'31c FAIL: MaxRetries should be >= 1, got ' + retryCall.kern__MaxRetries__c
		);
		for(kern__ApiCall__c c : newCalls)
		{
			trackingCallIds.add(c.Id);
		}
		for(kern__ApiIssue__c i :
		[
				SELECT Id
				FROM kern__ApiIssue__c
				WHERE Id NOT IN :trackingIssueIds
		])
		{
			trackingIssueIds.add(i.Id);
		}
		System.debug('31c PASS: Delegation with retry(2) persisted MaxRetries=' + retryCall.kern__MaxRetries__c);
	}

	// Test 31d: 500 mock with failureRate=100 → 3 calls → all StatusCode 500
	{
		kern.API_MockFactory.forService(echoService)
				.body('{"error":"injected"}').statusCode(500).withFailureRate(100).register();
		for(Integer i = 0; i < 3; i++)
		{
			kern.UTIL_HttpClient.useHandler(API_EchoSubscriber.class)
					.withParameter('message', 'failrate-31d-' + i)
					.invoke();
		}
		expectedTotal += 3;

		List<kern__ApiCall__c> newCalls =
		[
				SELECT kern__StatusCode__c
				FROM kern__ApiCall__c
				WHERE Id NOT IN :trackingCallIds
		];
		Integer failCount = 0;
		for(kern__ApiCall__c c : newCalls)
		{
			if(c.kern__StatusCode__c == '500')
			{
				failCount++;
			}
		}
		System.assert(failCount == 3, '31d FAIL: All 3 calls should have StatusCode 500, got ' + failCount);
		for(kern__ApiCall__c c : newCalls)
		{
			trackingCallIds.add(c.Id);
		}
		for(kern__ApiIssue__c i :
		[
				SELECT Id
				FROM kern__ApiIssue__c
				WHERE Id NOT IN :trackingIssueIds
		])
		{
			trackingIssueIds.add(i.Id);
		}
		System.debug('31d PASS: Failure rate 100% produced 3 ApiCalls with StatusCode 500');
	}

	// Test 31e: 200 mock with failureRate=0 → 3 calls → all StatusCode 200
	{
		kern.API_MockFactory.forService(echoService)
				.body('{"ok":true}').statusCode(200).withFailureRate(0).register();
		for(Integer i = 0; i < 3; i++)
		{
			kern.UTIL_HttpClient.useHandler(API_EchoSubscriber.class)
					.withParameter('message', 'success-31e-' + i)
					.invoke();
		}
		expectedTotal += 3;

		List<kern__ApiCall__c> newCalls =
		[
				SELECT kern__StatusCode__c
				FROM kern__ApiCall__c
				WHERE Id NOT IN :trackingCallIds
		];
		Integer successCount = 0;
		for(kern__ApiCall__c c : newCalls)
		{
			if(c.kern__StatusCode__c == '200')
			{
				successCount++;
			}
		}
		System.assert(successCount == 3, '31e FAIL: All 3 calls should have StatusCode 200, got ' + successCount);
		for(kern__ApiCall__c c : newCalls)
		{
			trackingCallIds.add(c.Id);
		}
		System.debug('31e PASS: Failure rate 0% produced 3 ApiCalls with StatusCode 200');
	}

	// Test 31f: Delegation 500 → ApiIssue created (LogIssues=true on EchoSubscriber)
	{
		kern.API_MockFactory.forService(echoService)
				.body('{"error":"delegation failure"}').statusCode(500).register();
		kern.UTIL_HttpClient.useHandler(API_EchoSubscriber.class)
				.withParameter('message', 'issue-31f')
				.invoke();
		expectedTotal++;

		List<kern__ApiIssue__c> newIssues =
		[
				SELECT kern__ServiceName__c
				FROM kern__ApiIssue__c
				WHERE Id NOT IN :trackingIssueIds
		];
		System.assert(!newIssues.isEmpty(), '31f FAIL: ApiIssue should be created when LogIssues=true and call fails');
		for(kern__ApiIssue__c i : newIssues)
		{
			trackingIssueIds.add(i.Id);
		}
		for(kern__ApiCall__c c :
		[
				SELECT Id
				FROM kern__ApiCall__c
				WHERE Id NOT IN :trackingCallIds
		])
		{
			trackingCallIds.add(c.Id);
		}
		System.debug('31f PASS: Delegation 500 created ' + newIssues.size() + ' ApiIssue(s) (LogIssues=true)');
	}

	// Test 31g: Delegation 200 → ApiCall Completed (recovery after failure)
	{
		kern.API_MockFactory.forService(echoService)
				.body('{"echo":"recovered"}').statusCode(200).register();
		kern.UTIL_HttpClient.useHandler(API_EchoSubscriber.class)
				.withParameter('message', 'recovery-31g')
				.invoke();
		expectedTotal++;

		List<kern__ApiCall__c> newCalls =
		[
				SELECT kern__Status__c
				FROM kern__ApiCall__c
				WHERE Id NOT IN :trackingCallIds
		];
		System.assert(!newCalls.isEmpty(), '31g FAIL: ApiCall should be created');
		kern__ApiCall__c lastCall = newCalls[newCalls.size() - 1];
		System.assert(
				lastCall.kern__Status__c == 'Completed',
				'31g FAIL: Status should be Completed, got ' + lastCall.kern__Status__c
		);
		for(kern__ApiCall__c c : newCalls)
		{
			trackingCallIds.add(c.Id);
		}
		System.debug('31g PASS: Delegation 200 produced Completed ApiCall after prior failure');
	}

	// Test 31h: Total ApiCall count matches expected
	{
		Integer totalNewCalls =
		[
				SELECT COUNT()
				FROM kern__ApiCall__c
				WHERE Id NOT IN :baselineCallIds
		];
		System.assert(
				totalNewCalls == expectedTotal,
				'31h FAIL: Expected ' + expectedTotal + ' total ApiCalls, got ' + totalNewCalls
		);
		System.debug('31h PASS: Total ApiCall count matches expected (' + expectedTotal + ')');
	}

	System.debug('=== Section 31 COMPLETE: All failure handling tests passed ===');
}
catch(Exception error)
{
	System.debug('Section 31 ERROR: ' + error.getMessage());
	System.debug('Stack trace: ' + error.getStackTraceString());
}
finally
{
	kern.API_MockFactory.clearMocks();

	List<kern__ApiCall__c> testCalls =
	[
			SELECT Id
			FROM kern__ApiCall__c
			WHERE Id NOT IN :baselineCallIds
	];
	if(!testCalls.isEmpty())
	{
		delete testCalls;
	}

	List<kern__ApiIssue__c> testIssues =
	[
			SELECT Id
			FROM kern__ApiIssue__c
			WHERE Id NOT IN :baselineIssueIds
	];
	if(!testIssues.isEmpty())
	{
		delete testIssues;
	}
}
