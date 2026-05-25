// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for the kernHome composite LWC.
 *
 * @author Jason van Beukering
 * @date April 2026, May 2026
 */
import {createElement} from 'lwc';
import KernHome from 'c/kernHome';
import {mockNavigate, mockCallControllerMethod} from 'c/componentBuilder';

jest.mock('c/classTypeResolverSetupModal', () => ({
	__esModule: true, default: {open: jest.fn().mockResolvedValue(undefined)}
}), {virtual: true});

jest.mock('@salesforce/label/c.KernHome_AdministrationToolsHeading', () => ({default: 'Administration Tools'}), {virtual: true});
jest.mock('@salesforce/label/c.KernHome_ToolOpenButton', () => ({default: 'Open'}), {virtual: true});
jest.mock('@salesforce/label/c.KernHome_ApiTestHarness_Title', () => ({default: 'API Test Harness'}), {virtual: true});
jest.mock('@salesforce/label/c.KernHome_ApiTestHarness_Description', () => ({default: 'Test inbound and outbound API calls...'}), {virtual: true});
jest.mock('@salesforce/label/c.KernHome_StreamingMonitor_Title', () => ({default: 'Streaming Event Monitor'}), {virtual: true});
jest.mock('@salesforce/label/c.KernHome_StreamingMonitor_Description', () => ({default: 'Monitor platform events...'}), {virtual: true});
jest.mock('@salesforce/label/c.KernHome_ChainMonitor_Title', () => ({default: 'Chain Monitor'}), {virtual: true});
jest.mock('@salesforce/label/c.KernHome_ChainMonitor_Description', () => ({default: 'Monitor async chain executions...'}), {virtual: true});

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
		return Array.from(element.shadowRoot.querySelectorAll('lightning-card'))
		.filter((card) => card.title !== 'Administration Tools');
	}

	it('should render an outer Administration Tools card', async() =>
	{
		const element = await createComponent();

		const allCards = element.shadowRoot.querySelectorAll('lightning-card');
		const outerCard = Array.from(allCards).find((card) => card.title === 'Administration Tools');
		expect(outerCard).toBeTruthy();
		expect(outerCard.iconName).toBe('utility:setup');
	});

	it('should render three tool cards inside the Administration Tools card', async() =>
	{
		const element = await createComponent();

		const toolCards = getToolCards(element);
		expect(toolCards).toHaveLength(3);
	});

	it('should render the expected tool titles', async() =>
	{
		const element = await createComponent();

		const toolCards = getToolCards(element);
		expect(toolCards[0].title).toBe('API Test Harness');
		expect(toolCards[1].title).toBe('Streaming Event Monitor');
		expect(toolCards[2].title).toBe('Chain Monitor');
	});

	it('should render the expected icon names on each tool card (matching their tab motifs)', async() =>
	{
		const element = await createComponent();

		const toolCards = getToolCards(element);
		expect(toolCards[0].iconName).toBe('custom:custom63');
		expect(toolCards[1].iconName).toBe('custom:custom30');
		expect(toolCards[2].iconName).toBe('custom:custom57');
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

});
