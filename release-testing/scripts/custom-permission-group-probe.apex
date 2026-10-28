// Custom permission muted in a permission set group. See RUNBOOK.md, "Custom permission muted in a permission set group".
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Prerequisites: the fixture in release-testing/fixtures/custom-permission-group/ is deployed, and one Salesforce licence
// seat is free.
//
// Asks Kern, as the running administrator, whether another user holds the packaged custom permission AbortAsyncChain.
// The question goes through the global method kern.UTIL_FeatureFlag.isEnabled(flagName, userId) and the packaged flag
// AsyncChainAbort_Enabled, whose packaged strategy is the custom permission core.AbortAsyncChain (a record this script cannot read).
// The other user is the Standard User custom-permission-probe.<org id>@example.com. The script creates that user, or
// makes it active again, and gives it the permission set group CustomPermissionGroupProbe.
//
// Run 1, with the muting set CustomPermissionGroupProbeMute in the group: Salesforce does not give the user the
// permission, so Kern must answer false. On PASS the script takes the muting set out of the group.
// Run 2, once the group shows the status Updated again: Salesforce gives the user the permission, so Kern must answer
// true. On PASS the script takes the group away from the user and makes the user inactive.
//
// Prints one line that starts with custom-permission-group-probe and then PASS, FAIL, WAIT or SETUP.
// WAIT means the group is still being worked out by Salesforce: wait 30 seconds and run the script again.
// SETUP means the org is not ready for the check; the line says what is missing.
//
// Run:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/custom-permission-group-probe.apex > tmp/custom-permission-group-probe.log 2>&1
//   grep USER_DEBUG tmp/custom-permission-group-probe.log

final String LINE_START = 'custom-permission-group-probe ';
final String FLAG_NAME = 'AsyncChainAbort_Enabled';
final String PERMISSION_NAME = 'AbortAsyncChain';
final String PACKAGE_NAMESPACE = 'kern';
final String GROUP_NAME = 'CustomPermissionGroupProbe';
final String MUTING_SET_NAME = 'CustomPermissionGroupProbeMute';
final String PROFILE_NAME = 'Standard User';
final String GROUP_UPDATED = 'Updated';
String username = 'custom-permission-probe.' + UserInfo.getOrganizationId() + '@example.com';

List<kern__FeatureFlag__mdt> flags =
[
		SELECT kern__IsActive__c, kern__ResultOnNoMatch__c
		FROM kern__FeatureFlag__mdt
		WHERE DeveloperName = :FLAG_NAME AND NamespacePrefix = :PACKAGE_NAMESPACE
];
List<kern__FeatureFlagStrategy__mdt> visibleStrategies =
[
		SELECT DeveloperName, NamespacePrefix
		FROM kern__FeatureFlagStrategy__mdt
		WHERE kern__FeatureFlag__r.DeveloperName = :FLAG_NAME AND kern__IsActive__c = true
];
List<kern__FeatureFlagStrategy__mdt> addedStrategies = new List<kern__FeatureFlagStrategy__mdt>();
for(kern__FeatureFlagStrategy__mdt strategy : visibleStrategies)
{
	if(strategy.NamespacePrefix != PACKAGE_NAMESPACE)
	{
		addedStrategies.add(strategy);
	}
}
List<PermissionSetGroup> groups = [SELECT Id, Status FROM PermissionSetGroup WHERE DeveloperName = :GROUP_NAME];
List<MutingPermissionSet> mutingSets = [SELECT Id FROM MutingPermissionSet WHERE DeveloperName = :MUTING_SET_NAME];
List<Profile> profiles = [SELECT Id FROM Profile WHERE Name = :PROFILE_NAME];
List<CustomPermission> permissions =
[
		SELECT Id
		FROM CustomPermission
		WHERE DeveloperName = :PERMISSION_NAME AND NamespacePrefix = :PACKAGE_NAMESPACE
];

String setupProblem;
if(flags.isEmpty() || !flags[0].kern__IsActive__c || flags[0].kern__ResultOnNoMatch__c)
{
	setupProblem = 'the flag ' + FLAG_NAME + ' is missing, inactive, or set to answer true when no strategy matches';
}
else if(!addedStrategies.isEmpty())
{
	setupProblem = 'the flag ' + FLAG_NAME + ' has active strategies added in this org: ' + addedStrategies
			+ '; the check expects only the packaged strategy';
}
else if(groups.isEmpty() || mutingSets.isEmpty())
{
	setupProblem = 'the permission set group ' + GROUP_NAME + ' or the muting set ' + MUTING_SET_NAME
			+ ' is missing: deploy release-testing/fixtures/custom-permission-group';
}
else if(profiles.isEmpty() || permissions.isEmpty())
{
	setupProblem = 'the profile ' + PROFILE_NAME + ' or the custom permission ' + PACKAGE_NAMESPACE + '__' + PERMISSION_NAME + ' is missing';
}
else
{
	List<PermissionSet> profilePermissionSets = [SELECT Id FROM PermissionSet WHERE ProfileId = :profiles[0].Id];
	Integer profileGrants = [SELECT COUNT() FROM SetupEntityAccess WHERE ParentId IN :profilePermissionSets AND SetupEntityId = :permissions[0].Id];
	if(profileGrants > 0)
	{
		setupProblem = 'the profile ' + PROFILE_NAME + ' itself grants ' + PERMISSION_NAME
				+ ': the package was installed for all users; use an org where it was installed for administrators only';
	}
}

if(setupProblem != null)
{
	System.debug(LINE_START + 'SETUP: ' + setupProblem);
}
else if(groups[0].Status != GROUP_UPDATED)
{
	System.debug(LINE_START + 'WAIT: the group ' + GROUP_NAME + ' has the status ' + groups[0].Status + ', not ' + GROUP_UPDATED
			+ '; wait 30 seconds and run the script again');
}
else
{
	PermissionSetGroup probeGroup = groups[0];
	List<User> users = [SELECT Id, IsActive FROM User WHERE Username = :username];
	User probeUser;
	if(users.isEmpty())
	{
		probeUser = new User(
				Username = username,
				Email = username,
				LastName = 'Custom Permission Probe',
				Alias = 'cpprobe',
				ProfileId = profiles[0].Id,
				EmailEncodingKey = 'UTF-8',
				LanguageLocaleKey = 'en_US',
				LocaleSidKey = 'en_US',
				TimeZoneSidKey = 'America/Los_Angeles');
		insert probeUser;
	}
	else
	{
		probeUser = users[0];
		if(!probeUser.IsActive)
		{
			probeUser.IsActive = true;
			update probeUser;
		}
	}

	List<PermissionSetAssignment> assignments =
	[
			SELECT Id
			FROM PermissionSetAssignment
			WHERE AssigneeId = :probeUser.Id AND PermissionSetGroupId = :probeGroup.Id
	];
	if(assignments.isEmpty())
	{
		assignments.add(new PermissionSetAssignment(AssigneeId = probeUser.Id, PermissionSetGroupId = probeGroup.Id));
		insert assignments;
	}

	List<PermissionSetGroupComponent> mutingComponents =
	[
			SELECT Id
			FROM PermissionSetGroupComponent
			WHERE PermissionSetGroupId = :probeGroup.Id AND PermissionSetId = :mutingSets[0].Id
	];
	Boolean isMuted = !mutingComponents.isEmpty();
	Boolean expected = !isMuted;
	Id probeUserId = probeUser.Id;
	Boolean kernAnswer = kern.UTIL_FeatureFlag.isEnabled(FLAG_NAME, probeUserId);
	String state = 'muting set in the group: ' + isMuted + '; expected from the group: ' + expected
			+ '; Kern answers: ' + kernAnswer + '; user ' + probeUserId;

	if(kernAnswer != expected)
	{
		System.debug(LINE_START + 'FAIL: ' + state);
	}
	else if(isMuted)
	{
		delete mutingComponents;
		System.debug(LINE_START + 'PASS: ' + state + '. The muting set is now out of the group: wait until the group status is '
				+ GROUP_UPDATED + ', then run the script again');
	}
	else
	{
		delete assignments;
		probeUser.IsActive = false;
		update probeUser;
		System.debug(LINE_START + 'PASS: ' + state + '. The group was taken from the user and the user is inactive');
	}
}
