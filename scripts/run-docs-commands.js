// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Runs the commands a guide prints, exactly as printed, in every terminal this machine has, inside a
 *              copy of a working tree made once per scope and put back with git between terminals, with stand-ins
 *              for sf, npm and npx; `--real` runs the actual tools in the working tree itself, since its commands
 *              are meant to change the reader's folder. The guide is the test script. What a
 *              stand-in should have been given is worked out from the command's own text, so there is no file of
 *              expected results to keep up to date. A scope's `afterHeading` starts its range only after a named
 *              earlier heading, for a heading text the guide repeats. The stand-in run's environment is hermetic:
 *              its PATH holds the stand-ins and a pass-through for each of the few local tools the guides print,
 *              its home is its own, and it carries none of the machine's variables beyond the few a shell needs,
 *              so a line naming any other tool finds nothing to run, whatever its shape, and needs a skip row with
 *              its proof.
 *              Usage: node scripts/run-docs-commands.js --working-directory <tree> [--register <file>] [--real] [--scope <id>]
 */
'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const {spawnSync} = require('child_process');
const {extractTerminalBlocks, lookalikeTerminalBlocks, commandLines} = require('./lib/terminal-blocks');
const {installStandIns, readRecordedCalls, resolveOnPath} = require('./lib/stand-in-tools');

const REPOSITORY_ROOT = path.resolve(__dirname, '..');
const DEFAULT_REGISTER = path.join(__dirname, 'docs-commands-register.json');
const STAND_IN_TOOLS = ['sf', 'npm', 'npx'];
// The only tools a stand-in run can reach besides the stand-ins, each passed through to the machine's own copy:
// the file tools the guides print, which act in the folder they run in as printed; node, whose children find the
// stand-ins first on the PATH; git, which the environment leaves without a credential helper or a prompt; tar; and
// uname and the two DNS lookups, which read the machine or the public DNS. A tool joins this list when a guide
// prints it and it can reach nothing with this machine's credentials. Everything else is absent from the
// environment, gh, curl and the reader's version manager included, so such a line fails and needs a skip row with
// its proof. The first run of the Documentation Site scope started gh for real against a placeholder repository,
// under the maintainer's login, when the run still inherited the machine's PATH (2026-09-27). Shell builtins need
// no entry: echo, set, export, and on Windows copy, mkdir, rmdir and ver. A pipe into head or tail fails the same
// way, since those are not here either; no guide prints one.
const PASS_THROUGH_TOOLS = ['cp', 'dig', 'git', 'mkdir', 'node', 'nslookup', 'rm', 'rmdir', 'tar', 'uname'];
const TERMINALS = {
	win32: {promised: ['cmd'], alsoTested: ['powershell', 'pwsh']},
	darwin: {promised: ['zsh', 'bash'], alsoTested: []},
	linux: {promised: ['bash'], alsoTested: []}
};
// Each shell by its absolute path, since the hermetic environment's PATH holds no shell.
const SHELL_PROGRAMS = {cmd: process.env.ComSpec || 'cmd.exe', bash: '/bin/bash', zsh: '/bin/zsh'};
const UNIX_TERMINALS = ['bash', 'zsh'];
const OUTPUT_TAIL_LINES = 20;
// The folders a reader's project accumulates that no guide line reads: installed packages, the CLI's own state,
// scratch output and coverage. A copy leaves them out at any depth.
const FOLDERS_LEFT_OUT_OF_A_COPY = ['node_modules', '.sf', '.sfdx', 'tmp', 'coverage'];
// Windows can still hold a folder that was a just-exited child's working directory; the retries wait it out.
const REMOVAL_OPTIONS = {recursive: true, force: true, maxRetries: 10, retryDelay: 100};

/**
 * @description Replaces every occurrence of every key with its value.
 * @param {string} command - A command line as printed.
 * @param {Object<string, string>} [substitutions] - Placeholder text to the value used in the run.
 * @returns {string} The command line that is run.
 */
function substitute(command, substitutions = {})
{
	return Object.entries(substitutions).reduce((text, [key, value]) => text.split(key).join(value), command);
}

/**
 * @description Splits a command line the one way the portable subset allows it to be read: words separated by
 *              spaces, double quotes grouping a word and then dropped. Inside a quoted argument, a backslash
 *              escapes a following double quote or backslash, so `\"` yields a plain `"` and `\\` yields a
 *              single `\`, the way the shell hands the argument to the tool.
 * @param {string} commandLine - A command line as it is run.
 * @returns {string[]} The tool followed by its arguments.
 */
function splitArguments(commandLine)
{
	const parts = [];
	let current = '';
	let quoted = false;
	let started = false;
	const characters = [...commandLine];
	for(let index = 0; index < characters.length; index++)
	{
		const character = characters[index];
		if(quoted && character === '\\' && (characters[index + 1] === '"' || characters[index + 1] === '\\'))
		{
			current += characters[++index];
			started = true;
		}
		else if(character === '"')
		{
			quoted = !quoted;
			started = true;
		}
		else if(character === ' ' && !quoted)
		{
			if(started)
			{
				parts.push(current);
			}
			current = '';
			started = false;
		}
		else
		{
			current += character;
			started = true;
		}
	}
	if(started)
	{
		parts.push(current);
	}
	return parts;
}

/**
 * @description Says what a stand-in should be given by a command, from the command's own text.
 * @param {string} commandLine - A command line as it is run.
 * @returns {Array<{tool: string, args: string[]}>} One call when the command starts a stand-in tool; else none.
 */
function expectedCalls(commandLine)
{
	const [tool, ...args] = splitArguments(commandLine);
	return STAND_IN_TOOLS.includes(tool) ? [{tool, args}] : [];
}

/**
 * @description Lists the commands a scope will run, after the skip rows and the substitutions. A skip row with
 *              `runsForReal: true` skips its command in the stand-in run only; the real run plans it like any other.
 * @param {Object} register - The parsed register.
 * @param {Object} scope - One of the register's scopes.
 * @param {string} repositoryRoot - Where the scope's guide path is resolved from.
 * @param {{real?: boolean}} [options] - `real: true` plans for the real run.
 * @returns {Array<{language: string, startLine: number, printed: string, command: string}>} The planned commands.
 */
function plannedCommands(register, scope, repositoryRoot, options = {})
{
	const content = fs.readFileSync(path.join(repositoryRoot, scope.guide), 'utf8');
	const skipRows = (register.skip || []).filter(row => row.scope === scope.id);
	const matched = new Set();
	const planned = [];
	for(const row of skipRows)
	{
		if(!String(row.provenBy || '').trim())
		{
			throw new Error(`skip row has no provenBy in ${scope.id}: ${row.command}`);
		}
		if(row.runsForReal !== undefined && typeof row.runsForReal !== 'boolean')
		{
			throw new Error(`skip row has a runsForReal that is not true or false in ${scope.id}: ${row.command}`);
		}
	}
	for(const block of extractTerminalBlocks(content, scope.guide, scope))
	{
		if(block.language === 'powershell')
		{
			throw new Error(`${scope.guide}:${block.startLine}: a powershell block is not allowed in a register scope`);
		}
		for(const printed of commandLines(block))
		{
			const row = skipRows.find(candidate => candidate.command === printed);
			if(row)
			{
				matched.add(row);
				if(!(row.runsForReal === true && options.real === true))
				{
					continue;
				}
			}
			planned.push({language: block.language, startLine: block.startLine, printed, command: substitute(printed, scope.substitutions)});
		}
	}
	for(const row of skipRows)
	{
		if(!matched.has(row))
		{
			throw new Error(`skip row matches no command in ${scope.id}: ${row.command}`);
		}
	}
	const lookalike = lookalikeTerminalBlocks(content, scope.guide, scope)[0];
	if(lookalike)
	{
		throw new Error(`${scope.guide}:${lookalike.startLine}: a ${lookalike.language} block is not a terminal block the runner knows; fence it shell, bat or bash`);
	}
	return planned;
}

/**
 * @description Names the terminals a system offers: the promised ones decide, the others are also tested.
 * @param {string} platform - A `process.platform` value.
 * @returns {{promised: string[], alsoTested: string[]}} Terminal names, promised first.
 */
function terminalsFor(platform)
{
	return TERMINALS[platform] || TERMINALS.linux;
}

/**
 * @description Says whether a block of this language is something a reader would run in this terminal.
 * @param {string} language - The block's fence language.
 * @param {string} terminal - cmd, powershell, pwsh, bash or zsh.
 * @param {boolean} legacy - True when the scope's bash blocks are all a Windows reader is offered.
 * @returns {boolean} True when the block runs there.
 */
function runsIn(language, terminal, legacy)
{
	if(language === 'shell' || legacy)
	{
		return true;
	}
	if(language === 'bat')
	{
		return terminal === 'cmd';
	}
	return UNIX_TERMINALS.includes(terminal);
}

/**
 * @description Runs one command line the way a reader's terminal would.
 * @param {string} terminal - cmd, powershell, pwsh, bash or zsh.
 * @param {string} command - The command line.
 * @param {string} workingDirectory - Where it runs.
 * @param {Object<string, string>} environment - The environment: hermetic for the stand-in run, the machine's own for the real run.
 * @param {string} scratchDirectory - Where a PowerShell script file may be written.
 * @returns {{status: number, stderr: string, output: string}} The exit status, what the command wrote to stderr, and
 *          everything it wrote, stdout then stderr.
 */
function runCommand(terminal, command, workingDirectory, environment, scratchDirectory)
{
	const options = {cwd: workingDirectory, env: environment, encoding: 'utf8'};
	let result;
	if(terminal === 'powershell' || terminal === 'pwsh')
	{
		const script = path.join(scratchDirectory, 'command.ps1');
		const scriptLines = [
			command, '$commandSucceeded = $?',
			'if ($LASTEXITCODE -ne $null -and $LASTEXITCODE -ne 0) { exit $LASTEXITCODE }',
			'if (-not $commandSucceeded) { exit 1 }', 'exit 0'
		];
		fs.writeFileSync(script, `${scriptLines.join('\n')}\n`);
		const name = terminal === 'pwsh' ? 'pwsh' : 'powershell.exe';
		result = spawnSync(resolveOnPath(name, process.env) || name, ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', script], options);
	}
	else
	{
		result = spawnSync(command, {...options, shell: SHELL_PROGRAMS[terminal]});
	}
	const stderr = (result.stderr || '') + (result.error ? result.error.message : '');
	return {status: result.status === null ? 1 : result.status, stderr, output: `${result.stdout || ''}${stderr}`};
}

/**
 * @description The last lines of what a command wrote, each indented to sit under the line that names its failure.
 * @param {string} output - Everything the command wrote.
 * @returns {string[]} At most OUTPUT_TAIL_LINES lines, blank edges dropped.
 */
function outputTail(output)
{
	const trimmed = output.trim();
	return trimmed ? trimmed.split(/\r?\n/).slice(-OUTPUT_TAIL_LINES).map(line => `    ${line}`) : [];
}

/**
 * @description Copies a tree for a stand-in run, leaving out the folders no guide line reads.
 * @param {string} sourceTree - The tree to copy.
 * @param {string} destination - Where the copy is made.
 */
function copyTree(sourceTree, destination)
{
	const source = path.resolve(sourceTree);
	fs.cpSync(source, destination, {recursive: true, filter: entry => entry === source || !FOLDERS_LEFT_OUT_OF_A_COPY.includes(path.basename(entry))});
}

/**
 * @description The commit a working copy stands at, which a restore later returns it to. A copy that carries
 *              anything beyond that commit, an edit, an untracked file or an ignored one, cannot be put back to what
 *              it was by git, so it has no starting commit and is copied afresh for every terminal instead.
 * @param {string} workingDirectory - The copy.
 * @returns {string|null} The commit, or null when the copy is not a clean git tree.
 */
function startingCommitOf(workingDirectory)
{
	if(!fs.existsSync(path.join(workingDirectory, '.git')))
	{
		return null;
	}
	const options = {cwd: workingDirectory, encoding: 'utf8'};
	const head = spawnSync('git', ['rev-parse', 'HEAD'], options);
	const status = spawnSync('git', ['status', '--porcelain', '--ignored', '--untracked-files=all'], options);
	return head.status === 0 && status.status === 0 && status.stdout.trim() === '' ? head.stdout.trim() : null;
}

/**
 * @description Puts a working copy back to what it was before a terminal ran a scope in it: the commit it started at,
 *              with every file a guide line made, changed or committed gone. Far cheaper than a fresh copy where
 *              files are slow to make, as they are on the Windows job.
 * @param {string} workingDirectory - The copy.
 * @param {string|null} startingCommit - From startingCommitOf; null for a copy that is not a git tree.
 * @returns {boolean} True when the copy is back; false when it cannot be, so the caller copies afresh.
 */
function restoreWorkingCopy(workingDirectory, startingCommit)
{
	if(!startingCommit)
	{
		return false;
	}
	const reset = spawnSync('git', ['reset', '--hard', '--quiet', startingCommit], {cwd: workingDirectory, encoding: 'utf8'});
	if(reset.status !== 0)
	{
		return false;
	}
	// The second f removes a nested repository a line may have made; nothing else is touched.
	return spawnSync('git', ['clean', '-ffdx', '--quiet'], {cwd: workingDirectory, encoding: 'utf8'}).status === 0;
}

/**
 * @description Makes a copy of the tree ready for a terminal's run: put back with git when it was used before, made
 *              afresh the first time and when git cannot put it back.
 * @param {string} sourceTree - The tree to copy.
 * @param {string} workingCopy - Where the copy lives for the whole scope.
 * @param {string|null|undefined} previousCommit - What the last preparation returned; undefined the first time.
 * @returns {string|null} The commit the copy now stands at, for the next preparation.
 */
function prepareWorkingCopy(sourceTree, workingCopy, previousCommit)
{
	if(previousCommit !== undefined && restoreWorkingCopy(workingCopy, previousCommit))
	{
		return previousCommit;
	}
	fs.rmSync(workingCopy, REMOVAL_OPTIONS);
	copyTree(sourceTree, workingCopy);
	return startingCommitOf(workingCopy);
}

/**
 * @description Runs every command of a scope that belongs in this terminal: the stand-in run in a copy of the tree,
 *              the real run in the tree itself, because its commands are meant to change the reader's folder.
 * @param {Object} register - The parsed register.
 * @param {Object} scope - The scope to run.
 * @param {string} terminal - The terminal to run it in.
 * @param {string} sourceTree - The tree: never written to by the stand-in run, which copies it unless given a copy;
 *        worked in by the real run.
 * @param {string} repositoryRoot - Where the scope's guide path is resolved from.
 * @param {{real?: boolean, workingCopy?: string}} [options] - `real: true` runs the actual tools on the machine's own
 *        PATH, with no stand-in and nothing expected, and runs the skip rows marked `runsForReal`. `workingCopy` is a
 *        copy the caller prepared and keeps; without it the stand-in run makes and removes one of its own.
 * @returns {Array<{printed: string, language: string, status: number, stderr: string, calls: Array, expected: Array}>} One result per command.
 */
function runScope(register, scope, terminal, sourceTree, repositoryRoot, options = {})
{
	const scratch = fs.mkdtempSync(path.join(os.tmpdir(), `docs-commands-${scope.id}-${terminal}-`));
	try
	{
		// The register is read before this run makes a copy of its own, so a register that names a heading the guide no
		// longer has costs nothing here; a copy the caller prepared is the caller's to remove.
		const planned = plannedCommands(register, scope, repositoryRoot, {real: options.real === true});
		let workingDirectory = path.resolve(sourceTree);
		if(options.real !== true)
		{
			workingDirectory = options.workingCopy || path.join(scratch, 'tree');
			if(!options.workingCopy)
			{
				copyTree(sourceTree, workingDirectory);
			}
		}
		// The stand-ins are written once per run; each command gets its own log through the environment.
		const standIns = options.real === true
			? null
			: installStandIns(path.join(scratch, 'stand-ins'), path.join(scratch, 'calls.log'), STAND_IN_TOOLS, {passThroughTools: PASS_THROUGH_TOOLS});
		const results = [];
		planned.forEach((command, index) =>
		{
			if(!runsIn(command.language, terminal, scope.legacy === true))
			{
				return;
			}
			if(options.real === true)
			{
				const outcome = runCommand(terminal, command.command, workingDirectory, process.env, scratch);
				results.push({
					printed: command.printed, language: command.language, status: outcome.status, stderr: outcome.stderr,
					output: outcome.output, calls: [], expected: []
				});
				return;
			}
			const logFile = path.join(scratch, `calls-${index}.log`);
			const outcome = runCommand(terminal, command.command, workingDirectory, {...standIns.environment, STAND_IN_LOG: logFile}, scratch);
			results.push({
				printed: command.printed, language: command.language, status: outcome.status, stderr: outcome.stderr,
				calls: readRecordedCalls(logFile), expected: expectedCalls(command.command)
			});
		});
		return results;
	}
	finally
	{
		fs.rmSync(scratch, REMOVAL_OPTIONS);
	}
}

/**
 * @description Lists what went wrong in one terminal's run of a scope: a command that failed, or a stand-in that was
 *              given something else than the guide's own text says.
 * @param {Array<{printed: string, status: number, stderr: string, output?: string, calls: Array, expected: Array}>} results - The
 *        results; a real run's carry `output`, whose last lines follow its failure, indented.
 * @returns {string[]} One sentence per problem, each starting with the printed command; empty when all is well.
 */
function problemsIn(results)
{
	const problems = [];
	for(const result of results)
	{
		if(result.status !== 0)
		{
			const heading = `${result.printed}: exit ${result.status} ${result.stderr.trim().split('\n')[0]}`.trim();
			problems.push([heading, ...outputTail(result.output || '')].join('\n'));
		}
		else if(result.expected.length > 0 && JSON.stringify(result.calls) !== JSON.stringify(result.expected))
		{
			const given = result.calls.length > 0 ? result.calls[0].args : [];
			problems.push(`${result.printed}: the stand-in was given ${JSON.stringify(given)}, and the guide says ${JSON.stringify(result.expected[0].args)}`);
		}
	}
	return problems;
}

/**
 * @description The problems that decide a terminal's verdict: all of them in a promised terminal; in PowerShell, all
 *              but the commands the register lists as known not to work there.
 * @param {string[]} problems - From problemsIn, each starting with the printed command.
 * @param {boolean} promised - Whether the terminal is a promised one.
 * @param {string[]} knownPowerShellFailures - The listed commands.
 * @returns {string[]} The deciding problems.
 */
function decidingProblems(problems, promised, knownPowerShellFailures)
{
	return problems.filter(problem => promised || !knownPowerShellFailures.some(command => problem.startsWith(`${command}:`)));
}

/**
 * @description Entry point. Returns the exit code: 0 all scopes pass, 1 a scope failed, 2 the arguments are unusable.
 * @param {string[]} argv - The arguments after the script name.
 * @param {string} [platform] - Overridable for tests.
 * @param {string} [repositoryRoot] - Where the scopes' guide paths are resolved from. Overridable for tests.
 * @returns {number} The exit code.
 */
function main(argv, platform = process.platform, repositoryRoot = REPOSITORY_ROOT)
{
	const valueOf = name => (argv.includes(name) ? argv[argv.indexOf(name) + 1] : undefined);
	const sourceTree = valueOf('--working-directory');
	if(!sourceTree)
	{
		console.error('Usage: node scripts/run-docs-commands.js --working-directory <tree> [--register <file>] [--real] [--scope <id>]');
		return 2;
	}
	const realPathOf = folder => (fs.existsSync(folder) ? fs.realpathSync.native(folder) : path.resolve(folder));
	if(realPathOf(sourceTree) === realPathOf(REPOSITORY_ROOT))
	{
		// The root holds the research clones, the org state and the scratch output: a copy of it never finishes.
		console.error('the runner never runs from its own repository root: give it a clone of the public tree as the working directory');
		return 2;
	}
	const register = JSON.parse(fs.readFileSync(valueOf('--register') || DEFAULT_REGISTER, 'utf8'));
	const terminals = terminalsFor(platform);
	const knownPowerShellFailures = (register.knownPowerShellFailures || []).map(row => row.command);
	const real = argv.includes('--real');
	const only = valueOf('--scope');
	if(only && !register.scopes.some(scope => scope.id === only))
	{
		console.error(`no scope named ${only}`);
		return 2;
	}
	const scopes = register.scopes.filter(scope => !only || scope.id === only);
	let failed = false;
	for(const scope of scopes)
	{
		// A scope that plans nothing proves nothing, and a heading renamed in the guide is how that happens. It is a
		// failure of the run, never a pass.
		if(plannedCommands(register, scope, repositoryRoot, {real}).length === 0)
		{
			console.log(`${scope.id}: FAIL`);
			console.log(`  ${scope.id}: no command was found under its headings in ${scope.guide}`);
			failed = true;
			continue;
		}
		const testedTerminals = real ? terminals.promised : [...terminals.promised, ...terminals.alsoTested];
		// One copy of the tree serves every terminal of the scope, put back with git in between.
		const scopeScratch = real ? null : fs.mkdtempSync(path.join(os.tmpdir(), `docs-commands-${scope.id}-`));
		const workingCopy = real ? undefined : path.join(scopeScratch, 'tree');
		let commit;
		try
		{
			for(const terminal of testedTerminals)
			{
				if(!real)
				{
					commit = prepareWorkingCopy(sourceTree, workingCopy, commit);
				}
				const promised = terminals.promised.includes(terminal);
				const results = runScope(register, scope, terminal, path.resolve(sourceTree), repositoryRoot, {real, workingCopy});
				const problems = decidingProblems(problemsIn(results), promised, knownPowerShellFailures);
				const label = real ? `${scope.id} in ${terminal} (real)` : `${scope.id} in ${terminal}${promised ? '' : ' (also tested)'}`;
				console.log(`${label}: ${problems.length === 0 ? 'pass' : 'FAIL'}`);
				problems.forEach(problem => console.log(`  ${problem}`));
				failed = failed || problems.length > 0;
			}
		}
		finally
		{
			if(scopeScratch)
			{
				fs.rmSync(scopeScratch, REMOVAL_OPTIONS);
			}
		}
	}
	return failed ? 1 : 0;
}

module.exports = {
	REPOSITORY_ROOT, DEFAULT_REGISTER, substitute, splitArguments, expectedCalls, plannedCommands, terminalsFor, runsIn, copyTree, startingCommitOf, restoreWorkingCopy,
	prepareWorkingCopy, runScope, problemsIn, decidingProblems, main
};

if(require.main === module)
{
	process.exit(main(process.argv.slice(2)));
}
