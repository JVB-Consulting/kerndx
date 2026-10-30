// SPDX-License-Identifier: MIT
'use strict';

const test = require('node:test');
const {RuleTester} = require('eslint');
const rule = require('../rules/no-jest-mock-component-module');

const TEST_FILENAME = '/project/force-app/main/default/lwc/ordReturnWizard/__tests__/ordReturnWizard.test.js';

const ruleTester = new RuleTester({parserOptions: {ecmaVersion: 2022, sourceType: 'module'}});

test('no-jest-mock-component-module', () =>
{
	ruleTester.run('no-jest-mock-component-module', rule, {
		valid: [
			{
				code: `
					jest.mock('../spinner.html');
				`, filename: TEST_FILENAME, name: 'a relative path is allowed'
			},
			{
				code: `
					jest.mock('lodash', () => ({debounce: jest.fn()}));
				`, filename: TEST_FILENAME, name: 'an npm package is allowed'
			},
			{
				code: `
					jest.mock('@salesforce/apex/ORD_Controller.getOrders', () => ({default: jest.fn()}), {virtual: true});
				`, filename: TEST_FILENAME, name: 'an @salesforce module is allowed'
			},
			{
				code: `
					jest.mock('@salesforce/label/c.SaveFailedMessage', () => ({default: 'Save failed'}), {virtual: true});
				`, filename: TEST_FILENAME, name: 'an @salesforce label whose name contains c. is allowed'
			},
			{
				code: `
					jest.mock(\`../helper.js\`);
				`, filename: TEST_FILENAME, name: 'a relative path in a template literal is allowed'
			},
			{
				code: `
					jest.mock(\`c/\${componentName}\`);
				`, filename: TEST_FILENAME, name: 'a template literal built at run time is skipped'
			},
			{
				code: `
					jest.mock(moduleName);
				`, filename: TEST_FILENAME, name: 'a module name held in a variable is skipped'
			},
			{
				code: `
					jest.mock();
				`, filename: TEST_FILENAME, name: 'jest.mock() with no argument is skipped'
			},
			{
				code: `
					jest.spyOn(toastService, 'showToast');
				`, filename: TEST_FILENAME, name: 'jest.spyOn on the real imported object is allowed'
			},
			{
				code: `
					jest.unmock('c/utilityLogger');
				`, filename: TEST_FILENAME, name: 'other jest methods are not reported'
			},
			{
				code: `
					other.mock('c/utilityLogger');
				`, filename: TEST_FILENAME, name: 'a mock method on another object is not reported'
			},
			{
				code: `
					jest['mock']('c/utilityLogger');
				`, filename: TEST_FILENAME, name: 'a computed property is not reported'
			},
			{
				code: `
					jest.mock('c/utilityLogger');
				`, filename: '/project/scripts/helpers.js', name: 'non-test files are skipped'
			}
		], invalid: [
			{
				code: `
					jest.mock('c/utilityLogger');
				`, filename: TEST_FILENAME, name: 'a c/ module is flagged', errors: [{messageId: 'unreliableMock', data: {specifier: 'c/utilityLogger'}}]
			},
			{
				code: `
					jest.mock("lightning/navigation");
				`,
				filename: TEST_FILENAME,
				name: 'a lightning/ module in double quotes is flagged',
				errors: [{messageId: 'unreliableMock', data: {specifier: 'lightning/navigation'}}]
			},
			{
				code: `
					jest.mock(\`c/toastService\`);
				`, filename: TEST_FILENAME, name: 'a template literal without expressions is flagged', errors: [{messageId: 'unreliableMock', data: {specifier: 'c/toastService'}}]
			},
			{
				code: `
					jest.mock('c/toastService', () => ({showToast: jest.fn()}));
				`, filename: TEST_FILENAME, name: 'a mock with a factory is flagged', errors: [{messageId: 'unreliableMock', data: {specifier: 'c/toastService'}}]
			},
			{
				code: `
					jest.mock('c/toastService', () => ({showToast: jest.fn()}), {virtual: true});
				`, filename: TEST_FILENAME, name: 'a virtual mock is still flagged', errors: [{messageId: 'unreliableMock', data: {specifier: 'c/toastService'}}]
			},
			{
				code: `
					jest.mock('lightning/platformShowToastEvent', () => ({ShowToastEvent: jest.fn()}), {virtual: true});
				`,
				filename: TEST_FILENAME,
				name: 'a virtual lightning/ mock with a factory is flagged',
				errors: [{messageId: 'unreliableMock', data: {specifier: 'lightning/platformShowToastEvent'}}]
			},
			{
				code: `
					jest.mock('c/utilityLogger');
				`,
				filename: '/project/force-app/main/default/lwc/ordReturnWizard/__tests__/helper.spec.js',
				name: '__tests__ directory files are scanned',
				errors: [{messageId: 'unreliableMock'}]
			},
			{
				code: `
					jest.mock('c/utilityLogger');
				`,
				filename: 'C:\\project\\force-app\\main\\default\\lwc\\ordReturnWizard\\__tests__\\helper.spec.js',
				name: '__tests__ directory files on a Windows path are scanned',
				errors: [{messageId: 'unreliableMock'}]
			},
			{
				code: `
					jest.mock('c/utilityLogger');
					jest.mock('lightning/navigation');
				`, filename: TEST_FILENAME, name: 'each unreliable mock in a file is reported', errors: [{messageId: 'unreliableMock'}, {messageId: 'unreliableMock'}]
			}
		]
	});
});
