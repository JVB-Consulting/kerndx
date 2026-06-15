// SPDX-License-Identifier: BUSL-1.1
/**
 * @description A Data Transfer Object (DTO) exposing the supported subset of
 * `EventBus.ChangeEventHeader` to Flow as a strongly-typed input variable. The platform
 * header type is not Flow-addressable directly; this DTO mirrors its public fields with
 * the `@InvocableVariable` + `@AuraEnabled` annotations required for Flow Apex-defined
 * variables and invocable-action parameters. `global` is required so subscriber-namespace
 * flows can reference the type cross-namespace.
 *
 * Stability contract: this is a stable additive subset of the platform header. New
 * platform header fields added in future Salesforce releases are added here as new
 * `@InvocableVariable` fields — never modified or removed — so existing subscriber
 * flows remain compatible.
 *
 * @see EventBus.ChangeEventHeader
 * @see TRG_InvokeFlow
 *
 * @author Jason van Beukering
 *
 * @group Data Transfer Objects
 *
 * @date May 2026
 *
 * @since 1.1
 *
 * @example
 * ```apex
 * EventBus.ChangeEventHeader platformHeader =
 *     (EventBus.ChangeEventHeader)records[0].get('ChangeEventHeader');
 * DTO_ChangeEventHeader flowHeader = new DTO_ChangeEventHeader(platformHeader);
 * // Pass flowHeader into a Flow interview as the `header` variable.
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class DTO_ChangeEventHeader
{
	/**
	 * @description The fully qualified API name of the source entity (e.g. `Account`,
	 * `Foobar__c`). Carries the standard / custom object name, not the Change Event
	 * suffix.
	 */
	@AuraEnabled
	@InvocableVariable(Label='Entity Name' Description='The fully qualified API name of the source entity for the change event')
	global String entityName;

	/**
	 * @description The list of source record IDs affected by this change event. A single
	 * change event may carry multiple IDs when the platform batches changes for the same
	 * entity within a commit window.
	 */
	@AuraEnabled
	@InvocableVariable(Label='Record Ids' Description='The list of source record IDs affected by this change event')
	global List<String> recordIds;

	/**
	 * @description The kind of change — `CREATE`, `UPDATE`, `DELETE`, `UNDELETE`, or
	 * `GAP_*` for replay-gap notifications.
	 */
	@AuraEnabled
	@InvocableVariable(Label='Change Type' Description='The kind of change — CREATE, UPDATE, DELETE, UNDELETE, or GAP_*')
	global String changeType;

	/**
	 * @description The origin of the change — typically `user/<userId>` for user-initiated
	 * changes or a system identifier for platform-initiated changes. Useful for filtering
	 * self-initiated changes out of downstream logic.
	 */
	@AuraEnabled
	@InvocableVariable(Label='Change Origin' Description='The origin of the change — typically user/<userId> for user-initiated changes')
	global String changeOrigin;

	/**
	 * @description A platform-assigned identifier that groups all change events from the
	 * same atomic transaction. Use to correlate cascading changes across multiple
	 * entities.
	 */
	@AuraEnabled
	@InvocableVariable(Label='Transaction Key' Description='Platform-assigned identifier grouping change events from the same atomic transaction')
	global String transactionKey;

	/**
	 * @description The ordinal position of this change within the transaction, starting
	 * at `1`. A multi-entity transaction emits events with sequential `sequenceNumber`s.
	 */
	@AuraEnabled
	@InvocableVariable(Label='Sequence Number' Description='Ordinal position of this change within the transaction (starting at 1)')
	global Integer sequenceNumber;

	/**
	 * @description The commit time as Unix epoch milliseconds. Use to compare ordering of
	 * change events across transactions.
	 */
	@AuraEnabled
	@InvocableVariable(Label='Commit Timestamp' Description='Commit time as Unix epoch milliseconds')
	global Long commitTimestamp;

	/**
	 * @description The ID of the user (or System) that committed the change.
	 */
	@AuraEnabled
	@InvocableVariable(Label='Commit User' Description='The ID of the user or System that committed the change')
	global String commitUser;

	/**
	 * @description A monotonically increasing commit-ordering number used by the platform
	 * for replay sequencing.
	 */
	@AuraEnabled
	@InvocableVariable(Label='Commit Number' Description='A monotonically increasing commit-ordering number used for replay sequencing')
	global Long commitNumber;

	/**
	 * @description The list of fields whose values were nulled by this change.
	 */
	@AuraEnabled
	@InvocableVariable(Label='Nulled Fields' Description='The list of fields whose values were nulled by this change')
	global List<String> nulledFields;

	/**
	 * @description The list of fields whose values differ from the prior commit (large /
	 * complex types only — most scalar field changes appear in `changedFields`).
	 */
	@AuraEnabled
	@InvocableVariable(Label='Diff Fields' Description='The list of fields whose values differ from the prior commit (large or complex types)')
	global List<String> diffFields;

	/**
	 * @description The list of fields whose scalar values changed in this commit.
	 */
	@AuraEnabled
	@InvocableVariable(Label='Changed Fields' Description='The list of fields whose scalar values changed in this commit')
	global List<String> changedFields;

	/**
	 * @description No-arg constructor required by some Flow runtime entry points that
	 * instantiate Apex-defined variable types before populating fields.
	 */
	@SuppressWarnings('PMD.EmptyStatementBlock')
	global DTO_ChangeEventHeader()
	{
	}

	/**
	 * @description Copy constructor — populates this DTO from a platform
	 * `EventBus.ChangeEventHeader`. Field-by-field assignment so the DTO is fully
	 * detached from the platform instance and safe to mutate without affecting the
	 * original.
	 *
	 * @param header The platform header to copy from. Must not be null.
	 */
	global DTO_ChangeEventHeader(EventBus.ChangeEventHeader header)
	{
		this.entityName = header.entityName;
		this.recordIds = header.recordIds;
		this.changeType = header.changeType;
		this.changeOrigin = header.changeOrigin;
		this.transactionKey = header.transactionKey;
		this.sequenceNumber = header.sequenceNumber;
		this.commitTimestamp = header.commitTimestamp;
		this.commitUser = header.commitUser;
		this.commitNumber = header.commitNumber;
		this.nulledFields = header.nulledFields;
		this.diffFields = header.diffFields;
		this.changedFields = header.changedFields;
	}
}