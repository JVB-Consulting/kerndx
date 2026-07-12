// SPDX-License-Identifier: BUSL-1.1
/**
 * @fileoverview The PLAN-111 i18n gate: report every hardcoded subscriber-visible
 *               string across LWC `.js`, `.html`, and `.js-meta.xml`.
 *
 * Three legs, one report:
 *   - `.js`   — runs the `kerndx/no-hardcoded-user-text` ESLint rule (via the
 *               isolated scanner/i18n-eslint.config.mjs) and keeps ONLY that
 *               rule's messages, so the broken repo-wide lint and the
 *               "definition for rule not found" noise from other plugins'
 *               disable-directives can never affect the i18n signal.
 *   - `.html` — flags display text nodes and user-facing attribute literals
 *               (label / title / message / alternative-text / field-level-help /
 *               placeholder / aria-label) that are not `{bindings}`.
 *   - `.js-meta.xml` — flags `<targetConfig>` `<property default="...">` literals
 *               (the only meta text a Custom Label can substitute; masterLabel /
 *               description cannot reference labels and are declared i18n gaps).
 *
 * Severity STAGING (scanner/i18n-swept-areas.json): a violation is an ERROR (fails
 * the gate) only when its bundle's sweep is complete; otherwise it is a WARN
 * (reported, non-failing). `alternative-text` stays WARN everywhere until PLAN-113.
 *
 * Escape hatch: put `<!-- i18n-allow -->` on or directly above a line in a
 * template/meta file to suppress a justified literal (API code sample, format
 * token). In `.js`, use `// eslint-disable-next-line kerndx/no-hardcoded-user-text`.
 *
 * Usage:
 *   node scanner/scan-hardcoded-user-text.js            # full tree (CI)
 *   node scanner/scan-hardcoded-user-text.js <files...> # only these (lint-staged)
 *   node scanner/scan-hardcoded-user-text.js --json     # machine-readable output
 */

'use strict';

const fs = require('fs');
const path = require('path');
const {execFileSync} = require('child_process');
const cheerio = require('cheerio');

const REPO_ROOT = path.resolve(__dirname, '..');
const LWC_DIR = path.join(REPO_ROOT, 'force-app', 'main', 'default', 'lwc');
const ESLINT_CONFIG = path.join('scanner', 'i18n-eslint.config.mjs');
const RULE_ID = 'kerndx/no-hardcoded-user-text';

const USER_FACING_ATTRS = new Set([
	'label',
	'title',
	'message',
	'alternative-text',
	'field-level-help',
	'placeholder',
	'aria-label',
	// lightning-input toggle state + validation messages are all subscriber-visible.
	'message-toggle-active',
	'message-toggle-inactive',
	'message-when-value-missing',
	'message-when-bad-input',
	'message-when-too-long',
	'message-when-too-short',
	'message-when-pattern-mismatch',
	'message-when-range-overflow',
	'message-when-range-underflow',
	'message-when-step-mismatch',
	'message-when-type-mismatch'
]);

// ---------------------------------------------------------------------------
// Pure detection helpers (exported for unit tests)
// ---------------------------------------------------------------------------

function indexToLine(source, index)
{
	if(index == null || index < 0)
	{
		return 0;
	}

	let line = 1;

	for(let i = 0; i < index && i < source.length; i++)
	{
		if(source[i] === '\n')
		{
			line++;
		}
	}

	return line;
}

function bundleOf(filePath)
{
	const relative = path.relative(LWC_DIR, path.resolve(filePath));

	return relative.split(path.sep)[0];
}

// The whole value is a single LWC `{binding}` — never a hardcoded literal.
function isBinding(value)
{
	return /^\s*\{[^{}]*\}\s*$/.test(value);
}

// A token-shaped attribute value (icon, css class, url, format token) — not copy.
function isTokenShaped(value)
{
	const trimmed = value.trim();

	if(/\s/.test(trimmed))
	{
		return false;
	}

	// The format-token branch requires a digit or a `:`/`/` separator, so ordinary
	// words built only from date-format letters ('Add', 'Days', 'May') are NOT
	// mistaken for format tokens and skipped.
	const isFormatToken = /[\d:/]/.test(trimmed) && /^[\dMdDyYHhmsSaAZ:/.,'’+_-]+$/.test(trimmed);

	return /^[A-Za-z][\w-]*:[\w-]/.test(trimmed) || /^https?:\/\//i.test(trimmed) || /^(slds|c|lightning)[-/]/.test(trimmed) || isFormatToken;
}

// Display copy = real letters remain after stripping bindings and HTML entities.
function hasDisplayText(value)
{
	const cleaned = value
	.replace(/\{[^{}]*\}/g, ' ')
	.replace(/&#?\w+;/g, ' ')
	.trim();

	return /[A-Za-z]{2,}/.test(cleaned);
}

function isUserFacingValue(value)
{
	if(value == null)
	{
		return false;
	}

	const trimmed = value.trim();

	if(trimmed === '' || isBinding(trimmed) || isTokenShaped(trimmed))
	{
		return false;
	}

	return hasDisplayText(trimmed);
}

// Lines suppressed by an `<!-- i18n-allow -->` marker. A marker alone on its line
// suppresses the NEXT line (like eslint-disable-next-line); an inline marker
// suppresses only its OWN line — so it never collaterally hides a real violation
// on the following line.
function suppressedLines(source)
{
	const suppressed = new Set();
	const lines = source.split('\n');

	lines.forEach((text, index) =>
	{
		if(!/<!--\s*i18n-allow\b/.test(text))
		{
			return;
		}

		const withoutMarker = text.replace(/<!--\s*i18n-allow\b[\s\S]*?-->/g, '').trim();

		suppressed.add(withoutMarker === '' ? index + 2 : index + 1);
	});

	return suppressed;
}

function scanHtml(source, filePath)
{
	const violations = [];
	const suppressed = suppressedLines(source);
	// htmlparser2 mode (isDocument=false): keeps `<template>` children literal —
	// parse5 would hoist them into a hidden content fragment. It indexes elements
	// but not text nodes, so text-node lines are resolved by a document-order cursor.
	const $ = cheerio.load(source, {withStartIndices: true, withEndIndices: true}, false);

	let cursor = 0;

	const visit = (node) =>
	{
		if(!node)
		{
			return;
		}

		if(node.startIndex != null)
		{
			cursor = Math.max(cursor, node.startIndex);
		}

		if(node.type === 'text')
		{
			const at = source.indexOf(node.data, cursor);
			const line = indexToLine(source, at >= 0 ? at : cursor);

			if(at >= 0)
			{
				cursor = at + node.data.length;
			}

			if(isUserFacingValue(node.data))
			{
				violations.push({filePath, line, kind: 'html-text', attr: null, text: node.data.trim()});
			}
		}

		if(node.type === 'tag' && node.attribs)
		{
			for(const attr of Object.keys(node.attribs))
			{
				if(USER_FACING_ATTRS.has(attr) && isUserFacingValue(node.attribs[attr]))
				{
					// A few elements come back without a startIndex from htmlparser2;
					// find the attribute value in source (document-order) as a fallback.
					const at = node.startIndex != null ? node.startIndex : source.indexOf(node.attribs[attr], cursor);

					violations.push({filePath, line: indexToLine(source, at >= 0 ? at : cursor), kind: `html-attr-${attr}`, attr, text: node.attribs[attr].trim()});
				}
			}
		}

		(node.children || []).forEach(visit);
	};

	($.root()[0].children || []).forEach(visit);

	return violations.filter((violation) => !suppressed.has(violation.line));
}

function scanMeta(source, filePath)
{
	const violations = [];
	const suppressed = suppressedLines(source);
	const $ = cheerio.load(source, {xmlMode: true, withStartIndices: true, withEndIndices: true});

	$('targetConfig property').each((index, element) =>
	{
		const attribs = element.attribs || {};
		const value = attribs.default;
		const type = attribs.type;

		// Only String-typed defaults are display copy; Boolean/Integer defaults
		// ('true'/'false'/'5') are configuration values, not translatable text.
		if((type == null || type === 'String') && !/^(true|false|\d+)$/i.test((value || '').trim()) && isUserFacingValue(value))
		{
			violations.push({filePath, line: indexToLine(source, element.startIndex), kind: 'meta-targetconfig-default', attr: 'default', text: value.trim()});
		}
	});

	return violations.filter((violation) => !suppressed.has(violation.line));
}

// ---------------------------------------------------------------------------
// JS leg — the ESLint rule, filtered to just our rule's messages
// ---------------------------------------------------------------------------

function scanJavaScript(jsFiles)
{
	// Only lint files the isolated config actually covers; passing an unmatched
	// path makes eslint exit 2 with empty stdout ("No files matching…").
	const lwcJs = jsFiles.filter((file) => /[/\\]lwc[/\\]/.test(file));

	if(!lwcJs.length)
	{
		return [];
	}

	let raw = '';

	try
	{
		raw = execFileSync('npx', [
			'eslint',
			'--config',
			ESLINT_CONFIG,
			'--format',
			'json',
			...lwcJs
		], {
			cwd: REPO_ROOT, env: {...process.env, ESLINT_USE_FLAT_CONFIG: 'true'}, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024
		});
	}
	catch(error)
	{
		// eslint exits non-zero when any message is an error (e.g. an unrelated
		// "definition for rule not found") — the JSON we want is still on stdout.
		raw = error.stdout ? error.stdout.toString() : '';

		if(!raw)
		{
			throw error;
		}
	}

	const results = JSON.parse(raw);
	const violations = [];

	for(const result of results)
	{
		for(const message of result.messages)
		{
			if(message.ruleId === RULE_ID)
			{
				violations.push(
						{filePath: result.filePath, line: message.line, kind: /toast|thrown/.test(message.message) ? 'js-sink' : 'js-display', attr: null, text: message.message});
			}
			else if(message.fatal)
			{
				// A file that fails to parse contributes zero rule messages — surface
				// it so a broken (or deliberately unparseable) file can't bypass the gate.
				violations.push({filePath: result.filePath, line: message.line || 0, kind: 'js-parse-error', attr: null, text: `Parse error: ${message.message}`});
			}
		}
	}

	return violations;
}

// ---------------------------------------------------------------------------
// File discovery + staging
// ---------------------------------------------------------------------------

function walkFiles(dir, acc)
{
	for(const entry of fs.readdirSync(dir, {withFileTypes: true}))
	{
		const full = path.join(dir, entry.name);

		if(entry.isDirectory())
		{
			if(entry.name !== 'node_modules' && entry.name !== '__tests__')
			{
				walkFiles(full, acc);
			}
		}
		else
		{
			acc.push(full);
		}
	}

	return acc;
}

function classify(files)
{
	const js = [];
	const html = [];
	const meta = [];

	for(const file of files)
	{
		if(file.endsWith('.test.js'))
		{
			continue;
		}

		if(file.endsWith('.js'))
		{
			js.push(file);
		}
		else if(file.endsWith('.html'))
		{
			html.push(file);
		}
		else if(file.endsWith('.js-meta.xml'))
		{
			meta.push(file);
		}
	}

	return {js, html, meta};
}

function loadSweptAreas()
{
	const file = path.join(REPO_ROOT, 'scanner', 'i18n-swept-areas.json');

	try
	{
		return new Set(JSON.parse(fs.readFileSync(file, 'utf8')).swept || []);
	}
	catch(error)
	{
		throw new Error(`Could not read/parse ${path.relative(REPO_ROOT, file)}: ${error.message}`);
	}
}

function severityOf(violation, swept)
{
	// alternative-text is owned by PLAN-113 — enforced but held at WARN for now.
	if(violation.kind === 'html-attr-alternative-text')
	{
		return 'warn';
	}

	return swept.has(bundleOf(violation.filePath)) ? 'error' : 'warn';
}

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

// Above this many warnings, print a per-bundle summary instead of every line
// (keeps a full-tree CI run readable). Errors are always listed in full.
const WARNING_DETAIL_LIMIT = 40;

function run(argv)
{
	const jsonOutput = argv.includes('--json');
	const verbose = argv.includes('--verbose');
	const fileArgs = argv.filter((arg) => !arg.startsWith('--'));

	const targets = fileArgs.length ? fileArgs.map((file) => path.resolve(REPO_ROOT, file)) : walkFiles(LWC_DIR, []);
	const {js, html, meta} = classify(targets);

	const swept = loadSweptAreas();
	const violations = [
		...scanJavaScript(js),
		...html.flatMap((file) => scanHtml(fs.readFileSync(file, 'utf8'), file)),
		...meta.flatMap((file) => scanMeta(fs.readFileSync(file, 'utf8'), file))
	].map((violation) => ({...violation, severity: severityOf(violation, swept)}));

	const errors = violations.filter((violation) => violation.severity === 'error');
	const warnings = violations.filter((violation) => violation.severity === 'warn');

	if(jsonOutput)
	{
		process.stdout.write(`${JSON.stringify({errors, warnings}, null, 2)}\n`);
	}
	else
	{
		report(errors, warnings, verbose);
	}

	return errors.length ? 1 : 0;
}

function listByFile(violations)
{
	const byFile = new Map();

	for(const violation of violations)
	{
		const relative = path.relative(REPO_ROOT, violation.filePath);
		byFile.set(relative, [
			...(byFile.get(relative) || []),
			violation
		]);
	}

	for(const [relative, list] of [...byFile.entries()].sort())
	{
		process.stdout.write(`\n${relative}\n`);

		for(const violation of list.sort((a, b) => a.line - b.line))
		{
			const marker = violation.severity === 'error' ? 'error  ' : 'warning';
			process.stdout.write(`  ${String(violation.line).padStart(4)}  ${marker}  [${violation.kind}]  ${violation.text}\n`);
		}
	}
}

function summariseByBundle(violations)
{
	const byBundle = new Map();

	for(const violation of violations)
	{
		const bundle = bundleOf(violation.filePath);
		byBundle.set(bundle, (byBundle.get(bundle) || 0) + 1);
	}

	for(const [bundle, count] of [...byBundle.entries()].sort((a, b) => b[1] - a[1]))
	{
		process.stdout.write(`  ${String(count).padStart(4)}  ${bundle}\n`);
	}
}

function report(errors, warnings, verbose)
{
	if(errors.length)
	{
		process.stdout.write('\nERRORS (hardcoded user text in a swept area — fix or move to a Custom Label):');
		listByFile(errors);
	}

	if(warnings.length && (verbose || warnings.length <= WARNING_DETAIL_LIMIT))
	{
		process.stdout.write('\nWARNINGS (unswept areas — informational until their sweep lands):');
		listByFile(warnings);
	}
	else if(warnings.length)
	{
		process.stdout.write(`\nWARNINGS by bundle (${warnings.length} total; run with --verbose or on specific files for line detail):\n`);
		summariseByBundle(warnings);
	}

	process.stdout.write(`\ni18n gate: ${errors.length} error(s), ${warnings.length} warning(s)\n`);
	process.stdout.write(errors.length ? '' : 'PASS — no hardcoded user text in swept areas.\n');
}

module.exports = {indexToLine, bundleOf, isBinding, isTokenShaped, hasDisplayText, isUserFacingValue, suppressedLines, scanHtml, scanMeta, severityOf, run};

if(require.main === module)
{
	process.exit(run(process.argv.slice(2)));
}
