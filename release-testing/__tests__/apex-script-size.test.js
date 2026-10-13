// SPDX-License-Identifier: BUSL-1.1
// Anonymous Apex refuses a script over 32,000 characters with "Script too large", and the refusal is a compile error,
// so the script fails on every org. Each script the release tests send keeps a margin under that ceiling, because the
// namespace rewrite and the next fixture both add characters.
const fs = require('fs');
const path = require('path');

const SCRIPTS_DIRECTORY = path.join(__dirname, '..', 'scripts');
const ANONYMOUS_APEX_CEILING = 32_000;
const SCRIPT_CHARACTER_LIMIT = 31_000;

function listApexScripts(directory)
{
	return fs.readdirSync(directory, {withFileTypes: true}).flatMap((entry) =>
	{
		const entryPath = path.join(directory, entry.name);
		if(entry.isDirectory())
		{
			return listApexScripts(entryPath);
		}
		return entry.name.endsWith('.apex') ? [entryPath] : [];
	});
}

// Counted by character, as the platform counts, not by byte: a dash or an accented letter is one character. Every line
// ending counts as two characters, as a Windows checkout sends it, so a script that fits here fits on every machine.
function countCharacters(filePath)
{
	return [...fs.readFileSync(filePath, 'utf8').replace(/\r?\n/g, '\r\n')].length;
}

describe('release-testing Apex scripts', () =>
{
	const scripts = listApexScripts(SCRIPTS_DIRECTORY);

	it('finds the scripts it checks', () =>
	{
		expect(scripts.length).toBeGreaterThan(100);
		expect(scripts.map((scriptPath) => path.basename(scriptPath))).toEqual(expect.arrayContaining(['seed-log-console.apex', 'seed-log-console-actions.apex']));
	});

	it('keeps the margin below the platform ceiling', () =>
	{
		expect(SCRIPT_CHARACTER_LIMIT).toBeLessThan(ANONYMOUS_APEX_CEILING);
	});

	it(`keeps every script at ${SCRIPT_CHARACTER_LIMIT} characters or fewer, so anonymous Apex never refuses one as too large`, () =>
	{
		const oversized = scripts
		.map((scriptPath) => ({script: path.relative(SCRIPTS_DIRECTORY, scriptPath), characters: countCharacters(scriptPath)}))
		.filter(({characters}) => characters > SCRIPT_CHARACTER_LIMIT);

		expect(oversized).toEqual([]);
	});
});
