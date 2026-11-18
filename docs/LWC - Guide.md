---
navOrder: 30
navLabel: "LWC (Lightning web components)"
movedAnchors: {"access-to-the-packages-apex-classes": "/lwc-guide#access-to-the-apex-classes-behind-a-page", "why-choose-this-over-the-built-in-option": "/#lwc", "how-does-this-compare-to-standard-lwc-development": "/#lwc"}
---

# LWC - Guide

**Who this page is for:** developers who build [Lightning Web Components](https://developer.salesforce.com/docs/platform/lwc/guide)
with KernDX's base classes, utilities and pre-built components, faster and more consistently; architects who design
component architectures with clean separation of concerns and reusable patterns; and business analysts who assemble
pages from the pre-built components and need to know their configuration options.

New to it? Try [Fast Start - LWC](Fast%20Start%20-%20LWC.md) first. Deciding whether to use KernDX? See
[Why KernDX](Strategic%20Guide%20-%20Overview.md).

## Copy this first

```javascript
import {ComponentBuilder} from 'kern/componentBuilder';
import saveRecord from '@salesforce/apex/MyController.saveRecord';
import RECORD_SAVED from '@salesforce/label/c.MyComponent_RecordSaved';

export default class MyComponent extends ComponentBuilder('notification', 'controller')
{
	async handleSave()
	{
		const recordId = await this.callControllerMethod(saveRecord, {record: this.record});
		if(recordId)
		{
			this.showSuccessToast(RECORD_SAVED);
		}
	}
}
```

**What this does:** builds a component with toasts and Apex calls already wired in. `handleSave()` calls your Apex
method `saveRecord` with the record and waits for it. People who use the component need access to your `MyController`
Apex class, through their profile or a permission set.

- Your `saveRecord` method must return a value, for example the Id of the record it saved. `callControllerMethod` gives
  that value back.
- When the save works, the Id is there, so the component shows a success toast.
- When the save fails, `callControllerMethod` does not throw. It logs the error, shows an error toast and gives back
  `undefined`, so no success toast appears.
- A method that returns nothing gives back no value when it works either, so the success toast would never appear. For
  such a method, pass `{isThrow: true}` and use `try` and `catch`, as the sample under
  [ComponentBuilder Pattern](#componentbuilder-pattern) shows.

The toast text comes from a custom label of your own, `MyComponent_RecordSaved` (for example, "Record saved
successfully"). Create the label in your org before you deploy the component: the component does not deploy without
it. The Fast Start - LWC section [Create the component](Fast%20Start%20-%20LWC.md#step-2-create-the-component) shows
the steps. A label lets your org translate the text or change it without a code change, so never type text a user
reads into the code.

**Read next:** [Every feature you can add](#what-modules-can-i-include), [Ready-made helper functions](#utility-modules),
[Methods your component gets](#basecomponent-api-reference), [Test your component](#testing).

---

## Quick Navigation

| I need to...                                                          | Go to...                                                                          |
|-----------------------------------------------------------------------|-----------------------------------------------------------------------------------|
| Place a ready-made component on a page or a Flow screen, mostly with no code | [Appendix: Droppable Components](#appendix-droppable-components-quick-reference)  |
| Choose which features my component gets                               | [What modules can I include?](#what-modules-can-i-include)                        |
| Give users access to the Apex classes behind a page                   | [Access to the Apex classes behind a page](LWC%20-%20Guide.md#access-to-the-apex-classes-behind-a-page) |
| Call Apex from a component                                            | [Controller Methods](#controller-methods)                                         |
| Show a toast                                                          | [Notification Methods](#notification-methods)                                     |
| Open a record page from a component                                   | [Navigation Methods](#navigation-methods)                                         |
| Send messages between components                                      | [Lightning Message Service Methods](#lightning-message-service-methods)           |
| Move a Flow screen on or back from a component                        | [Flow Navigation Methods](#flow-navigation-methods)                               |
| Look up every method and property a component gets                    | [BaseComponent API Reference](#basecomponent-api-reference)                       |
| Use the helper functions (strings, arrays, IDs, the clipboard)        | [Utility Modules](#utility-modules)                                               |
| Log from a component and link it to the Apex logs                     | [utilityLogger - Client-Side Logging](#utilitylogger---client-side-logging)       |
| Turn an Apex error into a readable message                            | [Reduce Errors](#reduce-errors)                                                   |
| Check a feature flag in a component                                   | [featureFlag - Feature Flag Bridge](#featureflag---feature-flag-bridge)           |
| Find the Flow screen components                                       | [Flow Screen Components](#flow-screen-components)                                 |
| Build a record form from a field set                                  | [createForm - Dynamic Record Forms](#createform---dynamic-record-forms)           |
| Watch the events flowing through your org, live                       | [streamingMonitor - Event Monitoring](#streamingmonitor---event-monitoring)       |
| Check the package is set up after install                             | [healthCheck - Post-Install Diagnostics](#healthcheck---post-install-diagnostics) |
| Write Jest tests                                                      | [Testing](#testing)                                                               |
| Stand in for KernDX modules in a Jest test                            | [Mocking KernDX Modules](#mocking-kerndx-modules)                                 |
| Fix a component that does not work                                    | [Troubleshooting](#troubleshooting)                                               |
| Understand component architecture                                     | [Base Component Architecture](#base-component-architecture)                       |
| Understand how the pieces fit together                                | [How does it work?](#how-does-it-work)                                            |
| See every component in the package                                    | [Complete Component Inventory](#complete-component-inventory)                     |
| See why KernDX is worth using                                         | [Why KernDX: the LWC example](/#lwc)                                              |

---

## Quick Start

Pick the shape that fits your screen:

| What you need | What to do |
|---|---|
| A custom component | Extend `ComponentBuilder` and list the features you want: the sample below, or the one under [Copy this first](#copy-this-first) |
| A common screen (a record form, a Flow footer, an event monitor, a search lookup) | Place a ready-made component through Lightning App Builder or Flow Builder, with no code: [Appendix: Droppable Components](#appendix-droppable-components-quick-reference). The search lookup is the one exception: it needs an Apex class of yours that implements [`IF_Search`](reference/apex/IF_Search.md), named in its required `controllerName` property |
| A small task inside your component (logging, formatting a string, sorting an array) | Import a helper function: [Utility Modules](#utility-modules) |

```javascript
import {ComponentBuilder} from 'kern/componentBuilder';
import saveRecord from '@salesforce/apex/MyController.saveRecord';
import RECORD_SAVED from '@salesforce/label/c.MyComponent_RecordSaved';

export default class MyComponent extends ComponentBuilder('notification', 'controller')
{
	async handleSave()
	{
		const recordId = await this.callControllerMethod(saveRecord, {record: this.record});
		if(recordId)
		{
			this.showSuccessToast(RECORD_SAVED);
		}
	}
}
```

> **Namespaces in code samples:** `kern.` on a class and `kern__` on an object, field, or metadata type mark the managed package's namespace.
> On the managed package, framework references need those prefixes even where a sample omits them; repackaged under your own namespace, replace `kern`/`kern__`
> with your prefix; on an unmanaged deploy, drop them. See [How to read the code samples](Installation.md#how-to-read-the-code-samples).

`ComponentBuilder('notification', 'controller')` gives your component toast notifications and a clean way to call Apex.
Need more? Add `'navigation'` for record-page navigation, or pass `'all'` to include every feature. The KernDX rule:
build every new component on `ComponentBuilder`, not on `LightningElement` directly, so they all share the same wiring.

### Access to the Apex classes behind a page

**Set up access before anyone but a System Administrator opens a page built on `ComponentBuilder` or the package's components.** The package's modules and components call Apex classes in the package, and a user
needs access to those classes. Give it in one of these ways:

- Assign the **Kern Component Access** permission set to every user of such a page. It grants the classes behind `kern/featureFlag`, `kern/utilityLogger`,
  `searchLookup`, `createForm` and `sObjectLookup`, and the Apex classes and Flow actions those components use (see the permission set).
- Or add Apex class access for the component's controller to a permission set they already have.
- A user with **Kern Administrator** already has all of this access.

---

## What problem does this solve?

Every Lightning Web Component (LWC) you build needs the same repetitive plumbing: toast notifications, Apex calls with error handling, navigation, and logging that survives a page reload. Re-writing that wiring in each component is slow and easy to get inconsistent.

This part of KernDX gives you that plumbing once:

- a base class you extend, with the features you list already wired in;
- a set of ready-to-use helper functions;
- drop-on-the-page components (search lookups, forms, an event monitor) you can use without writing code at all.

Use it whenever you create a custom LWC. Where a ready-made component, or a standard Lightning base component, already does the job, you just place it.

## Mental model

Think of `ComponentBuilder` as ordering a car with the options you want. You pick the features you need (toasts, Apex calls, navigation, messaging, Flow control), and you drive away in a component that already has them fitted, rather than bolting each one on by hand.

The utility modules are the toolkit in the boot: small, separate tools you use when a job needs them.

## Use this when

- You are building a custom LWC and want toasts, Apex calls, navigation, or logging without re-wiring them each time. Extend `ComponentBuilder` and list the features you need.
- You want client-side logs that are kept and searchable, and that line up with the matching Apex logs for one user action.
- You need a common screen (a search lookup, a record form, a Flow footer, an event monitor) and would rather configure a finished component than build one.
- You want every component in your org to share the same conventions, so the codebase stays consistent as it grows.

## Don't use this when

KernDX is opinionated here: every custom component you write extends `ComponentBuilder`, even with a single feature. The cost is small, and it keeps your components consistent. You skip it only when you write no component at all:

- A standard Lightning base component already does the job. If `lightning-record-form` or another built-in covers your screen, just place it; there is nothing to extend.
- You only need to drop a single ready-made component on a page. Configure it through Lightning App Builder; no custom code is involved.

---

## Base Component Architecture

You pick the capabilities you want, and KernDX hands you a base class that already includes them. You list the features; you extend the result.

Most components need the same handful of capabilities: showing a toast, calling Apex, navigating to a record, talking to sibling components, driving a Flow. Writing that wiring by hand in every component is repetitive and drifts out of sync over time.

The helper functions in [Utility Modules](#utility-modules) (logging, string formatting, arrays) are separate: you import them wherever you need them.

### ComponentBuilder Pattern

`ComponentBuilder` is the factory that does this. You call it with the feature modules you want, and it returns a base class with those mixed in.

**Import:**

```javascript
import {ComponentBuilder} from 'kern/componentBuilder';
```

**Basic Usage:**

The JavaScript samples in this guide take toast and message text from custom labels of your own, such as
`MyComponent_AccountsLoaded`. Create each label in your org before you deploy the component, as
[Copy this first](#copy-this-first) explains. The HTML samples and the string-helper samples type short text in to
stay short. In your own component, take that text from a label too.

```javascript
import {ComponentBuilder} from 'kern/componentBuilder';
import getAccounts from '@salesforce/apex/AccountController.getAccounts';
import ACCOUNTS_LOADED from '@salesforce/label/c.MyComponent_AccountsLoaded';
import LOAD_FAILED from '@salesforce/label/c.MyComponent_LoadFailed';

// Include specific modules
export default class MyComponent extends ComponentBuilder('notification', 'controller')
{
	// Component now has notification and controller methods available

	async handleClick()
	{
		try
		{
			// isThrow makes a failed call throw, so the catch below runs; silent skips the generic error toast
			const result = await this.callControllerMethod(getAccounts, {}, {isThrow: true, silent: true});
			this.showSuccessToast(ACCOUNTS_LOADED);
		}
		catch (error)
		{
			this.showErrorToast(LOAD_FAILED);
		}
	}
}
```

**Include All Modules:**

```javascript
import {ComponentBuilder} from 'kern/componentBuilder';

export default class FullFeaturedComponent extends ComponentBuilder('all')
{
	// All modules available: notification, navigation, lightning-message, controller, flow-navigation
}
```

**Wire adapters work as usual.** A wire adapter is the platform's way to send data to a component, so you do not call
for it yourself. `getRecord` and a cacheable Apex method are examples.

- Put `@wire` (imported from `lwc`) on a property or a method. The platform sends the data, and sends it again when
  one of the adapter's inputs changes.
- A `ComponentBuilder` component is still a Lightning web component, so `@wire` works the same way in it.
- The `controller` module adds `handleWireResponse()`. Call it in your wired method with the result. It returns the
  data, or `undefined` while there is no data yet. On an error it logs the error, shows an error toast and returns
  `undefined`.

See the sample in [Controller Methods](#controller-methods).

### What modules can I include?

| Module              | Functionality Included                                                                                                                                                                                    |
|---------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `notification`      | [Toast](https://developer.salesforce.com/docs/platform/lwc/guide/use-toast.html) notifications: `showSuccessToast()`, `showErrorToast()`, `showWarningToast()`, `showInfoToast()`, `customNotification()` |
| `navigation`        | Page [navigation](https://developer.salesforce.com/docs/platform/lwc/guide/use-navigate.html): `redirectToRecordPage()`, `generateRecordPageURL()`                                                        |
| `lightning-message` | [LMS](https://developer.salesforce.com/docs/platform/lwc/guide/use-message-channel.html): `addMessageChannelSubscription()`, `publishLightningMessage()`, `clearSubscriptions()`                          |
| `controller`        | [Apex calls](https://developer.salesforce.com/docs/platform/lwc/guide/apex.html): `callControllerMethod()`, `handleWireResponse()`                                                                        |
| `flow-navigation`   | [Flow events](https://developer.salesforce.com/docs/platform/lwc/guide/use-flow.html): `dispatchFlowNextEvent()`, `dispatchFlowBackEvent()`, `dispatchFlowFinishEvent()`                                  |
| `all`               | All of the above                                                                                                                                                                                          |

### How Modules Work

> **Note:** You only ever call `ComponentBuilder`; the other names here are its internal wiring, shown so the behaviour isn't a mystery, as [What you actually use](#component-categories) says.

Here is the mechanism in plain terms. When you list modules in `ComponentBuilder`, each one adds its methods straight onto your component instance as the component is created. So by the time your code runs, the methods are simply there to call.

#### Module Architecture

```text
+---------------------------------------------------------------------------+
|  ComponentBuilder('notification', 'controller')                           |
|                         |                                                 |
|                         v                                                 |
|  +---------------------------------------------------------------------+ |
|  | Creates new class extending baseComponent                           | |
|  |                                                                     | |
|  |  constructor() {                                                    | |
|  |    componentExtender(this, 'notification', 'controller')            | |
|  |  }                                                                  | |
|  +---------------------------------------------------------------------+ |
|                         |                                                 |
|                         v                                                 |
|  +---------------------------------------------------------------------+ |
|  | componentExtender calls each module's initialiser:                  | |
|  |                                                                     | |
|  |  initialiseNotificationModule(this)                                 | |
|  |    -> this.showSuccessToast = function() {...}                      | |
|  |    -> this.showErrorToast = function() {...}                        | |
|  |    -> this.customNotification = function() {...}                    | |
|  |                                                                     | |
|  |  initialiseControllerModule(this)                                   | |
|  |    -> this.callControllerMethod = function() {...}                  | |
|  |    -> this.handleWireResponse = function() {...}                    | |
|  +---------------------------------------------------------------------+ |
|                         |                                                 |
|                         v                                                 |
|  Your component now has: showSuccessToast(), showErrorToast(),            |
|  customNotification(), callControllerMethod(), handleWireResponse()       |
+---------------------------------------------------------------------------+
```

#### Module Files

Each module is a separate JavaScript file that exports an initialiser function:

| File                              | Export                                        | Purpose                                                                           |
|-----------------------------------|-----------------------------------------------|-----------------------------------------------------------------------------------|
| `kern/moduleNotification`            | `initialiseNotificationModule(component)`     | Adds toast methods                                                                |
| `kern/moduleNavigation`              | `initialiseNavigationModule(component)`       | Adds navigation methods                                                           |
| `kern/moduleLightningMessageService` | `initialiseLightningMessageModule(component)` | Adds LMS methods                                                                  |
| `kern/moduleController`              | `initialiseControllerModule(component)`       | Adds Apex call methods                                                            |
| `kern/moduleFlowNavigation`          | `initialiseFlowNavigationModule(component)`   | Adds Flow event methods                                                           |
| `kern/componentExtender` (internal)  | `componentExtender(component, ...modules)`    | Orchestrates module loading (used by `ComponentBuilder`; do not import directly) |

#### Why This Pattern?

Why build it this way rather than one giant base class? Four reasons, each with a benefit for you:

1. **You load only what you use.** Include just the features a component needs, so it carries no dead weight.
2. **No deep inheritance chain to reason about.** Unlike traditional mixins, the methods are added straight onto the instance.
3. **Each piece is easy to test.** Every module can be tested on its own.
4. **It isn't locked to one base class.** The pattern works with any LWC base class.

#### When to Use Which Modules

| Scenario                              | Recommended Modules               |
|---------------------------------------|-----------------------------------|
| Simple form with save confirmation    | `notification`                    |
| Record page with navigation           | `notification`, `navigation`      |
| Component communicating with siblings | `lightning-message`               |
| Data loading from Apex                | `controller`, `notification`      |
| Flow screen component                 | `notification`, `flow-navigation` |
| Full-featured component               | `all`                             |

#### Extending at Runtime (Advanced: Internal API)

> **For a rare edge case only:** almost always you list your modules up front in `ComponentBuilder(...)` and you are done. The pattern below is for the unusual case where a module has to be added later, after the component is already built, based on a runtime condition.

The sample below imports `componentExtender`, the internal piece that `ComponentBuilder` is built on. It is exposed, but it is internal: it is not meant to be imported directly, and it may change without notice. Prefer listing the module up front in `ComponentBuilder(...)`, even if some instances never use it. The sample only shows what happens inside the framework:

```javascript
// Internal: shown for explanation only, not for use in your own components
import {componentExtender} from 'kern/componentExtender';

connectedCallback()
{
	// Add navigation module if condition is met
	if (this.enableNavigation)
	{
		componentExtender(this, 'navigation');
	}
}
```

#### Performance Consideration

`'all'` is convenient, but it sets up all 5 modules whether you use them or not. When a component is performance-sensitive, for example one rendered many times in a list, list only the modules you actually use instead.

### BaseComponent API Reference

Once your component extends `ComponentBuilder`, these methods and properties are available to call.

#### Notification Methods

```javascript
import RECORD_SAVED from '@salesforce/label/c.MyComponent_RecordSaved';
// SAVE_FAILED and the other names in capitals are custom labels of your own too, imported the same way

// Simple toasts
this.showSuccessToast(RECORD_SAVED);
this.showErrorToast(SAVE_FAILED);
this.showWarningToast(PLEASE_REVIEW);
this.showInfoToast(WORKING);

// Custom notification: (title, message, variant, messageData, mode)
this.customNotification(NOTICE_TITLE, NOTICE_MESSAGE, 'success', [], 'dismissible');

// Factory for complex notifications: (variant, mode) returns (message, title, messageData)
const notify = this.customNotificationFactory('error', 'sticky');
notify(NOTICE_MESSAGE, NOTICE_TITLE);
```

#### Navigation Methods

```javascript
// Navigate to record
this.redirectToRecordPage(recordId);

// Generate URL without navigating
const url = await this.generateRecordPageURL(recordId);
```

#### Lightning Message Service Methods

```javascript
// Subscribe to channel
this.addMessageChannelSubscription(CHANNEL, (message) =>
{
	this.consoleLog('Received:', message);
});

// Publish message
this.publishLightningMessage(CHANNEL, {data: 'payload'});

// Clean up (call in disconnectedCallback)
this.clearSubscriptions();
```

#### Controller Methods

```javascript
// Call Apex method (getAccountData is imported from '@salesforce/apex/AccountController.getAccountData')
// On failure it logs, shows an error toast and returns undefined; pass {isThrow: true} as a third argument to make it throw instead
const result = await this.callControllerMethod(getAccountData, {
	accountId: this.recordId
});

// Handle wire response: returns the data, or undefined after logging and showing the error
@wire(getRecord, {recordId: '$recordId', fields: FIELDS})
wiredRecord(result)
{
	this.account = this.handleWireResponse(result);
}
```

**Return a small result class from a controller method rather than a raw record where you can**, the way the framework's
own controllers do. A result class carries exactly the fields the component uses, all of them part of the public API, so
it cannot lose one to this platform change:

- From Spring '27 the platform strips non-public system fields from custom-object records returned by Aura actions, the
  calls that carry a Lightning web component's `@AuraEnabled` requests as well.
- The change is the Remove Non-Public Fields from Custom Object Data in Aura Action Responses release update, available
  since Summer '26. It asks you to review every Lightning component that processes custom-object data.
- A component that reads such a field from a returned record can show missing data or fail with a JavaScript error.

#### Flow Navigation Methods

```javascript
// Navigate forward
this.dispatchFlowNextEvent();

// Navigate back
this.dispatchFlowBackEvent();

// Finish flow
this.dispatchFlowFinishEvent();
```

#### Utility Methods

```javascript
// Dispatch custom event
this.dispatchCustomEvent('recordselected', {recordId: '001xx'});

// Logging (uses utilityLogger internally)
this.consoleLog('Debug message');
this.consoleError(error, 'MyComponent.handleSave'); // the error object comes first
```

#### Properties

```javascript
this.isLoading  // Boolean for spinner control
this.messageContext  // LMS context (injected by framework)
this.activeMessageSubscriptions  // Array of active LMS subscriptions
```

---

## Utility Modules

These are small, ready-made functions for the chores that come up in nearly every component: logging, formatting strings, working with arrays, copying to the clipboard, generating IDs. You import the one you need and call it. They are not page components, so you can't drop them on a page; you use them inside the components you build.

### utilityLogger - Client-Side Logging

`utilityLogger` gives you a record of what happened on the screen, kept and searchable, not a `console.log` that vanishes on refresh. Its client-side logs are:

- saved to Apex;
- timed for performance;
- tied to the matching server-side logs, so a single user action reads as one story.

It links those entries with a correlation ID: one tracking ID that follows a single user action across the client and server (the same idea is described in the [Logging guide](Logging%20-%20Guide.md)).

**Import:**

```javascript
import utilityLogger, {LogLevel} from 'kern/utilityLogger';
// Or import specific functions
import {debug, info, warn, error, startCorrelation, startTimer} from 'kern/utilityLogger';
```

#### Log Level Constants

```javascript
LogLevel.DEBUG  // Detailed debugging information
LogLevel.INFO   // General informational messages
LogLevel.WARN   // Warning conditions
LogLevel.ERROR  // Error conditions
```

#### Basic Logging

```javascript
import {debug, info, warn, error} from 'kern/utilityLogger';

// Simple messages
debug('Component initialised');
info('User selected record', {recordId: '001xx'});
warn('Approaching limit', {current: 95, max: 100});
error('Operation failed', {error: err.message});

// With data objects
info('Account loaded', {
	accountId: account.Id,
	accountName: account.Name,
	loadTime: performance.now()
});
```

#### Correlation Tracking

When one user action triggers several log entries, on the client and then on the server, a correlation ID ties them together so you can read them as a single trail. Here is how to start and end one by hand.

```javascript
import {startCorrelation, endCorrelation, getCorrelationId, info, error} from 'kern/utilityLogger';

// Manual correlation management
async handleSave()
{
	const correlationId = startCorrelation('Save Account');
	try
	{
		info('Starting save operation');
		await saveAccount({record: this.account, correlationId});
		info('Save completed successfully');
	}
	catch (err)
	{
		error('Save failed', {error: err.message});
	}
	finally
	{
		endCorrelation(); // Flushes logs to server
	}
}
```

#### Automatic Correlation with withCorrelation

```javascript
import {withCorrelation} from 'kern/utilityLogger';

// Wraps async operation with automatic correlation start/end
async handleSave()
{
	const result = await withCorrelation('Save Account', async (correlationId) =>
	{
		// All logs within this block share the correlation ID
		return await saveAccount({record: this.account, correlationId});
	});
}
```

#### Performance Timing

```javascript
import {startTimer, info} from 'kern/utilityLogger';

async loadData()
{
	const timer = startTimer('Data Load');

	const accounts = await getAccounts();
	const contacts = await getContacts();

	const duration = timer.stop({
		accountCount: accounts.length,
		contactCount: contacts.length
	});
	// Logs: "[PERF] Data Load: 234ms" with additional data
}
```

#### Server Integration

You don't have to send logs to the server yourself. The framework flushes them to Apex automatically at three moments:

- when you call `endCorrelation()`,
- when you log an `error()` (sent immediately), and
- when the in-memory buffer reaches 20 entries.

On the server side, the framework sets the matching correlation context through [`LOG_Builder`](reference/apex/LOG_Builder.md), so your LWC logs land in `LogEntry__c` already linked to the related Apex logs. Each entry keeps:

- the context object you pass (`ContextData__c`);
- the JavaScript stack trace, when you log an `Error` (`StackTrace__c`).

So the [Log Console](Logging%20-%20Guide.md#the-log-console) detail drawer shows exactly what the client saw. When you investigate a problem later, the client and server halves of the same action are already stitched together.

---

### utilityString - String Manipulation

Ready-made string helpers so you don't reinvent them: fill placeholders in a template, fix capitalisation, insert separators (for card or phone numbers), and format currency.

**Import:**

```javascript
import {
	formatTemplateString,
	convertToSentenceCase,
	insertCharacterAtInterval,
	formatStringToCurrency,
	CAPITAL_LETTERS,
	LOWER_CASE_LETTERS,
	DIGITS,
	EMPTY,
	SPACE,
	COMMA,
	NEW_LINE
} from 'kern/utilityString';
```

#### Template String Formatting

```javascript
// Positional placeholders
const message = formatTemplateString(
	'Hello {0}, your balance is {1}',
	['John', '$1,000']
);
// Result: "Hello John, your balance is $1,000"

// Multiple occurrences of same placeholder
const greeting = formatTemplateString(
	'{0} said hello to {1}. {1} replied to {0}.',
	['Alice', 'Bob']
);
// Result: "Alice said hello to Bob. Bob replied to Alice."
```

#### Case Conversion

```javascript
// Convert to sentence case (first letter of each sentence capitalised)
const text = convertToSentenceCase('hello WORLD. how ARE you?');
// Result: "Hello world. How are you?"
```

#### Character Insertion

```javascript
// Insert spaces for readability (e.g., credit card formatting)
const cardNumber = insertCharacterAtInterval('4111111111111111', 4, ' ');
// Result: "4111 1111 1111 1111"

// Phone number formatting
const phone = insertCharacterAtInterval('0821234567', 3, '-');
// Result: "082-123-456-7"
```

#### Currency Formatting

```javascript
// Format with currency symbol and thousands separator
const amount = formatStringToCurrency(1234567.89, 'R');
// Result: "R 1,234,567.89"

const usd = formatStringToCurrency(50000, '$');
// Result: "$ 50,000.00"
```

#### Constants

```javascript
CAPITAL_LETTERS  // 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
LOWER_CASE_LETTERS  // 'abcdefghijklmnopqrstuvwxyz'
DIGITS  // '0123456789'
EMPTY   // ''
SPACE   // ' '
COMMA   // ','
SEMI_COLON  // ';'
COLON   // ':'
NEW_LINE  // '\n'
CRLF    // '\r\n'
TAB     // '\t'
TILDE   // '~'
```

---

### utilityArray - Array Operations

Helpers for reshaping a list of records: group them by a field, pull out only the ones matching a set of IDs, or filter to a single ID.

**Import:**

```javascript
import {
	convertObjectArrayToObject,
	extractListOfObjectsById,
	filterObjectListById
} from 'kern/utilityArray';
```

#### Convert Array to Keyed Object

```javascript
const accounts = [
	{Id: '001A', Name: 'Acme', Type: 'Customer'},
	{Id: '001B', Name: 'Beta', Type: 'Partner'},
	{Id: '001C', Name: 'Gamma', Type: 'Customer'}
];

// Group by field value
const accountsByType = convertObjectArrayToObject(accounts, 'Type');
// Result: {
//   'Customer': [{Id: '001A', ...}, {Id: '001C', ...}],
//   'Partner': [{Id: '001B', ...}]
// }

// Single record per key (last wins)
const accountsById = convertObjectArrayToObject(accounts, 'Id');
// Result: {'001A': {...}, '001B': {...}, '001C': {...}}
```

#### Extract Objects by ID

```javascript
const allRecords = [{Id: '001A', ...}, {Id: '001B', ...}, {Id: '001C', ...}];
const selectedIds = ['001A', '001C'];

const selected = extractListOfObjectsById(allRecords, selectedIds);
// Result: [{Id: '001A', ...}, {Id: '001C', ...}]
```

#### Filter Objects by ID

```javascript
const records = [{Id: '001A', ...}, {Id: '001B', ...}];

const filtered = filterObjectListById(records, '001A');
// Result: [{Id: '001A', ...}]
```

---

### utilitySystem - System Utilities

Lower-level helpers for working with the page and with data: copy to the clipboard, turn a messy Salesforce error into one readable sentence, set or flatten object properties, and sort a list of objects.

**Import:**

```javascript
import {
	copyToClipBoard,
	reduceErrors,
	setPropertyOnObject,
	flattenObject,
	sortBy
} from 'kern/utilitySystem';
```

#### Copy to Clipboard

```javascript
// Copy text to user's clipboard
await copyToClipBoard('Text to copy');
```

#### Reduce Errors

Salesforce throws errors in many different shapes (Apex exceptions, wire-adapter errors, HTTP failures, plain strings). `reduceErrors` flattens any of them into one human-readable string, so you don't have to write a different unwrapping path for each.

```javascript
const reduced = reduceErrors(error);

// Handles:
// - Standard JavaScript Error objects
// - Apex AuraHandledException error bodies
// - LDS / Wire adapter errors (body.fieldErrors object-keyed by field API name,
//   body.pageErrors, body.duplicateResults, body.message)
// - UI API errors (body.output.errors[], body.output.fieldErrors{})
// - HTTP status/statusText fallbacks
// - Plain strings or arrays of any of the above
```

In most cases you don't need to call `reduceErrors` yourself. Pass the raw error
straight into `showErrorToast` and the notification module cleans it up for you (a string you pass is shown unchanged):

```javascript
catch (error)
{
	this.showErrorToast(error);
}
```

Call `reduceErrors` directly only when you need that clean string somewhere other than a toast: for logging,
analytics, or inline error text on the page, for example.

#### Set Property on Object

```javascript
const obj = {existing: 'value'};
setPropertyOnObject(obj, 'newProp', 'newValue');
// obj is now {existing: 'value', newProp: 'newValue'}
```

#### Flatten Object

```javascript
const nested = {
	user: {
		name: 'John',
		address: {
			city: 'London'
		}
	}
};

const flat = flattenObject(nested);
// Result: {'user.name': 'John', 'user.address.city': 'London'}
```

#### Sort Array of Objects

```javascript
const users = [{name: 'Charlie'}, {name: 'Alice'}, {name: 'Bob'}];

const sorted = sortBy(users, 'name');
// Result: [{name: 'Alice'}, {name: 'Bob'}, {name: 'Charlie'}]

// Descending
const descending = sortBy(users, 'name', 'desc');
```

---

### utilityRandom - Random Generation

When you need a unique ID or a random string (a UUID, a one-time code, a test value), these functions produce one for you.

**Import:**

```javascript
import {
	generateUUID,
	getRandomAlphaNumericString,
	getRandomAlphaString,
	getRandomNumericString
} from 'kern/utilityRandom';
```

#### Generate UUID

```javascript
const uuid = generateUUID();
// Result: "550e8400-e29b-41d4-a716-446655440000" (v4 format)

// Uses crypto.randomUUID() when available, falls back to manual generation
```

#### Random Strings

```javascript
// Alphanumeric (letters and digits)
const code = getRandomAlphaNumericString(8);
// Result: "aB3xK9mP"

// Letters only
const alpha = getRandomAlphaString(6);
// Result: "AbCdEf"

// With case options
const upper = getRandomAlphaString(6, {uppercase: true});
// Result: "ABCDEF"

const lower = getRandomAlphaString(6, {lowercase: true});
// Result: "abcdef"

// Numeric only
const numeric = getRandomNumericString(4);
// Result: "7294"
```

---

### utilityGenerator - Generator Functions

Helpers for counting and stepping through a list on demand: a counter that produces the next number each time you ask, and a generator that walks an array forward, backward, or over part of it.

This module is internal to the package: it is not exposed, so your own components cannot import it, and the package offers no exposed module in its place. The
examples below show what the package's own components do with it; for the same effect in your code, write a small generator function of your own.

#### Counter Generator

```javascript
// Infinite counter
const count = counter();
console.log(count.next().value); // 0
console.log(count.next().value); // 1
console.log(count.next().value); // 2

// Bounded counter
const bounded = counter(5, 10);
for (const num of bounded)
{
	console.log(num); // 5, 6, 7, 8, 9
}

// With max inclusive
const inclusive = counter(1, 5, true);
// Yields: 1, 2, 3, 4, 5
```

#### Array Generator

```javascript
const items = ['a', 'b', 'c', 'd'];

// Forward iteration
for (const item of arrayGenerator(items))
{
	console.log(item); // a, b, c, d
}

// Reverse iteration
for (const item of arrayGenerator(items, items.length - 1, -1))
{
	console.log(item); // d, c, b, a
}

// Partial iteration
for (const item of arrayGenerator(items, 1, 3))
{
	console.log(item); // b, c
}
```

---

### featureFlag - Feature Flag Bridge

This bridge lets your component ask "is this feature turned on for this user?" and get the same answer your Apex code would get. A feature flag is an on/off switch you can change without a deployment.

- It checks a `FeatureFlag__mdt` flag for the running user through a cacheable Apex method in the package.
- That method asks `UTIL_FeatureFlag.isEnabled`, so the client sees exactly the same result as Apex. One source of truth, two places asking.

**Import:**

```javascript
import {isFlagEnabled} from 'kern/featureFlag';
```

**Usage:**

```javascript
import {ComponentBuilder} from 'kern/componentBuilder';
import {isFlagEnabled} from 'kern/featureFlag';

export default class MyComponent extends ComponentBuilder('notification')
{
	checkoutEnabled = false;

	async connectedCallback()
	{
		this.checkoutEnabled = await isFlagEnabled('NewCheckout_Enabled');
	}
}
```

**API:**

| Function                  | Returns            | Notes                                                                                                                 |
|---------------------------|--------------------|-----------------------------------------------------------------------------------------------------------------------|
| `isFlagEnabled(flagName)` | `Promise<boolean>` | Resolves to flag state for the running user. Errors propagate so callers can fall back via `try/catch` or `.catch()`. |

#### LDS Cache Staleness: Not for Client-Side Authorization

A cached answer can lag behind a permission change made mid-session. Know this before you rely on the bridge.

The bridge's Apex method is marked `@AuraEnabled(cacheable=true)`. Salesforce's Lightning Data Service (LDS) caches the answer per user session and per parameter, so one user can never see another user's result. Here is the sequence that goes wrong.

- An admin assigns or revokes a permission set that changes whether the flag applies to a user.
- The user's browser keeps serving the value it already cached for `isFlagEnabled`. It refreshes only when the page reloads or the wire adapter is called with different parameters, and the flag name never changes, so the wire adapter never fires again on its own.

**The rule, then:** do not use `kern/featureFlag` as a security gate that must react to a permission change within the same session. Use it for shaping the experience instead: which panel to show, whether a hint is visible. Your Apex code remains the real place that decides who is allowed to do what.

If a real authorization decision has to depend on a flag, check the flag inside the Apex controller method
that does the protected work, not on the client.

That rule governs a cacheable Apex call behind a wire adapter, which is what the bridge uses. It does not cover the platform's state managers:

The platform's built-in state managers that expose list- or query-shaped data, such as related list records, have their
own answer to stale data in Winter '27 and later:

- call `refresh()` on the state manager once its status is `loaded`;
- it fetches the latest data from the server without reconfiguring the manager or reloading the page.

That action belongs to state managers only; a cacheable Apex result still refreshes as described above.

---

## Flow Screen Components

These are finished components you can place inside a Flow screen (the `lightning__FlowScreen` target). Use them to assemble a Flow screen without building UI from scratch.

### flowFooter - Flow Navigation

You want consistent Back and Next buttons on a Flow screen without wiring up navigation yourself. `flowFooter` is that ready-made footer.

**Targets:** `lightning__FlowScreen`

**Usage in Flow Screen:**
Add via Flow Builder as a screen component.

**Usage as Child Component:**

```html
<template>
    <kern-flow-footer
        is-child-component
        hide-back-button={hideBack}
        disable-next={isNextDisabled}
        next-title="Continue"
        previous-title="Go Back"
        onnavigationevent={handleNavigation}>
    </kern-flow-footer>
</template>
```

```javascript
handleNavigation(event)
{
	const direction = event.detail; // 'NEXT' or 'BACK'
	if (direction === 'NEXT')
	{
		this.dispatchFlowNextEvent();
	}
	else
	{
		this.dispatchFlowBackEvent();
	}
}
```

Properties: see [flowFooter](#flowfooter) in the Appendix.

---

### jsonViewer - JSON Display

When you need to show JSON on a screen in a way people can actually read, this displays it read-only with colour-coded syntax highlighting.

**Targets:** `lightning__FlowScreen`

Properties: see [jsonViewer](#jsonviewer) in the Appendix.

**Features:**

- Colour-coded syntax highlighting
- Keys, strings, numbers, booleans, null each have distinct colours
- Handles invalid JSON gracefully with error message

---

## Page Components

These are finished components you place on App Pages, Record Pages, or Home Pages through the Lightning App Builder.

### streamingMonitor - Event Monitoring

When you need to watch real-time events flowing through your org, to debug an integration or confirm an event fired, this component shows them live. It covers [Platform Events](https://developer.salesforce.com/docs/atlas.en-us.platform_events.meta/platform_events/platform_events_intro.htm), CDC, PushTopic, and Generic events, and lets you subscribe, filter, and publish test events from one place.

**Targets:** `lightning__AppPage`, `lightning__RecordPage`, `lightning__HomePage`

Properties: none; see [streamingMonitor](#streamingmonitor) in the Appendix.

**Features:**

- Subscribe/unsubscribe to event channels
- Filter events by channel, payload content, time range
- Table and Timeline views
- Publish events for testing
- View org limits and event usage metrics
- Register new Platform Events

The component's views are listed in its [Appendix entry](#streamingmonitor).

---

### searchLookup - Search Interface

A search box that returns records, where you control how the search runs. You point it at an Apex controller that implements the [`IF_Search`](reference/apex/IF_Search.md) interface, so the search logic is whatever you write.

**Targets:** `lightning__FlowScreen`, `lightning__AppPage`, `lightning__HomePage`, `lightning__RecordPage`

Properties: see [searchLookup](#searchlookup) in the Appendix.

**Controller Interface:** the framework creates your controller from its class name, so the class must be `global`, or
`public` with a Type Resolver that finds it (see
[Type Resolution](DTOs%20-%20Guide.md#type-resolution-critical-requirement-in-your-org)).

```apex
public with sharing class MySearchController implements IF_Search
{
	public Object search(Object searchTerm, Map<String, Object> searchParameters)
	{
		List<Object> results = new List<Object>();
		// Add what your search finds to results
		return results;
	}
}
```

---

### scheduledJobDetail - Scheduled Job Detail

A read-only view for a `ScheduledJob__c` record page. It shows every field, turns the cron schedule into plain English, and lays out the job's parameters in a table.

**Targets:** `lightning__RecordPage` (ScheduledJob__c only)

Properties: none; see [scheduledJobDetail](#scheduledjobdetail) in the Appendix.

**Features:**

- Displays scheduler name, class name, active status, description, cron expression with human-readable description
- Shows parameter values as structured label/value pairs when the class implements [`IF_Schedulable`](reference/apex/IF_Schedulable.md)
- Falls back to raw JSON display for plain `Schedulable` classes

**Related Components:** Editing is handled by `scheduledJobEditor` (action override via `scheduledJobEditorOverride` Aura wrapper)
and `scheduledJobEditorModal` for inline editing. The editor embeds `cronExpressionEditor`
(see [Programmatic Components](#cronexpressioneditor)) and renders dynamic parameter forms through the editor's Apex controller in the package.

---

### healthCheck - Post-Install Diagnostics

After installing KernDX, a few things need to be set up correctly (caches, retention jobs). This component runs 12 checks and tells you what is healthy, what needs attention, and what to do about it, with one-click fixes where possible. Drop it on a Home Page or an App Page so the status is visible at a glance.

**Targets:** `lightning__AppPage`, `lightning__HomePage`

Properties: none; see [healthCheck](#healthcheck) in the Appendix.

**Checks:**

1. **Org Cache**: Platform Cache partition allocated (Fail if missing)
2. **Session Cache**: Session partition allocated (Warn if missing)
3. **Class Type Resolver**: `ClassTypeResolver__mdt` record configured with a valid resolver class (Warn if missing, with Setup action)
4. **Data Retention**: Scheduled purge jobs (`SCHED_PurgeRecords`) configured for framework data objects: Log Entry, API Call, API Issue, Async Chain Execution (Warn if any
   unconfigured; item disappears from the card once all four are configured).
    - The warning counts every user's records for each object, whoever opens the page: the check is about how much data your whole org holds, and a count shows no
      record's content.
    - Only a user the `BypassApiRecordDeleteGuard` feature flag is on for can delete API calls and API issues. A built-in rule turns it on for holders of the Delete API
      Records permission, which the Kern Administrator permission set carries. So the warning tells you to schedule their purge as such a user.
    - If a purge of either is already set up but runs as a user the flag is off for, the check warns and names it, because that purge deletes nothing. Reschedule it as a
      user who holds the Delete API Records permission.
    - If the flag record is deactivated, nobody can delete them, so the check warns that every purge of them deletes nothing.
5. **Masking Configuration**: masking posture across the org's configured targets. Warns on dead configuration (an active target pointing at an inactive or missing rule) or when almost
   nothing is masked yet; the warning's action opens the [Data Masking Advisor](Data%20Masking%20-%20Guide.md#the-data-masking-advisor)
6. **Masking Coverage (Custom Objects)**: how much of your own custom data carries masking (Warn when sensitive custom objects are left unmasked; the action opens the Data Masking Advisor)
7. **Chain Abort Capability**: whether the Chain Monitor's abort action is enabled and granted to at least one user (Warn when the flag is deactivated, when any profile beyond System Administrator holds the abort permission, usually the footprint of an All Users install, or when nobody holds the Kern Async Chain Abort permission set)
8. **Chain Watchdog**: whether the stalled-chain recovery job (`SCHED_ChainWatchdog`) is scheduled (Warn when it is not, with a one-click **Schedule Chain Watchdog** action that creates the hourly job with the recommended defaults, plus a **Customize schedule →** link for full control)
9. **Job Runner**: whether the job runner (the set of scheduled jobs that checks for due Scheduled Job records) is active, complete and checking on time. Passes when no job runner is set up.
    - Fail when its set of jobs is incomplete, when it has stopped checking, or when the user who turned it on is no longer active.
    - Warn when its last check is late.
10. **Jobs Waiting for the Job Runner**: whether jobs are set to run on the job runner while no job runner is active (Fail when any are, because they will never run)
11. **Job Runner Capacity**: how many of the org's 100 scheduled-job slots are in use, and whether the job runner's last check started every job that was due (Warn from 80 slots in use or when a due job was left waiting; Fail from 90 slots)
12. **Selected API Mocking**: every active API Setting with Mocking Enabled ticked, and whether those services answer mock data for you (Warn while any active API Setting has the box ticked, or while Mock All APIs or Mock All Inbound APIs is on for you; no action button)

**Features:**

- Two-section layout: **Action required** (fail items, red heading) rendered above **Review recommended** (warn items, neutral heading); items sorted by priority within each
  section
- All-green state: slim green success banner when every check passes
- Headline pluralises correctly ("1 warning" vs "2 warnings")
- **Setup action** on Class Type Resolver opens a modal with a code generator
- **Data Retention** renders two buttons side-by-side:
    - **Apply Recommended Retention** opens a confirmation modal listing the four purge jobs to create (90-day retention, or 180 days for API issues; batch size 2000;
      age measured on `CreatedDate`, or on `CompletedAt__c` for async chain executions; created active). Confirming creates all four `ScheduledJob__c` records in a single
      transaction.
    - **Customize each job →** expands the Data Retention row into a full-width block with a "customizing N jobs" headline, a back-to-apply link, a help paragraph, and a sub-row
      per unconfigured framework object.
        - Each sub-row shows record count (singular/plural correct, locale-formatted), the retention in days, and a **Set up** button.
        - **Set up** opens `scheduledJobEditorModal` prefilled with the object's defaults and the Class Name field read-only.
        - After saving a sub-row, the list auto-refreshes and drops the configured object.
- Namespace-agnostic: `schedulerClassName` is populated server-side from `SCHED_PurgeRecords.class.getName()`, so the experience works identically across managed-package installs and any
  rebranded builds.
- Refresh button to re-run checks after configuration changes

**Controller:** the component's Apex controller in the package returns one result per check, with:

- `name`, `status`, `detail` and `priority` (drives in-section sort);
- an optional `actionLabel`;
- optional `recordCounts` (object label + count).

Another method returns the retention proposals (one per framework object with no active purge job), and another commits the one-click flow.

---

## Form Components

Finished components for creating and editing records.

### createForm - Dynamic Record Forms

You want a record form whose fields are controlled by configuration, not hard-coded in markup. `createForm` builds the form for an object from a [FieldSet](https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_fieldset.htm), so admins change which fields appear by editing the field set, with no code change.

**Targets:** `lightning__FlowScreen`, `lightning__AppPage`, `lightning__HomePage`, `lightning__RecordPage`

Properties: see [createForm](#createform) in the Appendix.

**Supported Field Types:**

- Text, TextArea, Email
- Picklist (with dependent picklists)
- Lookup (with search)
- DateTime, Date
- Boolean (checkbox)
- Number, Currency, Percent

**Exports for Custom Extensions:**

```javascript
import {
	Field,
	TEXT_FIELD_TYPE,
	TEXTAREA_FIELD_TYPE,
	PICKLIST_FIELD_TYPE,
	LOOKUP_FIELD_TYPE,
	DATETIME_FIELD_TYPE,
	BOOLEAN_FIELD_TYPE,
	EMAIL_FIELD_TYPE
} from 'kern/createForm';
```

---

### sObjectLookup - Object Lookup

A lookup field for finding records of any object by searching one of its fields. Use it inside your own components when you need users to pick a record.

Properties: see [sObjectLookup](#sobjectlookup) in the Appendix. When the user picks a record, the component fires `valueselect`; the event detail carries `selectedId`, `elementName` and `isRequired`.

**Usage:**

```html
<kern-s-object-lookup
    object-api-name="Account"
    display-fields={displayFields}
    onvalueselect={handleRecordSelect}>
</kern-s-object-lookup>
```

---

## What are the parts?

The pieces of this part of KernDX are: helper functions for common operations (logging, string handling, arrays), a base class you extend to build your own components, and a library of pre-built components for common patterns. [How does it work?](#how-does-it-work) describes each group.

> **What components are for, and what they are not for:** Components handle the screen: what the user sees and clicks. They should not hold business logic. Your Apex controllers and trigger actions own that. So keep components thin: call a server method with `callControllerMethod()` and display what comes back.

> **What's in this part of KernDX:** components made up of helper-function modules, the base-component architecture, Flow screen components, page components, form components,
> data masking advisor components, log console components, and admin components.
>
> - Every one is covered by Jest tests at 100% coverage, so you can build on this layer without worrying that an upgrade will quietly break it.
> - The current component and test counts are in [Strategic Guide - Metrics](Strategic%20Guide%20-%20Metrics.md#lwc-components); the other framework figures are in
>   [Metrics](Strategic%20Guide%20-%20Metrics.md).

### Component Categories

```text
+-------------------------------------------------------------------------+
|                         KERN LWC ARCHITECTURE                           |
+-------------------------------------------------------------------------+
|                                                                         |
|  COMPONENTS YOU CAN USE                                                 |
|  ======================                                                 |
|                                                                         |
|  +-------------------+  +-------------------+  +-------------------+    |
|  |  UTILITY MODULES  |  |  FLOW COMPONENTS  |  |  PAGE COMPONENTS  |    |
|  +-------------------+  +-------------------+  +-------------------+    |
|  | utilityLogger     |  | flowFooter        |  | streamingMonitor  |    |
|  | utilityString     |  | jsonViewer        |  | searchLookup      |    |
|  | utilityArray      |  |                   |  |                   |    |
|  | utilitySystem     |  +-------------------+  +-------------------+    |
|  | utilityRandom     |                                                  |
|  | utilityGenerator  |  +-------------------+  +-------------------+    |
|  | utilityStreaming  |  | FORM COMPONENTS   |  | SCHEDULING        |    |
|  +-------------------+  +-------------------+  +-------------------+    |
|                         | createForm        |  | scheduledJob      |    |
|                         | sObjectLookup     |  |   Detail          |    |
|                         | searchLookup      |  | cronExpression    |    |
|                         +-------------------+  |   Editor          |    |
|                                                 +-------------------+    |
|                                                                         |
+-------------------------------------------------------------------------+
|                                                                         |
|  BASE ARCHITECTURE (for building custom components)                     |
|  ==================================================                     |
|                                                                         |
|  +-------------------+     +-------------------+                        |
|  | ComponentBuilder  |---->| baseComponent     |                        |
|  +-------------------+     +-------------------+                        |
|          |                         |                                    |
|          v                         v                                    |
|  +-------------------+     +-------------------+                        |
|  | componentExtender |     | Module Mixins:    |                        |
|  +-------------------+     | - moduleController|                        |
|                            | - moduleNavigation|                        |
|                            | - moduleNotification                       |
|                            | - moduleLightningMessageService            |
|                            | - moduleFlowNavigation                     |
|                            +-------------------+                        |
|                                                                         |
+-------------------------------------------------------------------------+
```

> **What you actually use:** `ComponentBuilder` is the one entry point you call. The `baseComponent`, `componentExtender`, and `module*` pieces shown in the diagram are the wiring behind it: KernDX assembles them for you. Always build a component with `extends ComponentBuilder('module1', 'module2')` and let the framework handle the rest.

---

## How does it work?

### Architecture Diagram

```text
+---------------------------------------------------------------------------+
|                       LWC FRAMEWORK ARCHITECTURE                          |
+---------------------------------------------------------------------------+
|                                                                           |
|  UTILITY MODULES (Stateless Services)                                     |
|  ====================================                                     |
|  +---------------+ +---------------+ +---------------+ +---------------+  |
|  | utilityLogger | | utilityString | | utilityArray  | | utilitySystem |  |
|  | - log levels  | | - templates   | | - keyBy()     | | - clipboard   |  |
|  | - correlation | | - case conv.  | | - extractById | | - reduceErrors|  |
|  | - server sync | | - currency    | | - filterById  | | - sort        |  |
|  +---------------+ +---------------+ +---------------+ +---------------+  |
|  +---------------+ +---------------+                                      |
|  | utilityRandom | | utilityGen    |                                      |
|  | - UUID        | | - counters    |                                      |
|  | - strings     | | - arrays      |                                      |
|  +---------------+ +---------------+                                      |
|                                                                           |
+---------------------------------------------------------------------------+
|                                                                           |
|  COMPONENT BUILDER (Base Class Factory)                                   |
|  ======================================                                   |
|                                                                           |
|  ComponentBuilder('notification', 'controller', ...)                      |
|        |                                                                  |
|        v                                                                  |
|  +-------------------------------------------------------------------+   |
|  |  Base Component (auto-generated from selected modules)            |   |
|  |  +-------------+ +------------+ +----------+ +----------------+   |   |
|  |  | notification | | controller | | navigation| | lightning-msg |   |   |
|  |  | showToast()  | | callCtrl() | | redirect() | | subscribe()  |   |   |
|  |  +-------------+ +------------+ +----------+ +----------------+   |   |
|  +-------------------------------------------------------------------+   |
|        |                                                                  |
|        v                                                                  |
|  Your Custom Components (extend ComponentBuilder result)                  |
|                                                                           |
+---------------------------------------------------------------------------+
|                                                                           |
|  PRE-BUILT COMPONENTS                                                     |
|  ====================                                                     |
|  Flow:  flowFooter, jsonViewer                                            |
|  Page:  streamingMonitor, searchLookup, scheduledJobDetail                |
|  Form:  createForm, sObjectLookup                                         |
|                                                                           |
+---------------------------------------------------------------------------+
```

This part of KernDX is organised into three groups, each solving a different need.

1. **Helper functions for everyday tasks.** When you need to format a string, sort an array, generate a UUID, or write a client log, you import a small function instead of writing it yourself.
    - These are plain JavaScript modules: `utilityLogger`, `utilityString`, `utilityArray`, `utilitySystem`, `utilityRandom`. `utilityGenerator` and `utilityStreaming` are internal to the package.
    - They have no memory of past calls: you call a function, you get a result.
    - They are not components, so you bring them into a component with a normal ES module import.

2. **A base class for building your own components.** Rather than re-wiring toasts, Apex calls, and navigation in every component, you extend one base class that already has them.
    - `ComponentBuilder(...)` is a factory: you list the features you want (notification, navigation, controller, lightning-message, flow-navigation) and it hands back a base class with exactly those mixed in.
    - Your component extends that result instead of extending `LightningElement` directly. The [Base Component Architecture](#base-component-architecture) section explains the full system.

3. **Pre-built components you can use as-is.** For common patterns there is already a finished component: Flow screen components (`flowFooter`, `jsonViewer`), page components (`streamingMonitor`, `searchLookup`, `scheduledJobDetail`), and form components (`createForm`, `sObjectLookup`). So a common screen often needs no new code at all.

All components use Allman bracing, tabs for indentation, single quotes, and follow the conventions defined in
[`docs/Code Conventions - Guide.md`](./Code%20Conventions%20-%20Guide.md). Every component requires a `.js-meta.xml` file with `apiVersion` 68.0.

---

## Internal Components Reference

These are the building blocks KernDX uses inside its own components. You don't place them on a page directly, but knowing what they do helps if you ever extend or troubleshoot the framework.

### UI Support Components

| Component                     | Purpose                                                        |
|-------------------------------|----------------------------------------------------------------|
| `modal`                       | Reusable modal dialog with show/hide API                       |
| `notice`                      | Info notice with icon                                          |
| `baseLookup`                  | Base class for lookup components                               |
| `viewRecord`                  | Read-only record display                                       |
| `applyRetentionModal`         | Confirmation modal for applying recommended retention jobs     |
| `classTypeResolverSetupModal` | Guided setup modal for your org's Class Type Resolver          |
| `kernHome`                    | Developer control room (Kern Home) card layout                 |
| `scheduledJobEditor`          | ScheduledJob__c editor form (action override via Aura wrapper) |
| `scheduledJobEditorModal`     | Modal dialog for creating/editing ScheduledJob__c records      |

### Streaming Monitor Components

KernDX's Streaming Monitor is adapted from Philippe Ozil's [Streaming Monitor](https://github.com/pozil/streaming-monitor), which he released to the public domain under CC0-1.0, rebuilt to follow KernDX conventions. Both monitors watch the same event types, replay past events, publish test events, and show org limits and event usage. KernDX's version adds search on the org limits screen, a table view of event usage, times in the time zone set on your Salesforce user, translatable screen text, platform events published with your permissions checked, and a message on screen when a generic event fails to send. His is [free on the AppExchange](https://appexchange.salesforce.com/appxListingDetail?listingId=a0N3A00000FYEEWUA5).

| Component                | Purpose                                                 |
|--------------------------|---------------------------------------------------------|
| `streamingEvents`        | Event list display                                      |
| `streamingEventFilters`  | Filter controls                                         |
| `streamingTimeline`      | Interactive timeline visualisation                            |
| `streamingEventsHeader`  | Header action buttons                                   |
| `streamingUsageMetrics`  | Usage metrics charts                                    |
| `streamingUsageFilters`  | Metrics filter controls                                 |
| `orgLimits`              | Org limits card grid (worst-first, per-limit usage bars) |
| `streamingSubscriptions` | Active subscription management                          |
| `streamingSidebar`       | Toggleable sidebar navigation for the Streaming Monitor |

### Chain Monitor Components

The Chain Monitor is a live view of `AsyncChainExecution__c` records, so you see how each step of a multi-step background job (a chain) went without writing SOQL by hand.

- **Operator actions** for the runs that need help: abort, retry, restart, clear stalled, and an org-wide suspend and resume control, each behind its own opt-in (see [the Async Processing Guide](Async%20Processing%20-%20Guide.md#re-driving-a-failed-chain)).
- **Two ways in:** a full-page, split-panel monitor reached from Kern Home, and a step-by-step timeline embedded on the record page.

**Component tree:**

```text
chainMonitor (AppPage container — list, detail, and the header operations control)
├── chainMonitorList (left panel — datatable, filters, pagination)
├── chainMonitorDetail (right panel — header actions, progress, accordion)
│   ├── chainStepTimeline (SLDS timeline with hover popovers)
│   └── chainLogStream (live activity stream for the selected run)
├── chainAbortModal (abort confirmation, opened from the detail header)
└── chainActionConfirmModal (retry / restart / clear-stalled / suspend / resume confirmations)

chainStepTimeline (standalone on AsyncChainExecution__c record page)
```

**Key patterns:**

- **Event-driven refresh:** `chainMonitor` subscribes to `LogEntryEvent__e` via `empApi`, resolving your
  org's namespace at runtime so live refresh works in unmanaged and renamed-namespace deploys too. If the
  subscribe fails, the failure is logged and the monitor still works through imperative Apex calls on user
  interactions.
- **Server-computed availability:** every operator action's availability is resolved in Apex and returned as a
  code on the response object.
    - A button whose check refuses renders disabled with the reason in its tooltip; a button that does not apply to
      the chain's state is hidden.
    - Button state is only a hint: Apex re-checks every condition when the action is confirmed, and every refusal
      surfaces as a labelled error toast.
- **Modal wording comes ready-made:** `chainAbortModal` and `chainActionConfirmModal` extend `LightningModal` and
  take ready-made title, body, and button strings, so all wording lives in Custom Labels at the call site.
- **Smart row selection:** `chainMonitorList` auto-selects the first row on load, keeps the selection
  after a filter or sort if the row still exists, and clears it if the row is filtered out.
- **String parameter pattern:** the controller takes `String requestJson` and calls `JSON.deserialize()` to avoid
  LWC Proxy wrapper issues with complex DTO parameters.
- **Hover popovers:** `chainStepTimeline` shows a CSS-only SLDS tooltip popover on hover, with class
  name, status, duration, continueOnError flag, and error message.
- **URL column:** the Chain Name links directly to the `AsyncChainExecution__c` record page.
- **View logs cross-link:** `chainMonitorDetail` includes a **View logs** button that opens the Log Console
  pre-filtered to the run's correlation ID, so you jump from a failed step straight to everything that run logged.
- **Launched under:** the detail panel always shows a Launched under row, and the list adds a Launched under column
  while it is kept to one action. Each reads one of four ways:
    - the launching chain's name and number (a step of it launched this run), as a link that selects it;
    - the action itself;
    - a restart of a named run, as a link;
    - that the run started the action.

  In the detail panel, when the reading is "this action", the action's own tracking ID sits beside the words with a
  copy button.
- **Action scope:** the container reads `c__rootCorrelationId` from the page state (the Log Console's link) and hands it
  to `chainMonitorList` as `actionRootCorrelationId`; the list shows the action as a removable pill with **Show the
  action's logs**, which returns to the Log Console with `c__rootCorrelationId` and a click stamp only, never a date
  window.

| Component                | Purpose                                                                               |
|--------------------------|---------------------------------------------------------------------------------------|
| `chainMonitor`           | Split-panel container (the list above the detail on a narrow screen) with empApi subscription, the header operations control (suspend/resume, clear stalled, state badge), and the action deep link |
| `chainMonitorList`       | Datatable with collapsible status filters, search, sorting, pagination, the action pill and Launched under column |
| `chainMonitorDetail`     | Status icon, progress bar, operator action buttons, step timeline, timing grid, error section, View logs link, the Launched under row (a restart reads as a link to the run it was restarted from), Show the action's logs |
| `chainStepTimeline`      | SLDS timeline blueprint with hover popovers; dual mode (@api steps or @api recordId) |
| `chainLogStream`         | Live activity stream: shows the run's newest entries (the Apex seed arrives oldest-first and is rendered newest-first), then live over empApi, with the errors-always-stream caveat |
| `chainAbortModal`        | Destructive confirmation dialogue for abort                                           |
| `chainActionConfirmModal`| Shared confirmation dialogue for retry, restart, clear stalled, suspend, and resume   |

### Log Console Components

The Log Console is where you browse and diagnose what your code logged: repeated events grouped into problems, a summary ribbon over the current window, and a detail drawer that lays the whole correlated run out as a timeline. You launch it from Kern Home or the App Launcher; the [Logging Guide](Logging%20-%20Guide.md#the-log-console) has the full walkthrough.

**Component tree:**

```text
logConsole (AppPage container — filters, two list views, ribbon, paging)
├── logConsoleTable (datatable with a colour-coded severity badge cell)
└── logConsoleDetail (tabbed drawer: Overview / Stack trace / Context / Timeline)

logConsoleContext (shared service module — readable execution-context names)
```

**Key patterns:**

- **Two list views, one container:** `logConsole` owns the filter state and switches between a **Problem summary**
  view (distinct problems with occurrence counts) and an **Individual entries** view (the flat rows), both read
  through the console's Apex controller in the package.
- **Debounced search and paging:** the search box waits briefly after you stop typing before querying, and both
  tables come a page at a time, with a position line under the list, Previous and Next, page numbers while there
  are few enough to use, and a page size of 25, 50 or 100.
- **Correlation deep links:** the console reads `c__correlationId` from the page state, so other tools (such as the
  Chain Monitor's **View logs** button) can open it pre-filtered to one correlated run; the detail drawer links back
  the other way into the Chain Monitor for async steps.
- **Custom severity cell:** `logConsoleTable` extends `LightningDatatable` with a `logLevel` column type that renders
  each row's level as a colour-coded badge.
- **Shared context names:** `logConsoleContext` maps raw execution-context values (the platform's record of how a
  transaction started: batch, queueable, REST, and so on) to Custom Label display names, one source for both the list
  and the timeline so the two never drift.

| Component           | Purpose                                                                       |
|---------------------|-------------------------------------------------------------------------------|
| `logConsole`        | Container: filters, Problem summary and Individual entries views, ribbon, drawer |
| `logConsoleTable`   | Datatable extension with the colour-coded severity badge column               |
| `logConsoleDetail`  | Tabbed detail drawer with the correlated execution timeline                   |
| `logConsoleContext` | Service module mapping execution-context values to readable names             |

---

## Demo Components

These exist to show how the framework is used and to give you a working example to learn from. They are available for testing, but not meant for production.

| Component            | Demonstrates                                                                                |
|----------------------|---------------------------------------------------------------------------------------------|
| `apiTestHarnessForm` | Interactive form for invoking inbound and outbound APIs with Safe Mode and mocking controls |

---

## Testing

You write [Jest](https://developer.salesforce.com/docs/platform/lwc/guide/testing.html) tests for your components the same way you would for any LWC. The difference is that your component depends on KernDX modules, so a test also needs [stand-ins (mocks) for those modules](#mocking-kerndx-modules).

### Jest Test Setup

Run KernDX LWC tests on Node 22.22.3. The version matters: the Jest worker pool hangs on 22.23.x, with no error and no timeout, so the suite simply never finishes. Switch to it with the command below. It names the version, so it works in any folder and with nvm on Windows, a Mac or Linux:

```shell
nvm use 22.22.3
```

If nvm says that version is not installed, install it with nvm first and run the command again, or, with no `nvm` on your machine, install that version from [Node's download page](https://nodejs.org/en/download).

Run all the tests:

```shell
npm run test:unit
```

Run the tests for one component, here `utilityString`:

```shell
npm run test:unit -- -- --testPathPattern=utilityString
```

Run the tests with coverage:

```shell
npm run test:unit -- --coverage
```

### Mocking KernDX Modules

When you test a component, you usually don't want it to really call KernDX logging or the real base class. You replace those with simple stand-ins (mocks) so the test stays fast and focused on your code. Here are ready-to-paste mocks for the modules you'll meet most often.

**Mock utilityLogger:**

```javascript
jest.mock('kern/utilityLogger', () => ({
	__esModule: true,
	default: {
		debug: jest.fn(),
		info: jest.fn(),
		warn: jest.fn(),
		error: jest.fn(),
		startCorrelation: jest.fn(() => 'mock-correlation-id'),
		endCorrelation: jest.fn(),
		getCorrelationId: jest.fn(() => 'mock-correlation-id'),
		startTimer: jest.fn(() => ({stop: jest.fn(() => 100)})),
		withCorrelation: jest.fn((name, fn) => fn('mock-correlation-id'))
	},
	LogLevel: {DEBUG: 'DEBUG', INFO: 'INFO', WARN: 'WARN', ERROR: 'ERROR'},
	debug: jest.fn(),
	info: jest.fn(),
	warn: jest.fn(),
	error: jest.fn(),
	startCorrelation: jest.fn(() => 'mock-correlation-id'),
	endCorrelation: jest.fn()
}), {virtual: true});
```

**Mock utilityString:**

```javascript
jest.mock('kern/utilityString', () => ({
	formatTemplateString: jest.fn((template, values) => template),
	convertToSentenceCase: jest.fn(str => str),
	CAPITAL_LETTERS: 'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
	DIGITS: '0123456789',
	EMPTY: '',
	SPACE: ' '
}), {virtual: true});
```

**Mock componentBuilder:**

```javascript
// Assign the stubs in the constructor, not as class fields: class fields make the LWC compiler
// add a helper that Jest's mock hoisting rejects.
jest.mock('kern/componentBuilder', () => ({
	ComponentBuilder: jest.fn().mockImplementation(() =>
	{
		const {LightningElement} = require('lwc');
		return class extends LightningElement
		{
			constructor()
			{
				super();
				this.showSuccessToast = jest.fn();
				this.showErrorToast = jest.fn();
				this.callControllerMethod = jest.fn().mockResolvedValue({});
			}
		};
	})
}), {virtual: true});
```

### Test Patterns

#### Testing Utility Modules

The package ships `utilityString`, so your code imports it from `kern/utilityString`. Your project does not hold the
package's source, so Jest can load that path only when `moduleNameMapper` in `jest.config.js` maps it to a copy. The
same shape tests a utility module of your own.

```javascript
import {formatTemplateString} from 'kern/utilityString';

describe('utilityString', () =>
{
	describe('formatTemplateString', () =>
	{
		it('should replace placeholders with values', () =>
		{
			const result = formatTemplateString('Hello {0}', ['World']);
			expect(result).toBe('Hello World');
		});

		it('should handle multiple occurrences', () =>
		{
			const result = formatTemplateString('{0} and {0}', ['Test']);
			expect(result).toBe('Test and Test');
		});
	});
});
```

#### Testing Components

```javascript
import {createElement} from 'lwc';
import MyComponent from 'c/myComponent';

describe('c-my-component', () =>
{
	afterEach(() =>
	{
		while (document.body.firstChild)
		{
			document.body.removeChild(document.body.firstChild);
		}
		jest.clearAllMocks();
	});

	it('should render correctly', async () =>
	{
		const element = createElement('c-my-component', {is: MyComponent});
		document.body.appendChild(element);

		await Promise.resolve();

		expect(element.shadowRoot.querySelector('.title')).not.toBeNull();
	});
});
```

---

## What to avoid

Common mistakes (a tempting but risky habit, sometimes called an anti-pattern) and what to do instead:

| Anti-Pattern                                                 | Why It's Wrong                                                             | Instead                                                                                              |
|--------------------------------------------------------------|----------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------|
| Extending `LightningElement` directly                        | Bypasses framework utilities, notification methods, and controller helpers | Extend `ComponentBuilder('module1', 'module2')`                                                      |
| Using `console.log` for debugging                            | Logs are ephemeral and not persisted; no correlation tracking              | Use `utilityLogger` for client-side logging with server persistence                                  |
| Using raw HTML elements (`<div>`, `<input>`) for UI controls | Inconsistent styling, no SLDS compliance, accessibility gaps               | Use Lightning base components (`lightning-button`, `lightning-input`, etc.)                          |
| Not cleaning up message channel subscriptions                | Memory leaks and duplicate event handlers across component lifecycle       | Call `clearSubscriptions()` in `disconnectedCallback` or use the built-in `lightning-message` module |
| Inline Apex calls without `callControllerMethod`             | No error handling, no loading state management, no consistent patterns     | Use `callControllerMethod(method, params)` from the `controller` module                              |

---

## Recommended habits

### Use ComponentBuilder for New Components

```javascript
// Prefer this
export default class MyComponent extends ComponentBuilder('notification', 'controller') {}

// Over manual mixin composition
```

### Use Utility Modules for Common Operations

```javascript
// Prefer this
import {formatTemplateString} from 'kern/utilityString';
const message = formatTemplateString('Hello {0}', [name]);

// Over inline string manipulation
const message = `Hello ${name}`;
```

### Correlate Client and Server Logs

```javascript
async saveRecord()
{
	await withCorrelation('Save Record', async (correlationId) =>
	{
		return await saveApexMethod({record: this.record, correlationId});
	});
}
```

### Handle Errors Consistently

```javascript
catch (error)
{
	this.showErrorToast(error);
}
```

The `notification` module's `showErrorToast` accepts either a string or an Apex / UI API error object, which it
normalises through `kern/utilitySystem.reduceErrors`. When to call `reduceErrors` yourself: see [Reduce Errors](#reduce-errors).

### Clean Up Subscriptions

```javascript
disconnectedCallback()
{
	this.clearSubscriptions();
}
```

### Add JSDoc to Component Classes and Methods

```javascript
/**
 * @description Displays a paginated list of records with sorting and selection.
 *
 * @author <your-author-tag>
 *
 * @date YYYY-MM
 */
export default class PaginatedTable extends ComponentBuilder('controller')
{
	/**
	 * @description Navigates to the specified page and refreshes the displayed rows.
	 *
	 * @param {number} pageNumber The 1-based page number to navigate to
	 */
	goToPage(pageNumber)
	{
		// ...
	}
}
```

All LWC component classes require `@description`, `@author`, and `@date`. Methods with parameters
require `@param {type} name` annotations.

---

## Troubleshooting

### Common Issues

| Issue                     | Solution                                                                                                                                               |
|---------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------|
| Module not found          | Ensure component is deployed; check namespace prefix                                                                                                   |
| Toast not showing         | Verify `moduleNotification` is included in ComponentBuilder                                                                                            |
| Navigation not working    | Verify `moduleNavigation` is included; check [NavigationMixin](https://developer.salesforce.com/docs/platform/lwc/guide/use-navigate.html)             |
| LMS messages not received | Verify channel import; check subscription in [connectedCallback](https://developer.salesforce.com/docs/platform/lwc/guide/create-lifecycle-hooks.html) |
| Jest tests failing        | Switch to Node 22.22.3 with the command in [Jest Test Setup](#jest-test-setup); check mock setup                                                        |
| Jest hangs with no output | You are on Node 22.23.x, where the worker pool stalls silently. Switch back to 22.22.3 with the command in [Jest Test Setup](#jest-test-setup)          |

### Debugging Tips

1. **Enable verbose logging:**
   ```javascript
   import {debug} from 'kern/utilityLogger';
   debug('State:', JSON.stringify(this.state));
   ```

2. **Check correlation in Apex logs:**
    - Find the [`LogEntry__c`](reference/objects/LogEntry__c.md) entries with the matching `CorrelationId__c` in the
      [Log Console](Logging%20-%20Guide.md#the-log-console); its detail drawer lays out the whole correlated run as a timeline

3. **Verify component exposure:**
    - Check `.js-meta.xml` for `isExposed` and `targets`

---

## Related Documentation

- **[Logging - Guide](Logging%20-%20Guide.md)** - Server-side logging correlation
- **[AI Agent Instructions](AI%20Agent%20Instructions.md)** - LWC code generation patterns
- **[Selectors - Guide](Selectors%20-%20Guide.md)** - Building Apex selectors for controller data
- **[Web Services - Guide](Web%20Services%20-%20Guide.md)** - Apex API classes called by LWC controllers
- **[Triggers - Guide](Triggers%20-%20Guide.md)** - Server-side trigger handlers
- **[DTOs - Guide](DTOs%20-%20Guide.md)** - `DTO_BaseTable` for datatable data structures

---

## Appendix: Droppable Components Quick Reference

The first two groups below are the components you place on pages, Flows, or record pages in a builder, with where
you can use each one and the properties it accepts, so you can pick the right one and configure it at a glance. The
third group, Programmatic Components, is different: you use those from the code of your own components.

### Flow Screen Components

Components available in Flow Builder's component palette.

#### flowFooter

**Purpose:** Standardised Back/Next navigation footer for flow screens

**Where to Use:** Flow Screens

| Property                   | Type    | Required | Default | Description                  |
|----------------------------|---------|----------|---------|------------------------------|
| `hideBackButton`           | Boolean | No       | false   | Hide the Back button         |
| `disableNext`              | Boolean | No       | false   | Disable the Next button      |
| `nextTitle`                | String  | No       | 'Next'  | Next button label            |
| `previousTitle`            | String  | No       | 'Back'  | Back button label            |
| `overrideNextToFinish`     | Boolean | No       | false   | Next dispatches Finish event |
| `overridePreviousToFinish` | Boolean | No       | false   | Back dispatches Finish event |

When you embed `flowFooter` in your own component, set `isChildComponent` (`is-child-component` in your markup) from
code; it is not offered in Flow Builder. The footer then sends a `navigationevent` to your component instead of moving the Flow itself.

---

#### jsonViewer

**Purpose:** Read-only JSON viewer with syntax highlighting

**Where to Use:** Flow Screens

| Property   | Type   | Required | Default | Description          |
|------------|--------|----------|---------|----------------------|
| `jsonText` | String | No       | -       | JSON data to display |

**Features:**

- Colour-coded keys, strings, numbers, booleans, null
- Handles malformed JSON with error message

---

### App Page / Record Page / Home Page Components

Components available in Lightning App Builder.

#### streamingMonitor

**Purpose:** Real-time monitor for Platform Events, CDC, PushTopic and Generic events

**Where to Use:** App Pages, Record Pages, Home Pages

| Property | Type | Required | Default | Description                               |
|----------|------|----------|---------|-------------------------------------------|
| (none)   | -    | -        | -       | Self-contained, no configuration required |

**Features:**

- Subscribe/unsubscribe to event channels
- Filter by channel, payload keyword, time range
- Table and Timeline views
- Publish test events
- View org limits consumption
- Event usage metrics dashboard
- Register new Platform Events

**Views:**

- **Monitor** - Real-time event stream with filtering
- **Subscribe All** - Bulk subscribe to all channels of a type
- **Subscribe** - Subscribe to specific channels
- **Publish** - Publish test events
- **Register** - Create new Platform Event definitions
- **Org Limits** - View current org limit consumption
- **Event Usage Metrics** - Historical event usage charts

---

#### searchLookup

**Purpose:** Search lookup with custom controller support

**Where to Use:** Flow Screens, App Pages, Home Pages, Record Pages

The same properties are offered on every target (Flow Screen, App, Home and Record pages).

| Property                     | Type   | Required | Default    | Description                                                             |
|------------------------------|--------|----------|------------|-------------------------------------------------------------------------|
| `controllerName`             | String | Yes      | -          | Apex controller implementing [`IF_Search`](reference/apex/IF_Search.md) |
| `name`                       | String | Yes      | -          | Unique name of this lookup on the page                                  |
| `fieldLabel`                 | String | Yes      | -          | Label above search input                                                |
| `resultUniqueId`             | String | No       | 'Id'       | Unique ID field in results                                              |
| `addedElementClass`          | String | No       | 'slds-box' | SLDS classes added to the outermost element                             |
| `controllerSearchParameters` | String | No       | -          | Extra search parameters, passed to your controller (see below)          |

`controllerSearchParameters` is one line of `name=value` pairs split by `;`, for example
`objectName=Account;maximumNumberOfResults=10`.

To show a record already chosen when the lookup opens, set `preselectedRecord` from your own component's code (it is
not offered in the builders).

**Controller Interface:** the framework creates your controller from its class name, so the class must be `global`, or
`public` with a Type Resolver that finds it (see
[Type Resolution](DTOs%20-%20Guide.md#type-resolution-critical-requirement-in-your-org)).

```apex
public with sharing class MyController implements IF_Search
{
	public Object search(Object searchTerm, Map<String, Object> searchParameters)
	{
		List<Object> results = new List<Object>();
		// Add what your search finds to results
		return results;
	}
}
```

---

#### createForm

**Purpose:** Dynamic record create/edit/clone form using FieldSets

**Where to Use:** Flow Screens, App Pages, Home Pages, Record Pages

| Property          | Type    | Required | Default | Description                | Offered on                     |
|-------------------|---------|----------|---------|----------------------------|--------------------------------|
| `objectApiName`   | String  | No       | -       | SObject API name           | Flow Screen, App, Home         |
| `fieldSetApiName` | String  | No       | -       | FieldSet API name          | Flow Screen, App, Home, Record |
| `recordId`        | String  | No       | -       | Record ID (for edit/clone) | Flow Screen                    |
| `formHeading`     | String  | No       | -       | Heading above form         | Flow Screen, App, Home, Record |
| `isSaveMode`      | Boolean | No       | false   | Show Save button           | Flow Screen, App, Home, Record |
| `isUpdateMode`    | Boolean | No       | false   | Enable update mode         | Flow Screen                    |

The builders mark no property as required, but the form needs a field set to show any fields: placed without
`fieldSetApiName`, it shows an error toast. On a Record Page you set only `formHeading`,
`isSaveMode` and `fieldSetApiName`; the page supplies the record, and the form takes the object from it.

**Supported Field Types:**

- Text, TextArea, Email
- Picklist (including dependent)
- Lookup (with search)
- DateTime, Date
- Boolean, Number, Currency, Percent

---

#### scheduledJobDetail

**Purpose:** View-only record page component for ScheduledJob__c records with cron descriptions and dynamic parameter tables

**Where to Use:** Record Pages (ScheduledJob__c)

| Property | Type | Required | Default | Description                                     |
|----------|------|----------|---------|-------------------------------------------------|
| (none)   | -    | -        | -       | `recordId` set automatically by the record page |

**Features:**

- Read-only field display with cron expression human-readable description and structured parameter values
- Dynamic parameter table when class implements `IF_Schedulable`; raw JSON fallback otherwise
- Editing handled by `scheduledJobEditor` (action override) and `scheduledJobEditorModal`

---

#### healthCheck

**Purpose:** Post-install diagnostics with 12 health checks and actionable warnings

**Where to Use:** App Pages, Home Pages

| Property | Type | Required | Default | Description                               |
|----------|------|----------|---------|-------------------------------------------|
| (none)   | -    | -        | -       | Self-contained, no configuration required |

**Features:**

- 12 checks: Org Cache, Session Cache, Class Type Resolver, Data Retention, Masking Configuration, Masking Coverage (Custom Objects), Chain Abort Capability, Chain Watchdog, Job Runner, Jobs Waiting for the Job Runner, Job Runner Capacity, Selected API Mocking
- Two-section layout: Action required (fail items) rendered above Review recommended (warn items); all-pass state collapses to a slim green banner
- Checks that the configured resolver class can be found and is a resolver (it implements
  `UTIL_TypeResolver.INT_ClassTypeResolver`, as `UTIL_TypeResolver.BaseClassResolver` does), and warns if a class
  exists but is not one
- Setup button on resolver warnings opens a code generator modal
- Data Retention renders Apply Recommended Retention (one-click modal creating all four purge jobs) plus a Customize each job → link that expands into per-object sub-rows, each
  with a Set up button that opens `scheduledJobEditorModal` prefilled with the object's defaults and a read-only Class Name
- Record counts per unconfigured object returned as structured data for locale-aware formatting

---

### Programmatic Components (for Custom LWC Development)

You can't drag these onto a page in Lightning App Builder. Instead, you use them inside your own components by importing and embedding them in your markup. They are building blocks for custom development.

#### sObjectLookup

**Purpose:** Lookup component for searching any SObject by field

**Usage:**

```html
<kern-s-object-lookup
    object-api-name="Account"
    display-fields={accountFields}
    field-label-name="Account"
    placeholder="Search accounts..."
    onvalueselect={handleAccountSelect}>
</kern-s-object-lookup>
```

| Property              | Type     | Required | Default  | Description                                                                      |
|-----------------------|----------|----------|----------|----------------------------------------------------------------------------------|
| `objectApiName`       | String   | Yes      | -        | SObject API name to search (the lookup has nothing to search without it) |
| `displayFields`       | String[] | No       | ['Name'] | Fields to display in results                                                     |
| `fieldLabelName`      | String   | No       | 'Name'   | Label above search input                                                         |
| `placeholder`         | String   | No       | 'Search' | Placeholder text                                                                 |
| `iconName`            | String   | No       | -        | SLDS icon for a custom object; a standard object always gets its own icon        |
| `isRequired`          | Boolean  | No       | false    | Mark field as required                                                           |
| `disableElement`      | Boolean  | No       | false    | Disable the lookup                                                               |
| `readOnly`            | Boolean  | No       | false    | Make lookup read-only                                                            |
| `displayFormat`       | String   | No       | -        | Custom display format for results                                                |
| `idField`             | String   | No       | 'Id'     | Field to use as unique identifier                                                |
| `elementName`         | String   | No       | -        | Component name for event identification                                          |
| `outerElementClasses` | String   | No       | ''       | CSS classes added to the outermost element                                       |
| `defaultRecordId`     | String   | No       | -        | Record Id to show as already chosen, for example the saved value on an edit form |

**Events:**

- `valueselect` - Fires when a record is selected (detail: `{selectedId, elementName, isRequired}`)
- `searchtermchanged` - Fires when search term changes (detail: `{searchTerm, elementName}`)

---

#### paginatedTable

**Purpose:** Paginated datatable wrapper with cross-page row selection

**Usage:**

```html
<kern-paginated-table
    rows={data}
    columns={columns}
    title="My Records"
    results-per-page="20"
    key-field="Id"
    max-rows-selected="10"
    onrowselection={handleSelection}
    onpagechange={handlePageChange}>
</kern-paginated-table>
```

| Property          | Type   | Required | Default | Description                                                                                                                                                 |
|-------------------|--------|----------|---------|-------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `rows`            | Array  | Yes      | []      | Data rows (same format as [lightning-datatable](https://developer.salesforce.com/docs/component-library/bundle/lightning-datatable/documentation))          |
| `columns`         | Array  | Yes      | []      | Column definitions (same format as [lightning-datatable](https://developer.salesforce.com/docs/component-library/bundle/lightning-datatable/documentation)) |
| `title`           | String | No       | ''      | Table title                                                                                                                                                 |
| `resultsPerPage`  | Number | No       | 10      | Rows displayed per page                                                                                                                                     |
| `maxRowsSelected` | Number | No       | 100     | Maximum selectable rows (0 = read-only)                                                                                                                     |
| `keyField`        | String | No       | 'Id'    | Unique row identifier field                                                                                                                                 |
| `uniqueTableName` | String | No       | -       | Unique identifier for the table                                                                                                                             |

**Events:**

- `rowselection` - Fires when rows are selected (detail: `{rows}` - all selected across pages)
- `pagechange` - Fires when page changes (detail: `{pageNumber}`)
- `columnsort` - Fires when column is sorted (detail: `{sortedBy, sortDirection}`)

**API Methods:**

- `selectedTableRows` - Get/set currently visible selected rows
- `totalSelectedRowIds` - Get all selected row IDs across pages

---

#### customDataTable

**Purpose:** Extended [lightning-datatable](https://developer.salesforce.com/docs/component-library/bundle/lightning-datatable/documentation) with custom column types

**Usage:**

```html
<kern-custom-data-table
    data={data}
    columns={columnsWithCustomTypes}
    key-field="Id">
</kern-custom-data-table>
```

| Property | Type  | Required | Default | Description                                                                                                                                                        |
|----------|-------|----------|---------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `types`  | Array | No       | []      | Additional custom column type definitions. A table does not see the types it passes itself; they reach only tables created after it. See **Your Own Column Types** |

**Built-in Custom Column Types:**

| Type             | Description              | Type Attributes               |
|------------------|--------------------------|-------------------------------|
| `richText`       | Renders HTML content     | -                             |
| `image`          | Displays an image        | `imgUrl`                      |
| `iconColumn`     | Displays SLDS icon       | `iconName`, `alternativeText` |
| `progressColumn` | Shows progress indicator | `value` (0-100)               |

**Column Definition Example:**

```javascript
const columns = [
	{label: 'Name', fieldName: 'Name', type: 'text'},
	{label: 'Status', fieldName: 'statusIcon', type: 'iconColumn',
		typeAttributes: {iconName: {fieldName: 'iconName'}, alternativeText: {fieldName: 'status'}}},
	{label: 'Progress', fieldName: 'completionPercent', type: 'progressColumn',
		typeAttributes: {value: {fieldName: 'completionPercent'}}},
	{label: 'Description', fieldName: 'richDescription', type: 'richText'}
];
```

**Your Own Column Types:**

A table never sees the types it passes in `types` itself. They reach only tables created after it, on any page, until the page reloads:

- The `types` property adds your column types to one map that every `customDataTable` in the app shares, until the page reloads.
- The platform datatable copies that map when it creates a table, before your properties reach the table.

To give a table its own column types every time, create a small component that extends `customDataTable`
and declares its own `static customTypes` map.

- Your component has only its JavaScript file, its meta file and the cell templates.
- It has no HTML file of its own, because the datatable supplies the table template.

Each entry in the map is one column type, keyed by the name you use as `type` in a column definition. Each entry has:

- `template`: the HTML template that draws the cell, imported from your component's folder.
- `typeAttributes`: the names of the values your column definition passes to the template.
- `standardCellLayout: true` (optional): keeps the standard cell padding, so the cell lines up with the other columns.

Your map takes the place of the built-in one for this table. To keep the built-in types as well, copy them in first with `...CustomDataTable.customTypes`.

```javascript
import CustomDataTable from 'kern/customDataTable';
import statusBadge from './statusBadge.html';
import recordLink from './recordLink.html';

export default class MyRecordTable extends CustomDataTable
{
	static customTypes = {
		...CustomDataTable.customTypes,
		statusBadge: {template: statusBadge, standardCellLayout: true, typeAttributes: ['status']},
		recordLink: {template: recordLink, standardCellLayout: true, typeAttributes: ['recordUrl', 'label']}
	};
}
```

A cell template reads the cell's own value as `{value}` and each name in `typeAttributes` as `{typeAttributes.<name>}`.
The map above imports two templates, so your component's folder holds both:

```html
<!-- statusBadge.html -->
<template>
	<span class="slds-badge">{typeAttributes.status}</span>
</template>

<!-- recordLink.html -->
<template>
	<a href={typeAttributes.recordUrl}>{typeAttributes.label}</a>
</template>
```

Use your component (here `c-my-record-table`) in place of `kern-custom-data-table`, and name the type and its values in the column
definition:

```javascript
{label: 'Status', fieldName: 'Status__c', type: 'statusBadge', typeAttributes: {status: {fieldName: 'Status__c'}}}
```

---

#### cronExpressionEditor

**Purpose:** Reusable Salesforce cron expression editor with preset, advanced, and custom modes

> **Internal:** this component is not exposed, so you cannot use it in your own components. It is described here because the scheduled job editors embed it, and you see it when you create or edit a scheduled job.

**Usage (inside KernDX):**

```html
<c-cron-expression-editor value={expression} oncronchange={handleChange}></c-cron-expression-editor>
```

| Property                        | Type                | Required | Default | Description                                                                                                                                                       |
|---------------------------------|---------------------|----------|---------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `value`                         | String              | No       | -       | Initial cron expression (input)                                                                                                                                   |
| `cronExpression`                | String (read-only)  | -        | -       | Current built expression (output)                                                                                                                                 |
| `isValid`                       | Boolean (read-only) | -        | -       | Whether the current expression has valid structure                                                                                                                |
| `job-runner-mode`               | Boolean             | No       | `false` | When true the minutes field accepts the grammar the job runner reads (`*`, steps, ranges, lists) and the Every N Minutes preset is offered                        |
| `active-check-interval-minutes` | Number              | No       | -       | How often the active runner checks for due jobs, in minutes; narrows the interval choices to multiples of it and states the effective interval in the description |

**Events:**

- `cronchange`: fires on every expression change (detail: `{value: expressionString, isValid: boolean}`)

**Modes:**

| Mode     | Description                                                                                                                                                                                    |
|----------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Preset   | Frequency-based builder: Hourly, Daily, Weekly, Monthly; Every N Minutes is offered only when the editor's job-runner-mode attribute is set (a job in its own mode fires at most once an hour) |
| Advanced | Field-by-field editor for all 7 Salesforce cron fields (Seconds, Minutes, Hours, Day of Month, Month, Day of Week, Year)                                                                       |
| Custom   | Free-text input for arbitrary cron expressions                                                                                                                                                 |

**Preview Section:**
Always-visible preview showing the monospace cron string and a crontab.guru-style human-readable description (e.g., `0 30 9 ? * MON,WED,FRI` displays as "Every Monday, Wednesday,
and Friday at 9:30 AM").

**Architecture:** Contains two internal modules:

- `constants.js`: option arrays and mode constants
- `cronParser.js`: pure functions: `parseCronExpression()`, `buildCronExpression()`, `describeCronExpression()`

---

### Component Availability Summary

| Component            | Flow Screen | App Page | Record Page | Home Page | Code Only |
|----------------------|:-----------:|:--------:|:-----------:|:---------:|:---------:|
| flowFooter           |     Yes     |    -     |      -      |     -     |     -     |
| jsonViewer           |     Yes     |    -     |      -      |     -     |     -     |
| streamingMonitor     |      -      |   Yes    |     Yes     |    Yes    |     -     |
| searchLookup         |     Yes     |   Yes    |     Yes     |    Yes    |     -     |
| createForm           |     Yes     |   Yes    |     Yes     |    Yes    |     -     |
| sObjectLookup        |      -      |    -     |      -      |     -     |    Yes    |
| paginatedTable       |      -      |    -     |      -      |     -     |    Yes    |
| customDataTable      |      -      |    -     |      -      |     -     |    Yes    |
| scheduledJobDetail   |      -      |    -     |     Yes     |     -     |     -     |
| healthCheck          |      -      |   Yes    |      -      |    Yes    |     -     |
| chainMonitor         |      -      |   Yes    |      -      |     -     |     -     |
| chainStepTimeline    |      -      |   Yes    |     Yes     |     -     |     -     |
| logConsole           |      -      |   Yes    |      -      |     -     |     -     |
| validationErrors     |     Yes     |   Yes    |     Yes     |    Yes    |     -     |

> **Code Only:** These components are exposed for use within custom LWC code but cannot be placed directly via Lightning App Builder.

---

### Complete Component Inventory

Every LWC component in the KernDX framework with its category, exposure status, and test coverage. The total count is in [Strategic Guide - Metrics](Strategic%20Guide%20-%20Metrics.md#lwc-components).

<details>
<summary>Expand the full component inventory</summary>

#### Utility Modules (9 components)

| Component          | Exposed | Jest Tests | Purpose                                     |
|--------------------|:-------:|:----------:|---------------------------------------------|
| `utilityLogger`    |   Yes   |    Yes     | Client-side logging with server correlation |
| `utilityString`    |   Yes   |    Yes     | String formatting and manipulation          |
| `utilityArray`     |   Yes   |    Yes     | Array and collection operations             |
| `utilitySystem`    |   Yes   |    Yes     | Error handling, clipboard, DOM utilities    |
| `utilityRandom`    |   Yes   |    Yes     | UUID and random string generation           |
| `utilityGenerator` |    -    |    Yes     | Counter and array generators                |
| `utilityStreaming` |    -    |    Yes     | Streaming constants and helpers             |
| `utilityScheduledJob` |    -    |    Yes     | Shared timezone-name and parameter-parsing helpers for the ScheduledJob__c components |
| `utilityApiIssueAction` |    -    |    Yes     | Shared helper that runs an action (such as Retry or Dismiss) on an API issue from a quick action |

#### Base Architecture (8 components)

| Component                       | Exposed | Jest Tests | Purpose                                                          |
|---------------------------------|:-------:|:----------:|------------------------------------------------------------------|
| `baseComponent` (internal)      |   Yes   |    Yes     | Base class with modular functionality (exposed, but internal)    |
| `componentBuilder`              |   Yes   |    Yes     | Factory for creating extended base classes (**the only public API**) |
| `componentExtender` (internal)  |   Yes   |    Yes     | Module initialiser for baseComponent (exposed, but internal)     |
| `moduleController`              |   Yes   |    Yes     | Apex controller integration module (exposed, but internal)       |
| `moduleNavigation`              |   Yes   |    Yes     | Page navigation module (exposed, but internal)                   |
| `moduleNotification`            |   Yes   |    Yes     | Toast notification module (exposed, but internal)                |
| `moduleLightningMessageService` |   Yes   |    Yes     | LMS publish/subscribe module (exposed, but internal)             |
| `moduleFlowNavigation`          |   Yes   |    Yes     | Flow navigation events module (exposed, but internal)            |

"Exposed, but internal" means the module can be imported from `kern/`, but you are not meant to use it directly: `ComponentBuilder` loads it for you.

#### Components You Can Use (15 components)

| Component              | Exposed | Jest Tests | Purpose                                                           |
|------------------------|:-------:|:----------:|-------------------------------------------------------------------|
| `flowFooter`           |   Yes   |    Yes     | Flow navigation footer                                            |
| `jsonViewer`           |   Yes   |    Yes     | JSON syntax-highlighted viewer                                    |
| `streamingMonitor`     |   Yes   |    Yes     | Platform Event/CDC monitor                                        |
| `searchLookup`         |   Yes   |    Yes     | Search with [`IF_Search`](reference/apex/IF_Search.md) controller |
| `createForm`           |   Yes   |    Yes     | FieldSet-driven record forms                                      |
| `sObjectLookup`        |   Yes   |    Yes     | SObject record lookup                                             |
| `paginatedTable`       |   Yes   |    Yes     | Paginated datatable wrapper                                       |
| `customDataTable`      |   Yes   |    Yes     | Datatable with custom types                                       |
| `streamingActions`     |   Yes   |    Yes     | Streaming subscribe/publish UI                                    |
| `retryApiIssue`        |   Yes   |    Yes     | Retry failed API issues                                           |
| `dismissApiIssue`      |   Yes   |    Yes     | Mark an API issue resolved without running its request again      |
| `validationErrors`     |   Yes   |    Yes     | Display validation rule errors                                    |
| `scheduledJobDetail`   |   Yes   |    Yes     | View-only record page component for ScheduledJob__c records       |
| `healthCheck`          |   Yes   |    Yes     | Post-install diagnostics with resolver code generator             |
| `featureFlag`          |   Yes   |    Yes     | Cacheable bridge to `UTIL_FeatureFlag.isEnabled()` for the UI      |

#### Internal UI Components (15 components)

| Component                     | Exposed | Jest Tests | Purpose                                                        |
|-------------------------------|:-------:|:----------:|----------------------------------------------------------------|
| `modal`                       |    -    |    Yes     | Reusable modal dialog                                          |
| `notice`                      |    -    |    Yes     | Info notice with icon                                          |
| `baseLookup`                  |    -    |    Yes     | Base lookup component                                          |
| `viewRecord`                  |    -    |    Yes     | Read-only record display                                       |
| `applyRetentionModal`         |    -    |    Yes     | Confirmation modal for applying recommended retention jobs     |
| `classTypeResolverSetupModal` |    -    |    Yes     | Guided setup modal for your org's Class Type Resolver          |
| `kernHome`                    |   Yes   |    Yes     | Kern Home developer control room card layout                   |
| `scheduledJobEditor`          |    -    |    Yes     | ScheduledJob__c editor form (action override via Aura wrapper) |
| `scheduledJobEditorModal`     |    -    |    Yes     | Modal dialog for creating/editing ScheduledJob__c records      |
| `scheduledJobEditorForm`      |    -    |    Yes     | The form the two ScheduledJob__c editors share                 |
| `scheduledJobClassPicker`     |    -    |    Yes     | Class Name field of the scheduled job editors; suggests the org's schedulable classes |
| `cronExpressionEditor`        |    -    |    Yes     | Reusable cron expression editor (preset/advanced/custom), embedded in the scheduled job editors |
| `scheduleChainWatchdogModal`  |    -    |    Yes     | Confirmation modal for the Health Check's one-click Chain Watchdog scheduling |
| `jobRunnerCard`               |    -    |    Yes     | Job runner card on the Health Check readiness banner       |
| `activateJobRunnerModal`      |    -    |    Yes     | Modal dialog that picks how often the job runner checks for due jobs |

#### Streaming Monitor Internals (9 components)

| Component                | Exposed | Jest Tests | Purpose                                                 |
|--------------------------|:-------:|:----------:|---------------------------------------------------------|
| `streamingEvents`        |    -    |    Yes     | Event list with table/timeline views                    |
| `streamingEventFilters`  |    -    |    Yes     | Event filter controls                                   |
| `streamingTimeline`      |    -    |    Yes     | Interactive timeline visualisation                            |
| `streamingEventsHeader`  |    -    |    Yes     | Event header actions                                    |
| `streamingUsageMetrics`  |    -    |    Yes     | Usage metrics charts                                    |
| `streamingUsageFilters`  |    -    |    Yes     | Metrics filter controls                                 |
| `orgLimits`              |    -    |    Yes     | Org limits card grid (worst-first, per-limit usage bars) |
| `streamingSubscriptions` |    -    |    Yes     | Active subscription management                          |
| `streamingSidebar`       |    -    |    Yes     | Toggleable sidebar navigation for the Streaming Monitor |

#### Chain Monitor (7 components)

| Component                 | Exposed | Jest Tests | Purpose                                                                                       |
|---------------------------|:-------:|:----------:|-----------------------------------------------------------------------------------------------|
| `chainMonitor`            |   Yes   |    Yes     | Full-page split-panel container with empApi subscription for live refresh and the header operations control |
| `chainMonitorList`        |    -    |    Yes     | Paginated datatable with filters, sorting, smart row selection, URL links to records          |
| `chainMonitorDetail`      |    -    |    Yes     | Accordion layout: status icon, progress bar, operator action buttons, step timeline, timing, error section, View logs cross-link to the Log Console |
| `chainStepTimeline`       |   Yes   |    Yes     | SLDS timeline with hover popovers showing class, status, duration, continueOnError            |
| `chainLogStream`          |    -    |    Yes     | Live activity stream for one run: Apex-seeded newest entries, then live empApi delivery       |
| `chainAbortModal`         |    -    |    Yes     | Destructive confirmation dialogue for the abort action                                        |
| `chainActionConfirmModal` |    -    |    Yes     | Shared confirmation dialogue for retry, restart, clear stalled, suspend, and resume           |

#### Log Console (4 components)

The browsing and diagnosis surface for captured log entries (see [Logging Guide, The Log Console](Logging%20-%20Guide.md#the-log-console)). Only the
`logConsole` page component is exposed; the rest are internal building blocks.

| Component           | Exposed | Jest Tests | Purpose                                                                       |
|---------------------|:-------:|:----------:|-------------------------------------------------------------------------------|
| `logConsole`        |   Yes   |    Yes     | Container: filters, Problem summary and Individual entries views, ribbon, drawer |
| `logConsoleTable`   |    -    |    Yes     | Datatable extension with the colour-coded severity badge column               |
| `logConsoleDetail`  |    -    |    Yes     | Tabbed detail drawer with the correlated execution timeline                   |
| `logConsoleContext` |    -    |     -*     | Service module mapping execution-context values to readable names             |

*`logConsoleContext` has no dedicated test file; it is covered to 100% through the other console components' Jest suites.

#### Data Masking Advisor (10 components)

The console and dialogs behind the **Data Masking Advisor** (see [Security Guide, Data Masking](Security%20-%20Guide.md#data-masking)). Only the
`dataMaskingAdvisor` page component is exposed; the rest are internal building blocks.

| Component                      | Exposed | Jest Tests | Purpose                                                       |
|--------------------------------|:-------:|:----------:|---------------------------------------------------------------|
| `dataMaskingAdvisor`           |   Yes   |    Yes     | Advisor console: object picker, posture review, scan, configure |
| `maskingRulePicker`            |    -    |    Yes     | Searchable per-field masking-rule combobox                    |
| `maskingRuleDetail`            |    -    |    Yes     | Rule-detail popup for a configured rule                       |
| `maskingAddRuleMenu`           |    -    |    Yes     | Menu for attaching a masking rule to a field                  |
| `maskingAddObjectDialog`       |    -    |    Yes     | "Add object" grouped search dialog for the scan               |
| `maskingReviewDialog`          |    -    |    Yes     | Review dialog for proposed masking reclassifications          |
| `maskingExportModal`           |    -    |    Yes     | Export dialog for the deployable masking configuration        |
| `maskingInventoryExportDialog` |    -    |    Yes     | Regulated-field inventory export dialog (CSV / JSON)          |
| `generateBundleModal`          |    -    |    Yes     | Confirmation dialog for the Generate-bundle flow              |
| `maskingFieldTypeLabels`       |    -    |    Yes     | Shared field-type label helper for the masking LWCs           |

#### Demo Components (1 component)

| Component            | Exposed | Jest Tests | Purpose                                                 |
|----------------------|:-------:|:----------:|---------------------------------------------------------|
| `apiTestHarnessForm` |   Yes   |    Yes     | Interactive form for invoking inbound and outbound APIs |

</details>

---

### Test Coverage Summary

| Category            | Components | With Jest Tests | Coverage |
|---------------------|:----------:|:---------------:|:--------:|
| Utility Modules     |     9      |        9        |   100%   |
| Base Architecture   |     8      |        8        |   100%   |
| You Can Use         |     15     |       15        |   100%   |
| Internal UI         |     15     |       15        |   100%   |
| Streaming Internals |     9      |        9        |   100%   |
| Chain Monitor       |     7      |        7        |   100%   |
| Log Console         |     4      |        3        |   100%   |
| Data Masking Advisor |    10     |       10        |   100%   |
| Demo Components     |     1      |        1        |   100%   |
| **TOTAL**           | [Metrics](Strategic%20Guide%20-%20Metrics.md#lwc-components) | All but `logConsoleContext` | **100%** |

> **Note:** Every LWC component is held at 100% Jest coverage (`logConsoleContext` is covered through the other Log Console components' test suites rather than a dedicated test file). To check it, run the coverage command in [Jest Test Setup](#jest-test-setup).
