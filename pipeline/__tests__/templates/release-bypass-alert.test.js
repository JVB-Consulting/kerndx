// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { renderTemplate } = require('../../src/lib/scaffold.js');

const TPL = path.join(__dirname, '..', '..', 'src', 'templates', 'workflows', 'release-bypass-alert.yml.eta');

test('release-bypass-alert renders for subscriber-equivalent config', () => {
	const rendered = renderTemplate(TPL, {
		releaseBranches: ['build', 'uat'],
		requiredChecks: ['Static Code Analysis', 'Naming Validation'],
		runsOn: 'ubuntu-latest',
		nodeVersion: '20',
		slack: { enabled: true, webhook_env_var: 'SLACK_WEBHOOK_URL' },
	}, { views: path.dirname(TPL) });

	assert.match(rendered, /name: release-bypass-alert/);
	assert.match(rendered, /build/);
	assert.match(rendered, /SLACK_WEBHOOK_URL/);
});

test('release-bypass-alert branches list uses releaseBranches', () => {
	const rendered = renderTemplate(TPL, {
		releaseBranches: ['build', 'uat'],
		requiredChecks: ['Static Code Analysis', 'Naming Validation'],
		runsOn: 'ubuntu-latest',
		nodeVersion: '20',
		slack: { enabled: true, webhook_env_var: 'SLACK_WEBHOOK_URL' },
	}, { views: path.dirname(TPL) });

	assert.match(rendered, /branches: \[build, uat\]/);
});

test('release-bypass-alert uses runsOn value', () => {
	const rendered = renderTemplate(TPL, {
		releaseBranches: ['sit', 'uat', 'main'],
		requiredChecks: ['Static Code Analysis'],
		runsOn: 'self-hosted',
		nodeVersion: '20',
		slack: { enabled: true, webhook_env_var: 'MY_WEBHOOK' },
	}, { views: path.dirname(TPL) });

	assert.match(rendered, /runs-on: self-hosted/);
	assert.match(rendered, /MY_WEBHOOK/);
	assert.match(rendered, /branches: \[sit, uat, main\]/);
});

test('release-bypass-alert emits requiredChecks in header comments', () => {
	const rendered = renderTemplate(TPL, {
		releaseBranches: ['build', 'uat'],
		requiredChecks: ['Static Code Analysis', 'Naming Validation'],
		runsOn: 'ubuntu-latest',
		nodeVersion: '20',
		slack: { enabled: true, webhook_env_var: 'SLACK_WEBHOOK_URL' },
	}, { views: path.dirname(TPL) });

	assert.match(rendered, /Static Code Analysis/);
	assert.match(rendered, /Naming Validation/);
});

test('release-bypass-alert includes race-guard sleep 20', () => {
	const rendered = renderTemplate(TPL, {
		releaseBranches: ['build', 'uat'],
		requiredChecks: ['Static Code Analysis', 'Naming Validation'],
		runsOn: 'ubuntu-latest',
		nodeVersion: '20',
		slack: { enabled: true, webhook_env_var: 'SLACK_WEBHOOK_URL' },
	}, { views: path.dirname(TPL) });

	assert.match(rendered, /sleep 20/);
});

test('release-bypass-alert uses reviewDecision check not check-runs', () => {
	const rendered = renderTemplate(TPL, {
		releaseBranches: ['build', 'uat'],
		requiredChecks: ['Static Code Analysis'],
		runsOn: 'ubuntu-latest',
		nodeVersion: '20',
		slack: { enabled: true, webhook_env_var: 'SLACK_WEBHOOK_URL' },
	}, { views: path.dirname(TPL) });

	assert.match(rendered, /reviewDecision/);
	assert.match(rendered, /APPROVED/);
});
