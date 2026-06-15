// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Drift-guard demo class for keyed-map terminals on
 * `kern.QRY_Builder.Builder`. Demonstrates the four new terminal methods (each with an
 * `SObjectField` and a `String` overload, for a total of 8 signatures) that bridge to
 * `UTIL_SObject.indexById` / `indexByStringKey` / `groupByKey` / `groupByStringKey`:
 *
 * - `asMapById(SObjectField|String)`        → `Map<Id, SObject>` keyed by an arbitrary Id field
 * - `asMapByString(SObjectField|String)`    → `Map<String, SObject>` keyed by an arbitrary String field
 * - `asGroupedMapById(SObjectField|String)` → `Map<Id, List<SObject>>` grouped by an Id field
 * - `asGroupedMapByString(SObjectField|String)` → `Map<String, List<SObject>>` grouped by a String field
 *
 * Before these terminals shipped, subscribers writing `Map<Id, Contact>` keyed by
 * `Contact.AccountId` (rather than the strictly Id-keyed `asMap()` terminal) had to
 * `.toList()` and hand-write the loop. Each new terminal is a one-line bridge to the
 * existing `UTIL_SObject` helpers; mocks, sharing modes, USER_MODE, and `.withCache()`
 * configuration apply transparently because every terminal runs `.toList()` internally.
 *
 * @see FastStart_QueryMapTerminals_DEMO_TEST
 *
 * @author your.name@company.com
 *
 * @group Fast Start Demos
 *
 * @date May 2026
 */
public with sharing class FastStart_QueryMapTerminals_DEMO
{
	/**
	 * @description Returns Contacts keyed by their AccountId — the most common subscriber pattern.
	 * One call replaces the `.toList()` + hand-written `for` loop in pre-terminal style.
	 *
	 * Apex does not allow a direct downcast from `Map<Id, SObject>` to `Map<Id, Contact>`,
	 * so the return type stays at the generic shape returned by the terminal. Subscribers
	 * who need typed values cast each value at the access site (`(Contact)result.get(id)`)
	 * or use the grouped variant when they want `List<Contact>` per key.
	 *
	 * @return Map of `Contact.AccountId` → first Contact for that AccountId, typed as SObject.
	 */
	public Map<Id, SObject> contactsKeyedByAccountId()
	{
		return kern.QRY_Builder.selectFrom(Contact.SObjectType)
				.fields(new List<SObjectField> {Contact.LastName, Contact.AccountId})
				.condition(Contact.AccountId).isNotNull()
				.asMapById(Contact.AccountId);
	}

	/**
	 * @description Returns Contacts grouped by their AccountId — the bulk-per-Account pattern.
	 * Useful for traversing parent → children relationships without a subselect.
	 *
	 * @return Map of `Contact.AccountId` → list of Contacts for that AccountId.
	 */
	public Map<Id, List<Contact>> contactsGroupedByAccountId()
	{
		return (Map<Id, List<Contact>>)kern.QRY_Builder.selectFrom(Contact.SObjectType)
				.fields(new List<SObjectField> {Contact.LastName, Contact.AccountId})
				.condition(Contact.AccountId).isNotNull()
				.asGroupedMapById(Contact.AccountId);
	}

	/**
	 * @description Returns Accounts keyed by Name (a non-Id String field).
	 *
	 * Apex does not allow a direct downcast from `Map<String, SObject>` to
	 * `Map<String, Account>` — return type stays generic; cast at access site or use
	 * the grouped variant.
	 *
	 * @return Map of `Account.Name` → Account, typed as SObject.
	 */
	public Map<String, SObject> accountsKeyedByName()
	{
		return kern.QRY_Builder.selectFrom(Account.SObjectType)
				.fields(new List<SObjectField> {Account.Name, Account.Industry})
				.condition(Account.Name).isNotNull()
				.asMapByString(Account.Name);
	}

	/**
	 * @description Returns Accounts grouped by Industry — multiple Accounts per Industry value.
	 *
	 * @return Map of `Account.Industry` → list of Accounts in that Industry.
	 */
	public Map<String, List<Account>> accountsGroupedByIndustry()
	{
		return (Map<String, List<Account>>)kern.QRY_Builder.selectFrom(Account.SObjectType)
				.fields(new List<SObjectField> {Account.Name, Account.Industry})
				.condition(Account.Industry).isNotNull()
				.asGroupedMapByString(Account.Industry);
	}
}
