#!/usr/bin/env node
// SPDX-License-Identifier: BUSL-1.1
'use strict';

/**
 * @description Compares a Salesforce Code Analyzer scan with the AppExchange rule set against the list of known
 *              findings in scanner/appexchange-baseline.json. Every known finding is explained in SECURITY.md, under
 *              "What a code scan reports, and why".
 *
 *              A finding is identified by its rule, its file, its message and a short hash of the source line the
 *              scan points at (spaces around the text are ignored), with a count for each. The script reads that line
 *              from the scanned copy itself. So a finding whose line only moved keeps its identity, while a changed
 *              or new line is a new finding, even when the same rule already has a finding in the same file.
 *
 *              It fails (exit 1) when the scan reports a finding that is not in the baseline, reports a known one
 *              more often than the baseline allows, could not run part of the scan (an entry with no file, such as
 *              an engine that could not start), or when a rule in the baseline has no section in SECURITY.md. It also
 *              fails when the scan checked nothing: a file with no list of findings, a list with no findings, or a
 *              scan that found none of the known findings. Some known findings no longer reported is a warning:
 *              remove them from the baseline in a reviewed commit.
 *
 *              Usage:
 *                node scripts/check-appexchange-baseline.js <scan.json> [--baseline <file>] [--security <file>]
 *                node scripts/check-appexchange-baseline.js <scan.json> --write <file>
 *              The scan is the JSON file from `sf code-analyzer run --rule-selector AppExchange --output-file`.
 *              `--write` builds a new baseline from a scan, for a reviewed commit.
 *
 *              Exit codes: 0 every finding is known and documented, 1 the check failed, 2 the input could not be read.
 *
 * @author Kern Framework
 * @date October 2026
 */

const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

const REPOSITORY_ROOT = path.resolve(__dirname, '..');
const DEFAULT_BASELINE = path.join(REPOSITORY_ROOT, 'scanner', 'appexchange-baseline.json');
const DEFAULT_SECURITY = path.join(REPOSITORY_ROOT, 'SECURITY.md');
const USAGE = 'Usage: node scripts/check-appexchange-baseline.js <scan.json> [--baseline <file>] [--security <file>] [--write <file>]';

// The SECURITY.md section that explains each rule's findings. A new rule needs a section before it can be added.
const SECURITY_SECTIONS = {
	AvoidUnauthorizedApiSessionIdInVisualforce: 'A Visualforce page reads the session ID',
	AvoidLmcIsExposedTrue: 'Two message channels are exposed',
	ProtectSensitiveData: 'Field names that look like secrets',
	AvoidLwcBubblesComposedTrue: 'Test files for the streaming monitor'
};

/**
 * @description A short hash of one source line, with the spaces around it removed.
 *
 * @param {string} text
 * @return {string} 16 hexadecimal characters
 */
function hashLine(text)
{
	return crypto.createHash('sha256').update(text.trim()).digest('hex').slice(0, 16);
}

/**
 * @description Cuts a scanned file's path down to the part from `force-app/` on, so a scan of a copy anywhere on disk
 * gives the same names as the repository.
 *
 * @param {string} file
 * @return {string}
 */
function normaliseFile(file)
{
	const forward = file.replace(/\\/g, '/');
	const index = forward.indexOf('force-app/');
	return index === -1 ? forward : forward.slice(index);
}

function keyOf(finding)
{
	return [finding.rule, finding.file, finding.message, finding.lineHash].join('\u0000');
}

function firstLine(text)
{
	return String(text || '').split('\n')[0].trim();
}

/**
 * @description Turns the scan's entries into findings with a count for each identity, and lists the entries that
 * show the scan did not run completely.
 *
 * @param {{violations: Array<object>}} scan
 * @return {{findings: Array<object>, scanErrors: string[]}}
 */
function collectFindings(scan)
{
	const counts = new Map();
	const scanErrors = [];
	const fileLines = new Map();
	for(const entry of scan.violations || [])
	{
		const location = (entry.locations || [])[entry.primaryLocationIndex || 0] || {};
		if(!location.file)
		{
			scanErrors.push(`${entry.rule} (${entry.engine}): ${firstLine(entry.message)}`);
			continue;
		}
		if(!fileLines.has(location.file))
		{
			fileLines.set(location.file, fs.existsSync(location.file) ? fs.readFileSync(location.file, 'utf8').split(/\r?\n/) : null);
		}
		const lines = fileLines.get(location.file);
		if(!lines)
		{
			scanErrors.push(`${entry.rule}: cannot read ${location.file} to check the reported line`);
			continue;
		}
		const finding = {
			rule: entry.rule,
			file: normaliseFile(location.file),
			message: firstLine(entry.message),
			lineHash: hashLine(lines[(location.startLine || 1) - 1] ?? '')
		};
		const key = keyOf(finding);
		const known = counts.get(key);
		if(known)
		{
			known.count++;
		}
		else
		{
			counts.set(key, {...finding, count: 1});
		}
	}
	const findings = [...counts.values()].sort((a, b) => a.rule.localeCompare(b.rule) || a.file.localeCompare(b.file) || a.lineHash.localeCompare(b.lineHash));
	return {findings, scanErrors};
}

/**
 * @description Compares the scan's findings with the baseline.
 *
 * @param {Array<object>} findings
 * @param {{findings: Array<object>}} baseline
 * @return {{added: Array<object>, exceeded: Array<object>, vanished: Array<object>}}
 */
function compareWithBaseline(findings, baseline)
{
	const allowed = new Map(baseline.findings.map(entry => [keyOf(entry), entry]));
	const found = new Map(findings.map(finding => [keyOf(finding), finding]));
	const added = [];
	const exceeded = [];
	for(const finding of findings)
	{
		const known = allowed.get(keyOf(finding));
		if(!known)
		{
			added.push(finding);
		}
		else if(finding.count > known.count)
		{
			exceeded.push({...finding, allowed: known.count});
		}
	}
	const vanished = baseline.findings
	.map(entry => ({...entry, found: found.get(keyOf(entry))?.count ?? 0}))
	.filter(entry => entry.found < entry.count);
	return {added, exceeded, vanished};
}

/**
 * @description Builds a baseline from a scan's findings, naming the SECURITY.md section for each rule.
 *
 * @param {Array<object>} findings
 * @param {Object<string, string>} sections rule name to SECURITY.md heading
 * @return {{description: string, documentedIn: Object<string, string>, findings: Array<object>}}
 */
function buildBaseline(findings, sections)
{
	const documentedIn = {};
	for(const {rule} of findings)
	{
		if(!sections[rule])
		{
			throw new Error(`${rule} has no section in SECURITY.md yet: explain it there and name the section in this script first`);
		}
		documentedIn[rule] = sections[rule];
	}
	return {
		description: 'Known findings of Salesforce Code Analyzer with the AppExchange rule set, each explained in SECURITY.md under the section named in documentedIn. '
			+ 'A finding is its rule, file, message and a hash of the trimmed source line it points at. scripts/check-appexchange-baseline.js fails CI on any other finding.',
		documentedIn,
		findings
	};
}

/**
 * @description Lists the baseline's rules that have no section in SECURITY.md.
 *
 * @param {{documentedIn: Object<string, string>, findings: Array<object>}} baseline
 * @param {string} securityText the content of SECURITY.md
 * @return {string[]}
 */
function findUndocumentedRules(baseline, securityText)
{
	const headings = new Set(securityText.split('\n').map(line => line.match(/^#{1,6}\s+(.*?)\s*$/)?.[1]).filter(Boolean));
	const rules = [...new Set(baseline.findings.map(finding => finding.rule))];
	return rules.filter(rule => !headings.has(baseline.documentedIn?.[rule]));
}

function parseArguments(argv)
{
	const options = {scan: null, baseline: DEFAULT_BASELINE, security: DEFAULT_SECURITY, write: null};
	const valued = {'--baseline': 'baseline', '--security': 'security', '--write': 'write'};
	for(let index = 0; index < argv.length; index++)
	{
		const argument = argv[index];
		if(valued[argument])
		{
			if(argv[index + 1] === undefined)
			{
				throw new Error(`${argument} needs a value`);
			}
			options[valued[argument]] = argv[++index];
		}
		else if(argument.startsWith('--') || options.scan)
		{
			throw new Error(`Unknown option: ${argument}`);
		}
		else
		{
			options.scan = argument;
		}
	}
	if(!options.scan)
	{
		throw new Error('Name the scan file');
	}
	return options;
}

function plural(count, word)
{
	return `${count} ${word}${count === 1 ? '' : 's'}`;
}

/**
 * @description Runs the check.
 *
 * @param {string[]} argv
 * @param {{log: function, warn: function}} dependencies
 * @return {number} the exit code
 */
function run(argv, {log, warn})
{
	let options;
	let scan;
	try
	{
		options = parseArguments(argv);
		scan = JSON.parse(fs.readFileSync(options.scan, 'utf8'));
	}
	catch(error)
	{
		log(error.message);
		log(USAGE);
		return 2;
	}
	// A scan that checked nothing must never read as clean: no list of findings means the output changed shape,
	// and an empty list means no rule ran (the analyzer reports a selector that loads no rule the same way).
	if(!Array.isArray(scan?.violations))
	{
		log(`FAIL the scan file ${options.scan} has no list of findings ("violations"), so the scan's output is not one this check can read.`);
		return 1;
	}
	if(scan.violations.length === 0)
	{
		log('FAIL the scan reported no findings at all. The known findings are always there, so no rule ran: check the rule selector and the folder scanned.');
		return 1;
	}
	const {findings, scanErrors} = collectFindings(scan);
	for(const error of scanErrors)
	{
		log(`SCAN ERROR ${error}`);
	}
	if(options.write)
	{
		if(scanErrors.length)
		{
			log('Not writing a baseline from a scan that did not run completely.');
			return 2;
		}
		fs.writeFileSync(options.write, JSON.stringify(buildBaseline(findings, SECURITY_SECTIONS), null, '\t') + '\n');
		log(`Wrote ${plural(findings.length, 'finding')} to ${options.write}`);
		return 0;
	}

	const baseline = JSON.parse(fs.readFileSync(options.baseline, 'utf8'));
	const {added, exceeded, vanished} = compareWithBaseline(findings, baseline);
	const undocumented = findUndocumentedRules(baseline, fs.readFileSync(options.security, 'utf8'));
	for(const finding of added)
	{
		log(`NEW ${finding.rule} in ${finding.file}: ${finding.message} (${plural(finding.count, 'time')})`);
	}
	for(const finding of exceeded)
	{
		log(`MORE ${finding.rule} in ${finding.file}: found ${finding.count}, the baseline allows ${finding.allowed}`);
	}
	for(const rule of undocumented)
	{
		log(`UNDOCUMENTED ${rule}: the baseline names no matching section in ${path.basename(options.security)}`);
	}
	for(const entry of vanished)
	{
		warn(`${entry.rule} in ${entry.file} is in the baseline ${entry.count} time(s) but the scan found it ${entry.found} time(s): update the baseline in a reviewed commit.`);
	}
	const total = findings.reduce((sum, finding) => sum + finding.count, 0);
	const noneKnownFound = baseline.findings.length > 0 && vanished.length === baseline.findings.length && vanished.every(entry => entry.found === 0);
	if(noneKnownFound)
	{
		log(`FAIL the scan found none of the ${plural(baseline.findings.length, 'known finding')}, so it did not scan what the baseline describes.`);
	}
	if(added.length || exceeded.length || undocumented.length || scanErrors.length || noneKnownFound)
	{
		const counts = `${added.length} new, ${exceeded.length} more often than allowed, ${undocumented.length} undocumented, ${scanErrors.length} scan error(s)`;
		log(`Check failed: ${plural(total, 'finding')}, ${counts}.`);
		return 1;
	}
	log(`Check passed: ${plural(total, 'finding')}, all in the baseline and documented in ${path.basename(options.security)}.`);
	return 0;
}

module.exports = {
	SECURITY_SECTIONS,
	hashLine,
	normaliseFile,
	collectFindings,
	compareWithBaseline,
	buildBaseline,
	findUndocumentedRules,
	run
};

if(require.main === module)
{
	process.exitCode = run(process.argv.slice(2), {
		log: message => console.log(message),
		warn: message => console.warn(`WARNING ${message}`)
	});
}
