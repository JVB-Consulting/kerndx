// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { resolve } = require('../../src/adapters/index.js');

test('resolve(none) returns the none adapter', () => {
	const a = resolve({ name: 'none' }, { protected_branches: ['main'] });
	assert.equal(a.name, 'none');
	assert.equal(typeof a.classifyHeadRef, 'function');
});

test('resolve rejects experimental adapter without ack', () => {
	assert.throws(() => resolve({ name: 'copado' }, { protected_branches: ['main'] }), /experimental/);
});

test('resolve accepts copado with experimental: true', () => {
	const a = resolve({ name: 'copado', experimental: true }, { protected_branches: ['main'] });
	assert.equal(a.name, 'copado');
});

test('resolve rejects unknown adapter name', () => {
	assert.throws(() => resolve({ name: 'unicorn' }, { protected_branches: ['main'] }), /unknown adapter/i);
});
