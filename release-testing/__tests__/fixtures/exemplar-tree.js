// SPDX-License-Identifier: BUSL-1.1
// An engine-written tree as the exemplar the staged fill clones: a root with two children, each with two leaves
// (fan-out 2, depth 2), with the entries the engine writes: a launch entry per run under the launcher's correlation,
// a narrating entry per leaf under its own, one failure entry. Shared by the synthesized-rows and launch tests.
const {mintVolumeId, KINDS} = require('../../scripts/consoles-at-volume/manifest');

const TOKEN = 'abcdefab';
const ACTION = mintVolumeId(KINDS.action, TOKEN, 0, 0, 0);
const MINUTE = 60_000;
const CHAIN_NAMES = ['Volume_Reconciliation', 'Volume_RegionReconcile', 'Volume_LedgerReconcile'];

/**
 * @description An instant a number of minutes after the tree's noon start.
 *
 * @param {number} minutes The minutes after noon.
 *
 * @returns {string}
 */
function at(minutes)
{
	return new Date(Date.parse('2026-09-24T12:00:00.000Z') + minutes * MINUTE).toISOString();
}

/**
 * @description One run row of the tree.
 *
 * @param {number} depth The run's depth below the root.
 * @param {number} ordinal The run's ordinal within its level.
 * @param {string} launchedBy The correlation it was launched under.
 * @param {object} [extra] Fields that differ from a completed run.
 *
 * @returns {object}
 */
function run(depth, ordinal, launchedBy, extra = {})
{
	return {
		ChainName__c: CHAIN_NAMES[depth], Status__c: 'Completed', CorrelationId__c: mintVolumeId(KINDS.reconciliationRun, TOKEN, 0, depth, ordinal),
		LaunchCorrelationId__c: launchedBy, RootCorrelationId__c: ACTION, StartedAt__c: at(depth * 2 + ordinal), CompletedAt__c: at(depth * 2 + ordinal + 1), DurationMs__c: MINUTE,
		TotalSteps__c: 2, CompletedSteps__c: 2, StepLog__c: '[{"className":"SubscriberChainSteps.FanOutStep","success":true,"durationMs":420}]',
		ContextData__c: `{"volumeRunToken":"${TOKEN}"}`, InitialContextData__c: '{}', FailureCategory__c: '', ErrorMessage__c: '', AllowRestart__c: false,
		CreatedDate: at(depth * 2 + ordinal), LastModifiedDate: at(depth * 2 + ordinal + 1), ...extra
	};
}

/**
 * @description One log entry of the tree.
 *
 * @param {string} level The log level.
 * @param {string} message The message.
 * @param {string} correlationId The correlation it sits under.
 * @param {string} transactionId The transaction it was written in.
 * @param {string} [parentTransactionId] The transaction that enqueued the one it was written in.
 *
 * @returns {object}
 */
function entry(level, message, correlationId, transactionId, parentTransactionId = '')
{
	return {
		LogLevel__c: level, ShortMessage__c: message, Message__c: message, ClassMethod__c: 'SubscriberChainSteps.NarratingStep.work', Origin__c: 'APEX',
		Source__c: 'SubscriberChainSteps', TransactionId__c: transactionId, ParentTransactionId__c: parentTransactionId, CorrelationId__c: correlationId,
		RootCorrelationId__c: ACTION, UserId__c: '005', DurationMs__c: 0, CreatedDate: at(1), LastModifiedDate: at(1)
	};
}

/**
 * @description The engine's launch announcement (UTIL_AsyncChain CHAIN_LAUNCHED_MESSAGE): the run id sits before the final period.
 *
 * @param {object} launched The run launched.
 * @param {string} under The correlation it was launched under.
 *
 * @returns {string}
 */
function launchMessage(launched, under)
{
	return `Chain ${launched.ChainName__c} launched under correlation ${under}; its run is recorded under correlation ${launched.CorrelationId__c}.`;
}

/**
 * @description The exemplar tree: its action id, its seven rows and its eight entries.
 *
 * @returns {{actionId: string, rows: object[], entries: object[]}}
 */
function exemplarTree()
{
	const root = run(0, 0, ACTION);
	const children = [run(1, 0, root.CorrelationId__c), run(1, 1, root.CorrelationId__c)];
	const failure = {Status__c: 'Failed', FailureCategory__c: 'StepException', ErrorMessage__c: 'Account batch 3 did not balance; posting held'};
	const leaves = [
		run(2, 0, children[0].CorrelationId__c), run(2, 1, children[0].CorrelationId__c), run(2, 2, children[1].CorrelationId__c),
		run(2, 3, children[1].CorrelationId__c, failure)
	];
	const rows = [root, ...children, ...leaves];
	const entries = [
		entry('INFO', launchMessage(root, ACTION), ACTION, 'tx-a'),
		...children.map((child) => entry('INFO', launchMessage(child, root.CorrelationId__c), root.CorrelationId__c, 'tx-b', 'tx-a')),
		...leaves.map((leaf) => entry('INFO', 'Validated account batch against the ledger', leaf.CorrelationId__c, 'tx-c', 'tx-b')),
		entry('ERROR', 'Step Outcome failed: Account batch 3 did not balance; posting held', leaves[3].CorrelationId__c, 'tx-c', 'tx-b')
	];
	return {actionId: ACTION, rows, entries};
}

module.exports = {TOKEN, ACTION, MINUTE, exemplarTree, launchMessage};
