// SPDX-License-Identifier: BUSL-1.1
const fs = require('fs');
const path = require('path');

const RESULTS_PATH = path.join(__dirname, '..', '..', 'results', 'current-run.json');

class KernReporter
{
	constructor()
	{
		this.results = {};
	}

	onBegin(config, suite)
	{
		this.results = this._loadExisting();
		if(!this.results.phase3)
		{
			this.results.phase3 = {};
		}
	}

	onTestEnd(test, result)
	{
		const specMatch = test.parent?.title?.match(/Part\s*(\d)/i) || test.location?.file?.match(/part(\d)/);
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

	onEnd(result)
	{
		this.results.phase3Automated = true;
		this._save();
	}

	_loadExisting()
	{
		try
		{
			return JSON.parse(fs.readFileSync(RESULTS_PATH, 'utf8'));
		}
		catch
		{
			return {
				packageVersion: '1.0.0-XX', testDate: new Date().toISOString().split('T')[0]
			};
		}
	}

	_save()
	{
		fs.mkdirSync(path.dirname(RESULTS_PATH), {recursive: true});
		fs.writeFileSync(RESULTS_PATH, JSON.stringify(this.results, null, 2) + '\n', 'utf8');
	}
}

module.exports = KernReporter;
