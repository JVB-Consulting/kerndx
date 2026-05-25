// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Selector for the AsyncChainExecution__c object. Provides query methods for
 * chain execution monitoring, status tracking, and correlation lookup.
 *
 * @see SEL_Base
 * @see SEL_AsyncChainExecution_TEST
 *
 * @author Jason van Beukering
 *
 * @group Async
 *
 * @date April 2026, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * List<AsyncChainExecution__c> running = new SEL_AsyncChainExecution().findByStatus(SEL_AsyncChainExecution.STATUS_RUNNING);
 * AsyncChainExecution__c execution = new SEL_AsyncChainExecution().findByCorrelationId('my-correlation-id');
 * List<AsyncChainExecution__c> executions = new SEL_AsyncChainExecution().findByChainName('MyChain');
 * ```
 */
@SuppressWarnings('PMD.ExcessiveParameterList,PMD.AvoidBooleanMethodParameters')
public inherited sharing class SEL_AsyncChainExecution extends SEL_Base
{
	/**
	 * @description Status indicating the chain execution is currently running.
	 */
	public static final String STATUS_RUNNING = 'Running';

	/**
	 * @description Status indicating the chain execution completed successfully.
	 */
	public static final String STATUS_COMPLETED = 'Completed';

	/**
	 * @description Status indicating the chain execution failed.
	 */
	public static final String STATUS_FAILED = 'Failed';

	/**
	 * @description Status indicating the chain execution was aborted.
	 */
	public static final String STATUS_ABORTED = 'Aborted';

	/**
	 * @description Constructs a new SEL_AsyncChainExecution selector instance.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * SEL_AsyncChainExecution selector = new SEL_AsyncChainExecution();
	 * ```
	 */
	public SEL_AsyncChainExecution()
	{
		super(AsyncChainExecution__c.SObjectType);
	}

	/**
	 * @description Returns the default fields for AsyncChainExecution__c queries.
	 *
	 * @return List of SObjectField tokens to include in queries.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<SObjectField> fields = new SEL_AsyncChainExecution().getFields();
	 * ```
	 */
	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>
		{
				AsyncChainExecution__c.ChainName__c,
				AsyncChainExecution__c.CompletedAt__c,
				AsyncChainExecution__c.CompletedSteps__c,
				AsyncChainExecution__c.ContextData__c,
				AsyncChainExecution__c.CorrelationId__c,
				AsyncChainExecution__c.CurrentStepName__c,
				AsyncChainExecution__c.DurationMs__c,
				AsyncChainExecution__c.ErrorMessage__c,
				AsyncChainExecution__c.StartedAt__c,
				AsyncChainExecution__c.Status__c,
				AsyncChainExecution__c.StepLog__c,
				AsyncChainExecution__c.TotalSteps__c
		};
	}

	/**
	 * @description Framework-owned sObject selector — always runs in `AccessLevel.SYSTEM_MODE`
	 * regardless of the `UserModeQueries_Enabled` feature flag. Running users typically have no
	 * CRUD on framework-owned records (the framework owns their lifecycle), so USER_MODE reads
	 * would return empty and chain orchestration would silently break.
	 *
	 * @return `true` — this selector requires SYSTEM_MODE.
	 */
	public override Boolean systemModeRequired()
	{
		return true;
	}

	/**
	 * @description Retrieves AsyncChainExecution__c records with a specific status.
	 *
	 * @param status The status value to filter on.
	 *
	 * @return List of AsyncChainExecution__c records matching the given status.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<AsyncChainExecution__c> running = new SEL_AsyncChainExecution().findByStatus(SEL_AsyncChainExecution.STATUS_RUNNING);
	 * ```
	 */
	public List<AsyncChainExecution__c> findByStatus(String status)
	{
		return query.condition(AsyncChainExecution__c.Status__c).equals(status).toList();
	}

	/**
	 * @description Retrieves a single AsyncChainExecution__c record by its correlation ID.
	 *
	 * @param correlationId The correlation ID to search for.
	 *
	 * @return The matching AsyncChainExecution__c record, or null if not found.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * AsyncChainExecution__c execution = new SEL_AsyncChainExecution().findByCorrelationId('550e8400-e29b-41d4-a716-446655440000');
	 * ```
	 */
	public AsyncChainExecution__c findByCorrelationId(String correlationId)
	{
		return (AsyncChainExecution__c)query
				.condition(AsyncChainExecution__c.CorrelationId__c).equals(correlationId).getFirst();
	}

	/**
	 * @description Retrieves AsyncChainExecution__c records by chain name, ordered by creation date descending.
	 *
	 * @param chainName The chain name to filter on.
	 *
	 * @return List of AsyncChainExecution__c records for the given chain name, newest first.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<AsyncChainExecution__c> executions = new SEL_AsyncChainExecution().findByChainName('MyChain');
	 * ```
	 */
	public List<AsyncChainExecution__c> findByChainName(String chainName)
	{
		return query.condition(AsyncChainExecution__c.ChainName__c).equals(chainName)
				.orderBy(AsyncChainExecution__c.CreatedDate).descending().toList();
	}

	/**
	 * @description Retrieves a paginated, filtered, and sorted page of AsyncChainExecution__c records.
	 * Used by the Chain Monitor controller for list view queries.
	 *
	 * @param statusFilters List of status values to filter on. Null or empty returns all statuses.
	 * @param nameFilter Chain name search string (LIKE filter). Null or blank returns all names.
	 * @param sortField The SObjectField to sort by.
	 * @param sortDescending True for descending sort, false for ascending.
	 * @param page The 1-based page number.
	 * @param pageSize The number of records per page.
	 *
	 * @return A QRY_Builder.QueryPage with records, totalRecords, hasMorePages, etc.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * QRY_Builder.QueryPage page = new SEL_AsyncChainExecution().findFiltered(
	 *     new List<String>{'Running', 'Failed'}, null,
	 *     AsyncChainExecution__c.CreatedDate, true, 1, 20
	 * );
	 * ```
	 */
	public QRY_Builder.QueryPage findFiltered
			(
					List<String> statusFilters,
					String nameFilter,
					SObjectField sortField,
					Boolean sortDescending,
					Integer page,
					Integer pageSize
			)
	{
		QRY_Builder.Builder filteredQuery = query;

		if(statusFilters?.isEmpty() == false)
		{
			filteredQuery = filteredQuery.condition(AsyncChainExecution__c.Status__c).isIn(statusFilters);
		}

		if(String.isNotBlank(nameFilter))
		{
			filteredQuery = filteredQuery.andCondition(AsyncChainExecution__c.ChainName__c).contains(nameFilter);
		}

		return filteredQuery.orderBy(sortField, sortDescending, sortDescending).getPage(page, pageSize);
	}
}