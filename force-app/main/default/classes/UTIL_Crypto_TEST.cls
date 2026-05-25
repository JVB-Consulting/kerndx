// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Validates UTIL_Crypto digest, key-generation and authenticated-encryption behaviour.
 *
 * @see UTIL_Crypto
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date February 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class UTIL_Crypto_TEST
{
	/**
	 * @description Input shared across digest tests.
	 */
	private static final String SAMPLE_INPUT = 'test string';
	/**
	 * @description Known MD5 hex for SAMPLE_INPUT.
	 */
	private static final String MD5_HEX = '6f8db599de986fab7a21625b7916589c';
	/**
	 * @description Known SHA-1 hex (uppercase) for SAMPLE_INPUT.
	 */
	private static final String SHA1_HEX = '661295C9CBF9D6B2F6428414504A8DEED3020641';
	/**
	 * @description Known SHA-256 hex (lowercase) for SAMPLE_INPUT.
	 */
	private static final String SHA256_HEX = 'd5579c46dfcc7f18207013e65b44e4cb4e2c2298f4ac457ba8f82743f31e930b';

	/**
	 * @description Verifies the MD5 hash matches the known value.
	 */
	@IsTest
	private static void shouldProduceCorrectMd5()
	{
		String result = UTIL_Crypto.generateMD5Hash(SAMPLE_INPUT);
		Assert.areEqual(MD5_HEX, result, 'MD5 hex should match');
		Assert.areEqual(32, result.length(), 'MD5 hex length should be 32');
	}

	/**
	 * @description Verifies null is returned for null, empty and blank MD5 input.
	 */
	@IsTest
	private static void shouldReturnNullForBlankMd5Input()
	{
		Assert.isNull(UTIL_Crypto.generateMD5Hash(null), 'Null input');
		Assert.isNull(UTIL_Crypto.generateMD5Hash(UTIL_String.EMPTY), 'Empty input');
		Assert.isNull(UTIL_Crypto.generateMD5Hash('   '), 'Blank input');
	}

	/**
	 * @description Verifies the SHA-1 hash matches and is uppercase.
	 */
	@IsTest
	private static void shouldProduceCorrectSha1()
	{
		String result = UTIL_Crypto.generateSHA1Hash(SAMPLE_INPUT);
		Assert.areEqual(SHA1_HEX, result, 'SHA-1 hex should match');
		Assert.areEqual(40, result.length(), 'SHA-1 hex length should be 40');
		Assert.areEqual(result.toUpperCase(), result, 'SHA-1 should be uppercase');
	}

	/**
	 * @description Verifies null is returned for blank SHA-1 input.
	 */
	@IsTest
	private static void shouldReturnNullForBlankSha1Input()
	{
		Assert.isNull(UTIL_Crypto.generateSHA1Hash(null), 'Null input');
		Assert.isNull(UTIL_Crypto.generateSHA1Hash(UTIL_String.EMPTY), 'Empty input');
	}

	/**
	 * @description Verifies the SHA-256 hash matches and is lowercase.
	 */
	@IsTest
	private static void shouldProduceCorrectSha256()
	{
		String result = UTIL_Crypto.generateSHA256Hash(SAMPLE_INPUT);
		Assert.areEqual(SHA256_HEX, result, 'SHA-256 hex should match');
		Assert.areEqual(64, result.length(), 'SHA-256 hex length should be 64');
		Assert.areEqual(result.toLowerCase(), result, 'SHA-256 should be lowercase');
	}

	/**
	 * @description Verifies null is returned for blank SHA-256 input.
	 */
	@IsTest
	private static void shouldReturnNullForBlankSha256Input()
	{
		Assert.isNull(UTIL_Crypto.generateSHA256Hash(null), 'Null input');
	}

	/**
	 * @description Verifies repeated hashing of the same value produces identical output.
	 */
	@IsTest
	private static void shouldBeDeterministic()
	{
		Assert.areEqual(UTIL_Crypto.generateMD5Hash(SAMPLE_INPUT), UTIL_Crypto.generateMD5Hash(SAMPLE_INPUT), 'MD5 determinism');
		Assert.areEqual(UTIL_Crypto.generateSHA1Hash(SAMPLE_INPUT), UTIL_Crypto.generateSHA1Hash(SAMPLE_INPUT), 'SHA-1 determinism');
		Assert.areEqual(UTIL_Crypto.generateSHA256Hash(SAMPLE_INPUT), UTIL_Crypto.generateSHA256Hash(SAMPLE_INPUT), 'SHA-256 determinism');
	}

	/**
	 * @description Verifies distinct inputs yield distinct digests.
	 */
	@IsTest
	private static void shouldDifferForDistinctInputs()
	{
		Assert.areNotEqual(UTIL_Crypto.generateMD5Hash('alpha'), UTIL_Crypto.generateMD5Hash('bravo'), 'MD5 collision');
		Assert.areNotEqual(UTIL_Crypto.generateSHA1Hash('alpha'), UTIL_Crypto.generateSHA1Hash('bravo'), 'SHA-1 collision');
	}

	/**
	 * @description Verifies key generation produces a 32-byte blob.
	 */
	@IsTest
	private static void shouldGenerate256BitKey()
	{
		Blob key = UTIL_Crypto.generateEncryptionKey();
		Assert.isNotNull(key, 'Key should not be null');
		Assert.areEqual(32, key.size(), 'Key should be 32 bytes');
	}

	/**
	 * @description Verifies successive keys are unique.
	 */
	@IsTest
	private static void shouldGenerateUniqueKeys()
	{
		Blob first = UTIL_Crypto.generateEncryptionKey();
		Blob second = UTIL_Crypto.generateEncryptionKey();
		Assert.areNotEqual(EncodingUtil.base64Encode(first), EncodingUtil.base64Encode(second), 'Keys should differ');
	}

	/**
	 * @description Verifies encrypt then decrypt returns the original text and the envelope has three segments.
	 */
	@IsTest
	private static void shouldRoundTripSuccessfully()
	{
		Blob key = UTIL_Crypto.generateEncryptionKey();
		String original = 'Classified payload';

		String envelope = UTIL_Crypto.encryptWithIntegrity(key, original);
		Assert.areNotEqual(original, envelope, 'Envelope should differ from plain text');
		Assert.areEqual(3, envelope.split(':').size(), 'Envelope should have three segments');

		String recovered = UTIL_Crypto.decryptWithIntegrity(key, envelope);
		Assert.areEqual(original, recovered, 'Decrypted text should match original');
	}

	/**
	 * @description Verifies blank inputs pass through encrypt unchanged.
	 */
	@IsTest
	private static void shouldPassThroughBlankOnEncrypt()
	{
		Blob key = UTIL_Crypto.generateEncryptionKey();
		Assert.isNull(UTIL_Crypto.encryptWithIntegrity(key, null), 'Null passthrough');
		Assert.areEqual(UTIL_String.EMPTY, UTIL_Crypto.encryptWithIntegrity(key, UTIL_String.EMPTY), 'Empty passthrough');
		Assert.areEqual('   ', UTIL_Crypto.encryptWithIntegrity(key, '   '), 'Blank passthrough');
	}

	/**
	 * @description Verifies blank inputs pass through decrypt unchanged.
	 */
	@IsTest
	private static void shouldPassThroughBlankOnDecrypt()
	{
		Blob key = UTIL_Crypto.generateEncryptionKey();
		Assert.isNull(UTIL_Crypto.decryptWithIntegrity(key, null), 'Null passthrough');
		Assert.areEqual(UTIL_String.EMPTY, UTIL_Crypto.decryptWithIntegrity(key, UTIL_String.EMPTY), 'Empty passthrough');
	}

	/**
	 * @description Verifies an envelope with fewer than three segments is rejected.
	 */
	@IsTest
	private static void shouldRejectMalformedEnvelope()
	{
		try
		{
			UTIL_Crypto.decryptWithIntegrity(UTIL_Crypto.generateEncryptionKey(), 'only:two');
			Assert.fail('Should throw IllegalArgumentException');
		}
		catch(IllegalArgumentException caught)
		{
			Assert.isTrue(caught.getMessage().contains(UTIL_Crypto.ERROR_INVALID_PAYLOAD), 'Expected payload error');
		}
	}

	/**
	 * @description Verifies tampered ciphertext fails HMAC verification.
	 */
	@IsTest
	private static void shouldDetectTampering()
	{
		Blob key = UTIL_Crypto.generateEncryptionKey();
		String envelope = UTIL_Crypto.encryptWithIntegrity(key, 'Original content');
		List<String> segments = envelope.split(':');
		segments[1] = EncodingUtil.base64Encode(Blob.valueOf('corrupted data!!'));

		try
		{
			UTIL_Crypto.decryptWithIntegrity(key, String.join(segments, ':'));
			Assert.fail('Should throw SecurityException');
		}
		catch(SecurityException caught)
		{
			Assert.isTrue(caught.getMessage().contains(UTIL_Crypto.ERROR_HMAC_VALIDATION_FAILED), 'Expected HMAC error');
		}
	}

	/**
	 * @description Verifies a wrong key fails HMAC verification.
	 */
	@IsTest
	private static void shouldRejectWrongKey()
	{
		Blob correctKey = UTIL_Crypto.generateEncryptionKey();
		Blob wrongKey = UTIL_Crypto.generateEncryptionKey();
		String envelope = UTIL_Crypto.encryptWithIntegrity(correctKey, 'Protected data');

		try
		{
			UTIL_Crypto.decryptWithIntegrity(wrongKey, envelope);
			Assert.fail('Should throw SecurityException');
		}
		catch(SecurityException caught)
		{
			Assert.isTrue(caught.getMessage().contains(UTIL_Crypto.ERROR_HMAC_VALIDATION_FAILED), 'Expected HMAC error');
		}
	}

	/**
	 * @description Verifies random IV produces different envelopes for the same key and text.
	 */
	@IsTest
	private static void shouldVaryWithRandomIv()
	{
		Blob key = UTIL_Crypto.generateEncryptionKey();
		String text = 'Repeated input';
		String first = UTIL_Crypto.encryptWithIntegrity(key, text);
		String second = UTIL_Crypto.encryptWithIntegrity(key, text);

		Assert.areNotEqual(first, second, 'Random IV should produce different envelopes');
		Assert.areEqual(text, UTIL_Crypto.decryptWithIntegrity(key, first), 'First should decrypt');
		Assert.areEqual(text, UTIL_Crypto.decryptWithIntegrity(key, second), 'Second should decrypt');
	}

	/**
	 * @description Verifies different keys produce different envelopes.
	 */
	@IsTest
	private static void shouldDifferWithDifferentKeys()
	{
		String text = 'Identical input';
		String a = UTIL_Crypto.encryptWithIntegrity(UTIL_Crypto.generateEncryptionKey(), text);
		String b = UTIL_Crypto.encryptWithIntegrity(UTIL_Crypto.generateEncryptionKey(), text);
		Assert.areNotEqual(a, b, 'Different keys should yield different envelopes');
	}
}