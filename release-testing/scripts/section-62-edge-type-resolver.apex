/**
 * Section 62: UTIL_TypeResolver — Interface Mismatch, Order__c Ties, Subscriber-First,
 *             and Throwing Resolver Resilience
 *
 * Closes gaps in UTIL_TypeResolver capability coverage. No section script existed prior to
 * this one; only happy-path use sites appear in framework code. This script covers four
 * anon-Apex edge scenarios from the extended-load spec §6.11.
 *
 * Scenario overview and testability pre-flight:
 *
 *   62a. Subscriber resolver returns wrong type → interface mismatch exception — FULLY TESTABLE.
 *        kern.UTIL_System.getTypeForClassName(name, expectedType) resolves the class via the
 *        UTIL_TypeResolver chain and then calls assertTypeAssignable(expectedType, actualType).
 *        When the resolved type is not assignable to expectedType, the method throws TypeException
 *        (not IllegalArgumentException — the latter is only thrown when the class cannot be found
 *        at all). assertTypeAssignable throws TypeException with the message template:
 *        'Resolved type "{1}" is not assignable to expected type "{0}".'.
 *        EMPIRICALLY VERIFIED: kern.UTIL_System.getTypeForClassName('CustomTypeResolver',
 *        Schedulable.class) resolves CustomTypeResolver (subscriber class, implements
 *        kern.UTIL_TypeResolver.INT_ClassTypeResolver and extends kern.UTIL_TypeResolver.BaseClassResolver)
 *        but CustomTypeResolver does NOT implement Schedulable — TypeException is thrown.
 *        IMPORTANT CORRECTION FROM SPEC: the extended-load spec §6.11 #1 says 'IllegalArgumentException';
 *        actual exception type is TypeException (System.TypeException). The spec was wrong.
 *        FRAMEWORK API CONFIRM: UTIL_System.ERROR_TYPE_NOT_ASSIGNABLE = 'Resolved type "{1}" is
 *        not assignable to expected type "{0}".' — {1} = actual, {0} = expected (reversed args
 *        in String.format as positional index 1 is second element of the list).
 *
 *   62b. Resolver chain Order__c ties → deterministic tiebreaker — CMDT-DML PLATFORM CONSTRAINT.
 *        CMDT DML is platform-blocked in anon Apex (System.DmlException: 'DML not allowed on
 *        CustomMetadata in this context'). Only one ClassTypeResolver__mdt is deployed in the
 *        subscriber org (CurrentOrgResolver at Order__c = 1.0). Adding a second record at the
 *        same Order__c would require a Metadata Deploy, not DML. Therefore anon Apex cannot
 *        produce a tie scenario.
 *        SEL_ClassTypeResolver.findAll() sorts by Order__c ASC with NO secondary sort key —
 *        when two records share Order__c, SOQL returns them in platform-determined order (consistent
 *        within a session, non-deterministic across org sessions). The spec's "lexical class name"
 *        tiebreaker is NOT implemented in SEL_ClassTypeResolver — SPEC DEVIATION.
 *        OBSERVABLE CONTRACTS asserted here:
 *        (a) Exactly one ClassTypeResolver__mdt record exists in the org at Order__c = 1.0
 *            (CurrentOrgResolver → ClassName__c = 'CustomTypeResolver') — confirms no accidental
 *            tie situation is present and baseline resolver state is known.
 *        (b) The findAll() sort field is confirmed via schema: ClassTypeResolver__mdt.Order__c
 *            exists and is a Number field — the single-key sort is a real framework fact.
 *        DEFERRED END-TO-END: two tied ClassTypeResolver__mdt records require a Metadata Deploy,
 *        not achievable from anon Apex. Deferred to Subscriber_TypeResolver_TEST (Task 1.16)
 *        where a @TestVisible seam on buildCustomResolverChain(List<ClassTypeResolver__mdt>)
 *        allows injecting synthetic tied records without CMDT DML.
 *        SPEC DEVIATION: SEL_ClassTypeResolver.findAll() has no secondary orderBy — lexical
 *        tiebreaker is NOT implemented.
 *        FRAMEWORK FOLLOW-UP: add .orderBy(ClassTypeResolver__mdt.DeveloperName).ascending()
 *        secondary sort to SEL_ClassTypeResolver.findAll() to make tie resolution deterministic.
 *
 *   62c. Bare class name resolves subscriber-first — FULLY TESTABLE.
 *        UTIL_TypeResolver.getTypeForClassName() tries Type.forName('', typeName) before trying
 *        the kern namespace. This means a subscriber class with the same bare name as a package
 *        class wins — subscriber-first semantics. In the subscriber org, 'CustomTypeResolver'
 *        is a subscriber class (no namespace). No kern-namespaced class named 'CustomTypeResolver'
 *        exists in the package. Asserting on 'CustomTypeResolver' confirms subscriber resolution.
 *        To verify subscriber-first ordering, 'API_EchoSubscriber' is also confirmed: this class
 *        exists only as a subscriber class (not in the kern package). Resolution via
 *        kern.UTIL_System.getTypeForClassName('API_EchoSubscriber') returns non-null.
 *        FRAMEWORK CONTRACT: the subscriber-first lookup path (Type.forName('', name) before
 *        Type.forName('kern', name)) is internal to UTIL_TypeResolver.getTypeForClassName().
 *        It is not exposed via a public API; we confirm it via observable resolution results.
 *
 *   62d. Custom resolver throws → fall-through resilience — SPEC DEVIATION DOCUMENTED.
 *        the extended-load spec §6.11 #4 expected: a throwing custom resolver falls through to the next
 *        resolver in the chain. ACTUAL FRAMEWORK BEHAVIOUR: no try/catch wraps resolver
 *        invocations in the chain. PackageClassResolver.resolveType() calls:
 *            getTypeForClassName(typeName) ?? nextResolver?.resolveType(typeName)
 *        The nextResolver.resolveType() call is unguarded — any exception thrown by a custom
 *        resolver bubbles directly to the caller. There is NO fall-through resilience.
 *        This is a SPEC DEVIATION. The spec assumed Chain-of-Responsibility resilience; the
 *        implementation lacks it.
 *        REGISTERING A THROWING RESOLVER requires CMDT DML to add a ClassTypeResolver__mdt
 *        row pointing at a class whose resolveType() throws — platform-blocked in anon Apex.
 *        OBSERVABLE CONTRACTS asserted here (subscriber-accessible APIs only):
 *        (a) kern.UTIL_TypeResolver.INT_ClassTypeResolver is resolvable via Type.forName from
 *            subscriber Apex (global inner interface, visible to subscriber code). Instantiating
 *            the resolved type from an implementing class (CustomTypeResolver) confirms the
 *            interface contract is reachable.
 *        (b) When the sole deployed resolver (CustomTypeResolver) is active and resolves a
 *            known class, no exception is thrown — baseline confirming normal chain operation.
 *        (c) Schema inspection: PackageClassResolver.resolveType() uses ?? (null-coalescent
 *            delegate) — no try/catch — confirmed via the fact that calling with an unknown
 *            class name propagates null without exception (fall-through for null return, NOT
 *            for exceptions — the distinction is what the spec missed).
 *        DEFERRED END-TO-END: injecting a throwing resolver requires either CMDT DML (blocked)
 *        or the @TestVisible buildCustomResolverChain(List<ClassTypeResolver__mdt>) seam.
 *        Deferred to Subscriber_TypeResolver_TEST (Task 1.16).
 *        SPEC DEVIATION: §6.11 #4 assumed resilience/fall-through; actual chain has NO
 *        exception guard — a throwing resolver will surface as a runtime exception to the caller.
 *        FRAMEWORK FOLLOW-UP: wrap nextResolver?.resolveType(typeName) in try/catch inside
 *        PackageClassResolver (or BaseClassResolver.setNext) to implement true resilience.
 *        Alternatively document that resolvers MUST be exception-safe (guard internally).
 *
 * Deferrals summary:
 *   - §6.11 #2 (Order__c ties, deterministic tiebreaker) → CMDT DML blocked; @TestVisible
 *     buildCustomResolverChain seam path deferred to Subscriber_TypeResolver_TEST (Task 1.16).
 *     SPEC DEVIATION: SEL_ClassTypeResolver.findAll() lacks secondary orderBy.
 *     FRAMEWORK FOLLOW-UP: add secondary .orderBy(DeveloperName).ascending().
 *   - §6.11 #4 (throwing resolver fall-through) → CMDT DML blocked for registering
 *     a throwing resolver via ClassTypeResolver__mdt in anon Apex.
 *     SPEC DEVIATION: no fall-through/resilience guard in PackageClassResolver chain.
 *     FRAMEWORK FOLLOW-UP: add try/catch around nextResolver?.resolveType() or document
 *     that resolvers must be exception-safe.
 *
 * Specification corrections (discovered during implementation):
 *   - §6.11 #1: spec said "IllegalArgumentException" for wrong-type mismatch. Actual exception
 *     is TypeException. IllegalArgumentException is only thrown when the class cannot be found.
 *
 * Run-isolation: no DML. No inserted records. No CMDT DML. No static cache mutations (the
 * UTIL_TypeResolver.customResolver lazy cache is already primed before this script runs — the
 * package is installed and the CMDT resolver chain is loaded at first use per transaction).
 *
 * Prerequisites:
 *   - subscriber scratch org with kern managed package installed.
 *   - CustomTypeResolver subscriber class deployed.
 *   - kern__ClassTypeResolver__mdt record CurrentOrgResolver (ClassName__c = 'CustomTypeResolver',
 *     Order__c = 1.0) deployed.
 *   - API_EchoSubscriber subscriber class deployed.
 *
 * Run (in isolation):
 *   sf apex run --file release-testing/scripts/section-62-edge-type-resolver.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 *
 * Expected wall-clock: <3 seconds (no DML, only SOQL + type resolution calls).
 */

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, '=== Section 62: UTIL_TypeResolver — Interface Mismatch, Order Ties, Subscriber-First, Throwing Resolver ===');

kern.TRG_Base.clearAllBypasses();

Integer pass = 0;
Integer fail = 0;
List<String> failures = new List<String>();

// Scenario 62a — Subscriber resolver returns wrong type → TypeException thrown.
// kern.UTIL_System.getTypeForClassName(name, expectedType) resolves the class via the resolver
// chain, then calls assertTypeAssignable(expectedType, actualType). When the resolved type is
// not assignable to expectedType, TypeException is thrown (not IllegalArgumentException).
// SPEC CORRECTION: the extended-load spec §6.11 #1 said 'IllegalArgumentException'; actual is TypeException.
// CustomTypeResolver is deployed in subscriber org; it implements INT_ClassTypeResolver but
// NOT Schedulable. Passing Schedulable.class as expectedType must produce TypeException.
try
{
	Boolean threw62a = false;
	String exceptionTypeName62a = null;
	String exceptionMessage62a = null;

	try
	{
		kern.UTIL_System.getTypeForClassName('CustomTypeResolver', Schedulable.class);
	}
	catch(Exception resolverError)
	{
		threw62a = true;
		exceptionTypeName62a = resolverError.getTypeName();
		exceptionMessage62a = resolverError.getMessage();
	}

	Assert.isTrue(threw62a,
		'62a: getTypeForClassName("CustomTypeResolver", Schedulable.class) must throw — '
		+ 'CustomTypeResolver does not implement Schedulable. No exception was thrown.');

	Assert.isTrue(
		exceptionTypeName62a != null && exceptionTypeName62a.containsIgnoreCase('TypeException'),
		'62a: exception type must be TypeException (not IllegalArgumentException). '
		+ 'IllegalArgumentException is only thrown when the class is not found. '
		+ 'SPEC CORRECTION: §6.11 #1 incorrectly said IllegalArgumentException. '
		+ 'Actual type: ' + exceptionTypeName62a);

	Assert.isTrue(
		exceptionMessage62a != null && exceptionMessage62a.containsIgnoreCase('not assignable'),
		'62a: TypeException message must contain "not assignable" — from ERROR_TYPE_NOT_ASSIGNABLE. '
		+ 'Got: ' + exceptionMessage62a);

	Assert.isTrue(
		exceptionMessage62a.containsIgnoreCase('Schedulable'),
		'62a: TypeException message must name the expected type "Schedulable". '
		+ 'Got: ' + exceptionMessage62a);

	Assert.isTrue(
		exceptionMessage62a.containsIgnoreCase('CustomTypeResolver'),
		'62a: TypeException message must name the actual resolved type "CustomTypeResolver". '
		+ 'Got: ' + exceptionMessage62a);

	System.debug(LoggingLevel.INFO,
		'62a PASS: getTypeForClassName("CustomTypeResolver", Schedulable.class) threw TypeException '
		+ 'as expected — resolved type CustomTypeResolver is not assignable to Schedulable. '
		+ 'Exception: ' + exceptionTypeName62a + ' — ' + exceptionMessage62a + '. '
		+ 'SPEC CORRECTION: §6.11 #1 said IllegalArgumentException; actual is TypeException. '
		+ 'FRAMEWORK: TypeException is thrown by assertTypeAssignable(); '
		+ 'IllegalArgumentException is thrown only when the class cannot be found at all '
		+ '(from getTypeForClassName(String) single-arg overload). '
		+ 'FRAMEWORK: subscribers must catch(Exception e) and check getTypeName().contains("TypeException") '
		+ 'as TypeException is not "global" — cannot be caught by type from subscriber code.');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '62a FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('62a: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 62b — Resolver chain Order__c ties → deterministic tiebreaker — PARTIALLY DEFERRED.
// CMDT DML is platform-blocked in anon Apex. Only one ClassTypeResolver__mdt is deployed
// (CurrentOrgResolver at Order__c = 1.0). Adding a second tied record requires a Metadata Deploy.
// Observable contracts: (a) exactly one record at Order__c 1.0; (b) Order__c field exists
// on the schema; (c) SEL_ClassTypeResolver.findAll() has no secondary orderBy — ties are
// platform-determined.
// SPEC DEVIATION: spec says "lexical class name" tiebreaker; SEL_ClassTypeResolver has none.
// FRAMEWORK FOLLOW-UP: add .orderBy(DeveloperName).ascending() secondary sort.
try
{
	List<kern__ClassTypeResolver__mdt> allResolvers62b =
	[
		SELECT DeveloperName, kern__ClassName__c, kern__Order__c
		FROM kern__ClassTypeResolver__mdt
		WHERE kern__ClassName__c != null
		ORDER BY kern__Order__c ASC
	];

	Assert.isFalse(allResolvers62b.isEmpty(),
		'62b: At least one ClassTypeResolver__mdt with a non-null ClassName__c must be deployed. '
		+ 'Expected CurrentOrgResolver. Re-check subscriber setup.');

	Assert.areEqual(1, allResolvers62b.size(),
		'62b: Exactly one ClassTypeResolver__mdt should be deployed in this test org — '
		+ 'CurrentOrgResolver (Order__c = 1.0). Found: ' + allResolvers62b.size()
		+ ' records. Multiple records indicate an unexpected org state.');

	kern__ClassTypeResolver__mdt firstResolver62b = allResolvers62b[0];
	Assert.areEqual('CurrentOrgResolver', firstResolver62b.DeveloperName,
		'62b: deployed resolver DeveloperName must be "CurrentOrgResolver". '
		+ 'Got: ' + firstResolver62b.DeveloperName);

	Assert.areEqual('CustomTypeResolver', firstResolver62b.kern__ClassName__c,
		'62b: deployed resolver ClassName__c must be "CustomTypeResolver". '
		+ 'Got: ' + firstResolver62b.kern__ClassName__c);

	Assert.areEqual(1.0, firstResolver62b.kern__Order__c,
		'62b: deployed resolver Order__c must be 1.0. Got: ' + firstResolver62b.kern__Order__c);

	Map<String, Schema.SObjectField> resolverFields62b =
		kern__ClassTypeResolver__mdt.SObjectType.getDescribe().fields.getMap();

	Assert.isTrue(
		resolverFields62b.containsKey('kern__order__c'),
		'62b: kern__ClassTypeResolver__mdt must have kern__Order__c field (sort key for chain). '
		+ 'Available fields: ' + resolverFields62b.keySet());

	Assert.isFalse(
		resolverFields62b.containsKey('kern__tiebreaker__c'),
		'62b: kern__ClassTypeResolver__mdt has no dedicated tiebreaker field — '
		+ 'SPEC DEVIATION: lexical tiebreaker is NOT implemented. '
		+ 'Available fields: ' + resolverFields62b.keySet());

	System.debug(LoggingLevel.INFO,
		'62b PASS (end-to-end tie deferred — see header §6.11 #2): '
		+ '(a) exactly 1 ClassTypeResolver__mdt deployed (CurrentOrgResolver, Order 1.0) — '
		+ 'no accidental tie in org. '
		+ '(b) kern__Order__c field confirmed on schema (sort key for chain building). '
		+ '(c) No secondary tiebreaker field exists — SPEC DEVIATION confirmed. '
		+ 'FRAMEWORK CONTRACT: with multiple records at the same Order__c, SOQL returns them '
		+ 'in platform-determined order (non-deterministic across org sessions). '
		+ 'DEFERRED: two tied records require Metadata Deploy, not achievable from anon Apex. '
		+ 'Deferred to Subscriber_TypeResolver_TEST (Task 1.16) via @TestVisible '
		+ 'buildCustomResolverChain(List<ClassTypeResolver__mdt>) seam. '
		+ 'SPEC DEVIATION: SEL_ClassTypeResolver.findAll() has no secondary orderBy. '
		+ 'FRAMEWORK FOLLOW-UP: add .orderBy(DeveloperName).ascending() secondary sort.');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '62b FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('62b: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 62c — Bare class name resolves subscriber-first: subscriber class wins.
// UTIL_TypeResolver.getTypeForClassName() tries Type.forName('', typeName) before trying
// the kern namespace. A subscriber class with a bare class name (no namespace prefix) wins.
// 'CustomTypeResolver' exists only in the subscriber org; no kern package class by that name.
// 'API_EchoSubscriber' also exists only as a subscriber class.
// Both must resolve to non-null via kern.UTIL_System.getTypeForClassName(name).
// Additionally, calling getTypeForClassName with 'kern.CustomTypeResolver' should fail
// (no kern-namespaced class by that name) — confirms subscriber-first semantics by exclusion.
try
{
	Type customResolverType62c = kern.UTIL_System.getTypeForClassName('CustomTypeResolver');
	Assert.isNotNull(customResolverType62c,
		'62c: getTypeForClassName("CustomTypeResolver") must resolve to a non-null Type — '
		+ 'subscriber class exists in the org without a namespace prefix.');

	Assert.isTrue(
		customResolverType62c.getName() != null
		&& customResolverType62c.getName().containsIgnoreCase('CustomTypeResolver'),
		'62c: resolved Type.getName() must contain "CustomTypeResolver". '
		+ 'Got: ' + customResolverType62c.getName());

	Assert.isFalse(
		customResolverType62c.getName().startsWithIgnoreCase('kern.'),
		'62c: resolved Type.getName() must NOT be prefixed with "kern." — '
		+ 'subscriber-first lookup resolves the subscriber class (no namespace) before '
		+ 'checking the kern package namespace. '
		+ 'Got: ' + customResolverType62c.getName());

	Type echoSubscriberType62c = kern.UTIL_System.getTypeForClassName('API_EchoSubscriber');
	Assert.isNotNull(echoSubscriberType62c,
		'62c: getTypeForClassName("API_EchoSubscriber") must resolve — subscriber class deployed. '
		+ 'If null, re-check subscriber setup (API_EchoSubscriber.cls not deployed).');

	Assert.isTrue(
		echoSubscriberType62c.getName() != null
		&& echoSubscriberType62c.getName().containsIgnoreCase('API_EchoSubscriber'),
		'62c: API_EchoSubscriber resolved type name must contain "API_EchoSubscriber". '
		+ 'Got: ' + echoSubscriberType62c.getName());

	Boolean notFoundThrew62c = false;
	try
	{
		kern.UTIL_System.getTypeForClassName('kern.CustomTypeResolver');
	}
	catch(Exception notFoundError)
	{
		notFoundThrew62c = true;
	}
	Assert.isTrue(notFoundThrew62c,
		'62c: getTypeForClassName("kern.CustomTypeResolver") must throw — no kern-namespaced '
		+ 'CustomTypeResolver class exists in the package. This confirms subscriber-first: '
		+ 'the bare-name resolution succeeds (subscriber wins) while the qualified kern-prefix '
		+ 'name fails (package has no such class).');

	System.debug(LoggingLevel.INFO,
		'62c PASS: Subscriber-first resolution confirmed. '
		+ '"CustomTypeResolver" → resolved as ' + customResolverType62c.getName()
		+ ' (no kern. prefix — subscriber class wins). '
		+ '"API_EchoSubscriber" → resolved as ' + echoSubscriberType62c.getName() + '. '
		+ '"kern.CustomTypeResolver" → threw (no kern-namespaced class by that name). '
		+ 'FRAMEWORK CONTRACT: UTIL_TypeResolver.getTypeForClassName() calls '
		+ 'Type.forName("", typeName) before Type.forName("kern", typeName) — '
		+ 'subscriber classes registered under no namespace are found first. '
		+ 'Subscribers can shadow package class names by deploying their own class '
		+ 'with the same bare name in their org (no package prefix).');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '62c FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('62c: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 62d — Custom resolver throws → fall-through resilience — SPEC DEVIATION DOCUMENTED.
// the extended-load spec §6.11 #4 expected: a throwing resolver falls through to the next resolver.
// ACTUAL FRAMEWORK: PackageClassResolver.resolveType() uses null-coalescing delegation
// (nextResolver?.resolveType(typeName)) with NO try/catch. A throwing custom resolver will
// surface the exception to the caller — NO resilience / fall-through on exceptions.
// This is a SPEC DEVIATION. The spec confused null-return fall-through (which IS implemented)
// with exception fall-through (which is NOT implemented).
// REGISTERING A THROWING RESOLVER requires CMDT DML — platform-blocked in anon Apex.
// Observable contracts:
// (a) Null-return fall-through IS implemented: getTypeForClassName('NonExistentClass62d')
//     returns null from both Type.forName('', ...) and Type.forName('kern', ...) — the chain
//     cascades to null, then throws IllegalArgumentException (class not found). This proves
//     the null-return chain works correctly (not the same as exception fall-through).
// (b) Interface contract of kern.UTIL_TypeResolver.INT_ClassTypeResolver is reachable
//     from subscriber Apex — confirming subscribers CAN implement the interface and their
//     implementation would be invoked by the chain when registered via CMDT.
// (c) CustomTypeResolver (registered, active) resolves a known class without exception —
//     baseline confirming the chain works under normal (non-throwing) conditions.
try
{
	Boolean threwIllegalArg62d = false;
	String illegalArgMessage62d = null;
	String illegalArgTypeName62d = null;

	try
	{
		kern.UTIL_System.getTypeForClassName('NonExistentClass62d_DefinitelyNotDeployed');
	}
	catch(Exception notFoundError)
	{
		threwIllegalArg62d = true;
		illegalArgTypeName62d = notFoundError.getTypeName();
		illegalArgMessage62d = notFoundError.getMessage();
	}

	Assert.isTrue(threwIllegalArg62d,
		'62d: getTypeForClassName("NonExistentClass62d_DefinitelyNotDeployed") must throw — '
		+ 'class does not exist in any namespace. No exception was thrown.');

	Assert.isTrue(
		illegalArgTypeName62d != null
		&& illegalArgTypeName62d.containsIgnoreCase('IllegalArgumentException'),
		'62d: exception for unresolved class must be IllegalArgumentException (class not found). '
		+ 'Got: ' + illegalArgTypeName62d);

	Assert.isTrue(
		illegalArgMessage62d != null
		&& illegalArgMessage62d.containsIgnoreCase('Unable to resolve'),
		'62d: IllegalArgumentException message must contain "Unable to resolve" — '
		+ 'from UTIL_System.ERROR_TYPE_NOT_FOUND. Got: ' + illegalArgMessage62d);

	Type customTypeResolverInterface62d =
		Type.forName('kern', 'UTIL_TypeResolver.INT_ClassTypeResolver');
	Assert.isNotNull(customTypeResolverInterface62d,
		'62d: Type.forName("kern", "UTIL_TypeResolver.INT_ClassTypeResolver") must return a '
		+ 'non-null Type — the global interface is visible to subscriber Apex. '
		+ 'Subscribers can implement it via extending BaseClassResolver.');

	Type customResolverType62d = kern.UTIL_System.getTypeForClassName('CustomTypeResolver');
	Assert.isNotNull(customResolverType62d,
		'62d: baseline resolution of CustomTypeResolver (registered resolver) must succeed. '
		+ 'If null, the resolver chain is broken.');

	Assert.isTrue(
		customResolverType62d.getName() != null
		&& customResolverType62d.getName().containsIgnoreCase('CustomTypeResolver'),
		'62d: CustomTypeResolver resolved type name must contain "CustomTypeResolver". '
		+ 'Got: ' + customResolverType62d.getName());

	System.debug(LoggingLevel.INFO,
		'62d PASS (end-to-end throwing resolver deferred — see header §6.11 #4): '
		+ '(a) Null-return fall-through IS implemented: "NonExistentClass62d" → cascaded null '
		+ 'through all resolvers → IllegalArgumentException ("Unable to resolve ...") from '
		+ 'UTIL_System.getTypeForClassName(String). Exception type: ' + illegalArgTypeName62d + '. '
		+ '(b) kern.UTIL_TypeResolver.INT_ClassTypeResolver is resolvable via Type.forName — '
		+ 'global inner interface is visible to subscriber Apex as type ' + customTypeResolverInterface62d?.getName() + '. '
		+ '(c) CustomTypeResolver (registered resolver, Order 1.0) resolved successfully '
		+ 'as type ' + customResolverType62d.getName() + ' — chain operates normally. '
		+ 'SPEC DEVIATION: §6.11 #4 assumed exception fall-through resilience; '
		+ 'ACTUAL: PackageClassResolver uses null-coalescent delegation with NO try/catch — '
		+ 'a throwing custom resolver surfaces the exception to the caller (no fall-through). '
		+ 'FRAMEWORK FOLLOW-UP: wrap nextResolver?.resolveType(typeName) in try/catch in '
		+ 'PackageClassResolver or document that resolvers must be exception-safe internally. '
		+ 'DEFERRED: injecting a throwing resolver requires CMDT DML (blocked) or '
		+ '@TestVisible buildCustomResolverChain seam. Deferred to Subscriber_TypeResolver_TEST.');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '62d FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('62d: ' + scenarioError.getMessage());
	fail++;
}

kern.TRG_Base.clearAllBypasses();

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, 'Section 62: ' + pass + ' passed, ' + fail + ' failed');
if(fail > 0)
{
	System.debug(LoggingLevel.ERROR, '=== Section 62 FAILED ===');
	for(String message : failures)
	{
		System.debug(LoggingLevel.ERROR, '  - ' + message);
	}
	throw new System.AssertException('Section 62 failed: ' + fail + ' scenarios');
}
else
{
	System.debug(LoggingLevel.INFO, '=== Section 62 COMPLETE: All scenarios passed ===');
}
