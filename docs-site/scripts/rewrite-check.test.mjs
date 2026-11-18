// SPDX-License-Identifier: Apache-2.0
// Checks that compareRewrite reports every fact a rewritten page lost: a code block, a heading, a
// class or field name, a number with its unit, or a link target. A fact that moved to another
// page (the movedTo text) is not lost.
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {compareRewrite} from './rewrite-check.mjs';

const PAGE = [
	'# Logging Guide',
	'',
	'## How does it work?',
	'',
	'Every log goes through `LOG_Builder` and lands in LogEntry__c. A batch holds up to 200 records.',
	'See the [reference](reference/apex/LOG_Builder.md) for every method.',
	'',
	'```apex',
	'LOG_Builder.newBuilder().info(\'Saved\').emit();',
	'```',
	'',
	'### Limits',
	'',
	'The buffer keeps 50 entries before it sends them.',
	''
].join('\n');

/** Returns PAGE with one piece of text replaced, so each test changes only what it is about. */
function pageWith(search, replacement)
{
	assert.ok(PAGE.includes(search), `the test page contains "${search}"`);
	return PAGE.replace(search, replacement);
}

/** Says whether a list of found items holds one of the given kind and value. */
function holds(items, kind, value)
{
	return items.some(item => item.kind === kind && item.value === value);
}

test('an identical page passes', () =>
{
	const result = compareRewrite(PAGE, PAGE);
	assert.equal(result.passed, true);
	assert.deepEqual(result.lost, []);
	assert.deepEqual(result.added, []);
	assert.equal(result.changedFences, 0);
	assert.deepEqual(result.changedHeadings, []);
});

test('a changed character in a fence fails', () =>
{
	const result = compareRewrite(PAGE, pageWith('info(\'Saved\')', 'info(\'Saved!\')'));
	assert.equal(result.passed, false);
	assert.ok(result.lost.some(item => item.kind === 'fence'), 'the old fence is lost');
	assert.equal(result.changedFences, 1);
});

test('a renamed heading fails', () =>
{
	const result = compareRewrite(PAGE, pageWith('### Limits', '### Buffer limits'));
	assert.equal(result.passed, false);
	assert.ok(holds(result.lost, 'heading', '### Limits'));
	assert.deepEqual(result.changedHeadings, ['### Limits']);
});

test('a heading moved to another level on the same page fails', () =>
{
	const result = compareRewrite(PAGE, pageWith('### Limits', '## Limits'));
	assert.equal(result.passed, false);
	assert.ok(holds(result.lost, 'heading', '### Limits'));
});

test('an identifier said twice and kept once passes', () =>
{
	const before = `${PAGE}\nAgain: \`LOG_Builder\` sends to LogEntry__c.\n`;
	const result = compareRewrite(before, PAGE);
	assert.equal(result.passed, true, JSON.stringify(result.lost));
});

test('an identifier dropped fails', () =>
{
	const result = compareRewrite(PAGE, pageWith(' and lands in LogEntry__c', ''));
	assert.equal(result.passed, false);
	assert.ok(holds(result.lost, 'identifier', 'LogEntry__c'));
});

test('a number dropped fails', () =>
{
	const result = compareRewrite(PAGE, pageWith('The buffer keeps 50 entries before it sends them.', 'The buffer keeps some entries.'));
	assert.equal(result.passed, false);
	assert.ok(holds(result.lost, 'number', '50 entries'));
});

test('a link target dropped fails', () =>
{
	const result = compareRewrite(PAGE, pageWith('See the [reference](reference/apex/LOG_Builder.md) for every method.', 'See the reference for every method.'));
	assert.equal(result.passed, false);
	assert.ok(holds(result.lost, 'link', 'reference/apex/LOG_Builder.md'));
});

test('a code span with a pipe in a table cell still matches', () =>
{
	const before = `${PAGE}\nSplit on \`a | b\` to read both.\n`;
	const after = `${PAGE}\n| Split on | Reads |\n|---|---|\n| \`a \\| b\` | both |\n`;
	const result = compareRewrite(before, after);
	assert.ok(!holds(result.lost, 'identifier', 'a | b'), JSON.stringify(result.lost));
});

test('a paragraph turned into bullets with the same facts passes', () =>
{
	const after = pageWith(
		'Every log goes through `LOG_Builder` and lands in LogEntry__c. A batch holds up to 200 records.',
		'- Every log goes through `LOG_Builder`.\n- It lands in LogEntry__c.\n- A batch holds up to 200 records.');
	const result = compareRewrite(PAGE, after);
	assert.equal(result.passed, true, JSON.stringify(result.lost));
	assert.deepEqual(result.added, []);
});

test('a new identifier is listed in added', () =>
{
	const result = compareRewrite(PAGE, pageWith('The buffer keeps', 'The buffer in `LOG_Engine` keeps'));
	assert.equal(result.passed, true);
	assert.ok(holds(result.added, 'identifier', 'LOG_Engine'));
});

// A guide whose "Limits" section moved to another page: the guide keeps a stub that links to
// the moved heading, and names the old anchor in movedAnchors.
const MOVED_GUIDE = [
	'---',
	'movedAnchors: {"limits": "/strategic-guide-overview#logging-limits"}',
	'---',
	'',
	'# Logging Guide',
	'',
	'## How does it work?',
	'',
	'Every log goes through `LOG_Builder` and lands in LogEntry__c. A batch holds up to 200 records.',
	'See the [reference](reference/apex/LOG_Builder.md) for every method.',
	'',
	'```apex',
	'LOG_Builder.newBuilder().info(\'Saved\').emit();',
	'```',
	'',
	'Limits: see [Limits](Strategic%20Guide%20-%20Overview.md#logging-limits).',
	''
].join('\n');

const COMPARISONS = [
	'# Strategic Guide — Overview',
	'',
	'## Logging {#logging}',
	'',
	'### Limits {#logging-limits}',
	'',
	'The buffer keeps 50 entries before it sends them.',
	''
].join('\n');

test('a section moved with movedAnchors and found in movedTo passes', () =>
{
	const result = compareRewrite(PAGE, MOVED_GUIDE, {movedTo: COMPARISONS});
	assert.equal(result.passed, true, JSON.stringify(result.lost));
	assert.deepEqual(result.changedHeadings, ['### Limits'], 'the moved heading is still listed for the reviewer');
});

test('a moved heading with an explicit id still matches', () =>
{
	const before = pageWith('### Limits', '### Limits {#limits}');
	const result = compareRewrite(before, MOVED_GUIDE, {movedTo: COMPARISONS});
	assert.equal(result.passed, true, JSON.stringify(result.lost));
});

test('a moved fence missing from movedTo fails', () =>
{
	const before = `${PAGE}\n\`\`\`apex\nLOG_Builder.flush();\n\`\`\`\n`;
	const result = compareRewrite(before, MOVED_GUIDE, {movedTo: COMPARISONS});
	assert.equal(result.passed, false);
	assert.ok(holds(result.lost, 'fence', 'apex\nLOG_Builder.flush();\n'), JSON.stringify(result.lost));
});

test('a removed sub-heading without a movedAnchors entry fails', () =>
{
	const after = MOVED_GUIDE.replace('movedAnchors: {"limits": "/strategic-guide-overview#logging-limits"}', 'title: "Logging Guide"');
	const result = compareRewrite(PAGE, after, {movedTo: COMPARISONS});
	assert.equal(result.passed, false);
	assert.ok(holds(result.lost, 'heading', '### Limits'));
});

// A page with two headings of the same text: the parser gives them the ids "architecture" and "architecture-1".
const TWICE = [
	'# Logging Guide',
	'',
	'## Why choose this?',
	'',
	'### Architecture',
	'',
	'First part.',
	'',
	'## Design',
	'',
	'### Architecture',
	'',
	'Second part.',
	''
].join('\n');

const TWICE_COMPARISONS = '# Comparisons\n\n## Logging {#logging}\n\n### Architecture {#logging-architecture}\n\nFirst part.\n';
const TWICE_MOVED_ANCHORS = 'movedAnchors: {"architecture": "/strategic-guide-overview#logging-architecture"}';

test('two headings with the same text, the first moved without movedAnchors, fails with a lost anchor', () =>
{
	const after = TWICE.replace('### Architecture\n\nFirst part.\n\n', '');
	const result = compareRewrite(TWICE, after, {movedTo: TWICE_COMPARISONS});
	assert.equal(result.passed, false);
	assert.ok(holds(result.lost, 'anchor', 'architecture-1'), JSON.stringify(result.lost));
});

test('the same move with movedAnchors for the moved id and an explicit id on the remaining heading passes', () =>
{
	const after = `---\n${TWICE_MOVED_ANCHORS}\n---\n${TWICE.replace('### Architecture\n\nFirst part.\n\n', '').replace('### Architecture', '### Architecture {#architecture-1}')}`;
	const result = compareRewrite(TWICE, after, {movedTo: TWICE_COMPARISONS});
	assert.equal(result.passed, true, JSON.stringify(result.lost));
});

test('adding an explicit id that keeps the heading\'s old id is not a changed heading', () =>
{
	const result = compareRewrite(PAGE, pageWith('### Limits', '### Limits {#limits}'));
	assert.equal(result.passed, true, JSON.stringify(result.lost));
	assert.deepEqual(result.changedHeadings, []);
	assert.deepEqual(result.moved, []);
});

// A deleted section: its heading is gone, and movedAnchors sends its old links to the front page.
// The section's text stays on the page here, so only the heading is missing.
const DELETED_HEADING = `---\nmovedAnchors: {"limits": "/"}\n---\n\n${PAGE.replace('### Limits\n\n', '')}`;

test('a deleted heading whose id is in movedAnchors is listed as moved, not lost, when no movedTo is given', () =>
{
	const result = compareRewrite(PAGE, DELETED_HEADING);
	assert.equal(result.passed, true, JSON.stringify(result.lost));
	assert.ok(holds(result.moved, 'heading', '### Limits'), JSON.stringify(result.moved));
	assert.ok(!holds(result.lost, 'heading', '### Limits'));
});

test('a deleted heading whose id is not in movedAnchors is still lost when no movedTo is given', () =>
{
	const result = compareRewrite(PAGE, pageWith('### Limits\n\n', ''));
	assert.equal(result.passed, false);
	assert.ok(holds(result.lost, 'heading', '### Limits'));
	assert.deepEqual(result.moved, []);
});

test('a heading moved to the movedTo page is listed as moved', () =>
{
	const result = compareRewrite(PAGE, MOVED_GUIDE, {movedTo: COMPARISONS});
	assert.ok(holds(result.moved, 'heading', '### Limits'), JSON.stringify(result.moved));
});

test('with movedTo given, a heading in movedAnchors that is not on the movedTo page is still lost', () =>
{
	const result = compareRewrite(PAGE, MOVED_GUIDE, {movedTo: '# Strategic Guide — Overview\n\nThe buffer keeps 50 entries before it sends them.\n'});
	assert.equal(result.passed, false);
	assert.ok(holds(result.lost, 'heading', '### Limits'));
});

test('two headings with the same text that swap places fail: each old id now opens the other heading', () =>
{
	const swapped = [
		'# Logging Guide',
		'',
		'## Design',
		'',
		'### Architecture',
		'',
		'Second part.',
		'',
		'## Why choose this?',
		'',
		'### Architecture',
		'',
		'First part.',
		''
	].join('\n');
	const result = compareRewrite(TWICE, swapped);
	assert.equal(result.passed, false);
	assert.ok(holds(result.lost, 'anchor', 'architecture'), JSON.stringify(result.lost));
	assert.ok(holds(result.lost, 'anchor', 'architecture-1'), JSON.stringify(result.lost));
});

test('renaming the heading above two headings with the same text keeps their ids, so nothing is lost', () =>
{
	const before = '# Guide\n\n## A\n\n### Example\n\nFirst.\n\n### Example\n\nSecond.\n';
	const after = before.replace('## A\n', '## A and more\n');
	const result = compareRewrite(before, after);
	assert.ok(!holds(result.lost, 'anchor', 'example'), JSON.stringify(result.lost));
	assert.ok(!holds(result.lost, 'anchor', 'example-1'), JSON.stringify(result.lost));
	assert.deepEqual(result.changedHeadings, ['## A']);
});

test('a heading whose text is used once keeps its id when it moves under another heading', () =>
{
	const result = compareRewrite(PAGE, pageWith('### Limits', '## Details\n\n### Limits'));
	assert.equal(result.passed, true, JSON.stringify(result.lost));
});
