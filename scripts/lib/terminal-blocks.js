// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Finds the terminal blocks in a guide (the blocks a reader pastes into a terminal), splits them into
 *              command lines and names each command's shape. Shared by the docs command runner and by the check
 *              that decides whether the Windows workflow needs to start.
 */
'use strict';

const crypto = require('crypto');
const {parseCodeBlocks} = require('../validate-docs');

const TERMINAL_LANGUAGES = ['shell', 'bat', 'bash', 'sh', 'zsh', 'powershell'];
const UNIX_SHELL_LANGUAGES = ['bash', 'sh', 'zsh'];
const TERMINAL_LOOKALIKE_LANGUAGES = ['cmd', 'batch', 'console', 'dos', 'pwsh', 'ps', 'ps1', 'terminal', 'command', 'shell-session'];
const HEADING = /^#{1,6}[ \t]+(.+?)[ \t]*$/;

/**
 * @description Lists the headings of a guide, skipping any line that sits inside a code block.
 * @param {string} content - The guide's markdown.
 * @returns {Array<{text: string, line: number}>} Heading texts with their 1-based line numbers.
 */
function headingLines(content)
{
	const fenced = new Set();
	for(const block of parseCodeBlocks(content))
	{
		for(let line = block.startLine; line <= block.endLine; line++)
		{
			fenced.add(line);
		}
	}
	const headings = [];
	content.split('\n').forEach((text, index) =>
	{
		const match = fenced.has(index + 1) ? null : text.match(HEADING);
		if(match)
		{
			headings.push({text: match[1], line: index + 1});
		}
	});
	return headings;
}

/**
 * @description The line range a scope names: from a heading to another, optionally only after a third, earlier one
 *              (for a heading text the guide repeats). Exact heading texts, without the `#` marks.
 * @param {Array<{text: string, line: number}>} headings - The guide's headings.
 * @param {string} guide - For the error message.
 * @param {{fromHeading?: string, untilHeading?: string, afterHeading?: string}} scope - The range.
 * @returns {{firstLine: number, lastLine: number}} Inclusive start, exclusive end.
 */
function rangeOf(headings, guide, scope)
{
	const find = (text, notBefore) =>
	{
		const heading = headings.find(candidate => candidate.text === text && candidate.line >= notBefore);
		if(!heading)
		{
			throw new Error(`${guide}: no heading "${text}"`);
		}
		return heading;
	};
	const after = scope.afterHeading ? find(scope.afterHeading, 1).line : 1;
	const from = scope.fromHeading ? find(scope.fromHeading, after) : null;
	const until = scope.untilHeading ? find(scope.untilHeading, from ? from.line : after) : null;
	return {firstLine: from ? from.line : after, lastLine: until ? until.line : Infinity};
}

/**
 * @description The code blocks of a guide inside a scope's range, with Windows line endings read as Unix ones.
 * @param {string} content - The guide's markdown.
 * @param {string} guide - The guide's repository-relative path.
 * @param {Object} scope - The range (see rangeOf).
 * @returns {Array<{lang: string, code: string, startLine: number}>} The blocks in range.
 */
function blocksInRange(content, guide, scope)
{
	const text = content.replace(/\r\n/g, '\n');
	const {firstLine, lastLine} = rangeOf(headingLines(text), guide, scope);
	return parseCodeBlocks(text).filter(block => block.startLine >= firstLine && block.startLine < lastLine);
}

/**
 * @description Returns the guide's terminal blocks, optionally only those between two headings. A guide checked out
 *              with Windows line endings reads the same as one with Unix line endings.
 * @param {string} content - The guide's markdown.
 * @param {string} guide - The guide's repository-relative path, carried into every block.
 * @param {{fromHeading?: string, untilHeading?: string, afterHeading?: string}} [scope] - Exact heading texts, without the `#` marks.
 * @returns {Array<{guide: string, language: string, startLine: number, code: string}>} The terminal blocks.
 */
function extractTerminalBlocks(content, guide, scope = {})
{
	return blocksInRange(content, guide, scope)
		.filter(block => TERMINAL_LANGUAGES.includes(block.lang.toLowerCase()))
		.map(block => ({guide, language: block.lang.toLowerCase(), startLine: block.startLine, code: block.code}));
}

/**
 * @description The blocks fenced with a language that looks like a terminal but that the runner does not run: a
 *              guide author's mistake the runner must name rather than skip.
 * @param {string} content - The guide's markdown.
 * @param {string} guide - The guide's repository-relative path.
 * @param {Object} [scope] - The range.
 * @returns {Array<{guide: string, language: string, startLine: number}>} The lookalike blocks.
 */
function lookalikeTerminalBlocks(content, guide, scope = {})
{
	return blocksInRange(content, guide, scope)
		.filter(block => TERMINAL_LOOKALIKE_LANGUAGES.includes(block.lang.toLowerCase()))
		.map(block => ({guide, language: block.lang.toLowerCase(), startLine: block.startLine}));
}

/**
 * @description Splits a block into the command lines a reader would run. A bash block may still continue a line
 *              with a backslash and carry comments; a shell or bat block is taken exactly as written.
 * @param {{language: string, code: string}} block - One terminal block.
 * @returns {string[]} The command lines, trimmed, blank lines removed.
 */
function commandLines(block)
{
	const isUnixShell = UNIX_SHELL_LANGUAGES.includes(block.language);
	const code = isUnixShell ? block.code.replace(/\\\n[ \t]*/g, '') : block.code;
	return code.split('\n').map(line => line.trim()).filter(line => line && !(isUnixShell && line.startsWith('#')));
}

/**
 * @description Names the kind of command: the tool, its subcommand words and its sorted flag names.
 * @param {string} commandLine - One command line.
 * @returns {string} For example `sf project deploy start [--ignore-conflicts -m -o]`.
 */
function commandShape(commandLine)
{
	const words = commandLine.split(/\s+/);
	const head = [];
	for(const word of words)
	{
		if(word.startsWith('-') || /[:="'/.@<>|]/.test(word) || head.length === 4)
		{
			break;
		}
		head.push(word);
	}
	const flags = [...new Set(words.filter(word => /^--?[a-zA-Z]/.test(word)).map(word => word.replace(/=.*/, '')))].sort();
	return `${head.join(' ')} [${flags.join(' ')}]`;
}

/**
 * @description One hash over every terminal block, so two versions of a guide can be compared without its prose.
 * @param {Array<{guide: string, language: string, code: string}>} blocks - Terminal blocks.
 * @returns {string} A SHA-256 hex digest.
 */
function fingerprint(blocks)
{
	const material = blocks.map(block => [block.guide, block.language, block.code]);
	return crypto.createHash('sha256').update(JSON.stringify(material)).digest('hex');
}

module.exports = {TERMINAL_LANGUAGES, TERMINAL_LOOKALIKE_LANGUAGES, extractTerminalBlocks, lookalikeTerminalBlocks, commandLines, commandShape, fingerprint};
