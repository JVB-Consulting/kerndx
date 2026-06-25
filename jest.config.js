// SPDX-License-Identifier: BUSL-1.1

const { jestConfig } = require('@salesforce/sfdx-lwc-jest/config');

module.exports = {
    ...jestConfig,
    moduleNameMapper: {
        ...jestConfig.moduleNameMapper,
        '^lightning/flowSupport$': '<rootDir>/force-app/test/jest-mocks/lightning/flowSupport.js',
        '^lightning/modal$': '<rootDir>/force-app/test/jest-mocks/lightning/modal.js',
        '^c/componentBuilder$': '<rootDir>/force-app/test/jest-mocks/c/componentBuilder.js',
        // The sfdx-lwc-jest jsdom environment resolves `cheerio` to its browser ESM
        // build (bare `export`), which jest cannot load. Pin to the CommonJS *slim*
        // build: it provides the full DOM API (load/find/contents/text) the doc
        // converter uses, without cheerio's `undici`/fetch dependency (which needs
        // web globals jsdom omits). Tests that `jest.mock('cheerio')` still override this.
        '^cheerio$': '<rootDir>/node_modules/cheerio/dist/commonjs/slim.js'
    },
    modulePathIgnorePatterns: ['<rootDir>/.localdevserver', '<rootDir>/tmp/'],
    // release-testing/e2e/helpers/capture-overlay.smoke.test.js is a Playwright BROWSER smoke test
    // (it launches chromium) run via `node --test`, not a jest unit test — jest can't load it, so
    // its dir is excluded (alongside the Playwright e2e specs). The processor's pure-function unit
    // tests live in release-testing/__tests__ and run as normal jest under `npm run test:release`.
    testPathIgnorePatterns: ['/node_modules/', '/coverage/', '/release-testing/e2e/specs/', '/release-testing/e2e/helpers/', '<rootDir>/tmp/', '/__tests__/fixtures/'],
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
