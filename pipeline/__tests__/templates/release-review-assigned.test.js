// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const {renderTemplate} = require('../../src/lib/scaffold.js');

const TPL = path.join(__dirname, '..', '..', 'src', 'templates', 'workflows', 'release-review-assigned.yml.eta');

const BASE_DATA = {
	releaseBranches: [
		'build',
		'uat'
	], runsOn: 'ubuntu-latest', nodeVersion: '20', codeownersTeamSlackId: 'S01ABCDEF', slack: {enabled: true, webhook_env_var: 'SLACK_WEBHOOK_URL'}
};

test('release-review-assigned renders', () =>
{
	const rendered = renderTemplate(TPL, BASE_DATA, {views: path.dirname(TPL)});

	assert.match(rendered, /name: release-review-assigned/);
	assert.match(rendered, /SLACK_WEBHOOK_URL/);
});

test('release-review-assigned uses runsOn value', () =>
{
	const rendered = renderTemplate(TPL, {...BASE_DATA, runsOn: 'self-hosted'}, {views: path.dirname(TPL)});

	assert.match(rendered, /runs-on: self-hosted/);
});

test('release-review-assigned renders releaseBranches in if condition', () =>
{
	const rendered = renderTemplate(TPL, BASE_DATA, {views: path.dirname(TPL)});

	assert.match(rendered, /base\.ref == 'build'/);
	assert.match(rendered, /base\.ref == 'uat'/);
});

test('release-review-assigned backprom PROTECTED includes releaseBranches', () =>
{
	const rendered = renderTemplate(TPL, BASE_DATA, {views: path.dirname(TPL)});

	assert.match(rendered, /build\|uat/);
});

test('release-review-assigned injects codeownersTeamSlackId as fallback', () =>
{
	const rendered = renderTemplate(TPL, {...BASE_DATA, codeownersTeamSlackId: 'S99TESTID'}, {views: path.dirname(TPL)});

	assert.match(rendered, /S99TESTID/);
});

test('release-review-assigned includes idempotency label dedup logic', () =>
{
	const rendered = renderTemplate(TPL, BASE_DATA, {views: path.dirname(TPL)});

	assert.match(rendered, /bot-release-admins-pinged/);
	assert.match(rendered, /should_notify/);
});

test('release-review-assigned includes clear-dedup-label job', () =>
{
	const rendered = renderTemplate(TPL, BASE_DATA, {views: path.dirname(TPL)});

	assert.match(rendered, /clear-dedup-label/);
	assert.match(rendered, /review_request_removed/);
});

test('release-review-assigned suppresses [E2E] prefixed PRs', () =>
{
	const rendered = renderTemplate(TPL, BASE_DATA, {views: path.dirname(TPL)});

	assert.match(rendered, /\[E2E\]/);
});
