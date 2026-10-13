// SPDX-License-Identifier: BUSL-1.1
'use strict';

const {execSync, spawnSync} = require('child_process');
const fs = require('fs');
const path = require('path');

const RULESET = path.resolve(__dirname, '..', 'kerndx-pmd-ruleset.xml');
const FIXTURES = path.resolve(__dirname, 'pmd-fixtures');
const {TIERS, generateTier} = require('../generate-ruleset-tiers');

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
		return execSync(`pmd check -d "${target}" -R "${RULESET}" -f csv --no-cache`, {
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
		it('fires once per sentinel: the Boolean flag, the captured Exception, and the inverse Assert.isNull', () =>
		{
			const output = runPmd('KernNoBooleanExceptionThrown-positive.cls');
			expect(countRuleHits(output, 'KernNoBooleanExceptionThrown')).toBe(3);
		});

		it('is silent on Assert.fail + isInstanceOfType, a bare must-not-throw call, and locals reassigned inside the catch', () =>
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

	describe('KernTriggerMustDelegate', () =>
	{
		it('fires once per top-level statement other than the delegating call, including a branch that wraps it', () =>
		{
			const output = runPmd('KernTriggerMustDelegate-positive.trigger');
			expect(countRuleHits(output, 'KernTriggerMustDelegate')).toBe(3);
		});

		it('is silent on a trigger body that only calls new TRG_Dispatcher().run()', () =>
		{
			const output = runPmd('KernTriggerMustDelegate-negative.trigger');
			expect(countRuleHits(output, 'KernTriggerMustDelegate')).toBe(0);
		});

		it('is silent on the namespaced form new kern.TRG_Dispatcher().run()', () =>
		{
			const output = runPmd('KernTriggerMustDelegate-negative-namespaced.trigger');
			expect(countRuleHits(output, 'KernTriggerMustDelegate')).toBe(0);
		});

		it('fires once, at the trigger itself, on a body with no statements at all', () =>
		{
			const output = runPmd('KernTriggerMustDelegate-positive-empty.trigger');
			expect(countRuleHits(output, 'KernTriggerMustDelegate')).toBe(1);
		});

		it('fires at the trigger itself on top of each statement when nothing delegates', () =>
		{
			const output = runPmd('KernTriggerMustDelegate-positive-no-delegation.trigger');
			expect(countRuleHits(output, 'KernTriggerMustDelegate')).toBe(3);
		});
	});

	describe('KernRestResourceNaming', () =>
	{
		it('fires on an @RestResource class outside the REST_ prefix', () =>
		{
			const output = runPmd('KernRestResourceNaming-positive.cls');
			expect(countRuleHits(output, 'KernRestResourceNaming')).toBe(1);
		});

		it('is silent on a REST_-prefixed @RestResource class', () =>
		{
			const output = runPmd('KernRestResourceNaming-negative.cls');
			expect(countRuleHits(output, 'KernRestResourceNaming')).toBe(0);
		});
	});

	describe('KernInvocableClassNeedsNoArgConstructor', () =>
	{
		it('fires on invocable-variable classes without a visible no-arg constructor', () =>
		{
			const output = runPmd('KernInvocableClassNeedsNoArgConstructor-positive.cls');
			expect(countRuleHits(output, 'KernInvocableClassNeedsNoArgConstructor')).toBe(2);
		});

		it('is silent when the no-arg constructor is explicit or implicit', () =>
		{
			const output = runPmd('KernInvocableClassNeedsNoArgConstructor-negative.cls');
			expect(countRuleHits(output, 'KernInvocableClassNeedsNoArgConstructor')).toBe(0);
		});
	});

	describe('KernLimitsThroughWrapper', () =>
	{
		it('fires once per Limits call, qualified or not, including inside an inner class that borrows the wrapper name', () =>
		{
			const output = runPmd('KernLimitsThroughWrapper-positive.cls');
			expect(countRuleHits(output, 'KernLimitsThroughWrapper')).toBe(5);
		});

		it('fires in a test class other than UTIL_Limits_TEST', () =>
		{
			const output = runPmd('KernLimitsThroughWrapper-positive-test.cls');
			expect(countRuleHits(output, 'KernLimitsThroughWrapper')).toBe(1);
		});

		it('is silent when every limit is read through UTIL_Limits, namespaced or not', () =>
		{
			const output = runPmd('KernLimitsThroughWrapper-negative.cls');
			expect(countRuleHits(output, 'KernLimitsThroughWrapper')).toBe(0);
		});

		it('is silent inside the UTIL_Limits wrapper class, inner classes included', () =>
		{
			const output = runPmd('KernLimitsThroughWrapper-allowlisted-wrapper.cls');
			expect(countRuleHits(output, 'KernLimitsThroughWrapper')).toBe(0);
		});

		it('is silent inside the wrapper test class UTIL_Limits_TEST', () =>
		{
			const output = runPmd('KernLimitsThroughWrapper-allowlisted-wrapper-test.cls');
			expect(countRuleHits(output, 'KernLimitsThroughWrapper')).toBe(0);
		});
	});

	describe('subset tiers', () =>
	{
		const allRules = [...fs.readFileSync(RULESET, 'utf8').matchAll(/<rule name="(Kern[^"]+)"/g)].map((m) => m[1]);

		it.each(Object.keys(TIERS))('%s tier fires every rule it carries and none of the others', (tierName) =>
		{
			const tier = TIERS[tierName];
			const tierFile = path.resolve(__dirname, '..', tier.outputFile);
			let output;
			try
			{
				output = execSync(`pmd check -d "${FIXTURES}" -R "${tierFile}" -f csv --no-cache`, {
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
			for(const rule of tier.rules)
			{
				expect(countRuleHits(output, rule)).toBeGreaterThanOrEqual(1);
			}
			const otherRules = allRules.filter((rule) => !tier.rules.includes(rule));
			expect(otherRules.length).toBe(allRules.length - tier.rules.length);
			for(const rule of otherRules)
			{
				expect(countRuleHits(output, rule)).toBe(0);
			}
		});
	});

});

// These invariants never execute pmd, so they live OUTSIDE describeIfPmd and
// run everywhere — including CI runners without a pmd install. They are the
// enforcement the generator header and CLAUDE.md cite; skipping them would
// let a generated tier drift, a file-path reference, or a standard-category
// ref land silently.
describe('ruleset invariants (no pmd required)', () =>
{
	it.each(Object.keys(TIERS))('%s tier output is byte-identical to a fresh extraction from the full ruleset', (tierName) =>
	{
		const tier = TIERS[tierName];
		const committed = fs.readFileSync(path.resolve(__dirname, '..', tier.outputFile), 'utf8');
		expect(committed).toBe(generateTier(fs.readFileSync(RULESET, 'utf8'), tier));
	});

	// PMD resolves a relative `<rule ref="some-file.xml/Rule">` against the
	// JVM's working directory, never against the referencing file. Salesforce
	// Code Analyzer 5.16.0 pins that directory to the engine's own install
	// folder, so a file-path reference cannot resolve there, and one
	// unresolvable reference fails the WHOLE ruleset load (exit 0, zero files
	// scanned). Guard: the tiered rulesets carry full definitions only.
	// combined-pmd-ruleset.xml is the IDE single-file and keeps its references
	// by design (it pulls in the per-subscriber naming ruleset, which cannot be
	// pre-inlined), so it is not listed here.
	it.each([
		'kerndx-pmd-ruleset.xml',
		'kerndx-hygiene-ruleset.xml',
		'kerndx-framework-ruleset.xml'
	])('%s contains no file-path rule references', (file) =>
	{
		const xml = fs.readFileSync(path.resolve(__dirname, '..', file), 'utf8');
		expect(xml).not.toMatch(/<rule\b[^>]*\bref=["'][^"']*\.xml/i);
	});

	// The rulesets must stay loadable on the PMD apex module the Salesforce
	// Code Analyzer bundles (7.26.0 as of pmd-engine 0.46.0, plugin 5.16.0). A
	// reference into a standard category can name a rule that only exists in a
	// newer PMD, and one unresolvable reference fails the WHOLE ruleset load.
	// Guard: no standard-category references anywhere — every rule is a KernDX
	// XPath definition or a reference to one.
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
