# Changelog

> **Audience:** subscribers consuming `@jvb-consulting/kerndx-pipeline`
> via the `KernDX-<version>-pipeline.zip` bundle. Each entry describes a
> publicly-tagged release. Pair with [`INSTALL-PIPELINE.md`](https://github.com/JVB-Consulting/kerndx/blob/main/pipeline/INSTALL-PIPELINE.md)
> in the bundle for install + upgrade steps.

All notable changes to `@jvb-consulting/kerndx-pipeline` are recorded here. Dates use ISO 8601. The format is based on [Keep a Changelog](https://keepachangelog.com/), and the
pipeline package adheres to [Semantic Versioning](https://semver.org/).

---

## [v0.5.0] — 2026-10-12

**Distribution:** `KernDX-1.8.0-11-pipeline.zip`. Ships as `pipeline-v0.5.0` with Kern 1.8.0-11.

This release closes a hole in the CI workflows the pipeline writes: a pull request's branch name or title could run commands in a job or change a Slack message. It also
makes the CLI and three ESLint rules work on Windows, prints one form of the `kerndx` command that runs in every terminal, and fixes the flow rule name in the scaffolded
`code-analyzer.yml`. Workflows already in your repository keep the hole until you write them again: run `node .kerndx-pipeline/bin/kerndx upgrade`, which saves each file
it replaces as `.bak` first. In the rulesets, a new informational rule reports governor limits read straight from `Limits`, `KernTriggerMustDelegate` now checks the
whole trigger body, and `kerndx-framework-ruleset.xml` runs its rules again under Code Analyzer 5.16 and later. A gate may now report findings it missed before.

### Security

**What you need to do:** the fixes below are in the workflow templates. Workflows that an earlier version wrote into `.github/workflows/` keep the old form until you write
them again. Run `node .kerndx-pipeline/bin/kerndx upgrade`, which backs up each file it replaces to `.bak` before it writes the new one. Until you do,
`node .kerndx-pipeline/bin/kerndx doctor` reports those workflows as changed.

- **A pull request's branch name and title can no longer run commands in your workflows.** The branch name is now passed to each workflow step as an environment variable instead of being pasted into the step's script, in `auto-assign`, `release-review-assigned` and the shared branch check that `naming-validation`, `secret-scan` and `sfca-quality-gate` use. The Slack payload step of `sfca-quality-gate` gets the same treatment for the pull request title, author, branch name and target branch. Run `node .kerndx-pipeline/bin/kerndx upgrade` to pick up the new workflow files.
- **Slack messages are built safely.** In `auto-assign`, `pr-ready-to-merge` and `release-review-assigned` the pull request title and branch name used to be pasted straight into the Slack message text, so a crafted title could break the message or add links and mentions to it. Each message is now assembled in code, with the characters `<`, `>` and `&` removed from the title and branch names first, and handed to the Slack action as a step output. The `slack-payload` command that `sfca-quality-gate` uses removes the same characters from the title, author and branch names it receives. `auto-assign` now uses the webhook secret name you chose at `kerndx init` instead of a fixed one. Run `node .kerndx-pipeline/bin/kerndx upgrade` to pick up the new workflow files.
- **Every GitHub Action the workflows use is pinned to an exact commit.** `actions/checkout`, `actions/setup-node`, `actions/github-script`, `actions/setup-java`, `slackapi/slack-github-action` and `forcedotcom/run-code-analyzer` were referenced by a moving version tag, so an upstream change could alter what runs in your pipeline without you opting in. Each reference now names the commit of a specific release, with the release number in a comment beside it. Run `node .kerndx-pipeline/bin/kerndx upgrade` to pick up the new workflow files.
- **The Salesforce CLI and Code Analyzer plugin are installed at fixed versions.** `sfca-quality-gate` installed whatever was newest on each run. It now installs `@salesforce/cli` 2.152.14 and the `code-analyzer` plugin 5.16.0, so a new upstream release cannot change your scan results overnight. Update the two versions in the workflow when you want to move up. Run `node .kerndx-pipeline/bin/kerndx upgrade` to pick up the new workflow files.

### Added

- **`KernLimitsThroughWrapper` PMD rule** *(informational, priority 5)*: reports each place your Apex reads a governor limit straight from the platform's `Limits` class, such as `Limits.getQueries` or `System.Limits.getQueries`, and names the `UTIL_Limits` call to use instead, for example `UTIL_Limits.soqlQueries.used`. Reading every limit through the wrapper means every limit is read the same way, and the near-limit check lives in one place. Only `UTIL_Limits` and its own test class may read `Limits` directly. The rule is in the full ruleset only, which now holds 27 rules; the hygiene and framework tiers leave it out. A scan through the full ruleset gains one Info finding for each direct read.

### Changed

- **The workflows run on the current release of every GitHub Action and on Node 22.** `actions/checkout` 7.0.1, `actions/setup-node` 7.0.0, `actions/github-script` 9.0.0, `actions/setup-java` 6.0.1 and `slackapi/slack-github-action` 4.0.0 replace the previous majors, which ran on the Node 20 action runtime GitHub has retired; `forcedotcom/run-code-analyzer` stays on 2.14.0. The steps that install and run the pipeline itself (the shared bootstrap in `sfca-quality-gate`, `secret-scan` and `naming-validation`, and `scanner-parity`) now pin Node 22 instead of Node 20; `validate-reviewers-json` keeps the Node version `kerndx init` chooses. Self-hosted runners need runner version 2.327.1 or newer for the Node 24 runtime these actions use. Run `node .kerndx-pipeline/bin/kerndx upgrade` to pick up the new workflow files.
- **Rules validated through PMD 7.27.0.** The KernDX rules were re-run against their fixtures on PMD 7.27.0 (released 2026-08-28). `doctor` now treats a bundled PMD apex module of 7.27.0 as validated and warns from 7.28.0 up. Salesforce Code Analyzer still bundles 7.26.0, so scan results do not change until that bundle moves.
- **The pipeline prints one form of its command, which runs in every terminal.** That form is `node .kerndx-pipeline/bin/kerndx`. The `./.kerndx-pipeline/bin/kerndx` form it printed before does not run in Command Prompt. The `doctor` message, the Husky pre-push hook, the scaffolded workflows and the pipeline README now use the portable form. Files that an earlier version scaffolded show as changed in `doctor` until your next `upgrade` writes them again.
- **The install and upgrade steps in the pipeline README run as printed on Windows, macOS and Linux.** Unpacking the bundle has a Command Prompt version (`mkdir` and `tar -xf`) and a macOS or Linux version (`unzip`), and installing the dependencies is one line that works everywhere: `npm ci --omit=dev --prefix .kerndx-pipeline/pipeline`. The upgrade steps now install the dependencies again, which the old steps skipped, and say what `upgrade` backs up: every scaffolded file, not only the ones you changed.
- **The `use-component-builder` message names the package import.** It told every reader to import `ComponentBuilder` from `c/componentBuilder`. With the package installed, the import comes from `kern/componentBuilder`, so the message now names that first, and `c/componentBuilder` for a framework deployed from source.
- **The ESLint example sets `enforce-component-naming` to `error`.** The bundle's ESLint snippet and the plugin README now match the Code Scanning guides, which already used `error`.
- **`KernTriggerMustDelegate` checks the whole trigger body.** The rule used to see only statements nested inside a loop or a branch, so a trigger that ran a query at its top level, or wrapped its dispatcher call in an `if`, passed unnoticed. It now reports every top-level statement other than the call that hands the trigger to the dispatcher, `new TRG_Dispatcher.run` (with or without the `kern.` prefix). A trigger that never calls the dispatcher, such as a new trigger whose body is still empty, is reported too. This is a priority-1 rule in the full and framework rulesets, so a gate may now report findings it missed before: move top-level logic into a trigger action, or add the dispatcher call.

### Fixed

- **Workflow files rendered with `runs-on` and the next line joined together.** The scaffolder trimmed the line break after the runner name, so `auto-assign` and `pr-ready-to-merge` produced a workflow GitHub rejects as invalid. The line break is now kept in every rendered workflow.
- **Answering yes to the auto-assign reviewer question now writes the workflow.** `kerndx init` recorded the answer in `.kerndx/config.yml` but never wrote `.github/workflows/auto-assign.yml`, so if you opted in you never received it. Your next `node .kerndx-pipeline/bin/kerndx upgrade` adds the file: a `pull_request_target` workflow with `pull-requests: write` permission that assigns a reviewer from `.github/reviewers.json` and checks out no pull request code.
- **No workflow references a Slack secret when Slack is off.** `ingress-bypass-alert`, `release-bypass-alert` and `release-review-assigned` rendered their Slack step whether or not Slack was enabled, pointing it at `secrets.undefined`, and `auto-assign` always rendered its two Slack messages and the back-promotion detection step that only feeds one of them. With Slack turned off, all of those steps are now left out, so no rendered workflow mentions a Slack webhook secret.
- **`release-review-assigned` renders a complete branch filter when no release branches are configured.** The job condition used to end in an empty group, `&& `, which GitHub rejects as an invalid expression; it now renders `&& (false)` and the header comment says `(none configured)` instead of trailing off.
- **The CLI finds `sf` on Windows.** `kerndx doctor` and `kerndx scan` reported the Salesforce CLI missing on every Windows machine, because `sf` there is a batch file that needs a shell to start. The pipeline now starts it through Command Prompt on Windows, quoting each argument itself, so a workspace path with a space reaches the scanner intact.
- **Three ESLint rules report on Windows.** `enforce-component-naming`, `no-jest-theatre` and `no-mutating-shared-fixture` split the file path only on the separator of the system they ran on, so on Windows they never found the component name or the `__tests__` folder and reported nothing. Each rule now reads either separator.
- **The scaffolded `code-analyzer.yml` overrides the flow rule under a name Code Analyzer recognises.** The template overrode the after-save rule as `SameRecordFieldUpdates`, a name no Code Analyzer rule has ever carried (it belongs to a different flow tool), and an override that matches no rule is ignored without a warning, so the rule ran at Moderate instead of the Info the template intended. The key is now `SameRecordUpdate`. `init` preserves an existing `code-analyzer.yml` and `upgrade` does not rewrite it, so if yours was scaffolded earlier, rename the key under `rules: flow:` by hand. The CI gate blocks at severity 2, so the finding was reported louder than intended, not blocking.
- **`kerndx-framework-ruleset.xml` runs its rules again under Code Analyzer 5.16 and later.** Code Analyzer 5.16 runs PMD from its own install folder. The framework ruleset pointed at the rule definitions in the full ruleset by a relative path, which stopped resolving there, so a scan that used the file ran no KernDX rule at all and still exited 0. The file now carries its own rule definitions, and what the rules check is unchanged. The `code-analyzer.yml` that `kerndx init` scaffolds uses the full or hygiene ruleset, which were not affected. If your own configuration uses the framework ruleset, a gate that has been passing may now report findings; they were already in your code, so fix them or adjust the gate.
- **The pipeline's dependencies move past published security advisories.** `fast-uri`, which the config schema validator uses, moves from 3.1.5 to 3.1.8, past advisories on host confusion and server-side request forgery, and `js-yaml` moves from 4.3.1 to 4.3.2. A production-dependency audit of the pipeline runs clean.

---

## [v0.4.0] — 2026-08-18

**Distribution:** `KernDX-1.7.0-13-pipeline.zip`. Shipped as `pipeline-v0.4.0` with Kern 1.7.0-13.

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

[v0.5.0]: https://github.com/JVB-Consulting/kerndx/tree/pipeline-v0.5.0
[v0.4.0]: https://github.com/JVB-Consulting/kerndx/tree/pipeline-v0.4.0
[v0.3.0]: https://github.com/JVB-Consulting/kerndx/tree/pipeline-v0.3.0
[v0.2.0]: https://github.com/JVB-Consulting/kerndx/tree/v1.0.0-121
