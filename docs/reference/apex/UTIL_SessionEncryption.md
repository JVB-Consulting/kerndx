---
title: "UTIL_SessionEncryption"
type: class
pageClass: reference
description: "Utility class providing bi-directional encryption and decryption capabilities with automatic key management and expiry. This class uses AES256 encryption combined with HMAC-SHA256 (Encrypt-then-MAC) t"
author: "Jason Van Beukering"
group: "Utilities"
date: "January 2025, May 2026"
since: "1.0"
category: apex
---

# UTIL_SessionEncryption

**Class** · Group: `Utilities`

```apex
global inherited sharing class UTIL_SessionEncryption
```

Utility class providing bi-directional encryption and decryption capabilities with automatic key management and expiry. This class uses AES256 encryption combined with HMAC-SHA256 (Encrypt-then-MAC) to ensure both confidentiality and integrity.

## CRITICAL ARCHITECTURAL WARNING

This utility uses EPHEMERAL STORAGE (Platform Cache) for encryption keys.
Keys are NOT persisted to the database. If the cache expires, is flushed, or the session ends,
the key is LOST FOREVER and any data encrypted with it becomes permanently unrecoverable.

DO NOT USE THIS CLASS FOR:

    - Persisting encrypted data to SObjects or Settings.

    - Long-term data storage.

USE THIS CLASS ONLY FOR:

    - Short-lived data passing (e.g., ViewState, temporary token exchange).

    - Session-scoped data where data loss is acceptable upon session expiry.

**Since:** 1.0

**Example:**

```apex
String encrypted = UTIL_SessionEncryption.encrypt('Sensitive Data');
String decrypted = UTIL_SessionEncryption.decrypt(encrypted);
Boolean available = UTIL_SessionEncryption.isAvailable();
```

---

## Methods

| Method | Description |
|--------|-------------|
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [decrypt](#decrypt)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) encryptedTextValue) | Decrypts a Base64-encoded string using the cached encryption key. |
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [encrypt](#encrypt)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) plainTextValue) | Encrypts a string using the current user's encryption key and appends an HMAC. |
| global static [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isAvailable](#isavailable)() | Safely checks if the Crypto utility is available for use (Cache is online). |

---

## Method Details

### decrypt

<div class="apex-member">

```apex
global static String decrypt(String encryptedTextValue)
```

Decrypts a Base64-encoded string using the cached encryption key.
Verifies the HMAC before attempting decryption to ensure integrity.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `encryptedTextValue` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The Base64-encoded encrypted string (IV:Cipher:HMAC). |

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — String The decrypted string, or the input if it is blank.

**Throws**

| Exception | Description |
|-----------|-------------|
| [Exception](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | If decryption fails due to invalid key or algorithm issues. |
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | If the encrypted text is invalid or no encryption key is found. |

**Example**

```apex
String plainTextValue = 'Sensitive Data';
String encrypted = UTIL_SessionEncryption.encrypt(plainTextValue);
String decrypted = UTIL_SessionEncryption.decrypt(encrypted);
System.debug(decrypted); // Outputs: Sensitive Data
try
{
decrypted = UTIL_SessionEncryption.decrypt('InvalidBase64');
}
catch(IllegalArgumentException e)
{
System.debug('Invalid input: ' + e.getMessage());
}
```

</div>

### encrypt

<div class="apex-member">

```apex
global static String encrypt(String plainTextValue)
```

Encrypts a string using the current user's encryption key and appends an HMAC.
The method generates a new key if none exists in the cache and stores it with an expiry.

Format: Base64(IV) : Base64(Cipher) : Base64(HMAC)

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `plainTextValue` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The string to encrypt. |

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — String The encrypted string in Base64 format with HMAC, or the input if it is blank.

**Throws**

| Exception | Description |
|-----------|-------------|
| [Exception](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | If encryption fails due to invalid key, algorithm issues, or cache write failures. |

**Example**

```apex
String plainTextValue = 'Sensitive Data';
String encrypted = UTIL_SessionEncryption.encrypt(plainTextValue);
System.debug(encrypted); // Outputs: Base64-encoded encrypted string
String blankInput = '';
encrypted = UTIL_SessionEncryption.encrypt(blankInput);
System.debug(encrypted); // Outputs: ''
```

</div>

### isAvailable

<div class="apex-member">

```apex
global static Boolean isAvailable()
```

Safely checks if the Crypto utility is available for use (Cache is online).
Useful for UI controllers to check availability without needing try/catch blocks.

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — Boolean True if cache is available, False otherwise.

**Example**

```apex
Boolean result = UTIL_SessionEncryption.isAvailable();
```

</div>

