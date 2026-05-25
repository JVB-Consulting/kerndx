// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { runInit, rerenderSubscriberNamingRuleset } = require('../../src/commands/init.js');

test('runInit writes config + workflows + manifest + husky', async (t) => {
	const originalCwd = process.cwd();
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'init-e2e-'));
	try
	{
		process.chdir(dir);

		const answers = {
			package_dirs: ['force-app/main/default'],
			ci_adapter: { name: 'none' },
			branches: { main: 'main', ingress: ['main'], protected: ['main'] },
			naming: { enabled: false },
			slack: { enabled: false },
			workflows: {
				runs_on: 'ubuntu-latest',
				auto_assign_reviewer: false,
				pr_ready_to_merge: false,
				ingress_bypass_alert: false,
				release_bypass_alert: false,
				release_review_assigned: false,
				scanner_parity: false,
				validate_reviewers_json: false,
			},
		};

		await runInit({ answers, interactive: false });

		assert.ok(fs.existsSync('.kerndx/config.yml'));
		assert.ok(fs.existsSync('.kerndx/manifest.json'));
		assert.ok(fs.existsSync('.github/workflows/sfca-quality-gate.yml'));
		assert.ok(fs.existsSync('.husky/pre-push'));

		const manifest = JSON.parse(fs.readFileSync('.kerndx/manifest.json', 'utf-8'));
		assert.ok(manifest.version);
		assert.ok(manifest.files);
		assert.ok(Object.keys(manifest.files).length >= 3);
	}
	finally
	{
		process.chdir(originalCwd);
	}
});

test('runInit persists slack config under notifications.slack when enabled', async (t) => {
	// Regression L12: prior init did not write slack to configRecord. On next
	// `upgrade --force`, upgrade loaded config (missing slack), re-ran init
	// with answers.slack = {enabled: false}, and the workflow scaffolded
	// without Slack steps — silently stripping the subscriber's config.
	const originalCwd = process.cwd();
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'init-slack-'));
	try
	{
		process.chdir(dir);

		const answers = {
			package_dirs: ['force-app/main/default'],
			ci_adapter: { name: 'none' },
			branches: { main: 'main', ingress: ['main'], protected: ['main'] },
			naming: { enabled: false },
			slack: { enabled: true, webhook_env_var: 'SLACK_WEBHOOK_URL' },
			workflows: {},
		};
		await runInit({ answers, interactive: false });

		const configYml = fs.readFileSync('.kerndx/config.yml', 'utf-8');
		assert.match(configYml, /notifications:/);
		assert.match(configYml, /slack:/);
		assert.match(configYml, /enabled: true/);
		assert.match(configYml, /webhook_env_var: SLACK_WEBHOOK_URL/);
	}
	finally
	{
		process.chdir(originalCwd);
	}
});

test('runInit omits notifications.slack when slack disabled', async (t) => {
	const originalCwd = process.cwd();
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'init-no-slack-'));
	try
	{
		process.chdir(dir);

		const answers = {
			package_dirs: ['force-app/main/default'],
			ci_adapter: { name: 'none' },
			branches: { main: 'main', ingress: ['main'], protected: ['main'] },
			naming: { enabled: false },
			slack: { enabled: false },
			workflows: {},
		};
		await runInit({ answers, interactive: false });

		const configYml = fs.readFileSync('.kerndx/config.yml', 'utf-8');
		assert.doesNotMatch(configYml, /notifications:/);
	}
	finally
	{
		process.chdir(originalCwd);
	}
});

test('runInit scaffolds code-analyzer.yml referencing bundled rulesets', async (t) => {
	const originalCwd = process.cwd();
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'init-codeanalyzer-'));
	try
	{
		process.chdir(dir);

		const answers = {
			package_dirs: ['force-app/main/default'],
			ci_adapter: { name: 'none' },
			branches: { main: 'main', ingress: ['main'], protected: ['main'] },
			naming: { enabled: false },
			slack: { enabled: false },
			workflows: {},
		};
		await runInit({ answers, interactive: false });

		assert.ok(fs.existsSync('code-analyzer.yml'), 'code-analyzer.yml scaffolded');
		const yml = fs.readFileSync('code-analyzer.yml', 'utf-8');
		assert.match(yml, /\.kerndx-pipeline\/scanner\/kerndx-pmd-ruleset\.xml/);
		assert.match(yml, /custom_rulesets/);
	}
	finally
	{
		process.chdir(originalCwd);
	}
});

test('runInit preserves existing code-analyzer.yml (does not overwrite)', async (t) => {
	const originalCwd = process.cwd();
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'init-codeanalyzer-preserve-'));
	try
	{
		process.chdir(dir);
		fs.writeFileSync('code-analyzer.yml', '# subscriber customizations\nengines:\n  pmd:\n    custom_rulesets:\n      - subscriber-rules.xml\n');

		const answers = {
			package_dirs: ['force-app/main/default'],
			ci_adapter: { name: 'none' },
			branches: { main: 'main', ingress: ['main'], protected: ['main'] },
			naming: { enabled: false },
			slack: { enabled: false },
			workflows: {},
		};
		await runInit({ answers, interactive: false });

		const yml = fs.readFileSync('code-analyzer.yml', 'utf-8');
		assert.match(yml, /subscriber customizations/);
		assert.match(yml, /subscriber-rules\.xml/);
		assert.doesNotMatch(yml, /kerndx-pmd-ruleset/);
	}
	finally
	{
		process.chdir(originalCwd);
	}
});

test('rerenderSubscriberNamingRuleset returns unchanged for default config', () => {
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'pmd-rerender-'));
	const xml = path.join(dir, 'subscriber-naming-pmd-ruleset.xml');
	const { renderPmdRuleset } = require('../../src/lib/render-pmd-ruleset.js');
	fs.writeFileSync(xml, renderPmdRuleset({}));
	const result = rerenderSubscriberNamingRuleset({}, { shippedXmlPath: xml });
	assert.equal(result.mode, 'unchanged');
});

test('rerenderSubscriberNamingRuleset writes new XML when domains differ', () => {
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'pmd-rerender-'));
	const xml = path.join(dir, 'subscriber-naming-pmd-ruleset.xml');
	const { renderPmdRuleset } = require('../../src/lib/render-pmd-ruleset.js');
	fs.writeFileSync(xml, renderPmdRuleset({}));
	const result = rerenderSubscriberNamingRuleset(
		{ naming: { domains: ['INV', 'WMS'] } },
		{ shippedXmlPath: xml }
	);
	assert.equal(result.mode, 'rerendered');
	const written = fs.readFileSync(xml, 'utf-8');
	assert.match(written, /Domains: INV, WMS/);
	assert.match(written, /\(INV\|WMS\)_/);
});

test('rerenderSubscriberNamingRuleset skips gracefully when shipped XML absent', () => {
	const result = rerenderSubscriberNamingRuleset(
		{},
		{ shippedXmlPath: '/nonexistent/path/scanner/subscriber-naming-pmd-ruleset.xml' }
	);
	assert.equal(result.mode, 'skipped');
});

test('runInit safely appends to existing husky hook', async (t) => {
	const originalCwd = process.cwd();
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'init-husky-'));
	try
	{
		process.chdir(dir);
		fs.mkdirSync('.husky');
		fs.writeFileSync('.husky/pre-push', '#!/usr/bin/env sh\nnpm run lint\n', { mode: 0o755 });

		const answers = {
			package_dirs: ['force-app/main/default'],
			ci_adapter: { name: 'none' },
			branches: { main: 'main', ingress: ['main'], protected: ['main'] },
			naming: { enabled: false },
			slack: { enabled: false },
			workflows: {},
		};
		await runInit({ answers, interactive: false });

		const hook = fs.readFileSync('.husky/pre-push', 'utf-8');
		assert.match(hook, /npm run lint/);
		assert.match(hook, /\.\/\.kerndx-pipeline\/bin\/kerndx preflight/);
	}
	finally
	{
		process.chdir(originalCwd);
	}
});
