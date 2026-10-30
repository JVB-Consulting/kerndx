// SPDX-License-Identifier: Apache-2.0
jest.mock('../e2e/helpers/sf-cli', () => ({soqlQuery: jest.fn()}));
const fs = require('fs');
const path = require('path');
const {fillNamespaceTokens, rewriteNamespaceLiterals} = require('../e2e/helpers/sf-namespace');

// Scripts that must keep a namespace literal to prove the namespaced package name themselves here, with the reason in
// their header comment (SAR-1). Empty today.
const ALLOWED_TO_KEEP_A_LITERAL = [];

describe('fillNamespaceTokens', () =>
{
	const template = '__APEX_NAMESPACE__UTIL_AsyncChain.newChain(\'x\'); __FIELD_NAMESPACE__Foobar__c row;';

	it('fills both tokens for a subscriber org', () =>
	{
		expect(fillNamespaceTokens(template, 'acme__')).toBe('acme.UTIL_AsyncChain.newChain(\'x\'); acme__Foobar__c row;');
	});

	it('empties both tokens for the development org', () =>
	{
		expect(fillNamespaceTokens(template, '')).toBe('UTIL_AsyncChain.newChain(\'x\'); Foobar__c row;');
	});
});

describe('rewriteNamespaceLiterals', () =>
{
	const script = 'kern.UTIL_AsyncChain.newChain(\'x\'); delete [SELECT Id FROM kern__Foobar__c]; // kern.Type in a comment';

	it('strips both literal forms for the development org', () =>
	{
		expect(rewriteNamespaceLiterals(script, '')).toBe('UTIL_AsyncChain.newChain(\'x\'); delete [SELECT Id FROM Foobar__c]; // Type in a comment');
	});

	it('leaves a script alone on an org under the same namespace', () =>
	{
		expect(rewriteNamespaceLiterals(script, 'kern__')).toBe(script);
	});

	it('moves a script to another namespace', () =>
	{
		expect(rewriteNamespaceLiterals(script, 'acme__')).toBe('acme.UTIL_AsyncChain.newChain(\'x\'); delete [SELECT Id FROM acme__Foobar__c]; // acme.Type in a comment');
	});
});

describe('every release-testing script survives the rewrite', () =>
{
	const scriptsDirectory = path.join(__dirname, '..', 'scripts');
	const scripts = fs.readdirSync(scriptsDirectory).filter((name) => name.endsWith('.apex') && !ALLOWED_TO_KEEP_A_LITERAL.includes(name));

	it.each(scripts)('%s carries no namespace literal after the rewrite', (name) =>
	{
		const rewritten = rewriteNamespaceLiterals(fs.readFileSync(path.join(scriptsDirectory, name), 'utf8'), '');
		expect(rewritten).not.toMatch(/kern__/);
		expect(rewritten).not.toMatch(/kern\./);
	});
});
