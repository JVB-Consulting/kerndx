// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { validateObject } = require('../../src/naming-engine/object.js');
const { buildPatterns } = require('../../src/naming-engine/config.js');

const SUBSCRIBER_CONFIG = {
	domains: ['SLS', 'ORD', 'PRD', 'SVC', 'SUB', 'MKT', 'CMN'],
	brands: ['ACM', 'BTA'],
	flow_types: ['BS'],
	apex_layers: ['SEL'],
	length_limits: { apex: 40, flow: 80 },
};

test('validateObject accepts SLS_Sale__c', () => {
	const patterns = buildPatterns(SUBSCRIBER_CONFIG);
	const dir = path.join(__dirname, '..', 'fixtures', 'subscriber-naming', 'objects', 'good', 'SLS_Sale__c');
	const result = validateObject(dir, patterns);
	assert.deepEqual(result.violations, []);
});

test('validateObject flags Bad_Sale__c (no domain prefix)', () => {
	const patterns = buildPatterns(SUBSCRIBER_CONFIG);
	const dir = path.join(__dirname, '..', 'fixtures', 'subscriber-naming', 'objects', 'bad', 'Bad_Sale__c');
	const result = validateObject(dir, patterns);
	assert.ok(result.violations.length >= 1);
	assert.ok(result.violations.some(v => /object-naming/i.test(v.rule)));
});
