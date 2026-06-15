// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for moduleNotification LWC module
 *
 * @author Jason van Beukering
 *
 * @date December 2025, June 2026
 */

		// Mock ShowToastEvent
const mockShowToastEventInstances = [];
jest.mock('lightning/platformShowToastEvent', () => ({
	ShowToastEvent: class MockShowToastEvent
	{
		constructor(config)
		{
			this.title = config.title;
			this.message = config.message;
			this.variant = config.variant;
			this.messageData = config.messageData;
			this.mode = config.mode;
			mockShowToastEventInstances.push(this);
		}
	}
}), {virtual: true});

// Mock c/utilitySystem — verifies that moduleNotification invokes reduceErrors only for
// object-shaped inputs. The actual reduceErrors implementation is covered by utilitySystem.test.js.
const mockReduceErrors = jest.fn((errors) => 'reduced: ' + JSON.stringify(errors));
jest.mock('c/utilitySystem', () => ({
	reduceErrors: (errors) => mockReduceErrors(errors)
}), {virtual: true});

import initialiseNotificationModule, {
	initialiseCustomNotification, initialiseCustomNotificationFactory, initializeShowInfoToast, initializeShowWarningToast, initializeShowSuccessToast, initializeShowErrorToast,
	INFO_NOTIFICATION_TITLE, WARNING_NOTIFICATION_TITLE, SUCCESS_NOTIFICATION_TITLE, ERROR_NOTIFICATION_TITLE
} from 'c/moduleNotification';

describe('moduleNotification', () =>
{
	let mockComponent;

	beforeEach(() =>
	{
		jest.clearAllMocks();
		mockShowToastEventInstances.length = 0;
		mockComponent = {
			dispatchEvent: jest.fn().mockReturnValue(true)
		};
	});

	describe('constants', () =>
	{
		it('should export INFO_NOTIFICATION_TITLE', () =>
		{
			expect(INFO_NOTIFICATION_TITLE).toBe('Info');
		});

		it('should export WARNING_NOTIFICATION_TITLE', () =>
		{
			expect(WARNING_NOTIFICATION_TITLE).toBe('Warning');
		});

		it('should export SUCCESS_NOTIFICATION_TITLE', () =>
		{
			expect(SUCCESS_NOTIFICATION_TITLE).toBe('Success');
		});

		it('should export ERROR_NOTIFICATION_TITLE', () =>
		{
			expect(ERROR_NOTIFICATION_TITLE).toBe('Error');
		});
	});

	describe('initialiseCustomNotification', () =>
	{
		it('should add customNotification method to component', () =>
		{
			initialiseCustomNotification(mockComponent);
			expect(typeof mockComponent.customNotification).toBe('function');
		});

		it('should dispatch ShowToastEvent with default values', () =>
		{
			initialiseCustomNotification(mockComponent);
			const result = mockComponent.customNotification('Title', 'Message');

			expect(mockComponent.dispatchEvent).toHaveBeenCalledTimes(1);
			expect(result).toBe(true);

			const toastEvent = mockShowToastEventInstances[0];
			expect(toastEvent.title).toBe('Title');
			expect(toastEvent.message).toBe('Message');
			expect(toastEvent.variant).toBe('info');
			expect(toastEvent.messageData).toEqual([]);
			expect(toastEvent.mode).toBe('dismissible');
		});

		it('should dispatch ShowToastEvent with custom values', () =>
		{
			initialiseCustomNotification(mockComponent);
			mockComponent.customNotification('Custom Title', 'Custom Message', 'success', ['data'], 'sticky');

			const toastEvent = mockShowToastEventInstances[0];
			expect(toastEvent.title).toBe('Custom Title');
			expect(toastEvent.message).toBe('Custom Message');
			expect(toastEvent.variant).toBe('success');
			expect(toastEvent.messageData).toEqual(['data']);
			expect(toastEvent.mode).toBe('sticky');
		});

		describe('variant validation', () =>
		{
			beforeEach(() =>
			{
				initialiseCustomNotification(mockComponent);
			});

			it('should accept info variant', () =>
			{
				expect(() => mockComponent.customNotification('T', 'M', 'info')).not.toThrow();
			});

			it('should accept success variant', () =>
			{
				expect(() => mockComponent.customNotification('T', 'M', 'success')).not.toThrow();
			});

			it('should accept warning variant', () =>
			{
				expect(() => mockComponent.customNotification('T', 'M', 'warning')).not.toThrow();
			});

			it('should accept error variant', () =>
			{
				expect(() => mockComponent.customNotification('T', 'M', 'error')).not.toThrow();
			});

			it('should throw error for invalid variant', () =>
			{
				expect(() => mockComponent.customNotification('T', 'M', 'invalid'))
				.toThrow('Invalid Toast variant. Valid values are: \'info\' (default), \'success\', \'warning\', and \'error\'.');
			});
		});

		describe('mode validation', () =>
		{
			beforeEach(() =>
			{
				initialiseCustomNotification(mockComponent);
			});

			it('should accept dismissible mode', () =>
			{
				expect(() => mockComponent.customNotification('T', 'M', 'info', [], 'dismissible')).not.toThrow();
			});

			it('should accept pester mode', () =>
			{
				expect(() => mockComponent.customNotification('T', 'M', 'info', [], 'pester')).not.toThrow();
			});

			it('should accept sticky mode', () =>
			{
				expect(() => mockComponent.customNotification('T', 'M', 'info', [], 'sticky')).not.toThrow();
			});

			it('should throw error for invalid mode', () =>
			{
				expect(() => mockComponent.customNotification('T', 'M', 'info', [], 'invalid'))
				.toThrow('Invalid Toast mode. Valid values are: \'dismissible\' (default), \'pester\', and \'sticky\'.');
			});
		});
	});

	describe('initialiseCustomNotificationFactory', () =>
	{
		it('should add customNotificationFactory method to component', () =>
		{
			initialiseCustomNotificationFactory(mockComponent);
			expect(typeof mockComponent.customNotificationFactory).toBe('function');
		});

		it('should also initialise customNotification by default', () =>
		{
			initialiseCustomNotificationFactory(mockComponent);
			expect(typeof mockComponent.customNotification).toBe('function');
		});

		it('should not initialise customNotification when flag is false', () =>
		{
			initialiseCustomNotificationFactory(mockComponent, false);
			expect(mockComponent.customNotification).toBeUndefined();
		});

		it('should create factory that returns notification function', () =>
		{
			initialiseCustomNotificationFactory(mockComponent);
			const infoNotifier = mockComponent.customNotificationFactory();
			expect(typeof infoNotifier).toBe('function');
		});

		it('should create factory with custom variant and mode', () =>
		{
			initialiseCustomNotificationFactory(mockComponent);
			const errorNotifier = mockComponent.customNotificationFactory('error', 'sticky');

			errorNotifier('Error message', 'Error Title');

			const toastEvent = mockShowToastEventInstances[0];
			expect(toastEvent.variant).toBe('error');
			expect(toastEvent.mode).toBe('sticky');
		});

		it('should use factory defaults (info, dismissible)', () =>
		{
			initialiseCustomNotificationFactory(mockComponent);
			const defaultNotifier = mockComponent.customNotificationFactory();

			defaultNotifier('Message', 'Title');

			const toastEvent = mockShowToastEventInstances[0];
			expect(toastEvent.variant).toBe('info');
			expect(toastEvent.mode).toBe('dismissible');
		});
	});

	describe('initializeShowInfoToast', () =>
	{
		it('should add showInfoToast method to component', () =>
		{
			initialiseCustomNotificationFactory(mockComponent);
			initializeShowInfoToast(mockComponent);
			expect(typeof mockComponent.showInfoToast).toBe('function');
		});

		it('should initialise customNotificationFactory when not already initialised', () =>
		{
			initializeShowInfoToast(mockComponent, false);
			expect(typeof mockComponent.customNotificationFactory).toBe('function');
		});

		it('should show info toast with default title', () =>
		{
			initialiseCustomNotificationFactory(mockComponent);
			initializeShowInfoToast(mockComponent);

			mockComponent.showInfoToast('Info message');

			const toastEvent = mockShowToastEventInstances[0];
			expect(toastEvent.title).toBe('Info');
			expect(toastEvent.message).toBe('Info message');
			expect(toastEvent.variant).toBe('info');
		});

		it('should show info toast with custom title', () =>
		{
			initialiseCustomNotificationFactory(mockComponent);
			initializeShowInfoToast(mockComponent);

			mockComponent.showInfoToast('Info message', 'Custom Info Title');

			const toastEvent = mockShowToastEventInstances[0];
			expect(toastEvent.title).toBe('Custom Info Title');
		});
	});

	describe('initializeShowWarningToast', () =>
	{
		it('should add showWarningToast method to component', () =>
		{
			initialiseCustomNotificationFactory(mockComponent);
			initializeShowWarningToast(mockComponent);
			expect(typeof mockComponent.showWarningToast).toBe('function');
		});

		it('should initialise customNotificationFactory when not already initialised', () =>
		{
			initializeShowWarningToast(mockComponent, false);
			expect(typeof mockComponent.customNotificationFactory).toBe('function');
		});

		it('should show warning toast with default title', () =>
		{
			initialiseCustomNotificationFactory(mockComponent);
			initializeShowWarningToast(mockComponent);

			mockComponent.showWarningToast('Warning message');

			const toastEvent = mockShowToastEventInstances[0];
			expect(toastEvent.title).toBe('Warning');
			expect(toastEvent.message).toBe('Warning message');
			expect(toastEvent.variant).toBe('warning');
		});

		it('should show warning toast with custom title', () =>
		{
			initialiseCustomNotificationFactory(mockComponent);
			initializeShowWarningToast(mockComponent);

			mockComponent.showWarningToast('Warning message', 'Custom Warning Title');

			const toastEvent = mockShowToastEventInstances[0];
			expect(toastEvent.title).toBe('Custom Warning Title');
		});
	});

	describe('initializeShowSuccessToast', () =>
	{
		it('should add showSuccessToast method to component', () =>
		{
			initialiseCustomNotificationFactory(mockComponent);
			initializeShowSuccessToast(mockComponent);
			expect(typeof mockComponent.showSuccessToast).toBe('function');
		});

		it('should initialise customNotificationFactory when not already initialised', () =>
		{
			initializeShowSuccessToast(mockComponent, false);
			expect(typeof mockComponent.customNotificationFactory).toBe('function');
		});

		it('should show success toast with default title', () =>
		{
			initialiseCustomNotificationFactory(mockComponent);
			initializeShowSuccessToast(mockComponent);

			mockComponent.showSuccessToast('Success message');

			const toastEvent = mockShowToastEventInstances[0];
			expect(toastEvent.title).toBe('Success');
			expect(toastEvent.message).toBe('Success message');
			expect(toastEvent.variant).toBe('success');
		});

		it('should show success toast with custom title', () =>
		{
			initialiseCustomNotificationFactory(mockComponent);
			initializeShowSuccessToast(mockComponent);

			mockComponent.showSuccessToast('Success message', 'Custom Success Title');

			const toastEvent = mockShowToastEventInstances[0];
			expect(toastEvent.title).toBe('Custom Success Title');
		});
	});

	describe('initializeShowErrorToast', () =>
	{
		it('should add showErrorToast method to component', () =>
		{
			initialiseCustomNotificationFactory(mockComponent);
			initializeShowErrorToast(mockComponent);
			expect(typeof mockComponent.showErrorToast).toBe('function');
		});

		it('should initialise customNotificationFactory when not already initialised', () =>
		{
			initializeShowErrorToast(mockComponent, false);
			expect(typeof mockComponent.customNotificationFactory).toBe('function');
		});

		it('should show error toast with default title', () =>
		{
			initialiseCustomNotificationFactory(mockComponent);
			initializeShowErrorToast(mockComponent);

			mockComponent.showErrorToast('Error message');

			const toastEvent = mockShowToastEventInstances[0];
			expect(toastEvent.title).toBe('Error');
			expect(toastEvent.message).toBe('Error message');
			expect(toastEvent.variant).toBe('error');
		});

		it('should show error toast with custom title', () =>
		{
			initialiseCustomNotificationFactory(mockComponent);
			initializeShowErrorToast(mockComponent);

			mockComponent.showErrorToast('Error message', 'Custom Error Title');

			const toastEvent = mockShowToastEventInstances[0];
			expect(toastEvent.title).toBe('Custom Error Title');
		});

		it('shouldPassStringMessageThroughUnchangedWithoutCallingReduceErrors', () =>
		{
			initialiseCustomNotificationFactory(mockComponent);
			initializeShowErrorToast(mockComponent);

			mockComponent.showErrorToast('plain string error');

			expect(mockReduceErrors).not.toHaveBeenCalled();
			expect(mockShowToastEventInstances[0].message).toBe('plain string error');
		});

		it('shouldReduceErrorObjectViaUtilitySystem', () =>
		{
			initialiseCustomNotificationFactory(mockComponent);
			initializeShowErrorToast(mockComponent);
			const apexError = {body: {message: 'failed'}};

			mockComponent.showErrorToast(apexError);

			expect(mockReduceErrors).toHaveBeenCalledTimes(1);
			expect(mockReduceErrors).toHaveBeenCalledWith(apexError);
			expect(mockShowToastEventInstances[0].message).toBe('reduced: ' + JSON.stringify(apexError));
		});

		it('shouldReduceArrayErrorInputs', () =>
		{
			initialiseCustomNotificationFactory(mockComponent);
			initializeShowErrorToast(mockComponent);
			const apexErrors = [
				{body: [{message: 'one'}]},
				{message: 'two'}
			];

			mockComponent.showErrorToast(apexErrors);

			expect(mockReduceErrors).toHaveBeenCalledTimes(1);
			expect(mockReduceErrors).toHaveBeenCalledWith(apexErrors);
		});

		it('shouldReduceNullishMessageThroughUtilitySystem', () =>
		{
			initialiseCustomNotificationFactory(mockComponent);
			initializeShowErrorToast(mockComponent);

			mockComponent.showErrorToast(null);

			expect(mockReduceErrors).toHaveBeenCalledTimes(1);
			expect(mockReduceErrors).toHaveBeenCalledWith(null);
		});
	});

	describe('initialiseNotificationModule (default export)', () =>
	{
		it('should add all notification methods to component', () =>
		{
			initialiseNotificationModule(mockComponent);

			expect(typeof mockComponent.customNotification).toBe('function');
			expect(typeof mockComponent.customNotificationFactory).toBe('function');
			expect(typeof mockComponent.showInfoToast).toBe('function');
			expect(typeof mockComponent.showWarningToast).toBe('function');
			expect(typeof mockComponent.showSuccessToast).toBe('function');
			expect(typeof mockComponent.showErrorToast).toBe('function');
		});

		it('should allow all toast methods to work correctly', () =>
		{
			initialiseNotificationModule(mockComponent);

			mockComponent.showInfoToast('Info');
			mockComponent.showWarningToast('Warning');
			mockComponent.showSuccessToast('Success');
			mockComponent.showErrorToast('Error');

			expect(mockComponent.dispatchEvent).toHaveBeenCalledTimes(4);
		});
	});
});
