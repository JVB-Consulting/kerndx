// SPDX-License-Identifier: MIT
/**
 * @fileoverview Forbid jest.mock(...) of a `c/` or `lightning/` module in Jest tests.
 * @description `jest.mock('c/<name>')` and `jest.mock('lightning/<name>')` are unreliable. Only the
 *              sfdx-lwc-jest resolver knows where these modules live. The mock is saved under the name
 *              as written, but once an earlier test file in the same Jest worker loads the real module,
 *              the component under test looks the module up by its full file path instead. The two names
 *              no longer match, so the mock stops replacing the module and nothing reports it. The test
 *              keeps passing while it checks a mock the code never calls. `{virtual: true}` does not fix it.
 *
 *              Safe patterns:
 *
 *              1. `jest.spyOn(...)` on the real object the test imports.
 *              2. Assert what the sfdx-lwc-jest stub received or dispatched.
 *              3. A `moduleNameMapper` entry in the Jest configuration that points at a mock file.
 *
 *              Relative paths, npm packages and `@salesforce/...` modules mock normally and are not reported.
 *
 *              Only applies to files ending in `.test.js` or under `__tests__/`.
 *
 *              Suppress with: // eslint-disable-next-line kerndx/no-jest-mock-component-module
 */

'use strict';

const UNRELIABLE_PREFIXES = [
	'c/',
	'lightning/'
];

module.exports = {
	meta: {
		type: 'problem', docs: {
			description: 'Forbid jest.mock(...) of c/ and lightning/ modules, which can silently stop replacing the module', recommended: true
		}, messages: {
			unreliableMock: 'jest.mock(\'{{specifier}}\') can silently stop replacing the module once another test file in the same Jest worker loads the real one. '
				+ 'Use jest.spyOn on the real imported object, assert what the sfdx-lwc-jest stub received, or map the module to a mock file with moduleNameMapper.'
		}, schema: []
	},

	create(context)
	{
		const filename = context.getFilename();

		if(!isTestFile(filename))
		{
			return {};
		}

		return {
			CallExpression(node)
			{
				if(!isJestMockCall(node))
				{
					return;
				}

				const specifier = readStaticString(node.arguments[0]);

				if(specifier === null || !hasUnreliablePrefix(specifier))
				{
					return;
				}

				context.report({
					node, messageId: 'unreliableMock', data: {specifier}
				});
			}
		};
	}
};

/**
 * @description Whether the file path targets a Jest test file. The path is split on both separators because ESLint
 *              can report either one on Windows.
 * @param {string} filename Absolute path reported by ESLint.
 * @return {boolean}
 */
function isTestFile(filename)
{
	if(!filename || filename === '<input>' || filename === '<text>')
	{
		return false;
	}

	if(filename.endsWith('.test.js'))
	{
		return true;
	}

	const parts = filename.split(/[\\/]/);
	return parts.includes('__tests__');
}

/**
 * @description Whether the CallExpression is a `jest.mock(...)` call.
 * @param {object} node CallExpression.
 * @return {boolean}
 */
function isJestMockCall(node)
{
	const callee = node.callee;

	if(callee.type !== 'MemberExpression' || callee.computed)
	{
		return false;
	}

	return callee.object.type === 'Identifier' && callee.object.name === 'jest' && callee.property.type === 'Identifier' && callee.property.name === 'mock';
}

/**
 * @description Returns the text of a string literal, or of a template literal with no `${...}` parts.
 * @param {?object} node First argument passed to `jest.mock(...)`.
 * @return {?string} The module name, or null when the argument is missing or built at run time.
 */
function readStaticString(node)
{
	if(!node)
	{
		return null;
	}

	if(node.type === 'Literal' && typeof node.value === 'string')
	{
		return node.value;
	}

	if(node.type === 'TemplateLiteral' && node.expressions.length === 0)
	{
		return node.quasis[0].value.cooked;
	}

	return null;
}

/**
 * @description Whether a module name starts with `c/` or `lightning/`.
 * @param {string} specifier Module name passed to `jest.mock(...)`.
 * @return {boolean}
 */
function hasUnreliablePrefix(specifier)
{
	return UNRELIABLE_PREFIXES.some((prefix) => specifier.startsWith(prefix));
}
