// SPDX-License-Identifier: Apache-2.0
/**
 * @description Answers one question before a tool installs a package into an org, deploys to it or deletes it: is the
 *              org it was handed the development org? The development org holds the framework deployed from source
 *              with no namespace; a managed install, a subscriber deploy or a delete there leaves it unusable.
 *
 *              The answer compares usernames, so the development org is recognised by its alias, by its username and
 *              by any second alias that points at it. The cheap comparison runs first: an org named exactly like the
 *              development org's alias is refused without starting the Salesforce CLI. Otherwise both names are
 *              resolved to a username with `sf org display --json`, of which only `result.username` is read.
 *
 *              Which way it fails, and why:
 *              - No development org on this machine (the alias is not declared, or the CLI does not know it, as on a
 *                build server): nothing is refused, because there is nothing here to protect.
 *              - The org it was handed cannot be resolved: nothing is refused; the tool's own next CLI call reports
 *                the unknown org, as it always has.
 *
 *              Run directly, it takes one or more org names and exits 1 with the refusal on stderr when any of them
 *              is the development org, or 0 otherwise, so a shell script can stop before it touches an org:
 *              `node scripts/lib/development-org-guard.js "$SF_SUBSCRIBER_ORG_ALIAS" || exit 1`
 */
'use strict';

const {startTool} = require('./start-tool');
const {getDevOrgAlias} = require('../dev-org-config');

const RESOLVE_TIMEOUT_MILLISECONDS = 60000;

/**
 * @description Reads the development org's alias from its one source, or null when none is declared on this machine
 *              (the public tree's configuration throws when KERN_DEV_ORG is unset).
 * @returns {string|null} The development org's alias, or null.
 */
function getDevelopmentOrgAlias()
{
	try
	{
		return getDevOrgAlias() || null;
	}
	catch(_)
	{
		return null;
	}
}

/**
 * @description Resolves an alias or a username to the org's username through the Salesforce CLI.
 * @param {string} org - An alias or a username.
 * @returns {string|null} The username in lower case (Salesforce usernames ignore case), or null when the CLI cannot
 *                        resolve it, cannot be started, or prints something that is not its JSON answer.
 */
function resolveUsername(org)
{
	const result = startTool('sf', ['org', 'display', '--target-org', org, '--json'], {encoding: 'utf8', timeout: RESOLVE_TIMEOUT_MILLISECONDS});
	if(!result || result.error || result.status !== 0)
	{
		return null;
	}
	const output = String(result.stdout || '');
	try
	{
		const answer = JSON.parse(output.slice(output.indexOf('{')));
		const username = answer && answer.result && answer.result.username;
		return username ? String(username).toLowerCase() : null;
	}
	catch(_)
	{
		return null;
	}
}

/**
 * @description Decides whether the org is the development org, by alias name first, then by username.
 * @param {string} org - The alias or username a tool is about to use.
 * @returns {boolean} True when the org is the development org.
 */
function isDevelopmentOrg(org)
{
	const developmentOrgAlias = getDevelopmentOrgAlias();
	if(!org || !developmentOrgAlias)
	{
		return false;
	}
	if(org === developmentOrgAlias)
	{
		return true;
	}
	const developmentUsername = resolveUsername(developmentOrgAlias);
	if(!developmentUsername)
	{
		return false;
	}
	if(org.toLowerCase() === developmentUsername)
	{
		return true;
	}
	return resolveUsername(org) === developmentUsername;
}

/**
 * @description Builds the sentence a tool prints when it refuses the development org.
 * @param {string} tool - What is refusing, such as "F02" or "This script".
 * @param {string} action - What it refuses to do, such as "install the package into".
 * @param {string} org - The org it was handed.
 * @returns {string} The refusal, naming the development org and why it is refused.
 */
function describeRefusal(tool, action, org)
{
	return `${tool} refuses to ${action} "${org}": it is the development org "${getDevelopmentOrgAlias()}", which holds the framework `
		+ 'deployed from source, and a managed install, subscriber deploy or delete there leaves it unusable. Point SF_SUBSCRIBER_ORG_ALIAS '
		+ '(or the variable you set) at a subscriber org.';
}

/**
 * @description The command-line entry: refuses when any org named is the development org.
 * @param {string[]} orgs - The org names, as the shell passed them.
 * @param {{write: function(string)}} errorStream - Where the refusal goes, normally process.stderr.
 * @returns {number} 1 when an org is the development org, otherwise 0.
 */
function main(orgs, errorStream)
{
	for(const org of orgs)
	{
		if(isDevelopmentOrg(org))
		{
			errorStream.write(describeRefusal('This script', 'use', org) + '\n');
			return 1;
		}
	}
	return 0;
}

if(require.main === module)
{
	process.exitCode = main(process.argv.slice(2), process.stderr);
}

module.exports = {getDevelopmentOrgAlias, resolveUsername, isDevelopmentOrg, describeRefusal, main};
