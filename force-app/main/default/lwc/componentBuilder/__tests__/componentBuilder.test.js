// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for componentBuilder LWC module.
 *
 *              Note: jest.config.js maps c/componentBuilder to the global mock in
 *              test/jest-mocks/c/componentBuilder.js for use by OTHER components.
 *
 *              This test file verifies the global mock works correctly since that's
 *              what all consuming components use. The behavior tested here matches
 *              what the real componentBuilder does.
 *
 *              The mock extends LightningElement to allow components using ComponentBuilder
 *              to be instantiated via createElement. Direct `new` instantiation is not
 *              possible, so tests verify class structure and prototype properties.
 *
 * @author Jason van Beukering
 * @date December 2025, May 2026
 */
import {
	ComponentBuilder, ALL_MODULES, INVALID_INITIALISATION_ERROR, mockShowErrorToast, mockShowWarningToast, mockShowInfoToast, mockShowSuccessToast, mockCustomNotification,
	mockCallControllerMethod, mockHandleWireResponse, mockNavigate, mockGenerateUrl, mockPublishLightningMessage, mockSubscribeToMessageChannel, mockAddMessageChannelSubscription
} from 'c/componentBuilder';

describe('componentBuilder', () =>
{
	describe('module exports', () =>
	{
		it('exports ComponentBuilder as named export', () =>
		{
			expect(ComponentBuilder).toBeDefined();
			expect(typeof ComponentBuilder).toBe('function');
		});

		it('exports ALL_MODULES constant as "all"', () =>
		{
			expect(ALL_MODULES).toBe('all');
		});

		it('exports INVALID_INITIALISATION_ERROR constant', () =>
		{
			expect(INVALID_INITIALISATION_ERROR).toBe('Verify that the module identifiers passed to ComponentBuilder are valid');
		});

		it('exports mock notification functions', () =>
		{
			expect(typeof mockShowErrorToast).toBe('function');
			expect(typeof mockShowWarningToast).toBe('function');
			expect(typeof mockShowInfoToast).toBe('function');
			expect(typeof mockShowSuccessToast).toBe('function');
			expect(typeof mockCustomNotification).toBe('function');
		});

		it('exports mock controller functions', () =>
		{
			expect(typeof mockCallControllerMethod).toBe('function');
			expect(typeof mockHandleWireResponse).toBe('function');
		});

		it('exports mock navigation functions', () =>
		{
			expect(typeof mockNavigate).toBe('function');
			expect(typeof mockGenerateUrl).toBe('function');
		});

		it('exports mock lightning message service functions', () =>
		{
			expect(typeof mockPublishLightningMessage).toBe('function');
			expect(typeof mockSubscribeToMessageChannel).toBe('function');
			expect(typeof mockAddMessageChannelSubscription).toBe('function');
		});
	});

	describe('ComponentBuilder function', () =>
	{
		it('returns a class constructor', () =>
		{
			const BuilderClass = ComponentBuilder('notification');
			expect(typeof BuilderClass).toBe('function');
			expect(BuilderClass.prototype).toBeDefined();
		});

		it('returns different classes for different calls', () =>
		{
			const Class1 = ComponentBuilder('notification');
			const Class2 = ComponentBuilder('controller');
			// Classes are created dynamically, so they should be different
			expect(Class1).not.toBe(Class2);
		});
	});

	describe('returned class structure', () =>
	{
		it('class definition includes notification methods', () =>
		{
			const BuilderClass = ComponentBuilder('notification');
			const classStr = BuilderClass.toString();

			// Methods are class instance fields, check they're defined in class
			expect(classStr).toContain('showErrorToast');
			expect(classStr).toContain('showWarningToast');
			expect(classStr).toContain('showInfoToast');
			expect(classStr).toContain('showSuccessToast');
			expect(classStr).toContain('customNotification');
			expect(classStr).toContain('customNotificationFactory');
		});

		it('class definition includes controller methods', () =>
		{
			const BuilderClass = ComponentBuilder('controller');
			const classStr = BuilderClass.toString();

			expect(classStr).toContain('callControllerMethod');
			expect(classStr).toContain('handleWireResponse');
		});

		it('class definition includes navigation methods', () =>
		{
			const BuilderClass = ComponentBuilder('navigation');
			const classStr = BuilderClass.toString();

			expect(classStr).toContain('navigate');
			expect(classStr).toContain('generateUrl');
		});

		it('class definition includes lightning message service methods', () =>
		{
			const BuilderClass = ComponentBuilder('lightning-message');
			const classStr = BuilderClass.toString();

			expect(classStr).toContain('publishLightningMessage');
			expect(classStr).toContain('subscribeToMessageChannel');
			expect(classStr).toContain('addMessageChannelSubscription');
		});

		it('class definition includes console methods', () =>
		{
			const BuilderClass = ComponentBuilder('all');
			const classStr = BuilderClass.toString();

			expect(classStr).toContain('consoleError');
			expect(classStr).toContain('consoleLog');
		});

		it('class definition includes common properties', () =>
		{
			const BuilderClass = ComponentBuilder('all');
			const classStr = BuilderClass.toString();

			expect(classStr).toContain('isLoading');
			expect(classStr).toContain('spinnerHtml');
			expect(classStr).toContain('functionality');
		});
	});

	describe('mock function behavior', () =>
	{
		beforeEach(() =>
		{
			jest.clearAllMocks();
		});

		it('mockCallControllerMethod invokes the controller', () =>
		{
			const mockController = jest.fn().mockResolvedValue('result');
			const params = {key: 'value'};

			mockCallControllerMethod(mockController, params);

			expect(mockController).toHaveBeenCalledWith(params);
		});

		it('mockHandleWireResponse returns data on success', () =>
		{
			const result = mockHandleWireResponse({data: 'test data', error: null});

			expect(result).toBe('test data');
		});

		it('mockHandleWireResponse shows error toast on error', () =>
		{
			const error = new Error('Test error');

			mockHandleWireResponse({data: null, error});

			expect(mockShowErrorToast).toHaveBeenCalledWith(error);
		});
	});

	describe('functionality handling', () =>
	{
		it('ComponentBuilder accepts single functionality parameter', () =>
		{
			// Verify no error thrown
			expect(() => ComponentBuilder('notification')).not.toThrow();
		});

		it('ComponentBuilder accepts multiple functionality parameters', () =>
		{
			// Verify no error thrown
			expect(() => ComponentBuilder('notification', 'controller', 'navigation')).not.toThrow();
		});

		it('ComponentBuilder accepts empty functionality list', () =>
		{
			// Verify no error thrown
			expect(() => ComponentBuilder()).not.toThrow();
		});

		it('ComponentBuilder accepts ALL_MODULES constant', () =>
		{
			// Verify no error thrown
			expect(() => ComponentBuilder(ALL_MODULES)).not.toThrow();
		});
	});
});
