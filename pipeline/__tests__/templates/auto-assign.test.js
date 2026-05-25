// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { renderTemplate } = require('../../src/lib/scaffold.js');

const TPL = path.join(__dirname, '..', '..', 'src', 'templates', 'workflows', 'auto-assign.yml.eta');

test('auto-assign renders for subscriber-equivalent config', () => {
	const rendered = renderTemplate(TPL, {
		protectedBranches: ['main', 'build', 'uat'],
		runsOn: 'ubuntu-latest',
		nodeVersion: '20',
		reviewers: { configFile: '.github/reviewers.json' },
	}, { views: path.dirname(TPL) });

	assert.match(rendered, /name: auto-assign/);
	assert.match(rendered, /\.github\/reviewers\.json/);
	assert.match(rendered, /pull_request_target/);
});

test('auto-assign branches list contains all protected branches', () => {
	const rendered = renderTemplate(TPL, {
		protectedBranches: ['main', 'build', 'uat'],
		runsOn: 'ubuntu-latest',
		nodeVersion: '20',
		reviewers: { configFile: '.github/reviewers.json' },
	}, { views: path.dirname(TPL) });

	assert.match(rendered, /branches: \[main, build, uat\]/);
});

test('auto-assign uses custom runsOn value', () => {
	const rendered = renderTemplate(TPL, {
		protectedBranches: ['main'],
		runsOn: 'self-hosted',
		nodeVersion: '20',
		reviewers: { configFile: '.github/reviewers.json' },
	}, { views: path.dirname(TPL) });

	assert.match(rendered, /runs-on: self-hosted/);
});

test('auto-assign uses custom reviewers configFile path', () => {
	const rendered = renderTemplate(TPL, {
		protectedBranches: ['main'],
		runsOn: 'ubuntu-latest',
		nodeVersion: '20',
		reviewers: { configFile: '.github/team/reviewers.json' },
	}, { views: path.dirname(TPL) });

	assert.match(rendered, /\.github\/team\/reviewers\.json/);
});

test('auto-assign slack_id comes from runtime reviewers.json data (not hardcoded)', () => {
	const rendered = renderTemplate(TPL, {
		protectedBranches: ['main', 'build', 'uat'],
		runsOn: 'ubuntu-latest',
		nodeVersion: '20',
		reviewers: { configFile: '.github/reviewers.json' },
	}, { views: path.dirname(TPL) });

	assert.match(rendered, /pick\.slack/);
	assert.doesNotMatch(rendered, /U0[A-Z0-9]{8}/);
});
