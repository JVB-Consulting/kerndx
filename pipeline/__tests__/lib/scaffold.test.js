// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const fs = require('node:fs');
const os = require('node:os');
const { renderTemplate } = require('../../src/lib/scaffold.js');

test('renderTemplate substitutes config values', () => {
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'tpl-'));
	const tmpl = path.join(dir, 'sample.eta');
	fs.writeFileSync(tmpl, 'hello <%= name %>');
	const out = renderTemplate(tmpl, { name: 'world' });
	assert.equal(out, 'hello world');
});

test('renderTemplate honors partials directory', () => {
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'tpl-'));
	const partials = path.join(dir, '_partials');
	fs.mkdirSync(partials);
	fs.writeFileSync(path.join(partials, '_hello.eta'), 'Hello, <%= name %>!');
	const tmpl = path.join(dir, 'page.eta');
	fs.writeFileSync(tmpl, '<%~ include("_partials/_hello", { name: name }) %>');
	const out = renderTemplate(tmpl, { name: 'world' }, { views: dir });
	assert.match(out, /Hello, world!/);
});
