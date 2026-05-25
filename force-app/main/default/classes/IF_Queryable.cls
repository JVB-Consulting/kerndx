// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Interface for any object that can execute a query.
 * Implemented by QRY_Builder.Builder and SEL_Base.
 * Allows polymorphic query execution across framework components
 * such as batch jobs, async processors, and purge utilities.
 *
 * @see QRY_Builder
 * @see SEL_Base
 *
 * @author Jason van Beukering
 *
 * @group Query Infrastructure
 *
 * @date February 2026, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * public class MyQueryable implements IF_Queryable
 * {
 *     public List<SObject> toList() { return query.toList(); }
 *     public SObject getFirst() { return query.getFirst(); }
 *     public Database.QueryLocator toQueryLocator() { return query.toQueryLocator(); }
 *     public Integer count() { return query.count(); }
 *     public Boolean exists() { return query.exists(); }
 * }
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global interface IF_Queryable
{
	/**
	 * @description Executes the query and returns all matching records.
	 *
	 * @return List of matching SObjects
	 *
	 * @since 1.0
	 */
	List<SObject> toList();

	/**
	 * @description Executes the query and returns the first matching record, or null.
	 *
	 * @return First matching SObject or null
	 *
	 * @since 1.0
	 */
	SObject getFirst();

	/**
	 * @description Returns a QueryLocator for batch processing.
	 *
	 * @return QueryLocator for this query
	 *
	 * @since 1.0
	 */
	Database.QueryLocator toQueryLocator();

	/**
	 * @description Returns the count of matching records.
	 *
	 * @return Number of matching records
	 *
	 * @since 1.0
	 */
	Integer count();

	/**
	 * @description Returns true if any records match the query.
	 *
	 * @return True if at least one record matches
	 *
	 * @since 1.0
	 */
	Boolean exists();
}