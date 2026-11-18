// Labels in a validation error message. See RUNBOOK.md, "Labels in a validation error message".
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Prerequisites: the package is installed (1.3), the 1.4 artifacts are deployed (they hold the Account trigger setting),
// and release-testing/fixtures/validation-label-merge/ is deployed.
//
// Checks the message an installed Kern validation rule gives when it names custom labels. The fixture rule
// ValidationLabelMergeProbe fails only for an Account named ValidationLabelMergeProbe, and its message names three labels:
// the fixture label {!$Label.ValidationLabelMergeProbe}, created in this org; the package label
// {!$Label.kern__EventUsageMetrics_Validation_StartAfterEnd}; and {!$Label.NoSuchLabelAnywhere}, which does not exist.
// The script asks kern.UTIL_ValidationRule.validate for the errors of a new Account with that name. It saves nothing.
// Prints one PASS or FAIL line for the message. Before it runs, it deletes the warnings an earlier attempt left for
// these labels, so the verify script counts only the warnings of this attempt. It also saves one INFO Log Entry that marks
// the start of the attempt, so the verify script knows how long it has been waiting.
//
// Run:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/validation-label-merge-probe.apex > tmp/validation-label-merge-probe.log 2>&1
//   grep USER_DEBUG tmp/validation-label-merge-probe.log

String ruleName = 'ValidationLabelMergeProbe';
String subscriberText = 'Release testing found the subscriber label.';
String packageText = 'The start date must be on or before the end date.';
String missingMergeField = '{!$Label.NoSuchLabelAnywhere}';
String expectedMessage = 'Subscriber: ' + subscriberText + ' Package: ' + packageText + ' Missing: ' + missingMergeField;
List<String> warnedLabelWords = new List<String>
{
		'names the label NoSuchLabelAnywhere,',
		'names the label ValidationLabelMergeProbe,',
		'names the label kern__EventUsageMetrics_Validation_StartAfterEnd,'
};

List<kern__LogEntry__c> earlierWarnings = new List<kern__LogEntry__c>();
for(kern__LogEntry__c entry :
[
		SELECT Id,
				kern__Message__c
		FROM kern__LogEntry__c
		WHERE kern__LogLevel__c = 'WARN' AND kern__ClassMethod__c LIKE '%UTIL_ValidationRule/processMergeFields'
])
{
	for(String words : warnedLabelWords)
	{
		if((entry.kern__Message__c ?? '').contains(words))
		{
			earlierWarnings.add(entry);
			break;
		}
	}
}
delete earlierWarnings;

String markerWords = 'validation-label-merge-probe';
delete [SELECT Id FROM kern__LogEntry__c WHERE kern__ClassMethod__c = :markerWords AND kern__LogLevel__c = 'INFO'];
insert new kern__LogEntry__c(
		kern__ClassMethod__c = markerWords,
		kern__LogLevel__c = 'INFO',
		kern__Message__c = 'Start of a probe attempt, used by the verify script to time its wait'
);

kern.UTIL_ValidationRule.clearAllBypasses();

Account probeAccount = new Account(Name = ruleName);
List<kern.UTIL_ValidationRule.ValidationResult> results = kern.UTIL_ValidationRule.validate(new List<SObject> {probeAccount}, null,
		TriggerOperation.BEFORE_INSERT);

String actualMessage = null;
for(kern.UTIL_ValidationRule.ValidationError error : results[0].errors)
{
	if(error.ruleName == ruleName)
	{
		actualMessage = error.message;
	}
}

if(actualMessage == null)
{
	System.debug('validation-label-merge-probe FAIL: the rule ' + ruleName + ' did not fail for the Account, so there is no message to check;'
			+ ' check that the fixture is deployed and look for an ERROR Log Entry from kern.UTIL_ValidationRule/evaluateRule. Errors from other rules: '
			+ results[0].errors.size());
}
else
{
	Boolean subscriberFilled = actualMessage.contains('Subscriber: ' + subscriberText);
	Boolean packageFilled = actualMessage.contains('Package: ' + packageText);
	Boolean missingKept = actualMessage.contains('Missing: ' + missingMergeField);
	String verdict = actualMessage == expectedMessage ? 'PASS' : 'FAIL';
	System.debug('validation-label-merge-probe ' + verdict + ': subscriber label filled: ' + subscriberFilled + '; package label filled: '
			+ packageFilled + '; missing label kept as written: ' + missingKept + '; earlier warnings deleted: ' + earlierWarnings.size()
			+ '; message: ' + actualMessage);
}
