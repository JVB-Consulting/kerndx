---
navOrder: 90
---

# Fast Start - Code Scanning

**Framework:** KernDX | **Total time:** ~20 minutes

**What this is:** A set of ready-made code checks that flag risky patterns (inline SOQL, direct DML, leftover `System.debug()`, and others) right in your editor, before the code reaches a teammate's review. **Why it matters:** Catching these the moment you type them is faster and cheaper than catching them in review or production, and it keeps a whole team writing code the same way. **Who should follow this:** developers setting up their IDE, and tech leads or DevOps owners wiring the same checks into the build pipeline. **When to use it:** as soon as you start writing or maintaining code in a KernDX project. The generic PMD and ESLint rules SF Code Analyzer ships are still worth running; these KernDX rules add on top of them, enforcing the framework's own patterns that the generic rules can't know about.

> **Namespaces in code samples:** `kern.` on a class and `kern__` on an object, field, or metadata type mark the managed package's namespace.
> On the managed package, framework references need those prefixes even where a sample omits them; repackaged under your own namespace, replace `kern`/`kern__`
> with your prefix; on an unmanaged deploy, drop them. See [How to read the code samples](Installation.md#how-to-read-the-code-samples).

**What you'll build:** a fully configured scanning setup that catches inline SOQL, direct DML, `System.debug()`, and 24 other framework violations, both inline in your IDE and in CI/CD.

**Success looks like:** You write a class with `System.debug()` and `[SELECT Id FROM Account]`, and your IDE underlines both lines before you even save.

**In one line:** Drop `scanner/kerndx-pmd-ruleset.xml` into your Apex PMD settings and every risky pattern the framework guards against lights up in your editor.

## Before you start

Open your terminal in your project's top folder, the one that holds `sfdx-project.json`; on Windows that terminal is
Command Prompt. Run the four-line check on [Set Up Your Computer](Set%20Up%20Your%20Computer.md#check-you-are-ready)
once: it proves your terminal, the CLI, your login and the KernDX package, and answers what goes wrong. Done that
today? Carry on. Work in a sandbox or a scratch org, never production. Every command below writes `YourOrgAlias`
where your org's alias goes: the name you gave it when you logged in.

Nothing in this guide talks to your org: the scanner and the linter read the files in your project.

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [Before you start](#before-you-start)
2. [Tier 1: See It Work (~2 minutes)](#tier-1-see-it-work-2-minutes)
    - [The sample violation class](#the-sample-violation-class)
    - [Run the scanner](#run-the-scanner)
3. [Tier 2: Set Up Your Project (~15 minutes)](#tier-2-set-up-your-project-15-minutes)
    - [Step 1: IDE Setup (VS Code)](#step-1-ide-setup-vs-code)
    - [Step 2: SF Code Analyzer v5](#step-2-sf-code-analyzer-v5)
    - [Step 3: IntelliJ / Illuminated Cloud](#step-3-intellij--illuminated-cloud)
    - [Step 4: ESLint for LWC](#step-4-eslint-for-lwc)
4. [Tier 3: Production Patterns (~5-10 minutes)](#tier-3-production-patterns-5-10-minutes)
    - [Priority tiers](#priority-tiers)
    - [PMD rule reference](#pmd-rule-reference)
    - [ESLint rule reference](#eslint-rule-reference)
    - [Suppressing rules](#suppressing-rules)
    - [CI/CD integration](#cicd-integration)
    - [GitHub Actions example](#github-actions-example)
    - [Org-specific naming rules](#org-specific-naming-rules)
    - [Clean up](#clean-up)
5. [Common Issues](#common-issues)
    - [Run the scanner](#run-the-scanner-1)
    - [Step 1: IDE Setup (VS Code)](#step-1-ide-setup-vs-code-1)
    - [Step 2: SF Code Analyzer v5](#step-2-sf-code-analyzer-v5-1)
    - [Step 3: IntelliJ / Illuminated Cloud](#step-3-intellij--illuminated-cloud-1)
    - [Step 4: ESLint for LWC](#step-4-eslint-for-lwc-1)
6. [What You Now Know](#what-you-now-know)
7. [Next Steps](#next-steps)

</details>

---

## Tier 1: See It Work (~2 minutes)

### The sample violation class

The quickest way to prove the scanner works is to give it something to catch: a small class that breaks the rules on
purpose. This is a throwaway that never goes to your org: delete it once you've seen the scanner flag it.

**In your editor**, create this file:

```text
force-app/main/default/classes/ScannerDemo.cls
```

```apex
public with sharing class ScannerDemo
{
	public List<Account> getAccounts()
	{
		Account[] accounts = [SELECT Id, Name FROM Account LIMIT 10];
		System.debug(accounts);
		return accounts;
	}
}
```

It has two violations baked in:

| Line                     | Violation        | Rule                |
|--------------------------|------------------|---------------------|
| `[SELECT Id, Name ...]`  | Inline SOQL      | `KernNoInlineSOQL`  |
| `System.debug(accounts)` | `System.debug()` | `KernNoSystemDebug` |

### Run the scanner

The scanner is SF Code Analyzer v5, a plugin for the Salesforce CLI.

**1. In the terminal**, install the plugin once (skip this if you installed it before):

```shell
sf plugins install @salesforce/plugin-code-analyzer
```

You should see a line that starts `@salesforce/cli: Installing plugin code-analyzer` and ends `installed` followed by
the plugin's version.

The scanner needs to know which rules to apply. SF Code Analyzer v5 reads custom rule sets from a config file, which
points at the rule set that shipped in your KernDX pipeline bundle. The bundle unpacks it into the `scanner` folder
inside `.kerndx-pipeline`; copy `kerndx-pmd-ruleset.xml` from there into a new `scanner` folder in your project's top
folder, which is where the file below looks for it. If you ran the bundle's `kerndx init`, it already wrote a
`code-analyzer.yml` that points at the bundle's copy, so keep that file and skip the next part.

**2. In your editor**, create this file in your project's top folder:

```text
code-analyzer.yml
```

```yaml
engines:
  pmd:
    custom_rulesets:
      - scanner/kerndx-pmd-ruleset.xml
```

**3. In the terminal**, run SF Code Analyzer against the demo class using the KernDX ruleset:

```shell
sf code-analyzer run --config-file code-analyzer.yml --rule-selector pmd:KernDXFrameworkCompliance --target force-app/main/default/classes/ScannerDemo.cls --view detail
```

You should see the two violations, each with its rule, severity and message (a `location:` line with the file and
line follows each; it is left out here because its path form differs by computer):

```text
=== 1. KernNoInlineSOQL
    severity: 2 (High)
    engine:   pmd
    message:  Inline SOQL is not allowed. Use a selector (SEL_*) or QRY_Builder.

=== 2. KernNoSystemDebug
    severity: 3 (Moderate)
    engine:   pmd
    message:  System.debug() is not allowed. Use LOG_Builder for structured, async logging.
```

A `=== Summary` section follows, starting `Found 2 violation(s) across 1 file(s):`. If your project has an ESLint
configuration file, the scanner may first print a note that it found the file but did not apply it; this scan checks
Apex only, so you can ignore that note here.

The scanner found both violations and told you what to use instead: the inline `[SELECT ...]` should go through a selector class or [`QRY_Builder`](reference/apex/QRY_Builder.md), and `System.debug()` should go through [`LOG_Builder`](reference/apex/LOG_Builder.md). The severity word next to each violation comes straight from the rule's PMD priority number: Priority 1 shows as High (the number after `severity:` is Code Analyzer's own scale), Priority 3 as Moderate, Priority 5 as Low.

> **When to move to Tier 2:** When you want violations to appear inline in your IDE as you type, without running the CLI manually.

Something went wrong? See [Common Issues](#run-the-scanner-1).

---

## Tier 2: Set Up Your Project (~15 minutes)

Running the scanner by hand proves it works, but you want the checks to be automatic: inline as you type, and again in your build pipeline. This tier wires that up. Set up whichever editor your team uses, then add the same rules to CI/CD.

### Step 1: IDE Setup (VS Code)

This step is for VS Code with the
[Apex PMD extension](https://marketplace.visualstudio.com/items?itemName=chuckjonas.apex-pmd) installed. Both editors
in this tier are optional: on IntelliJ with Illuminated Cloud, skip to Step 3, and Step 2's command-line scan works
without either. Tell VS Code where the rules live by adding the KernDX rule set to your project's VS Code settings.

**In your editor**, create this file (or add the setting to it, if it already exists):

```text
.vscode/settings.json
```

```json
{
   "apexPMD.rulesets": [
      "scanner/kerndx-pmd-ruleset.xml"
   ]
}
```

Save the file. Now open any Apex class that contains `System.debug()` or `[SELECT ...]`, and you'll see yellow or red squiggly underlines on the offending lines. Hover over one to read the rule name and the suggested replacement.

> **Multiple rulesets:** The Apex PMD extension accepts a list, so you can run your org's own naming rules alongside the framework rules:
> ```json
> "apexPMD.rulesets": [
>    "scanner/kerndx-pmd-ruleset.xml",
>    "scanner/subscriber-naming-pmd-ruleset.xml"
> ]
> ```

Something went wrong? See [Common Issues, Step 1](#step-1-ide-setup-vs-code-1).

### Step 2: SF Code Analyzer v5

Inline editor checks catch problems while you write, but you also want a command-line version for your build pipeline, pre-commit hooks, or a one-off scan of the whole project.

**1. In your editor**, create this file in your project's top folder, if you did not already make it in Tier 1:

```text
code-analyzer.yml
```

```yaml
engines:
  pmd:
    custom_rulesets:
      - scanner/kerndx-pmd-ruleset.xml
```

**2. In the terminal**, run the scanner:

```shell
sf code-analyzer run --config-file code-analyzer.yml --target force-app/ --view detail
```

This scans every Apex class and trigger in `force-app/` and lists the violations grouped by file. For a more compact view, add `--view table`. To capture the results for a CI report, add `--output-file results.csv`.

You should see one `===` entry for each violation, then a `=== Summary` section that starts `Found` and counts the
violations and files. With no `--rule-selector`, the scan runs Code Analyzer's recommended rules as well as the KernDX
ones, so on the Tier 1 demo class it finds more than the two violations Tier 1 showed.

Something went wrong? See [Common Issues, Step 2](#step-2-sf-code-analyzer-v5-1).

### Step 3: IntelliJ / Illuminated Cloud

If your team uses IntelliJ with Illuminated Cloud instead of VS Code, the setup is similar with one twist: Illuminated Cloud accepts only a single PMD rule set path, not a list. Point it at the combined rule set, which pulls in all the KernDX rules for you.

**In your editor** (IntelliJ):

1. Open **Settings > Illuminated Cloud > PMD**
2. Set **Custom Ruleset Path** to `scanner/combined-pmd-ruleset.xml`
3. Apply

Violations now appear inline in the IntelliJ editor. The combined file simply references the other rule sets (PMD `<rule ref="..."/>`), so no rule is duplicated.

Something went wrong? See [Common Issues, Step 3](#step-3-intellij--illuminated-cloud-1).

### Step 4: ESLint for LWC

The same idea applies to your Lightning Web Components (LWC), checked by the ESLint plugin `eslint-plugin-kerndx`,
which your KernDX pipeline bundle unpacks into `.kerndx-pipeline/scanner/eslint-plugin-kerndx`.

Four of these rules catch problems in any project, so turn them on first in your project's ESLint configuration file:
`kerndx/no-coverage-exempt-without-reason`, `kerndx/no-hardcoded-user-text` (at the `warn` level, so it flags without
failing the run), `kerndx/no-jest-theatre`, and `kerndx/no-mutating-shared-fixture`. In a clone of the KernDX source
repository they are **active by default**.

Three more rules push you toward the KernDX component model: `kerndx/use-component-builder`, `kerndx/no-console-log`,
and `kerndx/enforce-component-naming`. Turn them on when you're ready for that model, so they don't start flagging
code before you've adopted it. (In a clone of the KernDX source repository they sit in
`force-app/main/default/lwc/eslint.config.mjs` and ship **commented out**; uncomment their block there instead.)

**1. In your editor**, open the ESLint configuration file in your project's top folder (a project made by
`sf project generate` has one), register the plugin from `.kerndx-pipeline/scanner/eslint-plugin-kerndx` as the
ESLint step of the bundle's setup guide shows, and turn on these three rules:

```text
'kerndx/use-component-builder': 'error',
'kerndx/no-console-log': 'error',
'kerndx/enforce-component-naming': 'error'
```

**Verify it works:** with the `use-component-builder` rule enabled (above), create a test component that uses `extends LightningElement` instead of `extends ComponentBuilder(...)`.

**2. In your editor**, create this file:

```text
force-app/main/default/lwc/testViolation/testViolation.js
```

```javascript
import {LightningElement} from 'lwc';

export default class TestViolation extends LightningElement {}
```

**3. In the terminal**, run the linter:

```shell
npm run lint
```

You should see an `error` on line 3 of the test component, naming the rule `kerndx/use-component-builder` and telling
you to extend `ComponentBuilder(...)` instead of `LightningElement`, then the count line
`✖ 1 problem (1 error, 0 warnings)`.

Something went wrong? See [Common Issues, Step 4](#step-4-eslint-for-lwc-1).

---

## Tier 3: Production Patterns (~5-10 minutes)

Turning on every rule at once in an existing codebase floods you with violations, which is discouraging and easy to ignore. This tier shows you how to adopt the rules in stages, what each one checks, how to silence a genuine exception, and how to run the whole thing in CI/CD.

### Priority tiers

The rules are not all equally urgent, so the 27 KernDX-authored PMD rules that fire on your own code are grouped into three priority levels. Fix the most important first and add the rest over time:

| Tier          | Priority | Count | Approach                                                             |
|---------------|----------|-------|----------------------------------------------------------------------|
| Blockers      | 1        | 4     | Fix immediately: these bypass core framework patterns                |
| Should Fix    | 3        | 12    | Fix in the current sprint: leaving them makes code harder to maintain |
| Informational | 5        | 11    | Fix opportunistically: good practice, no immediate action required   |

**Recommended adoption path:** Start with Priority 1 (triggers and SOQL). Once clean, enable Priority 3. Add Priority 5 when the team is comfortable with the framework.

### PMD rule reference

The 27 KernDX-authored PMD rules, every one of which can fire on your own code:

| Rule                               | What It Blocks                                                                         | Use Instead                                                                                     | Priority |
|------------------------------------|----------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------|----------|
| `KernTriggerMustDelegate`          | Logic in trigger body, or no dispatcher call at all                                    | `new TRG_Dispatcher().run()`                                                                    | 1        |
| `KernNoInlineSOQL`                 | `[SELECT ...]`, `Database.query()`                                                     | Selector or [`QRY_Builder`](reference/apex/QRY_Builder.md)                                      | 1        |
| `KernNoCoverageTheatre`            | Test methods with no assertions                                                        | Real `Assert.*` calls that exercise the behaviour                                               | 1        |
| `KernCoverageExemptRequiresReason` | `@CoverageExempt` without a justification comment                                      | Add an inline `// Coverage-exempt because …` explanation                                        | 1        |
| `KernNoDirectDML`                  | `insert`/`update`/`delete`/`upsert`, `Database.*` DML                                  | [`DML_Builder`](reference/apex/DML_Builder.md)                                                  | 3        |
| `KernNoSystemDebug`                | `System.debug()`                                                                       | [`LOG_Builder`](reference/apex/LOG_Builder.md)                                                  | 3        |
| `KernNoRawHttp`                    | `new HttpRequest()`, `new Http()`                                                      | [`UTIL_HttpClient`](reference/apex/UTIL_HttpClient.md)                                          | 3        |
| `KernUseSchedulerBase`             | `implements Schedulable` directly                                                      | `extends SCHED_Base`                                                                            | 3        |
| `KernNoRawSchedule`                | `System.schedule()`                                                                    | `SCHED_Base` + `ScheduledJob__c`                                                                | 3        |
| `KernNoRawEventPublish`            | `EventBus.publish()`                                                                   | [`LOG_Builder`](reference/apex/LOG_Builder.md) / framework events                               | 3        |
| `KernNoRawHttpMock`                | `implements HttpCalloutMock/WebServiceMock`                                            | `API_MockFactory`                                                                               | 3        |
| `KernNoRawRestContext`             | `RestContext.request/response`                                                         | `API_Inbound` framework                                                                         | 3        |
| `KernNoRawEmail`                   | `Messaging.sendEmail()`, `new SingleEmailMessage()`                                    | `UTIL_Email`                                                                                    | 3        |
| `KernRestResourceNaming`           | `@RestResource` on non-`REST_*` class                                                  | `REST_*` + `API_Dispatcher`                                                                     | 3        |
| `KernNoInlineDmlInTests`           | `insert`/`update`/`delete` inside `@IsTest` methods                                    | [`TST_Builder`](reference/apex/TST_Builder.md) / [`DML_Builder`](reference/apex/DML_Builder.md) | 3        |
| `KernInvocableClassNeedsNoArgConstructor` | `@InvocableVariable` classes whose only constructors take arguments (Flow cannot create them at run time) | An explicit public no-arg constructor alongside the others                                      | 3        |
| `KernNoLegacyAssert`               | `System.assert*()`                                                                     | `Assert.*`                                                                                      | 5        |
| `KernUseTestBuilder`               | `new Account(Name = ...)` in tests                                                     | [`TST_Builder`](reference/apex/TST_Builder.md)                                                  | 5        |
| `KernNoRawCache`                   | `Cache.Org.*`, `Cache.Session.*`                                                       | `UTIL_Cache`                                                                                    | 5        |
| `KernNoRawDescribe`                | `Schema.getGlobalDescribe()`                                                           | `UTIL_SObjectDescribe`                                                                          | 5        |
| `KernNoRawTypeForName`             | `Type.forName()`                                                                       | `UTIL_System.getTypeForClassName()`                                                             | 5        |
| `KernNoRawEnqueueJob`              | `System.enqueueJob()`                                                                  | `UTIL_AsynchronousJobLauncher`                                                                  | 5        |
| `KernNoRawCrypto`                  | `Crypto.*`                                                                             | `UTIL_Crypto`                                                                                   | 5        |
| `KernLimitsThroughWrapper`         | `Limits.get*()` outside `UTIL_Limits` and its test class                               | `UTIL_Limits`, for example `UTIL_Limits.soqlQueries().used()`                                   | 5        |
| `KernNoRawFeatureManagement`       | `FeatureManagement.checkPermission()`                                                  | `UTIL_FeatureFlag.isEnabled()`                                                                  | 5        |
| `KernNoBooleanExceptionThrown`     | `Boolean exceptionThrown = false; try { ... } catch (...) { exceptionThrown = true; }` | `Assert.fail(...)` + `Assert.isInstanceOfType(...)`                                             | 5        |
| `KernSecurityBypassCallSite`       | Unacknowledged framework security-bypass call sites                                    | Confirm it's intentional + acknowledge with `@SuppressWarnings('PMD.KernSecurityBypassCallSite')` or `// NOPMD` + reason | 5        |

### ESLint rule reference

| Rule                                       | What It Blocks                                               | Use Instead                                      |
|--------------------------------------------|--------------------------------------------------------------|--------------------------------------------------|
| `kerndx/use-component-builder`             | `extends LightningElement`                                   | `extends ComponentBuilder(...)`                  |
| `kerndx/no-console-log`                    | `console.log()`, `window.console.*`                          | `this.consoleLog()`, `this.consoleError()`       |
| `kerndx/enforce-component-naming`          | LWC folders without domain prefix                            | `domain[Brand]FeatureVariant`                    |
| `kerndx/no-jest-theatre`                   | Assertion-less Jest tests, hollow `createElement` assertions | Real `expect(...)` calls that exercise behaviour |
| `kerndx/no-mutating-shared-fixture`        | Mutation of a `beforeAll(...)` fixture across tests          | Rebuild per-test state in `beforeEach(...)`      |
| `kerndx/no-coverage-exempt-without-reason` | `kern-coverage-exempt` comments without justification        | Add a substantive platform-limitation reason     |
| `kerndx/no-hardcoded-user-text`            | Hardcoded user-facing text in toasts, errors, and template bindings | Import the text from a Custom Label (`@salesforce/label/c.X`) |

### Suppressing rules

When a rule produces a false positive or you have a justified exception, suppress it with an annotation and a comment explaining why.

**Apex (PMD):**

**In your editor**, on the class:

```apex
@SuppressWarnings('PMD.KernNoDirectDML')
public inherited sharing class DML_SharingProxy
{
   // Framework infrastructure — direct DML is intentional here
}
```

**In your editor**, for multiple rules on one class:

```apex
@SuppressWarnings('PMD.KernNoDirectDML, PMD.KernNoRawHttp')
```

**JavaScript (ESLint):**

**In your editor**, on the line above the code the rule would flag:

```javascript
// eslint-disable-next-line kerndx/use-component-builder -- template-only component with no controller interaction
export default class Notice extends LightningElement {}
```

### CI/CD integration

Inline checks help one developer; running the same rules in your pipeline protects the whole team's main branch. Because the PMD rule sets are standard XML files, any tool that supports custom PMD rule sets can use them. Here is where to load the file in the common release tools:

| Tool          | Setup                                                                                     |
|---------------|-------------------------------------------------------------------------------------------|
| **Gearset**   | Static Code Analysis settings > upload `kerndx-pmd-ruleset.xml` as a custom ruleset       |
| **Copado**    | PMD SCA Settings > add as custom PMD ruleset > set enforcement level                      |
| **AutoRABIT** | Static Code Analysis > Apex PMD > upload ruleset > assign to analysis profile             |
| **CodeScan**  | Quality Profile > add as custom ruleset > activate KernDX rules > set severity thresholds |

### GitHub Actions example

**In your editor**, create a workflow file in your repository's GitHub Actions workflows folder, for example:

```text
.github/workflows/code-scan.yml
```

```yaml
name: Code Scan
on: [pull_request]

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 22
      - name: Install SF CLI
        run: npm install -g @salesforce/cli
      - name: Install Code Analyzer
        run: sf plugins install @salesforce/plugin-code-analyzer
      - name: Run KernDX Scanner
        run: sf code-analyzer run --config-file code-analyzer.yml --target force-app/ --view detail
```

This run only reports: the scanner finishes successfully even when it finds violations, so the job passes.
To make violations fail the job, add `--severity-threshold` with a level; violations at or above that level then fail
the run.

### Org-specific naming rules

The framework rules cover KernDX patterns, but most teams also have their own naming standard. The `scanner/subscriber-naming-pmd-ruleset.xml` file is a worked example of that: it enforces the `Domain_[Brand_]Layer_Name[_TEST]` convention for one particular org, and you can use it as a template for your own.

To create your own naming rule set, follow the same pattern:

1. Copy `subscriber-naming-pmd-ruleset.xml` as a starting point
2. Modify the regex in the XPath expression to match your naming convention
3. Update the rule name, message, and description
4. Add the file to your PMD configuration alongside `kerndx-pmd-ruleset.xml`

See the [Code Scanning - Guide](Code%20Scanning%20-%20Guide.md) for detailed instructions on creating custom rules.

### Clean up

When you have finished the guide, delete the two throwaway items in your editor: the Tier 1 `ScannerDemo` class and
the Step 4 `testViolation` folder. Neither went to your org, so there is nothing to delete there. Keep the
configuration files (`code-analyzer.yml`, `.vscode/settings.json` and, if you changed it, the `lint` script in
`package.json`): they are your scanning setup.

---

## Common Issues

Trouble with your computer rather than this guide (`sf` is not recognised, scripts are disabled, you are not logged
in, the wrong folder)? Those are answered once, in
[Set Up Your Computer](Set%20Up%20Your%20Computer.md#if-something-went-wrong).

### Run the scanner

#### The scanner says a rule or a rule class cannot be found

Your scanner's PMD Apex module is older than 7.19.0, or it runs a PMD 6 engine, which uses a different rule class.
Upgrade your scanner so its PMD Apex module is 7.19.0 or newer (for Salesforce Code Analyzer, update the
`code-analyzer` plugin); PMD 6 is not supported.

### Step 1: IDE Setup (VS Code)

#### The Apex PMD extension shows no violations

The rule set path is not set, or the extension is not installed. Check that `.vscode/settings.json` has
`apexPMD.rulesets` pointing to `scanner/kerndx-pmd-ruleset.xml`, and that the Apex PMD extension is installed.

### Step 2: SF Code Analyzer v5

#### Too many violations on the first scan

Your existing code was written before you adopted the framework. Adopt the rules in stages: start with the Priority 1
blockers only, then expand to Priority 3 and Priority 5 over time (see [Priority tiers](#priority-tiers)).

#### A violation in a class that uses the raw API on purpose

The rule correctly flags the pattern, but the class needs it. Suppress it with `@SuppressWarnings('PMD.RuleName')` and
add a comment explaining why (see [Suppressing rules](#suppressing-rules)).

### Step 3: IntelliJ / Illuminated Cloud

#### The combined rule set fails with relative path errors

`combined-pmd-ruleset.xml` refers to the other rule sets by relative path, and the scan ran from a folder that does not
hold them. Make sure the working folder contains the `scanner/` folder, or use absolute paths in the
`<rule ref="..."/>` elements.

### Step 4: ESLint for LWC

#### `No files matching the pattern "**/aura/**/*.js" were found.`

The lint command stops with this message in a project that has no Aura components: the `lint` script in a project
made by `sf project generate` checks both `aura` and `lwc` folders, and ESLint refuses a pattern that matches nothing.
In `package.json`, change the `lint` script to `eslint **/lwc/**/*.js`, then run the Step 4 lint command again.

#### ESLint says it cannot find the `kerndx/*` rules

The plugin is not loaded in your ESLint configuration. Check that your project's ESLint configuration file imports and
registers `eslint-plugin-kerndx` from `.kerndx-pipeline/scanner/eslint-plugin-kerndx`, as the ESLint step of the
bundle's setup guide shows (in a clone of the KernDX source repository, check `eslint.config.mjs` instead).

Still stuck? [Tell us](https://github.com/JVB-Consulting/kerndx/issues/new?template=bug_report.md&title=%5Bdocs%5D%20Code%20Scanning) which step and what you saw.

## What You Now Know

| Concept                    | What It Does                                                                                                                                                                        |
|----------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `kerndx-pmd-ruleset.xml`   | 27 KernDX-authored PMD rules enforcing framework conventions (triggers, queries, DML, logging, HTTP, coverage hygiene, etc.)                                                                 |
| `kerndx-hygiene-ruleset.xml` | Framework-agnostic tier: the six rules that need no KernDX framework (test quality, security-bypass review, Flow-invocable constructors), for repos that do not use the KernDX framework     |
| `eslint-plugin-kerndx`     | 7 ESLint rules enforcing LWC and test conventions: extend the shared component base class, no `console.log`, consistent naming, a reason on every coverage exemption, no assertion-less tests, no mutating a fixture shared across tests, and no hardcoded user-facing text |
| `combined-pmd-ruleset.xml` | Single-file reference for tools that only accept one ruleset (IntelliJ)                                                                                                             |
| Priority tiers (1/3/5)     | A staged adoption order: start with blockers, expand to should-fix, then informational                                                                                              |
| `@SuppressWarnings`        | Per-class or per-method opt-out with justification                                                                                                                                  |
| `code-analyzer.yml`        | SF Code Analyzer v5 configuration for CLI and CI/CD scanning                                                                                                                        |

**Key patterns:**

- Start with Priority 1 rules (inline SOQL and trigger delegation): these are the highest-impact framework violations
- Configure your IDE first so violations appear as you type, before you commit
- Use `@SuppressWarnings` sparingly and always with a justification comment
- Create org-specific naming rulesets following the `subscriber-naming-pmd-ruleset.xml` example
- Integrate into CI/CD to prevent regressions after the initial cleanup

---

## Next Steps

- [Code Scanning Guide (CI/CD recipes, custom rules)](Code%20Scanning%20-%20Guide.md)
- [Fast Start - Selectors](Fast%20Start%20-%20Selectors.md)
- [Fast Start - DML](Fast%20Start%20-%20DML.md)
- [Fast Start - Logging](Fast%20Start%20-%20Logging.md)
- [Fast Start - Trigger Actions](Fast%20Start%20-%20Trigger%20Actions.md)
- [Fast Start - Test Data](Fast%20Start%20-%20Test%20Data.md)
- [Fast Start - Outbound APIs](Fast%20Start%20-%20Outbound%20APIs.md)
