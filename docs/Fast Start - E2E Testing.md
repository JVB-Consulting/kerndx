---
navOrder: 92
---

# Fast Start - E2E Testing

**Framework:** KernDX | **Total time:** ~20 minutes

**What this is:** A short, hands-on way to prove your code actually works in your own Salesforce org, end to end: you write an Apex class, deploy it, run its tests, and watch them pass. **Why it matters:** It closes the gap between "the code compiles" and "the code does the right thing in the live org," which is where most release surprises come from. **Who should follow it:** developers verifying their work, and tech leads setting up a repeatable test cycle. **When to use it:** any time you want a fast, trustworthy check before shipping. Browser-level testing with Playwright is an optional add-on at the end.

> **Namespaces in code samples:** `kern.` on a class and `kern__` on an object, field, or metadata type mark the managed package's namespace.
> On the managed package, framework references need those prefixes even where a sample omits them; repackaged under your own namespace, replace `kern`/`kern__`
> with your prefix; on an unmanaged deploy, drop them. See [How to read the code samples](Installation.md#how-to-read-the-code-samples).

**What you'll build:** A subscriber Apex service, its `_TEST` class with 100% coverage, and a working
deployment and test run against your scratch org. The Tier 3 section shows how Playwright slots in on top.

**Success looks like:** `Outcome Passed, Tests Ran 3, Pass Rate 100%` from the Apex test runner and,
optionally, a green Playwright run against the same org.

## Before you start

Open your terminal in your project's top folder, the one that holds `sfdx-project.json`; on Windows that terminal is
Command Prompt. Run the four-line check on [Set Up Your Computer](Set%20Up%20Your%20Computer.md#check-you-are-ready)
once: it proves your terminal, the CLI, your login and the KernDX package, and answers what goes wrong. Done that
today? Carry on. Work in a sandbox or a scratch org, never production. Every command below writes `YourOrgAlias`
where your org's alias goes: the name you gave it when you logged in.

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [Before you start](#before-you-start)
2. [How It Works](#how-it-works)
3. [Tier 1: See It Work (~5 minutes)](#tier-1-see-it-work-5-minutes)
4. [Tier 2: Build Your Own (~10 minutes)](#tier-2-build-your-own-10-minutes)
    - [Step 1: Create the Service Class](#step-1-create-the-service-class)
    - [Step 2: Create the Test Class](#step-2-create-the-test-class)
5. [Tier 3: Playwright Browser Tests (~5 minutes)](#tier-3-playwright-browser-tests-5-minutes)
    - [Clean up](#clean-up)
6. [Common Issues](#common-issues)
    - [Tier 1: the demo classes](#tier-1-the-demo-classes)
    - [Step 1: Create the Service Class](#step-1-create-the-service-class-1)
    - [Step 2: Create the Test Class](#step-2-create-the-test-class-1)
    - [Tier 3: the browser tests](#tier-3-the-browser-tests)
    - [Clean up](#clean-up-1)
7. [What You Now Know](#what-you-now-know)
8. [Next Steps](#next-steps)

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
Playwright sits on top of that, and you'll set it up in Tier 3. If your change is pure business logic with
no screen of its own, the Apex layer alone is usually enough; add Playwright when a user-facing page is what
you need to protect. The full reference, with every helper
script, is the runbook at [`release-testing/RUNBOOK.md`](https://github.com/JVB-Consulting/kerndx/blob/main/release-testing/RUNBOOK.md).

---

## Tier 1: See It Work (~5 minutes)

The fastest way to see the whole cycle work is to deploy a ready-made demo class and run its tests. The
framework ships a paired demo (the class plus its test class) so you don't have to write anything yet. The
demo's four files are in the framework's `release-testing/subscriber/classes` folder.

These commands run from your copy of the framework's repository (the public repository you cloned), whose top folder
holds `release-testing/subscriber/classes` and the `test:e2e` script; that folder is "your project's top folder" in
this guide.

**1. In the terminal**, from your project's top folder, copy them into your source folder, with the commands for your
computer.

**Windows (Command Prompt)**

```bat
copy release-testing\subscriber\classes\FastStart_E2E_DEMO.cls force-app\main\default\classes\
copy release-testing\subscriber\classes\FastStart_E2E_DEMO.cls-meta.xml force-app\main\default\classes\
copy release-testing\subscriber\classes\FastStart_E2E_DEMO_TEST.cls force-app\main\default\classes\
copy release-testing\subscriber\classes\FastStart_E2E_DEMO_TEST.cls-meta.xml force-app\main\default\classes\
```

**macOS or Linux**

```bash
cp release-testing/subscriber/classes/FastStart_E2E_DEMO.cls force-app/main/default/classes/
cp release-testing/subscriber/classes/FastStart_E2E_DEMO.cls-meta.xml force-app/main/default/classes/
cp release-testing/subscriber/classes/FastStart_E2E_DEMO_TEST.cls force-app/main/default/classes/
cp release-testing/subscriber/classes/FastStart_E2E_DEMO_TEST.cls-meta.xml force-app/main/default/classes/
```

You should see the four files in `force-app/main/default/classes`. Command Prompt confirms each copy; on macOS or
Linux, `cp` prints nothing when it works.

**2. In the terminal**, send both classes to your org:

```shell
sf project deploy start -o YourOrgAlias -m "ApexClass:FastStart_E2E_DEMO" -m "ApexClass:FastStart_E2E_DEMO_TEST"
```

You should see `Status: Succeeded`, with `FastStart_E2E_DEMO` and `FastStart_E2E_DEMO_TEST` listed as created.

**3. In the terminal**, run the tests:

```shell
sf apex run test -o YourOrgAlias -t FastStart_E2E_DEMO_TEST --code-coverage --synchronous --result-format human
```

You should see the three tests passing: each shows `Pass`, and the summary lines read:

```text
Outcome              Passed
Tests Ran            3
Pass Rate            100%
```

> **Org-wide coverage won't be 100%, and that's expected.** The org-wide figure that
> `--result-format human` reports covers every Apex class in your org, not only this one, so it will not
> match the demo class's own 100% (on an unmanaged deploy of KernDX it includes the framework's classes
> too). Ignore that number here. What matters is the `Passed` outcome and 100% coverage on `FastStart_E2E_DEMO`
> itself.

If you see `Pass Rate 100%`, you've just proven the full subscriber test cycle works, from source to a
green run, without writing a line of code.

Something went wrong? See [Common Issues](#tier-1-the-demo-classes).

---

## Tier 2: Build Your Own (~10 minutes)

Now do it yourself, so the cycle sticks. You'll build a small class called `ProcessingService` (a simple
string-transformation class), write its tests, deploy it, and watch them pass. The goal is to walk the full
path from source to a green run with your own code.

### Step 1: Create the Service Class

You create an empty class with one command, paste the code into it, then send it to your org.

**1. In the terminal**, from your project's top folder, create the empty class:

```shell
sf apex generate class --name ProcessingService --output-dir force-app/main/default/classes
```

You should see two files created in `force-app/main/default/classes`: `ProcessingService.cls` and its companion of
the same name ending in `.cls-meta.xml`.

The second file tells Salesforce which API version the class uses. You do not need to edit it, but a deploy fails without it.

**2. In your editor**, open this file, delete what is there, paste the code below in, and save:

```text
force-app/main/default/classes/ProcessingService.cls
```

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

**3. In the terminal**, send the class to your org:

```shell
sf project deploy start -o YourOrgAlias -m "ApexClass:ProcessingService"
```

You should see `Status: Succeeded`, with `ProcessingService` listed as created.

Something went wrong? See [Common Issues, Step 1](#step-1-create-the-service-class-1).

### Step 2: Create the Test Class

The test class checks the three cases: ordinary input, blank input, and input that is too long. You create the empty
class with one command, paste the code into it, send it to your org, then run it.

**1. In the terminal**, from your project's top folder, create the empty test class:

```shell
sf apex generate class --name ProcessingService_TEST --output-dir force-app/main/default/classes
```

You should see two files created in `force-app/main/default/classes`: `ProcessingService_TEST.cls` and its companion
of the same name ending in `.cls-meta.xml`.

**2. In your editor**, open this file, delete what is there, paste the code below in, and save:

```text
force-app/main/default/classes/ProcessingService_TEST.cls
```

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
@IsTest(isParallel=true)
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

**3. In the terminal**, send the test class to your org:

```shell
sf project deploy start -o YourOrgAlias -m "ApexClass:ProcessingService_TEST"
```

You should see `Status: Succeeded`, with `ProcessingService_TEST` listed as created.

**4. In the terminal**, run the test:

```shell
sf apex run test -o YourOrgAlias -t ProcessingService_TEST --code-coverage --synchronous --result-format human
```

You should see 3 tests passing and 100% coverage on `ProcessingService`: all three tests show `Pass`, the summary line
`Outcome` reads `Passed`, and the coverage table shows `ProcessingService` at `100%`.

Something went wrong? See [Common Issues, Step 2](#step-2-create-the-test-class-1).

---

## Tier 3: Playwright Browser Tests (~5 minutes)

Apex tests prove your logic is right, but they don't prove the screen renders. Playwright fills that gap:
it drives a real browser to confirm the user-facing experience actually works. Once your Apex tests are
green, it logs into Lightning, navigates to a record, and checks that the UI looks the way it should.

> **Full setup and all helper scripts live in** [`release-testing/RUNBOOK.md`](https://github.com/JVB-Consulting/kerndx/blob/main/release-testing/RUNBOOK.md)
> (Phase 3). The infrastructure under `release-testing/e2e/` is ready to use: helpers for auth, navigation,
> CLI commands, wait strategies, and Lightning selectors are pre-written and documented there.

To run the existing browser-test suite against your org, you need just four commands. The browser tests need Node.js
22 or later; the Apex tiers above do not. Like Tier 1, these commands run from your copy of the framework's repository
(the public repository you cloned): its top folder holds `release-testing/subscriber/classes` and the `test:e2e`
script.

**1. In the terminal**, install the suite's dependencies:

```shell
npm ci
```

You should see a line that starts `added` and counts the packages npm installed.

**2. In the terminal**, install the browser the suite drives:

```shell
npx playwright install chromium
```

You should see Playwright download Chromium and finish without an error. It is a large download, so it takes a
while the first time.

**3. In the terminal**, tell the suite which org to use, with the command for your computer.

**Windows (Command Prompt)**

```bat
set SF_SUBSCRIBER_ORG_ALIAS=YourOrgAlias
```

**macOS or Linux**

```bash
export SF_SUBSCRIBER_ORG_ALIAS=YourOrgAlias
```

You should see nothing printed. The setting lasts until you close that terminal, so run the next command in the same
one.

The suite reads the target org alias from the `SF_SUBSCRIBER_ORG_ALIAS` environment variable. Set it to
point the suite at your org. The helpers pass that variable to `sf` as the org alias directly, so this is the one
place the alias ever needs to change.

**4. In the terminal**, run the suite:

```shell
npm run test:e2e
```

You should see Playwright log in to your org once, then run each spec file and report how many tests passed.

**What runs:** 12 spec files. They cover app navigation, record pages, log entry verification,
API call visibility, LWC component rendering, scheduled jobs, streaming, async chains, chain monitor,
the masking advisor, the job runner, the Log Console, and the consoles at volume.

**To write your own spec**, follow this pattern.

**In your editor**, add a file under `release-testing/e2e/specs/`:

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

**Why `test.describe.serial`?** Specs that touch the same org records have to run one at a time. Two files
that both create and tidy up the same scheduled-job rows will otherwise race each other, and one spec's
cleanup deletes the record the other is still waiting for. Marking those groups serial keeps them in single
file.

Specs that share no state are not held back like that: the suite runs them side by side on two workers. Every
spec reuses one `sid` session cookie saved by global setup (a one-time login step), so you log in once however
the work is spread.

> **CI/CD:** Store `SFDX_AUTH_URL` as a repository secret, authenticate the CLI to your subscriber org
> with the configured subscriber alias before invoking `npm run test:e2e`, and install Chromium with
> `--with-deps` on Linux runners. Full GitHub Actions example in the runbook.

Something went wrong? See [Common Issues](#tier-3-the-browser-tests).

### Clean up

If you deployed the classes only to try the cycle, run these two commands when you have finished the guide. Each
deletes a test class before the class it tests, because the org will not delete a class that another class still
uses. The browser-test specs create their own records and tidy them up themselves.

**1. In the terminal**, delete the Tier 1 demo classes:

```shell
sf project delete source -o YourOrgAlias -m "ApexClass:FastStart_E2E_DEMO_TEST" -m "ApexClass:FastStart_E2E_DEMO" --no-prompt
```

You should see `Status: Succeeded`, then a `Deleted Source` table listing the two demo classes.

**2. In the terminal**, delete the Tier 2 classes:

```shell
sf project delete source -o YourOrgAlias -m "ApexClass:ProcessingService_TEST" -m "ApexClass:ProcessingService" --no-prompt
```

You should see `Status: Succeeded`, then a `Deleted Source` table listing `ProcessingService` and
`ProcessingService_TEST`.

The commands delete the files from your project too.

Something went wrong? See [Common Issues](#clean-up-1).

---

## Common Issues

Trouble with your computer rather than this guide (`sf` is not recognised, scripts are disabled, you are not logged
in, the wrong folder)? Those are answered once, in
[Set Up Your Computer](Set%20Up%20Your%20Computer.md#if-something-went-wrong).

### Tier 1: the demo classes

#### `Invalid api version:68.0`

The deploy lists the two demo classes' `.cls-meta.xml` files with this problem. The demo files name a newer API version
than your org runs, as the number in the message shows. In each of the two copied `.cls-meta.xml` files, change the
number between `<apiVersion>` and `</apiVersion>` to a version your org accepts, such as your project's
`sourceApiVersion` (in `sfdx-project.json`) when it is lower, save, and send both classes again.

#### `This class name's value is invalid: FastStart_E2E_DEMO_TEST`

The test run cannot find the test class in your org, because the deploy before it failed. Fix the deploy (see the
entry above), then run the tests again.

### Step 1: Create the Service Class

#### The deploy says there is nothing to deploy

The command ran inside another project's folder, so the CLI looked for the class there and found nothing. Open the
terminal in your own project's top folder, the one that holds `sfdx-project.json`, and run the command again.

### Step 2: Create the Test Class

#### The test run cannot find `ProcessingService_TEST`

The test class is not in your org yet. Send it with the deploy command in Step 2, then run the test again.

### Tier 3: the browser tests

#### The suite cannot open your org

The CLI is not logged in to the org, or `SF_SUBSCRIBER_ORG_ALIAS` names the wrong alias. Check your login with the
check on [Set Up Your Computer](Set%20Up%20Your%20Computer.md#check-you-are-ready), then set the variable again with
the alias that check used.

#### Playwright times out waiting for the navigation bar

Lightning did not finish loading in time. Once your org's Lightning pages open normally in a browser, run the suite
again: its one-time login step signs in afresh on every run.

#### The run fails before a browser opens

Chromium is not installed. Run the browser install command in Tier 3 again.

### Clean up

#### The delete fails

The class you are deleting is used by another class in your org. Delete the test class first, as each clean-up
command does, and delete any class of your own that calls `ProcessingService` before deleting it.

Still stuck? [Tell us](https://github.com/JVB-Consulting/kerndx/issues/new?template=bug_report.md&title=%5Bdocs%5D%20E2E%20Testing) which step and what you saw.

## What You Now Know

| Concept                                   | What It Does                                                                     |
|-------------------------------------------|----------------------------------------------------------------------------------|
| **Subscriber `_TEST` class**              | Deploys alongside production code; proves coverage before release                |
| **`--code-coverage --synchronous`**       | Forces coverage report inline in the same CLI run                                |
| **`release-testing/subscriber/classes/`** | Pre-built demo classes you copy, deploy, and run                                 |
| **Playwright global setup**               | Authenticates once via frontdoor URL, reuses session across all specs            |
| **Serial execution**                      | Specs that share org state run one at a time; independent specs run side by side |

---

## Next Steps

- [Full E2E runbook (all phases, all helpers)](https://github.com/JVB-Consulting/kerndx/blob/main/release-testing/RUNBOOK.md)
- [Trigger actions to test end-to-end](Fast%20Start%20-%20Trigger%20Actions.md)
- [Logging to verify in Kern app](Fast%20Start%20-%20Logging.md)
- [Outbound API calls with test isolation](Fast%20Start%20-%20Outbound%20APIs.md)
