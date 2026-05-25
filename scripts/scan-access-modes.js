#!/usr/bin/env node
// SPDX-License-Identifier: BUSL-1.1
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
 *    / .setAccessLevel(. Selector classes that extend SEL_Base and return their
 *    fluent `query` getter are protected by the systemModeRequired() hook, so
 *    calls through `new SEL_X().query` / `this.query` don't hit this rule.
 *
 * 2. Raw SOQL / SOSL calls must pass an explicit AccessLevel argument
 *    - Database.query(
 *    - Database.queryWithBinds(
 *    - Database.getQueryLocator(
 *    - Database.countQuery(
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
	'TST_BuilderInternal.cls'
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
	/\.setAccessLevel\s*\(/
];

const RAW_QUERY_PATTERNS = [
	{re: /Database\.query\s*\(/g, kind: 'Database.query'},
	{re: /Database\.queryWithBinds\s*\(/g, kind: 'Database.queryWithBinds'},
	{re: /Database\.getQueryLocator\s*\(/g, kind: 'Database.getQueryLocator'},
	{re: /Database\.countQuery\s*\(/g, kind: 'Database.countQuery'},
	{re: /Search\.query\s*\(/g, kind: 'Search.query'},
	{re: /Search\.find\s*\(/g, kind: 'Search.find'}
];

const ACCESS_LEVEL_ARG_PATTERN = /\bAccessLevel\b/;

function stripCommentsAndStrings(source)
{
	return source
			.replace(/\/\*[\s\S]*?\*\//g, (match) => ' '.repeat(match.length))
			.replace(/\/\/[^\n]*/g, (match) => ' '.repeat(match.length))
			.replace(/'(?:\\.|[^'\\])*'/g, (match) => '\'' + ' '.repeat(match.length - 2) + '\'');
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

function listApexClassFiles()
{
	return fs.readdirSync(CLASSES_DIR)
			.filter((name) => name.endsWith('.cls'))
			.filter((name) => !name.endsWith('_TEST.cls'))
			.filter((name) => !ALLOWLIST.has(name))
			.map((name) => path.join(CLASSES_DIR, name));
}

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
			if(openParenIndex < 0) { continue; }
			const closeParenIndex = findMatchingCloseParen(cleaned, openParenIndex);
			if(closeParenIndex < 0) { continue; }
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

main();
