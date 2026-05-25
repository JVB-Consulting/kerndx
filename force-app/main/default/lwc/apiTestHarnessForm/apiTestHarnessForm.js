// SPDX-License-Identifier: BUSL-1.1
/**
 * @description API Test Harness form component for testing inbound and outbound API calls
 * with Safe Mode and Mocking control. Renders as a full-page two-column layout on the
 * ApiTestHarness FlexiPage tab: configuration on the left, response preview on the right.
 *
 * @author Jason van Beukering
 *
 * @date February 2026, May 2026
 */
import {ComponentBuilder} from 'c/componentBuilder';
import getServices from '@salesforce/apex/CTRL_ApiTestHarness.getServices';
import invokeOutbound from '@salesforce/apex/CTRL_ApiTestHarness.invokeOutbound';
import invokeInbound from '@salesforce/apex/CTRL_ApiTestHarness.invokeInbound';

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

	directionOptions = [
		{label: 'Outbound', value: 'Outbound'},
		{label: 'Inbound', value: 'Inbound'}
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
			return 'LIVE';
		}
		if(!this.safeModeEnabled)
		{
			return 'Live DML · Mocked callouts';
		}
		if(this.mockingEnabled)
		{
			return 'Full Sandbox';
		}
		return 'Safe Mode';
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
		return this.safeModeEnabled ? 'Execute' : 'Execute (Live)';
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
		return this.result?.status || 'Unknown';
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
			`Service: ${this.result?.serviceName || '\u2014'}`,
			`Status: ${this.result?.status || 'Unknown'} (${this.result?.statusCode ?? '\u2014'})`,
			`Total: ${total} (Handler: ${handler}, Callout: ${callout}, Commit: ${commit})`,
			`Safe Mode: ${this.result?.safeModeEnabled ? 'Enabled' : 'Disabled'}`,
			`Mocked: ${this.result?.isMockedResponse ? 'Yes' : 'No'}`,
			`API Call ID: ${this.result?.apiCallId || '\u2014'}`
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
		this.parameterRows = this.parameterRows.map((row) => row.id === rowId ? {...row, key: event.detail.value} : row);
	}

	handleParameterValueChange(event)
	{
		const rowId = event.currentTarget.dataset.rowId;
		this.parameterRows = this.parameterRows.map((row) => row.id === rowId ? {...row, value: event.detail.value} : row);
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
				return 'Parameter key cannot be blank when a value is provided.';
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
				return 'JSON Body contains invalid JSON.';
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
				this.result = null;
				this.showErrorToast('Execution failed to return a result');
				return;
			}

			this.result = executionResult;
			this.resultKey++;

			if(executionResult.isSuccess)
			{
				this.showSuccessToast('Execution completed successfully');
			}
			else if(executionResult.status === 'Aborted')
			{
				this.showWarningToast(executionResult.errorMessages || 'Execution aborted');
			}
			else
			{
				this.showErrorToast(executionResult.errorMessages || 'Execution failed');
			}
		}
		finally
		{
			this.isLoading = false;
		}
	}

	async handleCopySummary()
	{
		await this.copyToClipboard(this.summaryText, 'Summary copied', 'summary');
	}

	async handleCopyRequestHeaders()
	{
		await this.copyToClipboard(this.requestHeadersCopyText, 'Request headers copied', 'requestHeaders');
	}

	async handleCopyResponseHeaders()
	{
		await this.copyToClipboard(this.responseHeadersCopyText, 'Response headers copied', 'responseHeaders');
	}

	async handleCopyRequestBody()
	{
		await this.copyToClipboard(this.result?.requestBody, 'Request body copied', 'requestBody');
	}

	async handleCopyResponseBody()
	{
		await this.copyToClipboard(this.result?.responseBody, 'Response body copied', 'responseBody');
	}

	async handleCopyErrors()
	{
		await this.copyToClipboard(this.result?.errorMessages, 'Errors copied', 'errors');
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
			this.showErrorToast('Failed to copy to clipboard');
		}
	}
}