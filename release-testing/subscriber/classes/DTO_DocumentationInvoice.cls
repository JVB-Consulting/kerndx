// SPDX-License-Identifier: Apache-2.0
/**
 * @description The invoice from the DTOs guide and the DTO_JsonBase reference page: a class of its own (not inside
 * another class) that the package turns into JSON and back. It declares getObjectType() public override, as the guide
 * shows.
 *
 * @see DocumentationSamplesGuideDetails_TEST
 *
 * @author your.name@company.com
 *
 * @group Documentation Samples
 *
 * @date November 2026
 */
@JsonAccess(serializable='always' deserializable='always')
public inherited sharing class DTO_DocumentationInvoice extends kern.DTO_JsonBase
{
	/**
	 * @description The invoice number.
	 */
	public String invoiceId;

	/**
	 * @description The invoice status, for example Paid.
	 */
	public String status;

	/**
	 * @description Tells the package which class to build when it reads JSON back.
	 *
	 * @return The type of this class.
	 */
	public override Type getObjectType()
	{
		return DTO_DocumentationInvoice.class;
	}
}
