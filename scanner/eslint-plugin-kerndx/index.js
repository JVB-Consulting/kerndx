// SPDX-License-Identifier: MIT
/**
 * @fileoverview ESLint plugin for KernDX LWC framework conventions.
 */

'use strict';

const useComponentBuilder = require('./rules/use-component-builder');
const noConsoleLog = require('./rules/no-console-log');
const enforceComponentNaming = require('./rules/enforce-component-naming');
const noJestTheatre = require('./rules/no-jest-theatre');
const noMutatingSharedFixture = require('./rules/no-mutating-shared-fixture');
const noCoverageExemptWithoutReason = require('./rules/no-coverage-exempt-without-reason');
const noHardcodedUserText = require('./rules/no-hardcoded-user-text');

module.exports = {
	rules: {
		'use-component-builder': useComponentBuilder,
		'no-console-log': noConsoleLog,
		'enforce-component-naming': enforceComponentNaming,
		'no-jest-theatre': noJestTheatre,
		'no-mutating-shared-fixture': noMutatingSharedFixture,
		'no-coverage-exempt-without-reason': noCoverageExemptWithoutReason,
		'no-hardcoded-user-text': noHardcodedUserText
	}
};
