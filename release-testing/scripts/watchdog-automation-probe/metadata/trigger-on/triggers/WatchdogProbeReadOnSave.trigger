// SPDX-License-Identifier: Apache-2.0
/**
 * @description A test trigger for the chain watchdog. Each time chain run records are saved, it reads the running
 * user's record with one query. It does nothing else. It stands for one ordinary Apex trigger a subscriber may add
 * on chain run records. It is deployed only to a test org, never with the package.
 *
 * @author jason.van.beukering@jvb-consulting.io
 *
 * @date November 2026
 */
trigger WatchdogProbeReadOnSave on __NAMESPACE__AsyncChainExecution__c(after insert, after update)
{
	List<User> runningUsers = [SELECT Id, Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
}
