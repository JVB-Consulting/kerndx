// Lock-retry probe, holder transaction: creates the row and enqueues the holder that locks it for 30 seconds,
// the middle of the window in which the caller is refused twice and saves on its third attempt.
// Run by release-testing/runner/lock-retry-probe.js, never by hand alongside the caller.
Account probe = new Account(Name = 'Lock retry probe', Phone = '555-0100', Industry = 'Technology');
insert probe;
System.enqueueJob(new LockRetryProbeHolder(probe.Id, 30000));
System.debug('LOCK_RETRY_PROBE_ACCOUNT=' + probe.Id);
