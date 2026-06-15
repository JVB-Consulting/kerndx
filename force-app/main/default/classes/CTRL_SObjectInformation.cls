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
	public static Map<String, UTIL_SObjectDescribe.DTO_FieldInformation> getSObjectAllFieldsInformation(String objectName)
	{
		return UTIL_SObjectDescribe.getAllFieldInformation(objectName);
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
	public static Map<String, UTIL_SObjectDescribe.DTO_FieldInformation> getSObjectFieldInformation(String objectName, List<String> fieldList)
	{
		return UTIL_SObjectDescribe.getFieldInformation(objectName, fieldList);
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