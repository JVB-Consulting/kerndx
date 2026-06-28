// Stills capture seed — realistic synthetic data for the Administration Tools guide screenshots.
// Synthetic values only (no real PII / client names). Converges to a fixed set on every run so the
// "Requests Failed Today" view (CreatedDate = TODAY AND Status = Open) always has fresh rows on the
// day of capture. Runs against the MANAGED-install subscriber org (kern__ namespace):
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/capture-stills-seed.apex

// Open API issues so the API Issues queue still (and the Requests Failed Today list view) shows the
// triage-and-retry surface populated. Delete-and-reinsert keeps CreatedDate on the capture day.
List<kern__ApiIssue__c> demoIssues = [SELECT Id FROM kern__ApiIssue__c WHERE kern__ServiceName__c IN ('Payment Gateway', 'Shipping Rates', 'Tax Service')];
if(!demoIssues.isEmpty())
{
	delete demoIssues;
}
List<kern__ApiIssue__c> issues = new List<kern__ApiIssue__c>{
	new kern__ApiIssue__c(kern__Status__c = 'Open', kern__Direction__c = 'Outbound', kern__ServiceName__c = 'Payment Gateway', kern__RequestMethod__c = 'POST', kern__RequestPath__c = '/v1/charges', kern__ErrorMessages__c = 'HTTP 503 Service Unavailable after 3 retries'),
	new kern__ApiIssue__c(kern__Status__c = 'Open', kern__Direction__c = 'Outbound', kern__ServiceName__c = 'Shipping Rates', kern__RequestMethod__c = 'GET', kern__RequestPath__c = '/rates/quote', kern__ErrorMessages__c = 'Read timeout after 30000 ms'),
	new kern__ApiIssue__c(kern__Status__c = 'Open', kern__Direction__c = 'Outbound', kern__ServiceName__c = 'Tax Service', kern__RequestMethod__c = 'POST', kern__RequestPath__c = '/calculate', kern__ErrorMessages__c = 'HTTP 401 Unauthorized — access token expired')
};
insert issues;
System.debug('STILLS SEED: inserted ' + issues.size() + ' Open ApiIssue rows for the queue still');

// API calls so the API Calls list-view picker still shows a populated call history under the dropdown
// (mixed Completed/Failed, created today so the Today's Calls view is non-empty).
List<kern__ApiCall__c> demoCalls = [SELECT Id FROM kern__ApiCall__c WHERE kern__ServiceName__c IN ('Payment Gateway', 'CRM Sync', 'Inventory Service', 'Shipping Rates', 'Tax Service')];
if(!demoCalls.isEmpty())
{
	delete demoCalls;
}
List<kern__ApiCall__c> calls = new List<kern__ApiCall__c>{
	new kern__ApiCall__c(kern__Direction__c = 'Outbound', kern__Status__c = 'Completed', kern__ServiceName__c = 'Payment Gateway', kern__HttpMethod__c = 'POST', kern__URL__c = 'https://api.example.com/v1/charges', kern__StatusCode__c = '200', kern__TotalDurationMs__c = 412),
	new kern__ApiCall__c(kern__Direction__c = 'Outbound', kern__Status__c = 'Completed', kern__ServiceName__c = 'CRM Sync', kern__HttpMethod__c = 'GET', kern__URL__c = 'https://api.example.com/contacts', kern__StatusCode__c = '200', kern__TotalDurationMs__c = 189),
	new kern__ApiCall__c(kern__Direction__c = 'Inbound', kern__Status__c = 'Completed', kern__ServiceName__c = 'Inventory Service', kern__HttpMethod__c = 'POST', kern__URL__c = '/services/apexrest/inventory', kern__StatusCode__c = '201', kern__TotalDurationMs__c = 77),
	new kern__ApiCall__c(kern__Direction__c = 'Outbound', kern__Status__c = 'Failed', kern__ServiceName__c = 'Shipping Rates', kern__HttpMethod__c = 'GET', kern__URL__c = 'https://api.example.com/rates/quote', kern__StatusCode__c = '503', kern__TotalDurationMs__c = 30021),
	new kern__ApiCall__c(kern__Direction__c = 'Outbound', kern__Status__c = 'Failed', kern__ServiceName__c = 'Tax Service', kern__HttpMethod__c = 'POST', kern__URL__c = 'https://api.example.com/calculate', kern__StatusCode__c = '401', kern__TotalDurationMs__c = 233)
};
insert calls;
System.debug('STILLS SEED: inserted ' + calls.size() + ' ApiCall rows for the list-view picker still');
