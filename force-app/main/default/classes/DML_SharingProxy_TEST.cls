// SPDX-License-Identifier: Apache-2.0
/**
 * @description Tests the DML sharing proxy class for sharing enforcement and bypass behaviour.
 *
 * @see DML_SharingProxy
 *
 * @author Jason van Beukering
 *
 * @group DML
 *
 * @date February 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=false)
private class DML_SharingProxy_TEST
{
	/**
	 * @description Whether the `AccessLevel` passed to the async job was still the same object as
	 * `AccessLevel.SYSTEM_MODE` when the job ran, compared with `==`.
	 */
	private static Boolean roundTrippedMatchesSystemModeByIdentity;

	/**
	 * @description Whether DML_SharingProxy.matchesAccessLevel saw the `AccessLevel` passed to the async job as
	 * SYSTEM_MODE.
	 */
	private static Boolean comparatorResolvesSystemMode;

	/**
	 * @description Whether DML_SharingProxy.matchesAccessLevel wrongly saw the `AccessLevel` passed to the async
	 * job as USER_MODE.
	 */
	private static Boolean comparatorResolvesUserMode;

	/**
	 * @description An async job that carries `AccessLevel.SYSTEM_MODE` from the code that queues it to the code
	 * that runs it. When a job is queued, the platform saves its data and rebuilds it when the job runs. This is the
	 * only way to save and rebuild an `AccessLevel`, because `JSON.serialize` and `JSON.deserialize` both reject
	 * the type. When the job runs, it records how `==` and DML_SharingProxy.matchesAccessLevel each see the
	 * rebuilt value.
	 */
	public class AccessLevelRoundTripProbe implements IF_Async.Processable
	{
		/**
		 * @description The access level the platform saves and rebuilds with the job. It starts as
		 * `AccessLevel.SYSTEM_MODE` so that the rebuilt value can be compared with it.
		 */
		public AccessLevel carriedAccessLevel = System.AccessLevel.SYSTEM_MODE;

		/**
		 * @description Records how `==` and the comparison method see the rebuilt value, in static fields the
		 * test reads.
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
	 * @description Tests that DML_SharingProxy.matchesAccessLevel still finds the right mode after an
	 * `AccessLevel` has passed through an async job. The test runs the job through the real async code, so the
	 * platform saves and rebuilds the value. It then checks that `==` no longer matches, which is the trap the
	 * method exists for, and that the method still finds SYSTEM_MODE. If the platform changes how it saves or
	 * prints an access level, this test fails clearly. Without it, production code could quietly pick the
	 * wrong mode.
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
				'The rebuilt AccessLevel should not match with ==. If it does, the platform now keeps the same object and the fallback comparison is not tested');
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
	 * @description A stand-in proxy that a test installs through DML_SharingProxy.sharingProxyForTest. The test only
	 * checks which proxy getSharingProxy returns, so none of the inherited DML methods is ever called here.
	 */
	private class StandInProxy extends DML_SharingProxy.DatabaseProxy
	{
	}

	/**
	 * @description Tests that getSharingProxy returns the installed stand-in for every sharing type while
	 * sharingProxyForTest is set. Once it is cleared, getSharingProxy returns the proxy for the sharing type again.
	 * This is how a test can act like the platform and refuse a save.
	 *
	 * @see DML_SharingProxy.getSharingProxy
	 */
	@IsTest
	private static void getSharingProxyShouldReturnTheInstalledStandIn()
	{
		DML_SharingProxy.DatabaseProxy standIn = new StandInProxy();
		DML_SharingProxy.sharingProxyForTest = standIn;

		try
		{
			Assert.areEqual(standIn, DML_SharingProxy.getSharingProxy(DML_SharingProxy.SharingType.BYPASS), 'The stand-in should replace the bypass proxy');
			Assert.areEqual(standIn, DML_SharingProxy.getSharingProxy(DML_SharingProxy.SharingType.ENFORCE), 'The stand-in should replace the enforce proxy');
			Assert.areEqual(standIn, DML_SharingProxy.getSharingProxy(DML_SharingProxy.SharingType.INHERITED), 'The stand-in should replace the inherited proxy');
		}
		finally
		{
			DML_SharingProxy.sharingProxyForTest = null;
		}

		Assert.isFalse(DML_SharingProxy.getSharingProxy(DML_SharingProxy.SharingType.BYPASS) instanceof StandInProxy, 'Clearing the stand-in should restore the normal proxy');
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