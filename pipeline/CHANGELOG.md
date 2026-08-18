# Changelog

> **Audience:** subscribers consuming `@jvb-consulting/kerndx-pipeline`
> via the `KernDX-<version>-pipeline.zip` bundle. Each entry describes a
> publicly-tagged release. Pair with [`INSTALL-PIPELINE.md`](https://github.com/JVB-Consulting/kerndx/blob/main/pipeline/INSTALL-PIPELINE.md)
> in the bundle for install + upgrade steps.

All notable changes to `@jvb-consulting/kerndx-pipeline` are recorded here. Dates use ISO 8601. The format is based on [Keep a Changelog](https://keepachangelog.com/), and the
pipeline package adheres to [Semantic Versioning](https://semver.org/).

---

## [v0.4.0] — Unreleased

**Distribution:** ships alongside the next framework release as `pipeline-v0.4.0` (bundle file name and framework version are recorded here at release).

This release makes the CI gate block what it says it blocks, opens the pipeline to repos that do not run the KernDX framework, and adds a Flow-invocable constructor check that runs on every supported PMD version.

### Added

- **Framework-agnostic hygiene tier.** `kerndx init` now asks whether the repo builds on the KernDX managed package. Answering no scaffolds `code-analyzer.yml` against the new `kerndx-hygiene-ruleset.xml`: the six KernDX rules that need no framework classes (test quality, security-bypass review, Flow-invocable constructors), so the CI gate enforces those checks on their own. The answer persists as `framework_package` in `.kerndx/config.yml` and round-trips through `kerndx upgrade`; existing configs keep the full ruleset.
- **`KernInvocableClassNeedsNoArgConstructor` PMD rule** *(should fix)* — flags Apex classes that declare `@InvocableVariable` fields but no visible no-arg constructor. The platform instantiates those classes through the no-arg constructor, so a class declaring only argument-bearing constructors fails the moment a Flow runs it. This is a KernDX-authored XPath rule with the same intent as the standard PMD check that requires PMD 7.26.0, so it runs on the whole supported range (PMD apex module 7.19.0 and newer, including the version Salesforce Code Analyzer bundles). Brings the ruleset to 26 rules; included in the hygiene and framework tiers as well.
- **`kerndx/no-hardcoded-user-text` ESLint rule** — flags hardcoded user-facing text in LWC toasts, errors, and template bindings; import the text from a Custom Label instead. Brings the plugin to 7 rules.
- **`init` asks for release branches directly.** The answer lands in the new `branches.release` config key, making the stricter release gate reachable from interactive setup. Configs written before the question existed keep the previous derivation (protected branches minus ingress branches).
- **`init` renders the branch-protection rulesets its next steps reference.** `ingress-gate.json` (and `release-gate.json` when a protected branch exists beyond the ingress set) now land in `.kerndx/rulesets/` on scaffold, so the printed `gh ruleset create` commands work on a fresh setup instead of failing on missing files.

### Fixed

- **`scan --ci` now blocks on findings.** CI mode passes the same severity threshold as the quality-gate workflow (blocking severity 1 and 2), so Code Analyzer findings fail the run instead of exiting zero. The CLI and plugin presence preflights also run in CI mode and fail loudly with an accurate message.
- **`scan --ci` no longer passes silently when it cannot work out what changed.** When no diff base can be resolved (a shallow CI clone, for example), the scan now covers the full workspace instead of comparing the latest commit against itself and finding nothing, and an unresolvable changed-file list fails CI loudly. The diff-base resolver also honours a default branch not named `main`.
- **`init` and `upgrade` never overwrite hand-authored branch-protection rulesets.** An existing `.kerndx/rulesets/` file is preserved rather than replaced, and preserved files stay out of the manifest so drift detection does not claim them.
- **Dependency advisories cleared in both shipped trees** (`js-yaml` and `fast-uri` in the pipeline tree; `js-yaml` and `brace-expansion` in the ESLint plugin tree). Production-dependency audits run clean.

### Changed

- **The rulesets are guaranteed loadable on Salesforce Code Analyzer's bundled PMD.** Every rule is a KernDX-authored XPath definition and no standard PMD categories are referenced (one reference to a rule the bundled PMD lacks would stop the whole ruleset loading). Always-run tests enforce that policy, and the hygiene ruleset is generated verbatim from the full ruleset so the two can never drift. Validated floor: PMD apex module 7.19.0.
- **Unwired config knobs removed.** The schema no longer accepts `severity_overrides` or `scanner.changed_files_only`; neither was ever read by the pipeline. Severity tuning is available by editing `code-analyzer.yml` directly, and the scanner already scans changed files by default. The two working knobs (`severity_threshold`, `rule_selector`) are unchanged.

---

## [v0.3.0] — 2026-06-15

**Distribution:** `KernDX-1.1.0-11-pipeline.zip`. Ships alongside the framework as `pipeline-v0.3.0` against framework release `v1.1.0-11`.

This release adds committed-secret scanning, surfaces every security-bypass call site for review, and teaches `doctor` to catch silent PMD-for-Apex version drift.

### Added

- **`secret-scan` — committed-credential detection, wired as a CI gate.** A new `kerndx secret-scan` command scans changed files for credentials that should never reach a repository, with patterns tuned for Salesforce: SFDX auth URLs (`force://…`), session/access tokens and OAuth refresh tokens, connected-app consumer secrets, Salesforce credential environment variables assigned a literal value, PEM private keys, and prefixed cloud keys (AWS, GitHub, Slack, Google). Detection is tiered: unambiguous credential shapes **fail** the PR's Secret Scan status check, while keyword-anchored assignments, JWTs, and generic credential literals are reported as **advisories** that flag a likely leak without blocking CI. It is deliberately quiet on look-alikes — bare org and record IDs, 18-character API names, UUIDs, hashes, and `${{ secrets.X }}` templating are never flagged. `kerndx init` scaffolds the Secret Scan workflow, and `preflight` runs the same scan locally (advisory) before every push. Pairs with — does not replace — your Git host's native push protection.
- **`KernSecurityBypassCallSite` PMD rule** *(informational)* — inventories every security-bypass call site (`withSystemMode`, `bypassSharing`, `withoutSecurity`, validation- and trigger-action bypasses) so a pull request that introduces a new bypass surfaces during review. Acknowledge expected call sites with `@SuppressWarnings('PMD.KernSecurityBypassCallSite')` or an inline `// NOPMD` comment stating the reason.

### Changed

- **`preflight` now also runs `secret-scan`** — the pre-push sequence is `scan` + `secret-scan` + `naming` (previously `scan` + `naming`).
- **`doctor` catches PMD-for-Apex version drift.** `doctor --verbose` now surfaces the PMD Apex module version bundled inside Salesforce Code Analyzer — previously undetectable — and `doctor` warns when that bundled version moves past the version this pipeline has validated against, so a silent Code Analyzer upgrade can't change how your scans behave without telling you.

---

## [v0.2.0] — 2026-05-18 (first public release)

**Distribution:** `KernDX-1.0.0-121-pipeline.zip` (~100 KB, ~60 files). Ships alongside the framework as `pipeline-v0.2.0` against framework release `v1.0.0-121`.

Initial public release of the KernDX CI pipeline + ESLint behavioral rules as a unified zip distribution.

### What ships

- **`kerndx` CLI** with 8 subcommands:
    - `init` — interactive scaffolder (safe-append husky hooks, manifest hashing for drift detection)
    - `scan` — wraps `sf code-analyzer run` with `--target` args derived from changed files
    - `naming` — validates Flow / Custom Object / Custom Field naming against per-project rules
    - `preflight` — sequenced `scan` + `naming` for husky pre-push (advisory; never blocks)
    - `doctor` — environment + schema validation + LF-normalized hash drift detection
    - `upgrade` — backup-and-overwrite (`.bak`) with re-run of `init` non-interactively from cached config
    - `classify-ref` — adapter delegation with `GITHUB_OUTPUT` shape (used internally by workflows)
    - `slack-payload` — Slack notification payload builder (used internally by workflows)

- **CI/CD adapter support** for 6 release-promotion conventions:
    - `none` — pass-through (no PR-interception convention)
    - `devops-center` — pass-through (Salesforce DevOps Center)
    - `gearset` — back-promotion + intercepted-feature regex
    - `copado` (experimental) — `^promotion/.+-DeployTo.+$` branch convention
    - `autorabit` — verified-as-none (AutoRABIT does not intercept PRs by branch renaming)
    - `custom` — config-driven pattern list, first-match wins

- **9 GitHub Actions workflow templates** scaffolded by `init`:
    - `sfca-quality-gate` — runs Salesforce Code Analyzer on changed Apex/metadata
    - `naming-validation` — runs the naming engine on Flow/Object/Field changes
    - `auto-assign` — assigns reviewers based on `reviewers.json`
    - `pr-ready-to-merge` — checks merge prerequisites
    - `ingress-bypass-alert` — Slack alert when a ruleset is bypassed at ingress
    - `release-bypass-alert` — Slack alert when a ruleset is bypassed at release
    - `release-review-assigned` — auto-assigns the release reviewer team
    - `scanner-parity` — drift detector for code-analyzer rule selection
    - `validate-reviewers-json` — schema check for the reviewers config

- **2 PMD rulesets** bundled (`kerndx-pmd-ruleset.xml` + `kerndx-framework-ruleset.xml`):
    - `init` scaffolds `code-analyzer.yml` referencing the bundled rulesets when absent
    - Preserved on `init --force` re-run so subscriber customizations don't get clobbered

- **`@jvb-consulting/eslint-plugin-kerndx`** — 6 behavioral ESLint rules (zero formatting opinions; pairs with Prettier or any style guide):
    - `use-component-builder` — enforces LWC test factory pattern
    - `no-console-log` — bans `console.log` in shipped code
    - `enforce-component-naming` — Custom Object / LWC name parity
    - `no-jest-theatre` — blocks no-op test patterns
    - `no-mutating-shared-fixture` — blocks fixture mutation across tests
    - `no-coverage-exempt-without-reason` — requires justification for coverage waivers

- **Husky pre-push hook** scaffolded by `init` — runs `preflight` advisory check before push (preserves existing hook content via marker comment).

- **Slack notifications** — configurable per-workflow via `notifications.slack` in `.kerndx/config.yml`; webhook URL passed via `secrets.<WEBHOOK_ENV_VAR>`; rendered payloads
  support PR-title-prefix suppression and silent-on-clean-pass.

### Distribution model

- Zip bundle. No npm publication — `kerndx` resolves to `./.kerndx-pipeline/bin/kerndx` after unzip.
- SHA-256 sidecar (`.sha256`) ships next to every bundle for download verification.
- `MANIFEST.json` at the bundle root records the source git SHA, gate results, file count, and per-file hashes.

### Subscriber install

```bash
unzip KernDX-1.0.0-121-pipeline.zip -d .kerndx-pipeline
(cd .kerndx-pipeline/pipeline && npm ci --omit=dev)
./.kerndx-pipeline/bin/kerndx init
```

See `INSTALL-PIPELINE.md` in the bundle for the full guide (SHA verification, `package.json` scripts wiring, ESLint plugin wire-up, upgrade flow, Windows fallback,
troubleshooting).

### Test coverage at release

173/173 pipeline tests + 6/6 ESLint plugin tests + 1241/1241 script tests passing.

[v0.4.0]: https://github.com/JVB-Consulting/kerndx/tree/pipeline-v0.4.0
[v0.3.0]: https://github.com/JVB-Consulting/kerndx/tree/pipeline-v0.3.0
[v0.2.0]: https://github.com/JVB-Consulting/kerndx/tree/v1.0.0-121
