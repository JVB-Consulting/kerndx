// SPDX-License-Identifier: Apache-2.0
// Playwright config for the prototype gap-finders (AGENTS.md lever 2).
//
// Deliberately SEPARATE from playwright.config.js: the gap-finders are parity gates against a
// deployed org, not release-battery checks, and they must never inherit the battery's project
// dependency chain (which would drag part1's scheduler seeding in front of every run). Keeping
// them here also keeps `npm run test:e2e` free of a spec that seeds and tears down its own rows.
//
// Run:
//   SF_SUBSCRIBER_ORG_ALIAS=YourDevOrgAlias \
//     npx playwright test --config release-testing/e2e/gap-finder.config.js
//
// Every run gets a brand-new browser context, so a freshly deployed LWC bundle is never served
// from the previous session's module cache.
const {defineConfig} = require('@playwright/test');
const path = require('path');
const {authPathsFor, testResultsDirectoryFor} = require('./helpers/auth-paths');

module.exports = defineConfig({
	// The gap-finders live in specs/ because jest.config.js ignores that directory: a `.spec.js` at
	// the e2e root is swept into `npm run test:unit` by jest's default testMatch and fails there.
	// The release battery's own projects match only part1-10/capture, so nothing here runs in it.
	testDir: path.join(__dirname, 'specs'),
	testMatch: /gap-finder-.*\.spec\.js$/,
	globalSetup: path.join(__dirname, 'global-setup.js'),
	// The log-console gap-finder walks seven console/drawer states and waits out a real gap window
	// while seeding, so it needs far more than the battery's per-test budget.
	timeout: 900_000,
	expect: {timeout: 15_000},
	workers: 1,
	fullyParallel: false,
	retries: 0,
	reporter: [['list']],
	// Inside the already-ignored release-testing/test-results/ tree, so a failed run's traces and
	// screenshots never show up as untracked files.
	outputDir: path.join(testResultsDirectoryFor(), 'gap-finder'),
	use: {
		browserName: 'chromium',
		headless: true,
		storageState: authPathsFor().statePath,
		// The console derives its date presets from the browser clock; pin it to the scratch-org
		// user's timezone exactly as the release battery does.
		timezoneId: 'America/Los_Angeles',
		viewport: {width: 1920, height: 1080},
		screenshot: 'only-on-failure',
		trace: 'retain-on-failure',
		video: 'off',
		navigationTimeout: 30_000,
		actionTimeout: 15_000
	}
});
