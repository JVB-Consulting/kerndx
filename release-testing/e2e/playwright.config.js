// SPDX-License-Identifier: BUSL-1.1
const {defineConfig} = require('@playwright/test');
const path = require('path');

const sharedUse = {
	browserName: 'chromium',
	headless: true,
	storageState: path.join(__dirname, '.auth', 'state.json'),
	viewport: {width: 1920, height: 1080},
	screenshot: 'on',
	trace: 'retain-on-failure',
	video: 'retain-on-failure',
	navigationTimeout: 30_000,
	actionTimeout: 15_000
};

// Part 1 (app-core) and Part 4 (scheduler-exec) both mutate the same
// `kern__ScheduledJob__c` records keyed on `kern.SCHED_PurgeRecords` — part1's
// `executeAnonymousApex('delete [...] WHERE kern__ClassName__c = \'kern.SCHED_PurgeRecords\'')`
// runs as per-test cleanup and will happily nuke any job created in parallel by part4.
// Running them on separate workers therefore races: part4's V15 can be mid-save when a
// part1 cleanup fires, and the detail page V15 was waiting for never renders. Both files
// already declare `test.describe.serial(...)` so tests within each file are ordered;
// running the two files in a single-worker `scheduler-serial` project extends that
// serialisation across files too, without losing parallelism on the other independent
// specs (part2 / part3 / part7 / part8 / part9) that don't touch scheduled jobs.
const schedulerSerialMatch = /part(1|4)-.*\.spec\.js$/;
const independentMatch = /part(2|3|7|8|9)-.*\.spec\.js$/;
const streamingMatch = /part(5|6)-.*\.spec\.js$/;

module.exports = defineConfig({
	testDir: path.join(__dirname, 'specs'), globalSetup: path.join(__dirname, 'global-setup.js'), timeout: 120_000, expect: {timeout: 15_000}, workers: 2, reporter: [
		['list'],
		[path.join(__dirname, 'helpers', 'reporter.js')]
	], outputDir: path.join(__dirname, '..', 'test-results'), projects: [
		{
			name: 'scheduler-serial', testMatch: schedulerSerialMatch, fullyParallel: false, workers: 1, retries: 1, use: sharedUse
		},
		{
			name: 'independent', testMatch: independentMatch, fullyParallel: true, workers: 2, retries: 1, dependencies: ['scheduler-serial'], use: sharedUse
		},
		{
			name: 'streaming-serial', testMatch: streamingMatch, fullyParallel: false, workers: 1, retries: 0, dependencies: ['independent'], use: sharedUse
		},
		{
			name: 'capture', testMatch: /capture-heroes\.spec\.js$/, fullyParallel: false, workers: 1, retries: 0, use: {...sharedUse, video: {mode: 'on', size: {width: 1280, height: 720}}, trace: 'on'}
		}
	]
});
