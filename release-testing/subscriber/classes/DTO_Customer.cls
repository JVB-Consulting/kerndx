// SPDX-License-Identifier: Apache-2.0
/**
 * @description A customer as a JSON body carries it: an email address and an address with a city. It is the DTO sample
 * of the Why KernDX page, word for word.
 *
 * @see DocumentationSamplesFrontPage_TEST
 *
 * @author your.name@company.com
 *
 * @group Documentation Samples
 *
 * @date November 2026
 */
// public is enough: getObjectType() names the class, so KernDX does not look it up by name
@JsonAccess(serializable='always' deserializable='always')
public inherited sharing class DTO_Customer extends kern.DTO_JsonBase
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
		return DTO_Customer.class;
	}

	/**
	 * @description The part of a customer that holds the address.
	 */
	@JsonAccess(serializable='always' deserializable='always')
	public class DTO_Address
	{
		/**
		 * @description The city.
		 */
		public String city;
	}
}
