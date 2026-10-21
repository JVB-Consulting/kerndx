// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Selector for the ApiSetting__mdt custom metadata type. Provides query methods
 * for retrieving API service configuration including credential relationship fields.
 *
 * @see SEL_Base
 * @see SEL_ApiSetting_TEST
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, October 2026
 */
public inherited sharing class SEL_ApiSetting extends SEL_Base
{
	/**
	 * @description Relationship path for ApiCredential__r.NamedCredential__c (namespace-safe).
	 */
	private static final String PATH_API_CREDENTIAL_NAMED_CREDENTIAL =
			ApiSetting__mdt.ApiCredential__c.getDescribe().getRelationshipName() + UTIL_String.DOT +
			UTIL_SObjectDescribe.getCachedFieldName(ApiCredential__mdt.NamedCredential__c);

	/**
	 * @description Relationship path for BypassFeatureFlag__r.DeveloperName (namespace-safe).
	 */
	private static final String PATH_BYPASS_FEATURE_FLAG_DEVELOPER_NAME =
			ApiSetting__mdt.BypassFeatureFlag__c.getDescribe().getRelationshipName() + '.DeveloperName';
	/**
	 * @description Relationship path for RequiredFeatureFlag__r.DeveloperName (namespace-safe).
	 */
	private static final String PATH_REQUIRED_FEATURE_FLAG_DEVELOPER_NAME =
			ApiSetting__mdt.RequiredFeatureFlag__c.getDescribe().getRelationshipName() + '.DeveloperName';

	/**
	 * @description Direction value indicating an inbound API setting.
	 */
	public static final String DIRECTION_INBOUND = 'Inbound';

	/**
	 * @description Direction value indicating an outbound API setting.
	 */
	public static final String DIRECTION_OUTBOUND = 'Outbound';

	/**
	 * @description The handler class name of every API setting, for the rest of the transaction, keyed by the class
	 * name in lower case and without the package namespace (see `buildServiceKey`). Read from the settings once, on the
	 * first call of `findClassNameByServiceName`; null until then.
	 */
	private static Map<String, String> classNamesByServiceKey;

	/**
	 * @description Constructs an ApiSetting selector.
	 */
	public SEL_ApiSetting()
	{
		super(ApiSetting__mdt.SObjectType);
	}

	/**
	 * @description Returns the core fields for ApiSetting__mdt queries.
	 *
	 * @return List of ApiSetting__mdt SObjectField tokens
	 */
	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>
		{
				ApiSetting__mdt.MasterLabel,
				ApiSetting__mdt.ApiCredential__c,
				ApiSetting__mdt.CircuitBreakerEnabled__c,
				ApiSetting__mdt.CircuitBreakerFailureThreshold__c,
				ApiSetting__mdt.CircuitBreakerSuccessThreshold__c,
				ApiSetting__mdt.CircuitBreakerTimeout__c,
				ApiSetting__mdt.ClassName__c,
				ApiSetting__mdt.DeveloperName,
				ApiSetting__mdt.Direction__c,
				ApiSetting__mdt.EndpointPath__c,
				ApiSetting__mdt.IdempotencyEnabled__c,
				ApiSetting__mdt.IsActive__c,
				ApiSetting__mdt.LogIssues__c,
				ApiSetting__mdt.MaxRetryCount__c,
				ApiSetting__mdt.MockingEnabled__c,
				ApiSetting__mdt.NamespacePrefix,
				ApiSetting__mdt.Priority__c,
				ApiSetting__mdt.RequiredFeatureFlag__c,
				ApiSetting__mdt.BypassFeatureFlag__c,
				ApiSetting__mdt.ResolveIssues__c,
				ApiSetting__mdt.RetryBackoffSeconds__c,
				ApiSetting__mdt.RetryIssues__c
		};
	}

	/**
	 * @description Returns the relationship field paths for ApiSetting__mdt queries.
	 * Includes the Named Credential reference from the ApiCredential__r parent relationship.
	 *
	 * @return List of relationship field path strings
	 */
	public override List<String> getFieldPaths()
	{
		return new List<String>
		{
				PATH_API_CREDENTIAL_NAMED_CREDENTIAL,
				PATH_BYPASS_FEATURE_FLAG_DEVELOPER_NAME,
				PATH_REQUIRED_FEATURE_FLAG_DEVELOPER_NAME
		};
	}

	/**
	 * @description Framework-internal CMDT selector — always runs in `AccessLevel.SYSTEM_MODE`
	 * regardless of the `UserModeQueries_Enabled` feature flag. Subscribers typically grant
	 * running users no CRUD on `kern__*__mdt` records by design, so USER_MODE reads would
	 * return empty and framework behaviour would silently break.
	 *
	 * @return `true` — this selector requires SYSTEM_MODE.
	 */
	public override Boolean systemModeRequired()
	{
		return true;
	}

	/**
	 * @description Finds an ApiSetting__mdt record by its class name.
	 *
	 * @param className The fully qualified Apex class name of the web service handler
	 *
	 * @return The matching record or null if not found
	 */
	public ApiSetting__mdt findByClassName(String className)
	{
		return (ApiSetting__mdt)findFirstByField(ApiSetting__mdt.ClassName__c, className);
	}

	/**
	 * @description Finds the handler class name of the API setting for a service name, as the setting writes it in
	 * `ClassName__c`. The service name of an API call or an API issue is the class name of its handler, so this is the
	 * class a masking target names in `CallerClass__c` to apply only to that handler's calls and issues.
	 *
	 * The names are compared without regard to letter case and without the package namespace, so `kern.API_Example`
	 * and `API_Example` name the same setting. All settings are read once per transaction, on the first call, and every
	 * later call answers from memory. A service with no setting, a setting with no class name, a blank service name, or
	 * settings that cannot be read all give the empty string, which means no caller.
	 *
	 * @param serviceName The service name of an API call or an API issue; may be blank
	 *
	 * @return The handler class name from the setting, or the empty string when there is none
	 *
	 * @example
	 * ```apex
	 * String callerClassName = SEL_ApiSetting.findClassNameByServiceName(apiCall.ServiceName__c);
	 * ```
	 */
	public static String findClassNameByServiceName(String serviceName)
	{
		if(String.isBlank(serviceName))
		{
			return UTIL_String.EMPTY;
		}
		if(classNamesByServiceKey == null)
		{
			classNamesByServiceKey = readClassNamesByServiceKey();
		}
		return classNamesByServiceKey.get(buildServiceKey(serviceName)) ?? UTIL_String.EMPTY;
	}

	/**
	 * @description Reads every API setting once and keys its class name by `buildServiceKey`. When the settings cannot
	 * be read, it writes a warning and gives an empty map, so every service resolves to no caller and only the masking
	 * targets for every caller apply.
	 *
	 * @return The class name of each setting that has one, keyed by its service key
	 */
	private static Map<String, String> readClassNamesByServiceKey()
	{
		Map<String, String> classNames = new Map<String, String>();
		try
		{
			for(SObject record : new SEL_ApiSetting().toList())
			{
				String className = ((ApiSetting__mdt)record).ClassName__c;
				if(String.isNotBlank(className))
				{
					classNames.put(buildServiceKey(className), className);
				}
			}
		}
		catch(Exception readFailure)
		{
			LOG_Builder.build()
					.warn('The API settings could not be read, so API calls and issues are masked for no caller: ' + readFailure.getMessage())
					.emitAt(SEL_ApiSetting.class.getName() + '.findClassNameByServiceName');
		}
		return classNames;
	}

	/**
	 * @description Builds the key a class name or a service name is looked up by: the name in lower case, with the
	 * package namespace and its dot removed from the start.
	 *
	 * @param name A class name or a service name, never blank
	 *
	 * @return The key
	 */
	private static String buildServiceKey(String name)
	{
		return name.trim().toLowerCase().removeStart(UTIL_System.getManagedPackageNamespacePrefix(UTIL_String.DOT).toLowerCase());
	}

	/**
	 * @description Finds all active inbound routes for dynamic routing.
	 *
	 * @return List of active inbound settings ordered by priority
	 */
	public List<ApiSetting__mdt> findActiveInboundRoutes()
	{
		return query
				.condition(ApiSetting__mdt.Direction__c).equals(DIRECTION_INBOUND)
				.andCondition(ApiSetting__mdt.IsActive__c).equals(true)
				.andCondition(ApiSetting__mdt.EndpointPath__c).isNotNull()
				.orderBy(ApiSetting__mdt.Priority__c).ascending()
				.toList();
	}

	/**
	 * @description Finds all active API settings filtered by direction.
	 *
	 * @param direction The direction to filter by (Inbound or Outbound)
	 *
	 * @return List of active settings for the specified direction
	 */
	public List<ApiSetting__mdt> findActiveByDirection(String direction)
	{
		return query
				.condition(ApiSetting__mdt.Direction__c).equals(direction)
				.andCondition(ApiSetting__mdt.IsActive__c).equals(true)
				.orderBy(ApiSetting__mdt.MasterLabel).ascending()
				.toList();
	}
}