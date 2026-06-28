// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const {renderTemplate} = require('../../src/lib/scaffold.js');

const TPL = path.join(__dirname, '..', '..', 'src', 'templates', 'code-analyzer.yml.eta');

test('code-analyzer.yml.eta renders with bundled-ruleset path', () =>
{
	const rendered = renderTemplate(TPL, {});
	assert.match(rendered, /engines:/);
	assert.match(rendered, /pmd:/);
	assert.match(rendered, /custom_rulesets:/);
	assert.match(rendered, /\.kerndx-pipeline\/scanner\/kerndx-pmd-ruleset\.xml/);
});

test('code-analyzer.yml.eta documents the framework-vs-subscriber ruleset distinction', () =>
{
	const rendered = renderTemplate(TPL, {});
	assert.match(rendered, /kerndx-pmd-ruleset\.xml/);
	assert.match(rendered, /kerndx-framework-ruleset\.xml/);
});

test('code-analyzer.yml.eta preserves SameRecordFieldUpdates Info-severity override', () =>
{
	const rendered = renderTemplate(TPL, {});
	assert.match(rendered, /SameRecordFieldUpdates/);
	assert.match(rendered, /severity: Info/);
});

test('code-analyzer.yml.eta preserves NoMixedIndentation tag-disable override', () =>
{
	const rendered = renderTemplate(TPL, {});
	assert.match(rendered, /NoMixedIndentation/);
	assert.match(rendered, /tags: \[\]/);
});
