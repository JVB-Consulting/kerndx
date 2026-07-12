// SPDX-License-Identifier: MIT
/**
 * @fileoverview Flag hardcoded subscriber-visible text in LWC JavaScript.
 * @description All user-facing message text must come from Custom Labels
 *              (`import X from '@salesforce/label/c.X'`), never string literals —
 *              a hardcoded string cannot be translated or overridden in a
 *              managed-package subscriber org (CLAUDE.md "Client-Facing Text").
 *
 *              Two detectors:
 *                1. Display SINKS (high precision): string literals passed to a
 *                   toast method (this.showErrorToast / showSuccessToast / …),
 *                   the `title`/`message` of a `new ShowToastEvent({…})`, or the
 *                   message of a `throw new Error(…)` / `…Exception(…)`. Literals
 *                   inside `a || 'fallback'` and `cond ? 'a' : 'b'` are unwrapped.
 *                2. Display-text HEURISTIC (broad regression net): a multi-word
 *                   string literal that is NOT a log/console/event argument, NOT
 *                   a DOM/format-token plumbing value, and NOT token-shaped
 *                   (icon `utility:x`, css `slds-…`, module `c/…`, date/number
 *                   format). This catches const/getter display strings that feed
 *                   an HTML `{binding}`. Single-word literals are ambiguous
 *                   (enum/variant/api name) and are left to the one-time sweep.
 *
 *              HTML templates and .js-meta.xml are covered by the companion
 *              scanner (scanner/scan-hardcoded-user-text.js), not this rule.
 *
 *              Escape hatch for a justified literal (API proper noun, format
 *              token, developer-only text):
 *                // eslint-disable-next-line kerndx/no-hardcoded-user-text
 */

'use strict';

const TOAST_METHODS = new Set([
	'showToast',
	'showErrorToast',
	'showSuccessToast',
	'showWarningToast',
	'showInfoToast',
	'notify'
]);

const TOAST_TEXT_PROPS = new Set([
	'title',
	'message'
]);

// Callees whose string arguments are never subscriber-visible copy.
const EXEMPT_METHODS = new Set([
	// logging
	'log',
	'warn',
	'error',
	'info',
	'debug',
	'consoleLog',
	'consoleError',
	'consoleWarn',
	'consoleInfo',
	'consoleDebug',
	// DOM / plumbing
	'setAttribute',
	'getAttribute',
	'removeAttribute',
	'hasAttribute',
	'querySelector',
	'querySelectorAll',
	'closest',
	'matches',
	'addEventListener',
	'removeEventListener',
	'dispatchEvent',
	'add',
	'remove',
	'toggle',
	'contains',
	'getItem',
	'setItem',
	'get',
	'set',
	'has',
	// string / json format tokens
	'replace',
	'replaceAll',
	'split',
	'startsWith',
	'endsWith',
	'includes',
	'parse',
	'stringify'
]);

// Objects that mark ANY method call on them as non-user-facing (logging sinks).
const EXEMPT_OBJECTS = new Set([
	'utilityLogger',
	'logger',
	'console',
	'Logger'
]);

// Property keys and assignment targets that hold plumbing, not display copy.
const PLUMBING_KEYS = new Set([
	'cssText',
	'style',
	'detail',
	'srcdoc',
	'innerHTML',
	'outerHTML',
	'textContent'
]);
const PLUMBING_MEMBERS = new Set([
	'innerHTML',
	'outerHTML',
	'textContent',
	'cssText',
	'className',
	'src',
	'href'
]);
const EQUALITY_OPERATORS = new Set([
	'===',
	'!==',
	'==',
	'!='
]);

function isErrorCtorName(name)
{
	return typeof name === 'string' && (name.endsWith('Error') || name.endsWith('Exception'));
}

// The literal value of a string Literal or a no-substitution template literal.
function stringValueOf(node)
{
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

// Collect display-bearing nodes reachable through `||`/`&&`/`??` and ternaries.
// Used only for display SINKS, so an interpolated template literal (`Saved ${n}`)
// counts — its static words are subscriber-visible and need formatTemplateString.
function collectStringNodes(node, acc)
{
	if(!node)
	{
		return acc;
	}

	if(stringValueOf(node) !== null)
	{
		acc.push(node);

		return acc;
	}

	if(node.type === 'TemplateLiteral' && node.quasis.some((quasi) => /[A-Za-z]/.test(quasi.value.cooked || '')))
	{
		acc.push(node);

		return acc;
	}

	if(node.type === 'LogicalExpression')
	{
		collectStringNodes(node.left, acc);
		collectStringNodes(node.right, acc);
	}
	else if(node.type === 'ConditionalExpression')
	{
		collectStringNodes(node.consequent, acc);
		collectStringNodes(node.alternate, acc);
	}

	return acc;
}

function keyName(key)
{
	if(key.type === 'Identifier')
	{
		return key.name;
	}

	if(key.type === 'Literal')
	{
		return String(key.value);
	}

	return null;
}

// A space-separated list of CSS class tokens (e.g. 'slds-modal slds-fade-in-open',
// 'dot d-DEBUG') — never display copy. Requires every token to be class-shaped and
// at least one to carry a class signal (a hyphen/underscore), so real prose without
// hyphens ('New Scheduled Job', 'Day of Month') is NOT excluded here.
function isClassList(value)
{
	const tokens = value.trim().split(/\s+/);

	if(tokens.length < 2 || !tokens.every((token) => /^[A-Za-z][A-Za-z0-9]*([-_]+[A-Za-z0-9]+)*$/.test(token)))
	{
		return false;
	}

	// A real class list either uses a framework prefix or is ALL hyphenated tokens.
	// Requiring more than "any one hyphen" keeps hyphenated display copy such as
	// 'Read-only mode' or 'Real-time updates' (a plain word plus a compound) flagged.
	return tokens.some((token) => /^(slds|c|lightning)-/.test(token)) || tokens.every((token) => /[-_]/.test(token));
}

// A multi-word string that reads as display copy, excluding token shapes.
function isDisplayLike(value)
{
	if(!/[A-Za-z]/.test(value))
	{
		return false;
	}

	// Needs whitespace between two non-space characters (i.e. more than one word).
	if(!/\S\s+\S/.test(value))
	{
		return false;
	}

	if(/^https?:\/\//i.test(value))
	{
		return false;
	}

	// Pure date/number/time format token: only format characters + separators.
	if(/[/:]/.test(value) && /^[\dMdDyYHhmsSaAZ\s:/.,'’\-]+$/.test(value))
	{
		return false;
	}

	return !isClassList(value);
}

module.exports = {
	meta: {
		type: 'problem', docs: {
			description: 'Flag hardcoded subscriber-visible text in LWC JavaScript; use Custom Labels instead', recommended: true
		}, messages: {
			hardcodedInSink: 'Hardcoded user-facing text in a {{sink}} argument — move it to a Custom Label (@salesforce/label/c.X).',
			hardcodedDisplayText: 'Hardcoded display text — move it to a Custom Label (@salesforce/label/c.X), or suppress with "// eslint-disable-next-line kerndx/no-hardcoded-user-text" if it is not subscriber-visible.'
		}, schema: []
	},

	create(context)
	{
		const reported = new Set();

		function reportSink(node, sink)
		{
			if(reported.has(node))
			{
				return;
			}

			reported.add(node);
			context.report({node, messageId: 'hardcodedInSink', data: {sink}});
		}

		// Describe the call/new a literal is an argument of, for exemption/sink checks.
		function describeCallee(callNode)
		{
			const callee = callNode.callee;
			let name = null;
			let object = null;

			if(callee.type === 'Identifier')
			{
				name = callee.name;
			}
			else if(callee.type === 'MemberExpression' && callee.property.type === 'Identifier')
			{
				name = callee.property.name;

				if(callee.object.type === 'Identifier')
				{
					object = callee.object.name;
				}
			}

			const isNew = callNode.type === 'NewExpression';
			const sink = (name !== null && TOAST_METHODS.has(name)) || (isNew && name === 'ShowToastEvent') || (isNew && isErrorCtorName(name));
			const exempt = (name !== null && EXEMPT_METHODS.has(name)) || (object !== null && EXEMPT_OBJECTS.has(object)) || (isNew && name === 'CustomEvent');

			return {sink, exempt};
		}

		// Climb through ||/&&/ternary wrappers to the structural node this literal feeds,
		// then decide whether that position is exempt (log/DOM call, sink, or a class value).
		function isExemptPosition(node)
		{
			let current = node;
			let parent = node.parent;

			while(parent && (parent.type === 'LogicalExpression' || parent.type === 'ConditionalExpression'))
			{
				current = parent;
				parent = parent.parent;
			}

			if(!parent)
			{
				return false;
			}

			if((parent.type === 'CallExpression' || parent.type === 'NewExpression') && parent.arguments.includes(current))
			{
				const callee = describeCallee(parent);

				return callee.exempt || callee.sink;
			}

			// `status === 'In Progress'` — comparison against a picklist/API value.
			if(parent.type === 'BinaryExpression' && EQUALITY_OPERATORS.has(parent.operator))
			{
				return true;
			}

			// A `*Class`/`className` or other plumbing property value is not display copy.
			if(parent.type === 'Property' && parent.value === current && !parent.computed)
			{
				const key = keyName(parent.key) || '';

				return /class/i.test(key) || PLUMBING_KEYS.has(key);
			}

			// `el.innerHTML = '…'` / `el.style.cssText = '…'` — DOM plumbing, not copy.
			if(parent.type === 'AssignmentExpression' && parent.right === current && parent.left.type === 'MemberExpression' && parent.left.property.type === 'Identifier'
					&& PLUMBING_MEMBERS.has(parent.left.property.name))
			{
				return true;
			}

			return false;
		}

		function checkHeuristic(node)
		{
			if(reported.has(node))
			{
				return;
			}

			const value = stringValueOf(node);

			if(value === null || !isDisplayLike(value))
			{
				return;
			}

			const parent = node.parent;

			if(parent && parent.type === 'Property' && parent.key === node && !parent.computed)
			{
				return;
			}

			if(parent && (parent.type === 'ImportDeclaration' || parent.type === 'ExportNamedDeclaration' || parent.type === 'ExportAllDeclaration') && parent.source === node)
			{
				return;
			}

			if(isExemptPosition(node))
			{
				return;
			}

			context.report({node, messageId: 'hardcodedDisplayText'});
		}

		return {
			CallExpression(node)
			{
				const callee = node.callee;

				if(callee.type === 'MemberExpression' && callee.property.type === 'Identifier' && TOAST_METHODS.has(callee.property.name))
				{
					for(const arg of node.arguments)
					{
						for(const stringNode of collectStringNodes(arg, []))
						{
							reportSink(stringNode, 'toast');
						}
					}
				}
			},

			NewExpression(node)
			{
				if(!(node.callee.type === 'Identifier' && node.callee.name === 'ShowToastEvent'))
				{
					return;
				}

				const objectArg = node.arguments[0];

				if(!objectArg || objectArg.type !== 'ObjectExpression')
				{
					return;
				}

				for(const property of objectArg.properties)
				{
					if(property.type === 'Property' && !property.computed && TOAST_TEXT_PROPS.has(keyName(property.key)))
					{
						for(const stringNode of collectStringNodes(property.value, []))
						{
							reportSink(stringNode, 'toast');
						}
					}
				}
			},

			ThrowStatement(node)
			{
				const argument = node.argument;

				if(argument && argument.type === 'NewExpression' && argument.callee.type === 'Identifier' && isErrorCtorName(argument.callee.name))
				{
					for(const stringNode of collectStringNodes(argument.arguments[0], []))
					{
						reportSink(stringNode, 'thrown error');
					}
				}
			},

			'Literal:exit'(node)
			{
				if(typeof node.value === 'string')
				{
					checkHeuristic(node);
				}
			},

			'TemplateLiteral:exit'(node)
			{
				if(node.expressions.length === 0)
				{
					checkHeuristic(node);
				}
			}
		};
	}
};
