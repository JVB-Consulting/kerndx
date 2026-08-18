// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests the DML sharing proxy class for sharing enforcement and bypass behaviour.
 *
 * @see DML_SharingProxy
 *
 * @author Jason van Beukering
 *
 * @group DML
 *
 * @date February 2026, August 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=false)
private class DML_SharingProxy_TEST
{
	/**
	 * @description Whether the round-tripped `AccessLevel` still identity-matched the
	 * `SYSTEM_MODE` singleton inside the async execution context.
	 */
	private static Boolean roundTrippedMatchesSystemModeByIdentity;

	/**
	 * @description Whether the comparator resolved the round-tripped `AccessLevel` as SYSTEM_MODE.
	 */
	private static Boolean comparatorResolvesSystemMode;

	/**
	 * @description Whether the comparator wrongly resolved the round-tripped `AccessLevel` as USER_MODE.
	 */
	private static Boolean comparatorResolvesUserMode;

	/**
	 * @description Probe payload for the serialization round-trip fence. Carries the `SYSTEM_MODE`
	 * singleton through the platform's own async serializer — the only mechanism that round-trips
	 * an `AccessLevel`, since `JSON.serialize`/`JSON.deserialize` both reject the type — and
	 * records, from inside the deserialized execution context, how raw identity comparison and the
	 * comparator each resolve it.
	 */
	public class AccessLevelRoundTripProbe implements IF_Async.Processable
	{
		/**
		 * @description The access level carried through the platform async serializer; seeded with
		 * the live `SYSTEM_MODE` singleton so the deserialized instance can be compared against it.
		 */
		public AccessLevel carriedAccessLevel = System.AccessLevel.SYSTEM_MODE;

		/**
		 * @description Captures the identity and comparator observations into test statics.
		 *
		 * @param items The list of objects to process; the probe ignores their content.
		 */
		public void execute(List<Object> items)
		{
			roundTrippedMatchesSystemModeByIdentity = carriedAccessLevel == System.AccessLevel.SYSTEM_MODE;
			comparatorResolvesSystemMode = DML_SharingProxy.matchesAccessLevel(carriedAccessLevel, System.AccessLevel.SYSTEM_MODE);
			comparatorResolvesUserMode = DML_SharingProxy.matchesAccessLevel(carriedAccessLevel, System.AccessLevel.USER_MODE);
		}
	}

	/**
	 * @description Round-trip fence for the serialization-safe access-mode comparator. Drives the
	 * probe through the real async machinery so the platform serializer round-trips the carried
	 * `AccessLevel`, then asserts raw `==` fails (pinning the identity-loss trap) while the
	 * comparator resolves the mode correctly. A platform serialization or rendering-format change
	 * fails this test loudly instead of silently degrading production mode selection.
	 *
	 * @see DML_SharingProxy.matchesAccessLevel
	 */
	@IsTest
	private static void shouldResolveAccessLevelAcrossSerializationBoundary()
	{
		Test.startTest();

		UTIL_AsynchronousJobLauncher.process(new List<Object> {'round-trip-probe'}, new AccessLevelRoundTripProbe());

		Test.stopTest();

		Assert.isFalse(roundTrippedMatchesSystemModeByIdentity,
				'Round-tripped AccessLevel must fail raw identity comparison — if it holds, the platform now preserves identity and the comparator fallback is unexercised');
		Assert.isTrue(comparatorResolvesSystemMode, 'Comparator must resolve the round-tripped AccessLevel as SYSTEM_MODE');
		Assert.isFalse(comparatorResolvesUserMode, 'Comparator must not resolve the round-tripped SYSTEM_MODE as USER_MODE');
	}

	/**
	 * @description Tests bypass behaviour for all DML methods.
	 *
	 * @see DML_SharingProxy.DatabaseProxyWithoutSharing
	 */
	@IsTest
	private static void shouldBypassSharingForAllOperations()
	{
		DML_SharingProxy.DatabaseProxy proxy = DML_SharingProxy.getSharingProxy(DML_SharingProxy.SharingType.BYPASS);

		Foobar__c newFoobar = TST_Factory.insertFoobar();
		List<Foobar__c> foobars = new List<Foobar__c> {newFoobar};

		try
		{
			System.runAs(TST_Factory.newUser(SEL_Profile.PROFILE_STANDARD_USER))
			{
				Test.startTest();

				newFoobar.Name = UTIL_Random.randomAlphabetic(10);

				proxy.doUpdate(foobars, true, System.AccessLevel.SYSTEM_MODE);
				newFoobar.Name = UTIL_Random.randomAlphabetic(10);

				proxy.doUpsert(foobars, true, System.AccessLevel.SYSTEM_MODE);
				proxy.doDelete(foobars, true, System.AccessLevel.SYSTEM_MODE);
				proxy.doUndelete(foobars, true, System.AccessLevel.SYSTEM_MODE);

				foobars.clear();

				Foobar__c newFoobar2 = TST_Factory.newFoobar();
				newFoobar2.Lookup__c = newFoobar.Id;
				foobars.add(newFoobar2);

				proxy.doInsert(foobars, true, System.AccessLevel.SYSTEM_MODE);

				foobars.clear();

				Foobar__c newFoobar3 = TST_Factory.newFoobar();
				foobars.add(newFoobar3);

				proxy.doUpsert(foobars, Foobar__c.ExternalId__c, true, System.AccessLevel.SYSTEM_MODE);

				Test.stopTest();
			}
		}
		catch(Exception error)
		{
			Assert.fail('Sharing was not bypassed as expected.\n' + error.getMessage());
		}
	}

	/**
	 * @description Tests enforcement of sharing rules for delete operations.
	 *
	 * @see DML_SharingProxy.DatabaseProxyWithSharing
	 */
	@IsTest
	private static void shouldEnforceSharingForDelete()
	{
		assertSharingEnforced(TST_Factory.insertFoobar(), 'DELETE');
	}

	/**
	 * @description Tests enforcement of sharing rules for update operations.
	 *
	 * @see DML_SharingProxy.DatabaseProxyWithSharing
	 */
	@IsTest
	private static void shouldEnforceSharingForUpdate()
	{
		assertSharingEnforced(TST_Factory.insertFoobar(), 'UPDATE');
	}

	/**
	 * @description Tests enforcement of sharing rules for upsert operations.
	 *
	 * @see DML_SharingProxy.DatabaseProxyWithSharing
	 */
	@IsTest
	private static void shouldEnforceSharingForUpsert()
	{
		assertSharingEnforced(TST_Factory.insertFoobar(), 'UPSERT');
	}

	/**
	 * @description Tests enforcement of sharing rules for insert operations.
	 *
	 * @see DML_SharingProxy.DatabaseProxyWithSharing
	 */
	@IsTest
	private static void shouldEnforceSharingForInsert()
	{
		assertSharingEnforced(TST_Factory.newFoobar(), 'INSERT');
	}

	/**
	 * @description Tests enforcement of sharing rules for undelete operations.
	 *
	 * @see DML_SharingProxy.DatabaseProxyWithSharing
	 */
	@IsTest
	private static void shouldEnforceSharingForUndelete()
	{
		Foobar__c newFoobar = TST_Factory.insertFoobar();
		delete newFoobar;

		assertSharingEnforced(newFoobar, 'UNDELETE');
	}

	/**
	 * @description Tests inherited sharing for delete operations.
	 *
	 * @see DML_SharingProxy.DatabaseProxy
	 */
	@IsTest
	private static void shouldInheritSharingForDelete()
	{
		Foobar__c newFoobar = TST_Factory.insertFoobar();

		DML_SharingProxy.DatabaseProxy proxy = DML_SharingProxy.getSharingProxy(DML_SharingProxy.SharingType.INHERITED);

		try
		{
			System.runAs(TST_Factory.newUser(SEL_Profile.PROFILE_STANDARD_USER))
			{
				proxy.doDelete(new List<Foobar__c> {newFoobar}, true, System.AccessLevel.SYSTEM_MODE);
				Assert.fail('Expected exception to be thrown');
			}
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, DmlException.class, 'Incorrect Exception thrown: ' + error.getTypeName());
		}
	}

	/**
	 * @description Tests enforcement of sharing rules for external ID upsert operations.
	 *
	 * @see DML_SharingProxy.DatabaseProxyWithSharing
	 */
	@IsTest
	private static void shouldEnforceSharingForExternalIdUpsert()
	{
		// Commit through the SYSTEM_MODE factory path: a raw insert validates against the test-running
		// user, who lacks the packaged record type and field access in namespaced packaging/subscriber orgs.
		Foobar__c existingRecord = TST_Factory.insertFoobar();

		DML_SharingProxy.DatabaseProxy proxy = DML_SharingProxy.getSharingProxy(DML_SharingProxy.SharingType.ENFORCE);

		Foobar__c upsertRecord = TST_Factory.newFoobar();
		upsertRecord.ExternalId__c = existingRecord.ExternalId__c;
		upsertRecord.Name = 'Updated Record';

		try
		{
			System.runAs(TST_Factory.newUser(SEL_Profile.PROFILE_STANDARD_USER))
			{
				Test.startTest();

				proxy.doUpsert(new List<Foobar__c> {upsertRecord}, Foobar__c.ExternalId__c, true, System.AccessLevel.SYSTEM_MODE);

				Test.stopTest();

				Assert.fail('Expected sharing exception for unauthorized External ID match');
			}
		}
		catch(Exception error)
		{
			Boolean isValidError = (error instanceof SecurityException) || (error instanceof DmlException);
			Assert.isTrue(isValidError, 'Expected SecurityException or DmlException, but caught: ' + error.getTypeName());
		}
	}

	/**
	 * @description Asserts that sharing rules are enforced for the given operation.
	 *
	 * @param record The record to perform DML on.
	 * @param operation The DML operation name.
	 */
	private static void assertSharingEnforced(Foobar__c record, String operation)
	{
		List<Foobar__c> foobars = new List<Foobar__c> {record};
		DML_SharingProxy.DatabaseProxy proxy = DML_SharingProxy.getSharingProxy(DML_SharingProxy.SharingType.ENFORCE);

		try
		{
			System.runAs(TST_Factory.newUser(SEL_Profile.PROFILE_STANDARD_USER))
			{
				Test.startTest();

				if(operation == 'DELETE')
				{
					proxy.doDelete(foobars, true, System.AccessLevel.SYSTEM_MODE);
				}
				else if(operation == 'UPDATE')
				{
					proxy.doUpdate(foobars, true, System.AccessLevel.SYSTEM_MODE);
				}
				else if(operation == 'UPSERT')
				{
					proxy.doUpsert(foobars, true, System.AccessLevel.SYSTEM_MODE);
				}
				else if(operation == 'INSERT')
				{
					proxy.doInsert(foobars, true, System.AccessLevel.SYSTEM_MODE);
					return;
				}
				else if(operation == 'UNDELETE')
				{
					proxy.doUndelete(foobars, true, System.AccessLevel.SYSTEM_MODE);
				}

				Test.stopTest();

				Assert.fail('Sharing not enforced for ' + operation);
			}
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, DmlException.class, 'Incorrect Exception thrown: ' + error.getTypeName());
		}
	}
}