// SPDX-License-Identifier: Apache-2.0
/**
 * @description The DTO sample of the Why KernDX page with one change: the inner address class has no JsonAccess
 * annotation. A test uses it to find out whether the package can still fill the address.
 *
 * @see DocumentationSamplesFrontPage_TEST
 *
 * @author your.name@company.com
 *
 * @group Documentation Samples
 *
 * @date November 2026
 */
@JsonAccess(serializable='always' deserializable='always')
public inherited sharing class DTO_CustomerWithPlainAddress extends kern.DTO_JsonBase
{
	/**
	 * @description The customer's email address.
	 */
	public String email;

	/**
	 * @description The customer's address.
	 */
	public DTO_Address address;

	/**
	 * @description Names this class, so the package can turn JSON into it.
	 *
	 * @return This class.
	 */
	public override Type getObjectType()
	{
		return DTO_CustomerWithPlainAddress.class;
	}

	/**
	 * @description The part of a customer that holds the address, with no JsonAccess annotation.
	 */
	public class DTO_Address
	{
		/**
		 * @description The city.
		 */
		public String city;
	}
}
