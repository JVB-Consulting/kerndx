// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const autorabit = require('../../src/adapters/autorabit.js');

const adapter = autorabit.build({name: 'autorabit', experimental: true}, {protected_branches: ['main']});

test('autorabit returns full-scan/normal for every ref (verified-as-none per Phase 0.3)', () =>
{
	// AutoRABIT does NOT intercept PRs by branch renaming; it uses direct merges via UI.
	// No prefix exists to skip on; all PRs go through full scan.
	assert.deepEqual(adapter.classifyHeadRef('main'), {action: 'full-scan', label: 'normal'});
	assert.deepEqual(adapter.classifyHeadRef('feature/my-thing'), {action: 'full-scan', label: 'normal'});
	assert.deepEqual(adapter.classifyHeadRef('autorabit/promotion-anything'), {action: 'full-scan', label: 'normal'});
});

test('plan\'s speculative autorabit/promotion-* pattern is NOT a back-promotion (regression-guard)', () =>
{
	// The plan speculated AutoRABIT might use autorabit/promotion-* or cab-* prefixes.
	// Phase 0.3 verification found neither convention exists. If a future change reintroduces
	// either speculative regex, this test catches it.
	assert.deepEqual(adapter.classifyHeadRef('autorabit/promotion-build-to-uat'), {action: 'full-scan', label: 'normal'});
	assert.deepEqual(adapter.classifyHeadRef('cab-release-2026-05'), {action: 'full-scan', label: 'normal'});
});

test('autorabit name is correctly set', () =>
{
	assert.equal(adapter.name, 'autorabit');
});
