// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Cryptographic helpers for hashing, key generation and authenticated encryption.
 * Supports MD5, SHA-1 (uppercase) and SHA-256 (lowercase) digests plus AES-256/HMAC-SHA256
 * encrypt-then-MAC envelopes.
 *
 * @see UTIL_Crypto_TEST
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date February 2026, May 2026
 */
public inherited sharing class UTIL_Crypto
{
	/**
	 * @description MD5 algorithm identifier.
	 */
	private static final String HASH_MD5 = 'MD5';
	/**
	 * @description SHA-1 algorithm identifier.
	 */
	@SuppressWarnings('PMD.AvoidHardcodedCredentialsInFieldDecls')
	private static final String HASH_SHA1 = 'SHA-1';
	/**
	 * @description SHA-256 algorithm identifier.
	 */
	@SuppressWarnings('PMD.AvoidHardcodedCredentialsInFieldDecls')
	private static final String HASH_SHA256 = 'SHA256';
	/**
	 * @description AES-256 algorithm identifier for symmetric encryption.
	 */
	@SuppressWarnings('PMD.AvoidHardcodedCredentialsInFieldDecls')
	private static final String CIPHER_AES = 'AES256';
	/**
	 * @description HMAC-SHA256 algorithm identifier for message authentication.
	 */
	@SuppressWarnings('PMD.AvoidHardcodedCredentialsInFieldDecls')
	private static final String MAC_SHA256 = 'HmacSHA256';

	/**
	 * @description Key size in bits for AES-256.
	 */
	private static final Integer KEY_BITS = 256;
	/**
	 * @description IV size in bits for AES CBC mode.
	 */
	private static final Integer IV_BITS = 128;
	/**
	 * @description Separator between IV, ciphertext and HMAC in the envelope string.
	 */
	private static final String SEPARATOR = ':';
	/**
	 * @description Number of segments expected in a valid envelope (IV + cipher + MAC).
	 */
	private static final Integer SEGMENT_COUNT = 3;

	/**
	 * @description Error raised when the envelope string does not contain exactly three segments.
	 */
	@TestVisible
	@SuppressWarnings('PMD.AvoidHardcodedCredentialsInFieldDecls')
	private static final String ERROR_INVALID_PAYLOAD = 'Invalid encrypted payload format';

	/**
	 * @description Error raised when HMAC verification fails during decryption.
	 */
	@TestVisible
	@SuppressWarnings('PMD.AvoidHardcodedCredentialsInFieldDecls')
	private static final String ERROR_HMAC_VALIDATION_FAILED = 'HMAC validation failed - data may have been tampered with';

	/**
	 * @description Produces a lowercase hex MD5 digest.
	 *
	 * @param input The value to hash.
	 *
	 * @return Hex string or null when input is blank.
	 */
	public static String generateMD5Hash(String input)
	{
		return computeDigest(input, HASH_MD5, false);
	}

	/**
	 * @description Produces an uppercase hex SHA-1 digest.
	 *
	 * @param input The value to hash.
	 *
	 * @return Hex string or null when input is blank.
	 */
	public static String generateSHA1Hash(String input)
	{
		return computeDigest(input, HASH_SHA1, true);
	}

	/**
	 * @description Produces a lowercase hex SHA-256 digest.
	 *
	 * @param input The value to hash.
	 *
	 * @return Hex string or null when input is blank.
	 */
	public static String generateSHA256Hash(String input)
	{
		return computeDigest(input, HASH_SHA256, false);
	}

	/**
	 * @description Generates a random 256-bit AES key suitable for use with
	 * {@link #encryptWithIntegrity(Blob, String)}.
	 *
	 * @return A 32-byte key blob.
	 */
	public static Blob generateEncryptionKey()
	{
		return Crypto.generateAesKey(KEY_BITS);
	}

	/**
	 * @description Encrypts the given text with AES-256 using a random IV and appends an
	 * HMAC-SHA256 tag for tamper detection. The returned envelope has the format
	 * {@code Base64(IV):Base64(Ciphertext):Base64(HMAC)}.
	 *
	 * @param key A 256-bit AES key.
	 * @param plainText The value to encrypt.
	 *
	 * @return The three-segment envelope string, or the original value when blank.
	 */
	public static String encryptWithIntegrity(Blob key, String plainText)
	{
		if(String.isBlank(plainText))
		{
			return plainText;
		}

		Blob iv = Crypto.generateAesKey(IV_BITS);
		Blob cipherBlob = Crypto.encrypt(CIPHER_AES, key, iv, Blob.valueOf(plainText));

		String ivEncoded = EncodingUtil.base64Encode(iv);
		String cipherEncoded = EncodingUtil.base64Encode(cipherBlob);
		String signedPortion = ivEncoded + SEPARATOR + cipherEncoded;

		Blob macKey = Crypto.generateDigest(HASH_SHA256, key);
		Blob mac = Crypto.generateMac(MAC_SHA256, Blob.valueOf(signedPortion), macKey);

		return signedPortion + SEPARATOR + EncodingUtil.base64Encode(mac);
	}

	/**
	 * @description Verifies the HMAC tag and decrypts the envelope produced by
	 * {@link #encryptWithIntegrity(Blob, String)}.
	 *
	 * @param key The same 256-bit AES key used during encryption.
	 * @param encryptedPayload The three-segment envelope string.
	 *
	 * @return The original plain text, or the original value when blank.
	 *
	 * @throws IllegalArgumentException when the envelope does not contain three segments.
	 * @throws SecurityException when the HMAC check fails.
	 */
	public static String decryptWithIntegrity(Blob key, String encryptedPayload)
	{
		if(String.isBlank(encryptedPayload))
		{
			return encryptedPayload;
		}

		List<String> segments = encryptedPayload.split(SEPARATOR);
		if(segments.size() != SEGMENT_COUNT)
		{
			throw new IllegalArgumentException(ERROR_INVALID_PAYLOAD);
		}

		String ivEncoded = segments[0];
		String cipherEncoded = segments[1];
		String macEncoded = segments[2];

		Blob macKey = Crypto.generateDigest(HASH_SHA256, key);
		String signedPortion = ivEncoded + SEPARATOR + cipherEncoded;

		if(!Crypto.verifyHmac(MAC_SHA256, Blob.valueOf(signedPortion), macKey, EncodingUtil.base64Decode(macEncoded)))
		{
			throw new SecurityException(ERROR_HMAC_VALIDATION_FAILED);
		}

		Blob iv = EncodingUtil.base64Decode(ivEncoded);
		Blob cipherBlob = EncodingUtil.base64Decode(cipherEncoded);

		return Crypto.decrypt(CIPHER_AES, key, iv, cipherBlob).toString();
	}

	/**
	 * @description Internal digest helper that returns a hex string in the requested case.
	 *
	 * @param input The value to hash.
	 * @param algorithm The digest algorithm name.
	 * @param upper True for uppercase output, false for lowercase.
	 *
	 * @return Hex string or null when input is blank.
	 */
	private static String computeDigest(String input, String algorithm, Boolean upper)
	{
		if(String.isBlank(input))
		{
			return null;
		}
		String hex = EncodingUtil.convertToHex(Crypto.generateDigest(algorithm, Blob.valueOf(input)));
		return upper ? hex?.toUpperCase() : hex;
	}
}