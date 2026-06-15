// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const {
	parseRow, parseCsv, encodeForSlack, classifyEngine, truncMid, groupRows, buildSlackPayload, slackPayload
} = require('../../src/commands/slack-payload.js');

const FIXTURE_CSV = path.join(__dirname, '../fixtures/sfca-violations.csv');

test('parseRow handles plain fields', () =>
{
	const result = parseRow('1,pmd,KernNoInlineSOQL,force-app/classes/Foo.cls,42,Simple message');
	assert.deepEqual(result, [
		'1',
		'pmd',
		'KernNoInlineSOQL',
		'force-app/classes/Foo.cls',
		'42',
		'Simple message'
	]);
});

test('parseRow handles quoted fields containing commas', () =>
{
	const result = parseRow('"hello, world","foo","bar"');
	assert.deepEqual(result, [
		'hello, world',
		'foo',
		'bar'
	]);
});

test('parseRow handles escaped double-quotes inside quoted fields', () =>
{
	const result = parseRow('"say ""hello""",plain');
	assert.deepEqual(result, [
		'say "hello"',
		'plain'
	]);
});

test('encodeForSlack URL-encodes percent signs', () =>
{
	assert.equal(encodeForSlack('100%'), '100%25');
});

test('encodeForSlack URL-encodes commas', () =>
{
	assert.equal(encodeForSlack('a,b'), 'a%2Cb');
});

test('encodeForSlack URL-encodes colons', () =>
{
	assert.equal(encodeForSlack('http://foo'), 'http%3A//foo');
});

test('encodeForSlack encodes all three target characters together', () =>
{
	assert.equal(encodeForSlack('100%,foo:bar'), '100%25%2Cfoo%3Abar');
});

test('classifyEngine maps pmd to apex', () =>
{
	assert.equal(classifyEngine('pmd', 'force-app/classes/Foo.cls'), 'apex');
});

test('classifyEngine maps eslint + /lwc/ path to lwc', () =>
{
	assert.equal(classifyEngine('eslint', 'force-app/main/default/lwc/myComp/myComp.js'), 'lwc');
});

test('classifyEngine maps eslint + /aura/ path to aura', () =>
{
	assert.equal(classifyEngine('eslint', 'force-app/main/default/aura/myComp/myComp.js'), 'aura');
});

test('classifyEngine maps eslint + non-lwc/non-aura to js', () =>
{
	assert.equal(classifyEngine('eslint', 'force-app/main/default/staticresources/foo.js'), 'js');
});

test('classifyEngine maps flow engine to flow', () =>
{
	assert.equal(classifyEngine('flow', 'force-app/flows/MyFlow.flow-meta.xml'), 'flow');
});

test('truncMid returns string unchanged when within width', () =>
{
	assert.equal(truncMid('hello', 10), 'hello');
});

test('truncMid mid-truncates preserving head and tail', () =>
{
	const result = truncMid('ApexCRUDViolation', 10);
	assert.equal(result.length, 10);
	assert.ok(result.includes('…'), 'should contain ellipsis');
});

test('parseCsv returns headers and rows', () =>
{
	const {headers, rows} = parseCsv('A,B,C\n1,2,3\n4,5,6');
	assert.deepEqual(headers, [
		'A',
		'B',
		'C'
	]);
	assert.equal(rows.length, 2);
});

test('groupRows deduplicates lines and counts correctly', () =>
{
	const rows = [
		{sev: '1', src: 'apex', rule: 'RuleA', fname: 'Foo.cls', fpath: 'x/Foo.cls', line: '10'},
		{sev: '1', src: 'apex', rule: 'RuleA', fname: 'Foo.cls', fpath: 'x/Foo.cls', line: '10'},
		{sev: '1', src: 'apex', rule: 'RuleA', fname: 'Foo.cls', fpath: 'x/Foo.cls', line: '20'}
	];
	const result = groupRows(rows);
	assert.equal(result.length, 1);
	assert.equal(result[0].cnt, 3);
	assert.equal(result[0].lineStr, '10,20');
});

test('groupRows handles > 3 unique lines with ellipsis', () =>
{
	const rows = [
		'5',
		'10',
		'15',
		'20'
	].map(line => ({
		sev: '1', src: 'apex', rule: 'RuleA', fname: 'Foo.cls', fpath: 'x/Foo.cls', line
	}));
	const result = groupRows(rows);
	assert.equal(result[0].lineStr, '5,…,20');
});

test('slackPayload returns should_notify false for empty CSV', () =>
{
	const fs = require('node:fs');
	const os = require('node:os');
	const tmpFile = require('node:path').join(os.tmpdir(), 'empty-violations.csv');
	fs.writeFileSync(tmpFile, 'Severity,Engine,Rule,File,StartLine,Message\n');
	const output = slackPayload({
		csv: tmpFile,
		prUrl: 'https://github.com/test/repo/pull/1',
		prTitle: 'My PR',
		prAuthor: 'dev',
		prNumber: '1',
		headRef: 'feature/x',
		baseRef: 'main',
		repo: 'test/repo',
		runId: '999'
	});
	const parsed = JSON.parse(output);
	assert.equal(parsed.should_notify, false);
});

test('slackPayload against fixture CSV produces valid JSON with expected attachment fields', () =>
{
	const output = slackPayload({
		csv: FIXTURE_CSV,
		prUrl: 'https://github.com/test/repo/pull/42',
		prTitle: 'Add feature',
		prAuthor: 'jdev',
		prNumber: '42',
		headRef: 'feature/add-feature',
		baseRef: 'main',
		repo: 'test/repo',
		runId: '12345'
	});

	const payload = JSON.parse(output);
	assert.ok(payload.text, 'payload has top-level text');
	assert.ok(Array.isArray(payload.attachments), 'payload has attachments array');
	const att = payload.attachments[0];
	assert.equal(att.color, 'danger', 'sev-1 violations should produce danger color');
	assert.ok(att.title.includes('FAILED'), 'title should say FAILED for sev-1 violations');
	assert.ok(att.title.includes('violation'), 'title mentions violations');
	assert.ok(Array.isArray(att.fields), 'attachment has fields array');
	assert.ok(att.mrkdwn_in.includes('text'), 'mrkdwn_in contains text');
	assert.ok(att.mrkdwn_in.includes('fields'), 'mrkdwn_in contains fields');
});

test('slackPayload fixture includes PR field with pr-url and pr-number', () =>
{
	const output = slackPayload({
		csv: FIXTURE_CSV,
		prUrl: 'https://github.com/test/repo/pull/42',
		prTitle: 'Add feature',
		prAuthor: 'jdev',
		prNumber: '42',
		headRef: 'feature/add-feature',
		baseRef: 'main',
		repo: 'test/repo',
		runId: '12345'
	});

	const payload = JSON.parse(output);
	const att = payload.attachments[0];
	const prField = att.fields.find(f => f.title === 'PR');
	assert.ok(prField, 'PR field exists');
	assert.ok(prField.value.includes('#42'), 'PR field contains PR number');
	assert.ok(prField.value.includes('https://github.com/test/repo/pull/42'), 'PR field contains PR URL');
});

test('slackPayload fixture includes blocking violations table', () =>
{
	const output = slackPayload({
		csv: FIXTURE_CSV,
		prUrl: 'https://github.com/test/repo/pull/42',
		prTitle: 'Add feature',
		prAuthor: 'jdev',
		prNumber: '42',
		headRef: 'feature/add-feature',
		baseRef: 'main',
		repo: 'test/repo',
		runId: '12345'
	});

	const payload = JSON.parse(output);
	const att = payload.attachments[0];
	const blockingField = att.fields.find(f => f.title === 'Blocking violations (Sev-1/Sev-2)');
	assert.ok(blockingField, 'blocking violations field exists');
	assert.ok(blockingField.value.includes('```'), 'blocking table is wrapped in code fences');
	assert.ok(blockingField.value.includes('SEV'), 'blocking table has SEV header');
	assert.ok(blockingField.value.includes('RULE'), 'blocking table has RULE header');
});

test('slackPayload fixture includes informational violations section', () =>
{
	const output = slackPayload({
		csv: FIXTURE_CSV,
		prUrl: 'https://github.com/test/repo/pull/42',
		prTitle: 'Add feature',
		prAuthor: 'jdev',
		prNumber: '42',
		headRef: 'feature/add-feature',
		baseRef: 'main',
		repo: 'test/repo',
		runId: '12345'
	});

	const payload = JSON.parse(output);
	const att = payload.attachments[0];
	const infoField = att.fields.find(f => f.title === 'Informational');
	assert.ok(infoField, 'Informational field exists');
	assert.ok(infoField.value.includes('non-blocking'), 'Informational mentions non-blocking');
});

test('slackPayload fixture includes Details field with workflow run URL', () =>
{
	const output = slackPayload({
		csv: FIXTURE_CSV,
		prUrl: 'https://github.com/test/repo/pull/42',
		prTitle: 'Add feature',
		prAuthor: 'jdev',
		prNumber: '42',
		headRef: 'feature/add-feature',
		baseRef: 'main',
		repo: 'test/repo',
		runId: '12345'
	});

	const payload = JSON.parse(output);
	const att = payload.attachments[0];
	const detailsField = att.fields.find(f => f.title === 'Details');
	assert.ok(detailsField, 'Details field exists');
	assert.ok(detailsField.value.includes('test/repo/actions/runs/12345'), 'Details links to workflow run');
	assert.ok(detailsField.value.includes('/files'), 'Details links to files changed');
});

test('slackPayload only-warnings fixture produces warning color', () =>
{
	const fs = require('node:fs');
	const os = require('node:os');
	const tmpFile = require('node:path').join(os.tmpdir(), 'warn-violations.csv');
	fs.writeFileSync(tmpFile, [
		'Severity,Engine,Rule,File,StartLine,Message',
		'3,pmd,KernNoSystemDebug,force-app/classes/Baz.cls,99,Use LOG_Builder'
	].join('\n'));
	const output = slackPayload({
		csv: tmpFile,
		prUrl: 'https://github.com/test/repo/pull/5',
		prTitle: 'Warn only',
		prAuthor: 'dev',
		prNumber: '5',
		headRef: 'feature/b',
		baseRef: 'main',
		repo: 'test/repo',
		runId: '1'
	});
	const payload = JSON.parse(output);
	assert.equal(payload.attachments[0].color, 'warning');
	assert.ok(payload.attachments[0].title.includes('PASSED with warnings'));
});
