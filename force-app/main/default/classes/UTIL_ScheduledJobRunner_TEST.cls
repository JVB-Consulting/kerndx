// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for UTIL_ScheduledJobRunner: the job runner's constants and the helpers that read how a
 * scheduled job record opts in and who may change that.
 *
 * @see UTIL_ScheduledJobRunner
 *
 * @author Jason van Beukering
 *
 * @group Schedulables
 *
 * @date September 2026, October 2026
 */
@IsTest(seeAllData=false isParallel=false)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CyclomaticComplexity,PMD.NcssTypeCount,PMD.NcssCount')
private class UTIL_ScheduledJobRunner_TEST
{
	/**
	 * @description Company name identifying the administrator who holds the Kern Job Runner Management permission set.
	 */
	private static final String MANAGING_ADMIN_COMPANY = 'UTIL_ScheduledJobRunner_TEST-managing';

	/**
	 * @description Company name that identifies the test user who holds no job runner permission. A package install writes
	 * the Manage Job Runner permission into the System Administrator profile. So this user is on the Standard User profile,
	 * which the default install leaves without that permission.
	 */
	private static final String NO_JOB_RUNNER_PERMISSION_COMPANY = 'UTIL_ScheduledJobRunner_TEST-plain';

	/**
	 * @description Company name identifying the manager: a Standard User holding the Kern Job Runner Management set alone,
	 * with no Modify All, so record sharing applies to every row they do not own.
	 */
	private static final String LOW_PRIVILEGE_MANAGER_COMPANY = 'UTIL_ScheduledJobRunner_TEST-standard-manager';

	/**
	 * @description The runner schedulable's name without a namespace, the spelling a record carries in an unmanaged
	 * deployment and the bare half of the two spellings the runner accepts. It is taken from the class itself, with the
	 * package namespace removed when there is one, so it is never written out as a literal.
	 */
	private static final String RUNNER_CLASS_BARE_NAME = SCHED_JobRunner.class.getName().removeStart(UTIL_System.getManagedPackageNamespacePrefix(UTIL_String.DOT));

	/**
	 * @description A namespace that is not this package's, for proving that a class of the runner's name belonging to
	 * someone else is not the runner.
	 */
	private static final String FOREIGN_NAMESPACE = 'someoneelse';

	/**
	 * @description The cron expression every fixture row carries: it fires at every fifth minute of every hour.
	 */
	private static final String EVERY_FIVE_MINUTES = '0 */5 * * * ?';

	/**
	 * @description A second cron expression, firing at every tenth minute, used to prove that editing the expression of a
	 * parked row gives it a new cursor.
	 */
	private static final String EVERY_TEN_MINUTES = '0 */10 * * * ?';

	/**
	 * @description A cron expression whose only year has already passed, so it can never fire again.
	 */
	private static final String NEVER_FIRES_AGAIN = '0 0 12 * * ? 2020';

	/**
	 * @description A once-a-day cron expression, the kind a record carries when it is moved to its own scheduled job and
	 * the platform has to place it.
	 */
	private static final String DAILY_AT_THREE = '0 0 3 * * ?';

	/**
	 * @description Text that is not a cron expression at all, so reading it fails rather than yielding no run time.
	 */
	private static final String UNREADABLE_EXPRESSION = 'every other Tuesday';

	/**
	 * @description The time zone every fixture row is scheduled in, so a test can predict its next run time exactly.
	 */
	private static final String UTC_TIMEZONE = 'UTC';

	/**
	 * @description The log method the runner writes its entries under. The class half comes from the class itself, so it
	 * carries the package namespace exactly as the runner writes it.
	 */
	private static final String CHECK_METHOD = UTIL_ScheduledJobRunner.class.getName() + '.checkForDueJobs';

	/**
	 * @description The log method a run writes its entries under. The class half comes from the class itself, so it
	 * carries the package namespace exactly as the runner writes it.
	 */
	private static final String RUN_METHOD = UTIL_ScheduledJobRunner.class.getName() + '.Execution.execute';

	/**
	 * @description A card number the failing fixture job carries in its message, so the log entry can be proven to have
	 * had it taken out before it was stored.
	 */
	private static final String CARD_NUMBER = '4111 1111 1111 1111';

	/**
	 * @description The part of the failing fixture job's message that is not sensitive, so the same assertion can prove
	 * the rest of the message survived masking.
	 */
	private static final String DELIBERATE_FAILURE_PHRASE = 'failed on purpose';

	/**
	 * @description The scheduler name of the failing fixture job, so an assertion can prove the log entry's short
	 * message still names the job it was about after masking has been over it.
	 */
	private static final String CARD_LEAKING_JOB_NAME = 'leaks a card';

	/**
	 * @description The run priority a manager sets on a job they own, to prove the set lets them edit it.
	 */
	private static final Decimal EDITED_RUN_PRIORITY = 7;

	/**
	 * @description The display name of the chain the chain-building fixture job launches.
	 */
	private static final String CHAIN_NAME = 'Job runner chain';

	/**
	 * @description The fixed clock every check in these tests runs at.
	 */
	private static final Datetime CHECK_TIME = Datetime.newInstanceGmt(2026, 6, 1, 9, 0, 0);

	/**
	 * @description The width of one window of the ten-minute expression, in minutes: a row re-seeded from that expression
	 * gets a cursor no further ahead than this.
	 */
	private static final Integer TEN_MINUTE_WINDOW = 10;

	/**
	 * @description How many times the fixture job ran, kept on the outer class because an Apex inner class cannot declare statics.
	 */
	private static Integer recordedRunCount = 0;

	/**
	 * @description The trigger id the fixture job was handed on its last run.
	 */
	private static Id recordedTriggerId;

	/**
	 * @description The user the fixture job last ran as.
	 */
	private static Id recordedRunningUserId;

	/**
	 * @description The chain the chain-building fixture job launched on its last run.
	 */
	private static String recordedChainExecutionId;

	/**
	 * @description Three users: an administrator holding the Kern Job Runner Management permission set, a user who holds no
	 * job runner permission, and a low-privilege manager. They are created in setup so that System.runAs starts a fresh
	 * permission check for each test. The managing administrator and the low-privilege manager hold only the Kern Job
	 * Runner Management set, so the tests prove what that set allows. The low-privilege manager is on the Standard User
	 * profile with no Modify All Records, so record sharing applies to every row they do not own. The user without the
	 * permission is also on the Standard User profile. A package install writes the Manage Job Runner permission into the
	 * System Administrator profile, so a user there would hold the very permission the refusal tests need them to lack.
	 * This user keeps the Kern Administrator set, which gives field and record access to the rows it reads back, so its
	 * refusal can only come from the job runner permission check.
	 */
	@TestSetup
	private static void setupUsers()
	{
		TST_Factory.newUserWithPermissionSet(SEL_Profile.PROFILE_SYSTEM_ADMIN, MANAGING_ADMIN_COMPANY, UTIL_ScheduledJobRunner.JOB_RUNNER_MANAGEMENT_PERMISSION_SET_NAME);
		TST_Factory.newUserWithPermissionSet(SEL_Profile.PROFILE_STANDARD_USER, NO_JOB_RUNNER_PERMISSION_COMPANY, SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME);
		TST_Factory.newUserWithPermissionSet(SEL_Profile.PROFILE_STANDARD_USER, LOW_PRIVILEGE_MANAGER_COMPANY, UTIL_ScheduledJobRunner.JOB_RUNNER_MANAGEMENT_PERMISSION_SET_NAME);
	}

	/**
	 * @description Reads back the administrator who holds the Kern Job Runner Management permission set.
	 *
	 * @return The managing administrator.
	 */
	private static User getManagingAdmin()
	{
		return new SEL_User().findByCompanyName(MANAGING_ADMIN_COMPANY);
	}

	/**
	 * @description Reads back the user who holds no job runner permission, and asserts that the user really lacks it. On a
	 * package install for all users, the profile grant gives every user the permission, so a refusal test there would not
	 * test a user without it. The assertion says so, instead of editing the org's setup rows to create such a user.
	 *
	 * @return The user, checked to lack the Manage Job Runner permission.
	 */
	private static User getUserWithoutJobRunnerPermission()
	{
		User userWithoutPermission = new SEL_User().findByCompanyName(NO_JOB_RUNNER_PERMISSION_COMPANY);
		Assert.isFalse
				(
						SEL_CustomPermission.hasPackagePermission(userWithoutPermission.Id, UTIL_ScheduledJobRunner.MANAGE_JOB_RUNNER_CUSTOM_PERMISSION_NAME),
						'This org grants ' +
						UTIL_ScheduledJobRunner.MANAGE_JOB_RUNNER_CUSTOM_PERMISSION_NAME +
						' to the Standard User profile (an all-users package install), so no non-holder exists to prove the refusal against; ' +
						'run this suite in an org installed for admins only'
				);
		return userWithoutPermission;
	}

	/**
	 * @description Reads back the low-privilege manager: a Standard User holding the Kern Job Runner Management set alone,
	 * with no Modify All, so record sharing applies to every row they do not own.
	 *
	 * @return The low-privilege manager.
	 */
	private static User getLowPrivilegeManager()
	{
		return new SEL_User().findByCompanyName(LOW_PRIVILEGE_MANAGER_COMPANY);
	}

	/**
	 * @description Starts a scheduled job record that never reaches the database, with the class name and the execution
	 * mode left empty. The helpers under test read exactly those two fields, so the builder must not fill them in with
	 * values of its own.
	 *
	 * @return The builder, ready for the one field a test means to set.
	 */
	private static TST_Builder.Builder prepareRowInMemory()
	{
		return TST_Builder.of(ScheduledJob__c.SObjectType)
				.withOptionalField(ScheduledJob__c.ClassName__c)
				.withOptionalField(ScheduledJob__c.ExecutionMode__c)
				.withoutInsertion(true);
	}

	/**
	 * @description Builds a scheduled job record in memory with nothing in either field the helpers under test read.
	 *
	 * @return The record, never inserted.
	 */
	private static ScheduledJob__c buildRowInMemory()
	{
		return (ScheduledJob__c)prepareRowInMemory().build();
	}

	/**
	 * @description Builds a scheduled job record in memory carrying one field, so a test can hand a helper exactly the
	 * value the test is about and nothing else.
	 *
	 * @param field The field to set.
	 * @param value The value to set it to.
	 *
	 * @return The record, never inserted.
	 */
	private static ScheduledJob__c buildRowInMemory(SObjectField field, Object value)
	{
		return (ScheduledJob__c)prepareRowInMemory().withOverride(field, value).build();
	}

	/**
	 * @description Tests that the execution mode is read from the picklist and that blank keeps a record on its own
	 * scheduled job, so no record that existed before the runner changes behaviour.
	 */
	@IsTest
	private static void isJobRunnerModeReadsThePicklistAndTreatsBlankAsOwnMode()
	{
		ScheduledJob__c runnerMode = buildRowInMemory(ScheduledJob__c.ExecutionMode__c, UTIL_ScheduledJobRunner.EXECUTION_MODE_JOB_RUNNER);
		ScheduledJob__c ownMode = buildRowInMemory(ScheduledJob__c.ExecutionMode__c, UTIL_ScheduledJobRunner.EXECUTION_MODE_OWN_SCHEDULED_JOB);

		Assert.isTrue(UTIL_ScheduledJobRunner.isJobRunnerMode(runnerMode), 'JobRunner is job-runner mode');
		Assert.isFalse(UTIL_ScheduledJobRunner.isJobRunnerMode(ownMode), 'OwnScheduledJob is own mode');
		Assert.isFalse(UTIL_ScheduledJobRunner.isJobRunnerMode(buildRowInMemory()), 'blank reads as own mode, so every existing record is untouched');
		Assert.isFalse(UTIL_ScheduledJobRunner.isJobRunnerMode(null), 'a missing record is not on the runner');
	}

	/**
	 * @description Tests that the runner's own schedulable is recognised whether its class name is written with the
	 * package namespace or without it, and that no other class name is mistaken for it.
	 */
	@IsTest
	private static void isRunnerRecordRecognisesTheRunnerClassHoweverItIsWritten()
	{
		String qualifiedName = UTIL_ScheduledJobRunner.RUNNER_CLASS_NAME;
		String bareName = qualifiedName.substringAfterLast(UTIL_String.DOT);
		String writtenName = String.isBlank(bareName) ? qualifiedName : bareName;
		String foreignNamespaceName = FOREIGN_NAMESPACE + UTIL_String.DOT + RUNNER_CLASS_BARE_NAME;

		Assert.isTrue(UTIL_ScheduledJobRunner.isRunnerRecord(buildRowInMemory(ScheduledJob__c.ClassName__c, qualifiedName)), 'the qualified name');
		Assert.isTrue(UTIL_ScheduledJobRunner.isRunnerRecord(buildRowInMemory(ScheduledJob__c.ClassName__c, writtenName)), 'the bare name names the same class');
		String lowerCaseBareName = RUNNER_CLASS_BARE_NAME.toLowerCase();
		Assert.isTrue(UTIL_ScheduledJobRunner.isRunnerRecord(buildRowInMemory(ScheduledJob__c.ClassName__c, lowerCaseBareName)), 'the letter case does not matter');
		ScheduledJob__c foreignRecord = buildRowInMemory(ScheduledJob__c.ClassName__c, foreignNamespaceName);
		ScheduledJob__c otherSchedulable = buildRowInMemory(ScheduledJob__c.ClassName__c, SCHED_PurgeRecords.class.getName());
		ScheduledJob__c unknownClass = buildRowInMemory(ScheduledJob__c.ClassName__c, UTIL_Random.randomName());

		Assert.isFalse(UTIL_ScheduledJobRunner.isRunnerRecord(foreignRecord), 'the same bare name under another namespace is another class');
		Assert.isFalse(UTIL_ScheduledJobRunner.isRunnerRecord(otherSchedulable), 'another schedulable is not a runner record');
		Assert.isFalse(UTIL_ScheduledJobRunner.isRunnerRecord(unknownClass), 'an unknown class is not a runner record');
		Assert.isFalse(UTIL_ScheduledJobRunner.isRunnerRecord(buildRowInMemory()), 'a record with no class name is not a runner record');
		Assert.isFalse(UTIL_ScheduledJobRunner.isRunnerRecord(null), 'a missing record is not a runner record');
	}

	/**
	 * @description Tests that the manage permission follows the running user: the permission set grants it, and an
	 * administrator without the set does not hold it.
	 */
	@IsTest
	private static void hasManagePermissionFollowsTheRunningUser()
	{
		System.runAs(getManagingAdmin())
		{
			Assert.isTrue(UTIL_ScheduledJobRunner.hasManagePermission(), 'the Kern Job Runner Management permission set grants ManageJobRunner');
		}
		System.runAs(getUserWithoutJobRunnerPermission())
		{
			Assert.isFalse(UTIL_ScheduledJobRunner.hasManagePermission(), 'an administrator without the set does not hold it');
		}
	}

	/**
	 * @description Turns the job runner on for the rest of the test by registering its feature flag as enabled, and turns
	 * on log capture so every assertion about what the runner logged is a real one.
	 */
	private static void enableTheRunner()
	{
		TST_Factory.newFeatureFlag(UTIL_ScheduledJobRunner.FEATURE_FLAG_NAME);
		captureLogEntries();
	}

	/**
	 * @description Turns the job runner off for the rest of the test (the flag exists but nothing has it enabled), and
	 * turns on log capture so the assertion that nothing was logged is a real one.
	 */
	private static void disableTheRunner()
	{
		SEL_FeatureFlag.allDeveloperNames = new Set<String> {UTIL_ScheduledJobRunner.FEATURE_FLAG_NAME};
		SEL_FeatureFlag.activeFlags = new Map<String, FeatureFlag__mdt>();
		captureLogEntries();
	}

	/**
	 * @description Turns log capture on for the rest of the test: the logger writes while a test is running and keeps
	 * everything from DEBUG upwards, so an assertion about what a check logged, or about its logging nothing, means
	 * what it says.
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
	 * @description Inserts a job-runner row directly, with the trigger bypassed, so a test controls the cursor, the stamp
	 * and the policy exactly.
	 *
	 * @param name The scheduler name, unique per row.
	 * @param cursor The NextRunAt__c value the row starts with.
	 * @param priority The RunPriority__c value, blank allowed.
	 * @param overlapPolicy The OverlapPolicy__c value.
	 * @param className The Apex class the row names.
	 *
	 * @return The inserted row.
	 */
	private static ScheduledJob__c insertRow(String name, Datetime cursor, Decimal priority, String overlapPolicy, String className)
	{
		TRG_Base.bypass(ScheduledJob__c.SObjectType);
		ScheduledJob__c row = (ScheduledJob__c)TST_Builder.of(ScheduledJob__c.SObjectType)
				.withOverride(ScheduledJob__c.SchedulerName__c, name)
				.withOverride(ScheduledJob__c.ClassName__c, className)
				.withOverride(ScheduledJob__c.CronExpression__c, EVERY_FIVE_MINUTES)
				.withOverride(ScheduledJob__c.Timezone__c, UTC_TIMEZONE)
				.withOverride(ScheduledJob__c.IsActive__c, true)
				.withOverride(ScheduledJob__c.ExecutionMode__c, UTIL_ScheduledJobRunner.EXECUTION_MODE_JOB_RUNNER)
				.withOverride(ScheduledJob__c.NextRunAt__c, cursor)
				.withOverride(ScheduledJob__c.RunPriority__c, priority)
				.withOverride(ScheduledJob__c.OverlapPolicy__c, overlapPolicy)
				.build();
		TRG_Base.clearBypass(ScheduledJob__c.SObjectType);
		return row;
	}

	/**
	 * @description Inserts a row that is due exactly at the test clock, runs the counting fixture job and skips while its
	 * previous run is live.
	 *
	 * @param name The scheduler name, unique per row.
	 *
	 * @return The inserted row.
	 */
	private static ScheduledJob__c insertDueRow(String name)
	{
		return insertRow(name, CHECK_TIME, null, UTIL_ScheduledJobRunner.OVERLAP_POLICY_SKIP, RecordingJob.class.getName());
	}

	/**
	 * @description Reads one row back with every field the selector carries.
	 *
	 * @param rowId The row id.
	 *
	 * @return The row as it now stands.
	 */
	private static ScheduledJob__c reload(Id rowId)
	{
		return (ScheduledJob__c)new SEL_ScheduledJob().findById(rowId);
	}

	/**
	 * @description Delivers the pending log events and reads back everything the check logged.
	 *
	 * @return The check's log entries.
	 */
	private static List<LogEntry__c> checkLogEntries()
	{
		Test.getEventBus().deliver();
		return new SEL_LogEntry().findAllByMethod(CHECK_METHOD);
	}

	/**
	 * @description Delivers the pending log events and reads back everything a run logged.
	 *
	 * @return The run's log entries.
	 */
	private static List<LogEntry__c> runLogEntries()
	{
		Test.getEventBus().deliver();
		return new SEL_LogEntry().findAllByMethod(RUN_METHOD);
	}

	/**
	 * @description Starts a job that stays queued for the rest of the test and writes its id onto both rows as their
	 * previous run, with the trigger bypassed so the write is the stamp and nothing else.
	 *
	 * @param first The first row to stamp.
	 * @param second The second row to stamp.
	 *
	 * @return The queued job's id, now the previous run of both rows.
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	private static Id stampBothRowsWithALiveRun(ScheduledJob__c first, ScheduledJob__c second)
	{
		Id liveJobId = System.enqueueJob(new NoOperationJob());
		TRG_Base.bypass(ScheduledJob__c.SObjectType);
		List<ScheduledJob__c> stamped = new List<ScheduledJob__c>
		{
				new ScheduledJob__c(Id = first.Id, LastRunJobId__c = liveJobId),
				new ScheduledJob__c(Id = second.Id, LastRunJobId__c = liveJobId)
		};
		// Arranges a live previous run; the stamp is the runner's to write, never the manager's.
		DML_Builder.newTransaction().withSystemMode().doUpdate(stamped).execute();
		TRG_Base.clearBypass(ScheduledJob__c.SObjectType);
		return liveJobId;
	}

	/**
	 * @description Tests the ordinary check: every due row is started, each row's next run time is worked out from the
	 * check time rather than from the cursor it had, the run id is on the record before the run starts, and the outcome
	 * lands once the run finishes.
	 */
	@IsTest
	private static void checkStartsDueRowsMovesEachCursorFromTheCheckTimeAndTheRunRecordsSucceeded()
	{
		System.runAs(getManagingAdmin())
		{
			enableTheRunner();
			ScheduledJob__c first = insertDueRow('first');
			ScheduledJob__c second = insertRow('second', CHECK_TIME.addMinutes(-7), null, UTIL_ScheduledJobRunner.OVERLAP_POLICY_SKIP, RecordingJob.class.getName());

			Test.startTest();
			UTIL_ScheduledJobRunner.CheckResult result = UTIL_ScheduledJobRunner.checkForDueJobs(CHECK_TIME.addSeconds(12));
			ScheduledJob__c stampedBeforeStop = reload(first.Id);
			Assert.isNotNull(stampedBeforeStop.LastRunJobId__c, 'the run id is stamped in the check transaction, before the run executes');
			List<Id> stampedRunIds = new List<Id> {stampedBeforeStop.LastRunJobId__c};
			Integer liveStampedRuns = new SEL_AsyncApexJob().findLiveByIds(stampedRunIds).size();
			Assert.areEqual(1, liveStampedRuns, 'the stamp is the id System.enqueueJob returned, and the run is queued');
			Test.stopTest();

			Assert.areEqual(2, result.started, 'both due rows were started');
			Assert.areEqual(CHECK_TIME, result.checkTime, 'the clock was snapped to the minute');
			Assert.areEqual(2, recordedRunCount, 'both runs executed');
			Assert.isNotNull(recordedTriggerId, 'each run was handed a Kern run context naming the run itself');
			Assert.areEqual(UserInfo.getUserId(), recordedRunningUserId, 'and ran as the user the runner belongs to');
			Datetime expectedCursor = UTIL_CronExpression.nextFireTime(EVERY_FIVE_MINUTES, CHECK_TIME, UTC_TIMEZONE);
			for(ScheduledJob__c row : new List<ScheduledJob__c> {reload(first.Id), reload(second.Id)})
			{
				Assert.areEqual(expectedCursor, row.NextRunAt__c, 'the cursor is computed from the check time, never from the old cursor');
				Assert.areEqual(UTIL_ScheduledJobRunner.OUTCOME_SUCCEEDED, row.LastRunOutcome__c, 'the Finalizer recorded the outcome');
				Assert.isNotNull(row.LastRunAt__c, 'and when the run finished');
				Assert.isNull(row.LastRunReason__c, 'a success leaves no reason');
				Assert.isNull(row.ScheduledJobId__c, 'no CronTrigger was ever created');
			}
			Assert.isTrue(checkLogEntries().isEmpty(), 'a check that only started jobs writes no log entry');
			ScheduleSetting__c lastCheck = SEL_ScheduleSetting.getScheduleSetting(UTIL_ScheduledJobRunner.LAST_CHECK_SETTING_NAME);
			Assert.areEqual(CHECK_TIME.addSeconds(12), lastCheck.LastSuccessfulRunTime__c, 'the last check is recorded with the check clock');
		}
	}

	/**
	 * @description Tests that a row whose next run time has not arrived is untouched, and that a row whose run times were
	 * all missed while the runner was off runs once, not once per missed occurrence.
	 */
	@IsTest
	private static void checkLeavesRowsNotYetDueAloneAndAMissedOccurrenceIsConsumedOnce()
	{
		System.runAs(getManagingAdmin())
		{
			enableTheRunner();
			ScheduledJob__c notDue = insertRow('not due', CHECK_TIME.addMinutes(1), null, UTIL_ScheduledJobRunner.OVERLAP_POLICY_SKIP, RecordingJob.class.getName());
			ScheduledJob__c threeHoursLate = insertRow('late', CHECK_TIME.addHours(-3), null, UTIL_ScheduledJobRunner.OVERLAP_POLICY_SKIP, RecordingJob.class.getName());

			Test.startTest();
			UTIL_ScheduledJobRunner.CheckResult result = UTIL_ScheduledJobRunner.checkForDueJobs(CHECK_TIME);
			Test.stopTest();

			Assert.areEqual(1, result.started, 'only the overdue row ran');
			Assert.areEqual(CHECK_TIME.addMinutes(1), reload(notDue.Id).NextRunAt__c, 'a row due next minute is untouched');
			Datetime lateCursor = reload(threeHoursLate.Id).NextRunAt__c;
			Assert.areEqual(CHECK_TIME.addMinutes(5), lateCursor, 'three hours of missed occurrences yield one run and a cursor strictly after the check');
			Assert.areEqual(1, recordedRunCount, 'one run, not thirty-six');
		}
	}

	/**
	 * @description Tests that a check starts no more jobs than it may and takes them in run-priority order: with room for
	 * one job and three due rows, the row at priority 1 is the one that goes, the row at priority 2 and the row with no
	 * priority at all are left due for the next check, and one WARN says they were left behind.
	 */
	@IsTest
	private static void checkLimitCutsOffInPriorityOrderAndWarnsAboutRowsLeftWaiting()
	{
		System.runAs(getManagingAdmin())
		{
			enableTheRunner();
			SEL_AsynchronousJobSetting.mockedSetting = new AsynchronousJobSetting__mdt(DeveloperName = UTIL_ScheduledJobRunner.CHECK_LIMIT_SETTING_NAME, BatchSize__c = 1);
			ScheduledJob__c blank = insertRow('blank', CHECK_TIME.addMinutes(-30), null, UTIL_ScheduledJobRunner.OVERLAP_POLICY_SKIP, RecordingJob.class.getName());
			ScheduledJob__c two = insertRow('two', CHECK_TIME, 2, UTIL_ScheduledJobRunner.OVERLAP_POLICY_SKIP, RecordingJob.class.getName());
			ScheduledJob__c one = insertRow('one', CHECK_TIME, 1, UTIL_ScheduledJobRunner.OVERLAP_POLICY_SKIP, RecordingJob.class.getName());

			Test.startTest();
			UTIL_ScheduledJobRunner.CheckResult result = UTIL_ScheduledJobRunner.checkForDueJobs(CHECK_TIME);
			Test.stopTest();

			Assert.areEqual(1, result.checkLimit, 'the configured check limit');
			Assert.areEqual(1, result.started, 'one row started');
			Assert.areEqual(2, result.leftWaiting, 'two left for the next check');
			Assert.isNotNull(reload(one.Id).LastRunJobId__c, 'priority 1 was the one row the check had room for');
			Assert.isNull(reload(two.Id).LastRunJobId__c, 'priority 2 waited, so the claim really is in priority order');
			Assert.isNull(reload(blank.Id).LastRunJobId__c, 'the blank priority waited');
			Assert.areEqual(CHECK_TIME.addMinutes(-30), reload(blank.Id).NextRunAt__c, 'and its cursor is unchanged, so it is still due');
			List<LogEntry__c> entries = checkLogEntries();
			Assert.areEqual(1, entries.size(), 'exactly one WARN says the check was at its limit');
			Assert.areEqual(LoggingLevel.WARN.name(), entries[0].LogLevel__c, 'at WARN');
		}
	}

	/**
	 * @description Tests that the number of jobs a check may start never exceeds the queueable allowance the transaction
	 * has left, so a configured limit can never make a check hit a governor limit it cannot catch. The loop spends
	 * the allowance on purpose, which is the only way to prove the clamp.
	 */
	@IsTest
	@SuppressWarnings('PMD.OperationWithLimitsInLoop')
	private static void effectiveCheckLimitShrinksToTheRemainingQueueableAllowance()
	{
		System.runAs(getManagingAdmin())
		{
			enableTheRunner();
			insertDueRow('a');
			insertDueRow('b');

			Test.startTest();
			Integer allowance = UTIL_Limits.queueableJobs().remaining();
			for(Integer index = 0; index < allowance - 1; index++)
			{
				System.enqueueJob(new NoOperationJob());
			}
			UTIL_ScheduledJobRunner.CheckResult result = UTIL_ScheduledJobRunner.checkForDueJobs(CHECK_TIME);
			Test.stopTest();

			Assert.areEqual(1, result.checkLimit, 'the effective check limit is the one enqueue left, not the configured 25');
			Assert.areEqual(1, result.started, 'one row started');
			Assert.areEqual(1, result.leftWaiting, 'one left waiting and warned about');
		}
	}

	/**
	 * @description Tests that a row the runner cannot use is parked with its reason and pushed out of the way, and that
	 * editing what was wrong with it brings it back into the queue.
	 */
	@IsTest
	private static void parkedRowsRotateOutAndUnparkOnAnEdit()
	{
		System.runAs(getManagingAdmin())
		{
			enableTheRunner();
			ScheduledJob__c noSuchClass = insertRow('no class', CHECK_TIME, null, UTIL_ScheduledJobRunner.OVERLAP_POLICY_SKIP, UTIL_Random.randomName());
			ScheduledJob__c neverFires = insertRow('never', CHECK_TIME, null, UTIL_ScheduledJobRunner.OVERLAP_POLICY_SKIP, RecordingJob.class.getName());
			TRG_Base.bypass(ScheduledJob__c.SObjectType);
			DML_Builder.newTransaction().doUpdate(new ScheduledJob__c(Id = neverFires.Id, CronExpression__c = NEVER_FIRES_AGAIN)).execute();
			TRG_Base.clearBypass(ScheduledJob__c.SObjectType);

			Test.startTest();
			UTIL_ScheduledJobRunner.CheckResult result = UTIL_ScheduledJobRunner.checkForDueJobs(CHECK_TIME);
			Test.stopTest();

			Assert.areEqual(2, result.parked, 'both rows were parked');
			Assert.areEqual(0, result.started, 'no job was started');
			ScheduledJob__c parkedClass = reload(noSuchClass.Id);
			Assert.areEqual(UTIL_ScheduledJobRunner.OUTCOME_PARKED, parkedClass.LastRunOutcome__c, 'outcome Parked');
			Assert.areEqual(UTIL_ScheduledJobRunner.REASON_CLASS_NOT_FOUND, parkedClass.LastRunReason__c, 'the reason names the class problem');
			Datetime parkedCursor = CHECK_TIME.addDays(UTIL_ScheduledJobRunner.PARKED_CURSOR_PUSH_DAYS);
			Assert.areEqual(parkedCursor, parkedClass.NextRunAt__c, 'the cursor is pushed a day so the row cannot hold the front of the queue');
			ScheduledJob__c parkedExpression = reload(neverFires.Id);
			String horizonReason = UTIL_ScheduledJobRunner.REASON_EXPRESSION_CANNOT_FIRE_WITHIN_HORIZON;
			Assert.areEqual(horizonReason, parkedExpression.LastRunReason__c, 'an expression with a past year is parked with the horizon reason');
			Assert.areEqual(2, checkLogEntries().size(), 'each parked row has its log entry');

			parkedClass.ClassName__c = RecordingJob.class.getName();
			DML_Builder.newTransaction().doUpdate(parkedClass).execute();
			parkedClass.CronExpression__c = EVERY_TEN_MINUTES;
			DML_Builder.newTransaction().doUpdate(parkedClass).execute();
			Datetime reseededCursor = reload(parkedClass.Id).NextRunAt__c;
			Assert.areNotEqual(parkedCursor, reseededCursor, 'the parked cursor is gone');
			Assert.isTrue(reseededCursor > Datetime.now(), 'an expression edit re-seeds the cursor to the next window, un-parking the row');
			Assert.isTrue(reseededCursor <= Datetime.now().addMinutes(TEN_MINUTE_WINDOW), 'and that window is the next one the expression names');
		}
	}

	/**
	 * @description Tests that a job whose cron expression cannot be read at all is parked under its own reason, which is
	 * a different problem from an expression that reads correctly but never fires again.
	 */
	@IsTest
	private static void anUnreadableExpressionParksTheRowWithItsOwnReason()
	{
		System.runAs(getManagingAdmin())
		{
			enableTheRunner();
			ScheduledJob__c row = insertDueRow('unreadable');
			TRG_Base.bypass(ScheduledJob__c.SObjectType);
			DML_Builder.newTransaction().doUpdate(new ScheduledJob__c(Id = row.Id, CronExpression__c = UNREADABLE_EXPRESSION)).execute();
			TRG_Base.clearBypass(ScheduledJob__c.SObjectType);

			Test.startTest();
			UTIL_ScheduledJobRunner.CheckResult result = UTIL_ScheduledJobRunner.checkForDueJobs(CHECK_TIME);
			Test.stopTest();

			Assert.areEqual(1, result.parked, 'the row was parked');
			Assert.areEqual(0, result.started, 'no job was started');
			ScheduledJob__c parked = reload(row.Id);
			Assert.areEqual(UTIL_ScheduledJobRunner.OUTCOME_PARKED, parked.LastRunOutcome__c, 'outcome Parked');
			String placementReason = UTIL_ScheduledJobRunner.REASON_EXPRESSION_CANNOT_BE_PLACED;
			Assert.areEqual(placementReason, parked.LastRunReason__c, 'with the reason that says the expression could not be read');
			Datetime parkedCursor = CHECK_TIME.addDays(UTIL_ScheduledJobRunner.PARKED_CURSOR_PUSH_DAYS);
			Assert.areEqual(parkedCursor, parked.NextRunAt__c, 'and its cursor pushed out of the way');
			Assert.areEqual(1, checkLogEntries().size(), 'with one log entry carrying the detail');
		}
	}

	/**
	 * @description Tests the two overlap policies against the same live previous run: Skip gives up this run time and says
	 * why, Allow starts anyway.
	 */
	@IsTest
	private static void overlapSkipConsumesTheOccurrenceWhileAllowStartsTheRun()
	{
		System.runAs(getManagingAdmin())
		{
			enableTheRunner();
			ScheduledJob__c skipping = insertRow('skip', CHECK_TIME, null, UTIL_ScheduledJobRunner.OVERLAP_POLICY_SKIP, RecordingJob.class.getName());
			ScheduledJob__c allowing = insertRow('allow', CHECK_TIME, null, UTIL_ScheduledJobRunner.OVERLAP_POLICY_ALLOW, RecordingJob.class.getName());

			Test.startTest();
			Id liveJobId = stampBothRowsWithALiveRun(skipping, allowing);
			UTIL_ScheduledJobRunner.CheckResult result = UTIL_ScheduledJobRunner.checkForDueJobs(CHECK_TIME);
			Test.stopTest();

			Assert.areEqual(1, result.skipped, 'the Skip row was skipped because its previous run is still queued');
			Assert.areEqual(1, result.started, 'the Allow row ran regardless');
			ScheduledJob__c skipped = reload(skipping.Id);
			Assert.areEqual(UTIL_ScheduledJobRunner.OUTCOME_SKIPPED, skipped.LastRunOutcome__c, 'outcome Skipped');
			Assert.areEqual(UTIL_ScheduledJobRunner.REASON_PREVIOUS_RUN_STILL_RUNNING, skipped.LastRunReason__c, 'with the reason');
			Assert.areEqual(CHECK_TIME.addMinutes(5), skipped.NextRunAt__c, 'Skip consumes the occurrence');
			Assert.areEqual(liveJobId, Id.valueOf(skipped.LastRunJobId__c), 'and never touches the previous run id');
			Assert.areNotEqual(liveJobId, Id.valueOf(reload(allowing.Id).LastRunJobId__c), 'Allow stamped its new run');
			Assert.areEqual(1, checkLogEntries().size(), 'the skip has its log entry');
		}
	}

	/**
	 * @description Tests the overlap case the runner produces for itself: a run the runner started at one check is still
	 * going when the next check comes round, and the Skip policy recognises it. The run id the runner writes and the run
	 * id the platform's job table returns are the same job, so the two checks must agree about it.
	 */
	@IsTest
	private static void aRunTheCheckStartedIsStillLiveAtTheNextCheckSoSkipSkipsIt()
	{
		System.runAs(getManagingAdmin())
		{
			enableTheRunner();
			ScheduledJob__c row = insertDueRow('its own run');

			Test.startTest();
			UTIL_ScheduledJobRunner.CheckResult first = UTIL_ScheduledJobRunner.checkForDueJobs(CHECK_TIME);
			Id firstRunId = Id.valueOf(reload(row.Id).LastRunJobId__c);
			UTIL_ScheduledJobRunner.CheckResult second = UTIL_ScheduledJobRunner.checkForDueJobs(CHECK_TIME.addMinutes(5));
			ScheduledJob__c skipped = reload(row.Id);
			Test.stopTest();

			Assert.areEqual(1, first.started, 'the first check started the run');
			Assert.areEqual(1, second.skipped, 'the second check found that run still going and skipped this run time');
			Assert.areEqual(0, second.started, 'so it started nothing');
			Assert.areEqual(UTIL_ScheduledJobRunner.REASON_PREVIOUS_RUN_STILL_RUNNING, skipped.LastRunReason__c, 'with the reason');
			Assert.areEqual(firstRunId, Id.valueOf(skipped.LastRunJobId__c), 'and the stamp is still the first run');
			Assert.areEqual(1, recordedRunCount, 'one run, because the second run time was given up');
		}
	}

	/**
	 * @description Tests that one row the runner cannot write does not stop the rows behind it: the refused row is logged
	 * and stays due, the next row still starts, and the check finishes and records itself.
	 */
	@IsTest
	private static void aRefusedParkWriteIsLoggedAndTheOtherDueRowsStillStart()
	{
		System.runAs(getManagingAdmin())
		{
			enableTheRunner();
			ScheduledJob__c refused = insertRow('refused', CHECK_TIME, 1, UTIL_ScheduledJobRunner.OVERLAP_POLICY_SKIP, UTIL_Random.randomName());
			ScheduledJob__c healthy = insertRow('healthy', CHECK_TIME, 2, UTIL_ScheduledJobRunner.OVERLAP_POLICY_SKIP, RecordingJob.class.getName());

			Test.startTest();
			UTIL_ScheduledJobRunner.simulateRowWriteFailure = true;
			UTIL_ScheduledJobRunner.CheckResult result = UTIL_ScheduledJobRunner.checkForDueJobs(CHECK_TIME);
			Test.stopTest();

			Assert.areEqual(1, result.writeFailures, 'the park write was refused');
			Assert.areEqual(0, result.parked, 'so nothing was recorded as parked');
			Assert.areEqual(1, result.started, 'and the row behind it still started');
			ScheduledJob__c unchanged = reload(refused.Id);
			Assert.areEqual(CHECK_TIME, unchanged.NextRunAt__c, 'the refused row keeps its run time, so it is due again');
			Assert.isNull(unchanged.LastRunOutcome__c, 'and nothing was recorded on it');
			Assert.isNotNull(reload(healthy.Id).LastRunJobId__c, 'the healthy row has its run stamped');
			ScheduleSetting__c lastCheck = SEL_ScheduleSetting.getScheduleSetting(UTIL_ScheduledJobRunner.LAST_CHECK_SETTING_NAME);
			Assert.isNotNull(lastCheck, 'the check finished and recorded itself');
			List<LogEntry__c> entries = checkLogEntries();
			Assert.areEqual(1, entries.size(), 'exactly one entry accounts for the refused row');
			Assert.areEqual(LoggingLevel.ERROR.name(), entries[0].LogLevel__c, 'at ERROR');
			Assert.areEqual(refused.Id, entries[0].RecordId__c, 'linked to the row it was about');
		}
	}

	/**
	 * @description Tests that when the record cannot be written after its run was queued, the queued run is called off and
	 * the record is left exactly as it was, so the run time is not silently lost.
	 */
	@IsTest
	private static void aRowWriteThatFailsAfterTheEnqueueAbortsTheRunAndLeavesTheRowDue()
	{
		System.runAs(getManagingAdmin())
		{
			enableTheRunner();
			ScheduledJob__c row = insertDueRow('write fails');

			Test.startTest();
			UTIL_ScheduledJobRunner.simulateRowWriteFailure = true;
			UTIL_ScheduledJobRunner.CheckResult result = UTIL_ScheduledJobRunner.checkForDueJobs(CHECK_TIME);
			Test.stopTest();

			Assert.areEqual(1, result.writeFailures, 'the write failed once');
			Assert.areEqual(0, result.started, 'nothing counts as started');
			Assert.areEqual(0, result.leftWaiting, 'a row whose write failed is not reported as left waiting by the check limit');
			Assert.areEqual(0, recordedRunCount, 'the enqueued run was aborted and never executed');
			ScheduledJob__c unchanged = reload(row.Id);
			Assert.areEqual(CHECK_TIME, unchanged.NextRunAt__c, 'the row is unchanged and still due');
			Assert.isNull(unchanged.LastRunJobId__c, 'no stamp');
			Assert.areEqual(1, checkLogEntries().size(), 'the failure is logged');
			Assert.areEqual(row.Id, checkLogEntries()[0].RecordId__c, 'and it names the row');
		}
	}

	/**
	 * @description Tests that a check which cannot claim the rows because another writer holds them exits without changing
	 * anything, says so once, and still records that the runner checked.
	 */
	@IsTest
	private static void aLockTimeoutIsACleanExitWithOneWarnAndTheLastCheckRecorded()
	{
		System.runAs(getManagingAdmin())
		{
			enableTheRunner();
			ScheduledJob__c row = insertDueRow('locked out');

			Test.startTest();
			SEL_ScheduledJob.simulateLockTimeout = true;
			UTIL_ScheduledJobRunner.CheckResult result = UTIL_ScheduledJobRunner.checkForDueJobs(CHECK_TIME);
			Test.stopTest();

			Assert.isTrue(result.lockedOut, 'the check reports the lock-out');
			Assert.areEqual(0, result.started, 'no job was started');
			Assert.areEqual(CHECK_TIME, reload(row.Id).NextRunAt__c, 'no row changed');
			List<LogEntry__c> entries = checkLogEntries();
			Assert.areEqual(1, entries.size(), 'exactly one WARN');
			Assert.areEqual(LoggingLevel.WARN.name(), entries[0].LogLevel__c, 'at WARN');
			ScheduleSetting__c lastCheck = SEL_ScheduleSetting.getScheduleSetting(UTIL_ScheduledJobRunner.LAST_CHECK_SETTING_NAME);
			Assert.isNotNull(lastCheck, 'the last check is still recorded');
		}
	}

	/**
	 * @description Tests that a check running as a user who does not hold the Manage Job Runner permission starts nothing
	 * and does not record the runner as alive, so the Health Check sees that the runner has stopped.
	 */
	@IsTest
	private static void theEntryGuardRefusesAUserWithoutThePermission()
	{
		ScheduledJob__c row;
		System.runAs(getManagingAdmin())
		{
			row = insertDueRow('guarded');
		}
		System.runAs(getUserWithoutJobRunnerPermission())
		{
			enableTheRunner();
			Test.startTest();
			UTIL_ScheduledJobRunner.CheckResult result = UTIL_ScheduledJobRunner.checkForDueJobs(CHECK_TIME);
			Test.stopTest();

			Assert.isTrue(result.refusedWithoutPermission, 'the check refused');
			Assert.areEqual(CHECK_TIME, reload(row.Id).NextRunAt__c, 'no row changed');
			Assert.areEqual(1, checkLogEntries().size(), 'one WARN');
			ScheduleSetting__c lastCheck = SEL_ScheduleSetting.getScheduleSetting(UTIL_ScheduledJobRunner.LAST_CHECK_SETTING_NAME);
			Assert.isNull(lastCheck, 'no check is recorded, so Health Check shows the runner has stopped');
		}
	}

	/**
	 * @description Tests that turning the runner's feature flag off stops every job without touching a record, while the
	 * runner still records that it is alive, so an administrator sees a running-but-idle runner rather than a dead one.
	 */
	@IsTest
	private static void theFeatureFlagStopsEveryRowButStillRecordsTheLastCheck()
	{
		System.runAs(getManagingAdmin())
		{
			disableTheRunner();
			ScheduledJob__c row = insertDueRow('switched off');

			Test.startTest();
			UTIL_ScheduledJobRunner.CheckResult result = UTIL_ScheduledJobRunner.checkForDueJobs(CHECK_TIME);
			Test.stopTest();

			Assert.isTrue(result.stoppedByFeatureFlag, 'the flag stopped the check');
			Assert.areEqual(CHECK_TIME, reload(row.Id).NextRunAt__c, 'no row changed');
			ScheduleSetting__c lastCheck = SEL_ScheduleSetting.getScheduleSetting(UTIL_ScheduledJobRunner.LAST_CHECK_SETTING_NAME);
			Assert.areEqual(CHECK_TIME, lastCheck.LastSuccessfulRunTime__c, 'the last check is still recorded');
			Assert.isTrue(checkLogEntries().isEmpty(), 'and nothing is logged');
		}
	}

	/**
	 * @description Tests the lock that stops two administrators activating, repairing or deactivating the runner at the
	 * same moment: it creates the row it locks, reads it for update, and creates only one row however often it is taken.
	 */
	@IsTest
	private static void theRunnerManagementLockCreatesTheSettingRowAndReadsItForUpdate()
	{
		System.runAs(getManagingAdmin())
		{
			String settingName = UTIL_ScheduledJobRunner.LAST_CHECK_SETTING_NAME;
			Assert.isNull(SEL_ScheduleSetting.getScheduleSetting(settingName), 'no setting row before the first lock');

			UTIL_ScheduledJobRunner.FrameworkWriter writer = new UTIL_ScheduledJobRunner.FrameworkWriter();
			writer.lockRunnerManagement();

			Assert.isNotNull(SEL_ScheduleSetting.getScheduleSetting(settingName), 'the lock creates the row it locks');
			String soql = writer.buildRunnerManagementLock().toSoql().toUpperCase();
			Assert.isTrue(soql.endsWith('FOR UPDATE'), 'the read locks the row: ' + soql);
			writer.lockRunnerManagement();
			Integer settingRows = QRY_Builder.selectFrom(ScheduleSetting__c.SObjectType)
					.systemModeInternal()
					.condition(ScheduleSetting__c.Name).equals(settingName)
					.count();
			Assert.areEqual(1, settingRows, 'a second lock in the same transaction creates no second row');
		}
	}

	/**
	 * @description Tests the real platform entry point: the scheduled class runs one check and the due row runs.
	 */
	@IsTest
	private static void theGlobalSchedulableRunsOneCheckThroughTheRealEntryPoint()
	{
		System.runAs(getManagingAdmin())
		{
			enableTheRunner();
			Datetime aMinuteAgo = Datetime.now().addMinutes(-1);
			ScheduledJob__c row = insertRow('via schedulable', aMinuteAgo, null, UTIL_ScheduledJobRunner.OVERLAP_POLICY_SKIP, RecordingJob.class.getName());

			Test.startTest();
			new SCHED_JobRunner().execute(null);
			Test.stopTest();

			Assert.areEqual(1, recordedRunCount, 'the schedulable checked and the due row ran');
			Assert.isTrue(reload(row.Id).NextRunAt__c > aMinuteAgo, 'the cursor moved');
		}
	}

	/**
	 * @description Tests that a job which throws lands as Failed with no reason on the record, and that the detail of the
	 * failure lives in one ERROR log entry under the job, with the card number it carried taken out of that entry.
	 */
	@IsTest
	private static void aThrowingJobRecordsFailedWithNoReasonAndAMaskedErrorEntry()
	{
		System.runAs(getManagingAdmin())
		{
			enableTheRunner();
			TST_Factory.newFeatureFlag(UTIL_FrameworkMasker.FLAG_MASKING_FRAMEWORK_ENABLED);
			ScheduledJob__c row = insertRow(CARD_LEAKING_JOB_NAME, CHECK_TIME, null, UTIL_ScheduledJobRunner.OVERLAP_POLICY_SKIP, CardLeakingJob.class.getName());

			Test.startTest();
			UTIL_ScheduledJobRunner.checkForDueJobs(CHECK_TIME);
			Id stampedRunId = Id.valueOf(reload(row.Id).LastRunJobId__c);
			try
			{
				Test.stopTest();
				Assert.fail('the job throws, so the run ends in an exception the test sees when the run is let go');
			}
			catch(Exception died)
			{
				Assert.isInstanceOfType(died, UTIL_Exceptions.IllegalStateException.class, 'the run died of the job it ran');
			}

			ScheduledJob__c failed = reload(row.Id);
			Assert.areEqual(UTIL_ScheduledJobRunner.OUTCOME_FAILED, failed.LastRunOutcome__c, 'the Finalizer recorded Failed');
			Assert.isNotNull(failed.LastRunAt__c, 'and when');
			Assert.isNull(failed.LastRunReason__c, 'a failure carries no reason; the log entry does');
			Assert.areEqual(stampedRunId, Id.valueOf(failed.LastRunJobId__c), 'the stamp written at enqueue survives the failure');
			Assert.areEqual(CHECK_TIME.addMinutes(5), failed.NextRunAt__c, 'a failed run does not re-run at the next check; the cursor already moved');
			List<LogEntry__c> entries = runLogEntries();
			Assert.areEqual(1, entries.size(), 'one ERROR entry under the job');
			Assert.areEqual(LoggingLevel.ERROR.name(), entries[0].LogLevel__c, 'at ERROR');
			Assert.isFalse(entries[0].Message__c.contains(CARD_NUMBER), 'the card number never reaches the log entry: the shipped card target masks it');
			Assert.isTrue(entries[0].Message__c.contains(DELIBERATE_FAILURE_PHRASE), 'the rest of the message survives');
			Assert.isFalse(entries[0].ShortMessage__c.contains(CARD_NUMBER), 'and the runner\'s own summary is masked too, not only the exception it carries');
			Assert.isTrue(entries[0].ShortMessage__c.contains(CARD_LEAKING_JOB_NAME), 'while the summary still names the job it was about');
		}
	}

	/**
	 * @description Tests that a run which dies before it reaches its job still lands as Failed, because the Finalizer
	 * records the outcome after the run's own transaction has gone. The run dies the way a subscriber's does: the class
	 * the record names is changed to one the org does not have between the check and the start of the run, so the run
	 * cannot load it.
	 */
	@IsTest
	private static void aRunThatDiesBeforeItsJobStillRecordsFailed()
	{
		System.runAs(getManagingAdmin())
		{
			enableTheRunner();
			ScheduledJob__c row = insertDueRow('class goes away');
			String classTheOrgDoesNotHave = UTIL_Random.randomName();

			Test.startTest();
			UTIL_ScheduledJobRunner.checkForDueJobs(CHECK_TIME);
			Id stampedRunId = Id.valueOf(reload(row.Id).LastRunJobId__c);
			TRG_Base.bypass(ScheduledJob__c.SObjectType);
			DML_Builder.newTransaction().doUpdate(new ScheduledJob__c(Id = row.Id, ClassName__c = classTheOrgDoesNotHave)).execute();
			TRG_Base.clearBypass(ScheduledJob__c.SObjectType);
			try
			{
				Test.stopTest();
				Assert.fail('the run dies, so its exception reaches the test when the run is let go');
			}
			catch(Exception died)
			{
				Assert.isInstanceOfType(died, IllegalArgumentException.class, 'the run died before it reached its job, on the class it could not load');
			}

			ScheduledJob__c failed = reload(row.Id);
			Assert.areEqual(UTIL_ScheduledJobRunner.OUTCOME_FAILED, failed.LastRunOutcome__c, 'an uncaught death still lands as Failed through the Finalizer');
			Assert.isNull(failed.LastRunReason__c, 'a failure carries no reason');
			Assert.areEqual(stampedRunId, Id.valueOf(failed.LastRunJobId__c), 'and the stamp written at enqueue survives the uncaught death');
			Assert.areEqual(0, recordedRunCount, 'the job never ran');
			Assert.isTrue(runLogEntries()[0].Message__c.contains(classTheOrgDoesNotHave), 'the log entry carries the platform result, naming the class that could not be loaded');
		}
	}

	/**
	 * @description Tests that the scheduling context a job on the runner is handed names the run itself, so a job that
	 * asks what started it is told the run's platform job id rather than a scheduled job it must not abort.
	 */
	@IsTest
	private static void theRunReceivesAKernContextWhoseTriggerIdIsTheRunItself()
	{
		System.runAs(getManagingAdmin())
		{
			enableTheRunner();
			ScheduledJob__c row = insertDueRow('context');

			Test.startTest();
			UTIL_ScheduledJobRunner.checkForDueJobs(CHECK_TIME);
			Test.stopTest();

			Assert.areEqual(Id.valueOf(reload(row.Id).LastRunJobId__c), recordedTriggerId, 'getTriggerId names the run');
		}
	}

	/**
	 * @description Tests that a record deleted after its run was queued but before the run started writes nothing and
	 * accounts for itself with one INFO entry.
	 */
	@IsTest
	private static void aRecordDeletedBetweenTheCheckAndTheRunStartLogsOnceAndWritesNothing()
	{
		System.runAs(getManagingAdmin())
		{
			enableTheRunner();
			ScheduledJob__c row = insertDueRow('deleted');

			Test.startTest();
			UTIL_ScheduledJobRunner.checkForDueJobs(CHECK_TIME);
			DML_Builder.newTransaction().doDelete(row).execute();
			Test.stopTest();

			Assert.areEqual(0, recordedRunCount, 'nothing ran');
			List<LogEntry__c> entries = runLogEntries();
			Assert.areEqual(1, entries.size(), 'one INFO entry names the deleted record');
			Assert.areEqual(LoggingLevel.INFO.name(), entries[0].LogLevel__c, 'at INFO');
		}
	}

	/**
	 * @description Tests that a record deactivated after its run was queued is skipped when the run starts, that the
	 * Finalizer leaves that outcome alone, and that nothing puts the record back on a platform schedule.
	 */
	@IsTest
	private static void aRecordDeactivatedBetweenTheCheckAndTheRunStartIsSkippedAndNothingReschedulesIt()
	{
		System.runAs(getManagingAdmin())
		{
			enableTheRunner();
			ScheduledJob__c row = insertDueRow('deactivated');

			Test.startTest();
			UTIL_ScheduledJobRunner.checkForDueJobs(CHECK_TIME);
			DML_Builder.newTransaction().doUpdate(new ScheduledJob__c(Id = row.Id, IsActive__c = false)).execute();
			Test.stopTest();

			ScheduledJob__c skipped = reload(row.Id);
			Assert.areEqual(0, recordedRunCount, 'the job did not run');
			Assert.areEqual(UTIL_ScheduledJobRunner.OUTCOME_SKIPPED, skipped.LastRunOutcome__c, 'the run recorded Skipped and the Finalizer did not overwrite it');
			Assert.areEqual(UTIL_ScheduledJobRunner.REASON_RECORD_NO_LONGER_ON_RUNNER, skipped.LastRunReason__c, 'with the reason');
			Assert.isNull(skipped.ScheduledJobId__c, 'no CronTrigger appeared');
			Assert.isFalse(skipped.IsActive__c, 'and nothing re-activated it');
		}
	}

	/**
	 * @description Tests that when the run cannot write the Skipped outcome for a record that left the runner, the run
	 * dies with that write rather than quietly claiming it recorded something, and the Finalizer then records Failed
	 * with its own entry. The record must never be left saying Skipped when no Skipped was ever written.
	 */
	@IsTest
	private static void aSkippedWriteThatFailsLeavesTheFinalizerToRecordFailed()
	{
		System.runAs(getManagingAdmin())
		{
			enableTheRunner();
			ScheduledJob__c row = insertDueRow('skipped write fails');

			Test.startTest();
			UTIL_ScheduledJobRunner.checkForDueJobs(CHECK_TIME);
			DML_Builder.newTransaction().doUpdate(new ScheduledJob__c(Id = row.Id, IsActive__c = false)).execute();
			UTIL_ScheduledJobRunner.simulateRowWriteFailure = true;
			try
			{
				Test.stopTest();
				Assert.fail('the run could not write its Skipped outcome, so it dies and the test sees that when the run is let go');
			}
			catch(Exception died)
			{
				Assert.isInstanceOfType(died, DmlException.class, 'the run died on the refused write');
			}

			ScheduledJob__c failed = reload(row.Id);
			Assert.areEqual(0, recordedRunCount, 'the job never ran');
			Assert.areEqual(UTIL_ScheduledJobRunner.OUTCOME_FAILED, failed.LastRunOutcome__c, 'the run never marked its outcome written, so the Finalizer recorded Failed');
			Assert.isNull(failed.LastRunReason__c, 'a failure carries no reason');
			List<LogEntry__c> entries = runLogEntries();
			Assert.areEqual(1, entries.size(), 'one ERROR entry accounts for the run');
			Assert.areEqual(LoggingLevel.ERROR.name(), entries[0].LogLevel__c, 'at ERROR');
			Assert.areEqual(row.Id, entries[0].RecordId__c, 'against the record it was about');
		}
	}

	/**
	 * @description Tests that a record moved off the runner to its own scheduled job after its run was queued is skipped
	 * when the run starts, and that the framework's own write does not disturb the platform job the move created.
	 */
	@IsTest
	private static void aRecordMovedToOwnModeBetweenTheCheckAndTheRunStartIsSkippedAndKeepsItsOwnPlatformJob()
	{
		System.runAs(getManagingAdmin())
		{
			enableTheRunner();
			ScheduledJob__c row = insertRow('moved', CHECK_TIME, null, UTIL_ScheduledJobRunner.OVERLAP_POLICY_SKIP, RecordingJob.class.getName());
			TRG_Base.bypass(ScheduledJob__c.SObjectType);
			DML_Builder.newTransaction().doUpdate(new ScheduledJob__c(Id = row.Id, CronExpression__c = DAILY_AT_THREE)).execute();
			TRG_Base.clearBypass(ScheduledJob__c.SObjectType);

			Test.startTest();
			UTIL_ScheduledJobRunner.checkForDueJobs(CHECK_TIME);
			DML_Builder.newTransaction().doUpdate(new ScheduledJob__c(Id = row.Id, ExecutionMode__c = UTIL_ScheduledJobRunner.EXECUTION_MODE_OWN_SCHEDULED_JOB)).execute();
			String ownModeCronTrigger = reload(row.Id).ScheduledJobId__c;
			Assert.isNotNull(ownModeCronTrigger, 'the switch to own mode scheduled a CronTrigger');
			Test.stopTest();

			ScheduledJob__c after = reload(row.Id);
			Assert.areEqual(0, recordedRunCount, 'the run found the record off the runner and did not run it');
			Assert.areEqual(UTIL_ScheduledJobRunner.OUTCOME_SKIPPED, after.LastRunOutcome__c, 'Skipped');
			Assert.areEqual(ownModeCronTrigger, after.ScheduledJobId__c, 'the framework write did not re-schedule the own-mode record');
		}
	}

	/**
	 * @description Tests the shipped recurring-chain recipe: a job on the runner may build an async chain from inside its
	 * run, and the platform accepts that chain.
	 */
	@IsTest
	private static void aJobOnTheRunnerMayBuildAChainAndTheChainRuns()
	{
		System.runAs(getManagingAdmin())
		{
			enableTheRunner();
			TST_Factory.newFeatureFlag(UTIL_AsyncChain.FEATURE_FLAG_NAME);
			ScheduledJob__c row = insertRow('chains', CHECK_TIME, null, UTIL_ScheduledJobRunner.OVERLAP_POLICY_SKIP, ChainBuildingJob.class.getName());

			Test.startTest();
			UTIL_ScheduledJobRunner.checkForDueJobs(CHECK_TIME);
			Test.stopTest();

			Assert.areEqual(UTIL_ScheduledJobRunner.OUTCOME_SUCCEEDED, reload(row.Id).LastRunOutcome__c, 'the job succeeded');
			Assert.isNotNull(recordedChainExecutionId, 'the job launched a chain from inside the run');
			AsyncChainExecution__c chain = (AsyncChainExecution__c)new SEL_AsyncChainExecution().findById(Id.valueOf(recordedChainExecutionId));
			String launchFailure = 'the chain was accepted by the platform and did not fail on launch: ' + chain.ErrorMessage__c;
			Assert.areNotEqual(SEL_AsyncChainExecution.STATUS_FAILED, chain.Status__c, launchFailure);
		}
	}

	/**
	 * @description Tests both sharing dials at once: a manager who holds the job runner permission but owns none of the
	 * records still claims and stamps them at the check, and the Finalizer writes the outcome on a row they do not own.
	 */
	@IsTest
	private static void aCheckRunByAUserWithoutModifyAllStillClaimsAndStampsRowsItDoesNotOwn()
	{
		ScheduledJob__c row;
		System.runAs(getManagingAdmin())
		{
			row = insertDueRow('owned by the managing admin');
		}
		System.runAs(getLowPrivilegeManager())
		{
			enableTheRunner();
			Test.startTest();
			UTIL_ScheduledJobRunner.CheckResult result = UTIL_ScheduledJobRunner.checkForDueJobs(CHECK_TIME);
			Test.stopTest();

			Assert.areEqual(1, result.started, 'a manager who owns no rows still claims and stamps them');
			Assert.areEqual(UTIL_ScheduledJobRunner.OUTCOME_SUCCEEDED, reload(row.Id).LastRunOutcome__c, 'and the Finalizer wrote the outcome on a row it does not own');
		}
	}

	/**
	 * @description Tests that the Kern Job Runner Management set is enough on its own: a standard user holding nothing
	 * else edits the settings of a job they own, through the trigger, in user mode.
	 */
	@IsTest
	private static void aHolderOfTheJobRunnerSetAloneEditsTheSettingsOfAJobTheyOwn()
	{
		System.runAs(getLowPrivilegeManager())
		{
			ScheduledJob__c row = insertRow('edited by its manager', CHECK_TIME, null, UTIL_ScheduledJobRunner.OVERLAP_POLICY_SKIP, RecordingJob.class.getName());
			String description = UTIL_Random.randomDescription();

			Test.startTest();
			DML_Builder.newTransaction().doUpdate(new ScheduledJob__c(Id = row.Id, Description__c = description, RunPriority__c = EDITED_RUN_PRIORITY)).execute();
			Test.stopTest();

			ScheduledJob__c after = reload(row.Id);
			Assert.areEqual(description, after.Description__c, 'the description is a field the set lets a manager edit');
			Assert.areEqual(EDITED_RUN_PRIORITY, after.RunPriority__c, 'and so is the run priority');
		}
	}

	/**
	 * @description Tests that the Kern Job Runner Management set does not let its holder delete a job, even one they
	 * own: switching a job off is how a manager removes it, and deleting stays with the Kern Administrator set.
	 */
	@IsTest
	private static void aHolderOfTheJobRunnerSetAloneCannotDeleteAJobTheyOwn()
	{
		System.runAs(getLowPrivilegeManager())
		{
			ScheduledJob__c row = insertRow('not deletable by its manager', CHECK_TIME, null, UTIL_ScheduledJobRunner.OVERLAP_POLICY_SKIP, RecordingJob.class.getName());

			Test.startTest();
			try
			{
				DML_Builder.newTransaction().doDelete(row).execute();
				Assert.fail('the set grants no delete, so a user-mode delete must be refused');
			}
			catch(TypeException refusal)
			{
				Assert.isNotNull(reload(row.Id), 'the row is still there');
			}
			Test.stopTest();
		}
	}

	/**
	 * @description Tests that the Kern Job Runner Management set gives its holder the run-stamp fields to read, never to
	 * write: only the runner records how a run went.
	 */
	@IsTest
	private static void aHolderOfTheJobRunnerSetAloneCannotWriteARunStamp()
	{
		System.runAs(getLowPrivilegeManager())
		{
			ScheduledJob__c row = insertRow('stamps are the runner\'s', CHECK_TIME, null, UTIL_ScheduledJobRunner.OVERLAP_POLICY_SKIP, RecordingJob.class.getName());

			Test.startTest();
			try
			{
				DML_Builder.newTransaction().doUpdate(new ScheduledJob__c(Id = row.Id, LastRunOutcome__c = UTIL_ScheduledJobRunner.OUTCOME_SUCCEEDED)).execute();
				Assert.fail('the run stamps are read-only in the set, so a user-mode write must be refused');
			}
			catch(DmlException refusal)
			{
				String stampField = UTIL_SObjectDescribe.getCachedFieldName(ScheduledJob__c.LastRunOutcome__c);
				Assert.isTrue(refusal.getDmlFieldNames(0).contains(stampField), 'the refusal names the stamp field: ' + refusal.getMessage());
				Assert.isNull(reload(row.Id).LastRunOutcome__c, 'nothing was stamped');
			}
			Test.stopTest();
		}
	}

	/**
	 * @description Tests that the platform job id being read-only in the Kern Job Runner Management set does not stop its
	 * holder moving a job to its own scheduled job: the trigger schedules it and writes the id on the record as it saves.
	 */
	@IsTest
	private static void aHolderOfTheJobRunnerSetAloneMovesAJobToItsOwnScheduledJobAndTheTriggerWritesItsId()
	{
		System.runAs(getLowPrivilegeManager())
		{
			ScheduledJob__c row = insertRow('moved to its own job by its manager', CHECK_TIME, null, UTIL_ScheduledJobRunner.OVERLAP_POLICY_SKIP, RecordingJob.class.getName());

			Test.startTest();
			// Salesforce refuses a step in the minutes field of a platform schedule, so the move takes the daily expression too.
			String ownMode = UTIL_ScheduledJobRunner.EXECUTION_MODE_OWN_SCHEDULED_JOB;
			ScheduledJob__c moved = new ScheduledJob__c(Id = row.Id, ExecutionMode__c = ownMode, CronExpression__c = DAILY_AT_THREE);
			DML_Builder.newTransaction().doUpdate(moved).execute();
			Test.stopTest();

			Assert.isNotNull(reload(row.Id).ScheduledJobId__c, 'the trigger wrote the platform job id the set does not let the manager write');
		}
	}

	/**
	 * @description Tests Run now on an ordinary job: it starts the run, stamps the run id in the same transaction, runs as
	 * the person who pressed it, and leaves the schedule's own next run time exactly where it was.
	 */
	@IsTest
	private static void runNowStartsTheRunStampsTheIdRunsAsThePresserAndNeverMovesTheCursor()
	{
		System.runAs(getManagingAdmin())
		{
			enableTheRunner();
			ScheduledJob__c row = insertRow('run now', CHECK_TIME.addHours(3), null, UTIL_ScheduledJobRunner.OVERLAP_POLICY_SKIP, RecordingJob.class.getName());

			Test.startTest();
			Id runJobId = UTIL_ScheduledJobRunner.runNow(row.Id);
			Assert.areEqual(runJobId, Id.valueOf(reload(row.Id).LastRunJobId__c), 'the stamp is the returned id, in the same transaction');
			Test.stopTest();

			ScheduledJob__c after = reload(row.Id);
			Assert.areEqual(CHECK_TIME.addHours(3), after.NextRunAt__c, 'Run now never moves the cursor');
			Assert.areEqual(UTIL_ScheduledJobRunner.OUTCOME_SUCCEEDED, after.LastRunOutcome__c, 'the run recorded its outcome');
			Assert.areEqual(getManagingAdmin().Id, recordedRunningUserId, 'the run executed as the person who pressed it');
		}
	}

	/**
	 * @description Tests that Run now applies the overlap policy the same way a check does: under Skip it refuses while
	 * the previous run is still live and leaves the record alone, under Allow it starts anyway.
	 */
	@IsTest
	private static void runNowRefusesUnderSkipWhileThePreviousRunIsLiveAndProceedsUnderAllow()
	{
		System.runAs(getManagingAdmin())
		{
			enableTheRunner();
			ScheduledJob__c skipping = insertRow('skip now', CHECK_TIME, null, UTIL_ScheduledJobRunner.OVERLAP_POLICY_SKIP, RecordingJob.class.getName());
			ScheduledJob__c allowing = insertRow('allow now', CHECK_TIME, null, UTIL_ScheduledJobRunner.OVERLAP_POLICY_ALLOW, RecordingJob.class.getName());

			Test.startTest();
			Id liveJobId = stampBothRowsWithALiveRun(skipping, allowing);
			try
			{
				UTIL_ScheduledJobRunner.runNow(skipping.Id);
				Assert.fail('Run now must refuse while the previous run is live under Skip');
			}
			catch(IllegalArgumentException refusal)
			{
				Assert.areEqual(System.Label.ScheduledJob_RunNowRefusedPreviousRunLive, refusal.getMessage(), 'the refusal is the label');
			}
			Id allowedRun = UTIL_ScheduledJobRunner.runNow(allowing.Id);
			Test.stopTest();

			Assert.areEqual(liveJobId, Id.valueOf(reload(skipping.Id).LastRunJobId__c), 'the refused row is untouched');
			Assert.areEqual(allowedRun, Id.valueOf(reload(allowing.Id).LastRunJobId__c), 'Allow proceeded and stamped');
		}
	}

	/**
	 * @description Tests the one case where a check gives up on everything rather than lose a run time: the stamp could
	 * not be written and the run just queued could not be called off either, because calling off a job needs Modify All
	 * Data and this user does not have it. The check throws, which in a real transaction discards the queued run along
	 * with every write, so no run is ever left going without its run time having been consumed. The test has to catch
	 * that to assert on it, so the row is read before the queued run is let go. The check still leaves one ERROR entry
	 * behind, naming the row whose write was refused and the run it could not call off, because an entry emitted before
	 * the throw is published at once and outlives the rollback: it is the only account a subscriber has of what
	 * happened.
	 */
	@IsTest
	private static void aStampWriteThatFailsForAUserWhoCannotCallOffTheRunThrowsSoTheCheckRollsBack()
	{
		ScheduledJob__c row;
		System.runAs(getManagingAdmin())
		{
			row = insertDueRow('stamp fails, run not called off');
		}
		System.runAs(getLowPrivilegeManager())
		{
			enableTheRunner();
			Test.startTest();
			UTIL_ScheduledJobRunner.simulateRowWriteFailure = true;
			try
			{
				UTIL_ScheduledJobRunner.checkForDueJobs(CHECK_TIME);
				Assert.fail('the stamp was refused and the run could not be called off, so the check must not return as if nothing were wrong');
			}
			catch(Exception rolledBack)
			{
				Assert.isInstanceOfType(rolledBack, UTIL_Exceptions.IllegalStateException.class, 'the check throws, so the whole transaction goes back');
			}
			ScheduledJob__c unchanged = reload(row.Id);
			Assert.areEqual(CHECK_TIME, unchanged.NextRunAt__c, 'the row keeps its run time, so it is due again at the next check');
			Assert.isNull(unchanged.LastRunJobId__c, 'and carries no stamp');
			Assert.isNull(unchanged.LastRunOutcome__c, 'and nothing was recorded on it');
			Test.stopTest();
		}
		System.runAs(getManagingAdmin())
		{
			List<LogEntry__c> entries = checkLogEntries();
			Assert.areEqual(1, entries.size(), 'the check left exactly one account: the row it could not write and the run it could not call off');
			Assert.areEqual(LoggingLevel.ERROR.name(), entries[0].LogLevel__c, 'at ERROR');
			Assert.areEqual(row.Id, entries[0].RecordId__c, 'against the row whose write was refused');
			Assert.isTrue(entries[0].ShortMessage__c.contains('could not be aborted'), 'and it says the run could not be called off');
		}
	}

	/**
	 * @description Tests that when the record cannot be stamped after Run now has queued its run, the queued run is
	 * called off, the caller is told what went wrong, and the record is left exactly as it was.
	 */
	@IsTest
	private static void runNowWhoseStampCannotBeWrittenAbortsTheRunAndTellsTheCaller()
	{
		System.runAs(getManagingAdmin())
		{
			enableTheRunner();
			ScheduledJob__c row = insertRow('run now write fails', CHECK_TIME.addHours(3), null, UTIL_ScheduledJobRunner.OVERLAP_POLICY_SKIP, RecordingJob.class.getName());

			Test.startTest();
			UTIL_ScheduledJobRunner.simulateRowWriteFailure = true;
			try
			{
				UTIL_ScheduledJobRunner.runNow(row.Id);
				Assert.fail('the stamp could not be written, so Run now must not report a run');
			}
			catch(Exception writeError)
			{
				Assert.isInstanceOfType(writeError, DmlException.class, 'the caller is told what went wrong');
			}
			Test.stopTest();

			ScheduledJob__c unchanged = reload(row.Id);
			Assert.areEqual(0, recordedRunCount, 'the queued run was called off and never executed');
			Assert.isNull(unchanged.LastRunJobId__c, 'no stamp');
			Assert.isNull(unchanged.LastRunOutcome__c, 'and nothing was recorded on the record');
			Assert.areEqual(CHECK_TIME.addHours(3), unchanged.NextRunAt__c, 'Run now never touched the cursor');
		}
	}

	/**
	 * @description Tests that a Finalizer which cannot write the outcome says so in the log rather than losing the
	 * account of the run altogether: the Log Console is authoritative when a record and its log disagree.
	 */
	@IsTest
	private static void aFinalizerWhoseOwnWriteFailsAccountsForTheRunInTheLog()
	{
		System.runAs(getManagingAdmin())
		{
			enableTheRunner();
			ScheduledJob__c row = insertRow('outcome write fails', CHECK_TIME.addHours(3), null, UTIL_ScheduledJobRunner.OVERLAP_POLICY_SKIP, RecordingJob.class.getName());

			Test.startTest();
			UTIL_ScheduledJobRunner.runNow(row.Id);
			UTIL_ScheduledJobRunner.simulateRowWriteFailure = true;
			Test.stopTest();

			Assert.areEqual(1, recordedRunCount, 'the job itself ran');
			Assert.isNull(reload(row.Id).LastRunOutcome__c, 'but its outcome could not be written');
			List<LogEntry__c> entries = runLogEntries();
			Assert.areEqual(1, entries.size(), 'one entry accounts for the run whose outcome was lost');
			Assert.areEqual(LoggingLevel.ERROR.name(), entries[0].LogLevel__c, 'at ERROR');
			Assert.areEqual(row.Id, entries[0].RecordId__c, 'linked to the record it was about');
			String outcomeThatWasLost = UTIL_ScheduledJobRunner.OUTCOME_SUCCEEDED;
			Assert.isTrue(entries[0].ShortMessage__c.contains(outcomeThatWasLost), 'and the entry says which outcome could not be written, so it stands on its own');
		}
	}

	/**
	 * @description Tests that Run now is for active jobs on the runner only, and only for a user who holds the Manage Job
	 * Runner permission: a record on its own scheduled job, an inactive record and an unpermitted caller are each refused
	 * with the words the subscriber sees.
	 */
	@IsTest
	private static void runNowRefusesOwnModeInactiveAndUnpermittedCallers()
	{
		ScheduledJob__c ownMode;
		ScheduledJob__c inactive;
		ScheduledJob__c onRunner;
		System.runAs(getManagingAdmin())
		{
			enableTheRunner();
			ownMode = insertRow('own', CHECK_TIME, null, UTIL_ScheduledJobRunner.OVERLAP_POLICY_SKIP, RecordingJob.class.getName());
			TRG_Base.bypass(ScheduledJob__c.SObjectType);
			DML_Builder.newTransaction().doUpdate(new ScheduledJob__c(Id = ownMode.Id, ExecutionMode__c = UTIL_ScheduledJobRunner.EXECUTION_MODE_OWN_SCHEDULED_JOB)).execute();
			inactive = insertRow('inactive', CHECK_TIME, null, UTIL_ScheduledJobRunner.OVERLAP_POLICY_SKIP, RecordingJob.class.getName());
			DML_Builder.newTransaction().doUpdate(new ScheduledJob__c(Id = inactive.Id, IsActive__c = false)).execute();
			TRG_Base.clearBypass(ScheduledJob__c.SObjectType);
			onRunner = insertDueRow('on runner');

			for(Id refusedId : new List<Id> {ownMode.Id, inactive.Id})
			{
				try
				{
					UTIL_ScheduledJobRunner.runNow(refusedId);
					Assert.fail('Run now is for active job-runner records only: ' + refusedId);
				}
				catch(IllegalArgumentException refusal)
				{
					Assert.areEqual(System.Label.ScheduledJob_RunNowOnlyForJobRunnerRecords, refusal.getMessage(), 'the refusal is the label');
				}
			}
		}
		System.runAs(getUserWithoutJobRunnerPermission())
		{
			try
			{
				UTIL_ScheduledJobRunner.runNow(onRunner.Id);
				Assert.fail('Run now needs the permission');
			}
			catch(IllegalArgumentException refusal)
			{
				Assert.areEqual(System.Label.ScheduledJob_RunNowPermissionRequired, refusal.getMessage(), 'the refusal is the label');
			}
		}
	}

	/**
	 * @description Tests that Run now honours the switch that turns the whole job runner off: with the runner switched
	 * off it refuses in the words the subscriber sees, starts nothing and leaves the record exactly as it was, so an
	 * administrator who switches the runner off during an incident has stopped Run now as well as the checks.
	 */
	@IsTest
	private static void runNowIsRefusedWhileTheRunnerIsSwitchedOff()
	{
		System.runAs(getManagingAdmin())
		{
			disableTheRunner();
			ScheduledJob__c row = insertDueRow('runner switched off');

			Test.startTest();
			try
			{
				UTIL_ScheduledJobRunner.runNow(row.Id);
				Assert.fail('Run now must refuse while the runner is switched off');
			}
			catch(IllegalArgumentException refusal)
			{
				Assert.areEqual(System.Label.ScheduledJob_RunNowRefusedRunnerOff, refusal.getMessage(), 'the refusal is the label');
			}
			Test.stopTest();

			ScheduledJob__c unchanged = reload(row.Id);
			Assert.areEqual(0, recordedRunCount, 'no run was started');
			Assert.isNull(unchanged.LastRunJobId__c, 'nothing was stamped on the record');
			Assert.areEqual(CHECK_TIME, unchanged.NextRunAt__c, 'and its next run time is where it was');
		}
	}

	/**
	 * @description A job that counts its runs and remembers the context it was given, so a run can be proven to have
	 * happened and to have received a Kern run context.
	 */
	public class RecordingJob implements Schedulable
	{
		/**
		 * @description Records that this run happened and what it was given.
		 *
		 * @param context The scheduling context the runner handed it.
		 */
		public void execute(SchedulableContext context)
		{
			recordedRunCount++;
			recordedTriggerId = context?.getTriggerId();
			recordedRunningUserId = UserInfo.getUserId();
		}
	}

	/**
	 * @description A Queueable that does nothing: it holds a live platform job for the overlap tests and spends the
	 * Queueable allowance for the check-limit test. A fixture that does nothing has no outcome to record, so it needs no
	 * Finalizer.
	 */
	@SuppressWarnings('PMD.QueueableWithoutFinalizer')
	public class NoOperationJob implements Queueable
	{
		/**
		 * @description Does nothing at all.
		 *
		 * @param context The platform's Queueable context; not read.
		 */
		public void execute(QueueableContext context)
		{
			return;
		}
	}

	/**
	 * @description A job that fails with a card number in its message, to prove the message is masked before it is stored.
	 */
	public class CardLeakingJob implements Schedulable
	{
		/**
		 * @description Throws, carrying a card number and a phrase that is safe to keep.
		 *
		 * @param context The scheduling context the runner handed it; not read.
		 */
		public void execute(SchedulableContext context)
		{
			throw new UTIL_Exceptions.IllegalStateException('This job ' + DELIBERATE_FAILURE_PHRASE + ' while holding card ' + CARD_NUMBER);
		}
	}

	/**
	 * @description A job that builds a one-step chain, the shipped recurring-chain recipe under the runner.
	 */
	public class ChainBuildingJob extends SCHED_Base
	{
		/**
		 * @description Launches a one-step chain and remembers which chain it launched.
		 *
		 * @param context The scheduling context the runner handed it; not read.
		 */
		public void execute(SchedulableContext context)
		{
			recordedChainExecutionId = UTIL_AsyncChain.newChain(CHAIN_NAME).then(new SuccessStep()).execute();
		}
	}

	/**
	 * @description A chain step that does nothing but succeed, so the chain the fixture job launches has something to run.
	 * UTIL_AsyncChain_TEST declares the same fixture, but that class is a private test class, so its inner classes cannot
	 * be reached from here.
	 */
	public class SuccessStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Succeeds.
		 *
		 * @param context The shared chain context; not read.
		 *
		 * @return A succeeded result.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			return UTIL_AsyncChain.succeeded('Step completed');
		}
	}
}
