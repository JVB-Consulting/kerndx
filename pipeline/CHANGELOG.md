# Changelog

> **Audience:** subscribers consuming `@jvb-consulting/kerndx-pipeline`
> via the `KernDX-<version>-pipeline.zip` bundle. Each entry describes a
> publicly-tagged release. Pair with [`INSTALL-PIPELINE.md`](https://github.com/JVB-Consulting/kerndx/blob/main/pipeline/INSTALL-PIPELINE.md)
> in the bundle for install + upgrade steps.

All notable changes to `@jvb-consulting/kerndx-pipeline` are recorded here. Dates use ISO 8601. The format is based on [Keep a Changelog](https://keepachangelog.com/), and the pipeline package adheres to [Semantic Versioning](https://semver.org/).

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

- **Slack notifications** — configurable per-workflow via `notifications.slack` in `.kerndx/config.yml`; webhook URL passed via `secrets.<WEBHOOK_ENV_VAR>`; rendered payloads support PR-title-prefix suppression and silent-on-clean-pass.

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

See `INSTALL-PIPELINE.md` in the bundle for the full guide (SHA verification, `package.json` scripts wiring, ESLint plugin wire-up, upgrade flow, Windows fallback, troubleshooting).

### Test coverage at release

173/173 pipeline tests + 6/6 ESLint plugin tests + 1241/1241 script tests passing.

[v0.2.0]: https://github.com/JVB-Consulting/kerndx/tree/v1.0.0-121
