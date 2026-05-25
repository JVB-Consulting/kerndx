// SPDX-License-Identifier: MIT
'use strict';
const { scanCommand } = require('./scan.js');
const { namingCommand } = require('./naming.js');

async function runPreflight()
{
	await scanCommand({ ci: false });
	await namingCommand({ ci: false });
	return 0;
}

module.exports = { runPreflight };
