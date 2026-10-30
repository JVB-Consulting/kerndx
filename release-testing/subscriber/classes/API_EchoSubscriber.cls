// SPDX-License-Identifier: Apache-2.0
/**
 * @description Outbound call to an echo service, about the smallest outbound handler there is: it inherits everything
 * from kern.API_Outbound and only says that it needs no triggering record and what a mocked call answers. The release
 * tests use it wherever they need a simple outbound call to send.
 */
public with sharing class API_EchoSubscriber extends kern.API_Outbound
{
	/**
	 * @description Name of the request parameter that carries the text to echo. This class does not read it; the tests
	 * use it when they add the parameter to a call.
	 */
	@TestVisible
	private static final String PARAM_MESSAGE = 'message';

	/**
	 * @description Sets the handler up. The call is not about one record, so no triggering record is required, and the
	 * default body a mocked call answers with is a small echo message.
	 */
	public override void configure()
	{
		super.configure();
		requiresTriggeringRecord = false;
		defaultMockBody = '{"echo":"test"}';
	}
}
