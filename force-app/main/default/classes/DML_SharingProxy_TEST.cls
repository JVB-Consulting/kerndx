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
 * @date February 2026, June 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=false)
private class DML_SharingProxy_TEST
{
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