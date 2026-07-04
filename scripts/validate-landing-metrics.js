#!/usr/bin/env node
// SPDX-License-Identifier: BUSL-1.1
'use strict';

/**
 * @description Source guard for the docs-site landing-page credibility strip.
 *              The strip and version badge in KernLanding.vue are data-driven:
 *              scripts/prepare.mjs reads the four figures (global API classes,
 *              production classes, LWC components, Apex test count) from each
 *              version tree's docs/Strategic Guide - Metrics.md and emits them as
 *              .vitepress/landing.generated.mjs, which the component renders. That
 *              makes hand-authored drift impossible, but it also means a renamed or
 *              removed Metrics-doc row would break the landing build. This guard
 *              fails early (before a build) if the canonical Metrics doc no longer
 *              exposes one of those four rows, and exports the shared extractor
 *              (canonicalFigures) that prepare.mjs uses so there is one
 *              implementation of "which rows the landing reads".
 *
 *              Wired into npm run docs:validate. Exits non-zero on any missing row.
 *
 * @author Kern Framework
 * @date June 2026
 */

const fs = require('node:fs');
const path = require('node:path');

const {parseDocClaims} = require('./validate-strategic-metrics');

const REPO_ROOT = path.resolve(__dirname, '..');
const METRICS_FILE = path.join(REPO_ROOT, 'docs', 'Strategic Guide - Metrics.md');

// The four landing-strip figures, each mapped to the Metrics-doc claim key it reads.
const REQUIRED_FIGURES = [
	{field: 'globalApiClasses', key: 'globalClasses', label: 'Global classes (top-level)'},
	{field: 'productionClasses', key: 'apexProduction', label: 'Apex production classes'},
	{field: 'lwcComponents', key: 'lwcDirs', label: 'LWC components (total)'},
	{field: 'apexTests', key: 'apexTestMethods', label: 'Apex test methods'}
];

/**
 * @description Reads the four landing figures from a Metrics doc. Throws if any
 * required row is absent — the same failure prepare.mjs surfaces at build time, so
 * the two stay in lockstep.
 *
 * @param {string} metricsContent
 * @return {{globalApiClasses: number, productionClasses: number, lwcComponents: number, apexTests: number}}
 */
function canonicalFigures(metricsContent)
{
	const claims = parseDocClaims(metricsContent);
	const figures = {};
	for(const {field, key, label} of REQUIRED_FIGURES)
	{
		const claim = claims.get(key);
		if(!claim)
		{
			throw new Error(`landing metrics guard: Metrics doc is missing the "${label}" row`);
		}
		figures[field] = claim.value;
	}
	return figures;
}

/**
 * @description Returns the landing figures the Metrics doc fails to expose (missing
 * row, or a non-numeric value). Empty array means the data-driven landing build has
 * every row it needs.
 *
 * @param {string} metricsContent
 * @return {Array<{field: string, label: string}>}
 */
function missingFigures(metricsContent)
{
	const claims = parseDocClaims(metricsContent);
	return REQUIRED_FIGURES
	.filter(({key}) =>
	{
		const claim = claims.get(key);
		return !claim || !Number.isFinite(claim.value);
	})
	.map(({field, label}) => ({field, label}));
}

module.exports = {canonicalFigures, missingFigures, REQUIRED_FIGURES, METRICS_FILE};

if(require.main === module)
{
	const content = fs.readFileSync(METRICS_FILE, 'utf-8');
	const missing = missingFigures(content);
	if(missing.length === 0)
	{
		const f = canonicalFigures(content);
		console.log(`[validate-landing-metrics] PASS (Metrics doc exposes all four landing figures: ${f.globalApiClasses} global, ${f.productionClasses} classes, ${f.lwcComponents} LWC, ${f.apexTests} tests)`);
		process.exit(0);
	}
	console.error(`[validate-landing-metrics] FAIL — Metrics doc is missing ${missing.length} landing figure row(s) the data-driven landing reads:`);
	for(const m of missing)
	{
		console.error(`  ${m.label} (${m.field})`);
	}
	process.exit(1);
}
