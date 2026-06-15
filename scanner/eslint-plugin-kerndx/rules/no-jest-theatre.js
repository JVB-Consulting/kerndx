// SPDX-License-Identifier: MIT
/**
 * @fileoverview Forbid assertion-less Jest tests and hollow createElement assertions.
 * @description Jest tests must actually exercise behaviour. Two theatrical patterns are
 *              blocked:
 *
 *              1. Assertion-less tests - an `it(...)` or `test(...)` block whose body
 *                 contains zero `expect(...)` calls. These tests pass regardless of
 *                 behaviour and contribute coverage without any verification.
 *              2. Hollow createElement assertions - an `it(...)` block whose only
 *                 `expect(...)` call is `expect(element).toBeTruthy()` or
 *                 `expect(element).toBeDefined()` on a value returned by `createElement`.
 *                 This only verifies that `createElement` did not throw; it asserts
 *                 nothing about rendered state, dispatched events, or toast calls.
 *
 *              Only applies to files ending in `.test.js` or under `__tests__/`.
 *
 *              Suppress with: // eslint-disable-next-line kerndx/no-jest-theatre
 */

'use strict';

const path = require('path');

const TEST_FUNCTIONS = new Set([
	'it',
	'test'
]);
const HOLLOW_MATCHERS = new Set([
	'toBeTruthy',
	'toBeDefined'
]);

module.exports = {
	meta: {
		type: 'problem', docs: {
			description: 'Forbid assertion-less Jest tests and hollow createElement assertions', recommended: true
		}, messages: {
			noAssertions: 'Test "{{name}}" contains no expect(...) calls. Add assertions against rendered state, dispatched events, or toast calls.',
			hollowCreateElement: 'Test "{{name}}" only asserts that createElement returned a truthy/defined value. Assert on rendered DOM, dispatched events, or controller calls instead.'
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
				if(!isTestCall(node))
				{
					return;
				}

				const callbackArgument = node.arguments[1];

				if(!callbackArgument || !isFunctionLike(callbackArgument))
				{
					return;
				}

				const body = getBlockBody(callbackArgument);

				if(!body)
				{
					return;
				}

				const expectCalls = collectExpectCalls(body);
				const testName = describeTestName(node.arguments[0]);

				if(expectCalls.length === 0)
				{
					context.report({
						node, messageId: 'noAssertions', data: {name: testName}
					});
					return;
				}

				if(expectCalls.length === 1 && isHollowCreateElementAssertion(expectCalls[0], body))
				{
					context.report({
						node: expectCalls[0], messageId: 'hollowCreateElement', data: {name: testName}
					});
				}
			}
		};
	}
};

/**
 * @description Whether the file path targets a Jest test file.
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

	const parts = filename.split(path.sep);
	return parts.includes('__tests__');
}

/**
 * @description Whether the CallExpression is an `it(...)` or `test(...)` invocation
 *              (including `.only` / `.skip` chained modifiers).
 * @param {object} node AST node.
 * @return {boolean}
 */
function isTestCall(node)
{
	const callee = node.callee;

	if(callee.type === 'Identifier' && TEST_FUNCTIONS.has(callee.name))
	{
		return true;
	}

	if(callee.type === 'MemberExpression' && callee.object.type === 'Identifier' && TEST_FUNCTIONS.has(callee.object.name) && callee.property.type === 'Identifier')
	{
		return true;
	}

	return false;
}

/**
 * @description Whether the node is an arrow function or function expression.
 * @param {object} node AST node.
 * @return {boolean}
 */
function isFunctionLike(node)
{
	return node.type === 'ArrowFunctionExpression' || node.type === 'FunctionExpression';
}

/**
 * @description Returns the callback's body when it is a BlockStatement.
 * @param {object} node Function-like AST node.
 * @return {?object} BlockStatement body, or null when the callback is an expression-bodied arrow.
 */
function getBlockBody(node)
{
	if(node.body && node.body.type === 'BlockStatement')
	{
		return node.body;
	}

	return null;
}

/**
 * @description Walks a function body and returns all `expect(...)` CallExpression roots.
 *              The "root" is the outermost call that begins with `expect(` - e.g. for
 *              `expect(x).toBe(1)` the root is the whole chain, captured once.
 *              The walker only records the outermost chain by skipping descent when a
 *              match is found.
 * @param {object} block BlockStatement.
 * @return {Array<object>} CallExpression nodes rooted at `expect(...)`.
 */
function collectExpectCalls(block)
{
	const calls = [];

	walk(block, (node) =>
	{
		if(node.type === 'CallExpression' && isExpectChain(node))
		{
			calls.push(node);
			return false;
		}

		return true;
	});

	return calls;
}

/**
 * @description Whether a CallExpression's chain begins with `expect(` at its base.
 * @param {object} node CallExpression.
 * @return {boolean}
 */
function isExpectChain(node)
{
	let current = node;

	while(current)
	{
		if(current.type === 'CallExpression')
		{
			if(current.callee.type === 'Identifier' && current.callee.name === 'expect')
			{
				return true;
			}

			if(current.callee.type === 'MemberExpression')
			{
				current = current.callee.object;
				continue;
			}
		}

		if(current.type === 'MemberExpression')
		{
			current = current.object;
			continue;
		}

		return false;
	}

	return false;
}

/**
 * @description Whether an `expect(...)` chain is a hollow createElement assertion:
 *              `expect(createElement(...)).toBeTruthy()` or `.toBeDefined()`, optionally
 *              against a variable bound to `createElement(...)` earlier in the block.
 * @param {object} node CallExpression rooted at `expect`.
 * @param {object} body The enclosing BlockStatement (the it/test callback body).
 * @return {boolean}
 */
function isHollowCreateElementAssertion(node, body)
{
	if(node.callee.type !== 'MemberExpression')
	{
		return false;
	}

	if(node.callee.property.type !== 'Identifier' || !HOLLOW_MATCHERS.has(node.callee.property.name))
	{
		return false;
	}

	const expectCall = node.callee.object;

	if(expectCall.type !== 'CallExpression' || expectCall.callee.type !== 'Identifier' || expectCall.callee.name !== 'expect' || expectCall.arguments.length === 0)
	{
		return false;
	}

	const argument = expectCall.arguments[0];

	if(isCreateElementCall(argument))
	{
		return true;
	}

	if(argument.type === 'Identifier' && identifierBoundToCreateElement(argument.name, body))
	{
		return true;
	}

	return false;
}

/**
 * @description Whether a node is a direct `createElement(...)` CallExpression.
 * @param {object} node AST node.
 * @return {boolean}
 */
function isCreateElementCall(node)
{
	return (node.type === 'CallExpression' && node.callee.type === 'Identifier' && node.callee.name === 'createElement');
}

/**
 * @description Whether an identifier name is bound to a `createElement(...)` call in the
 *              enclosing BlockStatement. Covered patterns:
 *              `const element = createElement(...);` inside the same `it` block.
 * @param {string} name Identifier name being referenced.
 * @param {object} body BlockStatement enclosing the reference.
 * @return {boolean}
 */
function identifierBoundToCreateElement(name, body)
{
	if(!body || body.type !== 'BlockStatement')
	{
		return false;
	}

	return findCreateElementBinding(body, name);
}

/**
 * @description Searches a block's body for `const name = createElement(...)`.
 * @param {object} block BlockStatement or Program.
 * @param {string} name Identifier name.
 * @return {boolean}
 */
function findCreateElementBinding(block, name)
{
	for(const statement of block.body)
	{
		if(statement.type !== 'VariableDeclaration')
		{
			continue;
		}

		for(const declarator of statement.declarations)
		{
			if(declarator.id.type === 'Identifier' && declarator.id.name === name && declarator.init && isCreateElementCall(declarator.init))
			{
				return true;
			}
		}
	}

	return false;
}

/**
 * @description Returns a human-readable label for the test name argument.
 * @param {?object} node AST node passed to `it(...)` as the first argument.
 * @return {string}
 */
function describeTestName(node)
{
	if(!node)
	{
		return '<unnamed>';
	}

	if(node.type === 'Literal' && typeof node.value === 'string')
	{
		return node.value;
	}

	if(node.type === 'TemplateLiteral' && node.quasis.length === 1)
	{
		return node.quasis[0].value.cooked;
	}

	return '<dynamic>';
}

/**
 * @description Depth-first walker that invokes a visitor on each descendant. Does NOT
 *              mutate AST nodes (e.g. does not attach `.parent`) because ESLint manages
 *              parent pointers globally and other rules may crash if they see an
 *              overwritten or stale `.parent`.
 * @param {object} root AST root to walk.
 * @param {Function} visit Visitor receiving each node. Return false to skip descent.
 */
function walk(root, visit)
{
	if(!root || typeof root.type !== 'string')
	{
		return;
	}

	const descend = visit(root);

	if(descend === false)
	{
		return;
	}

	for(const key of Object.keys(root))
	{
		if(key === 'parent')
		{
			continue;
		}

		const value = root[key];

		if(Array.isArray(value))
		{
			for(const child of value)
			{
				if(child && typeof child.type === 'string')
				{
					walk(child, visit);
				}
			}
		}
		else if(value && typeof value.type === 'string')
		{
			walk(value, visit);
		}
	}
}
