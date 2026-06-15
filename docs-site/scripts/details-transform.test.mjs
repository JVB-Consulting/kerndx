// SPDX-License-Identifier: BUSL-1.1
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { transformDetails } from './details-transform.mjs'

test('converts a details/summary block to a ::: details container', () => {
  const input = [
    '<details>',
    '<summary>Expand</summary>',
    '',
    '1. [Overview](#overview)',
    '2. [Quick Start](#quick-start)',
    '',
    '</details>'
  ].join('\n')
  const out = transformDetails(input)
  assert.ok(out.startsWith('::: details Expand'))
  assert.ok(out.trim().endsWith(':::'))
  assert.ok(out.includes('1. [Overview](#overview)'))
  assert.ok(!out.includes('<details>'))
  assert.ok(!out.includes('<summary>'))
})

test('preserves an inner markdown table inside the container', () => {
  const input = '<details><summary>Cols</summary>\n\n| A | B |\n|---|---|\n| 1 | 2 |\n\n</details>'
  const out = transformDetails(input)
  assert.ok(out.includes('| A | B |'))
  assert.ok(out.includes('::: details Cols'))
})

test('handles multiple details blocks and leaves other markdown untouched', () => {
  const input = '# Title\n<details><summary>One</summary>\na\n</details>\ntext\n<details><summary>Two</summary>\nb\n</details>'
  const out = transformDetails(input)
  assert.equal((out.match(/::: details/g) || []).length, 2)
  assert.ok(out.includes('# Title'))
  assert.ok(out.includes('text'))
})

test('leaves content without details unchanged', () => {
  const input = '# Just a heading\n\nsome text'
  assert.equal(transformDetails(input), input)
})

test('leaves a details block inside a fenced code block verbatim', () => {
  const input = [
    'Example:',
    '',
    '```html',
    '<details>',
    '<summary>Click</summary>',
    'hidden',
    '</details>',
    '```',
    '',
    'done'
  ].join('\n')
  const out = transformDetails(input)
  assert.equal(out, input)
  assert.ok(!out.includes('::: details'))
  assert.ok(out.includes('<details>'))
  assert.ok(out.includes('<summary>Click</summary>'))
})

test('still transforms a real details block that follows a fenced example', () => {
  const input = [
    '```html',
    '<details><summary>Sample</summary>x</details>',
    '```',
    '',
    '<details>',
    '<summary>Real</summary>',
    '',
    'body text',
    '',
    '</details>'
  ].join('\n')
  const out = transformDetails(input)
  assert.ok(out.includes('```html\n<details><summary>Sample</summary>x</details>\n```'))
  assert.ok(out.includes('::: details Real'))
  assert.ok(out.includes('body text'))
})

test('matches an opening details tag with attributes (open)', () => {
  const input = '<details open>\n<summary>Title</summary>\nbody\n</details>'
  const out = transformDetails(input)
  assert.ok(out.startsWith('::: details Title'))
  assert.ok(out.trim().endsWith(':::'))
  assert.ok(out.includes('body'))
  assert.ok(!out.includes('<details'))
})

test('matches a summary tag with attributes (class)', () => {
  const input = '<details>\n<summary class="x" id="y">Title</summary>\nbody\n</details>'
  const out = transformDetails(input)
  assert.ok(out.startsWith('::: details Title'))
  assert.ok(out.includes('body'))
  assert.ok(!out.includes('<summary'))
})

test('matches an attributed details and attributed summary together', () => {
  const input = '<details open class="z">\n<summary data-foo="bar">Heading</summary>\ninner\n</details>'
  const out = transformDetails(input)
  assert.ok(out.startsWith('::: details Heading'))
  assert.ok(out.includes('inner'))
})

test('leaves a nested details block unmangled (skips the outer)', () => {
  const input = [
    '<details>',
    '<summary>Outer</summary>',
    'before',
    '<details>',
    '<summary>Inner</summary>',
    'in',
    '</details>',
    'after',
    '</details>'
  ].join('\n')
  const out = transformDetails(input)
  // No corruption: the surrounding content must survive intact. The non-greedy
  // match must not close the outer block at the inner </details>.
  assert.ok(out.includes('before'))
  assert.ok(out.includes('after'))
  assert.ok(out.includes('in'))
  // Nothing should be left dangling outside a balanced container.
  assert.ok(!/:::[\s\S]*<\/details>/.test(out))
  assert.ok(!/<details>[\s\S]*:::/.test(out))
})

test('leaves an unclosed details block unchanged', () => {
  const input = '<details>\n<summary>Oops</summary>\nbody with no close'
  const out = transformDetails(input)
  assert.equal(out, input)
  assert.ok(!out.includes('::: details'))
})

test('a literal </details> in the body does not close the container early', () => {
  const input = [
    '<details>',
    '<summary>Doc</summary>',
    '',
    'Write `</details>` to close the block.',
    '',
    '</details>'
  ].join('\n')
  const out = transformDetails(input)
  // The container must span to the FINAL </details>, keeping the inline-code mention intact.
  assert.ok(out.startsWith('::: details Doc'))
  assert.ok(out.includes('`</details>`'))
  assert.ok(out.trim().endsWith(':::'))
})
