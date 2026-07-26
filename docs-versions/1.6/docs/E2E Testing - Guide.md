---
navOrder: 92
---

# E2E Testing - Guide

**Framework:** KernDX
**Package Type:** Managed Package

**Target Audience:**

- **Developers** - Building and running Playwright E2E tests against Salesforce orgs with KernDX
- **Architects** - Designing E2E test strategies for Lightning applications
- **QA Engineers** - Automating browser-based verification of Salesforce features

---

## What problem does this solve?

Some failures only show up once a real person clicks through your app. A unit test (Apex `@IsTest`, LWC Jest) checks one piece of code on its own, so it never sees a page that renders wrong after a layout change, or a toast message that never appears.

This guide shows you how to test a real Salesforce screen end to end: log in, click through pages, and confirm what a user actually sees. It uses Playwright, a browser automation tool, with a set of ready-made helpers tuned for Salesforce Lightning.

Read it if you build, design, or verify Lightning features (developers, architects, and QA engineers). Use it whenever a unit test cannot prove that the user-facing result is correct.

---

## Mental model

Think of an end-to-end test as a robot stand-in for one of your users. It opens a browser, signs in, walks through the same screens a person would, and checks that the right things appear. The helpers in this guide are the parts of that journey Salesforce always makes awkward (waiting for a page to settle, finding an element inside a Lightning component, catching a toast before it vanishes) packaged up so you do not write them every time.

---

## Use this when

- You need to confirm a real user sees the right result: a field renders, a toast appears, a validation error blocks a save.
- A trigger action, custom validation, or LWC only proves itself once it runs inside a live Lightning page.
- You want to catch problems that only surface when everything is wired together: layout, components, and data loading at once.
- You are verifying a KernDX feature in the browser (the Streaming Event Monitor, log entries, API call records).

## Don't use this when

- A unit test can already prove the result. Apex `@IsTest` and LWC Jest tests are faster and steadier; use them first and keep E2E for what they cannot reach.
- You would be testing Salesforce's own platform behaviour rather than your custom features. That wastes time and breaks on platform updates.
- You only need to set up or check data. Do that through the `sf` CLI or anonymous Apex, not the browser. Drive the browser only for the thing you are actually verifying.

## Quick start

The fastest way in is the companion [Fast Start - E2E Testing](Fast%20Start%20-%20E2E%20Testing.md), which gets three tests passing in about 25 minutes. In short, the path is:

1. Create an `e2e/` folder beside your `force-app/` source and install Playwright (see [How do I set up the project?](#how-do-i-set-up-the-project)).
2. Point the suite at your org by its alias and let global setup log in for you once (see [Authentication](#authentication)).
3. Write your first spec using the navigation and wait helpers, so the test waits for Lightning to settle instead of guessing (see [Helper Library Reference](#helper-library-reference)).

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [What problem does this solve?](#what-problem-does-this-solve)
2. [Mental model](#mental-model)
3. [Use this when](#use-this-when)
4. [Don't use this when](#dont-use-this-when)
5. [Quick start](#quick-start)
6. [Quick Navigation](#quick-navigation)
7. [Why test in the browser at all?](#why-test-in-the-browser-at-all)
    - [Why E2E Testing for Salesforce?](#why-e2e-testing-for-salesforce)
    - [Why Playwright?](#why-playwright)
    - [How does it work?](#how-does-it-work)
    - [Key Design Decisions](#key-design-decisions)
8. [How do I set up the project?](#how-do-i-set-up-the-project)
    - [Directory Structure](#directory-structure)
    - [Dependencies](#dependencies)
    - [Configuration Deep Dive](#configuration-deep-dive)
    - [Org Alias](#org-alias)
9. [Authentication](#authentication)
    - [How Frontdoor URL Works](#how-frontdoor-url-works)
    - [Global Setup Flow](#global-setup-flow)
    - [Session State Reuse](#session-state-reuse)
    - [Re-authentication Mid-Test](#re-authentication-mid-test)
    - [Expired Sessions](#expired-sessions)
    - [Package Upgrade in E2E Context](#package-upgrade-in-e2e-context)
10. [Salesforce Lightning Challenges](#salesforce-lightning-challenges)
    - [Shadow DOM](#shadow-dom)
    - [Spinners and Loading States](#spinners-and-loading-states)
    - [Toasts](#toasts)
    - [Navigation and Page Loading](#navigation-and-page-loading)
    - [List Views](#list-views)
    - [Record Pages](#record-pages)
    - [Modals](#modals)
    - [Combobox and Picklist](#combobox-and-picklist)
11. [Helper Library Reference](#helper-library-reference)
    - [sf-auth.js](#sf-authjs)
    - [sf-cli.js](#sf-clijs)
    - [sf-navigation.js](#sf-navigationjs)
    - [wait-helpers.js](#wait-helpersjs)
    - [sf-selectors.js](#sf-selectorsjs)
12. [Page Object Patterns](#page-object-patterns)
    - [Why Page Objects for Salesforce](#why-page-objects-for-salesforce)
    - [Base Structure](#base-structure)
    - [Locator Strategies](#locator-strategies)
    - [Dynamic Content Handling](#dynamic-content-handling)
    - [Example: List View Page](#example-list-view-page)
    - [Example: Record Page](#example-record-page)
    - [Example: Custom LWC Page](#example-custom-lwc-page)
13. [Testing Common Salesforce Features](#testing-common-salesforce-features)
    - [Record CRUD and Field Verification](#record-crud-and-field-verification)
    - [Trigger Side Effects](#trigger-side-effects)
    - [Validation Error Messages](#validation-error-messages)
    - [List View Filtering](#list-view-filtering)
    - [Related Lists](#related-lists)
    - [LWC Component Interaction](#lwc-component-interaction)
    - [Toast Assertions](#toast-assertions)
    - [Modal Workflows](#modal-workflows)
    - [Log Entry Verification](#log-entry-verification)
    - [API Call Verification](#api-call-verification)
    - [Streaming and Change Data Capture Monitor](#streaming-and-change-data-capture-monitor)
    - [Event Usage Metrics](#event-usage-metrics)
14. [Data Management](#data-management)
    - [Creating Test Data](#creating-test-data)
    - [SOQL Queries with Namespace](#soql-queries-with-namespace)
    - [Cleanup Patterns](#cleanup-patterns)
    - [Deploying Metadata](#deploying-metadata)
    - [Custom Metadata States](#custom-metadata-states)
15. [Debugging](#debugging)
    - [Headed Mode](#headed-mode)
    - [Debug Mode](#debug-mode)
    - [Trace Viewer](#trace-viewer)
    - [Screenshots and Video](#screenshots-and-video)
    - [Browser Console](#browser-console)
    - [Lightning DOM Inspection](#lightning-dom-inspection)
16. [CI/CD Integration](#cicd-integration)
    - [GitHub Actions Workflow](#github-actions-workflow)
    - [Scratch Org Lifecycle](#scratch-org-lifecycle)
    - [Session Management in CI](#session-management-in-ci)
    - [Artifact Collection](#artifact-collection)
17. [Best Practices](#best-practices)
18. [Anti-Patterns](#anti-patterns)
19. [Troubleshooting](#troubleshooting)
20. [Related Documentation](#related-documentation)

</details>

---

## Quick Navigation

| I want to...                         | Go to                                                                     |
|--------------------------------------|---------------------------------------------------------------------------|
| Get started quickly                  | [Fast Start - E2E Testing](Fast%20Start%20-%20E2E%20Testing.md)           |
| Understand the authentication flow   | [Authentication](#authentication)                                         |
| Handle Lightning-specific challenges | [Salesforce Lightning Challenges](#salesforce-lightning-challenges)       |
| Look up a helper function            | [Helper Library Reference](#helper-library-reference)                     |
| Write page objects                   | [Page Object Patterns](#page-object-patterns)                             |
| Write tests for a specific feature   | [Testing Common Salesforce Features](#testing-common-salesforce-features) |
| Debug a failing test                 | [Debugging](#debugging)                                                   |
| Set up CI/CD                         | [CI/CD Integration](#cicd-integration)                                    |
| Fix a common issue                   | [Troubleshooting](#troubleshooting)                                       |

---

## Why test in the browser at all?

### Why E2E Testing for Salesforce?

Some failures only appear when a real user clicks through your app, and a unit test will never see them. A unit test (Apex `@IsTest`, LWC Jest) checks one component on its own. An E2E test plays out the whole user journey in a real browser: logging in, moving between pages, watching data render, clicking components, and confirming the side effects.

That broader view is the point. For Salesforce apps, E2E tests catch problems unit tests cannot:

- Lightning page layout rendering after metadata changes
- Trigger side effects visible in the UI after record creation
- Cross-component interactions on record pages
- Toast messages and validation errors shown to users
- Custom LWC behaviour when embedded in Lightning pages
- Navigation flows across multiple pages

### Why Playwright?

| Feature                                                          | Benefit for Salesforce                                          |
|------------------------------------------------------------------|-----------------------------------------------------------------|
| [Auto-waiting](https://playwright.dev/docs/actionability)        | Handles Lightning's dynamic DOM without explicit sleeps         |
| [CSS + text locators](https://playwright.dev/docs/locators)      | Works with Lightning component selectors and visible text       |
| [Browser contexts](https://playwright.dev/docs/browser-contexts) | Session state management via `storageState`                     |
| [Trace viewer](https://playwright.dev/docs/trace-viewer)         | Visual debugging of Lightning page interactions                 |
| Cross-browser                                                    | Chromium, Firefox, WebKit (Chromium recommended for Salesforce) |
| [Network interception](https://playwright.dev/docs/network)      | Mock or monitor Salesforce API calls                            |

### How does it work?

```text
┌─────────────────────────────────────────────────────┐
│  Test Runner (npx playwright test)                  │
├─────────────────────────────────────────────────────┤
│  Global Setup                                       │
│  ┌─────────────┐    ┌──────────────┐                │
│  │ sf org open  │───>│ Frontdoor    │──> .auth/      │
│  │ --url-only   │    │ URL auth     │    state.json  │
│  └─────────────┘    └──────────────┘                │
├─────────────────────────────────────────────────────┤
│  Specs (serial, single worker)                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐          │
│  │ login    │  │ record   │  │ trigger  │          │
│  │ .spec.js │  │ .spec.js │  │ .spec.js │          │
│  └──────────┘  └──────────┘  └──────────┘          │
│       │              │              │                │
│       ▼              ▼              ▼                │
│  ┌─────────────────────────────────────┐            │
│  │  Helpers (auth, cli, nav, wait, sel)│            │
│  └─────────────────────────────────────┘            │
│       │              │                               │
│       ▼              ▼                               │
│  ┌──────────┐  ┌──────────────┐                     │
│  │ Browser  │  │ sf CLI       │                     │
│  │ (Chrome) │  │ (SOQL, Apex) │                     │
│  └──────────┘  └──────────────┘                     │
└─────────────────────────────────────────────────────┘
```

| Layer            | Purpose                                                                    |
|------------------|----------------------------------------------------------------------------|
| **Global setup** | Authenticates once, saves session cookies to `.auth/state.json`            |
| **Specs**        | Test files that run serially in a single browser worker                    |
| **Helpers**      | Reusable functions for auth, CLI, navigation, waiting, and selectors       |
| **Browser**      | Chromium renders Lightning pages, Playwright interacts with the DOM        |
| **sf CLI**       | Executes SOQL queries, anonymous Apex, and record CRUD outside the browser |

### Key Design Decisions

A few choices shape how this setup runs. Knowing the reasoning saves you from "fixing" something that is deliberate.

1. **Run tests one at a time, in a single browser.** Every test shares one `sid` login cookie. If two browser sessions reuse that cookie at once, Salesforce hands out conflicting security tokens (CSRF and Aura): one session's page load quietly cancels the other's token. The result is "Page Expired" errors and tests that log themselves out at random. Running serially in a single worker avoids all of that.

2. **Log in with a one-time frontdoor URL, not a stored password.** `sf org open --url-only` generates a short-lived URL that signs you in through Salesforce's frontdoor.jsp endpoint. Nothing sensitive sits in the test code.

3. **Set up and check data through the CLI, not the browser.** Creating records, running SOQL, and executing Apex through the `sf` CLI is faster and steadier than filling in forms. Drive the browser only for the thing you are actually verifying.

4. **Allow generous timeouts.** A Lightning page makes several network calls and re-renders the DOM more than once before it settles. So the defaults are patient: 120 seconds for a whole test, 15 seconds for a single assertion.

> **Extending framework classes from your org.** Your own Apex extends the `kern` framework classes through their public, namespaced API. For example: `public inherited sharing class CustomTriggerHandler extends kern.TRG_Base implements kern.IF_Trigger.BeforeInsert`. The same pattern applies to the `kern.SEL_Base` selectors and the `kern.UTIL_*` utilities. The Triggers, Selectors, and DML Developer Guides cover this in full.

---

## How do I set up the project?

### Directory Structure

Tests live alongside your SFDX project:

```text
my-project/
  force-app/                    Salesforce source
  e2e/                          E2E test root
    playwright.config.js        Playwright configuration
    global-setup.js             Authentication setup
    package.json                Node.js dependencies
    .auth/                      Session state (gitignored)
      state.json
    helpers/                    Reusable helper modules
      sf-auth.js
      sf-cli.js
      sf-navigation.js
      wait-helpers.js
      sf-selectors.js
    pages/                      Page object classes
      account-record.page.js
    specs/                      Test files
      login.spec.js
      record-page.spec.js
    test-results/               Playwright output (gitignored)
```

Add to your `.gitignore`:

```text
e2e/.auth/
e2e/test-results/
e2e/node_modules/
```

### Dependencies

```bash
cd e2e
npm init -y
npm install -D @playwright/test
npx playwright install chromium
```

Only `@playwright/test` is required. No additional Salesforce-specific packages.

### [Configuration Deep Dive](https://playwright.dev/docs/test-configuration)

`e2e/playwright.config.js`:

```javascript
const {defineConfig} = require('@playwright/test');
const path = require('path');

module.exports = defineConfig({
	testDir: path.join(__dirname, 'specs'),
	globalSetup: path.join(__dirname, 'global-setup.js'),
	timeout: 120_000,
	expect: {timeout: 15_000},
	fullyParallel: false,
	workers: 1,
	retries: 0,
	reporter: 'list',
	use: {
		browserName: 'chromium',
		headless: true,
		storageState: path.join(__dirname, '.auth', 'state.json'),
		viewport: {width: 1920, height: 1080},
		screenshot: 'on',
		trace: 'retain-on-failure',
		video: 'retain-on-failure',
		navigationTimeout: 30_000,
		actionTimeout: 15_000
	},
	outputDir: path.join(__dirname, 'test-results')
});
```

<details>
<summary>Every config setting and why it is set</summary>

| Setting             | Value                 | Why                                                                                          |
|---------------------|-----------------------|----------------------------------------------------------------------------------------------|
| `testDir`           | `specs/`              | Separates test files from helpers and pages                                                  |
| `globalSetup`       | `global-setup.js`     | Runs authentication before any tests                                                         |
| `timeout`           | `120_000`             | Lightning pages can take 30-60s on first load                                                |
| `expect.timeout`    | `15_000`              | [Assertions](https://playwright.dev/docs/test-assertions) need time for Lightning re-renders |
| `fullyParallel`     | `false`               | Shared session cookie causes CSRF token conflicts in parallel                                |
| `workers`           | `1`                   | Single browser context, single authenticated session                                         |
| `retries`           | `0`                   | Retries mask real issues; fix flakiness in helpers instead                                   |
| `reporter`          | `'list'`              | Simple output; add `'html'` for detailed reports                                             |
| `storageState`      | `.auth/state.json`    | Session cookies saved by global setup                                                        |
| `viewport`          | `1920x1080`           | Full desktop layout; Lightning responsive breakpoints matter                                 |
| `screenshot`        | `'on'`                | Capture screenshot for every test (useful for visual verification)                           |
| `trace`             | `'retain-on-failure'` | Full trace for debugging, only kept for failed tests                                         |
| `video`             | `'retain-on-failure'` | Video recording for failed tests                                                             |
| `navigationTimeout` | `30_000`              | Page.goto and waitForURL timeout                                                             |
| `actionTimeout`     | `15_000`              | Click, fill, and other action timeouts                                                       |

</details>

### Org Alias

The Playwright suite always talks to one org, named by a fixed alias. That name is the `ORG_ALIAS` constant in `release-testing/e2e/helpers/sf-auth.js:5`. The helper does not read an environment variable for it, so the constant is the single place the alias is set.

If your scratch org already uses that alias, the only setup is to make it your CLI default:

```bash
sf config set target-org=$SF_SUBSCRIBER_ORG_ALIAS
```

If your org uses a different alias, pick one of two paths:

- **Rename the alias** (the simpler path for one-off testing): `export SF_SUBSCRIBER_ORG_ALIAS=YourExistingAlias`.
- **Edit your own copy of the helper**: change the `ORG_ALIAS` constant in `release-testing/e2e/helpers/sf-auth.js` to match your alias. This change lives in your own copy and is not contributed back upstream.

---

## Authentication

### How Frontdoor URL Works

1. `sf org open -o OrgAlias --url-only -r` generates a one-time URL:
   `https://instance.salesforce.com/secur/frontdoor.jsp?sid=ACCESS_TOKEN`
2. Playwright opens this URL in a headless Chromium browser
3. Salesforce validates the session ID and redirects to the authenticated org
4. Playwright captures all cookies and local storage from the authenticated session
5. Session state is saved to `.auth/state.json`
6. Every test loads this state file, starting already authenticated

### Global Setup Flow

```javascript
const {chromium} = require('@playwright/test');
const path = require('path');
const fs = require('fs');
const {getFrontdoorUrl, getInstanceUrl} = require('./helpers/sf-auth');

const AUTH_DIR = path.join(__dirname, '.auth');
const AUTH_STATE_PATH = path.join(AUTH_DIR, 'state.json');

async function globalSetup()
{
	const frontdoorUrl = getFrontdoorUrl();
	const instanceUrl = getInstanceUrl();
	const browser = await chromium.launch();
	const context = await browser.newContext({ignoreHTTPSErrors: true});
	const page = await context.newPage();

	await page.goto(frontdoorUrl, {waitUntil: 'domcontentloaded'});
	await page.waitForURL(url => !url.pathname.includes('/secur/frontdoor.jsp'), {timeout: 30_000});

	await page.goto(`${instanceUrl}/lightning/page/home`, {waitUntil: 'domcontentloaded'});
	await page.locator('one-app-nav-bar, one-appnav').first()
	.waitFor({state: 'attached', timeout: 60_000});

	fs.mkdirSync(AUTH_DIR, {recursive: true});
	await context.storageState({path: AUTH_STATE_PATH});
	await browser.close();
}

module.exports = globalSetup;
```

**Why navigate to Lightning home after frontdoor?** The frontdoor URL only establishes the session. Navigating
to Lightning home forces the browser to load Lightning's JavaScript bundles and set additional cookies and local
storage entries that Lightning requires. Without this step, the first test would need to wait for Lightning to
initialise, adding 30+ seconds.

### Session State Reuse

Playwright's [`storageState`](https://playwright.dev/docs/test-fixtures) in the config tells every test context to load `.auth/state.json` before the test
starts. This means:

- No login form interaction needed in tests
- Tests start directly on Lightning pages
- Session cookies are valid for the org's session timeout (default: 2-12 hours)

### Re-authentication Mid-Test

If a test navigates to a URL and the session has expired, the page redirects to the login screen. The
`ensureAuthenticated()` function in `sf-auth.js` detects this and re-authenticates automatically:

```javascript
async function ensureAuthenticated(page)
{
	const url = page.url();
	const isOnSalesforcePage = (url.includes('.salesforce.com') || url.includes('.force.com'))
		&& !url.includes('/login') && !url.includes('/secur/frontdoor');
	if(!isOnSalesforcePage)
	{
		await reauthenticate(page);
	}
}
```

All navigation helpers call `ensureAuthenticated()` before navigating, so session expiry is handled
transparently.

### Expired Sessions

If tests fail with authentication errors:

1. Delete `.auth/state.json` (global setup regenerates it on the next run)
2. Verify CLI authentication: `sf org display -o YourOrgAlias`
3. Check org session timeout settings: Setup > Session Settings > Session Timeout

For long-running test suites (>2 hours), consider lowering the test count per run or calling
`reauthenticate(page)` in `test.beforeEach`.

### Package Upgrade in E2E Context

A beta (unpromoted) package version cannot be upgraded over an existing install: Salesforce only supports in-place upgrades for promoted versions. So when you move to a new version, recreate the scratch org from scratch and clear the cached login files:

```bash
sf org delete scratch -o $SF_SUBSCRIBER_ORG_ALIAS --no-prompt
cd /tmp/kern-subscriber && sf org create scratch -f <your-kern-checkout>/config/project-scratch-def.json -a ${SF_SUBSCRIBER_ORG_ALIAS} -v DevHub -y 30 --wait 10
sf package install -o $SF_SUBSCRIBER_ORG_ALIAS --package <NewSubscriberPackageVersionId> --wait 15 --no-prompt
rm -f release-testing/e2e/.auth/state.json release-testing/e2e/.auth/instance.json
```

Deleting the `.auth/` files is a safety net. Playwright's `globalSetup` rewrites both of them the next time you run `npm run test:e2e`, so the test run itself is fine either way. The risk is a development workflow that calls the helpers directly with `node` before that next run: without the clear, it could pick up a stale instance URL or expired login cookies from the org you just deleted.

---

## Salesforce Lightning Challenges

A handful of things about Lightning trip up browser automation and make tests flaky if you do not know about them. The good news: each has a known fix. The sections below follow the same shape every time, so you can scan for the symptom you are hitting: the problem, why it happens, and the fix that works.

### Shadow DOM

**Problem:** Lightning Web Components render inside Shadow DOM, making elements invisible to standard CSS selectors.

**Why:** LWC uses native Shadow DOM for style and DOM encapsulation. Standard Playwright selectors can't pierce
shadow boundaries.

**Solution:** Playwright's default `locator()` pierces shadow DOM automatically. Use standard CSS selectors:

```javascript
await page.locator('lightning-formatted-text').first().textContent();

await page.locator('lightning-input input').fill('value');
```

For deeply nested components, chain locators:

```javascript
const card = page.locator('lightning-card').filter({hasText: 'Account Details'});
const field = card.locator('lightning-formatted-text').first();
```

### Spinners and Loading States

**Problem:** Interacting with elements while a spinner is visible causes flaky tests.

**Why:** Lightning shows spinners during server calls. The DOM is present but not interactive.

**Solution:** Wait for spinners to disappear before interacting:

```javascript
const {waitForSpinnerGone} = require('../helpers/wait-helpers');

await waitForSpinnerGone(page);
await page.locator('button').click();
```

The helper waits up to 2 seconds for a spinner to appear, then waits for it to disappear. If no spinner appears,
it continues immediately.

### Toasts

**Problem:** Toast notifications appear briefly and auto-dismiss, making assertions unreliable.

**Why:** Salesforce toasts have a ~5 second display time. If the assertion runs after the toast disappears, the
test fails.

**Solution:** Use `waitForToastMessage()` which waits for the toast to appear with specific text:

```javascript
const {waitForToastMessage} = require('../helpers/wait-helpers');

await page.locator('button[name="SaveEdit"]').click();
await waitForToastMessage(page, 'Account was saved');
```

To dismiss a toast (preventing it from blocking other elements):

```javascript
const {dismissToast} = require('../helpers/wait-helpers');

await dismissToast(page);
```

### Navigation and Page Loading

**Problem:** `page.goto()` resolves before Lightning finishes rendering. Interacting immediately causes timeouts.

**Why:** Lightning loads in stages: the DOM first, then the components, then the data. `domcontentloaded` fires at the very start of that.

**Solution:** Use navigation helpers that wait for Lightning-specific indicators:

```javascript
const {navigateToRecord, navigateToApp} = require('../helpers/sf-navigation');

await navigateToRecord(page, recordId);

await navigateToApp(page, 'kern__Kern');
```

These helpers wait for `one-app-nav-bar` (navigation loaded) and page-specific indicators (record layout,
list view manager) before returning.

### List Views

**Problem:** List views load asynchronously. The table might be empty or still loading when assertions run.

**Why:** Lightning fetches list view data via a separate API call after the page structure loads.

**Solution:** Wait for the list view component and spinner to finish:

```javascript
const {waitForListView} = require('../helpers/wait-helpers');

await navigateToAppItem(page, 'Account');
await waitForListView(page);

const rows = page.locator('table tbody tr');
await expect(rows.first()).toBeVisible();
```

### Record Pages

**Problem:** Record page fields render asynchronously. The highlights panel loads before detail sections.

**Why:** Lightning record pages use multiple components that load independently.

**Solution:** Wait for the record page layout to attach:

```javascript
const {waitForRecordPage} = require('../helpers/wait-helpers');

await navigateToRecord(page, recordId);
await waitForRecordPage(page);

await expect(page.getByText('Account Name')).toBeVisible();
```

### Modals

**Problem:** Modal animations and delayed rendering cause interaction failures.

**Why:** SLDS modals use CSS transitions. The DOM element exists before the animation completes.

**Solution:** Wait for the modal to be visible, then interact:

```javascript
const {waitForModal} = require('../helpers/wait-helpers');

await page.locator('button').filter({hasText: 'New'}).click();
await waitForModal(page);

await page.locator('lightning-input[field-name="Name"] input').fill('New Account');
```

### Combobox and Picklist

**Problem:** Picklist options load dynamically when the combobox opens. Clicking an option before it renders fails.

**Why:** Lightning combobox fetches options on demand and renders them in a dropdown overlay.

**Solution:** Click to open, wait for options, then select:

```javascript
const {COMBOBOX_OPTION} = require('../helpers/sf-selectors');

await page.locator('lightning-combobox[field-name="Industry"] button').click();
await page.locator(COMBOBOX_OPTION).filter({hasText: 'Technology'}).click();
```

---

## Helper Library Reference

### sf-auth.js

Authentication and session management.

| Export                      | Type             | Description                                                                                                       |
|-----------------------------|------------------|-------------------------------------------------------------------------------------------------------------------|
| `ORG_ALIAS`                 | `string`         | Hardcoded constant in `sf-auth.js:5`; rename your local alias with `sf alias set` or fork the helper to change it |
| `getFrontdoorUrl()`         | `function`       | Returns one-time frontdoor URL from `sf org open`                                                                 |
| `getInstanceUrl()`          | `function`       | Returns org instance URL (e.g., `https://example.my.salesforce.com`)                                              |
| `reauthenticate(page)`      | `async function` | Re-authenticates via frontdoor URL in the current page                                                            |
| `ensureAuthenticated(page)` | `async function` | Checks if page is on Salesforce; re-authenticates if not                                                          |

**`getFrontdoorUrl()`**

```javascript
const {getFrontdoorUrl} = require('../helpers/sf-auth');
const url = getFrontdoorUrl();
```

- Calls `sf org open -o <ORG_ALIAS> --url-only -r` (substituting the value of the `ORG_ALIAS` constant)
- Extracts the URL from stdout using regex
- Throws if no URL found (CLI not authenticated, wrong alias)
- Timeout: 30 seconds

**`getInstanceUrl()`**

```javascript
const {getInstanceUrl} = require('../helpers/sf-auth');
const instanceUrl = getInstanceUrl();
```

- Calls `sf org display -o <ORG_ALIAS> --json` (substituting the value of the `ORG_ALIAS` constant)
- Strips ANSI codes and parses JSON
- Returns `result.result.instanceUrl`
- Timeout: 30 seconds

**`reauthenticate(page)`**

```javascript
const {reauthenticate} = require('../helpers/sf-auth');
await reauthenticate(page);
```

- Gets a fresh frontdoor URL
- Navigates the page to the frontdoor URL
- Waits for redirect away from `/secur/frontdoor.jsp`
- Waits 2 seconds for session stabilization

**`ensureAuthenticated(page)`**

```javascript
const {ensureAuthenticated} = require('../helpers/sf-auth');
await ensureAuthenticated(page);
```

- Checks current page URL for `.salesforce.com` or `.force.com`
- Skips if already authenticated
- Calls `reauthenticate()` if on login page or non-Salesforce URL

### sf-cli.js

Salesforce CLI commands for data operations.

| Export                 | Signature                                  | Description                       |
|------------------------|--------------------------------------------|-----------------------------------|
| `executeAnonymousApex` | `(apex, options?) → string`                | Executes anonymous Apex code      |
| `soqlQuery`            | `(query, options?) → Array`                | Runs SOQL query, returns records  |
| `createRecord`         | `(sobjectType, values, options?) → object` | Creates a record via CLI          |
| `deleteRecord`         | `(sobjectType, recordId, options?) → void` | Deletes a record by ID            |
| `deployMetadata`       | `(sourcePath, options?) → object`          | Deploys metadata from a directory |

**`executeAnonymousApex(apex, options?)`**

```javascript
const {executeAnonymousApex} = require('../helpers/sf-cli');
const output = executeAnonymousApex(`
	Account a = new Account(Name = 'Test');
	insert a;
`);
```

- Writes Apex to a temp file in `/tmp/`, runs `sf apex run`, deletes temp file
- Returns raw CLI output as string
- Options: `{timeout: 60_000}` (default)

**`soqlQuery(query, options?)`**

```javascript
const {soqlQuery} = require('../helpers/sf-cli');
const accounts = soqlQuery("SELECT Id, Name FROM Account WHERE Name = 'Test'");
const toolingRecords = soqlQuery('SELECT Id FROM ApexClass', {tooling: true});
```

- Runs `sf data query --json`, strips ANSI codes, parses JSON
- Returns `result.records` array (empty array if no results)
- Options: `{tooling: false, timeout: 30_000}`
- **Namespace note:** Use `kern__FieldName__c` for KernDX custom fields

**`createRecord(sobjectType, values, options?)`**

```javascript
const {createRecord} = require('../helpers/sf-cli');
const result = createRecord('Account', {Name: 'E2E Corp', Industry: 'Technology'});
const accountId = result.id;
```

- Runs `sf data create record`
- Returns parsed JSON result with `.id` property
- Options: `{timeout: 30_000}`

**`deleteRecord(sobjectType, recordId, options?)`**

```javascript
const {deleteRecord} = require('../helpers/sf-cli');
deleteRecord('Account', accountId);
```

- Runs `sf data delete record`
- No return value
- Options: `{timeout: 30_000}`

**`deployMetadata(sourcePath, options?)`**

```javascript
const {deployMetadata} = require('../helpers/sf-cli');
deployMetadata('../force-app/main/default/customMetadata');
```

- Runs `sf project deploy start` with `--ignore-conflicts --wait ${waitMinutes}` so the CLI returns a completed deploy payload rather than an async deploy id
- Returns parsed JSON result
- Options: `{timeout: 120_000, waitMinutes: 10}`
- The path is relative to the `e2e/` working directory, so use `../force-app/...` to reach the outer SFDX project's source tree

### sf-navigation.js

Lightning page navigation with authentication checks.

| Export                  | Signature                         | Description                        |
|-------------------------|-----------------------------------|------------------------------------|
| `navigateToApp`         | `(page, appDeveloperName) → void` | Navigate to a Lightning app        |
| `navigateToAppItem`     | `(page, itemName) → void`         | Navigate to an object list view    |
| `navigateToRecord`      | `(page, recordId) → void`         | Navigate to a record page          |
| `clickNavTab`           | `(page, tabName) → void`          | Click a navigation tab by title    |
| `navigateToSetup`       | `(page, setupPath) → void`        | Navigate to a setup page           |
| `waitForLightningReady` | `(page) → void`                   | Wait for Lightning nav bar to load |
| `waitForPageLoad`       | `(page) → void`                   | Wait for page content to attach    |
| `getBaseUrl`            | `(page) → string`                 | Extract base URL from current page |

**`navigateToApp(page, appDeveloperName)`**

```javascript
const {navigateToApp} = require('../helpers/sf-navigation');

await navigateToApp(page, 'kern__Kern');

await navigateToApp(page, 'standard__LightningService');
```

- Calls `ensureAuthenticated()` first
- Navigates to `/lightning/app/${appDeveloperName}`
- Waits for Lightning nav bar via `waitForLightningReady()`
- For managed package apps, use `namespace__AppName` format

**`navigateToRecord(page, recordId)`**

```javascript
const {navigateToRecord} = require('../helpers/sf-navigation');
await navigateToRecord(page, '001xx000003DGb0AAG');
```

- Navigates to `/lightning/r/${recordId}/view`
- Waits for page content via `waitForPageLoad()`
- Works with any SObject type, because the record ID determines the page layout

**`clickNavTab(page, tabName)`**

```javascript
const {clickNavTab} = require('../helpers/sf-navigation');
await clickNavTab(page, 'Log Entries');
```

- Finds the tab by `title` attribute in the nav bar
- Clicks the tab and waits for page load
- The `tabName` must match the tab's visible label exactly

### wait-helpers.js

Wait strategies for Lightning-specific UI patterns.

| Export                | Signature                               | Description                               |
|-----------------------|-----------------------------------------|-------------------------------------------|
| `waitForSpinnerGone`  | `(page, timeout?) → void`               | Wait for spinner to appear then disappear |
| `waitForToast`        | `(page, timeout?) → void`               | Wait for any toast notification           |
| `waitForToastMessage` | `(page, expectedText, timeout?) → void` | Wait for toast with specific text         |
| `dismissToast`        | `(page) → void`                         | Close visible toast notification          |
| `waitForRecordPage`   | `(page, timeout?) → void`               | Wait for record page layout               |
| `waitForListView`     | `(page, timeout?) → void`               | Wait for list view table                  |
| `waitForModal`        | `(page, timeout?) → void`               | Wait for modal dialog                     |
| `pollUntil`           | `(page, conditionFn, options?) → any`   | Poll a condition until true or timeout    |

**`pollUntil(page, conditionFn, options?)`**

```javascript
const {pollUntil} = require('../helpers/wait-helpers');

const record = await pollUntil(page, () =>
{
	const records = soqlQuery("SELECT Id FROM kern__LogEntry__c WHERE kern__ShortMessage__c = 'test' LIMIT 1");
	return records.length > 0 ? records[0] : null;
}, {interval: 5000, timeout: 60_000, message: 'Log entry not created'});
```

- Calls `conditionFn()` every `interval` milliseconds
- Returns the truthy result when condition is met
- Throws with `message` if `timeout` is reached
- Options: `{interval: 5000, timeout: 120_000, message: 'Condition not met'}`

### sf-selectors.js

Reusable CSS selectors for Lightning UI components. Import individual selectors:

```javascript
const {TOAST, SPINNER, NAV_BAR, RECORD_HEADER} = require('../helpers/sf-selectors');
```

<details>
<summary>Every selector constant</summary>

| Constant            | Selector                | Matches                      |
|---------------------|-------------------------|------------------------------|
| `TOAST`             | Toast container icons   | Any toast notification       |
| `TOAST_SUCCESS`     | Success icon in toast   | Success toast specifically   |
| `TOAST_ERROR`       | Error icon in toast     | Error toast specifically     |
| `TOAST_MESSAGE`     | Toast message text      | Toast content span           |
| `TOAST_CLOSE`       | Toast close button      | Dismiss button               |
| `SPINNER`           | Lightning spinner       | Loading indicator            |
| `MODAL`             | Modal dialog            | SLDS modal container         |
| `MODAL_FOOTER`      | Modal footer            | Modal action buttons area    |
| `LIST_VIEW`         | List view table/header  | List view component          |
| `LIST_VIEW_RECORDS` | Table body rows         | Individual list view records |
| `RECORD_HEADER`     | Record highlights panel | Record page header section   |
| `RECORD_DETAIL`     | Record layout           | Record page detail section   |
| `RECORD_TAB`        | Record page tabs        | Tab navigation links         |
| `NAV_BAR`           | App navigation bar      | Top-level nav component      |
| `NAV_BAR_ITEM`      | Navigation tab items    | Individual nav tabs          |
| `COMBOBOX_OPTION`   | Combobox dropdown items | Picklist/combobox options    |
| `DATATABLE_ROW`     | Data table rows         | Rows in lightning-datatable  |

</details>

---

## Page Object Patterns

### Why Page Objects for Salesforce

A Lightning page has a deeply nested DOM, auto-generated class names, and a component tree that shifts at runtime. Pin a test directly to those details and a single Salesforce change can break it. A page object solves that: it keeps all the locators for a page in one class. When Salesforce changes the DOM, you fix that one file instead of hunting through every test that touched the page.

### Base Structure

```javascript
class SalesforcePage
{
	constructor(page)
	{
		this.page = page;
	}

	async navigate()
	{
		throw new Error('Subclass must implement navigate()');
	}
}

module.exports = SalesforcePage;
```

### [Locator Strategies](https://playwright.dev/docs/locators)

Use these selectors in order of preference:

| Strategy                | Example                                    | Reliability                                |
|-------------------------|--------------------------------------------|--------------------------------------------|
| `getByText()`           | `page.getByText('Account Name')`           | High: visible text rarely changes         |
| `getByRole()`           | `page.getByRole('button', {name: 'Save'})` | High: semantic roles are stable           |
| Component tag           | `page.locator('lightning-formatted-text')` | Medium: LWC tag names are stable          |
| `field-label` attribute | `page.locator('[field-label="Industry"]')` | Medium: field labels can change           |
| CSS class               | `page.locator('.slds-page-header__title')` | Low: SLDS classes change between releases |

> **SLDS release impact:** Salesforce updates SLDS classes with each major release (Spring, Summer, Winter).
> CSS-class-based selectors that work today may break after a platform upgrade. This is the primary reason to
> prefer `getByText()`, `getByRole()`, and Lightning component tags, which stay stable across releases.

### Dynamic Content Handling

Use `.filter()` to narrow results when multiple elements match:

```javascript
const techAccount = page.locator('table tbody tr').filter({hasText: 'Technology'});
await expect(techAccount).toBeVisible();
```

Use `.first()` or `.nth(n)` for positional selection:

```javascript
const firstRow = page.locator('table tbody tr').first();
await expect(firstRow).toBeVisible();
```

### Example: List View Page

```javascript
const {navigateToAppItem} = require('../helpers/sf-navigation');
const {waitForListView} = require('../helpers/wait-helpers');
const {LIST_VIEW_RECORDS} = require('../helpers/sf-selectors');

class ListViewPage
{
	constructor(page, objectApiName)
	{
		this.page = page;
		this.objectApiName = objectApiName;
	}

	async navigate()
	{
		await navigateToAppItem(this.page, this.objectApiName);
		await waitForListView(this.page);
	}

	rows()
	{
		return this.page.locator(LIST_VIEW_RECORDS);
	}

	rowWithText(text)
	{
		return this.page.locator(LIST_VIEW_RECORDS).filter({hasText: text});
	}

	async getRowCount()
	{
		return await this.rows().count();
	}
}

module.exports = ListViewPage;
```

### Example: Record Page

```javascript
const {navigateToRecord} = require('../helpers/sf-navigation');
const {waitForRecordPage} = require('../helpers/wait-helpers');
const {RECORD_TAB} = require('../helpers/sf-selectors');

class RecordPage
{
	constructor(page)
	{
		this.page = page;
	}

	async navigate(recordId)
	{
		await navigateToRecord(this.page, recordId);
		await waitForRecordPage(this.page);
	}

	highlightsField(text)
	{
		return this.page.locator('records-lwc-highlights-panel').getByText(text);
	}

	detailField(label)
	{
		return this.page.locator(`records-record-layout-item[field-label="${label}"] lightning-formatted-text, records-record-layout-item[field-label="${label}"] lightning-formatted-url`).first();
	}

	tab(tabName)
	{
		return this.page.locator(RECORD_TAB).filter({hasText: tabName});
	}

	async clickTab(tabName)
	{
		await this.tab(tabName).click();
	}
}

module.exports = RecordPage;
```

### Example: Custom LWC Page

For testing custom LWC components embedded in Lightning pages:

```javascript
const {navigateToApp} = require('../helpers/sf-navigation');
const {waitForSpinnerGone} = require('../helpers/wait-helpers');

class CustomDashboardPage
{
	constructor(page)
	{
		this.page = page;
	}

	async navigate()
	{
		await navigateToApp(this.page, 'c__MyApp');
		await waitForSpinnerGone(this.page);
	}

	component(tagName)
	{
		return this.page.locator(tagName);
	}

	async getComponentText(tagName)
	{
		return await this.component(tagName).textContent();
	}
}

module.exports = CustomDashboardPage;
```

---

## Testing Common Salesforce Features

This section is a recipe book. Each entry is a thing you commonly need to verify in a Salesforce app, with a short, copy-ready test. The recurring shape is the same throughout: set the data up through the CLI, drive the browser only to check what the user sees.

### Record CRUD and Field Verification

Create a record via CLI, verify its fields render on the record page:

```javascript
const {test, expect} = require('@playwright/test');
const {createRecord, deleteRecord} = require('../helpers/sf-cli');
const {navigateToRecord} = require('../helpers/sf-navigation');
const {waitForRecordPage} = require('../helpers/wait-helpers');

test.describe.serial('Account Record Page', () =>
{
	let accountId;

	test.afterAll(async () =>
	{
		if(accountId) { deleteRecord('Account', accountId); }
	});

	test('should display all fields correctly', async ({page}) =>
	{
		const result = createRecord('Account', {Name: 'Acme Corp', Industry: 'Technology', Phone: '555-0100'});
		accountId = result.id;

		await navigateToRecord(page, accountId);
		await waitForRecordPage(page);

		await expect(page.getByText('Acme Corp').first()).toBeVisible({timeout: 15_000});
		await expect(page.getByText('Technology').first()).toBeVisible();
		await expect(page.getByText('555-0100').first()).toBeVisible();
	});
});
```

### Trigger Side Effects

If you have a trigger action that sets field defaults (e.g., from the
[Trigger Actions Fast Start](Fast%20Start%20-%20Trigger%20Actions.md)), verify the side effect via SOQL then
confirm through the UI:

```javascript
test('should set defaults via trigger action', async ({page}) =>
{
	executeAnonymousApex(`
		Account a = new Account(Name = 'Trigger Test', Phone = '555-0200');
		insert a;
	`);

	const records = soqlQuery(
		"SELECT Id, Industry FROM Account WHERE Name = 'Trigger Test' ORDER BY CreatedDate DESC LIMIT 1"
	);
	expect(records.length).toBeGreaterThan(0);
	expect(records[0].Industry).toBe('Technology');

	await navigateToRecord(page, records[0].Id);
	await waitForRecordPage(page);
	await expect(page.getByText('Technology').first()).toBeVisible({timeout: 15_000});
});
```

Replace `Industry` and `'Technology'` with whatever field and value your trigger action sets.

### Validation Error Messages

Verify that validation rules show error messages in the UI:

```javascript
test('should show validation error on save', async ({page}) =>
{
	const result = createRecord('Account', {Name: 'Validation Test'});
	await navigateToRecord(page, result.id);
	await waitForRecordPage(page);

	await page.locator('button[name="Edit"]').click();
	await page.locator('lightning-input[field-name="Phone"] input').fill('');
	await page.locator('button[name="SaveEdit"]').click();

	await waitForToastMessage(page, 'Review the errors');
});
```

### List View Filtering

Navigate to a list view and verify records are visible:

```javascript
test('should display accounts in list view', async ({page}) =>
{
	await navigateToAppItem(page, 'Account');
	await waitForListView(page);

	const rows = page.locator('table tbody tr');
	await expect(rows.first()).toBeVisible({timeout: 15_000});
});
```

### Related Lists

Navigate to a record page and verify related list content:

```javascript
test('should show related contacts', async ({page}) =>
{
	await navigateToRecord(page, accountId);
	await waitForRecordPage(page);

	const relatedTab = page.locator('lightning-tab-bar li a').filter({hasText: 'Related'});
	await relatedTab.click();

	await expect(page.getByText('Contacts')).toBeVisible({timeout: 15_000});
});
```

### LWC Component Interaction

Interact with a custom LWC component on a Lightning page:

```javascript
test('should interact with custom component', async ({page}) =>
{
	await navigateToApp(page, 'kern__Kern');
	await waitForSpinnerGone(page);

	const component = page.locator('kern-health-check');
	await expect(component).toBeVisible({timeout: 30_000});

	const statusItems = component.locator('.health-check-item');
	const count = await statusItems.count();
	expect(count).toBeGreaterThan(0);
});
```

### Toast Assertions

Verify toast notifications after actions:

```javascript
test('should show success toast after save', async ({page}) =>
{
	await page.locator('button[name="SaveEdit"]').click();
	await waitForToastMessage(page, 'was saved');

	const {TOAST_SUCCESS} = require('../helpers/sf-selectors');
	await expect(page.locator(TOAST_SUCCESS)).toBeVisible();
});
```

### Modal Workflows

Test a create flow in a modal dialog:

```javascript
test('should create record via modal', async ({page}) =>
{
	await navigateToAppItem(page, 'Account');
	await waitForListView(page);

	await page.locator('button').filter({hasText: 'New'}).click();
	await waitForModal(page);

	await page.locator('lightning-input[field-name="Name"] input').fill('Modal Test Account');
	await page.locator('button').filter({hasText: 'Save'}).last().click();

	await waitForToastMessage(page, 'was created');
});
```

### Log Entry Verification

Emit a log entry through KernDX, then verify it renders on its record page. The test uses `pollUntil` because `kern.LOG_Builder` publishes through a platform event, so the record is created asynchronously and is not there the instant the Apex returns:

```javascript
test('should display log entry in Kern app', async ({page}) =>
{
	executeAnonymousApex(`
		kern.LOG_Builder.build()
			.info('E2E Playwright Verification')
			.at('E2E_Test.logEntry')
			.emit();
	`);

	const log = await pollUntil(page, () =>
	{
		const logs = soqlQuery(
			"SELECT Id FROM kern__LogEntry__c WHERE kern__ShortMessage__c = 'E2E Playwright Verification' ORDER BY CreatedDate DESC LIMIT 1"
		);
		return logs.length > 0 ? logs[0] : null;
	}, {interval: 3000, timeout: 30_000, message: 'Log entry not created'});

	await navigateToRecord(page, log.Id);
	await waitForRecordPage(page);
	await expect(page.getByText('E2E Playwright Verification').first()).toBeVisible({timeout: 15_000});
});
```

### API Call Verification

Verify that an API call was logged after invoking a web service:

```javascript
test('should log API call record', async ({page}) =>
{
	// API_Echo validates that the REST body is non-empty; seed a RestContext before dispatching.
	executeAnonymousApex(`
		RestRequest request = new RestRequest();
		request.requestBody = Blob.valueOf('{"message":"E2E"}');
		RestResponse response = new RestResponse();
		RestContext.request = request;
		RestContext.response = response;
		kern.API_Dispatcher.processInboundService('kern.API_Echo');
	`);

	const calls = soqlQuery(
		"SELECT Id, kern__ServiceName__c, kern__Status__c FROM kern__ApiCall__c ORDER BY CreatedDate DESC LIMIT 1"
	);
	expect(calls.length).toBeGreaterThan(0);
	expect(calls[0].kern__Status__c).toBe('Completed');

	await navigateToRecord(page, calls[0].Id);
	await waitForRecordPage(page);
	await expect(page.getByText('Service Name')).toBeVisible({timeout: 15_000});
});
```

### Streaming and Change Data Capture Monitor

KernDX ships a live **Streaming Event Monitor** (the `kern-streaming-monitor` component) that subscribes to Platform Events, Change Data Capture channels, PushTopics, and Generic events. Launch it from the **Kern Home** tool cards. Its controls carry stable `data-testid` hooks, so target those rather than SLDS classes (which shift between releases). The test pattern is the same as any event test: subscribe to a channel, emit an event from outside the page, then assert the received-event count goes up.

```javascript
const {test, expect} = require('@playwright/test');
const {navigateToApp} = require('../helpers/sf-navigation');
const {executeAnonymousApex} = require('../helpers/sf-cli');
const {waitForSpinnerGone, pollUntil} = require('../helpers/wait-helpers');

async function openStreamingMonitor(page)
{
	await navigateToApp(page, 'kern__Kern');
	await page.locator('[data-testid="kern-home-root"] lightning-button[data-key="streamingMonitor"]').click();
	await waitForSpinnerGone(page);
}

async function pickOption(page, testId, label)
{
	const combobox = page.locator(`[data-testid="${testId}"]`).first();
	await combobox.locator('input, button').first().click();
	await page.getByRole('option', {name: label}).first().click();
	await page.keyboard.press('Escape');
}

async function selectChannel(page, eventType, eventName)
{
	await pickOption(page, 'event-type', eventType);
	await pickOption(page, 'event-name', eventName);
}

async function eventCount(page)
{
	// The "Showing N events" badge is view-independent — the monitor defaults to the
	// timeline view, where the per-row datatable is not rendered. Read the badge, not rows.
	const badge = page.getByText(/Showing \d+ event/).first();
	if(!(await badge.isVisible().catch(() => false))) { return 0; }
	const match = (await badge.textContent()).match(/Showing (\d+)/);
	return match ? parseInt(match[1], 10) : 0;
}
```

Subscribe to the Log Entry Event platform-event channel, emit a log entry, and assert the monitor receives it. `kern.LOG_Builder`
publishes through a platform event, so the row arrives asynchronously: poll for it rather than checking once.

```javascript
test.describe.serial('Streaming Event Monitor', () =>
{
	test('surfaces a Log Entry Event after emit', async ({page}) =>
	{
		test.setTimeout(120_000);
		await openStreamingMonitor(page);

		await page.getByText('Subscribe to a channel', {exact: true}).click();
		await selectChannel(page, 'Custom Platform event', 'Log Entry Event');
		await page.locator('[data-testid="subscribe-button"]').click();
		await waitForSpinnerGone(page);

		executeAnonymousApex(`
			kern.LOG_Builder.build()
				.info('Streaming monitor E2E')
				.emitAt('E2E.streamingCheck');
		`);

		await pollUntil(page, async () => (await eventCount(page)) > 0,
			{interval: 2000, timeout: 30_000, message: 'No streaming event received'});
	});
});
```

For Change Data Capture, subscribe to the **Change Data Capture event** type, pick the object's change event, then commit a DML change.
The platform delivers the change event to the live subscription, so give the CometD handshake a moment to settle before you commit, then assert the
received-event count increases:

```javascript
test('surfaces a change event after a record commit', async ({page}) =>
{
	test.setTimeout(120_000);
	await openStreamingMonitor(page);

	await page.getByText('Subscribe to a channel', {exact: true}).click();
	await selectChannel(page, 'Change Data Capture event', 'Change Event: Account');
	await page.locator('[data-testid="subscribe-button"]').click();
	await waitForSpinnerGone(page);

	// Replay -1 only delivers events published after the subscription is live.
	await page.waitForTimeout(4000);
	const before = await eventCount(page);

	executeAnonymousApex("insert new Account(Name = 'CDC E2E');");

	await pollUntil(page, async () => (await eventCount(page)) > before,
		{interval: 2000, timeout: 40_000, message: 'No change event delivered'});
});
```

> **CDC prerequisite:** the object must have a Change Data Capture entity selected (Setup > Change Data Capture). `Change Event: Account`
> only appears in the channel list once Account CDC is enabled, because the monitor lists only real change-event entities.

The monitor can also publish an event for you: open **Publish an event**, fill the `[data-testid="publish-payload"]` textarea, and click
`[data-testid="publish-button"]`. Reset subscriptions between runs with `[data-testid="unsubscribe-all"]`.

### Event Usage Metrics

The Streaming Event Monitor's **Event usage metrics** view shows how many platform events your org published and delivered, charted from the `PlatformEventUsageMetric` data. It gives you a chart/table toggle, a date-range preset, a series legend, and a granularity switch.

Daily granularity always works. Hourly and 15-minute granularity need **Enhanced Usage Metrics** turned on for the org, so a plain org shows those two disabled with a notice explaining why. The controls carry `data-spec-id` hooks (the chart bars use `[data-testid="usage-bar"]`):

```javascript
test('Event usage metrics renders its controls', async ({page}) =>
{
	test.setTimeout(120_000);
	await openStreamingMonitor(page);
	await page.getByText('Event usage metrics', {exact: true}).click();
	await page.locator('[data-spec-id="usage-card-title"]').waitFor({state: 'visible'});
	await waitForSpinnerGone(page);

	// Daily granularity is selected by default; sub-daily needs Enhanced Usage Metrics.
	await expect(page.locator('[data-spec-id="usage-granularity-daily"]')).toHaveAttribute('aria-pressed', 'true');
	await expect(page.locator('[data-spec-id="usage-count-badge"]')).toBeVisible();
	await expect(page.locator('[data-spec-id="usage-range-preset"]')).toBeVisible();

	// Toggle from the chart to the table rendering of the same data.
	await page.locator('[data-spec-id="usage-view-table"]').click();
	await expect(page.locator('[data-spec-id="usage-table"]')).toBeVisible();
	await page.locator('[data-spec-id="usage-view-chart"]').click();
	await expect(page.locator('[data-spec-id="usage-table"]')).toBeHidden();
});
```

> **Aggregation lag:** the platform fills in `PlatformEventUsageMetric` rows on a delay (daily rows can take hours), so a
> freshly-seeded org may show the empty state and still be working correctly. Assert on the controls and the chart/table toggle (always present) rather than
> on a specific bar count.

---

## Data Management

### Creating Test Data

**Rule: only use the browser to test the browser.** Set up all test data through the CLI helpers or anonymous
Apex, never by filling in browser forms. Creating data through the browser is slow and flaky, and it ties your data setup
to the page layout, so a layout change can break setup that has nothing to do with what you are testing. Keep browser interaction for the assertions you actually care about.

Use CLI helpers for data creation:

```javascript
const result = createRecord('Account', {Name: 'Test', Industry: 'Technology'});
const accountId = result.id;
```

For complex data with relationships, use anonymous Apex:

```javascript
executeAnonymousApex(`
	Account a = new Account(Name = 'Parent Corp');
	insert a;
	Contact c = new Contact(FirstName = 'Test', LastName = 'User', AccountId = a.Id);
	insert c;
`);
```

### SOQL Queries with Namespace

KernDX custom objects and fields require the `kern__` namespace prefix in SOQL:

```javascript
const logs = soqlQuery('SELECT Id, kern__ShortMessage__c FROM kern__LogEntry__c LIMIT 10');

const calls = soqlQuery('SELECT Id, kern__ServiceName__c FROM kern__ApiCall__c WHERE kern__Status__c = \'Completed\'');
```

Standard objects and fields don't need a prefix:

```javascript
const accounts = soqlQuery("SELECT Id, Name, Industry FROM Account WHERE Name LIKE 'E2E%'");
```

### Cleanup Patterns

Always clean up test data to prevent interference between test runs:

```javascript
test.describe.serial('My Feature', () =>
{
	let recordId;

	test.afterAll(async () =>
	{
		if(recordId) { deleteRecord('Account', recordId); }
	});

	test('creates and verifies record', async ({page}) =>
	{
		const result = createRecord('Account', {Name: 'Cleanup Test'});
		recordId = result.id;
	});
});
```

For bulk cleanup:

```javascript
test.afterAll(async () =>
{
	const records = soqlQuery("SELECT Id FROM Account WHERE Name LIKE 'E2E%'");
	for(const record of records)
	{
		deleteRecord('Account', record.Id);
	}
});
```

### Deploying Metadata

Deploy Custom Metadata Type records or other metadata before tests:

```javascript
deployMetadata('force-app/main/default/customMetadata');
```

### Custom Metadata States

Toggle metadata-driven features by deploying updated records:

```javascript
executeAnonymousApex(`
	kern.TRG_Base.bypassAction('TRG_AccountSetDefaults');
`);

executeAnonymousApex(`
	kern.TRG_Base.clearActionBypass('TRG_AccountSetDefaults');
`);
```

---

## Debugging

### [Headed Mode](https://playwright.dev/docs/test-cli)

Watch the browser as tests execute:

```bash
npx playwright test --headed
```

Useful for understanding what the test sees, especially when locators fail.

### Debug Mode

Step through tests with the [Playwright Inspector](https://playwright.dev/docs/debug#playwright-inspector):

```bash
npx playwright test --debug
```

The Inspector opens alongside the browser. Click "Step over" to execute one action at a time. Hover over elements in the browser to see their selectors.

### [Trace Viewer](https://playwright.dev/docs/trace-viewer)

Open a trace file from a failed test:

```bash
npx playwright show-trace e2e/test-results/*/trace.zip
```

The trace viewer shows:

- Every action with before/after screenshots
- Network requests and responses
- Console logs
- DOM snapshots at each step

### [Screenshots](https://playwright.dev/docs/screenshots) and [Video](https://playwright.dev/docs/videos)

With `screenshot: 'on'` and `video: 'retain-on-failure'` in the config, Playwright saves:

- **Screenshots:** For every test, in `test-results/<test-name>/`
- **Videos:** Only for failed tests, as `.webm` files in the same directory

### Browser Console

Access console logs from within a test:

```javascript
page.on('console', (msg) =>
{
	if(msg.type() === 'error')
	{
		console.log(`Browser error: ${msg.text()}`);
	}
});
```

### Lightning DOM Inspection

Lightning's Shadow DOM can make element inspection tricky. In headed mode:

1. Right-click the element > Inspect
2. Look for the `lightning-*` or `c-*` component tag
3. Check the `shadowRoot` for child elements
4. Use Playwright's locator, which pierces shadow DOM automatically

Useful DevTools trick: In the Elements panel, enable "Show user agent shadow DOM" in Settings to see all
shadow boundaries.

---

## CI/CD Integration

### GitHub Actions Workflow

Complete workflow for running E2E tests on push:

```yaml
name: E2E Tests
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  e2e:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: 22

      - name: Install Salesforce CLI
        run: npm install -g @salesforce/cli

      - name: Install E2E dependencies
        working-directory: e2e
        run: |
          npm ci
          npx playwright install chromium --with-deps

      - name: Authenticate to Salesforce
        run: echo "${{ secrets.SFDX_AUTH_URL }}" | sf org login sfdx-url --set-default --sfdx-url-stdin --alias ${SF_SUBSCRIBER_ORG_ALIAS}

      - name: Run E2E tests
        working-directory: e2e
        run: npx playwright test

      - name: Upload test results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: e2e-results
          path: e2e/test-results/
          retention-days: 7
```

### Scratch Org Lifecycle

For ephemeral test environments, create a scratch org per CI run:

```yaml
      - name: Create scratch org
        run: |
          sf org create scratch -f config/project-scratch-def.json -a ${SF_SUBSCRIBER_ORG_ALIAS} -v DevHub -y 1 --wait 10
          sf package install -o $SF_SUBSCRIBER_ORG_ALIAS --package 04t... --wait 15 --no-prompt

      - name: Run E2E tests
        working-directory: e2e
        run: npx playwright test

      - name: Delete scratch org
        if: always()
        run: sf org delete scratch -o $SF_SUBSCRIBER_ORG_ALIAS --no-prompt
```

### Session Management in CI

A CI environment starts fresh on every run, so there is never a cached `.auth/state.json`. Global setup logs in for you each time, so authentication just works. A few things are worth setting up deliberately:

- **Auth URL secret:** Generate with `sf org display -o YourOrg --verbose --json` and store the `sfdxAuthUrl`
  field as a GitHub secret
- **Timeout:** CI environments can be slower. Consider increasing `timeout` to `180_000`
- **Headless:** Always `true` in CI (default)
- **Ephemeral orgs:** If your pipeline spins up temporary orgs (scratch orgs, sandboxes), log each one in under the expected alias with
  `sf org login sfdx-url --alias <ORG_ALIAS> ...` on every run, substituting the value of the `ORG_ALIAS` constant from `sf-auth.js:5`. The helper follows the alias, not a URL, so every
  test run targets whichever org is currently registered under that alias. If your release-management tool cannot rename aliases, the alternative is to edit your own copy of the helper to read the alias from an environment variable.

### Artifact Collection

Upload test results as artifacts for debugging failed CI runs:

```yaml
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: e2e-results
          path: e2e/test-results/
          retention-days: 7
```

Artifacts include screenshots, videos (for failures), and trace files.

---

## Best Practices

**Do:**

- Use CLI helpers (`createRecord`, `soqlQuery`) for data setup, rather than filling forms through the browser
- Use SOQL for data assertions: it is faster and more reliable than reading field values from the DOM
- Clean up test data in `test.afterAll` so data does not pile up across runs
- Use `test.describe.serial`, because Salesforce tests must run in order within a describe block
- Use page objects for pages you test often: it keeps locator maintenance in one place
- Wait for Lightning-specific indicators: nav bar, record page, list view, spinner gone
- Use `getByText()` and `getByRole()`: they hold up better than CSS selectors
- Run tests against sandboxes or scratch orgs, never production
- Capture traces on failure with `trace: 'retain-on-failure'` so you have something to debug from

**Don't:**

- Don't lean on `page.waitForTimeout()` as your main wait strategy; use the helper functions instead
- Don't use parallel workers with a shared session: the CSRF token conflicts cause flakiness
- Don't retry flaky tests; fix the root cause in the wait logic
- Don't hardcode record IDs; create records in setup and reference them by variable
- Don't rely on CSS class names, because SLDS classes change between Salesforce releases
- Don't test Salesforce platform behaviour; focus on your custom features

**Scaling beyond serial execution:** Running one test at a time works well until the suite gets large. A typical serial suite hits a ceiling around 100+ tests, which is roughly a 30 minute feedback loop at about 20 seconds per test. The reason you cannot simply run them in parallel is the shared `sid` session cookie: parallel workers reusing the one cookie generate conflicting CSRF and Aura security tokens.

The way around it is to give each worker its own login. Authenticate several distinct Salesforce users, then assign each one to a separate Playwright worker with its own `storageState` file. Now every worker has an independent session cookie, so the cross-worker token conflicts disappear. The cost is setup: you have to provision dedicated test users with the right profiles and permission sets.

---

## Anti-Patterns

| Anti-Pattern                                                            | Problem                                      | Better Approach                                                        |
|-------------------------------------------------------------------------|----------------------------------------------|------------------------------------------------------------------------|
| **Flaky selectors**, e.g. `div:nth-child(3) > span`                     | Breaks when layout changes                   | Use `getByText()`, component tags, or `field-label` attributes         |
| **Missing auth checks**: navigating without `ensureAuthenticated()`     | Random failures when session expires         | Use navigation helpers that call `ensureAuthenticated()` automatically |
| **Empty list view assertions**: asserting immediately after navigation  | List data loads asynchronously               | Use `waitForListView()` then assert on rows                            |
| **Deployment propagation**: testing immediately after metadata deploy   | Metadata may not be active yet               | Add a short wait or verify via SOQL after deployment                   |
| **Testing platform internals**: verifying Salesforce standard behaviour  | Wastes time, breaks on platform updates      | Focus on your custom trigger actions, LWC, and API integrations        |
| **Browser-based data creation**: filling forms for test setup           | Slow, flaky, depends on page layout          | Use `createRecord()` or `executeAnonymousApex()` via CLI               |
| **Shared state between tests**: relying on data from previous test      | One failure cascades to all subsequent tests | Each test creates its own data, cleans up in `afterAll`                |

---

## Troubleshooting

| Symptom                                      | Likely Cause                       | Solution                                                                                         |
|----------------------------------------------|------------------------------------|--------------------------------------------------------------------------------------------------|
| `Could not extract frontdoor URL`            | CLI not authenticated              | Run `sf org display -o YourOrgAlias` and re-authenticate if needed                               |
| `Error: Timeout 30000ms exceeded` on nav bar | Lightning not fully loaded         | Increase timeout in `waitForLightningReady`, check network                                       |
| `Error: strict mode violation`               | Multiple elements match locator    | Add `.first()` or use `.filter({hasText: ...})` to narrow                                        |
| `Error: locator.click: Target closed`        | Page navigated during action       | Ensure page is fully loaded before interacting                                                   |
| `ECONNREFUSED`                               | Chromium not installed             | Run `npx playwright install chromium`                                                            |
| Tests pass locally, fail in CI               | Different timing, missing deps     | Add `--with-deps` to Chromium install, increase timeouts                                         |
| SOQL returns empty array                     | Missing namespace prefix           | Use `kern__ObjectName__c` and `kern__FieldName__c`                                               |
| `JSON.parse` error on CLI output             | ANSI colour codes in output        | Helpers strip ANSI automatically; use `soqlQuery()` not raw `execSync`                           |
| Record page shows "Loading..."               | Record not yet committed           | Use `await waitForRecordPage(page)` after navigation (Best Practices bans bare `waitForTimeout`) |
| Toast assertion fails                        | Toast already dismissed            | Use `waitForToastMessage()` which waits for toast to appear                                      |
| Session expired mid-test                     | Long-running test suite            | Call `reauthenticate(page)` in `test.beforeEach`                                                 |
| `ERR_NAME_NOT_RESOLVED`                      | Instance URL changed (scratch org) | Delete `.auth/state.json` and re-run                                                             |
| Screenshots show login page                  | Session state not loaded           | Verify `storageState` path in config matches global setup output                                 |

---

## Related Documentation

| Document                                                                | Description                                           |
|-------------------------------------------------------------------------|-------------------------------------------------------|
| [Fast Start - E2E Testing](Fast%20Start%20-%20E2E%20Testing.md)         | Quick setup guide: get 3 tests passing in 25 minutes  |
| [Fast Start - Trigger Actions](Fast%20Start%20-%20Trigger%20Actions.md) | Build trigger actions to test E2E                     |
| [Fast Start - Logging](Fast%20Start%20-%20Logging.md)                   | Application logging to verify in Kern app             |
| [LWC - Guide](LWC%20-%20Guide.md)                                       | Build LWC components to test E2E                      |
| [Playwright Documentation](https://playwright.dev)                      | Official Playwright reference                         |
| [Playwright Locators](https://playwright.dev/docs/locators)             | Locator strategies and best practices                 |
| [Playwright Trace Viewer](https://playwright.dev/docs/trace-viewer)     | Visual debugging tool                                 |
