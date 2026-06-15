// SPDX-License-Identifier: BUSL-1.1
// Rewrites raw-HTML <details><summary>Title</summary> … </details> blocks into
// VitePress ::: details Title … ::: containers (built-in; renders inner markdown).
// Source files keep their <details> (GitHub renders them); this applies only to src/.
//
// The transform is fence-aware (a <details> shown INSIDE a fenced code block is a code
// EXAMPLE and is left verbatim), tolerates attributes on the opening tags (<details open>,
// <summary class="x">), and is robust against malformed input: an unclosed <details>, a
// literal </details> mention inside an inline-code span, and nested <details> are all left
// untouched rather than corrupting the surrounding content.

// Opening tags may carry attributes; closing tags do not.
const TOKEN = /<details(?:\s[^<>]*)?>|<\/details>|<summary(?:\s[^<>]*)?>|<\/summary>/gi
const SENTINEL = String.fromCharCode(0)

// Transform the top-level <details>…</details> blocks in one prose segment (already free of
// fenced code blocks). Inline code spans inside the segment are masked first so a </details>
// written as `</details>` is not mistaken for a real closing tag. A block is converted only
// when it is well-formed and NOT nested (its own body contains no further <details>); any
// malformed or nested block is left verbatim.
function transformSegment(seg) {
  // Mask inline code spans so their angle-bracket tags never count toward tokenization.
  const spans = []
  const masked = seg.replace(/`[^`\n]*`/g, (span) => {
    spans.push(span)
    return `${SENTINEL}${spans.length - 1}${SENTINEL}`
  })
  let out = ''
  let cursor = 0
  TOKEN.lastIndex = 0
  let m
  while ((m = TOKEN.exec(masked)) !== null) {
    const tag = m[0]
    if (!/^<details/i.test(tag)) {
      // A stray </details>, <summary> or </summary> with no preceding open — copy through.
      continue
    }
    // Found a top-level opening <details>. Walk forward tracking nesting depth to find its
    // matching close. If the body contains a nested <details>, or no close is found, bail
    // and leave the whole block verbatim.
    const blockStart = m.index
    let depth = 1
    let nested = false
    let closeEnd = -1
    let inner
    while ((inner = TOKEN.exec(masked)) !== null) {
      if (/^<details/i.test(inner[0])) {
        depth++
        nested = true
      } else if (/^<\/details>/i.test(inner[0])) {
        depth--
        if (depth === 0) {
          closeEnd = inner.index + inner[0].length
          break
        }
      }
    }
    if (closeEnd === -1) {
      // Unclosed: leave verbatim and resume scanning AFTER this opening tag.
      TOKEN.lastIndex = blockStart + tag.length
      continue
    }
    if (nested) {
      // Contains a nested <details>: leave the WHOLE outer block verbatim (do not transform
      // the inner one in isolation — that would leave a ::: container inside raw tags). Resume
      // scanning past the outer block's matching close.
      TOKEN.lastIndex = closeEnd
      continue
    }
    const block = masked.slice(blockStart, closeEnd)
    const summaryMatch = block.match(/^<details(?:\s[^<>]*)?>\s*<summary(?:\s[^<>]*)?>([\s\S]*?)<\/summary>([\s\S]*)<\/details>\s*$/i)
    if (!summaryMatch) {
      // No usable <summary> directly after the opening tag: leave verbatim.
      TOKEN.lastIndex = closeEnd
      continue
    }
    const heading = summaryMatch[1].replace(/\s+/g, ' ').trim()
    const body = summaryMatch[2].replace(/^\n+/, '').replace(/\n+$/, '')
    out += masked.slice(cursor, blockStart)
    out += `::: details ${heading}\n${body}\n:::`
    cursor = closeEnd
    TOKEN.lastIndex = closeEnd
  }
  out += masked.slice(cursor)
  // Restore the masked inline code spans.
  return out.replace(new RegExp(`${SENTINEL}(\\d+)${SENTINEL}`, 'g'), (_m, n) => spans[Number(n)])
}

export function transformDetails(md) {
  // Split into fenced code blocks (```…```) and prose; the capture group keeps the delimiters
  // so each odd-indexed segment is a fenced block that must stay verbatim (a <details> there
  // is an EXAMPLE, not a container directive).
  const parts = md.split(/(```[\s\S]*?```)/g)
  return parts
    .map((seg, i) => (i % 2 === 1 ? seg : transformSegment(seg)))
    .join('')
}
