// SPDX-License-Identifier: Apache-2.0
// Checks movedTargetFor, which the theme uses to send an old link to a moved heading on to its new
// place, and fileForRoute, which finds a page's built HTML file for the prose report.
import {test} from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import {movedTargetFor} from '../.vitepress/theme/movedTarget.mjs';
import {fileForRoute} from './prose-report.mjs';

const FRONTMATTER = {movedAnchors: {'limits': '/strategic-guide-overview#logging-limits', 'café': '/#consoles', 'sizes': '/'}};

test('an old id listed in movedAnchors gives its new place', () =>
{
	assert.equal(movedTargetFor(FRONTMATTER, '#limits'), '/strategic-guide-overview#logging-limits');
	assert.equal(movedTargetFor(FRONTMATTER, '#sizes'), '/', 'Expected a whole page to be a new place');
});

test('an old id written with percent signs in the address is read as the id', () =>
{
	assert.equal(movedTargetFor(FRONTMATTER, '#caf%C3%A9'), '/#consoles');
});

test('an address that cannot be decoded is read as written', () =>
{
	assert.equal(movedTargetFor({movedAnchors: {'100%': '/'}}, '#100%'), '/');
});

test('an id that is not listed gives null', () =>
{
	assert.equal(movedTargetFor(FRONTMATTER, '#other'), null);
	assert.equal(movedTargetFor(FRONTMATTER, '#constructor'), null, 'Expected a name every object has to be no moved id');
	assert.equal(movedTargetFor(FRONTMATTER, '#__proto__'), null);
});

test('no hash, an empty hash, or a page with no movedAnchors gives null', () =>
{
	assert.equal(movedTargetFor(FRONTMATTER, ''), null);
	assert.equal(movedTargetFor(FRONTMATTER, '#'), null);
	assert.equal(movedTargetFor(FRONTMATTER, undefined), null);
	assert.equal(movedTargetFor(undefined, '#limits'), null);
	assert.equal(movedTargetFor({}, '#limits'), null);
	assert.equal(movedTargetFor({movedAnchors: '{"limits": "/"}'}, '#limits'), null, 'Expected movedAnchors as text, not an object, to be ignored');
});

test('a new place that is not text gives null', () =>
{
	assert.equal(movedTargetFor({movedAnchors: {limits: 42}}, '#limits'), null);
});

test('fileForRoute finds a page, a section index and the front page', () =>
{
	const dist = path.join('site', 'dist');
	assert.equal(fileForRoute(dist, '/logging-guide'), path.join(dist, 'logging-guide.html'));
	assert.equal(fileForRoute(dist, 'logging-guide'), path.join(dist, 'logging-guide.html'), 'Expected a route without its slash');
	assert.equal(fileForRoute(dist, '/logging-guide.html'), path.join(dist, 'logging-guide.html'), 'Expected a route with .html');
	assert.equal(fileForRoute(dist, '/reference/apex/'), path.join(dist, 'reference', 'apex', 'index.html'));
	assert.equal(fileForRoute(dist, '/'), path.join(dist, 'index.html'));
	assert.equal(fileForRoute(dist, ''), path.join(dist, 'index.html'));
	assert.equal(fileForRoute(dist, '//reference/apex/log-builder'), path.join(dist, 'reference', 'apex', 'log-builder.html'));
});
