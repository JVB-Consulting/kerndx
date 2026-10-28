// SPDX-License-Identifier: BUSL-1.1
public with sharing class KernNoRawEmail_Positive
{
	public static void sendRaw()
	{
		SingleEmailMessage unqualified = new SingleEmailMessage();
		Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
		Messaging.sendEmail(new List<Messaging.SingleEmailMessage> {message});
		Messaging.renderStoredEmailTemplate(null, null, null);
		Messaging.sendEmailMessage(new List<Id>());
	}
}
