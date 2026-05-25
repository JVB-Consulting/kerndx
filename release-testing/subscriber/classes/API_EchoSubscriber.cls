// SPDX-License-Identifier: BUSL-1.1
public with sharing class API_EchoSubscriber extends kern.API_Outbound
{
	@TestVisible
	private static final String PARAM_MESSAGE = 'message';

	public override void configure()
	{
		super.configure();
		requiresTriggeringRecord = false;
		defaultMockBody = '{"echo":"test"}';
	}
}
