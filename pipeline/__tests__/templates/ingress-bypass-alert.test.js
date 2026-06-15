// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
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

test('ingress-bypass-alert emits required_checks as JSON array in shell', () =>
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

	assert.match(rendered, /required_checks=\["Static Code Analysis","Naming Validation"\]/);
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
