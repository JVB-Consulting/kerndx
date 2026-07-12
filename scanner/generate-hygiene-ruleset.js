// SPDX-License-Identifier: BUSL-1.1
'use strict';

/**
 * Generates scanner/kerndx-hygiene-ruleset.xml — the framework-agnostic tier.
 *
 * The hygiene ruleset carries the KernDX rules that assume nothing about the
 * codebase they scan: no KernDX classes, no managed package, no framework
 * adoption. It must be SELF-CONTAINED (full rule definitions, not
 * `<rule ref>` pointers) because PMD resolves relative rule references
 * against the process working directory, not the referencing file — a
 * ref-based subset breaks as soon as the ruleset is copied somewhere else
 * (the pipeline bundle installs it under `.kerndx-pipeline/scanner/`).
 *
 * To keep the copies from drifting, the definitions are extracted VERBATIM
 * from kerndx-pmd-ruleset.xml by this script, and a jest test
 * (scanner/__tests__/pmd-rules.test.js) fails whenever the committed output
 * differs from a fresh extraction.
 *
 * Regenerate with: node scanner/generate-hygiene-ruleset.js
 */

const fs = require('fs');
const path = require('path');

const SOURCE_RULESET = path.join(__dirname, 'kerndx-pmd-ruleset.xml');
const OUTPUT_RULESET = path.join(__dirname, 'kerndx-hygiene-ruleset.xml');

const HYGIENE_RULES = [
	'KernNoLegacyAssert',
	'KernNoCoverageTheatre',
	'KernNoBooleanExceptionThrown',
	'KernCoverageExemptRequiresReason',
	'KernSecurityBypassCallSite'
];

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

function generateHygieneRuleset(sourceXml)
{
	const rules = HYGIENE_RULES.map((name) => extractRule(sourceXml, name));
	return `<?xml version="1.0" encoding="UTF-8"?>
<!--
   KernDX Hygiene Ruleset - the framework-agnostic tier

   The subset of the KernDX PMD rules that does not require the KernDX
   framework: no KernDX classes or managed package are needed to adopt them.
   Point any PMD 7 (apex module 7.19.0 or newer) or the Salesforce Code
   Analyzer at this file to get the test-quality and security-review checks
   on their own. \`kerndx init\` scaffolds this ruleset when a repo does not
   build on the KernDX framework; repos that do should use
   kerndx-pmd-ruleset.xml instead, which contains every rule below plus the
   framework-integration rules.

   Two rules mention KernDX by name without requiring it:
   KernNoCoverageTheatre's fourth pattern fires only when the KernDX test
   builder is actually used, and KernSecurityBypassCallSite matches
   security-bypass method-name conventions (bypassSharing, withoutSecurity,
   withSystemMode, ...) wherever they appear - in a non-KernDX codebase a
   same-named method is flagged for the same review-and-acknowledge reason.

   GENERATED FILE - do not edit by hand. Each rule definition is extracted
   verbatim from kerndx-pmd-ruleset.xml by scanner/generate-hygiene-ruleset.js
   (regenerate with: node scanner/generate-hygiene-ruleset.js). A test keeps
   this file byte-identical to a fresh extraction, so the definitions cannot
   drift from the source ruleset.
-->
<ruleset name="KernDXHygiene"
         xmlns="http://pmd.sourceforge.net/ruleset/2.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://pmd.sourceforge.net/ruleset/2.0.0 https://pmd.sourceforge.io/ruleset_2_0_0.xsd">

   <description>
      KernDX rules that need no KernDX framework: no legacy System.assert
      methods, no coverage-theatre test patterns, a written reason on every
      coverage-rule suppression, no Boolean exceptionThrown try/catch
      testing, and a reviewed acknowledgement on every security-bypass call
      site (matched by method-name convention, framework or not).
   </description>

${rules.join('\n\n')}

</ruleset>
`;
}

function main()
{
	const sourceXml = fs.readFileSync(SOURCE_RULESET, 'utf8');
	const output = generateHygieneRuleset(sourceXml);
	fs.writeFileSync(OUTPUT_RULESET, output);
	console.log(`Wrote ${OUTPUT_RULESET} (${HYGIENE_RULES.length} rules)`);
}

if(require.main === module)
{
	main();
}

module.exports = {generateHygieneRuleset, HYGIENE_RULES};
