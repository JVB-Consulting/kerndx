// SPDX-License-Identifier: BSD-3-Clause
/**
 * Copyright (c), FinancialForce.com, inc
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * - Redistributions of source code must retain the above copyright notice,
 * this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation
 * and/or other materials provided with the distribution.
 * - Neither the name of the FinancialForce.com, inc nor the names of its contributors
 * may be used to endorse or promote products derived from this software without
 * specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * This class adapted from https://github.com/capeterson/Apex-Util
 * Used under a BSD license: https://github.com/capeterson/Apex-Util/blob/master/LICENSE
 */

/**
 * @description A semi-intelligent wrapper for standard Apex Schema methods, providing internal caching
 * to avoid hitting describe limits and helper methods for handling relationship field names and namespaces.
 *
 * @see UTIL_SObjectDescribe_TEST
 * @see UTIL_SObjectDescribe_ConnectApi_TEST
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date February 2026, June 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe(Account.SObjectType);
 * SObjectField nameField = describe.getNameField();
 * String fieldName = UTIL_SObjectDescribe.getCachedFieldName(Account.Industry);
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier,PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.ExcessiveClassLength,PMD.NcssTypeCount,PMD.AvoidBooleanMethodParameters')
global inherited sharing class UTIL_SObjectDescribe
{
	/**
	 * @description The SObjectType this instance describes.
	 */
	private final SObjectType objectType;

	/**
	 * @description Field API name used to detect Person Account enablement.
	 */
	@TestVisible
	private static final String FIELD_IS_PERSON_ACCOUNT = 'isPersonAccount';

	/**
	 * @description Suffix for custom fields (e.g., `MyField__c`).
	 */
	public static final String CUSTOM_FIELD_SUFFIX = '__c';

	/**
	 * @description Suffix for share objects of custom objects (e.g., `MyObject__Share`).
	 */
	public static final String CUSTOM_OBJECT_SHARE_SUFFIX = '__Share';

	/**
	 * @description Suffix for relationship fields (e.g., `Account__r`).
	 */
	public static final String RELATIONSHIP_SUFFIX = '__r';

	/**
	 * @description Suffix for platform events (e.g., `LogEntryEvent__e`). Namespace-immune — a
	 * managed platform event (`ns__Foo__e`) still ends with this suffix.
	 */
	public static final String PLATFORM_EVENT_SUFFIX = '__e';

	/**
	 * @description Suffix marking a Change Data Capture change event. Matches both standard
	 * (`AccountChangeEvent`) and custom (`Foo__ChangeEvent`, namespaced `ns__Foo__ChangeEvent`)
	 * change events — use {@link #CUSTOM_CHANGE_EVENT_SUFFIX} when only custom-object change events
	 * should match.
	 */
	public static final String CHANGE_EVENT_SUFFIX = 'ChangeEvent';

	/**
	 * @description Suffix marking a custom-object Change Data Capture change event
	 * (e.g., `Foo__ChangeEvent`). Narrower than {@link #CHANGE_EVENT_SUFFIX}: standard change
	 * events (`AccountChangeEvent`) do NOT end with `__ChangeEvent`.
	 */
	public static final String CUSTOM_CHANGE_EVENT_SUFFIX = '__ChangeEvent';

	/**
	 * @description Default batch size for DML and query operations (200 records).
	 */
	public static final Integer DEFAULT_BATCH_SIZE = 200;

	/**
	 * @description Maximum batch size for DML operations (2000 records).
	 */
	public static final Integer MAXIMUM_BATCH_SIZE = 2000;

	/**
	 * @description Cached name field for this SObject, lazily populated by getNameField().
	 */
	private SObjectField nameField;

	/**
	 * @description Lazy-loaded DescribeSObjectResult for this SObject.
	 */
	private final DescribeSObjectResult describe
	{
		get
		{
			if(describe == null)
			{
				describe = objectType.getDescribe(SObjectDescribeOptions.DEFERRED);
			}
			return describe;
		}
		set;
	}

	/**
	 * @description Lazy-loaded map of field API names to SObjectField tokens.
	 */
	private final Map<String, SObjectField> fields
	{
		get
		{
			if(fields == null)
			{
				fields = describe.fields.getMap();
			}
			return fields;
		}
		set;
	}

	/**
	 * @description Lazy-loaded map of field set names to FieldSet objects.
	 */
	private final Map<String, FieldSet> fieldSets
	{
		get
		{
			if(fieldSets == null)
			{
				fieldSets = describe.fieldSets.getMap();
			}
			return fieldSets;
		}
		set;
	}

	/**
	 * @description Lazy-loaded namespace-aware wrapper around the fields map.
	 */
	private final FieldsMap wrappedFields
	{
		get
		{
			if(wrappedFields == null)
			{
				wrappedFields = new FieldsMap(fields);
			}
			return wrappedFields;
		}
		set;
	}

	/**
	 * @description Lazy-loaded map of field API names (lowercase) to FieldMetadata.
	 * This is the primary cache - derived caches are built lazily from this.
	 */
	private final Map<String, FieldMetadata> fieldMetadataMap
	{
		get
		{
			if(fieldMetadataMap == null)
			{
				fieldMetadataMap = new Map<String, FieldMetadata>();

				for(String fieldNameKey : fields.keySet())
				{
					SObjectField field = fields.get(fieldNameKey);
					// Use field.getDescribe() directly instead of getCachedFieldDescribe() to avoid
					// caching ALL DescribeFieldResults upfront. The DescribeFieldResult used here
					// can be garbage collected after FieldMetadata extracts the needed values.
					// Caching only happens when metadata.getFieldDescribe() is explicitly called later.
					DescribeFieldResult fieldDescribe = field.getDescribe();

					String originalCaseName = fieldDescribe.getName();
					String lowerCaseName = originalCaseName.toLowerCase();
					String relationshipNameOriginal = fieldDescribe.relationshipName;
					String relationshipNameLower = relationshipNameOriginal != null
							? relationshipNameOriginal.toLowerCase()
							: null;

					FieldMetadata metadata = new FieldMetadata(this, fieldDescribe, originalCaseName, lowerCaseName, relationshipNameLower, relationshipNameOriginal);
					fieldMetadataMap.put(lowerCaseName, metadata);
				}
			}
			return fieldMetadataMap;
		}
		set;
	}

	/**
	 * @description Lazy-loaded set of queryable field names (original case).
	 * Built from fieldMetadataMap on first access.
	 */
	private final Set<String> queryableFieldNamesCache
	{
		get
		{
			if(queryableFieldNamesCache == null)
			{
				queryableFieldNamesCache = new Set<String>();
				for(FieldMetadata metadata : fieldMetadataMap.values())
				{
					if(metadata.isSelectableInQuery)
					{
						queryableFieldNamesCache.add(metadata.name);
					}
				}
			}
			return queryableFieldNamesCache;
		}
		set;
	}

	/**
	 * @description Lazy-loaded set of traversable reference field names (lowercase).
	 * Built from fieldMetadataMap on first access.
	 */
	private final Set<String> traversableReferenceFieldsCache
	{
		get
		{
			if(traversableReferenceFieldsCache == null)
			{
				traversableReferenceFieldsCache = new Set<String>();
				for(FieldMetadata metadata : fieldMetadataMap.values())
				{
					if(metadata.isTraversableReference)
					{
						traversableReferenceFieldsCache.add(metadata.nameLowerCase);
					}
				}
			}
			return traversableReferenceFieldsCache;
		}
		set;
	}

	/**
	 * @description Lazy-loaded set of creatable required field names (lowercase).
	 * Built from fieldMetadataMap on first access.
	 */
	private final Set<String> creatableRequiredFieldsCache
	{
		get
		{
			if(creatableRequiredFieldsCache == null)
			{
				creatableRequiredFieldsCache = new Set<String>();
				for(FieldMetadata metadata : fieldMetadataMap.values())
				{
					if(metadata.isCreatableRequired)
					{
						creatableRequiredFieldsCache.add(metadata.nameLowerCase);
					}
				}
			}
			return creatableRequiredFieldsCache;
		}
		set;
	}

	/**
	 * @description Lazy-loaded map of field name (lowercase) to relationship name (lowercase).
	 * Built from fieldMetadataMap on first access.
	 */
	private final Map<String, String> relationshipFieldMapCache
	{
		get
		{
			if(relationshipFieldMapCache == null)
			{
				relationshipFieldMapCache = new Map<String, String>();
				for(FieldMetadata metadata : fieldMetadataMap.values())
				{
					if(metadata.relationshipName != null)
					{
						relationshipFieldMapCache.put(metadata.nameLowerCase, metadata.relationshipName);
					}
				}
			}
			return relationshipFieldMapCache;
		}
		set;
	}

	/**
	 * @description Lazy-loaded map of relationship name (lowercase) to SObjectField token.
	 * Built from fieldMetadataMap on first access.
	 */
	private final Map<String, SObjectField> referenceFieldMapCache
	{
		get
		{
			if(referenceFieldMapCache == null)
			{
				referenceFieldMapCache = new Map<String, SObjectField>();
				for(FieldMetadata metadata : fieldMetadataMap.values())
				{
					if(metadata.relationshipNameOriginalCase != null)
					{
						referenceFieldMapCache.put(metadata.relationshipNameOriginalCase, fields.get(metadata.nameLowerCase));
					}
				}
			}
			return referenceFieldMapCache;
		}
		set;
	}

	/**
	 * @description Global static cache for SObjectField describes.
	 * Enables context-agnostic field name lookups without requiring an SObject instance.
	 * Using SObjectField as key is efficient since tokens are singletons.
	 */
	private static final Map<SObjectField, DescribeFieldResult> globalFieldDescribes
	{
		get
		{
			if(globalFieldDescribes == null)
			{
				globalFieldDescribes = new Map<SObjectField, DescribeFieldResult>();
			}
			return globalFieldDescribes;
		}
		set;
	}

	/**
	 * @description Static accessor for field describes that enables context-agnostic lookups.
	 * This method allows classes like QRY_Generator and QRY_Builder to resolve field names
	 * without needing to know the parent SObjectType.
	 *
	 * @param field The SObjectField token to describe.
	 *
	 * @return The cached `DescribeFieldResult` for the field, or null if the field is null.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String fieldName = UTIL_SObjectDescribe.getCachedFieldDescribe(Account.Name)?.getName();
	 * System.debug(fieldName); // Outputs: Name
	 * ```
	 */
	global static DescribeFieldResult getCachedFieldDescribe(SObjectField field)
	{
		DescribeFieldResult result;

		if(field != null)
		{
			result = globalFieldDescribes.get(field);

			if(result == null)
			{
				result = field.getDescribe();
				globalFieldDescribes.put(field, result);
			}
		}

		return result;
	}

	/**
	 * @description Static convenience method to get a field's API name directly from an SObjectField token.
	 * Uses the global field describe cache for efficiency. This is the preferred method when you only
	 * need the field name and don't require the full DescribeFieldResult.
	 *
	 * @param field The SObjectField token to get the name for.
	 *
	 * @return The field's API name, or null if the field is null.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String fieldName = UTIL_SObjectDescribe.getCachedFieldName(Account.Name);
	 * System.debug(fieldName); // Outputs: Name
	 * ```
	 */
	global static String getCachedFieldName(SObjectField field)
	{
		return getCachedFieldDescribe(field)?.name;
	}

	/**
	 * @description Private constructor that initializes the describe instance and caches it.
	 *
	 * @param objectType The SObjectType to describe.
	 */
	private UTIL_SObjectDescribe(SObjectType objectType)
	{
		this.objectType = objectType;
		describeCache.put(String.valueOf(objectType), this);
	}

	/**
	 * @description Returns the `SObjectType` this instance is based on, useful for retrieving metadata about the specific object.
	 *
	 * @return The `SObjectType` of the described object.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe('Account');
	 * SObjectType objType = describe.getSObjectType();
	 * System.debug(objType); // Outputs: Account
	 * ```
	 */
	global SObjectType getSObjectType()
	{
		return objectType;
	}

	/**
	 * @description Retrieves an `SObjectField` by name, with namespace handling enabled by default.
	 *
	 * @param name The API name of the field to retrieve.
	 *
	 * @return The `SObjectField` corresponding to the provided name, or null if not found.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe('Contact');
	 * SObjectField field = describe.getField('LastName');
	 * System.debug(field.getDescribe().getLabel()); // Outputs: Last Name
	 * ```
	 */
	global SObjectField getField(String name)
	{
		return getField(name, true);
	}

	/**
	 * @description Retrieves an `SObjectField` by name, handling relationship notation (e.g., 'Account' vs. 'AccountId') and optional namespace prefixing.
	 *
	 * @param fieldName The API name of the field to retrieve.
	 * @param implyNamespace Whether to automatically handle namespace prefixes.
	 *
	 * @return The `SObjectField` corresponding to the provided name, or null if not found.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe('Contact');
	 * SObjectField field = describe.getField('Account', false);
	 * System.debug(field?.getDescribe().name); // Outputs: AccountId
	 * ```
	 */
	global SObjectField getField(String fieldName, Boolean implyNamespace)
	{
		SObjectField result;

		if(String.isNotBlank(fieldName))
		{
			// Resolve custom field cross-object (__r) syntax
			result = wrappedFields.get((fieldName.endsWithIgnoreCase(RELATIONSHIP_SUFFIX) ?
					(fieldName.removeEndIgnoreCase(RELATIONSHIP_SUFFIX) + CUSTOM_FIELD_SUFFIX) : fieldName), implyNamespace);

			result = result ?? wrappedFields.get(fieldName + 'Id', implyNamespace);
		}

		return result;
	}

	/**
	 * @description Retrieves a cached `DescribeFieldResult` for the given field name.
	 * This method provides significant performance benefits when repeatedly accessing field metadata,
	 * as it caches the describe result after the first call.
	 *
	 * @param fieldName The API name of the field to describe.
	 *
	 * @return The `DescribeFieldResult` for the field, or null if the field doesn't exist.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe('Account');
	 * DescribeFieldResult fieldDescribe = describe.getFieldDescribe('Name');
	 * System.debug(fieldDescribe.getLabel()); // Outputs: Account Name
	 * ```
	 */
	global DescribeFieldResult getFieldDescribe(String fieldName)
	{
		// Delegate to SObjectField version - getField handles case-insensitivity and namespace resolution
		return getFieldDescribe(getField(fieldName));
	}

	/**
	 * @description Retrieves a cached `DescribeFieldResult` for the given `SObjectField` token.
	 * This overload accepts an `SObjectField` directly, providing type safety and avoiding string lookups.
	 * Delegates to the static `getCachedFieldDescribe` method to ensure both instance-based and
	 * static-based lookups share the same global cache.
	 *
	 * @param field The `SObjectField` token to describe.
	 *
	 * @return The `DescribeFieldResult` for the field, or null if the field is null.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe('Account');
	 * DescribeFieldResult fieldDescribe = describe.getFieldDescribe(Account.Name);
	 * System.debug(fieldDescribe.getLabel()); // Outputs: Account Name
	 * ```
	 */
	global DescribeFieldResult getFieldDescribe(SObjectField field)
	{
		// Delegate to static method to ensure unified caching
		return getCachedFieldDescribe(field);
	}

	/**
	 * @description Retrieves the API name for the given `SObjectField` token.
	 * Delegates to the static `getCachedFieldName` method to ensure both instance-based and
	 * static-based lookups share the same global cache.
	 *
	 * @param field The `SObjectField` token to get the name for.
	 *
	 * @return The field's API name, or null if the field is null.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe('Account');
	 * String fieldName = describe.getFieldName(Account.Name);
	 * System.debug(fieldName); // Outputs: Name
	 * ```
	 */
	global String getFieldName(SObjectField field)
	{
		return getCachedFieldName(field);
	}

	/**
	 * @description Retrieves the name field of the SObject (where `isNameField()` is true).
	 *
	 * @return The `SObjectField` where `isNameField()` is true, or null if no such field exists.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe('Account');
	 * SObjectField nameField = describe.getNameField();
	 * System.debug(nameField.getDescribe().name); // Outputs: Name
	 * ```
	 */
	global SObjectField getNameField()
	{
		if(nameField == null)
		{
			for(SObjectField field : wrappedFields.values())
			{
				if(getFieldDescribe(field).nameField)
				{
					nameField = field;
					break;
				}
			}
		}

		return nameField;
	}

	/**
	 * @description Retrieves the raw `DescribeSObjectResult` for the described object.
	 *
	 * @return The `DescribeSObjectResult` containing detailed metadata for the object.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe('Account');
	 * DescribeSObjectResult result = describe.getDescribe();
	 * System.debug(result.getLabel()); // Outputs: Account
	 * ```
	 */
	global DescribeSObjectResult getDescribe()
	{
		return describe;
	}

	/**
	 * @description Retrieves a map of field API names to `SObjectField` instances. Use `getFields()` for namespace handling.
	 *
	 * @return A map of field API names to `SObjectField` instances.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe('Account');
	 * Map<String, SObjectField> fieldMap = describe.getFieldsMap();
	 * System.debug(fieldMap.keySet().size()); // Outputs: Number of fields on Account
	 * ```
	 */
	global Map<String, SObjectField> getFieldsMap()
	{
		return fields;
	}

	/**
	 * @description Retrieves a wrapped map of fields with namespace handling for the described object.
	 *
	 * @return A `FieldsMap` containing the fields of the described object.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe('Account');
	 * UTIL_SObjectDescribe.FieldsMap fields = describe.getFields();
	 * System.debug(fields.get('Name')?.getDescribe().getLabel()); // Outputs: Name
	 * ```
	 */
	global FieldsMap getFields()
	{
		return wrappedFields;
	}

	/**
	 * @description Retrieves a map of field set names to `FieldSet` objects for the described object.
	 *
	 * @return A map of field set names to `FieldSet` objects.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe('Account');
	 * Map<String, FieldSet> fieldSets = describe.getFieldSetsMap();
	 * System.debug(fieldSets.keySet()); // Outputs: Set of field set names
	 * ```
	 */
	global Map<String, FieldSet> getFieldSetsMap()
	{
		return fieldSets;
	}

	/**
	 * @description Returns field names that are safe to include in SOQL SELECT clauses.
	 * Lazily populated from fieldMetadataMap on first access.
	 *
	 * @return A clone of the cached queryable field names (original case).
	 */
	public Set<String> getQueryableFieldNames()
	{
		return queryableFieldNamesCache.clone();
	}

	/**
	 * @description Returns lookup field names that are safe to traverse in nested SELECT * queries.
	 * Lazily populated from fieldMetadataMap on first access.
	 *
	 * @return A clone of the cached traversable reference field names (lowercase).
	 */
	public Set<String> getTraversableReferenceFields()
	{
		return traversableReferenceFieldsCache.clone();
	}

	/**
	 * @description Returns field names that require a value for DML insert operations.
	 * Lazily populated from fieldMetadataMap on first access.
	 *
	 * @return A clone of the cached required field names (lowercase).
	 */
	public Set<String> getCreatableRequiredFields()
	{
		return creatableRequiredFieldsCache.clone();
	}

	/**
	 * @description Returns a map of field names to their relationship names.
	 * Lazily populated from fieldMetadataMap on first access.
	 *
	 * @return A clone of the cached relationship field map.
	 */
	public Map<String, String> getRelationshipFieldMap()
	{
		return relationshipFieldMapCache.clone();
	}

	/**
	 * @description Returns a map of relationship names to their SObjectField tokens.
	 * Lazily populated from fieldMetadataMap on first access.
	 *
	 * @return A clone of the cached reference field map.
	 */
	public Map<String, SObjectField> getReferenceFieldMap()
	{
		return referenceFieldMapCache.clone();
	}

	/**
	 * @description Returns the full map of field metadata for all fields on this object.
	 *
	 * @return A clone of the fieldMetadataMap.
	 */
	public Map<String, FieldMetadata> getFieldMetadataMap()
	{
		return fieldMetadataMap.clone();
	}

	/**
	 * @description Builds display metadata — field label, DisplayType enum name, and (for lookups) the
	 * related object's API name — for a specific list of fields on the given SObject. Shared internally by
	 * the package's Lightning controllers; not part of the global API surface.
	 *
	 * @param objectName The SObject API name.
	 * @param fieldList The field API names to inspect.
	 *
	 * @return Map keyed by field API name to its display metadata, or `null` when `objectName` is blank.
	 */
	public static Map<String, DTO_FieldInformation> getFieldInformation(String objectName, List<String> fieldList)
	{
		return getFieldInformation(objectName, fieldList, null, false);
	}

	/**
	 * @description Builds display metadata for a specific list of fields, restricted to a set of
	 * `DisplayType`s. See the four-argument overload — this is that overload with system-managed fields
	 * included.
	 *
	 * @param objectName The SObject API name.
	 * @param fieldList The field API names to inspect.
	 * @param allowedTypes The `DisplayType`s to include, or `null` to include every field.
	 *
	 * @return Map keyed by field API name to its display metadata, or `null` when `objectName` is blank.
	 */
	public static Map<String, DTO_FieldInformation> getFieldInformation(String objectName, List<String> fieldList, Set<DisplayType> allowedTypes)
	{
		return getFieldInformation(objectName, fieldList, allowedTypes, false);
	}

	/**
	 * @description Builds display metadata — field label, DisplayType enum name, and (for lookups) the
	 * related object's API name — for a specific list of fields, optionally restricted to a set of
	 * `DisplayType`s and optionally excluding system-managed read-only fields. When `allowedTypes` is
	 * non-null, a field whose type is not in the set is skipped *before* its DTO (and, for a lookup, its
	 * related-object describe) is built, so a caller that only handles certain field types never pays to
	 * construct — then discard — metadata for the rest. When `excludeSystemManagedFields` is true, formula
	 * and roll-up summary fields (`isCalculated`) and auto-number fields (`isAutoNumber`) are skipped too —
	 * fields Salesforce computes or assigns under the hood and that no caller can write. Field-level
	 * security is deliberately NOT consulted, so the result does not vary with the running user's edit
	 * permissions. Shared internally by the package's Lightning controllers; not part of the global API
	 * surface.
	 *
	 * @param objectName The SObject API name.
	 * @param fieldList The field API names to inspect.
	 * @param allowedTypes The `DisplayType`s to include, or `null` to include every field.
	 * @param excludeSystemManagedFields When true, skip formula / roll-up / auto-number system-managed
	 * read-only fields.
	 *
	 * @return Map keyed by field API name to its display metadata, or `null` when `objectName` is blank.
	 */
	public static Map<String, DTO_FieldInformation> getFieldInformation(String objectName, List<String> fieldList, Set<DisplayType> allowedTypes, Boolean excludeSystemManagedFields)
	{
		if(String.isBlank(objectName))
		{
			return null;
		}

		Map<String, SObjectField> fieldTokensByName = getDescribe(objectName).getFieldsMap();
		Map<String, DTO_FieldInformation> result = new Map<String, DTO_FieldInformation>();

		for(String apiName : fieldList)
		{
			SObjectField token = fieldTokensByName.get(apiName.toLowerCase());

			if(token == null)
			{
				continue;
			}

			DescribeFieldResult fieldDescribe = getCachedFieldDescribe(token);

			if(allowedTypes != null && !allowedTypes.contains(fieldDescribe.type))
			{
				continue;
			}

			if(excludeSystemManagedFields && (fieldDescribe.isCalculated() || fieldDescribe.isAutoNumber()))
			{
				continue;
			}

			DTO_FieldInformation field = new DTO_FieldInformation();
			field.fieldLabel = fieldDescribe.label;
			field.fieldType = fieldDescribe.type.name();
			field.lookupObjectApiName = fieldDescribe.type == DisplayType.REFERENCE ? fieldDescribe.referenceTo.iterator().next().getDescribe().name : null;

			result.put(fieldDescribe.name, field);
		}

		return result;
	}

	/**
	 * @description Builds display metadata for every field on the given SObject. Shared internally by the
	 * package's Lightning controllers; not part of the global API surface.
	 *
	 * @param objectName The SObject API name.
	 *
	 * @return Map keyed by field API name to its display metadata, or `null` when `objectName` is blank.
	 */
	public static Map<String, DTO_FieldInformation> getAllFieldInformation(String objectName)
	{
		return getAllFieldInformation(objectName, null, false);
	}

	/**
	 * @description Builds display metadata for every field on the given SObject whose `DisplayType` is in
	 * `allowedTypes` (or every field when `allowedTypes` is `null`). See the three-argument overload —
	 * this is that overload with system-managed fields included.
	 *
	 * @param objectName The SObject API name.
	 * @param allowedTypes The `DisplayType`s to include, or `null` to include every field.
	 *
	 * @return Map keyed by field API name to its display metadata, or `null` when `objectName` is blank.
	 */
	public static Map<String, DTO_FieldInformation> getAllFieldInformation(String objectName, Set<DisplayType> allowedTypes)
	{
		return getAllFieldInformation(objectName, allowedTypes, false);
	}

	/**
	 * @description Builds display metadata for every field on the given SObject whose `DisplayType` is in
	 * `allowedTypes` (or every field when `allowedTypes` is `null`), optionally excluding system-managed
	 * read-only fields. Lets a caller that only handles certain writable field types — for example the
	 * masking advisor, which can only mask text-shaped fields the framework can write — avoid building
	 * metadata for fields it would immediately discard (formula, roll-up summary, and auto-number fields
	 * are skipped when `excludeSystemManagedFields` is true). Field-level security is not consulted.
	 * Shared internally by the package's Lightning controllers; not part of the global API surface.
	 *
	 * @param objectName The SObject API name.
	 * @param allowedTypes The `DisplayType`s to include, or `null` to include every field.
	 * @param excludeSystemManagedFields When true, skip formula / roll-up / auto-number system-managed
	 * read-only fields.
	 *
	 * @return Map keyed by field API name to its display metadata, or `null` when `objectName` is blank.
	 */
	public static Map<String, DTO_FieldInformation> getAllFieldInformation(String objectName, Set<DisplayType> allowedTypes, Boolean excludeSystemManagedFields)
	{
		return getFieldInformation(objectName, new List<String>(getDescribe(objectName).getFieldsMap().keySet()), allowedTypes, excludeSystemManagedFields);
	}

	/**
	 * @description Display metadata for a single SObject field, surfaced to Lightning components for dynamic
	 * form rendering.
	 */
	public class DTO_FieldInformation
	{
		/**
		 * @description The user-facing label of the field.
		 */
		@AuraEnabled
		public String fieldLabel;

		/**
		 * @description The DisplayType enum name (e.g., STRING, REFERENCE, PICKLIST).
		 */
		@AuraEnabled
		public String fieldType;

		/**
		 * @description For lookup/master-detail fields, the API name of the related object.
		 */
		@AuraEnabled
		public String lookupObjectApiName;
	}

	/**
	 * @description Returns the field metadata for a specific field by name.
	 *
	 * @param fieldName The API name of the field (case-insensitive).
	 *
	 * @return The FieldMetadata for the field, or null if not found.
	 */
	public FieldMetadata getFieldMetadata(String fieldName)
	{
		return String.isNotBlank(fieldName) ? fieldMetadataMap.get(fieldName.toLowerCase()) : null;
	}

	/**
	 * @description Retrieves a cached map of global `SObjectType` names to `SObjectType` instances.
	 *
	 * @return A map of `SObjectType` names to `SObjectType` instances.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Map<String, SObjectType> globalDescribe = UTIL_SObjectDescribe.getRawGlobalDescribe();
	 * System.debug(globalDescribe.containsKey('Account')); // Outputs: true
	 * ```
	 */
	global static Map<String, SObjectType> getRawGlobalDescribe()
	{
		return rawGlobalDescribe;
	}

	/**
	 * @description Retrieves a wrapped map of global `SObjectType` names to `SObjectType` instances with namespace handling.
	 *
	 * @return A `GlobalDescribeMap` containing global `SObjectType` data.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_SObjectDescribe.GlobalDescribeMap globalDescribe = UTIL_SObjectDescribe.getGlobalDescribe();
	 * System.debug(globalDescribe.get('Account')?.getDescribe().getLabel()); // Outputs: Account
	 * ```
	 */
	global static GlobalDescribeMap getGlobalDescribe()
	{
		return wrappedGlobalDescribe;
	}

	/**
	 * @description Clears the cache of global describe and SObject describe instances to free heap space.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_SObjectDescribe.flushCache();
	 * System.debug(UTIL_SObjectDescribe.getDescribe('Account')); // Forces new describe instance
	 * ```
	 */
	global static void flushCache()
	{
		rawGlobalDescribe = null;
		describeCache = null;
		globalFieldDescribes.clear();
	}

	/**
	 * @description Determines whether Person Accounts are enabled by checking for the `isPersonAccount` field on Account.
	 *
	 * @return `true` if Person Accounts are enabled, `false` otherwise.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Boolean isPersonAccountEnabled = UTIL_SObjectDescribe.isPersonAccountEnabled();
	 * System.debug(isPersonAccountEnabled); // Outputs: true or false based on org configuration
	 * ```
	 */
	global static Boolean isPersonAccountEnabled()
	{
		return getDescribe(Account.SObjectType).fields.containsKey(FIELD_IS_PERSON_ACCOUNT);
	}

	/**
	 * @description Retrieves a cached `UTIL_SObjectDescribe` instance for the specified SObject name.
	 *
	 * @param sObjectName The API name of the SObject.
	 *
	 * @return A `UTIL_SObjectDescribe` instance, or null if the SObject name is invalid.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe('Account');
	 * System.debug(describe.getSObjectType()); // Outputs: Account
	 * ```
	 */
	global static UTIL_SObjectDescribe getDescribe(String sObjectName)
	{
		UTIL_SObjectDescribe objectDescribe;

		if(String.isNotBlank(sObjectName))
		{
			objectDescribe = (UTIL_SObjectDescribe)describeCache.get(sObjectName);

			if(objectDescribe == null)
			{
				Type objectType = Type.forName(sObjectName);
				SObjectType sObjectType = ((SObject)objectType?.newInstance())?.getSObjectType();
				objectDescribe = sObjectType == null ? null : new UTIL_SObjectDescribe(sObjectType);
			}
		}

		return objectDescribe;
	}

	/**
	 * @description Retrieves a cached `UTIL_SObjectDescribe` instance for the specified SObject type.
	 *
	 * @param objectType The SObject type.
	 *
	 * @return A `UTIL_SObjectDescribe` instance, or null if the object type is null.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe(Account.SObjectType);
	 * System.debug(describe.getDescribe().name); // Outputs: Account
	 * ```
	 */
	global static UTIL_SObjectDescribe getDescribe(SObjectType objectType)
	{
		UTIL_SObjectDescribe objectDescribe;

		if(objectType != null)
		{
			objectDescribe = (UTIL_SObjectDescribe)describeCache.get(String.valueOf(objectType));
		}

		return objectDescribe == null & objectType != null ? new UTIL_SObjectDescribe(objectType) : objectDescribe;
	}

	/**
	 * @description Retrieves a cached `UTIL_SObjectDescribe` instance for the specified `DescribeSObjectResult`.
	 *
	 * @param describeResult The `DescribeSObjectResult` for the SObject.
	 *
	 * @return A `UTIL_SObjectDescribe` instance, or null if the describe result is null.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DescribeSObjectResult result = Account.SObjectType.getDescribe();
	 * UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe(result);
	 * System.debug(describe.getSObjectType()); // Outputs: Account
	 * ```
	 */
	global static UTIL_SObjectDescribe getDescribe(DescribeSObjectResult describeResult)
	{
		UTIL_SObjectDescribe result;

		if(describeResult != null)
		{
			result = (UTIL_SObjectDescribe)describeCache.get(describeResult.name);
			result = result ?? new UTIL_SObjectDescribe(describeResult.SObjectType);
		}

		return result;
	}

	/**
	 * @description Retrieves a cached `UTIL_SObjectDescribe` instance for the specified SObject instance.
	 *
	 * @param instance The SObject instance.
	 *
	 * @return A `UTIL_SObjectDescribe` instance, or null if the instance is null.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Account acc = new Account();
	 * UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe(acc);
	 * System.debug(describe.getNameField().getDescribe().name); // Outputs: Name
	 * ```
	 */
	global static UTIL_SObjectDescribe getDescribe(SObject instance)
	{
		return getDescribe(instance?.getSObjectType());
	}

	/**
	 * @description Will get the API name for the SObject given a specific type. Uses a describe cache
	 *
	 * @param objectType The object type for which to get the name
	 *
	 * @return The Name of the object
	 *
	 * @see UTIL_SObjectDescribe.getDescribe
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String result = UTIL_SObjectDescribe.getObjectNameFromType(Account.SObjectType);
	 * ```
	 */
	global static String getObjectNameFromType(SObjectType objectType)
	{
		return UTIL_SObjectDescribe.getDescribe(objectType)?.getDescribe().name;
	}

	/**
	 * @description Retrieves the default picklist value for a given SObject field.
	 *
	 * @param objectField The SObject field to retrieve a picklist value for.
	 *
	 * @return The default picklist value, or null if no default is available.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String picklistValue = UTIL_SObjectDescribe.getDefaultPicklistValue(Foobar__c.Picklist__c);
	 * ```
	 */
	global static String getDefaultPicklistValue(SObjectField objectField)
	{
		return getDefaultPicklistValue(objectField, false);
	}

	/**
	 * @description Retrieves the default picklist value for a given SObject field.
	 *
	 * @param objectField The SObject field to retrieve a picklist value for.
	 * @param returnFirstEntryIfNoDefault If no default is found, return the first entry if available.
	 *
	 * @return The default picklist value, or null if no default (or first entry) is available.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String picklistValue = UTIL_SObjectDescribe.getDefaultPicklistValue(Foobar__c.Picklist__c, true);
	 * ```
	 */
	global static String getDefaultPicklistValue(SObjectField objectField, Boolean returnFirstEntryIfNoDefault)
	{
		return getDefaultPicklistValue(getCachedFieldDescribe(objectField), returnFirstEntryIfNoDefault);
	}

	/**
	 * @description Retrieves the default picklist value for a given field describe.
	 *
	 * @param fieldDescribe The DescribeFieldResult to retrieve a picklist value for.
	 *
	 * @return The default picklist value, or null if no default is available.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String picklistValue = UTIL_SObjectDescribe.getDefaultPicklistValue(Foobar__c.Picklist__c.getDescribe());
	 * ```
	 */
	global static String getDefaultPicklistValue(DescribeFieldResult fieldDescribe)
	{
		return getDefaultPicklistValue(fieldDescribe, false);
	}

	/**
	 * @description Retrieves the default picklist value for a given field describe.
	 *
	 * @param fieldDescribe The DescribeFieldResult to retrieve a picklist value for.
	 * @param returnFirstEntryIfNoDefault If no default is found, return the first entry if available.
	 *
	 * @return The default picklist value, or null if no default (or first entry) is available.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String picklistValue = UTIL_SObjectDescribe.getDefaultPicklistValue(Foobar__c.Picklist__c.getDescribe(), true);
	 * ```
	 */
	global static String getDefaultPicklistValue(DescribeFieldResult fieldDescribe, Boolean returnFirstEntryIfNoDefault)
	{
		String picklistValue;

		switch on fieldDescribe?.type
		{
			when PICKLIST, MULTIPICKLIST
			{
				List<PicklistEntry> entries = fieldDescribe.picklistValues;

				for(PicklistEntry entry : entries)
				{
					if(entry.isDefaultValue())
					{
						picklistValue = entry.value;
						break;
					}
				}

				if(returnFirstEntryIfNoDefault && String.isBlank(picklistValue) && !entries.isEmpty())
				{
					picklistValue = entries.iterator().next().value;
				}
			}
		}

		return picklistValue;
	}

	/**
	 * @description Retrieves the Id of the default record type for an SObject.
	 *
	 * @param objectType The SObject type.
	 *
	 * @return The Id of the default record type, or null if not found.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Id recordTypeId = UTIL_SObjectDescribe.getDefaultRecordType(Account.SObjectType);
	 * ```
	 */
	global static Id getDefaultRecordType(SObjectType objectType)
	{
		Id recordTypeId;

		if(objectType != null)
		{
			for(RecordTypeInfo foundInfo : UTIL_SObjectDescribe.getDescribe(objectType).getDescribe().recordTypeInfos)
			{
				if(foundInfo.defaultRecordTypeMapping)
				{
					recordTypeId = foundInfo.recordTypeId;
					break;
				}
			}
		}

		return recordTypeId;
	}

	/**
	 * @description Retrieves the Id of a record type for an SObject by its developer name.
	 *
	 * @param objectType The SObject type.
	 * @param recordTypeName The developer name of the record type.
	 *
	 * @return The Id of the record type, or null if not found.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Id recordTypeId = UTIL_SObjectDescribe.getRecordTypeByDeveloperName(Account.SObjectType, 'Customer');
	 * ```
	 */
	global static Id getRecordTypeByDeveloperName(SObjectType objectType, String recordTypeName)
	{
		return getRecordTypeInfo(objectType, recordTypeName)?.recordTypeId;
	}

	/**
	 * @description Reports whether a record type, identified by its developer name, is available to the
	 * running user for the given SObject. A record type is available only when it exists, is active, and
	 * is assigned to the running user's profile or a permission set. Check this before stamping a
	 * RecordTypeId so an insert does not fail with INVALID_CROSS_REFERENCE_KEY when the type is not
	 * assigned to the running user — for example a packaged record type that a subscriber has not
	 * assigned to the profile the code runs under.
	 *
	 * @param objectType The SObject type.
	 * @param recordTypeName The developer name of the record type.
	 *
	 * @return true when the record type exists and is available to the running user; false otherwise.
	 *
	 * @since 1.1
	 *
	 * @example
	 * ```apex
	 * if(UTIL_SObjectDescribe.isRecordTypeAvailable(Account.SObjectType, 'Customer'))
	 * {
	 *     account.RecordTypeId = UTIL_SObjectDescribe.getRecordTypeByDeveloperName(Account.SObjectType, 'Customer');
	 * }
	 * ```
	 */
	global static Boolean isRecordTypeAvailable(SObjectType objectType, String recordTypeName)
	{
		RecordTypeInfo recordTypeInfo = getRecordTypeInfo(objectType, recordTypeName);

		return recordTypeInfo != null && recordTypeInfo.isAvailable();
	}

	/**
	 * @description Retrieves the record type information for an SObject by its developer name.
	 *
	 * @param objectType The SObject type.
	 * @param recordTypeName The developer name of the record type.
	 *
	 * @return The RecordTypeInfo, or null if not found.
	 */
	private static RecordTypeInfo getRecordTypeInfo(SObjectType objectType, String recordTypeName)
	{
		return objectType != null && String.isNotBlank(recordTypeName) ?
				UTIL_SObjectDescribe.getDescribe(objectType).getDescribe().recordTypeInfosByDeveloperName.get(recordTypeName) : null;
	}

	/**
	 * @description Returns the SObjectType token for a given record ID.
	 *
	 * @param objectId An Id of an SObject
	 *
	 * @return The SObjectType for the record, or null if the ID is null.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * SObjectType accountType = UTIL_SObjectDescribe.getSObjectTypeById(someAccountId);
	 * ```
	 */
	global static SObjectType getSObjectTypeById(Id objectId)
	{
		return objectId?.getSobjectType();
	}

	/**
	 * @description Returns the API name of an object based on its ID.
	 *
	 * @param objectId An Id of an SObject
	 *
	 * @return The API name of the object, or null if the ID is invalid.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String objectName = UTIL_SObjectDescribe.getObjectNameFromId(recordId); // e.g. 'Account'
	 * ```
	 */
	global static String getObjectNameFromId(Id objectId)
	{
		return getObjectNameFromType(getSObjectTypeById(objectId));
	}

	/**
	 * @description Returns the SObjectType token for a given object API name.
	 *
	 * @param objectApiName The API name of the object
	 *
	 * @return The corresponding SObjectType or null if the API name is invalid.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * SObjectType accountType = UTIL_SObjectDescribe.getSObjectTypeByName('Account');
	 * ```
	 */
	global static SObjectType getSObjectTypeByName(String objectApiName)
	{
		return getDescribe(objectApiName)?.getSObjectType();
	}

	/**
	 * @description Returns a list of picklist entries for a given SObject field reference.
	 *
	 * @param pickField SObject Field reference for the picklist field
	 *
	 * @return List of picklist entries
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<PicklistEntry> entries = UTIL_SObjectDescribe.getPicklistEntries(Account.Industry);
	 * ```
	 */
	global static List<PicklistEntry> getPicklistEntries(SObjectField pickField)
	{
		return getCachedFieldDescribe(pickField)?.picklistValues;
	}

	/**
	 * @description Returns a map of picklist label-to-value pairs for a given SObject field reference.
	 *
	 * @param pickField The Object Field which to retrieve entries
	 *
	 * @return A map of picklist values keyed by label
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Map<String, String> valueByLabel = UTIL_SObjectDescribe.getPicklistEntriesMap(Account.Industry);
	 * ```
	 */
	global static Map<String, String> getPicklistEntriesMap(SObjectField pickField)
	{
		return buildPicklistEntriesMap(getPicklistEntries(pickField), true);
	}

	/**
	 * @description Returns a map of picklist entries with configurable key for a given SObject field reference.
	 *
	 * @param pickField The Object Field for which to retrieve entries
	 * @param useLabelAsKey If true the key will be the picklist label, else it will be the API value
	 *
	 * @return A map of the found items
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Map<String, String> labelByValue = UTIL_SObjectDescribe.getPicklistEntriesMap(Account.Industry, false);
	 * ```
	 */
	global static Map<String, String> getPicklistEntriesMap(SObjectField pickField, Boolean useLabelAsKey)
	{
		return buildPicklistEntriesMap(getPicklistEntries(pickField), useLabelAsKey);
	}

	/**
	 * @description Returns all picklist values for a given object and record type combination,
	 * including dependent picklist relationships. Uses ConnectApi.RecordUi natively.
	 *
	 * @param objectApiName The API name of the SObject
	 * @param recordTypeId The record type ID
	 *
	 * @return The ConnectApi picklist values collection
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * ConnectApi.PicklistValuesCollection collection = UTIL_SObjectDescribe.getPicklistValuesByRecordType('Account', recordTypeId);
	 * ```
	 */
	global static ConnectApi.PicklistValuesCollection getPicklistValuesByRecordType(String objectApiName, Id recordTypeId)
	{
		return ConnectApi.RecordUi.getPicklistValuesByRecordType(objectApiName, recordTypeId);
	}

	/**
	 * @description Returns all picklist values for a given object and record type combination
	 * as a list of DTO_PickList objects, including dependent picklist relationships.
	 * Uses ConnectApi.RecordUi natively and transforms the results into framework DTOs.
	 *
	 * @param objectApiName The API name of the SObject
	 * @param recordTypeId The record type ID
	 *
	 * @return A list of DTO_PickList objects containing picklist names and their values
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<DTO_PickList> pickLists = UTIL_SObjectDescribe.getPicklistValues('Account', recordTypeId);
	 * ```
	 */
	global static List<DTO_PickList> getPicklistValues(String objectApiName, Id recordTypeId)
	{
		ConnectApi.PicklistValuesCollection collection = getPicklistValuesByRecordType(objectApiName, recordTypeId);
		return transformPicklistCollection(collection);
	}

	/**
	 * @description Transforms a ConnectApi.PicklistValuesCollection into a list of DTO_PickList objects.
	 *
	 * @param collection The ConnectApi picklist values collection
	 *
	 * @return A list of DTO_PickList objects
	 */
	@TestVisible
	private static List<DTO_PickList> transformPicklistCollection(ConnectApi.PicklistValuesCollection collection)
	{
		List<DTO_PickList> pickLists = new List<DTO_PickList>();

		if(collection.picklistFieldValues == null)
		{
			return pickLists;
		}

		for(String picklistName : collection.picklistFieldValues.keySet())
		{
			ConnectApi.PicklistValues sourceValues = collection.picklistFieldValues.get(picklistName);
			List<String> controllerValues = buildControllerValueList(sourceValues.controllerValues);

			DTO_PickList dtoPickList = new DTO_PickList();
			dtoPickList.picklistName = picklistName;
			dtoPickList.defaultValue = sourceValues.defaultValue != null
					? transformPicklistValue(sourceValues.defaultValue, controllerValues)
					: null;

			dtoPickList.values = new List<DTO_PicklistValue>();

			for(ConnectApi.PicklistValue sourceValue : sourceValues.values)
			{
				dtoPickList.values.add(transformPicklistValue(sourceValue, controllerValues));
			}

			pickLists.add(dtoPickList);
		}

		return pickLists;
	}

	/**
	 * @description Builds an index-ordered list of controller value labels from the controller values map.
	 * The map keys are controller value labels and values are their indexes.
	 *
	 * @param controllerValuesMap The controller values map from ConnectApi
	 *
	 * @return An ordered list of controller value labels, or null if no controller values exist
	 */
	@TestVisible
	private static List<String> buildControllerValueList(Map<String, Integer> controllerValuesMap)
	{
		if(controllerValuesMap == null || controllerValuesMap.isEmpty())
		{
			return null;
		}

		String[] indexed = new String[controllerValuesMap.size()];

		for(String controllerValue : controllerValuesMap.keySet())
		{
			indexed[controllerValuesMap.get(controllerValue)] = controllerValue;
		}

		return new List<String>(indexed);
	}

	/**
	 * @description Transforms a ConnectApi.PicklistValue into a DTO_PicklistValue.
	 *
	 * @param sourceValue The ConnectApi picklist value
	 * @param controllerValues The ordered list of controller value labels
	 *
	 * @return A transformed DTO_PicklistValue
	 */
	@TestVisible
	private static DTO_PicklistValue transformPicklistValue(ConnectApi.PicklistValue sourceValue, List<String> controllerValues)
	{
		DTO_PicklistValue dtoPicklistValue = new DTO_PicklistValue();

		dtoPicklistValue.label = sourceValue.label;
		dtoPicklistValue.value = sourceValue.value;

		if(controllerValues != null && sourceValue.validFor != null && !sourceValue.validFor.isEmpty())
		{
			dtoPicklistValue.validFor = new List<String>();

			for(Integer validForIndex : sourceValue.validFor)
			{
				dtoPicklistValue.validFor.add(controllerValues[validForIndex]);
			}
		}

		return dtoPicklistValue;
	}

	/**
	 * @description Builds a map of picklist entries with configurable key/value assignment.
	 *
	 * @param entries The picklist entries to map
	 * @param useLabelAsKey If true the key will be the picklist label, else it will be the API value
	 *
	 * @return A map of the found items
	 */
	private static Map<String, String> buildPicklistEntriesMap(List<PicklistEntry> entries, Boolean useLabelAsKey)
	{
		Map<String, String> entriesMap = new Map<String, String>();

		for(PicklistEntry foundEntry : entries)
		{
			String mapKey = useLabelAsKey ? foundEntry.getLabel() : foundEntry.getValue();
			String mapValue = useLabelAsKey ? foundEntry.getValue() : foundEntry.getLabel();

			entriesMap.put(mapKey, mapValue);
		}

		return entriesMap;
	}

	/**
	 * @description Returns the field map for an object by API name.
	 *
	 * @param objectName The name of the object to retrieve fields for
	 *
	 * @return A Map of SObject Fields keyed by field API name
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Map<String, SObjectField> fields = UTIL_SObjectDescribe.getObjectFieldMap('Account');
	 * ```
	 */
	global static Map<String, SObjectField> getObjectFieldMap(String objectName)
	{
		return getObjectFieldMap(getSObjectTypeByName(objectName));
	}

	/**
	 * @description Returns the field map for an object by SObjectType.
	 *
	 * @param objectType The type of the object for which to retrieve a field map
	 *
	 * @return A Map of SObject Fields keyed by field API name
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Map<String, SObjectField> fields = UTIL_SObjectDescribe.getObjectFieldMap(Account.SObjectType);
	 * ```
	 */
	global static Map<String, SObjectField> getObjectFieldMap(SObjectType objectType)
	{
		return getDescribe(objectType).getFieldsMap();
	}

	/**
	 * @description Returns a map of reference (lookup/master-detail) fields keyed by relationship name.
	 *
	 * @param objectName The name of the object to retrieve fields map for
	 *
	 * @return A Map of SObject Fields keyed by relationship name; non-reference fields are excluded
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Map<String, SObjectField> refFields = UTIL_SObjectDescribe.getObjectFieldReferenceMap('Contact');
	 * ```
	 */
	global static Map<String, SObjectField> getObjectFieldReferenceMap(String objectName)
	{
		return getDescribe(objectName).getReferenceFieldMap();
	}

	/**
	 * @description Walks the object tree and returns all fields for related objects (one level deep).
	 *
	 * @param objectName The name of the starting object
	 *
	 * @return A set of fields using multipart dot notation (e.g. Account.Name)
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Set<String> fields = UTIL_SObjectDescribe.getNestableFieldNames('Contact');
	 * ```
	 */
	global static Set<String> getNestableFieldNames(String objectName)
	{
		final Integer defaultNestedLevels = 1;
		return getNestableFieldNames(objectName, defaultNestedLevels);
	}

	/**
	 * @description Walks the object tree and returns all fields for related objects up to the specified depth.
	 *
	 * @param objectName The name of the starting object
	 * @param levels The number of levels to traverse (maximum 5)
	 *
	 * @return A set of fields using multipart dot notation (e.g. Account.Name)
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Set<String> fields = UTIL_SObjectDescribe.getNestableFieldNames('Contact', 2);
	 * ```
	 */
	global static Set<String> getNestableFieldNames(String objectName, Integer levels)
	{
		final Integer defaultStartLevel = 0;
		final Integer maxNestedLevels = 5;
		return getNestableFieldNames(UTIL_String.EMPTY, objectName, Math.min(maxNestedLevels, levels), defaultStartLevel);
	}

	/**
	 * @description Recursive helper that walks the object tree and returns all fields using dot notation.
	 *
	 * @param objectPrefix The prefix to apply to field names for related objects
	 * @param objectName The name of the starting object
	 * @param levels The number of levels to traverse
	 * @param currentLevel The current traversal depth
	 *
	 * @return A set of fields using multipart dot notation
	 */
	private static Set<String> getNestableFieldNames(String objectPrefix, String objectName, Integer levels, Integer currentLevel)
	{
		Set<String> currentLevelFieldNames = new Set<String>();

		if(currentLevel > levels)
		{
			return currentLevelFieldNames;
		}

		currentLevel++;

		UTIL_SObjectDescribe objectDescribe = getDescribe(objectName);
		Set<String> queryableFields = objectDescribe.getQueryableFieldNames();

		for(String fieldName : queryableFields)
		{
			String prefixedFieldName = String.isNotBlank(objectPrefix)
					? objectPrefix + UTIL_String.DOT + fieldName
					: fieldName;

			currentLevelFieldNames.add(prefixedFieldName);
		}

		Map<String, FieldMetadata> metadataMap = objectDescribe.getFieldMetadataMap();

		for(String fieldNameLower : objectDescribe.getTraversableReferenceFields())
		{
			FieldMetadata fieldMetadata = metadataMap.get(fieldNameLower);

			if(fieldMetadata?.relationshipNameOriginalCase != null && fieldMetadata?.referenceToObjectNames?.isEmpty() == false)
			{
				String relationshipPrefix = String.isNotBlank(objectPrefix)
						? objectPrefix + UTIL_String.DOT + fieldMetadata.relationshipNameOriginalCase
						: fieldMetadata.relationshipNameOriginalCase;

				String referencedObjectName = fieldMetadata.referenceToObjectNames.get(0);

				currentLevelFieldNames.addAll(getNestableFieldNames(relationshipPrefix, referencedObjectName, levels, currentLevel));
			}
		}

		return currentLevelFieldNames;
	}

	/**
	 * @description Returns all queryable field names for an object, optionally including record type fields.
	 *
	 * @param objectName The API name of the object
	 * @param includeRecordType Whether to include RecordType relationship fields
	 *
	 * @return A set of field names for the object
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Set<String> fieldNames = UTIL_SObjectDescribe.getAllFieldNames('Account', false);
	 * ```
	 */
	global static Set<String> getAllFieldNames(String objectName, Boolean includeRecordType)
	{
		UTIL_SObjectDescribe objectDescribe = getDescribe(objectName);
		Set<String> fieldNames = objectDescribe.getQueryableFieldNames();

		if(includeRecordType)
		{
			expandRecordTypeFields(fieldNames, objectDescribe);
		}

		return fieldNames;
	}

	/**
	 * @description Returns all queryable field names for an object by SObjectType (includes record type fields).
	 *
	 * @param objectType The SObjectType
	 *
	 * @return A set of field names for the object
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Set<String> fieldNames = UTIL_SObjectDescribe.getAllFieldNames(Account.SObjectType);
	 * ```
	 */
	global static Set<String> getAllFieldNames(SObjectType objectType)
	{
		return getAllFieldNames(getObjectNameFromType(objectType));
	}

	/**
	 * @description Returns all queryable field names for an object by API name (includes record type fields).
	 *
	 * @param objectName The API name of the object
	 *
	 * @return A set of field names for the object
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Set<String> fieldNames = UTIL_SObjectDescribe.getAllFieldNames('Account');
	 * ```
	 */
	global static Set<String> getAllFieldNames(String objectName)
	{
		return getAllFieldNames(objectName, true);
	}

	/**
	 * @description Filters a set of field names, returning only those that are valid for the given object.
	 *
	 * @param objectName The API name of the object
	 * @param fieldNames The field names to check
	 *
	 * @return A set containing only the valid field names
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Set<String> fields = new Set<String>{ 'Name', 'InvalidField__c', 'Industry' };
	 * Set<String> validFields = UTIL_SObjectDescribe.extractValidObjectFieldNames('Account', fields);
	 * ```
	 */
	global static Set<String> extractValidObjectFieldNames(String objectName, Set<String> fieldNames)
	{
		Set<String> validFieldNames = new Set<String>();

		SObjectType objectType = getSObjectTypeByName(objectName);

		if(objectType != null && fieldNames?.isEmpty() == false)
		{
			Boolean isValid;

			for(String fieldName : fieldNames)
			{
				List<String> fieldNameParts = UTIL_String.splitByWholeSeparator(fieldName, UTIL_String.DOT);

				Boolean isMultipartReference = fieldNameParts.size() > 1;

				String objectNameToUse = objectName;

				for(Integer i = 0; i < fieldNameParts.size(); i++)
				{
					String fieldPart = fieldNameParts[i];

					Map<String, SObjectField> fieldMap = getObjectFieldMap(objectNameToUse);

					String fieldNameToUse = fieldPart;

					if(isMultipartReference && i < fieldNameParts.size() - 1 && String.isNotBlank(fieldPart))
					{
						if(fieldPart.endsWith(RELATIONSHIP_SUFFIX))
						{
							fieldNameToUse = fieldNameToUse.replace(RELATIONSHIP_SUFFIX, CUSTOM_FIELD_SUFFIX);
						}
						else
						{
							fieldNameToUse = fieldNameToUse + 'Id';
						}
					}

					SObjectField objectField = fieldMap.get(fieldNameToUse.toLowerCase());

					isValid = String.isBlank(fieldNameToUse) || fieldMap == null ? false : objectField != null;

					if(!isValid)
					{
						break;
					}

					DescribeFieldResult describe = getCachedFieldDescribe(objectField);

					objectNameToUse = !describe.namePointing && !describe.referenceTo.isEmpty()
							? getObjectNameFromType(describe.referenceTo.iterator().next())
							: fieldPart;
				}

				if(isValid == true)
				{
					validFieldNames.add(fieldName);
				}
			}
		}

		return validFieldNames;
	}

	/**
	 * @description Converts a set of SObjectField tokens to their API name strings.
	 *
	 * @param objectFields The fields for which to get field names
	 *
	 * @return A set of SObject field API names
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Set<SObjectField> fields = new Set<SObjectField>{ Account.Name, Account.Industry };
	 * Set<String> names = UTIL_SObjectDescribe.getSObjectFieldNames(fields); // {'Name', 'Industry'}
	 * ```
	 */
	global static Set<String> getSObjectFieldNames(Set<SObjectField> objectFields)
	{
		Set<String> fieldNames = new Set<String>();

		for(SObjectField objectField : objectFields)
		{
			String fieldName = getCachedFieldName(objectField);

			if(String.isNotBlank(fieldName))
			{
				fieldNames.add(fieldName);
			}
		}

		return fieldNames;
	}

	/**
	 * @description Expands RecordType lookup fields to include RecordType's queryable fields.
	 *
	 * @param fieldNames The set of field names to expand (modified in place)
	 * @param objectDescribe The describe instance for the object
	 */
	private static void expandRecordTypeFields(Set<String> fieldNames, UTIL_SObjectDescribe objectDescribe)
	{
		Map<String, FieldMetadata> metadataMap = objectDescribe.getFieldMetadataMap();

		for(FieldMetadata fieldMetadata : metadataMap.values())
		{
			if(fieldMetadata?.relationshipNameOriginalCase != null && fieldMetadata?.referenceToObjectNames?.isEmpty() == false)
			{
				String referencedObjectName = fieldMetadata.referenceToObjectNames.get(0);

				if(SEL_RecordType.OBJECT_NAME.equalsIgnoreCase(referencedObjectName))
				{
					Set<String> recordTypeFields = getDescribe(referencedObjectName).getQueryableFieldNames();

					for(String recordTypeField : recordTypeFields)
					{
						fieldNames.add(fieldMetadata.relationshipNameOriginalCase + UTIL_String.DOT + recordTypeField);
					}
				}
			}
		}
	}

	/**
	 * @description Builds a comma-separated field list from SObjectField tokens and optional FieldSet definitions.
	 *
	 * @since 1.0
	 */
	global inherited sharing class FieldListBuilder extends UTIL_String.DelimitedListBuilder
	{
		/**
		 * @description Initializes a FieldListBuilder with a list of SObjectField tokens.
		 *
		 * @param objectFields A list of SObject fields to initialize the builder.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_SObjectDescribe.FieldListBuilder builder = new UTIL_SObjectDescribe.FieldListBuilder(new List<SObjectField>{Account.Name});
		 * ```
		 */
		global FieldListBuilder(List<SObjectField> objectFields)
		{
			this(objectFields, null);
		}

		/**
		 * @description Initializes a FieldListBuilder with fields and optional FieldSets.
		 *
		 * @param objectFields A list of SObject fields.
		 * @param fieldSets A list of FieldSets for concatenation.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_SObjectDescribe.FieldListBuilder builder = new UTIL_SObjectDescribe.FieldListBuilder(new List<SObjectField>{Account.Name}, new List<FieldSet>());
		 * ```
		 */
		global FieldListBuilder(List<SObjectField> objectFields, List<FieldSet> fieldSets)
		{
			for(SObjectField objectField : objectFields)
			{
				add(getCachedFieldName(objectField));
			}

			if(fieldSets?.isEmpty() == false)
			{
				for(FieldSet fieldSet : fieldSets)
				{
					for(FieldSetMember fieldSetMember : fieldSet.fields)
					{
						add(fieldSetMember.fieldPath);
					}
				}
			}
		}
	}

	/**
	 * @description Abstract base class for handling namespace-aware maps of SObject attributes, such as fields or global describe data.
	 * This class is intentionally `private` to maintain managed package compatibility - making it `global` would change
	 * the external inheritance hierarchy of already-released `FieldsMap` and `GlobalDescribeMap` classes.
	 */
	private abstract class NamespacedAttributeMap
	{
		/**
		 * @description The current namespace prefix, derived from this class's package namespace.
		 */
		@TestVisible
		protected String currentNamespace;

		/**
		 * @description Cached namespace prefix with double underscore suffix for map key lookups.
		 * Pre-computed to avoid repeated string concatenation in hot paths.
		 */
		@TestVisible
		protected String namespacePrefix;

		/**
		 * @description The underlying map of attribute names to values.
		 */
		protected Map<String, Object> values;

		/**
		 * @description Constructs a new NamespacedAttributeMap with the given values map.
		 *
		 * @param values The map of attribute names to values.
		 */
		protected NamespacedAttributeMap(Map<String, Object> values)
		{
			currentNamespace = UTIL_System.getManagedPackageNamespace().toLowerCase();
			namespacePrefix = UTIL_System.getManagedPackageNamespacePrefix().toLowerCase();
			this.values = values;
		}

		/**
		 * @description Retrieves an object from the map with optional namespace handling.
		 *
		 * @param name The key to retrieve.
		 * @param implyNamespace Whether to handle namespace prefixes.
		 *
		 * @return The object associated with the key, or null if not found.
		 */
		protected virtual Object getObject(String name, Boolean implyNamespace)
		{
			Object returnObject = null;

			if(String.isNotBlank(name))
			{
				String preferredValue = ((implyNamespace ? namespacePrefix : UTIL_String.EMPTY) + name).toLowerCase();

				returnObject = values.get(preferredValue);
				returnObject = returnObject == null && implyNamespace == true ? values.get(name.toLowerCase()) : returnObject;
			}

			return returnObject;
		}

		/**
		 * @description Checks if the map contains a key with namespace handling enabled by default.
		 *
		 * @param name The key to check.
		 *
		 * @return `true` if the key exists, `false` otherwise.
		 *
		 * @example
		 * ```apex
		 * UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe('Account');
		 * Boolean hasField = describe.getFields().containsKey('Name');
		 * System.debug(hasField); // Outputs: true
		 * ```
		 */
		public virtual Boolean containsKey(String name)
		{
			return containsKey(name, true);
		}

		/**
		 * @description Checks if the map contains a key with optional namespace handling.
		 *
		 * @param name The key to check.
		 * @param implyNamespace Whether to handle namespace prefixes.
		 *
		 * @return `true` if the key exists, `false` otherwise.
		 *
		 * @example
		 * ```apex
		 * UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe('Account');
		 * Boolean hasField = describe.getFields().containsKey('Name', false);
		 * System.debug(hasField); // Outputs: true or false based on namespace
		 * ```
		 */
		public virtual Boolean containsKey(String name, Boolean implyNamespace)
		{
			Boolean containsKey = null;

			if(name != null)
			{
				String preferredValue = ((implyNamespace ? namespacePrefix : UTIL_String.EMPTY) + name).toLowerCase();
				containsKey = (values.containsKey(preferredValue) || implyNamespace && values.containsKey(name.toLowerCase()));
			}

			return containsKey;
		}

		/**
		 * @description Returns the number of entries in the map.
		 *
		 * @return The size of the map.
		 *
		 * @example
		 * ```apex
		 * UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe('Account');
		 * Integer fieldCount = describe.getFields().size();
		 * System.debug(fieldCount); // Outputs: Number of fields on Account
		 * ```
		 */
		public virtual Integer size()
		{
			return values.size();
		}

		/**
		 * @description Returns the key set of the map with namespace handling disabled by default.
		 *
		 * @return A set of keys in the map.
		 *
		 * @example
		 * ```apex
		 * UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe('Account');
		 * Set<String> fieldNames = describe.getFields().keySet();
		 * System.debug(fieldNames); // Outputs: Set of field API names
		 * ```
		 */
		public virtual Set<String> keySet()
		{
			return keySet(false);
		}

		/**
		 * @description Returns the key set of the map with optional namespace handling.
		 *
		 * @param implyNamespace Whether to strip namespace prefixes from keys.
		 *
		 * @return A set of keys in the map.
		 *
		 * @example
		 * ```apex
		 * UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe('Account');
		 * Set<String> fieldNames = describe.getFields().keySet(true);
		 * System.debug(fieldNames); // Outputs: Set of field names without namespace
		 * ```
		 */
		public virtual Set<String> keySet(Boolean implyNamespace)
		{
			if(implyNamespace)
			{
				Set<String> result = new Set<String>();
				for(String key : values.keySet())
				{
					result.add(key.removeStartIgnoreCase(namespacePrefix));
				}
				return result;
			}
			else
			{
				return values.keySet();
			}
		}
	}

	/**
	 * @description A subclass of `NamespacedAttributeMap` for handling field maps returned by `DescribeSObjectResult.fields.getMap()`.
	 *
	 * @since 1.0
	 */
	global inherited sharing class FieldsMap extends NamespacedAttributeMap
	{
		/**
		 * @description Constructs a new FieldsMap wrapping the given field map.
		 *
		 * @param values The map of field API names to SObjectField tokens.
		 */
		@TestVisible
		private FieldsMap(Map<String, SObjectField> values)
		{
			super(values);
		}

		/**
		 * @description Checks if the map contains a key with namespace handling enabled by default.
		 *
		 * @param name The key to check.
		 *
		 * @return `true` if the key exists, `false` otherwise.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Boolean result = instance.containsKey('myName');
		 * ```
		 */
		global override Boolean containsKey(String name)
		{
			return super.containsKey(name);
		}

		/**
		 * @description Checks if the map contains a key with optional namespace handling.
		 *
		 * @param name The key to check.
		 * @param implyNamespace Whether to handle namespace prefixes.
		 *
		 * @return `true` if the key exists, `false` otherwise.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Boolean result = instance.containsKey('myName', true);
		 * ```
		 */
		global override Boolean containsKey(String name, Boolean implyNamespace)
		{
			return super.containsKey(name, implyNamespace);
		}

		/**
		 * @description Returns the number of entries in the map.
		 *
		 * @return The size of the map.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Integer result = instance.size();
		 * ```
		 */
		global override Integer size()
		{
			return super.size();
		}

		/**
		 * @description Returns the key set of the map with namespace handling disabled by default.
		 *
		 * @return A set of keys in the map.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Set<String> result = instance.keySet();
		 * ```
		 */
		global override Set<String> keySet()
		{
			return super.keySet();
		}

		/**
		 * @description Returns the key set of the map with optional namespace handling.
		 *
		 * @param implyNamespace Whether to strip namespace prefixes from keys.
		 *
		 * @return A set of keys in the map.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Set<String> result = instance.keySet(true);
		 * ```
		 */
		global override Set<String> keySet(Boolean implyNamespace)
		{
			return super.keySet(implyNamespace);
		}

		/**
		 * @description Retrieves an `SObjectField` by name with namespace handling enabled by default.
		 *
		 * @param name The API name of the field.
		 *
		 * @return The `SObjectField`, or null if not found.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe('Contact');
		 * SObjectField field = describe.getFields().get('Email');
		 * System.debug(field?.getDescribe().getLabel()); // Outputs: Email
		 * ```
		 */
		global SObjectField get(String name)
		{
			return get(name, true);
		}

		/**
		 * @description Retrieves an `SObjectField` by name with optional namespace handling.
		 *
		 * @param name The API name of the field.
		 * @param implyNamespace Whether to handle namespace prefixes.
		 *
		 * @return The `SObjectField`, or null if not found.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe('Contact');
		 * SObjectField field = describe.getFields().get('Account', false);
		 * System.debug(field?.getDescribe().name); // Outputs: AccountId
		 * ```
		 */
		global SObjectField get(String name, Boolean implyNamespace)
		{
			return (SObjectField)getObject(name, implyNamespace);
		}

		/**
		 * @description Returns the list of `SObjectField` values in the map.
		 *
		 * @return A list of `SObjectField` instances.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe('Account');
		 * List<SObjectField> fields = describe.getFields().values();
		 * System.debug(fields.size()); // Outputs: Number of fields on Account
		 * ```
		 */
		global List<SObjectField> values()
		{
			return (List<SObjectField>)values.values();
		}
	}

	/**
	 * @description A subclass of `NamespacedAttributeMap` for handling global describe data returned by `getGlobalDescribe`.
	 *
	 * @since 1.0
	 */
	global inherited sharing class GlobalDescribeMap extends NamespacedAttributeMap
	{
		/**
		 * @description Constructs a new GlobalDescribeMap wrapping the given SObjectType map.
		 *
		 * @param values The map of SObject API names to SObjectType tokens.
		 */
		@TestVisible
		private GlobalDescribeMap(Map<String, SObjectType> values)
		{
			super(values);
		}

		/**
		 * @description Checks if the map contains a key with namespace handling enabled by default.
		 *
		 * @param name The key to check.
		 *
		 * @return `true` if the key exists, `false` otherwise.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Boolean result = instance.containsKey('myName');
		 * ```
		 */
		global override Boolean containsKey(String name)
		{
			return super.containsKey(name);
		}

		/**
		 * @description Checks if the map contains a key with optional namespace handling.
		 *
		 * @param name The key to check.
		 * @param implyNamespace Whether to handle namespace prefixes.
		 *
		 * @return `true` if the key exists, `false` otherwise.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Boolean result = instance.containsKey('myName', true);
		 * ```
		 */
		global override Boolean containsKey(String name, Boolean implyNamespace)
		{
			return super.containsKey(name, implyNamespace);
		}

		/**
		 * @description Returns the number of entries in the map.
		 *
		 * @return The size of the map.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Integer result = instance.size();
		 * ```
		 */
		global override Integer size()
		{
			return super.size();
		}

		/**
		 * @description Returns the key set of the map with namespace handling disabled by default.
		 *
		 * @return A set of keys in the map.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Set<String> result = instance.keySet();
		 * ```
		 */
		global override Set<String> keySet()
		{
			return super.keySet();
		}

		/**
		 * @description Returns the key set of the map with optional namespace handling.
		 *
		 * @param implyNamespace Whether to strip namespace prefixes from keys.
		 *
		 * @return A set of keys in the map.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Set<String> result = instance.keySet(true);
		 * ```
		 */
		global override Set<String> keySet(Boolean implyNamespace)
		{
			return super.keySet(implyNamespace);
		}

		/**
		 * @description Retrieves an `SObjectType` by name with namespace handling enabled by default.
		 *
		 * @param name The API name of the SObject.
		 *
		 * @return The `SObjectType`, or null if not found.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_SObjectDescribe.GlobalDescribeMap globalDescribe = UTIL_SObjectDescribe.getGlobalDescribe();
		 * SObjectType objType = globalDescribe.get('Account');
		 * System.debug(objType?.getDescribe().getLabel()); // Outputs: Account
		 * ```
		 */
		global SObjectType get(String name)
		{
			return get(name, true);
		}

		/**
		 * @description Retrieves an `SObjectType` by name with optional namespace handling.
		 *
		 * @param name The API name of the SObject.
		 * @param implyNamespace Whether to handle namespace prefixes.
		 *
		 * @return The `SObjectType`, or null if not found.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_SObjectDescribe.GlobalDescribeMap globalDescribe = UTIL_SObjectDescribe.getGlobalDescribe();
		 * SObjectType objType = globalDescribe.get('Account', false);
		 * System.debug(objType?.getDescribe().name); // Outputs: Account
		 * ```
		 */
		global SObjectType get(String name, Boolean implyNamespace)
		{
			return (SObjectType)getObject(name, implyNamespace);
		}

		/**
		 * @description Returns the list of `SObjectType` values in the global describe map.
		 *
		 * @return A list of `SObjectType` instances.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_SObjectDescribe.GlobalDescribeMap globalDescribe = UTIL_SObjectDescribe.getGlobalDescribe();
		 * List<SObjectType> objTypes = globalDescribe.values();
		 * System.debug(objTypes.size()); // Outputs: Number of SObject types
		 * ```
		 */
		global List<SObjectType> values()
		{
			return (List<SObjectType>)values.values();
		}
	}

	/**
	 * @description Cached field metadata to avoid repeated describe calls.
	 * Computed once per field during single iteration, stored on UTIL_SObjectDescribe instance.
	 *
	 * Keep this class lightweight - primitives and one parent reference only.
	 * Do NOT store SObjectField tokens or DescribeFieldResult (not serializable, heap-heavy).
	 * On enterprise orgs, Account can have 800+ fields - each gets a FieldMetadata instance.
	 *
	 * String references are passed in from the caller to ensure reference sharing across
	 * the FieldMetadata object, map keys, and set entries - minimising heap usage.
	 */
	public inherited sharing class FieldMetadata
	{
		/**
		 * @description Reference to parent UTIL_SObjectDescribe for lazy access to full DescribeFieldResult.
		 */
		private final UTIL_SObjectDescribe parentDescribe;

		/**
		 * @description The field API name (original case).
		 */
		public final String name;

		/**
		 * @description The field API name in lowercase for case-insensitive lookups.
		 * Shares reference with map keys in parent class.
		 */
		public final String nameLowerCase;

		/**
		 * @description The field's data type.
		 */
		public final DisplayType fieldType;

		/**
		 * @description The relationship name for lookup fields in lowercase, null for non-lookup fields.
		 */
		public final String relationshipName;

		/**
		 * @description The relationship name for lookup fields in original case, null for non-lookup fields.
		 * Used as key in referenceFieldMap for backwards compatibility.
		 */
		public final String relationshipNameOriginalCase;

		/**
		 * @description Object API names this field references. Stored as strings for serializability.
		 */
		public final List<String> referenceToObjectNames;

		/**
		 * @description True if field requires a value for DML insert and won't be auto-populated.
		 */
		public final Boolean isCreatableRequired;

		/**
		 * @description True if field is safe to include in SOQL SELECT clauses.
		 */
		public final Boolean isSelectableInQuery;

		/**
		 * @description True if this lookup field is safe to traverse in nested SELECT * queries.
		 */
		public final Boolean isTraversableReference;

		/**
		 * @description Lazy-loaded full DescribeFieldResult for this field.
		 * Use sparingly - prefer using the cached metadata properties for better performance.
		 */
		public DescribeFieldResult fieldDescribe
		{
			get
			{
				if(fieldDescribe == null)
				{
					fieldDescribe = parentDescribe.getFieldDescribe(this.nameLowerCase);
				}
				return fieldDescribe;
			}
			private set;
		}

		/**
		 * @description Constructs field metadata from a describe result with pre-computed strings.
		 * Accepts pre-computed string references to ensure sharing with map keys and set entries.
		 *
		 * @param parent The parent UTIL_SObjectDescribe instance for lazy DescribeFieldResult access.
		 * @param fieldDescribe The field describe result to extract metadata from.
		 * @param cachedName The field name (original case) - shared with allFieldNames set.
		 * @param cachedNameLower The field name (lowercase) - shared with fieldMetadata map key.
		 * @param cachedRelationshipNameLower The relationship name (lowercase) - shared with relationshipFieldMap.
		 * @param cachedRelationshipNameOriginal The relationship name (original case) - shared with referenceFieldMap.
		 */
		@SuppressWarnings('PMD.ExcessiveParameterList')
		private FieldMetadata
				(
						UTIL_SObjectDescribe parent,
						DescribeFieldResult fieldDescribe,
						String cachedName,
						String cachedNameLower,
						String cachedRelationshipNameLower,
						String cachedRelationshipNameOriginal
				)
		{
			this.parentDescribe = parent;
			this.name = cachedName;
			this.nameLowerCase = cachedNameLower;
			this.fieldType = fieldDescribe.type;
			this.relationshipName = cachedRelationshipNameLower;
			this.relationshipNameOriginalCase = cachedRelationshipNameOriginal;
			this.referenceToObjectNames = extractReferenceObjectNames(fieldDescribe.referenceTo);
			this.isCreatableRequired = computeIsCreatableRequired(fieldDescribe);
			this.isSelectableInQuery = computeIsSelectableInQuery(fieldDescribe);
			this.isTraversableReference = computeIsTraversableReference(fieldDescribe, cachedNameLower);
		}

		/**
		 * @description Extracts object API names from SObjectType references.
		 *
		 * @param referenceTo List of SObjectType references from the field describe.
		 *
		 * @return List of object API names as strings.
		 */
		private List<String> extractReferenceObjectNames(List<SObjectType> referenceTo)
		{
			List<String> objectNames = new List<String>();

			if(referenceTo != null)
			{
				for(SObjectType referencedObjectType : referenceTo)
				{
					objectNames.add(getObjectNameFromType(referencedObjectType));
				}
			}

			return objectNames;
		}

		/**
		 * @description Determines if a field requires a value for record creation.
		 *
		 * @param fieldDescribe The field describe result.
		 *
		 * @return True if the field is required and won't be auto-populated.
		 */
		private Boolean computeIsCreatableRequired(DescribeFieldResult fieldDescribe)
		{
			return !fieldDescribe.defaultedOnCreate
					&& !fieldDescribe.autoNumber
					&& !fieldDescribe.nillable
					&& fieldDescribe.createable;
		}

		/**
		 * @description Determines if a field can be included in SOQL SELECT clauses.
		 *
		 * @param fieldDescribe The field describe result.
		 *
		 * @return True if the field is selectable in queries.
		 */
		private Boolean computeIsSelectableInQuery(DescribeFieldResult fieldDescribe)
		{
			if(!fieldDescribe.isAccessible())
			{
				return false;
			}

			if(fieldDescribe.type == DisplayType.ADDRESS || fieldDescribe.type == DisplayType.LOCATION)
			{
				return false;
			}

			if(fieldDescribe.type == DisplayType.BASE64 || fieldDescribe.type == DisplayType.ENCRYPTEDSTRING)
			{
				return false;
			}

			String fieldNameLower = fieldDescribe.name.toLowerCase();

			if(fieldNameLower == 'id' || fieldNameLower == 'isdeleted')
			{
				return false;
			}

			return true;
		}

		/**
		 * @description Determines if a lookup field should be traversed in nested SELECT * queries.
		 * Returns false for system audit fields (CreatedById, OwnerId, etc.) to prevent query explosion.
		 *
		 * @param fieldDescribe The field describe result.
		 * @param fieldNameLower The field name in lowercase.
		 *
		 * @return True if the lookup is safe to traverse in nested queries.
		 */
		private Boolean computeIsTraversableReference(DescribeFieldResult fieldDescribe, String fieldNameLower)
		{
			if(fieldDescribe.type != DisplayType.REFERENCE)
			{
				return false;
			}

			if(String.isBlank(fieldDescribe.relationshipName))
			{
				return false;
			}

			Set<String> systemAuditFields = new Set<String>
			{
					'createdbyid',
					'lastmodifiedbyid',
					'ownerid',
					'masterrecordid'
			};

			if(systemAuditFields.contains(fieldNameLower))
			{
				return false;
			}

			if(fieldDescribe.referenceTo == null || fieldDescribe.referenceTo.size() != 1)
			{
				return false;
			}

			return true;
		}
	}

	/**
	 * @description Cached map of global describe data.
	 */
	private static Map<String, SObjectType> rawGlobalDescribe
	{
		get
		{
			if(rawGlobalDescribe == null)
			{
				rawGlobalDescribe = Schema.getGlobalDescribe();
			}
			return rawGlobalDescribe;
		}
		set;
	}

	/**
	 * @description Wrapped map of global describe data with namespace handling.
	 */
	private static final GlobalDescribeMap wrappedGlobalDescribe
	{
		get
		{
			if(wrappedGlobalDescribe == null)
			{
				wrappedGlobalDescribe = new GlobalDescribeMap(rawGlobalDescribe);
			}
			return wrappedGlobalDescribe;
		}
		set;
	}

	/**
	 * @description Cache for `UTIL_SObjectDescribe` instances to prevent redundant instantiation.
	 */
	private static UTIL_Map.CaseInsensitiveMap describeCache
	{
		get
		{
			if(describeCache == null)
			{
				describeCache = new UTIL_Map.CaseInsensitiveMap();
			}
			return describeCache;
		}
		set;
	}
}