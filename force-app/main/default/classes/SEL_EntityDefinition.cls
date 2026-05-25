// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Selector for the EntityDefinition SObject. Provides default field configuration
 * and query methods for EntityDefinition records.
 *
 * @see SEL_Base
 * @see SEL_EntityDefinition_TEST
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date February 2026, May 2026
 */
public inherited sharing class SEL_EntityDefinition extends SEL_Base
{
	/**
	 * @description Picklist value of Private for Sharing Model.
	 */
	@SuppressWarnings('PMD.AvoidHardcodedCredentialsInFieldDecls')
	public static final String SHARING_MODEL_PRIVATE = 'Private';

	/**
	 * @description Picklist value of Read for Sharing Model.
	 */
	public static final String SHARING_MODEL_READ = 'Read';

	/**
	 * @description All the valid sharing models for objects.
	 */
	private static final Set<String> VALID_SHARING_MODEL = new Set<String>
	{
			SHARING_MODEL_PRIVATE,
			SHARING_MODEL_READ
	};

	/**
	 * @description Constructs an EntityDefinition selector with the EntityDefinition SObjectType.
	 */
	public SEL_EntityDefinition()
	{
		super(EntityDefinition.SObjectType);
	}

	/**
	 * @description Returns the core fields for EntityDefinition queries.
	 *
	 * @return List of EntityDefinition SObjectField tokens
	 */
	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>
		{
				EntityDefinition.InternalSharingModel,
				EntityDefinition.Label,
				EntityDefinition.QualifiedApiName
		};
	}

	/**
	 * @description Framework-internal schema selector — always runs in `AccessLevel.SYSTEM_MODE`
	 * regardless of the `UserModeQueries_Enabled` feature flag. EntityDefinition is Setup metadata
	 * that running users typically can't read, so USER_MODE reads would return empty and the
	 * framework's sharing-model inspection / metadata-relationship resolution would silently break.
	 *
	 * @return `true` — this selector requires SYSTEM_MODE.
	 */
	public override Boolean systemModeRequired()
	{
		return true;
	}

	/**
	 * @description Returns a map of shareable entity definitions keyed by QualifiedApiName.
	 * Only entities with Private or Read internal sharing model are included.
	 *
	 * @param objectApiNames Set of object API names to query
	 *
	 * @return A map by name - Map of QualifiedApiName to EntityDefinition
	 */
	public Map<String, EntityDefinition> getShareableEntityByName(Set<String> objectApiNames)
	{
		List<EntityDefinition> foundDefinitions = findShareableEntityByName(objectApiNames);

		Map<String, EntityDefinition> shareableEntityByNameMap = new Map<String, EntityDefinition>();

		for(EntityDefinition foundDefinition : foundDefinitions)
		{
			if(VALID_SHARING_MODEL.contains(foundDefinition.InternalSharingModel))
			{
				shareableEntityByNameMap.put(foundDefinition.QualifiedApiName, foundDefinition);
			}
		}

		return shareableEntityByNameMap;
	}

	/**
	 * @description Finds shareable entity definitions by their qualified API names.
	 * Filters to entities that are ID-enabled, searchable, and triggerable.
	 *
	 * @param objectApiNames Set of object API names to query
	 *
	 * @return List of matching EntityDefinition records
	 */
	@TestVisible
	private List<EntityDefinition> findShareableEntityByName(Set<String> objectApiNames)
	{
		return query
				.condition(EntityDefinition.IsIdEnabled).equals(true)
				.condition(EntityDefinition.IsSearchable).equals(true)
				.condition(EntityDefinition.IsTriggerable).equals(true)
				.condition(EntityDefinition.QualifiedApiName).isIn(new List<String>(objectApiNames))
				.toList();
	}

	/**
	 * @description Finds entity definitions for standard platform events. Excludes Change Data Capture events.
	 *
	 * @return List of standard platform event EntityDefinition records
	 */
	public List<EntityDefinition> getAllStandardPlatformEvents()
	{
		final String changeEventSuffix = 'ChangeEvent';

		List<EntityDefinition> foundEntities = query
				.condition(EntityDefinition.IsCustomizable).equals(false)
				.condition(EntityDefinition.IsEverCreatable).equals(true)
				.condition(EntityDefinition.QualifiedApiName).endsWith('Event')
				.orderBy(EntityDefinition.Label).ascending()
				.toList();

		List<EntityDefinition> platformEventDefinitions = new List<EntityDefinition>();

		for(EntityDefinition foundEntity : foundEntities)
		{
			if(!foundEntity.QualifiedApiName.endsWith(changeEventSuffix))
			{
				platformEventDefinitions.add(foundEntity);
			}
		}

		return platformEventDefinitions;
	}

	/**
	 * @description Finds entity definitions for custom platform events.
	 *
	 * @return List of custom platform event EntityDefinition records
	 */
	public List<EntityDefinition> getAllCustomPlatformEvents()
	{
		return query
				.condition(EntityDefinition.KeyPrefix).startsWith('e')
				.orderBy(EntityDefinition.Label).ascending()
				.toList();
	}

	/**
	 * @description Finds entity definitions for standard Change Data Capture events.
	 *
	 * @return List of standard Change Data Capture EntityDefinition records
	 */
	public List<EntityDefinition> getAllStandardChangeCaptureEvents()
	{
		return findByPublisher('CDC');
	}

	/**
	 * @description Finds entity definitions for custom Change Data Capture events.
	 *
	 * @return List of custom Change Data Capture EntityDefinition records
	 */
	public List<EntityDefinition> getAllCustomChangeCaptureEvents()
	{
		return findByPublisher('<local>');
	}

	/**
	 * @description Finds entity definitions with a particular publisher Id.
	 *
	 * @param publisherId The value to filter on
	 *
	 * @return List of matching EntityDefinition records
	 */
	private List<EntityDefinition> findByPublisher(String publisherId)
	{
		return query
				.condition(EntityDefinition.PublisherId).equals(publisherId)
				.toList();
	}

	/**
	 * @description Finds entity definitions by DurableId. Used to resolve the EntityDefinition
	 * durable Ids stored on CMDT MetadataRelationship fields (e.g., `MaskingTarget__mdt.SObjectType__c`)
	 * back to SObject API names without paying the platform's slow MetadataRelationship traversal
	 * penalty. A direct `WHERE DurableId IN :durableIds` clause is a single-digit-millisecond query
	 * even on cold cache.
	 *
	 * @param durableIds Set of EntityDefinition DurableId values to resolve.
	 *
	 * @return List of matching EntityDefinition records with DurableId + QualifiedApiName populated.
	 */
	public List<EntityDefinition> findByDurableIds(Set<String> durableIds)
	{
		if(durableIds == null || durableIds.isEmpty())
		{
			return new List<EntityDefinition>();
		}

		return query
				.addField(EntityDefinition.DurableId)
				.condition(EntityDefinition.DurableId).isIn(new List<String>(durableIds))
				.toList();
	}
}