// Section 20: Flow Logger Invocables — Start/Log/End Lifecycle
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Prerequisites:
//   - kern managed package installed
//
// Tests FLOW_LoggerStart, FLOW_LoggerLog, FLOW_LoggerEnd, and FLOW_WriteLog
// from subscriber code — the same invocable methods that Flows call.
//
// Run:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-20-flow-logger.apex

try
{
	// Test 20a: FLOW_LoggerStart — start correlation
	{
		kern.FLOW_LoggerStart.DTO_Request request = new kern.FLOW_LoggerStart.DTO_Request();
		request.flowName = 'SubscriberTestFlow';
		request.additionalContext = 'Integration test from subscriber org';

		List<kern.FLOW_LoggerStart.DTO_Response> responses = kern.FLOW_LoggerStart.execute(
				new List<kern.FLOW_LoggerStart.DTO_Request> {request}
		);

		System.assert(responses != null && !responses.isEmpty(), '20a FAIL: Should return responses');
		String correlationId = responses[0].correlationId;
		System.assert(String.isNotBlank(correlationId), '20a FAIL: Correlation ID should be non-blank');
		System.debug('20a PASS: FLOW_LoggerStart returned correlation ID: ' + correlationId);
	}

	// Test 20b: FLOW_LoggerStart — with record ID context
	{
		kern.TRG_Base.bypass(Schema.Account.SObjectType);
		Account testAccount = new Account(Name = 'Logger Test 20b', Industry = 'Technology');
		insert testAccount;

		kern.FLOW_LoggerStart.DTO_Request request = new kern.FLOW_LoggerStart.DTO_Request();
		request.flowName = 'AccountProcessFlow';
		request.recordId = testAccount.Id;
		request.additionalContext = 'Processing account record';

		List<kern.FLOW_LoggerStart.DTO_Response> responses = kern.FLOW_LoggerStart.execute(
				new List<kern.FLOW_LoggerStart.DTO_Request> {request}
		);

		System.assert(String.isNotBlank(responses[0].correlationId), '20b FAIL: Correlation ID should be set');

		delete testAccount;
		kern.TRG_Base.clearAllBypasses();
		System.debug('20b PASS: FLOW_LoggerStart with record ID context');
	}

	// Test 20c: FLOW_LoggerLog — log event with correlation
	{
		// Start a correlation first
		kern.FLOW_LoggerStart.DTO_Request startRequest = new kern.FLOW_LoggerStart.DTO_Request();
		startRequest.flowName = 'LogEventTestFlow';
		List<kern.FLOW_LoggerStart.DTO_Response> startResponses = kern.FLOW_LoggerStart.execute(
				new List<kern.FLOW_LoggerStart.DTO_Request> {startRequest}
		);
		String correlationId = startResponses[0].correlationId;

		// Log an event
		kern.FLOW_LoggerLog.DTO_Request logRequest = new kern.FLOW_LoggerLog.DTO_Request();
		logRequest.correlationId = correlationId;
		logRequest.message = 'Processing step completed';
		logRequest.logLevel = 'INFO';
		logRequest.flowStep = 'ValidationStep';

		kern.FLOW_LoggerLog.execute(new List<kern.FLOW_LoggerLog.DTO_Request> {logRequest});
		System.debug('20c PASS: FLOW_LoggerLog logged event with correlation and flow step');
	}

	// Test 20d: FLOW_LoggerLog — all log levels
	{
		kern.FLOW_LoggerStart.DTO_Request startRequest = new kern.FLOW_LoggerStart.DTO_Request();
		startRequest.flowName = 'LevelTestFlow';
		List<kern.FLOW_LoggerStart.DTO_Response> startResponses = kern.FLOW_LoggerStart.execute(
				new List<kern.FLOW_LoggerStart.DTO_Request> {startRequest}
		);
		String correlationId = startResponses[0].correlationId;

		for(String level : new List<String> {'DEBUG', 'INFO', 'WARN', 'ERROR'})
		{
			kern.FLOW_LoggerLog.DTO_Request logRequest = new kern.FLOW_LoggerLog.DTO_Request();
			logRequest.correlationId = correlationId;
			logRequest.message = 'Test message at ' + level + ' level';
			logRequest.logLevel = level;
			logRequest.flowStep = 'Step_' + level;
			kern.FLOW_LoggerLog.execute(new List<kern.FLOW_LoggerLog.DTO_Request> {logRequest});
		}

		System.debug('20d PASS: FLOW_LoggerLog accepted all 4 log levels');
	}

	// Test 20e: FLOW_LoggerEnd — success
	{
		kern.FLOW_LoggerStart.DTO_Request startRequest = new kern.FLOW_LoggerStart.DTO_Request();
		startRequest.flowName = 'SuccessFlow';
		List<kern.FLOW_LoggerStart.DTO_Response> startResponses = kern.FLOW_LoggerStart.execute(
				new List<kern.FLOW_LoggerStart.DTO_Request> {startRequest}
		);

		kern.FLOW_LoggerEnd.DTO_Request endRequest = new kern.FLOW_LoggerEnd.DTO_Request();
		endRequest.correlationId = startResponses[0].correlationId;
		endRequest.flowName = 'SuccessFlow';
		endRequest.success = true;

		kern.FLOW_LoggerEnd.execute(new List<kern.FLOW_LoggerEnd.DTO_Request> {endRequest});
		System.debug('20e PASS: FLOW_LoggerEnd completed with success=true');
	}

	// Test 20f: FLOW_LoggerEnd — failure with error message
	{
		kern.FLOW_LoggerStart.DTO_Request startRequest = new kern.FLOW_LoggerStart.DTO_Request();
		startRequest.flowName = 'FailureFlow';
		List<kern.FLOW_LoggerStart.DTO_Response> startResponses = kern.FLOW_LoggerStart.execute(
				new List<kern.FLOW_LoggerStart.DTO_Request> {startRequest}
		);

		kern.FLOW_LoggerEnd.DTO_Request endRequest = new kern.FLOW_LoggerEnd.DTO_Request();
		endRequest.correlationId = startResponses[0].correlationId;
		endRequest.flowName = 'FailureFlow';
		endRequest.success = false;
		endRequest.errorMessage = 'Required field missing: Account Name';

		kern.FLOW_LoggerEnd.execute(new List<kern.FLOW_LoggerEnd.DTO_Request> {endRequest});
		System.debug('20f PASS: FLOW_LoggerEnd completed with success=false and error message');
	}

	// Test 20g: FLOW_WriteLog — standalone log with context
	{
		kern.FLOW_WriteLog.DTO_Request writeRequest = new kern.FLOW_WriteLog.DTO_Request();
		writeRequest.logLevel = 'ERROR';
		writeRequest.message = 'Subscriber flow error: payment validation failed';
		writeRequest.shortMessage = 'Payment validation failed';
		writeRequest.classMethod = 'SubscriberPaymentFlow.ValidatePayment';

		kern.FLOW_WriteLog.writeLog(new List<kern.FLOW_WriteLog.DTO_Request> {writeRequest});
		System.debug('20g PASS: FLOW_WriteLog logged standalone message with context');
	}

	System.debug('=== Section 20 COMPLETE: All Flow Logger invocable tests passed ===');
}
catch(Exception error)
{
	System.debug('Section 20 ERROR: ' + error.getMessage());
	System.debug('Stack trace: ' + error.getStackTraceString());
}
