// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { validateFlow } = require('../../src/naming-engine/flow.js');
const { buildPatterns } = require('../../src/naming-engine/config.js');

const SUBSCRIBER_CONFIG = {
	domains: ['SLS', 'ORD', 'PRD', 'SVC', 'SUB', 'MKT', 'CMN'],
	brands: ['ACM', 'BTA'],
	flow_types: ['BS', 'AS', 'BD', 'SCR', 'AL', 'SCH', 'PE', 'SF'],
	apex_layers: ['SEL'],
	length_limits: { apex: 40, flow: 80 },
};

test('validateFlow accepts a well-named subscriber flow', () => {
	const patterns = buildPatterns(SUBSCRIBER_CONFIG);
	const file = path.join(__dirname, '..', 'fixtures', 'subscriber-naming', 'flows', 'good', 'SLS_Account_BS_SetDefaults.flow-meta.xml');
	const result = validateFlow(file, patterns);
	assert.deepEqual(result.violations, []);
});

test('validateFlow flags a flow without domain prefix', () => {
	const patterns = buildPatterns(SUBSCRIBER_CONFIG);
	const file = path.join(__dirname, '..', 'fixtures', 'subscriber-naming', 'flows', 'bad', 'BadFlowNoDomain.flow-meta.xml');
	const result = validateFlow(file, patterns);
	assert.equal(result.violations.length, 1);
	assert.match(result.violations[0].rule, /flow-naming/i);
});

test('validateFlow flags a flow exceeding 80 chars', () => {
	const patterns = buildPatterns(SUBSCRIBER_CONFIG);
	// Synthesise: use a flow name 81 chars long that otherwise matches
	const longName = 'SLS_' + 'A'.repeat(76) + '_BS_X'; // 4 + 76 + 5 = 85 chars
	const result = validateFlow('/tmp/' + longName + '.flow-meta.xml', patterns, { skipReadFile: true, label: longName });
	assert.ok(result.violations.some(v => /length/i.test(v.rule)));
});
