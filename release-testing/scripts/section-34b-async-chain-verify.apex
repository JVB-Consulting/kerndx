// Section 34b: Async Chain Verification
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Prerequisites:
//   - Section 34 executed (chains launched)
//   - Wait ~10 seconds for queueables to complete
//
// Verifies that chains launched in section 34 completed correctly.
//
// Run:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-34b-async-chain-verify.apex 2>&1 | grep USER_DEBUG

try
{
	// Verify 34a: Single-step chain completed
	{
		List<kern__AsyncChainExecution__c> executions = [
				SELECT kern__Status__c, kern__CompletedSteps__c, kern__ContextData__c
				FROM kern__AsyncChainExecution__c
				WHERE kern__ChainName__c = 'Test34a_SingleStep' ORDER BY CreatedDate DESC LIMIT 1
		];
		System.assert(!executions.isEmpty(), '34a-verify FAIL: Execution record not found');
		kern__AsyncChainExecution__c execution = executions[0];
		System.assert(execution.kern__Status__c == 'Completed', '34a-verify FAIL: Expected Completed, got: ' + execution.kern__Status__c);
		System.assert(execution.kern__CompletedSteps__c == 1, '34a-verify FAIL: Expected 1 completed step');

		Map<String, Object> context = (Map<String, Object>)JSON.deserializeUntyped(execution.kern__ContextData__c);
		Id foobarId = (Id)context.get('foobarId');
		List<kern__Foobar__c> foobars = [SELECT Id FROM kern__Foobar__c WHERE Id = :foobarId];
		System.assert(!foobars.isEmpty(), '34a-verify FAIL: Foobar record should exist');
		System.debug('34a-verify PASS: Completed with DML — Foobar: ' + foobarId);
	}

	// Verify 34b: Multi-step chain completed with context flow
	{
		List<kern__AsyncChainExecution__c> executions = [
				SELECT kern__Status__c, kern__CompletedSteps__c, kern__ContextData__c
				FROM kern__AsyncChainExecution__c
				WHERE kern__ChainName__c = 'Test34b_MultiStep' ORDER BY CreatedDate DESC LIMIT 1
		];
		kern__AsyncChainExecution__c execution = executions[0];
		System.assert(execution.kern__Status__c == 'Completed', '34b-verify FAIL: Expected Completed, got: ' + execution.kern__Status__c);
		System.assert(execution.kern__CompletedSteps__c == 2, '34b-verify FAIL: Expected 2 completed steps');

		Map<String, Object> context = (Map<String, Object>)JSON.deserializeUntyped(execution.kern__ContextData__c);
		Id foobarId = (Id)context.get('foobarId');
		kern__Foobar__c record = [SELECT Name FROM kern__Foobar__c WHERE Id = :foobarId];
		System.assert(record.Name.contains('Updated'), '34b-verify FAIL: Foobar should be updated');
		System.debug('34b-verify PASS: Multi-step completed — ' + record.Name);
	}

	// Verify 34c: Failing chain marked Failed
	{
		List<kern__AsyncChainExecution__c> executions = [
				SELECT kern__Status__c, kern__ErrorMessage__c
				FROM kern__AsyncChainExecution__c
				WHERE kern__ChainName__c = 'Test34c_Failing' ORDER BY CreatedDate DESC LIMIT 1
		];
		kern__AsyncChainExecution__c execution = executions[0];
		System.assert(execution.kern__Status__c == 'Failed', '34c-verify FAIL: Expected Failed, got: ' + execution.kern__Status__c);
		System.assert(execution.kern__ErrorMessage__c.contains('Deliberate subscriber failure'), '34c-verify FAIL: Wrong error message');
		System.debug('34c-verify PASS: Chain failed with correct error');
	}

	// Verify 34d: Error handler executed
	{
		List<kern__AsyncChainExecution__c> executions = [
				SELECT kern__Status__c, kern__ContextData__c
				FROM kern__AsyncChainExecution__c
				WHERE kern__ChainName__c = 'Test34d_ErrorHandler' ORDER BY CreatedDate DESC LIMIT 1
		];
		kern__AsyncChainExecution__c execution = executions[0];
		System.assert(execution.kern__Status__c == 'Failed', '34d-verify FAIL: Expected Failed');
		Map<String, Object> context = (Map<String, Object>)JSON.deserializeUntyped(execution.kern__ContextData__c);
		System.assert((Boolean)context.get('errorHandled') == true, '34d-verify FAIL: Error handler should have set flag');
		System.debug('34d-verify PASS: Error handler executed');
	}

	// Verify 34e: Completion handler executed
	{
		List<kern__AsyncChainExecution__c> executions = [
				SELECT kern__Status__c, kern__ContextData__c
				FROM kern__AsyncChainExecution__c
				WHERE kern__ChainName__c = 'Test34e_CompletionHandler' ORDER BY CreatedDate DESC LIMIT 1
		];
		kern__AsyncChainExecution__c execution = executions[0];
		System.assert(execution.kern__Status__c == 'Completed', '34e-verify FAIL: Expected Completed, got: ' + execution.kern__Status__c);
		Map<String, Object> context = (Map<String, Object>)JSON.deserializeUntyped(execution.kern__ContextData__c);
		System.assert((Boolean)context.get('completed') == true, '34e-verify FAIL: Completion handler should have set flag');
		System.debug('34e-verify PASS: Completion handler executed');
	}

	// Verify 34g: ContinueOnError chain completed
	{
		List<kern__AsyncChainExecution__c> executions = [
				SELECT kern__Status__c, kern__CompletedSteps__c, kern__ContextData__c
				FROM kern__AsyncChainExecution__c
				WHERE kern__ChainName__c = 'Test34g_ContinueOnError' ORDER BY CreatedDate DESC LIMIT 1
		];
		kern__AsyncChainExecution__c execution = executions[0];
		System.assert(execution.kern__Status__c == 'Completed', '34g-verify FAIL: Expected Completed, got: ' + execution.kern__Status__c);
		System.assert(execution.kern__CompletedSteps__c == 1, '34g-verify FAIL: Only the successful step should be counted, got: ' + execution.kern__CompletedSteps__c);
		System.debug('34g-verify PASS: ContinueOnError chain — ' + execution.kern__CompletedSteps__c + '/2 succeeded');
	}

	// Verify 34h: Handler callout isolation — onComplete handler ran callout after DML step
	{
		List<kern__AsyncChainExecution__c> executions = [
				SELECT kern__Status__c, kern__ContextData__c
				FROM kern__AsyncChainExecution__c
				WHERE kern__ChainName__c = 'Test34h_HandlerCallout' ORDER BY CreatedDate DESC LIMIT 1
		];
		kern__AsyncChainExecution__c execution = executions[0];
		System.assert(execution.kern__Status__c == 'Completed', '34h-verify FAIL: Expected Completed, got: ' + execution.kern__Status__c);
		Map<String, Object> context = (Map<String, Object>)JSON.deserializeUntyped(execution.kern__ContextData__c);
		System.assert(context.get('apiResponse') == 'invoked', '34h-verify FAIL: onComplete handler should have invoked API');
		System.debug('34h-verify PASS: Handler callout after DML succeeded — apiResponse: ' + context.get('apiResponse'));
	}

	// Verify 34i: ApiStep bridge completed with result in context
	{
		List<kern__AsyncChainExecution__c> executions = [
				SELECT kern__Status__c, kern__CompletedSteps__c, kern__ContextData__c
				FROM kern__AsyncChainExecution__c
				WHERE kern__ChainName__c = 'Test34i_ApiStep' ORDER BY CreatedDate DESC LIMIT 1
		];
		System.assert(!executions.isEmpty(), '34i-verify FAIL: Execution record not found');
		kern__AsyncChainExecution__c execution = executions[0];
		System.assert(execution.kern__Status__c == 'Completed', '34i-verify FAIL: Expected Completed, got: ' + execution.kern__Status__c);
		System.assert(execution.kern__CompletedSteps__c == 1, '34i-verify FAIL: Expected 1 completed step');
		Map<String, Object> context = (Map<String, Object>)JSON.deserializeUntyped(execution.kern__ContextData__c);
		Map<String, Object> apiResult = (Map<String, Object>)context.get('__apiResult_0');
		System.assert(apiResult != null, '34i-verify FAIL: API result should be in context');
		System.assert((Boolean)apiResult.get('success') == true, '34i-verify FAIL: API call should succeed');
		System.assert(apiResult.get('apiCallId') != null, '34i-verify FAIL: ApiCall ID should be stored');
		System.debug('34i-verify PASS: ApiStep bridge completed — apiCallId: ' + apiResult.get('apiCallId'));
	}

	// Verify 34j: Initial context preserved
	{
		List<kern__AsyncChainExecution__c> executions = [
				SELECT kern__Status__c, kern__ContextData__c
				FROM kern__AsyncChainExecution__c
				WHERE kern__ChainName__c = 'Test34j_InitialContext' ORDER BY CreatedDate DESC LIMIT 1
		];
		kern__AsyncChainExecution__c execution = executions[0];
		System.assert(execution.kern__Status__c == 'Completed', '34j-verify FAIL: Expected Completed');
		Map<String, Object> context = (Map<String, Object>)JSON.deserializeUntyped(execution.kern__ContextData__c);
		System.assert(context.get('testKey') == 'testValue', '34j-verify FAIL: Initial context should be preserved');
		System.debug('34j-verify PASS: Initial context preserved — testKey: ' + context.get('testKey'));
	}
}
catch(Exception error)
{
	System.debug('UNEXPECTED ERROR: ' + error.getMessage() + ' | ' + error.getStackTraceString());
}
