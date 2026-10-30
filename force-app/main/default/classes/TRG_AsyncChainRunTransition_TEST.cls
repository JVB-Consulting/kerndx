// SPDX-License-Identifier: Apache-2.0
/**
 * @description Tests for TRG_AsyncChainRunTransition, the trigger action that blocks a save of a chain run the engine
 * would never make. Each test calls the action directly on rows built in memory, never inserted, and reads the result
 * from the row's own errors. The tests prove that a status change the engine never makes is refused with the
 * AsyncChain_TransitionRefused message and an allowed one is let through; that each rule about the row's fields is
 * refused on its own; that a row whose status and end time did not change is left alone; and that a new row is accepted
 * in any status the engine writes when its fields fit, and refused with the AsyncChain_BirthRefused message otherwise.
 *
 * @see TRG_AsyncChainRunTransition
 * @see UTIL_AsyncChain
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.ApexUnitTestClassShouldHaveAsserts')
@IsTest(seeAllData=false isParallel=true)
private class TRG_AsyncChainRunTransition_TEST
{
	/**
	 * @description Chain name carried by every row the tests build.
	 */
	private static final String TEST_CHAIN_NAME = 'RunTransitionBackstopChain';

	/**
	 * @description The status the engine never writes. The value is the picklist's own; the selector keeps no constant
	 * for it because no code path reads or writes it.
	 */
	private static final String STATUS_DELAYED = 'Delayed';

	/**
	 * @description A message written on a row whose status and end time do not change, to prove such a save is left alone.
	 */
	private static final String CHANGED_MESSAGE = 'A message the row did not carry before';

	/**
	 * @description How many minutes after the first end time the second, refused end time sits.
	 */
	private static final Integer LATER_END_TIME_OFFSET_MINUTES = 5;

	/**
	 * @description A duration written on a Stalled row, which a Stalled run may not have.
	 */
	private static final Integer A_DURATION_MILLISECONDS = 1234;

	/**
	 * @description An active deduplication key left on a finished row, which a finished run may not hold.
	 */
	private static final String ACTIVE_DEDUPLICATION_KEY = 'run-transition-backstop-key';

	/**
	 * @description A Completed row asked to read Running again. The engine never makes that move, so the action refuses
	 * the save with the message that names both statuses.
	 */
	@IsTest
	private static void shouldRefuseAStatusMoveTheTableDoesNotAllow()
	{
		Datetime endTime = Datetime.now();
		AsyncChainExecution__c oldRecord = buildRow(SEL_AsyncChainExecution.STATUS_COMPLETED, endTime, null);
		AsyncChainExecution__c newRecord = buildRow(SEL_AsyncChainExecution.STATUS_RUNNING, null, null);

		new TRG_AsyncChainRunTransition().beforeUpdate(new List<SObject> {newRecord}, new List<SObject> {oldRecord});

		assertRefused(newRecord, SEL_AsyncChainExecution.STATUS_COMPLETED, SEL_AsyncChainExecution.STATUS_RUNNING);
	}

	/**
	 * @description A Running row that finishes well, with its end time set. The engine makes that move and the fields fit
	 * a Completed row, so the action adds no error.
	 */
	@IsTest
	private static void shouldAcceptAStatusMoveTheTableAllows()
	{
		AsyncChainExecution__c oldRecord = buildRow(SEL_AsyncChainExecution.STATUS_RUNNING, null, null);
		AsyncChainExecution__c newRecord = buildRow(SEL_AsyncChainExecution.STATUS_COMPLETED, Datetime.now(), null);

		new TRG_AsyncChainRunTransition().beforeUpdate(new List<SObject> {newRecord}, new List<SObject> {oldRecord});

		Assert.isFalse(newRecord.hasErrors(), 'Expected the move from Running to Completed with an end time to be accepted');
	}

	/**
	 * @description A Stalled run may not have an end time or a duration. A Running row written Stalled with both is
	 * refused, even though Running to Stalled is a move the engine makes.
	 */
	@IsTest
	private static void shouldRefuseAStalledRowWithAnEndTime()
	{
		AsyncChainExecution__c oldRecord = buildRow(SEL_AsyncChainExecution.STATUS_RUNNING, null, null);
		AsyncChainExecution__c newRecord = buildRow(SEL_AsyncChainExecution.STATUS_STALLED, Datetime.now(), SEL_AsyncChainExecution.FAILURE_CATEGORY_STALLED);
		newRecord.DurationMs__c = A_DURATION_MILLISECONDS;

		new TRG_AsyncChainRunTransition().beforeUpdate(new List<SObject> {newRecord}, new List<SObject> {oldRecord});

		assertRefused(newRecord, SEL_AsyncChainExecution.STATUS_RUNNING, SEL_AsyncChainExecution.STATUS_STALLED);
	}

	/**
	 * @description A Stalled run may not have a duration, even with no end time. A Running row written Stalled with a
	 * duration and no end time is refused, so the duration part of the rule is checked on its own.
	 */
	@IsTest
	private static void shouldRefuseAStalledRowWithADurationButNoEndTime()
	{
		AsyncChainExecution__c oldRecord = buildRow(SEL_AsyncChainExecution.STATUS_RUNNING, null, null);
		AsyncChainExecution__c newRecord = buildRow(SEL_AsyncChainExecution.STATUS_STALLED, null, SEL_AsyncChainExecution.FAILURE_CATEGORY_STALLED);
		newRecord.DurationMs__c = A_DURATION_MILLISECONDS;

		new TRG_AsyncChainRunTransition().beforeUpdate(new List<SObject> {newRecord}, new List<SObject> {oldRecord});

		assertRefused(newRecord, SEL_AsyncChainExecution.STATUS_RUNNING, SEL_AsyncChainExecution.STATUS_STALLED);
	}

	/**
	 * @description A finished run may not hold an active deduplication key. A Running row written Completed with an end
	 * time that still holds its key is refused, so the key part of the rule is checked on its own.
	 */
	@IsTest
	private static void shouldRefuseAFinishedRowThatStillHoldsAnActiveDeduplicationKey()
	{
		AsyncChainExecution__c oldRecord = buildRow(SEL_AsyncChainExecution.STATUS_RUNNING, null, null);
		AsyncChainExecution__c newRecord = buildRow(SEL_AsyncChainExecution.STATUS_COMPLETED, Datetime.now(), null);
		newRecord.ActiveDeduplicationKey__c = ACTIVE_DEDUPLICATION_KEY;

		new TRG_AsyncChainRunTransition().beforeUpdate(new List<SObject> {newRecord}, new List<SObject> {oldRecord});

		assertRefused(newRecord, SEL_AsyncChainExecution.STATUS_RUNNING, SEL_AsyncChainExecution.STATUS_COMPLETED);
	}

	/**
	 * @description A finished run must have an end time. A Running row written Completed without one is refused, even
	 * though the move itself is one the engine makes.
	 */
	@IsTest
	private static void shouldRefuseATerminalRowWithoutAnEndTime()
	{
		AsyncChainExecution__c oldRecord = buildRow(SEL_AsyncChainExecution.STATUS_RUNNING, null, null);
		AsyncChainExecution__c newRecord = buildRow(SEL_AsyncChainExecution.STATUS_COMPLETED, null, null);

		new TRG_AsyncChainRunTransition().beforeUpdate(new List<SObject> {newRecord}, new List<SObject> {oldRecord});

		assertRefused(newRecord, SEL_AsyncChainExecution.STATUS_RUNNING, SEL_AsyncChainExecution.STATUS_COMPLETED);
	}

	/**
	 * @description The end time rule holds for an Aborted row too. An operator abort that carries its category but no end
	 * time is refused, even though Running to Aborted is a move the engine makes.
	 */
	@IsTest
	private static void shouldRefuseAnAbortedRowWithoutAnEndTime()
	{
		AsyncChainExecution__c oldRecord = buildRow(SEL_AsyncChainExecution.STATUS_RUNNING, null, null);
		AsyncChainExecution__c newRecord = buildRow(SEL_AsyncChainExecution.STATUS_ABORTED, null, SEL_AsyncChainExecution.FAILURE_CATEGORY_OPERATOR_ABORT);

		new TRG_AsyncChainRunTransition().beforeUpdate(new List<SObject> {newRecord}, new List<SObject> {oldRecord});

		assertRefused(newRecord, SEL_AsyncChainExecution.STATUS_RUNNING, SEL_AsyncChainExecution.STATUS_ABORTED);
	}

	/**
	 * @description An end time never changes once it is set. A Failed row that keeps its status and category but moves
	 * its end time later is refused, so no later save can change when a run finished.
	 */
	@IsTest
	private static void shouldRefuseAChangedEndTime()
	{
		Datetime endTime = Datetime.now();
		AsyncChainExecution__c oldRecord = buildRow(SEL_AsyncChainExecution.STATUS_FAILED, endTime, SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION);
		Datetime laterEndTime = endTime.addMinutes(LATER_END_TIME_OFFSET_MINUTES);
		AsyncChainExecution__c newRecord = buildRow(SEL_AsyncChainExecution.STATUS_FAILED, laterEndTime, SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION);

		new TRG_AsyncChainRunTransition().beforeUpdate(new List<SObject> {newRecord}, new List<SObject> {oldRecord});

		assertRefused(newRecord, SEL_AsyncChainExecution.STATUS_FAILED, SEL_AsyncChainExecution.STATUS_FAILED);
	}

	/**
	 * @description A Running run may not have a failure category. A Stalled row driven again to Running that keeps its
	 * stall category is refused, even though Stalled to Running is a move the engine makes.
	 */
	@IsTest
	private static void shouldRefuseARunningRowWithACategory()
	{
		AsyncChainExecution__c oldRecord = buildRow(SEL_AsyncChainExecution.STATUS_STALLED, null, SEL_AsyncChainExecution.FAILURE_CATEGORY_STALLED);
		AsyncChainExecution__c newRecord = buildRow(SEL_AsyncChainExecution.STATUS_RUNNING, null, SEL_AsyncChainExecution.FAILURE_CATEGORY_STALLED);

		new TRG_AsyncChainRunTransition().beforeUpdate(new List<SObject> {newRecord}, new List<SObject> {oldRecord});

		assertRefused(newRecord, SEL_AsyncChainExecution.STATUS_STALLED, SEL_AsyncChainExecution.STATUS_RUNNING);
	}

	/**
	 * @description A Failed run must have a failure category. A Running row written Failed with an end time but no
	 * category is refused, even though the move itself is one the engine makes.
	 */
	@IsTest
	private static void shouldRefuseAFailedRowWithoutACategory()
	{
		AsyncChainExecution__c oldRecord = buildRow(SEL_AsyncChainExecution.STATUS_RUNNING, null, null);
		AsyncChainExecution__c newRecord = buildRow(SEL_AsyncChainExecution.STATUS_FAILED, Datetime.now(), null);

		new TRG_AsyncChainRunTransition().beforeUpdate(new List<SObject> {newRecord}, new List<SObject> {oldRecord});

		assertRefused(newRecord, SEL_AsyncChainExecution.STATUS_RUNNING, SEL_AsyncChainExecution.STATUS_FAILED);
	}

	/**
	 * @description A row that already breaks a rule (Stalled with an end time, a shape an older release could write)
	 * has only its message changed. Neither the status nor the end time moved, so the action leaves the save alone and
	 * the row stays editable for its other fields.
	 */
	@IsTest
	private static void shouldLeaveARowAloneWhenNeitherFieldChanged()
	{
		Datetime endTime = Datetime.now();
		AsyncChainExecution__c oldRecord = buildRow(SEL_AsyncChainExecution.STATUS_STALLED, endTime, SEL_AsyncChainExecution.FAILURE_CATEGORY_STALLED);
		AsyncChainExecution__c newRecord = buildRow(SEL_AsyncChainExecution.STATUS_STALLED, endTime, SEL_AsyncChainExecution.FAILURE_CATEGORY_STALLED);
		newRecord.ErrorMessage__c = CHANGED_MESSAGE;

		new TRG_AsyncChainRunTransition().beforeUpdate(new List<SObject> {newRecord}, new List<SObject> {oldRecord});

		Assert.isFalse(newRecord.hasErrors(), 'Expected a save that moves neither the status nor the end time to be left alone');
	}

	/**
	 * @description A Failed row saved with Failed in its new values and a changed message, as the engine writes a note
	 * about a handler. The same status is not a change, so the action adds no error.
	 */
	@IsTest
	private static void shouldTreatAnEqualStatusAsUnchanged()
	{
		Datetime endTime = Datetime.now();
		AsyncChainExecution__c oldRecord = buildRow(SEL_AsyncChainExecution.STATUS_FAILED, endTime, SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION);
		AsyncChainExecution__c newRecord = buildRow(SEL_AsyncChainExecution.STATUS_FAILED, endTime, SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION);
		newRecord.ErrorMessage__c = CHANGED_MESSAGE;

		new TRG_AsyncChainRunTransition().beforeUpdate(new List<SObject> {newRecord}, new List<SObject> {oldRecord});

		Assert.isFalse(newRecord.hasErrors(), 'Expected the same status in the new values to be read as unchanged');
	}

	/**
	 * @description A new Running row with no end time and no category fits its status, so it is accepted.
	 */
	@IsTest
	private static void shouldAcceptARunningBirth()
	{
		AsyncChainExecution__c newRecord = buildRow(SEL_AsyncChainExecution.STATUS_RUNNING, null, null);

		new TRG_AsyncChainRunTransition().beforeInsert(new List<SObject> {newRecord});

		Assert.isFalse(newRecord.hasErrors(), 'Expected a new Running row with no end time and no category to be accepted');
	}

	/**
	 * @description A new Completed row with an end time fits its status, so it is accepted. A run with no steps is
	 * created already finished.
	 */
	@IsTest
	private static void shouldAcceptACompletedBirthWithAnEndTime()
	{
		AsyncChainExecution__c newRecord = buildRow(SEL_AsyncChainExecution.STATUS_COMPLETED, Datetime.now(), null);

		new TRG_AsyncChainRunTransition().beforeInsert(new List<SObject> {newRecord});

		Assert.isFalse(newRecord.hasErrors(), 'Expected a new Completed row with an end time to be accepted');
	}

	/**
	 * @description Delayed is a status the engine never writes. A new row in that status is refused with the message
	 * that names the status.
	 */
	@IsTest
	private static void shouldRefuseADelayedBirth()
	{
		AsyncChainExecution__c newRecord = buildRow(STATUS_DELAYED, null, null);

		new TRG_AsyncChainRunTransition().beforeInsert(new List<SObject> {newRecord});

		assertBirthRefused(newRecord, STATUS_DELAYED);
	}

	/**
	 * @description A new Failed row with an end time and a category fits its status, so it is accepted.
	 */
	@IsTest
	private static void shouldAcceptAFailedBirthWithAnEndTimeAndACategory()
	{
		AsyncChainExecution__c newRecord = buildRow(SEL_AsyncChainExecution.STATUS_FAILED, Datetime.now(), SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION);

		new TRG_AsyncChainRunTransition().beforeInsert(new List<SObject> {newRecord});

		Assert.isFalse(newRecord.hasErrors(), 'Expected a new Failed row with an end time and a category to be accepted');
	}

	/**
	 * @description A new Failed row without a category does not fit its status, so it is refused.
	 */
	@IsTest
	private static void shouldRefuseAFailedBirthWithoutACategory()
	{
		AsyncChainExecution__c newRecord = buildRow(SEL_AsyncChainExecution.STATUS_FAILED, Datetime.now(), null);

		new TRG_AsyncChainRunTransition().beforeInsert(new List<SObject> {newRecord});

		assertBirthRefused(newRecord, SEL_AsyncChainExecution.STATUS_FAILED);
	}

	/**
	 * @description A new Stalled row with an end time does not fit its status, so it is refused. The shape an older
	 * release could write cannot be created.
	 */
	@IsTest
	private static void shouldRefuseAStalledBirthWithAnEndTime()
	{
		AsyncChainExecution__c newRecord = buildRow(SEL_AsyncChainExecution.STATUS_STALLED, Datetime.now(), SEL_AsyncChainExecution.FAILURE_CATEGORY_STALLED);

		new TRG_AsyncChainRunTransition().beforeInsert(new List<SObject> {newRecord});

		assertBirthRefused(newRecord, SEL_AsyncChainExecution.STATUS_STALLED);
	}

	/**
	 * @description Builds one chain run row in memory with the three fields the rules read most, and nothing else set
	 * beyond the chain name.
	 *
	 * @param status The run status.
	 * @param completedAt The end time, or null.
	 * @param failureCategory The failure category, or null.
	 *
	 * @return The row, not inserted.
	 */
	private static AsyncChainExecution__c buildRow(String status, Datetime completedAt, String failureCategory)
	{
		return (AsyncChainExecution__c)TST_Builder.of(AsyncChainExecution__c.SObjectType)
				.withOverride(AsyncChainExecution__c.ChainName__c, TEST_CHAIN_NAME)
				.withOverride(AsyncChainExecution__c.Status__c, status)
				.withOverride(AsyncChainExecution__c.CompletedAt__c, completedAt)
				.withOverride(AsyncChainExecution__c.FailureCategory__c, failureCategory)
				.withoutInsertion()
				.build();
	}

	/**
	 * @description Asserts the action refused an update with exactly one error carrying the AsyncChain_TransitionRefused
	 * message for the two statuses.
	 *
	 * @param record The row the action was given.
	 * @param fromStatus The status the message names as the current one.
	 * @param toStatus The status the message names as the one asked for.
	 */
	private static void assertRefused(AsyncChainExecution__c record, String fromStatus, String toStatus)
	{
		String expectedMessage = String.format(System.Label.AsyncChain_TransitionRefused, new List<String> {fromStatus, toStatus});
		assertOneError(record, expectedMessage, 'the update from ' + fromStatus + ' to ' + toStatus);
	}

	/**
	 * @description Asserts the action refused a new row with exactly one error carrying the AsyncChain_BirthRefused
	 * message for the status the row was given.
	 *
	 * @param record The row the action was given.
	 * @param status The status the message names.
	 */
	private static void assertBirthRefused(AsyncChainExecution__c record, String status)
	{
		String expectedMessage = String.format(System.Label.AsyncChain_BirthRefused, new List<String> {status});
		assertOneError(record, expectedMessage, 'the new row in ' + status);
	}

	/**
	 * @description Asserts the row carries exactly one error and that its message is the one expected.
	 *
	 * @param record The row the action was given.
	 * @param expectedMessage The message the one error must carry.
	 * @param saveDescription Words for the save under test, used in the assertion messages.
	 */
	private static void assertOneError(AsyncChainExecution__c record, String expectedMessage, String saveDescription)
	{
		Assert.isTrue(record.hasErrors(), 'Expected the action to refuse ' + saveDescription);
		List<Database.Error> recordErrors = record.getErrors();
		Assert.areEqual(1, recordErrors.size(), 'Expected exactly one error on the refused row');
		Assert.areEqual(expectedMessage, recordErrors.iterator().next().getMessage(), 'Expected the refusal of ' + saveDescription + ' to carry the label text');
	}
}
