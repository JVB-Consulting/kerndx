#!/usr/bin/env node
// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Scratch Org Setup Script for Kern Development
 *
 * Creates a new scratch org, deploys source, and runs tests.
 *
 * Usage:
 *   node scripts/setup-scratch-org.js                    # Default: ${KERN_DEV_ORG}, 30 days
 *   node scripts/setup-scratch-org.js --alias myOrg      # Custom alias
 *   node scripts/setup-scratch-org.js --days 7           # Custom duration
 *   node scripts/setup-scratch-org.js --skip-tests       # Skip test execution
 *   node scripts/setup-scratch-org.js --open             # Open org when complete
 *
 * @author Kern Framework
 */

const {execSync, spawn} = require('child_process');
const path = require('path');
const {getDevOrgAlias} = require('./dev-org-config');

// ============================================================================
// Configuration
// ============================================================================

const CONFIG = {
	DEFAULT_ALIAS: getDevOrgAlias(), DEFAULT_DURATION: 30, SCRATCH_DEF: 'config/project-scratch-def.json'
};

// ============================================================================
// CLI Argument Parsing
// ============================================================================

function parseArgs()
{
	const args = process.argv.slice(2);
	const options = {
		alias: CONFIG.DEFAULT_ALIAS, days: CONFIG.DEFAULT_DURATION, skipTests: false, open: false, help: false
	};

	for(let i = 0; i < args.length; i++)
	{
		switch(args[i])
		{
			case '--alias':
			case '-a':
				options.alias = args[++i];
				break;
			case '--days':
			case '-d':
				options.days = parseInt(args[++i], 10);
				break;
			case '--skip-tests':
				options.skipTests = true;
				break;
			case '--open':
			case '-o':
				options.open = true;
				break;
			case '--help':
			case '-h':
				options.help = true;
				break;
			default:
				// Allow positional alias as first arg for convenience
				if(i === 0 && !args[i].startsWith('-'))
				{
					options.alias = args[i];
				}
		}
	}

	return options;
}

function showHelp()
{
	console.log(`
Kern Scratch Org Setup

Usage:
  node scripts/setup-scratch-org.js [options]

Options:
  --alias, -a <name>   Scratch org alias (default: ${CONFIG.DEFAULT_ALIAS})
  --days, -d <number>  Duration in days (default: ${CONFIG.DEFAULT_DURATION})
  --skip-tests         Skip running tests after deployment
  --open, -o           Open the org in browser when complete
  --help, -h           Show this help message

Examples:
  node scripts/setup-scratch-org.js
  node scripts/setup-scratch-org.js --alias myOrg --days 7
  node scripts/setup-scratch-org.js --skip-tests --open
`);
}

// ============================================================================
// Output Helpers
// ============================================================================

const colors = {
	reset: '\x1b[0m', red: '\x1b[31m', green: '\x1b[32m', yellow: '\x1b[33m', blue: '\x1b[34m', cyan: '\x1b[36m'
};

function log(message, color = colors.reset)
{
	console.log(`${color}${message}${colors.reset}`);
}

function logStep(step, total, message)
{
	log(`[${step}/${total}] ${message}`, colors.yellow);
}

function logSuccess(message)
{
	log(`✓ ${message}`, colors.green);
}

function logError(message)
{
	log(`✗ ${message}`, colors.red);
}

function logInfo(message)
{
	log(message, colors.cyan);
}

// ============================================================================
// Command Execution
// ============================================================================

/**
 * @description Executes a command and streams output in real-time.
 * @param {string} command - The command to execute.
 * @param {string[]} args - Command arguments.
 * @returns {Promise<{code: number, output: string}>} Exit code and captured output.
 */
function runCommand(command, args)
{
	return new Promise((resolve) =>
	{
		let output = '';
		const proc = spawn(command, args, {
			stdio: [
				'inherit',
				'pipe',
				'pipe'
			], shell: true
		});

		proc.stdout.on('data', (data) =>
		{
			const text = data.toString();
			process.stdout.write(text);
			output += text;
		});

		proc.stderr.on('data', (data) =>
		{
			const text = data.toString();
			process.stderr.write(text);
			output += text;
		});

		proc.on('close', (code) =>
		{
			resolve({code: code || 0, output});
		});

		proc.on('error', (err) =>
		{
			logError(`Failed to start command: ${err.message}`);
			resolve({code: 1, output: err.message});
		});
	});
}

/**
 * @description Checks if the scratch org definition file exists.
 * @returns {boolean} True if file exists.
 */
function checkPrerequisites()
{
	const fs = require('fs');
	const scratchDefPath = path.join(process.cwd(), CONFIG.SCRATCH_DEF);

	if(!fs.existsSync(scratchDefPath))
	{
		logError(`Scratch org definition not found: ${CONFIG.SCRATCH_DEF}`);
		return false;
	}

	return true;
}

// ============================================================================
// Main Steps
// ============================================================================

async function createScratchOrg(alias, days)
{
	const args = [
		'org',
		'create',
		'scratch',
		'--definition-file',
		CONFIG.SCRATCH_DEF,
		'--alias',
		alias,
		'--duration-days',
		days.toString(),
		'--set-default',
		'--wait',
		'10'
	];

	const result = await runCommand('sf', args);
	return result.code === 0;
}

async function deploySource(alias)
{
	const args = [
		'project',
		'deploy',
		'start',
		'--target-org',
		alias,
		'--wait',
		'30'
	];

	const result = await runCommand('sf', args);
	return result.code === 0;
}

async function runTests(alias)
{
	const args = [
		'apex',
		'run',
		'test',
		'--target-org',
		alias,
		'--test-level',
		'RunLocalTests',
		'--result-format',
		'human',
		'--code-coverage',
		'--wait',
		'30'
	];

	const result = await runCommand('sf', args);
	return result.code === 0;
}

async function openOrg(alias)
{
	const args = [
		'org',
		'open',
		'--target-org',
		alias
	];
	await runCommand('sf', args);
}

// ============================================================================
// Main Entry Point
// ============================================================================

async function main()
{
	const options = parseArgs();

	if(options.help)
	{
		showHelp();
		process.exit(0);
	}

	const totalSteps = options.skipTests ? 2 : 3;
	let currentStep = 0;

	console.log('');
	log('========================================', colors.blue);
	log('  Kern Scratch Org Setup', colors.blue);
	log('========================================', colors.blue);
	console.log('');
	logInfo(`Alias:    ${options.alias}`);
	logInfo(`Duration: ${options.days} days`);
	console.log('');

	// Check prerequisites
	if(!checkPrerequisites())
	{
		process.exit(1);
	}

	// Step 1: Create scratch org
	logStep(++currentStep, totalSteps, 'Creating scratch org...');
	const orgCreated = await createScratchOrg(options.alias, options.days);
	if(!orgCreated)
	{
		logError('Failed to create scratch org');
		process.exit(1);
	}
	logSuccess('Scratch org created');
	console.log('');

	// Step 2: Deploy source
	logStep(++currentStep, totalSteps, 'Deploying source...');
	const deployed = await deploySource(options.alias);
	if(!deployed)
	{
		logError('Deployment failed');
		process.exit(1);
	}
	logSuccess('Source deployed');
	console.log('');

	// Step 3: Run tests (unless skipped)
	let testsPassed = true;
	if(!options.skipTests)
	{
		logStep(++currentStep, totalSteps, 'Running tests...');
		testsPassed = await runTests(options.alias);
		console.log('');
	}

	// Summary
	log('========================================', colors.blue);
	log('  Summary', colors.blue);
	log('========================================', colors.blue);
	console.log('');
	logInfo(`Scratch Org: ${options.alias}`);

	if(options.skipTests)
	{
		log('Tests:       SKIPPED', colors.yellow);
	}
	else if(testsPassed)
	{
		logSuccess('Tests:       PASSED');
	}
	else
	{
		logError('Tests:       FAILED');
	}

	console.log('');
	log('Useful commands:', colors.cyan);
	console.log(`  sf org open -o ${options.alias}`);
	console.log(`  sf apex run test -o ${options.alias} -t ClassName_TEST --code-coverage --synchronous`);
	console.log(`  sf project deploy start -o ${options.alias}`);
	console.log('');

	// Open org if requested
	if(options.open)
	{
		logInfo('Opening org in browser...');
		await openOrg(options.alias);
	}

	process.exit(testsPassed ? 0 : 1);
}

// ============================================================================
// Module Exports (for testing)
// ============================================================================

module.exports = {
	CONFIG, parseArgs, showHelp, checkPrerequisites, createScratchOrg, deploySource, runTests, openOrg, runCommand, colors, log, logStep, logSuccess, logError, logInfo, main
};

// Run if executed directly
if(require.main === module)
{
	main().catch((err) =>
	{
		logError(`Unexpected error: ${err.message}`);
		process.exit(1);
	});
}
