// SPDX-License-Identifier: BUSL-1.1
const {test, expect} = require('@playwright/test');
const MaskingAdvisorPage = require('../pages/masking-advisor.page');
const KernHomePage = require('../pages/kern-home.page');
const {waitForLightningReady} = require('../helpers/sf-navigation');
const {getInstanceUrl, ensureAuthenticated} = require('../helpers/sf-auth');
const {waitForSpinnerGone} = require('../helpers/wait-helpers');
const path = require('path');
const {deployMetadataDir} = require('../../runner/cmdt-deployer');

// The Data Masking Advisor is namespace-agnostic by data-testid, so this spec runs unchanged against
// the no-namespace unmanaged org and a namespaced subscriber install. Account is the multi-mask target:
// its Phone field surfaces two dormant phone-rule candidates (US + International), pre-ticked, so the
// per-object view has queued changes on arrival without any toggling.
const TARGET_OBJECT = 'Account';
const MULTI_MASK_FIELD = 'Phone';
const PHONE_RULE_US = 'MaskPhoneUS';
const PHONE_RULE_INTERNATIONAL = 'MaskPhoneInternational';
const OVERFLOW_TOLERANCE = 2;
// Must match System.Label.HealthCheck_MaskingPosture_CheckName — the masking-posture check was
// renamed when the custom-object coverage check split out of it.
const MASKING_CHECK_NAME = 'Masking configuration';
// Reuses the committed masking-advisor round-trip bundles: `create` adds a dead configuration (an
// active target bound to a dormant rule) that flips the masking-posture Health Check to Warn; `disable`
// restores the Pass baseline. The bundles carry namespace-qualified rule references, so the value-change
// check only runs on a managed subscriber install.
const MASKING_ADVISOR_BUNDLES_DIR = path.join(__dirname, '..', 'fixtures', 'masking-advisor-bundles');

test.describe.serial('Part 9: Masking Advisor', () =>
{
	test('V90: Review landing shows posture tiles and a masked-object inventory that drills in', async({page}, testInfo) =>
	{
		const advisor = new MaskingAdvisorPage(page);
		await advisor.navigate();

		await expect(advisor.scopeBanner(), 'Scope banner should explain the two masking modes').toBeVisible();

		const objectsMasked = await advisor.readCount(advisor.postureObjectsCount());
		const deadConfigs = await advisor.readCount(advisor.postureDeadCount());
		expect(objectsMasked, 'Objects-with-masking tile should render a number').not.toBeNaN();
		expect(deadConfigs, 'Dead-configuration tile should render a number').not.toBeNaN();

		await expect(advisor.inventory(), 'Org-wide inventory should render when objects are masked').toBeVisible();
		const inventoryNames = await advisor.inventoryApiNames();
		expect(inventoryNames.length, 'Inventory should list at least one masked object').toBeGreaterThan(0);

		await advisor.drillIntoInventoryRow(inventoryNames[0]);
		await expect(advisor.objectWideBanner(), 'Clicking an inventory row should drill into the per-object view').toBeVisible();

		testInfo.annotations.push(
				{type: 'notes', description: `${objectsMasked} masked / ${deadConfigs} dead; inventory: ${inventoryNames.join(', ')}; drilled into ${inventoryNames[0]}`});
	});

	test('V91: Per-object view has no horizontal scroll at 1280x720 and renders the field sections', async({page}, testInfo) =>
	{
		await page.setViewportSize({width: 1280, height: 720});
		const advisor = new MaskingAdvisorPage(page);
		await advisor.navigate();
		await advisor.selectObject(TARGET_OBJECT);

		const perObject = await advisor.measureOverflow();
		expect(perObject.pageOverflow, `Per-object view should not scroll horizontally @1280 (${JSON.stringify(perObject)})`).toBeLessThanOrEqual(OVERFLOW_TOLERANCE);
		if(perObject.cardRight !== null)
		{
			expect(perObject.cardRight, 'Advisor card should not extend past the viewport').toBeLessThanOrEqual(perObject.innerWidth + OVERFLOW_TOLERANCE);
		}

		await advisor.objectWideBannerToggle().click();
		await page.waitForTimeout(500);
		const bannerOpen = await advisor.measureOverflow();
		expect(bannerOpen.pageOverflow, `Banner-open view should not scroll horizontally @1280 (${JSON.stringify(bannerOpen)})`).toBeLessThanOrEqual(OVERFLOW_TOLERANCE);

		await expect(advisor.sectionReady(), 'Account has recommended fields, so the Ready section should render').toBeVisible();
		await expect(advisor.fieldRow(MULTI_MASK_FIELD), 'The Phone field row should be present in a section').toBeVisible();

		// The Manual-review and Other sections render only when the object has fields in those buckets;
		// record which appeared rather than gating on a classification that varies by object.
		const manualReviewVisible = await advisor.sectionManualReview().isVisible().catch(() => false);
		const otherVisible = await advisor.sectionOther().isVisible().catch(() => false);

		testInfo.annotations.push({
			type: 'notes',
			description: `per-object overflow=${perObject.pageOverflow}px, banner-open overflow=${bannerOpen.pageOverflow}px; sections ready=true manual-review=${manualReviewVisible} other=${otherVisible}`
		});
	});

	test('V92: Object-wide banner toggles its expanded state and reveals the add-rule affordance', async({page}, testInfo) =>
	{
		const advisor = new MaskingAdvisorPage(page);
		await advisor.navigate();
		await advisor.selectObject(TARGET_OBJECT);

		const objectWide = await advisor.flipToggle(advisor.objectWideBannerToggle());
		expect(objectWide.before, 'Object-wide banner should start collapsed').toBe('false');
		expect(objectWide.after, 'Object-wide banner should expand on toggle').toBe('true');
		await expect(advisor.addObjectWideRule(), 'Expanded object-wide banner should reveal Add object-wide rule').toBeVisible();

		const reclosed = await advisor.flipToggle(advisor.objectWideBannerToggle());
		expect(reclosed.after, 'Object-wide banner should collapse on second toggle').toBe('false');

		// The configuration-health banner only renders when the object has inactive object-wide rules or
		// dead field targets. A healthy object exposes none, so assert the flip only when it is present.
		const healthBannerPresent = await advisor.healthBanner().isVisible().catch(() => false);
		if(healthBannerPresent)
		{
			const health = await advisor.flipToggle(advisor.healthBannerToggle());
			expect(health.before, 'Health banner should start collapsed').toBe('false');
			expect(health.after, 'Health banner should expand on toggle').toBe('true');
			testInfo.annotations.push({type: 'notes', description: 'Health banner present and toggled'});
		}
		else
		{
			testInfo.annotations.push({type: 'notes', description: `No configuration-health findings on ${TARGET_OBJECT} (expected for a healthy object)`});
		}
	});

	test('V93: Rule-detail modal opens, previews a masked value, and closes', async({page}, testInfo) =>
	{
		const advisor = new MaskingAdvisorPage(page);
		await advisor.navigate();
		await advisor.selectObject(TARGET_OBJECT);

		const trigger = await advisor.openRuleDetailFromField(MULTI_MASK_FIELD);
		await expect(advisor.ruleDetailModal(), 'Clicking a chip should open the rule-detail modal').toBeVisible();
		await expect(advisor.ruleDetailMaskedAfterDeploy(), 'A dormant candidate rule should offer the masked-after-deploy toggle').toBeVisible();

		const sample = '415-555-0142';
		const masked = await advisor.runRuleDetailPreview(sample);
		expect(masked.length, 'Preview should render a masked output').toBeGreaterThan(0);
		expect(masked, 'Masked output should differ from the plain input').not.toBe(sample);

		await advisor.ruleDetailDoneButton().click();
		await advisor.ruleDetailModal().waitFor({state: 'hidden', timeout: 10_000}).catch(() =>
		{
		});

		// Focus-return to the trigger chip is a LightningModal guarantee, already asserted in Jest and
		// flaky to observe headlessly; record it as context rather than gating the run on it.
		const focused = await advisor.deepActiveTestId().catch(() => null);
		testInfo.annotations.push({type: 'notes', description: `Preview ${sample} -> ${masked}; focus after close: ${focused}`});
	});

	test('V94: Add-rule menus list type-matching rules for a field and for object-wide scope', async({page}, testInfo) =>
	{
		const advisor = new MaskingAdvisorPage(page);
		await advisor.navigate();
		await advisor.selectObject(TARGET_OBJECT);

		await advisor.openAddRuleMenu(MULTI_MASK_FIELD);
		const fieldMenuItems = await advisor.addRuleMenuItems().count();
		expect(fieldMenuItems, 'Phone field add-rule menu should list type-matching rules').toBeGreaterThan(0);
		await expect(advisor.createCustomRule(), 'Add-rule menu should offer the create-custom-rule escape hatch').toBeVisible();
		await advisor.addRuleMenuClose().click();
		await advisor.addRuleMenu().waitFor({state: 'hidden', timeout: 10_000}).catch(() =>
		{
		});

		await advisor.objectWideBannerToggle().click();
		await page.waitForTimeout(500);
		await advisor.addObjectWideRule().click();
		await advisor.addRuleMenu().waitFor({state: 'visible', timeout: 20_000});
		const objectWideMenuItems = await advisor.addRuleMenuItems().count();
		expect(objectWideMenuItems, 'Object-wide add-rule menu should list rules').toBeGreaterThan(0);
		await advisor.addRuleMenuClose().click();

		testInfo.annotations.push({type: 'notes', description: `field menu items=${fieldMenuItems}, object-wide menu items=${objectWideMenuItems}`});
	});

	test('V95: Export modal builds a grouped change package with a deploy command and download', async({page}, testInfo) =>
	{
		const advisor = new MaskingAdvisorPage(page);
		await advisor.navigate();
		await advisor.selectObject(TARGET_OBJECT);

		// Account's recommended fields surface pre-ticked candidates, so changes are queued on arrival.
		expect(await advisor.isExportEnabled(), 'Pre-ticked candidates should queue changes and enable Export').toBe(true);
		await expect(advisor.summaryChanges(), 'Summary strip should report queued changes').toBeVisible();

		await advisor.openExport();
		await expect(advisor.changeSummary(), 'Export modal should summarise the change set').toBeVisible();

		const rows = await advisor.packageRowDescriptors();
		expect(rows.length, 'Export package should list at least one change row').toBeGreaterThan(0);
		const validVerbs = [
			'add',
			'disable',
			're-enable'
		];
		for(const row of rows)
		{
			expect(validVerbs, `Every package row should carry a recognised verb (got ${row.verb})`).toContain(row.verb);
		}

		await advisor.aliasInput().fill('MyScratchOrg');
		await page.waitForTimeout(500);
		const command = (await advisor.deployCommand().textContent()) || '';
		expect(command, 'Deploy command should weave in the supplied org alias').toContain('MyScratchOrg');

		await expect(advisor.downloadButton(), 'Download button should be available').toBeEnabled();
		const [download] = await Promise.all([
			page.waitForEvent('download', {timeout: 15_000}),
			advisor.downloadButton().click()
		]);
		expect(download.suggestedFilename(), 'Download should produce a .zip package').toMatch(/\.zip$/i);

		testInfo.annotations.push({type: 'notes', description: `${rows.length} package rows; zip=${download.suggestedFilename()}`});
	});

	test('V96: A phone field pre-ticks both phone rules and exports two Add rows', async({page}, testInfo) =>
	{
		const advisor = new MaskingAdvisorPage(page);
		await advisor.navigate();
		await advisor.selectObject(TARGET_OBJECT);

		const chips = await advisor.fieldChipDescriptors(MULTI_MASK_FIELD);
		const candidateRules = chips.filter((chip) => chip.origin === 'candidate' && chip.desired === 'true').map((chip) => chip.rule);
		expect(candidateRules, 'Phone should pre-tick the US phone rule as a candidate').toContain(PHONE_RULE_US);
		expect(candidateRules, 'Phone should pre-tick the international phone rule as a candidate').toContain(PHONE_RULE_INTERNATIONAL);

		await advisor.openExport();
		const rows = await advisor.packageRowDescriptors();
		const phoneAddRows = rows.filter((row) => row.verb === 'add' && /phone/i.test(row.text));
		expect(phoneAddRows.length, `Both phone rules should export as Add rows (got ${JSON.stringify(rows)})`).toBeGreaterThanOrEqual(2);
		const phoneAddText = phoneAddRows.map((row) => row.text).join(' | ');
		expect(phoneAddText, 'A US phone Add row should be present').toMatch(/US Phone/i);
		expect(phoneAddText, 'An international phone Add row should be present').toMatch(/International Phone/i);

		testInfo.annotations.push({type: 'notes', description: `candidate chips=${candidateRules.join(', ')}; phone Add rows=${phoneAddRows.length}`});
	});

	test('V97: Health Check surfaces the Data Masking posture and deep-links to the advisor', async({page}, testInfo) =>
	{
		// Reach the Kern app's home page namespace-agnostically: the app is `Kern` unmanaged and
		// `kern__Kern` on a subscriber, so resolve the prefix the same way the advisor tab does.
		const advisorForNamespace = new MaskingAdvisorPage(page);
		await ensureAuthenticated(page);
		await page.goto(`${getInstanceUrl()}/lightning/app/${advisorForNamespace.namespacePrefix()}Kern`, {waitUntil: 'domcontentloaded'});
		await waitForLightningReady(page);

		const home = new KernHomePage(page);
		await home.navigate();

		const healthCheck = home.healthCheck();
		await healthCheck.waitFor({state: 'visible', timeout: 15_000});
		await waitForSpinnerGone(page);

		// "Data Masking" renders as a passing chip on a healthy org, an action item under Warn, or is
		// folded into the all-pass banner when every check passes — assert the masking check is wired
		// across all three renderings.
		const allPass = await healthCheck.locator('[data-testid="health-check-all-pass"]').isVisible().catch(() => false);
		if(!allPass)
		{
			await expect(healthCheck.getByText(MASKING_CHECK_NAME, {exact: false}).first(), 'Data Masking posture should render among the health-check results').toBeVisible();
		}

		const actionButton = home.healthCheckActionButton(MASKING_CHECK_NAME);
		const hasReviewAction = await actionButton.isVisible().catch(() => false);
		if(hasReviewAction)
		{
			// Warn posture: the masking check warns only when an active target masks nothing or no object
			// carries active masking, and then offers the Review-masking action, which deep-links in-app
			// into the advisor tab. Exercise the click-through when that posture is present.
			await actionButton.click();
			await page.locator('[data-testid="add-object-button"]').waitFor({state: 'visible', timeout: 30_000});
			testInfo.annotations.push({type: 'notes', description: 'Review-masking action navigated in-app to the Data Masking Advisor (Warn posture)'});
		}
		else
		{
			// Pass posture: the framework ships active object-wide masking on its own objects, so a clean
			// install reports a healthy posture and surfaces no Review-masking action. The action appears
			// only once masking config goes dead or empty; here verify the deep-link target resolves directly.
			await advisorForNamespace.navigate();
			await expect(advisorForNamespace.addObjectButton(), 'Review-masking deep-link target (advisor tab) should resolve').toBeVisible();
			testInfo.annotations.push({
				type: 'notes', description: 'Masking posture Pass — Review-masking action surfaces only when config is dead or empty; advisor deep-link target verified directly'
			});
		}
	});

	test('V98: Data Masking Health Check value flips Pass to Warn to Pass when masking config changes', async({page}, testInfo) =>
	{
		// Two bundle deploys plus refreshes — well beyond the default per-test budget.
		test.setTimeout(300_000);

		const advisorForNamespace = new MaskingAdvisorPage(page);
		const namespacePrefix = advisorForNamespace.namespacePrefix();

		// The Warn-inducing bundle carries namespace-qualified rule references (kern__...), so it deploys
		// only on a managed subscriber install. On the no-namespace unmanaged org the masking-posture
		// value-change is covered by the scripted section-76 round-trip (posture counts); the rendered
		// tick flip is proven here on the subscriber.
		test.skip(namespacePrefix === '', 'Masking-posture value-change uses the namespaced subscriber bundles; covered on the subscriber org.');

		await ensureAuthenticated(page);
		await page.goto(`${getInstanceUrl()}/lightning/app/${namespacePrefix}Kern`, {waitUntil: 'domcontentloaded'});
		await waitForLightningReady(page);

		const home = new KernHomePage(page);
		await home.navigate();
		const healthCheck = home.healthCheck();
		await healthCheck.waitFor({state: 'visible', timeout: 15_000});
		await waitForSpinnerGone(page);

		const maskingAction = home.healthCheckActionButton(MASKING_CHECK_NAME);

		// Baseline: the package ships active object-wide masking on its own objects, so the posture passes
		// and renders as a passing chip with no Review-masking action — the green tick the operator
		// normally sees. Poll so an initial load settles before asserting.
		await expect.poll(async() => home.readHealthCheckPosture(MASKING_CHECK_NAME), {timeout: 20_000, message: 'Baseline masking posture should render as Pass'}).toBe('pass');

		let restored = false;
		try
		{
			// Deploy a dead configuration (an active target bound to a dormant rule): deadConfigCount goes
			// 0 -> 1, which is the masking-posture Warn branch in CTRL_HealthCheck.checkMaskingPosture.
			deployMetadataDir(path.join(MASKING_ADVISOR_BUNDLES_DIR, 'create'));

			// Re-run the check until it recomputes (absorbing CMDT propagation): the tick is no longer green
			// — masking now surfaces the Review-masking action under Warn. This is the value-change proof:
			// the rendered Health Check result, not just the posture counts.
			await home.refreshUntilHealthCheckPosture(MASKING_CHECK_NAME, 'warn');
			await expect(maskingAction, 'A dead masking config must flip the tick to Warn and surface the Review-masking action').toBeVisible();
			const warnItems = await home.getHealthCheckActionItems();
			expect(warnItems.some((item) => item.name === MASKING_CHECK_NAME && !item.isPass),
					`Masking should render as a non-passing action item once config is dead (got ${JSON.stringify(warnItems)})`).toBe(true);

			// Restore: disabling the probes returns deadConfigCount to 0 — the Pass branch.
			deployMetadataDir(path.join(MASKING_ADVISOR_BUNDLES_DIR, 'disable'));
			restored = true;
			await home.refreshUntilHealthCheckPosture(MASKING_CHECK_NAME, 'pass');
			await expect(maskingAction, 'Restoring the config must recover the masking tick to Pass (no Review-masking action)').toBeHidden();

			testInfo.annotations.push({
				type: 'notes',
				description: 'Masking Health Check value changed Pass -> Warn -> Pass driven by config deploys (dead config added then removed) — the rendered tick flip, not only posture counts.'
			});
		}
		finally
		{
			if(!restored)
			{
				// Ensure the org returns to its Pass baseline even if a Warn-state assertion failed mid-test.
				// Guard the cleanup so a cleanup-deploy failure logs loudly without masking the original error.
				try
				{
					deployMetadataDir(path.join(MASKING_ADVISOR_BUNDLES_DIR, 'disable'));
				}
				catch(cleanupError)
				{
					console.error('V98 cleanup deploy failed — the subscriber org may retain a dead masking config:', cleanupError.message);
				}
			}
		}
	});
});
