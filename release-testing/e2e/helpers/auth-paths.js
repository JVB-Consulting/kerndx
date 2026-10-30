// SPDX-License-Identifier: Apache-2.0
// Where a run keeps its browser session files: the saved sign-in (state.json), the org's address (instance.json) and
// which kind of org it signed in to (run-target.json). Each org alias gets its own folder under .auth/, so two runs
// from one checkout against different orgs never read each other's session. With one shared folder, a second run's
// sign-in sent the first run's browser to the wrong org while its command-line calls still went to the right one.
const path = require('path');
const {getSubscriberOrgAlias} = require('../../runner/subscriber-config');

const AUTH_ROOT = path.join(__dirname, '..', '.auth');
// Where Playwright keeps each org's screenshots, videos and traces, one folder per org alias.
const TEST_RESULTS_ROOT = path.join(__dirname, '..', '..', 'test-results');
// Anything outside these characters becomes an underscore, so an alias can never name a folder outside .auth/.
const UNSAFE_FOLDER_CHARACTERS = /[^A-Za-z0-9._@-]/g;
const ONLY_DOTS = /^\.+$/;

/**
 * @description The folder name an org alias keeps its session files under.
 *
 * @param {string} orgAlias The org alias (or username) the run signs in to.
 *
 * @returns {string} The alias with every character a folder name should not carry replaced by an underscore.
 */
function authFolderName(orgAlias)
{
	const name = String(orgAlias ?? '').trim().replace(UNSAFE_FOLDER_CHARACTERS, '_');
	if(!name || ONLY_DOTS.test(name))
	{
		throw new Error(`The org alias "${orgAlias}" cannot name a folder for the session files; set SF_SUBSCRIBER_ORG_ALIAS to the org's alias`);
	}
	return name;
}

/**
 * @description The session files of one org.
 *
 * @param {string} orgAlias The org alias; the run's own alias (SF_SUBSCRIBER_ORG_ALIAS) when left out.
 *
 * @returns {{directory: string, statePath: string, instancePath: string, runTargetPath: string}} The org's folder and its three files.
 */
function authPathsFor(orgAlias = getSubscriberOrgAlias())
{
	const directory = path.join(AUTH_ROOT, authFolderName(orgAlias));
	return {
		directory,
		statePath: path.join(directory, 'state.json'),
		instancePath: path.join(directory, 'instance.json'),
		runTargetPath: path.join(directory, 'run-target.json')
	};
}

/**
 * @description The folder Playwright writes one org's screenshots, videos and traces to, so two runs against
 *              different orgs never write over each other's results.
 *
 * @param {string} orgAlias The org alias; the run's own alias (SF_SUBSCRIBER_ORG_ALIAS) when left out.
 *
 * @returns {string} The org's folder under release-testing/test-results/.
 */
function testResultsDirectoryFor(orgAlias = getSubscriberOrgAlias())
{
	return path.join(TEST_RESULTS_ROOT, authFolderName(orgAlias));
}

module.exports = {AUTH_ROOT, authFolderName, authPathsFor, testResultsDirectoryFor};
