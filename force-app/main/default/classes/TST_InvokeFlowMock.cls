// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Test mock harness for `TRG_InvokeFlow`-dispatched flows.
 *
 * Lets test authors register canned flow responses that `TRG_InvokeFlow.invokeSingle`
 * short-circuits against, bypassing the platform `Flow.Interview` API entirely. Mirrors
 * the fluent shape of `API_MockFactory` so the patterns transfer one-to-one.
 *
 * Subscriber-facing global surface (locked at v1.0):
 * - `forFlow(String)` — entry point returning a `MockBuilder`
 * - `MockBuilder.succeed() / .fail(String) / .withOutputRecord(SObject) / .withOutputRecords(List<SObject>) / .throwOnStart(Exception) / .register()`
 * - `clear()`, `assertInvoked(name, count)`, `assertNotInvoked(name)`, `wasInvoked(name)`
 * - `getLastInputRecord(name)`, `getLastInputPriorRecord(name)` — verify the flow saw upstream Apex mutations
 *
 * Framework-internal surface (used by `TRG_InvokeFlow`):
 * - `isMocked(name)`, `getMockResult(name)`, `recordInvocation(name, record, priorRecord)`
 *
 * @see TRG_InvokeFlow
 * @see TST_InvokeFlowMock_TEST
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date April 2026, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * TST_InvokeFlowMock.forFlow('Foobar_SetDefaults')
 *     .succeed()
 *     .withOutputRecord((Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
 *         .withOverride(Foobar__c.TextArea__c, 'Mock-set').withoutInsertion().build())
 *     .register();
 * Assert.isTrue(TST_InvokeFlowMock.wasInvoked('Foobar_SetDefaults'), 'Flow should be invoked');
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class TST_InvokeFlowMock
{
	/**
	 * @description Error message thrown when a mock for the same flow name is registered twice.
	 */
	private static final String ERR_DOUBLE_REGISTER = 'A mock for flow \'\'{0}\'\' is already registered. Call TST_InvokeFlowMock.clear() before re-registering.';

	/**
	 * @description Error message thrown when forFlow is called with a blank flow name.
	 */
	private static final String ERR_BLANK_FLOW_NAME = 'Flow name must not be blank.';

	/**
	 * @description Registry mapping normalized flow names to registered mock results.
	 */
	private static final Map<String, MockResult> MOCK_REGISTRY = new Map<String, MockResult>();

	/**
	 * @description Registry capturing each invocation per normalized flow name.
	 *
	 * Each entry is one `MockInvocation` per `TRG_InvokeFlow` short-circuit, in dispatch
	 * order. Lets `wasInvoked`, `assertInvoked`, `getLastInputRecord`, and
	 * `getLastInputPriorRecord` answer "was the flow invoked, and what did it see?"
	 * without inspecting the trigger record's final state.
	 */
	private static final Map<String, List<MockInvocation>> INVOCATION_HISTORY = new Map<String, List<MockInvocation>>();

	/**
	 * @description Creates a fluent builder for registering a mock flow response.
	 *
	 * @param flowName The flow API name (matches `TriggerAction__mdt.FlowName__c`)
	 *
	 * @return A new MockBuilder for chaining
	 *
	 * @throws UTIL_Exceptions.ConfigurationException When flowName is blank
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * TST_InvokeFlowMock.forFlow('Foobar_SetDefaults').succeed().register();
	 * ```
	 */
	global static MockBuilder forFlow(String flowName)
	{
		if(String.isBlank(flowName))
		{
			throw new UTIL_Exceptions.ConfigurationException(ERR_BLANK_FLOW_NAME);
		}
		return new MockBuilder(flowName);
	}

	/**
	 * @description Clears all registered mocks and invocation counts.
	 *
	 * Salesforce resets static state between tests, but `clear()` is exposed for
	 * scenarios where multiple register/invoke cycles run inside a single test method.
	 *
	 * @since 1.0
	 */
	global static void clear()
	{
		MOCK_REGISTRY.clear();
		INVOCATION_HISTORY.clear();
	}

	/**
	 * @description Asserts that a mocked flow was invoked an exact number of times.
	 *
	 * @param flowName The flow API name to verify
	 * @param expectedCount The expected number of invocations
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * TST_InvokeFlowMock.assertInvoked('Foobar_SetDefaults', 1);
	 * ```
	 */
	global static void assertInvoked(String flowName, Integer expectedCount)
	{
		Integer actualCount = invocationCountFor(flowName);
		Assert.areEqual
				(
						expectedCount,
						actualCount,
						'Flow \'' + flowName + '\' invocation count mismatch'
				);
	}

	/**
	 * @description Asserts that a mocked flow was never invoked.
	 *
	 * @param flowName The flow API name to verify
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * TST_InvokeFlowMock.assertNotInvoked('Foobar_SetDefaults');
	 * ```
	 */
	global static void assertNotInvoked(String flowName)
	{
		Integer actualCount = invocationCountFor(flowName);
		Assert.areEqual(0, actualCount, 'Flow \'' + flowName + '\' should not have been invoked');
	}

	/**
	 * @description Returns whether a mocked flow was invoked at least once. Use this for
	 * conditional test branching where the assertion shape varies on whether the flow ran
	 * (e.g. "only validate flow output write-back if the flow was reached"). For pass/fail
	 * count checks, prefer `assertInvoked(name, count)` or `assertNotInvoked(name)`.
	 *
	 * @param flowName The flow API name to check
	 *
	 * @return True if the flow was invoked at least once
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * if(TST_InvokeFlowMock.wasInvoked('Foobar_SetDefaults'))
	 * {
	 *     Foobar__c result = (Foobar__c)new SEL_Foobar().findById(record.Id);
	 *     Assert.areEqual('From flow', result.TextArea__c, 'Flow output should land');
	 * }
	 * ```
	 */
	global static Boolean wasInvoked(String flowName)
	{
		return invocationCountFor(flowName) > 0;
	}

	/**
	 * @description Returns the `record` SObject the mocked flow received on its most recent
	 * invocation, or null when the flow has not been invoked.
	 *
	 * Mirrors `API_MockFactory.lastRequestContains` — lets subscribers verify the flow saw
	 * the input they expected (typically: an upstream Apex action's mutation) without
	 * inspecting the trigger record's final state. The returned SObject is the in-memory
	 * reference passed into the flow input map; mutating it after retrieval is undefined.
	 *
	 * @param flowName The flow API name to check
	 *
	 * @return The `record` SObject from the last invocation, or null if never invoked
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Foobar__c observed = (Foobar__c)TST_InvokeFlowMock.getLastInputRecord('Foobar_SetDefaults');
	 * Assert.areEqual('upstream-set', observed.TextArea__c, 'Flow should see upstream Apex mutation');
	 * ```
	 */
	global static SObject getLastInputRecord(String flowName)
	{
		MockInvocation last = lastInvocation(flowName);
		return last == null ? null : last.record;
	}

	/**
	 * @description Returns the `recordPrior` SObject the mocked flow received on its most
	 * recent invocation. Null when the flow has not been invoked or when the context did
	 * not supply a prior record (insert / before-delete / after-undelete).
	 *
	 * Pairs with `getLastInputRecord` for update-context tests asserting the flow received
	 * both the new and prior record state.
	 *
	 * @param flowName The flow API name to check
	 *
	 * @return The `recordPrior` SObject from the last invocation, or null when no prior record
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Foobar__c oldValues = (Foobar__c)TST_InvokeFlowMock.getLastInputPriorRecord('Foobar_OnUpdate');
	 * Assert.areEqual('Old TextArea', oldValues.TextArea__c, 'Flow should see prior TextArea');
	 * ```
	 */
	global static SObject getLastInputPriorRecord(String flowName)
	{
		MockInvocation last = lastInvocation(flowName);
		return last == null ? null : last.priorRecord;
	}

	/**
	 * @description Returns the `header` Change Event input variable the mocked flow
	 * received on its most recent invocation. Null when the flow has not been invoked
	 * or when the dispatch was not a Change Event context (standard / custom-object
	 * triggers do not inject a header).
	 *
	 * Returned as `Object` (rather than `DTO_ChangeEventHeader`) to keep this mock's
	 * compile-time surface decoupled from the CDC header type — callers cast at the
	 * call site:
	 *
	 * ```apex
	 * DTO_ChangeEventHeader header =
	 *     (DTO_ChangeEventHeader)TST_InvokeFlowMock.getLastInputHeader('Foobar_OnChange');
	 * ```
	 *
	 * @param flowName The flow API name to check
	 *
	 * @return The `header` input variable from the last invocation, or null when the flow has not been invoked or the context did not carry a header
	 *
	 * @since 1.1
	 */
	global static Object getLastInputHeader(String flowName)
	{
		MockInvocation last = lastInvocation(flowName);
		return last == null ? null : last.header;
	}

	/**
	 * @description Checks whether a mock is registered for the given flow.
	 *
	 * Used by `TRG_InvokeFlow.invokeSingle` to short-circuit before constructing
	 * a platform `Flow.Interview` instance.
	 *
	 * @param flowName The flow API name to check
	 *
	 * @return True if a mock is registered
	 */
	public static Boolean isMocked(String flowName)
	{
		return MOCK_REGISTRY.containsKey(normalizeKey(flowName));
	}

	/**
	 * @description Retrieves the registered mock result for a flow.
	 *
	 * Used by `TRG_InvokeFlow.invokeSingle` after `isMocked` returns true.
	 *
	 * @param flowName The flow API name
	 *
	 * @return The registered MockResult, or null if no mock exists
	 */
	public static MockResult getMockResult(String flowName)
	{
		return MOCK_REGISTRY.get(normalizeKey(flowName));
	}

	/**
	 * @description Records that a mocked flow was invoked, capturing the input variables
	 * the flow received so subscriber tests can verify them via `getLastInputRecord` /
	 * `getLastInputPriorRecord`. Delegates to the 4-arg overload with a null `header`
	 * — used by non-CDC dispatches (standard/custom-object trigger contexts).
	 *
	 * @param flowName The flow API name that was invoked
	 * @param record The `record` input variable the flow received
	 * @param priorRecord The `recordPrior` input variable the flow received, or null when none
	 */
	public static void recordInvocation(String flowName, SObject record, SObject priorRecord)
	{
		recordInvocation(flowName, record, priorRecord, null);
	}

	/**
	 * @description Records that a mocked flow was invoked, capturing the input variables
	 * the flow received — including the optional Change Event header. Used by
	 * `TRG_InvokeFlow.invokeSingle` to track CDC dispatches that inject a typed `header`
	 * variable into the flow input map. Returns the captured header via
	 * `getLastInputHeader(flowName)` so subscriber tests can verify the flow received the
	 * correct change-event metadata.
	 *
	 * The supplied SObjects + header are stored by reference; the registry holds the
	 * same instances the trigger framework passed to the flow input map.
	 *
	 * @param flowName The flow API name that was invoked
	 * @param record The `record` input variable the flow received
	 * @param priorRecord The `recordPrior` input variable the flow received, or null when none
	 * @param header The `header` Change Event input variable (a `DTO_ChangeEventHeader`) the flow received, or null for non-CDC dispatches
	 *
	 * @since 1.1
	 */
	public static void recordInvocation(String flowName, SObject record, SObject priorRecord, Object header)
	{
		String key = normalizeKey(flowName);
		List<MockInvocation> history = INVOCATION_HISTORY.get(key);
		if(history == null)
		{
			history = new List<MockInvocation>();
			INVOCATION_HISTORY.put(key, history);
		}
		history.add(new MockInvocation(record, priorRecord, header));
	}

	/**
	 * @description Looks up the invocation count for a flow name.
	 *
	 * @param flowName The flow API name
	 *
	 * @return The number of times the flow was invoked (0 if never)
	 */
	private static Integer invocationCountFor(String flowName)
	{
		List<MockInvocation> history = INVOCATION_HISTORY.get(normalizeKey(flowName));
		return history == null ? 0 : history.size();
	}

	/**
	 * @description Returns the most recent `MockInvocation` recorded for the flow, or null
	 * when no invocation exists.
	 *
	 * @param flowName The flow API name
	 *
	 * @return The last invocation, or null if never invoked
	 */
	private static MockInvocation lastInvocation(String flowName)
	{
		List<MockInvocation> history = INVOCATION_HISTORY.get(normalizeKey(flowName));
		if(history == null || history.isEmpty())
		{
			return null;
		}
		return history[history.size() - 1];
	}

	/**
	 * @description Normalizes a flow name for case-insensitive registry lookup.
	 *
	 * @param flowName The flow name to normalize
	 *
	 * @return Lowercase trimmed key, or empty string when blank
	 */
	private static String normalizeKey(String flowName)
	{
		return String.isBlank(flowName) ? '' : flowName.trim().toLowerCase();
	}

	/**
	 * @description Captured input snapshot for one mocked flow invocation.
	 *
	 * Holds the `record` and `recordPrior` SObjects the trigger framework passed to the
	 * flow input map, exposed to subscriber tests via `getLastInputRecord` /
	 * `getLastInputPriorRecord`. Internal — subscribers should not construct or mutate
	 * `MockInvocation` directly.
	 */
	private class MockInvocation
	{
		/**
		 * @description The `record` SObject the flow received.
		 */
		private final SObject record;

		/**
		 * @description The `recordPrior` SObject the flow received, or null when none.
		 */
		private final SObject priorRecord;

		/**
		 * @description The Change Event `header` input variable the flow received
		 * (a `DTO_ChangeEventHeader`), or null for non-CDC dispatches.
		 */
		private final Object header;

		/**
		 * @description Constructs a snapshot of the inputs passed to one flow invocation.
		 *
		 * @param record The `record` input variable
		 * @param priorRecord The `recordPrior` input variable, or null when none
		 * @param header The Change Event header, or null when the dispatch is not CDC
		 */
		private MockInvocation(SObject record, SObject priorRecord, Object header)
		{
			this.record = record;
			this.priorRecord = priorRecord;
			this.header = header;
		}
	}

	/**
	 * @description Result captured by a registered mock.
	 *
	 * Read by `TRG_InvokeFlow.invokeSingle` to project the mocked outcome onto the
	 * triggering record without invoking the platform Flow runtime. Subscriber-facing
	 * test code should use the fluent `MockBuilder` chain rather than constructing
	 * `MockResult` directly.
	 */
	public class MockResult
	{
		/**
		 * @description True when the mock represents a successful flow execution.
		 */
		public Boolean success;

		/**
		 * @description Error message returned by the mock when `success = false`.
		 */
		public String errorMessage;

		/**
		 * @description The single SObject the mocked flow's `record` output variable returns.
		 *
		 * Null when the mock represents a failure or when the test author registered
		 * a list of records via `withOutputRecords`.
		 */
		public SObject outputRecord;

		/**
		 * @description The list of SObjects returned by the mocked flow when a single
		 * registration needs to seed multiple output records (e.g. a flow that populates
		 * a `records` collection variable). The framework reads `outputRecord` for the
		 * default per-record dispatch path.
		 */
		public List<SObject> outputRecords;

		/**
		 * @description When non-null, the trigger framework throws this exception at the
		 * point in `invokeSingle` where a real `Flow.Interview.start()` call would have
		 * raised — letting tests drive the runtime-error catch block via mock registration
		 * without deploying a deliberately-broken flow XML.
		 */
		public Exception exceptionToThrow;

		/**
		 * @description Builds a MockResult with default success=true.
		 */
		public MockResult()
		{
			success = true;
		}
	}

	/**
	 * @description Fluent builder for registering a mock flow response.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * TST_InvokeFlowMock.forFlow('Foobar_SetDefaults')
	 *     .succeed()
	 *     .withOutputRecord(record)
	 *     .register();
	 * ```
	 */
	global class MockBuilder
	{
		/**
		 * @description The flow name for this mock.
		 */
		private final String flowName;

		/**
		 * @description The mock result being built.
		 */
		private final MockResult result;

		/**
		 * @description Constructs a builder for the given flow.
		 *
		 * @param flowName The flow API name
		 */
		private MockBuilder(String flowName)
		{
			this.flowName = flowName;
			this.result = new MockResult();
		}

		/**
		 * @description Declares this mock returns a successful flow result.
		 *
		 * Default state — call is optional but improves readability.
		 *
		 * @return This builder for chaining
		 *
		 * @since 1.0
		 */
		global MockBuilder succeed()
		{
			result.success = true;
			result.errorMessage = null;
			return this;
		}

		/**
		 * @description Declares this mock simulates a flow failure.
		 *
		 * @param errorMessage The error message returned by the mock
		 *
		 * @return This builder for chaining
		 *
		 * @since 1.0
		 */
		global MockBuilder fail(String errorMessage)
		{
			result.success = false;
			result.errorMessage = errorMessage;
			return this;
		}

		/**
		 * @description Supplies the SObject the mocked flow's `record` output returns.
		 *
		 * @param outputRecord The SObject the flow's `record` output variable yields
		 *
		 * @return This builder for chaining
		 *
		 * @since 1.0
		 */
		global MockBuilder withOutputRecord(SObject outputRecord)
		{
			result.outputRecord = outputRecord;
			return this;
		}

		/**
		 * @description Supplies the list of SObjects the mocked flow returns when the
		 * registration needs to seed multiple output records (e.g. a flow that populates
		 * a `records` collection variable). For the default per-record dispatch path,
		 * use `withOutputRecord(SObject)` instead.
		 *
		 * @param outputRecords The list of SObjects the flow returns
		 *
		 * @return This builder for chaining
		 *
		 * @since 1.0
		 */
		global MockBuilder withOutputRecords(List<SObject> outputRecords)
		{
			result.outputRecords = outputRecords;
			return this;
		}

		/**
		 * @description Configures this mock to raise the supplied exception at the point in
		 * the trigger framework where `Flow.Interview.start()` would have run for a real
		 * flow. Lets test authors drive the runtime-error catch path (the framework's
		 * `catch (Exception runtimeError)` branch and the `LogAndContinue` / `BlockDml`
		 * routing that depends on it) without deploying a deliberately-broken flow XML.
		 *
		 * Marks this mock as a failure (`success = false`); the supplied exception's
		 * `getMessage()` is what the trigger framework records and surfaces to subscribers.
		 *
		 * @param toThrow The exception the trigger framework will throw on the test author's behalf
		 *
		 * @return This builder for chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * TST_InvokeFlowMock.forFlow('Foobar_SetDefaults')
		 *     .throwOnStart(new System.NullPointerException())
		 *     .register();
		 * ```
		 */
		global MockBuilder throwOnStart(Exception toThrow)
		{
			result.exceptionToThrow = toThrow;
			result.success = false;
			return this;
		}

		/**
		 * @description Registers this mock in the static registry. Terminal.
		 *
		 * Throws if a mock for the same flow is already registered. Tests that need
		 * to reconfigure a mock mid-method must call `TST_InvokeFlowMock.clear()` first.
		 *
		 * @throws UTIL_Exceptions.IllegalStateException When a mock is already registered for this flow
		 *
		 * @since 1.0
		 */
		global void register()
		{
			String key = normalizeKey(flowName);
			if(MOCK_REGISTRY.containsKey(key))
			{
				throw new UTIL_Exceptions.IllegalStateException
						(
								String.format(ERR_DOUBLE_REGISTER, new List<String> {flowName})
						);
			}
			MOCK_REGISTRY.put(key, result);
		}
	}
}