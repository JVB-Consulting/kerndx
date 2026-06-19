# bin/ — Namespace Swap Toolkit

This directory contains the namespace-swap script shipped in the public source repo. It powers Path 2 (repackage KernDX under your own namespace) for teams who clone the repo.

## Usage

```bash
node bin/swap-namespace.js <namespace>
node bin/swap-namespace.js <namespace> --dry-run
node bin/swap-namespace.js <namespace> --keep-readme   # opt out of README stub
```

`<namespace>` must be 1–15 alphanumeric chars starting with a letter. The reserved set `kern, kernx, kdx, kerndx, sf, sfdx, salesforce, test, admin, system` is rejected.

## What It Does

Performs a one-time stage-then-atomic-swap of your working tree from the `kern` namespace to `<namespace>`:

1. **Inventory** — walks `force-app/` to discover compound tokens (e.g. `kernHome`, `KernLogo`) so case-preserving substitution rules are generated only for tokens that exist.
2. **Stage** — copies the entire working tree into `.swap-staging/working-tree/`, applies content substitutions per file (kern → \<namespace\>), then renames paths bottom-up.
3. **Template-rename** — reads `sfdx-project.template.json`, injects your namespace, and writes the final `sfdx-project.json`. Deletes the template.
4. **Atomic rename** — two-phase journal-tracked rename (current tree → `.swap-rollback/`, then `.swap-staging/working-tree/` → current root). Automatic rollback on partial failure.
5. **Markers** — writes `.namespace-origin.json` (origin marker) and `.namespace-swap.json` (full audit). The script refuses re-execution once the origin marker exists.

## Dry-Run Audit

`--dry-run` performs steps 1–3 in staging, then **returns without renaming**. Staging is left under `.swap-staging/working-tree/` for inspection. Use it to preview the planned changes:

```bash
node bin/swap-namespace.js acmecorp --dry-run
diff -r . .swap-staging/working-tree/ | less
```

The audit object reports `{files: [...], renames: [...], skipped: [...]}` where each entry includes the path and replacement count (for files) or rename source/target (for renames). Binary files (`.png`, `.jpg`, `.svg`, etc.) and non-UTF-8 buffers are listed in `skipped` and copied without substitution.

## Post-Swap Action Required

> **PNG-logo replacement.** `<TargetPascal>Logo.asset` is a PNG image file. The filesystem rename gives it the right API name, but its **byte content is still the KernDX logo**. Before publishing your managed package, replace `<TargetPascal>Logo.asset` with your own 512×512 PNG.

> **Top-level `README.md` is replaced with a subscriber stub by default.** The KernDX upstream `README.md` describes the framework project — Quick Start, clone instructions, Path-1/2/3 framing, and KernDX-branded sections that are appropriate for the upstream project but NOT for your post-swap fork. After a successful swap, the script overwrites `README.md` with a short generated stub that names your namespace, attributes KernDX, and points at the rebranded `docs/` content. Pass `--keep-readme` to suppress this and preserve the swap-transformed upstream README content (subscribers who customized their `README.md` before swapping should opt out).

## After Successful Swap

1. **Register the package** (one-time per namespace):
   ```bash
   sf package create --name <PascalName> --package-type Managed --path force-app --target-dev-hub <DevHubAlias>
   ```
   This creates a `0Ho...` Package Id and adds an alias entry to `sfdx-project.json` `packageAliases`. The SF CLI also fills in the `package` field on the existing `packageDirectories[0]` — no manual edit required (the synthesized template ships without a `package` field on purpose so this merge lands in place rather than appending a second entry).

2. **Build the package version** (pass `--package <PascalName>` to match Step 1; the script's default alias `Kern` only resolves before the swap, so post-swap builds always need the explicit `--package` argument):
   ```bash
   node scripts/build-package.js --package <PascalName> --skip-validation
   ```
   Produces a `04t...` subscriber package version.

3. **Install + test**:
   ```bash
   sf package install --package <04t...> --target-org <scratch>
   npm run test:unit       # LWC component tests
   npm run test:e2e        # Playwright smoke against <scratch>
   ```

   First-time `test:e2e` setup (one-time per workstation):

   ```bash
   npx playwright install --with-deps       # Download chromium + system libs
   export SF_SUBSCRIBER_ORG_ALIAS=<scratch> # Required by release-testing/runner/subscriber-config.js
   sf org open -o <scratch> --url-only -r   # Smoke-test that the alias is authenticated
   ```

   The Playwright suite ships under `release-testing/e2e/`; `playwright.config.js` discovers all 55 specs across `specs/`. `npm run test:e2e -- --list` confirms discovery without launching a browser. Other test entry points (`test:scanner`, `test:release`, `test:pipeline`) are documented in the top-level `README.md`.

## Reference-Doc Regeneration (Optional)

This repo ships pre-generated Apex reference docs under `docs/reference/apex/`. The swap script rewrites these in place, so they're correct for your namespace post-swap.

If you modify Apex source after the swap, regenerate via:

```bash
ICAPEXDOC_HOME=/path/to/IcApexDoc npm run docs:build
```

[IcApexDoc](https://github.com/SCWells72/IcApexDoc/releases) is required on `PATH` (or via `ICAPEXDOC_HOME`) for this step. Without it, `npm run docs:build` will fail. The optional step is documented in `.env.example` (set `ICAPEXDOC_HOME` there).

## Safety Guards

- **Single-shot** — the `.namespace-origin.json` marker blocks re-execution. Re-extract from the original artifact to swap to a different namespace.
- **Lockfile** — `.namespace-swap.lock` prevents parallel runs.
- **Replacement cap** — 10,000 replacements per file is the circuit breaker for regex drift. If any file exceeds this, the swap aborts before any rename.
- **Journal + rollback** — both rename phases are journal-tracked; partial failures restore the original tree before throwing.
- **Reserved names** — common short identifiers (`sf`, `test`, `admin`, etc.) are rejected to avoid Salesforce metadata collisions.
