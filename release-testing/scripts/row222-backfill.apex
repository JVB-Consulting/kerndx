// Fills Triggering Record Index on API calls and API issues saved before Kern 1.12, so the finders by triggering record
// find them. It copies Triggering Record Id into Triggering Record Index on every row where the Id is filled and the field is blank.
// Run it as a user with the Kern Administrator permission set, or with Modify All on both objects: any other user fills only
// the rows they own. It starts one background job per object. Check that both have ended under Setup, Apex Jobs.
// Running it again is safe: it only picks rows where Triggering Record Index is still blank.
kern.QRY_Condition.Evaluable callsToFill = new kern.QRY_Condition.AndCondition()
		.add(new kern.QRY_Condition.FieldCondition('kern__TriggeringRecordId__c', kern.QRY_Condition.Operator.NOT_EQUALS, null))
		.add(new kern.QRY_Condition.FieldCondition('kern__TriggeringRecordIndex__c', kern.QRY_Condition.Operator.EQUALS, null));
kern.UTIL_BulkUpdates.copyField('kern__ApiCall__c', 'kern__TriggeringRecordId__c', 'kern__TriggeringRecordIndex__c', callsToFill, 200, false);

kern.QRY_Condition.Evaluable issuesToFill = new kern.QRY_Condition.AndCondition()
		.add(new kern.QRY_Condition.FieldCondition('kern__TriggeringRecordId__c', kern.QRY_Condition.Operator.NOT_EQUALS, null))
		.add(new kern.QRY_Condition.FieldCondition('kern__TriggeringRecordIndex__c', kern.QRY_Condition.Operator.EQUALS, null));
kern.UTIL_BulkUpdates.copyField('kern__ApiIssue__c', 'kern__TriggeringRecordId__c', 'kern__TriggeringRecordIndex__c', issuesToFill, 200, false);
