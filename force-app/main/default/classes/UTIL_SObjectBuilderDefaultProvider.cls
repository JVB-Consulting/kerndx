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
 * @description Provides the default value generation logic for the SObjectBuilder.
 * Subscribers should extend THIS class to override default values or define
 * custom required fields for SObjects.
 *
 * @see TST_Builder
 * @see UTIL_SObjectBuilderDefaultProvider_TEST
 *
 * @author Jason van Beukering
 *
 * @group Testing
 *
 * @date November 2025, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * global class MyDefaultProvider extends UTIL_SObjectBuilderDefaultProvider
 * {
 *     global override Set<SObjectField> defineSObjectRequiredFields(SObjectType sObjectType)
 *     {
 *         if(sObjectType == Account.SObjectType)
 *         {
 *             return new Set<SObjectField>{ Account.Industry };
 *         }
 *         return null;
 *     }
 * }
 * ```
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.AvoidGlobalModifier,PMD.ExcessiveClassLength')
global virtual inherited sharing class UTIL_SObjectBuilderDefaultProvider extends TST_Builder.DefaultValueProvider
{
	/**
	 * @description Use this text if using the default provider to inject the Record Index into generated values
	 */
	public static final String RECORD_INDEX_REPLACEMENT_TEXT = '[index]';

	@TestVisible
	private static Boolean isMockActive = false;
	@TestVisible
	private static Boolean mockPersonAccountsAreEnabled = false;
	@TestVisible
	private static Set<Id> mockPersonAccountRecordTypeIds;

	/**
	 * @description Abstracts the check for Person Accounts to allow for test mocking.
	 *
	 * @return True if Person Accounts are enabled or being mocked.
	 */
	private static Boolean isPersonAccountEnabled()
	{
		return isMockActive ? mockPersonAccountsAreEnabled : UTIL_SObjectDescribe.isPersonAccountEnabled();
	}

	/**
	 * @description Abstracts the retrieval of Person Account Record Types to allow for test mocking.
	 *
	 * @return A Set of Person Account Record Type Ids.
	 */
	private static Set<Id> getPersonAccountRecordTypes()
	{

		return isMockActive ? mockPersonAccountRecordTypeIds : UTIL_SObjectDescribe.isPersonAccountEnabled() ? SEL_RecordType.personAccountRecordTypes : new Set<Id>();
	}

	/**
	 * @description Defines a set of required fields for a given SObject. Can be overridden in a subclass.
	 *
	 * @param sObjectType The SObjectType for which the required fields will be defined.
	 *
	 * @return A set of defined required fields.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Set<SObjectField> result = instance.defineSObjectRequiredFields(Account.SObjectType);
	 * ```
	 */
	global virtual Set<SObjectField> defineSObjectRequiredFields(SObjectType sObjectType)
	{
		return null;
	}

	/**
	 * @description Defines a set of optional fields for a given SObject. Can be overridden in a subclass.
	 *
	 * @param sObjectType The SObjectType for which the optional fields will be defined.
	 *
	 * @return A set of defined optional fields.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Set<SObjectField> result = instance.defineSObjectOptionalFields(Account.SObjectType);
	 * ```
	 */
	global virtual Set<SObjectField> defineSObjectOptionalFields(SObjectType sObjectType)
	{
		return null;
	}

	/**
	 * @description Generates a default value for a given field of an SObject.
	 * Can be overridden by descendant classes.
	 *
	 * @param fieldDescribe The field describe information.
	 * @param recordIndex The index number (starting from 0) of the record being created.
	 *
	 * @return The generated field default value.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Object result = instance.getDefaultValue(Account.Name.getDescribe(), 10);
	 * ```
	 */
	global virtual Object getDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
	{
		switch on fieldDescribe?.type
		{
			when BOOLEAN
			{
				return getCheckboxDefaultValue(fieldDescribe, recordIndex);
			}
			when CURRENCY
			{
				return getCurrencyDefaultValue(fieldDescribe, recordIndex);
			}
			when DATE
			{
				return getDateDefaultValue(fieldDescribe, recordIndex);
			}
			when DATETIME
			{
				return getDateTimeDefaultValue(fieldDescribe, recordIndex);
			}
			when EMAIL
			{
				return getEmailDefaultValue(fieldDescribe, recordIndex);
			}
			when LOCATION
			{
				return getGeolocationDefaultValue(fieldDescribe, recordIndex);
			}
			when INTEGER, DOUBLE
			{
				return getDecimalDefaultValue(fieldDescribe, recordIndex);
			}
			when PERCENT
			{
				return getPercentDefaultValue(fieldDescribe, recordIndex);
			}
			when PHONE
			{
				return getPhoneDefaultValue(fieldDescribe, recordIndex);
			}
			when PICKLIST
			{
				return getPicklistDefaultValue(fieldDescribe, recordIndex);
			}
			when MULTIPICKLIST
			{
				return getMultiPicklistDefaultValue(fieldDescribe, recordIndex);
			}
			when STRING
			{
				return getTextDefaultValue(fieldDescribe, recordIndex);
			}
			when TEXTAREA
			{
				return getTextAreaDefaultValue(fieldDescribe, recordIndex);
			}
			when URL
			{
				return getURLDefaultValue(fieldDescribe, recordIndex);
			}
			when else
			{
				return null;
			}
		}
	}

	/**
	 * @description Provides the default value for a Checkbox field type.
	 *
	 * @param fieldDescribe The field describe information.
	 * @param recordIndex The index number (starting from 0) of the record being created.
	 *
	 * @return The default Boolean value.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Boolean result = instance.getCheckboxDefaultValue(Account.Name.getDescribe(), 10);
	 * ```
	 */
	@SuppressWarnings('ApexUnusedDeclaration')
	global virtual Boolean getCheckboxDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
	{
		return UTIL_Random.nextBoolean();
	}

	/**
	 * @description Provides the default value for a Currency field type.
	 *
	 * @param fieldDescribe The field describe information.
	 * @param recordIndex The index number (starting from 0) of the record being created.
	 *
	 * @return The default Decimal value.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Decimal result = instance.getCurrencyDefaultValue(Account.Name.getDescribe(), 10);
	 * ```
	 */
	global virtual Decimal getCurrencyDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
	{
		return getDecimalDefaultValue(fieldDescribe, recordIndex);
	}

	/**
	 * @description Provides the default value for a Date field type.
	 *
	 * @param fieldDescribe The field describe information.
	 * @param recordIndex The index number (starting from 0) of the record being created.
	 *
	 * @return The default Date value.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Date result = instance.getDateDefaultValue(Account.Name.getDescribe(), 10);
	 * ```
	 */
	@SuppressWarnings('ApexUnusedDeclaration')
	global virtual Date getDateDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
	{
		return UTIL_Random.randomDate();
	}

	/**
	 * @description Provides the default value for a Datetime field type.
	 *
	 * @param fieldDescribe The field describe information.
	 * @param recordIndex The index number (starting from 0) of the record being created.
	 *
	 * @return The default Datetime value.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Datetime result = instance.getDateTimeDefaultValue(Account.Name.getDescribe(), 10);
	 * ```
	 */
	@SuppressWarnings('ApexUnusedDeclaration')
	global virtual Datetime getDateTimeDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
	{
		return UTIL_Random.randomDateTime();
	}

	/**
	 * @description Provides the default value for an Email field type.
	 *
	 * @param fieldDescribe The field describe information.
	 * @param recordIndex The index number (starting from 0) of the record being created.
	 *
	 * @return The default String value for an email.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String result = instance.getEmailDefaultValue(Account.Name.getDescribe(), 10);
	 * ```
	 */
	global virtual String getEmailDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
	{
		return UTIL_Random.randomEmail();
	}

	/**
	 * @description Provides the default value for a Geolocation field type.
	 *
	 * @param fieldDescribe The field describe information.
	 * @param recordIndex The index number (starting from 0) of the record being created.
	 *
	 * @return The default Location value.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Location result = instance.getGeolocationDefaultValue(Account.Name.getDescribe(), 10);
	 * ```
	 */
	@SuppressWarnings('ApexUnusedDeclaration')
	global virtual Location getGeolocationDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
	{
		return Location.newInstance(UTIL_Random.nextInteger(-90, 90), UTIL_Random.nextInteger(-90, 90));
	}

	/**
	 * @description Provides the default value for a Decimal field type.
	 *
	 * @param fieldDescribe The field describe information.
	 * @param recordIndex The index number (starting from 0) of the record being created.
	 *
	 * @return The default Decimal value.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Decimal result = instance.getDecimalDefaultValue(Account.Name.getDescribe(), 10);
	 * ```
	 */
	@SuppressWarnings('ApexUnusedDeclaration')
	global virtual Decimal getDecimalDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
	{
		return UTIL_Random.randomDecimal(fieldDescribe.precision - fieldDescribe.scale, fieldDescribe.scale);
	}

	/**
	 * @description Provides the default value for a Percent field type.
	 *
	 * @param fieldDescribe The field describe information.
	 * @param recordIndex The index number (starting from 0) of the record being created.
	 *
	 * @return The default Decimal value.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Decimal result = instance.getPercentDefaultValue(Account.Name.getDescribe(), 10);
	 * ```
	 */
	global virtual Decimal getPercentDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
	{
		return getDecimalDefaultValue(fieldDescribe, recordIndex);
	}

	/**
	 * @description Provides the default value for a Phone field type.
	 *
	 * @param fieldDescribe The field describe information.
	 * @param recordIndex The index number (starting from 0) of the record being created.
	 *
	 * @return The default String value for a phone number.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String result = instance.getPhoneDefaultValue(Account.Name.getDescribe(), 10);
	 * ```
	 */
	@SuppressWarnings('ApexUnusedDeclaration')
	global virtual String getPhoneDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
	{
		return UTIL_Random.randomPhoneNumber();
	}

	/**
	 * @description Provides the default value for a Picklist field type.
	 *
	 * @param fieldDescribe The field describe information.
	 * @param recordIndex The index number (starting from 0) of the record being created.
	 *
	 * @return The default String value for a picklist.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String result = instance.getPicklistDefaultValue(Account.Name.getDescribe(), 10);
	 * ```
	 */
	@SuppressWarnings('ApexUnusedDeclaration')
	global virtual String getPicklistDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
	{
		return UTIL_SObjectDescribe.getDefaultPicklistValue(fieldDescribe, true);
	}

	/**
	 * @description Provides the default value for a Multipicklist field type.
	 *
	 * @param fieldDescribe The field describe information.
	 * @param recordIndex The index number (starting from 0) of the record being created.
	 *
	 * @return The default String value for a multipicklist.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String result = instance.getMultiPicklistDefaultValue(Account.Name.getDescribe(), 10);
	 * ```
	 */
	@SuppressWarnings('ApexUnusedDeclaration')
	global virtual String getMultiPicklistDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
	{
		return UTIL_SObjectDescribe.getDefaultPicklistValue(fieldDescribe, true);
	}

	/**
	 * @description Provides the default value for a Text field type.
	 *
	 * @param fieldDescribe The field describe information.
	 * @param recordIndex The index number (starting from 0) of the record being created.
	 *
	 * @return The default String value.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String result = instance.getTextDefaultValue(Account.Name.getDescribe(), 10);
	 * ```
	 */
	global virtual String getTextDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
	{
		return getTextDefaultValue(fieldDescribe, recordIndex, UTIL_Random.randomName());
	}

	/**
	 * @description Provides the default value for a Text field type by ensuring correct length enforce.
	 *
	 * @param fieldDescribe The field describe information.
	 * @param recordIndex The index number (starting from 0) of the record being created.
	 * @param defaultValue The value to use as default
	 *
	 * @return The default String value.
	 */
	private static String getTextDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex, String defaultValue)
	{
		return UTIL_String.abbreviate(defaultValue + recordIndex, fieldDescribe.length);
	}

	/**
	 * @description Provides the default value for a TextArea field type.
	 *
	 * @param fieldDescribe The field describe information.
	 * @param recordIndex The index number (starting from 0) of the record being created.
	 *
	 * @return The default String value.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String result = instance.getTextAreaDefaultValue(Account.Name.getDescribe(), 10);
	 * ```
	 */
	global virtual String getTextAreaDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
	{
		return getTextDefaultValue(fieldDescribe, recordIndex, UTIL_Random.randomDescription());
	}

	/**
	 * @description Provides the default value for a URL field type.
	 *
	 * @param fieldDescribe The field describe information.
	 * @param recordIndex The index number (starting from 0) of the record being created.
	 *
	 * @return The default String value for a URL.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String result = instance.getURLDefaultValue(Account.Name.getDescribe(), 10);
	 * ```
	 */
	global virtual String getURLDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
	{
		return getTextDefaultValue(fieldDescribe, recordIndex, 'https://www.example.com/');
	}

	/**
	 * @description Derives a lookup field API name (e.g., 'AccountId' or 'Custom__c') from a relationship name (e.g., 'Account' or 'Custom__r').
	 *
	 * @param relationshipName The relationship name.
	 *
	 * @return The corresponding field API name.
	 */
	public static String getFieldNameFromRelationshipName(String relationshipName)
	{
		if(relationshipName.endsWithIgnoreCase(UTIL_SObjectDescribe.RELATIONSHIP_SUFFIX))
		{
			return relationshipName.removeEndIgnoreCase(UTIL_SObjectDescribe.RELATIONSHIP_SUFFIX) + UTIL_SObjectDescribe.CUSTOM_FIELD_SUFFIX;
		}

		return relationshipName + 'Id';
	}

	/**
	 * @description Derives a relationship name (e.g., 'Account' or 'Custom__r') from a lookup field API name (e.g., 'AccountId' or 'Custom__c').
	 * If the input doesn't appear to be a field name (doesn't end with 'Id' or '__c'), returns it unchanged.
	 *
	 * @param fieldName The field API name.
	 *
	 * @return The corresponding relationship name.
	 */
	public static String getRelationshipNameFromFieldName(String fieldName)
	{
		if(String.isBlank(fieldName))
		{
			return fieldName;
		}

		if(fieldName.endsWithIgnoreCase(UTIL_SObjectDescribe.CUSTOM_FIELD_SUFFIX))
		{
			return fieldName.removeEndIgnoreCase(UTIL_SObjectDescribe.CUSTOM_FIELD_SUFFIX) + UTIL_SObjectDescribe.RELATIONSHIP_SUFFIX;
		}

		if(fieldName.endsWithIgnoreCase('Id') && fieldName.length() > 2)
		{
			return fieldName.removeEndIgnoreCase('Id');
		}

		// Not a field name pattern, return unchanged
		return fieldName;
	}

	/**
	 * @description Normalizes a dot-separated path by converting ALL segments (including the last one)
	 * to relationship names. This ensures consistent cache keys regardless of whether the caller uses
	 * field names (e.g., 'AccountId.ParentId') or relationship names (e.g., 'Account.Parent').
	 *
	 * @param path The path to normalize (e.g., 'AccountId.ParentId' or 'Account.Parent').
	 *
	 * @return The normalized path using relationship names, lowercased (e.g., 'account.parent').
	 */
	public static String normalizeToRelationshipPath(String path)
	{
		if(String.isBlank(path))
		{
			return path;
		}

		// Single segment - just convert directly
		if(!path.contains(UTIL_String.DOT))
		{
			return getRelationshipNameFromFieldName(path).toLowerCase();
		}

		// Multiple segments - convert all of them
		String result = UTIL_String.EMPTY;
		String remaining = path;

		while(remaining.contains(UTIL_String.DOT))
		{
			String segment = remaining.substringBefore(UTIL_String.DOT);
			remaining = remaining.substringAfter(UTIL_String.DOT);

			String normalizedSegment = getRelationshipNameFromFieldName(segment);
			result += (result.length() > 0 ? UTIL_String.DOT : UTIL_String.EMPTY) + normalizedSegment;
		}

		// Handle the last segment (also converted to relationship name)
		result += UTIL_String.DOT + getRelationshipNameFromFieldName(remaining);

		return result.toLowerCase();
	}

	/**
	 * @description Normalizes a dot-separated path to use relationship names instead of field names.
	 * This ensures consistent key format regardless of whether users specify paths using
	 * relationship names (e.g., 'Account.Parent.Name') or field names (e.g., 'AccountId.ParentId.Name').
	 *
	 * The last segment (the actual field name like 'Name', 'Id', etc.) is preserved as-is.
	 *
	 * @param path The path to normalize (e.g., 'AccountId.ParentId.Name' or 'Account.Parent.Name').
	 *
	 * @return The normalized path using relationship names (e.g., 'account.parent.name').
	 */
	@TestVisible
	private static String normalizePathToRelationshipNames(String path)
	{
		if(String.isBlank(path) || !path.contains(UTIL_String.DOT))
		{
			return path?.toLowerCase();
		}

		// Split into parent path (e.g., 'AccountId.ParentId') and field name (e.g., 'Name')
		String parentPath = path.substringBeforeLast(UTIL_String.DOT);
		String fieldName = path.substringAfterLast(UTIL_String.DOT);

		// Reuse the public method to normalize the parent path
		return normalizeToRelationshipPath(parentPath) + UTIL_String.DOT + fieldName.toLowerCase();
	}

	/**
	 * @description A wrapper class for a list of relationship field default values.
	 */
	@TestVisible
	private class ListRelationshipFieldDefaultValue extends TST_Builder.DefaultFieldValueProvider
	{
		/**
		 * @description A list of SObject values.
		 */
		private final List<SObject> objects;

		/**
		 * @description Constructor to wrap a given list of SObject values.
		 *
		 * @param objects The list of values that will be wrapped.
		 */
		public ListRelationshipFieldDefaultValue(List<SObject> objects)
		{
			this.objects = objects;
		}

		/**
		 * @description Gets the wrapped SObject Id for a given record index, cycling through the list.
		 *
		 * @param recordIndex The index number (starting from 0) of the record being created.
		 *
		 * @return The Id of the SObject at the specified index.
		 */
		public override Object getValue(Integer recordIndex)
		{
			// Use Math.mod to cycle through the list
			return objects.get(Math.mod(recordIndex, objects.size())).Id;
		}

		/**
		 * @description Returns the size of the wrapped list of SObject values.
		 *
		 * @return The list size.
		 */
		public Integer size()
		{
			return objects.size();
		}
	}

	/**
	 * @description A wrapper class for a list of field default values.
	 */
	@TestVisible
	private class ListFieldDefaultValue extends TST_Builder.DefaultFieldValueProvider
	{
		/**
		 * @description A list of field values.
		 */
		private final List<Object> values;

		/**
		 * @description Constructor to wrap a given list of values.
		 *
		 * @param values The list of values that will be wrapped.
		 */
		public ListFieldDefaultValue(List<Object> values)
		{
			this.values = values;
		}

		/**
		 * @description Gets the wrapped value for a given record index, cycling through the list.
		 *
		 * @param recordIndex The index number (starting from 0) of the record being created.
		 *
		 * @return The value at the calculated position in the list.
		 */
		public override Object getValue(Integer recordIndex)
		{
			return values.get(Math.mod(recordIndex, values.size()));
		}

		/**
		 * @description Returns the size of the wrapped list of values.
		 *
		 * @return The list size.
		 */
		public Integer size()
		{
			return values.size();
		}
	}

	/**
	 * @description A wrapper class for a relationship field's default value.
	 */
	@TestVisible
	private class RelationshipFieldDefaultValue extends TST_Builder.DefaultFieldValueProvider
	{
		/**
		 * @description The SObject value.
		 */
		private final SObject value;

		/**
		 * @description Constructor to wrap a given SObject value.
		 *
		 * @param value The SObject value that will be wrapped.
		 */
		public RelationshipFieldDefaultValue(SObject value)
		{
			this.value = value;
		}

		/**
		 * @description Gets the wrapped SObject's Id for a given record index.
		 *
		 * @param recordIndex The index number (starting from 0) of the record being created.
		 *
		 * @return The Id of the SObject field default value.
		 */
		public override Object getValue(Integer recordIndex)
		{
			return value.Id;
		}
	}

	/**
	 * @description A wrapper class for a field's default value.
	 */
	@TestVisible
	private class FieldDefaultValue extends TST_Builder.DefaultFieldValueProvider
	{
		/**
		 * @description An instance of the container class.
		 */
		private final UTIL_SObjectBuilderDefaultProvider defaultValueProvider;
		/**
		 * @description The field value.
		 */
		private final Object value;
		/**
		 * @description The field describe information.
		 */
		private final DescribeFieldResult fieldDescribe;

		/**
		 * @description Constructor to wrap a given field value.
		 *
		 * @param value The value that will be wrapped.
		 */
		public FieldDefaultValue(Object value)
		{
			this.value = value;
		}

		/**
		 * @description Constructor for a field value that will be generated based on describe information.
		 *
		 * @param defaultValueProvider The default value provider instance.
		 * @param fieldDescribe The field describe information.
		 */
		public FieldDefaultValue(UTIL_SObjectBuilderDefaultProvider defaultValueProvider, DescribeFieldResult fieldDescribe)
		{
			this(null);

			this.defaultValueProvider = defaultValueProvider;
			this.fieldDescribe = fieldDescribe;
		}

		/**
		 * @description Constructor for a field value that will be generated based on describe information.
		 *
		 * @param defaultValueProvider The default value provider instance.
		 * @param objectField The object field token.
		 */
		public FieldDefaultValue(UTIL_SObjectBuilderDefaultProvider defaultValueProvider, SObjectField objectField)
		{
			this(defaultValueProvider, UTIL_SObjectDescribe.getCachedFieldDescribe(objectField));
		}

		/**
		 * @description Gets the wrapped value for a given record index.
		 *
		 * @param recordIndex The index number (starting from 0) of the record being created.
		 *
		 * @return The field's default value.
		 */
		public override Object getValue(Integer recordIndex)
		{
			if(defaultValueProvider != null)
			{
				return defaultValueProvider.getDefaultValue(fieldDescribe, recordIndex);
			}
			else if(value instanceof String)
			{
				return ((String)value)?.replace(RECORD_INDEX_REPLACEMENT_TEXT, recordIndex.format() ?? UTIL_String.EMPTY);
			}

			return value;
		}
	}

	/**
	 * @description A wrapper for a default value that will be auto-generated.
	 */
	public class AutoFieldDefaultValue extends TST_Builder.DefaultFieldValueProvider
	{
		/**
		 * @description Default constructor
		 */
		@SuppressWarnings('PMD.EmptyStatementBlock')
		public AutoFieldDefaultValue()
		{
		}

		/**
		 * @description Gets the value for a given record index.
		 *
		 * @param recordIndex The index number (starting from 0) of the record being created.
		 *
		 * @return Always returns null, signaling that a value should be generated.
		 */
		public override Object getValue(Integer recordIndex)
		{
			return null;
		}
	}

	/**
	 * @description The default record type Id for the Account object.
	 */
	@TestVisible
	private Id accountDefaultRecordTypeId
	{
		get
		{
			if(accountDefaultRecordTypeId == null)
			{
				accountDefaultRecordTypeId = UTIL_SObjectDescribe.getDefaultRecordType(Account.SObjectType);
			}
			return accountDefaultRecordTypeId;
		}
		set;
	}

	/**
	 * @description Gets the default map of values for a given SObjectType.
	 *
	 * @param sObjectType The SObjectType for which to generate the map of values.
	 * @param mapOfValuesOverride A map of values that will override the auto-generated map.
	 *
	 * @return A map of default values.
	 */
	public override Map<String, TST_Builder.DefaultFieldValueProvider> getDefaultMapOfValues(SObjectType sObjectType, Map<String, Object> mapOfValuesOverride)
	{
		// Pass the SObjectType to the conversion method to allow for schema introspection
		Map<String, TST_Builder.DefaultFieldValueProvider> mapOfValues =
				new Map<String, TST_Builder.DefaultFieldValueProvider>(convertMapValueTypes(sObjectType, UTIL_String.EMPTY, mapOfValuesOverride));
		generateDefaultMapOfValues(sObjectType, mapOfValues, UTIL_String.EMPTY);
		return mapOfValues;
	}

	/**
	 * @description Builds the set of field names that need to be processed for default value generation.
	 * This optimization avoids iterating over all fields in the SObject schema.
	 *
	 * @param objectType The SObjectType being processed.
	 * @param prefix The current prefix (e.g., 'account.').
	 * @param keySetOverride The set of override keys from mapOfValues (already normalized to relationship names).
	 * @param definedRequiredFields User-defined required fields.
	 * @param definedOptionalFields User-defined optional fields.
	 * @param relationshipKeySet Set of relationship names with child overrides.
	 *
	 * @return A set of lowercase field names to process.
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private static Set<String> buildFieldsToProcess
			(
					SObjectType objectType,
					String prefix,
					Set<String> keySetOverride,
					Set<String> definedRequiredFields,
					Set<String> definedOptionalFields,
					Set<String> relationshipKeySet
			)
	{
		Set<String> fieldsToProcess = new Set<String>();

		// 1. Add schema-required fields (not marked optional)
		Set<String> schemaRequired = UTIL_SObjectDescribe.getDescribe(objectType).getCreatableRequiredFields();
		for(String fieldName : schemaRequired)
		{
			if(!definedOptionalFields.contains(fieldName))
			{
				fieldsToProcess.add(fieldName);
			}
		}

		// 2. Add user-defined required fields
		fieldsToProcess.addAll(definedRequiredFields);

		// 3. Add fields that have overrides (extract field name from fully-qualified keys)
		// Note: Keys are already normalized to relationship names by convertMapValueTypes,
		// so we only need to check against the relationship-based prefix
		Integer prefixLength = prefix.length();
		for(String key : keySetOverride)
		{
			if(key.startsWith(prefix))
			{
				String remainder = key.substring(prefixLength);
				String fieldName = remainder.contains(UTIL_String.DOT) ? remainder.substringBefore(UTIL_String.DOT) : remainder;
				if(String.isNotBlank(fieldName))
				{
					fieldsToProcess.add(fieldName);
				}
			}
		}

		// 4. Add relationship fields that are in relationshipKeySet
		Map<String, String> relationshipFields = UTIL_SObjectDescribe.getDescribe(objectType).getRelationshipFieldMap();
		for(String fieldName : relationshipFields.keySet())
		{
			String relationshipName = relationshipFields.get(fieldName);
			if(relationshipKeySet.contains(relationshipName) || relationshipKeySet.contains(fieldName))
			{
				fieldsToProcess.add(fieldName);
			}
		}

		return fieldsToProcess;
	}

	/**
	 * @description Generates the default map of values for a given SObjectType.
	 *
	 * @param objectType The SObjectType for which to generate the map of values.
	 * @param mapOfValues The map of values.
	 * @param prefix The relationship prefix (e.g., 'Contact.Account.').
	 */
	@TestVisible
	private void generateDefaultMapOfValues(SObjectType objectType, Map<String, TST_Builder.DefaultFieldValueProvider> mapOfValues, String prefix)
	{
		UTIL_SObjectDescribe utilDescribe = UTIL_SObjectDescribe.getDescribe(objectType);

		Set<String> definedOptionalFields = getDefinedSObjectOptionalFields(objectType);

		// Add the global optional fields from the builder's static list
		definedOptionalFields.addAll(getGlobalOptionalFieldsAsSet());

		Set<String> definedRequiredFields = getDefinedSObjectRequiredFields(objectType);
		Set<String> keySetOverride = mapOfValues.keySet();
		Set<String> relationshipKeySet = getRelationshipKeySet(keySetOverride, prefix);

		if(objectType == Account.SObjectType && isPersonAccountEnabled())
		{
			// Handle special case for Person Accounts
			managePersonAccountOrgEnabled(mapOfValues, prefix, definedRequiredFields);
		}

		// Build alternative prefix for field-name-based keys (e.g., 'accountid.' for 'account.')
		// This is used for looking up override values that may have been specified with field names
		String alternativePrefix = String.isNotBlank(prefix) ? convertPrefixToFieldNameBased(prefix) : prefix;

		// Build the set of fields we need to process (optimization: avoid iterating all fields)
		// Note: keySetOverride keys are already normalized to relationship names by convertMapValueTypes
		Set<String> fieldsToProcess = buildFieldsToProcess(objectType, prefix, keySetOverride, definedRequiredFields, definedOptionalFields, relationshipKeySet);

		for(String fieldNameLowerCase : fieldsToProcess)
		{
			// Use lightweight FieldMetadata first to reduce heap usage
			UTIL_SObjectDescribe.FieldMetadata metadata = utilDescribe.getFieldMetadata(fieldNameLowerCase);
			if(metadata == null)
			{
				continue; // Skip if field doesn't exist (e.g., invalid override key)
			}

			String fullyQualifiedFieldName = prefix + fieldNameLowerCase;

			// Try both relationship-name-based key and field-name-based key
			Object overrideFieldValue = mapOfValues.get(fullyQualifiedFieldName);
			if(overrideFieldValue == null && alternativePrefix != prefix)
			{
				// Try field-name-based key (e.g., 'accountid.parentid' instead of 'account.parentid')
				overrideFieldValue = mapOfValues.get(alternativePrefix + fieldNameLowerCase);
			}

			if(overrideFieldValue != null)
			{
				handleOverriddenField(mapOfValues, metadata, fullyQualifiedFieldName, overrideFieldValue, prefix);
			}
			else
			{
				// Use lightweight metadata for unoverridden fields
				handleUnoverriddenField
						(
								mapOfValues,
								metadata,
								fullyQualifiedFieldName,
								fieldNameLowerCase,
								prefix,
								definedOptionalFields,
								definedRequiredFields,
								relationshipKeySet
						);
			}
		}
	}

	/**
	 * @description Handles logic for a field that has an existing override value.
	 * Uses lightweight FieldMetadata for checks, only fetching heavy DescribeFieldResult when needed.
	 * This method checks if the override is an 'auto' placeholder and,
	 * if so, replaces it with a real provider or triggers relationship recursion.
	 *
	 * @param mapOfValues The map of default field providers, keyed by fully qualified field name. This map is modified in place.
	 * @param metadata The lightweight field metadata for quick checks.
	 * @param fullyQualifiedFieldName The full, lower-case, prefixed name of the field (e.g., 'account.name').
	 * @param overrideFieldValue The override value (e.g., AutoFieldDefaultValue) retrieved from the `mapOfValues`.
	 * @param prefix The relationship prefix (e.g., 'contact.account.').
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private void handleOverriddenField
			(
					Map<String, TST_Builder.DefaultFieldValueProvider> mapOfValues,
					UTIL_SObjectDescribe.FieldMetadata metadata,
					String fullyQualifiedFieldName,
					Object overrideFieldValue,
					String prefix
			)
	{
		// If the override is not an AutoFieldDefaultValue, it's a specific provider
		// (e.g., new FieldValue(123)), so we leave it alone - no DescribeFieldResult needed.
		if(overrideFieldValue instanceof AutoFieldDefaultValue)
		{
			if(metadata.relationshipName == null)
			{
				// Only get heavy DescribeFieldResult when creating a non-relationship provider
				mapOfValues.put(fullyQualifiedFieldName, new FieldDefaultValue(this, metadata.fieldDescribe));
			}
			else
			{
				// Use lightweight metadata for relationship fields
				putRelationshipField(mapOfValues, metadata, prefix);
				mapOfValues.remove(fullyQualifiedFieldName);
			}
		}
	}

	/**
	 * @description Handles logic for a field that does not have an override value.
	 * Uses lightweight FieldMetadata for checks to reduce heap usage, only fetching
	 * the heavy DescribeFieldResult when actually creating a provider.
	 *
	 * @param mapOfValues The map of default field providers, keyed by fully qualified field name. This map is modified in place.
	 * @param metadata The lightweight field metadata for quick checks.
	 * @param fullyQualifiedFieldName The full, lower-case, prefixed name of the field (e.g., 'account.name').
	 * @param fieldNameLowerCase The lower-case API name of the field, without any prefix.
	 * @param prefix The relationship prefix (e.g., 'contact.account.').
	 * @param definedOptionalFields A set of field names explicitly defined as optional by the factory.
	 * @param definedRequiredFields A set of field names explicitly defined as required by the factory.
	 * @param relationshipKeySet A set of relationship names that are part of the current override keyset.
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private void handleUnoverriddenField
			(
					Map<String, TST_Builder.DefaultFieldValueProvider> mapOfValues,
					UTIL_SObjectDescribe.FieldMetadata metadata,
					String fullyQualifiedFieldName,
					String fieldNameLowerCase,
					String prefix,
					Set<String> definedOptionalFields,
					Set<String> definedRequiredFields,
					Set<String> relationshipKeySet
			)
	{
		Boolean isRequired = isFieldRequired(metadata, fieldNameLowerCase, definedOptionalFields, definedRequiredFields);

		if(metadata.relationshipName == null)
		{
			if(isRequired)
			{
				// Only get heavy DescribeFieldResult when actually creating a provider
				mapOfValues.put(fullyQualifiedFieldName, new FieldDefaultValue(this, metadata.fieldDescribe));
			}
		}
		else
		{
			// Add if it's required OR if it's part of another relationship being defined
			// Check both relationship name (e.g., 'account') and field name (e.g., 'accountid')
			// to support users specifying paths with field names like 'AccountId.ParentId'
			if(isRequired || relationshipKeySet.contains(metadata.relationshipName) || relationshipKeySet.contains(fieldNameLowerCase))
			{
				// Use lightweight metadata for relationship fields
				putRelationshipField(mapOfValues, metadata, prefix);
			}
		}
	}

	/**
	 * @description Determines if a field requires a default value for record creation.
	 * Uses lightweight FieldMetadata instead of DescribeFieldResult to reduce heap usage.
	 *
	 * @param fieldDescribe The describe result for the field being evaluated.
	 *
	 * @return `true` if the field requires a default value, `false` otherwise.
	 */
	@TestVisible
	private static Boolean isDefaultValueRequired(DescribeFieldResult fieldDescribe)
	{
		return !fieldDescribe.defaultedOnCreate
				&& !fieldDescribe.autoNumber
				&& !fieldDescribe.nillable
				&& fieldDescribe.createable;
	}

	/**
	 * @description Helper method to determine if a field should be treated as required.
	 * Uses lightweight FieldMetadata to reduce heap usage.
	 * A field is considered required if it's required by the schema
	 * (and not explicitly marked as optional) OR if it's explicitly
	 * marked as required by the factory.
	 *
	 * @param metadata The lightweight field metadata from UTIL_SObjectDescribe.
	 * @param fieldNameLowerCase The lower-case API name of the field, without any prefix.
	 * @param definedOptionalFields A set of field names explicitly defined as optional by the factory.
	 * @param definedRequiredFields A set of field names explicitly defined as required by the factory.
	 *
	 * @return `true` if the field is considered required, `false` otherwise.
	 */
	private static Boolean isFieldRequired
			(
					UTIL_SObjectDescribe.FieldMetadata metadata,
					String fieldNameLowerCase,
					Set<String> definedOptionalFields,
					Set<String> definedRequiredFields
			)
	{
		// A field is required if it's required by schema AND not explicitly defined as optional
		Boolean isRequiredBySchema = metadata.isCreatableRequired && !definedOptionalFields.contains(fieldNameLowerCase);

		// OR if it's explicitly defined as required in our factory settings
		Boolean isRequiredByDefinition = definedRequiredFields.contains(fieldNameLowerCase);

		return isRequiredBySchema || isRequiredByDefinition;
	}

	/**
	 * @description Puts a relationship field into a map of values.
	 * Uses lightweight FieldMetadata to reduce heap usage.
	 * Polymorphic fields (those referencing multiple object types like OwnerId) are skipped
	 * and logged, as they cannot be auto-defaulted without knowing which type to use.
	 *
	 * @param mapOfValues The map of values in which the relationship field will be placed.
	 * @param metadata The lightweight field metadata from UTIL_SObjectDescribe.
	 * @param prefix The relationship prefix (e.g., 'Contact.Account.').
	 */
	@TestVisible
	private void putRelationshipField
			(
					Map<String, TST_Builder.DefaultFieldValueProvider> mapOfValues,
					UTIL_SObjectDescribe.FieldMetadata metadata,
					String prefix
			)
	{
		// Skip polymorphic fields (e.g., OwnerId can reference User or Queue)
		// These cannot be auto-defaulted without explicit type specification
		if(metadata.referenceToObjectNames.size() > 1)
		{
			LOG_Builder.build()
					.info('Skipping polymorphic field "' + metadata.name + '" in ' + TST_Builder.class.getName() + '. ' +
							'Field references multiple types: ' + metadata.referenceToObjectNames + '. ' +
							'Use withField() to set an explicit value.')
					.at(UTIL_SObjectBuilderDefaultProvider.class.getName() + '.putRelationshipField')
					.emit();
			return;
		}

		String fullyQualifiedRelationshipName = prefix + metadata.relationshipName;
		mapOfValues.put(fullyQualifiedRelationshipName + UTIL_String.DOT + 'id', new FieldDefaultValue(null));

		// Convert object name to SObjectType for recursion
		SObjectType referencedType = UTIL_SObjectDescribe.getGlobalDescribe().get(metadata.referenceToObjectNames.get(0));
		generateDefaultMapOfValues(referencedType, mapOfValues, fullyQualifiedRelationshipName + UTIL_String.DOT);
	}

	/**
	 * @description Manages the map of values and required fields for Accounts when Person Accounts are enabled.
	 *
	 * @param mapOfValues The map of values from which the Record Type Id will be extracted.
	 * @param prefix The relationship prefix (e.g., 'Contact.Account.').
	 * @param definedRequiredFields A set of defined required fields.
	 */
	@TestVisible
	private void managePersonAccountOrgEnabled(Map<String, TST_Builder.DefaultFieldValueProvider> mapOfValues, String prefix, Set<String> definedRequiredFields)
	{
		String fullyQualifiedRecordTypeIdFieldName = prefix + 'recordtypeid';

		TST_Builder.DefaultFieldValueProvider recordTypeIdDefaultValue = mapOfValues.get(fullyQualifiedRecordTypeIdFieldName);

		if(recordTypeIdDefaultValue == null)
		{
			recordTypeIdDefaultValue = new FieldDefaultValue(null);
		}

		if(recordTypeIdDefaultValue instanceof FieldDefaultValue)
		{
			Object recordTypeIdValue = recordTypeIdDefaultValue.getValue(0);
			if(recordTypeIdValue == null)
			{
				recordTypeIdValue = accountDefaultRecordTypeId;
				mapOfValues.put(fullyQualifiedRecordTypeIdFieldName, new FieldDefaultValue(accountDefaultRecordTypeId));
			}

			Id recordTypeId = UTIL_SObject.validateId((String)recordTypeIdValue);

			if(recordTypeIdValue != null && recordTypeId == null)
			{
				throw new IllegalArgumentException('The Record Type Id provided "' + recordTypeIdValue + '" is not valid');
			}

			// Use the abstracted helper method
			if(getPersonAccountRecordTypes().contains(recordTypeId))
			{
				definedRequiredFields.add(UTIL_SObjectDescribe.getDescribe(Contact.SObjectType).getFieldDescribe(Contact.LastName).name.toLowerCase());
			}
			else
			{
				definedRequiredFields.add('name');
			}
		}
		else if(recordTypeIdDefaultValue instanceof ListFieldDefaultValue)
		{
			throw new UTIL_Exceptions.IllegalStateException('List values is not supported for field "' + fullyQualifiedRecordTypeIdFieldName + '"');
		}
	}

	/**
	 * @description Converts a Set of SObjectField tokens to a Set of lowercase String API names.
	 *
	 * @param sObjectType The SObjectType for cached field describes.
	 * @param objectFields The Set of SObjectField tokens.
	 *
	 * @return A Set of lowercase String API names.
	 */
	private static Set<String> convertSObjectFieldsToStrings(SObjectType sObjectType, Set<SObjectField> objectFields)
	{
		Set<String> lowerCaseFieldNames = new Set<String>();

		if(objectFields != null)
		{
			UTIL_SObjectDescribe objectDescribe = UTIL_SObjectDescribe.getDescribe(sObjectType);
			for(SObjectField objectField : objectFields)
			{
				if(objectField != null)
				{
					lowerCaseFieldNames.add(objectDescribe.getFieldDescribe(objectField).name.toLowerCase());
				}
			}
		}
		return lowerCaseFieldNames;
	}

	/**
	 * @description Converts the global static 'TST_Builder.optionalFields' list
	 * (which contains Strings and SObjectFields) into a Set of lowercase field names.
	 *
	 * @return A Set<String> of lowercase field names.
	 */
	private static Set<String> getGlobalOptionalFieldsAsSet()
	{
		Set<String> globalOptionalFields = new Set<String>();

		for(Object fieldObject : TST_Builder.optionalFields)
		{
			String fieldName;

			if(fieldObject instanceof SObjectField)
			{
				fieldName = UTIL_SObjectDescribe.getCachedFieldDescribe((SObjectField)fieldObject)?.name;
			}
			else if(fieldObject instanceof String)
			{
				fieldName = (String)fieldObject;
			}

			if(String.isNotBlank(fieldName))
			{
				globalOptionalFields.add(fieldName.toLowerCase());
			}
		}

		return globalOptionalFields;
	}

	/**
	 * @description Gets a defined set of optional fields for a given SObjectType.
	 *
	 * @param sObjectType The SObjectType for which to return the defined optional fields.
	 *
	 * @return A set of defined optional fields.
	 */
	@TestVisible
	private Set<String> getDefinedSObjectOptionalFields(SObjectType sObjectType)
	{
		return convertSObjectFieldsToStrings(sObjectType, defineSObjectOptionalFields(sObjectType));
	}

	/**
	 * @description Gets a defined set of required fields for a given SObjectType.
	 *
	 * @param sObjectType The SObjectType for which to return the defined required fields.
	 *
	 * @return A set of defined required fields.
	 */
	@TestVisible
	private Set<String> getDefinedSObjectRequiredFields(SObjectType sObjectType)
	{
		return convertSObjectFieldsToStrings(sObjectType, defineSObjectRequiredFields(sObjectType));
	}

	/**
	 * @description Gets a set of relationship names that start with a given prefix.
	 * Supports both relationship name prefixes (e.g., 'Account.') and field name prefixes (e.g., 'AccountId.').
	 *
	 * @param keySetOverride The keySet of fully qualified field names.
	 * @param prefix The prefix (e.g., 'Contact.Account.').
	 *
	 * @return A set of relationship names (includes both relationship names and field names for compatibility).
	 */
	@TestVisible
	private static Set<String> getRelationshipKeySet(Set<String> keySetOverride, String prefix)
	{
		Set<String> relationshipKeySet = new Set<String>();
		String prefixLowerCase = prefix.toLowerCase();

		// Build a set of prefixes to check - includes both relationship name and field name variants
		Set<String> prefixesToCheck = new Set<String> {prefixLowerCase};

		// Also add field-name-based prefix (e.g., 'accountid.' for 'account.')
		// This supports users specifying paths like 'AccountId.ParentId' instead of 'Account.Parent'
		if(String.isNotBlank(prefix))
		{
			String alternativePrefix = convertPrefixToFieldNameBased(prefixLowerCase);
			if(alternativePrefix != prefixLowerCase)
			{
				prefixesToCheck.add(alternativePrefix);
			}
		}

		for(String fullyQualifiedFieldName : keySetOverride)
		{
			fullyQualifiedFieldName = fullyQualifiedFieldName.toLowerCase();

			for(String prefixToCheck : prefixesToCheck)
			{
				if(fullyQualifiedFieldName.startsWith(prefixToCheck))
				{
					String fullyQualifiedFieldNameAfterPrefix = fullyQualifiedFieldName.substringAfter(prefixToCheck) + UTIL_String.EMPTY;
					if(fullyQualifiedFieldNameAfterPrefix.contains(UTIL_String.DOT))
					{
						relationshipKeySet.add(fullyQualifiedFieldName.substringBetween(prefixToCheck, UTIL_String.DOT));
					}
				}
			}
		}
		return relationshipKeySet;
	}

	/**
	 * @description Converts a relationship-name-based prefix to a field-name-based prefix.
	 * E.g., 'account.' → 'accountid.', 'lookup__r.' → 'lookup__c.'
	 * Only converts segments that appear to be relationship names (not already field names).
	 *
	 * @param relationshipPrefix The relationship name prefix (e.g., 'account.').
	 *
	 * @return The field name prefix (e.g., 'accountid.').
	 */
	@TestVisible
	private static String convertPrefixToFieldNameBased(String relationshipPrefix)
	{
		if(String.isBlank(relationshipPrefix))
		{
			return relationshipPrefix;
		}

		// Use substringBefore/After instead of split (regex is expensive)
		Boolean endsWithDot = relationshipPrefix.endsWith(UTIL_String.DOT);
		String result = UTIL_String.EMPTY;
		String remaining = relationshipPrefix;

		while(remaining.contains(UTIL_String.DOT))
		{
			String segment = remaining.substringBefore(UTIL_String.DOT);
			remaining = remaining.substringAfter(UTIL_String.DOT);

			if(String.isNotBlank(segment))
			{
				// Only convert if it looks like a relationship name, not already a field name
				String convertedSegment;
				if(segment.endsWithIgnoreCase('Id') || segment.endsWithIgnoreCase(UTIL_SObjectDescribe.CUSTOM_FIELD_SUFFIX))
				{
					// Already a field name, keep as-is
					convertedSegment = segment;
				}
				else
				{
					// Relationship name, convert to field name
					convertedSegment = getFieldNameFromRelationshipName(segment);
				}
				result += (result.length() > 0 ? UTIL_String.DOT : UTIL_String.EMPTY) + convertedSegment;
			}
		}

		// Handle any remaining segment (if no trailing dot)
		if(String.isNotBlank(remaining))
		{
			String convertedSegment;
			if(remaining.endsWithIgnoreCase('Id') || remaining.endsWithIgnoreCase(UTIL_SObjectDescribe.CUSTOM_FIELD_SUFFIX))
			{
				convertedSegment = remaining;
			}
			else
			{
				convertedSegment = getFieldNameFromRelationshipName(remaining);
			}
			result += (result.length() > 0 ? UTIL_String.DOT : UTIL_String.EMPTY) + convertedSegment;
		}

		// Ensure lowercase and restore trailing dot if original had one
		return (result + (endsWithDot ? UTIL_String.DOT : UTIL_String.EMPTY)).toLowerCase();
	}

	/**
	 * @description Converts a map from Map<String, Object> to Map<String, DefaultFieldValueProvider>.
	 *
	 * @param currentSObjectType The SObjectType context for the current level of the map.
	 * @param prefix The prefix (e.g., 'Contact.Account.').
	 * @param mapOfValues The map of values to convert.
	 *
	 * @return The converted map.
	 */
	@TestVisible
	private Map<String, TST_Builder.DefaultFieldValueProvider> convertMapValueTypes(SObjectType currentSObjectType, String prefix, Map<String, Object> mapOfValues)
	{
		Map<String, TST_Builder.DefaultFieldValueProvider> convertedMap = new Map<String, TST_Builder.DefaultFieldValueProvider>();

		if(mapOfValues == null)
		{
			return convertedMap;
		}

		for(String name : mapOfValues.keySet())
		{
			if(name == null)
			{
				continue;
			}

			Object value = mapOfValues.get(name);
			// Normalize the key to use relationship names for consistent lookup
			// E.g., 'AccountId.ParentId.Name' becomes 'account.parent.name'
			String fullyQualifiedName = normalizePathToRelationshipNames(prefix + name.trim());

			processMapEntry(currentSObjectType, convertedMap, fullyQualifiedName, name, value);
		}

		return convertedMap;
	}

	/**
	 * @description Helper method to process a single entry during map conversion.
	 * This handles the type-checking, provider creation, and recursive calls.
	 *
	 * @param currentSObjectType The SObjectType context.
	 * @param convertedMap The map to add the processed value to.
	 * @param fullyQualifiedName The full, dot-notation name (e.g., 'account.owner.name').
	 * @param leafName The key from the map (e.g., 'Account' or 'Owner').
	 * @param value The value of the field.
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList,PMD.AvoidDeeplyNestedIfStmts')
	private void processMapEntry
			(
					SObjectType currentSObjectType,
					Map<String, TST_Builder.DefaultFieldValueProvider> convertedMap,
					String fullyQualifiedName,
					String leafName,
					Object value
			)
	{
		if(value instanceof TST_Builder.DefaultFieldValueProvider)
		{
			convertedMap.put(fullyQualifiedName, (TST_Builder.DefaultFieldValueProvider)value);
		}
		else if(value instanceof Map<String, Object>)
		{
			// Resolve the SObjectType for the next level of recursion
			SObjectType nextSObjectType = null;
			if(currentSObjectType != null)
			{
				UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe(currentSObjectType);
				// Try explicit field name
				SObjectField field = describe.getField(leafName);
				if(field == null)
				{
					// Try derivation (e.g. Account -> AccountId)
					field = describe.getField(getFieldNameFromRelationshipName(leafName));
				}

				if(field != null)
				{
					DescribeFieldResult fieldDescribe = describe.getFieldDescribe(field);

					if(fieldDescribe.type == DisplayType.REFERENCE && !fieldDescribe.referenceTo.isEmpty())
					{
						nextSObjectType = fieldDescribe.referenceTo.iterator().next();
					}
				}
			}

			// Recursive call
			convertedMap.putAll(convertMapValueTypes(nextSObjectType, fullyQualifiedName + UTIL_String.DOT, (Map<String, Object>)value));
		}
		else if(value instanceof List<Object>)
		{
			List<Object> objects = (List<Object>)value;

			if(objects.isEmpty() || !(objects.iterator().next() instanceof SObject))
			{
				// Case A: List<String> or empty. Treat as indexed values.
				convertedMap.put(fullyQualifiedName, new ListFieldDefaultValue(objects));
			}
			else
			{
				// Case B vs C/D: Indexed Lookup vs Child Relationship.
				Boolean isIndexedLookup = false;

				if(currentSObjectType != null)
				{
					UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe(currentSObjectType);

					// Check 1: Is it a field? (e.g. 'Account', 'Parent', 'Owner')
					SObjectField field = describe.getField(leafName);
					if(field == null)
					{
						field = describe.getField(getFieldNameFromRelationshipName(leafName));
					}

					// If it IS a field, and it IS a reference, it is an indexed lookup.
					if(field != null && describe.getFieldDescribe(field).type == DisplayType.REFERENCE)
					{
						isIndexedLookup = true;
					}
				}

				if(isIndexedLookup)
				{
					// Case B: Lookup list for indexing.
					convertedMap.put(fullyQualifiedName, new ListFieldDefaultValue(objects));
				}
				else
				{
					// Case C/D: Child relationship (e.g. 'Contacts') or unknown.
					// Treat as single value (Mock).
					convertedMap.put(fullyQualifiedName, new FieldDefaultValue(value));
				}
			}
		}
		else
		{
			// Default case for primitives or SObject types
			convertedMap.put(fullyQualifiedName, new FieldDefaultValue(value));
		}
	}
}