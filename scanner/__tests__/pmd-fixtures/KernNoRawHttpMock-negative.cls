// SPDX-License-Identifier: Apache-2.0
@IsTest
private class KernNoRawHttpMock_Negative_TEST
{
	@IsTest
	private static void shouldMockThroughFactory()
	{
		API_MockFactory.forService('ExampleService').body('{}').register();
		kern.API_MockFactory.forService('ExampleService').body('{}').register();
		Assert.isTrue(true, 'Mock registered');
	}
}
