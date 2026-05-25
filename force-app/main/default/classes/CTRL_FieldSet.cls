// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Common Controller used to get fields from Field set based on the Sobject
 *
 * @see CTRL_FieldSet_TEST
 *
 * @author Jason van Beukering
 *
 * @group Controllers
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.ExcessivePublicCount,PMD.AvoidBooleanMethodParameters')
public inherited sharing class CTRL_FieldSet implements IF_Search
{
	@TestVisible
	private static final String ERROR_FIELD_SET_LIST_NOT_PROVIDED = '"fieldSetApiList" must be provided and must contain values.';
	@TestVisible
	private static final String ERROR_RECORD_ID_OR_OBJECT_NAME_NOT_PROVIDED = '"recordId" or "objectName" must be provided';
	@TestVisible
	private static final String PARAMETER_FIELD_SET_LIST = 'fieldSetApiList';
	@TestVisible
	private static final String PARAMETER_OBJECT_NAME = 'objectName';
	@TestVisible
	private static final String PARAMETER_RECORD_ID = 'recordId';

	/**
	 * @description Retrieves field sets based on fieldset api name list and recordId/object name
	 *
	 * @param searchTerm searchTerm Search Term to be used for search/query (NOT USED)
	 * @param searchParameters Parameters to retrieve field sets by. 'fieldSetApiList' Required. 'recordId' or 'objectName' required, preference is given to
	 * 'recordId'.
	 *
	 * @return Field set search results
	 *
	 * @throws IllegalArgumentException If required parameters are not provided
	 */
	@SuppressWarnings('ApexUnusedDeclaration')
	@AuraEnabled(Cacheable=true)
	public static Object search(Object searchTerm, Map<String, Object> searchParameters)
	{
		List<String> fieldSetNames = UTIL_List.filterStrings((List<Object>)searchParameters.get(PARAMETER_FIELD_SET_LIST));

		if(UTIL_List.isEmpty(fieldSetNames))
		{
			throw new IllegalArgumentException(ERROR_FIELD_SET_LIST_NOT_PROVIDED);
		}

		String objectName = (String)searchParameters.get(PARAMETER_OBJECT_NAME);
		String recordId = (String)searchParameters.get(PARAMETER_RECORD_ID);

		Object searchResult;

		if(String.isNotBlank(recordId))
		{
			searchResult = getFieldSetsForRecord(new Map<Id, List<String>> {recordId => fieldSetNames});
		}
		else if(String.isNotBlank(objectName))
		{
			searchResult = getFieldSetsForObject(new Map<String, List<String>> {objectName => fieldSetNames});
		}
		else
		{
			throw new IllegalArgumentException(ERROR_RECORD_ID_OR_OBJECT_NAME_NOT_PROVIDED);
		}

		return searchResult;
	}

	/**
	 * @description Returns metadata Api Names field
	 *
	 * @return JS Import Structure
	 */
	@AuraEnabled(Cacheable=true)
	public static DTO_FieldSetGroupApiNames getFieldSetApiNamesField()
	{
		DTO_FieldSetGroupApiNames dtoSchemaFieldJSImport = new DTO_FieldSetGroupApiNames();

		dtoSchemaFieldJSImport.fieldApiName = SEL_FieldSetGroup.FIELD_FIELDSET_API_NAMES;
		dtoSchemaFieldJSImport.objectApiName = SEL_FieldSetGroup.OBJECT_NAME;

		return dtoSchemaFieldJSImport;
	}

	/**
	 * @description Returns metadata Active Sections field
	 *
	 * @return JS Import Structure
	 */
	@AuraEnabled(Cacheable=true)
	public static DTO_FieldSetGroupApiNames getDefaultActiveSectionsField()
	{
		DTO_FieldSetGroupApiNames dtoSchemaFieldJSImport = new DTO_FieldSetGroupApiNames();

		dtoSchemaFieldJSImport.fieldApiName = SEL_FieldSetGroup.FIELD_DEFAULT_ACTIVE_SECTIONS;
		dtoSchemaFieldJSImport.objectApiName = SEL_FieldSetGroup.OBJECT_NAME;

		return dtoSchemaFieldJSImport;
	}

	/**
	 * @description Use the method to get 1 or more fieldSets for a record of a particular SObjectType.
	 * eg: When you require 2 fieldSets for an account record, and 1 fieldSet for a case record in a single call
	 * Do not use when you want 1 fieldSet for multiple records of the same SObjectType
	 *
	 * @param recordIdToFieldSetListMap Map of record Id and List of fieldSets
	 *
	 * @return Map of FieldSetAPIName with List of DTO_FieldSetMembers
	 */
	@AuraEnabled(Cacheable=true)
	public static Map<Id, Map<String, List<DTO_FieldSetMember>>> getFieldSetsForRecord(Map<Id, List<String>> recordIdToFieldSetListMap)
	{
		Map<Id, Set<FieldSet>> objectIdToFieldsSetMap = new Map<Id, Set<FieldSet>>();
		Map<String, Set<Id>> objectNameToIdMap = new Map<String, Set<Id>>();
		Map<String, Set<String>> objectNameToFieldsMap = new Map<String, Set<String>>();

		initialiseMaps(recordIdToFieldSetListMap, objectNameToIdMap, objectNameToFieldsMap, objectIdToFieldsSetMap);

		List<SObject> foundObjects = findObjectsById(objectNameToIdMap, objectNameToFieldsMap);

		Map<Id, Map<String, List<DTO_FieldSetMember>>> objectIdToDtoMemberMap = new Map<Id, Map<String, List<DTO_FieldSetMember>>>();

		for(SObject foundObject : foundObjects)
		{
			Set<FieldSet> foundFieldSets = objectIdToFieldsSetMap.get(foundObject.Id);

			//This situation occurs when valid object Id is passed for an object with field sets, but request is passed with invalid field set name
			if(foundFieldSets == null)
			{
				continue;
			}

			Map<String, List<DTO_FieldSetMember>> dtoMemberByFieldSetMap = objectIdToDtoMemberMap.get(foundObject.Id);

			if(dtoMemberByFieldSetMap == null)
			{
				dtoMemberByFieldSetMap = new Map<String, List<DTO_FieldSetMember>>();
				objectIdToDtoMemberMap.put(foundObject.Id, dtoMemberByFieldSetMap);
			}

			for(FieldSet foundFieldSet : foundFieldSets)
			{
				String fullyQualifiedFieldSetName = UTIL_System.getNamespacePrefix(foundFieldSet.nameSpace) + foundFieldSet.name;
				List<DTO_FieldSetMember> dtoFieldSetMembers = dtoMemberByFieldSetMap.get(fullyQualifiedFieldSetName);

				if(dtoFieldSetMembers == null)
				{
					dtoFieldSetMembers = new List<DTO_FieldSetMember>();
					dtoMemberByFieldSetMap.put(fullyQualifiedFieldSetName, dtoFieldSetMembers);
				}

				addDtoFieldSetMembers(foundFieldSet, foundObject, dtoFieldSetMembers);
			}
		}

		return objectIdToDtoMemberMap;
	}

	/**
	 * @description Will setup the maps required to get the required information from object Ids and field sets provided
	 *
	 * @param recordIdToFieldSetListMap Original request with object Ids and required field set names
	 * @param objectNameToIdMap A map of object API name to the Ids request
	 * @param objectNameToFieldsMap A map of object API name to  required fields (API name)
	 * @param objectIdToFieldsSetMap A map of original Object Ids by found FieldSets (will be used to populate final response)
	 */
	private static void initialiseMaps
			(
					Map<Id, List<String>> recordIdToFieldSetListMap,
					Map<String, Set<Id>> objectNameToIdMap,
					Map<String, Set<String>> objectNameToFieldsMap,
					Map<Id, Set<FieldSet>> objectIdToFieldsSetMap
			)
	{
		for(Id recordId : recordIdToFieldSetListMap.keySet())
		{
			List<String> fieldsetNames = recordIdToFieldSetListMap.get(recordId);

			if(fieldsetNames == null || fieldsetNames.isEmpty())
			{
				continue;
			}

			String objectName = UTIL_SObjectDescribe.getObjectNameFromId(recordId);

			Map<String, FieldSet> fieldSetMap = UTIL_SObjectDescribe.getDescribe(objectName).getFieldSetsMap();

			if(fieldSetMap == null || fieldSetMap.isEmpty())
			{
				continue;
			}

			Set<Id> recordIds = objectNameToIdMap.get(objectName);

			if(recordIds == null)
			{
				recordIds = new Set<Id>();
				objectNameToIdMap.put(objectName, recordIds);
			}

			recordIds.add(recordId);

			for(String fieldSetName : fieldsetNames)
			{
				FieldSet foundFieldset = fieldSetMap.get(fieldSetName);

				if(foundFieldset == null)
				{
					continue;
				}

				Set<String> fieldSetFieldNames = getFieldNamesFromFieldSetMember(foundFieldset.fields);

				Set<String> fieldNames = objectNameToFieldsMap.get(objectName);

				if(fieldNames == null)
				{
					fieldNames = new Set<String>();
					objectNameToFieldsMap.put(objectName, fieldNames);
				}

				fieldNames.addAll(fieldSetFieldNames);

				Set<FieldSet> fieldSets = objectIdToFieldsSetMap.get(recordId);

				if(fieldSets == null)
				{
					fieldSets = new Set<FieldSet>();
					objectIdToFieldsSetMap.put(recordId, fieldSets);
				}

				fieldSets.add(foundFieldset);
			}
		}
	}

	/**
	 * @description Will retrieve all objects that have fields per original request
	 *
	 * @param objectNameToIdMap A unique list of object names and requested records
	 * @param objectNameToFieldsMap The fields per object to query
	 *
	 * @return A list of found items
	 */
	private static List<SObject> findObjectsById(Map<String, Set<Id>> objectNameToIdMap, Map<String, Set<String>> objectNameToFieldsMap)
	{
		List<SObject> foundObjects = new List<SObject>();

		for(String objectName : objectNameToIdMap.keySet())
		{
			foundObjects.addAll
					(
							QRY_Builder.selectFrom(UTIL_SObjectDescribe.getSObjectTypeByName(objectName))
									.withUserMode()
									.fields(new List<String>(objectNameToFieldsMap.get(objectName)))
									.condition('Id').isIn(UTIL_Set.toList(objectNameToIdMap.get(objectName)))
									.toList()
					);
		}
		return foundObjects;
	}

	/**
	 * @description Will add to the DTO FieldSet Member list using the record and Field Set provided
	 *
	 * @param foundFieldSet A fieldset for the given object
	 * @param foundObject An object record
	 * @param dtoFieldSetMembers List to which to add the DTO List
	 */
	private static void addDtoFieldSetMembers(FieldSet foundFieldSet, SObject foundObject, List<DTO_FieldSetMember> dtoFieldSetMembers)
	{
		for(FieldSetMember member : foundFieldSet.getFields())
		{
			DTO_FieldSetMember dtoFieldSetMember = new DTO_FieldSetMember();

			dtoFieldSetMember.fieldAPIName = member.fieldPath;
			dtoFieldSetMember.fieldLabel = member.label;
			dtoFieldSetMember.fieldSetAPIName = UTIL_System.getNamespacePrefix(foundFieldSet.nameSpace) + foundFieldSet.name;
			dtoFieldSetMember.fieldSetName = foundFieldSet.label;
			dtoFieldSetMember.fieldType = member.type.name();
			dtoFieldSetMember.fieldValue = UTIL_SObject.getFieldValue(foundObject, member.fieldPath);
			dtoFieldSetMember.isRequired = member.dbRequired || member.required;
			dtoFieldSetMember.objectName = UTIL_SObjectDescribe.getObjectNameFromType(foundFieldSet.SObjectType);

			if(dtoFieldSetMember.fieldValue != null)
			{
				switch on member.type
				{
					when REFERENCE
					{
						DescribeFieldResult fieldDescribe = UTIL_SObjectDescribe.getCachedFieldDescribe(member.SObjectField);
						dtoFieldSetMember.fieldDisplayValue = UTIL_SObject.getFieldValue(foundObject, fieldDescribe.relationshipName + UTIL_String.DOT + 'Name');
					}
					when PICKLIST
					{
						Map<String, String> picklistMap = UTIL_SObjectDescribe.getPicklistEntriesMap(member.SObjectField, false);
						dtoFieldSetMember.fieldDisplayValue = picklistMap.get(String.valueOf(dtoFieldSetMember.fieldValue));
					}
					when else
					{
						dtoFieldSetMember.fieldDisplayValue = String.valueOf(dtoFieldSetMember.fieldValue);
					}
				}
			}

			dtoFieldSetMembers.add(dtoFieldSetMember);
		}
	}

	/**
	 * @description Use the method to get 1 or more fieldSets for a specific SObjectName.
	 *
	 * @param objectNameToFieldSetListMap Map of record Id and List of fieldSets
	 *
	 * @return Map of ObjectName to Map of FieldSetAPIName with List of DTO_FieldSetMembers
	 */
	@AuraEnabled(Cacheable=true)
	public static Map<String, Map<String, List<DTO_FieldSetMember>>> getFieldSetsForObject(Map<String, List<String>> objectNameToFieldSetListMap)
	{
		Map<String, Map<String, List<DTO_FieldSetMember>>> objectNameToFieldSetMap = new Map<String, Map<String, List<DTO_FieldSetMember>>>();

		for(String objectName : objectNameToFieldSetListMap.keySet())
		{
			Map<String, List<DTO_FieldSetMember>> memberByFieldSetMap = objectNameToFieldSetMap.get(objectName);

			if(memberByFieldSetMap == null)
			{
				memberByFieldSetMap = new Map<String, List<DTO_FieldSetMember>>();
				objectNameToFieldSetMap.put(objectName, memberByFieldSetMap);
			}

			Map<String, FieldSet> fieldSetByNameMap = UTIL_SObjectDescribe.getDescribe(objectName).getFieldSetsMap();

			List<String> fieldSetNames = objectNameToFieldSetListMap.get(objectName);

			for(String fieldSetName : fieldSetNames)
			{
				FieldSet foundFieldSet = fieldSetByNameMap.get(fieldSetName);

				if(foundFieldSet == null)
				{
					continue;
				}

				List<DTO_FieldSetMember> dtoFieldSetMembers = memberByFieldSetMap.get(fieldSetName);

				if(dtoFieldSetMembers == null)
				{
					dtoFieldSetMembers = new List<DTO_FieldSetMember>();
					memberByFieldSetMap.put(fieldSetName, dtoFieldSetMembers);
				}

				addDtoFieldSetMembers(foundFieldSet, null, dtoFieldSetMembers);
			}
		}

		return objectNameToFieldSetMap;
	}

	/**
	 * @description This method is used to get the field names from fieldSetMember
	 *
	 * @param members A List of fieldSetMembers
	 *
	 * @return Set of name
	 */
	@TestVisible
	private static Set<String> getFieldNamesFromFieldSetMember(List<FieldSetMember> members)
	{
		Set<String> fieldNames = new Set<String>();

		for(FieldSetMember member : members)
		{
			fieldNames.add(member.fieldPath);
			if(member.type == DisplayType.REFERENCE)
			{
				fieldNames.add(UTIL_SObjectDescribe.getCachedFieldDescribe(member.SObjectField).relationshipName + UTIL_String.DOT + 'Name');
			}
		}

		return fieldNames;
	}

	/**
	 * @description This method is used to get the map of custom metadata developer name to custom metadata record which has the fieldSets information
	 *
	 * @param developerName The developerName of custom metadata
	 *
	 * @return Map of DeveloperName to the CustomMetadata record
	 */
	@AuraEnabled(Cacheable=true)
	public static FieldSetGroup__mdt findByDeveloperName(String developerName)
	{
		return new SEL_FieldSetGroup().findByDeveloperName(developerName);
	}

	/**
	 * @description Retrieves SObject API name using a record Id
	 *
	 * @param recordId Record Id to obtain information about
	 *
	 * @return SObject API Name
	 */
	@AuraEnabled(Cacheable=true)
	public static String getObjectNameFromId(Id recordId)
	{
		return UTIL_SObjectDescribe.getObjectNameFromId(recordId);
	}

	/**
	 * @description This wrapper class is used to store the field information
	 */
	public class DTO_FieldSetMember
	{
		/**
		 * @description stores the Label for the fields in the fieldSet
		 */
		@AuraEnabled
		public String fieldLabel {get; set;}
		/**
		 * @description stores the APIName for the fields in the fieldSet
		 */
		@AuraEnabled
		public String fieldAPIName {get; set;}
		/**
		 * @description The display value for the field, will be set when the field is storing the Id of a related object
		 */
		@AuraEnabled
		public Object fieldDisplayValue {get; set;}
		/**
		 * @description stores the value for the field in the fieldSet from the relevant SObject
		 */
		@AuraEnabled
		public Object fieldValue {get; set;}
		/**
		 * @description stores the APIName of the fieldSet
		 */
		@AuraEnabled
		public String fieldSetAPIName {get; set;}
		/**
		 * @description stores the Type of the field in the fieldset
		 */
		@AuraEnabled
		public String fieldType {get; set;}
		/**
		 * @description stores the Label of the fieldSet
		 */
		@AuraEnabled
		public String fieldSetName {get; set;}
		/**
		 * @description Required marker for the field
		 */
		@AuraEnabled
		public Boolean isRequired {get; set;}
		/**
		 * @description Object api name
		 */
		@AuraEnabled
		public String objectName {get; set;}
	}

	/**
	 * @description Contains the relevant object and field api name for FieldSetGroup__mdt
	 *
	 * @see FieldSetGroup__mdt
	 */
	public class DTO_FieldSetGroupApiNames
	{
		/**
		 * @description Contains the API name of the field
		 */
		@AuraEnabled
		public String fieldApiName {get; set;}
		/**
		 * @description Contains the API name of the object
		 */
		@AuraEnabled
		public String objectApiName {get; set;}
	}
}