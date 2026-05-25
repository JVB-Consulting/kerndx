// =============================================================================
// Benchmark: Flow-as-Trigger-Action Single-Mode Performance (the flow-as-trigger-action benchmark baseline)
// =============================================================================
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Package: kern (managed)
// Prerequisites:
//   - Section 41 prerequisites
//
// Run with:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/benchmark-flow-action.apex
//
// Captures CPU, SOQL, DML, wall-clock per N for the canonical single-mode-only flow-action
// scenario. Results compared against release-testing/results/the flow-as-trigger-action work-benchmark-baseline.json.
// Regression alarms when wall-clock or any governor count grows >20% on the canonical
// 100-record Account scenario. (Bulk-mode dimension permanently removed — platform-blocked
// at API 66.0 per Phase 0 Spike 2.)
// =============================================================================

kern.TRG_Base.clearAllBypasses();
kern.TRG_Base.clearAllActionBypasses();
kern.UTIL_ValidationRule.bypassObject('Account');

System.debug('========================================');
System.debug('Single-Mode Flow-Action Benchmark');
System.debug('========================================');

List<Integer> recordCounts = new List<Integer>{1, 10, 100};

try
{
	for(Integer recordCount : recordCounts)
	{
		Long startTime = System.currentTimeMillis();
		Integer startCpu = Limits.getCpuTime();
		Integer startSoql = Limits.getQueries();
		Integer startDml = Limits.getDmlStatements();

		List<Account> accounts = new List<Account>();
		for(Integer index = 0; index < recordCount; index++)
		{
			accounts.add(new Account(
					Name = 'Benchmark ' + recordCount + ' index ' + index,
					Industry = 'Technology',
					Phone = '555-0' + String.valueOf(index).leftPad(3, '0')
			));
		}
		insert accounts;

		Long elapsedMs = System.currentTimeMillis() - startTime;
		Integer cpuMs = Limits.getCpuTime() - startCpu;
		Integer soqlCount = Limits.getQueries() - startSoql;
		Integer dmlCount = Limits.getDmlStatements() - startDml;

		System.debug(JSON.serialize(new Map<String, Object>
		{
				'metric' => 'flow-action-single-mode',
				'recordCount' => recordCount,
				'wallClockMs' => elapsedMs,
				'cpuMs' => cpuMs,
				'soqlCount' => soqlCount,
				'dmlCount' => dmlCount
		}));

		delete accounts;
	}

	System.debug('========================================');
	System.debug('Benchmark complete — capture USER_DEBUG output to release-testing/results/the flow-as-trigger-action work-benchmark-{date}.json');
	System.debug('========================================');
}
finally
{
	kern.TRG_Base.clearAllBypasses();
	kern.TRG_Base.clearAllActionBypasses();
	kern.UTIL_ValidationRule.clearAllBypasses();
}
