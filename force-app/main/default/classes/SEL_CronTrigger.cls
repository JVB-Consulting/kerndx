// SPDX-License-Identifier: Apache-2.0
/**
 * @description Selector for the CronTrigger system table: the platform's record of every scheduled job. The job runner's
 * Health Check dimensions read it to know whether the runner's own scheduled jobs are still there and who owns them,
 * and to count how many of the org's 100 Scheduled Apex slots are in use.
 *
 * @see SEL_Base
 * @see SEL_CronTrigger_TEST
 *
 * @author Jason van Beukering
 *
 * @group Schedulables
 *
 * @date September 2026, October 2026
 */
public inherited sharing class SEL_CronTrigger extends SEL_Base
{
	/**
	 * @description The CronJobDetail.JobType of a Scheduled Apex job, the only type that counts against the 100-slot cap.
	 */
	public static final String JOB_TYPE_SCHEDULED_APEX = '7';

	/**
	 * @description Every state the platform documents for CronTrigger.State, in the platform's own spelling, so that
	 * name() is the value on the wire and in SOQL. What each means for a scheduled job: WAITING is waiting to fire,
	 * ACQUIRED has been picked up by the scheduler, EXECUTING is running now, PAUSED has been paused by an
	 * administrator, BLOCKED cannot start because an earlier run of the same job is still going, PAUSED_BLOCKED is both
	 * paused and blocked, COMPLETE has finished its last occurrence, ERROR ended in a failure, and DELETED has been
	 * aborted or removed. The first six mean the job will still fire, which is what LIVE_STATES holds.
	 */
	public enum CronTriggerState
	{
		/**
		 * @description Scheduled and waiting for its next fire time.
		 */
		WAITING,
		/**
		 * @description Claimed by the scheduler and about to run.
		 */
		ACQUIRED,
		/**
		 * @description Running right now.
		 */
		EXECUTING,
		/**
		 * @description Paused by an administrator; it keeps its schedule but will not fire until it is resumed.
		 */
		PAUSED,
		/**
		 * @description Held back because an earlier run of the same job has not finished.
		 */
		BLOCKED,
		/**
		 * @description Both paused by an administrator and held back by an unfinished earlier run.
		 */
		PAUSED_BLOCKED,
		/**
		 * @description Finished: the schedule has no occurrence left to fire.
		 */
		COMPLETE,
		/**
		 * @description Ended in a failure and will not fire again.
		 */
		ERROR,
		/**
		 * @description Aborted or removed, so nothing is scheduled any more.
		 */
		DELETED
	}

	/**
	 * @description The states in which a scheduled job will still fire.
	 */
	public static final Set<CronTriggerState> LIVE_STATES = new Set<CronTriggerState>
	{
			CronTriggerState.WAITING,
			CronTriggerState.ACQUIRED,
			CronTriggerState.EXECUTING,
			CronTriggerState.PAUSED,
			CronTriggerState.BLOCKED,
			CronTriggerState.PAUSED_BLOCKED
	};

	/**
	 * @description The wire values of LIVE_STATES, built once, in the form CronTrigger.State carries.
	 */
	private static final Set<Object> LIVE_STATE_NAMES = stateNames(LIVE_STATES);

	/**
	 * @description The relationship field naming the job type.
	 */
	private static final String FIELD_JOB_TYPE = 'CronJobDetail.JobType';

	/**
	 * @description Reads the platform's record of every scheduled job (CronTrigger). Every query skips the running user's object and field permission checks (system mode).
	 * Creating the selector runs no query.
	 */
	public SEL_CronTrigger()
	{
		super(CronTrigger.SObjectType);
	}

	/**
	 * @description The fields the job runner's dimensions read.
	 *
	 * @return The CronTrigger field tokens.
	 */
	public override List<SObjectField> getFields()
	{
		return new List<SObjectField> {CronTrigger.State, CronTrigger.NextFireTime, CronTrigger.PreviousFireTime, CronTrigger.OwnerId, CronTrigger.TimesTriggered};
	}

	/**
	 * @description The parent fields read alongside: the job's name and type.
	 *
	 * @return The relationship field paths.
	 */
	public override List<String> getFieldPaths()
	{
		return new List<String> {'CronJobDetail.Name', FIELD_JOB_TYPE};
	}

	/**
	 * @description System-table selector: always runs in system mode, because most users cannot read CronTrigger and a
	 * user-mode read would make a live runner look dead.
	 *
	 * @return True, because this selector requires system mode.
	 */
	public override Boolean systemModeRequired()
	{
		return true;
	}

	/**
	 * @description Finds the scheduled jobs with the given ids, whatever their state.
	 *
	 * @param cronTriggerIds The ids; empty reads nothing.
	 *
	 * @return The matching rows.
	 */
	public List<CronTrigger> findByIds(Set<Id> cronTriggerIds)
	{
		if(cronTriggerIds == null || cronTriggerIds.isEmpty())
		{
			return new List<CronTrigger>();
		}
		return query.condition(CronTrigger.Id)
				.isIn(new List<Id>(cronTriggerIds))
				.toList();
	}

	/**
	 * @description The read behind findScheduledApex, exposed so a test can assert the query it builds: the default
	 * fields of every scheduled job whose type is Scheduled Apex. A test org holds no job of any other type, so reading
	 * the query is the only way to prove the type filter is there.
	 *
	 * @return The builder, ready to execute.
	 */
	public QRY_Builder.Builder buildScheduledApexRead()
	{
		return query.condition(FIELD_JOB_TYPE)
				.equals(JOB_TYPE_SCHEDULED_APEX);
	}

	/**
	 * @description Every Scheduled Apex job in the org, the rows that count against the 100-slot cap.
	 *
	 * @return The Scheduled Apex rows.
	 */
	public List<CronTrigger> findScheduledApex()
	{
		return buildScheduledApexRead().toList();
	}

	/**
	 * @description Whether a scheduled job will still fire. The row's state is compared by name, never resolved with
	 * CronTriggerState.valueOf, so a state the platform adds later reads as not live instead of throwing.
	 *
	 * @param cronTrigger The row.
	 *
	 * @return True in a live state.
	 */
	public static Boolean isLive(CronTrigger cronTrigger)
	{
		return cronTrigger != null && LIVE_STATE_NAMES.contains(cronTrigger.State);
	}

	/**
	 * @description The wire values of the given states, the form both SOQL and CronTrigger.State carry.
	 *
	 * @param states The states.
	 *
	 * @return Their names, ready for a query condition or a membership test.
	 */
	private static Set<Object> stateNames(Set<CronTriggerState> states)
	{
		Set<Object> names = new Set<Object>();
		for(CronTriggerState state : states)
		{
			names.add(state.name());
		}
		return names;
	}
}
