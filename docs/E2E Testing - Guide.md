# E2E Testing - Guide

**Framework:** KernDX
**Package Type:** Managed Package

**Target Audience:**
- **Developers** - Building and running Playwright E2E tests against Salesforce orgs with KernDX
- **Architects** - Designing E2E test strategies for Lightning applications
- **QA Engineers** - Automating browser-based verification of Salesforce features

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [Quick Navigation](#quick-navigation)
2. [Overview](#overview)
   - [Why E2E Testing for Salesforce?](#why-e2e-testing-for-salesforce)
   - [Why Playwright?](#why-playwright)
   - [Architecture](#architecture)
   - [Key Design Decisions](#key-design-decisions)
3. [Project Setup](#project-setup)
   - [Directory Structure](#directory-structure)
   - [Dependencies](#dependencies)
   - [Configuration Deep Dive](#configuration-deep-dive)
   - [Org Alias](#org-alias)
4. [Authentication](#authentication)
   - [How Frontdoor URL Works](#how-frontdoor-url-works)
   - [Global Setup Flow](#global-setup-flow)
   - [Session State Reuse](#session-state-reuse)
   - [Re-authentication Mid-Test](#re-authentication-mid-test)
   - [Expired Sessions](#expired-sessions)
   - [Package Upgrade in E2E Context](#package-upgrade-in-e2e-context)
5. [Salesforce Lightning Challenges](#salesforce-lightning-challenges)
   - [Shadow DOM](#shadow-dom)
   - [Spinners and Loading States](#spinners-and-loading-states)
   - [Toasts](#toasts)
   - [Navigation and Page Loading](#navigation-and-page-loading)
   - [List Views](#list-views)
   - [Record Pages](#record-pages)
   - [Modals](#modals)
   - [Combobox and Picklist](#combobox-and-picklist)
6. [Helper Library Reference](#helper-library-reference)
   - [sf-auth.js](#sf-authjs)
   - [sf-cli.js](#sf-clijs)
   - [sf-navigation.js](#sf-navigationjs)
   - [wait-helpers.js](#wait-helpersjs)
   - [sf-selectors.js](#sf-selectorsjs)
7. [Page Object Patterns](#page-object-patterns)
   - [Why Page Objects for Salesforce](#why-page-objects-for-salesforce)
   - [Base Structure](#base-structure)
   - [Locator Strategies](#locator-strategies)
   - [Dynamic Content Handling](#dynamic-content-handling)
   - [Example: List View Page](#example-list-view-page)
   - [Example: Record Page](#example-record-page)
   - [Example: Custom LWC Page](#example-custom-lwc-page)
8. [Testing Common Salesforce Features](#testing-common-salesforce-features)
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
9. [Data Management](#data-management)
   - [Creating Test Data](#creating-test-data)
   - [SOQL Queries with Namespace](#soql-queries-with-namespace)
   - [Cleanup Patterns](#cleanup-patterns)
   - [Deploying Metadata](#deploying-metadata)
   - [Custom Metadata States](#custom-metadata-states)
10. [Debugging](#debugging)
    - [Headed Mode](#headed-mode)
    - [Debug Mode](#debug-mode)
    - [Trace Viewer](#trace-viewer)
    - [Screenshots and Video](#screenshots-and-video)
    - [Browser Console](#browser-console)
    - [Lightning DOM Inspection](#lightning-dom-inspection)
11. [CI/CD Integration](#cicd-integration)
    - [GitHub Actions Workflow](#github-actions-workflow)
    - [Scratch Org Lifecycle](#scratch-org-lifecycle)
    - [Session Management in CI](#session-management-in-ci)
    - [Artifact Collection](#artifact-collection)
12. [Best Practices](#best-practices)
13. [Anti-Patterns](#anti-patterns)
14. [Troubleshooting](#troubleshooting)
15. [Related Documentation](#related-documentation)

</details>

---

## Quick Navigation

| I want to... | Go to |
|--------------|-------|
| Get started quickly | [Fast Start - E2E Testing](Fast%20Start%20-%20E2E%20Testing.md) |
| Understand the authentication flow | [Authentication](#authentication) |
| Handle Lightning-specific challenges | [Salesforce Lightning Challenges](#salesforce-lightning-challenges) |
| Look up a helper function | [Helper Library Reference](#helper-library-reference) |
| Write page objects | [Page Object Patterns](#page-object-patterns) |
| Write tests for a specific feature | [Testing Common Salesforce Features](#testing-common-salesforce-features) |
| Debug a failing test | [Debugging](#debugging) |
| Set up CI/CD | [CI/CD Integration](#cicd-integration) |
| Fix a common issue | [Troubleshooting](#troubleshooting) |

---

## Overview

### Why E2E Testing for Salesforce?

Unit tests (Apex `@IsTest`, LWC Jest) verify individual components in isolation. E2E tests verify the complete user
experience: authentication, page navigation, data rendering, component interaction, and side effects. For Salesforce
applications, E2E tests catch issues that unit tests cannot:

- Lightning page layout rendering after metadata changes
- Trigger side effects visible in the UI after record creation
- Cross-component interactions on record pages
- Toast messages and validation errors shown to users
- Custom LWC behavior when embedded in Lightning pages
- Navigation flows across multiple pages

### Why Playwright?

| Feature | Benefit for Salesforce |
|---------|----------------------|
| [Auto-waiting](https://playwright.dev/docs/actionability) | Handles Lightning's dynamic DOM without explicit sleeps |
| [CSS + text locators](https://playwright.dev/docs/locators) | Works with Lightning component selectors and visible text |
| [Browser contexts](https://playwright.dev/docs/browser-contexts) | Session state management via `storageState` |
| [Trace viewer](https://playwright.dev/docs/trace-viewer) | Visual debugging of Lightning page interactions |
| Cross-browser | Chromium, Firefox, WebKit (Chromium recommended for Salesforce) |
| [Network interception](https://playwright.dev/docs/network) | Mock or monitor Salesforce API calls |

### Architecture

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

| Layer | Purpose |
|-------|---------|
| **Global setup** | Authenticates once, saves session cookies to `.auth/state.json` |
| **Specs** | Test files — run serially in a single browser worker |
| **Helpers** | Reusable functions for auth, CLI, navigation, waiting, and selectors |
| **Browser** | Chromium renders Lightning pages, Playwright interacts with the DOM |
| **sf CLI** | Executes SOQL queries, anonymous Apex, and record CRUD outside the browser |

### Key Design Decisions

1. **Serial execution with single worker** — All tests share a single `sid` session cookie. Parallel browser
   contexts reusing the same cookie generate conflicting CSRF/Aura tokens — one context's page load invalidates
   the token in another, causing "Page Expired" errors and random logouts.

2. **Frontdoor URL authentication** — No stored passwords. `sf org open --url-only` generates a one-time URL
   that authenticates via Salesforce's frontdoor.jsp endpoint.

3. **CLI helpers for data operations** — Creating records, running SOQL, and executing Apex via `sf` CLI is
   faster and more reliable than filling forms through the browser. Use the browser only for verification.

4. **Generous timeouts** — Lightning pages involve multiple network requests and DOM re-renders. Default test
   timeout is 120 seconds, expect timeout is 15 seconds.

> **Extending framework classes from a subscriber org.** Subscriber Apex extends `kern` framework classes via the namespaced public API —
> e.g. `public inherited sharing class CustomTriggerHandler extends kern.TRG_Base implements kern.IF_Trigger.BeforeInsert`. The same
> pattern applies to `kern.SEL_Base` selectors and the `kern.UTIL_*` utilities. See the Triggers, Selectors, and DML Developer Guides
> for long-form treatment.

---

## Project Setup

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

| Setting | Value | Why |
|---------|-------|-----|
| `testDir` | `specs/` | Separates test files from helpers and pages |
| `globalSetup` | `global-setup.js` | Runs authentication before any tests |
| `timeout` | `120_000` | Lightning pages can take 30-60s on first load |
| `expect.timeout` | `15_000` | [Assertions](https://playwright.dev/docs/test-assertions) need time for Lightning re-renders |
| `fullyParallel` | `false` | Shared session cookie causes CSRF token conflicts in parallel |
| `workers` | `1` | Single browser context, single authenticated session |
| `retries` | `0` | Retries mask real issues — fix flakiness in helpers instead |
| `reporter` | `'list'` | Simple output — add `'html'` for detailed reports |
| `storageState` | `.auth/state.json` | Session cookies saved by global setup |
| `viewport` | `1920x1080` | Full desktop layout — Lightning responsive breakpoints matter |
| `screenshot` | `'on'` | Capture screenshot for every test (useful for visual verification) |
| `trace` | `'retain-on-failure'` | Full trace for debugging, only kept for failed tests |
| `video` | `'retain-on-failure'` | Video recording for failed tests |
| `navigationTimeout` | `30_000` | Page.goto and waitForURL timeout |
| `actionTimeout` | `15_000` | Click, fill, and other action timeouts |

### Org Alias

The Playwright suite is bound to a single hard-coded org alias — declared as the `ORG_ALIAS` constant in `release-testing/e2e/helpers/sf-auth.js:5`. The helper does not read any environment variable for the alias; the constant is the only configuration surface.

If your scratch org already uses that alias, no setup is required beyond defaulting your CLI to it:

```bash
sf config set target-org=$SF_SUBSCRIBER_ORG_ALIAS
```

If your org has a different alias, you have two options:

- **Rename the alias** (recommended for one-off subscriber testing): `export SF_SUBSCRIBER_ORG_ALIAS=YourExistingAlias`.
- **Fork the helper**: edit the `ORG_ALIAS` constant in `release-testing/e2e/helpers/sf-auth.js` to match your alias. Tracked via your own fork; not upstreamable.

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
initialize, adding 30+ seconds.

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

1. Delete `.auth/state.json` — global setup regenerates it on the next run
2. Verify CLI authentication: `sf org display -o YourOrgAlias`
3. Check org session timeout settings: Setup > Session Settings > Session Timeout

For long-running test suites (>2 hours), consider lowering the test count per run or calling
`reauthenticate(page)` in `test.beforeEach`.

### Package Upgrade in E2E Context

Beta packages cannot be upgraded in-place. When promoting a new package version, recreate the scratch org and clear the cached auth artifacts:

```bash
sf org delete scratch -o $SF_SUBSCRIBER_ORG_ALIAS --no-prompt
cd /tmp/kern-subscriber && sf org create scratch -f <your-kern-checkout>/config/project-scratch-def.json -a ${SF_SUBSCRIBER_ORG_ALIAS} -v DevHub -y 30 --wait 10
sf package install -o $SF_SUBSCRIBER_ORG_ALIAS --package <NewSubscriberPackageVersionId> --wait 15 --no-prompt
rm -f release-testing/e2e/.auth/state.json release-testing/e2e/.auth/instance.json
```

The `.auth/` file clear is defence-in-depth: Playwright's `globalSetup` refreshes both files on the next `npm run test:e2e` run, but dev workflows that hand-invoke helpers via `node` before the next runner invocation would otherwise see a stale instance URL or expired session cookies from the old org.

---

## Salesforce Lightning Challenges

Lightning's architecture creates specific challenges for browser automation. Each challenge below includes the
problem, why it happens, and the proven solution.

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

**Why:** Lightning loads in stages — DOM first, then components, then data. `domcontentloaded` fires early.

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

| Export | Type | Description |
|--------|------|-------------|
| `ORG_ALIAS` | `string` | Hardcoded constant in `sf-auth.js:5`; rename your local alias with `sf alias set` or fork the helper to change it |
| `getFrontdoorUrl()` | `function` | Returns one-time frontdoor URL from `sf org open` |
| `getInstanceUrl()` | `function` | Returns org instance URL (e.g., `https://example.my.salesforce.com`) |
| `reauthenticate(page)` | `async function` | Re-authenticates via frontdoor URL in the current page |
| `ensureAuthenticated(page)` | `async function` | Checks if page is on Salesforce; re-authenticates if not |

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

| Export | Signature | Description |
|--------|-----------|-------------|
| `executeAnonymousApex` | `(apex, options?) → string` | Executes anonymous Apex code |
| `soqlQuery` | `(query, options?) → Array` | Runs SOQL query, returns records |
| `createRecord` | `(sobjectType, values, options?) → object` | Creates a record via CLI |
| `deleteRecord` | `(sobjectType, recordId, options?) → void` | Deletes a record by ID |
| `deployMetadata` | `(sourcePath, options?) → object` | Deploys metadata from a directory |

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
- Path is relative to the `e2e/` working directory — use `../force-app/...` to reach the outer SFDX project's source tree

### sf-navigation.js

Lightning page navigation with authentication checks.

| Export | Signature | Description |
|--------|-----------|-------------|
| `navigateToApp` | `(page, appDeveloperName) → void` | Navigate to a Lightning app |
| `navigateToAppItem` | `(page, itemName) → void` | Navigate to an object list view |
| `navigateToRecord` | `(page, recordId) → void` | Navigate to a record page |
| `clickNavTab` | `(page, tabName) → void` | Click a navigation tab by title |
| `navigateToSetup` | `(page, setupPath) → void` | Navigate to a setup page |
| `waitForLightningReady` | `(page) → void` | Wait for Lightning nav bar to load |
| `waitForPageLoad` | `(page) → void` | Wait for page content to attach |
| `getBaseUrl` | `(page) → string` | Extract base URL from current page |

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
- Works with any SObject type — the record ID determines the page layout

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

| Export | Signature | Description |
|--------|-----------|-------------|
| `waitForSpinnerGone` | `(page, timeout?) → void` | Wait for spinner to appear then disappear |
| `waitForToast` | `(page, timeout?) → void` | Wait for any toast notification |
| `waitForToastMessage` | `(page, expectedText, timeout?) → void` | Wait for toast with specific text |
| `dismissToast` | `(page) → void` | Close visible toast notification |
| `waitForRecordPage` | `(page, timeout?) → void` | Wait for record page layout |
| `waitForListView` | `(page, timeout?) → void` | Wait for list view table |
| `waitForModal` | `(page, timeout?) → void` | Wait for modal dialog |
| `pollUntil` | `(page, conditionFn, options?) → any` | Poll a condition until true or timeout |

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

| Constant | Selector | Matches |
|----------|----------|---------|
| `TOAST` | Toast container icons | Any toast notification |
| `TOAST_SUCCESS` | Success icon in toast | Success toast specifically |
| `TOAST_ERROR` | Error icon in toast | Error toast specifically |
| `TOAST_MESSAGE` | Toast message text | Toast content span |
| `TOAST_CLOSE` | Toast close button | Dismiss button |
| `SPINNER` | Lightning spinner | Loading indicator |
| `MODAL` | Modal dialog | SLDS modal container |
| `MODAL_FOOTER` | Modal footer | Modal action buttons area |
| `LIST_VIEW` | List view table/header | List view component |
| `LIST_VIEW_RECORDS` | Table body rows | Individual list view records |
| `RECORD_HEADER` | Record highlights panel | Record page header section |
| `RECORD_DETAIL` | Record layout | Record page detail section |
| `RECORD_TAB` | Record page tabs | Tab navigation links |
| `NAV_BAR` | App navigation bar | Top-level nav component |
| `NAV_BAR_ITEM` | Navigation tab items | Individual nav tabs |
| `COMBOBOX_OPTION` | Combobox dropdown items | Picklist/combobox options |
| `DATATABLE_ROW` | Data table rows | Rows in lightning-datatable |

---

## Page Object Patterns

### Why Page Objects for Salesforce

Lightning pages have complex, nested DOM structures with generated class names and dynamic component trees. Page
objects centralize locator logic so that when Salesforce updates its DOM structure, you fix one file instead of
every test.

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

| Strategy | Example | Reliability |
|----------|---------|-------------|
| `getByText()` | `page.getByText('Account Name')` | High — visible text rarely changes |
| `getByRole()` | `page.getByRole('button', {name: 'Save'})` | High — semantic roles are stable |
| Component tag | `page.locator('lightning-formatted-text')` | Medium — LWC tag names are stable |
| `field-label` attribute | `page.locator('[field-label="Industry"]')` | Medium — field labels can change |
| CSS class | `page.locator('.slds-page-header__title')` | Low — SLDS classes change between releases |

> **SLDS release impact:** Salesforce updates SLDS classes with each major release (Spring, Summer, Winter).
> CSS-class-based selectors that work today may break after a platform upgrade. This is the primary reason to
> prefer `getByText()`, `getByRole()`, and Lightning component tags — these are stable across releases.

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

Emit a log entry via KernDX and verify it renders on its record page. Uses `pollUntil` because
`kern.LOG_Builder` publishes via platform event — the record is created asynchronously:

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

---

## Data Management

### Creating Test Data

**Rule: Only use the browser to test the browser.** All test data setup must go through CLI helpers or anonymous
Apex — never through browser form fills. Browser-based data creation is slow, flaky, and couples your data setup
to page layout changes. Reserve browser interaction exclusively for the assertions you're actually testing.

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
4. Use Playwright's locator — it pierces shadow DOM automatically

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

CI environments start fresh every run. There is no cached `.auth/state.json`. Global setup handles authentication
automatically. Key considerations:

- **Auth URL secret:** Generate with `sf org display -o YourOrg --verbose --json` and store the `sfdxAuthUrl`
  field as a GitHub secret
- **Timeout:** CI environments can be slower. Consider increasing `timeout` to `180_000`
- **Headless:** Always `true` in CI (default)
- **Ephemeral orgs:** If your pipeline spins up temporary orgs (scratch orgs, sandboxes), authenticate each one under the canonical alias — `sf org login sfdx-url --alias <ORG_ALIAS> ...` per run, substituting the value of the `ORG_ALIAS` constant from `sf-auth.js:5`. The helper is alias-bound, not URL-bound; every test run targets whichever org is currently registered under that alias. Forking the helper to read an env-var is the alternative if your release-management tool cannot rename aliases.

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

- Use CLI helpers (`createRecord`, `soqlQuery`) for data setup — avoid filling forms through the browser
- Use SOQL for data assertions — faster and more reliable than reading field values from the DOM
- Clean up test data in `test.afterAll` — prevent data accumulation across runs
- Use `test.describe.serial` — Salesforce tests must run in order within a describe block
- Use page objects for pages you test frequently — centralizes locator maintenance
- Wait for Lightning-specific indicators — nav bar, record page, list view, spinner gone
- Use `getByText()` and `getByRole()` — more resilient than CSS selectors
- Run tests against sandboxes or scratch orgs — never production
- Capture traces on failure — `trace: 'retain-on-failure'` for debugging

**Don't:**

- Don't use `page.waitForTimeout()` as the primary wait strategy — use helper functions
- Don't use parallel workers with a shared session — CSRF token conflicts cause flakiness
- Don't retry flaky tests — fix the root cause in wait logic
- Don't hardcode record IDs — create records in setup, reference by variable
- Don't rely on CSS class names — SLDS classes change between Salesforce releases
- Don't test Salesforce platform behavior — focus on your custom features

**Scaling beyond serial execution:** A typical serial suite hits a ceiling around 100+ tests (~30 minute feedback
loop at ~20 seconds per test). The bottleneck is the shared `sid` session cookie — parallel workers reusing it
generate conflicting CSRF/Aura tokens. To scale, authenticate multiple unique Salesforce users and assign each
to a separate Playwright worker with its own `storageState` file. Each worker gets an independent session cookie,
eliminating cross-worker token conflicts. This requires provisioning dedicated test users with appropriate profiles
and permission sets.

---

## Anti-Patterns

| Anti-Pattern | Problem | Better Approach |
|-------------|---------|----------------|
| **Flaky selectors** — `div:nth-child(3) > span` | Breaks when layout changes | Use `getByText()`, component tags, or `field-label` attributes |
| **Missing auth checks** — navigating without `ensureAuthenticated()` | Random failures when session expires | Use navigation helpers that call `ensureAuthenticated()` automatically |
| **Empty list view assertions** — asserting immediately after navigation | List data loads asynchronously | Use `waitForListView()` then assert on rows |
| **Deployment propagation** — testing immediately after metadata deploy | Metadata may not be active yet | Add a short wait or verify via SOQL after deployment |
| **Testing platform internals** — verifying Salesforce standard behavior | Wastes time, breaks on platform updates | Focus on your custom trigger actions, LWC, and API integrations |
| **Browser-based data creation** — filling forms for test setup | Slow, flaky, depends on page layout | Use `createRecord()` or `executeAnonymousApex()` via CLI |
| **Shared state between tests** — relying on data from previous test | One failure cascades to all subsequent tests | Each test creates its own data, cleans up in `afterAll` |

---

## Troubleshooting

| Symptom | Likely Cause | Solution |
|---------|-------------|----------|
| `Could not extract frontdoor URL` | CLI not authenticated | Run `sf org display -o YourOrgAlias` and re-authenticate if needed |
| `Error: Timeout 30000ms exceeded` on nav bar | Lightning not fully loaded | Increase timeout in `waitForLightningReady`, check network |
| `Error: strict mode violation` | Multiple elements match locator | Add `.first()` or use `.filter({hasText: ...})` to narrow |
| `Error: locator.click: Target closed` | Page navigated during action | Ensure page is fully loaded before interacting |
| `ECONNREFUSED` | Chromium not installed | Run `npx playwright install chromium` |
| Tests pass locally, fail in CI | Different timing, missing deps | Add `--with-deps` to Chromium install, increase timeouts |
| SOQL returns empty array | Missing namespace prefix | Use `kern__ObjectName__c` and `kern__FieldName__c` |
| `JSON.parse` error on CLI output | ANSI color codes in output | Helpers strip ANSI automatically — use `soqlQuery()` not raw `execSync` |
| Record page shows "Loading..." | Record not yet committed | Use `await waitForRecordPage(page)` after navigation (Best Practices bans bare `waitForTimeout`) |
| Toast assertion fails | Toast already dismissed | Use `waitForToastMessage()` which waits for toast to appear |
| Session expired mid-test | Long-running test suite | Call `reauthenticate(page)` in `test.beforeEach` |
| `ERR_NAME_NOT_RESOLVED` | Instance URL changed (scratch org) | Delete `.auth/state.json` and re-run |
| Screenshots show login page | Session state not loaded | Verify `storageState` path in config matches global setup output |

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [Fast Start - E2E Testing](Fast%20Start%20-%20E2E%20Testing.md) | Quick setup guide — get 3 tests passing in 25 minutes |
| [Fast Start - Trigger Actions](Fast%20Start%20-%20Trigger%20Actions.md) | Build trigger actions to test E2E |
| [Fast Start - Logging](Fast%20Start%20-%20Logging.md) | Application logging to verify in Kern app |
| [LWC - Guide](LWC%20-%20Guide.md) | Build LWC components to test E2E |
| [Playwright Documentation](https://playwright.dev) | Official Playwright reference |
| [Playwright Locators](https://playwright.dev/docs/locators) | Locator strategies and best practices |
| [Playwright Trace Viewer](https://playwright.dev/docs/trace-viewer) | Visual debugging tool |
