// SPDX-License-Identifier: Apache-2.0
// Checks that each script the release note asks an administrator to run has a copy in the pack that matches it byte for
// byte. The pack runs its copy on the release-testing org, so a copy that drifted from the note proves a script nobody
// will run. For each pair it finds the apex block under the note's heading, compares it with the pack's file, prints one
// line, and exits 1 when any copy differs or a block cannot be found.
'use strict';

const fs = require('fs');
const path = require('path');
const {parseCodeBlocks} = require('../../scripts/validate-docs');

const REPOSITORY_ROOT = path.join(__dirname, '..', '..');
const NOTE_PATH = 'release-notes/Release Notes - Kern 1.8.md';
const SCRIPT_LANGUAGE = 'apex';
const HEADING = /^#{1,6}[ \t]+(.+?)[ \t]*$/;
// Each pack copy, with the heading of the note section whose apex block it copies.
const NOTE_SCRIPTS = [
	{copy: 'release-testing/scripts/mark-stranded-outbound-calls-failed.apex', heading: 'Calls an earlier version left waiting for a retry are not changed by the upgrade'},
	{copy: 'release-testing/scripts/upgrade-repair-ended-chain-runs.apex', heading: 'A chain run that has ended stays ended'}
];

/**
 * @description Reads a file as text, with Windows line endings read as Unix ones, so a checkout on either system
 *              compares the same.
 *
 * @param {string} filePath The file's path.
 *
 * @returns {string} The file's text.
 */
function readText(filePath)
{
	return fs.readFileSync(filePath, 'utf8').replace(/\r\n/g, '\n');
}

/**
 * @description Finds the one apex block between a heading and the next heading of the note. Headings inside a code
 *              block do not count.
 *
 * @param {string} note The note's markdown.
 * @param {string} heading The heading's exact text, without the `#` marks.
 *
 * @returns {string} The block's text with a closing line ending, as the pack's file holds it.
 *
 * @throws {Error} When the heading is missing, or the section holds no apex block or more than one.
 */
function findNoteScript(note, heading)
{
	const blocks = parseCodeBlocks(note);
	const fencedLines = new Set();
	for(const block of blocks)
	{
		for(let line = block.startLine; line <= block.endLine; line++)
		{
			fencedLines.add(line);
		}
	}
	const headings = [];
	note.split('\n').forEach((text, index) =>
	{
		const match = fencedLines.has(index + 1) ? null : text.match(HEADING);
		if(match)
		{
			headings.push({text: match[1], line: index + 1});
		}
	});
	const position = headings.findIndex((candidate) => candidate.text === heading);
	if(position === -1)
	{
		throw new Error(`the note has no heading "${heading}"`);
	}
	const firstLine = headings[position].line;
	const lastLine = position + 1 < headings.length ? headings[position + 1].line : Infinity;
	const scripts = blocks.filter((block) => block.lang === SCRIPT_LANGUAGE && block.startLine > firstLine && block.startLine < lastLine);
	if(scripts.length !== 1)
	{
		throw new Error(`the section "${heading}" holds ${scripts.length} apex blocks, expected 1`);
	}
	return `${scripts[0].code}\n`;
}

/**
 * @description Names the first line where two texts differ.
 *
 * @param {string} expected The note's script.
 * @param {string} actual The pack's copy.
 *
 * @returns {number} The 1-based line number of the first difference.
 */
function firstDifferentLine(expected, actual)
{
	const expectedLines = expected.split('\n');
	const actualLines = actual.split('\n');
	let index = 0;
	while(index < expectedLines.length && expectedLines[index] === actualLines[index])
	{
		index++;
	}
	return index + 1;
}

/**
 * @description Compares each pack copy with the note's script.
 *
 * @param {object} [options] Where to read from.
 * @param {string} [options.root] The repository root.
 * @param {string} [options.notePath] The note, relative to the root.
 * @param {Array<{copy: string, heading: string}>} [options.scripts] The pairs to compare.
 *
 * @returns {Array<{copy: string, same: boolean, detail: string}>} One result per pair.
 */
function compareNoteScripts({root = REPOSITORY_ROOT, notePath = NOTE_PATH, scripts = NOTE_SCRIPTS} = {})
{
	const note = readText(path.join(root, notePath));
	return scripts.map(({copy, heading}) =>
	{
		try
		{
			const expected = findNoteScript(note, heading);
			const actual = readText(path.join(root, copy));
			return expected === actual
				? {copy, same: true, detail: 'matches the note'}
				: {copy, same: false, detail: `differs from the note from line ${firstDifferentLine(expected, actual)}`};
		}
		catch(error)
		{
			return {copy, same: false, detail: error.message};
		}
	});
}

/**
 * @description Prints one line per pair and returns the exit code: 0 when every copy matches, 1 otherwise.
 *
 * @param {object} [options] As for compareNoteScripts, plus `log` to print with.
 *
 * @returns {number} The exit code.
 */
function main(options = {})
{
	const log = options.log || console.log;
	const results = compareNoteScripts(options);
	for(const result of results)
	{
		log(`${result.same ? 'SAME' : 'DIFFERENT'} ${result.copy}: ${result.detail}`);
	}
	return results.every((result) => result.same) ? 0 : 1;
}

if(require.main === module)
{
	process.exitCode = main();
}

module.exports = {NOTE_PATH, NOTE_SCRIPTS, findNoteScript, compareNoteScripts, main};
