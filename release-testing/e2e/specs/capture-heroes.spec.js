// SPDX-License-Identifier: BUSL-1.1
// Hero-loop capture spec (the `capture` Playwright project records always-on WebM). Each test
// choreographs ONE admin tool's key flow with deliberate-but-tight pacing + motion polish. NOT a
// pass/fail gate — the recorded video is the deliverable. Determinism comes from the demo seed +
// in-app triggers (Safe Mode/Mocking, UI publish, seeded rows), not real-time waits.
const {test} = require('@playwright/test');
const ApiTestHarnessPage = require('../pages/api-test-harness.page');
const StreamingMonitorPage = require('../pages/streaming-monitor.page');
const ChainMonitorPage = require('../pages/chain-monitor.page');
const MaskingAdvisorPage = require('../pages/masking-advisor.page');
const {installOverlay, settle, moveCursorTo, clickWithPolish} = require('../helpers/capture-overlay');
const {waitForSpinnerGone} = require('../helpers/wait-helpers');
const {getInstanceUrl} = require('../helpers/sf-auth');

// Each tool has a direct Lightning tab. We jump STRAIGHT to it (the global-setup storageState
// carries the session, so no frontdoor round-trip / double app load) — that keeps the leading
// app-load pre-roll to a single short load, which the processor then trims off the front. The
// kern__ namespace is fixed because the capture org is the managed subscriber install.
async function gotoTool(page, tabApiName)
{
	await page.goto(`${getInstanceUrl()}/lightning/n/kern__${tabApiName}`, {waitUntil: 'domcontentloaded'});
	await waitForSpinnerGone(page);
}

// Rhythm: act -> short settle (UI absorbs the change) -> glide cursor (waits for the target to be
// position-stable) -> act. `clickWithPolish` bundles move+pulse+click+settle for raw selectors;
// for page-object-mediated beats we glide the synthetic cursor to the control first, then let the
// page object perform the (more robust) interaction. No zoom in the loop itself — the cursor, the
// click ripple, and the UI's own motion (badge flips, progress bars, events landing) carry it; the
// page provides a full-screen lightbox for readers who want to inspect detail.

test.describe('admin-tool hero loops', () =>
{
	test('api-harness', async({page}) =>
	{
		// Differentiator: inbound + outbound calls from a form, with Mocking (canned response, no
		// live endpoint / no Postman) and Safe Mode (every DML write rolled back). The seeded Echo
		// Subscriber Service is Outbound (the form's default) and has a registered mock, so executing
		// with Mocking on returns a canned body deterministically.
		await installOverlay(page);
		const harness = new ApiTestHarnessPage(page);
		await gotoTool(page, 'ApiTestHarness');
		await harness.waitForReady();
		await settle(page, 500);
		await moveCursorTo(page, '[data-testid="harness-service"]');
		await harness.selectService('Echo Subscriber Service');
		await settle(page, 350);
		// Visual hook: flip Safe Mode + Mocking on and watch the mode badge restyle.
		await moveCursorTo(page, '[data-id="safeMode"]');
		await harness.setSafeMode(true);
		await settle(page, 300);
		await moveCursorTo(page, '[data-id="mocking"]');
		await harness.setMocking(true);
		await settle(page, 350);
		await moveCursorTo(page, '[data-testid="harness-execute"]');
		await harness.execute();
		await waitForSpinnerGone(page, 30000);
		await settle(page, 1100); // dwell on the outbound result: metric grid + Mocked/Safe Mode badges + response

		// Now the OTHER direction: switch to Inbound, point at the inbound demo service, and fill a
		// request body. With Mocking on (carried over from the outbound run) the harness returns the
		// service's registered mock response, so the inbound call is a clean, repeatable success.
		await moveCursorTo(page, '[data-testid="harness-direction"]');
		await harness.selectDirection('Inbound');
		await settle(page, 400);
		await moveCursorTo(page, '[data-testid="harness-service"]');
		await harness.selectService('FastStart Inbound API DEMO');
		await settle(page, 400);
		await harness.setBody(JSON.stringify({name: 'Northwind Trading', email: 'jordan.lee@example.com', phone: '(415) 555-0163'}, null, 2));
		await harness.setMocking(true); // idempotent — Mocking is already on from the outbound run
		await settle(page, 400);
		await moveCursorTo(page, '[data-testid="harness-execute"]');
		await harness.execute();
		await waitForSpinnerGone(page, 30000);
		await settle(page, 1500); // dwell on the inbound result (mocked response, status + timing)
	});

	test('streaming-monitor', async({page}) =>
	{
		// Differentiator: subscribe to live channels AND publish test events from the same screen —
		// no CometD client / external subscriber. Subscribe to a custom platform event, publish one,
		// and watch it land on the timeline. "Log Entry Event" is a packaged, publishable PE.
		await installOverlay(page);
		const monitor = new StreamingMonitorPage(page);
		await gotoTool(page, 'StreamingEventMonitor');
		await page.locator('[data-testid="streaming-monitor-root"]').first().waitFor({state: 'visible', timeout: 30000});
		await settle(page, 500);
		await monitor.clickSubscribe();
		await settle(page, 300);
		await monitor.selectEventType('Custom Platform event');
		await monitor.selectEventName('Log Entry Event');
		await settle(page, 250);
		await moveCursorTo(page, '[data-testid="subscribe-button"]');
		// Click subscribe but don't sit through the connector handshake on camera — the publish-form
		// fill below (several seconds of real activity) overlaps it, so the subscription is live by
		// the time we publish and the event still lands, with no dead wait in the loop.
		await page.locator('[data-testid="subscribe-button"]').first().evaluate(el => el.click());
		await waitForSpinnerGone(page);
		await settle(page, 400);
		await monitor.clickPublish();
		await settle(page, 300);
		await monitor.selectEventType('Custom Platform event');
		await monitor.selectEventName('Log Entry Event');
		await monitor.setPublishPayload(JSON.stringify({kern__Message__c: 'Nightly sync started', kern__LogLevel__c: 'INFO', kern__ClassMethod__c: 'AccountSync.run'}));
		await settle(page, 250);
		await clickWithPolish(page, '[data-testid="publish-button"]');
		await monitor.waitForEvent({channel: 'LogEntryEvent', timeout: 30000}).catch(() => {});
		await settle(page, 1400); // dwell on the event landing on the timeline
	});

	test('chain-monitor', async({page}) =>
	{
		// Differentiator: per-step visibility the platform doesn't give you — and when a step breaks,
		// it shows exactly which one and why. The seed gives a varied list (running / completed /
		// failed); we drill into the FAILED chain so the loop lands on the diagnose-a-failure payoff.
		await installOverlay(page);
		const chain = new ChainMonitorPage(page);
		await gotoTool(page, 'ChainMonitor');
		await chain.getListPanel().waitFor({state: 'visible', timeout: 30000});
		await settle(page, 1100); // dwell on the populated, varied-status list
		const rowTexts = await chain.getRowTexts();
		let failedIndex = rowTexts.findIndex(t => t.includes('Failed'));
		if(failedIndex < 0)
		{
			failedIndex = 0;
		}
		await clickWithPolish(page, '[data-testid="chain-monitor-list-root"] lightning-datatable');
		await chain.selectRow(failedIndex);
		await settle(page, 1300); // the step timeline renders with the failed step flagged
		await chain.expandErrorAccordion().catch(() => {});
		await settle(page, 1900); // dwell on the failed step + its error message
	});

	test('masking-advisor', async({page}) =>
	{
		// Differentiator: auto-discovery + a deployable masking package — scan for sensitive fields
		// instead of hand-auditing. The seeded Foobar rows give the scan real Email/Phone values to
		// flag. (Foobar is a packaged custom object, so include managed objects in the scan scope.)
		await installOverlay(page);
		const masking = new MaskingAdvisorPage(page);
		await gotoTool(page, 'DataMaskingAdvisor');
		await masking.addObjectButton().waitFor({state: 'visible', timeout: 60000});
		await settle(page, 600);
		const managedToggle = page.locator('[data-testid="coverage-managed-toggle"]');
		if(await managedToggle.isVisible().catch(() => false) && !(await managedToggle.isChecked().catch(() => false)))
		{
			await moveCursorTo(page, '[data-testid="coverage-managed-toggle"]');
			await managedToggle.click({force: true}).catch(() => {});
			await settle(page, 400);
		}
		await clickWithPolish(page, '[data-testid="coverage-scan-button"]');
		await page.waitForSelector('[data-testid="coverage-scan-progress"]', {timeout: 15000}).catch(() => {});
		await settle(page, 500); // let the progress bar animate
		await page.waitForSelector('[data-testid="coverage-scan-summary"], [data-testid="coverage-flagged-row"]', {timeout: 60000}).catch(() => {});
		await settle(page, 1200); // dwell on the flagged sensitive fields

		// Drill into a flagged object to show the per-field analysis + recommended masking rules — the
		// "here's exactly what to mask, then deploy it" payoff, not just the headline count.
		const foobarRow = '[data-testid="coverage-flagged-row"][data-api-name="kern__Foobar__c"]';
		if(await page.locator(foobarRow).first().isVisible().catch(() => false))
		{
			await clickWithPolish(page, foobarRow);
			await masking.objectWideBanner().waitFor({state: 'visible', timeout: 30000}).catch(() => {});
			await waitForSpinnerGone(page);
			await settle(page, 600);
			// Bring the flagged Email field row into view so the recommended-rule chips are on screen.
			await masking.fieldRow('kern__Email__c').scrollIntoViewIfNeeded().catch(() => {});
			await settle(page, 2000); // dwell on the per-object field sections (Email/Phone + rules)
		}
		else
		{
			await settle(page, 1500);
		}
	});
});
