// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests for SEL_ApexClass selector methods.
 *
 * @see SEL_ApexClass
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date March 2026, July 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=true)
private class SEL_ApexClass_TEST
{
	/**
	 * @description A namespace prefix registered in no org, pairing with a real local class name to prove
	 * the dotted lookup filters on the prefix.
	 */
	private static final String UNKNOWN_NAMESPACE_PREFIX = 'NoSuchNamespace';

	/**
	 * @description Tests that findSchedulableClassNames returns known Schedulable classes.
	 */
	@IsTest
	private static void shouldReturnSchedulableClassNames()
	{
		List<String> classNames = new SEL_ApexClass().findSchedulableClassNames();

		Assert.isFalse(classNames.isEmpty(), 'Should return at least one Schedulable class');
		Assert.isTrue(classNames.contains(SCHED_DeactivateUsers.class.getName()), 'Should contain SCHED_DeactivateUsers');
	}

	/**
	 * @description Tests that getFields returns Name and NamespacePrefix.
	 */
	@IsTest
	private static void shouldReturnDefaultFields()
	{
		List<SObjectField> fields = new SEL_ApexClass().getFields();

		Assert.areEqual(2, fields.size(), 'Should return two fields');
		Assert.isTrue(fields.contains(ApexClass.Name), 'Should contain Name field');
		Assert.isTrue(fields.contains(ApexClass.NamespacePrefix), 'Should contain NamespacePrefix field');
	}

	/**
	 * @description Tests that findByQualifiedName resolves this selector's own runtime class name — the
	 * dotted, namespace-qualified form in a namespaced deployment and the undotted form in an unmanaged
	 * one — so the lookup proves itself in whichever shape the deployment produces.
	 */
	@IsTest
	private static void shouldFindApexClassByItsQualifiedName()
	{
		ApexClass foundClass = new SEL_ApexClass().findByQualifiedName(SEL_ApexClass.class.getName());

		Assert.isNotNull(foundClass, 'The selector should find its own ApexClass row by its runtime class name');
	}

	/**
	 * @description Tests that findByQualifiedName treats the text before the dot as a namespace prefix:
	 * pairing an unknown prefix with a local class name that does exist proves the dotted form never
	 * falls back to an unqualified name lookup.
	 */
	@IsTest
	private static void shouldReturnNullForUnknownNamespacePrefix()
	{
		String runtimeClassName = SEL_ApexClass.class.getName();
		String localClassName = runtimeClassName.contains(UTIL_String.DOT) ? runtimeClassName.substringAfterLast(UTIL_String.DOT) : runtimeClassName;

		ApexClass foundClass = new SEL_ApexClass().findByQualifiedName(UNKNOWN_NAMESPACE_PREFIX + UTIL_String.DOT + localClassName);

		Assert.isNull(foundClass, 'An unknown namespace prefix must match nothing, even when the local class name exists');
	}
}