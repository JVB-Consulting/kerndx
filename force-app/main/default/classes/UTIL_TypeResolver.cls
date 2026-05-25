// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Utility class containing type resolution components for resolving Apex class types.
 *
 * @see UTIL_TypeResolver_TEST
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date March 2025, February 2026, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * UTIL_TypeResolver.INT_ClassTypeResolver resolver = UTIL_TypeResolver.getClassResolver();
 * Type handlerType = resolver.resolveType('TRG_SetFoobarDefaults');
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class UTIL_TypeResolver
{
	/**
	 * @description Ensure we only check once in a transaction for a custom type resolver
	 */
	private static Boolean haveCheckedForCustomResolver = false;

	/**
	 * @description Interface for resolving Type objects from class names and chaining resolvers.
	 *
	 * **Custom resolvers must be exception-safe.** The default chain implementation
	 * (`PackageClassResolver.resolveType`) delegates to `nextResolver?.resolveType(...)`
	 * via the `??` operator and DOES NOT catch and fall through on exception. A custom
	 * resolver that throws will propagate the exception to the caller, bypassing any
	 * later resolver in the chain. Implementations should either return `null` for
	 * "I cannot resolve this — try the next resolver" OR catch their own exceptions and
	 * convert them to `null` before returning.
	 *
	 * @since 1.0
	 */
	global interface INT_ClassTypeResolver
	{
		/**
		 * @description Resolves a Type object from a class name. Returning `null` signals
		 * "I cannot resolve this — chain falls through to the next resolver." Throwing
		 * propagates to the caller without consulting later resolvers — see the
		 * exception-safety contract on the interface ApexDoc.
		 *
		 * @param typeName The name of the class to resolve.
		 *
		 * @return The resolved Type object, or null if not found.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * INT_ClassTypeResolver resolver = new UTIL_TypeResolver.PackageClassResolver();
		 * Type resolvedType = resolver.resolveType('UTIL_TypeResolver_TEST.MyPackagePrivateClass');
		 * ```
		 */
		Type resolveType(String typeName);

		/**
		 * @description Sets the next resolver in the chain.
		 *
		 * @param nextTypeResolver The next resolver to try if this one fails.
		 *
		 * @return The next resolver in the chain.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * INT_ClassTypeResolver resolver = new UTIL_TypeResolver.PackageClassResolver();
		 * INT_ClassTypeResolver nextResolver = new CustomClassResolver();
		 * resolver.setNext(nextResolver);
		 * ```
		 */
		INT_ClassTypeResolver setNext(INT_ClassTypeResolver nextTypeResolver);
	}

	/**
	 * @description Abstract base class for implementing custom type resolvers, typically registered via custom metadata.
	 *
	 * @see ClassTypeResolver__mdt
	 *
	 * @since 1.0
	 */
	global abstract class BaseClassResolver implements INT_ClassTypeResolver
	{
		/**
		 * @description Holds the reference to the next resolver in the chain.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * INT_ClassTypeResolver value = instance.nextResolver;
		 * ```
		 */
		global protected INT_ClassTypeResolver nextResolver;

		/**
		 * @description Resolves a Type object from a class name.
		 *
		 * @param typeName The name of the class to resolve.
		 *
		 * @return The resolved Type object, or null if not found.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * BaseClassResolver resolver = new PackageClassResolver();
		 * Type resolvedType = resolver.resolveType('UTIL_TypeResolver_TEST.MyPackagePrivateClass');
		 * ```
		 */
		global abstract Type resolveType(String typeName);

		/**
		 * @description Sets the next resolver in the chain.
		 *
		 * @param nextTypeResolver The next resolver to try if this one fails.
		 *
		 * @return The next resolver in the chain.
		 *
		 * @example
		 * ```apex
		 * BaseClassResolver resolver = new PackageClassResolver();
		 * INT_ClassTypeResolver nextResolver = new CustomClassResolver();
		 * resolver.setNext(nextResolver);
		 * ```
		 */
		public virtual INT_ClassTypeResolver setNext(INT_ClassTypeResolver nextTypeResolver)
		{
			nextResolver = nextTypeResolver;
			return nextTypeResolver;
		}
	}

	/**
	 * @description Default managed package resolver for resolving class types.
	 */
	public inherited sharing class PackageClassResolver extends BaseClassResolver
	{
		/**
		 * @description Resolves a Type object from a class name, delegating to the next resolver if not found.
		 *
		 * @param typeName The name of the class to resolve.
		 *
		 * @return The resolved Type object, or null if not found.
		 *
		 * @example
		 * ```apex
		 * PackageClassResolver resolver = new PackageClassResolver();
		 * Type resolvedType = resolver.resolveType('UTIL_TypeResolver_TEST.MyPackagePrivateClass');
		 * ```
		 */
		public override Type resolveType(String typeName)
		{
			return getTypeForClassName(typeName) ?? nextResolver?.resolveType(typeName);
		}
	}

	/**
	 * @description Retrieves the configured resolver chain with the package resolver as the first link.
	 *
	 * @return The configured resolver chain.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * INT_ClassTypeResolver resolver = UTIL_TypeResolver.getClassResolver();
	 * Type resolvedType = resolver.resolveType('UTIL_TypeResolver_TEST.MyPackagePrivateClass');
	 * ```
	 */
	global static INT_ClassTypeResolver getClassResolver()
	{
		INT_ClassTypeResolver packageResolver = new PackageClassResolver();
		packageResolver.setNext(customResolver);
		return packageResolver;
	}

	/**
	 * @description Retrieves a custom resolver object from the class name set in custom metadata.
	 */
	@TestVisible
	private static INT_ClassTypeResolver customResolver
	{
		get
		{
			if(customResolver == null && !haveCheckedForCustomResolver)
			{
				customResolver = buildCustomResolverChain();
				haveCheckedForCustomResolver = true;
			}

			return customResolver;
		}
		set;
	}

	/**
	 * @description Builds a chained resolver from all configured ClassTypeResolver__mdt records,
	 * ordered by Order__c ascending. Each resolver delegates to the next via setNext().
	 *
	 * @return The chained resolver built from all configured metadata records, or null if none are configured
	 */
	private static INT_ClassTypeResolver buildCustomResolverChain()
	{
		return buildCustomResolverChain(new SEL_ClassTypeResolver().findAll());
	}

	/**
	 * @description Builds a chained resolver from the provided ClassTypeResolver__mdt records.
	 * Resolves each class name, validates it implements INT_ClassTypeResolver, and chains
	 * valid resolvers together via setNext().
	 *
	 * @param records The ClassTypeResolver__mdt records to build the resolver chain from
	 *
	 * @return The chained resolver built from the provided records, or null if none are valid
	 */
	@TestVisible
	private static INT_ClassTypeResolver buildCustomResolverChain(List<ClassTypeResolver__mdt> records)
	{
		List<INT_ClassTypeResolver> resolvers = new List<INT_ClassTypeResolver>();

		for(ClassTypeResolver__mdt record : records)
		{
			Type resolverType = getTypeForClassName(record.ClassName__c);

			if(resolverType == null || !INT_ClassTypeResolver.class.isAssignableFrom(resolverType))
			{
				continue;
			}

			resolvers.add((INT_ClassTypeResolver)resolverType.newInstance());
		}

		return chainResolvers(resolvers);
	}

	/**
	 * @description Chains a list of resolvers into a linked chain via setNext(). The first resolver
	 * in the list becomes the head, each subsequent resolver is linked as the next in the chain.
	 *
	 * @param resolvers The list of resolvers to chain together
	 *
	 * @return The head of the chained resolver list, or null if the list is empty
	 */
	@TestVisible
	private static INT_ClassTypeResolver chainResolvers(List<INT_ClassTypeResolver> resolvers)
	{
		INT_ClassTypeResolver head;
		INT_ClassTypeResolver current;

		for(INT_ClassTypeResolver resolver : resolvers)
		{
			if(head == null)
			{
				head = resolver;
				current = resolver;
			}
			else
			{
				current.setNext(resolver);
				current = resolver;
			}
		}

		return head;
	}

	/**
	 * @description Resolves the Type for a given class name using Subscriber-First resolution.
	 * Tries to resolve without namespace first (subscriber-defined classes), then falls back to
	 * package namespace if not found. This allows subscribers to override package classes.
	 *
	 * @param typeName The class name to resolve (include namespace prefix if required).
	 *
	 * @return The resolved Type object, or null if not found.
	 *
	 * @example
	 * ```apex
	 * Type resolvedType = UTIL_TypeResolver.getTypeForClassName('UTIL_TypeResolver_TEST.MyPackagePrivateClass');
	 * ```
	 */
	private static Type getTypeForClassName(String typeName)
	{
		Type classType;
		if(String.isNotBlank(typeName))
		{
			// Subscriber-First: Try without namespace first (subscriber-defined classes)
			classType = Type.forName(UTIL_String.EMPTY, typeName);

			// If not found, try with package namespace
			if(classType == null)
			{
				String namespace = UTIL_System.getNamespacePrefix(UTIL_System.getClassNamespace(typeName), UTIL_String.DOT);
				classType = Type.forName(namespace, typeName);
				// Retry without namespace for nested classes (e.g., MyParentClass.MyChildClass)
				classType = classType == null && String.isNotBlank(namespace) ? Type.forName(UTIL_String.EMPTY, typeName) : classType;
			}
		}
		return classType;
	}
}