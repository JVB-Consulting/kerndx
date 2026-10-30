// SPDX-License-Identifier: Apache-2.0
@JsonAccess(serializable='always' deserializable='always')
public with sharing class KernJsonReadClassNeedsJsonAccess_Negative extends kern.DTO_JsonBase
{
	public String name;

	@JsonAccess(Serializable='Always' Deserializable='Always')
	public with sharing class MixedCase extends KERN.dto_jsonbase
	{
		public String name;
	}

	@JsonAccess(serializable='always')
	public with sharing class Context implements kern.UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
	{
		public String probeField = 'value';
	}

	public with sharing class SameNamespaceDto extends DTO_JsonBase
	{
		public String name;
	}

	public with sharing class SameNamespaceContext implements UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
	{
		public String probeField = 'value';
	}

	public with sharing class LookalikeBase extends kern.MyDTO_JsonBase
	{
		public String name;
	}

	public with sharing class PlainClass
	{
		public String name;
	}
}
