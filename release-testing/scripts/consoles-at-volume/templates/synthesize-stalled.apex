// Consoles at volume: back-dated Stalled rows in the seed's shape (seed-chain-scenarios.apex, batch 1), used only
// when the probe found no in-engine cause of a genuine stall; the manifest marks them synthesized and the report
// classes them as a screen fixture, never as engine evidence. Needs audit-field back-dating (RUNBOOK Phase 1.4).
// Tokens: __APEX_NAMESPACE__ __FIELD_NAMESPACE__ __COUNT__ __RUN_TOKEN__ __ACTION_ID__
__APEX_NAMESPACE__LOG_Builder.setCorrelationId('__ACTION_ID__');
String actionId = '__ACTION_ID__';
List<__FIELD_NAMESPACE__AsyncChainExecution__c> rows = new List<__FIELD_NAMESPACE__AsyncChainExecution__c>();
Datetime now = Datetime.now();
List<String> steps = new List<String> {'Archive Chunk 4', 'Archive Chunk 9', 'Rebuild Price Book', 'Reindex Products'};
for(Integer synthesized = 0; synthesized < __COUNT__; synthesized++)
{
	Integer silentMinutes = 190 + synthesized * 70;
	List<Map<String, Object>> stepLog = new List<Map<String, Object>>
	{
			new Map<String, Object> {'className' => 'ArchiveValidate', 'stepName' => 'Validate Payload', 'success' => true, 'durationMs' => 312},
			new Map<String, Object> {'className' => 'ArchiveEnrich', 'stepName' => 'Enrich From Source', 'success' => true, 'durationMs' => 1187},
			new Map<String, Object> {'className' => 'ArchiveUpsert', 'stepName' => 'Upsert Records', 'success' => true, 'durationMs' => 904},
			new Map<String, Object> {'className' => 'ArchiveFinalise', 'stepName' => steps[Math.mod(synthesized, steps.size())]}
	};
	__FIELD_NAMESPACE__AsyncChainExecution__c row = new __FIELD_NAMESPACE__AsyncChainExecution__c();
	row.put('__FIELD_NAMESPACE__ChainName__c', 'Volume_StalledArchive');
	row.put('__FIELD_NAMESPACE__Status__c', 'Stalled');
	row.put('__FIELD_NAMESPACE__FailureCategory__c', 'Stalled');
	row.put('__FIELD_NAMESPACE__CorrelationId__c', SubscriberChainSteps.volumeRunId('__RUN_TOKEN__', SubscriberChainSteps.KIND_STALLED_ROW, 0, 0, synthesized));
	row.put('__FIELD_NAMESPACE__RootCorrelationId__c', actionId);
	row.put('__FIELD_NAMESPACE__LaunchCorrelationId__c', actionId);
	row.put('__FIELD_NAMESPACE__CurrentStepName__c', steps[Math.mod(synthesized, steps.size())]);
	row.put('__FIELD_NAMESPACE__TotalSteps__c', 4);
	row.put('__FIELD_NAMESPACE__CompletedSteps__c', 3);
	row.put('__FIELD_NAMESPACE__StartedAt__c', now.addMinutes(-(silentMinutes + 1)));
	row.put('__FIELD_NAMESPACE__StepLog__c', JSON.serialize(stepLog));
	row.put('CreatedDate', now.addMinutes(-(silentMinutes + 1)));
	row.put('LastModifiedDate', now.addMinutes(-silentMinutes));
	rows.add(row);
}
insert rows;
List<String> executionIds = new List<String>();
for(__FIELD_NAMESPACE__AsyncChainExecution__c row : rows)
{
	executionIds.add(row.Id);
}
System.debug('VOLUME_LAUNCH stage=stalled action=' + actionId + ' ordinal=0 ids=' + String.join(executionIds, ',') + ' launched=' + executionIds.size()
		+ ' dml=' + Limits.getDmlStatements() + '/' + Limits.getLimitDmlStatements() + ' enqueued=0/0');
