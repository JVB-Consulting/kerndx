// SPDX-License-Identifier: Apache-2.0
//
// Checks that a rewritten page kept every fact of the page it replaced. A rewrite may change the
// words, the order and the layout (a paragraph can become a table or a list), but it must keep:
//
//   fence       every fenced code block, character for character
//   heading     every heading, with its exact text and level
//   identifier  every inline code span, and every class or field name such as LOG_Builder or Foo__c
//   number      every number, with the unit word after it ("200 records")
//   link        every link target
//   anchor      every heading id, so an old link to `#id` still opens the same heading
//
// The comparison is by set, not by count: a fact said twice and kept once is not lost. A fact that
// moved to another page (the movedTo text) is not lost either. A heading that moved there
// also needs an entry in the rewritten page's `movedAnchors` frontmatter, so old links to it still
// work. Without --moved-to, a heading that left the page is moved when `movedAnchors` names its id:
// the section was deleted and its old links go to the place named there, such as the front page.
// Moved headings are printed in their own list, apart from the lost facts.
//
// An anchor is lost when its heading id is no longer on the page and `movedAnchors` does not name it,
// and also when two headings with the same text change places: their ids come from their order, so
// each old link would open the other heading.
//
//   npm run check:rewrite -- <file> [--base <git ref or saved file>] [--moved-to <file>]
//
// The base defaults to HEAD. A base that is an existing file is read as the page before the rewrite.
// The command prints what was lost and what was added, and exits with 1 when anything was lost.
//
// Code blocks and headings are read with VitePress's own Markdown parser (markdown-it), the parser
// that turns these pages into the site, so a fence or heading is found exactly where the site finds it.

import {existsSync, readFileSync, statSync} from 'node:fs';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
import {pathToFileURL} from 'node:url';
import {createMarkdownRenderer} from 'vitepress';
import {parseFrontmatter} from './frontmatter.mjs';
import {movedAnchorsOf} from './prepare.mjs';

const markdown = await createMarkdownRenderer(process.cwd(), {}, '/');

/** Words with an upper-case prefix and an underscore, such as LOG_Builder or UTIL_Retry.Policy. */
const PREFIXED_NAME = /\b[A-Z]{2,}_[A-Za-z0-9_.]+\b/g;

/** Custom object, metadata, event and relationship names, such as LogEntry__c or Setting__mdt. */
const CUSTOM_NAME = /\b[A-Za-z]+__(?:c|mdt|e|r)\b/g;

/** A number that does not sit inside a word, with an optional unit written straight after it (10MB, 5s, 100%). */
const NUMBER = /(?<![\w.,])(\d+(?:[.,:]\d+)*)([A-Za-z%]+)?(?!\w)/g;

/** Small words that follow a number but say nothing about what it counts. */
const NOT_A_UNIT = new Set(['a', 'an', 'and', 'are', 'as', 'at', 'be', 'but', 'by', 'can', 'do', 'for', 'from', 'has', 'have', 'if', 'in',
	'is', 'it', 'its', 'of', 'on', 'or', 'so', 'than', 'that', 'the', 'then', 'this', 'to', 'was', 'were', 'when', 'which', 'will', 'with']);

/** Marks where a code span sat in running text, so a number before it takes no unit from it. */
const CODE_GAP = ' \u0000 ';

/**
 * Removes an explicit `{#id}` from the end of a heading's text.
 *
 * @param {string} text the heading text as written
 * @returns {string} the text a reader sees
 */
function withoutExplicitId(text)
{
	return text.replace(/\s*\{#[^}]*\}\s*$/, '').trim();
}

/**
 * Collects the numbers in a piece of running text, each with its unit.
 *
 * @param {string} text the text, with code spans replaced by CODE_GAP
 * @param {function(string): void} add receives each number
 */
function collectNumbers(text, add)
{
	for(const match of text.matchAll(NUMBER))
	{
		const [whole, digits, attached = ''] = match;
		const next = text.slice(match.index + whole.length).match(/^\s+([A-Za-z][A-Za-z'-]*)/);
		const unit = next && !attached && !NOT_A_UNIT.has(next[1].toLowerCase()) ? ` ${next[1].toLowerCase()}` : '';

		add(`${digits}${attached}${unit}`);
	}
}

/**
 * Collects the class and field names in a piece of running text.
 *
 * @param {string} text the text
 * @param {function(string): void} add receives each name
 */
function collectNames(text, add)
{
	for(const pattern of [PREFIXED_NAME, CUSTOM_NAME])
	{
		for(const [name] of text.matchAll(pattern))
		{
			add(name.replace(/\.+$/, ''));
		}
	}
}

/**
 * Collects the facts in a block of raw HTML: its text, and the targets of its links and images.
 *
 * @param {string} html the HTML
 * @param {function(string, string): void} add receives each fact as kind and value
 */
function collectHtml(html, add)
{
	for(const [, target] of html.matchAll(/\b(?:href|src)\s*=\s*"([^"]*)"/gi))
	{
		add('link', target);
	}
	const text = html.replace(/<[^>]*>/g, ' ');
	collectNames(text, name => add('identifier', name));
	collectNumbers(text, number => add('number', number));
}

/**
 * Reads the facts of one page.
 *
 * @param {string} source the page's Markdown, with or without frontmatter
 * @returns {{facts: Array<{kind: string, value: string}>, headings: Array<{value: string, text: string, id: string, parents: string}>,
 *   movedAnchors: Object<string, string>}} the page's facts in page order, its headings (each with the text of the
 *   headings above it), and its moved anchors
 */
export function readFacts(source)
{
	const {data, content} = parseFrontmatter(source);
	const tokens = markdown.parse(content, {});
	const facts = [];
	const seen = new Set();
	const headings = [];
	// The text of each heading above the current place, by level: the parents of the next heading.
	const above = [];
	const add = (kind, value) =>
	{
		const key = `${kind}\u0001${value}`;

		if(value !== '' && !seen.has(key))
		{
			seen.add(key);
			facts.push({kind, value});
		}
	};

	for(let index = 0; index < tokens.length; index++)
	{
		const token = tokens[index];

		if(token.type === 'fence' || token.type === 'code_block')
		{
			add('fence', `${token.info.trim()}\n${token.content}`);
		}
		else if(token.type === 'heading_open')
		{
			const text = tokens[index + 1].content.trim();
			const shown = withoutExplicitId(text);
			const level = Number(token.tag.slice(1));

			above.length = level - 1;
			const heading = {value: `${'#'.repeat(level)} ${shown}`, text: shown, id: token.attrGet('id') || '', parents: above.filter(Boolean).join('\u0001')};

			above[level - 1] = shown;
			headings.push(heading);
			add('heading', heading.value);
		}
		else if(token.type === 'html_block')
		{
			collectHtml(token.content, add);
		}
		else if(token.type === 'inline')
		{
			let running = '';
			let inHeadingAnchor = false;

			for(const child of token.children)
			{
				// The parser adds a "#" link to each heading, pointing at the heading itself. The page never wrote it.
				if(child.type === 'link_open' && /(^|\s)header-anchor(\s|$)/.test(child.attrGet('class') || ''))
				{
					inHeadingAnchor = true;
				}
				else if(inHeadingAnchor)
				{
					inHeadingAnchor = child.type !== 'link_close';
				}
				else if(child.type === 'code_inline')
				{
					add('identifier', child.content.trim());
					running += CODE_GAP;
				}
				else if(child.type === 'text' || child.type === 'text_special')
				{
					running += child.content;
				}
				else if(child.type === 'softbreak' || child.type === 'hardbreak')
				{
					running += ' ';
				}
				else if(child.type === 'link_open')
				{
					add('link', child.attrGet('href'));
				}
				else if(child.type === 'image')
				{
					add('link', child.attrGet('src'));
					running += ` ${child.content} `;
				}
				else if(child.type === 'html_inline')
				{
					collectHtml(child.content, add);
					running += ' ';
				}
			}
			collectNames(running, name => add('identifier', name));
			collectNumbers(running, number => add('number', number));
		}
	}
	return {facts, headings, movedAnchors: movedAnchorsOf(data)};
}

/**
 * Builds a lookup of facts by kind and value.
 *
 * @param {Array<{kind: string, value: string}>} facts the facts
 * @returns {Set<string>} one key per fact
 */
function keysOf(facts)
{
	return new Set(facts.map(fact => `${fact.kind}\u0001${fact.value}`));
}

/**
 * Says whether a link that pointed inside the old page arrived on the page it moved to, where it
 * must name the old page in front of the same anchor.
 *
 * @param {string} target the old link target
 * @param {Array<{kind: string, value: string}>} movedFacts the facts of the page the sections moved to
 * @returns {boolean} true when a link with the same anchor is on the page the sections moved to
 */
function isSamePageLinkMoved(target, movedFacts)
{
	return target.startsWith('#') && movedFacts.some(fact => fact.kind === 'link' && fact.value.endsWith(target));
}

/**
 * Compares a page before and after a rewrite.
 *
 * @param {string} before the page before the rewrite
 * @param {string} after the page after the rewrite
 * @param {{movedTo?: string}} [options] movedTo is the page the sections moved to
 * @returns {{passed: boolean, lost: Array<{kind: string, value: string}>, moved: Array<{kind: string, value: string}>,
 *   added: Array<{kind: string, value: string}>, changedFences: number, changedHeadings: string[]}} passed is true when
 *   nothing was lost; moved lists the headings that left the page with a `movedAnchors` entry; moved, added,
 *   changedFences and changedHeadings are for the reviewer
 */
export function compareRewrite(before, after, options = {})
{
	const old = readFacts(before);
	const current = readFacts(after);
	const moved = options.movedTo == null ? {facts: [], headings: []} : readFacts(options.movedTo);
	const currentKeys = keysOf(current.facts);
	const movedKeys = keysOf(moved.facts);
	const movedHeadingTexts = new Set(moved.headings.map(heading => heading.text));
	const missing = old.facts.filter(fact => !currentKeys.has(`${fact.kind}\u0001${fact.value}`));
	// A heading that left the page is moved when movedAnchors sends its old id somewhere. With a movedTo
	// page, that page must also hold the heading. Without one, the section was deleted and its old links
	// go to the place movedAnchors names, such as the front page.
	const isMovedHeading = (heading) => Object.hasOwn(current.movedAnchors, heading.id)
		&& (options.movedTo == null || movedHeadingTexts.has(heading.text));
	const movedFacts = [];

	const lost = missing.filter(fact =>
	{
		if(fact.kind === 'heading')
		{
			// A heading may share its text with another heading, so every old heading with this value is checked.
			const sameValue = old.headings.filter(heading => heading.value === fact.value);
			if(sameValue.every(isMovedHeading))
			{
				movedFacts.push(fact);
				return false;
			}
			return true;
		}
		if(movedKeys.has(`${fact.kind}\u0001${fact.value}`))
		{
			return false;
		}
		return !(fact.kind === 'link' && isSamePageLinkMoved(fact.value, moved.facts));
	});
	// A heading id that is neither on the new page nor listed in movedAnchors is a link that now lands in the wrong place.
	const currentIds = new Set(current.headings.map(heading => heading.id));
	old.headings
		.filter(heading => heading.id !== '' && !currentIds.has(heading.id) && !Object.hasOwn(current.movedAnchors, heading.id))
		.forEach(heading => lost.push({kind: 'anchor', value: heading.id}));
	// Two headings with the same text get the ids "architecture" and "architecture-1" by their order on
	// the page. When they change places, each old id opens the other heading. So each repeated heading is
	// found again on the new page by its text and the headings above it (the first such heading for the
	// first, and so on), and its id there must be its old id. A heading not found that way, for example
	// because a heading above it was renamed, keeps its place among the headings with its text, and so its id.
	const isRepeated = (headings, text) => headings.filter(heading => heading.text === text).length > 1;
	const placeKey = (heading) => `${heading.text}\u0001\u0001${heading.parents}`;
	const groupByPlace = (headings) => Map.groupBy(headings, placeKey);
	const oldByPlace = groupByPlace(old.headings);
	const currentByPlace = groupByPlace(current.headings);
	old.headings
		.filter(heading => heading.id !== '' && currentIds.has(heading.id))
		.filter(heading => isRepeated(old.headings, heading.text) || isRepeated(current.headings, heading.text))
		.filter(heading =>
		{
			const counterpart = currentByPlace.get(placeKey(heading))?.[oldByPlace.get(placeKey(heading)).indexOf(heading)];
			return counterpart != null && counterpart.id !== heading.id;
		})
		.forEach(heading => lost.push({kind: 'anchor', value: heading.id}));
	const oldKeys = keysOf(old.facts);
	const added = current.facts.filter(fact => !oldKeys.has(`${fact.kind}\u0001${fact.value}`));

	return {
		passed: lost.length === 0,
		lost,
		moved: movedFacts,
		added,
		changedFences: missing.filter(fact => fact.kind === 'fence').length,
		changedHeadings: missing.filter(fact => fact.kind === 'heading').map(fact => fact.value)
	};
}

/**
 * Reads the page before the rewrite: a saved file, or the file as it was at a git commit.
 *
 * @param {string} file the page, as given on the command line
 * @param {string} base a git ref, or the path of a saved copy
 * @returns {string} the page before the rewrite
 */
function readBase(file, base)
{
	if(existsSync(base) && statSync(base).isFile())
	{
		return readFileSync(base, 'utf8');
	}
	const absolute = path.resolve(file);
	const top = execFileSync('git', ['rev-parse', '--show-toplevel'], {cwd: path.dirname(absolute), encoding: 'utf8'}).trim();
	const repoPath = path.relative(top, absolute).split(path.sep).join('/');

	return execFileSync('git', ['show', `${base}:${repoPath}`], {cwd: top, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024});
}

/**
 * Shows one fact on one line; a code block shows its first line and its length.
 *
 * @param {{kind: string, value: string}} fact the fact
 * @returns {string} the line to print
 */
function describe(fact)
{
	if(fact.kind !== 'fence')
	{
		return `${fact.kind}: ${fact.value}`;
	}
	const lines = fact.value.split('\n');
	return `fence: \`\`\`${lines[0]} ${JSON.stringify(lines.slice(1, 3).join('\n'))}... (${lines.length - 2} lines)`;
}

/**
 * Runs the check from the command line.
 *
 * @param {string[]} args the command-line arguments after the script name
 * @returns {number} the exit code: 0 when nothing was lost, 1 when something was, 2 for a usage error
 */
export function main(args)
{
	const files = [];
	let base = 'HEAD';
	let movedToFile = null;

	for(let index = 0; index < args.length; index++)
	{
		if(args[index] === '--base')
		{
			base = args[++index];
		}
		else if(args[index] === '--moved-to')
		{
			movedToFile = args[++index];
		}
		else
		{
			files.push(args[index]);
		}
	}
	if(files.length !== 1 || !base || (movedToFile !== null && !existsSync(movedToFile)))
	{
		console.error('Usage: npm run check:rewrite -- <file> [--base <git ref or saved file>] [--moved-to <file>]');
		return 2;
	}

	const [file] = files;
	const result = compareRewrite(readBase(file, base), readFileSync(file, 'utf8'), movedToFile === null ? {} : {movedTo: readFileSync(movedToFile, 'utf8')});

	console.log(`check:rewrite ${file} against ${base}${movedToFile === null ? '' : `, moved sections in ${movedToFile}`}`);
	console.log(`lost (${result.lost.length}):`);
	result.lost.forEach(fact => console.log(`  - ${describe(fact)}`));
	console.log(`moved (${result.moved.length}):`);
	result.moved.forEach(fact => console.log(`  > ${describe(fact)}`));
	console.log(`added (${result.added.length}):`);
	result.added.forEach(fact => console.log(`  + ${describe(fact)}`));
	console.log(`changed fences: ${result.changedFences}; changed headings: ${result.changedHeadings.length ? result.changedHeadings.join(' | ') : 'none'}`);
	console.log(result.passed ? 'PASSED: nothing was lost.' : 'FAILED: the rewrite lost the facts listed above.');
	return result.passed ? 0 : 1;
}

if(process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href)
{
	process.exitCode = main(process.argv.slice(2));
}
