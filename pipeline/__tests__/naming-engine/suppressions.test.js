// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { loadSuppressions } = require('../../src/naming-engine/suppressions.js');

function tmpFile(content) {
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'supp-'));
	const file = path.join(dir, 'suppressions.yml');
	fs.writeFileSync(file, content);
	return file;
}

test('loadSuppressions accepts well-formed manifest', () => {
	const file = tmpFile(`
suppressions:
  - path: force-app/main/default/flows/legacy/OldFlow.flow-meta.xml
    checks: [naming]
    reason: Brownfield legacy flow scheduled for rename in Q3 cleanup
    owner: team-x
`);
	const { suppressions, errors } = loadSuppressions(file);
	assert.deepEqual(errors, []);
	assert.equal(suppressions.size, 1);
});

test('loadSuppressions rejects short reason', () => {
	const file = tmpFile(`
suppressions:
  - path: x.flow-meta.xml
    checks: [naming]
    reason: short
`);
	const { errors } = loadSuppressions(file);
	assert.ok(errors.length >= 1);
	assert.match(errors[0], /20 characters/);
});

test('loadSuppressions returns empty map when file missing', () => {
	const { suppressions, errors } = loadSuppressions('/nonexistent/path');
	assert.deepEqual(errors, []);
	assert.equal(suppressions.size, 0);
});
