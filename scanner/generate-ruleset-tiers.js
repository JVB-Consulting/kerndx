// SPDX-License-Identifier: Apache-2.0
'use strict';

/**
 * Generates the two subset tiers of the KernDX PMD ruleset from the full
 * ruleset, scanner/kerndx-pmd-ruleset.xml:
 *
 *   hygiene   -> scanner/kerndx-hygiene-ruleset.xml   (framework-agnostic tier)
 *   framework -> scanner/kerndx-framework-ruleset.xml (package-side tier)
 *
 * Both outputs must be SELF-CONTAINED (full rule definitions, never
 * `<rule ref>` pointers). PMD resolves a relative rule reference against
 * the JVM's working directory, not against the referencing file, so a
 * pointer-based subset breaks whenever that directory is not this repo's
 * root: when the file is copied elsewhere (the pipeline bundle installs it
 * under `.kerndx-pipeline/scanner/`), and on every Salesforce Code Analyzer
 * run since plugin 5.16.0 (August 2026), which pins PMD's working directory
 * to the engine's own install folder.
 *
 * To keep the copies from drifting, every definition is extracted VERBATIM
 * from the full ruleset by this script, and a jest test
 * (scanner/__tests__/pmd-rules.test.js) fails whenever a committed output
 * differs from a fresh extraction.
 *
 * Regenerate both files with: node scanner/generate-ruleset-tiers.js
 */

const fs = require('fs');
const path = require('path');

const SOURCE_RULESET = path.join(__dirname, 'kerndx-pmd-ruleset.xml');

const TIERS = {
	hygiene: {
		outputFile: 'kerndx-hygiene-ruleset.xml',
		rulesetName: 'KernDXHygiene',
		rules: [
			'KernNoLegacyAssert',
			'KernNoCoverageTheatre',
			'KernNoBooleanExceptionThrown',
			'KernCoverageExemptRequiresReason',
			'KernSecurityBypassCallSite',
			'KernInvocableClassNeedsNoArgConstructor'
		],
		header: `   KernDX Hygiene Ruleset - the framework-agnostic tier

   The subset of the KernDX PMD rules that does not require the KernDX
   framework: no KernDX classes or managed package are needed to adopt them.
   Point any PMD 7 (apex module 7.19.0 or newer) or the Salesforce Code
   Analyzer at this file to get the test-quality, security-review and
   Flow-invocable constructor checks on their own. \`kerndx init\` scaffolds
   this ruleset when a repo does not build on the KernDX framework; repos
   that do should use kerndx-pmd-ruleset.xml instead, which contains every
   rule below plus the framework-integration rules.

   Two rules mention KernDX by name without requiring it:
   KernNoCoverageTheatre's fourth pattern fires only when the KernDX test
   builder is actually used, and KernSecurityBypassCallSite matches
   security-bypass method-name conventions (bypassSharing, withoutSecurity,
   withSystemMode, ...) wherever they appear - in a non-KernDX codebase a
   same-named method is flagged for the same review-and-acknowledge reason.`,
		description: `      KernDX rules that need no KernDX framework: no legacy System.assert
      methods, no coverage-theatre test patterns, a written reason on every
      coverage-rule suppression, no Boolean exceptionThrown try/catch
      testing, a reviewed acknowledgement on every security-bypass call
      site (matched by method-name convention, framework or not), and a
      visible no-arg constructor on every class with @InvocableVariable
      fields.`
	},
	framework: {
		outputFile: 'kerndx-framework-ruleset.xml',
		rulesetName: 'KernDXFrameworkPackageSide',
		rules: [
			'KernTriggerMustDelegate',
			'KernRestResourceNaming',
			'KernInvocableClassNeedsNoArgConstructor',
			'KernNoLegacyAssert',
			'KernNoCoverageTheatre',
			'KernNoBooleanExceptionThrown',
			'KernCoverageExemptRequiresReason'
		],
		header: `   KernDX Framework Compliance Scanner - Framework Ruleset

   Rules applicable to the Kern framework package itself.

   The framework IMPLEMENTS the APIs that subscribers use instead of raw
   platform primitives. That means the package legitimately contains calls
   to \`Cache.Org.*\` (behind UTIL_Cache), \`Schema.getGlobalDescribe()\`
   (behind UTIL_SObjectDescribe), \`System.enqueueJob\` (behind
   UTIL_AsynchronousJobLauncher), raw \`Database.*\` DML (in DML_Builder /
   DML_Transaction), raw \`System.schedule\` (in SCHED_Base), etc. Rules
   that nag "use the framework API" are subscriber-scoped by definition -
   enforcing them on the framework itself is architecturally wrong.

   This ruleset only includes the *universal* rules: production-code
   hygiene (trigger delegation, REST resource naming, a visible no-arg
   constructor on Flow-invocable classes) and test quality.
   KernNoInlineSOQL, KernNoSystemDebug and KernNoRawEmail are EXCLUDED
   because the framework's own infrastructure classes necessarily use the
   primitives those rules wrap: QRY_Engine / SEL_* use inline SOQL by
   design, LOG_Engine uses System.debug as its own fallback, and
   UTIL_Email / FLOW_SendEmailInternal wrap Messaging.sendEmail.
   Subscribers should run the full kerndx-pmd-ruleset.xml, which includes
   all three. The other tiers:

     * kerndx-pmd-ruleset.xml - the full ruleset: everything here plus
       the rules that apply only to code built on the framework. Repos
       that build on the framework should run this one.
     * kerndx-hygiene-ruleset.xml - the framework-agnostic tier for
       repos that do not use the framework at all.`,
		description: `      Framework-internal rules. Universal hygiene that applies to both
      framework and subscriber code. Excludes the "use the framework API
      instead of the platform primitive" rules that the framework itself
      necessarily violates to implement those APIs.`
	}
};

function extractRule(sourceXml, ruleName)
{
	// The closing tag is anchored to a newline plus the ruleset's three-space
	// rule indentation, so a literal "</rule>" inside a description or CDATA
	// XPath (which sit at other indent levels) cannot truncate the extraction.
	const pattern = new RegExp(`   <rule name="${ruleName}"[\\s\\S]*?\\n   </rule>`);
	const match = sourceXml.match(pattern);
	if(!match)
	{
		throw new Error(`Rule not found in source ruleset: ${ruleName}`);
	}
	const openers = (match[0].match(/<rule /g) || []).length;
	if(openers !== 1)
	{
		throw new Error(`Extraction for ${ruleName} captured ${openers} rule openers — source formatting changed; fix extractRule before regenerating`);
	}
	return match[0];
}

function generateTier(sourceXml, tier)
{
	const rules = tier.rules.map((name) => extractRule(sourceXml, name));
	return `<?xml version="1.0" encoding="UTF-8"?>
<!--
${tier.header}

   GENERATED FILE - do not edit by hand. Each rule definition is extracted
   verbatim from kerndx-pmd-ruleset.xml by scanner/generate-ruleset-tiers.js
   (regenerate with: node scanner/generate-ruleset-tiers.js). A test keeps
   this file byte-identical to a fresh extraction, so the definitions cannot
   drift from the source ruleset.
-->
<ruleset name="${tier.rulesetName}"
         xmlns="http://pmd.sourceforge.net/ruleset/2.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://pmd.sourceforge.net/ruleset/2.0.0 https://pmd.sourceforge.io/ruleset_2_0_0.xsd">

   <description>
${tier.description}
   </description>

${rules.join('\n\n')}

</ruleset>
`;
}

function main()
{
	const sourceXml = fs.readFileSync(SOURCE_RULESET, 'utf8');
	for(const [tierName, tier] of Object.entries(TIERS))
	{
		const outputPath = path.join(__dirname, tier.outputFile);
		fs.writeFileSync(outputPath, generateTier(sourceXml, tier));
		console.log(`Wrote ${outputPath} (${tierName}: ${tier.rules.length} rules)`);
	}
}

if(require.main === module)
{
	main();
}

module.exports = {TIERS, extractRule, generateTier};
