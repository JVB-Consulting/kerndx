// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Subscriber proof for `UTIL_TypeResolver` edge scenarios deferred from
 * `release-testing/scripts/section-62-edge-type-resolver.apex` (the extended-load spec §6.15, Task 1.16).
 * Anonymous Apex cannot perform CMDT DML to inject test resolver records, and the framework's
 * `@TestVisible buildCustomResolverChain(List<ClassTypeResolver__mdt>)` seam is package-private
 * so it is not callable from subscriber namespace either. This class works around both
 * constraints by mocking the `SEL_ClassTypeResolver` SOQL query via `kern.QRY_Builder.setMock`.
 *
 * Mock registration must occur in the same `@IsTest` method before any framework code triggers
 * `kern.UTIL_TypeResolver.customResolver` initialisation — each `@IsTest` method gets fresh
 * static state, so this contract is honoured by simply doing the mock registration first.
 *
 * Scenarios covered:
 *
 * 1. `shouldThrowWhenResolvedTypeDoesNotImplementExpectedInterface` — calls
 *    `kern.UTIL_System.getTypeForClassName('CustomTypeResolver', Schedulable.class)` and
 *    expects `TypeException` (not `IllegalArgumentException`). Section 62a documented the
 *    spec correction: `IllegalArgumentException` is only thrown when the class cannot be
 *    found at all; `TypeException` is thrown by the type-assignability assertion.
 * 2. `shouldTolerateTiesInResolverChain` — registers two mocked `ClassTypeResolver__mdt`
 *    records both pointing at `CustomTypeResolver` at the same `Order__c`. The framework
 *    currently has no secondary tiebreaker (spec deviation acknowledged in section-62b);
 *    this test asserts the observable contract — chain construction tolerates ties without
 *    throwing and resolution remains stable.
 * 3. `shouldResolveBareNameSubscriberFirst` — verifies that the subscriber-first lookup
 *    returns the no-namespace class for `'CustomTypeResolver'`.
 * 4. `shouldFallThroughOnThrowingResolver` — registers a mocked `ClassTypeResolver__mdt`
 *    pointing at the `ThrowingClassTypeResolver` fixture. The framework's
 *    `PackageClassResolver.resolveType` delegates via `nextResolver?.resolveType(typeName)`
 *    with no `try/catch`, so the exception must propagate to the caller (current contract
 *    per section-62 `§6.11 #4` finding — framework does NOT catch).
 *
 * @see kern.UTIL_TypeResolver
 * @see kern.UTIL_System
 * @see CustomTypeResolver
 * @see ThrowingClassTypeResolver
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class Subscriber_TypeResolver_TEST
{
	/**
	 * @description Subscriber resolver class deployed alongside the framework. Used as the
	 * `ClassName__c` value on injected `ClassTypeResolver__mdt` mocks because it is known to
	 * implement `kern.UTIL_TypeResolver.INT_ClassTypeResolver` (extends `BaseClassResolver`).
	 */
	private static final String CUSTOM_RESOLVER = 'CustomTypeResolver';

	/**
	 * @description Subscriber-side throwing resolver fixture. `ThrowingClassTypeResolver.cls`
	 * implements `INT_ClassTypeResolver` directly and unconditionally throws from
	 * `resolveType(String)`.
	 */
	private static final String THROWING_RESOLVER = 'ThrowingClassTypeResolver';

	/**
	 * @description A class name that no resolver in the chain will recognise — used to drive
	 * the chain to the throwing resolver in scenario 4.
	 */
	private static final String UNKNOWN_CLASS = 'NoSuchClass_TypeResolverTest_DefinitelyNotDeployed';

	/**
	 * @description `Order__c` value used on injected `ClassTypeResolver__mdt` mocks. A single
	 * constant avoids magic-number scatter across multiple test methods.
	 */
	private static final Decimal RESOLVER_ORDER = 1.0;

	/**
	 * @description Calling `kern.UTIL_System.getTypeForClassName` with an `expectedType` that
	 * the resolved class does not implement must throw `TypeException` (NOT
	 * `IllegalArgumentException`). `IllegalArgumentException` is only thrown when the class
	 * cannot be found at all.
	 */
	@IsTest
	private static void shouldThrowWhenResolvedTypeDoesNotImplementExpectedInterface()
	{
		Boolean threw = false;
		String exceptionTypeName = null;
		String exceptionMessage = null;

		Test.startTest();

		try
		{
			kern.UTIL_System.getTypeForClassName(CUSTOM_RESOLVER, Schedulable.class);
		}
		catch(Exception resolverError)
		{
			threw = true;
			exceptionTypeName = resolverError.getTypeName();
			exceptionMessage = resolverError.getMessage();
		}

		Test.stopTest();

		Assert.isTrue(threw, 'getTypeForClassName(name, Schedulable.class) should throw when the resolved class does not implement Schedulable');
		Assert.isNotNull(exceptionTypeName, 'Caught exception should have a non-null type name');
		Assert.isTrue(exceptionTypeName.containsIgnoreCase('TypeException'), 'Exception type should be TypeException (not IllegalArgumentException — that is reserved for class-not-found). Got: ' + exceptionTypeName);
		Assert.isNotNull(exceptionMessage, 'Caught TypeException should have a non-null message');
		Assert.isTrue(exceptionMessage.containsIgnoreCase('not assignable'), 'TypeException message should contain "not assignable". Got: ' + exceptionMessage);
		Assert.isTrue(exceptionMessage.containsIgnoreCase('Schedulable'), 'TypeException message should name the expected type "Schedulable". Got: ' + exceptionMessage);
		Assert.isTrue(exceptionMessage.containsIgnoreCase(CUSTOM_RESOLVER), 'TypeException message should name the actual resolved type "' + CUSTOM_RESOLVER + '". Got: ' + exceptionMessage);
	}

	/**
	 * @description When two `ClassTypeResolver__mdt` records share the same `Order__c`, the
	 * framework currently has no secondary tiebreaker (spec deviation per section-62b). The
	 * observable contract is: chain construction tolerates ties without throwing and resolution
	 * remains stable — `findTypeForClassName` continues to resolve known classes correctly
	 * (subscriber fallback to package classes still works). Both mocked records point at the
	 * same valid resolver so the chain has two functionally-identical links.
	 */
	@IsTest
	private static void shouldTolerateTiesInResolverChain()
	{
		List<SObject> tiedResolvers = new List<SObject>
		{
			(SObject)kern.TST_Mock.of(kern__ClassTypeResolver__mdt.SObjectType)
					.withOverride(kern__ClassTypeResolver__mdt.DeveloperName, 'TiedResolverA')
					.withOverride(kern__ClassTypeResolver__mdt.kern__ClassName__c, CUSTOM_RESOLVER)
					.withOverride(kern__ClassTypeResolver__mdt.kern__Order__c, RESOLVER_ORDER)
					.build(),
			(SObject)kern.TST_Mock.of(kern__ClassTypeResolver__mdt.SObjectType)
					.withOverride(kern__ClassTypeResolver__mdt.DeveloperName, 'TiedResolverB')
					.withOverride(kern__ClassTypeResolver__mdt.kern__ClassName__c, CUSTOM_RESOLVER)
					.withOverride(kern__ClassTypeResolver__mdt.kern__Order__c, RESOLVER_ORDER)
					.build()
		};
		kern.QRY_Builder.setMock(kern__ClassTypeResolver__mdt.SObjectType, tiedResolvers);

		Test.startTest();

		Type firstResolution = kern.UTIL_System.findTypeForClassName(CUSTOM_RESOLVER);
		Type secondResolution = kern.UTIL_System.findTypeForClassName(CUSTOM_RESOLVER);

		Test.stopTest();

		Assert.isNotNull(firstResolution, 'Chain construction should tolerate two records at the same Order__c without throwing');
		Assert.isNotNull(secondResolution, 'Repeated resolution should remain stable when the chain contains tied records');
		Assert.areEqual(firstResolution.getName(), secondResolution.getName(), 'Repeated resolution of the same class name should return the same Type when ties are present');
		Assert.isTrue(firstResolution.getName().containsIgnoreCase(CUSTOM_RESOLVER), 'Resolved Type name should still contain "' + CUSTOM_RESOLVER + '". Got: ' + firstResolution.getName());
	}

	/**
	 * @description The framework's `getTypeForClassName` tries `Type.forName('', name)` before
	 * `Type.forName('kern', name)` — a subscriber class with no namespace prefix wins over a
	 * potential package class with the same bare name. `CustomTypeResolver` exists only in
	 * the subscriber org; the resolved Type must NOT be `kern.`-prefixed.
	 */
	@IsTest
	private static void shouldResolveBareNameSubscriberFirst()
	{
		Test.startTest();

		Type resolved = kern.UTIL_System.getTypeForClassName(CUSTOM_RESOLVER);

		Test.stopTest();

		Assert.isNotNull(resolved, 'Subscriber class "' + CUSTOM_RESOLVER + '" should resolve to a non-null Type');
		Assert.isNotNull(resolved.getName(), 'Resolved Type should expose a non-null getName()');
		Assert.isTrue(resolved.getName().containsIgnoreCase(CUSTOM_RESOLVER), 'Resolved Type name should contain "' + CUSTOM_RESOLVER + '". Got: ' + resolved.getName());
		Assert.isFalse(resolved.getName().startsWithIgnoreCase('kern.'), 'Subscriber-first lookup should resolve the no-namespace class. Got: ' + resolved.getName());
	}

	/**
	 * @description When a custom resolver throws from `resolveType`, the framework currently
	 * has no `try/catch` guard in `PackageClassResolver` — the exception propagates to the
	 * caller. Mock-injecting a `ClassTypeResolver__mdt` record pointing at
	 * `ThrowingClassTypeResolver` builds a chain whose tail throws when asked to resolve an
	 * unknown class name. `findTypeForClassName` (the non-throwing variant) is used so the
	 * `IllegalArgumentException` raised by the package's "class not found" path does not mask
	 * the propagated `IllegalArgumentException` from the throwing resolver.
	 */
	@IsTest
	private static void shouldFallThroughOnThrowingResolver()
	{
		List<SObject> throwingChain = new List<SObject>
		{
			(SObject)kern.TST_Mock.of(kern__ClassTypeResolver__mdt.SObjectType)
					.withOverride(kern__ClassTypeResolver__mdt.DeveloperName, 'ThrowingResolverInjected')
					.withOverride(kern__ClassTypeResolver__mdt.kern__ClassName__c, THROWING_RESOLVER)
					.withOverride(kern__ClassTypeResolver__mdt.kern__Order__c, RESOLVER_ORDER)
					.build()
		};
		kern.QRY_Builder.setMock(kern__ClassTypeResolver__mdt.SObjectType, throwingChain);

		Boolean propagated = false;
		String exceptionMessage = null;

		Test.startTest();

		try
		{
			kern.UTIL_System.findTypeForClassName(UNKNOWN_CLASS);
		}
		catch(Exception thrown)
		{
			propagated = true;
			exceptionMessage = thrown.getMessage();
		}

		Test.stopTest();

		Assert.isTrue(propagated, 'A throwing resolver should propagate to the caller — framework does NOT catch resolver exceptions (current contract per the extended-load spec §6.11 #4)');
		Assert.isNotNull(exceptionMessage, 'Propagated exception should have a non-null message');
		Assert.isTrue(exceptionMessage.contains(ThrowingClassTypeResolver.SENTINEL_MESSAGE), 'Propagated exception should carry the throwing resolver sentinel message. Got: ' + exceptionMessage);
	}
}
