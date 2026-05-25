// Section 21: Scheduler Framework — SCHED_Base + Parameters
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Prerequisites:
//   - kern managed package installed
//   - SCHED_SubscriberJob class deployed
//
// Tests the subscriber scheduler framework: extending SCHED_Base, parameter
// definitions, typed parameter resolution, and the DTO_ScheduledParameterDefinition
// fluent builder API.
//
// Run:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-21-scheduler.apex

try
{
	// Test 21a: DTO_ScheduledParameterDefinition — fluent builder API (TEXT)
	// NOTE: DTO properties (name, label, dataType, etc.) are public not global —
	// subscribers cannot access them directly. Using JSON serialization to verify.
	{
		kern.DTO_ScheduledParameterDefinition textParam = kern.DTO_ScheduledParameterDefinition.of('objectName')
				.required()
				.withDescription('API name of the SObject');

		System.assert(textParam != null, '21a FAIL: Should create parameter definition');
		String json = JSON.serialize(textParam);
		System.assert(json.contains('"name":"objectName"'), '21a FAIL: JSON should contain name=objectName');
		System.assert(json.contains('"isRequired":true'), '21a FAIL: JSON should contain isRequired=true');
		System.assert(json.contains('"dataType":"TEXT"'), '21a FAIL: JSON should contain dataType=TEXT');
		System.assert(json.contains('"description":"API name of the SObject"'), '21a FAIL: JSON should contain description');
		System.debug('21a PASS: DTO_ScheduledParameterDefinition fluent builder — TEXT parameter');
	}

	// Test 21b: DTO_ScheduledParameterDefinition — NUMERIC type with default
	{
		kern.DTO_ScheduledParameterDefinition numericParam = kern.DTO_ScheduledParameterDefinition.of('batchSize', 'Batch Size')
				.asNumeric()
				.withDefault('2000');

		String json = JSON.serialize(numericParam);
		System.assert(json.contains('"dataType":"NUMERIC"'), '21b FAIL: Should be NUMERIC');
		System.assert(json.contains('"defaultValue":"2000"'), '21b FAIL: Default should be 2000');
		System.assert(json.contains('"label":"Batch Size"'), '21b FAIL: Label should be Batch Size');
		System.assert(json.contains('"isRequired":false'), '21b FAIL: Should not be required by default');
		System.debug('21b PASS: DTO_ScheduledParameterDefinition — NUMERIC with default and explicit label');
	}

	// Test 21c: DTO_ScheduledParameterDefinition — FLAG (boolean) type
	{
		kern.DTO_ScheduledParameterDefinition boolParam = kern.DTO_ScheduledParameterDefinition.of('dryRun')
				.asBoolean()
				.withDefault('false')
				.withDescription('Run without committing');

		String json = JSON.serialize(boolParam);
		System.assert(json.contains('"dataType":"FLAG"'), '21c FAIL: Should be FLAG');
		System.assert(json.contains('"defaultValue":"false"'), '21c FAIL: Default should be false');
		System.debug('21c PASS: DTO_ScheduledParameterDefinition — FLAG type');
	}

	// Test 21d: DTO_ScheduledParameterDefinition — camelCase auto-label
	{
		kern.DTO_ScheduledParameterDefinition param = kern.DTO_ScheduledParameterDefinition.of('profileNames');

		String json = JSON.serialize(param);
		System.assert(json.contains('"label":"Profile Names"'), '21d FAIL: Auto-label should be "Profile Names"');
		System.debug('21d PASS: camelCase to label conversion (profileNames → Profile Names)');
	}

	// Test 21e: SCHED_SubscriberJob — parameter definitions
	{
		SCHED_SubscriberJob job = new SCHED_SubscriberJob();
		List<kern.DTO_ScheduledParameterDefinition> params = job.getParameterDefinitions();

		System.assert(params.size() == 3, '21e FAIL: Should have 3 parameter definitions, got: ' + params.size());
		String json = JSON.serialize(params);
		System.assert(json.contains('"name":"objectName"'), '21e FAIL: Should contain objectName param');
		System.assert(json.contains('"name":"batchSize"'), '21e FAIL: Should contain batchSize param');
		System.assert(json.contains('"name":"dryRun"'), '21e FAIL: Should contain dryRun param');
		System.debug('21e PASS: SCHED_SubscriberJob returns 3 parameter definitions');
	}

	// Test 21f: SCHED_SubscriberJob — setParameterValues + execute with partial params
	{
		SCHED_SubscriberJob job = new SCHED_SubscriberJob();
		SCHED_SubscriberJob.executed = false;

		kern.DTO_NameValues values = new kern.DTO_NameValues();
		values.add('objectName', 'Account');
		job.setParameterValues(values);
		job.execute(null);

		System.assert(SCHED_SubscriberJob.executed == true, '21f FAIL: execute() should have run');
		System.assert(SCHED_SubscriberJob.resolvedObjectName == 'Account', '21f FAIL: objectName should be Account, got: ' + SCHED_SubscriberJob.resolvedObjectName);
		System.debug('21f PASS: setParameterValues + execute with partial parameters');
	}

	// Test 21g: SCHED_SubscriberJob — setParameterValues + execute with all params
	{
		SCHED_SubscriberJob job = new SCHED_SubscriberJob();
		SCHED_SubscriberJob.executed = false;

		kern.DTO_NameValues values = new kern.DTO_NameValues();
		values.add('objectName', 'Contact');
		values.add('batchSize', '500');
		values.add('dryRun', 'true');
		job.setParameterValues(values);
		job.execute(null);

		System.assert(SCHED_SubscriberJob.executed == true, '21g FAIL: execute() should have run');
		System.assert(SCHED_SubscriberJob.resolvedObjectName == 'Contact', '21g FAIL: objectName should be Contact');
		System.assert(SCHED_SubscriberJob.resolvedBatchSize == 500, '21g FAIL: batchSize should be 500, got: ' + SCHED_SubscriberJob.resolvedBatchSize);
		System.assert(SCHED_SubscriberJob.resolvedDryRun == true, '21g FAIL: dryRun should be true');

		System.debug('21g PASS: All parameters provided — TEXT=Contact, NUMERIC=500, FLAG=true');
	}

	// Test 21h: IF_Schedulable interface — verify via Object cast
	{
		Object job = (Object)new SCHED_SubscriberJob();
		System.assert(job instanceof kern.IF_Schedulable, '21h FAIL: SCHED_SubscriberJob should implement IF_Schedulable');
		System.assert(job instanceof Schedulable, '21h FAIL: SCHED_SubscriberJob should implement Schedulable');
		System.debug('21h PASS: SCHED_SubscriberJob implements IF_Schedulable and Schedulable');
	}

	System.debug('=== Section 21 COMPLETE: All Scheduler Framework tests passed ===');
}
catch(Exception error)
{
	System.debug('Section 21 ERROR: ' + error.getMessage());
	System.debug('Stack trace: ' + error.getStackTraceString());
}
