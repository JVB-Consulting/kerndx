// SPDX-License-Identifier: Apache-2.0
@RestResource(urlMapping='/kern/probe/*')
global with sharing class REST_KernRestResourceNamingNegative
{
	@HttpGet
	global static String doGet()
	{
		return 'probe';
	}
}
