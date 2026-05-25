// Section 22 Setup: Assign StrictValidation custom permission
// Run BEFORE section-22-advanced-strategies.apex
//
// Run:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-22-setup.apex

// 22a: Verify flag is disabled without custom permission
Boolean flagBefore = kern.UTIL_FeatureFlag.isEnabled('EnableStrictValidation');
System.assert(!flagBefore, '22a FAIL: Flag should be disabled — user lacks StrictValidation custom permission');
System.debug('22a PASS: EnableStrictValidation flag is disabled (no custom permission)');

// 22b: Assign the StrictValidationAccess permission set
Id permSetId = [
		SELECT Id
		FROM PermissionSet
		WHERE Name = 'StrictValidationAccess'
		LIMIT 1
].Id;
List<PermissionSetAssignment> existing =
[
		SELECT Id
		FROM PermissionSetAssignment
		WHERE PermissionSetId = :permSetId
		AND AssigneeId = :UserInfo.getUserId()
];

if(existing.isEmpty())
{
	insert new PermissionSetAssignment(PermissionSetId = permSetId, AssigneeId = UserInfo.getUserId());
	System.debug('22b PASS: StrictValidationAccess permission set assigned');
}
else
{
	System.debug('22b PASS: StrictValidationAccess already assigned');
}
