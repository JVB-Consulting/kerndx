// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Test class for UTIL_SessionEncryption
 * Tests encryption/decryption flows, HMAC integrity validation, and critical error handling.
 *
 * @see UTIL_Cache
 * @see UTIL_SessionEncryption
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date January 2025, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class UTIL_SessionEncryption_TEST
{
	private static final String INVALID_ENCRYPTED_TEXT = 'InvalidBase64NoSeparator';
	private static final String MSG_EXCEPTION_EXPECTED = 'Expected an exception to be thrown';
	private static final String MSG_NULL = 'Result should be null';
	private static final String MSG_VALUE_EQUALITY = 'Value should match expected';
	private static final String MSG_WRONG_VALUE = 'Value should not match expected';
	private static final String SAMPLE_TEXT = 'Test sensitive data 123!@#';

	/**
	 * @description Tests basic encryption and decryption functionality (Happy Path)
	 */
	@IsTest
	private static void shouldEncryptAndDecryptSuccessfully()
	{
		Test.startTest();

		String encryptedText = UTIL_SessionEncryption.encrypt(SAMPLE_TEXT);
		String decryptedText = UTIL_SessionEncryption.decrypt(encryptedText);

		// Verify structure contains 3 parts (IV:Cipher:HMAC)
		List<String> parts = encryptedText.split(UTIL_String.COLON);
		Assert.areEqual(3, parts.size(), 'Encrypted text should contain IV, Cipher, and HMAC');

		Assert.areNotEqual(SAMPLE_TEXT, encryptedText, MSG_WRONG_VALUE);
		Assert.areEqual(SAMPLE_TEXT, decryptedText, MSG_VALUE_EQUALITY);

		Test.stopTest();
	}

	/**
	 * @description Tests the availability check helper.
	 */
	@IsTest
	private static void shouldReportAvailability()
	{
		Test.startTest();

		// Should be true in normal test context
		Assert.isTrue(UTIL_SessionEncryption.isAvailable(), 'Should be available by default');

		// Simulate partition being unavailable
		UTIL_Cache.simulateNullPartition = true;
		Assert.isFalse(UTIL_SessionEncryption.isAvailable(), 'Should report unavailable when cache fails');

		Test.stopTest();
	}

	/**
	 * @description Tests that encryption fails fast when Platform Cache is completely unavailable.
	 */
	@IsTest
	private static void shouldThrowExceptionWhenCacheUnavailable()
	{
		// Simulate partition being unavailable (returns null partition instance)
		UTIL_Cache.simulateNullPartition = true;

		Test.startTest();

		try
		{
			UTIL_SessionEncryption.encrypt(SAMPLE_TEXT);
			Assert.fail(MSG_EXCEPTION_EXPECTED);
		}
		catch(Exception caughtException)
		{
			Assert.isInstanceOfType(caughtException, Cache.CacheException.class, 'Should throw CacheException');
			Assert.areEqual(UTIL_SessionEncryption.ERROR_CACHE_UNAVAILABLE, caughtException.getMessage(), MSG_VALUE_EQUALITY);
		}

		Test.stopTest();
	}

	/**
	 * @description Tests "Write Failure" scenario.
	 */
	@IsTest
	private static void shouldThrowExceptionOnCacheWriteFailure()
	{
		UTIL_Cache.simulatePutException = true;

		Test.startTest();

		try
		{
			UTIL_SessionEncryption.encrypt(SAMPLE_TEXT);
			Assert.fail(MSG_EXCEPTION_EXPECTED);
		}
		catch(Exception caughtException)
		{
			Assert.isInstanceOfType(caughtException, Cache.CacheException.class, 'Should throw CacheException');
			Assert.isTrue(caughtException.getMessage().contains('Critical Security Failure'), 'Exception should indicate security failure due to persistence issue');
		}

		Test.stopTest();
	}

	/**
	 * @description Tests "Read Failure" scenario.
	 */
	@IsTest
	private static void shouldThrowExceptionOnCacheReadFailure()
	{
		UTIL_SessionEncryption.encrypt(SAMPLE_TEXT);

		UTIL_Cache.simulateGetException = true;

		Test.startTest();

		try
		{
			UTIL_SessionEncryption.encrypt(SAMPLE_TEXT);
			Assert.fail(MSG_EXCEPTION_EXPECTED);
		}
		catch(Exception caughtException)
		{
			Assert.isInstanceOfType(caughtException, Cache.CacheException.class, 'Should throw CacheException');
			Assert.isTrue(caughtException.getMessage().contains('Failed to retrieve encryption key'), 'Exception should indicate read failure');
		}

		Test.stopTest();
	}

	/**
	 * @description Tests that a new random key is generated if the cache is cleared.
	 */
	@IsTest
	private static void shouldGenerateRandomKeys()
	{
		Test.startTest();

		UTIL_SessionEncryption.encrypt(SAMPLE_TEXT);
		Blob keyA = UTIL_SessionEncryption.getEncryptionKey();

		UTIL_Cache.auto()
				.withScope(UTIL_Cache.Scope.AUTO)
				.withUserScope(true)
				.remove(UTIL_SessionEncryption.CACHE_KEY_NAME);

		UTIL_SessionEncryption.encrypt(SAMPLE_TEXT);
		Blob keyB = UTIL_SessionEncryption.getEncryptionKey();

		Test.stopTest();

		Assert.areNotEqual(keyA, keyB, 'New random key should be different from previous key');
	}

	/**
	 * @description Tests detection of tampered data.
	 * If the Ciphertext is modified, the HMAC check should fail before decryption is attempted.
	 */
	@IsTest
	private static void shouldDetectTamperedCiphertext()
	{
		Test.startTest();

		String encryptedText = UTIL_SessionEncryption.encrypt(SAMPLE_TEXT);
		List<String> parts = encryptedText.split(UTIL_String.COLON);

		// Tamper with the middle part (Ciphertext) — ensure replacement differs from original
		String lastChar = parts[1].substring(parts[1].length() - 1);
		String replacement = lastChar == 'A' ? 'B' : 'A';
		String tamperedCipher = parts[1].substring(0, parts[1].length() - 1) + replacement;
		String tamperedPayload = parts[0] + UTIL_String.COLON + tamperedCipher + UTIL_String.COLON + parts[2];

		try
		{
			UTIL_SessionEncryption.decrypt(tamperedPayload);
			Assert.fail(MSG_EXCEPTION_EXPECTED);
		}
		catch(Exception caughtException)
		{
			Assert.isInstanceOfType(caughtException, SecurityException.class, 'Should throw SecurityException');
			Assert.areEqual(UTIL_Crypto.ERROR_HMAC_VALIDATION_FAILED, caughtException.getMessage(), 'Should detect tampering');
		}

		Test.stopTest();
	}

	/**
	 * @description Tests detection of tampered IV.
	 * If the IV is modified, the HMAC check should fail.
	 */
	@IsTest
	private static void shouldDetectTamperedIV()
	{
		Test.startTest();

		String encryptedText = UTIL_SessionEncryption.encrypt(SAMPLE_TEXT);
		List<String> parts = encryptedText.split(UTIL_String.COLON);

		// Tamper with the first part (IV) — ensure replacement differs from original
		String firstChar = parts[0].substring(0, 1);
		String ivReplacement = firstChar == 'A' ? 'B' : 'A';
		String tamperedIV = ivReplacement + parts[0].substring(1);
		String tamperedPayload = tamperedIV + UTIL_String.COLON + parts[1] + UTIL_String.COLON + parts[2];

		try
		{
			UTIL_SessionEncryption.decrypt(tamperedPayload);
			Assert.fail(MSG_EXCEPTION_EXPECTED);
		}
		catch(Exception caughtException)
		{
			Assert.areEqual(UTIL_Crypto.ERROR_HMAC_VALIDATION_FAILED, caughtException.getMessage(), 'Should detect tampering');
		}

		Test.stopTest();
	}

	/**
	 * @description Tests decryption with invalid encrypted text (bad structure).
	 */
	@IsTest
	private static void shouldHandleInvalidEncryptedText()
	{
		// First encrypt something to ensure a key exists in cache
		UTIL_SessionEncryption.encrypt(SAMPLE_TEXT);

		Test.startTest();

		try
		{
			UTIL_SessionEncryption.decrypt(INVALID_ENCRYPTED_TEXT);
			Assert.fail(MSG_EXCEPTION_EXPECTED);
		}
		catch(Exception caughtException)
		{
			Assert.areEqual(UTIL_Crypto.ERROR_INVALID_PAYLOAD, caughtException.getMessage(), MSG_VALUE_EQUALITY);
		}

		Test.stopTest();
	}

	/**
	 * @description Tests decryption when no key exists in the cache.
	 */
	@IsTest
	private static void shouldHandleMissingKey()
	{
		Test.startTest();

		// Generate a payload that looks valid structurally (3 parts) but key is missing
		final String fakePayload = 'IV:Cipher:HMAC';

		try
		{
			UTIL_SessionEncryption.decrypt(fakePayload);
			Assert.fail(MSG_EXCEPTION_EXPECTED);
		}
		catch(Exception caughtException)
		{
			Assert.areEqual(UTIL_SessionEncryption.ERROR_NO_ENCRYPTION_KEY, caughtException.getMessage(), MSG_VALUE_EQUALITY);
		}

		Test.stopTest();
	}

	/**
	 * @description Tests decryption with a valid encrypted value but a different key in cache.
	 * This simulates a key rotation or expiration event. The HMAC check will fail first.
	 */
	@IsTest
	private static void shouldHandleWrongKey()
	{
		Test.startTest();

		// Encrypt with Key A
		String encryptedText = UTIL_SessionEncryption.encrypt(SAMPLE_TEXT);

		// 2. Clear cache and generate Key B
		UTIL_Cache.auto()
				.withScope(UTIL_Cache.Scope.AUTO)
				.withUserScope(true)
				.remove(UTIL_SessionEncryption.CACHE_KEY_NAME);

		// Initialize new key
		UTIL_SessionEncryption.encrypt('New Init');

		try
		{
			// Try decrypting text (encrypted with Key A) using Key B
			UTIL_SessionEncryption.decrypt(encryptedText);
			Assert.fail(MSG_EXCEPTION_EXPECTED);
		}
		catch(Exception caughtException)
		{
			// This should now fail at HMAC stage because the keys used to derive HMAC key are different
			Assert.areEqual(UTIL_Crypto.ERROR_HMAC_VALIDATION_FAILED, caughtException.getMessage(), MSG_VALUE_EQUALITY);
		}

		Test.stopTest();
	}

	/**
	 * @description Tests handling of null and empty input values (should pass through).
	 */
	@IsTest
	private static void shouldHandleNullAndEmptyValues()
	{
		Test.startTest();

		String decryptedEmptyString = UTIL_SessionEncryption.decrypt(UTIL_String.EMPTY);
		String encryptedEmptyString = UTIL_SessionEncryption.encrypt(UTIL_String.EMPTY);
		String decryptedNullInput = UTIL_SessionEncryption.decrypt(null);
		String encryptedNullInput = UTIL_SessionEncryption.encrypt(null);

		Test.stopTest();

		Assert.areEqual(UTIL_String.EMPTY, decryptedEmptyString, MSG_VALUE_EQUALITY);
		Assert.areEqual(UTIL_String.EMPTY, encryptedEmptyString, MSG_VALUE_EQUALITY);
		Assert.isNull(decryptedNullInput, MSG_NULL);
		Assert.isNull(encryptedNullInput, MSG_NULL);
	}
}