// SPDX-License-Identifier: BUSL-1.1
@JsonAccess(serializable='always' deserializable='always')
public virtual with sharing class KernJsonReadClassNeedsJsonAccess_NegativeLocalChain extends kern.DTO_JsonBase
{
	@JsonAccess(serializable='always' deserializable='always')
	public virtual with sharing class Child extends KernJsonReadClassNeedsJsonAccess_NegativeLocalChain
	{
		public String name;
	}

	@JsonAccess(serializable='always' deserializable='always')
	public with sharing class Grandchild extends KernJsonReadClassNeedsJsonAccess_NegativeLocalChain.Child
	{
		public String code;
	}

	public virtual with sharing class PlainBase
	{
		public String name;
	}

	public with sharing class PlainChild extends PlainBase
	{
		public String label;
	}

	public with sharing class OtherNamespaceChild extends acme.Child
	{
		public String region;
	}

	@JsonAccess(serializable='always')
	public virtual with sharing class BaseContext implements kern.UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
	{
		public String probeField = 'value';
	}

	@JsonAccess(serializable='always')
	public with sharing class ChildContext extends BaseContext
	{
		public String childField = 'value';
	}
}
