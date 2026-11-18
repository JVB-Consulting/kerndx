// SPDX-License-Identifier: Apache-2.0
/**
 * @description Contact directory service. Reads and creates Contacts through the framework,
 * inheriting USER_MODE so CRUD and field-level security are enforced against the running user.
 *
 * @see SVC_ContactDirectory_TEST
 *
 * @author your.name@company.com
 *
 * @group Services
 *
 * @date February 2026, November 2026
 */
public with sharing class SVC_ContactDirectory
{
	/**
	 * @description Returns Contacts whose last name matches. Runs in USER_MODE by default, so a user
	 * who cannot read Contacts, or one of the selected fields, gets a QueryException.
	 *
	 * @param lastName The last name to filter by.
	 *
	 * @return Contacts the running user is allowed to see.
	 */
	public List<Contact> findByLastName(String lastName)
	{
		return new SEL_Contacts().query
				.condition(Contact.LastName).equals(lastName)
				.toList();
	}

	/**
	 * @description Creates a Contact. Runs in USER_MODE by default, so the create is checked
	 * against the running user's create access on Contact and on each field set.
	 *
	 * @param firstName The Contact's first name.
	 * @param lastName The Contact's last name.
	 *
	 * @return The result of the insert transaction.
	 */
	public kern.DML_Builder.TransactionResult createContact(String firstName, String lastName)
	{
		Contact newContact = new Contact(FirstName = firstName, LastName = lastName);

		return kern.DML_Builder.newTransaction()
				.doInsert(newContact)
				.execute();
	}

	/**
	 * @description Reads Contacts with the fields this service returns. Every read goes through a selector, so the
	 * fields live in one place and the read gets the framework's security, caching, logging and test mocks.
	 */
	private with sharing class SEL_Contacts extends kern.SEL_Base
	{
		/**
		 * @description Creates the selector for Contacts.
		 */
		public SEL_Contacts()
		{
			super(Contact.SObjectType);
		}

		/**
		 * @description The fields every read returns.
		 *
		 * @return First name, last name and email.
		 */
		public override List<SObjectField> getFields()
		{
			return new List<SObjectField> {Contact.FirstName, Contact.LastName, Contact.Email};
		}
	}
}
