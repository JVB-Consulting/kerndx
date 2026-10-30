// SPDX-License-Identifier: Apache-2.0
/**
 * @description Jest unit tests for componentExtender LWC module
 * @author Jason van Beukering
 * @date December 2025, October 2026
 */

import {componentExtender, activateModules} from 'c/componentExtender';

// The real module initialisers run here. A jest.mock of each c/ module is not reliable: once another suite in the same
// worker has loaded the real module, the mock silently stops intercepting. A spy cannot stand in either, because
// componentExtender keeps each initialiser in its own registry when it loads. So each test watches what the real
// initialisers do: every one puts its methods on the component, and the first method each one sets marks one run of it.
const MODULE_BY_FIRST_METHOD = new Map([
	[
		'redirectToRecordPage',
		'navigation'
	],
	[
		'customNotification',
		'notification'
	],
	[
		'clearSubscriptions',
		'lightning-message'
	],
	[
		'callControllerMethod',
		'controller'
	],
	[
		'dispatchFlowNextEvent',
		'flow-navigation'
	]
]);

/**
 * Builds a component that records, in order, each module whose initialiser ran against it.
 */
function createRecordingComponent()
{
	const initialisedModules = [];
	const component = new Proxy({functionality: []}, {
		set(target, property, value)
		{
			if(MODULE_BY_FIRST_METHOD.has(property))
			{
				initialisedModules.push(MODULE_BY_FIRST_METHOD.get(property));
			}
			target[property] = value;
			return true;
		}
	});
	return {component, initialisedModules};
}

/**
 * Counts how many times the named module was initialised.
 */
function countOf(initialisedModules, moduleName)
{
	return initialisedModules.filter((name) => name === moduleName).length;
}

/**
 * Counts how many times each of the five modules was initialised, keyed by module name.
 */
function countEachModule(initialisedModules)
{
	return Object.fromEntries([...MODULE_BY_FIRST_METHOD.values()].map((moduleName) => [
		moduleName,
		countOf(initialisedModules, moduleName)
	]));
}

/** Every module initialised exactly once. */
const EACH_MODULE_ONCE = {
	navigation: 1, notification: 1, 'lightning-message': 1, controller: 1, 'flow-navigation': 1
};

describe('componentExtender', () =>
{
	let mockComponent;
	let initialisedModules;

	beforeEach(() =>
	{
		({component: mockComponent, initialisedModules} = createRecordingComponent());
	});

	describe('componentExtender function', () =>
	{
		it('should initialize single functionality', () =>
		{
			componentExtender(mockComponent, 'notification');

			expect(initialisedModules).toEqual(['notification']);
			expect(typeof mockComponent.showErrorToast).toBe('function');
		});

		it('should initialize multiple functionalities', () =>
		{
			componentExtender(mockComponent, 'notification', 'controller', 'navigation');

			expect(initialisedModules).toEqual([
				'notification',
				'controller',
				'navigation'
			]);
			expect(typeof mockComponent.showErrorToast).toBe('function');
			expect(typeof mockComponent.callControllerMethod).toBe('function');
			expect(typeof mockComponent.redirectToRecordPage).toBe('function');
		});

		it('should deduplicate functionality using Set', () =>
		{
			componentExtender(mockComponent, 'notification', 'notification', 'notification');

			expect(countOf(initialisedModules, 'notification')).toBe(1);
		});

		it('should replace all functionality with "all" when present', () =>
		{
			componentExtender(mockComponent, 'notification', 'all', 'controller');

			expect(countOf(initialisedModules, 'notification')).toBe(1);
			expect(countOf(initialisedModules, 'controller')).toBe(1);
			expect(countOf(initialisedModules, 'navigation')).toBe(1);
			expect(countOf(initialisedModules, 'lightning-message')).toBe(1);
			expect(countOf(initialisedModules, 'flow-navigation')).toBe(1);
		});

		it('should handle empty functionality list', () =>
		{
			componentExtender(mockComponent);

			expect(initialisedModules).toEqual([]);
		});
	});

	describe('activateModules function', () =>
	{
		describe('navigation', () =>
		{
			it('should initialize navigation module', () =>
			{
				activateModules(mockComponent, ['navigation']);

				expect(initialisedModules).toEqual(['navigation']);
				expect(typeof mockComponent.generateRecordPageURL).toBe('function');
			});
		});

		describe('notification', () =>
		{
			it('should initialize notification module', () =>
			{
				activateModules(mockComponent, ['notification']);

				expect(initialisedModules).toEqual(['notification']);
				expect(typeof mockComponent.showSuccessToast).toBe('function');
			});
		});

		describe('lightning-message', () =>
		{
			it('should initialize lightning message module', () =>
			{
				activateModules(mockComponent, ['lightning-message']);

				expect(initialisedModules).toEqual(['lightning-message']);
				expect(typeof mockComponent.publishLightningMessage).toBe('function');
			});
		});

		describe('controller', () =>
		{
			it('should initialize controller module', () =>
			{
				activateModules(mockComponent, ['controller']);

				expect(initialisedModules).toEqual(['controller']);
				expect(typeof mockComponent.handleWireResponse).toBe('function');
			});
		});

		describe('flow-navigation', () =>
		{
			it('should initialize flow navigation module', () =>
			{
				activateModules(mockComponent, ['flow-navigation']);

				expect(initialisedModules).toEqual(['flow-navigation']);
				expect(typeof mockComponent.dispatchFlowFinishEvent).toBe('function');
			});
		});

		describe('all', () =>
		{
			it('should initialize all modules', () =>
			{
				activateModules(mockComponent, ['all']);

				expect(countEachModule(initialisedModules)).toEqual(EACH_MODULE_ONCE);
			});

			it('should initialize modules in registration order', () =>
			{
				activateModules(mockComponent, ['all']);

				expect(initialisedModules).toEqual([
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

				expect(initialisedModules).toEqual([
					'notification',
					'controller'
				]);
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

				expect(countEachModule(initialisedModules)).toEqual(EACH_MODULE_ONCE);
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

				expect(initialisedModules).toEqual([]);
			});
		});
	});
});
