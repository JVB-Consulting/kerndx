// SPDX-License-Identifier: BUSL-1.1
const fs = require('fs');
const os = require('os');
const path = require('path');
const {stripNamespace, renderPackageManifest, stageStrippedClasses, deployStrippedSubscriberClasses} = require('../e2e/helpers/subscriber-deploy');

describe('stripNamespace', () =>
{
	it('removes the package prefix from types and fields and leaves the rest', () =>
	{
		const source = 'public class X extends kern.UTIL_AsyncChain.ChainStep { kern__Foobar__c row; String name = \'kernel.\'; }';
		expect(stripNamespace(source)).toBe('public class X extends UTIL_AsyncChain.ChainStep { Foobar__c row; String name = \'kernel.\'; }');
	});
});

describe('stageStrippedClasses', () =>
{
	let sourceDirectory;
	let bundleDirectory;
	beforeEach(() =>
	{
		sourceDirectory = fs.mkdtempSync(path.join(os.tmpdir(), 'source-'));
		bundleDirectory = fs.mkdtempSync(path.join(os.tmpdir(), 'bundle-'));
		fs.writeFileSync(path.join(sourceDirectory, 'Steps.cls'), 'public class Steps { kern__Foobar__c row; }');
		fs.writeFileSync(path.join(sourceDirectory, 'Steps.cls-meta.xml'), '<ApexClass/>');
	});
	afterEach(() =>
	{
		fs.rmSync(sourceDirectory, {recursive: true, force: true});
		fs.rmSync(bundleDirectory, {recursive: true, force: true});
	});

	it('writes the stripped class, its meta file and a manifest naming it', () =>
	{
		stageStrippedClasses(['Steps'], bundleDirectory, {sourceDirectory});
		expect(fs.readFileSync(path.join(bundleDirectory, 'metadata', 'classes', 'Steps.cls'), 'utf8')).toBe('public class Steps { Foobar__c row; }');
		expect(fs.existsSync(path.join(bundleDirectory, 'metadata', 'classes', 'Steps.cls-meta.xml'))).toBe(true);
		expect(fs.readFileSync(path.join(bundleDirectory, 'metadata', 'package.xml'), 'utf8')).toBe(renderPackageManifest(['Steps']));
	});

	it('deploys a staged bundle and removes it afterwards', () =>
	{
		let stagedDirectory;
		const deploy = jest.fn((directory) =>
		{
			stagedDirectory = directory;
			expect(fs.existsSync(path.join(directory, 'metadata', 'package.xml'))).toBe(true);
			expect(fs.existsSync(path.join(directory, 'metadata', 'classes', 'SubscriberChainSteps.cls'))).toBe(true);
			return {status: 0};
		});
		expect(deployStrippedSubscriberClasses(['SubscriberChainSteps'], {deploy})).toEqual({status: 0});
		expect(deploy).toHaveBeenCalledTimes(1);
		expect(fs.existsSync(stagedDirectory)).toBe(false);
	});

	it('deploys to the org it is given, and to the environment variable\'s org when it is given none', () =>
	{
		const deploy = jest.fn(() => ({status: 0}));
		deployStrippedSubscriberClasses(['SubscriberChainSteps'], {deploy, alias: 'MyDevelopmentOrg'});
		deployStrippedSubscriberClasses(['SubscriberChainSteps'], {deploy});
		expect(deploy.mock.calls[0][1]).toBe('MyDevelopmentOrg');
		expect(deploy.mock.calls[1][1]).toBeUndefined();
	});

	it('removes the bundle when staging fails and never deploys', () =>
	{
		const deploy = jest.fn();
		expect(() => deployStrippedSubscriberClasses(['Missing'], {deploy})).toThrow(/ENOENT/);
		expect(deploy).not.toHaveBeenCalled();
	});
});
