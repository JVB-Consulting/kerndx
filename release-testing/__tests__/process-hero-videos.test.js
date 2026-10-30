// SPDX-License-Identifier: Apache-2.0
// Jest unit tests for the hero-video processor's pure helpers (budget gate + tool table). Lives in
// release-testing/__tests__ so it runs under `npm run test:release` alongside the other
// release-testing Jest suites, with coverage collected for release-testing/scripts.
const fs = require('fs');
const os = require('os');
const path = require('path');
const {checkBudget, findRawWebm, MAX_CLIP_BYTES, MAX_POSTER_BYTES, TOOLS} = require('../scripts/process-hero-videos');

describe('process-hero-videos helpers', () =>
{
	test('checkBudget passes a file under the hard limit and returns its size', () =>
	{
		const f = path.join(os.tmpdir(), `kern-budget-ok-${process.pid}.bin`);
		fs.writeFileSync(f, Buffer.alloc(1024));
		try
		{
			expect(checkBudget(f, MAX_CLIP_BYTES, 'ok.webm')).toBe(1024);
		}
		finally
		{
			fs.unlinkSync(f);
		}
	});

	test('checkBudget throws when a file exceeds the hard limit', () =>
	{
		const f = path.join(os.tmpdir(), `kern-budget-over-${process.pid}.bin`);
		fs.writeFileSync(f, Buffer.alloc(MAX_POSTER_BYTES + 1));
		try
		{
			expect(() => checkBudget(f, MAX_POSTER_BYTES, 'over.jpg')).toThrow(/over the/);
		}
		finally
		{
			fs.unlinkSync(f);
		}
	});

	test('findRawWebm finds the capture clip inside the org folder of the test results', () =>
	{
		const root = fs.mkdtempSync(path.join(os.tmpdir(), 'kern-raw-'));
		try
		{
			const folder = path.join(root, 'x-capture-chain-monitor');
			fs.mkdirSync(folder, {recursive: true});
			fs.writeFileSync(path.join(folder, 'video.webm'), Buffer.alloc(8));
			expect(findRawWebm('chain-monitor', root)).toBe(path.join(folder, 'video.webm'));
		}
		finally
		{
			fs.rmSync(root, {recursive: true, force: true});
		}
	});

	test('findRawWebm returns null when there is no capture folder', () =>
	{
		const root = fs.mkdtempSync(path.join(os.tmpdir(), 'kern-raw-'));
		try
		{
			fs.mkdirSync(path.join(root, 'x-release-chain-monitor'), {recursive: true});
			expect(findRawWebm('chain-monitor', root)).toBeNull();
			expect(findRawWebm('chain-monitor', path.join(root, 'missing'))).toBeNull();
		}
		finally
		{
			fs.rmSync(root, {recursive: true, force: true});
		}
	});

	test('RAW_DIR is the folder of the run\'s own org', () =>
	{
		const aliasBefore = process.env.SF_SUBSCRIBER_ORG_ALIAS;
		const rawDirectoryFor = (alias) =>
		{
			process.env.SF_SUBSCRIBER_ORG_ALIAS = alias;
			let rawDirectory;
			jest.isolateModules(() =>
			{
				rawDirectory = require('../scripts/process-hero-videos').RAW_DIR;
			});
			return rawDirectory;
		};
		try
		{
			expect(rawDirectoryFor('OrgA')).toMatch(/test-results[\\/]OrgA$/);
		}
		finally
		{
			if(aliasBefore === undefined)
			{
				delete process.env.SF_SUBSCRIBER_ORG_ALIAS;
			}
			else
			{
				process.env.SF_SUBSCRIBER_ORG_ALIAS = aliasBefore;
			}
		}
	});

	test('TOOLS covers the admin tools with neutral keys', () =>
	{
		const keys = TOOLS.map(t => t.key).sort();
		expect(keys).toEqual(['api-harness', 'chain-monitor', 'class-type-resolver', 'health-check', 'log-console', 'masking-advisor', 'scheduled-jobs', 'streaming-monitor']);
	});
});
