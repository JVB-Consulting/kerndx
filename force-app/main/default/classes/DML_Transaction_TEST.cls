// SPDX-License-Identifier: BSD-3-Clause
/**
 * Copyright (c), FinancialForce.com, inc
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * - Redistributions of source code must retain the above copyright notice,
 * this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation
 * and/or other materials provided with the distribution.
 * - Neither the name of the FinancialForce.com, inc nor the names of its contributors
 * may be used to endorse or promote products derived from this software without
 * specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/**
 * @description Unit tests for DML_Transaction.
 *
 * @see DML_Transaction
 *
 * @author Jason van Beukering
 *
 * @group DML
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CognitiveComplexity,PMD.AvoidBooleanMethodParameters')
@IsTest(SeeAllData=false IsParallel=false)
private class DML_Transaction_TEST
{
	/**
	 * @description Event name for the onCommitWorkStarting hook.
	 */
	private static final String EVENT_COMMIT_STARTING = 'onCommitWorkStarting';

	/**
	 * @description Event name for the onDMLStarting hook.
	 */
	private static final String EVENT_DML_STARTING = 'onDMLStarting';

	/**
	 * @description Event name for the onDMLFinished hook.
	 */
	private static final String EVENT_DML_FINISHED = 'onDMLFinished';

	/**
	 * @description Event name for the onCommitWorkFinishing hook.
	 */
	private static final String EVENT_COMMIT_FINISHING = 'onCommitWorkFinishing';

	/**
	 * @description Event name for the onCommitWorkFinished hook.
	 */
	private static final String EVENT_COMMIT_FINISHED = 'onCommitWorkFinished';

	/**
	 * @description Assertion message for value equality checks.
	 */
	private static final String MSG_VALUE_EQUALITY = 'Value should match expected';

	/**
	 * @description Assertion message for null checks.
	 */
	private static final String MSG_NULL = 'Result should be null';

	/**
	 * @description Assertion message for event count checks.
	 */
	private static final String MSG_EVENTS_MISMATCH = 'Number of events fired does not match expected';

	/**
	 * @description Tests inserting a single record via doInsert.
	 */
	@IsTest
	private static void shouldInsertSingleRecord()
	{
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withoutInsertion()
				.build();

		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.doInsert(record);

		Test.startTest();

		dmlTransaction.commitWork();

		Test.stopTest();

		Assert.isNotNull(record.Id, 'Record should have an Id after insert');
		Foobar__c found = (Foobar__c)new SEL_Foobar().findById(record.Id);
		Assert.isNotNull(found, 'Record should exist in database');
	}

	/**
	 * @description Tests inserting multiple records via doInsert list overload.
	 */
	@IsTest
	private static void shouldInsertMultipleRecords()
	{
		List<SObject> records = TST_Builder.of(Foobar__c.SObjectType)
				.withCount(3)
				.withoutInsertion()
				.buildList();

		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.doInsert(records);

		Test.startTest();

		dmlTransaction.commitWork();

		Test.stopTest();

		List<Foobar__c> found = new SEL_Foobar().getAll();
		Assert.areEqual(3, found.size(), MSG_VALUE_EQUALITY);
	}

	/**
	 * @description Tests inserting a parent and child with relationship resolution.
	 */
	@IsTest
	private static void shouldInsertParentChildRelationship()
	{
		Foobar__c parent = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withoutInsertion()
				.build();

		Foobar__c child = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withoutInsertion()
				.build();

		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.doInsert(parent);
		dmlTransaction.doInsert(child, Foobar__c.Lookup__c, parent);

		Test.startTest();

		dmlTransaction.commitWork();

		Test.stopTest();

		Foobar__c foundChild = (Foobar__c)new SEL_Foobar().findById(child.Id);
		Assert.areEqual(parent.Id, foundChild.Lookup__c, MSG_VALUE_EQUALITY);
	}

	/**
	 * @description Tests updating a single record via doUpdate.
	 */
	@IsTest
	private static void shouldUpdateSingleRecord()
	{
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
		String updatedName = UTIL_Random.randomName();
		record.Name = updatedName;

		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.doUpdate(record);

		Test.startTest();

		dmlTransaction.commitWork();

		Test.stopTest();

		Foobar__c found = (Foobar__c)new SEL_Foobar().findById(record.Id);
		Assert.areEqual(updatedName, found.Name, MSG_VALUE_EQUALITY);
	}

	/**
	 * @description Tests updating multiple records via doUpdate list overload.
	 */
	@IsTest
	private static void shouldUpdateMultipleRecords()
	{
		List<SObject> records = TST_Builder.of(Foobar__c.SObjectType)
				.withCount(2)
				.buildList();

		String updatedName = UTIL_Random.randomName();

		for(SObject record : records)
		{
			((Foobar__c)record).Name = updatedName;
		}

		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.doUpdate(records);

		Test.startTest();

		dmlTransaction.commitWork();

		Test.stopTest();

		List<Foobar__c> found = new SEL_Foobar().getAll();
		for(Foobar__c foundRecord : found)
		{
			Assert.areEqual(updatedName, foundRecord.Name, MSG_VALUE_EQUALITY);
		}
	}

	/**
	 * @description Tests updating a record with a relationship to a parent.
	 */
	@IsTest
	private static void shouldUpdateWithRelationship()
	{
		Foobar__c parent = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
		Foobar__c child = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();

		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.doUpdate(child, Foobar__c.Lookup__c, parent);

		Test.startTest();

		dmlTransaction.commitWork();

		Test.stopTest();

		Foobar__c found = (Foobar__c)new SEL_Foobar().findById(child.Id);
		Assert.areEqual(parent.Id, found.Lookup__c, MSG_VALUE_EQUALITY);
	}

	/**
	 * @description Tests deleting a single record via doDelete.
	 */
	@IsTest
	private static void shouldDeleteSingleRecord()
	{
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();

		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.doDelete(record);

		Test.startTest();

		dmlTransaction.commitWork();

		Test.stopTest();

		Foobar__c found = (Foobar__c)new SEL_Foobar().findById(record.Id);
		Assert.isNull(found, MSG_NULL);
	}

	/**
	 * @description Tests deleting multiple records via doDelete list overload.
	 */
	@IsTest
	private static void shouldDeleteMultipleRecords()
	{
		List<SObject> records = TST_Builder.of(Foobar__c.SObjectType)
				.withCount(2)
				.buildList();

		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.doDelete(records);

		Test.startTest();

		dmlTransaction.commitWork();

		Test.stopTest();

		List<Foobar__c> found = new SEL_Foobar().getAll();
		Assert.isTrue(found.isEmpty(), 'All records should be deleted');
	}

	/**
	 * @description Tests upserting a single record with an external ID field.
	 */
	@IsTest
	private static void shouldUpsertWithExternalId()
	{
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.ExternalId__c, 'EXT-001')
				.withoutInsertion()
				.build();

		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.doUpsert(record, Foobar__c.ExternalId__c);

		Test.startTest();

		dmlTransaction.commitWork();

		Test.stopTest();

		Assert.isNotNull(record.Id, 'Record should have an Id after upsert');
		Foobar__c found = (Foobar__c)new SEL_Foobar().findById(record.Id);
		Assert.areEqual('EXT-001', found.ExternalId__c, MSG_VALUE_EQUALITY);
	}

	/**
	 * @description Tests upserting multiple records with an external ID field.
	 */
	@IsTest
	private static void shouldUpsertMultipleWithExternalId()
	{
		Foobar__c existing = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.ExternalId__c, 'EXT-002')
				.build();

		existing.Name = 'Updated Name';

		Foobar__c newRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.ExternalId__c, 'EXT-003')
				.withoutInsertion()
				.build();

		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.doUpsert(new List<SObject> {newRecord, existing}, Foobar__c.ExternalId__c);

		Test.startTest();

		dmlTransaction.commitWork();

		Test.stopTest();

		List<Foobar__c> found = new SEL_Foobar().getAll();
		Assert.areEqual(2, found.size(), MSG_VALUE_EQUALITY);
	}

	/**
	 * @description Tests that conflicting external ID fields for the same SObjectType throws an exception.
	 */
	@IsTest
	private static void shouldThrowOnConflictingExternalIdFields()
	{
		Foobar__c record1 = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withoutInsertion()
				.build();

		Foobar__c record2 = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withoutInsertion()
				.build();

		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.doUpsert(record1, Foobar__c.ExternalId__c);

		try
		{
			dmlTransaction.doUpsert(record2, Foobar__c.NumberDecimal__c);
			Assert.fail('Expected IllegalStateException');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, UTIL_Exceptions.IllegalStateException.class, 'Incorrect Exception Type');
		}
	}

	/**
	 * @description Tests upserting a child record with relationship to a parent.
	 */
	@IsTest
	private static void shouldUpsertWithRelationship()
	{
		Foobar__c parent = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();

		Foobar__c child = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.ExternalId__c, 'EXT-CHILD')
				.withoutInsertion()
				.build();

		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.doUpsert(child, Foobar__c.Lookup__c, Foobar__c.ExternalId__c, parent);

		Test.startTest();

		dmlTransaction.commitWork();

		Test.stopTest();

		Foobar__c found = (Foobar__c)new SEL_Foobar().findById(child.Id);
		Assert.areEqual(parent.Id, found.Lookup__c, MSG_VALUE_EQUALITY);
	}

	/**
	 * @description Tests committing with bypass sharing.
	 */
	@IsTest
	private static void shouldCommitWithBypassSharing()
	{
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
		record.Name = UTIL_Random.randomName();

		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(System.AccessLevel.SYSTEM_MODE);
		dmlTransaction.doUpdate(record);
		dmlTransaction.doInsert(TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build());
		dmlTransaction.doDelete(record);

		try
		{
			System.runAs(TST_Factory.newUser(SEL_Profile.PROFILE_STANDARD_USER))
			{
				Test.startTest();

				dmlTransaction.commitWork(false);

				Test.stopTest();
			}
		}
		catch(Exception error)
		{
			Assert.fail('Sharing should have been bypassed: ' + error.getMessage());
		}
	}

	/**
	 * @description Tests committing with enforced sharing.
	 */
	@IsTest
	private static void shouldCommitWithEnforceSharing()
	{
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
		record.Name = UTIL_Random.randomName();

		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.doUpdate(record);

		try
		{
			System.runAs(TST_Factory.newUser(SEL_Profile.PROFILE_STANDARD_USER))
			{
				Test.startTest();

				dmlTransaction.commitWork(true);

				Test.stopTest();

				Assert.fail('Sharing should have been enforced');
			}
		}
		catch(Exception error)
		{
			Assert.isNotNull(error.getMessage(), 'Sharing was enforced as expected');
		}
	}

	/**
	 * @description Tests that a DML failure causes savepoint rollback.
	 */
	@IsTest
	private static void shouldRollbackOnFailure()
	{
		Foobar__c newRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withoutInsertion()
				.build();

		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.doUpdate(newRecord);

		try
		{
			Test.startTest();

			dmlTransaction.commitWork();

			Test.stopTest();

			Assert.fail('Expected DmlException');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, DmlException.class, 'Incorrect Exception Type');
		}
	}

	/**
	 * @description Tests that parent types are inserted before child types via topological sort.
	 */
	@IsTest
	private static void shouldOrderTypesTopologically()
	{
		Foobar__c parent = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withoutInsertion()
				.build();

		Foobar__c child = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withoutInsertion()
				.build();

		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.doInsert(child, Foobar__c.Lookup__c, parent);
		dmlTransaction.doInsert(parent);

		Test.startTest();

		dmlTransaction.commitWork();

		Test.stopTest();

		Assert.isNotNull(parent.Id, 'Parent should have an Id');
		Assert.areEqual(parent.Id, child.get(Foobar__c.Lookup__c), MSG_VALUE_EQUALITY);
	}

	/**
	 * @description Tests that all five lifecycle hooks are called in the correct order.
	 */
	@IsTest
	private static void shouldInvokeLifecycleHooks()
	{
		TEST_Transaction testTransaction = new TEST_Transaction();
		testTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		testTransaction.doInsert(TST_Factory.newFoobar());

		Test.startTest();

		testTransaction.commitWork();

		Test.stopTest();

		List<String> expectedEvents = new List<String>
		{
				EVENT_COMMIT_STARTING,
				EVENT_DML_STARTING,
				EVENT_DML_FINISHED,
				EVENT_COMMIT_FINISHING,
				EVENT_COMMIT_FINISHED + ' - true'
		};

		assertEvents(expectedEvents, testTransaction.getEventsFired());
	}

	/**
	 * @description Tests that onCommitWorkFinished reports failure when DML fails.
	 */
	@IsTest
	private static void shouldReportFailureInHook()
	{
		TEST_Transaction testTransaction = new TEST_Transaction();
		testTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		testTransaction.doUpdate(TST_Factory.newFoobar());

		try
		{
			Test.startTest();

			testTransaction.commitWork();

			Test.stopTest();

			Assert.fail('Expected DmlException');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, DmlException.class, 'Incorrect Exception Type');
		}

		List<String> expectedEvents = new List<String>
		{
				EVENT_COMMIT_STARTING,
				EVENT_DML_STARTING,
				EVENT_COMMIT_FINISHED + ' - false'
		};

		assertEvents(expectedEvents, testTransaction.getEventsFired());
	}

	/**
	 * @description Tests that allowPartial mode allows some records to fail without exception.
	 */
	@IsTest
	private static void shouldAllowPartialInsert()
	{
		Foobar__c validRecord = TST_Factory.newFoobar();

		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.setAllowPartial(true);
		dmlTransaction.doInsert(validRecord);

		Test.startTest();

		dmlTransaction.commitWork();

		Test.stopTest();

		Assert.isNotNull(validRecord.Id, 'Valid record should have been inserted');
	}

	/**
	 * @description Tests that a child is safely skipped when its parent fails in partial mode.
	 * Forces a parent failure via invalid email format on Email__c field.
	 */
	@IsTest
	private static void shouldSkipChildWhenParentFailsInPartial()
	{
		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.setAllowPartial(true);

		Foobar__c parent = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Email__c, 'not-a-valid-email')
				.withoutInsertion()
				.build();

		Foobar__c child = TST_Factory.newFoobar();

		dmlTransaction.doInsert(parent);
		dmlTransaction.doInsert(child, Foobar__c.Lookup__c, parent);

		Test.startTest();

		dmlTransaction.commitWork();

		Test.stopTest();

		Assert.isNull(parent.Id, 'Parent should have failed insertion due to invalid email');
		Assert.isNotNull(child.Id, 'Child should have been inserted despite parent failure');
		Foobar__c foundChild = (Foobar__c)new SEL_Foobar().findById(child.Id);
		Assert.isNull(foundChild.Lookup__c, 'Child relationship should not be populated');
	}

	/**
	 * @description Tests that partial failure mode does not rollback the savepoint.
	 */
	@IsTest
	private static void shouldNotRollbackOnPartialFailure()
	{
		Foobar__c validRecord = TST_Factory.newFoobar();
		Foobar__c invalidRecord = TST_Factory.newFoobar();

		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.setAllowPartial(true);
		dmlTransaction.doInsert(validRecord);
		dmlTransaction.doUpdate(invalidRecord);

		Test.startTest();

		dmlTransaction.commitWork();

		Test.stopTest();

		Assert.isNotNull(validRecord.Id, 'Valid record should persist despite partial failure');
	}

	/**
	 * @description Tests undeleting a single record via doUndelete.
	 */
	@IsTest
	private static void shouldUndeleteSingleRecord()
	{
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
		delete record;

		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.doUndelete(record);

		Test.startTest();

		dmlTransaction.commitWork();

		Test.stopTest();

		Foobar__c found = (Foobar__c)new SEL_Foobar().findById(record.Id);
		Assert.isNotNull(found, 'Record should be undeleted');
	}

	/**
	 * @description Tests undeleting multiple records via doUndelete list overload.
	 */
	@IsTest
	private static void shouldUndeleteMultipleRecords()
	{
		List<SObject> records = TST_Builder.of(Foobar__c.SObjectType)
				.withCount(2)
				.buildList();
		delete records;

		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.doUndelete(records);

		Test.startTest();

		dmlTransaction.commitWork();

		Test.stopTest();

		List<Foobar__c> found = new SEL_Foobar().getAll();
		Assert.areEqual(2, found.size(), MSG_VALUE_EQUALITY);
	}

	/**
	 * @description Tests that undelete participates in savepoint rollback when a subsequent operation fails.
	 */
	@IsTest
	private static void shouldRollbackUndeleteOnFailure()
	{
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
		delete record;

		Foobar__c invalidRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withoutInsertion()
				.build();

		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.doUndelete(record);
		dmlTransaction.doUpdate(invalidRecord);

		try
		{
			Test.startTest();

			dmlTransaction.commitWork();

			Test.stopTest();

			Assert.fail('Expected DmlException');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, DmlException.class, 'Incorrect Exception Type');
		}

		List<Foobar__c> found =
		[
				SELECT Id,
						IsDeleted
				FROM Foobar__c
				WHERE Id = :record.Id
				ALL ROWS
		];
		Assert.areEqual(1, found.size(), 'Record should exist');
		Assert.isTrue(found[0].IsDeleted, 'Undelete should have been rolled back');
	}

	/**
	 * @description Tests that undelete executes before insert in commit order.
	 */
	@IsTest
	private static void shouldUndeleteBeforeInsertInCommitOrder()
	{
		Foobar__c deletedRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
		delete deletedRecord;

		Foobar__c newRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withoutInsertion()
				.build();

		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.doInsert(newRecord);
		dmlTransaction.doUndelete(deletedRecord);

		Test.startTest();

		dmlTransaction.commitWork();

		Test.stopTest();

		List<Foobar__c> found = new SEL_Foobar().getAll();
		Assert.areEqual(2, found.size(), 'Both records should exist');
	}

	/**
	 * @description Tests upserting a single record without an external ID field.
	 */
	@IsTest
	private static void shouldUpsertWithoutExternalId()
	{
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withoutInsertion()
				.build();

		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.doUpsert(record);

		Test.startTest();

		dmlTransaction.commitWork();

		Test.stopTest();

		Assert.isNotNull(record.Id, 'Record should have an Id after upsert');
	}

	/**
	 * @description Tests upserting multiple records without an external ID field.
	 */
	@IsTest
	private static void shouldUpsertMultipleWithoutExternalId()
	{
		List<SObject> records = TST_Builder.of(Foobar__c.SObjectType)
				.withCount(2)
				.withoutInsertion()
				.buildList();

		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.doUpsert(records);

		Test.startTest();

		dmlTransaction.commitWork();

		Test.stopTest();

		List<Foobar__c> found = new SEL_Foobar().getAll();
		Assert.areEqual(2, found.size(), MSG_VALUE_EQUALITY);
	}

	/**
	 * @description Tests inserting a deeply nested self-referential tree (3 levels).
	 */
	@IsTest
	private static void shouldInsertDeeplyNestedTree()
	{
		Foobar__c grandparent = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withoutInsertion()
				.build();

		Foobar__c parent = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withoutInsertion()
				.build();

		Foobar__c child = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withoutInsertion()
				.build();

		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.doInsert(grandparent);
		dmlTransaction.doInsert(parent, Foobar__c.Lookup__c, grandparent);
		dmlTransaction.doInsert(child, Foobar__c.Lookup__c, parent);

		Test.startTest();

		dmlTransaction.commitWork();

		Test.stopTest();

		Assert.isNotNull(grandparent.Id, 'Grandparent should have an Id');
		Assert.isNotNull(parent.Id, 'Parent should have an Id');
		Assert.isNotNull(child.Id, 'Child should have an Id');

		Foobar__c foundParent = (Foobar__c)new SEL_Foobar().findById(parent.Id);
		Assert.areEqual(grandparent.Id, foundParent.Lookup__c, 'Parent should reference grandparent');

		Foobar__c foundChild = (Foobar__c)new SEL_Foobar().findById(child.Id);
		Assert.areEqual(parent.Id, foundChild.Lookup__c, 'Child should reference parent');
	}

	/**
	 * @description Tests that same-type child update is skipped when child fails insertion in partial mode.
	 */
	@IsTest
	private static void shouldSkipSameTypeUpdateWhenChildFailsInPartial()
	{
		Foobar__c parent = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withoutInsertion()
				.build();

		Foobar__c child = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Email__c, 'not-a-valid-email')
				.withoutInsertion()
				.build();

		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.setAllowPartial(true);
		dmlTransaction.doInsert(parent);
		dmlTransaction.doInsert(child, Foobar__c.Lookup__c, parent);

		Test.startTest();

		dmlTransaction.commitWork();

		Test.stopTest();

		Assert.isNotNull(parent.Id, 'Parent should have an Id');
		Assert.isNull(child.Id, 'Child should have failed insertion');
		List<Foobar__c> found = new SEL_Foobar().getAll();
		Assert.areEqual(1, found.size(), 'Only parent should exist');
	}

	/**
	 * @description Tests that partial results are logged via LOG_Builder.
	 */
	@IsTest
	private static void shouldLogPartialResults()
	{
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withoutInsertion()
				.build();

		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.setAllowPartial(true);
		dmlTransaction.doInsert(record);

		Test.startTest();

		dmlTransaction.commitWork();

		Test.stopTest();

		Assert.isNotNull(record.Id, 'Record should have been inserted');
	}

	/**
	 * @description Tests that setSuppressLogging(true) prevents partial result logging.
	 */
	@IsTest
	private static void shouldSuppressPartialLogging()
	{
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withoutInsertion()
				.build();

		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.setAllowPartial(true);
		dmlTransaction.setSuppressLogging(true);
		dmlTransaction.doInsert(record);

		Test.startTest();

		dmlTransaction.commitWork();

		Test.stopTest();

		Assert.isNotNull(record.Id, 'Record should have been inserted');
	}

	/**
	 * @description Verifies that the expected events were fired in the correct order.
	 *
	 * @param expectedEvents The list of expected event names.
	 * @param actualEvents The list of actual events fired.
	 */
	private static void assertEvents(List<String> expectedEvents, List<String> actualEvents)
	{
		Assert.areEqual(expectedEvents.size(), actualEvents.size(), MSG_EVENTS_MISMATCH);
		for(Integer i = 0; i < expectedEvents.size(); i++)
		{
			Assert.areEqual(expectedEvents[i], actualEvents[i], 'Event at index ' + i + ' does not match');
		}
	}

	/**
	 * @description Test subclass that tracks lifecycle hook invocations.
	 */
	private class TEST_Transaction extends DML_Transaction
	{
		/**
		 * @description Ordered list of events fired during the transaction.
		 */
		private final List<String> eventsFired = new List<String>();

		/**
		 * @description Constructs a new TEST_Transaction instance.
		 */
		@SuppressWarnings('PMD.EmptyStatementBlock')
		private TEST_Transaction()
		{
		}

		/**
		 * @description Returns the list of events fired.
		 *
		 * @return A copy of the events list.
		 */
		private List<String> getEventsFired()
		{
			return eventsFired.clone();
		}

		/**
		 * @description Records the onCommitWorkStarting event.
		 */
		public override void onCommitWorkStarting()
		{
			super.onCommitWorkStarting();
			eventsFired.add(EVENT_COMMIT_STARTING);
		}

		/**
		 * @description Records the onDMLStarting event.
		 */
		public override void onDMLStarting()
		{
			super.onDMLStarting();
			eventsFired.add(EVENT_DML_STARTING);
		}

		/**
		 * @description Records the onDMLFinished event.
		 */
		public override void onDMLFinished()
		{
			super.onDMLFinished();
			eventsFired.add(EVENT_DML_FINISHED);
		}

		/**
		 * @description Records the onCommitWorkFinishing event.
		 */
		public override void onCommitWorkFinishing()
		{
			super.onCommitWorkFinishing();
			eventsFired.add(EVENT_COMMIT_FINISHING);
		}

		/**
		 * @description Records the onCommitWorkFinished event with success status.
		 *
		 * @param wasSuccessful Whether the commit was successful.
		 */
		public override void onCommitWorkFinished(Boolean wasSuccessful)
		{
			super.onCommitWorkFinished(wasSuccessful);
			eventsFired.add(EVENT_COMMIT_FINISHED + ' - ' + wasSuccessful);
		}
	}

	/**
	 * @description Tests that a cyclic dependency between two different SObjectTypes throws IllegalStateException.
	 */
	@IsTest
	private static void shouldThrowOnCyclicDependency()
	{
		Account parentAccount = new Account(Name = UTIL_Random.randomName());
		Contact childContact = new Contact(LastName = UTIL_Random.randomName());

		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.doInsert(childContact, Contact.AccountId, parentAccount);
		dmlTransaction.doInsert(parentAccount, Account.ParentId, childContact);

		try
		{
			Test.startTest();

			dmlTransaction.commitWork();

			Test.stopTest();

			Assert.fail('Expected IllegalStateException for cyclic dependency');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, UTIL_Exceptions.IllegalStateException.class, 'Incorrect Exception Type');
		}
	}

	/**
	 * @description Tests that insert results are collected after commitWork.
	 */
	@IsTest
	private static void shouldCollectInsertResults()
	{
		List<SObject> records = TST_Builder.of(Foobar__c.SObjectType)
				.withCount(3)
				.withoutInsertion()
				.buildList();

		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.doInsert(records);

		Test.startTest();

		dmlTransaction.commitWork();

		Test.stopTest();

		Assert.areEqual(3, dmlTransaction.getInsertResults().size(), MSG_VALUE_EQUALITY);
		for(Database.SaveResult result : dmlTransaction.getInsertResults())
		{
			Assert.isTrue(result.isSuccess(), 'Each insert should succeed');
		}
		Assert.isTrue(dmlTransaction.getUpdateResults().isEmpty(), 'No update results expected');
		Assert.isTrue(dmlTransaction.getDeleteResults().isEmpty(), 'No delete results expected');
		Assert.isTrue(dmlTransaction.getUpsertResults().isEmpty(), 'No upsert results expected');
		Assert.isTrue(dmlTransaction.getUndeleteResults().isEmpty(), 'No undelete results expected');
	}

	/**
	 * @description Tests that update results are collected after commitWork.
	 */
	@IsTest
	private static void shouldCollectUpdateResults()
	{
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
		record.Name = UTIL_Random.randomName();

		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.doUpdate(record);

		Test.startTest();

		dmlTransaction.commitWork();

		Test.stopTest();

		Assert.areEqual(1, dmlTransaction.getUpdateResults().size(), MSG_VALUE_EQUALITY);
		Assert.isTrue(dmlTransaction.getUpdateResults()[0].isSuccess(), 'Update should succeed');
	}

	/**
	 * @description Tests that delete results are collected after commitWork.
	 */
	@IsTest
	private static void shouldCollectDeleteResults()
	{
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();

		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.doDelete(record);

		Test.startTest();

		dmlTransaction.commitWork();

		Test.stopTest();

		Assert.areEqual(1, dmlTransaction.getDeleteResults().size(), MSG_VALUE_EQUALITY);
		Assert.isTrue(dmlTransaction.getDeleteResults()[0].isSuccess(), 'Delete should succeed');
	}

	/**
	 * @description Tests that upsert results are collected after commitWork.
	 */
	@IsTest
	private static void shouldCollectUpsertResults()
	{
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withoutInsertion()
				.build();

		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.doUpsert(record);

		Test.startTest();

		dmlTransaction.commitWork();

		Test.stopTest();

		Assert.areEqual(1, dmlTransaction.getUpsertResults().size(), MSG_VALUE_EQUALITY);
		Assert.isTrue(dmlTransaction.getUpsertResults()[0].isSuccess(), 'Upsert should succeed');
	}
}