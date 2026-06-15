// SPDX-License-Identifier: BUSL-1.1
// Full-corpus render gate. Generalises the render smoke-test to EVERY built route:
// builds nothing itself (run after `npm run build`), serves `vitepress preview`, and
// drives Chromium over all routes via a worker pool. Hard-fails (exit 1) on any route
// that returns non-200, logs a console error / page error, leaks a container marker
// into rendered prose, fails to render a mermaid diagram to <svg>, or has a broken
// image. A second 390px pass reports horizontal-overflow pages as non-fatal warnings.
// Run: `npm run test:sweep`.
import { chromium } from '@playwright/test'
import { spawn } from 'node:child_process'
import { setTimeout as sleep } from 'node:timers/promises'
import { readdir } from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const DIST = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../.vitepress/dist')
const DOCS_BASE = (process.env.DOCS_BASE ?? '/').replace(/\/$/, '')
const BASE = `http://localhost:4173${DOCS_BASE}`
const BENIGN = [/favicon/i]

async function walk(dir) {
  const out = []
  for (const e of await readdir(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name)
    if (e.isDirectory()) { if (e.name === 'assets') continue; out.push(...await walk(p)) }
    else if (e.name.endsWith('.html')) out.push(p)
  }
  return out
}

async function waitForServer(timeoutMs = 30000) {
  const start = Date.now()
  while (Date.now() - start < timeoutMs) {
    try { const r = await fetch(BASE); if (r.ok) return } catch { /* retry */ }
    await sleep(500)
  }
  throw new Error('preview server did not start')
}

const files = (await walk(DIST)).sort()
const routes = files
  .map(f => path.relative(DIST, f).replace(/\.html$/, ''))
  .filter(s => s !== '404')
  .map(s => (s.replace(/(^|\/)index$/, '') || ''))
  .map(s => `${DOCS_BASE}/${s}`.replace(/\/$/, '') || '/')

const failures = []
const warnings = []

async function checkRoute(page, route) {
  const consoleErrs = []
  const pageErrs = []
  const onConsole = m => { if (m.type() === 'error') consoleErrs.push(m.text()) }
  const onPageErr = e => pageErrs.push(String(e))
  page.on('console', onConsole)
  page.on('pageerror', onPageErr)
  let status = 0
  try {
    const resp = await page.goto(`http://localhost:4173${route}`, { waitUntil: 'networkidle', timeout: 25000 })
    status = resp ? resp.status() : 0
  } catch (e) { failures.push(`NAV ${route}: ${e.message}`) }
  await page.waitForTimeout(120)
  const r = await page.evaluate(() => {
    const body = document.querySelector('.vp-doc') || document.body
    const text = body ? body.innerText : ''
    const leaks = []
    if (/(^|\n)\s*:::/.test(text)) leaks.push(':::')
    if (text.includes('[object Object]')) leaks.push('[object Object]')
    const mermaidNoSvg = [...document.querySelectorAll('.mermaid')].filter(m => !m.querySelector('svg')).length
    const brokenImgs = [...document.querySelectorAll('.vp-doc img')].filter(i => i.complete && i.naturalWidth === 0).map(i => i.getAttribute('src'))
    return { leaks, mermaidNoSvg, brokenImgs }
  })
  page.off('console', onConsole); page.off('pageerror', onPageErr)
  const realConsole = consoleErrs.filter(m => !BENIGN.some(b => b.test(m)))
  if (status !== 200) failures.push(`STATUS ${route}: HTTP ${status}`)
  if (realConsole.length) failures.push(`CONSOLE ${route}: ${realConsole.slice(0, 2).join(' | ')}`)
  if (pageErrs.length) failures.push(`PAGEERROR ${route}: ${pageErrs.slice(0, 2).join(' | ')}`)
  if (r.leaks.length) failures.push(`LEAK ${route}: ${r.leaks.join(', ')}`)
  if (r.mermaidNoSvg) failures.push(`MERMAID ${route}: ${r.mermaidNoSvg} not rendered to SVG`)
  if (r.brokenImgs.length) failures.push(`IMG ${route}: broken ${r.brokenImgs.slice(0, 2).join(', ')}`)
}

async function checkOverflow(page, route) {
  try {
    await page.goto(`http://localhost:4173${route}`, { waitUntil: 'domcontentloaded', timeout: 25000 })
    const over = await page.evaluate(() => {
      const de = document.documentElement
      return de.scrollWidth - de.clientWidth > 2 ? de.scrollWidth - de.clientWidth : 0
    })
    if (over) warnings.push(`OVERFLOW ${route}: ${over}px at 390px`)
  } catch { /* nav failure already captured in pass 1 */ }
}

async function poolRun(browser, list, fn, workers, viewport) {
  let idx = 0
  const worker = async () => {
    const ctx = await browser.newContext({ viewport })
    const page = await ctx.newPage()
    while (idx < list.length) await fn(page, list[idx++])
    await ctx.close()
  }
  await Promise.all(Array.from({ length: workers }, worker))
}

const server = spawn('npx', ['vitepress', 'preview', '--port', '4173'], { stdio: 'inherit' })
let browser
try {
  await waitForServer()
  browser = await chromium.launch()
  console.log(`Sweeping ${routes.length} routes (desktop)…`)
  await poolRun(browser, routes, checkRoute, 6, { width: 1280, height: 900 })
  console.log(`Sweeping ${routes.length} routes (390px overflow)…`)
  await poolRun(browser, routes, checkOverflow, 6, { width: 390, height: 800 })
} finally {
  if (browser) await browser.close()
  server.kill('SIGTERM')
}

if (warnings.length) {
  console.warn(`\n⚠ ${warnings.length} non-fatal warning(s):`)
  for (const w of warnings.slice(0, 40)) console.warn('  ' + w)
}
if (failures.length) {
  console.error(`\n✗ ${failures.length} failure(s):`)
  for (const f of failures) console.error('  ' + f)
  process.exit(1)
}
console.log(`\n✓ full-corpus sweep: ${routes.length}/${routes.length} routes — 200, no console/page errors, no leaks, mermaid→SVG, images load.`)
