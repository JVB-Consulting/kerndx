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
 * @date February 2026, May 2026
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
	 * @description Test-only seam — when set to `true`, `isFatalGovernorError` returns true for ANY
	 * caught exception so tests can drive the rethrow branch without throwing a real
	 * `System.LimitException`. Production code paths leave this `false`.
	 *
	 * Exposed `@TestVisible` because user-mode Apex tests cannot drive a real
	 * `System.LimitException` through a try/catch — user-thrown LimitException escapes all
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
	 * data that could not be reliably redacted. Subscribers catch this type to detect that
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