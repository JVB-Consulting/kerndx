// SPDX-License-Identifier: BUSL-1.1
const fs = require('fs');
const path = require('path');

// Which of the two results files a run belongs in is one rule, shared with the runner scripts that write the same record.
const {RESULTS_DIRECTORY, resolveResultsPath} = require('../../runner/release-target');
const {authPathsFor} = require('./auth-paths');

// Written by global-setup once it has signed in, in the run's own org folder: the namespace prefix the org gives the
// package, empty when it has none.
const RUN_TARGET_PATH = authPathsFor().runTargetPath;

class KernReporter
{
	constructor()
	{
		this.results = {};
	}

	// Nothing is read here: which file this run belongs in is only known once global-setup has signed in.
	onBegin()
	{
		this.results = {phase3: {}};
	}

	onTestEnd(test, result)
	{
		// Multi-digit part numbers matter: with a single-digit capture, "Part 10" would
		// truncate to part1 and silently misfile part10's results under part1's key.
		const specMatch = test.parent?.title?.match(/Part\s*(\d+)/i) || test.location?.file?.match(/part(\d+)/);
		if(!specMatch)
		{
			return;
		}

		const partNumber = specMatch[1];
		const partKey = `part${partNumber}`;
		if(!this.results.phase3[partKey])
		{
			this.results.phase3[partKey] = {};
		}

		const checkMatch = test.title.match(/V(\d+)/);
		if(!checkMatch)
		{
			return;
		}

		const checkKey = `V${checkMatch[1]}`;
		this.results.phase3[partKey][checkKey] = {
			result: result.status === 'passed' ? 'PASS' : 'FAIL',
			notes: result.status === 'passed' ? (test.annotations.find(a => a.type === 'notes')?.description || '') : (result.error?.message?.substring(0, 200) || 'Test failed')
		};
	}

	onEnd()
	{
		const resultsPath = this._resolveResultsPath();
		const merged = this._loadExisting(resultsPath);
		merged.phase3 = merged.phase3 || {};
		for(const [partKey, checks] of Object.entries(this.results.phase3))
		{
			merged.phase3[partKey] = {...merged.phase3[partKey], ...checks};
		}
		merged.phase3Automated = true;
		this.results = merged;
		this._save(resultsPath);
	}

	// A run counts as a release-testing run only when global-setup wrote down a namespace prefix for the org.
	// Anything else, a missing note and an unreadable one included, is a development run: the record is the
	// file that must never be written by mistake.
	_resolveResultsPath()
	{
		return resolveResultsPath(this._readNamespacePrefix());
	}

	_readNamespacePrefix()
	{
		try
		{
			return JSON.parse(fs.readFileSync(RUN_TARGET_PATH, 'utf8')).namespacePrefix;
		}
		catch
		{
			return undefined;
		}
	}

	_loadExisting(resultsPath)
	{
		try
		{
			return JSON.parse(fs.readFileSync(resultsPath, 'utf8'));
		}
		catch
		{
			return {
				packageVersion: '1.0.0-XX', testDate: new Date().toISOString().split('T')[0]
			};
		}
	}

	_save(resultsPath)
	{
		fs.mkdirSync(RESULTS_DIRECTORY, {recursive: true});
		fs.writeFileSync(resultsPath, JSON.stringify(this.results, null, 2) + '\n', 'utf8');
		// Said out loud, because a release-testing run that lands in the development file has recorded nothing for the cycle.
		console.log(`[results] journey results recorded in release-testing/results/${path.basename(resultsPath)}`);
	}
}

module.exports = KernReporter;
