---
navOrder: 30
---

# Fast Start - LWC

**Framework:** KernDX | **Total time:** ~30 minutes

**What this is:** A faster way to build Lightning Web Components. You extend one KernDX base class and the wiring every component needs (toast notifications, Apex calls with error handling, navigation, and logging) is already built in. **Why it exists:** Without a framework you re-write that same plumbing in every component, by hand. **Who should follow this:** developers building Lightning UI, and the tech leads who review it. **When to use it:** any time you'd otherwise start a component from `LightningElement` and re-wire toasts and Apex calls yourself.

> **Namespaces in code samples:** `kern.` on a class and `kern__` on an object, field, or metadata type mark the managed package's namespace.
> On the managed package, framework references need those prefixes even where a sample omits them; repackaged under your own namespace, replace `kern`/`kern__`
> with your prefix; on an unmanaged deploy, drop them. See [How to read the code samples](Installation.md#how-to-read-the-code-samples).

**What you'll build:** A KernDX-aware Lightning Web Component that calls an Apex controller method, shows a
toast on success or failure, and logs errors through the framework's client logger. You'll also write a Jest test that
mocks the framework base class so the component runs in isolation.

**Success looks like:** Your component drops onto a Lightning page, calls Apex, and raises a success toast.
Your Jest test passes with the framework base class mocked out, and the component imports the base from the
managed-package namespace (`kern/componentBuilder`).

**In one line:** `export default class MyComponent extends ComponentBuilder('notification', 'controller') {}`. Every KernDX component extends `ComponentBuilder(...)`, never `LightningElement` directly.

## Before you start

Open your terminal in your project's top folder, the one that holds `sfdx-project.json`; on Windows that terminal is
Command Prompt. Run the four-line check on [Set Up Your Computer](Set%20Up%20Your%20Computer.md#check-you-are-ready)
once: it proves your terminal, the CLI, your login and the KernDX package, and answers what goes wrong. Done that
today? Carry on. Work in a sandbox or a scratch org, never production. Every command below writes `YourOrgAlias`
where your org's alias goes: the name you gave it when you logged in.

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [Before you start](#before-you-start)
2. [The one rule: extend ComponentBuilder](#the-one-rule-extend-componentbuilder)
3. [Tier 1: See It Work (~2 minutes)](#tier-1-see-it-work-2-minutes)
    - [The smallest KernDX component](#the-smallest-kerndx-component)
    - [Add a toast](#add-a-toast)
    - [The namespace gotcha](#the-namespace-gotcha)
4. [Tier 2: Build Your Own (~20 minutes)](#tier-2-build-your-own-20-minutes)
    - [Step 1: Create the Apex controller](#step-1-create-the-apex-controller)
    - [Step 2: Create the component](#step-2-create-the-component)
    - [Step 3: Deploy and drop it on a page](#step-3-deploy-and-drop-it-on-a-page)
    - [Step 4: Write the Jest test](#step-4-write-the-jest-test)
    - [Step 5: Run the test](#step-5-run-the-test)
    - [Key Patterns](#key-patterns)
5. [Tier 3: Reference and Next Steps (~5-10 minutes)](#tier-3-reference-and-next-steps-5-10-minutes)
    - [Choosing modules](#choosing-modules)
    - [What every component inherits](#what-every-component-inherits)
    - [Client-side logging](#client-side-logging)
    - [Custom labels for all UI text](#custom-labels-for-all-ui-text)
    - [Pre-built components you can drop in without code](#pre-built-components-you-can-drop-in-without-code)
    - [Honest scope and limitations](#honest-scope-and-limitations)
    - [Clean up](#clean-up)
6. [Common Issues](#common-issues)
    - [Step 1: Create the Apex controller](#step-1-create-the-apex-controller-1)
    - [Step 2: Create the component](#step-2-create-the-component-1)
    - [Step 3: Deploy and drop it on a page](#step-3-deploy-and-drop-it-on-a-page-1)
    - [Step 5: Run the test](#step-5-run-the-test-1)
    - [Clean up](#clean-up-1)
7. [What You Now Know](#what-you-now-know)
8. [Next Steps](#next-steps)

</details>

---

## The one rule: extend ComponentBuilder

Every Lightning Web Component you build needs the same plumbing: toast notifications, Apex calls with error
handling, navigation, and logging. Without a framework you re-write that wiring in every component. KernDX
gives you one base class that already has it all wired in (a base class with the common LWC wiring already
built in, the `ComponentBuilder(...)` factory). So each custom component extends `ComponentBuilder(...)`
instead of extending `LightningElement` directly:

```javascript
import {ComponentBuilder} from 'kern/componentBuilder';

export default class MyComponent extends ComponentBuilder('notification', 'controller')
{
	// your component
}
```

`ComponentBuilder(...)` returns a base class with the modules you ask for already wired in. You pass module
identifiers (`'notification'`, `'controller'`, `'navigation'`, `'lightning-message'`, `'flow-navigation'`,
or `'all'`) and the matching methods (`showSuccessToast()`, `callControllerMethod()`, and so on) become
available on `this`. Ask only for the modules you use. If you call a method from a module you didn't request,
it logs a guidance error instead of running.

> **Why not `LightningElement`?** Extending `LightningElement` directly bypasses the framework's
> notification, controller, navigation, and logging helpers. You would re-implement toasts, Apex error
> handling, and navigation by hand in every component. `ComponentBuilder` asked for a single module only
> initialises that one module, so it is the recommended starting point for every custom component.

---

## Tier 1: See It Work (~2 minutes)

> **Heads up: no Developer Console here.** Unlike the Apex Fast Starts, LWC bundles cannot be created in the
> Developer Console's Execute Anonymous window. You need a Salesforce DX project on disk and the `sf` CLI.
> Each component below is a folder under `force-app/main/default/lwc/`.

### The smallest KernDX component

A component is a folder of files: here, a folder `force-app/main/default/lwc/firstKernComponent/` with three.

**1. In the terminal**, from your project's top folder, create the component:

```shell
sf lightning generate component --name firstKernComponent --type lwc --output-dir force-app/main/default/lwc
```

You should see four files created in `force-app/main/default/lwc/firstKernComponent`: `firstKernComponent.js`,
`firstKernComponent.html`, `firstKernComponent.js-meta.xml`, and a test file in a `__tests__` folder that this tier
does not use.

**2. In your editor**, open each of the three files below in turn, delete what is there, paste the code under it in,
and save. First the JavaScript file:

```text
force-app/main/default/lwc/firstKernComponent/firstKernComponent.js
```

```javascript
import {ComponentBuilder} from 'kern/componentBuilder';

export default class FirstKernComponent extends ComponentBuilder('notification')
{
	handleClick()
	{
		this.showSuccessToast('It works!');
	}
}
```

Then the HTML file:

```text
force-app/main/default/lwc/firstKernComponent/firstKernComponent.html
```

```html
<template>
	<lightning-button label="Try Me" onclick={handleClick}></lightning-button>
</template>
```

Then the configuration file, which tells Salesforce where the component may be placed:

```text
force-app/main/default/lwc/firstKernComponent/firstKernComponent.js-meta.xml
```

```xml
<?xml version="1.0" encoding="UTF-8"?>
<LightningComponentBundle xmlns="http://soap.sforce.com/2006/04/metadata">
	<apiVersion>68.0</apiVersion>
	<isExposed>true</isExposed>
	<targets>
		<target>lightning__AppPage</target>
		<target>lightning__HomePage</target>
		<target>lightning__RecordPage</target>
	</targets>
</LightningComponentBundle>
```

**3. In the terminal**, send the component to your org:

```shell
sf project deploy start -o YourOrgAlias -m "LightningComponentBundle:firstKernComponent"
```

You should see `Status: Succeeded`, with `firstKernComponent` listed as created. The test file in `__tests__` stays on
your computer.

Something went wrong? See [Common Issues, Step 3](#step-3-deploy-and-drop-it-on-a-page-1), which covers a component
deploy that fails.

Because the class extends `ComponentBuilder('notification')`, `this.showSuccessToast(...)` already exists.
You did not import `ShowToastEvent` or dispatch it yourself.

### Add a toast

Asking for the `notification` module gives you four ready-made toast helpers plus a custom one.

**In your editor**, in any component that asks for `notification`:

```javascript
this.showSuccessToast('Record saved');
this.showErrorToast('Something went wrong');
this.showWarningToast('Please review your input');
this.showInfoToast('Working on it…');
```

`showErrorToast` is especially handy. Pass it the raw error object straight from a `catch` block and the
framework normalises Apex, Lightning Data Service, and UI API error shapes into a readable message for you.

### The namespace gotcha

This is the single most common mistake when building KernDX components in a subscriber org. **The base class
lives in the managed package, so you import it from the `kern/` namespace, not `c/`.**

**In your editor**, at the top of your component's JavaScript file:

```javascript
// CORRECT — the managed package owns the module
import {ComponentBuilder} from 'kern/componentBuilder';

// WRONG in a subscriber org — c/ resolves to your own namespace, not KernDX's
import {ComponentBuilder} from 'c/componentBuilder';
```

The same rule applies to any KernDX LWC module you import: `kern/utilityLogger`, `kern/utilityString`,
`kern/featureFlag`, and so on. Your **own** components still reference each other with `c/` (your namespace).
Only the modules that ship inside the KernDX managed package take the `kern/` prefix.

> **Quick test:** if a component fails to compile on deploy with *"No MODULE named markup://c:componentBuilder
> found"*, you imported from `c/` instead of `kern/`. Switch the prefix and redeploy.

> **When to move to Tier 2:** When you want a real component that calls Apex and ships with a Jest test.

---

## Tier 2: Build Your Own (~20 minutes)

Now build something real: an Account summary card. It calls an Apex controller to load an Account by ID,
shows the name and industry, and raises a toast if the load fails. This is the everyday shape of a KernDX
component, so it doubles as a template you can copy for your own work.

### Step 1: Create the Apex controller

A KernDX LWC component calls server logic through `callControllerMethod()`, which invokes an
`@AuraEnabled` Apex method. Keep the component thin: business logic belongs in Apex, not the component. You create
the controller and its test class, paste the code into each, send both to your org, then run the test.

**1. In the terminal**, from your project's top folder, create the empty controller class:

```shell
sf apex generate class --name CTRL_AccountCard --output-dir force-app/main/default/classes
```

You should see two files created in `force-app/main/default/classes`: `CTRL_AccountCard.cls` and its companion of
the same name ending in `.cls-meta.xml`.

**2. In your editor**, open this file, delete what is there, paste the code below in, and save:

```text
force-app/main/default/classes/CTRL_AccountCard.cls
```

```apex
/**
 * @description Controller for the accountCard LWC. Loads a single Account for display.
 *
 * @see CTRL_AccountCard_TEST
 *
 * @author your.name@company.com
 *
 * @group Account Management
 *
 * @date February 2026
 */
public with sharing class CTRL_AccountCard
{
	/**
	 * @description Loads one Account by ID for the accountCard component.
	 *
	 * @param accountId The Id of the Account to load.
	 *
	 * @return The Account with Name and Industry populated.
	 */
	@AuraEnabled(cacheable=true)
	public static Account getAccount(Id accountId)
	{
		return (Account)kern.QRY_Builder.selectFrom(Account.SObjectType)
				.fields(new List<SObjectField> {Account.Name, Account.Industry})
				.condition(Account.Id).equals(accountId)
				.getFirst();
	}
}
```

> **Why `kern.QRY_Builder`?** It enforces field-level security (FLS, who can see which fields) on the query
> and keeps your controller free of inline SOQL. See [Fast Start - Selectors](Fast%20Start%20-%20Selectors.md)
> for the full query pattern.

Add a test for the controller, because the framework's coverage gate expects every Apex class covered.

**3. In the terminal**, create the empty test class:

```shell
sf apex generate class --name CTRL_AccountCard_TEST --output-dir force-app/main/default/classes
```

You should see two files named `CTRL_AccountCard_TEST` created in `force-app/main/default/classes`: the class, ending
in `.cls`, and its companion ending in `.cls-meta.xml`.

**4. In your editor**, open this file, delete what is there, paste the code below in, and save:

```text
force-app/main/default/classes/CTRL_AccountCard_TEST.cls
```

```apex
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=true)
private class CTRL_AccountCard_TEST
{
	@IsTest
	private static void shouldLoadAccountById()
	{
		Account account = (Account)kern.TST_Builder.of(Account.SObjectType)
			.withOverride(Account.Name, 'Acme')
			.withOverride(Account.Industry, 'Technology')
			.build();

		Test.startTest();
		Account result = CTRL_AccountCard.getAccount(account.Id);
		Test.stopTest();

		Assert.areEqual('Acme', result.Name, 'Should load the requested Account');
		Assert.areEqual('Technology', result.Industry, 'Should populate Industry');
	}
}
```

**5. In the terminal**, send both classes to your org:

```shell
sf project deploy start -o YourOrgAlias -m "ApexClass:CTRL_AccountCard" -m "ApexClass:CTRL_AccountCard_TEST"
```

You should see `Status: Succeeded`, with `CTRL_AccountCard` and `CTRL_AccountCard_TEST` listed as created.

**6. In the terminal**, run the test:

```shell
sf apex run test -o YourOrgAlias -t CTRL_AccountCard_TEST --code-coverage --synchronous --result-format human
```

You should see 1 test passing and full coverage on `CTRL_AccountCard`: the test shows `Pass`, the summary line
`Outcome` reads `Passed`, and the coverage table shows `CTRL_AccountCard` at `100%`.

Something went wrong? See [Common Issues, Step 1](#step-1-create-the-apex-controller-1).

### Step 2: Create the component

A component is a folder of files. You create the folder with one command, paste the code into three of its files,
then create the Custom Label the component shows when a load fails.

**1. In the terminal**, from your project's top folder, create the component:

```shell
sf lightning generate component --name accountCard --type lwc --output-dir force-app/main/default/lwc
```

You should see four files created in `force-app/main/default/lwc/accountCard`: `accountCard.js`, `accountCard.html`,
`accountCard.js-meta.xml`, and a test file in a `__tests__` folder that you fill in at Step 4.

**2. In your editor**, open this file, delete what is there, paste the code below in, and save:

```text
force-app/main/default/lwc/accountCard/accountCard.js
```

```javascript
import {ComponentBuilder} from 'kern/componentBuilder';
import getAccount from '@salesforce/apex/CTRL_AccountCard.getAccount';
import LOAD_FAILED from '@salesforce/label/c.AccountCard_LoadFailed';
import {api} from 'lwc';

/**
 * @description Displays the name and industry of a single Account. Loads data through the
 * KernDX controller module and raises a toast on failure.
 *
 * @author your.name@company.com
 *
 * @date February 2026
 */
export default class AccountCard extends ComponentBuilder('notification', 'controller')
{
	/** @description The Id of the Account to display. Set by the record page or parent component. */
	@api recordId;

	/** @description The loaded Account record. */
	account;

	async connectedCallback()
	{
		try
		{
			this.account = await this.callControllerMethod(getAccount, {accountId: this.recordId});
		}
		catch(error)
		{
			this.consoleError(error, 'accountCard.connectedCallback');
			this.showErrorToast(LOAD_FAILED);
		}
	}
}
```

**3. In your editor**, open this file, delete what is there, paste the code below in, and save:

```text
force-app/main/default/lwc/accountCard/accountCard.html
```

```html
<template>
	<lightning-card title="Account">
		<template if:true={account}>
			<div class="slds-p-horizontal_small">
				<p>{account.Name}</p>
				<p>{account.Industry}</p>
			</div>
		</template>
	</lightning-card>
</template>
```

**4. In your editor**, open this file, delete what is there, paste the code below in, and save. It lets you place the
card on a record page:

```text
force-app/main/default/lwc/accountCard/accountCard.js-meta.xml
```

```xml
<?xml version="1.0" encoding="UTF-8"?>
<LightningComponentBundle xmlns="http://soap.sforce.com/2006/04/metadata">
	<apiVersion>68.0</apiVersion>
	<isExposed>true</isExposed>
	<targets>
		<target>lightning__RecordPage</target>
	</targets>
</LightningComponentBundle>
```

**What this code does:**

- `extends ComponentBuilder('notification', 'controller')`: gives the component toast helpers AND
  `callControllerMethod()`
- `import {ComponentBuilder} from 'kern/componentBuilder'`: the base class comes from the managed package
- `this.callControllerMethod(getAccount, {accountId: this.recordId})`: calls the `@AuraEnabled` Apex method,
  passing parameters by name, with framework error handling built in
- `this.showErrorToast(LOAD_FAILED)`: raises an error toast using a Custom Label, not a hardcoded string
- `this.consoleError(error, 'accountCard.connectedCallback')`: logs the error through the framework

`accountCard.js` imports a Custom Label, so the label must exist in your org before the component deploys. You create
it in Setup, then pull it into your project so it is under source control with your code.

**5. In Salesforce**, open Setup, then Custom Labels, then **New Custom Label**, and save a label with these values.
If Setup fills in **Name** from the short description, replace it with the name below:

| Field               | API name           | Value                                         |
|---------------------|--------------------|-----------------------------------------------|
| Short Description   | `shortDescription` | `Account card load failure message`           |
| Name                | `fullName`         | `AccountCard_LoadFailed`                      |
| Protected Component | `protected`        | unchecked                                     |
| Language            | `language`         | `English` (stored as `en_US`)                 |
| Value               | `value`            | `Could not load the account.`                 |

**6. In the terminal**, pull the label into your project:

```shell
sf project retrieve start -o YourOrgAlias -m "CustomLabel:AccountCard_LoadFailed"
```

You should see `Status: Succeeded`, and one file created or updated under `force-app/main/default/labels` that holds
your project's labels.

> **All displayed text comes from Custom Labels.** `LOAD_FAILED` is imported with
> `import LOAD_FAILED from '@salesforce/label/c.AccountCard_LoadFailed';`, so the `AccountCard_LoadFailed`
> label must exist **before** the bundle deploys. You created it in Setup and pulled it into your project above.
> Your org can then translate or override it without editing your code.

Something went wrong? See [Common Issues, Step 2](#step-2-create-the-component-1).

### Step 3: Deploy and drop it on a page

Send the label, the classes and the component to your org, in that order. The component's `@salesforce/label`
import is resolved at deploy time, so the bundle won't compile until the label exists in the org. The label and the
classes are already there from Steps 1 and 2, so the first two commands change nothing this time; keep the order
whenever you send this component to another org.

**1. In the terminal**, send the label:

```shell
sf project deploy start -o YourOrgAlias -m "CustomLabel:AccountCard_LoadFailed"
```

You should see `Status: Succeeded`, with `AccountCard_LoadFailed` listed (as `Unchanged` when the org already has it).

**2. In the terminal**, send the two classes:

```shell
sf project deploy start -o YourOrgAlias -m "ApexClass:CTRL_AccountCard" -m "ApexClass:CTRL_AccountCard_TEST"
```

You should see `Status: Succeeded`, with `CTRL_AccountCard` and `CTRL_AccountCard_TEST` listed (as `Unchanged` when
the org already has them).

**3. In the terminal**, send the component:

```shell
sf project deploy start -o YourOrgAlias -m "LightningComponentBundle:accountCard"
```

You should see `Status: Succeeded`, with `accountCard` listed as created. The test file in `__tests__` stays on your
computer: it is for Jest, not for your org.

**4. In Salesforce**, open any Account record, click the gear icon, choose **Edit Page**, drag **accountCard** from
the custom component list onto the layout, and **Save**. If Salesforce asks you to activate the page, activate it for
your org. The card loads the Account's name and industry through your
Apex controller.

> **Bundle cache after deploy:** a live Lightning session can keep serving the previously cached bundle when
> you navigate within the app. If a freshly deployed change looks like it did nothing, do a full browser page
> reload to pick up the new bundle.

Something went wrong? See [Common Issues, Step 3](#step-3-deploy-and-drop-it-on-a-page-1).

### Step 4: Write the Jest test

Jest runs your component outside Salesforce, so the real `kern/componentBuilder` module is not on the test
runner's module path. You **mock** it: you supply a stand-in base class that provides the framework methods
your component calls (`callControllerMethod`, `showErrorToast`, `consoleError`). Without this mock, the import
of `kern/componentBuilder` fails to resolve and the test cannot load your component.

**In your editor**, open this file (Step 2's command created it), delete what is there, paste the code below in, and
save:

```text
force-app/main/default/lwc/accountCard/__tests__/accountCard.test.js
```

```javascript
import {createElement} from 'lwc';
import AccountCard from 'c/accountCard';

// Mock the managed-package base class. ComponentBuilder(...) must return a real class
// extending LightningElement, with the framework methods this component calls stubbed.
// Assign the stubs in the constructor, NOT as class fields: class fields on a
// LightningElement subclass make the LWC compiler inject a decorator-registration
// helper, and Jest's mock-factory hoist guard rejects that out-of-scope reference.
jest.mock('kern/componentBuilder', () => ({
	ComponentBuilder: jest.fn().mockImplementation(() =>
	{
		const {LightningElement} = require('lwc');
		return class extends LightningElement
		{
			constructor()
			{
				super();
				this.callControllerMethod = jest.fn().mockResolvedValue({Name: 'Acme', Industry: 'Technology'});
				this.showErrorToast = jest.fn();
				this.consoleError = jest.fn();
			}
		};
	})
}), {virtual: true});

// The Apex import is also not resolvable in Jest — mock it too.
jest.mock('@salesforce/apex/CTRL_AccountCard.getAccount', () => ({default: jest.fn()}), {virtual: true});

// Custom Label imports resolve to their dev value in Jest, but mock to keep the test self-contained.
jest.mock('@salesforce/label/c.AccountCard_LoadFailed', () => ({default: 'Could not load the account.'}), {virtual: true});

describe('c-account-card', () =>
{
	afterEach(() =>
	{
		while(document.body.firstChild)
		{
			document.body.removeChild(document.body.firstChild);
		}
		jest.clearAllMocks();
	});

	it('renders the loaded account name', async() =>
	{
		const element = createElement('c-account-card', {is: AccountCard});
		element.recordId = '001000000000001';
		document.body.appendChild(element);

		// Let connectedCallback's awaited controller call resolve.
		await Promise.resolve();
		await Promise.resolve();

		const text = element.shadowRoot.textContent;
		expect(text).toContain('Acme');
		expect(text).toContain('Technology');
	});
});
```

> **Why `{virtual: true}`?** Jest's virtual-mock flag tells the runner to honour the mock even though the real
> `kern/componentBuilder` module does not exist on disk in your project. The same flag is used for the
> `@salesforce/apex/...` and `@salesforce/label/...` imports, which are resolved by the platform at runtime
> but not by Jest.

> **Note the two import prefixes.** Inside the test you import the component under test as `c/accountCard`
> (your namespace) but mock the framework base as `kern/componentBuilder` (the managed-package namespace),
> exactly matching how the component itself imports it.

Something went wrong? See [Common Issues, Step 5](#step-5-run-the-test-1).

### Step 5: Run the test

Jest runs on your computer, not in your org. You install the runner once, make sure the right Node version is
active, then run the one test.

**1. In the terminal**, if this is your first LWC test in the project, install the Jest runner. It's standard
Salesforce LWC tooling, not part of the managed package:

```shell
npm install --save-dev @salesforce/sfdx-lwc-jest
```

You should see a line that starts `added` and counts the packages npm installed. Lines about funding or
vulnerabilities that follow it are npm's routine notices, and so are any deprecation warnings printed before it.

**2. In the terminal**, switch to Node 22.22.3. Jest hangs silently on 22.23.x:

```shell
nvm use 22.22.3
```

You should see `Now using node v22.22.3`. If nvm says that version is not installed, install it with nvm first, then
run this step again. No `nvm` on your machine? Install that version from
[Node's download page](https://nodejs.org/en/download).

**3. In the terminal**, run the test:

```shell
npx sfdx-lwc-jest -- --testPathPattern=accountCard
```

You should see the test file marked `PASS` and the one test ticked:

```text
PASS  force-app/main/default/lwc/accountCard/__tests__/accountCard.test.js
  c-account-card
    ✓ renders the loaded account name
```

On Windows the path shows backslashes.

Jest also prints how long the test took, then a summary that ends `Ran all test suites matching /accountCard/i.`

Something went wrong? See [Common Issues, Step 5](#step-5-run-the-test-1).

### Key Patterns

| Pattern                | Example                                                 | Why                                                             |
|------------------------|---------------------------------------------------------|-----------------------------------------------------------------|
| Extend the factory     | `extends ComponentBuilder('notification', ...)`         | Inherits framework helpers; never extend `LightningElement`     |
| Import from `kern/`    | `from 'kern/componentBuilder'`                          | The base class lives in the managed package, not your namespace |
| Call Apex via module   | `this.callControllerMethod(apexMethod, {params})`       | Framework error handling and consistent calling convention      |
| Toast from a `catch`   | `this.showErrorToast(error)`                            | Turns a raw Apex, Lightning Data Service, or UI API error into a readable message for you |
| Custom Labels for text | `@salesforce/label/c.AccountCard_LoadFailed`            | Translatable, overridable: never hardcode user-facing strings   |
| Virtual-mock the base  | `jest.mock('kern/componentBuilder', …, {virtual:true})` | Resolves the managed-package import inside Jest                 |

---

## Tier 3: Reference and Next Steps (~5-10 minutes)

### Choosing modules

You only pay for the helpers you ask for, so request the modules your component actually uses.
`ComponentBuilder(...)` accepts any combination of these identifiers. If you call a method from a module you
didn't request, it logs guidance instead of running.

| Module              | Gives you                                                                                                                                |
|---------------------|------------------------------------------------------------------------------------------------------------------------------------------|
| `notification`      | `showSuccessToast()`, `showErrorToast()`, `showWarningToast()`, `showInfoToast()`, `customNotification()`, `customNotificationFactory()` |
| `navigation`        | `redirectToRecordPage()`, `generateRecordPageURL()`                                                                                      |
| `lightning-message` | `addMessageChannelSubscription()`, `publishLightningMessage()`, `clearSubscriptions()`                                                   |
| `controller`        | `callControllerMethod()`, `handleWireResponse()`                                                                                         |
| `flow-navigation`   | `dispatchFlowNextEvent()`, `dispatchFlowBackEvent()`, `dispatchFlowFinishEvent()`                                                        |
| `all`               | Every module above                                                                                                                       |

| Scenario                          | Recommended modules               |
|-----------------------------------|-----------------------------------|
| Form with a save confirmation     | `notification`                    |
| Record page with navigation       | `notification`, `navigation`      |
| Component talking to its siblings | `lightning-message`               |
| Loading data from Apex            | `controller`, `notification`      |
| Flow screen component             | `notification`, `flow-navigation` |
| Full-featured component           | `all`                             |

> **`'all'` is convenient but not free.** It initialises every module whether or not you use it. For
> components rendered in lists or hot paths, name only the modules you actually call.

### What every component inherits

Some helpers come with every component, no matter which modules you request. Every component extending
`ComponentBuilder(...)` inherits these base capabilities.

**In your editor**, in any KernDX component:

```javascript
// Dispatch a custom event (the framework routes the real name through the detail payload)
this.dispatchCustomEvent('recordselected', {recordId: '001xx'});

// Loading flag for spinner control
this.isLoading = true;

// Client-side logging through the framework
this.consoleLog('State loaded', this.account);
this.consoleError(error, 'accountCard.connectedCallback');
```

The base class also handles teardown for you: register cleanup work with `this.addTearDownOperation(fn)` and
the framework runs every registered operation in `disconnectedCallback()` for you.

### Client-side logging

Use the framework logging helpers instead of `console.log` / `console.error`. They route through the
framework's client logger.

**In your editor**, in any KernDX component:

```javascript
// Log a labelled value (objects are JSON round-tripped to strip Lightning proxies)
this.consoleLog('User clicked save', {recordId: this.recordId});

// Log an error — note the argument order: the error object comes first
this.consoleError(error, 'accountCard.handleSave');
```

These are buffered and flushed to Apex automatically, so the client's story is **kept and searchable** out
of the box (browser-console echoing is off by default; enable it while debugging with
`setConsoleMirroring(true)` from `kern/utilityLogger`). For correlation tracking and explicit log levels,
import the `kern/utilityLogger` module directly: its `debug()` / `info()` / `warn()` / `error()` calls are
flushed to Apex automatically and saved as `kern__LogEntry__c` rows, and an `Error` passed to `error()` keeps its JavaScript
stack trace and context data on the entry. For logging from your Apex controller method itself, call
`kern.LOG_Builder`. See
[Fast Start - Logging](Fast%20Start%20-%20Logging.md). To tie a client interaction to the Apex it triggers
under one tracking ID that follows a single user action across triggers, queries, callouts and jobs (a
correlation ID), the [LWC Guide](LWC%20-%20Guide.md#utilitylogger---client-side-logging) covers the
`utilityLogger` correlation helpers.

### Custom labels for all UI text

Every string a user sees must come from a Custom Label, never a hardcoded literal. This is what lets your org
translate and override your component's copy. The pattern in an LWC is a `@salesforce/label` import.

**In your editor**, in the component's JavaScript file:

```javascript
import SAVE_SUCCESS from '@salesforce/label/c.AccountCard_SaveSuccess';
// ...
this.showSuccessToast(SAVE_SUCCESS);
```

In the matching Apex controller, the equivalent is `System.Label.X`.

**In your editor**, in the controller class:

```apex
throw new AuraHandledException(System.Label.AccountCard_LoadFailed);
```

### Pre-built components you can drop in without code

Before you build, check whether KernDX already ships what you need. These components are exposed for use in
Lightning App Builder or Flow Builder with no code:

| Component            | What it does                                                             | Where to use it                                   |
|----------------------|--------------------------------------------------------------------------|---------------------------------------------------|
| `streamingMonitor`   | Real-time Platform Event, Change Data Capture, and streaming monitor     | App Pages, Record Pages, Home Pages               |
| `searchLookup`       | Search lookup backed by a custom controller or the `IF_Search` interface | Flow Screens, App Pages, Home Pages, Record Pages |
| `createForm`         | Dynamic create / edit / clone form driven by a Field Set                 | Flow Screens, App Pages, Home Pages, Record Pages |
| `scheduledJobDetail` | View-only detail for `ScheduledJob__c` records                           | Record Pages (ScheduledJob__c)                    |
| `healthCheck`        | Post-install diagnostics (cache, retention jobs)                         | Home Pages                                        |
| `flowFooter`         | Standardised Back / Next footer for Flow screens                         | Flow Screens                                      |
| `jsonViewer`         | Read-only JSON viewer with syntax highlighting                           | Flow Screens                                      |

The full catalogue, including programmatic building blocks like `sObjectLookup`, lives in the
[LWC Guide](LWC%20-%20Guide.md#appendix-droppable-components-quick-reference). If one of these already does
what you need, you save the whole build. A user who is not a System Administrator and opens a page with `searchLookup`
or `createForm`, or with a component of yours that uses `kern/featureFlag` or `kern/utilityLogger`, needs the
**Kern Component Access** permission set, which grants the Apex classes behind them and the matching Flow actions; the administration tools
(`healthCheck`, `streamingMonitor`) come with the Kern Administrator set instead.

### Honest scope and limitations

- **LWC bundles need a DX project.** You cannot author or edit a Lightning Web Component in the Developer
  Console. The Apex-only Fast Starts let you skip the CLI; this one does not.
- **Components are for presentation, not business logic.** Keep them thin: call Apex through
  `callControllerMethod()` and render the result. Validation, DML, and business rules belong in Apex
  controllers and trigger actions.
- **`kern/featureFlag` is for UX shaping, not authorization.** It serves a cached flag result that can lag a
  permission-set change within a session. Gate hard authorization decisions in the Apex method that performs
  the protected operation, not on the client. See the
  [LWC Guide](LWC%20-%20Guide.md#lds-cache-staleness-not-for-client-side-authorization).
- **Jest cannot resolve managed-package or platform imports on its own.** Every `kern/...`,
  `@salesforce/apex/...`, and `@salesforce/label/...` import must be virtual-mocked in your test.

### Clean up

When you have finished the guide, run these four commands. Run the
first three in this order: the component points at the controller and the label, so it goes first. If you placed the
card on an Account page in Step 3, open that page's **Edit Page** first, remove the card and save, because the org will
not delete a component a page still uses. The Lightning record page you saved with **Edit Page** stays; delete it in
Lightning App Builder if you do not want it, and if you activated the page, remove its activation before you delete
it.

**1. In the terminal**, delete the component:

```shell
sf project delete source -o YourOrgAlias -m "LightningComponentBundle:accountCard" --no-prompt
```

You should see `Status: Succeeded`, then a `Deleted Source` table listing the component's three files.

**2. In the terminal**, delete the two classes:

```shell
sf project delete source -o YourOrgAlias -m "ApexClass:CTRL_AccountCard_TEST" -m "ApexClass:CTRL_AccountCard" --no-prompt
```

You should see `Status: Succeeded`, then a `Deleted Source` table listing the two classes.

**3. In the terminal**, delete the label:

```shell
sf project delete source -o YourOrgAlias -m "CustomLabel:AccountCard_LoadFailed" --no-prompt
```

You should see `Status: Succeeded`, then a `Deleted Source` table listing `AccountCard_LoadFailed`.

**4. In the terminal**, delete the Tier 1 component:

```shell
sf project delete source -o YourOrgAlias -m "LightningComponentBundle:firstKernComponent" --no-prompt
```

You should see `Status: Succeeded`, then a `Deleted Source` table listing the component's three files.

The commands delete those files from your project too: each component's whole folder, the two classes and the label.

Something went wrong? See [Common Issues](#clean-up-1).

---

## Common Issues

Trouble with your computer rather than this guide (`sf` is not recognised, scripts are disabled, you are not logged
in, the wrong folder)? Those are answered once, in
[Set Up Your Computer](Set%20Up%20Your%20Computer.md#if-something-went-wrong).

### Step 1: Create the Apex controller

#### The deploy of the two classes fails

The org you deployed to does not have KernDX installed, so it cannot find `kern.QRY_Builder` or `kern.TST_Builder`.
Install KernDX in that org first (see the [Installation guide](Installation.md)). If you installed KernDX under your
own namespace or without one, change the `kern.` prefix in the code as the namespace note at the top of this guide
explains.

### Step 2: Create the component

#### The pull creates no file

The label's name in Setup does not match the name in the command. The command asks for `AccountCard_LoadFailed`;
check the label's **Name** in Setup (Setup may have filled it in from the short description), fix it, and pull again.

### Step 3: Deploy and drop it on a page

#### `Invalid reference c.AccountCard_LoadFailed of type label`

The component deploy stops with this message, naming the component's JavaScript file, because the org has no label of
that name. Create the label as Step 2 shows, then send the component again.

#### `No MODULE named markup://c:componentBuilder found`

The component imports the base class from `c/`, your own namespace, instead of the managed package. Import it from
`kern/`: `import {ComponentBuilder} from 'kern/componentBuilder'`, then send the component again.

#### A toast or controller call does nothing

The component calls a helper from a module it did not ask for: a toast helper needs the `notification` module, and
`callControllerMethod()` needs the `controller` module. The framework records a guidance error as a log entry, not in
the browser console (see [Client-side logging](#client-side-logging) and
[Fast Start - Logging](Fast%20Start%20-%20Logging.md)). Add the missing module to the `ComponentBuilder(...)` call,
for example `ComponentBuilder('notification', 'controller')`, then send the component again.

#### A freshly deployed change looks like it did nothing

The live session served the cached bundle. Do a full browser page reload to pick up the new bundle.

### Step 5: Run the test

#### Toast or controller call works in the org but Jest can't load the component

The framework base import is unresolved in Jest, because the real `kern/componentBuilder` module is not on your
computer. Add a virtual mock: `jest.mock('kern/componentBuilder', () => ({...}), {virtual: true})`, as the test in
Step 4 does.

#### Jest cannot find a module that starts `@salesforce/apex/` or `@salesforce/label/`

Apex and label imports are resolved by the platform, not found on disk. Virtual-mock each `@salesforce/apex/...` and
`@salesforce/label/...` import, as the test in Step 4 does.

#### Jest starts and never finishes

Node 22.23.x is active. Switch to Node 22.22.3 as Step 5 shows, then run the test again.

### Clean up

#### The component delete fails

A Lightning page still uses the card. Open the Account page's **Edit Page**, remove **accountCard**, save, then run
the first clean-up command again.

Still stuck? [Tell us](https://github.com/JVB-Consulting/kerndx/issues/new?template=bug_report.md&title=%5Bdocs%5D%20LWC) which step and what you saw.

## What You Now Know

| Concept                                                  | What it does                                                         |
|----------------------------------------------------------|----------------------------------------------------------------------|
| `extends ComponentBuilder('module', ...)`                | Creates a KernDX-aware component with the named modules wired in     |
| `import {ComponentBuilder} from 'kern/componentBuilder'` | Imports the base class from the managed-package namespace            |
| `this.showSuccessToast()` / `showErrorToast()`           | Toast helpers from the `notification` module                         |
| `this.callControllerMethod(apexMethod, {params})`        | Calls an `@AuraEnabled` Apex method with framework error handling    |
| `this.consoleLog()` / `this.consoleError()`              | Client-side logging through the framework (error object comes first) |
| `this.dispatchCustomEvent(name, detail)`                 | Dispatches a routed custom event                                     |
| `this.isLoading`                                         | Inherited flag for spinner control                                   |
| `jest.mock('kern/componentBuilder', …, {virtual: true})` | Stand-in base class so the component loads in Jest                   |

**Key patterns:**

- **Extend `ComponentBuilder(...)`, never `LightningElement`:** request only the modules you use
- **Import KernDX modules from `kern/`, your own from `c/`:** the namespace gotcha behind most deploy errors
- **Call Apex through `callControllerMethod()`:** consistent calling convention and error handling
- **All user-facing text comes from Custom Labels:** `@salesforce/label/c.X` in LWC, `System.Label.X` in Apex
- **Virtual-mock every managed-package and platform import in Jest:** the base class, Apex methods, and labels
- **Keep components thin:** presentation in the component, business logic in Apex

---

## Next Steps

- [Server-side persistent logging](Fast%20Start%20-%20Logging.md)
- [Building the Apex controller's queries](Fast%20Start%20-%20Selectors.md)
- [DML from your controller methods](Fast%20Start%20-%20DML.md)
- [Feature flags in the UI](Fast%20Start%20-%20Feature%20Flags.md)
- [Catching LWC anti-patterns automatically](Fast%20Start%20-%20Code%20Scanning.md)
- [Complete LWC developer reference](LWC%20-%20Guide.md)
