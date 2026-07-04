// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Generic SObject Search Controller
 *
 * @see CTRL_Search_TEST
 *
 * @author Jason van Beukering
 *
 * @group Controllers
 *
 * @date February 2026, June 2026
 */
public inherited sharing class CTRL_Search implements IF_Search
{
	private static final Integer MAXIMUM_NUMBER_OF_RESULTS = 20;
	/**
	 * @description Record Id
	 */
	@TestVisible
	private static final String PARAMETER_RECORD_ID = 'recordId';
	/**
	 * @description List of fields to return from search
	 */
	@TestVisible
	private static final String PARAMETER_SELECT_FIELDS = 'selectFields';
	/**
	 * @description SObject to search on
	 */
	public static final String PARAMETER_OBJECT_NAME = 'objectName';
	/**
	 * @description Maximum number of results to return from search
	 */
	@TestVisible
	private static final String PARAMETER_MAXIMUM_NUMBER_OF_RESULTS = 'maximumNumberOfResults';

	/**
	 * @description Generic search controller method
	 *
	 * @param searchTerm searchTerm Search Term to be used for search/query
	 * @param searchParameters parameters to search on
	 *
	 * @return Response object
	 */
	@AuraEnabled(Cacheable=true)
	public static Object search(Object searchTerm, Map<String, Object> searchParameters)
	{
		Object result;
		Id recordId = (Id)searchParameters.get(PARAMETER_RECORD_ID);

		if(String.isNotBlank(recordId))
		{
			String objectName = UTIL_SObjectDescribe.getObjectNameFromId(recordId);

			result = QRY_Builder.selectFrom(UTIL_SObjectDescribe.getSObjectTypeByName(objectName))
					.withUserMode()
					.fields(new List<String>(getValidSelectFields(objectName, searchParameters)))
					.condition('Id').equals(recordId)
					.getFirst();
		}
		else
		{
			String objectName = (String)searchParameters.get(PARAMETER_OBJECT_NAME);

			if(String.isNotBlank(objectName))
			{
				Integer maximumNumberOfResults = (Integer)searchParameters.get(PARAMETER_MAXIMUM_NUMBER_OF_RESULTS);

				maximumNumberOfResults = maximumNumberOfResults ?? MAXIMUM_NUMBER_OF_RESULTS;

				if(String.isNotBlank((String)searchTerm))
				{
					result = findSObjectBySearchTerm(objectName, (String)searchTerm, getValidSelectFields(objectName, searchParameters), maximumNumberOfResults);
				}
			}
		}

		return result;
	}

	/**
	 * @description Will return a list of valid object fields to query either using what's provided through parameters or a default set
	 *
	 * @param objectName The Api Name of the object
	 * @param searchParameters parameters containing (potentially fields to search on
	 *
	 * @return A list of fields valid for the object
	 */
	private static Set<String> getValidSelectFields(String objectName, Map<String, Object> searchParameters)
	{
		List<String> selectFields = UTIL_List.filterStrings((List<Object>)searchParameters.get(PARAMETER_SELECT_FIELDS));

		if(UTIL_List.isEmpty(selectFields))
		{
			selectFields = new List<String>
			{
					'Id', 'Name', 'OwnerId', 'RecordTypeId'
			};
		}

		return UTIL_SObjectDescribe.extractValidObjectFieldNames(objectName, UTIL_Set.toSet(selectFields));
	}

	/**
	 * @description Returns a list of SObjects based on a search term and which SObject it is searching
	 *
	 * @param objectName SObject API name to search through
	 * @param searchTerm Search term to match the Name fields of the SObject
	 * @param selectFields Comma separated list of field API names to retrieve from the query
	 * @param maximumNumberOfResults Maximum number of records to return
	 *
	 * @return List of SObjects whose Name fields is contain the search term (uses SOSL search)
	 */
	private static List<SObject> findSObjectBySearchTerm(String objectName, String searchTerm, Set<String> selectFields, Integer maximumNumberOfResults)
	{
		SObjectType objectType = UTIL_SObjectDescribe.getSObjectTypeByName(objectName);

		if(objectType == null)
		{
			return new List<SObject>();
		}

		String fieldList = UTIL_String.join(selectFields, UTIL_String.COMMA) ?? 'Id';
		String query = 'FIND :searchTerm IN NAME FIELDS RETURNING '
				+ UTIL_SObjectDescribe.getObjectNameFromType(objectType) + ' (' + fieldList + ' LIMIT ' + maximumNumberOfResults + ' OFFSET 0)';

		List<List<SObject>> searchResults = Search.query(query, AccessLevel.USER_MODE);
		return searchResults.isEmpty() ? new List<SObject>() : searchResults.iterator().next();
	}
}