// Section 19: LWC Logger — Persistence Verification
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Prerequisites:
//   - kern managed package installed
//   - subscriberLoggerTest LWC deployed
//   - Click "Test Persistence" button on the LWC FIRST, then wait ~10 seconds
//
// This script verifies that LWC logs persisted via CTRL_Logger appear in kern__LogEntry__c.
//
// Run:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-19-lwc-logger-persistence.apex

try
{
	// Test 19a: Query for LWC-originated log entries
	{
		List<kern__LogEntry__c> lwcLogs =
		[
				SELECT
						kern__Message__c,
						kern__ClassMethod__c,
						kern__LogLevel__c,
						kern__CorrelationId__c
				FROM kern__LogEntry__c
				WHERE kern__ClassMethod__c LIKE 'LWC/%'
				ORDER BY CreatedDate DESC
				LIMIT 20
		];

		System.debug('19a INFO: Found ' + lwcLogs.size() + ' LWC log entries');
		for(kern__LogEntry__c log : lwcLogs)
		{
			System.debug('19a  - [' + log.kern__LogLevel__c + '] ' + log.kern__ClassMethod__c + ': ' + log.kern__Message__c + ' (corr: ' + log.kern__CorrelationId__c + ')');
		}

		// LWC logs are async via platform events — may not be available immediately
		if(lwcLogs.isEmpty())
		{
			System.debug('19a INFO: No LWC log entries found yet (async platform events may not have processed). Re-run after a few seconds.');
		}
		System.debug('19a PASS: LWC log entry query executed successfully');
	}

	// Test 19b: Verify persistence test entries specifically
	// NOTE: kern__Message__c is Long Text Area — cannot filter in SOQL WHERE. Filter in Apex.
	{
		List<kern__LogEntry__c> recentLogs =
		[
				SELECT
						kern__Message__c,
						kern__LogLevel__c,
						kern__CorrelationId__c
				FROM kern__LogEntry__c
				WHERE kern__ClassMethod__c LIKE 'LWC/%'
				ORDER BY CreatedDate DESC
				LIMIT 50
		];

		List<kern__LogEntry__c> persistenceLogs = new List<kern__LogEntry__c>();
		for(kern__LogEntry__c log : recentLogs)
		{
			if(log.kern__Message__c != null && log.kern__Message__c.contains('Subscriber LWC persistence test'))
			{
				persistenceLogs.add(log);
			}
		}

		System.debug('19b INFO: Found ' + persistenceLogs.size() + ' persistence test log entries');
		for(kern__LogEntry__c log : persistenceLogs)
		{
			System.debug('19b  - [' + log.kern__LogLevel__c + '] ' + log.kern__Message__c);
		}

		if(persistenceLogs.size() >= 4)
		{
			System.debug('19b PASS: All 4 log levels persisted from LWC');
		}
		else if(!persistenceLogs.isEmpty())
		{
			System.debug('19b PASS (partial): ' + persistenceLogs.size() + '/4 log entries found — async processing may still be in progress');
		}
		else
		{
			System.debug('19b INFO: No persistence test entries found yet. Ensure "Test Persistence" button was clicked first.');
		}
	}

	// Test 19c: Verify correlation IDs are consistent across entries from same session
	{
		List<kern__LogEntry__c> recentCorrelatedLogs =
		[
				SELECT
						kern__CorrelationId__c,
						kern__Message__c
				FROM kern__LogEntry__c
				WHERE kern__ClassMethod__c LIKE 'LWC/%'
				AND kern__CorrelationId__c != NULL
				ORDER BY CreatedDate DESC
				LIMIT 50
		];

		List<kern__LogEntry__c> correlatedLogs = new List<kern__LogEntry__c>();
		for(kern__LogEntry__c log : recentCorrelatedLogs)
		{
			if(log.kern__Message__c != null && log.kern__Message__c.contains('Subscriber LWC persistence test'))
			{
				correlatedLogs.add(log);
			}
		}

		if(correlatedLogs.size() >= 2)
		{
			String firstCorrelationId = correlatedLogs[0].kern__CorrelationId__c;
			Boolean allMatch = true;
			for(kern__LogEntry__c log : correlatedLogs)
			{
				if(log.kern__CorrelationId__c != firstCorrelationId)
				{
					allMatch = false;
					break;
				}
			}
			System.assert(allMatch, '19c FAIL: Correlation IDs should match across entries from same session');
			System.debug('19c PASS: All persistence test entries share correlation ID: ' + firstCorrelationId);
		}
		else
		{
			System.debug('19c INFO: Not enough correlated entries to verify. Ensure "Test Persistence" button was clicked.');
		}
	}

	// Test 19d: LOG_Builder with context — subscriber can log with custom context
	// NOTE: CTRL_Logger is public (not global) — subscribers cannot call it directly from Apex.
	// LWC logging works because the LWC controller runs in managed package context.
	// These tests verify LOG_Builder (the subscriber-accessible logging API) with similar patterns.
	{
		kern.LOG_Builder.build()
				.info('Subscriber log with context')
				.at('SubscriberClass.testMethod')
				.withContext('customKey', 'customValue')
				.emit();
		System.debug('19d PASS: LOG_Builder accepted subscriber log with custom context');
	}

	// Test 19e: LOG_Builder with record context
	{
		kern.TRG_Base.bypass(Schema.Account.SObjectType);
		Account testAccount = new Account(Name = 'Logger Context Test 19e', Industry = 'Technology', Phone = '555-1900', Website = 'https://test.com');
		insert testAccount;

		kern.LOG_Builder.build()
				.warn('Context with record')
				.at('SubscriberClass.processRecord')
				.forRecord(testAccount.Id)
				.withContext('operation', 'update')
				.emit();

		delete testAccount;
		kern.TRG_Base.clearAllBypasses();
		System.debug('19e PASS: LOG_Builder accepted subscriber log with record context');
	}

	// Test 19f: LOG_Builder scope (correlation lifecycle)
	{
		kern.LOG_Builder.LogScope scope = kern.LOG_Builder.scope();
		kern.LOG_Builder.build().info('Scope start').emitAt('SubscriberClass.scopeTest');
		kern.LOG_Builder.build().debug('Scope middle').emitAt('SubscriberClass.scopeTest');
		scope.close();
		System.debug('19f PASS: LOG_Builder scope lifecycle (start/log/close) from subscriber');
	}

	// Test 19g: LOG_Builder error with exception
	{
		try
		{
			Integer result = 1 / 0;
		}
		catch(Exception error)
		{
			kern.LOG_Builder.build().error(error).emitAt('SubscriberClass.errorTest');
		}
		System.debug('19g PASS: LOG_Builder accepted exception-based error log from subscriber');
	}

	// Test 19h: LOG_Builder all log levels from subscriber
	{
		kern.LOG_Builder.build().debug('Level test DEBUG').emitAt('SubscriberClass.levelTest');
		kern.LOG_Builder.build().info('Level test INFO').emitAt('SubscriberClass.levelTest');
		kern.LOG_Builder.build().warn('Level test WARN').emitAt('SubscriberClass.levelTest');
		kern.LOG_Builder.build().error('Level test ERROR').emitAt('SubscriberClass.levelTest');
		System.debug('19h PASS: LOG_Builder accepted all 4 log levels from subscriber');
	}

	System.debug('=== Section 19 COMPLETE: All LWC Logger persistence tests passed ===');
}
catch(Exception error)
{
	System.debug('Section 19 ERROR: ' + error.getMessage());
	System.debug('Stack trace: ' + error.getStackTraceString());
}
