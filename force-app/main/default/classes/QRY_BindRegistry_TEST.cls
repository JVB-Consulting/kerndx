// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for QRY_BindRegistry.
 * Tests bind variable registration, collection registration, and registry management.
 *
 * @see QRY_BindRegistry
 *
 * @author Jason van Beukering
 *
 * @group Query Infrastructure
 *
 * @date February 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class QRY_BindRegistry_TEST
{
	/**
	 * @description Tests that register returns sequentially named bind variables.
	 */
	@IsTest
	private static void registerReturnsSequentialBindNames()
	{
		QRY_BindRegistry registry = new QRY_BindRegistry();

		String first = registry.register('value1');
		String second = registry.register('value2');
		String third = registry.register(123);

		Assert.areEqual(':bv0', first, 'First bind should be :bv0');
		Assert.areEqual(':bv1', second, 'Second bind should be :bv1');
		Assert.areEqual(':bv2', third, 'Third bind should be :bv2');
	}

	/**
	 * @description Tests that register stores values in the map correctly.
	 */
	@IsTest
	private static void registerStoresValuesInMap()
	{
		QRY_BindRegistry registry = new QRY_BindRegistry();
		String testValue = 'TestValue';

		registry.register(testValue);
		Map<String, Object> bindMap = registry.getMap();

		Assert.areEqual(1, bindMap.size(), 'Should have one binding');
		Assert.areEqual(testValue, bindMap.get('bv0'), 'Value should be stored correctly');
	}

	/**
	 * @description Tests that register handles null values.
	 */
	@IsTest
	private static void registerHandlesNullValue()
	{
		QRY_BindRegistry registry = new QRY_BindRegistry();

		String bindName = registry.register(null);
		Map<String, Object> bindMap = registry.getMap();

		Assert.areEqual(':bv0', bindName, 'Should return bind name even for null');
		Assert.isTrue(bindMap.containsKey('bv0'), 'Should contain key for null value');
		Assert.isNull(bindMap.get('bv0'), 'Value should be null');
	}

	/**
	 * @description Tests that registerCollection returns bind reference with colon prefix.
	 */
	@IsTest
	private static void registerCollectionReturnsColonPrefixedRef()
	{
		QRY_BindRegistry registry = new QRY_BindRegistry();
		Set<String> values = new Set<String> {'Open', 'Pending'};

		String ref = registry.registerCollection(values);

		Assert.areEqual(':bv0', ref, 'Should return colon-prefixed bind reference');
	}

	/**
	 * @description Tests that registerCollection returns empty parens for null.
	 */
	@IsTest
	private static void registerCollectionReturnsEmptyParensForNull()
	{
		QRY_BindRegistry registry = new QRY_BindRegistry();

		String ref = registry.registerCollection(null);

		Assert.areEqual('()', ref, 'Should return empty parens for null collection');
		Assert.isTrue(registry.isEmpty(), 'Should not store null collection');
	}

	/**
	 * @description Tests that registerCollection stores collection in map.
	 */
	@IsTest
	private static void registerCollectionStoresInMap()
	{
		QRY_BindRegistry registry = new QRY_BindRegistry();
		List<Integer> values = new List<Integer> {1, 2, 3};

		registry.registerCollection(values);
		Map<String, Object> bindMap = registry.getMap();

		Assert.areEqual(1, bindMap.size(), 'Should have one binding');
		Assert.areEqual(values, bindMap.get('bv0'), 'Collection should be stored');
	}

	/**
	 * @description Tests that getMap returns the bindings map.
	 */
	@IsTest
	private static void getMapReturnBindings()
	{
		QRY_BindRegistry registry = new QRY_BindRegistry();
		registry.register('value1');
		registry.register(42);

		Map<String, Object> bindMap = registry.getMap();

		Assert.areEqual(2, bindMap.size(), 'Should return map with 2 entries');
		Assert.areEqual('value1', bindMap.get('bv0'), 'First value correct');
		Assert.areEqual(42, bindMap.get('bv1'), 'Second value correct');
	}

	/**
	 * @description Tests that isEmpty returns true for new registry.
	 */
	@IsTest
	private static void isEmptyReturnsTrueForNewRegistry()
	{
		QRY_BindRegistry registry = new QRY_BindRegistry();

		Assert.isTrue(registry.isEmpty(), 'New registry should be empty');
	}

	/**
	 * @description Tests that isEmpty returns false after registration.
	 */
	@IsTest
	private static void isEmptyReturnsFalseAfterRegistration()
	{
		QRY_BindRegistry registry = new QRY_BindRegistry();
		registry.register('value');

		Assert.isFalse(registry.isEmpty(), 'Registry should not be empty after registration');
	}

	/**
	 * @description Tests that size returns correct count.
	 */
	@IsTest
	private static void sizeReturnsCorrectCount()
	{
		QRY_BindRegistry registry = new QRY_BindRegistry();

		Assert.areEqual(0, registry.size(), 'Initial size should be 0');

		registry.register('a');
		Assert.areEqual(1, registry.size(), 'Size should be 1');

		registry.register('b');
		Assert.areEqual(2, registry.size(), 'Size should be 2');

		registry.registerCollection(new List<String> {'x'});
		Assert.areEqual(3, registry.size(), 'Size should be 3');
	}

	/**
	 * @description Tests that clear removes all bindings and resets counter.
	 */
	@IsTest
	private static void clearRemovesBindingsAndResetsCounter()
	{
		QRY_BindRegistry registry = new QRY_BindRegistry();
		registry.register('value1');
		registry.register('value2');

		registry.clear();

		Assert.isTrue(registry.isEmpty(), 'Registry should be empty after clear');
		Assert.areEqual(0, registry.size(), 'Size should be 0');

		String newBind = registry.register('newValue');
		Assert.areEqual(':bv0', newBind, 'Counter should be reset to 0');
	}

	/**
	 * @description Tests that mixed register and registerCollection work correctly.
	 */
	@IsTest
	private static void mixedRegistrationWorksCorrectly()
	{
		QRY_BindRegistry registry = new QRY_BindRegistry();

		String single1 = registry.register('single1');
		String collection1 = registry.registerCollection(new Set<Id> {});
		String single2 = registry.register(Date.today());

		Assert.areEqual(':bv0', single1, 'First single should be :bv0');
		Assert.areEqual(':bv1', collection1, 'Collection should be :bv1');
		Assert.areEqual(':bv2', single2, 'Second single should be :bv2');
		Assert.areEqual(3, registry.size(), 'Should have 3 bindings');
	}

	/**
	 * @description Tests register with various data types.
	 */
	@IsTest
	private static void registerHandlesVariousDataTypes()
	{
		QRY_BindRegistry registry = new QRY_BindRegistry();

		registry.register('string');
		registry.register(123);
		registry.register(45.67);
		registry.register(true);
		registry.register(Date.today());
		registry.register(Datetime.now());
		registry.register(UTIL_Random.randomId(Account.SObjectType));

		Assert.areEqual(7, registry.size(), 'Should handle all data types');
	}
}