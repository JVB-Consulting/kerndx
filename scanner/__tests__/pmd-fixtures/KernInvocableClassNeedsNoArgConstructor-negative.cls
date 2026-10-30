// SPDX-License-Identifier: Apache-2.0
/**
 * @description Scanner test input that KernInvocableClassNeedsNoArgConstructor must NOT report. Both classes here can
 * be created by Flow at run time: the outer one declares a public constructor with no parameters next to its other
 * constructor, and the inner one declares no constructor at all.
 */
public class KernInvocableClassNeedsNoArgConstructor_Negative
{
	/**
	 * @description A Flow input, so the rule checks this class's constructors.
	 */
	@InvocableVariable(required=true)
	public String recordId;

	/**
	 * @description An explicit public constructor with no parameters, next to the one with a parameter, so Flow/Process
	 * instantiation succeeds.
	 */
	public KernInvocableClassNeedsNoArgConstructor_Negative() {}

	/**
	 * @description The constructor with a parameter. On its own it would remove the implicit no-arg constructor; the
	 * public no-arg constructor above keeps the class valid.
	 *
	 * @param recordId The record Id to store in the Flow input.
	 */
	public KernInvocableClassNeedsNoArgConstructor_Negative(String recordId)
	{
		this.recordId = recordId;
	}

	/**
	 * @description No constructor declared at all: the implicit no-arg constructor remains available, so Flow/Process
	 * instantiation succeeds.
	 */
	public class RequestWithImplicitConstructor
	{
		/**
		 * @description A Flow input, so the rule checks this inner class too.
		 */
		@InvocableVariable
		public String name;
	}
}
