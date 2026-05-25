// SPDX-License-Identifier: MIT
'use strict';

const test = require('node:test');
const {RuleTester} = require('eslint');
const rule = require('../rules/no-mutating-shared-fixture');

const TEST_FILENAME = '/project/force-app/main/default/lwc/ordReturnWizard/__tests__/ordReturnWizard.test.js';

const ruleTester = new RuleTester({parserOptions: {ecmaVersion: 2022, sourceType: 'module'}});

test('no-mutating-shared-fixture', () => {
	ruleTester.run('no-mutating-shared-fixture', rule, {
		valid: [
			{
				code: `
					describe('pure read-only tests', () => {
						let element;
						beforeAll(() => {
							element = createElement('c-x', {is: X});
							document.body.appendChild(element);
						});
						it('renders title', () => {
							expect(element.shadowRoot.querySelector('h1').textContent).toBe('Hello');
						});
						it('renders subtitle', () => {
							expect(element.shadowRoot.querySelector('h2').textContent).toBe('World');
						});
					});
				`,
				filename: TEST_FILENAME,
				name: 'beforeAll with read-only tests is allowed'
			},
			{
				code: `
					describe('rebuilds per test', () => {
						let element;
						beforeEach(() => {
							element = createElement('c-x', {is: X});
							document.body.appendChild(element);
						});
						it('dispatches save', () => {
							element.dispatchEvent(new CustomEvent('save'));
							expect(handler).toHaveBeenCalled();
						});
					});
				`,
				filename: TEST_FILENAME,
				name: 'beforeEach with mutating tests is allowed'
			},
			{
				code: `
					describe('beforeAll without createElement is fine', () => {
						beforeAll(() => {
							jest.spyOn(window, 'fetch');
						});
						it('mutates', () => {
							element.dispatchEvent(new CustomEvent('save'));
							expect(true).toBe(true);
						});
					});
				`,
				filename: TEST_FILENAME,
				name: 'beforeAll without createElement is allowed even when a test mutates'
			},
			{
				code: `
					describe('shared but no mutations', () => {
						beforeAll(() => {
							const element = createElement('c-x', {is: X});
							document.body.appendChild(element);
						});
						it('asserts', () => {
							expect(1).toBe(1);
						});
					});
				`,
				filename: TEST_FILENAME,
				name: 'beforeAll with createElement but no mutating tests is allowed'
			},
			{
				code: `
					describe('not a test file', () => {
						beforeAll(() => {
							element = createElement('c-x', {is: X});
						});
						it('mutates', () => {
							element.click();
						});
					});
				`,
				filename: '/project/scripts/helpers.js',
				name: 'non-test files are skipped'
			},
			{
				code: `
					doSomething('<input>');
				`,
				filename: '<input>',
				name: 'virtual <input> filename is skipped'
			},
			{
				code: `
					describe('no callback');
				`,
				filename: TEST_FILENAME,
				name: 'describe with no callback is skipped'
			},
			{
				code: `
					describe('string callback', 'not a function');
				`,
				filename: TEST_FILENAME,
				name: 'describe with non-function callback is skipped'
			},
			{
				code: `
					describe('arrow expression body', () => doWork());
				`,
				filename: TEST_FILENAME,
				name: 'describe with expression-bodied arrow is skipped'
			},
			{
				code: `
					describe.only('subscript', () => {
						beforeAll(() => {
							element = createElement('c-x', {is: X});
						});
						it('mutates via bracket access', () => {
							element['value'] = 'bracket';
						});
					});
				`,
				filename: TEST_FILENAME,
				name: 'bracket-property assignment is not treated as mutation'
			},
			{
				code: `
					describe('top-level non-call statement', () => {
						const helper = 1;
						beforeAll('not a callback');
						notACall;
						it('mutates', () => {
							element.dispatchEvent(new CustomEvent('x'));
						});
					});
				`,
				filename: TEST_FILENAME,
				name: 'non-call top-level statements are ignored'
			},
			{
				code: `
					describe('beforeAll without function arg', () => {
						beforeAll('string instead of callback');
						it('mutates', () => {
							element.click();
						});
					});
				`,
				filename: TEST_FILENAME,
				name: 'beforeAll without function callback is skipped'
			},
			{
				code: `
					describe('it without function arg', () => {
						beforeAll(() => {
							element = createElement('c-x', {is: X});
						});
						it('no callback here');
						other(() => {});
					});
				`,
				filename: TEST_FILENAME,
				name: 'it without function callback prevents mutation detection'
			},
			{
				code: `
					describe('dispatched via simple local', () => {
						beforeAll(() => {
							element = createElement('c-x', {is: X});
						});
						it('calls a local function only', () => {
							const localFunction = () => 1;
							const value = localFunction();
							expect(value).toBe(1);
						});
					});
				`,
				filename: TEST_FILENAME,
				name: 'pure function calls do not constitute mutation'
			},
			{
				code: `
					describe('local identifier assignment is not mutation', () => {
						beforeAll(() => {
							element = createElement('c-x', {is: X});
						});
						it('reassigns a local', () => {
							let local = 1;
							local = 2;
							expect(local).toBe(2);
						});
					});
				`,
				filename: TEST_FILENAME,
				name: 'assignment to plain identifier is not treated as mutation'
			}
		],

		invalid: [
			{
				code: `
					describe('dispatchEvent shared fixture', () => {
						let element;
						beforeAll(() => {
							element = createElement('c-x', {is: X});
							document.body.appendChild(element);
						});
						it('dispatches', () => {
							element.dispatchEvent(new CustomEvent('save'));
							expect(handler).toHaveBeenCalled();
						});
					});
				`,
				filename: TEST_FILENAME,
				name: 'beforeAll with dispatchEvent test is flagged',
				errors: [{messageId: 'sharedFixture'}]
			},
			{
				code: `
					describe('click shared fixture', () => {
						let element;
						beforeAll(() => {
							element = createElement('c-x', {is: X});
						});
						it('clicks', () => {
							element.shadowRoot.querySelector('button').click();
							expect(handler).toHaveBeenCalled();
						});
					});
				`,
				filename: TEST_FILENAME,
				name: 'querySelector().click() test is flagged',
				errors: [{messageId: 'sharedFixture'}]
			},
			{
				code: `
					describe('api setter shared fixture', () => {
						let element;
						beforeAll(() => {
							element = createElement('c-x', {is: X});
						});
						it('sets api prop', () => {
							element.value = 'new value';
							expect(element.value).toBe('new value');
						});
					});
				`,
				filename: TEST_FILENAME,
				name: 'public-api setter mutation is flagged',
				errors: [{messageId: 'sharedFixture'}]
			},
			{
				code: `
					describe('test() variant', () => {
						let element;
						beforeAll(() => {
							element = createElement('c-x', {is: X});
						});
						test('mutates', () => {
							element.dispatchEvent(new CustomEvent('save'));
						});
					});
				`,
				filename: TEST_FILENAME,
				name: 'test() alias with mutation is flagged',
				errors: [{messageId: 'sharedFixture'}]
			}
		]
	});
});
