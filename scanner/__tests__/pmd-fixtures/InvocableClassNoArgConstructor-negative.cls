// SPDX-License-Identifier: BUSL-1.1
public class InvocableClassNoArgConstructor_Negative
{
	@InvocableVariable(required=true)
	public String recordId;

	// Explicit public no-arg constructor restored alongside the
	// argument-bearing one, so Flow/Process instantiation succeeds.
	public InvocableClassNoArgConstructor_Negative() {}

	public InvocableClassNoArgConstructor_Negative(String recordId)
	{
		this.recordId = recordId;
	}
}
