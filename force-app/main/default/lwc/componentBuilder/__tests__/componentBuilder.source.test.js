// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for the REAL componentBuilder LWC module implementation.
 *
 *              This test file tests the actual source code of componentBuilder.js,
 *              NOT the mock used by other component tests.
 *
 *              Uses direct file path import to bypass the jest.config.js moduleNameMapper
 *              that redirects c/componentBuilder to the mock.
 *
 * @author Jason van Beukering
 * @date January 2026, May 2026
 */

// Mock the dependencies before importing the real componentBuilder
// Use direct paths to bypass moduleNameMapper for these too
jest.mock('../../baseComponent/baseComponent.js', () =>
{
	return {
		__esModule: true, default: class MockBaseComponent
		{
			functionality = [];
		}
	};
});

const mockActivateModules = jest.fn();
jest.mock('../../componentExtender/componentExtender.js', () =>
{
	return {
		__esModule: true, activateModules: mockActivateModules
	};
});

// Import using the real file path (not c/componentBuilder which gets mocked)
const {ComponentBuilder, ALL_MODULES, INVALID_INITIALISATION_ERROR} = require('../componentBuilder.js');

describe('componentBuilder source implementation', () =>
{
	beforeEach(() =>
	{
		jest.clearAllMocks();
	});

	describe('exports', () =>
	{
		it('exports ALL_MODULES constant as "all"', () =>
		{
			expect(ALL_MODULES).toBe('all');
		});

		it('exports INVALID_INITIALISATION_ERROR constant', () =>
		{
			expect(INVALID_INITIALISATION_ERROR).toBe('Verify that the module identifiers passed to ComponentBuilder are valid');
		});

		it('exports ComponentBuilder as a function', () =>
		{
			expect(typeof ComponentBuilder).toBe('function');
		});
	});

	describe('ComponentBuilder factory', () =>
	{
		it('returns a class constructor', () =>
		{
			const BuilderClass = ComponentBuilder('notification');

			expect(typeof BuilderClass).toBe('function');
			expect(BuilderClass.prototype).toBeDefined();
		});

		it('creates instance that calls activateModules', () =>
		{
			const BuilderClass = ComponentBuilder('notification');
			const instance = new BuilderClass();

			expect(mockActivateModules).toHaveBeenCalledWith(instance, ['notification']);
		});

		it('deduplicates functionality parameters using Set', () =>
		{
			const BuilderClass = ComponentBuilder('notification', 'notification', 'controller');
			const instance = new BuilderClass();

			expect(mockActivateModules).toHaveBeenCalledWith(instance, expect.arrayContaining([
				'notification',
				'controller'
			]));
			const calledFunctionality = mockActivateModules.mock.calls[0][1];
			expect(calledFunctionality.length).toBe(2);
		});

		it('handles ALL_MODULES by passing only ["all"]', () =>
		{
			const BuilderClass = ComponentBuilder(ALL_MODULES);
			const instance = new BuilderClass();

			expect(mockActivateModules).toHaveBeenCalledWith(instance, ['all']);
		});

		it('handles ALL_MODULES with other params by using only ["all"]', () =>
		{
			const BuilderClass = ComponentBuilder('notification', ALL_MODULES, 'controller');
			const instance = new BuilderClass();

			expect(mockActivateModules).toHaveBeenCalledWith(instance, ['all']);
		});

		it('handles empty functionality list', () =>
		{
			const BuilderClass = ComponentBuilder();
			const instance = new BuilderClass();

			expect(mockActivateModules).toHaveBeenCalledWith(instance, []);
		});

		it('sets functionality property on instance', () =>
		{
			const BuilderClass = ComponentBuilder('navigation', 'controller');
			const instance = new BuilderClass();

			expect(instance.functionality).toEqual(expect.arrayContaining([
				'navigation',
				'controller'
			]));
			expect(instance.functionality.length).toBe(2);
		});

		it('sets functionality to ["all"] when ALL_MODULES is included', () =>
		{
			const BuilderClass = ComponentBuilder(ALL_MODULES, 'notification');
			const instance = new BuilderClass();

			expect(instance.functionality).toEqual(['all']);
		});
	});
});
