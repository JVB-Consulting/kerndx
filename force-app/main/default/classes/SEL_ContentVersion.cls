// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Selector for the ContentVersion object. Provides query methods for retrieving
 * content versions by publishing location, content document, and workspace folders.
 *
 * @see SEL_Base
 * @see SEL_ContentVersion_TEST
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date February 2026, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * List<ContentVersion> versions = new SEL_ContentVersion().findByFirstPublishLocationId(recordId);
 * List<ContentVersion> latest = new SEL_ContentVersion().findLatestByContentDocumentId(documentIds);
 * ContentVersion version = (ContentVersion)new SEL_ContentVersion().findById(versionId);
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class SEL_ContentVersion extends SEL_Base
{
	/**
	 * @description File extension for text files.
	 */
	public static final String TEXT_FILE_EXTENSION = '.txt';

	/**
	 * @description Will return true if the object can be created by the current user, false otherwise.
	 */
	public static Boolean isCreateable
	{
		get
		{
			return ContentVersion.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).isCreateable();
		}
	}

	/**
	 * @description Constructs a new SEL_ContentVersion selector instance.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * SEL_ContentVersion instance = new SEL_ContentVersion();
	 * ```
	 */
	global SEL_ContentVersion()
	{
		super(ContentVersion.SObjectType);
	}

	/**
	 * @description Returns the default fields for ContentVersion queries.
	 *
	 * @return List of SObjectField tokens to include in queries.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<SObjectField> result = instance.getFields();
	 * ```
	 */
	global override List<SObjectField> getFields()
	{
		return new List<SObjectField>
		{
				ContentVersion.Checksum,
				ContentVersion.ContentBodyId,
				ContentVersion.ContentDocumentId,
				ContentVersion.ContentLocation,
				ContentVersion.ContentSize,
				ContentVersion.ContentUrl,
				ContentVersion.Description,
				ContentVersion.ExternalDataSourceId,
				ContentVersion.ExternalDocumentInfo1,
				ContentVersion.ExternalDocumentInfo2,
				ContentVersion.FeaturedContentBoost,
				ContentVersion.FeaturedContentDate,
				ContentVersion.FileExtension,
				ContentVersion.FileType,
				ContentVersion.FirstPublishLocationId,
				ContentVersion.IsAssetEnabled,
				ContentVersion.IsLatest,
				ContentVersion.IsMajorVersion,
				ContentVersion.NegativeRatingCount,
				ContentVersion.Origin,
				ContentVersion.OwnerId,
				ContentVersion.PathOnClient,
				ContentVersion.PositiveRatingCount,
				ContentVersion.PublishStatus,
				ContentVersion.RatingCount,
				ContentVersion.ReasonForChange,
				ContentVersion.SharingOption,
				ContentVersion.SharingPrivacy,
				ContentVersion.SystemModstamp,
				ContentVersion.TagCsv,
				ContentVersion.TextPreview,
				ContentVersion.Title,
				ContentVersion.VersionData,
				ContentVersion.VersionNumber
		};
	}

	/**
	 * @description Framework-internal schema selector — always runs in `AccessLevel.SYSTEM_MODE`
	 * regardless of the `UserModeQueries_Enabled` feature flag. ContentVersion reads are used by
	 * framework internals (log attachment resolution, asset lookup) where the running user may
	 * not have sharing access to content published by another user, so USER_MODE reads would
	 * return scoped-out results and attachments would appear missing.
	 *
	 * @return `true` — this selector requires SYSTEM_MODE.
	 */
	public override Boolean systemModeRequired()
	{
		return true;
	}

	/**
	 * @description Retrieves the latest ContentVersion records linked to the specified FirstPublishLocationId.
	 *
	 * @param firstPublishLocationId The ID of the location where the content version was first published.
	 *
	 * @return List of the latest ContentVersion records associated with the specified location.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<ContentVersion> result = instance.findByFirstPublishLocationId(recordId);
	 * ```
	 */
	global List<ContentVersion> findByFirstPublishLocationId(Id firstPublishLocationId)
	{
		return findByFirstPublishLocationId(new Set<Id> {firstPublishLocationId});
	}

	/**
	 * @description Retrieves the latest ContentVersion records linked to the specified FirstPublishLocationId values.
	 *
	 * @param firstPublishLocationIds Set of IDs for the locations where the content versions were first published.
	 *
	 * @return List of ContentVersion records found for the specified locations.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<ContentVersion> result = instance.findByFirstPublishLocationId(recordIds);
	 * ```
	 */
	global List<ContentVersion> findByFirstPublishLocationId(Set<Id> firstPublishLocationIds)
	{
		return query
				.condition(ContentVersion.FirstPublishLocationId).isIn(new List<Id>(firstPublishLocationIds))
				.condition(ContentVersion.IsLatest).equals(true)
				.toList();
	}

	/**
	 * @description Retrieves the latest ContentVersion records for the specified ContentDocument IDs.
	 *
	 * @param contentDocumentIds Set of Content Document IDs for which to retrieve the latest content versions.
	 *
	 * @return A list of the latest ContentVersion records corresponding to each provided ContentDocument ID.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<ContentVersion> result = instance.findLatestByContentDocumentId(recordIds);
	 * ```
	 */
	global List<ContentVersion> findLatestByContentDocumentId(Set<Id> contentDocumentIds)
	{
		if(contentDocumentIds.isEmpty())
		{
			return new List<ContentVersion>();
		}

		return query
				.condition(ContentVersion.ContentDocumentId).isIn(new List<Id>(contentDocumentIds))
				.condition(ContentVersion.IsLatest).equals(true)
				.toList();
	}

	/**
	 * @description Retrieves all ContentVersion records in the system.
	 * This method only returns data when called during a test context.
	 *
	 * @return A list of all ContentVersion records if in a test context; otherwise, returns an empty list.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<ContentVersion> allVersions = new SEL_ContentVersion().getAll();
	 * ```
	 */
	global List<ContentVersion> getAll()
	{
		return Test.isRunningTest() ? toList() : new List<ContentVersion>();
	}
}