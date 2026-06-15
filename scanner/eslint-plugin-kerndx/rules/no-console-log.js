// SPDX-License-Identifier: MIT
/**
 * @fileoverview Enforce ComponentBuilder console methods instead of native console.
 * @description LWC components must use this.consoleLog() and this.consoleError() from
 *              ComponentBuilder instead of native console.log(), console.error(), etc.
 *
 *              Suppress with: // eslint-disable-next-line kerndx/no-console-log
 */

'use strict';

const CONSOLE_METHODS = new Set([
	'log',
	'error',
	'warn',
	'info',
	'debug'
]);

module.exports = {
	meta: {
		type: 'suggestion', docs: {
			description: 'Enforce ComponentBuilder console methods instead of native console', recommended: true
		}, messages: {
			noConsole: 'Use this.consoleLog() or this.consoleError() from ComponentBuilder instead of console.{{method}}().'
		}, schema: []
	},

	create(context)
	{
		function isConsoleObject(node)
		{
			if(node.type === 'Identifier' && node.name === 'console')
			{
				return true;
			}

			if(node.type === 'MemberExpression' && node.property.type === 'Identifier' && node.property.name === 'console' && node.object.type === 'Identifier' && (node.object.name
					=== 'window' || node.object.name === 'globalThis'))
			{
				return true;
			}

			return false;
		}

		return {
			CallExpression(node)
			{
				const callee = node.callee;

				if(callee.type === 'MemberExpression' && isConsoleObject(callee.object) && callee.property.type === 'Identifier' && CONSOLE_METHODS.has(callee.property.name))
				{
					context.report({
						node, messageId: 'noConsole', data: {method: callee.property.name}
					});
				}
			}
		};
	}
};
