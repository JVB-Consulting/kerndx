// SPDX-License-Identifier: BUSL-1.1
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {repoUrl, DEFAULT_REPO_URL} from './repo.mjs';

test('repoUrl defaults to the production mirror repo', () =>
{
	assert.equal(DEFAULT_REPO_URL, 'https://github.com/JVB-Consulting/kerndx');
	assert.equal(repoUrl({}), DEFAULT_REPO_URL);
});

test('repoUrl honors REPO_URL for per-repo (clone / rehearsal / ephemeral) deploys', () =>
{
	assert.equal(
		repoUrl({REPO_URL: 'https://github.com/JVB-Consulting/kerndx-rehearsal'}),
		'https://github.com/JVB-Consulting/kerndx-rehearsal'
	);
});

test('repoUrl trims and falls back to the default on empty / whitespace REPO_URL', () =>
{
	assert.equal(repoUrl({REPO_URL: ''}), DEFAULT_REPO_URL);
	assert.equal(repoUrl({REPO_URL: '   '}), DEFAULT_REPO_URL);
	assert.equal(repoUrl({REPO_URL: '  https://github.com/x/y  '}), 'https://github.com/x/y');
});
