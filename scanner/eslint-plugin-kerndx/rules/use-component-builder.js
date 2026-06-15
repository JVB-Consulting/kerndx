// SPDX-License-Identifier: MIT
/**
 * @fileoverview Enforce ComponentBuilder usage instead of LightningElement in LWC.
 * @description LWC components must extend ComponentBuilder(...) instead of LightningElement
 *              directly. ComponentBuilder provides toast notifications, controller calls,
 *              navigation, and other framework features.
 *
 *              Suppress with: // eslint-disable-next-line kerndx/use-component-builder
 */

'use strict';

module.exports = {
	meta: {
		type: 'suggestion', docs: {
			description: 'Enforce ComponentBuilder usage instead of LightningElement', recommended: true
		}, messages: {
			useCB: 'LWC components must extend ComponentBuilder(...) instead of LightningElement. Import {ComponentBuilder} from \'c/componentBuilder\'.'
		}, schema: []
	},

	create(context)
	{
		const lightningElementAliases = new Set(['LightningElement']);

		return {
			ImportDeclaration(node)
			{
				if(node.source.value !== 'lwc')
				{
					return;
				}

				for(const specifier of node.specifiers)
				{
					if(specifier.type === 'ImportSpecifier' && specifier.imported.name === 'LightningElement' && specifier.local.name !== 'LightningElement')
					{
						lightningElementAliases.add(specifier.local.name);
					}
				}
			},

			ClassDeclaration(node)
			{
				if(!node.superClass)
				{
					return;
				}

				const superClass = node.superClass;

				if(superClass.type === 'Identifier' && lightningElementAliases.has(superClass.name))
				{
					context.report({node: superClass, messageId: 'useCB'});
				}
			}
		};
	}
};
