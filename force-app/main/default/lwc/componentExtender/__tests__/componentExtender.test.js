// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for componentExtender LWC module
 * @author Jason van Beukering
 * @date December 2025, May 2026
 */

// Mock componentBuilder constants
jest.mock('c/componentBuilder', () => ({
	ALL_MODULES: 'all', INVALID_INITIALISATION_ERROR: 'Verify that the module identifiers passed to ComponentBuilder are valid'
}), {virtual: true});

// Mock all module initializers
const mockInitialiseController = jest.fn();
const mockInitialiseFlowNavigation = jest.fn();
const mockInitialiseLightningMessage = jest.fn();
const mockInitialiseNavigation = jest.fn();
const mockInitialiseNotification = jest.fn();

jest.mock('c/moduleController', () => ({
	__esModule: true, default: (...args) => mockInitialiseController(...args)
}), {virtual: true});

jest.mock('c/moduleFlowNavigation', () => ({
	__esModule: true, default: (...args) => mockInitialiseFlowNavigation(...args)
}), {virtual: true});

jest.mock('c/moduleLightningMessageService', () => ({
	__esModule: true, default: (...args) => mockInitialiseLightningMessage(...args)
}), {virtual: true});

jest.mock('c/moduleNavigation', () => ({
	__esModule: true, default: (...args) => mockInitialiseNavigation(...args)
}), {virtual: true});

jest.mock('c/moduleNotification', () => ({
	__esModule: true, default: (...args) => mockInitialiseNotification(...args)
}), {virtual: true});

import {componentExtender, activateModules} from 'c/componentExtender';

describe('componentExtender', () =>
{
	let mockComponent;

	beforeEach(() =>
	{
		jest.clearAllMocks();
		mockComponent = {functionality: []};
	});

	describe('componentExtender function', () =>
	{
		it('should initialize single functionality', () =>
		{
			componentExtender(mockComponent, 'notification');

			expect(mockInitialiseNotification).toHaveBeenCalledTimes(1);
			expect(mockInitialiseNotification).toHaveBeenCalledWith(mockComponent);
		});

		it('should initialize multiple functionalities', () =>
		{
			componentExtender(mockComponent, 'notification', 'controller', 'navigation');

			expect(mockInitialiseNotification).toHaveBeenCalledWith(mockComponent);
			expect(mockInitialiseController).toHaveBeenCalledWith(mockComponent);
			expect(mockInitialiseNavigation).toHaveBeenCalledWith(mockComponent);
		});

		it('should deduplicate functionality using Set', () =>
		{
			componentExtender(mockComponent, 'notification', 'notification', 'notification');

			expect(mockInitialiseNotification).toHaveBeenCalledTimes(1);
		});

		it('should replace all functionality with "all" when present', () =>
		{
			componentExtender(mockComponent, 'notification', 'all', 'controller');

			expect(mockInitialiseNotification).toHaveBeenCalledTimes(1);
			expect(mockInitialiseController).toHaveBeenCalledTimes(1);
			expect(mockInitialiseNavigation).toHaveBeenCalledTimes(1);
			expect(mockInitialiseLightningMessage).toHaveBeenCalledTimes(1);
			expect(mockInitialiseFlowNavigation).toHaveBeenCalledTimes(1);
		});

		it('should handle empty functionality list', () =>
		{
			componentExtender(mockComponent);

			expect(mockInitialiseNotification).not.toHaveBeenCalled();
			expect(mockInitialiseController).not.toHaveBeenCalled();
			expect(mockInitialiseNavigation).not.toHaveBeenCalled();
			expect(mockInitialiseLightningMessage).not.toHaveBeenCalled();
			expect(mockInitialiseFlowNavigation).not.toHaveBeenCalled();
		});
	});

	describe('activateModules function', () =>
	{
		describe('navigation', () =>
		{
			it('should initialize navigation module', () =>
			{
				activateModules(mockComponent, ['navigation']);

				expect(mockInitialiseNavigation).toHaveBeenCalledTimes(1);
				expect(mockInitialiseNavigation).toHaveBeenCalledWith(mockComponent);
			});
		});

		describe('notification', () =>
		{
			it('should initialize notification module', () =>
			{
				activateModules(mockComponent, ['notification']);

				expect(mockInitialiseNotification).toHaveBeenCalledTimes(1);
				expect(mockInitialiseNotification).toHaveBeenCalledWith(mockComponent);
			});
		});

		describe('lightning-message', () =>
		{
			it('should initialize lightning message module', () =>
			{
				activateModules(mockComponent, ['lightning-message']);

				expect(mockInitialiseLightningMessage).toHaveBeenCalledTimes(1);
				expect(mockInitialiseLightningMessage).toHaveBeenCalledWith(mockComponent);
			});
		});

		describe('controller', () =>
		{
			it('should initialize controller module', () =>
			{
				activateModules(mockComponent, ['controller']);

				expect(mockInitialiseController).toHaveBeenCalledTimes(1);
				expect(mockInitialiseController).toHaveBeenCalledWith(mockComponent);
			});
		});

		describe('flow-navigation', () =>
		{
			it('should initialize flow navigation module', () =>
			{
				activateModules(mockComponent, ['flow-navigation']);

				expect(mockInitialiseFlowNavigation).toHaveBeenCalledTimes(1);
				expect(mockInitialiseFlowNavigation).toHaveBeenCalledWith(mockComponent);
			});
		});

		describe('all', () =>
		{
			it('should initialize all modules', () =>
			{
				activateModules(mockComponent, ['all']);

				expect(mockInitialiseNavigation).toHaveBeenCalledTimes(1);
				expect(mockInitialiseNotification).toHaveBeenCalledTimes(1);
				expect(mockInitialiseLightningMessage).toHaveBeenCalledTimes(1);
				expect(mockInitialiseController).toHaveBeenCalledTimes(1);
				expect(mockInitialiseFlowNavigation).toHaveBeenCalledTimes(1);
			});

			it('should initialize modules in registration order', () =>
			{
				const callOrder = [];
				mockInitialiseNavigation.mockImplementation(() => callOrder.push('navigation'));
				mockInitialiseNotification.mockImplementation(() => callOrder.push('notification'));
				mockInitialiseLightningMessage.mockImplementation(() => callOrder.push('lightning-message'));
				mockInitialiseController.mockImplementation(() => callOrder.push('controller'));
				mockInitialiseFlowNavigation.mockImplementation(() => callOrder.push('flow-navigation'));

				activateModules(mockComponent, ['all']);

				expect(callOrder).toEqual([
					'navigation',
					'notification',
					'lightning-message',
					'controller',
					'flow-navigation'
				]);
			});
		});

		describe('multiple functionalities', () =>
		{
			it('should initialize multiple modules in order', () =>
			{
				activateModules(mockComponent, [
					'notification',
					'controller'
				]);

				expect(mockInitialiseNotification).toHaveBeenCalledTimes(1);
				expect(mockInitialiseController).toHaveBeenCalledTimes(1);
			});

			it('should initialize all specified modules', () =>
			{
				activateModules(mockComponent, [
					'navigation',
					'notification',
					'lightning-message',
					'controller',
					'flow-navigation'
				]);

				expect(mockInitialiseNavigation).toHaveBeenCalledTimes(1);
				expect(mockInitialiseNotification).toHaveBeenCalledTimes(1);
				expect(mockInitialiseLightningMessage).toHaveBeenCalledTimes(1);
				expect(mockInitialiseController).toHaveBeenCalledTimes(1);
				expect(mockInitialiseFlowNavigation).toHaveBeenCalledTimes(1);
			});
		});

		describe('invalid functionality', () =>
		{
			it('should throw error for invalid functionality value', () =>
			{
				expect(() =>
				{
					activateModules(mockComponent, ['invalid-module']);
				}).toThrow('Invalid initialisation value: \'invalid-module\'');
			});

			it('should include guidance message in error', () =>
			{
				expect(() =>
				{
					activateModules(mockComponent, ['unknown']);
				}).toThrow('Verify that the module identifiers passed to ComponentBuilder are valid');
			});

			it('should throw error with exact invalid value', () =>
			{
				expect(() =>
				{
					activateModules(mockComponent, ['my-custom-module']);
				}).toThrow('Invalid initialisation value: \'my-custom-module\'');
			});
		});

		describe('empty functionality', () =>
		{
			it('should handle empty array without errors', () =>
			{
				expect(() =>
				{
					activateModules(mockComponent, []);
				}).not.toThrow();

				expect(mockInitialiseNavigation).not.toHaveBeenCalled();
				expect(mockInitialiseNotification).not.toHaveBeenCalled();
			});
		});
	});
});
