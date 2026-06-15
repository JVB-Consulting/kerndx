// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Subscriber service demonstrating KernDX structured logging patterns.
 *
 * Covers four patterns from Fast Start - Logging:
 * - Scoped correlation with LOG_Builder.scope()
 * - Per-record debug logging with .forRecord()
 * - Structured context values with .withContext()
 * - Single-shot error alerts with .error(Exception) and .error(String)
 *
 * @see FastStart_Logging_DEMO_TEST
 *
 * @author your.name@company.com
 *
 * @group Fast Start Demos
 *
 * @date May 2026
 */
public with sharing class FastStart_Logging_DEMO
{
	/**
	 * @description Context key for the record count value.
	 */
	@TestVisible private static final String CONTEXT_COUNT = 'count';

	/**
	 * @description Class name constant used in all log context strings.
	 */
	@TestVisible private static final String CLASS_NAME = 'FastStart_Logging_DEMO';

	/**
	 * @description Processes a list of Account records with correlated, structured logging.
	 *
	 * Opens a LogScope so every emit inside the try/finally shares one CorrelationId.
	 * Logs INFO at start and end, DEBUG per record, ERROR for any exception (continues processing).
	 *
	 * @param accounts The Account records to process.
	 */
	public void processOrders(List<Account> accounts)
	{
		kern.LOG_Builder.LogScope scope = kern.LOG_Builder.scope();

		try
		{
			kern.LOG_Builder.build()
					.info('Order processing started')
					.withSummary('Processing accounts')
					.withContext(CONTEXT_COUNT, accounts.size())
					.emitAt(CLASS_NAME + '.processOrders');

			for(Account account : accounts)
			{
				kern.LOG_Builder.build()
						.debug('Processing account')
						.forRecord(Account.Id)
						.emitAt(CLASS_NAME + '.processOrders');
			}

			kern.LOG_Builder.build()
					.info('Order processing completed')
					.withSummary('All accounts processed')
					.withContext(CONTEXT_COUNT, accounts.size())
					.emitAt(CLASS_NAME + '.processOrders');
		}
		finally
		{
			scope.close();
		}
	}

	/**
	 * @description Emits a single ERROR-level alert for a critical condition.
	 *
	 * Use this pattern when you need a one-shot persistent error record without
	 * wrapping code in a try/catch — for example, logging a configuration problem
	 * detected at startup.
	 *
	 * @param message The alert message to persist.
	 */
	public void criticalAlert(String message)
	{
		kern.LOG_Builder.build()
				.error(message)
				.emitAt(CLASS_NAME + '.criticalAlert');
	}
}
