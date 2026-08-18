#!/usr/bin/env node
// SPDX-License-Identifier: BUSL-1.1
'use strict';

/**
 * @description Validator for docs/Strategic Guide - Metrics.md numeric
 *              claims. Recomputes each metric from source and compares
 *              against the documented value. Reports drift so the doc
 *              can be kept honest as the codebase grows.
 *
 *              Wired into npm run docs:validate via scripts/validate-docs.js.
 *              Exits non-zero on any unaccounted-for drift.
 *
 *              Why this is its own file (not inside validate-docs.js): the
 *              metric computations are codebase-traversal heavy and benefit
 *              from being unit-testable in isolation. validate-docs.js
 *              focuses on markdown structure + prose-ref + doc-claim
 *              checks; this script focuses on numeric claims in a single
 *              specific document.
 *
 * @author Kern Framework
 * @date May 2026
 */

const fs = require('node:fs');
const path = require('node:path');

const counts = require('./lib/metrics-counts');

const REPO_ROOT = path.resolve(__dirname, '..');
const METRICS_FILE_RELATIVE = path.join('docs', 'Strategic Guide - Metrics.md');

// Combined Test Coverage rollup rows carry a unit word in the "Tests" column
// (e.g. `4,064 methods`), so the generic numeric-column parser cannot see them.
// This map wires each rollup label to the claim key it echoes (or, for the
// Total row, the sum key) so those cells are read + validated explicitly.
const ROLLUP_LABEL_KEYS = {
	'package apex tests': 'rollupApexTestMethods',
	'package jest tests': 'rollupJestTestCases',
	'subscriber apex tests': 'rollupSubscriberTestMethods',
	'subscriber anonymous apex': 'rollupAnonymousApexSections',
	'subscriber e2e (playwright)': 'rollupE2eFunctionalCases',
	'total': 'rollupTestsTotal'
};

function countFiles(dir, predicate)
{
	if(!fs.existsSync(dir))
	{
		return 0;
	}
	let count = 0;
	for(const entry of fs.readdirSync(dir, {withFileTypes: true}))
	{
		const full = path.join(dir, entry.name);
		if(entry.isDirectory())
		{
			count += countFiles(full, predicate);
		}
		else if(entry.isFile() && predicate(full))
		{
			count++;
		}
	}
	return count;
}

function collectFiles(dir, predicate)
{
	const out = [];
	if(!fs.existsSync(dir))
	{
		return out;
	}
	for(const entry of fs.readdirSync(dir, {withFileTypes: true}))
	{
		const full = path.join(dir, entry.name);
		if(entry.isDirectory())
		{
			out.push(...collectFiles(full, predicate));
		}
		else if(entry.isFile() && predicate(full))
		{
			out.push(full);
		}
	}
	return out;
}

function countLwcDirs(repoRoot)
{
	const lwcRoot = path.join(repoRoot, 'force-app', 'main', 'default', 'lwc');
	if(!fs.existsSync(lwcRoot))
	{
		return 0;
	}
	return fs.readdirSync(lwcRoot, {withFileTypes: true})
	.filter(e => e.isDirectory()).length;
}

function countLineStartIsTestMethods(repoRoot)
{
	// "Apex test methods" = method-level `@IsTest` annotations only.
	// Excludes class-level `@IsTest(SeeAllData=...)`, `@IsTest(IsParallel=...)`
	// and other parameterized variants — those wrap a class, not a method.
	const dir = path.join(repoRoot, 'force-app', 'main', 'default', 'classes');
	if(!fs.existsSync(dir))
	{
		return 0;
	}
	let count = 0;
	for(const entry of fs.readdirSync(dir))
	{
		if(!entry.endsWith('_TEST.cls'))
		{
			continue;
		}
		const text = fs.readFileSync(path.join(dir, entry), 'utf-8');
		const lines = text.split('\n');
		for(const line of lines)
		{
			const trimmed = line.trimStart();
			if(!trimmed.startsWith('@IsTest'))
			{
				continue;
			}
			if(trimmed.includes('(') || trimmed.includes('class ') || line === trimmed)
			{
				continue;
			}
			count++;
		}
	}
	return count;
}

function countLwcJestCases(repoRoot)
{
	// Jest test cases = `it(` / `test(` declarations across every LWC *.test.js.
	// Line-anchored so a dotted variant (`it.each(`, `test.only(`) or an inline
	// `it(` inside a comment/string is not counted — the doc's "counted across
	// all Jest test files" figure is the plain per-`it`/`test` declaration count.
	const dir = path.join(repoRoot, 'force-app', 'main', 'default', 'lwc');
	const re = /^\s*(it|test)\s*\(/;
	let count = 0;
	for(const file of collectFiles(dir, f => f.endsWith('.test.js')))
	{
		for(const line of fs.readFileSync(file, 'utf-8').split('\n'))
		{
			if(re.test(line))
			{
				count++;
			}
		}
	}
	return count;
}

function countE2eFunctionalCases(repoRoot)
{
	// Functional release-verification e2e cases only: `test(` declarations in the
	// numbered part specs (`partN-*.spec.js`). The `capture-*` screenshot specs
	// are excluded, and the line-anchored match ignores `test.setTimeout(...)` /
	// `test.skip(condition)` modifiers that are not test declarations.
	const dir = path.join(repoRoot, 'release-testing', 'e2e', 'specs');
	if(!fs.existsSync(dir))
	{
		return 0;
	}
	const re = /^\s*test\s*\(/;
	let count = 0;
	for(const entry of fs.readdirSync(dir))
	{
		if(!/^part\d+.*\.spec\.js$/.test(entry))
		{
			continue;
		}
		for(const line of fs.readFileSync(path.join(dir, entry), 'utf-8').split('\n'))
		{
			if(re.test(line))
			{
				count++;
			}
		}
	}
	return count;
}

function countAnonymousApexSections(repoRoot)
{
	// One "section" = one distinct numeric id among the release-testing section
	// scripts (`release-testing/scripts/section-<N>...`). A section can span
	// several files that share a number (setup / cleanup / `b`-suffixed verify
	// halves), and two sections are load harnesses authored as `.js`; the RUNBOOK
	// enumerates all of them as sections, so the count is the number of distinct
	// <N>, not the file count.
	const dir = path.join(repoRoot, 'release-testing', 'scripts');
	if(!fs.existsSync(dir))
	{
		return 0;
	}
	const numbers = new Set();
	for(const entry of fs.readdirSync(dir))
	{
		if(!entry.endsWith('.apex') && !entry.endsWith('.js'))
		{
			continue;
		}
		const match = entry.match(/^section-(\d+)/);
		if(match)
		{
			numbers.add(parseInt(match[1], 10));
		}
	}
	return numbers.size;
}

function countPatternInSectionApex(repoRoot, pattern)
{
	// Total occurrences of a pattern across the anonymous-Apex section scripts
	// (release-testing/scripts/section-<N>*.apex). `.js` load harnesses are
	// excluded — they carry no `PASS:` / `Assert.` assertion markers.
	const dir = path.join(repoRoot, 'release-testing', 'scripts');
	if(!fs.existsSync(dir))
	{
		return 0;
	}
	let count = 0;
	for(const entry of fs.readdirSync(dir))
	{
		if(!/^section-\d+.*\.apex$/.test(entry))
		{
			continue;
		}
		const matches = fs.readFileSync(path.join(dir, entry), 'utf-8').match(pattern);
		if(matches)
		{
			count += matches.length;
		}
	}
	return count;
}

function countAnonymousApexPassAssertions(repoRoot)
{
	// `PASS:` markers the anonymous-Apex scripts print on a successful assertion.
	return countPatternInSectionApex(repoRoot, /PASS:/g);
}

function countAnonymousApexAssertAssertions(repoRoot)
{
	// Native `Assert.*` assertion calls in the anonymous-Apex scripts.
	return countPatternInSectionApex(repoRoot, /Assert\./g);
}

function computeExpected(repoRoot)
{
	const classesDir = path.join(repoRoot, 'force-app', 'main', 'default', 'classes');
	const lwcDir = path.join(repoRoot, 'force-app', 'main', 'default', 'lwc');
	const docsDir = path.join(repoRoot, 'docs');
	const referenceDir = path.join(docsDir, 'reference');
	const releaseTestingClassesDir = path.join(repoRoot, 'release-testing', 'subscriber', 'classes');

	const apexProduction = countFiles(classesDir, f => f.endsWith('.cls') && !f.endsWith('_TEST.cls'));
	const apexTest = countFiles(classesDir, f => f.endsWith('_TEST.cls'));
	const apexTotal = apexProduction + apexTest;
	const apexTestMethods = countLineStartIsTestMethods(repoRoot);
	const lwcDirs = countLwcDirs(repoRoot);
	const lwcTestFiles = countFiles(lwcDir, f => f.endsWith('.test.js'));

	const fastStartGuides = fs.existsSync(docsDir) ? fs.readdirSync(docsDir).filter(f => f.startsWith('Fast Start - ') && f.endsWith('.md')).length : 0;
	const developerGuides = fs.existsSync(docsDir) ? fs.readdirSync(docsDir).filter(f => f.endsWith(' - Guide.md')).length : 0;
	const strategicGuidesSource = fs.existsSync(docsDir) ? fs.readdirSync(docsDir).filter(f => f.startsWith('Strategic Guide - ') && f.endsWith('.md')).length : 0;
	// Strategic Guide count: source-tree files matching the pattern minus
	// internal-only guides (which are excluded from the release artifact;
	// substring filtering keeps the count consistent in both trees).
	const INTERNAL_ONLY_GUIDE_MARKERS = [];
	const strategicGuidesShipped = fs.existsSync(docsDir) ? fs.readdirSync(docsDir)
	.filter(f => f.startsWith('Strategic Guide - ') && f.endsWith('.md') && !INTERNAL_ONLY_GUIDE_MARKERS.some(marker => f.includes(marker))).length : 0;

	const apexReference = fs.existsSync(path.join(referenceDir, 'apex')) ? fs.readdirSync(path.join(referenceDir, 'apex')).filter(f => f.endsWith('.md')).length : 0;
	const metadataReference = fs.existsSync(path.join(referenceDir, 'metadata')) ? fs.readdirSync(path.join(referenceDir, 'metadata')).filter(f => f.endsWith('.md')).length : 0;
	const objectsReference = fs.existsSync(path.join(referenceDir, 'objects')) ? fs.readdirSync(path.join(referenceDir, 'objects')).filter(f => f.endsWith('.md')).length : 0;
	const eventsReference = fs.existsSync(path.join(referenceDir, 'events')) ? fs.readdirSync(path.join(referenceDir, 'events')).filter(f => f.endsWith('.md')).length : 0;
	const referenceTotal = apexReference + metadataReference + objectsReference + eventsReference;
	const totalDocFiles = developerGuides + fastStartGuides + strategicGuidesShipped;

	const subscriberApexProduction = countFiles(releaseTestingClassesDir, f => f.endsWith('.cls') && !f.endsWith('_TEST.cls'));
	const subscriberApexTest = countFiles(releaseTestingClassesDir, f => f.endsWith('_TEST.cls'));
	const subscriberTestMethods = (function()
	{
		if(!fs.existsSync(releaseTestingClassesDir))
		{
			return 0;
		}
		let count = 0;
		for(const entry of fs.readdirSync(releaseTestingClassesDir))
		{
			if(!entry.endsWith('_TEST.cls'))
			{
				continue;
			}
			const text = fs.readFileSync(path.join(releaseTestingClassesDir, entry), 'utf-8');
			const lines = text.split('\n');
			for(const line of lines)
			{
				const trimmed = line.trimStart();
				if(!trimmed.startsWith('@IsTest'))
				{
					continue;
				}
				if(trimmed.includes('(') || trimmed.includes('class '))
				{
					continue;
				}
				count++;
			}
		}
		return count;
	})();

	const e2eSpecFiles = countFiles(path.join(repoRoot, 'release-testing', 'e2e'), f => f.endsWith('.spec.js'));

	const jestTestCases = countLwcJestCases(repoRoot);
	const e2eFunctionalCases = countE2eFunctionalCases(repoRoot);
	const anonymousApexSections = countAnonymousApexSections(repoRoot);
	const anonymousApexAssertionsPass = countAnonymousApexPassAssertions(repoRoot);
	const anonymousApexAssertionsAssert = countAnonymousApexAssertAssertions(repoRoot);

	// Combined Test Coverage rollup — the countable "Tests" column echoes the five
	// per-layer metrics; the Total is their exact sum. Each echo is validated
	// against its own source count, and the total against the sum, so the rollup
	// cannot silently drift from the per-section rows (the "~<lines>" Assertions
	// column is a hand-maintained estimate and is intentionally not validated).
	const rollupTestsTotal = apexTestMethods + jestTestCases + subscriberTestMethods + anonymousApexSections + e2eFunctionalCases;

	const customObjects = counts.countCustomObjects(repoRoot);
	const cmdtTypes = counts.countCmdtTypes(repoRoot);
	const platformEvents = counts.countPlatformEvents(repoRoot);
	const customFields = counts.countCustomFields(repoRoot);

	// Scanner checks: one ESLint rule per file under the plugin's rules/, one
	// PMD rule per `<rule name=` definition in the full ruleset (subsets only
	// reference or copy these). The four standalone Node validators the guide's
	// table counts (Flow/Object naming, field naming, secret scan, scanner
	// parity) have no directly countable unit, so they stay a named constant.
	const eslintRules = countFiles(path.join(repoRoot, 'scanner', 'eslint-plugin-kerndx', 'rules'), f => f.endsWith('.js'));
	const pmdRulesetXml = path.join(repoRoot, 'scanner', 'kerndx-pmd-ruleset.xml');
	const pmdCustomRules = fs.existsSync(pmdRulesetXml)
		? (fs.readFileSync(pmdRulesetXml, 'utf-8').match(/<rule name="/g) || []).length
		: 0;
	const NODE_VALIDATOR_COUNT = 4;
	const totalScannerChecks = pmdCustomRules + eslintRules + NODE_VALIDATOR_COUNT;

	return {
		eslintRules,
		pmdCustomRules,
		totalScannerChecks,
		apexProduction,
		apexTest,
		apexTotal,
		apexTestMethods,
		lwcDirs,
		lwcTestFiles,
		fastStartGuides,
		developerGuides,
		strategicGuidesShipped,
		apexReference,
		metadataReference,
		objectsReference,
		eventsReference,
		referenceTotal,
		totalDocFiles,
		subscriberApexProduction,
		subscriberApexTest,
		subscriberTestMethods,
		e2eSpecFiles,
		jestTestCases,
		e2eFunctionalCases,
		anonymousApexSections,
		anonymousApexAssertionsPass,
		anonymousApexAssertionsAssert,
		rollupApexTestMethods: apexTestMethods,
		rollupJestTestCases: jestTestCases,
		rollupSubscriberTestMethods: subscriberTestMethods,
		rollupAnonymousApexSections: anonymousApexSections,
		rollupE2eFunctionalCases: e2eFunctionalCases,
		rollupTestsTotal,
		customObjects,
		cmdtTypes,
		platformEvents,
		customFieldsTotal: customFields.total
	};
}

function parseDocClaims(content)
{
	const claims = new Map();

	function setIfMissing(key, value, line)
	{
		if(!claims.has(key))
		{
			claims.set(key, {value, line});
		}
	}

	const lines = content.split('\n');
	let inCombinedTable = false;
	for(let i = 0; i < lines.length; i++)
	{
		const line = lines[i];

		// Track the Combined Test Coverage section so its rollup rows — whose
		// "Tests" cells carry a unit word (`methods`/`cases`/`sections`) or bold
		// markers and so are invisible to the generic numeric-column parser — can
		// be read explicitly against ROLLUP_LABEL_KEYS.
		const heading = line.match(/^##\s+(.*)/);
		if(heading)
		{
			inCombinedTable = /^combined test coverage$/i.test(heading[1].trim());
		}
		if(inCombinedTable && /^\|/.test(line))
		{
			const cells = line.split('|');
			if(cells.length >= 4)
			{
				const rollupLabel = cells[1].replace(/[`*_]/g, '').trim().toLowerCase();
				const rollupKey = ROLLUP_LABEL_KEYS[rollupLabel];
				if(rollupKey)
				{
					const numMatch = cells[2].replace(/,/g, '').match(/\d+/);
					if(numMatch)
					{
						setIfMissing(rollupKey, parseInt(numMatch[0], 10), i + 1);
					}
				}
			}
		}

		const matchRow = line.match(/^\|\s*(.+?)\s*\|\s*([\d,~+\sK%]+)\s*(?:\||$)/);
		if(!matchRow)
		{
			continue;
		}
		const label = matchRow[1].replace(/[`*_]/g, '').trim();
		const raw = matchRow[2].replace(/[~,\s]/g, '');
		const value = parseInt(raw, 10);
		if(Number.isNaN(value))
		{
			continue;
		}

		const labelLc = label.toLowerCase();

		if(labelLc === 'apex classes (total)')
		{
			setIfMissing('apexTotal', value, i + 1);
		}
		if(labelLc === 'apex production classes')
		{
			setIfMissing('apexProduction', value, i + 1);
		}
		if(labelLc === 'apex test classes')
		{
			setIfMissing('apexTest', value, i + 1);
		}
		if(labelLc === 'apex test methods')
		{
			setIfMissing('apexTestMethods', value, i + 1);
		}
		// Parsed for the public README badge synthesizer (not source-validated:
		// the global top-level count is maintained by hand in the Metrics doc).
		if(labelLc === 'global classes (top-level)')
		{
			setIfMissing('globalClasses', value, i + 1);
		}
		if(labelLc === 'lwc components (total)')
		{
			setIfMissing('lwcDirs', value, i + 1);
		}
		if(labelLc === 'jest test files')
		{
			setIfMissing('lwcTestFiles', value, i + 1);
		}
		if(labelLc === 'pmd rules (kerndx custom)')
		{
			setIfMissing('pmdCustomRules', value, i + 1);
		}
		if(labelLc === 'eslint rules (kerndx custom)')
		{
			setIfMissing('eslintRules', value, i + 1);
		}
		if(labelLc === 'total scanner checks')
		{
			setIfMissing('totalScannerChecks', value, i + 1);
		}
		if(labelLc === 'developer guides')
		{
			setIfMissing('developerGuides', value, i + 1);
		}
		if(labelLc === 'fast start guides')
		{
			setIfMissing('fastStartGuides', value, i + 1);
		}
		if(labelLc === 'strategic guide documents')
		{
			setIfMissing('strategicGuidesShipped', value, i + 1);
		}
		if(labelLc === 'api reference pages (apex)')
		{
			setIfMissing('apexReference', value, i + 1);
		}
		if(labelLc === 'api reference pages (metadata)')
		{
			setIfMissing('metadataReference', value, i + 1);
		}
		if(labelLc === 'api reference pages (objects)')
		{
			setIfMissing('objectsReference', value, i + 1);
		}
		if(labelLc === 'api reference pages (events)')
		{
			setIfMissing('eventsReference', value, i + 1);
		}
		if(labelLc === 'api reference pages (total)')
		{
			setIfMissing('referenceTotal', value, i + 1);
		}
		if(labelLc === 'total documentation files (developer-focused)')
		{
			setIfMissing('totalDocFiles', value, i + 1);
		}
		if(labelLc === 'subscriber apex classes (production)')
		{
			setIfMissing('subscriberApexProduction', value, i + 1);
		}
		if(labelLc === 'subscriber test classes')
		{
			setIfMissing('subscriberApexTest', value, i + 1);
		}
		if(labelLc === 'subscriber test methods')
		{
			setIfMissing('subscriberTestMethods', value, i + 1);
		}
		if(labelLc === 'spec files')
		{
			setIfMissing('e2eSpecFiles', value, i + 1);
		}
		if(labelLc === 'jest test cases')
		{
			setIfMissing('jestTestCases', value, i + 1);
		}
		if(labelLc === 'test cases')
		{
			setIfMissing('e2eFunctionalCases', value, i + 1);
		}
		if(labelLc === 'anonymous apex test sections')
		{
			setIfMissing('anonymousApexSections', value, i + 1);
		}
		// Backticks are stripped from the label, so `PASS:` -> "pass:" and
		// `Assert.` -> "assert.".
		if(labelLc === 'anonymous apex assertions (pass:)')
		{
			setIfMissing('anonymousApexAssertionsPass', value, i + 1);
		}
		if(labelLc === 'anonymous apex assertions (assert.)')
		{
			setIfMissing('anonymousApexAssertionsAssert', value, i + 1);
		}
		// Salesforce Metadata section. parseDocClaims strips backticks and
		// underscores from the label, so `__c` -> "c", `__mdt` -> "mdt",
		// `__e` -> "e".
		if(labelLc === 'custom objects (c)')
		{
			setIfMissing('customObjects', value, i + 1);
		}
		if(labelLc === 'custom metadata types (mdt)')
		{
			setIfMissing('cmdtTypes', value, i + 1);
		}
		if(labelLc === 'platform events (e)')
		{
			setIfMissing('platformEvents', value, i + 1);
		}
		if(labelLc === 'custom fields (total)')
		{
			setIfMissing('customFieldsTotal', value, i + 1);
		}
	}
	return claims;
}

function validate(repoRoot, metricsFile = path.join(repoRoot, METRICS_FILE_RELATIVE))
{
	const expected = computeExpected(repoRoot);
	const content = fs.readFileSync(metricsFile, 'utf-8');
	const claims = parseDocClaims(content);

	const violations = [];
	for(const [key, expectedValue] of Object.entries(expected))
	{
		if(!claims.has(key))
		{
			continue;
		}
		const {value: claimed, line} = claims.get(key);
		if(claimed !== expectedValue)
		{
			violations.push({key, line, claimed, expected: expectedValue});
		}
	}
	return {violations, expected, claims};
}

function formatViolation(v)
{
	return `docs/Strategic Guide - Metrics.md:${v.line} [${v.key}] claimed=${v.claimed} expected=${v.expected}`;
}

module.exports = {validate, computeExpected, parseDocClaims, formatViolation};

if(require.main === module)
{
	const {violations} = validate(REPO_ROOT);
	if(violations.length === 0)
	{
		console.log('[validate-strategic-metrics] PASS (0 violations)');
		process.exit(0);
	}
	console.error(`[validate-strategic-metrics] FAIL — ${violations.length} drift(s):`);
	for(const v of violations)
	{
		console.error('  ' + formatViolation(v));
	}
	process.exit(1);
}
