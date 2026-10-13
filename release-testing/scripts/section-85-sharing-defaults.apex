/**
 * Section 85: Sharing defaults of the framework's record objects
 *
 * Proves the sharing default (the organization-wide default for people inside the company) that the framework's four
 * record objects carry on this org. A new 1.8 install gives API Issue and Log Entry a Private default, as API Call and
 * Async Chain Execution already had. An upgrade never changes an org's sharing default, so an org upgraded from 1.7
 * keeps Public Read/Write on API Issue and Log Entry until an administrator sets them to Private in Setup, Sharing
 * Settings, as the 1.8 release note tells them to.
 *
 * The expected default for API Issue and Log Entry is the one value a person edits below:
 *   - fresh install (Phase 1.3): leave it at 'Private'.
 *   - upgrade leg (Phase 1.3b), right after the upgrade: set it to 'ReadWrite' and run the section.
 *   - upgrade leg, after setting both objects to Private in Sharing Settings: set it back to 'Private' and run again.
 * API Call and Async Chain Execution read Private in every case.
 *
 * One check, one PASS line when all four objects read the expected default.
 *
 * Run:
 *   sf apex run --file release-testing/scripts/section-85-sharing-defaults.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 */

final String EXPECTED_API_ISSUE_AND_LOG_ENTRY_DEFAULT = 'Private';

final String PRIVATE_DEFAULT = 'Private';
final Map<String, String> EXPECTED_DEFAULT_BY_OBJECT = new Map<String, String>
{
		'kern__ApiIssue__c' => EXPECTED_API_ISSUE_AND_LOG_ENTRY_DEFAULT,
		'kern__LogEntry__c' => EXPECTED_API_ISSUE_AND_LOG_ENTRY_DEFAULT,
		'kern__ApiCall__c' => PRIVATE_DEFAULT,
		'kern__AsyncChainExecution__c' => PRIVATE_DEFAULT
};

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, '=== Section 85: Sharing defaults of the framework record objects ===');

Integer pass = 0;
Integer fail = 0;
List<String> failures = new List<String>();

try
{
	Set<String> objectNames = EXPECTED_DEFAULT_BY_OBJECT.keySet();
	List<EntityDefinition> definitions =
	[
			SELECT QualifiedApiName,
					InternalSharingModel
			FROM EntityDefinition
			WHERE QualifiedApiName IN :objectNames
	];

	Map<String, String> actualDefaultByObject = new Map<String, String>();
	for(EntityDefinition definition : definitions)
	{
		actualDefaultByObject.put(definition.QualifiedApiName, definition.InternalSharingModel);
	}

	List<String> mismatches = new List<String>();
	for(String objectName : objectNames)
	{
		String expected = EXPECTED_DEFAULT_BY_OBJECT.get(objectName);
		String actual = actualDefaultByObject.get(objectName);
		if(actual != expected)
		{
			mismatches.add(objectName + ' reads ' + actual + ', expected ' + expected);
		}
	}

	Assert.isTrue(mismatches.isEmpty(), '85a: Expected every object to read its expected sharing default: ' + String.join(mismatches, '; '));
	System.debug(LoggingLevel.INFO, '85a PASS: the four objects read their expected sharing defaults ' + JSON.serialize(actualDefaultByObject));
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '85a FAIL: ' + scenarioError.getMessage());
	failures.add('85a: ' + scenarioError.getMessage());
	fail++;
}

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, 'Section 85: ' + pass + ' passed, ' + fail + ' failed');
if(fail > 0)
{
	for(String message : failures)
	{
		System.debug(LoggingLevel.ERROR, '  - ' + message);
	}
	throw new System.AssertException('Section 85 failed: ' + fail + ' scenarios');
}
