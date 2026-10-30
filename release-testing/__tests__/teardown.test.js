// SPDX-License-Identifier: Apache-2.0
const {run} = require('../scripts/consoles-at-volume/teardown');

describe('teardown', () =>
{
	it('deletes until nothing survives, unschedules the watchdog and records when', async() =>
	{
		const survivors = [9000, 0];
		const salesforce = {
			runApex: jest.fn((apex) =>
			{
				if(apex.includes('CronTrigger'))
				{
					return {logs: '', debugLines: ['VOLUME_WATCHDOG aborted=12']};
				}
				return {logs: '', debugLines: [`VOLUME_TEARDOWN chainRows=${survivors.length > 1 ? survivors.shift() : survivors[0]} logRows=0`]};
			})
		};
		const manifest = {runToken: 'abcdefab', actions: [{id: 'a'}], org: {namespacePrefix: ''}, watchdog: {jobNamePrefix: 'Consoles At Volume Watchdog'}, stages: {}};
		const result = await run({salesforce, manifest, options: {manifestPath: '/dev/null/m.json'}, log: () => {}});
		expect(result.tornDownAt).toBeDefined();
		expect(result.teardown).toEqual({passes: 2, survivingChainRows: 0, survivingLogRows: 0, watchdogJobsAborted: 12});
	});

	it('also removes the watchdog\'s own log entries for the rows it acted on, found by the rows\' ids', async() =>
	{
		// The watchdog writes those entries in its own sweep, under no id of the run, so only the record id finds them.
		const scripts = [];
		const salesforce = {
			runApex: jest.fn((apex) =>
			{
				scripts.push(apex);
				return {logs: '', debugLines: [apex.includes('CronTrigger') ? 'VOLUME_WATCHDOG aborted=0' : 'VOLUME_TEARDOWN chainRows=0 logRows=0']};
			})
		};
		const manifest = {
			runToken: 'abcdefab', actions: [{id: 'a'}], org: {namespacePrefix: ''}, watchdog: {jobNamePrefix: 'x'}, stages: {},
			synthesized: {stalledRows: ['fixture1'], startedStepRows: ['started1', 'started2']}, operatorWave: {deadJobStalls: [{executionId: 'dead1'}]}
		};
		await run({salesforce, manifest, options: {}, log: () => {}});
		const teardown = scripts.find((apex) => apex.includes('VOLUME_TEARDOWN'));
		expect(teardown).toContain('List<String> watchedRowIds = new List<String> {\'fixture1\', \'started1\', \'started2\', \'dead1\'};');
		expect(teardown).toContain('RecordId__c IN :watchedRowIds');
	});
});
