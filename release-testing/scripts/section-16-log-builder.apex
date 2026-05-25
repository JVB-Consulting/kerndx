// =============================================================================
// Section 16: LOG_Builder — Logging Framework
// =============================================================================
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Prerequisites:
//   - kern managed package installed
//
// Tests direct LOG_Builder usage from subscriber code. Note: LOG_Builder uses
// platform events (LogEntryEvent__e) which are async. Log entries may not be
// immediately queryable in kern__LogEntry__c.
//
// Run:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-16-log-builder.apex
// =============================================================================

try
{
	// Test 16a: LOG_Builder.build() returns a non-null builder
	{
		kern.LOG_Builder.LogEntry entry = kern.LOG_Builder.build();
		System.assert(entry != null, '16a FAIL: build() should return a non-null LogEntry');
		System.debug('16a PASS: LOG_Builder.build() returns LogEntry instance');
	}

	// Test 16b: Error level logging with exception
	{
		Boolean emitted = false;
		try
		{
			throw new IllegalArgumentException('Test exception for 16b');
		}
		catch(Exception error)
		{
			kern.LOG_Builder.build().error(error).emitAt('SubscriberTest.section16b');
			emitted = true;
		}

		System.assert(emitted, '16b FAIL: Should have emitted error log');
		System.debug('16b PASS: Error level logging with Exception emitted successfully');
	}

	// Test 16c: Info level logging with message
	{
		kern.LOG_Builder.build().info('Test info message from subscriber').emitAt('SubscriberTest.section16c');
		System.debug('16c PASS: Info level logging emitted successfully');
	}

	// Test 16d: Warning level logging
	{
		kern.LOG_Builder.build().warn('Test warning from subscriber').emitAt('SubscriberTest.section16d');
		System.debug('16d PASS: Warning level logging emitted successfully');
	}

	// Test 16e: Debug level logging
	{
		kern.LOG_Builder.build().debug('Test debug from subscriber').emitAt('SubscriberTest.section16e');
		System.debug('16e PASS: Debug level logging emitted successfully');
	}

	// Test 16f: Logging with record association
	{
		kern.TRG_Base.bypass(Schema.Account.SObjectType);
		Account testAccount = new Account(Name = 'LOG Test 16f', Industry = 'Technology');
		insert testAccount;

		kern.LOG_Builder.build()
				.info('Processing account: ' + testAccount.Name)
				.forRecord(testAccount.Id)
				.emitAt('SubscriberTest.section16f');

		delete testAccount;
		kern.TRG_Base.clearAllBypasses();

		System.debug('16f PASS: Logging with record association (forRecord) emitted');
	}

	// Test 16g: Logging with context data
	{
		kern.LOG_Builder.build()
				.info('Payment processed')
				.withContext('amount', 150.00)
				.withContext('currency', 'USD')
				.withSummary('Payment summary')
				.emitAt('SubscriberTest.section16g');

		System.debug('16g PASS: Logging with context data and summary emitted');
	}

	// Test 16h: Correlation ID lifecycle
	{
		String correlationId = kern.LOG_Builder.startCorrelation();
		System.assert(correlationId != null, '16h FAIL: startCorrelation() should return a non-null ID');
		System.assert(correlationId.length() > 0, '16h FAIL: Correlation ID should not be empty');

		kern.LOG_Builder.build().info('Correlated log 1').emitAt('SubscriberTest.section16h');
		kern.LOG_Builder.build().info('Correlated log 2').emitAt('SubscriberTest.section16h');

		System.debug('16h PASS: Correlation ID generated: ' + correlationId);
	}

	// Test 16i: Query log entries (async — may have entries from previous sections)
	{
		List<kern__LogEntry__c> recentLogs =
		[
				SELECT
						kern__Message__c,
						kern__ClassMethod__c,
						kern__LogLevel__c,
						kern__RecordId__c
				FROM kern__LogEntry__c
				WHERE kern__ClassMethod__c LIKE '%SubscriberTest%'
				ORDER BY CreatedDate DESC
				LIMIT 20
		];

		System.debug('16i INFO: Found ' + recentLogs.size() + ' subscriber log entries');
		for(kern__LogEntry__c log : recentLogs)
		{
			System.debug('16i  - [' + log.kern__LogLevel__c + '] ' + log.kern__ClassMethod__c + ': ' + log.kern__Message__c);
		}

		// Log entries are async via platform events — may not be available immediately
		// A count > 0 is a bonus, but not failing on 0 since async processing may lag
		if(recentLogs.isEmpty())
		{
			System.debug('16i INFO: No log entries found yet (async platform events may not have processed)');
		}
		System.debug('16i PASS: Log entry query executed successfully');
	}

	// Test 16j: Bulk-100 boundary — emit 100 log entries (capped at 100, not 200, due to PublishImmediate governor of 150 per tx)
	// Verifies LOG_Builder.emit() does not throw at bulk volume within the governor boundary.
	{
		Integer emitCount = 0;
		for(Integer i = 0; i < 100; i++)
		{
			kern.LOG_Builder.build()
					.info('Bulk log entry ' + i)
					.at('SubscriberTest.section16j')
					.emit();
			emitCount++;
		}
		System.assertEquals(100, emitCount, '16j FAIL: Should have emitted 100 log entries without exception, emitted: ' + emitCount);
		System.debug('16j PASS: LOG_Builder emitted 100 entries at bulk boundary without governor error (PublishImmediate limit is 150 per tx)');
	}

	System.debug('=== Section 16 COMPLETE: All LOG_Builder tests passed ===');
}
catch(Exception error)
{
	System.debug('Section 16 ERROR: ' + error.getMessage());
	System.debug('Stack trace: ' + error.getStackTraceString());
}
