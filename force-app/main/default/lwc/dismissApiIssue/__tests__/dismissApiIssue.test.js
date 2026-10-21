// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for the dismissApiIssue headless quick action, which marks an API issue resolved
 *              without running its request again. The toasts, the record refresh, the closing and the error logging
 *              belong to c/utilityApiIssueAction and are proved in its own suite. This suite proves what belongs to
 *              this action: it calls the dismiss Apex method with the issue id, hands the shared action its own toast
 *              texts and error name, and shows recordId and invoke on the element.
 *
 * @author Jason van Beukering
 * @date October 2026
 */

jest.mock('lightning/actions', () => ({
	CloseActionScreenEvent: class CloseActionScreenEvent extends CustomEvent
	{
		constructor()
		{
			super('close');
		}
	}
}), {virtual: true});

// c/utilityApiIssueAction is not mocked: the action runs the real module, which is only watched with a spy. A
// jest.mock of a c/* module stops working once another suite in the same Jest worker has loaded the real module.

// Give the toast labels their real English values (the default sfdx-lwc-jest stub gives each one the bare string
// 'c.<Name>').
jest.mock('@salesforce/label/c.RetryApiIssue_Dismissed', () => ({default: 'The issue was marked resolved without running the request again.'}), {virtual: true});
jest.mock('@salesforce/label/c.RetryApiIssue_UnexpectedError', () => ({default: 'An unexpected error occurred'}), {virtual: true});

/** @description The id of the API issue record the quick action runs on. */
const ISSUE_ID = 'a00000000000001';

/** @description The toast text shown when the issue was marked resolved. */
const DISMISSED_MESSAGE = 'The issue was marked resolved without running the request again.';

/**
 * @description The toast text shown when the dismiss did not work and nothing better is known. The action uses it
 *              both when the Apex method gives no reason and when a thrown error has no readable detail.
 */
const UNEXPECTED_ERROR_MESSAGE = 'An unexpected error occurred';

/** @description The name a thrown error is logged under. */
const ERROR_SOURCE = 'DismissApiIssue.invoke';

/** @description The stand-in for the dismiss Apex method. */
const dismiss = jest.fn();

/*
 * Note on the global slot `__lwcJestMock_dismiss`:
 *
 * The @lwc/jest-transformer turns `import dismiss from '@salesforce/apex/...'` into a try/catch. When the require
 * throws, the catch block uses the function in the global slot, or makes a fallback function when the slot is empty.
 * The tests fill the slot before the component is loaded, so they control what dismiss returns; the last test
 * leaves it empty to run the fallback function. Each load runs inside `jest.isolateModules`, so the catch block runs
 * again. This only matters for Jest coverage: in production the import works and the catch block never runs.
 */

/**
 * @description Loads the dismiss quick action in a fresh module registry, together with the real shared action
 *              module and a spy on it that still runs the real code.
 * @param {Function} [apexStandIn] - What to put in the global slot for the dismiss Apex method; leave it out to
 *                                   run the fallback function of the Jest transformer.
 * @returns {{dismissApiIssueClass: Function, runApiIssueActionSpy: jest.SpyInstance}} The class and the spy.
 */
function loadDismissAction(apexStandIn)
{
	const result = {};
	global.__lwcJestMock_dismiss = apexStandIn;
	jest.isolateModules(() =>
	{
		result.runApiIssueActionSpy = jest.spyOn(require('c/utilityApiIssueAction'), 'runApiIssueAction');
		result.dismissApiIssueClass = require('c/dismissApiIssue').default;
	});
	delete global.__lwcJestMock_dismiss;
	return result;
}

/**
 * @description Builds the object `invoke()` runs against: the issue id and the methods the shared action calls.
 * @returns {Object}
 */
function createIssueQuickAction()
{
	return {recordId: ISSUE_ID, showSuccessToast: jest.fn(), showErrorToast: jest.fn(), consoleError: jest.fn(), dispatchEvent: jest.fn()};
}

describe('c-dismiss-api-issue', () =>
{
	afterEach(() =>
	{
		document.body.replaceChildren();
		jest.clearAllMocks();
	});

	it('shows recordId and invoke on the element', async() =>
	{
		const {createElement} = require('lwc');
		const element = createElement('c-dismiss-api-issue', {is: require('c/dismissApiIssue').default});
		element.recordId = ISSUE_ID;
		document.body.appendChild(element);
		await Promise.resolve();

		expect(element.recordId).toBe(ISSUE_ID);
		expect(typeof element.invoke).toBe('function');
	});

	it('calls dismiss with the issue id and hands the shared action its own toast texts and error name', async() =>
	{
		dismiss.mockResolvedValue({callSuccessful: true});
		const {dismissApiIssueClass, runApiIssueActionSpy} = loadDismissAction(dismiss);
		const quickAction = createIssueQuickAction();

		await dismissApiIssueClass.prototype.invoke.call(quickAction);

		expect(dismiss).toHaveBeenCalledWith({issueId: ISSUE_ID});
		expect(runApiIssueActionSpy.mock.calls).toEqual([
			[
				quickAction,
				{
					callApex: expect.any(Function),
					successMessage: DISMISSED_MESSAGE,
					failureMessage: UNEXPECTED_ERROR_MESSAGE,
					unexpectedErrorMessage: UNEXPECTED_ERROR_MESSAGE,
					errorSource: ERROR_SOURCE
				}
			]
		]);
		expect(quickAction.showSuccessToast).toHaveBeenCalledWith(DISMISSED_MESSAGE);
	});

	it('runs the fallback function of the Jest transformer when no stand-in is given', async() =>
	{
		const quickAction = createIssueQuickAction();

		await loadDismissAction().dismissApiIssueClass.prototype.invoke.call(quickAction);

		expect(dismiss).not.toHaveBeenCalled();
		expect(quickAction.showErrorToast).toHaveBeenCalledTimes(1);
		expect(quickAction.consoleError).toHaveBeenCalledWith(expect.any(TypeError), ERROR_SOURCE);
	});
});
