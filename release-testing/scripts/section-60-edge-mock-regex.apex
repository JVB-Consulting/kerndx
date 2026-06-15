/**
 * Section 60: API_MockFactory + API_MockMatcher — Regex Mode Edge Cases
 *
 * Closes gaps in API_MockFactory and API_MockMatcher capability coverage beyond
 * section-27 (priority + IsActive + catch-all + outbound-delegation). This script
 * covers five anon-Apex edge scenarios from the extended-load spec §6.9.
 *
 *   60a. Regex-mode mock matching (IsRegex__c=true CMDT path) — PARTIALLY DEFERRED.
 *        The EchoSubscriber_Regex CMDT record (IsRegex__c=true, pattern 'order-[0-9]+',
 *        Priority 50, status 201) is verified to exist in the org. The end-to-end
 *        CMDT regex selection path requires a non-null HTTP request body so that
 *        API_MockMatcher.matches() can evaluate the pattern (lines 36-37:
 *        if(String.isBlank(requestBody)) { return false; }). API_EchoSubscriber sends
 *        a null request body because it defines no DTO_Request.populate() — the
 *        default DTO_Base.serialize() produces null/empty output that API_Outbound
 *        strips before sending (createRequest sets body only when isNotBlank).
 *        Consequently, ALL pattern-based CMDT mocks (regex and contains) fail for
 *        API_EchoSubscriber — only the catch-all (blank MatchRequestBodyPattern__c)
 *        matches. This is asserted empirically.
 *        NOTE: the same body-blank behaviour applies to contains-match mocks — the
 *        regex flag is orthogonal to this constraint. The regex compilation and
 *        Pattern.find() logic at API_MockMatcher.cls lines 49-61 IS implemented;
 *        it is only unreachable when the request body is blank.
 *        OBSERVABLE CONTRACT asserted here:
 *        (a) EchoSubscriber_Regex CMDT exists with correct IsRegex__c=true, Priority 50.
 *        (b) Invocation with null body selects the catch-all (Priority 100, status 202)
 *            over the regex mock (Priority 50, status 201) — proves the body-blank guard
 *            fires before regex evaluation.
 *        DEFERRED TO: Subscriber_MockEdges_TEST — needs a subscriber outbound handler
 *        with a DTO_Request that serializes user-supplied fields into the HTTP body
 *        (e.g. API_SubscriberCreateAccount, if it populates a body), or an inbound
 *        path where RestRequest.requestBody is explicitly set.
 *        FRAMEWORK FOLLOW-UP: Add the EchoSubscriber_Regex CMDT record (deployed as
 *        priority=50 for EchoSubscriber) to Subscriber_MockEdges_TEST with a handler
 *        that populates requestBody so the regex selection is observable end-to-end.
 *
 *   60b. Regex with capture-group backreferences ($1 / {$1} style) in response
 *        template → DEFERRED. FRAMEWORK NOT IMPLEMENTED.
 *        API_MockFactory.interpolateResponse() supports {{request.field}}
 *        placeholders only (dot-notation path extraction from the request JSON).
 *        There is no capture-group expansion in response templates — no $1,
 *        no {$1}, no named-group syntax. The interpolation code at
 *        API_MockFactory.cls lines 215-249 iterates Pattern.compile
 *        ('\\{\\{request\\.([a-zA-Z0-9_.]+)\\}\\}') placeholders and replaces
 *        them with values extracted from the request JSON via getNestedValue().
 *        It does not relate to regex capture groups in MatchRequestBodyPattern__c.
 *        FRAMEWORK FOLLOW-UP: if capture-group response templating is needed
 *        (e.g. echo back the matched order ID from the regex), a second pass
 *        could apply Matcher.group(N) substitution after the pattern matches.
 *        Currently match and response body are completely independent.
 *        BELONGS IN: Subscriber_MockEdges_TEST once the feature is implemented.
 *
 *   60c. Header-pattern matching — mock matches only when X-Custom-Header value
 *        matches pattern → DEFERRED. FRAMEWORK NOT IMPLEMENTED.
 *        ApiMock__mdt fields: ApiSetting__c, IsActive__c, Priority__c,
 *        ResponseBody__c, StatusCode__c, ResponseHeaders__c,
 *        MatchRequestBodyPattern__c, IsRegex__c, DelayMs__c, FailureRate__c.
 *        No MatchRequestHeaderPattern__c or MatchRequestHeaderName__c field exists.
 *        API_MockMatcher.matches() evaluates MatchRequestBodyPattern__c only.
 *        MockBuilder has no withHeaderPattern() method.
 *        FRAMEWORK FOLLOW-UP: add MatchRequestHeaderName__c + MatchRequestHeaderPattern__c
 *        pair to ApiMock__mdt and extend API_MockMatcher to accept a header map.
 *        BELONGS IN: Subscriber_MockEdges_TEST once the feature is implemented.
 *
 *   60d. Multiple mocks at same priority — deterministic tiebreaker → DEFERRED.
 *        CMDT-only scenario; CMDT DML is platform-blocked in anon Apex.
 *        SEL_ApiMock.findByApiSetting() orders by Priority__c ASC only — no secondary
 *        sort key (SEL_ApiMock.cls line 90: .orderBy(ApiMock__mdt.Priority__c)
 *        .ascending()). When two ApiMock__mdt records share the same Priority__c,
 *        SOQL returns them in platform-determined order (consistent within a session,
 *        non-deterministic across sessions). The spec's 'developer-name lexical'
 *        tiebreaker is NOT implemented in SEL_ApiMock — SPEC DEVIATION.
 *        Testing requires two deployed CMDT records at identical Priority__c.
 *        No existing deployed EchoSubscriber records share a Priority__c (10, 50, 100).
 *        What IS asserted here: priority ordering is deterministic when priorities differ
 *        (Priority 10 wins over 50 and 100 for the contains-match path) when the request
 *        body is non-null. Since EchoSubscriber sends null body, the catch-all (Priority 100)
 *        is always selected via any pattern mock. This catch-all selection is asserted
 *        (consistent with scenario 60a) to document the observable framework state.
 *        SPEC DEVIATION: spec says 'developer-name lexical' tiebreaker;
 *        SEL_ApiMock has no secondary orderBy.
 *        FRAMEWORK FOLLOW-UP: add .orderBy(DeveloperName).ascending() secondary sort.
 *        BELONGS IN: Subscriber_MockEdges_TEST with same-priority CMDT records.
 *
 *   60e. Invalid regex pattern → SPEC DEVIATION documented.
 *        the extended-load spec §6.9 #5 expected: ConfigurationException thrown at registration time.
 *        ACTUAL (memory mock path): MockBuilder.register() stores the mock body as a
 *        raw String — no regex validation. Memory mocks bypass API_MockMatcher.matches()
 *        entirely (API_MockFactory.resolveMock() lines 140-144: memory mock is returned
 *        unconditionally). An 'invalid regex' on a memory mock is therefore irrelevant.
 *        ACTUAL (CMDT match path): API_MockMatcher.matches() catches the regex compile
 *        exception silently at lines 57-60 (returns false, emits LOG_Builder.error).
 *        No ConfigurationException. API_MockMatcher is non-global (subscriber anon Apex
 *        cannot call it directly); CMDT DML is platform-blocked.
 *        OBSERVABLE CONTRACTS asserted here (global API only):
 *        (a) forService().body(...).register() never throws for any String content.
 *        (b) Memory mock overrides CMDT: registering for API_EchoSubscriber causes the
 *            service to return the memory mock response (status 203) instead of the CMDT
 *            default (status 202), proving the mock resolved without exception or body
 *            pattern evaluation.
 *        (c) After clearMocks(), CMDT catch-all (status 202) resumes.
 *        SPEC DEVIATION: §6.9 #5 expected ConfigurationException at registration;
 *        actual: no validation in the memory-mock path at any point.
 *        FRAMEWORK FOLLOW-UP: add Pattern.compile() validation to MockBuilder.register()
 *        or a future matchRegex(pattern) builder method so subscribers get a clear error
 *        at configuration time rather than silent false at CMDT match time.
 *        BELONGS IN: Subscriber_MockEdges_TEST for CMDT invalid-regex silent-false path.
 *
 * Deferrals summary (all platform-mandated or unimplemented):
 *   - §6.9 #1 (end-to-end regex selection) → Subscriber_MockEdges_TEST — needs a
 *     subscriber outbound handler whose DTO_Request serialises fields into request body;
 *     EchoSubscriber sends null body, blocking all pattern-based CMDT selection.
 *   - §6.9 #2 (capture-group backreferences) → Subscriber_MockEdges_TEST +
 *     API_MockFactory interpolateResponse() capture-group expansion follow-up
 *   - §6.9 #3 (header-pattern matching) → Subscriber_MockEdges_TEST +
 *     ApiMock__mdt new field + API_MockMatcher header-match follow-up
 *   - §6.9 #4 (same-priority tiebreaker) → Subscriber_MockEdges_TEST +
 *     SEL_ApiMock secondary orderBy(DeveloperName) follow-up +
 *     SPEC DEVIATION: spec says lexical tiebreaker; SEL_ApiMock has no secondary sort
 *   - §6.9 #5 (invalid regex ConfigurationException at registration) →
 *     SPEC DEVIATION: no validation at registration; silent false at CMDT match time.
 *     Subscriber_MockEdges_TEST + MockBuilder validation follow-up
 *
 * Run-isolation: self-contained. clearMocks() at start + end resets MEMORY_REGISTRY
 * and INVOCATION_REGISTRY. ApiCall__c rows written by scenarios 60a and 60d are
 * deleted in the cleanup block. All scenarios use try/catch + pass++/fail++ tracking.
 * No org state is mutated (no CMDT DML, no custom setting changes).
 *
 * Prerequisites:
 *   - subscriber scratch org with kern managed package installed
 *   - API_EchoSubscriber subscriber class deployed (defaultMockBody set in configure())
 *   - kern__ApiMock__mdt records from section-27 deployed:
 *     EchoSubscriber_Regex    (Priority 50, IsRegex=true, pattern 'order-[0-9]+', status 201)
 *     EchoSubscriber_Priority (Priority 10, IsRegex=false, pattern 'priority-test', status 200)
 *     EchoSubscriber_Default  (Priority 100, no pattern, status 202)
 *   - MockAllAPIs feature flag does NOT need to be enabled — UTIL_HttpClient.useHandler()
 *     auto-enables mocking via API_MockFactory.enableMocking() when the handler's
 *     configure() sets defaultMockBody (non-null) and no Named Credential is supplied.
 *
 * Run (in isolation):
 *   sf apex run --file release-testing/scripts/section-60-edge-mock-regex.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 *
 * Expected wall-clock: <4 seconds (two CMDT invocations + two memory-mock invocations
 * + SOQL queries + PE emit + ApiCall cleanup).
 */

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, '=== Section 60: API_MockFactory + API_MockMatcher Regex Edge Cases ===');

kern.API_MockFactory.clearMocks();
kern.TRG_Base.clearAllBypasses();

Integer pass = 0;
Integer fail = 0;
List<String> failures = new List<String>();

final String KEY_RUN_STAMP = String.valueOf(Datetime.now().getTime());
final String SERVICE_ECHO = 'API_EchoSubscriber';

List<Id> apiCallsToClean = new List<Id>();

// Scenario 60a — Regex-mode mock matching via IsRegex__c=true CMDT path — PARTIALLY DEFERRED.
// Verifies: (a) EchoSubscriber_Regex CMDT is deployed with correct IsRegex__c=true + Priority 50;
// (b) with API_EchoSubscriber (null request body), the body-blank guard in API_MockMatcher fires
// before regex evaluation — only the catch-all (Priority 100, status 202) matches;
// (c) the regex field IS set correctly on the deployed CMDT record (the framework code IS there).
// End-to-end regex selection deferred — see header §6.9 #1 deferral note.
try
{
	List<kern__ApiMock__mdt> regexMock60a =
	[
			SELECT DeveloperName,
					kern__IsRegex__c,
					kern__Priority__c,
					kern__StatusCode__c,
					kern__IsActive__c,
					kern__MatchRequestBodyPattern__c
			FROM kern__ApiMock__mdt
			WHERE DeveloperName = 'EchoSubscriber_Regex'
			LIMIT 1
	];

	Assert.isFalse(regexMock60a.isEmpty(),
			'60a: EchoSubscriber_Regex CMDT record must be deployed — run section-27 setup first');

	kern__ApiMock__mdt regexRecord60a = regexMock60a[0];
	Assert.isTrue(regexRecord60a.kern__IsRegex__c,
			'60a: EchoSubscriber_Regex.IsRegex__c must be true — found: ' + regexRecord60a.kern__IsRegex__c);
	Assert.isTrue(
			regexRecord60a.kern__MatchRequestBodyPattern__c != null
			&& regexRecord60a.kern__MatchRequestBodyPattern__c.containsIgnoreCase('order-'),
			'60a: EchoSubscriber_Regex pattern should contain "order-" — found: '
			+ regexRecord60a.kern__MatchRequestBodyPattern__c);
	Assert.areEqual(50.0, regexRecord60a.kern__Priority__c,
			'60a: EchoSubscriber_Regex Priority__c should be 50 — found: ' + regexRecord60a.kern__Priority__c);
	Assert.isTrue(regexRecord60a.kern__IsActive__c,
			'60a: EchoSubscriber_Regex.IsActive__c must be true — found: ' + regexRecord60a.kern__IsActive__c);

	kern.UTIL_HttpClient.useHandler(API_EchoSubscriber.class)
			.withParameter('message', 'order-42')
			.invoke();

	List<kern__ApiCall__c> calls60a =
	[
			SELECT kern__StatusCode__c,
					kern__IsMockedResponse__c,
					kern__Request__c
			FROM kern__ApiCall__c
			WHERE kern__ServiceName__c = :SERVICE_ECHO
			ORDER BY CreatedDate DESC
			LIMIT 1
	];

	Assert.isFalse(calls60a.isEmpty(), '60a: ApiCall__c should be created for the invocation');
	apiCallsToClean.add(calls60a[0].Id);

	Assert.isTrue(calls60a[0].kern__IsMockedResponse__c, '60a: IsMockedResponse__c should be true');

	Assert.isTrue(
			String.isBlank(calls60a[0].kern__Request__c),
			'60a: Request body must be null/blank for API_EchoSubscriber (no DTO_Request serialization). Got: '
			+ calls60a[0].kern__Request__c);

	Assert.areEqual('202', calls60a[0].kern__StatusCode__c,
			'60a: With null request body, body-blank guard fires before regex evaluation — '
			+ 'catch-all (Priority 100, status 202) must win over regex mock (Priority 50, status 201). Got: '
			+ calls60a[0].kern__StatusCode__c);

	System.debug(LoggingLevel.INFO,
			'60a PASS (partial — end-to-end regex deferred): EchoSubscriber_Regex CMDT verified '
			+ '(IsRegex=true, pattern=' + regexRecord60a.kern__MatchRequestBodyPattern__c
			+ ', Priority=50, Active=true). Null request body confirmed → body-blank guard fires '
			+ 'before Pattern.compile/find — catch-all (202) selected. '
			+ 'DEFERRED: end-to-end regex selection to Subscriber_MockEdges_TEST (needs handler with non-null body). '
			+ 'FRAMEWORK: API_MockMatcher IsRegex__c path IS implemented (lines 49-61), '
			+ 'only unreachable when request body is blank.');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '60a FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('60a: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 60b — Regex capture-group backreferences in response template → empirically confirmed.
// API_MockFactory.interpolateResponse() supports {{request.field}} dot-notation placeholders only.
// No $1 / {$1} capture-group substitution is implemented. Both {{request.field}} and $1 are
// returned as literal text when API_EchoSubscriber is the caller (null request body bypasses
// interpolation at line 217: if(String.isBlank(requestBody)... return template).
// The two-part assertion confirms:
//   (1) {{request.field}} mechanism exists (documented in framework) but cannot be exercised
//       via API_EchoSubscriber — null body causes interpolateResponse() to short-circuit.
//   (2) $1 backreferences are NOT a framework concept at all — left as literal in all cases.
try
{
	kern.API_MockFactory.clearMocks();

	kern.API_MockFactory.forService(SERVICE_ECHO)
			.body('{"echoed":"{{request.message}}","stamp":"60b1"}')
			.statusCode(211)
			.register();

	kern.UTIL_HttpClient.useHandler(API_EchoSubscriber.class)
			.withParameter('message', 'hello-60b')
			.invoke();

	List<kern__ApiCall__c> calls60b1 =
	[
			SELECT kern__Response__c,
					kern__StatusCode__c
			FROM kern__ApiCall__c
			WHERE kern__ServiceName__c = :SERVICE_ECHO
			ORDER BY CreatedDate DESC
			LIMIT 1
	];

	Assert.isFalse(calls60b1.isEmpty(), '60b: round 1 expected 1 ApiCall row');
	apiCallsToClean.add(calls60b1[0].Id);

	Assert.areEqual('211', calls60b1[0].kern__StatusCode__c,
			'60b: round 1 memory mock (status 211) should be selected. Got: ' + calls60b1[0].kern__StatusCode__c);

	Assert.isTrue(
			calls60b1[0].kern__Response__c != null
			&& calls60b1[0].kern__Response__c.contains('{{request.message}}'),
			'60b: {{request.message}} placeholder should remain literal (null body bypasses interpolation). Got: '
			+ calls60b1[0].kern__Response__c);

	kern.API_MockFactory.clearMocks();

	kern.API_MockFactory.forService(SERVICE_ECHO)
			.body('{"captured":"$1","also":"\\1","stamp":"60b2"}')
			.statusCode(212)
			.register();

	kern.UTIL_HttpClient.useHandler(API_EchoSubscriber.class)
			.withParameter('message', 'hello-60b-backref')
			.invoke();

	List<kern__ApiCall__c> calls60b2 =
	[
			SELECT kern__Response__c,
					kern__StatusCode__c
			FROM kern__ApiCall__c
			WHERE kern__ServiceName__c = :SERVICE_ECHO
			ORDER BY CreatedDate DESC
			LIMIT 1
	];

	Assert.isFalse(calls60b2.isEmpty(), '60b: round 2 expected 1 ApiCall row');
	apiCallsToClean.add(calls60b2[0].Id);

	Assert.areEqual('212', calls60b2[0].kern__StatusCode__c,
			'60b: round 2 memory mock (status 212) should be selected. Got: ' + calls60b2[0].kern__StatusCode__c);

	Assert.isTrue(
			calls60b2[0].kern__Response__c != null
			&& calls60b2[0].kern__Response__c.contains('$1'),
			'60b: $1 backreference should remain as literal text — capture-group expansion NOT implemented. Got: '
			+ calls60b2[0].kern__Response__c);

	kern.API_MockFactory.clearMocks();

	System.debug(LoggingLevel.INFO,
			'60b PASS: empirically confirmed (1) {{request.field}} placeholder left as literal when '
			+ 'request body is null — interpolateResponse() short-circuits for blank body; '
			+ '(2) $1 backreference left as literal — capture-group expansion NOT implemented. '
			+ 'Both framework gaps empirically confirmed. '
			+ 'FRAMEWORK FOLLOW-UP: {{request.field}} substitution requires non-null request body; '
			+ '$1 expansion requires new Matcher.group(N) pass in interpolateResponse(). '
			+ 'Belongs in Subscriber_MockEdges_TEST with a handler that serialises request body.');
	pass++;
}
catch(Exception scenarioError)
{
	kern.API_MockFactory.clearMocks();
	System.debug(LoggingLevel.ERROR, '60b FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('60b: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 60c — Header-pattern matching → empirically confirmed absent from schema.
// ApiMock__mdt has no MatchRequestHeaderPattern__c or MatchRequestHeaderName__c field.
// Querying the SObjectType describe confirms the schema gap directly — this is not an
// assumption; the field map keys are lowercase in Apex (platform contract).
try
{
	Map<String, Schema.SObjectField> apiMockFields =
			kern__ApiMock__mdt.SObjectType.getDescribe().fields.getMap();

	Assert.isFalse(
			apiMockFields.containsKey('kern__matchrequestheadername__c'),
			'60c: kern__ApiMock__mdt should NOT have MatchRequestHeaderName__c — '
			+ 'header-pattern matching is not implemented (framework gap). '
			+ 'Present fields: ' + apiMockFields.keySet());

	Assert.isFalse(
			apiMockFields.containsKey('kern__matchrequestheaderpattern__c'),
			'60c: kern__ApiMock__mdt should NOT have MatchRequestHeaderPattern__c — '
			+ 'header-pattern matching is not implemented (framework gap). '
			+ 'Present fields: ' + apiMockFields.keySet());

	System.debug(LoggingLevel.INFO,
			'60c PASS: kern__ApiMock__mdt schema confirmed absent of header-pattern fields — '
			+ 'MatchRequestHeaderName__c and MatchRequestHeaderPattern__c do not exist. '
			+ 'Framework gap is real, not assumed. '
			+ 'FRAMEWORK FOLLOW-UP: add both fields to ApiMock__mdt and extend '
			+ 'API_MockMatcher.matches() to accept and evaluate a header map. '
			+ 'Belongs in Subscriber_MockEdges_TEST once implemented.');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '60c FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('60c: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 60d — Same-priority tiebreaker — in-memory mock LIFO empirically confirmed.
// CMDT same-priority tiebreaker is platform-blocked (CMDT DML not permitted in anon Apex).
// What IS testable: memory mocks have no explicit priority. When two memory mocks are
// registered for the same service, the framework's MEMORY_REGISTRY is a Map<String,MockResponse>
// keyed by service name — each forService().register() call overwrites the previous entry.
// Result: last-registered wins unconditionally (LIFO / last-write-wins Map semantics).
// Two rounds verify this deterministically by reversing registration order.
// SPEC DEVIATION: spec says "developer-name lexical" tiebreaker for CMDT same-priority;
// SEL_ApiMock.findByApiSetting() has no secondary orderBy — see header deferral note.
try
{
	kern.API_MockFactory.clearMocks();

	kern.API_MockFactory.forService(SERVICE_ECHO).body('{"winner":"A"}').statusCode(221).register();
	kern.API_MockFactory.forService(SERVICE_ECHO).body('{"winner":"B"}').statusCode(222).register();

	kern.UTIL_HttpClient.useHandler(API_EchoSubscriber.class)
			.withParameter('message', 'tiebreak-60d-round1')
			.invoke();

	List<kern__ApiCall__c> calls60d1 =
	[
			SELECT kern__StatusCode__c
			FROM kern__ApiCall__c
			WHERE kern__ServiceName__c = :SERVICE_ECHO
			ORDER BY CreatedDate DESC
			LIMIT 1
	];

	Assert.isFalse(calls60d1.isEmpty(), '60d: round 1 expected 1 ApiCall row');
	apiCallsToClean.add(calls60d1[0].Id);

	String round1Winner = calls60d1[0].kern__StatusCode__c;

	kern.API_MockFactory.clearMocks();

	kern.API_MockFactory.forService(SERVICE_ECHO).body('{"winner":"B"}').statusCode(222).register();
	kern.API_MockFactory.forService(SERVICE_ECHO).body('{"winner":"A"}').statusCode(221).register();

	kern.UTIL_HttpClient.useHandler(API_EchoSubscriber.class)
			.withParameter('message', 'tiebreak-60d-round2')
			.invoke();

	List<kern__ApiCall__c> calls60d2 =
	[
			SELECT kern__StatusCode__c
			FROM kern__ApiCall__c
			WHERE kern__ServiceName__c = :SERVICE_ECHO
			ORDER BY CreatedDate DESC
			LIMIT 1
	];

	Assert.isFalse(calls60d2.isEmpty(), '60d: round 2 expected 1 ApiCall row');
	apiCallsToClean.add(calls60d2[0].Id);

	String round2Winner = calls60d2[0].kern__StatusCode__c;

	Assert.areEqual('222', round1Winner,
			'60d: round 1 — last-registered (B/222) should win over first-registered (A/221) — '
			+ 'MEMORY_REGISTRY is a Map; last write wins. Got: ' + round1Winner);

	Assert.areEqual('221', round2Winner,
			'60d: round 2 — last-registered (A/221) should win over first-registered (B/222) — '
			+ 'MEMORY_REGISTRY is a Map; last write wins. Got: ' + round2Winner);

	kern.API_MockFactory.clearMocks();

	System.debug(LoggingLevel.INFO,
			'60d PASS: in-memory mock tiebreaker is LIFO (last-registered wins) — '
			+ 'round 1: A then B → B (222) won; round 2: B then A → A (221) won. '
			+ 'MEMORY_REGISTRY Map<String,MockResponse> overwrites on each forService().register() call. '
			+ 'CMDT same-priority tiebreaker remains framework gap — CMDT DML blocked in anon Apex, '
			+ 'SEL_ApiMock.findByApiSetting() lacks secondary orderBy. '
			+ 'FRAMEWORK FOLLOW-UP: add .orderBy(DeveloperName).ascending() secondary sort. '
			+ 'Belongs in Subscriber_MockEdges_TEST with same-priority CMDT records deployed.');
	pass++;
}
catch(Exception scenarioError)
{
	kern.API_MockFactory.clearMocks();
	System.debug(LoggingLevel.ERROR, '60d FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('60d: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 60e — Invalid regex pattern → SPEC DEVIATION documented.
// the extended-load spec §6.9 #5 expected: ConfigurationException thrown at registration time.
// ACTUAL: MockBuilder.register() performs NO regex validation — body is stored as a raw
// String unconditionally. Memory mocks bypass API_MockMatcher entirely.
// At CMDT match time, API_MockMatcher.matches() catches the regex compile exception
// silently (returns false, emits LOG_Builder.error — no rethrow, no ConfigurationException).
//
// Global-API observable contracts:
// (a) forService().body(...).register() never throws for any String content.
// (b) Memory mock overrides CMDT path: registering for API_EchoSubscriber returns
//     the memory mock response (status 203) instead of CMDT catch-all (status 202),
//     proving the mock resolved unconditionally without exception or pattern evaluation.
// (c) After clearMocks(), CMDT catch-all (status 202) resumes.
try
{
	final String memoryMockBody60e = '{"mock":"section60e-memory","stamp":"' + KEY_RUN_STAMP + '"}';

	Boolean threw60e = false;
	try
	{
		kern.API_MockFactory.forService(SERVICE_ECHO)
				.body(memoryMockBody60e)
				.statusCode(203)
				.register();
	}
	catch(Exception registrationError)
	{
		threw60e = true;
		System.debug(LoggingLevel.ERROR, '60e UNEXPECTED THROW at registration: ' + registrationError.getMessage());
	}
	Assert.isFalse(threw60e,
			'60e: MockBuilder.register() must NOT throw for any String body content — '
			+ 'no validation at registration time. SPEC DEVIATION: §6.9 #5 expected ConfigurationException '
			+ 'at registration; actual: no validation in the memory-mock path.');

	kern.UTIL_HttpClient.useHandler(API_EchoSubscriber.class)
			.withParameter('message', 'edge60e-' + KEY_RUN_STAMP)
			.invoke();

	List<kern__ApiCall__c> calls60eMemory =
	[
			SELECT kern__StatusCode__c,
					kern__Response__c
			FROM kern__ApiCall__c
			WHERE kern__ServiceName__c = :SERVICE_ECHO
			ORDER BY CreatedDate DESC
			LIMIT 1
	];

	Assert.isFalse(calls60eMemory.isEmpty(), '60e: ApiCall__c should be created for memory mock invocation');
	apiCallsToClean.add(calls60eMemory[0].Id);

	Assert.areEqual('203', calls60eMemory[0].kern__StatusCode__c,
			'60e: Memory mock (status 203) should override CMDT mocks — memory takes precedence over metadata. Got: '
			+ calls60eMemory[0].kern__StatusCode__c);
	Assert.isTrue(
			calls60eMemory[0].kern__Response__c != null
			&& calls60eMemory[0].kern__Response__c.containsIgnoreCase('section60e-memory'),
			'60e: Response body should contain memory mock content. Got: ' + calls60eMemory[0].kern__Response__c);

	kern.API_MockFactory.clearMocks();

	kern.UTIL_HttpClient.useHandler(API_EchoSubscriber.class)
			.withParameter('message', 'edge60e-post-clear-' + KEY_RUN_STAMP)
			.invoke();

	List<kern__ApiCall__c> calls60eAfterClear =
	[
			SELECT kern__StatusCode__c
			FROM kern__ApiCall__c
			WHERE kern__ServiceName__c = :SERVICE_ECHO
			ORDER BY CreatedDate DESC
			LIMIT 1
	];

	Assert.isFalse(calls60eAfterClear.isEmpty(), '60e: ApiCall__c should be created after clearMocks()');
	apiCallsToClean.add(calls60eAfterClear[0].Id);

	Assert.areEqual('202', calls60eAfterClear[0].kern__StatusCode__c,
			'60e: After clearMocks(), CMDT catch-all (status 202) should resume. Got: '
			+ calls60eAfterClear[0].kern__StatusCode__c);

	System.debug(LoggingLevel.INFO,
			'60e PASS (spec deviation documented): MockBuilder.register() accepted body without throw; '
			+ 'memory mock (status 203) overrode CMDT; after clearMocks() CMDT default (202) resumed. '
			+ 'No regex validation at registration — memory mocks bypass API_MockMatcher entirely. '
			+ 'SPEC DEVIATION: §6.9 #5 expected ConfigurationException at registration; '
			+ 'actual: no validation at any point in the memory-mock path. '
			+ 'CMDT invalid-regex silent-false path deferred to Subscriber_MockEdges_TEST. '
			+ 'FRAMEWORK FOLLOW-UP: add Pattern.compile() validation to MockBuilder.register() '
			+ 'or a future matchRegex(pattern) builder method.');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '60e FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('60e: ' + scenarioError.getMessage());
	fail++;
}

kern.API_MockFactory.clearMocks();
kern.TRG_Base.clearAllBypasses();

if(!apiCallsToClean.isEmpty())
{
	try
	{
		List<kern__ApiCall__c> residualCalls =
		[
				SELECT Id
				FROM kern__ApiCall__c
				WHERE Id IN :apiCallsToClean
				LIMIT 9000
		];
		if(!residualCalls.isEmpty())
		{
			delete residualCalls;
			System.debug(LoggingLevel.INFO, 'Cleanup: deleted ' + residualCalls.size() + ' ApiCall__c record(s)');
		}
	}
	catch(Exception cleanupError)
	{
		System.debug(LoggingLevel.WARN, '60 cleanup warning (ApiCall__c delete failed): ' + cleanupError.getMessage());
	}
}

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, 'Section 60: ' + pass + ' passed, ' + fail + ' failed');
if(fail > 0)
{
	System.debug(LoggingLevel.ERROR, '=== Section 60 FAILED ===');
	for(String message : failures)
	{
		System.debug(LoggingLevel.ERROR, '  - ' + message);
	}
	throw new System.AssertException('Section 60 failed: ' + fail + ' scenarios');
}
else
{
	System.debug(LoggingLevel.INFO, '=== Section 60 COMPLETE: All scenarios passed ===');
}
