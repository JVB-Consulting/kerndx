#!/usr/bin/env node
// SPDX-License-Identifier: MIT
'use strict';
const sade = require('sade');
const {version} = require('../package.json');

const cli = sade('kerndx-pipeline').version(version);

cli.command('init')
.describe('Scaffold workflows + config into the current repo.')
.option('--check', 'dry-run; do not write files')
.action(async(opts) =>
{
	const {runInit} = require('../src/commands/init.js');
	try
	{
		await runInit({interactive: true});
		process.exit(0);
	}
	catch(e)
	{
		console.error('init failed:', e.message);
		process.exit(1);
	}
});

cli.command('scan')
.describe('Run SFCA against changed files.')
.option('--ci', 'exit non-zero on Sev-1 (default: advisory)')
.option('--config', '.kerndx/config.yml path', '.kerndx/config.yml')
.action(async(opts) =>
{
	const {scanCommand} = require('../src/commands/scan.js');
	process.exit(await scanCommand({ci: opts.ci, configPath: opts.config}));
});

cli.command('naming')
.describe('Validate Flow + Object naming on changed files.')
.option('--ci', 'exit non-zero on violation')
.option('--config', '.kerndx/config.yml path', '.kerndx/config.yml')
.action(async(opts) =>
{
	const {namingCommand} = require('../src/commands/naming.js');
	process.exit(await namingCommand({ci: opts.ci, configPath: opts.config}));
});

cli.command('secret-scan')
.describe('Scan changed files for Salesforce + common secrets.')
.option('--ci', 'exit non-zero on a blocking finding (default: advisory)')
.option('--config', '.kerndx/config.yml path', '.kerndx/config.yml')
.action(async(opts) =>
{
	const {secretScanCommand} = require('../src/commands/secret-scan.js');
	process.exit(await secretScanCommand({ci: opts.ci, configPath: opts.config}));
});

cli.command('preflight')
.describe('Run scan + naming back-to-back (advisory).')
.action(async() =>
{
	const {runPreflight} = require('../src/commands/preflight.js');
	process.exit(await runPreflight());
});

cli.command('doctor')
.describe('Validate install + detect drift in scaffolded files.')
.option('--verbose', 'list drifted files')
.action(async(opts) =>
{
	const {runDoctor} = require('../src/commands/doctor.js');
	process.exit(await runDoctor({verbose: opts.verbose}));
});

cli.command('upgrade')
.describe('Back up scaffolded files + write current templates.')
.option('--force', 'auto-delete stale .bak files from a prior upgrade (review first if unsure)')
.action(async(opts) =>
{
	const {runUpgrade} = require('../src/commands/upgrade.js');
	process.exit(await runUpgrade({force: !!opts.force}));
});

cli.command('classify-ref')
.describe('(Internal) Classify a head ref against the configured adapter.')
.option('--head-ref <ref>', 'the git ref to classify')
.option('--config <path>', '.kerndx/config.yml path', '.kerndx/config.yml')
.action((opts) =>
{
	const {classifyRef} = require('../src/commands/classify-ref.js');
	process.stdout.write(classifyRef({headRef: opts['head-ref'], configPath: opts.config}));
});

cli.command('slack-payload')
.describe('(Internal) Build the Slack payload JSON from CSV + env.')
.option('--csv <path>', 'SFCA violations CSV path')
.option('--pr-url <url>', 'PR URL')
.option('--pr-title <text>', 'PR title')
.option('--pr-author <login>', 'PR author login')
.option('--pr-number <num>', 'PR number')
.option('--head-ref <ref>', 'PR head ref')
.option('--base-ref <ref>', 'PR base ref')
.option('--repo <owner-name>', 'GitHub repo (owner/name)')
.option('--run-id <id>', 'GitHub Actions run ID')
.action((opts) =>
{
	const {slackPayload} = require('../src/commands/slack-payload.js');
	process.stdout.write(slackPayload({
		csv: opts.csv,
		prUrl: opts['pr-url'],
		prTitle: opts['pr-title'],
		prAuthor: opts['pr-author'],
		prNumber: opts['pr-number'],
		headRef: opts['head-ref'],
		baseRef: opts['base-ref'],
		repo: opts.repo,
		runId: opts['run-id']
	}));
});

if(process.argv.length === 2)
{
	cli.help();
	process.exit(1);
}
cli.parse(process.argv);
