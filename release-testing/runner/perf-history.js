#!/usr/bin/env node
// SPDX-License-Identifier: BUSL-1.1

const fs = require('fs');
const path = require('path');

const HISTORY_PATH = path.resolve(__dirname, '../results/perf-history.json');
const MAX_HISTORY = 5;
const WARN_RATIO = 1.3;
const LOUD_RATIO = 1.5;

function parseArgs()
{
	const args = process.argv.slice(2);
	const out = {section: null, logfile: null, report: false, reset: false};
	for(let i = 0; i < args.length; i++)
	{
		if(args[i] === '--section' && args[i + 1])
		{
			out.section = parseInt(args[++i], 10);
		}
		else if(args[i].startsWith('--section='))
		{
			out.section = parseInt(args[i].split('=')[1], 10);
		}
		else if(args[i] === '--logfile' && args[i + 1])
		{
			out.logfile = args[++i];
		}
		else if(args[i].startsWith('--logfile='))
		{
			out.logfile = args[i].split('=')[1];
		}
		else if(args[i] === '--report')
		{
			out.report = true;
		}
		else if(args[i] === '--reset')
		{
			out.reset = true;
		}
	}
	return out;
}

function loadHistory()
{
	if(!fs.existsSync(HISTORY_PATH))
	{
		return {};
	}
	return JSON.parse(fs.readFileSync(HISTORY_PATH, 'utf8'));
}

function saveHistory(history)
{
	fs.writeFileSync(HISTORY_PATH, JSON.stringify(history, null, 2));
}

function median(values)
{
	const sorted = [...values].sort((a, b) => a - b);
	const mid = Math.floor(sorted.length / 2);
	return sorted.length % 2 === 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid];
}

function stdDev(values, mean)
{
	if(values.length < 2)
	{
		return 0;
	}
	const variance = values.reduce((s, v) => s + Math.pow(v - mean, 2), 0) / values.length;
	return Math.sqrt(variance);
}

function harvestRows(input)
{
	const rows = [];
	const re = /PERF_ROW:\s*(\{[^}]+\})/g;
	let match;
	while((match = re.exec(input)) !== null)
	{
		try
		{
			rows.push(JSON.parse(match[1]));
		}
		catch(e)
		{
			console.error('Failed to parse PERF_ROW:', match[1]);
		}
	}
	return rows;
}

function classify(value, currentMedian)
{
	if(currentMedian === undefined || currentMedian === null)
	{
		return 'NEW';
	}
	const ratio = value / currentMedian;
	if(ratio >= LOUD_RATIO)
	{
		return 'WARN!';
	}
	if(ratio >= WARN_RATIO)
	{
		return 'WARN';
	}
	if(ratio > 1.0)
	{
		return 'INFO';
	}
	return 'OK';
}

function main()
{
	const args = parseArgs();
	let history = loadHistory();

	if(args.report)
	{
		console.log(JSON.stringify(history, null, 2));
		return;
	}

	if(args.reset)
	{
		if(args.section)
		{
			const key = Object.keys(history).find(k => k.startsWith(`section-${args.section}-`));
			if(key)
			{
				delete history[key];
			}
		}
		else
		{
			history = {};
		}
		saveHistory(history);
		console.log('History reset.');
		return;
	}

	const input = args.logfile ? fs.readFileSync(args.logfile, 'utf8') : fs.readFileSync(0, 'utf8');
	const rows = harvestRows(input);

	if(rows.length === 0)
	{
		console.log('No PERF_ROW lines found in input.');
		return;
	}

	const warnings = [];
	for(const row of rows)
	{
		if(args.section && row.section !== args.section)
		{
			continue;
		}

		const sectionKey = Object.keys(history).find(k => k.startsWith(`section-${row.section}-`)) || `section-${row.section}-unknown`;
		if(!history[sectionKey])
		{
			history[sectionKey] = {};
		}
		if(!history[sectionKey][row.metric])
		{
			history[sectionKey][row.metric] = {history: [], median: null, stdDev: 0};
		}

		const entry = history[sectionKey][row.metric];
		const currentMedian = entry.median;
		const verdict = classify(row.value, currentMedian);

		entry.history.push(row.value);
		if(entry.history.length > MAX_HISTORY)
		{
			entry.history.shift();
		}
		entry.median = median(entry.history);
		entry.stdDev = stdDev(entry.history, entry.median);

		const msg = `${verdict.padEnd(5)} section-${row.section} ${row.metric}=${row.value} (median was ${currentMedian || '—'})`;
		console.log(msg);
		if(verdict === 'WARN' || verdict === 'WARN!')
		{
			warnings.push(msg);
		}
	}

	saveHistory(history);

	if(warnings.length > 0)
	{
		console.log('\n=== Performance regressions ===');
		warnings.forEach(w => console.log(w));
	}

	process.exit(0);
}

main();
