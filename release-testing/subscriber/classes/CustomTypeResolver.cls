// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Finds Apex classes by name on behalf of the framework. Code inside the installed package cannot look up
 * a class that lives in this org's own code, so the framework asks a resolver class that lives here to do the lookup.
 * The class is global so that the framework can reach it.
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global with sharing class CustomTypeResolver extends kern.UTIL_TypeResolver.BaseClassResolver
{
	/**
	 * @description Finds the Apex type for a class name. Looks in this org first; when the class is not found here, the
	 * name is passed to the next resolver in line, if there is one.
	 *
	 * @param className The name of the class to find.
	 *
	 * @return The type, or null when neither this resolver nor a later one finds the class.
	 */
	public override Type resolveType(String className)
	{
		return getTypeForClassName(className) ?? (Type)nextResolver?.resolveType(className);
	}

	/**
	 * @description Looks the class up by its full name, in one lookup made from this org's own code. The platform reads
	 * every way a class name can be written: "ClassName", a namespace in front ("ns.ClassName"), an inner class after its
	 * outer class ("Outer.Inner"), and both ("ns.Outer.Inner"). Splitting the name at its first dot cannot tell a
	 * namespace from an outer class, so the name is passed whole.
	 *
	 * @param className The name of the class to find, written in any of those four ways.
	 *
	 * @return The type, or null when the name is blank or no class matches.
	 */
	private static Type getTypeForClassName(String className)
	{
		return String.isBlank(className) ? null : Type.forName(className);
	}
}
