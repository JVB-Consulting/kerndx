// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Central registry and fluent builder for mock SObjects. Wraps QRY_Builder.setMock()
 * with lifecycle management, providing a single point of control for registering, retrieving, and
 * clearing mock records used in DML-free unit tests. The nested MockBuilder creates records with
 * mock IDs and auto-registers them for query interception.
 *
 * @see TST_Mock_TEST
 * @see TST_Builder
 * @see QRY_Builder
 *
 * @author Jason van Beukering
 *
 * @group Testing
 *
 * @date February 2026, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * Foobar__c mock = (Foobar__c)TST_Mock.of(Foobar__c.SObjectType)
 *     .withOverride(Foobar__c.Name, 'Test').build();
 * Foobar__c result = (Foobar__c)new SEL_Foobar().findById(mock.Id);
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier,PMD.CognitiveComplexity')
global inherited sharing class TST_Mock
{
	/**
	 * @description Internal storage of mock records keyed by SObjectType.
	 */
	private static final Map<SObjectType, List<SObject>> MOCK_REGISTRY = new Map<SObjectType, List<SObject>>();

	/**
	 * @description Registers a list of mock records for the specified SObject type. Appends to any
	 * previously registered records for the same type and updates the QRY_Builder mock layer.
	 *
	 * @param objectType The SObject type to register mocks for.
	 * @param records The mock records to register.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<Foobar__c> mocks = new List<Foobar__c>
	 * {
	 *     (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion(true).build(),
	 *     (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion(true).build()
	 * };
	 * TST_Mock.register(Foobar__c.SObjectType, mocks);
	 * ```
	 */
	global static void register(SObjectType objectType, List<SObject> records)
	{
		if(!MOCK_REGISTRY.containsKey(objectType))
		{
			MOCK_REGISTRY.put(objectType, new List<SObject>());
		}

		MOCK_REGISTRY.get(objectType).addAll(records);
		QRY_Builder.setMock(objectType, MOCK_REGISTRY.get(objectType));
	}

	/**
	 * @description Registers a single mock record for the specified SObject type.
	 *
	 * @param objectType The SObject type to register the mock for.
	 * @param record The mock record to register.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Foobar__c mock = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion(true).build();
	 * TST_Mock.register(Foobar__c.SObjectType, mock);
	 * ```
	 */
	global static void register(SObjectType objectType, SObject record)
	{
		register(objectType, new List<SObject> {record});
	}

	/**
	 * @description Registers an Exception to be thrown the next time the framework queries
	 * the specified SObjectType. Use for negative-path test coverage when a caller needs to
	 * exercise a catch block around a SOQL call.
	 *
	 * Coexists with record mocks: if both an exception and records are registered for the
	 * same SObjectType, the exception is thrown first (records are unreachable).
	 *
	 * Cleared by TST_Mock.clear() and TST_Mock.clear(SObjectType).
	 *
	 * @param objectType The SObjectType for which queries should throw.
	 * @param exceptionToThrow The exception instance to throw.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * TST_Mock.throwsException(Account.SObjectType, new QueryException('Simulated SOQL failure'));
	 * try
	 * {
	 *     new SEL_Accounts().findById(someAccountId);
	 *     Assert.fail('Expected QueryException');
	 * }
	 * catch(QueryException error)
	 * {
	 *     Assert.areEqual('Simulated SOQL failure', error.getMessage(), 'Caught the simulated failure');
	 * }
	 * ```
	 */
	global static void throwsException(SObjectType objectType, Exception exceptionToThrow)
	{
		QRY_Builder.setMockException(objectType, exceptionToThrow);
	}

	/**
	 * @description Convenience overload that throws a QueryException with the given message.
	 *
	 * @param objectType The SObjectType for which queries should throw.
	 * @param errorMessage The message attached to the synthesized QueryException.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * TST_Mock.throwsException(Account.SObjectType, 'Simulated SOQL failure');
	 * ```
	 */
	global static void throwsException(SObjectType objectType, String errorMessage)
	{
		throwsException(objectType, new QueryException(errorMessage));
	}

	/**
	 * @description Convenience overload that throws a generic QueryException for the given
	 * SObjectType. The synthesized message names the type so failures point to which mock
	 * fired without manual message threading.
	 *
	 * @param objectType The SObjectType for which queries should throw.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * TST_Mock.throwsException(Account.SObjectType);
	 * ```
	 */
	global static void throwsException(SObjectType objectType)
	{
		throwsException(objectType, new QueryException('Simulated query failure for ' + String.valueOf(objectType)));
	}

	/**
	 * @description Retrieves all mock records registered for the specified SObject type.
	 *
	 * @param objectType The SObject type to retrieve mocks for.
	 *
	 * @return The list of registered mock records, or an empty list if none registered.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<SObject> mocks = TST_Mock.get(Foobar__c.SObjectType);
	 * ```
	 */
	global static List<SObject> get(SObjectType objectType)
	{
		return MOCK_REGISTRY.containsKey(objectType)
				? MOCK_REGISTRY.get(objectType)
				: new List<SObject>();
	}

	/**
	 * @description Clears all registered mock records for all SObject types and resets the
	 * QRY_Builder mock layer.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * TST_Mock.clear();
	 * ```
	 */
	global static void clear()
	{
		for(SObjectType objectType : MOCK_REGISTRY.keySet())
		{
			QRY_Builder.setMock(objectType, new List<SObject>());
		}

		MOCK_REGISTRY.clear();
		QRY_Engine.clearMockExceptions();
	}

	/**
	 * @description Clears registered mock records for a specific SObject type and resets its
	 * QRY_Builder mock layer.
	 *
	 * @param objectType The SObject type to clear mocks for.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * TST_Mock.clear(Foobar__c.SObjectType);
	 * ```
	 */
	global static void clear(SObjectType objectType)
	{
		MOCK_REGISTRY.remove(objectType);
		QRY_Builder.setMock(objectType, new List<SObject>());
		QRY_Engine.clearMockException(objectType);
	}

	/**
	 * @description Creates a new MockBuilder for the specified SObject type. Records built via
	 * the returned builder are automatically created with mock IDs (no DML) and registered
	 * with TST_Mock for query interception.
	 *
	 * @param objectType The SObject type to build mock records for.
	 *
	 * @return A new MockBuilder instance configured for the specified type.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Foobar__c mock = (Foobar__c)TST_Mock.of(Foobar__c.SObjectType)
	 *     .withOverride(Foobar__c.Name, 'Test')
	 *     .build();
	 * ```
	 */
	global static MockBuilder of(SObjectType objectType)
	{
		return new MockBuilder(objectType);
	}

	/**
	 * @description Fluent builder wrapper that delegates to TST_Builder.Builder for record
	 * construction and auto-registers built records with TST_Mock.
	 *
	 * @since 1.0
	 */
	global inherited sharing class MockBuilder
	{
		/**
		 * @description The SObject type being built.
		 */
		private final SObjectType objectType;

		/**
		 * @description The underlying TST_Builder.Builder instance.
		 */
		private TST_Builder.Builder innerBuilder;

		/**
		 * @description Constructs a MockBuilder for the specified SObject type.
		 *
		 * @param objectType The SObject type to build mock records for.
		 */
		private MockBuilder(SObjectType objectType)
		{
			this.objectType = objectType;
			this.innerBuilder = TST_Builder.of(objectType).withoutInsertion(true);
		}

		/**
		 * @description Sets field value overrides for the mock records.
		 *
		 * @param fieldOverrides Map of SObjectField to override values.
		 *
		 * @return This MockBuilder instance for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * TST_Mock.of(Foobar__c.SObjectType)
		 *     .withOverrides(new Map<SObjectField, Object>{ Foobar__c.Name => 'Test' })
		 *     .build();
		 * ```
		 */
		global MockBuilder withOverrides(Map<SObjectField, Object> fieldOverrides)
		{
			innerBuilder = innerBuilder.withOverrides(fieldOverrides);
			return this;
		}

		/**
		 * @description Sets a single field value override for the mock records.
		 *
		 * @param field The SObject field to override.
		 * @param value The value to set.
		 *
		 * @return This MockBuilder instance for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * TST_Mock.of(Foobar__c.SObjectType)
		 *     .withOverride(Foobar__c.Name, 'Test')
		 *     .build();
		 * ```
		 */
		global MockBuilder withOverride(SObjectField field, Object value)
		{
			innerBuilder = innerBuilder.withOverride(field, value);
			return this;
		}

		/**
		 * @description Sets the number of mock records to build.
		 *
		 * @param count The number of records to create.
		 *
		 * @return This MockBuilder instance for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<SObject> mocks = TST_Mock.of(Foobar__c.SObjectType)
		 *     .withCount(5)
		 *     .buildList();
		 * ```
		 */
		global MockBuilder withCount(Integer count)
		{
			innerBuilder = innerBuilder.withCount(count);
			return this;
		}

		/**
		 * @description Sets field value overrides using String field names. Supports relationship
		 * traversal paths like 'Account.Name'.
		 *
		 * @param overrides Map of field API names to override values.
		 *
		 * @return This MockBuilder instance for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * TST_Mock.of(Foobar__c.SObjectType)
		 *     .withOverrides(new Map<String, Object>{ 'Name' => 'Test', 'Account.Name' => 'Parent' })
		 *     .build();
		 * ```
		 */
		global MockBuilder withOverrides(Map<String, Object> overrides)
		{
			innerBuilder = innerBuilder.withOverrides(overrides);
			return this;
		}

		/**
		 * @description Sets a single field value override using a String field name. Supports
		 * relationship traversal paths like 'Account.Name'.
		 *
		 * @param fieldName The API name of the field.
		 * @param value The value to set.
		 *
		 * @return This MockBuilder instance for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * TST_Mock.of(Foobar__c.SObjectType)
		 *     .withOverride('Name', 'Test')
		 *     .build();
		 * ```
		 */
		global MockBuilder withOverride(String fieldName, Object value)
		{
			innerBuilder = innerBuilder.withOverride(fieldName, value);
			return this;
		}

		/**
		 * @description Assigns a list of values that cycle across mock records built by `buildList()`.
		 * When more records are built than values provided, the values repeat from the beginning.
		 *
		 * @param field The SObjectField token of the field to cycle.
		 * @param values The list of values to cycle through. Must not be null or empty.
		 *
		 * @return This MockBuilder instance for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<SObject> mocks = TST_Mock.of(Foobar__c.SObjectType)
		 *     .withCycle(Foobar__c.Picklist__c, new List<Object>{'Alpha', 'Beta', 'Gamma'})
		 *     .withCount(6)
		 *     .buildList();
		 * ```
		 */
		global MockBuilder withCycle(SObjectField field, List<Object> values)
		{
			innerBuilder = innerBuilder.withCycle(field, values);
			return this;
		}

		/**
		 * @description Assigns a list of values that cycle across mock records built by `buildList()`.
		 * When more records are built than values provided, the values repeat from the beginning.
		 *
		 * @param fieldName The API name of the field to cycle.
		 * @param values The list of values to cycle through. Must not be null or empty.
		 *
		 * @return This MockBuilder instance for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<SObject> mocks = TST_Mock.of(Foobar__c.SObjectType)
		 *     .withCycle('Picklist__c', new List<Object>{'Alpha', 'Beta', 'Gamma'})
		 *     .withCount(6)
		 *     .buildList();
		 * ```
		 */
		global MockBuilder withCycle(String fieldName, List<Object> values)
		{
			innerBuilder = innerBuilder.withCycle(fieldName, values);
			return this;
		}

		/**
		 * @description Sets the Record Type for the mock records using the Record Type's DeveloperName.
		 *
		 * @param recordTypeDeveloperName The DeveloperName of the Record Type.
		 *
		 * @return This MockBuilder instance for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * TST_Mock.of(Account.SObjectType)
		 *     .withRecordType('Enterprise_Account')
		 *     .build();
		 * ```
		 */
		global MockBuilder withRecordType(String recordTypeDeveloperName)
		{
			innerBuilder = innerBuilder.withRecordType(recordTypeDeveloperName);
			return this;
		}

		/**
		 * @description Specifies fields to populate with default values, even if not required.
		 *
		 * @param fields A list of fields (SObjectField tokens or String API names).
		 *
		 * @return This MockBuilder instance for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * TST_Mock.of(Account.SObjectType)
		 *     .withDefaultedFields(new List<Object>{ 'Description', Account.Industry })
		 *     .build();
		 * ```
		 */
		global MockBuilder withDefaultedFields(List<Object> fields)
		{
			innerBuilder = innerBuilder.withDefaultedFields(fields);
			return this;
		}

		/**
		 * @description Specifies a single field to populate with a default value using a String name.
		 *
		 * @param fieldName The API name of the field.
		 *
		 * @return This MockBuilder instance for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * TST_Mock.of(Foobar__c.SObjectType)
		 *     .withDefaultedField('Description')
		 *     .build();
		 * ```
		 */
		global MockBuilder withDefaultedField(String fieldName)
		{
			innerBuilder = innerBuilder.withDefaultedField(fieldName);
			return this;
		}

		/**
		 * @description Specifies a single field to populate with a default value using an SObjectField token.
		 *
		 * @param field The SObjectField token of the field.
		 *
		 * @return This MockBuilder instance for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * TST_Mock.of(Account.SObjectType)
		 *     .withDefaultedField(Account.Description)
		 *     .build();
		 * ```
		 */
		global MockBuilder withDefaultedField(SObjectField field)
		{
			innerBuilder = innerBuilder.withDefaultedField(field);
			return this;
		}

		/**
		 * @description Specifies fields to treat as optional, preventing auto-population.
		 *
		 * @param fields A list of fields (SObjectField tokens or String API names).
		 *
		 * @return This MockBuilder instance for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * TST_Mock.of(Account.SObjectType)
		 *     .withOptionalFields(new List<Object>{ 'Name', Account.Type })
		 *     .build();
		 * ```
		 */
		global MockBuilder withOptionalFields(List<Object> fields)
		{
			innerBuilder = innerBuilder.withOptionalFields(fields);
			return this;
		}

		/**
		 * @description Specifies a field to treat as optional using a String name.
		 *
		 * @param fieldName The API name of the field to mark as optional.
		 *
		 * @return This MockBuilder instance for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * TST_Mock.of(Account.SObjectType)
		 *     .withOptionalField('Name')
		 *     .build();
		 * ```
		 */
		global MockBuilder withOptionalField(String fieldName)
		{
			innerBuilder = innerBuilder.withOptionalField(fieldName);
			return this;
		}

		/**
		 * @description Specifies a field to treat as optional using an SObjectField token.
		 *
		 * @param field The SObjectField token of the field to mark as optional.
		 *
		 * @return This MockBuilder instance for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * TST_Mock.of(Account.SObjectType)
		 *     .withOptionalField(Account.Name)
		 *     .build();
		 * ```
		 */
		global MockBuilder withOptionalField(SObjectField field)
		{
			innerBuilder = innerBuilder.withOptionalField(field);
			return this;
		}

		/**
		 * @description Adds child records to the parent mock using SObjectField token overrides.
		 *
		 * @param childType The SObjectType of the child records.
		 * @param count Number of child records to create.
		 * @param overrides Field overrides for child records using SObjectField tokens.
		 *
		 * @return This MockBuilder instance for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Account mock = (Account)TST_Mock.of(Account.SObjectType)
		 *     .withChildren(Contact.SObjectType, 3, new Map<SObjectField, Object>{
		 *         Contact.LastName => 'Doe'
		 *     })
		 *     .build();
		 * ```
		 */
		global MockBuilder withChildren(SObjectType childType, Integer count, Map<SObjectField, Object> overrides)
		{
			innerBuilder = innerBuilder.withChildren(childType, count, overrides);
			return this;
		}

		/**
		 * @description Adds child records to the parent mock without field overrides.
		 *
		 * @param childType The SObjectType of the child records.
		 * @param count Number of child records to create.
		 *
		 * @return This MockBuilder instance for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Account mock = (Account)TST_Mock.of(Account.SObjectType)
		 *     .withChildren(Contact.SObjectType, 3)
		 *     .build();
		 * ```
		 */
		global MockBuilder withChildren(SObjectType childType, Integer count)
		{
			innerBuilder = innerBuilder.withChildren(childType, count);
			return this;
		}

		/**
		 * @description Adds child records to the parent mock using String field name overrides.
		 *
		 * @param childType The SObjectType of the child records.
		 * @param count Number of child records to create.
		 * @param overrides Field overrides for child records using String field names.
		 *
		 * @return This MockBuilder instance for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Account mock = (Account)TST_Mock.of(Account.SObjectType)
		 *     .withChildren(Contact.SObjectType, 2, new Map<String, Object>{
		 *         'LastName' => 'Smith'
		 *     })
		 *     .build();
		 * ```
		 */
		global MockBuilder withChildren(SObjectType childType, Integer count, Map<String, Object> overrides)
		{
			innerBuilder = innerBuilder.withChildren(childType, count, overrides);
			return this;
		}

		/**
		 * @description Adds child records using a pre-configured TST_Builder.Builder with
		 * auto-detected relationship name.
		 *
		 * @param childBuilder A pre-configured Builder instance for the child records.
		 *
		 * @return This MockBuilder instance for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Account mock = (Account)TST_Mock.of(Account.SObjectType)
		 *     .withChildren(
		 *         TST_Builder.of(Contact.SObjectType)
		 *             .withCount(2)
		 *             .withOverride(Contact.LastName, 'Doe')
		 *     )
		 *     .build();
		 * ```
		 */
		global MockBuilder withChildren(TST_Builder.Builder childBuilder)
		{
			innerBuilder = innerBuilder.withChildren(childBuilder);
			return this;
		}

		/**
		 * @description Adds child records using a pre-configured TST_Builder.Builder with
		 * an explicit relationship name. Use when multiple relationships exist between
		 * the same parent and child types.
		 *
		 * @param relationshipName The child relationship name (e.g., 'Contacts').
		 * @param childBuilder A pre-configured Builder instance for the child records.
		 *
		 * @return This MockBuilder instance for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Foobar__c mock = (Foobar__c)TST_Mock.of(Foobar__c.SObjectType)
		 *     .withChildren('PrimaryContacts__r',
		 *         TST_Builder.of(Contact.SObjectType).withCount(2)
		 *     )
		 *     .build();
		 * ```
		 */
		global MockBuilder withChildren(String relationshipName, TST_Builder.Builder childBuilder)
		{
			innerBuilder = innerBuilder.withChildren(relationshipName, childBuilder);
			return this;
		}

		/**
		 * @description Builds a single mock record with a mock ID and registers it with TST_Mock
		 * for query interception.
		 *
		 * @return The built mock SObject record.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Foobar__c mock = (Foobar__c)TST_Mock.of(Foobar__c.SObjectType).build();
		 * ```
		 */
		global SObject build()
		{
			SObject record = innerBuilder.build();
			TST_Mock.register(objectType, record);
			return record;
		}

		/**
		 * @description Builds a list of mock records with mock IDs and registers them with TST_Mock
		 * for query interception.
		 *
		 * @return The list of built mock SObject records.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<SObject> mocks = TST_Mock.of(Foobar__c.SObjectType)
		 *     .withCount(3)
		 *     .buildList();
		 * ```
		 */
		global List<SObject> buildList()
		{
			List<SObject> records = innerBuilder.buildList();
			TST_Mock.register(objectType, records);
			return records;
		}
	}
}