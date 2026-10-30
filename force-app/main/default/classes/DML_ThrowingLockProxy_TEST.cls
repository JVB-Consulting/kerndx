// SPDX-License-Identifier: Apache-2.0
/**
 * @description A fake database layer that lets a test watch the retry after a row lock. A row lock is the
 * platform refusing a save because another process holds the record. This class takes the place of the real
 * sharing proxy, the class that runs each DML statement. It lets the first few statements through. It then
 * throws the platform's lock refusal for the next few. After that it hands every statement to the real proxy,
 * so the retry saves real records. Only statements on the test object count. The framework's own rows always go
 * straight to the real proxy: these are the log rows the log trigger saves through the builder while a test has
 * this class installed. It is a separate class because three test classes install it through
 * DML_SharingProxy.sharingProxyForTest, and they cannot share a private inner class. It is used only in tests.
 *
 * @see DML_Transaction_TEST
 * @see DML_Builder_TEST
 * @see PROC_ExecuteDML_TEST
 *
 * @author Jason van Beukering
 *
 * @group DML
 *
 * @date September 2026, October 2026
 */
@IsTest
@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
public inherited sharing class DML_ThrowingLockProxy_TEST extends DML_SharingProxy.DatabaseProxy
{
	/**
	 * @description A row-lock refusal message for tests. The framework spots a lock refusal by the status code in this
	 * message. It names the status code the framework retries on, and leaves out the platform's row phrase, because a
	 * DmlException built in a test carries no rows and asking it for them ends the transaction.
	 */
	public static final String LOCK_REFUSAL_MESSAGE = 'Update failed. UNABLE_TO_LOCK_ROW, unable to obtain exclusive access to this record';

	/**
	 * @description Statements still to let through before the refusals start.
	 */
	private Integer statementsToPass;

	/**
	 * @description Refusals still to throw once the pass-through statements are spent.
	 */
	private Integer refusalsLeft;

	/**
	 * @description The message of every refusal thrown.
	 */
	private final String refusalMessage;

	/**
	 * @description Builds a stand-in that refuses the test object's first statements with the platform's lock refusal.
	 *
	 * @param refusals How many statements to refuse.
	 */
	public DML_ThrowingLockProxy_TEST(Integer refusals)
	{
		this(0, refusals, LOCK_REFUSAL_MESSAGE);
	}

	/**
	 * @description Builds a stand-in that refuses from its first statement with the given message.
	 *
	 * @param refusals How many statements to refuse.
	 * @param refusalMessage The message of every refusal thrown.
	 */
	public DML_ThrowingLockProxy_TEST(Integer refusals, String refusalMessage)
	{
		this(0, refusals, refusalMessage);
	}

	/**
	 * @description Builds a stand-in that lets some statements through before it refuses, which is how a test gets
	 * Ids assigned before the refusal.
	 *
	 * @param statementsToPass How many statements to let through first.
	 * @param refusals How many statements to refuse after those.
	 * @param refusalMessage The message of every refusal thrown.
	 */
	public DML_ThrowingLockProxy_TEST(Integer statementsToPass, Integer refusals, String refusalMessage)
	{
		this.statementsToPass = statementsToPass;
		refusalsLeft = refusals;
		this.refusalMessage = refusalMessage;
	}

	/**
	 * @description Whether a statement carries the test object's rows. Every stand-in acts only on those: the log
	 * engine delivers its events inside a test after every log call, and the persist trigger commits through the
	 * same sharing-proxy factory, so a stand-in that touched every statement would break the framework's own log
	 * rows mid-commit.
	 *
	 * @param records The statement's rows.
	 *
	 * @return True when the rows are Foobar__c rows.
	 */
	public static Boolean isTestObjectStatement(List<SObject> records)
	{
		return !records.isEmpty() && records[0].getSObjectType() == Foobar__c.SObjectType;
	}

	/**
	 * @description Lets a statement through while any pass-through remains, then throws while any refusal remains.
	 * A statement that does not carry the test object's rows is always let through and never counted.
	 *
	 * @param records The statement's rows.
	 */
	private void refuseWhileAny(List<SObject> records)
	{
		if(!isTestObjectStatement(records))
		{
			return;
		}
		if(statementsToPass > 0)
		{
			statementsToPass--;
			return;
		}
		if(refusalsLeft > 0)
		{
			refusalsLeft--;
			throw new DmlException(refusalMessage);
		}
	}

	/**
	 * @description Refuses or delegates an insert statement.
	 *
	 * @param records The records to insert.
	 * @param allOrNothing Whether the statement is all-or-nothing.
	 * @param accessLevel The access level to use.
	 *
	 * @return The real proxy's results when the statement is let through.
	 */
	public override List<Database.SaveResult> doInsert(List<SObject> records, Boolean allOrNothing, AccessLevel accessLevel)
	{
		refuseWhileAny(records);
		return super.doInsert(records, allOrNothing, accessLevel);
	}

	/**
	 * @description Refuses or delegates an update statement.
	 *
	 * @param records The records to update.
	 * @param allOrNothing Whether the statement is all-or-nothing.
	 * @param accessLevel The access level to use.
	 *
	 * @return The real proxy's results when the statement is let through.
	 */
	public override List<Database.SaveResult> doUpdate(List<SObject> records, Boolean allOrNothing, AccessLevel accessLevel)
	{
		refuseWhileAny(records);
		return super.doUpdate(records, allOrNothing, accessLevel);
	}
}
