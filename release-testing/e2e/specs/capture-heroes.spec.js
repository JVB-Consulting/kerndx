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
const ScheduledJobsPage = require('../pages/scheduled-jobs.page');
const KernHomePage = require('../pages/kern-home.page');
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

// Close any transient app-shell toast (e.g. the "this app is invalid, taking you to your default
// app" notice that flashes on a direct deep-link into the Kern app) so it is never filmed. Best-
// effort: click each toast's close button, then wait for the toast region to clear.
async function dismissToasts(page)
{
	// Poll for up to ~2.5s because the toast appears a beat AFTER the shell loads. Clicking it the
	// moment it shows keeps the dismissal inside the trimmed lead, not the filmed choreography.
	for(let attempt = 0; attempt < 10; attempt++)
	{
		const toast = page.locator('.slds-notify_toast, .forceToastMessage').first();
		const visible = await toast.isVisible().catch(() => false);
		if(visible)
		{
			const closers = page.locator('.slds-notify_toast button[title="Close"], .toastContainer button[title="Close"], .forceToastMessage button[title="Close"], .slds-notify__close button');
			const count = await closers.count().catch(() => 0);
			for(let i = 0; i < count; i++)
			{
				await closers.nth(i).click({timeout: 1200}).catch(() => {});
			}
			if(!(await toast.isVisible().catch(() => false)))
			{
				return;
			}
		}
		await page.waitForTimeout(250);
	}
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

	test('scheduled-jobs', async({page}) =>
	{
		// Differentiator: schedule a recurring job with no cron knowledge — pick a mode, watch the
		// plain-English description rewrite live as you change the schedule, and have an impossible
		// schedule rejected inline before it can be saved. The native Schedule Apex screen does none
		// of this. We don't save (the loop is about BUILDING the schedule, not the save toast), so the
		// org's retention state stays untouched for the health-check loop that follows.
		await installOverlay(page);
		const jobs = new ScheduledJobsPage(page);
		await page.goto(`${getInstanceUrl()}/lightning/o/kern__ScheduledJob__c/list`, {waitUntil: 'domcontentloaded'});
		await waitForSpinnerGone(page);
		await settle(page, 500);
		await jobs.clickNew(); // the Large-form-factor override renders the custom editor, not the standard New page
		const editor = page.locator('[data-testid="scheduled-job-editor-root"]');
		await editor.waitFor({state: 'visible', timeout: 30000});
		await settle(page, 700);
		await moveCursorTo(page, '[data-testid="scheduler-name"] input');
		await editor.locator('[data-testid="scheduler-name"] input').fill('Nightly Record Cleanup');
		await settle(page, 350);
		// Pick the class to schedule (best-effort + bounded — the cron builder below is the focus; the
		// class combobox can be slow to populate on a cold org, and we never want a long dead wait on camera).
		await moveCursorTo(page, '[data-testid="class-name"]');
		try
		{
			await editor.locator('[data-testid="class-name"] button, [data-testid="class-name"] input').first().click();
			const firstOption = page.getByRole('option').first();
			await firstOption.waitFor({state: 'visible', timeout: 6000});
			await firstOption.click();
		}
		catch(e)
		{
			await page.keyboard.press('Escape').catch(() => {});
		}
		await settle(page, 900); // dwell on the Preset builder + its live "Every day at 12:00 PM" description

		// Advanced mode: the per-field power-user view, with the same live preview underneath.
		await moveCursorTo(page, '[data-testid="cron-mode"]');
		await editor.getByText('Advanced', {exact: true}).click();
		await settle(page, 1300);

		// Custom mode: hand-write an expression and make a deliberate mistake — the editor catches it inline.
		await editor.getByText('Custom', {exact: true}).click();
		await settle(page, 450);
		await moveCursorTo(page, '[data-testid="cron-custom-input"] input');
		const cronInput = editor.locator('[data-testid="cron-custom-input"] input').first();
		await cronInput.fill('0 0 12 31 2 ?'); // day 31 of February — impossible
		await cronInput.blur();
		await settle(page, 1700); // dwell on the inline validation error

		// Fix it to a valid weekday-morning schedule — the error clears and the description rewrites.
		await cronInput.fill('0 0 6 ? * MON-FRI');
		await cronInput.blur();
		await settle(page, 2200); // dwell on the valid expression + "Every weekday ... at 6:00 AM"
	});

	test('health-check', async({page}, testInfo) =>
	{
		// Differentiator: a readiness banner that surfaces what ISN'T configured yet AND fixes it in
		// place. It opens flagging Data Retention (no purge jobs scheduled, framework records growing
		// unbounded); one click schedules the recommended jobs and the row flips to Passing without
		// leaving the page. The loop must SHOW the not-yet-healthy state prominently first — that is the
		// point of a readiness check — so we dwell on the flagged card and grab the poster from there,
		// then film the one-click remediation.
		await installOverlay(page);
		const home = new KernHomePage(page);
		await page.goto(`${getInstanceUrl()}/lightning/app/kern__Kern`, {waitUntil: 'domcontentloaded'});
		await dismissToasts(page);
		await waitForSpinnerGone(page);
		const hc = home.healthCheck();
		await hc.waitFor({state: 'visible', timeout: 30000});
		await waitForSpinnerGone(page);
		await dismissToasts(page);
		await settle(page, 1300);

		// Dwell on the banner doing its job: on a freshly-installed org it flags everything that
		// isn't configured yet — Action required for the foundational pieces (Organisation Cache,
		// Trusted Site) and Review recommended for the rest (Data Retention, the Class Type Resolver).
		// This top-of-banner frame becomes the poster (the still a reader sees before pressing play),
		// so the not-healthy state is what greets them.
		await hc.scrollIntoViewIfNeeded();
		await settle(page, 2600);
		await page.screenshot({path: testInfo.outputPath('problem-poster.png')});
		await settle(page, 700);

		// Now fix one in place: the Data Retention check schedules its purge jobs with a single click.
		await moveCursorTo(page, '[data-testid="apply-retention-button"]');
		await settle(page, 900);
		await home.clickApplyRetention();
		await settle(page, 800); // the confirm modal animates in
		await moveCursorTo(page, '[data-testid="confirm-button"]');
		await home.confirmApplyRetention(); // creates the jobs in-context; the card re-runs its checks
		await home.healthCheckPassingChip('Data Retention').waitFor({state: 'visible', timeout: 30000}).catch(() => {});
		await settle(page, 2400); // dwell on Data Retention now showing as Passing
	});

	test('class-type-resolver', async({page}) =>
	{
		// Differentiator: a guided helper that writes the small "type resolver" class a managed package
		// needs in order to find your own Apex by name. Opened straight from the Health Check row that
		// flags it as not-yet-configured: name the class, watch the generated source rewrite live, and
		// read the spelled-out deploy + register steps. The helper only GENERATES the class — the modal
		// shows the numbered deploy/register checklist, so the loop never implies a one-click outcome.
		await installOverlay(page);
		const home = new KernHomePage(page);
		await page.goto(`${getInstanceUrl()}/lightning/app/kern__Kern`, {waitUntil: 'domcontentloaded'});
		await dismissToasts(page);
		await waitForSpinnerGone(page);
		const hc = home.healthCheck();
		await hc.waitFor({state: 'visible', timeout: 30000});
		await waitForSpinnerGone(page);
		await dismissToasts(page);
		await settle(page, 1300); // dwell on the readiness banner flagging the resolver as not set up

		// Open the Class Type Resolver helper from its flagged row.
		const setupButton = home.healthCheckActionButton('Class Type Resolver');
		await setupButton.waitFor({state: 'visible', timeout: 15000});
		await moveCursorTo(page, 'lightning-button[data-name="Class Type Resolver"]');
		await settle(page, 450);
		await setupButton.click();

		// The helper modal animates in: the class-name field, the ordered setup steps, and the
		// generated resolver source.
		await page.locator('[data-testid="resolver-class-name"]').waitFor({state: 'visible', timeout: 20000});
		await waitForSpinnerGone(page);
		await settle(page, 1800); // dwell on the generated class + the numbered deploy/register checklist

		// Rename the class to something org-specific and watch the generated source rewrite live.
		await moveCursorTo(page, '[data-testid="resolver-class-name"] input');
		const nameInput = page.locator('[data-testid="resolver-class-name"] input').first();
		await nameInput.click();
		await nameInput.fill('');
		await nameInput.pressSequentially('Northwind_ClassTypeResolver', {delay: 45});
		await settle(page, 1800); // the code block re-renders with the new class name

		// Copy the resolver — the copy icon flips to a check.
		await moveCursorTo(page, '[data-testid="copy-resolver"]');
		await clickWithPolish(page, '[data-testid="copy-resolver"]');
		await settle(page, 2200); // dwell on the copied state + the setup steps
	});
});
