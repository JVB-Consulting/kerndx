// SPDX-License-Identifier: BUSL-1.1
/**
 * Original sourced from https://github.com/benahm
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/**
 * @description An advanced factory for creating and inserting SObject records for Apex tests.
 * This class provides a flexible way to generate test data, automatically handling required fields
 * and complex object relationships using a fluid builder pattern.
 *
 * @see TST_BuilderInternal
 * @see TST_Builder_TEST
 * @see UTIL_SObjectBuilderDefaultProvider
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
 * Account account = (Account)TST_Builder.of(Account.SObjectType).build();
 * Account inMemory = (Account)TST_Builder.of(Account.SObjectType).withoutInsertion().build();
 * Account custom = (Account)TST_Builder.of(Account.SObjectType)
 *     .withOverride(Account.Name, 'Acme Corp').build();
 * List<SObject> accounts = TST_Builder.of(Account.SObjectType).withCount(5).buildList();
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier,PMD.CognitiveComplexity,PMD.TooManyMethods,PMD.ExcessiveClassLength,PMD.AvoidBooleanMethodParameters')
global inherited sharing class TST_Builder
{
	/**
	 * @description Overrides the default factory provider with a custom implementation.
	 * This is the primary extension point for subscribers to inject custom SObject creation logic.
	 *
	 * @example
	 * ```apex
	 * // Set a custom factory provider
	 * TST_Builder.factoryProvider = new MyCustomFactoryProvider();
	 * ```
	 */
	public static FactoryProvider factoryProvider
	{
		get
		{
			if(factoryProvider == null)
			{
				factoryProvider = new TST_BuilderInternal.SObjectFactoryProvider();
			}
			return factoryProvider;
		}
		set;
	}

	/**
	 * @description Overrides the default value provider instance with a custom implementation.
	 * This allows developers to define custom logic for generating default field values.
	 * To customize, extend 'UTIL_SObjectBuilderDefaultProvider' and assign an instance here.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * // Set a custom default value provider
	 * TST_Builder.defaultValueProvider = new MyCustomDefaultProvider();
	 * ```
	 */
	global static DefaultValueProvider defaultValueProvider
	{
		get
		{
			if(defaultValueProvider == null)
			{
				defaultValueProvider = new UTIL_SObjectBuilderDefaultProvider();
			}
			return defaultValueProvider;
		}
		set;
	}

	/**
	 * @description A special marker value that signals the factory to generate a default value for a field,
	 * even if it's not required. Use this in field override maps to request automatic value generation.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * // Request automatic default value for Description field
	 * Account account = (Account)TST_Builder.of(Account.SObjectType)
	 * 	.withOverrides(new Map<String, Object>
	 * 	{
	 * 		'Name' => 'Test Account',
	 * 		'Description' => TST_Builder.autoDefaultFieldValueProvider
	 * 	})
	 * 	.withoutInsertion()
	 * 	.build();
	 * ```
	 */
	global static DefaultFieldValueProvider autoDefaultFieldValueProvider
	{
		get
		{
			if(autoDefaultFieldValueProvider == null)
			{
				autoDefaultFieldValueProvider = new UTIL_SObjectBuilderDefaultProvider.AutoFieldDefaultValue();
			}
			return autoDefaultFieldValueProvider;
		}
		private set;
	}

	/**
	 * @description A static list of fields to treat as optional for the current transaction's build operations.
	 * Fields added to this list will not be automatically populated with default values, even if they are required.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * // Globally mark Phone as optional for all builds in this transaction
	 * TST_Builder.optionalFields.add('Phone');
	 * Account account = (Account)TST_Builder.of(Account.SObjectType)
	 * 	.withoutInsertion()
	 * 	.build();
	 * ```
	 */
	global static List<Object> optionalFields
	{
		get
		{
			if(optionalFields == null)
			{
				optionalFields = new List<Object>();
			}
			return optionalFields;
		}
		private set;
	}

	/**
	 * @description Starts a new SObject build operation for the specified SObjectType.
	 *
	 * @param objectType The `SObjectType` of the SObject to create.
	 *
	 * @return A new Builder instance to configure and execute the build.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * // Build a single Account in memory with a specific name
	 * Account account = (Account)TST_Builder.of(Account.SObjectType)
	 * 	.withOverrides(new Map<String, Object>{ 'Name' => 'Test Account' })
	 * 	.withoutInsertion()
	 * 	.build();
	 * ```
	 */
	global static Builder of(SObjectType objectType)
	{
		return new Builder(objectType);
	}

	/**
	 * @description Starts a new SObject build operation for the specified SObject API name.
	 *
	 * @param sObjectName The API name of the SObject to create.
	 *
	 * @return A new Builder instance to configure and execute the build.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * // Build and insert a list of 5 Foobars
	 * List<SObject> fooBars = TST_Builder.of('Foobar__c')
	 * 	.withCount(5)
	 * 	.buildList();
	 * ```
	 */
	global static Builder of(String sObjectName)
	{
		return new Builder(sObjectName);
	}

	/**
	 * @description Resolves an SObject API name to its SObjectType, throwing a descriptive
	 * error if the name is invalid.
	 *
	 * @param sObjectName The SObject API name to resolve.
	 *
	 * @return The resolved SObjectType.
	 */
	private static SObjectType resolveType(String sObjectName)
	{
		if(String.isBlank(sObjectName))
		{
			throw new IllegalArgumentException('SObject name cannot be blank.');
		}

		UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe(sObjectName);

		if(describe == null)
		{
			throw new IllegalArgumentException('SObject \'' + sObjectName + '\' not found. Verify the API name is correct.');
		}

		return describe.getSObjectType();
	}

	/**
	 * @description A fluid builder for configuring and creating SObject records.
	 * Obtain an instance via `TST_Builder.of(SObjectType)`.
	 *
	 * @since 1.0
	 */
	@SuppressWarnings('PMD.CyclomaticComplexity')
	global inherited sharing class Builder
	{
		/**
		 * @description Indicates if we should insert or not, defaults to true
		 */
		private Boolean doInsert = true;
		/**
		 * @description Indicates if mock IDs should be generated for in-memory builds
		 */
		private Boolean generateMockIds = false;
		/**
		 * @description Indicates the number of objects to create, defaults to 1
		 */
		private Integer numberOfSObjects = 1;
		/**
		 * @description The fields to automatically default (whether they are required or not)
		 */
		private final List<Object> fieldsToDefault = new List<Object>();
		/**
		 * @description Tne fields to treat as optional, overriding the default provider's required field logic.
		 */
		private final List<Object> optionalFields = new List<Object>();
		/**
		 * @description Fields and their override value
		 */
		private final Map<String, Object> mapOfValuesOverride = new Map<String, Object>();
		/**
		 * @description The object type we're building
		 */
		private final SObjectType sObjectType;

		/**
		 * @description Cached object describe for efficient field metadata lookups
		 */
		private final UTIL_SObjectDescribe objectDescribe;

		/**
		 * @description Map of child relationship names to child record lists for graph building
		 */
		private final Map<String, List<SObject>> childRelationships = new Map<String, List<SObject>>();

		/**
		 * @description Map of child relationship names to deferred child builders.
		 * Children are built in buildList() after global mock ID flag is set.
		 */
		private final Map<String, Builder> deferredChildBuilders = new Map<String, Builder>();

		/**
		 * @description Private constructor. Use `TST_Builder.of()`.
		 *
		 * @param objectType The SObjectType to build.
		 */
		private Builder(SObjectType objectType)
		{
			if(objectType == null)
			{
				throw new IllegalArgumentException('SObjectType cannot be null.');
			}

			this.sObjectType = objectType;
			this.objectDescribe = UTIL_SObjectDescribe.getDescribe(objectType);
		}

		/**
		 * @description Private constructor. Use `TST_Builder.of()`.
		 *
		 * @param sObjectName The SObject API name to build.
		 */
		private Builder(String sObjectName)
		{
			this(resolveType(sObjectName));
		}

		/**
		 * @description Applies a map of specific field values, overriding defaults.
		 *
		 * @param overrides A map of field names to their override values.
		 *
		 * @return This Builder instance for further chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * // Build an Account with multiple field overrides
		 * Account account = (Account)TST_Builder.of(Account.SObjectType)
		 * 	.withOverrides(new Map<String, Object>
		 * 	{
		 * 		'Name' => 'Acme Corp',
		 * 		'Phone' => '555-1234',
		 * 		'Industry' => 'Technology'
		 * 	})
		 * 	.withoutInsertion()
		 * 	.build();
		 * ```
		 */
		global Builder withOverrides(Map<String, Object> overrides)
		{
			if(overrides != null)
			{
				// Lowercase keys immediately for consistent lookup
				for(String key : overrides.keySet())
				{
					if(key != null)
					{
						mapOfValuesOverride.put(key.toLowerCase(), overrides.get(key));
					}
				}
			}
			return this;
		}

		/**
		 * @description Applies a map of specific field values using SObjectField tokens, overriding defaults.
		 * This provides compile-time checking for field names.
		 *
		 * @param overrides A map of SObjectField tokens to their override values.
		 *
		 * @return This Builder instance for further chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Account account = (Account)TST_Builder.of(Account.SObjectType)
		 * .withOverrides(new Map<SObjectField, Object>
		 *    {
		 * 		Account.Name => 'Token Account',
		 * 		Account.Phone => '111-222-3333'
		 * 	})
		 * .withoutInsertion()
		 * .build();
		 * ```
		 */
		global Builder withOverrides(Map<SObjectField, Object> overrides)
		{
			if(overrides?.isEmpty() == false)
			{
				for(SObjectField objectField : overrides.keySet())
				{
					if(objectField != null)
					{
						// Lowercase immediately for consistent lookup
						mapOfValuesOverride.put(objectDescribe.getFieldDescribe(objectField).name.toLowerCase(), overrides.get(objectField));
					}
				}
			}
			return this;
		}

		/**
		 * @description Applies a specific field value override.
		 *
		 * @param fieldName The API name of the field.
		 * @param value The override value.
		 *
		 * @return This Builder instance for further chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * // Build an Account with a single field override
		 * Account account = (Account)TST_Builder.of(Account.SObjectType)
		 * 	.withOverride('Name', 'Test Account')
		 * 	.withOverride('Phone', '555-9999')
		 * 	.withoutInsertion()
		 * 	.build();
		 * ```
		 */
		global Builder withOverride(String fieldName, Object value)
		{
			if(String.isNotBlank(fieldName))
			{
				// Lowercase immediately for consistent lookup
				mapOfValuesOverride.put(fieldName.toLowerCase(), value);
			}
			return this;
		}

		/**
		 * @description Applies a specific field value override using an SObjectField token.
		 * This provides compile-time checking for field names.
		 *
		 * @param field The SObjectField token of the field.
		 * @param value The override value.
		 *
		 * @return This Builder instance for further chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * // Build an Account with type-safe field overrides
		 * Account account = (Account)TST_Builder.of(Account.SObjectType)
		 * 	.withOverride(Account.Name, 'Test Account')
		 * 	.withOverride(Account.AnnualRevenue, 1000000)
		 * 	.withoutInsertion()
		 * 	.build();
		 * ```
		 */
		global Builder withOverride(SObjectField field, Object value)
		{
			if(field != null)
			{
				// Lowercase immediately for consistent lookup
				mapOfValuesOverride.put(objectDescribe.getFieldDescribe(field).name.toLowerCase(), value);
			}
			return this;
		}

		/**
		 * @description Assigns a list of values that cycle across records built by `buildList()`.
		 * When more records are built than values provided, the values repeat from the beginning.
		 *
		 * @param field The SObjectField token of the field to cycle.
		 * @param values The list of values to cycle through. Must not be null or empty.
		 *
		 * @return This Builder instance for further chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<SObject> foobars = TST_Builder.of(Foobar__c.SObjectType)
		 *     .withCycle(Foobar__c.Picklist__c, new List<Object>{'Alpha', 'Beta', 'Gamma'})
		 *     .withCount(6)
		 *     .withoutInsertion()
		 *     .buildList();
		 * // Alpha, Beta, Gamma, Alpha, Beta, Gamma
		 * ```
		 */
		global Builder withCycle(SObjectField field, List<Object> values)
		{
			if(field == null)
			{
				throw new IllegalArgumentException('Field cannot be null.');
			}

			if(values == null || values.isEmpty())
			{
				throw new IllegalArgumentException('Values list cannot be null or empty.');
			}

			mapOfValuesOverride.put(objectDescribe.getFieldDescribe(field).name.toLowerCase(), values);
			return this;
		}

		/**
		 * @description Assigns a list of values that cycle across records built by `buildList()`.
		 * When more records are built than values provided, the values repeat from the beginning.
		 *
		 * @param fieldName The API name of the field to cycle.
		 * @param values The list of values to cycle through. Must not be null or empty.
		 *
		 * @return This Builder instance for further chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<SObject> foobars = TST_Builder.of(Foobar__c.SObjectType)
		 *     .withCycle('Picklist__c', new List<Object>{'Alpha', 'Beta', 'Gamma'})
		 *     .withCount(6)
		 *     .withoutInsertion()
		 *     .buildList();
		 * // Alpha, Beta, Gamma, Alpha, Beta, Gamma
		 * ```
		 */
		global Builder withCycle(String fieldName, List<Object> values)
		{
			if(String.isBlank(fieldName))
			{
				throw new IllegalArgumentException('Field name cannot be blank.');
			}

			if(values == null || values.isEmpty())
			{
				throw new IllegalArgumentException('Values list cannot be null or empty.');
			}

			mapOfValuesOverride.put(fieldName.toLowerCase(), values);
			return this;
		}

		/**
		 * @description Specifies a list of optional fields to populate with default values,
		 * even though they are not marked as required.
		 *
		 * @param fields A list of fields (SObjectField tokens or String API names).
		 *
		 * @return This Builder instance for further chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * // Build an Account with optional fields automatically populated
		 * Account account = (Account)TST_Builder.of(Account.SObjectType)
		 * 	.withDefaultedFields(new List<Object>{ 'Description', 'Industry', 'Website' })
		 * 	.withoutInsertion()
		 * 	.build();
		 * ```
		 */
		global Builder withDefaultedFields(List<Object> fields)
		{
			if(fields != null)
			{
				fieldsToDefault.addAll(fields);
			}
			return this;
		}

		/**
		 * @description Specifies an optional field to populate with a default value,
		 * even though it is not marked as required.
		 *
		 * @param fieldName The API name of the field.
		 *
		 * @return This Builder instance for further chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * // Build an Account with Description field automatically populated
		 * Account account = (Account)TST_Builder.of(Account.SObjectType)
		 * 	.withDefaultedField('Description')
		 * 	.withDefaultedField('Industry')
		 * 	.withoutInsertion()
		 * 	.build();
		 * ```
		 */
		global Builder withDefaultedField(String fieldName)
		{
			if(String.isNotBlank(fieldName))
			{
				fieldsToDefault.add(fieldName);
			}
			return this;
		}

		/**
		 * @description Specifies an optional field to populate with a default value using an SObjectField token.
		 * This provides compile-time checking for field names.
		 *
		 * @param field The SObjectField token of the field.
		 *
		 * @return This Builder instance for further chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * // Build an Account with type-safe defaulted fields
		 * Account account = (Account)TST_Builder.of(Account.SObjectType)
		 * 	.withDefaultedField(Account.Description)
		 * 	.withDefaultedField(Account.Industry)
		 * 	.withoutInsertion()
		 * 	.build();
		 * ```
		 */
		global Builder withDefaultedField(SObjectField field)
		{
			if(field != null)
			{
				fieldsToDefault.add(field);
			}
			return this;
		}

		/**
		 * @description Specifies a field to treat as optional,
		 * preventing the factory from auto-populating it as a required field.
		 *
		 * @param fieldName The API name of the field to mark as optional.
		 *
		 * @return This Builder instance for further chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * // Build an Account without populating the Name field (normally required)
		 * Account account = (Account)TST_Builder.of(Account.SObjectType)
		 * 	.withOptionalField('Name')
		 * 	.withoutInsertion()
		 * 	.build();
		 * Assert.isNull(account.Name);
		 * ```
		 */
		global Builder withOptionalField(String fieldName)
		{
			if(String.isNotBlank(fieldName))
			{
				optionalFields.add(fieldName);
			}
			return this;
		}

		/**
		 * @description Specifies a field to treat as optional using an SObjectField token,
		 * preventing the factory from auto-populating it as a required field.
		 * This provides compile-time checking for field names.
		 *
		 * @param field The SObjectField token of the field to mark as optional.
		 *
		 * @return This Builder instance for further chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * // Build an Account without populating the Name field using type-safe field reference
		 * Account account = (Account)TST_Builder.of(Account.SObjectType)
		 * 	.withOptionalField(Account.Name)
		 * 	.withoutInsertion()
		 * 	.build();
		 * Assert.isNull(account.Name);
		 * ```
		 */
		global Builder withOptionalField(SObjectField field)
		{
			if(field != null)
			{
				optionalFields.add(objectDescribe.getFieldDescribe(field).name);
			}
			return this;
		}

		/**
		 * @description Specifies a list of fields to treat as optional,
		 * preventing the factory from auto-populating them as required fields.
		 *
		 * @param fields A list of fields (SObjectField tokens or String API names).
		 *
		 * @return This Builder instance for further chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * // Build an Account without populating multiple normally-required fields
		 * Account account = (Account)TST_Builder.of(Account.SObjectType)
		 * 	.withOptionalFields(new List<Object>{ 'Name', Account.Type })
		 * 	.withoutInsertion()
		 * 	.build();
		 * ```
		 */
		global Builder withOptionalFields(List<Object> fields)
		{
			if(fields != null)
			{
				optionalFields.addAll(fields);
			}
			return this;
		}

		/**
		 * @description Sets the number of SObject records to create when calling `buildList()`.
		 *
		 * @param count The number of records to create.
		 *
		 * @return This Builder instance for further chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * // Build 10 Account records and insert them
		 * List<Account> accounts = (List<Account>)TST_Builder.of(Account.SObjectType)
		 * 	.withCount(10)
		 * 	.buildList();
		 * Assert.areEqual(10, accounts.size());
		 * ```
		 */
		global Builder withCount(Integer count)
		{
			numberOfSObjects = count;
			return this;
		}

		/**
		 * @description Configures the build to *not* insert the records into the database.
		 * By default, records are inserted. Use this when you need in-memory records for testing
		 * without DML operations.
		 *
		 * @return This Builder instance for further chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * // Build an Account in memory without inserting it
		 * Account account = (Account)TST_Builder.of(Account.SObjectType)
		 * 	.withOverride('Name', 'Test Account')
		 * 	.withoutInsertion()
		 * 	.build();
		 * Assert.isNull(account.Id);
		 * ```
		 */
		global Builder withoutInsertion()
		{
			doInsert = false;
			return this;
		}

		/**
		 * @description Configures the build to *not* insert the records into the database,
		 * with an option to generate mock IDs for the entire object graph.
		 * Use this when you need in-memory records with IDs for query mocking.
		 *
		 * @param withMockIds If true, generates unique mock IDs for all records in the graph
		 *                    (parents and children). Foreign key fields on children are
		 *                    automatically set to reference their parent's mock ID.
		 *
		 * @return This Builder instance for further chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * // Build mock Account with Contacts - all with generated IDs
		 * Account mockAccount = (Account)TST_Builder.of(Account.SObjectType)
		 * 	.withOverride(Account.Name, 'Mock Account')
		 * 	.withChildren(Contact.SObjectType, 3, new Map<SObjectField, Object>{
		 * 		Contact.LastName => 'Mock Contact'
		 * 	})
		 * 	.withoutInsertion(true)
		 * 	.build();
		 * Assert.isNotNull(mockAccount.Id, 'Parent should have mock ID');
		 * Assert.areEqual(3, mockAccount.Contacts.size());
		 * Assert.isNotNull(mockAccount.Contacts[0].Id, 'Children should have mock IDs');
		 * Assert.areEqual(mockAccount.Id, mockAccount.Contacts[0].AccountId, 'FK should reference parent');
		 * // Register for query mocking
		 * QRY_Builder.setMock(Account.SObjectType, new List<Account>{mockAccount});
		 * ```
		 */
		global Builder withoutInsertion(Boolean withMockIds)
		{
			doInsert = false;
			generateMockIds = withMockIds == true;
			return this;
		}

		/**
		 * @description Sets the Record Type for the SObject(s) to be built, using the Record Type's DeveloperName.
		 *
		 * @param recordTypeDeveloperName The DeveloperName of the Record Type.
		 *
		 * @return This Builder instance for further chaining.
		 *
		 * @throws IllegalArgumentException if the Record Type DeveloperName is not found; ignores blank DeveloperName's
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * // Build an Account with a specific record type
		 * Account account = (Account)TST_Builder.of(Account.SObjectType)
		 * 	.withRecordType('Enterprise_Account')
		 * 	.withOverride('Name', 'Enterprise Corp')
		 * 	.withoutInsertion()
		 * 	.build();
		 * ```
		 */
		global Builder withRecordType(String recordTypeDeveloperName)
		{
			if(String.isNotBlank(recordTypeDeveloperName))
			{
				Id recordTypeId = UTIL_SObjectDescribe.getRecordTypeByDeveloperName(sObjectType, recordTypeDeveloperName);

				if(recordTypeId == null)
				{
					throw new IllegalArgumentException('No RecordType found with DeveloperName "' + recordTypeDeveloperName + '"');
				}

				mapOfValuesOverride.put('RecordTypeId', recordTypeId);
			}

			return this;
		}

		/**
		 * @description Adds child records to the parent being built using SObjectField tokens.
		 * The child records will be assigned to the appropriate relationship field.
		 *
		 * @param childType The SObjectType of the child records
		 * @param count Number of child records to create
		 * @param overrides Field overrides for child records using SObjectField tokens
		 *
		 * @return Builder for method chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Account account = (Account)TST_Builder.of(Account.SObjectType)
		 *     .withOverride(Account.Name, 'ACME Corp')
		 *     .withChildren(Contact.SObjectType, 3, new Map<SObjectField, Object>{
		 *         Contact.FirstName => 'John',
		 *         Contact.LastName => 'Doe'
		 *     })
		 *     .build();
		 * Assert.areEqual(3, account.Contacts.size());
		 * ```
		 */
		global Builder withChildren(SObjectType childType, Integer count, Map<SObjectField, Object> overrides)
		{
			if(childType == null)
			{
				throw new IllegalArgumentException('Child SObjectType cannot be null');
			}

			// Convert SObjectField map to String map
			Map<String, Object> stringOverrides = new Map<String, Object>();
			if(overrides != null)
			{
				UTIL_SObjectDescribe childDescribe = UTIL_SObjectDescribe.getDescribe(childType);
				for(SObjectField field : overrides.keySet())
				{
					stringOverrides.put(childDescribe.getFieldDescribe(field).name, overrides.get(field));
				}
			}

			return withChildren(childType, count, stringOverrides);
		}

		/**
		 * @description Adds child records to the parent being built without field overrides.
		 * The simplest way to add child records - relationship name is auto-detected.
		 * All child fields will use framework defaults.
		 *
		 * @param childType The SObjectType of the child records
		 * @param count Number of child records to create
		 *
		 * @return Builder for method chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Account account = (Account)TST_Builder.of(Account.SObjectType)
		 *     .withOverride(Account.Name, 'ACME Corp')
		 *     .withChildren(Contact.SObjectType, 3)
		 *     .build();
		 * Assert.areEqual(3, account.Contacts.size());
		 * ```
		 */
		global Builder withChildren(SObjectType childType, Integer count)
		{
			return withChildren(childType, count, new Map<String, Object>());
		}

		/**
		 * @description Adds child records to the parent being built using String field names.
		 * The child records will be assigned to the appropriate relationship field.
		 *
		 * @param childType The SObjectType of the child records
		 * @param count Number of child records to create
		 * @param overrides Field overrides for child records using String field names
		 *
		 * @return Builder for method chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Account account = (Account)TST_Builder.of(Account.SObjectType)
		 *     .withOverride('Name', 'ACME Corp')
		 *     .withChildren(Contact.SObjectType, 2, new Map<String, Object>{
		 *         'LastName' => 'Smith'
		 *     })
		 *     .build();
		 * ```
		 */
		global Builder withChildren(SObjectType childType, Integer count, Map<String, Object> overrides)
		{
			if(childType == null)
			{
				throw new IllegalArgumentException('Child SObjectType cannot be null');
			}

			if(count == null || count < 1)
			{
				throw new IllegalArgumentException('Count must be at least 1');
			}

			// Create child builder but defer building until buildList() after global flag is set
			Builder childBuilder = TST_Builder.of(childType)
					.withCount(count)
					.withOverrides(overrides);

			return withChildren(childBuilder);
		}

		/**
		 * @description Adds child records using a pre-configured Builder instance with auto-detected relationship name.
		 * The relationship name is automatically determined from the child Builder's SObjectType.
		 * Allows for complex child record configuration using fluent Builder API.
		 *
		 * @param childBuilder A pre-configured Builder instance for the child records
		 *
		 * @return Builder for method chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Account account = (Account)TST_Builder.of(Account.SObjectType)
		 *     .withChildren(
		 *         TST_Builder.of(Opportunity.SObjectType)
		 *             .withCount(2)
		 *             .withOverride(Opportunity.Name, 'Big Deal')
		 *             .withOverride(Opportunity.StageName, 'Prospecting')
		 *     )
		 *     .build();
		 * ```
		 */
		global Builder withChildren(Builder childBuilder)
		{
			if(childBuilder == null)
			{
				throw new IllegalArgumentException('Child builder cannot be null');
			}

			// Auto-detect relationship name from child builder's SObjectType
			String relationshipName = getChildRelationshipName(sObjectType, childBuilder.sObjectType);

			// Store builder for deferred building in buildList() after global flag is set
			return withChildren(relationshipName, childBuilder);
		}

		/**
		 * @description Adds child records using a pre-configured Builder instance with explicit relationship name.
		 * EDGE CASE ONLY: Use this variant when there are multiple relationships between the same parent and child types
		 * (e.g., self-referential with multiple lookup fields, or objects with multiple lookups to the same parent).
		 * For most cases, use withChildren(Builder) which auto-detects the relationship name.
		 *
		 * @param relationshipName The child relationship name (e.g., 'Contacts', 'Opportunities', 'PrimaryContacts__r')
		 * @param childBuilder A pre-configured Builder instance for the child records
		 *
		 * @return Builder for method chaining
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * // Edge case: Foobar__c has TWO lookup fields to Contact (PrimaryContact__c, SecondaryContact__c)
		 * Foobar__c foobar = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
		 *     .withChildren('PrimaryContacts__r',
		 *         TST_Builder.of(Contact.SObjectType).withCount(2)
		 *     )
		 *     .withChildren('SecondaryContacts__r',
		 *         TST_Builder.of(Contact.SObjectType).withCount(1)
		 *     )
		 *     .build();
		 * ```
		 */
		global Builder withChildren(String relationshipName, Builder childBuilder)
		{
			if(String.isBlank(relationshipName))
			{
				throw new IllegalArgumentException('Relationship name cannot be blank');
			}

			if(childBuilder == null)
			{
				throw new IllegalArgumentException('Child builder cannot be null');
			}

			// Store builder for deferred building in buildList() after global flag is set
			deferredChildBuilders.put(relationshipName, childBuilder);

			return this;
		}

		/**
		 * @description Executes the build operation and creates a single SObject record.
		 * If `withCount()` was called, this method still only returns one record.
		 *
		 * @return The created SObject record (inserted by default unless `withoutInsertion()` was called).
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * // Build and insert a single Account
		 * Account account = (Account)TST_Builder.of(Account.SObjectType)
		 * 	.withOverride('Name', 'Test Account')
		 * 	.build();
		 * Assert.isNotNull(account.Id);
		 * ```
		 */
		global SObject build()
		{
			numberOfSObjects = 1;
			return buildList().iterator().next();
		}

		/**
		 * @description Executes the build operation and creates a list of SObject records.
		 * The number of records is determined by the value passed to `withCount()` (defaults to 1).
		 *
		 * @return A list of the created SObject records (inserted by default unless `withoutInsertion()` was called).
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * // Build and insert 5 Contact records
		 * List<Contact> contacts = (List<Contact>)TST_Builder.of(Contact.SObjectType)
		 * 	.withCount(5)
		 * 	.withOverride('LastName', 'Smith')
		 * 	.buildList();
		 * Assert.areEqual(5, contacts.size());
		 * Assert.isNotNull(contacts[0].Id);
		 * ```
		 */
		global List<SObject> buildList()
		{
			//Use to restore the static list
			List<Object> optionalFieldsToRestore = new List<Object>(TST_Builder.optionalFields);
			Boolean previousGlobalMockIds = TST_BuilderInternal.globalGenerateMockIds;
			try
			{
				TST_Builder.optionalFields.addAll(optionalFields);

				// Set global flag so nested child builders inherit mock ID generation
				if(generateMockIds && !doInsert)
				{
					TST_BuilderInternal.globalGenerateMockIds = true;
				}

				// Build deferred children NOW (after global flag is set) so they inherit mock ID generation
				for(String relationshipName : deferredChildBuilders.keySet())
				{
					Builder childBuilder = deferredChildBuilders.get(relationshipName);
					List<SObject> children = childBuilder.withoutInsertion().buildList();
					childRelationships.put(relationshipName, children);
				}

				// Delegate to Internal for child relationship handling (single UOW transaction)
				// Mock IDs are applied via MockIdProvider in prepareOverrides() when generateMockIds is true
				if(!childRelationships.isEmpty())
				{
					return buildInternalWithChildren(sObjectType, prepareOverrides(), numberOfSObjects, doInsert, childRelationships);
				}

				// Standard path: no children
				return buildInternal(sObjectType, prepareOverrides(), numberOfSObjects, doInsert);
			}
			finally
			{
				TST_Builder.optionalFields.clear();
				TST_Builder.optionalFields.addAll(optionalFieldsToRestore);
				TST_BuilderInternal.globalGenerateMockIds = previousGlobalMockIds;
			}
		}

		/**
		 * @description Private helper to combine defaulted fields and explicit overrides.
		 *
		 * @return A single map of all overrides.
		 */
		private Map<String, Object> prepareOverrides()
		{
			// Start with the auto-default map
			Map<String, Object> finalMap = TST_BuilderInternal.createAutoDefaultMap(fieldsToDefault, objectDescribe);
			// Add explicit overrides, which will take precedence
			finalMap.putAll(mapOfValuesOverride);

			// Add mock ID provider if requested OR if inherited from parent builder via global flag
			Boolean shouldGenerateMockIds = (generateMockIds || TST_BuilderInternal.globalGenerateMockIds) && !doInsert;
			if(shouldGenerateMockIds)
			{
				finalMap.put('Id', new TST_BuilderInternal.MockIdProvider(sObjectType));
			}

			return finalMap;
		}

		/**
		 * @description Inserts child relationships with proper parent ID assignment (for with insertion).
		 * Parents must already be inserted at this point.
		 *
		 * @param parents List of parent SObjects (already inserted with IDs)
		 */
		/**
		 * @description Determines the child relationship name from parent/child types.
		 * Detects multiple relationships and provides clear error message guiding to explicit variant.
		 *
		 * @param parentType The parent SObjectType
		 * @param childType The child SObjectType
		 *
		 * @return The child relationship name
		 *
		 * @throws IllegalArgumentException if no relationship found or multiple relationships exist
		 */
		private String getChildRelationshipName(SObjectType parentType, SObjectType childType)
		{
			// Delegate to Internal helper
			return new TST_BuilderInternal.ChildRelationshipHelper().getChildRelationshipName(parentType, childType);
		}

	}

	/**
	 * @description Creates a list of SObjects with specified field values and controls insertion.
	 * (Core implementation method, now private)
	 *
	 * @param objectType The `SObjectType` of the SObject to create.
	 * @param mapOfValuesOverride A map of field names to their override values.
	 * @param numberOfSObjects The number of SObjects to create.
	 * @param doInsert If `true`, the SObjects are inserted.
	 *
	 * @return A list of the created SObject records.
	 */
	private static List<SObject> buildInternal(SObjectType objectType, Map<String, Object> mapOfValuesOverride, Integer numberOfSObjects, Boolean doInsert)
	{
		return factoryProvider.createFactory(objectType).getListSObjectInstance(mapOfValuesOverride, doInsert, numberOfSObjects);
	}

	/**
	 * @description Creates a list of SObjects with child relationships using a single UOW transaction.
	 * Delegates to TST_BuilderInternal for complex logic.
	 *
	 * @param objectType The `SObjectType` of the SObject to create.
	 * @param mapOfValuesOverride A map of field names to their override values.
	 * @param numberOfSObjects The number of SObjects to create.
	 * @param doInsert If `true`, the SObjects and children are inserted atomically.
	 * @param childRelationships Map of relationship names to child SObject lists.
	 *
	 * @return A list of the created SObject records with children.
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private static List<SObject> buildInternalWithChildren
			(
					SObjectType objectType,
					Map<String, Object> mapOfValuesOverride,
					Integer numberOfSObjects,
					Boolean doInsert,
					Map<String, List<SObject>> childRelationships
			)
	{
		Factory baseFactory = factoryProvider.createFactory(objectType);

		// Check if the factory supports child relationships
		if(!(baseFactory instanceof FactoryWithChildren))
		{
			throw new UnsupportedOperationException(
					'The configured factory provider does not support child relationships. ' +
					'Child relationship functionality requires a factory that implements FactoryWithChildren. ' +
					'Please use the default factory provider or implement FactoryWithChildren in your custom factory.'
			);
		}

		// Safe to cast now
		FactoryWithChildren factory = (FactoryWithChildren)baseFactory;
		return factory.getListSObjectInstanceWithChildren(mapOfValuesOverride, doInsert, numberOfSObjects, childRelationships, objectType);
	}

	/**
	 * @description Defines an interface for a provider that creates SObjectFactory instances.
	 * @warning FOR INTERNAL FRAMEWORK USE ONLY.
	 * Do not implement this interface in a subscriber org.
	 */
	public interface FactoryProvider
	{
		/**
		 * @description Creates an instance of a class that implements `Factory`.
		 *
		 * @param sObjectType The SObject type for which the factory will create records.
		 *
		 * @return An instance of an `Factory` implementation.
		 */
		Factory createFactory(SObjectType sObjectType);
	}

	/**
	 * @description Defines the interface for managing SObject instances during the build process.
	 * @warning FOR INTERNAL FRAMEWORK USE ONLY.
	 * Do not implement this interface in a subscriber org.
	 * To customize default values, extend 'UTIL_SObjectBuilderDefaultProvider' instead.
	 */
	public interface Manager
	{
		/**
		 * @description Gets the list of main SObjects being built.
		 *
		 * @return The list of SObjects.
		 */
		List<SObject> getMainObjects();

		/**
		 * @description Sets an SObject at a specific index in the main list.
		 *
		 * @param index The index.
		 * @param sObj The SObject to set.
		 */
		void setSObject(Integer index, SObject sObj);

		/**
		 * @description Gets an SObject from a specific index in the main list.
		 *
		 * @param index The index.
		 *
		 * @return The SObject at the index.
		 */
		SObject getSObject(Integer index);

		/**
		 * @description Inserts all managed SObjects (main and related) in the correct dependency order.
		 */
		void insertAll();
	}

	/**
	 * @description Defines the interface for the SObject factory.
	 * @warning FOR INTERNAL FRAMEWORK USE ONLY.
	 * Do not implement this interface in a subscriber org.
	 * To customize default values, extend 'UTIL_SObjectBuilderDefaultProvider' instead.
	 */
	public interface Factory
	{
		/**
		 * @description Gets the SObject manager.
		 *
		 * @return The `Manager` instance.
		 */
		Manager getSObjectManager();
		/**
		 * @description Gets a single SObject instance.
		 *
		 * @param mapOfValuesOverride Map of values to override.
		 * @param doInsert Flag to insert the record.
		 *
		 * @return The created SObject.
		 */
		SObject getSObjectInstance(Map<String, Object> mapOfValuesOverride, Boolean doInsert);
		/**
		 * @description Gets a list of SObject instances.
		 *
		 * @param mapOfValuesOverride Map of values to override.
		 * @param doInsert Flag to insert the records.
		 * @param numberOfSObjects Number of records to create.
		 *
		 * @return A list of created SObjects.
		 */
		List<SObject> getListSObjectInstance(Map<String, Object> mapOfValuesOverride, Boolean doInsert, Integer numberOfSObjects);
	}

	/**
	 * @description Extended interface for SObject factories that support child relationships.
	 * This interface is implemented by the internal factory to enable parent-child record
	 * creation within a single Unit of Work transaction.
	 *
	 * @warning FOR INTERNAL FRAMEWORK USE ONLY.
	 * Do not implement this interface in a subscriber org.
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	public interface FactoryWithChildren extends Factory
	{
		/**
		 * @description Creates parent SObjects with associated child records in a single UOW transaction.
		 *
		 * @param mapOfValuesOverride Map of field values to override for parent records.
		 * @param doInsert If true, inserts parent and child records atomically.
		 * @param numberOfSObjects Number of parent records to create.
		 * @param childRelationships Map of relationship names to lists of child SObjects.
		 * @param objectType The SObjectType of the parent records.
		 *
		 * @return A list of parent SObjects with children attached.
		 */
		List<SObject> getListSObjectInstanceWithChildren
				(
						Map<String, Object> mapOfValuesOverride,
						Boolean doInsert,
						Integer numberOfSObjects,
						Map<String, List<SObject>> childRelationships,
						SObjectType objectType
				);
	}

	/**
	 * @description Base class for default value providers. Extend 'UTIL_SObjectBuilderDefaultProvider'
	 * (which extends this class) to customize default value generation.
	 *
	 * @note Using a virtual class instead of an interface allows adding new methods in future
	 * managed package versions without breaking existing subscriber implementations.
	 *
	 * @since 1.0
	 */
	global virtual class DefaultValueProvider
	{
		/**
		 * @description Gets the default map of values for a given SObjectType.
		 *
		 * @param sObjectType The SObjectType.
		 * @param mapOfValuesOverride A map of override values.
		 *
		 * @return A map of default field values, keyed by fully-qualified field name (e.g., 'Name' or 'Account.Name').
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * global override Map<String, DefaultFieldValueProvider> getDefaultMapOfValues(SObjectType sObjectType, Map<String, Object> mapOfValuesOverride)
		 * {
		 *     Map<String, DefaultFieldValueProvider> defaults = super.getDefaultMapOfValues(sObjectType, mapOfValuesOverride);
		 *     // add custom default providers
		 *     return defaults;
		 * }
		 * ```
		 */
		global virtual Map<String, DefaultFieldValueProvider> getDefaultMapOfValues(SObjectType sObjectType, Map<String, Object> mapOfValuesOverride)
		{
			return new Map<String, DefaultFieldValueProvider>();
		}
	}

	/**
	 * @description Base class for field-level default value providers.
	 *
	 * @note Using a virtual class instead of an interface allows adding new methods in future
	 * managed package versions without breaking existing implementations.
	 *
	 * @since 1.0
	 */
	global virtual class DefaultFieldValueProvider
	{
		/**
		 * @description Gets the wrapped value for a given record index.
		 *
		 * @param recordIndex The index of the record (e.g., 0 for the first record, 1 for the second).
		 *
		 * @return The value for the specified index.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * global override Object getValue(Integer recordIndex)
		 * {
		 *     return 'Record ' + recordIndex;
		 * }
		 * ```
		 */
		global virtual Object getValue(Integer recordIndex)
		{
			return null;
		}
	}

}