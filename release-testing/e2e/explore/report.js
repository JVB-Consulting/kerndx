// SPDX-License-Identifier: Apache-2.0
// Part 6 of the exploration: the findings ledger. It numbers the findings, counts a repeat instead of
// recording it again, takes the screenshots, and writes the findings table.
'use strict';

const fs = require('fs');
const path = require('path');
const {REPOSITORY_ROOT} = require('./constants');
const {consoleEntry, describePins} = require('./model');
const {addressKeys, formatKeys} = require('./checks');

function sanitise(value)
{
	return String(value === undefined || value === null ? '' : value).replace(/\|/g, '/').replace(/\s+/g, ' ').trim();
}

/**
 * @description The run's findings, kept in one place the context carries instead of in module state:
 *              the numbered findings, the seed they belong to, the screenshot budget and the file the
 *              table is written to.
 */
class FindingsLedger
{
	/**
	 * @description Opens an empty ledger for one run.
	 * @param {Object} options The seed, the screenshot directory, the findings path and the screenshot cap.
	 */
	constructor({seed, screenshotDirectory, findingsPath, maximumScreenshots})
	{
		this.seed = seed;
		this.screenshotDirectory = screenshotDirectory;
		this.findingsPath = findingsPath;
		this.maximumScreenshots = maximumScreenshots;
		this.findings = [];
		this.findingsByKey = new Map();
		this.screenshotCount = 0;
	}

	/**
	 * @description Records one finding with everything needed to read it later: where in the walk it
	 *              happened, what the model expected, what the screen showed, the address and a
	 *              screenshot. A finding seen before is counted rather than repeated, so one systemic
	 *              disagreement cannot bury the rest. The page is optional: the seed's own totals are
	 *              checked before the browser starts and the teardown is proved after it closes, and both
	 *              of those have to be able to report.
	 * @param {Object} context The run context, or anything carrying a `page` (or none).
	 * @param {Object} finding The finding: session, step, move, check, expected, observed, pins.
	 */
	async report(context, finding)
	{
		const key = `${finding.check}|${finding.move}|${sanitise(finding.expected)}|${sanitise(finding.observed)}`;
		const seen = this.findingsByKey.get(key);
		if(seen)
		{
			seen.repeats++;
			return;
		}
		const page = context && context.page ? context.page : null;
		let screenshot = '';
		if(page && this.screenshotCount < this.maximumScreenshots)
		{
			screenshot = path.join(this.screenshotDirectory, `${finding.session}-${finding.step}-${finding.check}.png`);
			await page.screenshot({path: screenshot}).catch(() =>
			{
				screenshot = '';
			});
			this.screenshotCount++;
		}
		let address = 'no page open';
		try
		{
			address = page ? formatKeys(addressKeys(page)) : address;
		}
		catch
		{
			address = 'the address could not be read';
		}
		const record = {
			index: this.findings.length + 1,
			seed: this.seed,
			session: finding.session,
			step: finding.step,
			move: finding.move,
			check: finding.check,
			model: describePins(finding.pins || consoleEntry()),
			expected: sanitise(finding.expected),
			observed: sanitise(finding.observed),
			address,
			screenshot: screenshot ? path.relative(REPOSITORY_ROOT, screenshot) : '',
			informational: Boolean(finding.informational),
			repeats: 0
		};
		this.findings.push(record);
		this.findingsByKey.set(key, record);
	}

	/**
	 * @description How many findings count against the run: the ones not recorded as observations only.
	 * @returns {number} The reportable count.
	 */
	reportableCount()
	{
		return this.findings.filter((finding) => !finding.informational).length;
	}

	/**
	 * @description Writes the findings table with the run's summary line above it.
	 * @param {string} runSummary The one-line summary of what the run walked.
	 */
	write(runSummary)
	{
		const lines = [];
		lines.push('# The console exploration\'s findings');
		lines.push('');
		lines.push(runSummary);
		lines.push('');
		lines.push('| # | Seed | Session | Step | Move | Check | Model | Expected | On screen | Address | Repeats | Screenshot |');
		lines.push('|---|---|---|---|---|---|---|---|---|---|---|---|');
		for(const finding of this.findings)
		{
			lines.push(`| ${finding.index} | ${finding.seed} | ${finding.session} | ${finding.step} | ${sanitise(finding.move)} | ${finding.check} `
					+ `| ${sanitise(finding.model)} | ${finding.expected} | ${finding.observed} | ${sanitise(finding.address)} | ${finding.repeats} `
					+ `| ${finding.screenshot} |`);
		}
		lines.push('');
		const reportable = this.reportableCount();
		lines.push(`Findings: ${reportable} (plus ${this.findings.length - reportable} recorded as observations only).`);
		lines.push('');
		fs.writeFileSync(this.findingsPath, lines.join('\n'), 'utf8');
	}
}

/**
 * @description Opens the ledger for one run.
 * @param {Object} options The seed, the screenshot directory, the findings path and the screenshot cap.
 * @returns {FindingsLedger} The ledger: `findings`, `report(context, finding)`, `write(summary)`, `reportableCount()`.
 */
function createFindingsLedger(options)
{
	return new FindingsLedger(options);
}

/**
 * @description Where a run writes, all under one folder: the findings table, the timings and the screenshots.
 * @param {string} directory The run's output folder.
 * @returns {Object} The folder, the screenshot folder, the findings path and the timings path.
 */
function outputPaths(directory)
{
	return {
		directory,
		screenshotDirectory: path.join(directory, 'screenshots'),
		findingsPath: path.join(directory, 'exploration-findings.md'),
		timingsPath: path.join(directory, 'timings.json')
	};
}

module.exports = {sanitise, createFindingsLedger, FindingsLedger, outputPaths};
