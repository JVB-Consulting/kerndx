// SPDX-License-Identifier: BUSL-1.1
'use strict';

const {execSync, spawnSync} = require('child_process');
const fs = require('fs');
const path = require('path');

const RULESET = path.resolve(__dirname, '..', 'kerndx-pmd-ruleset.xml');
const FIXTURES = path.resolve(__dirname, 'pmd-fixtures');

function pmdAvailable()
{
	const probe = spawnSync('pmd', ['--version'], {stdio: 'ignore'});
	return probe.status === 0;
}

function runPmd(fixture)
{
	const target = path.join(FIXTURES, fixture);
	if (!fs.existsSync(target))
	{
		throw new Error(`Fixture does not exist: ${target}`);
	}
	try
	{
		const output = execSync(`pmd check -d "${target}" -R "${RULESET}" -f csv --no-cache`, {encoding: 'utf-8', stdio: ['pipe', 'pipe', 'pipe']});
		return output;
	}
	catch (error)
	{
		return (error.stdout || '') + (error.stderr || '');
	}
}

function countRuleHits(output, ruleName)
{
	const lines = output.split(/\r?\n/).filter(line => line.includes(`"${ruleName}"`));
	return lines.length;
}

const describeIfPmd = pmdAvailable() ? describe : describe.skip;

describeIfPmd('kerndx-pmd-ruleset', () =>
{
	describe('KernNoCoverageTheatre', () =>
	{
		it('fires on the positive fixture (all four theatre patterns)', () =>
		{
			const output = runPmd('KernNoCoverageTheatre-positive.cls');
			const hits = countRuleHits(output, 'KernNoCoverageTheatre');
			expect(hits).toBeGreaterThanOrEqual(4);
		});

		it('is silent on the negative fixture', () =>
		{
			const output = runPmd('KernNoCoverageTheatre-negative.cls');
			expect(countRuleHits(output, 'KernNoCoverageTheatre')).toBe(0);
		});
	});

	describe('KernCoverageExemptRequiresReason', () =>
	{
		it('fires whenever PMD.KernNoCoverageTheatre is suppressed', () =>
		{
			const output = runPmd('KernCoverageExemptRequiresReason-positive.cls');
			expect(countRuleHits(output, 'KernCoverageExemptRequiresReason')).toBeGreaterThanOrEqual(1);
		});

		it('is silent when no coverage-theatre suppression is present', () =>
		{
			const output = runPmd('KernCoverageExemptRequiresReason-negative.cls');
			expect(countRuleHits(output, 'KernCoverageExemptRequiresReason')).toBe(0);
		});
	});

	describe('KernNoInlineDmlInTests', () =>
	{
		it('fires on inline DML in non-allowlisted test classes', () =>
		{
			const output = runPmd('KernNoInlineDmlInTests-positive.cls');
			expect(countRuleHits(output, 'KernNoInlineDmlInTests')).toBeGreaterThanOrEqual(2);
		});

		it('is silent when TST_Builder and DML_Builder are used', () =>
		{
			const output = runPmd('KernNoInlineDmlInTests-negative.cls');
			expect(countRuleHits(output, 'KernNoInlineDmlInTests')).toBe(0);
		});

		it('is silent inside the allowlisted TST_Builder_TEST class', () =>
		{
			const output = runPmd('KernNoInlineDmlInTests-allowlisted.cls');
			expect(countRuleHits(output, 'KernNoInlineDmlInTests')).toBe(0);
		});
	});

	describe('KernNoBooleanExceptionThrown', () =>
	{
		it('fires on the positive fixture', () =>
		{
			const output = runPmd('KernNoBooleanExceptionThrown-positive.cls');
			expect(countRuleHits(output, 'KernNoBooleanExceptionThrown')).toBe(1);
		});

		it('is silent on the Assert.fail + isInstanceOfType fixture', () =>
		{
			const output = runPmd('KernNoBooleanExceptionThrown-negative.cls');
			expect(countRuleHits(output, 'KernNoBooleanExceptionThrown')).toBe(0);
		});
	});
});

if (!pmdAvailable())
{
	// eslint-disable-next-line no-console
	console.warn('[pmd-rules.test] pmd CLI not found on PATH; PMD tests skipped. Install with: brew install pmd');
}
