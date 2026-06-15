// SPDX-License-Identifier: BUSL-1.1
/**
 * Jest configuration for Node.js scripts (separate from LWC tests)
 */
module.exports = {
	displayName: 'scripts', testEnvironment: 'node', testMatch: ['<rootDir>/__tests__/**/*.test.js'], collectCoverageFrom: [
		'<rootDir>/*.js',
		'<rootDir>/research/validate-strategic-docs.js',
		'<rootDir>/research/validate-evidence.js',
		'!<rootDir>/jest.config.js'
	], coverageDirectory: '<rootDir>/__tests__/coverage', verbose: true
};
