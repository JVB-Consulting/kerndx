// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Namespace, type resolution, and platform utility methods. Provides runtime introspection
 * for managed package namespace detection, class type resolution, API version retrieval,
 * and session management.
 *
 * @see UTIL_System_TEST
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date February 2026, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * String namespace = UTIL_System.getManagedPackageNamespace();
 * Type handlerType = UTIL_System.getTypeForClassName('TRG_SetFoobarDefaults');
 * Type validated = UTIL_System.getTypeForClassName('TRG_SetFoobarDefaults', IF_Trigger.BeforeInsert.class);
 * ```
 */
@SuppressWarnings('PMD.CyclomaticComplexity,PMD.CognitiveComplexity,PMD.AvoidGlobalModifier')
global inherited sharing class UTIL_System
{
	@TestVisible
	private static final String ERROR_TYPE_NOT_ASSIGNABLE = 'Resolved type "{1}" is not assignable to expected type "{0}".';

	@TestVisible
	private static final String ERROR_TYPE_NOT_FOUND = 'Unable to resolve type for class "{0}".';

	private static final String apiEnabledSessionId
	{
		get
		{
			if(apiEnabledSessionId == null)
			{
				//NB: GetContent cannot be called in a unit test as it results in the following error "Methods defined as TestMethod do not support getContent call"
				// Placeholder session ID — obviously fake, never resolves. Real format substituted at runtime.
				final String dummyPageContent = '<html>\n' +
						'<body>[[00DXX0000000000!XX_NOT_A_REAL_SESSION_ID_TEST_DUMMY_XX]]\n' +
						'</body>\n' +
						'</html>';

				String pageContent = Test.isRunningTest() ? dummyPageContent : Page.UTIL_GetApiEnabledSessionId.getContent().toString();

				apiEnabledSessionId = UTIL_String.substringBetween(pageContent, '[[', ']]');
			}

			return apiEnabledSessionId;
		}
		set;
	}

	private static final String currentNamespace
	{
		get
		{
			if(currentNamespace == null)
			{
				currentNamespace = getClassNamespace(UTIL_System.class.getName());
			}

			return currentNamespace;
		}
		set;
	}

	/**
	 * @description Will determine the namespace for the current execution context
	 * with double-underscore delimiter for SObject field/relationship prefixing.
	 *
	 * @return Empty String or the namespace with '__' suffix
	 *
	 * @example
	 * ```apex
	 * String prefix = UTIL_System.getManagedPackageNamespacePrefix(); // e.g. 'kern__' or ''
	 * ```
	 */
	public static String getManagedPackageNamespacePrefix()
	{
		return getManagedPackageNamespacePrefix(UTIL_String.DOUBLE_UNDERSCORE);
	}

	/**
	 * @description Will determine the namespace for the current execution context;
	 * ie. Is code currently running sitting in a package and the namespace of the package
	 * and add the provided delimiter (if a namespace exists)
	 *
	 * @param delimiter The delimiter for the item
	 *
	 * @return Empty String or the namespace with prefix
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * // Returns 'Sfdc_Surveys.' when namespace exists with '.' delimiter
	 * String namespaceWithDot = UTIL_System.getManagedPackageNamespacePrefix('.');
	 * // Returns 'Sfdc_Surveys__' when namespace exists with '__' delimiter
	 * String namespaceWithUnderscores = UTIL_System.getManagedPackageNamespacePrefix('__');
	 * // Returns '' when namespace does not exist
	 * ```
	 */
	global static String getManagedPackageNamespacePrefix(String delimiter)
	{
		return getNamespacePrefix(getManagedPackageNamespace(), delimiter);
	}

	/**
	 * @description Will determine the namespace for the current execution context;
	 * ie. Is code currently running sitting in a package and the namespace of the package
	 *
	 * @return Empty String or the package namespace
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String namespace = UTIL_System.getManagedPackageNamespace(); // e.g. 'kern' or ''
	 * ```
	 */
	global static String getManagedPackageNamespace()
	{
		return currentNamespace;
	}

	/**
	 * @description Will extract the namespace out of a class name, expects the class to be a top level class
	 *
	 * @param className The name of the class
	 *
	 * @return Empty String or the namespace
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String namespace = UTIL_System.getClassNamespace('kern.UTIL_System'); // 'kern'
	 * String empty = UTIL_System.getClassNamespace('MyClass'); // ''
	 * ```
	 */
	global static String getClassNamespace(String className)
	{
		String namespaceOfClass = UTIL_String.EMPTY;

		if(String.isNotBlank(className))
		{
			List<String> classNameParts = UTIL_String.split(className, '\\.', 2);
			namespaceOfClass = classNameParts.size() > 1 ? classNameParts.iterator().next() : UTIL_String.EMPTY;
		}

		return namespaceOfClass;
	}

	/**
	 * @description Will calculate namespace prefix with double-underscore delimiter for SObject field/relationship prefixing.
	 *
	 * @param namespace The provided namespace
	 *
	 * @return Empty String or the namespace with '__' suffix
	 *
	 * @example
	 * ```apex
	 * String prefix = UTIL_System.getNamespacePrefix('kern'); // 'kern__'
	 * ```
	 */
	public static String getNamespacePrefix(String namespace)
	{
		return getNamespacePrefix(namespace, UTIL_String.DOUBLE_UNDERSCORE);
	}

	/**
	 * @description Will calculate namespace prefix as follows:
	 * if the namespace exists - namespace + delimiter
	 * else Empty String
	 *
	 * @param namespace The provided namespace
	 * @param delimiter The delimiter for the item
	 *
	 * @return Empty String or the namespace with prefix
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String prefix = UTIL_System.getNamespacePrefix('kern', '.'); // 'kern.'
	 * ```
	 */
	global static String getNamespacePrefix(String namespace, String delimiter)
	{
		return String.isNotBlank(namespace) ? namespace + delimiter : UTIL_String.EMPTY;
	}

	/**
	 * @description Will return the Type for a given object class name
	 *
	 * @param className The class name to find a type for (please ensure that you prefix namespace if required)
	 * @param expectedType The expected type that the type for the class is assignable from
	 *
	 * @return The type of the object
	 *
	 * @throws IllegalArgumentException If no type if found for the given class name
	 * @throws TypeException if the type is not compatible with the expected type
	 *
	 * @see Type.isAssignableFrom
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Type classType = UTIL_System.getTypeForClassName('UTIL_System', Object.class);
	 * ```
	 */
	global static Type getTypeForClassName(String className, Type expectedType)
	{
		Type actualType = getTypeForClassName(className);

		assertTypeAssignable(expectedType, actualType);

		return actualType;
	}

	/**
	 * @description Will return the Type for a given object class name
	 *
	 * @param className The class name to find a type for (please ensure that you prefix namespace if required)
	 *
	 * @return The type of the object
	 *
	 * @throws IllegalArgumentException If no type if found for the given class name
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Type classType = UTIL_System.getTypeForClassName('UTIL_System');
	 * ```
	 */
	global static Type getTypeForClassName(String className)
	{
		Type classType = findTypeForClassName(className);

		if(classType == null)
		{
			throw new IllegalArgumentException(String.format(ERROR_TYPE_NOT_FOUND, new List<String> {className}));
		}

		return classType;
	}

	/**
	 * @description Resolves a class name to a Type via the UTIL_TypeResolver chain without throwing
	 * an exception. Returns null when the class cannot be found or has compilation errors.
	 *
	 * @param className The class name to resolve.
	 *
	 * @return The resolved Type, or null if not found.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Type classType = UTIL_System.findTypeForClassName('SCHED_DeactivateUsers');
	 * ```
	 */
	global static Type findTypeForClassName(String className)
	{
		UTIL_TypeResolver.INT_ClassTypeResolver resolver = UTIL_TypeResolver.getClassResolver();
		return resolver?.resolveType(className);
	}

	/**
	 * @description Resolves a class name to a Type via the UTIL_TypeResolver chain and verifies it
	 * is assignable to the expected type. Returns null when the class cannot be found or does not
	 * implement the expected type.
	 *
	 * @param className The class name to resolve.
	 * @param expectedType The type the resolved class must be assignable to.
	 *
	 * @return The resolved Type, or null if not found or not assignable.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Type classType = UTIL_System.findTypeForClassName('SCHED_DeactivateUsers', Schedulable.class);
	 * ```
	 */
	global static Type findTypeForClassName(String className, Type expectedType)
	{
		Type classType = findTypeForClassName(className);

		if(classType != null && expectedType != null && expectedType.isAssignableFrom(classType))
		{
			return classType;
		}

		return null;
	}

	/**
	 * @description Method will check that one type assignable from another; if not an exception will be raise
	 *
	 * @param expectedType The type that was expected
	 * @param actualType The type that was provided
	 *
	 * @throws TypeException if the expected is not assignable from the actual type
	 *
	 * @see Type.isAssignableFrom
	 *
	 * @example
	 * ```apex
	 * UTIL_System.assertTypeAssignable(List<Object>.class, List<String>.class);
	 * ```
	 */
	public static void assertTypeAssignable(Type expectedType, Type actualType)
	{
		if(expectedType == null || actualType == null || !expectedType.isAssignableFrom(actualType))
		{
			throw new TypeException(String.format(ERROR_TYPE_NOT_ASSIGNABLE, new List<String> {expectedType?.getName(), actualType?.getName()}));
		}
	}

	/**
	 * @description Running type of object passed in parameter.
	 *
	 * @param o The object to evaluate
	 *
	 * @return This method returns null if type is not accessible - when class is private
	 * or when it's part of anonymous script. In that case, getRunningTypeName() should be used instead.
	 *
	 * @example
	 * ```apex
	 * Type objectType = UTIL_System.getRuntimeType((Object)'Hello');
	 * ```
	 */
	public static Type getRuntimeType(Object o)
	{
		return getRuntimeType(o, 'Invalid conversion from runtime type ', ' to System.SelectOption');
	}

	/**
	 * @description Overloaded method to get the type from the Type name
	 *
	 * @param anObject The object to evaluate
	 * @param open The opening tag as response from the getRuntimeType
	 * @param close The closing tag as response from the getRuntimeType
	 *
	 * @return Running type of object passed in parameter.
	 *
	 * @example
	 * ```apex
	 * List<Object> items = new List<Object>{ 'Hello' };
	 * Type itemType = UTIL_System.getRuntimeType(items, 'List<', '>'); // String
	 * ```
	 */
	public static Type getRuntimeType(Object anObject, String open, String close)
	{
		return getTypeForClassName(getRuntimeTypeName(anObject, open, close));
	}

	/**
	 * @description This method serves to retrieve the type name of the provided object
	 *
	 * @param anObject The object to evaluate
	 *
	 * @return Name of Class of the Object provided
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String typeName = UTIL_System.getRuntimeTypeName((Object)'Hello'); // 'String'
	 * ```
	 */
	global static String getRuntimeTypeName(Object anObject)
	{
		return getRuntimeTypeName(anObject, 'Invalid conversion from runtime type ', ' to System.SelectOption');
	}

	/**
	 * @description Method to determine the running type of any node, this method uses assignment to SelectOption
	 * to attempt to convert the input object and subsequently extracts the type from potential error responses
	 * when performing the type conversion.
	 *
	 * @param anObject The object used in the type conversion
	 * @param open the opening tag of the type conversion
	 * @param close the closing tag of the type conversion
	 *
	 * @return A string containing the name of the class
	 */
	@SuppressWarnings('ApexUnusedDeclaration')
	@TestVisible
	private static String getRuntimeTypeName(Object anObject, String open, String close)
	{
		if(anObject == null)
		{
			LOG_Builder.build().error('NullPointerException - Input object is null').at(UTIL_System.class.getName() + '/getRuntimeTypeName').emit();
			throw new NullPointerException();
		}

		// Check Id BEFORE String - fixes issue where Id values stored in List<Object>
		// incorrectly report as String via exception message parsing.
		// LIMITATION: Strings that look like valid Salesforce IDs (15 or 18 chars) will also
		// return 'Id' due to Apex's implicit Id/String coercion. If you need to preserve
		// String type for ID-like values, use a strongly-typed List<String> instead of List<Object>.
		if(anObject instanceof Id)
		{
			return Id.class.getName();
		}

		// Common primitives - instanceof is more reliable and performant than exception parsing
		if(anObject instanceof String)
		{
			return String.class.getName();
		}
		if(anObject instanceof Boolean)
		{
			return Boolean.class.getName();
		}
		if(anObject instanceof Integer)
		{
			return Integer.class.getName();
		}
		if(anObject instanceof Long)
		{
			return Long.class.getName();
		}
		// Note: Double and Decimal are indistinguishable at runtime in Apex.
		// Both return true for `instanceof Decimal` and `instanceof Double`.
		// We use Decimal as the canonical type name for all floating-point values.
		if(anObject instanceof Decimal)
		{
			return Decimal.class.getName();
		}
		if(anObject instanceof Date)
		{
			return Date.class.getName();
		}
		if(anObject instanceof Datetime)
		{
			return Datetime.class.getName();
		}
		if(anObject instanceof Time)
		{
			return Time.class.getName();
		}
		if(anObject instanceof Blob)
		{
			return Blob.class.getName();
		}

		// SObjects - use describe for accurate type name
		// Note: List<SObject> passes instanceof SObject but cannot be cast, so exclude Lists
		if(anObject instanceof SObject && !(anObject instanceof List<Object>))
		{
			return ((SObject)anObject).getSObjectType().getDescribe().name;
		}

		// Fallback: exception parsing for Lists, Maps, Sets, and custom Apex classes
		// Use SelectOption as cast target - rare type not checked by instanceof above
		// If someone passes SelectOption (unlikely), cast succeeds and returns correct type
		// For all other types, TypeException is thrown and type extracted from message
		try
		{
			SelectOption unusedOption = (SelectOption)anObject;
			return SelectOption.class.getName();
		}
		catch(Exception ex)
		{
			return ex.getMessage().substringBetween(open, close);
		}
	}

	/**
	 * @description Will render a VF page to retrieve an API Enabled Session Id for current user
	 * To improve performance, session will be cached
	 *
	 * @return API enabled Session Id
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String sessionId = UTIL_System.getApiEnabledSessionId();
	 * ```
	 */
	global static String getApiEnabledSessionId()
	{
		return apiEnabledSessionId;
	}

	/**
	 * @description Will determine the current Salesforce Org Api Version
	 *
	 * @return the version in the form of "59.0"
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String version = UTIL_System.getOrgApiVersion(); // e.g. '65.0'
	 * ```
	 */
	global static String getOrgApiVersion()
	{
		Matcher matches = Pattern.compile('/v(\\d+\\.0)').matcher(JSON.serialize(UTIL_SObjectDescribe.getDescribe(User.SObjectType).getDescribe(), true));
		return matches.find() ? matches.group(1) : UTIL_String.EMPTY;
	}

	/**
	 * @description Wraps `Flow.Interview.createInterview` with namespace-aware resolution.
	 * Salesforce's 2-arg form `createInterview(flowName, vars)` fails with
	 * `TypeException: Invalid type` when resolving managed-package flows across namespace
	 * boundaries. The 3-arg form `createInterview(namespace, flowName, vars)` makes the
	 * namespace explicit and resolves reliably in every context tested. This helper parses
	 * a `namespace__name` prefix from `flowName` if present (defaulting to empty-string
	 * namespace when no prefix is found) and delegates to the 3-arg form. Empty-string
	 * namespace is safe; literal `null` would trigger an *uncatchable*
	 * `System.UnexpectedException` on `start()`, but this helper's initialisation ensures
	 * namespace is never null.
	 *
	 * @param flowName The flow API name. May be bare (`MyFlow`) or namespace-prefixed
	 *                 (`namespace__MyFlow`).
	 * @param variables The flow input variables map.
	 *
	 * @return The constructed `Flow.Interview`.
	 *
	 * @example
	 * ```apex
	 * Flow.Interview interview = UTIL_System.createInterview('kern__MyFlow', new Map<String, Object> {'record' => account});
	 * interview.start();
	 * ```
	 */
	public static Flow.Interview createInterview(String flowName, Map<String, Object> variables)
	{
		String namespace = UTIL_String.EMPTY;
		String resolvedFlowName = flowName;
		if(flowName?.contains(UTIL_String.DOUBLE_UNDERSCORE) == true)
		{
			Integer prefixEnd = flowName.indexOf(UTIL_String.DOUBLE_UNDERSCORE);
			namespace = flowName.substring(0, prefixEnd);
			resolvedFlowName = flowName.substring(prefixEnd + 2);
		}
		return Flow.Interview.createInterview(namespace, resolvedFlowName, variables);
	}
}