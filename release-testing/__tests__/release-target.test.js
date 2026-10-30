// SPDX-License-Identifier: Apache-2.0
const path = require('path');

const {
	RECORDED_RESULTS_PATH, DEVELOPMENT_RESULTS_PATH, ReleaseTargetError, isReleaseTarget, resolveResultsPath, assertReleaseTarget
} = require('../runner/release-target');

const RESULTS_DIRECTORY = path.join(__dirname, '..', 'results');

// The shape `execSync` gives a failed `sf ... --json` call: the command line's own answer is on stdout.
function failedCommand(stdout)
{
	return Object.assign(new Error('Command failed: sf data query -o MyExpiredOrg\nsome stack of text'), {stdout});
}

// A run whose question to the org fails with the given error.
function refuseWith(error)
{
	return () => assertReleaseTarget('MyExpiredOrg', () =>
	{
		throw error;
	});
}

describe('release-target', () =>
{
	describe('the two results files', () =>
	{
		it('keeps the record of a release-testing cycle in current-run.json', () =>
		{
			expect(RECORDED_RESULTS_PATH).toBe(path.join(RESULTS_DIRECTORY, 'current-run.json'));
		});

		it('keeps every other run in development-run.json', () =>
		{
			expect(DEVELOPMENT_RESULTS_PATH).toBe(path.join(RESULTS_DIRECTORY, 'development-run.json'));
		});
	});

	describe('isReleaseTarget', () =>
	{
		it('accepts an org that gives the package a namespace prefix', () =>
		{
			expect(isReleaseTarget('kern__')).toBe(true);
		});

		it('turns away an org that gives the package no namespace', () =>
		{
			expect(isReleaseTarget('')).toBe(false);
		});

		it.each([
			[
				'a prefix that was never read',
				undefined
			],
			[
				'a null prefix',
				null
			],
			[
				'a prefix that is not text, even one that holds the right text',
				['kern__']
			]
		])('turns away %s, because the record is the file that must never be written by mistake', (description, namespacePrefix) =>
		{
			expect(isReleaseTarget(namespacePrefix)).toBe(false);
		});
	});

	describe('resolveResultsPath', () =>
	{
		it('sends a run against an org with the package installed to the recorded results', () =>
		{
			expect(resolveResultsPath('kern__')).toBe(RECORDED_RESULTS_PATH);
		});

		it('sends a run against any other org to the development results', () =>
		{
			expect(resolveResultsPath('')).toBe(DEVELOPMENT_RESULTS_PATH);
			expect(resolveResultsPath(undefined)).toBe(DEVELOPMENT_RESULTS_PATH);
		});
	});

	describe('assertReleaseTarget', () =>
	{
		it('lets a run against an org with the package installed go on', () =>
		{
			expect(() => assertReleaseTarget('MySubscriberOrg', () => 'kern__')).not.toThrow();
		});

		it('stops a run against an org without the package, as an error a caller can tell apart', () =>
		{
			expect(() => assertReleaseTarget('MyDevelopmentOrg', () => '')).toThrow(ReleaseTargetError);
		});

		it('names the org, says why, says nothing was written, and names the variable and the command that runs the journeys alone', () =>
		{
			const refuse = () => assertReleaseTarget('MyDevelopmentOrg', () => '');

			expect(refuse).toThrow('"MyDevelopmentOrg"');
			expect(refuse).toThrow('does not have the package installed');
			expect(refuse).toThrow('Nothing was written');
			expect(refuse).toThrow('SF_SUBSCRIBER_ORG_ALIAS');
			expect(refuse).toThrow('npm run test:e2e');
			expect(refuse).toThrow('development-run.json');
		});
	});

	describe('assertReleaseTarget when the org cannot be asked', () =>
	{
		it('stops the run as the same kind of error, so a caller prints a message and not a stack trace', () =>
		{
			expect(refuseWith(failedCommand(''))).toThrow(ReleaseTargetError);
		});

		it('names the org, says it could not be asked, says nothing was written and names the variable', () =>
		{
			const refuse = refuseWith(failedCommand(''));

			expect(refuse).toThrow('"MyExpiredOrg"');
			expect(refuse).toThrow('could not be asked whether it has the package installed');
			expect(refuse).toThrow('Nothing was written');
			expect(refuse).toThrow('SF_SUBSCRIBER_ORG_ALIAS');
		});

		it('repeats the first line of what the command line said about the failure', () =>
		{
			const answer = JSON.stringify({status: 1, name: 'NoOrgFound', message: 'No authorization information found for MyExpiredOrg.\nTry this: sf org login web'});

			expect(refuseWith(failedCommand(answer))).toThrow('(No authorization information found for MyExpiredOrg)');
			expect(refuseWith(failedCommand(answer))).not.toThrow('Try this');
		});

		it('reads the command line\'s answer through the colour codes a terminal can wrap it in', () =>
		{
			const answer = `\u001B[31m${JSON.stringify({status: 1, message: 'The org has expired'})}\u001B[0m`;

			expect(refuseWith(failedCommand(answer))).toThrow('(The org has expired)');
		});

		it('falls back to the first line of the error when the command line\'s answer holds no message', () =>
		{
			expect(refuseWith(failedCommand(JSON.stringify({status: 1})))).toThrow('(Command failed: sf data query -o MyExpiredOrg)');
		});

		it('ends the sentence once, whether or not what it repeats ended in a full stop', () =>
		{
			const answer = JSON.stringify({status: 1, message: 'HTTP response contains html content.'});

			expect(refuseWith(failedCommand(answer))).toThrow('installed (HTTP response contains html content). Nothing was written.');
		});

		it('lets a failure that is not a failed command through untouched, so a mistake in the code keeps its stack trace', () =>
		{
			const mistake = new TypeError('readNamespacePrefix is not a function');

			expect(refuseWith(mistake)).toThrow(mistake);
			expect(refuseWith(mistake)).not.toThrow(ReleaseTargetError);
		});

		it('falls back to the first line of the error when the command line gave no answer it can read', () =>
		{
			expect(refuseWith(failedCommand('not json'))).toThrow('(Command failed: sf data query -o MyExpiredOrg)');
			expect(refuseWith(failedCommand('not json'))).not.toThrow('some stack of text');
		});

		it('still says the org could not be asked when the failure carries no words at all', () =>
		{
			const refuse = refuseWith(Object.assign(new Error(''), {stdout: undefined}));

			expect(refuse).toThrow('could not be asked whether it has the package installed.');
		});
	});
});
