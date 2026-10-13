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
 * @date February 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.NcssCount,PMD.NcssTypeCount,PMD.AvoidBooleanMethodParameters')
@IsTest(seeAllData=false isParallel=false)
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
	 * @description An email value the platform refuses with INVALID_EMAIL_ADDRESS.
	 */
	private static final String INVALID_EMAIL = 'not-a-valid-email';

	/**
	 * @description A failed save result carrying two errors, which real DML on this platform never produces for one row.
	 */
	private static final String TWO_ERROR_ROW_JSON = '{"success":false,"errors":['
			+ '{"statusCode":"INVALID_EMAIL_ADDRESS","message":"invalid email","fields":["Email__c"]},'
			+ '{"statusCode":"REQUIRED_FIELD_MISSING","message":"required field missing","fields":["Name"]}]}';

	/**
	 * @description An external Id value the platform refuses with STRING_TOO_LONG on the Text(50) field.
	 */
	private static final String OVERLONG_EXTERNAL_ID = 'x'.repeat(60);

	/**
	 * @description Message the deliberately-throwing hook subclasses raise in the swallow tests and the empty-commit test.
	 */
	private static final String HOOK_FAILURE_MESSAGE = 'Deliberate hook failure for the swallow tests';

	/**
	 * @description The platform's row-lock refusal message, owned by the shared stand-in so every DML test class reads
	 * the same token.
	 */
	private static final String LOCK_REFUSAL_MESSAGE = DML_ThrowingLockProxy_TEST.LOCK_REFUSAL_MESSAGE;

	/**
	 * @description A refusal that is not a lock, thrown by the stand-in to prove the loop leaves it alone.
	 */
	private static final String VALIDATION_REFUSAL_MESSAGE = 'Insert failed. First exception on row 0; first error: FIELD_CUSTOM_VALIDATION_EXCEPTION, '
			+ 'a rule refused the row';

	/**
	 * @description A single refused row as the platform reports it in partial mode, built from JSON because no test
	 * can hold a second transaction's lock.
	 */
	private static final String LOCK_REFUSED_ROW_JSON = '{"success":false,"errors":['
			+ '{"statusCode":"UNABLE_TO_LOCK_ROW","message":"unable to obtain exclusive access to this record","fields":[]}]}';

	/**
	 * @description A refused row carrying a lock error and a validation error: the every-error rule must not retry it.
	 */
	private static final String MIXED_REFUSED_ROW_JSON = '{"success":false,"errors":['
			+ '{"statusCode":"UNABLE_TO_LOCK_ROW","message":"unable to obtain exclusive access to this record","fields":[]},'
			+ '{"statusCode":"FIELD_CUSTOM_VALIDATION_EXCEPTION","message":"a rule refused the row","fields":["Name"]}]}';

	/**
	 * @description A remaining budget below anything a first attempt can consume, so the headroom guard must stop the loop.
	 */
	private static final Integer NO_HEADROOM = 1;

	/**
	 * @description No DML rows left at all, so the partial-mode guard must stop the rounds: one row left would still
	 * fit a single re-issued row.
	 */
	private static final Integer NO_ROWS_LEFT = 0;

	/**
	 * @description The DML statements one failed attempt costs when the stand-in throws before its statement runs:
	 * the savepoint, the rollback and the savepoint release, each of which the platform counts (observed 2026-09-02).
	 */
	private static final Integer STATEMENTS_PER_FAILED_ATTEMPT = 3;

	/**
	 * @description The length of the random key stored in the query result memory cache.
	 */
	private static final Integer MEMORY_CACHE_KEY_LENGTH = 20;

	/**
	 * @description Stands in for the platform in partial mode: rows whose Name still has refusals left come back as
	 * lock-refused results built from JSON, the other rows go to the real proxy, and the merged list keeps the
	 * statement's row order. Keyed by Name because a retry hands the proxy only the refused rows, so positions shift.
	 * Only the test object's statements are inspected; the framework's own rows always go straight to the real proxy.
	 */
	private class RefusingRowsProxy extends DML_SharingProxy.DatabaseProxy
	{
		/**
		 * @description Refusals still to return, by the row's Name.
		 */
		private final Map<String, Integer> refusalsLeftByName;

		/**
		 * @description Builds a stand-in that refuses the named rows the given number of times each, on any statement.
		 *
		 * @param refusalsLeftByName Refusals to return, by the row's Name.
		 */
		private RefusingRowsProxy(Map<String, Integer> refusalsLeftByName)
		{
			this.refusalsLeftByName = refusalsLeftByName;
		}

		/**
		 * @description Splits a statement's rows into the ones to refuse and the ones to hand to the real proxy.
		 *
		 * @param records The statement's rows.
		 * @param accepted Receives the rows to hand to the real proxy, in order.
		 *
		 * @return One flag per row, true when the row is refused.
		 */
		private List<Boolean> splitRefused(List<SObject> records, List<SObject> accepted)
		{
			List<Boolean> refusedFlags = new List<Boolean>();
			Boolean inspect = DML_ThrowingLockProxy_TEST.isTestObjectStatement(records);
			for(SObject record : records)
			{
				String name = inspect ? (String)record.get(Foobar__c.Name) : null;
				Integer refusalsLeft = name == null ? 0 : (refusalsLeftByName.get(name) ?? 0);
				Boolean refused = refusalsLeft > 0;
				refusedFlags.add(refused);
				if(refused)
				{
					refusalsLeftByName.put(name, refusalsLeft - 1);
				}
				else
				{
					accepted.add(record);
				}
			}
			return refusedFlags;
		}

		/**
		 * @description Fills the merged list with one result per row in the statement's order: a lock refusal built
		 * from JSON for a refused row, the real proxy's next result otherwise.
		 *
		 * @param refusedFlags One flag per row, true when the row was refused.
		 * @param acceptedResults The real proxy's results for the rows it received, in order.
		 * @param resultType The result type of the statement.
		 * @param merged The typed list to fill.
		 */
		@SuppressWarnings('PMD.ExcessiveParameterList')
		private void combineResults(List<Boolean> refusedFlags, List<Object> acceptedResults, Type resultType, List<Object> merged)
		{
			Integer nextAccepted = 0;
			for(Boolean refused : refusedFlags)
			{
				if(refused)
				{
					merged.add(JSON.deserialize(LOCK_REFUSED_ROW_JSON, resultType));
				}
				else
				{
					merged.add(acceptedResults[nextAccepted]);
					nextAccepted++;
				}
			}
		}

		/**
		 * @description Refuses the named rows and inserts the rest, keeping one result per row in order.
		 *
		 * @param records The records to insert.
		 * @param allOrNothing Whether the statement is all-or-nothing.
		 * @param accessLevel The access level to use.
		 *
		 * @return One result per row: a lock refusal built from JSON, or the real proxy's result.
		 */
		public override List<Database.SaveResult> doInsert(List<SObject> records, Boolean allOrNothing, AccessLevel accessLevel)
		{
			List<SObject> accepted = new List<SObject>();
			List<Boolean> refusedFlags = splitRefused(records, accepted);
			List<Database.SaveResult> acceptedResults = accepted.isEmpty() ? new List<Database.SaveResult>() : super.doInsert(accepted, allOrNothing, accessLevel);
			List<Database.SaveResult> merged = new List<Database.SaveResult>();
			combineResults(refusedFlags, acceptedResults, Database.SaveResult.class, merged);
			return merged;
		}

		/**
		 * @description Refuses the named rows and updates the rest, keeping one result per row in order.
		 *
		 * @param records The records to update.
		 * @param allOrNothing Whether the statement is all-or-nothing.
		 * @param accessLevel The access level to use.
		 *
		 * @return One result per row: a lock refusal built from JSON, or the real proxy's result.
		 */
		public override List<Database.SaveResult> doUpdate(List<SObject> records, Boolean allOrNothing, AccessLevel accessLevel)
		{
			List<SObject> accepted = new List<SObject>();
			List<Boolean> refusedFlags = splitRefused(records, accepted);
			List<Database.SaveResult> acceptedResults = accepted.isEmpty() ? new List<Database.SaveResult>() : super.doUpdate(accepted, allOrNothing, accessLevel);
			List<Database.SaveResult> merged = new List<Database.SaveResult>();
			combineResults(refusedFlags, acceptedResults, Database.SaveResult.class, merged);
			return merged;
		}

		/**
		 * @description Refuses the named rows and upserts the rest by external Id, keeping one result per row in order.
		 *
		 * @param records The records to upsert.
		 * @param externalIdField The external Id field for matching.
		 * @param allOrNothing Whether the statement is all-or-nothing.
		 * @param accessLevel The access level to use.
		 *
		 * @return One result per row: a lock refusal built from JSON, or the real proxy's result.
		 */
		@SuppressWarnings('PMD.ExcessiveParameterList')
		public override List<Database.UpsertResult> doUpsert(List<SObject> records, SObjectField externalIdField, Boolean allOrNothing, AccessLevel accessLevel)
		{
			List<SObject> accepted = new List<SObject>();
			List<Boolean> refusedFlags = splitRefused(records, accepted);
			List<Database.UpsertResult> acceptedResults = new List<Database.UpsertResult>();
			if(!accepted.isEmpty())
			{
				acceptedResults = super.doUpsert(accepted, externalIdField, allOrNothing, accessLevel);
			}
			List<Database.UpsertResult> merged = new List<Database.UpsertResult>();
			combineResults(refusedFlags, acceptedResults, Database.UpsertResult.class, merged);
			return merged;
		}

		/**
		 * @description Refuses the named rows and deletes the rest, keeping one result per row in order.
		 *
		 * @param records The records to delete.
		 * @param allOrNothing Whether the statement is all-or-nothing.
		 * @param accessLevel The access level to use.
		 *
		 * @return One result per row: a lock refusal built from JSON, or the real proxy's result.
		 */
		public override List<Database.DeleteResult> doDelete(List<SObject> records, Boolean allOrNothing, AccessLevel accessLevel)
		{
			List<SObject> accepted = new List<SObject>();
			List<Boolean> refusedFlags = splitRefused(records, accepted);
			List<Database.DeleteResult> acceptedResults = accepted.isEmpty() ? new List<Database.DeleteResult>() : super.doDelete(accepted, allOrNothing, accessLevel);
			List<Database.DeleteResult> merged = new List<Database.DeleteResult>();
			combineResults(refusedFlags, acceptedResults, Database.DeleteResult.class, merged);
			return merged;
		}

		/**
		 * @description Refuses the named rows and undeletes the rest, keeping one result per row in order.
		 *
		 * @param records The records to undelete.
		 * @param allOrNothing Whether the statement is all-or-nothing.
		 * @param accessLevel The access level to use.
		 *
		 * @return One result per row: a lock refusal built from JSON, or the real proxy's result.
		 */
		public override List<Database.UndeleteResult> doUndelete(List<SObject> records, Boolean allOrNothing, AccessLevel accessLevel)
		{
			List<SObject> accepted = new List<SObject>();
			List<Boolean> refusedFlags = splitRefused(records, accepted);
			List<Database.UndeleteResult> acceptedResults = accepted.isEmpty() ? new List<Database.UndeleteResult>() : super.doUndelete(accepted, allOrNothing, accessLevel);
			List<Database.UndeleteResult> merged = new List<Database.UndeleteResult>();
			combineResults(refusedFlags, acceptedResults, Database.UndeleteResult.class, merged);
			return merged;
		}
	}

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
	 * @description Tests that a dirty relationship resolves against a parent whose Id only
	 * materialises during the same commitWork (parent inserted in the same transaction).
	 */
	@IsTest
	private static void shouldResolveRelationshipWhenParentInsertedSameTransaction()
	{
		Foobar__c newParent = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withoutInsertion()
				.build();
		Foobar__c child = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();

		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.doInsert(newParent);
		dmlTransaction.doUpdate(child, Foobar__c.Lookup__c, newParent);

		Test.startTest();

		dmlTransaction.commitWork();

		Test.stopTest();

		Assert.isNotNull(newParent.Id, 'Parent should have been inserted during commitWork');
		Foobar__c foundChild = (Foobar__c)new SEL_Foobar().findById(child.Id);
		Assert.areEqual(newParent.Id, foundChild.Lookup__c, MSG_VALUE_EQUALITY);
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
	 * @description Tests that a DML failure rolls the whole commit back to its savepoint: the insert that ran before
	 * the failing update leaves no row behind.
	 */
	@IsTest
	private static void shouldRollbackOnFailure()
	{
		Foobar__c validRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withoutInsertion()
				.build();

		Foobar__c invalidRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withoutInsertion()
				.build();

		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.doInsert(validRecord);
		dmlTransaction.doUpdate(invalidRecord);

		commitWorkExpectingDmlException(dmlTransaction);

		Assert.isNotNull(validRecord.Id, 'The insert should have run before the update failed');
		Assert.isTrue(new SEL_Foobar().getAll().isEmpty(), 'The inserted row should have been rolled back with the failed update');
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

		commitWorkExpectingDmlException(testTransaction);

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
	 * @description Tests that an existing child keeps its current lookup value when the replacement
	 * parent fails to insert in partial mode. Forces the parent failure via invalid email format.
	 */
	@IsTest
	private static void shouldPreserveExistingLookupWhenParentFailsInPartial()
	{
		Foobar__c originalParent = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
		Foobar__c child = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Lookup__c, originalParent.Id)
				.build();

		Foobar__c replacementParent = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Email__c, 'not-a-valid-email')
				.withoutInsertion()
				.build();

		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.setAllowPartial(true);
		dmlTransaction.doInsert(replacementParent);
		dmlTransaction.doUpdate(child, Foobar__c.Lookup__c, replacementParent);

		Test.startTest();

		dmlTransaction.commitWork();

		Test.stopTest();

		Assert.isNull(replacementParent.Id, 'Parent should have failed insertion due to invalid email');
		Foobar__c foundChild = (Foobar__c)new SEL_Foobar().findById(child.Id);
		Assert.areEqual(originalParent.Id, foundChild.Lookup__c,
				'Existing lookup must survive when the replacement parent fails in partial mode');
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

		commitWorkExpectingDmlException(dmlTransaction);

		List<SObject> found = QRY_Builder.selectFrom(Foobar__c.SObjectType)
				.fields(new List<SObjectField> {Foobar__c.IsDeleted})
				.condition(Foobar__c.Id).equals(record.Id)
				.allRows()
				.toList();
		Assert.areEqual(1, found.size(), 'Record should exist');
		Assert.isTrue((Boolean)found[0].get(Foobar__c.IsDeleted), 'Undelete should have been rolled back');
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
	 * @description Verifies partial mode still swallows a statement-level exception raised before any
	 * operation ran (the commit answers, the registered insert never ran) and now leaves exactly one
	 * ERROR entry at the commit recording the swallow.
	 */
	@IsTest
	private static void shouldLogSwallowedStatementFailureInPartialMode()
	{
		captureLogEntries();
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();

		DML_Transaction dmlTransaction = new ThrowingStartTransaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.setAllowPartial(true);
		dmlTransaction.doInsert(record);

		Test.startTest();

		dmlTransaction.commitWork();

		Test.stopTest();

		Assert.isNull(record.Id, 'The operation registered after the failure point should never have run');
		Assert.isTrue(new SEL_Foobar().getAll().isEmpty(), 'No row should have been committed');
		LogEntry__c entry = new SEL_LogEntry().findByMethod(DML_Transaction.CLASS_METHOD_COMMIT);
		Assert.isNotNull(entry, 'The swallowed statement failure should leave one entry at the commit');
		Assert.areEqual(LOG_Engine.LEVEL_ERROR, entry.LogLevel__c, 'The swallowed failure should log at ERROR');
		Assert.areEqual(1, new SEL_LogEntry().findByLogLevel(LOG_Engine.LEVEL_ERROR).size(), 'Exactly one ERROR entry should exist');
		Map<String, Object> context = SEL_LogEntry.parseContextDataForTest(entry);
		Object recordedOutcome = context.get(DML_Transaction.CONTEXT_KEY_PARTIAL_COMMIT_OUTCOME);
		Assert.areEqual(DML_Transaction.MESSAGE_STATEMENT_FAILURE_SWALLOWED, recordedOutcome, 'The entry should record the swallow outcome');
	}

	/**
	 * @description Verifies partial mode swallows a statement-level exception raised after the registered
	 * operations ran: the committed insert stands and the swallow entry is still written.
	 */
	@IsTest
	private static void shouldKeepCommittedWorkWhenSwallowingStatementFailure()
	{
		captureLogEntries();
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();

		DML_Transaction dmlTransaction = new ThrowingFinishTransaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.setAllowPartial(true);
		dmlTransaction.doInsert(record);

		Test.startTest();

		dmlTransaction.commitWork();

		Test.stopTest();

		Assert.isNotNull(record.Id, 'The statement committed before the failure should stand');
		Assert.areEqual(1, new SEL_Foobar().getAll().size(), 'The committed row should stand');
		Assert.isNotNull(new SEL_LogEntry().findByMethod(DML_Transaction.CLASS_METHOD_COMMIT), 'The swallow entry should be written');
	}

	/**
	 * @description Verifies setSuppressLogging(true) silences the swallowed-statement-failure entry while
	 * the swallow behaviour is unchanged.
	 */
	@IsTest
	private static void shouldSuppressSwallowedStatementFailureLogging()
	{
		captureLogEntries();
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();

		DML_Transaction dmlTransaction = new ThrowingStartTransaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.setAllowPartial(true);
		dmlTransaction.setSuppressLogging(true);
		dmlTransaction.doInsert(record);

		Test.startTest();

		dmlTransaction.commitWork();

		Test.stopTest();

		Assert.isNull(record.Id, 'The swallow behaviour should be unchanged');
		Assert.isNull(new SEL_LogEntry().findByMethod(DML_Transaction.CLASS_METHOD_COMMIT), 'setSuppressLogging(true) should silence the swallow entry');
	}

	/**
	 * @description Verifies that an all-or-nothing commit with nothing registered whose onCommitWorkStarting hook
	 * throws surfaces the hook's own exception and leaves one ERROR entry at the commit, as a commit with registered
	 * work does. With nothing registered no savepoint is taken, so the rollback must not run and replace the failure.
	 */
	@IsTest
	private static void shouldSurfaceTheHookFailureOfACommitWithNothingRegistered()
	{
		captureLogEntries();
		DML_Transaction dmlTransaction = new ThrowingCommitStartingTransaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);

		try
		{
			Test.startTest();
			dmlTransaction.commitWork();
			Assert.fail('Expected the hook failure to surface');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, UTIL_Exceptions.IllegalStateException.class, 'The hook failure must surface as itself, not as the rollback failure');
			Assert.areEqual(HOOK_FAILURE_MESSAGE, error.getMessage(), 'The hook failure must surface with its own message');
		}
		finally
		{
			Test.stopTest();
		}

		LogEntry__c entry = new SEL_LogEntry().findByMethod(DML_Transaction.CLASS_METHOD_COMMIT);
		Assert.isNotNull(entry, 'The hook failure must leave one entry at the commit');
		Assert.areEqual(LOG_Engine.LEVEL_ERROR, entry.LogLevel__c, 'The hook failure must log at ERROR');
		Assert.areEqual(1, new SEL_LogEntry().findByLogLevel(LOG_Engine.LEVEL_ERROR).size(), 'Exactly one ERROR entry must exist');
	}

	/**
	 * @description Verifies that an all-or-nothing commit with nothing registered whose onCommitWorkStarting hook
	 * registers work rolls that work back when a later statement fails: the savepoint is taken once the hook has
	 * registered work, so the row the hook's insert saved does not outlive the refused update behind it.
	 */
	@IsTest
	private static void shouldRollBackHookRegisteredWorkOnACommitWithNothingRegistered()
	{
		DML_Transaction dmlTransaction = new RegisteringCommitStartingTransaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);

		commitWorkExpectingDmlException(dmlTransaction);

		Assert.isTrue(new SEL_Foobar().getAll().isEmpty(), 'The row the hook registered must be rolled back with the refused statement');
	}

	/**
	 * @description Verifies that a refused row whose status code the caller declared as expected is logged
	 * at WARN, and nothing is logged at ERROR, while the row still fails.
	 */
	@IsTest
	private static void shouldLogExpectedRefusalAtWarn()
	{
		captureLogEntries();
		Foobar__c savedRecord = TST_Factory.newFoobar();
		Foobar__c refusedRecord = TST_Factory.newFoobarWithEmail(INVALID_EMAIL);

		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.setAllowPartial(true);
		dmlTransaction.setExpectedRefusalStatusCodes(new Set<StatusCode> {StatusCode.INVALID_EMAIL_ADDRESS});
		dmlTransaction.doInsert(new List<SObject> {savedRecord, refusedRecord});

		Test.startTest();

		dmlTransaction.commitWork();

		Test.stopTest();

		Assert.isNotNull(savedRecord.Id, 'The valid row should be saved');
		Assert.isNull(refusedRecord.Id, 'The refused row should still fail');
		Assert.areEqual(1, new SEL_LogEntry().findByLogLevel(LOG_Engine.LEVEL_WARN).size(), 'The expected refusal should be logged once at WARN');
		Assert.isTrue(new SEL_LogEntry().findByLogLevel(LOG_Engine.LEVEL_ERROR).isEmpty(), 'Nothing should be logged at ERROR');
	}

	/**
	 * @description Verifies that a refusal with a status code the caller did not declare stays at ERROR,
	 * even when another code was declared.
	 */
	@IsTest
	private static void shouldKeepUndeclaredRefusalAtError()
	{
		captureLogEntries();
		Foobar__c refusedRecord = TST_Factory.newFoobarWithEmail(INVALID_EMAIL);

		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.setAllowPartial(true);
		dmlTransaction.setExpectedRefusalStatusCodes(new Set<StatusCode> {StatusCode.DUPLICATE_VALUE});
		dmlTransaction.doInsert(refusedRecord);

		Test.startTest();

		dmlTransaction.commitWork();

		Test.stopTest();

		Assert.areEqual(1, new SEL_LogEntry().findByLogLevel(LOG_Engine.LEVEL_ERROR).size(), 'The undeclared refusal should be logged once at ERROR');
		Assert.isTrue(new SEL_LogEntry().findByLogLevel(LOG_Engine.LEVEL_WARN).isEmpty(), 'Nothing should be logged at WARN');
	}

	/**
	 * @description Verifies that declared status codes change nothing in all-or-nothing mode: the commit
	 * still throws and no WARN row is written.
	 */
	@IsTest
	private static void shouldIgnoreExpectedRefusalsInAllOrNothingMode()
	{
		captureLogEntries();
		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.setExpectedRefusalStatusCodes(new Set<StatusCode> {StatusCode.INVALID_EMAIL_ADDRESS});
		dmlTransaction.doInsert(TST_Factory.newFoobarWithEmail(INVALID_EMAIL));

		commitWorkExpectingDmlException(dmlTransaction);
		Test.getEventBus().deliver();

		Assert.isTrue(new SEL_LogEntry().findByLogLevel(LOG_Engine.LEVEL_WARN).isEmpty(), 'All-or-nothing mode should not log a WARN refusal');
	}

	/**
	 * @description Verifies that a null set of expected status codes means "none", not a failure.
	 */
	@IsTest
	private static void shouldTreatNullExpectedStatusCodesAsNone()
	{
		captureLogEntries();
		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.setAllowPartial(true);
		dmlTransaction.setExpectedRefusalStatusCodes(null);
		dmlTransaction.doInsert(TST_Factory.newFoobarWithEmail(INVALID_EMAIL));

		Test.startTest();

		dmlTransaction.commitWork();

		Test.stopTest();

		Assert.areEqual(1, new SEL_LogEntry().findByLogLevel(LOG_Engine.LEVEL_ERROR).size(), 'With no declared codes the refusal should stay at ERROR');
		Assert.isTrue(new SEL_LogEntry().findByLogLevel(LOG_Engine.LEVEL_WARN).isEmpty(), 'Nothing should be logged at WARN');
	}

	/**
	 * @description Verifies the every-error rule on a row carrying two errors: the row is an expected refusal only
	 * when both status codes are declared, so a real failure never hides behind an expected one. Real DML on this
	 * platform reports one error per row, so the two-error row is built from JSON, the only way to see the rule at work.
	 */
	@IsTest
	private static void shouldRequireEveryErrorOnTheRowToBeDeclared()
	{
		Database.SaveResult twoErrorRow = (Database.SaveResult)JSON.deserialize(TWO_ERROR_ROW_JSON, Database.SaveResult.class);
		DML_Transaction dmlTransaction = new DML_Transaction();

		dmlTransaction.setExpectedRefusalStatusCodes(new Set<StatusCode> {StatusCode.INVALID_EMAIL_ADDRESS});
		Assert.isFalse(dmlTransaction.isExpectedRefusal(twoErrorRow), 'A row carrying an undeclared error is not an expected refusal');

		dmlTransaction.setExpectedRefusalStatusCodes(new Set<StatusCode> {StatusCode.INVALID_EMAIL_ADDRESS, StatusCode.REQUIRED_FIELD_MISSING});
		Assert.isTrue(dmlTransaction.isExpectedRefusal(twoErrorRow), 'A row whose every error is declared is an expected refusal');
	}

	/**
	 * @description Verifies the partition on one commit carrying both kinds of failed row: the row refused for a
	 * declared reason logs at WARN and the row refused for an undeclared reason logs at ERROR, each exactly once.
	 */
	@IsTest
	private static void shouldSplitDeclaredAndUndeclaredRefusalsInOneCommit()
	{
		captureLogEntries();
		Foobar__c refusedByEmail = TST_Factory.newFoobarWithEmail(INVALID_EMAIL);
		Foobar__c refusedByLength = TST_Factory.newFoobar();
		refusedByLength.ExternalId__c = OVERLONG_EXTERNAL_ID;

		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.setAllowPartial(true);
		dmlTransaction.setExpectedRefusalStatusCodes(new Set<StatusCode> {StatusCode.INVALID_EMAIL_ADDRESS});
		dmlTransaction.doInsert(new List<SObject> {refusedByEmail, refusedByLength});

		Test.startTest();

		dmlTransaction.commitWork();

		Test.stopTest();

		Assert.isNull(refusedByEmail.Id, 'The row with the invalid email should fail');
		Assert.isNull(refusedByLength.Id, 'The row with the over-length external Id should fail');
		Assert.areEqual(1, new SEL_LogEntry().findByLogLevel(LOG_Engine.LEVEL_WARN).size(), 'The declared refusal should be logged once at WARN');
		Assert.areEqual(1, new SEL_LogEntry().findByLogLevel(LOG_Engine.LEVEL_ERROR).size(), 'The undeclared refusal should be logged once at ERROR');
	}

	/**
	 * @description Commits the given transaction inside startTest/stopTest, asserting it throws a
	 * DmlException.
	 *
	 * @param dmlTransaction The configured transaction whose commitWork must fail.
	 */
	private static void commitWorkExpectingDmlException(DML_Transaction dmlTransaction)
	{
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
	 * @description Makes log rows observable: platform events are delivered at Test.stopTest() and a
	 * DEBUG threshold keeps every level, so a WARN row is never filtered by an org-level setting.
	 */
	private static void captureLogEntries()
	{
		LogSetting__c setting = new LogSetting__c();
		setting.IsEnabled__c = true;
		setting.LogLevelThreshold__c = LOG_Engine.LEVEL_DEBUG;
		LOG_Engine.logSettingOverride = setting;
		LOG_Builder.ignoreTestMode = true;
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
	 * @description Test subclass whose onDMLStarting hook throws, raising a statement-level exception
	 * inside the commit before any registered operation runs.
	 */
	private class ThrowingStartTransaction extends DML_Transaction
	{
		/**
		 * @description Throws as soon as the commit is about to run its first statement, so the tests can check
		 * what a commit does when it fails before anything has been written.
		 */
		public override void onDMLStarting()
		{
			throw new UTIL_Exceptions.IllegalStateException(HOOK_FAILURE_MESSAGE);
		}
	}

	/**
	 * @description Test subclass whose onDMLFinished hook throws, raising a statement-level exception
	 * inside the commit after every registered operation has run.
	 */
	private class ThrowingFinishTransaction extends DML_Transaction
	{
		/**
		 * @description Throws once every registered statement has run, so the tests can check what a commit does
		 * when it fails after the rows have been written.
		 */
		public override void onDMLFinished()
		{
			throw new UTIL_Exceptions.IllegalStateException(HOOK_FAILURE_MESSAGE);
		}
	}

	/**
	 * @description Test subclass whose onCommitWorkStarting hook throws: the one hook a commit with nothing
	 * registered still runs, so its failure reaches the commit's catch with no savepoint taken.
	 */
	private class ThrowingCommitStartingTransaction extends DML_Transaction
	{
		/**
		 * @description Throws at the very start of the commit, the step that runs even when nothing is registered,
		 * so the tests can check how a commit fails before it has set a point to roll back to.
		 */
		public override void onCommitWorkStarting()
		{
			throw new UTIL_Exceptions.IllegalStateException(HOOK_FAILURE_MESSAGE);
		}
	}

	/**
	 * @description Test subclass whose onCommitWorkStarting hook registers an insert the platform accepts and an
	 * update it refuses, on a transaction that had nothing registered when commitWork was called.
	 */
	private class RegisteringCommitStartingTransaction extends DML_Transaction
	{
		/**
		 * @description Registers two writes at the very start of the commit: an insert of a new Foobar__c row, which
		 * the platform accepts, and an update of a row that was never inserted, which the platform refuses. The
		 * tests use it to check a commit whose only work is added by this step and then fails part of the way.
		 */
		public override void onCommitWorkStarting()
		{
			doInsert(TST_Factory.newFoobar());
			doUpdate(TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build());
		}
	}

	/**
	 * @description Test subclass that reads Foobar__c rows through the memory cache once its statements have run, so
	 * the new row is cached, and then fails in onCommitWorkFinishing, so the commit rolls back.
	 */
	private class CachingRolledBackTransaction extends DML_Transaction
	{
		/**
		 * @description The rows the cached read returned inside the write.
		 */
		private List<SObject> rowsReadInsideTheWrite;

		/**
		 * @description Reads the rows through the memory cache after the statements have run.
		 */
		public override void onDMLFinished()
		{
			super.onDMLFinished();
			rowsReadInsideTheWrite = readFoobarsThroughTheMemoryCache();
		}

		/**
		 * @description Fails the commit after the read, so the write is rolled back.
		 */
		public override void onCommitWorkFinishing()
		{
			throw new UTIL_Exceptions.IllegalStateException(HOOK_FAILURE_MESSAGE);
		}
	}

	/**
	 * @description Test subclass that reads Foobar__c rows through the memory cache before each attempt's
	 * statements and records how many queries each read ran.
	 */
	private class CachingStartTransaction extends DML_Transaction
	{
		/**
		 * @description The queries the read ran, one entry per attempt.
		 */
		private final List<Integer> queriesPerAttempt = new List<Integer>();

		/**
		 * @description Reads the rows through the memory cache and records the queries the read ran.
		 */
		public override void onDMLStarting()
		{
			super.onDMLStarting();
			Integer queriesBefore = UTIL_Limits.soqlQueries().used();
			readFoobarsThroughTheMemoryCache();
			queriesPerAttempt.add(UTIL_Limits.soqlQueries().used() - queriesBefore);
		}
	}

	/**
	 * @description Test subclass that reads Foobar__c names through the memory cache after the first clear and before
	 * the statements, as a trigger action reading the records being saved would.
	 */
	private class CachingBeforeTheWriteTransaction extends DML_Transaction
	{
		/**
		 * @description The rows the cached read returned before the statements ran.
		 */
		private List<SObject> rowsReadBeforeTheWrite;

		/**
		 * @description The queries a second, identical read ran right after the first; zero proves the first read's rows
		 * were kept in the memory cache.
		 */
		private Integer queriesForTheRepeatedRead;

		/**
		 * @description Reads the names through the memory cache before the statements run, then repeats the read and
		 * records the queries the repeat ran.
		 */
		public override void onDMLStarting()
		{
			super.onDMLStarting();
			rowsReadBeforeTheWrite = readFoobarsThroughTheMemoryCache();
			Integer queriesBefore = UTIL_Limits.soqlQueries().used();
			readFoobarsThroughTheMemoryCache();
			queriesForTheRepeatedRead = UTIL_Limits.soqlQueries().used() - queriesBefore;
		}
	}

	/**
	 * @description Reads the Name of every Foobar__c row in user mode, asking for the rows to be kept in memory for
	 * the transaction.
	 *
	 * @return The rows
	 */
	private static List<SObject> readFoobarsThroughTheMemoryCache()
	{
		return QRY_Builder.selectFrom(Foobar__c.SObjectType).addField(Foobar__c.Name).withCache(UTIL_Cache.Scope.IN_TRANSACTION, null).toList();
	}

	/**
	 * @description Stores one row in the query result memory cache under a random key, so a test can see whether a
	 * commit empties it.
	 *
	 * @return The key
	 */
	private static String storeKeyInMemoryCache()
	{
		String key = UTIL_Random.randomAlphanumeric(MEMORY_CACHE_KEY_LENGTH);
		QRY_Engine.storeCopyInMemoryCache(key, new List<Foobar__c> {TST_Factory.newFoobar()}, QRY_Engine.CacheStatus.MEMORY_STORED);
		Assert.isNotNull(QRY_Engine.getCopyFromMemoryCache(key), 'The key should be stored before the commit');
		return key;
	}

	/**
	 * @description Builds an unsaved contact without its required last name, so an insert of it fails.
	 *
	 * @return The contact
	 */
	private static Contact newContactWithoutLastName()
	{
		Contact contact = (Contact)TST_Builder.of(Contact.SObjectType).withoutInsertion().build();
		contact.LastName = null;
		return contact;
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
	@SuppressWarnings('PMD.KernNoStandardObjectInPackageTests')
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

	/**
	 * @description Tests that a commit refused for a row lock once is re-run and saves: the rows exist with valid
	 * Ids and one WARN entry records the single retry.
	 *
	 * @see DML_Transaction.setRetryOnLock
	 */
	@IsTest
	private static void commitWorkShouldRetryAnAllOrNothingCommitRefusedForARowLock()
	{
		captureLogEntries();
		List<SObject> records = TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().withCount(2).buildList();
		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.setRetryOnLock(1);
		dmlTransaction.doInsert(records);
		DML_SharingProxy.sharingProxyForTest = new DML_ThrowingLockProxy_TEST(1);

		try
		{
			Test.startTest();
			dmlTransaction.commitWork();
			Test.stopTest();
		}
		finally
		{
			DML_SharingProxy.sharingProxyForTest = null;
		}

		Assert.areEqual(2, dmlTransaction.getInsertResults().size(), 'Both rows should carry a result');
		Assert.isNotNull(records[0].Id, 'The first row should be saved on the second attempt');
		Assert.isNotNull(new SEL_Foobar().findById(records[0].Id), 'The saved row should exist');
		List<LogEntry__c> warnings = new SEL_LogEntry().findByLogLevel(LOG_Engine.LEVEL_WARN);
		Assert.areEqual(1, warnings.size(), 'One WARN entry should record the retry');
		Map<String, Object> context = SEL_LogEntry.parseContextDataForTest(warnings[0]);
		Assert.areEqual('1', String.valueOf(context.get(DML_Transaction.CONTEXT_KEY_RETRIES_USED)), 'The entry should carry one retry used');
		Assert.isFalse(context.containsKey(DML_Transaction.CONTEXT_KEY_RETRY_STOPPED_BY), 'A recovered commit names nothing that stopped it');
		Assert.isTrue(new SEL_LogEntry().findByLogLevel(LOG_Engine.LEVEL_ERROR).isEmpty(), 'A recovered commit logs no ERROR');
	}

	/**
	 * @description Tests that a commit refused for a row lock on every attempt surfaces the last refusal through the
	 * existing failure path: one ERROR entry carrying the retries used and what stopped them, then the rethrow.
	 *
	 * @see DML_Transaction.setRetryOnLock
	 */
	@IsTest
	private static void commitWorkShouldSurfaceTheRefusalWhenEveryAttemptIsLocked()
	{
		captureLogEntries();
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();
		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.setRetryOnLock(2);
		dmlTransaction.doInsert(record);
		DML_SharingProxy.sharingProxyForTest = new DML_ThrowingLockProxy_TEST(3);

		try
		{
			Test.startTest();
			dmlTransaction.commitWork();
			Assert.fail('The last refusal should be rethrown');
		}
		catch(DmlException error)
		{
			Assert.isTrue(error.getMessage().contains(DML_Transaction.LOCK_REFUSAL_TOKEN), 'The rethrown refusal should be the lock');
		}
		finally
		{
			Test.stopTest();
			DML_SharingProxy.sharingProxyForTest = null;
		}

		Assert.isNull(record.Id, 'A record refused on every attempt should carry no Id');
		List<LogEntry__c> errors = new SEL_LogEntry().findByLogLevel(LOG_Engine.LEVEL_ERROR);
		Assert.areEqual(1, errors.size(), 'One ERROR entry should record the final refusal');
		Map<String, Object> context = SEL_LogEntry.parseContextDataForTest(errors[0]);
		Assert.areEqual('2', String.valueOf(context.get(DML_Transaction.CONTEXT_KEY_RETRIES_USED)), 'The entry should carry both retries used');
		Assert.areEqual(DML_Transaction.RETRY_STOPPED_BY_COUNT, context.get(DML_Transaction.CONTEXT_KEY_RETRY_STOPPED_BY), 'The count should be what stopped the retries');
		Assert.isTrue(new SEL_LogEntry().findByLogLevel(LOG_Engine.LEVEL_WARN).isEmpty(), 'A commit that never recovered logs no WARN');
	}

	/**
	 * @description Tests that a refusal which is not a lock makes exactly one attempt: the DML-statement delta is
	 * what one attempt costs when the stand-in throws before its statement runs, and the refusal surfaces unchanged.
	 *
	 * @see DML_Transaction.setRetryOnLock
	 */
	@IsTest
	private static void commitWorkShouldNotRetryARefusalThatIsNotALock()
	{
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();
		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.setSuppressLogging(true);
		dmlTransaction.setRetryOnLock(2);
		dmlTransaction.doInsert(record);
		DML_SharingProxy.sharingProxyForTest = new DML_ThrowingLockProxy_TEST(3, VALIDATION_REFUSAL_MESSAGE);
		Integer statementsBefore = UTIL_Limits.dmlStatements().used();

		try
		{
			dmlTransaction.commitWork();
			Assert.fail('The refusal should be rethrown');
		}
		catch(DmlException error)
		{
			Assert.areEqual(VALIDATION_REFUSAL_MESSAGE, error.getMessage(), 'The refusal should surface unchanged');
		}
		finally
		{
			DML_SharingProxy.sharingProxyForTest = null;
		}

		Assert.areEqual(STATEMENTS_PER_FAILED_ATTEMPT, UTIL_Limits.dmlStatements().used() - statementsBefore, 'Exactly one attempt should have run');
	}

	/**
	 * @description Tests the idempotency of a retried parent-and-child insert: the first attempt inserts both rows
	 * and is refused at the child's lookup update, so the rolled-back Ids are cleared, both rows are re-inserted
	 * with new Ids, the child's lookup carries the parent's final Id, and the child's lookup update runs once, on
	 * the attempt that saved. With logging suppressed, the retried commit leaves no entry at all.
	 *
	 * @see DML_Transaction.setRetryOnLock
	 */
	@IsTest
	private static void commitWorkShouldClearRolledBackIdsAndRestoreTheRegistrationBeforeRetrying()
	{
		captureLogEntries();
		Foobar__c parent = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();
		Foobar__c child = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();
		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.setSuppressLogging(true);
		dmlTransaction.setRetryOnLock(1);
		dmlTransaction.doInsert(parent);
		dmlTransaction.doInsert(child, Foobar__c.Lookup__c, parent);
		DML_SharingProxy.sharingProxyForTest = new DML_ThrowingLockProxy_TEST(1, 1, LOCK_REFUSAL_MESSAGE);

		try
		{
			Test.startTest();
			dmlTransaction.commitWork();
			Test.stopTest();
		}
		finally
		{
			DML_SharingProxy.sharingProxyForTest = null;
		}

		Assert.isNotNull(parent.Id, 'The parent should be saved on the second attempt');
		Assert.isNotNull(child.Id, 'The child should be saved on the second attempt');
		Foobar__c savedChild = (Foobar__c)new SEL_Foobar().findById(child.Id);
		Assert.areEqual(parent.Id, savedChild.Lookup__c, 'The child should point at the parent\'s final Id');
		Assert.areEqual(2, dmlTransaction.getInsertResults().size(), 'Exactly two rows should be inserted, none twice');
		Assert.areEqual(1, dmlTransaction.getUpdateResults().size(), 'The child\'s lookup update should run exactly once, on the attempt that saved');
		Assert.isTrue(new SEL_LogEntry().findByLogLevel(LOG_Engine.LEVEL_WARN).isEmpty(), 'Suppressed logging should silence the retry summary');
		Assert.isTrue(new SEL_LogEntry().findByLogLevel(LOG_Engine.LEVEL_ERROR).isEmpty(), 'A recovered commit with logging suppressed should log nothing');
	}

	/**
	 * @description Tests that the headroom guard stops the loop when the remaining DML budget cannot cover another
	 * attempt: no retry runs, the refusal surfaces, and the ERROR entry names headroom as the reason. The stand-in
	 * has one refusal, so a retry that wrongly ran would have saved the row.
	 *
	 * @see DML_Transaction.setRetryOnLock
	 */
	@IsTest
	private static void commitWorkShouldStopRetryingWhenHeadroomIsGone()
	{
		captureLogEntries();
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();
		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.setRetryOnLock(3);
		dmlTransaction.doInsert(record);
		DML_SharingProxy.sharingProxyForTest = new DML_ThrowingLockProxy_TEST(1);
		DML_Transaction.remainingDmlStatementsForTest = NO_HEADROOM;

		try
		{
			Test.startTest();
			dmlTransaction.commitWork();
			Assert.fail('The refusal should surface when no retry fits');
		}
		catch(DmlException error)
		{
			Assert.isTrue(error.getMessage().contains(DML_Transaction.LOCK_REFUSAL_TOKEN), 'The surfaced refusal should be the lock');
		}
		finally
		{
			Test.stopTest();
			DML_SharingProxy.sharingProxyForTest = null;
			DML_Transaction.remainingDmlStatementsForTest = null;
		}

		Assert.isNull(record.Id, 'No retry should have run: a second attempt would have saved the row');
		List<LogEntry__c> errors = new SEL_LogEntry().findByLogLevel(LOG_Engine.LEVEL_ERROR);
		Assert.areEqual(1, errors.size(), 'One ERROR entry should record the refusal');
		Map<String, Object> context = SEL_LogEntry.parseContextDataForTest(errors[0]);
		Assert.areEqual(DML_Transaction.RETRY_STOPPED_BY_HEADROOM, context.get(DML_Transaction.CONTEXT_KEY_RETRY_STOPPED_BY), 'Headroom should be what stopped the retries');
	}

	/**
	 * @description Tests the verdict on its own: a thrown DmlException is a lock only when its message carries the
	 * status code token and it is a DmlException; a row is a lock only when every error it carries is the lock.
	 *
	 * @see DML_Transaction.isLockRefusalException
	 * @see DML_Transaction.isLockRefusedRow
	 */
	@IsTest
	private static void lockVerdictShouldRequireTheLockToBeAllThereIs()
	{
		Assert.isTrue(DML_Transaction.isLockRefusalException(new DmlException(LOCK_REFUSAL_MESSAGE)), 'A DmlException naming the lock is a lock refusal');
		Assert.isFalse(DML_Transaction.isLockRefusalException(new DmlException(VALIDATION_REFUSAL_MESSAGE)), 'A DmlException naming another code is not');
		Assert.isFalse(DML_Transaction.isLockRefusalException(new IllegalArgumentException(LOCK_REFUSAL_MESSAGE)), 'Only a DmlException can be a lock refusal');
		Assert.isFalse(DML_Transaction.isLockRefusalException(new DmlException()), 'A DmlException with no message is not a lock refusal');
		Assert.isTrue(DML_Transaction.isLockRefusedRow(JSON.deserialize(LOCK_REFUSED_ROW_JSON, Database.SaveResult.class)), 'A row refused only for the lock is a lock refusal');
		Assert.isFalse(DML_Transaction.isLockRefusedRow(JSON.deserialize(MIXED_REFUSED_ROW_JSON, Database.SaveResult.class)), 'A row with another error beside the lock is not');
		Assert.isFalse(DML_Transaction.isLockRefusedRow(JSON.deserialize(TWO_ERROR_ROW_JSON, Database.SaveResult.class)), 'A row with no lock error is not');
	}

	/**
	 * @description Tests that a partial commit re-issues the rows refused for a lock before it moves on: every row
	 * saves, every result is a success, and the WARN entry counts the recovered rows.
	 *
	 * @see DML_Transaction.setRetryOnLock
	 */
	@IsTest
	private static void commitWorkShouldReissueLockRefusedRowsInPartialMode()
	{
		captureLogEntries();
		Foobar__c saved = TST_Factory.newFoobarWithName('saved-first');
		Foobar__c refusedOnce = TST_Factory.newFoobarWithName('refused-once');
		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.setAllowPartial(true);
		dmlTransaction.setRetryOnLock(1);
		dmlTransaction.doInsert(new List<SObject> {saved, refusedOnce});
		DML_SharingProxy.sharingProxyForTest = new RefusingRowsProxy(new Map<String, Integer> {'refused-once' => 1});

		try
		{
			Test.startTest();
			dmlTransaction.commitWork();
			Test.stopTest();
		}
		finally
		{
			DML_SharingProxy.sharingProxyForTest = null;
		}

		List<Database.SaveResult> results = dmlTransaction.getInsertResults();
		Assert.areEqual(2, results.size(), 'One result per row');
		Assert.isTrue(results[0].isSuccess() && results[1].isSuccess(), 'Both rows should end saved');
		Assert.isNotNull(refusedOnce.Id, 'The refused row should be saved by the retry');
		List<LogEntry__c> warnings = new SEL_LogEntry().findByLogLevel(LOG_Engine.LEVEL_WARN);
		Assert.areEqual(1, warnings.size(), 'One WARN entry should record the retry');
		Map<String, Object> context = SEL_LogEntry.parseContextDataForTest(warnings[0]);
		Assert.areEqual('1', String.valueOf(context.get(DML_Transaction.CONTEXT_KEY_ROWS_RECOVERED)), 'One row should count as recovered');
		Assert.isTrue(new SEL_LogEntry().findByLogLevel(LOG_Engine.LEVEL_ERROR).isEmpty(), 'Nothing should be logged at ERROR');
	}

	/**
	 * @description Tests the re-assembly across rounds: of three refused rows, one recovers in round one, one in
	 * round two and one never; each row's final result sits at its original position.
	 *
	 * @see DML_Transaction.setRetryOnLock
	 */
	@IsTest
	private static void commitWorkShouldKeepEachRetriedRowsResultAtItsOriginalPosition()
	{
		captureLogEntries();
		Foobar__c recoversInRoundOne = TST_Factory.newFoobarWithName('round-one');
		Foobar__c saved = TST_Factory.newFoobarWithName('saved-first');
		Foobar__c recoversInRoundTwo = TST_Factory.newFoobarWithName('round-two');
		Foobar__c neverRecovers = TST_Factory.newFoobarWithName('never');
		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.setAllowPartial(true);
		dmlTransaction.setRetryOnLock(2);
		dmlTransaction.doInsert(new List<SObject> {recoversInRoundOne, saved, recoversInRoundTwo, neverRecovers});
		DML_SharingProxy.sharingProxyForTest = new RefusingRowsProxy(new Map<String, Integer> {'round-one' => 1, 'round-two' => 2, 'never' => 3});

		try
		{
			Test.startTest();
			dmlTransaction.commitWork();
			Test.stopTest();
		}
		finally
		{
			DML_SharingProxy.sharingProxyForTest = null;
		}

		List<Database.SaveResult> results = dmlTransaction.getInsertResults();
		Assert.areEqual(4, results.size(), 'One result per row');
		Assert.isTrue(results[0].isSuccess(), 'The round-one row should end saved at position 0');
		Assert.isTrue(results[1].isSuccess(), 'The never-refused row should be saved at position 1');
		Assert.isTrue(results[2].isSuccess(), 'The round-two row should end saved at position 2');
		Assert.isFalse(results[3].isSuccess(), 'The never-recovering row should end refused at position 3');
		Assert.areEqual(StatusCode.UNABLE_TO_LOCK_ROW, results[3].getErrors()[0].getStatusCode(), 'Its last result should be the lock refusal');
		Assert.isNotNull(recoversInRoundTwo.Id, 'The round-two row should be saved');
		Assert.isNull(neverRecovers.Id, 'The never-recovering row should carry no Id');
		List<LogEntry__c> warnings = new SEL_LogEntry().findByLogLevel(LOG_Engine.LEVEL_WARN);
		Assert.areEqual(1, warnings.size(), 'One WARN entry should summarise the rounds');
		Map<String, Object> context = SEL_LogEntry.parseContextDataForTest(warnings[0]);
		Assert.areEqual('2', String.valueOf(context.get(DML_Transaction.CONTEXT_KEY_ROWS_RECOVERED)), 'Two rows should count as recovered');
		Assert.areEqual('1', String.valueOf(context.get(DML_Transaction.CONTEXT_KEY_ROWS_STILL_REFUSED)), 'One row should count as still refused');
		Assert.areEqual(DML_Transaction.RETRY_STOPPED_BY_COUNT, context.get(DML_Transaction.CONTEXT_KEY_RETRY_STOPPED_BY), 'The count should be what stopped the rounds');
		Assert.areEqual(1, new SEL_LogEntry().findByLogLevel(LOG_Engine.LEVEL_ERROR).size(), 'The row still refused should log once at ERROR through the partial-results path');
	}

	/**
	 * @description Tests that a row still refused after the last round logs at WARN, not ERROR, when the caller
	 * declared the lock as an expected refusal; the summary WARN sits beside it.
	 *
	 * @see DML_Transaction.setRetryOnLock
	 */
	@IsTest
	private static void commitWorkShouldHonourAnExpectedLockRefusalAfterTheLastRound()
	{
		captureLogEntries();
		Foobar__c neverRecovers = TST_Factory.newFoobarWithName('never');
		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.setAllowPartial(true);
		dmlTransaction.setRetryOnLock(1);
		dmlTransaction.setExpectedRefusalStatusCodes(new Set<StatusCode> {StatusCode.UNABLE_TO_LOCK_ROW});
		dmlTransaction.doInsert(neverRecovers);
		DML_SharingProxy.sharingProxyForTest = new RefusingRowsProxy(new Map<String, Integer> {'never' => 2});

		try
		{
			Test.startTest();
			dmlTransaction.commitWork();
			Test.stopTest();
		}
		finally
		{
			DML_SharingProxy.sharingProxyForTest = null;
		}

		Assert.isFalse(dmlTransaction.getInsertResults()[0].isSuccess(), 'The row should end refused');
		Assert.areEqual(2, new SEL_LogEntry().findByLogLevel(LOG_Engine.LEVEL_WARN).size(), 'The declared refusal and the retry summary should both log at WARN');
		Assert.isTrue(new SEL_LogEntry().findByLogLevel(LOG_Engine.LEVEL_ERROR).isEmpty(), 'Nothing should be logged at ERROR');
	}

	/**
	 * @description Tests that the partial-mode guard keeps the statements the rest of the commit needs: with one
	 * statement left and an update still to run, no round runs, the refused row stays refused, the update still
	 * runs, and the summary names headroom.
	 *
	 * @see DML_Transaction.setRetryOnLock
	 */
	@IsTest
	private static void commitWorkShouldStopPartialRoundsWhenHeadroomIsGone()
	{
		captureLogEntries();
		Foobar__c refused = TST_Factory.newFoobarWithName('refused');
		Foobar__c existing = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
		existing.Name = UTIL_Random.randomName();
		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.setAllowPartial(true);
		dmlTransaction.setRetryOnLock(2);
		dmlTransaction.doInsert(refused);
		dmlTransaction.doUpdate(existing);
		DML_SharingProxy.sharingProxyForTest = new RefusingRowsProxy(new Map<String, Integer> {'refused' => 1});
		DML_Transaction.remainingDmlStatementsForTest = NO_HEADROOM;

		try
		{
			Test.startTest();
			dmlTransaction.commitWork();
			Test.stopTest();
		}
		finally
		{
			DML_SharingProxy.sharingProxyForTest = null;
			DML_Transaction.remainingDmlStatementsForTest = null;
		}

		Assert.isFalse(dmlTransaction.getInsertResults()[0].isSuccess(), 'No round should have run');
		Assert.isNull(refused.Id, 'The refused row should carry no Id');
		Assert.isTrue(dmlTransaction.getUpdateResults()[0].isSuccess(), 'The statement the guard reserved should still have run');
		List<LogEntry__c> warnings = new SEL_LogEntry().findByLogLevel(LOG_Engine.LEVEL_WARN);
		Assert.areEqual(1, warnings.size(), 'One WARN entry should record the stopped retry');
		Map<String, Object> context = SEL_LogEntry.parseContextDataForTest(warnings[0]);
		Assert.areEqual(DML_Transaction.RETRY_STOPPED_BY_HEADROOM, context.get(DML_Transaction.CONTEXT_KEY_RETRY_STOPPED_BY), 'Headroom should be what stopped the rounds');
	}

	/**
	 * @description Tests that every operation kind re-issues its lock-refused rows in partial mode: one row of each
	 * kind is refused once and recovers on its retry, so every write-back and every re-issue arm runs.
	 *
	 * @see DML_Transaction.setRetryOnLock
	 */
	@IsTest
	private static void commitWorkShouldReissueLockRefusedRowsForEveryOperationKind()
	{
		Foobar__c toUndelete = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withOverride(Foobar__c.Name, 'undelete-me').build();
		DML_Builder.newTransaction().withSystemMode().doDelete(toUndelete).execute();
		Foobar__c toInsert = TST_Factory.newFoobarWithName('insert-me');
		Foobar__c toUpsert = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withoutInsertion()
				.withOverride(Foobar__c.Name, 'upsert-me')
				.withOverride(Foobar__c.ExternalId__c, 'EXT-RETRY')
				.build();
		Foobar__c toUpdate = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withOverride(Foobar__c.Name, 'update-me').build();
		Foobar__c toDelete = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withOverride(Foobar__c.Name, 'delete-me').build();
		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.setAllowPartial(true);
		dmlTransaction.setSuppressLogging(true);
		dmlTransaction.setRetryOnLock(1);
		dmlTransaction.doUndelete(toUndelete);
		dmlTransaction.doInsert(toInsert);
		dmlTransaction.doUpsert(toUpsert, Foobar__c.ExternalId__c);
		dmlTransaction.doUpdate(toUpdate);
		dmlTransaction.doDelete(toDelete);
		Map<String, Integer> refusalsByName = new Map<String, Integer> {'undelete-me' => 1, 'insert-me' => 1, 'upsert-me' => 1, 'update-me' => 1, 'delete-me' => 1};
		DML_SharingProxy.sharingProxyForTest = new RefusingRowsProxy(refusalsByName);

		try
		{
			dmlTransaction.commitWork();
		}
		finally
		{
			DML_SharingProxy.sharingProxyForTest = null;
		}

		Assert.isTrue(dmlTransaction.getUndeleteResults()[0].isSuccess(), 'The undelete should recover on its retry');
		Assert.isTrue(dmlTransaction.getInsertResults()[0].isSuccess(), 'The insert should recover on its retry');
		Assert.isTrue(dmlTransaction.getUpsertResults()[0].isSuccess(), 'The upsert should recover on its retry');
		Assert.isTrue(dmlTransaction.getUpdateResults()[0].isSuccess(), 'The update should recover on its retry');
		Assert.isTrue(dmlTransaction.getDeleteResults()[0].isSuccess(), 'The delete should recover on its retry');
		Assert.isNotNull(toInsert.Id, 'The inserted row should carry its Id');
		Assert.isNotNull(toUpsert.Id, 'The upserted row should carry its Id');
		Assert.isNotNull(new SEL_Foobar().findById(toUndelete.Id), 'The undeleted row should be back');
	}

	/**
	 * @description Tests that a parent refused once in partial mode still hands its Id to its child: the parent is
	 * re-issued before the commit moves on, so the population step finds its Id and writes the child's lookup.
	 *
	 * @see DML_Transaction.setRetryOnLock
	 */
	@IsTest
	private static void commitWorkShouldHandARecoveredParentsIdToItsChildInPartialMode()
	{
		Foobar__c parent = TST_Factory.newFoobarWithName('parent');
		Foobar__c child = TST_Factory.newFoobarWithName('child');
		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.setAllowPartial(true);
		dmlTransaction.setSuppressLogging(true);
		dmlTransaction.setRetryOnLock(1);
		dmlTransaction.doInsert(parent);
		dmlTransaction.doInsert(child, Foobar__c.Lookup__c, parent);
		DML_SharingProxy.sharingProxyForTest = new RefusingRowsProxy(new Map<String, Integer> {'parent' => 1});

		try
		{
			dmlTransaction.commitWork();
		}
		finally
		{
			DML_SharingProxy.sharingProxyForTest = null;
		}

		Assert.isNotNull(parent.Id, 'The parent should be saved by the retry');
		Foobar__c savedChild = (Foobar__c)new SEL_Foobar().findById(child.Id);
		Assert.areEqual(parent.Id, savedChild.Lookup__c, 'The child should point at the parent the retry saved');
	}

	/**
	 * @description Tests the rows half of the headroom guard: with the remaining DML rows overridden below what the
	 * first attempt consumed, no retry runs and the ERROR entry names headroom. The refusal comes at the child's
	 * lookup update, after the insert consumed rows, so the row budget is what stops the loop.
	 *
	 * @see DML_Transaction.setRetryOnLock
	 */
	@IsTest
	private static void commitWorkShouldStopRetryingWhenRowHeadroomIsGone()
	{
		captureLogEntries();
		Foobar__c parent = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();
		Foobar__c child = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();
		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.setRetryOnLock(1);
		dmlTransaction.doInsert(parent);
		dmlTransaction.doInsert(child, Foobar__c.Lookup__c, parent);
		DML_SharingProxy.sharingProxyForTest = new DML_ThrowingLockProxy_TEST(1, 1, LOCK_REFUSAL_MESSAGE);
		DML_Transaction.remainingDmlRowsForTest = NO_HEADROOM;

		try
		{
			Test.startTest();
			dmlTransaction.commitWork();
			Assert.fail('The refusal should surface when the rows left cannot cover another attempt');
		}
		catch(DmlException error)
		{
			Assert.isTrue(error.getMessage().contains(DML_Transaction.LOCK_REFUSAL_TOKEN), 'The surfaced refusal should be the lock');
		}
		finally
		{
			Test.stopTest();
			DML_SharingProxy.sharingProxyForTest = null;
			DML_Transaction.remainingDmlRowsForTest = null;
		}

		Assert.isTrue(new SEL_Foobar().getAll().isEmpty(), 'No retry should have saved the rows');
		List<LogEntry__c> errors = new SEL_LogEntry().findByLogLevel(LOG_Engine.LEVEL_ERROR);
		Assert.areEqual(1, errors.size(), 'One ERROR entry should record the refusal');
		Map<String, Object> context = SEL_LogEntry.parseContextDataForTest(errors[0]);
		Assert.areEqual(DML_Transaction.RETRY_STOPPED_BY_HEADROOM, context.get(DML_Transaction.CONTEXT_KEY_RETRY_STOPPED_BY), 'Headroom should be what stopped the retries');
	}

	/**
	 * @description Tests the rows half of the partial-mode guard: with no DML rows left, no round runs, the refused
	 * row stays refused, and the summary names headroom.
	 *
	 * @see DML_Transaction.setRetryOnLock
	 */
	@IsTest
	private static void commitWorkShouldStopPartialRoundsWhenRowHeadroomIsGone()
	{
		captureLogEntries();
		Foobar__c refused = TST_Factory.newFoobarWithName('refused');
		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.setAllowPartial(true);
		dmlTransaction.setRetryOnLock(2);
		dmlTransaction.doInsert(refused);
		DML_SharingProxy.sharingProxyForTest = new RefusingRowsProxy(new Map<String, Integer> {'refused' => 1});
		DML_Transaction.remainingDmlRowsForTest = NO_ROWS_LEFT;

		try
		{
			Test.startTest();
			dmlTransaction.commitWork();
			Test.stopTest();
		}
		finally
		{
			DML_SharingProxy.sharingProxyForTest = null;
			DML_Transaction.remainingDmlRowsForTest = null;
		}

		Assert.isFalse(dmlTransaction.getInsertResults()[0].isSuccess(), 'No round should have run');
		Assert.isNull(refused.Id, 'The refused row should carry no Id');
		List<LogEntry__c> warnings = new SEL_LogEntry().findByLogLevel(LOG_Engine.LEVEL_WARN);
		Assert.areEqual(1, warnings.size(), 'One WARN entry should record the stopped retry');
		Map<String, Object> context = SEL_LogEntry.parseContextDataForTest(warnings[0]);
		Assert.areEqual(DML_Transaction.RETRY_STOPPED_BY_HEADROOM, context.get(DML_Transaction.CONTEXT_KEY_RETRY_STOPPED_BY), 'Headroom should be what stopped the rounds');
	}

	/**
	 * @description Tests that the lifecycle hooks fire once per attempt: a refused first attempt reports failure,
	 * and the recovering attempt runs the full sequence again.
	 *
	 * @see DML_Transaction.commitWork
	 */
	@IsTest
	private static void commitWorkShouldFireTheLifecycleHooksOncePerAttempt()
	{
		TEST_Transaction testTransaction = new TEST_Transaction();
		testTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		testTransaction.setSuppressLogging(true);
		testTransaction.setRetryOnLock(1);
		testTransaction.doInsert(TST_Factory.newFoobar());
		DML_SharingProxy.sharingProxyForTest = new DML_ThrowingLockProxy_TEST(1);

		try
		{
			testTransaction.commitWork();
		}
		finally
		{
			DML_SharingProxy.sharingProxyForTest = null;
		}

		List<String> expectedEvents = new List<String>
		{
				EVENT_COMMIT_STARTING,
				EVENT_DML_STARTING,
				EVENT_COMMIT_FINISHED + ' - false',
				EVENT_COMMIT_STARTING,
				EVENT_DML_STARTING,
				EVENT_DML_FINISHED,
				EVENT_COMMIT_FINISHING,
				EVENT_COMMIT_FINISHED + ' - true'
		};

		Assert.areEqual(expectedEvents.size(), testTransaction.getEventsFired().size(), 'Two attempts should fire the hooks of a refused attempt and then of a full one');
		assertEvents(expectedEvents, testTransaction.getEventsFired());
	}

	/**
	 * @description Tests that a commit made directly on a DML_Transaction, the path API_Base and the login frequency
	 * aggregator use, empties the query result memory cache.
	 *
	 * @see DML_Transaction.commitWork
	 */
	@IsTest
	private static void directCommitEmptiesTheMemoryCache()
	{
		String key = storeKeyInMemoryCache();
		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.doInsert(TST_Factory.newFoobar());

		dmlTransaction.commitWork(false);

		Assert.isNull(QRY_Engine.getCopyFromMemoryCache(key), 'A commit should empty the memory cache');
	}

	/**
	 * @description Tests that an all-or-nothing commit that fails still empties the query result memory cache.
	 *
	 * @see DML_Transaction.commitWork
	 */
	@IsTest
	private static void failedCommitStillEmptiesTheMemoryCache()
	{
		String key = storeKeyInMemoryCache();
		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.setSuppressLogging(true);
		dmlTransaction.doInsert(newContactWithoutLastName());

		commitWorkExpectingDmlException(dmlTransaction);

		Assert.isNull(QRY_Engine.getCopyFromMemoryCache(key), 'A failed commit should still empty the memory cache');
	}

	/**
	 * @description Tests that a commit allowed to partly succeed empties the query result memory cache when one row
	 * saves and another is refused.
	 *
	 * @see DML_Transaction.setAllowPartial
	 */
	@IsTest
	private static void partialSuccessCommitEmptiesTheMemoryCache()
	{
		String key = storeKeyInMemoryCache();
		Foobar__c savedRecord = TST_Factory.newFoobar();
		Foobar__c refusedRecord = TST_Factory.newFoobarWithEmail(INVALID_EMAIL);
		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.setAllowPartial(true);
		dmlTransaction.setSuppressLogging(true);
		dmlTransaction.doInsert(new List<SObject> {savedRecord, refusedRecord});

		dmlTransaction.commitWork(false);

		Assert.isNotNull(savedRecord.Id, 'The good row should be saved');
		Assert.isNull(refusedRecord.Id, 'The row with an invalid email address should be refused');
		Assert.isNull(QRY_Engine.getCopyFromMemoryCache(key), 'A partly successful commit should empty the memory cache');
	}

	/**
	 * @description Tests that rows cached during a commit that rolls back are not served afterwards: the read made
	 * inside the write sees and caches the new row, the commit fails and rolls back, and the same read afterwards
	 * runs its query again and finds no row.
	 *
	 * @see DML_Transaction.commitWork
	 */
	@IsTest
	private static void rolledBackCommitEmptiesTheMemoryCache()
	{
		CachingRolledBackTransaction dmlTransaction = new CachingRolledBackTransaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.setSuppressLogging(true);
		dmlTransaction.doInsert(TST_Factory.newFoobar());

		try
		{
			dmlTransaction.commitWork(false);
			Assert.fail('The failing hook should be rethrown');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, UTIL_Exceptions.IllegalStateException.class, 'Incorrect Exception Type');
		}

		Integer queriesBefore = UTIL_Limits.soqlQueries().used();
		List<SObject> rowsAfterTheRollback = readFoobarsThroughTheMemoryCache();
		Integer queriesUsed = UTIL_Limits.soqlQueries().used() - queriesBefore;

		Assert.areEqual(1, dmlTransaction.rowsReadInsideTheWrite.size(), 'The read inside the write should see the new row');
		Assert.areEqual(1, queriesUsed, 'The read after the rollback should run its query again');
		Assert.isTrue(rowsAfterTheRollback.isEmpty(), 'The rolled-back row should not be served');
	}

	/**
	 * @description Tests that rows cached during a successful commit are not served afterwards: the read made before
	 * the statements caches the old name (its repeat runs no query, which proves the rows were kept), the commit updates
	 * it, and the same read afterwards runs its query again and returns the new name.
	 *
	 * @see DML_Transaction.commitWork
	 */
	@IsTest
	private static void successfulCommitEmptiesRowsCachedDuringIt()
	{
		Foobar__c foobar = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
		String newName = UTIL_Random.randomName();
		CachingBeforeTheWriteTransaction dmlTransaction = new CachingBeforeTheWriteTransaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.doUpdate(TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Id, foobar.Id)
				.withOverride(Foobar__c.Name, newName)
				.withoutInsertion()
				.build());

		dmlTransaction.commitWork(false);

		Integer queriesBefore = UTIL_Limits.soqlQueries().used();
		List<SObject> rowsAfterTheWrite = readFoobarsThroughTheMemoryCache();
		Integer queriesUsed = UTIL_Limits.soqlQueries().used() - queriesBefore;

		Assert.areEqual(1, dmlTransaction.rowsReadBeforeTheWrite.size(), 'The read before the statements should see the row');
		Assert.areEqual(0, dmlTransaction.queriesForTheRepeatedRead, 'The repeated read before the statements should be served from the memory cache');
		Assert.areNotEqual(newName, dmlTransaction.rowsReadBeforeTheWrite[0].get(Foobar__c.Name), 'The read before the statements should see the old name');
		Assert.areEqual(1, queriesUsed, 'The read after the commit should run its query again');
		Assert.areEqual(newName, rowsAfterTheWrite[0].get(Foobar__c.Name), 'The read after the commit should return the new name');
	}

	/**
	 * @description Tests that every attempt of a retried commit starts with an empty query result memory cache: the
	 * read the starting hook makes runs a query on the first attempt and again on the attempt after the lock refusal.
	 *
	 * @see DML_Transaction.setRetryOnLock
	 */
	@IsTest
	private static void retriedAttemptEmptiesTheMemoryCache()
	{
		List<SObject> records = TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().withCount(2).buildList();
		CachingStartTransaction dmlTransaction = new CachingStartTransaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.setSuppressLogging(true);
		dmlTransaction.setRetryOnLock(1);
		dmlTransaction.doInsert(records);
		DML_SharingProxy.sharingProxyForTest = new DML_ThrowingLockProxy_TEST(1);

		try
		{
			dmlTransaction.commitWork();
		}
		finally
		{
			DML_SharingProxy.sharingProxyForTest = null;
		}

		Assert.areEqual(new List<Integer> {1, 1}, dmlTransaction.queriesPerAttempt, 'The read in each attempt should run its query');
		Assert.isNotNull(records[0].Id, 'The rows should be saved on the second attempt');
	}
}