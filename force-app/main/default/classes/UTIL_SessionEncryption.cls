// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Utility class providing bi-directional encryption and decryption capabilities with automatic key management and expiry.
 * This class uses AES256 encryption combined with HMAC-SHA256 (Encrypt-then-MAC) to ensure both
 * confidentiality and integrity.
 *
 * ## CRITICAL ARCHITECTURAL WARNING
 * This utility uses EPHEMERAL STORAGE (Platform Cache) for encryption keys.
 * Keys are NOT persisted to the database. If the cache expires, is flushed, or the session ends,
 * the key is LOST FOREVER and any data encrypted with it becomes permanently unrecoverable.
 *
 * #### DO NOT USE THIS CLASS FOR:
 * - Persisting encrypted data to SObjects or Settings.
 * - Long-term data storage.
 *
 * #### USE THIS CLASS ONLY FOR:
 * - Short-lived data passing (e.g., ViewState, temporary token exchange).
 * - Session-scoped data where data loss is acceptable upon session expiry.
 *
 * @see UTIL_SessionEncryption_TEST
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date January 2025, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * String encrypted = UTIL_SessionEncryption.encrypt('Sensitive Data');
 * String decrypted = UTIL_SessionEncryption.decrypt(encrypted);
 * Boolean available = UTIL_SessionEncryption.isAvailable();
 * ```
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.AvoidGlobalModifier')
global inherited sharing class UTIL_SessionEncryption
{
	/**
	 * @description The expiry time for cached encryption keys in seconds.
	 * Set to 8 hours (28800s) to match the maximum Salesforce Session Cache TTL.
	 */
	private static final Integer KEY_EXPIRY_SECONDS = 28800;

	/**
	 * @description The cache key name.
	 */
	@TestVisible
	private static final String CACHE_KEY_NAME = 'EncryptionKey';

	/**
	 * @description Error message when no encryption key is found in the cache.
	 */
	@TestVisible
	@SuppressWarnings('PMD.AvoidHardcodedCredentialsInFieldDecls')
	private static final String ERROR_NO_ENCRYPTION_KEY = 'No encryption key found';

	/**
	 * @description Error message when cache is unavailable.
	 */
	@TestVisible
	private static final String ERROR_CACHE_UNAVAILABLE = 'Platform Cache is unavailable or misconfigured. Cannot perform encryption operations.';

	/**
	 * @description The platform cache instance used for storing encryption keys.
	 * Configured with .withUserScope(true) to ensure keys are unique per user.
	 */
	private static final UTIL_Cache.Store cache
	{
		get
		{
			if(cache == null)
			{
				cache = UTIL_Cache.auto()
						.withScope(UTIL_Cache.Scope.AUTO)
						.withUserScope(true);
			}
			return cache;
		}
		set;
	}

	/**
	 * @description Safely checks if the Crypto utility is available for use (Cache is online).
	 * Useful for UI controllers to check availability without needing try/catch blocks.
	 *
	 * @return Boolean True if cache is available, False otherwise.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Boolean result = UTIL_SessionEncryption.isAvailable();
	 * ```
	 */
	global static Boolean isAvailable()
	{
		try
		{
			checkCacheAvailability();
			return true;
		}
		catch(Exception error)
		{
			return false;
		}
	}

	/**
	 * @description Encrypts a string using the current user's encryption key and appends an HMAC.
	 * The method generates a new key if none exists in the cache and stores it with an expiry.
	 *
	 * Format: Base64(IV) : Base64(Cipher) : Base64(HMAC)
	 *
	 * @param plainTextValue The string to encrypt.
	 *
	 * @return String The encrypted string in Base64 format with HMAC, or the input if it is blank.
	 *
	 * @throws Exception If encryption fails due to invalid key, algorithm issues, or cache write failures.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String plainTextValue = 'Sensitive Data';
	 * String encrypted = UTIL_SessionEncryption.encrypt(plainTextValue);
	 * System.debug(encrypted); // Outputs: Base64-encoded encrypted string
	 * String blankInput = '';
	 * encrypted = UTIL_SessionEncryption.encrypt(blankInput);
	 * System.debug(encrypted); // Outputs: ''
	 * ```
	 */
	global static String encrypt(String plainTextValue)
	{
		if(String.isBlank(plainTextValue))
		{
			return plainTextValue;
		}

		try
		{
			checkCacheAvailability();

			Blob encryptionKey = getEncryptionKey();

			if(encryptionKey == null)
			{
				encryptionKey = UTIL_Crypto.generateEncryptionKey();
				String encodedKey = EncodingUtil.base64Encode(encryptionKey);

				// Attempt to store the new key
				cache.put(CACHE_KEY_NAME, encodedKey, KEY_EXPIRY_SECONDS);
				UTIL_Cache.OperationResult operationResult = cache.getLastOperationResult();

				// CRITICAL: Verify the key was actually stored.
				if(!operationResult.success)
				{
					throw new Cache.CacheException('Critical Security Failure: Unable to persist encryption key to cache. ' + operationResult.errorMessage);
				}
			}

			return UTIL_Crypto.encryptWithIntegrity(encryptionKey, plainTextValue);
		}
		catch(Exception error)
		{
			LOG_Builder.build().error(error).at(UTIL_SessionEncryption.class.getName() + '/encrypt').emit();
			throw error;
		}
	}

	/**
	 * @description Decrypts a Base64-encoded string using the cached encryption key.
	 * Verifies the HMAC before attempting decryption to ensure integrity.
	 *
	 * @param encryptedTextValue The Base64-encoded encrypted string (IV:Cipher:HMAC).
	 *
	 * @return String The decrypted string, or the input if it is blank.
	 *
	 * @throws Exception If decryption fails due to invalid key or algorithm issues.
	 * @throws IllegalArgumentException If the encrypted text is invalid or no encryption key is found.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String plainTextValue = 'Sensitive Data';
	 * String encrypted = UTIL_SessionEncryption.encrypt(plainTextValue);
	 * String decrypted = UTIL_SessionEncryption.decrypt(encrypted);
	 * System.debug(decrypted); // Outputs: Sensitive Data
	 * try
	 * {
	 * decrypted = UTIL_SessionEncryption.decrypt('InvalidBase64');
	 * }
	 * catch(IllegalArgumentException e)
	 * {
	 * System.debug('Invalid input: ' + e.getMessage());
	 * }
	 * ```
	 */
	global static String decrypt(String encryptedTextValue)
	{
		if(String.isBlank(encryptedTextValue))
		{
			return encryptedTextValue;
		}

		try
		{
			checkCacheAvailability();

			Blob encryptionKey = getEncryptionKey();

			if(encryptionKey == null)
			{
				throw new IllegalArgumentException(ERROR_NO_ENCRYPTION_KEY);
			}

			return UTIL_Crypto.decryptWithIntegrity(encryptionKey, encryptedTextValue);
		}
		catch(Exception error)
		{
			LOG_Builder.build().error(error).at(UTIL_SessionEncryption.class.getName() + '/decrypt').emit();
			throw error;
		}
	}

	/**
	 * @description Checks if the Platform Cache is available for use.
	 * Throws an exception if the cache is unavailable or simulated to be unavailable.
	 */
	private static void checkCacheAvailability()
	{
		if(!(cache?.isCacheAvailable() == true))
		{
			throw new Cache.CacheException(ERROR_CACHE_UNAVAILABLE);
		}
	}

	/**
	 * @description Retrieves or generates a unique encryption key for the current user and session.
	 * The key is stored in the cache and retrieved as a Base64-encoded Blob.
	 * Checks specifically for read failures vs cache misses.
	 *
	 * @return Blob The encryption key, or null if not found in the cache (Cache Miss).
	 *
	 * @throws Cache.CacheException If the cache read operation fails (not just a miss).
	 *
	 * @example
	 * ```apex
	 * Blob encryptionKey = UTIL_SessionEncryption.getEncryptionKey();
	 * System.debug(encryptionKey != null); // Outputs: true (if key exists in cache)
	 * ```
	 */
	@TestVisible
	private static Blob getEncryptionKey()
	{
		String cachedKeyString = (String)cache.get(CACHE_KEY_NAME);
		UTIL_Cache.OperationResult operationResult = cache.getLastOperationResult();

		if(!operationResult.success)
		{
			throw new Cache.CacheException('Failed to retrieve encryption key from cache. Status: ' + operationResult.status + ', Error: ' + operationResult.errorMessage);
		}

		Blob encryptionKey;

		if(String.isNotBlank(cachedKeyString))
		{
			encryptionKey = EncodingUtil.base64Decode(cachedKeyString);
		}

		return encryptionKey;
	}
}