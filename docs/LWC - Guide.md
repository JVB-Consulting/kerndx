---
navOrder: 30
---

# LWC - Guide

**Framework:** KernDX
**Package Type:** Managed Package

**Target Audience:**

- **Developers** - Building [Lightning Web Components](https://developer.salesforce.com/docs/platform/lwc/guide) using KernDX's base classes, utilities, and pre-built components
- **Architects** - Designing component architectures with proper separation of concerns and reusable patterns
- **Business Analysts** - Understanding available components and their configuration options

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [Quick Navigation](#quick-navigation)
2. [Overview](#overview)
    - [Component Categories](#component-categories)
    - [Key Benefits](#key-benefits)
    - [KernDX vs OOTB: LWC Patterns Comparison](#kerndx-vs-ootb-lwc-patterns-comparison)
3. [Architecture](#architecture)
    - [Architecture Diagram](#architecture-diagram)
4. [Quick Start](#quick-start)
5. [Utility Modules](#utility-modules)
    - [utilityLogger - Client-Side Logging](#utilitylogger---client-side-logging)
        - [Log Level Constants](#log-level-constants)
        - [Basic Logging](#basic-logging)
        - [Correlation Tracking](#correlation-tracking)
        - [Automatic Correlation with withCorrelation](#automatic-correlation-with-withcorrelation)
        - [Performance Timing](#performance-timing)
        - [Server Integration](#server-integration)
    - [utilityString - String Manipulation](#utilitystring---string-manipulation)
        - [Template String Formatting](#template-string-formatting)
        - [Case Conversion](#case-conversion)
        - [Character Insertion](#character-insertion)
        - [Currency Formatting](#currency-formatting)
        - [Constants](#constants)
    - [utilityArray - Array Operations](#utilityarray---array-operations)
        - [Convert Array to Keyed Object](#convert-array-to-keyed-object)
        - [Extract Objects by ID](#extract-objects-by-id)
        - [Filter Objects by ID](#filter-objects-by-id)
    - [utilitySystem - System Utilities](#utilitysystem---system-utilities)
        - [Copy to Clipboard](#copy-to-clipboard)
        - [Reduce Errors](#reduce-errors)
        - [Set Property on Object](#set-property-on-object)
        - [Flatten Object](#flatten-object)
        - [Sort Array of Objects](#sort-array-of-objects)
    - [utilityRandom - Random Generation](#utilityrandom---random-generation)
        - [Generate UUID](#generate-uuid)
        - [Random Strings](#random-strings)
    - [utilityGenerator - Generator Functions](#utilitygenerator---generator-functions)
        - [Counter Generator](#counter-generator)
        - [Array Generator](#array-generator)
    - [featureFlag - Feature Flag Bridge](#featureflag---feature-flag-bridge)
        - [LDS Cache Staleness — Not for Client-Side Authorization](#lds-cache-staleness--not-for-client-side-authorization)
6. [Base Component Architecture](#base-component-architecture)
    - [ComponentBuilder Pattern](#componentbuilder-pattern)
    - [Available Modules](#available-modules)
    - [How Modules Work](#how-modules-work)
        - [Module Architecture](#module-architecture)
        - [Module Files](#module-files)
        - [Why This Pattern?](#why-this-pattern)
        - [When to Use Which Modules](#when-to-use-which-modules)
        - [Extending at Runtime (Advanced — Internal API)](#extending-at-runtime-advanced--internal-api)
        - [Performance Consideration](#performance-consideration)
    - [BaseComponent API Reference](#basecomponent-api-reference)
        - [Notification Methods](#notification-methods)
        - [Navigation Methods](#navigation-methods)
        - [Lightning Message Service Methods](#lightning-message-service-methods)
        - [Controller Methods](#controller-methods)
        - [Flow Navigation Methods](#flow-navigation-methods)
        - [Utility Methods](#utility-methods)
        - [Properties](#properties)
7. [Flow Screen Components](#flow-screen-components)
    - [flowFooter - Flow Navigation](#flowfooter---flow-navigation)
    - [jsonViewer - JSON Display](#jsonviewer---json-display)
8. [Page Components](#page-components)
    - [streamingMonitor - Event Monitoring](#streamingmonitor---event-monitoring)
    - [searchLookup - Search Interface](#searchlookup---search-interface)
    - [scheduledJobDetail - Scheduled Job Detail](#scheduledjobdetail---scheduled-job-detail)
    - [healthCheck - Post-Install Diagnostics](#healthcheck---post-install-diagnostics)
9. [Form Components](#form-components)
    - [createForm - Dynamic Record Forms](#createform---dynamic-record-forms)
    - [sObjectLookup - Object Lookup](#sobjectlookup---object-lookup)
10. [Internal Components Reference](#internal-components-reference)
    - [UI Support Components](#ui-support-components)
    - [Streaming Monitor Components](#streaming-monitor-components)
    - [Chain Monitor Components](#chain-monitor-components)
11. [Demo Components](#demo-components)
12. [Testing](#testing)
    - [Jest Test Setup](#jest-test-setup)
    - [Mocking KernDX Modules](#mocking-kerndx-modules)
    - [Test Patterns](#test-patterns)
        - [Testing Utility Modules](#testing-utility-modules)
        - [Testing Components](#testing-components)
13. [Anti-Patterns](#anti-patterns)
14. [Best Practices](#best-practices)
    - [Use ComponentBuilder for New Components](#use-componentbuilder-for-new-components)
    - [Use Utility Modules for Common Operations](#use-utility-modules-for-common-operations)
    - [Correlate Client and Server Logs](#correlate-client-and-server-logs)
    - [Handle Errors Consistently](#handle-errors-consistently)
    - [Clean Up Subscriptions](#clean-up-subscriptions)
    - [Add JSDoc to Component Classes and Methods](#add-jsdoc-to-component-classes-and-methods)
15. [Troubleshooting](#troubleshooting)
    - [Common Issues](#common-issues)
    - [Debugging Tips](#debugging-tips)
16. [Related Documentation](#related-documentation)
17. [Appendix: Droppable Components Quick Reference](#appendix-droppable-components-quick-reference)
    - [Flow Screen Components](#flow-screen-components-1)
        - [flowFooter](#flowfooter)
        - [jsonViewer](#jsonviewer)
    - [App Page / Record Page / Home Page Components](#app-page--record-page--home-page-components)
        - [streamingMonitor](#streamingmonitor)
        - [searchLookup](#searchlookup)
        - [createForm](#createform)
        - [scheduledJobDetail](#scheduledjobdetail)
        - [healthCheck](#healthcheck)
    - [Programmatic Components (for Custom LWC Development)](#programmatic-components-for-custom-lwc-development)
        - [sObjectLookup](#sobjectlookup)
        - [paginatedTable](#paginatedtable)
        - [customDataTable](#customdatatable)
        - [cronExpressionEditor](#cronexpressioneditor)
    - [Component Availability Summary](#component-availability-summary)
    - [Complete Component Inventory](#complete-component-inventory)
        - [Utility Modules (7 components)](#utility-modules-7-components)
        - [Base Architecture (8 components)](#base-architecture-8-components)
        - [Subscriber-Usable Components (15 components)](#subscriber-usable-components-15-components)
        - [Internal UI Components (9 components)](#internal-ui-components-9-components)
        - [Streaming Monitor Internals (9 components)](#streaming-monitor-internals-9-components)
        - [Chain Monitor (4 components)](#chain-monitor-4-components)
        - [Data Masking Advisor (10 components)](#data-masking-advisor-10-components)
        - [Demo Components (1 component)](#demo-components-1-component)
    - [Test Coverage Summary](#test-coverage-summary)

</details>

---

## Quick Navigation

| I am a...     | I need to...                      | Go to...                                                                         |
|---------------|-----------------------------------|----------------------------------------------------------------------------------|
| **Architect** | Understand component architecture | [Base Component Architecture](#base-component-architecture)                      |
| **Architect** | Review available modules          | [Utility Modules](#utility-modules)                                              |
| **Developer** | Build my first component          | [Quick Start](#quick-start)                                                      |
| **Developer** | Write Jest tests                  | [Testing](#testing)                                                              |
| **Developer** | Use utility modules               | [Utility Modules](#utility-modules)                                              |
| **Analyst**   | See available components          | [Appendix: Droppable Components](#appendix-droppable-components-quick-reference) |
| **Analyst**   | Find flow screen components       | [Flow Screen Components](#flow-screen-components)                                |

---

## Overview

KernDX provides a comprehensive suite of [Lightning Web Components](https://developer.salesforce.com/docs/platform/lwc/guide) designed to accelerate development while maintaining
enterprise-grade patterns. The framework includes utility modules, base classes for component inheritance, and pre-built components for common use cases.

> **Responsibilities:** The LWC framework provides base classes, utility modules, and pre-built components. Components handle UI presentation
> and user interaction. They do not contain business logic -- Apex controllers and trigger actions own that. Keep components thin: call
> server methods via `callControllerMethod()` and display the results.

> **LWC Framework Scope:** 63 components across 7 utility modules, base architecture, Flow screen components, page components, form components,
> data masking advisor components, and admin components. Backed by 65 Jest test files containing ~2,640 test cases (~38K lines of test code) at 100% coverage.

> For current framework statistics, see [Metrics](Strategic%20Guide%20-%20Metrics.md).

> **When NOT to use this pattern:**
> - Simple UI requirements where a standard Lightning base component (e.g., `lightning-record-form`) does the job
> - `ComponentBuilder` with a single module has minimal overhead and is still the recommended approach for all custom components

### Component Categories

```text
+-------------------------------------------------------------------------+
|                         KERN LWC ARCHITECTURE                           |
+-------------------------------------------------------------------------+
|                                                                         |
|  SUBSCRIBER-USABLE COMPONENTS                                           |
|  ============================                                           |
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

> **Implementation detail:** `baseComponent`, `componentExtender`, and the `module*` components shown in the diagram are internal
> infrastructure. `ComponentBuilder` is the only public API — always use `extends ComponentBuilder('module1', 'module2')` to build components.

### Key Benefits

| Benefit                  | Description                                                                                                                                                                        |
|--------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Consistent Patterns**  | All components follow the same coding standards and conventions                                                                                                                    |
| **Pre-Built Utilities**  | Common operations (logging, string manipulation, arrays) ready to use                                                                                                              |
| **Modular Architecture** | ComponentBuilder pattern enables selective functionality inclusion                                                                                                                 |
| **Server Correlation**   | Client-side logging correlates with Apex logs via [`LOG_Builder`](reference/apex/LOG_Builder.md) for debugging                                                                     |
| **Flow Integration**     | Multiple components designed for [Flow Screen](https://developer.salesforce.com/docs/platform/lwc/guide/use-flow.html) use                                                         |
| **Streaming Support**    | Complete [Platform Event](https://developer.salesforce.com/docs/atlas.en-us.platform_events.meta/platform_events/platform_events_intro.htm) monitoring and subscription management |
| **100% Test Coverage**   | All utility modules have comprehensive [Jest](https://developer.salesforce.com/docs/platform/lwc/guide/testing.html) tests                                                         |

### KernDX vs OOTB: LWC Patterns Comparison

| Feature                 | KernDX LWC Framework                          | Standard LWC Development                                                                                                                         |
|-------------------------|-----------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------|
| **Base Component**      | ComponentBuilder with modular functionality   | Manual mixin composition or monolithic base                                                                                                      |
| **Client Logging**      | utilityLogger with server correlation         | console.log with no persistence                                                                                                                  |
| **String Utilities**    | utilityString module                          | Manual implementation or external libraries                                                                                                      |
| **Toast Notifications** | Built-in via moduleNotification               | Manual [ShowToastEvent](https://developer.salesforce.com/docs/platform/lwc/guide/use-toast.html) import                                          |
| **Navigation**          | Built-in via moduleNavigation                 | Manual [NavigationMixin](https://developer.salesforce.com/docs/platform/lwc/guide/use-navigate.html) composition                                 |
| **LMS Integration**     | Built-in via moduleLightningMessageService    | Manual [Lightning Message Service](https://developer.salesforce.com/docs/platform/lwc/guide/use-message-channel.html) subscribe/publish handling |
| **Flow Navigation**     | Built-in via moduleFlowNavigation             | Manual [FlowNavigationNextEvent](https://developer.salesforce.com/docs/platform/lwc/guide/use-flow.html) handling                                |
| **Data Tables**         | Pre-built with pagination, sorting, selection | Build from scratch with [lightning-datatable](https://developer.salesforce.com/docs/component-library/bundle/lightning-datatable/documentation)  |

---

## Architecture

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

The KernDX LWC framework is built on three architectural pillars:

1. **Utility Modules** - Stateless JavaScript service modules (`utilityLogger`, `utilityString`,
   `utilityArray`, `utilitySystem`, `utilityRandom`, `utilityGenerator`, `utilityStreaming`) that provide common
   operations as importable functions. These are not components themselves but are consumed by components via
   ES module imports.

2. **ComponentBuilder / Base Component** - A factory function that creates base classes with selectively
   mixed-in functionality modules (notification, navigation, controller, lightning-message, flow-navigation).
   Components extend the result of `ComponentBuilder(...)` rather than `LightningElement` directly. See
   [Base Component Architecture](#base-component-architecture) for the full module system details.

3. **Pre-Built Components** - Production-ready components for common patterns: Flow screen components
   (`flowFooter`, `jsonViewer`), page components (`streamingMonitor`, `searchLookup`,
   `scheduledJobDetail`), form components (`createForm`, `sObjectLookup`), and scheduling components
   (`scheduledJobEditor`, `scheduledJobEditorModal`, `cronExpressionEditor`).

All components use Allman bracing, tabs for indentation, single quotes, and follow the conventions defined in
[`docs/Code Conventions - Guide.md`](./Code%20Conventions%20-%20Guide.md). Every component requires a `.js-meta.xml` file with `apiVersion` 67.0.

---

## Quick Start

To create a new LWC component using the KernDX framework, extend `ComponentBuilder` with the modules you need:

```javascript
import {ComponentBuilder} from 'c/componentBuilder';

export default class MyComponent extends ComponentBuilder('notification', 'controller')
{
	async handleSave()
	{
		const result = await this.callControllerMethod('saveRecord', {record: this.record});
		this.showSuccessToast('Record saved successfully');
	}
}
```

This gives your component toast notifications and Apex controller integration. Add `'navigation'` to enable
record page navigation, or use `'all'` to include every module. Every new component should use
`ComponentBuilder` rather than extending `LightningElement` directly.

For deeper coverage, continue reading the sections below.

---

## Utility Modules

Utility modules are JavaScript service modules that provide common functionality. They are imported and used within your components but are not placeable on pages themselves.

### utilityLogger - Client-Side Logging

Client-side logging utility with server correlation, performance timing, and async persistence to Apex.

**Import:**

```javascript
import utilityLogger, {LogLevel} from 'c/utilityLogger';
// Or import specific functions
import {debug, info, warn, error, startCorrelation, startTimer} from 'c/utilityLogger';
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
import {debug, info, warn, error} from 'c/utilityLogger';

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

Correlation IDs link related log entries across client and server operations.

```javascript
import {startCorrelation, endCorrelation, getCorrelationId, info} from 'c/utilityLogger';

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
import {withCorrelation} from 'c/utilityLogger';

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
import {startTimer, info} from 'c/utilityLogger';

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

Logs are automatically persisted to Apex when:

- `endCorrelation()` is called
- Buffer reaches capacity
- Page unloads (best effort)

The server automatically sets the correlation context to link client and Apex logs via [`LOG_Builder`](reference/apex/LOG_Builder.md), ensuring LWC logs appear in `LogEntry__c`
with proper correlation and context.

---

### utilityString - String Manipulation

Common string utility methods for formatting, case conversion, and text manipulation.

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
} from 'c/utilityString';
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

Helper functions for array and object collection operations.

**Import:**

```javascript
import {
	convertObjectArrayToObject,
	extractListOfObjectsById,
	filterObjectListById
} from 'c/utilityArray';
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

System-level helper functions for DOM manipulation, error handling, and clipboard operations.

**Import:**

```javascript
import {
	copyToClipBoard,
	reduceErrors,
	setPropertyOnObject,
	flattenObject,
	sortBy
} from 'c/utilitySystem';
```

#### Copy to Clipboard

```javascript
// Copy text to user's clipboard
await copyToClipBoard('Text to copy');
```

#### Reduce Errors

Normalises various Salesforce error shapes into a single human-readable string.

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

In most cases you don't need to call `reduceErrors` yourself — pass the raw error
straight into `showErrorToast` and the notification module normalises it for you:

```javascript
catch (error)
{
	this.showErrorToast(error);
}
```

Reach for `reduceErrors` directly when you need the normalised string for logging,
analytics, or non-toast UI (e.g. inline error text).

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

Functions for generating random strings, UUIDs, and values.

**Import:**

```javascript
import {
	generateUUID,
	getRandomAlphaNumericString,
	getRandomAlphaString,
	getRandomNumericString
} from 'c/utilityRandom';
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

Generator utilities for iterating and counting.

**Import:**

```javascript
import {counter, arrayGenerator} from 'c/utilityGenerator';
```

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

Resolves a `FeatureFlag__mdt` flag for the running user via the `CTRL_FeatureFlag.isEnabled` cacheable Apex
method, so LWC consumers see the same evaluation result Apex consumers see (`UTIL_FeatureFlag.isEnabled`).

**Import:**

```javascript
import {isFlagEnabled} from 'c/featureFlag';
```

**Usage:**

```javascript
import {ComponentBuilder} from 'c/componentBuilder';
import {isFlagEnabled} from 'c/featureFlag';

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

#### LDS Cache Staleness — Not for Client-Side Authorization

The bridge resolves through `CTRL_FeatureFlag.isEnabled`, which is annotated `@AuraEnabled(cacheable=true)`.
Salesforce's Lightning Data Service (LDS) cache keys cacheable results by `(user session, parameter)` —
direct cross-user contamination is not a real risk, but **stale-cache propagation after permission-set
changes is**:

- An admin assigns or revokes a permission set that flips a flag's strategy match for a user.
- The user's LWC client continues to serve the previously-cached `isFlagEnabled` value until either the
  page reloads OR the wire adapter fires with different parameters (it doesn't — the flag name is constant).

**Contract:** subscribers should not use `c/featureFlag` for client-side authorization gates that need to
react to runtime permission changes within a session. Use it for UX-shaping decisions (which panel to
render, whether a hint chip is visible) — Apex enforcement is still the authoritative authorization layer.

If a hard authorization decision must be flag-gated, evaluate the flag inside the Apex controller method
that performs the protected operation, not on the LWC client.

---

## Base Component Architecture

KernDX provides a modular base component architecture that allows you to selectively include functionality in your components. The `ComponentBuilder` factory function creates a
base class with the specified functionality modules mixed in, and utility modules provide common operations (logging, string formatting, arrays) as importable services.

### ComponentBuilder Pattern

The `ComponentBuilder` factory function creates a base class with the specified functionality modules mixed in.

**Import:**

```javascript
import {ComponentBuilder} from 'c/componentBuilder';
```

**Basic Usage:**

```javascript
import {ComponentBuilder} from 'c/componentBuilder';

// Include specific modules
export default class MyComponent extends ComponentBuilder('notification', 'controller')
{
	// Component now has notification and controller methods available

	async handleClick()
	{
		try
		{
			const result = await this.callControllerMethod('getAccounts', {});
			this.showSuccessToast('Accounts loaded');
		}
		catch (error)
		{
			this.showErrorToast('Failed to load accounts');
		}
	}
}
```

**Include All Modules:**

```javascript
import {ComponentBuilder} from 'c/componentBuilder';

export default class FullFeaturedComponent extends ComponentBuilder('all')
{
	// All modules available: notification, navigation, lightning-message, controller, flow-navigation
}
```

### Available Modules

| Module              | Functionality Included                                                                                                                                                                                    |
|---------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `notification`      | [Toast](https://developer.salesforce.com/docs/platform/lwc/guide/use-toast.html) notifications: `showSuccessToast()`, `showErrorToast()`, `showWarningToast()`, `showInfoToast()`, `customNotification()` |
| `navigation`        | Page [navigation](https://developer.salesforce.com/docs/platform/lwc/guide/use-navigate.html): `redirectToRecordPage()`, `generateRecordPageURL()`                                                        |
| `lightning-message` | [LMS](https://developer.salesforce.com/docs/platform/lwc/guide/use-message-channel.html): `addMessageChannelSubscription()`, `publishLightningMessage()`, `clearSubscriptions()`                          |
| `controller`        | [Apex calls](https://developer.salesforce.com/docs/platform/lwc/guide/apex.html): `callControllerMethod()`, `handleWireResponse()`                                                                        |
| `flow-navigation`   | [Flow events](https://developer.salesforce.com/docs/platform/lwc/guide/use-flow.html): `dispatchFlowNextEvent()`, `dispatchFlowBackEvent()`, `dispatchFlowFinishEvent()`                                  |
| `all`               | All of the above                                                                                                                                                                                          |

### How Modules Work

> **Note:** This section describes internal implementation details. `ComponentBuilder` is the only public API —
> the names `baseComponent` and `componentExtender` shown below are internal components that should not be
> imported directly.

The module system uses a **runtime method injection pattern**. When you specify modules in ComponentBuilder, those modules add methods directly to your component instance at
construction time.

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
| `c/moduleNotification`            | `initialiseNotificationModule(component)`     | Adds toast methods                                                                |
| `c/moduleNavigation`              | `initialiseNavigationModule(component)`       | Adds navigation methods                                                           |
| `c/moduleLightningMessageService` | `initialiseLightningMessageModule(component)` | Adds LMS methods                                                                  |
| `c/moduleController`              | `initialiseControllerModule(component)`       | Adds Apex call methods                                                            |
| `c/moduleFlowNavigation`          | `initialiseFlowNavigationModule(component)`   | Adds Flow event methods                                                           |
| `c/componentExtender` (internal)  | `componentExtender(component, ...modules)`    | Orchestrates module loading (used by `ComponentBuilder` — do not import directly) |

#### Why This Pattern?

1. **Selective Loading** - Only include the functionality you need, reducing component overhead
2. **No Inheritance Chain** - Unlike traditional mixins, methods are added directly to the instance
3. **Easy Testing** - Each module can be tested independently
4. **Framework Agnostic** - The pattern works with any LWC base class

#### When to Use Which Modules

| Scenario                              | Recommended Modules               |
|---------------------------------------|-----------------------------------|
| Simple form with save confirmation    | `notification`                    |
| Record page with navigation           | `notification`, `navigation`      |
| Component communicating with siblings | `lightning-message`               |
| Data loading from Apex                | `controller`, `notification`      |
| Flow screen component                 | `notification`, `flow-navigation` |
| Full-featured component               | `all`                             |

#### Extending at Runtime (Advanced — Internal API)

> **Internal implementation detail:** `componentExtender` is an internal component used by `ComponentBuilder`.
> The pattern below is only needed for rare cases where modules must be loaded conditionally after construction.
> For all standard use cases, specify modules in `ComponentBuilder(...)` directly.

If you need to add a module after construction, use `componentExtender` directly:

```javascript
import {componentExtender} from 'c/componentExtender';

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

Using `'all'` is convenient but initialises all 5 modules regardless of need. For components where performance is critical (e.g., rendered in lists), specify only the modules you
actually use.

### BaseComponent API Reference

When using ComponentBuilder, your component inherits the following API:

#### Notification Methods

```javascript
// Simple toasts
this.showSuccessToast('Record saved');
this.showErrorToast('Operation failed');
this.showWarningToast('Please review');
this.showInfoToast('Processing...');

// Custom notification
this.customNotification('Custom Title', 'Custom message', 'success', 'dismissable');

// Factory for complex notifications
const notify = this.customNotificationFactory();
notify('Title', 'Message', 'error', 'sticky');
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
// Call Apex method
const result = await this.callControllerMethod('getAccountData', {
	accountId: this.recordId
});

// Handle wire response
@wire(getRecord, {recordId: '$recordId', fields: FIELDS})
wiredRecord(result)
{
	this.handleWireResponse(result, (data) =>
	{
		this.account = data;
	});
}
```

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
this.consoleError('Error occurred', error);
```

#### Properties

```javascript
this.isLoading  // Boolean for spinner control
this.messageContext  // LMS context (injected by framework)
this.activeMessageSubscriptions  // Array of active LMS subscriptions
```

---

## Flow Screen Components

Components designed for use in [Flow Screens](https://developer.salesforce.com/docs/platform/lwc/guide/use-flow.html) with `lightning__FlowScreen` target.

### flowFooter - Flow Navigation

Reusable flow screen footer with Back/Next navigation buttons.

**Targets:** `lightning__FlowScreen`

**Usage in Flow Screen:**
Add via Flow Builder as a screen component.

**Usage as Child Component:**

```html
<template>
    <c-flow-footer
        is-child-component
        hide-back-button={hideBack}
        disable-next={isNextDisabled}
        next-title="Continue"
        previous-title="Go Back"
        onnavigationevent={handleNavigation}>
    </c-flow-footer>
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

**Properties:**

| Property                   | Type    | Default | Description                          |
|----------------------------|---------|---------|--------------------------------------|
| `hideBackButton`           | Boolean | false   | Hide the Back button                 |
| `disableNext`              | Boolean | false   | Disable the Next button              |
| `nextTitle`                | String  | 'Next'  | Label for Next button                |
| `previousTitle`            | String  | 'Back'  | Label for Back button                |
| `overrideNextToFinish`     | Boolean | false   | Change Next to Finish event          |
| `overridePreviousToFinish` | Boolean | false   | Change Back to Finish event          |
| `isChildComponent`         | Boolean | false   | Set true when embedded in parent LWC |

---

### jsonViewer - JSON Display

Read-only JSON viewer with syntax highlighting.

**Targets:** `lightning__FlowScreen`

**Properties:**

| Property   | Type   | Description          |
|------------|--------|----------------------|
| `jsonText` | String | JSON data to display |

**Features:**

- Colour-coded syntax highlighting
- Keys, strings, numbers, booleans, null each have distinct colours
- Handles invalid JSON gracefully with error message
- Collapsible sections for nested objects

---

## Page Components

Components designed for App Pages, Record Pages, and Home Pages.

### streamingMonitor - Event Monitoring

Comprehensive real-time streaming event monitor
for [Platform Events](https://developer.salesforce.com/docs/atlas.en-us.platform_events.meta/platform_events/platform_events_intro.htm), CDC, PushTopic, and Generic events.

**Targets:** `lightning__AppPage`, `lightning__RecordPage`, `lightning__HomePage`

**Features:**

- Subscribe/unsubscribe to event channels
- Filter events by channel, payload content, time range
- Table and Timeline views (D3.js visualisation)
- Publish events for testing
- View org limits and event usage metrics
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

### searchLookup - Search Interface

Search lookup component supporting custom controllers or the [`IF_Search`](reference/apex/IF_Search.md) interface.

**Targets:** `lightning__FlowScreen`, `lightning__AppPage`, `lightning__HomePage`, `lightning__RecordPage`

**Properties:**

| Property                     | Type   | Required | Description                                                             |
|------------------------------|--------|----------|-------------------------------------------------------------------------|
| `controllerName`             | String | Yes      | Apex controller implementing [`IF_Search`](reference/apex/IF_Search.md) |
| `name`                       | String | No       | Component name for identification                                       |
| `fieldLabel`                 | String | No       | Label displayed above search input                                      |
| `resultUniqueId`             | String | No       | Field for unique result ID (default: 'Id')                              |
| `controllerSearchParameters` | Object | No       | Additional search parameters                                            |
| `preselectedRecord`          | Object | No       | Record to pre-populate                                                  |

**Controller Interface:**

```apex
public with sharing class MySearchController implements IF_Search
{
	public Object search(Object searchTerm, Map<String, Object> searchParameters)
	{
		// Return search results
	}
}
```

---

### scheduledJobDetail - Scheduled Job Detail

View-only record page component for `ScheduledJob__c` records. Displays all fields read-only with embedded cron descriptions
and dynamic parameter tables.

**Targets:** `lightning__RecordPage` (ScheduledJob__c only)

**Features:**

- Displays scheduler name, class name, active status, description, cron expression with human-readable description
- Shows parameter values as structured label/value pairs when the class implements [`IF_Schedulable`](reference/apex/IF_Schedulable.md)
- Falls back to raw JSON display for plain `Schedulable` classes

**Related Components:** Editing is handled by `scheduledJobEditor` (action override via `scheduledJobEditorOverride` Aura wrapper)
and `scheduledJobEditorModal` for inline editing. The editor embeds `cronExpressionEditor`
(see [Programmatic Components](#cronexpressioneditor)) and renders dynamic parameter forms via `CTRL_ScheduledJob`.

---

### healthCheck - Post-Install Diagnostics

Runs 7 diagnostic checks to verify post-install configuration and operational health.

**Targets:** `lightning__HomePage`

**Checks:**

1. **Organisation Cache** — Platform Cache partition allocated (Fail if missing)
2. **Session Cache** — Session partition allocated (Warn if missing)
3. **Trusted Site** — CSP Trusted URL configured for the org domain (Fail if missing)
4. **Class Type Resolver** — `ClassTypeResolver__mdt` record configured with a valid resolver class (Warn if missing, with Setup action)
5. **Data Retention** — Scheduled purge jobs (`SCHED_PurgeRecords`) configured for framework data objects: Log Entry, API Call, API Issue, Async Chain Execution (Warn if any
   unconfigured; item disappears from the card once all four are configured)
6. **Data Masking** — masking posture across the org's configured targets (Warn on dead configuration — an active target pointing at an inactive or missing rule — or when almost
   nothing is masked yet; the warning's action opens the [Data Masking Advisor](Data%20Masking%20-%20Guide.md#the-data-masking-advisor))
7. **Custom Object Coverage** — how much of your own custom data carries masking (Warn when sensitive custom objects are left unmasked; the action opens the Data Masking Advisor)

**Features:**

- Two-section layout: **Action required** (fail items, red heading) rendered above **Review recommended** (warn items, neutral heading); items sorted by priority within each
  section
- All-green state: slim green success banner when every check passes
- Headline pluralises correctly ("1 warning" vs "2 warnings")
- **Setup action** on Class Type Resolver — opens a modal with a code generator
- **Data Retention** renders two buttons side-by-side:
    - **Apply Recommended Retention** — opens a confirmation modal listing the four purge jobs to create (90-day retention, batch size 2000, `CreatedDate` field, inactive by
      default). Confirming creates all four `ScheduledJob__c` records in a single transaction.
    - **Customize each job →** — expands the Data Retention row into a full-width block with a "customizing N jobs" headline, a back-to-apply link, a help paragraph, and a sub-row
      per unconfigured framework object. Each sub-row shows record count (singular/plural correct, locale-formatted), the retention in days, and a **Set up** button that opens
      `scheduledJobEditorModal` prefilled with the object's defaults and the Class Name field read-only. After saving a sub-row, the list auto-refreshes and drops the configured
      object.
- Namespace-agnostic: `schedulerClassName` is populated server-side from `SCHED_PurgeRecords.class.getName()`, so the UX works identically across managed-package installs and any
  rebranded builds.
- Refresh button to re-run checks after configuration changes

**Controller:** `CTRL_HealthCheck` — returns `List<DTO_HealthCheckResult>` with `name`, `status`, `detail`, `priority` (drives in-section sort), optional `actionLabel`, and
optional `List<DTO_ObjectRecordCount> recordCounts` (object label + count). Retention-specific payload comes from `getRetentionProposals()` → `List<DTO_RetentionProposal>` (nested
inside `CTRL_HealthCheck`); `applyRetentionRecommendations(proposalsJson)` commits the one-click flow.

---

## Form Components

Components for creating and editing records.

### createForm - Dynamic Record Forms

Creates SObject forms dynamically using [FieldSet](https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_fieldset.htm) configuration.

**Targets:** `lightning__FlowScreen`, `lightning__AppPage`, `lightning__HomePage`, `lightning__RecordPage`

**Properties:**

| Property          | Type    | Required | Description                   |
|-------------------|---------|----------|-------------------------------|
| `objectApiName`   | String  | Yes      | API name of the SObject       |
| `fieldSetApiName` | String  | Yes      | API name of the FieldSet      |
| `recordId`        | String  | No       | Record ID for edit/clone mode |
| `formHeading`     | String  | No       | Heading displayed above form  |
| `isSaveMode`      | Boolean | No       | Show Save button              |
| `isUpdateMode`    | Boolean | No       | Enable update mode            |

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
} from 'c/createForm';
```

---

### sObjectLookup - Object Lookup

Lookup component for searching SObject records by field.

**Properties:**

| Property         | Type   | Description                       |
|------------------|--------|-----------------------------------|
| `objectApiName`  | String | API name of the SObject to search |
| `displayFields`  | Array  | Fields to display in results      |
| `searchTerm`     | String | Current search term               |
| `recordId`       | String | Selected record ID                |
| `selectedRecord` | Object | Full selected record              |
| `iconName`       | String | Icon to display                   |

**Usage:**

```html
<c-s-object-lookup
    object-api-name="Account"
    display-fields={displayFields}
    onrecordselect={handleRecordSelect}>
</c-s-object-lookup>
```

---

## Internal Components Reference

These components are used internally by the framework or as building blocks. They are not directly placeable but understanding them helps when extending the framework.

### UI Support Components

| Component                     | Purpose                                                        |
|-------------------------------|----------------------------------------------------------------|
| `modal`                       | Reusable modal dialog with show/hide API                       |
| `notice`                      | Info notice with icon                                          |
| `baseLookup`                  | Base class for lookup components                               |
| `viewRecord`                  | Read-only record display                                       |
| `applyRetentionModal`         | Confirmation modal for applying recommended retention jobs     |
| `classTypeResolverSetupModal` | Guided setup modal for subscriber Class Type Resolver          |
| `kernHome`                    | Developer control room (Kern Home) card layout                 |
| `scheduledJobEditor`          | ScheduledJob__c editor form (action override via Aura wrapper) |
| `scheduledJobEditorModal`     | Modal dialog for creating/editing ScheduledJob__c records      |

### Streaming Monitor Components

| Component                | Purpose                                                 |
|--------------------------|---------------------------------------------------------|
| `streamingEvents`        | Event list display                                      |
| `streamingEventFilters`  | Filter controls                                         |
| `streamingTimeline`      | D3.js timeline visualisation                            |
| `streamingEventsHeader`  | Header action buttons                                   |
| `streamingUsageMetrics`  | Usage metrics charts                                    |
| `streamingUsageFilters`  | Metrics filter controls                                 |
| `orgLimits`              | Org limits bar chart                                    |
| `streamingSubscriptions` | Active subscription management                          |
| `streamingSidebar`       | Toggleable sidebar navigation for the Streaming Monitor |

### Chain Monitor Components

The Chain Monitor provides a read-only visualization of `AsyncChainExecution__c` records. It surfaces as a
full-page split-panel monitor (accessible from Kern Home) and an embedded step timeline on the record page.

**Component tree:**

```text
chainMonitor (AppPage container)
├── chainMonitorList (left panel — datatable, filters, pagination)
└── chainMonitorDetail (right panel — header, progress, accordion)
    └── chainStepTimeline (SLDS timeline with hover popovers)

chainStepTimeline (standalone on AsyncChainExecution__c record page)
```

**Key patterns:**

- **Event-driven refresh** — `chainMonitor` subscribes to `LogEntryEvent__e` via `empApi`. Subscribe
  failure is caught silently (works without it via imperative Apex calls on user interactions).
- **Smart row selection** — `chainMonitorList` auto-selects the first row on load, keeps selection
  after filter/sort if the row still exists, and clears if filtered out.
- **String parameter pattern** — Controller uses `String requestJson` + `JSON.deserialize()` to avoid
  LWC Proxy wrapper issues with complex DTO parameters.
- **Hover popovers** — `chainStepTimeline` shows a CSS-only SLDS tooltip popover on hover with class
  name, status, duration, continueOnError flag, and error message.
- **URL column** — Chain Name links directly to the `AsyncChainExecution__c` record page.

| Component            | Purpose                                                                               |
|----------------------|---------------------------------------------------------------------------------------|
| `chainMonitor`       | Split-panel container with empApi subscription                                        |
| `chainMonitorList`   | Datatable with collapsible status filters, search, sorting, pagination                |
| `chainMonitorDetail` | Status icon, progress bar, step timeline, timing grid, error section                  |
| `chainStepTimeline`  | SLDS timeline blueprint with hover popovers — dual mode (@api steps or @api recordId) |

---

## Demo Components

Demo components show framework capabilities and serve as implementation examples. They are exposed for testing but not intended for production use.

| Component            | Demonstrates                                                                                |
|----------------------|---------------------------------------------------------------------------------------------|
| `apiTestHarnessForm` | Interactive form for invoking inbound and outbound APIs with Safe Mode and mocking controls |

---

## Testing

### Jest Test Setup

KernDX LWC components require Node 22 for [Jest testing](https://developer.salesforce.com/docs/platform/lwc/guide/testing.html).

```bash
# Switch to Node 22
. /opt/homebrew/opt/nvm/nvm.sh && nvm use 22

# Run all tests
npm run test:unit

# Run specific component tests
npm run test:unit -- --testPathPattern=utilityString

# Run with coverage
npm run test:unit -- --coverage
```

### Mocking KernDX Modules

**Mock utilityLogger:**

```javascript
jest.mock('c/utilityLogger', () => ({
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
jest.mock('c/utilityString', () => ({
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
jest.mock('c/componentBuilder', () => ({
	ComponentBuilder: jest.fn().mockImplementation(() =>
	{
		const {LightningElement} = require('lwc');
		return class extends LightningElement
		{
			showSuccessToast = jest.fn();
			showErrorToast = jest.fn();
			callControllerMethod = jest.fn().mockResolvedValue({});
		};
	})
}), {virtual: true});
```

### Test Patterns

#### Testing Utility Modules

```javascript
import {formatTemplateString} from 'c/utilityString';

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

## Anti-Patterns

| Anti-Pattern                                                 | Why It's Wrong                                                             | Instead                                                                                              |
|--------------------------------------------------------------|----------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------|
| Extending `LightningElement` directly                        | Bypasses framework utilities, notification methods, and controller helpers | Extend `ComponentBuilder('module1', 'module2')`                                                      |
| Using `console.log` for debugging                            | Logs are ephemeral and not persisted; no correlation tracking              | Use `utilityLogger` for client-side logging with server persistence                                  |
| Using raw HTML elements (`<div>`, `<input>`) for UI controls | Inconsistent styling, no SLDS compliance, accessibility gaps               | Use Lightning base components (`lightning-button`, `lightning-input`, etc.)                          |
| Not cleaning up message channel subscriptions                | Memory leaks and duplicate event handlers across component lifecycle       | Call `clearSubscriptions()` in `disconnectedCallback` or use the built-in `lightning-message` module |
| Inline Apex calls without `callControllerMethod`             | No error handling, no loading state management, no consistent patterns     | Use `callControllerMethod(method, params)` from the `controller` module                              |

---

## Best Practices

### Use ComponentBuilder for New Components

```javascript
// Prefer this
export default class MyComponent extends ComponentBuilder('notification', 'controller') {}

// Over manual mixin composition
```

### Use Utility Modules for Common Operations

```javascript
// Prefer this
import {formatTemplateString} from 'c/utilityString';
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

The `notification` module's `showErrorToast` accepts either a string (passed
through unchanged) or an Apex / UI API error object (auto-normalised through
`c/utilitySystem.reduceErrors`). Import `reduceErrors` directly only when you
need the normalised string outside the toast pipeline.

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
| Jest tests failing        | Use Node 22; check mock setup                                                                                                                          |

### Debugging Tips

1. **Enable verbose logging:**
   ```javascript
   import {debug} from 'c/utilityLogger';
   debug('State:', JSON.stringify(this.state));
   ```

2. **Check correlation in Apex logs:**
    - Query [`LogEntry__c`](reference/objects/LogEntry__c.md) with matching `CorrelationId__c`

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

This section provides a complete reference for all components that subscribers can place directly on pages, flows, or record pages without writing code. These are production-ready,
standalone components.

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

---

#### jsonViewer

**Purpose:** Read-only JSON viewer with syntax highlighting

**Where to Use:** Flow Screens

| Property   | Type   | Required | Default | Description          |
|------------|--------|----------|---------|----------------------|
| `jsonText` | String | Yes      | -       | JSON data to display |

**Features:**

- Colour-coded keys, strings, numbers, booleans, null
- Handles malformed JSON with error message
- Scrollable for large payloads

---

### App Page / Record Page / Home Page Components

Components available in Lightning App Builder.

#### streamingMonitor

**Purpose:** Real-time Platform Event, CDC, and streaming event monitor

**Where to Use:** App Pages, Record Pages, Home Pages

| Property | Type | Required | Default | Description                               |
|----------|------|----------|---------|-------------------------------------------|
| (none)   | -    | -        | -       | Self-contained, no configuration required |

**Features:**

- Subscribe/unsubscribe to event channels
- Filter by channel, payload keyword, time range
- Table and Timeline (D3.js) views
- Publish test events
- View org limits consumption
- Event usage metrics dashboard

---

#### searchLookup

**Purpose:** Search lookup with custom controller support

**Where to Use:** Flow Screens, App Pages, Home Pages, Record Pages

| Property                     | Type   | Required | Default | Description                                                        |
|------------------------------|--------|----------|---------|--------------------------------------------------------------------|
| `controllerName`             | String | Yes      | -       | Controller implementing [`IF_Search`](reference/apex/IF_Search.md) |
| `name`                       | String | No       | -       | Component name identifier                                          |
| `fieldLabel`                 | String | No       | -       | Label above search input                                           |
| `resultUniqueId`             | String | No       | 'Id'    | Unique ID field in results                                         |
| `controllerSearchParameters` | Object | No       | -       | Additional search params                                           |
| `preselectedRecord`          | Object | No       | -       | Pre-populated record                                               |

**Controller Interface:**

```apex
public with sharing class MyController implements IF_Search
{
	public Object search(Object searchTerm, Map<String, Object> searchParameters)
	{
		// Return search results
	}
}
```

---

#### createForm

**Purpose:** Dynamic record create/edit/clone form using FieldSets

**Where to Use:** Flow Screens, App Pages, Home Pages, Record Pages

| Property          | Type    | Required | Default | Description                |
|-------------------|---------|----------|---------|----------------------------|
| `objectApiName`   | String  | Yes      | -       | SObject API name           |
| `fieldSetApiName` | String  | Yes      | -       | FieldSet API name          |
| `recordId`        | String  | No       | -       | Record ID (for edit/clone) |
| `formHeading`     | String  | No       | -       | Heading above form         |
| `isSaveMode`      | Boolean | No       | false   | Show Save button           |
| `isUpdateMode`    | Boolean | No       | false   | Enable update mode         |

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

**Purpose:** Post-install diagnostics with 7 health checks and actionable warnings

**Where to Use:** Home Pages

| Property | Type | Required | Default | Description                               |
|----------|------|----------|---------|-------------------------------------------|
| (none)   | -    | -        | -       | Self-contained, no configuration required |

**Features:**

- 5 checks: Organisation Cache, Session Cache, Trusted Site, Class Type Resolver, Data Retention
- Two-section layout: Action required (fail items) rendered above Review recommended (warn items); all-pass state collapses to a slim green banner
- Validates resolver classes extend `BaseClassResolver` — warns if class exists but is incompatible
- Setup button on resolver warnings opens a code generator modal
- Data Retention renders Apply Recommended Retention (one-click modal creating all four purge jobs) plus a Customize each job → link that expands into per-object sub-rows, each
  with a Set up button that opens `scheduledJobEditorModal` prefilled with the object's defaults and a read-only Class Name
- Record counts per unconfigured object returned as structured data for locale-aware formatting

---

### Programmatic Components (for Custom LWC Development)

These components are exposed for use within custom Lightning Web Components but are not directly placeable via Lightning App Builder. Use them by importing into your LWC code.

#### sObjectLookup

**Purpose:** Lookup component for searching any SObject by field

**Usage:**

```html
<c-s-object-lookup
    object-api-name="Account"
    display-fields={accountFields}
    field-label-name="Account"
    placeholder="Search accounts..."
    onvalueselect={handleAccountSelect}>
</c-s-object-lookup>
```

| Property          | Type     | Required | Default  | Description                                |
|-------------------|----------|----------|----------|--------------------------------------------|
| `objectApiName`   | String   | Yes      | -        | SObject API name to search                 |
| `displayFields`   | String[] | No       | ['Name'] | Fields to display in results               |
| `fieldLabelName`  | String   | No       | 'Name'   | Label above search input                   |
| `placeholder`     | String   | No       | 'Search' | Placeholder text                           |
| `iconName`        | String   | No       | (auto)   | SLDS icon name (auto-detected from object) |
| `isRequired`      | Boolean  | No       | false    | Mark field as required                     |
| `disableElement`  | Boolean  | No       | false    | Disable the lookup                         |
| `readOnly`        | Boolean  | No       | false    | Make lookup read-only                      |
| `displayFormat`   | String   | No       | -        | Custom display format for results          |
| `idField`         | String   | No       | 'Id'     | Field to use as unique identifier          |
| `defaultRecordId` | String   | No       | -        | Pre-select record by ID                    |
| `elementName`     | String   | No       | -        | Component name for event identification    |

**Events:**

- `valueselect` - Fires when a record is selected (detail: `{selectedId, elementName, isRequired}`)
- `searchtermchanged` - Fires when search term changes (detail: `{searchTerm, elementName}`)

---

#### paginatedTable

**Purpose:** Paginated datatable wrapper with cross-page row selection

**Usage:**

```html
<c-paginated-table
    rows={data}
    columns={columns}
    title="My Records"
    results-per-page="20"
    key-field="Id"
    max-rows-selected="10"
    onrowselection={handleSelection}
    onpagechange={handlePageChange}>
</c-paginated-table>
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
- `clearLookup()` - Clear selection

---

#### customDataTable

**Purpose:** Extended [lightning-datatable](https://developer.salesforce.com/docs/component-library/bundle/lightning-datatable/documentation) with custom column types

**Usage:**

```html
<c-custom-data-table
    data={data}
    columns={columnsWithCustomTypes}
    key-field="Id">
</c-custom-data-table>
```

| Property | Type  | Required | Default | Description                               |
|----------|-------|----------|---------|-------------------------------------------|
| `types`  | Array | No       | []      | Additional custom column type definitions |

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

---

#### cronExpressionEditor

**Purpose:** Reusable Salesforce cron expression editor with preset, advanced, and custom modes

**Usage:**

```html
<c-cron-expression-editor value={expression} oncronchange={handleChange}></c-cron-expression-editor>
```

| Property         | Type                | Required | Default | Description                                        |
|------------------|---------------------|----------|---------|----------------------------------------------------|
| `value`          | String              | No       | -       | Initial cron expression (input)                    |
| `cronExpression` | String (read-only)  | -        | -       | Current built expression (output)                  |
| `isValid`        | Boolean (read-only) | -        | -       | Whether the current expression has valid structure |

**Events:**

- `cronchange` — Fires on every expression change (detail: `{value: expressionString, isValid: boolean}`)

**Modes:**

| Mode     | Description                                                                                                              |
|----------|--------------------------------------------------------------------------------------------------------------------------|
| Preset   | Frequency-based builder: Every N Minutes, Hourly, Daily, Weekly, Monthly                                                 |
| Advanced | Field-by-field editor for all 7 Salesforce cron fields (Seconds, Minutes, Hours, Day of Month, Month, Day of Week, Year) |
| Custom   | Free-text input for arbitrary cron expressions                                                                           |

**Preview Section:**
Always-visible preview showing the monospace cron string and a crontab.guru-style human-readable description (e.g., `0 30 9 ? * MON,WED,FRI` displays as "Every Monday, Wednesday,
and Friday at 9:30 AM").

**Architecture:** Contains two internal modules:

- `constants.js` — option arrays and mode constants
- `cronParser.js` — pure functions: `parseCronExpression()`, `buildCronExpression()`, `describeCronExpression()`

**Subscriber Usage (with namespace prefix):**

```html
<namespace-cron-expression-editor value={expression} oncronchange={handleChange}></namespace-cron-expression-editor>
```

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
| cronExpressionEditor |      -      |    -     |      -      |     -     |    Yes    |
| scheduledJobDetail   |      -      |    -     |     Yes     |     -     |     -     |
| healthCheck          |      -      |    -     |      -      |    Yes    |     -     |
| chainMonitor         |      -      |   Yes    |      -      |     -     |     -     |
| chainStepTimeline    |      -      |    -     |     Yes     |     -     |     -     |

> **Code Only:** These components are exposed for use within custom LWC code but cannot be placed directly via Lightning App Builder.

---

### Complete Component Inventory

All 63 LWC components in the KernDX framework with their category, exposure status, and test coverage.

#### Utility Modules (7 components)

| Component          | Exposed | Jest Tests | Purpose                                     |
|--------------------|:-------:|:----------:|---------------------------------------------|
| `utilityLogger`    |   Yes   |    Yes     | Client-side logging with server correlation |
| `utilityString`    |   Yes   |    Yes     | String formatting and manipulation          |
| `utilityArray`     |   Yes   |    Yes     | Array and collection operations             |
| `utilitySystem`    |   Yes   |    Yes     | Error handling, clipboard, DOM utilities    |
| `utilityRandom`    |   Yes   |    Yes     | UUID and random string generation           |
| `utilityGenerator` |    -    |    Yes     | Counter and array generators                |
| `utilityStreaming` |    -    |    Yes     | Streaming constants and helpers             |

#### Base Architecture (8 components)

| Component                       | Exposed | Jest Tests | Purpose                                                          |
|---------------------------------|:-------:|:----------:|------------------------------------------------------------------|
| `baseComponent` (internal)      |    -    |    Yes     | Base class with modular functionality                            |
| `componentBuilder`              |    -    |    Yes     | Factory for creating extended base classes — **only public API** |
| `componentExtender` (internal)  |    -    |    Yes     | Module initialiser for baseComponent                             |
| `moduleController`              |    -    |    Yes     | Apex controller integration module                               |
| `moduleNavigation`              |    -    |    Yes     | Page navigation module                                           |
| `moduleNotification`            |    -    |    Yes     | Toast notification module                                        |
| `moduleLightningMessageService` |    -    |    Yes     | LMS publish/subscribe module                                     |
| `moduleFlowNavigation`          |    -    |    Yes     | Flow navigation events module                                    |

#### Subscriber-Usable Components (15 components)

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
| `validationErrors`     |   Yes   |    Yes     | Display validation rule errors                                    |
| `cronExpressionEditor` |    -    |    Yes     | Reusable cron expression editor (preset/advanced/custom)          |
| `scheduledJobDetail`   |   Yes   |    Yes     | View-only record page component for ScheduledJob__c records       |
| `healthCheck`          |   Yes   |    Yes     | Post-install diagnostics with resolver code generator             |
| `featureFlag`          |   Yes   |    Yes     | Cacheable bridge to `UTIL_FeatureFlag.isEnabled()` for the UI      |

#### Internal UI Components (9 components)

| Component                     | Exposed | Jest Tests | Purpose                                                        |
|-------------------------------|:-------:|:----------:|----------------------------------------------------------------|
| `modal`                       |    -    |    Yes     | Reusable modal dialog                                          |
| `notice`                      |    -    |    Yes     | Info notice with icon                                          |
| `baseLookup`                  |    -    |    Yes     | Base lookup component                                          |
| `viewRecord`                  |    -    |    Yes     | Read-only record display                                       |
| `applyRetentionModal`         |    -    |    Yes     | Confirmation modal for applying recommended retention jobs     |
| `classTypeResolverSetupModal` |    -    |    Yes     | Guided setup modal for subscriber Class Type Resolver          |
| `kernHome`                    |   Yes   |    Yes     | Kern Home developer control room card layout                   |
| `scheduledJobEditor`          |    -    |    Yes     | ScheduledJob__c editor form (action override via Aura wrapper) |
| `scheduledJobEditorModal`     |    -    |    Yes     | Modal dialog for creating/editing ScheduledJob__c records      |

#### Streaming Monitor Internals (9 components)

| Component                | Exposed | Jest Tests | Purpose                                                 |
|--------------------------|:-------:|:----------:|---------------------------------------------------------|
| `streamingEvents`        |    -    |    Yes     | Event list with table/timeline views                    |
| `streamingEventFilters`  |    -    |    Yes     | Event filter controls                                   |
| `streamingTimeline`      |    -    |    Yes     | D3.js timeline visualisation                            |
| `streamingEventsHeader`  |    -    |    Yes     | Event header actions                                    |
| `streamingUsageMetrics`  |    -    |    Yes     | Usage metrics charts                                    |
| `streamingUsageFilters`  |    -    |    Yes     | Metrics filter controls                                 |
| `orgLimits`              |    -    |    Yes     | Org limits bar chart                                    |
| `streamingSubscriptions` |    -    |    Yes     | Active subscription management                          |
| `streamingSidebar`       |    -    |    Yes     | Toggleable sidebar navigation for the Streaming Monitor |

#### Chain Monitor (4 components)

| Component            | Exposed | Jest Tests | Purpose                                                                                       |
|----------------------|:-------:|:----------:|-----------------------------------------------------------------------------------------------|
| `chainMonitor`       |   Yes   |    Yes     | Full-page split-panel container with empApi subscription for live refresh                     |
| `chainMonitorList`   |    -    |    Yes     | Paginated datatable with filters, sorting, smart row selection, URL links to records          |
| `chainMonitorDetail` |    -    |    Yes     | Accordion layout: header with status icon, progress bar, step timeline, timing, error section |
| `chainStepTimeline`  |   Yes   |    Yes     | SLDS timeline with hover popovers showing class, status, duration, continueOnError            |

#### Data Masking Advisor (10 components)

The console and dialogs behind the **Data Masking Advisor** (see [Security Guide → Data Masking](Security%20-%20Guide.md#data-masking)). Only the
`dataMaskingAdvisor` page component is exposed; the rest are internal building blocks.

| Component                      | Exposed | Jest Tests | Purpose                                                       |
|--------------------------------|:-------:|:----------:|---------------------------------------------------------------|
| `dataMaskingAdvisor`           |   Yes   |    Yes     | Advisor console — object picker, posture review, scan, configure |
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

---

### Test Coverage Summary

| Category            | Components | With Jest Tests | Coverage |
|---------------------|:----------:|:---------------:|:--------:|
| Utility Modules     |     7      |        7        |   100%   |
| Base Architecture   |     8      |        8        |   100%   |
| Subscriber-Usable   |     15     |       15        |   100%   |
| Internal UI         |     9      |        9        |   100%   |
| Streaming Internals |     9      |        9        |   100%   |
| Chain Monitor       |     4      |        4        |   100%   |
| Data Masking Advisor |    10     |       10        |   100%   |
| Demo Components     |     1      |        1        |   100%   |
| **TOTAL**           |   **63**   |     **63**      | **100%** |

> **Note:** All 63 LWC components have Jest unit tests. Run `npm run test:unit -- --coverage` to verify coverage.

---

*Last Updated: April 2026*
