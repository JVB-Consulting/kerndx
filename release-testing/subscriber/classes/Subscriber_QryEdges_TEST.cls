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
 * @see kern.QRY_Builder
 * @see kern.QRY_Function
 * @see kern.UTIL_FeatureFlag
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date May 2026, June 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=false)
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

		Assert.isTrue(queriedCleanly, '.stripInaccessible() should swallow FLS restrictions and return an empty list for a Standard User without kern__Foobar__c read. Got exception: ' + thrownTypeName);
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
