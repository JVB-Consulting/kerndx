// SPDX-License-Identifier: Apache-2.0
/**
 * @description The data shapes that CTRL_ChainMonitor sends to and receives from the Chain Monitor's LWC components:
 * the list request, the page, the summary row, the detail, the step, the header controls, the sweep counts and the
 * log stream entry. This class only holds data. It has no queries, no DML and no behaviour. It was split out of the
 * controller so that the controller holds only behaviour and stays within the size limits of the code inspections.
 * The LWC components read these shapes as JSON and never name the Apex types.
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
 * @date August 2026, October 2026
 */
public inherited sharing class CTRL_ChainMonitorTypes
{
	/**
	 * @description How a run entered its action, in the four cases the Launched-under column shows. The components
	 * receive the value's name as a String.
	 *
	 * @date September 2026
	 */
	public enum LaunchKind
	{
		/**
		 * @description A step of another run launched it, and the launched-under value names that run.
		 */
		CHAIN,
		/**
		 * @description The action's own code launched it, and no run holds the launch id.
		 */
		ACTION,
		/**
		 * @description An operator restarted another run, and this run is the new copy.
		 */
		RESTART,
		/**
		 * @description It started the action itself, with no launch id and no source, a scheduled job for example.
		 */
		ORIGIN
	}

	/**
	 * @description How one run entered its action. It is decided from the run's launch id and its source run. It is one
	 * of the four cases the Launched-under column shows: the launching chain, the action itself, a restart of a named
	 * run, or the run that started the action. This class stays inside Apex. The consoles receive its values as text,
	 * copied onto their own DTOs.
	 *
	 * @date September 2026
	 */
	public inherited sharing class DTO_LaunchOrigin
	{
		/**
		 * @description Which of the four cases applies: a chain launch, an action launch, a restart, or the run that
		 * started the action. The controller copies the value's name onto the console DTOs as text.
		 */
		public LaunchKind launchKind;

		/**
		 * @description The launching chain's name and number for a chain launch, the source run's for a restart; null for
		 * the other two kinds and for a source that no longer exists.
		 */
		public String launchedUnderLabel;

		/**
		 * @description The launching run's id for a chain launch, the source run's for a restart; null otherwise. The
		 * consoles select that run from it.
		 */
		public Id launchedUnderExecutionId;
	}

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

		/**
		 * @description The tracking id of an action. Set, the list keeps to the runs launched under that action and each row
		 * says what launched it. Blank lists every run.
		 */
		@AuraEnabled
		public String rootCorrelationId;
	}

	/**
	 * @description Paginated response DTO for the chain list view. Wraps summary records with
	 * pagination metadata from QRY_Builder.QueryPage.
	 */
	public inherited sharing class DTO_ChainPage
	{
		/**
		 * @description One summary row for each run on this page, in the order of the requested sort. An empty list when
		 * no run matches the filters.
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
		 * @description The name the run's chain was given, copied from the run's ChainName__c field.
		 */
		@AuraEnabled
		public String chainName;

		/**
		 * @description The run's status when the page was read: the value stored in its Status__c field, not a display
		 * label.
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

		/**
		 * @description The tracking id the run was launched under: the parent run's when a step launched it, the action's
		 * otherwise; null for a run that started its own action or was restarted.
		 */
		@AuraEnabled
		public String launchCorrelationId;

		/**
		 * @description How the run entered its action: the `LaunchKind`'s name as text, because the transport to the
		 * components does not convert an enum field. It is filled in only while the list is filtered by an action, and
		 * is null otherwise.
		 */
		@AuraEnabled
		public String launchKind;

		/**
		 * @description The launching run's name and number, or the restart source's. Null for the other kinds, and while
		 * the list is not filtered by an action.
		 */
		@AuraEnabled
		public String launchedUnderLabel;

		/**
		 * @description The launching run's id, or the restart source's, so the column's link can select it; null otherwise.
		 */
		@AuraEnabled
		public Id launchedUnderExecutionId;
	}

	/**
	 * @description Full detail DTO for the chain detail view. Includes parsed step definitions
	 * and computed timing values. A data holder whose public members are the fields the view shows, so the
	 * public-member count rule is suppressed for it.
	 */
	@SuppressWarnings('PMD.ExcessivePublicCount')
	public inherited sharing class DTO_ChainDetail
	{
		/**
		 * @description The AsyncChainExecution__c record ID.
		 */
		@AuraEnabled
		public Id executionId;

		/**
		 * @description The name the run's chain was given, copied from the run's ChainName__c field.
		 */
		@AuraEnabled
		public String chainName;

		/**
		 * @description The run's status when the detail was read: the value stored in its Status__c field, not a display
		 * label.
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
		 * @description The run this chain was restarted from (the SourceExecution__c lookup). Null for every chain that
		 * is not a copy made by a restart.
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
		 * @description Duration in milliseconds: the stored duration, or a live count for a Running or Stalled chain, or
		 * the time between start and end for an ended chain that stored none.
		 */
		@AuraEnabled
		public Long durationMs;

		/**
		 * @description Human-readable duration label.
		 */
		@AuraEnabled
		public String durationLabel;

		/**
		 * @description How long the chain's steps actually ran, in milliseconds: the sum of the recorded step
		 * durations. `durationMs` is clock time and includes every idle wait between runs. So when an operator starts
		 * the chain again hours after a failure, those hours count as run time there. This value is the same run without
		 * the waiting.
		 * It counts only the MOST RECENT run of each step, for these reasons:
		 * 1. The step log holds one entry per step.
		 * 2. A retry inside the chain overwrites that entry's duration with the latest attempt's.
		 * 3. An operator's retry clears the failed entry's duration completely.
		 * So no earlier attempt's time is recorded anywhere, and none of it is counted here. Null when no step recorded
		 * a duration.
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
		 * @description The tracking id the run was launched under: the parent run's correlation id when a step launched
		 * it, the launching action's id otherwise; null when the chain started its own action or was restarted.
		 */
		@AuraEnabled
		public String launchCorrelationId;

		/**
		 * @description The root correlation id: the tracking id of the action this run belongs to.
		 */
		@AuraEnabled
		public String rootCorrelationId;

		/**
		 * @description How the run entered its action: the `LaunchKind`'s name as text, because the transport to the
		 * components does not convert an enum field.
		 */
		@AuraEnabled
		public String launchKind;

		/**
		 * @description The launching run's name and number, or the restart source's; null for the other kinds.
		 */
		@AuraEnabled
		public String launchedUnderName;

		/**
		 * @description The launching run's id, or the restart source's, so the Timing row can select it; null otherwise.
		 */
		@AuraEnabled
		public Id launchedUnderExecutionId;

		/**
		 * @description Parsed step definitions with display-ready status.
		 */
		@AuraEnabled
		public List<DTO_StepDetail> steps;
	}

	/**
	 * @description The detail of one step in the chain timeline. It sends one word for the step's status (stepStatus).
	 * The Chain Monitor turns that word into an icon and a label.
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
		 * @description True when the step's entry in the run's step log sets its continue-on-error flag to true; false in every
		 * other case, so it is never null.
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
		 * @description One word for the step's status. The Chain Monitor turns it into an icon and a label. The seven words are:
		 * success: the step finished without an error.
		 * warning: the step failed, and the chain went on because the step allows that.
		 * failed: the step failed, and the chain stopped at it.
		 * running: the step has started, and the chain is still running.
		 * pending: the step has no result yet. Either it never started and the chain is running, or the chain is stalled.
		 * noResultRecorded: the step started, but the chain ended before the step saved a result.
		 * didNotRun: the step never started, and the chain has ended.
		 */
		@AuraEnabled
		public String stepStatus;

		/**
		 * @description Whether an operator retried this step by hand. False for a step nobody retried.
		 */
		@AuraEnabled
		public Boolean manuallyRetried;

		/**
		 * @description How long the run had sat failed when the operator retried this step, in milliseconds. Null when the step
		 * was never retried by hand, or when the wait could not be measured.
		 */
		@AuraEnabled
		public Long manualRetryAfterMs;

		/**
		 * @description Human-readable form of manualRetryAfterMs. Null whenever that is null.
		 */
		@AuraEnabled
		public String manualRetryAfterLabel;
	}

	/**
	 * @description The state of the controls in the monitor's list header. It holds the current answer of the switch
	 * that turns chain processing on and off, and whether the running user may use each of the two header controls.
	 */
	public inherited sharing class DTO_OperationsState
	{
		/**
		 * @description Whether chain processing is enabled now for the running user's context. The header shows it
		 * as the state of the kill switch (the switch that stops all chain processing).
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
		 * @description How many chains are waiting for the Clear Stalled sweep, so its confirmation dialog can show the
		 * number before the operator confirms. Zero when nothing is waiting. Also zero when clearStalledAvailability
		 * refuses the sweep: a caller who cannot run it is not told what it would have found.
		 */
		@AuraEnabled
		public Integer stalledChainCount;
	}

	/**
	 * @description The counts of one Clear Stalled sweep, by outcome, for the message shown after it. It is the
	 * engine's own count, copied into a shape the components can receive.
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
		 * @description How many candidates were proven dead and started again, so they are Running again.
		 */
		@AuraEnabled
		public Integer redriven;

		/**
		 * @description How many candidates could not be recovered and were marked Failed for good.
		 */
		@AuraEnabled
		public Integer markedFailed;

		/**
		 * @description How many candidates are still waiting for recovery. This counts all of these alike: runs whose
		 * recovery limit refused another start, runs the sweep only found and marked this time, runs skipped because
		 * their background job is still alive, and runs that the sweep's steps could not act on because those steps
		 * keep sharing.
		 */
		@AuraEnabled
		public Integer remainingStalled;
	}

	/**
	 * @description One saved log entry from the history the live stream shows when it opens. It holds
	 * the fields the stream displays, read from the log entries that belong to the chain.
	 */
	public inherited sharing class DTO_LogStreamEntry
	{
		/**
		 * @description When the entry was recorded.
		 */
		@AuraEnabled
		public Datetime timestamp;

		/**
		 * @description The level the entry was logged at, copied as stored from its LogLevel__c field.
		 */
		@AuraEnabled
		public String logLevel;

		/**
		 * @description The entry's short message. The history read leaves out the long-text fields
		 * on purpose, so the full message is never loaded.
		 */
		@AuraEnabled
		public String message;
	}
}