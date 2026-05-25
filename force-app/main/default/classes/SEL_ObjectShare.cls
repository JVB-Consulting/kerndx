// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Utility class for working with SObject Share records generically across all SObject types.
 * Provides metadata about share objects and creates share record instances.
 *
 * @see SEL_ObjectShare_TEST
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date February 2026, May 2026
 */
public inherited sharing class SEL_ObjectShare
{
	/**
	 * @description Represents the approximate Heap size for a standard Share SObject,
	 * this is based on test code that measured the memory usage when creating shares.
	 *
	 * @see Foobar__Share
	 */
	private static final Integer HEAP_SIZE_STANDARD_SHARE = 110;

	/**
	 * @description Represents the approximate Heap size for a special Share SObject,
	 * this is based on test code that measured the memory usage when creating shares.
	 *
	 * @see AccountShare
	 */
	private static final Integer HEAP_SIZE_SPECIAL_SHARE = 125;

	/**
	 * @description Reference field name for associated parent object.
	 */
	private static final String REFERENCE_PARENT = 'Parent';

	/**
	 * @description Store the Share label.
	 */
	private static final String FIELD_SHARE = 'Share';

	/**
	 * @description Any object in this list needs to be treated differently when calculating Share object name and fields.
	 */
	private static final Set<String> OBJECTS_WITH_SPECIAL_SHARES = new Set<String>
	{
			'Asset',
			'Campaign',
			'Case',
			'Contact',
			'Individual',
			'Lead',
			'Opportunity',
			'Account',
			'User'
	};

	/**
	 * @description Field API name of AccessLevel for custom object share records.
	 */
	public static final String FIELD_ACCESS_LEVEL = 'AccessLevel';

	/**
	 * @description Provides no access to an object via object share.
	 */
	public static final String ACCESS_LEVEL_NONE = 'None';

	/**
	 * @description Field API name of OpportunityAccessLevel.
	 */
	public static final String FIELD_OPPORTUNITY_ACCESS_LEVEL = 'OpportunityAccessLevel';

	/**
	 * @description Field API name of RowCause.
	 */
	public static final String FIELD_ROW_CAUSE = 'RowCause';

	/**
	 * @description Field API name of UserOrGroupId.
	 */
	public static final String FIELD_USER_OR_GROUP_ID = 'UserOrGroupId';

	/**
	 * @description Object API name of AccountShare.
	 */
	public static final String OBJECT_ACCOUNT_SHARE = 'AccountShare';

	/**
	 * @description RowCause setting that will be used to create ShareObject records.
	 */
	public static final String ROW_CAUSE_MANUAL = 'Manual';

	/**
	 * @description Will return all the relevant share field describes for an Object based on their Id.
	 *
	 * @param parentId Refers to the related Object Id
	 *
	 * @return DTO containing all the relevant information
	 */
	public static DTO_ObjectShareDescribe getShareDescribe(Id parentId)
	{
		return new DTO_ObjectShareDescribe(UTIL_SObjectDescribe.getSObjectTypeById(parentId));
	}

	/**
	 * @description DTO that can be used to retrieve share object describe information.
	 */
	public class DTO_ObjectShareDescribe
	{
		/**
		 * @description Contains the accessLevel Field Api name.
		 */
		public String accessLevel;

		/**
		 * @description Contains the related record id Field Api name.
		 */
		public String parentIdFieldName;

		/**
		 * @description Contains the related record Object Field name.
		 */
		public String parentObjectFieldName;

		/**
		 * @description Contains the Api name of the Share object.
		 */
		public String shareObjectName;

		/**
		 * @description Contains the anticipated heap size for a newly created Object Share,
		 * used for bulk processing scenarios where we need to ensure we don't breach memory limits.
		 */
		public Integer estimatedHeapSize;

		/**
		 * @description Will initialise all the relevant information for the Share object related to the given object api name.
		 * <p/>
		 * https:///developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_associated_objects_share.htm
		 *
		 * @param objectType Type of an SObject that has a related share object
		 */
		public DTO_ObjectShareDescribe(SObjectType objectType)
		{
			if(objectType != null)
			{
				String objectApiName = UTIL_SObjectDescribe.getObjectNameFromType(objectType);

				Boolean isObjectWithSpecialShare = OBJECTS_WITH_SPECIAL_SHARES.contains(objectApiName);

				accessLevel = isObjectWithSpecialShare ? objectApiName + FIELD_ACCESS_LEVEL : FIELD_ACCESS_LEVEL;
				estimatedHeapSize = isObjectWithSpecialShare ? HEAP_SIZE_SPECIAL_SHARE : HEAP_SIZE_STANDARD_SHARE;
				parentObjectFieldName = isObjectWithSpecialShare ? objectApiName : REFERENCE_PARENT;
				parentIdFieldName = parentObjectFieldName + 'Id';
				shareObjectName = UTIL_SObjectDescribe.getDescribe(objectType).getDescribe().custom ?
						UTIL_String.replace(objectApiName, UTIL_SObjectDescribe.CUSTOM_FIELD_SUFFIX, UTIL_SObjectDescribe.CUSTOM_OBJECT_SHARE_SUFFIX) :
						objectApiName + FIELD_SHARE;
			}
		}

		/**
		 * @description Will create a new instance of a Share Object.
		 *
		 * @return Newly created item
		 */
		public SObject newShareObject()
		{
			SObject shareObject;

			if(String.isNotBlank(shareObjectName))
			{
				shareObject = UTIL_SObjectDescribe.getSObjectTypeByName(shareObjectName).newSObject();
			}

			return shareObject;
		}
	}
}