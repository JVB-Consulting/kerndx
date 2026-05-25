// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for apiTestHarnessForm LWC component
 * @author Jason van Beukering
 * @date February 2026, May 2026
 */

import {createElement} from 'lwc';
import ApiTestHarnessForm from 'c/apiTestHarnessForm';
import getServices from '@salesforce/apex/CTRL_ApiTestHarness.getServices';
import invokeOutbound from '@salesforce/apex/CTRL_ApiTestHarness.invokeOutbound';
import invokeInbound from '@salesforce/apex/CTRL_ApiTestHarness.invokeInbound';

const mockCallControllerMethod = jest.fn().mockResolvedValue([]);
const mockShowSuccessToast = jest.fn();
const mockShowWarningToast = jest.fn();
const mockShowErrorToast = jest.fn();
const mockNavigate = jest.fn();

/**
 * Returns the parsed request payload from the most recent call to the given Apex method.
 * Use this instead of asserting on individual parameters since the controller now accepts
 * a single JSON-serialized DTO_Request.
 */
function extractRequest(apexMethod)
{
	const calls = mockCallControllerMethod.mock.calls.filter(([fn]) => fn === apexMethod);
	if(calls.length === 0)
	{
		return null;
	}
	const args = calls[calls.length - 1][1];
	return JSON.parse(args.requestJson);
}

jest.mock('@salesforce/apex/CTRL_ApiTestHarness.getServices', () => ({default: jest.fn()}), {virtual: true});
jest.mock('@salesforce/apex/CTRL_ApiTestHarness.invokeOutbound', () => ({default: jest.fn()}), {virtual: true});
jest.mock('@salesforce/apex/CTRL_ApiTestHarness.invokeInbound', () => ({default: jest.fn()}), {virtual: true});

jest.mock('c/componentBuilder', () => ({
	ComponentBuilder: jest.fn().mockImplementation(() =>
	{
		const {LightningElement} = require('lwc');
		return class extends LightningElement
		{
			callControllerMethod(...args)
			{
				return mockCallControllerMethod(...args);
			}

			showSuccessToast(...args)
			{
				mockShowSuccessToast(...args);
			}

			showErrorToast(...args)
			{
				mockShowErrorToast(...args);
			}

			showInfoToast()
			{
			}

			showWarningToast(...args)
			{
				mockShowWarningToast(...args);
			}

			navigate(...args)
			{
				mockNavigate(...args);
			}
		};
	})
}), {virtual: true});

jest.mock('c/jsonViewer', () =>
{
	const {LightningElement} = require('lwc');
	return {
		__esModule: true, default: class extends LightningElement
		{
		}
	};
}, {virtual: true});

describe('c-api-test-harness-form', () =>
{
	afterEach(() =>
	{
		while(document.body.firstChild)
		{
			document.body.removeChild(document.body.firstChild);
		}
		jest.clearAllMocks();
	});

	async function createComponent(props = {})
	{
		const element = createElement('c-api-test-harness-form', {is: ApiTestHarnessForm});
		Object.assign(element, props);
		document.body.appendChild(element);
		await Promise.resolve();
		return element;
	}

	async function executeWithResult(element, result)
	{
		mockCallControllerMethod.mockResolvedValueOnce(result);

		const button = element.shadowRoot.querySelector('[data-id="execute"]');
		button.click();
		await Promise.resolve();
		await Promise.resolve();
	}

	async function selectServiceAndExecute(result)
	{
		mockCallControllerMethod.mockResolvedValueOnce([{label: 'Test', value: 'API_Test'}]);
		const element = await createComponent();
		await Promise.resolve();

		const combobox = element.shadowRoot.querySelector('lightning-combobox');
		combobox.dispatchEvent(new CustomEvent('change', {detail: {value: 'API_Test'}}));
		await Promise.resolve();

		await executeWithResult(element, result);
		return element;
	}

	it('should render direction radio group with outbound default', async() =>
	{
		const element = await createComponent();

		const radioGroup = element.shadowRoot.querySelector('lightning-radio-group');
		expect(radioGroup).toBeTruthy();
		expect(radioGroup.value).toBe('Outbound');
	});

	it('should load services on connected callback', async() =>
	{
		await createComponent();

		expect(mockCallControllerMethod).toHaveBeenCalledWith(getServices, {direction: 'Outbound'});
	});

	it('should reload services when direction changes', async() =>
	{
		const element = await createComponent();
		mockCallControllerMethod.mockClear();

		const radioGroup = element.shadowRoot.querySelector('lightning-radio-group');
		radioGroup.dispatchEvent(new CustomEvent('change', {detail: {value: 'Inbound'}}));
		await Promise.resolve();

		expect(mockCallControllerMethod).toHaveBeenCalledWith(getServices, {direction: 'Inbound'});
	});

	it('should show outbound fields when outbound selected', async() =>
	{
		const element = await createComponent();

		const recordIdInput = element.shadowRoot.querySelector('[data-id="recordId"]');
		const parameterKeyInputs = element.shadowRoot.querySelectorAll('[data-testid="parameter-key"]');
		const jsonBodyTextarea = element.shadowRoot.querySelector('[data-id="jsonBody"]');

		expect(recordIdInput).toBeTruthy();
		expect(parameterKeyInputs.length).toBeGreaterThanOrEqual(1);
		expect(jsonBodyTextarea).toBeFalsy();
	});

	it('should show inbound fields when inbound selected', async() =>
	{
		const element = await createComponent();

		const radioGroup = element.shadowRoot.querySelector('lightning-radio-group');
		radioGroup.dispatchEvent(new CustomEvent('change', {detail: {value: 'Inbound'}}));
		await Promise.resolve();

		const jsonBodyTextarea = element.shadowRoot.querySelector('[data-id="jsonBody"]');
		const recordIdInput = element.shadowRoot.querySelector('[data-id="recordId"]');

		expect(jsonBodyTextarea).toBeTruthy();
		expect(recordIdInput).toBeFalsy();
	});

	it('should call invokeOutbound on execute for outbound', async() =>
	{
		mockCallControllerMethod.mockResolvedValueOnce([{label: 'Test', value: 'API_Test'}]);
		const element = await createComponent();
		await Promise.resolve();

		mockCallControllerMethod.mockResolvedValueOnce({isSuccess: true, executionTimeMs: 100});

		const combobox = element.shadowRoot.querySelector('lightning-combobox');
		combobox.dispatchEvent(new CustomEvent('change', {detail: {value: 'API_Test'}}));
		await Promise.resolve();

		const button = element.shadowRoot.querySelector('[data-id="execute"]');
		button.click();
		await Promise.resolve();
		await Promise.resolve();

		const request = extractRequest(invokeOutbound);
		expect(request.serviceName).toBe('API_Test');
	});

	it('should call invokeInbound on execute for inbound', async() =>
	{
		const element = await createComponent();

		const radioGroup = element.shadowRoot.querySelector('lightning-radio-group');
		radioGroup.dispatchEvent(new CustomEvent('change', {detail: {value: 'Inbound'}}));
		await Promise.resolve();

		mockCallControllerMethod.mockResolvedValueOnce({isSuccess: true, executionTimeMs: 50});

		const combobox = element.shadowRoot.querySelector('lightning-combobox');
		combobox.dispatchEvent(new CustomEvent('change', {detail: {value: 'API_Echo'}}));
		await Promise.resolve();

		const button = element.shadowRoot.querySelector('[data-id="execute"]');
		button.click();
		await Promise.resolve();
		await Promise.resolve();

		const request = extractRequest(invokeInbound);
		expect(request.serviceName).toBe('API_Echo');
	});

	it('should display results after execution', async() =>
	{
		const element = await selectServiceAndExecute({isSuccess: true, statusCode: 200, executionTimeMs: 42, serviceName: 'API_Test', status: 'Completed'});

		const badge = element.shadowRoot.querySelector('[data-id="statusBadge"]');
		expect(badge).toBeTruthy();
		expect(badge.label).toBe('Completed');
	});

	it('should show success toast on successful execution', async() =>
	{
		await selectServiceAndExecute({isSuccess: true, executionTimeMs: 10});

		expect(mockShowSuccessToast).toHaveBeenCalledWith('Execution completed successfully');
	});

	it('should show error toast on failed execution', async() =>
	{
		await selectServiceAndExecute({isSuccess: false, status: 'Failed', executionTimeMs: 10, errorMessages: 'Something failed'});

		expect(mockShowErrorToast).toHaveBeenCalledWith('Something failed');
	});

	it('should show warning toast on aborted execution', async() =>
	{
		await selectServiceAndExecute({isSuccess: false, status: 'Aborted', executionTimeMs: 10, errorMessages: 'A valid Triggering Object Id is required.'});

		expect(mockShowWarningToast).toHaveBeenCalledWith('A valid Triggering Object Id is required.');
	});

	it('should remove spinner after execution completes', async() =>
	{
		const element = await selectServiceAndExecute({isSuccess: true, status: 'Completed', executionTimeMs: 10});

		const spinner = element.shadowRoot.querySelector('lightning-spinner');
		expect(spinner).toBeFalsy();
	});

	it('should remove spinner after execution returns undefined', async() =>
	{
		mockCallControllerMethod.mockResolvedValueOnce([{label: 'Test', value: 'API_Test'}]);
		const element = await createComponent();
		await Promise.resolve();

		mockCallControllerMethod.mockResolvedValueOnce(undefined);

		const combobox = element.shadowRoot.querySelector('lightning-combobox');
		combobox.dispatchEvent(new CustomEvent('change', {detail: {value: 'API_Test'}}));
		await Promise.resolve();

		const button = element.shadowRoot.querySelector('[data-id="execute"]');
		button.click();
		await Promise.resolve();
		await Promise.resolve();

		const spinner = element.shadowRoot.querySelector('lightning-spinner');
		expect(spinner).toBeFalsy();
	});

	it('should apply warning badge class for aborted status', async() =>
	{
		const element = await selectServiceAndExecute({isSuccess: false, status: 'Aborted', executionTimeMs: 10});

		const badge = element.shadowRoot.querySelector('[data-id="statusBadge"]');
		expect(badge.label).toBe('Aborted');
		expect(badge.className).toContain('slds-theme_warning');
	});

	it('should show Safe Mode badge when safe mode is enabled', async() =>
	{
		const element = await selectServiceAndExecute({isSuccess: true, executionTimeMs: 10, safeModeEnabled: true});

		const safeModeBadge = element.shadowRoot.querySelector('[data-id="safeModeBadge"]');
		expect(safeModeBadge).toBeTruthy();
		expect(safeModeBadge.label).toBe('Safe Mode');
		expect(safeModeBadge.className).toContain('slds-theme_warning');
	});

	it('should hide Safe Mode badge when safe mode is disabled', async() =>
	{
		const element = await selectServiceAndExecute({isSuccess: true, executionTimeMs: 10, safeModeEnabled: false});

		const safeModeBadge = element.shadowRoot.querySelector('[data-id="safeModeBadge"]');
		expect(safeModeBadge).toBeFalsy();
	});

	it('should show Mocked badge when response is mocked', async() =>
	{
		const element = await selectServiceAndExecute({isSuccess: true, executionTimeMs: 10, isMockedResponse: true});

		const mockedBadge = element.shadowRoot.querySelector('[data-id="mockedBadge"]');
		expect(mockedBadge).toBeTruthy();
		expect(mockedBadge.label).toBe('Mocked');
		expect(mockedBadge.className).toContain('slds-theme_info');
	});

	it('should hide Mocked badge when response is not mocked', async() =>
	{
		const element = await selectServiceAndExecute({isSuccess: true, executionTimeMs: 10, isMockedResponse: false});

		const mockedBadge = element.shadowRoot.querySelector('[data-id="mockedBadge"]');
		expect(mockedBadge).toBeFalsy();
	});

	it('should display timing breakdown in metrics row', async() =>
	{
		const element = await selectServiceAndExecute({
			isSuccess: true, executionTimeMs: 196, handlerDurationMs: 120, calloutDurationMs: 50, commitDurationMs: 26
		});

		const metrics = element.shadowRoot.querySelectorAll('.slds-size_1-of-3');
		expect(metrics).toHaveLength(6);

		const metricTexts = Array.from(metrics).map(col => col.querySelectorAll('p')[1].textContent);
		expect(metricTexts).toContain('196ms');
		expect(metricTexts).toContain('120ms');
		expect(metricTexts).toContain('50ms');
		expect(metricTexts).toContain('26ms');
	});

	it('should show dash for null timing values', async() =>
	{
		const element = await selectServiceAndExecute({isSuccess: true, executionTimeMs: 100});

		const metrics = element.shadowRoot.querySelectorAll('.slds-size_1-of-3');
		const handlerText = metrics[2].querySelectorAll('p')[1].textContent;
		const calloutText = metrics[3].querySelectorAll('p')[1].textContent;
		const commitText = metrics[4].querySelectorAll('p')[1].textContent;

		expect(handlerText).toBe('\u2014');
		expect(calloutText).toBe('\u2014');
		expect(commitText).toBe('\u2014');
	});

	it('should copy summary to clipboard', async() =>
	{
		const mockWriteText = jest.fn().mockResolvedValue(undefined);
		Object.assign(navigator, {clipboard: {writeText: mockWriteText}});

		const element = await selectServiceAndExecute({
			isSuccess: true,
			statusCode: 200,
			executionTimeMs: 196,
			handlerDurationMs: 120,
			calloutDurationMs: 50,
			commitDurationMs: 26,
			serviceName: 'API_Test',
			status: 'Completed',
			safeModeEnabled: true,
			isMockedResponse: false,
			apiCallId: 'a00O500000cZuhOIAS'
		});

		const copyButton = element.shadowRoot.querySelector('[data-id="copySummary"]');
		copyButton.click();
		await Promise.resolve();

		expect(mockWriteText).toHaveBeenCalledWith(expect.stringContaining('Service: API_Test'));
		expect(mockWriteText).toHaveBeenCalledWith(expect.stringContaining('Status: Completed (200)'));
		expect(mockWriteText).toHaveBeenCalledWith(expect.stringContaining('Total: 196ms'));
		expect(mockWriteText).toHaveBeenCalledWith(expect.stringContaining('Handler: 120ms'));
		expect(mockWriteText).toHaveBeenCalledWith(expect.stringContaining('Safe Mode: Enabled'));
		expect(mockWriteText).toHaveBeenCalledWith(expect.stringContaining('Mocked: No'));
		expect(mockWriteText).toHaveBeenCalledWith(expect.stringContaining('API Call ID: a00O500000cZuhOIAS'));
		expect(mockShowSuccessToast).toHaveBeenCalledWith('Summary copied');
	});

	it('should update recordId on input change', async() =>
	{
		const element = await createComponent();

		const input = element.shadowRoot.querySelector('[data-id="recordId"]');
		input.dispatchEvent(new CustomEvent('change', {detail: {value: '001000000000001'}}));
		await Promise.resolve();

		mockCallControllerMethod.mockResolvedValueOnce({isSuccess: true, executionTimeMs: 5});

		const combobox = element.shadowRoot.querySelector('lightning-combobox');
		combobox.dispatchEvent(new CustomEvent('change', {detail: {value: 'API_Test'}}));
		await Promise.resolve();

		const button = element.shadowRoot.querySelector('[data-id="execute"]');
		button.click();
		await Promise.resolve();
		await Promise.resolve();

		const request = extractRequest(invokeOutbound);
		expect(request.recordId).toBe('001000000000001');
	});

	it('should update parameter key/value via the grid inputs', async() =>
	{
		const element = await createComponent();

		const keyInput = element.shadowRoot.querySelector('[data-testid="parameter-key"]');
		const valueInput = element.shadowRoot.querySelector('[data-testid="parameter-value"]');

		keyInput.dispatchEvent(new CustomEvent('change', {detail: {value: 'key'}}));
		await Promise.resolve();
		valueInput.dispatchEvent(new CustomEvent('change', {detail: {value: 'value'}}));
		await Promise.resolve();

		mockCallControllerMethod.mockResolvedValueOnce({isSuccess: true, executionTimeMs: 5});

		const combobox = element.shadowRoot.querySelector('lightning-combobox');
		combobox.dispatchEvent(new CustomEvent('change', {detail: {value: 'API_Test'}}));
		await Promise.resolve();

		const button = element.shadowRoot.querySelector('[data-id="execute"]');
		button.click();
		await Promise.resolve();
		await Promise.resolve();

		const request = extractRequest(invokeOutbound);
		expect(request.parameters).toEqual([{name: 'key', value: 'value'}]);
	});

	it('should update jsonBody on textarea change', async() =>
	{
		const element = await createComponent();

		const radioGroup = element.shadowRoot.querySelector('lightning-radio-group');
		radioGroup.dispatchEvent(new CustomEvent('change', {detail: {value: 'Inbound'}}));
		await Promise.resolve();

		const textarea = element.shadowRoot.querySelector('[data-id="jsonBody"]');
		textarea.dispatchEvent(new CustomEvent('change', {detail: {value: '{"test":true}'}}));
		await Promise.resolve();

		mockCallControllerMethod.mockResolvedValueOnce({isSuccess: true, executionTimeMs: 5});

		const combobox = element.shadowRoot.querySelector('lightning-combobox');
		combobox.dispatchEvent(new CustomEvent('change', {detail: {value: 'API_Echo'}}));
		await Promise.resolve();

		const button = element.shadowRoot.querySelector('[data-id="execute"]');
		button.click();
		await Promise.resolve();
		await Promise.resolve();

		const request = extractRequest(invokeInbound);
		expect(request.jsonBody).toBe('{"test":true}');
	});

	it('should toggle safe mode', async() =>
	{
		const element = await createComponent();

		const safeModeToggle = element.shadowRoot.querySelector('[data-id="safeMode"]');
		safeModeToggle.checked = false;
		safeModeToggle.dispatchEvent(new CustomEvent('change'));
		await Promise.resolve();

		mockCallControllerMethod.mockResolvedValueOnce({isSuccess: true, executionTimeMs: 5});

		const combobox = element.shadowRoot.querySelector('lightning-combobox');
		combobox.dispatchEvent(new CustomEvent('change', {detail: {value: 'API_Test'}}));
		await Promise.resolve();

		const button = element.shadowRoot.querySelector('[data-id="execute"]');
		button.click();
		await Promise.resolve();
		await Promise.resolve();

		const request = extractRequest(invokeOutbound);
		expect(request.enableSafeMode).toBe(false);
	});

	it('should toggle mocking', async() =>
	{
		const element = await createComponent();

		const mockingToggle = element.shadowRoot.querySelector('[data-id="mocking"]');
		mockingToggle.checked = true;
		mockingToggle.dispatchEvent(new CustomEvent('change'));
		await Promise.resolve();

		mockCallControllerMethod.mockResolvedValueOnce({isSuccess: true, executionTimeMs: 5});

		const combobox = element.shadowRoot.querySelector('lightning-combobox');
		combobox.dispatchEvent(new CustomEvent('change', {detail: {value: 'API_Test'}}));
		await Promise.resolve();

		const button = element.shadowRoot.querySelector('[data-id="execute"]');
		button.click();
		await Promise.resolve();
		await Promise.resolve();

		const request = extractRequest(invokeOutbound);
		expect(request.enableMocking).toBe(true);
	});

	it('should default serviceOptions to empty array when loadServices returns undefined', async() =>
	{
		mockCallControllerMethod.mockResolvedValueOnce(undefined);
		const element = await createComponent();
		await Promise.resolve();

		const combobox = element.shadowRoot.querySelector('lightning-combobox');
		expect(combobox.options).toEqual([]);
	});

	it('should show error and clear result when execution returns undefined', async() =>
	{
		mockCallControllerMethod.mockResolvedValueOnce([{label: 'Test', value: 'API_Test'}]);
		const element = await createComponent();
		await Promise.resolve();

		mockCallControllerMethod.mockResolvedValueOnce(undefined);

		const combobox = element.shadowRoot.querySelector('lightning-combobox');
		combobox.dispatchEvent(new CustomEvent('change', {detail: {value: 'API_Test'}}));
		await Promise.resolve();

		const button = element.shadowRoot.querySelector('[data-id="execute"]');
		button.click();
		await Promise.resolve();
		await Promise.resolve();

		expect(mockShowErrorToast).toHaveBeenCalledWith('Execution failed to return a result');
		expect(element.shadowRoot.querySelector('[data-id="statusBadge"]')).toBeFalsy();
	});

	it('should render request headers as table rows', async() =>
	{
		const element = await selectServiceAndExecute({
			isSuccess: true, executionTimeMs: 10, requestHeaders: '{"Content-Type":"application/json","X-Request-Id":"abc123"}'
		});

		const rows = element.shadowRoot.querySelectorAll('table tbody tr');
		expect(rows).toHaveLength(2);

		const cells = rows[0].querySelectorAll('td');
		expect(cells[0].textContent).toBe('Content-Type');
		expect(cells[1].textContent).toBe('application/json');
	});

	it('should render response headers as table rows', async() =>
	{
		const element = await selectServiceAndExecute({
			isSuccess: true, executionTimeMs: 10, responseHeaders: '{"X-Correlation-Id":"xyz789"}'
		});

		const tables = element.shadowRoot.querySelectorAll('table');
		expect(tables.length).toBeGreaterThan(0);

		const lastTable = tables[tables.length - 1];
		const rows = lastTable.querySelectorAll('tbody tr');
		expect(rows).toHaveLength(1);

		const cells = rows[0].querySelectorAll('td');
		expect(cells[0].textContent).toBe('X-Correlation-Id');
		expect(cells[1].textContent).toBe('xyz789');
	});

	it('should unwrap nameValueMap wrapper from headers', async() =>
	{
		const element = await selectServiceAndExecute({
			isSuccess: true, executionTimeMs: 10, requestHeaders: '{"nameValueMap":{"Content-Type":"application/json"}}'
		});

		const rows = element.shadowRoot.querySelectorAll('table tbody tr');
		expect(rows).toHaveLength(1);

		const cells = rows[0].querySelectorAll('td');
		expect(cells[0].textContent).toBe('Content-Type');
		expect(cells[1].textContent).toBe('application/json');
	});

	it('should hide header tables when headers are not present', async() =>
	{
		const element = await selectServiceAndExecute({isSuccess: true, executionTimeMs: 10});

		const tables = element.shadowRoot.querySelectorAll('table');
		expect(tables).toHaveLength(0);
	});

	it('should show empty state message when no tab content exists', async() =>
	{
		const element = await selectServiceAndExecute({isSuccess: true, executionTimeMs: 10});

		const tabset = element.shadowRoot.querySelector('lightning-tabset');
		expect(tabset).toBeFalsy();

		const emptyMessage = element.shadowRoot.querySelector('.slds-text-color_weak');
		expect(emptyMessage).toBeTruthy();
		expect(emptyMessage.textContent).toContain('No request or response data');
	});

	it('should render tabset with Request and Response tabs when content exists', async() =>
	{
		const element = await selectServiceAndExecute({
			isSuccess: true, executionTimeMs: 10, requestBody: '{"hello":"world"}', responseBody: '{"status":"ok"}'
		});

		const tabset = element.shadowRoot.querySelector('lightning-tabset');
		expect(tabset).toBeTruthy();

		const tabs = element.shadowRoot.querySelectorAll('lightning-tab');
		expect(tabs.length).toBeGreaterThanOrEqual(2);
		expect(tabs[0].label).toBe('Request');
		expect(tabs[1].label).toBe('Response');
	});

	it('should hide Request tab when no request body or headers', async() =>
	{
		const element = await selectServiceAndExecute({
			isSuccess: true, executionTimeMs: 10, responseBody: '{"status":"ok"}'
		});

		const tabs = element.shadowRoot.querySelectorAll('lightning-tab');
		const requestTab = Array.from(tabs).find(tab => tab.label === 'Request');
		expect(requestTab).toBeFalsy();
	});

	it('should hide Response tab when no response body or headers', async() =>
	{
		const element = await selectServiceAndExecute({
			isSuccess: true, executionTimeMs: 10, requestBody: '{"hello":"world"}'
		});

		const tabs = element.shadowRoot.querySelectorAll('lightning-tab');
		const responseTab = Array.from(tabs).find(tab => tab.label === 'Response');
		expect(responseTab).toBeFalsy();
	});

	it('should render Errors tab when errors are present', async() =>
	{
		const element = await selectServiceAndExecute({
			isSuccess: false, status: 'Failed', executionTimeMs: 10, errorMessages: 'Something went wrong'
		});

		const tabs = element.shadowRoot.querySelectorAll('lightning-tab');
		const errorTab = Array.from(tabs).find(tab => tab.label === 'Errors');
		expect(errorTab).toBeTruthy();
	});

	it('should not render Errors tab when no errors', async() =>
	{
		const element = await selectServiceAndExecute({isSuccess: true, executionTimeMs: 10});

		const tabs = element.shadowRoot.querySelectorAll('lightning-tab');
		const errorTab = Array.from(tabs).find(tab => tab.label === 'Errors');
		expect(errorTab).toBeFalsy();
	});

	it('should copy request headers to clipboard', async() =>
	{
		const mockWriteText = jest.fn().mockResolvedValue(undefined);
		Object.assign(navigator, {clipboard: {writeText: mockWriteText}});

		const element = await selectServiceAndExecute({
			isSuccess: true, executionTimeMs: 10, requestHeaders: '{"Content-Type":"application/json"}'
		});

		const copyButton = element.shadowRoot.querySelector('[data-id="copyRequestHeaders"]');
		copyButton.click();
		await Promise.resolve();

		expect(mockWriteText).toHaveBeenCalledWith('Content-Type: application/json');
		expect(mockShowSuccessToast).toHaveBeenCalledWith('Request headers copied');
	});

	it('should copy response headers to clipboard', async() =>
	{
		const mockWriteText = jest.fn().mockResolvedValue(undefined);
		Object.assign(navigator, {clipboard: {writeText: mockWriteText}});

		const element = await selectServiceAndExecute({
			isSuccess: true, executionTimeMs: 10, responseHeaders: '{"X-Request-Id":"abc123"}'
		});

		const copyButton = element.shadowRoot.querySelector('[data-id="copyResponseHeaders"]');
		copyButton.click();
		await Promise.resolve();

		expect(mockWriteText).toHaveBeenCalledWith('X-Request-Id: abc123');
		expect(mockShowSuccessToast).toHaveBeenCalledWith('Response headers copied');
	});

	it('should copy request body to clipboard', async() =>
	{
		const mockWriteText = jest.fn().mockResolvedValue(undefined);
		Object.assign(navigator, {clipboard: {writeText: mockWriteText}});

		const element = await selectServiceAndExecute({
			isSuccess: true, executionTimeMs: 10, requestBody: '{"hello":"world"}'
		});

		const copyButton = element.shadowRoot.querySelector('[data-id="copyRequestBody"]');
		copyButton.click();
		await Promise.resolve();

		expect(mockWriteText).toHaveBeenCalledWith('{"hello":"world"}');
		expect(mockShowSuccessToast).toHaveBeenCalledWith('Request body copied');
	});

	it('should copy response body to clipboard', async() =>
	{
		const mockWriteText = jest.fn().mockResolvedValue(undefined);
		Object.assign(navigator, {clipboard: {writeText: mockWriteText}});

		const element = await selectServiceAndExecute({
			isSuccess: true, executionTimeMs: 10, responseBody: '{"status":"ok"}'
		});

		const copyButton = element.shadowRoot.querySelector('[data-id="copyResponseBody"]');
		copyButton.click();
		await Promise.resolve();

		expect(mockWriteText).toHaveBeenCalledWith('{"status":"ok"}');
		expect(mockShowSuccessToast).toHaveBeenCalledWith('Response body copied');
	});

	it('should copy errors to clipboard', async() =>
	{
		const mockWriteText = jest.fn().mockResolvedValue(undefined);
		Object.assign(navigator, {clipboard: {writeText: mockWriteText}});

		const element = await selectServiceAndExecute({
			isSuccess: false, status: 'Failed', executionTimeMs: 10, errorMessages: 'Something went wrong'
		});

		const copyButton = element.shadowRoot.querySelector('[data-id="copyErrors"]');
		copyButton.click();
		await Promise.resolve();

		expect(mockWriteText).toHaveBeenCalledWith('Something went wrong');
		expect(mockShowSuccessToast).toHaveBeenCalledWith('Errors copied');
	});

	it('should show error toast when clipboard write fails', async() =>
	{
		const mockWriteText = jest.fn().mockRejectedValue(new Error('Permission denied'));
		Object.assign(navigator, {clipboard: {writeText: mockWriteText}});

		const element = await selectServiceAndExecute({
			isSuccess: true, executionTimeMs: 10, requestHeaders: '{"Content-Type":"application/json"}'
		});

		const copyButton = element.shadowRoot.querySelector('[data-id="copyRequestHeaders"]');
		copyButton.click();
		await Promise.resolve();

		expect(mockShowErrorToast).toHaveBeenCalledWith('Failed to copy to clipboard');
	});

	it('should handle malformed header JSON gracefully', async() =>
	{
		const element = await selectServiceAndExecute({
			isSuccess: true, executionTimeMs: 10, requestHeaders: 'not-valid-json'
		});

		const tables = element.shadowRoot.querySelectorAll('table');
		expect(tables).toHaveLength(0);
	});

	it('should mark service combobox as required', async() =>
	{
		const element = await createComponent();

		const combobox = element.shadowRoot.querySelector('lightning-combobox');
		expect(combobox.required).toBe(true);
	});

	it('should show error toast when a parameter value has no key', async() =>
	{
		mockCallControllerMethod.mockResolvedValueOnce([{label: 'Test', value: 'API_Test'}]);
		const element = await createComponent();
		await Promise.resolve();

		const combobox = element.shadowRoot.querySelector('lightning-combobox');
		combobox.dispatchEvent(new CustomEvent('change', {detail: {value: 'API_Test'}}));
		await Promise.resolve();

		const valueInputs = element.shadowRoot.querySelectorAll('[data-testid="parameter-value"]');
		valueInputs[0].dispatchEvent(new CustomEvent('change', {detail: {value: 'orphan'}}));
		await Promise.resolve();

		const button = element.shadowRoot.querySelector('[data-id="execute"]');
		button.click();
		await Promise.resolve();

		expect(mockShowErrorToast).toHaveBeenCalledWith('Parameter key cannot be blank when a value is provided.');
		expect(mockCallControllerMethod).not.toHaveBeenCalledWith(invokeOutbound, expect.anything());
	});

	it('should allow valid key-value parameter pairs', async() =>
	{
		mockCallControllerMethod.mockResolvedValueOnce([{label: 'Test', value: 'API_Test'}]);
		const element = await createComponent();
		await Promise.resolve();

		const combobox = element.shadowRoot.querySelector('lightning-combobox');
		combobox.dispatchEvent(new CustomEvent('change', {detail: {value: 'API_Test'}}));
		await Promise.resolve();

		const firstKey = element.shadowRoot.querySelectorAll('[data-testid="parameter-key"]')[0];
		const firstValue = element.shadowRoot.querySelectorAll('[data-testid="parameter-value"]')[0];
		firstKey.dispatchEvent(new CustomEvent('change', {detail: {value: 'key'}}));
		await Promise.resolve();
		firstValue.dispatchEvent(new CustomEvent('change', {detail: {value: 'value'}}));
		await Promise.resolve();

		const addButton = element.shadowRoot.querySelector('[data-testid="add-parameter"]');
		addButton.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();

		const secondKey = element.shadowRoot.querySelectorAll('[data-testid="parameter-key"]')[1];
		const secondValue = element.shadowRoot.querySelectorAll('[data-testid="parameter-value"]')[1];
		secondKey.dispatchEvent(new CustomEvent('change', {detail: {value: 'key2'}}));
		await Promise.resolve();
		secondValue.dispatchEvent(new CustomEvent('change', {detail: {value: 'value2'}}));
		await Promise.resolve();

		mockCallControllerMethod.mockResolvedValueOnce({isSuccess: true, executionTimeMs: 5});

		const button = element.shadowRoot.querySelector('[data-id="execute"]');
		button.click();
		await Promise.resolve();
		await Promise.resolve();

		const request = extractRequest(invokeOutbound);
		expect(request.parameters).toEqual([
			{name: 'key', value: 'value'},
			{name: 'key2', value: 'value2'}
		]);
	});

	it('should show error toast for invalid JSON body', async() =>
	{
		const element = await createComponent();

		const radioGroup = element.shadowRoot.querySelector('lightning-radio-group');
		radioGroup.dispatchEvent(new CustomEvent('change', {detail: {value: 'Inbound'}}));
		await Promise.resolve();

		const combobox = element.shadowRoot.querySelector('lightning-combobox');
		combobox.dispatchEvent(new CustomEvent('change', {detail: {value: 'API_Echo'}}));
		await Promise.resolve();

		const textarea = element.shadowRoot.querySelector('[data-id="jsonBody"]');
		textarea.dispatchEvent(new CustomEvent('change', {detail: {value: '{invalid json content!!!}'}}));
		await Promise.resolve();

		const button = element.shadowRoot.querySelector('[data-id="execute"]');
		button.click();
		await Promise.resolve();

		expect(mockShowErrorToast).toHaveBeenCalledWith('JSON Body contains invalid JSON.');
		expect(mockCallControllerMethod).not.toHaveBeenCalledWith(invokeInbound, expect.anything());
	});

	it('should allow valid JSON body', async() =>
	{
		const element = await createComponent();

		const radioGroup = element.shadowRoot.querySelector('lightning-radio-group');
		radioGroup.dispatchEvent(new CustomEvent('change', {detail: {value: 'Inbound'}}));
		await Promise.resolve();

		const combobox = element.shadowRoot.querySelector('lightning-combobox');
		combobox.dispatchEvent(new CustomEvent('change', {detail: {value: 'API_Echo'}}));
		await Promise.resolve();

		const textarea = element.shadowRoot.querySelector('[data-id="jsonBody"]');
		textarea.dispatchEvent(new CustomEvent('change', {detail: {value: '{"valid":"json"}'}}));
		await Promise.resolve();

		mockCallControllerMethod.mockResolvedValueOnce({isSuccess: true, executionTimeMs: 5});

		const button = element.shadowRoot.querySelector('[data-id="execute"]');
		button.click();
		await Promise.resolve();
		await Promise.resolve();

		const request = extractRequest(invokeInbound);
		expect(request.jsonBody).toBe('{"valid":"json"}');
	});

	it('should filter out headers with null values', async() =>
	{
		const element = await selectServiceAndExecute({
			isSuccess: true, executionTimeMs: 10, responseHeaders: '{"Content-Type":null,"X-Request-Id":"abc123"}'
		});

		const tables = element.shadowRoot.querySelectorAll('table');
		const lastTable = tables[tables.length - 1];
		const rows = lastTable.querySelectorAll('tbody tr');
		expect(rows).toHaveLength(1);

		const cells = rows[0].querySelectorAll('td');
		expect(cells[0].textContent).toBe('X-Request-Id');
		expect(cells[1].textContent).toBe('abc123');
	});

	it('should filter out headers with empty string values', async() =>
	{
		const element = await selectServiceAndExecute({
			isSuccess: true, executionTimeMs: 10, responseHeaders: '{"Content-Type":"","X-Request-Id":"abc123"}'
		});

		const tables = element.shadowRoot.querySelectorAll('table');
		const lastTable = tables[tables.length - 1];
		const rows = lastTable.querySelectorAll('tbody tr');
		expect(rows).toHaveLength(1);

		const cells = rows[0].querySelectorAll('td');
		expect(cells[0].textContent).toBe('X-Request-Id');
	});

	it('should join array header values with commas', async() =>
	{
		const element = await selectServiceAndExecute({
			isSuccess: true, executionTimeMs: 10, responseHeaders: '{"Accept":["text/html","application/json"]}'
		});

		const tables = element.shadowRoot.querySelectorAll('table');
		const lastTable = tables[tables.length - 1];
		const rows = lastTable.querySelectorAll('tbody tr');

		const cells = rows[0].querySelectorAll('td');
		expect(cells[0].textContent).toBe('Accept');
		expect(cells[1].textContent).toBe('text/html, application/json');
	});

	it('should show dash for null status code', async() =>
	{
		const element = await selectServiceAndExecute({isSuccess: false, status: 'Aborted', executionTimeMs: 10});

		const metrics = element.shadowRoot.querySelectorAll('.slds-size_1-of-3');
		const statusCodeText = metrics[0].querySelectorAll('p')[1].textContent;
		expect(statusCodeText).toBe('\u2014');
	});

	it('should show dash for blank API Call ID', async() =>
	{
		const element = await selectServiceAndExecute({isSuccess: true, executionTimeMs: 10, apiCallId: ''});

		const metrics = element.shadowRoot.querySelectorAll('.slds-size_1-of-3');
		const apiCallIdText = metrics[5].querySelectorAll('p')[1].textContent;
		expect(apiCallIdText).toBe('\u2014');
	});

	it('should show dash for null API Call ID', async() =>
	{
		const element = await selectServiceAndExecute({isSuccess: true, executionTimeMs: 10});

		const metrics = element.shadowRoot.querySelectorAll('.slds-size_1-of-3');
		const apiCallIdText = metrics[5].querySelectorAll('p')[1].textContent;
		expect(apiCallIdText).toBe('\u2014');
	});

	it('should filter out parameter rows with blank keys when serializing for Apex', async() =>
	{
		mockCallControllerMethod.mockResolvedValueOnce([{label: 'Test', value: 'API_Test'}]);
		const element = await createComponent();
		await Promise.resolve();

		const combobox = element.shadowRoot.querySelector('lightning-combobox');
		combobox.dispatchEvent(new CustomEvent('change', {detail: {value: 'API_Test'}}));
		await Promise.resolve();

		const addButton = element.shadowRoot.querySelector('[data-testid="add-parameter"]');
		addButton.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();

		const keyInputs = element.shadowRoot.querySelectorAll('[data-testid="parameter-key"]');
		const valueInputs = element.shadowRoot.querySelectorAll('[data-testid="parameter-value"]');

		keyInputs[0].dispatchEvent(new CustomEvent('change', {detail: {value: 'keepMe'}}));
		await Promise.resolve();
		valueInputs[0].dispatchEvent(new CustomEvent('change', {detail: {value: 'stays'}}));
		await Promise.resolve();
		valueInputs[1].dispatchEvent(new CustomEvent('change', {detail: {value: ''}}));
		await Promise.resolve();

		mockCallControllerMethod.mockResolvedValueOnce({isSuccess: true, executionTimeMs: 5});

		const button = element.shadowRoot.querySelector('[data-id="execute"]');
		button.click();
		await Promise.resolve();
		await Promise.resolve();

		const request = extractRequest(invokeOutbound);
		expect(request.parameters).toEqual([{name: 'keepMe', value: 'stays'}]);
	});

	it('should show check icon after successful copy', async() =>
	{
		const mockWriteText = jest.fn().mockResolvedValue(undefined);
		Object.assign(navigator, {clipboard: {writeText: mockWriteText}});

		const element = await selectServiceAndExecute({
			isSuccess: true, executionTimeMs: 10, serviceName: 'API_Test', status: 'Completed'
		});

		const copyButton = element.shadowRoot.querySelector('[data-id="copySummary"]');
		copyButton.click();
		await Promise.resolve();
		await Promise.resolve();

		const updatedButton = element.shadowRoot.querySelector('[data-id="copySummary"]');
		expect(updatedButton.iconName).toBe('utility:check');
	});

	it('should skip validation for empty parameters', async() =>
	{
		mockCallControllerMethod.mockResolvedValueOnce([{label: 'Test', value: 'API_Test'}]);
		const element = await createComponent();
		await Promise.resolve();

		const combobox = element.shadowRoot.querySelector('lightning-combobox');
		combobox.dispatchEvent(new CustomEvent('change', {detail: {value: 'API_Test'}}));
		await Promise.resolve();

		mockCallControllerMethod.mockResolvedValueOnce({isSuccess: true, executionTimeMs: 5});

		const button = element.shadowRoot.querySelector('[data-id="execute"]');
		button.click();
		await Promise.resolve();
		await Promise.resolve();

		const request = extractRequest(invokeOutbound);
		expect(request.parameters).toEqual([]);
	});

	it('should skip validation for empty JSON body', async() =>
	{
		const element = await createComponent();

		const radioGroup = element.shadowRoot.querySelector('lightning-radio-group');
		radioGroup.dispatchEvent(new CustomEvent('change', {detail: {value: 'Inbound'}}));
		await Promise.resolve();

		const combobox = element.shadowRoot.querySelector('lightning-combobox');
		combobox.dispatchEvent(new CustomEvent('change', {detail: {value: 'API_Echo'}}));
		await Promise.resolve();

		mockCallControllerMethod.mockResolvedValueOnce({isSuccess: true, executionTimeMs: 5});

		const button = element.shadowRoot.querySelector('[data-id="execute"]');
		button.click();
		await Promise.resolve();
		await Promise.resolve();

		const request = extractRequest(invokeInbound);
		expect(request.jsonBody).toBe('');
	});

	it('should render a default empty parameter row on load', async() =>
	{
		const element = await createComponent();

		const rows = element.shadowRoot.querySelectorAll('.parameter-row');
		expect(rows.length).toBe(1);
	});

	it('should add a new parameter row when Add parameter is clicked', async() =>
	{
		const element = await createComponent();

		const addButton = element.shadowRoot.querySelector('[data-testid="add-parameter"]');
		addButton.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();

		const rows = element.shadowRoot.querySelectorAll('.parameter-row');
		expect(rows.length).toBe(2);
	});

	it('should remove a parameter row when the delete button is clicked', async() =>
	{
		const element = await createComponent();

		const addButton = element.shadowRoot.querySelector('[data-testid="add-parameter"]');
		addButton.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();
		addButton.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();

		expect(element.shadowRoot.querySelectorAll('.parameter-row').length).toBe(3);

		const removeButtons = element.shadowRoot.querySelectorAll('[data-testid="remove-parameter"]');
		removeButtons[0].dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();

		expect(element.shadowRoot.querySelectorAll('.parameter-row').length).toBe(2);
	});

	it('should add a replacement row when the last row is removed', async() =>
	{
		const element = await createComponent();

		const removeButton = element.shadowRoot.querySelector('[data-testid="remove-parameter"]');
		removeButton.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();

		const rows = element.shadowRoot.querySelectorAll('.parameter-row');
		expect(rows.length).toBe(1);
	});

	it('should render the empty response placeholder before execution', async() =>
	{
		const element = await createComponent();

		const emptyState = element.shadowRoot.querySelector('[data-testid="empty-response"]');
		expect(emptyState).toBeTruthy();
	});

	it('should hide the empty response placeholder after execution', async() =>
	{
		const element = await selectServiceAndExecute({isSuccess: true, executionTimeMs: 10});

		const emptyState = element.shadowRoot.querySelector('[data-testid="empty-response"]');
		expect(emptyState).toBeFalsy();
	});

	it('should render Safe Mode badge by default (Safe ON, Mock OFF)', async() =>
	{
		const element = await createComponent();

		const badge = element.shadowRoot.querySelector('[data-testid="mode-badge"]');
		expect(badge.label).toBe('Safe Mode');
		expect(badge.className).toContain('slds-theme_info');

		const safetyBar = element.shadowRoot.querySelector('[data-testid="safety-bar"]');
		expect(safetyBar.className).toBe('safety-bar');
	});

	it('should render Full Sandbox badge when Safe Mode and Mocking are both on', async() =>
	{
		const element = await createComponent();

		const mockingToggle = element.shadowRoot.querySelector('[data-id="mocking"]');
		mockingToggle.checked = true;
		mockingToggle.dispatchEvent(new CustomEvent('change'));
		await Promise.resolve();

		const badge = element.shadowRoot.querySelector('[data-testid="mode-badge"]');
		expect(badge.label).toBe('Full Sandbox');
		expect(badge.className).toContain('slds-theme_success');

		const safetyBar = element.shadowRoot.querySelector('[data-testid="safety-bar"]');
		expect(safetyBar.className).toContain('safety-bar_sandbox');
	});

	it('should render mixed Live DML + Mocked callouts badge when Safe Mode off and Mocking on', async() =>
	{
		const element = await createComponent();

		const safeModeToggle = element.shadowRoot.querySelector('[data-id="safeMode"]');
		safeModeToggle.checked = false;
		safeModeToggle.dispatchEvent(new CustomEvent('change'));
		await Promise.resolve();

		const mockingToggle = element.shadowRoot.querySelector('[data-id="mocking"]');
		mockingToggle.checked = true;
		mockingToggle.dispatchEvent(new CustomEvent('change'));
		await Promise.resolve();

		const badge = element.shadowRoot.querySelector('[data-testid="mode-badge"]');
		expect(badge.label).toBe('Live DML · Mocked callouts');
		expect(badge.className).toContain('slds-theme_warning');

		const safetyBar = element.shadowRoot.querySelector('[data-testid="safety-bar"]');
		expect(safetyBar.className).toContain('safety-bar_warning');
	});

	it('should render LIVE badge and danger styling when both toggles off', async() =>
	{
		const element = await createComponent();

		const safeModeToggle = element.shadowRoot.querySelector('[data-id="safeMode"]');
		safeModeToggle.checked = false;
		safeModeToggle.dispatchEvent(new CustomEvent('change'));
		await Promise.resolve();

		const badge = element.shadowRoot.querySelector('[data-testid="mode-badge"]');
		expect(badge.label).toBe('LIVE');
		expect(badge.className).toContain('slds-theme_error');

		const safetyBar = element.shadowRoot.querySelector('[data-testid="safety-bar"]');
		expect(safetyBar.className).toContain('safety-bar_danger');
		expect(safetyBar.className).toContain('slds-theme_alert-texture');
	});

	it('should render destructive variant execute button when safe mode is off', async() =>
	{
		const element = await createComponent();

		const executeButton = element.shadowRoot.querySelector('[data-id="execute"]');
		expect(executeButton.variant).toBe('brand');
		expect(executeButton.label).toBe('Execute');

		const safeModeToggle = element.shadowRoot.querySelector('[data-id="safeMode"]');
		safeModeToggle.checked = false;
		safeModeToggle.dispatchEvent(new CustomEvent('change'));
		await Promise.resolve();

		const updatedButton = element.shadowRoot.querySelector('[data-id="execute"]');
		expect(updatedButton.variant).toBe('destructive');
		expect(updatedButton.label).toBe('Execute (Live)');
	});

	it('should reset form state when reset button is clicked', async() =>
	{
		const element = await selectServiceAndExecute({isSuccess: true, executionTimeMs: 10});

		const addButton = element.shadowRoot.querySelector('[data-testid="add-parameter"]');
		addButton.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();
		expect(element.shadowRoot.querySelectorAll('.parameter-row').length).toBe(2);

		mockCallControllerMethod.mockResolvedValueOnce([{label: 'Test', value: 'API_Test'}]);
		const resetButton = element.shadowRoot.querySelector('[data-testid="harness-reset"]');
		resetButton.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();
		await Promise.resolve();

		const emptyState = element.shadowRoot.querySelector('[data-testid="empty-response"]');
		expect(emptyState).toBeTruthy();

		const rows = element.shadowRoot.querySelectorAll('.parameter-row');
		expect(rows.length).toBe(1);
	});

	it('should not render API Call Id as a link when Safe Mode was enabled', async() =>
	{
		const element = await selectServiceAndExecute({
			isSuccess: true, executionTimeMs: 10, apiCallId: 'a00000000000001', safeModeEnabled: true
		});

		const link = element.shadowRoot.querySelector('[data-testid="api-call-link"]');
		expect(link).toBeFalsy();
	});

	it('should render API Call Id as a link when Safe Mode was disabled', async() =>
	{
		const element = await selectServiceAndExecute({
			isSuccess: true, executionTimeMs: 10, apiCallId: 'a00000000000001', safeModeEnabled: false
		});

		const link = element.shadowRoot.querySelector('[data-testid="api-call-link"]');
		expect(link).toBeTruthy();
		expect(link.label).toBe('a00000000000001');
	});

	it('should navigate to the ApiCall__c record when the link is clicked', async() =>
	{
		const element = await selectServiceAndExecute({
			isSuccess: true, executionTimeMs: 10, apiCallId: 'a00000000000001', safeModeEnabled: false
		});

		const link = element.shadowRoot.querySelector('[data-testid="api-call-link"]');
		link.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();

		expect(mockNavigate).toHaveBeenCalledWith(expect.objectContaining({
			type: 'standard__recordPage', attributes: expect.objectContaining({
				recordId: 'a00000000000001', objectApiName: 'ApiCall__c', actionName: 'view'
			})
		}));
	});

	it('should apply error status class when statusCode is 4xx even if isSuccess is true', async() =>
	{
		const element = await selectServiceAndExecute({
			isSuccess: true, status: 'Completed', statusCode: 404, executionTimeMs: 10
		});

		const badge = element.shadowRoot.querySelector('[data-id="statusBadge"]');
		expect(badge).toBeTruthy();
		expect(badge.className).toContain('slds-theme_error');
	});

	it('should apply error status class when statusCode is 5xx', async() =>
	{
		const element = await selectServiceAndExecute({
			isSuccess: false, status: 'Failed', statusCode: 500, executionTimeMs: 10
		});

		const badge = element.shadowRoot.querySelector('[data-id="statusBadge"]');
		expect(badge).toBeTruthy();
		expect(badge.className).toContain('slds-theme_error');
	});

	it('should reset the copied icon back to the clipboard icon after the timeout fires', async() =>
	{
		jest.useFakeTimers();
		const mockWriteText = jest.fn().mockResolvedValue(undefined);
		Object.assign(navigator, {clipboard: {writeText: mockWriteText}});

		const element = await selectServiceAndExecute({
			isSuccess: true, executionTimeMs: 10, serviceName: 'API_Test', status: 'Completed'
		});

		const copyButton = element.shadowRoot.querySelector('[data-id="copySummary"]');
		copyButton.click();

		await Promise.resolve();
		await Promise.resolve();

		const afterCopy = element.shadowRoot.querySelector('[data-id="copySummary"]');
		expect(afterCopy.iconName).toBe('utility:check');

		jest.runAllTimers();
		jest.useRealTimers();
		await Promise.resolve();

		const afterTimeout = element.shadowRoot.querySelector('[data-id="copySummary"]');
		expect(afterTimeout.iconName).toBe('utility:copy_to_clipboard');
	});
});
