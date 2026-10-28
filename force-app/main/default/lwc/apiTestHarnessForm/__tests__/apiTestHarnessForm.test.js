// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for apiTestHarnessForm LWC component
 * @author Jason van Beukering
 * @date February 2026, October 2026
 */

import {createElement} from 'lwc';
import ApiTestHarnessForm from 'c/apiTestHarnessForm';
import {mockCallControllerMethod, mockNavigate, mockShowErrorToast, mockShowSuccessToast, mockShowWarningToast} from 'c/componentBuilder';
import getServices from '@salesforce/apex/CTRL_ApiTestHarness.getServices';
import describeService from '@salesforce/apex/CTRL_ApiTestHarness.describeService';
import invokeOutbound from '@salesforce/apex/CTRL_ApiTestHarness.invokeOutbound';
import invokeInbound from '@salesforce/apex/CTRL_ApiTestHarness.invokeInbound';

const EMPTY_DESCRIPTION = {inputs: [], requiresTriggeringRecord: false};
const DEFAULT_ROUTING = {services: [], description: EMPTY_DESCRIPTION, result: null, describeRejects: false};

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
jest.mock('@salesforce/apex/CTRL_ApiTestHarness.describeService', () => ({default: jest.fn()}), {virtual: true});
jest.mock('@salesforce/apex/CTRL_ApiTestHarness.invokeOutbound', () => ({default: jest.fn()}), {virtual: true});
jest.mock('@salesforce/apex/CTRL_ApiTestHarness.invokeInbound', () => ({default: jest.fn()}), {virtual: true});

jest.mock('c/jsonViewer', () =>
{
	const {LightningElement} = require('lwc');
	return {
		__esModule: true, default: class extends LightningElement
		{
		}
	};
}, {virtual: true});

// Restore the real English values for every bundle label (the default sfdx-lwc-jest stub resolves
// each to the bare string 'c.<Name>'), so value assertions stay byte-faithful to the shipped
// labels. The six summary templates keep their {0}-form so the real formatTemplateString
// interpolation is verified end-to-end.
jest.mock('@salesforce/label/c.ApiTestHarness_CardTitle', () => ({default: 'API Test Harness'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Direction_Outbound', () => ({default: 'Outbound'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Direction_Inbound', () => ({default: 'Inbound'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_ModeBadge_Live', () => ({default: 'LIVE'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_ModeBadge_LiveDmlMocked', () => ({default: 'Live DML · Mocked callouts'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_ModeBadge_FullSandbox', () => ({default: 'Full Sandbox'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_ModeBadge_SafeModeRealCallouts', () => ({default: 'Safe Mode · Real callouts'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_SafeMode', () => ({default: 'Safe Mode'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Execute', () => ({default: 'Execute'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_ExecuteLive', () => ({default: 'Execute (Live)'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Status_Unknown', () => ({default: 'Unknown'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Validation_BlankParameterKey', () => ({default: 'Parameter key cannot be blank when a value is provided.'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Validation_InvalidJson', () => ({default: 'JSON Body contains invalid JSON.'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Validation_RequiredParameterMissing', () => ({default: 'Fill in every required parameter before executing.'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Validation_RecordIdRequired', () => ({default: 'This service needs a triggering record ID.'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Validation_RecordIdInvalid', () => ({default: 'Enter a 15- or 18-character record ID.'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Toast_ExecutionSuccess', () => ({default: 'Execution completed successfully'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Toast_ExecutionAborted', () => ({default: 'Execution aborted'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Toast_ExecutionFailed', () => ({default: 'Execution failed'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Toast_SummaryCopied', () => ({default: 'Summary copied'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Toast_RequestHeadersCopied', () => ({default: 'Request headers copied'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Toast_ResponseHeadersCopied', () => ({default: 'Response headers copied'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Toast_RequestBodyCopied', () => ({default: 'Request body copied'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Toast_ResponseBodyCopied', () => ({default: 'Response body copied'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Toast_ErrorsCopied', () => ({default: 'Errors copied'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Toast_CopyFailed', () => ({default: 'Failed to copy to clipboard'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Summary_Service', () => ({default: 'Service: {0}'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Summary_Status', () => ({default: 'Status: {0} ({1})'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Summary_Timing', () => ({default: 'Total: {0} (Handler: {1}, Callout: {2}, Commit: {3})'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Summary_SafeMode', () => ({default: 'Safe Mode: {0}'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Summary_Mocked', () => ({default: 'Mocked: {0}'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Summary_ApiCallId', () => ({default: 'API Call ID: {0}'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Enabled', () => ({default: 'Enabled'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Disabled', () => ({default: 'Disabled'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Yes', () => ({default: 'Yes'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_No', () => ({default: 'No'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Direction', () => ({default: 'Direction'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Service', () => ({default: 'Service'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Service_ValueMissing', () => ({default: 'Select a service to execute'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Service_Placeholder', () => ({default: 'Select a service'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_RecordId', () => ({default: 'Record ID'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_RecordId_Optional', () => ({default: 'Record ID (optional)'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_RecordId_Placeholder', () => ({default: 'Enter triggering record ID'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Parameters', () => ({default: 'Parameters'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_RequiredMarker', () => ({default: 'Required'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Key', () => ({default: 'Key'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Value', () => ({default: 'Value'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Name', () => ({default: 'Name'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_AddParameter', () => ({default: 'Add parameter'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_JsonBody', () => ({default: 'JSON Body'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_JsonBody_Placeholder', () => ({default: 'Enter JSON request body'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_ExecutionSettings', () => ({default: 'Execution Settings'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_SafeMode_ToggleActive', () => ({default: 'DML rolled back'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_SafeMode_ToggleInactive', () => ({default: 'Live DML — changes will persist'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Mocking', () => ({default: 'Mocking'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Mocking_ToggleActive', () => ({default: 'Mock responses'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Mocking_ToggleInactive', () => ({default: 'Real endpoint responses'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Reset', () => ({default: 'Reset'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Mocked', () => ({default: 'Mocked'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_StatusCode', () => ({default: 'Status Code'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Total', () => ({default: 'Total'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Handler', () => ({default: 'Handler'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Callout', () => ({default: 'Callout'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Commit', () => ({default: 'Commit'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_ApiCallId', () => ({default: 'API Call ID'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Tab_Request', () => ({default: 'Request'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_RequestHeaders', () => ({default: 'Request Headers'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_RequestBody', () => ({default: 'Request Body'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Tab_Response', () => ({default: 'Response'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_ResponseHeaders', () => ({default: 'Response Headers'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_ResponseBody', () => ({default: 'Response Body'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_Tab_Errors', () => ({default: 'Errors'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_ErrorMessages', () => ({default: 'Error Messages'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_NoData', () => ({default: 'No request or response data available.'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_EmptyState_Heading', () => ({default: 'No response yet'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_EmptyState_Body', () => ({default: 'Configure the request on the left and click Execute.'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_AlternativeText_Executing', () => ({default: 'Executing'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_AlternativeText_RemoveParameter', () => ({default: 'Remove parameter'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_AlternativeText_ExecutionSettings', () => ({default: 'Execution settings'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_AlternativeText_CopySummary', () => ({default: 'Copy summary'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_AlternativeText_CopyRequestHeaders', () => ({default: 'Copy request headers'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_AlternativeText_CopyRequestBody', () => ({default: 'Copy request body'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_AlternativeText_CopyResponseHeaders', () => ({default: 'Copy response headers'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_AlternativeText_CopyResponseBody', () => ({default: 'Copy response body'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_AlternativeText_CopyErrors', () => ({default: 'Copy errors'}), {virtual: true});
jest.mock('@salesforce/label/c.ApiTestHarness_AlternativeText_NoResponse', () => ({default: 'No response'}), {virtual: true});

describe('c-api-test-harness-form', () =>
{
	let routing = {...DEFAULT_ROUTING};
	let isRoutingConfigured = false;

	/**
	 * Answers `callControllerMethod` by Apex method identity rather than by call order, so a test
	 * stays correct however many describe calls the component makes while a service is selected.
	 * A failed controller call is modelled as a resolved falsy value, never a rejection: the
	 * wired method routes rejections to `surfaceError` and resolves `undefined` unless asked to
	 * throw, so a rejection here would not reproduce what the component actually sees.
	 *
	 * `description` may be a function of the call parameters instead of a value, which is how a
	 * test hands back a promise it controls (to hold a describe open) or a different answer per
	 * service (to interleave two describes).
	 */
	function routeControllerCalls(options = {})
	{
		isRoutingConfigured = true;
		routing = {...DEFAULT_ROUTING, ...options};

		mockCallControllerMethod.mockImplementation((method, parameters) =>
		{
			if(method === getServices)
			{
				return Promise.resolve(routing.services);
			}
			if(method === describeService)
			{
				const description = typeof routing.description === 'function' ? routing.description(parameters) : routing.description;
				return Promise.resolve(routing.describeRejects ? null : description);
			}
			return Promise.resolve(routing.result);
		});
	}

	beforeEach(() =>
	{
		routeControllerCalls();
		isRoutingConfigured = false;
	});

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
		if(!isRoutingConfigured)
		{
			routeControllerCalls({services: [{label: 'Test', value: 'API_Test'}]});
		}

		const element = createElement('c-api-test-harness-form', {is: ApiTestHarnessForm});
		Object.assign(element, props);
		document.body.appendChild(element);
		await Promise.resolve();
		return element;
	}

	async function executeWithResult(element, result)
	{
		routing.result = result;

		const button = element.shadowRoot.querySelector('[data-id="execute"]');
		button.click();
		await Promise.resolve();
		await Promise.resolve();
	}

	async function selectService(element, value = 'API_Test')
	{
		element.shadowRoot.querySelector('lightning-combobox').dispatchEvent(new CustomEvent('change', {detail: {value}}));
		await Promise.resolve();
		await Promise.resolve();
	}

	async function selectServiceAndExecute(result)
	{
		const element = await createComponent();
		await Promise.resolve();

		await selectService(element);
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
		routeControllerCalls({services: [{label: 'Test', value: 'API_Test'}], result: {isSuccess: true, executionTimeMs: 100}});
		const element = await createComponent();
		await Promise.resolve();

		await selectService(element);

		const button = element.shadowRoot.querySelector('[data-id="execute"]');
		button.click();
		await Promise.resolve();
		await Promise.resolve();

		const request = extractRequest(invokeOutbound);
		expect(request.serviceName).toBe('API_Test');
	});

	it('should call invokeInbound on execute for inbound', async() =>
	{
		routeControllerCalls({services: [{label: 'Test', value: 'API_Test'}], result: {isSuccess: true, executionTimeMs: 50}});
		const element = await createComponent();

		const radioGroup = element.shadowRoot.querySelector('lightning-radio-group');
		radioGroup.dispatchEvent(new CustomEvent('change', {detail: {value: 'Inbound'}}));
		await Promise.resolve();

		await selectService(element, 'API_Echo');

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
		await selectServiceAndExecute({isSuccess: false, status: 'Aborted', executionTimeMs: 10, errorMessages: 'A valid triggering record Id is required.'});

		expect(mockShowWarningToast).toHaveBeenCalledWith('A valid triggering record Id is required.');
	});

	it('should remove spinner after execution completes', async() =>
	{
		const element = await selectServiceAndExecute({isSuccess: true, status: 'Completed', executionTimeMs: 10});

		const spinner = element.shadowRoot.querySelector('lightning-spinner');
		expect(spinner).toBeFalsy();
	});

	it('should remove spinner after execution returns undefined', async() =>
	{
		routeControllerCalls({services: [{label: 'Test', value: 'API_Test'}], result: undefined});
		const element = await createComponent();
		await Promise.resolve();

		await selectService(element);

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

		await selectService(element);
		await executeWithResult(element, {isSuccess: true, executionTimeMs: 5});

		const request = extractRequest(invokeOutbound);
		expect(request.recordId).toBe('001000000000001');
	});

	it('should update parameter key/value via the grid inputs', async() =>
	{
		const element = await createComponent();
		await selectService(element);

		const keyInput = element.shadowRoot.querySelector('[data-testid="parameter-key"]');
		const valueInput = element.shadowRoot.querySelector('[data-testid="parameter-value"]');

		keyInput.dispatchEvent(new CustomEvent('change', {detail: {value: 'key'}}));
		await Promise.resolve();
		valueInput.dispatchEvent(new CustomEvent('change', {detail: {value: 'value'}}));
		await Promise.resolve();

		await executeWithResult(element, {isSuccess: true, executionTimeMs: 5});

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

		await selectService(element, 'API_Echo');
		await executeWithResult(element, {isSuccess: true, executionTimeMs: 5});

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

		await selectService(element);
		await executeWithResult(element, {isSuccess: true, executionTimeMs: 5});

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

		await selectService(element);
		await executeWithResult(element, {isSuccess: true, executionTimeMs: 5});

		const request = extractRequest(invokeOutbound);
		expect(request.enableMocking).toBe(true);
	});

	it('should default serviceOptions to empty array when loadServices returns undefined', async() =>
	{
		routeControllerCalls({services: undefined});
		const element = await createComponent();
		await Promise.resolve();

		const combobox = element.shadowRoot.querySelector('lightning-combobox');
		expect(combobox.options).toEqual([]);
	});

	it('should clear the result without stacking a second error toast when execution resolves undefined', async() =>
	{
		// callControllerMethod resolves undefined after surfacing an Apex failure as an error
		// toast; a component-level toast on top of that stacks two error toasts for one failure.
		const element = await createComponent();
		await Promise.resolve();

		await selectService(element);

		await executeWithResult(element, {isSuccess: true, executionTimeMs: 10});
		expect(element.shadowRoot.querySelector('[data-id="statusBadge"]')).toBeTruthy();
		mockShowErrorToast.mockClear();
		mockShowSuccessToast.mockClear();

		await executeWithResult(element, undefined);
		await Promise.resolve();

		expect(mockShowErrorToast).not.toHaveBeenCalled();
		expect(mockShowSuccessToast).not.toHaveBeenCalled();
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

		const emptyMessage = element.shadowRoot.querySelector('.slds-align_absolute-center');
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
		const element = await createComponent();
		await Promise.resolve();

		await selectService(element);

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
		const element = await createComponent();
		await Promise.resolve();

		await selectService(element);

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

		await executeWithResult(element, {isSuccess: true, executionTimeMs: 5});

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

		await executeWithResult(element, {isSuccess: true, executionTimeMs: 5});

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
		const element = await createComponent();
		await Promise.resolve();

		await selectService(element);

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

		await executeWithResult(element, {isSuccess: true, executionTimeMs: 5});

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

	it('copies a summary with em dashes where the result named nothing', async() =>
	{
		const mockWriteText = jest.fn().mockResolvedValue(undefined);
		Object.assign(navigator, {clipboard: {writeText: mockWriteText}});

		const element = await selectServiceAndExecute({isSuccess: true, executionTimeMs: 10});

		element.shadowRoot.querySelector('[data-id="copySummary"]').click();
		await Promise.resolve();
		await Promise.resolve();

		const copied = mockWriteText.mock.calls[0][0];
		expect(copied).toContain('Service: \u2014');
		expect(copied).toContain('Status: Unknown (\u2014)');
		expect(copied).toContain('API Call ID: \u2014');
	});

	it('should skip validation for empty parameters', async() =>
	{
		const element = await createComponent();
		await Promise.resolve();

		await selectService(element);
		await executeWithResult(element, {isSuccess: true, executionTimeMs: 5});

		const request = extractRequest(invokeOutbound);
		expect(request.parameters).toEqual([]);
	});

	it('should skip validation for empty JSON body', async() =>
	{
		const element = await createComponent();

		const radioGroup = element.shadowRoot.querySelector('lightning-radio-group');
		radioGroup.dispatchEvent(new CustomEvent('change', {detail: {value: 'Inbound'}}));
		await Promise.resolve();

		await selectService(element, 'API_Echo');
		await executeWithResult(element, {isSuccess: true, executionTimeMs: 5});

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

	it('should read Safe Mode · Real callouts on the mode badge when only Safe Mode is on', async() =>
	{
		const element = await createComponent();

		const badge = element.shadowRoot.querySelector('[data-testid="mode-badge"]');
		expect(badge.label).toBe('Safe Mode · Real callouts');
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

	it('clears the timer that resets the copied icon when the form is removed before it fires', async() =>
	{
		jest.useFakeTimers();
		Object.assign(navigator, {clipboard: {writeText: jest.fn().mockResolvedValue(undefined)}});

		const element = await selectServiceAndExecute({
			isSuccess: true, executionTimeMs: 10, serviceName: 'API_Test', status: 'Completed'
		});

		element.shadowRoot.querySelector('[data-id="copySummary"]').click();
		await Promise.resolve();
		await Promise.resolve();
		expect(jest.getTimerCount()).toBe(1);

		document.body.removeChild(element);

		expect(jest.getTimerCount()).toBe(0);
		jest.useRealTimers();
	});

	it('keeps the services of the direction chosen last when the list for an earlier direction arrives after it', async() =>
	{
		const outboundServices = [{label: 'Outbound service', value: 'API_Outbound'}];
		const inboundServices = [{label: 'Inbound service', value: 'API_Inbound'}];
		const element = await createComponent();
		await Promise.resolve();

		const resolveServicesByDirection = new Map();
		mockCallControllerMethod.mockImplementation((method, parameters) =>
		{
			if(method === getServices)
			{
				return new Promise((resolve) =>
				{
					resolveServicesByDirection.set(parameters.direction, resolve);
				});
			}
			return Promise.resolve(null);
		});

		const radioGroup = element.shadowRoot.querySelector('lightning-radio-group');
		radioGroup.dispatchEvent(new CustomEvent('change', {detail: {value: 'Inbound'}}));
		radioGroup.dispatchEvent(new CustomEvent('change', {detail: {value: 'Outbound'}}));

		resolveServicesByDirection.get('Outbound')(outboundServices);
		await Promise.resolve();
		await Promise.resolve();
		resolveServicesByDirection.get('Inbound')(inboundServices);
		await Promise.resolve();
		await Promise.resolve();

		expect(element.shadowRoot.querySelector('[data-testid="harness-service"]').options).toEqual(outboundServices);
	});

	const PWND_DESCRIPTION = {inputs: [{name: 'password', isRequired: true}], requiresTriggeringRecord: false};
	const RECORD_DESCRIPTION = {inputs: [], requiresTriggeringRecord: true};
	const VALID_RECORD_ID = '001000000000001AAA';

	function findParameterRows(element)
	{
		return [...element.shadowRoot.querySelectorAll('.parameter-row')];
	}

	function findExecuteButton(element)
	{
		return element.shadowRoot.querySelector('[data-id="execute"]');
	}

	/** Drains the microtasks a held-open describe needs to settle, seed its rows and re-render. */
	async function settleDescribe()
	{
		await Promise.resolve();
		await Promise.resolve();
		await Promise.resolve();
		await Promise.resolve();
	}

	it('seeds one read-only required row per declared input plus one optional row', async() =>
	{
		routeControllerCalls({services: [{label: 'Pwnd', value: 'API_GetPwndPasswords'}], description: PWND_DESCRIPTION});
		const element = await createComponent();
		await selectService(element, 'API_GetPwndPasswords');

		const seeded = findParameterRows(element);
		expect(seeded).toHaveLength(2);

		const requiredKey = seeded[0].querySelector('[data-testid="parameter-key"]');
		expect(requiredKey.value).toBe('password');
		expect(requiredKey.readOnly).toBe(true);
		expect(seeded[0].querySelector('[data-testid="parameter-value"]').required).toBe(true);
		expect(seeded[0].querySelector('[data-testid="remove-parameter"]')).toBeNull();
		expect(seeded[0].querySelector('[data-testid="required-marker"]').textContent).toBe('Required');
		expect(seeded[1].querySelector('[data-testid="remove-parameter"]')).not.toBeNull();
	});

	it('asks the controller what the selected service declares', async() =>
	{
		routeControllerCalls({services: [{label: 'Pwnd', value: 'API_GetPwndPasswords'}], description: PWND_DESCRIPTION});
		const element = await createComponent();
		await selectService(element, 'API_GetPwndPasswords');

		expect(mockCallControllerMethod).toHaveBeenCalledWith(describeService, {className: 'API_GetPwndPasswords'}, {silent: true});
	});

	it('disables Execute until every required value is filled', async() =>
	{
		routeControllerCalls({services: [{label: 'Pwnd', value: 'API_GetPwndPasswords'}], description: PWND_DESCRIPTION});
		const element = await createComponent();
		await selectService(element, 'API_GetPwndPasswords');
		expect(findExecuteButton(element).disabled).toBe(true);

		const valueInput = findParameterRows(element)[0].querySelector('[data-testid="parameter-value"]');
		valueInput.dispatchEvent(new CustomEvent('change', {detail: {value: 'Password123'}}));
		await Promise.resolve();
		expect(findExecuteButton(element).disabled).toBe(false);
	});

	it('refuses to execute while a required parameter is blank', async() =>
	{
		routeControllerCalls({
			services: [{label: 'Pwnd', value: 'API_GetPwndPasswords'}], description: PWND_DESCRIPTION, result: {isSuccess: true, executionTimeMs: 5}
		});
		const element = await createComponent();
		await selectService(element, 'API_GetPwndPasswords');

		findExecuteButton(element).click();
		await Promise.resolve();

		expect(mockShowErrorToast).toHaveBeenCalledWith('Fill in every required parameter before executing.');
		expect(mockCallControllerMethod).not.toHaveBeenCalledWith(invokeOutbound, expect.anything());
	});

	it('labels the record id optional when the service does not require one', async() =>
	{
		routeControllerCalls({services: [{label: 'Pwnd', value: 'API_GetPwndPasswords'}], description: PWND_DESCRIPTION});
		const element = await createComponent();
		await selectService(element, 'API_GetPwndPasswords');

		const recordInput = element.shadowRoot.querySelector('[data-id="recordId"]');
		expect(recordInput.label).toBe('Record ID (optional)');
		expect(recordInput.required).toBe(false);
	});

	it('requires an id-shaped record id when the service declares one', async() =>
	{
		routeControllerCalls({services: [{label: 'Post', value: 'API_PostExample'}], description: RECORD_DESCRIPTION});
		const element = await createComponent();
		await selectService(element, 'API_PostExample');

		const recordInput = element.shadowRoot.querySelector('[data-id="recordId"]');
		expect(recordInput.label).toBe('Record ID');
		expect(recordInput.required).toBe(true);
		expect(findExecuteButton(element).disabled).toBe(true);

		recordInput.dispatchEvent(new CustomEvent('change', {detail: {value: 'not-an-id'}}));
		await Promise.resolve();
		expect(findExecuteButton(element).disabled).toBe(true);
		expect(element.shadowRoot.querySelector('[data-testid="gate-reason"]').textContent).toBe('Enter a 15- or 18-character record ID.');

		recordInput.dispatchEvent(new CustomEvent('change', {detail: {value: VALID_RECORD_ID}}));
		await Promise.resolve();
		expect(findExecuteButton(element).disabled).toBe(false);
	});

	it('names the missing record id as the reason Execute is disabled', async() =>
	{
		routeControllerCalls({services: [{label: 'Post', value: 'API_PostExample'}], description: RECORD_DESCRIPTION});
		const element = await createComponent();
		await selectService(element, 'API_PostExample');

		expect(element.shadowRoot.querySelector('[data-testid="gate-reason"]').textContent).toBe('This service needs a triggering record ID.');
	});

	it('explains why Execute is disabled and clears the reason once executable', async() =>
	{
		routeControllerCalls({services: [{label: 'Pwnd', value: 'API_GetPwndPasswords'}], description: PWND_DESCRIPTION});
		const element = await createComponent();
		await selectService(element, 'API_GetPwndPasswords');
		expect(element.shadowRoot.querySelector('[data-testid="gate-reason"]').textContent).toBe('Fill in every required parameter before executing.');

		findParameterRows(element)[0].querySelector('[data-testid="parameter-value"]').dispatchEvent(new CustomEvent('change', {detail: {value: 'Password123'}}));
		await Promise.resolve();
		expect(element.shadowRoot.querySelector('[data-testid="gate-reason"]').textContent).toBe('');
	});

	it('falls back to one optional row when describe fails', async() =>
	{
		routeControllerCalls({services: [{label: 'Test', value: 'API_Test'}], describeRejects: true});
		const element = await createComponent();
		await selectService(element);

		expect(findParameterRows(element)).toHaveLength(1);
		expect(findParameterRows(element)[0].querySelector('[data-testid="remove-parameter"]')).not.toBeNull();
		expect(element.shadowRoot.querySelector('[data-id="recordId"]').required).toBe(false);
		expect(findExecuteButton(element).disabled).toBe(false);
	});

	it('re-seeds from scratch on re-select and clears on reset', async() =>
	{
		routeControllerCalls({services: [{label: 'Pwnd', value: 'API_GetPwndPasswords'}], description: PWND_DESCRIPTION});
		const element = await createComponent();
		await selectService(element, 'API_GetPwndPasswords');
		element.shadowRoot.querySelector('[data-testid="add-parameter"]').click();
		await Promise.resolve();
		expect(findParameterRows(element)).toHaveLength(3);

		await selectService(element, 'API_GetPwndPasswords');
		expect(findParameterRows(element)).toHaveLength(2);

		element.shadowRoot.querySelector('[data-id="reset"]').click();
		await Promise.resolve();
		await Promise.resolve();
		expect(findParameterRows(element)).toHaveLength(1);
		expect(element.shadowRoot.querySelector('[data-id="recordId"]').required).toBe(false);
	});

	it('keeps one empty optional row when the last optional row is removed beside a required one', async() =>
	{
		routeControllerCalls({services: [{label: 'Pwnd', value: 'API_GetPwndPasswords'}], description: PWND_DESCRIPTION});
		const element = await createComponent();
		await selectService(element, 'API_GetPwndPasswords');

		const removeButtons = element.shadowRoot.querySelectorAll('[data-testid="remove-parameter"]');
		expect(removeButtons).toHaveLength(1);
		removeButtons[0].dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();

		const remaining = findParameterRows(element);
		expect(remaining).toHaveLength(2);
		expect(remaining[0].querySelector('[data-testid="parameter-key"]').value).toBe('password');
		expect(remaining[1].querySelector('[data-testid="parameter-key"]').value).toBe('');
	});

	it('sends a filled required row as a plain name/value pair', async() =>
	{
		routeControllerCalls({services: [{label: 'Pwnd', value: 'API_GetPwndPasswords'}], description: PWND_DESCRIPTION});
		const element = await createComponent();
		await selectService(element, 'API_GetPwndPasswords');

		findParameterRows(element)[0].querySelector('[data-testid="parameter-value"]').dispatchEvent(new CustomEvent('change', {detail: {value: 'Password123'}}));
		await Promise.resolve();

		await executeWithResult(element, {isSuccess: true, executionTimeMs: 5});

		expect(extractRequest(invokeOutbound).parameters).toEqual([{name: 'password', value: 'Password123'}]);
	});

	it('sends the record id trimmed of the whitespace the user pasted', async() =>
	{
		routeControllerCalls({services: [{label: 'Post', value: 'API_PostExample'}], description: RECORD_DESCRIPTION});
		const element = await createComponent();
		await selectService(element, 'API_PostExample');

		const recordInput = element.shadowRoot.querySelector('[data-id="recordId"]');
		recordInput.dispatchEvent(new CustomEvent('change', {detail: {value: `  ${VALID_RECORD_ID}  `}}));
		await Promise.resolve();
		expect(findExecuteButton(element).disabled).toBe(false);

		await executeWithResult(element, {isSuccess: true, executionTimeMs: 5});

		expect(extractRequest(invokeOutbound).recordId).toBe(VALID_RECORD_ID);
	});

	it('disables Execute while the service description is still loading', async() =>
	{
		let resolveDescribe;
		const pendingDescribe = new Promise((resolve) =>
		{
			resolveDescribe = resolve;
		});
		routeControllerCalls({services: [{label: 'Test', value: 'API_Test'}], description: () => pendingDescribe});
		const element = await createComponent();
		await selectService(element);

		expect(findExecuteButton(element).disabled).toBe(true);
		expect(element.shadowRoot.querySelector('[data-testid="gate-reason"]').textContent).toBe('');

		resolveDescribe(EMPTY_DESCRIPTION);
		await settleDescribe();

		expect(findExecuteButton(element).disabled).toBe(false);
	});

	it('ignores a describe that resolves after the user has picked another service', async() =>
	{
		let resolveFirstDescribe;
		const firstDescribe = new Promise((resolve) =>
		{
			resolveFirstDescribe = resolve;
		});
		routeControllerCalls({
			services: [
				{label: 'Pwnd', value: 'API_GetPwndPasswords'},
				{label: 'Post', value: 'API_PostExample'}
			], description: (parameters) => (parameters.className === 'API_GetPwndPasswords' ? firstDescribe : EMPTY_DESCRIPTION)
		});
		const element = await createComponent();

		await selectService(element, 'API_GetPwndPasswords');
		await selectService(element, 'API_PostExample');

		resolveFirstDescribe(PWND_DESCRIPTION);
		await settleDescribe();

		expect(findParameterRows(element)).toHaveLength(1);
		expect(element.shadowRoot.querySelector('[data-testid="required-marker"]')).toBeNull();
		expect(findExecuteButton(element).disabled).toBe(false);
	});

	it('applies one seeding when the same service is re-selected after a reset inside the describe window', async() =>
	{
		const describeResolvers = [];
		routeControllerCalls({
			services: [{label: 'Test', value: 'API_Test'}], description: () => new Promise((resolve) => describeResolvers.push(resolve))
		});
		const element = await createComponent();

		await selectService(element);

		element.shadowRoot.querySelector('[data-id="reset"]').click();
		await Promise.resolve();
		await Promise.resolve();

		await selectService(element);
		element.shadowRoot.querySelector('[data-testid="add-parameter"]').click();
		await Promise.resolve();
		expect(findParameterRows(element)).toHaveLength(2);

		describeResolvers[0](EMPTY_DESCRIPTION);
		await settleDescribe();

		expect(findParameterRows(element)).toHaveLength(2);
		expect(findExecuteButton(element).disabled).toBe(true);

		describeResolvers[1](EMPTY_DESCRIPTION);
		await settleDescribe();

		expect(findParameterRows(element)).toHaveLength(1);
		expect(findExecuteButton(element).disabled).toBe(false);
	});

	it('clears the seeded rows and the record requirement when the direction changes', async() =>
	{
		const bothDescription = {inputs: [{name: 'password', isRequired: true}], requiresTriggeringRecord: true};
		routeControllerCalls({services: [{label: 'Pwnd', value: 'API_GetPwndPasswords'}], description: bothDescription});
		const element = await createComponent();
		await selectService(element, 'API_GetPwndPasswords');
		expect(findParameterRows(element)).toHaveLength(2);
		expect(element.shadowRoot.querySelector('[data-id="recordId"]').required).toBe(true);

		const radioGroup = element.shadowRoot.querySelector('lightning-radio-group');
		radioGroup.dispatchEvent(new CustomEvent('change', {detail: {value: 'Inbound'}}));
		await Promise.resolve();
		await Promise.resolve();
		radioGroup.dispatchEvent(new CustomEvent('change', {detail: {value: 'Outbound'}}));
		await Promise.resolve();
		await Promise.resolve();

		expect(findParameterRows(element)).toHaveLength(1);
		expect(element.shadowRoot.querySelector('[data-id="recordId"]').required).toBe(false);
	});

	it('renders inside a lightning-card shell with the harness title', async() =>
	{
		const element = await createComponent();
		const card = element.shadowRoot.querySelector('lightning-card');
		expect(card).not.toBeNull();
		expect(card.title).toBe('API Test Harness');
		expect(card.querySelector('[data-testid="api-test-harness-root"]')).not.toBeNull();
	});

	it('gives the empty state a status role inside the shell', async() =>
	{
		const element = await createComponent();
		expect(element.shadowRoot.querySelector('[data-testid="empty-response"]').getAttribute('role')).toBe('status');
	});

	it('collapses the gate reason line while it has nothing to say', async() =>
	{
		const element = await createComponent();
		const gateReason = element.shadowRoot.querySelector('[data-testid="gate-reason"]');
		expect(gateReason.textContent).toBe('');
		expect(gateReason.classList.contains('gate-reason')).toBe(true);
	});

	it('accents an aborted result and not a completed one', async() =>
	{
		const abortedElement = await selectServiceAndExecute({isSuccess: false, status: 'Aborted', executionTimeMs: 10, errorMessages: 'x'});
		expect(abortedElement.shadowRoot.querySelector('[data-testid="result-card"]').classList.contains('result-card_warning')).toBe(true);

		const completedElement = await selectServiceAndExecute({isSuccess: true, statusCode: 200, status: 'Completed', executionTimeMs: 10});
		expect(completedElement.shadowRoot.querySelector('[data-testid="result-card"]').classList.contains('result-card_warning')).toBe(false);
		expect(completedElement.shadowRoot.querySelector('[data-testid="result-card"]').classList.contains('result-card_error')).toBe(false);
	});

	it('accents a failed result whether the failure carries a status code or not', async() =>
	{
		const failedElement = await selectServiceAndExecute({isSuccess: false, status: 'Failed', executionTimeMs: 10, errorMessages: 'boom'});
		expect(failedElement.shadowRoot.querySelector('[data-testid="result-card"]').classList.contains('result-card_error')).toBe(true);

		const serverErrorElement = await selectServiceAndExecute({isSuccess: true, statusCode: 503, status: 'Completed', executionTimeMs: 10});
		expect(serverErrorElement.shadowRoot.querySelector('[data-testid="result-card"]').classList.contains('result-card_error')).toBe(true);
	});

	it('takes the screen-reader text of the always-rendered icons from Custom Labels', async() =>
	{
		const element = await createComponent();

		expect(element.shadowRoot.querySelector('[data-testid="empty-response"] lightning-icon').alternativeText).toBe('No response');
		expect(element.shadowRoot.querySelector('[data-testid="safety-bar"] lightning-icon').alternativeText).toBe('Execution settings');
		expect(element.shadowRoot.querySelector('[data-testid="remove-parameter"]').alternativeText).toBe('Remove parameter');
	});

	it('takes the screen-reader text of the result copy buttons from Custom Labels', async() =>
	{
		const element = await selectServiceAndExecute({
			isSuccess: true,
			statusCode: 200,
			status: 'Completed',
			executionTimeMs: 10,
			requestBody: '{"a":1}',
			responseBody: '{"b":2}',
			requestHeaders: '{"Accept":"application/json"}',
			responseHeaders: '{"X-Request-Id":"abc123"}',
			errorMessages: 'boom'
		});

		expect(element.shadowRoot.querySelector('[data-id="copySummary"]').alternativeText).toBe('Copy summary');
		expect(element.shadowRoot.querySelector('[data-id="copyRequestHeaders"]').alternativeText).toBe('Copy request headers');
		expect(element.shadowRoot.querySelector('[data-id="copyRequestBody"]').alternativeText).toBe('Copy request body');
		expect(element.shadowRoot.querySelector('[data-id="copyResponseHeaders"]').alternativeText).toBe('Copy response headers');
		expect(element.shadowRoot.querySelector('[data-id="copyResponseBody"]').alternativeText).toBe('Copy response body');
		expect(element.shadowRoot.querySelector('[data-id="copyErrors"]').alternativeText).toBe('Copy errors');
	});

	it('reads a completed success as success on the badge and no accent on the card', async() =>
	{
		const element = await selectServiceAndExecute({isSuccess: true, statusCode: 200, status: 'Completed', executionTimeMs: 10});

		expect(element.shadowRoot.querySelector('[data-id="statusBadge"]').className).toBe('slds-theme_success');
		expect(element.shadowRoot.querySelector('[data-testid="result-card"]').className).toBe('slds-box result-card');
	});

	it('reads a success without a status code as success on the badge and no accent on the card', async() =>
	{
		const element = await selectServiceAndExecute({isSuccess: true, status: 'Completed', executionTimeMs: 10});

		expect(element.shadowRoot.querySelector('[data-id="statusBadge"]').className).toBe('slds-theme_success');
		expect(element.shadowRoot.querySelector('[data-testid="result-card"]').className).toBe('slds-box result-card');
	});

	it('reads a 4xx as error on both the badge and the card even when the result claims success', async() =>
	{
		const element = await selectServiceAndExecute({isSuccess: true, statusCode: 404, status: 'Completed', executionTimeMs: 10});

		expect(element.shadowRoot.querySelector('[data-id="statusBadge"]').className).toBe('slds-theme_error');
		expect(element.shadowRoot.querySelector('[data-testid="result-card"]').className).toBe('slds-box result-card result-card_error');
	});

	it('reads a 5xx as error on both the badge and the card', async() =>
	{
		const element = await selectServiceAndExecute({isSuccess: false, statusCode: 500, status: 'Failed', executionTimeMs: 10, errorMessages: 'boom'});

		expect(element.shadowRoot.querySelector('[data-id="statusBadge"]').className).toBe('slds-theme_error');
		expect(element.shadowRoot.querySelector('[data-testid="result-card"]').className).toBe('slds-box result-card result-card_error');
	});

	it('reads a failure without a status code as error on both the badge and the card', async() =>
	{
		const element = await selectServiceAndExecute({isSuccess: false, status: 'Failed', executionTimeMs: 10, errorMessages: 'boom'});

		expect(element.shadowRoot.querySelector('[data-id="statusBadge"]').className).toBe('slds-theme_error');
		expect(element.shadowRoot.querySelector('[data-testid="result-card"]').className).toBe('slds-box result-card result-card_error');
	});

	it('reads an aborted run as warning on both the badge and the card', async() =>
	{
		const element = await selectServiceAndExecute({isSuccess: false, status: 'Aborted', executionTimeMs: 10, errorMessages: 'x'});

		expect(element.shadowRoot.querySelector('[data-id="statusBadge"]').className).toBe('slds-theme_warning');
		expect(element.shadowRoot.querySelector('[data-testid="result-card"]').className).toBe('slds-box result-card result-card_warning');
	});

	it('scrolls header tables inside a wrapper instead of turning the table into a block', async() =>
	{
		const element = await selectServiceAndExecute({
			isSuccess: true, statusCode: 200, status: 'Completed', executionTimeMs: 10, requestHeaders: JSON.stringify({Accept: 'application/json'})
		});
		const table = element.shadowRoot.querySelector('.table-scroll table.slds-table');
		expect(table).not.toBeNull();
	});
});
