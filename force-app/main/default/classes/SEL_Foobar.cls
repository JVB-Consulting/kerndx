// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Selector for the Foobar__c SObject. Provides query methods and field/metadata
 * constants for the framework's test data object.
 *
 * @see SEL_Base
 * @see SEL_Foobar_TEST
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
 * Foobar__c record = (Foobar__c)new SEL_Foobar().findById(recordId);
 * List<Foobar__c> children = new SEL_Foobar().findByParentId(parentId);
 * List<Foobar__c> records = new SEL_Foobar().findByField(Foobar__c.Picklist__c, 'Active');
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class SEL_Foobar extends SEL_Base
{
	/**
	 * @description API Name for the Checkbox field
	 */
	@TestVisible
	private static final String FIELD_CHECK_BOX = Foobar__c.Checkbox__c.getDescribe().name;
	/**
	 * @description API Name for the Currency field
	 */
	@TestVisible
	private static final String FIELD_CURRENCY = Foobar__c.Currency__c.getDescribe().name;
	/**
	 * @description API Name for the Date field
	 */
	@TestVisible
	private static final String FIELD_DATE = Foobar__c.Date__c.getDescribe().name;
	/**
	 * @description API Name for the Datetime field
	 */
	@TestVisible
	private static final String FIELD_DATETIME = Foobar__c.Datetime__c.getDescribe().name;
	/**
	 * @description API Name for the Decimal field
	 */
	@TestVisible
	private static final String FIELD_DECIMAL = Foobar__c.NumberDecimal__c.getDescribe().name;
	/**
	 * @description API Name for the Email field
	 */
	@TestVisible
	private static final String FIELD_EMAIL = Foobar__c.Email__c.getDescribe().name;
	/**
	 * @description API Name for the Geolocation field
	 */
	@TestVisible
	private static final String FIELD_GEOLOCATION = Foobar__c.Geolocation__c.getDescribe().name;
	/**
	 * @description API Name for the Integer field
	 */
	@TestVisible
	private static final String FIELD_INTEGER = Foobar__c.NumberInteger__c.getDescribe().name;
	/**
	 * @description API Name for the Lookup field
	 */
	@TestVisible
	private static final String FIELD_LOOKUP = Foobar__c.Lookup__c.getDescribe().name;
	/**
	 * @description API Name for the Name field
	 */
	@TestVisible
	private static final String FIELD_NAME = 'Name';
	/**
	 * @description API Name for the Percent field
	 */
	@TestVisible
	private static final String FIELD_PERCENT = Foobar__c.Percent__c.getDescribe().name;
	/**
	 * @description API Name for the Phone field
	 */
	@TestVisible
	private static final String FIELD_PHONE = Foobar__c.Phone__c.getDescribe().name;
	/**
	 * @description API Name for the Picklist field
	 */
	@TestVisible
	private static final String FIELD_PICKLIST = Foobar__c.Picklist__c.getDescribe().name;
	/**
	 * @description API Name for the PicklistMultiSelect field
	 */
	@TestVisible
	private static final String FIELD_PICKLIST_MULTI_SELECT = Foobar__c.PicklistMultiSelect__c.getDescribe().name;
	/**
	 * @description API Name for the Text field
	 */
	@TestVisible
	private static final String FIELD_TEXT = Foobar__c.Text__c.getDescribe().name;
	/**
	 * @description API Name for the TextArea field
	 */
	@TestVisible
	private static final String FIELD_TEXT_AREA = Foobar__c.TextArea__c.getDescribe().name;
	/**
	 * @description API Name for the URL field
	 */
	@TestVisible
	private static final String FIELD_URL = Foobar__c.URL__c.getDescribe().name;
	/**
	 * @description API Name for the CreatedById field
	 */
	@TestVisible
	private static final String FIELD_CREATED_BY_ID = Foobar__c.CreatedById.getDescribe().name;
	/**
	 * @description API Name for the LastModifiedById field
	 */
	@TestVisible
	private static final String FIELD_LAST_MODIFIED_BY_ID = Foobar__c.LastModifiedById.getDescribe().name;
	/**
	 * @description API Name for the OwnerId field
	 */
	@TestVisible
	private static final String FIELD_OWNER_ID = Foobar__c.OwnerId.getDescribe().name;

	/**
	 * @description API name for the Foobar__c object
	 */
	@TestVisible
	private static final String OBJECT_NAME = UTIL_SObjectDescribe.getObjectNameFromType(Foobar__c.SObjectType);
	/**
	 * @description API Name for the parent lookup relationship name + Name field
	 */
	@TestVisible
	private static final String FIELD_PARENT_NAME = Foobar__c.Lookup__c.getDescribe().getRelationshipName() + UTIL_String.DOT + 'Name';
	/**
	 * @description Fieldset for audit-related fields
	 */
	@TestVisible
	private static final String FIELDSET_AUDIT = UTIL_System.getManagedPackageNamespacePrefix() + 'Audit';
	/**
	 * @description Fieldset for person-related fields
	 */
	@TestVisible
	private static final String FIELDSET_PERSON = UTIL_System.getManagedPackageNamespacePrefix() + 'Person';
	/**
	 * @description Relationship name for child Foobar__c records via Lookup__c field.
	 * Uses namespace prefix for managed package compatibility.
	 */
	@TestVisible
	private static final String RELATIONSHIP_FOOBARS = UTIL_System.getManagedPackageNamespacePrefix() + 'Foobars__r';
	/**
	 * @description Relationship name for the parent Lookup__c field
	 */
	@TestVisible
	private static final String RELATIONSHIP_LOOKUP = Foobar__c.Lookup__c.getDescribe().getRelationshipName();
	/**
	 * @description Default record type for Foobar__c objects
	 */
	public static final String RT_DEFAULT = 'DefaultFoobar';

	/**
	 * @description Constructs a Foobar selector.
	 *
	 * @example
	 * ```apex
	 * SEL_Foobar instance = new SEL_Foobar();
	 * ```
	 */
	public SEL_Foobar()
	{
		super(Foobar__c.SObjectType);
	}

	/**
	 * @description Framework test-fixture selector — always runs in `AccessLevel.SYSTEM_MODE`
	 * regardless of the `UserModeQueries_Enabled` feature flag. `Foobar__c` is a framework-owned
	 * fixture object shipped with the package for internal testing; it is never subscriber-facing
	 * data, and tests must be able to read it regardless of the running user's FLS. Under
	 * `USER_MODE`, managed-package validation runs tests as a synthetic user without FLS on
	 * `kern__` fields and these queries would fail with "No such column" errors.
	 *
	 * @return `true` — this selector requires SYSTEM_MODE.
	 */
	public override Boolean systemModeRequired()
	{
		return true;
	}

	/**
	 * @description Returns the core fields for Foobar__c queries.
	 *
	 * @return List of Foobar__c SObjectField tokens
	 *
	 * @example
	 * ```apex
	 * List<SObjectField> result = instance.getFields();
	 * ```
	 */
	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>
		{
				Foobar__c.Checkbox__c,
				Foobar__c.CreatedById,
				Foobar__c.CreatedDate,
				Foobar__c.Date__c,
				Foobar__c.Datetime__c,
				Foobar__c.Email__c,
				Foobar__c.ExternalId__c,
				Foobar__c.IsDeleted,
				Foobar__c.LastModifiedById,
				Foobar__c.LastModifiedDate,
				Foobar__c.Lookup__c,
				Foobar__c.Name,
				Foobar__c.NumberDecimal__c,
				Foobar__c.NumberInteger__c,
				Foobar__c.OwnerId,
				Foobar__c.Phone__c,
				Foobar__c.Picklist__c,
				Foobar__c.RecordTypeId,
				Foobar__c.Text__c
		};
	}

	/**
	 * @description Returns relationship traversal field paths for Foobar__c queries.
	 *
	 * @return List of field path strings including parent relationship fields
	 *
	 * @example
	 * ```apex
	 * List<String> result = instance.getFieldPaths();
	 * ```
	 */
	public override List<String> getFieldPaths()
	{
		return new List<String> {FIELD_PARENT_NAME};
	}

	/**
	 * @description Retrieves all Foobar__c records. Only executes in test context to prevent
	 * full-table scans in production.
	 *
	 * @return List of all Foobar__c records in test context, empty list in production
	 *
	 * @example
	 * ```apex
	 * List<Foobar__c> result = instance.getAll();
	 * ```
	 */
	public List<Foobar__c> getAll()
	{
		return !Test.isRunningTest() ? new List<Foobar__c>() : query.toList();
	}

	/**
	 * @description Finds Foobar__c records by parent Lookup ID (self-referential relationship).
	 *
	 * @param parentId The parent Foobar__c ID to filter by
	 *
	 * @return List of Foobar__c records related to the parent
	 *
	 * @example
	 * ```apex
	 * List<Foobar__c> result = instance.findByParentId(recordId);
	 * ```
	 */
	public List<Foobar__c> findByParentId(Id parentId)
	{
		return findByField(Foobar__c.Lookup__c, parentId);
	}
}