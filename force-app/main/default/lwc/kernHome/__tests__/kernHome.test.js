// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for the kernHome composite LWC.
 *
 * @author Jason van Beukering
 * @date April 2026, August 2026
 */
import {createElement} from 'lwc';
import KernHome from 'c/kernHome';
import {mockNavigate, mockCallControllerMethod} from 'c/componentBuilder';

jest.mock('@salesforce/label/c.KernHome_AdministrationToolsHeading', () => ({default: 'Administration Tools'}), {virtual: true});
jest.mock('@salesforce/label/c.KernHome_ToolOpenButton', () => ({default: 'Open'}), {virtual: true});
jest.mock('@salesforce/label/c.KernHome_ToolOpenButtonWithName', () => ({default: 'Open {0}'}), {virtual: true});
jest.mock('@salesforce/label/c.KernHome_ApiTestHarness_Title', () => ({default: 'API Test Harness'}), {virtual: true});
jest.mock('@salesforce/label/c.KernHome_ApiTestHarness_Description', () => ({default: 'Test inbound and outbound API calls...'}), {virtual: true});
jest.mock('@salesforce/label/c.KernHome_StreamingMonitor_Title', () => ({default: 'Streaming Event Monitor'}), {virtual: true});
jest.mock('@salesforce/label/c.KernHome_StreamingMonitor_Description', () => ({default: 'Monitor platform events...'}), {virtual: true});
jest.mock('@salesforce/label/c.KernHome_ChainMonitor_Title', () => ({default: 'Chain Monitor'}), {virtual: true});
jest.mock('@salesforce/label/c.KernHome_ChainMonitor_Description', () => ({default: 'Monitor async chain executions...'}), {virtual: true});
jest.mock('@salesforce/label/c.KernHome_DataMaskingAdvisor_Title', () => ({default: 'Data Masking Advisor'}), {virtual: true});
jest.mock('@salesforce/label/c.KernHome_DataMaskingAdvisor_Description', () => ({default: 'Surface sensitive fields, preview rule output...'}), {virtual: true});
jest.mock('@salesforce/label/c.KernHome_LogConsole_Title', () => ({default: 'Log Console'}), {virtual: true});
jest.mock('@salesforce/label/c.KernHome_LogConsole_Description', () => ({default: 'Browse and group log entries...'}), {virtual: true});

describe('c-kern-home', () =>
{
	afterEach(() =>
	{
		while(document.body.firstChild)
		{
			document.body.removeChild(document.body.firstChild);
		}
		jest.clearAllMocks();
	});

	async function createComponent()
	{
		mockCallControllerMethod.mockResolvedValue([]);

		const element = createElement('c-kern-home', {is: KernHome});
		document.body.appendChild(element);
		await Promise.resolve();
		await Promise.resolve();
		return element;
	}

	it('should render the health check component', async() =>
	{
		const element = await createComponent();

		const healthCheck = element.shadowRoot.querySelector('c-health-check');
		expect(healthCheck).toBeTruthy();
	});

	function getToolCards(element)
	{
		return Array.from(element.shadowRoot.querySelectorAll('article[data-testid="tool-card"]'));
	}

	function getToolTitles(element)
	{
		return Array.from(element.shadowRoot.querySelectorAll('[data-testid="tool-card-title"]'));
	}

	it('should render an outer Administration Tools card', async() =>
	{
		const element = await createComponent();

		const allCards = element.shadowRoot.querySelectorAll('lightning-card');
		const outerCard = Array.from(allCards).find((card) => card.title === 'Administration Tools');
		expect(outerCard).toBeTruthy();
		expect(outerCard.iconName).toBe('utility:setup');
	});

	it('should render five tool cards inside the Administration Tools card', async() =>
	{
		const element = await createComponent();

		const toolCards = getToolCards(element);
		expect(toolCards).toHaveLength(5);
	});

	it('should render the expected tool titles', async() =>
	{
		const element = await createComponent();

		const toolTitles = getToolTitles(element).map((title) => title.textContent);
		expect(toolTitles).toEqual([
			'API Test Harness',
			'Streaming Event Monitor',
			'Chain Monitor',
			'Data Masking Advisor',
			'Log Console'
		]);
	});

	it('should render the expected icon names on each tool card (matching their tab motifs)', async() =>
	{
		const element = await createComponent();

		const toolIcons = getToolCards(element).map((card) => card.querySelector('lightning-icon').iconName);
		expect(toolIcons).toEqual([
			'custom:custom63',
			'custom:custom30',
			'custom:custom57',
			'custom:custom91',
			'custom:custom7'
		]);
	});

	it('should title each tool tile one heading level below the Administration Tools section heading', async() =>
	{
		const element = await createComponent();

		const toolTitles = getToolTitles(element);
		expect(toolTitles).toHaveLength(5);
		toolTitles.forEach((title) => expect(title.tagName).toBe('H3'));
	});

	it('should keep the Administration Tools card as the only card on the page, so the tiles do not repeat its heading level', async() =>
	{
		const element = await createComponent();

		const cards = element.shadowRoot.querySelectorAll('lightning-card');
		expect(cards).toHaveLength(1);
		expect(element.shadowRoot.querySelectorAll('h2')).toHaveLength(0);
	});

	it('should let a long tool heading wrap rather than truncate it behind an ellipsis', async() =>
	{
		const element = await createComponent();

		getToolTitles(element).forEach((title) =>
		{
			expect(title.className).toContain('tool-card-title');
			expect(title.className).not.toContain('slds-truncate');
		});
	});

	it('should name each Open button after the tool it opens, so five identical labels are still distinguishable', async() =>
	{
		const element = await createComponent();

		const buttons = Array.from(element.shadowRoot.querySelectorAll('lightning-button[data-key]'));
		expect(buttons.map((button) => button.label)).toEqual([
			'Open',
			'Open',
			'Open',
			'Open',
			'Open'
		]);
		expect(buttons.map((button) => button.getAttribute('aria-label'))).toEqual([
			'Open API Test Harness',
			'Open Streaming Event Monitor',
			'Open Chain Monitor',
			'Open Data Masking Advisor',
			'Open Log Console'
		]);
	});

	it('should navigate to the api test harness tab when the open button is clicked', async() =>
	{
		const element = await createComponent();

		const button = element.shadowRoot.querySelector('lightning-button[data-key="apiTestHarness"]');
		button.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();

		expect(mockNavigate).toHaveBeenCalledWith(expect.objectContaining({
			type: 'standard__navItemPage', attributes: {apiName: 'ApiTestHarness'}
		}));
	});

	it('should navigate to the streaming event monitor page when the open button is clicked', async() =>
	{
		const element = await createComponent();

		const button = element.shadowRoot.querySelector('lightning-button[data-key="streamingMonitor"]');
		button.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();

		expect(mockNavigate).toHaveBeenCalledWith(expect.objectContaining({
			type: 'standard__navItemPage', attributes: {apiName: 'StreamingEventMonitor'}
		}));
	});

	it('should navigate to the chain monitor page when the open button is clicked', async() =>
	{
		const element = await createComponent();

		const button = element.shadowRoot.querySelector('lightning-button[data-key="chainMonitor"]');
		button.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();

		expect(mockNavigate).toHaveBeenCalledWith(expect.objectContaining({
			type: 'standard__navItemPage', attributes: {apiName: 'ChainMonitor'}
		}));
	});

	it('should navigate to the data masking advisor page when the open button is clicked', async() =>
	{
		const element = await createComponent();

		const button = element.shadowRoot.querySelector('lightning-button[data-key="dataMaskingAdvisor"]');
		button.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();

		expect(mockNavigate).toHaveBeenCalledWith(expect.objectContaining({
			type: 'standard__navItemPage', attributes: {apiName: 'DataMaskingAdvisor'}
		}));
	});

	it('should navigate to the log console page when the open button is clicked', async() =>
	{
		const element = await createComponent();

		const button = element.shadowRoot.querySelector('lightning-button[data-key="logConsole"]');
		button.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();

		expect(mockNavigate).toHaveBeenCalledWith(expect.objectContaining({
			type: 'standard__navItemPage', attributes: {apiName: 'LogConsole'}
		}));
	});

});
