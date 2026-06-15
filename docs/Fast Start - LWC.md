# Fast Start - LWC

**Framework:** KernDX | **Total time:** ~30 minutes

> Build Lightning Web Components on the KernDX base class — toast notifications, Apex calls, navigation,
> and structured logging come for free, with no manual mixin plumbing.

**Before you start:**

- [ ] KernDX package installed in your org
- [ ] Org configured post-install — verify with the **Kern** app's Health Check (see [Installation guide](Installation.md#post-install-configuration))
- [ ] A Salesforce DX project on disk (LWC bundles cannot be authored in the Developer Console) — verify with `sf org open -o YourOrgAlias`
- [ ] Node 22 installed for Jest unit tests (`node --version` shows `v22.x`)
- [ ] Working in a sandbox or scratch org (not production)

**What you'll build:** A KernDX-aware Lightning Web Component that calls an Apex controller method, shows a
toast on success or failure, and logs to the browser console through the framework — plus a Jest test that
mocks the framework base class so the component runs in isolation.

**Success looks like:** Your component drops onto a Lightning page, calls Apex, and raises a success toast.
Your Jest test passes with the framework base class mocked out, and the component imports the base from the
managed-package namespace (`kern/componentBuilder`).

**In one line:** `export default class MyComponent extends ComponentBuilder('notification', 'controller') {}`
— every KernDX component extends `ComponentBuilder(...)`, never `LightningElement` directly.

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [The one rule: extend ComponentBuilder](#the-one-rule-extend-componentbuilder)
2. [Tier 1: See It Work (~2 minutes)](#tier-1-see-it-work-2-minutes)
    - [The smallest KernDX component](#the-smallest-kerndx-component)
    - [Add a toast](#add-a-toast)
    - [The namespace gotcha](#the-namespace-gotcha)
3. [Tier 2: Build Your Own (~20 minutes)](#tier-2-build-your-own-20-minutes)
    - [Step 1: Create the Apex controller](#step-1-create-the-apex-controller)
    - [Step 2: Create the component](#step-2-create-the-component)
    - [Step 3: Deploy and drop it on a page](#step-3-deploy-and-drop-it-on-a-page)
    - [Step 4: Write the Jest test](#step-4-write-the-jest-test)
    - [Step 5: Run the test](#step-5-run-the-test)
        - [Key Patterns](#key-patterns)
4. [Tier 3: Reference and Next Steps (~5-10 minutes)](#tier-3-reference-and-next-steps-5-10-minutes)
    - [Choosing modules](#choosing-modules)
    - [What every component inherits](#what-every-component-inherits)
    - [Client-side logging](#client-side-logging)
    - [Custom labels for all UI text](#custom-labels-for-all-ui-text)
    - [Pre-built components you can drop in without code](#pre-built-components-you-can-drop-in-without-code)
    - [Honest scope and limitations](#honest-scope-and-limitations)
5. [Common Issues](#common-issues)
6. [What You Now Know](#what-you-now-know)
7. [Next Steps](#next-steps)

</details>

---

## The one rule: extend ComponentBuilder

Every custom KernDX component extends the result of the `ComponentBuilder(...)` factory instead of
extending `LightningElement` directly:

```javascript
import {ComponentBuilder} from 'kern/componentBuilder';

export default class MyComponent extends ComponentBuilder('notification', 'controller')
{
	// your component
}
```

`ComponentBuilder(...)` returns a base class with the modules you ask for already wired in. You pass module
identifiers — `'notification'`, `'controller'`, `'navigation'`, `'lightning-message'`, `'flow-navigation'`,
or `'all'` — and the matching methods (`showSuccessToast()`, `callControllerMethod()`, and so on) become
available on `this`. Ask only for the modules you use; an unrequested module's method logs a guidance error
instead of running.

> **Why not `LightningElement`?** Extending `LightningElement` directly bypasses the framework's
> notification, controller, navigation, and logging helpers — you would re-implement toasts, Apex error
> handling, and navigation by hand in every component. `ComponentBuilder` with a single module has minimal
> overhead and is the recommended starting point for every custom component.

---

## Tier 1: See It Work (~2 minutes)

> **Heads up — no Developer Console here.** Unlike the Apex Fast Starts, LWC bundles cannot be created in the
> Developer Console's Execute Anonymous window. You need a Salesforce DX project on disk and the `sf` CLI.
> Each component below is a folder under `force-app/main/default/lwc/`.

### The smallest KernDX component

Create a folder `force-app/main/default/lwc/firstKernComponent/` with two files.

`firstKernComponent.js`:

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

`firstKernComponent.html`:

```html
<template>
	<lightning-button label="Try Me" onclick={handleClick}></lightning-button>
</template>
```

`firstKernComponent.js-meta.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<LightningComponentBundle xmlns="http://soap.sforce.com/2006/04/metadata">
	<apiVersion>67.0</apiVersion>
	<isExposed>true</isExposed>
	<targets>
		<target>lightning__AppPage</target>
		<target>lightning__HomePage</target>
		<target>lightning__RecordPage</target>
	</targets>
</LightningComponentBundle>
```

Because the class extends `ComponentBuilder('notification')`, `this.showSuccessToast(...)` already exists —
you did not import `ShowToastEvent` or dispatch it yourself.

### Add a toast

Asking for the `notification` module gives you four ready-made toast helpers plus a custom one:

```javascript
this.showSuccessToast('Record saved');
this.showErrorToast('Something went wrong');
this.showWarningToast('Please review your input');
this.showInfoToast('Working on it…');
```

`showErrorToast` is especially handy: pass it the raw error object straight from a `catch` block and the
framework normalises Apex, Lightning Data Service, and UI API error shapes into a readable message for you.

### The namespace gotcha

This is the single most common mistake when building KernDX components in a subscriber org. **The base class
lives in the managed package, so you import it from the `kern/` namespace, not `c/`:**

```javascript
// CORRECT — the managed package owns the module
import {ComponentBuilder} from 'kern/componentBuilder';

// WRONG in a subscriber org — c/ resolves to your own namespace, not KernDX's
import {ComponentBuilder} from 'c/componentBuilder';
```

The same rule applies to any KernDX LWC module you import — `kern/utilityLogger`, `kern/utilityString`,
`kern/featureFlag`, and so on. Your **own** components still reference each other with `c/` (your namespace);
only the modules that ship inside the KernDX managed package take the `kern/` prefix.

> **Quick test:** if a component fails to compile on deploy with *"No MODULE named markup://c/componentBuilder
> found"*, you imported from `c/` instead of `kern/`. Switch the prefix and redeploy.

> **When to move to Tier 2:** When you want a real component that calls Apex and ships with a Jest test.

---

## Tier 2: Build Your Own (~20 minutes)

Build an Account summary card: it calls an Apex controller to load an Account by ID, shows the name and
industry, and raises a toast if the load fails.

### Step 1: Create the Apex controller

A KernDX LWC component calls server logic through `callControllerMethod()`, which invokes an
`@AuraEnabled` Apex method. Keep the component thin — business logic belongs in Apex, not the component.

Create `force-app/main/default/classes/CTRL_AccountCard.cls`:

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

> **Why `kern.QRY_Builder`?** It enforces field-level security on the query and keeps your controller free of
> inline SOQL. See [Fast Start - Selectors](Fast%20Start%20-%20Selectors.md) for the full query pattern.

### Step 2: Create the component

Create a folder `force-app/main/default/lwc/accountCard/` with these files.

`accountCard.js`:

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

`accountCard.html`:

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

`accountCard.js-meta.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<LightningComponentBundle xmlns="http://soap.sforce.com/2006/04/metadata">
	<apiVersion>67.0</apiVersion>
	<isExposed>true</isExposed>
	<targets>
		<target>lightning__RecordPage</target>
	</targets>
</LightningComponentBundle>
```

**What this code does:**

- `extends ComponentBuilder('notification', 'controller')` — gives the component toast helpers AND
  `callControllerMethod()`
- `import {ComponentBuilder} from 'kern/componentBuilder'` — the base class comes from the managed package
- `this.callControllerMethod(getAccount, {accountId: this.recordId})` — calls the `@AuraEnabled` Apex method,
  passing parameters by name, with framework error handling built in
- `this.showErrorToast(LOAD_FAILED)` — raises an error toast using a Custom Label, not a hardcoded string
- `this.consoleError(error, 'accountCard.connectedCallback')` — logs the error through the framework

> **All displayed text comes from Custom Labels.** `LOAD_FAILED` is imported with
> `import LOAD_FAILED from '@salesforce/label/c.AccountCard_LoadFailed';`. Create the label under
> **Setup > Custom Labels** (name `AccountCard_LoadFailed`, value e.g. *"Could not load the account."*).
> Subscribers can then translate or override it without editing your code.

### Step 3: Deploy and drop it on a page

```bash
sf project deploy start -o YourOrgAlias -m "ApexClass:CTRL_AccountCard" --ignore-conflicts
sf project deploy start -o YourOrgAlias -m "LightningComponentBundle:accountCard" --ignore-conflicts
```

Open any Account record, click the gear icon, choose **Edit Page**, drag **accountCard** from the custom
component list onto the layout, and **Save**. The card loads the Account's name and industry through your
Apex controller.

> **Bundle cache after deploy:** a live Lightning session can keep serving the previously cached bundle when
> you navigate within the app. If a freshly deployed change looks like it did nothing, do a full browser page
> reload to pick up the new bundle.

### Step 4: Write the Jest test

Jest runs your component outside Salesforce, so the real `kern/componentBuilder` module is not on the test
runner's module path. You **mock** it — supplying a stand-in base class that provides the framework methods
your component calls (`callControllerMethod`, `showErrorToast`, `consoleError`). This is the Jest mock the
task description refers to: without it, the import of `kern/componentBuilder` fails to resolve and the test
cannot load your component.

Create `force-app/main/default/lwc/accountCard/__tests__/accountCard.test.js`:

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
> (your namespace) but mock the framework base as `kern/componentBuilder` (the managed-package namespace) —
> exactly matching how the component itself imports it.

### Step 5: Run the test

```bash
. /opt/homebrew/opt/nvm/nvm.sh && nvm use 22
npm run test:unit -- --testPathPattern=accountCard
```

**Expected output:**

```text
PASS  force-app/main/default/lwc/accountCard/__tests__/accountCard.test.js
  c-account-card
    ✓ renders the loaded account name
```

#### Key Patterns

| Pattern                | Example                                                 | Why                                                             |
|------------------------|---------------------------------------------------------|-----------------------------------------------------------------|
| Extend the factory     | `extends ComponentBuilder('notification', ...)`         | Inherits framework helpers; never extend `LightningElement`     |
| Import from `kern/`    | `from 'kern/componentBuilder'`                          | The base class lives in the managed package, not your namespace |
| Call Apex via module   | `this.callControllerMethod(apexMethod, {params})`       | Framework error handling and consistent calling convention      |
| Toast from a `catch`   | `this.showErrorToast(error)`                            | Normalises Apex / LDS / UI API error shapes automatically       |
| Custom Labels for text | `@salesforce/label/c.AccountCard_LoadFailed`            | Translatable, overridable — never hardcode user-facing strings  |
| Virtual-mock the base  | `jest.mock('kern/componentBuilder', …, {virtual:true})` | Resolves the managed-package import inside Jest                 |

---

## Tier 3: Reference and Next Steps (~5-10 minutes)

### Choosing modules

`ComponentBuilder(...)` accepts any combination of these identifiers. Ask for what you use; an unrequested
module's method logs guidance instead of running.

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

Regardless of which modules you request, every component extending `ComponentBuilder(...)` inherits a few
base capabilities:

```javascript
// Dispatch a custom event (the framework routes the real name through the detail payload)
this.dispatchCustomEvent('recordselected', {recordId: '001xx'});

// Loading flag for spinner control
this.isLoading = true;

// Client-side logging through the framework
this.consoleLog('State loaded', this.account);
this.consoleError(error, 'accountCard.connectedCallback');
```

The base class also handles teardown: register cleanup work with `this.addTearDownOperation(fn)` and the
framework runs every registered operation in `disconnectedCallback()` for you.

### Client-side logging

Use the framework logging helpers instead of `console.log` / `console.error`. They route through the
framework's client logger:

```javascript
// Log a labelled value (objects are JSON round-tripped to strip Lightning proxies)
this.consoleLog('User clicked save', {recordId: this.recordId});

// Log an error — note the argument order: the error object comes first
this.consoleError(error, 'accountCard.handleSave');
```

These write to the browser console. For **persistent, queryable** server-side logging that survives the
transaction, call `kern.LOG_Builder` from your Apex controller method — see
[Fast Start - Logging](Fast%20Start%20-%20Logging.md). To correlate a client interaction with the Apex it
triggers, the [LWC Guide](LWC%20-%20Guide.md#utilitylogger---client-side-logging) covers the `utilityLogger`
correlation helpers.

### Custom labels for all UI text

Every string a user sees must come from a Custom Label, never a hardcoded literal — this is what lets
subscribers translate and override your component's copy. The pattern in an LWC is a `@salesforce/label`
import:

```javascript
import SAVE_SUCCESS from '@salesforce/label/c.AccountCard_SaveSuccess';
// ...
this.showSuccessToast(SAVE_SUCCESS);
```

In the matching Apex controller, the equivalent is `System.Label.X`:

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
| `healthCheck`        | Post-install diagnostics (cache, trusted site, retention jobs)           | Home Pages                                        |
| `flowFooter`         | Standardised Back / Next footer for Flow screens                         | Flow Screens                                      |
| `jsonViewer`         | Read-only JSON viewer with syntax highlighting                           | Flow Screens                                      |

The full catalogue, including programmatic building blocks like `sObjectLookup`, lives in the
[LWC Guide](LWC%20-%20Guide.md#appendix-droppable-components-quick-reference).

### Honest scope and limitations

- **LWC bundles need a DX project.** You cannot author or edit a Lightning Web Component in the Developer
  Console. The Apex-only Fast Starts let you skip the CLI; this one does not.
- **Components are for presentation, not business logic.** Keep them thin: call Apex through
  `callControllerMethod()` and render the result. Validation, DML, and business rules belong in Apex
  controllers and trigger actions.
- **`kern/featureFlag` is for UX shaping, not authorization.** It serves a cached flag result that can lag a
  permission-set change within a session. Gate hard authorization decisions in the Apex method that performs
  the protected operation, not on the client. See the
  [LWC Guide](LWC%20-%20Guide.md#lds-cache-staleness--not-for-client-side-authorization).
- **Jest cannot resolve managed-package or platform imports on its own.** Every `kern/...`,
  `@salesforce/apex/...`, and `@salesforce/label/...` import must be virtual-mocked in your test.

---

## Common Issues

| Problem                                                                     | Cause                                                     | Fix                                                                                                 |
|-----------------------------------------------------------------------------|-----------------------------------------------------------|-----------------------------------------------------------------------------------------------------|
| Deploy fails: *No MODULE named markup://c/componentBuilder*                 | Imported the base from `c/` in a subscriber org           | Import from the managed-package namespace: `import {ComponentBuilder} from 'kern/componentBuilder'` |
| `showSuccessToast is not a function`                                        | The `notification` module was not requested               | Add `'notification'` to `ComponentBuilder('notification', ...)`                                     |
| `callControllerMethod` logs a guidance error and does nothing               | The `controller` module was not requested                 | Add `'controller'` to the `ComponentBuilder(...)` call                                              |
| Toast or controller call works in the org but Jest can't load the component | The framework base import is unresolved in Jest           | Add a virtual mock: `jest.mock('kern/componentBuilder', () => ({...}), {virtual: true})`            |
| Jest: *Cannot find module '@salesforce/apex/...'*                           | Apex and label imports are platform-resolved, not on disk | Virtual-mock each `@salesforce/apex/...` and `@salesforce/label/...` import                         |
| A freshly deployed change looks like it did nothing                         | The live session served the cached bundle                 | Do a full browser page reload to pick up the new bundle                                             |
| User-facing text can't be translated                                        | A string literal was hardcoded in markup or JS            | Import the text from a Custom Label (`@salesforce/label/c.X`) and reference the import              |
| `consoleError` logs the wrong thing                                         | Arguments passed in the wrong order                       | Call `this.consoleError(errorObject, 'Class.method')` — the error object is the **first** argument  |

---

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

- **Extend `ComponentBuilder(...)`, never `LightningElement`** — request only the modules you use
- **Import KernDX modules from `kern/`, your own from `c/`** — the namespace gotcha behind most deploy errors
- **Call Apex through `callControllerMethod()`** — consistent calling convention and error handling
- **All user-facing text comes from Custom Labels** — `@salesforce/label/c.X` in LWC, `System.Label.X` in Apex
- **Virtual-mock every managed-package and platform import in Jest** — the base class, Apex methods, and labels
- **Keep components thin** — presentation in the component, business logic in Apex

---

## Next Steps

| Topic                                    | Link                                                                |
|------------------------------------------|---------------------------------------------------------------------|
| Server-side persistent logging           | [Fast Start - Logging](Fast%20Start%20-%20Logging.md)               |
| Building the Apex controller's queries   | [Fast Start - Selectors](Fast%20Start%20-%20Selectors.md)           |
| DML from your controller methods         | [Fast Start - DML](Fast%20Start%20-%20DML.md)                       |
| Feature flags in the UI                  | [Fast Start - Feature Flags](Fast%20Start%20-%20Feature%20Flags.md) |
| Catching LWC anti-patterns automatically | [Fast Start - Code Scanning](Fast%20Start%20-%20Code%20Scanning.md) |
| Complete LWC developer reference         | [LWC - Guide](LWC%20-%20Guide.md)                                   |
