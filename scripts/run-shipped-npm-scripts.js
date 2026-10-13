// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Runs every npm script the shipped package.json offers a reader, on this machine, except the ones a
 *              register row excuses with a reason and what proves them instead. A script is in by default, so a new
 *              one is proven on Windows before a reader meets it. The shipped set is the working directory's own
 *              package.json, so the tree it runs in must carry the package.json a reader gets. The scripts the
 *              register's changesFiles names rewrite that tree, so they run after every other script.
 *              Usage: node scripts/run-shipped-npm-scripts.js --working-directory <tree> [--register <file>] [--list]
 */
'use strict';

const fs = require('fs');
const path = require('path');
const {spawnSync} = require('child_process');

const DEFAULT_REGISTER = path.join(__dirname, 'shipped-npm-scripts-register.json');
const OUTPUT_LIMIT = 64 * 1024 * 1024;
const TAIL_LINES = 15;

/**
 * @description The shipped package.json as an object: the working directory's own.
 * @param {string} workingDirectory - The tree whose package.json is read.
 * @returns {Object} The shipped package.json.
 */
function shippedPackage(workingDirectory)
{
	return JSON.parse(fs.readFileSync(path.join(workingDirectory, 'package.json'), 'utf8'));
}

/**
 * @description The scripts a reader's package.json offers.
 * @param {string} workingDirectory - The tree whose package.json is read.
 * @returns {Object<string, string>} Script name to command.
 */
function shippedScripts(workingDirectory)
{
	return shippedPackage(workingDirectory).scripts || {};
}

/**
 * @description The scripts to run: every shipped script that no register row excuses. A row must carry a reason and
 *              a provenBy, and must name a script that ships. The scripts the register's changesFiles names rewrite
 *              the tree they run in, so they run last and every other script sees the tree a reader clones; each of
 *              those names must be a script that ships.
 * @param {Object<string, string>} scripts - The shipped scripts.
 * @param {{excluded: Array<{script: string, reason: string, provenBy: string}>, changesFiles: string[]}} register - The register.
 * @returns {string[]} Script names, in package.json order, with the ones that change files after the rest.
 */
function plannedScripts(scripts, register)
{
	const changesFiles = new Set(register.changesFiles || []);
	for(const name of changesFiles)
	{
		if(!(name in scripts))
		{
			throw new Error(`changesFiles names a script that does not ship: ${name}`);
		}
	}
	const rows = register.excluded || [];
	for(const row of rows)
	{
		if(!String(row.reason || '').trim() || !String(row.provenBy || '').trim())
		{
			throw new Error(`excluded row for ${row.script} needs a reason and a provenBy`);
		}
		if(!(row.script in scripts))
		{
			throw new Error(`excluded row names a script that does not ship: ${row.script}`);
		}
	}
	const excluded = new Set(rows.map(row => row.script));
	const planned = Object.keys(scripts).filter(name => !excluded.has(name));
	return [...planned.filter(name => !changesFiles.has(name)), ...planned.filter(name => changesFiles.has(name))];
}

/**
 * @description Runs one script the way a reader does, npm run <name>, in the working directory. The command is one
 *              string through the system shell, which is what npm itself is on Windows (npm.cmd), so no argument
 *              array meets a shell here.
 * @param {string} name - The script name.
 * @param {string} workingDirectory - The tree.
 * @returns {{name: string, status: number, seconds: number, tail: string}} What happened.
 */
function runScript(name, workingDirectory)
{
	const started = Date.now();
	const result = spawnSync(`npm run ${name}`, {cwd: workingDirectory, encoding: 'utf8', shell: true, maxBuffer: OUTPUT_LIMIT});
	const output = `${result.stdout || ''}${result.stderr || ''}${result.error ? result.error.message : ''}`;
	return {
		name, status: result.status === null ? 1 : result.status, seconds: Math.round((Date.now() - started) / 1000),
		tail: output.trim().split('\n').slice(-TAIL_LINES).join('\n')
	};
}

/**
 * @description Writes a markdown table of every shipped script, run or excused, to the job summary when there is one.
 *              A script that changes files is marked as one, since it ran after the rest.
 * @param {Array<{name: string, status: number, seconds: number}>} results - The runs.
 * @param {Array<{script: string, reason: string, provenBy: string}>} excluded - The register's rows.
 * @param {string[]} changesFiles - The scripts the register names as changing files.
 */
function writeSummary(results, excluded, changesFiles)
{
	if(!process.env.GITHUB_STEP_SUMMARY)
	{
		return;
	}
	const lines = ['| Script | Outcome | Seconds | Excused because | Proven by |', '|---|---|---|---|---|'];
	for(const result of results)
	{
		const label = changesFiles.includes(result.name) ? `${result.name} (changes files, run last)` : result.name;
		lines.push(`| ${label} | ${result.status === 0 ? 'pass' : `FAIL (${result.status})`} | ${result.seconds} | | |`);
	}
	for(const row of excluded)
	{
		lines.push(`| ${row.script} | excused | | ${row.reason} | ${row.provenBy} |`);
	}
	fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, `## The shipped npm scripts on this runner\n\n${lines.join('\n')}\n\n`);
}

/**
 * @description Entry point. Returns the exit code: 0 every planned script passed, 1 one failed, 2 unusable arguments.
 * @param {string[]} argv - The arguments after the script name.
 * @returns {number} The exit code.
 */
function main(argv)
{
	const valueOf = name => (argv.includes(name) ? argv[argv.indexOf(name) + 1] : undefined);
	const workingDirectory = valueOf('--working-directory');
	if(!workingDirectory)
	{
		console.error('Usage: node scripts/run-shipped-npm-scripts.js --working-directory <tree> [--register <file>] [--list]');
		return 2;
	}
	const register = JSON.parse(fs.readFileSync(valueOf('--register') || DEFAULT_REGISTER, 'utf8'));
	const planned = plannedScripts(shippedScripts(workingDirectory), register);
	if(argv.includes('--list'))
	{
		planned.forEach(name => console.log(name));
		return 0;
	}
	const results = [];
	for(const name of planned)
	{
		const result = runScript(name, path.resolve(workingDirectory));
		results.push(result);
		console.log(`${name}: ${result.status === 0 ? 'pass' : 'FAIL'} (${result.seconds} s)`);
		if(result.status !== 0)
		{
			result.tail.split('\n').forEach(line => console.log(`  ${line}`));
		}
	}
	writeSummary(results, register.excluded || [], register.changesFiles || []);
	return results.some(result => result.status !== 0) ? 1 : 0;
}

module.exports = {DEFAULT_REGISTER, shippedPackage, shippedScripts, plannedScripts, runScript, main};

if(require.main === module)
{
	process.exit(main(process.argv.slice(2)));
}
