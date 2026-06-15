// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests the [UTIL_TypeResolver] class for resolving class types from names.
 *
 * @see UTIL_TypeResolver
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date March 2025, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class UTIL_TypeResolver_TEST
{
	private static final String MSG_TYPE_MISMATCH = 'Resolved type should match expected class';
	private static final String MSG_TYPE_NOT_RESOLVED = 'Type should be resolved';

	/**
	 * @description The class name recognized by the SelectiveResolver for chaining tests.
	 */
	private static final String TEST_KNOWN_CLASS = 'MyPackagePrivateClass';

	/**
	 * @description Error message thrown by ThrowingResolver and asserted on by the
	 * exception-safety codifying test. Lives on the outer class because Apex disallows
	 * static fields on inner classes.
	 */
	private static final String THROWING_RESOLVER_ERROR = 'Custom resolver does not implement exception-safety';

	/**
	 * @description Tests type resolution using a custom resolver for a private class.
	 *
	 * @see UTIL_TypeResolver.getClassResolver
	 */
	@IsTest
	private static void resolveWithCustomResolver()
	{
		UTIL_TypeResolver.customResolver = (UTIL_TypeResolver.INT_ClassTypeResolver)new CustomResolver();
		UTIL_TypeResolver.INT_ClassTypeResolver typeResolver = UTIL_TypeResolver.getClassResolver();

		Test.startTest();

		Type resolvedType = typeResolver.resolveType(null);

		Test.stopTest();

		Assert.isNotNull(resolvedType, MSG_TYPE_NOT_RESOLVED);
		Assert.areEqual(MyPackagePrivateClass.class, resolvedType, MSG_TYPE_MISMATCH);
	}

	/**
	 * @description Tests that package classes resolve when no local override exists.
	 * Verifies Subscriber-First resolution falls back to package namespace correctly.
	 *
	 * @see UTIL_TypeResolver.getClassResolver
	 */
	@IsTest
	private static void shouldFallbackToPackageClass()
	{
		UTIL_TypeResolver.INT_ClassTypeResolver typeResolver = UTIL_TypeResolver.getClassResolver();

		Test.startTest();

		Type resolvedType = typeResolver.resolveType('UTIL_String');

		Test.stopTest();

		Assert.isNotNull(resolvedType, MSG_TYPE_NOT_RESOLVED);
		Assert.areEqual(UTIL_String.class, resolvedType, MSG_TYPE_MISMATCH);
	}

	/**
	 * @description Tests that nested class resolution works with Subscriber-First approach.
	 *
	 * @see UTIL_TypeResolver.getClassResolver
	 */
	@IsTest
	private static void shouldResolveNestedPackageClass()
	{
		UTIL_TypeResolver.INT_ClassTypeResolver typeResolver = UTIL_TypeResolver.getClassResolver();

		Test.startTest();

		Type resolvedType = typeResolver.resolveType('UTIL_TypeResolver.BaseClassResolver');

		Test.stopTest();

		Assert.isNotNull(resolvedType, MSG_TYPE_NOT_RESOLVED);
		Assert.areEqual(UTIL_TypeResolver.BaseClassResolver.class, resolvedType, MSG_TYPE_MISMATCH);
	}

	/**
	 * @description Tests that multiple resolvers are chained correctly, with the first resolver
	 * handling known classes and delegating unrecognized classes to the next resolver in the chain.
	 *
	 * @see UTIL_TypeResolver.chainResolvers
	 */
	@IsTest
	private static void shouldChainMultipleResolvers()
	{
		List<UTIL_TypeResolver.INT_ClassTypeResolver> resolvers = new List<UTIL_TypeResolver.INT_ClassTypeResolver>
		{
				new SelectiveResolver(),
				new FallbackResolver()
		};

		Test.startTest();

		UTIL_TypeResolver.INT_ClassTypeResolver chain = UTIL_TypeResolver.chainResolvers(resolvers);

		Test.stopTest();

		Assert.areEqual(MyPackagePrivateClass.class, chain.resolveType(TEST_KNOWN_CLASS), 'First resolver should handle its known class');
		Assert.areEqual(FallbackClass.class, chain.resolveType('AnythingElse'), 'Second resolver should handle unrecognized classes');
	}

	/**
	 * @description Codifies the exception-safety contract on `INT_ClassTypeResolver`. A custom
	 * resolver that throws does NOT fall through to the next resolver in the chain — the
	 * exception propagates to the caller. Implementations must return null (not throw) to
	 * signal "I cannot resolve this; try the next resolver."
	 *
	 * @see UTIL_TypeResolver.INT_ClassTypeResolver
	 */
	@IsTest
	private static void shouldPropagateExceptionFromCustomResolver()
	{
		UTIL_TypeResolver.customResolver = (UTIL_TypeResolver.INT_ClassTypeResolver)new ThrowingResolver();
		UTIL_TypeResolver.INT_ClassTypeResolver chain = UTIL_TypeResolver.getClassResolver();

		Test.startTest();

		try
		{
			chain.resolveType('NameThatPackageResolverCannotFind');
			Assert.fail('Should propagate UTIL_Exceptions.IllegalStateException from the throwing resolver');
		}
		catch(UTIL_Exceptions.IllegalStateException error)
		{
			Assert.areEqual(THROWING_RESOLVER_ERROR, error.getMessage(), 'Should surface the resolver\'s own message verbatim');
		}

		Test.stopTest();
	}

	/**
	 * @description Tests that chainResolvers returns null for an empty list.
	 *
	 * @see UTIL_TypeResolver.chainResolvers
	 */
	@IsTest
	private static void shouldReturnNullForEmptyResolverList()
	{
		Test.startTest();

		UTIL_TypeResolver.INT_ClassTypeResolver chain = UTIL_TypeResolver.chainResolvers
				(
						new List<UTIL_TypeResolver.INT_ClassTypeResolver>()
				);

		Test.stopTest();

		Assert.isNull(chain, 'Empty resolver list should return null');
	}

	/**
	 * @description Custom resolver for testing type resolution of a private class.
	 *
	 * @see UTIL_TypeResolver.BaseClassResolver
	 */
	private class CustomResolver extends UTIL_TypeResolver.BaseClassResolver
	{
		/**
		 * @description Resolves a Type object from a class name.
		 *
		 * @param className The name of the class to resolve
		 *
		 * @return The resolved Type object
		 */
		public override Type resolveType(String className)
		{
			return MyPackagePrivateClass.class;
		}
	}

	/**
	 * @description Resolver that only handles a specific class name and delegates all others to the next resolver.
	 */
	private class SelectiveResolver extends UTIL_TypeResolver.BaseClassResolver
	{
		/**
		 * @description Resolves only the known class name, delegating others to the next resolver in the chain.
		 *
		 * @param className The name of the class to resolve
		 *
		 * @return The resolved Type object, or the result from the next resolver
		 */
		public override Type resolveType(String className)
		{
			if(className == TEST_KNOWN_CLASS)
			{
				return MyPackagePrivateClass.class;
			}

			return nextResolver?.resolveType(className);
		}
	}

	/**
	 * @description Resolver that always throws — used to codify the exception-safety contract:
	 * throws propagate to the caller and are NOT swallowed by the chain.
	 */
	private class ThrowingResolver extends UTIL_TypeResolver.BaseClassResolver
	{
		/**
		 * @description Throws unconditionally to verify chain-propagation behaviour.
		 *
		 * @param className The name of the class to resolve (ignored).
		 *
		 * @return Never returns — always throws.
		 *
		 * @throws UTIL_Exceptions.IllegalStateException Always, with `THROWING_RESOLVER_ERROR`.
		 */
		public override Type resolveType(String className)
		{
			throw new UTIL_Exceptions.IllegalStateException(THROWING_RESOLVER_ERROR);
		}
	}

	/**
	 * @description Fallback resolver that always returns FallbackClass.
	 */
	private class FallbackResolver extends UTIL_TypeResolver.BaseClassResolver
	{
		/**
		 * @description Always resolves to FallbackClass.
		 *
		 * @param className The name of the class to resolve
		 *
		 * @return The FallbackClass type
		 */
		public override Type resolveType(String className)
		{
			return FallbackClass.class;
		}
	}

	/**
	 * @description Private class used to test type resolution.
	 */
	private class MyPackagePrivateClass
	{
	}

	/**
	 * @description Private class used to test fallback resolution in chaining.
	 */
	private class FallbackClass
	{
	}
}