// SPDX-License-Identifier: BUSL-1.1
/**
 * @description SVC_Omnistudio is a factory class that implements the `Callable` interface
 * and is designed to instantiate and execute operations on specific classes based on a provided class name.
 * It is mainly used within the Omnistudio framework to dynamically manage actions on classes.
 *
 * This class supports passing and handling parameters for both input and output operations.
 *
 * @see SVC_Omnistudio_TEST
 *
 * @author Jason van Beukering
 *
 * @group Omnistudio
 *
 * @date February 2026, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * // Implement an OmniCallable action
 * public class MyOmniAction implements SVC_Omnistudio.OmniCallable
 * {
 *     public void call(SVC_Omnistudio.Parameters parameters)
 *     {
 *         String input = (String)parameters.getInputVariable('name');
 *         parameters.setOutputVariable('result', 'Hello ' + input);
 *     }
 * }
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global virtual inherited sharing class SVC_Omnistudio implements Callable
{
	@TestVisible
	private static final String INPUT_MAP_KEY = 'input';
	@TestVisible
	private static final String OPTION_MAP_KEY = 'options';
	@TestVisible
	private static final String OUTPUT_MAP_KEY = 'output';

	/**
	 * @description Constant containing the class name
	 */
	public static final String CLASS_NAME = SVC_Omnistudio.class.getName();

	/**
	 * @description This global method dynamically instantiates a class based on the provided `className`
	 * and executes a method within the instantiated class to perform the requested operation. The method
	 * takes a `parameterMap` containing arguments necessary for the operation and manages the
	 * interaction through the `Parameters` DTO.
	 *
	 * @param className The name of the class to instantiate; this class must implement `Callable`.
	 * @param parameterMap A map of arguments to be used by the specified class for executing its logic.
	 *
	 * @return Returns `true` if the operation is successful.
	 *
	 * @throws Exception This method may throw an exception if the specified class cannot be instantiated
	 * or if an error occurs during method execution. The exception will be logged.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Object result = instance.call('SVC_Omnistudio', new Map<String, Object>{'key' => 'value'});
	 * ```
	 */
	global Object call(String className, Map<String, Object> parameterMap)
	{
		Object callResult = true;
		Parameters parameters = new Parameters(parameterMap);
		try
		{
			((OmniCallable)UTIL_System.getTypeForClassName(className, OmniCallable.class).newInstance()).call(parameters);
		}
		catch(Exception error)
		{
			LOG_Builder.build().error(error).at(SVC_Omnistudio.class.getName() + '/call').emit();
			throw error;
		}

		return callResult;
	}

	/**
	 * @description A global inner interface that allows the `SVC_Omnistudio` class
	 * to instantiate a class and perform an operation within the Omnistudio framework. Classes implementing
	 * this interface are expected to define the `call` method to execute custom logic using provided parameters.
	 *
	 * @since 1.0
	 */
	global interface OmniCallable
	{
		/**
		 * @description Will execute an operation based on the parameters provided
		 *
		 * @param parameters The Omnistudio input, output and options parameters
		 */
		void call(Parameters parameters);
	}

	/**
	 * @description A Data Transfer Object (DTO) used to wrap the original parameters provided by Omnistudio,
	 * organizing them into distinct input, output, and option maps. This global inherited sharing class is designed to simplify
	 * the retrieval and management of these parameters within an Omnistudio context.
	 *
	 * @since 1.0
	 */
	global inherited sharing class Parameters
	{
		private final Map<String, Object> parameters;

		/**
		 * @description Provides access to all input variables provided in the parameter map.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Map<String, Object> value = instance.inputMap;
		 * ```
		 */
		global Map<String, Object> inputMap
		{
			get
			{
				return (Map<String, Object>)parameters.get(INPUT_MAP_KEY);
			}
		}
		/**
		 * @description Provides access to various option parameters that control the behavior of the call operation.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Map<String, Object> value = instance.optionMap;
		 * ```
		 */
		global Map<String, Object> optionMap
		{
			get
			{
				return (Map<String, Object>)parameters.get(OPTION_MAP_KEY);
			}
		}
		/**
		 * @description Provides access to the output map where results of the operation can be stored.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Map<String, Object> value = instance.outputMap;
		 * ```
		 */
		global Map<String, Object> outputMap
		{
			get
			{
				return (Map<String, Object>)parameters.get(OUTPUT_MAP_KEY);
			}
		}

		/**
		 * @description DTO constructor
		 *
		 * @param parameters A map containing call parameters
		 */
		private Parameters(Map<String, Object> parameters)
		{
			this.parameters = parameters;
		}

		/**
		 * @description Retrieves the value of an input variable from the input map.
		 *
		 * @param key The name of the input variable to retrieve.
		 *
		 * @return Returns the value associated with the specified key, or null if the key is not found.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Object result = instance.getInputVariable('value');
		 * ```
		 */
		global Object getInputVariable(String key)
		{
			return inputMap.get(key);
		}

		/**
		 * @description Retrieves the value of an option variable from the options map.
		 *
		 * @param key The name of the option variable to retrieve.
		 *
		 * @return Returns the value associated with the specified key, or null if the key is not found.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Object result = instance.getOptionVariable('value');
		 * ```
		 */
		global Object getOptionVariable(String key)
		{
			return optionMap.get(key);
		}

		/**
		 * @description Sets the value of an output variable in the output map. This method is used to store
		 * the results of operations for retrieval after method execution.
		 *
		 * @param key The name of the output variable to set.
		 * @param value The value to assign to the specified key in the output map.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * instance.setOutputVariable('value', 'value');
		 * ```
		 */
		global void setOutputVariable(String key, Object value)
		{
			outputMap.put(key, value);
		}
	}
}