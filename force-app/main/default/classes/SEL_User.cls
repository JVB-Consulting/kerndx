// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Selector for the User SObject. Provides default field configuration
 * and query methods for User records, including retrieval by ID, role, profile, or other fields,
 * as well as generating aliases and community nicknames.
 *
 * @see SEL_Base
 * @see SEL_User_TEST
 * @see User
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
 * User currentUser = new SEL_User().getCurrentUser();
 * User foundUser = new SEL_User().findByUsername('admin@example.com');
 * List<User> admins = new SEL_User().findActiveByProfileName('System Administrator');
 * List<User> roleUsers = new SEL_User().findByRoleId(roleIds);
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier,PMD.CognitiveComplexity,PMD.ExcessivePublicCount')
global virtual inherited sharing class SEL_User extends SEL_Base
{
	/**
	 * @description Cached current user record.
	 */
	private static User currentUser;

	/**
	 * @description API name for the ProfileId field.
	 */
	private static final String FIELD_PROFILE_ID = User.ProfileId.getDescribe().name;

	/**
	 * @description API name for the IsActive field.
	 */
	public static final String FIELD_IS_ACTIVE = User.IsActive.getDescribe().name;

	/**
	 * @description API name for the LastLoginDate field.
	 */
	public static final String FIELD_LAST_LOGIN_DATE = User.LastLoginDate.getDescribe().name;

	/**
	 * @description Reference to the Profile.Name field for SOQL queries.
	 */
	public static final String FIELD_PROFILE_NAME = 'Profile.Name';

	/**
	 * @description Suffix used for composing example email addresses.
	 */
	public static final String INVALID_EMAIL_SUFFIX = '.invalid';

	/**
	 * @description API name of the User object.
	 */
	public static final String OBJECT_NAME = UTIL_SObjectDescribe.getObjectNameFromType(User.SObjectType);

	/**
	 * @description Constructs a User selector with the User SObjectType.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * SEL_User instance = new SEL_User();
	 * ```
	 */
	global SEL_User()
	{
		super(User.SObjectType);
	}

	/**
	 * @description Returns the core SObjectField tokens for User queries.
	 *
	 * @return List of User SObjectField tokens
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * SEL_User selector = new SEL_User();
	 * List<SObjectField> userFields = selector.getFields();
	 * System.debug('User selector has ' + userFields.size() + ' core fields');
	 * ```
	 */
	global virtual override List<SObjectField> getFields()
	{
		return new List<SObjectField>
		{
				User.AccountId,
				User.Address,
				User.Alias,
				User.CompanyName,
				User.ContactId,
				User.Email,
				User.EmailEncodingKey,
				User.FederationIdentifier,
				User.FirstName,
				User.IsActive,
				User.CommunityNickname,
				User.LanguageLocaleKey,
				User.LastName,
				User.LocaleSidKey,
				User.ManagerId,
				User.MobilePhone,
				User.Name,
				User.Phone,
				User.ProfileId,
				User.TimeZoneSidKey,
				User.Title,
				User.Username,
				User.UserRoleId,
				User.UserType
		};
	}

	/**
	 * @description Returns relationship field paths for User queries.
	 *
	 * @return List of relationship field path strings
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * SEL_User selector = new SEL_User();
	 * List<String> paths = selector.getFieldPaths();
	 * System.debug('Relationship paths: ' + paths); // ['Profile.Name']
	 * ```
	 */
	global virtual override List<String> getFieldPaths()
	{
		return new List<String> {FIELD_PROFILE_NAME};
	}

	/**
	 * @description Framework-internal schema selector — always runs in `AccessLevel.SYSTEM_MODE`
	 * regardless of the `UserModeQueries_Enabled` feature flag. Running users typically lack the
	 * View All Users permission needed to look up arbitrary users (context-user lookups, batch
	 * processing, log correlation), so USER_MODE reads would return scoped-out results and the
	 * framework's identity resolution machinery would silently break.
	 *
	 * @return `true` — this selector requires SYSTEM_MODE.
	 */
	public override Boolean systemModeRequired()
	{
		return true;
	}

	/**
	 * @description Retrieves a list of users based on a set of role IDs, using default User fields.
	 *
	 * @param roleIds The set of role IDs to query.
	 *
	 * @return A list of User records assigned to the specified roles, or an empty list if none found.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Set<Id> roleIds = new Set<Id>{'00E3X00000R1AbC'};
	 * List<User> users = new SEL_User().findByRoleId(roleIds);
	 * ```
	 */
	global List<User> findByRoleId(Set<Id> roleIds)
	{
		return findByField(User.UserRoleId, new List<Id>(roleIds));
	}

	/**
	 * @description Retrieves the current user's details using default fields.
	 * Caches the result so subsequent calls within the same transaction do not re-query.
	 *
	 * @return The User record for the current user, or null if not found.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * User currentUser = new SEL_User().getCurrentUser();
	 * ```
	 */
	global User getCurrentUser()
	{
		if(mustRefreshUser())
		{
			currentUser = (User)findById(UserInfo.getUserId());
		}
		return currentUser;
	}

	/**
	 * @description Checks if the current user's details need to be refreshed based on the UserInfo ID.
	 *
	 * @return True if the current user details must be retrieved, false otherwise.
	 */
	private static Boolean mustRefreshUser()
	{
		return currentUser?.Id != UserInfo.getUserId();
	}

	/**
	 * @description Retrieves active users with the specified profile name, using default fields.
	 *
	 * @param profileName The name of the profile to filter by.
	 *
	 * @return A list of active User records matching the profile, or an empty list if none found.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<User> admins = new SEL_User().findActiveByProfileName('System Administrator');
	 * ```
	 */
	global List<User> findActiveByProfileName(String profileName)
	{
		return buildActiveByProfileQuery(profileName).toList();
	}

	/**
	 * @description Retrieves a random active user with the specified profile name, using default fields.
	 *
	 * @param profileName The name of the profile to filter by.
	 *
	 * @return A random active User record matching the profile, or null if none found.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * User randomAdmin = new SEL_User().findRandomActiveByProfileName('System Administrator');
	 * ```
	 */
	global User findRandomActiveByProfileName(String profileName)
	{
		return (User)buildActiveByProfileQuery(profileName).getRandomItem();
	}

	/**
	 * @description Builds a query for active users with the specified profile name.
	 *
	 * @param profileName The name of the profile to filter by.
	 *
	 * @return A configured QRY_Builder.Builder ready for execution.
	 */
	private QRY_Builder.Builder buildActiveByProfileQuery(String profileName)
	{
		QRY_Builder.Builder profileSubquery = QRY_Builder.selectFrom(Profile.SObjectType)
				.withSystemMode()
				.fields(new List<String> {'Id'})
				.condition(Profile.Name).equals(profileName);

		return query
				.condition(FIELD_IS_ACTIVE).equals(true)
				.andCondition(FIELD_PROFILE_ID).isIn(profileSubquery);
	}

	/**
	 * @description Retrieves active users with the specified profile and permission set or group, using default fields.
	 *
	 * @param profileName The name of the profile to filter by.
	 * @param permissionSetOrGroupName The name of the permission set or group to filter by.
	 *
	 * @return A list of active User records matching both criteria, or an empty list if none found.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<User> hrAdmins = new SEL_User().findActiveByProfileAndPermissionSetName('HR Admin', 'HR_Permissions');
	 * ```
	 */
	global List<User> findActiveByProfileAndPermissionSetName(String profileName, String permissionSetOrGroupName)
	{
		return buildActiveByProfileAndPermissionSetQuery(profileName, permissionSetOrGroupName).toList();
	}

	/**
	 * @description Retrieves a random active user with the specified profile and permission set or group, using default fields.
	 *
	 * @param profileName The name of the profile to filter by.
	 * @param permissionSetOrGroupName The name of the permission set or group to filter by.
	 *
	 * @return A random active User record matching both criteria, or null if none found.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * User randomHrAdmin = new SEL_User().findRandomActiveByProfileAndPermissionSetName('HR Admin', 'HR_Permissions');
	 * ```
	 */
	global User findRandomActiveByProfileAndPermissionSetName(String profileName, String permissionSetOrGroupName)
	{
		return (User)buildActiveByProfileAndPermissionSetQuery(profileName, permissionSetOrGroupName).getRandomItem();
	}

	/**
	 * @description Builds a query for active users with a specific profile and permission set or group.
	 *
	 * @param profileName The name of the profile to filter by.
	 * @param permissionSetOrGroupName The name of the permission set or group to filter by.
	 *
	 * @return A configured QRY_Builder.Builder ready for execution.
	 */
	private QRY_Builder.Builder buildActiveByProfileAndPermissionSetQuery(String profileName, String permissionSetOrGroupName)
	{
		QRY_Builder.Builder permissionSetSubquery = QRY_Builder.selectFrom(PermissionSetAssignment.SObjectType)
				.withSystemMode()
				.fields(new List<String> {SEL_PermissionSetAssignment.FIELD_ASSIGNEE_ID})
				.condition(SEL_PermissionSetAssignment.FIELD_PERMISSION_SET_NAME).equals(permissionSetOrGroupName);

		return buildActiveByProfileQuery(profileName)
				.andCondition('Id').isIn(permissionSetSubquery);
	}

	/**
	 * @description Retrieves a list of users by their usernames, using default User fields.
	 *
	 * @param userNames The set of usernames to query.
	 *
	 * @return A list of User records matching the usernames, or an empty list if none found.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Set<String> userNames = new Set<String>{'test.user@example.com'};
	 * List<User> users = new SEL_User().findByUsername(userNames);
	 * ```
	 */
	global List<User> findByUsername(Set<String> userNames)
	{
		return query.condition(User.Username).isIn(new List<String>(userNames)).toList();
	}

	/**
	 * @description Finds a user record by username.
	 *
	 * @param username The username (email format) to search for
	 *
	 * @return The User record with default fields, or null if not found
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * User foundUser = new SEL_User().findByUsername('test.user@example.com');
	 * ```
	 */
	global User findByUsername(String username)
	{
		return String.isBlank(username) ? null : (User)findFirstByField(User.Username, username);
	}

	/**
	 * @description Retrieves the Profile ID for a specific user.
	 *
	 * @param userId The user ID to look up
	 *
	 * @return The user's Profile ID, or null if user not found
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Id profileId = new SEL_User().findProfileIdByUserId(someUserId);
	 * ```
	 */
	global Id findProfileIdByUserId(Id userId)
	{
		if(String.isBlank(userId))
		{
			return null;
		}

		User foundUser = (User)findById(userId);
		return foundUser?.ProfileId;
	}

	/**
	 * @description Retrieves a list of users by their profile names, using default User fields.
	 *
	 * @param profileNames The set of profile names to query.
	 *
	 * @return A list of User records matching the profile names, or an empty list if none found.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Set<String> profileNames = new Set<String>{'System Administrator', 'Standard User'};
	 * List<User> users = new SEL_User().findByProfileName(profileNames);
	 * ```
	 */
	global List<User> findByProfileName(Set<String> profileNames)
	{
		return query
				.condition(FIELD_PROFILE_NAME).isIn(new List<String>(profileNames))
				.toList();
	}

	/**
	 * @description Retrieves a list of users by their profile and company name, using default User fields.
	 *
	 * @param profileName The profile which to find records
	 * @param companyName The company which to find records
	 *
	 * @return A list of User records matching the criteria, or an empty list if none found.
	 */
	@TestVisible
	private List<User> findByProfileAndCompany(String profileName, String companyName)
	{
		return query
				.andCondition(FIELD_PROFILE_NAME).equals(profileName)
				.andCondition(User.CompanyName).equals(companyName)
				.toList();
	}

	/**
	 * @description Checks if the current user has the System Administrator profile.
	 *
	 * @return True if the current user is a System Administrator, false otherwise.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * if(new SEL_User().isCurrentUserSystemAdmin())
	 * {
	 *     // Current user is a System Administrator
	 * }
	 * ```
	 */
	global Boolean isCurrentUserSystemAdmin()
	{
		getCurrentUser();
		return SEL_Profile.PROFILE_SYSTEM_ADMIN.equalsIgnoreCase(currentUser.Profile.Name);
	}

	/**
	 * @description Retrieves a user by their federation ID, using default User fields.
	 *
	 * @param federationId The federation ID to query.
	 *
	 * @return A User record matching the federation ID, or null if not found.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * User user = new SEL_User().findByFederationId('fed123456');
	 * ```
	 */
	global User findByFederationId(String federationId)
	{
		return (User)findFirstByField(User.FederationIdentifier, federationId);
	}

	/**
	 * @description Retrieves a user by their company name, using default User fields.
	 *
	 * @param companyName The company name to query.
	 *
	 * @return A User record matching the company name, or null if not found.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * User testUser = new SEL_User().findByCompanyName('my-test-user-identifier');
	 * ```
	 */
	global User findByCompanyName(String companyName)
	{
		return (User)findFirstByField(User.CompanyName, companyName);
	}

	/**
	 * @description Retrieves a specified number of active users, using default User fields.
	 *
	 * @param numberOfUsers The maximum number of users to return.
	 *
	 * @return A list of active User records, up to the specified number, or an empty list if none found.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<User> activeUsers = new SEL_User().findActiveUsers(5);
	 * ```
	 */
	global List<User> findActiveUsers(Integer numberOfUsers)
	{
		return query
				.condition(FIELD_IS_ACTIVE).equals(true)
				.withLimit(numberOfUsers)
				.toList();
	}

	/**
	 * @description Generates an alias from a user's full name, adhering to the User.Alias field length.
	 *
	 * @param fullName The user's full name (including first, middle, last names, prefixes, or suffixes).
	 *
	 * @return A generated alias string, or an empty string if the input is blank.
	 *
	 * @see User.Alias
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String alias = SEL_User.generateAlias('Jason van Thor Bob');
	 * ```
	 */
	global String generateAlias(String fullName)
	{
		String alias = UTIL_String.EMPTY;
		List<String> nameParts = new List<String>();
		for(String namePart : UTIL_String.split(fullName))
		{
			if(String.isNotBlank(namePart))
			{
				nameParts.add(namePart.trim().toLowerCase().capitalize());
			}
		}
		final Integer firstNameCharacters = 1;
		alias += nameParts.size() == 1 ? nameParts.iterator().next() : UTIL_String.substring(nameParts.iterator().next(), 0, firstNameCharacters);
		final Integer otherNamesCharacters = 3;
		for(Integer i = 1; i < nameParts.size(); i++)
		{
			alias += UTIL_String.substring(nameParts[i], 0, otherNamesCharacters);
		}
		return UTIL_String.substring(alias, 0, User.Alias.getDescribe().length);
	}

	/**
	 * @description Generates a unique community nickname from a user's full name, checking for existing nicknames.
	 *
	 * @param fullName The user's full name.
	 *
	 * @return A unique community nickname string, or a random name if the input is blank.
	 *
	 * @see User.CommunityNickname
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String nickname = new SEL_User().generateUniqueCommunityNickname('Billy Bob Thornton');
	 * ```
	 */
	global String generateUniqueCommunityNickname(String fullName)
	{
		return generateUniqueCommunityNickname
				(
						fullName,
						getSimilarNicknames(generateUniqueCommunityNickname(fullName, null))
				);
	}

	/**
	 * @description Queries existing community nicknames similar to the provided nickname.
	 *
	 * @param communityNickname The nickname to check for similarity.
	 *
	 * @return A set of similar community nicknames, or an empty set if none found.
	 */
	private static Set<String> getSimilarNicknames(String communityNickname)
	{
		return QRY_Builder.selectFrom(User.SObjectType)
				.withSystemMode()
				.addField(User.CommunityNickname)
				.condition(User.CommunityNickname).startsWith(communityNickname)
				.bypassSharing()
				.asStringSet(User.CommunityNickname);
	}

	/**
	 * @description Generates a unique community nickname from a user's full name, ensuring uniqueness against existing nicknames.
	 *
	 * @param fullName The user's full name.
	 * @param existingNicknames A set of existing nicknames to check against, or null to ignore.
	 *
	 * @return A unique community nickname string, or a random name if the input is blank.
	 *
	 * @see User.CommunityNickname
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Set<String> existing = new Set<String>{'BillyBobThornton'};
	 * String nickname = SEL_User.generateUniqueCommunityNickname('Billy Bob Thornton', existing);
	 * ```
	 */
	global String generateUniqueCommunityNickname(String fullName, Set<String> existingNicknames)
	{
		String nickName = String.isNotBlank(fullName) ? UTIL_String.EMPTY : UTIL_Random.randomName();
		if(String.isBlank(nickName))
		{
			for(String namePart : UTIL_String.split(fullName))
			{
				if(String.isNotBlank(namePart))
				{
					nickName += namePart.trim().toLowerCase().capitalize();
				}
			}
			final Integer maximumLength = User.CommunityNickname.getDescribe().length;
			nickName = UTIL_String.substring(nickName, 0, maximumLength);
			Set<String> existingNicknamesInLowerCase = UTIL_Set.lowerCase(existingNicknames);
			if(existingNicknamesInLowerCase?.contains(nickName.toLowerCase()) == true)
			{
				nickName = UTIL_String.substring(nickName, 0, maximumLength - 3);
				Integer iNickNameSuffix = 1;
				while(existingNicknamesInLowerCase.contains(nickName.toLowerCase() + iNickNameSuffix) && iNickNameSuffix <= 999)
				{
					iNickNameSuffix++;
				}
				nickName += iNickNameSuffix;
			}
		}
		return nickName;
	}
}