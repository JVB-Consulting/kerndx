// SPDX-License-Identifier: BUSL-1.1
@RestResource(urlMapping='/kern/probe/*')
global with sharing class KernRestResourceNamingPositive
{
	@HttpGet
	global static String doGet()
	{
		return 'probe';
	}
}
