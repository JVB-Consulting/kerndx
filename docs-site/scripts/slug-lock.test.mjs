// SPDX-License-Identifier: BUSL-1.1
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {diffSlugs} from './slug-lock.mjs';

test('no change -> ok', () =>
{
	const r = diffSlugs([
		'a',
		'b'
	], [
		'a',
		'b'
	], {});
	assert.deepEqual(r.removedWithoutRedirect, []);
	assert.deepEqual(r.added, []);
});

test('added slug is reported, not an error', () =>
{
	const r = diffSlugs(['a'], [
		'a',
		'b'
	], {});
	assert.deepEqual(r.added, ['b']);
	assert.deepEqual(r.removedWithoutRedirect, []);
});

test('removed slug without redirect is a failure', () =>
{
	const r = diffSlugs([
		'a',
		'b'
	], ['a'], {});
	assert.deepEqual(r.removedWithoutRedirect, ['b']);
});

test('removed slug WITH a redirect entry is allowed', () =>
{
	const r = diffSlugs([
		'a',
		'b'
	], ['a'], {b: 'a'});
	assert.deepEqual(r.removedWithoutRedirect, []);
});

test('a removed slug whose name is an Object.prototype key still fails without a real redirect', () =>
{
	// `'constructor' in {}` is true via the prototype chain — using `in` would silently treat
	// a removed slug named "constructor" (or "toString", "__proto__") as already redirected.
	const r = diffSlugs([
		'a',
		'constructor'
	], ['a'], {});
	assert.deepEqual(r.removedWithoutRedirect, ['constructor']);
});
