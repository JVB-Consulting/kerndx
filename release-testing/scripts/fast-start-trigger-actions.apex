// Fast Start - Trigger Actions: verify active TriggerAction__mdt configuration
// Run from Developer Console > Execute Anonymous (or sf apex run --file ...)
// NOTE: kern.TST_Factory.newTriggerActionForContext is @TestVisible private — do NOT call it here.
// Use this script only to inspect deployed metadata; never to set up CMDT in anonymous Apex.

List<kern__TriggerAction__mdt> actions = [
	SELECT DeveloperName, kern__ApexClassName__c, kern__Event__c, kern__Order__c, kern__TriggerSetting__c, kern__BypassExecution__c
	FROM kern__TriggerAction__mdt
	WHERE kern__BypassExecution__c = false
	ORDER BY kern__TriggerSetting__c, kern__Order__c
	LIMIT 10
];

for(kern__TriggerAction__mdt action : actions)
{
	System.debug(
		'Setting=' + action.kern__TriggerSetting__c
		+ ' | Class=' + action.kern__ApexClassName__c
		+ ' | Event=' + action.kern__Event__c
		+ ' | Order=' + action.kern__Order__c
	);
}
