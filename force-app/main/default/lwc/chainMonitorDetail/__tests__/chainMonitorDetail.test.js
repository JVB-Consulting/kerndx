// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for chainMonitorDetail LWC component
 * @author Jason van Beukering
 * @date April 2026, May 2026
 */

import {createElement} from 'lwc';
import {mockCallControllerMethod, mockShowSuccessToast} from 'c/componentBuilder';

const mockCopyToClipBoard = jest.fn().mockResolvedValue(undefined);

jest.mock('c/utilitySystem', () => ({
	copyToClipBoard: (...args) => mockCopyToClipBoard(...args)
}), {virtual: true});

/*
 * Note on `global.__lwcJestMock_getChainDetail`:
 *
 * The @lwc/jest-transformer rewrites `import getChainDetail from '@salesforce/apex/...'`
 * into a try/catch whose catch block sets
 *   `global.__lwcJestMock_getChainDetail = global.__lwcJestMock_getChainDetail || function getChainDetail() {...};`.
 *
 * The first test (`exercises the transformer fallback stub when global slot is empty`)
 * loads the component in an isolated module registry before any other code has
 * referenced the module, so the catch block's `||` expression evaluates the RHS
 * function fallback. All later tests use `require('c/chainMonitorDetail').default`
 * directly — the module is then cached so the catch block is not re-entered.
 */

const MOCK_DETAIL = {
	executionId: 'a00000000000001AAA',
	chainName: 'TestChain',
	status: 'Completed',
	totalSteps: 3,
	completedSteps: 3,
	errorMessage: null,
	startedAt: '2026-04-08T14:00:00.000Z',
	completedAt: '2026-04-08T14:00:45.000Z',
	durationMs: 45000,
	durationLabel: '45s',
	correlationId: 'test-correlation-id',
	steps: [
		{name: 'Step 1', stepStatus: 'success', durationLabel: '0.8s', errorMessage: null},
		{name: 'Step 2', stepStatus: 'success', durationLabel: '2.1s', errorMessage: null},
		{name: 'Step 3', stepStatus: 'success', durationLabel: '0.3s', errorMessage: null}
	]
};

const MOCK_FAILED_DETAIL = {
	...MOCK_DETAIL, status: 'Failed', errorMessage: 'System.NullPointerException: Attempt to de-reference a null object', completedSteps: 1
};

describe('c-chain-monitor-detail', () =>
{
	afterAll(() =>
	{
		delete global.__lwcJestMock_getChainDetail;
	});

	afterEach(() =>
	{
		while(document.body.firstChild)
		{
			document.body.removeChild(document.body.firstChild);
		}
		jest.clearAllMocks();
	});

	async function createComponent(executionId = null)
	{
		mockCallControllerMethod.mockResolvedValue(executionId ? MOCK_DETAIL : null);

		const ChainMonitorDetail = require('c/chainMonitorDetail').default;
		const element = createElement('c-chain-monitor-detail', {is: ChainMonitorDetail});

		if(executionId)
		{
			element.executionId = executionId;
		}

		document.body.appendChild(element);
		await Promise.resolve();
		await Promise.resolve();
		return element;
	}

	/*
	 * These two tests MUST run before any other test that loads chainMonitorDetail
	 * via `createComponent`. They force the @lwc/jest-transformer catch block to run
	 * by making the apex import throw, and they stub chainStepTimeline (which shares
	 * the same apex import and would otherwise pre-populate the global slot via its
	 * own catch block before this component's catch runs).
	 * Together they exercise both sides of the transformer-emitted
	 * `global.__lwcJestMock_getChainDetail || function getChainDetail() {...}`.
	 */
	describe('apex-stub fallback (jest-transformer catch block)', () =>
	{
		const stubApexImport = () =>
		{
			jest.doMock('@salesforce/apex/CTRL_ChainMonitor.getChainDetail', () =>
			{
				throw new Error('forced require failure');
			}, {virtual: true});
			jest.doMock('c/chainStepTimeline', () => ({__esModule: true, default: null}), {virtual: true});
		};

		afterEach(() =>
		{
			jest.dontMock('c/chainStepTimeline');
			jest.dontMock('@salesforce/apex/CTRL_ChainMonitor.getChainDetail');
			delete global.__lwcJestMock_getChainDetail;
		});

		it('uses the pre-set global.__lwcJestMock_getChainDetail when present', () =>
		{
			const fallback = jest.fn().mockResolvedValue(null);
			global.__lwcJestMock_getChainDetail = fallback;

			let loaded;
			jest.isolateModules(() =>
			{
				stubApexImport();
				loaded = require('c/chainMonitorDetail').default;
			});

			expect(typeof loaded).toBe('function');
			expect(global.__lwcJestMock_getChainDetail).toBe(fallback);
		});

		it('generates the stub function when the global slot is empty', () =>
		{
			delete global.__lwcJestMock_getChainDetail;

			let loaded;
			jest.isolateModules(() =>
			{
				stubApexImport();
				loaded = require('c/chainMonitorDetail').default;
			});

			expect(typeof loaded).toBe('function');
			expect(typeof global.__lwcJestMock_getChainDetail).toBe('function');
		});
	});

	it('should show placeholder when no execution selected', async() =>
	{
		const element = await createComponent();

		const placeholder = element.shadowRoot.querySelector('.slds-text-heading_medium');
		expect(placeholder).toBeTruthy();
		expect(placeholder.textContent).toContain('Select a chain');
	});

	it('should render chain name when execution loaded', async() =>
	{
		const element = await createComponent('a00000000000001AAA');

		const heading = element.shadowRoot.querySelector('.slds-text-heading_small');
		expect(heading).toBeTruthy();
		expect(heading.textContent).toBe('TestChain');
	});

	it('should render progress bar', async() =>
	{
		const element = await createComponent('a00000000000001AAA');

		const progressBar = element.shadowRoot.querySelector('lightning-progress-bar');
		expect(progressBar).toBeTruthy();
	});

	it('should render step timeline child component', async() =>
	{
		const element = await createComponent('a00000000000001AAA');

		const timeline = element.shadowRoot.querySelector('c-chain-step-timeline');
		expect(timeline).toBeTruthy();
	});

	it('should not show error section when no error', async() =>
	{
		const element = await createComponent('a00000000000001AAA');

		const errorSection = element.shadowRoot.querySelector('.slds-text-color_error');
		expect(errorSection).toBeFalsy();
	});

	it('should show error section when chain has error', async() =>
	{
		mockCallControllerMethod.mockResolvedValue(MOCK_FAILED_DETAIL);
		const ChainMonitorDetail = require('c/chainMonitorDetail').default;
		const element = createElement('c-chain-monitor-detail', {is: ChainMonitorDetail});
		element.executionId = 'a00000000000001AAA';
		document.body.appendChild(element);
		await Promise.resolve();
		await Promise.resolve();

		const errorSection = element.shadowRoot.querySelector('.slds-theme_error');
		expect(errorSection).toBeTruthy();
		expect(errorSection.textContent).toContain('NullPointerException');
	});

	it('should copy correlation id to clipboard when button clicked', async() =>
	{
		const element = await createComponent('a00000000000001AAA');

		const copyButton = element.shadowRoot.querySelector('lightning-button-icon');
		copyButton.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();
		await Promise.resolve();
		await Promise.resolve();
		await Promise.resolve();
		await Promise.resolve();

		expect(mockCopyToClipBoard).toHaveBeenCalledWith('test-correlation-id');
		expect(mockShowSuccessToast).toHaveBeenCalledWith('Correlation ID copied');
	});

	it('should clear detail when executionId set to null', async() =>
	{
		const element = await createComponent('a00000000000001AAA');

		element.executionId = null;
		await Promise.resolve();

		const placeholder = element.shadowRoot.querySelector('.slds-text-color_weak');
		expect(placeholder).toBeTruthy();
	});

	it('should reload data on refresh api call', async() =>
	{
		const element = await createComponent('a00000000000001AAA');
		mockCallControllerMethod.mockClear();

		await element.refresh();

		expect(mockCallControllerMethod).toHaveBeenCalled();
	});

	it('should show progress label', async() =>
	{
		const element = await createComponent('a00000000000001AAA');

		const progressText = element.shadowRoot.querySelector('.slds-text-body_small');
		expect(progressText.textContent).toContain('3/3 steps');
	});

	it('should return executionId from getter', async() =>
	{
		const element = await createComponent('a00000000000001AAA');

		expect(element.executionId).toBe('a00000000000001AAA');
	});

	it('should handle zero total steps in progress bar', async() =>
	{
		mockCallControllerMethod.mockResolvedValue({...MOCK_DETAIL, totalSteps: 0, completedSteps: 0});
		const ChainMonitorDetail = require('c/chainMonitorDetail').default;
		const element = createElement('c-chain-monitor-detail', {is: ChainMonitorDetail});
		element.executionId = 'a00000000000001AAA';
		document.body.appendChild(element);
		await Promise.resolve();
		await Promise.resolve();

		const progressBar = element.shadowRoot.querySelector('lightning-progress-bar');
		expect(progressBar.value).toBe(0);
	});

	it('should not refresh when no executionId set', async() =>
	{
		const element = await createComponent();
		mockCallControllerMethod.mockClear();

		await element.refresh();

		expect(mockCallControllerMethod).not.toHaveBeenCalled();
	});

	it('should not copy when no correlationId', async() =>
	{
		mockCallControllerMethod.mockResolvedValue({...MOCK_DETAIL, correlationId: null});
		const ChainMonitorDetail = require('c/chainMonitorDetail').default;
		const element = createElement('c-chain-monitor-detail', {is: ChainMonitorDetail});
		element.executionId = 'a00000000000001AAA';
		document.body.appendChild(element);
		await Promise.resolve();
		await Promise.resolve();

		const copyButton = element.shadowRoot.querySelector('lightning-button-icon');
		if(copyButton)
		{
			copyButton.dispatchEvent(new CustomEvent('click'));
			await Promise.resolve();
		}

		expect(mockCopyToClipBoard).not.toHaveBeenCalled();
	});

	it('should use fallback icon for unknown status', async() =>
	{
		mockCallControllerMethod.mockResolvedValue({...MOCK_DETAIL, status: 'Unknown'});
		const ChainMonitorDetail = require('c/chainMonitorDetail').default;
		const element = createElement('c-chain-monitor-detail', {is: ChainMonitorDetail});
		element.executionId = 'a00000000000001AAA';
		document.body.appendChild(element);
		await Promise.resolve();
		await Promise.resolve();

		const icon = element.shadowRoot.querySelector('lightning-icon');
		expect(icon.iconName).toBe('utility:question');
	});

	it('should show completed date when chain is finished', async() =>
	{
		const element = await createComponent('a00000000000001AAA');

		const dtElements = element.shadowRoot.querySelectorAll('dt');
		const labels = Array.from(dtElements).map(el => el.textContent);
		expect(labels).toContain('Completed');
	});

	it('should hide completed date when chain is running', async() =>
	{
		mockCallControllerMethod.mockResolvedValue({...MOCK_DETAIL, status: 'Running', completedAt: null});
		const ChainMonitorDetail = require('c/chainMonitorDetail').default;
		const element = createElement('c-chain-monitor-detail', {is: ChainMonitorDetail});
		element.executionId = 'a00000000000001AAA';
		document.body.appendChild(element);
		await Promise.resolve();
		await Promise.resolve();

		const dtElements = element.shadowRoot.querySelectorAll('dt');
		const labels = Array.from(dtElements).map(el => el.textContent);
		expect(labels).not.toContain('Completed');
	});

});
