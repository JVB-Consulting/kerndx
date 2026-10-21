// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for the utilityApiIssueAction module, which runs an action on an API issue record for
 *              the Retry and Dismiss quick actions.
 *
 * @author Jason van Beukering
 *
 * @date October 2026
 */
import {runApiIssueAction} from 'c/utilityApiIssueAction';
import {notifyRecordUpdateAvailable} from 'lightning/uiRecordApi';

// c/utilitySystem is not mocked: the module runs the real reduceErrors. lightning/uiRecordApi is not mocked either:
// the sfdx-lwc-jest stub already makes notifyRecordUpdateAvailable a Jest mock function. A jest.mock of such a module
// stops working once another suite in the same Jest worker has loaded the real one.

jest.mock('lightning/actions', () => ({
	CloseActionScreenEvent: class CloseActionScreenEvent extends CustomEvent
	{
		constructor()
		{
			super('close');
		}
	}
}), {virtual: true});

/** @description The id of the API issue record the quick action is open on. */
const RECORD_ID = 'a00000000000001';

/** @description The toast text when the action worked. */
const SUCCESS_MESSAGE = 'The action worked';

/** @description The toast text when the action did not work and the Apex method gave no reason. */
const FAILURE_MESSAGE = 'The action did not work';

/** @description The toast text when the call threw and the error has no readable detail. */
const UNEXPECTED_ERROR_MESSAGE = 'An unexpected error occurred';

/** @description The name the logged error is filed under. */
const ERROR_SOURCE = 'TestAction.invoke';

/** @description The reason the Apex method gives when the action did not work. */
const REFUSAL_MESSAGE = 'You need a permission to do this';

/** @description The message of the error the Apex call throws. */
const SERVER_ERROR_MESSAGE = 'Server error';

/** @description The message of a JavaScript error the Apex call throws, for example when the network fails. */
const NETWORK_FAILURE_MESSAGE = 'Network failure';

/** @description The name of the event that closes the quick action. */
const CLOSE_EVENT_NAME = 'close';

/**
 * @description Builds the quick action the module runs against, with the properties it uses.
 * @returns {Object}
 */
function createQuickAction()
{
	return {recordId: RECORD_ID, showSuccessToast: jest.fn(), showErrorToast: jest.fn(), consoleError: jest.fn(), dispatchEvent: jest.fn()};
}

/**
 * @description Builds the parts of the action, with an Apex call that gives the result or error it is handed.
 * @param {Function} callApex - The Apex call of the action.
 * @returns {Object}
 */
function createAction(callApex)
{
	return {
		callApex, successMessage: SUCCESS_MESSAGE, failureMessage: FAILURE_MESSAGE, unexpectedErrorMessage: UNEXPECTED_ERROR_MESSAGE, errorSource: ERROR_SOURCE
	};
}

/**
 * @description Checks that the quick action was closed once, with the close event.
 * @param {Object} quickAction - The quick action the module ran against.
 */
function expectClosedOnce(quickAction)
{
	expect(quickAction.dispatchEvent).toHaveBeenCalledTimes(1);
	expect(quickAction.dispatchEvent.mock.calls[0][0].type).toBe(CLOSE_EVENT_NAME);
}

describe('c-utility-api-issue-action', () =>
{
	afterEach(() =>
	{
		jest.clearAllMocks();
	});

	it('refreshes the record, shows the success toast and closes the action when the action worked', async() =>
	{
		const callApex = jest.fn().mockResolvedValue({callSuccessful: true});
		const quickAction = createQuickAction();

		await runApiIssueAction(quickAction, createAction(callApex));

		expect(callApex).toHaveBeenCalledTimes(1);
		expect(notifyRecordUpdateAvailable).toHaveBeenCalledWith([{recordId: RECORD_ID}]);
		expect(quickAction.showSuccessToast).toHaveBeenCalledWith(SUCCESS_MESSAGE);
		expect(quickAction.showErrorToast).not.toHaveBeenCalled();
		expect(quickAction.consoleError).not.toHaveBeenCalled();
		expectClosedOnce(quickAction);
	});

	it('shows the reason from the Apex method and does not refresh the record when the action did not work', async() =>
	{
		const quickAction = createQuickAction();

		await runApiIssueAction(quickAction, createAction(jest.fn().mockResolvedValue({callSuccessful: false, errorMessage: REFUSAL_MESSAGE})));

		expect(quickAction.showErrorToast).toHaveBeenCalledWith(REFUSAL_MESSAGE);
		expect(quickAction.showSuccessToast).not.toHaveBeenCalled();
		expect(notifyRecordUpdateAvailable).not.toHaveBeenCalled();
		expectClosedOnce(quickAction);
	});

	it.each([
		[
			'an empty reason',
			''
		],
		[
			'no reason',
			null
		]
	])('shows the failure text when the action did not work and the Apex method gave %s', async(reasonKind, errorMessage) =>
	{
		const quickAction = createQuickAction();

		await runApiIssueAction(quickAction, createAction(jest.fn().mockResolvedValue({callSuccessful: false, errorMessage})));

		expect(quickAction.showErrorToast).toHaveBeenCalledWith(FAILURE_MESSAGE);
		expect(notifyRecordUpdateAvailable).not.toHaveBeenCalled();
		expectClosedOnce(quickAction);
	});

	it.each([
		[
			'an error from the Apex method',
			{body: {message: SERVER_ERROR_MESSAGE}},
			SERVER_ERROR_MESSAGE
		],
		[
			'a JavaScript error',
			new Error(NETWORK_FAILURE_MESSAGE),
			NETWORK_FAILURE_MESSAGE
		]
	])('logs the error and shows its detail when the Apex call throws %s', async(errorKind, error, expectedDetail) =>
	{
		const quickAction = createQuickAction();

		await runApiIssueAction(quickAction, createAction(jest.fn().mockRejectedValue(error)));

		expect(quickAction.consoleError).toHaveBeenCalledWith(error, ERROR_SOURCE);
		expect(quickAction.showErrorToast).toHaveBeenCalledWith(expectedDetail);
		expect(quickAction.showSuccessToast).not.toHaveBeenCalled();
		expectClosedOnce(quickAction);
	});

	it.each([
		[
			'nothing',
			null
		],
		[
			'an empty object',
			{}
		]
	])('shows the unexpected error text when the thrown error is %s and has no readable detail', async(errorKind, error) =>
	{
		const quickAction = createQuickAction();

		await runApiIssueAction(quickAction, createAction(jest.fn().mockRejectedValue(error)));

		expect(quickAction.consoleError).toHaveBeenCalledWith(error, ERROR_SOURCE);
		expect(quickAction.showErrorToast).toHaveBeenCalledWith(UNEXPECTED_ERROR_MESSAGE);
		expectClosedOnce(quickAction);
	});

	it('logs the error and still closes the action when the record refresh fails', async() =>
	{
		const refreshError = new Error(SERVER_ERROR_MESSAGE);
		notifyRecordUpdateAvailable.mockRejectedValueOnce(refreshError);
		const quickAction = createQuickAction();

		await runApiIssueAction(quickAction, createAction(jest.fn().mockResolvedValue({callSuccessful: true})));

		expect(quickAction.showSuccessToast).not.toHaveBeenCalled();
		expect(quickAction.consoleError).toHaveBeenCalledWith(refreshError, ERROR_SOURCE);
		expect(quickAction.showErrorToast).toHaveBeenCalledWith(SERVER_ERROR_MESSAGE);
		expectClosedOnce(quickAction);
	});
});
