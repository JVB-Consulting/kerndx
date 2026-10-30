// SPDX-License-Identifier: Apache-2.0
/**
 * @description Jest unit tests for the retryApiIssue headless quick action. The toasts, the record refresh, the closing
 *              and the error logging belong to c/utilityApiIssueAction and are proved in its own suite. This suite proves
 *              what belongs to this action: it calls its own Apex method with the record id, hands the shared action its
 *              own toast texts and error name, and shows recordId and invoke on the element.
 *
 * @author Jason van Beukering
 * @date May 2026, October 2026
 */

// lightning/actions comes from its moduleNameMapper mock in jest.config.js: CloseActionScreenEvent is a close event.

// c/utilityApiIssueAction is not mocked: the action runs the real module, which is only watched with a spy. A
// jest.mock of a c/* module stops working once another suite in the same Jest worker has loaded the real module.

/** @description The id of an API issue about a call your org made. */
const RECORD_ID = 'a00000000000001';

/** @description The id of an API issue about a call your org received. */
const INBOUND_RECORD_ID = 'a00000000000002';

/** @description The toast text when the retry worked. */
const RETRY_SUCCESSFUL_MESSAGE = 'Retry successful';

/** @description The toast text when the retry did not work and the Apex method gave no reason. */
const RETRY_FAILED_MESSAGE = 'Retry failed';

/** @description The toast text when the call threw and the error has no readable detail. */
const UNEXPECTED_ERROR_MESSAGE = 'An unexpected error occurred';

/** @description The name a thrown error is logged under. */
const ERROR_SOURCE = 'RetryApiIssue.invoke';

// Give the toast labels the real English values above (the default sfdx-lwc-jest stub gives each one the bare string
// 'c.<Name>'). A jest.mock factory cannot use the constants, so it repeats the values.
jest.mock('@salesforce/label/c.RetryApiIssue_RetrySuccessful', () => ({default: 'Retry successful'}), {virtual: true});
jest.mock('@salesforce/label/c.RetryApiIssue_RetryFailed', () => ({default: 'Retry failed'}), {virtual: true});
jest.mock('@salesforce/label/c.RetryApiIssue_UnexpectedError', () => ({default: 'An unexpected error occurred'}), {virtual: true});

/** @description The global slot where the Jest transformer looks for the stand-in for the resolveFailure Apex method. */
const APEX_MOCK_SLOT = '__lwcJestMock_resolveFailure';

/** @description The stand-in for the resolveFailure Apex method. */
const resolveFailure = jest.fn();

/*
 * Note on the global slot `__lwcJestMock_resolveFailure`:
 *
 * The @lwc/jest-transformer turns `import resolveFailure from '@salesforce/apex/...'` into a try/catch. When the
 * require throws, the catch block uses the function in the global slot, or makes a fallback function when the slot
 * is empty. Filling the slot BEFORE the component is loaded gives the tests control over what resolveFailure returns.
 * The component is loaded inside `jest.isolateModules`, so the catch block runs again each time. The last test
 * empties the slot to run the fallback function too. This only matters for Jest coverage: in production the import
 * works and the catch block never runs.
 */

/**
 * @description Loads the component and the real shared action module in a fresh module registry, with a spy on the
 *              shared action that still runs the real code.
 * @returns {{retryApiIssueClass: Function, runApiIssueActionSpy: jest.SpyInstance}} The component class and the spy.
 */
function loadComponent()
{
	let loaded;
	jest.isolateModules(() =>
	{
		const runApiIssueActionSpy = jest.spyOn(require('c/utilityApiIssueAction'), 'runApiIssueAction');
		loaded = {retryApiIssueClass: require('c/retryApiIssue').default, runApiIssueActionSpy};
	});
	return loaded;
}

/**
 * @description Builds the object `invoke()` runs against, with the properties the shared action uses.
 * @param {string} recordId - The id of the API issue record the quick action is open on.
 * @returns {Object}
 */
function createQuickAction(recordId)
{
	return {recordId, showSuccessToast: jest.fn(), showErrorToast: jest.fn(), consoleError: jest.fn(), dispatchEvent: jest.fn()};
}

describe('c-retry-api-issue', () =>
{
	beforeAll(() =>
	{
		global[APEX_MOCK_SLOT] = resolveFailure;
	});

	afterAll(() =>
	{
		delete global[APEX_MOCK_SLOT];
	});

	afterEach(() =>
	{
		while(document.body.firstChild)
		{
			document.body.removeChild(document.body.firstChild);
		}
		jest.clearAllMocks();
	});

	it('shows recordId and invoke on the element', async() =>
	{
		const {createElement} = require('lwc');
		const element = createElement('c-retry-api-issue', {is: require('c/retryApiIssue').default});
		element.recordId = RECORD_ID;
		document.body.appendChild(element);
		await Promise.resolve();

		expect(element.recordId).toBe(RECORD_ID);
		expect(typeof element.invoke).toBe('function');
	});

	it('hands the shared action its own toast texts and error name, and the shared action closes the quick action', async() =>
	{
		const {retryApiIssueClass, runApiIssueActionSpy} = loadComponent();
		resolveFailure.mockResolvedValue({callSuccessful: true});
		const quickAction = createQuickAction(RECORD_ID);

		await retryApiIssueClass.prototype.invoke.call(quickAction);

		expect(runApiIssueActionSpy).toHaveBeenCalledWith(quickAction, {
			callApex: expect.any(Function),
			successMessage: RETRY_SUCCESSFUL_MESSAGE,
			failureMessage: RETRY_FAILED_MESSAGE,
			unexpectedErrorMessage: UNEXPECTED_ERROR_MESSAGE,
			errorSource: ERROR_SOURCE
		});
		expect(quickAction.showSuccessToast).toHaveBeenCalledWith(RETRY_SUCCESSFUL_MESSAGE);
		expect(quickAction.dispatchEvent).toHaveBeenCalledTimes(1);
	});

	it.each([
		[
			'an issue about a call your org made',
			RECORD_ID
		],
		[
			'an issue about a call your org received',
			INBOUND_RECORD_ID
		]
	])('sends %s to the same resolve method, with its record id', async(issueKind, recordId) =>
	{
		const {retryApiIssueClass} = loadComponent();
		resolveFailure.mockResolvedValue({callSuccessful: true});

		await retryApiIssueClass.prototype.invoke.call(createQuickAction(recordId));

		expect(resolveFailure).toHaveBeenCalledTimes(1);
		expect(resolveFailure).toHaveBeenCalledWith({failureId: recordId});
	});

	it('runs the fallback function of the Jest transformer when the global slot is empty', async() =>
	{
		delete global[APEX_MOCK_SLOT];
		let retryApiIssueClass;
		try
		{
			({retryApiIssueClass} = loadComponent());
		}
		finally
		{
			global[APEX_MOCK_SLOT] = resolveFailure;
		}
		const quickAction = createQuickAction(RECORD_ID);

		await retryApiIssueClass.prototype.invoke.call(quickAction);

		expect(resolveFailure).not.toHaveBeenCalled();
		expect(quickAction.consoleError).toHaveBeenCalledWith(expect.any(TypeError), ERROR_SOURCE);
		expect(quickAction.dispatchEvent).toHaveBeenCalledTimes(1);
	});
});
