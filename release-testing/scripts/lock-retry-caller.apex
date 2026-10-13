// Lock-retry probe, caller transaction: updates the held row with two retries and reports the outcome.
Account probe = [SELECT Id, Industry FROM Account WHERE Name = 'Lock retry probe' ORDER BY CreatedDate DESC LIMIT 1];
probe.Industry = 'Energy';
Long startedAt = System.currentTimeMillis();
kern.DML_Builder.TransactionResult result = kern.DML_Builder.newTransaction().doUpdate(probe).withRetryOnLock(2).execute();
System.debug('LOCK_RETRY_PROBE_RESULT success=' + result.isSuccess() + ' elapsedMs=' + (System.currentTimeMillis() - startedAt));
