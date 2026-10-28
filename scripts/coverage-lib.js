// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Pure helper functions for the per-file coverage harness.
 *
 * Parsers and evaluators that take already-loaded inputs (parsed JSON, source
 * text) and return normalised results. No child_process, no fs reads of org
 * state, no network — those live in evaluate-coverage.js so this module stays
 * trivially unit-testable.
 *
 * @see evaluate-coverage.js
 *
 * @author Kern Framework
 * @version 1.0.0
 */

const fs = require('fs');
const path = require('path');

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

/** @description Apex per-class percentage floor. */
const APEX_FLOOR = 100.0;

/** @description Allowed values for the `--format` CLI flag. */
const SUPPORTED_FORMATS = Object.freeze([
	'text',
	'pmd-xml',
	'github-annotations'
]);

/** @description PMD ruleset attribute used in `--format pmd-xml` output. */
const PMD_RULESET_NAME = 'KernDXCoverage';

/** @description PMD rule attribute used for every violation in `--format pmd-xml`. */
const PMD_RULE_NAME = 'KernCoverageRegression';

/** @description LWC per-file statements percentage floor. */
const LWC_STATEMENTS_FLOOR = 95.0;

/** @description LWC per-file branches percentage floor. */
const LWC_BRANCHES_FLOOR = 95.0;

/** @description Minimum character length for a kern-coverage-exempt reason. */
const EXEMPT_REASON_MIN_LENGTH = 15;

/** @description Reasons that do not qualify under the exemption policy. */
const EXEMPT_REASON_BLOCKLIST = Object.freeze([
	'hard to test',
	'tricky',
	'todo',
	'fixme',
	'later',
	'xxx',
	'hack'
]);

/** @description Regex matching `// kern-coverage-exempt: <reason>` comments. */
const COVERAGE_EXEMPT_REGEX = /\/\/\s*kern-coverage-exempt\s*:\s*(.*)$/i;

/** @description Regex matching `// kern-testsetup-exempt: <reason>` comments. */
const TESTSETUP_EXEMPT_REGEX = /\/\/\s*kern-testsetup-exempt\s*:\s*(.*)$/i;

// ─────────────────────────────────────────────────────────────────────────────
// CLI-output safety
// ─────────────────────────────────────────────────────────────────────────────

/**
 * @description True if the buffer looks like JSON (first non-whitespace char
 * is `{` or `[`). Lets callers distinguish "sf wrote JSON to stdout" from
 * "sf wrote a warning banner and then JSON".
 *
 * @param {string} buffer - The raw captured output.
 * @return {boolean} True if the first non-whitespace character is `{` or `[`.
 */
function looksLikeJson(buffer)
{
	if(typeof buffer !== 'string' || buffer.length === 0)
	{
		return false;
	}
	const trimmed = buffer.replace(/^\s+/, '');
	return trimmed.startsWith('{') || trimmed.startsWith('[');
}

/**
 * @description Parses JSON, returning an object or throwing a CLI_OUTPUT_NOT_JSON
 * error that includes the first 200 characters of the offending payload.
 *
 * @param {string} buffer - Raw text to parse.
 * @param {string} source - Human-readable source (e.g. "sf apex run test stdout").
 * @return {Object} Parsed object.
 * @throws {Error} With `code = 'CLI_OUTPUT_NOT_JSON'` on a first-character failure.
 */
function safeParseJson(buffer, source)
{
	if(!looksLikeJson(buffer))
	{
		const preview = String(buffer).slice(0, 200);
		const error = new Error(`[${source}] output did not start with JSON. First 200 characters: ${preview}`);
		error.code = 'CLI_OUTPUT_NOT_JSON';
		throw error;
	}
	return JSON.parse(buffer);
}

// ─────────────────────────────────────────────────────────────────────────────
// Apex coverage parser
// ─────────────────────────────────────────────────────────────────────────────

/**
 * @description Extracts per-class coverage from the parsed `sf apex run test
 * --result-format json` payload. Handles both `"100%"` (string) and `100`
 * (number) percentage shapes that sf emits across CLI versions. Exempt-line
 * adjustment is applied afterwards via `applyApexExemptions()`.
 *
 * @param {Object} sfPayload - Parsed sf-apex result JSON.
 * @return {{classes: Object<string, Object>, wallClockSeconds: number, testsPassed: boolean, testFailures: Array<Object>}} Normalised result.
 */
function parseApexCoverage(sfPayload)
{
	if(!sfPayload || typeof sfPayload !== 'object')
	{
		throw new Error('sf apex payload is not an object');
	}
	const root = sfPayload.result && typeof sfPayload.result === 'object' ? sfPayload.result : sfPayload;

	const rawCoverage = (Array.isArray(root.codecoverage) ? root.codecoverage : null) || (root.coverage && Array.isArray(root.coverage.coverage) ? root.coverage.coverage : null)
			|| (Array.isArray(root.coverage) ? root.coverage : null) || [];

	const classes = {};
	for(const entry of rawCoverage)
	{
		const name = entry && (entry.name || entry.Name);
		if(typeof name !== 'string')
		{
			continue;
		}
		const covered = toInt(entry.numLinesCovered === undefined ? entry.totalCovered : entry.numLinesCovered);
		const totalLines = toInt(entry.totalLines === undefined ? (covered + toInt(entry.numLinesUncovered)) : entry.totalLines);
		const uncovered = Math.max(0, totalLines - covered);
		let percentage = coercePercentage(entry.percentage);
		if(!percentage)
		{
			percentage = coercePercentage(entry.coveredPercent);
		}
		if(!percentage && totalLines > 0)
		{
			percentage = Number(((covered / totalLines) * 100).toFixed(1));
		}
		classes[name] = withUncoveredLineNumbers({percentage, coveredLines: covered, uncoveredLines: uncovered}, readUncoveredLineNumbers(entry));
	}

	const summary = root.summary || {};
	const wallClockMs = toInt(summary.testTotalTime || summary.totalTime || 0);
	const wallClockSeconds = wallClockMs / 1000;

	const tests = Array.isArray(root.tests) ? root.tests : [];
	const testFailures = tests.filter(test => test && test.Outcome && test.Outcome !== 'Pass');

	return {
		classes, wallClockSeconds, testsPassed: testFailures.length === 0, testFailures
	};
}

/**
 * @description Reads the uncovered line numbers from one coverage entry of an `sf apex run test` result. The
 * `codecoverage` shape lists them in `uncoveredLines`; the `coverage.coverage` shape maps each line number to 1
 * (covered) or 0 (not covered) in `lines`.
 *
 * @param {Object} entry - One raw coverage entry.
 * @return {Array<number>|null} The line numbers, or null when the entry does not say which lines were missed.
 */
function readUncoveredLineNumbers(entry)
{
	if(Array.isArray(entry.uncoveredLines))
	{
		return entry.uncoveredLines;
	}
	if(entry.lines && typeof entry.lines === 'object')
	{
		return Object.entries(entry.lines).filter(([, hits]) => Number(hits) === 0).map(([line]) => Number(line));
	}
	return null;
}

/**
 * @description Adds the sorted, distinct uncovered line numbers to a class entry. An entry whose source did not
 * say which lines were missed gets no list at all, so no exemption can be applied to it by guesswork.
 *
 * @param {Object} entry - A class entry: `{percentage, coveredLines, uncoveredLines}`.
 * @param {Array<number>|null} lineNumbers - The uncovered line numbers, or null when they are not known.
 * @return {Object} The entry, with `uncoveredLineNumbers` when the line numbers are known.
 */
function withUncoveredLineNumbers(entry, lineNumbers)
{
	if(!Array.isArray(lineNumbers))
	{
		return entry;
	}
	const sorted = [...new Set(lineNumbers.map(Number))].sort((left, right) => left - right);
	return {...entry, uncoveredLineNumbers: sorted};
}

/**
 * @description Reapplies the exemption policy to a class's coverage. Each valid exempt comment marks one line;
 * a marked line is taken out of both the uncovered count and the total only when the run reports that exact line
 * as uncovered. A marked line a test covers takes nothing away, so it can never hide a different uncovered line.
 * A class whose coverage does not list its uncovered line numbers gets no exemption at all. The percentage
 * rises to 100% only when every line that is not exempt is covered.
 *
 * @param {Object} apexCoverage - Output of `parseApexCoverage()`.
 * @param {Object<string, Array<number|Array<number>>>} exemptLinesByClass - `{className: [marked line of each valid exempt comment]}`.
 *     An entry may be one line number, or a list of line numbers when the comment marks a `catch` line and its brace line.
 *     An entry takes away at most one uncovered line, whichever line of the list the run reports.
 * @return {Object} New coverage object with adjusted percentages and `exemptLines` counts.
 */
function applyApexExemptions(apexCoverage, exemptLinesByClass)
{
	const adjusted = {classes: {}};
	for(const [className, entry] of Object.entries(apexCoverage.classes))
	{
		const markedEntries = Array.isArray(exemptLinesByClass[className]) ? exemptLinesByClass[className] : [];
		const uncoveredLineNumbers = new Set(entry.uncoveredLineNumbers || []);
		const usedLines = new Set();
		let exemptLines = 0;
		for(const markedEntry of markedEntries)
		{
			const hitLine = [].concat(markedEntry).find(line => uncoveredLineNumbers.has(line) && !usedLines.has(line));
			if(hitLine !== undefined)
			{
				usedLines.add(hitLine);
				exemptLines += 1;
			}
		}
		const totalLines = entry.coveredLines + entry.uncoveredLines;
		const adjustedTotal = Math.max(0, totalLines - exemptLines);
		const adjustedUncovered = Math.max(0, entry.uncoveredLines - exemptLines);
		const adjustedCovered = Math.max(0, adjustedTotal - adjustedUncovered);
		const percentage = adjustedTotal === 0 ? 100 : Number(((adjustedCovered / adjustedTotal) * 100).toFixed(1));
		adjusted.classes[className] = {
			percentage, coveredLines: adjustedCovered, uncoveredLines: adjustedUncovered, exemptLines
		};
	}
	return {
		...apexCoverage, ...adjusted
	};
}

/**
 * @description Computes a class's true coverage from its raw per-test
 * `ApexCodeCoverage` rows by unioning every test method's covered lines: a line
 * is covered when *any* test covers it, and uncovered only when no test ever
 * covers it. This union is what `ApexCodeCoverageAggregate` is meant to equal,
 * but which it under-reports for heavily-shared classes after a parallel
 * `RunLocalTests` (coverage-record write contention loses rollup entries).
 *
 * @param {Array<{Coverage: {coveredLines: Array<number>, uncoveredLines: Array<number>}}>} rows
 * @return {{percentage: number, coveredLines: number, uncoveredLines: number, uncoveredLineNumbers: Array<number>}} The
 *     counts, and the lines no row covers.
 */
function unionCoverageFromRows(rows)
{
	const covered = new Set();
	const mentionedUncovered = new Set();
	for(const row of rows || [])
	{
		const coverage = (row && row.Coverage) || {};
		for(const line of coverage.coveredLines || [])
		{
			covered.add(line);
		}
		for(const line of coverage.uncoveredLines || [])
		{
			mentionedUncovered.add(line);
		}
	}
	const neverCovered = [...mentionedUncovered].filter(line => !covered.has(line)).sort((left, right) => left - right);
	const uncoveredCount = neverCovered.length;
	const coveredCount = covered.size;
	const total = coveredCount + uncoveredCount;
	const percentage = total === 0 ? 100 : Number(((coveredCount / total) * 100).toFixed(1));
	return {percentage, coveredLines: coveredCount, uncoveredLines: uncoveredCount, uncoveredLineNumbers: neverCovered};
}

/**
 * @description Corrects `ApexCodeCoverageAggregate`-derived coverage against the
 * authoritative per-test union for the named classes. Upgrade-only: a class is
 * replaced with its union figure solely when the union reports a strictly higher
 * percentage, so a genuinely-uncovered line can never be masked by stale or
 * partial per-test rows. Absorbs the parallel-run rollup artifact where the
 * aggregate under-reports classes whose per-test rows are in fact complete.
 * On a tie, the union also replaces an aggregate row that lists no uncovered
 * line numbers (an empty or missing list) and counts the same lines: the figure is the same, and the
 * union's line list lets the class's exempt comments apply.
 *
 * @param {{classes: Object<string, Object>}} aggregateCoverage - Output of `normaliseAggregateRows()`.
 * @param {Object<string, Array<Object>>} perTestRowsByClass - `{className: ApexCodeCoverage rows}`.
 * @return {{classes: Object<string, Object>}} New coverage object; classes absent from the map pass through untouched.
 */
function reconcileAggregateWithPerTestRows(aggregateCoverage, perTestRowsByClass)
{
	const classes = {...((aggregateCoverage && aggregateCoverage.classes) || {})};
	for(const [className, rows] of Object.entries(perTestRowsByClass || {}))
	{
		const union = unionCoverageFromRows(rows);
		const current = classes[className];
		const currentListsNoLines = !Array.isArray(current?.uncoveredLineNumbers) || current.uncoveredLineNumbers.length === 0;
		const countsSameLines = union.coveredLines + union.uncoveredLines === (current?.coveredLines ?? 0) + (current?.uncoveredLines ?? 0);
		const isTieThatAddsLineNumbers = union.percentage === current?.percentage && currentListsNoLines && countsSameLines;
		if(!current || union.percentage > current.percentage || isTieThatAddsLineNumbers)
		{
			classes[className] = union;
		}
	}
	return {...aggregateCoverage, classes};
}

// ─────────────────────────────────────────────────────────────────────────────
// Jest coverage parser
// ─────────────────────────────────────────────────────────────────────────────

/**
 * @description Extracts per-file coverage from Jest's `coverage-final.json`
 * (raw istanbul format). Computes statements/branches/functions/lines
 * percentages directly from the `s`/`b`/`f` hit-count maps because Jest's
 * `json-summary` reporter silently drops files in some configurations.
 *
 * @param {Object} finalJson - Parsed `coverage/coverage-final.json`.
 * @param {string} repoRoot - Absolute path to the repo root, used to rebase keys.
 * @return {{files: Object<string, Object>}} Normalised result.
 */
function parseJestCoverageFinal(finalJson, repoRoot)
{
	if(!finalJson || typeof finalJson !== 'object')
	{
		throw new Error('jest coverage final is not an object');
	}
	const files = {};
	for(const [key, value] of Object.entries(finalJson))
	{
		if(!value || typeof value !== 'object' || !value.s)
		{
			continue;
		}
		const relative = toRepoRelative(key, repoRoot);
		files[relative] = computeIstanbulPercentages(value);
	}
	return {files};
}

/**
 * @description Computes statements/branches/functions/lines percentages from
 * a raw istanbul file entry (shape: `{s, f, b, statementMap, fnMap, branchMap}`).
 *
 * @param {Object} entry - One file's istanbul coverage record.
 * @return {{statements: number, branches: number, functions: number, lines: number}}
 */
function computeIstanbulPercentages(entry)
{
	const statements = tallyHits(entry.s);
	const functions = tallyHits(entry.f);
	const branches = tallyBranchHits(entry.b);
	const lines = deriveLineCoverage(entry);
	return {
		statements: pct(statements.covered, statements.total),
		branches: pct(branches.covered, branches.total),
		functions: pct(functions.covered, functions.total),
		lines: pct(lines.covered, lines.total),
		// The raw counts, so a floor is checked on the real ratio: the rounded percentage reads 95.0 for
		// 189 of 199 statements (94.97%), which is under the 95% floor.
		counts: {statements, branches, functions, lines}
	};
}

/**
 * @description Tallies covered/total from an object of hit counts.
 *
 * @param {Object<string, number>} hits
 * @return {{covered: number, total: number}}
 */
function tallyHits(hits)
{
	const values = hits ? Object.values(hits) : [];
	return {
		covered: values.reduce((sum, value) => sum + (Number(value) > 0 ? 1 : 0), 0), total: values.length
	};
}

/**
 * @description Tallies covered/total for istanbul's branch format (each entry
 * is an array of hit counts, one per branch outcome).
 *
 * @param {Object<string, Array<number>>} branchHits
 * @return {{covered: number, total: number}}
 */
function tallyBranchHits(branchHits)
{
	const arrays = branchHits ? Object.values(branchHits) : [];
	let covered = 0;
	let total = 0;
	for(const arr of arrays)
	{
		if(!Array.isArray(arr))
		{
			continue;
		}
		for(const hit of arr)
		{
			total += 1;
			if(Number(hit) > 0)
			{
				covered += 1;
			}
		}
	}
	return {covered, total};
}

/**
 * @description Derives line coverage from the statement map. A line is
 * covered if any statement on it was hit.
 *
 * @param {Object} entry
 * @return {{covered: number, total: number}}
 */
function deriveLineCoverage(entry)
{
	const map = entry.statementMap || {};
	const hits = entry.s || {};
	const byLine = {};
	for(const [id, location] of Object.entries(map))
	{
		const line = location && location.start && location.start.line;
		if(typeof line !== 'number')
		{
			continue;
		}
		byLine[line] = byLine[line] || 0;
		if(Number(hits[id]) > 0)
		{
			byLine[line] += 1;
		}
	}
	const lines = Object.values(byLine);
	return {
		covered: lines.filter(count => count > 0).length, total: lines.length
	};
}

/**
 * @description Division with a clean 0/0 → 100% convention, rounded to 1 dp.
 *
 * @param {number} covered
 * @param {number} total
 * @return {number}
 */
function pct(covered, total)
{
	if(total === 0)
	{
		return 100;
	}
	return Number(((covered / total) * 100).toFixed(1));
}

/**
 * @description Extracts per-file coverage from Jest's `coverage-summary.json`.
 * Kept for callers that already have summary JSON — production uses
 * `parseJestCoverageFinal` instead.
 *
 * @param {Object} summary - Parsed `coverage/coverage-summary.json`.
 * @param {string} repoRoot - Absolute path to the repo root.
 * @return {{files: Object<string, Object>}} Normalised result.
 */
function parseJestCoverageSummary(summary, repoRoot)
{
	if(!summary || typeof summary !== 'object')
	{
		throw new Error('jest coverage summary is not an object');
	}
	const files = {};
	for(const [key, value] of Object.entries(summary))
	{
		if(key === 'total' || !value || typeof value !== 'object')
		{
			continue;
		}
		const relative = toRepoRelative(key, repoRoot);
		files[relative] = {
			statements: toPct(value.statements),
			branches: toPct(value.branches),
			functions: toPct(value.functions),
			lines: toPct(value.lines),
			counts: {
				statements: toCounts(value.statements), branches: toCounts(value.branches), functions: toCounts(value.functions), lines: toCounts(value.lines)
			}
		};
	}
	return {files};
}

/**
 * @description Reads the covered and total counts of a Jest coverage-summary metric (`{total, covered, pct}`).
 *
 * @param {Object} metric - The metric block.
 * @return {{covered: number, total: number}|null} The counts, or null when the block has none.
 */
function toCounts(metric)
{
	if(!metric || !Number.isFinite(Number(metric.total)) || !Number.isFinite(Number(metric.covered)))
	{
		return null;
	}
	return {covered: Number(metric.covered), total: Number(metric.total)};
}

/**
 * @description Decides whether a measurement is under a floor on its real ratio when the counts are known
 * (`covered * 100 < floor * total`, exact in integers), and on the rounded percentage otherwise. The rounded
 * figure is for display: 189 of 199 statements reads 95.0 and is under the 95% floor, and an Apex class of
 * 2,000 lines with one uncovered line reads 100.0 and is under the 100% floor.
 *
 * @param {{covered: number, total: number}|null|undefined} counts - The covered and total counts, when known.
 * @param {number} percentage - The rounded percentage.
 * @param {number} floor - The floor, in percent.
 * @return {boolean} True when the measurement is under the floor.
 */
function isBelowFloor(counts, percentage, floor)
{
	if(counts && counts.total > 0)
	{
		return counts.covered * 100 < floor * counts.total;
	}
	return percentage < floor;
}

/**
 * @description Decides whether a measurement fell below its baseline. When both sides carry counts the real
 * ratios are compared (cross-multiplied, exact in integers); otherwise the rounded percentages are, as the
 * baseline stores them.
 *
 * @param {{covered: number, total: number}|null|undefined} counts - The current counts, when known.
 * @param {number} percentage - The current rounded percentage.
 * @param {{covered: number, total: number}|null|undefined} baselineCounts - The baseline counts, when known.
 * @param {number} baselinePercentage - The baseline percentage.
 * @return {boolean} True when the measurement is below the baseline.
 */
function isBelowBaseline(counts, percentage, baselineCounts, baselinePercentage)
{
	if(counts && baselineCounts && counts.total > 0 && baselineCounts.total > 0)
	{
		return counts.covered * baselineCounts.total < baselineCounts.covered * counts.total;
	}
	return percentage < baselinePercentage;
}

// ─────────────────────────────────────────────────────────────────────────────
// Exempt-comment parser
// ─────────────────────────────────────────────────────────────────────────────

/**
 * @description Scans source text for `// kern-coverage-exempt:` comments.
 * Returns one entry per comment with the 1-indexed line number, the line it
 * marks (see `findMarkedLineNumber`), reason text, and a validation verdict
 * against the policy blocklist.
 *
 * @param {string} source - The source file contents.
 * @return {Array<{lineNumber: number, targetLineNumber: number|null, markedLineNumbers: Array<number>, reason: string, reasonValid: boolean,
 *     failures: Array<string>}>}
 */
function parseCoverageExemptComments(source)
{
	return parseExemptComments(source, COVERAGE_EXEMPT_REGEX);
}

/**
 * @description Scans source text for `// kern-testsetup-exempt:` comments with
 * the same validation.
 *
 * @param {string} source - The source file contents.
 * @return {Array<{lineNumber: number, targetLineNumber: number|null, markedLineNumbers: Array<number>, reason: string, reasonValid: boolean,
 *     failures: Array<string>}>}
 */
function parseTestSetupExemptComments(source)
{
	return parseExemptComments(source, TESTSETUP_EXEMPT_REGEX);
}

/**
 * @description Validates an exempt reason against policy — non-empty, meets
 * minimum length, does not contain a blocklisted term.
 *
 * @param {string} reason - The raw reason text (already trimmed).
 * @return {{valid: boolean, failures: Array<string>}}
 */
function validateExemptReason(reason)
{
	const failures = [];
	const trimmed = (reason || '').trim();
	if(trimmed.length === 0)
	{
		failures.push('reason_empty');
	}
	if(trimmed.length < EXEMPT_REASON_MIN_LENGTH && trimmed.length > 0)
	{
		failures.push('reason_too_short');
	}
	const lower = trimmed.toLowerCase();
	for(const blocked of EXEMPT_REASON_BLOCKLIST)
	{
		if(lower.includes(blocked))
		{
			failures.push(`reason_blocklisted:${blocked}`);
		}
	}
	return {valid: failures.length === 0, failures};
}

// ─────────────────────────────────────────────────────────────────────────────
// Threshold evaluation
// ─────────────────────────────────────────────────────────────────────────────

/**
 * @description Evaluates per-file coverage against both the absolute floor
 * (Apex 100%, LWC 95%/95%) and the per-file baseline (≥ previous percentage).
 *
 * @param {Object} args
 * @param {Object} args.apexResult - Normalised apex coverage (after exemption application).
 * @param {Object} args.lwcResult - Normalised jest coverage.
 * @param {Object} args.baseline - Committed baseline snapshot.
 * @param {Array<string>} args.apexTargets - Class names the caller explicitly asked about.
 * @param {Array<string>} args.lwcTargets - Component folder names the caller explicitly asked about.
 * @return {{pass: boolean, violations: Array<Object>, measurements: Array<Object>, notes: Array<Object>}} `notes` names every
 *     target the baseline does not hold: its regression check was skipped and only the floor applied, which the caller must say.
 */
function evaluateThresholds(args)
{
	const {apexResult, lwcResult, baseline, apexTargets, lwcTargets} = args;
	const outcome = {violations: [], measurements: [], notes: []};

	for(const className of apexTargets || [])
	{
		evaluateApexClass(className, apexResult, baseline, outcome);
	}

	const componentsWithoutData = new Set();
	for(const component of lwcTargets || [])
	{
		const matches = findLwcFilesForComponent(lwcResult, component);
		if(matches.length === 0)
		{
			componentsWithoutData.add(component);
			outcome.violations.push({kind: 'lwc_missing', target: component, detail: 'no coverage data returned for component path'});
			continue;
		}
		for(const {filePath, coverage} of matches)
		{
			evaluateLwcFile(filePath, coverage, baseline, outcome);
		}
	}

	// A baseline file the Jest report no longer holds (no test loads it any more) is not in `matches`, so the
	// loop above never looks at it; without this it passed instead of reading as 0%.
	const baselineFiles = (baseline && baseline.lwc && baseline.lwc.files) || {};
	const reportedFiles = (lwcResult && lwcResult.files) || {};
	const targetSet = new Set(lwcTargets || []);
	for(const filePath of Object.keys(baselineFiles))
	{
		const component = componentOfLwcFile(filePath);
		if(!component || !targetSet.has(component) || componentsWithoutData.has(component) || reportedFiles[filePath])
		{
			continue;
		}
		outcome.violations.push({
			kind: 'lwc_missing', target: filePath, detail: 'the baseline holds this file but the Jest report does not: no test loads it any more, so it reads as 0%'
		});
	}

	return {pass: outcome.violations.length === 0, ...outcome};
}

/**
 * @description Reads the component folder name from a repo-relative Lightning web component file path.
 *
 * @param {string} filePath - The file path, such as `force-app/main/default/lwc/bar/bar.js`.
 * @return {string|null} The component folder name, or null when the path is not under an `lwc/` folder.
 */
function componentOfLwcFile(filePath)
{
	const match = filePath.match(/\/lwc\/([^/]+)\//);
	return match ? match[1] : null;
}

/**
 * @description Evaluates one apex class against the floor and, when the
 * baseline holds it, against its baseline; a class the baseline does not hold
 * is noted instead.
 *
 * @param {string} className
 * @param {Object} apexResult - Normalised apex coverage.
 * @param {Object} baseline - Committed baseline snapshot.
 * @param {{violations: Array<Object>, measurements: Array<Object>, notes: Array<Object>}} outcome - Collects the findings.
 * @return {void}
 */
function evaluateApexClass(className, apexResult, baseline, outcome)
{
	const current = apexResult && apexResult.classes && apexResult.classes[className];
	if(!current)
	{
		outcome.violations.push({kind: 'apex_missing', target: className, detail: 'no coverage data returned'});
		return;
	}
	const priorPct = pickBaselinePercentage(baseline, 'apex', className);
	outcome.measurements.push({kind: 'apex', target: className, current: current.percentage, baseline: priorPct});
	const counts = apexLineCounts(current);
	if(isBelowFloor(counts, current.percentage, APEX_FLOOR))
	{
		outcome.violations.push({kind: 'apex_below_floor', target: className, current: current.percentage, floor: APEX_FLOOR});
	}
	if(priorPct === null)
	{
		outcome.notes.push({kind: 'apex_unbaselined', target: className});
	}
	else if(isBelowBaseline(counts, current.percentage, apexLineCounts(baseline.apex.classes[className]), priorPct))
	{
		outcome.violations.push({kind: 'apex_regression', target: className, current: current.percentage, baseline: priorPct});
	}
}

/**
 * @description Reads an Apex coverage entry's covered and total line counts, when it carries them.
 *
 * @param {Object} entry - A class entry: `{percentage, coveredLines, uncoveredLines}`.
 * @return {{covered: number, total: number}|null} The counts, or null when the entry has none.
 */
function apexLineCounts(entry)
{
	if(!Number.isFinite(Number(entry.coveredLines)) || !Number.isFinite(Number(entry.uncoveredLines)))
	{
		return null;
	}
	const covered = Number(entry.coveredLines);
	return {covered, total: covered + Number(entry.uncoveredLines)};
}

/**
 * @description Evaluates one LWC source file against both floors and, when the
 * baseline holds it, against its baseline metrics; a file the baseline does not
 * hold is noted instead.
 *
 * @param {string} filePath - Repo-relative path of the component source file.
 * @param {{statements: number, branches: number}} coverage - The file's measured coverage.
 * @param {Object} baseline - Committed baseline snapshot.
 * @param {{violations: Array<Object>, measurements: Array<Object>, notes: Array<Object>}} outcome - Collects the findings.
 * @return {void}
 */
function evaluateLwcFile(filePath, coverage, baseline, outcome)
{
	const priorStatements = pickBaselineLwcMetric(baseline, filePath, 'statements');
	const priorBranches = pickBaselineLwcMetric(baseline, filePath, 'branches');
	outcome.measurements.push({
		kind: 'lwc',
		target: filePath,
		current: {statements: coverage.statements, branches: coverage.branches},
		baseline: {statements: priorStatements, branches: priorBranches}
	});
	const counts = coverage.counts || {};
	if(isBelowFloor(counts.statements, coverage.statements, LWC_STATEMENTS_FLOOR))
	{
		outcome.violations.push({kind: 'lwc_statements_below_floor', target: filePath, current: coverage.statements, floor: LWC_STATEMENTS_FLOOR});
	}
	if(isBelowFloor(counts.branches, coverage.branches, LWC_BRANCHES_FLOOR))
	{
		outcome.violations.push({kind: 'lwc_branches_below_floor', target: filePath, current: coverage.branches, floor: LWC_BRANCHES_FLOOR});
	}
	// The baseline stores rounded percentages only, so the regression check stays on rounded figures: a raw
	// ratio against a rounded baseline would report a regression that never happened.
	if(priorStatements === null && priorBranches === null)
	{
		outcome.notes.push({kind: 'lwc_unbaselined', target: filePath});
	}
	if(priorStatements !== null && coverage.statements < priorStatements)
	{
		outcome.violations.push({kind: 'lwc_statements_regression', target: filePath, current: coverage.statements, baseline: priorStatements});
	}
	if(priorBranches !== null && coverage.branches < priorBranches)
	{
		outcome.violations.push({kind: 'lwc_branches_regression', target: filePath, current: coverage.branches, baseline: priorBranches});
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary formatting
// ─────────────────────────────────────────────────────────────────────────────

/**
 * @description Produces the single-line summary that the harness prints on
 * success and that maintainers paste into commit-message bodies.
 *
 * @param {Array<Object>} measurements - Output of `evaluateThresholds().measurements`.
 * @param {boolean} pass - Overall pass/fail verdict.
 * @return {string} One-line summary.
 */
function formatSummaryLine(measurements, pass)
{
	const prefix = pass ? 'OK' : 'FAIL';
	const apexParts = measurements
	.filter(measurement => measurement.kind === 'apex')
	.map(measurement => `${measurement.target} ${fmtPct(measurement.current)}`);
	const lwcParts = measurements
	.filter(measurement => measurement.kind === 'lwc')
	.map(measurement => `${componentLabel(measurement.target)} ${fmtPct(measurement.current.statements)}/${fmtPct(measurement.current.branches)}`);
	const segments = [];
	if(apexParts.length > 0)
	{
		segments.push(`apex: ${apexParts.join(' / ')}`);
	}
	if(lwcParts.length > 0)
	{
		segments.push(`jest: ${lwcParts.join(' ')}`);
	}
	return segments.length === 0 ? `${prefix} (no measurements)` : `${prefix} ${segments.join('; ')}`;
}

/**
 * @description Produces a human-readable multi-line failure report, one line
 * per violation, with the kind and the numbers that triggered the violation.
 *
 * @param {Array<Object>} violations - Output of `evaluateThresholds().violations`.
 * @return {string} Multi-line report or empty string if no violations.
 */
function formatViolationsReport(violations)
{
	if(!violations || violations.length === 0)
	{
		return '';
	}
	return violations.map(violation =>
	{
		switch(violation.kind)
		{
			case 'apex_below_floor':
				return `apex ${violation.target}: ${fmtPct(violation.current)} < floor ${fmtPct(violation.floor)}`;
			case 'apex_regression':
				return `apex ${violation.target}: ${fmtPct(violation.current)} < baseline ${fmtPct(violation.baseline)}`;
			case 'apex_missing':
				return `apex ${violation.target}: ${violation.detail}`;
			case 'lwc_statements_below_floor':
				return `lwc ${violation.target}: statements ${fmtPct(violation.current)} < floor ${fmtPct(violation.floor)}`;
			case 'lwc_branches_below_floor':
				return `lwc ${violation.target}: branches ${fmtPct(violation.current)} < floor ${fmtPct(violation.floor)}`;
			case 'lwc_statements_regression':
				return `lwc ${violation.target}: statements ${fmtPct(violation.current)} < baseline ${fmtPct(violation.baseline)}`;
			case 'lwc_branches_regression':
				return `lwc ${violation.target}: branches ${fmtPct(violation.current)} < baseline ${fmtPct(violation.baseline)}`;
			case 'lwc_missing':
				return `lwc ${violation.target}: ${violation.detail}`;
			default:
				return `${violation.kind} ${violation.target || ''}`.trim();
		}
	}).join('\n');
}

/**
 * @description Produces one line per note: a target the committed baseline does
 * not hold, whose regression check was therefore skipped with only the floor
 * applied. Each line names the class or component and what adds it to the
 * baseline, so a gate that passed on the floor alone never reads as a full pass.
 *
 * @param {Array<Object>} notes - Output of `evaluateThresholds().notes`.
 * @return {string} Multi-line report or empty string if no notes.
 */
function formatNotesReport(notes)
{
	if(!notes || notes.length === 0)
	{
		return '';
	}
	return notes.map(describeNote).join('\n');
}

/**
 * @description Renders one note as the sentence the text and annotation
 * emitters print. An LWC note names the file, as the violations report does,
 * so two source files of one component never read as the same line.
 *
 * @param {Object} note - One entry of `evaluateThresholds().notes`.
 * @return {string}
 */
function describeNote(note)
{
	const label = note.kind === 'lwc_unbaselined' ? `lwc ${note.target}` : `apex ${note.target}`;
	return `${label}: not in the baseline, so only the floor was checked (a --fix-baseline capture adds it)`;
}

// ─────────────────────────────────────────────────────────────────────────────
// Machine-readable emitters (PMD XML, GitHub Actions annotations)
// ─────────────────────────────────────────────────────────────────────────────

/**
 * @description Emits a PMD 7-compatible XML document from the supplied
 * violations. Each violation is rendered as a `<violation>` under a `<file>`
 * element whose `name` attribute is the repo-relative source path. Gearset,
 * Copado, AutoRABIT, and CodeScan all ingest this shape natively, so no
 * additional integration code is needed on the CI side.
 *
 * @param {Array<Object>} violations - Output of `evaluateThresholds().violations`.
 * @param {{timestamp?: string}} [options] - Optional overrides (mainly for tests).
 * @return {string} Well-formed XML document.
 */
function formatPmdXml(violations, options)
{
	const timestamp = (options && options.timestamp) || new Date().toISOString();
	const grouped = groupViolationsByFile(violations || []);
	const lines = [];
	lines.push('<?xml version="1.0" encoding="UTF-8"?>');
	lines.push(`<pmd version="7.0.0" timestamp="${xmlEscape(timestamp)}" xmlns="http://pmd.sourceforge.net/report/2.0.0">`);
	for(const entry of grouped)
	{
		lines.push(`\t<file name="${xmlEscape(entry.filePath)}">`);
		for(const violation of entry.violations)
		{
			const priority = violationPriority(violation);
			const message = xmlEscape(describeViolation(violation));
			lines.push('\t\t<violation beginline="0" endline="0" begincolumn="0" endcolumn="0" '
					+ `rule="${xmlEscape(PMD_RULE_NAME)}" ruleset="${xmlEscape(PMD_RULESET_NAME)}" `
					+ `priority="${priority}">${message}</violation>`);
		}
		lines.push('\t</file>');
	}
	lines.push('</pmd>');
	return `${lines.join('\n')}\n`;
}

/**
 * @description Emits GitHub Actions annotation lines (`::error` / `::warning`)
 * from the supplied violations. GitHub renders these as inline diagnostics on
 * the PR and in the job-summary log. Floor breaches and regressions are
 * `::error`; "missing" violations (no coverage data returned) are `::warning`
 * because they may just mean the target class is new.
 *
 * @param {Array<Object>} violations - Output of `evaluateThresholds().violations`.
 * @return {string} Newline-terminated string; empty when no violations.
 */
function formatGithubAnnotations(violations)
{
	if(!violations || violations.length === 0)
	{
		return '';
	}
	const lines = violations.map(violation =>
	{
		const severity = annotationSeverity(violation);
		const filePath = violationFilePath(violation);
		const message = escapeAnnotationMessage(describeViolation(violation));
		return `::${severity} file=${filePath},line=1::${message}`;
	});
	return `${lines.join('\n')}\n`;
}

/**
 * @description Emits one GitHub Actions `::notice` line per note, so a target
 * the baseline does not hold is visible on the run without failing it.
 *
 * @param {Array<Object>} notes - Output of `evaluateThresholds().notes`.
 * @return {string} Newline-terminated string; empty when no notes.
 */
function formatGithubNotices(notes)
{
	if(!notes || notes.length === 0)
	{
		return '';
	}
	const lines = notes.map(note => `::notice file=${violationFilePath(note)},line=1::${escapeAnnotationMessage(describeNote(note))}`);
	return `${lines.join('\n')}\n`;
}

/**
 * @description Maps a violation to a PMD priority (1 = blocker, 3 = warn,
 * 5 = info). Floor breaches and regressions are blocker-class; `*_missing`
 * violations are warnings since they often reflect new, unmeasured surface
 * rather than a real regression.
 *
 * @param {Object} violation
 * @return {number}
 */
function violationPriority(violation)
{
	const kind = violation && violation.kind;
	if(kind && kind.endsWith('_missing'))
	{
		return 3;
	}
	return 1;
}

/**
 * @description Maps a violation to the GitHub Actions annotation severity.
 *
 * @param {Object} violation
 * @return {'error'|'warning'}
 */
function annotationSeverity(violation)
{
	const kind = violation && violation.kind;
	return kind && kind.endsWith('_missing') ? 'warning' : 'error';
}

/**
 * @description Derives the repo-relative file path for a violation. LWC
 * violations already carry a file path; Apex violations use `force-app/.../
 * classes/<target>.cls`.
 *
 * @param {Object} violation
 * @return {string}
 */
function violationFilePath(violation)
{
	if(!violation || typeof violation !== 'object')
	{
		return '';
	}
	if(violation.kind && violation.kind.startsWith('lwc'))
	{
		return String(violation.target || '');
	}
	const target = violation.target || '';
	return target ? `force-app/main/default/classes/${target}.cls` : '';
}

/**
 * @description Groups violations by their emitted file path, preserving the
 * original order within each group.
 *
 * @param {Array<Object>} violations
 * @return {Array<{filePath: string, violations: Array<Object>}>}
 */
function groupViolationsByFile(violations)
{
	const order = [];
	const byFile = new Map();
	for(const violation of violations)
	{
		const filePath = violationFilePath(violation);
		if(!byFile.has(filePath))
		{
			byFile.set(filePath, []);
			order.push(filePath);
		}
		byFile.get(filePath).push(violation);
	}
	return order.map(filePath => ({filePath, violations: byFile.get(filePath)}));
}

/**
 * @description Builds the short human message describing one violation. Used
 * as the body of both PMD `<violation>` and GitHub annotation lines.
 *
 * @param {Object} violation
 * @return {string}
 */
function describeViolation(violation)
{
	if(!violation || typeof violation !== 'object')
	{
		return '';
	}
	switch(violation.kind)
	{
		case 'apex_below_floor':
			return `apex ${violation.target}: ${fmtPct(violation.current)} < floor ${fmtPct(violation.floor)}`;
		case 'apex_regression':
			return `apex ${violation.target}: ${fmtPct(violation.current)} < baseline ${fmtPct(violation.baseline)}`;
		case 'apex_missing':
			return `apex ${violation.target}: ${violation.detail || 'no coverage data returned'}`;
		case 'lwc_statements_below_floor':
			return `lwc ${violation.target}: statements ${fmtPct(violation.current)} < floor ${fmtPct(violation.floor)}`;
		case 'lwc_branches_below_floor':
			return `lwc ${violation.target}: branches ${fmtPct(violation.current)} < floor ${fmtPct(violation.floor)}`;
		case 'lwc_statements_regression':
			return `lwc ${violation.target}: statements ${fmtPct(violation.current)} < baseline ${fmtPct(violation.baseline)}`;
		case 'lwc_branches_regression':
			return `lwc ${violation.target}: branches ${fmtPct(violation.current)} < baseline ${fmtPct(violation.baseline)}`;
		case 'lwc_missing':
			return `lwc ${violation.target}: ${violation.detail || 'no coverage data returned'}`;
		default:
			return `${violation.kind || 'violation'} ${violation.target || ''}`.trim();
	}
}

/**
 * @description Escapes the five XML predefined entities so arbitrary violation
 * text can be safely embedded inside attribute or element content.
 *
 * @param {string} value
 * @return {string}
 */
function xmlEscape(value)
{
	return String(value == null ? '' : value)
	.replace(/&/g, '&amp;')
	.replace(/</g, '&lt;')
	.replace(/>/g, '&gt;')
	.replace(/"/g, '&quot;')
	.replace(/'/g, '&apos;');
}

/**
 * @description Escapes a GitHub Actions annotation message. GitHub encodes
 * `%`, `\r`, and `\n` in the message payload; doing so ourselves keeps the
 * output deterministic regardless of runner version.
 *
 * @param {string} value
 * @return {string}
 */
function escapeAnnotationMessage(value)
{
	return String(value == null ? '' : value)
	.replace(/%/g, '%25')
	.replace(/\r/g, '%0D')
	.replace(/\n/g, '%0A');
}

// ─────────────────────────────────────────────────────────────────────────────
// Baseline I/O
// ─────────────────────────────────────────────────────────────────────────────

/**
 * @description Reads and parses the committed baseline JSON. Returns an empty
 * baseline shape if the file does not yet exist (first `--fix-baseline` run).
 *
 * @param {string} baselinePath - Absolute path to the baseline file.
 * @return {Object} Parsed baseline.
 */
function readBaseline(baselinePath)
{
	if(!fs.existsSync(baselinePath))
	{
		return {
			capturedAt: null, apex: {totalWallClockSeconds: 0, testSetupClasses: [], classes: {}}, lwc: {totalRuntimeSeconds: 0, files: {}}
		};
	}
	const contents = fs.readFileSync(baselinePath, 'utf8');
	return JSON.parse(contents);
}

/**
 * @description Writes a baseline snapshot as formatted JSON with a stable
 * key order and a trailing newline.
 *
 * @param {string} baselinePath - Absolute path to the baseline file.
 * @param {Object} baseline - Baseline data to write.
 * @return {void}
 */
function writeBaseline(baselinePath, baseline)
{
	const serialised = JSON.stringify(baseline, null, 2) + '\n';
	fs.writeFileSync(baselinePath, serialised, 'utf8');
}

/**
 * @description Produces a fresh baseline snapshot from a full apex + jest run.
 *
 * @param {Object} args
 * @param {Object} args.apexResult - Output of `parseApexCoverage` (post-exemption).
 * @param {Object} args.lwcResult - Output of `parseJestCoverageSummary`.
 * @param {Array<string>} args.testSetupClasses - `_TEST` class names that declare `@TestSetup`.
 * @param {number} args.lwcRuntimeSeconds - Total jest wall-clock.
 * @return {Object}
 */
function buildBaseline(args)
{
	const {apexResult, lwcResult, testSetupClasses, lwcRuntimeSeconds} = args;
	const apexClasses = {};
	for(const [name, entry] of Object.entries(apexResult.classes))
	{
		apexClasses[name] = {
			percentage: entry.percentage, coveredLines: entry.coveredLines, uncoveredLines: entry.uncoveredLines, exemptLines: toInt(entry.exemptLines || 0)
		};
	}
	const lwcFiles = {};
	for(const [filePath, entry] of Object.entries(lwcResult.files))
	{
		lwcFiles[filePath] = {
			statements: entry.statements, branches: entry.branches, functions: entry.functions, lines: entry.lines
		};
	}
	return {
		capturedAt: new Date().toISOString(), apex: {
			totalWallClockSeconds: Number(apexResult.wallClockSeconds || 0),
			testSetupClasses: Array.isArray(testSetupClasses) ? [...testSetupClasses].sort() : [],
			classes: sortKeys(apexClasses)
		}, lwc: {
			totalRuntimeSeconds: Number(lwcRuntimeSeconds || 0), files: sortKeys(lwcFiles)
		}
	};
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal helpers
// ─────────────────────────────────────────────────────────────────────────────

/**
 * @description Coerces a percentage value (number, `"100%"`, `"93.3%"`, or
 * arbitrary string) to a finite Number. Returns 0 on parse failure.
 *
 * @param {string|number} value - The raw percentage.
 * @return {number}
 */
function coercePercentage(value)
{
	if(typeof value === 'number' && Number.isFinite(value))
	{
		return Number(value.toFixed(1));
	}
	if(typeof value === 'string')
	{
		const match = value.match(/-?\d+(?:\.\d+)?/);
		if(match)
		{
			return Number(Number(match[0]).toFixed(1));
		}
	}
	return 0;
}

/**
 * @description Coerces a value to a non-negative integer; returns 0 on NaN.
 *
 * @param {string|number} value - The raw value.
 * @return {number}
 */
function toInt(value)
{
	const parsed = Number(value);
	return Number.isFinite(parsed) ? Math.max(0, Math.trunc(parsed)) : 0;
}

/**
 * @description Extracts the percentage from a Jest coverage-summary metric
 * object (shape: `{total, covered, skipped, pct}`).
 *
 * @param {Object} metric - The metric object.
 * @return {number}
 */
function toPct(metric)
{
	if(!metric || typeof metric !== 'object')
	{
		return 0;
	}
	const value = Number(metric.pct);
	return Number.isFinite(value) ? Number(value.toFixed(1)) : 0;
}

/**
 * @description Formats a percentage for display as `NN.N%`.
 *
 * @param {number} value - The percentage.
 * @return {string}
 */
function fmtPct(value)
{
	if(value === null || value === undefined)
	{
		return 'n/a';
	}
	return `${Number(value).toFixed(1)}%`;
}

/**
 * @description Rebases an absolute path to a repo-relative POSIX path. Returns
 * the original key if it's already relative or cannot be rebased.
 *
 * @param {string} absOrRelative - Absolute or relative path.
 * @param {string} repoRoot - The repo root (absolute path).
 * @return {string}
 */
function toRepoRelative(absOrRelative, repoRoot)
{
	if(!absOrRelative)
	{
		return absOrRelative;
	}
	if(path.isAbsolute(absOrRelative) && repoRoot)
	{
		const relative = path.relative(repoRoot, absOrRelative);
		return relative.split(path.sep).join('/');
	}
	return absOrRelative.split(path.sep).join('/');
}

/**
 * @description Finds Jest coverage entries whose file path is under the given
 * LWC component folder.
 *
 * @param {Object} lwcResult - Output of `parseJestCoverageSummary`.
 * @param {string} component - Component folder name (e.g. `healthCheck`).
 * @return {Array<{filePath: string, coverage: Object}>}
 */
function findLwcFilesForComponent(lwcResult, component)
{
	if(!lwcResult || !lwcResult.files)
	{
		return [];
	}
	const needle = `/lwc/${component}/`;
	const matches = [];
	for(const [filePath, coverage] of Object.entries(lwcResult.files))
	{
		if(filePath.includes(needle))
		{
			matches.push({filePath, coverage});
		}
	}
	return matches;
}

/**
 * @description Extracts a class's baseline percentage, returning `null` if the
 * class is not in the baseline (e.g. first-ever measurement).
 *
 * @param {Object} baseline
 * @param {string} section - `"apex"` or `"lwc"`.
 * @param {string} key - Class name or file path.
 * @return {number|null}
 */
function pickBaselinePercentage(baseline, section, key)
{
	const container = baseline && baseline[section];
	const entries = container && (container.classes || container.files);
	if(!entries || !entries[key])
	{
		return null;
	}
	return Number(entries[key].percentage);
}

/**
 * @description Extracts an LWC-file baseline metric (statements/branches).
 *
 * @param {Object} baseline
 * @param {string} filePath
 * @param {string} metric
 * @return {number|null}
 */
function pickBaselineLwcMetric(baseline, filePath, metric)
{
	const files = baseline && baseline.lwc && baseline.lwc.files;
	if(!files || !files[filePath])
	{
		return null;
	}
	const value = files[filePath][metric];
	return value === undefined ? null : Number(value);
}

/**
 * @description Derives a short component label from a file path for the
 * summary line (e.g. `force-app/.../lwc/healthCheck/healthCheck.js` →
 * `healthCheck`).
 *
 * @param {string} filePath
 * @return {string}
 */
function componentLabel(filePath)
{
	const match = filePath.match(/\/lwc\/([^/]+)\//);
	return match ? match[1] : filePath;
}

/**
 * @description Core exempt-comment scanner used by both coverage and testsetup
 * variants.
 *
 * @param {string} source - Source text.
 * @param {RegExp} pattern - The line-level regex to match.
 * @return {Array<{lineNumber: number, targetLineNumber: number|null, markedLineNumbers: Array<number>, reason: string,
 *     reasonValid: boolean, failures: Array<string>}>}
 */
function parseExemptComments(source, pattern)
{
	if(typeof source !== 'string' || source.length === 0)
	{
		return [];
	}
	const results = [];
	const lines = source.split(/\r?\n/);
	for(let index = 0; index < lines.length; index += 1)
	{
		const match = lines[index].match(pattern);
		if(!match)
		{
			continue;
		}
		const reason = (match[1] || '').trim();
		const {valid, failures} = validateExemptReason(reason);
		results.push({
			lineNumber: index + 1, targetLineNumber: findMarkedLineNumber(lines, index), markedLineNumbers: findMarkedLineNumbers(lines, index),
			reason, reasonValid: valid, failures
		});
	}
	return results;
}

/**
 * @description Finds the code line an exempt comment marks. When code comes before the comment on the same line,
 * that line is marked. Otherwise the comment sits above the line it marks, as the exemption policy asks: the mark
 * is the first line below it that is neither blank nor a comment, so a reason that carries on over more comment
 * lines still marks the code under it.
 *
 * @param {Array<string>} lines - The source split into lines.
 * @param {number} commentIndex - The 0-based index of the line holding the comment.
 * @return {number|null} The 1-based number of the marked line, or null when only blank or comment lines follow.
 */
function findMarkedLineNumber(lines, commentIndex)
{
	const codeBeforeComment = lines[commentIndex].slice(0, lines[commentIndex].indexOf('//')).trim();
	if(codeBeforeComment.length > 0)
	{
		return commentIndex + 1;
	}
	for(let index = commentIndex + 1; index < lines.length; index += 1)
	{
		const text = lines[index].trim();
		if(text.length > 0 && !/^(\/\/|\/\*|\*)/.test(text))
		{
			return index + 1;
		}
	}
	return null;
}

/**
 * @description Lists the lines an exempt comment stands for. This is the marked line, plus the line right after it when
 * that line holds only an opening brace. Salesforce reports the brace line, not the `catch(...)` line, as the line of a
 * `catch` block. No other line is added, and a comment still takes away at most one uncovered line.
 *
 * @param {Array<string>} lines - The source split into lines.
 * @param {number} commentIndex - The 0-based index of the line holding the comment.
 * @return {Array<number>} The 1-based line numbers, or an empty list when the comment marks no line.
 */
function findMarkedLineNumbers(lines, commentIndex)
{
	const markedLine = findMarkedLineNumber(lines, commentIndex);
	if(markedLine === null)
	{
		return [];
	}
	const nextText = markedLine < lines.length ? lines[markedLine].trim() : '';
	return nextText === '{' ? [markedLine, markedLine + 1] : [markedLine];
}

/**
 * @description Returns a new object with keys in ascending alphabetical order.
 *
 * @param {Object} obj - Input object.
 * @return {Object}
 */
function sortKeys(obj)
{
	const sorted = {};
	for(const key of Object.keys(obj).sort())
	{
		sorted[key] = obj[key];
	}
	return sorted;
}

// ─────────────────────────────────────────────────────────────────────────────
// Exports
// ─────────────────────────────────────────────────────────────────────────────

module.exports = {
	APEX_FLOOR,
	LWC_STATEMENTS_FLOOR,
	LWC_BRANCHES_FLOOR,
	EXEMPT_REASON_MIN_LENGTH,
	EXEMPT_REASON_BLOCKLIST,
	SUPPORTED_FORMATS,
	PMD_RULESET_NAME,
	PMD_RULE_NAME,
	looksLikeJson,
	safeParseJson,
	parseApexCoverage,
	applyApexExemptions,
	withUncoveredLineNumbers,
	unionCoverageFromRows,
	reconcileAggregateWithPerTestRows,
	parseJestCoverageFinal,
	parseJestCoverageSummary,
	parseCoverageExemptComments,
	parseTestSetupExemptComments,
	validateExemptReason,
	evaluateThresholds,
	isBelowFloor,
	isBelowBaseline,
	formatSummaryLine,
	formatViolationsReport,
	formatNotesReport,
	describeNote,
	formatPmdXml,
	formatGithubAnnotations,
	formatGithubNotices,
	describeViolation,
	violationFilePath,
	violationPriority,
	annotationSeverity,
	xmlEscape,
	escapeAnnotationMessage,
	readBaseline,
	writeBaseline,
	buildBaseline,
	coercePercentage,
	toInt,
	toPct,
	fmtPct,
	toRepoRelative,
	findLwcFilesForComponent,
	componentLabel,
	sortKeys
};
