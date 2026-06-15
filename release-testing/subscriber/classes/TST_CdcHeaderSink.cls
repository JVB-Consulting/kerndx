// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Release-test invocable that the subscriber CDC recorder Flow calls, handing it
 * the typed kern.DTO_ChangeEventHeader the framework injected. Persists one
 * SubscriberCdcMarker__c per delivered change event capturing the header scalars (change type,
 * entity, record ids), then emits a KernDX log entry. The marker is the synchronous, queryable
 * observable the CDC release-test verify scripts assert on after the change-event delivery
 * window — it proves a subscriber Flow received the platform header through DTO_ChangeEventHeader
 * and could hand it to subscriber Apex across the namespace boundary. Writes into a non-CDC
 * object so the insert never re-fires the dispatch. Not part of the managed package.
 *
 * The invocable input is a request wrapper carrying the whole DTO_ChangeEventHeader as a single
 * Apex-defined @InvocableVariable. A bare List<DTO_ChangeEventHeader> parameter cannot be bound
 * from Flow: because DTO_ChangeEventHeader itself declares @InvocableVariable fields, Flow treats
 * it as a request type and exposes its fields rather than accepting a collection — so the Flow
 * passes the whole header object into the wrapper's single field instead.
 *
 * @author developer@kerndx.com
 *
 * @group Release Testing
 *
 * @date June 2026
 */
global inherited sharing class TST_CdcHeaderSink
{
	/**
	 * @description Separator joining the header record ids into the marker's long-text field.
	 */
	private static final String RECORD_ID_SEPARATOR = ';';

	/**
	 * @description Flow invocable request wrapper carrying one change-event header. Wrapping the
	 * header in a dedicated request type lets the recorder Flow map the whole injected
	 * DTO_ChangeEventHeader object to a single input, rather than enumerating its scalar fields.
	 */
	global class PersistRequest
	{
		/**
		 * @description The change-event header the Flow received from the framework.
		 */
		@InvocableVariable(Label='Change Event Header' Description='The DTO_ChangeEventHeader the framework injected into the recorder Flow.' Required=true)
		global kern.DTO_ChangeEventHeader header;
	}

	/**
	 * @description Persists one marker record per delivered change-event header and emits a log
	 * entry. Invoked by TST_SubscriberFlow_CdcHeaderRecorder, one request per dispatched change
	 * event. Runs in the Change Data Capture automated-process transaction.
	 *
	 * @param requests The change-event header requests the Flow received, one per dispatched change event.
	 */
	@InvocableMethod(Label='Persist CDC Header (Release Test)' Description='Records the change-event header scalars into a SubscriberCdcMarker__c for release-test verification.')
	global static void persistCdcHeader(List<PersistRequest> requests)
	{
		List<SubscriberCdcMarker__c> markers = new List<SubscriberCdcMarker__c>();
		for(PersistRequest request : requests)
		{
			kern.DTO_ChangeEventHeader header = Request?.header;
			if(header == null)
			{
				continue;
			}
			List<String> recordIds = header.recordIds ?? new List<String>();
			markers.add(new SubscriberCdcMarker__c(
					HeaderChangeType__c = header.changeType,
					HeaderEntityName__c = header.entityName,
					HeaderRecordIds__c = String.join(recordIds, RECORD_ID_SEPARATOR),
					HeaderRecordIdCount__c = recordIds.size(),
					HeaderChangeOrigin__c = header.changeOrigin
			));
			kern.LOG_Builder.build()
					.info('TST_CdcHeaderSink received ' + header.changeType + ' for ' + recordIds.size() + ' record id(s)')
					.emitAt('TST_CdcHeaderSink.persistCdcHeader');
		}
		if(!markers.isEmpty())
		{
			insert markers;
		}
	}
}
