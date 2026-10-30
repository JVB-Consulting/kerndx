// SPDX-License-Identifier: Apache-2.0
public with sharing class KernNoRawCrypto_Positive
{
	public static void hashRaw()
	{
		Blob digest = Crypto.generateDigest('SHA-256', Blob.valueOf('value'));
		Blob key = Crypto.generateAesKey(256);
		Blob encrypted = crypto.encryptWithManagedIV('AES256', key, digest);
	}
}
