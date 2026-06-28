#!/usr/bin/env node
// SPDX-License-Identifier: BUSL-1.1
'use strict';

/**
 * @description Drift guard for the docs-site landing-page credibility strip.
 *              The strip in KernLanding.vue is hand-authored Vue (not generated
 *              from the Metrics doc the way the public README badge is), so it
 *              can silently drift. This check reads the canonical figures from
 *              docs/Strategic Guide - Metrics.md and fails if the four strip
 *              numbers (global API classes, production classes, LWC components,
 *              Apex test count) no longer match.
 *
 *              Wired into npm run docs:validate. Exits non-zero on any drift.
 *
 * @author Kern Framework
 * @date June 2026
 */

const fs = require('node:fs');
const path = require('node:path');

const {parseDocClaims} = require('./validate-strategic-metrics');

const REPO_ROOT = path.resolve(__dirname, '..');
const METRICS_FILE = path.join(REPO_ROOT, 'docs', 'Strategic Guide - Metrics.md');
const LANDING_FILE = path.join(REPO_ROOT, 'docs-site', '.vitepress', 'theme', 'components', 'KernLanding.vue');

/**
 * @description Reads the canonical strip figures from the Metrics doc.
 *
 * @param {string} metricsContent
 * @return {{globalApiClasses: number, productionClasses: number, lwcComponents: number, apexTests: number}}
 */
function canonicalFigures(metricsContent)
{
	const claims = parseDocClaims(metricsContent);
	function need(key, label)
	{
		const claim = claims.get(key);
		if(!claim)
		{
			throw new Error(`landing drift guard: Metrics doc is missing the "${label}" row`);
		}
		return claim.value;
	}
	return {
		globalApiClasses: need('globalClasses', 'Global classes (top-level)'),
		productionClasses: need('apexProduction', 'Apex production classes'),
		lwcComponents: need('lwcDirs', 'LWC components (total)'),
		apexTests: need('apexTestMethods', 'Apex test methods')
	};
}

/**
 * @description Extracts the four landing-strip numbers, keyed by their
 * `data-spec-id`. Returns null for any field the strip markup no longer matches
 * (a structural change the guard should surface rather than silently pass).
 *
 * @param {string} landingContent
 * @return {{globalApiClasses: (number|null), productionClasses: (number|null), lwcComponents: (number|null), apexTests: (number|null)}}
 */
function landingFigures(landingContent)
{
	function bold(specId)
	{
		const m = landingContent.match(new RegExp(`data-spec-id="${specId}"><b>([\\d,]+)`));
		return m ? Number(m[1].replace(/,/g, '')) : null;
	}
	function testsCount()
	{
		const m = landingContent.match(/data-spec-id="strip-coverage">[\s\S]*?([\d,]+)\s*tests/);
		return m ? Number(m[1].replace(/,/g, '')) : null;
	}
	return {
		globalApiClasses: bold('strip-global'),
		productionClasses: bold('strip-classes'),
		lwcComponents: bold('strip-lwc'),
		apexTests: testsCount()
	};
}

/**
 * @description Compares the landing strip against the Metrics canonical figures.
 *
 * @param {string} metricsContent
 * @param {string} landingContent
 * @return {Array<{field: string, expected: number, found: (number|null)}>}
 */
function validate(metricsContent, landingContent)
{
	const expected = canonicalFigures(metricsContent);
	const found = landingFigures(landingContent);
	const violations = [];
	for(const field of Object.keys(expected))
	{
		if(found[field] !== expected[field])
		{
			violations.push({field, expected: expected[field], found: found[field]});
		}
	}
	return violations;
}

module.exports = {canonicalFigures, landingFigures, validate, METRICS_FILE, LANDING_FILE};

if(require.main === module)
{
	const violations = validate(fs.readFileSync(METRICS_FILE, 'utf-8'), fs.readFileSync(LANDING_FILE, 'utf-8'));
	if(violations.length === 0)
	{
		console.log('[validate-landing-metrics] PASS (landing strip matches Metrics canonical figures)');
		process.exit(0);
	}
	console.error(`[validate-landing-metrics] FAIL — ${violations.length} drift(s) vs docs/Strategic Guide - Metrics.md:`);
	for(const v of violations)
	{
		console.error(`  KernLanding.vue ${v.field}: found ${v.found}, expected ${v.expected}`);
	}
	process.exit(1);
}
