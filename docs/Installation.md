# Installation

> **What this is:** the practical setup guide for getting KernDX into your org. **Why it exists:** there are three ways to adopt the framework, and which one fits depends on how much you want to own the source. **Who should read it:** the developer or admin doing the install, plus the architect deciding which path to take. **Three paths, in order of effort:** Path 1 installs the ready-made managed package in a few clicks (the simplest start). Path 2 clones the public source and repackages it under your own namespace, so you own and can modify the code. Path 3 adds only the continuous-integration tooling (scanner and workflow templates), with no Apex or package in your org. Pick the path that matches your goal, then follow its section below.

## Table of Contents

<details>
<summary>Expand</summary>

1. [Path 1: Install the KernDX Managed Package](#path-1-install-the-kerndx-managed-package)
    - [Installation](#installation)
    - [Post-Install Configuration](#post-install-configuration)
    - [Integration Gotchas](#integration-gotchas)
    - [CI Integration User: Manage Flow Permission](#ci-integration-user-manage-flow-permission)
    - [Upgrading](#upgrading)
    - [Release Testing](#release-testing)
2. [Path 2: Repackage Under Your Own Namespace](#path-2-repackage-under-your-own-namespace)
    - [What You'll Do](#what-youll-do)
3. [Prerequisites](#prerequisites)
4. [Step 1: Enable Your Dev Hub](#step-1-enable-your-dev-hub)
5. [Step 2: Register and Link Your Namespace](#step-2-register-and-link-your-namespace)
    - [Register Namespace in Namespace Org](#register-namespace-in-namespace-org)
    - [Link Namespace to Dev Hub (UI Only)](#link-namespace-to-dev-hub-ui-only)
6. [Step 3: Rebrand the Project Tree](#step-3-rebrand-the-project-tree)
    - [Confirm your starting tree](#confirm-your-starting-tree)
    - [Run the swap script](#run-the-swap-script)
    - [Verify the swap](#verify-the-swap)
7. [Step 4: Configure Your Package](#step-4-configure-your-package)
8. [Step 5: Create Your Managed Package](#step-5-create-your-managed-package)
    - [Create the Package](#create-the-package)
    - [Create Your First Package Version](#create-your-first-package-version)
    - [Test Your Beta Version](#test-your-beta-version)
    - [Promote to Released](#promote-to-released)
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

This is the fastest way to start. You install the ready-built package straight into your org and use it as-is, with the framework's classes living under the `kern` namespace. Choose this path when you want the framework running quickly and are happy to keep the code as a managed dependency rather than owning a copy of the source.

### Installation

**Current SubscriberPackageVersionId (1.3.0-3):** `04tfj000000M0ZFAA0`

**One-click install** (in the browser, no CLI needed; Salesforce prompts you to log in on the page):

[![Install in Production](https://img.shields.io/badge/Install-Production-blue.svg)](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tfj000000M0ZFAA0)
[![Install in Sandbox](https://img.shields.io/badge/Install-Sandbox-orange.svg)](https://test.salesforce.com/packaging/installPackage.apexp?p0=04tfj000000M0ZFAA0)

The same buttons appear on every entry of the [Releases page](https://github.com/JVB-Consulting/kerndx/releases), so you can pick the release that matches the version you want to install.

---

**CLI install**, in production:

```bash
sf package install --package 04tfj000000M0ZFAA0 --target-org YourProdOrg --no-prompt --wait 15
```

**CLI install**, in a sandbox (point `--target-org` at your sandbox alias):

```bash
sf package install --package 04tfj000000M0ZFAA0 --target-org YourSandboxOrg --no-prompt --wait 15
```

**Machine-readable source.** If you are scripting installs, prefer `RELEASE-PROVENANCE.json` at the repo root over scraping this guide. The file ships with every release and
carries the `subscriber_package_version_id` field as authoritative truth, so tooling can fetch + parse it directly:

```bash
jq -r '.subscriber_package_version_id' RELEASE-PROVENANCE.json
```

For a specific older version, see the [Releases page](https://github.com/JVB-Consulting/kerndx/releases): each release's description carries its 04t id. If you need help, email `jason@jvb-consulting.io`.

### Post-Install Configuration

Installing the package is only step one. A few org-level settings still need attention before everything works, and the framework guides you through them so you don't have to hunt them down yourself.

The tool that does this is the **Health Check** built into the **Kern** app. If you installed the package as a System Administrator, the app is already available to you: open the **App Launcher** (the grid icon, top-left), search for **Kern**, and select it. Its **Home** tab runs the Health Check automatically.

The Health Check verifies the configuration listed below and sorts anything outstanding to the top, in three groups: **Action required** for hard prerequisites, **Review recommended** for optional settings, and **Passing** for everything already set. Where it can, it fixes things in place for you. That includes a **Class Type Resolver** generator (it writes a resolver class and its test for you, explained below) and a one-click **Data Retention** scheduler. The Home tab also gives you quick-launch **Administration Tools**: the API Test Harness, the Streaming Event Monitor, the Chain Monitor, the Data Masking Advisor, and the Log Console.

What the Health Check looks for, and how to satisfy it:

1. **Platform Cache.** KernDX ships its own Platform Cache partition (called **LibraryCache**, under the `kern` namespace), so you don't create one. Salesforce does not carry a managed package's cache capacity over to your org, so you allocate the space yourself: in **Setup > Platform Cache**, edit the **LibraryCache** partition.

   Give it **Organisation** cache. Kern uses this to remember state between requests. Without it, automatic retries on failing integrations, protection from repeated errors, and shared configuration lookups all stop working.

   Add **Session** cache where you can. Kern keeps per-user data such as encryption keys there. Without it, that data falls back to Org Cache, which uses more of your org-cache allocation and slows down user-specific operations.
2. **Trusted URL (only if you use the features that need it).** A few Kern features call back into your own org, for example pushing to streaming channels. If you use them, add a Trusted URL for your org's My Domain in **Setup > Trusted URLs** (find your domain under **Setup > Company Information > My Domain**). If you don't use those features, you can skip this step.
3. **Class Type Resolver (optional).** You only need this if you keep your own trigger handlers, validation rules, scheduled jobs, or web-service classes `public` rather than `global`. In that case Kern needs a small helper class (a Type Resolver) to find your classes across its namespace; in plain terms, you tell the framework where to look for your code. Click **Setup** on this row and the Health Check generates a ready-to-deploy resolver and test class for you. See also [Integration Gotchas](#integration-gotchas) below.

To grant non-admin users access to the app, assign the **Kern Administrator** permission set (see [CI Integration User: Manage Flow Permission](#ci-integration-user-manage-flow-permission) below). For a full walkthrough of every check and what each result means,
see [Health Check](Utilities%20-%20Guide.md#health-check) in the Utilities Guide.

### Integration Gotchas

Four details that catch most people on their first integration. Knowing them up front saves a confusing debugging session later.

1. **Custom type resolvers must be `global`.** The framework creates your resolver class from its own namespace, and that only works if the class is declared `global with sharing`. (The `resolveType` method inside it stays `public`: it overrides a `global abstract` method without itself needing to be widened to `global`.) You don't have to write the body by hand: the Kern app's Health Check generates a complete, namespace-aware resolver and a matching test for you (click **Setup** on the Class Type Resolver row; see [Health Check](Utilities%20-%20Guide.md#health-check)). The shape is:
   ```apex
   global with sharing class MyCustomResolver extends kern.UTIL_TypeResolver.BaseClassResolver
   {
       public override Type resolveType(String className) { /* ... */ }
   }
   ```
2. **Your request DTOs need `@JsonAccess` with both flags.** A DTO is a small class that holds exactly the fields you want to move in or out and converts itself to and from JSON. Because the framework runs the conversion from its own namespace, even an inbound request DTO needs serialization access granted with both flags:
   ```apex
   @JsonAccess(Serializable='always' Deserializable='always')
   public class DTO_Request extends kern.DTO_JsonBase { }
   ```
3. **Validation bypass takes a `String`, not an `SObjectType`.** When you turn off a validation rule for an object, pass the object name as text: `kern.UTIL_ValidationRule.bypassObject('Account')`. There is no `bypass(SObjectType)` version of the method. One more thing to know: validation bypasses are tracked separately from trigger (`TRG_Base`) bypasses, so calling `TRG_Base.clearAllActionBypasses()` does not clear them.
4. **The current package does not include the `RequiredPermission__c` and `BypassPermission__c` fields** on `TriggerAction__mdt`, `TriggerSetting__mdt`, `ValidationRule__mdt`, or `ValidationRuleGroup__mdt`. If your own project ships configuration (CMDT) files that reference those fields, perhaps from an older install or in anticipation of a future release, remove the references before you deploy. Otherwise the deploy fails with a "No such column" error.

### CI Integration User: Manage Flow Permission

If you run KernDX checks in a continuous-integration (CI) pipeline, the user that pipeline logs in as needs one specific permission, or a key safety check passes when it shouldn't.

Here's why. The KernDX flow-reference scanner (`npm run scan:flow-references`) confirms that the flows your code references actually exist. To do that it reads `FlowDefinitionView` and `Flow.Metadata`, which require the `Manage Flow` permission. CI integration users usually run on a custom or `Standard User` profile, which lacks that permission. Without it the scanner finds nothing, returns zero rows, and reports success even when a referenced flow is missing. The check looks green but isn't actually checking anything.

The fix is a one-time setup step. The `Manage Flow` permission is already in the bundled `Kern Administrator` permission set, so assign that set to the integration user:

```bash
sf org assign permset -n kern__Administrator -o <integration-user>
```

If you'd rather give the integration user the bare minimum and not the full administrator surface, create your own permission set in the org that grants only the `Manage Flow` user permission, and assign that instead.

One exception: CI runners that use a System Administrator profile (the default when each build spins up its own scratch org) already have `Manage Flow` through `Modify All Data`, so they need neither assignment.

### Upgrading

How you move to a newer version depends on the org type.

In a scratch org, a beta package version can't be upgraded over the top of an older one, so you start fresh:

1. Delete the existing scratch org: `sf org delete scratch -o YourOrg --no-prompt`
2. Create a fresh scratch org and install the new package version
3. Redeploy your own code

In sandbox and production orgs you don't do this manually. Push upgrades are managed by the KernDX team.

### Release Testing

Every release is tested before it reaches you, so you can adopt a new version with confidence. Each release candidate runs through a four-step internal cycle: setting up the test environment, running automated Apex scripts, running the test classes against an installed copy of the package, and performing visual checks in the browser. The results for the version you install are summarised in the release notes.

---

## Path 2: Repackage Under Your Own Namespace

Choose this path when you want to own the source outright rather than depend on the managed package. You take a copy of the public KernDX code, rename it to your own namespace, and ship it as your own managed package. The trade-off is more setup work in exchange for full control: you can read, change, and maintain every line, and your org no longer depends on the original package.

### What You'll Do

1. Set up your Dev Hub and register a namespace
2. Create a new Salesforce DX project
3. Import and rebrand the KernDX code with your namespace
4. Package and release your own managed package

**Start by cloning the public source repo:**

```bash
git clone https://github.com/JVB-Consulting/kerndx my-company-framework
```

The clone is a complete Salesforce DX project, ready to rename. The working tree contains `force-app/`, the rename script `bin/swap-namespace.js`, the `sfdx-project.template.json` template, and the rest of the project files. The instructions below assume you are starting from this state.

---

## Prerequisites

Before starting, ensure you have:

- **Salesforce CLI** (latest version), installed from Salesforce
- **Git** for version control
- **Visual Studio Code** with Salesforce Extension Pack (recommended)
- **Two Salesforce Orgs:**
    - **Dev Hub Org**: Production org or Partner Business Org (to manage packages)
    - **Namespace Org**: Developer Edition org (to register your namespace)
- A working tree of the KernDX project: a clone of `JVB-Consulting/kerndx`

---

## Step 1: Enable Your Dev Hub

Before you can build a package, Salesforce needs one org designated to manage it. That org is your Dev Hub: the central place that controls all your packages, scratch orgs, and namespaces.

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

A namespace is the unique prefix (for example `acmecorp`) that becomes part of every API name in your package. It guarantees your code never collides with anyone else's in an org.

> **CRITICAL: this is a UI-only operation.** Linking your namespace to the Dev Hub **MUST** be done through the Salesforce web UI. The Salesforce CLI does **NOT** support namespace linking from the command line, so you will complete Step 2.2 by hand in your browser.

### Register Namespace in Namespace Org

**Use a Developer Edition Org as your Namespace Org.**

1. Log into your Developer Edition org (or create one at developer.salesforce.com/signup)
2. Navigate to **Setup > Packages > Package Manager**
3. Click **Edit** next to "Namespace Settings"
4. Enter your desired **Namespace Prefix** (e.g., `acmecorp`)
5. Click **Check Availability** to verify it's unique
6. Click **Save** to register the namespace

> **Important:** Once registered, a namespace cannot be changed or reused. Choose carefully!

### Link Namespace to Dev Hub (UI Only)

**IMPORTANT:** You **MUST** link the namespace to your Dev Hub using the Salesforce UI. Linking from the command line is **NOT available** in the Salesforce CLI; this is a UI-only operation.

**Steps to Link Namespace:**

1. Log into your **Dev Hub org** (from Step 1) in a web browser
2. Click the **App Launcher** (waffle icon) and search for **Namespace Registries**
3. Click **Link Namespace**
4. You'll be redirected to log into your **Namespace Org** (Developer Edition org from Step 2.1)
5. Log in with your Namespace Org credentials and **authorize the connection**
6. You'll be redirected back to your Dev Hub with the namespace now linked

**Checkpoint:** In your Dev Hub, navigate to **Namespace Registries** and verify your namespace appears in the list
with status "Linked".

> **Why UI Only?** Salesforce requires an OAuth sign-in between the Dev Hub and the Namespace Org. That security handshake can only be completed in the browser, not through CLI commands.

---

## Step 3: Rebrand the Project Tree

Renaming every reference from `kern` to your own namespace by hand would be tedious and error-prone. The project ships with a one-shot rename script that does it all for you. There is no manual `find`/`sed` recipe to follow: the script is the one tool that performs the swap.

### Confirm your starting tree

From the directory where you cloned the public repo, confirm the project structure is in place:

```bash
ls bin/swap-namespace.js sfdx-project.template.json force-app/
```

If those three paths exist, you have the correct starting state and can skip to Step 3.2. The tree is already a full Salesforce DX project: `sfdx-project.template.json`, `force-app/`, `scripts/`, `bin/`, and `package.json` are all in place. You do not need an `sf project generate` step.

> **Note for the top-level `README.md`:** the rename script does not rewrite the public repo's top-level `README.md`. Its Quick Start and Path-1/2/3 wording describes the original KernDX project, not your renamed copy. Treat that file as background reading and follow Steps 3 to 5 of this guide for the rename-then-package recipe. See `bin/README.md`, section "Post-Swap Action Required", for details.

### Run the swap script

```bash
node bin/swap-namespace.js <your-namespace>
node bin/swap-namespace.js <your-namespace> --dry-run         # preview only, no writes
node bin/swap-namespace.js <your-namespace> --keep-readme     # opt out of README stub
```

Replace `<your-namespace>` with the namespace you registered in Step 2 (for example `acmecorp`).

The script handles every kind of reference. It rewrites every `kern.ClassName` and `kern__Field__c`, the `<kern>` namespace declaration, and the filesystem paths (`kernHome/`, `KernHome.tab-meta.xml`, `KernLogo.asset`). It also produces a finished `sfdx-project.json` from the template in this repo. As proof that the swap completed, it writes `.namespace-origin.json` at the root of your working copy, and it refuses to run a second time on the same tree.

After a successful swap, the script replaces the top-level `README.md` with a short stub that credits KernDX, names your namespace, and points at your renamed `docs/` content. The original KernDX README isn't appropriate for your renamed copy, which is why it's swapped out. If you wrote your own README before the swap and want to keep it, pass `--keep-readme`.

See `bin/README.md` in this repo for the full script details, the `--dry-run` audit format, the `--keep-readme` opt-out, and one step the script can't do for you: replacing the logo image. The file `<TargetPascal>Logo.asset` is renamed correctly, but its image content is still the KernDX logo. Replace it with your own before you ship to your users.

### Verify the swap

```bash
cat .namespace-origin.json                                   # confirms swap target + timestamp
grep -r "kern\." force-app --include="*.cls" --include="*.xml" | head    # should return no matches
grep -r "kern__" force-app --include="*.xml" | head                       # should return no matches
```

**Checkpoint:**

- The swap is complete when `.namespace-origin.json` shows your target namespace and an ISO timestamp.
- The source is clean when `grep` returns no results, meaning no `kern.*` references are left behind.

If `grep` does return results, the swap is incomplete. Inspect the matches and report them: the script aims to handle every case, so any leftover reference points to a gap in the script that is worth fixing.

---

## Step 4: Configure Your Package

Good news: there is nothing to do here by hand. The rename script in Step 3.2 already wrote your `sfdx-project.json` from the template, with your namespace, `sfdcLoginUrl`, and `sourceApiVersion: 67.0` all in place. **You do not need to edit `sfdx-project.json` manually at this point.**

You can skip straight to Step 5, where the remaining fields fill themselves in:

- `sf package create` (Step 5.1) adds a `packageAliases` entry and completes `packageDirectories[0]` with the new `package` field. The template deliberately ships without a `package` field so this update lands cleanly instead of duplicating an entry.
- Creating the first package version (Step 5.2) then writes that version's `versionName` and `versionNumber` into `packageDirectories[0]`.

---

## Step 5: Create Your Managed Package

### Create the Package

```bash
sf package create \
  --name "YourCompanyFramework" \
  --package-type "Managed" \
  --path "force-app" \
  --target-dev-hub MyCompanyDevHub
```

**Checkpoint:** Run `sf package list --target-dev-hub MyCompanyDevHub` to see your package listed.

### Create Your First Package Version

**First, commit your rebrand to a local branch.** The build script needs a clean `force-app/` tree to work from. During the build it temporarily adds namespace prefixes to your files, then undoes those changes with `git checkout`, so it relies on git having a clean committed state to revert to. From your project root:

```bash
git init                                          # if you haven't already
git add -A && git commit -m "rebrand to YourNamespace"
```

Then build:

```bash
node scripts/build-package.js --package "YourCompanyFramework" --no-resync
```

This takes 10-30 minutes. Save the **Package Version ID** (it starts with `04t`) and the **Installation URL**.

**Why `build-package.js` instead of `sf package version create` directly?** Because one type of reference won't get your namespace prefix otherwise, and the package will break at runtime.

Here's the problem. Some metadata stores class and field names as plain text strings rather than as real references: Custom Metadata records (for example `ApiSetting` and `TriggerAction`), Flow metadata, FlexiPages, and LWC `apex://` references. During a managed-package build, Salesforce applies your namespace prefix to genuine references but *not* to these plain-string values.

`scripts/build-package.js` solves this. Its Step 1 calls `scripts/prepare-package-build.js`, which writes the prefix into those string fields for the duration of the build (for example, `ClassName__c = "API_PostExample"` becomes `ClassName__c = "yournamespace.API_PostExample"`), then restores your working tree to its committed state afterwards. Run `sf package version create` directly and you skip this step, so the finished package fails at runtime with errors like `API setting record not found for service "yournamespace.<class>"`.

Two flags to know. Use `--no-resync` because the resync step targets the KernDX maintainer's dev org, which you don't have. Use `--skip-validation` only for quick smoke-test builds; a real release candidate should always run with validation on.

### Test Your Beta Version

1. Open the **Package Installation URL** from the previous step
2. Install in a scratch org or sandbox
3. Test all functionality thoroughly
4. Verify your namespace prefix appears on all components

### Promote to Released

```bash
sf package version promote \
  --package "04tXX0000004XXXXX" \
  --target-dev-hub MyCompanyDevHub
```

---

## Complete Example: Acme Corp

To see all five steps in one place, here is the whole sequence for a fictional company, **Acme Corp**, using the namespace `acmecorp`:

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

These are the errors people most often hit when repackaging under their own namespace, along with the cause and the fix for each. Find the message that matches yours.

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

A few metadata types must be unique across every package in an org, not just within yours. If your renamed copy and another package both use the same name, the install fails. When that happens, change the value shown here to something unique to you:

| Metadata Type              | Uniqueness Field             | Resolution        |
|----------------------------|------------------------------|-------------------|
| **CustomNotificationType** | `customNotifTypeName`        | Rename XML label  |
| **DuplicateRule**          | `masterLabel`                | Rename label      |
| **MatchingRule**           | `masterLabel`                | Rename label      |
| **ExternalDataSource**     | `endpoint` + `principalType` | Change endpoint   |
| **RemoteSiteSetting**      | `url`                        | Use different URL |
| **ContentSecurityPolicy**  | `masterLabel`                | Rename label      |

---

## Next Steps

Once your package is released:

1. **Install in Orgs:** Share the installation URL with your team
2. **Version Updates:** Update `versionNumber` in `sfdx-project.json`, commit the change, and run `node scripts/build-package.js --package "YourCompanyFramework" --no-resync`
3. **Documentation:** Already updated with your namespace from Step 3.2
4. **Customise:** Add your own classes extending KernDX capabilities using `SEL_Base`, `TRG_Base`, `DML_Builder`,
   and `QRY_Builder`
5. **Support:** Set up processes for bug fixes and enhancement requests
6. **Governance:** Establish release management and versioning strategies

For more detail on how the framework is built, see the developer guides in the `docs/` folder:

- Triggers Guide, Selectors Guide, Web Services Guide, DTOs Guide, and the rest.

---

## Path 3: CI Tooling Only

Maybe you want KernDX's automated code checks in your continuous-integration (CI) pipeline, the checks that run on every pull request, but not the framework itself. This path gives you exactly that. You get the KernDX CI tooling (an ESLint plugin, PMD rulesets, and GitHub Actions workflow templates) and nothing more.

It ships as a standalone zip that lives entirely in your repo's `.kerndx-pipeline/` directory. It adds no Apex, no Lightning components, and no managed-package dependency to your org, so it stays out of your runtime entirely.

### What's Inside

- `@jvb-consulting/kerndx-pipeline` CLI: 8 commands (`init`, `scan`, `naming`, `preflight`, `doctor`, `upgrade`, `classify-ref`, `slack-payload`).
- ESLint plugin (`eslint-plugin-kerndx`): 6 behavioural rules, with no formatting opinions.
- Two PMD rulesets: naming and sharing-modifier enforcement.
- Eleven Eta-rendered GitHub Actions workflow templates: scan, preflight, release-notes, and Slack-bridge wiring.
- `INSTALL-PIPELINE.md`: the full setup guide, bundled inside the zip.

### Install

Download `KernDX-<version>-pipeline.zip` from the [Releases page](https://github.com/JVB-Consulting/kerndx/releases), then unpack and initialise:

```bash
unzip /path/to/KernDX-<version>-pipeline.zip -d .kerndx-pipeline
(cd .kerndx-pipeline/pipeline && npm ci --omit=dev)
./.kerndx-pipeline/bin/kerndx init
```

`kerndx init` walks you through setting up `.kerndx/config.yml` (your prefix and domain conventions, Slack webhook, and CI-tool adapter) and wires the workflow templates into `.github/workflows/`. It is safe to re-run after upgrades.

If you'd like to see the 9 rendered workflow examples before you install, they're browsable in the public repo at [`examples/workflows/`](https://github.com/JVB-Consulting/kerndx/tree/main/examples/workflows).

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

If you use an AI coding assistant, it works much better when it knows the framework's conventions. When you set up a project that uses KernDX as a managed package, create an `AGENTS.md` file in the project root (or your assistant's equivalent, such as `CLAUDE.md` for Claude Code or `.cursorrules` for Cursor) using the patterns below. Replace every `{{PLACEHOLDER}}` with your own values.

### Namespace Usage

In your org, every KernDX framework class is called with the namespace prefix in front of it. These examples show the common patterns:

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

Here is what each placeholder in the examples above stands for, and the kind of value to put in its place:

| Placeholder         | Description                     | Example                   |
|---------------------|---------------------------------|---------------------------|
| `{{NAMESPACE}}`     | KernDX package namespace        | `ClientLib`, `ACME`       |
| `{{ORG_ALIAS}}`     | Salesforce org alias            | `DevOrg`, `ClientDevOrg`  |
| `{{PREFIX}}`        | Project class prefix (optional) | `PRJ_`, `ACME_`, or empty |
| `{{LWC_NAMESPACE}}` | LWC import namespace            | `acme`, `clientlib`       |
| `{{AUTHOR_EMAIL}}`  | Developer email                 | `developer@client.com`    |
