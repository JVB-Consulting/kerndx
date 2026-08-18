// SPDX-License-Identifier: BUSL-1.1
public class KernInvocableClassNeedsNoArgConstructor_Positive
{
	@InvocableVariable(required=true)
	public String recordId;

	// Declares only an argument-bearing constructor, so the implicit no-arg
	// constructor is gone. Flow/Process instantiation at run time fails.
	public KernInvocableClassNeedsNoArgConstructor_Positive(String recordId)
	{
		this.recordId = recordId;
	}

	// A private no-arg constructor is not visible to Flow/Process
	// instantiation, so this inner input class fails at run time too.
	public class RequestWithHiddenConstructor
	{
		@InvocableVariable
		public String name;

		private RequestWithHiddenConstructor() {}

		public RequestWithHiddenConstructor(String name)
		{
			this.name = name;
		}
	}
}
