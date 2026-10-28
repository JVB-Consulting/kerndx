// SPDX-License-Identifier: BUSL-1.1
public with sharing class KernJsonReadClassNeedsJsonAccess_Positive extends kern.DTO_JsonBase
{
	public String name;

	@JsonAccess(serializable='always')
	public with sharing class SerializableOnly extends kern.DTO_JsonBase
	{
		public String name;
	}

	@JsonAccess(deserializable='always')
	public with sharing class DeserializableOnly extends kern.DTO_JsonBase
	{
		public String name;
	}

	@JsonAccess(serializable='samePackage' deserializable='always')
	public with sharing class WrongValue extends kern.DTO_JsonBase
	{
		public String name;
	}

	public with sharing class Context implements kern.UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
	{
		public String probeField = 'value';
	}

	@JsonAccess(deserializable='always')
	public with sharing class ContextDeserializableOnly implements kern.UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
	{
		public String probeField = 'value';
	}
}
