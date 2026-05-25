// SPDX-License-Identifier: MIT
'use strict';
/**
 * slack-payload.js
 *
 * Port of an upstream Python Slack payload builder from a subscriber SFCA
 * Quality Gate workflow. Reads a violations CSV produced by Salesforce Code
 * Analyser and assembles a Slack attachment payload JSON.
 *
 * Upstream source: .github/workflows/SFCA Quality Gate.yml lines 246-498.
 *
 * CSV columns used (case-insensitive, whitespace-trimmed):
 *   severity  — numeric string "1"–"5"
 *   engine    — "pmd", "eslint", "flow", etc.
 *   rule      — rule name (also accepted: "rulename")
 *   file      — path (also accepted: fpath)
 *   startline — line number (also accepted: "line", "linenumber")
 *   message   — violation message
 *
 * Output: Slack legacy-attachment payload written to stdout as pretty JSON.
 */

const fs = require('node:fs');

const MAX_BLOCKING_ROWS = 15;

function parseRow(line)
{
	const fields = [];
	let i = 0;
	let current = '';
	let inQuotes = false;
	while (i < line.length)
	{
		const c = line[i];
		if (inQuotes)
		{
			if (c === '"' && line[i + 1] === '"') { current += '"'; i += 2; continue; }
			if (c === '"') { inQuotes = false; i++; continue; }
			current += c; i++; continue;
		}
		if (c === '"') { inQuotes = true; i++; continue; }
		if (c === ',') { fields.push(current); current = ''; i++; continue; }
		current += c; i++;
	}
	fields.push(current);
	return fields;
}

function parseCsv(content)
{
	const lines = content.split(/\r?\n/).filter(line => line.length > 0);
	if (lines.length === 0) return { headers: [], rows: [] };
	const headers = parseRow(lines[0]);
	const rows = lines.slice(1).map(parseRow);
	return { headers, rows };
}

function classifyEngine(engine, fpath)
{
	const eng = (engine || '').trim().toLowerCase();
	const fp = (fpath || '').toLowerCase();
	if (eng === 'flow') return 'flow';
	if (eng === 'eslint')
	{
		if (fp.includes('/lwc/')) return 'lwc';
		if (fp.includes('/aura/')) return 'aura';
		return 'js';
	}
	if (eng === 'pmd') return 'apex';
	return (eng.slice(0, 4)) || 'oth';
}

function truncMid(s, width)
{
	if (s.length <= width) return s;
	if (width < 6) return s.slice(0, width);
	const head = Math.floor((width - 1) / 2);
	const tail = width - 1 - head;
	return s.slice(0, head) + '…' + s.slice(-tail);
}

function padEnd(s, n) { return s + ' '.repeat(Math.max(0, n - s.length)); }
function padStart(s, n) { return ' '.repeat(Math.max(0, n - s.length)) + s; }

function groupRows(rows)
{
	const map = new Map();
	for (const r of rows)
	{
		const key = `${r.sev}||${r.src}||${r.rule}||${r.fname}`;
		if (!map.has(key)) map.set(key, { sev: r.sev, src: r.src, rule: r.rule, fname: r.fname, lines: [], cnt: 0 });
		const entry = map.get(key);
		entry.lines.push(r.line);
		entry.cnt++;
	}
	const result = [];
	for (const entry of map.values())
	{
		const uniq = [...new Set(entry.lines.filter(l => l && /^\d+$/.test(l)))].sort((a, b) => parseInt(a) - parseInt(b));
		let lineStr;
		if (uniq.length === 0) lineStr = '-';
		else if (uniq.length === 1) lineStr = uniq[0];
		else if (uniq.length <= 3) lineStr = uniq.join(',');
		else lineStr = `${uniq[0]},…,${uniq[uniq.length - 1]}`;
		result.push({ sev: entry.sev, src: entry.src, rule: entry.rule, fname: entry.fname, lineStr, cnt: entry.cnt });
	}
	return result;
}

function buildSlackPayload(opts)
{
	const { csv, prUrl, prTitle, prAuthor, prNumber, headRef, baseRef, repo, runId, counts } = opts;

	let rawRows = [];
	try
	{
		const content = fs.readFileSync(csv, 'utf-8');
		const { headers, rows } = parseCsv(content);
		const hIdx = {};
		headers.forEach((h, i) => { hIdx[h.toLowerCase().trim()] = i; });

		const col = (row, ...names) =>
		{
			for (const n of names)
			{
				const i = hIdx[n];
				if (i !== undefined && row[i] !== undefined) return (row[i] || '').trim();
			}
			return '';
		};

		for (const row of rows)
		{
			const sev = col(row, 'severity');
			const rule = col(row, 'rule', 'rulename');
			const engine = col(row, 'engine');
			const fpath = col(row, 'file').replace(/\\/g, '/');
			const fname = fpath.split('/').pop() || fpath;
			const line = col(row, 'startline', 'line', 'linenumber');
			const message = col(row, 'message').replace(/[\r\n]+/g, ' ');
			if (sev || rule)
			{
				rawRows.push({ sev, src: classifyEngine(engine, fpath), rule, fname, fpath, line, message });
			}
		}
	}
	catch (err)
	{
		if (err.code !== 'ENOENT') throw err;
	}

	const sevCounts = counts || computeSevCounts(rawRows);
	const sev1 = sevCounts.sev1;
	const sev2 = sevCounts.sev2;
	const sev3 = sevCounts.sev3;
	const sev4 = sevCounts.sev4;
	const sev5 = sevCounts.sev5;
	const totalV = sev1 + sev2 + sev3 + sev4 + sev5;

	if (totalV === 0)
	{
		return null;
	}

	const status = (sev1 > 0 || sev2 > 0) ? 'FAILED' : 'PASSED with warnings';
	const color = (sev1 > 0 || sev2 > 0) ? 'danger' : 'warning';
	const heading = (sev1 > 0 || sev2 > 0) ? '🔴' : '🟠';

	let top = null;
	if (rawRows.length > 0)
	{
		const blocking = rawRows.filter(r => r.sev === '1' || r.sev === '2');
		const pool = blocking.length > 0 ? blocking : rawRows;
		pool.sort((a, b) =>
		{
			const sa = /^\d+$/.test(a.sev) ? parseInt(a.sev) : 99;
			const sb = /^\d+$/.test(b.sev) ? parseInt(b.sev) : 99;
			if (sa !== sb) return sa - sb;
			if (a.rule !== b.rule) return a.rule < b.rule ? -1 : 1;
			return a.fname < b.fname ? -1 : 1;
		});
		top = pool[0];
	}

	let topText = null;
	if (top)
	{
		const loc = top.line ? `\`${top.fname}:${top.line}\`` : `\`${top.fname}\``;
		topText = `*Top blocker:* \`[${top.rule}]\` in ${loc}`;
		if (top.message)
		{
			let m = top.message;
			if (m.length > 160) m = m.slice(0, 157) + '…';
			topText += `\n> ${m}`;
		}
	}

	const infoTotal = sev3 + sev4 + sev5;
	let infoBreakdownLine = '';
	if (infoTotal > 0)
	{
		const ruleCounts = new Map();
		for (const r of rawRows)
		{
			if ((r.sev === '3' || r.sev === '4' || r.sev === '5') && r.rule)
			{
				ruleCounts.set(r.rule, (ruleCounts.get(r.rule) || 0) + 1);
			}
		}
		if (ruleCounts.size > 0)
		{
			const sorted = [...ruleCounts.entries()].sort((a, b) => b[1] - a[1]);
			const top4 = sorted.slice(0, 4);
			const remainder = sorted.slice(4).reduce((acc, [, c]) => acc + c, 0);
			const parts = top4.map(([rule, cnt]) => `${cnt}× \`${rule}\``);
			if (remainder > 0) parts.push(`+${remainder} other`);
			infoBreakdownLine = ' — ' + parts.join(', ');
		}
	}

	const pill = (emoji, label, n) => `${emoji} ${n} ${label}`;
	const stats = [
		pill('🔴', 'Sev-1', sev1),
		pill('🟠', 'Sev-2', sev2),
		pill('🟡', 'Sev-3', sev3),
		pill('⚪', 'info', sev4 + sev5),
	].join(' · ');

	const runUrl = `https://github.com/${repo}/actions/runs/${runId}`;
	const filesUrl = `${prUrl}/files`;
	const uniqueFiles = new Set(rawRows.map(r => r.fname)).size;
	const title = `${heading} SFCA ${status} — ${totalV} violation(s) across ${uniqueFiles} file(s)`;

	const blockingGrouped = groupRows(rawRows.filter(r => r.sev === '1' || r.sev === '2'));
	blockingGrouped.sort((a, b) =>
	{
		const sa = /^\d+$/.test(a.sev) ? parseInt(a.sev) : 99;
		const sb = /^\d+$/.test(b.sev) ? parseInt(b.sev) : 99;
		if (sa !== sb) return sa - sb;
		return a.rule < b.rule ? -1 : 1;
	});

	let blockingText = null;
	if (blockingGrouped.length > 0)
	{
		const shown = blockingGrouped.slice(0, MAX_BLOCKING_ROWS);
		const overflow = blockingGrouped.length - shown.length;
		const C_SEV = 3, C_SRC = 4, C_RULE = 26, C_FILE = 28, C_LINE = 9, C_CNT = 4;
		const hdrLine = padEnd('SEV', C_SEV) + '  ' + padEnd('SRC', C_SRC) + '  '
			+ padEnd('RULE', C_RULE) + '  ' + padEnd('FILE', C_FILE) + '  '
			+ padStart('LINE(S)', C_LINE) + '  ' + padStart('CNT', C_CNT);
		const sep = '-'.repeat(hdrLine.length);
		const tableLines = [hdrLine, sep];
		for (const { sev, src, rule, fname, lineStr, cnt } of shown)
		{
			tableLines.push(
				padEnd(sev, C_SEV) + '  '
				+ padEnd(src.slice(0, C_SRC), C_SRC) + '  '
				+ padEnd(truncMid(rule, C_RULE), C_RULE) + '  '
				+ padEnd(truncMid(fname, C_FILE), C_FILE) + '  '
				+ padStart(lineStr.slice(0, C_LINE), C_LINE) + '  '
				+ padStart(String(cnt), C_CNT)
			);
		}
		if (overflow > 0) tableLines.push(`...and ${overflow} more blocking violation(s); full list in the artifact`);
		blockingText = '```\n' + tableLines.join('\n') + '\n```';
	}

	let infoText = null;
	if (infoTotal > 0)
	{
		infoText = `_${infoTotal} non-blocking violation(s) (${sev3} Sev-3 + ${sev4 + sev5} info)${infoBreakdownLine}. See the run artifact for the full list._`;
	}

	const fields = [
		{ title: 'PR', value: `<${prUrl}|#${prNumber} ${prTitle}>`, short: false },
		{ title: 'Author', value: prAuthor, short: true },
		{ title: 'Branch', value: `${headRef} → ${baseRef}`, short: true },
		{ title: 'Severity', value: stats, short: false },
	];
	if (topText) fields.push({ title: 'Top blocker', value: topText, short: false });
	if (blockingText) fields.push({ title: 'Blocking violations (Sev-1/Sev-2)', value: blockingText, short: false });
	if (infoText) fields.push({ title: 'Informational', value: infoText, short: false });

	const cta = `<${filesUrl}|Files Changed> · <${runUrl}|Workflow Run>`;
	fields.push({ title: 'Details', value: cta, short: false });

	return {
		text: `${heading} SFCA ${status} on <${prUrl}|PR #${prNumber}> — ${totalV} violation(s)`,
		attachments: [{
			color,
			title,
			title_link: prUrl,
			fields,
			mrkdwn_in: ['text', 'fields'],
		}],
	};
}

function computeSevCounts(rawRows)
{
	return {
		sev1: rawRows.filter(r => r.sev === '1').length,
		sev2: rawRows.filter(r => r.sev === '2').length,
		sev3: rawRows.filter(r => r.sev === '3').length,
		sev4: rawRows.filter(r => r.sev === '4').length,
		sev5: rawRows.filter(r => r.sev === '5').length,
	};
}

function slackPayload(opts)
{
	const payload = buildSlackPayload(opts);
	if (payload === null) return JSON.stringify({ should_notify: false }, null, 2);
	return JSON.stringify(payload, null, 2);
}

function encodeForSlack(text)
{
	return text.replace(/%/g, '%25').replace(/,/g, '%2C').replace(/:/g, '%3A');
}

module.exports = { slackPayload, parseCsv, parseRow, encodeForSlack, buildSlackPayload, classifyEngine, truncMid, groupRows };
