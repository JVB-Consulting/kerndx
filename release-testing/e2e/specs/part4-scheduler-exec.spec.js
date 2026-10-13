// SPDX-License-Identifier: BUSL-1.1
const {test, expect} = require('@playwright/test');
const ScheduledJobsPage = require('../pages/scheduled-jobs.page');
const {navigateToApp, navigateToAppItem} = require('../helpers/sf-navigation');
const {waitForSpinnerGone} = require('../helpers/wait-helpers');
const {executeAnonymousApex} = require('../helpers/sf-cli');
const fs = require('fs');
const os = require('os');
const path = require('path');
const {execSync} = require('child_process');
const {ORG_ALIAS} = require('../helpers/sf-auth');

// A schedulable class the journey deploys after the editor has stored its class list, so the list cannot show it.
const TYPED_PROBE_CLASS_NAME = 'TypedClassNameProbe';
// The same colour-free environment the harness gives every sf call it parses (helpers/sf-cli.js).
const SF_ENVIRONMENT = {...process.env, FORCE_COLOR: '0', NO_COLOR: '1'};

// A project folder of its own for the probe class: deploying a folder outside the checkout from the checkout would
// confuse its source tracking.
function writeTypedClassProbeProject()
{
	const apiVersion = JSON.parse(execSync(`sf org display -o ${ORG_ALIAS} --json`, {encoding: 'utf8', timeout: 60_000, env: SF_ENVIRONMENT})).result.apiVersion;
	const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'typed-class-probe-'));
	const classes = path.join(directory, 'force-app', 'main', 'default', 'classes');
	fs.mkdirSync(classes, {recursive: true});
	fs.writeFileSync(path.join(directory, 'sfdx-project.json'), JSON.stringify({packageDirectories: [{path: 'force-app', default: true}], sourceApiVersion: apiVersion}));
	fs.writeFileSync(path.join(classes, `${TYPED_PROBE_CLASS_NAME}.cls`),
			`global with sharing class ${TYPED_PROBE_CLASS_NAME} implements Schedulable\n{\n\tglobal void execute(SchedulableContext context)\n\t{\n\t}\n}\n`);
	fs.writeFileSync(path.join(classes, `${TYPED_PROBE_CLASS_NAME}.cls-meta.xml`),
			`<?xml version="1.0" encoding="UTF-8"?>\n<ApexClass xmlns="http://soap.sforce.com/2006/04/metadata">\n`
			+ `\t<apiVersion>${apiVersion}</apiVersion>\n\t<status>Active</status>\n</ApexClass>\n`);
	return directory;
}

function runInProbeProject(directory, command)
{
	return JSON.parse(execSync(`${command} -o ${ORG_ALIAS} --json`, {cwd: directory, encoding: 'utf8', timeout: 300_000, env: SF_ENVIRONMENT}));
}

test.describe.serial('Part 4: Scheduler Execution', () =>
{
	test('V15: Scheduled Job Execution — Purge Records', async({page}) =>
	{
		test.setTimeout(180_000);
		await navigateToApp(page, 'Kern');
		const jobs = new ScheduledJobsPage(page);
		await jobs.navigate();

		await jobs.clickNew();
		await jobs.fillJobForm({
			name: 'Purge Test Job', className: 'SCHED_PurgeRecords', cron: '0 0 2 * * ?', isActive: true, parameters: {
				'objectName': 'kern__LogEntry__c', 'minimumNumberOfDays': '9999', 'batchSize': '200'
			}
		});
		await jobs.clickSave();
		await page.waitForTimeout(3000);

		const detail = await jobs.getDetailComponent();
		await expect(detail).toBeVisible();
		// The detail root now also renders during its loading and error states, so prove the
		// record actually loaded rather than just that the card mounted.
		await expect(detail.locator('[data-testid="cron-description"]')).toBeVisible();
		await expect(detail.locator('[data-testid="load-error"]')).toBeHidden();

		executeAnonymousApex(`
			List<CronTrigger> triggers = [SELECT Id, State FROM CronTrigger WHERE CronJobDetail.Name LIKE '%Purge Test Job%'];
			System.debug('JOB_FOUND:' + !triggers.isEmpty());
		`);

		await jobs.deleteCurrentRecord();
	});

	test('V16: Scheduled Job Execution — Login History', async({page}) =>
	{
		test.setTimeout(180_000);
		await navigateToApp(page, 'Kern');
		const jobs = new ScheduledJobsPage(page);
		await jobs.navigate();

		await jobs.clickNew();
		await jobs.fillJobForm({
			name: 'Login Stats Test', className: 'SCHED_ProcessLoginHistory', cron: '0 0 3 * * ?', isActive: true
		});
		await jobs.clickSave();
		await page.waitForTimeout(3000);

		const detail = await jobs.getDetailComponent();
		await expect(detail).toBeVisible();
		// The detail root now also renders during its loading and error states, so prove the
		// record actually loaded rather than just that the card mounted.
		await expect(detail.locator('[data-testid="cron-description"]')).toBeVisible();
		await expect(detail.locator('[data-testid="load-error"]')).toBeHidden();

		await jobs.deleteCurrentRecord();
	});

	test('V138: Scheduled Job Editor — a sub-hourly cron is refused before save', async({page}) =>
	{
		test.setTimeout(120_000);
		await navigateToApp(page, 'Kern');
		const jobs = new ScheduledJobsPage(page);
		await jobs.navigate();
		const countBefore = await jobs.getRecordCount();

		await jobs.clickNew();
		await jobs.fillJobForm({name: 'Sub-hourly Probe', className: 'SCHED_ProcessLoginHistory', cron: '0 */15 * * * ?', isActive: true});

		// In its own mode the platform takes one integer in the minutes field, so the editor must say so before anyone saves.
		const message = await jobs.getCronValidationMessage();
		expect(message, 'the alert names the minutes field').toContain('minutes:');
		expect(message, 'the alert states the once-an-hour rule').toContain('once an hour');

		await jobs.clickSave();
		await page.waitForTimeout(2000);
		await expect(page.locator('[data-testid="scheduled-job-editor-root"]'), 'the editor stays open').toBeVisible();

		await jobs.clickCancel();
		await jobs.navigate();
		expect(await jobs.getRecordCount(), 'no record was created').toBe(countBefore);
	});

	test('V156: Scheduled Job Editor — a class missing from the cached list can be typed, and a name that cannot be scheduled is refused at the field', async({page}) =>
	{
		test.setTimeout(420_000);
		const probeDirectory = writeTypedClassProbeProject();
		await navigateToApp(page, 'Kern');
		const jobs = new ScheduledJobsPage(page);
		try
		{
			await jobs.navigate();
			await jobs.clickNew();
			const editor = jobs.editor();
			// Opening the editor stores the class list in org Platform Cache before the probe class exists.
			expect(await jobs.listedSchedulableClasses(editor), 'the probe class is not deployed yet').not.toContain(TYPED_PROBE_CLASS_NAME);
			// A name and the preset schedule would open Save, so only the refused class can keep it closed.
			await editor.locator('[data-testid="scheduler-name"] input').fill('Typed Class Probe');
			await jobs.typeSchedulableClass(editor, TYPED_PROBE_CLASS_NAME);
			await expect.poll(() => jobs.getClassNameError(editor), {timeout: 15_000, message: 'a class that does not exist is refused at the field'})
			.toContain(TYPED_PROBE_CLASS_NAME);
			// The test id sits on the lightning-button host; the disabled state is on the button inside it.
			await expect(page.locator('[data-testid="save-button"] button').first(), 'and Save stays closed').toBeDisabled();
			await jobs.clickCancel();

			const deployed = runInProbeProject(probeDirectory, 'sf project deploy start -d force-app --wait 10');
			expect(deployed.status, `the probe class deployed: ${JSON.stringify(deployed.result?.details?.componentFailures ?? '')}`).toBe(0);

			await jobs.navigate();
			await jobs.clickNew();
			const freshEditor = jobs.editor();
			// Needs org Platform Cache (Health Check's Org Cache row): without it the list is scanned on every open.
			expect(await jobs.listedSchedulableClasses(freshEditor), 'the cached list does not show a class deployed after it was stored').not.toContain(TYPED_PROBE_CLASS_NAME);
			await jobs.typeSchedulableClass(freshEditor, TYPED_PROBE_CLASS_NAME);
			await expect.poll(() => jobs.getClassNameError(freshEditor), {timeout: 15_000, message: 'the deployed class, typed again, is accepted'}).toBe('');

			await jobs.typeSchedulableClass(freshEditor, '  sched_deactivateusers  ');
			await expect(freshEditor.locator('[data-testid="param-minimumNumberOfDays"]'), 'a listed name typed in lower case with spaces loads its parameter form')
			.toBeVisible({timeout: 15_000});
			await jobs.clickCancel();
		}
		finally
		{
			try
			{
				runInProbeProject(probeDirectory, `sf project delete source -m ApexClass:${TYPED_PROBE_CLASS_NAME} --no-prompt`);
			}
			catch(cleanupFailure)
			{
				console.warn(`[part4] V156 could not delete ${TYPED_PROBE_CLASS_NAME}: ${cleanupFailure.message}`);
			}
			fs.rmSync(probeDirectory, {recursive: true, force: true});
		}
	});

	test('V17: Verify Scheduled Jobs Clean', async({page}) =>
	{
		await navigateToApp(page, 'Kern');
		const jobs = new ScheduledJobsPage(page);
		await jobs.navigate();

		const count = await jobs.getRecordCount();
		expect(count, 'Should have 0 scheduled job records').toBe(0);
	});

	test('V18: Verify No Leftover Test Data', async({page}) =>
	{
		await navigateToAppItem(page, 'Accounts');
		await waitForSpinnerGone(page);
		await page.waitForTimeout(2000);

		const pageContent = await page.content();
		const hasTestAccount = pageContent.includes('Visual Test Account');
		expect(hasTestAccount, 'Visual Test Account should not exist').toBeFalsy();

		await navigateToApp(page, 'Kern');
		const jobs = new ScheduledJobsPage(page);
		await jobs.navigate();

		const count = await jobs.getRecordCount();
		expect(count, 'Scheduled Jobs should be empty').toBe(0);
	});
});
