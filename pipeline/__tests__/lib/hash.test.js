// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {hashContent, hashFile} = require('../../src/lib/hash.js');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

test('hashContent is stable for identical input', () =>
{
	assert.equal(hashContent('hello\n'), hashContent('hello\n'));
});

test('hashContent normalizes CRLF to LF before hashing', () =>
{
	const withLf = 'line1\nline2\n';
	const withCrlf = 'line1\r\nline2\r\n';
	assert.equal(hashContent(withCrlf), hashContent(withLf), 'CRLF and LF versions of the same content must hash identically');
});

test('hashContent differs for different content', () =>
{
	assert.notEqual(hashContent('a'), hashContent('b'));
});

test('hashFile reads file + LF-normalizes', () =>
{
	const tmp = path.join(os.tmpdir(), `hash-test-${process.pid}.txt`);
	fs.writeFileSync(tmp, 'crlf\r\ncontent\r\n');
	try
	{
		const fromFile = hashFile(tmp);
		const fromContent = hashContent('crlf\ncontent\n');
		assert.equal(fromFile, fromContent);
	}
	finally
	{
		fs.unlinkSync(tmp);
	}
});
