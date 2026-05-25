// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const copado = require('../../src/adapters/copado.js');

const adapter = copado.build({ name: 'copado', experimental: true }, { protected_branches: ['main'] });

test('promotion/<storyId>-DeployTo<env> matches as back-promotion (verified Copado pattern)', () => {
	assert.deepEqual(adapter.classifyHeadRef('promotion/P0001-DeployToUAT'),
		{ action: 'skip-scan', label: 'back-promotion' });
});

test('promotion to production also matches', () => {
	assert.deepEqual(adapter.classifyHeadRef('promotion/P0042-DeployToProduction'),
		{ action: 'skip-scan', label: 'back-promotion' });
});

test('back-promotion to Dev (forward-and-back use same pattern in Copado)', () => {
	assert.deepEqual(adapter.classifyHeadRef('promotion/P0019-DeployToDev'),
		{ action: 'skip-scan', label: 'back-promotion' });
});

test('feature branch unaffected', () => {
	assert.deepEqual(adapter.classifyHeadRef('feature/US-0000123'),
		{ action: 'full-scan', label: 'normal' });
});

test("plan's hypothetical cmc/promote pattern is NOT a back-promotion (regression-guard)", () => {
	// The plan's original speculative regex was ^cmc/promote-(.+)-to-(.+)$.
	// This adapter SHOULD NOT match cmc/promote-* since Copado does not use that prefix.
	// If a future change reintroduces the wrong regex, this test catches it.
	assert.deepEqual(adapter.classifyHeadRef('cmc/promote-dev-to-uat'),
		{ action: 'full-scan', label: 'normal' });
});
