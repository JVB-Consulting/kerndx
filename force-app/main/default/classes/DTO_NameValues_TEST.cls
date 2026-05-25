// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Test the behaviour of Shared DTO class for name value pairs
 *
 * @see DTO_NameValues
 *
 * @author Jason van Beukering
 *
 * @group Data Transfer Objects
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class DTO_NameValues_TEST
{
	/**
	 * @description Tests that the "exists" methods work as expected
	 *
	 * @see DTO_NameValues.exists
	 */
	@IsTest
	private static void exists()
	{
		String key = UTIL_Random.randomName();

		Map<String, String> nameValueMap = new Map<String, String>
		{
				key => UTIL_String.EMPTY,
				UTIL_Random.randomName() => UTIL_Random.randomName()

		};

		Test.startTest();

		DTO_NameValues dtoNameValues = new DTO_NameValues(nameValueMap);
		Boolean exists = dtoNameValues.exists(key);
		Boolean existsNonBlank = dtoNameValues.exists(key, true);

		Test.stopTest();

		Assert.areEqual(nameValueMap.size(), dtoNameValues.size, 'DTO not initialised correctly');
		Assert.isTrue(exists, 'Key should be reported as exists.');
		Assert.isFalse(existsNonBlank, 'Key should not be reported as existing.');
	}

	/**
	 * @description Tests that the "get" methods work as expected
	 *
	 * @see DTO_NameValues.get
	 */
	@IsTest
	private static void get()
	{
		String key = UTIL_Random.randomName();
		String value = UTIL_Random.randomName();

		DTO_NameValues dtoNameValues = new DTO_NameValues(key + UTIL_String.EQUALS + value);

		Test.startTest();

		String foundValue = dtoNameValues.get(key);

		Test.stopTest();

		Assert.areEqual(value, foundValue, 'Item value was not retrieved correctly');
	}

	/**
	 * @description Tests that the "allExists" methods work as expected
	 *
	 * @see DTO_NameValues.allExists
	 */
	@IsTest
	private static void allExists()
	{
		String key1 = UTIL_Random.randomName();
		String key2 = UTIL_Random.randomName();

		Map<String, String> nameValueMap = new Map<String, String>
		{
				key1 => UTIL_String.EMPTY,
				key2 => UTIL_String.EMPTY

		};

		DTO_NameValues dtoNameValues = new DTO_NameValues(nameValueMap);
		Set<String> keys = new Set<String> {key1, key2};

		Test.startTest();

		Boolean exists = dtoNameValues.allExists(keys);
		Boolean existsNonBlank = dtoNameValues.allExists(keys, true);

		Test.stopTest();

		Assert.isTrue(exists, 'Key should be reported as exists.');
		Assert.isFalse(existsNonBlank, 'Key should not be reported as existing.');
	}

	/**
	 * @description Tests that the "names" methods work as expected
	 *
	 * @see DTO_NameValues.names
	 */
	@IsTest
	private static void names()
	{
		DTO_NameValues dtoNameValues = new DTO_NameValues();

		String key1 = UTIL_Random.randomName();
		String key2 = UTIL_Random.randomName();

		dtoNameValues.add(key1, UTIL_String.EMPTY);
		dtoNameValues.add(key2, UTIL_String.EMPTY);

		Test.startTest();

		Set<String> names = dtoNameValues.names;

		Test.stopTest();

		Set<String> keys = new Set<String> {key1, key2};

		Assert.areEqual(keys, names, 'Names property is not returning valid items.');
	}

	/**
	 * @description Tests that the "values" methods work as expected
	 *
	 * @see DTO_NameValues.values
	 */
	@IsTest
	private static void values()
	{
		DTO_NameValues dtoNameValues = new DTO_NameValues();

		String value1 = UTIL_Random.randomName();
		String value2 = UTIL_Random.randomName();

		dtoNameValues.add(UTIL_Random.randomName(), value1);
		dtoNameValues.add(UTIL_Random.randomName(), value2);

		Test.startTest();

		List<String> foundValues = dtoNameValues.values;

		Test.stopTest();

		List<String> originalValues = new List<String> {value1, value2};

		Assert.areEqual(originalValues, foundValues, 'Values property is not returning valid items.');
	}

	/**
	 * @description Checks that the equals method is working correctly
	 *
	 * @see DTO_Base.equals
	 * @see DTO_Base.hashCode
	 */
	@IsTest
	private static void equals()
	{
		Map<String, String> nameValueMap = new Map<String, String>
		{
				UTIL_Random.randomName() => UTIL_Random.randomName(),
				UTIL_Random.randomName() => UTIL_Random.randomName()

		};

		DTO_NameValues dto1 = new DTO_NameValues(nameValueMap);
		DTO_NameValues dto2 = new DTO_NameValues(nameValueMap);

		Test.startTest();

		Boolean isEqual = dto1 == dto2;

		Map<DTO_NameValues, String> dtoMap = new Map<DTO_NameValues, String>
		{
				dto1 => 'hello',
				dto2 => 'world'
		};

		Test.stopTest();

		Assert.isTrue(isEqual, 'Objects not should be considered equal');
		Assert.areEqual('world', dtoMap.get(dto1), 'Key not considered equal');
	}

	/**
	 * @description Tests that the "deserialization" methods work as expected
	 *
	 * @see DTO_Base.deserialize
	 */
	@IsTest
	private static void deserialization()
	{
		final String name = 'hello';
		final String value = 'world';

		final String nameValuesJson = '{"nameValueMap":{"' + name + '":"' + value + '"}}';

		DTO_NameValues dtoNameValues = new DTO_NameValues();

		Test.startTest();

		dtoNameValues = (DTO_NameValues)dtoNameValues.deserialize(nameValuesJson);

		Test.stopTest();

		Assert.areEqual(value, dtoNameValues.get(name), 'Object did not deserialize correctly');
	}

	/**
	 * @description Tests that the "toParameterString" methods work as expected
	 *
	 * @see DTO_NameValues.toParameterString
	 */
	@IsTest
	private static void toParameterString()
	{
		final String nameValues = 'paramName1=paramValue1,paramName2=paramValue2';

		DTO_NameValues dtoNameValues = new DTO_NameValues(nameValues);

		Test.startTest();

		String nameValueString = dtoNameValues.toParameterString();

		Test.stopTest();

		Assert.areEqual(nameValues, nameValueString, 'Name values not generated correctly');
	}
}