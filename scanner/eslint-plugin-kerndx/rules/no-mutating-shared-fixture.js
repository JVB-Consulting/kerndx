// SPDX-License-Identifier: MIT
/**
 * @fileoverview Forbid mutation of a shared `beforeAll(...)` fixture across `it(...)` blocks.
 * @description A `describe(...)` block that creates its DOM fixture via `beforeAll` with
 *              `createElement(...)` and then has any `it(...)` that mutates the element
 *              (via `dispatchEvent`, `.click()`, public-API setter assignment, or
 *              `querySelector(...).click()`) is order-dependent: each test inherits the
 *              previous test's mutations.
 *
 *              Fix: downgrade `beforeAll` -> `beforeEach` so each test rebuilds the
 *              fixture, or move the `createElement(...)` into the mutating `it(...)`
 *              block itself.
 *
 *              Only applies to files ending in `.test.js` or under `__tests__/`.
 *
 *              Suppress with: // eslint-disable-next-line kerndx/no-mutating-shared-fixture
 */

'use strict';

const path = require('path');

const MUTATING_METHODS = new Set([
	'dispatchEvent',
	'click'
]);

module.exports = {
	meta: {
		type: 'problem', docs: {
			description: 'Forbid mutation of a shared beforeAll(...) fixture across tests', recommended: true
		}, messages: {
			sharedFixture: 'beforeAll(...) builds a createElement fixture that is mutated by later it(...) blocks. Use beforeEach(...) or move createElement into the mutating test.'
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
				if(!isDescribeCall(node))
				{
					return;
				}

				const describeBody = getDescribeBody(node);

				if(!describeBody)
				{
					return;
				}

				const beforeAll = findBeforeAllWithCreateElement(describeBody);

				if(!beforeAll)
				{
					return;
				}

				const mutatingTest = findMutatingTest(describeBody);

				if(!mutatingTest)
				{
					return;
				}

				context.report({
					node: beforeAll, messageId: 'sharedFixture'
				});
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
 * @description Whether the CallExpression is a `describe(...)` invocation (including
 *              `.only` / `.skip` modifiers).
 * @param {object} node CallExpression.
 * @return {boolean}
 */
function isDescribeCall(node)
{
	const callee = node.callee;

	if(callee.type === 'Identifier' && callee.name === 'describe')
	{
		return true;
	}

	if(callee.type === 'MemberExpression' && callee.object.type === 'Identifier' && callee.object.name === 'describe')
	{
		return true;
	}

	return false;
}

/**
 * @description Returns the BlockStatement body of the `describe` callback when present.
 * @param {object} node describe() CallExpression.
 * @return {?object}
 */
function getDescribeBody(node)
{
	const callback = node.arguments[1];

	if(!callback)
	{
		return null;
	}

	if(callback.type !== 'ArrowFunctionExpression' && callback.type !== 'FunctionExpression')
	{
		return null;
	}

	if(!callback.body || callback.body.type !== 'BlockStatement')
	{
		return null;
	}

	return callback.body;
}

/**
 * @description Scans top-level statements of the describe body for a `beforeAll(...)`
 *              whose callback calls `createElement(...)` at least once.
 * @param {object} describeBody BlockStatement.
 * @return {?object} The beforeAll CallExpression, or null.
 */
function findBeforeAllWithCreateElement(describeBody)
{
	for(const statement of describeBody.body)
	{
		if(statement.type !== 'ExpressionStatement')
		{
			continue;
		}

		const expression = statement.expression;

		if(expression.type !== 'CallExpression')
		{
			continue;
		}

		if(expression.callee.type !== 'Identifier' || expression.callee.name !== 'beforeAll')
		{
			continue;
		}

		const callback = expression.arguments[0];

		if(!callback || (callback.type !== 'ArrowFunctionExpression' && callback.type !== 'FunctionExpression'))
		{
			continue;
		}

		if(containsCreateElement(callback.body))
		{
			return expression;
		}
	}

	return null;
}

/**
 * @description Whether any descendant of a subtree is a `createElement(...)` call.
 * @param {object} subtree AST node.
 * @return {boolean}
 */
function containsCreateElement(subtree)
{
	let found = false;

	walk(subtree, (node) =>
	{
		if(node.type === 'CallExpression' && node.callee.type === 'Identifier' && node.callee.name === 'createElement')
		{
			found = true;
			return false;
		}

		return true;
	});

	return found;
}

/**
 * @description Scans top-level statements of the describe body for an `it(...)` /
 *              `test(...)` whose callback contains a mutating expression.
 * @param {object} describeBody BlockStatement.
 * @return {?object}
 */
function findMutatingTest(describeBody)
{
	for(const statement of describeBody.body)
	{
		if(statement.type !== 'ExpressionStatement')
		{
			continue;
		}

		const expression = statement.expression;

		if(expression.type !== 'CallExpression')
		{
			continue;
		}

		const callee = expression.callee;
		const calleeName = callee.type === 'Identifier' ? callee.name : (callee.type === 'MemberExpression' && callee.object.type === 'Identifier' ? callee.object.name : null);

		if(calleeName !== 'it' && calleeName !== 'test')
		{
			continue;
		}

		const callback = expression.arguments[1];

		if(!callback || (callback.type !== 'ArrowFunctionExpression' && callback.type !== 'FunctionExpression'))
		{
			continue;
		}

		if(callback.body && containsMutation(callback.body))
		{
			return expression;
		}
	}

	return null;
}

/**
 * @description Whether any descendant of a subtree mutates a DOM element or calls a
 *              mutating method. Covers:
 *                - `x.dispatchEvent(...)` / `x.click()`
 *                - `x.querySelector(...).click()`
 *                - Assignment to a MemberExpression whose property is a simple
 *                  identifier (public-api setter like `element.value = 'foo'`).
 * @param {object} subtree AST node.
 * @return {boolean}
 */
function containsMutation(subtree)
{
	let found = false;

	walk(subtree, (node) =>
	{
		if(found)
		{
			return false;
		}

		if(node.type === 'CallExpression' && isMutatingCall(node))
		{
			found = true;
			return false;
		}

		if(node.type === 'AssignmentExpression' && isMutatingAssignment(node))
		{
			found = true;
			return false;
		}

		return true;
	});

	return found;
}

/**
 * @description Whether a CallExpression is a DOM-mutating invocation.
 * @param {object} node CallExpression.
 * @return {boolean}
 */
function isMutatingCall(node)
{
	if(node.callee.type !== 'MemberExpression')
	{
		return false;
	}

	const property = node.callee.property;

	if(property.type !== 'Identifier')
	{
		return false;
	}

	return MUTATING_METHODS.has(property.name);
}

/**
 * @description Whether an assignment mutates a member expression (e.g. public-api setter).
 *              Excludes shorthand-assignment to local identifiers.
 * @param {object} node AssignmentExpression.
 * @return {boolean}
 */
function isMutatingAssignment(node)
{
	if(node.left.type !== 'MemberExpression')
	{
		return false;
	}

	if(node.left.property.type !== 'Identifier')
	{
		return false;
	}

	return true;
}

/**
 * @description Depth-first walker. Visitor returning false halts descent into that node.
 * @param {object} root AST root.
 * @param {Function} visit Visitor function.
 */
function walk(root, visit)
{
	const stack = [root];

	while(stack.length)
	{
		const node = stack.pop();

		if(!node || typeof node.type !== 'string')
		{
			continue;
		}

		const descend = visit(node);

		if(descend === false)
		{
			continue;
		}

		for(const key of Object.keys(node))
		{
			if(key === 'parent')
			{
				continue;
			}

			const value = node[key];

			if(Array.isArray(value))
			{
				for(const child of value)
				{
					if(child && typeof child.type === 'string')
					{
						stack.push(child);
					}
				}
			}
			else if(value && typeof value.type === 'string')
			{
				stack.push(value);
			}
		}
	}
}
