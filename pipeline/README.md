# @jvb-consulting/kerndx-pipeline

KernDX CI tooling for Salesforce subscribers — opinionated quality gates that catch SOQL leaks, naming violations, coverage theatre, and stale workflows before they hit your default branch. Works with GitHub Actions. Deployment-tool agnostic (DevOps Center, Gearset, Copado, AutoRabit, custom).

## Who it's for

You want the KernDX engineering discipline (SFCA scans + naming validators + branch protection + Slack pings) on your Salesforce CI pipeline. You may or may not be running the KernDX managed package — this tooling works either way.

## What it gives you

After installation you get:

- **`kerndx scan`** — runs SF Code Analyzer against changed files, with KernDX's curated PMD rulesets
- **`kerndx naming`** — validates Flow + Object + Field naming conventions
- **`kerndx preflight`** — combines both in a Husky pre-push hook
- **`kerndx doctor`** — checks your install + detects drift in scaffolded files
- **9 GitHub Actions workflows** scaffolded into `.github/workflows/` — quality gates, scanning, naming, release flow
- **Branch-protection rulesets** for ingress + release branches
- **ESLint plugin** with 6 LWC behavioral rules

## Install

KernDX Pipeline ships as a self-contained zip on the [Releases page](https://github.com/JVB-Consulting/kerndx/releases). The zip contains the CLI + scanner + workflows + everything needed offline (no npm-registry dependency after the initial install).

**Quickstart:**

```bash
# 1. Download the latest pipeline zip from the Releases page above.
cd /path/to/your/subscriber-repo
unzip /path/to/KernDX-<version>-pipeline.zip -d .kerndx-pipeline

# 2. Install the CLI's own dependencies (one-time, online).
(cd .kerndx-pipeline/pipeline && npm ci --omit=dev)

# 3. Scaffold workflows + config into your repo.
./.kerndx-pipeline/bin/kerndx init
```

The `init` command is interactive — it asks for your package directories, CI tool (DevOps Center / Gearset / Copado / AutoRabit / custom), branch-protection preferences, and Slack settings. It generates `.github/workflows/`, `.husky/pre-push`, `.kerndx/config.yml`, and `.kerndx/manifest.json`.

**Step-by-step install guide:** every zip bundle ships an `INSTALL-PIPELINE.md` at the zip root that walks each step in detail (SHA-256 verification, package.json scripts wiring, ESLint plugin wire-up, the upgrade flow, Windows fallback, troubleshooting). Unzip and open that file once you've grabbed the bundle.

## After installation

Wire convenience scripts into your `package.json`:

```json
{
  "scripts": {
    "kerndx": "./.kerndx-pipeline/bin/kerndx",
    "preflight": "npm run kerndx -- preflight",
    "scan": "npm run kerndx -- scan",
    "naming": "npm run kerndx -- naming",
    "doctor": "npm run kerndx -- doctor"
  }
}
```

Then:

```bash
npm run preflight    # scan + naming on changed files (also runs from pre-push)
npm run doctor       # validate install, detect drift in scaffolded files
```

## Upgrading

When a new bundle ships:

```bash
rm -rf .kerndx-pipeline
unzip /path/to/KernDX-<new-version>-pipeline.zip -d .kerndx-pipeline
./.kerndx-pipeline/bin/kerndx upgrade
```

`upgrade` backs up any locally-modified scaffolded file to `.bak` before overwriting. It refuses to run if `.bak` files from a prior upgrade still exist — review and delete them first, or pass `--force` to skip the review. The full upgrade flow is documented in the bundle's `INSTALL-PIPELINE.md`.

## Command reference

| Command | Purpose |
|---|---|
| `init` | Interactive scaffolder; writes `.github/workflows/`, `.husky/pre-push`, `.kerndx/config.yml` |
| `scan` | Run SFCA against changed files |
| `naming` | Validate Flow + Object naming on changed files |
| `preflight` | Run scan + naming back-to-back (advisory; used by Husky) |
| `doctor` | Validate install + detect drift in scaffolded files |
| `upgrade` | Back up scaffolded files + refresh from a new bundle |
| `classify-ref` | (Internal) Classify a head ref against the configured adapter |
| `slack-payload` | (Internal) Build the Slack payload JSON from CSV + env |

## Architecture (for contributors)

- `bin/cli.js` — sade-based CLI entry; `bin/kerndx` (synthesized in bundle) is the subscriber-facing wrapper
- `src/commands/` — 8 command implementations
- `src/lib/` — utility modules (`diff-base`, `hash` with LF-normalized SHA-256, `config-loader` with ajv + safe-regex, `sfca-runner`, `scan`, `scanner-parity`, `prompts`, `scaffold`)
- `src/naming-engine/` — Flow / Object / Field naming validators with cross-domain mode support
- `src/adapters/` — 6 CI-tool adapters: `none`, `devops-center`, `gearset`, `copado` (experimental), `autorabit` (verified-as-none), `custom`
- `src/templates/` — Eta-rendered GitHub Actions workflows + Husky pre-push + branch-protection rulesets

## Building the distribution zip (monorepo internal)

From the upstream kern monorepo root:

```bash
node scripts/build-distribution.js --flavor=pipeline --version=<kern-package-version>
# → tmp/dist/KernDX-<version>-pipeline.zip + .sha256 sidecar
```

## Testing

```bash
cd pipeline && node --test                          # 152 unit tests
cd scanner/eslint-plugin-kerndx && node --test      # 6 ESLint rule tests
```

CI runs both suites via `.github/workflows/pipeline-ci.yml` on every push.

## License

MIT — see `pipeline/LICENSE` for the full text. The top-level `LICENSE` is BUSL-1.1 with an explicit carve-out for this directory; see its "License Carve-Out for Pipeline Tooling" section. For licensing inquiries about the broader framework, contact `jason@jvb-consulting.io`.
