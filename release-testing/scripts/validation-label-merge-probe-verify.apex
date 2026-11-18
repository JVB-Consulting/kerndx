// Labels in a validation error message: verification. See RUNBOOK.md, "Labels in a validation error message".
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Prerequisites: release-testing/scripts/validation-label-merge-probe.apex ran and printed PASS, at least 30 seconds ago
// (a log entry is saved a few seconds after the probe sends it).
//
// Counts the WARN Log Entries from kern.UTIL_ValidationRule/processMergeFields that name each of the three labels in the
// fixture rule's message. The probe deleted the ones an earlier attempt left, so only this attempt counts.
// PASS: exactly one warning names NoSuchLabelAnywhere, and none names ValidationLabelMergeProbe or
// kern__EventUsageMetrics_Validation_StartAfterEnd, because those two labels exist.
// WAIT: no warning yet for any label, and the probe started less than 5 minutes ago. Wait 30 seconds and run again.
// FAIL: any other count, no warning 5 minutes or more after the probe started, or no probe start mark (run the probe first).
//
// Run:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/validation-label-merge-probe-verify.apex > tmp/validation-label-merge-verify.log 2>&1
//   grep USER_DEBUG tmp/validation-label-merge-verify.log

String missingWords = 'names the label NoSuchLabelAnywhere,';
String subscriberWords = 'names the label ValidationLabelMergeProbe,';
String packageWords = 'names the label kern__EventUsageMetrics_Validation_StartAfterEnd,';

Integer missingWarnings = 0;
Integer subscriberWarnings = 0;
Integer packageWarnings = 0;
String missingWarningText = null;
for(kern__LogEntry__c entry :
[
		SELECT kern__Message__c
		FROM kern__LogEntry__c
		WHERE kern__LogLevel__c = 'WARN' AND kern__ClassMethod__c LIKE '%UTIL_ValidationRule/processMergeFields'
])
{
	String message = entry.kern__Message__c ?? '';
	if(message.contains(missingWords))
	{
		missingWarnings++;
		missingWarningText = message;
	}
	if(message.contains(subscriberWords))
	{
		subscriberWarnings++;
	}
	if(message.contains(packageWords))
	{
		packageWarnings++;
	}
}

String counts = 'warnings naming NoSuchLabelAnywhere: ' + missingWarnings + '; naming ValidationLabelMergeProbe: ' + subscriberWarnings
		+ '; naming kern__EventUsageMetrics_Validation_StartAfterEnd: ' + packageWarnings;

if(missingWarnings == 0 && subscriberWarnings == 0 && packageWarnings == 0)
{
	Integer waitLimitMinutes = 5;
	List<kern__LogEntry__c> probeMarks =
	[
			SELECT CreatedDate
			FROM kern__LogEntry__c
			WHERE kern__ClassMethod__c = 'validation-label-merge-probe' AND kern__LogLevel__c = 'INFO'
			ORDER BY CreatedDate DESC
			LIMIT 1
	];
	if(probeMarks.isEmpty())
	{
		System.debug('validation-label-merge-verify FAIL: ' + counts + '; no probe start mark was found, so run the probe first');
	}
	else if(probeMarks[0].CreatedDate.addMinutes(waitLimitMinutes) <= Datetime.now())
	{
		System.debug('validation-label-merge-verify FAIL: ' + counts + '; still no warning ' + waitLimitMinutes
				+ ' minutes after the probe started; check the log settings for WARN entries');
	}
	else
	{
		System.debug('validation-label-merge-verify WAIT: ' + counts + '; wait 30 seconds and run again');
	}
}
else
{
	String verdict = missingWarnings == 1 && subscriberWarnings == 0 && packageWarnings == 0 ? 'PASS' : 'FAIL';
	System.debug('validation-label-merge-verify ' + verdict + ': ' + counts + '; warning: ' + missingWarningText);
}
