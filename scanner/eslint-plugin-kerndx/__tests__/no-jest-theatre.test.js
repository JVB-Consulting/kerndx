// SPDX-License-Identifier: MIT
'use strict';

const test = require('node:test');
const {RuleTester} = require('eslint');
const rule = require('../rules/no-jest-theatre');

const TEST_FILENAME = '/project/force-app/main/default/lwc/ordReturnWizard/__tests__/ordReturnWizard.test.js';

const ruleTester = new RuleTester({parserOptions: {ecmaVersion: 2022, sourceType: 'module'}});

test('no-jest-theatre', () => {
	ruleTester.run('no-jest-theatre', rule, {
		valid: [
			{
				code: `
					it('renders title', () => {
						const element = createElement('c-x', {is: X});
						document.body.appendChild(element);
						expect(element.shadowRoot.querySelector('h1').textContent).toBe('Hello');
					});
				`,
				filename: TEST_FILENAME,
				name: 'it() with rendered-state expect is allowed'
			},
			{
				code: `
					test('dispatches save event', () => {
						const element = createElement('c-x', {is: X});
						expect(element).toBeTruthy();
						element.dispatchEvent(new CustomEvent('save'));
						expect(handler).toHaveBeenCalled();
					});
				`,
				filename: TEST_FILENAME,
				name: 'hollow toBeTruthy plus a real assertion is allowed'
			},
			{
				code: `
					it('rejects invalid input', () => {
						expect(() => doWork(null)).toThrow();
					});
				`,
				filename: TEST_FILENAME,
				name: 'expect.toThrow counts as an assertion'
			},
			{
				code: `
					it('renders even when handler is redefined', () => {
						const element = createElement('c-x', {is: X});
						expect(element).toBeDefined();
						expect(element.shadowRoot).not.toBeNull();
					});
				`,
				filename: TEST_FILENAME,
				name: 'hollow toBeDefined plus a real assertion is allowed'
			},
			{
				code: `
					it('does nothing useful', () => {});
				`,
				filename: '/project/scripts/helpers.js',
				name: 'non-test files are skipped'
			},
			{
				code: `
					it.only('renders', () => {
						expect(wrapper.textContent).toBe('ok');
					});
				`,
				filename: TEST_FILENAME,
				name: 'it.only with a real expect is allowed'
			},
			{
				code: `
					it('arrow expression body skipped', () => doWork());
				`,
				filename: TEST_FILENAME,
				name: 'expression-bodied arrow callback is skipped'
			},
			{
				code: `
					it('no callback argument');
				`,
				filename: TEST_FILENAME,
				name: 'it() without a callback is skipped'
			},
			{
				code: `
					it('string callback argument', 'not a function');
				`,
				filename: TEST_FILENAME,
				name: 'non-function callback is skipped'
			},
			{
				code: `
					it('empty expect is ignored', () => {
						expect();
					});
				`,
				filename: TEST_FILENAME,
				name: 'expect() with zero arguments still counts as an assertion'
			},
			{
				code: `
					it('hollow-looking matcher on identifier not bound to createElement', () => {
						const unrelated = {};
						expect(unrelated).toBeTruthy();
					});
				`,
				filename: TEST_FILENAME,
				name: 'toBeTruthy on non-createElement identifier is allowed'
			},
			{
				code: `
					it('non-hollow matcher on createElement is fine', () => {
						expect(createElement('c-x', {is: X})).toBe(expected);
					});
				`,
				filename: TEST_FILENAME,
				name: 'non-hollow matcher on createElement is allowed'
			},
			{
				code: `
					it('member call not rooted at expect', () => {
						other(1).toBeTruthy();
						expect(value).toBe(1);
					});
				`,
				filename: TEST_FILENAME,
				name: 'non-expect member chains are ignored'
			},
			{
				code: `
					doSomething('<input>');
				`,
				filename: '<input>',
				name: 'ESLint virtual <input> filename is skipped'
			},
			{
				code: `
					notATest(() => {});
				`,
				filename: TEST_FILENAME,
				name: 'non-it/test call is ignored'
			},
			{
				code: `
					it('expect-like non-expect root', () => {
						const chain = foo().bar().baz;
						const ref = chain;
						expect(ref).toBe(1);
					});
				`,
				filename: TEST_FILENAME,
				name: 'chained member access on non-expect is ignored'
			},
			{
				code: `
					it('hollow matcher with zero-arg expect', () => {
						expect().toBeTruthy();
					});
				`,
				filename: TEST_FILENAME,
				name: 'zero-argument expect followed by hollow matcher is allowed'
			}
		],

		invalid: [
			{
				code: `
					it('does nothing', () => {
						const element = createElement('c-x', {is: X});
						document.body.appendChild(element);
					});
				`,
				filename: TEST_FILENAME,
				name: 'it() with no expect is flagged',
				errors: [{messageId: 'noAssertions', data: {name: 'does nothing'}}]
			},
			{
				code: `
					test('also nothing', function() {
						doSomething();
					});
				`,
				filename: TEST_FILENAME,
				name: 'test() with no expect is flagged',
				errors: [{messageId: 'noAssertions', data: {name: 'also nothing'}}]
			},
			{
				code: `
					it('hollow inline createElement', () => {
						expect(createElement('c-x', {is: X})).toBeTruthy();
					});
				`,
				filename: TEST_FILENAME,
				name: 'hollow expect(createElement).toBeTruthy is flagged',
				errors: [{messageId: 'hollowCreateElement', data: {name: 'hollow inline createElement'}}]
			},
			{
				code: `
					it('hollow bound createElement', () => {
						const element = createElement('c-x', {is: X});
						expect(element).toBeDefined();
					});
				`,
				filename: TEST_FILENAME,
				name: 'hollow expect(bound).toBeDefined is flagged',
				errors: [{messageId: 'hollowCreateElement', data: {name: 'hollow bound createElement'}}]
			},
			{
				code: `
					it.skip('skipped but still checked', () => {
						const element = createElement('c-x', {is: X});
					});
				`,
				filename: TEST_FILENAME,
				name: 'it.skip with no expect is flagged',
				errors: [{messageId: 'noAssertions', data: {name: 'skipped but still checked'}}]
			},
			{
				code: `
					test(\`template name\`, () => {});
				`,
				filename: TEST_FILENAME,
				name: 'template literal test name is flagged and labelled',
				errors: [{messageId: 'noAssertions', data: {name: 'template name'}}]
			},
			{
				code: `
					it(dynamicName, () => {});
				`,
				filename: TEST_FILENAME,
				name: 'dynamic test name falls back to <dynamic>',
				errors: [{messageId: 'noAssertions', data: {name: '<dynamic>'}}]
			},
			{
				code: `
					it('under __tests__ even without .test.js suffix', () => {});
				`,
				filename: '/project/force-app/main/default/lwc/ordReturnWizard/__tests__/helper.spec.js',
				name: '__tests__ directory files are scanned',
				errors: [{messageId: 'noAssertions'}]
			},
			{
				code: `
					it(undefined, () => {});
				`,
				filename: TEST_FILENAME,
				name: 'it() with identifier-undefined name falls through to <dynamic>',
				errors: [{messageId: 'noAssertions', data: {name: '<dynamic>'}}]
			}
		]
	});
});
