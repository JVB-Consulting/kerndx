# Installation

> This guide walks you through setting up your Salesforce development environment to build your own managed package using
> the unmanaged KernDX framework code.

## Table of Contents

<details>
<summary>Expand</summary>

1. [Path 1: Install the KernDX Managed Package](#path-1-install-the-kerndx-managed-package)
   - [Installation](#installation)
   - [Post-Install Configuration](#post-install-configuration)
   - [Subscriber Integration Gotchas](#subscriber-integration-gotchas)
   - [CI Integration User — Manage Flow Permission](#ci-integration-user--manage-flow-permission)
   - [Upgrading](#upgrading)
   - [Release Testing](#release-testing)
2. [Path 2: Repackage Under Your Own Namespace](#path-2-repackage-under-your-own-namespace)
   - [What You'll Do](#what-youll-do)
3. [Prerequisites](#prerequisites)
4. [Step 1: Enable Your Dev Hub](#step-1-enable-your-dev-hub)
5. [Step 2: Register and Link Your Namespace](#step-2-register-and-link-your-namespace)
   - [2.1 Register Namespace in Namespace Org](#21-register-namespace-in-namespace-org)
   - [2.2 Link Namespace to Dev Hub (UI Only)](#22-link-namespace-to-dev-hub-ui-only)
6. [Step 3: Rebrand the Project Tree](#step-3-rebrand-the-project-tree)
   - [3.1 Confirm your starting tree](#31-confirm-your-starting-tree)
   - [3.2 Run the swap script](#32-run-the-swap-script)
   - [3.3 Verify the swap](#33-verify-the-swap)
7. [Step 4: Configure Your Package](#step-4-configure-your-package)
8. [Step 5: Create Your Managed Package](#step-5-create-your-managed-package)
   - [5.1 Create the Package](#51-create-the-package)
   - [5.2 Create Your First Package Version](#52-create-your-first-package-version)
   - [5.3 Test Your Beta Version](#53-test-your-beta-version)
   - [5.4 Promote to Released](#54-promote-to-released)
9. [Complete Example: Acme Corp](#complete-example-acme-corp)
10. [Troubleshooting](#troubleshooting)
    - ["Namespace not found"](#namespace-not-found)
    - ["Package name already exists"](#package-name-already-exists)
    - ["Code coverage below 75%"](#code-coverage-below-75)
    - [Package Build Fails with "Object does not exist"](#package-build-fails-with-object-does-not-exist)
    - ["duplicate value found: CustomNotifTypeName"](#duplicate-value-found-customnotiftypename)
    - [Lightning Page Components Missing](#lightning-page-components-missing)
    - [Metadata Uniqueness Reference](#metadata-uniqueness-reference)
11. [Next Steps](#next-steps)
12. [Path 3: CI Tooling Only](#path-3-ci-tooling-only)
13. [References](#references)
14. [Project Template](#project-template)
    - [Namespace Usage](#namespace-usage)
    - [Placeholders Reference](#placeholders-reference)

</details>

---

## Path 1: Install the KernDX Managed Package

The simplest path — install the pre-built managed package into your org.

### Installation

**Current SubscriberPackageVersionId (1.0.0-121):** `04tfj000000JN0vAAG`

**One-click install** (browser, no CLI required — Salesforce login prompts in-page):

[![Install in Production](https://img.shields.io/badge/Install-Production-blue.svg)](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tfj000000JN0vAAG)
[![Install in Sandbox](https://img.shields.io/badge/Install-Sandbox-orange.svg)](https://test.salesforce.com/packaging/installPackage.apexp?p0=04tfj000000JN0vAAG)

The same buttons are mirrored on every entry of the [Releases page](https://github.com/JVB-Consulting/kerndx/releases) — pick the release matching the version you want to install.

---

**CLI install** — install in production:

```bash
sf package install --package 04tfj000000JN0vAAG --target-org YourProdOrg --no-prompt --wait 15
```

**CLI install** — install in sandbox (point `--target-org` at your sandbox alias):

```bash
sf package install --package 04tfj000000JN0vAAG --target-org YourSandboxOrg --no-prompt --wait 15
```

**Machine-readable source.** If you are scripting installs, prefer `RELEASE-PROVENANCE.json` at the repo root over scraping this guide. The file ships with every release and carries the `subscriber_package_version_id` field as authoritative truth, so tooling can fetch + parse it directly:

```bash
jq -r '.subscriber_package_version_id' RELEASE-PROVENANCE.json
```

For specific older versions, see the [Releases page](https://github.com/JVB-Consulting/kerndx/releases) — each release's description carries its 04t id. Email fallback: `jason@jvb-consulting.io`.

### Post-Install Configuration

After installation, verify the framework is operational:

1. **Org Cache partition** — required for `UTIL_Cache`. Navigate to **Setup > Platform Cache** and verify a partition exists. If none, click **New Platform Cache Partition** and allocate at least 5 MB of Org Cache capacity (10 MB recommended for production).
2. **Session Cache partition** — required for `UTIL_SessionEncryption`. Same location as Org Cache. Allocate at least 3 MB of Session Cache capacity to the same partition.
3. **Trusted URL** — only required if you are calling out to a domain that triggers Salesforce's outbound header-validation (CSP, lockerservice, or hostname binding). For framework smoke-tests against a sandbox or scratch org, you can skip this step. To find your org's My Domain, navigate to **Setup > Company Information > My Domain**. To register an outbound target, navigate to **Setup > Trusted URLs** and add the host you intend to call (do not include a path or trailing slash).
4. **Health Check LWC** — KernDX ships a `healthCheck` Lightning component that diagnoses post-install configuration drift. To install it:
   1. Open **Setup > Lightning App Builder > New** and create (or open) a Lightning App Page, Home Page, or Record Page.
   2. In the component palette, search for **Health Check** under **Custom > Managed**. Drag it onto the page canvas. Save and activate the page.
   3. Open the page. The component renders a status table covering: Org Cache + Session Cache partitions, `TriggerSetting__mdt` records for shipped objects, `MaskingTarget__mdt` wiring, `ApiSetting__mdt` + `ApiCredential__mdt` for outbound calls, scheduled-job presence for retention sweeps, and feature-flag coverage.
   4. Read the status indicators:
      - 🟢 **Pass** — configuration is complete and the capability is operational.
      - 🟡 **Warn** — the capability ships but a recommended setting is missing (e.g. retention scheduled job not yet active); the framework still works.
      - 🔴 **Fail** — a hard prerequisite is missing (e.g. Org Cache partition); the corresponding capability will throw at runtime until fixed. Failing rows sort to the top, with the most foundational issue first.
   5. Each row exposes an inline **Customize** or **Apply** action where the framework can repair the configuration without leaving the page (e.g. apply recommended retention, schedule a sweep job).

### Subscriber Integration Gotchas

Four details that consistently bite subscribers on first integration:

1. **Custom type resolvers must be `global`.** The managed package cannot instantiate `public` subscriber classes via
   `Type.newInstance()` across namespaces. If you implement a `ClassTypeResolver__mdt` resolver, declare the class
   `global with sharing` and use `kern.UTIL_System.getNamespacePrefix()` for namespace-aware resolution:
   ```apex
   global with sharing class MyCustomResolver extends kern.UTIL_TypeResolver.BaseClassResolver
   {
       global override Type resolve(String className) { /* ... */ }
   }
   ```
2. **Subscriber request DTOs need `@JsonAccess` with both flags.** `DTO_JsonBase.serialize()` runs from the managed
   package context, so even request DTOs need serialization access:
   ```apex
   @JsonAccess(Serializable='always' Deserializable='always')
   public class DTO_Request extends kern.DTO_JsonBase { }
   ```
3. **Validation bypass takes a `String`, not an `SObjectType`.** Use
   `kern.UTIL_ValidationRule.bypassObject('Account')`. There is no `bypass(SObjectType)` overload. Validation bypasses
   are tracked separately from `TRG_Base` bypasses and are not cleared by `TRG_Base.clearAllActionBypasses()`.
4. **Current package omits `RequiredPermission__c` / `BypassPermission__c` on `TriggerAction__mdt`,
   `TriggerSetting__mdt`, `ValidationRule__mdt`, and `ValidationRuleGroup__mdt`.** If your subscriber project ships
   CMDT files that reference those fields (from an older install or a future release), strip them before deploy or
   the deploy will fail on "No such column."

### CI Integration User — Manage Flow Permission

Subscriber CI integration users typically run with a custom or `Standard User` profile that lacks `Manage Flow`. The
KernDX flow-reference scanner (`npm run scan:flow-references`) needs that permission to read `FlowDefinitionView` and
`Flow.Metadata`; without it, the scanner returns zero rows and silently passes even when referenced flows are missing.

`Manage Flow` is included in the bundled `Kern Administrator` permission set. Assign it to the integration user as a
one-time setup step:

```bash
sf org assign permset -n kern__Administrator -o <integration-user>
```

If the integration user must run with the minimum permissions required for the scanner — and not the full administrator
surface — create a custom permission set in the subscriber org granting only the `Manage Flow` user permission and
assign that instead.

Sysadmin-profile CI runners (the default in scratch-org-per-build pipelines) already satisfy `Manage Flow` via
`Modify All Data` and do not need either assignment.

### Upgrading

Beta packages cannot be upgraded in-place. To install a new version:

1. Delete the existing scratch org: `sf org delete scratch -o YourOrg --no-prompt`
2. Create a fresh scratch org and install the new package version
3. Redeploy subscriber code

For sandbox/production orgs, push upgrades are managed by the KernDX team.

### Release Testing

Each release candidate goes through a four-phase internal test cycle before publication: environment setup, automated Apex scripts, subscriber test classes, and visual browser checks. Test results for your subscriber version are summarised in the release notes.

---

## Path 2: Repackage Under Your Own Namespace

For teams that want full source ownership — repackage KernDX under your own namespace and managed package.

### What You'll Do

1. Set up your Dev Hub and register a namespace
2. Create a new Salesforce DX project
3. Import and rebrand the KernDX code with your namespace
4. Package and release your own managed package

**Two ways to start:**
- **Clone the public source repo** — `git clone https://github.com/JVB-Consulting/kerndx my-company-framework` gives you a complete Salesforce DX project ready to swap (this is the canonical entry point for Path 2).
- **Or extract a `docs+source` distribution** — older subscribers may have received this as a tarball/zip; once extracted, the working tree is identical to a clone of the public repo and the rest of this guide applies the same way.

Either entry path lands you at the same starting point: a working tree containing `force-app/`, `bin/swap-namespace.js`, `sfdx-project.template.json`, and the rest of the project files. The instructions below assume that starting state.

---

## Prerequisites

Before starting, ensure you have:

- **Salesforce CLI** (latest version) — Install from Salesforce
- **Git** for version control
- **Visual Studio Code** with Salesforce Extension Pack (recommended)
- **Two Salesforce Orgs:**
  - **Dev Hub Org**: Production org or Partner Business Org (to manage packages)
  - **Namespace Org**: Developer Edition org (to register your namespace)
- A working tree of the KernDX project — either a clone of `JVB-Consulting/kerndx` or an extracted `docs+source` distribution (both produce the same starting state)

---

## Step 1: Enable Your Dev Hub

The Dev Hub is the central org that manages all your packages, scratch orgs, and namespaces.

**Use a Production Org or Partner Business Org as your Dev Hub.**

1. Log into your org
2. Navigate to **Setup > Dev Hub**
3. Enable **Dev Hub** and **Unlocked Packages and Second-Generation Managed Packages**
4. Authorize the org from your terminal and set it as your default Dev Hub:

```bash
sf org login web --alias MyCompanyDevHub --set-default-dev-hub
```

**Checkpoint:** Run `sf org list` to verify your Dev Hub is marked as `(D)` for default Dev Hub.

---

## Step 2: Register and Link Your Namespace

A namespace is your unique prefix (e.g., `acmecorp`) that will be part of all your package's API names.

> **CRITICAL — UI ONLY OPERATION:** Linking your namespace to the Dev Hub **MUST** be done through the Salesforce web UI.
> Salesforce CLI does **NOT** support namespace linking via command line. You will need to complete Step 2.2 manually
> in your browser.

### 2.1 Register Namespace in Namespace Org

**Use a Developer Edition Org as your Namespace Org.**

1. Log into your Developer Edition org (or create one at developer.salesforce.com/signup)
2. Navigate to **Setup > Packages > Package Manager**
3. Click **Edit** next to "Namespace Settings"
4. Enter your desired **Namespace Prefix** (e.g., `acmecorp`)
5. Click **Check Availability** to verify it's unique
6. Click **Save** to register the namespace

> **Important:** Once registered, a namespace cannot be changed or reused. Choose carefully!

### 2.2 Link Namespace to Dev Hub (UI Only)

**IMPORTANT:** You **MUST** link the namespace to your Dev Hub using the Salesforce UI. Command-line linking via
Salesforce CLI is **NOT available** — this is a UI-only operation.

**Steps to Link Namespace:**

1. Log into your **Dev Hub org** (from Step 1) in a web browser
2. Click the **App Launcher** (waffle icon) and search for **Namespace Registries**
3. Click **Link Namespace**
4. You'll be redirected to log into your **Namespace Org** (Developer Edition org from Step 2.1)
5. Log in with your Namespace Org credentials and **authorize the connection**
6. You'll be redirected back to your Dev Hub with the namespace now linked

**Checkpoint:** In your Dev Hub, navigate to **Namespace Registries** and verify your namespace appears in the list
with status "Linked".

> **Why UI Only?** Salesforce requires OAuth authentication between the Dev Hub and Namespace Org. This security flow
> can only be completed through the browser-based UI, not via CLI commands.

---

## Step 3: Rebrand the Project Tree

The project ships with a one-shot rebrand script that handles all namespace rewriting automatically. No manual `find`/`sed` recipe required — the script is the single source of truth for the swap.

### 3.1 Confirm your starting tree

From the directory where you cloned the public repo (or extracted the `docs+source` distribution), confirm the project structure is in place:

```bash
ls bin/swap-namespace.js sfdx-project.template.json force-app/
```

If those three paths exist, you have the canonical starting state and can skip to Step 3.2. The tree is already a full Salesforce DX project — `sfdx-project.template.json`, `force-app/`, `scripts/`, `bin/`, `package.json` are all in place. No `sf project generate` step needed.

> **Note for top-level `README.md`:** the swap script does not rewrite the public repo's top-level `README.md`. Its Quick Start and Path-1/2/3 framing describe the upstream KernDX project, not your post-swap fork. Treat it as historical content and follow Steps 3–5 of this guide for the canonical rebrand-then-package recipe. See `bin/README.md` § "Post-Swap Action Required" for details.

### 3.2 Run the swap script

```bash
node bin/swap-namespace.js <your-namespace>
node bin/swap-namespace.js <your-namespace> --dry-run         # preview only, no writes
node bin/swap-namespace.js <your-namespace> --keep-readme     # opt out of README stub
```

Replace `<your-namespace>` with the namespace you registered in Step 2 (e.g. `acmecorp`).

The script rewrites every `kern.ClassName`, `kern__Field__c`, `<kern>` namespace declaration, filesystem path (`kernHome/`, `KernHome.tab-meta.xml`, `KernLogo.asset`), and produces a finalised `sfdx-project.json` from the template in this repo. It writes `.namespace-origin.json` at the working-copy root as proof the swap completed; the script refuses to run a second time on the same tree.

After a successful swap, the script replaces the top-level `README.md` with a short subscriber stub that attributes KernDX, names your namespace, and points at the rebranded `docs/` content — the upstream KernDX README isn't appropriate for your post-swap fork. Pass `--keep-readme` to preserve your own README content (subscribers who wrote a custom README before swap should opt out).

See `bin/README.md` in this repo for full script details, the `--dry-run` audit format, the `--keep-readme` opt-out, and the **post-swap PNG-logo replacement step** (`<TargetPascal>Logo.asset` is renamed correctly but its byte content remains the KernDX logo — replace before shipping to your subscribers).

### 3.3 Verify the swap

```bash
cat .namespace-origin.json                                   # confirms swap target + timestamp
grep -r "kern\." force-app --include="*.cls" --include="*.xml" | head    # should return no matches
grep -r "kern__" force-app --include="*.xml" | head                       # should return no matches
```

**Checkpoint:**
- `.namespace-origin.json` shows your target namespace and an ISO timestamp = swap completed
- `grep` returns no results = no residual `kern.*` references in source

If `grep` returns results, the swap is incomplete. Inspect the matches and report them — the script aims to handle every case, so any residue is a script gap worth fixing.

---

## Step 4: Configure Your Package

The swap script in Step 3.2 already wrote your `sfdx-project.json` from the template (with your namespace, `sfdcLoginUrl`, and `sourceApiVersion: 66.0` in place). **You do not need to edit `sfdx-project.json` manually at this point.**

Skip ahead to Step 5: `sf package create` (5.1) appends a `packageAliases` entry and completes `packageDirectories[0]` with the new `package` field — the template ships without a `package` field on purpose so this merge lands in place rather than duplicating an entry. Step 5.2 then writes the first package version's `versionName` / `versionNumber` into `packageDirectories[0]`.

---

## Step 5: Create Your Managed Package

### 5.1 Create the Package

```bash
sf package create \
  --name "YourCompanyFramework" \
  --package-type "Managed" \
  --path "force-app" \
  --target-dev-hub MyCompanyDevHub
```

**Checkpoint:** Run `sf package list --target-dev-hub MyCompanyDevHub` to see your package listed.

### 5.2 Create Your First Package Version

**First, commit your rebrand to a local branch.** The build script requires a clean `force-app/` tree because it applies namespace prefixes temporarily during the build and reverts them via `git checkout`. From your project root:

```bash
git init                                          # if you haven't already
git add -A && git commit -m "rebrand to YourNamespace"
```

Then build:

```bash
node scripts/build-package.js --package "YourCompanyFramework" --no-resync
```

This takes 10-30 minutes. Save the **Package Version ID** (starts with `04t`) and **Installation URL**.

**Why `build-package.js` instead of `sf package version create` directly?** Custom Metadata records (e.g. `ApiSetting`, `TriggerAction`), Flow metadata, FlexiPages, and LWC `apex://` references store class and field names as plain strings — Salesforce does *not* automatically apply your namespace prefix to those values during a managed-package build. `scripts/build-package.js` Step 1 calls `scripts/prepare-package-build.js`, which injects the prefix into those string fields (e.g. `ClassName__c = "API_PostExample"` → `ClassName__c = "yournamespace.API_PostExample"`) for the duration of the build, then reverts the working tree to its committed state. Running `sf package version create` directly skips this step, and the resulting package will fail at runtime with `API setting record not found for service "yournamespace.<class>"` errors.

`--no-resync` is used because the resync step targets the KernDX maintainer's dev org; you don't have one. Pass `--skip-validation` only for fast smoke builds — release candidates should always run with validation.

### 5.3 Test Your Beta Version

1. Open the **Package Installation URL** from the previous step
2. Install in a scratch org or sandbox
3. Test all functionality thoroughly
4. Verify your namespace prefix appears on all components

### 5.4 Promote to Released

```bash
sf package version promote \
  --package "04tXX0000004XXXXX" \
  --target-dev-hub MyCompanyDevHub
```

---

## Complete Example: Acme Corp

Walkthrough for **Acme Corp** using namespace `acmecorp`:

```bash
# Step 1: Enable Dev Hub
sf org login web --alias AcmeDevHub --set-default-dev-hub

# Step 2: Register and Link Namespace (UI ONLY)
sf org login web --alias AcmeNamespace

# CRITICAL: Steps 2.1 and 2.2 MUST be done in the Salesforce UI:
#
# 2.1 - In AcmeNamespace org: Setup > Packages > Package Manager > Edit Developer Settings
#        Enter "acmecorp" > Check Availability > Save
#
# 2.2 - In AcmeDevHub org: App Launcher > "Namespace Registries" > Link Namespace
#        Login with AcmeNamespace credentials > Authorize
#        Verify "Linked" status

# Step 3: Clone the project and rebrand under the acmecorp namespace
git clone https://github.com/JVB-Consulting/kerndx acme-framework
cd acme-framework

# One-shot namespace swap (rewrites every kern.* reference + paths,
# writes a finalised sfdx-project.json from the template, refuses
# re-execution once .namespace-origin.json exists)
node bin/swap-namespace.js acmecorp

# Verify the swap (should return no matches)
grep -r "kern\." force-app --include="*.cls" --include="*.xml" | head
grep -r "kern__" force-app --include="*.xml" | head

# Confirm the origin marker (target namespace + ISO timestamp)
cat .namespace-origin.json

# Step 4: (No manual edits) — bin/swap-namespace.js in Step 3 already
# wrote sfdx-project.json from the template with the acmecorp namespace.
# sf package create (Step 5.1) will fill in the package alias + complete
# packageDirectories[0]. Skip straight to Step 5.

# Step 5: Create and Release Package
sf package create \
  --name "AcmeFramework" \
  --package-type "Managed" \
  --path "force-app" \
  --target-dev-hub AcmeDevHub

# Commit the rebrand before building (build-package.js requires clean force-app/)
git init && git add -A && git commit -m "rebrand to acme"

# Build via build-package.js so namespace prefixes get injected into CMDT/Flow/LWC files
node scripts/build-package.js --package "AcmeFramework" --no-resync

# Promote to released (replace with your Package Version ID)
sf package version promote \
  --package "04tXX0000004XXXXX" \
  --target-dev-hub AcmeDevHub
```

---

## Troubleshooting

### "Namespace not found"

**Cause:** Namespace not properly linked to Dev Hub.

Follow Step 2.2 to link via the **Salesforce UI** (cannot be done via CLI):

1. Log into **Dev Hub org** in browser
2. Open **App Launcher** > **"Namespace Registries"**
3. Click **"Link Namespace"**
4. Log in with **Namespace Org** credentials
5. **Authorize** the connection
6. Verify status is **"Linked"**

### "Package name already exists"

Choose a different package name, or delete the existing package:
`sf package delete --package "PackageName" --target-dev-hub MyDevHub`

### "Code coverage below 75%"

- Ensure all test classes have `@IsTest` annotation
- Run tests locally: `sf apex run test --test-level RunLocalTests --code-coverage --result-format human`
- Fix any failing tests before creating package version

### Package Build Fails with "Object does not exist"

**Cause:** Duplicate rules (`.duplicateRule-meta.xml`) still reference the original namespace.

```bash
# Find and verify duplicate rule files
find force-app -name "*.duplicateRule-meta.xml"
# Manually update any remaining original namespace references
```

### "duplicate value found: CustomNotifTypeName"

**Cause:** CustomNotificationType has identical name to an existing package in the target org.

**Resolution:**

1. Find the file: `find force-app -name "*.notificationType-meta.xml"`
2. Rename the file to use your namespace prefix
3. Update `<customNotifTypeName>` to be globally unique (include company name)
4. Rebuild package version

### Lightning Page Components Missing

**Cause:** `.flexipage-meta.xml` files reference incorrect namespace in fieldset/component references.

```bash
grep -r "OriginalNamespace" force-app --include="*.flexipage-meta.xml"
```

Update fieldset references, component references, and record type references to use your namespace.

### Metadata Uniqueness Reference

These metadata types enforce global uniqueness and may cause conflicts during coexistence:

| Metadata Type | Uniqueness Field | Resolution |
|---------------|------------------|------------|
| **CustomNotificationType** | `customNotifTypeName` | Rename XML label |
| **DuplicateRule** | `masterLabel` | Rename label |
| **MatchingRule** | `masterLabel` | Rename label |
| **ExternalDataSource** | `endpoint` + `principalType` | Change endpoint |
| **RemoteSiteSetting** | `url` | Use different URL |
| **ContentSecurityPolicy** | `masterLabel` | Rename label |

---

## Next Steps

Once your package is released:

1. **Install in Orgs:** Share the installation URL with your team
2. **Version Updates:** Update `versionNumber` in `sfdx-project.json`, commit the change, and run `node scripts/build-package.js --package "YourCompanyFramework" --no-resync`
3. **Documentation:** Already updated with your namespace from Step 3.2
4. **Customize:** Add your own classes extending KernDX capabilities using `SEL_Base`, `TRG_Base`, `DML_Builder`,
   and `QRY_Builder`
5. **Support:** Set up processes for bug fixes and enhancement requests
6. **Governance:** Establish release management and versioning strategies

For more detail on framework architecture, see the comprehensive guides in the `docs/` folder:
- Triggers Guide, Selectors Guide, Web Services Guide, DTOs Guide, etc.

---

## Path 3: CI Tooling Only

For teams that want the KernDX CI pipeline (ESLint plugin + PMD rulesets + GitHub Actions workflow templates) without taking on the framework itself. The pipeline distribution ships as a standalone zip, lives entirely in your repo's `.kerndx-pipeline/` directory, and adds no Apex, LWC, or managed-package dependencies to your org.

### What's Inside

- `@jvb-consulting/kerndx-pipeline` CLI — 8 commands (`init`, `scan`, `naming`, `preflight`, `doctor`, `upgrade`, `classify-ref`, `slack-payload`).
- ESLint plugin (`eslint-plugin-kerndx`) — 6 behavioral rules with zero formatting opinions.
- Two PMD rulesets — naming + sharing-modifier enforcement.
- Eleven Eta-rendered GitHub Actions workflow templates — scan/preflight/release-notes/Slack-bridge wiring.
- `INSTALL-PIPELINE.md` — full setup guide bundled inside the zip.

### Install

Download `KernDX-<version>-pipeline.zip` from the [Releases page](https://github.com/JVB-Consulting/kerndx/releases), then unpack and initialise:

```bash
unzip /path/to/KernDX-<version>-pipeline.zip -d .kerndx-pipeline
(cd .kerndx-pipeline/pipeline && npm ci --omit=dev)
./.kerndx-pipeline/bin/kerndx init
```

`kerndx init` interactively configures `.kerndx/config.yml` (your prefix/domain conventions, Slack webhook, CI-tool adapter) and wires the workflow templates into `.github/workflows/`. It is safe to re-run after upgrades.

The 9 rendered workflow examples are also browsable in the public repo at [`examples/workflows/`](https://github.com/JVB-Consulting/kerndx/tree/main/examples/workflows) — preview them before installing.

### Upgrading

```bash
unzip -o /path/to/KernDX-<newer-version>-pipeline.zip -d .kerndx-pipeline
(cd .kerndx-pipeline/pipeline && npm ci --omit=dev)
./.kerndx-pipeline/bin/kerndx upgrade --force
```

The `upgrade` command preserves your `.kerndx/config.yml` and re-renders the workflow templates against the new version.

### Full Reference

See the bundled `INSTALL-PIPELINE.md` inside the zip for command reference, config schema, and per-CI-tool adapter notes (DevOps Center, Gearset, Copado, AutoRABIT, custom).

---

## References

- [Second-Generation Managed Packaging Developer Guide](https://resources.docs.salesforce.com/latest/latest/en-us/sfdc/pdf/pkg2_dev.pdf)
- [Create and Register Your Namespace](https://developer.salesforce.com/docs/atlas.en-us.pkg2_dev.meta/pkg2_dev/sfdx_dev_dev2gp_create_namespace.htm)
- [Link a Namespace to a Dev Hub Org](https://developer.salesforce.com/docs/atlas.en-us.pkg2_dev.meta/pkg2_dev/sfdx_dev_dev2gp_link_namespace.htm)
- [Salesforce CLI Command Reference](https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference)
- [Salesforce DX Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev)
- [Managed Packages Overview](https://developer.salesforce.com/docs/atlas.en-us.pkg2_dev.meta/pkg2_dev/sfdx_dev_dev2gp_intro.htm)

---

## Project Template

When setting up a subscriber project that uses KernDX as a managed package, create an `AGENTS.md` file (or your AI
assistant's equivalent — e.g., `CLAUDE.md` for Claude Code, `.cursorrules` for Cursor) in the project root using the
patterns below. Replace all `{{PLACEHOLDERS}}` with your specific values.

### Namespace Usage

All KernDX framework classes require the namespace prefix in subscriber orgs:

```apex
// Query builder
{{NAMESPACE}}.QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<String>{'Name', 'Industry'})
	.condition(Account.Industry).equals('Tech')
	.toList();

// Logging
{{NAMESPACE}}.LOG_Builder.build().error(e).emitAt('MyClass.myMethod');

// Selector
public inherited sharing class {{PREFIX}}SEL_Cases extends {{NAMESPACE}}.SEL_Base
{
	public {{PREFIX}}SEL_Cases()
	{
		super(Case.SObjectType);
	}

	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>{ Case.Subject };
	}
}

// Trigger
trigger TRG_Account on Account (before insert, before update)
{
	new {{NAMESPACE}}.TRG_Dispatcher().run();
}

// DTO
@JsonAccess(Serializable='always' Deserializable='always')
public inherited sharing class {{PREFIX}}DTO_Request extends {{NAMESPACE}}.DTO_JsonBase
{
	@AuraEnabled public String email;

	public override void populate(Id id, {{NAMESPACE}}.DTO_NameValues params)
	{
		super.populate(id, params);
		Case record = (Case)new {{PREFIX}}SEL_Cases().findById(id);
		this.email = record.Contact.Email;
	}
}

// Web Service
public with sharing class {{PREFIX}}API_SendEmail extends {{NAMESPACE}}.API_Outbound { }

// Testing
Account account = (Account){{NAMESPACE}}.TST_Builder.of(Account.SObjectType)
	.withoutInsertion()
	.build();

// LWC
import {ComponentBuilder} from '{{LWC_NAMESPACE}}/componentBuilder';
```

### Placeholders Reference

| Placeholder | Description | Example |
|-------------|-------------|---------|
| `{{NAMESPACE}}` | KernDX package namespace | `ClientLib`, `ACME` |
| `{{ORG_ALIAS}}` | Salesforce org alias | `DevOrg`, `ClientDevOrg` |
| `{{PREFIX}}` | Project class prefix (optional) | `PRJ_`, `ACME_`, or empty |
| `{{LWC_NAMESPACE}}` | LWC import namespace | `acme`, `clientlib` |
| `{{AUTHOR_EMAIL}}` | Developer email | `developer@client.com` |
