// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests the behavior of the {@link DTO_Base} class.
 *
 * @see DTO_Base
 *
 * @author Jason van Beukering
 *
 * @group Data Transfer Objects
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class DTO_Base_TEST
{
	/**
	 * @description Tests that serialize returns an empty string by default.
	 *
	 * @see DTO_Base.serialize
	 */
	@IsTest
	private static void shouldReturnEmptyStringWhenSerialized()
	{
		DTO_Base instance = new DTO_Base();

		Test.startTest();

		String result = instance.serialize();

		Test.stopTest();

		Assert.areEqual(UTIL_String.EMPTY, result, 'Base serialize should return empty string');
	}

	/**
	 * @description Tests that deserialize returns the same instance by default.
	 *
	 * @see DTO_Base.deserialize
	 */
	@IsTest
	private static void shouldReturnSameInstanceWhenDeserialized()
	{
		DTO_Base instance = new DTO_Base();

		Test.startTest();

		DTO_Base result = instance.deserialize('{}');

		Test.stopTest();

		Assert.areEqual(instance, result, 'Base deserialize should return same instance');
	}

	/**
	 * @description Tests that two DTO_Base instances with the same serialized output are equal.
	 *
	 * @see DTO_Base.equals
	 */
	@IsTest
	private static void shouldBeEqualWhenSerializationMatches()
	{
		DTO_Base first = new DTO_Base();
		DTO_Base second = new DTO_Base();

		Test.startTest();

		Boolean result = first.equals(second);

		Test.stopTest();

		Assert.isTrue(result, 'Two default DTO_Base instances should be equal');
	}

	/**
	 * @description Tests that equals returns false when compared to a non-DTO object.
	 *
	 * @see DTO_Base.equals
	 */
	@IsTest
	private static void shouldNotBeEqualToNonDtoObject()
	{
		DTO_Base instance = new DTO_Base();

		Test.startTest();

		Boolean result = instance.equals('not a dto');

		Test.stopTest();

		Assert.isFalse(result, 'Should not be equal to a non-DTO object');
	}

	/**
	 * @description Tests that hashCode returns a consistent value for the same instance.
	 *
	 * @see DTO_Base.hashCode
	 */
	@IsTest
	private static void shouldReturnConsistentHashCode()
	{
		DTO_Base instance = new DTO_Base();

		Test.startTest();

		Integer first = instance.hashCode();
		Integer second = instance.hashCode();

		Test.stopTest();

		Assert.areEqual(first, second, 'Hash code should be consistent across calls');
	}

	/**
	 * @description Tests that populate with Id does not throw.
	 *
	 * @see DTO_Base.populate
	 */
	@IsTest
	private static void shouldNotThrowWhenPopulatedWithId()
	{
		DTO_Base instance = new DTO_Base();

		Test.startTest();

		instance.populate(UserInfo.getUserId());

		Test.stopTest();

		Assert.isNotNull(instance, 'Instance should remain valid after populate');
	}

	/**
	 * @description Tests that populate with Id and DTO_NameValues delegates to single-parameter overload.
	 *
	 * @see DTO_Base.populate
	 */
	@IsTest
	private static void shouldNotThrowWhenPopulatedWithIdAndParameters()
	{
		DTO_Base instance = new DTO_Base();

		Test.startTest();

		instance.populate(UserInfo.getUserId(), new DTO_NameValues());

		Test.stopTest();

		Assert.isNotNull(instance, 'Instance should remain valid after populate with parameters');
	}

	/**
	 * @description Tests that transform does not throw when called with another DTO_Base.
	 *
	 * @see DTO_Base.transform
	 */
	@IsTest
	private static void shouldNotThrowWhenTransformed()
	{
		DTO_Base instance = new DTO_Base();
		DTO_Base input = new DTO_Base();

		Test.startTest();

		instance.transform(input);

		Test.stopTest();

		Assert.isNotNull(instance, 'Instance should remain valid after transform');
	}
}