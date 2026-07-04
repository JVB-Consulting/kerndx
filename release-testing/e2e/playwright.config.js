// SPDX-License-Identifier: BUSL-1.1
const {defineConfig} = require('@playwright/test');
const path = require('path');

const sharedUse = {
	browserName: 'chromium',
	headless: true,
	storageState: path.join(__dirname, '.auth', 'state.json'),
	// Pin the browser clock to the scratch-org user's Salesforce timezone (America/Los_Angeles
	// is the scratch-org default). The Log Console computes its date presets from the browser
	// clock, so part10's midnight-straddle probe (V108) is only coherent when browser and
	// Salesforce user agree on where "today" starts — the normal case for a real user. A browser
	// whose OS timezone differs from the Salesforce user's (this machine: America/New_York)
	// shifts the console's "Today" window off the user's calendar day; that browser-clock
	// windowing is a known console limitation, tracked for a user-timezone-aware fix.
	timezoneId: 'America/Los_Angeles',
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
// specs (part2 / part3 / part7 / part8 / part9 / part10) that don't touch scheduled jobs.
//
// part10 (log-console) sits in `independent` deliberately: that project depends on
// `scheduler-serial`, so part1's fire-and-forget `kern__LogEntry__c` purge batch is
// launched (and its beforeAll finished) before part10 starts. part10 then seeds its own
// LogEntry fixtures in its OWN beforeAll — after additionally waiting out any still-running
// kern batch — so the purge can never race the seeded rows away mid-spec.
const schedulerSerialMatch = /part(1|4)-.*\.spec\.js$/;
const independentMatch = /part(2|3|7|8|9|10)-.*\.spec\.js$/;
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
		// The media-capture projects mutate release-gate state: capture-heroes' kern-home hero
		// clicks Apply Recommended Retention, creating the 4 purge ScheduledJob__c rows that
		// part4's V17/V18 assert to zero. Without a dependency they start on the second global
		// worker in parallel with scheduler-serial and contaminate the battery (caught 2026-07-03:
		// V17 failed on 4 mid-run jobs and 63 dependent checks never ran). Sequencing them after
		// streaming-serial keeps `npm run test:e2e` safe; run them alone with --project capture.
		{
			name: 'capture', testMatch: /capture-heroes\.spec\.js$/, fullyParallel: false, workers: 1, retries: 0, dependencies: ['streaming-serial'], use: {...sharedUse, permissions: ['clipboard-read', 'clipboard-write'], video: {mode: 'on', size: {width: 1280, height: 720}}, trace: 'on'}
		},
		{
			name: 'stills', testMatch: /capture-stills\.spec\.js$/, fullyParallel: false, workers: 1, retries: 0, dependencies: ['capture'], use: {...sharedUse, video: 'off', trace: 'off'}
		}
	]
});
