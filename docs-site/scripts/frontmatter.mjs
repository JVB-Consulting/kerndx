// SPDX-License-Identifier: BUSL-1.1
// Minimal frontmatter splitter for the flat, scalar frontmatter used in docs/.
// Avoids a dependency; handles string/number/boolean scalars and quoted strings.
export function parseFrontmatter(md) {
  // A leading UTF-8 BOM (﻿) defeats the ^--- anchor and leaks the block
  // into the page body; strip it before matching, and account for its width
  // when slicing the body back off.
  const bom = md.charCodeAt(0) === 0xfeff ? 1 : 0
  const src = bom ? md.slice(1) : md
  const m = src.match(/^---\n([\s\S]*?)\n---\n?/)
  if (!m) return { data: {}, content: md }
  // Guard against a document that merely opens with a `---` thematic break
  // (horizontal rule) and happens to have a later `---`. A real frontmatter
  // block is only key: value pairs (and blank lines); anything else means the
  // opening `---` is content, so leave the document untouched.
  const lines = m[1].split('\n')
  const looksLikeFrontmatter = lines.every((line) => {
    const t = line.trim()
    return t === '' || /^[A-Za-z0-9_-]+:(\s.*)?$/.test(t)
  })
  if (!looksLikeFrontmatter) return { data: {}, content: md }
  const data = {}
  for (const line of lines) {
    const kv = line.match(/^([A-Za-z0-9_-]+):\s*(.*)$/)
    if (!kv) continue
    let v = kv[2].trim()
    if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) {
      v = v.slice(1, -1)
    } else if (v === 'true' || v === 'false') {
      v = v === 'true'
    } else if (isPlainNumber(v)) {
      v = Number(v)
    }
    data[kv[1]] = v
  }
  return { data, content: src.slice(m[0].length) }
}

// True only for scalars safe to coerce to Number without losing information:
// a single integer, or a decimal whose fractional part does not end in 0, with
// no leading zero (other than a lone 0) and at most one dot. Version-looking
// values stay strings so they round-trip intact: multi-dot (1.2.3), leading
// zero (007), and trailing-zero decimals (1.0, 1.10 — which would collapse to
// 1 and 1.1) all keep their exact textual form.
function isPlainNumber(v) {
  const m = v.match(/^-?(0|[1-9][0-9]*)(?:\.([0-9]+))?$/)
  if (!m) return false
  const frac = m[2]
  if (frac !== undefined && frac.endsWith('0')) return false
  return true
}

// Re-emit a frontmatter block from a data object (scalars only).
export function stringifyFrontmatter(data) {
  const lines = Object.entries(data).map(([k, v]) => {
    if (typeof v === 'string') return `${k}: ${JSON.stringify(v)}`
    return `${k}: ${v}`
  })
  return `---\n${lines.join('\n')}\n---\n`
}
