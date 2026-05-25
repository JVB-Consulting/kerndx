// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for SEL_EmailTemplate selector.
 *
 * @see SEL_EmailTemplate
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date February 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SEL_EmailTemplate_TEST
{
	/**
	 * @description Known email template DeveloperName used for query tests.
	 */
	private static final String TEST_TEMPLATE_NAME = SEL_EmailTemplate.TEST_EMAIL_TEMPLATE;

	/**
	 * @description Tests that findByName returns matching EmailTemplate records.
	 */
	@IsTest
	private static void shouldFindByName()
	{
		SEL_EmailTemplate selector = new SEL_EmailTemplate();

		List<EmailTemplate> results = selector.findByName(new Set<String> {TEST_TEMPLATE_NAME});

		Assert.isFalse(results.isEmpty(), 'Should return at least one template');
		Assert.areEqual(TEST_TEMPLATE_NAME, results[0].DeveloperName, 'Should return the correct template');
	}

	/**
	 * @description Tests that findByName returns an empty list when no templates match.
	 */
	@IsTest
	private static void shouldReturnEmptyWhenNoneMatch()
	{
		SEL_EmailTemplate selector = new SEL_EmailTemplate();

		List<EmailTemplate> results = selector.findByName(new Set<String> {'NonExistentTemplate_XYZ_999'});

		Assert.isTrue(results.isEmpty(), 'Should return empty list for non-existent template names');
	}
}