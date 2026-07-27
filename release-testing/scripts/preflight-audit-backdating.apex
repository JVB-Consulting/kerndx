// Preflight: verifies audit-field back-dating is enabled before Phase 2 runs. Section 79's
// stale-probe seed writes a back-dated CreatedDate with a static assignment, which fails
// COMPILE in an org missing the RUNBOOK Phase 1.4 enablement (two-step audit-fields deploys +
// the KernE2EAuditFieldAccess permission set) — a confusing failure 14 minutes into the run.
// This probe uses a dynamic put() so the same gap surfaces as a clear runtime verdict up front,
// and it also catches the silent-ignore mode where the insert succeeds but the platform
// discards the back-dated value.
Boolean enabled = false;
String detail = '';
kern__AsyncChainExecution__c probe = new kern__AsyncChainExecution__c(
		kern__ChainName__c = 'Audit Backdate Preflight',
		kern__Status__c = 'Completed',
		kern__CorrelationId__c = EncodingUtil.convertToHex(Crypto.generateAesKey(128)),
		kern__TotalSteps__c = 1,
		kern__CompletedSteps__c = 1,
		kern__StartedAt__c = System.now().addMinutes(-45)
);
try
{
	probe.put('CreatedDate', System.now().addMinutes(-45));
	insert probe;
	kern__AsyncChainExecution__c fetched = [SELECT CreatedDate FROM kern__AsyncChainExecution__c WHERE Id = :probe.Id];
	enabled = fetched.CreatedDate < System.now().addMinutes(-30);
	if(!enabled)
	{
		detail = ' (insert succeeded but the platform silently discarded the back-dated value)';
	}
	delete probe;
}
catch(Exception failure)
{
	detail = ' (' + failure.getMessage() + ')';
}
if(enabled)
{
	System.debug('preflight PASS: audit-field back-dating enabled');
}
else
{
	System.debug('preflight FAIL: audit-field back-dating NOT enabled' + detail + ' — apply the RUNBOOK Phase 1.4 audit-fields recipe before running Phase 2');
}
