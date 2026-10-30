// SPDX-License-Identifier: Apache-2.0
// Puts subscriber Apex from release-testing/subscriber/classes/ on an org that holds the framework with no
// namespace, by stripping the package namespace from a copy and deploying the copy as a metadata bundle. The two
// literals below are spelled in the forms bin/swap-namespace.js rewrites, so a swapped tree strips its own namespace.
const fs = require('fs');
const os = require('os');
const path = require('path');
const {deployMetadataDir} = require('../../runner/cmdt-deployer');

const SUBSCRIBER_CLASSES_DIRECTORY = path.join(__dirname, '..', '..', 'subscriber', 'classes');
const API_VERSION = '68.0';

/**
 * @description Removes the package namespace from subscriber Apex source.
 *
 * @param {string} source The class body as written for the installed package.
 *
 * @returns {string} The same body with `kern__` and `kern.` removed.
 */
function stripNamespace(source)
{
	return source.split('kern__').join('').split('kern.').join('');
}

/**
 * @description The package manifest for a bundle of Apex classes.
 *
 * @param {string[]} classNames The classes the bundle carries.
 *
 * @returns {string}
 */
function renderPackageManifest(classNames)
{
	const members = classNames.map((name) => `        <members>${name}</members>\n`).join('');
	return '<?xml version="1.0" encoding="UTF-8"?>\n<Package xmlns="http://soap.sforce.com/2006/04/metadata">\n    <types>\n'
			+ `${members}        <name>ApexClass</name>\n    </types>\n    <version>${API_VERSION}</version>\n</Package>\n`;
}

/**
 * @description Writes the stripped classes and their manifest into `bundleDirectory/metadata/`.
 *
 * @param {string[]} classNames The classes to stage, by name.
 * @param {string} bundleDirectory Where the bundle goes.
 * @param {object} [options] `sourceDirectory` (default the subscriber classes folder) and `strip` (default stripNamespace).
 *
 * @returns {string} The bundle directory.
 */
function stageStrippedClasses(classNames, bundleDirectory, {sourceDirectory = SUBSCRIBER_CLASSES_DIRECTORY, strip = stripNamespace} = {})
{
	const classesDirectory = path.join(bundleDirectory, 'metadata', 'classes');
	fs.mkdirSync(classesDirectory, {recursive: true});
	for(const className of classNames)
	{
		const source = fs.readFileSync(path.join(sourceDirectory, `${className}.cls`), 'utf8');
		fs.writeFileSync(path.join(classesDirectory, `${className}.cls`), strip(source), 'utf8');
		fs.copyFileSync(path.join(sourceDirectory, `${className}.cls-meta.xml`), path.join(classesDirectory, `${className}.cls-meta.xml`));
	}
	fs.writeFileSync(path.join(bundleDirectory, 'metadata', 'package.xml'), renderPackageManifest(classNames), 'utf8');
	return bundleDirectory;
}

/**
 * @description Deploys stripped copies of the named subscriber classes to the harness org.
 *
 * @param {string[]} classNames The classes, by name.
 * @param {object} [options] `alias`, the org to deploy to (default the org SF_SUBSCRIBER_ORG_ALIAS names), and `deploy`
 * (default deployMetadataDir), for tests.
 *
 * @returns {object} The deploy command's parsed answer.
 */
function deployStrippedSubscriberClasses(classNames, {alias, deploy = deployMetadataDir} = {})
{
	const bundleDirectory = fs.mkdtempSync(path.join(os.tmpdir(), 'stripped-subscriber-'));
	try
	{
		stageStrippedClasses(classNames, bundleDirectory);
		return deploy(bundleDirectory, alias);
	}
	finally
	{
		fs.rmSync(bundleDirectory, {recursive: true, force: true});
	}
}

module.exports = {SUBSCRIBER_CLASSES_DIRECTORY, stripNamespace, renderPackageManifest, stageStrippedClasses, deployStrippedSubscriberClasses};
