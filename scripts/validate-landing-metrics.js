#!/usr/bin/env node
// SPDX-License-Identifier: BUSL-1.1
'use strict';

/**
 * @description Source guard for the docs-site landing-page credibility strip.
 *              The strip and version badge in KernLanding.vue are data-driven:
 *              scripts/prepare.mjs reads the four figures (global API classes,
 *              production classes, LWC components, Apex test count) from each
 *              version tree's docs/Strategic Guide - Metrics.md, with the Salesforce
 *              API version the API badge and the AI definition name, and emits them as
 *              .vitepress/landing.generated.mjs, which the component renders. That
 *              makes hand-authored drift impossible, but it also means a renamed or
 *              removed Metrics-doc row would break the landing build. This guard
 *              fails early (before a build) if the canonical Metrics doc no longer
 *              exposes one of those rows, and exports the shared extractor
 *              (canonicalFigures) that prepare.mjs uses so there is one
 *              implementation of "which rows the landing reads".
 *
 *              Wired into npm run docs:validate. Exits non-zero on any missing row.
 *
 * @author Kern Framework
 * @date June 2026, October 2026
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

// The Salesforce API version the landing names in its API badge and its one-paragraph
// definition. It is read as text ("68.0"), because the number parser keeps whole numbers only.
const API_VERSION_LABEL = 'Source API version';
const API_VERSION_ROW = /^\|\s*Source API version\s*\|\s*(\d+\.\d+)\s*\|/m;

/**
 * @description Reads the Salesforce API version from the Metrics doc's
 * "Source API version" row, or returns null when the row is absent or holds no version.
 *
 * @param {string} metricsContent
 * @return {string|null} the version as written, for example "68.0"
 */
function sourceApiVersion(metricsContent)
{
	return metricsContent.match(API_VERSION_ROW)?.[1] ?? null;
}

/**
 * @description Reads the four landing figures and the API version from a Metrics doc.
 * Throws if any required row is absent: the same failure prepare.mjs surfaces at build
 * time, so the two stay in lockstep.
 *
 * @param {string} metricsContent
 * @return {{globalApiClasses: number, productionClasses: number, lwcComponents: number, apexTests: number, apiVersion: string}}
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
	const apiVersion = sourceApiVersion(metricsContent);
	if(!apiVersion)
	{
		throw new Error(`landing metrics guard: Metrics doc is missing the "${API_VERSION_LABEL}" row`);
	}
	figures.apiVersion = apiVersion;
	return figures;
}

/**
 * @description Returns the landing figures the Metrics doc fails to expose (missing
 * row, a non-numeric value, or no API version). Empty array means the data-driven landing build has
 * every row it needs.
 *
 * @param {string} metricsContent
 * @return {Array<{field: string, label: string}>}
 */
function missingFigures(metricsContent)
{
	const claims = parseDocClaims(metricsContent);
	const missing = REQUIRED_FIGURES
	.filter(({key}) =>
	{
		const claim = claims.get(key);
		return !claim || !Number.isFinite(claim.value);
	})
	.map(({field, label}) => ({field, label}));
	if(!sourceApiVersion(metricsContent))
	{
		missing.push({field: 'apiVersion', label: API_VERSION_LABEL});
	}
	return missing;
}

module.exports = {canonicalFigures, missingFigures, sourceApiVersion, REQUIRED_FIGURES, METRICS_FILE};

if(require.main === module)
{
	const content = fs.readFileSync(METRICS_FILE, 'utf-8');
	const missing = missingFigures(content);
	if(missing.length === 0)
	{
		const f = canonicalFigures(content);
		console.log(`[validate-landing-metrics] PASS (Metrics doc exposes every landing figure: ${f.globalApiClasses} global, ${f.productionClasses} classes, ${f.lwcComponents} LWC, ${f.apexTests} tests, API ${f.apiVersion})`);
		process.exit(0);
	}
	console.error(`[validate-landing-metrics] FAIL — Metrics doc is missing ${missing.length} landing figure row(s) the data-driven landing reads:`);
	for(const m of missing)
	{
		console.error(`  ${m.label} (${m.field})`);
	}
	process.exit(1);
}
