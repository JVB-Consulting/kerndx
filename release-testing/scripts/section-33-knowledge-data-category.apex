// =============================================================================
// Section 33: Knowledge — WITH DATA CATEGORY Queries
// =============================================================================
// Org: ${SF_SUBSCRIBER_ORG_ALIAS} (Knowledge-enabled, created with km-scratch-def.json)
// Prerequisites:
//   - kern managed package installed
//   - Knowledge settings + data category groups deployed
//   - section-33-knowledge-setup.apex executed
//   - Data categories assigned to articles
//
// Run:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-33-knowledge-data-category.apex
// =============================================================================

try
{
	// Test 33a: SOQL generation — withDataCategory produces valid SOQL string
	{
		String soql = kern.QRY_Builder.selectFrom(KnowledgeArticleVersion.SObjectType)
				.fields(new List<String>{'Id', 'Title'})
				.condition('PublishStatus').equals('Online')
				.condition('Language').equals('en_US')
				.withDataCategory('KM_TestCategory__c').at('Alpha__c')
				.toSoql();

		System.assert(soql.contains('WITH DATA CATEGORY KM_TestCategory__c AT Alpha__c'), '33a FAIL: SOQL should contain data category clause, got: ' + soql);
		System.debug('33a PASS: withDataCategory().at() generates correct SOQL: ' + soql);
	}

	// Test 33b: Single category query — AT returns matching articles
	{
		List<SObject> results = kern.QRY_Builder.selectFrom(KnowledgeArticleVersion.SObjectType)
				.fields(new List<String>{'Id', 'Title'})
				.condition('PublishStatus').equals('Online')
				.condition('Language').equals('en_US')
				.condition('Title').contains('KDX Test')
				.withDataCategory('KM_TestCategory__c').at('Alpha__c')
				.toList();

		System.assert(results.size() >= 1, '33b FAIL: Should find at least 1 Alpha article, found: ' + results.size());
		for(SObject record : results)
		{
			System.assert(((String)record.get('Title')).contains('Alpha'), '33b FAIL: Article should be Alpha category: ' + record.get('Title'));
		}
		System.debug('33b PASS: AT query returns ' + results.size() + ' Alpha articles');
	}

	// Test 33c: BELOW operator — returns all descendants
	{
		List<SObject> results = kern.QRY_Builder.selectFrom(KnowledgeArticleVersion.SObjectType)
				.fields(new List<String>{'Id', 'Title'})
				.condition('PublishStatus').equals('Online')
				.condition('Language').equals('en_US')
				.condition('Title').contains('KDX Test')
				.withDataCategory('KM_TestCategory__c').below('All__c')
				.toList();

		System.assert(results.size() >= 3, '33c FAIL: BELOW All should return all test articles, found: ' + results.size());
		System.debug('33c PASS: BELOW All returns ' + results.size() + ' articles (all descendants)');
	}

	// Test 33d: Multiple groups — AND filter across two category groups
	{
		List<SObject> results = kern.QRY_Builder.selectFrom(KnowledgeArticleVersion.SObjectType)
				.fields(new List<String>{'Id', 'Title'})
				.condition('PublishStatus').equals('Online')
				.condition('Language').equals('en_US')
				.condition('Title').contains('KDX Test')
				.withDataCategory('KM_TestCategory__c').at('Alpha__c')
				.withDataCategory('KM_TestRegion__c').at('North__c')
				.toList();

		System.assert(results.size() >= 1, '33d FAIL: Should find at least 1 Alpha+North article, found: ' + results.size());
		System.debug('33d PASS: Multi-group AND filter returns ' + results.size() + ' articles');
	}

	// Test 33e: Empty result — query category with no matching articles
	{
		List<SObject> results = kern.QRY_Builder.selectFrom(KnowledgeArticleVersion.SObjectType)
				.fields(new List<String>{'Id', 'Title'})
				.condition('PublishStatus').equals('Online')
				.condition('Language').equals('en_US')
				.condition('Title').contains('NONEXISTENT_KDX_MARKER')
				.withDataCategory('KM_TestCategory__c').at('Beta__c')
				.toList();

		System.assert(results.isEmpty(), '33e FAIL: Should return no results for nonexistent title, found: ' + results.size());
		System.debug('33e PASS: Query with no matching articles returns empty list');
	}
}
catch(Exception error)
{
	System.debug('33-UNEXPECTED FAIL: ' + error.getMessage() + ' at ' + error.getStackTraceString());
}
