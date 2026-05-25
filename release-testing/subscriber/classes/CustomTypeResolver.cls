// SPDX-License-Identifier: BUSL-1.1
@SuppressWarnings('PMD.AvoidGlobalModifier')
global with sharing class CustomTypeResolver extends kern.UTIL_TypeResolver.BaseClassResolver
{
	public override Type resolveType(String className)
	{
		return getTypeForClassName(className) ?? (Type)nextResolver?.resolveType(className);
	}

	private static Type getTypeForClassName(String className)
	{
		Type classType;

		if(String.isNotBlank(className))
		{
			String namespace = kern.UTIL_System.getNamespacePrefix(kern.UTIL_System.getClassNamespace(className), '.');
			classType = Type.forName(namespace, className);
			classType = classType == null && String.isNotBlank(namespace) ? Type.forName('', className) : classType;
		}

		return classType;
	}
}
