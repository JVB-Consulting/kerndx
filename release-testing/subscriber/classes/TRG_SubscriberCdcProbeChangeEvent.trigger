// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Release-testing harness trigger. Subscribes to the Change Data Capture event for the
 * harness-owned SubscriberCdcProbe__c object and routes the change-event records through the
 * managed trigger framework via kern.TRG_Dispatcher. The dispatcher resolves the
 * SubscriberCdcProbeChangeEvent TriggerSetting (registered via ObjectApiNameOverride__c) and
 * invokes the configured Flow actions, supplying each Flow a typed kern.DTO_ChangeEventHeader.
 * Models exactly how a real subscriber wires a custom-object CDC entity into KernDX. Not part
 * of the managed package; deployed unmanaged into the subscriber test org.
 */
trigger TRG_SubscriberCdcProbeChangeEvent on SubscriberCdcProbe__ChangeEvent (after insert)
{
	new kern.TRG_Dispatcher().run();
}
