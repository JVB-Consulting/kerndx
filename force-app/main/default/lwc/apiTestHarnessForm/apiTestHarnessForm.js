// SPDX-License-Identifier: BUSL-1.1
/**
 * @description API Test Harness form component for testing inbound and outbound API calls
 * with Safe Mode and Mocking control. Renders as a full-page two-column layout on the
 * ApiTestHarness FlexiPage tab: configuration on the left, response preview on the right.
 *
 * @author Jason van Beukering
 *
 * @date February 2026, July 2026
 */
import {ComponentBuilder} from 'c/componentBuilder';
import {formatTemplateString} from 'c/utilityString';
import getServices from '@salesforce/apex/CTRL_ApiTestHarness.getServices';
import invokeOutbound from '@salesforce/apex/CTRL_ApiTestHarness.invokeOutbound';
import invokeInbound from '@salesforce/apex/CTRL_ApiTestHarness.invokeInbound';

import DIRECTION_OUTBOUND from '@salesforce/label/c.ApiTestHarness_Direction_Outbound';
import DIRECTION_INBOUND from '@salesforce/label/c.ApiTestHarness_Direction_Inbound';
import MODE_BADGE_LIVE from '@salesforce/label/c.ApiTestHarness_ModeBadge_Live';
import MODE_BADGE_LIVE_DML_MOCKED from '@salesforce/label/c.ApiTestHarness_ModeBadge_LiveDmlMocked';
import MODE_BADGE_FULL_SANDBOX from '@salesforce/label/c.ApiTestHarness_ModeBadge_FullSandbox';
import SAFE_MODE from '@salesforce/label/c.ApiTestHarness_SafeMode';
import EXECUTE from '@salesforce/label/c.ApiTestHarness_Execute';
import EXECUTE_LIVE from '@salesforce/label/c.ApiTestHarness_ExecuteLive';
import STATUS_UNKNOWN from '@salesforce/label/c.ApiTestHarness_Status_Unknown';
import VALIDATION_BLANK_PARAMETER_KEY from '@salesforce/label/c.ApiTestHarness_Validation_BlankParameterKey';
import VALIDATION_INVALID_JSON from '@salesforce/label/c.ApiTestHarness_Validation_InvalidJson';
import TOAST_EXECUTION_SUCCESS from '@salesforce/label/c.ApiTestHarness_Toast_ExecutionSuccess';
import TOAST_EXECUTION_ABORTED from '@salesforce/label/c.ApiTestHarness_Toast_ExecutionAborted';
import TOAST_EXECUTION_FAILED from '@salesforce/label/c.ApiTestHarness_Toast_ExecutionFailed';
import TOAST_SUMMARY_COPIED from '@salesforce/label/c.ApiTestHarness_Toast_SummaryCopied';
import TOAST_REQUEST_HEADERS_COPIED from '@salesforce/label/c.ApiTestHarness_Toast_RequestHeadersCopied';
import TOAST_RESPONSE_HEADERS_COPIED from '@salesforce/label/c.ApiTestHarness_Toast_ResponseHeadersCopied';
import TOAST_REQUEST_BODY_COPIED from '@salesforce/label/c.ApiTestHarness_Toast_RequestBodyCopied';
import TOAST_RESPONSE_BODY_COPIED from '@salesforce/label/c.ApiTestHarness_Toast_ResponseBodyCopied';
import TOAST_ERRORS_COPIED from '@salesforce/label/c.ApiTestHarness_Toast_ErrorsCopied';
import TOAST_COPY_FAILED from '@salesforce/label/c.ApiTestHarness_Toast_CopyFailed';
import SUMMARY_SERVICE from '@salesforce/label/c.ApiTestHarness_Summary_Service';
import SUMMARY_STATUS from '@salesforce/label/c.ApiTestHarness_Summary_Status';
import SUMMARY_TIMING from '@salesforce/label/c.ApiTestHarness_Summary_Timing';
import SUMMARY_SAFE_MODE from '@salesforce/label/c.ApiTestHarness_Summary_SafeMode';
import SUMMARY_MOCKED from '@salesforce/label/c.ApiTestHarness_Summary_Mocked';
import SUMMARY_API_CALL_ID from '@salesforce/label/c.ApiTestHarness_Summary_ApiCallId';
import ENABLED from '@salesforce/label/c.ApiTestHarness_Enabled';
import DISABLED from '@salesforce/label/c.ApiTestHarness_Disabled';
import YES from '@salesforce/label/c.ApiTestHarness_Yes';
import NO from '@salesforce/label/c.ApiTestHarness_No';
import DIRECTION from '@salesforce/label/c.ApiTestHarness_Direction';
import SERVICE from '@salesforce/label/c.ApiTestHarness_Service';
import SERVICE_VALUE_MISSING from '@salesforce/label/c.ApiTestHarness_Service_ValueMissing';
import SERVICE_PLACEHOLDER from '@salesforce/label/c.ApiTestHarness_Service_Placeholder';
import RECORD_ID from '@salesforce/label/c.ApiTestHarness_RecordId';
import RECORD_ID_PLACEHOLDER from '@salesforce/label/c.ApiTestHarness_RecordId_Placeholder';
import PARAMETERS from '@salesforce/label/c.ApiTestHarness_Parameters';
import KEY from '@salesforce/label/c.ApiTestHarness_Key';
import VALUE from '@salesforce/label/c.ApiTestHarness_Value';
import NAME from '@salesforce/label/c.ApiTestHarness_Name';
import ADD_PARAMETER from '@salesforce/label/c.ApiTestHarness_AddParameter';
import JSON_BODY from '@salesforce/label/c.ApiTestHarness_JsonBody';
import JSON_BODY_PLACEHOLDER from '@salesforce/label/c.ApiTestHarness_JsonBody_Placeholder';
import EXECUTION_SETTINGS from '@salesforce/label/c.ApiTestHarness_ExecutionSettings';
import SAFE_MODE_TOGGLE_ACTIVE from '@salesforce/label/c.ApiTestHarness_SafeMode_ToggleActive';
import SAFE_MODE_TOGGLE_INACTIVE from '@salesforce/label/c.ApiTestHarness_SafeMode_ToggleInactive';
import MOCKING from '@salesforce/label/c.ApiTestHarness_Mocking';
import MOCKING_TOGGLE_ACTIVE from '@salesforce/label/c.ApiTestHarness_Mocking_ToggleActive';
import MOCKING_TOGGLE_INACTIVE from '@salesforce/label/c.ApiTestHarness_Mocking_ToggleInactive';
import RESET from '@salesforce/label/c.ApiTestHarness_Reset';
import MOCKED from '@salesforce/label/c.ApiTestHarness_Mocked';
import STATUS_CODE from '@salesforce/label/c.ApiTestHarness_StatusCode';
import TOTAL from '@salesforce/label/c.ApiTestHarness_Total';
import HANDLER from '@salesforce/label/c.ApiTestHarness_Handler';
import CALLOUT from '@salesforce/label/c.ApiTestHarness_Callout';
import COMMIT from '@salesforce/label/c.ApiTestHarness_Commit';
import API_CALL_ID from '@salesforce/label/c.ApiTestHarness_ApiCallId';
import TAB_REQUEST from '@salesforce/label/c.ApiTestHarness_Tab_Request';
import REQUEST_HEADERS from '@salesforce/label/c.ApiTestHarness_RequestHeaders';
import REQUEST_BODY from '@salesforce/label/c.ApiTestHarness_RequestBody';
import TAB_RESPONSE from '@salesforce/label/c.ApiTestHarness_Tab_Response';
import RESPONSE_HEADERS from '@salesforce/label/c.ApiTestHarness_ResponseHeaders';
import RESPONSE_BODY from '@salesforce/label/c.ApiTestHarness_ResponseBody';
import TAB_ERRORS from '@salesforce/label/c.ApiTestHarness_Tab_Errors';
import ERROR_MESSAGES from '@salesforce/label/c.ApiTestHarness_ErrorMessages';
import NO_DATA from '@salesforce/label/c.ApiTestHarness_NoData';
import EMPTY_STATE_HEADING from '@salesforce/label/c.ApiTestHarness_EmptyState_Heading';
import EMPTY_STATE_BODY from '@salesforce/label/c.ApiTestHarness_EmptyState_Body';

const COPY_RESET_DELAY = 1500;

export default class ApiTestHarnessForm extends ComponentBuilder('controller', 'notification', 'navigation')
{
	direction = 'Outbound';
	selectedService = '';
	serviceOptions = [];
	recordId = '';
	parameterRows = [{id: 'row-0', key: '', value: ''}];
	jsonBody = '';
	safeModeEnabled = true;
	mockingEnabled = false;
	result = null;
	resultKey = 0;
	copiedButtonId = null;

	_nextRowId = 1;

	/** @description Template-bound Custom Labels for the harness form and result panel. */
	labels = {
		direction: DIRECTION,
		service: SERVICE,
		serviceValueMissing: SERVICE_VALUE_MISSING,
		servicePlaceholder: SERVICE_PLACEHOLDER,
		recordId: RECORD_ID,
		recordIdPlaceholder: RECORD_ID_PLACEHOLDER,
		parameters: PARAMETERS,
		key: KEY,
		value: VALUE,
		name: NAME,
		addParameter: ADD_PARAMETER,
		jsonBody: JSON_BODY,
		jsonBodyPlaceholder: JSON_BODY_PLACEHOLDER,
		executionSettings: EXECUTION_SETTINGS,
		safeMode: SAFE_MODE,
		safeModeToggleActive: SAFE_MODE_TOGGLE_ACTIVE,
		safeModeToggleInactive: SAFE_MODE_TOGGLE_INACTIVE,
		mocking: MOCKING,
		mockingToggleActive: MOCKING_TOGGLE_ACTIVE,
		mockingToggleInactive: MOCKING_TOGGLE_INACTIVE,
		reset: RESET,
		mocked: MOCKED,
		statusCode: STATUS_CODE,
		total: TOTAL,
		handler: HANDLER,
		callout: CALLOUT,
		commit: COMMIT,
		apiCallId: API_CALL_ID,
		tabRequest: TAB_REQUEST,
		requestHeaders: REQUEST_HEADERS,
		requestBody: REQUEST_BODY,
		tabResponse: TAB_RESPONSE,
		responseHeaders: RESPONSE_HEADERS,
		responseBody: RESPONSE_BODY,
		tabErrors: TAB_ERRORS,
		errorMessages: ERROR_MESSAGES,
		noData: NO_DATA,
		emptyStateHeading: EMPTY_STATE_HEADING,
		emptyStateBody: EMPTY_STATE_BODY
	};

	directionOptions = [
		{label: DIRECTION_OUTBOUND, value: 'Outbound'},
		{label: DIRECTION_INBOUND, value: 'Inbound'}
	];

	get isOutbound()
	{
		return this.direction === 'Outbound';
	}

	get isInbound()
	{
		return this.direction === 'Inbound';
	}

	get hasResult()
	{
		return this.result !== null;
	}

	/**
	 * @description Returns parameter rows trimmed, filtered to non-blank keys, and
	 * mapped to the DTO_NameValue shape for Apex serialization.
	 */
	get parametersForApex()
	{
		return this.parameterRows
		.filter((row) => row.key && row.key.trim() !== '')
		.map((row) => ({name: row.key.trim(), value: (row.value || '').trim()}));
	}

	get safetyBarClass()
	{
		if(!this.safeModeEnabled && !this.mockingEnabled)
		{
			return 'safety-bar safety-bar_danger slds-theme_alert-texture';
		}
		if(!this.safeModeEnabled)
		{
			return 'safety-bar safety-bar_warning';
		}
		if(this.mockingEnabled)
		{
			return 'safety-bar safety-bar_sandbox';
		}
		return 'safety-bar';
	}

	get modeBadgeLabel()
	{
		if(!this.safeModeEnabled && !this.mockingEnabled)
		{
			return MODE_BADGE_LIVE;
		}
		if(!this.safeModeEnabled)
		{
			return MODE_BADGE_LIVE_DML_MOCKED;
		}
		if(this.mockingEnabled)
		{
			return MODE_BADGE_FULL_SANDBOX;
		}
		return SAFE_MODE;
	}

	get modeBadgeClass()
	{
		if(!this.safeModeEnabled && !this.mockingEnabled)
		{
			return 'slds-theme_error';
		}
		if(!this.safeModeEnabled)
		{
			return 'slds-theme_warning';
		}
		if(this.mockingEnabled)
		{
			return 'slds-theme_success';
		}
		return 'slds-theme_info';
	}

	get executeVariant()
	{
		return this.safeModeEnabled ? 'brand' : 'destructive';
	}

	get executeLabel()
	{
		return this.safeModeEnabled ? EXECUTE : EXECUTE_LIVE;
	}

	get executeIcon()
	{
		return this.safeModeEnabled ? null : 'utility:warning';
	}

	get hasErrors()
	{
		return this.result?.errorMessages != null && this.result.errorMessages !== '';
	}

	get hasRequestBody()
	{
		return this.result?.requestBody != null && this.result.requestBody !== '';
	}

	get hasResponseBody()
	{
		return this.result?.responseBody != null && this.result.responseBody !== '';
	}

	get hasRequestHeaders()
	{
		return this.parsedRequestHeaders.length > 0;
	}

	get hasResponseHeaders()
	{
		return this.parsedResponseHeaders.length > 0;
	}

	get hasRequestContent()
	{
		return this.hasRequestHeaders || this.hasRequestBody;
	}

	get hasResponseContent()
	{
		return this.hasResponseHeaders || this.hasResponseBody;
	}

	get hasTabContent()
	{
		return this.hasRequestContent || this.hasResponseContent || this.hasErrors;
	}

	get isExecuteDisabled()
	{
		return !this.selectedService || this.isLoading;
	}

	get statusCodeDisplay()
	{
		return this.result?.statusCode ?? '\u2014';
	}

	get apiCallIdDisplay()
	{
		return this.result?.apiCallId || '\u2014';
	}

	/**
	 * @description True when the current result has a persistent ApiCall__c record
	 * (Safe Mode was off so the record wasn't rolled back).
	 */
	get hasApiCallLink()
	{
		return Boolean(this.result?.apiCallId) && this.result.safeModeEnabled === false;
	}

	get resultStatusLabel()
	{
		return this.result?.status || STATUS_UNKNOWN;
	}

	get isAborted()
	{
		return this.result?.status === 'Aborted';
	}

	get resultStatusClass()
	{
		const statusCode = this.result?.statusCode;
		if(statusCode != null && statusCode >= 400)
		{
			return 'slds-theme_error';
		}
		if(this.result?.isSuccess)
		{
			return 'slds-theme_success';
		}
		return this.isAborted ? 'slds-theme_warning' : 'slds-theme_error';
	}

	get executionTimeDisplay()
	{
		return this.formatDuration(this.result?.executionTimeMs);
	}

	get handlerTimeDisplay()
	{
		return this.formatDuration(this.result?.handlerDurationMs);
	}

	get calloutTimeDisplay()
	{
		return this.formatDuration(this.result?.calloutDurationMs);
	}

	get commitTimeDisplay()
	{
		return this.formatDuration(this.result?.commitDurationMs);
	}

	get summaryText()
	{
		const total = this.formatDuration(this.result?.executionTimeMs);
		const handler = this.formatDuration(this.result?.handlerDurationMs);
		const callout = this.formatDuration(this.result?.calloutDurationMs);
		const commit = this.formatDuration(this.result?.commitDurationMs);
		const lines = [
			formatTemplateString(SUMMARY_SERVICE, [this.result?.serviceName || '\u2014']),
			formatTemplateString(SUMMARY_STATUS, [
				this.result?.status || STATUS_UNKNOWN,
				this.result?.statusCode ?? '\u2014'
			]),
			formatTemplateString(SUMMARY_TIMING, [
				total,
				handler,
				callout,
				commit
			]),
			formatTemplateString(SUMMARY_SAFE_MODE, [this.result?.safeModeEnabled ? ENABLED : DISABLED]),
			formatTemplateString(SUMMARY_MOCKED, [this.result?.isMockedResponse ? YES : NO]),
			formatTemplateString(SUMMARY_API_CALL_ID, [this.result?.apiCallId || '\u2014'])
		];
		return lines.join('\n');
	}

	get parsedRequestHeaders()
	{
		return this.parseHeaders(this.result?.requestHeaders);
	}

	get parsedResponseHeaders()
	{
		return this.parseHeaders(this.result?.responseHeaders);
	}

	get requestHeadersCopyText()
	{
		return this.formatHeadersForCopy(this.parsedRequestHeaders);
	}

	get responseHeadersCopyText()
	{
		return this.formatHeadersForCopy(this.parsedResponseHeaders);
	}

	get copyIcons()
	{
		const base = 'utility:copy_to_clipboard';
		const check = 'utility:check';
		const id = this.copiedButtonId;
		return {
			summary: id === 'summary' ? check : base,
			requestHeaders: id === 'requestHeaders' ? check : base,
			responseHeaders: id === 'responseHeaders' ? check : base,
			requestBody: id === 'requestBody' ? check : base,
			responseBody: id === 'responseBody' ? check : base,
			errors: id === 'errors' ? check : base
		};
	}

	/**
	 * @description Builds the DTO_Request payload that the Apex controller deserialises
	 * inside `invokeOutbound`/`invokeInbound`. Keeps the JSON shape in one place.
	 */
	buildRequestPayload()
	{
		return {
			serviceName: this.selectedService,
			recordId: this.recordId,
			parameters: this.parametersForApex,
			jsonBody: this.jsonBody,
			enableSafeMode: this.safeModeEnabled,
			enableMocking: this.mockingEnabled
		};
	}

	handleOpenApiCall(event)
	{
		event.preventDefault();
		this.navigate({
			type: 'standard__recordPage', attributes: {
				recordId: this.result.apiCallId, objectApiName: 'ApiCall__c', actionName: 'view'
			}
		});
	}

	async connectedCallback()
	{
		await this.loadServices();
	}

	async handleDirectionChange(event)
	{
		this.direction = event.detail.value;
		this.selectedService = '';
		this.result = null;
		await this.loadServices();
	}

	handleServiceChange(event)
	{
		this.selectedService = event.detail.value;
	}

	handleRecordIdChange(event)
	{
		this.recordId = event.detail.value;
	}

	handleParameterKeyChange(event)
	{
		const rowId = event.currentTarget.dataset.rowId;
		this.parameterRows = this.parameterRows.map((row) => (row.id === rowId ? {...row, key: event.detail.value} : row));
	}

	handleParameterValueChange(event)
	{
		const rowId = event.currentTarget.dataset.rowId;
		this.parameterRows = this.parameterRows.map((row) => (row.id === rowId ? {...row, value: event.detail.value} : row));
	}

	handleAddParameterRow()
	{
		const id = `row-${this._nextRowId}`;
		this._nextRowId += 1;
		this.parameterRows = [
			...this.parameterRows,
			{id, key: '', value: ''}
		];
	}

	handleRemoveParameterRow(event)
	{
		const rowId = event.currentTarget.dataset.rowId;
		const remaining = this.parameterRows.filter((row) => row.id !== rowId);

		if(remaining.length === 0)
		{
			const replacementId = `row-${this._nextRowId}`;
			this._nextRowId += 1;
			this.parameterRows = [{id: replacementId, key: '', value: ''}];
			return;
		}

		this.parameterRows = remaining;
	}

	handleJsonBodyChange(event)
	{
		this.jsonBody = event.detail.value;
	}

	handleSafeModeChange(event)
	{
		this.safeModeEnabled = event.target.checked;
	}

	handleMockingChange(event)
	{
		this.mockingEnabled = event.target.checked;
	}

	handleReset()
	{
		this.direction = 'Outbound';
		this.selectedService = '';
		this.recordId = '';
		this.jsonBody = '';
		this.safeModeEnabled = true;
		this.mockingEnabled = false;
		this.result = null;
		this.resultKey = 0;
		this.copiedButtonId = null;
		this._nextRowId = 1;
		this.parameterRows = [{id: 'row-0', key: '', value: ''}];
		this.loadServices();
	}

	async loadServices()
	{
		this.serviceOptions = await this.callControllerMethod(getServices, {direction: this.direction}) || [];
	}

	validateInputs()
	{
		if(this.isOutbound)
		{
			const hasBlankKeyWithValue = this.parameterRows.some((row) => (!row.key || !row.key.trim()) && row.value && row.value.trim() !== '');
			if(hasBlankKeyWithValue)
			{
				return VALIDATION_BLANK_PARAMETER_KEY;
			}
		}

		if(this.isInbound && this.jsonBody)
		{
			try
			{
				JSON.parse(this.jsonBody);
			}
			catch
			{
				return VALIDATION_INVALID_JSON;
			}
		}

		return null;
	}

	async handleExecute()
	{
		const validationError = this.validateInputs();

		if(validationError)
		{
			this.showErrorToast(validationError);
			return;
		}

		this.isLoading = true;

		try
		{
			let executionResult;

			const requestJson = JSON.stringify(this.buildRequestPayload());

			if(this.isOutbound)
			{
				executionResult = await this.callControllerMethod(invokeOutbound, {requestJson});
			}
			else
			{
				executionResult = await this.callControllerMethod(invokeInbound, {requestJson});
			}

			if(!executionResult)
			{
				// callControllerMethod resolves undefined after surfacing the Apex failure as an
				// error toast; toasting here again would stack a second error toast on the same failure.
				this.result = null;
				return;
			}

			this.result = executionResult;
			this.resultKey++;

			if(executionResult.isSuccess)
			{
				this.showSuccessToast(TOAST_EXECUTION_SUCCESS);
			}
			else if(executionResult.status === 'Aborted')
			{
				this.showWarningToast(executionResult.errorMessages || TOAST_EXECUTION_ABORTED);
			}
			else
			{
				this.showErrorToast(executionResult.errorMessages || TOAST_EXECUTION_FAILED);
			}
		}
		finally
		{
			this.isLoading = false;
		}
	}

	async handleCopySummary()
	{
		await this.copyToClipboard(this.summaryText, TOAST_SUMMARY_COPIED, 'summary');
	}

	async handleCopyRequestHeaders()
	{
		await this.copyToClipboard(this.requestHeadersCopyText, TOAST_REQUEST_HEADERS_COPIED, 'requestHeaders');
	}

	async handleCopyResponseHeaders()
	{
		await this.copyToClipboard(this.responseHeadersCopyText, TOAST_RESPONSE_HEADERS_COPIED, 'responseHeaders');
	}

	async handleCopyRequestBody()
	{
		await this.copyToClipboard(this.result?.requestBody, TOAST_REQUEST_BODY_COPIED, 'requestBody');
	}

	async handleCopyResponseBody()
	{
		await this.copyToClipboard(this.result?.responseBody, TOAST_RESPONSE_BODY_COPIED, 'responseBody');
	}

	async handleCopyErrors()
	{
		await this.copyToClipboard(this.result?.errorMessages, TOAST_ERRORS_COPIED, 'errors');
	}

	parseHeaders(headerJson)
	{
		if(!headerJson)
		{
			return [];
		}

		try
		{
			let parsed = JSON.parse(headerJson);

			if(parsed.nameValueMap)
			{
				parsed = parsed.nameValueMap;
			}

			return Object.entries(parsed)
			.filter(([, value]) => value != null && value !== '' && !(Array.isArray(value) && value.length === 0))
			.map(([name, value]) => ({name, value: Array.isArray(value) ? value.join(', ') : value}));
		}
		catch
		{
			return [];
		}
	}

	formatHeadersForCopy(headers)
	{
		return headers.map(header => `${header.name}: ${header.value}`).join('\n');
	}

	formatDuration(value)
	{
		return value != null ? value + 'ms' : '\u2014';
	}

	async copyToClipboard(text, successMessage, buttonId)
	{
		try
		{
			await navigator.clipboard.writeText(text);
			this.showSuccessToast(successMessage);
			this.copiedButtonId = buttonId;
			clearTimeout(this._copyResetTimeout);
			// eslint-disable-next-line @lwc/lwc/no-async-operation -- deliberate delay to reset copy icon
			this._copyResetTimeout = setTimeout(() =>
			{
				this.copiedButtonId = null;
			}, COPY_RESET_DELAY);
		}
		catch
		{
			this.showErrorToast(TOAST_COPY_FAILED);
		}
	}
}