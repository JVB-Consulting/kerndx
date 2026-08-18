// SPDX-License-Identifier: BUSL-1.1
/**
 * @description The Chain Monitor's Aura data contracts: the request, page, summary, detail, step,
 * operations-state, sweep-count, and log-stream shapes CTRL_ChainMonitor returns to the monitor
 * LWC components. A pure data holder — no queries, no DML, no behaviour — extracted from the
 * controller so the controller holds only behaviour and stays within design-inspection bounds.
 * The LWC layer consumes these shapes as JSON and never references the Apex type names.
 *
 * @see CTRL_ChainMonitor
 * @see CTRL_ChainMonitor_TEST
 * @see CTRL_ChainMonitorAbort_TEST
 * @see CTRL_ChainMonitorRedrive_TEST
 *
 * @author Jason van Beukering
 *
 * @group Controllers
 *
 * @date August 2026
 */
public inherited sharing class CTRL_ChainMonitorTypes
{
	/**
	 * @description Request DTO for the chain list view. Encapsulates filter, sort, and pagination
	 * parameters in a single object instead of individual method parameters.
	 */
	public inherited sharing class DTO_Request
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
		 * @description Field name to sort by. Must be a sortable field name CTRL_ChainMonitor
		 * recognises. Defaults to CreatedDate.
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
	public inherited sharing class DTO_ChainPage
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
	public inherited sharing class DTO_ChainSummary
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
	public inherited sharing class DTO_ChainDetail
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
		 * @description Why the abort action is or is not available: Available, ChainNotAbortable,
		 * CapabilityDisabled, or PermissionMissing. A stable code, not display text; the client
		 * maps it to a label.
		 */
		@AuraEnabled
		public String abortAvailability;

		/**
		 * @description Why the retry-from-failed-step action is or is not available: Available,
		 * ChainNotRetryable, ChainProcessingSuspended, ContextUnavailable, FailurePermanent,
		 * StepNotIdempotent, CapabilityDisabled, or PermissionMissing. A stable code, not display
		 * text; the client maps it to a label.
		 */
		@AuraEnabled
		public String retryAvailability;

		/**
		 * @description Why the restart-from-start action is or is not available: Available,
		 * ChainNotRestartable, ChainProcessingSuspended, RestartNotDeclared, CapabilityDisabled, or
		 * PermissionMissing. A stable code, not display text; the client maps it to a label.
		 */
		@AuraEnabled
		public String restartAvailability;

		/**
		 * @description The source run this chain was restarted from — the restart lineage lookup,
		 * null for every chain that is not a restart clone.
		 */
		@AuraEnabled
		public Id sourceExecutionId;

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
		 * @description How long the chain's steps actually ran, in milliseconds — the sum of the
		 * recorded step durations. `durationMs` is wall-clock and spans every idle gap between
		 * runs, so an operator re-drive hours after a failure counts those hours as run time; this
		 * is the same run without the waiting. It counts only the MOST RECENT run of each step:
		 * the step log holds one entry per step, an in-chain retry overwrites that entry's duration
		 * with the latest attempt's, and an operator re-drive clears the failed entry's duration
		 * altogether — so no earlier attempt's time is recorded anywhere and none of it is
		 * included here. Null when no step recorded a duration.
		 */
		@AuraEnabled
		public Long activeDurationMs;

		/**
		 * @description Human-readable active-run-time label. Null when no step recorded a duration.
		 */
		@AuraEnabled
		public String activeDurationLabel;

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
	public inherited sharing class DTO_StepDetail
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

	/**
	 * @description Operations-control state for the monitor's list header: the runtime switch's
	 * current answer plus the availability of the two header controls for the running user.
	 */
	public inherited sharing class DTO_OperationsState
	{
		/**
		 * @description Whether async chain processing is currently enabled for the running user's
		 * context — the kill-switch state the header renders.
		 */
		@AuraEnabled
		public Boolean chainProcessingEnabled;

		/**
		 * @description Why the kill-switch toggle is or is not available: Available,
		 * CapabilityDisabled, or PermissionMissing. A stable code, not display text.
		 */
		@AuraEnabled
		public String killSwitchAvailability;

		/**
		 * @description Why the clear-stalled sweep is or is not available: Available,
		 * ChainProcessingSuspended, CapabilityDisabled, or PermissionMissing. A stable code, not
		 * display text.
		 */
		@AuraEnabled
		public String clearStalledAvailability;

		/**
		 * @description How many chains are waiting for the clear-stalled sweep, so its confirmation
		 * dialog can name the number before the operator commits. Zero when nothing is waiting, and
		 * also zero when clearStalledAvailability refuses the sweep: a caller who cannot run it is
		 * not told what it would have found.
		 */
		@AuraEnabled
		public Integer stalledChainCount;
	}

	/**
	 * @description Per-bucket counts of one operator clear-stalled sweep, for the result toast —
	 * the engine tally mapped to an Aura-serializable shape.
	 */
	public inherited sharing class DTO_ClearStalledResult
	{
		/**
		 * @description How many stalled candidates the sweep inspected; always the sum of the other
		 * three counts.
		 */
		@AuraEnabled
		public Integer candidates;

		/**
		 * @description How many candidates were proven dead and re-driven — Running again.
		 */
		@AuraEnabled
		public Integer redriven;

		/**
		 * @description How many candidates were unrecoverable and terminally failed.
		 */
		@AuraEnabled
		public Integer markedFailed;

		/**
		 * @description How many candidates still await recovery — budget-refused, detect-marked,
		 * live-executor skips, and rows the sweep's sharing-respecting legs could not act on alike.
		 */
		@AuraEnabled
		public Integer remainingStalled;
	}

	/**
	 * @description One persisted log entry of the live stream's seed history: the display fields
	 * the stream renders, mapped from the correlated-trace projection.
	 */
	public inherited sharing class DTO_LogStreamEntry
	{
		/**
		 * @description When the entry was recorded.
		 */
		@AuraEnabled
		public Datetime timestamp;

		/**
		 * @description The entry's log level.
		 */
		@AuraEnabled
		public String logLevel;

		/**
		 * @description The entry's short message. The seed deliberately reads the lean trace
		 * projection, which carries no long-text bodies.
		 */
		@AuraEnabled
		public String message;
	}
}