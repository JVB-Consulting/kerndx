// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests for DTO_ScheduledParameterDefinition builder pattern and field population.
 *
 * @see DTO_ScheduledParameterDefinition
 *
 * @author Jason van Beukering
 *
 * @group Schedulables
 *
 * @date March 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class DTO_ScheduledParameterDefinition_TEST
{
	/**
	 * @description Test parameter name.
	 */
	private static final String TEST_NAME = 'batchSize';
	/**
	 * @description Test parameter label.
	 */
	private static final String TEST_LABEL = 'Batch Size';
	/**
	 * @description Test default value.
	 */
	private static final String TEST_DEFAULT = '2000';
	/**
	 * @description Test description text.
	 */
	private static final String TEST_DESCRIPTION = 'Number of records per batch';

	/**
	 * @description Tests that of() with required() creates a required parameter with correct fields.
	 */
	@IsTest
	private static void shouldCreateRequiredParameter()
	{
		DTO_ScheduledParameterDefinition parameter = DTO_ScheduledParameterDefinition.of(TEST_NAME, TEST_LABEL).asNumeric()
				.required();

		Assert.areEqual(TEST_NAME, parameter.name, 'Name should match');
		Assert.areEqual(TEST_LABEL, parameter.label, 'Label should match');
		Assert.areEqual('NUMERIC', parameter.dataType, 'Data type should match');
		Assert.isTrue(parameter.isRequired, 'Parameter should be required');
	}

	/**
	 * @description Tests that of() without required() creates an optional parameter.
	 */
	@IsTest
	private static void shouldCreateOptionalParameter()
	{
		DTO_ScheduledParameterDefinition parameter = DTO_ScheduledParameterDefinition.of(TEST_NAME, TEST_LABEL).asNumeric();

		Assert.areEqual(TEST_NAME, parameter.name, 'Name should match');
		Assert.areEqual(TEST_LABEL, parameter.label, 'Label should match');
		Assert.areEqual('NUMERIC', parameter.dataType, 'Data type should match');
		Assert.isFalse(parameter.isRequired, 'Parameter should be optional');
	}

	/**
	 * @description Tests that builder methods chain correctly and populate all fields.
	 */
	@IsTest
	private static void shouldChainBuilderMethods()
	{
		DTO_ScheduledParameterDefinition parameter = DTO_ScheduledParameterDefinition.of(TEST_NAME, TEST_LABEL).asNumeric()
				.withDefault(TEST_DEFAULT)
				.withDescription(TEST_DESCRIPTION);

		Assert.areEqual(TEST_DEFAULT, parameter.defaultValue, 'Default value should match');
		Assert.areEqual(TEST_DESCRIPTION, parameter.description, 'Description should match');
	}

	/**
	 * @description Tests that all DataType enum values are accessible.
	 */
	@IsTest
	private static void shouldExposeAllDataTypeEnumValues()
	{
		Assert.areEqual('TEXT', DTO_ScheduledParameterDefinition.DataType.TEXT.name(), 'TEXT enum value');
		Assert.areEqual('NUMERIC', DTO_ScheduledParameterDefinition.DataType.NUMERIC.name(), 'NUMERIC enum value');
		Assert.areEqual('FLAG', DTO_ScheduledParameterDefinition.DataType.FLAG.name(), 'FLAG enum value');
	}

	/**
	 * @description Tests that of(name) derives label from camelCase API name.
	 */
	@IsTest
	private static void shouldDeriveLabelFromName()
	{
		DTO_ScheduledParameterDefinition parameter = DTO_ScheduledParameterDefinition.of('profileNames');

		Assert.areEqual('profileNames', parameter.name, 'Name should match');
		Assert.areEqual('Profile Names', parameter.label, 'Label should be derived from camelCase name');
		Assert.areEqual('TEXT', parameter.dataType, 'Default data type should be TEXT');
	}

	/**
	 * @description Tests that of(name) defaults to TEXT data type.
	 */
	@IsTest
	private static void shouldDefaultToTextDataType()
	{
		DTO_ScheduledParameterDefinition parameter = DTO_ScheduledParameterDefinition.of(TEST_NAME, TEST_LABEL);

		Assert.areEqual('TEXT', parameter.dataType, 'Default data type should be TEXT');
	}

	/**
	 * @description Tests that asNumeric() sets data type to NUMERIC.
	 */
	@IsTest
	private static void shouldSetNumericDataType()
	{
		DTO_ScheduledParameterDefinition parameter = DTO_ScheduledParameterDefinition.of(TEST_NAME, TEST_LABEL).asNumeric();

		Assert.areEqual('NUMERIC', parameter.dataType, 'Data type should be NUMERIC');
	}

	/**
	 * @description Tests that asBoolean() sets data type to FLAG.
	 */
	@IsTest
	private static void shouldSetBooleanDataType()
	{
		DTO_ScheduledParameterDefinition parameter = DTO_ScheduledParameterDefinition.of(TEST_NAME, TEST_LABEL).asBoolean();

		Assert.areEqual('FLAG', parameter.dataType, 'Data type should be FLAG');
	}

	/**
	 * @description Tests that of(name) handles a blank name gracefully.
	 */
	@IsTest
	private static void shouldHandleBlankNameInSingleArgFactory()
	{
		DTO_ScheduledParameterDefinition parameter = DTO_ScheduledParameterDefinition.of('');

		Assert.areEqual('', parameter.name, 'Name should be blank');
		Assert.areEqual('', parameter.label, 'Label should be blank for blank name');
	}

	/**
	 * @description Tests that the parameter serializes to JSON via inherited DTO_JsonBase.
	 */
	@IsTest
	private static void shouldSerializeToJson()
	{
		DTO_ScheduledParameterDefinition parameter = DTO_ScheduledParameterDefinition.of(TEST_NAME, TEST_LABEL).asNumeric()
				.required()
				.withDefault(TEST_DEFAULT)
				.withDescription(TEST_DESCRIPTION);

		String serialized = parameter.serialize();

		Assert.isTrue(serialized.contains(TEST_NAME), 'JSON should contain parameter name');
		Assert.isTrue(serialized.contains(TEST_LABEL), 'JSON should contain parameter label');
	}
}