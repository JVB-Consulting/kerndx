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

const REPO_ROOT = path.resolve(__dirname, '..');
const METRICS_FILE = path.join(REPO_ROOT, 'docs', 'Strategic Guide - Metrics.md');

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
			if(trimmed.includes('(') || trimmed.includes('class '))
			{
				continue;
			}
			count++;
		}
	}
	return count;
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

	return {
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
		e2eSpecFiles
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
	for(let i = 0; i < lines.length; i++)
	{
		const line = lines[i];
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
		if(labelLc === 'lwc components (total)')
		{
			setIfMissing('lwcDirs', value, i + 1);
		}
		if(labelLc === 'jest test files')
		{
			setIfMissing('lwcTestFiles', value, i + 1);
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
	}
	return claims;
}

function validate(repoRoot)
{
	const expected = computeExpected(repoRoot);
	const content = fs.readFileSync(METRICS_FILE, 'utf-8');
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
