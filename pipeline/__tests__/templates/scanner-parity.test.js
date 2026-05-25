// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { renderTemplate } = require('../../src/lib/scaffold.js');

const TPL = path.join(__dirname, '..', '..', 'src', 'templates', 'workflows', 'scanner-parity.yml.eta');

test('scanner-parity renders', () => {
	const rendered = renderTemplate(TPL, {
		runsOn: 'ubuntu-latest',
		nodeVersion: '20',
	}, { views: path.dirname(TPL) });

	assert.match(rendered, /name: scanner-parity/);
	assert.match(rendered, /node-version: ['"]20['"]/);
});

test('scanner-parity uses custom runsOn value', () => {
	const rendered = renderTemplate(TPL, {
		runsOn: 'self-hosted',
		nodeVersion: '20',
	}, { views: path.dirname(TPL) });

	assert.match(rendered, /runs-on: self-hosted/);
});

test('scanner-parity default sources include only files that use --rule-selector CLI flag', () => {
	// Regression L11: prior default included code-analyzer.yml in checkParity sources,
	// but that's a config file (never contains --rule-selector). False positive every PR.
	const rendered = renderTemplate(TPL, {
		runsOn: 'ubuntu-latest',
		nodeVersion: '20',
	}, { views: path.dirname(TPL) });

	assert.match(rendered, /sfca-quality-gate\.yml/);
	// scanner-parity paths filter still mentions package.json (subscriber extension point)
	assert.match(rendered, /package\.json/);
	// Default checkParity call must NOT pass code-analyzer.yml as a source
	assert.doesNotMatch(rendered, /'code-analyzer config': 'code-analyzer\.yml'/);
});

test('scanner-parity references the bundled pipeline (zip distribution)', () => {
	// Regression L10: prior template did `npm install @jvb-consulting/kerndx-pipeline`
	// — that package was never published. Bundle ships in .kerndx-pipeline/pipeline/
	// and the workflow should require from there.
	const rendered = renderTemplate(TPL, {
		runsOn: 'ubuntu-latest',
		nodeVersion: '20',
	}, { views: path.dirname(TPL) });

	assert.match(rendered, /\.kerndx-pipeline\/pipeline\/src\/lib\/scanner-parity\.js/);
	assert.match(rendered, /npm ci --omit=dev/);
	assert.doesNotMatch(rendered, /@jvb-consulting\/kerndx-pipeline/);
	assert.doesNotMatch(rendered, /npm install @/);
});

test('scanner-parity runs-on line is well-formed YAML (no eta tag fusion)', () => {
	// Regression L10: prior template used `<%~ runsOn %>` which fused
	// `runs-on: ubuntu-latest` with the next line's `permissions:`, breaking
	// the YAML. Verify the line ends with a newline before the next key.
	const rendered = renderTemplate(TPL, {
		runsOn: 'ubuntu-latest',
		nodeVersion: '20',
	}, { views: path.dirname(TPL) });

	assert.match(rendered, /runs-on: ubuntu-latest\n\s+permissions:/);
});
