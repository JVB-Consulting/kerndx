// SPDX-License-Identifier: BUSL-1.1
public class KernInvocableClassNeedsNoArgConstructor_Negative
{
	@InvocableVariable(required=true)
	public String recordId;

	// Explicit public no-arg constructor restored alongside the
	// argument-bearing one, so Flow/Process instantiation succeeds.
	public KernInvocableClassNeedsNoArgConstructor_Negative() {}

	public KernInvocableClassNeedsNoArgConstructor_Negative(String recordId)
	{
		this.recordId = recordId;
	}

	// No constructor declared at all: the implicit no-arg constructor
	// remains available, so Flow/Process instantiation succeeds.
	public class RequestWithImplicitConstructor
	{
		@InvocableVariable
		public String name;
	}
}
