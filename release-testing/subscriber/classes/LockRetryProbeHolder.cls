// SPDX-License-Identifier: Apache-2.0
/**
 * @description Release-testing fixture: holds a row lock for a while so a second transaction can be refused and
 * retry. Selects the row FOR UPDATE, then spins until the hold elapses; the lock lasts until this transaction ends.
 * Spinning costs CPU, which an asynchronous transaction has sixty seconds of.
 */
public with sharing class LockRetryProbeHolder implements Queueable
{
	/**
	 * @description The Account row this job locks. The second transaction writes to the same row and is refused while
	 * the lock is held.
	 */
	private final Id accountId;
	/**
	 * @description How many milliseconds the job keeps its transaction open after taking the lock, which is how long
	 * the lock lasts.
	 */
	private final Integer holdMilliseconds;

	/**
	 * @description Builds the holder for one row and one hold.
	 *
	 * @param accountId The Account row to lock.
	 * @param holdMilliseconds How long to keep the transaction, and with it the lock, alive.
	 */
	public LockRetryProbeHolder(Id accountId, Integer holdMilliseconds)
	{
		this.accountId = accountId;
		this.holdMilliseconds = holdMilliseconds;
	}

	/**
	 * @description Locks the row and keeps the transaction alive until the hold elapses.
	 *
	 * @param context The queueable context; unused.
	 */
	public void execute(QueueableContext context)
	{
		List<SObject> held = kern.QRY_Builder.selectFrom(Account.SObjectType)
				.fields(new List<SObjectField> {Account.Id})
				.condition(Account.Id).equals(accountId)
				.forUpdate()
				.toList();
		Long releaseAt = System.currentTimeMillis() + holdMilliseconds;
		while(System.currentTimeMillis() < releaseAt)
		{
			held.size();
		}
	}
}
