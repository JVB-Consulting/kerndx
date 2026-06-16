---
title: "UTIL_Random"
type: class
pageClass: reference
description: "Generates random values across multiple data types for testing and development, including numbers, strings, UUIDs, and mock Salesforce IDs."
author: "Jason Van Beukering"
group: "Utilities"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# UTIL_Random

**Class** · Group: `Utilities`

<div class="apex-member apex-class">

```apex
global inherited sharing class UTIL_Random
```

Generates random values across multiple data types for testing and development, including numbers, strings, UUIDs, and mock Salesforce IDs.

**Example**

```apex
String uuid = UTIL_Random.randomUUID();
String email = UTIL_Random.randomEmail();
Integer number = UTIL_Random.nextInteger(1, 100);
Id mockAccountId = UTIL_Random.randomId(Account.SObjectType);
```

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global static [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [nextBoolean](#nextboolean)() | Produces a random boolean by mapping a binary integer result to true or false. |
| global static [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [nextInteger](#nextinteger)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) upperBound) | Produces a random integer from zero up to the given ceiling. |
| global static [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [nextInteger](#nextinteger)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) lowerBound, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) upperBound) | Produces a random integer between the specified floor and ceiling, both inclusive. |
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [random](#random)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) length) | Builds a random string of the requested length from the printable ASCII character set (codes 32-126). |
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [random](#random)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) length, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) characterSet) | Builds a random string of the requested length by sampling from the supplied character set. |
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [randomAlphabetic](#randomalphabetic)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) length) | Builds a random string of the requested length using only Latin letters (a-z, A-Z). |
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [randomAlphanumeric](#randomalphanumeric)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) length) | Builds a random string of the requested length using Latin letters and decimal digits (a-z, A-Z, 0-9). |
| global static [Date](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_date.htm) [randomDate](#randomdate)() | Produces a random date falling between the Unix epoch (1970-01-01) and the current day. |
| global static [Datetime](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm) [randomDateTime](#randomdatetime)() | Produces a random datetime falling between the Unix epoch (1970-01-01) and the current moment. |
| global static [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [randomDecimal](#randomdecimal)() | Produces a random decimal value with two digits after the decimal point. |
| global static [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [randomDecimal](#randomdecimal)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) scale) | Produces a random decimal with a standard digit count and the caller-specified fractional precision. |
| global static [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [randomDecimal](#randomdecimal)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) length, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) scale) | Produces a random decimal with a caller-specified whole-number digit count and fractional precision. |
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [randomDescription](#randomdescription)() | Produces a random alphabetic string exactly 40 characters long, suitable for description fields. |
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [randomEmail](#randomemail)() | Produces a random, realistic-looking email address by combining name components with a randomly selected provider domain. |
| global static [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [randomId](#randomid)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) sObjectType) | Constructs a mock 18-character Salesforce ID based on the key prefix of the supplied SObjectType, useful for unit tests that need fake record IDs. |
| global static [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [randomInteger](#randominteger)() | Produces a random integer with a standard length of 6 digits. |
| global static [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [randomInteger](#randominteger)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) upperBound) | Produces a random non-negative integer up to the specified ceiling. |
| global static [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [randomIntegerOfLength](#randomintegeroflength)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) requiredLength) | Produces a random integer with exactly the specified number of digits. |
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [randomName](#randomname)() | Produces a random alphabetic string with a standard length of 10 characters. |
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [randomNumber](#randomnumber)() | Produces a random numeric string with a standard length of 6 digits. |
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [randomNumeric](#randomnumeric)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) length) | Builds a random string of the requested length using only decimal digit characters (0-9). |
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [randomPhoneNumber](#randomphonenumber)() | Produces a random international phone number in the format '+[countryCode] ([areaCode]) [part1]-[part2]'. |
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [randomUUID](#randomuuid)() | Produces a universally unique identifier in the standard 8-4-4-4-12 hexadecimal format. |

---

## Method Details

### nextBoolean

<div class="apex-member">

```apex
global static Boolean nextBoolean()
```

Produces a random boolean by mapping a binary integer result to true or false.

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — A randomly selected boolean value.

**Example**

```apex
Boolean randomBool = UTIL_Random.nextBoolean();
System.debug(randomBool); // Outputs: true or false
```

</div>

### nextInteger

<div class="apex-member">

```apex
global static Integer nextInteger(Integer upperBound)
```

Produces a random integer from zero up to the given ceiling.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `upperBound` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The maximum value (inclusive). |

**Returns** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) — An integer between 0 and the absolute value of upperBound.

**Example**

```apex
Integer randomInt = UTIL_Random.nextInteger(100);
System.debug(randomInt); // Outputs: e.g., 42
```

</div>

<div class="apex-member">

```apex
global static Integer nextInteger(Integer lowerBound, Integer upperBound)
```

Produces a random integer between the specified floor and ceiling, both inclusive.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `lowerBound` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The minimum value (inclusive). |
| `upperBound` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The maximum value (inclusive). |

**Returns** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) — An integer within the specified boundaries.

**Example**

```apex
Integer randomInt = UTIL_Random.nextInteger(10, 20);
System.debug(randomInt); // Outputs: e.g., 15
```

</div>

### random

<div class="apex-member">

```apex
global static String random(Integer length)
```

Builds a random string of the requested length from the printable ASCII character set (codes 32-126).

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `length` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | How many characters the result should contain. |

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — A random printable-ASCII string, or an empty string when length is non-positive.

**Example**

```apex
String randomString = UTIL_Random.random(10);
System.debug(randomString); // Outputs: e.g., "Kj#9mP$2vQ"
```

</div>

<div class="apex-member">

```apex
global static String random(Integer length, String characterSet)
```

Builds a random string of the requested length by sampling from the supplied character set.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `length` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | How many characters the result should contain. |
| `characterSet` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The pool of characters to draw from. |

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — A random string composed of characters from the set, or an empty string when length is non-positive.

**Example**

```apex
String randomCustom = UTIL_Random.random(5, 'ABC');
System.debug(randomCustom); // Outputs: e.g., "ABCCB"
```

</div>

### randomAlphabetic

<div class="apex-member">

```apex
global static String randomAlphabetic(Integer length)
```

Builds a random string of the requested length using only Latin letters (a-z, A-Z).

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `length` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | How many characters the result should contain. |

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — A random alphabetic string, or an empty string when length is non-positive.

**Example**

```apex
String randomAlpha = UTIL_Random.randomAlphabetic(6);
System.debug(randomAlpha); // Outputs: e.g., "KjmPqR"
```

</div>

### randomAlphanumeric

<div class="apex-member">

```apex
global static String randomAlphanumeric(Integer length)
```

Builds a random string of the requested length using Latin letters and decimal digits (a-z, A-Z, 0-9).

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `length` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | How many characters the result should contain. |

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — A random alphanumeric string, or an empty string when length is non-positive.

**Example**

```apex
String randomAlphanumeric = UTIL_Random.randomAlphanumeric(8);
System.debug(randomAlphanumeric); // Outputs: e.g., "Kj9mP2vQ"
```

</div>

### randomDate

<div class="apex-member">

```apex
global static Date randomDate()
```

Produces a random date falling between the Unix epoch (1970-01-01) and the current day.

**Returns** [Date](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_date.htm) — A Date that is never in the future.

**Example**

```apex
Date randomDate = UTIL_Random.randomDate();
```

</div>

### randomDateTime

<div class="apex-member">

```apex
global static Datetime randomDateTime()
```

Produces a random datetime falling between the Unix epoch (1970-01-01) and the current moment.

**Returns** [Datetime](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm) — A Datetime that is never in the future.

**Example**

```apex
Datetime randomDt = UTIL_Random.randomDateTime();
```

</div>

### randomDecimal

<div class="apex-member">

```apex
global static Decimal randomDecimal()
```

Produces a random decimal value with two digits after the decimal point.

**Returns** [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) — A Decimal such as 45.67.

**Example**

```apex
Decimal randomDec = UTIL_Random.randomDecimal();
```

</div>

<div class="apex-member">

```apex
global static Decimal randomDecimal(Integer scale)
```

Produces a random decimal with a standard digit count and the caller-specified fractional precision.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `scale` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The number of digits after the decimal point. |

**Returns** [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) — A Decimal with the requested precision.

**Example**

```apex
Decimal randomDec = UTIL_Random.randomDecimal(2);
```

</div>

<div class="apex-member">

```apex
global static Decimal randomDecimal(Integer length, Integer scale)
```

Produces a random decimal with a caller-specified whole-number digit count and fractional precision.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `length` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The magnitude of digits before the decimal point. |
| `scale` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The number of digits after the decimal point. |

**Returns** [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) — A Decimal with the requested scale.

**Example**

```apex
Decimal randomDec = UTIL_Random.randomDecimal(4, 2);
```

</div>

### randomDescription

<div class="apex-member">

```apex
global static String randomDescription()
```

Produces a random alphabetic string exactly 40 characters long, suitable for description fields.

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — A 40-character alphabetic string.

**Example**

```apex
String randomDesc = UTIL_Random.randomDescription();
```

</div>

### randomEmail

<div class="apex-member">

```apex
global static String randomEmail()
```

Produces a random, realistic-looking email address by combining name components with a randomly selected provider domain.

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — A randomly composed email address such as 'john.doe@gmail.com'.

**Example**

```apex
String randomEmail = UTIL_Random.randomEmail();
```

</div>

### randomId

<div class="apex-member">

```apex
global static Id randomId(SObjectType sObjectType)
```

Constructs a mock 18-character Salesforce ID based on the key prefix of the supplied SObjectType, useful for unit tests that need fake record IDs.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `sObjectType` | [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) | The SObject type whose key prefix seeds the mock ID. |

**Returns** [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) — A synthetic 18-character Salesforce ID.

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | When the SObjectType does not yield a valid 3-character key prefix. |

**Example**

```apex
Id mockId = UTIL_Random.randomId(Account.SObjectType);
System.debug(mockId); // Outputs: e.g., "00100000000lACzAAM"
```

</div>

### randomInteger

<div class="apex-member">

```apex
global static Integer randomInteger()
```

Produces a random integer with a standard length of 6 digits.

**Returns** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) — A 6-digit random integer such as 789234.

**Example**

```apex
Integer randomInt = UTIL_Random.randomInteger();
```

</div>

<div class="apex-member">

```apex
global static Integer randomInteger(Integer upperBound)
```

Produces a random non-negative integer up to the specified ceiling.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `upperBound` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The inclusive maximum for the generated value. |

**Returns** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) — A random integer between 0 and upperBound, or null when upperBound is null.

**Example**

```apex
Integer randomInt = UTIL_Random.randomInteger(100);
System.debug(randomInt); // Outputs: e.g., 42
```

</div>

### randomIntegerOfLength

<div class="apex-member">

```apex
global static Integer randomIntegerOfLength(Integer requiredLength)
```

Produces a random integer with exactly the specified number of digits.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `requiredLength` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The exact digit count for the generated integer. |

**Returns** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) — An integer guaranteed to have the requested number of digits.

**Example**

```apex
Integer randomInt = UTIL_Random.randomIntegerOfLength(5);
```

</div>

### randomName

<div class="apex-member">

```apex
global static String randomName()
```

Produces a random alphabetic string with a standard length of 10 characters.

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — A 10-character alphabetic string.

**Example**

```apex
String randomName = UTIL_Random.randomName();
```

</div>

### randomNumber

<div class="apex-member">

```apex
global static String randomNumber()
```

Produces a random numeric string with a standard length of 6 digits.

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — A 6-character numeric string.

**Example**

```apex
String randomNum = UTIL_Random.randomNumber();
```

</div>

### randomNumeric

<div class="apex-member">

```apex
global static String randomNumeric(Integer length)
```

Builds a random string of the requested length using only decimal digit characters (0-9).

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `length` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | How many characters the result should contain. |

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — A random numeric string, or an empty string when length is non-positive.

**Example**

```apex
String randomNum = UTIL_Random.randomNumeric(5);
System.debug(randomNum); // Outputs: e.g., "39281"
```

</div>

### randomPhoneNumber

<div class="apex-member">

```apex
global static String randomPhoneNumber()
```

Produces a random international phone number in the format '+[countryCode] ([areaCode]) [part1]-[part2]'.

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — A formatted phone number such as '+123 (456) 789-0123'.

**Example**

```apex
String randomPhone = UTIL_Random.randomPhoneNumber();
```

</div>

### randomUUID

<div class="apex-member">

```apex
global static String randomUUID()
```

Produces a universally unique identifier in the standard 8-4-4-4-12 hexadecimal format.

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — A freshly generated UUID string.

**Example**

```apex
String uuid = UTIL_Random.randomUUID();
System.debug(uuid); // Outputs: e.g., "550e8400-e29b-41d4-a716-446655440000"
```

</div>

