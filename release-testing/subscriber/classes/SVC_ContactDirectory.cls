// SPDX-License-Identifier: BUSL-1.1
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
 * @date February 2026
 */
public with sharing class SVC_ContactDirectory
{
	/**
	 * @description Returns Contacts whose last name matches, with any fields the running user
	 * cannot read stripped from the results rather than throwing.
	 *
	 * @param lastName The last name to filter by.
	 *
	 * @return Contacts the running user is allowed to see, with inaccessible fields removed.
	 */
	public List<Contact> findByLastName(String lastName)
	{
		return kern.QRY_Builder.selectFrom(Contact.SObjectType)
				.fields(new List<SObjectField> {Contact.FirstName, Contact.LastName, Contact.Email})
				.condition(Contact.LastName).equals(lastName)
				.stripInaccessible()
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
}
