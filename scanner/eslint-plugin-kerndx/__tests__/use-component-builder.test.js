// SPDX-License-Identifier: MIT
'use strict';

const test = require('node:test');
const {RuleTester} = require('eslint');
const rule = require('../rules/use-component-builder');

const ruleTester = new RuleTester({parserOptions: {ecmaVersion: 2022, sourceType: 'module'}});

test('use-component-builder', () => {
	ruleTester.run('use-component-builder', rule, {
		valid: [
			{
				code: `
					import {ComponentBuilder} from 'c/componentBuilder';
					export default class MyComponent extends ComponentBuilder('notification') {}
				`,
				name: 'ComponentBuilder with module is allowed'
			},
			{
				code: `
					import {ComponentBuilder} from 'c/componentBuilder';
					export default class MyComponent extends ComponentBuilder('notification', 'controller') {}
				`,
				name: 'ComponentBuilder with multiple modules is allowed'
			},
			{
				code: 'class MyHelper {}',
				name: 'class without superclass is allowed'
			},
			{
				code: 'class MyChild extends MyParent {}',
				name: 'class extending non-LightningElement is allowed'
			},
			{
				code: `
					import {SomeElement} from 'some-framework';
					class MyComponent extends SomeElement {}
				`,
				name: 'class extending non-lwc import is allowed'
			}
		],

		invalid: [
			{
				code: `
					import {LightningElement} from 'lwc';
					export default class MyComponent extends LightningElement {}
				`,
				name: 'direct LightningElement extension is caught',
				errors: [{messageId: 'useCB'}]
			},
			{
				code: `
					import {LightningElement, api} from 'lwc';
					export default class MyComponent extends LightningElement {}
				`,
				name: 'LightningElement with other named imports is caught',
				errors: [{messageId: 'useCB'}]
			},
			{
				code: `
					import {LightningElement as BaseElement} from 'lwc';
					export default class MyComponent extends BaseElement {}
				`,
				name: 'aliased LightningElement import is caught',
				errors: [{messageId: 'useCB'}]
			},
			{
				code: `
					import {LightningElement as LE} from 'lwc';
					export default class MyComponent extends LE {}
				`,
				name: 'short alias of LightningElement is caught',
				errors: [{messageId: 'useCB'}]
			},
			{
				code: `
					import {LightningElement as Base, api} from 'lwc';
					export default class MyComponent extends Base {}
				`,
				name: 'aliased LightningElement with other named imports is caught',
				errors: [{messageId: 'useCB'}]
			}
		]
	});
});
