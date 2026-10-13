// SPDX-License-Identifier: BUSL-1.1
const fs = require('fs');
const path = require('path');

const RESULTS_DIR = path.join(__dirname, '..', 'results');
const CURRENT_RUN_PATH = path.join(RESULTS_DIR, 'current-run.json');
// The length of the "part" the phase 3 keys start with: what follows it is the part number.
const PART_KEY_PREFIX_LENGTH = 4;
const PART_NAMES = {
	1: 'App Home & Core Pages',
	2: 'API Results, Config & Login',
	3: 'Subscriber LWC & Account Integration',
	4: 'Scheduler Execution',
	5: 'Streaming — Setup & Subscribe',
	6: 'Streaming — Advanced & Cleanup',
	7: 'Async Chain Orchestration',
	8: 'Chain Monitor UI'
};

/**
 * @description Orders the rows of a table by the number their key ends with, so section-2 comes before
 * section-10 and V5 before V40.
 * @param {object} rows the rows, keyed by name
 * @param {string} prefix the part of the key ahead of the number
 * @return {Array[]} the [key, value] pairs, in number order
 */
function entriesByNumber(rows, prefix)
{
	return Object.entries(rows).sort((a, b) => parseInt(a[0].replace(prefix, ''), 10) - parseInt(b[0].replace(prefix, ''), 10));
}

/**
 * @description Whether every row of a table passed.
 * @param {object} rows the rows, keyed by name
 * @return {boolean} true when no row carries anything but PASS
 */
function everyResultPasses(rows)
{
	return Object.values(rows).every((row) => row.result === 'PASS');
}

/**
 * @description The title block: the version, the date of the run, the package version it tested and the
 * platform version it ran on.
 * @param {string} version the package version the run tested
 * @param {object} data the recorded run
 * @return {string} the markdown
 */
function renderHeader(version, data)
{
	let markdown = `# KernDX Release Test Results — ${version}\n\n`;
	markdown += `**Test Date:** ${data.testDate || new Date().toISOString().split('T')[0]}\n`;
	markdown += `**Package Version ID:** ${data.subscriberPackageVersionId || 'N/A'}\n`;
	if(data.apiVersion)
	{
		markdown += `**Platform / API Version:** ${data.apiVersion}\n`;
	}
	return markdown + '\n';
}

/**
 * @description The table of the Apex script sections, one row each.
 * @param {object} data the recorded run
 * @return {string} the markdown
 */
function renderApexScripts(data)
{
	let markdown = '## Phase 2 — Automated Tests\n\n';
	markdown += '### Apex Scripts\n\n';
	markdown += '| Section | Result | Score | Notes |\n';
	markdown += '|---------|--------|-------|-------|\n';
	if(data.phase2?.scripts)
	{
		for(const [key, row] of entriesByNumber(data.phase2.scripts, 'section-'))
		{
			markdown += `| ${key} | ${row.result} | ${row.score || ''} | ${row.notes || ''} |\n`;
		}
	}
	return markdown;
}

/**
 * @description What the Apex test classes did: the outcome, the counts and the coverage.
 * @param {object} data the recorded run
 * @return {string} the markdown
 */
function renderTestClasses(data)
{
	let markdown = '\n### Test Classes\n\n';
	if(data.phase2?.testClasses)
	{
		const testClasses = data.phase2.testClasses;
		markdown += `- **Result:** ${testClasses.result}\n`;
		markdown += `- **Passed:** ${testClasses.passed}\n`;
		markdown += `- **Failed:** ${testClasses.failed}\n`;
		markdown += `- **Coverage:** ${testClasses.coverage}\n`;
	}
	return markdown;
}

/**
 * @description What the code scanners found.
 * @param {object} data the recorded run
 * @return {string} the markdown
 */
function renderScanner(data)
{
	let markdown = '\n### Scanner\n\n';
	if(data.phase2?.scanner)
	{
		markdown += `- **PMD Violations:** ${data.phase2.scanner.violations}\n`;
	}
	if(data.phase2?.eslint)
	{
		markdown += `- **ESLint Fixture Violations:** ${data.phase2.eslint.fixtureViolations}\n`;
		markdown += `- **ESLint Framework Violations:** ${data.phase2.eslint.frameworkViolations}\n`;
	}
	return markdown;
}

/**
 * @description One section of the visual tests: its heading and the table of its checks.
 * @param {string} heading the section's heading text
 * @param {object} rows the section's checks, keyed by check name
 * @return {string} the markdown
 */
function renderVisualSection(heading, rows)
{
	let markdown = `### ${heading}\n\n`;
	markdown += '| # | Check | Result | Notes |\n';
	markdown += '|---|-------|--------|-------|\n';
	for(const [check, row] of entriesByNumber(rows, 'V'))
	{
		markdown += `| ${check} | ${row.result} | ${row.notes || ''} |\n`;
	}
	return markdown + '\n';
}

/**
 * @description One part of the visual tests: its heading and the table of its checks.
 * @param {number} number the part's number
 * @param {object} partData the part's checks, keyed by check name
 * @return {string} the markdown
 */
function renderVisualPart(number, partData)
{
	return renderVisualSection(`Part ${number}: ${PART_NAMES[number] || 'Additional Checks'}`, partData);
}

/**
 * @description Every part of the visual tests, in part order, then every other section the run recorded under
 * phase 3, by name, so nothing the verdict judges goes unseen; a section the run left blank is skipped.
 * @param {object} data the recorded run
 * @return {string} the markdown
 */
function renderVisualTests(data)
{
	let markdown = '\n## Phase 3 — Visual Tests\n\n';
	const keys = Object.keys(data.phase3 || {});
	const partKeys = keys.filter(isPartKey).sort((a, b) => partNumber(a) - partNumber(b));
	const otherKeys = keys.filter((key) => !isPartKey(key)).sort();
	for(const key of [...partKeys, ...otherKeys])
	{
		if(data.phase3[key])
		{
			markdown += isPartKey(key) ? renderVisualPart(partNumber(key), data.phase3[key]) : renderVisualSection(key, data.phase3[key]);
		}
	}
	return markdown;
}

/**
 * @description Whether a phase 3 key names a numbered part.
 * @param {string} key the key
 * @return {boolean} true for `part<N>`
 */
function isPartKey(key)
{
	return /^part\d+$/.test(key);
}

/**
 * @description The number a part key carries.
 * @param {string} key a `part<N>` key
 * @return {number} N
 */
function partNumber(key)
{
	return parseInt(key.slice(PART_KEY_PREFIX_LENGTH), 10);
}

/**
 * @description The extended load section, present only when the run carried one.
 * @param {object} data the recorded run
 * @return {string} the markdown, empty when the run ran no extended load
 */
function renderExtendedLoad(data)
{
	if(!data.extendedLoad)
	{
		return '';
	}
	let markdown = '## Extended Load\n\n';
	markdown += `- **Status:** ${data.extendedLoad.status}\n`;
	if(data.extendedLoad.notes)
	{
		markdown += `- **Notes:** ${data.extendedLoad.notes}\n`;
	}
	return markdown + '\n';
}

/**
 * @description The verdict: ALL PASS only when every automated section, the test classes and every visual
 * check passed.
 * @param {object} data the recorded run
 * @return {string} the markdown
 */
function renderVerdict(data)
{
	let markdown = '## Verdict\n\n';
	const allAutomatedTestsPass = data.phase2?.scripts && everyResultPasses(data.phase2.scripts) && data.phase2?.testClasses?.result === 'PASS';
	const allVisualTestsPass = data.phase3 && Object.values(data.phase3).every((part) => Boolean(part) && typeof part === 'object' && everyResultPasses(part));
	const overall = allAutomatedTestsPass && allVisualTestsPass ? 'ALL PASS' : 'FAIL';
	markdown += `**Overall:** ${overall}\n`;
	if(data.phase3Automated)
	{
		markdown += '\n*Phase 3 visual tests were executed via Playwright automation.*\n';
	}
	return markdown;
}

/**
 * @description Turns the recorded run into the release's results page and writes it beside the recorded run.
 * @param {string} version the package version the run tested
 * @return {string} the path of the page it wrote
 */
function compile(version)
{
	if(!fs.existsSync(CURRENT_RUN_PATH))
	{
		console.error('No current-run.json found. Run Phase 2 and 3 first.');
		process.exit(1);
	}

	const data = JSON.parse(fs.readFileSync(CURRENT_RUN_PATH, {encoding: 'utf8'}));
	const outputPath = path.join(RESULTS_DIR, `${version}.md`);
	const markdown = [
		renderHeader(version, data),
		renderApexScripts(data),
		renderTestClasses(data),
		renderScanner(data),
		renderVisualTests(data),
		renderExtendedLoad(data),
		renderVerdict(data)
	].join('');

	fs.writeFileSync(outputPath, markdown, 'utf8');
	console.log(`Results compiled to ${outputPath}`);
	return outputPath;
}

if(require.main === module)
{
	const version = process.argv[2];
	if(!version)
	{
		console.error('Usage: node result-compiler.js <version>');
		console.error('Example: node result-compiler.js 1.0.0-53');
		process.exit(1);
	}
	compile(version);
}

module.exports = {compile};
