// SPDX-License-Identifier: BUSL-1.1
// @ts-check

import {createRequire} from 'node:module';

const require = createRequire(import.meta.url);
const kerndxPlugin = require('../../../scanner/eslint-plugin-kerndx');

export default [
	{
		plugins: {
			kerndx: kerndxPlugin
		}, files: ['**/*.js'], rules: {
			'kerndx/use-component-builder': 'error', 'kerndx/no-console-log': 'error', 'kerndx/enforce-component-naming': 'error'
		}
	}
];