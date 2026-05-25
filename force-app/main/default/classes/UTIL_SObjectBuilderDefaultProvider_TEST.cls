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
 * @description Test class for UTIL_SObjectBuilderDefaultProvider
 *
 * @see UTIL_SObjectBuilderDefaultProvider
 *
 * @author Jason van Beukering
 *
 * @group Testing
 *
 * @date October 2025, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CyclomaticComplexity')
private class UTIL_SObjectBuilderDefaultProvider_TEST
{
	// Lowercase Keys (String map key for assertions, derived from SEL_Foobar)
	private static final String FOOBAR_CHECKBOX_FIELD_KEY = SEL_Foobar.FIELD_CHECK_BOX.toLowerCase();
	private static final String FOOBAR_CURRENCY_FIELD_KEY = SEL_Foobar.FIELD_CURRENCY.toLowerCase();
	private static final String FOOBAR_DATETIME_FIELD_KEY = SEL_Foobar.FIELD_DATETIME.toLowerCase();
	private static final String FOOBAR_DATE_FIELD_KEY = SEL_Foobar.FIELD_DATE.toLowerCase();
	private static final String FOOBAR_DECIMAL_FIELD_KEY = SEL_Foobar.FIELD_DECIMAL.toLowerCase();
	private static final String FOOBAR_EMAIL_FIELD_KEY = SEL_Foobar.FIELD_EMAIL.toLowerCase();
	private static final String FOOBAR_GEOLOCATION_FIELD_KEY = SEL_Foobar.FIELD_GEOLOCATION.toLowerCase();
	private static final String FOOBAR_INTEGER_FIELD_KEY = SEL_Foobar.FIELD_INTEGER.toLowerCase();
	private static final String FOOBAR_NAME_FIELD_KEY = SEL_Foobar.FIELD_NAME.toLowerCase();
	private static final String FOOBAR_PERCENT_FIELD_KEY = SEL_Foobar.FIELD_PERCENT.toLowerCase();
	private static final String FOOBAR_PHONE_FIELD_KEY = SEL_Foobar.FIELD_PHONE.toLowerCase();
	private static final String FOOBAR_PICKLIST_FIELD_KEY = SEL_Foobar.FIELD_PICKLIST.toLowerCase();
	private static final String FOOBAR_PICKLIST_MULTI_SELECT_FIELD_KEY = SEL_Foobar.FIELD_PICKLIST_MULTI_SELECT.toLowerCase();
	private static final String FOOBAR_TEXT_AREA_FIELD_KEY = SEL_Foobar.FIELD_TEXT_AREA.toLowerCase();
	private static final String FOOBAR_TEXT_FIELD_KEY = SEL_Foobar.FIELD_TEXT.toLowerCase();
	private static final String FOOBAR_URL_FIELD_KEY = SEL_Foobar.FIELD_URL.toLowerCase();

	// Relationship / Compound Keys
	private static final String FOOBAR_LOOKUP_RELATIONSHIP_NAME_KEY = SEL_Foobar.RELATIONSHIP_LOOKUP.toLowerCase();
	private static final String FOOBAR_RELATIONSHIP_TEXT_AREA_FIELD_KEY = FOOBAR_LOOKUP_RELATIONSHIP_NAME_KEY + UTIL_String.DOT + FOOBAR_TEXT_AREA_FIELD_KEY;
	private static final String FOOBAR_RELATIONSHIP_TEXT_FIELD_KEY = FOOBAR_LOOKUP_RELATIONSHIP_NAME_KEY + UTIL_String.DOT + FOOBAR_TEXT_FIELD_KEY;

	/**
	 * @description Given: An SObject with standard required fields (Opportunity)
	 * When: 'getDefaultMapOfValues' is called with an empty map
	 * Then: The resulting map contains providers for all required fields (Name, StageName, CloseDate)
	 * @note This test MUST use Opportunity as Foobar__c has no default required fields.
	 */
	@IsTest
	private static void givenOpportunityWhenMapGeneratedThenRequiredFieldsPopulated()
	{
		Map<String, TST_Builder.DefaultFieldValueProvider> mapOfValues = generateMap(Opportunity.SObjectType);

		Assert.isNotNull(mapOfValues, 'The map of values should not be null.');

		assertPopulated(mapOfValues, 'name', String.class, 'Opportunity Name should be defaulted.');

		String stageNameValue = (String)assertPopulated(mapOfValues, 'stagename', String.class, 'Opportunity StageName should be defaulted and not null.');
		Assert.isTrue(String.isNotBlank(stageNameValue), 'Opportunity StageName should not be empty.');

		assertPopulated(mapOfValues, 'closedate', 'Opportunity CloseDate should be defaulted.');
	}

	/**
	 * @description Given: An SObject with a required lookup (Contract)
	 * When: 'getDefaultMapOfValues' is called with an empty map
	 * Then: The resulting map contains providers for the related object's required fields
	 * @note This test MUST use Contract as Foobar__c's lookup is not required.
	 */
	@IsTest
	private static void givenContractWhenMapGeneratedThenRequiredLookupPopulated()
	{
		Map<String, TST_Builder.DefaultFieldValueProvider> mapOfValues = generateMap(Contract.SObjectType);

		Assert.isNotNull(mapOfValues, 'The map of values should not be null.');
		assertMissing(mapOfValues, 'account.id', 'Contract.Account.Id should be null by default, but the relationship should be processed.');
		assertPopulated(mapOfValues, 'account.name', 'Related Account.Name should be populated.');
	}

	/**
	 * @description Given: An SObject with required fields (Contact) and a null override map
	 * When: 'getDefaultMapOfValues' is called
	 * Then: The resulting map still contains providers for required fields
	 * @note This test MUST use Contact as Foobar__c has no default required fields.
	 */
	@IsTest
	private static void givenContactWithNullMapWhenMapGeneratedThenRequiredFieldsPopulated()
	{
		Map<String, TST_Builder.DefaultFieldValueProvider> mapOfValues =
				new UTIL_SObjectBuilderDefaultProvider().getDefaultMapOfValues(Contact.SObjectType, null);

		// Then required fields are still populated
		Assert.isNotNull(mapOfValues, 'The map of values should not be null.');
		assertPopulated(mapOfValues, 'lastname', String.class, 'LastName should be defaulted when override map is null.');
	}

	/**
	 * @description Given: An SObject (Case) with a related Id provided ('contact.id')
	 * When: 'getDefaultMapOfValues' is called
	 * Then: The related object's required fields (Contact.LastName) are still populated
	 * @note This test MUST use Case/Contact.
	 */
	@IsTest
	private static void givenCaseWithRelatedIdWhenMapGeneratedThenRelatedRequiredFieldsPopulated()
	{
		Map<String, Object> overrides = new Map<String, Object>
		{
				'contact.id' => null
		};

		Map<String, TST_Builder.DefaultFieldValueProvider> mapOfValues = generateMap(Case.SObjectType, overrides);

		Assert.isNotNull(mapOfValues, 'The map of values should not be null.');
		assertPopulated(mapOfValues, 'contact.lastname', String.class, 'Related Contact.LastName should still be populated even if Contact.Id was in the map.');
	}

	/**
	 * @description Given: An override map containing a List<Object> for a field
	 * When: 'getDefaultMapOfValues' is called
	 * Then: The resulting map contains a ListFieldDefaultValue provider for that field
	 * @note This test CAN use Foobar__c as it tests the override mechanism.
	 */
	@IsTest
	private static void givenListOverrideWhenMapGeneratedThenListProviderCreated()
	{
		Map<String, Object> overrides = new Map<String, Object>
		{
				SEL_Foobar.FIELD_NAME => new List<String> {'test1', 'test2'}
		};

		Map<String, TST_Builder.DefaultFieldValueProvider> mapOfValues = generateMap(Foobar__c.SObjectType, overrides);

		Assert.isNotNull(mapOfValues, 'The map of values should not be null.');
		Assert.isTrue(mapOfValues.get(FOOBAR_NAME_FIELD_KEY) instanceof UTIL_SObjectBuilderDefaultProvider.ListFieldDefaultValue, 'Should be a ListFieldDefaultValue provider');
		assertValue(mapOfValues, FOOBAR_NAME_FIELD_KEY, 0, 'test1', 'Name for index 0 should be from the override list.');
		assertValue(mapOfValues, FOOBAR_NAME_FIELD_KEY, 1, 'test2', 'Name for index 1 should be from the override list.');
	}

	/**
	 * @description Given: An override map containing a nested Map<String, Object> for a relationship
	 * When: 'getDefaultMapOfValues' is called
	 * Then: The resulting map contains flattened dot-notation providers for the nested fields
	 * @note This test CAN use Foobar__c as it tests the override mechanism.
	 */
	@IsTest
	private static void givenNestedMapOverrideWhenMapGeneratedThenFieldsFlattened()
	{
		Map<String, Object> overrides = new Map<String, Object>
		{
				SEL_Foobar.RELATIONSHIP_LOOKUP => new Map<String, Object> // Use the relationship name from DAL
				{
						SEL_Foobar.FIELD_TEXT => 'test1',
						SEL_Foobar.FIELD_TEXT_AREA => 'test2'
				}
		};

		Map<String, TST_Builder.DefaultFieldValueProvider> mapOfValues = generateMap(Foobar__c.SObjectType, overrides);

		Assert.isNotNull(mapOfValues, 'The map of values should not be null.');
		assertValue(mapOfValues, FOOBAR_RELATIONSHIP_TEXT_FIELD_KEY, 'test1', 'Foobars.Text__c should be set from the nested map.');
		assertValue(mapOfValues, FOOBAR_RELATIONSHIP_TEXT_AREA_FIELD_KEY, 'test2', 'Foobars.TextArea__c should be set from the nested map.');
	}

	/**
	 * @description Given: An SObject (Case) with deeply nested field overrides
	 * When: 'getDefaultMapOfValues' is called
	 * Then: The overrides are preserved AND required fields at all levels are populated
	 * @note This test MUST use Case/Asset/Contact.
	 */
	@IsTest
	private static void givenDeeplyNestedOverridesWhenMapGeneratedThenOverridesPreserved()
	{
		Map<String, Object> overrides = new Map<String, Object>
		{
				'asset.contact.description' => 'test0',
				'asset.parent.contact.description' => 'test1'
		};

		Map<String, TST_Builder.DefaultFieldValueProvider> mapOfValues = generateMap(Case.SObjectType, overrides);

		Assert.isNotNull(mapOfValues, 'The map of values should not be null.');
		assertPopulated(mapOfValues, 'asset.contact.lastname', 'Asset.Contact.LastName should be populated.');
		assertValue(mapOfValues, 'asset.contact.description', 'test0', 'Asset.Contact.Description override should be preserved.');
		assertPopulated(mapOfValues, 'asset.parent.contact.lastname', 'Asset.Parent.Contact.LastName should be populated.');
		assertValue(mapOfValues, 'asset.parent.contact.description', 'test1', 'Asset.Parent.Contact.Description override should be preserved.');
	}

	/**
	 * @description Given: An override map that already contains a FieldDefaultValue provider
	 * When: 'getDefaultMapOfValues' is called
	 * Then: The existing provider is preserved
	 * @note This test CAN use Foobar__c as it tests override preservation.
	 */
	@IsTest
	private static void givenExistingListProviderWhenMapGeneratedThenProviderPreserved()
	{
		UTIL_SObjectBuilderDefaultProvider.ListFieldDefaultValue existingProvider =
				new UTIL_SObjectBuilderDefaultProvider.ListFieldDefaultValue(new List<String> {'desc1', 'desc2'});
		Map<String, TST_Builder.DefaultFieldValueProvider> mapOfValues = new Map<String, TST_Builder.DefaultFieldValueProvider>
		{
				FOOBAR_TEXT_AREA_FIELD_KEY => existingProvider
		};

		new UTIL_SObjectBuilderDefaultProvider().generateDefaultMapOfValues(Foobar__c.SObjectType, mapOfValues, UTIL_String.EMPTY);

		Assert.isNotNull(mapOfValues, 'The map of values should not be null.');
		assertValue(mapOfValues, FOOBAR_TEXT_AREA_FIELD_KEY, 0, 'desc1', 'Value at index 0 from the ListFieldDefaultValue should be preserved.');
		assertValue(mapOfValues, FOOBAR_TEXT_AREA_FIELD_KEY, 1, 'desc2', 'Value at index 1 from the ListFieldDefaultValue should be preserved.');
		Assert.areEqual(existingProvider, mapOfValues.get(FOOBAR_TEXT_AREA_FIELD_KEY), 'The original provider instance should be preserved.');
	}

	/**
	 * @description Given: A custom provider that overrides 'defineSObjectRequiredFields'
	 * When: 'getDefaultMapOfValues' is called
	 * Then: The custom required fields are populated
	 * @note This test CAN use Foobar__c because it uses the custom provider.
	 */
	@IsTest
	private static void givenCustomRequiredFieldsWhenMapGeneratedThenCustomFieldsPopulated()
	{
		UTIL_SObjectBuilderDefaultProvider customProvider = new DefaultValueProviderOverride();
		Map<String, Object> overrides = new Map<String, Object>
		{
				FOOBAR_TEXT_FIELD_KEY => 'test0' // This field is optional in our custom provider
		};

		Map<String, TST_Builder.DefaultFieldValueProvider> mapOfValues =
				customProvider.getDefaultMapOfValues(Foobar__c.SObjectType, overrides);

		Assert.isNotNull(mapOfValues, 'The map of values should not be null.');
		assertValue(mapOfValues, FOOBAR_TEXT_FIELD_KEY, 'test0', 'Text__c should be set from the override map.');

		assertPopulated(mapOfValues, FOOBAR_NAME_FIELD_KEY, String.class, 'Name should be populated by the custom provider\'s required fields.');
		assertValue(mapOfValues, FOOBAR_EMAIL_FIELD_KEY, 'my_custom_email0@email.com', 'Email__c should be populated by the custom provider\'s overridden default value method.');
	}

	/**
	 * @description Given: A custom provider that overrides 'defineSObjectOptionalFields'
	 * When: 'getDefaultMapOfValues' is called
	 * Then: The default required fields (Name) are suppressed
	 * @note This test CAN use Foobar__c because it uses the custom provider.
	 */
	@IsTest
	private static void givenCustomOptionalFieldsWhenMapGeneratedThenDefaultFieldsSuppressed()
	{
		UTIL_SObjectBuilderDefaultProvider customProvider = new DefaultValueProviderOverride();
		Map<String, Object> overrides = new Map<String, Object>();

		Map<String, TST_Builder.DefaultFieldValueProvider> mapOfValues =
				customProvider.getDefaultMapOfValues(Foobar__c.SObjectType, overrides);

		Assert.isNotNull(mapOfValues, 'The map of values should not be null.');
		assertMissing(mapOfValues, FOOBAR_TEXT_FIELD_KEY, 'Text__c should be null as it was defined as optional in the custom provider.');

		// And the fields marked as required ARE populated
		assertPopulated(mapOfValues, FOOBAR_NAME_FIELD_KEY, String.class, 'Name should be populated by the custom provider\'s required fields.');
		assertValue(mapOfValues, FOOBAR_EMAIL_FIELD_KEY, 'my_custom_email0@email.com', 'Email__c should be populated by the custom provider\'s overridden default value method.');
	}

	/**
	 * @description Custom provider override, refactored to use Foobar__c and
	 * correctly define Name as required for these tests.
	 */
	private class DefaultValueProviderOverride extends UTIL_SObjectBuilderDefaultProvider
	{
		public override Set<SObjectField> defineSObjectRequiredFields(SObjectType sObjectType)
		{
			if(sObjectType == Foobar__c.SObjectType)
			{
				return new Set<SObjectField>
				{
						Foobar__c.Email__c,
						Foobar__c.Name
				};
			}
			return null;
		}

		public override Set<SObjectField> defineSObjectOptionalFields(SObjectType sObjectType)
		{
			if(sObjectType == Foobar__c.SObjectType)
			{
				return new Set<SObjectField>
				{
						Foobar__c.TextArea__c,
						Foobar__c.Text__c
				};
			}
			return null;
		}

		public override String getEmailDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
		{
			// This override is to test that the custom provider is being called
			return 'my_custom_email' + recordIndex.format() + '@email.com';
		}
	}

	/**
	 * @description Given: A custom provider that defines all Foobar__c fields as required
	 * When: 'getDefaultMapOfValues' is called
	 * Then: The resulting map contains valid, non-null providers for every data type
	 * @note This single test replaces the need for 'providerGetDefaultValueDispatchesByType'
	 * and 'providerGetTypeSpecificDefaultValues' by testing the dispatching
	 * behavior of 'getDefaultValue' indirectly.
	 */
	@IsTest
	private static void whenAllFieldTypesRequiredThenAllTypesPopulated()
	{
		UTIL_SObjectBuilderDefaultProvider allTypesProvider = new AllTypesRequiredProvider();
		Map<String, Object> overrides = new Map<String, Object>();

		Map<String, TST_Builder.DefaultFieldValueProvider> mapOfValues =
				allTypesProvider.getDefaultMapOfValues(Foobar__c.SObjectType, overrides);

		assertPopulated(mapOfValues, FOOBAR_CHECKBOX_FIELD_KEY, Boolean.class, 'Should return default for BOOLEAN.');
		assertPopulated(mapOfValues, FOOBAR_CURRENCY_FIELD_KEY, Decimal.class, 'Should return default for CURRENCY.');
		assertPopulated(mapOfValues, FOOBAR_DATE_FIELD_KEY, Date.class, 'Should return default for DATE.');
		assertPopulated(mapOfValues, FOOBAR_DATETIME_FIELD_KEY, Datetime.class, 'Should return default for DATETIME.');
		assertPopulated(mapOfValues, FOOBAR_EMAIL_FIELD_KEY, String.class, 'Should return default for EMAIL.');
		assertPopulated(mapOfValues, FOOBAR_GEOLOCATION_FIELD_KEY, Location.class, 'Should return default for LOCATION.');
		assertPopulated(mapOfValues, FOOBAR_INTEGER_FIELD_KEY, Decimal.class, 'Should return default for INTEGER.');
		assertPopulated(mapOfValues, FOOBAR_DECIMAL_FIELD_KEY, Decimal.class, 'Should return default for DOUBLE.');
		assertPopulated(mapOfValues, FOOBAR_PERCENT_FIELD_KEY, Decimal.class, 'Should return default for PERCENT.');
		assertPopulated(mapOfValues, FOOBAR_PHONE_FIELD_KEY, String.class, 'Should return default for PHONE.');
		assertPopulated(mapOfValues, FOOBAR_PICKLIST_FIELD_KEY, 'Should return default for PICKLIST.');
		assertPopulated(mapOfValues, FOOBAR_PICKLIST_MULTI_SELECT_FIELD_KEY, 'Should return default for MULTIPICKLIST.');
		assertPopulated(mapOfValues, FOOBAR_TEXT_FIELD_KEY, String.class, 'Should return default for STRING.');
		assertPopulated(mapOfValues, FOOBAR_TEXT_AREA_FIELD_KEY, String.class, 'Should return default for TEXTAREA.');
		assertPopulated(mapOfValues, FOOBAR_URL_FIELD_KEY, String.class, 'Should return default for URL.');
	}

	/**
	 * @description Custom provider that marks (almost) all fields on Foobar__c as required
	 * to test the 'getDefaultValue' dispatching for all types.
	 */
	private class AllTypesRequiredProvider extends UTIL_SObjectBuilderDefaultProvider
	{
		public override Set<SObjectField> defineSObjectRequiredFields(SObjectType sObjectType)
		{
			return new Set<SObjectField>
			{
					Foobar__c.Checkbox__c,
					Foobar__c.Currency__c,
					Foobar__c.Date__c,
					Foobar__c.Datetime__c,
					Foobar__c.Email__c,
					Foobar__c.Geolocation__c,
					Foobar__c.NumberDecimal__c,
					Foobar__c.NumberInteger__c,
					Foobar__c.Percent__c,
					Foobar__c.Phone__c,
					Foobar__c.PicklistMultiSelect__c,
					Foobar__c.Picklist__c,
					Foobar__c.TextArea__c,
					Foobar__c.Text__c,
					Foobar__c.URL__c
			};

		}
	}

	/**
	 * @description Given: The SObject is Account
	 * When: 'getDefaultMapOfValues' is called and Person Accounts are (mocked) enabled
	 * Then: The 'if(objectType == Account.SObjectType && isPersonAccountEnabled())' block is executed,
	 * and 'managePersonAccountOrgEnabled' is called, populating 'Name' and 'RecordTypeId'.
	 */
	@IsTest
	private static void givenAccountWhenMapGeneratedAndPersonAccountsEnabledThenManageLogicCalled()
	{
		mockPersonAccountsIfNotEnabled();

		UTIL_SObjectBuilderDefaultProvider.isMockActive = UTIL_SObjectBuilderDefaultProvider.mockPersonAccountsAreEnabled;

		Map<String, TST_Builder.DefaultFieldValueProvider> mapOfValues = generateMap(Account.SObjectType);
		Assert.isNotNull(mapOfValues, 'The map of values should not be null.');
		assertPopulated(mapOfValues, 'recordtypeid', Id.class, 'RecordTypeId should be defaulted.');
		assertPopulated(mapOfValues, 'name', String.class, 'Account Name should be required for the default business record type.');
	}

	/**
	 * @description Given: A request for an Account in ANY org (mocked if PA is disabled)
	 * When: 'managePersonAccountOrgEnabled' is called
	 * Then: The default *business* Account RecordTypeId is populated and Name is required
	 */
	@IsTest
	private static void providerManagePersonAccountDefaultsRecordType()
	{
		UTIL_SObjectBuilderDefaultProvider.isMockActive = true;
		mockPersonAccountsIfNotEnabled();

		UTIL_SObjectBuilderDefaultProvider defaultValueProvider = new UTIL_SObjectBuilderDefaultProvider();
		Map<String, TST_Builder.DefaultFieldValueProvider> providerMap = new Map<String, TST_Builder.DefaultFieldValueProvider>();
		Set<String> definedRequiredFields = new Set<String>();

		// We must test the internal method here as 'getDefaultMapOfValues' would hide 'definedRequiredFields'
		defaultValueProvider.managePersonAccountOrgEnabled(providerMap, UTIL_String.EMPTY, definedRequiredFields);

		Assert.areEqual(1, providerMap.keySet().size(), 'Map should only contain the RecordTypeId.');
		Object recordTypeId = assertPopulated(providerMap, 'recordtypeid', Id.class, 'RecordTypeId key should exist.');
		Assert.areEqual
				(
						defaultValueProvider.accountDefaultRecordTypeId,
						recordTypeId,
						'RecordTypeId should be the default business Account record type.'
				);
		Assert.areEqual(1, definedRequiredFields.size(), 'Required fields set should contain one entry (Name).');
	}

	/**
	 * @description Given: An override map specifying a *business* Account RecordTypeId
	 * When: 'managePersonAccountOrgEnabled' is called
	 * Then: The provider correctly identifies it and requires 'Name'
	 */
	@IsTest
	private static void providerManagePersonAccountWithBusinessRecordType()
	{
		UTIL_SObjectBuilderDefaultProvider defaultValueProvider = new UTIL_SObjectBuilderDefaultProvider();
		Id businessAccountRecordTypeId = UTIL_SObjectDescribe.getDescribe(Account.SObjectType).getDescribe().getRecordTypeInfos().iterator().next().recordTypeId;
		Map<String, TST_Builder.DefaultFieldValueProvider> providerMap = new Map<String, TST_Builder.DefaultFieldValueProvider>
		{
				'account.recordtypeid' => new UTIL_SObjectBuilderDefaultProvider.FieldDefaultValue(businessAccountRecordTypeId)
		};
		Set<String> definedRequiredFields = new Set<String>();

		defaultValueProvider.managePersonAccountOrgEnabled(providerMap, 'account.', definedRequiredFields);

		Assert.areEqual(1.0, providerMap.keySet().size(), 'Map size should be 1.');
		Object recordTypeId = assertPopulated(providerMap, 'account.recordtypeid', Id.class, 'RecordTypeId key should exist.');
		Assert.areEqual(businessAccountRecordTypeId, recordTypeId, 'RecordTypeId should match the provided business record type.');
		Assert.areEqual(1.0, definedRequiredFields.size(), 'Required fields set should contain one entry (Name).');
	}

	/**
	 * @description Given: An override map specifying a *person* Account RecordTypeId (real or mocked)
	 * When: 'managePersonAccountOrgEnabled' is called
	 * Then: The provider correctly identifies it and requires 'LastName'
	 */
	@IsTest
	private static void providerManagePersonAccountWithPersonRecordType()
	{
		UTIL_SObjectBuilderDefaultProvider.isMockActive = true;
		Id personAccountRecordTypeId = mockPersonAccountsIfNotEnabled();

		UTIL_SObjectBuilderDefaultProvider defaultValueProvider = new UTIL_SObjectBuilderDefaultProvider();
		Map<String, TST_Builder.DefaultFieldValueProvider> providerMap = new Map<String, TST_Builder.DefaultFieldValueProvider>
		{
				'account.recordtypeid' => new UTIL_SObjectBuilderDefaultProvider.FieldDefaultValue(personAccountRecordTypeId)
		};
		Set<String> definedRequiredFields = new Set<String>();

		defaultValueProvider.managePersonAccountOrgEnabled(providerMap, 'account.', definedRequiredFields);

		Assert.areEqual(1.0, providerMap.keySet().size(), 'Map size should be 1.');
		Object recordTypeId = assertPopulated(providerMap, 'account.recordtypeid', Id.class, 'RecordTypeId key should exist.');
		Assert.areEqual(personAccountRecordTypeId, recordTypeId, 'RecordTypeId should match the provided person account record type.');
		Assert.areEqual(1.0, definedRequiredFields.size(), 'Required fields set should contain one entry (LastName).');
	}

	/**
	 * @description Given: An override map specifying a List for 'RecordTypeId'
	 * When: 'managePersonAccountOrgEnabled' is called
	 * Then: An IllegalStateException is thrown
	 */
	@IsTest
	private static void providerManagePersonAccountWithListRecordTypeThrowsException()
	{
		UTIL_SObjectBuilderDefaultProvider defaultValueProvider = new UTIL_SObjectBuilderDefaultProvider();
		Id personAccountRecordTypeId = UTIL_SObjectDescribe.getDescribe(Account.SObjectType).getDescribe().getRecordTypeInfos().get(0).recordTypeId;
		Map<String, TST_Builder.DefaultFieldValueProvider> mapOfValues = new Map<String, TST_Builder.DefaultFieldValueProvider>
		{
				'account.recordtypeid' => new UTIL_SObjectBuilderDefaultProvider.ListFieldDefaultValue(new List<Id> {personAccountRecordTypeId})
		};
		Set<String> definedRequiredFields = new Set<String>();

		try
		{
			defaultValueProvider.managePersonAccountOrgEnabled(mapOfValues, 'account.', definedRequiredFields);
			Assert.fail('Expected an UTIL_Exceptions.IllegalStateException for a List of RecordTypeIds, but none was thrown.');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, UTIL_Exceptions.IllegalStateException.class, 'Expected an UTIL_Exceptions.IllegalStateException.');
		}
	}

	/**
	 * @description Given: An override map specifying an invalid value for 'RecordTypeId'
	 * When: 'managePersonAccountOrgEnabled' is called
	 * Then: A TypeException is thrown
	 */
	@IsTest
	private static void providerManagePersonAccountWithInvalidRecordTypeObjectThrowsException()
	{
		UTIL_SObjectBuilderDefaultProvider defaultValueProvider = new UTIL_SObjectBuilderDefaultProvider();
		Map<String, TST_Builder.DefaultFieldValueProvider> mapOfValues = new Map<String, TST_Builder.DefaultFieldValueProvider>
		{
				// Simulate an invalid value that isn't an Id or a String
				'account.recordtypeid' => new UTIL_SObjectBuilderDefaultProvider.FieldDefaultValue(new List<Object> {UTIL_Random.randomInteger()})
		};

		try
		{
			Test.startTest();

			defaultValueProvider.managePersonAccountOrgEnabled(mapOfValues, 'account.', new Set<String>());

			Test.stopTest();

			Assert.fail('Expected a TypeException for an invalid RecordTypeId object type, but none was thrown.');
		}
		catch(Exception error)
		{
			// THEN
			assertIsTypeException(error, 'Expected a TypeException for an invalid RecordTypeId');
		}
	}

	/**
	 * @description Given: An override map specifying an invalid String for 'RecordTypeId' that is NOT an ID.
	 * When: 'managePersonAccountOrgEnabled' is called
	 * Then: An IllegalArgumentException is thrown (because validation fails returning null).
	 */
	@IsTest
	private static void providerManagePersonAccountWithMalformedIdThrowsIllegalArgument()
	{
		UTIL_SObjectBuilderDefaultProvider defaultValueProvider = new UTIL_SObjectBuilderDefaultProvider();
		Map<String, TST_Builder.DefaultFieldValueProvider> mapOfValues = new Map<String, TST_Builder.DefaultFieldValueProvider>
		{
				// "BadId" is a String, so it passes the type check, but fails ID validation
				'account.recordtypeid' => new UTIL_SObjectBuilderDefaultProvider.FieldDefaultValue('BadId')
		};

		try
		{
			Test.startTest();

			defaultValueProvider.managePersonAccountOrgEnabled(mapOfValues, 'account.', new Set<String>());

			Test.stopTest();

			Assert.fail('Expected IllegalArgumentException for malformed ID string.');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Should throw IllegalArgumentException when ID validation fails.');
		}
	}

	/**
	 * @description Tests the 'AutoFieldDefaultValue' provider, ensuring its 'getValue' method always returns null to signal auto-generation.
	 */
	@IsTest
	private static void autoFieldDefaultValueProviderGetValue()
	{
		TST_Builder.DefaultFieldValueProvider autoFieldDefaultValue = new UTIL_SObjectBuilderDefaultProvider.AutoFieldDefaultValue();
		Assert.isNull(autoFieldDefaultValue.getValue(0), 'AutoFieldDefaultValue should always return null.');
	}

	/**
	 * @description Given: An override map contains an AutoFieldDefaultValue placeholder
	 * When: 'getDefaultMapOfValues' is called
	 * Then: The provider is correctly replaced with a concrete value provider
	 * @note This test covers the `if(overrideFieldValue instanceof AutoFieldDefaultValue)` block
	 * in `handleOverriddenField` for both relationship and non-relationship fields.
	 */
	@IsTest
	private static void givenAutoFieldDefaultValueOverrideWhenMapGeneratedThenProviderReplaced()
	{
		Map<String, Object> overrides = new Map<String, Object>
		{
				'Description' => new UTIL_SObjectBuilderDefaultProvider.AutoFieldDefaultValue(), // A standard, non-required field on Contact
				'AccountId' => new UTIL_SObjectBuilderDefaultProvider.AutoFieldDefaultValue() // A relationship field on Contact
		};

		Map<String, TST_Builder.DefaultFieldValueProvider> mapOfValues = generateMap(Contact.SObjectType, overrides);

		assertPopulated(mapOfValues, 'description', String.class, 'Description should be auto-generated.');
		Assert.isTrue(mapOfValues.get('description') instanceof UTIL_SObjectBuilderDefaultProvider.FieldDefaultValue,
				'AutoFieldDefaultValue for Description should be replaced by FieldDefaultValue.');

		assertMissing(mapOfValues, 'accountid', 'Original AccountId provider should be removed.');
		assertMissing(mapOfValues, 'account.id', 'account.id value should be null by default.');
		Assert.isTrue(mapOfValues.get('account.id') instanceof UTIL_SObjectBuilderDefaultProvider.FieldDefaultValue, 'account.id provider should be FieldDefaultValue.');

		assertPopulated(mapOfValues, 'account.name', String.class, 'Relationship processing should populate related Account.Name.');
		assertPopulated(mapOfValues, 'lastname', 'Contact.LastName should still be populated.');
	}

	/**
	 * @description Tests the 'FieldDefaultValue' provider, ensuring 'getValue' returns the correct value for simple values,
	 * [index] merge fields, and when using a DefaultValueProvider.
	 * @note This test CAN use Foobar__c.
	 */
	@IsTest
	private static void fieldDefaultValueProviderGetValue()
	{
		Assert.isNull((new UTIL_SObjectBuilderDefaultProvider.FieldDefaultValue(null)).getValue(0), 'Provider with null value should return null.');

		TST_Builder.DefaultFieldValueProvider fieldDefaultValueSimple = new UTIL_SObjectBuilderDefaultProvider.FieldDefaultValue('test');
		Assert.areEqual('test', fieldDefaultValueSimple.getValue(0), 'Provider with simple value should return that value.');

		// Test [index] replacement
		TST_Builder.DefaultFieldValueProvider fieldDefaultValueIndexed = new UTIL_SObjectBuilderDefaultProvider.FieldDefaultValue('Test_[index]');
		Assert.areEqual('Test_0', fieldDefaultValueIndexed.getValue(0), 'Provider should replace [index] with 0.');
		Assert.areEqual('Test_123', fieldDefaultValueIndexed.getValue(123), 'Provider should replace [index] with 123.');

		// Test dynamic value generation
		TST_Builder.DefaultFieldValueProvider fieldDefaultValueEmail =
				new UTIL_SObjectBuilderDefaultProvider.FieldDefaultValue(new UTIL_SObjectBuilderDefaultProvider(), Foobar__c.Email__c);
		Assert.isTrue(fieldDefaultValueEmail.getValue(0) instanceof String, 'Provider should generate default EMAIL value.');

		TST_Builder.DefaultFieldValueProvider fieldDefaultValueId =
				new UTIL_SObjectBuilderDefaultProvider.FieldDefaultValue(new UTIL_SObjectBuilderDefaultProvider(), Foobar__c.Id);
		Assert.isNull(fieldDefaultValueId.getValue(0), 'Provider should return null for ID field type.');
	}

	/**
	 * @description Tests the 'ListFieldDefaultValue' provider, ensuring its 'size' and 'getValue' methods work correctly (including index cycling).
	 */
	@IsTest
	private static void listFieldDefaultValueProviderGetValue()
	{
		List<String> listValues = new List<String> {'test0', 'test1'};
		UTIL_SObjectBuilderDefaultProvider.ListFieldDefaultValue listFieldDefaultValue = new UTIL_SObjectBuilderDefaultProvider.ListFieldDefaultValue(listValues);
		Assert.areEqual(2, listFieldDefaultValue.size(), 'Size should be 2.');
		Assert.areEqual('test0', listFieldDefaultValue.getValue(0), 'Value at index 0 should be test0.');
		Assert.areEqual('test1', listFieldDefaultValue.getValue(1), 'Value at index 1 should be test1.');
		Assert.areEqual('test0', listFieldDefaultValue.getValue(2), 'Value at index 2 should cycle back to test0.');
		Assert.areEqual('test1', listFieldDefaultValue.getValue(3), 'Value at index 3 should cycle back to test1.');
	}

	/**
	 * @description Tests the 'RelationshipFieldDefaultValue' provider, ensuring its 'getValue' method returns the Id of the wrapped SObject.
	 * @note This test CAN use Foobar__c.
	 */
	@IsTest
	private static void relationshipFieldDefaultValueProviderGetValue()
	{
		Id testId = UTIL_Random.randomId(Foobar__c.SObjectType);
		UTIL_SObjectBuilderDefaultProvider.RelationshipFieldDefaultValue provider = new UTIL_SObjectBuilderDefaultProvider.RelationshipFieldDefaultValue(new Foobar__c(Id = testId));

		Assert.areEqual(testId, provider.getValue(0), 'Provider should return the Id of the wrapped SObject.');
		Assert.areEqual(testId, provider.getValue(100), 'Provider should return the same Id regardless of index.');
	}

	/**
	 * @description Tests the 'ListRelationshipFieldDefaultValue' provider, ensuring its 'size' and 'getValue' methods work correctly by returning the Id at the specified index.
	 * @note This test CAN use Foobar__c.
	 */
	@IsTest
	private static void listRelationshipFieldDefaultValueProviderGetValue()
	{
		Id testId0 = UTIL_Random.randomId(Foobar__c.SObjectType);
		Id testId1 = UTIL_Random.randomId(Foobar__c.SObjectType);
		List<SObject> listValues = new List<SObject> {new Foobar__c(Id = testId0), new Foobar__c(Id = testId1)};
		UTIL_SObjectBuilderDefaultProvider.ListRelationshipFieldDefaultValue provider = new UTIL_SObjectBuilderDefaultProvider.ListRelationshipFieldDefaultValue(listValues);

		Assert.areEqual(2, provider.size(), 'Size should be 2.');
		Assert.areEqual(testId0, provider.getValue(0), 'Value at index 0 should be testId0.');
		Assert.areEqual(testId1, provider.getValue(1), 'Value at index 1 should be testId1.');
		Assert.areEqual(testId0, provider.getValue(2), 'Value at index 2 should be testId0.');
	}

	/**
	 * @description Tests the 'getDefinedSObjectOptionalFields' method, ensuring it returns a non-null set (even if empty) by default.
	 */
	@IsTest
	private static void providerGetDefinedSObjectOptionalFields()
	{
		UTIL_SObjectBuilderDefaultProvider defaultValueProvider = new UTIL_SObjectBuilderDefaultProvider();
		Set<String> definedOptionalFields = defaultValueProvider.getDefinedSObjectOptionalFields(Foobar__c.SObjectType);
		Assert.isNotNull(definedOptionalFields, 'The set of optional fields should not be null.');
	}

	/**
	 * @description Tests that global optional fields can include SObjectField tokens.
	 * This covers the SObjectField branch in getGlobalOptionalFieldsAsSet.
	 */
	@IsTest
	private static void providerGlobalOptionalFieldsWithSObjectFieldToken()
	{
		// Given: Add an SObjectField token to the global optional fields
		TST_Builder.optionalFields.add(Foobar__c.Text__c);

		try
		{
			// When: Build a Foobar using the builder (triggers getGlobalOptionalFieldsAsSet)
			Foobar__c foobar = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();

			// Then: The build should succeed and the field should be treated as optional
			Assert.isNotNull(foobar, 'Foobar should be created successfully.');
		}
		finally
		{
			// Cleanup: Remove the added field to avoid affecting other tests
			TST_Builder.optionalFields.remove(TST_Builder.optionalFields.size() - 1);
		}
	}

	/**
	 * @description Tests that UTIL_SObjectDescribe returns relationship fields correctly.
	 */
	@IsTest
	private static void providerGetRelationshipFieldsCacheMiss()
	{
		Map<String, String> relationshipFields = UTIL_SObjectDescribe.getDescribe(Lead.SObjectType).getRelationshipFieldMap();

		Assert.isNotNull(relationshipFields, 'Relationship fields map should not be null.');
		Assert.isTrue(relationshipFields.containsKey('ownerid'), 'Lead should have OwnerId as a relationship field.');
	}

	/**
	 * @description Tests the 'getRelationshipKeySet' helper method, ensuring it correctly extracts the next-level relationship names
	 * from a set of fully-qualified field names based on a prefix.
	 */
	@IsTest
	private static void providerGetRelationshipKeySet()
	{
		Assert.areEqual
				(
						new Set<String> {SEL_Foobar.OBJECT_NAME.toLowerCase()},
						UTIL_SObjectBuilderDefaultProvider.getRelationshipKeySet
								(
										new Set<String> {SEL_Foobar.OBJECT_NAME + '.OwnerId', SEL_Foobar.OBJECT_NAME + '.Owner.Profile.Id'},
										UTIL_String.EMPTY
								),
						'Should extract the top-level relationship name.'
				);
		Assert.areEqual
				(
						new Set<String> {'owner'},
						UTIL_SObjectBuilderDefaultProvider.getRelationshipKeySet(
								new Set<String> {SEL_Foobar.OBJECT_NAME + '.Owner.Id', SEL_Foobar.OBJECT_NAME + '.Owner.Profile.Id', SEL_Foobar.OBJECT_NAME + '.OwnerId'},
								SEL_Foobar.OBJECT_NAME + '.'
						),
						'Should extract the next-level relationship name based on the prefix.'
				);
		Assert.areEqual
				(
						new Set<String> {'parent', 'user'},
						UTIL_SObjectBuilderDefaultProvider.getRelationshipKeySet
								(
										new Set<String> {'Contact.Account.User.Id', 'Contact.Account.Parent.Id', 'Contact.Account.Description'},
										'Contact.Account.'
								),
						'Should extract multiple relationship names at the same level.'
				);
	}

	/**
	 * @description Tests the 'convertMapValueTypes' helper method, verifying it correctly converts a nested Map<String, Object>
	 * into a flat Map<String, DefaultFieldValueProvider>.
	 */
	@IsTest
	private static void providerConvertMapValueTypes()
	{
		UTIL_SObjectBuilderDefaultProvider defaultValueProvider = new UTIL_SObjectBuilderDefaultProvider();
		// Create a variable for the user to ensure we are checking the same instance
		User testUser = new User(Id = UserInfo.getUserId());
		Map<String, Object> testValueMap = new Map<String, Object>
		{
				'Test0' => 0,
				'  tEst1  ' => 1,
				'TesT2' => new UTIL_SObjectBuilderDefaultProvider.FieldDefaultValue(2),
				'test3' => new List<String> {'value1', 'value2'},
				'test4' => new Map<String, Object>
				{
						'Test1' => 'value1',
						'tesT2 ' => new Map<String, Object>
						{
								'test1' => 'value2'
						}
				},
				'test5' => testUser, // Use variable
				'test6' => new List<SObject> {new User(Id = null), new User(Id = UserInfo.getUserId())},
				'test7__r' => testUser, // Use variable
				null => testUser
		};

		Map<String, TST_Builder.DefaultFieldValueProvider> convertedValueMap =
				defaultValueProvider.convertMapValueTypes(User.SObjectType, UTIL_String.EMPTY, testValueMap);

		Assert.isTrue(convertedValueMap.keySet().contains('test0'), 'Key should be lowercased.');
		Assert.isTrue(convertedValueMap.keySet().contains('test1'), 'Key should be lowercased and trimmed.');
		Assert.isTrue(convertedValueMap.keySet().contains('test2'), 'Key should be lowercased.');
		assertValue(convertedValueMap, 'test0', 0, 'Should convert primitive value.');
		assertValue(convertedValueMap, 'test1', 1, 'Should convert primitive value.');
		assertValue(convertedValueMap, 'test2', 2, 'Should preserve existing provider.');
		assertValue(convertedValueMap, 'test3', 0, 'value1', 'Should convert List<Object> to ListFieldDefaultValue.');
		assertValue(convertedValueMap, 'test3', 1, 'value2', 'Should retrieve second value from ListFieldDefaultValue.');
		assertValue(convertedValueMap, 'test4.test1', 'value1', 'Should flatten nested map.');
		assertValue(convertedValueMap, 'test4.test2.test1', 'value2', 'Should flatten deeply nested map.');

		Object test5Value = getValue(convertedValueMap, 'test5');
		Assert.isNotNull(test5Value, 'Value for "test5" should not be null.');
		Assert.isInstanceOfType(test5Value, SObject.class, 'Value for key "test5" should be an SObject.');
		Assert.areEqual(UserInfo.getUserId(), ((SObject)test5Value).Id, 'The Id of the SObject at key "test5" should be the UserInfo.getUserId().');

		// Assertions updated to reflect new logic for child relationships
		Assert.isNull(getValue(convertedValueMap, 'test5Id'), 'The key "test5Id" should not be created for a single SObject.');

		Assert.isNull(getValue(convertedValueMap, 'test6Id'), 'The key "test6Id" should NOT be created for a List<SObject>.');
		Object test6Value = getValue(convertedValueMap, 'test6');
		Assert.isNotNull(test6Value, 'Value for "test6" (List<SObject>) should not be null.');
		Assert.isInstanceOfType(test6Value, List<SObject>.class, 'Value for "test6" should be a List.');

		List<Object> test6List = (List<Object>)test6Value;
		Assert.areEqual(2, test6List.size(), 'List for "test6" should have 2 elements.');
		Assert.isInstanceOfType(test6List.get(1), User.class, 'Element in "test6" list should be a User.');
		Assert.areEqual(UserInfo.getUserId(), ((User)test6List.get(1)).Id, 'The Id of the SObject in the "test6" list should be correct.');

		Object test7Value = getValue(convertedValueMap, 'test7__r');
		Assert.isNotNull(test7Value, 'Value for "test7__r" should not be null.');
		Assert.isInstanceOfType(test7Value, SObject.class, 'Value for key "test7__r" should be an SObject.');
		Assert.areEqual(UserInfo.getUserId(), ((SObject)test7Value).Id, 'The Id of the SObject at key "test7__r" should be the UserInfo.getUserId().');
		Assert.isNull(getValue(convertedValueMap, 'test7__c'), 'The key "test7__c" should no longer be created for a single SObject.');
	}

	/**
	 * @description Tests that the provider dynamically distinguishes between
	 * an Indexed Lookup (where a List implies "assign these to records 1, 2, 3...")
	 * and a Mocked Child List (where a List implies "this is a related list for record 1").
	 * This verifies the schema-based logic in processMapEntry.
	 */
	@IsTest
	private static void dynamicLookupVsChildListDetection()
	{
		UTIL_SObjectBuilderDefaultProvider defaultValueProvider = new UTIL_SObjectBuilderDefaultProvider();

		// 1. Setup Data — parent records for the Lookup__c reference field
		List<Foobar__c> parentList = new List<Foobar__c>
		{
				new Foobar__c(Name = 'Parent1'),
				new Foobar__c(Name = 'Parent2')
		};

		// Child records for the Foobars__r child relationship
		List<Foobar__c> childList = new List<Foobar__c>
		{
				new Foobar__c(Name = 'Child1'),
				new Foobar__c(Name = 'Child2')
		};

		Map<String, Object> lookupOverrides = new Map<String, Object>
		{
				// Lookup__r is a Reference Field on Foobar__c.
				// The list should be treated as INDEXED (ListFieldDefaultValue)
				SEL_Foobar.RELATIONSHIP_LOOKUP => parentList
		};

		Map<String, Object> childRelOverrides = new Map<String, Object>
		{
				// Foobars__r is a Child Relationship on Foobar__c (Not a Reference Field).
				// The list should be treated as a SINGLE VALUE (FieldDefaultValue) for mocking.
				SEL_Foobar.RELATIONSHIP_FOOBARS => childList
		};

		// 2. Process lookup scenario (Lookup__r is a reference field)
		Map<String, TST_Builder.DefaultFieldValueProvider> lookupResult =
				defaultValueProvider.convertMapValueTypes(Foobar__c.SObjectType, UTIL_String.EMPTY, lookupOverrides);

		// 3. Process child relationship scenario (Foobars__r is a child relationship)
		Map<String, TST_Builder.DefaultFieldValueProvider> childRelResult =
				defaultValueProvider.convertMapValueTypes(Foobar__c.SObjectType, UTIL_String.EMPTY, childRelOverrides);

		// 4. Assertions for Indexed Lookup
		TST_Builder.DefaultFieldValueProvider lookupProvider = lookupResult.get(SEL_Foobar.RELATIONSHIP_LOOKUP?.toLowerCase());
		Assert.isNotNull(lookupProvider, 'Provider for Lookup reference should exist.');
		Assert.isInstanceOfType(lookupProvider, UTIL_SObjectBuilderDefaultProvider.ListFieldDefaultValue.class,
				'Lookup reference list should be treated as ListFieldDefaultValue (Indexed).');
		Assert.areEqual(parentList[0], lookupProvider.getValue(0), 'Index 0 should return Parent 0.');
		Assert.areEqual(parentList[1], lookupProvider.getValue(1), 'Index 1 should return Parent 1.');

		// 5. Assertions for Mocked Child List
		TST_Builder.DefaultFieldValueProvider childProvider = childRelResult.get(SEL_Foobar.RELATIONSHIP_FOOBARS?.toLowerCase());
		Assert.isNotNull(childProvider, 'Provider for child relationship should exist.');
		Assert.isInstanceOfType(childProvider, UTIL_SObjectBuilderDefaultProvider.FieldDefaultValue.class,
				'Child relationship list should be treated as FieldDefaultValue (Single Value).');

		Object val = childProvider.getValue(0);
		Assert.isInstanceOfType(val, List<Foobar__c>.class, 'Value should be the full list of children.');
		List<Foobar__c> resultList = (List<Foobar__c>)val;
		Assert.areEqual(2, resultList.size(), 'The mocked list should contain both children.');
	}

	/**
	 * @description Tests the 'isDefaultValueRequired' helper method, verifying it correctly returns true
	 * for required/non-nillable fields (Contact.LastName) and false for nillable fields (Foobar__c.Name).
	 */
	@IsTest
	private static void providerIsDefaultValueRequired()
	{
		Assert.isTrue
				(
						UTIL_SObjectBuilderDefaultProvider.isDefaultValueRequired(Contact.LastName.getDescribe()),
						'Contact.LastName should be identified as required (nillable=false).'
				);
		Assert.isFalse
				(
						UTIL_SObjectBuilderDefaultProvider.isDefaultValueRequired(Foobar__c.Name.getDescribe()),
						'Foobar__c.Name should be identified as NOT required by default (nillable=true).'
				);
		Assert.isFalse
				(
						UTIL_SObjectBuilderDefaultProvider.isDefaultValueRequired(Foobar__c.OwnerId.getDescribe()),
						'Foobar__c.OwnerId should be identified as not required (defaulted on create).'
				);
	}

	/**
	 * @description Tests the 'getFieldNameFromRelationshipName' utility method, verifying it correctly converts custom ('__r' to '__c') and standard (to 'Id') relationship names.
	 */
	@IsTest
	private static void utilGetFieldNameFromRelationshipName()
	{
		Assert.areEqual
				(
						'customrelationshiP__c',
						UTIL_SObjectBuilderDefaultProvider.getFieldNameFromRelationshipName('customrelationshiP__r'),
						'Should convert custom relationship __r to __c.'
				);
		Assert.areEqual
				(
						'standardRelationshiPId',
						UTIL_SObjectBuilderDefaultProvider.getFieldNameFromRelationshipName('standardRelationshiP'),
						'Should convert standard relationship name to Id field name.'
				);
	}

	/**
	 * @description Will switch on person account mocking if the feature isn't enabled
	 *
	 * @return The real or mocked person account recordtype id
	 */
	private static Id mockPersonAccountsIfNotEnabled()
	{
		Boolean isPersonAccountEnabled = UTIL_SObjectDescribe.isPersonAccountEnabled();
		Id personAccountRecordTypeId = isPersonAccountEnabled ? SEL_RecordType.personAccountRecordTypes.iterator().next() : UTIL_Random.randomId(Foobar__c.SObjectType);

		UTIL_SObjectBuilderDefaultProvider.mockPersonAccountsAreEnabled = !isPersonAccountEnabled;
		UTIL_SObjectBuilderDefaultProvider.mockPersonAccountRecordTypeIds = new Set<Id> {personAccountRecordTypeId};

		return personAccountRecordTypeId;
	}

	/**
	 * @description Checks that the error is a TypeException
	 *
	 * @param error The error object to check
	 * @param assertMessage The message to display if exception is of a different type
	 *
	 * @see TypeException
	 */
	private static void assertIsTypeException(Exception error, String assertMessage)
	{
		Assert.isInstanceOfType(error, TypeException.class, assertMessage);
	}

	/**
	 * @description Helper to generate a default map of values using the default provider.
	 *
	 * @param sObjectType The SObjectType to build.
	 *
	 * @return The generated map of providers.
	 */
	private static Map<String, TST_Builder.DefaultFieldValueProvider> generateMap(SObjectType sObjectType)
	{
		return new UTIL_SObjectBuilderDefaultProvider().getDefaultMapOfValues(sObjectType, new Map<String, Object>());
	}

	/**
	 * @description Helper to generate a default map of values using the default provider with overrides.
	 *
	 * @param sObjectType The SObjectType to build.
	 * @param overrides The map of override values.
	 *
	 * @return The generated map of providers.
	 */
	private static Map<String, TST_Builder.DefaultFieldValueProvider> generateMap(SObjectType sObjectType, Map<String, Object> overrides)
	{
		return new UTIL_SObjectBuilderDefaultProvider().getDefaultMapOfValues(sObjectType, overrides);
	}

	/**
	 * @description Helper to safely get a value from the provider map.
	 *
	 * @param mapOfValues The map of providers.
	 * @param fieldName The dot-notation field name.
	 * @param index The record index.
	 *
	 * @return The generated value, or null if the provider does not exist.
	 */
	private static Object getValue(Map<String, TST_Builder.DefaultFieldValueProvider> mapOfValues, String fieldName, Integer index)
	{
		TST_Builder.DefaultFieldValueProvider provider = mapOfValues.get(fieldName.toLowerCase());
		if(provider == null)
		{
			return null;
		}
		return provider.getValue(index);
	}

	/**
	 * @description Helper to safely get a value from the provider map for index 0.
	 *
	 * @param mapOfValues The map of providers.
	 * @param fieldName The dot-notation field name.
	 *
	 * @return The generated value for index 0, or null.
	 */
	private static Object getValue(Map<String, TST_Builder.DefaultFieldValueProvider> mapOfValues, String fieldName)
	{
		return getValue(mapOfValues, fieldName, 0);
	}

	/**
	 * @description Asserts that a field is populated (not null) and returns its value.
	 *
	 * @param mapOfValues The map of providers.
	 * @param fieldName The field to check.
	 * @param message The assertion message.
	 *
	 * @return The value of the field.
	 */
	private static Object assertPopulated(Map<String, TST_Builder.DefaultFieldValueProvider> mapOfValues, String fieldName, String message)
	{
		Object value = getValue(mapOfValues, fieldName);
		Assert.isNotNull(value, message);
		return value;
	}

	/**
	 * @description Asserts that a field is populated, matches the expected type, and returns its value.
	 *
	 * @param mapOfValues The map of providers.
	 * @param fieldName The field to check.
	 * @param expectedType The System.Type the value should be.
	 * @param message The assertion message.
	 *
	 * @return The value of the field.
	 */
	private static Object assertPopulated(Map<String, TST_Builder.DefaultFieldValueProvider> mapOfValues, String fieldName, System.Type expectedType, String message)
	{
		Object value = assertPopulated(mapOfValues, fieldName, message);
		Assert.isInstanceOfType(value, expectedType, 'Field ' + fieldName + ' should be of type ' + expectedType.getName());
		return value;
	}

	/**
	 * @description Asserts that a field at a specific index has an expected value.
	 *
	 * @param mapOfValues The map of providers.
	 * @param fieldName The field to check.
	 * @param index The record index.
	 * @param expectedValue The expected value.
	 * @param message The assertion message.
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private static void assertValue
			(
					Map<String, TST_Builder.DefaultFieldValueProvider> mapOfValues,
					String fieldName,
					Integer index,
					Object expectedValue,
					String message
			)
	{
		Assert.areEqual(expectedValue, getValue(mapOfValues, fieldName, index), message);
	}

	/**
	 * @description Asserts that a field at index 0 has an expected value.
	 *
	 * @param mapOfValues The map of providers.
	 * @param fieldName The field to check.
	 * @param expectedValue The expected value.
	 * @param message The assertion message.
	 */
	private static void assertValue(Map<String, TST_Builder.DefaultFieldValueProvider> mapOfValues, String fieldName, Object expectedValue, String message)
	{
		assertValue(mapOfValues, fieldName, 0, expectedValue, message);
	}

	/**
	 * @description Asserts that a field is null or its provider is missing.
	 *
	 * @param mapOfValues The map of providers.
	 * @param fieldName The field to check.
	 * @param message The assertion message.
	 */
	private static void assertMissing(Map<String, TST_Builder.DefaultFieldValueProvider> mapOfValues, String fieldName, String message)
	{
		Assert.isNull(getValue(mapOfValues, fieldName), message);
	}

	/**
	 * @description Given: A polymorphic lookup field (OwnerId which can reference User or Queue)
	 * When: 'withDefaultedField' is called with that field
	 * Then: The field is gracefully skipped (no error thrown) and an info log is published
	 */
	@IsTest
	private static void givenPolymorphicFieldWhenDefaultedThenSkippedAndLogged()
	{
		LOG_Builder.ignoreTestMode = true;

		Test.startTest();

		// When: Build a Case with a polymorphic field (OwnerId references User or Queue)
		Case result = (Case)TST_Builder.of(Case.SObjectType)
				.withDefaultedField(Case.OwnerId)
				.withDefaultedField(Case.Subject)
				.withoutInsertion(true)
				.build();

		Test.stopTest();

		// Then: The Case was built successfully (no exception)
		Assert.isNotNull(result, 'Case should be built successfully despite polymorphic field.');
		Assert.isNotNull(result.Subject, 'Subject should be defaulted.');

		// Then: The Owner relationship is NOT populated (polymorphic field was skipped)
		Assert.isNull(result.Owner, 'Owner relationship should be null because polymorphic fields are skipped.');

		// Note: An info log event is published when polymorphic fields are skipped.
		Assert.isFalse(new SEL_LogEntry().findByLogLevel(LoggingLevel.INFO.name()).isEmpty(), 'No Log Written as expected');
	}

	/**
	 * @description Verifies that putRelationshipField correctly identifies and skips polymorphic fields
	 * by checking the referenceToObjectNames size. This directly tests the polymorphic detection logic.
	 */
	@IsTest
	private static void putRelationshipFieldSkipsPolymorphicFields()
	{
		LOG_Builder.ignoreTestMode = true;
		UTIL_SObjectBuilderDefaultProvider provider = new UTIL_SObjectBuilderDefaultProvider();
		Map<String, TST_Builder.DefaultFieldValueProvider> mapOfValues = new Map<String, TST_Builder.DefaultFieldValueProvider>();

		// Get lightweight field metadata for OwnerId (polymorphic: User or Queue)
		UTIL_SObjectDescribe.FieldMetadata ownerIdMetadata = UTIL_SObjectDescribe.getDescribe(Case.SObjectType).getFieldMetadata('ownerid');

		// Verify OwnerId is indeed polymorphic (references multiple types)
		Assert.isTrue(ownerIdMetadata.referenceToObjectNames.size() > 1, 'OwnerId should reference multiple types (User and Queue).');

		Test.startTest();

		// When: putRelationshipField is called with a polymorphic field
		provider.putRelationshipField(mapOfValues, ownerIdMetadata, UTIL_String.EMPTY);

		Test.stopTest();

		// Then: The map should NOT contain the owner relationship (it was skipped)
		String expectedKey = ownerIdMetadata.relationshipName + '.id';
		Assert.isFalse(mapOfValues.containsKey(expectedKey), 'Polymorphic field should be skipped and not added to map. Key checked: ' + expectedKey);

		// Note: An info log event is published when polymorphic fields are skipped.
		Assert.isFalse(new SEL_LogEntry().findByLogLevel(LoggingLevel.INFO.name()).isEmpty(), 'No Log Written as expected');
	}

	/**
	 * @description Tests convertPrefixToFieldNameBased returns blank input unchanged.
	 */
	@IsTest
	private static void convertPrefixToFieldNameBasedReturnsBlankUnchanged()
	{
		// Given: A blank prefix
		String blankPrefix = '';
		String nullPrefix = null;

		// When: Converting the blank/null prefix
		String resultBlank = UTIL_SObjectBuilderDefaultProvider.convertPrefixToFieldNameBased(blankPrefix);
		String resultNull = UTIL_SObjectBuilderDefaultProvider.convertPrefixToFieldNameBased(nullPrefix);

		// Then: The blank/null value should be returned unchanged
		Assert.areEqual(blankPrefix, resultBlank, 'Blank prefix should be returned unchanged');
		Assert.areEqual(nullPrefix, resultNull, 'Null prefix should be returned unchanged');
	}

	/**
	 * @description Tests convertPrefixToFieldNameBased keeps existing field names unchanged.
	 */
	@IsTest
	private static void convertPrefixToFieldNameBasedKeepsFieldNamesUnchanged()
	{
		// Given: A prefix that already uses field names (ending with 'Id' or '__c')
		String fieldNamePrefixStandard = 'AccountId.';
		String fieldNamePrefixCustom = 'Lookup__c.';
		String mixedPrefix = 'AccountId.Parent.';

		// When: Converting prefixes that already contain field names
		String resultStandard = UTIL_SObjectBuilderDefaultProvider.convertPrefixToFieldNameBased(fieldNamePrefixStandard);
		String resultCustom = UTIL_SObjectBuilderDefaultProvider.convertPrefixToFieldNameBased(fieldNamePrefixCustom);
		String resultMixed = UTIL_SObjectBuilderDefaultProvider.convertPrefixToFieldNameBased(mixedPrefix);

		// Then: Field names should be preserved, relationship names should be converted
		Assert.areEqual('accountid.', resultStandard, 'Standard field name should be preserved (lowercase)');
		Assert.areEqual('lookup__c.', resultCustom, 'Custom field name should be preserved (lowercase)');
		Assert.areEqual('accountid.parentid.', resultMixed, 'Mixed prefix: field name preserved, relationship converted');
	}

	/**
	 * @description Tests convertPrefixToFieldNameBased handles paths without trailing dots.
	 * This covers the remaining segment logic after the while loop.
	 */
	@IsTest
	private static void convertPrefixToFieldNameBasedHandlesNoTrailingDot()
	{
		// Given: Paths without trailing dots
		String relationshipPath = 'Account.Parent'; // Final segment is relationship name
		String fieldNamePath = 'Account.ParentId'; // Final segment already ends with Id
		String customFieldPath = SEL_Foobar.RELATIONSHIP_LOOKUP + UTIL_String.DOT + SEL_Foobar.FIELD_LOOKUP; // Custom field

		// When: Converting paths without trailing dots
		String resultRelationship = UTIL_SObjectBuilderDefaultProvider.convertPrefixToFieldNameBased(relationshipPath);
		String resultFieldName = UTIL_SObjectBuilderDefaultProvider.convertPrefixToFieldNameBased(fieldNamePath);
		String resultCustomField = UTIL_SObjectBuilderDefaultProvider.convertPrefixToFieldNameBased(customFieldPath);

		// Then: All segments should be converted appropriately
		Assert.areEqual('accountid.parentid', resultRelationship, 'Relationship path should convert final segment');
		Assert.areEqual('accountid.parentid', resultFieldName, 'Field name path should preserve final segment');
		Assert.areEqual((SEL_Foobar.FIELD_LOOKUP + UTIL_String.DOT + SEL_Foobar.FIELD_LOOKUP).toLowerCase(),
				resultCustomField, 'Custom field path should convert relationship to field name');
	}

	/**
	 * @description Tests convertPrefixToFieldNameBased handles single segment without dot.
	 * This covers the remaining segment logic when there's no dot at all.
	 */
	@IsTest
	private static void convertPrefixToFieldNameBasedHandlesSingleSegment()
	{
		// Given: Single segment paths (no dots)
		String relationshipName = 'Account';
		String fieldName = 'AccountId';
		String customRelationship = SEL_Foobar.RELATIONSHIP_LOOKUP;

		// When: Converting single segment paths
		String resultRelationship = UTIL_SObjectBuilderDefaultProvider.convertPrefixToFieldNameBased(relationshipName);
		String resultFieldName = UTIL_SObjectBuilderDefaultProvider.convertPrefixToFieldNameBased(fieldName);
		String resultCustom = UTIL_SObjectBuilderDefaultProvider.convertPrefixToFieldNameBased(customRelationship);

		// Then: Single segments should be converted appropriately
		Assert.areEqual('accountid', resultRelationship, 'Relationship name should be converted to field name');
		Assert.areEqual('accountid', resultFieldName, 'Field name should be preserved');
		Assert.areEqual(SEL_Foobar.FIELD_LOOKUP.toLowerCase(), resultCustom, 'Custom relationship should be converted to field name');
	}

	/**
	 * @description Tests getRelationshipNameFromFieldName converts standard field names.
	 */
	@IsTest
	private static void getRelationshipNameFromFieldNameConvertsStandardFields()
	{
		// Given: Standard field names ending with 'Id'
		String accountId = 'AccountId';
		String parentId = 'ParentId';
		String ownerId = 'OwnerId';

		// When: Converting to relationship names
		String accountResult = UTIL_SObjectBuilderDefaultProvider.getRelationshipNameFromFieldName(accountId);
		String parentResult = UTIL_SObjectBuilderDefaultProvider.getRelationshipNameFromFieldName(parentId);
		String ownerResult = UTIL_SObjectBuilderDefaultProvider.getRelationshipNameFromFieldName(ownerId);

		// Then: 'Id' suffix should be removed
		Assert.areEqual('Account', accountResult, 'AccountId should become Account');
		Assert.areEqual('Parent', parentResult, 'ParentId should become Parent');
		Assert.areEqual('Owner', ownerResult, 'OwnerId should become Owner');
	}

	/**
	 * @description Tests getRelationshipNameFromFieldName converts custom field names.
	 */
	@IsTest
	private static void getRelationshipNameFromFieldNameConvertsCustomFields()
	{
		// Given: Custom field names ending with '__c'
		String customField = 'Custom_Lookup__c';

		// When: Converting to relationship name
		String result = UTIL_SObjectBuilderDefaultProvider.getRelationshipNameFromFieldName(customField);

		// Then: '__c' suffix should be replaced with '__r'
		Assert.areEqual('Custom_Lookup__r', result, 'Custom__c should become Custom__r');
	}

	/**
	 * @description Tests getRelationshipNameFromFieldName preserves non-field names.
	 */
	@IsTest
	private static void getRelationshipNameFromFieldNamePreservesNonFieldNames()
	{
		// Given: Names that are already relationship names or regular field names
		String relationshipName = 'Account';
		String customRelationship = 'Custom__r';
		String regularField = 'Name';
		String blankValue = '';

		// When: Converting
		String relResult = UTIL_SObjectBuilderDefaultProvider.getRelationshipNameFromFieldName(relationshipName);
		String customResult = UTIL_SObjectBuilderDefaultProvider.getRelationshipNameFromFieldName(customRelationship);
		String fieldResult = UTIL_SObjectBuilderDefaultProvider.getRelationshipNameFromFieldName(regularField);
		String blankResult = UTIL_SObjectBuilderDefaultProvider.getRelationshipNameFromFieldName(blankValue);

		// Then: Should be returned unchanged
		Assert.areEqual('Account', relResult, 'Relationship name should be preserved');
		Assert.areEqual('Custom__r', customResult, 'Custom relationship should be preserved');
		Assert.areEqual('Name', fieldResult, 'Regular field name should be preserved');
		Assert.areEqual('', blankResult, 'Blank should be preserved');
	}

	/**
	 * @description Tests normalizePathToRelationshipNames converts field-name-based paths.
	 */
	@IsTest
	private static void normalizePathToRelationshipNamesConvertsFieldNamePaths()
	{
		// Given: Paths using field names instead of relationship names
		String singleLevel = 'AccountId.Name';
		String multiLevel = 'AccountId.ParentId.Name';
		String mixedPath = 'Account.ParentId.Name';

		// When: Normalizing to relationship names
		String singleResult = UTIL_SObjectBuilderDefaultProvider.normalizePathToRelationshipNames(singleLevel);
		String multiResult = UTIL_SObjectBuilderDefaultProvider.normalizePathToRelationshipNames(multiLevel);
		String mixedResult = UTIL_SObjectBuilderDefaultProvider.normalizePathToRelationshipNames(mixedPath);

		// Then: All paths should be normalized to relationship name format
		Assert.areEqual('account.name', singleResult, 'Single level should normalize to relationship name');
		Assert.areEqual('account.parent.name', multiResult, 'Multi-level should normalize all segments');
		Assert.areEqual('account.parent.name', mixedResult, 'Mixed path should normalize field name segments');
	}

	/**
	 * @description Tests normalizePathToRelationshipNames handles edge cases.
	 */
	@IsTest
	private static void normalizePathToRelationshipNamesHandlesEdgeCases()
	{
		// Given: Edge cases
		String singleField = 'Name';
		String blankPath = '';
		String customPath = 'Lookup__c.OtherLookup__c.Name';

		// When: Normalizing
		String singleResult = UTIL_SObjectBuilderDefaultProvider.normalizePathToRelationshipNames(singleField);
		String blankResult = UTIL_SObjectBuilderDefaultProvider.normalizePathToRelationshipNames(blankPath);
		String customResult = UTIL_SObjectBuilderDefaultProvider.normalizePathToRelationshipNames(customPath);

		// Then: Handle appropriately
		Assert.areEqual('name', singleResult, 'Single field should just be lowercased');
		Assert.areEqual('', blankResult, 'Blank should remain blank');
		Assert.areEqual('lookup__r.otherlookup__r.name', customResult, 'Custom fields should convert to __r');
	}

	/**
	 * @description Tests the public 'normalizeToRelationshipPath' method directly.
	 * Verifies that it converts field paths (AccountId.ParentId) to relationship paths (account.parent).
	 */
	@IsTest
	private static void normalizeToRelationshipPathConvertsCorrectly()
	{
		// Test Null/Blank
		Assert.isNull(UTIL_SObjectBuilderDefaultProvider.normalizeToRelationshipPath(null), 'Should return null for null input');
		Assert.areEqual('', UTIL_SObjectBuilderDefaultProvider.normalizeToRelationshipPath(''), 'Should return empty string for empty input');

		// Test Single Segment (Field Name -> Relationship)
		Assert.areEqual('account', UTIL_SObjectBuilderDefaultProvider.normalizeToRelationshipPath('AccountId'), 'Should convert AccountId -> account');
		Assert.areEqual('account', UTIL_SObjectBuilderDefaultProvider.normalizeToRelationshipPath('Account'), 'Should preserve Account -> account');

		// Test Custom Field (Field Name -> Relationship)
		Assert.areEqual('lookup__r', UTIL_SObjectBuilderDefaultProvider.normalizeToRelationshipPath('Lookup__c'), 'Should convert Lookup__c -> lookup__r');

		// Test Multi-Segment
		Assert.areEqual('account.parent', UTIL_SObjectBuilderDefaultProvider.normalizeToRelationshipPath('Account.ParentId'), 'Should convert path segments');
		Assert.areEqual('account.createdby', UTIL_SObjectBuilderDefaultProvider.normalizeToRelationshipPath('AccountId.CreatedById'), 'Should convert all segments');
	}

	/**
	 * @description Integration test: withOverride with mixed path format should work.
	 */
	@IsTest
	private static void withOverrideWithMixedPathFormatSetsValue()
	{
		// Given: A builder with defaulted field using field-name path and override using mixed path
		// 'AccountId.Name' creates an Account, 'Account.ParentId.Name' overrides the Parent's Name

		// When: Building the object
		Case testCase = (Case)TST_Builder.of(Case.SObjectType)
				.withDefaultedField('AccountId.Name')
				.withOverride('Account.ParentId.Name', 'Mixed Path Override')
				.withoutInsertion(true)
				.withOptionalField(Case.BusinessHoursId)
				.build();

		// Then: The Parent Account's Name should be set to the override value
		Assert.isNotNull(testCase.Account, 'Account should exist');
		Assert.isNotNull(testCase.Account.Parent, 'Parent should exist');
		Assert.areEqual('Mixed Path Override', testCase.Account.Parent.Name, 'Parent Name should be set via mixed path override');
	}

	/**
	 * @description Tests getDefaultValue directly returns Boolean for BOOLEAN field type.
	 */
	@IsTest
	private static void getDefaultValueReturnsBooleanForCheckbox()
	{
		UTIL_SObjectBuilderDefaultProvider provider = new UTIL_SObjectBuilderDefaultProvider();
		DescribeFieldResult fieldDescribe = Foobar__c.Checkbox__c.getDescribe();

		Object result = provider.getDefaultValue(fieldDescribe, 0);

		Assert.isNotNull(result, 'getDefaultValue should return non-null for BOOLEAN');
		Assert.isInstanceOfType(result, Boolean.class, 'getDefaultValue should return Boolean for BOOLEAN field');
	}

	/**
	 * @description Tests getDefaultValue directly returns Decimal for CURRENCY field type.
	 */
	@IsTest
	private static void getDefaultValueReturnsDecimalForCurrency()
	{
		UTIL_SObjectBuilderDefaultProvider provider = new UTIL_SObjectBuilderDefaultProvider();
		DescribeFieldResult fieldDescribe = Foobar__c.Currency__c.getDescribe();

		Object result = provider.getDefaultValue(fieldDescribe, 0);

		Assert.isNotNull(result, 'getDefaultValue should return non-null for CURRENCY');
		Assert.isInstanceOfType(result, Decimal.class, 'getDefaultValue should return Decimal for CURRENCY field');
	}

	/**
	 * @description Tests getDefaultValue directly returns Date for DATE field type.
	 */
	@IsTest
	private static void getDefaultValueReturnsDateForDate()
	{
		UTIL_SObjectBuilderDefaultProvider provider = new UTIL_SObjectBuilderDefaultProvider();
		DescribeFieldResult fieldDescribe = Foobar__c.Date__c.getDescribe();

		Object result = provider.getDefaultValue(fieldDescribe, 0);

		Assert.isNotNull(result, 'getDefaultValue should return non-null for DATE');
		Assert.isInstanceOfType(result, Date.class, 'getDefaultValue should return Date for DATE field');
	}

	/**
	 * @description Tests getDefaultValue directly returns Datetime for DATETIME field type.
	 */
	@IsTest
	private static void getDefaultValueReturnsDatetimeForDatetime()
	{
		UTIL_SObjectBuilderDefaultProvider provider = new UTIL_SObjectBuilderDefaultProvider();
		DescribeFieldResult fieldDescribe = Foobar__c.Datetime__c.getDescribe();

		Object result = provider.getDefaultValue(fieldDescribe, 0);

		Assert.isNotNull(result, 'getDefaultValue should return non-null for DATETIME');
		Assert.isInstanceOfType(result, Datetime.class, 'getDefaultValue should return Datetime for DATETIME field');
	}

	/**
	 * @description Tests getDefaultValue directly returns String for EMAIL field type.
	 */
	@IsTest
	private static void getDefaultValueReturnsStringForEmail()
	{
		UTIL_SObjectBuilderDefaultProvider provider = new UTIL_SObjectBuilderDefaultProvider();
		DescribeFieldResult fieldDescribe = Foobar__c.Email__c.getDescribe();

		Object result = provider.getDefaultValue(fieldDescribe, 0);

		Assert.isNotNull(result, 'getDefaultValue should return non-null for EMAIL');
		Assert.isInstanceOfType(result, String.class, 'getDefaultValue should return String for EMAIL field');
	}

	/**
	 * @description Tests getDefaultValue directly returns Location for LOCATION field type.
	 */
	@IsTest
	private static void getDefaultValueReturnsLocationForGeolocation()
	{
		UTIL_SObjectBuilderDefaultProvider provider = new UTIL_SObjectBuilderDefaultProvider();
		DescribeFieldResult fieldDescribe = Foobar__c.Geolocation__c.getDescribe();

		Object result = provider.getDefaultValue(fieldDescribe, 0);

		Assert.isNotNull(result, 'getDefaultValue should return non-null for LOCATION');
		Assert.isInstanceOfType(result, Location.class, 'getDefaultValue should return Location for LOCATION field');
	}

	/**
	 * @description Tests getDefaultValue directly returns Decimal for INTEGER field type.
	 */
	@IsTest
	private static void getDefaultValueReturnsDecimalForInteger()
	{
		UTIL_SObjectBuilderDefaultProvider provider = new UTIL_SObjectBuilderDefaultProvider();
		DescribeFieldResult fieldDescribe = Foobar__c.NumberInteger__c.getDescribe();

		Object result = provider.getDefaultValue(fieldDescribe, 0);

		Assert.isNotNull(result, 'getDefaultValue should return non-null for INTEGER');
		Assert.isInstanceOfType(result, Decimal.class, 'getDefaultValue should return Decimal for INTEGER field');
	}

	/**
	 * @description Tests getDefaultValue directly returns Decimal for DOUBLE field type.
	 */
	@IsTest
	private static void getDefaultValueReturnsDecimalForDouble()
	{
		UTIL_SObjectBuilderDefaultProvider provider = new UTIL_SObjectBuilderDefaultProvider();
		DescribeFieldResult fieldDescribe = Foobar__c.NumberDecimal__c.getDescribe();

		Object result = provider.getDefaultValue(fieldDescribe, 0);

		Assert.isNotNull(result, 'getDefaultValue should return non-null for DOUBLE');
		Assert.isInstanceOfType(result, Decimal.class, 'getDefaultValue should return Decimal for DOUBLE field');
	}

	/**
	 * @description Tests getDefaultValue directly returns Decimal for PERCENT field type.
	 */
	@IsTest
	private static void getDefaultValueReturnsDecimalForPercent()
	{
		UTIL_SObjectBuilderDefaultProvider provider = new UTIL_SObjectBuilderDefaultProvider();
		DescribeFieldResult fieldDescribe = Foobar__c.Percent__c.getDescribe();

		Object result = provider.getDefaultValue(fieldDescribe, 0);

		Assert.isNotNull(result, 'getDefaultValue should return non-null for PERCENT');
		Assert.isInstanceOfType(result, Decimal.class, 'getDefaultValue should return Decimal for PERCENT field');
	}

	/**
	 * @description Tests getDefaultValue directly returns String for PHONE field type.
	 */
	@IsTest
	private static void getDefaultValueReturnsStringForPhone()
	{
		UTIL_SObjectBuilderDefaultProvider provider = new UTIL_SObjectBuilderDefaultProvider();
		DescribeFieldResult fieldDescribe = Foobar__c.Phone__c.getDescribe();

		Object result = provider.getDefaultValue(fieldDescribe, 0);

		Assert.isNotNull(result, 'getDefaultValue should return non-null for PHONE');
		Assert.isInstanceOfType(result, String.class, 'getDefaultValue should return String for PHONE field');
	}

	/**
	 * @description Tests getDefaultValue directly returns String for PICKLIST field type.
	 */
	@IsTest
	private static void getDefaultValueReturnsStringForPicklist()
	{
		UTIL_SObjectBuilderDefaultProvider provider = new UTIL_SObjectBuilderDefaultProvider();
		DescribeFieldResult fieldDescribe = Foobar__c.Picklist__c.getDescribe();

		Object result = provider.getDefaultValue(fieldDescribe, 0);

		Assert.isNotNull(result, 'getDefaultValue should return non-null for PICKLIST');
		Assert.isInstanceOfType(result, String.class, 'getDefaultValue should return String for PICKLIST field');
	}

	/**
	 * @description Tests getDefaultValue directly returns String for MULTIPICKLIST field type.
	 */
	@IsTest
	private static void getDefaultValueReturnsStringForMultiPicklist()
	{
		UTIL_SObjectBuilderDefaultProvider provider = new UTIL_SObjectBuilderDefaultProvider();
		DescribeFieldResult fieldDescribe = Foobar__c.PicklistMultiSelect__c.getDescribe();

		Object result = provider.getDefaultValue(fieldDescribe, 0);

		Assert.isNotNull(result, 'getDefaultValue should return non-null for MULTIPICKLIST');
		Assert.isInstanceOfType(result, String.class, 'getDefaultValue should return String for MULTIPICKLIST field');
	}

	/**
	 * @description Tests getDefaultValue directly returns String for STRING field type.
	 */
	@IsTest
	private static void getDefaultValueReturnsStringForText()
	{
		UTIL_SObjectBuilderDefaultProvider provider = new UTIL_SObjectBuilderDefaultProvider();
		DescribeFieldResult fieldDescribe = Foobar__c.Text__c.getDescribe();

		Object result = provider.getDefaultValue(fieldDescribe, 0);

		Assert.isNotNull(result, 'getDefaultValue should return non-null for STRING');
		Assert.isInstanceOfType(result, String.class, 'getDefaultValue should return String for STRING field');
	}

	/**
	 * @description Tests getDefaultValue directly returns String for TEXTAREA field type.
	 */
	@IsTest
	private static void getDefaultValueReturnsStringForTextArea()
	{
		UTIL_SObjectBuilderDefaultProvider provider = new UTIL_SObjectBuilderDefaultProvider();
		DescribeFieldResult fieldDescribe = Foobar__c.TextArea__c.getDescribe();

		Object result = provider.getDefaultValue(fieldDescribe, 0);

		Assert.isNotNull(result, 'getDefaultValue should return non-null for TEXTAREA');
		Assert.isInstanceOfType(result, String.class, 'getDefaultValue should return String for TEXTAREA field');
	}

	/**
	 * @description Tests getDefaultValue directly returns String for URL field type.
	 */
	@IsTest
	private static void getDefaultValueReturnsStringForUrl()
	{
		UTIL_SObjectBuilderDefaultProvider provider = new UTIL_SObjectBuilderDefaultProvider();
		DescribeFieldResult fieldDescribe = Foobar__c.URL__c.getDescribe();

		Object result = provider.getDefaultValue(fieldDescribe, 0);

		Assert.isNotNull(result, 'getDefaultValue should return non-null for URL');
		Assert.isInstanceOfType(result, String.class, 'getDefaultValue should return String for URL field');
	}

	/**
	 * @description Tests getDefaultValue returns null for unsupported field types (ID, REFERENCE).
	 */
	@IsTest
	private static void getDefaultValueReturnsNullForUnsupportedTypes()
	{
		UTIL_SObjectBuilderDefaultProvider provider = new UTIL_SObjectBuilderDefaultProvider();

		// Test ID field type
		DescribeFieldResult idFieldDescribe = Foobar__c.Id.getDescribe();
		Object idResult = provider.getDefaultValue(idFieldDescribe, 0);
		Assert.isNull(idResult, 'getDefaultValue should return null for ID field type');

		// Test REFERENCE field type (lookup/master-detail)
		DescribeFieldResult refFieldDescribe = Foobar__c.OwnerId.getDescribe();
		Object refResult = provider.getDefaultValue(refFieldDescribe, 0);
		Assert.isNull(refResult, 'getDefaultValue should return null for REFERENCE field type');
	}

	/**
	 * @description Tests getDefaultValue returns null when fieldDescribe is null.
	 */
	@IsTest
	private static void getDefaultValueReturnsNullForNullFieldDescribe()
	{
		UTIL_SObjectBuilderDefaultProvider provider = new UTIL_SObjectBuilderDefaultProvider();

		Object result = provider.getDefaultValue(null, 0);

		Assert.isNull(result, 'getDefaultValue should return null when fieldDescribe is null');
	}
}