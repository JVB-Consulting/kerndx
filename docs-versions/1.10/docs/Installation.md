---
navOrder: 1
---

# Installation

> **What this is:** the practical setup guide for getting KernDX into your org. **Why it exists:** there are three ways to adopt the framework, and which one fits depends on how much you want to own the source. **Who should read it:** the developer or admin doing the install, plus the architect deciding which path to take. **Three paths, in order of effort:** Path 1 installs the ready-made managed package in a few clicks (the simplest start). Path 2 clones the public source and repackages it under your own namespace, so you own and can modify the code. Path 3 adds only the continuous-integration tooling (scanner and workflow templates), with no Apex or package in your org. Pick the path that matches your goal, then follow its section below.

## Table of Contents

<details>
<summary>Expand</summary>

1. [How to read the code samples](#how-to-read-the-code-samples)
2. [Path 1: Install the KernDX Managed Package](#path-1-install-the-kerndx-managed-package)
   - [Install the package](#install-the-package)
   - [Post-Install Configuration](#post-install-configuration)
   - [Integration Gotchas](#integration-gotchas)
   - [CI Integration User: Manage Flow Permission](#ci-integration-user-manage-flow-permission)
   - [Upgrading the package](#upgrading-the-package)
   - [Release Testing](#release-testing)
   - [Project template for AI assistants](#project-template-for-ai-assistants)
     - [Namespace usage](#namespace-usage)
     - [Placeholders reference](#placeholders-reference)
3. [Path 2: Repackage Under Your Own Namespace](#path-2-repackage-under-your-own-namespace)
   - [What You'll Do](#what-youll-do)
   - [Before you start](#before-you-start)
   - [Step 1: Enable Your Dev Hub](#step-1-enable-your-dev-hub)
   - [Step 2: Register and Link Your Namespace](#step-2-register-and-link-your-namespace)
   - [Step 3: Rebrand the Project Tree](#step-3-rebrand-the-project-tree)
   - [Step 4: Configure Your Package](#step-4-configure-your-package)
   - [Step 5: Create Your Managed Package](#step-5-create-your-managed-package)
   - [Complete Example: Acme Corp](#complete-example-acme-corp)
   - [Troubleshooting](#troubleshooting)
     - ["Namespace not found"](#namespace-not-found)
     - ["Package name already exists"](#package-name-already-exists)
     - ["Code coverage below 75%"](#code-coverage-below-75)
     - [Package Build Fails with "Object does not exist"](#package-build-fails-with-object-does-not-exist)
     - ["duplicate value found: CustomNotifTypeName"](#duplicate-value-found-customnotiftypename)
     - [Lightning Page Components Missing](#lightning-page-components-missing)
     - [Metadata Uniqueness Reference](#metadata-uniqueness-reference)
     - [The package install reports an error](#the-package-install-reports-an-error)
     - [The permission set cannot be assigned](#the-permission-set-cannot-be-assigned)
     - [mkdir says the folder already exists](#mkdir-says-the-folder-already-exists)
     - [npm ci complains about the Node version](#npm-ci-complains-about-the-node-version)
     - [kerndx init or kerndx upgrade stops with a message](#kerndx-init-or-kerndx-upgrade-stops-with-a-message)
     - [aer runs fewer tests than you asked for, or a test fails only in aer](#aer-runs-fewer-tests-than-you-asked-for-or-a-test-fails-only-in-aer)
   - [Run the tests on your computer with aer (optional)](#run-the-tests-on-your-computer-with-aer-optional)
   - [Next Steps](#next-steps)
4. [Path 3: CI Tooling Only](#path-3-ci-tooling-only)
   - [What's Inside](#whats-inside)
   - [Install](#install)
   - [Upgrading the CI tooling](#upgrading-the-ci-tooling)
   - [Full Reference](#full-reference)
5. [References](#references)

</details>

---

## How to read the code samples

Two things mark the managed package's namespace in a code sample: `kern.` in front of a class, and `kern__` in front of an object, field, or custom metadata type. Samples across this documentation appear in both forms. Some spell the prefixes out, others leave them off to keep the example short. A sample's form is not a statement about your org, so read it for its shape and apply the rule for the path you took.

**Path 1, the managed package.** The framework lives in the `kern` namespace, so your code has to name it. Every framework class reference needs `kern.` in front of it, for example `kern.LOG_Builder`, and every framework object, field, and custom metadata type needs `kern__`, for example `kern__LogEntry__c` and `kern__TriggerSetting__mdt`. Add them wherever a sample leaves them out. Your own classes, objects, and fields keep the names you gave them, with no prefix. For custom permissions and permission sets, use the API name exactly as it appears in Setup.

**Path 2, repackaged under your own namespace.** Your prefix takes kern's place, so `kern__LogEntry__c` reads `acme__LogEntry__c` in a package built under the namespace `acme`. Your own code calls the framework classes with no prefix at all, because it now lives in the same namespace as the framework.

**Deployed straight from the source, with no namespace of its own (an unmanaged deploy).** Drop the prefixes where a sample shows them: `kern.LOG_Builder` is simply `LOG_Builder`, and `kern__LogEntry__c` is `LogEntry__c`.

The release notes show the managed (`kern.`) form. The generated reference pages show the bare form, without the prefixes.

---

## Path 1: Install the KernDX Managed Package

This is the fastest way to start. You install the ready-built package straight into your org and use it as-is, with the framework's classes living under the `kern` namespace. Choose this path when you want the framework running quickly and are happy to keep the code as a managed dependency rather than owning a copy of the source.

### Install the package

**Current SubscriberPackageVersionId (1.10.0-4):** `04tfj000000fkuvAAA`

**One-click install** (in the browser, no CLI needed; Salesforce prompts you to log in on the page):

<a href="https://login.salesforce.com/packaging/installPackage.apexp?p0=04tfj000000fkuvAAA"><img src="https://img.shields.io/badge/Install-Production-blue.svg?style=for-the-badge" alt="Install in Production" width="187" height="28"></a>
<a href="https://test.salesforce.com/packaging/installPackage.apexp?p0=04tfj000000fkuvAAA"><img src="https://img.shields.io/badge/Install-Sandbox-orange.svg?style=for-the-badge" alt="Install in Sandbox" width="163" height="28"></a>

The same buttons appear on every entry of the [Releases page](https://github.com/JVB-Consulting/kerndx/releases), so you can pick the release that matches the version you want to install.

When the install page asks who to install for, choose **Install for Admins Only**. Installing for All Users writes the chain-abort permission into every profile in your org, silently enabling the Chain Monitor's abort action for everyone; the Health Check will flag it if that happens (see the Chain abort action entry under [Post-Install Configuration](#post-install-configuration)). The CLI command below installs for admins only, which is the default.

---

**CLI install.** One command installs into production or a sandbox alike.

**In the terminal**, replacing `YourOrgAlias` with the alias of the org you are installing into, your production org or
your sandbox:

```shell
sf package install --package 04tfj000000fkuvAAA -o YourOrgAlias --wait 15 --no-prompt
```

You should see `Successfully installed package` when the install finishes.

**Machine-readable source.** If you are scripting installs, prefer `RELEASE-PROVENANCE.json` at the repo root over scraping this guide. The file ships with every release and
carries the `subscriber_package_version_id` field as authoritative truth, so your tooling can fetch the file and read that field directly.

For a specific older version, see the [Releases page](https://github.com/JVB-Consulting/kerndx/releases): each release's description carries its 04t id. If you need help, email `jason@jvb-consulting.io`.

Something went wrong? See [Troubleshooting](#troubleshooting).

### Post-Install Configuration

Installing the package is only step one. A few org-level settings still need attention before everything works, and the framework guides you through them so you don't have to hunt them down yourself.

The tool that does this is the **Health Check** built into the **Kern** app. If you installed the package as a System Administrator, the app is already available to you: open the **App Launcher** (the grid icon, top-left), search for **Kern**, and select it. Its **Home** tab runs the Health Check automatically.

The Health Check verifies the configuration listed below and sorts anything outstanding to the top, in three groups: **Action required** for hard prerequisites, **Review recommended** for optional settings, and **Passing** for everything already set. Where it can, it fixes things in place for you. That includes a **Class Type Resolver** generator (it writes a resolver class and its test for you, explained below) and a one-click **Data Retention** scheduler. The Home tab also gives you quick-launch **Administration Tools**: the API Test Harness, the Streaming Event Monitor, the Chain Monitor, the Data Masking Advisor, and the Log Console.

What the Health Check looks for, and how to satisfy it:

1. **Platform Cache.** KernDX ships its own Platform Cache partition (called **LibraryCache**, under the `kern` namespace), so you don't create one. Salesforce does not carry a managed package's cache capacity over to your org, so you allocate the space yourself: in **Setup > Platform Cache**, edit the **LibraryCache** partition.

   Give it **Organisation** cache. Kern uses this to remember state between requests. Without it, automatic retries on failing integrations, protection from repeated errors, and shared configuration lookups all stop working.

   Add **Session** cache where you can. Kern keeps per-user data such as encryption keys there. Without it, that data falls back to Org Cache, which uses more of your org-cache allocation and slows down user-specific operations.
2. **Class Type Resolver (optional).** You only need this if you keep your own trigger handlers, validation rules, scheduled jobs, or web-service classes `public` rather than `global`. In that case Kern needs a small helper class (a Type Resolver) to find your classes across its namespace; in plain terms, you tell the framework where to look for your code. Click **Setup** on this row and the Health Check generates a ready-to-deploy resolver and test class for you. See also [Integration Gotchas](#integration-gotchas) below.
3. **Chain abort action (optional).** The Chain Monitor can abort a single runaway async chain, and it ships switched off so no one can stop a chain by accident. To switch it on, assign the **Kern Async Chain Abort** permission set to the operations users who should be allowed to abort a chain, and the action appears for them. A separate org-wide off-switch, the **Async Chain Abort Enabled** feature-flag record, ships active and lets you hide the action for everyone in one step without touching anyone's permissions. The Health Check's **Chain Abort Capability** row reports where you stand; if the package was installed for All Users, every profile already holds the abort permission, and the row warns until you remove those profile grants and rely on the permission set instead. See [Stopping a chain from the Chain Monitor](Async%20Processing%20-%20Guide.md#stopping-a-chain-from-the-chain-monitor) in the Async Processing Guide.
4. **Chain recovery actions (optional).** The Chain Monitor can also re-drive a failed chain from its failed step, restart a declared chain from the start, and clear stalled chains on demand. These ship switched off the same way as abort: assign the **Kern Async Chain Redrive** permission set to the operations users who recover chains, and the three actions appear for them. Pair it with the **Kern Async Chain Monitor Read Only** set, which grants the chain data, tabs, and monitor access the actions work on. The org-wide off-switch is the **Async Chain Redrive Enabled** feature-flag record. The first two actions also need the chain itself to opt in (a retry needs the failed step to declare itself safe to re-run; a restart needs the chain's author to have allowed restarts), so they stay unavailable on chains that never declared them; see [Re-driving a failed chain](Async%20Processing%20-%20Guide.md#re-driving-a-failed-chain) in the Async Processing Guide.
5. **Chain kill-switch control (optional).** Operations leads can suspend and resume all chain processing org-wide from the Chain Monitor, without a deployment. This grant is deliberately separate from the recovery actions because it stops everything at once: assign the **Kern Async Chain Kill Switch** permission set only to the users trusted with an org-wide stop. Its off-switch is the **Async Chain Kill Switch Enabled** feature-flag record. If the package was installed for All Users, every profile already holds the recovery and kill-switch permissions too; remove those profile grants to bring the actions back under the permission sets' control. See [The operations control](Async%20Processing%20-%20Guide.md#the-operations-control) in the Async Processing Guide.
6. **Issue resolvers (optional).** Assign the **Kern API Issue Resolver** permission set to the support users who run failed API calls again from an API issue. It grants the **Retry API Issue** permission, access to the Retry action, read access to API issues, read access to every API call (View All Records, so the holder sees calls other users made, which are otherwise private to their owner), the API Issues tab and the Kern app. Administrators keep Retry through the **Kern Administrator** set. A fresh install for admins only also writes the permission into the System Administrator profile, and a fresh install for all users writes it into every profile; remove those profile grants to bring Retry under the permission sets' control. An administrator who works through a profile alone and is refused Retry after an upgrade needs the Kern API Issue Resolver or the Kern Administrator set. See [Failures and retries](Web%20Services%20-%20Guide.md#failures-and-retries) in the Web Services Guide.
7. **Stalled-chain recovery (schedule the watchdog).** A background job can die silently and leave an async chain stuck part-way. A scheduled watchdog spots these and marks them `Stalled`. When it can prove a chain's job died, it runs the stalled step again only if that is safe (the step never started, or it declares itself safe to run twice) and otherwise ends the chain `Failed`; the rest it flags for you. A managed package cannot ship a scheduled job, so stalled-chain recovery stays dormant until you schedule it. The Health Check's **Chain Watchdog** row spots the gap and schedules the job for you in one click (hourly, with a 30-minute stale threshold and up to 50 chains per sweep). To set it up yourself instead, create a `ScheduledJob__c` record whose `ClassName__c` is `SCHED_ChainWatchdog`, running hourly (cron `0 0 * * * ?`), through the framework's Scheduled Jobs UI (no code needed). Two optional attributes tune it: `StaleThresholdMinutes` (idle minutes before a chain counts as stalled, default 30) and `BatchSize` (chains inspected per sweep, default 50). To schedule it from Apex instead: `System.schedule('Chain Watchdog', '0 0 * * * ?', new SCHED_ChainWatchdog());`. See [Declarative Scheduling with `ScheduledJob__c`](Async%20Processing%20-%20Guide.md#declarative-scheduling-with-scheduledjob__c) in the Async Processing Guide.

To grant non-admin users access to the app, assign the **Kern Administrator** permission set (see [CI Integration User: Manage Flow Permission](#ci-integration-user-manage-flow-permission) below). It grants every Kern tab and the Apex classes behind the Health Check and the Administration Tools, so a user who is not a System Administrator can open them. A user of your own pages and flows built with the package's components, modules and Flow actions (feature flag reads, logging, search lookups, field-set forms, picklist values, permission checks) needs only the much smaller **Kern Component Access** set; see [Use in LWC](Fast%20Start%20-%20Feature%20Flags.md#use-in-lwc) in the Feature Flags Fast Start. For a full walkthrough of every check and what each result means,
see [Health Check](Utilities%20-%20Guide.md#health-check) in the Utilities Guide.

### Integration Gotchas

Four details that catch most people on their first integration. Knowing them up front saves a confusing debugging session later.

1. **Custom type resolvers must be `global`.** The framework creates your resolver class from its own namespace, and that only works if the class is declared `global with sharing`. (The `resolveType` method inside it stays `public`: it overrides a `global abstract` method without itself needing to be widened to `global`.) You don't have to write the body by hand: the Kern app's Health Check generates a complete, namespace-aware resolver and a matching test for you (click **Setup** on the Class Type Resolver row; see [Health Check](Utilities%20-%20Guide.md#health-check)). **In your editor**, the class has this shape:
   ```apex
   global with sharing class MyCustomResolver extends kern.UTIL_TypeResolver.BaseClassResolver
   {
       public override Type resolveType(String className) { /* ... */ }
   }
   ```
2. **Your request DTOs need `@JsonAccess` with both flags.** A DTO is a small class that holds exactly the fields you want to move in or out and converts itself to and from JSON. Because the framework runs the conversion from its own namespace, even an inbound request DTO needs serialization access granted with both flags. **In your editor**, declare it like this:
   ```apex
   @JsonAccess(serializable='always' deserializable='always')
   public class DTO_Request extends kern.DTO_JsonBase { }
   ```
3. **Validation bypass takes a `String`, not an `SObjectType`.** When you turn off a validation rule for an object, pass the object name as text: `kern.UTIL_ValidationRule.bypassObject('Account')`. There is no `bypass(SObjectType)` version of the method. One more thing to know: validation bypasses are tracked separately from trigger (`TRG_Base`) bypasses, so calling `TRG_Base.clearAllActionBypasses()` does not clear them.
4. **The current package does not include the `RequiredPermission__c` and `BypassPermission__c` fields** on `TriggerAction__mdt`, `TriggerSetting__mdt`, `ValidationRule__mdt`, or `ValidationRuleGroup__mdt`. If your own project ships configuration (CMDT) files that reference those fields, perhaps from an older install or in anticipation of a future release, remove the references before you deploy. Otherwise the deploy fails with a "No such column" error.

### CI Integration User: Manage Flow Permission

If you run KernDX checks in a continuous-integration (CI) pipeline, the user that pipeline logs in as needs one specific permission, or a key safety check passes when it shouldn't.

Here's why. The KernDX flow-reference scanner (`npm run scan:flow-references`) confirms that the flows your code references actually exist. To do that it reads `FlowDefinitionView` and `Flow.Metadata`, which require the `Manage Flow` permission. CI integration users usually run on a custom or `Standard User` profile, which lacks that permission. Without it the scanner finds nothing, returns zero rows, and reports success even when a referenced flow is missing. The check looks green but isn't actually checking anything.

The fix is a one-time setup step. The `Manage Flow` permission is already in the bundled `Kern Administrator` permission set, so assign that set to the integration user.

**In the terminal**, replacing `YourIntegrationUser` with the integration user's alias or username:

```shell
sf org assign permset -n kern__Administrator -o YourIntegrationUser
```

You should see a table titled `Permsets Assigned`, with the integration user's name under `Username`.

If you'd rather give the integration user the bare minimum and not the full administrator surface, create your own permission set in the org that grants only the `Manage Flow` user permission, and assign that instead.

One exception: CI runners that use a System Administrator profile (the default when each build spins up its own scratch org) already have `Manage Flow` through `Modify All Data`, so they need neither assignment.

Something went wrong? See [Troubleshooting](#troubleshooting).

### Upgrading the package

How you move to a newer version depends on the org type.

In a scratch org, a beta package version can't be upgraded over the top of an older one, so you start fresh:

1. **In the terminal**, delete the existing scratch org:

   ```shell
   sf org delete scratch -o YourOrgAlias --no-prompt
   ```

   You should see a line that starts `Successfully` and names the scratch org.

2. Create a fresh scratch org and install the new package version
3. Redeploy your own code

In sandbox and production orgs you upgrade in place: install the new package version when you choose to. KernDX never pushes an upgrade to your org.

Something went wrong? See [Troubleshooting](#troubleshooting).

### Release Testing

Every release is tested before it reaches you, so you can adopt a new version with confidence. Each release candidate runs through a four-step internal cycle: setting up the test environment, running automated Apex scripts, running the test classes against an installed copy of the package, and performing visual checks in the browser. The results for the version you install are summarised in the release notes.

### Project template for AI assistants

If you use an AI coding assistant, it works much better when it knows the framework's conventions. When you set up a project that uses KernDX as a managed package, create an `AGENTS.md` file in the project root (or your assistant's equivalent, such as `CLAUDE.md` for Claude Code or `.cursorrules` for Cursor) using the patterns below. Replace every `{{PLACEHOLDER}}` with your own values.

#### Namespace usage

In your org, every KernDX framework class is called with the namespace prefix in front of it. **In your editor**, add these examples of the common patterns to the file:

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
@JsonAccess(serializable='always' deserializable='always')
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

#### Placeholders reference

Here is what each placeholder in the examples above stands for, and the kind of value to put in its place:

| Placeholder         | Description                     | Example                   |
|---------------------|---------------------------------|---------------------------|
| `{{NAMESPACE}}`     | KernDX package namespace        | `ClientLib`, `ACME`       |
| `{{ORG_ALIAS}}`     | Salesforce org alias            | `DevOrg`, `ClientDevOrg`  |
| `{{PREFIX}}`        | Project class prefix (optional) | `PRJ_`, `ACME_`, or empty |
| `{{LWC_NAMESPACE}}` | LWC import namespace            | `acme`, `clientlib`       |
| `{{AUTHOR_EMAIL}}`  | Developer email                 | `developer@client.com`    |

---

## Path 2: Repackage Under Your Own Namespace

Choose this path when you want to own the source outright rather than depend on the managed package. You take a copy of the public KernDX code, rename it to your own namespace, and ship it as your own managed package. The trade-off is more setup work in exchange for full control: you can read, change, and maintain every line, and your org no longer depends on the original package.

### What You'll Do

1. Enable your Dev Hub (Step 1)
2. Register your namespace and link it to your Dev Hub (Step 2)
3. Rebrand the KernDX code with your namespace (Step 3)
4. Check the package configuration the rebrand wrote for you (Step 4)
5. Package and release your own managed package (Step 5)

After the rebrand and before you build the package, you can also run the Apex tests on your own computer, with no org: see [Run the tests on your computer with aer (optional)](#run-the-tests-on-your-computer-with-aer-optional).

### Before you start

Make sure you have:

- **Salesforce CLI** (latest version), installed from Salesforce
- **Git** for version control
- **Visual Studio Code** with Salesforce Extension Pack (recommended)
- **Two Salesforce Orgs:**
    - **Dev Hub Org**: Production org or Partner Business Org (to manage packages)
    - **Namespace Org**: Developer Edition org (to register your namespace)
- A working tree of the KernDX project: a clone of `JVB-Consulting/kerndx`

Set up your terminal and the CLI with [Set Up Your Computer](Set%20Up%20Your%20Computer.md) first; on Windows that terminal is Command Prompt.

**1. In the terminal**, start by cloning the public source repo:

```shell
git clone https://github.com/JVB-Consulting/kerndx my-company-framework
```

You should see a new folder named `my-company-framework`.

**2. In the terminal**, move into it:

```shell
cd my-company-framework
```

You should see nothing printed; every command after this one runs inside `my-company-framework`.

The clone is a complete Salesforce DX project, ready to rename. The working tree contains `force-app/`, the rename script `bin/swap-namespace.js`, the `sfdx-project.template.json` template, and the rest of the project files. The instructions below assume you are starting from this state.

Something went wrong? See [Troubleshooting](#troubleshooting).

---

### Step 1: Enable Your Dev Hub

Before you can build a package, Salesforce needs one org designated to manage it. That org is your Dev Hub: the central place that controls all your packages, scratch orgs, and namespaces.

**Use a Production Org or Partner Business Org as your Dev Hub.**

**1. In Salesforce**:

1. Log into your org
2. Navigate to **Setup > Dev Hub**
3. Enable **Dev Hub** and **Unlocked Packages and Second-Generation Managed Packages**

**2. In the terminal**, authorise the org and set it as your default Dev Hub:

```shell
sf org login web --alias MyCompanyDevHub --set-default-dev-hub
```

You should see your browser open on the Salesforce login page. Once you log in and allow access, the terminal prints `Successfully authorized` followed by your username and org ID.

**3. In the terminal**, check that your Dev Hub is your default Dev Hub:

```shell
sf org list
```

You should see your Dev Hub in the list, marked as the default; the legend under the table explains the mark.

Something went wrong? See [Troubleshooting](#troubleshooting).

---

### Step 2: Register and Link Your Namespace

A namespace is the unique prefix (for example `acmecorp`) that becomes part of every API name in your package. It guarantees your code never collides with anyone else's in an org.

> **CRITICAL: this is a UI-only operation.** Linking your namespace to the Dev Hub **MUST** be done through the Salesforce web UI. The Salesforce CLI does **NOT** support namespace linking from the command line, so you will complete Step 2.2 by hand in your browser.

#### Step 2.1: Register the namespace

**Use a Developer Edition Org as your Namespace Org.**

**In Salesforce**:

1. Log into your Developer Edition org (or create one at developer.salesforce.com/signup)
2. Navigate to **Setup > Packages > Package Manager**
3. Click **Edit** next to "Namespace Settings"
4. Enter your desired **Namespace Prefix** (e.g., `acmecorp`)
5. Click **Check Availability** to verify it's unique
6. Click **Save** to register the namespace

> **Important:** Once registered, a namespace cannot be changed or reused. Choose carefully!

#### Step 2.2: Link the namespace to your Dev Hub

**IMPORTANT:** You **MUST** link the namespace to your Dev Hub using the Salesforce UI. Linking from the command line is **NOT available** in the Salesforce CLI; this is a UI-only operation.

**In Salesforce**:

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

### Step 3: Rebrand the Project Tree

Renaming every reference from `kern` to your own namespace by hand would be tedious and error-prone. The project ships with a one-shot rename script that does it all for you. There is no manual `find`/`sed` recipe to follow: the script is the one tool that performs the swap.

#### Step 3.1: Confirm your starting tree

From the top folder of your clone, preview the swap. Replace `YourNamespace` with the namespace you registered in Step 2 (for example `acmecorp`). The preview writes a
swapped copy of your files to a `.swap-staging` folder for you to look through and changes nothing else; the swap in the next step clears that folder.

**In the terminal**:

```shell
node bin/swap-namespace.js YourNamespace --dry-run
```

You should see `Swap to 'YourNamespace' complete.`, with your namespace in place of `YourNamespace`. For a preview, that line means the tree passed the check; none of your files has changed yet. If you are in another folder, Node cannot find the script at all and stops with an error instead: move to the top folder of your clone and run the line again.

If the preview runs, you have the correct starting state and can skip to Step 3.2. The tree is already a full Salesforce DX project: `sfdx-project.template.json`, `force-app/`, `scripts/`, `bin/`, and `package.json` are all in place. You do not need an `sf project generate` step.

> **Note for the top-level `README.md`:** the rename script replaces the public repo's top-level `README.md` with a short stub unless you pass `--keep-readme`. If you keep the original, its Quick Start and Path-1/2/3 wording describes the original KernDX project, not your renamed copy: treat that file as background reading and follow Steps 3 to 5 of this guide for the rename-then-package recipe. See `bin/README.md`, section "Post-Swap Action Required", for details.

Something went wrong? See [Troubleshooting](#troubleshooting).

#### Step 3.2: Run the swap script

Replace `YourNamespace` with the namespace you registered in Step 2 (for example `acmecorp`).

**In the terminal**:

```shell
node bin/swap-namespace.js YourNamespace
```

You should see `Swap to 'YourNamespace' complete.`, then a line that starts `README.md replaced with subscriber stub.`, then the script's own `Next steps.` list.

To keep a README you wrote yourself, add `--keep-readme` to that command instead. **In the terminal**:

```shell
node bin/swap-namespace.js YourNamespace --keep-readme
```

You should see the same `Swap to 'YourNamespace' complete.` line, with no line about `README.md`.

The script handles every kind of reference. It rewrites every `kern.ClassName` and `kern__Field__c`, the `<kern>` namespace declaration, and the filesystem paths (`kernHome/`, `KernHome.tab-meta.xml`, `KernLogo.asset`). It also produces a finished `sfdx-project.json` from the template in this repo. As proof that the swap completed, it writes `.namespace-origin.json` at the root of your working copy, and it refuses to run a second time on the same tree.

After a successful swap, the script replaces the top-level `README.md` with a short stub that credits KernDX, names your namespace, and points at your renamed `docs/` content. The original KernDX README isn't appropriate for your renamed copy, which is why it's swapped out. If you wrote your own README before the swap and want to keep it, pass `--keep-readme`.

See `bin/README.md` in this repo for the full script details, the `--dry-run` audit format, the `--keep-readme` opt-out, and one step the script can't do for you: replacing the logo image. The file `<TargetPascal>Logo.asset` is renamed correctly, but its image content is still the KernDX logo. Replace it with your own before you ship to your users.

Something went wrong? See [Troubleshooting](#troubleshooting).

#### Step 3.3: Verify the swap

**In the terminal**:

```shell
node bin/swap-namespace.js --verify
```

You should see a line that starts `Swapped:` and names your target namespace and an ISO timestamp, then `No reference to the original namespace is left in force-app.`

If it lists leftover references, the swap is incomplete. Report them: the script aims to handle every case, so any leftover reference points to a gap in the script that is worth fixing.

Something went wrong? See [Troubleshooting](#troubleshooting).

---

### Step 4: Configure Your Package

Good news: there is nothing to do here by hand. The rename script in Step 3.2 already wrote your `sfdx-project.json` from the template, with your namespace, `sfdcLoginUrl`, and `sourceApiVersion: 68.0` all in place. **You do not need to edit `sfdx-project.json` manually at this point.**

You can skip straight to Step 5, where the remaining fields fill themselves in:

- `sf package create` (Step 5.1) adds a `packageAliases` entry and completes `packageDirectories[0]` with the new `package` field. The template deliberately ships without a `package` field so this update lands cleanly instead of duplicating an entry.
- Creating the first package version (Step 5.2) then writes that version's `versionName` and `versionNumber` into `packageDirectories[0]`.

---

### Step 5: Create Your Managed Package

#### Step 5.1: Create the package

**1. In the terminal**, create the package:

```shell
sf package create --name "YourCompanyFramework" --package-type "Managed" --path "force-app" --target-dev-hub MyCompanyDevHub
```

You should see a table titled `Ids` holding your new `Package Id`.

**2. In the terminal**, check that your package is listed:

```shell
sf package list --target-dev-hub MyCompanyDevHub
```

You should see your package listed, with your namespace in the `Namespace Prefix` column.

Something went wrong? See [Troubleshooting](#troubleshooting).

#### Step 5.2: Create your first package version

**First, commit your rebrand to a local branch.** The build script needs a clean `force-app/` tree to work from. During the build it temporarily adds namespace prefixes to your files, then undoes those changes with `git checkout`, so it relies on git having a clean committed state to revert to.

**1. In the terminal**, from your project root:

```shell
git add -A
git commit -m "rebrand to YourNamespace"
```

You should see git's summary of the commit, whose first line ends `rebrand to YourNamespace`.

**2. In the terminal**, build:

```shell
node scripts/build-package.js --package "YourCompanyFramework" --dev-org MyCompanyDevHub --no-resync
```

You should see `Build Complete` when it finishes.

This takes 10-30 minutes. Save the **Package Version ID** (it starts with `04t`) and the **Installation URL**.

**Why `build-package.js` instead of `sf package version create` directly?** Because one type of reference won't get your namespace prefix otherwise, and the package will break at runtime.

Here's the problem. Some metadata stores class and field names as plain text strings rather than as real references: Custom Metadata records (for example `ApiSetting` and `TriggerAction`), Flow metadata, FlexiPages, and LWC `apex://` references. During a managed-package build, Salesforce applies your namespace prefix to genuine references but *not* to these plain-string values.

`scripts/build-package.js` solves this. Its Step 1 calls `scripts/prepare-package-build.js`, which writes the prefix into those string fields for the duration of the build (for example, `ClassName__c = "API_PostExample"` becomes `ClassName__c = "yournamespace.API_PostExample"`), then restores your working tree to its committed state afterwards. Run `sf package version create` directly and you skip this step, so the finished package fails at runtime with errors like `No API setting record was found for the service yournamespace.<class>.`

Three flags to know. Use `--dev-org` to name your Dev Hub (the alias you chose in Step 1): without it the script looks for a Dev Hub called `DevHub`, which is not yours, and the build fails. Use `--no-resync` because the resync step targets the KernDX maintainer's dev org, which you don't have. Use `--skip-validation` only for quick smoke-test builds; a real release candidate should always run with validation on.

Something went wrong? See [Troubleshooting](#troubleshooting).

#### Step 5.3: Test your beta version

**In Salesforce**:

1. Open the **Package Installation URL** from Step 5.2
2. Install in a scratch org or sandbox
3. Test all functionality thoroughly
4. Verify your namespace prefix appears on all components

#### Step 5.4: Promote to released

**In the terminal**:

```shell
sf package version promote --package "YourPackageVersionId" --target-dev-hub MyCompanyDevHub
```

You should see the question `Release package (y/n)?` first; answer `y`. Then you see `Successfully promoted the package version`, with your version's ID.

Something went wrong? See [Troubleshooting](#troubleshooting).

---

### Complete Example: Acme Corp

To see all five steps in one place, here is the whole sequence for a fictional company, **Acme Corp**, using the namespace `acmecorp`. Each block holds one action, in order.

Step 1, enable your Dev Hub.

**1. In the terminal**:

```shell
sf org login web --alias AcmeDevHub --set-default-dev-hub
```

You should see `Successfully authorized` followed by the Dev Hub's username and org ID.

Step 2, log in to the org that will own the namespace, then register and link it in the browser (Steps 2.1 and 2.2 cannot be done from the terminal).

**2. In the terminal**:

```shell
sf org login web --alias AcmeNamespace
```

You should see `Successfully authorized` followed by the namespace org's username and org ID.

**3. In Salesforce**, for Step 2.1, in the AcmeNamespace org: Setup > Packages > Package Manager > Namespace Settings > Edit. Enter "acmecorp" > Check Availability > Save.

**4. In Salesforce**, for Step 2.2, in the AcmeDevHub org: App Launcher > "Namespace Registries" > Link Namespace. Log in with AcmeNamespace credentials > Authorize. Verify "Linked" status.

Step 3, clone the project.

**5. In the terminal**:

```shell
git clone https://github.com/JVB-Consulting/kerndx acme-framework
```

You should see a new folder named `acme-framework`.

Move into it.

**6. In the terminal**:

```shell
cd acme-framework
```

You should see nothing printed; every command after this one runs inside `acme-framework`.

Rebrand it under the `acmecorp` namespace. The swap rewrites every reference and path, writes `sfdx-project.json` from the template, and refuses to run twice.

**7. In the terminal**:

```shell
node bin/swap-namespace.js acmecorp
```

You should see `Swap to 'acmecorp' complete.`

Check it.

**8. In the terminal**:

```shell
node bin/swap-namespace.js --verify
```

You should see `No reference to the original namespace is left in force-app.`

Step 4 needs nothing from you: the swap already wrote `sfdx-project.json`.

Step 5, create the package.

**9. In the terminal**:

```shell
sf package create --name "AcmeFramework" --package-type "Managed" --path "force-app" --target-dev-hub AcmeDevHub
```

You should see a table titled `Ids` holding the new `Package Id`.

Commit the rebrand, because the build needs a clean `force-app/`.

**10. In the terminal**:

```shell
git add -A
git commit -m "rebrand to acmecorp"
```

You should see git's summary of the commit, whose first line ends `rebrand to acmecorp`.

Build, so your namespace prefix is written into the metadata that stores names as plain text.

**11. In the terminal**:

```shell
node scripts/build-package.js --package "AcmeFramework" --dev-org AcmeDevHub --no-resync
```

You should see `Build Complete` when it finishes.

Promote it, using your own Package Version ID.

**12. In the terminal**:

```shell
sf package version promote --package "YourPackageVersionId" --target-dev-hub AcmeDevHub
```

You should see the question `Release package (y/n)?`; answer `y`, and you see `Successfully promoted the package version`.

Something went wrong? See [Troubleshooting](#troubleshooting).

---

### Troubleshooting

These are the errors people most often hit on all three paths, along with the cause and the fix for each. The
entries for repackaging under your own namespace (Path 2) come first, then those for installing the managed package
(Path 1) and for the CI tooling (Path 3). Find the message that matches yours.

#### "Namespace not found"

**Cause:** Namespace not properly linked to Dev Hub.

Follow Step 2.2 to link via the **Salesforce UI** (cannot be done via CLI):

1. Log into **Dev Hub org** in browser
2. Open **App Launcher** > **"Namespace Registries"**
3. Click **"Link Namespace"**
4. Log in with **Namespace Org** credentials
5. **Authorize** the connection
6. Verify status is **"Linked"**

#### "Package name already exists"

Choose a different package name, or delete the existing package:

```shell
sf package delete --package "PackageName" --target-dev-hub MyCompanyDevHub
```

#### "Code coverage below 75%"

- Ensure all test classes have `@IsTest` annotation
- Run tests locally, replacing `YourOrgAlias` with the alias of the org that holds your deployed source:

  ```shell
  sf apex run test -o YourOrgAlias --test-level RunLocalTests --code-coverage --result-format human
  ```

- Fix any failing tests before creating package version

#### Package Build Fails with "Object does not exist"

**Cause:** Duplicate rules (`.duplicateRule-meta.xml`) still reference the original namespace.

List your duplicate rule files, then update any that still name the original namespace:

```shell
git ls-files "*.duplicateRule-meta.xml"
```

#### "duplicate value found: CustomNotifTypeName"

**Cause:** CustomNotificationType has identical name to an existing package in the target org.

**Resolution:**

1. Find the file:

   ```shell
   git ls-files "*.notificationType-meta.xml"
   ```

2. Rename the file to use your namespace prefix
3. Update `<customNotifTypeName>` to be globally unique (include company name)
4. Rebuild package version

#### Lightning Page Components Missing

**Cause:** `.flexipage-meta.xml` files reference incorrect namespace in fieldset/component references.

```shell
git grep -l "OriginalNamespace" -- "*.flexipage-meta.xml"
```

Update fieldset references, component references, and record type references to use your namespace.

#### Metadata Uniqueness Reference

A few metadata types must be unique across every package in an org, not just within yours. If your renamed copy and another package both use the same name, the install fails. When that happens, change the value shown here to something unique to you:

| Metadata Type              | Uniqueness Field             | Resolution        |
|----------------------------|------------------------------|-------------------|
| **CustomNotificationType** | `customNotifTypeName`        | Rename XML label  |
| **DuplicateRule**          | `masterLabel`                | Rename label      |
| **MatchingRule**           | `masterLabel`                | Rename label      |
| **ExternalDataSource**     | `endpoint` + `principalType` | Change endpoint   |
| **RemoteSiteSetting**      | `url`                        | Use different URL |
| **ContentSecurityPolicy**  | `masterLabel`                | Rename label      |

#### The package install reports an error

This applies to Path 1, when you install or upgrade the package.

**Why:** the install stopped, and the command's own message names the cause.

**What to do:** read that message first. Then check that the package version id is the one from the
[Releases page](https://github.com/JVB-Consulting/kerndx/releases) (it starts `04t`), and that the org you named is the
one you meant to install into, and that you are allowed to install packages there.

#### The permission set cannot be assigned

This applies to Path 1, when you give the CI integration user its permission set.

**Why:** the command could not find the user, or could not find the permission set by the name you gave.

**What to do:** the value after `-o` must be the integration user's username or alias, exactly as `sf org list` shows
it. The permission set's name carries the package namespace: `kern__Administrator` for the managed package, and
`YourNamespace__Administrator` if you repackaged under your own namespace.

#### `mkdir` says the folder already exists

This applies to Path 3 on Windows, where the unpack starts with `mkdir`; on a Mac or Linux the unpack creates the folder itself.

**Why:** an earlier unpack left the `.kerndx-pipeline` folder in place.

**What to do:** run the removal line for your computer under
[Upgrading the CI tooling](#upgrading-the-ci-tooling), then unpack again.

#### `npm ci` complains about the Node version

This applies to Path 3, when you install the tooling's dependencies.

**Why:** the Node version on your computer is not the one the tooling needs. Use Node 22, the version Set Up Your
Computer asks for; the tooling itself accepts Node 20 or later.

**What to do:** follow the entry "Node is the wrong version" on
[Set Up Your Computer](Set%20Up%20Your%20Computer.md#node-is-the-wrong-version), then run the install again.

#### `kerndx init` or `kerndx upgrade` stops with a message

This applies to Path 3, when you set up or upgrade the tooling.

**Why:** the command needs something it did not find, and its message says what.

**What to do:** give it what the message asks for, then run it again. The [Full Reference](#full-reference) section
lists where to find each command and its flags.

#### aer runs fewer tests than you asked for, or a test fails only in aer

This applies when you run the tests on your computer with aer.

**Why:** how many tests one aer run may take depends on aer's licence terms. When a run asks for more than those terms allow, aer prints a licence message and stops or skips tests. That is the licence, not a problem in the code. Separately, aer does not copy every detail of how Salesforce behaves, so now and then a test that passes in an org fails in aer.

**What to do:** for a licence message, run one test method at a time (step 3 of [Run the tests on your computer with aer](#run-the-tests-on-your-computer-with-aer-optional)), or see [aer's repository](https://github.com/octoberswimmer/aer-dist), which explains its licence terms. If a test passes in your org but fails in aer, report it on [aer's issue tracker](https://github.com/octoberswimmer/aer-dist/issues).

---

### Run the tests on your computer with aer (optional)

Running Apex tests normally means deploying to an org and waiting. aer, a tool made by October Swimmer, runs them on your own computer instead, straight from your source folder, with no org. That makes it a quick check after you change the code, before you deploy or build a package.

This is for you if you deploy KernDX from source: repackaged under your own namespace (this path) or deployed with no namespace. It works the same way on your own Apex classes in the same project.

aer is a separate product with its own licence terms. [aer's repository](https://github.com/octoberswimmer/aer-dist) explains how to install it and how many tests one run may take with and without a licence. The steps below cover only what is specific to KernDX.

**1. Install aer** by following [aer's repository](https://github.com/octoberswimmer/aer-dist). The steps below need the `aer` command on your `PATH` (the list of folders your terminal searches for programs).

**2. In the terminal**, check that aer is installed:

```shell
aer --version
```

You should see `aer version` followed by its version number.

**3. In the terminal**, from the top folder of your project, run one test method:

```shell
aer test force-app -p Administrator -f UTIL_Random_TEST.shouldGenerateNonNullBoolean
```

You should see `PASS UTIL_Random_TEST.shouldGenerateNonNullBoolean`, then `Ran 1 tests: 1 passed, 0 failed`.

Put your own class and method name after `-f` to run a different test.

To run more than one test in a single aer run on a project the size of KernDX, your aer licence must allow it ([aer's repository](https://github.com/octoberswimmer/aer-dist) explains the terms). Without that, aer prints a licence message and runs none of the tests you asked for. With it, put only a class name after `-f` to run every test in that class:

```shell
aer test force-app -p Administrator -f UTIL_Random_TEST
```

You should see a `PASS` line for each test method, then a summary such as `Ran 20 tests: 20 passed, 0 failed`.

Why `-p Administrator`? The public repository has no `profiles` folder, and aer gives its test user only the access your source folder grants. `-p Administrator` tells aer to run as a user who holds the Kern Administrator permission set, as an admin would in a real org. Without it, tests that read fields only that permission set grants will fail.

With the same licence, you can run a group of classes by giving `-f` a name pattern, where `*` stands for any characters. **In the terminal**:

```shell
aer test force-app -p Administrator -f "UTIL_R*"
```

You should see a `PASS` line for each test method in every class whose name starts with `UTIL_R`, then the summary.

These commands are written to work in Command Prompt, PowerShell and a macOS or Linux terminal. Keep the double quotes around a pattern: Command Prompt does not treat single quotes as quotes.

**4. To run every test at once**, check first that your aer licence allows a run that size ([aer's repository](https://github.com/octoberswimmer/aer-dist) explains the terms). Then, **in the terminal**, from the top folder of your project, run every test:

```shell
aer test force-app -p Administrator
```

You should see a `PASS` line for each test method, any failures, then the summary of the whole run.

**What to expect.** Almost all of KernDX's tests pass under aer; the current figure is in [Strategic Guide - Metrics](Strategic%20Guide%20-%20Metrics.md). A few behave differently, because aer does not copy every detail of how Salesforce behaves. So a real org stays the final word: before you build your package, run the tests there too (the package build in Step 5.2 does this when validation is on).

Two limits to know:

- If you use aer's namespace option (`-d YourNamespace`), it does not check that only `global` classes and methods can be reached from another namespace. Only a real org with your namespace proves that.
- aer can stand in for an installed managed package so you can test code that calls it (its `aer package mock` command), but that does not work for the KernDX managed package today: it stops on the `MaskingTarget__mdt` custom metadata type. So you cannot yet use aer to test your own code against an installed KernDX (Path 1).

Something went wrong? See [Troubleshooting](#aer-runs-fewer-tests-than-you-asked-for-or-a-test-fails-only-in-aer).

---

### Next Steps

Once your package is released:

1. **Install in Orgs:** Share the installation URL with your team
2. **Version Updates:** Update `versionNumber` in `sfdx-project.json`, commit the change, and run the build command from Step 5.2 again
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

- `@jvb-consulting/kerndx-pipeline` CLI: 9 commands (`init`, `scan`, `naming`, `preflight`, `doctor`, `upgrade`, `classify-ref`, `secret-scan`, `slack-payload`).
- ESLint plugin (`eslint-plugin-kerndx`): 7 behavioural rules, with no formatting opinions.
- Two PMD rulesets: naming and sharing-modifier enforcement.
- Ten Eta-rendered GitHub Actions workflow templates, including the `sfca-quality-gate` scan, naming validation, secret scanning, and the Slack-bridge alert workflows.
- `INSTALL-PIPELINE.md`: the full setup guide, bundled inside the zip.

### Install

Download `KernDX-YourVersion-pipeline.zip` from the [Releases page](https://github.com/JVB-Consulting/kerndx/releases)
and put it in your project's top folder, the folder that holds `sfdx-project.json`. In the commands below, replace
`YourVersion` with the version in the file name you downloaded. Set up your terminal and the CLI with
[Set Up Your Computer](Set%20Up%20Your%20Computer.md) first; on Windows that terminal is Command Prompt.

**1. In the terminal**, unpack it into a folder named `.kerndx-pipeline`, with the commands for your computer.

**Windows (Command Prompt)**

```bat
mkdir .kerndx-pipeline
tar -xf KernDX-YourVersion-pipeline.zip -C .kerndx-pipeline
```

**macOS or Linux**

```bash
unzip KernDX-YourVersion-pipeline.zip -d .kerndx-pipeline
```

You should see a new `.kerndx-pipeline` folder holding `bin` and `pipeline`, the two folders the next commands use.

**2. In the terminal**, install the tooling's own dependencies:

```shell
npm ci --omit=dev --prefix .kerndx-pipeline/pipeline
```

You should see npm's summary, a line that starts `added` and counts the packages it installed.

**3. In the terminal**, set it up:

```shell
node .kerndx-pipeline/bin/kerndx init
```

You should see `.kerndx/config.yml` in your project and the workflow templates in `.github/workflows/` once you have answered its questions.

`init` walks you through setting up `.kerndx/config.yml` (your prefix and domain conventions, Slack webhook, and CI-tool adapter) and wires the workflow templates into `.github/workflows/`. It is safe to re-run after upgrades.

If you'd like to see the 9 rendered workflow examples before you install, they're browsable in the public repo at [`examples/workflows/`](https://github.com/JVB-Consulting/kerndx/tree/main/examples/workflows).

Something went wrong? See [Troubleshooting](#troubleshooting).

### Upgrading the CI tooling

Download the newer `KernDX-YourVersion-pipeline.zip` into your project's top folder, then replace the old tooling with it.

**1. In the terminal**, remove the old tooling and unpack the new one, with the commands for your computer.

**Windows (Command Prompt)**

```bat
rmdir /s /q .kerndx-pipeline
mkdir .kerndx-pipeline
tar -xf KernDX-YourVersion-pipeline.zip -C .kerndx-pipeline
```

**macOS or Linux**

```bash
rm -rf .kerndx-pipeline
unzip KernDX-YourVersion-pipeline.zip -d .kerndx-pipeline
```

You should see the `.kerndx-pipeline` folder again, holding `bin` and `pipeline` from the newer zip.

**2. In the terminal**, install its dependencies again:

```shell
npm ci --omit=dev --prefix .kerndx-pipeline/pipeline
```

You should see npm's summary, a line that starts `added` and counts the packages it installed.

**3. In the terminal**, let it refresh what it scaffolded:

```shell
node .kerndx-pipeline/bin/kerndx upgrade
```

You should see `Backups:` followed by the count of files saved as `.bak`.

`upgrade` keeps your `.kerndx/config.yml`, re-renders the workflow templates against the new version, and backs up every scaffolded file to `.bak` before it
overwrites it. It stops if `.bak` files from an earlier upgrade are still there: review and delete them, or add `--force` to skip that review.

Something went wrong? See [Troubleshooting](#troubleshooting).

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
