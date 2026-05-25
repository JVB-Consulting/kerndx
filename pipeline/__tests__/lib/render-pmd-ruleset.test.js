// SPDX-License-Identifier: MIT
'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const fs = require('node:fs');
const { execSync } = require('node:child_process');

const {
	renderPmdRuleset,
	deriveTemplateData,
	PmdRulesetError,
	DEFAULT_DOMAINS,
	DEFAULT_BRANDS,
	DEFAULT_LAYERS,
	DEFAULT_APEX_LENGTH,
	TEMPLATE_PATH,
} = require('../../src/lib/render-pmd-ruleset.js');

const REPO_ROOT = path.resolve(__dirname, '..', '..', '..');
const CHECKED_IN_XML = path.join(REPO_ROOT, 'scanner', 'subscriber-naming-pmd-ruleset.xml');

function xmllintAvailable() {
	try {
		execSync('xmllint --version', { stdio: 'ignore' });
		return true;
	} catch {
		return false;
	}
}

test('renderPmdRuleset with empty config renders defaults byte-identical to checked-in XML', () => {
	const rendered = renderPmdRuleset({});
	const checkedIn = fs.readFileSync(CHECKED_IN_XML, 'utf-8');
	assert.equal(
		rendered,
		checkedIn,
		'Rendered output drifted from scanner/subscriber-naming-pmd-ruleset.xml. ' +
		'Either the template changed without updating the checked-in XML, or the ' +
		'checked-in XML was hand-edited. Regenerate via the renderer.'
	);
});

test('renderPmdRuleset with no config (undefined) renders defaults', () => {
	const rendered = renderPmdRuleset();
	const checkedIn = fs.readFileSync(CHECKED_IN_XML, 'utf-8');
	assert.equal(rendered, checkedIn);
});

test('default constants match historical published values', () => {
	assert.deepEqual(DEFAULT_DOMAINS, ['SLS', 'ORD', 'PRD', 'SVC', 'SUB', 'MKT', 'CMN']);
	assert.deepEqual(DEFAULT_BRANDS, ['ACM', 'BTA']);
	assert.deepEqual(DEFAULT_LAYERS, ['SEL', 'TRG', 'FLOW', 'SVC', 'BATCH', 'SCHED', 'API', 'REST', 'DTO', 'CTRL', 'UTIL', 'LOG', 'IF', 'QRY', 'DML', 'MAP', 'TST']);
	assert.equal(DEFAULT_APEX_LENGTH, 40);
});

test('deriveTemplateData defaults round-trip cleanly', () => {
	const data = deriveTemplateData({});
	assert.equal(data.domainsPipe, 'SLS|ORD|PRD|SVC|SUB|MKT|CMN');
	assert.equal(data.brandsPipe, 'ACM|BTA');
	assert.equal(data.layersPipe, 'SEL|TRG|FLOW|SVC|BATCH|SCHED|API|REST|DTO|CTRL|UTIL|LOG|IF|QRY|DML|MAP|TST');
	assert.equal(data.apexLengthLimit, 40);
});

test('renderPmdRuleset with custom domains includes them in XPath', () => {
	const rendered = renderPmdRuleset({
		naming: {
			domains: ['INV', 'WMS', 'OPS'],
		},
	});
	assert.match(rendered, /\(INV\|WMS\|OPS\)_/);
	assert.match(rendered, /Domains: INV, WMS, OPS/);
	assert.doesNotMatch(rendered, /\(SLS\|ORD\|PRD/);
});

test('renderPmdRuleset with custom brands includes them in XPath', () => {
	const rendered = renderPmdRuleset({
		naming: {
			brands: ['AAA', 'BBB', 'CCC'],
		},
	});
	assert.match(rendered, /\(\(AAA\|BBB\|CCC\)_\)\?/);
	assert.match(rendered, /Brands:  AAA, BBB, CCC/);
});

test('renderPmdRuleset with empty brands array omits brand segment from XPath', () => {
	const rendered = renderPmdRuleset({
		naming: {
			brands: [],
		},
	});
	assert.match(rendered, /Brands:  \(none\)/);
	assert.doesNotMatch(rendered, /\(ACM\|BTA\)/);
	const apexClassRegexMatch = rendered.match(/'\^([^']+)'/);
	assert.ok(apexClassRegexMatch, 'expected to find Apex class XPath regex');
	assert.doesNotMatch(apexClassRegexMatch[1], /\?\(/);
});

test('renderPmdRuleset with custom apex_layers includes them in XPath', () => {
	const rendered = renderPmdRuleset({
		naming: {
			apex_layers: ['CTL', 'SRV', 'REPO'],
		},
	});
	assert.match(rendered, /\(CTL\|SRV\|REPO\)_/);
	assert.match(rendered, /Layer:   CTL, SRV, REPO/);
});

test('renderPmdRuleset with custom length_limit appears in error message and XPath', () => {
	const rendered = renderPmdRuleset({
		naming: {
			length_limits: { apex: 60 },
		},
	});
	assert.match(rendered, /exceeds the 60-character limit/);
	assert.match(rendered, /string-length\(@SimpleName\) > 60/);
});

test('renderPmdRuleset with full custom config renders all overrides', () => {
	const rendered = renderPmdRuleset({
		naming: {
			domains: ['INV', 'WMS'],
			brands: ['ACME'],
			apex_layers: ['CTL', 'SRV'],
			length_limits: { apex: 50 },
		},
	});
	assert.match(rendered, /Domains: INV, WMS/);
	assert.match(rendered, /Brands:  ACME/);
	assert.match(rendered, /Layers:  CTL, SRV/);
	assert.match(rendered, /exceeds the 50-character limit/);
	assert.match(rendered, /\^\(INV\|WMS\)_\(\(ACME\)_\)\?\(CTL\|SRV\)_/);
});

test('rendered XML is well-formed (xmllint --noout)', { skip: !xmllintAvailable() }, () => {
	const dir = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'pmd-render-'));
	const customXml = path.join(dir, 'custom.xml');
	fs.writeFileSync(customXml, renderPmdRuleset({
		naming: {
			domains: ['INV', 'WMS', 'OPS'],
			brands: ['AAA'],
			apex_layers: ['CTL', 'SRV', 'REPO'],
			length_limits: { apex: 60 },
		},
	}));
	const defaultXml = path.join(dir, 'default.xml');
	fs.writeFileSync(defaultXml, renderPmdRuleset({}));
	assert.doesNotThrow(() => execSync(`xmllint --noout "${defaultXml}"`, { stdio: 'pipe' }));
	assert.doesNotThrow(() => execSync(`xmllint --noout "${customXml}"`, { stdio: 'pipe' }));
});

test('renderPmdRuleset rejects domain codes with lowercase letters', () => {
	assert.throws(
		() => renderPmdRuleset({ naming: { domains: ['inv', 'WMS'] } }),
		(err) => err instanceof PmdRulesetError && /uppercase alphanumeric/.test(err.message)
	);
});

test('renderPmdRuleset rejects domain codes with special chars', () => {
	assert.throws(
		() => renderPmdRuleset({ naming: { domains: ['INV-1', 'WMS'] } }),
		(err) => err instanceof PmdRulesetError && /uppercase alphanumeric/.test(err.message)
	);
});

test('renderPmdRuleset rejects domain codes that are too short', () => {
	assert.throws(
		() => renderPmdRuleset({ naming: { domains: ['A', 'WMS'] } }),
		(err) => err instanceof PmdRulesetError && /2-5 characters/.test(err.message)
	);
});

test('renderPmdRuleset rejects domain codes that are too long', () => {
	assert.throws(
		() => renderPmdRuleset({ naming: { domains: ['LONGDOMAIN', 'WMS'] } }),
		(err) => err instanceof PmdRulesetError && /2-5 characters/.test(err.message)
	);
});

test('renderPmdRuleset rejects duplicate domain codes', () => {
	assert.throws(
		() => renderPmdRuleset({ naming: { domains: ['INV', 'WMS', 'INV'] } }),
		(err) => err instanceof PmdRulesetError && /duplicate entry/.test(err.message)
	);
});

test('renderPmdRuleset rejects domains as non-array', () => {
	assert.throws(
		() => renderPmdRuleset({ naming: { domains: 'INV,WMS' } }),
		(err) => err instanceof PmdRulesetError && /must be an array/.test(err.message)
	);
});

test('renderPmdRuleset rejects length_limit below 10', () => {
	assert.throws(
		() => renderPmdRuleset({ naming: { length_limits: { apex: 5 } } }),
		(err) => err instanceof PmdRulesetError && /between 10 and 80/.test(err.message)
	);
});

test('renderPmdRuleset rejects length_limit above 80', () => {
	assert.throws(
		() => renderPmdRuleset({ naming: { length_limits: { apex: 100 } } }),
		(err) => err instanceof PmdRulesetError && /between 10 and 80/.test(err.message)
	);
});

test('renderPmdRuleset ignores naming.enabled and other unrelated config fields', () => {
	const rendered = renderPmdRuleset({
		naming: {
			enabled: true,
			domains: ['INV'],
			field_prefix_rule: 'cross-domain-only',
			truncations: ['Mgmt -> Mgt'],
			suppressions_file: '.kerndx/naming-suppressions.json',
		},
		ci_adapter: { name: 'gearset' },
		package_dirs: ['force-app/main/default'],
	});
	assert.match(rendered, /\(INV\)_/);
});

test('TEMPLATE_PATH exists and is a file', () => {
	assert.ok(fs.existsSync(TEMPLATE_PATH), `template missing at ${TEMPLATE_PATH}`);
	assert.ok(fs.statSync(TEMPLATE_PATH).isFile());
});

test('renderPmdRuleset honors custom templatePath option', () => {
	const dir = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'pmd-render-'));
	const altTmpl = path.join(dir, 'alt.xml.eta');
	fs.writeFileSync(altTmpl, 'domains=<%= it.domainsCsv %>');
	const out = renderPmdRuleset({ naming: { domains: ['INV', 'WMS'] } }, { templatePath: altTmpl });
	assert.equal(out, 'domains=INV, WMS');
});
