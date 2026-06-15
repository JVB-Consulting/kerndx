// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const {renderTemplate} = require('../../src/lib/scaffold.js');

const TPL = path.join(__dirname, '..', '..', 'src', 'templates', 'rulesets', 'release-gate.json.eta');

const BASE_DATA = {
	releaseBranches: [
		's.i.t',
		'uat',
		'main'
	], bypassActors: []
};

test('release-gate renders parseable JSON', () =>
{
	const rendered = renderTemplate(TPL, BASE_DATA);
	const parsed = JSON.parse(rendered);
	assert.equal(parsed.name, 'Release Gate');
});

test('release-gate includes all release branches as refs', () =>
{
	const rendered = renderTemplate(TPL, BASE_DATA);
	const parsed = JSON.parse(rendered);
	const includes = parsed.conditions.ref_name.include;
	assert.ok(includes.includes('refs/heads/s.i.t'), 's.i.t missing');
	assert.ok(includes.includes('refs/heads/uat'), 'uat missing');
	assert.ok(includes.includes('refs/heads/main'), 'main missing');
});

test('release-gate pull_request rule has stricter settings than ingress', () =>
{
	const rendered = renderTemplate(TPL, BASE_DATA);
	const parsed = JSON.parse(rendered);
	const prRule = parsed.rules.find(r => r.type === 'pull_request');
	assert.equal(prRule.parameters.dismiss_stale_reviews_on_push, true);
	assert.equal(prRule.parameters.require_code_owner_review, true);
	assert.equal(prRule.parameters.require_last_push_approval, true);
	assert.equal(prRule.parameters.required_review_thread_resolution, true);
});

test('release-gate has no required_status_checks rule', () =>
{
	const rendered = renderTemplate(TPL, BASE_DATA);
	const parsed = JSON.parse(rendered);
	const checksRule = parsed.rules.find(r => r.type === 'required_status_checks');
	assert.equal(checksRule, undefined);
});

test('release-gate bypass_actors is empty array by default', () =>
{
	const rendered = renderTemplate(TPL, BASE_DATA);
	const parsed = JSON.parse(rendered);
	assert.deepEqual(parsed.bypass_actors, []);
});

test('release-gate bypass_actors propagates when provided', () =>
{
	const rendered = renderTemplate(TPL, {...BASE_DATA, bypassActors: [{actor_id: 5, actor_type: 'Team'}]});
	const parsed = JSON.parse(rendered);
	assert.equal(parsed.bypass_actors.length, 1);
	assert.equal(parsed.bypass_actors[0].actor_id, 5);
});
