// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {runInit, renderSubscriberNamingRuleset, readAnswersFile} = require('../../src/commands/init.js');

test('runInit writes config + workflows + manifest + husky', async() =>
{
	const originalCwd = process.cwd();
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'init-e2e-'));
	try
	{
		process.chdir(dir);

		const answers = {
			package_dirs: ['force-app/main/default'],
			ci_adapter: {name: 'none'},
			branches: {main: 'main', ingress: ['main'], protected: ['main']},
			naming: {enabled: false},
			slack: {enabled: false},
			workflows: {
				runs_on: 'ubuntu-latest',
				auto_assign_reviewer: false,
				pr_ready_to_merge: false,
				ingress_bypass_alert: false,
				release_bypass_alert: false,
				release_review_assigned: false,
				scanner_parity: false,
				validate_reviewers_json: false
			}
		};

		await runInit({answers, interactive: false});

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

test('runInit writes every opted-in workflow, the auto-assign reviewer workflow included', async() =>
{
	// Regression: the config key is auto_assign_reviewer but the template is
	// auto-assign, so a plain underscore-to-dash mapping dropped the opt-in
	// and no subscriber who answered yes ever received the workflow.
	const originalCwd = process.cwd();
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'init-opt-ins-'));
	try
	{
		process.chdir(dir);

		const answers = {
			package_dirs: ['force-app/main/default'],
			ci_adapter: {name: 'none'},
			branches: {main: 'main', ingress: ['main'], protected: ['main', 'release'], release: ['release']},
			naming: {enabled: true},
			slack: {enabled: false},
			workflows: {
				runs_on: 'ubuntu-latest',
				auto_assign_reviewer: true,
				pr_ready_to_merge: true,
				ingress_bypass_alert: true,
				release_bypass_alert: true,
				release_review_assigned: true,
				scanner_parity: true,
				validate_reviewers_json: true
			}
		};
		await runInit({answers, interactive: false});

		const expected = [
			'sfca-quality-gate',
			'secret-scan',
			'naming-validation',
			'auto-assign',
			'pr-ready-to-merge',
			'ingress-bypass-alert',
			'release-bypass-alert',
			'release-review-assigned',
			'scanner-parity',
			'validate-reviewers-json'
		];
		const written = fs.readdirSync('.github/workflows').sort();
		assert.deepEqual(written, expected.map(name => `${name}.yml`).sort());

		const autoAssign = fs.readFileSync('.github/workflows/auto-assign.yml', 'utf-8');
		assert.match(autoAssign, /^name: auto-assign\n/);
		assert.match(autoAssign, /pull_request_target:/);
		assert.doesNotMatch(autoAssign, /actions\/checkout/, 'auto-assign runs on pull_request_target and must never check out PR code');

		const manifest = JSON.parse(fs.readFileSync('.kerndx/manifest.json', 'utf-8'));
		assert.ok(manifest.files['.github/workflows/auto-assign.yml'], 'auto-assign.yml is tracked in the manifest');
	}
	finally
	{
		process.chdir(originalCwd);
	}
});

test('runInit leaves every opt-in workflow out when the answer is no', async() =>
{
	const originalCwd = process.cwd();
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'init-opt-outs-'));
	try
	{
		process.chdir(dir);

		const answers = {
			package_dirs: ['force-app/main/default'],
			ci_adapter: {name: 'none'},
			branches: {main: 'main', ingress: ['main'], protected: ['main']},
			naming: {enabled: false},
			slack: {enabled: false},
			workflows: {
				runs_on: 'ubuntu-latest',
				auto_assign_reviewer: false,
				pr_ready_to_merge: false,
				ingress_bypass_alert: false,
				release_bypass_alert: false,
				release_review_assigned: false,
				scanner_parity: false,
				validate_reviewers_json: false
			}
		};
		await runInit({answers, interactive: false});

		assert.deepEqual(fs.readdirSync('.github/workflows').sort(), [
			'secret-scan.yml',
			'sfca-quality-gate.yml'
		]);
	}
	finally
	{
		process.chdir(originalCwd);
	}
});

test('runInit persists slack config under notifications.slack when enabled', async() =>
{
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
			ci_adapter: {name: 'none'},
			branches: {main: 'main', ingress: ['main'], protected: ['main']},
			naming: {enabled: false},
			slack: {enabled: true, webhook_env_var: 'SLACK_WEBHOOK_URL'},
			workflows: {}
		};
		await runInit({answers, interactive: false});

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

test('runInit omits notifications.slack when slack disabled', async() =>
{
	const originalCwd = process.cwd();
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'init-no-slack-'));
	try
	{
		process.chdir(dir);

		const answers = {
			package_dirs: ['force-app/main/default'],
			ci_adapter: {name: 'none'},
			branches: {main: 'main', ingress: ['main'], protected: ['main']},
			naming: {enabled: false},
			slack: {enabled: false},
			workflows: {}
		};
		await runInit({answers, interactive: false});

		const configYml = fs.readFileSync('.kerndx/config.yml', 'utf-8');
		assert.doesNotMatch(configYml, /notifications:/);
	}
	finally
	{
		process.chdir(originalCwd);
	}
});

test('runInit scaffolds code-analyzer.yml referencing bundled rulesets', async() =>
{
	const originalCwd = process.cwd();
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'init-codeanalyzer-'));
	try
	{
		process.chdir(dir);

		const answers = {
			package_dirs: ['force-app/main/default'],
			ci_adapter: {name: 'none'},
			branches: {main: 'main', ingress: ['main'], protected: ['main']},
			naming: {enabled: false},
			slack: {enabled: false},
			workflows: {}
		};
		await runInit({answers, interactive: false});

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

test('runInit renders the ingress branch-protection ruleset its next-steps reference', async() =>
{
	const originalCwd = process.cwd();
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'init-rulesets-'));
	try
	{
		process.chdir(dir);

		const answers = {
			package_dirs: ['force-app/main/default'],
			ci_adapter: {name: 'none'},
			branches: {main: 'main', ingress: ['main'], protected: ['main']},
			naming: {enabled: false},
			slack: {enabled: false},
			workflows: {}
		};
		await runInit({answers, interactive: false});

		assert.ok(fs.existsSync('.kerndx/rulesets/ingress-gate.json'), 'ingress-gate.json rendered');
		const ruleset = JSON.parse(fs.readFileSync('.kerndx/rulesets/ingress-gate.json', 'utf-8'));
		assert.equal(ruleset.name, 'Ingress Gate');
		assert.deepEqual(ruleset.conditions.ref_name.include, ['refs/heads/main']);
		const checksRule = ruleset.rules.find((r) => r.type === 'required_status_checks');
		const contexts = checksRule.parameters.required_status_checks.map((c) => c.context);
		assert.ok(contexts.includes('Static Code Analysis'));
		assert.ok(!contexts.includes('Naming Validation'), 'naming disabled: its check must not be required');

		const manifest = JSON.parse(fs.readFileSync('.kerndx/manifest.json', 'utf-8'));
		assert.ok(manifest.files['.kerndx/rulesets/ingress-gate.json'], 'ruleset hashed into the manifest');

		assert.ok(!fs.existsSync('.kerndx/rulesets/release-gate.json'), 'no release branches: release-gate skipped');
	}
	finally
	{
		process.chdir(originalCwd);
	}
});

test('runInit renders the release-gate ruleset when release branches exist and naming is enforced', async() =>
{
	const originalCwd = process.cwd();
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'init-rulesets-release-'));
	try
	{
		process.chdir(dir);

		const answers = {
			package_dirs: ['force-app/main/default'],
			ci_adapter: {name: 'none'},
			branches: {main: 'main', ingress: ['main'], protected: ['main', 'release']},
			naming: {enabled: true},
			slack: {enabled: false},
			workflows: {}
		};
		await runInit({answers, interactive: false});

		const ingress = JSON.parse(fs.readFileSync('.kerndx/rulesets/ingress-gate.json', 'utf-8'));
		const checksRule = ingress.rules.find((r) => r.type === 'required_status_checks');
		const contexts = checksRule.parameters.required_status_checks.map((c) => c.context);
		assert.ok(contexts.includes('Naming Validation'), 'naming enabled: its check is required');

		assert.ok(fs.existsSync('.kerndx/rulesets/release-gate.json'), 'release-gate.json rendered');
		const release = JSON.parse(fs.readFileSync('.kerndx/rulesets/release-gate.json', 'utf-8'));
		assert.deepEqual(release.conditions.ref_name.include, ['refs/heads/release']);

		const manifest = JSON.parse(fs.readFileSync('.kerndx/manifest.json', 'utf-8'));
		assert.ok(manifest.files['.kerndx/rulesets/release-gate.json'], 'release ruleset hashed into the manifest');
	}
	finally
	{
		process.chdir(originalCwd);
	}
});

test('runInit honours the explicit release-branch answer and preserves hand-authored rulesets', async() =>
{
	const originalCwd = process.cwd();
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'init-rulesets-explicit-'));
	try
	{
		process.chdir(dir);

		fs.mkdirSync('.kerndx/rulesets', {recursive: true});
		fs.writeFileSync('.kerndx/rulesets/ingress-gate.json', '{"name": "Hand Authored"}');

		const answers = {
			package_dirs: ['force-app/main/default'],
			ci_adapter: {name: 'none'},
			branches: {main: 'main', ingress: ['main'], protected: ['main', 'release'], release: ['release']},
			naming: {enabled: false},
			slack: {enabled: false},
			workflows: {}
		};
		await runInit({answers, interactive: false});

		const preserved = JSON.parse(fs.readFileSync('.kerndx/rulesets/ingress-gate.json', 'utf-8'));
		assert.equal(preserved.name, 'Hand Authored', 'existing ruleset file must never be overwritten');
		const manifest = JSON.parse(fs.readFileSync('.kerndx/manifest.json', 'utf-8'));
		assert.ok(!manifest.files['.kerndx/rulesets/ingress-gate.json'], 'preserved file is not manifest-hashed');

		const release = JSON.parse(fs.readFileSync('.kerndx/rulesets/release-gate.json', 'utf-8'));
		assert.deepEqual(release.conditions.ref_name.include, ['refs/heads/release'], 'branches.release drives the release gate');
	}
	finally
	{
		process.chdir(originalCwd);
	}
});

test('runInit scaffolds the hygiene ruleset when the repo does not use the framework', async() =>
{
	const originalCwd = process.cwd();
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'init-codeanalyzer-hygiene-'));
	try
	{
		process.chdir(dir);

		const answers = {
			package_dirs: ['force-app/main/default'],
			framework_package: false,
			ci_adapter: {name: 'none'},
			branches: {main: 'main', ingress: ['main'], protected: ['main']},
			naming: {enabled: false},
			slack: {enabled: false},
			workflows: {}
		};
		await runInit({answers, interactive: false});

		const yml = fs.readFileSync('code-analyzer.yml', 'utf-8');
		assert.match(yml, /- \.kerndx-pipeline\/scanner\/kerndx-hygiene-ruleset\.xml/);
		assert.doesNotMatch(yml, /- \.kerndx-pipeline\/scanner\/kerndx-pmd-ruleset\.xml/);

		const config = fs.readFileSync('.kerndx/config.yml', 'utf-8');
		assert.match(config, /framework_package: false/);
	}
	finally
	{
		process.chdir(originalCwd);
	}
});

test('runInit preserves existing code-analyzer.yml (does not overwrite)', async() =>
{
	const originalCwd = process.cwd();
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'init-codeanalyzer-preserve-'));
	try
	{
		process.chdir(dir);
		fs.writeFileSync('code-analyzer.yml', '# subscriber customizations\nengines:\n  pmd:\n    custom_rulesets:\n      - subscriber-rules.xml\n');

		const answers = {
			package_dirs: ['force-app/main/default'],
			ci_adapter: {name: 'none'},
			branches: {main: 'main', ingress: ['main'], protected: ['main']},
			naming: {enabled: false},
			slack: {enabled: false},
			workflows: {}
		};
		await runInit({answers, interactive: false});

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

test('renderSubscriberNamingRuleset returns unchanged for default config', () =>
{
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'pmd-rerender-'));
	const xml = path.join(dir, 'subscriber-naming-pmd-ruleset.xml');
	const {renderPmdRuleset} = require('../../src/lib/render-pmd-ruleset.js');
	fs.writeFileSync(xml, renderPmdRuleset({}));
	const result = renderSubscriberNamingRuleset({}, {shippedXmlPath: xml});
	assert.equal(result.mode, 'unchanged');
});

test('renderSubscriberNamingRuleset renders new XML with the domains when they differ', () =>
{
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'pmd-rerender-'));
	const xml = path.join(dir, 'subscriber-naming-pmd-ruleset.xml');
	const {renderPmdRuleset} = require('../../src/lib/render-pmd-ruleset.js');
	fs.writeFileSync(xml, renderPmdRuleset({}));
	const result = renderSubscriberNamingRuleset({
		naming: {
			domains: [
				'INV',
				'WMS'
			]
		}
	}, {shippedXmlPath: xml});
	assert.equal(result.mode, 'rerendered');
	assert.equal(result.path, xml);
	assert.match(result.content, /Domains: INV, WMS/);
	assert.match(result.content, /\(INV\|WMS\)_/);
});

test('renderSubscriberNamingRuleset skips gracefully when shipped XML absent', () =>
{
	const result = renderSubscriberNamingRuleset({}, {shippedXmlPath: '/nonexistent/path/scanner/subscriber-naming-pmd-ruleset.xml'});
	assert.equal(result.mode, 'skipped');
});

test('runInit safely appends to existing husky hook', async() =>
{
	const originalCwd = process.cwd();
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'init-husky-'));
	try
	{
		process.chdir(dir);
		fs.mkdirSync('.husky');
		fs.writeFileSync('.husky/pre-push', '#!/usr/bin/env sh\nnpm run lint\n', {mode: 0o755});

		const answers = {
			package_dirs: ['force-app/main/default'],
			ci_adapter: {name: 'none'},
			branches: {main: 'main', ingress: ['main'], protected: ['main']},
			naming: {enabled: false},
			slack: {enabled: false},
			workflows: {}
		};
		await runInit({answers, interactive: false});

		const hook = fs.readFileSync('.husky/pre-push', 'utf-8');
		assert.match(hook, /npm run lint/);
		assert.match(hook, /node \.kerndx-pipeline\/bin\/kerndx preflight/);
	}
	finally
	{
		process.chdir(originalCwd);
	}
});

// Runs fn while collecting every console.log line, and returns the lines.
async function captureLog(fn)
{
	const lines = [];
	const originalLog = console.log;
	console.log = (...parts) => lines.push(parts.join(' '));
	try
	{
		await fn();
	}
	finally
	{
		console.log = originalLog;
	}
	return lines;
}

test('runInit in check mode writes no file and lists every path it would write', async() =>
{
	const originalCwd = process.cwd();
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'init-check-'));
	try
	{
		process.chdir(dir);
		const answers = {
			package_dirs: ['force-app/main/default'],
			ci_adapter: {name: 'none'},
			branches: {main: 'main', ingress: ['main'], protected: ['main', 'release'], release: ['release']},
			naming: {enabled: true},
			slack: {enabled: false},
			workflows: {runs_on: 'ubuntu-latest', auto_assign_reviewer: true}
		};

		const lines = await captureLog(() => runInit({answers, interactive: false, check: true}));

		assert.deepEqual(fs.readdirSync(dir), []);
		assert.deepEqual(lines.filter(line => line.startsWith('  would write ')), [
			'.kerndx/config.yml',
			'code-analyzer.yml',
			'.github/workflows/sfca-quality-gate.yml',
			'.github/workflows/secret-scan.yml',
			'.github/workflows/naming-validation.yml',
			'.github/workflows/auto-assign.yml',
			'.kerndx/rulesets/ingress-gate.json',
			'.kerndx/rulesets/release-gate.json',
			'.husky/pre-push',
			'.kerndx/manifest.json'
		].map(expected => `  would write ${expected}`), 'Expected the check to list every file, in the order init writes them');
		assert.ok(lines.some(line => line.includes('Check only: no files were written.')));
		assert.ok(!lines.some(line => line.includes('Scaffold complete.')));
	}
	finally
	{
		process.chdir(originalCwd);
	}
});

test('runInit in check mode leaves an existing husky hook as it was', async() =>
{
	const originalCwd = process.cwd();
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'init-check-husky-'));
	try
	{
		process.chdir(dir);
		fs.mkdirSync('.husky');
		const hookBefore = '#!/usr/bin/env sh\nnpm run lint\n';
		fs.writeFileSync('.husky/pre-push', hookBefore, {mode: 0o755});
		const answers = {
			package_dirs: ['force-app/main/default'],
			ci_adapter: {name: 'none'},
			branches: {main: 'main', ingress: ['main'], protected: ['main']},
			naming: {enabled: false},
			slack: {enabled: false},
			workflows: {}
		};

		const lines = await captureLog(() => runInit({answers, interactive: false, check: true}));

		assert.equal(fs.readFileSync('.husky/pre-push', 'utf-8'), hookBefore);
		assert.deepEqual(fs.readdirSync(dir), ['.husky']);
		assert.ok(lines.includes('  would write .husky/pre-push'));
	}
	finally
	{
		process.chdir(originalCwd);
	}
});

test('renderSubscriberNamingRuleset writes nothing and prints nothing when the XML would change', async() =>
{
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'pmd-rerender-check-'));
	const xml = path.join(dir, 'subscriber-naming-pmd-ruleset.xml');
	const {renderPmdRuleset} = require('../../src/lib/render-pmd-ruleset.js');
	const before = renderPmdRuleset({});
	fs.writeFileSync(xml, before);

	let result;
	const lines = await captureLog(() =>
	{
		result = renderSubscriberNamingRuleset({naming: {domains: ['INV']}}, {shippedXmlPath: xml});
	});

	assert.equal(result.mode, 'rerendered');
	assert.equal(fs.readFileSync(xml, 'utf-8'), before);
	assert.deepEqual(lines, []);
});

// The answers a reader would give, in the shape runInit takes: the smallest set a CI job needs.
const VALID_ANSWERS = {
	package_dirs: ['force-app/main/default'],
	framework_package: true,
	ci_adapter: {name: 'none'},
	branches: {main: 'main', ingress: ['main'], protected: ['main'], release: []},
	slack: {enabled: false}
};

// A number given where the answers file needs text, a list of text or true or false.
const NUMBER_INSTEAD_OF_TEXT = 42;

// The workflow opt-in answers under workflows, each true or false.
const WORKFLOW_OPT_IN_KEYS = [
	'auto_assign_reviewer',
	'pr_ready_to_merge',
	'ingress_bypass_alert',
	'release_bypass_alert',
	'release_review_assigned',
	'scanner_parity',
	'validate_reviewers_json'
];

// The temporary folders the answers file tests make, removed when the tests in this file end.
const temporaryAnswersFolders = [];

test.after(() =>
{
	for(const folder of temporaryAnswersFolders)
	{
		fs.rmSync(folder, {recursive: true, force: true});
	}
});

// Makes a new temporary folder that is removed when the tests in this file end, and returns its path.
function makeTemporaryAnswersFolder(prefix)
{
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), prefix));
	temporaryAnswersFolders.push(dir);
	return dir;
}

// Writes text to a new file in a new temporary folder and returns the file's path.
function writeAnswersFile(text)
{
	const filePath = path.join(makeTemporaryAnswersFolder('init-answers-'), 'kerndx-answers.json');
	fs.writeFileSync(filePath, text);
	return filePath;
}

// Checks that readAnswersFile refuses each set of answers, with a message that names the file and the key.
function assertAnswersRefused(cases)
{
	for(const {key, answers} of cases)
	{
		const filePath = writeAnswersFile(JSON.stringify(answers));

		assert.throws(() => readAnswersFile(filePath), (error) => error.message.includes(filePath) && error.message.includes(key),
			`Expected ${JSON.stringify(answers)} to be refused, naming ${key}`);
	}
}

test('readAnswersFile returns the answers in a valid file', () =>
{
	const filePath = writeAnswersFile(JSON.stringify(VALID_ANSWERS));

	assert.deepEqual(readAnswersFile(filePath), VALID_ANSWERS);
});

test('readAnswersFile names the file when the file does not exist', () =>
{
	const filePath = path.join(os.tmpdir(), 'init-answers-missing', 'kerndx-answers.json');

	assert.throws(() => readAnswersFile(filePath), (error) => error.message.includes(filePath) && /cannot read/i.test(error.message));
});

test('readAnswersFile names the file when the path is a folder it cannot read as text', () =>
{
	const dir = makeTemporaryAnswersFolder('init-answers-folder-');

	assert.throws(() => readAnswersFile(dir), (error) => error.message.includes(dir) && /cannot read/i.test(error.message));
});

test('readAnswersFile names the file when its text is not JSON', () =>
{
	const filePath = writeAnswersFile('package_dirs: force-app');

	assert.throws(() => readAnswersFile(filePath), (error) => error.message.includes(filePath) && /not valid JSON/.test(error.message));
});

test('readAnswersFile names package_dirs when the list is missing, empty or holds something other than text', () =>
{
	for(const packageDirs of [undefined, [], 'force-app', [''], [NUMBER_INSTEAD_OF_TEXT]])
	{
		const answers = {...VALID_ANSWERS, package_dirs: packageDirs};
		const filePath = writeAnswersFile(JSON.stringify(answers));

		assert.throws(() => readAnswersFile(filePath), (error) => error.message.includes(filePath) && error.message.includes('package_dirs'),
			`Expected package_dirs ${JSON.stringify(packageDirs)} to be refused`);
	}
});

test('readAnswersFile names ci_adapter.name when the CI tool is missing', () =>
{
	for(const ciAdapter of [undefined, {}, {name: ''}])
	{
		const answers = {...VALID_ANSWERS, ci_adapter: ciAdapter};
		const filePath = writeAnswersFile(JSON.stringify(answers));

		assert.throws(() => readAnswersFile(filePath), (error) => error.message.includes(filePath) && error.message.includes('ci_adapter.name'),
			`Expected ci_adapter ${JSON.stringify(ciAdapter)} to be refused`);
	}
});

test('readAnswersFile names branches.main when the main branch is missing', () =>
{
	for(const branches of [undefined, {}, {main: ''}])
	{
		const answers = {...VALID_ANSWERS, branches};
		const filePath = writeAnswersFile(JSON.stringify(answers));

		assert.throws(() => readAnswersFile(filePath), (error) => error.message.includes(filePath) && error.message.includes('branches.main'),
			`Expected branches ${JSON.stringify(branches)} to be refused`);
	}
});

test('readAnswersFile refuses JSON that is not an object of answers', () =>
{
	for(const text of ['null', '[]', '"main"'])
	{
		const filePath = writeAnswersFile(text);

		assert.throws(() => readAnswersFile(filePath), (error) => error.message.includes(filePath) && error.message.includes('package_dirs'),
			`Expected ${text} to be refused`);
	}
});

test('readAnswersFile fills branches.ingress and branches.protected from branches.main when they are missing', () =>
{
	const filePath = writeAnswersFile(JSON.stringify({...VALID_ANSWERS, branches: {main: 'trunk'}}));

	const answers = readAnswersFile(filePath);

	assert.deepEqual(answers.branches.ingress, ['trunk']);
	assert.deepEqual(answers.branches.protected, ['trunk']);
	assert.equal('release' in answers.branches, false);
});

test('readAnswersFile builds branches.protected from the main, ingress and release branches when it is missing', () =>
{
	const branches = {main: 'main', ingress: ['main', 'develop'], release: ['release']};
	const filePath = writeAnswersFile(JSON.stringify({...VALID_ANSWERS, branches}));

	assert.deepEqual(readAnswersFile(filePath).branches.protected, ['main', 'develop', 'release']);
});

test('readAnswersFile names the branch list that is not a list of branch names', () =>
{
	const badValues = ['main', [NUMBER_INSTEAD_OF_TEXT], [''], '', null];

	assertAnswersRefused(['ingress', 'protected', 'release'].flatMap((key) => (key === 'release' ? badValues : [...badValues, []]).map((value) => ({
		key: `branches.${key}`, answers: {...VALID_ANSWERS, branches: {...VALID_ANSWERS.branches, [key]: value}}
	}))));
});

test('readAnswersFile gives Slack the default webhook secret name when Slack is on and no name is given', () =>
{
	const filePath = writeAnswersFile(JSON.stringify({...VALID_ANSWERS, slack: {enabled: true}}));

	assert.deepEqual(readAnswersFile(filePath).slack, {enabled: true, webhook_env_var: 'SLACK_WEBHOOK_URL'});
});

test('readAnswersFile keeps the webhook secret name the file gives', () =>
{
	const filePath = writeAnswersFile(JSON.stringify({...VALID_ANSWERS, slack: {enabled: true, webhook_env_var: 'TEAM_HOOK'}}));

	assert.equal(readAnswersFile(filePath).slack.webhook_env_var, 'TEAM_HOOK');
});

test('readAnswersFile names slack.webhook_env_var when Slack is on and the name is blank or not text', () =>
{
	for(const name of ['', '   ', NUMBER_INSTEAD_OF_TEXT, null, ['A']])
	{
		const filePath = writeAnswersFile(JSON.stringify({...VALID_ANSWERS, slack: {enabled: true, webhook_env_var: name}}));

		assert.throws(() => readAnswersFile(filePath), (error) => error.message.includes(filePath) && error.message.includes('slack.webhook_env_var'),
			`Expected slack.webhook_env_var ${JSON.stringify(name)} to be refused`);
	}
});

test('readAnswersFile leaves the Slack answers alone when Slack is off or left out', () =>
{
	const off = writeAnswersFile(JSON.stringify({...VALID_ANSWERS, slack: {enabled: false}}));
	const absent = writeAnswersFile(JSON.stringify({package_dirs: VALID_ANSWERS.package_dirs, ci_adapter: {name: 'none'}, branches: {main: 'main'}}));

	assert.deepEqual(readAnswersFile(off).slack, {enabled: false});
	assert.equal('slack' in readAnswersFile(absent), false);
});

test('readAnswersFile names slack.enabled when it is not true or false', () =>
{
	for(const enabled of ['true', 1, 'yes', null, [true]])
	{
		const filePath = writeAnswersFile(JSON.stringify({...VALID_ANSWERS, slack: {enabled}}));

		assert.throws(() => readAnswersFile(filePath), (error) => error.message.includes(filePath) && error.message.includes('slack.enabled'),
			`Expected slack.enabled ${JSON.stringify(enabled)} to be refused`);
	}
});

test('readAnswersFile names slack when it is given but is not a set of answers', () =>
{
	for(const slack of ['yes', true, 1, null, ['SLACK_WEBHOOK_URL']])
	{
		const filePath = writeAnswersFile(JSON.stringify({...VALID_ANSWERS, slack}));

		assert.throws(() => readAnswersFile(filePath), (error) => error.message.includes(filePath) && error.message.includes('slack'),
			`Expected slack ${JSON.stringify(slack)} to be refused`);
	}
});

test('readAnswersFile accepts Slack answers that leave enabled out', () =>
{
	const filePath = writeAnswersFile(JSON.stringify({...VALID_ANSWERS, slack: {}}));

	assert.deepEqual(readAnswersFile(filePath).slack, {});
});

test('runInit completes in check mode with only the three required answers read from a file', async() =>
{
	const dir = makeTemporaryAnswersFolder('init-minimal-answers-');
	const originalCwd = process.cwd();
	const filePath = writeAnswersFile(JSON.stringify({
		package_dirs: ['force-app/main/default'], ci_adapter: {name: 'none'}, branches: {main: 'main'}
	}));
	try
	{
		process.chdir(dir);
		const answers = readAnswersFile(filePath);

		const lines = await captureLog(() => runInit({answers, interactive: false, check: true}));

		assert.deepEqual(fs.readdirSync(dir), []);
		assert.ok(lines.includes('  would write .kerndx/config.yml'));
		assert.ok(lines.includes('  would write .github/workflows/sfca-quality-gate.yml'));
	}
	finally
	{
		process.chdir(originalCwd);
	}
});

test('readAnswersFile returns every answer the questions can give, unchanged', () =>
{
	const answers = {
		package_dirs: ['force-app/main/default', 'unpackaged'],
		framework_package: false,
		ci_adapter: {name: 'copado', experimental: true},
		branches: {main: 'main', ingress: ['main', 'develop'], protected: ['main', 'develop', 'release'], release: ['release']},
		naming: {enabled: true},
		slack: {enabled: true, webhook_env_var: 'TEAM_HOOK', suppress_on_pr_title_prefix: 'chore(deps)'},
		workflows: {runs_on: 'windows-latest', ...Object.fromEntries(WORKFLOW_OPT_IN_KEYS.map((key) => [key, true]))},
		codeowners_team_slack_id: 'S0123ABCD'
	};
	const filePath = writeAnswersFile(JSON.stringify(answers));

	assert.deepEqual(readAnswersFile(filePath), answers);
});

test('readAnswersFile names package_dirs when a folder name holds a quote character, and says why', () =>
{
	for(const folder of ["force-app/it's", 'force-app/"main"'])
	{
		const filePath = writeAnswersFile(JSON.stringify({...VALID_ANSWERS, package_dirs: [folder]}));

		assert.throws(() => readAnswersFile(filePath),
			(error) => error.message.includes(filePath) && error.message.includes('package_dirs') && /quote/.test(error.message),
			`Expected package_dirs ${JSON.stringify(folder)} to be refused`);
	}
});

test('readAnswersFile accepts each CI tool the questions offer', () =>
{
	for(const ciAdapter of [{name: 'gearset'}, {name: 'devops-center'}, {name: 'none'}, {name: 'custom'}, {name: 'copado', experimental: true},
		{name: 'autorabit', experimental: true}])
	{
		const filePath = writeAnswersFile(JSON.stringify({...VALID_ANSWERS, ci_adapter: ciAdapter}));

		assert.deepEqual(readAnswersFile(filePath).ci_adapter, ciAdapter);
	}
});

test('readAnswersFile names ci_adapter.name for a CI tool the questions do not offer, and ci_adapter.experimental for an experimental one', () =>
{
	assertAnswersRefused([
		{key: 'ci_adapter.name', answers: {...VALID_ANSWERS, ci_adapter: {name: 'jenkins'}}},
		{key: 'ci_adapter.name', answers: {...VALID_ANSWERS, ci_adapter: {name: 'Gearset'}}},
		{key: 'ci_adapter.name', answers: {...VALID_ANSWERS, ci_adapter: {name: NUMBER_INSTEAD_OF_TEXT}}},
		{key: 'ci_adapter.experimental', answers: {...VALID_ANSWERS, ci_adapter: {name: 'copado'}}},
		{key: 'ci_adapter.experimental', answers: {...VALID_ANSWERS, ci_adapter: {name: 'autorabit', experimental: false}}},
		{key: 'ci_adapter.experimental', answers: {...VALID_ANSWERS, ci_adapter: {name: 'copado', experimental: 'true'}}}
	]);
});

test('readAnswersFile names the Slack answer that is not text', () =>
{
	assertAnswersRefused([
		{key: 'slack.suppress_on_pr_title_prefix', answers: {...VALID_ANSWERS, slack: {enabled: true, suppress_on_pr_title_prefix: NUMBER_INSTEAD_OF_TEXT}}},
		{key: 'slack.suppress_on_pr_title_prefix', answers: {...VALID_ANSWERS, slack: {enabled: true, suppress_on_pr_title_prefix: true}}},
		{key: 'slack.suppress_on_pr_title_prefix', answers: {...VALID_ANSWERS, slack: {enabled: true, suppress_on_pr_title_prefix: ['chore']}}},
		{key: 'slack.suppress_on_pr_title_prefix', answers: {...VALID_ANSWERS, slack: {enabled: true, suppress_on_pr_title_prefix: "it's"}}}
	]);
});

test('readAnswersFile names workflows or the workflow answer that has the wrong kind of value', () =>
{
	assertAnswersRefused([
		...['yes', true, null, ['scanner_parity']].map((workflows) => ({key: 'workflows', answers: {...VALID_ANSWERS, workflows}})),
		...['', '   ', NUMBER_INSTEAD_OF_TEXT, null].map((runsOn) => ({key: 'workflows.runs_on', answers: {...VALID_ANSWERS, workflows: {runs_on: runsOn}}})),
		...WORKFLOW_OPT_IN_KEYS.flatMap((key) => ['true', 1, null].map((value) => ({
			key: `workflows.${key}`, answers: {...VALID_ANSWERS, workflows: {[key]: value}}
		})))
	]);
});

test('readAnswersFile names naming or naming.enabled when it has the wrong kind of value', () =>
{
	assertAnswersRefused([
		...['yes', true, null, [true]].map((naming) => ({key: 'naming', answers: {...VALID_ANSWERS, naming}})),
		...['true', 1, null].map((enabled) => ({key: 'naming.enabled', answers: {...VALID_ANSWERS, naming: {enabled}}}))
	]);
});

test('readAnswersFile names framework_package or codeowners_team_slack_id when it has the wrong kind of value', () =>
{
	assertAnswersRefused([
		...['true', 1, null].map((value) => ({key: 'framework_package', answers: {...VALID_ANSWERS, framework_package: value}})),
		...[NUMBER_INSTEAD_OF_TEXT, true, null, "S0'1"].map((value) => ({key: 'codeowners_team_slack_id', answers: {...VALID_ANSWERS, codeowners_team_slack_id: value}}))
	]);
});

test('readAnswersFile names each text answer that holds a line break', () =>
{
	const slackOn = {enabled: true, webhook_env_var: 'SLACK_WEBHOOK_URL'};
	assertAnswersRefused(['\n', '\r'].flatMap((lineBreak) => [
		{key: 'package_dirs', answers: {...VALID_ANSWERS, package_dirs: ['force-app/main/default', `src${lineBreak}extra`]}},
		{key: 'branches.main', answers: {...VALID_ANSWERS, branches: {main: `main${lineBreak}x`}}},
		{key: 'branches.ingress', answers: {...VALID_ANSWERS, branches: {main: 'main', ingress: ['main', `develop${lineBreak}`]}}},
		{key: 'branches.protected', answers: {...VALID_ANSWERS, branches: {main: 'main', protected: [`release${lineBreak}x`]}}},
		{key: 'branches.release', answers: {...VALID_ANSWERS, branches: {main: 'main', release: [`release${lineBreak}x`]}}},
		{key: 'workflows.runs_on', answers: {...VALID_ANSWERS, workflows: {runs_on: `ubuntu-latest${lineBreak}`}}},
		{key: 'slack.webhook_env_var', answers: {...VALID_ANSWERS, slack: {...slackOn, webhook_env_var: `HOOK${lineBreak}X`}}},
		{key: 'slack.suppress_on_pr_title_prefix', answers: {...VALID_ANSWERS, slack: {...slackOn, suppress_on_pr_title_prefix: `chore${lineBreak}`}}},
		{key: 'codeowners_team_slack_id', answers: {...VALID_ANSWERS, codeowners_team_slack_id: `S0123${lineBreak}ABCD`}}
	]));
});

// Text the interactive questions would trim or split on commas, so a file may not give it as one folder or branch name.
const NAMES_THE_QUESTIONS_WOULD_CHANGE = [' main', 'main ', 'ma,in', 'a, b', ','];

test('readAnswersFile names each folder or branch name that starts or ends with a space or holds a comma, and says why', () =>
{
	const cases = NAMES_THE_QUESTIONS_WOULD_CHANGE.flatMap((name) => [
		{key: 'package_dirs', answers: {...VALID_ANSWERS, package_dirs: ['force-app/main/default', name]}},
		{key: 'branches.main', answers: {...VALID_ANSWERS, branches: {main: name}}},
		{key: 'branches.ingress', answers: {...VALID_ANSWERS, branches: {main: 'main', ingress: ['main', name]}}},
		{key: 'branches.protected', answers: {...VALID_ANSWERS, branches: {main: 'main', protected: ['main', name]}}},
		{key: 'branches.release', answers: {...VALID_ANSWERS, branches: {main: 'main', release: [name]}}}
	]);
	for(const {key, answers} of cases)
	{
		const filePath = writeAnswersFile(JSON.stringify(answers));

		assert.throws(() => readAnswersFile(filePath),
			(error) => error.message.includes(filePath) && error.message.includes(key) && /must not start or end with a space or hold a comma/.test(error.message),
			`Expected ${key} to be refused for ${JSON.stringify(answers)}`);
	}
});

test('readAnswersFile accepts folder and branch names with a space or a dash inside', () =>
{
	const answers = {...VALID_ANSWERS, package_dirs: ['my app/main default'], branches: {main: 'feature/a-b', ingress: ['feature/a-b'], protected: ['feature/a-b'], release: []}};
	const filePath = writeAnswersFile(JSON.stringify(answers));

	assert.deepEqual(readAnswersFile(filePath), answers);
});

test('readAnswersFile names workflows.runs_on when it is not a runner label of letters, digits, dots, underscores and dashes', () =>
{
	assertAnswersRefused(['ubuntu latest', 'ubuntu-latest, windows-latest', '[self-hosted]', 'ubuntu-latest}}', 'ubuntu:latest', ' ubuntu-latest'].map((runsOn) => ({
		key: 'workflows.runs_on', answers: {...VALID_ANSWERS, workflows: {runs_on: runsOn}}
	})));
});

test('readAnswersFile accepts each runner label of letters, digits, dots, underscores and dashes', () =>
{
	for(const runsOn of ['ubuntu-latest', 'ubuntu-22.04', 'self_hosted', 'macos-14'])
	{
		const filePath = writeAnswersFile(JSON.stringify({...VALID_ANSWERS, workflows: {runs_on: runsOn}}));

		assert.equal(readAnswersFile(filePath).workflows.runs_on, runsOn);
	}
});

test('runInit writes nothing when the naming answers fail after the answers file was accepted', async() =>
{
	const dir = makeTemporaryAnswersFolder('init-naming-error-');
	const originalCwd = process.cwd();
	const filePath = writeAnswersFile(JSON.stringify({...VALID_ANSWERS, naming: {enabled: true, domains: 'SLS'}}));
	try
	{
		process.chdir(dir);
		const answers = readAnswersFile(filePath);

		await assert.rejects(runInit({answers, interactive: false}), /naming\.domains must be an array/);

		assert.ok(!fs.existsSync(path.join(dir, '.kerndx', 'config.yml')), 'Expected no .kerndx/config.yml');
		assert.ok(!fs.existsSync(path.join(dir, 'code-analyzer.yml')), 'Expected no code-analyzer.yml');
		assert.deepEqual(fs.readdirSync(dir), []);
	}
	finally
	{
		process.chdir(originalCwd);
	}
});

test('runInit writes and reports nothing when a workflow template fails to render', async() =>
{
	// A config file edited by hand can give the ingress branches as text, not a list. The workflow template then fails on it,
	// after the config, code-analyzer.yml and the naming ruleset would have been written if each file were written as soon as it was ready.
	const answers = {...VALID_ANSWERS, branches: {main: 'main', ingress: 'main', protected: ['main'], release: []}};
	for(const check of [false, true])
	{
		const dir = makeTemporaryAnswersFolder('init-template-error-');
		const originalCwd = process.cwd();
		try
		{
			process.chdir(dir);

			const lines = await captureLog(() => assert.rejects(runInit({answers, interactive: false, check}), /ingressBranches\.join is not a function/));

			assert.deepEqual(fs.readdirSync(dir), [], `Expected no file written with check ${check}`);
			assert.deepEqual(lines, [], `Expected no line printed with check ${check}`);
		}
		finally
		{
			process.chdir(originalCwd);
		}
	}
});
