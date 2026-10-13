// SPDX-License-Identifier: BUSL-1.1
const path = require('path');

const AUTH_ROOT = path.join(__dirname, '..', 'e2e', '.auth');

describe('authPathsFor', () =>
{
	let originalAlias;

	beforeEach(() =>
	{
		jest.resetModules();
		originalAlias = process.env.SF_SUBSCRIBER_ORG_ALIAS;
	});

	afterEach(() =>
	{
		if(originalAlias === undefined)
		{
			delete process.env.SF_SUBSCRIBER_ORG_ALIAS;
		}
		else
		{
			process.env.SF_SUBSCRIBER_ORG_ALIAS = originalAlias;
		}
	});

	it('keeps the three session files in a folder named after the org alias', () =>
	{
		const {authPathsFor} = require('../e2e/helpers/auth-paths');

		expect(authPathsFor('KernUpgradeSubscriber')).toEqual({
			directory: path.join(AUTH_ROOT, 'KernUpgradeSubscriber'),
			statePath: path.join(AUTH_ROOT, 'KernUpgradeSubscriber', 'state.json'),
			instancePath: path.join(AUTH_ROOT, 'KernUpgradeSubscriber', 'instance.json'),
			runTargetPath: path.join(AUTH_ROOT, 'KernUpgradeSubscriber', 'run-target.json')
		});
	});

	it('gives two orgs two folders, so a run against one never reads the other run\'s session', () =>
	{
		const {authPathsFor} = require('../e2e/helpers/auth-paths');
		const upgraded = authPathsFor('KernUpgradeSubscriber');
		const fresh = authPathsFor('FreshSubscriber');

		expect(upgraded.directory).not.toBe(fresh.directory);
		expect(upgraded.statePath).not.toBe(fresh.statePath);
		expect(upgraded.instancePath).not.toBe(fresh.instancePath);
		expect(upgraded.runTargetPath).not.toBe(fresh.runTargetPath);
	});

	it('uses the run\'s own alias when none is given', () =>
	{
		process.env.SF_SUBSCRIBER_ORG_ALIAS = 'KernUpgradeSubscriber';
		const {authPathsFor} = require('../e2e/helpers/auth-paths');

		expect(authPathsFor().statePath).toBe(path.join(AUTH_ROOT, 'KernUpgradeSubscriber', 'state.json'));
	});

	it('keeps a username alias as it is, since its characters are safe in a folder name', () =>
	{
		const {authFolderName} = require('../e2e/helpers/auth-paths');

		expect(authFolderName('test-abc@example.com')).toBe('test-abc@example.com');
	});

	it('replaces path separators and spaces, so an alias can never name a folder outside the session root', () =>
	{
		const {authPathsFor} = require('../e2e/helpers/auth-paths');
		const {directory} = authPathsFor('../outside/my org');

		expect(path.dirname(directory)).toBe(AUTH_ROOT);
		expect(path.basename(directory)).toBe('.._outside_my_org');
	});

	it.each(['', '   ', '.', '..', null, undefined])('refuses the alias %p, which cannot name a folder of its own', (alias) =>
	{
		const {authFolderName} = require('../e2e/helpers/auth-paths');

		expect(() => authFolderName(alias)).toThrow('cannot name a folder for the session files');
	});
});
