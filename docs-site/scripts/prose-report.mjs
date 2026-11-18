// SPDX-License-Identifier: Apache-2.0
//
// Measures how much of a built page is running text, and how much is code, tables and lists.
// It reads one page of the built site (HTML) and counts the words in each kind of block inside
// the page's main content, so the navigation, the "On this page" outline and the footer are left out.
//
//   node scripts/prose-report.mjs <page.html> [<page.html> ...]
//   node scripts/prose-report.mjs --dist <dir> <route> [<route> ...]
//
// prints one line of figures per page. The second form reads each page of a built site by its route
// (`/logging-guide`), in the built site's folder (`.vitepress/dist`).

import {readFileSync} from 'node:fs';
import path from 'node:path';
import {pathToFileURL} from 'node:url';

/** A paragraph, list item or table cell with more words than this is long. */
export const LONG_PARAGRAPH_WORDS = 60;

const LIST_ITEM_TAGS = new Set(['li', 'dd', 'dt']);
const TABLE_CELL_TAGS = new Set(['td', 'th']);

const VOID_TAGS = new Set(['area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input', 'link', 'meta', 'source', 'track', 'wbr']);
const INLINE_TAGS = new Set(['a', 'abbr', 'b', 'code', 'em', 'i', 'kbd', 'mark', 's', 'small', 'span', 'strong', 'sub', 'sup', 'u']);
const RUN_BREAKING_TAGS = new Set(['h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'table', 'pre', 'ul', 'ol', 'dl', 'img', 'hr', 'details', 'figure', 'svg']);
const TOKEN = /<!--[\s\S]*?-->|<(\/?)([a-zA-Z][a-zA-Z0-9-]*)([^>]*)>|([^<]+)/g;

/**
 * Returns the part of the page between the main element's tags, or the whole page when it has none.
 *
 * @param {string} html the built page
 * @returns {string} the main content
 */
function mainContent(html)
{
	const withoutScripts = html.replace(/<script[\s\S]*?<\/script>/gi, '').replace(/<style[\s\S]*?<\/style>/gi, '');
	const start = withoutScripts.search(/<main[\s>]/i);
	const end = withoutScripts.lastIndexOf('</main>');

	return start >= 0 && end > start ? withoutScripts.slice(start, end + '</main>'.length) : withoutScripts;
}

/**
 * Turns the HTML entities a built page uses back into plain characters.
 *
 * @param {string} text text taken from between tags
 * @returns {string} the text as a reader sees it
 */
function decodeEntities(text)
{
	return text
		.replace(/&nbsp;|&#160;/g, ' ')
		.replace(/&ZeroWidthSpace;|&#8203;|​/g, '')
		.replace(/&#(\d+);/g, (unused, code) => String.fromCodePoint(Number(code)))
		.replace(/&#x([0-9a-f]+);/gi, (unused, code) => String.fromCodePoint(parseInt(code, 16)))
		.replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&#39;|&apos;/g, '\'')
		.replace(/&amp;/g, '&');
}

/**
 * Counts the words in a piece of text: anything between spaces is one word.
 *
 * @param {string} text the text to count
 * @returns {number} the number of words
 */
function countWords(text)
{
	return (text.match(/\S+/g) || []).length;
}

/**
 * Says which kind of block the text at the top of the stack belongs to.
 *
 * @param {Array<{tag: string, className: string}>} stack the open elements, outermost first
 * @returns {'code'|'table'|'list'|'paragraph'|'other'} the kind of block
 */
function blockKind(stack)
{
	const has = predicate => stack.some(predicate);

	if(has(element => element.tag === 'pre' || (element.tag === 'div' && /(^|\s)language-/.test(element.className))))
	{
		return 'code';
	}
	if(has(element => element.tag === 'table'))
	{
		return 'table';
	}
	if(has(element => element.tag === 'li' || element.tag === 'dd' || element.tag === 'dt'))
	{
		return 'list';
	}
	if(has(element => element.tag === 'p'))
	{
		return 'paragraph';
	}
	return 'other';
}

/**
 * Measures one built page.
 *
 * A paragraph is a p element outside a list, a table and a code block; a callout's paragraphs count too.
 * A paragraph run is a number of paragraphs in a row with no heading, table, code block, list or image between them.
 * A list item and a table cell are counted the same way as a paragraph: the words of a list item inside it
 * belong to that inner item, and the words of a code block are not counted.
 *
 * @param {string} html the built page
 * @returns {{words: number, paragraphWords: number, codeWords: number, tableWords: number, listWords: number,
 *   longParagraphs: number, longListItems: number, longTableCells: number, longestParagraphRun: number,
 *   images: number}} the page's figures
 */
export function measurePage(html)
{
	const buffers = {code: '', table: '', list: '', other: ''};
	const stack = [];
	let paragraph = null;
	let paragraphWords = 0;
	let longParagraphs = 0;
	let longListItems = 0;
	let longTableCells = 0;
	let run = 0;
	let longestParagraphRun = 0;
	let images = 0;

	const innermost = tags =>
	{
		for(let index = stack.length - 1; index >= 0; index--)
		{
			if(tags.has(stack[index].tag))
			{
				return stack[index];
			}
		}
		return null;
	};

	const append = text =>
	{
		const kind = blockKind(stack);

		if(kind === 'paragraph' && paragraph !== null)
		{
			paragraph += text;
		}
		else
		{
			buffers[kind === 'paragraph' ? 'other' : kind] += text;
		}

		const holder = kind === 'list' ? innermost(LIST_ITEM_TAGS) : kind === 'table' ? innermost(TABLE_CELL_TAGS) : null;

		if(holder !== null)
		{
			holder.text += text;
		}
	};

	const closeElement = element =>
	{
		if(element.text === undefined || countWords(element.text) <= LONG_PARAGRAPH_WORDS)
		{
			return;
		}
		if(LIST_ITEM_TAGS.has(element.tag))
		{
			longListItems++;
		}
		else
		{
			longTableCells++;
		}
	};

	for(const match of mainContent(html).matchAll(TOKEN))
	{
		const [whole, closing, rawTag, attributes, text] = match;

		if(text !== undefined)
		{
			append(decodeEntities(text));
			continue;
		}
		if(rawTag === undefined || whole.startsWith('<!--'))
		{
			continue;
		}

		const tag = rawTag.toLowerCase();

		if(!INLINE_TAGS.has(tag))
		{
			append(' ');
		}

		if(closing)
		{
			const index = stack.map(element => element.tag).lastIndexOf(tag);

			if(index < 0)
			{
				continue;
			}
			if(tag === 'p' && paragraph !== null && stack[index].isParagraph)
			{
				const words = countWords(paragraph);

				paragraph = null;
				if(words > 0)
				{
					paragraphWords += words;
					longParagraphs += words > LONG_PARAGRAPH_WORDS ? 1 : 0;
					run++;
					longestParagraphRun = Math.max(longestParagraphRun, run);
				}
			}
			stack.splice(index).reverse().forEach(closeElement);
			continue;
		}

		if(tag === 'img')
		{
			images++;
		}
		if(RUN_BREAKING_TAGS.has(tag) && paragraph === null)
		{
			run = 0;
		}

		if(VOID_TAGS.has(tag) || attributes.trim().endsWith('/'))
		{
			continue;
		}

		const className = (attributes.match(/class\s*=\s*"([^"]*)"/i) || [])[1] || '';
		const isParagraph = tag === 'p' && paragraph === null && blockKind(stack) !== 'code' && blockKind(stack) !== 'table' && blockKind(stack) !== 'list';

		const element = {tag, className, isParagraph};

		if((LIST_ITEM_TAGS.has(tag) || TABLE_CELL_TAGS.has(tag)) && blockKind(stack) !== 'code')
		{
			element.text = '';
		}
		stack.push(element);
		if(isParagraph)
		{
			paragraph = '';
		}
	}

	const codeWords = countWords(buffers.code);
	const tableWords = countWords(buffers.table);
	const listWords = countWords(buffers.list);

	return {
		words: paragraphWords + codeWords + tableWords + listWords + countWords(buffers.other),
		paragraphWords,
		codeWords,
		tableWords,
		listWords,
		longParagraphs,
		longListItems,
		longTableCells,
		longestParagraphRun,
		images
	};
}

/**
 * Finds the built HTML file of a page route in a built site: `/logging-guide` is `logging-guide.html`,
 * and a section index such as `/reference/apex/` is `reference/apex/index.html`.
 *
 * @param {string} dist the built site's folder
 * @param {string} route the page route, with or without its leading slash
 * @returns {string} the path of the page's HTML file
 */
export function fileForRoute(dist, route)
{
	const trimmed = route.replace(/^\/+/, '').replace(/\.html$/, '');

	return trimmed === '' || trimmed.endsWith('/') ? path.join(dist, trimmed, 'index.html') : path.join(dist, `${trimmed}.html`);
}

/**
 * Prints one line of figures for a page.
 *
 * @param {object} label what the line is about, such as {file} or {route}
 * @param {string} html the built page
 */
function printFigures(label, html)
{
	const figures = measurePage(html);
	const paragraphShare = figures.words ? Math.round(figures.paragraphWords / figures.words * 1000) / 10 : 0;

	console.log(JSON.stringify({...label, ...figures, paragraphShare}));
}

if(process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href)
{
	const args = process.argv.slice(2);

	if(args[0] === '--dist')
	{
		const [, dist, ...routes] = args;

		if(!dist || routes.length === 0)
		{
			console.error('Usage: node scripts/prose-report.mjs --dist <dir> <route> [<route> ...]');
			process.exit(2);
		}
		for(const route of routes)
		{
			printFigures({route}, readFileSync(fileForRoute(dist, route), 'utf8'));
		}
	}
	else
	{
		for(const file of args)
		{
			printFigures({file}, readFileSync(file, 'utf8'));
		}
	}
}
