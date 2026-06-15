// SPDX-License-Identifier: BUSL-1.1
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {rewriteHomeLinks} from './home.mjs';

const REPO = 'https://github.com/JVB-Consulting/kerndx/blob/main';
const slugMap = new Map([
	[
		'Installation.md',
		'installation'
	],
	[
		'Fast Start - DML.md',
		'fast-start-dml'
	],
	[
		'release-notes/Release Notes - Kern 1.1.md',
		'release-notes-kern-1-1'
	],
	[
		'release-notes/Release Notes - Kern 1.0.md',
		'release-notes-kern-1-0'
	]
]);

test('docs/*.md links become slug URLs', () =>
{
	const out = rewriteHomeLinks('See [Install](docs/Installation.md) and [DML](docs/Fast%20Start%20-%20DML.md).', slugMap);
	assert.ok(out.includes('](/installation)'));
	assert.ok(out.includes('](/fast-start-dml)'));
});

test('./docs/*.md links (the synthesized public README form) resolve to slugs, not GitHub', () =>
{
	const out = rewriteHomeLinks('[Install](./docs/Installation.md) and [a](./docs/Installation.md#path-1)', slugMap);
	assert.ok(out.includes('](/installation)'));
	assert.ok(out.includes('](/installation#path-1)'));
	assert.ok(!out.includes('github.com'));
});

test('./release-notes/*.md links on the home resolve to the release-notes slug', () =>
{
	const out = rewriteHomeLinks('[RN](./release-notes/Release%20Notes%20-%20Kern%201.1.md)', slugMap);
	assert.ok(out.includes('](/release-notes-kern-1-1)'));
});

test('from a release note, a sibling and a ../docs link both resolve', () =>
{
	const body = 'See [1.0](./Release%20Notes%20-%20Kern%201.0.md) and [install](../docs/Installation.md).';
	const out = rewriteHomeLinks(body, slugMap, 'release-notes');
	assert.ok(out.includes('](/release-notes-kern-1-0)'));
	assert.ok(out.includes('](/installation)'));
});

test('AGENTS.md links to the on-site /agents page', () =>
{
	const out = rewriteHomeLinks('[Agents](AGENTS.md)', slugMap);
	assert.ok(out.includes('](/agents)'));
});

test('repo-admin files link to GitHub blobs', () =>
{
	const out = rewriteHomeLinks('[License](LICENSE) and [Contrib](CONTRIBUTING.md) and [Rules](CLAUDE.md)', slugMap);
	assert.ok(out.includes(`](${REPO}/LICENSE)`));
	assert.ok(out.includes(`](${REPO}/CONTRIBUTING.md)`));
	assert.ok(out.includes(`](${REPO}/CLAUDE.md)`));
});

test('strips local image refs but keeps remote badges (P0 spike finding)', () =>
{
	assert.equal(rewriteHomeLinks('![Coverage](./LICENSE) text', slugMap).trim(), 'text');
	const remote = '![badge](https://img.shields.io/x)';
	assert.ok(rewriteHomeLinks(remote, slugMap).includes(remote));
});

test('external links are untouched', () =>
{
	const url = 'https://developer.salesforce.com/x';
	assert.ok(rewriteHomeLinks(`[X](${url})`, slugMap).includes(`](${url})`));
});
