// SPDX-License-Identifier: Apache-2.0
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {markdownCopyHeadEntry, markdownCopyPath, renderMarkdownCopy, stripHtmlComments} from './markdown-copy.mjs';

test('the copy of a page sits beside the page, with .md added', () =>
{
	assert.equal(markdownCopyPath('selectors-guide'), 'selectors-guide.md');
	assert.equal(markdownCopyPath('reference/apex/qry-builder'), 'reference/apex/qry-builder.md');
});

test('the head entry is an alternate link of type text/markdown, behind the deploy base', () =>
{
	assert.deepEqual(markdownCopyHeadEntry('dml-guide'), ['link', {rel: 'alternate', type: 'text/markdown', href: '/dml-guide.md'}]);
	assert.equal(markdownCopyHeadEntry('dml-guide', '/kern/')[1].href, '/kern/dml-guide.md');
});

test('HTML comments are removed from prose but kept inside code', () =>
{
	const input = 'Before <!-- internal note -->after.\n\n```html\n<!-- shown on purpose -->\n```\n\nUse `<!-- x -->` as a marker.\n';
	const output = stripHtmlComments(input);
	assert.ok(!output.includes('internal note'));
	assert.ok(output.includes('Before after.'));
	assert.ok(output.includes('<!-- shown on purpose -->'));
	assert.ok(output.includes('`<!-- x -->`'));
});

test('a copy ends with one newline and keeps the heading it has', () =>
{
	assert.equal(renderMarkdownCopy({markdown: '\n# Title\n\nBody.\n\n\n', title: 'Other'}), '# Title\n\nBody.\n');
});

test('a copy with no top-level heading starts with the page title', () =>
{
	assert.equal(renderMarkdownCopy({markdown: 'Body only.\n', title: 'My Page'}), '# My Page\n\nBody only.\n');
});

test('angle brackets, mustaches and details blocks are left as written', () =>
{
	const input = '# T\n\nA List<Id> and {{ value }}.\n\n<details>\n<summary>More</summary>\n\nText.\n\n</details>\n';
	const output = renderMarkdownCopy({markdown: input, title: 'T'});
	assert.ok(output.includes('List<Id>'));
	assert.ok(output.includes('{{ value }}'));
	assert.ok(output.includes('<summary>More</summary>'));
	assert.ok(!output.includes('&lt;'));
	assert.ok(!output.includes(':::'));
});
