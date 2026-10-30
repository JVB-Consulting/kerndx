#!/usr/bin/env node
// SPDX-License-Identifier: Apache-2.0
/**
 * KernDX access-mode scanner.
 *
 * Two rule families enforce secure-by-default across production .cls files:
 *
 * 1. Builder trigger calls must chain an explicit access-mode declaration
 *    - QRY_Builder.selectFrom(
 *    - DML_Builder.newTransaction(
 *    - new DML_Transaction(
 *    …must be followed (within 500 chars) by .withUserMode() / .withSystemMode()
 *    / .setAccessLevel( / .systemModeInternal(. Selector classes that extend SEL_Base and return their
 *    fluent `query` getter are protected by the systemModeRequired() hook, so
 *    calls through `new SEL_X().query` / `this.query` don't hit this rule.
 *
 * 2. Raw SOQL / SOSL calls must pass an explicit AccessLevel argument
 *    - Database.query(
 *    - Database.queryWithBinds(
 *    - Database.getQueryLocator(
 *    - Database.countQuery(
 *    - Database.getQueryLocatorWithBinds(
 *    - Database.countQueryWithBinds(
 *    - Search.query(
 *    - Search.find(
 *    …must include `AccessLevel` inside the argument list (either literal
 *    `AccessLevel.USER_MODE` / `AccessLevel.SYSTEM_MODE` or a typed
 *    `AccessLevel` variable passed through from caller).
 *
 * Framework-internal files that define the primitives themselves are
 * allowlisted.
 *
 * Usage: node scripts/scan-access-modes.js
 * Exits 0 on clean, 1 on any violation.
 */

'use strict';

const fs = require('fs');
const path = require('path');

const PROJECT_ROOT = path.resolve(__dirname, '..');
const CLASSES_DIR = path.join(PROJECT_ROOT, 'force-app/main/default/classes');

const ALLOWLIST = new Set([
	'QRY_Builder.cls',
	'QRY_Condition.cls',
	'QRY_Engine.cls',
	'SEL_Base.cls',
	'DML_Builder.cls',
	'DML_Transaction.cls',
	'DML_SharingProxy.cls',
	'TST_Factory.cls',
	'TST_BuilderInternal.cls',
	'PROC_ExecuteDML.cls',    // when the caller passes no access level, it deliberately leaves the builder on the flag-driven default
	'UTIL_PurgeRecords.cls'    // the purge query inherits the flag-driven default by design, the contract its test class states
]);

const WINDOW_CHARS = 500;

const BUILDER_PATTERNS = [
	{re: /QRY_Builder\.selectFrom\s*\(/g, kind: 'QRY_Builder.selectFrom'},
	{re: /DML_Builder\.newTransaction\s*\(/g, kind: 'DML_Builder.newTransaction'},
	{re: /new\s+DML_Transaction\s*\(/g, kind: 'new DML_Transaction'}
];

const DECLARATION_PATTERNS = [
	/\.withUserMode\s*\(/,
	/\.withSystemMode\s*\(/,
	/\.setAccessLevel\s*\(/,
	/\.systemModeInternal\s*\(/
];

const RAW_QUERY_PATTERNS = [
	{re: /Database\.query\s*\(/g, kind: 'Database.query'},
	{re: /Database\.queryWithBinds\s*\(/g, kind: 'Database.queryWithBinds'},
	{re: /Database\.getQueryLocator\s*\(/g, kind: 'Database.getQueryLocator'},
	{re: /Database\.countQuery\s*\(/g, kind: 'Database.countQuery'},
	{re: /Database\.getQueryLocatorWithBinds\s*\(/g, kind: 'Database.getQueryLocatorWithBinds'},
	{re: /Database\.countQueryWithBinds\s*\(/g, kind: 'Database.countQueryWithBinds'},
	{re: /Database\.getCursor\s*\(/g, kind: 'Database.getCursor'},
	{re: /Database\.getCursorWithBinds\s*\(/g, kind: 'Database.getCursorWithBinds'},
	{re: /Search\.query\s*\(/g, kind: 'Search.query'},
	{re: /Search\.find\s*\(/g, kind: 'Search.find'}
];

const ACCESS_LEVEL_ARG_PATTERN = /\bAccessLevel\b/;

function stripCommentsAndStrings(source)
{
	return source.replace(/'(?:\\.|[^'\\\n])*'|\/\*[\s\S]*?\*\/|\/\/[^\n]*/g, (match) =>
	{
		if(match.startsWith('\''))
		{
			return '\'' + ' '.repeat(match.length - 2) + '\'';
		}
		return match.replace(/[^\n]/g, ' ');
	});
}

function findLineNumber(source, charIndex)
{
	return source.slice(0, charIndex).split('\n').length;
}

function findMatchingCloseParen(text, openIndex)
{
	let depth = 0;
	for(let i = openIndex; i < text.length; i++)
	{
		const character = text[i];
		if(character === '(')
		{
			depth++;
		}
		else if(character === ')')
		{
			depth--;
			if(depth === 0)
			{
				return i;
			}
		}
	}
	return -1;
}

/**
 * @description The production Apex classes to scan: every `.cls` file in the folder that is neither a test class nor
 *              on the allow-list.
 * @param {string} [directory] - The classes folder; this repository's by default.
 * @returns {string[]} The class file paths.
 */
function listApexClassFiles(directory = CLASSES_DIR)
{
	return fs.readdirSync(directory)
	.filter((name) => name.endsWith('.cls'))
	.filter((name) => !name.endsWith('_TEST.cls'))
	.filter((name) => !ALLOWLIST.has(name))
	.map((name) => path.join(directory, name));
}

/**
 * @description Scans one Apex class for builder chains with no access-mode declaration within the window, and raw
 *              SOQL or SOSL calls with no AccessLevel argument. Comments and string contents are ignored.
 * @param {string} filePath - The class file.
 * @returns {Array<{file: string, line: number, kind: string, snippet: string, remedy: string}>} The violations found.
 */
function scanFile(filePath)
{
	const source = fs.readFileSync(filePath, 'utf8');
	const cleaned = stripCommentsAndStrings(source);
	const violations = [];

	for(const {re, kind} of BUILDER_PATTERNS)
	{
		re.lastIndex = 0;
		let match;
		while((match = re.exec(cleaned)) !== null)
		{
			const start = match.index;
			const windowText = cleaned.slice(start, start + WINDOW_CHARS);
			const hasDeclaration = DECLARATION_PATTERNS.some((pattern) => pattern.test(windowText));
			if(!hasDeclaration)
			{
				violations.push({
					file: path.relative(PROJECT_ROOT, filePath),
					line: findLineNumber(source, start),
					kind,
					snippet: source.slice(start, start + 120).replace(/\s+/g, ' '),
					remedy: '.withUserMode() / .withSystemMode() / .setAccessLevel()'
				});
			}
		}
	}

	for(const {re, kind} of RAW_QUERY_PATTERNS)
	{
		re.lastIndex = 0;
		let match;
		while((match = re.exec(cleaned)) !== null)
		{
			const openParenIndex = cleaned.indexOf('(', match.index);
			if(openParenIndex < 0)
			{
				continue;
			}
			const closeParenIndex = findMatchingCloseParen(cleaned, openParenIndex);
			if(closeParenIndex < 0)
			{
				continue;
			}
			const argsText = cleaned.slice(openParenIndex + 1, closeParenIndex);
			if(!ACCESS_LEVEL_ARG_PATTERN.test(argsText))
			{
				violations.push({
					file: path.relative(PROJECT_ROOT, filePath),
					line: findLineNumber(source, match.index),
					kind,
					snippet: source.slice(match.index, match.index + 120).replace(/\s+/g, ' '),
					remedy: `pass AccessLevel.USER_MODE or AccessLevel.SYSTEM_MODE as an argument`
				});
			}
		}
	}

	return violations;
}

function main()
{
	const files = listApexClassFiles();
	const allViolations = [];

	for(const filePath of files)
	{
		const violations = scanFile(filePath);
		allViolations.push(...violations);
	}

	if(allViolations.length === 0)
	{
		console.log(`✓ Scanned ${files.length} production .cls files — no access-mode violations.`);
		process.exit(0);
	}

	console.error(`✗ ${allViolations.length} access-mode violation(s) across ${new Set(allViolations.map((v) => v.file)).size} file(s):\n`);
	for(const {file, line, kind, snippet, remedy} of allViolations)
	{
		console.error(`  ${file}:${line}  ${kind} missing access-mode declaration`);
		console.error(`    remedy: ${remedy}`);
		console.error(`    ${snippet}\n`);
	}
	console.error('Every production call that queries or commits data must declare an explicit access mode. This enforces secure-by-default.');
	process.exit(1);
}

module.exports = {listApexClassFiles, scanFile};

if(require.main === module)
{
	main();
}
