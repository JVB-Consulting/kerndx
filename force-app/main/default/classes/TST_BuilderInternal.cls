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
 * @description Contains the internal implementation for the SObject Builder Factory.
 * These classes are not intended for direct use by subscribers and are considered
 * internal to the managed package.
 *
 * @see TST_Builder
 * @see TST_BuilderInternal_TEST
 *
 * @author Jason van Beukering
 *
 * @group Testing
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.ExcessiveClassLength,PMD.AvoidBooleanMethodParameters')
public inherited sharing class TST_BuilderInternal
{
	/**
	 * @description Build context that flows through nested builder calls.
	 * When a parent builder sets generateMockIds, child builders inherit this setting.
	 * This flag is set by TST_Builder.buildList() and consumed here.
	 */
	public static Boolean globalGenerateMockIds = false;

	/**
	 * @description Provides unique mock IDs for each record when building without insertion.
	 * Implements DefaultFieldValueProvider to integrate with the existing default value machinery.
	 */
	public class MockIdProvider extends TST_Builder.DefaultFieldValueProvider
	{
		private final SObjectType objectType;

		/**
		 * @description Constructs a MockIdProvider for the specified SObjectType.
		 *
		 * @param objectType The SObjectType for which to generate mock IDs.
		 */
		public MockIdProvider(SObjectType objectType)
		{
			this.objectType = objectType;
		}

		/**
		 * @description Generates a unique mock ID for the specified record index.
		 *
		 * @param recordIndex The index of the record being created (not used, but required by interface).
		 *
		 * @return A unique mock ID for the configured SObjectType.
		 */
		public override Object getValue(Integer recordIndex)
		{
			return UTIL_Random.randomId(objectType);
		}
	}

	/**
	 * @description Handles the instantiation of all SObject instances and their dependencies.
	 */
	@TestVisible
	@SuppressWarnings('PMD.CyclomaticComplexity')
	private class SObjectFactory implements TST_Builder.FactoryWithChildren
	{
		/**
		 * @description The main SObject type to be instantiated.
		 */
		private final SObjectType sObjectType;
		/**
		 * @description The main SObject API name to be instantiated.
		 */
		private final UTIL_SObjectDescribe objectDescribe;
		/**
		 * @description An instance of SObjectManager to store all created SObject instances.
		 */
		private final SObjectManager objectManager;

		/**
		 * @description Constructor for the SObjectFactory.
		 *
		 * @param objectType The main SObject type to be instantiated.
		 */
		public SObjectFactory(SObjectType objectType)
		{
			if(objectType == null)
			{
				throw new IllegalArgumentException('A null SObjectType was provided.');
			}

			this.sObjectType = objectType;
			objectDescribe = UTIL_SObjectDescribe.getDescribe(objectType);
			objectManager = new SObjectManager(objectDescribe);
		}

		/**
		 * @description Retrieves the SObjectManager instance.
		 *
		 * @return The SObjectManager instance.
		 */
		public SObjectManager getSObjectManager()
		{
			return objectManager;
		}

		/**
		 * @description Generates an SObject instance and applies the override map of values.
		 *
		 * @param mapOfValuesOverride A map of values to override when instantiating the SObject.
		 * @param doInsert If true, the SObject list is inserted into the Salesforce database.
		 *
		 * @return An SObject instance.
		 */
		public SObject getSObjectInstance(Map<String, Object> mapOfValuesOverride, Boolean doInsert)
		{
			return getListSObjectInstance(mapOfValuesOverride, doInsert, 1).get(0);
		}

		/**
		 * @description Generates a list of SObject instances and applies the override map of values.
		 *
		 * @param mapOfValuesOverride A map of values to override when instantiating the SObject.
		 * @param doInsert If true, the SObject list is inserted into the Salesforce database.
		 * @param numberOfSObjects The number of SObjects to be instantiated.
		 *
		 * @return A list of SObject instances.
		 */
		public List<SObject> getListSObjectInstance(Map<String, Object> mapOfValuesOverride, Boolean doInsert, Integer numberOfSObjects)
		{
			Map<String, TST_Builder.DefaultFieldValueProvider> mapOfValues =
					TST_Builder.defaultValueProvider.getDefaultMapOfValues(sObjectType, mapOfValuesOverride);

			for(Integer i = 0; i < numberOfSObjects; i++)
			{
				initSObjectInstance(mapOfValues, i, doInsert);
			}

			if(doInsert)
			{
				// Read-only fields cannot be applied for DML.
				objectManager.insertAll();
			}
			else
			{
				// This is a withoutInsertion() build. Apply read-only fields using JSON mocking.
				List<SObject> builtObjects = objectManager.getMainObjects();

				if(objectManager.hasReadOnlyOverrides())
				{
					List<SObject> finalObjects = new List<SObject>();
					String rootPathKey = objectDescribe.getDescribe().name;

					for(Integer i = 0; i < builtObjects.size(); i++)
					{
						// Fetch overrides specifically for this index and the root object path
						Map<String, Object> overrides = objectManager.getReadOnlyOverrides(i, rootPathKey);
						finalObjects.add(overrides?.isEmpty() == false ? applyReadOnlyFields(builtObjects[i], overrides) : builtObjects[i]);
					}

					// Update the manager's list with the new, mocked objects
					objectManager.setMainObjectsList(finalObjects);
				}
			}

			return objectManager.getMainObjects();
		}

		/**
		 * @description Generates a list of SObject instances with child relationships.
		 * Uses a single UOW transaction for atomic insertion of parents and children.
		 *
		 * @param mapOfValuesOverride A map of values to override when instantiating the SObject.
		 * @param doInsert If true, the SObject list and children are inserted into the Salesforce database.
		 * @param numberOfSObjects The number of SObjects to be instantiated.
		 * @param childRelationships Map of relationship names to child SObject lists.
		 * @param parentType The SObjectType of the parent.
		 *
		 * @return A list of SObject instances with children.
		 */
		@SuppressWarnings('PMD.ExcessiveParameterList')
		public List<SObject> getListSObjectInstanceWithChildren
				(
						Map<String, Object> mapOfValuesOverride,
						Boolean doInsert,
						Integer numberOfSObjects,
						Map<String, List<SObject>> childRelationships,
						SObjectType parentType
				)
		{
			// Build parents first (without inserting yet if doInsert=true)
			Map<String, TST_Builder.DefaultFieldValueProvider> mapOfValues =
					TST_Builder.defaultValueProvider.getDefaultMapOfValues(sObjectType, mapOfValuesOverride);

			for(Integer i = 0; i < numberOfSObjects; i++)
			{
				initSObjectInstance(mapOfValues, i, doInsert);
			}

			List<SObject> parents = objectManager.getMainObjects();

			// Handle child relationships
			if(doInsert)
			{
				// Single UOW transaction: register children with parent's UOW before commit
				ChildRelationshipHelper helper = new ChildRelationshipHelper();
				objectManager.registerChildren(parents, childRelationships, parentType, helper);
				objectManager.insertAll(); // Commits both parents and children atomically
			}
			else
			{
				// withoutInsertion: Apply JSON mocking for children
				ChildRelationshipHelper helper = new ChildRelationshipHelper();
				parents = helper.applyChildRelationshipsViaJSON(parents, childRelationships);

				// Also handle read-only fields for parents if needed
				if(objectManager.hasReadOnlyOverrides())
				{
					List<SObject> finalObjects = new List<SObject>();
					String rootPathKey = objectDescribe.getDescribe().name;

					for(Integer i = 0; i < parents.size(); i++)
					{
						Map<String, Object> overrides = objectManager.getReadOnlyOverrides(i, rootPathKey);
						finalObjects.add(overrides?.isEmpty() == false ? applyReadOnlyFields(parents[i], overrides) : parents[i]);
					}

					parents = finalObjects;
				}

				objectManager.setMainObjectsList(parents);
			}

			return objectManager.getMainObjects();
		}

		/**
		 * @description Initiates the main SObject instance with all related SObjects and applies the map of values.
		 *
		 * @param mapOfValues A map of values where the key is the field name and the value is the default value to use.
		 * @param recordIndex The index number (starting from 0) of the record being created.
		 * @param doInsert If true, the SObject list is inserted into the Salesforce database.
		 */
		@TestVisible
		private void initSObjectInstance(Map<String, TST_Builder.DefaultFieldValueProvider> mapOfValues, Integer recordIndex, Boolean doInsert)
		{
			objectManager.setSObject(recordIndex, sObjectType.newSObject(), doInsert);
			SObject mainSObject = objectManager.getSObject(recordIndex);
			String rootPathKey = objectDescribe.getDescribe().name;

			for(String fullyQualifiedFieldName : mapOfValues.keySet())
			{
				String fieldName = (UTIL_String.DOT + fullyQualifiedFieldName).substringAfterLast(UTIL_String.DOT);
				Object fieldValue = getFieldValueFromMapOfValues(mapOfValues, fullyQualifiedFieldName, recordIndex);

				if(!fullyQualifiedFieldName.contains(UTIL_String.DOT))
				{
					// Handle read-only child relationships (e.g., 'Contacts')
					if(fieldValue instanceof List<SObject>)
					{
						// This is likely a read-only child relationship.
						// We can't 'put' it, so register it for the JSON mock.
						// We must find the correctly-cased relationship name for JSON deserialization.
						String realRelationshipName = fieldName; // Default to lowercase
						for(ChildRelationship relationship : objectDescribe.getDescribe().getChildRelationships())
						{
							if(relationship.getRelationshipName()?.equalsIgnoreCase(fieldName) == true)
							{
								realRelationshipName = relationship.getRelationshipName(); // Found it; e.g., 'Contacts'
								break;
							}
						}
						objectManager.registerReadOnlyOverride(recordIndex, rootPathKey, realRelationshipName, fieldValue);
					}
					// Handle lookups (e.g., 'Account')
					else if(fieldValue instanceof SObject)
					{
						putSObject
								(
										mainSObject,
										fieldName,
										(SObject)fieldValue,
										rootPathKey,
										doInsert,
										recordIndex
								);
					}
					// Handle primitive fields (e.g., 'Name')
					else
					{
						putField(mainSObject, fieldName, fieldValue, rootPathKey, recordIndex);
					}
				}
				else
				{
					String firstRelationshipName = fullyQualifiedFieldName.substringBefore(UTIL_String.DOT);
					String fullyQualifiedRelationshipName = fullyQualifiedFieldName.substringBeforeLast(UTIL_String.DOT);
					SObject relatedSObj = getRelationshipInstance(fullyQualifiedRelationshipName, recordIndex, doInsert);
					String errorMessageMergeValue = objectDescribe.getDescribe().name + UTIL_String.DOT + fullyQualifiedRelationshipName;

					// Handle SObject values (parent lookups) with putSObject to set up relationships properly
					if(fieldValue instanceof SObject)
					{
						putSObject(relatedSObj, fieldName, (SObject)fieldValue, errorMessageMergeValue, doInsert, recordIndex);
					}
					else
					{
						putField(relatedSObj, fieldName, fieldValue, errorMessageMergeValue, recordIndex);
					}

					putSObject
							(
									mainSObject,
									firstRelationshipName,
									objectManager.getCachedSObject(recordIndex, firstRelationshipName),
									objectDescribe.getDescribe().name,
									doInsert,
									recordIndex
							);
				}
			}
		}

		/**
		 * @description A recursive method that initiates all related SObjects for a given fully qualified relationship name.
		 *
		 * @param fullyQualifiedRelationshipName A fully qualified relationship name (e.g., 'Case.Contact.Account').
		 * @param recordIndex The index number (starting from 0) of the record being created.
		 * @param doInsert If true, the SObject list is inserted into the Salesforce database.
		 *
		 * @return The main SObject instance with all related SObjects attached.
		 */
		@TestVisible
		private SObject getRelationshipInstance(String fullyQualifiedRelationshipName, Integer recordIndex, Boolean doInsert)
		{
			// Cache lookup normalizes keys, so 'accountid' and 'account' both find the same entry
			SObject sObj = objectManager.getCachedSObject(recordIndex, fullyQualifiedRelationshipName);

			if(sObj == null)
			{
				String leafRelationshipName = (UTIL_String.DOT + fullyQualifiedRelationshipName).substringAfterLast(UTIL_String.DOT);

				if(!fullyQualifiedRelationshipName.contains(UTIL_String.DOT))
				{
					sObj = getRelatedSObjectInstance(sObjectType, leafRelationshipName, objectDescribe.getDescribe().name);
				}
				else
				{
					String fullyQualifiedRelationshipNameWithoutLeaf = fullyQualifiedRelationshipName.substringBeforeLast(UTIL_String.DOT);
					SObject relatedSObj = getRelationshipInstance(fullyQualifiedRelationshipNameWithoutLeaf, recordIndex, doInsert);
					String errorMessageMergeValue = objectDescribe.getDescribe().name + UTIL_String.DOT + fullyQualifiedRelationshipNameWithoutLeaf;

					sObj = getRelatedSObjectInstance(relatedSObj.getSObjectType(), leafRelationshipName, errorMessageMergeValue);

					putSObject(relatedSObj, leafRelationshipName, sObj, errorMessageMergeValue, doInsert, recordIndex);
				}

				objectManager.registerAndCache(recordIndex, fullyQualifiedRelationshipName, sObj, doInsert);
			}

			return sObj;
		}

		/**
		 * @description Gets a related SObject instance for a given SObject type and relationship name.
		 *
		 * @param sObjectType The SObject type to which the generated SObject is related.
		 * @param relationshipName The relationship name that links the SObject type and the instance to be generated.
		 * @param errorMessageMergeValue A value provided for error message generation context (e.g., 'Contact.Account').
		 *
		 * @return The generated related SObject instance.
		 */
		@TestVisible
		private SObject getRelatedSObjectInstance(SObjectType sObjectType, String relationshipName, String errorMessageMergeValue)
		{
			Map<String, SObjectField> fieldMap = UTIL_SObjectDescribe.getDescribe(sObjectType).getFieldsMap();
			SObjectField objectField;
			String actualFieldName;

			// First, try the input as-is (handles field names like ParentId, AccountId, Custom_Lookup__c)
			objectField = fieldMap?.get(relationshipName);

			if(objectField != null && objectDescribe.getFieldDescribe(objectField).type == DisplayType.REFERENCE)
			{
				actualFieldName = relationshipName;
			}
			else
			{
				// Fall back to conversion (handles relationship names like Parent, Account, Custom__r)
				actualFieldName = UTIL_SObjectBuilderDefaultProvider.getFieldNameFromRelationshipName(relationshipName);
				objectField = fieldMap?.get(actualFieldName);
			}

			if(objectField == null)
			{
				throw new SObjectException
						(
								String.format
										(
												'The relationship "{0}" (field: "{1}") is invalid for SObject "{2}". It does not exist in the ',
												new List<String> {relationshipName, actualFieldName, errorMessageMergeValue}
										)
						);
			}

			DescribeFieldResult fieldDescribe = objectDescribe.getFieldDescribe(objectField);

			if(fieldDescribe.referenceTo.isEmpty())
			{
				throw new SObjectException
						(
								String.format
										(
												'The field "{0}" on "{1}" is not a relationship field or has no referenceTo targets.',
												new List<String> {actualFieldName, errorMessageMergeValue}
										)
						);
			}

			SObjectType parentType = fieldDescribe.referenceTo.iterator().next();
			SObject relatedObject = parentType.newSObject();

			// Assign mock ID to parent records when generating mock IDs for withoutInsertion builds
			if(globalGenerateMockIds)
			{
				relatedObject.Id = (Id)new MockIdProvider(parentType).getValue(0);
			}

			return relatedObject;
		}

		/**
		 * @description Gets the field value from the map of values for a given record index and fully qualified field name.
		 *
		 * @param mapOfValues A map of values with the key as the field name.
		 * @param fullyQualifiedFieldName A fully qualified field name (e.g., 'Contact.Account.Name').
		 * @param recordIndex The index number (starting from 0) of the record being created.
		 *
		 * @return The field's value.
		 */
		@TestVisible
		private Object getFieldValueFromMapOfValues
				(
						Map<String, TST_Builder.DefaultFieldValueProvider> mapOfValues,
						String fullyQualifiedFieldName,
						Integer recordIndex
				)
		{
			TST_Builder.DefaultFieldValueProvider provider = mapOfValues.get(fullyQualifiedFieldName);

			if(provider == null)
			{
				// Use SObjectException (custom) or IllegalArgumentException here as NullPointerException(String) is invalid
				throw new SObjectException
						(
								'Configuration Error: No default value provider found for field "' + fullyQualifiedFieldName +
								'". This typically implies an issue with the default map generation logic.'
						);
			}

			try
			{
				return provider.getValue(recordIndex);
			}
			catch(Exception error)
			{
				error.setMessage
						(
								'Error generating value for field "' + fullyQualifiedFieldName +
								'" at index ' + recordIndex + ': ' + error.getMessage()
						);
				throw error;
			}
		}

		/**
		 * @description Attaches an SObject instance to a related SObject instance
		 * and registers the relationship with the Unit of Work.
		 *
		 * @param sObj The child SObject instance.
		 * @param relationshipName The relationship name of the parent SObject.
		 * @param sObjectValue The parent SObject instance to attach.
		 * @param errorMessageMergeValue A value provided for error message generation context (e.g., 'Contact.Account').
		 * @param doInsert If true, registers with Unit of Work. If false, links in memory.
		 * @param recordIndex The index of the record being processed (used for override registration).
		 *
		 * @return The main SObject instance.
		 */
		@SuppressWarnings('PMD.ExcessiveParameterList')
		@TestVisible
		private SObject putSObject
				(
						SObject sObj,
						String relationshipName,
						SObject sObjectValue,
						String errorMessageMergeValue,
						Boolean doInsert,
						Integer recordIndex
				)
		{
			UTIL_SObjectDescribe sObjDescribe = UTIL_SObjectDescribe.getDescribe(sObj);
			Map<String, SObjectField> fieldMap = sObjDescribe.getFieldsMap();
			SObjectField objectField;
			String childFieldName;

			// First, try the input as-is (handles field names like ParentId, AccountId, Custom_Lookup__c, SObjectType__c)
			objectField = fieldMap?.get(relationshipName);

			if(objectField != null)
			{
				childFieldName = relationshipName;
			}
			else
			{
				// Fall back to conversion (handles relationship names like Parent, Account, Custom__r)
				childFieldName = UTIL_SObjectBuilderDefaultProvider.getFieldNameFromRelationshipName(relationshipName);
				objectField = fieldMap?.get(childFieldName);
			}

			if(objectField == null)
			{
				throw new SObjectException
						(
								String.format
										(
												'The relationship "{0}" (field: "{1}") does not exist on "{2}".',
												new List<String> {relationshipName, childFieldName, errorMessageMergeValue}
										)
						);
			}

			DescribeFieldResult fieldDescribe = sObjDescribe.getFieldDescribe(objectField);

			// MetadataRelationship fields to EntityDefinition don't expose a relationship name via describe.
			// Derive it from the field name (e.g., SObjectType__c → SObjectType__r).
			String resolvedRelationshipName = fieldDescribe.getRelationshipName();
			if(resolvedRelationshipName == null && fieldDescribe.getName().endsWith(UTIL_SObjectDescribe.CUSTOM_FIELD_SUFFIX))
			{
				resolvedRelationshipName = fieldDescribe.getName().removeEnd(UTIL_SObjectDescribe.CUSTOM_FIELD_SUFFIX)
						+ UTIL_SObjectDescribe.RELATIONSHIP_SUFFIX;
			}

			// Apex allows setting lookup fields in memory even if FLS is read-only.
			// DML will enforce system read-only constraints, which we handle via exceptions if they occur.
			if(doInsert)
			{
				//Use the Unit of Work
				objectManager.registerLink(sObjectValue, fieldDescribe.getSobjectField(), sObj);
			}
			else
			{
				try
				{
					//Use in-memory linking
					sObj.putSObject(resolvedRelationshipName, sObjectValue);

					// Also set the ID field for in-memory-only records
					if(sObjectValue.Id != null)
					{
						// Use the describe's name for correct casing (e.g., 'CreatedById')
						sObj.put(fieldDescribe.name, sObjectValue.Id);
					}
				}
				catch(SObjectException error)
				{
					// If we cannot set the relationship (e.g. CreatedBy is system read-only), we register it for mocking.
					if(error.getMessage().contains('not editable'))
					{
						objectManager.registerReadOnlyOverride(recordIndex, errorMessageMergeValue, resolvedRelationshipName, sObjectValue);
						if(sObjectValue.Id != null)
						{
							objectManager.registerReadOnlyOverride(recordIndex, errorMessageMergeValue, fieldDescribe.name, sObjectValue.Id);
						}
					}
					else
					{
						throw error;
					}
				}
			}

			return sObj;
		}

		/**
		 * @description Sets a field's value in a given SObject instance.
		 * If the field is read-only (not createable), it registers it for
		 * in-memory mocking instead of setting it directly.
		 *
		 * @param sObj The main SObject instance.
		 * @param fieldName The API name of the field to set.
		 * @param fieldValue The value for the field.
		 * @param errorMessageMergeValue A value provided for error message generation context (e.g., 'Contact.Account').
		 * @param recordIndex The index of the record being processed (used for override registration).
		 *
		 * @return The main SObject instance.
		 */
		@TestVisible
		@SuppressWarnings('PMD.ExcessiveParameterList')
		private SObject putField(SObject sObj, String fieldName, Object fieldValue, String errorMessageMergeValue, Integer recordIndex)
		{
			UTIL_SObjectDescribe sObjDescribe = UTIL_SObjectDescribe.getDescribe(sObj);
			SObjectField objectField = sObjDescribe?.getFieldsMap().get(fieldName);

			if(objectField == null)
			{
				// If the field doesn't exist AND the value is null, this is
				// likely a junk key from the default value provider.
				// It is safe to ignore it, as the real data
				// is handled by a different block in initSObjectInstance.
				if(fieldValue == null)
				{
					return sObj;
				}

				throw new SObjectException('Field "' + fieldName + '" does not exist on SObject "' + errorMessageMergeValue + '".');
			}

			DescribeFieldResult fieldDescribe = sObjDescribe.getFieldDescribe(objectField);

			// Don't overwrite an existing Id with null (preserves mock IDs set by getRelatedSObjectInstance)
			if(!fieldDescribe.name.equalsIgnoreCase('Id') || sObj.Id == null)
			{
				try
				{
					// Use the describe's name for sObj.put() as it is case-sensitive for some fields
					// Note: We do NOT check isCreateable() here.
					// 1. Apex ignores FLS on put(), so we can set 'Status__c' even if the user can't see it.
					// 2. If it is a REAL system read-only field (like CreatedById), put() will throw an SObjectException.
					sObj.put(fieldDescribe.name, fieldValue);
				}
				catch(Exception error)
				{
					// Check if the failure is due to the field being genuinely read-only (system field/formula)
					// The error message is typically "Field [Name] is not editable"
					if(error.getMessage().contains('not editable'))
					{
						// Use the describe's name for correct casing (e.g., 'CreatedById')
						objectManager.registerReadOnlyOverride(recordIndex, errorMessageMergeValue, fieldDescribe.name, fieldValue);
						return sObj;
					}

					throw error;
				}
			}

			return sObj;
		}

		/**
		 * @description Applies read-only fields to an SObject by serializing a map
		 * of all fields (including read-only ones) and deserializing it
		 * back into the SObject type.
		 *
		 * @param sObj The SObject built with writeable fields.
		 * @param overrides The map of read-only fields/relationships to apply.
		 *
		 * @return A new SObject instance with read-only fields populated.
		 */
		private SObject applyReadOnlyFields(SObject sObj, Map<String, Object> overrides)
		{
			// Get all currently populated fields from the SObject
			Map<String, Object> objectAsMap = new Map<String, Object>(sObj.getPopulatedFieldsAsMap());

			//Add all the read-only overrides
			objectAsMap.putAll(overrides);

			//Convert SObjects/Lists into mockable maps before serialization
			Map<String, Object> finalMockMap = convertSObjectMapToMockableMap(objectAsMap);

			// Serialize the complete map and deserialize into the SObject
			String jsonMap = JSON.serialize(finalMockMap);
			return (SObject)JSON.deserialize(jsonMap, Type.forName(UTIL_SObjectDescribe.getDescribe(sObj).getDescribe().name));
		}

		/**
		 * @description Recursively converts a map containing SObjects and Lists of SObjects
		 * into a map structure that can be safely serialized and deserialized
		 * to mock read-only fields.
		 *
		 * @param objectAsMap A map of field names to values.
		 *
		 * @return A map containing only primitives and other maps.
		 */
		private Map<String, Object> convertSObjectMapToMockableMap(Map<String, Object> objectAsMap)
		{
			Map<String, Object> finalMockMap = new Map<String, Object>();

			if(objectAsMap != null)
			{
				for(String key : objectAsMap.keySet())
				{
					Object value = objectAsMap.get(key);

					if(value instanceof List<SObject>)
					{
						// Recursively convert child relationship lists
						finalMockMap.put(key, convertSObjectListToMockableMap((List<SObject>)value));
					}
					else if(value instanceof SObject)
					{
						// Recursively convert lookup SObjects, preserving type for deserialization
						SObject sObjectValue = (SObject)value;
						Map<String, Object> sObjectMap = convertSObjectMapToMockableMap(sObjectValue.getPopulatedFieldsAsMap());
						sObjectMap.put('attributes', new Map<String, Object>
						{
								'type' => UTIL_SObjectDescribe.getDescribe(sObjectValue).getDescribe().name
						});
						finalMockMap.put(key, sObjectMap);
					}
					else
					{
						// Add primitives directly
						finalMockMap.put(key, value);
					}
				}
			}

			return finalMockMap;
		}

		/**
		 * @description Helper for convertSObjectMapToMockableMap. Converts a List<SObject>
		 * into the "records" map structure required by the JSON mocking pattern.
		 *
		 * @param sObjectList The list of child SObjects.
		 *
		 * @return A map in the format { 'records': [ ... ] }.
		 */
		private Map<String, Object> convertSObjectListToMockableMap(List<SObject> sObjectList)
		{
			List<Map<String, Object>> recordMaps = new List<Map<String, Object>>();
			if(sObjectList != null)
			{
				for(SObject rec : sObjectList)
				{
					// Recursively convert each SObject in the list, preserving type
					Map<String, Object> recordMap = convertSObjectMapToMockableMap(rec.getPopulatedFieldsAsMap());
					recordMap.put('attributes', new Map<String, Object>
					{
							'type' => UTIL_SObjectDescribe.getDescribe(rec).getDescribe().name
					});
					recordMaps.add(recordMap);
				}
			}
			return new Map<String, Object>
			{
					'done' => true,
					'size' => recordMaps.size(),
					'records' => recordMaps
			};
		}
	}

	/**
	 * @description Manages the lifecycle of SObject instances, including their relationships and database insertion.
	 * Extends DML_Transaction to handle DML operations with dependency ordering.
	 */
	public inherited sharing class SObjectManager extends DML_Transaction implements TST_Builder.Manager
	{
		/**
		 * @description The API name of the main SObject being managed.
		 */
		private final UTIL_SObjectDescribe objectDescribe;

		/**
		 * @description A list of the main SObject instances.
		 */
		@TestVisible
		private List<SObject> mainObjects = new List<SObject>();

		/**
		 * @description A cache of all created SObjects (main and related) by their
		 * index and relationship path.
		 * Map<Index, Map<Path, SObject>>
		 */
		@TestVisible
		private Map<Integer, Map<String, SObject>> objectsByIndexAndPath = new Map<Integer, Map<String, SObject>>();

		/**
		 * @description A cache of read-only field values to be applied
		 * during in-memory (withoutInsertion) builds.
		 * Map<Index, Map<PathKey, Map<FieldName, FieldValue>>>
		 * We use Integer (Index) as the primary key because SObjects with no ID and no fields
		 * are considered equal by the Map, which causes collisions if we use Map<SObject, ...>.
		 */
		@TestVisible
		private Map<Integer, Map<String, Map<String, Object>>> readOnlyOverrides = new Map<Integer, Map<String, Map<String, Object>>>();

		/**
		 * @description Constructor for the SObjectManager.
		 *
		 * @param objectDescribe The object describe for the main object.
		 */
		public SObjectManager(UTIL_SObjectDescribe objectDescribe)
		{
			super();
			this.objectDescribe = objectDescribe;
			setAccessLevel(System.AccessLevel.SYSTEM_MODE);
		}

		/**
		 * @description Retrieves the list of main SObject instances being managed.
		 *
		 * @return A list of SObject instances.
		 */
		public List<SObject> getMainObjects()
		{
			return mainObjects;
		}

		/**
		 * @description Replaces the entire list of main objects.
		 * Used by the factory after applying read-only mocks.
		 *
		 * @param newMainObjects The new list of SObjects.
		 */
		@TestVisible
		private void setMainObjectsList(List<SObject> newMainObjects)
		{
			mainObjects = newMainObjects;
		}

		/**
		 * @description Adds or replaces an SObject in the main list at a specific index.
		 * Also registers and caches the SObject.
		 *
		 * @param index The index at which to add or replace the SObject.
		 * @param sObj The SObject instance to add or replace.
		 */
		public void setSObject(Integer index, SObject sObj)
		{
			setSObject(index, sObj, false);
		}

		/**
		 * @description Adds or replaces an SObject in the main list at a specific index.
		 * Also registers and caches the SObject.
		 *
		 * @param index The index at which to add or replace the SObject.
		 * @param sObj The SObject instance to add or replace.
		 * @param doInsert If true, registers with Unit of Work.
		 */
		@TestVisible
		private void setSObject(Integer index, SObject sObj, Boolean doInsert)
		{
			if(index == mainObjects.size())
			{
				mainObjects.add(sObj);
			}
			else
			{
				mainObjects.set(index, sObj);
			}

			registerAndCache(index, objectDescribe.getDescribe().name, sObj, doInsert);
		}

		/**
		 * @description Retrieves an SObject from the main list at a specific index.
		 *
		 * @param index The index of the SObject to retrieve.
		 *
		 * @return The retrieved SObject instance.
		 */
		public SObject getSObject(Integer index)
		{
			return mainObjects.get(index);
		}

		/**
		 * @description Retrieves a cached SObject (main or related) by its index and path.
		 * Used by the SObjectFactory.
		 *
		 * @param index The record index.
		 * @param fullyQualifiedRelationshipName The path (e.g., 'contact.account').
		 *
		 * @return The SObject, or null if not found.
		 */
		public SObject getCachedSObject(Integer index, String fullyQualifiedRelationshipName)
		{
			// Normalize key to relationship name format for consistent lookup
			String normalizedKey = normalizeCacheKey(fullyQualifiedRelationshipName);
			return objectsByIndexAndPath.get(index)?.get(normalizedKey);
		}

		/**
		 * @description Normalizes a cache key to use relationship names (not field names).
		 * This ensures consistent cache keys regardless of whether the caller uses
		 * 'accountid' or 'account', 'accountid.parentid' or 'account.parent'.
		 *
		 * @param cacheKey The cache key to normalize.
		 *
		 * @return The normalized cache key, lowercased.
		 */
		@TestVisible
		private String normalizeCacheKey(String cacheKey)
		{
			return UTIL_SObjectBuilderDefaultProvider.normalizeToRelationshipPath(cacheKey);
		}

		/**
		 * @description Checks if there are any overrides registered.
		 *
		 * @return True if overrides exist.
		 */
		@TestVisible
		private Boolean hasReadOnlyOverrides()
		{
			return !readOnlyOverrides.isEmpty();
		}

		/**
		 * @description Retrieves the map of read-only field overrides for a specific record index and path.
		 *
		 * @param index The record index.
		 * @param pathKey The relationship path key (e.g., 'foobar__c').
		 *
		 * @return The map of field names to values, or null.
		 */
		@TestVisible
		private Map<String, Object> getReadOnlyOverrides(Integer index, String pathKey)
		{
			return readOnlyOverrides.get(index)?.get(pathKey.toLowerCase());
		}

		/**
		 * @description Registers a read-only field or relationship value for an SObject.
		 * These are only applied during in-memory (withoutInsertion) builds.
		 *
		 * @param index The record index.
		 * @param pathKey The relationship path identifying the object (e.g. 'foobar__c' or 'foobar__c.parent').
		 * @param fieldName The API name of the read-only field or relationship.
		 * @param fieldValue The value to set (e.g., a primitive, SObject, or List<SObject>).
		 */
		@TestVisible
		private void registerReadOnlyOverride(Integer index, String pathKey, String fieldName, Object fieldValue)
		{
			if(!readOnlyOverrides.containsKey(index))
			{
				readOnlyOverrides.put(index, new Map<String, Map<String, Object>>());
			}
			Map<String, Map<String, Object>> pathMap = readOnlyOverrides.get(index);
			String normalizedPathKey = pathKey.toLowerCase();

			if(!pathMap.containsKey(normalizedPathKey))
			{
				pathMap.put(normalizedPathKey, new Map<String, Object>());
			}

			pathMap.get(normalizedPathKey).put(fieldName, fieldValue);
		}

		/**
		 * @description Registers a new SObject with the Unit of Work (if doInsert is true)
		 * and adds it to the internal cache.
		 * Used by the SObjectFactory.
		 *
		 * @param index The record index.
		 * @param fullyQualifiedRelationshipName The path (e.g., 'contact.account').
		 * @param sObj The SObject to register and cache.
		 * @param doInsert If true, registers with Unit of Work.
		 */
		@TestVisible
		private void registerAndCache(Integer index, String fullyQualifiedRelationshipName, SObject sObj, Boolean doInsert)
		{
			// Normalize key to relationship name format for consistent storage
			String pathKey = normalizeCacheKey(fullyQualifiedRelationshipName);
			Map<String, SObject> pathMap = objectsByIndexAndPath.get(index);
			if(pathMap == null)
			{
				pathMap = new Map<String, SObject>();
				objectsByIndexAndPath.put(index, pathMap);
			}

			// Only register and cache if it's the first time seeing this object
			if(!pathMap.containsKey(pathKey))
			{
				if(doInsert)
				{
					super.doInsert(sObj);
				}
				pathMap.put(pathKey, sObj);
			}
		}

		/**
		 * @description Registers a parent-child relationship with DML_Transaction.
		 * Used by the SObjectFactory. The child record should already be registered for insert;
		 * this method only establishes the relationship for foreign key population after parent DML.
		 *
		 * @param parentRecord The parent SObject.
		 * @param childRelationshipField The SObjectField on the child.
		 * @param childRecord The child SObject.
		 */
		@TestVisible
		private void registerLink(SObject parentRecord, SObjectField childRelationshipField, SObject childRecord)
		{
			super.registerRelationshipOnly(parentRecord, childRelationshipField, childRecord);
		}

		/**
		 * @description Registers child SObjects with relationships to their parents using the UOW.
		 * This allows children to be inserted in the same transaction as parents.
		 *
		 * @param parents List of parent SObjects (already registered with UOW but not yet inserted)
		 * @param childRelationships Map of relationship names to child SObject lists
		 * @param parentType The SObjectType of the parent
		 * @param relationshipHelper Helper for schema introspection
		 */
		public void registerChildren(List<SObject> parents, Map<String, List<SObject>> childRelationships, SObjectType parentType, ChildRelationshipHelper relationshipHelper)
		{
			for(String relationshipName : childRelationships.keySet())
			{
				List<SObject> children = childRelationships.get(relationshipName);
				String foreignKeyField = relationshipHelper.getForeignKeyField(parentType, relationshipName);
				SObjectField foreignKeyFieldToken = UTIL_SObjectDescribe.getObjectFieldMap(children.iterator().next().getSObjectType())?.get(foreignKeyField);

				// For each parent, register its children with relationship
				for(SObject parent : parents)
				{
					for(SObject child : children)
					{
						// Clone child to avoid modifying the original
						SObject childClone = child.clone(false, true, false, false);
						// Register child for insert with relationship to parent
						super.doInsert(childClone, foreignKeyFieldToken, parent);
					}
				}
			}
		}

		/**
		 * @description Commits all registered SObjects and relationships to the database.
		 * All registration logic now happens during the build phase.
		 */
		public void insertAll()
		{
			commitWork();
		}
	}

	/**
	 * @description The default implementation of the factory provider, included with the package.
	 * It returns the standard SObjectFactory.
	 */
	public inherited sharing class SObjectFactoryProvider implements TST_Builder.FactoryProvider
	{
		public TST_Builder.Factory createFactory(SObjectType sObjectType)
		{
			return new SObjectFactory(sObjectType);
		}
	}

	/**
	 * @description Helper method to convert the new simplified list
	 * into the override map the internal factory understands.
	 *
	 * @param fieldsToDefault A list of SObjectField tokens or String API names.
	 * @param objectDescribe The object describe for cached field lookups.
	 *
	 * @return A Map<String, Object> where each field is mapped to AUTO_DEFAULT.
	 */
	public static Map<String, Object> createAutoDefaultMap(List<Object> fieldsToDefault, UTIL_SObjectDescribe objectDescribe)
	{
		Map<String, Object> autoDefaultMap = new Map<String, Object>();

		if(fieldsToDefault != null)
		{
			for(Object field : fieldsToDefault)
			{
				String fieldName;

				if(field instanceof SObjectField)
				{
					DescribeFieldResult fieldDescribe = objectDescribe?.getFieldDescribe((SObjectField)field);
					fieldName = fieldDescribe?.name;
				}
				else if(field instanceof String)
				{
					fieldName = (String)field;
				}

				if(String.isNotBlank(fieldName))
				{
					autoDefaultMap.put(fieldName.toLowerCase(), TST_Builder.autoDefaultFieldValueProvider);
				}
			}
		}

		return autoDefaultMap;
	}

	/**
	 * @description Helper class for managing child relationships and schema introspection.
	 * Encapsulates complex logic for detecting and managing parent-child relationships.
	 */
	public inherited sharing class ChildRelationshipHelper
	{
		/**
		 * @description Determines the child relationship name from parent/child types.
		 * Detects multiple relationships and provides clear error message.
		 *
		 * @param parentType The parent SObjectType
		 * @param childType The child SObjectType
		 *
		 * @return The child relationship name
		 *
		 * @throws IllegalArgumentException if no relationship found or multiple relationships exist
		 */
		public String getChildRelationshipName(SObjectType parentType, SObjectType childType)
		{
			DescribeSObjectResult parentDescribe = parentType.getDescribe();
			List<String> foundRelationships = new List<String>();

			for(ChildRelationship relationship : parentDescribe.getChildRelationships())
			{
				if(relationship.getChildSObject() == childType)
				{
					String relName = relationship.getRelationshipName();
					if(relName != null)
					{
						foundRelationships.add(relName);
					}
				}
			}

			if(foundRelationships.isEmpty())
			{
				throw new IllegalArgumentException('No child relationship found between ' + parentType + ' and ' + childType);
			}

			if(foundRelationships.size() > 1)
			{
				throw new IllegalArgumentException
						(
								'Multiple relationships found between ' + parentType + ' and ' + childType +
								': ' + foundRelationships + '. Use withChildren(String relationshipName, Builder childBuilder) to specify explicit relationship.'
						);
			}

			return foundRelationships.iterator().next();
		}

		/**
		 * @description Finds the foreign key field name for a given relationship.
		 *
		 * @param parentType The parent SObjectType
		 * @param relationshipName The child relationship name
		 *
		 * @return The foreign key field API name
		 *
		 * @throws IllegalArgumentException if relationship not found
		 */
		public String getForeignKeyField(SObjectType parentType, String relationshipName)
		{
			UTIL_SObjectDescribe parentUtilDescribe = UTIL_SObjectDescribe.getDescribe(parentType);
			DescribeSObjectResult parentDescribe = parentUtilDescribe.getDescribe();

			for(ChildRelationship relationship : parentDescribe.getChildRelationships())
			{
				if(relationship.getRelationshipName() == relationshipName)
				{
					// Get child object describe to use cached field describe
					UTIL_SObjectDescribe childDescribe = UTIL_SObjectDescribe.getDescribe(relationship.getChildSObject());
					return childDescribe.getFieldDescribe(relationship.getField()).name;
				}
			}

			throw new IllegalArgumentException('No relationship found with name: ' + relationshipName + ' on ' + parentType);
		}

		/**
		 * @description Applies child relationships via JSON mocking (for withoutInsertion).
		 * This allows child records to be accessible via relationship queries without DML.
		 *
		 * @param parents List of parent SObjects
		 * @param childRelationships Map of relationship names to child SObject lists
		 *
		 * @return List of parent SObjects with child relationships populated
		 */
		public List<SObject> applyChildRelationshipsViaJSON(List<SObject> parents, Map<String, List<SObject>> childRelationships)
		{
			List<SObject> result = new List<SObject>();

			for(SObject parent : parents)
			{
				// Build JSON representation with child relationships
				Map<String, Object> jsonMap = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(parent));

				// Add each child relationship
				for(String relationshipName : childRelationships.keySet())
				{
					List<SObject> children = childRelationships.get(relationshipName);

					// Serialize children to List<Map<String,Object>> for proper QueryResult format
					List<Object> childrenMaps = new List<Object>();
					for(SObject child : children)
					{
						childrenMaps.add(JSON.deserializeUntyped(JSON.serialize(child)));
					}

					// Add in QueryResult format
					jsonMap.put(relationshipName, new Map<String, Object>
					{
							'records' => childrenMaps,
							'totalSize' => children.size(),
							'done' => true
					});
				}

				// Deserialize back to SObject with children
				String jsonString = JSON.serialize(jsonMap);
				SObject parentWithChildren = (SObject)JSON.deserialize(jsonString, SObject.class);
				result.add(parentWithChildren);
			}

			return result;
		}
	}
}