# KernDX Framework Compliance Scanner

KernDX's PMD rulesets and ESLint plugin enforce framework conventions, universal test quality, and configurable naming standards. They run in IDEs
(VS Code inline warnings), CI/CD tools (Gearset, Copado, AutoRABIT, CodeScan), and Salesforce Code Analyzer.

**Files:**

| File                                | Scope                                   | What It Enforces                                                                                                                                                                                                                                                                                                                           |
|-------------------------------------|-----------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `kerndx-pmd-ruleset.xml`            | Repos that build on KernDX (full ruleset) | Every KernDX rule — use this when your org runs the framework. Includes the "use the framework API instead of the platform primitive" rules (`KernNoDirectDML`, `KernNoRawHttp`, `KernUseSchedulerBase`, `KernNoInlineDmlInTests`, etc.) which only make sense when the framework is present.                                              |
| `kerndx-hygiene-ruleset.xml`        | Any Salesforce repo (no framework needed) | Framework-agnostic tier: `KernNoLegacyAssert`, `KernNoCoverageTheatre`, `KernCoverageExemptRequiresReason`, `KernNoBooleanExceptionThrown`, `KernSecurityBypassCallSite`. Self-contained and generated verbatim from the full ruleset (`generate-hygiene-ruleset.js`); `kerndx init` scaffolds it when a repo does not use the framework. |
| `kerndx-framework-ruleset.xml`      | Kern framework package itself           | Subset that excludes the "use the framework API" rules. The framework IMPLEMENTS those APIs on top of the platform primitives, so enforcing them on the package would be architecturally wrong. Keeps the universal rules: trigger delegation, REST resource naming, and the test-quality set.                                             |
| `subscriber-naming-pmd-ruleset.xml` | Subscriber (configurable)               | Apex class naming (`Domain_[Brand_]Layer_Name`), trigger naming (`TRG_ObjectName`), 40-char limit                                                                                                                                                                                                                                          |
| `combined-pmd-ruleset.xml`          | Subscriber orgs (single-file reference) | Full subscriber ruleset + subscriber naming — use when your tool only accepts one file (IntelliJ/Illuminated Cloud)                                                                                                                                                                                                                        |
| `eslint-plugin-kerndx/`             | Framework + subscriber naming           | `ComponentBuilder` usage, `console.log` blocking, LWC component naming (`domain[Brand]Feature`), Jest test-quality rules                                                                                                                                                                                                                   |
| `validate-naming.js`                | Subscriber (standalone)                 | Flow and Custom Object naming (artefacts PMD/ESLint cannot parse)                                                                                                                                                                                                                                                                          |

The framework ruleset references rule definitions in `kerndx-pmd-ruleset.xml` via `<rule ref="…">`,
so rule text lives in exactly one place; the hygiene ruleset carries verbatim copies of its five
rules instead (PMD resolves relative references against the working directory, so a reference-based
file breaks when copied elsewhere) and a generator plus test keep those copies identical to the
source. `code-analyzer.yml` in this repo points at `kerndx-framework-ruleset.xml` — that is what
the framework's own CI runs against. Point your tooling at `kerndx-pmd-ruleset.xml` if your org
runs the framework, `kerndx-hygiene-ruleset.xml` if it does not, or `combined-pmd-ruleset.xml` if
you also need the naming rules in a single file.

## Rules

Priority tiers: **1** = blocker (must fix), **3** = should fix, **5** = informational (best practice).

| Rule                               | What It Blocks                                                                                                                                            | Use Instead                                                                                | Priority |
|------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------|----------|
| `KernTriggerMustDelegate`          | Logic in trigger body                                                                                                                                     | `new TRG_Dispatcher().run()`                                                               | 1        |
| `KernNoInlineSOQL`                 | `[SELECT ...]`, `Database.query()` outside `SEL_*`/`QRY_*`                                                                                                | Selector or `QRY_Builder`                                                                  | 1        |
| `KernNoCoverageTheatre`            | Zero-assertion tests, empty `catch(Exception e) {}`, `Boolean exceptionThrown = true`, `Assert.isNotNull(record)` immediately after `TST_Builder.build()` | Real assertions on observed behaviour (`Assert.areEqual`, `Assert.isInstanceOfType`, etc.) | 1        |
| `KernCoverageExemptRequiresReason` | `// kern-coverage-exempt:` with empty, short, or blocklisted reason                                                                                       | Document a concrete, testable reason ≥15 chars                                             | 1        |
| `KernNoDirectDML`                  | `insert`/`update`/`delete`/`upsert`, `Database.*` DML                                                                                                     | `DML_Builder`                                                                              | 3        |
| `KernNoSystemDebug`                | `System.debug()`                                                                                                                                          | `LOG_Builder`                                                                              | 3        |
| `KernNoRawHttp`                    | `new HttpRequest()`, `new Http()`                                                                                                                         | `UTIL_HttpClient`                                                                          | 3        |
| `KernUseSchedulerBase`             | `implements Schedulable` directly                                                                                                                         | `extends SCHED_Base`                                                                       | 3        |
| `KernNoRawSchedule`                | `System.schedule()`                                                                                                                                       | `SCHED_Base` + `ScheduledJob__c`                                                           | 3        |
| `KernNoRawEventPublish`            | `EventBus.publish()`                                                                                                                                      | `LOG_Builder` / framework events                                                           | 3        |
| `KernNoRawHttpMock`                | `implements HttpCalloutMock/WebServiceMock`                                                                                                               | `API_MockFactory`                                                                          | 3        |
| `KernNoRawRestContext`             | `RestContext.request/response`                                                                                                                            | `API_Inbound` framework                                                                    | 3        |
| `KernNoRawEmail`                   | `Messaging.sendEmail()`, `new SingleEmailMessage()`                                                                                                       | `UTIL_Email`                                                                               | 3        |
| `KernRestResourceNaming`           | `@RestResource` on non-`REST_*` class                                                                                                                     | `REST_*` + `API_Dispatcher`                                                                | 3        |
| `KernNoInlineDmlInTests`           | Inline DML (`insert record;`, etc.) in `_TEST.cls` files outside the framework allowlist                                                                  | `TST_Builder.build()` / `DML_Builder`                                                      | 3        |
| `KernNoLegacyAssert`               | `System.assert*()`                                                                                                                                        | `Assert.*`                                                                                 | 5        |
| `KernUseTestBuilder`               | `new Account(Name = ...)` in tests                                                                                                                        | `TST_Builder`                                                                              | 5        |
| `KernNoBooleanExceptionThrown`     | `Boolean exceptionThrown = true/false` followed by asserting the flag                                                                                     | `Assert.fail` + `Assert.isInstanceOfType` inside the catch block                           | 5        |
| `KernNoRawCache`                   | `Cache.Org.*`, `Cache.Session.*`                                                                                                                          | `UTIL_Cache`                                                                               | 5        |
| `KernNoRawDescribe`                | `Schema.getGlobalDescribe()`                                                                                                                              | `UTIL_SObjectDescribe`                                                                     | 5        |
| `KernNoRawTypeForName`             | `Type.forName()`                                                                                                                                          | `UTIL_System.getTypeForClassName()`                                                        | 5        |
| `KernNoRawEnqueueJob`              | `System.enqueueJob()`                                                                                                                                     | `UTIL_AsynchronousJobLauncher`                                                             | 5        |
| `KernNoRawCrypto`                  | `Crypto.*`                                                                                                                                                | `UTIL_Crypto`                                                                              | 5        |
| `KernNoRawFeatureManagement`       | `FeatureManagement.checkPermission()`                                                                                                                     | `UTIL_FeatureFlag.isEnabled()`                                                             | 5        |

The four PMD test-quality rules above — `KernNoCoverageTheatre`, `KernCoverageExemptRequiresReason`,
`KernNoInlineDmlInTests`, `KernNoBooleanExceptionThrown` — catch the canonical coverage-theatre anti-patterns
so tests can't silently pad the coverage number without exercising real behaviour.


## Suppressing Rules

Add `@SuppressWarnings('PMD.RuleName')` to the class or method that needs an exception:

```apex
@SuppressWarnings('PMD.KernNoDirectDML')
public inherited sharing class DML_SharingProxy
{
   // Framework infrastructure — direct DML is intentional here
}
```

Multiple rules: `@SuppressWarnings('PMD.KernNoDirectDML, PMD.KernNoRawHttp')`

## Subscriber Naming PMD Rules

Configurable subscriber naming rules in `subscriber-naming-pmd-ruleset.xml`:

| Rule                        | What It Validates                                     | Priority |
|-----------------------------|-------------------------------------------------------|----------|
| `SubscriberApexClassNaming` | Class names follow `Domain_[Brand_]Layer_Name[_TEST]` | 3        |
| `SubscriberTriggerNaming`   | Trigger names follow `TRG_ObjectName`                 | 3        |
| `SubscriberApexNameLength`  | Class and trigger names do not exceed 40 characters   | 3        |

### `<Brand>` placeholder convention

The ruleset ships with placeholder brand codes (`ACM`, `BTA`) and placeholder
domain codes (`SLS`, `ORD`, `PRD`, `SVC`, `SUB`, `MKT`, `CMN`) in the XPath
patterns. These are example values — every subscriber swaps them for their
own 3-letter abbreviations during initial setup. Fixtures under `scanner/`
and `release-testing/scanner/` use these same placeholder codes; treat them
as stand-ins, not as canonical values. Subscribers replace the brand
alternation in the XPath regex with their own brand codes alongside the
namespace-swap performed when installing KernDX (see the Naming Standards
section of the Code Scanning Guide for the full edit recipe).

## CI/CD Integration

### Salesforce Code Analyzer v5 (SF CLI)

Configure in `code-analyzer.yml`:

```yaml
engines:
  pmd:
    custom_rulesets:
      - scanner/kerndx-pmd-ruleset.xml
      - scanner/subscriber-naming-pmd-ruleset.xml
```

Then run:

```bash
sf code-analyzer run --target force-app/ --view detail
```

### Single-Ruleset Tools (IntelliJ / Illuminated Cloud)

Some tools only accept a single ruleset file. Use the combined ruleset:

```
scanner/combined-pmd-ruleset.xml
```

In **Illuminated Cloud**: Settings > Illuminated Cloud > PMD > Custom Ruleset Path → point to `scanner/combined-pmd-ruleset.xml`.

The combined file uses PMD `<rule ref="..."/>` to include both rulesets by reference — no rules are duplicated.

### VS Code (Apex PMD Extension)

Add to `.vscode/settings.json`:

```json
{
   "apexPMD.rulesets": [
      "scanner/kerndx-pmd-ruleset.xml",
      "scanner/subscriber-naming-pmd-ruleset.xml"
   ]
}
```

VS Code Apex PMD supports multiple rulesets. Violations appear inline as you type.

### Gearset

1. Go to **Static Code Analysis** settings
2. Upload both `scanner/kerndx-pmd-ruleset.xml` and `scanner/subscriber-naming-pmd-ruleset.xml` as custom rulesets
3. Enable for deployment validations

Gearset runs PMD against all Apex classes and triggers during deployment validation. Both rulesets are standard PMD XML — no
additional configuration beyond uploading them.

### Copado

1. Navigate to **PMD SCA Settings** or **Quality Gate** configuration
2. Add both PMD rulesets as custom PMD rulesets
3. Set enforcement level (block or warn)

Copado supports custom PMD rulesets natively. Upload both XML files and they run on every deployment.

### AutoRABIT

1. Go to **Static Code Analysis > Apex PMD**
2. Upload both PMD rulesets
3. Assign to your project's analysis profile

AutoRABIT runs PMD as part of its static analysis pipeline. Custom rulesets are uploaded through the UI and apply to all Apex scans.

### CodeScan

1. Add both rulesets as custom rulesets in your **Quality Profile**
2. Activate the KernDX and subscriber naming rules
3. Set severity thresholds

### Salesforce Code Analyzer (SF Scanner — deprecated v4)

For teams still on `sfdx-scanner` (v4):

```bash
sfdx scanner:run --pmdconfig scanner/kerndx-pmd-ruleset.xml,scanner/subscriber-naming-pmd-ruleset.xml --target force-app/ --format table
```

Note: SF Code Analyzer v5 (`sf code-analyzer`) replaces `sfdx-scanner`. Migrate when possible.

## ESLint LWC Rules

The `eslint-plugin-kerndx` plugin enforces framework and naming conventions in LWC components. PMD cannot parse JavaScript, so these rules are handled via ESLint.

| Rule                                       | What It Blocks                                                                                       | Use Instead                                                                               |
|--------------------------------------------|------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------|
| `kerndx/use-component-builder`             | `extends LightningElement` (including aliased imports)                                               | `extends ComponentBuilder(...)`                                                           |
| `kerndx/no-console-log`                    | `console.log()`, `window.console.*`, `globalThis.console.*`                                          | `this.consoleLog()`, `this.consoleError()`                                                |
| `kerndx/enforce-component-naming`          | LWC folder names without domain prefix                                                               | `domain[Brand]FeatureVariant` (e.g. `ordReturnWizard`)                                    |
| `kerndx/no-jest-theatre`                   | Assertion-less Jest `it`/`test` blocks, hollow `expect(createElement(...)).toBeTruthy()` smoke tests | Query the rendered DOM and assert on the visible outcome                                  |
| `kerndx/no-mutating-shared-fixture`        | `beforeAll` that calls `createElement` while `it` blocks mutate its shared state                     | Create a fresh element per test in `beforeEach`, or scope mutation to a dedicated fixture |
| `kerndx/no-coverage-exempt-without-reason` | `// kern-coverage-exempt:` in `.js` files with empty/short/blocklisted reason                        | Document a concrete, testable reason ≥15 chars (mirrors the Apex rule)                    |

### Setup

Already configured in `force-app/main/default/lwc/eslint.config.mjs`. Runs automatically with `npm run lint`.

### Suppressing

For template-only or utility components that don't need ComponentBuilder features:

```javascript
// eslint-disable-next-line kerndx/use-component-builder -- template-only component
export default class Notice extends LightningElement
{
}
```

## PMD Version Compatibility

The rulesets run on **PMD 7.19.0 or newer** (the PMD `apex` module version; the Salesforce Code Analyzer
ships its own copy inside the `code-analyzer` plugin). Every rule is a KernDX-authored XPath rule and no
standard PMD categories are referenced, so the rulesets load on the Code Analyzer's bundled PMD as-is.
The pipeline still checks the version before scanning: `kerndx doctor` flags a PMD `apex` module older
than 7.19.0, and `kerndx scan` prints the same notice in its preflight.

The rules target **PMD 7** (`net.sourceforge.pmd.lang.rule.xpath.XPathRule`). For a **PMD 6** engine,
change each rule's class attribute to `net.sourceforge.pmd.lang.apex.rule.ApexXPathRule`; PMD 6 is
otherwise untested and not recommended.

The rulesets deliberately reference no standard PMD categories (one reference to a rule your tool's
bundled PMD lacks would stop the whole ruleset loading). If your PMD apex module is 7.26.0 or newer,
you can enable PMD's own rules directly in your tool's configuration alongside these — for example
`category/apex/errorprone.xml/InvocableClassNoArgConstructor`, which flags Flow-invocable classes
missing a zero-argument constructor.

## Validating Locally

```bash
sf code-analyzer run --config-file code-analyzer.yml --rule-selector pmd:KernDXFrameworkCompliance --target force-app/ --view detail
```

## Coverage Harness

The scanner catches coverage *theatre* statically. The per-file coverage gate —
`scripts/evaluate-coverage.js` — catches *regressions* dynamically by measuring
current coverage and comparing it to `scripts/coverage-baseline.json`. Use both
together: the scanner blocks a bad test going in; the harness blocks a file
silently slipping below baseline.

```bash
# Targeted check — after editing one or more apex classes (deploys + runs *_TEST):
npm run coverage:gate -- --apex UTIL_FrameworkMasker
npm run coverage:gate -- --apex ClassA,ClassB

# Targeted check — one or more LWC component folders:
npm run coverage:gate -- --lwc healthCheck
npm run coverage:gate -- --lwc compA,compB

# Full regression gate — walks every class + every LWC file in the baseline:
npm run coverage:gate -- --full

# Baseline refresh — rebuilds coverage-baseline.json from a full RunLocalTests + jest run:
npm run coverage:gate -- --fix-baseline
```

### Floors

Apex: 100% per class. LWC: 95% statements / 95% branches per file. A `// kern-coverage-exempt:
<reason>` comment raises a class to 100% only when the reason is ≥15 chars, non-empty, and not
on the blocklist (`hard to test`, `tricky`, `todo`, `fixme`, `later`, `xxx`, `hack`). The scanner
rule `KernCoverageExemptRequiresReason` enforces the same policy at source level.

### Machine-Readable Output

The harness defaults to human-readable text. Pass `--format` to emit a shape that CI tools can
ingest directly.

#### `--format pmd-xml`

Emits a PMD 7 XML document. Each regression becomes a `<violation>` element under a `<file>`
entry whose `name` attribute is the repo-relative source path. Priority 1 for floor breaches
and regressions; priority 3 for `*_missing` (the class is in the baseline but the current run
returned no data).

```xml
<?xml version="1.0" encoding="UTF-8"?>
<pmd version="7.0.0" timestamp="2026-04-16T00:00:00.000Z" xmlns="http://pmd.sourceforge.net/report/2.0.0">
  <file name="force-app/main/default/classes/Foo.cls">
    <violation beginline="0" endline="0" begincolumn="0" endcolumn="0"
               rule="KernCoverageRegression" ruleset="KernDXCoverage"
               priority="1">apex Foo: 99.0% &lt; baseline 100.0%</violation>
  </file>
</pmd>
```

Gearset, Copado, AutoRABIT, and CodeScan all ingest this XML shape natively per the **CI/CD
Integration** section above — upload the XML alongside the existing PMD rulesets and the
violations render inline on the deployment report.

#### `--format github-annotations`

Emits one annotation line per violation in
the [GitHub Actions workflow-command format](https://docs.github.com/en/actions/reference/workflow-commands-for-github-actions#setting-an-error-message).
`::error` for regressions and floor breaches; `::warning` for `*_missing`. `%`, CR, and LF are
URL-escaped per the GitHub spec so arbitrary messages round-trip safely.

```
::error file=force-app/main/default/classes/Foo.cls,line=1::apex Foo: 99.0%25 < baseline 100.0%25
::warning file=force-app/main/default/classes/New.cls,line=1::apex New: no coverage data returned
::error file=force-app/main/default/lwc/bar/bar.js,line=1::lwc bar: statements 94.0%25 < floor 95.0%25
```

GitHub Actions renders these inline on the PR file diff — no workflow-step changes are needed
beyond running the command and letting stdout flow to the log.

## Customizing naming rules (Flow + Custom Object validator)

`scanner/validate-naming.js` enforces Flow and Custom Object naming
conventions for artefact types that PMD and ESLint cannot parse. As of
v1.0, the validator reads its naming taxonomy from `.kerndx/config.yml`
(if present) — subscribers no longer need to fork `validate-naming.js`
itself to override brand codes, domain codes, or Flow type suffixes.

The matching PMD XPath patterns are NOT yet config-driven — see the
[next section](#customizing-pmd-ruleset-brand-codes) for that fork
recipe. Unifying the two paths is on the post-v1.0 roadmap.

### Schema

Place the following block in `.kerndx/config.yml` (alongside the rest of
your kerndx-pipeline config):

```yaml
naming:
  domains: [SLS, ORD, PRD, SVC, SUB, MKT, CMN]   # Domain prefixes (3-letter)
  brands:  [ACM, BTA]                            # Optional brand segment (3-letter); empty list disables
  flow_types: [BS, AS, BD, SCR, AL, SCH, PE, SF] # Flow type suffixes
  apex_layers: [SEL, TRG, FLOW, SVC, BATCH, SCHED, API, REST, DTO, CTRL, UTIL, LOG, IF, QRY, DML, MAP, TST]
  length_limits:
    flow: 80
    custom_object: 40
    apex: 40
```

Any key you omit defaults to the value above (the same defaults the
validator used in v0.x). To disable the brand segment entirely, set
`brands: []`.

### Loader behaviour

The loader (at `scanner/lib/naming-config-loader.js`) follows a strict
fallback policy:

1. **`.kerndx/config.yml` does not exist** → hardcoded defaults apply
   silently (legacy v0.x behaviour preserved).
2. **`.kerndx/config.yml` exists but YAML parse fails** → the validator
   exits with `Configuration error: YAML parse error in <path>: <details>`
   (exit code 2). It does NOT silently fall back to defaults — that
   would mask a real configuration bug.
3. **YAML parses but a key has the wrong type** → the validator exits
   with a typed error naming the offending key (exit code 2).
4. **`.kerndx/config.yml` exists but has no `naming:` block** →
   hardcoded defaults apply (the file is still consumed by the
   pipeline's other config blocks; the validator just sees no naming
   overrides).

### Worked example

A subscriber named "Globex Industries" wants single-brand validation
(`GLB` only), the domains `INV`, `WMS`, `CRM`, no Flow type segment
constraints (they use Salesforce-suggested naming for flows), and a
60-char Flow limit:

```yaml
naming:
  domains: [INV, WMS, CRM]
  brands:  [GLB]
  flow_types: []
  length_limits:
    flow: 60
```

(An empty `flow_types: []` is a valid config — but note that the
validator's Flow pattern requires a type segment by structure, so
subscribers needing flow-type-less naming must also fork the validator
itself. Roadmap.)

### PMD ruleset is auto-generated from the same config

PMD XPath rule properties are compile-time strings — they cannot read
`.kerndx/config.yml` directly at scan time. KernDX bridges the gap at
scaffold time: `kerndx init` reads `.kerndx/config.yml` and **regenerates**
`scanner/subscriber-naming-pmd-ruleset.xml` from
`scanner/subscriber-naming-pmd-ruleset.xml.eta` so the PMD XPath patterns
stay in lock-step with the Flow + Custom Object naming engine. See the
[next section](#customizing-pmd-ruleset-brand-codes) for the customisation
recipe.

---

## Customizing PMD ruleset brand codes

`scanner/subscriber-naming-pmd-ruleset.xml` is **auto-generated** from
`scanner/subscriber-naming-pmd-ruleset.xml.eta` via
`pipeline/src/lib/render-pmd-ruleset.js`. The checked-in XML is the rendered
default — the source of truth for customisation is `.kerndx/config.yml`, not
the XML itself.

> **Do not hand-edit `subscriber-naming-pmd-ruleset.xml`.** The next
> `kerndx init` run will overwrite your edits. Customise via
> `.kerndx/config.yml` so the XPath patterns stay in sync with the Flow +
> Custom Object naming engine.

### How to customise

Edit `.kerndx/config.yml` (created by `kerndx init`):

```yaml
naming:
  enabled: true
  domains: [INV, WMS, OPS]      # your domain taxonomy
  brands: [ACME, BETA]          # your brand codes (3-5 chars, uppercase alphanumeric)
                                #   omit or set to [] for no brand segment
  apex_layers: [CTL, SRV, REPO] # your Apex layers (defaults to SEL/TRG/FLOW/...)
  length_limits:
    apex: 40                    # Apex class name length cap (10-80, Salesforce hard limit is 40)
```

Then re-run `kerndx init` (or run `kerndx upgrade --force` to refresh an
existing scaffold). The runner reads `.kerndx/config.yml`, validates the
codes (2-5 chars, uppercase alphanumeric, no duplicates), and regenerates
`scanner/subscriber-naming-pmd-ruleset.xml` so the PMD XPath patterns match
your `.kerndx/config.yml` exactly.

### Worked examples

| Subscriber profile                                             | `.kerndx/config.yml` `naming.brands:` |
|----------------------------------------------------------------|---------------------------------------|
| Single brand (e.g. ACME Corp)                                  | `[ACM]`                               |
| Two brands (Northwind + Globex)                                | `[NWD, GLB]`                          |
| No brand segment at all (single-org subscriber, no brand axis) | `[]` (or omit `brands:`)              |
| Three brands (Acme, Beta, Coyote)                              | `[ACM, BET, COY]`                     |

The same pattern applies to `naming.domains` and `naming.apex_layers`.

### Defaults

If `.kerndx/config.yml` does not declare `naming.domains` / `naming.brands` /
`naming.apex_layers`, the renderer falls back to the KernDX framework defaults
(`SLS`/`ORD`/`PRD`/`SVC`/`SUB`/`MKT`/`CMN` × `ACM`/`BTA` ×
`SEL`/`TRG`/`FLOW`/`SVC`/`BATCH`/`SCHED`/`API`/`REST`/`DTO`/`CTRL`/`UTIL`/`LOG`/`IF`/`QRY`/`DML`/`MAP`/`TST`).
The same defaults render the checked-in `scanner/subscriber-naming-pmd-ruleset.xml`.
