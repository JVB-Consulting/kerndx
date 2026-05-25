// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests the methods in [UTIL_System] for namespace, type resolution, and platform utility functions.
 *
 * @see UTIL_System
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.CyclomaticComplexity,PMD.CognitiveComplexity,PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class UTIL_System_TEST
{
	/**
	 * @description Error message for session ID retrieval failure.
	 */
	private static final String MSG_SESSION_ID_NOT_RETRIEVED = 'Session Id not retrieved';

	/**
	 * @description Error message for API version retrieval failure.
	 */
	private static final String MSG_API_VERSION_NOT_RETRIEVED = 'Api version not retrieved';

	/**
	 * @description Non-existent namespace used in createInterview probes. Chosen so the platform
	 * deterministically raises `TypeException` for every flow lookup.
	 */
	private static final String NONEXISTENT_NAMESPACE = 'kerntest';

	/**
	 * @description Non-existent flow name used in createInterview probes.
	 */
	private static final String NONEXISTENT_FLOW = 'UTIL_System_TEST_FlowDoesNotExist';

	/**
	 * @description Tests retrieving the namespace from a class name.
	 *
	 * @see UTIL_System.getClassNamespace
	 */
	@IsTest
	private static void resolveClassNamespace()
	{
		Test.startTest();

		String namespace = UTIL_System.getClassNamespace('acmelib.SomeClassName.NestedClassName');

		Test.stopTest();

		Assert.areEqual('acmelib', namespace, 'Namespace incorrect');
	}

	/**
	 * @description Tests resolving the running type of a Date instance.
	 *
	 * @see UTIL_System.getRuntimeType
	 */
	@IsTest
	private static void resolveDateRunningType()
	{
		Assert.areEqual(Date.class, UTIL_System.getRuntimeType(Date.today()), 'Invalid Type returned');
	}

	/**
	 * @description Tests resolving the type name of a null instance.
	 *
	 * @see UTIL_System.getRuntimeTypeName
	 */
	@IsTest
	private static void resolveNullRunningTypeName()
	{
		try
		{
			ExampleClass instance = null;
			UTIL_System.getRuntimeTypeName(instance);
			Assert.fail('Exception not thrown as expected');
		}
		catch(NullPointerException e)
		{
			Assert.areEqual('Script-thrown exception', e.getMessage(), 'Incorrect exception raised');
		}
	}

	/**
	 * @description Tests resolving the running type of an instance.
	 *
	 * @see UTIL_System.getRuntimeType
	 */
	@IsTest
	private static void resolveRunningType()
	{
		Assert.areEqual(ExampleClass.class, UTIL_System.getRuntimeType(new ExampleClass()), 'Invalid Type returned');
	}

	/**
	 * @description Tests resolving the type name of an instance.
	 *
	 * @see UTIL_System.getRuntimeTypeName
	 */
	@IsTest
	private static void resolveRunningTypeName()
	{
		String expectedTypeName = UTIL_System.getManagedPackageNamespacePrefix(UTIL_String.DOT) + 'UTIL_System_TEST.ExampleClass';
		Assert.areEqual(expectedTypeName, UTIL_System.getRuntimeTypeName(new ExampleClass()), 'Invalid Type Name returned');
	}

	/**
	 * @description Tests getRuntimeTypeName returns correct type names for all standard primitive types.
	 *
	 * @see UTIL_System.getRuntimeTypeName
	 */
	@IsTest
	private static void getRuntimeTypeNameReturnsPrimitiveTypes()
	{
		Assert.areEqual(Id.class.getName(), UTIL_System.getRuntimeTypeName(UTIL_Random.randomId(Account.SObjectType)), 'Should return Id');
		Assert.areEqual(String.class.getName(), UTIL_System.getRuntimeTypeName('test string'), 'Should return String');
		Assert.areEqual(Boolean.class.getName(), UTIL_System.getRuntimeTypeName(true), 'Should return Boolean');
		Assert.areEqual(Integer.class.getName(), UTIL_System.getRuntimeTypeName(42), 'Should return Integer');
		Assert.areEqual(Long.class.getName(), UTIL_System.getRuntimeTypeName(123456789012345L), 'Should return Long');
		Assert.areEqual(Decimal.class.getName(), UTIL_System.getRuntimeTypeName(Decimal.valueOf('123.45')), 'Should return Decimal');
		// Note: Apex doesn't distinguish Double from Decimal at runtime - Double.valueOf returns Decimal
		Assert.areEqual(Decimal.class.getName(), UTIL_System.getRuntimeTypeName(Double.valueOf(3.14159)), 'Double reports as Decimal');
		Assert.areEqual(Date.class.getName(), UTIL_System.getRuntimeTypeName(Date.today()), 'Should return Date');
		Assert.areEqual(Datetime.class.getName(), UTIL_System.getRuntimeTypeName(Datetime.now()), 'Should return Datetime');
		Assert.areEqual(Time.class.getName(), UTIL_System.getRuntimeTypeName(Time.newInstance(12, 0, 0, 0)), 'Should return Time');
		Assert.areEqual(Blob.class.getName(), UTIL_System.getRuntimeTypeName(Blob.valueOf('test')), 'Should return Blob');
	}

	/**
	 * @description Tests getRuntimeTypeName returns correct type name for SObjects.
	 *
	 * @see UTIL_System.getRuntimeTypeName
	 */
	@IsTest
	private static void getRuntimeTypeNameReturnsSObjectType()
	{
		Foobar__c record = TST_Factory.newFoobarWithName('Test');

		String typeName = UTIL_System.getRuntimeTypeName(record);

		Assert.areEqual(SEL_Foobar.OBJECT_NAME, typeName, 'Should return SObject API name');
	}

	/**
	 * @description Tests getRuntimeTypeName correctly identifies Id values stored in List<Object>.
	 * This verifies the fix for the issue where Ids in List<Object> were incorrectly
	 * reported as Strings via exception message parsing.
	 *
	 * @see UTIL_System.getRuntimeTypeName
	 */
	@IsTest
	private static void getRuntimeTypeNameReturnsIdForIdInListObject()
	{
		Id testId = UTIL_Random.randomId(Account.SObjectType);
		List<Object> values = new List<Object> {testId};

		String typeName = UTIL_System.getRuntimeTypeName(values[0]);

		Assert.areEqual(Id.class.getName(), typeName, 'Should return Id for Id stored in List<Object>');
	}

	/**
	 * @description Tests getRuntimeTypeName returns correct type names for collection types.
	 *
	 * @see UTIL_System.getRuntimeTypeName
	 */
	@IsTest
	private static void getRuntimeTypeNameReturnsCollectionTypes()
	{
		Assert.areEqual('List<String>', UTIL_System.getRuntimeTypeName(new List<String>()), 'Should return List<String>');
		Assert.areEqual('Set<Id>', UTIL_System.getRuntimeTypeName(new Set<Id>()), 'Should return Set<Id>');
		Assert.areEqual('Map<String,Integer>', UTIL_System.getRuntimeTypeName(new Map<String, Integer>()), 'Should return Map<String,Integer>');
	}

	/**
	 * @description Tests getRuntimeTypeName returns correct type name for SelectOption.
	 * This covers the fallback cast success path when a SelectOption is passed.
	 *
	 * @see UTIL_System.getRuntimeTypeName
	 */
	@IsTest
	private static void getRuntimeTypeNameReturnsSelectOptionType()
	{
		SelectOption option = new SelectOption('value', 'label');

		String typeName = UTIL_System.getRuntimeTypeName(option);

		Assert.areEqual('System.SelectOption', typeName, 'Should return System.SelectOption');
	}

	/**
	 * @description Tests resolving the type for a class name.
	 *
	 * @see UTIL_System.getTypeForClassName
	 */
	@IsTest
	private static void resolveTypeForClassName()
	{
		Assert.areEqual(ExampleClass.class, UTIL_System.getTypeForClassName(ExampleClass.class.getName()), 'Invalid Type returned');
	}

	/**
	 * @description Tests that resolving the type for a nonexistent class name throws an exception.
	 *
	 * @see UTIL_System.getTypeForClassName
	 */
	@IsTest
	private static void resolveTypeForClassNameNotFound()
	{
		try
		{
			UTIL_System.getTypeForClassName('NonExistentClassName');
			Assert.fail('Expected an Exception to be thrown');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect exception thrown');
		}
	}

	/**
	 * @description Tests resolving the type for a class name with an expected type.
	 *
	 * @see UTIL_System.getTypeForClassName
	 */
	@IsTest
	private static void resolveTypeForClassNameWithExpectedType()
	{
		Assert.areEqual(
				ExampleClass.class,
				UTIL_System.getTypeForClassName(ExampleClass.class.getName(), ParentExampleClass.class),
				'Invalid Type returned'
		);
	}

	/**
	 * @description Tests resolving the type for a class name with an invalid expected type.
	 *
	 * @see UTIL_System.getTypeForClassName
	 */
	@IsTest
	private static void resolveTypeForClassNameWithInvalidType()
	{
		try
		{
			UTIL_System.getTypeForClassName(ExampleClass.class.getName(), UTIL_System_TEST.class);
			Assert.fail('Expected an Exception to be thrown');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, TypeException.class, 'Incorrect exception thrown');
			String expectedMessage =
					String.format(UTIL_System.ERROR_TYPE_NOT_ASSIGNABLE, new List<String> {UTIL_System_TEST.class.getName(), ExampleClass.class.getName()});
			Assert.areEqual(expectedMessage, error.getMessage(), 'Invalid Exception Message');
		}
	}

	/**
	 * @description Tests that findTypeForClassName returns the type for a valid class name.
	 *
	 * @see UTIL_System.findTypeForClassName
	 */
	@IsTest
	private static void shouldFindTypeForValidClassName()
	{
		Assert.areEqual(ExampleClass.class, UTIL_System.findTypeForClassName(ExampleClass.class.getName()), 'Should resolve valid class');
	}

	/**
	 * @description Tests that findTypeForClassName returns null for a nonexistent class name.
	 *
	 * @see UTIL_System.findTypeForClassName
	 */
	@IsTest
	private static void shouldReturnNullWhenClassNotFound()
	{
		Assert.isNull(UTIL_System.findTypeForClassName('NonExistentClassName'), 'Should return null for nonexistent class');
	}

	/**
	 * @description Tests that findTypeForClassName with expected type returns the type when assignable.
	 *
	 * @see UTIL_System.findTypeForClassName
	 */
	@IsTest
	private static void shouldFindTypeForClassNameWithAssignableType()
	{
		Assert.areEqual(ExampleClass.class, UTIL_System.findTypeForClassName(ExampleClass.class.getName(), ParentExampleClass.class), 'Should resolve assignable type');
	}

	/**
	 * @description Tests that findTypeForClassName with expected type returns null when not assignable.
	 *
	 * @see UTIL_System.findTypeForClassName
	 */
	@IsTest
	private static void shouldReturnNullWhenTypeNotAssignable()
	{
		Assert.isNull(UTIL_System.findTypeForClassName(ExampleClass.class.getName(), UTIL_System_TEST.class), 'Should return null for non-assignable type');
	}

	/**
	 * @description Tests that findTypeForClassName with expected type returns null for a nonexistent class.
	 *
	 * @see UTIL_System.findTypeForClassName
	 */
	@IsTest
	private static void shouldReturnNullForNonexistentClassWithExpectedType()
	{
		Assert.isNull(UTIL_System.findTypeForClassName('NonExistentClassName', Object.class), 'Should return null for nonexistent class');
	}

	/**
	 * @description Tests retrieving an API-enabled session ID.
	 *
	 * @see UTIL_System.getApiEnabledSessionId
	 */
	@IsTest
	private static void retrieveApiEnabledSessionId()
	{
		Test.startTest();

		String apiSessionId = UTIL_System.getApiEnabledSessionId();

		Test.stopTest();

		Assert.isTrue(String.isNotBlank(apiSessionId), MSG_SESSION_ID_NOT_RETRIEVED);
	}

	/**
	 * @description Tests retrieving managed package namespace.
	 *
	 * @see UTIL_System.getManagedPackageNamespace
	 */
	@IsTest
	private static void retrieveManagedPackageNamespace()
	{
		String namespace = UTIL_System.getManagedPackageNamespacePrefix(UTIL_String.DOT);
		Boolean valid = String.isBlank(namespace) || namespace != UTIL_String.DOT;
		Assert.isTrue(valid, 'Namespace is incorrect');
	}

	/**
	 * @description Tests retrieving namespace prefix with both 1-arg and 2-arg overloads.
	 *
	 * @see UTIL_System.getNamespacePrefix
	 */
	@IsTest
	private static void retrieveNamespacePrefix()
	{
		String generatedNamespace = UTIL_Random.randomName();
		String expectedNamespacePrefix = generatedNamespace + UTIL_String.DOUBLE_UNDERSCORE;

		Assert.areEqual(expectedNamespacePrefix, UTIL_System.getNamespacePrefix(generatedNamespace, UTIL_String.DOUBLE_UNDERSCORE), 'Namespace prefix is incorrect');
		Assert.areEqual(expectedNamespacePrefix, UTIL_System.getNamespacePrefix(generatedNamespace), 'Namespace prefix is incorrect for 1-arg overload');
		Assert.areEqual(UTIL_String.EMPTY, UTIL_System.getNamespacePrefix(null, UTIL_String.DOUBLE_UNDERSCORE), 'Namespace prefix is incorrect');
	}

	/**
	 * @description Tests retrieving managed package namespace prefix with no-arg overload.
	 *
	 * @see UTIL_System.getManagedPackageNamespacePrefix
	 */
	@IsTest
	private static void retrieveManagedPackageNamespacePrefixNoArg()
	{
		String prefix = UTIL_System.getManagedPackageNamespacePrefix();
		Boolean valid = String.isBlank(prefix) || prefix.endsWith(UTIL_String.DOUBLE_UNDERSCORE);
		Assert.isTrue(valid, 'Namespace prefix should be blank or end with __');
	}

	/**
	 * @description Tests retrieving the organization API version.
	 *
	 * @see UTIL_System.getOrgApiVersion
	 */
	@IsTest
	private static void retrieveOrgApiVersion()
	{
		Test.startTest();

		String apiVersion = UTIL_System.getOrgApiVersion();

		Test.stopTest();

		Assert.isTrue(String.isNotBlank(apiVersion), MSG_API_VERSION_NOT_RETRIEVED);
	}

	/**
	 * @description Verifies `createInterview` extracts the namespace from a `namespace__name`
	 * prefix and routes through the 3-arg `Flow.Interview.createInterview` form. The platform's
	 * `TypeException` message format `'namespace.flowName'` (dot-separated) is the empirical
	 * signal that the namespace was supplied as the standalone first argument — the 2-arg
	 * form would leave the literal `__` separator in the error.
	 *
	 * @see UTIL_System.createInterview
	 */
	@IsTest
	private static void shouldParseNamespacePrefixWhenFlowNameContainsDoubleUnderscore()
	{
		String prefixedFlowName = NONEXISTENT_NAMESPACE + UTIL_String.DOUBLE_UNDERSCORE + NONEXISTENT_FLOW;
		try
		{
			UTIL_System.createInterview(prefixedFlowName, new Map<String, Object> {'record' => new Account()});
			Assert.fail('Lookup of non-existent flow should throw TypeException');
		}
		catch(TypeException error)
		{
			Assert.isTrue(error.getMessage().contains(NONEXISTENT_NAMESPACE + UTIL_String.DOT + NONEXISTENT_FLOW),
					'Error should report dot-separated namespace.name form, proving the prefix was parsed and the 3-arg form invoked: ' + error.getMessage());
		}
	}

	/**
	 * @description Verifies `createInterview` defaults to empty-string namespace
	 * (unmanaged / current-org context) when the flow name has no `namespace__name` prefix.
	 *
	 * @see UTIL_System.createInterview
	 */
	@IsTest
	private static void shouldDefaultToEmptyNamespaceWhenFlowNameHasNoPrefix()
	{
		try
		{
			UTIL_System.createInterview(NONEXISTENT_FLOW, new Map<String, Object> {'record' => new Account()});
			Assert.fail('Lookup of non-existent flow should throw TypeException');
		}
		catch(TypeException error)
		{
			Assert.isTrue(error.getMessage().contains(NONEXISTENT_FLOW),
					'Error should reference the bare flow name: ' + error.getMessage());
			Assert.isFalse(error.getMessage().contains(UTIL_String.DOT + NONEXISTENT_FLOW),
					'Error should not contain a `.flowName` form because no namespace was parsed: ' + error.getMessage());
		}
	}

	/**
	 * @description Parent class for testing type retrieval.
	 */
	public virtual class ParentExampleClass
	{
	}

	/**
	 * @description Example class for testing type retrieval.
	 */
	public class ExampleClass extends ParentExampleClass
	{
	}
}