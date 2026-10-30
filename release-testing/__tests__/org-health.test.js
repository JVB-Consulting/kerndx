// SPDX-License-Identifier: Apache-2.0
const {describeOrgProblem, assertOrgIsUsable} = require('../e2e/helpers/org-health');

const ALIAS = 'AnyAlias';

describe('describeOrgProblem', () =>
{
	it('finds nothing wrong with an active scratch org', () =>
	{
		expect(describeOrgProblem(ALIAS, {status: 0, result: {status: 'Active', instanceUrl: 'https://example.my.salesforce.com'}})).toBeNull();
	});

	it('finds nothing wrong with a connected org that is not a scratch org', () =>
	{
		expect(describeOrgProblem(ALIAS, {status: 0, result: {connectedStatus: 'Connected', instanceUrl: 'https://example.my.salesforce.com'}})).toBeNull();
	});

	it('names a deleted scratch org, the day it expired and the variable to set', () =>
	{
		const problem = describeOrgProblem(ALIAS, {status: 0, result: {status: 'Deleted', expirationDate: '2026-09-17'}});

		expect(problem).toBe('The journeys are pointed at the org "AnyAlias", which cannot be opened: it is a scratch org whose status is Deleted, and it expired on '
				+ '2026-09-17. Set SF_SUBSCRIBER_ORG_ALIAS to the alias of an org that is open, then run again.');
	});

	it('names an expired scratch org that carries no expiry date', () =>
	{
		const problem = describeOrgProblem(ALIAS, {status: 0, result: {status: 'Expired'}});

		expect(problem).toContain('it is a scratch org whose status is Expired.');
		expect(problem).not.toContain('it expired on');
	});

	it('says the command line does not know the alias, with its reason and not the line that only names the flag', () =>
	{
		const display = {status: 2, name: 'NamedOrgNotFoundError', message: 'Parsing --target-org \n\tNo authorization information found for AnyAlias.\nSee more help'};

		expect(describeOrgProblem(ALIAS, display)).toContain('the Salesforce CLI does not know it (No authorization information found for AnyAlias.).');
	});

	it('names any other failure of the command line as what it is, never as an unknown alias', () =>
	{
		const display = {status: 1, name: 'RequestTimeoutError', message: 'The request timed out.\nTry again'};

		const problem = describeOrgProblem(ALIAS, display);

		expect(problem).toContain('the Salesforce CLI could not answer for it: RequestTimeoutError (The request timed out.).');
		expect(problem).not.toContain('does not know it');
	});

	it('says the command line could not answer when its error carries neither a name nor a reason', () =>
	{
		expect(describeOrgProblem(ALIAS, {status: 1})).toContain('the Salesforce CLI could not answer for it.');
	});

	it('names the connection status of an org that is not connected', () =>
	{
		expect(describeOrgProblem(ALIAS, {status: 0, result: {connectedStatus: 'RefreshTokenAuthError'}})).toContain('its connection status is RefreshTokenAuthError.');
	});

	it('says the command line gave no answer when there is nothing to read', () =>
	{
		expect(describeOrgProblem(ALIAS, null)).toContain('the Salesforce CLI gave no answer about it.');
	});

	it('says the command line gave no answer when the answer has no result', () =>
	{
		expect(describeOrgProblem(ALIAS, {status: 0})).toContain('the Salesforce CLI gave no answer about it.');
	});
});

describe('assertOrgIsUsable', () =>
{
	it('throws the problem as the error a run stops on', () =>
	{
		expect(() => assertOrgIsUsable(ALIAS, {status: 0, result: {status: 'Deleted'}})).toThrow('it is a scratch org whose status is Deleted.');
	});

	it('lets a usable org through', () =>
	{
		expect(() => assertOrgIsUsable(ALIAS, {status: 0, result: {status: 'Active'}})).not.toThrow();
	});
});
