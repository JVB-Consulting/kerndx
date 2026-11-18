// SPDX-License-Identifier: Apache-2.0
/**
 * @description Reads one post from the posts service. It is the outbound service sample of the Why KernDX page, word for
 * word, under another name: this release test org already has a class called API_GetPost. Its API Setting record holds
 * the endpoint path, so the class sets only what is special about this call.
 *
 * @see DocumentationSamplesFrontPage_TEST
 *
 * @author your.name@company.com
 *
 * @group Documentation Samples
 *
 * @date November 2026
 */
// global: KernDX creates this class by name, from its API Setting record
@SuppressWarnings('PMD.AvoidGlobalModifier')
global with sharing class API_GetOnePost extends kern.API_Outbound
{
	/**
	 * @description Says that no record starts this call, so the call needs no triggering record.
	 */
	public override void configure()
	{
		super.configure();
		requiresTriggeringRecord = false; // no record starts this call
	}

	/**
	 * @description Sends the call as a GET.
	 *
	 * @return The GET method.
	 */
	public override kern.API_Base.HttpMethod getHttpMethod()
	{
		return kern.API_Base.HttpMethod.GET;
	}
}
