// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { runPreflight } = require('../../src/commands/preflight.js');

test('preflight exports runPreflight function', () => {
	assert.equal(typeof runPreflight, 'function');
});
