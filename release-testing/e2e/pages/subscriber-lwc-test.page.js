// SPDX-License-Identifier: BUSL-1.1
const {waitForLightningReady} = require('../helpers/sf-navigation');
const {ensureAuthenticated, getInstanceUrl} = require('../helpers/sf-auth');
const {waitForSpinnerGone} = require('../helpers/wait-helpers');

const EXPECTED_COMPONENTS = [
	'subscriberBaseOnly',
	'subscriberNotification',
	'subscriberController',
	'subscriberNavigation',
	'subscriberLightningMessage',
	'subscriberFlowNavigation',
	'subscriberAllModules',
	'subscriberControllerIntegration',
	'subscriberUtilityTest',
	'subscriberModuleCombinations',
	'subscriberLoggerTest',
	'subscriberFeatureFlag',
	'subscriberErrorReducer'
];

const MODULE_SECTIONS = [
	'subscriberNotification',
	'subscriberController',
	'subscriberNavigation',
	'subscriberLightningMessage',
	'subscriberFlowNavigation',
	'subscriberAllModules',
	'subscriberBaseOnly',
	'subscriberFeatureFlag'
];

const INTEGRATION_SECTIONS = [
	'subscriberControllerIntegration',
	'subscriberUtilityTest',
	'subscriberModuleCombinations',
	'subscriberErrorReducer'
];

class SubscriberLwcTestPage
{
	constructor(page)
	{
		this.page = page;
	}

	async navigate()
	{
		await ensureAuthenticated(this.page);
		const instanceUrl = getInstanceUrl();
		await this.page.goto(`${instanceUrl}/lightning/n/SubscriberLwcTestPage`, {waitUntil: 'domcontentloaded'});
		await waitForLightningReady(this.page);
		await waitForSpinnerGone(this.page);
		const firstComponent = this.getComponentLocator(EXPECTED_COMPONENTS[0]);
		await firstComponent.waitFor({state: 'visible', timeout: 15_000}).catch(() =>
		{
		});
	}

	getComponentLocator(name)
	{
		const kebabName = name.replace(/([A-Z])/g, '-$1').toLowerCase().replace(/^-/, '');
		return this.page.locator(`c-${kebabName}`);
	}

	async getVisibleComponents()
	{
		const visible = [];
		for(const name of EXPECTED_COMPONENTS)
		{
			const component = this.getComponentLocator(name);
			if(await component.isVisible().catch(() => false))
			{
				visible.push(name);
			}
		}
		return visible;
	}

	async allComponentsVisible()
	{
		const visible = await this.getVisibleComponents();
		return visible.length === EXPECTED_COMPONENTS.length;
	}

	async hasErrorBoundaries()
	{
		const errors = this.page.locator('aura-component-error, .error-boundary');
		const errorText = this.page.getByText('An error occurred');
		return (await errors.count()) > 0 || (await errorText.count()) > 0;
	}

	async runSectionTests(componentName)
	{
		const section = this.getComponentLocator(componentName);
		const button = section.getByRole('button', {name: 'Run Tests'});
		await button.click();
		await section.locator('li').first().waitFor({state: 'visible', timeout: 15_000}).catch(() =>
		{
		});
	}

	async getSectionResults(componentName)
	{
		const section = this.getComponentLocator(componentName);
		const items = section.locator('li');
		return items.allTextContents();
	}

	async allSectionTestsPassing(componentName)
	{
		const results = await this.getSectionResults(componentName);
		return results.length > 0 && results.every(r => r.includes('PASS'));
	}

	async getFailedTests(componentName)
	{
		const results = await this.getSectionResults(componentName);
		return results.filter(r => r.includes('FAIL'));
	}

	async runAndVerifySection(componentName)
	{
		await this.runSectionTests(componentName);
		const results = await this.getSectionResults(componentName);
		const failed = results.filter(r => r.includes('FAIL'));
		return {total: results.length, passed: results.length - failed.length, failed: failed.length, failures: failed};
	}
}

SubscriberLwcTestPage.EXPECTED_COMPONENTS = EXPECTED_COMPONENTS;
SubscriberLwcTestPage.MODULE_SECTIONS = MODULE_SECTIONS;
SubscriberLwcTestPage.INTEGRATION_SECTIONS = INTEGRATION_SECTIONS;
module.exports = SubscriberLwcTestPage;
