// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { validateField, getFieldPrefix } = require('../../src/naming-engine/field.js');
const { buildPatterns } = require('../../src/naming-engine/config.js');

const SUBSCRIBER_CONFIG = {
	domains: ['SLS', 'ORD', 'PRD', 'SVC'],
	brands: [],
	flow_types: [],
	apex_layers: [],
	length_limits: { apex: 40, flow: 80 },
};

test('getFieldPrefix extracts first underscore segment before __c', () => {
	assert.equal(getFieldPrefix('ORD_TrackingNumber__c'), 'ORD');
	assert.equal(getFieldPrefix('TrackingNumber__c'), null);
});

test('cross-domain-only: field with matching parent domain does NOT need prefix', () => {
	const patterns = buildPatterns(SUBSCRIBER_CONFIG);
	const result = validateField('Region__c', 'SLS_Account__c', patterns);
	assert.deepEqual(result.violations, []);
});

test('cross-domain-only: field on standard object MUST have prefix', () => {
	const patterns = buildPatterns(SUBSCRIBER_CONFIG);
	const result = validateField('CustomFlag__c', 'Account', patterns);
	assert.equal(result.violations.length, 1);
	assert.match(result.violations[0].rule, /field-prefix/i);
});

test('cross-domain-only: field with domain prefix matching parent is OK', () => {
	const patterns = buildPatterns(SUBSCRIBER_CONFIG);
	const result = validateField('ORD_TrackingNumber__c', 'ORD_Sale__c', patterns);
	assert.deepEqual(result.violations, []);
});
