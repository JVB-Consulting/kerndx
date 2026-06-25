---
navOrder: 92
---

# Fast Start - E2E Testing

**Framework:** KernDX | **Total time:** ~20 minutes

**What this is:** A short, hands-on way to prove your code actually works in your own Salesforce org, end to end: you write an Apex class, deploy it, run its tests, and watch them pass. **Why it matters:** It closes the gap between "the code compiles" and "the code does the right thing in the live org," which is where most release surprises come from. **Who should follow it:** developers verifying their work, and tech leads setting up a repeatable test cycle. **When to reach for it:** any time you want a fast, trustworthy check before shipping. Browser-level testing with Playwright is an optional add-on at the end.

**Before you start:**

- [ ] KernDX package installed in your org
- [ ] Org configured post-install: verify with the **Kern** app's Health Check (see [Installation guide](Installation.md#post-install-configuration))
- [ ] CLI authenticated (`sf org display -o YourOrgAlias` to verify)
- [ ] Node.js 22+ installed (`node --version`), required for the Playwright tier only

> **Subscriber orgs:** Use `kern.ClassName` when extending framework classes (e.g., `kern.TRG_Base`,
> `kern.SEL_Base`). Your own classes don't need a namespace prefix: the framework's Type Resolver (how the
> framework finds the Apex classes in your namespace, by you telling it where to look) handles resolution
> automatically.

**What you'll build:** A subscriber Apex service, its `_TEST` class with 100% coverage, and a working
deployment and test run against your scratch org. The Tier 3 section shows how Playwright slots in on top.

**Success looks like:** `Outcome Passed, Tests Ran 3, Pass Rate 100%` from the Apex test runner and,
optionally, a green Playwright run against the same org.

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [How It Works](#how-it-works)
2. [Tier 1: See It Work (~5 minutes)](#tier-1-see-it-work-5-minutes)
3. [Tier 2: Build Your Own (~10 minutes)](#tier-2-build-your-own-10-minutes)
    - [Step 1: Create the Service Class](#step-1-create-the-service-class)
    - [Step 2: Create the Test Class](#step-2-create-the-test-class)
    - [Step 3: Deploy and Run](#step-3-deploy-and-run)
4. [Tier 3: Playwright Browser Tests (~5 minutes)](#tier-3-playwright-browser-tests-5-minutes)
5. [Common Issues](#common-issues)
6. [What You Now Know](#what-you-now-know)
7. [Next Steps](#next-steps)

</details>

---

## How It Works

There are two things worth testing, and they answer different questions. One asks "does my business logic
work?" The other asks "does the screen the user sees work?" KernDX covers both, in two layers:

| Layer                        | What It Tests                               | Tool                  |
|------------------------------|---------------------------------------------|-----------------------|
| **Apex subscriber tests**    | Business logic deployed to a subscriber org | `sf apex run test`    |
| **Playwright browser tests** | Lightning UI rendered in a real browser     | `npx playwright test` |

This Fast Start focuses on the Apex layer first, because that is where most teams start: write a class,
deploy it, and prove it works with a `_TEST` class (a companion test class). Browser testing with
Playwright sits on top of that, and you'll set it up in Tier 3. The full reference, with every helper
script, is the runbook at [`release-testing/RUNBOOK.md`](https://github.com/JVB-Consulting/kerndx/blob/main/release-testing/RUNBOOK.md).

---

## Tier 1: See It Work (~5 minutes)

The fastest way to see the whole cycle work is to deploy a ready-made demo class and run its tests. The
framework ships a paired demo (the class plus its test class) so you don't have to write anything yet. From
your project root, copy them into your source folder:

```bash
cp release-testing/subscriber/classes/FastStart_E2E_DEMO.cls \
   force-app/main/default/classes/FastStart_E2E_DEMO.cls
cp release-testing/subscriber/classes/FastStart_E2E_DEMO.cls-meta.xml \
   force-app/main/default/classes/FastStart_E2E_DEMO.cls-meta.xml
cp release-testing/subscriber/classes/FastStart_E2E_DEMO_TEST.cls \
   force-app/main/default/classes/FastStart_E2E_DEMO_TEST.cls
cp release-testing/subscriber/classes/FastStart_E2E_DEMO_TEST.cls-meta.xml \
   force-app/main/default/classes/FastStart_E2E_DEMO_TEST.cls-meta.xml
```

Deploy both classes:

```bash
sf project deploy start -o YourOrgAlias \
  -m "ApexClass:FastStart_E2E_DEMO" \
  -m "ApexClass:FastStart_E2E_DEMO_TEST"
```

Run the tests:

```bash
sf apex run test -o YourOrgAlias \
  -t FastStart_E2E_DEMO_TEST \
  --code-coverage --synchronous --result-format human
```

**Expected output:**

```text
Test Summary
────────────────────────────────────────────────────────────────
Outcome              Passed
Tests Ran            3
Pass Rate            100%
```

> **Org-wide coverage won't be 100%, and that's expected.** With KernDX installed, the org-wide coverage
> number is dominated by the framework's own classes, so `--result-format human` reports a lower figure.
> Ignore that number here. What matters is the `Passed` outcome and 100% coverage on `FastStart_E2E_DEMO`
> itself.

If you see `Pass Rate 100%`, you've just proven the full subscriber test cycle works, from source to a
green run, without writing a line of code.

---

## Tier 2: Build Your Own (~10 minutes)

Now do it yourself, so the cycle sticks. You'll build a small class called `ProcessingService` (a simple
string-transformation class), write its tests, deploy it, and watch them pass. The goal is to walk the full
path from source to a green run with your own code.

### Step 1: Create the Service Class

Create `force-app/main/default/classes/ProcessingService.cls`:

```apex
/**
 * @description Processes raw string input from subscriber workflows.
 *
 * @see ProcessingService_TEST
 *
 * @author your.name@company.com
 *
 * @group Subscriber Services
 *
 * @date May 2026
 */
public with sharing class ProcessingService
{
	/** @description Error message when input exceeds the allowed length. */
	@TestVisible
	private static final String ERROR_TOO_LONG = 'Input must not exceed 255 characters';

	/** @description Maximum allowed input length. */
	private static final Integer MAX_LENGTH = 255;

	/**
	 * @description Normalises the input: trims whitespace, uppercases, and applies a prefix.
	 * Returns an empty string when the input is blank.
	 *
	 * @param input The raw string to normalise.
	 *
	 * @return The normalised result, or an empty string when input is blank.
	 *
	 * @throws IllegalArgumentException when input exceeds 255 characters.
	 */
	public String normalise(String input)
	{
		if(String.isBlank(input))
		{
			return '';
		}

		if(input.trim().length() > MAX_LENGTH)
		{
			throw new IllegalArgumentException(ERROR_TOO_LONG);
		}

		return 'NORM: ' + input.trim().toUpperCase();
	}
}
```

Create `force-app/main/default/classes/ProcessingService.cls-meta.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<ApexClass xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>67.0</apiVersion>
    <status>Active</status>
</ApexClass>
```

### Step 2: Create the Test Class

Create `force-app/main/default/classes/ProcessingService_TEST.cls`:

```apex
/**
 * @description Unit tests for ProcessingService at 100% coverage.
 *
 * @see ProcessingService
 *
 * @author your.name@company.com
 *
 * @group Subscriber Services
 *
 * @date May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(IsParallel=true)
private class ProcessingService_TEST
{
	/** @description Standard input for happy-path tests. */
	private static final String INPUT_STANDARD = 'hello world';

	/** @description Expected output for the standard input. */
	private static final String EXPECTED_STANDARD = 'NORM: HELLO WORLD';

	/**
	 * @description Verifies that a non-blank input is trimmed, uppercased, and prefixed.
	 */
	@IsTest
	private static void shouldNormaliseStandardInput()
	{
		String result = new ProcessingService().normalise(INPUT_STANDARD);

		Assert.areEqual(EXPECTED_STANDARD, result, 'Standard input should produce prefixed uppercase output');
	}

	/**
	 * @description Verifies that blank input returns an empty string without throwing.
	 */
	@IsTest
	private static void shouldReturnEmptyForBlankInput()
	{
		ProcessingService service = new ProcessingService();

		Assert.areEqual('', service.normalise(null), 'Null input should return empty string');
		Assert.areEqual('', service.normalise(''), 'Empty input should return empty string');
		Assert.areEqual('', service.normalise('   '), 'Whitespace-only should return empty string');
	}

	/**
	 * @description Verifies that an input exceeding 255 characters throws IllegalArgumentException.
	 */
	@IsTest
	private static void shouldThrowWhenInputTooLong()
	{
		String oversizedInput = 'A'.repeat(256);

		try
		{
			new ProcessingService().normalise(oversizedInput);
			Assert.fail('Should throw IllegalArgumentException');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect exception type');
			Assert.areEqual(ProcessingService.ERROR_TOO_LONG, error.getMessage(), 'Incorrect error message');
		}
	}
}
```

Create `force-app/main/default/classes/ProcessingService_TEST.cls-meta.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<ApexClass xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>67.0</apiVersion>
    <status>Active</status>
</ApexClass>
```

### Step 3: Deploy and Run

```bash
sf project deploy start -o YourOrgAlias \
  -m "ApexClass:ProcessingService" \
  -m "ApexClass:ProcessingService_TEST"

sf apex run test -o YourOrgAlias \
  -t ProcessingService_TEST \
  --code-coverage --synchronous --result-format human
```

**Expected:** 3 tests passing, 100% coverage on `ProcessingService`.

---

## Tier 3: Playwright Browser Tests (~5 minutes)

Apex tests prove your logic is right, but they don't prove the screen renders. Playwright fills that gap:
it drives a real browser to confirm the user-facing experience actually works. Once your Apex tests are
green, it logs into Lightning, navigates to a record, and checks that the UI looks the way it should.

> **Full setup and all helper scripts live in** [`release-testing/RUNBOOK.md`](https://github.com/JVB-Consulting/kerndx/blob/main/release-testing/RUNBOOK.md)
> (Phase 3). The infrastructure under `release-testing/e2e/` is ready to use: helpers for auth, navigation,
> CLI commands, wait strategies, and Lightning selectors are pre-written and documented there.

To run the existing browser-test suite against your org, you need just four commands:

```bash
npm ci
npx playwright install chromium
export SF_SUBSCRIBER_ORG_ALIAS=<your-org-alias>
npm run test:e2e
```

The suite reads the target org alias from the `SF_SUBSCRIBER_ORG_ALIAS` environment variable. Export it to
point the suite at your org. The helpers call `sf -o $SF_SUBSCRIBER_ORG_ALIAS` directly, so this is the one
place the alias ever needs to change.

**What runs:** 9 spec files. They cover app navigation, record pages, log entry verification,
API call visibility, LWC component rendering, async chains, chain monitor, and the masking advisor.

**To write your own spec**, add a file under `release-testing/e2e/specs/` following this pattern:

```javascript
const {test, expect} = require('@playwright/test');
const {getInstanceUrl} = require('../helpers/sf-auth');

test.describe.serial('My Feature', () =>
{
	test('should render record page', async ({page}) =>
	{
		const instanceUrl = getInstanceUrl();
		await page.goto(`${instanceUrl}/lightning/page/home`, {waitUntil: 'domcontentloaded'});
		await expect(page.locator('one-app-nav-bar')).toBeVisible({timeout: 30_000});
	});
});
```

**Why `test.describe.serial` and one worker?** All tests share a single `sid` session cookie saved by global
setup (a one-time login step). If tests ran in parallel, they would reuse that same cookie and generate
conflicting CSRF tokens (the anti-forgery tokens Salesforce checks on each request). Running the tests one
at a time avoids that conflict entirely.

> **CI/CD:** Store `SFDX_AUTH_URL` as a repository secret, authenticate the CLI to your subscriber org
> with the configured subscriber alias before invoking `npm run test:e2e`, and install Chromium with
> `--with-deps` on Linux runners. Full GitHub Actions example in the runbook.

---

## Common Issues

| Problem                               | Cause                                | Fix                                                                                                                                          |
|---------------------------------------|--------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------|
| `Type not visible` in subscriber test | Class is `public` in managed package | No change needed: your own classes are always resolved in your namespace                                                        |
| `No such column 'kern__FieldName__c'` | Missing namespace prefix in SOQL     | Use `kern__FieldName__c` for KernDX custom fields                                                                                            |
| `Could not extract frontdoor URL`     | CLI not authenticated or wrong alias | Run `sf org display -o YourOrgAlias` to verify                                                                                               |
| Playwright timeout on nav bar         | Lightning didn't fully load          | Delete `release-testing/e2e/.auth/state.json` and `release-testing/e2e/.auth/instance.json`, then re-run to refresh the session              |
| `ECONNREFUSED`                        | Chromium not installed               | Run `npx playwright install chromium`                                                                                                        |
| Tests fail after working yesterday    | Frontdoor URL expired                | Delete both `release-testing/e2e/.auth/state.json` and `release-testing/e2e/.auth/instance.json`; global setup regenerates them on next run |

---

## What You Now Know

| Concept                                   | What It Does                                                          |
|-------------------------------------------|-----------------------------------------------------------------------|
| **Subscriber `_TEST` class**              | Deploys alongside production code; proves coverage before release     |
| **`--code-coverage --synchronous`**       | Forces coverage report inline in the same CLI run                     |
| **`release-testing/subscriber/classes/`** | Pre-built demo classes you copy, deploy, and run                      |
| **Playwright global setup**               | Authenticates once via frontdoor URL, reuses session across all specs |
| **Serial execution**                      | One browser, one worker: reliable for Salesforce Lightning            |

---

## Next Steps

- [Full E2E runbook (all phases, all helpers)](https://github.com/JVB-Consulting/kerndx/blob/main/release-testing/RUNBOOK.md)
- [Trigger actions to test end-to-end](Fast%20Start%20-%20Trigger%20Actions.md)
- [Logging to verify in Kern app](Fast%20Start%20-%20Logging.md)
- [Outbound API calls with test isolation](Fast%20Start%20-%20Outbound%20APIs.md)
