// SPDX-License-Identifier: BUSL-1.1
const {execSync} = require('child_process');
const path = require('path');

const ROOT = path.join(__dirname, '..', '..');
const CONFIG = path.join(__dirname, '..', 'e2e', 'playwright.config.js');

function runPhase3({headed = false, part = null} = {})
{
	const args = [
		'npx',
		'playwright',
		'test',
		'--config',
		CONFIG
	];

	if(headed)
	{
		args.push('--headed');
	}
	if(part)
	{
		args.push(part);
	}

	const command = args.join(' ');
	console.log(`Running: ${command}\n`);

	try
	{
		execSync(command, {
			encoding: 'utf8', stdio: 'inherit', timeout: 1800_000, cwd: ROOT
		});
		return true;
	}
	catch
	{
		return false;
	}
}

if(require.main === module)
{
	const args = process.argv.slice(2);
	const headed = args.includes('--headed');
	const partArg = args.find(a => a.startsWith('--part'));
	const part = partArg ? `part${partArg.split('=')[1]}-` : null;

	const success = runPhase3({headed, part});
	process.exit(success ? 0 : 1);
}

module.exports = {runPhase3};
