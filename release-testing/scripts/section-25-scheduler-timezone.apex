// Section 25: Scheduler Timezone Awareness
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Prerequisites:
//   - kern managed package installed
//   - SCHED_SubscriberJob class deployed
//
// Tests that the Timezone__c field on ScheduledJob__c is accessible from
// subscriber context, persists correctly, and that scheduling works with
// and without a timezone value.
//
// Run:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-25-scheduler-timezone.apex

try
{
	// Test 25a: Timezone__c field is writable on ScheduledJob__c
	{
		kern__ScheduledJob__c job = new kern__ScheduledJob__c();
		job.kern__SchedulerName__c = 'TZ Test 25a';
		job.kern__ClassName__c = 'SCHED_SubscriberJob';
		job.kern__CronExpression__c = '0 0 14 * * ?';
		job.kern__IsActive__c = false;
		job.kern__Timezone__c = 'Africa/Johannesburg';
		insert job;

		kern__ScheduledJob__c result =
		[
				SELECT kern__Timezone__c
				FROM kern__ScheduledJob__c
				WHERE Id = :job.Id
		];
		System.assert(result.kern__Timezone__c == 'Africa/Johannesburg',
				'25a FAIL: Timezone__c should persist, got: ' + result.kern__Timezone__c);
		delete job;
		System.debug('25a PASS: Timezone__c field is writable and persists on ScheduledJob__c');
	}

	// Test 25b: Scheduling works with Timezone__c populated (matching timezone — no shift)
	{
		String userTz = UserInfo.getTimeZone().getID();
		kern__ScheduledJob__c job = new kern__ScheduledJob__c();
		job.kern__SchedulerName__c = 'TZ Test 25b';
		job.kern__ClassName__c = 'kern.SCHED_ProcessLoginHistory';
		job.kern__CronExpression__c = '0 0 14 * * ?';
		job.kern__IsActive__c = true;
		job.kern__Timezone__c = userTz;
		insert job;

		kern__ScheduledJob__c result =
		[
				SELECT kern__ScheduledJobId__c,
						kern__Timezone__c
				FROM kern__ScheduledJob__c
				WHERE Id = :job.Id
		];
		System.assert(String.isNotBlank(result.kern__ScheduledJobId__c),
				'25b FAIL: Job should be scheduled (ScheduledJobId populated)');
		System.assert(result.kern__Timezone__c == userTz,
				'25b FAIL: Timezone should match running user');
		delete job;
		System.debug('25b PASS: Scheduling succeeds with matching timezone — ' + userTz);
	}

	// Test 25c: Scheduling works without Timezone__c (backward compatible)
	{
		kern__ScheduledJob__c job = new kern__ScheduledJob__c();
		job.kern__SchedulerName__c = 'TZ Test 25c';
		job.kern__ClassName__c = 'kern.SCHED_ProcessLoginHistory';
		job.kern__CronExpression__c = '0 0 14 * * ?';
		job.kern__IsActive__c = true;
		insert job;

		kern__ScheduledJob__c result =
		[
				SELECT kern__ScheduledJobId__c,
						kern__Timezone__c
				FROM kern__ScheduledJob__c
				WHERE Id = :job.Id
		];
		System.assert(String.isNotBlank(result.kern__ScheduledJobId__c),
				'25c FAIL: Job should be scheduled without timezone');
		System.assert(result.kern__Timezone__c == null,
				'25c FAIL: Timezone should remain null when not set');
		delete job;
		System.debug('25c PASS: Scheduling succeeds with null timezone (backward compatible)');
	}

	// Test 25d: Timezone__c survives activation/deactivation cycle
	{
		kern__ScheduledJob__c job = new kern__ScheduledJob__c();
		job.kern__SchedulerName__c = 'TZ Test 25d';
		job.kern__ClassName__c = 'kern.SCHED_ProcessLoginHistory';
		job.kern__CronExpression__c = '0 0 9 ? * MON-FRI';
		job.kern__IsActive__c = true;
		job.kern__Timezone__c = 'Australia/Brisbane';
		insert job;

		kern__ScheduledJob__c afterInsert =
		[
				SELECT kern__ScheduledJobId__c,
						kern__Timezone__c
				FROM kern__ScheduledJob__c
				WHERE Id = :job.Id
		];
		System.assert(String.isNotBlank(afterInsert.kern__ScheduledJobId__c),
				'25d FAIL: Job should be scheduled after insert');

		job.kern__IsActive__c = false;
		update job;

		kern__ScheduledJob__c afterDeactivate =
		[
				SELECT kern__ScheduledJobId__c,
						kern__Timezone__c
				FROM kern__ScheduledJob__c
				WHERE Id = :job.Id
		];
		System.assert(afterDeactivate.kern__Timezone__c == 'Australia/Brisbane',
				'25d FAIL: Timezone should persist after deactivation');

		job.kern__IsActive__c = true;
		update job;

		kern__ScheduledJob__c afterReactivate =
		[
				SELECT kern__ScheduledJobId__c,
						kern__Timezone__c
				FROM kern__ScheduledJob__c
				WHERE Id = :job.Id
		];
		System.assert(String.isNotBlank(afterReactivate.kern__ScheduledJobId__c),
				'25d FAIL: Job should be rescheduled after reactivation');
		System.assert(afterReactivate.kern__Timezone__c == 'Australia/Brisbane',
				'25d FAIL: Timezone should persist through activation cycle');
		delete job;
		System.debug('25d PASS: Timezone__c persists through activate/deactivate/reactivate cycle');
	}

	System.debug('=== Section 25 COMPLETE: All Scheduler Timezone tests passed ===');
}
catch(Exception error)
{
	System.debug('Section 25 ERROR: ' + error.getMessage());
	System.debug('Stack trace: ' + error.getStackTraceString());
}
