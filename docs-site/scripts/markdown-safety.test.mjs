// SPDX-License-Identifier: BUSL-1.1
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {escapeAngles} from './markdown-safety.mjs';

test('escapes Apex generics in prose', () =>
{
	assert.equal(escapeAngles('Returns List<SObject> of records.'), 'Returns List&lt;SObject&gt; of records.');
	assert.equal(escapeAngles('A Map<String, Object> param'), 'A Map&lt;String, Object&gt; param');
});

test('escapes nested generics', () =>
{
	assert.equal(escapeAngles('List<List<Object>> nested'), 'List&lt;List&lt;Object&gt;&gt; nested');
});

test('leaves code spans and fenced code untouched', () =>
{
	assert.equal(escapeAngles('Use `List<SObject>` here'), 'Use `List<SObject>` here');
	const fence = '```apex\nList<SObject> x = new List<SObject>();\n```';
	assert.equal(escapeAngles(fence), fence);
});

test('preserves real HTML tags from the allowlist', () =>
{
	assert.equal(escapeAngles('Line one<br>line two'), 'Line one<br>line two');
	assert.equal(escapeAngles('A <a href="https://x.test">link</a> here'), 'A <a href="https://x.test">link</a> here');
});

test('preserves allowlisted tags whose attribute value contains a quoted >', () =>
{
	// The attribute value contains a literal '>'; the whole tag must survive intact.
	assert.equal(escapeAngles('A <a title="a > b">link</a> here'), 'A <a title="a > b">link</a> here');
	assert.equal(escapeAngles("A <a title='a > b'>link</a> here"), "A <a title='a > b'>link</a> here");
	// A real generic after such a tag must still be escaped.
	assert.equal(escapeAngles('See <a title="x > y">link</a> and List<Id> too'), 'See <a title="x > y">link</a> and List&lt;Id&gt; too');
});

test('escapes generic-looking pseudo-tags but keeps allowlisted ones in the same line', () =>
{
	assert.equal(escapeAngles('Set<Id> ids and a <br> break'), 'Set&lt;Id&gt; ids and a <br> break');
});

test('neutralizes Vue mustache interpolation in prose so SSR does not evaluate it', () =>
{
	// Vue reads {{ x }} as an interpolation binding; in docs prose it is literal text.
	assert.equal(escapeAngles('Use {{request.field}} in templates'), 'Use &#123;&#123;request.field&#125;&#125; in templates');
});

test('neutralizes mustache inside inline code spans but keeps the angle brackets there', () =>
{
	// Inline-code angle brackets must stay verbatim (they render fine); only mustaches break SSR.
	assert.equal(escapeAngles('See `{{request.field}}` and `List<Id>`'), 'See `&#123;&#123;request.field&#125;&#125;` and `List<Id>`');
});

test('leaves mustache inside fenced code blocks untouched (VitePress applies v-pre)', () =>
{
	const fence = '```yaml\ntoken: {{ secrets.AUTH }}\n```';
	assert.equal(escapeAngles(fence), fence);
});

test('strips HTML comments in prose (they are invisible on GitHub; escaping them leaks the text)', () =>
{
	// An author comment a reader never sees on GitHub must not become visible page text.
	assert.equal(escapeAngles('Before <!-- a hidden note --> after'), 'Before  after');
	// An internal audit marker in a table cell must not leak into the rendered site.
	const out = escapeAngles('| value  | High |');
	assert.ok(!out.includes('regrounded'));
	assert.ok(!out.includes('&lt;!--'));
	assert.equal(out, '| value  | High |');
});

test('preserves HTML comments inside code (they are intentional examples there)', () =>
{
	const fence = '```html\n<!-- accountTable.html -->\n<div></div>\n```';
	assert.equal(escapeAngles(fence), fence);
	assert.equal(escapeAngles('Inline `<!-- keep -->` example'), 'Inline `<!-- keep -->` example');
});
