// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const {renderTemplate} = require('../../src/lib/scaffold.js');

const TPL = path.join(__dirname, '..', '..', 'src', 'templates', 'workflows', 'naming-validation.yml.eta');
const VIEWS = path.join(__dirname, '..', '..', 'src', 'templates', 'workflows');

test('naming-validation renders for subscriber-equivalent config', () =>
{
	const rendered = renderTemplate(TPL, {
		ingressBranches: [
			'build',
			'main'
		], packageDirs: ['unpackaged/main/default'], nodeVersion: '20', runsOn: 'ubuntu-latest'
	}, {views: VIEWS});

	assert.match(rendered, /name: naming-validation/);
	assert.match(rendered, /branches:.*build.*main/);
	assert.match(rendered, /\.\/\.kerndx-pipeline\/bin\/kerndx naming --ci/);
	assert.match(rendered, /node-version: ['"]20['"]/);
});

test('naming-validation uses the runsOn value', () =>
{
	const rendered = renderTemplate(TPL, {
		ingressBranches: ['main'], packageDirs: ['force-app/main/default'], nodeVersion: '20', runsOn: 'self-hosted'
	}, {views: VIEWS});

	assert.match(rendered, /runs-on: self-hosted/);
	assert.match(rendered, /branches:.*main/);
	assert.doesNotMatch(rendered, /branches:.*build/);
});

test('naming-validation locks node 20 in the bootstrap partial', () =>
{
	// _classify-ref partial hardcodes node 20 for CLI compatibility.
	// nodeVersion data is no longer honored in the rendered output.
	const rendered = renderTemplate(TPL, {
		ingressBranches: ['main'], packageDirs: ['force-app/main/default'], nodeVersion: '18', runsOn: 'ubuntu-latest'
	}, {views: VIEWS});
	assert.match(rendered, /node-version: ['"]20['"]/);
	assert.doesNotMatch(rendered, /node-version: ['"]18['"]/);
});

test('naming-validation includes back-promotion skip logic', () =>
{
	const rendered = renderTemplate(TPL, {
		ingressBranches: [
			'build',
			'main'
		], packageDirs: ['unpackaged/main/default'], nodeVersion: '20', runsOn: 'ubuntu-latest'
	}, {views: VIEWS});

	assert.match(rendered, /classify-ref|classify/);
	assert.match(rendered, /is_backprom/);
});

test('naming-validation scopes diff to packageDirs', () =>
{
	const rendered = renderTemplate(TPL, {
		ingressBranches: [
			'build',
			'main'
		], packageDirs: ['unpackaged/main/default'], nodeVersion: '20', runsOn: 'ubuntu-latest'
	}, {views: VIEWS});

	assert.match(rendered, /unpackaged\/main\/default/);
});

test('naming-validation uses explicit merge-base for PR diff', () =>
{
	const rendered = renderTemplate(TPL, {
		ingressBranches: ['main'], packageDirs: ['force-app/main/default'], nodeVersion: '20', runsOn: 'ubuntu-latest'
	}, {views: VIEWS});

	assert.match(rendered, /BASE_SHA=\$\(git merge-base "\$BASE_REF" HEAD\)/);
	assert.match(rendered, /git diff --name-only "\$BASE_SHA" "\$HEAD_SHA" --/);
	assert.doesNotMatch(rendered, /origin\/.*\.\.\.HEAD/);
});

test('naming-validation diff command ends with proper redirect (no orphan)', () =>
{
	const rendered = renderTemplate(TPL, {
		ingressBranches: ['main'],
		packageDirs: [
			'force-app/main/default',
			'src-shared'
		],
		nodeVersion: '20',
		runsOn: 'ubuntu-latest'
	}, {views: VIEWS});

	const start = rendered.indexOf('git diff --name-only');
	const end = rendered.indexOf('changed-naming-files.txt', start);
	assert.ok(start !== -1 && end !== -1, 'diff block must exist');
	const block = rendered.slice(start, end + 'changed-naming-files.txt'.length);
	const lines = block.split('\n');
	for(let i = 0; i < lines.length - 1; i++)
	{
		const line = lines[i].trimEnd();
		assert.ok(line.endsWith('\\'), `line ${i} must end with backslash continuation: ${JSON.stringify(line)}`);
	}
	assert.match(lines[lines.length - 1], /^\s*> changed-naming-files\.txt\s*$/);
});
