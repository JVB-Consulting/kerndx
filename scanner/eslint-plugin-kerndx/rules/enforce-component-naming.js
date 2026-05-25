// SPDX-License-Identifier: MIT
/**
 * @fileoverview Enforce LWC component folder naming: <domain>[<brand>]<Feature>.
 * @description LWC component folder names must match a configurable pattern of
 *              <domain>[<brand>]<Feature>. The allowed domain + brand vocab is
 *              supplied via rule options — there are no baked-in defaults,
 *              keeping the plugin subscriber-agnostic. The component name is
 *              derived from the file path.
 *
 *              Configure in eslint.config.mjs:
 *                'kerndx/enforce-component-naming': ['warn', {
 *                  domains: ['sls', 'svc', 'cmn'],   // required, lowercase
 *                  brands:  ['Acme', 'Beta'],        // optional, PascalCase
 *                  maxLength: 40                     // optional, default 40
 *                }]
 *
 *              When `domains` is empty or no options are passed, the rule is a
 *              no-op (no violations reported). Suppress per-file with:
 *                // eslint-disable-next-line kerndx/enforce-component-naming
 */

'use strict';

const path = require('path');

const DEFAULT_MAX_LENGTH = 40;

module.exports = {
	meta: {
		type: 'suggestion',
		docs: {
			description: 'Enforce LWC component folder naming pattern from configured domain/brand vocab',
			recommended: false
		},
		messages: {
			badName: 'LWC component "{{name}}" does not match the configured naming pattern {{pattern}}.',
			tooLong: 'LWC component "{{name}}" exceeds the {{limit}}-character limit ({{length}} characters).'
		},
		schema: [
			{
				type: 'object',
				properties: {
					domains: {
						type: 'array',
						items: { type: 'string', pattern: '^[a-z]+$' },
						minItems: 1,
						uniqueItems: true
					},
					brands: {
						type: 'array',
						items: { type: 'string', pattern: '^[A-Z][a-zA-Z0-9]*$' },
						uniqueItems: true
					},
					maxLength: {
						type: 'integer',
						minimum: 1
					}
				},
				required: ['domains'],
				additionalProperties: false
			}
		]
	},

	create(context)
	{
		const opts = context.options[0];

		// No options → no enforcement. Subscribers must opt in explicitly.
		if (!opts || !Array.isArray(opts.domains) || opts.domains.length === 0)
		{
			return {};
		}

		const domains = opts.domains;
		const brands = Array.isArray(opts.brands) ? opts.brands : [];
		const maxLength = typeof opts.maxLength === 'number' ? opts.maxLength : DEFAULT_MAX_LENGTH;

		const domainGroup = domains.join('|');
		const brandSegment = brands.length > 0 ? `(?:${brands.join('|')})?` : '';
		const pattern = new RegExp(`^(${domainGroup})${brandSegment}[A-Z][a-zA-Z0-9]*$`);
		const patternDoc = `^(${domainGroup})${brandSegment}[A-Z][a-zA-Z0-9]*$`;

		let reported = false;

		function getComponentName()
		{
			const filePath = context.getFilename();
			const parts = filePath.split(path.sep);
			const lwcIndex = parts.lastIndexOf('lwc');

			if (lwcIndex === -1 || lwcIndex >= parts.length - 1)
			{
				return null;
			}

			return parts[lwcIndex + 1];
		}

		return {
			Program(node)
			{
				if (reported)
				{
					return;
				}

				const componentName = getComponentName();

				if (!componentName)
				{
					return;
				}

				if (componentName.startsWith('__'))
				{
					return;
				}

				if (!pattern.test(componentName))
				{
					reported = true;
					context.report({
						node,
						messageId: 'badName',
						data: { name: componentName, pattern: patternDoc }
					});
					return;
				}

				if (componentName.length > maxLength)
				{
					reported = true;
					context.report({
						node,
						messageId: 'tooLong',
						data: { name: componentName, length: componentName.length, limit: maxLength }
					});
				}
			}
		};
	}
};
