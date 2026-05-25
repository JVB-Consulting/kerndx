// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Will test that the factory class works as expected
 *
 * @see SVC_Omnistudio
 *
 * @author Jason van Beukering
 *
 * @group Omnistudio
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class SVC_Omnistudio_TEST
{
	private static final String ERROR_MESSAGE = 'Exception thrown as expected';
	private static final String PARAMETER_FOOBAR_ID = 'foobarId';
	private static final String PARAMETER_FOUND_FOOBAR_OUTPUT = 'foobar';
	private static final String PARAMETER_THROW_EXCEPTION = 'throwException';

	/**
	 * @description Will check that factory instantiates GetFoobar and has it perform correct operation
	 * based on the parameters provided, in this case it will query for a foobar record
	 *
	 * @see SVC_Omnistudio.call
	 * @see SVC_Omnistudio.OmniCallable
	 */
	@IsTest
	private static void getFoobar()
	{
		Foobar__c newFoobar = TST_Factory.insertFoobar();

		Map<String, Object> parameters = new Map<String, Object>();

		Map<String, Object> inputMap = new Map<String, Object>
		{
				PARAMETER_FOOBAR_ID => newFoobar.Id
		};

		parameters.put(SVC_Omnistudio.INPUT_MAP_KEY, inputMap);

		Map<String, Object> outputMap = new Map<String, Object>();
		parameters.put(SVC_Omnistudio.OUTPUT_MAP_KEY, outputMap);
		parameters.put(SVC_Omnistudio.OPTION_MAP_KEY, new Map<String, Object>());

		Callable omnistudioCallable = (Callable)UTIL_System.getTypeForClassName(SVC_Omnistudio.CLASS_NAME, Callable.class).newInstance();

		Test.startTest();

		Object result = omnistudioCallable.call(GetFoobar.class.getName(), parameters);

		Test.stopTest();

		Assert.isNotNull(result, 'No result object returned');
		Assert.isInstanceOfType(result, Boolean.class, 'Return type incorrect');
		Assert.isTrue(Boolean.valueOf(result), 'An error occured');

		Assert.isFalse(outputMap.isEmpty(), 'No results variables were returned');
		Object foundFoobar = outputMap.get(PARAMETER_FOUND_FOOBAR_OUTPUT);
		Assert.isNotNull(foundFoobar, 'Foobar variable not set');

		Assert.isInstanceOfType(foundFoobar, Foobar__c.class, 'Expected a foobar object');
		Assert.areEqual(newFoobar.Id, ((Foobar__c)foundFoobar).Id, 'Ids do not match');
	}

	/**
	 * @description Will check that factory instantiates GetFoobar and has it perform correct operation
	 * based on the parameters provided, in this case it will check that an exception was thrown
	 *
	 * @see SVC_Omnistudio.call
	 * @see SVC_Omnistudio.OmniCallable
	 */
	@IsTest
	private static void throwException()
	{
		Map<String, Object> parameters = new Map<String, Object>();

		Map<String, Object> optionMap = new Map<String, Object>
		{
				PARAMETER_THROW_EXCEPTION => ERROR_MESSAGE
		};

		parameters.put(SVC_Omnistudio.OPTION_MAP_KEY, optionMap);

		Map<String, Object> outputMap = new Map<String, Object>();
		parameters.put(SVC_Omnistudio.OUTPUT_MAP_KEY, outputMap);
		parameters.put(SVC_Omnistudio.INPUT_MAP_KEY, new Map<String, Object>());

		Callable omnistudioCallable = (Callable)UTIL_System.getTypeForClassName(SVC_Omnistudio.CLASS_NAME, Callable.class).newInstance();

		try
		{
			Test.startTest();

			omnistudioCallable.call(GetFoobar.class.getName(), parameters);

			Test.stopTest();

			Assert.fail('No Exception thrown as excpected');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Expected an IllegalArgumentException object');
			Assert.areEqual(ERROR_MESSAGE, error.getMessage(), 'Error message incorrect');
		}
	}

	/**
	 * @description Class to test that factory class executes the call method and that a result is returned
	 */
	public class GetFoobar implements SVC_Omnistudio.OmniCallable
	{
		/**
		 * @description Will execute 1 of 2 operations, either query for a foobar record or throw an exception
		 *
		 * @param parameters The parameters provided by Omnistudio when executing a remote action
		 */
		public void call(SVC_Omnistudio.Parameters parameters)
		{
			Object variable = parameters.getOptionVariable(PARAMETER_THROW_EXCEPTION);

			if(variable != null)
			{
				throw new IllegalArgumentException(String.valueOf(variable));
			}

			variable = parameters.getInputVariable(PARAMETER_FOOBAR_ID);
			parameters.setOutputVariable(PARAMETER_FOUND_FOOBAR_OUTPUT, new SEL_Foobar().findById((Id)variable));
		}
	}
}