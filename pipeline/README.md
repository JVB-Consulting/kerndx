# @jvb-consulting/kerndx-pipeline

KernDX CI tooling for Salesforce subscribers — opinionated quality gates that catch SOQL leaks, naming violations, coverage theatre, and stale workflows before they hit your
default branch. Works with GitHub Actions. Deployment-tool agnostic (DevOps Center, Gearset, Copado, AutoRabit, custom).

## Who it's for

You want the KernDX engineering discipline (SFCA scans + naming validators + branch protection + Slack pings) on your Salesforce CI pipeline. You may or may not be running the
KernDX managed package — this tooling works either way.

## What it gives you

After installation you get:

- **`kerndx scan`** — runs SF Code Analyzer against changed files, with KernDX's curated PMD rulesets
- **`kerndx secret-scan`** — flags Salesforce + common secrets (auth URLs, tokens, keys) in changed files
- **`kerndx naming`** — validates Flow + Object + Field naming conventions
- **`kerndx preflight`** — combines scan + secret-scan + naming in a Husky pre-push hook
- **`kerndx doctor`** — checks your install + detects drift in scaffolded files
- **10 GitHub Actions workflows** scaffolded into `.github/workflows/` — quality gates, secret scanning, naming, release flow
- **Branch-protection rulesets** rendered to `.kerndx/rulesets/`, ready for `gh ruleset create`
- **ESLint plugin** with 7 LWC behavioral rules

## Install

KernDX Pipeline ships as a self-contained zip on the [Releases page](https://github.com/JVB-Consulting/kerndx/releases). The zip contains the CLI + scanner + workflows + everything
needed offline (no npm-registry dependency after the initial install).

**Quickstart:**

Download `KernDX-YourVersion-pipeline.zip` from the Releases page above and put it in your project's top folder, the folder that holds `sfdx-project.json`. In the commands
below, replace `YourVersion` with the version in the file name you downloaded.

Unpack it into a folder named `.kerndx-pipeline`. On Windows, in Command Prompt:

```bat
mkdir .kerndx-pipeline
tar -xf KernDX-YourVersion-pipeline.zip -C .kerndx-pipeline
```

On macOS or Linux:

```bash
unzip KernDX-YourVersion-pipeline.zip -d .kerndx-pipeline
```

Install the CLI's own dependencies (one-time, online), then scaffold workflows + config into your repo:

```shell
npm ci --omit=dev --prefix .kerndx-pipeline/pipeline
```

```shell
node .kerndx-pipeline/bin/kerndx init
```

The `init` command is interactive: it asks for your package directories, whether the repo builds on the KernDX framework
(which picks the PMD ruleset your CI scans against), CI tool (DevOps Center / Gearset / Copado / AutoRabit / custom),
branch-protection preferences, and Slack settings. It generates `.github/workflows/`, `.husky/pre-push`, `code-analyzer.yml`,
`.kerndx/config.yml`, `.kerndx/rulesets/`, and `.kerndx/manifest.json`.

To run `init` without questions, for example in a CI job or a script, put the answers in a JSON file and pass it with `--answers-file`. On Windows, in Command Prompt:

```bat
node .kerndx-pipeline\bin\kerndx init --answers-file kerndx-answers.json
```

On macOS or Linux:

```bash
node .kerndx-pipeline/bin/kerndx init --answers-file kerndx-answers.json
```

A small answers file looks like this. `package_dirs`, `ci_adapter.name` and `branches.main` are required; every other answer is optional.

```json
{
  "package_dirs": ["force-app/main/default"],
  "framework_package": true,
  "ci_adapter": {"name": "none"},
  "branches": {"main": "main", "ingress": ["main"], "protected": ["main"], "release": []},
  "slack": {"enabled": false}
}
```

`init` checks every answer before it writes anything, and stops with an error that names the file and the answer when:

- a required answer is missing;
- an answer has the wrong kind of value, for example text where `true` or `false` belongs;
- `ci_adapter.name` is not one of `gearset`, `copado`, `autorabit`, `devops-center`, `none` or `custom`;
- `ci_adapter.name` is `copado` or `autorabit` without `"experimental": true`. These adapters are experimental, and the questions ask you to confirm them;
- a package folder, `slack.suppress_on_pr_title_prefix` or `codeowners_team_slack_id` holds a quote character (`'` or `"`).
  The workflows put these values in quotes, so a quote inside one would break the workflow;
- a package folder or a branch name starts or ends with a space, or holds a comma. The questions trim each answer and split a list on commas, so a file may not give a name they would change;
- `workflows.runs_on` holds anything but letters, digits, dots, underscores and dashes, such as `ubuntu-latest`. The workflows use it as it is;
- a text answer (a package folder, a branch name, `workflows.runs_on`, a Slack answer or `codeowners_team_slack_id`) holds a line break.

`init` also builds every file in memory before it writes the first one. If a file cannot be built, for example because a naming answer
is not valid, `init` stops with the error and leaves your repo as it was.

When you leave out `branches.ingress`, it is the main branch. When you leave out `branches.protected`, it is the main, ingress and release branches together.
When you leave out `branches.release` but give `branches.protected`, every protected branch that is not an ingress branch gets the release gate.
When Slack is on and you leave out `slack.webhook_env_var`, the secret name is `SLACK_WEBHOOK_URL`.
Add `--check` to list the files `init` would write without writing them.

**Step-by-step install guide:** every zip bundle ships an `INSTALL-PIPELINE.md` at the zip root that walks each step in detail (SHA-256 verification, package.json scripts wiring,
ESLint plugin wire-up, the upgrade flow, troubleshooting). Unzip and open that file once you've grabbed the bundle.

## After installation

Wire convenience scripts into your `package.json`:

```json
{
  "scripts": {
    "kerndx": "node .kerndx-pipeline/bin/kerndx",
    "preflight": "npm run kerndx -- preflight",
    "scan": "npm run kerndx -- scan",
    "secret-scan": "npm run kerndx -- secret-scan",
    "naming": "npm run kerndx -- naming",
    "doctor": "npm run kerndx -- doctor"
  }
}
```

Then:

```bash
npm run preflight    # scan + secret-scan + naming on changed files (also runs from pre-push)
npm run doctor       # validate install, detect drift in scaffolded files
```

## Secret scanning

Every PR runs a **Secret Scan** status check, and `preflight` runs the same scan locally before each push. It looks for credentials that should never reach a repository, with
patterns tuned for Salesforce:

- **SFDX auth URLs** (`force://…`) — the highest-risk leak; one is enough to mint access tokens for your org
- **Session / access tokens** and **OAuth refresh tokens**
- **Connected-app consumer secrets** and Salesforce credential environment variables assigned a literal value
- **Private keys** (PEM) and common cloud keys (AWS, GitHub, Slack, Google)

It is deliberately tuned to avoid false alarms on the things that *look* secret but aren't: bare org IDs and record IDs, 18-character API names, UUIDs, hashes, and CI templating
expressions like `${{ secrets.X }}` are never flagged.

The check blocks a PR only on **unambiguous credential shapes** — auth URLs, access and refresh tokens, PEM private keys, and the prefixed cloud keys — where the structure alone
identifies a secret. **Keyword-anchored assignments** (a `client_secret=` or `SF_ACCESS_TOKEN=` literal), JWTs, and generic credential assignments are reported as **advisories**:
they flag a likely leak for review without failing CI, because a pattern alone can't reliably tell a real value from a placeholder or a reference. Locally, `preflight` reports
findings but lets your push proceed — CI is the hard gate.

**This complements, it does not replace, your platform's native scanning.** Turn on your Git host's built-in secret scanning and **push protection** too (GitHub: Settings → Code
security and analysis; GitLab: Secret Detection) so a secret is caught before it ever leaves your machine.

**If a real secret reaches a commit, rotate it.** Deleting it from the working tree is not enough — it stays in your Git history, and in every clone and fork. Treat the credential
as compromised and issue a new one.

Configuration lives under `secret_scanning` in `.kerndx/config.yml`:

```yaml
secret_scanning:
  enabled: true                 # default; set false to skip the scan
  ignore_globs:                 # paths to skip (e.g. test fixtures)
    - '**/test/fixtures/**'
```

The pattern set is fixed and maintained in the pipeline; there are no subscriber-supplied regexes to configure. Setting `enabled: false` turns scanning off, but the `Secret Scan`
status check still reports green — so a required check passing no longer guarantees a scan ran. Treat `.kerndx/config.yml` as security-sensitive and protect it with CODEOWNERS /
branch protection: an `ignore_globs` entry narrows what the scan sees.

To silence a confirmed-safe finding without disabling the gate: add an inline `kerndx-secret-allow: <reason>` comment **on the offending line** (it exempts that whole line), or
list the finding's fingerprint (printed in the scan output as `path:rule:hash`) in a `.kerndxsecretsignore` file at your repo root (the fingerprint is derived from the secret, so
it survives rebases and line moves). A strong redaction sentinel such as `***REDACTED***` or `***MASKED***` on a line suppresses any finding on that whole line (handy for sample
and fixture content); a bareword like `placeholder` suppresses only advisory findings, never a blocking one. These suppressions are an honor-system convenience for the committer
— your Git host's push protection is the real backstop.

## Upgrading

When a new bundle ships, download the newer `KernDX-YourVersion-pipeline.zip` into your project's top folder, then replace the old tooling with it. On Windows, in Command
Prompt:

```bat
rmdir /s /q .kerndx-pipeline
mkdir .kerndx-pipeline
tar -xf KernDX-YourVersion-pipeline.zip -C .kerndx-pipeline
```

On macOS or Linux:

```bash
rm -rf .kerndx-pipeline
unzip KernDX-YourVersion-pipeline.zip -d .kerndx-pipeline
```

Install its dependencies again, then let it refresh what it scaffolded:

```shell
npm ci --omit=dev --prefix .kerndx-pipeline/pipeline
```

```shell
node .kerndx-pipeline/bin/kerndx upgrade
```

`upgrade` keeps your `.kerndx/config.yml`, re-renders the workflow templates against the new version, and backs up every scaffolded file to `.bak` before it overwrites it. It
stops if `.bak` files from an earlier upgrade are still there: review and delete them, or add `--force` to skip that review. The full upgrade flow is documented in the
bundle's `INSTALL-PIPELINE.md`.

This version adds a required `Secret Scan` check. After upgrading, let the new `secret-scan.yml` workflow run once on your default branch **before** you re-apply your ingress
branch-protection ruleset — so the check exists and has reported at least once by the time it becomes required. (Requiring a check that has never run leaves every PR waiting on a
status that is never posted.)

## Command reference

| Command         | Purpose                                                                                                                                                |
|-----------------|--------------------------------------------------------------------------------------------------------------------------------------------------------|
| `init`          | Interactive scaffolder; writes `.github/workflows/`, `.husky/pre-push`, `.kerndx/config.yml`; `--answers-file <path>` answers from a JSON file instead |
| `scan`          | Run SFCA against changed files                                                                                                                         |
| `secret-scan`   | Flag Salesforce + common secrets in changed files (advisory locally, blocking in CI)                                                                   |
| `naming`        | Validate Flow + Object naming on changed files                                                                                                         |
| `preflight`     | Run scan + secret-scan + naming back-to-back (advisory; used by Husky)                                                                                 |
| `doctor`        | Validate install + detect drift in scaffolded files                                                                                                    |
| `upgrade`       | Back up scaffolded files + refresh from a new bundle                                                                                                   |
| `classify-ref`  | (Internal) Classify a head ref against the configured adapter                                                                                          |
| `slack-payload` | (Internal) Build the Slack payload JSON from CSV + env                                                                                                 |

## Architecture (for contributors)

- `bin/cli.js` — sade-based CLI entry; `bin/kerndx` (synthesized in bundle) is the subscriber-facing wrapper
- `src/commands/` — 9 command implementations
- `src/lib/` — utility modules (`diff-base`, `hash` with LF-normalized SHA-256, `config-loader` with ajv + safe-regex, `sfca-runner`, `secret-patterns` (shared, pure),
  `scanner-parity`, `prompts`, `scaffold`)
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
cd pipeline && node --test                          # 325 unit tests
cd scanner/eslint-plugin-kerndx && node --test      # 8 ESLint rule tests
```

CI runs both suites via `.github/workflows/pipeline-ci.yml` on every push.

## License

MIT — see `pipeline/LICENSE` for the full text. The top-level `LICENSE` is Apache-2.0 and does not apply to this directory, which stays
MIT. For licensing inquiries about the broader framework, contact `jason@jvb-consulting.io`.
