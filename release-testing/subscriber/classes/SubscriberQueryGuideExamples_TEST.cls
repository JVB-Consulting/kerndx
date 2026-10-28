// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Proves, on an org that installs the package, that the Selectors guide's examples for aggregate-query mocks,
 * TYPEOF parents and blank record keys compile and behave as the guide says. Each test carries one example as the guide
 * prints it, with the kern prefix, and adds only the data it needs and an assertion of the outcome the guide describes.
 * The class uses only names the package makes available to your org, so a compile error here means the guide names
 * something your code cannot call, or calls it with a different signature.
 *
 * An aggregate query counts, adds up or groups records instead of returning them. TYPEOF is the SOQL clause that picks
 * different parent fields for each kind of parent of a lookup that can point to more than one object.
 *
 * @see kern.QRY_Builder
 * @see kern.TST_Mock
 * @see kern.TST_Builder
 * @see kern.UTIL_Exceptions
 *
 * @author your.name@company.com
 *
 * @group Selectors
 *
 * @date October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=true)
private class SubscriberQueryGuideExamples_TEST
{
	/**
	 * @description The alias the count examples give the number of records.
	 */
	private static final String ALIAS_TOTAL = 'total';

	/**
	 * @description The alias the builder example gives the sum of the opportunity amounts.
	 */
	private static final String ALIAS_PIPELINE = 'pipeline';

	/**
	 * @description The key a grouped row uses for the stage: the field's API name.
	 */
	private static final String KEY_STAGE_NAME = 'StageName';

	/**
	 * @description The stage of the first row the guide registers.
	 */
	private static final String STAGE_PROSPECTING = 'Prospecting';

	/**
	 * @description The stage of the second row the guide registers.
	 */
	private static final String STAGE_CLOSED_WON = 'Closed Won';

	/**
	 * @description The total of the first row the guide registers.
	 */
	private static final Integer PROSPECTING_TOTAL = 3;

	/**
	 * @description The total of the second row the guide registers.
	 */
	private static final Integer CLOSED_WON_TOTAL = 2;

	/**
	 * @description The number of rows the guide registers for the stage totals.
	 */
	private static final Integer REGISTERED_ROW_COUNT = 2;

	/**
	 * @description The total the standing rows hold. These rows answer every aggregate query that has no rows of its own.
	 */
	private static final Integer STANDING_TOTAL = 5;

	/**
	 * @description The total the rows for the next query hold. These rows answer one aggregate query only.
	 */
	private static final Integer NEXT_TOTAL = 1;

	/**
	 * @description The pipeline total the builder example registers.
	 */
	private static final Decimal PIPELINE_TOTAL = 250000;

	/**
	 * @description The number of record mocks the count test registers.
	 */
	private static final Integer RECORD_MOCK_COUNT = 2;

	/**
	 * @description A total in the aggregate rows of the count test. It differs from the number of record mocks, so the test
	 * can tell which of the two answered.
	 */
	private static final Integer AGGREGATE_ROW_TOTAL = 9;

	/**
	 * @description A phone number for each account the tests save. The TYPEOF test reads it back through the account
	 * branch.
	 */
	private static final String ACCOUNT_PHONE = '555-0100';

	/**
	 * @description The amount of the opportunity an event points to.
	 */
	private static final Decimal OPPORTUNITY_AMOUNT = 1200;

	/**
	 * @description How long each saved event lasts, in minutes. An event needs a length.
	 */
	private static final Integer EVENT_DURATION_MINUTES = 30;

	/**
	 * @description How long a cached read may be kept, in seconds. A read in user mode is kept in memory for the
	 * transaction, so the value only has to be set.
	 */
	private static final Integer CACHE_SECONDS = 300;

	/**
	 * @description The number of events the TYPEOF test saves: one for an account, one for an opportunity and one with no
	 * parent.
	 */
	private static final Integer EVENT_COUNT = 3;

	/**
	 * @description The number of rows a test expects when exactly one row matches.
	 */
	private static final Integer SINGLE_MATCH_COUNT = 1;

	/**
	 * @description The text the error for an aggregate query with only record mocks contains: the method that registers
	 * aggregate rows.
	 */
	private static final String MESSAGE_PART_REGISTER_ROWS = 'registerAggregateRows';

	/**
	 * @description The text the error for a record read of a mocked aggregate query contains: the read to use instead.
	 */
	private static final String MESSAGE_PART_AGGREGATE_READ = 'toAggregateList';

	/**
	 * @description The guide's first example. Registered rows answer a grouped count read with toAggregateList(), in the order
	 * they were registered, and each value is read back by its alias or by the grouped field's API name.
	 */
	@IsTest
	private static void shouldReadMockedStageTotals()
	{
		kern.TST_Mock.registerAggregateRows(Opportunity.SObjectType, new List<Map<String, Object>>
		{
			new Map<String, Object>{ 'total' => 3, 'StageName' => 'Prospecting' },
			new Map<String, Object>{ 'total' => 2, 'StageName' => 'Closed Won' }
		});

		Test.startTest();
		List<kern.QRY_Builder.AggregateRow> rows = kern.QRY_Builder.selectFrom(Opportunity.SObjectType)
			.count(Opportunity.Id, 'total')
			.groupBy(Opportunity.StageName)
			.toAggregateList();
		Test.stopTest();

		Assert.areEqual(REGISTERED_ROW_COUNT, rows.size(), 'Expected one row for each registered map');
		Assert.areEqual(PROSPECTING_TOTAL, rows[0].getInteger(ALIAS_TOTAL), 'Expected the rows in the order they were registered');
		Assert.areEqual(STAGE_PROSPECTING, rows[0].getString(KEY_STAGE_NAME), 'Expected the stage the first row was registered with');
		Assert.areEqual(CLOSED_WON_TOTAL, rows[1].getInteger(ALIAS_TOTAL), 'Expected the total the second row was registered with');
		Assert.areEqual(STAGE_CLOSED_WON, rows[1].getString(KEY_STAGE_NAME), 'Expected the stage the second row was registered with');

		kern.TST_Mock.clear();
	}

	/**
	 * @description The guide's single-row form. One map registers one row, and getFirstAggregate() reads it.
	 */
	@IsTest
	private static void shouldReadOneMockedRowWithGetFirstAggregate()
	{
		kern.TST_Mock.registerAggregateRows(Opportunity.SObjectType, new Map<String, Object>{ ALIAS_TOTAL => STANDING_TOTAL });

		Test.startTest();
		kern.QRY_Builder.AggregateRow row = kern.QRY_Builder.selectFrom(Opportunity.SObjectType)
			.count(Opportunity.Id, ALIAS_TOTAL)
			.getFirstAggregate();
		Test.stopTest();

		Assert.areEqual(STANDING_TOTAL, row.getInteger(ALIAS_TOTAL), 'Expected the total of the one registered row');
	}

	/**
	 * @description Rows registered with registerNextAggregateRows answer only the next aggregate query. The query after it
	 * gets the standing rows registered with registerAggregateRows again.
	 */
	@IsTest
	private static void shouldAnswerTheNextQueryOnceThenTheStandingRows()
	{
		kern.TST_Mock.registerAggregateRows(Opportunity.SObjectType, new Map<String, Object>{ ALIAS_TOTAL => STANDING_TOTAL });
		kern.TST_Mock.registerNextAggregateRows(Opportunity.SObjectType, new List<Map<String, Object>>
		{
			new Map<String, Object>{ ALIAS_TOTAL => NEXT_TOTAL }
		});

		Test.startTest();
		Integer firstTotal = readOpportunityTotal();
		Integer secondTotal = readOpportunityTotal();
		Test.stopTest();

		Assert.areEqual(NEXT_TOTAL, firstTotal, 'Expected the rows for the next query to answer the first query');
		Assert.areEqual(STANDING_TOTAL, secondTotal, 'Expected the standing rows to answer the query after it');
	}

	/**
	 * @description The guide's builder example. setAggregateMock answers an aggregate query as registerAggregateRows does,
	 * and setAggregateMock with a null list removes the rows, so the database answers. The test saves no opportunities, so
	 * the database's sum holds no value.
	 */
	@IsTest
	private static void shouldAnswerFromTheBuilderAndRemoveTheRowsWithNull()
	{
		kern.QRY_Builder.setAggregateMock(Opportunity.SObjectType, new List<Map<String, Object>>
		{
			new Map<String, Object>{ 'pipeline' => 250000 }
		});

		Test.startTest();
		Decimal mockedPipeline = readOpportunityPipeline();
		kern.QRY_Builder.setAggregateMock(Opportunity.SObjectType, null);
		Decimal databasePipeline = readOpportunityPipeline();
		Test.stopTest();

		Assert.areEqual(PIPELINE_TOTAL, mockedPipeline, 'Expected the pipeline total set with setAggregateMock');
		Assert.isNull(databasePipeline, 'Expected the database to answer once the rows are removed, with no total because no opportunity exists');
	}

	/**
	 * @description Record mocks never answer an aggregate query. With record mocks and no aggregate rows, the aggregate read
	 * throws an error that names registerAggregateRows. The guide's one-line fix, an empty list of rows, then lets the same
	 * query find nothing.
	 */
	@IsTest
	private static void shouldThrowForRecordMocksUntilEmptyRowsAreRegistered()
	{
		kern.TST_Mock.of(Opportunity.SObjectType).build();

		Test.startTest();
		try
		{
			buildStageTotalsQuery().toAggregateList();
			Assert.fail('Expected the aggregate read to throw while only record mocks are registered');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, kern.UTIL_Exceptions.IllegalStateException.class, 'Expected an IllegalStateException');
			Assert.isTrue(error.getMessage().contains(MESSAGE_PART_REGISTER_ROWS), 'Expected the message to name registerAggregateRows: ' + error.getMessage());
		}

		kern.TST_Mock.registerAggregateRows(Opportunity.SObjectType, new List<Map<String, Object>>());
		List<kern.QRY_Builder.AggregateRow> rows = buildStageTotalsQuery().toAggregateList();
		Test.stopTest();

		Assert.isTrue(rows.isEmpty(), 'Expected an empty list of rows to make the query find nothing');
	}

	/**
	 * @description With record mocks and no aggregate rows, toList() on an aggregate query throws the same error. The record
	 * mocks never answer it.
	 */
	@IsTest
	private static void shouldThrowOnToListWhenOnlyRecordMocksAnswerAnAggregateQuery()
	{
		kern.TST_Mock.of(Opportunity.SObjectType).build();

		Test.startTest();
		try
		{
			buildStageTotalsQuery().toList();
			Assert.fail('Expected toList() on an aggregate query to throw while only record mocks are registered');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, kern.UTIL_Exceptions.IllegalStateException.class, 'Expected an IllegalStateException');
			Assert.isTrue(error.getMessage().contains(MESSAGE_PART_REGISTER_ROWS), 'Expected the message to name registerAggregateRows: ' + error.getMessage());
		}
		Test.stopTest();
	}

	/**
	 * @description Once aggregate rows answer a query, toList() and the other reads that return records throw an error that
	 * points to toAggregateList().
	 */
	@IsTest
	private static void shouldThrowOnToListWhenAggregateRowsAnswer()
	{
		kern.TST_Mock.registerAggregateRows(Opportunity.SObjectType, new List<Map<String, Object>>
		{
			new Map<String, Object>{ ALIAS_TOTAL => PROSPECTING_TOTAL, KEY_STAGE_NAME => STAGE_PROSPECTING }
		});

		Test.startTest();
		try
		{
			buildStageTotalsQuery().toList();
			Assert.fail('Expected toList() to throw on a query that aggregate rows answer');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, kern.UTIL_Exceptions.IllegalStateException.class, 'Expected an IllegalStateException');
			Assert.isTrue(error.getMessage().contains(MESSAGE_PART_AGGREGATE_READ), 'Expected the message to point to toAggregateList: ' + error.getMessage());
		}
		Test.stopTest();
	}

	/**
	 * @description The count() that ends a query and returns a number is not an aggregate read. Record mocks answer it, and
	 * the aggregate rows registered for the same object never do.
	 */
	@IsTest
	private static void shouldCountRecordMocksAndNeverAggregateRows()
	{
		List<SObject> opportunities = kern.TST_Builder.of(Opportunity.SObjectType).withoutInsertion(true).withCount(RECORD_MOCK_COUNT).buildList();
		kern.TST_Mock.register(Opportunity.SObjectType, opportunities);
		kern.TST_Mock.registerAggregateRows(Opportunity.SObjectType, new Map<String, Object>{ ALIAS_TOTAL => AGGREGATE_ROW_TOTAL });

		Test.startTest();
		Integer total = kern.QRY_Builder.selectFrom(Opportunity.SObjectType).count();
		Test.stopTest();

		Assert.areEqual(RECORD_MOCK_COUNT, total, 'Expected count() to count the record mocks, not read the aggregate rows');
	}

	/**
	 * @description The guide's TYPEOF example on saved records, in user mode. Each event's parent is read through an SObject
	 * variable and switch on: the account branch reads the phone, the opportunity branch reads the amount, and an event with
	 * no parent takes the null branch. Every event comes back, because TYPEOF picks fields and never filters rows. A second
	 * read of the same query with caching on is served from the cache and runs no query.
	 */
	@IsTest
	private static void shouldReadEachKindOfParentWithTypeOf()
	{
		Account parentAccount = insertAccount();
		Opportunity parentOpportunity = (Opportunity)kern.TST_Builder.of(Opportunity.SObjectType)
			.withOverride(Opportunity.AccountId, parentAccount.Id)
			.withOverride(Opportunity.Amount, OPPORTUNITY_AMOUNT)
			.build();
		Event accountEvent = insertEvent(parentAccount.Id);
		Event opportunityEvent = insertEvent(parentOpportunity.Id);
		Event eventWithNoParent = insertEvent(null);

		Map<Id, Object> parentValueByEventId = new Map<Id, Object>();
		Set<Id> eventIdsWithNoParent = new Set<Id>();

		Test.startTest();
		List<Event> events = kern.QRY_Builder.selectFrom(Event.SObjectType)
			.fields(new List<SObjectField>{ Event.Id, Event.Subject })
			.addField('TYPEOF What WHEN Account THEN Phone, Industry WHEN Opportunity THEN Amount ELSE Name END')
			.toList();

		for(Event event : events)
		{
			SObject parent = event.What;
			switch on parent
			{
				when Account account
				{
					String phone = account.Phone;
					parentValueByEventId.put(event.Id, phone);
				}
				when Opportunity opportunity
				{
					Decimal amount = opportunity.Amount;
					parentValueByEventId.put(event.Id, amount);
				}
				when null
				{
					// the event has no parent
					eventIdsWithNoParent.add(event.Id);
				}
				when else
				{
					// Any other parent: only its Name was selected
					String parentName = (String)parent.get('Name');
					parentValueByEventId.put(event.Id, parentName);
				}
			}
		}

		readEventsWithCache();
		Integer queriesBeforeCachedRead = kern.UTIL_Limits.soqlQueries().used();
		List<Event> cachedEvents = readEventsWithCache();
		Integer queriesAfterCachedRead = kern.UTIL_Limits.soqlQueries().used();
		Test.stopTest();

		Assert.areEqual(EVENT_COUNT, events.size(), 'Expected every event back, whatever its parent is');
		Assert.areEqual(ACCOUNT_PHONE, parentValueByEventId.get(accountEvent.Id), 'Expected the account branch to read the account phone');
		Assert.areEqual(OPPORTUNITY_AMOUNT, parentValueByEventId.get(opportunityEvent.Id), 'Expected the opportunity branch to read the amount');
		Assert.isTrue(eventIdsWithNoParent.contains(eventWithNoParent.Id), 'Expected the event with no parent to take the null branch');
		Assert.areEqual(SINGLE_MATCH_COUNT, eventIdsWithNoParent.size(), 'Expected only the event with no parent to take the null branch');
		Assert.areEqual(EVENT_COUNT, cachedEvents.size(), 'Expected the cached read to return every event');
		Assert.areEqual(queriesBeforeCachedRead, queriesAfterCachedRead, 'Expected the second cached read to be served from the cache without a query');
	}

	/**
	 * @description The guide's isIn(records, field) example. A record whose key field is blank is skipped, so only the account
	 * a contact points to comes back, and the blank key matches nothing.
	 */
	@IsTest
	private static void shouldSkipARecordWithABlankKey()
	{
		Account linkedAccount = insertAccount();
		insertAccount();
		List<Contact> contacts = new List<Contact>
		{
			buildContactInMemory(linkedAccount.Id),
			buildContactInMemory(null)
		};

		Test.startTest();
		List<Account> accounts = findAccountsForContacts(contacts);
		Test.stopTest();

		Assert.areEqual(SINGLE_MATCH_COUNT, accounts.size(), 'Expected only the account the contact points to, with the blank key skipped');
		Assert.areEqual(linkedAccount.Id, accounts[0].Id, 'Expected the account the contact points to');
	}

	/**
	 * @description Adding orCondition(field).isNull() after isIn(records, field) matches the rows whose field is blank as
	 * well, as the guide says. Contacts of the account an opportunity points to come back, and so does the contact with no
	 * account. A contact of another account does not.
	 */
	@IsTest
	private static void shouldMatchBlankRowsWithOrConditionIsNull()
	{
		Account linkedAccount = insertAccount();
		Account otherAccount = insertAccount();
		Contact linkedContact = insertContact(linkedAccount.Id);
		Contact contactWithNoAccount = insertContact(null);
		Contact otherContact = insertContact(otherAccount.Id);
		List<Opportunity> opportunities = new List<Opportunity>
		{
			buildOpportunityInMemory(linkedAccount.Id),
			buildOpportunityInMemory(null)
		};

		Test.startTest();
		List<Contact> keyedContacts = kern.QRY_Builder.selectFrom(Contact.SObjectType)
			.condition(Contact.AccountId).isIn(opportunities, Opportunity.AccountId)
			.toList();
		List<Contact> keyedAndBlankContacts = kern.QRY_Builder.selectFrom(Contact.SObjectType)
			.condition(Contact.AccountId).isIn(opportunities, Opportunity.AccountId)
			.orCondition(Contact.AccountId).isNull()
			.toList();
		Test.stopTest();

		Set<Id> keyedIds = new Map<Id, SObject>(keyedContacts).keySet();
		Set<Id> keyedAndBlankIds = new Map<Id, SObject>(keyedAndBlankContacts).keySet();
		Assert.areEqual(new Set<Id>{ linkedContact.Id }, keyedIds, 'Expected only the contact of the linked account without the null check');
		Assert.isTrue(keyedAndBlankIds.contains(linkedContact.Id), 'Expected the contact of the linked account with the null check');
		Assert.isTrue(keyedAndBlankIds.contains(contactWithNoAccount.Id), 'Expected the contact with no account with the null check');
		Assert.isFalse(keyedAndBlankIds.contains(otherContact.Id), 'Expected no contact of another account with the null check');
	}

	/**
	 * @description notInSet(records, field) keeps a record whose key field is blank, so the rows whose field is blank are
	 * left out. The contact with no account does not come back, and neither does the contact of the account an opportunity
	 * points to. Only the contact of another account comes back.
	 */
	@IsTest
	private static void shouldLeaveOutBlankRowsFromNotInSetWhenARecordHasABlankKey()
	{
		Account linkedAccount = insertAccount();
		Account otherAccount = insertAccount();
		Contact linkedContact = insertContact(linkedAccount.Id);
		Contact contactWithNoAccount = insertContact(null);
		Contact otherContact = insertContact(otherAccount.Id);
		List<Opportunity> opportunities = new List<Opportunity>
		{
			buildOpportunityInMemory(linkedAccount.Id),
			buildOpportunityInMemory(null)
		};

		Test.startTest();
		List<Contact> excludedContacts = kern.QRY_Builder.selectFrom(Contact.SObjectType)
			.condition(Contact.AccountId).notInSet(opportunities, Opportunity.AccountId)
			.toList();
		Test.stopTest();

		Set<Id> excludedIds = new Map<Id, SObject>(excludedContacts).keySet();
		Assert.areEqual(new Set<Id>{ otherContact.Id }, excludedIds, 'Expected only the contact of another account');
		Assert.isFalse(excludedIds.contains(contactWithNoAccount.Id), 'Expected no contact with no account');
		Assert.isFalse(excludedIds.contains(linkedContact.Id), 'Expected no contact of the linked account');
	}

	/**
	 * @description The guide's example method that finds the accounts the given contacts point to, as the guide prints it.
	 *
	 * @param contacts The contacts whose account ids are the keys.
	 *
	 * @return The accounts the contacts point to.
	 */
	private static List<Account> findAccountsForContacts(List<Contact> contacts)
	{
		return kern.QRY_Builder.selectFrom(Account.SObjectType)
			.fields(new List<SObjectField>{ Account.Name, Account.Industry })
			.condition(Account.Id).isIn(contacts, Contact.AccountId)
			.toList();
	}

	/**
	 * @description Builds the grouped count the guide uses: the number of opportunities in each stage.
	 *
	 * @return The query, ready to read.
	 */
	private static kern.QRY_Builder.Builder buildStageTotalsQuery()
	{
		return kern.QRY_Builder.selectFrom(Opportunity.SObjectType)
			.count(Opportunity.Id, ALIAS_TOTAL)
			.groupBy(Opportunity.StageName);
	}

	/**
	 * @description Reads the number of opportunities through an aggregate count with getFirstAggregate().
	 *
	 * @return The total the first row holds.
	 */
	private static Integer readOpportunityTotal()
	{
		return kern.QRY_Builder.selectFrom(Opportunity.SObjectType)
			.count(Opportunity.Id, ALIAS_TOTAL)
			.getFirstAggregate()
			.getInteger(ALIAS_TOTAL);
	}

	/**
	 * @description Reads the sum of the opportunity amounts through an aggregate query with getFirstAggregate().
	 *
	 * @return The pipeline total the first row holds.
	 */
	private static Decimal readOpportunityPipeline()
	{
		return kern.QRY_Builder.selectFrom(Opportunity.SObjectType)
			.sum(Opportunity.Amount, ALIAS_PIPELINE)
			.getFirstAggregate()
			.getDecimal(ALIAS_PIPELINE);
	}

	/**
	 * @description Reads the events with the guide's TYPEOF clause, with caching on.
	 *
	 * @return The events.
	 */
	private static List<Event> readEventsWithCache()
	{
		return kern.QRY_Builder.selectFrom(Event.SObjectType)
			.fields(new List<SObjectField>{ Event.Id, Event.Subject })
			.addField('TYPEOF What WHEN Account THEN Phone, Industry WHEN Opportunity THEN Amount ELSE Name END')
			.withCache(CACHE_SECONDS)
			.toList();
	}

	/**
	 * @description Saves an account with a phone number. The org's own validation rules for accounts are switched off for
	 * the save: they are not what these tests check, and TST_Builder fills only the fields an account must have.
	 *
	 * @return The saved account.
	 */
	private static Account insertAccount()
	{
		kern.UTIL_ValidationRule.bypassObject('Account');
		return (Account)kern.TST_Builder.of(Account.SObjectType).withOverride(Account.Phone, ACCOUNT_PHONE).build();
	}

	/**
	 * @description Saves an event that starts now, pointed at the given parent.
	 *
	 * @param parentId The account or opportunity the event points to, or null for an event with no parent.
	 *
	 * @return The saved event.
	 */
	private static Event insertEvent(Id parentId)
	{
		return (Event)kern.TST_Builder.of(Event.SObjectType)
			.withOverride(Event.WhatId, parentId)
			.withOverride(Event.ActivityDateTime, Datetime.now())
			.withOverride(Event.DurationInMinutes, EVENT_DURATION_MINUTES)
			.build();
	}

	/**
	 * @description Saves a contact of the given account.
	 *
	 * @param accountId The account of the contact, or null for a contact with no account.
	 *
	 * @return The saved contact.
	 */
	private static Contact insertContact(Id accountId)
	{
		return (Contact)kern.TST_Builder.of(Contact.SObjectType).withOverride(Contact.AccountId, accountId).build();
	}

	/**
	 * @description Builds a contact in memory, without saving it.
	 *
	 * @param accountId The account of the contact, or null for a blank key.
	 *
	 * @return The contact.
	 */
	private static Contact buildContactInMemory(Id accountId)
	{
		return (Contact)kern.TST_Builder.of(Contact.SObjectType).withOverride(Contact.AccountId, accountId).withoutInsertion().build();
	}

	/**
	 * @description Builds an opportunity in memory, without saving it.
	 *
	 * @param accountId The account of the opportunity, or null for a blank key.
	 *
	 * @return The opportunity.
	 */
	private static Opportunity buildOpportunityInMemory(Id accountId)
	{
		return (Opportunity)kern.TST_Builder.of(Opportunity.SObjectType).withOverride(Opportunity.AccountId, accountId).withoutInsertion().build();
	}
}
