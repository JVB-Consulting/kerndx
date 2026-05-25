// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for SEL_EntityDefinition selector.
 *
 * @see SEL_EntityDefinition
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date February 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SEL_EntityDefinition_TEST
{
	/**
	 * @description Tests that getShareableEntityByName returns a results map for a known object.
	 */
	@IsTest
	private static void shouldFindShareableEntityByName()
	{
		Map<String, EntityDefinition> results = new SEL_EntityDefinition().getShareableEntityByName(new Set<String> {'Account'});

		Assert.isNotNull(results, 'Should return results map');
	}

	/**
	 * @description Tests that getAllStandardPlatformEvents returns a list.
	 */
	@IsTest
	private static void shouldGetAllStandardPlatformEvents()
	{
		List<EntityDefinition> results = new SEL_EntityDefinition().getAllStandardPlatformEvents();

		Assert.isNotNull(results, 'Should return list');
	}

	/**
	 * @description Tests that getAllCustomPlatformEvents returns a list.
	 */
	@IsTest
	private static void shouldGetAllCustomPlatformEvents()
	{
		List<EntityDefinition> results = new SEL_EntityDefinition().getAllCustomPlatformEvents();

		Assert.isNotNull(results, 'Should return list');
	}

	/**
	 * @description Tests that getAllStandardChangeCaptureEvents returns a list.
	 */
	@IsTest
	private static void shouldGetAllStandardChangeCaptureEvents()
	{
		List<EntityDefinition> results = new SEL_EntityDefinition().getAllStandardChangeCaptureEvents();

		Assert.isNotNull(results, 'Should return list');
	}

	/**
	 * @description Tests that getAllCustomChangeCaptureEvents returns a list.
	 */
	@IsTest
	private static void shouldGetAllCustomChangeCaptureEvents()
	{
		List<EntityDefinition> results = new SEL_EntityDefinition().getAllCustomChangeCaptureEvents();

		Assert.isNotNull(results, 'Should return list');
	}

	/**
	 * @description Tests that `findByDurableIds` short-circuits to an empty list when passed
	 * a null set — guards callers (e.g., `SEL_MaskingTarget.resolveDurableIds`) from needing
	 * their own null check.
	 */
	@IsTest
	private static void shouldReturnEmptyWhenDurableIdsNull()
	{
		List<EntityDefinition> results = new SEL_EntityDefinition().findByDurableIds(null);

		Assert.isNotNull(results, 'Should return a list, never null');
		Assert.isTrue(results.isEmpty(), 'Should be empty when input set is null');
	}

	/**
	 * @description Tests that `findByDurableIds` short-circuits to an empty list when passed
	 * an empty set, avoiding a wasted SOQL.
	 */
	@IsTest
	private static void shouldReturnEmptyWhenDurableIdsEmpty()
	{
		List<EntityDefinition> results = new SEL_EntityDefinition().findByDurableIds(new Set<String>());

		Assert.isNotNull(results, 'Should return a list, never null');
		Assert.isTrue(results.isEmpty(), 'Should be empty when input set is empty');
	}

	/**
	 * @description Tests that `findByDurableIds` executes the query path (covers the `toList`
	 * branch) when called with a syntactically-valid but non-matching durable Id. Returns an
	 * empty list rather than throwing.
	 */
	@IsTest
	private static void shouldReturnEmptyListForUnknownDurableId()
	{
		List<EntityDefinition> results = new SEL_EntityDefinition().findByDurableIds(new Set<String> {'01INOTANACTUALID'});

		Assert.isNotNull(results, 'Should return a list, never null');
		Assert.isTrue(results.isEmpty(), 'Unknown durable Id should yield no rows');
	}
}