// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for retryApiIssue headless LWC quick action component.
 *
 * @author Jason van Beukering
 * @date February 2026, May 2026
 */

jest.mock('lightning/uiRecordApi', () => ({
	notifyRecordUpdateAvailable: jest.fn()
}), {virtual: true});

jest.mock('lightning/actions', () => ({
	CloseActionScreenEvent: class CloseActionScreenEvent extends CustomEvent
	{
		constructor()
		{
			super('close');
		}
	}
}), {virtual: true});

jest.mock('c/utilitySystem', () => ({
	reduceErrors: jest.fn().mockReturnValue('mock error detail')
}), {virtual: true});

/*
 * Note on `global.__lwcJestMock_retry`:
 *
 * The @lwc/jest-transformer rewrites `import retry from '@salesforce/apex/...'`
 * into a try/catch that stashes a fallback `jest.fn()` on the global under
 * `__lwcJestMock_<name>` if the require throws. By pre-setting that global
 * BEFORE the component module is required, we cover the truthy-LHS branch of
 * the generated `global.X || function X() {...}` expression AND keep full
 * control over the retry function's return value. The module is loaded inside
 * `jest.isolateModules` so each test sees a fresh catch-block execution.
 *
 * This is a Jest coverage concern only — in production the try-path succeeds
 * and the fallback code is never reached.
 */
describe('c-retry-api-issue', () =>
{
	let retry;

	beforeAll(() =>
	{
		retry = jest.fn();
		global.__lwcJestMock_retry = retry;
	});

	afterAll(() =>
	{
		delete global.__lwcJestMock_retry;
	});

	beforeEach(() =>
	{
		retry.mockReset();
	});

	afterEach(() =>
	{
		while(document.body.firstChild)
		{
			document.body.removeChild(document.body.firstChild);
		}
		jest.clearAllMocks();
	});

	/**
	 * @description Loads the component inside an isolated module registry so the
	 *              transformer's apex-import catch block runs fresh each time.
	 * @returns {Function} The RetryApiIssue class.
	 */
	function loadComponent()
	{
		let component;
		jest.isolateModules(() =>
		{
			component = require('c/retryApiIssue').default;
		});
		return component;
	}

	/**
	 * @description Builds a prototype-invocation context with the properties the
	 *              quick action touches during `invoke()`.
	 * @param {Object} overrides - Optional property overrides.
	 * @returns {Object}
	 */
	function createMockContext(overrides = {})
	{
		return {
			recordId: 'a00000000000001', showSuccessToast: jest.fn(), showErrorToast: jest.fn(), consoleError: jest.fn(), dispatchEvent: jest.fn(), ...overrides
		};
	}

	describe('module exports', () =>
	{
		it('exports default as a function', () =>
		{
			const RetryApiIssue = loadComponent();
			expect(RetryApiIssue).toBeDefined();
			expect(typeof RetryApiIssue).toBe('function');
		});

		it('exposes @api recordId via createElement', async() =>
		{
			const {createElement} = require('lwc');
			const RetryApiIssue = require('c/retryApiIssue').default;
			const element = createElement('c-retry-api-issue', {is: RetryApiIssue});
			element.recordId = 'a00000000000001';
			document.body.appendChild(element);
			await Promise.resolve();
			expect(element.recordId).toBe('a00000000000001');
		});
	});

	describe('class structure', () =>
	{
		it('has @api recordId property on prototype', () =>
		{
			const RetryApiIssue = loadComponent();
			const descriptor = Object.getOwnPropertyDescriptor(RetryApiIssue.prototype, 'recordId');
			expect(descriptor).toBeDefined();
		});

		it('has @api invoke method on prototype', () =>
		{
			const RetryApiIssue = loadComponent();
			expect(typeof RetryApiIssue.prototype.invoke).toBe('function');
		});
	});

	describe('invoke behavior', () =>
	{
		it('shows success toast and notifies record update on successful retry', async() =>
		{
			const RetryApiIssue = loadComponent();
			retry.mockResolvedValue({callSuccessful: true});
			const {notifyRecordUpdateAvailable} = require('lightning/uiRecordApi');
			notifyRecordUpdateAvailable.mockResolvedValue();
			const context = createMockContext();

			await RetryApiIssue.prototype.invoke.call(context);

			expect(retry).toHaveBeenCalledWith({recordId: 'a00000000000001'});
			expect(notifyRecordUpdateAvailable).toHaveBeenCalledWith([{recordId: 'a00000000000001'}]);
			expect(context.showSuccessToast).toHaveBeenCalledWith('Retry successful');
			expect(context.showErrorToast).not.toHaveBeenCalled();
			expect(context.dispatchEvent).toHaveBeenCalledTimes(1);
		});

		it('shows error toast with message on business failure', async() =>
		{
			const RetryApiIssue = loadComponent();
			retry.mockResolvedValue({callSuccessful: false, errorMessage: 'Retry not enabled'});
			const {notifyRecordUpdateAvailable} = require('lightning/uiRecordApi');
			const context = createMockContext();

			await RetryApiIssue.prototype.invoke.call(context);

			expect(context.showErrorToast).toHaveBeenCalledWith('Retry not enabled');
			expect(notifyRecordUpdateAvailable).not.toHaveBeenCalled();
			expect(context.dispatchEvent).toHaveBeenCalledTimes(1);
		});

		it('shows fallback error toast when errorMessage is null', async() =>
		{
			const RetryApiIssue = loadComponent();
			retry.mockResolvedValue({callSuccessful: false, errorMessage: null});
			const context = createMockContext();

			await RetryApiIssue.prototype.invoke.call(context);

			expect(context.showErrorToast).toHaveBeenCalledWith('Retry failed');
			expect(context.dispatchEvent).toHaveBeenCalledTimes(1);
		});

		it('shows fallback error toast when errorMessage is empty string', async() =>
		{
			const RetryApiIssue = loadComponent();
			retry.mockResolvedValue({callSuccessful: false, errorMessage: ''});
			const context = createMockContext();

			await RetryApiIssue.prototype.invoke.call(context);

			expect(context.showErrorToast).toHaveBeenCalledWith('Retry failed');
		});

		it('shows error toast and logs error on exception', async() =>
		{
			const RetryApiIssue = loadComponent();
			const error = {body: {message: 'Server error'}};
			retry.mockRejectedValue(error);
			const context = createMockContext();

			await RetryApiIssue.prototype.invoke.call(context);

			expect(context.consoleError).toHaveBeenCalledWith(error, 'RetryApiIssue.invoke');
			expect(context.showErrorToast).toHaveBeenCalledWith('mock error detail');
			expect(context.dispatchEvent).toHaveBeenCalledTimes(1);
		});

		it('shows fallback error toast when reduceErrors returns empty string', async() =>
		{
			const RetryApiIssue = loadComponent();
			const {reduceErrors} = require('c/utilitySystem');
			reduceErrors.mockReturnValueOnce('');
			retry.mockRejectedValue({});
			const context = createMockContext();

			await RetryApiIssue.prototype.invoke.call(context);

			expect(context.consoleError).toHaveBeenCalled();
			expect(context.showErrorToast).toHaveBeenCalledWith('An unexpected error occurred');
			expect(context.dispatchEvent).toHaveBeenCalledTimes(1);
		});

		it('always dispatches CloseActionScreenEvent on error', async() =>
		{
			const RetryApiIssue = loadComponent();
			retry.mockRejectedValue(new Error('Network failure'));
			const context = createMockContext();

			await RetryApiIssue.prototype.invoke.call(context);

			expect(context.dispatchEvent).toHaveBeenCalledTimes(1);
		});

		it('exercises the transformer fallback stub when global slot is empty', async() =>
		{
			delete global.__lwcJestMock_retry;
			let RetryApiIssueFresh;
			jest.isolateModules(() =>
			{
				RetryApiIssueFresh = require('c/retryApiIssue').default;
			});
			global.__lwcJestMock_retry = retry;

			const context = createMockContext();

			await RetryApiIssueFresh.prototype.invoke.call(context);

			expect(context.consoleError).toHaveBeenCalled();
			expect(context.dispatchEvent).toHaveBeenCalledTimes(1);
		});
	});
});
