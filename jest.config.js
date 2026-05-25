// SPDX-License-Identifier: BUSL-1.1

const { jestConfig } = require('@salesforce/sfdx-lwc-jest/config');

module.exports = {
    ...jestConfig,
    moduleNameMapper: {
        ...jestConfig.moduleNameMapper,
        '^lightning/flowSupport$': '<rootDir>/force-app/test/jest-mocks/lightning/flowSupport.js',
        '^lightning/modal$': '<rootDir>/force-app/test/jest-mocks/lightning/modal.js',
        '^c/componentBuilder$': '<rootDir>/force-app/test/jest-mocks/c/componentBuilder.js'
    },
    modulePathIgnorePatterns: ['<rootDir>/.localdevserver', '<rootDir>/tmp/'],
    testPathIgnorePatterns: ['/node_modules/', '/coverage/', '/release-testing/e2e/specs/', '<rootDir>/tmp/', '/__tests__/fixtures/'],
    collectCoverageFrom: [
        'force-app/main/default/lwc/**/*.js',
        'scripts/**/*.js',
        'scanner/eslint-plugin-kerndx/**/*.js',
        'release-testing/runner/**/*.js',
        'release-testing/e2e/helpers/**/*.js',
        '!**/__tests__/**',
        '!**/*.test.js',
        '!**/*.spec.js',
        '!force-app/test/jest-mocks/**'
    ],
    coveragePathIgnorePatterns: [
        '/node_modules/',
        '/__tests__/',
        '/force-app/test/jest-mocks/'
    ]
};
