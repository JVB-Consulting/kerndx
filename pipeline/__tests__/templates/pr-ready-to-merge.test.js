// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const {renderTemplate} = require('../../src/lib/scaffold.js');

const TPL = path.join(__dirname, '..', '..', 'src', 'templates', 'workflows', 'pr-ready-to-merge.yml.eta');

test('pr-ready-to-merge renders for subscriber-equivalent config', () =>
{
	const rendered = renderTemplate(TPL, {
		protectedBranches: [
			'main',
			'build',
			'uat'
		], runsOn: 'ubuntu-latest', nodeVersion: '20', slack: {enabled: true, webhook_env_var: 'SLACK_WEBHOOK_URL'}
	}, {views: path.dirname(TPL)});

	assert.match(rendered, /name: pr-ready-to-merge/);
	assert.match(rendered, /SLACK_WEBHOOK_URL/);
});

test('pr-ready-to-merge uses custom runsOn value', () =>
{
	const rendered = renderTemplate(TPL, {
		protectedBranches: ['main'], runsOn: 'self-hosted', nodeVersion: '20', slack: {enabled: true, webhook_env_var: 'SLACK_WEBHOOK_URL'}
	}, {views: path.dirname(TPL)});

	assert.match(rendered, /runs-on: self-hosted/);
});

test('pr-ready-to-merge includes all protected branches in backprom regex', () =>
{
	const rendered = renderTemplate(TPL, {
		protectedBranches: [
			'main',
			'build',
			'uat'
		], runsOn: 'ubuntu-latest', nodeVersion: '20', slack: {enabled: true, webhook_env_var: 'SLACK_WEBHOOK_URL'}
	}, {views: path.dirname(TPL)});

	assert.match(rendered, /main/);
	assert.match(rendered, /build/);
	assert.match(rendered, /uat/);
});

test('pr-ready-to-merge uses custom slack webhook_env_var', () =>
{
	const rendered = renderTemplate(TPL, {
		protectedBranches: ['main'], runsOn: 'ubuntu-latest', nodeVersion: '20', slack: {enabled: true, webhook_env_var: 'MY_CUSTOM_WEBHOOK'}
	}, {views: path.dirname(TPL)});

	assert.match(rendered, /MY_CUSTOM_WEBHOOK/);
	assert.doesNotMatch(rendered, /SLACK_WEBHOOK_URL/);
});

test('pr-ready-to-merge omits Slack step when slack.enabled is false', () =>
{
	const rendered = renderTemplate(TPL, {
		protectedBranches: ['main'], runsOn: 'ubuntu-latest', nodeVersion: '20', slack: {enabled: false, webhook_env_var: 'SLACK_WEBHOOK_URL'}
	}, {views: path.dirname(TPL)});

	assert.doesNotMatch(rendered, /slackapi\/slack-github-action/);
	assert.doesNotMatch(rendered, /SLACK_WEBHOOK_URL/);
});

test('pr-ready-to-merge reads reviewers.json from main branch', () =>
{
	const rendered = renderTemplate(TPL, {
		protectedBranches: ['main'], runsOn: 'ubuntu-latest', nodeVersion: '20', slack: {enabled: true, webhook_env_var: 'SLACK_WEBHOOK_URL'}
	}, {views: path.dirname(TPL)});

	assert.match(rendered, /reviewers\.json/);
	assert.match(rendered, /ref: 'main'/);
});

test('pr-ready-to-merge does not hardcode any Slack user IDs', () =>
{
	const rendered = renderTemplate(TPL, {
		protectedBranches: [
			'main',
			'build',
			'uat'
		], runsOn: 'ubuntu-latest', nodeVersion: '20', slack: {enabled: true, webhook_env_var: 'SLACK_WEBHOOK_URL'}
	}, {views: path.dirname(TPL)});

	assert.doesNotMatch(rendered, /U0[A-Z0-9]{8}/);
});
