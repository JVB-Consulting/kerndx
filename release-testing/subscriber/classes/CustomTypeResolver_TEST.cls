// SPDX-License-Identifier: Apache-2.0
/**
 * @description Proves that CustomTypeResolver finds a class however its name is written, and hands a name it cannot find
 * to the next resolver. Every class name comes from the class itself, never from typed-out text, so each test follows the
 * org it runs in: where the framework is installed as a package, its class names carry the "kern." namespace, and the two
 * tests that look up a framework class prove the namespaced shapes; on an org with no namespace the same two tests look
 * up the plain names.
 *
 * @see CustomTypeResolver
 *
 * @author your.name@company.com
 *
 * @group Utilities
 *
 * @date October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=true)
private class CustomTypeResolver_TEST
{
	/**
	 * @description The start of a class name no class has. A class name must begin with a letter, so the random part
	 * goes after it.
	 */
	private static final String UNKNOWN_NAME_START = 'Missing';
	/**
	 * @description How many random letters and digits follow UNKNOWN_NAME_START in a class name no class has.
	 */
	private static final Integer UNKNOWN_NAME_RANDOM_LENGTH = 24;

	/**
	 * @description A class written with no namespace and no outer class is found: the resolver class finds itself.
	 */
	@IsTest
	private static void shouldFindAClassNamedWithoutANamespace()
	{
		Type result = new CustomTypeResolver().resolveType(CustomTypeResolver.class.getName());

		Assert.areEqual(CustomTypeResolver.class, result, 'Expected CustomTypeResolver, got ' + result);
	}

	/**
	 * @description A framework class written with its namespace in front ("kern.UTIL_System" where the framework is a
	 * package) is found. Splitting such a name at its first dot and keeping the namespace in both halves finds nothing.
	 */
	@IsTest
	private static void shouldFindAClassNamedWithItsNamespace()
	{
		Type result = new CustomTypeResolver().resolveType(kern.UTIL_System.class.getName());

		Assert.areEqual(kern.UTIL_System.class, result, 'Expected UTIL_System, got ' + result);
	}

	/**
	 * @description An inner class written after its outer class ("CustomTypeResolver_TEST.NextResolver") is found. A
	 * lookup that reads the outer class as a namespace finds nothing.
	 */
	@IsTest
	private static void shouldFindAnInnerClassNamedWithItsOuterClass()
	{
		Type result = new CustomTypeResolver().resolveType(NextResolver.class.getName());

		Assert.areEqual(NextResolver.class, result, 'Expected CustomTypeResolver_TEST.NextResolver, got ' + result);
	}

	/**
	 * @description A framework inner class written with its namespace and its outer class
	 * ("kern.UTIL_TypeResolver.BaseClassResolver" where the framework is a package) is found.
	 */
	@IsTest
	private static void shouldFindAnInnerClassNamedWithItsNamespaceAndOuterClass()
	{
		Type result = new CustomTypeResolver().resolveType(kern.UTIL_TypeResolver.BaseClassResolver.class.getName());

		Assert.areEqual(kern.UTIL_TypeResolver.BaseClassResolver.class, result, 'Expected UTIL_TypeResolver.BaseClassResolver, got ' + result);
	}

	/**
	 * @description A name no class has goes to the next resolver in line, once, and its answer is the resolver's answer.
	 */
	@IsTest
	private static void shouldAskTheNextResolverWhenNoClassMatches()
	{
		String unknownName = buildUnknownClassName();
		NextResolver next = new NextResolver();
		kern.UTIL_TypeResolver.INT_ClassTypeResolver resolver = new CustomTypeResolver();
		resolver.setNext(next);

		Type result = resolver.resolveType(unknownName);

		Assert.areEqual(NextResolver.class, result, 'Expected the next resolver\'s answer, got ' + result);
		Assert.areEqual(new List<String> {unknownName}, next.askedNames, 'Expected the next resolver to be asked once, for the unknown name');
	}

	/**
	 * @description A name this org's code has is answered here, and the next resolver in line is never asked.
	 */
	@IsTest
	private static void shouldNotAskTheNextResolverWhenAClassMatches()
	{
		NextResolver next = new NextResolver();
		kern.UTIL_TypeResolver.INT_ClassTypeResolver resolver = new CustomTypeResolver();
		resolver.setNext(next);

		Type result = resolver.resolveType(CustomTypeResolver.class.getName());

		Assert.areEqual(CustomTypeResolver.class, result, 'Expected CustomTypeResolver, got ' + result);
		Assert.areEqual(0, next.askedNames.size(), 'Expected the next resolver not to be asked, got ' + next.askedNames);
	}

	/**
	 * @description With no resolver after it, a name no class has gives null rather than an error.
	 */
	@IsTest
	private static void shouldReturnNullWhenNoClassMatches()
	{
		Type result = new CustomTypeResolver().resolveType(buildUnknownClassName());

		Assert.isNull(result, 'Expected null for a name no class has, got ' + result);
	}

	/**
	 * @description With no resolver after it, a missing name gives null rather than an error: the platform's lookup
	 * fails on a null name, so the resolver does not make one.
	 */
	@IsTest
	private static void shouldReturnNullForAMissingName()
	{
		Type result = new CustomTypeResolver().resolveType(null);

		Assert.isNull(result, 'Expected null for a missing name, got ' + result);
	}

	/**
	 * @description Builds a class name that no class has.
	 *
	 * @return The name.
	 */
	private static String buildUnknownClassName()
	{
		return UNKNOWN_NAME_START + kern.UTIL_Random.randomAlphanumeric(UNKNOWN_NAME_RANDOM_LENGTH);
	}

	/**
	 * @description A stand-in for the next resolver in line. It records every name it is asked for and answers with its
	 * own type, so a test can tell its answer from CustomTypeResolver's.
	 */
	public class NextResolver implements kern.UTIL_TypeResolver.INT_ClassTypeResolver
	{
		/**
		 * @description The names this resolver was asked for, in the order they came.
		 */
		public final List<String> askedNames = new List<String>();

		/**
		 * @description Records the name and answers with this class's own type.
		 *
		 * @param typeName The name of the class to find.
		 *
		 * @return The type of NextResolver, whatever the name.
		 */
		public Type resolveType(String typeName)
		{
			askedNames.add(typeName);
			return NextResolver.class;
		}

		/**
		 * @description Accepts a resolver to follow this one. This stand-in never passes a name on, so it keeps nothing.
		 *
		 * @param nextTypeResolver The resolver that would follow this one.
		 *
		 * @return The resolver it was given.
		 */
		public kern.UTIL_TypeResolver.INT_ClassTypeResolver setNext(kern.UTIL_TypeResolver.INT_ClassTypeResolver nextTypeResolver)
		{
			return nextTypeResolver;
		}
	}
}
