// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {extractSelectorsFromText, normaliseList} = require('../../src/lib/scanner-parity.js');

test('extractSelectorsFromText finds --rule-selector args', () =>
{
	const text = 'sf code-analyzer run --rule-selector pmd,flow,eslint --target x.cls';
	assert.deepEqual(extractSelectorsFromText(text), ['eslint,flow,pmd']);
});

test('normaliseList sorts comma-delimited values', () =>
{
	assert.equal(normaliseList('pmd,flow,eslint'), 'eslint,flow,pmd');
});
