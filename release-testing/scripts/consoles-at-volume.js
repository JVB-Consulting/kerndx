#!/usr/bin/env node
// SPDX-License-Identifier: Apache-2.0
// Loads an org for the consoles-at-volume proof: preflight, launch, drain, operate, verify, each a
// subcommand and each resumable from the manifest; `run` does the five in order; `teardown` is separate and optional.
//   SF_SUBSCRIBER_ORG_ALIAS=<your org alias> node release-testing/scripts/consoles-at-volume.js run --mode staged
'use strict';
const fs = require('fs');
const path = require('path');
const {getSubscriberOrgAlias} = require('../runner/subscriber-config');

// The variable the e2e helpers and the deploy helper read for the org; the driver sets it from --org.
const ORG_ALIAS_VARIABLE = 'SF_SUBSCRIBER_ORG_ALIAS';
const {parseCommandLine, USAGE} = require('./consoles-at-volume/command-line');
const {createOrgDoor} = require('./consoles-at-volume/org-door');
const {readManifest, writeManifest, isStageDone, assertSameRun, describeForeignManifest, describeManifest} = require('./consoles-at-volume/manifest');
const {scaleShape} = require('./consoles-at-volume/shapes');

const USAGE_EXIT_CODE = 2;
// A stage whose module is not named after it (the operate stage's module is operator-wave.js).
const STAGE_MODULES = {operate: 'operator-wave'};
const STAGE_ORDER = [
	'preflight',
	'launch',
	'drain',
	'operate',
	'verify'
];
const ALWAYS_RUN = [
	'verify',
	'teardown'
];

/**
 * @description The module of a stage or of teardown, loaded when asked for so a missing later stage fails only when used.
 *
 * @param {string} name The stage name.
 *
 * @returns {object} The module, with a `run(context)` function.
 */
function loadStage(name)
{
	// Required here, not at the top: some stage helpers read the org variable once, as they load, and pinOrgAlias sets it first.
	return require(`./consoles-at-volume/${STAGE_MODULES[name] || name}`);
}

/**
 * @description Runs one stage unless the manifest says it is done, and writes the manifest it returns.
 *
 * @param {string} name The stage name.
 * @param {object} context `{options, salesforce, shape, manifest, log}`.
 *
 * @returns {Promise<object>} The manifest after the stage.
 */
async function runStage(name, context)
{
	if(!ALWAYS_RUN.includes(name) && isStageDone(context.manifest, name))
	{
		console.log(`${name}: already done at ${context.manifest.stages[name].finishedAt}; skipped`);
		return context.manifest;
	}
	const stage = loadStage(name);
	const manifest = await stage.run(context);
	writeManifest(context.options.manifestPath, manifest);
	if(name === 'teardown' && !(manifest.stages.teardown && manifest.stages.teardown.ok === false))
	{
		// A torn-down manifest is kept for the record and moved aside, so the next run starts fresh instead of reusing its stages.
		const asidePath = path.join(path.dirname(context.options.manifestPath), `manifest-${manifest.runToken}-torn-down.json`);
		fs.renameSync(context.options.manifestPath, asidePath);
		console.log(`teardown: the manifest is kept at ${asidePath}`);
	}
	return manifest;
}

/**
 * @description The process exit code a command earns from what it did: teardown fails when rows survived, verify
 * and run fail when a claim failed, any other stage passes once it recorded itself ok.
 *
 * @param {string} command The command that ran.
 * @param {object} manifest The manifest after it ran.
 *
 * @returns {number}
 */
function exitCodeFor(command, manifest)
{
	if(command === 'teardown')
	{
		return manifest.stages.teardown?.ok === false ? 1 : 0;
	}
	if(command === 'verify' || command === 'run')
	{
		return manifest.stages.verify?.failed > 0 ? 1 : 0;
	}
	return 0;
}

/**
 * @description Points every helper that reads SF_SUBSCRIBER_ORG_ALIAS at the org the command line named. The browser
 * sign-in of the operate stage and the page objects read that variable when they load, so it is set before any stage
 * loads. With no --org the alias is the variable's own value already, and nothing changes.
 *
 * @param {object} options The parsed command line.
 * @param {object} [environment] The environment to set, default the process's.
 */
function pinOrgAlias(options, environment = process.env)
{
	if(options.alias)
	{
		environment[ORG_ALIAS_VARIABLE] = options.alias;
	}
}

/**
 * @description Refuses a manifest written on another org than the one this command targets: one that names another
 * alias, or one whose org cannot be reached or now signs in as another user (the alias points at a new org). The
 * alias is compared first, with no call to the org; the run user is read only when the aliases agree and the
 * manifest recorded one.
 *
 * @param {object|null} manifest The manifest on disk, or null when there is none.
 * @param {object} options The parsed command line.
 * @param {object} salesforce The org door for the targeted org.
 */
function assertManifestBelongsToOrg(manifest, options, salesforce)
{
	const target = {alias: options.alias, manifestPath: options.manifestPath};
	if(manifest?.org && manifest.org.alias === options.alias && manifest.org.userId)
	{
		try
		{
			target.userId = salesforce.runUserId();
		}
		catch(failure)
		{
			target.unreachable = failure.message.split('\n')[0];
		}
	}
	const foreign = describeForeignManifest(manifest, target);
	if(foreign)
	{
		throw new Error(foreign);
	}
}

/**
 * @description Reads the command line, then runs the asked stages in order against the org.
 */
async function main()
{
	let options;
	try
	{
		options = parseCommandLine(process.argv.slice(2), {alias: getSubscriberOrgAlias()});
	}
	catch(failure)
	{
		console.error(failure.message);
		process.exit(USAGE_EXIT_CODE);
	}
	pinOrgAlias(options);
	const existing = readManifest(options.manifestPath);
	if(options.command === 'status')
	{
		// One screen for a person debugging a run: every stage, its outcome and reason, the counts, the drain rate.
		console.log(describeManifest(existing, options.manifestPath));
		process.exit(existing ? 0 : 1);
	}
	const salesforce = createOrgDoor({alias: options.alias, log: (line) => console.log(line)});
	const shape = scaleShape(options.mode, options.size);
	if(existing)
	{
		try
		{
			assertManifestBelongsToOrg(existing, options, salesforce);
			assertSameRun(existing, options);
		}
		catch(refusal)
		{
			console.error(refusal.message);
			process.exit(1);
		}
	}
	// A stage that records progress batch by batch writes the manifest as it goes, so a failure mid-stage keeps what landed.
	const context = {options, salesforce, shape, manifest: existing, log: (line) => console.log(line), persist: (manifest) => writeManifest(options.manifestPath, manifest)};
	const stages = options.command === 'run' ? STAGE_ORDER : [options.command];
	for(const name of stages)
	{
		context.manifest = await runStage(name, context);
		if(context.manifest.stages[name]?.ok === false)
		{
			console.error(`${name} failed; the manifest says why.`);
			process.exit(1);
		}
	}
	process.exit(exitCodeFor(options.command, context.manifest));
}

if(require.main === module)
{
	main().catch((failure) =>
	{
		console.error('The driver stopped:', failure);
		process.exit(1);
	});
}

module.exports = {STAGE_ORDER, STAGE_MODULES, loadStage, runStage, exitCodeFor, pinOrgAlias, assertManifestBelongsToOrg, USAGE};
