// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for chainMonitor container LWC component
 * @author Jason van Beukering
 * @date April 2026, August 2026
 */

// The prefix wrapper defaults to the managed-install value so the existing channel and
// payload-key tests double as the managed-path regression; no-namespace tests override it.
jest.mock('@salesforce/apex/CTRL_ChainMonitor.getNamespacePrefix', () => ({
	default: jest.fn().mockResolvedValue('kern__')
}), {virtual: true});

// Operations-control labels mirror their in-org values byte-for-byte (the M0 frozen copy), so the
// modal-payload, badge, tooltip, and toast assertions verify byte-faithful wiring end to end.
jest.mock('@salesforce/label/c.ChainMonitor_ClearStalledAction', () => ({default: 'Clear stalled'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_ClearStalledModalTitle', () => ({default: 'Clear stalled chains'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_ClearStalledModalBody', () => ({
	default: 'Stalled chains waiting: {0}. They are checked oldest first. A chain proven to have stopped is re-driven. A chain that cannot be checked, such as one with no '
			+ 'executor job on record, is left exactly as it is. The result says how many fell into each group.'
}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_ActionUnavailableNote', () => ({default: '{0}: {1}'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_ClearStalledConfirmButton', () => ({default: 'Clear stalled chains'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_ClearStalledResultToast', () => ({default: '{0} stalled chains checked: {1} re-driven, {2} marked failed, {3} still waiting.'}),
		{virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_ClearStalledFailed', () => ({default: 'The action could not be completed. Refresh and try again.'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_SuspendAction', () => ({default: 'Suspend chains'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_SuspendModalTitle', () => ({default: 'Suspend chain processing'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_SuspendModalBody',
		() => ({default: 'Every running chain stops at its next step and new chains stop at once, org-wide, until you resume.'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_SuspendConfirmButton', () => ({default: 'Suspend chains'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_SuspendedToast', () => ({default: 'Chain processing suspended.'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_ResumeAction', () => ({default: 'Resume chains'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_ResumeModalTitle', () => ({default: 'Resume chain processing'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_ResumeModalBody',
		() => ({default: 'New chains run again. Chains stopped during the suspension stay stopped; restart the ones that should run.'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_ResumeConfirmButton', () => ({default: 'Resume chains'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_ResumedToast', () => ({default: 'Chain processing resumed.'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_ProcessingEnabledBadge', () => ({default: 'Chains enabled'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_ProcessingSuspendedBadge', () => ({default: 'Chains suspended'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_ActionCancelButton', () => ({default: 'Cancel'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_KillSwitchUnavailableDisabled', () => ({default: 'The kill-switch control is switched off for this org.'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_KillSwitchUnavailableMissingPermission', () => ({default: 'You do not have permission to change chain processing.'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_RedriveUnavailableDisabled', () => ({default: 'Re-drive actions are switched off for this org.'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_RedriveUnavailableMissingPermission', () => ({default: 'You do not have permission to re-drive chains.'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_RedriveUnavailableSuspended', () => ({default: 'Chain processing is suspended. Resume it before re-driving chains.'}), {virtual: true});

import {createElement} from 'lwc';
import ChainMonitor from 'c/chainMonitor';
import {subscribe, unsubscribe} from 'lightning/empApi';
import {CurrentPageReference} from 'lightning/navigation';
import {mockCallControllerMethod, mockConsoleError, mockShowErrorToast, mockShowSuccessToast} from 'c/componentBuilder';
import ChainActionConfirmModal from 'c/chainActionConfirmModal';
import getNamespacePrefix from '@salesforce/apex/CTRL_ChainMonitor.getNamespacePrefix';
import clearStalledChains from '@salesforce/apex/CTRL_ChainMonitor.clearStalledChains';
import CHAIN_MONITOR_TITLE from '@salesforce/label/c.ChainMonitor_Title';

// Spy-on-real: the static open lives on the real module (lightning/modal resolves to the repo's
// moduleNameMapper mock), so the interception survives the resolver-cache flip that silently
// defeats a jest.mock('c/...') of the same module (see moduleController.test.js).
const mockChainActionConfirmModalOpen = jest.spyOn(ChainActionConfirmModal, 'open').mockResolvedValue({action: 'cancel'});

describe('c-chain-monitor', () =>
{
	beforeEach(() =>
	{
		// Re-arm the shared static-open spy each test; per-case overrides use
		// mockResolvedValueOnce and are consumed within their own test.
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

	async function createComponent()
	{
		const element = createElement('c-chain-monitor', {is: ChainMonitor});
		document.body.appendChild(element);
		await Promise.resolve();
		await Promise.resolve();
		return element;
	}

	it('should render list and detail panels', async() =>
	{
		const element = await createComponent();

		const list = element.shadowRoot.querySelector('c-chain-monitor-list');
		const detail = element.shadowRoot.querySelector('c-chain-monitor-detail');
		expect(list).toBeTruthy();
		expect(detail).toBeTruthy();
	});

	it('should title the card from the custom label', async() =>
	{
		const element = await createComponent();

		const card = element.shadowRoot.querySelector('lightning-card');
		expect(card.title).toBe(CHAIN_MONITOR_TITLE);
	});

	it('should subscribe to empApi on connected callback', async() =>
	{
		await createComponent();

		expect(subscribe).toHaveBeenCalledWith('/event/kern__LogEntryEvent__e', -1, expect.any(Function));
	});

	it('should unsubscribe from empApi on disconnected callback', async() =>
	{
		const element = await createComponent();

		document.body.removeChild(element);
		await Promise.resolve();

		expect(unsubscribe).toHaveBeenCalled();
	});

	it('should pass selected execution id to detail panel', async() =>
	{
		const element = await createComponent();
		const list = element.shadowRoot.querySelector('c-chain-monitor-list');

		list.dispatchEvent(new CustomEvent('select', {detail: {executionId: 'test-id'}}));
		await Promise.resolve();

		const detail = element.shadowRoot.querySelector('c-chain-monitor-detail');
		expect(detail.executionId).toBe('test-id');
	});

	it('should refresh the list when the detail panel reports an aborted chain', async() =>
	{
		const element = await createComponent();
		const list = element.shadowRoot.querySelector('c-chain-monitor-list');
		const listRefresh = jest.fn();
		list.refresh = listRefresh;

		const detail = element.shadowRoot.querySelector('c-chain-monitor-detail');
		detail.dispatchEvent(new CustomEvent('chainabort', {detail: {executionId: 'aborted-chain-id'}}));
		await Promise.resolve();

		expect(listRefresh).toHaveBeenCalledTimes(1);
	});

	it('should refresh list for any record event until a chain has been in view', async() =>
	{
		const element = await createComponent();
		const list = element.shadowRoot.querySelector('c-chain-monitor-list');
		const detail = element.shadowRoot.querySelector('c-chain-monitor-detail');
		const listRefresh = jest.fn();
		const detailRefresh = jest.fn();
		list.refresh = listRefresh;
		detail.refresh = detailRefresh;

		// No chain has been in view yet, so the key prefix is unknown and the streaming filter
		// deliberately passes every record event; on an empty monitor the first chain still
		// appears live rather than being filtered out.
		const streamingCallback = subscribe.mock.calls[0][2];
		streamingCallback({data: {payload: {kern__RecordId__c: 'some-chain-id'}}});
		await Promise.resolve();

		expect(listRefresh).toHaveBeenCalledTimes(1);
		expect(detailRefresh).not.toHaveBeenCalled();
	});

	it('should refresh detail when streaming event matches selected execution', async() =>
	{
		const element = await createComponent();

		const list = element.shadowRoot.querySelector('c-chain-monitor-list');
		list.dispatchEvent(new CustomEvent('select', {detail: {executionId: 'matching-id'}}));
		await Promise.resolve();

		const detail = element.shadowRoot.querySelector('c-chain-monitor-detail');
		const listRefresh = jest.fn();
		const detailRefresh = jest.fn();
		list.refresh = listRefresh;
		detail.refresh = detailRefresh;

		const streamingCallback = subscribe.mock.calls[0][2];
		streamingCallback({data: {payload: {kern__RecordId__c: 'matching-id'}}});
		await Promise.resolve();

		expect(listRefresh).toHaveBeenCalledTimes(1);
		expect(detailRefresh).toHaveBeenCalledTimes(1);
	});

	it('should not re-query when the streaming event record does not match the chains in view', async() =>
	{
		const element = await createComponent();
		const list = element.shadowRoot.querySelector('c-chain-monitor-list');
		list.dispatchEvent(new CustomEvent('select', {detail: {executionId: 'a05000000000001AAA'}}));
		await Promise.resolve();
		const listRefresh = jest.fn();
		const detailRefresh = jest.fn();
		list.refresh = listRefresh;
		element.shadowRoot.querySelector('c-chain-monitor-detail').refresh = detailRefresh;

		// An org-wide LogEntryEvent about an unrelated record (an Account here) must no longer
		// trigger a full re-query of the chain list.
		const streamingCallback = subscribe.mock.calls[0][2];
		streamingCallback({data: {payload: {kern__RecordId__c: '001000000000001AAA'}}});
		await Promise.resolve();

		expect(listRefresh).not.toHaveBeenCalled();
		expect(detailRefresh).not.toHaveBeenCalled();
	});

	it('should re-query for a chain execution event even when it is not the selected chain', async() =>
	{
		const element = await createComponent();
		const list = element.shadowRoot.querySelector('c-chain-monitor-list');
		list.dispatchEvent(new CustomEvent('select', {detail: {executionId: 'a05000000000001AAA'}}));
		await Promise.resolve();
		const listRefresh = jest.fn();
		const detailRefresh = jest.fn();
		list.refresh = listRefresh;
		element.shadowRoot.querySelector('c-chain-monitor-detail').refresh = detailRefresh;

		// A different chain execution (same org-specific key prefix) still refreshes the list so
		// newly started or re-sorted chains keep appearing live; only the detail stays put.
		const streamingCallback = subscribe.mock.calls[0][2];
		streamingCallback({data: {payload: {kern__RecordId__c: 'a05000000000777AAA'}}});
		await Promise.resolve();

		expect(listRefresh).toHaveBeenCalledTimes(1);
		expect(detailRefresh).not.toHaveBeenCalled();
	});

	it('should subscribe on the unprefixed channel in an unmanaged (no-namespace) deploy', async() =>
	{
		getNamespacePrefix.mockResolvedValueOnce('');

		await createComponent();

		expect(subscribe).toHaveBeenCalledWith('/event/LogEntryEvent__e', -1, expect.any(Function));
	});

	it('should refresh from the unprefixed payload key in an unmanaged (no-namespace) deploy', async() =>
	{
		getNamespacePrefix.mockResolvedValueOnce('');
		const element = await createComponent();
		const list = element.shadowRoot.querySelector('c-chain-monitor-list');
		const listRefresh = jest.fn();
		list.refresh = listRefresh;

		const streamingCallback = subscribe.mock.calls[0][2];
		streamingCallback({data: {payload: {RecordId__c: 'some-chain-id'}}});
		await Promise.resolve();

		expect(listRefresh).toHaveBeenCalledTimes(1);
	});

	it('should treat a nullish prefix as unprefixed rather than corrupting the channel', async() =>
	{
		getNamespacePrefix.mockResolvedValueOnce(undefined);

		await createComponent();

		expect(subscribe).toHaveBeenCalledWith('/event/LogEntryEvent__e', -1, expect.any(Function));
	});

	it('should degrade silently without subscribing when the prefix resolution fails', async() =>
	{
		getNamespacePrefix.mockRejectedValueOnce(new Error('apex unavailable'));
		const element = createElement('c-chain-monitor', {is: ChainMonitor});
		document.body.appendChild(element);
		await Promise.resolve();
		await Promise.resolve();

		expect(subscribe).not.toHaveBeenCalled();
		expect(mockShowErrorToast).not.toHaveBeenCalled();
		// Silent means no toast; the failure is still logged so real-time breakage is visible.
		expect(mockConsoleError).toHaveBeenCalledWith(expect.any(Error), 'ChainMonitor.subscribeToEvents');
		expect(element.shadowRoot.querySelector('c-chain-monitor-list')).toBeTruthy();
	});

	it('should not subscribe when the component disconnects during prefix resolution', async() =>
	{
		let resolvePrefix;
		getNamespacePrefix.mockReturnValueOnce(new Promise((resolve) =>
		{
			resolvePrefix = resolve;
		}));
		const element = createElement('c-chain-monitor', {is: ChainMonitor});
		document.body.appendChild(element);
		document.body.removeChild(element);

		resolvePrefix('kern__');
		await Promise.resolve();
		await Promise.resolve();

		expect(subscribe).not.toHaveBeenCalled();
	});

	it('should release a subscription that resolves after the component disconnects', async() =>
	{
		let resolveSubscribe;
		subscribe.mockReturnValueOnce(new Promise((resolve) =>
		{
			resolveSubscribe = resolve;
		}));
		const element = createElement('c-chain-monitor', {is: ChainMonitor});
		document.body.appendChild(element);
		await Promise.resolve();
		await Promise.resolve();
		document.body.removeChild(element);

		const lateSubscription = {id: 'late-subscription'};
		resolveSubscribe(lateSubscription);
		await Promise.resolve();
		await Promise.resolve();

		expect(unsubscribe).toHaveBeenCalledWith(lateSubscription);
	});

	it('should not start a second subscription when the component reconnects during prefix resolution', async() =>
	{
		let resolveFirstPrefix;
		getNamespacePrefix.mockReturnValueOnce(new Promise((resolve) =>
		{
			resolveFirstPrefix = resolve;
		}));
		subscribe.mockResolvedValueOnce({id: 'live-subscription'});
		const element = createElement('c-chain-monitor', {is: ChainMonitor});
		document.body.appendChild(element);
		document.body.removeChild(element);
		document.body.appendChild(element);
		await Promise.resolve();
		await Promise.resolve();
		expect(subscribe).toHaveBeenCalledTimes(1);

		// The first connection's subscribe run resumes while the component is connected again; a
		// stale run must stand down instead of registering a second, orphaned subscription.
		resolveFirstPrefix('kern__');
		await Promise.resolve();
		await Promise.resolve();

		expect(subscribe).toHaveBeenCalledTimes(1);

		document.body.removeChild(element);
		expect(unsubscribe).toHaveBeenCalledWith({id: 'live-subscription'});
	});

	it('should release a stale subscription that resolves after the component reconnects', async() =>
	{
		let resolveFirstSubscribe;
		subscribe.mockReturnValueOnce(new Promise((resolve) =>
		{
			resolveFirstSubscribe = resolve;
		}));
		subscribe.mockResolvedValueOnce({id: 'second-subscription'});
		const element = createElement('c-chain-monitor', {is: ChainMonitor});
		document.body.appendChild(element);
		await Promise.resolve();
		await Promise.resolve();
		expect(subscribe).toHaveBeenCalledTimes(1);
		document.body.removeChild(element);
		document.body.appendChild(element);
		await Promise.resolve();
		await Promise.resolve();
		await Promise.resolve();

		const staleSubscription = {id: 'first-subscription'};
		resolveFirstSubscribe(staleSubscription);
		await Promise.resolve();
		await Promise.resolve();

		expect(unsubscribe).toHaveBeenCalledWith(staleSubscription);

		unsubscribe.mockClear();
		document.body.removeChild(element);
		expect(unsubscribe).toHaveBeenCalledWith({id: 'second-subscription'});
	});

	it('should log the failure through consoleError when the subscription cannot be established', async() =>
	{
		const failure = new Error('403::Handshake denied');
		subscribe.mockRejectedValueOnce(failure);
		const element = createElement('c-chain-monitor', {is: ChainMonitor});
		document.body.appendChild(element);
		await Promise.resolve();
		await Promise.resolve();
		await Promise.resolve();

		expect(mockConsoleError).toHaveBeenCalledWith(failure, 'ChainMonitor.subscribeToEvents');
	});

	it('should handle subscribe failure gracefully', async() =>
	{
		subscribe.mockRejectedValueOnce(new Error('403:denied_by_security_policy'));
		const element = createElement('c-chain-monitor', {is: ChainMonitor});
		document.body.appendChild(element);
		await Promise.resolve();
		await Promise.resolve();

		const list = element.shadowRoot.querySelector('c-chain-monitor-list');
		expect(list).toBeTruthy();
	});

	it('should handle streaming event without recordId gracefully', async() =>
	{
		await createComponent();

		const streamingCallback = subscribe.mock.calls[0][2];
		expect(() => streamingCallback({data: {payload: {}}})).not.toThrow();
		expect(() => streamingCallback({data: {}})).not.toThrow();
		expect(() => streamingCallback({})).not.toThrow();
	});

	// The container hosts the real chainMonitorList child, whose loadData also calls the
	// controller mock — deep-link assertions therefore filter to calls carrying correlationId.
	function getResolveCalls()
	{
		return mockCallControllerMethod.mock.calls.filter((call) => call[1] && 'correlationId' in call[1]);
	}

	function stubResolveResult(executionId)
	{
		mockCallControllerMethod.mockImplementation((controller, params) =>
		{
			if(typeof controller === 'function')
			{
				controller(params);
			}
			return Promise.resolve(params && 'correlationId' in params ? executionId : {});
		});
	}

	it('should select the deep-linked chain when the correlation resolves', async() =>
	{
		stubResolveResult('resolved-chain-id');
		const element = await createComponent();
		const list = element.shadowRoot.querySelector('c-chain-monitor-list');
		const selectById = jest.fn();
		list.selectById = selectById;

		CurrentPageReference.emit({state: {c__correlationId: 'corr-9'}});
		await Promise.resolve();
		await Promise.resolve();

		expect(getResolveCalls()).toEqual([
			[
				expect.anything(),
				{correlationId: 'corr-9'}
			]
		]);
		const detail = element.shadowRoot.querySelector('c-chain-monitor-detail');
		expect(detail.executionId).toBe('resolved-chain-id');
		expect(selectById).toHaveBeenCalledWith('resolved-chain-id');
	});

	it('should leave the default selection when the correlation resolves to no chain', async() =>
	{
		stubResolveResult(null);
		const element = await createComponent();
		const list = element.shadowRoot.querySelector('c-chain-monitor-list');
		const selectById = jest.fn();
		list.selectById = selectById;

		CurrentPageReference.emit({state: {c__correlationId: 'corr-unknown'}});
		await Promise.resolve();
		await Promise.resolve();

		const detail = element.shadowRoot.querySelector('c-chain-monitor-detail');
		expect(detail.executionId).toBeNull();
		expect(selectById).not.toHaveBeenCalled();
	});

	it('should resolve a repeated correlation only once', async() =>
	{
		stubResolveResult('resolved-chain-id');
		await createComponent();

		CurrentPageReference.emit({state: {c__correlationId: 'corr-9'}});
		await Promise.resolve();
		CurrentPageReference.emit({state: {c__correlationId: 'corr-9'}});
		await Promise.resolve();

		expect(getResolveCalls()).toHaveLength(1);
	});

	it('should ignore page references without a correlation', async() =>
	{
		await createComponent();

		CurrentPageReference.emit({state: {}});
		CurrentPageReference.emit({});
		await Promise.resolve();

		expect(getResolveCalls()).toHaveLength(0);
	});

	it('should keep the deep-linked chain when the list reconciles without it', async() =>
	{
		const offPagePayload = {
			records: [{executionId: 'other-1', chainName: 'Other', status: 'Running', completedSteps: 0, totalSteps: 1}],
			totalCount: 21,
			pageNumber: 1,
			totalPages: 2,
			hasMorePages: true
		};
		mockCallControllerMethod.mockImplementation((controller, params) =>
		{
			if(typeof controller === 'function')
			{
				controller(params);
			}
			return Promise.resolve(params && 'correlationId' in params ? 'off-page-chain-id' : offPagePayload);
		});
		const element = await createComponent();
		const list = element.shadowRoot.querySelector('c-chain-monitor-list');

		CurrentPageReference.emit({state: {c__correlationId: 'corr-off-page'}});
		await Promise.resolve();
		await Promise.resolve();
		await list.refresh();
		await Promise.resolve();

		const detail = element.shadowRoot.querySelector('c-chain-monitor-detail');
		expect(detail.executionId).toBe('off-page-chain-id');
	});

	it('should not stomp a selection the user made during the resolve', async() =>
	{
		let resolveDeepLink;
		mockCallControllerMethod.mockImplementation((controller, params) =>
		{
			if(typeof controller === 'function')
			{
				controller(params);
			}
			if(params && 'correlationId' in params)
			{
				return new Promise((resolve) =>
				{
					resolveDeepLink = resolve;
				});
			}
			return Promise.resolve({});
		});
		const element = await createComponent();
		const list = element.shadowRoot.querySelector('c-chain-monitor-list');
		const selectById = jest.fn();
		list.selectById = selectById;

		CurrentPageReference.emit({state: {c__correlationId: 'corr-slow'}});
		await Promise.resolve();
		list.dispatchEvent(new CustomEvent('select', {detail: {executionId: 'user-pick', isUserSelection: true}}));
		await Promise.resolve();
		resolveDeepLink('late-chain-id');
		await Promise.resolve();
		await Promise.resolve();

		const detail = element.shadowRoot.querySelector('c-chain-monitor-detail');
		expect(detail.executionId).toBe('user-pick');
		expect(selectById).not.toHaveBeenCalled();
	});

	describe('operations control (D8/D13 client leg)', () =>
	{
		const WAITING_STALLED_COUNT = 4;
		const MOCK_ENABLED_STATE = {
			chainProcessingEnabled: true, killSwitchAvailability: 'Available', clearStalledAvailability: 'Available', stalledChainCount: WAITING_STALLED_COUNT
		};
		const MOCK_SUSPENDED_STATE = {
			chainProcessingEnabled: false, killSwitchAvailability: 'Available', clearStalledAvailability: 'ChainProcessingSuspended', stalledChainCount: 0
		};
		const EXPECTED_CLEAR_STALLED_BODY = `Stalled chains waiting: ${WAITING_STALLED_COUNT}. They are checked oldest first. A chain proven to have stopped is re-driven. `
				+ 'A chain that cannot be checked, such as one with no executor job on record, is left exactly as it is. The result says how many fell into each group.';

		// Routes the shared controller mock by the endpoint it was handed: the sweep answers its own
		// tally, every other parameterless call is the operations-state load (the container's only
		// other one), and the hosted list and deep-link calls always carry parameters.
		function stubOperationsState(operationsState, sweepResult)
		{
			mockCallControllerMethod.mockImplementation((controller, params) =>
			{
				if(typeof controller === 'function')
				{
					controller(params);
				}
				if(controller === clearStalledChains)
				{
					return Promise.resolve(sweepResult);
				}
				return Promise.resolve(params === undefined ? operationsState : {});
			});
		}

		// A macrotask flush lets the async click handler (modal await + controller await) fully
		// settle, then two microtask flushes let the re-render land in the DOM.
		async function flushOperationHandler()
		{
			await new Promise((resolve) => setTimeout(resolve, 0));
			await Promise.resolve();
			await Promise.resolve();
		}

		function operationsElement(element, testId)
		{
			return element.shadowRoot.querySelector(`[data-testid="${testId}"]`);
		}

		it('renders the enabled badge with clear-stalled and suspend while processing is enabled', async() =>
		{
			stubOperationsState(MOCK_ENABLED_STATE);
			const element = await createComponent();

			const badge = operationsElement(element, 'operations-state-badge');
			expect(badge.label).toBe('Chains enabled');
			expect(badge.className).toContain('slds-theme_success');
			expect(operationsElement(element, 'clear-stalled-action').disabled).toBeFalsy();
			expect(operationsElement(element, 'suspend-action')).toBeTruthy();
			expect(operationsElement(element, 'resume-action')).toBeFalsy();
		});

		it('renders the suspended badge with resume and a suspension-disabled clear-stalled while suspended', async() =>
		{
			stubOperationsState(MOCK_SUSPENDED_STATE);
			const element = await createComponent();

			const badge = operationsElement(element, 'operations-state-badge');
			expect(badge.label).toBe('Chains suspended');
			expect(badge.className).toContain('slds-theme_warning');
			expect(operationsElement(element, 'suspend-action')).toBeFalsy();
			expect(operationsElement(element, 'resume-action')).toBeTruthy();
			const clearStalled = operationsElement(element, 'clear-stalled-action');
			expect(clearStalled.disabled).toBe(true);
			expect(clearStalled.title).toBe('Chain processing is suspended. Resume it before re-driving chains.');
		});

		it('disables both controls with their refusal tooltips when the user lacks the permissions', async() =>
		{
			stubOperationsState({chainProcessingEnabled: true, killSwitchAvailability: 'PermissionMissing', clearStalledAvailability: 'PermissionMissing'});
			const element = await createComponent();

			const clearStalled = operationsElement(element, 'clear-stalled-action');
			expect(clearStalled.disabled).toBe(true);
			expect(clearStalled.title).toBe('You do not have permission to re-drive chains.');
			const suspend = operationsElement(element, 'suspend-action');
			expect(suspend.disabled).toBe(true);
			expect(suspend.title).toBe('You do not have permission to change chain processing.');
		});

		it('runs the confirmed clear-stalled sweep, toasts the per-bucket counts, and refreshes both panes', async() =>
		{
			stubOperationsState(MOCK_ENABLED_STATE, {candidates: 4, redriven: 2, markedFailed: 1, remainingStalled: 1});
			const element = await createComponent();
			const list = element.shadowRoot.querySelector('c-chain-monitor-list');
			const detail = element.shadowRoot.querySelector('c-chain-monitor-detail');
			const listRefresh = jest.fn();
			const detailRefresh = jest.fn();
			list.refresh = listRefresh;
			detail.refresh = detailRefresh;
			mockChainActionConfirmModalOpen.mockResolvedValueOnce({action: 'confirm'});

			operationsElement(element, 'clear-stalled-action').dispatchEvent(new CustomEvent('click'));
			await flushOperationHandler();

			expect(mockChainActionConfirmModalOpen).toHaveBeenCalledWith({
				size: 'small',
				label: 'Clear stalled chains',
				title: 'Clear stalled chains',
				body: EXPECTED_CLEAR_STALLED_BODY,
				confirmLabel: 'Clear stalled chains',
				cancelLabel: 'Cancel',
				confirmVariant: 'brand'
			});
			expect(mockShowSuccessToast).toHaveBeenCalledWith('4 stalled chains checked: 2 re-driven, 1 marked failed, 1 still waiting.');
			expect(listRefresh).toHaveBeenCalledTimes(1);
			expect(detailRefresh).toHaveBeenCalledTimes(1);
			expect(mockShowErrorToast).not.toHaveBeenCalled();
		});

		it('re-reads the waiting count so the dialog names what is waiting at the moment of the decision', async() =>
		{
			stubOperationsState(MOCK_ENABLED_STATE, {candidates: 0, redriven: 0, markedFailed: 0, remainingStalled: 0});
			const element = await createComponent();
			// Two more chains stall while the page sits open; the dialog must not quote the count
			// the header loaded on arrival.
			stubOperationsState({...MOCK_ENABLED_STATE, stalledChainCount: 6}, {candidates: 0, redriven: 0, markedFailed: 0, remainingStalled: 0});
			mockChainActionConfirmModalOpen.mockResolvedValueOnce({action: 'confirm'});

			operationsElement(element, 'clear-stalled-action').dispatchEvent(new CustomEvent('click'));
			await flushOperationHandler();

			expect(mockChainActionConfirmModalOpen.mock.calls[0][0].body).toContain('Stalled chains waiting: 6.');
		});

		it('toasts the labelled failure when a confirmed sweep answers nothing at all', async() =>
		{
			// callControllerMethod resolves undefined on failure — it has already toasted the raw
			// error; the labelled toast tells the operator what to do about it.
			stubOperationsState(MOCK_ENABLED_STATE, undefined);
			const element = await createComponent();
			mockChainActionConfirmModalOpen.mockResolvedValueOnce({action: 'confirm'});

			operationsElement(element, 'clear-stalled-action').dispatchEvent(new CustomEvent('click'));
			await flushOperationHandler();

			expect(mockShowSuccessToast).not.toHaveBeenCalled();
			expect(mockShowErrorToast).toHaveBeenCalledWith('The action could not be completed. Refresh and try again.');
		});

		it('says why a greyed-out operator action cannot run, on screen and as its accessible description', async() =>
		{
			stubOperationsState(MOCK_SUSPENDED_STATE);
			const element = await createComponent();

			// A disabled button suppresses pointer events, so its tooltip never fires, and it takes
			// no focus, so its assistive description is out of reach for a keyboard-only reader.
			// The visible note is the one path to the reason that needs neither.
			const clearStalled = operationsElement(element, 'clear-stalled-action');
			expect(clearStalled.disabled).toBe(true);
			const description = element.shadowRoot.querySelector(`[id="${clearStalled.getAttribute('aria-describedby')}"]`);
			expect(description.textContent).toBe(clearStalled.title);
			expect(description.textContent).toBe('Chain processing is suspended. Resume it before re-driving chains.');
			expect(description.classList.contains('slds-assistive-text')).toBe(true);
			expect(description.getAttribute('aria-hidden')).toBe('true');

			const notes = element.shadowRoot.querySelectorAll('[data-testid="operations-unavailable-note"]');
			expect(notes.length).toBe(1);
			expect(notes[0].textContent).toBe('Clear stalled: Chain processing is suspended. Resume it before re-driving chains.');
			expect(element.shadowRoot.querySelector('[data-testid="operations-unavailable-notes"]').hasAttribute('aria-hidden')).toBe(false);
		});

		it('names both greyed-out operator actions when the user lacks their permissions', async() =>
		{
			stubOperationsState({chainProcessingEnabled: true, killSwitchAvailability: 'PermissionMissing', clearStalledAvailability: 'PermissionMissing', stalledChainCount: 0});
			const element = await createComponent();

			const notes = Array.from(element.shadowRoot.querySelectorAll('[data-testid="operations-unavailable-note"]')).map((note) => note.textContent);
			expect(notes).toEqual([
				'Clear stalled: You do not have permission to re-drive chains.',
				'Suspend chains: You do not have permission to change chain processing.'
			]);
		});

		it('renders no reason note while every operator action is available', async() =>
		{
			stubOperationsState(MOCK_ENABLED_STATE);
			const element = await createComponent();

			expect(element.shadowRoot.querySelector('[data-testid="operations-unavailable-notes"]')).toBeFalsy();
		});

		it('does not run the sweep when the confirm modal is cancelled', async() =>
		{
			stubOperationsState(MOCK_ENABLED_STATE);
			const element = await createComponent();

			operationsElement(element, 'clear-stalled-action').dispatchEvent(new CustomEvent('click'));
			await flushOperationHandler();

			expect(mockChainActionConfirmModalOpen).toHaveBeenCalledTimes(1);
			expect(mockShowSuccessToast).not.toHaveBeenCalled();
			expect(mockShowErrorToast).not.toHaveBeenCalled();
		});

		it('suspends through the destructive confirm, flips the badge, and refreshes the detail', async() =>
		{
			stubOperationsState(MOCK_ENABLED_STATE);
			const element = await createComponent();
			const detail = element.shadowRoot.querySelector('c-chain-monitor-detail');
			const detailRefresh = jest.fn();
			detail.refresh = detailRefresh;
			mockChainActionConfirmModalOpen.mockResolvedValueOnce({action: 'confirm'});
			mockCallControllerMethod.mockResolvedValueOnce(MOCK_SUSPENDED_STATE);

			operationsElement(element, 'suspend-action').dispatchEvent(new CustomEvent('click'));
			await flushOperationHandler();

			expect(mockChainActionConfirmModalOpen).toHaveBeenCalledWith({
				size: 'small',
				label: 'Suspend chain processing',
				title: 'Suspend chain processing',
				body: 'Every running chain stops at its next step and new chains stop at once, org-wide, until you resume.',
				confirmLabel: 'Suspend chains',
				cancelLabel: 'Cancel',
				confirmVariant: 'destructive'
			});
			expect(mockShowSuccessToast).toHaveBeenCalledWith('Chain processing suspended.');
			expect(operationsElement(element, 'operations-state-badge').label).toBe('Chains suspended');
			expect(operationsElement(element, 'resume-action')).toBeTruthy();
			expect(detailRefresh).toHaveBeenCalledTimes(1);
		});

		it('holds both header controls disabled while a confirmed operation is in server transit', async() =>
		{
			stubOperationsState(MOCK_ENABLED_STATE);
			const element = await createComponent();
			mockChainActionConfirmModalOpen.mockResolvedValueOnce({action: 'confirm'});
			let resolveControllerCall;
			mockCallControllerMethod.mockImplementationOnce(() => new Promise((resolve) =>
			{
				resolveControllerCall = resolve;
			}));

			operationsElement(element, 'suspend-action').dispatchEvent(new CustomEvent('click'));
			await Promise.resolve();
			await Promise.resolve();
			await Promise.resolve();

			// Availability is 'Available' throughout, so only the in-flight guard can disable here:
			// dropping it turns both assertions false while every other test stays green.
			expect(operationsElement(element, 'clear-stalled-action').disabled).toBe(true);
			expect(operationsElement(element, 'suspend-action').disabled).toBe(true);

			resolveControllerCall(MOCK_SUSPENDED_STATE);
			await flushOperationHandler();

			expect(operationsElement(element, 'clear-stalled-action').disabled).toBe(true);
			expect(operationsElement(element, 'resume-action').disabled).toBe(false);
		});

		it('resumes through the brand confirm and flips the badge back', async() =>
		{
			stubOperationsState(MOCK_SUSPENDED_STATE);
			const element = await createComponent();
			mockChainActionConfirmModalOpen.mockResolvedValueOnce({action: 'confirm'});
			mockCallControllerMethod.mockResolvedValueOnce(MOCK_ENABLED_STATE);

			operationsElement(element, 'resume-action').dispatchEvent(new CustomEvent('click'));
			await flushOperationHandler();

			expect(mockChainActionConfirmModalOpen).toHaveBeenCalledWith({
				size: 'small',
				label: 'Resume chain processing',
				title: 'Resume chain processing',
				body: 'New chains run again. Chains stopped during the suspension stay stopped; restart the ones that should run.',
				confirmLabel: 'Resume chains',
				cancelLabel: 'Cancel',
				confirmVariant: 'brand'
			});
			expect(mockShowSuccessToast).toHaveBeenCalledWith('Chain processing resumed.');
			expect(operationsElement(element, 'operations-state-badge').label).toBe('Chains enabled');
			expect(operationsElement(element, 'suspend-action')).toBeTruthy();
		});
	});

	describe('operator action events from the detail pane', () =>
	{
		it('refreshes the list when the detail reports a retried chain', async() =>
		{
			const element = await createComponent();
			const list = element.shadowRoot.querySelector('c-chain-monitor-list');
			const listRefresh = jest.fn();
			list.refresh = listRefresh;

			const detail = element.shadowRoot.querySelector('c-chain-monitor-detail');
			detail.dispatchEvent(new CustomEvent('chainretry', {detail: {executionId: 'retried-chain-id'}}));
			await Promise.resolve();

			expect(listRefresh).toHaveBeenCalledTimes(1);
		});

		it('re-points the selection at the clone and selects its row when the detail reports a restart', async() =>
		{
			const element = await createComponent();
			const list = element.shadowRoot.querySelector('c-chain-monitor-list');
			const listRefresh = jest.fn().mockResolvedValue(undefined);
			const selectById = jest.fn();
			list.refresh = listRefresh;
			list.selectById = selectById;

			const detail = element.shadowRoot.querySelector('c-chain-monitor-detail');
			detail.dispatchEvent(new CustomEvent('chainrestart', {detail: {executionId: 'clone-chain-id'}}));
			await Promise.resolve();
			await Promise.resolve();
			await Promise.resolve();

			expect(detail.executionId).toBe('clone-chain-id');
			expect(listRefresh).toHaveBeenCalledTimes(1);
			expect(selectById).toHaveBeenCalledWith('clone-chain-id');
		});

		it('selects the source run when the detail asks to navigate the restart lineage', async() =>
		{
			const element = await createComponent();
			const list = element.shadowRoot.querySelector('c-chain-monitor-list');
			const selectById = jest.fn();
			list.selectById = selectById;

			const detail = element.shadowRoot.querySelector('c-chain-monitor-detail');
			detail.dispatchEvent(new CustomEvent('chainlineagenavigate', {detail: {executionId: 'source-chain-id'}}));
			await Promise.resolve();

			expect(detail.executionId).toBe('source-chain-id');
			expect(selectById).toHaveBeenCalledWith('source-chain-id');
		});
	});
});
