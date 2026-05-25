#!/usr/bin/env node
// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Package build script for Kern managed package.
 * Applies namespace prefixes, creates a package version, then reverts changes.
 *
 * Usage:
 *   node scripts/build-package.js                          # Build with defaults
 *   node scripts/build-package.js --dry-run                # Preview without changes
 *   node scripts/build-package.js --skip-validation        # Skip package validation
 *   node scripts/build-package.js --dev-org MyHub          # Custom dev hub
 *   node scripts/build-package.js --installation-key s3cr3t # Set installation key
 *   node scripts/build-package.js --no-resync              # Skip post-build org resync
 *   node scripts/build-package.js --package MyAcmePackage  # Build a non-default package alias
 *
 * @author Kern Framework
 */

const { execSync, spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const preparePackageBuild = require('./prepare-package-build');
const {getDevOrgAlias} = require('./dev-org-config');

// ============================================================================
// Configuration
// ============================================================================

const CONFIG = {
	DEFAULT_DEV_ORG: 'DevHub',
	DEFAULT_WAIT: 60,
	PACKAGE_NAME: 'Kern'
};

// ============================================================================
// Output Helpers
// ============================================================================

const colors = {
	reset: '\x1b[0m',
	red: '\x1b[31m',
	green: '\x1b[32m',
	yellow: '\x1b[33m',
	blue: '\x1b[34m',
	cyan: '\x1b[36m'
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
// CLI Argument Parsing
// ============================================================================

function parseArgs()
{
	const args = process.argv.slice(2);
	const options = {
		devOrg: CONFIG.DEFAULT_DEV_ORG,
		wait: CONFIG.DEFAULT_WAIT,
		skipValidation: false,
		installationKey: null,
		dryRun: false,
		verbose: false,
		help: false,
		noResync: false,
		packageAlias: CONFIG.PACKAGE_NAME,
		extraArgs: []
	};

	for (let i = 0; i < args.length; i++)
	{
		switch (args[i])
		{
			case '--dev-org':
			case '-o':
				options.devOrg = args[++i];
				break;
			case '--wait':
			case '-w':
				options.wait = parseInt(args[++i], 10);
				break;
			case '--skip-validation':
				options.skipValidation = true;
				break;
			case '--installation-key':
			case '-k':
				options.installationKey = args[++i];
				break;
			case '--dry-run':
				options.dryRun = true;
				break;
			case '--verbose':
				options.verbose = true;
				break;
			case '--no-resync':
				options.noResync = true;
				break;
			case '--package':
			case '-p':
				options.packageAlias = args[++i];
				break;
			case '--help':
			case '-h':
				options.help = true;
				break;
			default:
				options.extraArgs.push(args[i]);
		}
	}

	return options;
}

function showHelp()
{
	console.log(`
Kern Package Build

Usage:
  node scripts/build-package.js [options]

Options:
  --dev-org, -o <alias>          Dev hub org alias (default: ${CONFIG.DEFAULT_DEV_ORG})
  --wait, -w <minutes>           Build wait time in minutes (default: ${CONFIG.DEFAULT_WAIT})
  --skip-validation              Skip package validation
  --installation-key, -k <key>   Installation key (default: bypass)
  --dry-run                      Preview changes without building
  --verbose                      Show detailed output
  --no-resync                    Skip post-build CustomMetadata deploy to the dev org
                                 (used when building from a non-kern tree, e.g. distribution E2E)
  --package, -p <alias>          Package alias from sfdx-project.json (default: ${CONFIG.PACKAGE_NAME})
  --help, -h                     Show this help message

Any unknown arguments are forwarded to 'sf package version create'.

Examples:
  node scripts/build-package.js
  node scripts/build-package.js --dry-run --verbose
  node scripts/build-package.js --skip-validation
  node scripts/build-package.js --installation-key s3cr3t
  node scripts/build-package.js --package MyAcmePackage
`);
}

// ============================================================================
// Core Functions
// ============================================================================

/**
 * @description Checks for uncommitted changes in force-app/.
 * @returns {boolean} True if there are uncommitted changes.
 */
function hasUncommittedChanges()
{
	const output = execSync('git status --porcelain -- force-app/', { encoding: 'utf8' });
	return output.trim().length > 0;
}

/**
 * @description Applies namespace prefixes via the prepare script.
 * @param {Object} options - Options to pass to the prepare script.
 * @param {boolean} options.dryRun - Whether to skip actual modifications.
 * @param {boolean} options.verbose - Whether to show detailed output.
 * @returns {{totalModified: number, totalSkipped: number}} Results from the prepare script.
 */
function applyNamespacePrefixes(options)
{
	return preparePackageBuild.main({
		dryRun: options.dryRun,
		verbose: options.verbose
	});
}

/**
 * @description Creates a package version using the SF CLI.
 * @param {Object} options - Build options. The `packageAlias` field selects which
 *                           sfdx-project.json packageAliases entry to build under
 *                           (defaults to `CONFIG.PACKAGE_NAME`).
 * @returns {Promise<{code: number, output: string}>} Exit code and captured output.
 */
function createPackageVersion(options)
{
	const args = [
		'package', 'version', 'create',
		'--package', options.packageAlias,
		'--target-dev-hub', options.devOrg,
		'--wait', options.wait.toString(),
	];

	if (options.skipValidation)
	{
		args.push('--skip-validation');
	}
	else
	{
		args.push('--code-coverage');
	}

	if (options.installationKey)
	{
		args.push('--installation-key', options.installationKey);
	}
	else
	{
		args.push('--installation-key-bypass');
	}

	args.push(...options.extraArgs);

	return runCommand('sf', args);
}

/**
 * @description Reverts all changes in force-app/ to HEAD.
 * @param {boolean} verbose - Whether to show detailed output.
 */
function revertChanges(verbose)
{
	if (verbose)
	{
		logInfo('Reverting force-app/ changes...');
	}
	execSync('git checkout -- force-app/', { encoding: 'utf8' });
	if (verbose)
	{
		logSuccess('Changes reverted');
	}
}

/**
 * @description Deploys custom metadata and LWC meta files to the dev org to ensure
 * the org reflects committed state rather than accidentally deployed build artifacts.
 * @param {boolean} verbose - Whether to show detailed output.
 */
function resyncOrgMetadata(verbose)
{
	const metadataArgs = [
		'project', 'deploy', 'start',
		'-o', getDevOrgAlias(),
		'-m', 'CustomMetadata',
		'--ignore-conflicts'
	];

	if (verbose)
	{
		logInfo('Deploying committed metadata to org...');
	}

	execSync(`sf ${metadataArgs.join(' ')}`, { encoding: 'utf8', stdio: verbose ? 'inherit' : 'pipe' });
}

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
			stdio: ['inherit', 'pipe', 'pipe'],
			shell: true
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
			resolve({ code: code || 0, output });
		});

		proc.on('error', (err) =>
		{
			logError(`Failed to start command: ${err.message}`);
			resolve({ code: 1, output: err.message });
		});
	});
}

/**
 * @description Sets up signal handlers to revert changes on interrupt.
 * @param {boolean} verbose - Whether to show detailed output.
 * @param {boolean} noResync - Whether to skip the org metadata resync.
 */
function setupSignalHandlers(verbose, noResync)
{
	const handler = (signal) =>
	{
		logError(`\nReceived ${signal}, reverting changes...`);
		try
		{
			revertChanges(verbose);
			if (!noResync)
			{
				resyncOrgMetadata(verbose);
			}
		}
		catch (error)
		{
			logError(`Failed to revert changes: ${error.message}`);
		}
		process.exit(1);
	};

	process.on('SIGINT', handler);
	process.on('SIGTERM', handler);
}

// ============================================================================
// Main Entry Point
// ============================================================================

async function main()
{
	const options = parseArgs();

	if (options.help)
	{
		showHelp();
		return;
	}

	console.log('');
	log('========================================', colors.blue);
	log('  Kern Package Build', colors.blue);
	log('========================================', colors.blue);
	console.log('');
	logInfo(`Dev Hub:    ${options.devOrg}`);
	logInfo(`Package:    ${options.packageAlias}`);
	logInfo(`Wait:       ${options.wait} minutes`);
	logInfo(`Validation: ${options.skipValidation ? 'SKIPPED' : 'enabled'}`);
	logInfo(`Key:        ${options.installationKey ? '(custom)' : 'bypass'}`);
	logInfo(`Resync:     ${options.noResync ? 'SKIPPED' : 'enabled'}`);
	if (options.dryRun)
	{
		logInfo('Mode:       DRY RUN');
	}
	console.log('');

	const totalSteps = options.dryRun ? 1 : 4;
	let currentStep = 0;
	let prefixesApplied = false;

	// Check for uncommitted changes
	try
	{
		if (hasUncommittedChanges())
		{
			logError('Uncommitted changes detected in force-app/. Please commit or stash them first.');
			process.exit(1);
		}
	}
	catch (error)
	{
		logError(`Failed to check git status: ${error.message}`);
		process.exit(1);
	}

	setupSignalHandlers(options.verbose, options.noResync);

	// Step 1: Apply namespace prefixes
	logStep(++currentStep, totalSteps, 'Applying namespace prefixes...');

	let prefixResult;
	try
	{
		prefixResult = applyNamespacePrefixes(options);
		prefixesApplied = true;
	}
	catch (error)
	{
		logError(`Failed to apply namespace prefixes: ${error.message}`);
		process.exit(1);
	}

	logSuccess(`Namespace prefixes applied (${prefixResult.totalModified} files modified)`);
	console.log('');

	if (options.dryRun)
	{
		logInfo('Dry run complete. No package version created.');
		revertChanges(options.verbose);
		return;
	}

	// Step 2: Create package version
	let buildFailed = false;
	try
	{
		logStep(++currentStep, totalSteps, 'Creating package version...');
		const buildResult = await createPackageVersion(options);
		console.log('');

		if (buildResult.code !== 0)
		{
			logError('Package version creation failed');
			buildFailed = true;
		}
		else
		{
			logSuccess('Package version created');
		}
	}
	catch (error)
	{
		logError(`Package version creation error: ${error.message}`);
		buildFailed = true;
	}

	// Step 3: Update doc references to the newly-created package version.
	// Non-fatal — the package version is already created at this point, so
	// a doc-substitution failure should NOT roll back the build.
	// Subscriber clones of the source release don't ship update-package-refs.js
	// (it's a kern-maintainer-only tool that rewrites internal CHANGELOG +
	// Installation.md), so skip the step quietly when the module isn't present.
	if (!buildFailed)
	{
		const updatePackageRefsPath = path.join(__dirname, 'update-package-refs.js');
		if (!fs.existsSync(updatePackageRefsPath))
		{
			logStep(++currentStep, totalSteps, 'Updating doc references to new package version...');
			console.log('  (skipped — update-package-refs.js not present; this is a subscriber/release install)');
			console.log('');
		}
		else
		{
			logStep(++currentStep, totalSteps, 'Updating doc references to new package version...');
			try
			{
				const updatePackageRefs = require('./update-package-refs');
				const exitCode = updatePackageRefs.run([], {
					log: (m) => console.log('  ' + m),
					errlog: (m) => console.error('  ' + m)
				});
				if (exitCode === 0)
				{
					logSuccess('Doc references updated');
				}
				else
				{
					logError(`Doc reference update completed with warnings (exit=${exitCode}) — review the WARNING lines above; the build itself succeeded.`);
				}
			}
			catch (error)
			{
				logError(`Doc reference update error (non-fatal): ${error.message}`);
			}
			console.log('');
		}
	}
	else
	{
		// Build failed; skip the step number to keep the displayed count honest.
		currentStep++;
	}

	// Step 4: Revert changes and resync org (always runs)
	logStep(++currentStep, totalSteps, 'Reverting changes and resyncing org...');

	try
	{
		revertChanges(options.verbose);
		logSuccess('Local file changes reverted');
	}
	catch (error)
	{
		logError(`Failed to revert changes: ${error.message}`);
		logError('Manual revert required: git checkout -- force-app/');
	}

	if (!options.noResync)
	{
		try
		{
			resyncOrgMetadata(options.verbose);
			logSuccess('Org metadata resynced to committed state');
		}
		catch (error)
		{
			logError(`Failed to resync org metadata: ${error.message}`);
		}
	}

	if (buildFailed)
	{
		console.log('');
		logError('Build failed. Changes have been reverted.');
		process.exit(1);
	}

	console.log('');
	log('========================================', colors.blue);
	log('  Build Complete', colors.blue);
	log('========================================', colors.blue);
	console.log('');
}

// ============================================================================
// Module Exports (for testing)
// ============================================================================

module.exports = {
	CONFIG,
	parseArgs,
	showHelp,
	hasUncommittedChanges,
	applyNamespacePrefixes,
	createPackageVersion,
	revertChanges,
	resyncOrgMetadata,
	runCommand,
	setupSignalHandlers,
	colors,
	log,
	logStep,
	logSuccess,
	logError,
	logInfo,
	main
};

// Run if executed directly
if (require.main === module)
{
	main().catch((err) =>
	{
		logError(`Unexpected error: ${err.message}`);
		const noResync = process.argv.includes('--no-resync');
		try
		{
			revertChanges(true);
			if (!noResync)
			{
				resyncOrgMetadata(true);
			}
		}
		catch (revertError)
		{
			logError(`Failed to revert changes: ${revertError.message}`);
			logError('Manual revert required: git checkout -- force-app/');
		}
		process.exit(1);
	});
}
