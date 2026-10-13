---
navOrder: 34
---

# Fast Start - Inbound APIs

**Framework:** KernDX | **Total time:** ~30 minutes

**What this is:** A way to build a Salesforce REST endpoint that receives data from an outside system (a website form, a partner system, another app), checks the data, saves a record, and returns a clean response. **Why it matters:** Hand-rolled REST endpoints usually scatter logging, validation, and error handling across each one, so they drift apart and break differently. Here those are built in, so every endpoint behaves the same. **Who should follow this:** developers building integrations, and tech leads who want consistent, testable inbound APIs. **When to use it:** any time an external system needs to send data into Salesforce. If you only need a single, one-off endpoint with no logging or validation, a plain `@RestResource` class is simpler; the framework earns its keep once you have several endpoints that should all behave the same way.

> **Namespaces in code samples:** `kern.` on a class and `kern__` on an object, field, or metadata type mark the managed package's namespace.
> On the managed package, framework references need those prefixes even where a sample omits them; repackaged under your own namespace, replace `kern`/`kern__`
> with your prefix; on an unmanaged deploy, drop them. See [How to read the code samples](Installation.md#how-to-read-the-code-samples).

**What you'll build:** A REST API endpoint that receives JSON from external systems, validates the data,
creates a Salesforce record, and returns a structured response.

**Success looks like:** You POST JSON to your endpoint, see a response with the new record ID, and the call
is logged in the Kern app's **API Calls** tab, with 100% test coverage.

**In one line:** `kern.API_Dispatcher.processInboundService(API_ContactFormSubmit.class.getName());` is the only line in the
REST resource; all logic lives in the handler class.

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
2. [Tier 1: See It Work (~2 minutes)](#tier-1-see-it-work-2-minutes)
    - [Call the Echo API](#call-the-echo-api)
3. [How It Works (Two-Class Architecture)](#how-it-works-two-class-architecture)
4. [Tier 2: Build Your Own (~20 minutes)](#tier-2-build-your-own-20-minutes)
    - [Step 1: Create the REST Routing Class](#step-1-create-the-rest-routing-class)
    - [Step 2: Create the API Handler](#step-2-create-the-api-handler)
    - [Step 3: Register Metadata](#step-3-register-metadata)
    - [Step 4: Execute](#step-4-execute)
    - [Step 5: Write Tests](#step-5-write-tests)
5. [Sensitive data is masked by default](#sensitive-data-is-masked-by-default)
6. [Tier 3: Production Patterns (~5 minutes)](#tier-3-production-patterns-5-minutes)
    - [Feature Flag Gating](#feature-flag-gating)
    - [Multiple HTTP Methods on One URL](#multiple-http-methods-on-one-url)
    - [Idempotency](#idempotency)
    - [Clean up](#clean-up)
7. [Common Issues](#common-issues)
    - [Step 4: Execute](#step-4-execute-1)
    - [Feature Flag Gating](#feature-flag-gating-1)
8. [What You Now Know](#what-you-now-know)
9. [Next Steps](#next-steps)

</details>

---

## Tier 1: See It Work (~2 minutes)

Before you build anything, prove the framework works end to end. The package ships with a built-in **Echo** endpoint you can call right away, no code needed.

### Call the Echo API

The Echo endpoint sends back whatever JSON you send it. One command calls it and prints its reply.

**In the terminal**, from your project's top folder, call the Echo endpoint:

```shell
sf api request rest -o YourOrgAlias --method POST --body "{\"message\":\"Hello from Salesforce\"}" services/apexrest/kern/echo
```

You should see this reply, whose line reads `"message": "Hello from Salesforce"`:

```json
{
  "message": "Hello from Salesforce"
}
```

The Echo endpoint received your JSON, processed it through the framework, and echoed it back. Behind the scenes,
the framework:

- Parsed the request body into a DTO (a small class holding exactly the fields to move in or out, that converts itself to and from JSON)
- Ran validation (non-blank body required)
- Logged the call as an `ApiCall__c` record
- Returned the response

> **See it in the org:** Open **App Launcher > Kern > API Calls** tab and select the **All** list view. You'll
> see the Echo call logged with the full request/response details, status, and timing.

> **No CLI installed?** Tier 1 just verifies the package endpoint is working. If you don't have the Salesforce CLI,
> skip to [Tier 2](#tier-2-build-your-own-20-minutes): you can do everything from the Developer Console. Alternatively, use
> [Workbench](https://workbench.developerforce.com/) (REST Explorer > POST >
> `/services/apexrest/kern/echo` > body: `{"message":"Hello from Salesforce"}`).

Something went wrong? See [Common Issues](#common-issues).

---

## How It Works (Two-Class Architecture)

Every inbound API splits into two classes so that the wiring Salesforce requires stays separate from your own logic.
One class only routes the URL; the other does the real work. That split keeps each class small and easy to test on
its own.

| Class    | Role                                                             | Visibility                                |
|----------|------------------------------------------------------------------|-------------------------------------------|
| `REST_*` | URL routing only: defines the endpoint, delegates to framework   | `global` (required by Salesforce)         |
| `API_*`  | Business logic: validation, DML, response building               | `global` (or `public` with Type Resolver) |

The Echo API's routing class is just three lines of logic:

```apex
@RestResource(urlMapping='/echo/*')
global inherited sharing class REST_Echo
{
	@HttpPost
	global static void echo()
	{
		kern.API_Dispatcher.processInboundService(API_Echo.class.getName());
	}
}
```

> **When to move to Tier 2:** When you need to build your own endpoint that creates or updates records, validates
> input, and returns structured responses.

---

## Tier 2: Build Your Own (~20 minutes)

> **No local project?** You can create classes directly in the Developer Console (Gear Icon > Developer
> Console > File > New > Apex Class) and run tests from there too (Test > New Run). Paste the code, save,
> and skip the terminal commands.

Build a **Contact Form** API that receives submissions from an external website, validates the data, creates a
Lead record, and returns the Lead ID.

**What the website sends:**

```json
POST /services/apexrest/v1/contact-form
{
  "firstName": "Jane",
  "lastName": "Doe",
  "email": "jane.doe@example.com",
  "message": "I'd like to learn more about your products"
}
```

### Step 1: Create the REST Routing Class

This class defines the URL endpoint. It contains no business logic, just routing: logic placed here would skip the
framework's logging and validation, so all of it goes in the `API_*` class of Step 2. You create an empty class with
one command and paste the code into it; Step 2 sends it to your org together with the handler.

**1. In the terminal**, from your project's top folder, create the empty class:

```shell
sf apex generate class --name REST_ContactForm --output-dir force-app/main/default/classes
```

You should see two files created in `force-app/main/default/classes`: `REST_ContactForm.cls` and its companion of the
same name ending in `.cls-meta.xml`.

The second file tells Salesforce which API version the class uses. You never edit it, but a deploy fails without it.

**2. In your editor**, open this file, delete what is there, paste the code below in exactly as it is, and save:

```text
force-app/main/default/classes/REST_ContactForm.cls
```

```apex
/**
 * @description REST endpoint for Contact Us form submissions.
 *
 * @see API_ContactFormSubmit
 *
 * @author your.name@company.com
 *
 * @group Web Services
 *
 * @date February 2026
 */
@RestResource(urlMapping='/v1/contact-form/*')
global inherited sharing class REST_ContactForm
{
	/**
	 * @description Handles POST requests for form submissions.
	 */
	@HttpPost
	global static void submitForm()
	{
		kern.API_Dispatcher.processInboundService(API_ContactFormSubmit.class.getName());
	}
}
```

Something went wrong? See [Common Issues](#common-issues).

### Step 2: Create the API Handler

This class contains all the business logic: it checks the submission, creates the Lead and builds the reply. You
create the empty class with one command, paste the code into it, then send both classes to your org.

**1. In the terminal**, from your project's top folder, create the empty class:

```shell
sf apex generate class --name API_ContactFormSubmit --output-dir force-app/main/default/classes
```

You should see two files created in `force-app/main/default/classes`: `API_ContactFormSubmit.cls` and its companion of
the same name ending in `.cls-meta.xml`.

**2. In your editor**, open this file, delete what is there, paste the code below in exactly as it is, and save. Do
not change the class name.

```text
force-app/main/default/classes/API_ContactFormSubmit.cls
```

> **Why `global`?** This lets the managed package resolve the class at runtime without additional setup.
> If you prefer `public with sharing`, you'll need a Type Resolver class (it tells the framework where to find your
> own classes). The Kern home page health check provides the code, or see
> [Type Resolution](Utilities%20-%20Guide.md#type-resolution-util_typeresolver).

```apex
/**
 * @description Processes Contact Us form submissions. Creates a Lead record.
 *
 * @see REST_ContactForm
 *
 * @see API_ContactFormSubmit_TEST
 *
 * @author your.name@company.com
 *
 * @group Web Services
 *
 * @date February 2026
 */
global with sharing class API_ContactFormSubmit extends kern.API_Inbound
{
	/** @description The Lead record being created. */
	private Lead newLead;

	/**
	 * @description Initializes request and response DTOs.
	 */
	public override void configure()
	{
		super.configure();
		requestPayload = new DTO_Request();
		responsePayload = new DTO_Response();
	}

	/**
	 * @description Validates the incoming request data.
	 *
	 * @return A list of validation error messages. Empty list means validation passed.
	 */
	public override List<String> getValidationErrors()
	{
		List<String> errors = new List<String>();
		DTO_Request dto = (DTO_Request)requestPayload;

		if(String.isBlank(dto.lastName))
		{
			errors.add('Last name is required');
		}

		if(String.isBlank(dto.email))
		{
			errors.add('Email is required');
		}

		return errors;
	}

	/**
	 * @description Creates the Lead record from the submitted data.
	 */
	public override void onSuccess()
	{
		super.onSuccess();
		DTO_Request dto = (DTO_Request)requestPayload;

		newLead = new Lead(
			FirstName = dto.firstName,
			LastName = dto.lastName,
			Email = dto.email,
			Description = dto.message,
			LeadSource = 'Web',
			Company = dto.lastName + ' (Web Lead)'
		);

		// Use doInsert() (not direct insert) — framework logs errors and commits atomically
		doInsert(newLead);
	}

	/**
	 * @description Populates the response after the database commit.
	 */
	public override void updateResponseDTO()
	{
		DTO_Response dto = (DTO_Response)responsePayload;

		if(result.isSuccess && newLead?.Id != null)
		{
			dto.success = true;
			dto.leadId = newLead.Id;
			dto.message = 'Thank you for contacting us!';
		}
	}

	/** @description Incoming form submission data. */
	@JsonAccess(serializable='always' deserializable='always')
	global class DTO_Request extends kern.DTO_JsonBase
	{
		/** @description Contact's first name. */
		public String firstName;

		/** @description Contact's last name. */
		public String lastName;

		/** @description Contact's email address. */
		public String email;

		/** @description Message from the contact form. */
		public String message;
	}

	/** @description Response returned to the caller. */
	@JsonAccess(serializable='always' deserializable='always')
	global class DTO_Response extends kern.DTO_JsonBase
	{
		/** @description Whether the submission was successful. */
		public Boolean success;

		/** @description The created Lead record ID. */
		public String leadId;

		/** @description User-friendly response message. */
		public String message;
	}
}
```

**3. In the terminal**, send both classes to your org:

```shell
sf project deploy start -o YourOrgAlias -m "ApexClass:REST_ContactForm" -m "ApexClass:API_ContactFormSubmit"
```

You should see `Status: Succeeded`, with `API_ContactFormSubmit` and `REST_ContactForm` listed as created.

Something went wrong? See [Common Issues](#common-issues).

### Step 3: Register Metadata

The framework needs to know which handler class serves which URL. You tell it by creating one configuration record
(an `ApiSetting__mdt`) instead of wiring it in code, so you can add or change endpoints without a redeploy. You
create the record in Setup, then pull it into your project so it is under source control with your code.

**1. In Salesforce**, open Setup, then Custom Metadata Types, then **API Setting**, then **Manage API Settings**, then
**New**, and save a record with these values:

| Field            | API name                | Value                   |
|------------------|-------------------------|-------------------------|
| Label            | `MasterLabel`           | `Contact Form Submit`   |
| API Setting Name | `DeveloperName`         | `ContactFormSubmit`     |
| Class Name       | `kern__ClassName__c`    | `API_ContactFormSubmit` |
| Direction        | `kern__Direction__c`    | `Inbound`               |
| Endpoint Path    | `kern__EndpointPath__c` | `/v1/contact-form/*`    |
| Is Active        | `kern__IsActive__c`     | checked                 |
| Log Issues       | `kern__LogIssues__c`    | checked                 |

**2. In the terminal**, pull the record into your project:

```shell
sf project retrieve start -o YourOrgAlias -m "CustomMetadata:kern__ApiSetting.ContactFormSubmit"
```

You should see one file created under `force-app/main/default/customMetadata`, named after the record.

> **Class Name** (`kern__ClassName__c`) must match the `API_*` class name exactly (e.g., `API_ContactFormSubmit`), with no
> namespace prefix. The framework finds the class in your namespace for you.

Something went wrong? See [Common Issues](#common-issues).

### Step 4: Execute

Call your new API the way the website would, and read the reply it sends back.

**In the terminal**, call your new API:

```shell
sf api request rest -o YourOrgAlias --method POST --body "{\"firstName\":\"Jane\",\"lastName\":\"Doe\",\"email\":\"jane.doe@example.com\",\"message\":\"Hello\"}" services/apexrest/v1/contact-form
```

You should see a reply like this one, with `"success": true` and your org's own Lead ID in place of `00Q...`:

```json
{
  "success": true,
  "message": "Thank you for contacting us!",
  "leadId": "00Q..."
}
```

> **See it in the org:** Open **App Launcher > Kern > API Calls** tab and select the **All** list view.
> You'll see your call logged with the full request/response details, status, and timing.

**Why it works, the key patterns:**

- **`configure()`**: always call `super.configure()` first, then set `requestPayload` and `responsePayload`
- **`getValidationErrors()`**: return error messages; an empty list means validation passed, and the framework aborts the call if the list is non-empty.
- **`onSuccess()`**: use inherited `doInsert()`/`doUpdate()`/`doDelete()` (NOT direct DML). The framework commits
  all the changes together after processing.
- **`updateResponseDTO()`**: runs after the database commit, so the new record IDs are available
- **`@JsonAccess`**: required on all DTOs in a managed package context

Something went wrong? See [Common Issues, Step 4](#step-4-execute-1).

### Step 5: Write Tests

The test class checks the three paths: a valid submission succeeds, and a submission missing its last name or its
email is turned away. You create the empty class with one command, paste the code into it, send it to your org, then
run it.

**1. In the terminal**, from your project's top folder, create the empty test class:

```shell
sf apex generate class --name API_ContactFormSubmit_TEST --output-dir force-app/main/default/classes
```

You should see two files created in `force-app/main/default/classes`: `API_ContactFormSubmit_TEST.cls` and its
companion of the same name ending in `.cls-meta.xml`.

**2. In your editor**, open this file, delete what is there, paste the code below in, and save:

```text
force-app/main/default/classes/API_ContactFormSubmit_TEST.cls
```

```apex
/**
 * @description Unit tests for API_ContactFormSubmit.
 *
 * @see API_ContactFormSubmit
 *
 * @author your.name@company.com
 *
 * @group Web Services
 *
 * @date February 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(isParallel=true)
private class API_ContactFormSubmit_TEST
{
	/** @description The API service class name. */
	private static final String SERVICE_NAME = API_ContactFormSubmit.class.getName();

	/** @description Tests a successful form submission that creates a Lead. */
	@IsTest
	private static void shouldCreateLeadFromValidSubmission()
	{
		API_ContactFormSubmit.DTO_Request request = new API_ContactFormSubmit.DTO_Request();
		request.firstName = 'Jane';
		request.lastName = 'Doe';
		request.email = 'jane.doe@example.com';
		request.message = 'I want to learn more';

		// Framework handles RestContext setup, dispatching, and assertion -- no manual mock needed
		kern.API_InboundTestHelper.assertCallSuccessful(SERVICE_NAME, request);
	}

	/** @description Tests that the call is aborted when last name is missing. */
	@IsTest
	private static void shouldAbortWhenLastNameMissing()
	{
		API_ContactFormSubmit.DTO_Request request = new API_ContactFormSubmit.DTO_Request();
		request.email = 'jane@example.com';

		kern.API_InboundTestHelper.assertCallAborted(SERVICE_NAME, request, 'Last name is required');
	}

	/** @description Tests that the call is aborted when email is missing. */
	@IsTest
	private static void shouldAbortWhenEmailMissing()
	{
		API_ContactFormSubmit.DTO_Request request = new API_ContactFormSubmit.DTO_Request();
		request.lastName = 'Doe';

		kern.API_InboundTestHelper.assertCallAborted(SERVICE_NAME, request, 'Email is required');
	}
}
```

**3. In the terminal**, send the test class to your org:

```shell
sf project deploy start -o YourOrgAlias -m "ApexClass:API_ContactFormSubmit_TEST"
```

You should see `Status: Succeeded`, with `API_ContactFormSubmit_TEST` listed as created.

**4. In the terminal**, run the test:

```shell
sf apex run test -o YourOrgAlias -t API_ContactFormSubmit_TEST --code-coverage --synchronous --result-format human
```

You should see 3 tests passing and 100% coverage on `API_ContactFormSubmit`: all three tests show `Pass`, the summary
line `Outcome` reads `Passed`, and the coverage table shows `API_ContactFormSubmit` at `100%`.

> **About the annotations:** `@IsTest(isParallel=true)` enables parallel test execution (faster runs).
> `SeeAllData` defaults to `false`, so we omit it. `@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')`
> suppresses a code-quality rule about `System.runAs()`: fine for quick starts, but consider adding
> `System.runAs()` in production tests to verify profile and permission set access.

> **Writing your own tests?** The `assertCall*` methods set up the incoming request for you. A test that calls the
> handler another way must set it up first with `kern.API_InboundTestHelper.setupRestContext()`; without it, the test
> fails with a NullPointerException.

Something went wrong? See [Common Issues](#common-issues).

---

## Sensitive data is masked by default

Logging every call is useful, but you don't want a logged audit record to become the place a password or card number leaks. To avoid that, every inbound request and response is captured to `ApiCall__c` for audit, and the request body, response body, URL, and parameters are first run through the data masking framework, which redacts sensitive values before they are saved. Out of the box, two rules fire:

- **`MaskSecretKeys`**: redacts common secret JSON keys (`password`, `token`, `apiKey`, `authorization`, `bearer`, `client_secret`, `private_key`, `access_token`,
  `refresh_token`).
- **`MaskPaymentCard`**: redacts 13–19 digit sequences that pass the Luhn (mod-10) checksum, covering all major card brands; digits may be separated by spaces or hyphens.
  (Replaces the original `MaskCreditCard` rule, which still ships for compatibility.)

So if a caller posts a body containing a `password` or card number, the persisted `ApiCall__c.Request__c` has those redacted. The response you generate and return to the caller is
untouched.

Fifteen more rules ship as inactive templates: SSN, IBAN, SWIFT/BIC, MBI, health keywords, email, US phone, JWT, AWS access key, URL basic auth, authorization header, private IPv4, postal address,
free text, and international phone. To turn one on, set `kern__MaskingRule__mdt.IsActive__c = true` and add a `kern__MaskingTarget__mdt` record wiring the rule to the field(s)
that need it.

If a sensitive value still appears raw on `ApiCall__c`, the field is not covered by a masking target, or its rule is
inactive. Add a `kern__MaskingTarget__mdt` record with the rule, `kern__SObjectType__c = ApiCall__c`, and a `kern__Field__c`
(blank for wildcard); see the [Web Services Guide](Web%20Services%20-%20Guide.md).

---

## Tier 3: Production Patterns (~5 minutes)

### Feature Flag Gating

Sometimes you want an endpoint deployed but switched off until you decide to turn it on, for example during a phased
rollout. You can do that without touching code: point the Required Feature Flag (`kern__RequiredFeatureFlag__c`) field on
your `ApiSetting__mdt` record at a [Feature Flag](Fast%20Start%20-%20Feature%20Flags.md). When the flag is not
enabled, the framework aborts the request automatically.

#### Deploy a feature-flagged API

You create the flag switched off, pull it into your project, then point the API Setting from Step 3 at it.

**1. In Salesforce**, open Setup, then Custom Metadata Types, then **Feature Flag**, then **Manage Feature Flags**,
then **New**, and save a record with these values:

| Field                 | API name                       | Value                     |
|-----------------------|--------------------------------|---------------------------|
| Label                 | `MasterLabel`                  | `Enable Contact Form API` |
| Feature Flag Name     | `DeveloperName`                | `EnableContactFormApi`    |
| Is Active             | `kern__IsActive__c`            | checked                   |
| Is Enabled By Default | `kern__IsEnabledByDefault__c`  | unchecked                 |

**2. In the terminal**, pull the flag into your project:

```shell
sf project retrieve start -o YourOrgAlias -m "CustomMetadata:kern__FeatureFlag.EnableContactFormApi"
```

You should see one file created under `force-app/main/default/customMetadata`, named after the record.

**3. In Salesforce**, open Setup, then Custom Metadata Types, then **API Setting**, then **Manage API Settings**, then
**Edit** beside `Contact Form Submit`, set this value and save:

| Field                 | API name                       | Value                      |
|-----------------------|--------------------------------|----------------------------|
| Required Feature Flag | `kern__RequiredFeatureFlag__c` | `Enable Contact Form API`  |

**4. In the terminal**, pull the API Setting again, so your project holds the change:

```shell
sf project retrieve start -o YourOrgAlias -m "CustomMetadata:kern__ApiSetting.ContactFormSubmit"
```

You should see `Status: Succeeded`, with the API Setting's file listed as `Changed`.

Something went wrong? See [Common Issues](#feature-flag-gating-1).

#### Verify

Call the endpoint while the flag is off: the framework should turn the call away before your handler runs.

**In the terminal**, call your API:

```shell
sf api request rest -o YourOrgAlias --method POST --body "{\"firstName\":\"Jane\",\"lastName\":\"Doe\",\"email\":\"jane@test.com\",\"message\":\"Test\"}" services/apexrest/v1/contact-form
```

You should see the call turned away. The flag is disabled, so the framework returns the error messages as a bare
JSON array:

```json
[
  "Required condition \"EnableContactFormApi\" is not met"
]
```

Enable the flag (check **Is Enabled By Default**, `kern__IsEnabledByDefault__c`, or create a strategy) and the API starts accepting
requests again. Use **Bypass Feature Flag** (`kern__BypassFeatureFlag__c`) instead for a kill-switch (a master off-switch you can flip in an incident
without a deployment): the service is bypassed when the flag is **enabled**.

Something went wrong? See [Common Issues](#feature-flag-gating-1).

### Multiple HTTP Methods on One URL

One URL can serve more than one action, for example POST to submit a form and GET to read submissions back. You add
more methods to the same `REST_*` class. Each HTTP method hands off to a different `API_*` handler class, each with
its own `ApiSetting__mdt` record.

**In your editor**, the routing class then has one method per HTTP method:

```apex
@RestResource(urlMapping='/v1/contact-form/*')
global inherited sharing class REST_ContactForm
{
	@HttpPost
	global static void submitForm()
	{
		kern.API_Dispatcher.processInboundService(API_ContactFormSubmit.class.getName());
	}

	@HttpGet
	global static void getSubmissions()
	{
		kern.API_Dispatcher.processInboundService(API_GetContactSubmissions.class.getName());
	}
}
```

> **Note:** This shows the shape of the pattern; `API_GetContactSubmissions` is not included in this guide.
> See the [Web Services Guide](Web%20Services%20-%20Guide.md) for a working multi-method example.

### Idempotency

A flaky network or an over-eager retry can send the same request twice and create two records when the caller meant
one. You switch idempotency on for the endpoint with **Idempotency Enabled** (`kern__IdempotencyEnabled__c`) on its
`ApiSetting__mdt` record.

**1. In Salesforce**, open Setup, then Custom Metadata Types, then **API Setting**, then **Manage API Settings**, then
**Edit** beside `Contact Form Submit`, set this value and save:

| Field               | API name                      | Value   |
|---------------------|-------------------------------|---------|
| Idempotency Enabled | `kern__IdempotencyEnabled__c` | checked |

**2. In the terminal**, pull the record again:

```shell
sf project retrieve start -o YourOrgAlias -m "CustomMetadata:kern__ApiSetting.ContactFormSubmit"
```

You should see `Status: Succeeded`, with the file listed as `Changed`.

A caller sends an `Idempotency-Key` header with a value unique to that request. The framework stores the first
result under that key, so a repeated request that reuses the same key is answered from the stored result instead of
running the handler again. See
[Idempotency in the Web Services Guide](Web%20Services%20-%20Guide.md#idempotency-inbound-apis) for the feature's
details.

Something went wrong? See [Common Issues](#common-issues).

### Clean up

Run this when you have finished the guide, if you built this example only to try the framework. One command removes
everything the guide deployed or created in Setup.

**In the terminal**, delete the three classes and the two records:

```shell
sf project delete source -o YourOrgAlias -m "ApexClass:API_ContactFormSubmit_TEST" -m "ApexClass:REST_ContactForm" -m "ApexClass:API_ContactFormSubmit" -m "CustomMetadata:kern__ApiSetting.ContactFormSubmit" -m "CustomMetadata:kern__FeatureFlag.EnableContactFormApi" --no-prompt
```

You should see `Status: Succeeded`, then a `Deleted Source` table listing the three classes and the two records.

The command deletes the files from your project too. The Leads your calls created, and the call records on the
**API Calls** tab, stay in your org: delete them from their tabs if you do not want to keep them.

Something went wrong? See [Common Issues](#common-issues).

---

## Common Issues

Trouble with your computer rather than this guide (`sf` is not recognised, scripts are disabled, you are not logged
in, the wrong folder)? Those are answered once, in
[Set Up Your Computer](Set%20Up%20Your%20Computer.md#if-something-went-wrong).

### Step 4: Execute

#### `Duplicate Alert`

The call fails with a reply whose first line of text is `Duplicate Alert`. A Lead with the same name and email
already exists (for example from an earlier run of this step), and your org's duplicate rule for Leads blocks the new one. Delete
the earlier Lead from the **Leads** tab, or change the email in the body, and call again.

#### `Unable to resolve type for class "API_ContactFormSubmit"`

The call fails with this message. The handler class is `public`, and the framework cannot see a `public` class in
your org. Make the class `global` as Step 2 shows, or set up a Type Resolver so the framework knows where to look
([details](Utilities%20-%20Guide.md#type-resolution-util_typeresolver)). If the message names
`API_ContactFormSubmit.DTO_Request` and asks for `getObjectType()`, it is the request class inside the handler that is
`public`: make it `global`.

#### `Type cannot be deserialized`

The call fails with this message. A DTO class in the handler is missing its `@JsonAccess` annotation, which a class
in your org needs before the framework can turn JSON into it. Add
`@JsonAccess(serializable='always' deserializable='always')` above each DTO class, as Step 2 shows.

#### `Stopwatch is not running.`

The call fails with a reply whose message contains `Stopwatch is not running.` Your `configure()` override does not
call `super.configure()`, so the framework's own set-up never runs. Always call `super.configure()` first, as Step 2
shows.

### Feature Flag Gating

#### The call succeeds while the flag is off

The Verify call creates a Lead instead of being turned away. The framework ran the call with no flag to check, for
one of two reasons. Either the record's **Class Name** (`kern__ClassName__c`) does not match your simple class name,
so the framework did not find your `ApiSetting__mdt` record, or the record's **Required Feature Flag** was left empty,
so there is no flag for it to check. Set the value that is wrong as Step 3 or Feature Flag Gating shows, then call
again.

Still stuck? [Tell us](https://github.com/JVB-Consulting/kerndx/issues/new?template=bug_report.md&title=%5Bdocs%5D%20Inbound%20APIs) which step and what you saw.

## What You Now Know

After completing this guide, you understand the **inbound API architecture** in KernDX:

| Concept                    | What It Does                                                                     |
|----------------------------|----------------------------------------------------------------------------------|
| **Two-class architecture** | `REST_*` handles URL routing (global), `API_*` handles business logic            |
| **`API_Dispatcher`**       | Routes requests from the REST endpoint to your handler class                     |
| **`ApiSetting__mdt`**      | Registers your handler with the framework (class name, direction, endpoint path) |
| **`ApiCall__c`**           | Automatic logging of every inbound call with request/response details            |

**Key methods you override:**

- **`configure()`**: set up DTOs (always call `super.configure()` first)
- **`getValidationErrors()`**: return error messages; the framework aborts if the list is non-empty
- **`onSuccess()`**: create or update records using `doInsert()`/`doUpdate()` (NOT direct DML)
- **`updateResponseDTO()`**: build the response after the database commit
- **`@JsonAccess`**: required on all DTOs in a managed package context
- **`API_InboundTestHelper`**: one-line test assertions for success, abort, and failure paths

---

## Next Steps

- [Building Outbound APIs](Fast%20Start%20-%20Outbound%20APIs.md)
- [Feature Flag Gating](Fast%20Start%20-%20Feature%20Flags.md)
- [Complete Web Services Guide](Web%20Services%20-%20Guide.md)
- [Data Masking](Web%20Services%20-%20Guide.md#what-else-can-it-do)
