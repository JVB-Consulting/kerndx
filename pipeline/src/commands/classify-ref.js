// SPDX-License-Identifier: MIT
'use strict';
const { loadConfig } = require('../lib/config-loader.js');
const { resolve } = require('../adapters/index.js');

/**
 * Classifies a git head ref using the configured CI adapter and returns
 * GITHUB_OUTPUT-style key=value lines.
 *
 * @param {object} opts
 * @param {string} opts.headRef - The git ref to classify.
 * @param {string} opts.configPath - Path to the .kerndx/config.yml file.
 * @returns {string} Newline-separated key=value lines ending with a trailing newline.
 */
function classifyRef({ headRef, configPath }) {
	const config = loadConfig(configPath);
	const adapter = resolve(config.ci_adapter, config.branches);
	const { action, label } = adapter.classifyHeadRef(headRef);
	const isBackprom = action === 'skip-scan' ? 'true' : 'false';
	return [
		`is_backprom=${isBackprom}`,
		`action=${action}`,
		`label=${label}`,
	].join('\n') + '\n';
}

module.exports = { classifyRef };
