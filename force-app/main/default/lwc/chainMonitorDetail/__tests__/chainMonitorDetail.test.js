// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for chainMonitorDetail LWC component
 * @author Jason van Beukering
 * @date April 2026, July 2026
 */

import {createElement} from 'lwc';
// noinspection JSUnresolvedReference - mock helpers are provided by the c/componentBuilder jest mock at run time
import {mockCallControllerMethod, mockNavigate, mockShowErrorToast, mockShowSuccessToast} from 'c/componentBuilder';
import ChainAbortModal from 'c/chainAbortModal';

// Spy-on-real: the static open lives on the real module (lightning/modal resolves to the repo's
// moduleNameMapper mock), so the interception survives the resolver-cache flip that silently
// defeats a jest.mock('c/...') of the same module (see moduleController.test.js).
const mockChainAbortModalOpen = jest.spyOn(ChainAbortModal, 'open').mockResolvedValue({action: 'cancel'});

const mockCopyToClipBoard = jest.fn().mockResolvedValue(undefined);

jest.mock('c/utilitySystem', () => ({
	copyToClipBoard: (...args) => mockCopyToClipBoard(...args)
}));

jest.mock('@salesforce/label/c.ChainMonitor_ViewLogsAction', () => ({default: 'View logs'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_CopyFailed', () => ({default: 'Couldn\'t copy to the clipboard. Try again or copy the value manually.'}), {virtual: true});
// The progress badge carries {0}/{1} placeholders; the real template value keeps the '3/3 steps'
// assertion an end-to-end check of formatTemplateString. The rest mirror their in-org values so
// the DOM-text and toast-title assertions verify byte-faithful wiring, not a bare label id.
jest.mock('@salesforce/label/c.ChainMonitor_ProgressSteps', () => ({default: '{0}/{1} steps'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_CorrelationCopied', () => ({default: 'Correlation ID copied'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_StepsSection', () => ({default: 'Steps'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_TimingSection', () => ({default: 'Timing'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_Started', () => ({default: 'Started'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_CompletedLabel', () => ({default: 'Completed'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_Duration', () => ({default: 'Duration'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_CorrelationIdLabel', () => ({default: 'Correlation ID'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_ErrorSection', () => ({default: 'Error'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_EmptyStateHeading', () => ({default: 'Select a chain'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_EmptyStateBody', () => ({default: 'Choose a chain execution from the list to view step details.'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_AbortAction', () => ({default: 'Abort'}), {virtual: true});
// The modal body carries {0}/{1} placeholders; the real template value keeps the confirm-path body
// assertion an end-to-end check of formatTemplateString over the chain name and progress label.
jest.mock('@salesforce/label/c.ChainMonitor_AbortModalBody', () => ({default: '{0} has completed {1}. The running step finishes, then the chain stops and cannot be resumed.'}),
		{virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_AbortModalTitle', () => ({default: 'Abort this chain?'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_AbortConfirmButton', () => ({default: 'Abort chain'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_AbortCancelButton', () => ({default: 'Cancel'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_AbortSuccessToast', () => ({default: 'Abort recorded. The chain stops at its next step boundary.'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_AbortUnavailableDisabled',
		() => ({default: 'Aborting chains is switched off for this org. An administrator can enable it by activating the Async Chain Abort Enabled feature flag.'}),
		{virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_AbortUnavailableMissingPermission',
		() => ({default: 'You do not have permission to abort chains. Ask an administrator for the Kern Async Chain Abort permission set.'}), {virtual: true});
// The five shipped status labels mirror their in-org values (the raw status equals the label text),
// so the DOM-text assertions verify the badge is wired through Labels, not that a raw value happens
// to match. The two conflict labels carry the neutral D20 badge + tooltip copy verbatim.
jest.mock('@salesforce/label/c.ChainMonitor_StatusRunning', () => ({default: 'Running'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_StatusCompleted', () => ({default: 'Completed'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_StatusFailed', () => ({default: 'Failed'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_StatusAborted', () => ({default: 'Aborted'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_StatusStalled', () => ({default: 'Stalled'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_StatusConflict', () => ({default: 'Ended — status conflict'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_StatusConflictDetail',
		() => ({default: 'This chain recorded a completion and was then marked Stalled by recovery. It has ended and will not run again; the recorded status conflict is diagnostic only.'}),
		{virtual: true});

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
		delete global.__lwcJestMock_abortChain;
	});

	beforeEach(() =>
	{
		// Re-arm the shared static-open spy each test (moduleController.test.js lifecycle); per-case
		// overrides use mockResolvedValueOnce and are consumed within their own test.
		mockChainAbortModalOpen.mockResolvedValue({action: 'cancel'});
	});

	afterEach(() =>
	{
		while(document.body.firstChild)
		{
			document.body.removeChild(document.body.firstChild);
		}
		jest.clearAllMocks();
	});

	async function createComponent(executionId = null, detail)
	{
		mockCallControllerMethod.mockResolvedValue(detail === undefined ? (executionId ? MOCK_DETAIL : null) : detail);

		const element = createElement('c-chain-monitor-detail', {is: require('c/chainMonitorDetail').default});

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
		const element = await createComponent('a00000000000001AAA', MOCK_FAILED_DETAIL);

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

	it('shows an error toast instead of an unhandled rejection when the clipboard copy fails', async() =>
	{
		mockCopyToClipBoard.mockRejectedValueOnce(new Error('copy denied'));

		const element = await createComponent('a00000000000001AAA');
		const copyButton = element.shadowRoot.querySelector('lightning-button-icon');
		copyButton.dispatchEvent(new CustomEvent('click'));
		// A macrotask flush lets the async click handler fully settle. Before the fix, the
		// un-caught copy rejection escaped the handler here and failed this test as an
		// unhandled rejection, so a regression of the catch surfaces loudly on its own.
		await new Promise((resolve) => setTimeout(resolve, 0));

		expect(mockShowSuccessToast).not.toHaveBeenCalled();
		expect(mockShowErrorToast).toHaveBeenCalledWith('Couldn\'t copy to the clipboard. Try again or copy the value manually.');
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
		const element = await createComponent('a00000000000001AAA', {...MOCK_DETAIL, totalSteps: 0, completedSteps: 0});

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
		const element = await createComponent('a00000000000001AAA', {...MOCK_DETAIL, correlationId: null});

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
		const element = await createComponent('a00000000000001AAA', {...MOCK_DETAIL, status: 'Unknown'});

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
		const element = await createComponent('a00000000000001AAA', {...MOCK_DETAIL, status: 'Running', completedAt: null});

		const dtElements = element.shadowRoot.querySelectorAll('dt');
		const labels = Array.from(dtElements).map(el => el.textContent);
		expect(labels).not.toContain('Completed');
	});

	it('navigates to the Log Console filtered by the correlation id when View logs is clicked', async() =>
	{
		const element = await createComponent('a00000000000001AAA');

		const viewLogs = element.shadowRoot.querySelector('[data-testid="view-logs"]');
		expect(viewLogs).toBeTruthy();
		viewLogs.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();

		expect(mockNavigate).toHaveBeenCalled();
		const target = mockNavigate.mock.calls[0][0];
		expect(target.type).toBe('standard__navItemPage');
		expect(target.attributes.apiName).toBe('LogConsole');
		expect(target.state.c__correlationId).toBe('test-correlation-id');
	});

	it('hides the View logs action when the chain has no correlation id', async() =>
	{
		const element = await createComponent('a00000000000001AAA', {...MOCK_DETAIL, correlationId: null});

		expect(element.shadowRoot.querySelector('[data-testid="view-logs"]')).toBeFalsy();
	});

	describe('abort action (D23)', () =>
	{
		const MOCK_RUNNING_DETAIL = {
			...MOCK_DETAIL, status: 'Running', completedAt: null, completedSteps: 2, totalSteps: 5, abortAvailability: 'Available'
		};

		// A macrotask flush lets the async click handler (modal await + controller await) fully
		// settle, then two microtask flushes let the re-render land in the DOM.
		async function flushAbortHandler()
		{
			await new Promise((resolve) => setTimeout(resolve, 0));
			await Promise.resolve();
			await Promise.resolve();
		}

		it('shows an enabled abort button when the abort is available', async() =>
		{
			const element = await createComponent('a00000000000001AAA', MOCK_RUNNING_DETAIL);

			const abortButton = element.shadowRoot.querySelector('[data-testid="abort-button"]');
			expect(abortButton).toBeTruthy();
			expect(abortButton.disabled).toBeFalsy();
		});

		it('disables the abort button with the missing-permission tooltip when the user lacks the permission', async() =>
		{
			const element = await createComponent('a00000000000001AAA', {...MOCK_RUNNING_DETAIL, abortAvailability: 'PermissionMissing'});

			const abortButton = element.shadowRoot.querySelector('[data-testid="abort-button"]');
			expect(abortButton).toBeTruthy();
			expect(abortButton.disabled).toBe(true);
			expect(abortButton.title).toBe('You do not have permission to abort chains. Ask an administrator for the Kern Async Chain Abort permission set.');
		});

		it('disables the abort button with the switched-off tooltip when the capability is disabled', async() =>
		{
			const element = await createComponent('a00000000000001AAA', {...MOCK_RUNNING_DETAIL, abortAvailability: 'CapabilityDisabled'});

			const abortButton = element.shadowRoot.querySelector('[data-testid="abort-button"]');
			expect(abortButton).toBeTruthy();
			expect(abortButton.disabled).toBe(true);
			expect(abortButton.title)
			.toBe('Aborting chains is switched off for this org. An administrator can enable it by activating the Async Chain Abort Enabled feature flag.');
		});

		it('hides the abort button when the chain can no longer be aborted', async() =>
		{
			const element = await createComponent('a00000000000001AAA', {...MOCK_RUNNING_DETAIL, abortAvailability: 'ChainNotAbortable'});

			expect(element.shadowRoot.querySelector('[data-testid="abort-button"]')).toBeFalsy();
		});

		it('replaces the detail, emits chainabort, and toasts on a confirmed abort', async() =>
		{
			const element = await createComponent('a00000000000001AAA', MOCK_RUNNING_DETAIL);
			const abortHandler = jest.fn();
			element.addEventListener('chainabort', abortHandler);
			mockChainAbortModalOpen.mockResolvedValueOnce({action: 'confirm'});
			mockCallControllerMethod.mockResolvedValueOnce({...MOCK_RUNNING_DETAIL, status: 'Aborted', abortAvailability: 'ChainNotAbortable'});

			element.shadowRoot.querySelector('[data-testid="abort-button"]').dispatchEvent(new CustomEvent('click'));
			await flushAbortHandler();

			expect(mockChainAbortModalOpen).toHaveBeenCalledWith({
				size: 'small',
				label: 'Abort this chain?',
				title: 'Abort this chain?',
				body: 'TestChain has completed 2/5 steps. The running step finishes, then the chain stops and cannot be resumed.',
				confirmLabel: 'Abort chain',
				cancelLabel: 'Cancel'
			});
			expect(mockCallControllerMethod).toHaveBeenCalledWith(expect.anything(), {executionId: 'a00000000000001AAA'});
			expect(element.shadowRoot.querySelector('[data-testid="status-badge"]').label).toBe('Aborted');
			expect(element.shadowRoot.querySelector('[data-testid="abort-button"]')).toBeFalsy();
			expect(abortHandler).toHaveBeenCalledTimes(1);
			expect(abortHandler.mock.calls[0][0].detail).toEqual({executionId: 'a00000000000001AAA'});
			expect(mockShowSuccessToast).toHaveBeenCalledWith('Abort recorded. The chain stops at its next step boundary.');
		});

		it('does not call the controller when the modal is cancelled', async() =>
		{
			const element = await createComponent('a00000000000001AAA', MOCK_RUNNING_DETAIL);
			mockCallControllerMethod.mockClear();

			element.shadowRoot.querySelector('[data-testid="abort-button"]').dispatchEvent(new CustomEvent('click'));
			await flushAbortHandler();

			expect(mockChainAbortModalOpen).toHaveBeenCalledTimes(1);
			expect(mockCallControllerMethod).not.toHaveBeenCalled();
		});

		it('treats a dismissed modal (ESC or backdrop, no action) as a cancel', async() =>
		{
			const element = await createComponent('a00000000000001AAA', MOCK_RUNNING_DETAIL);
			mockCallControllerMethod.mockClear();
			mockChainAbortModalOpen.mockResolvedValueOnce(undefined);

			element.shadowRoot.querySelector('[data-testid="abort-button"]').dispatchEvent(new CustomEvent('click'));
			await flushAbortHandler();

			expect(mockCallControllerMethod).not.toHaveBeenCalled();
		});

		it('does not emit chainabort or toast when the abort is refused', async() =>
		{
			const element = await createComponent('a00000000000001AAA', MOCK_RUNNING_DETAIL);
			const abortHandler = jest.fn();
			element.addEventListener('chainabort', abortHandler);
			mockChainAbortModalOpen.mockResolvedValueOnce({action: 'confirm'});
			// callControllerMethod resolves undefined on failure — it has already toasted the error.
			mockCallControllerMethod.mockResolvedValueOnce(undefined);

			element.shadowRoot.querySelector('[data-testid="abort-button"]').dispatchEvent(new CustomEvent('click'));
			await flushAbortHandler();

			expect(mockCallControllerMethod).toHaveBeenCalledWith(expect.anything(), {executionId: 'a00000000000001AAA'});
			expect(abortHandler).not.toHaveBeenCalled();
			expect(mockShowSuccessToast).not.toHaveBeenCalled();
			expect(element.shadowRoot.querySelector('[data-testid="status-badge"]').label).toBe('Running');
			expect(element.shadowRoot.querySelector('[data-testid="abort-button"]')).toBeTruthy();
		});
	});

	describe('status label and conflict badge (D20)', () =>
	{
		const CONFLICT_LABEL = 'Ended — status conflict';
		const CONFLICT_TOOLTIP = 'This chain recorded a completion and was then marked Stalled by recovery. It has ended and will not run again; the recorded status conflict is diagnostic only.';

		function statusBadge(element)
		{
			return element.shadowRoot.querySelector('[data-testid="status-badge"]');
		}

		it('shows the neutral conflict label and tooltip when a stalled row carries a completion timestamp', async() =>
		{
			const element = await createComponent('a00000000000001AAA', {...MOCK_DETAIL, status: 'Stalled', completedAt: '2026-07-23T10:00:00.000Z'});

			const badge = statusBadge(element);
			expect(badge.label).toBe(CONFLICT_LABEL);
			expect(badge.title).toBe(CONFLICT_TOOLTIP);
		});

		it('shows the translated Stalled label with no tooltip for a genuine stall with no completion timestamp', async() =>
		{
			const element = await createComponent('a00000000000001AAA', {...MOCK_DETAIL, status: 'Stalled', completedAt: null});

			const badge = statusBadge(element);
			expect(badge.label).toBe('Stalled');
			expect(badge.title).toBe('');
		});

		it.each([
			[
				'Running',
				'Running'
			],
			[
				'Completed',
				'Completed'
			],
			[
				'Failed',
				'Failed'
			],
			[
				'Aborted',
				'Aborted'
			]
		])('renders the %s status through its label', async(status, expected) =>
		{
			const element = await createComponent('a00000000000001AAA', {...MOCK_DETAIL, status, completedAt: null});

			const badge = statusBadge(element);
			expect(badge.label).toBe(expected);
			expect(badge.title).toBe('');
		});

		it('falls back to the raw status string for an unmapped status the framework never writes', async() =>
		{
			const element = await createComponent('a00000000000001AAA', {...MOCK_DETAIL, status: 'Delayed', completedAt: null});

			const badge = statusBadge(element);
			expect(badge.label).toBe('Delayed');
			expect(badge.title).toBe('');
		});
	});

});
