// Section 22 Cleanup: Remove StrictValidation custom permission
// Run AFTER section-22-advanced-strategies.apex
//
// Run:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-22-cleanup.apex

Id permSetId = [
		SELECT Id
		FROM PermissionSet
		WHERE Name = 'StrictValidationAccess'
		LIMIT 1
].Id;
List<PermissionSetAssignment> assignments =
[
		SELECT Id
		FROM PermissionSetAssignment
		WHERE PermissionSetId = :permSetId
		AND AssigneeId = :UserInfo.getUserId()
];

if(!assignments.isEmpty())
{
	delete assignments;
}

Boolean flagAfter = kern.UTIL_FeatureFlag.isEnabled('EnableStrictValidation');
System.assert(!flagAfter, '22i FAIL: Flag should be disabled after permission removal');
System.debug('22i PASS: Permission removed, flag disabled, Fail Fast group deactivated');
