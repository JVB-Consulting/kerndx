// Consoles at volume: removes one slice of a run's rows, by its action ids, by its token and by the Volume name
// family; the driver runs it until the counts read zero. Three thousand rows per delete keeps one pass under the
// platform's ten thousand DML rows. The name pattern is bound through a variable: an inline literal cannot escape
// the underscore (a literal 'Volume\\_%' matched nothing, measured 2026-09-24). The watchdog writes its entries for
// the rows it acts on (re-driven, ended Failed, parked, marked Stalled again) in its own sweep, under no id of the run,
// so those entries are found by the rows' record ids, which the driver passes from the manifest.
// Tokens: __FIELD_NAMESPACE__ __ACTION_IDS__ (a list literal's body) __RUN_TOKEN__ __WATCHED_ROW_IDS__ (a list literal's body)
List<String> actionIds = new List<String> {__ACTION_IDS__};
List<String> watchedRowIds = new List<String> {__WATCHED_ROW_IDS__};
String tokenPrefix = '__RUN_TOKEN__-%';
String volumeChainNames = 'Volume\\_%';
String stepClassMethods = 'SubscriberChainSteps.%';
delete [SELECT Id FROM __FIELD_NAMESPACE__AsyncChainExecution__c WHERE __FIELD_NAMESPACE__RootCorrelationId__c IN :actionIds
		OR __FIELD_NAMESPACE__RootCorrelationId__c LIKE :tokenPrefix OR __FIELD_NAMESPACE__ChainName__c LIKE :volumeChainNames LIMIT 3000];
delete [SELECT Id FROM __FIELD_NAMESPACE__LogEntry__c WHERE __FIELD_NAMESPACE__RootCorrelationId__c IN :actionIds
		OR __FIELD_NAMESPACE__RootCorrelationId__c LIKE :tokenPrefix OR __FIELD_NAMESPACE__ClassMethod__c LIKE :stepClassMethods
		OR __FIELD_NAMESPACE__RecordId__c IN :watchedRowIds LIMIT 3000];
delete [SELECT Id FROM __FIELD_NAMESPACE__Foobar__c WHERE Name LIKE 'Subscriber Recovery Marker %' OR Name LIKE 'Chain Test %' LIMIT 3000];
Integer chainRows = [SELECT COUNT() FROM __FIELD_NAMESPACE__AsyncChainExecution__c WHERE __FIELD_NAMESPACE__RootCorrelationId__c IN :actionIds
		OR __FIELD_NAMESPACE__RootCorrelationId__c LIKE :tokenPrefix OR __FIELD_NAMESPACE__ChainName__c LIKE :volumeChainNames];
Integer logRows = [SELECT COUNT() FROM __FIELD_NAMESPACE__LogEntry__c WHERE __FIELD_NAMESPACE__RootCorrelationId__c IN :actionIds
		OR __FIELD_NAMESPACE__RootCorrelationId__c LIKE :tokenPrefix OR __FIELD_NAMESPACE__ClassMethod__c LIKE :stepClassMethods
		OR __FIELD_NAMESPACE__RecordId__c IN :watchedRowIds];
System.debug('VOLUME_TEARDOWN chainRows=' + chainRows + ' logRows=' + logRows);
