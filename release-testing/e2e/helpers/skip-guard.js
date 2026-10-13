// SPDX-License-Identifier: BUSL-1.1
// For journeys that prove behaviour only the installed package has. On the development org they are skipped with
// the reason; on the subscriber pass, the proof of record, they run. RUNBOOK Phase 3 lists the journeys that use it.
const {namespacePrefix} = require('./sf-namespace');

const INSTALLED_PACKAGE_ONLY_KINDS = [
	'masked stack frames',
	'install-time permission writes',
	'the namespace echoed in page action references',
	'the upgrade leg',
	'version gates'
];

/**
 * @description Skips the journey on an org that holds the framework with no namespace.
 *
 * @param {object} test Playwright's `test`, or any object with `skip(condition, message)`.
 * @param {string} reason What only the installed package shows, in plain words.
 */
function skipUnlessPackaged(test, reason)
{
	test.skip(!namespacePrefix(), `Only the installed package shows this: ${reason}`);
}

module.exports = {skipUnlessPackaged, INSTALLED_PACKAGE_ONLY_KINDS};
