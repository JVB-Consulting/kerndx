// SPDX-License-Identifier: Apache-2.0
const {defineConfig} = require('@playwright/test');
const path = require('path');
const {authPathsFor, testResultsDirectoryFor} = require('./helpers/auth-paths');

const sharedUse = {
	browserName: 'chromium',
	headless: true,
	// The run's own org folder: global-setup signs in to SF_SUBSCRIBER_ORG_ALIAS and saves the session there.
	storageState: authPathsFor().statePath,
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
// running the three files in a single-worker `scheduler-serial` project extends that
// serialisation across files too, without losing parallelism on the other independent
// specs (part2 / part3 / part7 / part8 / part9 / part10) that don't touch scheduled jobs.
//
// part10 (log-console) sits in `independent` deliberately: that project depends on
// `scheduler-serial`, so part1's fire-and-forget `kern__LogEntry__c` purge batch is
// launched (and its beforeAll finished) before part10 starts. part10 then seeds its own
// LogEntry fixtures in its OWN beforeAll — after additionally waiting out any still-running
// kern batch — so the purge can never race the seeded rows away mid-spec.
//
// part11 (job-runner) also runs in `scheduler-serial`: it changes org state (job-runner
// records) that other parts assume absent, so it needs the same single-worker serialisation.
//
// part12 (consoles-at-volume) runs in its OWN `volume` project, never `independent`. Its
// `beforeAll` lays a staged load on one worker for about twenty minutes while `independent`'s
// other worker would otherwise run part7 through part10 beside it; the seed writes engine rows
// (and the operate wave's launches) with `StartedAt` at or near now, in bursts far larger than
// anything the other independent specs tolerate. part8's `selectRowByChainName` reads the
// UNSCOPED Chain Monitor's first page (the twenty newest-first rows, no name search) at nine
// sites, so a part8 fixture selected while the seed is writing can be pushed off page one by
// those newer rows and the journey fails. Giving part12 its own single-worker project after
// `independent` keeps part8 (and the other independent specs) clear of the seed's rows, and
// `dependencies: ['independent']` keeps part1's purge ordered before part12's seed the same
// way it always has.
const schedulerSerialMatch = /part(1|4|11)-.*\.spec\.js$/;
const independentMatch = /part(2|3|7|8|9|10)-.*\.spec\.js$/;
const volumeMatch = /part12-.*\.spec\.js$/;
const streamingMatch = /part(5|6)-.*\.spec\.js$/;

module.exports = defineConfig({
	testDir: path.join(__dirname, 'specs'), globalSetup: path.join(__dirname, 'global-setup.js'), timeout: 120_000, expect: {timeout: 15_000}, workers: 2, reporter: [
		['list'],
		[path.join(__dirname, 'helpers', 'reporter.js')]
	], outputDir: testResultsDirectoryFor(), projects: [
		{
			name: 'scheduler-serial', testMatch: schedulerSerialMatch, fullyParallel: false, workers: 1, retries: 1, use: sharedUse
		},
		{
			name: 'independent', testMatch: independentMatch, fullyParallel: true, workers: 2, retries: 1, dependencies: ['scheduler-serial'], use: sharedUse
		},
		{
			name: 'volume', testMatch: volumeMatch, fullyParallel: false, workers: 1, retries: 1, dependencies: ['independent'], use: sharedUse
		},
		{
			name: 'streaming-serial', testMatch: streamingMatch, fullyParallel: false, workers: 1, retries: 0, dependencies: ['volume'], use: sharedUse
		},
		// The media-capture projects are NOT release gates: they record hero videos/stills and
		// carry their own seeded-state assumptions (the 2026-07-26 full release run failed 2
		// capture specs on a missing seeded ERROR entry while every release check passed). They
		// are defined only when KERNDX_CAPTURE=1, which runner/capture-heroes.js sets, so
		// `npm run test:e2e` / `release:phase3` can never sweep them into a release verdict.
		// They also mutate release-gate state: capture-heroes' kern-home hero clicks Apply
		// Recommended Retention, creating the 4 purge ScheduledJob__c rows that part4's V17/V18
		// assert to zero (caught 2026-07-03: V17 failed on 4 mid-run jobs and 63 dependent
		// checks never ran) — one more reason they stay out of the release battery.
		...(process.env.KERNDX_CAPTURE === '1' ? [
			{
				name: 'capture', testMatch: /capture-heroes\.spec\.js$/, fullyParallel: false, workers: 1, retries: 0, dependencies: ['streaming-serial'], use: {...sharedUse, permissions: ['clipboard-read', 'clipboard-write'], video: {mode: 'on', size: {width: 1280, height: 720}}, trace: 'on'}
			},
			{
				name: 'stills', testMatch: /capture-stills\.spec\.js$/, fullyParallel: false, workers: 1, retries: 0, dependencies: ['capture'], use: {...sharedUse, video: 'off', trace: 'off'}
			}
		] : [])
	]
});
