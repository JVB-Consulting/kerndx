// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for SEL_ContentVersion selector.
 *
 * @see SEL_ContentVersion
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date February 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SEL_ContentVersion_TEST
{
	/**
	 * @description Tests that findByFirstPublishLocationId returns content versions
	 * linked to a specific record.
	 */
	@IsTest
	private static void shouldFindByFirstPublishLocationId()
	{
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();

		ContentVersion version = TST_Factory.newContentVersion(record.Id, 'test.txt', Blob.valueOf('test'));
		DML_Builder.newTransaction().doInsert(version).execute();

		List<ContentVersion> results = new SEL_ContentVersion().findByFirstPublishLocationId(record.Id);

		Assert.isFalse(results.isEmpty(), 'Should find content version by publish location');
		Assert.areEqual(record.Id, results[0].FirstPublishLocationId, 'FirstPublishLocationId should match');
	}

	/**
	 * @description Tests that findLatestByContentDocumentId returns the latest versions
	 * for specified content document IDs.
	 */
	@IsTest
	private static void shouldFindLatestByContentDocumentId()
	{
		ContentVersion version = TST_Factory.newContentVersion(null, 'test.txt', Blob.valueOf('test'));
		DML_Builder.newTransaction().doInsert(version).execute();

		List<ContentVersion> allVersions = new SEL_ContentVersion().getAll();
		Set<Id> documentIds = new Set<Id>();
		for(ContentVersion foundVersion : allVersions)
		{
			documentIds.add(foundVersion.ContentDocumentId);
		}

		List<ContentVersion> results = new SEL_ContentVersion().findLatestByContentDocumentId(documentIds);

		Assert.isFalse(results.isEmpty(), 'Should find latest version by document ID');
	}

	/**
	 * @description Tests that findLatestByContentDocumentId returns empty list for empty input.
	 */
	@IsTest
	private static void shouldReturnEmptyForEmptyDocumentIds()
	{
		List<ContentVersion> results = new SEL_ContentVersion().findLatestByContentDocumentId(new Set<Id>());

		Assert.isTrue(results.isEmpty(), 'Should return empty list for empty input');
	}

	/**
	 * @description Tests that getAll returns content versions in test context.
	 */
	@IsTest
	private static void shouldGetAllInTestContext()
	{
		ContentVersion version = TST_Factory.newContentVersion(null, 'test.txt', Blob.valueOf('test'));
		DML_Builder.newTransaction().doInsert(version).execute();

		List<ContentVersion> results = new SEL_ContentVersion().getAll();

		Assert.isFalse(results.isEmpty(), 'Should return content versions in test context');
	}

	/**
	 * @description Tests that isCreateable returns a boolean value.
	 */
	@IsTest
	private static void shouldCheckIsCreateable()
	{
		Boolean result = SEL_ContentVersion.isCreateable;

		Assert.isNotNull(result, 'isCreateable should return a value');
	}
}