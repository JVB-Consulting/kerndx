// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Subscriber proof for `QRY_Builder` `runAs` scenarios deferred from
 * `release-testing/scripts/section-53-edge-qry-builder.apex` (the extended-load spec §6.15, Task 1.15) plus
 * subscriber-namespace SOQL shape verification. Anonymous Apex cannot impersonate via
 * `System.runAs` — only `@IsTest` context can — so these two scenarios live here:
 *
 * 1. `.withSystemMode().stripInaccessible()` against `kern__Foobar__c` as a Standard User
 *    without `kern__Foobar__c` CRUD — `.withSystemMode()` lets the SOQL succeed past
 *    USER_MODE's CRUD/FLS gate, then the post-query strip layer scrubs every field the
 *    Standard User cannot read, yielding zero observable rows. No exception is thrown —
 *    the contract under test is "subscriber-safe FLS handling via the documented composition".
 * 2. `.toSoql()` against `kern__Foobar__c.SObjectType` returns SOQL that includes the
 *    `kern__` namespace prefix on the FROM clause — proving subscriber callers receive
 *    properly-namespaced SOQL strings for packaged objects.
 *
 * Also proves each release's new global query surface is subscriber-reachable through the
 * `kern` namespace: the 1.2 geolocation distance functions, and the 1.3 aliased aggregates
 * (`count`/`countDistinct`/`sum`/`avg`/`min`/`max` with an explicit alias), `orderByCount`,
 * the single-argument `QRY_Condition.FieldCondition` constructors paired with `contains()`,
 * and the call-site alias validation on aliased selections.
 *
 * Two tests run as a Standard User who has no permission set and cannot see a private API call record the administrator
 * saved: a cursor opened with bypassSharing() fetches that record, and the query cache keeps a system-mode read only when
 * the read states its sharing (a user-mode read is kept for the rest of the transaction).
 *
 * @see kern.QRY_Builder
 * @see kern.QRY_Condition
 * @see kern.QRY_Function
 * @see kern.UTIL_FeatureFlag
 * @see kern.UTIL_Limits
 * @see kern.TST_Factory
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date May 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=false)
private class Subscriber_QryEdges_TEST
{
	/**
	 * @description Profile name for the Standard User fixture used by `System.runAs`.
	 */
	private static final String STANDARD_PROFILE = 'Standard User';

	/**
	 * @description Expected namespace prefix that `.toSoql()` should emit when querying a
	 * packaged custom object from subscriber Apex.
	 */
	private static final String NAMESPACE_PREFIX = 'kern__';

	/**
	 * @description The service name on the private API call record the administrator saves for the sharing tests.
	 */
	private static final String PRIVATE_CALL_SERVICE_NAME = 'QryEdgesPrivateCall';

	/**
	 * @description The direction of the private API call record.
	 */
	private static final String DIRECTION_OUTBOUND = 'Outbound';

	/**
	 * @description The account name the user-mode cached read looks for; no account needs to carry it.
	 */
	private static final String CACHED_ACCOUNT_NAME = 'QryEdges cached read';

	/**
	 * @description How long, in seconds, the user-mode cached read may be kept.
	 */
	private static final Integer CACHE_SECONDS = 300;

	/**
	 * @description Two identical reads that are not cached each run a query.
	 */
	private static final Integer QUERIES_FOR_TWO_UNCACHED_READS = 2;

	/**
	 * @description Two identical cached reads run one query: the second read is answered from the cache.
	 */
	private static final Integer QUERIES_FOR_TWO_CACHED_READS = 1;

	/**
	 * @description A Standard User running a `.withSystemMode().stripInaccessible()` chain
	 * against a packaged custom object they cannot read should observe an empty result list:
	 * SYSTEM_MODE lets the SOQL fetch the row without USER_MODE's CRUD/FLS gate, then the
	 * post-query strip layer scrubs every field the running user (Standard User) cannot
	 * read — yielding zero observable rows because every selected field is inaccessible.
	 * This is the core deferral from section-53: anonymous Apex cannot impersonate a user
	 * with different FLS than the running admin, so this composition needs an `@IsTest`
	 * runAs harness. The spec text "field is null in result" was aspirational — the
	 * platform strips inaccessible fields entirely rather than nulling them; the observable
	 * contract — no exception under `System.runAs`, predictable empty result — is what
	 * subscribers depend on.
	 */
	@IsTest
	private static void shouldReturnEmptyListForFlsStrippedQuery()
	{
		User standardUser = createStandardUser();
		kern__Foobar__c seedRecord = (kern__Foobar__c)kern.TST_Builder.of(kern__Foobar__c.SObjectType)
				.withOverride(kern__Foobar__c.Name, 'QryEdges-FLS-seed')
				.build();
		Boolean queriedCleanly = false;
		List<SObject> results = null;
		String thrownTypeName = null;

		Test.startTest();

		System.runAs(standardUser)
		{
			try
			{
				results = kern.QRY_Builder.selectFrom(kern__Foobar__c.SObjectType)
						.fields(new List<SObjectField> {kern__Foobar__c.Name, kern__Foobar__c.kern__Text__c})
						.condition(kern__Foobar__c.Id).equals(seedRecord.Id)
						.withSystemMode()
						.stripInaccessible()
						.toList();
				queriedCleanly = true;
			}
			catch(Exception unexpected)
			{
				thrownTypeName = unexpected.getTypeName();
			}
		}

		Test.stopTest();

		Assert.isTrue(queriedCleanly, '.stripInaccessible() should swallow FLS restrictions and return an empty list for a Standard User without kern__Foobar__c read. '
				+ 'Got exception: ' + thrownTypeName);
		Assert.isNotNull(results, 'Result list should be a non-null collection (empty is the expected shape when every field is stripped)');
		Assert.isTrue(results.isEmpty(), 'Standard User without kern__Foobar__c FLS should observe zero rows after the strip layer scrubs every readable field');
	}

	/**
	 * @description Calling `.toSoql()` from subscriber Apex against a packaged custom object
	 * must emit SOQL that includes the `kern__` namespace prefix — both on the `FROM` clause
	 * and on packaged field references — so the resulting query is portable across subscribers
	 * regardless of whether they hand the SOQL to Database.query or pass it onward.
	 */
	@IsTest
	private static void shouldGenerateNamespacePrefixedSoqlForPackagedObject()
	{
		Test.startTest();

		String soql = kern.QRY_Builder.selectFrom(kern__Foobar__c.SObjectType)
				.fields(new List<SObjectField> {kern__Foobar__c.Name, kern__Foobar__c.kern__Text__c})
				.condition(kern__Foobar__c.Name).equals('NamespaceShape-probe')
				.toSoql();

		Test.stopTest();

		Assert.isNotNull(soql, '.toSoql() should return a non-null SOQL string');
		Assert.isTrue(soql.contains(NAMESPACE_PREFIX + 'Foobar__c'), 'Generated SOQL FROM clause should include the kern__ namespace prefix on the packaged object. Got: ' + soql);
		Assert.isTrue(soql.contains(NAMESPACE_PREFIX + 'Text__c'), 'Generated SOQL field list should include the kern__ namespace prefix on packaged fields. Got: ' + soql);
	}

	/**
	 * @description Reference latitude (San Francisco) used by the 1.2 geolocation distance tests.
	 */
	private static final Decimal REFERENCE_LATITUDE = 37.7749;

	/**
	 * @description Reference longitude (San Francisco) used by the 1.2 geolocation distance tests.
	 */
	private static final Decimal REFERENCE_LONGITUDE = -122.4194;

	/**
	 * @description The 1.2 geolocation distance functions on `QRY_Function` must emit a
	 * `DISTANCE(... GEOLOCATION(...) ...)` SOQL expression when fed into the builder's WHERE and
	 * ORDER BY overloads, across both the Decimal-coordinate and `System.Location` factories and
	 * both the mile and kilometre units. This shape test proves the global factories and the
	 * builder integration are subscriber-reachable and render the documented SOQL, independent of
	 * any stored geolocation data.
	 */
	@IsTest
	private static void shouldEmitDistanceExpressionInGeneratedSoql()
	{
		Test.startTest();

		String soql = kern.QRY_Builder.selectFrom(Account.SObjectType)
				.fields(new List<SObjectField> {Account.Name})
				.condition(kern.QRY_Function.distanceInMiles(Account.BillingAddress, REFERENCE_LATITUDE, REFERENCE_LONGITUDE)).lessThan(50)
				.orderBy(kern.QRY_Function.distanceInKilometers(Account.BillingAddress, System.Location.newInstance(REFERENCE_LATITUDE, REFERENCE_LONGITUDE))).ascending()
				.toSoql();

		Test.stopTest();

		Assert.isNotNull(soql, '.toSoql() should return a non-null SOQL string');
		Assert.isTrue(soql.contains('DISTANCE('), 'Generated SOQL should include the DISTANCE() function. Got: ' + soql);
		Assert.isTrue(soql.contains('GEOLOCATION('), 'Generated SOQL should include the GEOLOCATION() function. Got: ' + soql);
		Assert.isTrue(soql.contains('\'mi\''), 'The miles factory should render the \'mi\' unit. Got: ' + soql);
		Assert.isTrue(soql.contains('\'km\''), 'The kilometres factory should render the \'km\' unit. Got: ' + soql);
	}

	/**
	 * @description End-to-end proof that the 1.2 distance functions filter and sort real records
	 * by proximity. Three Accounts are seeded with billing geolocation at known distances from a
	 * San Francisco reference point; a single fluent query then keeps those within fifty miles and
	 * orders them nearest-first, returning the two local Accounts in order and excluding the
	 * cross-country one. The Accounts are deliberately inserted in an order that differs from the
	 * distance order (Mid before Near), so a missing or broken ORDER BY DISTANCE would fail the
	 * sequence assertion rather than pass by coincidence of insertion order.
	 */
	@IsTest
	private static void shouldFilterAndOrderRecordsByGeolocationDistance()
	{
		kern.UTIL_ValidationRule.bypassObject('Account');

		kern.TST_Builder.of(Account.SObjectType)
				.withOverride(Account.Name, 'Geo Mid')
				.withOverride(Account.BillingLatitude, 37.8044)
				.withOverride(Account.BillingLongitude, -122.2712)
				.build();
		kern.TST_Builder.of(Account.SObjectType)
				.withOverride(Account.Name, 'Geo Near')
				.withOverride(Account.BillingLatitude, REFERENCE_LATITUDE)
				.withOverride(Account.BillingLongitude, REFERENCE_LONGITUDE)
				.build();
		kern.TST_Builder.of(Account.SObjectType)
				.withOverride(Account.Name, 'Geo Far')
				.withOverride(Account.BillingLatitude, 40.7128)
				.withOverride(Account.BillingLongitude, -74.0060)
				.build();

		Test.startTest();

		List<Account> nearby = (List<Account>)kern.QRY_Builder.selectFrom(Account.SObjectType)
				.fields(new List<SObjectField> {Account.Name})
				.condition(kern.QRY_Function.distanceInMiles(Account.BillingAddress, REFERENCE_LATITUDE, REFERENCE_LONGITUDE)).lessThan(50)
				.orderBy(kern.QRY_Function.distanceInMiles(Account.BillingAddress, REFERENCE_LATITUDE, REFERENCE_LONGITUDE)).ascending()
				.toList();

		Test.stopTest();

		Assert.areEqual(2, nearby.size(), 'Only the two Accounts within fifty miles should be returned (the cross-country one is excluded)');
		Assert.areEqual('Geo Near', nearby[0].Name, 'The nearest Account should sort first');
		Assert.areEqual('Geo Mid', nearby[1].Name, 'The second-nearest Account should sort second');
	}

	/**
	 * @description The 1.3 aliased aggregates must accumulate into ONE grouped query from
	 * subscriber Apex — six aggregate functions folded over the same GROUP BY — with every value
	 * read back by its caller-chosen alias on the `AggregateRow`. Two industries are seeded with
	 * known headcounts so each per-group value is exact, proving the aliases survive the round
	 * trip through the generated SOQL rather than falling back to the auto `expr0` positions.
	 * Account trigger actions are bypassed for the seeds because the Phase-5B flow action
	 * (`TST_SubscriberFlow_AdditionalDefaults`) stamps `NumberOfEmployees = 42` on every Account
	 * before-insert, which would replace the seeded headcounts these aggregate assertions read.
	 * Accessor choice matches the verified runtime boxing over the int-soapType
	 * NumberOfEmployees: COUNT/COUNT_DISTINCT/MIN/MAX box as Integer (read via `getInteger`),
	 * while SUM/AVG box as Double (read via `getDecimal`; `getInteger` there throws a
	 * TypeException, and `getDecimal` also reads Integer-boxed values safely).
	 *
	 * @date July 2026
	 */
	@IsTest
	private static void shouldFoldAliasedAggregatesReadBackByAlias()
	{
		kern.UTIL_ValidationRule.bypassObject('Account');
		kern.TRG_Base.bypass(Account.SObjectType);
		seedAccount('AggAlias Alpha', 'Technology', 10);
		seedAccount('AggAlias Beta', 'Technology', 30);
		seedAccount('AggAlias Gamma', 'Agriculture', 5);

		Test.startTest();

		List<kern.QRY_Builder.AggregateRow> rows = kern.QRY_Builder.selectFrom(Account.SObjectType)
				.condition(Account.Name).contains('AggAlias')
				.groupBy(Account.Industry)
				.count(Account.Id, 'rowTotal')
				.countDistinct(Account.Name, 'uniqueNames')
				.sum(Account.NumberOfEmployees, 'headcount')
				.avg(Account.NumberOfEmployees, 'meanHeadcount')
				.min(Account.NumberOfEmployees, 'smallest')
				.max(Account.NumberOfEmployees, 'largest')
				.toAggregateList();

		Test.stopTest();

		Assert.areEqual(2, rows.size(), 'One grouped row per seeded industry should be returned');
		kern.QRY_Builder.AggregateRow technology = findGroup(rows, 'Technology');
		Assert.areEqual(2, technology.getInteger('rowTotal'), 'COUNT should read back by its alias for the two Technology accounts');
		Assert.areEqual(2, technology.getInteger('uniqueNames'), 'COUNT_DISTINCT should read back by its alias');
		Assert.areEqual(40, technology.getDecimal('headcount'), 'SUM should read back by its alias (10 + 30)');
		Assert.areEqual(20, technology.getDecimal('meanHeadcount'), 'AVG should read back by its alias ((10 + 30) / 2)');
		Assert.areEqual(10, technology.getInteger('smallest'), 'MIN should read back by its alias');
		Assert.areEqual(30, technology.getInteger('largest'), 'MAX should read back by its alias');
		kern.QRY_Builder.AggregateRow agriculture = findGroup(rows, 'Agriculture');
		Assert.areEqual(1, agriculture.getInteger('rowTotal'), 'COUNT should read back for the single Agriculture account');
		Assert.areEqual(5, agriculture.getDecimal('headcount'), 'SUM should read back for the single Agriculture account');
	}

	/**
	 * @description The 1.3 `orderByCount` must emit ORDER BY COUNT(...) and actually rank the
	 * grouped rows largest-first from subscriber Apex. The groups are seeded so the count order
	 * is the REVERSE of the alphabetical group order (the alphabetically-first industry gets the
	 * smaller count) and inserted smallest-group-first — so a dropped or ignored ORDER BY COUNT
	 * could not pass by coincidence of default or insertion ordering.
	 *
	 * @date July 2026
	 */
	@IsTest
	private static void shouldRankGroupsLargestFirstWithOrderByCount()
	{
		kern.UTIL_ValidationRule.bypassObject('Account');
		seedAccount('OrderByCount Solo', 'Agriculture', 1);
		seedAccount('OrderByCount One', 'Technology', 1);
		seedAccount('OrderByCount Two', 'Technology', 1);
		seedAccount('OrderByCount Three', 'Technology', 1);

		Test.startTest();

		List<kern.QRY_Builder.AggregateRow> rows = kern.QRY_Builder.selectFrom(Account.SObjectType)
				.condition(Account.Name).contains('OrderByCount')
				.groupBy(Account.Industry)
				.count(Account.Id, 'groupSize')
				.orderByCount(Account.Id, true)
				.toAggregateList();

		Test.stopTest();

		Assert.areEqual(2, rows.size(), 'One grouped row per seeded industry should be returned');
		Assert.areEqual('Technology', rows[0].getString('Industry'),
				'orderByCount descending should rank the three-record group first (alphabetical order would put Agriculture first)');
		Assert.areEqual(3, rows[0].getInteger('groupSize'), 'The leading group should carry its COUNT under the chosen alias');
		Assert.areEqual('Agriculture', rows[1].getString('Industry'), 'The single-record group should rank last');
		Assert.areEqual(1, rows[1].getInteger('groupSize'), 'The trailing group should carry its COUNT under the chosen alias');
	}

	/**
	 * @description The 1.3 single-argument `QRY_Condition.FieldCondition` constructors (SObjectField
	 * and String forms) paired with `contains()` must build executable standalone conditions from
	 * subscriber Apex — the documented way to assemble an OR group of contains matches and hand it
	 * to the builder via `addCondition`. Executes against seeded rows so the wrapped `%value%`
	 * pattern is proven end-to-end, not just rendered. The string-form condition uses `Phone`:
	 * `AccountNumber` (with `Site`, `Sic` and `TickerSymbol`) is no longer present on the Account
	 * entity in Summer '26 (v67) scratch orgs, and `Description` is a long text area and therefore
	 * not filterable.
	 *
	 * @date July 2026
	 */
	@IsTest
	private static void shouldFilterWithStandaloneContainsConditions()
	{
		kern.UTIL_ValidationRule.bypassObject('Account');
		seedAccount('QryContains Target', 'Technology', 1);
		seedAccount('Plain Control Row', 'Technology', 1);

		kern.QRY_Condition.OrCondition textMatch = new kern.QRY_Condition.OrCondition();
		textMatch.add(new kern.QRY_Condition.FieldCondition(Account.Name).contains('QryContains'));
		textMatch.add(new kern.QRY_Condition.FieldCondition('Phone').contains('QryContains'));

		Test.startTest();

		List<Account> matches = (List<Account>)kern.QRY_Builder.selectFrom(Account.SObjectType)
				.fields(new List<SObjectField> {Account.Name})
				.addCondition(textMatch)
				.toList();

		Test.stopTest();

		Assert.areEqual(1, matches.size(), 'Only the account whose Name contains the token should match the OR group');
		Assert.areEqual('QryContains Target', matches[0].Name, 'The contains match should be the seeded target row');
	}

	/**
	 * @description The alias on an aliased aggregate selection and on a projected function field
	 * is validated at the call site: anything other than a bare identifier (a letter followed by
	 * letters, digits or underscores) must throw `IllegalArgumentException` immediately, so a
	 * caller-supplied alias can never carry SOQL syntax into the generated clause.
	 *
	 * @date July 2026
	 */
	@IsTest
	private static void shouldRejectMalformedAliasAtCallSite()
	{
		Boolean aggregateAliasRejected = false;
		Boolean projectionAliasRejected = false;

		Test.startTest();

		try
		{
			kern.QRY_Builder.selectFrom(Account.SObjectType)
					.groupBy(Account.Industry)
					.count(Account.Id, 'not a bare identifier');
		}
		catch(IllegalArgumentException expected)
		{
			aggregateAliasRejected = true;
		}
		try
		{
			kern.QRY_Builder.selectFrom(Opportunity.SObjectType)
					.addField(kern.QRY_Function.calendarMonth(Opportunity.CloseDate), '1leadingDigit');
		}
		catch(IllegalArgumentException expected)
		{
			projectionAliasRejected = true;
		}

		Test.stopTest();

		Assert.isTrue(aggregateAliasRejected, 'An aliased aggregate should reject a non-identifier alias at the call site');
		Assert.isTrue(projectionAliasRejected, 'A projected function field should reject a non-identifier alias at the call site');
	}

	/**
	 * @description A cursor keeps the sharing the builder asked for. The administrator saves a private API call record
	 * that a Standard User with no permission set cannot see. As that user, a system-mode cursor with withSharing() finds
	 * nothing, and the same cursor with bypassSharing() counts the record and fetches it. System mode is needed on both,
	 * because a user-mode query always applies the user's sharing and this user has no access to the object at all.
	 *
	 * @date October 2026
	 */
	@IsTest
	private static void shouldFetchAnotherUsersPrivateRecordThroughACursorThatBypassesSharing()
	{
		User standardUser = kern.TST_Factory.insertUser(STANDARD_PROFILE);
		kern__ApiCall__c privateCall = insertPrivateCall();
		Integer recordsWithSharing;
		Integer recordsBypassingSharing;
		List<SObject> fetched;

		Test.startTest();

		System.runAs(standardUser)
		{
			recordsWithSharing = selectPrivateCall(privateCall.Id).withSharing().toCursor().getNumRecords();
			Database.Cursor bypassingCursor = selectPrivateCall(privateCall.Id).bypassSharing().toCursor();
			recordsBypassingSharing = bypassingCursor.getNumRecords();
			fetched = recordsBypassingSharing > 0 ? bypassingCursor.fetch(0, recordsBypassingSharing) : new List<SObject>();
		}

		Test.stopTest();

		Assert.areEqual(0, recordsWithSharing, 'Expected the cursor that keeps sharing to find none of the administrator\'s private records');
		Assert.areEqual(1, recordsBypassingSharing, 'Expected the cursor that bypasses sharing to count the administrator\'s private record');
		Assert.areEqual(privateCall.Id, fetched[0].Id, 'Expected the cursor that bypasses sharing to fetch the administrator\'s private record');
	}

	/**
	 * @description The query cache keeps a read only when it can tell whose rows the read returns. As a Standard User, two
	 * identical system-mode reads that leave their sharing to the calling class are not cached, so they run two queries.
	 * The same two reads with withSharing() run one query, because the second is answered from the cache. Two identical
	 * user-mode reads also run one query, because a user-mode read is kept for the rest of the transaction. The two
	 * system-mode pairs ask to be cached for this transaction only, so a kept read is held in memory and never in Platform
	 * Cache, which the platform may empty at any time. The rule that refuses to cache a read with no sharing stated does
	 * not depend on where the read would be kept. A first read that is not cached runs before the counting starts, so a
	 * setting the framework reads once per transaction is not counted.
	 *
	 * @date October 2026
	 */
	@IsTest
	private static void shouldCacheASystemModeReadOnlyWhenItStatesItsSharing()
	{
		User standardUser = kern.TST_Factory.insertUser(STANDARD_PROFILE);
		kern__ApiCall__c privateCall = insertPrivateCall();
		Integer queriesWithoutSharingStated;
		Integer queriesWithSharingStated;
		Integer queriesInUserMode;

		Test.startTest();

		System.runAs(standardUser)
		{
			selectPrivateCall(privateCall.Id).toList();

			Integer queriesBefore = kern.UTIL_Limits.soqlQueries().used();
			selectPrivateCall(privateCall.Id).withCache(kern.UTIL_Cache.Scope.IN_TRANSACTION, null).toList();
			selectPrivateCall(privateCall.Id).withCache(kern.UTIL_Cache.Scope.IN_TRANSACTION, null).toList();
			queriesWithoutSharingStated = kern.UTIL_Limits.soqlQueries().used() - queriesBefore;

			queriesBefore = kern.UTIL_Limits.soqlQueries().used();
			selectPrivateCall(privateCall.Id).withSharing().withCache(kern.UTIL_Cache.Scope.IN_TRANSACTION, null).toList();
			selectPrivateCall(privateCall.Id).withSharing().withCache(kern.UTIL_Cache.Scope.IN_TRANSACTION, null).toList();
			queriesWithSharingStated = kern.UTIL_Limits.soqlQueries().used() - queriesBefore;

			queriesBefore = kern.UTIL_Limits.soqlQueries().used();
			selectAccountsInUserMode().withCache(CACHE_SECONDS).toList();
			selectAccountsInUserMode().withCache(CACHE_SECONDS).toList();
			queriesInUserMode = kern.UTIL_Limits.soqlQueries().used() - queriesBefore;
		}

		Test.stopTest();

		Assert.areEqual(QUERIES_FOR_TWO_UNCACHED_READS, queriesWithoutSharingStated, 'Expected a system-mode read that leaves its sharing to the caller not to be cached');
		Assert.areEqual(QUERIES_FOR_TWO_CACHED_READS, queriesWithSharingStated, 'Expected a system-mode read that states withSharing() to be cached');
		Assert.areEqual(QUERIES_FOR_TWO_CACHED_READS, queriesInUserMode, 'Expected a user-mode read to be cached for the rest of the transaction');
	}

	/**
	 * @description Seeds one Account through the packaged test-data builder with the fields the
	 * aggregate and contains scenarios read back.
	 *
	 * @param name The account name (carries each scenario's match token).
	 * @param industry The grouping value for the aggregate scenarios.
	 * @param employees The numeric value the SUM/AVG/MIN/MAX scenarios fold.
	 *
	 * @date July 2026
	 */
	private static void seedAccount(String name, String industry, Integer employees)
	{
		kern.TST_Builder.of(Account.SObjectType)
				.withOverride(Account.Name, name)
				.withOverride(Account.Industry, industry)
				.withOverride(Account.NumberOfEmployees, employees)
				.build();
	}

	/**
	 * @description Finds the grouped aggregate row for an industry, failing the test with a clear
	 * message when the group is missing instead of throwing a null dereference.
	 *
	 * @param rows The grouped aggregate rows.
	 * @param industry The GROUP BY value to find.
	 *
	 * @return The matching aggregate row.
	 */
	private static kern.QRY_Builder.AggregateRow findGroup(List<kern.QRY_Builder.AggregateRow> rows, String industry)
	{
		for(kern.QRY_Builder.AggregateRow row : rows)
		{
			if(row.getString('Industry') == industry)
			{
				return row;
			}
		}
		Assert.fail('No grouped row returned for industry ' + industry);
		return null;
	}

	/**
	 * @description Saves, as the running administrator, the private API call record the sharing tests read. The object's
	 * sharing is Private, so only its owner and users with access to every record can see it.
	 *
	 * @return The saved record.
	 *
	 * @date October 2026
	 */
	private static kern__ApiCall__c insertPrivateCall()
	{
		return (kern__ApiCall__c)kern.TST_Builder.of(kern__ApiCall__c.SObjectType)
				.withOverride(kern__ApiCall__c.kern__ServiceName__c, PRIVATE_CALL_SERVICE_NAME)
				.withOverride(kern__ApiCall__c.kern__Direction__c, DIRECTION_OUTBOUND)
				.build();
	}

	/**
	 * @description Starts a system-mode read of the one private API call record. System mode skips the object and field
	 * checks, which this user would fail; the caller decides the record sharing.
	 *
	 * @param callId The Id of the private API call record.
	 *
	 * @return The builder, ready for a sharing choice, a cache choice and a terminal call.
	 *
	 * @date October 2026
	 */
	private static kern.QRY_Builder.Builder selectPrivateCall(Id callId)
	{
		return kern.QRY_Builder.selectFrom(kern__ApiCall__c.SObjectType)
				.fields(new List<SObjectField> {kern__ApiCall__c.kern__ServiceName__c})
				.condition(kern__ApiCall__c.Id).equals(callId)
				.withSystemMode();
	}

	/**
	 * @description Starts a user-mode read of accounts by name, an object a Standard User may read.
	 *
	 * @return The builder, ready for a cache choice and a terminal call.
	 *
	 * @date October 2026
	 */
	private static kern.QRY_Builder.Builder selectAccountsInUserMode()
	{
		return kern.QRY_Builder.selectFrom(Account.SObjectType)
				.fields(new List<SObjectField> {Account.Name})
				.condition(Account.Name).equals(CACHED_ACCOUNT_NAME)
				.withUserMode();
	}

	/**
	 * @description Creates a Standard User with no kern managed-package permission sets. The
	 * test context never commits this user — they exist only for the scope of `System.runAs`.
	 *
	 * @return The Standard User instance.
	 */
	private static User createStandardUser()
	{
		Profile standardProfile =
		[
				SELECT Id
				FROM Profile
				WHERE Name = :STANDARD_PROFILE
				LIMIT 1
		];
		String suffix = String.valueOf(Crypto.getRandomInteger()).right(8);
		User standardUser = new User
				(
						FirstName = 'QryEdges',
						LastName = 'Subscriber',
						Email = 'qry-edges-' + suffix + '@kerndx.test',
						Username = 'qry-edges-' + suffix + '@kerndx.test.invalid',
						Alias = 'qry' + suffix.right(3),
						TimeZoneSidKey = 'America/New_York',
						LocaleSidKey = 'en_US',
						EmailEncodingKey = 'UTF-8',
						LanguageLocaleKey = 'en_US',
						ProfileId = standardProfile.Id
				);
		insert standardUser;
		return standardUser;
	}
}
