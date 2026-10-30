// SPDX-License-Identifier: Apache-2.0
// Every piece of anonymous Apex the driver sends is a .apex file under templates/, readable and lintable as Apex in
// the IDE; this module fills the tokens a file names in its header comment and refuses to send a script with a
// token left unfilled. The two namespace tokens stay for the caller, which fills them from the org's probe.
const fs = require('fs');
const path = require('path');

const TEMPLATES_DIRECTORY = path.join(__dirname, 'templates');
const NAMESPACE_TOKENS = [
	'__APEX_NAMESPACE__',
	'__FIELD_NAMESPACE__'
];
const TOKEN = /__[A-Z][A-Z_]+__/g;
const LAUNCH_LINE = /VOLUME_LAUNCH stage=(\S+) action=(\S+) ordinal=(\d+) ids=(\S*) launched=(\d+)/;
const PREVIEW_LENGTH = 400;

/**
 * @description A value as an Apex string literal.
 *
 * @param {*} value The value.
 *
 * @returns {string}
 */
function apexString(value)
{
	return `'${String(value).replace(/\\/g, '\\\\').replace(/'/g, '\\\'')}'`;
}

/**
 * @description Values as the body of an Apex list literal, `'none'` when empty so the list is never empty.
 *
 * @param {Array} values The values.
 *
 * @returns {string}
 */
function apexStringList(values)
{
	return values.map(apexString).join(', ') || apexString('none');
}

/**
 * @description The template files, sorted.
 *
 * @returns {string[]}
 */
function listTemplates()
{
	return fs.readdirSync(TEMPLATES_DIRECTORY).filter((name) => name.endsWith('.apex')).sort();
}

/**
 * @description A template with its tokens filled.
 *
 * @param {string} name The file under templates/.
 * @param {object} values Token to value; every token the file carries must be here, the two namespace tokens aside.
 *
 * @returns {string} The script, with only the namespace tokens left.
 */
function renderTemplate(name, values = {})
{
	let text = fs.readFileSync(path.join(TEMPLATES_DIRECTORY, name), 'utf8');
	for(const [token, value] of Object.entries(values))
	{
		text = text.split(token).join(String(value));
	}
	const unfilled = [...new Set(text.match(TOKEN) || [])].filter((token) => !NAMESPACE_TOKENS.includes(token));
	if(unfilled.length > 0)
	{
		throw new Error(`${name} still carries ${unfilled.join(', ')}`);
	}
	return text;
}

/**
 * @description The launch line a launch script prints, parsed.
 *
 * @param {string[]} debugLines The script's debug lines.
 *
 * @returns {{stage: string, action: string, ordinal: number, ids: string[], launched: number}}
 */
function readLaunchLine(debugLines)
{
	const line = debugLines.find((candidate) => candidate.startsWith('VOLUME_LAUNCH'));
	const match = line ? line.match(LAUNCH_LINE) : null;
	if(!match)
	{
		throw new Error(`No VOLUME_LAUNCH line in: ${debugLines.join(' | ').slice(0, PREVIEW_LENGTH)}`);
	}
	return {stage: match[1], action: match[2], ordinal: Number(match[3]), ids: match[4] ? match[4].split(',') : [], launched: Number(match[5])};
}

module.exports = {TEMPLATES_DIRECTORY, renderTemplate, listTemplates, apexString, apexStringList, readLaunchLine};
