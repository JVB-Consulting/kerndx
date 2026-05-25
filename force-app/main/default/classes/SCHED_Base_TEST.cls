// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests for SCHED_Base abstract class.
 *
 * @see SCHED_Base
 *
 * @author Jason van Beukering
 *
 * @group Schedulables
 *
 * @date March 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class SCHED_Base_TEST
{
	/**
	 * @description Tests that setParameterValues stores and resolves the provided attributes.
	 */
	@IsTest
	private static void shouldStoreAttributes()
	{
		DTO_NameValues attributes = new DTO_NameValues();
		attributes.add('key', 'value');

		TestScheduler scheduler = new TestScheduler();
		scheduler.setParameterValues(attributes);

		Assert.areEqual('value', scheduler.getTextParameter('key'), 'Attribute should be stored and resolved');
	}

	/**
	 * @description Tests that getParameterDefinitions returns an empty list by default.
	 */
	@IsTest
	private static void shouldReturnEmptyParametersByDefault()
	{
		MinimalScheduler scheduler = new MinimalScheduler();

		List<DTO_ScheduledParameterDefinition> parameters = scheduler.getParameterDefinitions();

		Assert.isNotNull(parameters, 'Parameters should not be null');
		Assert.isTrue(parameters.isEmpty(), 'Default parameters should be empty');
	}

	/**
	 * @description Tests that subclasses can override getParameterDefinitions.
	 */
	@IsTest
	private static void shouldAllowParameterOverride()
	{
		TypedScheduler scheduler = new TypedScheduler();

		List<DTO_ScheduledParameterDefinition> parameters = scheduler.getParameterDefinitions();

		Assert.isFalse(parameters.isEmpty(), 'Override should return parameters');
		Assert.areEqual('textParam', parameters[0].name, 'Parameter name should match');
	}

	/**
	 * @description Tests that TEXT parameters are resolved as strings.
	 */
	@IsTest
	private static void shouldResolveTextParameter()
	{
		TypedScheduler scheduler = new TypedScheduler();
		DTO_NameValues attributes = new DTO_NameValues();
		attributes.add('textParam', 'hello');
		scheduler.setParameterValues(attributes);

		Assert.areEqual('hello', scheduler.getResolvedText(), 'Text parameter should resolve as string');
	}

	/**
	 * @description Tests that NUMERIC parameters are resolved as integers.
	 */
	@IsTest
	private static void shouldResolveNumericParameter()
	{
		TypedScheduler scheduler = new TypedScheduler();
		DTO_NameValues attributes = new DTO_NameValues();
		attributes.add('numericParam', '42');
		scheduler.setParameterValues(attributes);

		Assert.areEqual(42, scheduler.getResolvedNumeric(), 'Numeric parameter should resolve as integer');
	}

	/**
	 * @description Tests that TOGGLE parameters are resolved as booleans.
	 */
	@IsTest
	private static void shouldResolveBooleanParameter()
	{
		TypedScheduler scheduler = new TypedScheduler();
		DTO_NameValues attributes = new DTO_NameValues();
		attributes.add('toggleParam', 'true');
		scheduler.setParameterValues(attributes);

		Assert.isTrue(scheduler.getResolvedBoolean(), 'Boolean parameter should resolve as true');
	}

	/**
	 * @description Tests that TOGGLE defaults to false when not set.
	 */
	@IsTest
	private static void shouldDefaultBooleanToFalse()
	{
		TypedScheduler scheduler = new TypedScheduler();
		scheduler.setParameterValues(new DTO_NameValues());

		Assert.isFalse(scheduler.getResolvedBoolean(), 'Boolean should default to false');
	}

	/**
	 * @description Tests that default values are applied when attributes are blank.
	 */
	@IsTest
	private static void shouldApplyDefaultValues()
	{
		TypedScheduler scheduler = new TypedScheduler();
		scheduler.setParameterValues(new DTO_NameValues());

		Assert.areEqual(500, scheduler.getResolvedNumeric(), 'Numeric default should be applied');
	}

	/**
	 * @description Tests that setParameterValues handles null gracefully by initializing empty attributes.
	 */
	@IsTest
	private static void shouldHandleNullParameterValues()
	{
		TypedScheduler scheduler = new TypedScheduler();
		scheduler.setParameterValues(null);

		Assert.isNull(scheduler.getResolvedText(), 'Text should be null when attributes are null');
		Assert.areEqual(500, scheduler.getResolvedNumeric(), 'Numeric default should be applied');
	}

	/**
	 * @description Tests that NUMERIC returns null for non-numeric values.
	 */
	@IsTest
	private static void shouldReturnNullForInvalidNumeric()
	{
		TypedScheduler scheduler = new TypedScheduler();
		DTO_NameValues attributes = new DTO_NameValues();
		attributes.add('numericParam', 'notANumber');
		scheduler.setParameterValues(attributes);

		Assert.isNull(scheduler.getResolvedNumeric(), 'Invalid numeric should return null');
	}

	/**
	 * @description Bare SCHED_Base subclass that does not override getParameterDefinitions.
	 */
	private class MinimalScheduler extends SCHED_Base
	{
		/**
		 * @description No-op execute for testing.
		 *
		 * @param context The SchedulableContext.
		 */
		@SuppressWarnings('PMD.EmptyStatementBlock')
		public void execute(SchedulableContext context)
		{
		}
	}

	/**
	 * @description SCHED_Base subclass with a single TEXT parameter for testing attribute storage.
	 */
	private class TestScheduler extends SCHED_Base
	{
		/**
		 * @description No-op execute for testing.
		 *
		 * @param context The SchedulableContext.
		 */
		@SuppressWarnings('PMD.EmptyStatementBlock')
		public void execute(SchedulableContext context)
		{
		}

		/**
		 * @description Declares a single TEXT parameter for testing attribute storage.
		 *
		 * @return List of parameter definitions.
		 */
		public override List<DTO_ScheduledParameterDefinition> getParameterDefinitions()
		{
			return new List<DTO_ScheduledParameterDefinition>
			{
					DTO_ScheduledParameterDefinition.of('key', 'Key')
			};
		}
	}

	/**
	 * @description SCHED_Base subclass with typed parameters for testing resolution.
	 */
	private class TypedScheduler extends SCHED_Base
	{
		/**
		 * @description No-op execute for testing.
		 *
		 * @param context The SchedulableContext.
		 */
		@SuppressWarnings('PMD.EmptyStatementBlock')
		public void execute(SchedulableContext context)
		{
		}

		/**
		 * @description Returns parameter definitions covering all data types.
		 *
		 * @return List of parameter definitions.
		 */
		public override List<DTO_ScheduledParameterDefinition> getParameterDefinitions()
		{
			return new List<DTO_ScheduledParameterDefinition>
			{
					DTO_ScheduledParameterDefinition.of('textParam', 'Text Param'),
					DTO_ScheduledParameterDefinition.of('numericParam', 'Numeric Param').asNumeric().withDefault('500'),
					DTO_ScheduledParameterDefinition.of('toggleParam', 'Boolean Param').asBoolean()
			};
		}

		/**
		 * @description Exposes getTextParameter for testing.
		 *
		 * @return The resolved text value.
		 */
		public String getResolvedText()
		{
			return getTextParameter('textParam');
		}

		/**
		 * @description Exposes getNumericParameter for testing.
		 *
		 * @return The resolved numeric value.
		 */
		public Integer getResolvedNumeric()
		{
			return getNumericParameter('numericParam');
		}

		/**
		 * @description Exposes getBooleanParameter for testing.
		 *
		 * @return The resolved boolean value.
		 */
		public Boolean getResolvedBoolean()
		{
			return getBooleanParameter('toggleParam');
		}
	}
}