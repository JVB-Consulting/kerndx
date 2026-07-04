// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Controller for the Chain Monitor LWC components. Provides methods to query, filter,
 * sort, and paginate chain executions, and to retrieve parsed step detail DTOs. The LWC layer
 * receives display-ready DTOs and does not parse the StepLog JSON directly.
 *
 * @see CTRL_ChainMonitor_TEST
 * @see SEL_AsyncChainExecution
 * @see UTIL_AsyncChain
 *
 * @author Jason van Beukering
 *
 * @group Controllers
 *
 * @date April 2026, June 2026, July 2026
 */
public with sharing class CTRL_ChainMonitor
{
	/**
	 * @description Default page size for chain list queries.
	 */
	@TestVisible
	private static final Integer DEFAULT_PAGE_SIZE = 20;

	/**
	 * @description Step completed successfully.
	 */
	@TestVisible
	private static final String STEP_STATUS_SUCCESS = 'success';

	/**
	 * @description Step failed but chain continued (continueOnError).
	 */
	@TestVisible
	private static final String STEP_STATUS_WARNING = 'warning';

	/**
	 * @description Step failed and chain stopped.
	 */
	@TestVisible
	private static final String STEP_STATUS_FAILED = 'failed';

	/**
	 * @description Step has not yet executed. The LWC determines which pending step is currently
	 * running based on the chain's Status__c field.
	 */
	@TestVisible
	private static final String STEP_STATUS_PENDING = 'pending';

	/**
	 * @description Map of sortable field names to SObjectField tokens for compile-time safety.
	 */
	private static final Map<String, SObjectField> SORTABLE_FIELDS = new Map<String, SObjectField>
	{
			'ChainName' => AsyncChainExecution__c.ChainName__c,
			'Status' => AsyncChainExecution__c.Status__c,
			'StartedAt' => AsyncChainExecution__c.StartedAt__c,
			'DurationMs' => AsyncChainExecution__c.DurationMs__c,
			'CreatedDate' => AsyncChainExecution__c.CreatedDate
	};

	/**
	 * @description Retrieves a paginated, filtered, and sorted list of chain executions for the
	 * Chain Monitor list view. Delegates to SEL_AsyncChainExecution and uses framework pagination.
	 *
	 * @param requestJson The filter, sort, and pagination parameters.
	 *
	 * @return A DTO_ChainPage with records, pagination metadata, and total count.
	 *
	 * @example
	 * ```apex
	 * CTRL_ChainMonitor.DTO_Request request = new CTRL_ChainMonitor.DTO_Request();
	 * request.statusFilters = new List<String>{'Running', 'Failed'};
	 * request.pageNumber = 1;
	 * CTRL_ChainMonitor.DTO_ChainPage result = CTRL_ChainMonitor.getChainExecutions(request);
	 * ```
	 */
	@AuraEnabled
	public static DTO_ChainPage getChainExecutions(String requestJson)
	{
		DTO_Request request = String.isBlank(requestJson)
				? new DTO_Request()
				: (DTO_Request)JSON.deserialize(requestJson, DTO_Request.class);

		SObjectField resolvedSortField = SORTABLE_FIELDS.get(request.sortField);
		if(resolvedSortField == null)
		{
			resolvedSortField = AsyncChainExecution__c.CreatedDate;
		}

		Integer resolvedPageSize = request.pageSize != null && request.pageSize > 0 ? request.pageSize : DEFAULT_PAGE_SIZE;
		Integer resolvedPageNumber = request.pageNumber != null && request.pageNumber > 0 ? request.pageNumber : 1;

		QRY_Builder.QueryPage page = new SEL_AsyncChainExecution().findFiltered
				(
						request.statusFilters, request.nameFilter, resolvedSortField,
						request.sortAscending != true, resolvedPageNumber, resolvedPageSize
				);

		List<DTO_ChainSummary> summaries = new List<DTO_ChainSummary>();
		for(SObject record : page.records)
		{
			summaries.add(toChainSummary((AsyncChainExecution__c)record));
		}

		DTO_ChainPage result = new DTO_ChainPage();

		result.hasMorePages = page.hasMorePages;
		result.pageNumber = page.pageNumber;
		result.records = summaries;
		result.totalCount = page.totalRecords;
		result.totalPages = page.totalPages;

		return result;
	}

	/**
	 * @description Retrieves the full detail of a chain execution, including parsed step definitions
	 * as display-ready DTOs.
	 *
	 * @param executionId The ID of the AsyncChainExecution__c record.
	 *
	 * @return A DTO_ChainDetail with all chain metadata and parsed step details. Null if not found.
	 *
	 * @example
	 * ```apex
	 * CTRL_ChainMonitor.DTO_ChainDetail detail = CTRL_ChainMonitor.getChainDetail(executionId);
	 * ```
	 */
	@AuraEnabled
	public static DTO_ChainDetail getChainDetail(Id executionId)
	{
		AsyncChainExecution__c execution = new SEL_AsyncChainExecution().findByIdForMonitoring(executionId);

		if(execution == null)
		{
			return null;
		}

		return toChainDetail(execution);
	}

	/**
	 * @description Retrieves parsed step definitions for a single chain execution. Lightweight method
	 * for the embedded record page component that only needs the step timeline.
	 *
	 * @param executionId The ID of the AsyncChainExecution__c record.
	 *
	 * @return List of DTO_StepDetail representing each step in the chain. Empty list if not found.
	 *
	 * @example
	 * ```apex
	 * List<CTRL_ChainMonitor.DTO_StepDetail> steps = CTRL_ChainMonitor.getStepTimeline(executionId);
	 * ```
	 */
	@AuraEnabled(Cacheable=true)
	public static List<DTO_StepDetail> getStepTimeline(Id executionId)
	{
		AsyncChainExecution__c execution = new SEL_AsyncChainExecution().findByIdForMonitoring(executionId);

		if(execution == null)
		{
			return new List<DTO_StepDetail>();
		}

		return parseSteps(execution);
	}

	/**
	 * @description Resolves the chain execution that carries a correlation id, so a deep link
	 * arriving from the Log Console lands on the linked chain instead of the default selection.
	 * Uses the monitoring read, which sees chains org-wide exactly as the console's list does.
	 *
	 * @param correlationId The correlation id carried by the deep link.
	 *
	 * @return The Id of the matching AsyncChainExecution__c record, or null when the correlation
	 * id is blank or no registered chain carries it.
	 *
	 * @date July 2026
	 *
	 * @example
	 * ```apex
	 * Id executionId = CTRL_ChainMonitor.findChainExecutionIdByCorrelation('550e8400-e29b-41d4-a716-446655440000');
	 * ```
	 */
	@AuraEnabled
	public static Id findChainExecutionIdByCorrelation(String correlationId)
	{
		return new SEL_AsyncChainExecution().findByCorrelationIdForMonitoring(correlationId)?.Id;
	}

	/**
	 * @description Converts an AsyncChainExecution__c record to a summary DTO for the list view.
	 *
	 * @param record The AsyncChainExecution__c record.
	 *
	 * @return A populated DTO_ChainSummary.
	 */
	private static DTO_ChainSummary toChainSummary(AsyncChainExecution__c record)
	{
		DTO_ChainSummary summary = new DTO_ChainSummary();

		summary.executionId = record.Id;
		summary.chainName = record.ChainName__c;
		summary.status = record.Status__c;
		summary.completedSteps = record.CompletedSteps__c != null ? record.CompletedSteps__c.intValue() : 0;
		summary.totalSteps = record.TotalSteps__c != null ? record.TotalSteps__c.intValue() : 0;
		summary.startedAt = record.StartedAt__c;
		summary.durationMs = record.DurationMs__c?.longValue();
		summary.durationLabel = UTIL_Date.formatDuration(summary.durationMs);

		return summary;
	}

	/**
	 * @description Converts an AsyncChainExecution__c record to a full detail DTO with parsed steps.
	 *
	 * @param execution The AsyncChainExecution__c record.
	 *
	 * @return A populated DTO_ChainDetail.
	 */
	private static DTO_ChainDetail toChainDetail(AsyncChainExecution__c execution)
	{
		DTO_ChainDetail detail = new DTO_ChainDetail();

		detail.chainName = execution.ChainName__c;
		detail.completedAt = execution.CompletedAt__c;
		detail.completedSteps = execution.CompletedSteps__c != null ? execution.CompletedSteps__c.intValue() : 0;
		detail.correlationId = execution.CorrelationId__c;
		detail.errorMessage = execution.ErrorMessage__c;
		detail.executionId = execution.Id;
		detail.startedAt = execution.StartedAt__c;
		detail.status = execution.Status__c;
		detail.totalSteps = execution.TotalSteps__c != null ? execution.TotalSteps__c.intValue() : 0;

		if(execution.DurationMs__c != null)
		{
			detail.durationMs = execution.DurationMs__c.longValue();
		}
		else if(execution.StartedAt__c != null && execution.Status__c == SEL_AsyncChainExecution.STATUS_RUNNING)
		{
			detail.durationMs = Datetime.now().getTime() - execution.StartedAt__c.getTime();
		}

		detail.durationLabel = UTIL_Date.formatDuration(detail.durationMs);
		detail.steps = parseSteps(execution);
		return detail;
	}

	/**
	 * @description Parses the StepLog__c JSON into a list of display-ready step DTOs using typed
	 * deserialization via UTIL_AsyncChain.DTO_StepDefinition. Determines step status based on runtime
	 * fields, chain status, and step index.
	 *
	 * @param execution The AsyncChainExecution__c record containing the StepLog__c JSON.
	 *
	 * @return List of DTO_StepDetail. Empty list if StepLog is blank.
	 */
	@TestVisible
	private static List<DTO_StepDetail> parseSteps(AsyncChainExecution__c execution)
	{
		List<DTO_StepDetail> results = new List<DTO_StepDetail>();

		if(String.isBlank(execution.StepLog__c))
		{
			return results;
		}

		List<UTIL_AsyncChain.DTO_StepDefinition> definitions =
				(List<UTIL_AsyncChain.DTO_StepDefinition>)JSON.deserialize(execution.StepLog__c, List<UTIL_AsyncChain.DTO_StepDefinition>.class);

		for(UTIL_AsyncChain.DTO_StepDefinition definition : definitions)
		{
			DTO_StepDetail step = new DTO_StepDetail();

			step.className = definition.className;
			step.stepName = definition.stepName;
			step.name = String.isNotBlank(definition.stepName) ? definition.stepName : definition.className;
			step.continueOnError = definition.continueOnError == true;
			step.success = definition.success;
			step.errorMessage = definition.message;

			if(definition.durationMs != null)
			{
				step.durationMs = definition.durationMs;
				step.durationLabel = UTIL_Date.formatDuration(definition.durationMs);
			}

			if(step.success == true)
			{
				step.stepStatus = STEP_STATUS_SUCCESS;
			}
			else if(step.success == false && step.continueOnError)
			{
				step.stepStatus = STEP_STATUS_WARNING;
			}
			else if(step.success == false)
			{
				step.stepStatus = STEP_STATUS_FAILED;
			}
			else
			{
				step.stepStatus = STEP_STATUS_PENDING;
			}

			results.add(step);
		}

		return results;
	}

	/**
	 * @description Request DTO for the chain list view. Encapsulates filter, sort, and pagination
	 * parameters in a single object instead of individual method parameters.
	 */
	public class DTO_Request
	{
		/**
		 * @description Status values to filter on. Null or empty returns all statuses.
		 */
		@AuraEnabled
		public List<String> statusFilters;

		/**
		 * @description Chain name search string (LIKE filter). Null or blank returns all names.
		 */
		@AuraEnabled
		public String nameFilter;

		/**
		 * @description Field name to sort by. Must be a key in SORTABLE_FIELDS. Defaults to CreatedDate.
		 */
		@AuraEnabled
		public String sortField;

		/**
		 * @description Sort ascending when true, descending when false or null.
		 */
		@AuraEnabled
		public Boolean sortAscending;

		/**
		 * @description Number of records per page. Defaults to 20.
		 */
		@AuraEnabled
		public Integer pageSize;

		/**
		 * @description The 1-based page number. Defaults to 1.
		 */
		@AuraEnabled
		public Integer pageNumber;
	}

	/**
	 * @description Paginated response DTO for the chain list view. Wraps summary records with
	 * pagination metadata from QRY_Builder.QueryPage.
	 */
	public class DTO_ChainPage
	{
		/**
		 * @description The chain summary records for the current page.
		 */
		@AuraEnabled
		public List<DTO_ChainSummary> records;

		/**
		 * @description Total number of records matching the filter criteria.
		 */
		@AuraEnabled
		public Integer totalCount;

		/**
		 * @description The current 1-based page number.
		 */
		@AuraEnabled
		public Integer pageNumber;

		/**
		 * @description Total number of pages available.
		 */
		@AuraEnabled
		public Integer totalPages;

		/**
		 * @description True if there are more pages after the current page.
		 */
		@AuraEnabled
		public Boolean hasMorePages;
	}

	/**
	 * @description Summary DTO for the chain list view. Contains only the fields needed for table display.
	 */
	public class DTO_ChainSummary
	{
		/**
		 * @description The AsyncChainExecution__c record ID.
		 */
		@AuraEnabled
		public Id executionId;

		/**
		 * @description The chain name.
		 */
		@AuraEnabled
		public String chainName;

		/**
		 * @description The current chain status.
		 */
		@AuraEnabled
		public String status;

		/**
		 * @description Number of steps that completed successfully.
		 */
		@AuraEnabled
		public Integer completedSteps;

		/**
		 * @description Total number of steps in the chain.
		 */
		@AuraEnabled
		public Integer totalSteps;

		/**
		 * @description When the chain started.
		 */
		@AuraEnabled
		public Datetime startedAt;

		/**
		 * @description Duration in milliseconds.
		 */
		@AuraEnabled
		public Long durationMs;

		/**
		 * @description Human-readable duration label.
		 */
		@AuraEnabled
		public String durationLabel;
	}

	/**
	 * @description Full detail DTO for the chain detail view. Includes parsed step definitions
	 * and computed timing values.
	 */
	public class DTO_ChainDetail
	{
		/**
		 * @description The AsyncChainExecution__c record ID.
		 */
		@AuraEnabled
		public Id executionId;

		/**
		 * @description The chain name.
		 */
		@AuraEnabled
		public String chainName;

		/**
		 * @description The current chain status.
		 */
		@AuraEnabled
		public String status;

		/**
		 * @description Total number of steps in the chain.
		 */
		@AuraEnabled
		public Integer totalSteps;

		/**
		 * @description Number of steps that completed successfully.
		 */
		@AuraEnabled
		public Integer completedSteps;

		/**
		 * @description Error message if the chain failed.
		 */
		@AuraEnabled
		public String errorMessage;

		/**
		 * @description When the chain started.
		 */
		@AuraEnabled
		public Datetime startedAt;

		/**
		 * @description When the chain completed.
		 */
		@AuraEnabled
		public Datetime completedAt;

		/**
		 * @description Duration in milliseconds. Computed live for running chains.
		 */
		@AuraEnabled
		public Long durationMs;

		/**
		 * @description Human-readable duration label.
		 */
		@AuraEnabled
		public String durationLabel;

		/**
		 * @description Correlation ID for log tracing.
		 */
		@AuraEnabled
		public String correlationId;

		/**
		 * @description Parsed step definitions with display-ready status.
		 */
		@AuraEnabled
		public List<DTO_StepDetail> steps;
	}

	/**
	 * @description Step detail DTO representing a single step in the chain timeline. Includes
	 * pre-computed status icon and variant for direct rendering in the LWC.
	 */
	public class DTO_StepDetail
	{
		/**
		 * @description Display name (stepName if set, otherwise className).
		 */
		@AuraEnabled
		public String name;

		/**
		 * @description The Apex class name.
		 */
		@AuraEnabled
		public String className;

		/**
		 * @description The custom step name.
		 */
		@AuraEnabled
		public String stepName;

		/**
		 * @description Whether the step succeeded. Null if not yet executed.
		 */
		@AuraEnabled
		public Boolean success;

		/**
		 * @description Whether this step continues on error.
		 */
		@AuraEnabled
		public Boolean continueOnError;

		/**
		 * @description Step duration in milliseconds.
		 */
		@AuraEnabled
		public Long durationMs;

		/**
		 * @description Human-readable duration label.
		 */
		@AuraEnabled
		public String durationLabel;

		/**
		 * @description Error message if the step failed.
		 */
		@AuraEnabled
		public String errorMessage;

		/**
		 * @description Semantic step status: success, warning, failed, handler, running, or pending.
		 * The LWC maps this to appropriate icons and variants.
		 */
		@AuraEnabled
		public String stepStatus;
	}
}