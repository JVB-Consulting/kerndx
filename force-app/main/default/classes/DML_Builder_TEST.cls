// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for DML_Builder.
 *
 * @see DML_Builder
 *
 * @author Jason van Beukering
 *
 * @group DML
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CognitiveComplexity,PMD.CyclomaticComplexity')
@IsTest(SeeAllData=false IsParallel=false)
private class DML_Builder_TEST
{
	private static final String TEST_ADMIN_COMPANY = 'DML_Builder_TEST-admin';
	private static final String LOW_PRIVILEGE_COMPANY = 'DML_Builder_TEST-low-privilege';

	/**
	 * @description Assertion message for value equality checks.
	 */
	private static final String MSG_VALUE_EQUALITY = 'Value should match expected';

	/**
	 * @description Creates a dedicated test admin user so System.runAs in each test starts a fresh
	 * permission-evaluation context, bypassing the synthetic-org permission-cache staleness issue
	 * that affected mutating the running user's permissionSet mid-transaction. Also commits a
	 * low-privilege user (Minimum Access - Salesforce profile) so the tier-A regression test
	 * (shouldRejectAsyncUserModeUpdateForLowPrivilegeUser) can use System.runAs without triggering
	 * MIXED_DML_OPERATION — User is a Setup object, User DML cannot mix with standard/custom-object
	 * DML in the same transaction; pre-provisioning here satisfies that boundary.
	 */
	@TestSetup
	private static void setupTestUsers()
	{
		TST_Factory.newUserWithPermissionSet
				(
						SEL_Profile.PROFILE_SYSTEM_ADMIN,
						TEST_ADMIN_COMPANY,
						SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME
				);

		User lowPrivilegeUser = TST_Factory.newMinimumAccessUser(LOW_PRIVILEGE_COMPANY);
		insert lowPrivilegeUser;
	}

	/**
	 * @description Tests all single-record DML operations (insert, update, upsert, delete, undelete).
	 */
	@IsTest
	private static void shouldPerformAllDmlOperationsSuccessfully()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doInsert(record)
					.execute();

			Assert.isNotNull(record.Id, 'Record should have an Id after insert');

			String updatedName = UTIL_Random.randomName();
			record.Name = updatedName;

			DML_Builder.newTransaction()
					.withSystemMode()
					.doUpdate(record)
					.execute();

			Foobar__c found = (Foobar__c)new SEL_Foobar().findById(record.Id);
			Assert.areEqual(updatedName, found.Name, MSG_VALUE_EQUALITY);

			DML_Builder.newTransaction()
					.withSystemMode()
					.doUpsert(record)
					.execute();

			found = (Foobar__c)new SEL_Foobar().findById(record.Id);
			Assert.isNotNull(found, 'Record should exist after upsert');

			DML_Builder.newTransaction()
					.withSystemMode()
					.doDelete(record)
					.execute();

			found = (Foobar__c)new SEL_Foobar().findById(record.Id);
			Assert.isNull(found, 'Record should be deleted');

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doUndelete(record)
					.execute();

			Test.stopTest();

			found = (Foobar__c)new SEL_Foobar().findById(record.Id);
			Assert.isNotNull(found, 'Record should be undeleted');
		}
	}

	/**
	 * @description Tests insert and update list overloads.
	 */
	@IsTest
	private static void shouldPerformListOperationsSuccessfully()
	{
		System.runAs(getTestAdmin())
		{
			List<SObject> records = TST_Builder.of(Foobar__c.SObjectType)
					.withCount(3)
					.withoutInsertion()
					.buildList();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doInsert(records)
					.execute();

			for(SObject record : records)
			{
				Assert.isNotNull(record.Id, 'Record should have an Id');
			}

			String updatedName = UTIL_Random.randomName();
			for(SObject record : records)
			{
				((Foobar__c)record).Name = updatedName;
			}

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doUpdate(records)
					.execute();

			Test.stopTest();

			List<Foobar__c> found = new SEL_Foobar().getAll();
			Assert.areEqual(3, found.size(), MSG_VALUE_EQUALITY);
			for(Foobar__c foundRecord : found)
			{
				Assert.areEqual(updatedName, foundRecord.Name, MSG_VALUE_EQUALITY);
			}
		}
	}

	/**
	 * @description Tests that an empty transaction executes without error.
	 */
	@IsTest
	private static void shouldHandleEmptyTransactionWithoutError()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();

			DML_Builder.newTransaction().withSystemMode().execute();

			Test.stopTest();

			Assert.isTrue(new SEL_Foobar().getAll().isEmpty(), 'No records should exist');
		}
	}

	/**
	 * @description Tests upsert with an external ID field.
	 */
	@IsTest
	private static void shouldUpsertWithExternalIdField()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.ExternalId__c, 'EXT-BUILDER-001')
					.withoutInsertion()
					.build();

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doUpsert(record, Foobar__c.ExternalId__c)
					.execute();

			Test.stopTest();

			Assert.isNotNull(record.Id, 'Record should have an Id after upsert');
			Foobar__c found = (Foobar__c)new SEL_Foobar().findById(record.Id);
			Assert.areEqual('EXT-BUILDER-001', found.ExternalId__c, MSG_VALUE_EQUALITY);
		}
	}

	/**
	 * @description Tests upsert list overload with an external ID field.
	 */
	@IsTest
	private static void shouldUpsertListWithExternalIdField()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record1 = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.ExternalId__c, 'EXT-LIST-001')
					.withoutInsertion()
					.build();

			Foobar__c record2 = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.ExternalId__c, 'EXT-LIST-002')
					.withoutInsertion()
					.build();

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doUpsert(new List<SObject> {record1, record2}, Foobar__c.ExternalId__c)
					.execute();

			Test.stopTest();

			List<Foobar__c> found = new SEL_Foobar().getAll();
			Assert.areEqual(2, found.size(), MSG_VALUE_EQUALITY);
		}
	}

	/**
	 * @description Tests delete and undelete list overloads.
	 */
	@IsTest
	private static void shouldDeleteAndUndeleteList()
	{
		System.runAs(getTestAdmin())
		{
			List<SObject> records = TST_Builder.of(Foobar__c.SObjectType)
					.withCount(2)
					.buildList();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doDelete(records)
					.execute();

			Assert.isTrue(new SEL_Foobar().getAll().isEmpty(), 'Records should be deleted');

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doUndelete(records)
					.execute();

			Test.stopTest();

			Assert.areEqual(2, new SEL_Foobar().getAll().size(), 'Records should be undeleted');
		}
	}

	/**
	 * @description Tests that allowPartial mode does not throw on partial failure.
	 */
	@IsTest
	private static void shouldAllowPartialSuccess()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c validRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doInsert(validRecord)
					.allowPartial()
					.execute();

			Test.stopTest();

			Assert.isNotNull(validRecord.Id, 'Valid record should have been inserted');
		}
	}

	/**
	 * @description Tests that bypassSharing allows DML for restricted users.
	 */
	@IsTest
	private static void shouldBypassSharingForInsert()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
			record.Name = UTIL_Random.randomName();

			try
			{
				System.runAs(TST_Factory.newUser(SEL_Profile.PROFILE_STANDARD_USER))
				{
					Test.startTest();

					DML_Builder.newTransaction()
							.withSystemMode()
							.doUpdate(record)
							.bypassSharing()
							.execute();

					Test.stopTest();
				}
			}
			catch(Exception error)
			{
				Assert.fail('Sharing should have been bypassed: ' + error.getMessage());
			}
		}
	}

	/**
	 * @description Tests that suppressLogging prevents error logging in partial mode.
	 */
	@IsTest
	private static void shouldSuppressLogging()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doInsert(record)
					.allowPartial()
					.suppressLogging()
					.execute();

			Test.stopTest();

			Assert.isNotNull(record.Id, 'Record should have been inserted');
		}
	}

	/**
	 * @description Tests that suppressExceptions prevents DmlException from being thrown.
	 */
	@IsTest
	private static void shouldSuppressExceptionOnFailure()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doUpdate(record)
					.suppressExceptions()
					.execute();

			Test.stopTest();

			Assert.isNull(record.Id, 'Record should not have an Id');
		}
	}

	/**
	 * @description Tests that default all-or-nothing mode throws DmlException on failure.
	 */
	@IsTest
	private static void shouldThrowByDefault()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			try
			{
				DML_Builder.newTransaction()
						.withSystemMode()
						.doUpdate(record)
						.execute();

				Assert.fail('Expected DmlException');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, DmlException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests chaining doInsert and doUpdate operations.
	 */
	@IsTest
	private static void shouldExecuteChainedInsertAndUpdate()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c insertRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			Foobar__c existingRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
			String updatedName = UTIL_Random.randomName();
			existingRecord.Name = updatedName;

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doInsert(insertRecord)
					.doUpdate(existingRecord)
					.execute();

			Test.stopTest();

			Assert.isNotNull(insertRecord.Id, 'Inserted record should have an Id');
			Foobar__c found = (Foobar__c)new SEL_Foobar().findById(existingRecord.Id);
			Assert.areEqual(updatedName, found.Name, MSG_VALUE_EQUALITY);
		}
	}

	/**
	 * @description Tests chaining parent and child inserts with a relationship field.
	 */
	@IsTest
	private static void shouldExecuteChainedParentChildInsert()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c parent = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			Foobar__c child = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doInsert(parent)
					.doInsert(child, Foobar__c.Lookup__c, parent)
					.execute();

			Test.stopTest();

			Assert.isNotNull(parent.Id, 'Parent should have an Id');
			Foobar__c foundChild = (Foobar__c)new SEL_Foobar().findById(child.Id);
			Assert.areEqual(parent.Id, foundChild.Lookup__c, MSG_VALUE_EQUALITY);
		}
	}

	/**
	 * @description Tests chained operations with bypass sharing.
	 */
	@IsTest
	private static void shouldExecuteChainedWithBypassSharing()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record1 = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			Foobar__c record2 = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			try
			{
				System.runAs(TST_Factory.newUser(SEL_Profile.PROFILE_STANDARD_USER))
				{
					Test.startTest();

					DML_Builder.newTransaction()
							.withSystemMode()
							.doInsert(record1)
							.doInsert(record2)
							.bypassSharing()
							.execute();

					Test.stopTest();
				}
			}
			catch(Exception error)
			{
				Assert.fail('Sharing should have been bypassed: ' + error.getMessage());
			}

			Assert.isNotNull(record1.Id, 'Record 1 should have an Id');
			Assert.isNotNull(record2.Id, 'Record 2 should have an Id');
		}
	}

	/**
	 * @description Tests chained operations with partial success mode.
	 */
	@IsTest
	private static void shouldExecuteChainedWithPartialSuccess()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c insertRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			Foobar__c updateRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
			updateRecord.Name = UTIL_Random.randomName();

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doInsert(insertRecord)
					.doUpdate(updateRecord)
					.allowPartial()
					.execute();

			Test.stopTest();

			Assert.isNotNull(insertRecord.Id, 'Inserted record should have an Id');
		}
	}

	/**
	 * @description Tests doUpsert list overload without an external ID field.
	 */
	@IsTest
	private static void shouldUpsertListWithoutExternalIdField()
	{
		System.runAs(getTestAdmin())
		{
			List<SObject> records = TST_Builder.of(Foobar__c.SObjectType)
					.withCount(2)
					.withoutInsertion()
					.buildList();

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doUpsert(records)
					.execute();

			Test.stopTest();

			List<Foobar__c> found = new SEL_Foobar().getAll();
			Assert.areEqual(2, found.size(), MSG_VALUE_EQUALITY);
		}
	}

	/**
	 * @description Tests that a chained transaction throws DmlException on failure.
	 */
	@IsTest
	private static void shouldThrowOnChainedFailure()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c validRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			Foobar__c invalidRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			try
			{
				DML_Builder.newTransaction()
						.withSystemMode()
						.doInsert(validRecord)
						.doUpdate(invalidRecord)
						.execute();

				Assert.fail('Expected DmlException');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, DmlException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests chained upsert without external ID routes through transaction path.
	 */
	@IsTest
	private static void shouldExecuteChainedUpsertWithoutExternalId()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record1 = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			Foobar__c record2 = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doInsert(record1)
					.doUpsert(record2)
					.execute();

			Test.stopTest();

			Assert.isNotNull(record1.Id, 'Record 1 should have an Id');
			Assert.isNotNull(record2.Id, 'Record 2 should have an Id');
		}
	}

	/**
	 * @description Tests suppressExceptions in a chained transaction path.
	 */
	@IsTest
	private static void shouldSuppressExceptionOnChainedFailure()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c validRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			Foobar__c invalidRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doInsert(validRecord)
					.doUpdate(invalidRecord)
					.suppressExceptions()
					.execute();

			Test.stopTest();

			Foobar__c found = (Foobar__c)new SEL_Foobar().findById(validRecord.Id);
			Assert.isNull(found, 'Insert should have been rolled back');
		}
	}

	/**
	 * @description Tests chained undelete operation in the transaction path.
	 */
	@IsTest
	private static void shouldExecuteChainedWithUndelete()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record1 = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
			TST_Builder.of(Foobar__c.SObjectType).build();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doDelete(record1)
					.execute();

			Foobar__c record3 = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doInsert(record3)
					.doUndelete(record1)
					.execute();

			Test.stopTest();

			Assert.isNotNull(record3.Id, 'New record should have an Id');
			Foobar__c found = (Foobar__c)new SEL_Foobar().findById(record1.Id);
			Assert.isNotNull(found, 'Record should be undeleted');
		}
	}

	/**
	 * @description Tests chained undelete with bypass sharing in the transaction path.
	 */
	@IsTest
	private static void shouldExecuteChainedUndeleteWithBypassSharing()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doDelete(record)
					.execute();

			Foobar__c insertRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doInsert(insertRecord)
					.doUndelete(record)
					.bypassSharing()
					.execute();

			Test.stopTest();

			Assert.isNotNull(insertRecord.Id, 'New record should have an Id');
		}
	}

	/**
	 * @description Tests chained delete in the transaction path.
	 */
	@IsTest
	private static void shouldExecuteChainedWithDelete()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record1 = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
			Foobar__c record2 = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doInsert(record2)
					.doDelete(record1)
					.execute();

			Test.stopTest();

			Assert.isNotNull(record2.Id, 'Inserted record should have an Id');
			Foobar__c found = (Foobar__c)new SEL_Foobar().findById(record1.Id);
			Assert.isNull(found, 'Deleted record should not exist');
		}
	}

	/**
	 * @description Tests chained upsert with external ID in the transaction path.
	 */
	@IsTest
	private static void shouldExecuteChainedUpsertWithExternalId()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record1 = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			Foobar__c record2 = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.ExternalId__c, 'EXT-CHAINED-001')
					.withoutInsertion()
					.build();

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doInsert(record1)
					.doUpsert(record2, Foobar__c.ExternalId__c)
					.execute();

			Test.stopTest();

			Assert.isNotNull(record1.Id, 'Inserted record should have an Id');
			Assert.isNotNull(record2.Id, 'Upserted record should have an Id');
		}
	}

	/**
	 * @description Tests async insert via DML_AsyncBuilder.
	 */
	@IsTest
	private static void shouldInsertRecordsAsynchronously()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> records = TST_Factory.newFoobars(5);

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doInsert(records)
					.async()
					.execute();

			Test.stopTest();

			Assert.areEqual(5, new SEL_Foobar().getAll().size(), 'Should have inserted 5 records asynchronously');
		}
	}

	/**
	 * @description Tests async delete via DML_AsyncBuilder.
	 */
	@IsTest
	private static void shouldDeleteRecordsAsynchronously()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> records = TST_Factory.insertFoobars(5);

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doDelete(records)
					.async()
					.execute();

			Test.stopTest();

			Assert.isTrue(new SEL_Foobar().getAll().isEmpty(), 'All records should be deleted asynchronously');
		}
	}

	/**
	 * @description Tests async update with partial success via DML_AsyncBuilder.
	 */
	@IsTest
	private static void shouldUpdateRecordsAsynchronouslyWithPartialSuccess()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> records = TST_Factory.insertFoobars(5);
			Datetime testDateTime = UTIL_Random.randomDateTime();

			for(Foobar__c record : records)
			{
				record.Datetime__c = testDateTime;
			}

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doUpdate(records)
					.allowPartial()
					.async()
					.execute();

			Test.stopTest();

			List<Foobar__c> updatedRecords = new SEL_Foobar().getAll();
			for(Foobar__c record : updatedRecords)
			{
				Assert.areEqual(testDateTime, record.Datetime__c, MSG_VALUE_EQUALITY);
			}
		}
	}

	/**
	 * @description Tests async DML with batch size override.
	 */
	@IsTest
	private static void shouldExecuteAsyncWithBatchSize()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> records = TST_Factory.insertFoobars(5);

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doDelete(records)
					.async()
					.withBatchSize(2)
					.execute();

			Test.stopTest();

			Assert.isTrue(new SEL_Foobar().getAll().isEmpty(), 'All records should be deleted asynchronously with batch size');
		}
	}

	/**
	 * @description Tests that async with no operations is a no-op.
	 */
	@IsTest
	private static void shouldHandleEmptyAsyncOperations()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.async()
					.execute();

			Test.stopTest();

			Assert.isTrue(new SEL_Foobar().getAll().isEmpty(), 'No records should exist after empty async execution');
		}
	}

	/**
	 * @description Tests that execute returns a success result with correct inserted IDs.
	 */
	@IsTest
	private static void shouldReturnSuccessResultWithInsertedIds()
	{
		System.runAs(getTestAdmin())
		{
			List<SObject> records = TST_Builder.of(Foobar__c.SObjectType)
					.withCount(3)
					.withoutInsertion()
					.buildList();

			Test.startTest();

			DML_Builder.TransactionResult result = DML_Builder.newTransaction()
					.withSystemMode()
					.doInsert(records)
					.execute();

			Test.stopTest();

			Assert.isTrue(result.isSuccess(), 'Transaction should be successful');
			Assert.areEqual(3, result.getInsertedIds().size(), 'Should have 3 inserted IDs');
			Assert.areEqual(3, result.getSuccessCount(), 'Should have 3 successes');
			Assert.areEqual(0, result.getFailureCount(), 'Should have 0 failures');
			Assert.isTrue(result.getErrors().isEmpty(), 'Should have no errors');
		}
	}

	/**
	 * @description Tests that execute returns a result reflecting partial failures.
	 */
	@IsTest
	private static void shouldReturnPartialResultWithErrors()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c validRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			Foobar__c invalidRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Email__c, 'not-a-valid-email')
					.withoutInsertion()
					.build();

			Test.startTest();

			DML_Builder.TransactionResult result = DML_Builder.newTransaction()
					.withSystemMode()
					.doInsert(new List<SObject> {validRecord, invalidRecord})
					.allowPartial()
					.execute();

			Test.stopTest();

			Assert.isFalse(result.isSuccess(), 'Transaction should not be fully successful');
			Assert.areEqual(1, result.getInsertedIds().size(), 'Should have 1 inserted ID');
			Assert.areEqual(1, result.getSuccessCount(), 'Should have 1 success');
			Assert.areEqual(1, result.getFailureCount(), 'Should have 1 failure');
			Assert.isFalse(result.getErrors().isEmpty(), 'Should have errors');
		}
	}

	/**
	 * @description Tests that an empty transaction returns a success result.
	 */
	@IsTest
	private static void shouldReturnSuccessResultForEmptyTransaction()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();

			DML_Builder.TransactionResult result = DML_Builder.newTransaction().withSystemMode().execute();

			Test.stopTest();

			Assert.isTrue(result.isSuccess(), 'Empty transaction should be successful');
			Assert.isTrue(result.getInsertedIds().isEmpty(), 'Should have no inserted IDs');
			Assert.areEqual(0, result.getSuccessCount(), 'Should have 0 successes');
			Assert.areEqual(0, result.getFailureCount(), 'Should have 0 failures');
		}
	}

	/**
	 * @description Tests that a suppressed exception returns a failure result.
	 */
	@IsTest
	private static void shouldReturnFailureResultWhenExceptionSuppressed()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			Test.startTest();

			DML_Builder.TransactionResult result = DML_Builder.newTransaction()
					.withSystemMode()
					.doUpdate(record)
					.suppressExceptions()
					.execute();

			Test.stopTest();

			Assert.isFalse(result.isSuccess(), 'Transaction should not be successful');
			Assert.areEqual(0, result.getSuccessCount(), 'Should have 0 successes when DML exception occurred');
			Assert.isTrue(result.getFailureCount() > 0, 'Should have failures');
		}
	}

	/**
	 * @description Tests that execute returns a success result for mixed insert and update operations.
	 */
	@IsTest
	private static void shouldReturnSuccessResultForMixedOperations()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c existingRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
			existingRecord.Name = UTIL_Random.randomName();

			Foobar__c newRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			Test.startTest();

			DML_Builder.TransactionResult result = DML_Builder.newTransaction()
					.withSystemMode()
					.doInsert(newRecord)
					.doUpdate(existingRecord)
					.execute();

			Test.stopTest();

			Assert.isTrue(result.isSuccess(), 'Transaction should be successful');
			Assert.areEqual(1, result.getInsertedIds().size(), 'Should have 1 inserted ID');
			Assert.areEqual(2, result.getSuccessCount(), 'Should have 2 successes');
		}
	}

	/**
	 * @description Tests TransactionResult error and failure metrics for a partial update failure.
	 */
	@IsTest
	private static void shouldReturnErrorsForPartialUpdateFailure()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
			record.Email__c = 'not-a-valid-email';

			Test.startTest();

			DML_Builder.TransactionResult result = DML_Builder.newTransaction()
					.withSystemMode()
					.doUpdate(record)
					.allowPartial()
					.execute();

			Test.stopTest();

			Assert.isFalse(result.getErrors().isEmpty(), 'Should have errors for invalid update');
			Assert.areEqual(1, result.getFailureCount(), 'Should have 1 failure');
		}
	}

	/**
	 * @description Tests TransactionResult error and failure metrics for a partial upsert failure.
	 */
	@IsTest
	private static void shouldReturnErrorsForPartialUpsertFailure()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
			record.Email__c = 'not-a-valid-email';

			Test.startTest();

			DML_Builder.TransactionResult result = DML_Builder.newTransaction()
					.withSystemMode()
					.doUpsert(record)
					.allowPartial()
					.execute();

			Test.stopTest();

			Assert.isFalse(result.getErrors().isEmpty(), 'Should have errors for invalid upsert');
			Assert.areEqual(1, result.getFailureCount(), 'Should have 1 failure');
		}
	}

	/**
	 * @description Tests TransactionResult error and failure metrics for a partial delete failure.
	 */
	@IsTest
	private static void shouldReturnErrorsForPartialDeleteFailure()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
			delete record;

			Test.startTest();

			DML_Builder.TransactionResult result = DML_Builder.newTransaction()
					.withSystemMode()
					.doDelete(record)
					.allowPartial()
					.execute();

			Test.stopTest();

			Assert.isFalse(result.getErrors().isEmpty(), 'Should have errors for deleting already-deleted record');
			Assert.areEqual(1, result.getFailureCount(), 'Should have 1 failure');
		}
	}

	/**
	 * @description Tests TransactionResult error and failure metrics for a partial undelete failure.
	 */
	@IsTest
	private static void shouldReturnErrorsForPartialUndeleteFailure()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();

			Test.startTest();

			DML_Builder.TransactionResult result = DML_Builder.newTransaction()
					.withSystemMode()
					.doUndelete(record)
					.allowPartial()
					.execute();

			Test.stopTest();

			Assert.isFalse(result.getErrors().isEmpty(), 'Should have errors for undeleting active record');
			Assert.areEqual(1, result.getFailureCount(), 'Should have 1 failure');
		}
	}

	/**
	 * @description Tests TransactionResult methods after an update operation with allowPartial.
	 */
	@IsTest
	private static void shouldReturnResultMetricsForUpdateOperation()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
			record.Name = UTIL_Random.randomName();

			Test.startTest();

			DML_Builder.TransactionResult result = DML_Builder.newTransaction()
					.withSystemMode()
					.doUpdate(record)
					.allowPartial()
					.execute();

			Test.stopTest();

			Assert.isTrue(result.isSuccess(), 'Transaction should be successful');
			Assert.areEqual(1, result.getSuccessCount(), 'Should have 1 success');
			Assert.areEqual(0, result.getFailureCount(), 'Should have 0 failures');
			Assert.isTrue(result.getErrors().isEmpty(), 'Should have no errors');
		}
	}

	/**
	 * @description Tests TransactionResult methods after an upsert operation with allowPartial.
	 */
	@IsTest
	private static void shouldReturnResultMetricsForUpsertOperation()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			Test.startTest();

			DML_Builder.TransactionResult result = DML_Builder.newTransaction()
					.withSystemMode()
					.doUpsert(record)
					.allowPartial()
					.execute();

			Test.stopTest();

			Assert.isTrue(result.isSuccess(), 'Transaction should be successful');
			Assert.areEqual(1, result.getSuccessCount(), 'Should have 1 success');
			Assert.areEqual(0, result.getFailureCount(), 'Should have 0 failures');
			Assert.isTrue(result.getErrors().isEmpty(), 'Should have no errors');
		}
	}

	/**
	 * @description Tests TransactionResult methods after a delete operation with allowPartial.
	 */
	@IsTest
	private static void shouldReturnResultMetricsForDeleteOperation()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();

			Test.startTest();

			DML_Builder.TransactionResult result = DML_Builder.newTransaction()
					.withSystemMode()
					.doDelete(record)
					.allowPartial()
					.execute();

			Test.stopTest();

			Assert.isTrue(result.isSuccess(), 'Transaction should be successful');
			Assert.areEqual(1, result.getSuccessCount(), 'Should have 1 success');
			Assert.areEqual(0, result.getFailureCount(), 'Should have 0 failures');
			Assert.isTrue(result.getErrors().isEmpty(), 'Should have no errors');
		}
	}

	/**
	 * @description Tests TransactionResult methods after an undelete operation with allowPartial.
	 */
	@IsTest
	private static void shouldReturnResultMetricsForUndeleteOperation()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
			delete record;

			Test.startTest();

			DML_Builder.TransactionResult result = DML_Builder.newTransaction()
					.withSystemMode()
					.doUndelete(record)
					.allowPartial()
					.execute();

			Test.stopTest();

			Assert.isTrue(result.isSuccess(), 'Transaction should be successful');
			Assert.areEqual(1, result.getSuccessCount(), 'Should have 1 success');
			Assert.areEqual(0, result.getFailureCount(), 'Should have 0 failures');
			Assert.isTrue(result.getErrors().isEmpty(), 'Should have no errors');
		}
	}

	/**
	 * @description Flag disabled: DML_SharingProxy.defaultAccessLevel() returns SYSTEM_MODE.
	 */
	@IsTest
	private static void shouldDefaultDmlToSystemModeWhenFlagDisabled()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true, false);

			Assert.areEqual(AccessLevel.SYSTEM_MODE, DML_SharingProxy.defaultAccessLevel(), 'DML default must be SYSTEM_MODE when flag is disabled');
		}
	}

	/**
	 * @description Flag enabled: DML_SharingProxy.defaultAccessLevel() returns USER_MODE.
	 */
	@IsTest
	private static void shouldDefaultDmlToUserModeWhenFlagEnabled()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true);

			Assert.areEqual(AccessLevel.USER_MODE, DML_SharingProxy.defaultAccessLevel(), 'DML default must be USER_MODE when flag is enabled');
		}
	}

	/**
	 * @description `.withSystemMode()` overrides a flag-driven USER_MODE default.
	 */
	@IsTest
	private static void shouldLetDmlBuilderWithSystemModeOverrideFlag()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true);

			DML_Builder builder = DML_Builder.newTransaction().withSystemMode();

			Assert.areEqual(AccessLevel.SYSTEM_MODE, builder.resolvedAccessLevel(), '.withSystemMode() must force SYSTEM_MODE regardless of flag');
		}
	}

	/**
	 * @description `.withUserMode()` overrides a flag-driven SYSTEM_MODE default.
	 */
	@IsTest
	private static void shouldLetDmlBuilderWithUserModeOverrideFlag()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true, false);

			DML_Builder builder = DML_Builder.newTransaction().withUserMode();

			Assert.areEqual(AccessLevel.USER_MODE, builder.resolvedAccessLevel(), '.withUserMode() must force USER_MODE regardless of flag');
		}
	}

	/**
	 * @description Neither explicit method called → builder resolves to flag-driven default.
	 */
	@IsTest
	private static void shouldResolveToFlagDefaultWhenNoExplicitCall()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true);

			DML_Builder builder = DML_Builder.newTransaction();

			Assert.areEqual(AccessLevel.USER_MODE, builder.resolvedAccessLevel(), 'resolvedAccessLevel() must return flag-driven default when no explicit call');
		}
	}

	/**
	 * @description Tier-A — regression gate for BUG 1. Proves that
	 * DML_Builder.newTransaction().doUpdate(...).withUserMode().async().execute() honours the
	 * explicit USER_MODE even in the async Queueable path. A low-privilege user (Minimum
	 * Access - Salesforce) who lacks FLS on Foobar__c attempts to async-update a Foobar__c
	 * record seeded by admin. Because the builder-chain explicitly calls .withUserMode(), the
	 * framework must propagate AccessLevel.USER_MODE through DML_AsyncBuilder → PROC_ExecuteDML,
	 * the queueable's DML must evaluate FLS against the running user, and the update must be
	 * rejected (the seeded value is preserved).
	 *
	 * Catches: a regression that re-hard-codes .withSystemMode() inside PROC_ExecuteDML.execute()
	 * (the bug commit f22a88d fixed) — the low-privilege user's update would silently succeed,
	 * violating the framework's "global API contract" promise that .withUserMode() means USER_MODE
	 * end-to-end.
	 *
	 * @see DML_Builder.async
	 * @see PROC_ExecuteDML.execute
	 */
	@IsTest
	private static void shouldRejectAsyncUserModeUpdateForLowPrivilegeUser()
	{
		final String originalEmail = 'seeded-admin@kerndx.test.invalid';
		final String attemptedEmail = 'mutated-low-privilege@kerndx.test.invalid';
		Foobar__c seededRecord;

		System.runAs(getTestAdmin())
		{
			seededRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Email__c, originalEmail)
					.build();
		}

		System.runAs(getLowPrivilegeUser())
		{
			seededRecord.Email__c = attemptedEmail;

			Test.startTest();

			DML_Builder.newTransaction()
					.withUserMode()
					.doUpdate(seededRecord)
					.allowPartial()
					.suppressExceptions()
					.async()
					.execute();

			Test.stopTest();
		}

		System.runAs(getTestAdmin())
		{
			Foobar__c found = (Foobar__c)new SEL_Foobar().findById(seededRecord.Id);

			Assert.areEqual(originalEmail, found.Email__c, 'USER_MODE async update must be rejected for low-privilege user — Email__c should be unchanged');
		}
	}

	/**
	 * @description Verifies the pre-execute row-count guard fires when total registered
	 * records exceed Salesforce's per-transaction DML row limit. Without the guard the
	 * platform raises an uncatchable `System.LimitException` mid-commit; the framework
	 * converts that into a `UTIL_Exceptions.IllegalStateException` thrown BEFORE any DML
	 * runs so subscribers can catch it and split the work. Uses the `maxDmlRowsForTest`
	 * `@TestVisible` seam to drive the guard with 6 records instead of 10,001, keeping
	 * the test body well under the synchronous-CPU governor budget.
	 */
	@IsTest
	private static void shouldRejectTransactionExceedingPlatformDmlRowLimit()
	{
		DML_Builder.maxDmlRowsForTest = 5;
		Integer overflowCount = DML_Builder.maxDmlRowsForTest + 1;
		List<SObject> records = TST_Builder.of(Foobar__c.SObjectType)
				.withCount(overflowCount)
				.withoutInsertion()
				.buildList();

		try
		{
			DML_Builder.newTransaction().doInsert(records).execute();
			Assert.fail('Pre-execute guard should have thrown for ' + overflowCount + ' rows');
		}
		catch(UTIL_Exceptions.IllegalStateException expected)
		{
			Assert.isTrue(
					expected.getMessage().contains(String.valueOf(overflowCount)),
					'Exception message should report the actual row count. Got: ' + expected.getMessage());
			Assert.isTrue(
					expected.getMessage().contains('.async()'),
					'Exception message should suggest .async() as the remediation. Got: ' + expected.getMessage());
		}
	}

	/**
	 * @description Verifies the pre-execute row-count guard does NOT fire at the boundary
	 * (exactly the configured limit). Catches off-by-one regressions in the comparison
	 * operator (`>` vs `>=`). Uses the `maxDmlRowsForTest` seam to keep the test fast.
	 * Any post-guard exception (e.g. unrelated platform error during the actual insert)
	 * is allowed to propagate — the test only verifies the framework guard let the work
	 * through.
	 */
	@IsTest
	private static void shouldAllowTransactionAtExactPlatformDmlRowLimit()
	{
		DML_Builder.maxDmlRowsForTest = 5;
		List<SObject> records = TST_Builder.of(Foobar__c.SObjectType)
				.withCount(DML_Builder.maxDmlRowsForTest)
				.withoutInsertion()
				.buildList();

		try
		{
			DML_Builder.newTransaction().doInsert(records).execute();
		}
		catch(UTIL_Exceptions.IllegalStateException unexpected)
		{
			Assert.fail('Row-count guard must NOT fire at exactly the limit. Got: ' + unexpected.getMessage());
		}
	}

	/**
	 * @description Retrieves the committed test admin user set up in @TestSetup for use with
	 * System.runAs, so each test body runs with a fresh permission-evaluation context.
	 *
	 * @return The test admin User record.
	 */
	private static User getTestAdmin()
	{
		return new SEL_User().findByCompanyName(TEST_ADMIN_COMPANY);
	}

	/**
	 * @description Retrieves the committed low-privilege user (Minimum Access - Salesforce profile)
	 * set up in @TestSetup. Used by the tier-A test to prove USER_MODE async DML is rejected when
	 * the caller lacks FLS on the target SObject.
	 *
	 * @return The low-privilege User record.
	 */
	private static User getLowPrivilegeUser()
	{
		return new SEL_User().findByCompanyName(LOW_PRIVILEGE_COMPANY);
	}

	/**
	 * @description Tests that `withSystemMode` emits a `dml` bypass audit entry recording the
	 * `system-mode` target — proving subscriber-reachable DML opt-outs from USER_MODE-by-default
	 * leave a forensic trail.
	 *
	 * @see DML_Builder.withSystemMode
	 * @see UTIL_BypassAudit.emit
	 */
	@IsTest
	private static void shouldEmitBypassAuditOnDmlSystemMode()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();

		Test.startTest();
		DML_Builder.newTransaction().doInsert(record).withSystemMode().execute();
		Test.stopTest();

		Map<String, Object> context = findBypassAuditContext('system-mode');
		Assert.isNotNull(context, 'withSystemMode should emit a bypass audit entry');
		Assert.areEqual(UTIL_BypassAudit.SURFACE_DML, context.get(UTIL_BypassAudit.CONTEXT_SURFACE), 'Surface should be dml');
		Assert.areEqual(UTIL_BypassAudit.ACTION_BYPASS, context.get(UTIL_BypassAudit.CONTEXT_ACTION), 'Action should be BYPASS');
	}

	/**
	 * @description Tests that `systemModeInternal` flips the access level to SYSTEM_MODE WITHOUT
	 * enqueuing a bypass audit entry. The framework-internal channel is the path used by
	 * `TRG_PersistLogEntry` to write `LogEntry__c` rows after `LogEntryEvent__e` delivery — that
	 * write is not a subscriber-facing bypass, and auditing it would create an
	 * emit→deliver→persist→emit cascade with no fixpoint. Without this contract, every framework
	 * platform-event persist would emit a noise audit and (in test mode where
	 * `Test.getEventBus().deliver()` runs synchronously) recurse until CPU exhausted.
	 *
	 * @see DML_Builder.systemModeInternal
	 * @see TRG_PersistLogEntry
	 * @see UTIL_BypassAudit.emit
	 */
	@IsTest
	private static void shouldNotEmitBypassAuditOnDmlSystemModeInternal()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();

		Test.startTest();
		DML_Builder.newTransaction().doInsert(record).systemModeInternal().execute();
		Test.stopTest();

		Assert.isNull(findBypassAuditContext('system-mode'), 'systemModeInternal must not emit a bypass audit entry');
	}

	/**
	 * @description Tests that `bypassSharing` emits a `dml` bypass audit entry recording the
	 * `sharing` target.
	 *
	 * @see DML_Builder.bypassSharing
	 * @see UTIL_BypassAudit.emit
	 */
	@IsTest
	private static void shouldEmitBypassAuditOnDmlBypassSharing()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();

		Test.startTest();
		DML_Builder.newTransaction().doInsert(record).bypassSharing().execute();
		Test.stopTest();

		Map<String, Object> context = findBypassAuditContext('sharing');
		Assert.isNotNull(context, 'bypassSharing should emit a bypass audit entry');
		Assert.areEqual(UTIL_BypassAudit.SURFACE_DML, context.get(UTIL_BypassAudit.CONTEXT_SURFACE), 'Surface should be dml');
		Assert.areEqual(UTIL_BypassAudit.ACTION_BYPASS, context.get(UTIL_BypassAudit.CONTEXT_ACTION), 'Action should be BYPASS');
	}

	/**
	 * @description Tests that `async()` flushes queued bypass audits before handing off to
	 * `DML_AsyncBuilder`. Without this flush, a subscriber chaining `bypassSharing().async().execute()`
	 * records the bypass intent on the source builder but never emits an audit, leaving a forensic
	 * gap. The async path runs on a different builder instance with no `auditQueue`, so the source
	 * builder is the only place to flush before handoff.
	 *
	 * @see DML_Builder.async
	 * @see UTIL_BypassAudit.AuditQueue.flush
	 */
	@IsTest
	private static void shouldEmitBypassAuditWhenAsyncCalledAfterBypassSharing()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();

		Test.startTest();
		DML_Builder.newTransaction().doInsert(record).bypassSharing().async();
		Test.stopTest();

		Map<String, Object> context = findBypassAuditContext('sharing');
		Assert.isNotNull(context, 'async() should flush queued bypass audits before handing off to DML_AsyncBuilder');
		Assert.areEqual(UTIL_BypassAudit.SURFACE_DML, context.get(UTIL_BypassAudit.CONTEXT_SURFACE), 'Surface should be dml');
		Assert.areEqual(UTIL_BypassAudit.ACTION_BYPASS, context.get(UTIL_BypassAudit.CONTEXT_ACTION), 'Action should be BYPASS');
	}

	/**
	 * @description Locates the most-recent bypass audit entry whose `target` matches the supplied
	 * value and whose `surface` is `dml`. Filtering by both target and surface keeps assertions
	 * stable when other framework-internal audits (e.g., `query` system-mode emissions) also fire
	 * during test setup.
	 *
	 * @param target The bypass audit `target` context value to find.
	 *
	 * @return The inner context map for the matching audit entry, or `null` if none exists.
	 */
	private static Map<String, Object> findBypassAuditContext(String target)
	{
		for(LogEntry__c entry : new SEL_LogEntry().findAllOrderedByCreatedDateDesc())
		{
			Map<String, Object> context = SEL_LogEntry.parseContextDataForTest(entry);
			if(context != null
					&& target.equals(context.get(UTIL_BypassAudit.CONTEXT_TARGET))
					&& UTIL_BypassAudit.SURFACE_DML.equals(context.get(UTIL_BypassAudit.CONTEXT_SURFACE)))
			{
				return context;
			}
		}
		return null;
	}
}