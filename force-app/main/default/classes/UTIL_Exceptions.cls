// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Centralised container for framework-specific exception types.
 * Groups related exception classes under a single outer class to minimise top-level file count
 * while keeping each exception independently referenceable.
 *
 * @see UTIL_Exceptions_TEST
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date February 2026, October 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * if(config == null)
 * {
 *     throw new UTIL_Exceptions.ConfigurationException('Missing required configuration.');
 * }
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class UTIL_Exceptions
{
	/**
	 * @description Test-only switch: when set to `true`, `isFatalGovernorError` returns true for ANY
	 * caught exception so tests can drive the rethrow branch without throwing a real
	 * `System.LimitException`. Production code paths leave this `false`.
	 *
	 * Exposed `@TestVisible` because user-mode Apex tests cannot drive a real
	 * `System.LimitException` through a try/catch. A LimitException that user code throws escapes all
	 * catches at the executor level. The toggle lets tests drive the rethrow branch with an
	 * injectable non-LimitException for coverage purposes; production code paths set the
	 * toggle to `false` and never mutate it.
	 *
	 * @since 1.0
	 */
	@TestVisible
	private static Boolean simulateFatalGovernorErrorForTest = false;

	/**
	 * @description Thrown when required platform configuration is absent or malformed.
	 * Typical triggers include missing custom metadata records, unset custom settings,
	 * or incompatible configuration values that prevent normal operation.
	 *
	 * @group Utilities
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * if(credential == null)
	 * {
	 *     throw new UTIL_Exceptions.ConfigurationException('Named credential not found for service: ' + serviceName);
	 * }
	 * ```
	 */
	global inherited sharing class ConfigurationException extends Exception
	{
	}

	/**
	 * @description Thrown when a lookup for a specific record or resource yields no results.
	 * Commonly raised by selector `findByIdOrThrow` methods and resource-loading utilities
	 * to distinguish "not found" from other failure modes.
	 *
	 * @group Utilities
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Account account = new SEL_Account().findById(accountId);
	 * if(account == null)
	 * {
	 *     throw new UTIL_Exceptions.NotFoundException('Account does not exist: ' + accountId);
	 * }
	 * ```
	 */
	global inherited sharing class NotFoundException extends Exception
	{
	}

	/**
	 * @description Thrown when an operation is attempted on an object whose internal state
	 * does not support that operation. Use this to enforce lifecycle constraints
	 * such as calling methods out of order or re-entering a finalised workflow.
	 *
	 * @group Utilities
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * if(isFinished)
	 * {
	 *     throw new UTIL_Exceptions.IllegalStateException('Transaction has already been committed.');
	 * }
	 * ```
	 */
	global inherited sharing class IllegalStateException extends Exception
	{
	}

	/**
	 * @description Thrown when a masking rule configured with `FailureAction__c = BlockDml`
	 * fails. Propagates out of `UTIL_FrameworkMasker.RecordMasker.apply` and (via the trigger
	 * dispatcher pre-step) the surrounding DML so the record is never persisted with sensitive
	 * data that could not be reliably redacted. Catch this type in your code to detect that
	 * the framework aborted a write because masking could not complete safely.
	 *
	 * @see UTIL_FrameworkMasker
	 *
	 * @group Data Masking
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * try
	 * {
	 *     insert account;
	 * }
	 * catch(UTIL_Exceptions.MaskingBlockedException blocked)
	 * {
	 *     handleMaskingFailure(blocked);
	 * }
	 * ```
	 */
	global inherited sharing class MaskingBlockedException extends Exception
	{
	}

	/**
	 * @description Throw this from your own outbound handler code to say the failure is permanent: sending the same
	 * request again cannot help. The framework then ends the call Failed at once, with one issue and no retry scheduled,
	 * whatever the retry settings and the handler's retry strategy say. Throw it from prepareRequest(), a request DTO's
	 * populate(), createRequest() and the methods it calls, parseResponse(), onSuccess() or createRetryStrategy().
	 * Thrown from getValidationErrors() it ends the call Aborted instead, because a refusal in validation always does. A
	 * throw raised while the records you registered are saved reaches the framework as a DmlException, whatever you
	 * threw, and is decided like any other failure after a successful response. For a success status whose body carries
	 * a refusal, throw RequestRefusedException from parseResponse() instead: it is refused the same way, and the issue
	 * it leaves records that the external system did not act.
	 *
	 * @see API_Outbound
	 *
	 * @group Web Services
	 *
	 * @since 1.8
	 *
	 * @example
	 * ```apex
	 * global override void prepareRequest()
	 * {
	 *     super.prepareRequest();
	 *     if(String.isBlank(orderNumber))
	 *     {
	 *         throw new UTIL_Exceptions.PermanentFailureException('The order has no number; sending it again cannot help.');
	 *     }
	 * }
	 * ```
	 */
	global virtual inherited sharing class PermanentFailureException extends Exception
	{
	}

	/**
	 * @description Throw this from parseResponse() when the external system answered with a success status but its body says
	 * it refused the request, for example an order answered 200 with status REJECTED. It is a PermanentFailureException, so
	 * the call ends Failed at once, with one issue and no retry scheduled. A refusal means the external system did not act,
	 * so the issue's External System May Have Acted box stays clear and the issue can be run again from the API Issues list
	 * once the cause is fixed. Thrown from anywhere else, onSuccess() included, it behaves exactly as PermanentFailureException
	 * does, and an issue for a failure after a success status then says the external system acted, because by then it did.
	 *
	 * @see API_Outbound
	 *
	 * @group Web Services
	 *
	 * @since 1.8
	 *
	 * @example
	 * ```apex
	 * global override void parseResponse()
	 * {
	 *     super.parseResponse();
	 *     if(((DTO_Response)responsePayload).status == 'REJECTED')
	 *     {
	 *         throw new UTIL_Exceptions.RequestRefusedException('The external system rejected the order; fix the order and run the call again.');
	 *     }
	 * }
	 * ```
	 */
	global inherited sharing class RequestRefusedException extends PermanentFailureException
	{
	}

	/**
	 * @description Thrown by the post-trigger no-DML contract guard when an
	 * `IF_Trigger.PostAction.execute(context)` performs synchronous DML inside the trigger
	 * dispatcher unwind. `UTIL_PostTriggerAction.handleFailure` always rethrows this type
	 * regardless of the row's `FailureAction__c` policy, because the no-DML rule is the framework's
	 * own rule, not a choice the policy makes.
	 *
	 * Intentionally `public`, not `global`: it signals a broken rule found while developing
	 * (a post-action may only compute, log or queue asynchronous work, never run synchronous DML),
	 * always aborts the transaction, and is never caught for recovery by subscriber code.
	 * The type must be its own: the guard tells it apart through `instanceof` from
	 * exceptions thrown by the action itself, so it must be a type no subscriber action raises.
	 *
	 * @see UTIL_PostTriggerAction
	 *
	 * @group Triggers
	 *
	 * @since 1.1
	 */
	public inherited sharing class PostActionDmlException extends Exception
	{
	}

	/**
	 * @description Discriminates governor blowouts (which must propagate verbatim to abort the
	 * surrounding transaction) from runtime errors (which route through caller-defined failure
	 * policies). Returns `true` when the caught exception is a `System.LimitException` so the
	 * surrounding `catch(Exception)` rethrows verbatim instead of swallowing.
	 *
	 * Centralised here so every framework call site classifies governor blows identically;
	 * a future addition to "what counts as fatal" propagates from one place.
	 *
	 * @param caught The exception raised inside a try block.
	 *
	 * @return `true` when the exception should be rethrown verbatim, `false` for routine runtime errors.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * try
	 * {
	 *     riskyOperation();
	 * }
	 * catch(Exception caught)
	 * {
	 *     if(UTIL_Exceptions.isFatalGovernorError(caught))
	 *     {
	 *         throw caught;
	 *     }
	 *     handleRoutineFailure(caught);
	 * }
	 * ```
	 */
	public static Boolean isFatalGovernorError(Exception caught)
	{
		return caught instanceof System.LimitException || simulateFatalGovernorErrorForTest;
	}
}