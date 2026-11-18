// SPDX-License-Identifier: Apache-2.0
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {measurePage} from './prose-report.mjs';

const SIXTY_ONE_WORDS = Array.from({length: 61}, (unused, index) => `word${index}`).join(' ');

function page(body)
{
	return `<html><body><nav>Menu words here</nav><main class="main"><div class="vp-doc">${body}</div></main><footer>Footer text</footer></body></html>`;
}

test('counts code separately from paragraphs', () =>
{
	const figures = measurePage(page('<p>One two three.</p><div class="language-apex"><pre><code>Integer a = 1;\nInteger b = 2;</code></pre></div>'));

	assert.equal(figures.paragraphWords, 3);
	assert.equal(figures.codeWords, 8);
	assert.equal(figures.words, 11);
});

test('a paragraph over 60 words is long', () =>
{
	const figures = measurePage(page(`<p>${SIXTY_ONE_WORDS}</p><p>${SIXTY_ONE_WORDS.split(' ').slice(0, 60).join(' ')}</p>`));

	assert.equal(figures.longParagraphs, 1);
	assert.equal(figures.paragraphWords, 121);
});

test('a heading ends a paragraph run', () =>
{
	const figures = measurePage(page('<p>One.</p><p>Two.</p><h2 id="next">Next<a class="header-anchor" href="#next">​</a></h2><p>Three.</p>'));

	assert.equal(figures.longestParagraphRun, 2);
});

test('a table breaks a paragraph run', () =>
{
	const figures = measurePage(page('<p>One.</p><table><tr><td>Cell words</td></tr></table><p>Two.</p><p>Three.</p><p>Four.</p>'));

	assert.equal(figures.longestParagraphRun, 3);
	assert.equal(figures.tableWords, 2);
});

test('a list item over 60 words is long', () =>
{
	const figures = measurePage(page(`<ul><li>${SIXTY_ONE_WORDS}</li><li><p>${SIXTY_ONE_WORDS.split(' ').slice(0, 60).join(' ')}</p></li></ul>`));

	assert.equal(figures.longListItems, 1);
	assert.equal(figures.longParagraphs, 0);
});

test('a nested list item is counted on its own, and code in a list item is not counted', () =>
{
	const half = SIXTY_ONE_WORDS.split(' ').slice(0, 40).join(' ');
	const figures = measurePage(page(`<ul><li>${half}<ul><li>${half}</li></ul></li>`
		+ `<li>Short item<div class="language-apex"><pre><code>${SIXTY_ONE_WORDS}</code></pre></div></li></ul>`));

	assert.equal(figures.longListItems, 0);
	assert.equal(figures.codeWords, 61);
});

test('a table cell over 60 words is long', () =>
{
	const figures = measurePage(page(`<table><thead><tr><th>Topic</th><th>What happens</th></tr></thead>`
		+ `<tbody><tr><td>Short</td><td>${SIXTY_ONE_WORDS}</td></tr><tr><td>Short</td><td>${SIXTY_ONE_WORDS.split(' ').slice(0, 60).join(' ')}</td></tr></tbody></table>`));

	assert.equal(figures.longTableCells, 1);
	assert.equal(figures.longListItems, 0);
});

test('list words, images and text outside the main content', () =>
{
	const figures = measurePage(page('<ul><li>First item</li><li><p>Second item here</p></li></ul><p>Text <code>inline</code> &amp; more.</p><img src="a.png" alt="A">'));

	assert.equal(figures.listWords, 5);
	assert.equal(figures.paragraphWords, 4);
	assert.equal(figures.images, 1);
	assert.equal(figures.words, 9);
});
