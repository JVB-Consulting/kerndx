---
navOrder: 34
---

# Fast Start - Inbound APIs

**Framework:** KernDX | **Total time:** ~30 minutes

**What this is:** A way to build a Salesforce REST endpoint that receives data from an outside system (a website form, a partner system, another app), checks the data, saves a record, and returns a clean response. **Why it matters:** Hand-rolled REST endpoints usually scatter logging, validation, and error handling across each one, so they drift apart and break differently. Here those are built in, so every endpoint behaves the same. **Who should follow this:** developers building integrations, and tech leads who want consistent, testable inbound APIs. **When to use it:** any time an external system needs to send data into Salesforce. If you only need a single, one-off endpoint with no logging or validation, a plain `@RestResource` class is simpler; the framework earns its keep once you have several endpoints that should all behave the same way.

**Before you start:**

- [ ] KernDX package installed in your org
- [ ] Org configured post-install (verify with the **Kern** app's Health Check; see [Installation guide](Installation.md#post-install-configuration))
- [ ] CLI authenticated (`sf org open -o YourOrgAlias` to verify), or just use the Developer Console
  (Gear Icon > Developer Console) for all Apex work
- [ ] Working in a sandbox or scratch org (not production)

> **Subscriber orgs:** Use `kern.ClassName` when extending framework classes (e.g., `kern.TRG_Base`,
> `kern.SEL_Base`). Your own classes don't need a namespace prefix: the framework's Type Resolver (how it finds
> the Apex classes in your namespace, once you tell it where to look) handles resolution automatically.

**What you'll build:** A REST API endpoint that receives JSON from external systems, validates the data,
creates a Salesforce record, and returns a structured response.

**Success looks like:** You POST JSON to your endpoint, see a response with the new record ID, and the call
is logged in the Kern app's **API Calls** tab, with 100% test coverage.

**In one line:** `kern.API_Dispatcher.processInboundService(API_ContactFormSubmit.class.getName());` is the only line in the
REST resource; all logic lives in the handler class.

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [Tier 1: See It Work (~2 minutes)](#tier-1-see-it-work-2-minutes)
    - [Call the Echo API](#call-the-echo-api)
    - [How It Works (Two-Class Architecture)](#how-it-works-two-class-architecture)
2. [Tier 2: Build Your Own (~20 minutes)](#tier-2-build-your-own-20-minutes)
    - [Step 1: Create the REST Routing Class](#step-1-create-the-rest-routing-class)
    - [Step 2: Create the API Handler](#step-2-create-the-api-handler)
    - [Step 3: Register Metadata](#step-3-register-metadata)
    - [Step 4: Execute](#step-4-execute)
    - [Step 5: Write Tests](#step-5-write-tests)
3. [Tier 3: Production Patterns (~5 minutes)](#tier-3-production-patterns-5-minutes)
    - [Feature Flag Gating](#feature-flag-gating)
        - [Deploy a feature-flagged API](#deploy-a-feature-flagged-api)
        - [Verify](#verify)
    - [Multiple HTTP Methods on One URL](#multiple-http-methods-on-one-url)
    - [Idempotency](#idempotency)
4. [Sensitive data is masked by default](#sensitive-data-is-masked-by-default)
5. [Common Issues](#common-issues)
6. [What You Now Know](#what-you-now-know)
7. [Next Steps](#next-steps)

</details>

---

## Tier 1: See It Work (~2 minutes)

Before you build anything, prove the framework works end to end. The package ships with a built-in **Echo** endpoint you can call right away, no code needed.

### Call the Echo API

From your terminal (replace `YourOrgAlias` with your subscriber org alias):

```bash
sf api request rest -o YourOrgAlias --method POST --body '{"message":"Hello from Salesforce"}' 'services/apexrest/kern/echo'
```

**Expected output:**

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

### How It Works (Two-Class Architecture)

Every inbound API splits into two classes so that the wiring Salesforce requires stays separate from your own logic. One class only routes the URL; the other does the real work. That split keeps each class small and easy to test on its own.

| Class    | Role                                                             | Visibility                                |
|----------|------------------------------------------------------------------|-------------------------------------------|
| `REST_*` | URL routing only: defines the endpoint, delegates to framework   | `global` (required by Salesforce)         |
| `API_*`  | Business logic: validation, DML, response building               | `global` (or `public` with Type Resolver) |

The Echo API's routing class is just three lines of logic:

```apex
@RestResource(UrlMapping='/echo/*')
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
> and skip the `sf project deploy start` and `sf apex run test` commands.

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

This class defines the URL endpoint. It contains no business logic, just routing. Create a new file named
`REST_ContactForm.cls` and copy the following code exactly as is:

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
@RestResource(UrlMapping='/v1/contact-form/*')
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

### Step 2: Create the API Handler

This class contains all the business logic. Create a new file named `API_ContactFormSubmit.cls` and copy the
following code exactly as is. Do not modify the class name or `kern.*` namespace references.

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
	@JsonAccess(Serializable='always' Deserializable='always')
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
	@JsonAccess(Serializable='always' Deserializable='always')
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

**Deploy:**

```bash
sf project deploy start -o YourOrgAlias -m "ApexClass:REST_ContactForm" -m "ApexClass:API_ContactFormSubmit"
```

### Step 3: Register Metadata

The framework needs to know which handler class serves which URL. You tell it by creating one configuration record (an `ApiSetting__mdt`) instead of wiring it in code, so you can add or change endpoints without a redeploy.

<details open>
<summary><strong>Windows (PowerShell)</strong></summary>

```powershell
New-Item -ItemType Directory -Force -Path force-app/main/default/customMetadata | Out-Null
@'
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <label>Contact Form Submit</label>
    <protected>false</protected>
    <values>
        <field>kern__ClassName__c</field>
        <value xsi:type="xsd:string">API_ContactFormSubmit</value>
    </values>
    <values>
        <field>kern__Direction__c</field>
        <value xsi:type="xsd:string">Inbound</value>
    </values>
    <values>
        <field>kern__EndpointPath__c</field>
        <value xsi:type="xsd:string">/v1/contact-form/*</value>
    </values>
    <values>
        <field>kern__IsActive__c</field>
        <value xsi:type="xsd:boolean">true</value>
    </values>
    <values>
        <field>kern__LogIssues__c</field>
        <value xsi:type="xsd:boolean">true</value>
    </values>
</CustomMetadata>
'@ | Set-Content -Path "force-app/main/default/customMetadata/kern__ApiSetting.ContactFormSubmit.md-meta.xml" -Encoding UTF8
sf project deploy start -o YourOrgAlias -m "CustomMetadata:kern__ApiSetting.ContactFormSubmit" --ignore-conflicts
```

</details>

<details>
<summary><strong>macOS/Linux (bash)</strong></summary>

```bash
mkdir -p force-app/main/default/customMetadata
cat > force-app/main/default/customMetadata/kern__ApiSetting.ContactFormSubmit.md-meta.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <label>Contact Form Submit</label>
    <protected>false</protected>
    <values>
        <field>kern__ClassName__c</field>
        <value xsi:type="xsd:string">API_ContactFormSubmit</value>
    </values>
    <values>
        <field>kern__Direction__c</field>
        <value xsi:type="xsd:string">Inbound</value>
    </values>
    <values>
        <field>kern__EndpointPath__c</field>
        <value xsi:type="xsd:string">/v1/contact-form/*</value>
    </values>
    <values>
        <field>kern__IsActive__c</field>
        <value xsi:type="xsd:boolean">true</value>
    </values>
    <values>
        <field>kern__LogIssues__c</field>
        <value xsi:type="xsd:boolean">true</value>
    </values>
</CustomMetadata>
EOF
sf project deploy start -o YourOrgAlias \
  -m "CustomMetadata:kern__ApiSetting.ContactFormSubmit" --ignore-conflicts
```

</details>

> **Prefer the UI?** Create this record in **Setup > Custom Metadata Types > ApiSetting > Manage Records > New**:
> Label = `Contact Form Submit`, Name = `ContactFormSubmit`, ClassName__c = `API_ContactFormSubmit`,
> Direction__c = `Inbound`, EndpointPath__c = `/v1/contact-form/*`,
> IsActive__c = checked, LogIssues__c = checked.

> **ClassName__c** must match the `API_*` class name exactly (e.g., `API_ContactFormSubmit`), with no
> namespace prefix. The framework finds the class in your namespace for you.

### Step 4: Execute

Call your new API from the terminal:

```bash
sf api request rest -o YourOrgAlias --method POST \
  --body '{"firstName":"Jane","lastName":"Doe","email":"jane.doe@example.com","message":"Hello"}' \
  'services/apexrest/v1/contact-form'
```

**Expected output:**

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

### Step 5: Write Tests

Create `API_ContactFormSubmit_TEST.cls`:

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
@IsTest(IsParallel=true)
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

**Deploy and run:**

```bash
sf project deploy start -o YourOrgAlias -m "ApexClass:API_ContactFormSubmit_TEST"
sf apex run test -o YourOrgAlias -t API_ContactFormSubmit_TEST --code-coverage --synchronous --result-format human
```

**Expected:** 3 tests passing, 100% coverage on `API_ContactFormSubmit`.

> **About the annotations:** `@IsTest(IsParallel=true)` enables parallel test execution (faster runs).
> `SeeAllData` defaults to `false`, so we omit it. `@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')`
> suppresses a code-quality rule about `System.runAs()`: fine for quick starts, but consider adding
> `System.runAs()` in production tests to verify profile and permission set access.

---

## Tier 3: Production Patterns (~5 minutes)

### Feature Flag Gating

Sometimes you want an endpoint deployed but switched off until you decide to turn it on, for example during a phased rollout. You can do that without touching code: point the `RequiredFeatureFlag__c`
field on your `ApiSetting__mdt` record at a [Feature Flag](Fast%20Start%20-%20Feature%20Flags.md). When the flag is not enabled, the framework aborts the request
automatically.

#### Deploy a feature-flagged API

<details open>
<summary><strong>Windows (PowerShell)</strong></summary>

```powershell
@'
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <label>Enable Contact Form API</label>
    <protected>false</protected>
    <values>
        <field>kern__IsActive__c</field>
        <value xsi:type="xsd:boolean">true</value>
    </values>
    <values>
        <field>kern__IsEnabledByDefault__c</field>
        <value xsi:type="xsd:boolean">false</value>
    </values>
</CustomMetadata>
'@ | Set-Content -Path "force-app/main/default/customMetadata/kern__FeatureFlag.EnableContactFormApi.md-meta.xml" -Encoding UTF8
sf project deploy start -o YourOrgAlias -m "CustomMetadata:kern__FeatureFlag.EnableContactFormApi" --ignore-conflicts
```

</details>

<details>
<summary><strong>macOS/Linux (bash)</strong></summary>

```bash
cat > force-app/main/default/customMetadata/kern__FeatureFlag.EnableContactFormApi.md-meta.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <label>Enable Contact Form API</label>
    <protected>false</protected>
    <values>
        <field>kern__IsActive__c</field>
        <value xsi:type="xsd:boolean">true</value>
    </values>
    <values>
        <field>kern__IsEnabledByDefault__c</field>
        <value xsi:type="xsd:boolean">false</value>
    </values>
</CustomMetadata>
EOF
sf project deploy start -o YourOrgAlias \
  -m "CustomMetadata:kern__FeatureFlag.EnableContactFormApi" --ignore-conflicts
```

</details>

Now set `RequiredFeatureFlag__c` on the ApiSetting: **Setup > Custom Metadata Types > ApiSetting > Manage
Records > ContactFormSubmit > Edit > RequiredFeatureFlag = `EnableContactFormApi` > Save**.

#### Verify

```bash
sf api request rest -o YourOrgAlias --method POST \
  --body '{"firstName":"Jane","lastName":"Doe","email":"jane@test.com","message":"Test"}' \
  'services/apexrest/v1/contact-form'
```

**Expected output** (the flag is disabled, so the framework returns the error messages as a bare JSON array):

```json
["Required condition \"EnableContactFormApi\" is not met"]
```

Enable the flag (set `IsEnabledByDefault = true` or create a strategy) and the API starts accepting
requests again. Use `BypassFeatureFlag__c` instead for a kill-switch (a master off-switch you can flip in an incident
without a deployment): the service is bypassed when the flag is **enabled**.

### Multiple HTTP Methods on One URL

One URL can serve more than one action, for example POST to submit a form and GET to read submissions back. You add more methods to the same `REST_*` class. Each HTTP method hands off to a different `API_*` handler
class, each with its own `ApiSetting__mdt` record:

```apex
@RestResource(UrlMapping='/v1/contact-form/*')
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

A flaky network or an over-eager retry can send the same request twice and create two records when the caller meant one. Idempotency prevents that: if the exact same request arrives twice, the first result is returned again rather than re-run. Turn it on by setting `IdempotencyEnabled__c = true` on
your `ApiSetting__mdt` record (**Setup > Custom Metadata Types > ApiSetting > ContactFormSubmit > Edit >
IdempotencyEnabled = checked > Save**).

Callers include an `Idempotency-Key` header:

```bash
# First call — creates the Lead
sf api request rest -o YourOrgAlias --method POST \
  --header 'Idempotency-Key: unique-request-123' \
  --body '{"firstName":"Jane","lastName":"Doe","email":"jane@test.com","message":"Test"}' \
  'services/apexrest/v1/contact-form'

# Second call with same key + same body — returns cached response (HTTP 200), no duplicate Lead
sf api request rest -o YourOrgAlias --method POST \
  --header 'Idempotency-Key: unique-request-123' \
  --body '{"firstName":"Jane","lastName":"Doe","email":"jane@test.com","message":"Test"}' \
  'services/apexrest/v1/contact-form'
```

The first call creates the Lead and returns a success response. The second call recognises the duplicate
`Idempotency-Key` and returns the **same cached response** (HTTP 200) without re-running the handler: no
duplicate Lead is created and the caller sees the original success payload.

There is one deliberate exception. If a caller reuses the same key with a **different request body** (for example a buggy retry that mutated the payload),
the framework rejects it with **HTTP 409** rather than silently masking the change, and returns a JSON body containing the original `ApiCall.Id` so the caller can
reconcile against the conflicting request. See [Idempotency in the Web Services Guide](Web%20Services%20-%20Guide.md#idempotency-inbound-apis)
for the full replay table and 409 response shape.

> **No CLI?** You can test idempotency from [Workbench](https://workbench.developerforce.com/) too: REST Explorer >
> POST > `/services/apexrest/v1/contact-form` > add header `Idempotency-Key: unique-request-123` > paste the JSON
> body > Execute twice.

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

## Common Issues

| Problem                                     | Cause                                                      | Fix                                                                                                                                                                                   |
|---------------------------------------------|------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `Type cannot be deserialized`               | `public` class not visible to package                      | Make the class `global`, or set up a Type Resolver ([details](Utilities%20-%20Guide.md#type-resolution-util_typeresolver))                                                            |
| `No ApiSetting found`                       | Missing or mismatched metadata                             | Check `ClassName__c` matches your simple class name and `Direction__c` is `Inbound`                                                                                                   |
| `super.configure()` not called              | Missing `super` in override                                | Always call `super.configure()` first                                                                                                                                                 |
| NullPointerException in test                | RestContext not initialized                                | Use `kern.API_InboundTestHelper.setupRestContext()` or the `assertCall*` methods                                                                                                      |
| Business logic in REST_ class               | Bypass of framework logging/validation                     | Move all logic to the `API_*` class; REST_ class only delegates                                                                                                                       |
| DML error in `onSuccess()`                  | Using `insert` instead of `doInsert()`                     | Use inherited `doInsert()`/`doUpdate()`; the framework commits all DML together                                                                                                       |
| Missing `@JsonAccess` on DTO                | Runtime serialization error                                | Add `@JsonAccess(Serializable='always' Deserializable='always')`                                                                                                                      |
| Sensitive value appears raw on `ApiCall__c` | Field not covered by a masking target, or rule is inactive | Add a `kern__MaskingTarget__mdt` record with the rule, `SObjectType__c = ApiCall__c`, and a `Field__c` (blank for wildcard); see [Web Services Guide](Web%20Services%20-%20Guide.md) |

---

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
