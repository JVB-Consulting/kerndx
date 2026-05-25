# KernDX API Reference

> Auto-generated documentation for the KernDX Framework

---

## Table of Contents

1. [Overview](#overview)
2. [Quick Links by Use Case](#quick-links-by-use-case)
3. [Apex Classes](#apex-classes)
   - [Query Infrastructure](#query-infrastructure)
   - [Selectors](#selectors)
   - [DML and Unit of Work](#dml-and-unit-of-work)
   - [Trigger Framework](#trigger-framework)
   - [Web Services](#web-services)
   - [Data Transfer Objects](#data-transfer-objects)
   - [Logging](#logging)
   - [Feature Flags](#feature-flags)
   - [Resilience Patterns](#resilience-patterns)
   - [Async Processing](#async-processing)
   - [Utilities](#utilities)
   - [Controllers](#controllers)
   - [Schedulables](#schedulables)
   - [Bulk DML](#bulk-dml)
   - [Testing](#testing)
   - [Uncategorized](#uncategorized)
   - [Validation](#validation)
   - [Email](#email)
   - [Async](#async)
   - [Omnistudio](#omnistudio)
   - [Trigger Framework](#trigger-framework)
   - [Data Masking](#data-masking)
4. [Custom Objects](#custom-objects)
5. [Platform Events](#platform-events)
6. [Custom Metadata Types](#custom-metadata-types)

---

## Overview

This reference contains **258 documented items** across the following categories:

| Category | Items | Description | Browse |
|----------|-------|-------------|--------|
| **Custom Metadata Types** | 14 | Configuration and settings metadata | [Browse All](metadata/index.md) |
| **Apex Classes** | 233 | Core Apex classes, utilities, and services | [Browse All](apex/index.md) |
| **Custom Objects** | 10 | Custom SObjects in the package | [Browse All](objects/index.md) |
| **Platform Events** | 1 | Asynchronous event definitions | [Browse All](events/index.md) |

---

## Quick Links by Use Case

### I Need To...

| Use Case | Primary Class | Related Classes |
|----------|---------------|-----------------|
| **Build SOQL queries** | [QRY_Builder](apex/QRY_Builder.md) | [QRY_Condition](apex/QRY_Condition.md) |
| **Simple record lookup** | [SEL_Base](apex/SEL_Base.md) | - |
| **Create trigger actions** | [TRG_Dispatcher](apex/TRG_Dispatcher.md) | [TRG_Base](apex/TRG_Base.md), [IF_Trigger](apex/IF_Trigger.md) |
| **Make REST API calls** | [API_Outbound](apex/API_Outbound.md) | API_OutboundMock, [DTO_JsonBase](apex/DTO_JsonBase.md) |
| **Handle inbound APIs** | [API_Inbound](apex/API_Inbound.md) | - |
| **Transactional DML** | [DML_Builder](apex/DML_Builder.md) | [DML_Transaction](apex/DML_Transaction.md) |
| **Log application events** | [LOG_Builder](apex/LOG_Builder.md) | - |
| **Create test data** | [TST_Builder](apex/TST_Builder.md) | [TST_Factory](apex/TST_Factory.md), [TST_Mock](apex/TST_Mock.md) |
| **Check feature flags** | [UTIL_FeatureFlag](apex/UTIL_FeatureFlag.md) | - |
| **Implement circuit breaker** | [UTIL_CircuitBreaker](apex/UTIL_CircuitBreaker.md) | [UTIL_Retry](apex/UTIL_Retry.md) |
| **Work with strings** | [UTIL_String](apex/UTIL_String.md) | - |
| **Work with dates** | [UTIL_Date](apex/UTIL_Date.md) | - |
| **Work with collections** | [UTIL_List](apex/UTIL_List.md) | [UTIL_Map](apex/UTIL_Map.md), UTIL_Set |

---

## Apex Classes

### Query Infrastructure

Fluent SOQL builder, bind registry, conditions, and query engine. Use `QRY_Builder` for 95% of queries.

| Class | Description |
|-------|-------------|
| [QRY_Builder](apex/QRY_Builder.md) | Modern fluent query builder - the primary entry point for constructing and executing SOQL queries. |
| [QRY_Condition](apex/QRY_Condition.md) | Condition infrastructure for building complex SOQL WHERE clauses. |
| [IF_Queryable](apex/IF_Queryable.md) | Interface for any object that can execute a query. |

### Selectors

Object-specific query classes that extend `SEL_Base`. Define default fields and provide type-safe record retrieval via `findById()`, `findByField()`, and custom query methods.

| Class | Description |
|-------|-------------|
| [SEL_Base](apex/SEL_Base.md) | Abstract base class for all selectors. |
| [IF_Search](apex/IF_Search.md) | Generic Interface for searches |
| [SEL_ContentVersion](apex/SEL_ContentVersion.md) | Selector for the ContentVersion object. |
| [SEL_EmailTemplate](apex/SEL_EmailTemplate.md) | Selector for the EmailTemplate SObject. |
| [SEL_Foobar](apex/SEL_Foobar.md) | Selector for the Foobar__c SObject. |
| [SEL_Group](apex/SEL_Group.md) | Selector for Salesforce Group objects. |
| [SEL_Hierarchy](apex/SEL_Hierarchy.md) | Data Access Layer for managing self-referencing hierarchical relationships. |
| [SEL_ObjectPermission](apex/SEL_ObjectPermission.md) | Provides methods for querying and evaluating user access permissions on Salesforce objects. |
| [SEL_OrgWideEmailAddress](apex/SEL_OrgWideEmailAddress.md) | Selector for the OrgWideEmailAddress SObject. |
| [SEL_PermissionSet](apex/SEL_PermissionSet.md) | Selector for the PermissionSet SObject. |
| [SEL_PermissionSetGroup](apex/SEL_PermissionSetGroup.md) | Selector for the PermissionSetGroup SObject. |
| [SEL_Profile](apex/SEL_Profile.md) | Selector for the Profile SObject. |
| [SEL_User](apex/SEL_User.md) | Selector for the User SObject. |
| [SEL_UserRole](apex/SEL_UserRole.md) | Selector for the UserRole SObject. |

### DML and Unit of Work

Transactional DML with dependency management, partial success handling, and sharing enforcement. Use `DML_Builder.newTransaction()` for all DML operations.

| Class | Description |
|-------|-------------|
| [DML_Builder](apex/DML_Builder.md) | Fluent DML API for building and executing database operations. |
| [DML_Transaction](apex/DML_Transaction.md) | Transaction engine for managing complex DML operations across multiple SObjects. |

### Trigger Framework

Metadata-driven trigger dispatch. Configure trigger actions via `TriggerAction__mdt` custom metadata. Extend `TRG_Base` and implement `IF_Trigger` event interfaces.

| Class | Description |
|-------|-------------|
| [TRG_Dispatcher](apex/TRG_Dispatcher.md) | Factory class for instantiating and executing configured trigger actions. |
| [TRG_Base](apex/TRG_Base.md) | The base class for trigger actions, designed to be extended and implement relevant interfaces. |
| [IF_Trigger](apex/IF_Trigger.md) | Contracts for metadata-driven trigger action handlers. |
| [FLOW_BypassTrigger](apex/FLOW_BypassTrigger.md) | Flow invocable action to manage trigger bypasses. |
| [FLOW_CheckTriggerBypassed](apex/FLOW_CheckTriggerBypassed.md) | This class is used to check whether certain triggers or actions are bypassed in the system. |

### Web Services

REST integration framework with automatic retry, circuit breaking, and queue-based processing. Configure endpoints via `ApiSetting__mdt`.

| Class | Description |
|-------|-------------|
| [API_Outbound](apex/API_Outbound.md) | Base class for all outbound web service calls. |
| [API_Inbound](apex/API_Inbound.md) | Base class for all inbound REST API web service calls. |
| [API_Base](apex/API_Base.md) | Base class for all API web service calls (outbound and inbound). |
| [API_CallCurrentOrg](apex/API_CallCurrentOrg.md) | Base API class for all handlers that call the current Org standard APIs. |
| [API_Dispatcher](apex/API_Dispatcher.md) | Factory class for orchestrating the execution of web service handlers. |
| [API_MockFactory](apex/API_MockFactory.md) | Central factory for mock response management. |
| [API_MockTestHelper](apex/API_MockTestHelper.md) | Test helper for API mock verification. |
| [DTO_JsonBase](apex/DTO_JsonBase.md) | A Data Transfer Object (DTO) base class for JSON serialization and deserialization, providing a framework for transfo... |
| [FLOW_CallApi](apex/FLOW_CallApi.md) | Invokes web service calls synchronously, allowing for integration with external systems from Salesforce using Lightni... |
| [FLOW_CallApiAsync](apex/FLOW_CallApiAsync.md) | Asynchronously invokes web service calls, allowing large or delayed API callouts to be processed outside of immediate... |
| [REST_Echo](apex/REST_Echo.md) | REST Endpoint wrapper class for the inbound echo test service. |
| [SCHED_PerformBatchedCallouts](apex/SCHED_PerformBatchedCallouts.md) | The SCHED_PerformBatchedCallouts class is a scheduled job responsible for processing batched API calls that are queue... |
| [SEL_ApiCall](apex/SEL_ApiCall.md) | Selector for the ApiCall__c object. |
| [SEL_ApiIssue](apex/SEL_ApiIssue.md) | Selector for the ApiIssue__c SObject. |
| [UTIL_HttpClient](apex/UTIL_HttpClient.md) | Fluent HTTP client facade over the API_Dispatcher pipeline. |

### Data Transfer Objects

Base classes for JSON and XML serialization. All DTOs extend `DTO_JsonBase` and support automatic population from SObject records.

| Class | Description |
|-------|-------------|
| [DTO_Base](apex/DTO_Base.md) | A base Data Transfer Object (DTO) class for storing JSON content, providing utility methods for serialization, deseri... |
| [DTO_NameValues](apex/DTO_NameValues.md) | Class for managing and transferring key-value pairs, represented as names and values, between classes. |
| [DTO_BaseTable](apex/DTO_BaseTable.md) | A Data Transfer Object (DTO) class that structures webservice handler responses into a common table format, providing... |
| [DTO_FlowValidationError](apex/DTO_FlowValidationError.md) | Represents a single validation error or warning for Flow display. |
| [DTO_NameValue](apex/DTO_NameValue.md) | DTO class for name-value pairs, used in invocable methods for data mapping, such as merge fields or configuration set... |
| [DTO_PickList](apex/DTO_PickList.md) | A Data Transfer Object (DTO) representing a single picklist and all associated values. |
| [DTO_PicklistValue](apex/DTO_PicklistValue.md) | A Data Transfer Object (DTO) representing a single picklist value. |

### Logging

Platform event-based async logging with correlation IDs, structured context, and configurable filtering.

| Class | Description |
|-------|-------------|
| [LOG_Builder](apex/LOG_Builder.md) | Primary logging interface for application debugging, monitoring, and error tracking. |
| [FLOW_LoggerEnd](apex/FLOW_LoggerEnd.md) | Ends a logging correlation for a Flow. |
| [FLOW_LoggerLog](apex/FLOW_LoggerLog.md) | Logs an event within a Flow with correlation support. |
| [FLOW_LoggerStart](apex/FLOW_LoggerStart.md) | Starts a logging correlation for a Flow. |
| [FLOW_WriteLog](apex/FLOW_WriteLog.md) | Provides an invocable method for logging messages at specified levels (DEBUG, INFO, WARN, ERROR) from Salesforce flows. |

### Feature Flags

Runtime feature toggling with custom metadata configuration and pluggable evaluation strategies.

| Class | Description |
|-------|-------------|
| [UTIL_FeatureFlag](apex/UTIL_FeatureFlag.md) | Provides static methods to check if a feature is enabled. |
| [FLOW_CheckFeatureFlag](apex/FLOW_CheckFeatureFlag.md) | This class is used in Flows to check whether a specific feature flag is enabled. |

### Resilience Patterns

Circuit breaker, retry strategies (linear, exponential), and platform cache management for fault-tolerant integrations.

| Class | Description |
|-------|-------------|
| [UTIL_CircuitBreaker](apex/UTIL_CircuitBreaker.md) | Factory for creating circuit breaker instances to prevent cascading failures and provide fast failure when external s... |
| [UTIL_Retry](apex/UTIL_Retry.md) | Factory for retry strategies with nested interface definitions. |

### Async Processing

Adaptive async job launching that automatically selects the optimal execution strategy (batch, queueable, future).

| Class | Description |
|-------|-------------|
| [UTIL_AsynchronousJobLauncher](apex/UTIL_AsynchronousJobLauncher.md) | Provides a simplified, static entry point for running complex asynchronous jobs using the UTIL_AdaptiveAsynchronousPr... |
| [IF_Async](apex/IF_Async.md) | A container for shared global interfaces used by the asynchronous framework. |

### Utilities

Common utilities for strings, dates, numbers, collections, security, encryption, and system reflection.

| Class | Description |
|-------|-------------|
| [UTIL_String](apex/UTIL_String.md) | Various string manipulation utilities |
| [UTIL_Date](apex/UTIL_Date.md) | Provides date and datetime helper operations such as business day arithmetic, weekday/weekend checks, ISO 8601 serial... |
| [UTIL_List](apex/UTIL_List.md) | Various list utilities for manipulating lists of objects and SObjects. |
| [UTIL_Map](apex/UTIL_Map.md) | Static helper methods for common Map operations in Apex, including key-value transformation, entry joining, equality ... |
| [FLOW_CheckObjectPermissions](apex/FLOW_CheckObjectPermissions.md) | Will check what the current user's object permissions are |
| [FLOW_GetPicklistValues](apex/FLOW_GetPicklistValues.md) | Invocable method to get all the picklist values for a particular object for a given record type. |
| [MAP_SObject](apex/MAP_SObject.md) | In-memory index for SObjects, indexed by one or more fields. |
| [UTIL_Cache](apex/UTIL_Cache.md) | Factory for Platform Cache instances with nested interface pattern. |
| [UTIL_Exceptions](apex/UTIL_Exceptions.md) | Centralised container for framework-specific exception types. |
| [UTIL_Exceptions.ConfigurationException](apex/UTIL_Exceptions.ConfigurationException.md) | Thrown when required platform configuration is absent or malformed. |
| [UTIL_Exceptions.IllegalStateException](apex/UTIL_Exceptions.IllegalStateException.md) | Thrown when an operation is attempted on an object whose internal state does not support that operation. |
| [UTIL_Exceptions.NotFoundException](apex/UTIL_Exceptions.NotFoundException.md) | Thrown when a lookup for a specific record or resource yields no results. |
| [UTIL_FormulaContext](apex/UTIL_FormulaContext.md) | Container for pre-built formula evaluation context classes for standard Salesforce objects. |
| [UTIL_FormulaFilter](apex/UTIL_FormulaFilter.md) | Class that can filter list of SObject based on Formula Information provided adapted from:apex-trigger-actions-framework |
| [UTIL_JsonPath](apex/UTIL_JsonPath.md) | Utility class to streamline parsing nested JSON data structures. |
| [UTIL_JsonPath.MissingKeyException](apex/UTIL_JsonPath.MissingKeyException.md) | Custom exception thrown when a JSON path key cannot be resolved. |
| [UTIL_Limits](apex/UTIL_Limits.md) | Fluent interface for inspecting Salesforce governor limits. |
| [UTIL_Random](apex/UTIL_Random.md) | Generates random values across multiple data types for testing and development, including numbers, strings, UUIDs, an... |
| [UTIL_SessionEncryption](apex/UTIL_SessionEncryption.md) | Utility class providing bi-directional encryption and decryption capabilities with automatic key management and expiry. |
| [UTIL_Sharing](apex/UTIL_Sharing.md) | Utility class for managing SObject record sharing. |
| [UTIL_SObject](apex/UTIL_SObject.md) | SObject runtime operations — filtering, field extraction, list-to-map conversion, and dot-notation field value retrie... |
| [UTIL_SObjectDescribe](apex/UTIL_SObjectDescribe.md) | A semi-intelligent wrapper for standard Apex Schema methods, providing internal caching to avoid hitting describe lim... |
| [UTIL_System](apex/UTIL_System.md) | Namespace, type resolution, and platform utility methods. |
| [UTIL_TypeResolver](apex/UTIL_TypeResolver.md) | Utility class containing type resolution components for resolving Apex class types. |

### Controllers

Aura and LWC server-side controllers for UI components.

| Class | Description |
|-------|-------------|
| [CTRL_TableDataSource](apex/CTRL_TableDataSource.md) | Controller class responsible for managing the instantiation of a data source class that supports the table data sourc... |
| [IF_TableDataSource](apex/IF_TableDataSource.md) | Generic Interface for Table data sources |

### Schedulables

Configurable scheduled jobs with metadata-driven scheduling and batch size control.

| Class | Description |
|-------|-------------|
| [DTO_ScheduledParameterDefinition](apex/DTO_ScheduledParameterDefinition.md) | A Data Transfer Object describing a single parameter definition supported by a scheduled job class. |
| [IF_Schedulable](apex/IF_Schedulable.md) | An interface for a Schedulable class that can declare the parameters it supports and receive validated parameter valu... |
| [SCHED_Base](apex/SCHED_Base.md) | Abstract base class for scheduled jobs that support configurable parameters. |
| [SCHED_ProcessLoginHistory](apex/SCHED_ProcessLoginHistory.md) | Scheduled job that runs daily to process login history data. |

### Bulk DML

Batch processors for high-volume field updates and aggregation operations.

| Class | Description |
|-------|-------------|
| [PROC_ExecuteDML](apex/PROC_ExecuteDML.md) | Processor for generic DML operations using the adaptive async framework. |
| [PROC_UpdateFields](apex/PROC_UpdateFields.md) | Processor for bulk field updates using the adaptive async framework. |
| [SCHED_DeactivateUsers](apex/SCHED_DeactivateUsers.md) | Scheduled job to automatically deactivate users who haven't logged in for a specified number of days. |
| [SCHED_PurgeRecords](apex/SCHED_PurgeRecords.md) | A scheduled job that deletes records from a specified Salesforce object based on age or all records, configurable via... |
| [UTIL_BulkUpdates](apex/UTIL_BulkUpdates.md) | Utility methods used to initialize adaptive async jobs to update fields on multiple objects. |
| [UTIL_PurgeRecords](apex/UTIL_PurgeRecords.md) | Provides utility methods for purging records from Salesforce objects using adaptive async processing. |

### Testing

Test data factories, mock builders, and test helpers. Use `TST_Builder` for record creation and `TST_Mock` for DML-free query interception.

| Class | Description |
|-------|-------------|
| [TST_Builder](apex/TST_Builder.md) | An advanced factory for creating and inserting SObject records for Apex tests. |
| [TST_Factory](apex/TST_Factory.md) | Factory class for generating test data, permission set assignments, share records, metadata updates, and failure logs... |
| [TST_Mock](apex/TST_Mock.md) | Central registry and fluent builder for mock SObjects. |
| [API_InboundTestHelper](apex/API_InboundTestHelper.md) | Class has base methods that can be used to assist with testing inbound service calls |
| [API_OutboundTestHelper](apex/API_OutboundTestHelper.md) | Class has base methods that can be used to test an outbound service. |
| [UTIL_SObjectBuilderDefaultProvider](apex/UTIL_SObjectBuilderDefaultProvider.md) | Provides the default value generation logic for the SObjectBuilder. |
| [UTIL_ValidationTestHelper](apex/UTIL_ValidationTestHelper.md) | Reusable utility class for testing validation rules. |

### Uncategorized

| Class | Description |
|-------|-------------|
| [API_Base.HttpMethod](apex/API_Base.HttpMethod.md) | HTTP method verbs for web service calls. |
| [API_Base.ServiceCallResult](apex/API_Base.ServiceCallResult.md) | Tracks the request, response, and status of a web service call. |
| [API_Base.WebserviceStatus](apex/API_Base.WebserviceStatus.md) | Enum representing the status of a web service call. |
| [API_MockFactory.MockBuilder](apex/API_MockFactory.MockBuilder.md) | Fluent builder for constructing and registering mock responses. |
| [API_MockFactory.MockResponse](apex/API_MockFactory.MockResponse.md) | Represents a mock HTTP response with fault simulation options. |
| [DML_Builder.DatabaseOperation](apex/DML_Builder.DatabaseOperation.md) | Enum to specify the type of DML operation for external use. |
| [DML_Builder.DML_AsyncBuilder](apex/DML_Builder.DML_AsyncBuilder.md) | Async DML execution wrapper. |
| [DML_Builder.TransactionResult](apex/DML_Builder.TransactionResult.md) | Result object returned by execute() containing the outcome of all DML operations in the transaction. |
| [DTO_BaseTable.DTO_Column](apex/DTO_BaseTable.DTO_Column.md) | Represents a column in the DTO_BaseTable, containing properties for label, field name, type, and sorting ability. |
| [DTO_ScheduledParameterDefinition.DataType](apex/DTO_ScheduledParameterDefinition.DataType.md) | Enumeration of supported input data types for scheduled job parameters. |
| [FLOW_BypassTrigger.DTO_Request](apex/FLOW_BypassTrigger.DTO_Request.md) | Request DTO for the Trigger Bypass invocable action. |
| [FLOW_BypassValidation.DTO_Request](apex/FLOW_BypassValidation.DTO_Request.md) | Request DTO for the Bypass Validation invocable action. |
| [FLOW_CallApi.DTO_Request](apex/FLOW_CallApi.DTO_Request.md) | Data Transfer Object representing the web service call request. |
| [FLOW_CallApi.DTO_Response](apex/FLOW_CallApi.DTO_Response.md) | Data Transfer Object representing the web service response or errors. |
| [FLOW_CheckObjectPermissions.DTO_Request](apex/FLOW_CheckObjectPermissions.DTO_Request.md) | DTO containing the name of the object for which to object permissions |
| [FLOW_CheckObjectPermissions.DTO_Response](apex/FLOW_CheckObjectPermissions.DTO_Response.md) | DTO containing the permissions per object provided in request. |
| [FLOW_CheckTriggerBypassed.DTO_Request](apex/FLOW_CheckTriggerBypassed.DTO_Request.md) | A DTO indicating what action has been bypassed |
| [FLOW_ClearValidationBypass.DTO_Request](apex/FLOW_ClearValidationBypass.DTO_Request.md) | Request DTO for the Clear Validation Bypass invocable action. |
| [FLOW_ExecuteValidationRules.DTO_Request](apex/FLOW_ExecuteValidationRules.DTO_Request.md) | Request DTO for the Execute Validation Rules invocable action. |
| [FLOW_ExecuteValidationRules.DTO_Response](apex/FLOW_ExecuteValidationRules.DTO_Response.md) | Response DTO for the Execute Validation Rules invocable action. |
| [FLOW_GetPicklistValues.DTO_Request](apex/FLOW_GetPicklistValues.DTO_Request.md) | Request DTO containing the information required to retrieve picklist values. |
| [FLOW_GetPicklistValues.DTO_Response](apex/FLOW_GetPicklistValues.DTO_Response.md) | Provides the outcome of the picklist values retrieval. |
| [FLOW_LoggerEnd.DTO_Request](apex/FLOW_LoggerEnd.DTO_Request.md) | Input parameters for ending Flow correlation. |
| [FLOW_LoggerLog.DTO_Request](apex/FLOW_LoggerLog.DTO_Request.md) | Input parameters for logging a Flow event. |
| [FLOW_LoggerStart.DTO_Request](apex/FLOW_LoggerStart.DTO_Request.md) | Input parameters for starting Flow correlation. |
| [FLOW_LoggerStart.DTO_Response](apex/FLOW_LoggerStart.DTO_Response.md) | Output containing the generated correlation ID. |
| [FLOW_SendEmail.DTO_Request](apex/FLOW_SendEmail.DTO_Request.md) | Data Transfer Object (DTO) representing the input parameters for a single email request. |
| [FLOW_SendEmail.DTO_Response](apex/FLOW_SendEmail.DTO_Response.md) | Data Transfer Object (DTO) representing the outcome of an email request. |
| [FLOW_WriteLog.DTO_Request](apex/FLOW_WriteLog.DTO_Request.md) | Data Transfer Object (DTO) for log requests, specifying log level, message details, and context. |
| [IF_Async.AsynchronousExecutionStrategy](apex/IF_Async.AsynchronousExecutionStrategy.md) | Enum defining different asynchronous execution strategies. |
| [IF_Async.Finishable](apex/IF_Async.Finishable.md) | Optional interface for defining finalizer logic that runs after all data is processed. |
| [IF_Async.Processable](apex/IF_Async.Processable.md) | Interface for defining the core processing logic to be executed by an asynchronous job. |
| [IF_Chain.Step](apex/IF_Chain.Step.md) | Interface for defining the business logic of a single chain step. |
| [IF_Trigger.AfterDelete](apex/IF_Trigger.AfterDelete.md) | Handler contract for the after-delete trigger event. |
| [IF_Trigger.AfterInsert](apex/IF_Trigger.AfterInsert.md) | Handler contract for the after-insert trigger event. |
| [IF_Trigger.AfterUndelete](apex/IF_Trigger.AfterUndelete.md) | Handler contract for the after-undelete trigger event. |
| [IF_Trigger.AfterUpdate](apex/IF_Trigger.AfterUpdate.md) | Handler contract for the after-update trigger event. |
| [IF_Trigger.BeforeDelete](apex/IF_Trigger.BeforeDelete.md) | Handler contract for the before-delete trigger event. |
| [IF_Trigger.BeforeInsert](apex/IF_Trigger.BeforeInsert.md) | Handler contract for the before-insert trigger event. |
| [IF_Trigger.BeforeUpdate](apex/IF_Trigger.BeforeUpdate.md) | Handler contract for the before-update trigger event. |
| [LOG_Builder.LogEntry](apex/LOG_Builder.LogEntry.md) | Fluent builder for constructing rich log entries with context. |
| [LOG_Builder.LogScope](apex/LOG_Builder.LogScope.md) | A logging scope that buffers log entries until closed. |
| [PROC_UpdateFields.DTO_Field](apex/PROC_UpdateFields.DTO_Field.md) | DTO representing a field to update on an SObject. |
| [PROC_UpdateFields.DTO_Parameters](apex/PROC_UpdateFields.DTO_Parameters.md) | DTO for parameters to query and update records. |
| [PROC_UpdateFields.FieldUpdateMethod](apex/PROC_UpdateFields.FieldUpdateMethod.md) | Enum defining methods for updating SObject fields. |
| [QRY_Builder.AggregateRow](apex/QRY_Builder.AggregateRow.md) | Typed wrapper around AggregateResult for convenient value access. |
| [QRY_Builder.Builder](apex/QRY_Builder.Builder.md) | Extensible query builder class. |
| [QRY_Builder.ConditionBuilder](apex/QRY_Builder.ConditionBuilder.md) | Fluent builder for field-level conditions (WHERE and HAVING). |
| [QRY_Builder.DataCategoryBuilder](apex/QRY_Builder.DataCategoryBuilder.md) | Fluent builder for WITH DATA CATEGORY filters. |
| [QRY_Builder.QueryPage](apex/QRY_Builder.QueryPage.md) | Result container for paged queries, providing records and pagination metadata. |
| [QRY_Builder.Scope](apex/QRY_Builder.Scope.md) | Enumeration of valid SOQL scope values for use with the USING SCOPE clause. |
| [QRY_Condition.AndCondition](apex/QRY_Condition.AndCondition.md) | Represents a SOQL "AND" condition group. |
| [QRY_Condition.DateLiteral](apex/QRY_Condition.DateLiteral.md) | Provides SOQL date literal values for use in QRY_Builder conditions. |
| [QRY_Condition.Evaluable](apex/QRY_Condition.Evaluable.md) | Interface for condition classes. |
| [QRY_Condition.FieldCondition](apex/QRY_Condition.FieldCondition.md) | Represents a condition in a SOQL WHERE clause based on a specific field, operator, and value. |
| [QRY_Condition.Nestable](apex/QRY_Condition.Nestable.md) | Interface for condition containers that support adding nested conditions. |
| [QRY_Condition.Operator](apex/QRY_Condition.Operator.md) | SOQL comparison operators used to build query conditions. |
| [QRY_Condition.OrCondition](apex/QRY_Condition.OrCondition.md) | Represents a SOQL "OR" condition group. |
| [QRY_Condition.SoqlOptions](apex/QRY_Condition.SoqlOptions.md) | Options for SOQL generation. |
| [QRY_Condition.UnitOfTime](apex/QRY_Condition.UnitOfTime.md) | Units of time for SOQL date literals. |
| [SEL_Hierarchy.Selector](apex/SEL_Hierarchy.Selector.md) | Selector class that provides hierarchy operations for a specific SObject type. |
| [SEL_ObjectPermission.ObjectPermissionType](apex/SEL_ObjectPermission.ObjectPermissionType.md) | A Permission that a User might have on a SObjectType. |
| [SVC_Omnistudio.OmniCallable](apex/SVC_Omnistudio.OmniCallable.md) | A global inner interface that allows the SVC_Omnistudio class to instantiate a class and perform an operation within ... |
| [SVC_Omnistudio.Parameters](apex/SVC_Omnistudio.Parameters.md) | A Data Transfer Object (DTO) used to wrap the original parameters provided by Omnistudio, organizing them into distin... |
| [TRG_ApiCall](apex/TRG_ApiCall.md) | Trigger on ApiCall__c. |
| [TRG_ApiIssue](apex/TRG_ApiIssue.md) | Trigger on ApiIssue__c. |
| [TRG_AsyncChainExecution](apex/TRG_AsyncChainExecution.md) | Trigger on AsyncChainExecution__c. |
| [TRG_Base.BypassType](apex/TRG_Base.BypassType.md) | Indicates the type of trigger bypass being applied. |
| [TRG_Foobar](apex/TRG_Foobar.md) | Example trigger demonstrating the Trigger Action framework |
| [TRG_LogEntryEvent](apex/TRG_LogEntryEvent.md) | Log entry event trigger for handling log events |
| [TRG_ScheduledJob](apex/TRG_ScheduledJob.md) | TRG_ScheduledJob activated by saving Scheduled Job records (rule: 1 record per periodic job setting) |
| [TST_Builder.Builder](apex/TST_Builder.Builder.md) | A fluid builder for configuring and creating SObject records. |
| [TST_Builder.DefaultFieldValueProvider](apex/TST_Builder.DefaultFieldValueProvider.md) | Base class for field-level default value providers. |
| [TST_Builder.DefaultValueProvider](apex/TST_Builder.DefaultValueProvider.md) | Base class for default value providers. |
| [TST_InvokeFlowMock.MockBuilder](apex/TST_InvokeFlowMock.MockBuilder.md) | Fluent builder for registering a mock flow response. |
| [TST_Mock.MockBuilder](apex/TST_Mock.MockBuilder.md) | Fluent builder wrapper that delegates to TST_Builder.Builder for record construction and auto-registers built records... |
| [UTIL_AsyncChain.ApiStep](apex/UTIL_AsyncChain.ApiStep.md) | Chain step adapter that executes any API_Outbound handler as part of an async chain. |
| [UTIL_AsyncChain.ChainBuilder](apex/UTIL_AsyncChain.ChainBuilder.md) | Fluent builder for configuring and executing an async chain. |
| [UTIL_AsyncChain.ChainContext](apex/UTIL_AsyncChain.ChainContext.md) | Shared state container passed between chain steps. |
| [UTIL_AsyncChain.ChainStep](apex/UTIL_AsyncChain.ChainStep.md) | Abstract base class for individual steps in an async chain. |
| [UTIL_AsyncChain.StepResult](apex/UTIL_AsyncChain.StepResult.md) | Immutable result object returned by each ChainStep to indicate success or failure. |
| [UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest](apex/UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest.md) | Request object for initiating an asynchronous process. |
| [UTIL_Cache.OperationResult](apex/UTIL_Cache.OperationResult.md) | Result of a cache operation with detailed status information |
| [UTIL_Cache.Scope](apex/UTIL_Cache.Scope.md) | Cache type enumeration |
| [UTIL_Cache.Status](apex/UTIL_Cache.Status.md) | Operation status enumeration |
| [UTIL_Cache.Store](apex/UTIL_Cache.Store.md) | Interface for Platform Cache operations |
| [UTIL_CircuitBreaker.Breaker](apex/UTIL_CircuitBreaker.Breaker.md) | Interface for circuit breaker operations. |
| [UTIL_CircuitBreaker.Metrics](apex/UTIL_CircuitBreaker.Metrics.md) | Public class containing circuit breaker metrics |
| [UTIL_CircuitBreaker.OpenException](apex/UTIL_CircuitBreaker.OpenException.md) | Exception thrown when circuit breaker is OPEN and blocks a request |
| [UTIL_CircuitBreaker.ProtectedAction](apex/UTIL_CircuitBreaker.ProtectedAction.md) | Interface for code that needs circuit breaker protection (no return value) Implement this interface to use the simpli... |
| [UTIL_CircuitBreaker.Provider](apex/UTIL_CircuitBreaker.Provider.md) | Interface for code that needs circuit breaker protection (with return value) Implement this interface when your actio... |
| [UTIL_CircuitBreaker.State](apex/UTIL_CircuitBreaker.State.md) | Enum representing the circuit breaker state |
| [UTIL_Email.DeliverabilityAccessLevel](apex/UTIL_Email.DeliverabilityAccessLevel.md) | Enum representing the three possible email deliverability settings in a Salesforce org. |
| [UTIL_FeatureFlag.INT_FeatureFlagStrategy](apex/UTIL_FeatureFlag.INT_FeatureFlagStrategy.md) | The global interface for all feature evaluation strategies. |
| [UTIL_FeatureFlag.INT_UserAwareFeatureFlagStrategy](apex/UTIL_FeatureFlag.INT_UserAwareFeatureFlagStrategy.md) | Extended interface for custom strategies that support user context evaluation. |
| [UTIL_FormulaContext.AccountContext](apex/UTIL_FormulaContext.AccountContext.md) | Formula evaluation context for Account object. |
| [UTIL_FormulaContext.CampaignContext](apex/UTIL_FormulaContext.CampaignContext.md) | Formula evaluation context for Campaign object. |
| [UTIL_FormulaContext.CaseContext](apex/UTIL_FormulaContext.CaseContext.md) | Formula evaluation context for Case object. |
| [UTIL_FormulaContext.ContactContext](apex/UTIL_FormulaContext.ContactContext.md) | Formula evaluation context for Contact object. |
| [UTIL_FormulaContext.EventContext](apex/UTIL_FormulaContext.EventContext.md) | Formula evaluation context for Event object. |
| [UTIL_FormulaContext.FoobarContext](apex/UTIL_FormulaContext.FoobarContext.md) | Formula evaluation context for Foobar__c test object. |
| [UTIL_FormulaContext.LeadContext](apex/UTIL_FormulaContext.LeadContext.md) | Formula evaluation context for Lead object. |
| [UTIL_FormulaContext.OpportunityContext](apex/UTIL_FormulaContext.OpportunityContext.md) | Formula evaluation context for Opportunity object. |
| [UTIL_FormulaContext.TaskContext](apex/UTIL_FormulaContext.TaskContext.md) | Formula evaluation context for Task object. |
| [UTIL_FormulaContext.UserContext](apex/UTIL_FormulaContext.UserContext.md) | Formula evaluation context for User object. |
| [UTIL_FormulaFilter.DTO_FilterResults](apex/UTIL_FormulaFilter.DTO_FilterResults.md) | Inner class representing the result of the filter method. |
| [UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext](apex/UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext.md) | Interface for providing context data to dynamic formula evaluations using Salesforce's FormulaEval namespace. |
| [UTIL_HttpClient.FailureAction](apex/UTIL_HttpClient.FailureAction.md) | Defines the action to take when an HTTP call fails. |
| [UTIL_HttpClient.RequestBuilder](apex/UTIL_HttpClient.RequestBuilder.md) | Fluent builder for configuring and executing HTTP requests through API_Dispatcher. |
| [UTIL_Limits.LimitCheck](apex/UTIL_Limits.LimitCheck.md) | Fluent limit inspector scoped to a single governor limit type. |
| [UTIL_Map.CaseInsensitiveMap](apex/UTIL_Map.CaseInsensitiveMap.md) | A Map implementation that performs case-insensitive key lookups. |
| [UTIL_Retry.Context](apex/UTIL_Retry.Context.md) | Interface defining the retry context. |
| [UTIL_Retry.Strategy](apex/UTIL_Retry.Strategy.md) | Interface defining the retry strategy logic. |
| [UTIL_SObjectDescribe.FieldListBuilder](apex/UTIL_SObjectDescribe.FieldListBuilder.md) | Builds a comma-separated field list from SObjectField tokens and optional FieldSet definitions. |
| [UTIL_SObjectDescribe.FieldsMap](apex/UTIL_SObjectDescribe.FieldsMap.md) | A subclass of NamespacedAttributeMap for handling field maps returned by DescribeSObjectResult.fields.getMap(). |
| [UTIL_SObjectDescribe.GlobalDescribeMap](apex/UTIL_SObjectDescribe.GlobalDescribeMap.md) | A subclass of NamespacedAttributeMap for handling global describe data returned by getGlobalDescribe. |
| [UTIL_TypeResolver.BaseClassResolver](apex/UTIL_TypeResolver.BaseClassResolver.md) | Abstract base class for implementing custom type resolvers, typically registered via custom metadata. |
| [UTIL_TypeResolver.INT_ClassTypeResolver](apex/UTIL_TypeResolver.INT_ClassTypeResolver.md) | Interface for resolving Type objects from class names and chaining resolvers. |
| [UTIL_ValidationRule.INT_BulkValidationContext](apex/UTIL_ValidationRule.INT_BulkValidationContext.md) | Optional interface for bulk-optimized validation contexts. |
| [UTIL_ValidationRule.ValidationError](apex/UTIL_ValidationRule.ValidationError.md) | Represents a single validation error or warning. |
| [UTIL_ValidationRule.ValidationResult](apex/UTIL_ValidationRule.ValidationResult.md) | Result of validating a single record. |

### Validation

| Class | Description |
|-------|-------------|
| [FLOW_BypassValidation](apex/FLOW_BypassValidation.md) | Flow invocable action to bypass validation rules for the current transaction. |
| [FLOW_ClearValidationBypass](apex/FLOW_ClearValidationBypass.md) | Flow invocable action to clear validation rule bypasses for the current transaction. |
| [FLOW_ExecuteValidationRules](apex/FLOW_ExecuteValidationRules.md) | Flow invocable action to execute validation rules against records. |
| [TRG_ExecuteValidationRules](apex/TRG_ExecuteValidationRules.md) | Pre-built trigger action that executes formula-driven validation rules. |
| [UTIL_ValidationRule](apex/UTIL_ValidationRule.md) | Formula-driven declarative validation framework for advanced validation scenarios that standard Salesforce validation... |

### Email

| Class | Description |
|-------|-------------|
| [FLOW_SendEmail](apex/FLOW_SendEmail.md) | Provides an invocable entry point for sending emails via Salesforce Flow with advanced capabilities. |
| [UTIL_Email](apex/UTIL_Email.md) | Utility class for validating and sending emails within the Salesforce platform. |

### Async

| Class | Description |
|-------|-------------|
| [IF_Chain](apex/IF_Chain.md) | A container for shared global interfaces used by the async chain orchestration framework. |
| [UTIL_AsyncChain](apex/UTIL_AsyncChain.md) | Lightweight async chain runner for sequencing jobs with shared state, error handling, and progress tracking. |

### Omnistudio

| Class | Description |
|-------|-------------|
| [SVC_Omnistudio](apex/SVC_Omnistudio.md) | SVC_Omnistudio is a factory class that implements the Callable interface and is designed to instantiate and execute o... |

### Trigger Framework

| Class | Description |
|-------|-------------|
| [TST_InvokeFlowMock](apex/TST_InvokeFlowMock.md) | Test mock harness for TRG_InvokeFlow-dispatched flows. |

### Data Masking

| Class | Description |
|-------|-------------|
| [UTIL_Exceptions.MaskingBlockedException](apex/UTIL_Exceptions.MaskingBlockedException.md) | Thrown when a masking rule configured with FailureAction__c = BlockDml fails. |

---

## Custom Objects

| Object | Description |
|--------|-------------|
| [ApiCall__c](objects/ApiCall__c.md) | Tracks API calls (inbound and outbound) through their full lifecycle. |
| [ApiIssue__c](objects/ApiIssue__c.md) | Tracks API integration issues for troubleshooting, manual resolution, and automatic retry of failed service calls. |
| [ApiRuntimeSwitch__c](objects/ApiRuntimeSwitch__c.md) | Hierarchical custom setting that provides runtime API kill switches at the org, profile, or user level. |
| [AsyncChainExecution__c](objects/AsyncChainExecution__c.md) | Tracks async chain executions including state, step definitions, shared context, and progress. |
| [Foobar__c](objects/Foobar__c.md) | Test object for managed package unit tests. |
| [LogEntry__c](objects/LogEntry__c.md) | Persistent log entries captured by the Kern logging framework. |
| [LoginFrequency__c](objects/LoginFrequency__c.md) | Tracks monthly login activity per user, including total login count and number of unique days logged in. |
| [LogSetting__c](objects/LogSetting__c.md) | Controls logging behaviour: log level threshold, class filtering, performance logging thresholds, and context data si... |
| [ScheduledJob__c](objects/ScheduledJob__c.md) | Declarative scheduled job configuration. |
| [ScheduleSetting__c](objects/ScheduleSetting__c.md) | Stores runtime state for scheduled jobs, such as the last successful execution time. |

---

## Platform Events

| Event | Description |
|--------|-------------|
| [LogEntryEvent__e](events/LogEntryEvent__e.md) | High-volume platform event that transports log data asynchronously. |

---

## Custom Metadata Types

| Metadata | Description |
|--------|-------------|
| [ApiCredential__mdt](metadata/ApiCredential__mdt.md) | Links outbound API handlers to their Salesforce Named Credential for endpoint resolution and authentication. |
| [ApiMock__mdt](metadata/ApiMock__mdt.md) | Configures mock response scenarios for API services. |
| [ApiSetting__mdt](metadata/ApiSetting__mdt.md) | Configures outbound web service handlers with endpoint paths, retry behavior, circuit breaker settings, and failure l... |
| [AsynchronousJobSetting__mdt](metadata/AsynchronousJobSetting__mdt.md) | Declarative configuration for asynchronous job classes. |
| [ClassTypeResolver__mdt](metadata/ClassTypeResolver__mdt.md) | Registers a subscriber-org class that resolves Apex class names to Types at runtime. |
| [FeatureFlag__mdt](metadata/FeatureFlag__mdt.md) | This object is the master record for a single feature flag. |
| [FeatureFlagStrategy__mdt](metadata/FeatureFlagStrategy__mdt.md) | Defines a single evaluation rule for a parent Feature Flag. |
| [FieldSetGroup__mdt](metadata/FieldSetGroup__mdt.md) | Groups multiple field sets for an object into a single configuration record. |
| [MaskingRule__mdt](metadata/MaskingRule__mdt.md) | Defines a rule for masking sensitive data in a field — what to look for and what to replace it with. |
| [MaskingTarget__mdt](metadata/MaskingTarget__mdt.md) | Applies a Masking Rule to a specific field on a specific object. |
| [TriggerAction__mdt](metadata/TriggerAction__mdt.md) | Registers a single trigger action: one Apex class bound to one trigger event (e.g. |
| [TriggerSetting__mdt](metadata/TriggerSetting__mdt.md) | Parent configuration for all trigger actions on a single object. |
| [ValidationRule__mdt](metadata/ValidationRule__mdt.md) | Defines an individual validation rule with a formula-based condition, error message, and configuration options. |
| [ValidationRuleGroup__mdt](metadata/ValidationRuleGroup__mdt.md) | Groups validation rules for a specific object and trigger context. |

---

*Generated from IcApexDoc*
