// SPDX-License-Identifier: MIT
'use strict';

/**
 * Shared, pure Salesforce-aware secret-pattern scanner.
 *
 * This is the single source of truth for credential detection across the
 * KernDX pipeline (`scan` / `preflight` commands) and the package's own
 * release-supply-chain gates (`build-distribution.js`, `sync-public-mirror.js`).
 * It performs NO file or git I/O — callers enumerate files and feed text in.
 * (The one exception: a single diagnostic line is written to stderr if a
 * pathologically long line has to be truncated; see MAX_MATCHES_PER_LINE.)
 *
 * Design priorities, in order:
 *   1. Zero false positives on a real Salesforce codebase. A bare org ID
 *      (`00D…`), a record ID, an 18-char API name, a UUID, a SHA-256 hash, a
 *      `***REDACTED***` masking fixture, or a CI templating expression
 *      (`${{ secrets.X }}`) must never fail a gate.
 *   2. High recall on the credentials that actually cause Salesforce account
 *      takeover: the SFDX auth URL, access/refresh tokens, the JWT-bearer
 *      private key, and connected-app consumer secrets.
 *
 * Tiers:
 *   - 'block'    — fail the gate (CI / build / mirror). RESERVED for unambiguous
 *                  credential SHAPES whose structure alone identifies a secret:
 *                  the SFDX auth URL, access/refresh tokens, PEM private keys,
 *                  and the prefixed cloud keys (AWS/GitHub/Slack/Google). These
 *                  do not depend on a surrounding keyword or on classifying the
 *                  value, so they cannot be evaded by renaming a variable and do
 *                  not misfire on a placeholder.
 *   - 'advisory' — warn only; never fails a gate. Everything that needs CONTEXT
 *                  or a value judgement to call: keyword-anchored assignments
 *                  (`client_secret=…`, `SF_ACCESS_TOKEN=…`), JWTs, generic
 *                  credential assignments, and the lone consumer key (which is
 *                  still promoted to 'block' only when a secret keyword sits on
 *                  the same line — a shape+context signal, not a value guess).
 *
 * This is a deliberate "converge on shapes" design. Earlier revisions tried to
 * BLOCK keyword-anchored assignments by classifying the assigned value as a real
 * secret vs a placeholder / reference / path; repeated adversarial review showed
 * that classification is an arms race (placeholder-prefixed real secrets, all-
 * lowercase passphrases, member-access look-alikes) that produced both false
 * positives and bypasses. Keyword rules are therefore advisory: they surface a
 * likely leak for human review without gating CI on a guess. The unambiguous
 * SHAPE rules are the hard gate, and your Git host's push protection remains the
 * backstop for the ambiguous cases.
 *
 * Suppression is layered, two-class, and never disables the scanner wholesale:
 *   - inline allow comment — a line containing `kerndx-secret-allow` is skipped
 *     (mirrors the repo's `kern-coverage-exempt` convention; a reason string is
 *     expected after the marker). Suppresses ANY tier — auditable in review.
 *   - STRONG sentinels (`***REDACTED***`, `***MASKED***`) — symbol-wrapped,
 *     attacker-implausible, and visible in review. A line containing one is a
 *     deliberate redaction fixture and is skipped at ANY tier (whole-line).
 *   - WEAK stopwords (`REDACTED`, `PLACEHOLDER`, `CHANGEME`, …) — bare words
 *     that can appear incidentally in prose or be planted by a hostile author.
 *     They suppress ADVISORY findings ONLY (case-insensitively); they can NEVER
 *     hide a block-tier secret. Callers may add more via `extraStopwords`
 *     (always treated as WEAK).
 *   Path ignore-globs and the `.kerndxsecretsignore` fingerprint file are
 *   I/O-layer concerns handled by the calling command/gate, not here.
 *
 * Regex shapes are grounded in upstream sources: the sfdx-core auth-URL parser,
 * TruffleHog's Salesforce detector (`00…!…` access token, `3MVG9…` consumer
 * key, `5Aep861…` refresh token), and gitleaks' canonical config (private key,
 * AWS, GitHub, Slack, Google).
 */

/**
 * STRONG, symbol-wrapped sentinels. A line containing any of these is a
 * deliberate, review-visible redaction fixture and is skipped at ANY tier. The
 * `***…***` wrapping is what makes them attacker-implausible: a reviewer seeing
 * `***REDACTED***` next to a credential-shaped string will challenge it, the
 * same way an inline `kerndx-secret-allow` is challenged.
 */
const STRONG_SENTINELS = [
	'***REDACTED***',
	'***MASKED***'
];

/**
 * WEAK / bareword stopwords. Matched CASE-INSENSITIVELY. These suppress
 * ADVISORY-tier findings only — never a block-tier secret. A bare word like
 * `placeholder` is too easy to plant near a real `force://` URL or access token
 * to be allowed to silence a block finding (the suppression-bypass that whole-
 * line bareword matching previously enabled).
 */
const WEAK_STOPWORDS = [
	'REDACTED',
	'MASKED',
	'DO_NOT_USE',
	'DO-NOT-USE',
	'DONOTUSE',
	'EXAMPLE_ONLY',
	'EXAMPLE_SECRET',
	'SAMPLE_ONLY',
	'FAKE_SECRET',
	'PLACEHOLDER',
	'CHANGEME',
	'CHANGE_ME',
	'XXXXXXXX',
	'NOT_A_REAL',
	'SYNTHETIC_SECRET'
];

/**
 * Back-compatible union (strong ∪ weak). Exported so callers and tests can see
 * the full default sentinel vocabulary in one place.
 */
const DEFAULT_STOPWORDS = STRONG_SENTINELS.concat(WEAK_STOPWORDS);

const INLINE_ALLOW_MARKER = 'kerndx-secret-allow';

/**
 * A line is capped at this many raw pattern matches before dedup. A minified /
 * generated one-liner (which passes the 5 MB file cap, has no NUL byte, and is
 * valid UTF-8) could otherwise drive the O(N²) nested-dedup into a multi-second
 * wedge that compounds across a whole-tree gate walk. The first matches on a
 * line already include every distinct secret shape in practice; capping the
 * tail is safe. Truncation is announced on stderr — never silent.
 */
const MAX_MATCHES_PER_LINE = 1000;

/**
 * The pattern set. Each entry:
 *   - id          unique stable identifier (reported as ruleId)
 *   - label       human-readable description
 *   - tier        'block' | 'advisory' (base tier)
 *   - regex       global RegExp used to find matches within a single line
 *   - promoteWhen optional RegExp; an advisory match is promoted to 'block'
 *                 when this matches anywhere on the same line (proximity anchor)
 */
const SECRET_PATTERNS = [
	// ---- Tier 1: near-zero false positive, block standalone ----
	{
		id: 'sfdx-auth-url', label: 'SFDX auth URL (force://… — full account takeover)', tier: 'block', // clientId/clientSecret groups may be empty (default connected app);
		// refresh-token group is required. Angle-bracket doc placeholders are
		// excluded by the character classes.
		regex: /force:\/\/[A-Za-z0-9._-]*={0,2}:[A-Za-z0-9._-]*={0,2}:[A-Za-z0-9._-]+={0,2}@[A-Za-z0-9:._-]+/g
	},
	{
		id: 'salesforce-access-token', label: 'Salesforce access token / session ID', tier: 'block', // 15-char org id (00 + 13) then '!' then the opaque token body. The '!'
		// is what distinguishes this from a benign public org ID.
		regex: /\b00[A-Za-z0-9]{13}![A-Za-z0-9._]{80,}/g
	},
	{
		id: 'salesforce-refresh-token', label: 'Salesforce OAuth refresh token', tier: 'block', regex: /\b5Aep861[A-Za-z0-9._=-]{20,}/g
	},
	{
		id: 'private-key', label: 'Private key block (PEM)', tier: 'block', regex: /-----BEGIN (?:RSA |EC |DSA |OPENSSH |PGP |ENCRYPTED )?PRIVATE KEY(?: BLOCK)?-----/g
	},
	{
		id: 'aws-access-key', label: 'AWS access key ID', tier: 'block', // The `(?![A-Z2-7]{9}EXAMPLE\b)` lookahead skips AWS's reserved
		// documentation example keys (AKIAIOSFODNN7EXAMPLE / ASIA…EXAMPLE). Real
		// AWS access key IDs never end in EXAMPLE, so this drops a known false
		// positive (masking-test fixtures, AWS docs) with zero real-world recall loss.
		regex: /\b(?:A3T[A-Z0-9]|AKIA|ASIA|ABIA|ACCA)(?![A-Z2-7]{9}EXAMPLE\b)[A-Z2-7]{16}\b/g
	},
	{
		id: 'github-token', label: 'GitHub access token', tier: 'block', regex: /\b(?:gh[pousr]_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{59,})\b/g
	},
	{
		id: 'slack-token', label: 'Slack token', tier: 'block', regex: /\bxox[baprs]-[A-Za-z0-9-]{10,}/g
	},
	{
		id: 'google-api-key', label: 'Google API key', tier: 'block', regex: /\bAIza[0-9A-Za-z_-]{35}\b/g
	},
	// ---- Tier 2: keyword-anchored assignments (ADVISORY) ----
	// These need surrounding context to tell a real credential from a reference,
	// placeholder, or path. Classifying the assigned value proved an arms race
	// (false positives AND bypasses), so they warn for human review rather than
	// gate CI on a guess. The unambiguous SHAPE rules above are the block-tier
	// backstop, as is the Git host's push protection. The capture groups are
	// retained (harmless) so the matched assignment is reported in full.
	{
		id: 'salesforce-consumer-secret',
		label: 'OAuth consumer/client secret assignment',
		tier: 'advisory',
		regex: /(?:consumer[_-]?secret|client[_-]?secret)\s*[:=]\s*(["']?)([A-Za-z0-9+/=_.\-]{16,})/gi
	},
	{
		id: 'sf-credential-env-assignment',
		label: 'Salesforce credential environment variable assigned a literal',
		tier: 'advisory', // Only genuinely secret-bearing env names — org alias / instance URL /
		// username / id names (SF_ORG_ALIAS, SF_ORG_URL, SF_ORG_ID, …) are public
		// metadata and are deliberately NOT listed.
		regex: /\b(?:SFDX_AUTH_URL|SF_ACCESS_TOKEN|SFDX_ACCESS_TOKEN|SECURITY_TOKEN|SF_ORG_PASSWORD|SF_ORG_SECRET)\b\s*[:=]\s*(["']?)([A-Za-z0-9+/=_.\-]{12,})/g
	},
	// ---- Tier 2: proximity-anchored (advisory; block in secret context) ----
	{
		id: 'salesforce-consumer-key',
		label: 'OAuth consumer/client key (3MVG9…)',
		tier: 'advisory',
		regex: /\b3MVG9[A-Za-z0-9+/=_.-]{40,}/g,
		promoteWhen: /consumer[_-]?secret|client[_-]?secret|refresh|private[_-]?key|password/i
	},
	// ---- Tier 3: advisory ----
	{
		id: 'jwt', label: 'JSON Web Token', tier: 'advisory', regex: /\beyJ[A-Za-z0-9_-]{6,}\.eyJ[A-Za-z0-9_-]{6,}\.[A-Za-z0-9_-]{6,}/g
	},
	{
		id: 'generic-api-key',
		label: 'Generic credential assignment',
		tier: 'advisory',
		regex: /(?:api[_-]?key|secret|token|password|passwd|credential)["']?\s*[:=]\s*["']?([A-Za-z0-9+/=_-]{20,150})/gi
	}
];

/**
 * Mask the middle of a secret, preserving a short signature for triage.
 *
 * @param {string} value - The raw matched substring.
 * @returns {string} A redacted, printable form that omits the secret body.
 */
function redactSecret(value)
{
	if(value === null || value === undefined)
	{
		return '';
	}
	const str = String(value);
	if(str.length <= 8)
	{
		return '*'.repeat(str.length);
	}
	return `${str.slice(0, 4)}…${str.slice(-2)}`;
}

/**
 * Drop matches fully nested inside a larger match on the same line, so a single
 * auth-URL leak reports once rather than also re-reporting its inner refresh
 * token, and a keyword-anchored assignment subsumes a generic one at the same
 * spot. Larger ranges win; for identical ranges, 'block' wins over 'advisory'.
 *
 * @param {object[]} matches - Per-line raw matches with {start, end, effectiveTier}.
 * @returns {object[]} The surviving matches.
 */
function dedupeNested(matches)
{
	const rank = m => (m.effectiveTier === 'block' ? 0 : 1);
	const sorted = [...matches].sort((a, b) => (a.start - b.start) || (b.end - a.end) || (rank(a) - rank(b)));
	const kept = [];
	for(const m of sorted)
	{
		// A match is dropped only when subsumed by a kept match of EQUAL OR HIGHER
		// severity. A larger advisory must never swallow a contained block secret
		// (e.g. `password=<refresh token>`) — that would downgrade a real leak to
		// advisory and let it past a CI gate that blocks only on block-tier.
		const contained = kept.some(k => k !== m && k.start <= m.start && k.end >= m.end && rank(k) <= rank(m));
		if(!contained)
		{
			kept.push(m);
		}
	}
	return kept;
}

/**
 * Whether a line carries a strong, whole-line, any-tier suppression marker:
 * the inline allow comment or a symbol-wrapped sentinel.
 *
 * @param {string} line
 * @returns {boolean}
 */
function hasWholeLineSuppressor(line)
{
	if(line.includes(INLINE_ALLOW_MARKER))
	{
		return true;
	}
	for(const s of STRONG_SENTINELS)
	{
		if(line.includes(s))
		{
			return true;
		}
	}
	return false;
}

/**
 * Whether a line carries a WEAK stopword (advisory-only suppression). Matched
 * case-insensitively.
 *
 * @param {string} lowerLine - The line, already lower-cased.
 * @param {string[]} weakStopwords
 * @returns {boolean}
 */
function hasWeakStopword(lowerLine, weakStopwords)
{
	for(const w of weakStopwords)
	{
		if(w && lowerLine.includes(w.toLowerCase()))
		{
			return true;
		}
	}
	return false;
}

/**
 * Scan text for secret patterns. Pure — no file/git I/O (a single stderr note is
 * emitted only when a pathological line is truncated; see MAX_MATCHES_PER_LINE).
 *
 * @param {string} content - The text to scan (a file's contents, a diff, etc.).
 * @param {object} [options]
 * @param {Array}  [options.customPatterns] - Extra patterns ({id,label,tier,regex}).
 * @param {string[]} [options.extraStopwords] - Additional WEAK suppression stopwords.
 * @param {boolean} [options.includeAdvisory=true] - Include advisory-tier findings.
 * @returns {Array<{ruleId,label,tier,lineNumber,column,match,redacted}>}
 */
function scanText(content, options)
{
	if(content === null || content === undefined || content === '')
	{
		return [];
	}
	const opts = options || {};
	const customPatterns = Array.isArray(opts.customPatterns) ? opts.customPatterns : [];
	const extraStopwords = Array.isArray(opts.extraStopwords) ? opts.extraStopwords : [];
	const includeAdvisory = opts.includeAdvisory !== false;

	const patterns = customPatterns.length ? SECRET_PATTERNS.concat(customPatterns) : SECRET_PATTERNS;
	// extraStopwords are always WEAK (advisory-only): a caller-supplied bareword
	// must not be able to hide a block-tier secret.
	const weakStopwords = extraStopwords.length ? WEAK_STOPWORDS.concat(extraStopwords) : WEAK_STOPWORDS;

	// Split on CRLF, lone CR (classic-Mac), LF, and the Unicode line separators
	// U+2028/U+2029. The latter render as a line break in many editors/diff
	// viewers but are NOT \n — without them a `***REDACTED***` sentinel could sit
	// on what looks (to a reviewer) like a separate line yet share one logical
	// line with a secret and silence it. 1-based line numbering is preserved.
	const lines = String(content).split(/\r\n|\r|\n|\u2028|\u2029/);
	const findings = [];

	for(let i = 0; i < lines.length; i++)
	{
		const line = lines[i];
		if(!line)
		{
			continue;
		}
		// Whole-line, any-tier suppression: inline allow comment or strong sentinel.
		if(hasWholeLineSuppressor(line))
		{
			continue;
		}
		const lowerLine = line.toLowerCase();
		const weakSuppressed = hasWeakStopword(lowerLine, weakStopwords);

		const lineMatches = [];
		let truncated = false;
		for(const p of patterns)
		{
			if(!(p.regex instanceof RegExp))
			{
				continue;
			}
			p.regex.lastIndex = 0;
			let m;
			while((m = p.regex.exec(line)) !== null)
			{
				const text = m[0];
				if(text.length === 0)
				{
					p.regex.lastIndex++;
					continue;
				}
				const promoted = !!(p.promoteWhen && p.promoteWhen.test(line));
				lineMatches.push({
					pattern: p, start: m.index, end: m.index + text.length, match: text, effectiveTier: promoted ? 'block' : p.tier
				});
				if(lineMatches.length >= MAX_MATCHES_PER_LINE)
				{
					truncated = true;
					break;
				}
				if(!p.regex.global)
				{
					break;
				}
			}
			if(truncated)
			{
				break;
			}
		}
		if(truncated)
		{
			process.stderr.write(
					`[secret-patterns] line ${i + 1}: capped at ${MAX_MATCHES_PER_LINE} pattern matches (looks minified/generated); matches beyond the cap were not evaluated.\n`);
		}

		for(const lm of dedupeNested(lineMatches))
		{
			if(lm.effectiveTier === 'advisory')
			{
				if(!includeAdvisory)
				{
					continue;
				}
				// WEAK stopwords suppress advisory findings only — never block.
				if(weakSuppressed)
				{
					continue;
				}
			}
			findings.push({
				ruleId: lm.pattern.id, label: lm.pattern.label, tier: lm.effectiveTier, lineNumber: i + 1, column: lm.start + 1, match: lm.match, redacted: redactSecret(lm.match)
			});
		}
	}

	return findings;
}

/**
 * Tally findings by enforcement tier.
 *
 * @param {Array} findings - Output of scanText.
 * @returns {{blocking:number, advisory:number, total:number}}
 */
function summarizeFindings(findings)
{
	let blocking = 0;
	let advisory = 0;
	for(const f of findings || [])
	{
		if(f.tier === 'block')
		{
			blocking++;
		}
		else
		{
			advisory++;
		}
	}
	return {blocking, advisory, total: blocking + advisory};
}

module.exports = {
	SECRET_PATTERNS, DEFAULT_STOPWORDS, STRONG_SENTINELS, WEAK_STOPWORDS, INLINE_ALLOW_MARKER, scanText, redactSecret, summarizeFindings
};
