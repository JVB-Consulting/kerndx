// SPDX-License-Identifier: BUSL-1.1
const {test, expect} = require('@playwright/test');
const KernHomePage = require('../pages/kern-home.page');
const ScheduledJobsPage = require('../pages/scheduled-jobs.page');
const {navigateToApp} = require('../helpers/sf-navigation');
const {pollUntil} = require('../helpers/wait-helpers');
const {soqlQuery, executeAnonymousApex} = require('../helpers/sf-cli');
const {namespacePrefix, rewriteNamespaceLiterals} = require('../helpers/sf-namespace');
const {ORG_ALIAS, getFrontdoorUrlFor} = require('../helpers/sf-auth');
const {cleanupStepRunner, submitNewPassword} = require('../helpers/user-journey');
const {execSync} = require('child_process');
const {randomUUID} = require('crypto');
const {env} = require('process');

// Check names are the HealthCheck_JobRunner_*_CheckName label values.
const ORPHANED_CHECK_NAME = 'Jobs Waiting for the Job Runner';
const RUNNER_CLASS_NAME = 'kern.SCHED_JobRunner';
const PROBE_JOB_NAME = 'Job Runner Probe';
const PROBE_CLASS_NAME = 'SCHED_PurgeRecords';
// The Scheduled Jobs Fast Start's demo class, record name and switch, as the guide prints them.
const FAST_START_CLASS_NAME = 'FastStart_ScheduledJob_DEMO';
const FAST_START_JOB_NAME = 'Fast Start demo job';
const FAIL_ON_PURPOSE_PARAMETER = 'failOnPurpose';
// The labels Fast Start - Scheduled Jobs tells the reader to look for. A change here is a change to the guide.
const GUIDE_LABELS = {
	schedulerName: 'Scheduler Name', className: 'Class Name', executionMode: 'Execution mode', failOnPurpose: 'Fail on purpose',
	scheduledJobId: 'Scheduled Job Id', runNow: 'Run now', viewLog: 'View log'
};
// V139 leaves a dozen jobs waiting on the deactivated runner, not one: a count of one was never a volume proof.
const WAITING_PROBE_COUNT = 12;

// Object and field API names carry the package prefix only on the subscriber org. Anonymous Apex needs no helper:
// executeAnonymousApex rewrites its namespace literals for the org it runs on.
function prefixed(apiName)
{
	return `${namespacePrefix()}${apiName}`;
}

// A query written with the package's literals, as the org needs it: the rewrite anonymous Apex already gets.
function forOrg(query)
{
	return rewriteNamespaceLiterals(query, namespacePrefix());
}

// A permission set query's namespace filter: the package's namespace on a subscriber org, none on the development org.
function namespaceClause()
{
	const prefix = namespacePrefix();
	return prefix ? `NamespacePrefix = '${prefix.slice(0, -2)}'` : 'NamespacePrefix = NULL';
}

function probeParameters()
{
	return {objectName: prefixed('LogEntry__c'), minimumNumberOfDays: '9999', batchSize: '200'};
}

const runnerRecords = () => soqlQuery(forOrg('SELECT Id, kern__SchedulerName__c, kern__CronExpression__c, kern__ScheduledJobId__c '
		+ `FROM kern__ScheduledJob__c WHERE kern__ClassName__c = '${RUNNER_CLASS_NAME}' ORDER BY kern__CronExpression__c`));
const probeRecords = () => soqlQuery(forOrg('SELECT Id, kern__ExecutionMode__c, kern__IsActive__c, kern__NextRunAt__c, kern__LastRunAt__c, '
		+ 'kern__LastRunOutcome__c, kern__LastRunReason__c, kern__LastRunJobId__c '
		+ `FROM kern__ScheduledJob__c WHERE kern__SchedulerName__c = '${PROBE_JOB_NAME}'`));
const waitingProbeRecords = () => soqlQuery(forOrg('SELECT Id, kern__ExecutionMode__c '
		+ `FROM kern__ScheduledJob__c WHERE kern__SchedulerName__c LIKE '${PROBE_JOB_NAME} %'`));
const seedWaitingProbeRecords = () => executeAnonymousApex('List<kern__ScheduledJob__c> waiting = new List<kern__ScheduledJob__c>();'
		+ ` for(Integer index = 1; index <= ${WAITING_PROBE_COUNT}; index++) { waiting.add(new kern__ScheduledJob__c(`
		+ ` kern__SchedulerName__c = '${PROBE_JOB_NAME} ' + String.valueOf(index).leftPad(2, '0'), kern__ClassName__c = 'kern.${PROBE_CLASS_NAME}',`
		+ ' kern__CronExpression__c = \'0 */5 * * * ?\', kern__IsActive__c = true, kern__Timezone__c = \'UTC\', kern__ExecutionMode__c = \'JobRunner\','
		// Parameters__c holds a serialised kern.DTO_NameValues, so the pairs sit under nameValueMap.
		+ ` kern__Parameters__c = '{"nameValueMap":${JSON.stringify(probeParameters())}}')); } insert waiting;`);
// Covers both the single V140/V141 probe and V139's twelve, which carry a two-digit suffix.
const deleteProbeRecords = () => executeAnonymousApex(`delete [SELECT Id FROM kern__ScheduledJob__c WHERE kern__SchedulerName__c LIKE '${PROBE_JOB_NAME}%'];`);
const deleteRunnerRecords = () => executeAnonymousApex(`delete [SELECT Id FROM kern__ScheduledJob__c WHERE kern__ClassName__c = '${RUNNER_CLASS_NAME}'];`);
const fastStartRecords = () => soqlQuery(forOrg('SELECT Id, kern__ScheduledJobId__c, kern__ExecutionMode__c, kern__IsActive__c, kern__LastRunOutcome__c '
		+ `FROM kern__ScheduledJob__c WHERE kern__SchedulerName__c = '${FAST_START_JOB_NAME}'`));
const deleteFastStartRecords = () => executeAnonymousApex(`delete [SELECT Id FROM kern__ScheduledJob__c WHERE kern__SchedulerName__c = '${FAST_START_JOB_NAME}'];`);

// One cleanup step, run whatever happened before it; a failure is reported and never hides the journey's own.
const runCleanupStep = cleanupStepRunner('part11');

async function activateRunnerEveryFifteenMinutes(home)
{
	await expect(home.jobRunnerActivateButton(), 'an inactive runner offers Activate').toBeVisible();
	await home.jobRunnerActivateButton().click();
	await home.jobRunnerModalRoot().waitFor({state: 'visible', timeout: 15_000});
	await home.chooseJobRunnerCheckInterval('15');
	await home.confirmJobRunnerModal();
	await home.refreshHealthCheck();
}

test.describe.serial('Part 11: Job Runner', () =>
{
	test.beforeAll(() =>
	{
		// The journeys run as the e2e admin, who must hold ManageJobRunner: Activate, Run now and the check's own
		// entry refuse without it. The assignment is removed in afterAll so other parts see the shipped baseline.
		// Before the permission set ships, the journeys must still reach their own first assertion, so a missing
		// set is skipped rather than fatal.
		executeAnonymousApex(`List<PermissionSet> managing = [SELECT Id FROM PermissionSet WHERE Name = 'JobRunnerManagement' AND ${namespaceClause()} LIMIT 1];`
				+ ' if(!managing.isEmpty() && [SELECT COUNT() FROM PermissionSetAssignment WHERE AssigneeId = :UserInfo.getUserId() AND PermissionSetId = :managing[0].Id] == 0)'
				+ ' { insert new PermissionSetAssignment(AssigneeId = UserInfo.getUserId(), PermissionSetId = managing[0].Id); }');
		deleteProbeRecords();
		deleteRunnerRecords();
	});

	test.afterAll(() =>
	{
		deleteProbeRecords();
		deleteRunnerRecords();
		executeAnonymousApex('for(CronTrigger trigger_x : [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name LIKE \'V14% Job Runner%\']) { System.abortJob(trigger_x.Id); }');
		executeAnonymousApex('delete [SELECT Id FROM PermissionSetAssignment WHERE AssigneeId = :UserInfo.getUserId() AND PermissionSet.Name = \'JobRunnerManagement\''
				+ ` AND PermissionSet.${namespaceClause()}];`);
	});

	test('V139: Job runner — Activate every 15 minutes, Deactivate flags a waiting job, Repair restores the set', async({page}) =>
	{
		test.setTimeout(300_000);
		const pageErrors = [];
		page.on('pageerror', (error) => pageErrors.push(String(error.message)));

		await navigateToApp(page, 'Kern');
		const home = new KernHomePage(page);
		await home.navigate();
		await expect(home.jobRunnerCard(), 'the job runner card renders beneath the readiness banner').toBeVisible();
		await expect(home.jobRunnerActivateButton(), 'an inactive runner offers Activate').toBeVisible();

		await activateRunnerEveryFifteenMinutes(home);

		const summary = await home.jobRunnerSummary().textContent();
		expect(summary, 'the card names the check interval').toContain('every 15 minutes');
		expect(summary, 'the card names the slot cost').toContain('using 4 of the org');
		expect(await home.jobRunnerActivator().textContent(), 'the card names who the jobs run as').toContain('Runs jobs as');
		expect(await home.jobRunnerSlots().textContent(), 'the slot breakdown counts the runner').toMatch(/4 for the job runner/);

		const created = runnerRecords();
		expect(created.map((row) => row[prefixed('SchedulerName__c')]), 'four runner records, one per minute mark')
		.toEqual(['Job runner :00', 'Job runner :15', 'Job runner :30', 'Job runner :45']);
		expect(created.every((row) => Boolean(row[prefixed('ScheduledJobId__c')])), 'every runner record owns a platform job').toBe(true);
		const liveTriggers = soqlQuery(`SELECT Id FROM CronTrigger WHERE Id IN ('${created.map((row) => row[prefixed('ScheduledJobId__c')]).join('\',\'')}')`);
		expect(liveTriggers.length, 'four live CronTriggers').toBe(4);

		// A dozen job-runner jobs wait on the runner; Deactivate must leave them all in place and flag them.
		seedWaitingProbeRecords();

		await home.jobRunnerDeactivateButton().click();
		await home.confirmDeactivate();
		await home.refreshUntilHealthCheckPosture(ORPHANED_CHECK_NAME, 'warn');
		expect(runnerRecords().length, 'Deactivate removes every runner record').toBe(0);
		const waiting = waitingProbeRecords();
		expect(waiting.length, 'every job-runner job is left alone').toBe(WAITING_PROBE_COUNT);
		expect(waiting.every((row) => row[prefixed('ExecutionMode__c')] === 'JobRunner'), 'they all still point at the runner').toBe(true);
		const orphaned = (await home.getHealthCheckActionItems()).find((item) => item.name === ORPHANED_CHECK_NAME);
		expect(orphaned?.detail, 'the waiting check counts every one of them').toContain(`${WAITING_PROBE_COUNT} waiting`);

		// With no runner left, the card offers Activate and no Repair, and the waiting-jobs row's own button activates a
		// runner: it opens the check interval picker.
		await expect(home.jobRunnerRepairButton(), 'an inactive runner offers no Repair').toHaveCount(0);
		await expect(home.jobRunnerActivateButton(), 'an inactive runner offers Activate').toBeVisible();
		await home.healthCheckActionButton(ORPHANED_CHECK_NAME).click();
		await home.jobRunnerModalRoot().waitFor({state: 'visible', timeout: 15_000});
		await home.chooseJobRunnerCheckInterval('15');
		await home.confirmJobRunnerModal();
		await home.refreshUntilHealthCheckPosture(ORPHANED_CHECK_NAME, 'pass');
		expect(runnerRecords().length, 'Activate from the waiting-jobs row re-creates the four runner records').toBe(4);

		expect(pageErrors, `no page errors during activate, deactivate and repair (got: ${JSON.stringify(pageErrors)})`).toEqual([]);
		deleteProbeRecords();
		await home.jobRunnerDeactivateButton().click();
		await home.confirmDeactivate();
		await home.refreshHealthCheck();
		expect(runnerRecords().length, 'the org is back to no runner').toBe(0);
	});

	test('V140: A job on the runner shows its effective check interval, runs at the next check, and records the outcome', async({page}) =>
	{
		test.setTimeout(420_000);
		await navigateToApp(page, 'Kern');
		const home = new KernHomePage(page);
		await home.navigate();
		await activateRunnerEveryFifteenMinutes(home);

		const jobs = new ScheduledJobsPage(page);
		await jobs.navigate();
		await jobs.clickNew();
		await jobs.fillJobForm({
			name: PROBE_JOB_NAME, className: PROBE_CLASS_NAME, cron: '0 */5 * * * ?', isActive: true, executionMode: 'JobRunner', parameters: probeParameters()
		});
		expect(await jobs.getCronPreviewDescription(), 'the preview states the effective check interval').toContain('Every 15 minutes on this job runner');
		await jobs.clickSave();
		await page.waitForTimeout(3000);
		expect(await jobs.getDetailText('detail-execution-mode'), 'the detail view names the runner').toContain('Job runner');
		expect(await jobs.getDetailText('detail-next-run'), 'the detail view shows a next run').not.toBe('');

		const [record] = probeRecords();
		expect(record[prefixed('NextRunAt__c')], 'the trigger seeded the cursor').toBeTruthy();

		// Back-date the cursor so the very next check finds the row due, then fire one runner check in ~75 seconds
		// through the platform scheduler (the section-79 shape: a global class, no package-internal member).
		executeAnonymousApex(`update new kern__ScheduledJob__c(Id = '${record.Id}', kern__NextRunAt__c = System.now().addMinutes(-10));`);
		executeAnonymousApex('Datetime fireAt = System.now().addSeconds(75);'
				+ ' String cron = \'0 \' + fireAt.minute() + \' \' + fireAt.hour() + \' \' + fireAt.day() + \' \' + fireAt.month() + \' ? \' + fireAt.year();'
				+ ' System.schedule(\'V140 Job Runner Check \' + System.now().getTime(), cron, new kern.SCHED_JobRunner());');

		await pollUntil(page, () => probeRecords()[0][prefixed('LastRunOutcome__c')] === 'Succeeded', {timeout: 240_000, interval: 5_000, message: 'the run records Succeeded'});
		const [ran] = probeRecords();
		expect(new Date(ran[prefixed('NextRunAt__c')]).getTime(), 'the cursor moved past the check').toBeGreaterThan(Date.now() - 60_000);
		expect(ran[prefixed('LastRunJobId__c')], 'the run id was stamped at the start of the run').toMatch(/^707/);
		expect(ran[prefixed('LastRunReason__c')] ?? '', 'a success leaves no reason').toBe('');

		await jobs.openRecordById(record.Id);
		expect(await jobs.getDetailText('detail-last-run-outcome'), 'the detail view shows the outcome').toContain('Succeeded');
		expect(await jobs.getDetailText('detail-last-run'), 'the detail view shows when it ran').not.toBe('');
	});

	test('V141: Run now runs the job without moving the cursor, and refuses while the previous run is live under Skip', async({page}) =>
	{
		test.setTimeout(300_000);
		await navigateToApp(page, 'Kern');
		const jobs = new ScheduledJobsPage(page);
		const [record] = probeRecords();
		expect(record, 'V140 left the probe record in place').toBeTruthy();
		const cursorBefore = record[prefixed('NextRunAt__c')];

		await jobs.openRecordById(record.Id);
		await jobs.clickRunNow();
		await pollUntil(page, () => probeRecords()[0][prefixed('LastRunJobId__c')] !== record[prefixed('LastRunJobId__c')], {
			timeout: 60_000, interval: 3_000, message: 'Run now stamps a new run id'
		});
		await pollUntil(page, () => probeRecords()[0][prefixed('LastRunOutcome__c')] === 'Succeeded', {
			timeout: 180_000, interval: 5_000, message: 'the Run now run records Succeeded'
		});
		expect(probeRecords()[0][prefixed('NextRunAt__c')], 'Run now never moves the cursor').toBe(cursorBefore);

		// Make the previous run look live: a one-off scheduled job thirty minutes out holds a Queued AsyncApexJob.
		executeAnonymousApex('Datetime fireAt = System.now().addMinutes(30);'
				+ ' String cron = \'0 \' + fireAt.minute() + \' \' + fireAt.hour() + \' \' + fireAt.day() + \' \' + fireAt.month() + \' ? \' + fireAt.year();'
				+ ' Id cronId = System.schedule(\'V141 Job Runner Hold \' + System.now().getTime(), cron, new kern.SCHED_JobRunner());'
				+ ' AsyncApexJob held = [SELECT Id FROM AsyncApexJob WHERE CronTriggerId = :cronId LIMIT 1];'
				+ ` update new kern__ScheduledJob__c(Id = '${record.Id}', kern__LastRunJobId__c = held.Id);`);

		await jobs.openRecordById(record.Id);
		await jobs.clickRunNow();
		const toast = page.locator('.toastMessage, [data-key="error"] .toastMessage, lightning-toast').first();
		await toast.waitFor({state: 'visible', timeout: 15_000});
		expect(await toast.textContent(), 'the refusal names the overlap policy').toContain('overlap policy is Skip');

		executeAnonymousApex('for(CronTrigger trigger_x : [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name LIKE \'V141 Job Runner Hold%\'])'
				+ ' { System.abortJob(trigger_x.Id); }');
		deleteProbeRecords();
		const home = new KernHomePage(page);
		await home.navigate();
		await home.jobRunnerDeactivateButton().click();
		await home.confirmDeactivate();
		await home.refreshHealthCheck();
		expect(runnerRecords().length, 'the org is back to no runner').toBe(0);
	});

	test('V155: A user holding only Kern Job Runner Management creates a job, puts it on the runner and runs it now, cannot delete it, '
			+ 'and the platform job id is read-only', async({page, browser, viewport, timezoneId}) =>
	{
		test.setTimeout(300_000);
		const home = new KernHomePage(page);
		await home.navigate();
		await activateRunnerEveryFifteenMinutes(home);

		// A Standard User who holds this one set and nothing else from the package. Users cannot be deleted, so the
		// journey deactivates its user at the end; a scratch org's licences are few, so a failed run must not leave one active.
		// The same colour-free environment the harness gives every sf call it parses (helpers/sf-cli.js).
		const sfEnvironment = {...env, FORCE_COLOR: '0', NO_COLOR: '1'};
		let username;
		let context;
		try
		{
			const created = JSON.parse(execSync(`sf org create user -o ${ORG_ALIAS} profileName="Standard User" --json`, {encoding: 'utf8', timeout: 120_000, env: sfEnvironment}));
			username = created.result.fields.username;
			const managerId = created.result.fields.id;
			executeAnonymousApex(`User manager = [SELECT Id FROM User WHERE Username = '${username}' LIMIT 1];`
					+ ` PermissionSet managing = [SELECT Id FROM PermissionSet WHERE Name = 'JobRunnerManagement' AND ${namespaceClause()} LIMIT 1];`
					+ ' insert new PermissionSetAssignment(AssigneeId = manager.Id, PermissionSetId = managing.Id);');
			// A context opened in a test inherits the project's `use`, the admin's signed-in storage state included; an empty
			// state replaces it, so no admin cookie on the Lightning domain outlives the manager's sign-in.
			context = await browser.newContext({viewport, timezoneId, storageState: {cookies: [], origins: []}});
			const managerPage = await context.newPage();
			// The harness re-signs a page in when its address looks signed out; this page must come back as the manager.
			managerPage.kernFrontdoorUrl = () => getFrontdoorUrlFor(username);
			await managerPage.goto(getFrontdoorUrlFor(username), {waitUntil: 'domcontentloaded'});
			// A new user's first sign-in stops at Change Your Password; a random password and answer get past it, and
			// neither is needed again because the user is deactivated at the end.
			const changePassword = managerPage.getByRole('button', {name: 'Change Password'});
			await Promise.race([managerPage.waitForURL(/\/lightning\//, {timeout: 60_000}), changePassword.waitFor({state: 'visible', timeout: 60_000})]);
			if(await changePassword.isVisible())
			{
				await submitNewPassword(managerPage, changePassword, `V155-${randomUUID()}-a1`);
				await managerPage.waitForURL(/\/lightning\//, {timeout: 60_000});
			}
			// The set grants no Kern app, so the manager reaches the tab by its address, as the App Launcher would.
			await managerPage.goto(`${managerPage.url().split('/lightning/')[0]}/lightning/o/${prefixed('ScheduledJob__c')}/list`);
			const jobs = new ScheduledJobsPage(managerPage);
			await jobs.clickNew();
			// fillJobForm waits for the runner option to open, which it does only for a user who may manage the runner.
			await jobs.fillJobForm({name: PROBE_JOB_NAME, className: PROBE_CLASS_NAME, cron: '0 0 3 * * ?', executionMode: 'JobRunner', parameters: probeParameters()});
			await jobs.clickSave();
			// Asked by Id alone first: on an org where the admin's own field access comes from this set, the full probe
			// cannot run until the set grants it, and this check must still say whether the manager's save landed.
			const saved = soqlQuery(forOrg(`SELECT Id, CreatedById FROM kern__ScheduledJob__c WHERE kern__SchedulerName__c = '${PROBE_JOB_NAME}'`));
			expect(saved.length, 'the editor saved the job: the tab, the record access and the controller all reached').toBe(1);
			expect(saved[0].CreatedById, 'the manager, not the admin, saved it').toBe(managerId);
			const [record] = probeRecords();
			expect(record[prefixed('ExecutionMode__c')], 'the job is on the runner').toBe('JobRunner');

			await jobs.openRecordById(record.Id);
			await jobs.clickRunNow();
			await pollUntil(managerPage, () => probeRecords()[0][prefixed('LastRunJobId__c')], {
				timeout: 60_000, interval: 3_000, message: 'Run now, pressed by the manager, started a run'
			});

			await jobs.openRecordById(record.Id);
			// The record page lists Delete among its actions, and Lightning can show it to a user who may not delete; the
			// set grants no delete, so pressing it must be refused and leave the job in place.
			// The set grants edit, so Edit renders; once it has, the panel's other actions have too.
			await expect(managerPage.getByRole('button', {name: 'Edit', exact: true}), 'the record page shows its actions').toBeVisible({timeout: 30_000});
			const pageUserId = await managerPage.evaluate(() => window.$A?.get('$SObjectType.CurrentUser.Id'));
			expect(pageUserId, 'the page is still signed in as the manager').toBe(managerId);
			const deleteButton = managerPage.getByRole('button', {name: 'Delete', exact: true});
			if(await deleteButton.count() > 0)
			{
				test.info().annotations.push({type: 'delete-path', description: 'Delete was offered and pressed'});
				await jobs.deleteCurrentRecord();
				await managerPage.keyboard.press('Escape');
			}
			else
			{
				test.info().annotations.push({type: 'delete-path', description: 'Delete was not offered'});
				await expect(deleteButton, 'no Delete button for a set that grants no delete').toHaveCount(0);
				const moreActions = managerPage.getByRole('button', {name: 'Show more actions'});
				if(await moreActions.count() > 0)
				{
					await moreActions.first().click();
					await expect(managerPage.getByRole('menuitem', {name: 'Delete'}), 'no Delete in the overflow menu').toHaveCount(0);
					await managerPage.keyboard.press('Escape');
				}
			}
			expect(probeRecords().length, 'the manager cannot delete the job').toBe(1);
			// Field controls render only once the detail section has; the manager owns the job, so Owner offers Change Owner.
			await expect(managerPage.locator('button[title="Change Owner"]'), 'the detail section has rendered with its editable fields').toBeVisible({timeout: 30_000});
			await expect(managerPage.locator('button[title="Edit Scheduled Job Id"]'), 'the platform job id is read-only for the manager').toHaveCount(0);
		}
		finally
		{
			// Each step runs whatever the one before it did, and none hides the journey's own failure. The user goes
			// first: an active one costs a licence.
			await runCleanupStep(() => username
					&& executeAnonymousApex(`update new User(Id = [SELECT Id FROM User WHERE Username = '${username}' LIMIT 1].Id, IsActive = false);`));
			await runCleanupStep(() => context?.close());
			await runCleanupStep(() => deleteProbeRecords());
			await runCleanupStep(async() =>
			{
				await home.navigate();
				await home.jobRunnerDeactivateButton().click();
				await home.confirmDeactivate();
				await home.refreshHealthCheck();
			});
		}
		expect(runnerRecords().length, 'the org is back to no runner').toBe(0);
	});

	test('V157: The Scheduled Jobs Fast Start, as written: a record schedules the demo class, it moves onto the runner, '
		+ 'Run now succeeds, a failed run opens its log entry, and the job is switched off', async({page}) =>
	{
		test.setTimeout(420_000);
		expect(soqlQuery(`SELECT Id FROM ApexClass WHERE Name = '${FAST_START_CLASS_NAME}'`).length,
				`${FAST_START_CLASS_NAME} is deployed (release-testing/subscriber/classes; a copy without the prefixes on the development org)`).toBe(1);
		deleteFastStartRecords();
		await navigateToApp(page, 'Kern');
		const jobs = new ScheduledJobsPage(page);
		const home = new KernHomePage(page);
		const reopenEditor = async(recordId) =>
		{
			await jobs.openRecordById(recordId);
			await jobs.clickEdit();
			const editor = jobs.editor();
			// The record arrives after the form opens; fill only once it has, or the record's values overwrite the edit.
			await expect(editor.locator('[data-testid="scheduler-name"] input'), 'the editor has loaded the record').toHaveValue(FAST_START_JOB_NAME, {timeout: 15_000});
			return editor;
		};
		const pollOutcome = (outcome, message) => pollUntil(page, () => fastStartRecords()[0][prefixed('LastRunOutcome__c')] === outcome,
				{timeout: 120_000, interval: 3_000, message});
		try
		{
			// Step 2: the record, on a scheduled job of its own.
			await jobs.navigate();
			await jobs.clickNew();
			const editor = jobs.editor();
			// A required field's label carries the asterisk in the same element, so the match allows it in front.
			await Promise.all([GUIDE_LABELS.schedulerName, GUIDE_LABELS.className, GUIDE_LABELS.executionMode].map((label) =>
					expect(editor.getByText(new RegExp(`^\\*?\\s*${label}$`)).first(), `the editor shows "${label}", as the guide's table names it`).toBeVisible()));
			await jobs.fillJobForm({name: FAST_START_JOB_NAME, typedClassName: FAST_START_CLASS_NAME, cron: '0 0 * * * ?', isActive: true});
			await expect(editor.getByText(GUIDE_LABELS.failOnPurpose, {exact: true}).first(), 'the class\'s switch shows as a parameter').toBeVisible({timeout: 15_000});
			await jobs.clickSave();
			await page.waitForTimeout(3000);
			const [saved] = fastStartRecords();
			expect(saved[prefixed('ScheduledJobId__c')], 'Step 2: the record scheduled the class on a platform job of its own').toBeTruthy();
			await jobs.openRecordById(saved.Id);
			await expect(page.getByText(GUIDE_LABELS.scheduledJobId, {exact: true}).first(), 'the record page shows the field Step 2 reads').toBeVisible();

			// Step 4 (the e2e admin holds the set from beforeAll, the guide's Step 3).
			await home.navigate();
			await activateRunnerEveryFifteenMinutes(home);

			// Step 5: onto the runner.
			await reopenEditor(saved.Id);
			await jobs.fillJobForm({executionMode: 'JobRunner'});
			await jobs.clickSave();
			await page.waitForTimeout(3000);
			expect(fastStartRecords()[0][prefixed('ExecutionMode__c')], 'Step 5: the job is on the runner').toBe('JobRunner');

			// Step 6: Run now succeeds.
			await jobs.openRecordById(saved.Id);
			await expect(page.getByRole('button', {name: GUIDE_LABELS.runNow, exact: true}), 'Step 6 presses "Run now"').toBeVisible({timeout: 15_000});
			await jobs.clickRunNow();
			await pollOutcome('Succeeded', 'Step 6: the run records Succeeded');

			// Step 7: a failed run, and the log entry View log opens.
			const failingEditor = await reopenEditor(saved.Id);
			await jobs.setParameterToggle(failingEditor, FAIL_ON_PURPOSE_PARAMETER, true);
			await jobs.clickSave();
			await page.waitForTimeout(3000);
			await jobs.openRecordById(saved.Id);
			await jobs.clickRunNow();
			await pollOutcome('Failed', 'Step 7: the run records Failed');
			await jobs.openRecordById(saved.Id);
			await expect(page.getByRole('button', {name: GUIDE_LABELS.viewLog, exact: true}), 'Step 7 opens "View log"').toBeVisible({timeout: 15_000});
			await jobs.clickViewLog();
			await expect(page.locator('body'), 'the log entry carries the demo\'s message').toContainText('failed on purpose', {timeout: 30_000});
			const restoredEditor = await reopenEditor(saved.Id);
			await jobs.setParameterToggle(restoredEditor, FAIL_ON_PURPOSE_PARAMETER, false);
			await jobs.clickSave();
			await page.waitForTimeout(3000);

			// Step 9: switched off; the record stays.
			await reopenEditor(saved.Id);
			await jobs.fillJobForm({isActive: false});
			await jobs.clickSave();
			await page.waitForTimeout(3000);
			const [switchedOff] = fastStartRecords();
			expect(switchedOff[prefixed('IsActive__c')], 'Step 9: the job is off').toBe(false);
		}
		finally
		{
			await runCleanupStep(() => deleteFastStartRecords());
			await runCleanupStep(async() =>
			{
				if(runnerRecords().length > 0)
				{
					await home.navigate();
					await home.jobRunnerDeactivateButton().click();
					await home.confirmDeactivate();
					await home.refreshHealthCheck();
				}
			});
		}
	});
});
