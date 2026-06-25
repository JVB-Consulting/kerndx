---
navOrder: 32
---

# Fast Start - Outbound APIs

**Framework:** KernDX | **Total time:** ~30 minutes

**What this is:** A way to call an external system (a payment gateway, a shipping API, any REST endpoint) from Salesforce, starting with a single line of Apex and growing into a fully tested, production-ready service. **Why it exists:** Hand-rolled HTTP callouts repeat the same plumbing every time (retries, timeouts, logging, error handling) and break in ways that are hard to trace. KernDX gives you that plumbing once, the same way every time. **Who should follow this:** developers building integrations, and tech leads who want callouts that are logged, tested, and consistent. **When to use it:** any time Salesforce needs to send data to, or fetch data from, another system.

**Before you start:**

- [ ] KernDX package installed in your org
- [ ] Org configured post-install. Verify with the **Kern** app's Health Check (see [Installation guide](Installation.md#post-install-configuration))
- [ ] CLI authenticated (run `sf org open -o YourOrgAlias` to verify), or just use the Developer Console
  (Gear Icon > Developer Console) for all Apex work
- [ ] Working in a sandbox or scratch org (not production)

> **Subscriber orgs:** Use `kern.ClassName` when extending framework classes (e.g., `kern.TRG_Base`,
> `kern.SEL_Base`). Your own classes don't need a namespace prefix — the framework's Type Resolver handles
> resolution automatically.

**What you'll build:** A working outbound HTTP call to an external API. You start with a one-liner and
finish with a production-ready service that has typed DTOs (small classes that hold exactly the fields you
send and receive, and convert themselves to and from JSON), input validation, and automated tests.

**Success looks like:** Your API call appears in the Kern app's **API Calls** tab with full request/response
logging, and your test class has 100% code coverage.

**In one line:** `kern.UTIL_HttpClient.post('PaymentGateway', '/charges').body(request).withRetry(3).send();`
That single call comes with automatic retries, a circuit breaker (after repeated failures the framework
stops calling a failing system for a cool-off, then resumes), and logging already built in.

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [Tier 1: See It Work (~2 minutes)](#tier-1-see-it-work-2-minutes)
    - [Check the Named Credential](#check-the-named-credential)
    - [GET Request](#get-request)
    - [POST Request](#post-request)
    - [Builder Features](#builder-features)
2. [Tier 2: Build Your Own (~15 minutes)](#tier-2-build-your-own-15-minutes)
    - [Step 1: Create the API Handler](#step-1-create-the-api-handler)
    - [Step 2: Register Metadata](#step-2-register-metadata)
        - [2a. Create ApiCredential](#2a-create-apicredential)
        - [2b. Create ApiSetting](#2b-create-apisetting)
    - [Step 3: Execute](#step-3-execute)
    - [Step 4: Write Tests](#step-4-write-tests)
    - [Step 5: Add Validation](#step-5-add-validation)
    - [Step 6: Understanding Mocks](#step-6-understanding-mocks)
3. [Tier 3: Production Patterns (~10 minutes)](#tier-3-production-patterns-10-minutes)
    - [From a Flow](#from-a-flow)
        - [Build a Screen Flow (step-by-step)](#build-a-screen-flow-step-by-step)
    - [From Apex (Queue-Based)](#from-apex-queue-based)
4. [Sensitive data is masked by default](#sensitive-data-is-masked-by-default)
5. [Common Issues](#common-issues)
6. [What You Now Know](#what-you-now-know)
7. [Next Steps](#next-steps)

</details>

---

## Tier 1: See It Work (~2 minutes)

The fastest way to prove a callout works is to make one with no setup at all. For quick calls and prototyping,
you can fire an HTTP request straight from anonymous Apex, with no custom classes to write. The helper that
does this is [`UTIL_HttpClient`](reference/apex/UTIL_HttpClient.md).

### Check the Named Credential

So you can try everything here without signing up for anything, the package ships with a ready-made
connection called **Example REST API** (`kern__API_ExampleRestApi`). It points to
[JSONPlaceholder](https://jsonplaceholder.typicode.com), a free, public fake API. No API keys needed.

Go to **Setup > Named Credentials** and confirm you see it with endpoint `https://jsonplaceholder.typicode.com`
and **Callout Status** `Enabled`.

### GET Request

Open **Developer Console > Debug > Open Execute Anonymous Window** and run:

```apex
Map<String, Object> post = kern.UTIL_HttpClient.get('kern__API_ExampleRestApi', '/posts/1').asMap();
System.debug(JSON.serializePretty(post));
```

**Expected output:**

```json
{
  "userId" : 1,
  "id" : 1,
  "title" : "sunt aut facere repellat provident occaecati excepturi optio reprehenderit",
  "body" : "quia et suscipit\nsuscipit recusandae..."
}
```

### POST Request

```apex
Map<String, Object> body = new Map<String, Object>{
	'title' => 'Hello from Salesforce',
	'body' => 'This post was created via KernDX',
	'userId' => 1
};

HttpResponse response = kern.UTIL_HttpClient.post('kern__API_ExampleRestApi', '/posts')
	.body(body)
	.send();

System.debug('Status: ' + response.getStatusCode());
System.debug('Body: ' + response.getBody());
```

**Expected output:**

```text
Status: 201
Body: {"id": 101}
```

> **Review your calls:** Open the **Kern** app (App Launcher > Kern) and click the **API Calls** tab to see
> every call logged with full request/response details, status, and timing.

### Builder Features

You configure each call with short chained method calls, then one final call (such as `.send()`) runs it
and returns the result. Here are the common options you can add to any call:

```apex
// Headers
kern.UTIL_HttpClient.get('kern__API_ExampleRestApi', '/posts/1')
	.header('Accept', 'application/json')
	.send();

// Query parameters — GET /comments?postId=1
kern.UTIL_HttpClient.get('kern__API_ExampleRestApi', '/comments')
	.queryParam('postId', '1')
	.asString();

// Path parameters — GET /posts/42
kern.UTIL_HttpClient.get('kern__API_ExampleRestApi', '/posts/{id}')
	.pathParam('id', '42')
	.asMap();

// Timeout (milliseconds)
kern.UTIL_HttpClient.get('kern__API_ExampleRestApi', '/posts/1')
	.timeout(5000)
	.send();

// Retry + circuit breaker
kern.UTIL_HttpClient.post('kern__API_ExampleRestApi', '/posts')
	.body(new Map<String, Object>{'title' => 'Test', 'body' => 'Testing', 'userId' => 1})
	.withRetry(3)
	.withCircuitBreaker()
	.onFailure(kern.UTIL_HttpClient.FailureAction.RETRY_THEN_LOG)
	.send();
```

> **When to move to Tier 2:** Move on once you need typed DTOs (the small request/response classes),
> input validation, tests that run without real callouts and assert in one line, or retry and circuit
> breaker settings managed as configuration records rather than in code.

---

## Tier 2: Build Your Own (~15 minutes)

> **No local project?** You can create classes directly in the Developer Console (Gear Icon > Developer
> Console > File > New > Apex Class) and run tests from there too (Test > New Run). Paste the code, save,
> and skip the `sf project deploy start` and `sf apex run test` commands.

A one-liner is great for trying things out, but a real integration needs structure: known request and
response shapes, validation, and tests. In this tier you build a reusable API handler class
(`API_GetPost`) that fetches a post from JSONPlaceholder by ID. It comes with typed DTOs (the request and
response classes), test coverage, and parameter validation.

### Step 1: Create the API Handler

Create a new file named `API_GetPost.cls`. Copy the following code exactly as is. Do not modify the class
name or the `kern.*` namespace references.

> **Why `global`?** This lets the managed package find and run your class at runtime without any extra setup.
> If you prefer `public with sharing`, you instead point the framework at where your classes live (a Type
> Resolver class: how the framework finds the Apex classes in your namespace, where you tell it where to
> look). The Kern home page health check generates that code for you, or see
> [Type Resolution](Utilities%20-%20Guide.md#type-resolution-util_typeresolver).

```apex
/**
 * @description Fetches a post from JSONPlaceholder by ID.
 *
 * @see API_GetPost_TEST
 *
 * @author your.name@company.com
 *
 * @group Web Services
 *
 * @date February 2026
 */
global with sharing class API_GetPost extends kern.API_Outbound
{
	/** @description Parameter name for the post ID. */
	@TestVisible
	private static final String PARAM_POST_ID = 'postId';

	/**
	 * @description Initializes DTOs, mock body, and configuration.
	 */
	public override void configure()
	{
		super.configure();
		requestPayload = new DTO_Request();
		responsePayload = new DTO_Response();
		// This JSON string is returned instead of making a real HTTP call during tests
		defaultMockBody = '{"userId": 1, "id": 1, "title": "Mock Post Title", "body": "Mock post body"}';
		requiresTriggeringRecord = false;
	}

	/**
	 * @description Overrides HTTP method to GET (default is POST).
	 *
	 * @return The HTTP method for this service.
	 */
	public override kern.API_Base.HttpMethod getHttpMethod()
	{
		return kern.API_Base.HttpMethod.GET;
	}

	/**
	 * @description Appends the post ID to the endpoint path.
	 *
	 * @return The full endpoint URL.
	 */
	public override String getWebServiceEndPoint()
	{
		return super.getWebServiceEndPoint() + '/' + inputs.get(PARAM_POST_ID);
	}

	/**
	 * @description Registers required input parameters.
	 *
	 * @return The set of required parameter names.
	 */
	public override Set<String> getRequiredInputs()
	{
		Set<String> requiredInputs = super.getRequiredInputs();
		requiredInputs.add(PARAM_POST_ID);
		return requiredInputs;
	}

	// @JsonAccess is required for managed packages — the framework runs in the kern namespace
	// and needs explicit serialization access to your DTO fields
	/** @description Request DTO (empty for GET requests -- parameters go in the URL). */
	@JsonAccess(Serializable='always' Deserializable='always')
	global class DTO_Request extends kern.DTO_JsonBase
	{
	}

	/** @description Response DTO matching the JSONPlaceholder post schema. */
	@JsonAccess(Serializable='always' Deserializable='always')
	global class DTO_Response extends kern.DTO_JsonBase
	{
		/** @description The user who created the post. */
		private Integer userId;

		/** @description The post ID. */
		private Integer id;

		/** @description The post title. */
		private String title;

		/** @description The post body text. */
		private String body;

		/**
		 * @description Returns the Type used for deserialization.
		 *
		 * @return The DTO_Response Type.
		 */
		public override Type getObjectType()
		{
			return DTO_Response.class;
		}
	}
}
```

**Deploy:**

```bash
sf project deploy start -o YourOrgAlias -m "ApexClass:API_GetPost"
```

### Step 2: Register Metadata

Your handler class is written, but the framework still needs to know how to run it. You tell it with two
configuration records: an **ApiCredential** record (which Named Credential, that is, which connection, to
use) and an **ApiSetting** record (how to run your handler).

#### 2a. Create ApiCredential

The ApiCredential record tells the framework which Named Credential (which connection) to use for HTTP calls.

<details>
<summary><strong>Windows (PowerShell)</strong></summary>

```powershell
New-Item -ItemType Directory -Force -Path force-app/main/default/customMetadata | Out-Null
@'
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <label>Example REST API</label>
    <protected>false</protected>
    <values>
        <field>kern__NamedCredential__c</field>
        <value xsi:type="xsd:string">kern__API_ExampleRestApi</value>
    </values>
</CustomMetadata>
'@ | Set-Content -Path "force-app/main/default/customMetadata/kern__ApiCredential.API_ExampleRestApi.md-meta.xml" -Encoding UTF8
sf project deploy start -o YourOrgAlias -m "CustomMetadata:kern__ApiCredential.API_ExampleRestApi" --ignore-conflicts
```

</details>

<details>
<summary><strong>macOS/Linux (bash)</strong></summary>

```bash
mkdir -p force-app/main/default/customMetadata
cat > force-app/main/default/customMetadata/kern__ApiCredential.API_ExampleRestApi.md-meta.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <label>Example REST API</label>
    <protected>false</protected>
    <values>
        <field>kern__NamedCredential__c</field>
        <value xsi:type="xsd:string">kern__API_ExampleRestApi</value>
    </values>
</CustomMetadata>
EOF
sf project deploy start -o YourOrgAlias \
  -m "CustomMetadata:kern__ApiCredential.API_ExampleRestApi" --ignore-conflicts
```

</details>

> **Prefer the UI?** Create this record in **Setup > Custom Metadata Types > ApiCredential > Manage Records > New**:
> Label = `Example REST API`, Name = `API_ExampleRestApi`, NamedCredential__c = `kern__API_ExampleRestApi`.

> **Why create this?** The package ships an `ApiCredential` record for the Example REST API, but it is
> protected (kept internal to the package), so your code cannot reference it. Your org needs its own
> `ApiCredential` record that points to the same Named Credential.

#### 2b. Create ApiSetting

The ApiSetting record configures how your handler runs: its class name, endpoint path, retry policy, and more.

<details>
<summary><strong>Windows (PowerShell)</strong></summary>

```powershell
@'
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <label>API Get Post</label>
    <protected>false</protected>
    <values>
        <field>kern__ApiCredential__c</field>
        <value xsi:type="xsd:string">API_ExampleRestApi</value>
    </values>
    <values>
        <field>kern__CircuitBreakerEnabled__c</field>
        <value xsi:type="xsd:boolean">true</value>
    </values>
    <values>
        <field>kern__ClassName__c</field>
        <value xsi:type="xsd:string">API_GetPost</value>
    </values>
    <values>
        <field>kern__Direction__c</field>
        <value xsi:type="xsd:string">Outbound</value>
    </values>
    <values>
        <field>kern__EndpointPath__c</field>
        <value xsi:type="xsd:string">/posts</value>
    </values>
    <values>
        <field>kern__IsActive__c</field>
        <value xsi:type="xsd:boolean">true</value>
    </values>
    <values>
        <field>kern__LogIssues__c</field>
        <value xsi:type="xsd:boolean">true</value>
    </values>
    <values>
        <field>kern__MaxRetryCount__c</field>
        <value xsi:type="xsd:double">3.0</value>
    </values>
    <values>
        <field>kern__RetryBackoffSeconds__c</field>
        <value xsi:type="xsd:double">5.0</value>
    </values>
</CustomMetadata>
'@ | Set-Content -Path "force-app/main/default/customMetadata/kern__ApiSetting.API_GetPost.md-meta.xml" -Encoding UTF8
sf project deploy start -o YourOrgAlias -m "CustomMetadata:kern__ApiSetting.API_GetPost" --ignore-conflicts
```

</details>

<details>
<summary><strong>macOS/Linux (bash)</strong></summary>

```bash
cat > force-app/main/default/customMetadata/kern__ApiSetting.API_GetPost.md-meta.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <label>API Get Post</label>
    <protected>false</protected>
    <values>
        <field>kern__ApiCredential__c</field>
        <value xsi:type="xsd:string">API_ExampleRestApi</value>
    </values>
    <values>
        <field>kern__CircuitBreakerEnabled__c</field>
        <value xsi:type="xsd:boolean">true</value>
    </values>
    <values>
        <field>kern__ClassName__c</field>
        <value xsi:type="xsd:string">API_GetPost</value>
    </values>
    <values>
        <field>kern__Direction__c</field>
        <value xsi:type="xsd:string">Outbound</value>
    </values>
    <values>
        <field>kern__EndpointPath__c</field>
        <value xsi:type="xsd:string">/posts</value>
    </values>
    <values>
        <field>kern__IsActive__c</field>
        <value xsi:type="xsd:boolean">true</value>
    </values>
    <values>
        <field>kern__LogIssues__c</field>
        <value xsi:type="xsd:boolean">true</value>
    </values>
    <values>
        <field>kern__MaxRetryCount__c</field>
        <value xsi:type="xsd:double">3.0</value>
    </values>
    <values>
        <field>kern__RetryBackoffSeconds__c</field>
        <value xsi:type="xsd:double">5.0</value>
    </values>
</CustomMetadata>
EOF
sf project deploy start -o YourOrgAlias \
  -m "CustomMetadata:kern__ApiSetting.API_GetPost" --ignore-conflicts
```

</details>

> **Prefer the UI?** Create this record in **Setup > Custom Metadata Types > ApiSetting > Manage Records > New**:
> Label = `API Get Post`, Name = `API_GetPost`, ClassName__c = `API_GetPost`, Direction__c = `Outbound`,
> EndpointPath__c = `/posts`, ApiCredential__c = (select) `Example REST API`,
> IsActive__c = checked, LogIssues__c = checked, MaxRetryCount__c = `3`, RetryBackoffSeconds__c = `5`,
> CircuitBreakerEnabled__c = checked.

> **ClassName__c** is the simple class name (`API_GetPost`), without a namespace prefix. The framework's
> type resolver (how it finds your classes) handles the namespace for you.
>
> **ApiCredential__c** is a lookup (a metadata relationship) to `ApiCredential__mdt`. Select the record you
> created in step 2a.

> **How the HTTP verb is set for outbound calls:** `getHttpMethod()` in your handler class decides the verb.
> The framework reads it inside `setHeaders()` and applies it to the request that goes over the wire. The
> default (when you do not override it) is `POST`, so override `getHttpMethod()` to use a different verb.

### Step 3: Execute

Test from anonymous Apex:

```apex
// Use the simple DeveloperName (e.g., 'API_ExampleRestApi'), not the namespace-prefixed version
kern.API_Outbound handler = kern.UTIL_HttpClient.useHandler(API_GetPost.class)
	.credential('API_ExampleRestApi')
	.withParameter('postId', '1')
	.invoke();

System.debug('Success: ' + handler.result.isSuccess);
System.debug('Response: ' + handler.result.responseBody);
```

**Expected output:**

```text
Success: true
Response: {"userId": 1, "id": 1, "title": "sunt aut facere repellat provident...", "body": "quia et suscipit..."}
```

> **See it in the org:** Open **App Launcher > Kern > API Calls** tab and select the **All** list view.
> You'll see your call logged with the full request/response details, status, and timing. This visual
> confirmation is the real proof it worked.

### Step 4: Write Tests

Create `API_GetPost_TEST.cls`:

```apex
/**
 * @description Unit tests for API_GetPost.
 *
 * @see API_GetPost
 *
 * @author your.name@company.com
 *
 * @group Web Services
 *
 * @date February 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(IsParallel=true)
private class API_GetPost_TEST
{
	/** @description The API service class name. */
	private static final String SERVICE_NAME = API_GetPost.class.getName();

	/** @description Test value for post ID parameter. */
	private static final String TEST_POST_ID = '1';

	/** @description Tests a successful API call with valid parameters. */
	@IsTest
	private static void shouldFetchPostSuccessfully()
	{
		Map<String, String> parameters = new Map<String, String>{
			API_GetPost.PARAM_POST_ID => TEST_POST_ID
		};

		// Framework intercepts the callout and returns defaultMockBody -- no real HTTP call is made
		kern.API_OutboundTestHelper.assertCallSuccessful(SERVICE_NAME, null, parameters);
	}

	/** @description Tests that the call is aborted when the post ID parameter is missing. */
	@IsTest
	private static void shouldAbortWhenPostIdMissing()
	{
		kern.API_OutboundTestHelper.assertCallAborted(SERVICE_NAME, null);
	}
}
```

**Deploy and run:**

```bash
sf project deploy start -o YourOrgAlias -m "ApexClass:API_GetPost_TEST"
sf apex run test -o YourOrgAlias -t API_GetPost_TEST --code-coverage --synchronous --result-format human
```

**Expected:** 2 tests passing, 100% coverage on `API_GetPost`.

> **About the annotations:** `@IsTest(IsParallel=true)` lets tests run in parallel, which makes the run
> faster. `SeeAllData` defaults to `false`, so we omit it. `@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')`
> turns off a code-scanner rule about `System.runAs()`. That is fine for a quick start, but in production
> tests consider adding `System.runAs()` to verify profile and permission set access.

### Step 5: Add Validation

Sometimes a request should be rejected before it ever leaves your org, for example when an input is the
wrong shape. You can add your own checks that run before the HTTP call. Add this method to `API_GetPost.cls`
after `getRequiredInputs()`:

```apex
/**
 * @description Validates that the post ID is a positive integer.
 *
 * @return A list of validation error messages. Empty list means validation passed.
 */
public override List<String> getValidationErrors()
{
	List<String> errors = new List<String>();
	String postId = inputs.get(PARAM_POST_ID);

	if(!postId.isNumeric())
	{
		errors.add('Post ID must be a numeric value');
	}

	return errors;
}
```

Add a test for the abort path in `API_GetPost_TEST.cls`:

```apex
/** @description Tests that the call is aborted when post ID is not numeric. */
@IsTest
private static void shouldAbortWhenPostIdNotNumeric()
{
	Map<String, String> parameters = new Map<String, String>{
		API_GetPost.PARAM_POST_ID => 'abc'
	};

	kern.API_OutboundTestHelper.assertCallAborted(SERVICE_NAME, null, parameters);
}
```

**Redeploy and run:**

```bash
sf project deploy start -o YourOrgAlias -m "ApexClass:API_GetPost" -m "ApexClass:API_GetPost_TEST"
sf apex run test -o YourOrgAlias -t API_GetPost_TEST --code-coverage --synchronous --result-format human
```

**Expected:** 3 tests passing, 100% coverage.

**Try it out:** Run these in **Execute Anonymous** to see validation in action:

```apex
// Invalid post ID — should abort with validation error
kern.API_Outbound handler = kern.UTIL_HttpClient.useHandler(API_GetPost.class)
	.credential('API_ExampleRestApi')
	.withParameter('postId', 'ABC')
	.invoke();

System.debug('Success: ' + handler.result.isSuccess);
System.debug('Errors: ' + handler.result.errors);
```

**Expected output:**

```text
Success: false
Errors: (Post ID must be a numeric value)
```

Check the **API Calls** tab. You'll see an entry with status **Aborted** and the validation error logged.

```apex
// Valid post ID — should succeed
kern.API_Outbound handler = kern.UTIL_HttpClient.useHandler(API_GetPost.class)
	.credential('API_ExampleRestApi')
	.withParameter('postId', '1')
	.invoke();

System.debug('Success: ' + handler.result.isSuccess);
System.debug('Response: ' + handler.result.responseBody);
```

### Step 6: Understanding Mocks

Your tests already passed without calling the real API. That matters because tests must not depend on a
live external system. Here is why it works, and how to customise it.

**The simple way (`defaultMockBody`):**

The `defaultMockBody` you set in `configure()` is the stand-in response. When tests run, the framework
intercepts the HTTP callout and returns that JSON instead of calling JSONPlaceholder. There is no extra
setup and no `Test.setMock()` to wire up: the framework handles it.

```apex
// In configure() — this IS your test mock
defaultMockBody = '{"userId": 1, "id": 1, "title": "Mock Post Title", "body": "Mock post body"}';
```

**Custom mocks (`API_MockFactory`):**

Sometimes one test needs a different response, for example to check how your code handles an error or an
edge case. For that, use `API_MockFactory`:

```apex
// Return a custom response body
kern.API_MockFactory.forService(SERVICE_NAME)
	.body('{"userId": 99, "id": 42, "title": "Custom", "body": "Custom mock"}')
	.statusCode(200)
	.register();

// Simulate a 500 error — tests your error handling
kern.API_MockFactory.registerErrorMock(SERVICE_NAME);

// Simulate unparseable response — tests your parse failure handling
kern.API_MockFactory.registerParseFailMock(SERVICE_NAME);
```

Add this test to `API_GetPost_TEST.cls` to see error mocking in action:

```apex
/** @description Tests that the call fails when the API returns a server error. */
@IsTest
private static void shouldFailWhenApiReturnsError()
{
	kern.API_MockFactory.registerErrorMock(SERVICE_NAME);

	Map<String, String> parameters = new Map<String, String>{
		API_GetPost.PARAM_POST_ID => TEST_POST_ID
	};

	kern__ApiCall__c apiCall = kern.TST_Factory.newOutboundApiCall(SERVICE_NAME, null, parameters);
	kern.API_OutboundTestHelper.assertCallFailed(new List<kern__ApiCall__c>{apiCall});
}
```

> **More mocking features:** Dynamic response interpolation (`{{request.field}}`), fault injection
> (`.withFailureRate()`), invocation verification (`API_MockFactory.wasCalled()`). See
> [Web Services - Guide](Web%20Services%20-%20Guide.md) for the full mocking API.

---

## Tier 3: Production Patterns (~10 minutes)

### From a Flow

Not every callout starts in Apex. To let an admin trigger your handler from a screen flow without writing
code, the package includes [`FLOW_CallApi`](reference/apex/FLOW_CallApi.md), an invocable action that calls
any registered `API_Outbound` handler from a Flow.

#### Build a Screen Flow (step-by-step)

1. Go to **Setup > Flows > New Flow > Screen Flow > Create**
2. **Add a Screen** element:
    - **Label:** `Enter Post ID`
    - Add a **Text** input component:
        - **Label:** `Post ID`
        - **API Name:** `postId`
        - **Required:** checked
3. **Add an Action** element after the Screen:
    - In the search box, type **Invoke Callout Synchronously** and select it
    - **Label:** `Fetch Post`
    - Set input values:
        - **apiName:** `API_GetPost`
        - **inputs:** Use a formula: `'postId=' & {!Enter_Post_ID.postId}`
4. **Add a second Screen** element:
    - **Label:** `API Result`
    - Add a **Display Text** component:
        - **Content:** `Response: {!Fetch_Post.responseBody}`
5. Click **Save**:
    - **Flow Label:** `Get Post Demo`
    - **Flow API Name:** `Get_Post_Demo`
6. Click **Activate**

> **Test it:** Click **Debug** in Flow Builder, enter a Post ID (e.g., `1`), and click **Run**. The second
> screen shows the JSON response from JSONPlaceholder.

The `inputs` field uses `key=value` format, comma-delimited for multiple parameters
(e.g., `postId=1,format=json`).

### From Apex (Queue-Based)

For calls that should run in the background rather than while a user waits, create a `kern__ApiCall__c`
record directly. A record-triggered flow in the framework picks up the item, runs the call asynchronously,
and logs the result:

```apex
kern__ApiCall__c queueItem = new kern__ApiCall__c(
	kern__ServiceName__c = API_GetPost.class.getName(),
	kern__Direction__c = 'Outbound',
	kern__Status__c = 'Queued',
	kern__RequestParameters__c = '{"postId":"1"}'
);

kern.DML_Builder.newTransaction().doInsert(queueItem).execute();
System.debug('Queue item created: ' + queueItem.Id);
```

> **Note:** `kern.TST_Factory.newOutboundApiCall()` is a **test-only** utility. In production code, create
> `kern__ApiCall__c` records directly as shown above.

Check status after a few seconds using the built-in `SEL_ApiCall` selector:

```apex
List<kern__ApiCall__c> calls = new kern.SEL_ApiCall().findByServiceName('API_GetPost');

for(kern__ApiCall__c apiCall : calls)
{
	System.debug('Status: ' + apiCall.kern__Status__c);
}
```

> **Lifecycle:** `Queued` -> `Processing` -> `Completed` / `Failed` / `Aborted`. Failed items retry
> automatically per the `MaxRetryCount__c` setting. See [Web Services - Guide](Web%20Services%20-%20Guide.md).

---

## Sensitive data is masked by default

Logging every call is useful, but you do not want secrets sitting in those logs. `ApiCall__c` records store
the request body, response body, URL, and parameters captured from every outbound call, so before any of
that is saved, it passes through the data masking framework and sensitive values are redacted. Out of the
box, two rules fire:

- **`MaskSecretKeys`** redacts common secret JSON keys (`password`, `token`, `apiKey`, `authorization`,
  `bearer`, `client_secret`, `private_key`, `access_token`, `refresh_token`).
- **`MaskPaymentCard`** redacts 13–19 digit sequences that pass the Luhn (mod-10) checksum, covering all
  major card brands; the digits may be separated by spaces or hyphens. (This replaces the original
  `MaskCreditCard` rule, which still ships for compatibility.)

So if your outbound request body contains a `password` or a card number, the saved `ApiCall__c.Request__c`
has them redacted. The actual HTTP request going over the wire is unchanged: only the stored copy is masked.
Fifteen more rules ship as inactive templates (SSN, IBAN, SWIFT/BIC, MBI, health keywords, email, US phone,
JWT, AWS access key, URL basic auth, authorization header, private IPv4, postal address, free text, and
international phone). To switch one on, set `kern__MaskingRule__mdt.IsActive__c = true` and add a
`kern__MaskingTarget__mdt` record that wires the rule to the field(s) that need it.

## Common Issues

| Problem                                      | Cause                                 | Fix                                                                                                                        |
|----------------------------------------------|---------------------------------------|----------------------------------------------------------------------------------------------------------------------------|
| `Type cannot be serialized`                  | Missing `@JsonAccess` on DTO          | Add `@JsonAccess(Serializable='always' Deserializable='always')`                                                           |
| `Type cannot be deserialized`                | `public` class not visible to package | Make the class `global`, or set up a Type Resolver ([details](Utilities%20-%20Guide.md#type-resolution-util_typeresolver)) |
| `No ApiSetting found`                        | Missing or mismatched metadata        | Check `ClassName__c` matches your simple class name (e.g., `API_GetPost`, not namespace-prefixed)                          |
| `Required parameter missing`                 | Parameter not passed                  | Check `getRequiredInputs()` for required names                                                                             |
| Named Credential not found                   | Wrong credential name                 | Use `kern__API_ExampleRestApi` (namespace-prefixed)                                                                        |
| `no CustomMetadata named ApiCredential...`   | ApiCredential record missing          | Create your own `ApiCredential__mdt` record (step 2a); the package's is protected                                          |
| `Uncommitted work pending`                   | DML during callout phase              | Move DML to `onSuccess()` using `DML_Builder`                                                                              |
| `super.configure()` not called               | Missing `super` in override           | Always call `super.configure()` first                                                                                      |
| Sensitive value not redacted on `ApiCall__c` | Field not covered by a masking target | Add a `kern__MaskingTarget__mdt` record (see Web Services Guide)                                                           |

---

## What You Now Know

After completing this guide, you understand the **three ways** to make outbound HTTP calls with KernDX:

| Approach                       | When to Use                              | What You Get                                                                  |
|--------------------------------|------------------------------------------|-------------------------------------------------------------------------------|
| **`UTIL_HttpClient`** (Tier 1) | Quick calls, prototyping, anonymous Apex | Fluent one-liners with optional retry and circuit breaker                     |
| **`API_Outbound`** (Tier 2)    | Production integrations                  | Typed DTOs, input validation, mock testing, automatic logging to `ApiCall__c` |
| **Orchestration** (Tier 3)     | Flow-driven or async processing          | Declarative triggers via `FLOW_CallApi`, queue-based retry with `ApiCall__c`  |

**Key patterns:**

- **`configure()`**: set up DTOs and `defaultMockBody` (always call `super.configure()` first)
- **`getRequiredInputs()`**: declare mandatory parameters; the framework aborts the call if one is missing
- **`getValidationErrors()`**: your own business validation, run before the HTTP call
- **`getHttpMethod()`**: override this if the verb is not POST (the default)
- **`getWebServiceEndPoint()`**: build the URL path dynamically
- **`onSuccess()`**: run DML after the call, using `DML_Builder`
- **`@JsonAccess`**: required on every DTO in a managed package context
- **`defaultMockBody`**: the simple mock that lets tests run without real HTTP callouts
- **`API_MockFactory`**: custom mocks for error paths, edge cases, and fault injection
- **`API_OutboundTestHelper`**: one-line test assertions for the success, abort, and failure paths
- **DML/Callout ordering**: the framework handles the `Uncommitted work pending` problem for you.
  `onSuccess()` runs after the callout completes, so DML and callouts never conflict.
- **Kern Home Page / API Calls tab**: live visibility into every API call result

---

## Next Steps

- [Building Inbound APIs](Fast%20Start%20-%20Inbound%20APIs.md)
- [Feature Flag Gating](Fast%20Start%20-%20Feature%20Flags.md)
- [Complete Web Services Guide](Web%20Services%20-%20Guide.md)
- [Retry & Circuit Breaker](Web%20Services%20-%20Guide.md#advanced-features)
