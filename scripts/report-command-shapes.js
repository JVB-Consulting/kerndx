// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Compares the sf command shapes the shipped guides print with the shapes the real-org journey ran. A
 *              shape neither reached nor excused with a proof fails the report; a skip row for a shape no guide prints
 *              any more fails it too, so the table cannot go stale unnoticed.
 *              Usage: node scripts/report-command-shapes.js --journey-register <file>
 */
'use strict';

const fs = require('fs');
const path = require('path');
const {extractTerminalBlocks, commandLines, commandShape} = require('./lib/terminal-blocks');
const {plannedCommands, DEFAULT_REGISTER} = require('./run-docs-commands');
const {watchedGuides} = require('./terminal-blocks-changed');

const REPOSITORY_ROOT = path.resolve(__dirname, '..');
const GUIDE_FOLDERS = ['docs', 'bin'];
const JOURNEY_REGISTER = path.join(REPOSITORY_ROOT, 'release-testing', 'windows', 'real-org-journey-register.json');

/**
 * @description The shipped guides: every top-level docs/*.md, bin/README.md, and every guide a register names.
 * @param {string} repositoryRoot - The tree.
 * @param {Object} register - The docs command register.
 * @returns {string[]} Repository-relative paths.
 */
function shippedGuides(repositoryRoot, register)
{
	const guides = new Set(watchedGuides(register));
	for(const folder of GUIDE_FOLDERS)
	{
		for(const name of fs.readdirSync(path.join(repositoryRoot, folder)))
		{
			if(name.endsWith('.md') && (folder === 'docs' || name === 'README.md'))
			{
				guides.add(`${folder}/${name}`);
			}
		}
	}
	return [...guides].sort();
}

/**
 * @description The sf command shapes across guides, with how often each is printed.
 * @param {string[]} guides - Repository-relative guide paths.
 * @param {string} repositoryRoot - The tree.
 * @returns {Map<string, number>} Shape to count.
 */
function shapesIn(guides, repositoryRoot)
{
	const shapes = new Map();
	for(const guide of guides)
	{
		const content = fs.readFileSync(path.join(repositoryRoot, guide), 'utf8');
		for(const block of extractTerminalBlocks(content, guide))
		{
			for(const line of commandLines(block).filter(candidate => /^sf\s/.test(candidate)))
			{
				const shape = commandShape(line);
				shapes.set(shape, (shapes.get(shape) || 0) + 1);
			}
		}
	}
	return shapes;
}

/**
 * @description The verdict: which guide shapes the journey reached, which a row excuses, which neither, which rows
 *              are dead, and which shapes only the journey runs.
 * @param {{guideShapes: Map<string, number>, journeyShapes: Set<string>, skipShapes: Array<{shape: string}>}} input - The three sets.
 * @returns {{reached: string[], excused: string[], unreached: string[], dead: string[], journeyOnly: string[]}} The verdict.
 */
function report({guideShapes, journeyShapes, skipShapes})
{
	const excusedShapes = new Set(skipShapes.map(row => row.shape));
	const guide = [...guideShapes.keys()];
	return {
		reached: guide.filter(shape => journeyShapes.has(shape)),
		excused: guide.filter(shape => !journeyShapes.has(shape) && excusedShapes.has(shape)),
		unreached: guide.filter(shape => !journeyShapes.has(shape) && !excusedShapes.has(shape)),
		dead: [...excusedShapes].filter(shape => !guideShapes.has(shape)),
		journeyOnly: [...journeyShapes].filter(shape => !guideShapes.has(shape))
	};
}

/**
 * @description Entry point. Returns 0 when every guide shape is reached or excused and no row is dead, 1 otherwise,
 *              2 when the journey register cannot be read.
 * @param {string[]} argv - The arguments after the script name.
 * @param {string} [repositoryRoot] - The tree. Overridable for tests.
 * @param {string} [docsRegisterPath] - Where the docs command register is read from. Overridable for tests.
 * @returns {number} The exit code.
 */
function main(argv, repositoryRoot = REPOSITORY_ROOT, docsRegisterPath = DEFAULT_REGISTER)
{
	const registerPath = argv[argv.indexOf('--journey-register') + 1];
	if(!argv.includes('--journey-register') || !registerPath || !fs.existsSync(path.resolve(repositoryRoot, registerPath)))
	{
		console.error('Usage: node scripts/report-command-shapes.js --journey-register <file>');
		return 2;
	}
	const journeyRegister = JSON.parse(fs.readFileSync(path.resolve(repositoryRoot, registerPath), 'utf8'));
	const docsRegister = JSON.parse(fs.readFileSync(docsRegisterPath, 'utf8'));
	const guideShapes = shapesIn(shippedGuides(repositoryRoot, docsRegister), repositoryRoot);
	const journeyShapes = new Set();
	for(const scope of journeyRegister.scopes)
	{
		for(const command of plannedCommands(journeyRegister, scope, repositoryRoot))
		{
			if(/^sf\s/.test(command.command))
			{
				journeyShapes.add(commandShape(command.command));
			}
		}
	}
	for(const row of journeyRegister.skipShapes || [])
	{
		if(!String(row.reason || '').trim() || !String(row.provenBy || '').trim())
		{
			console.log(`skipShapes row for ${row.shape} needs a reason and a provenBy`);
			return 1;
		}
	}
	const verdict = report({guideShapes, journeyShapes, skipShapes: journeyRegister.skipShapes || []});
	const lines = ['| Shape | Printed | Verdict |', '|---|---|---|'];
	for(const [shape, count] of [...guideShapes.entries()].sort((a, b) => b[1] - a[1]))
	{
		const state = verdict.reached.includes(shape) ? 'reached' : verdict.excused.includes(shape) ? 'excused' : 'NOT REACHED';
		lines.push(`| ${shape} | ${count} | ${state} |`);
	}
	verdict.journeyOnly.forEach(shape => lines.push(`| ${shape} | 0 | journey only |`));
	verdict.dead.forEach(shape => lines.push(`| ${shape} | 0 | DEAD ROW |`));
	console.log(lines.join('\n'));
	if(process.env.GITHUB_STEP_SUMMARY)
	{
		fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, `## Documented sf command shapes and the real-org journey\n\n${lines.join('\n')}\n\n`);
	}
	return verdict.unreached.length === 0 && verdict.dead.length === 0 ? 0 : 1;
}

module.exports = {JOURNEY_REGISTER, shippedGuides, shapesIn, report, main};

if(require.main === module)
{
	process.exit(main(process.argv.slice(2)));
}
