# Workflow examples

This directory holds **pre-rendered** versions of the nine GitHub Actions workflows that ship with the `@jvb-consulting/kerndx-pipeline` distribution.

They are here so you can read the YAML directly — what your `.github/workflows/` will look like once you adopt the pipeline — without needing to install the pipeline first.

| Workflow | What it does |
|---|---|
| [`sfca-quality-gate.yml`](./sfca-quality-gate.yml) | Salesforce Code Analyzer runs on every PR; blocks merge on Critical or High violations in changed files; emits per-violation PR annotations. |
| [`naming-validation.yml`](./naming-validation.yml) | Enforces KernDX naming conventions on Flows + custom objects in changed files. |
| [`auto-assign.yml`](./auto-assign.yml) | Assigns reviewers from `.github/reviewers.json` based on the files changed. |
| [`pr-ready-to-merge.yml`](./pr-ready-to-merge.yml) | Detects when a PR meets all merge criteria (approvals + required checks); posts a comment so the author knows the PR is ready. |
| [`ingress-bypass-alert.yml`](./ingress-bypass-alert.yml) | Alerts on bypass-of-ingress-gate events (administrative merges that skipped a required check). |
| [`release-bypass-alert.yml`](./release-bypass-alert.yml) | Alerts on bypass-of-release-gate events. |
| [`release-review-assigned.yml`](./release-review-assigned.yml) | Assigns release-admin reviewers on PRs targeting release branches. |
| [`scanner-parity.yml`](./scanner-parity.yml) | Asserts the bundled PMD + ESLint rulesets match what the pipeline package ships, so subscribers cannot accidentally drift from the canonical version. |
| [`validate-reviewers-json.yml`](./validate-reviewers-json.yml) | Validates `.github/reviewers.json` against its committed schema on any PR that edits either file. |

## How these were generated

These files are not authoritative. They are renders of the Eta templates that ship inside the pipeline package, produced with a vanilla "subscriber init" configuration:

- Ingress branch: `main`
- Package directory: `force-app/main/default`
- Node version: `22`
- CI adapter: `none`
- Slack: disabled (no webhook env var referenced)
- SFCA rule selector: `pmd,flow,eslint`

If you `kerndx init` with different answers (different branch names, multiple package directories, a CI adapter like Gearset or Copado, Slack enabled), the rendered workflows will differ. To regenerate with your own config:

```bash
./.kerndx-pipeline/bin/kerndx init        # interactive
./.kerndx-pipeline/bin/kerndx upgrade     # if already installed
```

The pipeline then writes the workflows directly to your `.github/workflows/` directory.

## Adopting

Don't copy these files manually into your repo. Install the pipeline:

```bash
unzip KernDX-<version>-pipeline.zip -d .kerndx-pipeline
(cd .kerndx-pipeline/pipeline && npm ci --omit=dev)
./.kerndx-pipeline/bin/kerndx init
```

The `init` command renders the templates with answers you supply, writes them to `.github/workflows/`, and records a manifest at `.kerndx/manifest.json` so subsequent `upgrade` commands know what to refresh.
