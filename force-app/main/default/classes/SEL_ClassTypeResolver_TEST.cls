// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for SEL_ClassTypeResolver selector.
 *
 * @see SEL_ClassTypeResolver
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date February 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SEL_ClassTypeResolver_TEST
{
	/**
	 * @description Tests that findFirst returns a record when mock metadata exists.
	 */
	@IsTest
	private static void shouldFindFirst()
	{
		TST_Mock.of(ClassTypeResolver__mdt.SObjectType)
				.withOverride(ClassTypeResolver__mdt.ClassName__c, 'MockResolver').build();

		ClassTypeResolver__mdt result = new SEL_ClassTypeResolver().findFirst();

		Assert.isNotNull(result, 'Should return metadata record when configured');
	}

	/**
	 * @description Tests that findAll returns all configured records.
	 */
	@IsTest
	private static void shouldFindAll()
	{
		TST_Mock.of(ClassTypeResolver__mdt.SObjectType)
				.withOverride(ClassTypeResolver__mdt.ClassName__c, 'MockResolver').build();

		List<ClassTypeResolver__mdt> results = new SEL_ClassTypeResolver().findAll();

		Assert.isFalse(results.isEmpty(), 'Should return metadata records when configured');
	}

	/**
	 * @description Tests that findAll breaks Order__c ties using DeveloperName ascending,
	 * so resolver chains are deterministic across orgs (without the secondary sort the
	 * platform decides which same-priority record wins).
	 */
	@IsTest
	private static void shouldOrderSamePriorityByDeveloperNameAscending()
	{
		TST_Mock.of(ClassTypeResolver__mdt.SObjectType)
				.withOverride(ClassTypeResolver__mdt.ClassName__c, 'BetaResolver')
				.withOverride(ClassTypeResolver__mdt.DeveloperName, 'BetaResolver')
				.withOverride(ClassTypeResolver__mdt.Order__c, 10).build();
		TST_Mock.of(ClassTypeResolver__mdt.SObjectType)
				.withOverride(ClassTypeResolver__mdt.ClassName__c, 'AlphaResolver')
				.withOverride(ClassTypeResolver__mdt.DeveloperName, 'AlphaResolver')
				.withOverride(ClassTypeResolver__mdt.Order__c, 10).build();

		List<ClassTypeResolver__mdt> results = new SEL_ClassTypeResolver().findAll();

		Assert.areEqual(2, results.size(), 'Both records should be returned');
		Assert.areEqual('AlphaResolver', results[0].DeveloperName, 'Lower DeveloperName must come first when Order__c ties');
		Assert.areEqual('BetaResolver', results[1].DeveloperName, 'Higher DeveloperName must come second when Order__c ties');
	}
}