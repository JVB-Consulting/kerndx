# bin/ — Namespace Swap Toolkit

This directory contains the namespace-swap script shipped in the public source repo. It powers Path 2 (repackage KernDX under your own namespace) for teams who clone the repo.

## Usage

Pass `--dry-run` to preview the swap without changing your files (it writes the preview to `.swap-staging/working-tree/`), or `--keep-readme` to opt out of the README stub described in "Post-Swap Action Required" below.

```shell
node bin/swap-namespace.js YourNamespace
node bin/swap-namespace.js YourNamespace --dry-run
node bin/swap-namespace.js YourNamespace --keep-readme
```

`YourNamespace` must be 1–15 alphanumeric chars starting with a letter. The reserved set `kern, kernx, kdx, kerndx, sf, sfdx, salesforce, test, admin, system` is rejected.

## What It Does

Performs a one-time stage-then-atomic-swap of your working tree from the `kern` namespace to `YourNamespace`:

1. **Inventory** — walks `force-app/` to discover compound tokens (e.g. `kernHome`, `KernLogo`) so case-preserving substitution rules are generated only for tokens that exist.
2. **Stage** — copies the entire working tree into `.swap-staging/working-tree/`, applies content substitutions per file (kern → YourNamespace), then renames paths bottom-up.
3. **Template-rename** — reads `sfdx-project.template.json`, injects your namespace, and writes the final `sfdx-project.json`. Deletes the template.
4. **Atomic rename** — two-phase journal-tracked rename (current tree → `.swap-rollback/`, then `.swap-staging/working-tree/` → current root). Automatic rollback on partial failure.
5. **Markers** — writes `.namespace-origin.json` (origin marker) and `.namespace-swap.json` (full audit). The script refuses re-execution once the origin marker exists.

## Dry-Run Audit

`--dry-run` performs steps 1–3 in staging, then **returns without renaming**. Staging is left under `.swap-staging/working-tree/` for inspection. Use it to preview the planned changes, then compare each folder you want to check with its staged copy, starting with `force-app` and `docs` (this needs `git`; the swap script itself does not use it):

```shell
node bin/swap-namespace.js acmecorp --dry-run
git diff --no-index force-app .swap-staging/working-tree/force-app
git diff --no-index docs .swap-staging/working-tree/docs
```

Compare folder by folder rather than the whole project: the staged copy leaves out `.git`, `node_modules` and the staging folder itself, so a whole-project comparison lists every file in them as deleted, mixed in with the real changes. The swap rewrites other folders too, such as `release-testing`; put that folder's name in both places to compare it.

The audit object reports `{files: [...], renames: [...], skipped: [...]}` where each entry includes the path and replacement count (for files) or rename source/target (for renames). Binary files (`.png`, `.jpg`, `.svg`, etc.) and non-UTF-8 buffers are listed in `skipped` and copied without substitution.

## Post-Swap Action Required

> **PNG-logo replacement.** `<TargetPascal>Logo.asset` is a PNG image file. The filesystem rename gives it the right API name, but its **byte content is still the KernDX logo**. Before publishing your managed package, replace `<TargetPascal>Logo.asset` with your own 512×512 PNG.

> **Top-level `README.md` is replaced with a subscriber stub by default.** The KernDX upstream `README.md` describes the framework project — Quick Start, clone instructions, Path-1/2/3 framing, and KernDX-branded sections that are appropriate for the upstream project but NOT for your post-swap fork. After a successful swap, the script overwrites `README.md` with a short generated stub that names your namespace, attributes KernDX, and points at the rebranded `docs/` content. Pass `--keep-readme` to suppress this and preserve the swap-transformed upstream README content (subscribers who customized their `README.md` before swapping should opt out).

## After Successful Swap

Steps 1 to 3 are the same steps, in the same order, that the script prints when it finishes; step 4 follows them. Run each line on its own, from the top folder of your project.

1. **Commit the rebrand** (the build needs a working tree with nothing uncommitted in it, so this comes first):
   ```shell
   git add -A
   git commit -m "rebrand to YourNamespace"
   ```

2. **Register the package** (one-time per namespace):
   ```shell
   sf package create --name "YourPackageName" --package-type "Managed" --path "force-app" --target-dev-hub YourDevHubAlias
   ```
   This creates a `0Ho...` Package Id and adds an alias entry to `sfdx-project.json` `packageAliases`. The SF CLI also fills in the `package` field on the existing `packageDirectories[0]`, so you do not have to edit anything by hand (the template ships without a `package` field on purpose, so this merge lands in place rather than appending a second entry).

3. **Build the package version** (pass `--package` with the name you gave in step 2: the script's default alias `Kern` only resolves before the swap, so a build after the swap always needs it. Pass `--dev-org` too: without it the script looks for a Dev Hub called `DevHub`, which is not yours, and the build fails):
   ```shell
   node scripts/build-package.js --package "YourPackageName" --dev-org YourDevHubAlias --no-resync
   ```
   Produces a `04t...` subscriber package version.

4. **Install + test**: `YourPackageVersionId` is the `04t` id step 3 printed. Install it, wait for the install to finish, then run the LWC Jest suite and the Playwright smoke suite:
   ```shell
   sf package install -o YourOrgAlias --package YourPackageVersionId --wait 30 --no-prompt
   npm run test:unit
   npm run test:e2e
   ```

   Before you run `npm run test:e2e` above, set up Playwright. Download Chromium and its system libraries (one-time per workstation):

   ```shell
   npx playwright install --with-deps
   ```

   The Playwright suite reads the subscriber org alias from `release-testing/runner/subscriber-config.js` through the environment. The setting lasts only for the terminal window you set it in, so set it in each new terminal window, before `npm run test:e2e`:

   **Windows (Command Prompt)**

   ```bat
   set SF_SUBSCRIBER_ORG_ALIAS=YourOrgAlias
   ```

   **macOS or Linux**

   ```bash
   export SF_SUBSCRIBER_ORG_ALIAS=YourOrgAlias
   ```

   Smoke-test that the alias is authenticated:

   ```shell
   sf org open -o YourOrgAlias --url-only
   ```

   The Playwright suite ships under `release-testing/e2e/`; `playwright.config.js` discovers the specs across `specs/`. `npm run test:e2e -- --list` confirms discovery without launching a browser. Other test entry points (`test:scanner`, `test:release`, `test:pipeline`) are documented in the top-level `README.md`.

## Reference-Doc Regeneration (Optional)

This repo ships pre-generated Apex reference docs under `docs/reference/apex/`. The swap script rewrites these in place, so they're correct for your namespace post-swap.

If you modify Apex source after the swap, regenerate via:

**Windows (Command Prompt)**

```bat
set ICAPEXDOC_HOME=C:\path\to\IcApexDoc
npm run docs:build
```

**macOS or Linux**

```bash
ICAPEXDOC_HOME=/path/to/IcApexDoc npm run docs:build
```

[IcApexDoc](https://github.com/SCWells72/IcApexDoc/releases) is required for this step: the build finds it through the `ICAPEXDOC_HOME` variable the command for your computer sets. Without it, `npm run docs:build` will fail. `.env.example` documents the variable; nothing reads a `.env` file, so set it with the command above.

## Safety Guards

- **Single-shot** — the `.namespace-origin.json` marker blocks re-execution. Re-extract from the original artifact to swap to a different namespace.
- **Lockfile** — `.namespace-swap.lock` prevents parallel runs.
- **Replacement cap** — 10,000 replacements per file is the circuit breaker for regex drift. If any file exceeds this, the swap aborts before any rename.
- **Journal + rollback** — both rename phases are journal-tracked; partial failures restore the original tree before throwing.
- **Reserved names** — common short identifiers (`sf`, `test`, `admin`, etc.) are rejected to avoid Salesforce metadata collisions.
