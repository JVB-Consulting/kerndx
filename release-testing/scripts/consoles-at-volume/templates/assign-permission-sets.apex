// Consoles at volume: gives the run user the chain operator permission sets preflight found missing.
// Tokens: __PERMISSION_SET_NAMES__ (a list literal's body) __NAMESPACE_CLAUSE__ (NamespacePrefix = 'x' or NamespacePrefix = NULL) __USER_ID__
Integer assigned = 0;
for(PermissionSet permissionSet : [SELECT Id FROM PermissionSet WHERE Name IN (__PERMISSION_SET_NAMES__) AND __NAMESPACE_CLAUSE__])
{
	insert new PermissionSetAssignment(AssigneeId = '__USER_ID__', PermissionSetId = permissionSet.Id);
	assigned++;
}
System.debug('VOLUME_PREFLIGHT assigned=' + assigned);
