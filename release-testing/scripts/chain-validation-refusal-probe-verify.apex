// Chain save refused by a subscriber validation rule: verification. See RUNBOOK.md,
// "Chain save refused by a subscriber validation rule".
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Prerequisites: release-testing/scripts/chain-validation-refusal-probe.apex ran, and its chains finished (about 60 seconds).
//
// Prints one PASS, WAIT or FAIL line for each chain. Only the newest run of each chain counts.
// SubscriberValidationRefusalProbe: PASS means the run is Failed with the StepException category, 1 completed step
// and an end time; its error message starts with the Finalizer's crash words, carries the platform's
// FIELD_CUSTOM_VALIDATION_EXCEPTION and the rule's own message; and an ERROR Log Entry for the run carries the same
// crash words. A probe run that is still Running with an ERROR log that starts "Chain run transition refused by the
// backstop" is a FAIL: the engine took the rule's message for its own guard's refusal.
// SubscriberValidationRefusalControl: PASS means the run is Completed with 2 completed steps.
//
// Run:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/chain-validation-refusal-probe-verify.apex > tmp/chain-validation-refusal-verify.log 2>&1
//   grep USER_DEBUG tmp/chain-validation-refusal-verify.log

String probeChain = 'SubscriberValidationRefusalProbe';
String controlChain = 'SubscriberValidationRefusalControl';
String crashWords = 'Queueable crashed (unhandled exception): ';
String platformCode = 'FIELD_CUSTOM_VALIDATION_EXCEPTION';
String ruleMessage = 'Release testing refuses this chain run moving to Completed.';
String engineRefusalWords = 'Chain run transition refused by the backstop';

Map<String, kern__AsyncChainExecution__c> newestRunByChain = new Map<String, kern__AsyncChainExecution__c>();
for(kern__AsyncChainExecution__c run :
[
		SELECT kern__ChainName__c,
				kern__Status__c,
				kern__FailureCategory__c,
				kern__CompletedSteps__c,
				kern__CompletedAt__c,
				kern__ErrorMessage__c,
				CreatedDate
		FROM kern__AsyncChainExecution__c
		WHERE kern__ChainName__c IN (:probeChain, :controlChain)
		ORDER BY CreatedDate DESC
])
{
	if(!newestRunByChain.containsKey(run.kern__ChainName__c))
	{
		newestRunByChain.put(run.kern__ChainName__c, run);
	}
}

kern__AsyncChainExecution__c probe = newestRunByChain.get(probeChain);
if(probe == null)
{
	System.debug('chain-validation-refusal-verify FAIL: ' + probeChain + ': no run found');
}
else if(probe.kern__Status__c == 'Running')
{
	Integer refusalLogs = 0;
	for(kern__LogEntry__c entry :
	[
			SELECT kern__Message__c
			FROM kern__LogEntry__c
			WHERE kern__RecordId__c = :String.valueOf(probe.Id) AND kern__LogLevel__c = 'ERROR'
	])
	{
		if((entry.kern__Message__c ?? '').startsWith(engineRefusalWords))
		{
			refusalLogs++;
		}
	}
	if(refusalLogs > 0)
	{
		System.debug('chain-validation-refusal-verify FAIL: ' + probeChain + ': still Running with ' + probe.kern__CompletedSteps__c
				+ ' completed step(s) and ' + refusalLogs + ' ERROR log(s) that start "' + engineRefusalWords
				+ '": the engine took the subscriber rule\'s message for its own guard\'s refusal');
	}
	else
	{
		System.debug('chain-validation-refusal-verify WAIT: ' + probeChain + ': still Running with ' + probe.kern__CompletedSteps__c
				+ ' completed step(s), wait and run again');
	}
}
else
{
	String errorMessage = probe.kern__ErrorMessage__c ?? '';
	Integer crashLogs = 0;
	for(kern__LogEntry__c entry :
	[
			SELECT kern__Message__c
			FROM kern__LogEntry__c
			WHERE kern__RecordId__c = :String.valueOf(probe.Id) AND kern__LogLevel__c = 'ERROR'
	])
	{
		if((entry.kern__Message__c ?? '').startsWith(crashWords))
		{
			crashLogs++;
		}
	}
	Boolean statusRight = probe.kern__Status__c == 'Failed' && probe.kern__FailureCategory__c == 'StepException'
			&& probe.kern__CompletedSteps__c == 1 && probe.kern__CompletedAt__c != null;
	Boolean messageRight = errorMessage.startsWith(crashWords) && errorMessage.contains(platformCode)
			&& errorMessage.contains(ruleMessage);
	String verdict = statusRight && messageRight && crashLogs > 0 ? 'PASS' : 'FAIL';
	System.debug('chain-validation-refusal-verify ' + verdict + ': ' + probeChain + ': ' + probe.kern__Status__c + ', category '
			+ probe.kern__FailureCategory__c + ', ' + probe.kern__CompletedSteps__c + ' completed step(s), end time '
			+ probe.kern__CompletedAt__c + ', crash ERROR logs ' + crashLogs + ', error ' + errorMessage);
}

kern__AsyncChainExecution__c control = newestRunByChain.get(controlChain);
if(control == null)
{
	System.debug('chain-validation-refusal-verify FAIL: ' + controlChain + ': no run found');
}
else if(control.kern__Status__c == 'Running')
{
	System.debug('chain-validation-refusal-verify WAIT: ' + controlChain + ': still Running, wait and run again');
}
else
{
	String verdict = control.kern__Status__c == 'Completed' && control.kern__CompletedSteps__c == 2 ? 'PASS' : 'FAIL';
	System.debug('chain-validation-refusal-verify ' + verdict + ': ' + controlChain + ': ' + control.kern__Status__c + ' with '
			+ control.kern__CompletedSteps__c + ' completed step(s), error ' + control.kern__ErrorMessage__c);
}
