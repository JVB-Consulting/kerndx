// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { renderTemplate } = require('../../src/lib/scaffold.js');

const TPL = path.join(__dirname, '..', '..', 'src', 'templates', 'rulesets', 'ingress-gate.json.eta');

const BASE_DATA = {
	ingressBranches: ['main', 'build'],
	requiredChecks: ['Static Code Analysis', 'Naming Validation'],
	bypassActors: [],
};

test('ingress-gate renders parseable JSON', () => {
	const rendered = renderTemplate(TPL, BASE_DATA);
	const parsed = JSON.parse(rendered);
	assert.equal(parsed.name, 'Ingress Gate');
});

test('ingress-gate includes both ingress branches as refs', () => {
	const rendered = renderTemplate(TPL, BASE_DATA);
	const parsed = JSON.parse(rendered);
	const includes = parsed.conditions.ref_name.include;
	assert.ok(includes.includes('refs/heads/main'), 'main missing');
	assert.ok(includes.includes('refs/heads/build'), 'build missing');
});

test('ingress-gate required_status_checks contains all check names', () => {
	const rendered = renderTemplate(TPL, BASE_DATA);
	const parsed = JSON.parse(rendered);
	const checksRule = parsed.rules.find(r => r.type === 'required_status_checks');
	const contexts = checksRule.parameters.required_status_checks.map(c => c.context);
	assert.ok(contexts.includes('Static Code Analysis'));
	assert.ok(contexts.includes('Naming Validation'));
});

test('ingress-gate bypass_actors is empty array by default', () => {
	const rendered = renderTemplate(TPL, BASE_DATA);
	const parsed = JSON.parse(rendered);
	assert.deepEqual(parsed.bypass_actors, []);
});

test('ingress-gate bypass_actors propagates when provided', () => {
	const rendered = renderTemplate(TPL, { ...BASE_DATA, bypassActors: [{ actor_id: 1, actor_type: 'Team' }] });
	const parsed = JSON.parse(rendered);
	assert.equal(parsed.bypass_actors.length, 1);
	assert.equal(parsed.bypass_actors[0].actor_id, 1);
});

test('ingress-gate only one branch fails assertion for two-branch test', () => {
	const rendered = renderTemplate(TPL, { ...BASE_DATA, ingressBranches: ['main'] });
	const parsed = JSON.parse(rendered);
	const includes = parsed.conditions.ref_name.include;
	assert.ok(includes.includes('refs/heads/main'));
	assert.ok(!includes.includes('refs/heads/build'), 'build should not be present');
});
