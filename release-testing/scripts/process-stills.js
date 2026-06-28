// SPDX-License-Identifier: BUSL-1.1
// Turns the raw full-viewport PNG screenshots from the `stills` Playwright project into committed
// guide stills under docs-site/assets/stills/: 1280-wide JPEGs, each kept under the 200 KB budget by
// stepping the JPEG quality down until it fits. ffmpeg is a SYSTEM CLI (not an npm dep) — preflighted.
const {execFileSync} = require('child_process');
const fs = require('fs');
const path = require('path');

const MAX_STILL_BYTES = 200 * 1024; // 200 KB per still (mirrors the poster ceiling)

const STILLS = [
	'kern-home',
	'org-limits',
	'event-usage',
	'log-entry',
	'api-calls-picker',
	'api-issues-queue',
	'async-timeline'
];

const ROOT = path.join(__dirname, '..', '..');
const RAW_DIR = path.join(ROOT, 'release-testing', 'test-results', 'stills');
const OUT_DIR = path.join(ROOT, 'docs-site', 'assets', 'stills');

function preflightFfmpeg()
{
	try
	{
		execFileSync('ffmpeg', ['-version'], {stdio: 'ignore'});
	}
	catch(e)
	{
		throw new Error('ffmpeg not found on PATH. Install it (e.g. `brew install ffmpeg`) before processing stills.');
	}
}

// Encode a 1280-wide JPEG, stepping quality down (higher -q:v = more compression) until it fits the
// budget. Returns the byte size on success, throws if even the most-compressed pass is over.
function encodeStill(input, output)
{
	for(let q = 4; q <= 16; q += 2)
	{
		execFileSync('ffmpeg', ['-y', '-i', input, '-vf', 'scale=1280:-2', '-q:v', String(q), output], {stdio: 'ignore'});
		const bytes = fs.statSync(output).size;
		if(bytes <= MAX_STILL_BYTES)
		{
			return {bytes, q};
		}
	}
	const bytes = fs.statSync(output).size;
	throw new Error(`${path.basename(output)} is ${Math.round(bytes / 1024)} KB, over the ${Math.round(MAX_STILL_BYTES / 1024)} KB limit even at max compression.`);
}

function processAll(only)
{
	preflightFfmpeg();
	fs.mkdirSync(OUT_DIR, {recursive: true});
	const selected = (only && only.length) ? STILLS.filter(k => only.includes(k)) : STILLS;
	if(only && only.length && selected.length !== only.length)
	{
		throw new Error(`Unknown still key(s) in ${JSON.stringify(only)} — known keys: ${STILLS.join(', ')}`);
	}
	const summary = [];
	for(const key of selected)
	{
		const raw = path.join(RAW_DIR, `${key}.png`);
		if(!fs.existsSync(raw))
		{
			throw new Error(`No raw screenshot for ${key} at ${raw} — run the stills capture project first.`);
		}
		const out = path.join(OUT_DIR, `${key}.jpg`);
		const {bytes, q} = encodeStill(raw, out);
		summary.push({key, kb: Math.round(bytes / 1024), q});
	}
	console.log('Stills processed:');
	for(const s of summary)
	{
		console.log(`  ${s.key}: ${s.kb} KB (q${s.q})`);
	}
	return summary;
}

if(require.main === module)
{
	processAll(process.argv.slice(2));
}

module.exports = {processAll, encodeStill, preflightFfmpeg, MAX_STILL_BYTES, OUT_DIR, STILLS};
