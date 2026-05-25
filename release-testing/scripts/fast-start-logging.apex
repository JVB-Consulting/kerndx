// Fast Start - Logging: Tier 1 anonymous Apex verification script
// Run from: Developer Console > Debug > Open Execute Anonymous Window
//            OR: sf apex run --file release-testing/scripts/fast-start-logging.apex -o YourOrgAlias
//
// Expected: one LogEntry__c row visible in App Launcher > Kern > Log Entries within 2-3 seconds.
// No @TestVisible private calls are made — this script uses only global API surface.

kern.LOG_Builder.LogScope scope = kern.LOG_Builder.scope();

try
{
	kern.LOG_Builder.build()
		.info('Hello from Logging Fast Start')
		.withSummary('Tier 1 verification')
		.withContext('source', 'fast-start-logging.apex')
		.emitAt('FastStart.Logging.tier1');

	kern.LOG_Builder.build()
		.debug('Debug-level entry — filtered in production by default')
		.emitAt('FastStart.Logging.tier1');

	kern.LOG_Builder.build()
		.warn('Warn-level entry — use for business-rule violations')
		.emitAt('FastStart.Logging.tier1');
}
finally
{
	scope.close();
}

System.debug('Done. Open App Launcher > Kern > Log Entries to see the three entries.');
System.debug('All three share the same CorrelationId — filter by it to group them together.');
