// SPDX-License-Identifier: BUSL-1.1
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {logicalPath, currentVersion, resolveTargetUrl, toRouteSet} from './version-routing.mjs';

const LATEST = {line: '1.3', label: '1.3', base: '/', latest: true};
const V12 = {line: '1.2', label: '1.2', base: '/1.2/', latest: false};
const V11 = {line: '1.1', label: '1.1', base: '/1.1/', latest: false};
const VERSIONS = [LATEST, V12, V11];

test('logicalPath strips a frozen base, leaving the version-agnostic page path', () =>
{
	assert.equal(logicalPath('/1.2/fast-starts/triggers', '/1.2/'), 'fast-starts/triggers');
});

test('logicalPath under root base just trims the leading slash', () =>
{
	assert.equal(logicalPath('/installation', '/'), 'installation');
});

test('logicalPath maps each tree home to the empty logical path', () =>
{
	assert.equal(logicalPath('/', '/'), '');
	assert.equal(logicalPath('/1.2/', '/1.2/'), '');
	assert.equal(logicalPath('/1.2', '/1.2/'), '');
});

test('logicalPath does not strip a base that only prefixes the segment name', () =>
{
	// '/1.2x/...' is not under base '/1.2/' — must not be mistaken for it.
	assert.equal(logicalPath('/1.2x/guide', '/1.2/'), '1.2x/guide');
});

test('currentVersion matches the active base', () =>
{
	assert.equal(currentVersion(VERSIONS, '/1.2/'), V12);
	assert.equal(currentVersion(VERSIONS, '/'), LATEST);
});

test('currentVersion falls back to latest, then first, then null', () =>
{
	assert.equal(currentVersion(VERSIONS, '/9.9/'), LATEST);
	assert.equal(currentVersion([V12, V11], '/9.9/'), V12);
	assert.equal(currentVersion([], '/'), null);
});

test('resolveTargetUrl keeps the same page when it exists in the target tree', () =>
{
	const routes = toRouteSet(['fast-starts/triggers', 'installation']);
	assert.equal(resolveTargetUrl(V12, 'fast-starts/triggers', routes), '/1.2/fast-starts/triggers');
});

test('resolveTargetUrl falls back to the target home when the page is absent', () =>
{
	const routes = toRouteSet(['installation']);
	assert.equal(resolveTargetUrl(V12, 'fast-starts/triggers', routes), '/1.2/');
});

test('resolveTargetUrl falls back to home when the route list could not be loaded', () =>
{
	assert.equal(resolveTargetUrl(V12, 'fast-starts/triggers', null), '/1.2/');
});

test('resolveTargetUrl sends the home page to the target home', () =>
{
	assert.equal(resolveTargetUrl(V12, '', toRouteSet([])), '/1.2/');
});

test('resolveTargetUrl to latest builds a root-relative URL', () =>
{
	const routes = toRouteSet(['installation']);
	assert.equal(resolveTargetUrl(LATEST, 'installation', routes), '/installation');
});

test('toRouteSet normalises slugs and rejects non-arrays', () =>
{
	const set = toRouteSet(['/installation/', 'fast-starts/triggers']);
	assert.ok(set.has('installation'));
	assert.ok(set.has('fast-starts/triggers'));
	assert.equal(toRouteSet(null), null);
	assert.equal(toRouteSet({}), null);
});
