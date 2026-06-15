// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const {renderTemplate} = require('../../src/lib/scaffold.js');

const TPL = path.join(__dirname, '..', '..', 'src', 'templates', 'workflows', 'secret-scan.yml.eta');
const VIEWS = path.join(__dirname, '..', '..', 'src', 'templates', 'workflows');

function render(data)
{
	return renderTemplate(TPL, Object.assign({
		ingressBranches: [
			'build',
			'main'
		], packageDirs: ['force-app/main/default'], runsOn: 'ubuntu-latest'
	}, data || {}), {views: VIEWS});
}

test('secret-scan renders for subscriber-equivalent config', () =>
{
	const rendered = render();
	assert.match(rendered, /name: secret-scan/);
	assert.match(rendered, /name: Secret Scan/);
	assert.match(rendered, /branches:.*build.*main/);
	assert.match(rendered, /\.\/\.kerndx-pipeline\/bin\/kerndx secret-scan --ci/);
});

test('secret-scan uses the runsOn value', () =>
{
	const rendered = render({ingressBranches: ['main'], runsOn: 'self-hosted'});
	assert.match(rendered, /runs-on: self-hosted/);
	assert.match(rendered, /branches:.*main/);
	assert.doesNotMatch(rendered, /branches:.*build/);
});

test('secret-scan includes back-promotion skip logic via the partial', () =>
{
	const rendered = render();
	assert.match(rendered, /classify-ref|classify/);
	assert.match(rendered, /is_backprom/);
	// The partial pins node 20 + fetch-depth:0 (needed for merge-base diff base).
	assert.match(rendered, /node-version: ['"]20['"]/);
	assert.match(rendered, /fetch-depth: 0/);
});

test('secret-scan has NO active paths filter (secrets can land in any file)', () =>
{
	const rendered = render();
	const onBlock = rendered.slice(rendered.indexOf('on:'), rendered.indexOf('jobs:'));
	for(const line of onBlock.split('\n'))
	{
		if(line.trim().startsWith('#'))
		{
			continue;
		} // the explanatory comment mentions the word
		assert.doesNotMatch(line, /^\s*paths:/, `unexpected active paths filter: ${line}`);
	}
});

test('secret-scan requests only read permissions', () =>
{
	const rendered = render();
	assert.match(rendered, /contents: read/);
	assert.match(rendered, /pull-requests: read/);
	assert.doesNotMatch(rendered, /pull-requests: write/);
});
