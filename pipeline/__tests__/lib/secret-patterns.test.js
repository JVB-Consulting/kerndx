// SPDX-License-Identifier: MIT
'use strict';

/*
 * Unit tests for the shared, pure secret-pattern scanner.
 *
 * Fixture strings below are SYNTHETIC. The Tier-1 positives are deliberately
 * free of redaction sentinels so they exercise true detection; the suppression
 * tests add a sentinel/inline-allow and assert the same string is silenced.
 * This file lives under __tests__/, which the build/mirror secret gates skip
 * by path, so these synthetic shapes never trip the package's own gates.
 *
 * Prefix-bearing fixtures (Salesforce 5Aep…, Slack xoxb-…, ghp_…, AIza…) are
 * assembled by concatenation so the recognizable prefix is split from the body.
 * The runtime value is identical — the scanner sees the joined string — but no
 * contiguous secret literal appears in the source, so external push-protection
 * scanners (e.g. GitHub's) don't flag these synthetic fixtures.
 */

const test = require('node:test');
const assert = require('node:assert/strict');
const {
	SECRET_PATTERNS, DEFAULT_STOPWORDS, STRONG_SENTINELS, WEAK_STOPWORDS, scanText, redactSecret, summarizeFindings
} = require('../../src/lib/secret-patterns.js');

// ---- Synthetic positive fixtures (no stopwords) -------------------------

const FX = {
	authUrl: 'force://3MVG9SemV5D80oBfABCdefGHIjkl:1955279925675241719:5Aep' + '861TSESlnP65BVjJ8E0L0RfQ5kQ8aQ.aBcDeFgH@acme-dev-ed.my.salesforce.com', // kerndx-secret-allow — synthetic fixture
	authUrlEmptyCred: 'force://::5Aep' + '861TSESlnP65BVjJ8E0L0RfQ5kQ8aQ.aBcDeFgHiJ@acme-dev-ed.my.salesforce.com', // kerndx-secret-allow — synthetic fixture
	accessToken: '00D5f000000abcd!' + 'aB3xQ9zP'.repeat(12),       // 15-char org id + '!' + 96 token chars
	refreshToken: '5Aep' + '861TSESlnP65BVjJ8E0L0RfQ5kQ8aQ.aBcDeFgHiJkLmNoPqR', // kerndx-secret-allow — synthetic fixture
	privateKey: '-----BEGIN RSA PRIVATE KEY-----',                 // kerndx-secret-allow — synthetic fixture
	awsKey: 'AKIAZ7Q2W3E4R5T6Y7U2',                              // synthetic AKIA + 16 base32 chars (NOT the reserved …EXAMPLE key) — kerndx-secret-allow
	githubToken: 'ghp_' + 'a1B2c3D4e5f6G7h8I9j0kLmNoPqRsTuVwXyZ',     // ghp_ + 36
	githubPat: 'github_pat_' + '1A'.repeat(40),
	slackToken: 'xoxb-' + '1234567890-1234567890-aBcDeFgHiJkLmNoPqRsTuVwX', // kerndx-secret-allow — synthetic fixture
	googleKey: 'AIza' + 'A1b2C3d4E5f6G7h8I9j0KlMnOpQrStUvWxY',        // AIza + 35
	consumerSecretAssign: 'client_secret: aB3xQ9zPVconsumerSecretValue64charsLong0000000000000000abcd',
	envAssign: 'SF_ACCESS_TOKEN=aB3xQ9zPliteralTokenValue123456',
	jwt: 'eyJhbGciOiJSUzI1NiJ9.eyJpc3MiOiIzTVZHOWZ.aBcDeF1234567890signatureSeg',
	consumerKey: '3MVG9SemV5D80oBfABCdefGHIjklMnOpQrStUvWxYz0123456789'
};

// ---- Synthetic negative fixtures (must NOT be flagged at block tier) -----

const NEG = {
	orgId15: '00D5f000000abcd',
	orgId18: '00D5f000000abcdEAA',
	userId18: '005Q7000000abcdEAA',
	uuid: '8f3a2b1c-4d5e-6f70-8a9b-0c1d2e3f4a5b',
	sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
	awsDocExampleKey: 'AKIAIOSFODNN7EXAMPLE',                     // AWS's reserved documentation example — must NOT be flagged
	awsDocExampleSession: 'ASIAIOSFODNN7EXAMPLE',
	apiName: 'Account_Diagnostic_Field__c',
	ciTemplate: 'SF_ACCESS_TOKEN: ${{ secrets.SF_ACCESS_TOKEN }}',
	envVarRef: 'SFDX_AUTH_URL: $SFDX_AUTH_URL',
	docPlaceholder: 'force://<clientId>:<clientSecret>:<refreshToken>@<instanceUrl>'
};

function ruleIds(findings)
{
	return findings.map(f => f.ruleId);
}

function hasRule(findings, id)
{
	return findings.some(f => f.ruleId === id);
}

function blockingFindings(findings)
{
	return findings.filter(f => f.tier === 'block');
}

// ---- API surface --------------------------------------------------------

test('exports the documented surface', () =>
{
	assert.ok(Array.isArray(SECRET_PATTERNS), 'SECRET_PATTERNS is an array');
	assert.ok(SECRET_PATTERNS.length > 0, 'SECRET_PATTERNS is non-empty');
	assert.ok(Array.isArray(DEFAULT_STOPWORDS), 'DEFAULT_STOPWORDS is an array');
	assert.equal(typeof scanText, 'function');
	assert.equal(typeof redactSecret, 'function');
	assert.equal(typeof summarizeFindings, 'function');
});

test('every pattern declares id, label, tier and a RegExp', () =>
{
	const tiers = new Set([
		'block',
		'advisory'
	]);
	const ids = new Set();
	for(const p of SECRET_PATTERNS)
	{
		assert.equal(typeof p.id, 'string', 'pattern has string id');
		assert.ok(!ids.has(p.id), `pattern id is unique: ${p.id}`);
		ids.add(p.id);
		assert.equal(typeof p.label, 'string', `${p.id} has a label`);
		assert.ok(tiers.has(p.tier), `${p.id} tier is block|advisory`);
		assert.ok(p.regex instanceof RegExp, `${p.id} carries a RegExp`);
		assert.ok(p.regex.flags.includes('g'), `${p.id} regex is global (for scanning)`);
	}
});

// ---- Tier-1 positives: must be detected as blocking ---------------------

test('detects an SFDX auth URL as blocking', () =>
{
	const f = scanText(FX.authUrl);
	assert.ok(hasRule(f, 'sfdx-auth-url'), 'auth url flagged');
	assert.ok(blockingFindings(f).length >= 1, 'auth url is blocking');
});

test('detects an empty-credential auth URL (real refresh token, PlatformCLI-style)', () =>
{
	const f = scanText(FX.authUrlEmptyCred);
	assert.ok(hasRule(f, 'sfdx-auth-url'), 'empty-cred auth url still flagged');
});

test('detects a Salesforce access token (00D…!…) as blocking', () =>
{
	const f = scanText(FX.accessToken);
	assert.ok(hasRule(f, 'salesforce-access-token'), 'access token flagged');
	assert.ok(blockingFindings(f).length >= 1);
});

test('detects a refresh token as blocking', () =>
{
	const f = scanText(FX.refreshToken);
	assert.ok(hasRule(f, 'salesforce-refresh-token'));
	assert.ok(blockingFindings(f).length >= 1);
});

test('detects a private key header as blocking', () =>
{
	const f = scanText(FX.privateKey);
	assert.ok(hasRule(f, 'private-key'));
	assert.ok(blockingFindings(f).length >= 1);
});

test('detects prefixed cloud credentials (AWS, GitHub, Slack, Google) as blocking', () =>
{
	assert.ok(hasRule(scanText(FX.awsKey), 'aws-access-key'), 'AWS');
	assert.ok(hasRule(scanText(FX.githubToken), 'github-token'), 'GitHub PAT');
	assert.ok(hasRule(scanText(FX.githubPat), 'github-token'), 'GitHub fine-grained PAT');
	assert.ok(hasRule(scanText(FX.slackToken), 'slack-token'), 'Slack');
	assert.ok(hasRule(scanText(FX.googleKey), 'google-api-key'), 'Google');
	for(const fx of [
		FX.awsKey,
		FX.githubToken,
		FX.slackToken,
		FX.googleKey
	])
	{
		assert.ok(blockingFindings(scanText(fx)).length >= 1);
	}
});

// ---- Tier-2: keyword-anchored / contextual ------------------------------
// Keyword-anchored assignments are ADVISORY, not block: telling a real
// credential from a reference/placeholder/path needs a value judgement that
// proved an arms race, so they surface for review rather than gating CI.

test('flags a client_secret assignment as ADVISORY (keyword-anchored, not a hard block)', () =>
{
	const f = scanText(FX.consumerSecretAssign);
	assert.ok(hasRule(f, 'salesforce-consumer-secret'), 'consumer secret flagged');
	assert.equal(blockingFindings(f).length, 0, 'keyword-anchored consumer secret is advisory, never block');
});

test('flags an SF credential env-var assigned a literal value as ADVISORY', () =>
{
	const f = scanText(FX.envAssign);
	assert.ok(hasRule(f, 'sf-credential-env-assignment'));
	assert.equal(blockingFindings(f).length, 0, 'keyword-anchored env credential is advisory, never block');
});

test('a lone consumer key is advisory, but blocks when co-located with a secret keyword', () =>
{
	const lone = scanText(FX.consumerKey);
	assert.ok(hasRule(lone, 'salesforce-consumer-key'), 'consumer key flagged');
	assert.equal(blockingFindings(lone).length, 0, 'lone consumer key is advisory only');

	const withContext = scanText(`consumer_secret used with key ${FX.consumerKey}`);
	assert.ok(blockingFindings(withContext).some(x => x.ruleId === 'salesforce-consumer-key'), 'consumer key promoted to block in secret context');
});

// ---- Tier-3 advisory ----------------------------------------------------

test('a JWT is advisory, never blocking', () =>
{
	const f = scanText(FX.jwt);
	assert.ok(hasRule(f, 'jwt'));
	assert.equal(blockingFindings(f).length, 0, 'JWT alone does not block');
});

// ---- Tier-0: the Salesforce false-positive minefield --------------------

test('does NOT flag bare org IDs / user IDs / API names / UUIDs / hashes', () =>
{
	for(const [name, fx] of Object.entries({
		orgId15: NEG.orgId15, orgId18: NEG.orgId18, userId18: NEG.userId18, uuid: NEG.uuid, sha256: NEG.sha256, apiName: NEG.apiName
	}))
	{
		const f = scanText(fx);
		assert.equal(blockingFindings(f).length, 0, `${name} must not block (value: ${fx})`);
	}
});

test('does NOT flag AWS reserved documentation example keys (…EXAMPLE)', () =>
{
	// These appear in masking-test fixtures and AWS docs; flagging them would
	// hard-fail the distribution / mirror gates on a non-secret. A real AWS key
	// never ends in EXAMPLE, so excluding them costs no recall.
	assert.equal(blockingFindings(scanText(NEG.awsDocExampleKey)).length, 0, 'AKIA…EXAMPLE is not a secret');
	assert.equal(blockingFindings(scanText(NEG.awsDocExampleSession)).length, 0, 'ASIA…EXAMPLE is not a secret');
	assert.equal(blockingFindings(scanText('AWS AKIAIOSFODNN7EXAMPLE used')).length, 0, 'in surrounding prose too');
});

test('does NOT flag CI templating expressions or env-var references', () =>
{
	assert.equal(blockingFindings(scanText(NEG.ciTemplate)).length, 0, 'CI ${{ }} template');
	assert.equal(blockingFindings(scanText(NEG.envVarRef)).length, 0, '$VAR reference');
});

test('does NOT flag angle-bracket documentation placeholders', () =>
{
	const f = scanText(NEG.docPlaceholder);
	assert.equal(blockingFindings(f).length, 0, 'doc placeholder must not match auth-url rule');
});

// ---- Suppression: stopwords + inline allow ------------------------------

test('a redaction sentinel on the line suppresses the finding', () =>
{
	const f = scanText(`refreshToken = ${FX.refreshToken} ***REDACTED***`);
	assert.equal(f.length, 0, 'line carrying ***REDACTED*** is suppressed');
});

test('an inline kerndx-secret-allow comment suppresses the finding', () =>
{
	const js = `const t = "${FX.accessToken}"; // kerndx-secret-allow: synthetic fixture`;
	assert.equal(scanText(js).length, 0, 'inline allow silences the line');
});

test('extraStopwords are WEAK — suppress advisory findings only, never a block secret', () =>
{
	// A caller-supplied stopword is treated as WEAK: it silences advisory noise...
	const adv = scanText(`token ${FX.jwt} ZZZCUSTOMSENTINEL`, {extraStopwords: ['ZZZCUSTOMSENTINEL']});
	assert.equal(adv.length, 0, 'advisory JWT suppressed by a custom (weak) extra stopword');
	// ...but it must NEVER be able to hide a block-tier secret (suppression-bypass guard).
	const blk = scanText(`token ${FX.refreshToken} ZZZCUSTOMSENTINEL`, {extraStopwords: ['ZZZCUSTOMSENTINEL']});
	assert.ok(blockingFindings(blk).length >= 1, 'a weak extra stopword cannot suppress a block-tier refresh token');
});

test('default stopwords include the masking redaction sentinel', () =>
{
	assert.ok(DEFAULT_STOPWORDS.includes('***REDACTED***'));
});

// ---- Line numbers, dedup, redaction, summary ----------------------------

test('reports a 1-based line number', () =>
{
	const content = `line one\nline two\n${FX.awsKey}\n`;
	const f = scanText(content);
	const aws = f.find(x => x.ruleId === 'aws-access-key');
	assert.ok(aws, 'aws key found');
	assert.equal(aws.lineNumber, 3);
});

test('dedupes nested matches — an auth URL reports once, not also its inner tokens', () =>
{
	const f = scanText(FX.authUrl);
	const onAuthLine = f.filter(x => x.lineNumber === 1);
	assert.equal(onAuthLine.length, 1, 'only the outer auth-url finding survives dedup');
	assert.equal(onAuthLine[0].ruleId, 'sfdx-auth-url');
});

test('redactSecret masks the middle while preserving a short signature', () =>
{
	const r = redactSecret(FX.refreshToken);
	assert.notEqual(r, FX.refreshToken, 'redacted value differs from raw');
	assert.ok(!r.includes('BVjJ8E0L0RfQ5kQ8aQ'), 'middle of the secret is masked');
	assert.ok(r.length <= FX.refreshToken.length);
});

test('findings carry a redacted match, never the raw secret in a printable field', () =>
{
	const f = scanText(FX.refreshToken);
	assert.ok(f.length >= 1);
	assert.ok(f[0].redacted && !f[0].redacted.includes('BVjJ8E0L0RfQ5kQ8aQ'), 'redacted field hides the secret body');
});

test('summarizeFindings tallies blocking vs advisory', () =>
{
	const findings = [
		...scanText(FX.accessToken),   // block
		...scanText(FX.jwt)            // advisory
	];
	const s = summarizeFindings(findings);
	assert.equal(s.total, findings.length);
	assert.ok(s.blocking >= 1, 'at least one blocking');
	assert.ok(s.advisory >= 1, 'at least one advisory');
	assert.equal(s.blocking + s.advisory, s.total);
});

test('includeAdvisory:false returns only blocking findings', () =>
{
	const f = scanText(FX.jwt, {includeAdvisory: false});
	assert.equal(f.length, 0, 'advisory-only content yields nothing when advisory excluded');
	const g = scanText(FX.accessToken, {includeAdvisory: false});
	assert.ok(g.length >= 1, 'blocking content still returned');
});

test('customPatterns extend the scan', () =>
{
	const f = scanText('widget-key=SUPERSECRETWIDGET', {
		customPatterns: [{id: 'widget', label: 'Widget key', tier: 'block', regex: /SUPERSECRETWIDGET/g}]
	});
	assert.ok(hasRule(f, 'widget'));
});

test('empty / whitespace content yields no findings', () =>
{
	assert.equal(scanText('').length, 0);
	assert.equal(scanText('   \n\t\n').length, 0);
	assert.equal(scanText(null).length, 0, 'null is tolerated');
});

// ---- Regression: a larger advisory must NOT downgrade a contained block ----

test('a refresh token assigned to a password= key is still BLOCKING (not swallowed by generic advisory)', () =>
{
	const f = scanText(`password=${FX.refreshToken}`);
	assert.ok(blockingFindings(f).length >= 1, 'block-tier survives the containing generic advisory');
	assert.ok(f.some(x => x.ruleId === 'salesforce-refresh-token' && x.tier === 'block'));
});

test('a consumer key promoted in context survives the containing generic advisory', () =>
{
	// `password:` both promotes the consumer key to block AND triggers a generic
	// advisory that spans it — the block must not be swallowed.
	const f = scanText(`password: ${FX.consumerKey}`);
	assert.ok(blockingFindings(f).length >= 1, 'promoted consumer key not lost to generic advisory');
});

// ---- Regression: keyword-anchored rules must not flag references / non-secrets ----

test('does NOT block credential keys assigned an identifier reference, path, or URL', () =>
{
	const refs = [
		'client_secret: process.env.SF_CLIENT_SECRET',
		'this.clientSecret = options.clientSecret || defaults.clientSecret;',
		'clientSecret = getClientSecretFromVault();',
		'SFDX_AUTH_URL = process.env.SFDX_AUTH_URL',
		'client_secret: /path/to/some/long/config/location',
		'client_secret: see-the-documentation-link-below-for-details'
	];
	for(const r of refs)
	{
		assert.equal(blockingFindings(scanText(r)).length, 0, `must not block: ${r}`);
	}
});

test('does NOT block non-secret SF_ORG_* env metadata (alias / url / id / username)', () =>
{
	const benign = [
		'SF_ORG_ALIAS=MyDevOrgSandbox01',
		'SF_ORG_URL=https://acme.my.salesforce.com',
		'SF_ORG_ID=00D5f000000abcdEAA',
		'SF_ORG_USERNAME=admin@example.com.prod',
		'SF_ORG_INSTANCE_URL: https://acme.my.salesforce.com'
	];
	for(const b of benign)
	{
		assert.equal(blockingFindings(scanText(b)).length, 0, `must not block: ${b}`);
	}
});

test('a genuine client_secret / SF_ACCESS_TOKEN / SF_ORG_PASSWORD literal is surfaced (advisory)', () =>
{
	// Real keyword-anchored credential literals are still REPORTED — as advisory,
	// for human review — even though they no longer hard-block CI.
	assert.ok(hasRule(scanText(FX.consumerSecretAssign), 'salesforce-consumer-secret'), 'real client_secret literal flagged');
	assert.ok(hasRule(scanText(FX.envAssign), 'sf-credential-env-assignment'), 'real SF_ACCESS_TOKEN literal flagged');
	assert.ok(hasRule(scanText('SF_ORG_PASSWORD=aB3xQ9zPliteralPassw0rdValue'), 'sf-credential-env-assignment'), 'SF_ORG_PASSWORD literal flagged');
	for(const line of [
		FX.consumerSecretAssign,
		FX.envAssign,
		'SF_ORG_PASSWORD=aB3xQ9zPliteralPassw0rdValue'
	])
	{
		assert.equal(blockingFindings(scanText(line)).length, 0, `keyword-anchored literal is advisory, not block: ${line.slice(0, 24)}…`);
	}
});

// ---- Suppression model: strong (whole-line, any tier) vs weak (advisory only) ----

test('a strong symbol-wrapped sentinel (***REDACTED***) suppresses the whole line at any tier', () =>
{
	assert.equal(scanText(`${FX.awsKey} ***REDACTED***`).length, 0, 'adjacent strong sentinel suppresses a block');
	const filler = ' '.repeat(60);
	assert.equal(scanText(`${FX.awsKey}${filler}***REDACTED***`).length, 0, 'distance is irrelevant — strong sentinel is whole-line');
	assert.equal(scanText(`token ${FX.refreshToken} ***MASKED***`).length, 0, '***MASKED*** is also a strong sentinel');
});

test('a bareword weak stopword does NOT suppress a block-tier secret (BLOCKER 2 bypass guard)', () =>
{
	// The suppression-bypass: an author who controls the file plants a bareword
	// next to a real secret to silence the gate. Weak stopwords touch advisory only.
	for(const word of [
		'REDACTED',
		'PLACEHOLDER',
		'CHANGEME',
		'redacted',
		'placeholder'
	])
	{
		const f = scanText(`auth = ${FX.refreshToken} ${word}`);
		assert.ok(blockingFindings(f).length >= 1, `bareword "${word}" must not hide a block secret`);
	}
});

test('a weak stopword suppresses an advisory finding, case-insensitively', () =>
{
	assert.ok(scanText(`jwt ${FX.jwt}`).length >= 1, 'without a stopword the advisory is reported');
	assert.equal(scanText(`jwt ${FX.jwt} placeholder`).length, 0, 'lowercase weak stopword suppresses advisory');
	assert.equal(scanText(`jwt ${FX.jwt} PLACEHOLDER`).length, 0, 'uppercase weak stopword suppresses advisory');
});

// ---- Keyword-anchored rules are ADVISORY: references / placeholders never BLOCK ----
// "Converge on shapes": telling a real keyword-anchored credential from a
// reference / placeholder / path needs a value judgement that proved an arms
// race (both false positives and bypasses), so these rules never gate CI. Some
// benign lines below are reported as advisory noise — acceptable, because CI
// blocks only on the unambiguous SHAPE rules. None of these may BLOCK.

test('keyword values that are references, paths, calls, placeholders, or UUIDs never BLOCK', () =>
{
	const benign = [
		'client_secret: process.env.SF_CLIENT_SECRET',
		'clientSecret = config.clientSecret;',
		'clientSecret = getClientSecretFromVault();',
		'client_secret: /path/to/config/location/value',
		'client_secret: see-the-documentation-link-below',
		'client_secret: your_client_secret_here',
		'client_secret: <your-client-secret>',
		'client_secret: REPLACE_ME_WITH_REAL_VALUE',
		'client_secret: CHANGE_ME_BEFORE_DEPLOY',
		'client_secret: placeholder_value_goes_in_here',
		'client_secret: example_secret_for_the_docs',
		'SF_ACCESS_TOKEN: 8f3a2b1c-4d5e-6f70-8a9b-0c1d2e3f4a5b'
	];
	for(const b of benign)
	{
		assert.equal(blockingFindings(scanText(b)).length, 0, `must not block: ${b}`);
	}
});

// ---- U+2028/U+2029 line separators (visual-deception suppression guard) ----

test('a strong sentinel separated by U+2028 / U+2029 does NOT suppress a secret on the next logical line', () =>
{
	// U+2028/U+2029 render as a line break in many editors/diff viewers but are
	// not \\n. Splitting on them puts the sentinel and the secret on SEPARATE
	// logical lines, so the secret is still reported (no whole-line suppression).
	const u2028 = `x = "${FX.refreshToken}"\u2028// ***REDACTED*** decoy`;
	assert.ok(blockingFindings(scanText(u2028)).length >= 1, 'U+2028-separated decoy sentinel does not hide the secret');
	const u2029 = `${FX.awsKey}\u2029***REDACTED*** decoy`;
	assert.ok(scanText(u2029).some(x => x.ruleId === 'aws-access-key'), 'U+2029 also splits logical lines');
});

// ---- CR-only line endings (HIGH 7) ----

test('CR-only (\\r) line endings still surface a block secret on the correct line', () =>
{
	// Classic-Mac line endings: a strong sentinel on one author-line must not
	// collapse onto the secret's line (old split was on \n only).
	const content = `${FX.awsKey}\rsafe line ***REDACTED***\r`;
	const f = scanText(content);
	const aws = f.find(x => x.ruleId === 'aws-access-key');
	assert.ok(aws, 'AWS key on its own CR-delimited line is still found');
	assert.equal(aws.lineNumber, 1, 'CR split yields a correct 1-based line number');
});

// ---- Per-line match cap (MED 8 — O(n^2) dedup DoS guard) ----

test('caps matches on a pathological single line without wedging', () =>
{
	// A minified one-liner with thousands of secret-shaped tokens must not drive
	// the O(N^2) nested dedup into a multi-second wedge; matches are bounded.
	const line = 'AKIAIOSFODNN7EXAMPLE '.repeat(3000);   // ~3000 AWS-key shapes on ONE line
	const start = process.hrtime.bigint();
	const f = scanText(line);
	const ms = Number(process.hrtime.bigint() - start) / 1e6;
	assert.ok(f.length <= 1000, `bounded to the per-line cap (got ${f.length})`);
	assert.ok(ms < 2000, `completes quickly under the cap (took ${ms.toFixed(0)}ms)`);
});

// ---- defensive branches -------------------------------------------------

test('summarizeFindings tolerates null/undefined input', () =>
{
	assert.deepEqual(summarizeFindings(null), {blocking: 0, advisory: 0, total: 0});
	assert.deepEqual(summarizeFindings(undefined), {blocking: 0, advisory: 0, total: 0});
});

test('a non-global custom pattern is matched once without infinite loop', () =>
{
	const f = scanText('value=WIDGETSECRETZZZ here', {
		customPatterns: [{id: 'ng', label: 'non-global', tier: 'block', regex: /WIDGETSECRET[A-Z]+/}]
	});
	assert.equal(f.filter(x => x.ruleId === 'ng').length, 1, 'matched exactly once');
});

test('a custom pattern entry without a RegExp is ignored, not thrown', () =>
{
	const f = scanText(`x ${FX.awsKey}`, {customPatterns: [{id: 'bad', label: 'bad', tier: 'block', regex: 'not-a-regexp'}]});
	assert.ok(f.some(x => x.ruleId === 'aws-access-key'), 'real patterns still run');
	assert.ok(!f.some(x => x.ruleId === 'bad'), 'invalid custom entry produced no finding');
});

test('an empty-string extra stopword is ignored (no spurious suppression)', () =>
{
	const f = scanText(FX.awsKey, {extraStopwords: ['']});
	assert.ok(f.some(x => x.ruleId === 'aws-access-key'), 'empty stopword does not suppress everything');
});

// ---- Two-class stopword vocabulary ---------------------------------------

test('STRONG_SENTINELS are symbol-wrapped; WEAK_STOPWORDS are barewords; union is DEFAULT_STOPWORDS', () =>
{
	assert.ok(Array.isArray(STRONG_SENTINELS) && STRONG_SENTINELS.length >= 1);
	assert.ok(Array.isArray(WEAK_STOPWORDS) && WEAK_STOPWORDS.length >= 1);
	for(const s of STRONG_SENTINELS)
	{
		assert.ok(s.startsWith('***') && s.endsWith('***'), `strong sentinel is symbol-wrapped: ${s}`);
	}
	for(const w of WEAK_STOPWORDS)
	{
		assert.ok(!w.startsWith('***'), `weak stopword is a bareword: ${w}`);
	}
	assert.deepEqual(DEFAULT_STOPWORDS, STRONG_SENTINELS.concat(WEAK_STOPWORDS), 'DEFAULT_STOPWORDS is the union');
});

// ---- redactSecret edge lengths -------------------------------------------

test('redactSecret handles null, short, and long values', () =>
{
	assert.equal(redactSecret(null), '', 'null → empty string');
	assert.equal(redactSecret(undefined), '', 'undefined → empty string');
	assert.equal(redactSecret('abcd'), '****', 'a short value is fully masked');
	assert.equal(redactSecret('12345678'), '********', 'an 8-char value is fully masked');
	assert.ok(redactSecret('123456789012').includes('…'), 'a longer value keeps a short signature');
});

// ---- zero-width custom pattern guard (no infinite loop) -------------------

test('a custom pattern that can match the empty string does not loop or yield findings', () =>
{
	const f = scanText('bbb bbb', {
		customPatterns: [{id: 'zw', label: 'zero-width', tier: 'block', regex: /A*/g}]
	});
	assert.equal(f.filter(x => x.ruleId === 'zw').length, 0, 'empty matches are skipped, not reported');
});
