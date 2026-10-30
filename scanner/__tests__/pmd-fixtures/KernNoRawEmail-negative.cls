// SPDX-License-Identifier: Apache-2.0
public with sharing class KernNoRawEmail_Negative
{
	public static void sendThroughUtility(Id templateId, Id recipientId)
	{
		UTIL_Email.sendTemplate(templateId, recipientId);
		kern.UTIL_Email.sendTemplate(templateId, recipientId);
		Messaging.InboundEmail inbound = new Messaging.InboundEmail();
	}
}
