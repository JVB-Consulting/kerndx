// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { parsePrePushStdin } = require('../../src/lib/diff-base.js');

test('parsePrePushStdin returns null for empty input', () => {
	assert.equal(parsePrePushStdin(''), null);
	assert.equal(parsePrePushStdin(null), null);
});

test('parsePrePushStdin returns remoteSha for well-formed line', () => {
	const stdin = 'refs/heads/feature/x abc123def456 refs/heads/feature/x 0123456789abcdef0123456789abcdef01234567\n';
	assert.deepEqual(parsePrePushStdin(stdin), { remoteSha: '0123456789abcdef0123456789abcdef01234567' });
});

test('parsePrePushStdin returns null for malformed line', () => {
	assert.equal(parsePrePushStdin('garbage'), null);
});
