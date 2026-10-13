// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Checks that a step's state has one answer. A step entry can carry five runtime markers: success,
 * continueOnError, recoveryRefused, started and attempt. Every combination of them goes through
 * UTIL_AsyncChain.resolveStepState and must give exactly the state that a table written out by hand in this class says.
 * The table also holds combinations the engine never writes. They are there to fix the order in which the rules apply,
 * not to say that such an entry is valid.
 *
 * @see UTIL_AsyncChain
 *
 * @author Jason van Beukering
 *
 * @group Async
 *
 * @date October 2026
 */
@IsTest(seeAllData=false isParallel=true)
private class UTIL_AsyncChainStepState_TEST
{
	/**
	 * @description The number of marker combinations: success in {null, true, false}, continueOnError in {null, true},
	 * recoveryRefused in {null, true}, started in {null, true}, attempt in {null, 2}.
	 */
	private static final Integer EXPECTED_ROW_COUNT = 48;

	/**
	 * @description The attempt value that stands for a retried step; the other value is null, the first attempt.
	 */
	private static final Integer SECOND_ATTEMPT = 2;

	/**
	 * @description The state name for an entry no executor was ever committed for.
	 */
	private static final String STATE_NOT_STARTED = 'NOT_STARTED';

	/**
	 * @description The state name for an entry an executor was committed for that has no result yet.
	 */
	private static final String STATE_STARTED = 'STARTED';

	/**
	 * @description The state name for an entry that recorded a success.
	 */
	private static final String STATE_SUCCEEDED = 'SUCCEEDED';

	/**
	 * @description The state name for an entry that failed while the chain went on.
	 */
	private static final String STATE_FAILED_CONTINUED = 'FAILED_CONTINUED';

	/**
	 * @description The state name for an entry that failed and stopped the chain.
	 */
	private static final String STATE_FAILED_STOPPED = 'FAILED_STOPPED';

	/**
	 * @description The state name for an entry the watchdog refused to run again.
	 */
	private static final String STATE_RECOVERY_REFUSED = 'RECOVERY_REFUSED';

	/**
	 * @description How many table rows rule 1 (success == true) decides.
	 */
	private static final Integer EXPECTED_SUCCEEDED_ROWS = 16;

	/**
	 * @description How many table rows rule 2 (success == false with recoveryRefused == true) decides.
	 */
	private static final Integer EXPECTED_RECOVERY_REFUSED_ROWS = 8;

	/**
	 * @description How many table rows rule 3 (success == false with continueOnError == true, not refused) decides.
	 */
	private static final Integer EXPECTED_FAILED_CONTINUED_ROWS = 4;

	/**
	 * @description How many table rows rule 4 (the other success == false rows) decides.
	 */
	private static final Integer EXPECTED_FAILED_STOPPED_ROWS = 4;

	/**
	 * @description How many table rows rule 5 (success == null with started == true) decides.
	 */
	private static final Integer EXPECTED_STARTED_ROWS = 8;

	/**
	 * @description How many table rows rule 6 (everything else) decides.
	 */
	private static final Integer EXPECTED_NOT_STARTED_ROWS = 8;

	/**
	 * @description Every one of the 48 marker combinations resolves to the state the literal table names, through the real
	 * resolver on a step entry built per row. Rule order matters: a refused step added with continueOnError reads
	 * RECOVERY_REFUSED, not FAILED_CONTINUED, and a success with any other marker reads SUCCEEDED.
	 */
	@IsTest
	private static void shouldResolveEveryMarkerCombinationAsTheLiteralTableSays()
	{
		for(ExpectedState row : buildTable())
		{
			UTIL_AsyncChain.DTO_StepDefinition entry = new UTIL_AsyncChain.DTO_StepDefinition();
			entry.success = row.success;
			entry.continueOnError = row.continueOnError;
			entry.recoveryRefused = row.recoveryRefused;
			entry.started = row.started;
			entry.attempt = row.attempt;

			String resolved = UTIL_AsyncChain.resolveStepState(entry).name();

			Assert.areEqual(row.stateName, resolved, 'Expected the marker combination ' + describeRow(row) + ' to resolve ' + row.stateName);
		}
	}

	/**
	 * @description The literal table covers every marker combination exactly once: 48 rows, split across the six rules as
	 * the arithmetic of the marker domains says, so a row dropped or duplicated by hand cannot pass unnoticed.
	 */
	@IsTest
	private static void shouldCountFortyEightRows()
	{
		List<ExpectedState> table = buildTable();

		Map<String, Integer> rowsByState = new Map<String, Integer>();
		Set<String> seenCombinations = new Set<String>();
		for(ExpectedState row : table)
		{
			rowsByState.put(row.stateName, (rowsByState.get(row.stateName) ?? 0) + 1);
			seenCombinations.add(describeRow(row));
		}

		Assert.areEqual(EXPECTED_ROW_COUNT, table.size(), 'Expected the literal table to hold every marker combination');
		Assert.areEqual(EXPECTED_ROW_COUNT, seenCombinations.size(), 'Expected every row of the literal table to be a distinct marker combination');
		Assert.areEqual(EXPECTED_SUCCEEDED_ROWS, rowsByState.get(STATE_SUCCEEDED), 'Expected rule 1 to decide sixteen rows');
		Assert.areEqual(EXPECTED_RECOVERY_REFUSED_ROWS, rowsByState.get(STATE_RECOVERY_REFUSED), 'Expected rule 2 to decide eight rows');
		Assert.areEqual(EXPECTED_FAILED_CONTINUED_ROWS, rowsByState.get(STATE_FAILED_CONTINUED), 'Expected rule 3 to decide four rows');
		Assert.areEqual(EXPECTED_FAILED_STOPPED_ROWS, rowsByState.get(STATE_FAILED_STOPPED), 'Expected rule 4 to decide four rows');
		Assert.areEqual(EXPECTED_STARTED_ROWS, rowsByState.get(STATE_STARTED), 'Expected rule 5 to decide eight rows');
		Assert.areEqual(EXPECTED_NOT_STARTED_ROWS, rowsByState.get(STATE_NOT_STARTED), 'Expected rule 6 to decide eight rows');
	}

	/**
	 * @description The literal table: every marker combination with its expected state, written out by hand from the six
	 * rules. Order: success, then continueOnError, then recoveryRefused, then started, then attempt.
	 *
	 * @return The 48 rows.
	 */
	private static List<ExpectedState> buildTable()
	{
		return new List<ExpectedState>
		{
				new ExpectedState(null, null, null, null, null, STATE_NOT_STARTED),
				new ExpectedState(null, null, null, null, SECOND_ATTEMPT, STATE_NOT_STARTED),
				new ExpectedState(null, null, null, true, null, STATE_STARTED),
				new ExpectedState(null, null, null, true, SECOND_ATTEMPT, STATE_STARTED),
				new ExpectedState(null, null, true, null, null, STATE_NOT_STARTED),
				new ExpectedState(null, null, true, null, SECOND_ATTEMPT, STATE_NOT_STARTED),
				new ExpectedState(null, null, true, true, null, STATE_STARTED),
				new ExpectedState(null, null, true, true, SECOND_ATTEMPT, STATE_STARTED),
				new ExpectedState(null, true, null, null, null, STATE_NOT_STARTED),
				new ExpectedState(null, true, null, null, SECOND_ATTEMPT, STATE_NOT_STARTED),
				new ExpectedState(null, true, null, true, null, STATE_STARTED),
				new ExpectedState(null, true, null, true, SECOND_ATTEMPT, STATE_STARTED),
				new ExpectedState(null, true, true, null, null, STATE_NOT_STARTED),
				new ExpectedState(null, true, true, null, SECOND_ATTEMPT, STATE_NOT_STARTED),
				new ExpectedState(null, true, true, true, null, STATE_STARTED),
				new ExpectedState(null, true, true, true, SECOND_ATTEMPT, STATE_STARTED),
				new ExpectedState(true, null, null, null, null, STATE_SUCCEEDED),
				new ExpectedState(true, null, null, null, SECOND_ATTEMPT, STATE_SUCCEEDED),
				new ExpectedState(true, null, null, true, null, STATE_SUCCEEDED),
				new ExpectedState(true, null, null, true, SECOND_ATTEMPT, STATE_SUCCEEDED),
				new ExpectedState(true, null, true, null, null, STATE_SUCCEEDED),
				new ExpectedState(true, null, true, null, SECOND_ATTEMPT, STATE_SUCCEEDED),
				new ExpectedState(true, null, true, true, null, STATE_SUCCEEDED),
				new ExpectedState(true, null, true, true, SECOND_ATTEMPT, STATE_SUCCEEDED),
				new ExpectedState(true, true, null, null, null, STATE_SUCCEEDED),
				new ExpectedState(true, true, null, null, SECOND_ATTEMPT, STATE_SUCCEEDED),
				new ExpectedState(true, true, null, true, null, STATE_SUCCEEDED),
				new ExpectedState(true, true, null, true, SECOND_ATTEMPT, STATE_SUCCEEDED),
				new ExpectedState(true, true, true, null, null, STATE_SUCCEEDED),
				new ExpectedState(true, true, true, null, SECOND_ATTEMPT, STATE_SUCCEEDED),
				new ExpectedState(true, true, true, true, null, STATE_SUCCEEDED),
				new ExpectedState(true, true, true, true, SECOND_ATTEMPT, STATE_SUCCEEDED),
				new ExpectedState(false, null, null, null, null, STATE_FAILED_STOPPED),
				new ExpectedState(false, null, null, null, SECOND_ATTEMPT, STATE_FAILED_STOPPED),
				new ExpectedState(false, null, null, true, null, STATE_FAILED_STOPPED),
				new ExpectedState(false, null, null, true, SECOND_ATTEMPT, STATE_FAILED_STOPPED),
				new ExpectedState(false, null, true, null, null, STATE_RECOVERY_REFUSED),
				new ExpectedState(false, null, true, null, SECOND_ATTEMPT, STATE_RECOVERY_REFUSED),
				new ExpectedState(false, null, true, true, null, STATE_RECOVERY_REFUSED),
				new ExpectedState(false, null, true, true, SECOND_ATTEMPT, STATE_RECOVERY_REFUSED),
				new ExpectedState(false, true, null, null, null, STATE_FAILED_CONTINUED),
				new ExpectedState(false, true, null, null, SECOND_ATTEMPT, STATE_FAILED_CONTINUED),
				new ExpectedState(false, true, null, true, null, STATE_FAILED_CONTINUED),
				new ExpectedState(false, true, null, true, SECOND_ATTEMPT, STATE_FAILED_CONTINUED),
				new ExpectedState(false, true, true, null, null, STATE_RECOVERY_REFUSED),
				new ExpectedState(false, true, true, null, SECOND_ATTEMPT, STATE_RECOVERY_REFUSED),
				new ExpectedState(false, true, true, true, null, STATE_RECOVERY_REFUSED),
				new ExpectedState(false, true, true, true, SECOND_ATTEMPT, STATE_RECOVERY_REFUSED)
		};
	}

	/**
	 * @description Names a row's markers for an assertion message and for the distinctness check.
	 *
	 * @param row The table row.
	 *
	 * @return The five marker values in table order.
	 */
	private static String describeRow(ExpectedState row)
	{
		return 'success=' + row.success + ', continueOnError=' + row.continueOnError + ', recoveryRefused=' + row.recoveryRefused
				+ ', started=' + row.started + ', attempt=' + row.attempt;
	}

	/**
	 * @description One row of the literal table: the five markers and the state they must resolve to.
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private inherited sharing class ExpectedState
	{
		/**
		 * @description The success marker of the row.
		 */
		private final Boolean success;

		/**
		 * @description The continueOnError marker of the row.
		 */
		private final Boolean continueOnError;

		/**
		 * @description The recoveryRefused marker of the row.
		 */
		private final Boolean recoveryRefused;

		/**
		 * @description The started marker of the row.
		 */
		private final Boolean started;

		/**
		 * @description The attempt marker of the row.
		 */
		private final Integer attempt;

		/**
		 * @description The name of the state the row must resolve to.
		 */
		private final String stateName;

		/**
		 * @description Builds one row.
		 *
		 * @param success The success marker.
		 * @param continueOnError The continueOnError marker.
		 * @param recoveryRefused The recoveryRefused marker.
		 * @param started The started marker.
		 * @param attempt The attempt marker.
		 * @param stateName The expected state name.
		 */
		private ExpectedState(Boolean success, Boolean continueOnError, Boolean recoveryRefused, Boolean started, Integer attempt, String stateName)
		{
			this.success = success;
			this.continueOnError = continueOnError;
			this.recoveryRefused = recoveryRefused;
			this.started = started;
			this.attempt = attempt;
			this.stateName = stateName;
		}
	}
}
