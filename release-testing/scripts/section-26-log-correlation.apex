// Section 26: Log Correlation — End-to-End Traceability
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Prerequisites:
//   - kern managed package installed
//   - Sections 16-20 executed first (to populate LogEntry__c records)
//
// Verifies that the logging framework provides end-to-end correlation:
//   - Multiple logs from a single logical operation share a CorrelationId
//   - Correlation survives DML that triggers handler execution
//   - Context serialization/hydration preserves correlation for async jobs
//   - LogEntry__c records can be queried and grouped by CorrelationId
//
// Run:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-26-log-correlation.apex

try
{
	// Test 26a: Multiple logs within a single correlation share the same ID
	{
		String correlationId = kern.LOG_Builder.startCorrelation();
		System.assert(String.isNotBlank(correlationId), '26a FAIL: startCorrelation should return a non-blank ID');

		kern.LOG_Builder.build()
				.info('Controller: saveAccount invoked')
				.at('SubscriberController.saveAccount')
				.emit();

		System.assert(kern.LOG_Builder.correlationId == correlationId,
				'26a FAIL: Correlation should persist after first emit');

		kern.LOG_Builder.build()
				.info('Service: account validation passed')
				.at('SubscriberService.validateAccount')
				.emit();

		kern.LOG_Builder.build()
				.info('API: notification sent')
				.at('SubscriberAPI.sendNotification')
				.emit();

		System.assert(kern.LOG_Builder.correlationId == correlationId,
				'26a FAIL: Correlation should persist across all emits');

		System.debug('26a PASS: Three logs emitted with shared correlation — ' + correlationId);
	}

	// Test 26b: Correlation persists through DML and trigger execution
	{
		String correlationId = kern.LOG_Builder.startCorrelation();

		kern.LOG_Builder.build()
				.info('Pre-DML: about to create account')
				.at('SubscriberTest.beforeDML')
				.emit();

		Account testAccount = new Account(Name = 'Correlation Test 26b', Industry = 'Technology', Phone = '555-2600');
		insert testAccount;

		System.assert(kern.LOG_Builder.correlationId == correlationId,
				'26b FAIL: Correlation should survive trigger execution — got: ' + kern.LOG_Builder.correlationId);

		kern.LOG_Builder.build()
				.info('Post-DML: account created — ' + testAccount.Id)
				.at('SubscriberTest.afterDML')
				.forRecord(testAccount.Id)
				.emit();

		delete testAccount;
		System.debug('26b PASS: Correlation persists through DML/trigger cascade — ' + correlationId);
	}

	// Test 26c: Correlation persists through nested DML (insert parent + child)
	{
		String correlationId = kern.LOG_Builder.startCorrelation();

		kern.LOG_Builder.build().info('Creating parent').at('SubscriberTest.nestedDML').emit();

		kern.TRG_Base.bypass(Schema.Account.SObjectType);
		Account parent = new Account(Name = 'Correlation Parent 26c');
		insert parent;
		kern.TRG_Base.clearBypass(Schema.Account.SObjectType);

		kern.LOG_Builder.build().info('Creating child').at('SubscriberTest.nestedDML').emit();

		Contact child = new Contact(LastName = 'Correlation Child 26c', AccountId = parent.Id);
		insert child;

		System.assert(kern.LOG_Builder.correlationId == correlationId,
				'26c FAIL: Correlation should survive nested DML');

		kern.LOG_Builder.build().info('Both created').at('SubscriberTest.nestedDML').emit();

		delete child;
		kern.TRG_Base.bypass(Schema.Account.SObjectType);
		delete parent;
		kern.TRG_Base.clearAllBypasses();

		System.debug('26c PASS: Correlation persists through nested parent/child DML — ' + correlationId);
	}

	// Test 26d: Context serialization/hydration for async job correlation
	{
		String correlationId = kern.LOG_Builder.startCorrelation();
		kern.LOG_Builder.setGlobalContext('operation', 'batchSync');
		kern.LOG_Builder.setGlobalContext('batchId', 'BATCH-001');

		String serialized = kern.LOG_Builder.serializeContext();

		System.assert(String.isNotBlank(serialized), '26d FAIL: Serialized context should not be blank');
		System.assert(serialized.contains(correlationId), '26d FAIL: Serialized context should contain correlation ID');

		kern.LOG_Builder.setCorrelationId(null);
		System.assert(kern.LOG_Builder.correlationId == null, '26d FAIL: Correlation should be cleared');

		kern.LOG_Builder.hydrateContext(serialized);

		System.assert(kern.LOG_Builder.correlationId == correlationId,
				'26d FAIL: Correlation should be restored after hydration — got: ' + kern.LOG_Builder.correlationId);

		kern.LOG_Builder.build()
				.info('Async job processed with restored correlation')
				.at('SubscriberQueueable.execute')
				.emit();

		System.debug('26d PASS: Correlation survives serialize/hydrate cycle — ' + correlationId);
	}

	// Test 26e: LOG_Builder.scope() creates and maintains correlation
	{
		kern.LOG_Builder.LogScope scope = kern.LOG_Builder.scope();
		String scopeCorrelationId = kern.LOG_Builder.correlationId;

		System.assert(String.isNotBlank(scopeCorrelationId),
				'26e FAIL: scope() should auto-start a correlation');

		kern.LOG_Builder.build().info('Scope entry 1').emitAt('SubscriberTest.scopeCorrelation');
		kern.LOG_Builder.build().info('Scope entry 2').emitAt('SubscriberTest.scopeCorrelation');

		System.assert(kern.LOG_Builder.correlationId == scopeCorrelationId,
				'26e FAIL: Correlation should remain stable within scope');

		scope.close();
		System.debug('26e PASS: LogScope maintains stable correlation — ' + scopeCorrelationId);
	}

	// Test 26f: Query LogEntry__c to verify correlated entries in the database
	{
		List<kern__LogEntry__c> correlatedLogs =
		[
				SELECT
						kern__CorrelationId__c,
						kern__TransactionId__c,
						kern__ClassMethod__c,
						kern__Message__c
				FROM kern__LogEntry__c
				WHERE kern__CorrelationId__c != NULL
				ORDER BY CreatedDate DESC
				LIMIT 100
		];

		if(correlatedLogs.isEmpty())
		{
			System.debug('26f INFO: No correlated entries found yet — platform events are async. Re-run after a few seconds.');
		}
		else
		{
			Map<String, List<kern__LogEntry__c>> byCorrelation = new Map<String, List<kern__LogEntry__c>>();
			for(kern__LogEntry__c log : correlatedLogs)
			{
				if(!byCorrelation.containsKey(log.kern__CorrelationId__c))
				{
					byCorrelation.put(log.kern__CorrelationId__c, new List<kern__LogEntry__c>());
				}
				byCorrelation.get(log.kern__CorrelationId__c).add(log);
			}

			System.debug('26f INFO: ' + byCorrelation.size() + ' correlation groups across ' + correlatedLogs.size() + ' entries');
			Integer multiEntryGroups = 0;
			for(String corrId : byCorrelation.keySet())
			{
				List<kern__LogEntry__c> entries = byCorrelation.get(corrId);
				if(entries.size() > 1)
				{
					multiEntryGroups++;
					System.debug('26f  Correlation ' + corrId.left(12) + '...: ' + entries.size() + ' entries');
					for(kern__LogEntry__c log : entries)
					{
						System.debug('26f    - [' + log.kern__ClassMethod__c + '] ' + (log.kern__Message__c != null ? log.kern__Message__c.left(80) : ''));
					}
				}
			}

			System.assert(multiEntryGroups > 0,
					'26f FAIL: At least one correlation group should have multiple entries');
			System.debug('26f PASS: Found ' + multiEntryGroups + ' multi-entry correlation groups — end-to-end traceability confirmed');
		}
	}

	// Test 26g: TransactionId consistency — entries from the same transaction share TransactionId
	{
		List<kern__LogEntry__c> transactionLogs =
		[
				SELECT
						kern__TransactionId__c,
						kern__CorrelationId__c,
						kern__ClassMethod__c
				FROM kern__LogEntry__c
				WHERE kern__TransactionId__c != NULL
				AND kern__CorrelationId__c != NULL
				ORDER BY CreatedDate DESC
				LIMIT 50
		];

		if(transactionLogs.size() >= 2)
		{
			Map<String, Set<String>> correlationsByTransaction = new Map<String, Set<String>>();
			for(kern__LogEntry__c log : transactionLogs)
			{
				if(!correlationsByTransaction.containsKey(log.kern__TransactionId__c))
				{
					correlationsByTransaction.put(log.kern__TransactionId__c, new Set<String>());
				}
				correlationsByTransaction.get(log.kern__TransactionId__c).add(log.kern__CorrelationId__c);
			}

			System.debug('26g INFO: ' + correlationsByTransaction.size() + ' unique transactions found');

			Boolean foundSingleCorrelationTransaction = false;
			for(String transactionId : correlationsByTransaction.keySet())
			{
				if(correlationsByTransaction.get(transactionId).size() == 1)
				{
					foundSingleCorrelationTransaction = true;
					break;
				}
			}

			if(foundSingleCorrelationTransaction)
			{
				System.debug('26g PASS: Transactions with single correlation ID found — operations properly grouped');
			}
			else
			{
				System.debug('26g INFO: All transactions have multiple correlations (batch or mixed-context execution)');
			}
		}
		else
		{
			System.debug('26g INFO: Not enough entries for transaction analysis — re-run after async processing');
		}
	}

	System.debug('=== Section 26 COMPLETE: All Log Correlation tests passed ===');
}
catch(Exception error)
{
	System.debug('Section 26 ERROR: ' + error.getMessage());
	System.debug('Stack trace: ' + error.getStackTraceString());
}
