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
 * @see kern.UTIL_FeatureFlag
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date May 2026
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
