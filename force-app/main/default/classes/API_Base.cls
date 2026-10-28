// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Base class for all API web service calls (outbound and inbound).
 * Provides common functionality for HTTP request handling, error management, and data persistence.
 *
 * @see API_Base_TEST
 * @see API_Dispatcher_TEST
 * @see API_PostExample_TEST
 * @see API_Echo_TEST
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, October 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * public class API_MyService extends API_Outbound
 * {
 *     global override void configure()
 *     {
 *         super.configure();
 *         requestPayload = new DTO_Request();
 *     }
 * }
 * ```
 */
@SuppressWarnings
(
		'PMD.AvoidGlobalModifier,PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.ExcessiveClassLength,PMD.AvoidBooleanMethodParameters,PMD.ExcessivePublicCount,PMD.NcssCount,PMD.NcssTypeCount'
)
global abstract inherited sharing class API_Base extends DML_Transaction
{
	/**
	 * @description Flag to simulate storing data to a file for testing.
	 */
	@TestVisible
	private static Boolean simulateStoreToFile = false;

	/**
	 * @description Error message when the API is disabled.
	 */
	@TestVisible
	private static final String ERROR_API_DISABLED = 'API has been disabled';

	/**
	 * @description Error message when the API service is inactive via IsActive__c.
	 */
	public static final String ERROR_API_INACTIVE = 'API service is not active';

	/**
	 * @description Error message when a required feature flag condition is not met.
	 */
	public static final String ERROR_REQUIRED_CONDITION_NOT_MET = 'Required condition "{0}" is not met';

	/**
	 * @description Error message when a bypass feature flag condition is met, causing the service to be skipped.
	 */
	public static final String ERROR_API_BYPASSED = 'API service bypassed by feature flag "{0}"';

	/**
	 * @description Feature flag name for disabling all API calls.
	 */
	public static final String FLAG_DISABLE_ALL_APIS = 'DisableAllAPIs';

	/**
	 * @description Feature flag name that decides who may delete API calls and API issues. A built-in rule turns it on for
	 * everyone who holds the Delete API Records permission. The scheduled purge and the Health Check read it. The delete
	 * guard's trigger action records name it too.
	 */
	public static final String FLAG_BYPASS_API_RECORD_DELETE_GUARD = 'BypassApiRecordDeleteGuard';

	/**
	 * @description Feature flag name that mocks every outgoing call for the users it is on for. The Health Check reads it too.
	 */
	public static final String FLAG_MOCK_ALL_APIS = 'MockAllAPIs';

	/**
	 * @description Feature flag name that turns on mocking for the services whose API Setting has Mocking Enabled
	 * ticked. Only the users the flag is on for get mock answers; for everyone else those services work for real.
	 */
	public static final String FLAG_MOCK_SELECTED_APIS = 'MockSelectedAPIs';

	/**
	 * @description Number of active safe mode scopes.
	 */
	@TestVisible
	private static Integer safeModeActiveScopeCount = 0;

	/**
	 * @description Unique correlation ID for this handler instance.
	 * Used to isolate logging context in batch scenarios where multiple handlers
	 * are processed within the same transaction.
	 */
	private String handlerCorrelationId;

	/**
	 * @description The id under which the logging engine holds this handler's call details: the handler's own id until
	 * the call runs under a trace, then the trace id. Only one entry is held at a time; moving to another id drops the
	 * entry under the previous one.
	 */
	private String loggingContextKey;

	/**
	 * @description Flag tracking whether the setting query has been executed.
	 */
	@TestVisible
	private Boolean settingQueryRun = false;

	/**
	 * @description How many times the handler's own unit of work tries its commit again when the platform refuses a row
	 * lock: once, the same count DML_Builder.withRetryOnLock() applies without an argument. Only the commit of the records
	 * the handler registered runs again; the callout the handler made is never sent again by this retry.
	 */
	private static final Integer COMMIT_RETRIES_ON_LOCK = 1;

	/**
	 * @description The phrase the platform puts in the message of every DmlException it raises for refused rows. A
	 * DmlException built in code (throw new DmlException('...')) carries no row errors, and asking it for them ends the
	 * transaction with an error no catch block receives, so the row errors are read only from an exception whose message
	 * carries this phrase.
	 */
	private static final String DML_ROW_ERRORS_PHRASE = 'First exception on row';

	/**
	 * @description True when the last attempt of the current commit failed. Each attempt sets it to false when it
	 * starts and to its own result when it ends. So once the commit is over, it is true only when the commit failed for
	 * good. commitWork then reads it to clear the Id of a call record that was new: the insert that gave the record its
	 * Id was rolled back, so the Id no longer points to a saved row.
	 */
	private Boolean hasLastCommitAttemptFailed = false;

	/**
	 * @description The exception that API_Base.performValidation caught while it checked the call, for example one that
	 * getValidationErrors() threw. Null when those checks threw nothing. The extra outbound checks in
	 * API_Outbound.performValidation never set it. It is kept apart from lastFailure, because the
	 * outbound retry decision reads lastFailure and a call that failed its checks must never be retried. Each direction
	 * reads it to mark the call as a permanent failure when isPermanentFailure says the exception is one.
	 */
	protected Exception validationFailure;

	/**
	 * @description The payload fields of the call record, in the order their files are made: the request body, the
	 * response body, the address and the request parameters.
	 */
	private static final List<SObjectField> PAYLOAD_FIELDS = new List<SObjectField>
	{
			ApiCall__c.Request__c, ApiCall__c.Response__c, ApiCall__c.URL__c, ApiCall__c.RequestParameters__c
	};

	/**
	 * @description The title, before the file extension, of the file that holds the whole request body of a call when
	 * the body is too long for the Request field of the call record.
	 */
	public static final String REQUEST_BODY_FILE_TITLE = 'RequestBody';

	/**
	 * @description The title, before the file extension, of the file that holds the whole text of each payload field
	 * when the text is too long for the field.
	 */
	private static final Map<SObjectField, String> FILE_TITLE_BY_PAYLOAD_FIELD = new Map<SObjectField, String>
	{
			ApiCall__c.Request__c => REQUEST_BODY_FILE_TITLE,
			ApiCall__c.Response__c => 'ResponseBody',
			ApiCall__c.URL__c => 'Url',
			ApiCall__c.RequestParameters__c => 'RequestParameters'
	};

	/**
	 * @description What this handler already masked for each payload field: the raw payload, the masked text written to
	 * the field and, while no file holds it yet, the whole masked text when it is too long for the field. There is at
	 * most one entry for each payload field. setApiCallDetails adds an entry when it masks a payload too long for its
	 * field; the file step adds one when it masks a payload again. When setApiCallDetails or the file step meets the
	 * same raw payload again (the inbound commit writes the call details twice, a commit refused for a row lock runs
	 * again, a failed call writes them once more), the entry's field text is used and nothing is masked again. The file
	 * step takes the whole masked text once and drops it, so a long text is not kept for the rest of the transaction.
	 */
	private final Map<SObjectField, MaskedPayload> maskedPayloadsByField = new Map<SObjectField, MaskedPayload>();

	/**
	 * @description The values of the call record's fields as the handler's own commit wrote them, taken right after the
	 * commit's statements ran (see onDMLFinished), before any step of the commit changes the record again.
	 * buildApiCallChangesToSave compares the record with them, so the save after the commit sends only the fields that
	 * changed since the row was written, including the ones the inbound commit fills after its statements. Null until a
	 * commit of this handler wrote the record, and again after an attempt of the commit that failed.
	 */
	private Map<String, Object> savedApiCallFieldValues;

	/**
	 * @description Length of a W3C span ID in hex characters.
	 */
	private static final Integer SPAN_ID_LENGTH = 16;
	/**
	 * @description Length of a W3C trace ID in hex characters.
	 */
	private static final Integer TRACE_ID_LENGTH = 32;
	/**
	 * @description Expected number of parts in a W3C Trace Parent header (version-traceId-spanId-flags).
	 */
	private static final Integer TRACE_PARENT_PARTS = 4;
	/**
	 * @description W3C Trace Parent flags value indicating the trace is sampled.
	 */
	private static final String TRACE_PARENT_FLAGS_SAMPLED = '01';
	/**
	 * @description W3C Trace Parent version prefix.
	 */
	private static final String TRACE_PARENT_VERSION = '00';
	/**
	 * @description Lowercase hex character set for trace and span ID generation.
	 */
	private static final String HEX_CHARACTERS = '0123456789abcdef';
	/**
	 * @description Compiled regex for validating lowercase hex strings per W3C Trace Context.
	 */
	private static final Pattern HEX_PATTERN = Pattern.compile('[0-9a-f]+');
	/**
	 * @description Invalid all-zeros trace ID, as the W3C Trace Context standard defines it.
	 */
	private static final String INVALID_TRACE_ID = '00000000000000000000000000000000';
	/**
	 * @description Invalid all-zeros parent ID, as the W3C Trace Context standard defines it.
	 */
	private static final String INVALID_PARENT_ID = '0000000000000000';

	/**
	 * @description When true, prevents the API call from being registered for DML in the handler's unit of work.
	 * Used by UTIL_HttpClient for skipLogging (no persistence at all) and subscriber handler mode
	 * (dispatcher owns the API call lifecycle instead of individual handlers).
	 */
	public Boolean skipPersistence = false;

	/**
	 * @description HTTP status code for a successful request (200).
	 */
	public static final Integer HTTP_OK = 200;

	/**
	 * @description HTTP status code for resource creation (201).
	 */
	public static final Integer HTTP_CREATED = 201;

	/**
	 * @description HTTP status code for accepted but unprocessed requests (202).
	 */
	public static final Integer HTTP_ACCEPTED = 202;

	/**
	 * @description HTTP status code for non-authoritative information (203).
	 */
	public static final Integer HTTP_NON_AUTH_INFO = 203;

	/**
	 * @description HTTP status code for no content (204).
	 */
	public static final Integer HTTP_NO_CONTENT = 204;

	/**
	 * @description HTTP status code for reset content (205).
	 */
	public static final Integer HTTP_RESET_CONTENT = 205;

	/**
	 * @description HTTP status code for bad request (400).
	 */
	public static final Integer HTTP_BAD_REQUEST = 400;

	/**
	 * @description HTTP status code for request timeout (408): the external system gave up waiting for the request and asks for it again.
	 */
	public static final Integer HTTP_REQUEST_TIMEOUT = 408;

	/**
	 * @description HTTP status code for `Conflict` (409). Returned when an inbound request
	 * replays the same `Idempotency-Key` with a different request body — the original
	 * processed call's `ApiCall__c.Id` is included in the 409 response body so callers can
	 * reconcile against the conflicting record.
	 */
	public static final Integer HTTP_CONFLICT = 409;

	/**
	 * @description HTTP status code for not found (404).
	 */
	public static final Integer HTTP_NOT_FOUND = 404;

	/**
	 * @description HTTP status code for too early (425): the external system asks the caller to wait and send again.
	 */
	public static final Integer HTTP_TOO_EARLY = 425;

	/**
	 * @description HTTP status code for too many requests (429).
	 */
	public static final Integer HTTP_TOO_MANY_REQUESTS = 429;

	/**
	 * @description HTTP status code for internal server error (500).
	 */
	public static final Integer HTTP_INTERNAL_SERVER_ERROR = 500;

	/**
	 * @description HTTP status code for bad gateway (502): a system between the caller and the external system failed to respond.
	 */
	public static final Integer HTTP_BAD_GATEWAY = 502;

	/**
	 * @description HTTP status code for service unavailable (503): the external system is temporarily unable to respond.
	 */
	public static final Integer HTTP_SERVICE_UNAVAILABLE = 503;

	/**
	 * @description HTTP status code for gateway timeout (504): a system between the caller and the external system gave up waiting.
	 */
	public static final Integer HTTP_GATEWAY_TIMEOUT = 504;

	/**
	 * @description Set of HTTP status codes indicating successful requests.
	 */
	public static final Set<Integer> HTTP_SUCCESS_CODES = new Set<Integer>
	{
			HTTP_OK, HTTP_CREATED, HTTP_ACCEPTED, HTTP_NON_AUTH_INFO, HTTP_NO_CONTENT, HTTP_RESET_CONTENT
	};

	/**
	 * @description Standard error message for internal server errors.
	 */
	public static final String ERR_INTERNAL_SERVER = 'Internal Server Error';

	/**
	 * @description Bearer token prefix for authorization headers.
	 */
	@SuppressWarnings('PMD.AvoidHardcodedCredentialsInFieldDecls')
	public static final String HTTP_AUTH_TOKEN_BEARER = 'Bearer ';

	/**
	 * @description Standard HTTP header for content type.
	 */
	public static final String HTTP_CONTENT_TYPE = 'Content-Type';

	/**
	 * @description Standard content type for JSON data.
	 */
	public static final String HTTP_ENCODING_JSON = 'application/json';

	/**
	 * @description Standard HTTP header for acceptable response formats.
	 */
	public static final String HTTP_HEADER_ACCEPT = 'Accept';

	/**
	 * @description Standard HTTP header for authorization.
	 */
	@SuppressWarnings('PMD.AvoidHardcodedCredentialsInFieldDecls')
	public static final String HTTP_HEADER_AUTHORIZATION = 'Authorization';

	/**
	 * @description Names of the headers whose values are credentials: the standard HTTP carriers (Authorization,
	 * Proxy-Authorization, Cookie, Set-Cookie) and the vendor key headers most APIs use (X-Api-Key, Api-Key,
	 * X-Auth-Token). Lower-case, compared case-insensitively by redactCredentialHeaders. Every surface that shows or
	 * stores a call's headers redacts exactly these, so the displayed and the stored copies never drift apart.
	 */
	@SuppressWarnings('PMD.AvoidHardcodedCredentialsInFieldDecls')
	public static final Set<String> CREDENTIAL_HEADER_NAMES = new Set<String>
	{
			'authorization', 'proxy-authorization', 'cookie', 'set-cookie', 'x-api-key', 'api-key', 'x-auth-token'
	};

	/**
	 * @description Name fragments that mark a header as credential-bearing whatever its exact name, so a vendor's
	 * proprietary header (X-Vendor-Secret, X-Access-Token) is caught without a list entry. Lower-case, matched as a
	 * case-insensitive contains. The fragment 'key' is deliberately absent: Idempotency-Key and similar operational
	 * headers carry no secret and must stay visible.
	 */
	@SuppressWarnings('PMD.AvoidHardcodedCredentialsInFieldDecls')
	public static final Set<String> CREDENTIAL_HEADER_NAME_FRAGMENTS = new Set<String>
	{
			'secret', 'password', 'passwd', 'token', 'credential'
	};

	/**
	 * @description The value written in place of a credential header's value wherever the framework shows or stores
	 * headers. A data marker rather than message text: the same bytes land in the stored call record and in the API
	 * Test Harness, so it is a constant and not a label, and it matches the vocabulary of the shipped MaskAuthHeader rule.
	 */
	public static final String REDACTED_HEADER_VALUE = '[REDACTED]';

	/**
	 * @description The prefix of a credential merge field ({!$Credential...}), matched anywhere in a header value so
	 * a scheme-prefixed form like 'Bearer {!$Credential.MyExternalCredential.Token}' also qualifies. A credential
	 * header whose value carries it holds no secret, only the platform's placeholder, and is kept verbatim wherever
	 * headers are shown or stored: the merge text is the documented way to send a credential header, and its stored
	 * copy must survive so a retry can send it for the platform to substitute. Deliberately the credential syntax
	 * only, never a bare '{!': an arbitrary merge expression is not a credential reference and gets no pass-through.
	 */
	public static final String PLATFORM_MERGE_FIELD_PREFIX = '{!$Credential';

	/**
	 * @description Ensures that RFC-7230 validation is enforced.
	 */
	public static final String HTTP_HEADER_RFC_7230_CHECK = 'RFC-7230-Check';

	/**
	 * @description The User-Agent request header that identifies the application.
	 */
	public static final String HTTP_HEADER_USER_AGENT = 'User-Agent';

	/**
	 * @description Standard character encoding scheme.
	 */
	public static final String UTF8_ENCODING_SCHEME = 'UTF-8';

	/**
	 * @description Content type header value for JSON with UTF-8 encoding.
	 */
	public static final String HTTP_ACCEPT_JSON_WITH_CHARSET = 'application/json; charset=' + UTF8_ENCODING_SCHEME;

	/**
	 * @description HTTP header name for W3C Trace Context.
	 */
	public static final String HEADER_TRACE_PARENT = 'traceparent';
	/**
	 * @description HTTP header name for idempotency keys.
	 */
	public static final String HEADER_IDEMPOTENCY_KEY = 'Idempotency-Key';
	/**
	 * @description Thread-local trace context for the current transaction.
	 */
	public static TraceContext currentTraceContext;

	/**
	 * @description HTTP method verbs for web service calls.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * API_Base.HttpMethod method = API_Base.HttpMethod.POST;
	 * ```
	 */
	global enum HttpMethod
	{
		/**
		 * @description HTTP GET method for retrieving resources.
		 */
		GET,
		/**
		 * @description HTTP POST method for creating resources.
		 */
		POST,
		/**
		 * @description HTTP PUT method for updating resources.
		 */
		PUT,
		/**
		 * @description HTTP DELETE method for removing resources (named DELETION to avoid reserved word).
		 */
		DELETION,
		/**
		 * @description HTTP PATCH method for partial updates.
		 */
		PATCH
	}

	/**
	 * @description Converts an HttpMethod enum value to its HTTP wire-format string.
	 * All values map directly via name() except DELETION which becomes 'DELETE'.
	 *
	 * @param method The enum value
	 *
	 * @return The HTTP method string (e.g. 'GET', 'DELETE')
	 */
	public static String toHttpString(HttpMethod method)
	{
		return method == HttpMethod.DELETION ? 'DELETE' : method?.name();
	}

	/**
	 * @description Parses an HTTP method string into its HttpMethod enum value.
	 *
	 * @param method The HTTP method string (e.g. 'GET', 'DELETE')
	 *
	 * @return The corresponding HttpMethod enum value, or null if unrecognised
	 */
	public static HttpMethod fromHttpString(String method)
	{
		if(method == null)
		{
			return null;
		}
		return 'DELETE'.equalsIgnoreCase(method) ? HttpMethod.DELETION : HttpMethod.valueOf(method.toUpperCase());
	}

	/**
	 * @description Tracks the request, response, and status of a web service call.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Boolean success = handler.result.isSuccess;
	 * ```
	 */
	global ServiceCallResult result
	{
		get
		{
			if(result == null)
			{
				result = new ServiceCallResult();
			}
			return result;
		}
		private set;
	}

	/**
	 * @description Returns errors encountered during the request or the error payload if no error is logged.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String errors = handler.errorText;
	 * ```
	 */
	global String errorText
	{
		get
		{
			return !result.isSuccess ? result.errors.isEmpty() ? result.responseBody : String.join(result.errors, UTIL_String.LF) : UTIL_String.EMPTY;
		}
	}

	/**
	 * @description The ApiCall__c object that initiated the service call.
	 *
	 * Its payload fields (the request, the response, the address and the request parameters) are not always masked,
	 * even after the call was saved. A payload that fits its field is masked when the call is saved to the database,
	 * but this record still holds the raw text the call sent or received: the save does not copy the masked text back
	 * into it. A payload field holds masked text only when the payload is longer than the field (the masked text is then
	 * cut to fit), or, in some cases, when the payload was masked again to make its file. So code that reads this record
	 * after a save must never pass a payload field on as if it were masked. To get the masked text, read the saved call
	 * back from the database by its Id.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * ApiCall__c item = handler.apiCall;
	 * ```
	 */
	global ApiCall__c apiCall
	{
		get;
		private set;
	}

	/**
	 * @description The unique correlation ID for this handler instance.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String id = handler.correlationId;
	 * ```
	 */
	global String correlationId
	{
		get
		{
			return handlerCorrelationId;
		}
	}

	/**
	 * @description DTO containing parameters passed to the API.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String value = inputs.get('parameterName');
	 * ```
	 */
	global protected DTO_NameValues inputs
	{
		get
		{
			if(inputs == null)
			{
				inputs = new DTO_NameValues();
			}
			return inputs;
		}
		set;
	}

	/**
	 * @description Class name of the current service. Internal caching; use getServiceName() for access.
	 */
	private String className
	{
		get
		{
			if(String.isBlank(className))
			{
				className = UTIL_System.getRuntimeTypeName(this);
			}
			return className;
		}
		private set;
	}

	/**
	 * @description API settings metadata for this service, lazy-loaded from ApiSetting__mdt.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Boolean isActive = handler.setting.IsActive__c;
	 * ```
	 */
	global protected ApiSetting__mdt setting
	{
		get
		{
			if(settingQueryRun == false)
			{
				setting = new SEL_ApiSetting().findByClassName(getServiceName());
				settingQueryRun = true;
			}
			return setting;
		}
		private set;
	}

	/**
	 * @description Injects in-memory settings, bypassing the lazy metadata query.
	 * Used by UTIL_HttpClient to provide fluent configuration without real ApiSetting__mdt records.
	 *
	 * @param settingToApply The in-memory settings to inject
	 */
	public void applySettings(ApiSetting__mdt settingToApply)
	{
		this.setting = settingToApply;
		this.settingQueryRun = true;
	}

	/**
	 * @description Stopwatch for tracking outbound web service call duration.
	 */
	public UTIL_StopWatch calloutProcessingTime
	{
		get
		{
			if(calloutProcessingTime == null)
			{
				calloutProcessingTime = new UTIL_StopWatch();
			}
			return calloutProcessingTime;
		}
		private set;
	}

	/**
	 * @description Stopwatch for tracking commit process duration.
	 */
	public UTIL_StopWatch commitProcessingTime
	{
		get
		{
			if(commitProcessingTime == null)
			{
				commitProcessingTime = new UTIL_StopWatch();
			}
			return commitProcessingTime;
		}
		private set;
	}

	/**
	 * @description Stopwatch for tracking total web service processing time.
	 * Uses UTIL_PerformanceTimer for automatic performance logging when threshold is exceeded.
	 */
	public UTIL_StopWatch fullProcessingTime
	{
		get
		{
			if(fullProcessingTime == null)
			{
				fullProcessingTime = new UTIL_PerformanceTimer(getServiceName(), getServiceName() + '/execute');
			}
			return fullProcessingTime;
		}
		private set;
	}

	/**
	 * @description Stopwatch for tracking service processing time (excludes commit time).
	 */
	public UTIL_StopWatch serviceProcessingTime
	{
		get
		{
			if(serviceProcessingTime == null)
			{
				serviceProcessingTime = new UTIL_StopWatch();
			}
			return serviceProcessingTime;
		}
		private set;
	}

	/**
	 * @description The exception the framework caught for this call: a parse failure, a throw from a handler hook, or a
	 * callout that got no response. Null when the failure carried no exception, as when the external system responded
	 * with a status code. The outbound retry decision reads it to learn the failure's type and passes it into the retry
	 * context. It is set at the framework's own catch sites, never inside handleError, because a handler may override
	 * handleError without calling the base method. There are three such sites: where an outbound response is parsed, on
	 * the dispatcher's error path, and where UTIL_HttpClient hands a call to a subscriber's handler and that handler's
	 * processing or commit throws. A throw from performValidation() leaves it null on purpose (see API_Outbound); that
	 * exception is kept in validationFailure instead.
	 */
	public Exception lastFailure
	{
		protected get;
		set;
	}

	/**
	 * @description Base constructor. Sets the transaction's `AccessLevel` to `SYSTEM_MODE`. `API_Base` extends
	 * `DML_Transaction`, and most of what its unit of work saves is the framework's own audit data: the `ApiCall__c`
	 * record, the `ApiIssue__c` record created on a failure, and the `ContentVersion` attachments. These saves must
	 * succeed whether or not the running user has create, read, update and delete access to those framework objects.
	 * Without this setting, the audit trail would silently disappear whenever a service runs as a user who is not an
	 * administrator and has no access to `ApiCall__c`. A service whose `onSuccess()` or `populate()` code must save
	 * records with the running user's permissions does so in its own transaction, through
	 * `DML_Builder.newTransaction().withUserMode()...execute()`, instead of registering the records with this inherited
	 * unit of work. The unit of work also tries a commit again once when the platform refuses it for a row lock, so a
	 * lock while saving a successful call's records never sends the call again.
	 */
	@SuppressWarnings('ApexUnusedDeclaration,RedundantSuppression')
	public API_Base()
	{
		setAccessLevel(System.AccessLevel.SYSTEM_MODE);
		setRetryOnLock(COMMIT_RETRIES_ON_LOCK);
		configure();
	}

	/**
	 * @description Determines whether the given content should be persisted as a ContentVersion file attachment.
	 * Returns true when the content exceeds the field length limit and the user has create permission,
	 * or when file storage is being simulated in tests.
	 *
	 * @param content The string content to evaluate.
	 * @param fieldLengthLimit The maximum length the corresponding ApiCall__c field can hold.
	 *
	 * @return True if the content should be stored as a file, false otherwise.
	 */
	private static Boolean shouldStoreAsFile(String content, Integer fieldLengthLimit)
	{
		if(String.isBlank(content))
		{
			return false;
		}
		if(simulateStoreToFile)
		{
			return true;
		}
		return content.length() > fieldLengthLimit &&
				(SEL_ContentVersion.isCreateable || SEL_ObjectPermission.hasCreateAccess(UserInfo.getUserId(), ContentVersion.SObjectType));
	}

	/**
	 * @description Creates ContentVersion file attachments for any API call data that exceeds
	 * the corresponding ApiCall__c field length limits. Content is masked with the same
	 * MaskingTarget__mdt rules that fire on the ApiCall__c record itself, so oversized payloads
	 * landing in ContentVersion files carry the same redaction the persisted record does.
	 *
	 * Each payload is masked once on a save, so the file is built from a masked text that already exists when there is
	 * one. For each payload, in this order:
	 *
	 * 1. This handler already masked the same raw text (see maskedPayloadsByField): the whole masked text it kept, if
	 *    any, is the file, and it is not kept any longer. No whole text means no file is needed, or a file already holds
	 *    it.
	 * 2. Otherwise the masker is asked what it did with the raw text for this handler (see
	 *    UTIL_FrameworkMasker.takeMaskedValueAnswer). REMEMBERED: the trigger cut the masked text and kept all of it, and
	 *    that text is the file. FITTED: the masked text fits the field, so no file is needed.
	 * 3. NOT_SEEN or DROPPED: the trigger never masked this raw text (another step changed the field first, for
	 *    example), or did not keep the whole text. The raw text is masked again here, and a file is made when the whole
	 *    masked text is too long for its field. This masking is timed by UTIL_MaskerPerformanceTimer under the name
	 *    ContentVersion, so a performance entry shows each time the file step masks again.
	 *
	 * A rule set to block DML that fails while the payloads are redacted attaches nothing: the block is
	 * recorded on the result and the call still answers its caller (the rule's own warning log names the rule).
	 *
	 * @return A list of uncommitted ContentVersion records, empty if no fields exceed limits or a masking rule blocked the redaction.
	 */
	public List<ContentVersion> createRelatedContentVersions()
	{
		List<ContentVersion> versions = new List<ContentVersion>();
		String callerClassName = getMaskingCallerClassName();
		Map<SObjectField, String> rawValuesByField = buildRawPayloadsByField();
		Map<SObjectField, String> fileTextsByField = new Map<SObjectField, String>();
		List<SObjectField> fieldsToMaskAgain = new List<SObjectField>();

		for(SObjectField field : PAYLOAD_FIELDS)
		{
			String rawValue = rawValuesByField.get(field);
			MaskedPayload knownPayload = findMaskedPayload(field, rawValue);
			if(knownPayload != null)
			{
				fileTextsByField.put(field, knownPayload.wholeMaskedText ?? (simulateStoreToFile ? knownPayload.fieldText : null));
				knownPayload.wholeMaskedText = null;
			}
			else if(String.isNotEmpty(rawValue))
			{
				addFileTextFromMaskerAnswer(field, rawValue, callerClassName, fileTextsByField, fieldsToMaskAgain);
			}
		}

		try
		{
			fileTextsByField.putAll(maskPayloadsAgain(fieldsToMaskAgain, rawValuesByField, callerClassName));
		}
		catch(UTIL_Exceptions.MaskingBlockedException blocked)
		{
			result.errors.add(blocked.getMessage());
			return versions;
		}

		for(SObjectField field : PAYLOAD_FIELDS)
		{
			String fileText = fileTextsByField.get(field);
			if(shouldStoreAsFile(fileText, UTIL_SObjectDescribe.getCachedFieldDescribe(field).getLength()))
			{
				versions.add(TST_Factory.newContentVersion(apiCall.Id, FILE_TITLE_BY_PAYLOAD_FIELD.get(field) + SEL_ContentVersion.TEXT_FILE_EXTENSION, Blob.valueOf(fileText)));
			}
		}
		return versions;
	}

	/**
	 * @description Asks the masker what it did with one raw payload for this handler, and acts on the answer: a
	 * REMEMBERED answer gives the file text, a FITTED answer needs no file, and any other answer puts the field in the
	 * list of fields to mask again. A FITTED payload is masked again too while simulateStoreToFile is on, because a test
	 * then wants a file for every payload, and the masker does not keep a masked text that fits its field.
	 *
	 * @param field The payload field.
	 * @param rawValue The raw payload, never empty.
	 * @param callerClassName The handler class the payload was masked for; empty for no caller.
	 * @param fileTextsByField The file texts found so far; a REMEMBERED text is added.
	 * @param fieldsToMaskAgain The fields whose raw payload must be masked again; the field is added when needed.
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private static void addFileTextFromMaskerAnswer
			(
					SObjectField field,
					String rawValue,
					String callerClassName,
					Map<SObjectField, String> fileTextsByField,
					List<SObjectField> fieldsToMaskAgain
			)
	{
		UTIL_FrameworkMasker.MaskedValueAnswer answer = UTIL_FrameworkMasker.takeMaskedValueAnswer(field, callerClassName, rawValue);
		if(answer.state == UTIL_FrameworkMasker.MaskedValueState.REMEMBERED)
		{
			fileTextsByField.put(field, answer.uncutMaskedValue);
		}
		else if(answer.state != UTIL_FrameworkMasker.MaskedValueState.FITTED || simulateStoreToFile)
		{
			fieldsToMaskAgain.add(field);
		}
	}

	/**
	 * @description Masks the raw payloads of the given fields again, for the files, and times that masking with a
	 * UTIL_MaskerPerformanceTimer named ContentVersion, which writes one performance entry for the run when masker
	 * performance logging is on. Nothing is masked or timed when the list is empty or masking is switched off.
	 *
	 * When the record's field still holds the raw payload (cut to fit), the trigger has not masked it yet: the payload
	 * was set after the record was written (the inbound response, for example), or the record is not saved yet. The
	 * second case is a call that failed before its commit saved it: the error path of API_Dispatcher builds the files of
	 * such a call and saves them together with the call. In both cases the masked text that fits the field is written to
	 * the record and registered with the masker, so the save that follows sends masked text and the trigger leaves it as
	 * it is: the payload is masked once, here. The raw payload and its field text are kept (see maskedPayloadsByField), so a later
	 * setApiCallDetails on the same raw payload masks nothing.
	 *
	 * @param fields The payload fields to mask again.
	 * @param rawValuesByField The raw payload of each field.
	 * @param callerClassName The handler class to mask for; empty for no caller.
	 *
	 * @return The whole masked text of each field, never cut to the field's length.
	 *
	 * @throws UTIL_Exceptions.MaskingBlockedException when a rule with FailureAction = BlockDml fails
	 */
	private Map<SObjectField, String> maskPayloadsAgain(List<SObjectField> fields, Map<SObjectField, String> rawValuesByField, String callerClassName)
	{
		Map<SObjectField, String> maskedTextsByField = new Map<SObjectField, String>();
		if(fields.isEmpty())
		{
			return maskedTextsByField;
		}

		UTIL_MaskerPerformanceTimer timer = UTIL_FrameworkMasker.isMaskingEnabled
				? new UTIL_MaskerPerformanceTimer(UTIL_SObjectDescribe.getObjectNameFromType(ContentVersion.SObjectType), fields.size())
				: null;
		timer?.start();
		for(SObjectField field : fields)
		{
			String rawValue = rawValuesByField.get(field);
			String wholeMaskedText = maskContent(field, rawValue, callerClassName);
			maskedTextsByField.put(field, wholeMaskedText);
			writeMaskedTextOverRawField(field, rawValue, wholeMaskedText, callerClassName);
		}
		timer?.stop();
		return maskedTextsByField;
	}

	/**
	 * @description Writes the masked text that fits the field over the record's field when the field still holds the
	 * raw payload cut to fit, registers it with the masker and keeps the raw payload with it (see maskPayloadsAgain).
	 * A field that holds anything else (the trigger's masked text, or a text another step wrote) is left as it is.
	 * Nothing happens while masking is switched off.
	 *
	 * @param field The payload field.
	 * @param rawValue The raw payload, never empty.
	 * @param wholeMaskedText The whole masked text of the raw payload.
	 * @param callerClassName The handler class the payload was masked for; empty for no caller.
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private void writeMaskedTextOverRawField(SObjectField field, String rawValue, String wholeMaskedText, String callerClassName)
	{
		if(!UTIL_FrameworkMasker.isMaskingEnabled || !UTIL_String.abbreviate(rawValue, field).equals(apiCall.get(field)))
		{
			return;
		}
		String fieldText = UTIL_String.abbreviate(wholeMaskedText, field);
		apiCall.put(field, fieldText);
		UTIL_FrameworkMasker.registerMaskedFieldText(field, callerClassName, fieldText);
		maskedPayloadsByField.put(field, new MaskedPayload(rawValue, fieldText, null));
	}

	/**
	 * @description Finds what this handler already masked for a payload field, when it was the same raw payload.
	 *
	 * @param field The payload field.
	 * @param rawValue The raw payload now; may be null.
	 *
	 * @return The kept entry, or null when the field has none or its entry came from another raw payload.
	 */
	private MaskedPayload findMaskedPayload(SObjectField field, String rawValue)
	{
		MaskedPayload knownPayload = maskedPayloadsByField.get(field);
		return knownPayload != null && knownPayload.rawValue.equals(rawValue) ? knownPayload : null;
	}

	/**
	 * @description Builds the raw text of each payload field: the request body, the response body and the address the
	 * call used, and the serialized request parameters. Empty parameters ({}) count as no parameters, as on the record,
	 * so they are never masked for a file. The one exception is while simulateStoreToFile is on, when a test wants a
	 * file for every payload, empty parameters included.
	 *
	 * @return The raw text of each payload field; a payload the call does not have is null.
	 */
	private Map<SObjectField, String> buildRawPayloadsByField()
	{
		String parameters = inputs.serialize();
		return new Map<SObjectField, String>
		{
				ApiCall__c.Request__c => result.requestBody,
				ApiCall__c.Response__c => result.responseBody,
				ApiCall__c.URL__c => result.url,
				ApiCall__c.RequestParameters__c => UTIL_String.EMPTY_JSON_RESPONSE.equals(parameters) && !simulateStoreToFile ? null : parameters
		};
	}

	/**
	 * @description Finds the handler class a masking target names in CallerClass__c to apply to this handler's calls:
	 * the class name in the API setting of the call's service. The trigger finds the class for the call record the same
	 * way, from the same service name, so the masking this handler does before the save and the masking the trigger
	 * does are always for the same caller.
	 *
	 * @return The handler class name, or the empty string when the service has no setting with a class name.
	 */
	private String getMaskingCallerClassName()
	{
		return SEL_ApiSetting.findClassNameByServiceName(apiCall?.ServiceName__c);
	}

	/**
	 * @description Checks whether a text is longer than its field can hold.
	 *
	 * @param text The text; may be null.
	 * @param field The field the text is saved to.
	 *
	 * @return True when the text has more characters than the field holds.
	 */
	private static Boolean isLongerThanField(String text, SObjectField field)
	{
		return text != null && text.length() > UTIL_SObjectDescribe.getCachedFieldDescribe(field).getLength();
	}

	/**
	 * @description Returns a copy of the headers in which every credential header carries REDACTED_HEADER_VALUE
	 * instead of its value. A header is credential-bearing when its name is in CREDENTIAL_HEADER_NAMES or contains a
	 * CREDENTIAL_HEADER_NAME_FRAGMENTS entry, compared case-insensitively. Every other header is copied as sent, and
	 * two credential values pass through untouched: a blank value (an absent token is not reported as a redacted one)
	 * and a value carrying credential merge-field text (PLATFORM_MERGE_FIELD_PREFIX anywhere in the value, so
	 * 'Bearer {!$Credential...}' qualifies: it holds no secret and its stored copy must survive for retries). A null
	 * map yields an empty map. The redaction reads neither the data-masking feature flag nor any masking rule: it is
	 * a disclosure control on what the framework shows and stores, not a data-at-rest policy an administrator tunes.
	 *
	 * @param headers The headers as sent or received; may be null.
	 *
	 * @return A new map with every credential value redacted.
	 */
	public static Map<String, String> redactCredentialHeaders(Map<String, String> headers)
	{
		Map<String, String> redacted = new Map<String, String>();
		if(headers == null)
		{
			return redacted;
		}
		for(String name : headers.keySet())
		{
			String value = headers.get(name);
			redacted.put(name, isCredentialHeader(name) && String.isNotBlank(value) && !value.contains(PLATFORM_MERGE_FIELD_PREFIX) ? REDACTED_HEADER_VALUE : value);
		}
		return redacted;
	}

	/**
	 * @description Reports whether a header name is credential-bearing: an exact CREDENTIAL_HEADER_NAMES member or a
	 * name containing a CREDENTIAL_HEADER_NAME_FRAGMENTS entry, compared case-insensitively.
	 *
	 * @param name The header name; may be null.
	 *
	 * @return True when the header's value is a credential.
	 */
	public static Boolean isCredentialHeader(String name)
	{
		if(name == null)
		{
			return false;
		}
		String lowered = name.toLowerCase();
		if(CREDENTIAL_HEADER_NAMES.contains(lowered))
		{
			return true;
		}
		for(String fragment : CREDENTIAL_HEADER_NAME_FRAGMENTS)
		{
			if(lowered.contains(fragment))
			{
				return true;
			}
		}
		return false;
	}

	/**
	 * @description The DTO_NameValues form of redactCredentialHeaders(Map), for the invocation results the API Test
	 * Harness maps. Returns a new instance and never mutates its input; a null input yields an empty instance.
	 *
	 * @param headers The headers as sent or received; may be null.
	 *
	 * @return A new DTO_NameValues with every credential value redacted.
	 */
	public static DTO_NameValues redactCredentialHeaders(DTO_NameValues headers)
	{
		Map<String, String> source = new Map<String, String>();
		if(headers != null)
		{
			for(String name : headers.names)
			{
				source.put(name, headers.get(name));
			}
		}
		return new DTO_NameValues(redactCredentialHeaders(source));
	}

	/**
	 * @description Runs the MaskingTarget rules configured for one ApiCall__c field against an
	 * arbitrary string, for the handler class the record is masked for. Lets ContentVersion blobs inherit the same
	 * redaction the persisted ApiCall record gets from its before-insert trigger action. The whole masked text is
	 * returned, never cut to the field's length, so it can be saved in a file.
	 *
	 * @param field The ApiCall__c SObjectField whose rules to apply
	 * @param value The string content to redact
	 * @param callerClassName The handler class to mask for; empty for no caller
	 *
	 * @return The redacted string, or the original value when masking is disabled or the input is blank
	 *
	 * @throws UTIL_Exceptions.MaskingBlockedException when a rule with FailureAction = BlockDml fails
	 */
	private static String maskContent(SObjectField field, String value, String callerClassName)
	{
		if(!UTIL_FrameworkMasker.isMaskingEnabled || String.isEmpty(value))
		{
			return value;
		}
		UTIL_FrameworkMasker.MaskingResult masked = UTIL_FrameworkMasker.forField(field).calledFrom(callerClassName).maskAndReturnWholeText(value);
		return masked.uncutMaskedValue ?? masked.maskedValue;
	}

	/**
	 * @description Returns the HTTP request body.
	 *
	 * @return String The request body, empty by default.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global override String getBody()
	 * {
	 *     return requestPayload.serialize();
	 * }
	 * ```
	 */
	global protected virtual String getBody()
	{
		return UTIL_String.EMPTY;
	}

	/**
	 * @description Returns the HTTP character encoding.
	 *
	 * @return String The encoding scheme, must be implemented by subclasses.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global override String getEncoding()
	 * {
	 *     return 'application/xml';
	 * }
	 * ```
	 */
	global protected abstract String getEncoding();

	/**
	 * @description Returns the HTTP method for the service.
	 *
	 * @return The HTTP method enum value, or null by default.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global override HttpMethod getHttpMethod()
	 * {
	 *     return HttpMethod.GET;
	 * }
	 * ```
	 */
	global protected virtual HttpMethod getHttpMethod()
	{
		return null;
	}

	/**
	 * @description Returns the name of the class that runs the call, read from the object's runtime type the first
	 * time and kept after that. The framework uses it to find the service's API setting and mock, and to label its
	 * timers and log entries.
	 *
	 * @return String The class name of the service.
	 *
	 * @example
	 * ```apex
	 * String serviceName = handler.getServiceName();
	 * ```
	 */
	protected virtual String getServiceName()
	{
		return className;
	}

	/**
	 * @description Creates a ApiIssue__c record for logging failures.
	 *
	 * @return A new failure record, or null by default.
	 */
	public virtual ApiIssue__c createFailureRecord()
	{
		return null;
	}

	/**
	 * @description Builds an issue record for a call that failed, with only the fields that every direction shares: the
	 * call's error messages (or the call's response when it has no error messages), the service, the Open status, the
	 * triggering record and the call itself. The record is not saved. Each direction adds its own fields to it, so every
	 * issue the framework writes starts from this one builder.
	 *
	 * @param apiCall The call that failed.
	 *
	 * @return A new issue record for the call, not yet saved.
	 */
	public static ApiIssue__c buildFailureRecord(ApiCall__c apiCall)
	{
		return new ApiIssue__c(
				ErrorMessages__c = String.isBlank(apiCall.ErrorMessages__c) ? apiCall.Response__c : apiCall.ErrorMessages__c,
				ServiceName__c = apiCall.ServiceName__c,
				Status__c = SEL_ApiIssue.STATUS_OPEN,
				TriggeringRecordId__c = apiCall.TriggeringRecordId__c,
				ApiCall__c = apiCall.Id
		);
	}

	/**
	 * @description Whether an exception marks its call as a permanent failure, so that Retry, Retry Selected and the Flow
	 * action refuse to run the call again. That is true for a UTIL_Exceptions.PermanentFailureException, but not for a
	 * UTIL_Exceptions.RequestRefusedException. A refused request still ends Failed, and the framework never sends it again
	 * on its own. But the external system said no to it, so a person can run it again once the cause is fixed. Both
	 * directions use this one rule.
	 *
	 * @param failure The exception the call caught, or null when it caught none.
	 *
	 * @return True when the exception marks the call as a permanent failure.
	 */
	protected Boolean isPermanentFailure(Exception failure)
	{
		return failure instanceof UTIL_Exceptions.PermanentFailureException && !(failure instanceof UTIL_Exceptions.RequestRefusedException);
	}

	/**
	 * @description Saves the issue record for this failed call, when createFailureRecord gives one. The save waives
	 * field and object permissions, because the user whose call failed often has no access to issue records, and an
	 * issue the platform refuses is skipped without an error. An issue must be saved whatever access the running
	 * user has, so the failure is never lost. The framework runs this after the call's records are
	 * saved, when the call failed and its setting has Log Issues on. The HTTP client also runs it when a handler it
	 * passed a call to throws.
	 *
	 * @example
	 * ```apex
	 * protected override void logApiIssues()
	 * {
	 *     super.logApiIssues();
	 *     // more failure logging
	 * }
	 * ```
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	protected virtual void logApiIssues()
	{
		ApiIssue__c apiIssue = createFailureRecord();
		if(apiIssue != null)
		{
			DML_Builder.newTransaction().withSystemMode().doInsert(apiIssue).allowPartial().execute();
		}
	}

	/**
	 * @description Marks the open issues of an earlier failure of this request as resolved. By default it does nothing:
	 * each direction decides which issues a success closes. The framework runs this after a save of the call that
	 * succeeded, when the call succeeded and its setting has Resolve Issues on.
	 */
	@SuppressWarnings('PMD.EmptyStatementBlock')
	protected virtual void resolveApiIssues()
	{
	}

	/**
	 * @description Handles errors encountered during the service call.
	 *
	 * @param exceptionThrown The exception to handle.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global override void handleError(Exception exceptionThrown)
	 * {
	 *     super.handleError(exceptionThrown);
	 *     // custom error handling
	 * }
	 * ```
	 */
	global protected virtual void handleError(Exception exceptionThrown)
	{
		result.errors.addAll(extractErrorMessages(exceptionThrown));
		result.errors.add(exceptionThrown.getStackTraceString());
		result.hasFailed = true;
	}

	/**
	 * @description Extracts human-readable error messages from an exception.
	 * For a DML exception the platform raised for refused rows, returns the individual row-level messages; for all
	 * others, a DmlException built in code included, returns the top-level exception message.
	 *
	 * @param exceptionThrown The exception to extract messages from.
	 *
	 * @return A list of error message strings.
	 */
	private static List<String> extractErrorMessages(Exception exceptionThrown)
	{
		List<String> messages = new List<String>();
		if(exceptionThrown instanceof DmlException && exceptionThrown.getMessage()?.contains(DML_ROW_ERRORS_PHRASE) == true)
		{
			DmlException dmlError = (DmlException)exceptionThrown;
			for(Integer i = 0, rowCount = dmlError.getNumDml(); i < rowCount; i++)
			{
				messages.add(dmlError.getDmlMessage(i));
			}
		}
		else
		{
			messages.add(exceptionThrown.getMessage());
		}
		return messages;
	}

	/**
	 * @description Applies this handler's API context to the static logger.
	 * Sets the current correlation ID to the W3C trace ID when available, falling back
	 * to the handler's unique ID. This bridges distributed trace context to log entries. The call details are held under
	 * that same ID, so every line logged under it carries them.
	 */
	public void applyLoggingContext()
	{
		String loggingCorrelationId = String.isNotBlank(apiCall?.TraceId__c) ? apiCall.TraceId__c : handlerCorrelationId;
		if(loggingContextKey != loggingCorrelationId)
		{
			LOG_Engine.clearWebserviceContext(loggingContextKey);
		}
		loggingContextKey = loggingCorrelationId;

		LOG_Builder.setCorrelationId(loggingCorrelationId);
		LOG_Engine.setWebserviceContext(loggingCorrelationId, getServiceName(), result.url, toHttpString(getHttpMethod()));
		LOG_Engine.updateWebserviceContext(loggingCorrelationId, result.statusCode, calloutProcessingTime.getTime());
	}

	/**
	 * @description Removes this handler's call details from the logging engine, so lines logged after the handler is
	 * done no longer carry its endpoint, status code or callout duration. The code that runs the handler calls this once
	 * the handler's work is over, whether it succeeded or failed.
	 */
	public void clearLoggingContext()
	{
		LOG_Engine.clearWebserviceContext(loggingContextKey);
	}

	/**
	 * @description Gives this handler the call record being processed when it does not hold one yet, without saving the
	 * record. A handler that fails before its processing takes the record in hand can then still write the failure's
	 * details onto it.
	 *
	 * @param apiCallRecord The call record being processed.
	 */
	public void assignApiCallWhenMissing(ApiCall__c apiCallRecord)
	{
		apiCall = apiCall ?? apiCallRecord;
	}

	/**
	 * @description Builds the service name and HTTP method that this handler's `API_CALL` logging context carries. The code
	 * that runs the handler pushes them around each piece of the handler's work and pops them in a `finally`; creating a
	 * handler pushes nothing.
	 *
	 * @return The service name and the HTTP method, keyed by the engine's context keys.
	 */
	public Map<String, String> buildCallContext()
	{
		return new Map<String, String>
		{
				LOG_Engine.CONTEXT_SERVICE_NAME => getServiceName(),
				LOG_Engine.CONTEXT_HTTP_METHOD => toHttpString(getHttpMethod())
		};
	}

	/**
	 * @description Initializes global variables and timers. Override this method to configure
	 * DTOs, mock types, timeouts, and other service-specific settings.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global override void configure()
	 * {
	 *     super.configure();
	 *     requestPayload = new DTO_Request();
	 *     responsePayload = new DTO_Response();
	 *     defaultMockBody = '{"success": true}';
	 * }
	 * ```
	 */
	global protected virtual void configure()
	{
		fullProcessingTime.start();
		serviceProcessingTime.start();
		setUnitOfWorksObjectTypes();

		handlerCorrelationId = UTIL_Random.randomUUID();
		loggingContextKey = handlerCorrelationId;

		LOG_Engine.setWebserviceContext(handlerCorrelationId, getServiceName(), UTIL_String.EMPTY, toHttpString(getHttpMethod()));
	}

	/**
	 * @description Checks if the API is disabled for the current user.
	 * Override to add custom disable logic.
	 *
	 * @return Boolean True if the API is disabled, otherwise false.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global override Boolean isDisabled()
	 * {
	 *     return super.isDisabled() || customDisableCheck();
	 * }
	 * ```
	 */
	global protected virtual Boolean isDisabled()
	{
		return UTIL_FeatureFlag.isEnabled(FLAG_DISABLE_ALL_APIS);
	}

	/**
	 * @description Checks if this outgoing service answers mock data instead of calling the real system. There are three
	 * ways a service mocks:
	 * 1. The API Test Harness or a test turned mocking on for the service in this transaction.
	 * 2. The Mock All APIs feature flag is on for the running user.
	 * 3. The service's API Setting has Mocking Enabled ticked, and the Mock Selected APIs feature flag is on for the
	 * running user. The box alone, or the flag alone, mocks nothing.
	 * Each flag is checked for the user the transaction runs as. The check adds no query: the setting is already loaded.
	 *
	 * @return True if the service answers mock data, otherwise false.
	 */
	protected Boolean isMocking()
	{
		return API_MockFactory.isMockingEnabled(getServiceName()) || UTIL_FeatureFlag.isEnabled(FLAG_MOCK_ALL_APIS)
				|| (setting?.MockingEnabled__c == true && UTIL_FeatureFlag.isEnabled(FLAG_MOCK_SELECTED_APIS));
	}

	/**
	 * @description Performs actions after an attempt of the commit ends. It runs once for each attempt of the commit. An
	 * attempt the platform refused for a row lock is run again once, so everything here is safe to run more than once.
	 * The steps run in this order:
	 * 1. The parent class's own step for the end of an attempt runs.
	 * 2. The attempt's outcome is noted for the end of the commit. When the attempt failed, the values onDMLFinished took are dropped.
	 * 3. Only after an attempt that succeeds: a call that succeeded resolves its earlier issues, when its setting has Resolve Issues on (resolveApiIssues).
	 * 4. Only after an attempt that succeeds: a call that failed saves its issue, when its setting has Log Issues on (logApiIssues).
	 * 5. Only after an attempt that succeeds: the files that hold call data too long for its fields are created.
	 * 6. The handler's call details are removed from the logging engine.
	 * An override must call super.onCommitWorkFinished(wasSuccessful) first, before its own work: this method notes the
	 * attempt's outcome, and an override that throws before that call leaves a failed attempt unnoted.
	 *
	 * @param wasSuccessful Indicates if the attempt was successful.
	 */
	public override virtual void onCommitWorkFinished(Boolean wasSuccessful)
	{
		super.onCommitWorkFinished(wasSuccessful);
		hasLastCommitAttemptFailed = !wasSuccessful;
		if(!wasSuccessful)
		{
			savedApiCallFieldValues = null;
		}
		if(wasSuccessful && result.isSuccess && setting?.ResolveIssues__c == true)
		{
			resolveApiIssues();
		}
		if(wasSuccessful && !result.isSuccess && setting?.LogIssues__c == true)
		{
			logApiIssues();
		}
		if(wasSuccessful)
		{
			List<ContentVersion> relatedContentVersions = createRelatedContentVersions();
			if(!relatedContentVersions.isEmpty())
			{
				DML_Builder.newTransaction().systemModeInternal().doInsert(relatedContentVersions).allowPartial().execute();
			}
		}

		clearLoggingContext();
	}

	/**
	 * @description Performs actions before an attempt of the commit starts. It runs once for each attempt of the commit,
	 * and an attempt the platform refused for a row lock is run again once, so everything here is safe to run more than
	 * once: the handler's call details are given to the logging engine for the attempt. The stopwatches are not touched
	 * here; commitWork stops the service time and starts the commit time once, before the first attempt.
	 */
	public override virtual void onCommitWorkStarting()
	{
		super.onCommitWorkStarting();
		hasLastCommitAttemptFailed = false;

		applyLoggingContext();
	}

	/**
	 * @description Determines if the web service request should be aborted. Returns a list of validation error messages.
	 * Override this to add your own validation. Framework validation is handled internally
	 * by performValidation() — no super call needed.
	 *
	 * @return A list of error messages. Empty list means validation passed.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global override List<String> getValidationErrors()
	 * {
	 *     List<String> errors = new List<String>();
	 *     if(String.isBlank(apiCall.TriggeringRecordId__c))
	 *     {
	 *         errors.add('Triggering record is required');
	 *     }
	 *     return errors;
	 * }
	 * ```
	 */
	global protected virtual List<String> getValidationErrors()
	{
		return new List<String>();
	}

	/**
	 * @description Performs framework-level validation (disabled check, subscriber validation).
	 * Subclasses (API_Outbound, API_Inbound) override to add their own validation. An exception thrown by the checks in
	 * this method, getValidationErrors() among them, aborts the call and is kept in validationFailure. The extra checks
	 * an override makes do not set validationFailure: API_Outbound.performValidation (the triggering record, the
	 * required inputs, the setting and the circuit breaker) catches its own exception and leaves the field null.
	 *
	 * @return Boolean True if the request should be aborted, otherwise false.
	 */
	protected virtual Boolean performValidation()
	{
		Boolean mustAbort = false;
		try
		{
			if(isDisabled())
			{
				result.errors.add(ERROR_API_DISABLED);
				mustAbort = true;
			}

			if(!mustAbort && setting != null && !setting.IsActive__c)
			{
				result.errors.add(ERROR_API_INACTIVE);
				mustAbort = true;
			}

			if(!mustAbort && setting?.RequiredFeatureFlag__c != null && !UTIL_FeatureFlag.isEnabled(setting.RequiredFeatureFlag__r?.DeveloperName))
			{
				result.errors.add(String.format(ERROR_REQUIRED_CONDITION_NOT_MET, new List<String> {setting.RequiredFeatureFlag__r?.DeveloperName}));
				mustAbort = true;
			}

			if(!mustAbort && setting?.BypassFeatureFlag__c != null && UTIL_FeatureFlag.isEnabled(setting.BypassFeatureFlag__r?.DeveloperName))
			{
				result.errors.add(String.format(ERROR_API_BYPASSED, new List<String> {setting.BypassFeatureFlag__r?.DeveloperName}));
				mustAbort = true;
			}

			if(!mustAbort)
			{
				List<String> subscriberErrors = getValidationErrors();
				if(!subscriberErrors.isEmpty())
				{
					result.errors.addAll(subscriberErrors);
					mustAbort = true;
				}
			}
		}
		catch(Exception exceptionThrown)
		{
			validationFailure = exceptionThrown;
			handleError(exceptionThrown);
			mustAbort = true;
		}
		return mustAbort;
	}

	/**
	 * @description Main processing method for the web service.
	 *
	 * @param apiCallRecord The ApiCall__c object to update.
	 *
	 * @example
	 * ```apex
	 * global override void process(ApiCall__c apiCallRecord)
	 * {
	 *     super.process(apiCallRecord);
	 *     // custom processing logic
	 * }
	 * ```
	 */
	public virtual void process(ApiCall__c apiCallRecord)
	{
		setApiCall(apiCallRecord);
	}

	/**
	 * @description Registers database changes after a successful call.
	 * Records you register here are saved in system mode, so the running user's object and field permissions are not checked.
	 * To save with the user's permissions, use `DML_Builder.newTransaction().withUserMode()` in its own transaction.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global override void onSuccess()
	 * {
	 *     super.onSuccess();
	 *     doUpdate(updatedRecord);
	 * }
	 * ```
	 */
	@SuppressWarnings('PMD.EmptyStatementBlock')
	global protected virtual void onSuccess()
	{
	}

	/**
	 * @description Updates the API call with HTTP request/response details. Each payload (the request body, the
	 * response body, the address and the request parameters) is written by writePayload: a payload that fits its field
	 * is written as it is and the trigger masks it on the save, and a payload too long for its field is masked here, once,
	 * for this handler's class (see writePayload).
	 *
	 * @throws UTIL_Exceptions.MaskingBlockedException when a rule with FailureAction = BlockDml fails while a payload too
	 * long for its field is masked. The save is then refused, as it is when the trigger meets the same failure.
	 */
	public virtual void setApiCallDetails()
	{
		String callerClassName = getMaskingCallerClassName();
		Map<SObjectField, String> rawValuesByField = buildRawPayloadsByField();

		apiCall.ErrorMessages__c = errorText;
		apiCall.HttpMethod__c = toHttpString(getHttpMethod());
		apiCall.IsMockedResponse__c = result.isMocked ?? false;
		apiCall.NextRetry__c = null;
		apiCall.StatusCode__c = result.statusCode;
		apiCall.Status__c = result.statusText;
		for(SObjectField field : PAYLOAD_FIELDS)
		{
			writePayload(field, rawValuesByField.get(field), callerClassName);
		}
		apiCall.RequestParameters__c = UTIL_String.EMPTY_JSON_RESPONSE.equals(apiCall.RequestParameters__c) ? null : apiCall.RequestParameters__c;

		if(currentTraceContext != null)
		{
			apiCall.TraceId__c = currentTraceContext.traceId;
			apiCall.ParentSpanId__c = currentTraceContext.parentSpanId;
		}
	}

	/**
	 * @description Writes one payload to its field on the call record. A payload that fits its field, or any payload
	 * while masking is switched off, is written as it is, and the trigger masks it on the save. A payload too long for
	 * its field is masked here, once, for this handler's class, so it is never masked again on the save or for its
	 * file:
	 *
	 * 1. The masker returns both the masked text that fits the field and the whole masked text (see
	 *    UTIL_FrameworkMasker.FieldMasker.maskAndReturnWholeText). The whole text comes straight from the masker, so a
	 *    payload of any length keeps all of it. The masking is timed by a UTIL_MaskerPerformanceTimer named after the
	 *    field (for example ApiCall__c.Request__c), so a performance entry shows each time a payload is masked here.
	 * 2. The field gets the masked text, cut to fit with three dots at the end when it is still too long.
	 * 3. The raw payload, the field text and, when it is too long for the field, the whole masked text are kept in
	 *    maskedPayloadsByField. createRelatedContentVersions saves the whole text in a file.
	 * 4. The text written to the field is registered with the masker for this field and caller, so the trigger leaves
	 *    it as it is on the insert and on the update after the callout.
	 *
	 * When this handler already masked the same raw payload for this field, here or in the file step, the kept field
	 * text is written and nothing is masked again: the inbound commit writes the call details before and after its
	 * statements, a commit refused for a row lock runs again, and a failed call writes them once more.
	 *
	 * The raw payload, cut to fit, is written before the masking runs. When a rule set to block DML fails, the masking
	 * throws, and that text stays in the field: it is not registered, so the trigger masks it on any later save, meets
	 * the same rule and refuses the save.
	 *
	 * @param field The payload field.
	 * @param rawValue The raw payload; may be null.
	 * @param callerClassName The handler class to mask for; empty for no caller.
	 *
	 * @throws UTIL_Exceptions.MaskingBlockedException when a rule with FailureAction = BlockDml fails
	 */
	private void writePayload(SObjectField field, String rawValue, String callerClassName)
	{
		MaskedPayload knownPayload = findMaskedPayload(field, rawValue);
		if(knownPayload != null)
		{
			apiCall.put(field, knownPayload.fieldText);
			return;
		}

		maskedPayloadsByField.remove(field);
		apiCall.put(field, UTIL_String.abbreviate(rawValue, field));
		if(!UTIL_FrameworkMasker.isMaskingEnabled || !isLongerThanField(rawValue, field))
		{
			return;
		}

		UTIL_MaskerPerformanceTimer timer = new UTIL_MaskerPerformanceTimer(UTIL_SObjectDescribe.getObjectNameFromType(ApiCall__c.SObjectType) + UTIL_String.DOT
				+ UTIL_SObjectDescribe.getCachedFieldName(field), 1);
		timer.start();
		UTIL_FrameworkMasker.MaskingResult masked = UTIL_FrameworkMasker.forField(field).calledFrom(callerClassName).maskAndReturnWholeText(rawValue);
		timer.stop();

		String wholeMaskedText = masked.uncutMaskedValue ?? masked.maskedValue;
		String fieldText = UTIL_String.abbreviate(masked.maskedValue, field);
		maskedPayloadsByField.put(field, new MaskedPayload(rawValue, fieldText, isLongerThanField(wholeMaskedText, field) ? wholeMaskedText : null));
		apiCall.put(field, fieldText);
		UTIL_FrameworkMasker.registerMaskedFieldText(field, callerClassName, fieldText);
	}

	/**
	 * @description Builds the call record to save after the handler's own commit: the save that writes the timings,
	 * and the outcome when the call failed after the commit. When the handler's commit saved the record, it is a new
	 * record with the Id and only the fields whose values changed since that commit, so a payload saved on the commit,
	 * and masked then, is not sent again and the trigger has nothing new to mask. Otherwise it is the handler's own
	 * record, with every field: a record that is not saved yet must be inserted whole, and a record whose commit failed
	 * holds values that are not saved yet.
	 *
	 * @return The record to save.
	 */
	public ApiCall__c buildApiCallChangesToSave()
	{
		if(apiCall?.Id == null || savedApiCallFieldValues == null)
		{
			return apiCall;
		}

		ApiCall__c changes = new ApiCall__c(Id = apiCall.Id);
		Map<String, Object> currentValues = apiCall.getPopulatedFieldsAsMap();
		for(String fieldName : currentValues.keySet())
		{
			Object currentValue = currentValues.get(fieldName);
			if(!(currentValue instanceof SObject) && !(currentValue instanceof List<SObject>) && hasFieldChangedSinceSave(fieldName, currentValue))
			{
				changes.put(fieldName, currentValue);
			}
		}
		return changes;
	}

	/**
	 * @description Checks whether a field of the call record holds a value other than the one the handler's commit
	 * saved. Text is compared with its letter case, so a change of case counts as a change.
	 *
	 * @param fieldName The field's API name.
	 * @param currentValue The field's value now.
	 *
	 * @return True when the field was not saved by the commit or now holds another value.
	 */
	private Boolean hasFieldChangedSinceSave(String fieldName, Object currentValue)
	{
		if(!savedApiCallFieldValues.containsKey(fieldName))
		{
			return true;
		}
		Object savedValue = savedApiCallFieldValues.get(fieldName);
		if(currentValue instanceof String && savedValue instanceof String)
		{
			return !((String)currentValue).equals(savedValue);
		}
		return currentValue != savedValue;
	}

	/**
	 * @description Takes the values of the call record's fields as the commit's statements wrote them, for
	 * buildApiCallChangesToSave. Nothing is taken when the handler does not save the record (skipPersistence), in safe
	 * mode (the commit is rolled back) or when the record has no Id.
	 */
	private void rememberSavedApiCallFields()
	{
		if(!skipPersistence && !isSafeModeActive() && apiCall?.Id != null)
		{
			savedApiCallFieldValues = new Map<String, Object>(apiCall.getPopulatedFieldsAsMap());
		}
	}

	/**
	 * @description Runs after the commit has written its records to the database, and before onCommitWorkFinishing and
	 * onCommitWorkFinished. It keeps a copy of the call record's field values as they were written. The call record is
	 * saved once more after the commit, to write the timings and the outcome. Because of the copy, that second save sends
	 * only the fields that changed after the commit, such as the response the inbound commit writes in
	 * onCommitWorkFinishing. When an attempt fails after this point, the copy is dropped again. Your handler class may
	 * override this method. Your override must call super.onDMLFinished() first. If it does not, the second save sends
	 * the whole call record again.
	 *
	 * @since 1.9
	 *
	 * @example
	 * ```apex
	 * global override void onDMLFinished()
	 * {
	 *     super.onDMLFinished();
	 *     // your own work, after the commit has written its records
	 * }
	 * ```
	 */
	global override virtual void onDMLFinished()
	{
		super.onDMLFinished();
		rememberSavedApiCallFields();
	}

	/**
	 * @description Sets the API call and registers it for database changes.
	 * When skipPersistence is true, the record is assigned but not registered for DML.
	 *
	 * @param apiCallRecord The ApiCall__c object to set.
	 */
	protected virtual void setApiCall(ApiCall__c apiCallRecord)
	{
		this.apiCall = apiCallRecord;
		if(!skipPersistence)
		{
			doSave(this.apiCall);
		}
	}

	/**
	 * @description Defines valid SObject types for the unit of work.
	 */
	@SuppressWarnings('PMD.EmptyStatementBlock')
	protected virtual void setUnitOfWorksObjectTypes()
	{
	}

	/**
	 * @description Enum representing the status of a web service call.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * API_Base.WebserviceStatus status = API_Base.WebserviceStatus.COMPLETED;
	 * ```
	 */
	global enum WebserviceStatus
	{
		/**
		 * @description The web service call completed successfully.
		 */
		COMPLETED,

		/**
		 * @description The web service call failed with an error.
		 */
		FAILED,

		/**
		 * @description The web service call was aborted before execution.
		 */
		ABORTED
	}

	/**
	 * @description Enters Safe Mode. Returns a context that must be closed via try/finally.
	 * When Safe Mode is active, DML is wrapped in savepoint with guaranteed rollback.
	 *
	 * @return A new SafeModeContext that must be closed
	 *
	 * @example
	 * ```apex
	 * API_Base.SafeModeContext safeMode = API_Base.enterSafeMode();
	 * try
	 * {
	 *     API_Dispatcher.processInboundService('API_MyHandler');
	 * }
	 * finally
	 * {
	 *     safeMode.close();
	 * }
	 * ```
	 */
	public static SafeModeContext enterSafeMode()
	{
		return new SafeModeContext();
	}

	/**
	 * @description Checks if Safe Mode is currently active.
	 *
	 * @return True if any Safe Mode scope is active
	 */
	public static Boolean isSafeModeActive()
	{
		return safeModeActiveScopeCount > 0;
	}

	/**
	 * @description Context manager for Safe Mode execution.
	 * Provides automatic cleanup via try/finally pattern and prevents cross-contamination
	 * in batch scenarios where multiple handlers execute in one transaction.
	 */
	public inherited sharing class SafeModeContext
	{
		/**
		 * @description Whether this context has already been closed.
		 */
		private Boolean isClosed = false;

		/**
		 * @description Creates and activates a new Safe Mode scope.
		 */
		private SafeModeContext()
		{
			safeModeActiveScopeCount++;
		}

		/**
		 * @description Closes the Safe Mode scope. Idempotent — safe to call multiple times.
		 * Must be called in finally block.
		 */
		public void close()
		{
			if(isClosed)
			{
				return;
			}
			isClosed = true;
			if(safeModeActiveScopeCount > 0)
			{
				safeModeActiveScopeCount--;
			}
		}
	}

	/**
	 * @description Commits all registered DML operations.
	 * When Safe Mode is active, wraps execution in savepoint with guaranteed rollback.
	 */
	public override void commitWork()
	{
		commitWork(null);
	}

	/**
	 * @description Commits all registered DML operations with optional sharing enforcement.
	 * When Safe Mode is active, wraps execution in savepoint with guaranteed rollback. Every attempt empties the
	 * transaction's in-memory query cache before its first statement and again when it ends, whatever the outcome, and
	 * safe mode empties it once more after its rollback, so no read after a write is served rows from before it or from
	 * a write that was rolled back. The work that belongs to the commit as a whole happens here, once, however many
	 * attempts the commit takes: the service time is stopped and the commit time started before the first attempt, and
	 * the commit time is stopped when the commit ends, so it covers every attempt. The commit time is stopped only when it
	 * was started: a commit refused before that point fails with its own exception, never with a second one raised by
	 * stopping a stopwatch that is not running. When the commit fails for good, the Id of a call record that was new when
	 * the commit began is cleared, because the insert that gave it the Id was rolled back. A call record that was already
	 * saved when the commit began keeps its Id whatever happens, because the Id still names its row: the next attempt
	 * updates that row, and after a commit that fails for good the failure is written to that same row. The values the
	 * commit wrote to the call record are taken right after its statements, for buildApiCallChangesToSave (see
	 * onDMLFinished).
	 *
	 * @param enforceSharing Whether to enforce sharing rules during commit
	 */
	public override void commitWork(Boolean enforceSharing)
	{
		Boolean isNewCallRecord = apiCall?.Id == null;
		Boolean hasCommitTimeStarted = false;
		try
		{
			serviceProcessingTime.stop();
			commitProcessingTime.start();
			hasCommitTimeStarted = true;

			if(isSafeModeActive())
			{
				SavePoint safeModeCheckpoint = Database.setSavepoint();
				try
				{
					super.commitWork(enforceSharing);
				}
				finally
				{
					Database.rollback(safeModeCheckpoint);
					// Safe mode rolls back a commit that succeeded, so rows cached during it describe a write that no longer exists.
					QRY_Engine.clearQueryResultMemoryCache();
				}
			}
			else
			{
				super.commitWork(enforceSharing);
			}
		}
		finally
		{
			if(hasLastCommitAttemptFailed && isNewCallRecord)
			{
				apiCall.Id = null;
			}
			if(hasCommitTimeStarted)
			{
				commitProcessingTime.stop();
			}
		}
	}

	/**
	 * @description Tracks the request, response, and status of a web service call.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * API_Base.ServiceCallResult result = handler.result;
	 * Boolean success = result.isSuccess;
	 * ```
	 */
	global inherited sharing class ServiceCallResult
	{
		/**
		 * @description List of errors encountered during the service call.
		 *
		 * @since 1.0
		 */
		global List<String> errors = new List<String>();

		/**
		 * @description The request body sent.
		 *
		 * @since 1.0
		 */
		global String requestBody;

		/**
		 * @description The response body received.
		 *
		 * @since 1.0
		 */
		global String responseBody;

		/**
		 * @description The HTTP status code for the request.
		 *
		 * @since 1.0
		 */
		global String statusCode;

		/**
		 * @description The URL of the endpoint accessed.
		 *
		 * @since 1.0
		 */
		global String url;

		/**
		 * @description The status of the web service call.
		 *
		 * @since 1.0
		 */
		global WebserviceStatus status;

		/**
		 * @description Indicates if the service call response was mocked.
		 *
		 * @since 1.0
		 */
		global Boolean isMocked;

		/**
		 * @description Indicates the response was successfully received from the remote
		 * endpoint but `parseResponse()` failed (typically a JSON deserialization error
		 * or unexpected payload shape). When `true` the transport itself succeeded — the
		 * status code and body are populated — but `responsePayload` is unreliable.
		 * Check this flag in your code to tell a parse failure from a transport failure
		 * without inspecting `errors[]` strings.
		 *
		 * @since 1.0
		 */
		global Boolean parseError = false;

		/**
		 * @description Request headers as name-value pairs.
		 *
		 * @since 1.0
		 */
		global DTO_NameValues requestHeaders = new DTO_NameValues();

		/**
		 * @description Response headers as name-value pairs.
		 *
		 * @since 1.0
		 */
		global DTO_NameValues responseHeaders = new DTO_NameValues();

		/**
		 * @description Text representation of the service status.
		 *
		 * @since 1.0
		 */
		global String statusText
		{
			get
			{
				switch on status
				{
					when COMPLETED
					{
						return 'Completed';
					}
					when FAILED
					{
						return 'Failed';
					}
					when ABORTED
					{
						return 'Aborted';
					}
					when else
					{
						return String.valueOf(status);
					}
				}
			}
		}

		/**
		 * @description True when the call's status is FAILED. Setting it to true marks the status FAILED; setting it
		 * to false leaves the status as it is.
		 *
		 * @since 1.0
		 */
		global Boolean hasFailed
		{
			get
			{
				return status == API_Base.WebserviceStatus.FAILED;
			}
			set
			{
				status = value == true ? API_Base.WebserviceStatus.FAILED : status;
			}
		}

		/**
		 * @description Indicates if the service call completed successfully.
		 *
		 * @since 1.0
		 */
		global Boolean isSuccess
		{
			get
			{
				return status == API_Base.WebserviceStatus.COMPLETED;
			}
			set
			{
				status = value == true ? API_Base.WebserviceStatus.COMPLETED : status;
			}
		}

		/**
		 * @description Indicates if the service call was aborted.
		 *
		 * @since 1.0
		 */
		global Boolean isAborted
		{
			get
			{
				return status == API_Base.WebserviceStatus.ABORTED;
			}
			set
			{
				status = value == true ? API_Base.WebserviceStatus.ABORTED : status;
			}
		}
	}

	/**
	 * @description What this handler masked for one payload field: the raw payload, the masked text written to the
	 * field and, until the file step takes it, the whole masked text when it is too long for the field (see
	 * maskedPayloadsByField).
	 */
	private inherited sharing class MaskedPayload
	{
		/**
		 * @description The raw payload that was masked.
		 */
		private final String rawValue;

		/**
		 * @description The masked text written to the field, cut to fit.
		 */
		private final String fieldText;

		/**
		 * @description The whole masked text when it is too long for the field and no file holds it yet; null
		 * otherwise. The file step takes it once and sets it to null.
		 */
		private String wholeMaskedText;

		/**
		 * @description Keeps a raw payload with its masked texts.
		 *
		 * @param rawValue The raw payload that was masked.
		 * @param fieldText The masked text written to the field.
		 * @param wholeMaskedText The whole masked text when it is too long for the field; null otherwise.
		 */
		private MaskedPayload(String rawValue, String fieldText, String wholeMaskedText)
		{
			this.rawValue = rawValue;
			this.fieldText = fieldText;
			this.wholeMaskedText = wholeMaskedText;
		}
	}

	/**
	 * @description W3C Trace Context for distributed tracing across API calls.
	 */
	public inherited sharing class TraceContext
	{
		/**
		 * @description The 32-hex-character trace ID.
		 */
		public String traceId;

		/**
		 * @description The 16-hex-character span ID for this operation.
		 */
		public String spanId;

		/**
		 * @description The parent span ID (from incoming Trace Parent header).
		 */
		public String parentSpanId;

		/**
		 * @description Formats as W3C Trace Parent header value.
		 *
		 * @return Formatted Trace Parent header (e.g., '00-traceId-spanId-01')
		 */
		public String toHeader()
		{
			return TRACE_PARENT_VERSION + '-' + traceId + '-' + spanId + '-' + TRACE_PARENT_FLAGS_SAMPLED;
		}

		/**
		 * @description Creates a child context for an outbound call within the same trace.
		 *
		 * @return New context with same trace ID but new span ID
		 */
		public TraceContext createChildSpan()
		{
			TraceContext child = new TraceContext();
			child.traceId = this.traceId;
			child.parentSpanId = this.spanId;
			child.spanId = UTIL_Random.random(SPAN_ID_LENGTH, HEX_CHARACTERS);
			return child;
		}
	}

	/**
	 * @description Generates a new trace context with random IDs and sets it as current.
	 *
	 * @return New trace context instance
	 */
	public static TraceContext generateTraceContext()
	{
		TraceContext context = new TraceContext();
		context.traceId = UTIL_Random.random(TRACE_ID_LENGTH, HEX_CHARACTERS);
		context.spanId = UTIL_Random.random(SPAN_ID_LENGTH, HEX_CHARACTERS);
		currentTraceContext = context;
		return context;
	}

	/**
	 * @description Parses a W3C Trace Parent header value, following the W3C Trace Context standard. Validates the
	 * header format: version (2 hex), trace-id (32 hex, not all zeros), parent-id (16 hex, not all zeros), and
	 * trace-flags (2 hex). An invalid header is logged as a warning and a new context is generated instead: the API
	 * call is never aborted because of a malformed trace header.
	 *
	 * @param headerValue The Trace Parent header value (e.g., '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01')
	 *
	 * @return Parsed trace context, or new context if header is invalid
	 *
	 * @see https://www.w3.org/TR/trace-context/#traceparent-header
	 */
	public static TraceContext parseTraceParentHeader(String headerValue)
	{
		if(String.isNotBlank(headerValue))
		{
			List<String> parts = headerValue.split('-');

			if(parts.size() == TRACE_PARENT_PARTS && isValidTraceParent(parts))
			{
				TraceContext context = new TraceContext();
				context.traceId = parts[1];
				context.parentSpanId = parts[2];
				context.spanId = UTIL_Random.random(SPAN_ID_LENGTH, HEX_CHARACTERS);
				currentTraceContext = context;
				return context;
			}

			LOG_Builder.build().warn('Invalid Trace Parent header ignored: ' + headerValue).emitAt(API_Base.class.getName() + '.parseTraceParentHeader');
		}

		return generateTraceContext();
	}

	/**
	 * @description Validates the parts of a W3C Trace Parent header against the W3C Trace Context standard.
	 * Checks field lengths, lowercase hex character format, and rejects all-zeros trace-id and parent-id.
	 *
	 * @param parts The split traceparent header parts (version, trace-id, parent-id, trace-flags)
	 *
	 * @return True if all parts are valid under the W3C Trace Context standard
	 */
	private static Boolean isValidTraceParent(List<String> parts)
	{
		String traceId = parts[1];
		String parentId = parts[2];

		return traceId.length() == TRACE_ID_LENGTH
				&& parentId.length() == SPAN_ID_LENGTH
				&& traceId != INVALID_TRACE_ID
				&& parentId != INVALID_PARENT_ID
				&& HEX_PATTERN.matcher(traceId + parentId).matches();
	}

	/**
	 * @description Returns the current trace context, generating one if none exists.
	 *
	 * @return Current trace context
	 */
	public static TraceContext currentOrNewTraceContext()
	{
		if(currentTraceContext == null)
		{
			generateTraceContext();
		}

		return currentTraceContext;
	}

	/**
	 * @description Clears the thread-local trace context. Called at end of request processing.
	 */
	public static void clearTraceContext()
	{
		currentTraceContext = null;
	}

}