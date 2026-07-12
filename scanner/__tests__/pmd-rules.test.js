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
	if(!fs.existsSync(target))
	{
		throw new Error(`Fixture does not exist: ${target}`);
	}
	try
	{
		const output = execSync(`pmd check -d "${target}" -R "${RULESET}" -f csv --no-cache`, {
			encoding: 'utf-8',
			stdio: [
				'pipe',
				'pipe',
				'pipe'
			]
		});
		return output;
	}
	catch(error)
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

	describe('KernSecurityBypassCallSite', () =>
	{
		it('fires once per bypass call site on the positive fixture', () =>
		{
			const output = runPmd('KernSecurityBypassCallSite-positive.cls');
			const hits = countRuleHits(output, 'KernSecurityBypassCallSite');
			expect(hits).toBeGreaterThanOrEqual(7);
		});

		it('is silent on the negative fixture', () =>
		{
			const output = runPmd('KernSecurityBypassCallSite-negative.cls');
			expect(countRuleHits(output, 'KernSecurityBypassCallSite')).toBe(0);
		});
	});

	describe('KernNoLegacyAssert', () =>
	{
		it('fires on each legacy System.assert variant', () =>
		{
			const output = runPmd('KernNoLegacyAssert-positive.cls');
			expect(countRuleHits(output, 'KernNoLegacyAssert')).toBe(3);
		});

		it('is silent on modern Assert methods', () =>
		{
			const output = runPmd('KernNoLegacyAssert-negative.cls');
			expect(countRuleHits(output, 'KernNoLegacyAssert')).toBe(0);
		});
	});

	describe('kerndx-hygiene-ruleset', () =>
	{
		const {HYGIENE_RULES} = require('../generate-hygiene-ruleset');
		const HYGIENE = path.resolve(__dirname, '..', 'kerndx-hygiene-ruleset.xml');

		it('fires every framework-agnostic rule and none of the framework-coupled ones', () =>
		{
			let output;
			try
			{
				output = execSync(`pmd check -d "${FIXTURES}" -R "${HYGIENE}" -f csv --no-cache`, {
					encoding: 'utf-8',
					stdio: [
						'pipe',
						'pipe',
						'pipe'
					]
				});
			}
			catch(error)
			{
				output = (error.stdout || '') + (error.stderr || '');
			}
			for(const rule of HYGIENE_RULES)
			{
				expect(countRuleHits(output, rule)).toBeGreaterThanOrEqual(1);
			}
			const allRules = [...fs.readFileSync(RULESET, 'utf8').matchAll(/<rule name="(Kern[^"]+)"/g)].map((m) => m[1]);
			const coupledRules = allRules.filter((rule) => !HYGIENE_RULES.includes(rule));
			expect(coupledRules.length).toBe(allRules.length - HYGIENE_RULES.length);
			for(const rule of coupledRules)
			{
				expect(countRuleHits(output, rule)).toBe(0);
			}
		});
	});

});

// These invariants never execute pmd, so they live OUTSIDE describeIfPmd and
// run everywhere — including CI runners without a pmd install. They are the
// enforcement the generator header and CLAUDE.md cite; skipping them would
// let hygiene-ruleset drift or a standard-category ref land silently.
describe('ruleset invariants (no pmd required)', () =>
{
	const {generateHygieneRuleset} = require('../generate-hygiene-ruleset');
	const HYGIENE = path.resolve(__dirname, '..', 'kerndx-hygiene-ruleset.xml');

	it('kerndx-hygiene-ruleset.xml is byte-identical to a fresh extraction from the full ruleset', () =>
	{
		const committed = fs.readFileSync(HYGIENE, 'utf8');
		const regenerated = generateHygieneRuleset(fs.readFileSync(RULESET, 'utf8'));
		expect(committed).toBe(regenerated);
	});

	// The rulesets must stay loadable on the PMD apex module the Salesforce
	// Code Analyzer bundles (7.25.0 as of engine 0.43.0). A reference into a
	// standard category can name a rule that only exists in a newer PMD, and
	// one unresolvable reference fails the WHOLE ruleset load. Guard: no
	// standard-category references anywhere — every rule is a KernDX XPath
	// definition or a reference to one.
	it.each([
		'kerndx-pmd-ruleset.xml',
		'kerndx-framework-ruleset.xml',
		'kerndx-hygiene-ruleset.xml',
		'combined-pmd-ruleset.xml',
		'subscriber-naming-pmd-ruleset.xml'
	])('%s contains no standard-category rule references', (file) =>
	{
		const xml = fs.readFileSync(path.resolve(__dirname, '..', file), 'utf8');
		expect(xml).not.toMatch(/ref="category\//);
	});
});

if(!pmdAvailable())
{
	// eslint-disable-next-line no-console
	console.warn('[pmd-rules.test] pmd CLI not found on PATH; PMD tests skipped. Install with: brew install pmd');
}
