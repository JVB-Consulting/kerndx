// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const {renderTemplate} = require('../../src/lib/scaffold.js');

const TPL = path.join(__dirname, '..', '..', 'src', 'templates', 'workflows', 'validate-reviewers-json.yml.eta');

test('validate-reviewers-json renders', () =>
{
	const rendered = renderTemplate(TPL, {
		runsOn: 'ubuntu-latest', nodeVersion: '20', reviewers: {configFile: '.github/reviewers.json', schemaFile: '.github/reviewers.schema.json'}
	}, {views: path.dirname(TPL)});

	assert.match(rendered, /name: validate-reviewers-json/);
	assert.match(rendered, /-d \.github\/reviewers\.json/);
	assert.match(rendered, /-s \.github\/reviewers\.schema\.json/);
});

test('validate-reviewers-json runs-on line is well-formed (no eta tag fusion)', () =>
{
	// Regression L10: `<%~ runsOn %>` fused runs-on into the next line.
	const rendered = renderTemplate(TPL, {
		runsOn: 'ubuntu-latest', nodeVersion: '20', reviewers: {configFile: '.github/reviewers.json', schemaFile: '.github/reviewers.schema.json'}
	}, {views: path.dirname(TPL)});

	assert.match(rendered, /runs-on: ubuntu-latest\n\s+steps:/);
});
