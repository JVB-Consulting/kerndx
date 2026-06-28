// SPDX-License-Identifier: BUSL-1.1
// Jest unit tests for the hero-video processor's pure helpers (budget gate + tool table). Lives in
// release-testing/__tests__ so it runs under `npm run test:release` alongside the other
// release-testing Jest suites, with coverage collected for release-testing/scripts.
const fs = require('fs');
const os = require('os');
const path = require('path');
const {checkBudget, MAX_CLIP_BYTES, MAX_POSTER_BYTES, TOOLS} = require('../scripts/process-hero-videos');

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

	test('TOOLS covers the admin tools with neutral keys', () =>
	{
		const keys = TOOLS.map(t => t.key).sort();
		expect(keys).toEqual(['api-harness', 'chain-monitor', 'health-check', 'masking-advisor', 'scheduled-jobs', 'streaming-monitor']);
	});
});
