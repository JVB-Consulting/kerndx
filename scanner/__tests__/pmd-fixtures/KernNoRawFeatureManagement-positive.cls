// SPDX-License-Identifier: Apache-2.0
public with sharing class KernNoRawFeatureManagement_Positive
{
	public static void checkRaw()
	{
		Boolean allowed = FeatureManagement.checkPermission('MyPermission');
		Boolean flag = FeatureManagement.checkPackageBooleanValue('MyFlag');
		Date expiry = FeatureManagement.checkPackageDateValue('MyDate');
		Integer seats = FeatureManagement.checkPackageIntegerValue('MySeats');
	}
}
