// SPDX-License-Identifier: Apache-2.0
public with sharing class KernNoRawCrypto_Negative
{
	public static void hashThroughUtility()
	{
		String hash = UTIL_Crypto.generateSHA256Hash('value');
		Blob key = kern.UTIL_Crypto.generateEncryptionKey();
		String digest = MyCrypto.generateDigest('value');
	}
}
