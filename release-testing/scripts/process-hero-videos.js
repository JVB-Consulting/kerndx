// SPDX-License-Identifier: BUSL-1.1
// Turns the raw always-on WebM captures into committed hero-loop assets in TWO formats —
// VP9 WebM (primary) + H.264 MP4 (iOS Safari / older-browser fallback) — plus a poster. Strips
// audio, normalizes to 30 fps. Quality-first: warn over the preferred size, FAIL over the hard
// limit. ffmpeg is a SYSTEM CLI (not an npm dep) — preflighted here.
const {execFileSync} = require('child_process');
const fs = require('fs');
const path = require('path');

const PREFERRED_BYTES = 2 * 1024 * 1024; // 2 MB — warn if a clip is larger
const MAX_CLIP_BYTES = 3 * 1024 * 1024;  // 3 MB — hard fail
const MAX_POSTER_BYTES = 200 * 1024;     // 200 KB per poster
// The raw capture opens on the Lightning app-shell load (a blank/spinner pre-roll before the tool
// renders, ~2s). In a LOOPING clip that dead frame replays every cycle, so trim it off the front.
// Every tool is interactive by ~2.0s, so this never cuts a beat.
const LEAD_TRIM_SECONDS = 2.0;

const TOOLS = [
	{key: 'api-harness', title: 'api-harness'},
	{key: 'streaming-monitor', title: 'streaming-monitor'},
	{key: 'chain-monitor', title: 'chain-monitor'},
	{key: 'masking-advisor', title: 'masking-advisor'}
];

const ROOT = path.join(__dirname, '..', '..');
const RAW_DIR = path.join(ROOT, 'release-testing', 'test-results');
const OUT_DIR = path.join(ROOT, 'docs-site', 'assets', 'recordings');

function preflightFfmpeg()
{
	try
	{
		execFileSync('ffmpeg', ['-version'], {stdio: 'ignore'});
	}
	catch(e)
	{
		throw new Error('ffmpeg not found on PATH. Install it (e.g. `brew install ffmpeg`) before processing hero videos.');
	}
}

function findRawWebm(title)
{
	if(!fs.existsSync(RAW_DIR))
	{
		return null;
	}
	const dirs = fs.readdirSync(RAW_DIR, {withFileTypes: true})
		.filter(d => d.isDirectory() && d.name.includes(title) && d.name.includes('capture'));
	for(const d of dirs)
	{
		const v = path.join(RAW_DIR, d.name, 'video.webm');
		if(fs.existsSync(v))
		{
			return v;
		}
	}
	return null;
}

function encodeWebm(input, output)
{
	execFileSync('ffmpeg', [
		'-y', '-ss', String(LEAD_TRIM_SECONDS), '-i', input,
		'-an', '-r', '30',
		'-c:v', 'libvpx-vp9', '-b:v', '0', '-crf', '32',
		'-vf', 'scale=1280:-2',
		'-pix_fmt', 'yuv420p',
		output
	], {stdio: 'inherit'});
}

function encodeMp4(input, output)
{
	execFileSync('ffmpeg', [
		'-y', '-ss', String(LEAD_TRIM_SECONDS), '-i', input,
		'-an', '-r', '30',
		'-c:v', 'libx264', '-crf', '24', '-preset', 'slow',
		'-vf', 'scale=1280:-2',
		'-pix_fmt', 'yuv420p',
		'-movflags', '+faststart',
		output
	], {stdio: 'inherit'});
}

function extractPoster(input, output)
{
	// Grab the poster from the final dwell (1.5s before the end), NOT frame 0 — the first frame is
	// the blank pre-load screen. The dwell frame shows the tool's key result, so it's a representative
	// still for the reduced-motion / pre-autoplay state.
	execFileSync('ffmpeg', ['-y', '-sseof', '-1.5', '-i', input, '-frames:v', '1', '-update', '1', '-vf', 'scale=1280:-2', '-q:v', '4', output], {stdio: 'inherit'});
}

function checkBudget(file, max, label)
{
	const bytes = fs.statSync(file).size;
	if(bytes > max)
	{
		throw new Error(`${label} is ${Math.round(bytes / 1024)} KB, over the ${Math.round(max / 1024)} KB hard limit: ${file}`);
	}
	return bytes;
}

function warnIfOverPreferred(bytes, label)
{
	if(bytes > PREFERRED_BYTES)
	{
		console.warn(`WARN: ${label} is ${Math.round(bytes / 1024)} KB, over the ${Math.round(PREFERRED_BYTES / 1024)} KB preferred size (under the hard limit).`);
	}
}

function processAll()
{
	preflightFfmpeg();
	fs.mkdirSync(OUT_DIR, {recursive: true});
	const summary = [];
	for(const tool of TOOLS)
	{
		const raw = findRawWebm(tool.title);
		if(!raw)
		{
			throw new Error(`No raw capture for ${tool.key} under ${RAW_DIR} — run the capture project first.`);
		}
		const webm = path.join(OUT_DIR, `${tool.key}.webm`);
		const mp4 = path.join(OUT_DIR, `${tool.key}.mp4`);
		const poster = path.join(OUT_DIR, `${tool.key}-poster.jpg`);
		encodeWebm(raw, webm);
		encodeMp4(raw, mp4);
		extractPoster(webm, poster);
		const wb = checkBudget(webm, MAX_CLIP_BYTES, `${tool.key}.webm`);
		warnIfOverPreferred(wb, `${tool.key}.webm`);
		const mb = checkBudget(mp4, MAX_CLIP_BYTES, `${tool.key}.mp4`);
		warnIfOverPreferred(mb, `${tool.key}.mp4`);
		const pb = checkBudget(poster, MAX_POSTER_BYTES, `${tool.key}-poster.jpg`);
		summary.push({tool: tool.key, webmKB: Math.round(wb / 1024), mp4KB: Math.round(mb / 1024), posterKB: Math.round(pb / 1024)});
	}
	console.log('Hero videos processed:');
	for(const s of summary)
	{
		console.log(`  ${s.tool}: ${s.webmKB} KB webm, ${s.mp4KB} KB mp4, ${s.posterKB} KB poster`);
	}
	return summary;
}

if(require.main === module)
{
	processAll();
}

module.exports = {processAll, checkBudget, warnIfOverPreferred, findRawWebm, preflightFfmpeg, PREFERRED_BYTES, MAX_CLIP_BYTES, MAX_POSTER_BYTES, OUT_DIR, TOOLS};
