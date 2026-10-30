// SPDX-License-Identifier: Apache-2.0
/**
 * @description Scanner test input that KernInvocableClassNeedsNoArgConstructor must report twice: once for the outer
 * class, which has only a constructor with a parameter, and once for the inner class, whose no-arg constructor is
 * private.
 */
public class KernInvocableClassNeedsNoArgConstructor_Positive
{
	/**
	 * @description A Flow input, so the rule checks this class's constructors.
	 */
	@InvocableVariable(required=true)
	public String recordId;

	/**
	 * @description Declares only an argument-bearing constructor, so the implicit no-arg constructor is gone. Flow/Process
	 * instantiation at run time fails.
	 *
	 * @param recordId The record Id to store in the Flow input.
	 */
	public KernInvocableClassNeedsNoArgConstructor_Positive(String recordId)
	{
		this.recordId = recordId;
	}

	/**
	 * @description A private no-arg constructor is not visible to Flow/Process instantiation, so this inner input class
	 * fails at run time too.
	 */
	public class RequestWithHiddenConstructor
	{
		/**
		 * @description A Flow input, so the rule checks this inner class's constructors.
		 */
		@InvocableVariable
		public String name;

		/**
		 * @description A no-arg constructor that Flow cannot see because it is private, which is what the rule must catch.
		 */
		private RequestWithHiddenConstructor() {}

		/**
		 * @description The public constructor with a parameter; it does not help Flow, which needs one with none.
		 *
		 * @param name The value to store in the Flow input.
		 */
		public RequestWithHiddenConstructor(String name)
		{
			this.name = name;
		}
	}
}
