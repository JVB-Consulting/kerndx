#!/usr/bin/env node
// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Full Documentation Build Orchestrator
 *
 * For CI/CD or manual full rebuilds. This script:
 * 1. Cleans existing output directories
 * 2. (Optional) Generates HTML via IcApexDoc if available
 * 3. Converts HTML to Markdown
 *
 * Cross-platform compatible (Windows, macOS, Linux).
 *
 * @author Kern Framework
 * @version 1.0.0
 *
 * @example
 * ```bash
 * # Full build (clean + convert existing HTML)
 * npm run docs:build
 *
 * # With IcApexDoc generation (requires ICAPEXDOC_HOME env var)
 * ICAPEXDOC_HOME=/path/to/IcApexDoc npm run docs:build
 * ```
 */

const fs = require('fs');
const path = require('path');
const {execSync} = require('child_process');
const {spawn} = require('child_process');
const {getDevOrgAlias} = require('./dev-org-config');

// ─────────────────────────────────────────────────────────────────────────────
// Configuration
// ─────────────────────────────────────────────────────────────────────────────

const DEFAULT_CONFIG = {
	/** ApexDoc HTML output directory */
	apexdocDir: './apexdoc',

	/** Markdown reference output directory */
	referenceDir: './docs/reference',

	/** Path to the SFDX project file */
	projectFile: './sfdx-project.json',

	/** Salesforce org alias for username resolution */
	orgAlias: getDevOrgAlias(),

	/** Documentation title */
	documentationTitle: 'Kern Apex Docs',

	/** Visibility filter */
	visibilityFilter: 'global',

	/** Strip namespace from generated docs */
	noNamespace: true,

	/** Include internal classes */
	includeInternal: true,

	/** Path to the conversion script */
	converterScript: path.join(__dirname, 'convert-icapexdoc-html-to-markdown.js'),

	/** Environment variable for IcApexDoc home */
	icApexDocHomeEnv: 'ICAPEXDOC_HOME',

	/** Default IcApexDoc home when env var is not set */
	defaultIcApexDocHome: path.resolve(__dirname, '../../../lib/IcApexDoc')
};

// ─────────────────────────────────────────────────────────────────────────────
// Logging Utilities
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Creates a logger with colored output
 * @param {boolean} [silent=false] - If true, suppress output
 * @returns {Object} Logger object
 */
function createLogger(silent = false)
{
	const noop = () =>
	{
	};
	if(silent)
	{
		return {info: noop, success: noop, warn: noop, error: noop, step: noop};
	}
	return {
		info: (msg) => console.log(`\x1b[36m[build]\x1b[0m ${msg}`),
		success: (msg) => console.log(`\x1b[32m[build]\x1b[0m ${msg}`),
		warn: (msg) => console.log(`\x1b[33m[build]\x1b[0m ${msg}`),
		error: (msg) => console.error(`\x1b[31m[build]\x1b[0m ${msg}`),
		step: (num, msg) => console.log(`\x1b[35m[${num}]\x1b[0m ${msg}`)
	};
}

// ─────────────────────────────────────────────────────────────────────────────
// Cross-Platform Utilities
// ─────────────────────────────────────────────────────────────────────────────

const isWindows = process.platform === 'win32';

/**
 * Recursively removes a directory (cross-platform)
 * @param {string} dirPath - Directory to remove
 * @param {Object} [fsModule=fs] - File system module (for testing)
 */
function removeDir(dirPath, fsModule = fs)
{
	if(fsModule.existsSync(dirPath))
	{
		fsModule.rmSync(dirPath, {recursive: true, force: true});
	}
}

/**
 * Gets the IcApexDoc binary path for the current platform
 * @param {string} icApexDocHome - Base path to IcApexDoc installation
 * @param {string} [platform=process.platform] - Platform string (for testing)
 * @returns {string} Full path to the binary
 */
function getIcApexDocBinary(icApexDocHome, platform = process.platform)
{
	const binName = platform === 'win32' ? 'apexdoc.bat' : 'apexdoc';
	return path.join(icApexDocHome, 'bin', binName);
}

// ─────────────────────────────────────────────────────────────────────────────
// DocsBuilder Class
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Orchestrates the documentation build process
 */
class DocsBuilder
{
	/**
	 * @param {Object} [options] - Configuration options
	 * @param {string} [options.apexdocDir] - ApexDoc output directory
	 * @param {string} [options.referenceDir] - Markdown output directory
	 * @param {string} [options.projectFile] - Path to SFDX project file
	 * @param {string} [options.orgAlias] - Salesforce org alias
	 * @param {string} [options.documentationTitle] - Documentation title
	 * @param {string} [options.visibilityFilter] - Visibility filter
	 * @param {string} [options.converterScript] - Path to converter script
	 * @param {string} [options.icApexDocHomeEnv] - Env var name for IcApexDoc
	 * @param {boolean} [options.silent] - Suppress logging
	 * @param {Object} [options.fs] - File system module (for testing)
	 * @param {Function} [options.spawnFn] - Custom spawn function (for testing)
	 * @param {Function} [options.execSyncFn] - Custom execSync function (for testing)
	 * @param {Object} [options.env] - Environment variables (for testing)
	 * @param {string} [options.platform] - Platform string (for testing)
	 */
	constructor(options = {})
	{
		this.config = {...DEFAULT_CONFIG, ...options};
		this.log = createLogger(options.silent);
		this.fs = options.fs || fs;
		this.spawnFn = options.spawnFn || spawn;
		this.execSyncFn = options.execSyncFn || execSync;
		this.env = options.env || process.env;
		this.platform = options.platform || process.platform;
	}

	/**
	 * Resolves the Salesforce username from the configured org alias
	 * @returns {string|null} The resolved username or null
	 */
	resolveOrgUsername()
	{
		try
		{
			const result = this.execSyncFn(`sf org display --target-org ${this.config.orgAlias} --json`, {encoding: 'utf8', timeout: 30000});
			const parsed = JSON.parse(result);
			return parsed.result?.username || null;
		}
		catch(err)
		{
			this.log.warn(`  Could not resolve username for org ${this.config.orgAlias}: ${err.message}`);
			return null;
		}
	}

	/**
	 * Step 1: Clean output directories
	 * Preserves curated index.md if it exists (contains hand-written content)
	 * @returns {{apexdocRemoved: boolean, referenceRemoved: boolean, indexPreserved: boolean}}
	 */
	cleanDirectories()
	{
		this.log.step(1, 'Cleaning output directories...');

		const apexdocExisted = this.fs.existsSync(this.config.apexdocDir);
		removeDir(this.config.apexdocDir, this.fs);
		this.log.info(`  Removed: ${this.config.apexdocDir}`);

		const referenceExisted = this.fs.existsSync(this.config.referenceDir);
		removeDir(this.config.referenceDir, this.fs);
		this.log.info(`  Removed: ${this.config.referenceDir}`);

		this.log.success('Clean complete');

		return {apexdocRemoved: apexdocExisted, referenceRemoved: referenceExisted};
	}

	/**
	 * Step 2: Generate HTML via IcApexDoc (if available)
	 * @returns {Promise<{attempted: boolean, success: boolean}>}
	 */
	generateHtml()
	{
		return new Promise((resolve) =>
		{
			this.log.step(2, 'Checking for IcApexDoc...');

			const icApexDocHome = this.env[this.config.icApexDocHomeEnv] || this.config.defaultIcApexDocHome;

			if(!icApexDocHome)
			{
				this.log.warn(`  ${this.config.icApexDocHomeEnv} not set and no default configured - skipping HTML generation`);
				this.log.info('  To enable: Set ICAPEXDOC_HOME environment variable');
				this.log.info('  Proceeding to convert existing HTML files...');
				resolve({attempted: false, success: false, reason: 'env_not_set'});
				return;
			}

			const binary = getIcApexDocBinary(icApexDocHome, this.platform);

			if(!this.fs.existsSync(binary))
			{
				this.log.warn(`  IcApexDoc binary not found: ${binary}`);
				this.log.info('  Proceeding to convert existing HTML files...');
				resolve({attempted: false, success: false, reason: 'binary_not_found'});
				return;
			}

			this.log.info(`  Found: ${binary}`);

			// Resolve Salesforce username from org alias
			const sfUsername = this.resolveOrgUsername();
			if(!sfUsername)
			{
				this.log.warn('  Could not resolve org username - skipping HTML generation');
				resolve({attempted: false, success: false, reason: 'org_username_not_resolved'});
				return;
			}

			this.log.info(`  Org: ${this.config.orgAlias} (${sfUsername})`);
			this.log.info('  Generating ApexDoc HTML...');

			// Ensure output directory exists
			this.fs.mkdirSync(this.config.apexdocDir, {recursive: true});

			// Build command arguments
			const args = [
				'-p',
				path.resolve(this.config.projectFile),
				'-o',
				path.resolve(this.config.apexdocDir),
				'-u',
				sfUsername,
				'-i',
				'-v',
				this.config.visibilityFilter,
				'-nn',
				'-t',
				this.config.documentationTitle
			];

			// Use shell on Windows for .bat files
			const spawnOptions = {
				stdio: 'inherit', cwd: process.cwd(), shell: this.platform === 'win32'
			};

			const child = this.spawnFn(binary, args, spawnOptions);

			child.on('close', (code) =>
			{
				if(code === 0)
				{
					this.log.success('HTML generation complete');
					resolve({attempted: true, success: true});
				}
				else
				{
					this.log.error(`IcApexDoc exited with code ${code}`);
					resolve({attempted: true, success: false, exitCode: code});
				}
			});

			child.on('error', (err) =>
			{
				this.log.error(`Failed to run IcApexDoc: ${err.message}`);
				resolve({attempted: true, success: false, error: err});
			});
		});
	}

	/**
	 * Step 3: Convert HTML to Markdown
	 * @returns {Promise<{attempted: boolean, success: boolean, fileCount?: number}>}
	 */
	convertToMarkdown()
	{
		return new Promise((resolve) =>
		{
			this.log.step(3, 'Converting HTML to Markdown...');

			// Check if there are HTML files to convert
			if(!this.fs.existsSync(this.config.apexdocDir))
			{
				this.log.warn(`  No ${this.config.apexdocDir} directory found`);
				this.log.info('  Generate HTML first, then run this script again');
				resolve({attempted: false, success: false, reason: 'no_apexdoc_dir'});
				return;
			}

			const htmlFiles = this.fs.readdirSync(this.config.apexdocDir)
			.filter(f => f.endsWith('.html'));

			if(htmlFiles.length === 0)
			{
				this.log.warn(`  No HTML files found in ${this.config.apexdocDir}`);
				this.log.info('  Generate HTML first, then run this script again');
				resolve({attempted: false, success: false, reason: 'no_html_files'});
				return;
			}

			this.log.info(`  Found ${htmlFiles.length} HTML files`);

			const startTime = Date.now();
			const child = this.spawnFn('node', [this.config.converterScript], {
				stdio: 'inherit', cwd: process.cwd()
			});

			child.on('close', (code) =>
			{
				const duration = Date.now() - startTime;

				if(code === 0)
				{
					this.log.success(`Conversion complete in ${(duration / 1000).toFixed(2)}s`);
					resolve({attempted: true, success: true, fileCount: htmlFiles.length, duration});
				}
				else
				{
					this.log.error(`Converter exited with code ${code}`);
					resolve({attempted: true, success: false, exitCode: code});
				}
			});

			child.on('error', (err) =>
			{
				this.log.error(`Failed to run converter: ${err.message}`);
				resolve({attempted: true, success: false, error: err});
			});
		});
	}

	/**
	 * Run the full build process
	 * @returns {Promise<{success: boolean, steps: Object}>}
	 */
	async build()
	{
		this.log.info('╔════════════════════════════════════════════════════════════╗');
		this.log.info('║          ApexDoc Documentation Builder                     ║');
		this.log.info('╚════════════════════════════════════════════════════════════╝');
		this.log.info('');

		const startTime = Date.now();
		const steps = {};

		try
		{
			// Step 1: Clean
			steps.clean = this.cleanDirectories();
			this.log.info('');

			// Step 2: Generate (optional)
			steps.generate = await this.generateHtml();
			this.log.info('');

			// Step 3: Convert
			steps.convert = await this.convertToMarkdown();
			this.log.info('');

			// Summary
			const totalTime = Date.now() - startTime;
			this.log.success('═══════════════════════════════════════════════════════════');
			this.log.success(`Build complete in ${(totalTime / 1000).toFixed(2)}s`);
			this.log.success('═══════════════════════════════════════════════════════════');

			return {success: true, steps, duration: totalTime};
		}
		catch(err)
		{
			this.log.error(`Build failed: ${err.message}`);
			return {success: false, steps, error: err};
		}
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// CLI Entry Point
// ─────────────────────────────────────────────────────────────────────────────

async function main()
{
	const builder = new DocsBuilder();
	const result = await builder.build();

	if(!result.success)
	{
		process.exit(1);
	}
}

// Run if called directly
if(require.main === module)
{
	main();
}

// ─────────────────────────────────────────────────────────────────────────────
// Exports for Testing
// ─────────────────────────────────────────────────────────────────────────────

module.exports = {
	DocsBuilder, createLogger, removeDir, getIcApexDocBinary, DEFAULT_CONFIG, isWindows
};
