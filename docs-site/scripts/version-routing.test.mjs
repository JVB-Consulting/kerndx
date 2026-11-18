// SPDX-License-Identifier: Apache-2.0
import {test} from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {logicalPath, currentVersion, resolveTargetUrl, toRouteSet, removedVersionTarget, removedVersionRedirectScript} from './version-routing.mjs';

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

// The site publishes the current docs at '/' and the older versions 1.8, 1.9 and 1.10.
const PUBLISHED = ['1.10', '1.9', '1.8'];

test('removedVersionTarget sends a page of a removed version to the same page in the current docs', () =>
{
	assert.equal(removedVersionTarget('/1.3/selectors-guide', PUBLISHED, '/'), '/selectors-guide');
	assert.equal(removedVersionTarget('/1.5/reference/apex/qry-builder', PUBLISHED, '/'), '/reference/apex/qry-builder');
	assert.equal(removedVersionTarget('/1.1/fast-starts/triggers/', PUBLISHED, '/'), '/fast-starts/triggers/');
});

test('removedVersionTarget sends the home of a removed version to the current home', () =>
{
	assert.equal(removedVersionTarget('/1.1/', PUBLISHED, '/'), '/');
	assert.equal(removedVersionTarget('/1.1', PUBLISHED, '/'), '/');
	assert.equal(removedVersionTarget('/1.7/index.html', PUBLISHED, '/'), '/index.html');
});

test('removedVersionTarget leaves a published older version alone', () =>
{
	assert.equal(removedVersionTarget('/1.9/selectors-guide', PUBLISHED, '/'), null);
	assert.equal(removedVersionTarget('/1.10/', PUBLISHED, '/'), null);
	assert.equal(removedVersionTarget('/1.8/no-such-page', PUBLISHED, '/'), null);
});

test('removedVersionTarget leaves the current docs and other addresses alone', () =>
{
	assert.equal(removedVersionTarget('/selectors-guide', PUBLISHED, '/'), null);
	assert.equal(removedVersionTarget('/', PUBLISHED, '/'), null);
	assert.equal(removedVersionTarget('/release-notes-kern-1-3', PUBLISHED, '/'), null);
	assert.equal(removedVersionTarget('/1.2x/guide', PUBLISHED, '/'), null);
	assert.equal(removedVersionTarget('/no-such-page', PUBLISHED, '/'), null);
});

test('removedVersionTarget keeps a project-page base', () =>
{
	assert.equal(removedVersionTarget('/YourRepo/1.3/selectors-guide', PUBLISHED, '/YourRepo/'), '/YourRepo/selectors-guide');
	assert.equal(removedVersionTarget('/YourRepo/1.3', PUBLISHED, '/YourRepo/'), '/YourRepo/');
	assert.equal(removedVersionTarget('/YourRepo/1.9/selectors-guide', PUBLISHED, '/YourRepo/'), null);
	assert.equal(removedVersionTarget('/Other/1.3/selectors-guide', PUBLISHED, '/YourRepo/'), null);
});

// Runs the "page not found" script against a pretend browser address and returns where it sent the reader.
function runRedirectScript(pathname, search = '', hash = '')
{
	const replaced = [];
	const location = {pathname, search, hash, replace: url => replaced.push(url)};
	vm.runInNewContext(removedVersionRedirectScript(PUBLISHED, '/'), {location});
	return replaced;
}

test('the page-not-found script opens the current page and keeps the query and section', () =>
{
	assert.deepEqual(runRedirectScript('/1.3/selectors-guide', '?q=1', '#joins'), ['/selectors-guide?q=1#joins']);
	assert.deepEqual(runRedirectScript('/1.1/'), ['/']);
});

test('the page-not-found script does nothing for a published version or the current docs', () =>
{
	assert.deepEqual(runRedirectScript('/1.9/selectors-guide'), []);
	assert.deepEqual(runRedirectScript('/no-such-page'), []);
});
