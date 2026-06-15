// SPDX-License-Identifier: BUSL-1.1
// Guarded synthesizer for <meta name="description">. Returns a clean string, or
// null when the result would be an unusable fragment (< 30 chars) — never a
// templated/duplicate string.

// Common abbreviations whose trailing period is NOT a sentence boundary. Matched
// case-insensitively against the word immediately preceding the period.
const ABBREVIATIONS = new Set([
  'e.g', 'i.e', 'etc', 'vs', 'inc', 'ltd', 'co', 'corp', 'llc',
  'mr', 'mrs', 'ms', 'dr', 'prof', 'st', 'no', 'vol', 'fig',
  'al', 'cf', 'approx', 'dept', 'est', 'min', 'max', 'sec', 'ref',
])

// Decide whether the period at index `i` in `s` is a real sentence terminator
// rather than part of an abbreviation, a single-letter initial, or a number.
function isSentenceEnd(s, i) {
  const ch = s[i]
  if (ch === '!' || ch === '?') return true            // never ambiguous
  // A decimal / version dot: digit on both sides (e.g. v2.0, 3.14) — not an end.
  if (/\d/.test(s[i - 1] || '') && /\d/.test(s[i + 1] || '')) return false
  // Grab the run of word characters (letters/digits/dots) ending just before
  // this period, e.g. "e.g" for "e.g.", "Inc" for "Inc.", "J" for "J.".
  const before = s.slice(0, i)
  const m = before.match(/([\p{L}\p{N}.]+)$/u)
  if (m) {
    const word = m[1]
    const bare = word.replace(/\.+$/, '')               // strip any trailing dots
    if (ABBREVIATIONS.has(bare.toLowerCase())) return false
    // Single-letter initial (e.g. "J." or "A." in "J. Smith").
    if (/^\p{L}$/u.test(bare)) return false
  }
  return true
}

// Code-point-safe slice: never splits an astral character (emoji / supplementary
// plane) by truncating mid surrogate pair.
function sliceCodePoints(s, max) {
  const cps = Array.from(s)
  return cps.length <= max ? s : cps.slice(0, max).join('')
}

export function cleanMetaDescription(rawText) {
  if (!rawText) return null
  let s = String(rawText)
  s = s.replace(/\{@\w+\s+([^}]*)\}/g, '$1')        // {@link Foo} / {@see Bar} → Foo / Bar
  s = s.replace(/\[([^\]]*)\]\([^)]*\)/g, '$1')      // [label](url) → label
  s = s.replace(/<[^>]+>/g, '')                       // inline HTML
  s = s.replace(/[`*#>~]/g, '')                        // markdown emphasis/code/heading tokens (keep _ — it is an identifier char, e.g. UTIL_SObject)
  s = s.replace(/[[\]]/g, '')                         // stray brackets
  s = s.replace(/\s+/g, ' ').trim()
  // First sentence: scan for a terminator that is followed by whitespace/end and
  // is not part of an abbreviation, single-letter initial, or version/decimal.
  let out = s
  const term = /[.!?](?=\s|$)/g
  let match
  while ((match = term.exec(s)) !== null) {
    if (isSentenceEnd(s, match.index)) {
      out = s.slice(0, match.index + 1)
      break
    }
  }
  out = out.trim()
  if (out.length < 30) return null
  if (out.length > 155) out = sliceCodePoints(out, 152).replace(/\s+\S*$/, '').trimEnd() + '…'
  return out
}
