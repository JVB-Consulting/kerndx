// SPDX-License-Identifier: Apache-2.0
@JsonAccess(serializable='always' deserializable='always')
public virtual with sharing class KernJsonReadClassNeedsJsonAccess_PositiveLocalChain extends kern.DTO_JsonBase
{
	@JsonAccess(serializable='always' deserializable='always')
	public virtual with sharing class BaseDto extends kern.DTO_JsonBase
	{
		public String name;
	}

	public with sharing class OrderDto extends BaseDto
	{
		public String orderNumber;
	}

	@JsonAccess(serializable='always' deserializable='always')
	public virtual with sharing class MiddleDto extends KernJsonReadClassNeedsJsonAccess_PositiveLocalChain.BaseDto
	{
		public String region;
	}

	@JsonAccess(serializable='always')
	public with sharing class LeafDto extends MiddleDto
	{
		public String code;
	}

	public with sharing class OuterChild extends KernJsonReadClassNeedsJsonAccess_PositiveLocalChain
	{
		public String label;
	}

	@JsonAccess(serializable='always' deserializable='always')
	public virtual with sharing class BaseContext implements kern.UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
	{
		public String probeField = 'value';
	}

	@JsonAccess(deserializable='always')
	public with sharing class OrderContext extends BaseContext
	{
		public String orderField = 'value';
	}
}
