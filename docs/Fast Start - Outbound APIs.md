---
navOrder: 32
---

# Fast Start - Outbound APIs

**Framework:** KernDX | **Total time:** ~30 minutes

**What this is:** A way to call an external system (a payment gateway, a shipping API, any REST endpoint) from Salesforce, starting with a single line of Apex and growing into a fully tested, production-ready service. **Why it exists:** Hand-rolled HTTP callouts repeat the same plumbing every time (retries, timeouts, logging, error handling) and break in ways that are hard to trace. KernDX gives you that plumbing once, the same way every time. **Who should follow this:** developers building integrations, and tech leads who want callouts that are logged, tested, and consistent. **When to use it:** any time Salesforce needs to send data to, or fetch data from, another system.

> **Namespaces in code samples:** `kern.` on a class and `kern__` on an object, field, or metadata type mark the managed package's namespace.
> On the managed package, framework references need those prefixes even where a sample omits them; repackaged under your own namespace, replace `kern`/`kern__`
> with your prefix; on an unmanaged deploy, drop them. See [How to read the code samples](Installation.md#how-to-read-the-code-samples).

**What you'll build:** A working outbound HTTP call to an external API. You start with a one-liner and
finish with a production-ready service that has typed DTOs (small classes that hold exactly the fields you
send and receive, and convert themselves to and from JSON), input validation, and automated tests.

**Success looks like:** Your API call appears in the Kern app's **API Calls** tab with full request/response
logging, and your test class has 100% code coverage.

**When the built-in is enough:** for a single, simple callout with no retries, no logging, and no shared
shape, a plain `Http`/`HttpRequest` callout (or an External Service / Named Credential on its own) does the
job. Use this when you want retries, request/response logging, validation, and tests in a consistent
shape across many integrations.

**In one line:** `kern.UTIL_HttpClient.post('PaymentGateway', '/charges').body(request).withRetry(3).send();`
That single call comes with automatic retries for the failures that sending it again can safely fix, a circuit
breaker you add with `.withCircuitBreaker()` (after repeated failures the framework
stops calling a failing system for a cool-off, then resumes), and logging already built in.

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
    - [Check the Named Credential](#check-the-named-credential)
    - [GET Request](#get-request)
    - [POST Request](#post-request)
    - [Builder Features](#builder-features)
3. [Tier 2: Build Your Own (~15 minutes)](#tier-2-build-your-own-15-minutes)
    - [Step 1: Create the API Handler](#step-1-create-the-api-handler)
    - [Step 2: Register Metadata](#step-2-register-metadata)
        - [Step 2.1: Create the API credential](#step-21-create-the-api-credential)
        - [Step 2.2: Create the API setting](#step-22-create-the-api-setting)
    - [Step 3: Execute](#step-3-execute)
    - [Step 4: Write Tests](#step-4-write-tests)
    - [Step 5: Add Validation](#step-5-add-validation)
    - [Step 6: Understanding Mocks](#step-6-understanding-mocks)
4. [Tier 3: Production Patterns (~10 minutes)](#tier-3-production-patterns-10-minutes)
    - [From a Flow](#from-a-flow)
        - [Build a Screen Flow (step-by-step)](#build-a-screen-flow-step-by-step)
    - [From Apex (Queue-Based)](#from-apex-queue-based)
    - [Sensitive data is masked by default](#sensitive-data-is-masked-by-default)
    - [Clean up](#clean-up)
5. [Common Issues](#common-issues)
    - [Step 1: Create the API Handler](#step-1-create-the-api-handler-1)
    - [Step 2: Register Metadata](#step-2-register-metadata-1)
    - [Step 3: Execute](#step-3-execute-1)
    - [Step 5: Add Validation](#step-5-add-validation-1)
    - [Clean up](#clean-up-1)
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

**In Salesforce**, open Setup, then Named Credentials, and confirm you see it with endpoint
`https://jsonplaceholder.typicode.com` and **Callout Status** `Enabled`.

### GET Request

**In Salesforce**, open the Developer Console (the gear icon, then Developer Console), then Debug, then Open Execute
Anonymous Window, and run:

```apex
Map<String, Object> post = kern.UTIL_HttpClient.get('kern__API_ExampleRestApi', '/posts/1').asMap();
System.debug(JSON.serializePretty(post));
```

You should see the post in the log, like this (shortened here):

```json
{
  "userId" : 1,
  "id" : 1,
  "title" : "sunt aut facere repellat provident occaecati excepturi optio reprehenderit",
  "body" : "quia et suscipit\nsuscipit recusandae..."
}
```

### POST Request

**In Salesforce**, in the same Execute Anonymous window, run:

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

You should see these lines in the log (the body is shortened here):

```text
Status: 201
Body: {"id": 101}
```

> **Review your calls:** Open the **Kern** app (App Launcher > Kern) and click the **API Calls** tab to see
> every call logged with full request/response details, status, and timing.

### Builder Features

You configure each call with short chained method calls, then one final call (such as `.send()`) runs it
and returns the result. Here are the common options you can add to any call.

**In Salesforce**, in the Execute Anonymous window, try any of these:

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

Headers like `Accept` are yours to set freely. A credential is different: it belongs in the Named Credential the call already names, or, for an API that wants
its key in a header, in an External Credential.
[Where credentials belong](Web%20Services%20-%20Guide.md#util_httpclient-fluent-http-client) in the Web Services Guide explains why and how.

> **When to move to Tier 2:** Move on once you need typed DTOs (the small request/response classes),
> input validation, tests that run without real callouts and assert in one line, or retry and circuit
> breaker settings managed as configuration records rather than in code.

---

## Tier 2: Build Your Own (~15 minutes)

> **No local project?** You can create classes directly in the Developer Console (Gear Icon > Developer
> Console > File > New > Apex Class) and run tests from there too (Test > New Run). Paste the code, save,
> and skip the terminal commands.

A one-liner is great for trying things out, but a real integration needs structure: known request and
response shapes, validation, and tests. In this tier you build a reusable API handler class
(`API_GetPost`) that fetches a post from JSONPlaceholder by ID. It comes with typed DTOs (the request and
response classes), test coverage, and parameter validation.

### Step 1: Create the API Handler

The handler is one class that describes a single call: which verb it uses, which inputs it needs, and the shape of
the request and the response. You create an empty class with one command, paste the code into it, then send it to
your org.

**1. In the terminal**, from your project's top folder, create the empty class:

```shell
sf apex generate class --name API_GetPost --output-dir force-app/main/default/classes
```

You should see two files created in `force-app/main/default/classes`: `API_GetPost.cls` and its companion of the
same name ending in `.cls-meta.xml`.

The second file tells Salesforce which API version the class uses. You never edit it, but a deploy fails without it.

**2. In your editor**, open this file, delete what is there, paste the code below in, and save. Copy the code exactly
as it is: do not change the class name.

```text
force-app/main/default/classes/API_GetPost.cls
```

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
	@JsonAccess(serializable='always' deserializable='always')
	global class DTO_Request extends kern.DTO_JsonBase
	{
	}

	/** @description Response DTO matching the JSONPlaceholder post schema. */
	@JsonAccess(serializable='always' deserializable='always')
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

**3. In the terminal**, send the class to your org:

```shell
sf project deploy start -o YourOrgAlias -m "ApexClass:API_GetPost"
```

You should see `Status: Succeeded`, with `API_GetPost` listed as created.

Something went wrong? See [Common Issues, Step 1](#step-1-create-the-api-handler-1).

### Step 2: Register Metadata

Your handler class is written, but the framework still needs to know how to run it. You tell it with two
configuration records: an **API Credential** record (which Named Credential, that is, which connection, to
use) and an **API Setting** record (how to run your handler). You create each one in Setup, then pull it into your
project so it is under source control with your code.

#### Step 2.1: Create the API credential

The API Credential record tells the framework which Named Credential (which connection) to use for HTTP calls.

**1. In Salesforce**, open Setup, then Custom Metadata Types, then **API Credential**, then **Manage API
Credentials**, then **New**, and save a record with these values:

| Field               | API name                   | Value                      |
|---------------------|----------------------------|----------------------------|
| Label               | `MasterLabel`              | `Example REST API`         |
| API Credential Name | `DeveloperName`            | `API_ExampleRestApi`       |
| Named Credential    | `kern__NamedCredential__c` | `kern__API_ExampleRestApi` |

> **Why create this?** The package ships an `ApiCredential` record for the Example REST API, but it is
> protected (kept internal to the package), so your code cannot reference it. Your org needs its own
> `ApiCredential` record that points to the same Named Credential.

**2. In the terminal**, pull the record into your project:

```shell
sf project retrieve start -o YourOrgAlias -m "CustomMetadata:kern__ApiCredential.API_ExampleRestApi"
```

You should see one file created under `force-app/main/default/customMetadata`, named after the record.

Something went wrong? See [Common Issues, Step 2](#step-2-register-metadata-1).

#### Step 2.2: Create the API setting

The API Setting record configures how your handler runs: its class name, endpoint path, retry policy, and more.

**1. In Salesforce**, open Setup, then Custom Metadata Types, then **API Setting**, then **Manage API Settings**,
then **New**, and save a record with these values:

| Field                   | API name                         | Value                                                         |
|-------------------------|----------------------------------|---------------------------------------------------------------|
| Label                   | `MasterLabel`                    | `API Get Post`                                                |
| API Setting Name        | `DeveloperName`                  | `API_GetPost`                                                 |
| API Credential          | `kern__ApiCredential__c`         | `API_ExampleRestApi` (the list shows `Example REST API`)      |
| Circuit Breaker Enabled | `kern__CircuitBreakerEnabled__c` | checked                                                       |
| Class Name              | `kern__ClassName__c`             | `API_GetPost`                                                 |
| Direction               | `kern__Direction__c`             | `Outbound`                                                    |
| Endpoint Path           | `kern__EndpointPath__c`          | `/posts`                                                      |
| Is Active               | `kern__IsActive__c`              | checked                                                       |
| Log Issues              | `kern__LogIssues__c`             | checked                                                       |
| Max Retry Count         | `kern__MaxRetryCount__c`         | `3`                                                           |
| Retry Backoff (sec)     | `kern__RetryBackoffSeconds__c`   | `5`                                                           |

> **Class Name** (`kern__ClassName__c`) is the simple class name (`API_GetPost`), without a namespace prefix. The
> framework's type resolver (how it finds your classes) handles the namespace for you.
>
> **API Credential** (`kern__ApiCredential__c`) is a lookup (a metadata relationship) to `kern__ApiCredential__mdt`.
> Select the record you created in Step 2.1. The handler in Step 3 names the same Named Credential; the record
> is what the framework uses when a handler names none.

> **How the HTTP verb is set for outbound calls:** `getHttpMethod()` in your handler class decides the verb.
> The framework reads it inside `setHeaders()` and applies it to the request that goes over the wire. The
> default (when you do not override it) is `POST`, so override `getHttpMethod()` to use a different verb.

**2. In the terminal**, pull the record into your project:

```shell
sf project retrieve start -o YourOrgAlias -m "CustomMetadata:kern__ApiSetting.API_GetPost"
```

You should see one file created under `force-app/main/default/customMetadata`, named after the record.

Something went wrong? See [Common Issues, Step 2](#step-2-register-metadata-1).

### Step 3: Execute

Run the handler once and read what came back.

**In Salesforce**, open the Developer Console (the gear icon, then Developer Console), then Debug, then Open Execute
Anonymous Window, and run:

```apex
// The Named Credential's real name, which on the managed package carries the kern__ prefix.
// The API Setting record supplies it when a call names none; this call names it itself.
kern.API_Outbound handler = kern.UTIL_HttpClient.useHandler(API_GetPost.class)
	.credential('kern__API_ExampleRestApi')
	.withParameter('postId', '1')
	.invoke();

if (handler != null)
{
	System.debug('Success: ' + handler.result.isSuccess);
	System.debug('Response: ' + handler.result.responseBody);
}
```

You should see these lines in the log (the response is shortened here):

```text
Success: true
Response: {"userId": 1, "id": 1, "title": "sunt aut facere repellat provident...", "body": "quia et suscipit..."}
```

> **See it in the org:** Open **App Launcher > Kern > API Calls** tab and select the **All** list view.
> You'll see your call logged with the full request/response details, status, and timing. This visual
> confirmation is the real proof it worked.

Something went wrong? See [Common Issues, Step 3](#step-3-execute-1).

### Step 4: Write Tests

The test class checks both paths: a call with the post ID succeeds, and a call without it stops before anything is
sent. You create the empty class with one command, paste the code into it, send it to your org, then run it.

**1. In the terminal**, from your project's top folder, create the empty test class:

```shell
sf apex generate class --name API_GetPost_TEST --output-dir force-app/main/default/classes
```

You should see two files created in `force-app/main/default/classes`: `API_GetPost_TEST.cls` and its companion of
the same name ending in `.cls-meta.xml`.

**2. In your editor**, open this file, delete what is there, paste the code below in, and save:

```text
force-app/main/default/classes/API_GetPost_TEST.cls
```

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
@IsTest(isParallel=true)
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

**3. In the terminal**, send the test class to your org:

```shell
sf project deploy start -o YourOrgAlias -m "ApexClass:API_GetPost_TEST"
```

You should see `Status: Succeeded`, with `API_GetPost_TEST` listed as created.

**4. In the terminal**, run the test:

```shell
sf apex run test -o YourOrgAlias -t API_GetPost_TEST --code-coverage --synchronous --result-format human
```

You should see 2 tests passing: both tests show `Pass`, the summary line `Outcome` reads `Passed`, and the coverage
table lists `API_GetPost`, fully covered (it showed `100%` on our test org).

> **About the annotations:** `@IsTest(isParallel=true)` lets tests run in parallel, which makes the run
> faster. `SeeAllData` defaults to `false`, so we omit it. `@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')`
> turns off a code-scanner rule about `System.runAs()`. That is fine for a quick start, but in production
> tests consider adding `System.runAs()` to verify profile and permission set access.

Something went wrong? See [Common Issues](#common-issues).

### Step 5: Add Validation

Sometimes a request should be rejected before it ever leaves your org, for example when an input is the
wrong shape. You can add your own checks that run before the HTTP call.

**1. In your editor**, open `API_GetPost.cls` and add this method after `getRequiredInputs()`, inside the class:

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

**2. In your editor**, add a test for the abort path in `API_GetPost_TEST.cls`, inside the class:

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

**3. In the terminal**, send both classes to your org:

```shell
sf project deploy start -o YourOrgAlias -m "ApexClass:API_GetPost" -m "ApexClass:API_GetPost_TEST"
```

You should see `Status: Succeeded`, with `API_GetPost` and `API_GetPost_TEST` listed as changed.

**4. In the terminal**, run the tests again:

```shell
sf apex run test -o YourOrgAlias -t API_GetPost_TEST --code-coverage --synchronous --result-format human
```

You should see 3 tests passing: all three show `Pass`, the summary line `Outcome` reads `Passed`, and the coverage
table lists `API_GetPost`, still fully covered (`100%` on our test org).

**Try it out.** **In Salesforce**, in the Execute Anonymous window, run this to see validation in action:

```apex
// Invalid post ID — should abort with validation error
kern.API_Outbound handler = kern.UTIL_HttpClient.useHandler(API_GetPost.class)
	.credential('kern__API_ExampleRestApi')
	.withParameter('postId', 'ABC')
	.invoke();

if (handler != null)
{
	System.debug('Success: ' + handler.result.isSuccess);
	System.debug('Errors: ' + handler.result.errors);
}
```

You should see these lines in the log:

```text
Success: false
Errors: (Post ID must be a numeric value)
```

Check the **API Calls** tab. You'll see an entry with status **Aborted** and the validation error logged.

**In Salesforce**, run this one to see a valid ID go through:

```apex
// Valid post ID — should succeed
kern.API_Outbound handler = kern.UTIL_HttpClient.useHandler(API_GetPost.class)
	.credential('kern__API_ExampleRestApi')
	.withParameter('postId', '1')
	.invoke();

if (handler != null)
{
	System.debug('Success: ' + handler.result.isSuccess);
	System.debug('Response: ' + handler.result.responseBody);
}
```

Something went wrong? See [Common Issues, Step 5](#step-5-add-validation-1).

### Step 6: Understanding Mocks

Your tests already passed without calling the real API. That matters because tests must not depend on a
live external system. Here is why it works, and how to customise it.

**The simple way (`defaultMockBody`):**

The `defaultMockBody` you set in `configure()` is the stand-in response. When tests run, the framework
intercepts the HTTP callout and returns that JSON instead of calling JSONPlaceholder. There is no extra
setup and no `Test.setMock()` to wire up: the framework handles it.

**In your editor**, this is the line in `configure()` that does it:

```apex
// In configure() — this IS your test mock
defaultMockBody = '{"userId": 1, "id": 1, "title": "Mock Post Title", "body": "Mock post body"}';
```

**Custom mocks (`API_MockFactory`):**

Sometimes one test needs a different response, for example to check how your code handles an error or an
edge case. For that, use `API_MockFactory`.

**In your editor**, inside a test method:

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

**In your editor**, add this test to `API_GetPost_TEST.cls` to see error mocking in action:

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
and logs the result.

**In Salesforce**, to try it, run this in the Execute Anonymous window:

```apex
kern.DTO_NameValues parameters = new kern.DTO_NameValues();
parameters.add('postId', '1');

kern__ApiCall__c queueItem = new kern__ApiCall__c(
	kern__ServiceName__c = API_GetPost.class.getName(),
	kern__Direction__c = 'Outbound',
	kern__Status__c = 'Queued',
	kern__RequestParameters__c = parameters.serialize()
);

kern.DML_Builder.newTransaction().doInsert(queueItem).execute();
System.debug('Queue item created: ' + queueItem.Id);
```

> **Note:** `kern.TST_Factory.newOutboundApiCall()` is a **test-only** utility. In production code, create
> `kern__ApiCall__c` records directly as shown above.

**In Salesforce**, check the status after a few seconds using the built-in `SEL_ApiCall` selector:

```apex
List<kern__ApiCall__c> calls = new kern.SEL_ApiCall().findByServiceName('API_GetPost');

for(kern__ApiCall__c apiCall : calls)
{
	System.debug('Status: ' + apiCall.kern__Status__c);
}
```

> **Lifecycle:** `Queued` -> `Processing` -> `Completed` / `Failed` / `Aborted`, with `Retry` and `Retrying` in between
> when a retry is scheduled. A failure that sending the request again could fix is retried automatically, up to the
> `MaxRetryCount__c` setting; a `Failed` call is not retried. See
> [Failures and retries](Web%20Services%20-%20Guide.md#failures-and-retries).

### Sensitive data is masked by default

Logging every call is useful, but you do not want secrets sitting in those logs. `ApiCall__c` records store
the request body, response body, URL, and parameters captured from every outbound call, so before any of
that is saved, it passes through the data masking framework and sensitive values are redacted. Out of the
box, three rules fire:

- **`MaskSecretKeys`** redacts common secret JSON keys (`password`, `token`, `apiKey`, `authorization`,
  `bearer`, `client_secret`, `private_key`, `access_token`, `refresh_token`).
- **`MaskPaymentCard`** redacts 13–19 digit sequences that pass the Luhn (mod-10) checksum, covering all
  major card brands; the digits may be separated by spaces or hyphens. (This replaces the original
  `MaskCreditCard` rule, which still ships, switched off. If you switch it on, switch its four targets on
  with it.)
- **`MaskJwt`** redacts JSON Web Tokens (the signed access tokens many APIs pass around; each one starts
  with `eyJ` and has three dot-separated parts) as `[JWT_REDACTED]`.

So if your outbound request body contains a `password` or a card number, the saved `ApiCall__c.Request__c`
has them redacted. The actual HTTP request going over the wire is unchanged: only the stored copy is masked.
Fourteen more rules ship as inactive templates (SSN, IBAN, SWIFT/BIC, MBI, health keywords, email, US phone,
AWS access key, URL basic auth, authorization header, private IPv4, postal address, free text, and
international phone). To switch one on, set `kern__MaskingRule__mdt.IsActive__c = true` and add a
`kern__MaskingTarget__mdt` record that wires the rule to the field(s) that need it. If a sensitive value still
shows on a saved `kern__ApiCall__c` record, no active rule recognises it: switch on the rule that matches it and,
unless a shipped `kern__MaskingTarget__mdt` record already wires that rule to the field, add one that does (see the
Web Services Guide).

### Clean up

If you built this example only to try the framework, run these lines when you have finished the guide, to remove it
from your org. Delete it in two commands, in this order: the org refuses to delete the API credential while an API
setting still points at it.

**1. In the terminal**, delete the two classes and the API setting:

```shell
sf project delete source -o YourOrgAlias -m "ApexClass:API_GetPost_TEST" -m "ApexClass:API_GetPost" -m "CustomMetadata:kern__ApiSetting.API_GetPost" --no-prompt
```

You should see `Status: Succeeded`, then a `Deleted Source` table listing the two classes and the API setting.

**2. In the terminal**, delete the API credential:

```shell
sf project delete source -o YourOrgAlias -m "CustomMetadata:kern__ApiCredential.API_ExampleRestApi" --no-prompt
```

You should see `Status: Succeeded`, then a `Deleted Source` table listing the API credential.

The commands delete the files from your project too. Two things they leave behind: the calls you made stay on the
**API Calls** tab as a record of what ran, and if you built the `Get Post Demo` screen flow, deactivate it and
delete it in Setup, then Flows.

Something went wrong? See [Common Issues](#clean-up-1).

---

## Common Issues

Trouble with your computer rather than this guide (`sf` is not recognised, scripts are disabled, you are not logged
in, the wrong folder)? Those are answered once, in
[Set Up Your Computer](Set%20Up%20Your%20Computer.md#if-something-went-wrong).

### Step 1: Create the API Handler

#### The deploy says there is nothing to deploy

The deploy stops with `No source-backed components present in the package.` The command ran inside another project's
folder, so the CLI looked for the class there and found nothing. Open the terminal in your own project's top folder,
the one that holds `sfdx-project.json`, and run the command again.

#### The deploy fails with an Invalid type message naming API_Outbound

The org you deployed to does not have KernDX installed, so it cannot find the framework's base class. The message
names the class with the package namespace in front (`Invalid type: kern.API_Outbound`). Install KernDX in that org
first (see the [Installation guide](Installation.md)). If you installed KernDX under your own namespace or without
one, change the `kern.` prefix in the code as the namespace note at the top of this guide explains.

### Step 2: Register Metadata

#### The pull says `Nothing retrieved`

The pull finishes with the warning `Nothing retrieved` and a line saying the record `cannot be found`. The name in
the pull command does not match a record in your org: either the record was not saved in Step 2.1 or Step 2.2, or
its name differs. Check the **API Credential Name** or **API Setting Name** you saved matches the table exactly,
then run the pull again.

### Step 3: Execute

#### `Success: false` and `Response: null`

The call did not come back. To see why, add this line to the end of the block and run it again:
`System.debug('Errors: ' + handler.result.errors);`. The entries below cover what it can show.

If the errors line says `the named credential "API_ExampleRestApi" might not exist`, the call used the wrong
Named Credential name. On the managed package, use `kern__API_ExampleRestApi` (namespace-prefixed), as the
namespace note at the top of this guide explains.

#### `Type cannot be serialized`

A DTO class is missing `@JsonAccess`, so the framework, which runs in the `kern` namespace, is not allowed to turn it
into JSON. The call also shows on the **API Calls** tab with this error. Add
`@JsonAccess(serializable='always' deserializable='always')` above each DTO class, as the Step 1 code does, and send
the class to your org again.

#### `The required parameters ["postId"] were not provided or were blank.`

The call was made without the post ID, so the framework stopped it before sending anything (the **API Calls** tab
shows it as **Aborted**). Pass every name that `getRequiredInputs()` lists, here with `.withParameter('postId', '1')`.

#### `Type cannot be deserialized`

The same cause and fix as in the Inbound APIs guide: see its [Common Issues](Fast%20Start%20-%20Inbound%20APIs.md#type-cannot-be-deserialized).

#### `Stopwatch is not running.`

The same cause and fix as in the Inbound APIs guide: see its [Common Issues](Fast%20Start%20-%20Inbound%20APIs.md#stopwatch-is-not-running).

### Step 5: Add Validation

#### `Missing '<EOF>' at 'public'`

The deploy fails with this message because the new method was pasted after the class's last closing brace, outside
the class. Move it up so it sits inside the class, after `getRequiredInputs()`, and send the class again.

### Clean up

#### `Your attempt to delete Example REST API could not be completed`

The API credential was deleted while the API setting still pointed at it, and the org refuses that. Delete in two
commands, as the clean-up shows: first the classes and the API setting, then the API credential.

Still stuck? [Tell us](https://github.com/JVB-Consulting/kerndx/issues/new?template=bug_report.md&title=%5Bdocs%5D%20Outbound%20APIs) which step and what you saw.

## What You Now Know

After completing this guide, you understand the **three ways** to make outbound HTTP calls with KernDX:

| Approach                       | When to Use                              | What You Get                                                                  |
|--------------------------------|------------------------------------------|-------------------------------------------------------------------------------|
| **`UTIL_HttpClient`** (Tier 1) | Quick calls, prototyping, anonymous Apex | Short chained one-liners, with optional retry and circuit breaker             |
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
- [Retry & Circuit Breaker](Web%20Services%20-%20Guide.md#what-else-can-it-do)
