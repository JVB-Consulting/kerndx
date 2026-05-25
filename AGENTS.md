# AGENTS.md

Tool-neutral entry point for AI coding assistants working in this repository.
The canonical code conventions live in [`docs/Code Conventions - Guide.md`](./docs/Code%20Conventions%20-%20Guide.md);
they apply to every contributor — human or automated — and supersede generic
language/style heuristics that an assistant might apply by default.

## Output grading

Generated code must pass the two rulesets that ship in this repo under `scanner/`:

- **PMD (Apex):** `scanner/kerndx-pmd-ruleset.xml` — KernDX Apex conventions (no inline SOQL/DML, no `System.debug`, no `fflib_` patterns, ApexDoc required, explicit sharing, coverage-theatre detection, etc.).
- **ESLint (LWC + JS):** `scanner/eslint-plugin-kerndx/` — KernDX LWC conventions (no direct `LightningElement`, `ComponentBuilder` extension, etc.).

Run them locally before opening a PR:

```bash
# PMD via Salesforce Code Analyzer (uses scanner/code-analyzer.yml config)
sf code-analyzer run --config-file code-analyzer.yml --target force-app/

# ESLint via the bundled plugin (extend it from your repo's flat config)
npx eslint --config eslint.config.mjs <files>
```

If either fails, fix the violation in source — do not suppress the rule without justification documented in code review.

## Read first

| Document | Purpose |
| --- | --- |
| [`docs/Code Conventions - Guide.md`](./docs/Code%20Conventions%20-%20Guide.md) | Critical Apex/LWC/JS rules, naming, formatting, ApexDoc requirements. |
| [`docs/Installation.md`](./docs/Installation.md) | How adopters install or repackage KernDX. Path 1 (managed package) vs Path 2 (namespace repackage). |
| [`docs/README.md`](./docs/README.md) | Learning paths into Fast Starts + Strategic Guides + the auto-generated Apex reference. |
| [`scanner/README.md`](./scanner/README.md) | How to wire the PMD ruleset + ESLint plugin into a subscriber's CI. |

## Operating rules for AI assistants

- **Match repository style.** Allman braces in Apex + JavaScript, tabs for indentation, 180-char Apex line cap, single-quoted JS strings, K&R-style `if(condition)` (no space before paren).
- **No inline SOQL / DML.** Use `SEL_*` selectors and `DML_Builder` — see [`docs/Selectors - Guide.md`](./docs/Selectors%20-%20Guide.md) and [`docs/DML - Guide.md`](./docs/DML%20-%20Guide.md).
- **No `System.debug`.** Use `LOG_Builder` — see [`docs/Logging - Guide.md`](./docs/Logging%20-%20Guide.md).
- **No `LightningElement` directly.** Use `ComponentBuilder` — see [`docs/LWC - Guide.md`](./docs/LWC%20-%20Guide.md).
- **Declare sharing.** Every Apex class declares one of `with sharing` / `inherited sharing` / `without sharing`. Default to `with sharing`; use `inherited sharing` for selectors + stateless utilities.
- **100% test coverage** on Apex + LWC. Tests must assert behaviour — empty `try { ... } catch { }` blocks and unconditional `Assert.isNotNull(record)` after `TST_Builder.build()` are coverage theatre and rejected by the scanner.
- **No hardcoded namespaces.** Use `SObjectClass.class.getName()` in Apex, `@salesforce/schema/*` and `standard__objectPage` in LWC. Never embed `kern.` as a literal in production code.
- **Use `Assert.*`** in tests, not `System.Assert.*`. Prefer `Foobar__c` over standard objects unless the test specifically validates a standard-object integration.

## Subscriber context

KernDX ships as a managed package under the `kern` namespace. Subscribers may have their own namespace and prefix conventions (e.g., `ACME_SEL_*`). When generating code for a subscriber repo, apply that repo's stated prefix conventions and refer to KernDX classes as `kern.ClassName` from subscriber Apex.

> **Building subscriber code that consumes KernDX?** This file (AGENTS.md) governs work
> *inside this repo*. For AI-generation context to drop into your own subscriber
> repository's AI assistant, use [`docs/AI Agent Instructions.md`](./docs/AI%20Agent%20Instructions.md) —
> it's the comprehensive KernDX framework reference (namespace rules, class patterns,
> common idioms) designed for that purpose.

## Configuration

The release-testing runners read two environment variables:

- `SF_SUBSCRIBER_ORG_ALIAS` — your subscriber test scratch-org alias.
- `KERN_DEV_ORG` — your dev scratch-org alias.

Both are required (no defaults). Export them before invoking `npm run release:phase2`, `npm run release:all`, or any script under `scripts/` that resolves an org alias.

## When this document doesn't apply

- Pure documentation edits.
- Build-script changes that touch only `scripts/` and do not alter Apex or LWC contracts.
- Configuration / metadata edits in `force-app/main/default/customMetadata/`.

For everything else: `docs/Code Conventions - Guide.md` is the rule set.
