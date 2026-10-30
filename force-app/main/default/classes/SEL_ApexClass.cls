// SPDX-License-Identifier: Apache-2.0
/**
 * @description Selector for the ApexClass SObject. Provides type-safe querying and
 * Schedulable interface resolution for all Apex classes in the org.
 *
 * @see SEL_Base
 * @see SEL_ApexClass_TEST
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date March 2026, October 2026
 */
public inherited sharing class SEL_ApexClass extends SEL_Base
{
	/**
	 * @description Reads the Apex classes in the org (ApexClass). Every query skips the running user's object and field permission checks (system mode). Creating the selector runs
	 * no query.
	 */
	public SEL_ApexClass()
	{
		super(ApexClass.SObjectType);
	}

	/**
	 * @description Returns the core fields for ApexClass queries.
	 *
	 * @return List of ApexClass SObjectField tokens
	 */
	public override List<SObjectField> getFields()
	{
		return new List<SObjectField> {ApexClass.Name, ApexClass.NamespacePrefix};
	}

	/**
	 * @description Framework-internal schema selector — always runs in `AccessLevel.SYSTEM_MODE`
	 * regardless of the `UserModeQueries_Enabled` feature flag. Running users typically lack
	 * View All Data / View Setup on ApexClass, so USER_MODE reads would return empty and the
	 * class-discovery machinery (scheduler registration, type resolver) would silently break.
	 *
	 * @return `true` — this selector requires SYSTEM_MODE.
	 */
	public override Boolean systemModeRequired()
	{
		return true;
	}

	/**
	 * @description Returns the names of all Apex classes in the org that implement the Schedulable interface.
	 * Queries all ApexClass records and resolves each via the UTIL_TypeResolver chain so that subscriber
	 * public classes registered through ClassTypeResolver__mdt are also discoverable. Namespaced classes
	 * are returned with their namespace prefix (e.g. kern.SCHED_DeactivateUsers).
	 *
	 * @return List of class names that implement Schedulable (namespace-qualified where applicable).
	 */
	public List<String> findSchedulableClassNames()
	{
		List<String> classNames = new List<String>();

		for(ApexClass foundClass : (List<ApexClass>)query.orderBy(ApexClass.Name).ascending().toList())
		{
			String displayName = String.isNotBlank(foundClass.NamespacePrefix) ? foundClass.NamespacePrefix + UTIL_String.DOT + foundClass.Name : foundClass.Name;
			Type resolvedType = UTIL_System.findTypeForClassName(displayName, Schedulable.class);

			if(resolvedType != null && isInstantiable(resolvedType))
			{
				classNames.add(displayName);
			}
		}

		return classNames;
	}

	/**
	 * @description Finds the ApexClass row for a class name that may carry a namespace prefix: a dotted
	 * name matches its local name under that prefix, an undotted name matches under a null prefix (the
	 * unmanaged deployment shape). Owning this split here keeps callers namespace-robust without each
	 * re-deriving it.
	 *
	 * @param qualifiedClassName The class name, optionally namespace-qualified with a dot.
	 *
	 * @return The matching ApexClass row, or null when none exists.
	 */
	public ApexClass findByQualifiedName(String qualifiedClassName)
	{
		Boolean isNamespaced = qualifiedClassName.contains(UTIL_String.DOT);
		return (ApexClass)findFirstByFields(new Map<SObjectField, Object>
		{
				ApexClass.Name => isNamespaced ? qualifiedClassName.substringAfterLast(UTIL_String.DOT) : qualifiedClassName,
				ApexClass.NamespacePrefix => isNamespaced ? qualifiedClassName.substringBeforeLast(UTIL_String.DOT) : null
		});
	}

	/**
	 * @description Checks whether a type is a concrete (instantiable) class by attempting newInstance().
	 * Interfaces and abstract classes will throw and return false.
	 *
	 * @param resolvedType The Type to check.
	 *
	 * @return True if the type can be instantiated.
	 */
	private static Boolean isInstantiable(Type resolvedType)
	{
		try
		{
			resolvedType.newInstance();
			return true;
		}
		catch(Exception error)
		{
			return false;
		}
	}
}