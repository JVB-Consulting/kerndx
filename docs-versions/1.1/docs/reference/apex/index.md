# Apex Classes

> Core Apex classes, utilities, and services

**238 items** in this category.

---

## Async

| Name | Description |
|------|-------------|
| [IF_Chain](IF_Chain.md) | A container for shared global interfaces used by the async chain orchestration framework. Subscriber |
| [UTIL_AsyncChain](UTIL_AsyncChain.md) | Lightweight async chain runner for sequencing jobs with shared state, error handling, and progress t |

## Async Processing

| Name | Description |
|------|-------------|
| [IF_Async](IF_Async.md) | A container for shared global interfaces used by the asynchronous framework. |
| [UTIL_AsynchronousJobLauncher](UTIL_AsynchronousJobLauncher.md) | Provides a simplified, static entry point for running complex asynchronous jobs using the UTIL_Adapt |

## Bulk DML

| Name | Description |
|------|-------------|
| [PROC_ExecuteDML](PROC_ExecuteDML.md) | Processor for generic DML operations using the adaptive async framework. Implements IF_Async.Process |
| [PROC_UpdateFields](PROC_UpdateFields.md) | Processor for bulk field updates using the adaptive async framework. Implements IF_Async.Processable |
| [SCHED_DeactivateUsers](SCHED_DeactivateUsers.md) | Scheduled job to automatically deactivate users who haven't logged in for a specified number of days |
| [SCHED_PurgeRecords](SCHED_PurgeRecords.md) | A scheduled job that deletes records from a specified Salesforce object based on age or all records, |
| [UTIL_BulkUpdates](UTIL_BulkUpdates.md) | Utility methods used to initialize adaptive async jobs to update fields on multiple objects. Provide |
| [UTIL_PurgeRecords](UTIL_PurgeRecords.md) | Provides utility methods for purging records from Salesforce objects using adaptive async processing |

## Controllers

| Name | Description |
|------|-------------|
| [CTRL_TableDataSource](CTRL_TableDataSource.md) | Controller class responsible for managing the instantiation of a data source class that supports the |
| [IF_TableDataSource](IF_TableDataSource.md) | Generic Interface for Table data sources |

## Data Masking

| Name | Description |
|------|-------------|
| [UTIL_Exceptions.MaskingBlockedException](UTIL_Exceptions.MaskingBlockedException.md) | Thrown when a masking rule configured with FailureAction__c = BlockDml fails. Propagates out of UTIL |

## Data Transfer Objects

| Name | Description |
|------|-------------|
| [DTO_Base](DTO_Base.md) | A base Data Transfer Object (DTO) class for storing JSON content, providing utility methods for seri |
| [DTO_BaseTable](DTO_BaseTable.md) | A Data Transfer Object (DTO) class that structures webservice handler responses into a common table  |
| [DTO_ChangeEventHeader](DTO_ChangeEventHeader.md) | A Data Transfer Object (DTO) exposing the supported subset of EventBus.ChangeEventHeader to Flow as  |
| [DTO_FlowValidationError](DTO_FlowValidationError.md) | Represents a single validation error or warning for Flow display. Contains details about the validat |
| [DTO_NameValue](DTO_NameValue.md) | DTO class for name-value pairs, used in invocable methods for data mapping, such as merge fields or  |
| [DTO_NameValues](DTO_NameValues.md) | Class for managing and transferring key-value pairs, represented as names and values, between classe |
| [DTO_PickList](DTO_PickList.md) | A Data Transfer Object (DTO) representing a single picklist and all associated values. This class is |
| [DTO_PicklistValue](DTO_PicklistValue.md) | A Data Transfer Object (DTO) representing a single picklist value. This object includes details abou |

## DML

| Name | Description |
|------|-------------|
| [DML_Builder](DML_Builder.md) | Fluent DML API for building and executing database operations. Uses a static factory entry point to  |
| [DML_Transaction](DML_Transaction.md) | Transaction engine for managing complex DML operations across multiple SObjects. Handles dependency  |

## Email

| Name | Description |
|------|-------------|
| [FLOW_SendEmail](FLOW_SendEmail.md) | Provides an invocable entry point for sending emails via Salesforce Flow with advanced capabilities. |
| [UTIL_Email](UTIL_Email.md) | Utility class for validating and sending emails within the Salesforce platform. Includes a unicode-a |

## Feature Flags

| Name | Description |
|------|-------------|
| [FLOW_CheckFeatureFlag](FLOW_CheckFeatureFlag.md) | This class is used in Flows to check whether a specific feature flag is enabled. It provides a metho |
| [UTIL_FeatureFlag](UTIL_FeatureFlag.md) | Provides static methods to check if a feature is enabled. It reads Custom Metadata records to determ |

## Logging

| Name | Description |
|------|-------------|
| [FLOW_LoggerEnd](FLOW_LoggerEnd.md) | Ends a logging correlation for a Flow. Use this at the end of a Flow to log completion status. |
| [FLOW_LoggerLog](FLOW_LoggerLog.md) | Logs an event within a Flow with correlation support. Use this to log messages, warnings, or errors  |
| [FLOW_LoggerStart](FLOW_LoggerStart.md) | Starts a logging correlation for a Flow. Use this at the beginning of a Flow to generate a correlati |
| [FLOW_WriteLog](FLOW_WriteLog.md) | Provides an invocable method for logging messages at specified levels (DEBUG, INFO, WARN, ERROR) fro |
| [LOG_Builder](LOG_Builder.md) | Primary logging interface for application debugging, monitoring, and error tracking. Uses a fluent b |

## Omnistudio

| Name | Description |
|------|-------------|
| [SVC_Omnistudio](SVC_Omnistudio.md) | SVC_Omnistudio is a factory class that implements the Callable interface and is designed to instanti |

## Query Infrastructure

| Name | Description |
|------|-------------|
| [IF_Queryable](IF_Queryable.md) | Interface for any object that can execute a query. Implemented by QRY_Builder.Builder and SEL_Base.  |
| [QRY_Builder](QRY_Builder.md) | Modern fluent query builder - the primary entry point for constructing and executing SOQL queries. P |
| [QRY_Condition](QRY_Condition.md) | Condition infrastructure for building complex SOQL WHERE clauses. Use these classes with QRY_Builder |
| [QRY_Function](QRY_Function.md) | Typed SOQL date-function expressions (CALENDAR_MONTH, DAY_IN_MONTH, FISCAL_QUARTER, ...) for use in  |

## Resilience

| Name | Description |
|------|-------------|
| [UTIL_CircuitBreaker](UTIL_CircuitBreaker.md) | Factory for creating circuit breaker instances to prevent cascading failures and provide fast failur |
| [UTIL_Retry](UTIL_Retry.md) | Factory for retry strategies with nested interface definitions. Provides a clean API for creating an |

## Schedulables

| Name | Description |
|------|-------------|
| [DTO_ScheduledParameterDefinition](DTO_ScheduledParameterDefinition.md) | A Data Transfer Object describing a single parameter definition supported by a scheduled job class.  |
| [IF_Schedulable](IF_Schedulable.md) | An interface for a Schedulable class that can declare the parameters it supports and receive validat |
| [SCHED_Base](SCHED_Base.md) | Abstract base class for scheduled jobs that support configurable parameters. Implements IF_Schedulab |
| [SCHED_ProcessLoginHistory](SCHED_ProcessLoginHistory.md) | Scheduled job that runs daily to process login history data. Launches PROC_LoginFrequencyAggregator  |

## Selectors

| Name | Description |
|------|-------------|
| [IF_Search](IF_Search.md) | Generic Interface for searches |
| [SEL_Base](SEL_Base.md) | Abstract base class for all selectors. Provides lazy-loaded field management and IF_Queryable implem |
| [SEL_ContentVersion](SEL_ContentVersion.md) | Selector for the ContentVersion object. Provides query methods for retrieving content versions by pu |
| [SEL_EmailTemplate](SEL_EmailTemplate.md) | Selector for the EmailTemplate SObject. Provides default field configuration and query methods for E |
| [SEL_Foobar](SEL_Foobar.md) | Selector for the Foobar__c SObject. Provides query methods and field/metadata constants for the fram |
| [SEL_Group](SEL_Group.md) | Selector for Salesforce Group objects. Provides query methods for group lookup and recursive group m |
| [SEL_Hierarchy](SEL_Hierarchy.md) | Data Access Layer for managing self-referencing hierarchical relationships. Provides methods to trav |
| [SEL_ObjectPermission](SEL_ObjectPermission.md) | Provides methods for querying and evaluating user access permissions on Salesforce objects. Simplifi |
| [SEL_OrgWideEmailAddress](SEL_OrgWideEmailAddress.md) | Selector for the OrgWideEmailAddress SObject. Provides query methods for retrieving organization-wid |
| [SEL_PermissionSet](SEL_PermissionSet.md) | Selector for the PermissionSet SObject. Provides default field configuration and query methods for P |
| [SEL_PermissionSetGroup](SEL_PermissionSetGroup.md) | Selector for the PermissionSetGroup SObject. Provides default field configuration and query methods  |
| [SEL_Profile](SEL_Profile.md) | Selector for the Profile SObject. Provides default field configuration, query methods, and commonly  |
| [SEL_User](SEL_User.md) | Selector for the User SObject. Provides default field configuration and query methods for User recor |
| [SEL_UserRole](SEL_UserRole.md) | Selector for the UserRole SObject. Provides query methods for retrieving user roles and traversing t |

## Testing

| Name | Description |
|------|-------------|
| [API_InboundTestHelper](API_InboundTestHelper.md) | Class has base methods that can be used to assist with testing inbound service calls |
| [API_OutboundTestHelper](API_OutboundTestHelper.md) | Class has base methods that can be used to test an outbound service. |
| [TST_Builder](TST_Builder.md) | An advanced factory for creating and inserting SObject records for Apex tests. This class provides a |
| [TST_Factory](TST_Factory.md) | Factory class for generating test data, permission set assignments, share records, metadata updates, |
| [TST_Mock](TST_Mock.md) | Central registry and fluent builder for mock SObjects. Wraps QRY_Builder.setMock() with lifecycle ma |
| [UTIL_SObjectBuilderDefaultProvider](UTIL_SObjectBuilderDefaultProvider.md) | Provides the default value generation logic for the SObjectBuilder. Subscribers should extend THIS c |
| [UTIL_ValidationTestHelper](UTIL_ValidationTestHelper.md) | Reusable utility class for testing validation rules. This is NOT a test class itself but provides as |

## Triggers

| Name | Description |
|------|-------------|
| [FLOW_BypassTrigger](FLOW_BypassTrigger.md) | Flow invocable action to manage trigger bypasses. Supports bypassing a specific trigger action or ob |
| [FLOW_CheckTriggerBypassed](FLOW_CheckTriggerBypassed.md) | This class is used to check whether certain triggers or actions are bypassed in the system. The clas |
| [IF_Trigger](IF_Trigger.md) | Contracts for metadata-driven trigger action handlers. Each nested interface corresponds to a Salesf |
| [TRG_Base](TRG_Base.md) | The base class for trigger actions, designed to be extended and implement relevant interfaces. This  |
| [TRG_Dispatcher](TRG_Dispatcher.md) | Factory class for instantiating and executing configured trigger actions. Manages the lifecycle of t |
| [TST_InvokeFlowMock](TST_InvokeFlowMock.md) | Test mock harness for TRG_InvokeFlow-dispatched flows. Lets test authors register canned flow respon |

## Utilities

| Name | Description |
|------|-------------|
| [FLOW_CheckObjectPermissions](FLOW_CheckObjectPermissions.md) | Will check what the current user's object permissions are |
| [FLOW_GetPicklistValues](FLOW_GetPicklistValues.md) | Invocable method to get all the picklist values for a particular object for a given record type. Del |
| [MAP_SObject](MAP_SObject.md) | In-memory index for SObjects, indexed by one or more fields. Supports cross-object field references, |
| [UTIL_Cache](UTIL_Cache.md) | Factory for Platform Cache instances with nested interface pattern. Provides intelligent cache manag |
| [UTIL_Date](UTIL_Date.md) | Provides date and datetime helper operations such as business day arithmetic, weekday/weekend checks |
| [UTIL_Exceptions](UTIL_Exceptions.md) | Centralised container for framework-specific exception types. Groups related exception classes under |
| [UTIL_Exceptions.ConfigurationException](UTIL_Exceptions.ConfigurationException.md) | Thrown when required platform configuration is absent or malformed. Typical triggers include missing |
| [UTIL_Exceptions.IllegalStateException](UTIL_Exceptions.IllegalStateException.md) | Thrown when an operation is attempted on an object whose internal state does not support that operat |
| [UTIL_Exceptions.NotFoundException](UTIL_Exceptions.NotFoundException.md) | Thrown when a lookup for a specific record or resource yields no results. Commonly raised by selecto |
| [UTIL_FormulaContext](UTIL_FormulaContext.md) | Container for pre-built formula evaluation context classes for standard Salesforce objects.  This cl |
| [UTIL_FormulaFilter](UTIL_FormulaFilter.md) | Class that can filter list of SObject based on Formula Information provided adapted from:apex-trigge |
| [UTIL_JsonPath](UTIL_JsonPath.md) | Utility class to streamline parsing nested JSON data structures. Provides methods to navigate and ex |
| [UTIL_JsonPath.MissingKeyException](UTIL_JsonPath.MissingKeyException.md) | Custom exception thrown when a JSON path key cannot be resolved. |
| [UTIL_Limits](UTIL_Limits.md) | Fluent interface for inspecting Salesforce governor limits. Provides named factory methods per limit |
| [UTIL_List](UTIL_List.md) | Various list utilities for manipulating lists of objects and SObjects. This class provides methods f |
| [UTIL_Map](UTIL_Map.md) | Static helper methods for common Map operations in Apex, including key-value transformation, entry j |
| [UTIL_Random](UTIL_Random.md) | Generates random values across multiple data types for testing and development, including numbers, s |
| [UTIL_SessionEncryption](UTIL_SessionEncryption.md) | Utility class providing bi-directional encryption and decryption capabilities with automatic key man |
| [UTIL_Sharing](UTIL_Sharing.md) | Utility class for managing SObject record sharing. Provides methods for both permanent and time-boun |
| [UTIL_SObject](UTIL_SObject.md) | SObject runtime operations — filtering, field extraction, list-to-map conversion, and dot-notation f |
| [UTIL_SObjectDescribe](UTIL_SObjectDescribe.md) | A semi-intelligent wrapper for standard Apex Schema methods, providing internal caching to avoid hit |
| [UTIL_String](UTIL_String.md) | Various string manipulation utilities |
| [UTIL_System](UTIL_System.md) | Namespace, type resolution, and platform utility methods. Provides runtime introspection for managed |
| [UTIL_TypeResolver](UTIL_TypeResolver.md) | Utility class containing type resolution components for resolving Apex class types. |

## Validation

| Name | Description |
|------|-------------|
| [FLOW_BypassValidation](FLOW_BypassValidation.md) | Flow invocable action to bypass validation rules for the current transaction. Use this before DML op |
| [FLOW_ClearValidationBypass](FLOW_ClearValidationBypass.md) | Flow invocable action to clear validation rule bypasses for the current transaction. Use this after  |
| [FLOW_ExecuteValidationRules](FLOW_ExecuteValidationRules.md) | Flow invocable action to execute validation rules against records. Use this in Record-Triggered Flow |
| [TRG_ExecuteValidationRules](TRG_ExecuteValidationRules.md) | Pre-built trigger action that executes formula-driven validation rules. This class implements all tr |
| [UTIL_ValidationRule](UTIL_ValidationRule.md) | Formula-driven declarative validation framework for advanced validation scenarios that standard Sale |

## Web Services

| Name | Description |
|------|-------------|
| [API_Base](API_Base.md) | Base class for all API web service calls (outbound and inbound). Provides common functionality for H |
| [API_CallCurrentOrg](API_CallCurrentOrg.md) | Base API class for all handlers that call the current Org standard APIs. Uses session-ID-based authe |
| [API_Dispatcher](API_Dispatcher.md) | Factory class for orchestrating the execution of web service handlers. Manages the lifecycle of API  |
| [API_Inbound](API_Inbound.md) | Base class for all inbound REST API web service calls. Provides foundational functionality for handl |
| [API_MockFactory](API_MockFactory.md) | Central factory for mock response management. Provides test isolation via scoped registries and supp |
| [API_MockTestHelper](API_MockTestHelper.md) | Test helper for API mock verification. Provides assertion methods that delegate to API_MockFactory v |
| [API_Outbound](API_Outbound.md) | Base class for all outbound web service calls. Extends API_Base to provide functionality for making  |
| [DTO_JsonBase](DTO_JsonBase.md) | A Data Transfer Object (DTO) base class for JSON serialization and deserialization, providing a fram |
| [FLOW_CallApi](FLOW_CallApi.md) | Invokes web service calls synchronously, allowing for integration with external systems from Salesfo |
| [FLOW_CallApiAsync](FLOW_CallApiAsync.md) | Asynchronously invokes web service calls, allowing large or delayed API callouts to be processed out |
| [REST_Echo](REST_Echo.md) | REST Endpoint wrapper class for the inbound echo test service. This class serves as a RESTFUL endpoi |
| [SCHED_PerformBatchedCallouts](SCHED_PerformBatchedCallouts.md) | The SCHED_PerformBatchedCallouts class is a scheduled job responsible for processing batched API cal |
| [SEL_ApiCall](SEL_ApiCall.md) | Selector for the ApiCall__c object. Provides query methods for service call management, status track |
| [SEL_ApiIssue](SEL_ApiIssue.md) | Selector for the ApiIssue__c SObject. Provides query methods for retrieving and filtering failed API |
| [UTIL_HttpClient](UTIL_HttpClient.md) | Fluent HTTP client facade over the API_Dispatcher pipeline. Provides zero-boilerplate callouts with  |

## Other

| Name | Description |
|------|-------------|
| [API_Base.HttpMethod](API_Base.HttpMethod.md) | HTTP method verbs for web service calls. |
| [API_Base.ServiceCallResult](API_Base.ServiceCallResult.md) | Tracks the request, response, and status of a web service call. |
| [API_Base.WebserviceStatus](API_Base.WebserviceStatus.md) | Enum representing the status of a web service call. |
| [API_MockFactory.MockBuilder](API_MockFactory.MockBuilder.md) | Fluent builder for constructing and registering mock responses. |
| [API_MockFactory.MockResponse](API_MockFactory.MockResponse.md) | Represents a mock HTTP response with fault simulation options. |
| [DML_Builder.DatabaseOperation](DML_Builder.DatabaseOperation.md) | Enum to specify the type of DML operation for external use. |
| [DML_Builder.DML_AsyncBuilder](DML_Builder.DML_AsyncBuilder.md) | Async DML execution wrapper. Groups registered operations by type and delegates to PROC_ExecuteDML w |
| [DML_Builder.TransactionResult](DML_Builder.TransactionResult.md) | Result object returned by execute() containing the outcome of all DML operations in the transaction. |
| [DTO_BaseTable.DTO_Column](DTO_BaseTable.DTO_Column.md) | Represents a column in the DTO_BaseTable, containing properties for label, field name, type, and sor |
| [DTO_ScheduledParameterDefinition.DataType](DTO_ScheduledParameterDefinition.DataType.md) | Enumeration of supported input data types for scheduled job parameters. |
| [FLOW_BypassTrigger.DTO_Request](FLOW_BypassTrigger.DTO_Request.md) | Request DTO for the Trigger Bypass invocable action. |
| [FLOW_BypassValidation.DTO_Request](FLOW_BypassValidation.DTO_Request.md) | Request DTO for the Bypass Validation invocable action. Specifies which validation rules to bypass b |
| [FLOW_CallApi.DTO_Request](FLOW_CallApi.DTO_Request.md) | Data Transfer Object representing the web service call request. |
| [FLOW_CallApi.DTO_Response](FLOW_CallApi.DTO_Response.md) | Data Transfer Object representing the web service response or errors. |
| [FLOW_CheckObjectPermissions.DTO_Request](FLOW_CheckObjectPermissions.DTO_Request.md) | DTO containing the name of the object for which to object permissions |
| [FLOW_CheckObjectPermissions.DTO_Response](FLOW_CheckObjectPermissions.DTO_Response.md) | DTO containing the permissions per object provided in request. |
| [FLOW_CheckTriggerBypassed.DTO_Request](FLOW_CheckTriggerBypassed.DTO_Request.md) | A DTO indicating what action has been bypassed |
| [FLOW_ClearValidationBypass.DTO_Request](FLOW_ClearValidationBypass.DTO_Request.md) | Request DTO for the Clear Validation Bypass invocable action. Specifies which bypass to clear by nam |
| [FLOW_ExecuteValidationRules.DTO_Request](FLOW_ExecuteValidationRules.DTO_Request.md) | Request DTO for the Execute Validation Rules invocable action. Contains the records to validate and  |
| [FLOW_ExecuteValidationRules.DTO_Response](FLOW_ExecuteValidationRules.DTO_Response.md) | Response DTO for the Execute Validation Rules invocable action. Contains the validation results incl |
| [FLOW_GetPicklistValues.DTO_Request](FLOW_GetPicklistValues.DTO_Request.md) | Request DTO containing the information required to retrieve picklist values. |
| [FLOW_GetPicklistValues.DTO_Response](FLOW_GetPicklistValues.DTO_Response.md) | Provides the outcome of the picklist values retrieval. |
| [FLOW_LoggerEnd.DTO_Request](FLOW_LoggerEnd.DTO_Request.md) | Input parameters for ending Flow correlation. |
| [FLOW_LoggerLog.DTO_Request](FLOW_LoggerLog.DTO_Request.md) | Input parameters for logging a Flow event. |
| [FLOW_LoggerStart.DTO_Request](FLOW_LoggerStart.DTO_Request.md) | Input parameters for starting Flow correlation. |
| [FLOW_LoggerStart.DTO_Response](FLOW_LoggerStart.DTO_Response.md) | Output containing the generated correlation ID. |
| [FLOW_SendEmail.DTO_Request](FLOW_SendEmail.DTO_Request.md) | Data Transfer Object (DTO) representing the input parameters for a single email request. |
| [FLOW_SendEmail.DTO_Response](FLOW_SendEmail.DTO_Response.md) | Data Transfer Object (DTO) representing the outcome of an email request. |
| [FLOW_WriteLog.DTO_Request](FLOW_WriteLog.DTO_Request.md) | Data Transfer Object (DTO) for log requests, specifying log level, message details, and context. |
| [IF_Async.AsynchronousExecutionStrategy](IF_Async.AsynchronousExecutionStrategy.md) | Enum defining different asynchronous execution strategies. |
| [IF_Async.Finishable](IF_Async.Finishable.md) | Optional interface for defining finalizer logic that runs after all data is processed. Implement thi |
| [IF_Async.Processable](IF_Async.Processable.md) | Interface for defining the core processing logic to be executed by an asynchronous job. |
| [IF_Chain.Step](IF_Chain.Step.md) | Interface for defining the business logic of a single chain step. Each step receives a shared contex |
| [IF_Trigger.AfterDelete](IF_Trigger.AfterDelete.md) | Handler contract for the after-delete trigger event. |
| [IF_Trigger.AfterInsert](IF_Trigger.AfterInsert.md) | Handler contract for the after-insert trigger event. |
| [IF_Trigger.AfterUndelete](IF_Trigger.AfterUndelete.md) | Handler contract for the after-undelete trigger event. |
| [IF_Trigger.AfterUpdate](IF_Trigger.AfterUpdate.md) | Handler contract for the after-update trigger event. |
| [IF_Trigger.BeforeDelete](IF_Trigger.BeforeDelete.md) | Handler contract for the before-delete trigger event. |
| [IF_Trigger.BeforeInsert](IF_Trigger.BeforeInsert.md) | Handler contract for the before-insert trigger event. |
| [IF_Trigger.BeforeUpdate](IF_Trigger.BeforeUpdate.md) | Handler contract for the before-update trigger event. |
| [IF_Trigger.PostAction](IF_Trigger.PostAction.md) | Handler contract for a post-trigger action — an Apex class that runs exactly once at the end of a tr |
| [IF_Trigger.PostActionContext](IF_Trigger.PostActionContext.md) | Context handed to a post-trigger action when the dispatcher unwinds the outermost trigger dispatch.  |
| [IF_Trigger.PostActionEntryCriteria](IF_Trigger.PostActionEntryCriteria.md) | Optional entry-criteria contract for a post-trigger action. Implementing classes are referenced from |
| [LOG_Builder.LogEntry](LOG_Builder.LogEntry.md) | Fluent builder for constructing rich log entries with context. Provides a chainable API for setting  |
| [LOG_Builder.LogScope](LOG_Builder.LogScope.md) | A logging scope that buffers log entries until closed. On creation, suspends immediate log publishin |
| [PROC_UpdateFields.DTO_Field](PROC_UpdateFields.DTO_Field.md) | DTO representing a field to update on an SObject. |
| [PROC_UpdateFields.DTO_Parameters](PROC_UpdateFields.DTO_Parameters.md) | DTO for parameters to query and update records. |
| [PROC_UpdateFields.FieldUpdateMethod](PROC_UpdateFields.FieldUpdateMethod.md) | Enum defining methods for updating SObject fields. |
| [QRY_Builder.AggregateRow](QRY_Builder.AggregateRow.md) | Typed wrapper around AggregateResult for convenient value access. Provides typed accessors that elim |
| [QRY_Builder.Builder](QRY_Builder.Builder.md) | Extensible query builder class. Maintains internal query state and uses QRY_Generator for SOQL build |
| [QRY_Builder.ConditionBuilder](QRY_Builder.ConditionBuilder.md) | Fluent builder for field-level conditions (WHERE and HAVING). |
| [QRY_Builder.DataCategoryBuilder](QRY_Builder.DataCategoryBuilder.md) | Fluent builder for WITH DATA CATEGORY filters. |
| [QRY_Builder.QueryPage](QRY_Builder.QueryPage.md) | Result container for paged queries, providing records and pagination metadata. |
| [QRY_Builder.Scope](QRY_Builder.Scope.md) | Enumeration of valid SOQL scope values for use with the USING SCOPE clause. |
| [QRY_Condition.AndCondition](QRY_Condition.AndCondition.md) | Represents a SOQL "AND" condition group. |
| [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) | Provides SOQL date literal values for use in QRY_Builder conditions. Implements Evaluable so date li |
| [QRY_Condition.Evaluable](QRY_Condition.Evaluable.md) | Interface for condition classes. Pass to QRY_Builder.addCondition(). |
| [QRY_Condition.FieldCondition](QRY_Condition.FieldCondition.md) | Represents a condition in a SOQL WHERE clause based on a specific field, operator, and value. |
| [QRY_Condition.Nestable](QRY_Condition.Nestable.md) | Interface for condition containers that support adding nested conditions. Extends Evaluable so group |
| [QRY_Condition.Operator](QRY_Condition.Operator.md) | SOQL comparison operators used to build query conditions. Operator SOQL Description EQUALS = Equal t |
| [QRY_Condition.OrCondition](QRY_Condition.OrCondition.md) | Represents a SOQL "OR" condition group. |
| [QRY_Condition.SoqlOptions](QRY_Condition.SoqlOptions.md) | Options for SOQL generation. |
| [QRY_Condition.UnitOfTime](QRY_Condition.UnitOfTime.md) | Units of time for SOQL date literals. |
| [SEL_Hierarchy.Selector](SEL_Hierarchy.Selector.md) | Selector class that provides hierarchy operations for a specific SObject type. Created via SEL_Hiera |
| [SEL_ObjectPermission.ObjectPermissionType](SEL_ObjectPermission.ObjectPermissionType.md) | A Permission that a User might have on a SObjectType. |
| [SVC_Omnistudio.OmniCallable](SVC_Omnistudio.OmniCallable.md) | A global inner interface that allows the SVC_Omnistudio class to instantiate a class and perform an  |
| [SVC_Omnistudio.Parameters](SVC_Omnistudio.Parameters.md) | A Data Transfer Object (DTO) used to wrap the original parameters provided by Omnistudio, organizing |
| [TRG_ApiCall](TRG_ApiCall.md) | Trigger on ApiCall__c. Fires the configured trigger actions for content-document cleanup on delete a |
| [TRG_ApiIssue](TRG_ApiIssue.md) | Trigger on ApiIssue__c. Fires the configured trigger actions for data masking before insert and upda |
| [TRG_AsyncChainExecution](TRG_AsyncChainExecution.md) | Trigger on AsyncChainExecution__c. Fires the configured trigger actions for data masking before inse |
| [TRG_Base.BypassType](TRG_Base.BypassType.md) | Indicates the type of trigger bypass being applied. |
| [TRG_Foobar](TRG_Foobar.md) | Example trigger demonstrating the Trigger Action framework |
| [TRG_LogEntryEvent](TRG_LogEntryEvent.md) | Log entry event trigger for handling log events |
| [TRG_ScheduledJob](TRG_ScheduledJob.md) | TRG_ScheduledJob activated by saving Scheduled Job records (rule: 1 record per periodic job setting) |
| [TST_Builder.Builder](TST_Builder.Builder.md) | A fluid builder for configuring and creating SObject records. Obtain an instance via TST_Builder.of( |
| [TST_Builder.DefaultFieldValueProvider](TST_Builder.DefaultFieldValueProvider.md) | Base class for field-level default value providers. @note Using a virtual class instead of an interf |
| [TST_Builder.DefaultValueProvider](TST_Builder.DefaultValueProvider.md) | Base class for default value providers. Extend 'UTIL_SObjectBuilderDefaultProvider' (which extends t |
| [TST_InvokeFlowMock.MockBuilder](TST_InvokeFlowMock.MockBuilder.md) | Fluent builder for registering a mock flow response. |
| [TST_Mock.MockBuilder](TST_Mock.MockBuilder.md) | Fluent builder wrapper that delegates to TST_Builder.Builder for record construction and auto-regist |
| [UTIL_AsyncChain.ApiStep](UTIL_AsyncChain.ApiStep.md) | Chain step adapter that executes any API_Outbound handler as part of an async chain. Wraps the full  |
| [UTIL_AsyncChain.ChainBuilder](UTIL_AsyncChain.ChainBuilder.md) | Fluent builder for configuring and executing an async chain. Provides methods for adding steps, sett |
| [UTIL_AsyncChain.ChainContext](UTIL_AsyncChain.ChainContext.md) | Shared state container passed between chain steps. Provides key-value storage for inter-step communi |
| [UTIL_AsyncChain.ChainStep](UTIL_AsyncChain.ChainStep.md) | Abstract base class for individual steps in an async chain. Each step runs in its own Queueable tran |
| [UTIL_AsyncChain.StepResult](UTIL_AsyncChain.StepResult.md) | Immutable result object returned by each ChainStep to indicate success or failure. Use the static fa |
| [UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest](UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest.md) | Request object for initiating an asynchronous process. |
| [UTIL_Cache.OperationResult](UTIL_Cache.OperationResult.md) | Result of a cache operation with detailed status information |
| [UTIL_Cache.Scope](UTIL_Cache.Scope.md) | Cache type enumeration |
| [UTIL_Cache.Status](UTIL_Cache.Status.md) | Operation status enumeration |
| [UTIL_Cache.Store](UTIL_Cache.Store.md) | Interface for Platform Cache operations |
| [UTIL_CircuitBreaker.Breaker](UTIL_CircuitBreaker.Breaker.md) | Interface for circuit breaker operations. This interface defines the contract for circuit breaker be |
| [UTIL_CircuitBreaker.Metrics](UTIL_CircuitBreaker.Metrics.md) | Public class containing circuit breaker metrics |
| [UTIL_CircuitBreaker.OpenException](UTIL_CircuitBreaker.OpenException.md) | Exception thrown when circuit breaker is OPEN and blocks a request |
| [UTIL_CircuitBreaker.ProtectedAction](UTIL_CircuitBreaker.ProtectedAction.md) | Interface for code that needs circuit breaker protection (no return value) Implement this interface  |
| [UTIL_CircuitBreaker.Provider](UTIL_CircuitBreaker.Provider.md) | Interface for code that needs circuit breaker protection (with return value) Implement this interfac |
| [UTIL_CircuitBreaker.State](UTIL_CircuitBreaker.State.md) | Enum representing the circuit breaker state |
| [UTIL_Email.DeliverabilityAccessLevel](UTIL_Email.DeliverabilityAccessLevel.md) | Enum representing the three possible email deliverability settings in a Salesforce org. |
| [UTIL_FeatureFlag.INT_FeatureFlagStrategy](UTIL_FeatureFlag.INT_FeatureFlagStrategy.md) | The global interface for all feature evaluation strategies. Implement this interface and reference y |
| [UTIL_FeatureFlag.INT_UserAwareFeatureFlagStrategy](UTIL_FeatureFlag.INT_UserAwareFeatureFlagStrategy.md) | Extended interface for custom strategies that support user context evaluation. Implement this interf |
| [UTIL_FormulaContext.AccountContext](UTIL_FormulaContext.AccountContext.md) | Formula evaluation context for Account object.  Provides typed access to Account records in formula  |
| [UTIL_FormulaContext.CampaignContext](UTIL_FormulaContext.CampaignContext.md) | Formula evaluation context for Campaign object. Provides typed access to Campaign records in formula |
| [UTIL_FormulaContext.CaseContext](UTIL_FormulaContext.CaseContext.md) | Formula evaluation context for Case object. Provides typed access to Case records in formula evaluat |
| [UTIL_FormulaContext.ContactContext](UTIL_FormulaContext.ContactContext.md) | Formula evaluation context for Contact object. Provides typed access to Contact records in formula e |
| [UTIL_FormulaContext.EventContext](UTIL_FormulaContext.EventContext.md) | Formula evaluation context for Event object. Provides typed access to Event records in formula evalu |
| [UTIL_FormulaContext.FoobarContext](UTIL_FormulaContext.FoobarContext.md) | Formula evaluation context for Foobar__c test object. Provides typed access to Foobar__c records in  |
| [UTIL_FormulaContext.LeadContext](UTIL_FormulaContext.LeadContext.md) | Formula evaluation context for Lead object. Provides typed access to Lead records in formula evaluat |
| [UTIL_FormulaContext.OpportunityContext](UTIL_FormulaContext.OpportunityContext.md) | Formula evaluation context for Opportunity object. Provides typed access to Opportunity records in f |
| [UTIL_FormulaContext.TaskContext](UTIL_FormulaContext.TaskContext.md) | Formula evaluation context for Task object. Provides typed access to Task records in formula evaluat |
| [UTIL_FormulaContext.UserContext](UTIL_FormulaContext.UserContext.md) | Formula evaluation context for User object. Provides typed access to User records in formula evaluat |
| [UTIL_FormulaFilter.DTO_FilterResults](UTIL_FormulaFilter.DTO_FilterResults.md) | Inner class representing the result of the filter method. |
| [UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext](UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext.md) | Interface for providing context data to dynamic formula evaluations using Salesforce's FormulaEval n |
| [UTIL_HttpClient.FailureAction](UTIL_HttpClient.FailureAction.md) | Defines the action to take when an HTTP call fails. |
| [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) | Fluent builder for configuring and executing HTTP requests through API_Dispatcher. |
| [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) | Fluent limit inspector scoped to a single governor limit type. Provides methods to check remaining b |
| [UTIL_Map.CaseInsensitiveMap](UTIL_Map.CaseInsensitiveMap.md) | A Map implementation that performs case-insensitive key lookups. Keys are normalised to lower case f |
| [UTIL_Retry.Context](UTIL_Retry.Context.md) | Interface defining the retry context. Contains information about the current retry attempt including |
| [UTIL_Retry.Strategy](UTIL_Retry.Strategy.md) | Interface defining the retry strategy logic. Implement this interface to create custom retry strateg |
| [UTIL_SObjectDescribe.FieldListBuilder](UTIL_SObjectDescribe.FieldListBuilder.md) | Builds a comma-separated field list from SObjectField tokens and optional FieldSet definitions. |
| [UTIL_SObjectDescribe.FieldsMap](UTIL_SObjectDescribe.FieldsMap.md) | A subclass of NamespacedAttributeMap for handling field maps returned by DescribeSObjectResult.field |
| [UTIL_SObjectDescribe.GlobalDescribeMap](UTIL_SObjectDescribe.GlobalDescribeMap.md) | A subclass of NamespacedAttributeMap for handling global describe data returned by getGlobalDescribe |
| [UTIL_TypeResolver.BaseClassResolver](UTIL_TypeResolver.BaseClassResolver.md) | Abstract base class for implementing custom type resolvers, typically registered via custom metadata |
| [UTIL_TypeResolver.INT_ClassTypeResolver](UTIL_TypeResolver.INT_ClassTypeResolver.md) | Interface for resolving Type objects from class names and chaining resolvers. Custom resolvers must  |
| [UTIL_ValidationRule.INT_BulkValidationContext](UTIL_ValidationRule.INT_BulkValidationContext.md) | Optional interface for bulk-optimized validation contexts. Implement this in addition to INT_SObject |
| [UTIL_ValidationRule.ValidationError](UTIL_ValidationRule.ValidationError.md) | Represents a single validation error or warning. |
| [UTIL_ValidationRule.ValidationResult](UTIL_ValidationRule.ValidationResult.md) | Result of validating a single record. Contains all validation errors/warnings for that record. |

