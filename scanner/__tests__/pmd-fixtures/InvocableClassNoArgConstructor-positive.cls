// SPDX-License-Identifier: BUSL-1.1
public class InvocableClassNoArgConstructor_Positive
{
	@InvocableVariable(required=true)
	public String recordId;

	// Declares only an argument-bearing constructor, so the implicit no-arg
	// constructor is gone. Flow/Process instantiation at run time fails.
	public InvocableClassNoArgConstructor_Positive(String recordId)
	{
		this.recordId = recordId;
	}
}
