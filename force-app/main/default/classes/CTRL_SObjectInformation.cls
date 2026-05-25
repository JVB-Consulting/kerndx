// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Aura-enabled controller that exposes SObject metadata (fields, record types)
 * for dynamic form rendering in Lightning components.
 *
 * @see CTRL_SObjectInformation_TEST
 *
 * @author Jason van Beukering
 *
 * @group Controllers
 *
 * @date February 2026, May 2026
 */
public inherited sharing class CTRL_SObjectInformation
{
	/**
	 * @description Retrieves field metadata for every field on the given SObject.
	 *
	 * @param objectName The SObject API name (e.g., 'Account').
	 *
	 * @return Map keyed by field API name to its metadata wrapper, or null when objectName is blank.
	 */
	@AuraEnabled(Cacheable=true)
	public static Map<String, DTO_FieldInformation> getSObjectAllFieldsInformation(String objectName)
	{
		Set<String> allFields = UTIL_SObjectDescribe.getDescribe(objectName).getFieldsMap().keySet();
		return getSObjectFieldInformation(objectName, new List<String>(allFields));
	}

	/**
	 * @description Retrieves field metadata for a specific list of fields on the given SObject.
	 *
	 * @param objectName The SObject API name.
	 * @param fieldList List of field API names to inspect.
	 *
	 * @return Map keyed by field API name to its metadata wrapper, or null when objectName is blank.
	 */
	@AuraEnabled(Cacheable=true)
	public static Map<String, DTO_FieldInformation> getSObjectFieldInformation(String objectName, List<String> fieldList)
	{
		if(String.isBlank(objectName))
		{
			return null;
		}

		Map<String, SObjectField> fieldTokensByName = UTIL_SObjectDescribe.getDescribe(objectName).getFieldsMap();
		Map<String, DTO_FieldInformation> result = new Map<String, DTO_FieldInformation>();

		for(String apiName : fieldList)
		{
			SObjectField token = fieldTokensByName.get(apiName.toLowerCase());

			if(token == null)
			{
				continue;
			}

			DescribeFieldResult describe = UTIL_SObjectDescribe.getCachedFieldDescribe(token);

			DTO_FieldInformation field = new DTO_FieldInformation();
			field.fieldLabel = describe.label;
			field.fieldType = describe.type.name();
			field.lookupObjectApiName = describe.type == DisplayType.REFERENCE
					? describe.referenceTo.iterator().next().getDescribe().name
					: null;

			result.put(describe.name, field);
		}

		return result;
	}

	/**
	 * @description Retrieves all record types defined on the given SObject.
	 *
	 * @param objectName The SObject API name.
	 *
	 * @return List of record type metadata wrappers.
	 */
	@AuraEnabled(Cacheable=true)
	public static List<DTO_RecordTypeInformation> getRecordTypes(String objectName)
	{
		List<DTO_RecordTypeInformation> items = new List<DTO_RecordTypeInformation>();

		for(RecordTypeInfo info : UTIL_SObjectDescribe.getDescribe(objectName).getDescribe().recordTypeInfos)
		{
			DTO_RecordTypeInformation item = new DTO_RecordTypeInformation();
			item.name = info.developerName;
			item.label = info.name;
			item.available = info.isAvailable();
			item.active = info.isActive();
			item.master = info.isMaster();
			item.recordTypeId = info.recordTypeId;
			items.add(item);
		}

		return items;
	}

	/**
	 * @description Wrapper for a single SObject field's display metadata.
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
	 * @description Wrapper for a single record type's metadata.
	 */
	public class DTO_RecordTypeInformation
	{
		/**
		 * @description The developer (API) name of the record type.
		 */
		@AuraEnabled
		public String name;
		/**
		 * @description The UI label of the record type.
		 */
		@AuraEnabled
		public String label;
		/**
		 * @description Whether the record type is available to the running user.
		 */
		@AuraEnabled
		public Boolean available;
		/**
		 * @description Whether the record type is currently active.
		 */
		@AuraEnabled
		public Boolean active;
		/**
		 * @description Whether this is the master (default) record type.
		 */
		@AuraEnabled
		public Boolean master;
		/**
		 * @description The 18-character record type ID.
		 */
		@AuraEnabled
		public Id recordTypeId;
	}
}