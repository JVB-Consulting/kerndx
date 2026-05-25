// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests the behaviour of `DTO_JsonBase` — JSON serialise / deserialise helpers
 * and the `getObjectType()` runtime-type resolution that drives them.
 *
 * @see DTO_JsonBase
 *
 * @author Jason van Beukering
 *
 * @group Data Transfer Objects
 *
 * @date April 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class DTO_JsonBase_TEST
{
	/**
	 * @description Inner DTO whose runtime name resolves against the managed package — used to
	 * exercise the happy path of `getObjectType()`, `deserialize()`, and `serialize()`.
	 */
	@JsonAccess(Serializable='always' Deserializable='always')
	public class TestableDto extends DTO_JsonBase
	{
		/**
		 * @description Arbitrary field used to prove round-trip serialisation.
		 */
		public String value;

		/**
		 * @description Exposes the protected `getObjectType()` to the test class.
		 *
		 * @return The resolved runtime `Type`.
		 */
		public Type exposeGetObjectType()
		{
			return this.getObjectType();
		}
	}

	/**
	 * @description `serialize()` should concatenate the base empty prefix with a pretty-printed
	 * JSON payload whose null fields are suppressed.
	 *
	 * @see DTO_JsonBase.serialize
	 */
	@IsTest
	private static void shouldSerialiseInstanceToJsonPayload()
	{
		TestableDto dto = new TestableDto();
		dto.value = 'hello';

		Test.startTest();

		String jsonString = dto.serialize();

		Test.stopTest();

		Assert.isTrue(jsonString.contains('"value" : "hello"'), 'Serialised payload should include the value field');
	}

	/**
	 * @description `deserialize()` should return a populated DTO instance when the runtime type
	 * resolves cleanly.
	 *
	 * @see DTO_JsonBase.deserialize
	 */
	@IsTest
	private static void shouldDeserialiseJsonPayloadIntoTypedInstance()
	{
		TestableDto dto = new TestableDto();

		Test.startTest();

		TestableDto result = (TestableDto)dto.deserialize('{"value":"world"}');

		Test.stopTest();

		Assert.areEqual('world', result.value, 'Deserialised DTO should carry the JSON value');
	}

	/**
	 * @description `getObjectType()` should return the resolved `Type` when the runtime class name
	 * is resolvable via `UTIL_System.getTypeForClassName`.
	 *
	 * @see DTO_JsonBase.getObjectType
	 */
	@IsTest
	private static void shouldResolveRuntimeTypeForAccessibleDto()
	{
		TestableDto dto = new TestableDto();

		Test.startTest();

		Type resolved = dto.exposeGetObjectType();

		Test.stopTest();

		Assert.isNotNull(resolved, 'Accessible DTO should resolve to a non-null Type');
	}

	/**
	 * @description `getObjectType()` should re-throw an annotated exception (with a hint pointing
	 * subscribers at `global` access or a `getObjectType()` override) when the runtime class name
	 * cannot be resolved — covering the catch branch at lines 53-58.
	 *
	 * Uses an instance whose runtime type returns a non-resolvable name: a DTO constructed
	 * inside an anonymous sObject-like helper that `UTIL_System.getTypeForClassName` cannot
	 * resolve because the synthetic name does not correspond to an actual class.
	 *
	 * @see DTO_JsonBase.getObjectType
	 */
	@IsTest
	private static void shouldAnnotateErrorWhenRuntimeTypeIsUnresolvable()
	{
		Test.startTest();

		try
		{
			new UnresolvableDto().exposeGetObjectType();
			Assert.fail('Should throw when runtime type cannot be resolved');
		}
		catch(Exception error)
		{
			Assert.isTrue(error.getMessage().contains('getObjectType()'), 'Thrown error should include the framework-added hint mentioning getObjectType()');
		}

		Test.stopTest();
	}

	/**
	 * @description Private-scope DTO whose runtime class name `DTO_JsonBase_TEST.UnresolvableDto`
	 * is visible to the test class but cannot be resolved by `UTIL_System.getTypeForClassName`
	 * via `Type.forName` from the managed-package context at runtime — triggering the catch
	 * branch in `DTO_JsonBase.getObjectType()`.
	 */
	@JsonAccess(Serializable='always' Deserializable='always')
	private class UnresolvableDto extends DTO_JsonBase
	{
		/**
		 * @description Exposes the protected `getObjectType()` to the test class so the catch
		 * branch is reachable from a test method.
		 *
		 * @return The resolved runtime `Type` — in practice unreachable for this class.
		 */
		public Type exposeGetObjectType()
		{
			return this.getObjectType();
		}
	}
}