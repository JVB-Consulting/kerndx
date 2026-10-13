// SPDX-License-Identifier: BUSL-1.1
/**
 * @description A with-sharing batch whose only job is to count the rows its locator delivers. Built with or
 * without the sharing bypass so the same class proves both directions. Lives as its own class because only a
 * top-level class may implement Database.Batchable; it is test-only and is driven by QRY_Builder_TEST.
 *
 * @see QRY_Builder_TEST
 *
 * @author Jason van Beukering
 *
 * @group Query Infrastructure
 *
 * @date August 2026, October 2026
 */
@IsTest
public with sharing class QRY_LocatorProbeBatch_TEST implements Database.Batchable<SObject>
{
	/**
	 * @description Rows the probe batch saw through its locator; static so the in-test synchronous batch run can
	 * report back to the asserting test method.
	 */
	public static Integer rowsSeen = 0;

	/**
	 * @description True when the batch opens its locator with the sharing bypass, so it should see every row; false
	 * when sharing stays as inherited, so it should see only the rows the running user may see.
	 */
	private final Boolean bypassSharing;

	/**
	 * @description Builds the probe. The Boolean is the probe's single dial; a second probe class would
	 * duplicate everything else.
	 *
	 * @param bypassSharing True to build the locator with the sharing bypass, false to leave sharing inherited.
	 */
	@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
	public QRY_LocatorProbeBatch_TEST(Boolean bypassSharing)
	{
		this.bypassSharing = bypassSharing;
	}

	/**
	 * @description Opens the locator under test.
	 *
	 * @param context The batch context.
	 *
	 * @return The locator, built with or without the sharing bypass.
	 */
	public Database.QueryLocator start(Database.BatchableContext context)
	{
		QRY_Builder.Builder query = QRY_Builder.selectFrom(Foobar__c.SObjectType).withSystemMode();
		return bypassSharing ? query.bypassSharing().toQueryLocator() : query.toQueryLocator();
	}

	/**
	 * @description Counts the rows delivered in this chunk.
	 *
	 * @param context The batch context.
	 * @param scope The rows delivered.
	 */
	public void execute(Database.BatchableContext context, List<SObject> scope)
	{
		rowsSeen += scope.size();
	}

	/**
	 * @description Nothing to finish.
	 *
	 * @param context The batch context.
	 */
	@SuppressWarnings('PMD.EmptyStatementBlock')
	public void finish(Database.BatchableContext context)
	{
	}
}
