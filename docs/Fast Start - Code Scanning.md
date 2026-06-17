---
navOrder: 90
---

# Fast Start - Code Scanning

**Framework:** KernDX | **Total time:** ~20 minutes

> PMD rulesets and ESLint rules that catch framework violations in your IDE before they reach code review.

**Before you start:**

- [ ] KernDX package installed in your org
- [ ] Org configured post-install — verify with the **Kern** app's Health Check (see [Installation guide](Installation.md#post-install-configuration))
- [ ] VS Code with [Apex PMD extension](https://marketplace.visualstudio.com/items?itemName=chuckjonas.apex-pmd) installed -- or IntelliJ with Illuminated Cloud
- [ ] SF Code Analyzer v5 installed (`sf plugins install @salesforce/plugin-code-analyzer`)
- [ ] Working in a sandbox or scratch org (not production)

**What you'll build:** A fully configured scanning pipeline that catches inline SOQL, direct DML, `System.debug()`, and 21 other framework violations -- inline in your IDE and in
CI/CD.

**Success looks like:** You write a class with `System.debug()` and `[SELECT Id FROM Account]`, and your IDE underlines both lines before you even save.

**In one line:** Drop `scanner/kerndx-pmd-ruleset.xml` into your Apex PMD settings and every framework anti-pattern lights up in your editor.

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [Tier 1: See It Work (~2 minutes)](#tier-1-see-it-work-2-minutes)
    - [The sample violation class](#the-sample-violation-class)
    - [Run the scanner](#run-the-scanner)
2. [Tier 2: Set Up Your Project (~15 minutes)](#tier-2-set-up-your-project-15-minutes)
    - [Step 1: IDE Setup (VS Code)](#step-1-ide-setup-vs-code)
    - [Step 2: SF Code Analyzer v5](#step-2-sf-code-analyzer-v5)
    - [Step 3: IntelliJ / Illuminated Cloud](#step-3-intellij--illuminated-cloud)
    - [Step 4: ESLint for LWC](#step-4-eslint-for-lwc)
3. [Tier 3: Production Patterns (~5-10 minutes)](#tier-3-production-patterns-5-10-minutes)
    - [Priority tiers](#priority-tiers)
    - [PMD rule reference](#pmd-rule-reference)
    - [ESLint rule reference](#eslint-rule-reference)
    - [Suppressing rules](#suppressing-rules)
    - [CI/CD integration](#cicd-integration)
    - [GitHub Actions example](#github-actions-example)
    - [Org-specific naming rules](#org-specific-naming-rules)
4. [Common Issues](#common-issues)
5. [What You Now Know](#what-you-now-know)
6. [Next Steps](#next-steps)

</details>

---

## Tier 1: See It Work (~2 minutes)

### The sample violation class

Create a small, deliberately-violating class in your project so the scanner has something to flag —
`force-app/main/default/classes/ScannerDemo.cls`. It is not a class to keep; delete it once you've seen
the scanner work:

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

SF Code Analyzer v5 reads custom rulesets from a config file. Create `code-analyzer.yml` in your project
root, pointing at the ruleset that shipped in your KernDX pipeline bundle:

```yaml
engines:
  pmd:
    custom_rulesets:
      - scanner/kerndx-pmd-ruleset.xml
```

Run SF Code Analyzer against the demo class using the KernDX ruleset:

```bash
sf code-analyzer run --rule-selector pmd:KernDXFrameworkCompliance --target force-app/main/default/classes/ScannerDemo.cls --config-file code-analyzer.yml --view detail
```

**Expected output** (violations including at minimum):

```text
KernNoInlineSOQL     High       Inline SOQL is not allowed. Use a selector (SEL_*) or QRY_Builder.
KernNoSystemDebug    Moderate   System.debug() is not allowed. Use LOG_Builder for structured, async logging.
```

The scanner found the violations. The inline `[SELECT ...]` should use a selector or [`QRY_Builder`](reference/apex/QRY_Builder.md), and `System.debug()` should use
[`LOG_Builder`](reference/apex/LOG_Builder.md). Severity levels map from PMD priorities: Priority 1 → High, Priority 3 → Moderate, Priority 5 → Low.

> **When to move to Tier 2:** When you want violations to appear inline in your IDE as you type, without running the CLI manually.

---

## Tier 2: Set Up Your Project (~15 minutes)

### Step 1: IDE Setup (VS Code)

Add the KernDX ruleset to your `.vscode/settings.json`:

```json
{
   "apexPMD.rulesets": [
      "scanner/kerndx-pmd-ruleset.xml"
   ]
}
```

Save the file. Open any Apex class that contains `System.debug()` or `[SELECT ...]` -- you'll see yellow/red squiggly underlines on the offending lines. Hover for the rule
name and suggested replacement.

> **Multiple rulesets:** The Apex PMD extension accepts an array. Add org-specific naming rules alongside the framework rules:
> ```json
> "apexPMD.rulesets": [
>    "scanner/kerndx-pmd-ruleset.xml",
>    "scanner/subscriber-naming-pmd-ruleset.xml"
> ]
> ```

### Step 2: SF Code Analyzer v5

For CLI-based scanning (CI/CD, pre-commit hooks, batch analysis), configure `code-analyzer.yml` in your project root:

```yaml
engines:
  pmd:
    custom_rulesets:
      - scanner/kerndx-pmd-ruleset.xml
```

Run the scanner:

```bash
sf code-analyzer run --target force-app/ --view detail
```

This scans all Apex classes and triggers in `force-app/` and displays violations grouped by file. Add `--view table` for a concise tabular format, or add
`--output-file results.csv`
for CI reporting.

### Step 3: IntelliJ / Illuminated Cloud

IntelliJ with Illuminated Cloud only accepts a single PMD ruleset path. Use the combined ruleset that includes all KernDX rules by reference:

1. Open **Settings > Illuminated Cloud > PMD**
2. Set **Custom Ruleset Path** to `scanner/combined-pmd-ruleset.xml`
3. Apply

Violations now appear inline in the IntelliJ editor. The combined file uses PMD `<rule ref="..."/>` -- no rules are duplicated.

### Step 4: ESLint for LWC

The ESLint plugin is configured in `force-app/main/default/lwc/eslint.config.mjs`. Three rules are
**active by default** — `kerndx/no-coverage-exempt-without-reason`, `kerndx/no-jest-theatre`, and
`kerndx/no-mutating-shared-fixture`. Three "use the framework API" rules ship **commented out**, so they
don't fire before you've adopted the component model — `kerndx/use-component-builder`,
`kerndx/no-console-log`, and `kerndx/enforce-component-naming`. Enable them when you're ready by
uncommenting their block in `eslint.config.mjs`:

```text
'kerndx/use-component-builder': 'error',
'kerndx/no-console-log': 'error',
'kerndx/enforce-component-naming': 'error'
```

Run the linter with:

```bash
npm run lint
```

**Verify it works** -- with the `use-component-builder` rule enabled (above), create a test LWC with
`extends LightningElement` instead of `extends ComponentBuilder(...)`:

```javascript
import {LightningElement} from 'lwc';

export default class TestViolation extends LightningElement {}
```

Run `npm run lint` -- you'll see:

```text
error  LWC components must extend ComponentBuilder(...) instead of LightningElement. Import {ComponentBuilder} from c/componentBuilder  kerndx/use-component-builder
```

---

## Tier 3: Production Patterns (~5-10 minutes)

### Priority tiers

The 25 KernDX PMD rules are organized into three priority tiers for phased adoption:

| Tier          | Priority | Count | Approach                                                             |
|---------------|----------|-------|----------------------------------------------------------------------|
| Blockers      | 1        | 4     | Fix immediately -- these bypass core framework patterns              |
| Should Fix    | 3        | 11    | Fix in current sprint -- makes code harder to maintain if left       |
| Informational | 5        | 10    | Fix opportunistically -- best practice, no immediate action required |

**Recommended adoption path:** Start with Priority 1 (triggers and SOQL). Once clean, enable Priority 3. Add Priority 5 when the team is comfortable with the framework.

### PMD rule reference

All 25 KernDX PMD rules:

| Rule                               | What It Blocks                                                                         | Use Instead                                                                                     | Priority |
|------------------------------------|----------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------|----------|
| `KernTriggerMustDelegate`          | Logic in trigger body                                                                  | `new TRG_Dispatcher().run()`                                                                    | 1        |
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
| `KernNoLegacyAssert`               | `System.assert*()`                                                                     | `Assert.*`                                                                                      | 5        |
| `KernUseTestBuilder`               | `new Account(Name = ...)` in tests                                                     | [`TST_Builder`](reference/apex/TST_Builder.md)                                                  | 5        |
| `KernNoRawCache`                   | `Cache.Org.*`, `Cache.Session.*`                                                       | `UTIL_Cache`                                                                                    | 5        |
| `KernNoRawDescribe`                | `Schema.getGlobalDescribe()`                                                           | `UTIL_SObjectDescribe`                                                                          | 5        |
| `KernNoRawTypeForName`             | `Type.forName()`                                                                       | `UTIL_System.getTypeForClassName()`                                                             | 5        |
| `KernNoRawEnqueueJob`              | `System.enqueueJob()`                                                                  | `UTIL_AsynchronousJobLauncher`                                                                  | 5        |
| `KernNoRawCrypto`                  | `Crypto.*`                                                                             | `UTIL_Crypto`                                                                                   | 5        |
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

### Suppressing rules

When a rule produces a false positive or you have a justified exception, suppress it with an annotation and a comment explaining why.

**Apex (PMD):**

```apex
@SuppressWarnings('PMD.KernNoDirectDML')
public inherited sharing class DML_SharingProxy
{
   // Framework infrastructure — direct DML is intentional here
}
```

Multiple rules on one class:

```apex
@SuppressWarnings('PMD.KernNoDirectDML, PMD.KernNoRawHttp')
```

**JavaScript (ESLint):**

```javascript
// eslint-disable-next-line kerndx/use-component-builder -- template-only component with no controller interaction
export default class Notice extends LightningElement {}
```

### CI/CD integration

The PMD rulesets are standard XML files that work with any tool that supports custom PMD rulesets.

| Tool          | Setup                                                                                     |
|---------------|-------------------------------------------------------------------------------------------|
| **Gearset**   | Static Code Analysis settings > upload `kerndx-pmd-ruleset.xml` as a custom ruleset       |
| **Copado**    | PMD SCA Settings > add as custom PMD ruleset > set enforcement level                      |
| **AutoRABIT** | Static Code Analysis > Apex PMD > upload ruleset > assign to analysis profile             |
| **CodeScan**  | Quality Profile > add as custom ruleset > activate KernDX rules > set severity thresholds |

### GitHub Actions example

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
        run: sf code-analyzer run --target force-app/ --view detail
```

### Org-specific naming rules

The `scanner/subscriber-naming-pmd-ruleset.xml` file is an example of org-specific naming rules. It enforces the `Domain_[Brand_]Layer_Name[_TEST]` convention for one specific
subscriber org.

You can create your own naming ruleset following the same pattern:

1. Copy `subscriber-naming-pmd-ruleset.xml` as a starting point
2. Modify the regex in the XPath expression to match your naming convention
3. Update the rule name, message, and description
4. Add the file to your PMD configuration alongside `kerndx-pmd-ruleset.xml`

See the [Code Scanning - Guide](Code%20Scanning%20-%20Guide.md) for detailed instructions on creating custom rules.

---

## Common Issues

| Problem                                                    | Cause                                                                          | Fix                                                                                                                                                          |
|------------------------------------------------------------|--------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------|
| "Rule not found" or "Class not found" error                | PMD version mismatch (v7 vs v6)                                                | Change the `class` attribute on each rule. PMD 7: `net.sourceforge.pmd.lang.rule.xpath.XPathRule`. PMD 6: `net.sourceforge.pmd.lang.apex.rule.ApexXPathRule` |
| Too many violations on first scan                          | Existing codebase predates framework adoption                                  | Use priority tiers for phased adoption -- start with P1 blockers only, expand to P3 and P5 over time                                                         |
| False positive in framework infrastructure class           | Rule correctly flags the pattern, but the class intentionally uses the raw API | Suppress with `@SuppressWarnings('PMD.RuleName')` and add a comment explaining why                                                                           |
| Apex PMD extension not showing violations                  | Ruleset path not set or extension not installed                                | Verify `.vscode/settings.json` has `apexPMD.rulesets` pointing to `scanner/kerndx-pmd-ruleset.xml`                                                           |
| ESLint `kerndx/*` rules not found                          | Plugin not loaded in ESLint config                                             | Verify `eslint.config.mjs` imports and registers `eslint-plugin-kerndx`                                                                                      |
| `combined-pmd-ruleset.xml` fails with relative path errors | Running from wrong directory                                                   | Ensure the working directory contains the `scanner/` folder, or use absolute paths in the `<rule ref="..."/>` elements                                       |

---

## What You Now Know

| Concept                    | What It Does                                                                                                                                                                        |
|----------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `kerndx-pmd-ruleset.xml`   | 25 PMD rules enforcing KernDX framework conventions (triggers, queries, DML, logging, HTTP, coverage hygiene, etc.)                                                                 |
| `eslint-plugin-kerndx`     | 6 ESLint rules enforcing LWC + test conventions (ComponentBuilder, console.log, naming, coverage-exempt justification, jest-theatre prevention, shared-fixture mutation prevention) |
| `combined-pmd-ruleset.xml` | Single-file reference for tools that only accept one ruleset (IntelliJ)                                                                                                             |
| Priority tiers (1/3/5)     | Phased adoption -- start with blockers, expand to should-fix, then informational                                                                                                    |
| `@SuppressWarnings`        | Per-class or per-method opt-out with justification                                                                                                                                  |
| `code-analyzer.yml`        | SF Code Analyzer v5 configuration for CLI and CI/CD scanning                                                                                                                        |

**Key patterns:**

- Start with Priority 1 rules (inline SOQL and trigger delegation) -- these are the highest-impact framework violations
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
