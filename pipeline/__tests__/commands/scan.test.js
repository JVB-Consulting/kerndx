// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {resolveChangedFiles, scanPatternsFor} = require('../../src/commands/scan.js');

test('scanPatternsFor returns the standard glob set for force-app default', () =>
{
	const patterns = scanPatternsFor(['force-app/main/default']);
	assert.deepEqual(patterns, [
		'force-app/main/default/**/*.cls',
		'force-app/main/default/**/*.trigger',
		'force-app/main/default/**/*.js',
		'force-app/main/default/**/*.html',
		'force-app/main/default/**/*.flow-meta.xml'
	]);
});

test('scanPatternsFor handles multiple package dirs', () =>
{
	const patterns = scanPatternsFor([
		'force-app/main/default',
		'unpackaged/main/default'
	]);
	assert.equal(patterns.length, 10);
	assert.ok(patterns.some(p => p.startsWith('unpackaged/')));
});
