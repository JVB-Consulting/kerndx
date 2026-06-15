// SPDX-License-Identifier: MIT
'use strict';

const test = require('node:test');
const {RuleTester} = require('eslint');
const rule = require('../rules/no-console-log');

const ruleTester = new RuleTester({parserOptions: {ecmaVersion: 2022, sourceType: 'module'}});

test('no-console-log', () =>
{
	ruleTester.run('no-console-log', rule, {
		valid: [
			{
				code: 'this.consoleLog("message");', name: 'ComponentBuilder consoleLog is allowed'
			},
			{
				code: 'this.consoleError("error");', name: 'ComponentBuilder consoleError is allowed'
			},
			{
				code: 'logger.log("message");', name: 'non-console log method is allowed'
			},
			{
				code: 'myConsole.warn("message");', name: 'non-console object with warn method is allowed'
			},
			{
				code: 'console.table([1, 2, 3]);', name: 'console methods not in the blocked set are allowed'
			}
		],

		invalid: [
			{
				code: 'console.log("message");', name: 'bare console.log is caught', errors: [{messageId: 'noConsole', data: {method: 'log'}}]
			},
			{
				code: 'console.error("error");', name: 'bare console.error is caught', errors: [{messageId: 'noConsole', data: {method: 'error'}}]
			},
			{
				code: 'console.warn("warning");', name: 'bare console.warn is caught', errors: [{messageId: 'noConsole', data: {method: 'warn'}}]
			},
			{
				code: 'console.info("info");', name: 'bare console.info is caught', errors: [{messageId: 'noConsole', data: {method: 'info'}}]
			},
			{
				code: 'console.debug("debug");', name: 'bare console.debug is caught', errors: [{messageId: 'noConsole', data: {method: 'debug'}}]
			},
			{
				code: 'window.console.log("message");', name: 'window.console.log is caught', errors: [{messageId: 'noConsole', data: {method: 'log'}}]
			},
			{
				code: 'window.console.error("error");', name: 'window.console.error is caught', errors: [{messageId: 'noConsole', data: {method: 'error'}}]
			},
			{
				code: 'window.console.warn("warning");', name: 'window.console.warn is caught', errors: [{messageId: 'noConsole', data: {method: 'warn'}}]
			},
			{
				code: 'globalThis.console.log("message");', name: 'globalThis.console.log is caught', errors: [{messageId: 'noConsole', data: {method: 'log'}}]
			},
			{
				code: 'globalThis.console.error("error");', name: 'globalThis.console.error is caught', errors: [{messageId: 'noConsole', data: {method: 'error'}}]
			},
			{
				code: `
				function doWork() {
					console.log("first");
					window.console.warn("second");
					globalThis.console.error("third");
				}
			`, name: 'multiple violations in one function are all caught', errors: [
					{messageId: 'noConsole', data: {method: 'log'}},
					{messageId: 'noConsole', data: {method: 'warn'}},
					{messageId: 'noConsole', data: {method: 'error'}}
				]
			}
		]
	});
});
