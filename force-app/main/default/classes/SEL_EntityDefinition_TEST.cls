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
 * @date February 2026, June 2026
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
	 * @description Tests that `getAllChangeCaptureEvents` returns both standard and custom
	 * ChangeEvent entities from a single query, with the `QualifiedApiName` passed through verbatim
	 * (never rewritten). `TST_Mock` returns registered rows regardless of the query predicate, so
	 * this test asserts the passthrough contract the caller relies on; the `PublisherId`/capability
	 * filter itself is proven against a real org by the streaming release tests.
	 */
	@IsTest
	private static void shouldGetAllChangeCaptureEvents()
	{
		TST_Mock.of(EntityDefinition.SObjectType)
				.withOverride(EntityDefinition.Label, 'Account Change Event')
				.withOverride(EntityDefinition.QualifiedApiName, 'AccountChangeEvent')
				.build();
		TST_Mock.of(EntityDefinition.SObjectType)
				.withOverride(EntityDefinition.Label, 'Change Event: Foobar')
				.withOverride(EntityDefinition.QualifiedApiName, 'Foobar__ChangeEvent')
				.build();

		List<EntityDefinition> results = new SEL_EntityDefinition().getAllChangeCaptureEvents();

		Set<String> apiNames = new Set<String>();

		for(EntityDefinition result : results)
		{
			apiNames.add(result.QualifiedApiName);
		}

		Assert.isTrue(apiNames.contains('AccountChangeEvent'), 'Standard change events must be returned by the single change-capture query');
		Assert.isTrue(apiNames.contains('Foobar__ChangeEvent'), 'Custom change events must be returned by the same single query, api name unmodified');
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

	/**
	 * @description Tests that `findSelectableObjects` returns the customizable entities an administrator
	 * can analyze in the advisor. Every org exposes customizable objects (e.g. Account), so the result is
	 * non-empty — exercising the query path.
	 */
	@IsTest
	private static void findSelectableObjectsReturnsCustomizableObjects()
	{
		List<EntityDefinition> results = new SEL_EntityDefinition().findSelectableObjects();

		Assert.isNotNull(results, 'Should return a list, never null');
		Assert.isFalse(results.isEmpty(), 'an org always exposes customizable objects such as Account');
	}

	/**
	 * @description Tests that `findSelectableObjects` offers only objects that can host an Apex trigger.
	 * Masking is applied through the trigger framework, so a non-triggerable object can never be masked and
	 * must not appear in the advisor's picker. A customizable, triggerable object such as `Account` is
	 * offered, while a customizable but non-triggerable object such as `PricebookEntry` is excluded.
	 */
	@IsTest
	private static void findSelectableObjectsExcludesNonTriggerableObjects()
	{
		Set<String> selectable = new Set<String>();
		for(EntityDefinition entity : new SEL_EntityDefinition().findSelectableObjects())
		{
			selectable.add(entity.QualifiedApiName);
		}

		Assert.isTrue(selectable.contains('Account'), 'a customizable triggerable object such as Account is still offered');
		Assert.isFalse(selectable.contains('PricebookEntry'), 'a customizable but non-triggerable object is excluded from the picker');
	}

	/**
	 * @description Tests that `findSelectableObjects` projects `NamespacePrefix`, which the Data Masking
	 * Advisor reads to scope its custom-object coverage scan to the subscriber's own (un-namespaced)
	 * objects — managed-package objects are excluded from the default scan population. Reading the field
	 * off every returned row proves the projection carries it (an unqueried field throws SObjectException).
	 */
	@IsTest
	private static void findSelectableObjectsProjectsNamespacePrefix()
	{
		Boolean foundUnNamespacedObject = false;
		for(EntityDefinition entity : new SEL_EntityDefinition().findSelectableObjects())
		{
			if(entity.NamespacePrefix == null)
			{
				foundUnNamespacedObject = true;
			}
		}

		Assert.isTrue(foundUnNamespacedObject, 'every org exposes selectable objects without a namespace prefix, such as Account');
	}
}