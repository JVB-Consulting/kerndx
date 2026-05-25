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
 * @date February 2026, May 2026
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
@SuppressWarnings('PMD.AvoidGlobalModifier,PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.ExcessiveClassLength,PMD.AvoidBooleanMethodParameters')
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
	@TestVisible
	private static final String FLAG_DISABLE_ALL_APIS = 'DisableAllAPIs';

	/**
	 * @description Feature flag name for mocking all API calls.
	 */
	@TestVisible
	private static final String FLAG_MOCK_ALL_APIS = 'MockAllAPIs';

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
	 * @description Flag tracking whether the setting query has been executed.
	 */
	@TestVisible
	private Boolean settingQueryRun = false;

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
	 * @description Invalid all-zeros trace ID per W3C Trace Context specification.
	 */
	private static final String INVALID_TRACE_ID = '00000000000000000000000000000000';
	/**
	 * @description Invalid all-zeros parent ID per W3C Trace Context specification.
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
	 * @description HTTP status code for too many requests (429).
	 */
	public static final Integer HTTP_TOO_MANY_REQUESTS = 429;

	/**
	 * @description HTTP status code for internal server error (500).
	 */
	public static final Integer HTTP_INTERNAL_SERVER_ERROR = 500;

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
	 * @description Base constructor. Pins the transaction's `AccessLevel` to `SYSTEM_MODE` because
	 * `API_Base` extends `DML_Transaction` and its UnitOfWork is dominated by framework-owned audit
	 * DML (`ApiCall__c` save, `ApiIssue__c` create on failure, `ContentVersion` attachments) that
	 * must succeed regardless of whether the running user holds CRUD on those framework objects.
	 * Without this pin the audit trail would disappear silently any time a subscriber API invocation
	 * runs as a non-admin who lacks CRUD on `ApiCall__c` — a failure mode we explicitly guard against.
	 * Subscriber services whose `onSuccess()` / `populate()` code does user-mode DML opt in per-call
	 * via `DML_Builder.newTransaction().withUserMode()...execute()` rather than registering with this
	 * inherited UoW.
	 */
	@SuppressWarnings('ApexUnusedDeclaration,RedundantSuppression')
	public API_Base()
	{
		setAccessLevel(System.AccessLevel.SYSTEM_MODE);
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
	 * @return A list of uncommitted ContentVersion records, empty if no fields exceed limits.
	 */
	public List<ContentVersion> createRelatedContentVersions()
	{
		List<ContentVersion> versions = new List<ContentVersion>();

		String maskedRequestBody = maskContent(ApiCall__c.Request__c, result.requestBody);
		String maskedResponseBody = maskContent(ApiCall__c.Response__c, result.responseBody);
		String maskedUrl = maskContent(ApiCall__c.URL__c, result.url);
		String maskedParameters = maskContent(ApiCall__c.RequestParameters__c, inputs.serialize());

		if(shouldStoreAsFile(maskedRequestBody, SEL_ApiCall.REQUEST_LENGTH))
		{
			versions.add(TST_Factory.newContentVersion(apiCall.Id, 'RequestBody' + SEL_ContentVersion.TEXT_FILE_EXTENSION, Blob.valueOf(maskedRequestBody)));
		}
		if(shouldStoreAsFile(maskedResponseBody, SEL_ApiCall.RESPONSE_LENGTH))
		{
			versions.add(TST_Factory.newContentVersion(apiCall.Id, 'ResponseBody' + SEL_ContentVersion.TEXT_FILE_EXTENSION, Blob.valueOf(maskedResponseBody)));
		}
		if(shouldStoreAsFile(maskedUrl, SEL_ApiCall.URL_LENGTH))
		{
			versions.add(TST_Factory.newContentVersion(apiCall.Id, 'Url' + SEL_ContentVersion.TEXT_FILE_EXTENSION, Blob.valueOf(maskedUrl)));
		}
		if(shouldStoreAsFile(maskedParameters, SEL_ApiCall.REQUEST_PARAMETERS_LENGTH))
		{
			versions.add(TST_Factory.newContentVersion(apiCall.Id, 'RequestParameters' + SEL_ContentVersion.TEXT_FILE_EXTENSION, Blob.valueOf(maskedParameters)));
		}
		return versions;
	}

	/**
	 * @description Runs the MaskingTarget rules configured for one ApiCall__c field against an
	 * arbitrary string. Lets ContentVersion blobs inherit the same redaction the persisted
	 * ApiCall record gets from its before-insert trigger action.
	 *
	 * @param field The ApiCall__c SObjectField whose rules to apply
	 * @param value The string content to redact
	 *
	 * @return The redacted string, or the original value when masking is disabled or the input is blank
	 */
	private static String maskContent(SObjectField field, String value)
	{
		if(!UTIL_FrameworkMasker.isMaskingEnabled || String.isEmpty(value))
		{
			return value;
		}
		return UTIL_FrameworkMasker.forField(field).mask(value).maskedValue;
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
	 * @description Returns the current service name.
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
	 * For DML exceptions, returns the individual row-level messages; for all others,
	 * returns the top-level exception message.
	 *
	 * @param exceptionThrown The exception to extract messages from.
	 *
	 * @return A list of error message strings.
	 */
	private static List<String> extractErrorMessages(Exception exceptionThrown)
	{
		List<String> messages = new List<String>();
		if(exceptionThrown instanceof DmlException)
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
	 * to the handler's unique ID. This bridges distributed trace context to log entries.
	 */
	public void applyLoggingContext()
	{
		LOG_Builder.setCorrelationId(String.isNotBlank(apiCall?.TraceId__c) ? apiCall.TraceId__c : handlerCorrelationId);
		LOG_Engine.setWebserviceContext(handlerCorrelationId, getServiceName(), result.url, toHttpString(getHttpMethod()));
		LOG_Engine.updateWebserviceContext(handlerCorrelationId, result.statusCode, calloutProcessingTime.getTime());
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

		LOG_Engine.setWebserviceContext(handlerCorrelationId, getServiceName(), UTIL_String.EMPTY, toHttpString(getHttpMethod()));

		LOG_Engine.pushOperationContext(LOG_Engine.OperationType.API_CALL, new Map<String, String>
		{
				LOG_Engine.CONTEXT_SERVICE_NAME => getServiceName(),
				LOG_Engine.CONTEXT_HTTP_METHOD => toHttpString(getHttpMethod())
		});
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
	 * @description Checks if the API is set to return mock responses.
	 *
	 * @return Boolean True if mocking is enabled, otherwise false.
	 */
	protected Boolean isMocking()
	{
		return API_MockFactory.isMockingEnabled(getServiceName()) || UTIL_FeatureFlag.isEnabled(FLAG_MOCK_ALL_APIS);
	}

	/**
	 * @description Performs actions after unit of work DML operations.
	 *
	 * @param wasSuccessful Indicates if the commit was successful.
	 */
	public override virtual void onCommitWorkFinished(Boolean wasSuccessful)
	{
		super.onCommitWorkFinished(wasSuccessful);
		if(wasSuccessful)
		{
			List<ContentVersion> relatedContentVersions = createRelatedContentVersions();
			if(!relatedContentVersions.isEmpty())
			{
				DML_Builder.newTransaction().withSystemMode().doInsert(relatedContentVersions).allowPartial().execute();
			}
		}
		else
		{
			apiCall.Id = null;
		}
		commitProcessingTime.stop();

		LOG_Engine.popOperationContext();
		LOG_Engine.clearWebserviceContext(handlerCorrelationId);
	}

	/**
	 * @description Performs actions before unit of work DML operations.
	 */
	public override virtual void onCommitWorkStarting()
	{
		super.onCommitWorkStarting();
		serviceProcessingTime.stop();
		commitProcessingTime.start();

		applyLoggingContext();
	}

	/**
	 * @description Determines if the web service request should be aborted. Returns a list of validation error messages.
	 * Subscribers override this to add custom validation. Framework validation is handled internally
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
	 * Subclasses (API_Outbound, API_Inbound) override to add their own validation.
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
	 * @description Updates the API call with HTTP request/response details.
	 */
	public virtual void setApiCallDetails()
	{
		apiCall.ErrorMessages__c = errorText;
		apiCall.HttpMethod__c = toHttpString(getHttpMethod());
		apiCall.IsMockedResponse__c = result.isMocked ?? false;
		apiCall.NextRetry__c = null;
		apiCall.RequestParameters__c = UTIL_String.abbreviate(inputs.serialize(), ApiCall__c.RequestParameters__c);
		apiCall.RequestParameters__c = UTIL_String.EMPTY_JSON_RESPONSE.equals(apiCall.RequestParameters__c) ? null : apiCall.RequestParameters__c;
		apiCall.Request__c = UTIL_String.abbreviate(result.requestBody, ApiCall__c.Request__c);
		apiCall.Response__c = UTIL_String.abbreviate(result.responseBody, ApiCall__c.Response__c);
		apiCall.StatusCode__c = result.statusCode;
		apiCall.Status__c = result.statusText;
		apiCall.URL__c = UTIL_String.abbreviate(result.url, ApiCall__c.URL__c);

		if(currentTraceContext != null)
		{
			apiCall.TraceId__c = currentTraceContext.traceId;
			apiCall.ParentSpanId__c = currentTraceContext.parentSpanId;
		}
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
	 * When Safe Mode is active, wraps execution in savepoint with guaranteed rollback.
	 *
	 * @param enforceSharing Whether to enforce sharing rules during commit
	 */
	public override void commitWork(Boolean enforceSharing)
	{
		if(isSafeModeActive())
		{
			Savepoint safeModeCheckpoint = Database.setSavepoint();
			try
			{
				super.commitWork(enforceSharing);
			}
			finally
			{
				Database.rollback(safeModeCheckpoint);
			}
		}
		else
		{
			super.commitWork(enforceSharing);
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
		 * Subscribers branch on this to distinguish parse failure from transport failure
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
		 * @description Indicates if the service call failed.
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
	 * @description Parses a W3C Trace Parent header value per the W3C Trace Context specification.
	 * Validates the header format: version (2 hex), trace-id (32 hex, not all zeros),
	 * parent-id (16 hex, not all zeros), and trace-flags (2 hex).
	 * Invalid headers are logged as warnings and a new context is generated instead — the API
	 * call is never aborted due to a malformed trace header.
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
	 * @description Validates the parts of a W3C Trace Parent header against the specification.
	 * Checks field lengths, lowercase hex character format, and rejects all-zeros trace-id and parent-id.
	 *
	 * @param parts The split traceparent header parts (version, trace-id, parent-id, trace-flags)
	 *
	 * @return True if all parts are valid per the W3C Trace Context specification
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