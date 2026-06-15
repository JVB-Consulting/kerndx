// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {buildPatterns} = require('../../src/naming-engine/config.js');

test('buildPatterns assembles flow regex from domains, brands, flow_types', () =>
{
	const patterns = buildPatterns({
		domains: [
			'SLS',
			'ORD'
		],
		brands: ['ACM'],
		flow_types: [
			'BS',
			'AS'
		],
		apex_layers: [
			'SEL',
			'TRG'
		],
		length_limits: {apex: 40, flow: 80}
	});
	// Flow pattern: Domain_[Brand_]Object_Type_Action
	assert.ok(patterns.flow.test('SLS_Account_BS_SetDefaults'));
	assert.ok(patterns.flow.test('ORD_ACM_Order_AS_NotifyCustomer'));
	assert.ok(!patterns.flow.test('BadFlowNoDomain'));
});

test('buildPatterns flow pattern rejects non-allowlisted domain', () =>
{
	const patterns = buildPatterns({
		domains: ['SLS'], brands: [], flow_types: ['BS'], apex_layers: [], length_limits: {apex: 40, flow: 80}
	});
	assert.ok(!patterns.flow.test('UNKNOWN_Account_BS_DoStuff'));
});

test('buildPatterns handles empty brands array (no brand segment required)', () =>
{
	const patterns = buildPatterns({
		domains: ['SLS'], brands: [], flow_types: ['BS'], apex_layers: [], length_limits: {apex: 40, flow: 80}
	});
	assert.ok(patterns.flow.test('SLS_Account_BS_SetDefaults'));
});
