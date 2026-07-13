// SPDX-License-Identifier: BUSL-1.1
// Portions adapted from streaming-monitor (https://github.com/pozil/streaming-monitor),
// Copyright (c) Philippe Ozil (CC0-1.0 — rights waived): the streaming channel-discovery query
// methods getAllStandardPlatformEvents, getAllCustomPlatformEvents and getAllChangeCaptureEvents
// derive from his controller's inline SOQL. The remaining selector methods are original KernDX work.
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
 * @date February 2026, July 2026
 */
public inherited sharing class SEL_EntityDefinition extends SEL_Base
{
	/**
	 * @description Publisher Id under which every Change Data Capture entity — standard and custom
	 * alike — is registered. Standard change events do not use a separate `CDC` publisher.
	 */
	private static final String PUBLISHER_ID_SYSTEM = 'System';

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
		List<EntityDefinition> foundEntities = query
				.condition(EntityDefinition.IsCustomizable).equals(false)
				.condition(EntityDefinition.IsEverCreatable).equals(true)
				.condition(EntityDefinition.QualifiedApiName).endsWith('Event')
				.orderBy(EntityDefinition.Label).ascending()
				.toList();

		List<EntityDefinition> platformEventDefinitions = new List<EntityDefinition>();

		for(EntityDefinition foundEntity : foundEntities)
		{
			if(!foundEntity.QualifiedApiName.endsWith(UTIL_SObjectDescribe.CHANGE_EVENT_SUFFIX))
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
	 * @description Finds entity definitions for all Change Data Capture events — both standard
	 * (for example `AccountChangeEvent`) and custom (for example `Foobar__ChangeEvent`). Every
	 * ChangeEvent entity, standard or custom, is registered under the `System` publisher with the
	 * same fixed capability shape (Apex-triggerable, not customizable, not searchable, not
	 * queryable), so a single shape query returns the whole set. There is deliberately no second
	 * `PublisherId = 'CDC'` query: standard change events publish under `System`, not `CDC`
	 * (verified in both a namespace-free dev org and a managed subscriber org, where the `CDC`
	 * publisher matches no rows), so that query would return nothing and only spend SOQL.
	 *
	 * The `endsWith('ChangeEvent')` (`LIKE '%ChangeEvent'`) predicate is intentionally broad enough
	 * to match both classes; callers distinguish custom from standard by the `__ChangeEvent` suffix
	 * (`UTIL_SObjectDescribe.CUSTOM_CHANGE_EVENT_SUFFIX`). The `QualifiedApiName` is always handed to
	 * the caller verbatim and never rewritten — a ChangeEvent's channel api name is the
	 * `QualifiedApiName` itself, so reconstructing it (for example from a `__c` base) would silently
	 * drop channels.
	 *
	 * @return All standard and custom Change Data Capture EntityDefinition records, ordered by label.
	 */
	public List<EntityDefinition> getAllChangeCaptureEvents()
	{
		return query
				.condition(EntityDefinition.PublisherId).equals(PUBLISHER_ID_SYSTEM)
				.condition(EntityDefinition.IsApexTriggerable).equals(true)
				.condition(EntityDefinition.IsCustomizable).equals(false)
				.condition(EntityDefinition.IsSearchable).equals(false)
				.condition(EntityDefinition.IsQueryable).equals(false)
				.condition(EntityDefinition.QualifiedApiName).endsWith(UTIL_SObjectDescribe.CHANGE_EVENT_SUFFIX)
				.orderBy(EntityDefinition.Label).ascending()
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

	/**
	 * @description Finds the SObjects an administrator can choose to analyze in the Data Masking Advisor:
	 * every customizable entity that can also host an Apex trigger, ordered by label. The `IsCustomizable`
	 * filter excludes system and setup-only entities; the `IsTriggerable` filter additionally excludes objects
	 * the framework cannot mask — masking is applied through the trigger framework, so a non-triggerable object
	 * (for example PricebookEntry, custom metadata types, or custom settings) can never be masked and must not
	 * be offered. `NamespacePrefix` is projected so the advisor can scope its custom-object coverage scan to
	 * the subscriber's own (un-namespaced) objects, treating managed-package objects as an explicit opt-in.
	 *
	 * @return Customizable, triggerable EntityDefinition records ordered by label.
	 */
	public List<EntityDefinition> findSelectableObjects()
	{
		return query
				.addField(EntityDefinition.NamespacePrefix)
				.condition(EntityDefinition.IsCustomizable).equals(true)
				.condition(EntityDefinition.IsTriggerable).equals(true)
				.orderBy(EntityDefinition.Label).ascending()
				.toList();
	}
}