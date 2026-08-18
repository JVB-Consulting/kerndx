// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for chainMonitorDetail LWC component
 * @author Jason van Beukering
 * @date April 2026, August 2026
 */

// The rendered c-chain-log-stream child imports these two apex modules; explicit virtual mocks
// give them stable identities so createComponent can route the shared controller mock by function.
jest.mock('@salesforce/apex/CTRL_ChainMonitor.getChainLogEntries', () => ({default: jest.fn()}), {virtual: true});
jest.mock('@salesforce/apex/CTRL_ChainMonitor.getNamespacePrefix', () => ({default: jest.fn().mockResolvedValue('')}), {virtual: true});

import {createElement} from 'lwc';
// noinspection JSUnresolvedReference - mock helpers are provided by the c/componentBuilder jest mock at run time
import {mockCallControllerMethod, mockNavigate, mockShowErrorToast, mockShowSuccessToast} from 'c/componentBuilder';
import ChainAbortModal from 'c/chainAbortModal';
import ChainActionConfirmModal from 'c/chainActionConfirmModal';
import getChainLogEntries from '@salesforce/apex/CTRL_ChainMonitor.getChainLogEntries';

// Spy-on-real: the static open lives on the real module (lightning/modal resolves to the repo's
// moduleNameMapper mock), so the interception survives the resolver-cache flip that silently
// defeats a jest.mock('c/...') of the same module (see moduleController.test.js).
const mockChainAbortModalOpen = jest.spyOn(ChainAbortModal, 'open').mockResolvedValue({action: 'cancel'});
const mockChainActionConfirmModalOpen = jest.spyOn(ChainActionConfirmModal, 'open').mockResolvedValue({action: 'cancel'});

const mockCopyToClipBoard = jest.fn().mockResolvedValue(undefined);

jest.mock('c/utilitySystem', () => ({
	copyToClipBoard: (...args) => mockCopyToClipBoard(...args)
}));

jest.mock('@salesforce/label/c.ChainMonitor_ViewLogsAction', () => ({default: 'View logs'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_Copy', () => ({default: 'Copy'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_CopyFailed', () => ({default: 'Couldn\'t copy to the clipboard. Try again or copy the value manually.'}), {virtual: true});
// The progress phrase carries {0}/{1} placeholders; the real template value keeps the
// 'Step 3 of 3' assertion an end-to-end check of formatTemplateString. The rest mirror their
// in-org values so the DOM-text and toast-title assertions verify byte-faithful wiring, not a
// bare label id. (Value ratified at M0 P13; the abort modal body composes this phrase too.)
jest.mock('@salesforce/label/c.ChainMonitor_ProgressSteps', () => ({default: 'Step {0} of {1}'}), {virtual: true});
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
jest.mock('@salesforce/label/c.ChainMonitor_AbortModalBody', () => ({
	default: '{0} has completed {1}. No further steps start, and the chain cannot be resumed. A step already running is not interrupted, so a hung step keeps the chain from '
			+ 'stopping until it ends.'
}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_AbortModalProgress', () => ({default: '{0}/{1} steps'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_AbortModalTitle', () => ({default: 'Abort chain'}), {virtual: true});
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
// Operator-action labels mirror their in-org values byte-for-byte (the M0 frozen copy), so the
// modal-payload, tooltip, and toast assertions verify byte-faithful wiring end to end.
jest.mock('@salesforce/label/c.ChainMonitor_RetryAction', () => ({default: 'Retry from failed step'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_RetryModalTitle', () => ({default: 'Retry chain from failed step'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_RetryModalBody', () => ({default: '{0} resumes at its failed step. Steps that already completed do not run again.'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_RetryConfirmButton', () => ({default: 'Retry chain'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_RetrySuccessToast', () => ({default: 'Retry started. {0} resumes at its failed step.'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_RestartAction', () => ({default: 'Restart from start'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_RestartModalTitle', () => ({default: 'Restart chain from start'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_RestartModalBody', () => ({default: '{0} runs again from step 1 as a new chain with a fresh context. This record is kept for audit.'}),
		{virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_RestartConfirmButton', () => ({default: 'Restart chain'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_RestartSuccessToast', () => ({default: 'Restart started. {0} is running again from step 1, and its new run is selected.'}),
		{virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_RestartedFrom', () => ({default: 'Restarted from'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_ActionCancelButton', () => ({default: 'Cancel'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_RetryUnavailableStepNotIdempotent',
		() => ({default: 'The failed step does not declare itself safe to re-run, so retry is not available.'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_RetryUnavailablePermanent', () => ({default: 'The step declared this failure permanent, so retrying it cannot succeed.'}),
		{virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_RetryUnavailableContext', () => ({default: 'The chain\'s saved context is not available, so it cannot resume from the failed step.'}),
		{virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_RestartUnavailableNotDeclared', () => ({default: 'This chain was not built to allow restarts.'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_RedriveUnavailableDisabled', () => ({default: 'Re-drive actions are switched off for this org.'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_RedriveUnavailableMissingPermission', () => ({default: 'You do not have permission to re-drive chains.'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_RedriveUnavailableSuspended', () => ({default: 'Chain processing is suspended. Resume it before re-driving chains.'}), {virtual: true});
// U1/U13/U39 additions. The stopped phrase carries {0}/{1} like its shipped sibling, so the
// 'Stopped after 1 of 3 steps' assertion stays an end-to-end check of formatTemplateString.
jest.mock('@salesforce/label/c.ChainMonitor_ActionsGroup', () => ({default: 'Chain actions'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_ActiveDuration', () => ({default: 'Active run time'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_EndedLabel', () => ({default: 'Ended'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_ProgressStepsStopped', () => ({default: 'Stopped after {0} of {1} steps'}), {virtual: true});

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
		delete global.__lwcJestMock_retryChainFromFailedStep;
		delete global.__lwcJestMock_restartChainFromStart;
	});

	beforeEach(() =>
	{
		// Re-arm the shared static-open spies each test (moduleController.test.js lifecycle); per-case
		// overrides use mockResolvedValueOnce and are consumed within their own test.
		mockChainAbortModalOpen.mockResolvedValue({action: 'cancel'});
		mockChainActionConfirmModalOpen.mockResolvedValue({action: 'cancel'});
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
		const detailValue = detail === undefined ? (executionId ? MOCK_DETAIL : null) : detail;
		// The rendered c-chain-log-stream child seeds through the same shared controller mock;
		// routing by apex-function identity hands the seed an entry list, never the detail shape.
		// Invoking the apex function mirrors the mock's default contract so the transformer's
		// import stubs stay exercised.
		mockCallControllerMethod.mockImplementation((apexFunction, parameters) =>
		{
			if(typeof apexFunction === 'function')
			{
				apexFunction(parameters);
			}
			return Promise.resolve(apexFunction === getChainLogEntries ? [] : detailValue);
		});

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

		const errorSection = element.shadowRoot.querySelector('[data-testid="error-message"]');
		expect(errorSection).toBeTruthy();
		expect(errorSection.textContent).toContain('NullPointerException');
	});

	it('lays the correlation id out as a truncating value with the copy affordance beside it', async() =>
	{
		const element = await createComponent('a00000000000001AAA');

		// The timing cards are as narrow as 10rem while a correlation id is 36 characters, so the value has to
		// be a shrinkable block that ellipsises and the copy affordance has to hold its place on the same row —
		// an inline span never truncates, and the affordance then wraps underneath the clipped id.
		const value = element.shadowRoot.querySelector('[data-testid="correlation-id"]');
		const row = value.parentElement;
		expect(row.tagName).toBe('DD');
		expect(row.classList.contains('timing-value-row')).toBe(true);

		const children = Array.from(row.children);
		expect(children).toHaveLength(2);
		expect(children[0]).toBe(value);
		expect(value.classList.contains('slds-truncate')).toBe(true);
		expect(value.classList.contains('timing-value')).toBe(true);
		expect(value.title).toBe('test-correlation-id');
		expect(value.textContent).toBe('test-correlation-id');

		expect(children[1].tagName.toLowerCase()).toBe('lightning-button-icon');
		expect(children[1].dataset.testid).toBe('copy-correlation');
		expect(children[1].classList.contains('timing-value-action')).toBe(true);
		// The icon's name and tooltip come from a label, never a hardcoded string.
		expect(children[1].alternativeText).toBe('Copy');
		expect(children[1].title).toBe('Copy');
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

	it('should not reload when the same executionId is assigned again', async() =>
	{
		// The list re-emits its selection on every page refresh; an unchanged id must not cost a second
		// server round trip or flicker the pane through its loading state.
		const element = await createComponent('a00000000000001AAA');
		mockCallControllerMethod.mockClear();

		element.executionId = 'a00000000000001AAA';
		await Promise.resolve();

		expect(mockCallControllerMethod).not.toHaveBeenCalled();
	});

	it('should show progress label', async() =>
	{
		const element = await createComponent('a00000000000001AAA');

		const progressText = element.shadowRoot.querySelector('[data-testid="progress-label"]');
		expect(progressText.textContent).toContain('Step 3 of 3');
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

	describe('View logs window bounds', () =>
	{
		async function clickViewLogs(detail)
		{
			const element = await createComponent('a00000000000001AAA', detail);
			element.shadowRoot.querySelector('[data-testid="view-logs"]').dispatchEvent(new CustomEvent('click'));
			await Promise.resolve();
			return mockNavigate.mock.calls[0][0].state;
		}

		it('hands the console this run\'s bounds widened by a minute at each end', async() =>
		{
			// The mock run spans 14:00:00 to 14:00:45; the margin keeps a log written a moment either
			// side of the recorded run inside the window the console opens on.
			const state = await clickViewLogs(MOCK_DETAIL);

			expect(state.c__windowStart).toBe('2026-04-08T13:59:00.000Z');
			expect(state.c__windowEnd).toBe('2026-04-08T14:01:45.000Z');
		});

		it('sends no upper bound for a chain that is still running, so the console reads to now', async() =>
		{
			const state = await clickViewLogs({...MOCK_DETAIL, status: 'Running', completedAt: null});

			expect(state.c__windowStart).toBe('2026-04-08T13:59:00.000Z');
			expect(state.c__windowEnd).toBeUndefined();
		});

		it('sends the correlation id alone when the run has no recorded start', async() =>
		{
			const state = await clickViewLogs({...MOCK_DETAIL, startedAt: null, completedAt: null});

			expect(state.c__correlationId).toBe('test-correlation-id');
			expect(state.c__windowStart).toBeUndefined();
			expect(state.c__windowEnd).toBeUndefined();
		});

		it('stamps every hand-off with the click instant, so the console can tell a fresh click from a re-delivered one', async() =>
		{
			const nowSpy = jest.spyOn(Date, 'now').mockReturnValue(1712584800000);
			try
			{
				const state = await clickViewLogs(MOCK_DETAIL);
				expect(state.c__viewLogsAt).toBe('1712584800000');
			}
			finally
			{
				nowSpy.mockRestore();
			}
		});
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
				size: 'small', label: 'Abort chain', title: 'Abort chain', // The abort body composes its own '2/5 steps' fragment, deliberately distinct
				// from the headline's P13 'Step N of M' phrase.
				body: 'TestChain has completed 2/5 steps. No further steps start, and the chain cannot be resumed. A step already running is not interrupted, so a hung step keeps '
						+ 'the chain from stopping until it ends.', confirmLabel: 'Abort chain', cancelLabel: 'Cancel'
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

	describe('operator actions: retry and restart (D12/D13 client leg)', () =>
	{
		const MOCK_OPERATOR_DETAIL = {
			...MOCK_FAILED_DETAIL, retryAvailability: 'Available', restartAvailability: 'Available', abortAvailability: 'ChainNotAbortable'
		};
		const CLONE_ID = 'a00000000000009AAA';

		// A macrotask flush lets the async click handler (modal await + controller await) fully
		// settle, then two microtask flushes let the re-render land in the DOM.
		async function flushActionHandler()
		{
			await new Promise((resolve) => setTimeout(resolve, 0));
			await Promise.resolve();
			await Promise.resolve();
		}

		function actionButton(element, testId)
		{
			return element.shadowRoot.querySelector(`[data-testid="${testId}"]`);
		}

		it('renders the action group with enabled retry and restart when both are available', async() =>
		{
			const element = await createComponent('a00000000000001AAA', MOCK_OPERATOR_DETAIL);

			expect(element.shadowRoot.querySelector('[data-testid="detail-action-group"]')).toBeTruthy();
			expect(actionButton(element, 'retry-action').disabled).toBeFalsy();
			expect(actionButton(element, 'restart-action').disabled).toBeFalsy();
			expect(actionButton(element, 'abort-button')).toBeFalsy();
		});

		it('renders no action group when the detail carries no availability codes', async() =>
		{
			const element = await createComponent('a00000000000001AAA', MOCK_FAILED_DETAIL);

			expect(element.shadowRoot.querySelector('[data-testid="detail-action-group"]')).toBeFalsy();
		});

		it('disables retry with the step-not-idempotent tooltip', async() =>
		{
			const element = await createComponent('a00000000000001AAA', {...MOCK_OPERATOR_DETAIL, retryAvailability: 'StepNotIdempotent'});

			const retryButton = actionButton(element, 'retry-action');
			expect(retryButton.disabled).toBe(true);
			expect(retryButton.title).toBe('The failed step does not declare itself safe to re-run, so retry is not available.');
		});

		it('disables both re-drive actions with the shared suspension tooltip while processing is suspended', async() =>
		{
			const element = await createComponent('a00000000000001AAA',
					{...MOCK_OPERATOR_DETAIL, retryAvailability: 'ChainProcessingSuspended', restartAvailability: 'ChainProcessingSuspended'});

			expect(actionButton(element, 'retry-action').title).toBe('Chain processing is suspended. Resume it before re-driving chains.');
			expect(actionButton(element, 'restart-action').title).toBe('Chain processing is suspended. Resume it before re-driving chains.');
		});

		it('hides retry for a chain state that does not permit it and restart for an undeclared chain', async() =>
		{
			const element = await createComponent('a00000000000001AAA',
					{...MOCK_OPERATOR_DETAIL, retryAvailability: 'ChainNotRetryable', restartAvailability: 'RestartNotDeclared'});

			expect(actionButton(element, 'retry-action')).toBeFalsy();
			const restartButton = actionButton(element, 'restart-action');
			expect(restartButton.disabled).toBe(true);
			expect(restartButton.title).toBe('This chain was not built to allow restarts.');
		});

		it('hides restart entirely when the chain state does not permit a restart', async() =>
		{
			const element = await createComponent('a00000000000001AAA', {...MOCK_OPERATOR_DETAIL, restartAvailability: 'ChainNotRestartable'});

			expect(actionButton(element, 'restart-action')).toBeFalsy();
			expect(actionButton(element, 'retry-action')).toBeTruthy();
		});

		it('replaces the detail, emits chainretry, and toasts on a confirmed retry', async() =>
		{
			const element = await createComponent('a00000000000001AAA', MOCK_OPERATOR_DETAIL);
			const retryHandler = jest.fn();
			element.addEventListener('chainretry', retryHandler);
			mockChainActionConfirmModalOpen.mockResolvedValueOnce({action: 'confirm'});
			mockCallControllerMethod.mockResolvedValueOnce({...MOCK_OPERATOR_DETAIL, status: 'Running', retryAvailability: 'ChainNotRetryable'});

			actionButton(element, 'retry-action').dispatchEvent(new CustomEvent('click'));
			await flushActionHandler();

			expect(mockChainActionConfirmModalOpen).toHaveBeenCalledWith({
				size: 'small',
				label: 'Retry chain from failed step',
				title: 'Retry chain from failed step',
				body: 'TestChain resumes at its failed step. Steps that already completed do not run again.',
				confirmLabel: 'Retry chain',
				cancelLabel: 'Cancel',
				confirmVariant: 'brand'
			});
			expect(mockCallControllerMethod).toHaveBeenCalledWith(expect.anything(), {executionId: 'a00000000000001AAA'});
			expect(element.shadowRoot.querySelector('[data-testid="status-badge"]').label).toBe('Running');
			expect(retryHandler).toHaveBeenCalledTimes(1);
			expect(retryHandler.mock.calls[0][0].detail).toEqual({executionId: 'a00000000000001AAA'});
			expect(mockShowSuccessToast).toHaveBeenCalledWith('Retry started. TestChain resumes at its failed step.');
		});

		it('re-points at the clone, emits chainrestart with the clone id, and toasts on a confirmed restart', async() =>
		{
			const element = await createComponent('a00000000000001AAA', MOCK_OPERATOR_DETAIL);
			const restartHandler = jest.fn();
			element.addEventListener('chainrestart', restartHandler);
			mockChainActionConfirmModalOpen.mockResolvedValueOnce({action: 'confirm'});
			mockCallControllerMethod.mockResolvedValueOnce({
				...MOCK_DETAIL,
				executionId: CLONE_ID,
				status: 'Running',
				completedAt: null,
				sourceExecutionId: 'a00000000000001AAA',
				retryAvailability: 'ChainNotRetryable',
				restartAvailability: 'ChainNotRestartable',
				abortAvailability: 'Available'
			});

			actionButton(element, 'restart-action').dispatchEvent(new CustomEvent('click'));
			await flushActionHandler();

			expect(mockChainActionConfirmModalOpen).toHaveBeenCalledWith({
				size: 'small',
				label: 'Restart chain from start',
				title: 'Restart chain from start',
				body: 'TestChain runs again from step 1 as a new chain with a fresh context. This record is kept for audit.',
				confirmLabel: 'Restart chain',
				cancelLabel: 'Cancel',
				confirmVariant: 'brand'
			});
			expect(element.executionId).toBe(CLONE_ID);
			expect(restartHandler).toHaveBeenCalledTimes(1);
			expect(restartHandler.mock.calls[0][0].detail).toEqual({executionId: CLONE_ID});
			expect(mockShowSuccessToast).toHaveBeenCalledWith('Restart started. TestChain is running again from step 1, and its new run is selected.');
			const lineageLink = element.shadowRoot.querySelector('[data-testid="restart-lineage-link"]');
			expect(lineageLink).toBeTruthy();
			// U41: the whole source id, ellipsised by CSS when the card is narrow — never cut to a
			// prefix that no longer identifies a record. The full value stays on the title.
			expect(lineageLink.textContent.trim()).toBe('a00000000000001AAA');
			expect(lineageLink.title).toBe('a00000000000001AAA');
		});

		it('does not call the controller when the confirm modal is cancelled', async() =>
		{
			const element = await createComponent('a00000000000001AAA', MOCK_OPERATOR_DETAIL);
			mockCallControllerMethod.mockClear();

			actionButton(element, 'retry-action').dispatchEvent(new CustomEvent('click'));
			await flushActionHandler();

			expect(mockChainActionConfirmModalOpen).toHaveBeenCalledTimes(1);
			expect(mockCallControllerMethod).not.toHaveBeenCalled();
		});

		it('does not emit chainretry or toast when the retry is refused', async() =>
		{
			const element = await createComponent('a00000000000001AAA', MOCK_OPERATOR_DETAIL);
			const retryHandler = jest.fn();
			element.addEventListener('chainretry', retryHandler);
			mockChainActionConfirmModalOpen.mockResolvedValueOnce({action: 'confirm'});
			// callControllerMethod resolves undefined on failure — it has already toasted the error.
			mockCallControllerMethod.mockResolvedValueOnce(undefined);

			actionButton(element, 'retry-action').dispatchEvent(new CustomEvent('click'));
			await flushActionHandler();

			expect(retryHandler).not.toHaveBeenCalled();
			expect(mockShowSuccessToast).not.toHaveBeenCalled();
			expect(element.shadowRoot.querySelector('[data-testid="status-badge"]').label).toBe('Failed');
		});

		it('holds every action button disabled while a confirmed retry is in server transit', async() =>
		{
			const element = await createComponent('a00000000000001AAA', MOCK_OPERATOR_DETAIL);
			mockChainActionConfirmModalOpen.mockResolvedValueOnce({action: 'confirm'});
			let resolveControllerCall;
			mockCallControllerMethod.mockImplementationOnce(() => new Promise((resolve) =>
			{
				resolveControllerCall = resolve;
			}));

			actionButton(element, 'retry-action').dispatchEvent(new CustomEvent('click'));
			await Promise.resolve();
			await Promise.resolve();
			await Promise.resolve();

			expect(actionButton(element, 'retry-action').disabled).toBe(true);
			expect(actionButton(element, 'restart-action').disabled).toBe(true);

			resolveControllerCall(MOCK_OPERATOR_DETAIL);
			await flushActionHandler();

			expect(actionButton(element, 'retry-action').disabled).toBe(false);
			expect(actionButton(element, 'restart-action').disabled).toBe(false);
		});

		it('holds the abort button disabled while a confirmed abort is in server transit', async() =>
		{
			const runningDetail = {...MOCK_DETAIL, status: 'Running', completedAt: null, abortAvailability: 'Available'};
			const element = await createComponent('a00000000000001AAA', runningDetail);
			mockChainAbortModalOpen.mockResolvedValueOnce({action: 'confirm'});
			let resolveControllerCall;
			mockCallControllerMethod.mockImplementationOnce(() => new Promise((resolve) =>
			{
				resolveControllerCall = resolve;
			}));

			actionButton(element, 'abort-button').dispatchEvent(new CustomEvent('click'));
			await Promise.resolve();
			await Promise.resolve();
			await Promise.resolve();

			expect(actionButton(element, 'abort-button').disabled).toBe(true);

			resolveControllerCall(runningDetail);
			await flushActionHandler();

			expect(actionButton(element, 'abort-button').disabled).toBe(false);
		});

		it('asks the container to select the source run when the lineage link is clicked', async() =>
		{
			const element = await createComponent(CLONE_ID, {...MOCK_DETAIL, executionId: CLONE_ID, sourceExecutionId: 'a00000000000001AAA'});
			const lineageHandler = jest.fn();
			element.addEventListener('chainlineagenavigate', lineageHandler);

			element.shadowRoot.querySelector('[data-testid="restart-lineage-link"]').dispatchEvent(new CustomEvent('click'));
			await Promise.resolve();

			expect(lineageHandler).toHaveBeenCalledTimes(1);
			expect(lineageHandler.mock.calls[0][0].detail).toEqual({executionId: 'a00000000000001AAA'});
		});

		it('renders one status dot per step with per-status classes and the pending default', async() =>
		{
			const element = await createComponent('a00000000000001AAA', {
				...MOCK_FAILED_DETAIL, steps: [
					{name: 'Step 1', stepStatus: 'success', durationLabel: '0.8s', errorMessage: null},
					{name: 'Step 2', stepStatus: 'failed', durationLabel: '0.1s', errorMessage: 'boom'},
					{name: 'Step 3', stepStatus: 'queued', durationLabel: null, errorMessage: null}
				]
			});

			const dots = element.shadowRoot.querySelectorAll('.step-dot');
			expect(dots.length).toBe(3);
			expect(dots[0].className).toContain('step-dot_done');
			expect(dots[1].className).toContain('step-dot_failed');
			expect(dots[2].className).toContain('step-dot_pending');
		});

		it('renders no step dots beyond the ten-step ceiling', async() =>
		{
			const element = await createComponent('a00000000000001AAA', {...MOCK_FAILED_DETAIL, totalSteps: 25});

			expect(element.shadowRoot.querySelectorAll('.step-dot').length).toBe(0);
		});

		it('renders no lineage entry when the chain is not a restart clone', async() =>
		{
			const element = await createComponent('a00000000000001AAA');

			expect(element.shadowRoot.querySelector('[data-testid="restart-lineage-link"]')).toBeFalsy();
			const labels = Array.from(element.shadowRoot.querySelectorAll('dt')).map(dtElement => dtElement.textContent);
			expect(labels).not.toContain('Restarted from');
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

		it('renders the dominant pill emphasis with the per-status theme class', async() =>
		{
			const element = await createComponent('a00000000000001AAA', MOCK_FAILED_DETAIL);

			const badge = statusBadge(element);
			expect(badge.className).toContain('status-pill');
			expect(badge.className).toContain('slds-theme_error');
		});

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

	describe('header identity row and action toolbar (U1)', () =>
	{
		const MOCK_TOOLBAR_DETAIL = {
			...MOCK_FAILED_DETAIL, retryAvailability: 'Available', restartAvailability: 'Available', abortAvailability: 'ChainNotAbortable'
		};

		function identityRow(element)
		{
			return element.shadowRoot.querySelector('[data-testid="detail-identity-row"]');
		}

		function toolbarRow(element)
		{
			return element.shadowRoot.querySelector('[data-testid="detail-toolbar-row"]');
		}

		it('keeps every button out of the identity row', async() =>
		{
			// The whole U1 defect: buttons living in the identity row's reverse figure, which never
			// wraps and never shrinks, so they overlap the chain name and clip off the pane edge.
			const element = await createComponent('a00000000000001AAA', MOCK_TOOLBAR_DETAIL);

			expect(identityRow(element)).toBeTruthy();
			expect(identityRow(element).querySelectorAll('lightning-button')).toHaveLength(0);
		});

		it('renders the toolbar as the single labelled group holding both the operator actions and View logs', async() =>
		{
			const element = await createComponent('a00000000000001AAA', MOCK_TOOLBAR_DETAIL);

			const toolbar = toolbarRow(element);
			expect(toolbar.getAttribute('role')).toBe('group');
			expect(toolbar.getAttribute('aria-label')).toBe('Chain actions');
			expect(toolbar.querySelector('[data-testid="retry-action"]')).toBeTruthy();
			expect(toolbar.querySelector('[data-testid="view-logs"]')).toBeTruthy();
			// The operator wrapper stays semantics-free: one labelled group, never a nested one.
			expect(toolbar.querySelector('[data-testid="detail-action-group"]').getAttribute('role')).toBeNull();
		});

		it('renders the toolbar with View logs alone when the chain has no operator actions', async() =>
		{
			const element = await createComponent('a00000000000001AAA');

			const toolbar = toolbarRow(element);
			expect(toolbar).toBeTruthy();
			expect(toolbar.querySelector('[data-testid="view-logs"]')).toBeTruthy();
			expect(toolbar.querySelector('[data-testid="detail-action-group"]')).toBeFalsy();
			expect(toolbar.querySelector('[data-testid="action-divider"]')).toBeFalsy();
		});

		it('renders the toolbar with the operator actions alone when the chain has no correlation id', async() =>
		{
			const element = await createComponent('a00000000000001AAA', {...MOCK_TOOLBAR_DETAIL, correlationId: null});

			const toolbar = toolbarRow(element);
			expect(toolbar).toBeTruthy();
			expect(toolbar.querySelector('[data-testid="detail-action-group"]')).toBeTruthy();
			expect(toolbar.querySelector('[data-testid="view-logs"]')).toBeFalsy();
			expect(toolbar.querySelector('[data-testid="action-divider"]')).toBeFalsy();
		});

		it('renders no toolbar row at all when the chain offers neither operator actions nor logs', async() =>
		{
			const element = await createComponent('a00000000000001AAA', {...MOCK_FAILED_DETAIL, correlationId: null});

			expect(toolbarRow(element)).toBeFalsy();
		});

		it('divides the operator actions from View logs only when both are present', async() =>
		{
			const element = await createComponent('a00000000000001AAA', MOCK_TOOLBAR_DETAIL);

			const divider = toolbarRow(element).querySelector('[data-testid="action-divider"]');
			expect(divider).toBeTruthy();
			expect(divider.getAttribute('aria-hidden')).toBe('true');
		});

		it('keeps the chain name a wrapping heading rather than a hover-only truncation', async() =>
		{
			const element = await createComponent('a00000000000001AAA', MOCK_TOOLBAR_DETAIL);

			const heading = element.shadowRoot.querySelector('[data-testid="chain-name"]');
			expect(heading.tagName).toBe('H2');
			expect(heading.classList.contains('slds-text-heading_small')).toBe(true);
			expect(heading.classList.contains('chain-name-secondary')).toBe(true);
			expect(heading.classList.contains('slds-truncate')).toBe(false);
			expect(heading.getAttribute('title')).toBeNull();
		});

		it('offers a break opportunity after every separator in a long chain name', async() =>
		{
			const element = await createComponent('a00000000000001AAA', {...MOCK_DETAIL, chainName: 'Seed_Nightly-Reconciliation.EMEA:2026'});

			const heading = element.shadowRoot.querySelector('[data-testid="chain-name"]');
			expect(heading.textContent).toBe('Seed_Nightly-Reconciliation.EMEA:2026');
			// One <wbr> per segment: the name breaks at its separators before it breaks mid-token.
			expect(heading.querySelectorAll('wbr')).toHaveLength(5);
			expect(Array.from(heading.querySelectorAll('.chain-name-segment')).map((segment) => segment.textContent))
			.toEqual([
				'Seed_',
				'Nightly-',
				'Reconciliation.',
				'EMEA:',
				'2026'
			]);
		});

		it('emits a single segment for a name with no separators', async() =>
		{
			const element = await createComponent('a00000000000001AAA');

			expect(element.shadowRoot.querySelectorAll('[data-testid="chain-name"] .chain-name-segment')).toHaveLength(1);
		});

		it('renders an empty heading rather than a literal null when the run carries no chain name', async() =>
		{
			const element = await createComponent('a00000000000001AAA', {...MOCK_DETAIL, chainName: null});

			const heading = element.shadowRoot.querySelector('[data-testid="chain-name"]');
			expect(heading.textContent).toBe('');
		});

		it('holds the progress phrase on one line beside the name', async() =>
		{
			const element = await createComponent('a00000000000001AAA');

			// SLDS has no no-wrap utility, so the never-wrap rule rides a component class.
			expect(element.shadowRoot.querySelector('[data-testid="progress-label"]').classList.contains('progress-label')).toBe(true);
		});
	});

	describe('disabled action reasons (U38)', () =>
	{
		const MOCK_REFUSED_DETAIL = {
			...MOCK_FAILED_DETAIL, retryAvailability: 'StepNotIdempotent', restartAvailability: 'RestartNotDeclared', abortAvailability: 'ChainNotAbortable'
		};

		function reasonFor(element, testId)
		{
			const button = element.shadowRoot.querySelector(`[data-testid="${testId}"]`);
			const describedBy = button.getAttribute('aria-describedby');
			return {button, describedBy, reason: element.shadowRoot.querySelector(`[id="${describedBy}"]`)};
		}

		function visibleNotes(element)
		{
			return Array.from(element.shadowRoot.querySelectorAll('[data-testid="action-unavailable-note"]')).map((note) => note.textContent);
		}

		it('describes each disabled action with the same sentence its tooltip carries', async() =>
		{
			const element = await createComponent('a00000000000001AAA', MOCK_REFUSED_DETAIL);

			const retry = reasonFor(element, 'retry-action');
			expect(retry.button.disabled).toBe(true);
			expect(retry.describedBy).toBeTruthy();
			expect(retry.reason.textContent).toBe('The failed step does not declare itself safe to re-run, so retry is not available.');
			expect(retry.reason.textContent).toBe(retry.button.title);
			// Hidden AND aria-hidden: the description is announced once, never a second time as text.
			expect(retry.reason.classList.contains('slds-assistive-text')).toBe(true);
			expect(retry.reason.getAttribute('aria-hidden')).toBe('true');
			expect(retry.reason.dataset.testid).toBe('action-unavailable-reason');

			const restart = reasonFor(element, 'restart-action');
			expect(restart.reason.textContent).toBe('This chain was not built to allow restarts.');
		});

		it('leaves an available action with an empty reason', async() =>
		{
			const element = await createComponent('a00000000000001AAA', {...MOCK_REFUSED_DETAIL, retryAvailability: 'Available', restartAvailability: 'Available'});

			expect(reasonFor(element, 'retry-action').reason.textContent).toBe('');
			expect(reasonFor(element, 'restart-action').reason.textContent).toBe('');
		});

		it('shows the reasons on screen too, because a disabled button is not focusable', async() =>
		{
			const element = await createComponent('a00000000000001AAA', MOCK_REFUSED_DETAIL);

			expect(visibleNotes(element)).toEqual([
				'The failed step does not declare itself safe to re-run, so retry is not available.',
				'This chain was not built to allow restarts.'
			]);
			// A disabled button takes no focus, so a screen-reader user moving by keyboard never reaches
			// its description; the visible list must stay in the accessibility tree as the guaranteed path.
			expect(element.shadowRoot.querySelector('[data-testid="action-unavailable-notes"]').hasAttribute('aria-hidden')).toBe(false);
		});

		it('states a reason shared by two actions once', async() =>
		{
			const element = await createComponent('a00000000000001AAA',
					{...MOCK_REFUSED_DETAIL, retryAvailability: 'ChainProcessingSuspended', restartAvailability: 'ChainProcessingSuspended'});

			expect(visibleNotes(element)).toEqual(['Chain processing is suspended. Resume it before re-driving chains.']);
		});

		it('shows no reason line when every rendered action is usable', async() =>
		{
			const element = await createComponent('a00000000000001AAA', {...MOCK_REFUSED_DETAIL, retryAvailability: 'Available', restartAvailability: 'Available'});

			expect(element.shadowRoot.querySelector('[data-testid="action-unavailable-notes"]')).toBeFalsy();
		});
	});

	describe('progress bar fill', () =>
	{
		async function barClassesFor(status)
		{
			const element = await createComponent('a00000000000001AAA', {...MOCK_DETAIL, status, completedSteps: 3});
			return element.shadowRoot.querySelector('lightning-progress-bar').className;
		}

		it('paints a stopped run in its own hue instead of leaving it the working blue', async() =>
		{
			// A failed or aborted run held a brand-blue part-way bar, which looked exactly like a run
			// still working through its steps. The status pill carries the word, so the hue only
			// reinforces what is already written.
			expect(await barClassesFor('Failed')).toContain('progress-bar_error');
			expect(await barClassesFor('Aborted')).toContain('progress-bar_error');
			expect(await barClassesFor('Stalled')).toContain('progress-bar_warning');
			expect(await barClassesFor('Completed')).toContain('progress-bar_success');
		});

		it('leaves a run still working on the default fill', async() =>
		{
			const classes = await barClassesFor('Running');

			expect(classes).toContain('progress-bar');
			expect(classes).not.toContain('progress-bar_');
		});
	});

	describe('terminal-chain coherence and timing (U13/U39/U41)', () =>
	{
		function timingLabels(element)
		{
			return Array.from(element.shadowRoot.querySelectorAll('dt')).map((term) => term.textContent);
		}

		function progressText(element)
		{
			return element.shadowRoot.querySelector('[data-testid="progress-label"]').textContent;
		}

		it.each([
			[
				'Aborted',
				'Aborted'
			],
			[
				'Failed',
				'Failed'
			],
			[
				'Completed',
				'Completed'
			]
		])('names the completion timestamp after what actually happened: %s', async(status, expected) =>
		{
			const element = await createComponent('a00000000000001AAA', {...MOCK_DETAIL, status, completedSteps: 3});

			expect(timingLabels(element)).toContain(expected);
		});

		it('stays neutral about the instant on a contradictory terminal row', async() =>
		{
			// Recovery overwrote the status that ended this run, so the instant belongs to a
			// predecessor status nothing can recover — naming it "Stalled" would claim the run
			// stalled at that moment, which is exactly what the badge refuses to say.
			const element = await createComponent('a00000000000001AAA', {...MOCK_DETAIL, status: 'Stalled', completedSteps: 3});

			expect(timingLabels(element)).toContain('Ended');
			expect(timingLabels(element)).not.toContain('Stalled');
			expect(element.shadowRoot.querySelector('[data-testid="status-badge"]').label).toBe('Ended — status conflict');
		});

		it('says the run stopped short instead of freezing the running phrase', async() =>
		{
			const element = await createComponent('a00000000000001AAA', {...MOCK_DETAIL, status: 'Aborted', completedSteps: 3, totalSteps: 4});

			expect(progressText(element)).toBe('Stopped after 3 of 4 steps');
		});

		it('keeps the running phrase for a chain that is still going', async() =>
		{
			const element = await createComponent('a00000000000001AAA', {...MOCK_DETAIL, status: 'Running', completedAt: null, completedSteps: 3, totalSteps: 4});

			expect(progressText(element)).toBe('Step 3 of 4');
		});

		it('keeps the running phrase for a chain that ended having run every step', async() =>
		{
			const element = await createComponent('a00000000000001AAA', {...MOCK_DETAIL, status: 'Aborted', completedSteps: 3, totalSteps: 3});

			expect(progressText(element)).toBe('Step 3 of 3');
		});

		it('keeps the running phrase for a completed chain', async() =>
		{
			const element = await createComponent('a00000000000001AAA', {...MOCK_DETAIL, completedSteps: 2, totalSteps: 3});

			expect(progressText(element)).toBe('Step 2 of 3');
		});

		it('separates the time the steps actually ran from the elapsed wall clock', async() =>
		{
			// U13: a re-driven chain's elapsed duration spans the operator's idle gap; the active
			// value is the sum of the step runs, so both numbers are on screen and neither lies.
			const element = await createComponent('a00000000000001AAA', {...MOCK_DETAIL, durationLabel: '12m 4s', activeDurationMs: 1200, activeDurationLabel: '1.2s'});

			expect(timingLabels(element)).toContain('Active run time');
			expect(element.shadowRoot.querySelector('[data-testid="duration"]').textContent).toBe('12m 4s');
			expect(element.shadowRoot.querySelector('[data-testid="active-duration"]').textContent).toBe('1.2s');
		});

		it('shows no active run time when the step log recorded none', async() =>
		{
			const element = await createComponent('a00000000000001AAA');

			expect(element.shadowRoot.querySelector('[data-testid="active-duration"]')).toBeFalsy();
			expect(timingLabels(element)).not.toContain('Active run time');
		});

		it('lays the restart lineage out as a truncating value carrying the whole source id', async() =>
		{
			const element = await createComponent('a00000000000001AAA', {...MOCK_DETAIL, sourceExecutionId: 'a00000000000002AAA'});

			const link = element.shadowRoot.querySelector('[data-testid="restart-lineage-link"]');
			expect(link.textContent.trim()).toBe('a00000000000002AAA');
			expect(link.title).toBe('a00000000000002AAA');
			expect(link.classList.contains('slds-truncate')).toBe(true);
			expect(link.classList.contains('timing-value')).toBe(true);
		});
	});

});
