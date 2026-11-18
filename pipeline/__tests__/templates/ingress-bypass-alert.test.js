// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const yaml = require('js-yaml');
const {spawnSync} = require('node:child_process');
const {renderTemplate} = require('../../src/lib/scaffold.js');

const TPL = path.join(__dirname, '..', '..', 'src', 'templates', 'workflows', 'ingress-bypass-alert.yml.eta');

test('ingress-bypass-alert renders for subscriber-equivalent config', () =>
{
	const rendered = renderTemplate(TPL, {
		ingressBranches: [
			'build',
			'main'
		],
		requiredChecks: [
			'Static Code Analysis',
			'Naming Validation'
		],
		runsOn: 'ubuntu-latest',
		nodeVersion: '20',
		slack: {enabled: true, webhook_env_var: 'SLACK_WEBHOOK_URL'}
	}, {views: path.dirname(TPL)});

	assert.match(rendered, /name: ingress-bypass-alert/);
	assert.match(rendered, /Static Code Analysis/);
	assert.match(rendered, /SLACK_WEBHOOK_URL/);
});

test('ingress-bypass-alert branches list uses ingressBranches', () =>
{
	const rendered = renderTemplate(TPL, {
		ingressBranches: [
			'build',
			'main'
		],
		requiredChecks: [
			'Static Code Analysis',
			'Naming Validation'
		],
		runsOn: 'ubuntu-latest',
		nodeVersion: '20',
		slack: {enabled: true, webhook_env_var: 'SLACK_WEBHOOK_URL'}
	}, {views: path.dirname(TPL)});

	assert.match(rendered, /branches: \[build, main\]/);
});

test('ingress-bypass-alert uses runsOn value', () =>
{
	const rendered = renderTemplate(TPL, {
		ingressBranches: ['production'], requiredChecks: ['Static Code Analysis'], runsOn: 'self-hosted', nodeVersion: '20', slack: {enabled: true, webhook_env_var: 'MY_WEBHOOK'}
	}, {views: path.dirname(TPL)});

	assert.match(rendered, /runs-on: self-hosted/);
	assert.match(rendered, /MY_WEBHOOK/);
	assert.match(rendered, /branches: \[production\]/);
});

test('ingress-bypass-alert emits required_checks as a quoted bash array in shell', () =>
{
	const rendered = renderTemplate(TPL, {
		ingressBranches: [
			'build',
			'main'
		],
		requiredChecks: [
			'Static Code Analysis',
			'Naming Validation'
		],
		runsOn: 'ubuntu-latest',
		nodeVersion: '20',
		slack: {enabled: true, webhook_env_var: 'SLACK_WEBHOOK_URL'}
	}, {views: path.dirname(TPL)});

	assert.match(rendered, /required_checks=\('Static Code Analysis' 'Naming Validation'\)/);
});

const bashProbe = spawnSync('bash', ['-c', 'true']);
const bashAvailable = !bashProbe.error && bashProbe.status === 0;

test('ingress-bypass-alert required_checks keeps each name whole when bash reads it', {skip: !bashAvailable && 'bash is not available'}, () =>
{
	const names = [
		'Static Code Analysis',
		"Bob's Check",
		'Cost $HOME `whoami` "quoted"'
	];
	const rendered = renderTemplate(TPL, {
		ingressBranches: ['main'],
		requiredChecks: names,
		runsOn: 'ubuntu-latest',
		nodeVersion: '20',
		slack: {enabled: true, webhook_env_var: 'SLACK_WEBHOOK_URL'}
	}, {views: path.dirname(TPL)});
	const line = rendered.split('\n').find(text => text.trim().startsWith('required_checks=')).trim();
	const result = spawnSync('bash', ['-c', line + '; printf "%s\\n" "${required_checks[@]}"'], {encoding: 'utf8'});

	assert.equal(result.status, 0, result.stderr);
	assert.equal(result.stdout, names.join('\n') + '\n');
});

test('ingress-bypass-alert sends each check name to gh as a parameter, with no hand-made encoding', {skip: !bashAvailable && 'bash is not available'}, () =>
{
	const names = [
		'Static Code Analysis',
		'A&B #1 100%+?'
	];
	const rendered = renderTemplate(TPL, {
		ingressBranches: ['main'],
		requiredChecks: names,
		runsOn: 'ubuntu-latest',
		nodeVersion: '20',
		slack: {enabled: true, webhook_env_var: 'SLACK_WEBHOOK_URL'}
	}, {views: path.dirname(TPL)});
	const parsed = yaml.load(rendered);
	const steps = Object.values(parsed.jobs).flatMap(job => job.steps);
	const script = steps.find(step => step.id === 'inspect').run;
	const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'ingress-bypass-alert-'));

	try
	{
		const recordFile = path.join(directory, 'gh-arguments.txt');
		const outputFile = path.join(directory, 'github-output.txt');
		const binDirectory = path.join(directory, 'bin');
		fs.mkdirSync(binDirectory);
		fs.writeFileSync(path.join(binDirectory, 'gh'), '#!/usr/bin/env bash\nprintf "%s\\n" "$@" >> "' + recordFile + '"\n'
			+ 'case "$*" in *"check_name=A&B #1 100%+?"*) printf "failure\\n" ;; *) printf "success\\n" ;; esac\n', {mode: 0o755});

		const result = spawnSync('bash', ['-c', script], {
			encoding: 'utf8',
			env: {
				...process.env,
				PATH: binDirectory + path.delimiter + process.env.PATH,
				GITHUB_REPOSITORY: 'owner/repository',
				GITHUB_OUTPUT: outputFile,
				GH_TOKEN: 'dummy-token',
				SHA: 'abc123',
				PR_NUMBER: '7',
				PR_TITLE: 'Dummy title',
				PR_URL: 'https://example.invalid/pull/7',
				PR_AUTHOR: 'dummy-author',
				PR_BASE: 'main',
				PR_MERGED_BY: 'dummy-merger'
			}
		});
		const recorded = fs.readFileSync(recordFile, 'utf8').split('\n');

		assert.equal(result.status, 0, result.stderr);
		for(const name of names)
		{
			assert.ok(recorded.includes('check_name=' + name), 'gh did not receive check_name=' + name);
		}
		assert.equal(recorded.filter(argument => argument === 'check_name=A&B #1 100%+?').length, 2,
			'Expected the failing check to be looked up twice: once for its conclusion and once for its run link');
		assert.equal(recorded.filter(argument => argument === '--method').length, 3, 'Expected every gh call to be given --method');
		assert.ok(recorded.every((argument, index) => argument !== '--method' || recorded[index + 1] === 'GET'), 'Expected every gh call to use GET');
		assert.match(fs.readFileSync(outputFile, 'utf8'), /^alert=true$/m, 'Expected the failing check to raise the alert');
	}
	finally
	{
		fs.rmSync(directory, {recursive: true, force: true});
	}
});

test('ingress-bypass-alert includes race-guard sleep 20', () =>
{
	const rendered = renderTemplate(TPL, {
		ingressBranches: [
			'build',
			'main'
		],
		requiredChecks: [
			'Static Code Analysis',
			'Naming Validation'
		],
		runsOn: 'ubuntu-latest',
		nodeVersion: '20',
		slack: {enabled: true, webhook_env_var: 'SLACK_WEBHOOK_URL'}
	}, {views: path.dirname(TPL)});

	assert.match(rendered, /sleep 20/);
});
