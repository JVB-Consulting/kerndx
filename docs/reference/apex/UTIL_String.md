---
title: "UTIL_String"
type: class
pageClass: reference
description: "Various string manipulation utilities"
author: "Jason Van Beukering"
group: "Utilities"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# UTIL_String

**Class** · Group: `Utilities`

<div class="apex-member apex-class">

```apex
global inherited sharing class UTIL_String
```

Various string manipulation utilities

**Example**

```apex
String shortened = UTIL_String.abbreviate('Now is the time for all good men', 10);
String joined = UTIL_String.join(new List<Object>{'a', 'b', 'c'}, ',');
List<String> parts = UTIL_String.split('one,two,three', ',');
String replaced = UTIL_String.replace('Hello World', 'World', 'Apex');
```

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [abbreviate](#abbreviate)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) input, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) maxWidth) | Abbreviates a String using ellipses. |
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [abbreviate](#abbreviate)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) input, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) offset, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) maxWidth) | Abbreviates a String using ellipses. |
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [abbreviate](#abbreviate)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) input, [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Abbreviates a String to fit within the maximum length of the specified SObjectField. |
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [join](#join)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> objectArray, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) separator) | Joins the elements of the provided array into a single String containing the provided list of elements. |
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [join](#join)([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> stringSet, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) separator) | Joins the elements of the provided array into a single String containing the provided list of elements. |
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [maskString](#maskstring)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) sensitiveString) | Will mask the given string |
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [maskString](#maskstring)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) sensitiveString, [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) percentageOfStringToBeMasked) | Will mask the given string |
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [maskString](#maskstring)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) sensitiveString, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) maskCharacter, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) minimumStringLength, [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) percentageOfStringToBeMasked) | Masks a string |
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [remove](#remove)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) input, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) remove) | Removes all occurrences of a substring from within the source string. |
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [replace](#replace)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) text, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) searchString, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) replacement) | Replaces all occurrences of a String within another String. |
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> [split](#split)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) input) | Splits the provided text into an array, using whitespace as the separator. |
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> [split](#split)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) input, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) separatorChars) | Splits the provided text into an array, separators specified. |
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> [split](#split)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) input, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) separatorChars, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) max) | Splits the provided text into an array with a maximum length, separators specified. |
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> [splitByWholeSeparator](#splitbywholeseparator)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) input, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) separator) | Splits the provided text into an array, separator string specified. |

### abbreviate

<div class="apex-member">

```apex
global static String abbreviate(String input, Integer maxWidth)
```

Abbreviates a String using ellipses. This will turn
"Now is the time for all good men" into "Now is the time for..."

Specifically:

- If the number of characters in `input` is less than or equal to
`maxWidth`, return `input`.

- Else abbreviate it to `(substring(input, 0, max-3) + "...")`.

- If `maxWidth` is less than `4`, throw an
`IllegalArgumentException`.

- In no case will it return a String of length greater than
`maxWidth`.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `input` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | the String to check, may be null |
| `maxWidth` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | maximum length of result String, must be at least 4 |

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — abbreviated String, `null` if null String input

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | if the width is too small |

**Example**

```apex
UTIL_String.abbreviate(null, 4);        // returns null
UTIL_String.abbreviate('', 4);          // returns ''
UTIL_String.abbreviate('abcdefg', 6);   // returns 'abc...'
UTIL_String.abbreviate('abcdefg', 7);   // returns 'abcdefg'
UTIL_String.abbreviate('abcdefg', 8);   // returns 'abcdefg'
UTIL_String.abbreviate('abcdefg', 4);   // returns 'a...'
UTIL_String.abbreviate('abcdefg', 3);   // throws IllegalArgumentException
```

</div>

<div class="apex-member">

```apex
global static String abbreviate(String input, Integer offset, Integer maxWidth)
```

Abbreviates a String using ellipses. This will turn
"Now is the time for all good men" into "...is the time for..."

Works like String.abbreviate, but allows you to specify
a "left edge" offset. Note that this left edge is not necessarily going to
be the leftmost character in the result, or the first character following the
ellipses, but it will appear somewhere in the result.

In no case will it return a String of length greater than maxWidth

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `input` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | the String to check, may be null |
| `offset` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | left edge of source String |
| `maxWidth` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | maximum length of result String, must be at least 4 |

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — abbreviated String, `null` if null String input

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | if the width is too small |

**Example**

```apex
UTIL_String.abbreviate(null, 0, 4);                 // returns null
UTIL_String.abbreviate('', 0, 4);                   // returns ''
UTIL_String.abbreviate('abcdefghijklmno', -1, 10);  // returns 'abcdefg...'
UTIL_String.abbreviate('abcdefghijklmno', 0, 10);   // returns 'abcdefg...'
UTIL_String.abbreviate('abcdefghijklmno', 1, 10);   // returns 'abcdefg...'
UTIL_String.abbreviate('abcdefghijklmno', 4, 10);   // returns 'abcdefg...'
UTIL_String.abbreviate('abcdefghijklmno', 5, 10);   // returns '...fghi...'
UTIL_String.abbreviate('abcdefghijklmno', 6, 10);   // returns '...ghij...'
UTIL_String.abbreviate('abcdefghijklmno', 8, 10);   // returns '...ijklmno'
UTIL_String.abbreviate('abcdefghijklmno', 10, 10);  // returns '...ijklmno'
UTIL_String.abbreviate('abcdefghijklmno', 12, 10);  // returns '...ijklmno'
UTIL_String.abbreviate('abcdefghij', 0, 3);         // throws IllegalArgumentException
UTIL_String.abbreviate('abcdefghij', 5, 6);         // throws IllegalArgumentException
```

</div>

<div class="apex-member">

```apex
global static String abbreviate(String input, SObjectField field)
```

Abbreviates a String to fit within the maximum length of the specified SObjectField.
Automatically derives the field length from the field's describe metadata.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `input` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | the String to abbreviate, may be null |
| `field` | [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) | the SObjectField whose length determines the maximum width |

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — abbreviated String fitting within the field length, `null` if null String input

**Example**

```apex
String shortened = UTIL_String.abbreviateToField(longMessage, LogEntry__c.Message__c);
```

</div>

### join

<div class="apex-member">

```apex
global static String join(List<Object> objectArray, String separator)
```

Joins the elements of the provided array into a single String
containing the provided list of elements.

No delimiter is added before or after the list.
Null objects or empty strings within the array are represented by
empty strings.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `objectArray` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | the array of values to join together, may be null |
| `separator` | [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) | the separator character to use |

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — the joined String, `null` if null array input

**Example**

```apex
UTIL_String.join(null, ';');                              // returns null
UTIL_String.join(new List<Object>(), ';');                // returns ''
UTIL_String.join(new List<Object>{null}, ';');            // returns ''
UTIL_String.join(new List<Object>{'a', 'b', 'c'}, ';');   // returns 'a;b;c'
UTIL_String.join(new List<Object>{'a', 'b', 'c'}, null);  // returns 'abc'
UTIL_String.join(new List<Object>{null, '', 'a'}, ';');   // returns ';a'
```

</div>

<div class="apex-member">

```apex
global static String join(Set<String> stringSet, String separator)
```

Joins the elements of the provided `Iterator` into
a single String containing the provided elements.

No delimiter is added before or after the list.
A `null` separator is the same as an empty String ("").

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `stringSet` | [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) | the Iterator of values to join together, may be null |
| `separator` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | the separator character to use, null treated as "" |

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — the joined String, `null` if null iterator input

**Example**

```apex
String result = UTIL_String.join(new Set<String>{'a', 'b'}, ',');
```

</div>

### maskString

<div class="apex-member">

```apex
global static String maskString(String sensitiveString)
```

Will mask the given string

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `sensitiveString` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The string to mask |

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — A Masked string

**Example**

```apex
String result = UTIL_String.maskString('value');
```

</div>

<div class="apex-member">

```apex
global static String maskString(String sensitiveString, Decimal percentageOfStringToBeMasked)
```

Will mask the given string

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `sensitiveString` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The string to mask |
| `percentageOfStringToBeMasked` | [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) | The percentage of string to be masked |

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — A Masked string

**Example**

```apex
String result = UTIL_String.maskString('value', 99.99);
```

</div>

<div class="apex-member">

```apex
global static String maskString(String sensitiveString, String maskCharacter, Integer minimumStringLength, Decimal percentageOfStringToBeMasked)
```

Masks a string

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `sensitiveString` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The string to mask |
| `maskCharacter` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The character to be used for masking |
| `minimumStringLength` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The minimum length of the input string which is to be masked |
| `percentageOfStringToBeMasked` | [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) | The percentage of string to be masked |

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — A Masked string

**Example**

```apex
String result = UTIL_String.maskString('value', 'value', 10, 99.99);
```

</div>

### remove

<div class="apex-member">

```apex
global static String remove(String input, String remove)
```

Removes all occurrences of a substring from within the source string.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `input` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | the source String to search, may be null |
| `remove` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | the String to search for and remove, may be null |

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — the substring with the string removed if found, null if null String input

**Example**

```apex
UTIL_String.remove(null, 'ue');       // returns null
UTIL_String.remove('', 'ue');         // returns ''
UTIL_String.remove('queued', null);   // returns 'queued'
UTIL_String.remove('queued', '');     // returns 'queued'
UTIL_String.remove('queued', 'ue');   // returns 'qd'
UTIL_String.remove('queued', 'zz');   // returns 'queued'
```

</div>

### replace

<div class="apex-member">

```apex
global static String replace(String text, String searchString, String replacement)
```

Replaces all occurrences of a String within another String.

A `null` reference passed to this method is a no-op.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `text` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | text to search and replace in, may be null |
| `searchString` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | the String to search for, may be null |
| `replacement` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | the String to replace it with, may be null |

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — the text with any replacements processed, `null` if null String input

**Example**

```apex
UTIL_String.replace(null, 'a', 'z');    // returns null
UTIL_String.replace('', 'a', 'z');      // returns ''
UTIL_String.replace('any', null, 'z');  // returns 'any'
UTIL_String.replace('any', 'a', null);  // returns 'any'
UTIL_String.replace('any', '', 'z');    // returns 'any'
UTIL_String.replace('aba', 'a', null);  // returns 'aba'
UTIL_String.replace('aba', 'a', '');    // returns 'b'
UTIL_String.replace('aba', 'a', 'z');   // returns 'zbz'
```

</div>

### split

<div class="apex-member">

```apex
global static List<String> split(String input)
```

Splits the provided text into an array, using whitespace as the
separator.
Whitespace is defined by `UTIL_Character.isWhitespace`.

The separator is not included in the returned String array.
Adjacent separators are treated as one separator.
For more control over the split use the StrTokenizer class.

A `null` input String returns `null`.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `input` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | the String to parse, may be null |

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — an array of parsed Strings, `null` if null String input

**Example**

```apex
UTIL_String.split(null);          // returns null
UTIL_String.split('');            // returns new List<String>()
UTIL_String.split('abc def');     // returns new List<String>{'abc', 'def'}
UTIL_String.split('abc  def');    // returns new List<String>{'abc', 'def'}
UTIL_String.split(' abc ');       // returns new List<String>{'abc'}
```

</div>

<div class="apex-member">

```apex
global static List<String> split(String input, String separatorChars)
```

Splits the provided text into an array, separators specified.
This is an alternative to using StringTokenizer.

The separator is not included in the returned String array.
Adjacent separators are treated as one separator.
For more control over the split use the StrTokenizer class.

A `null` input String returns `null`.
A `null` separatorChars splits on whitespace.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `input` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | the String to parse, may be null |
| `separatorChars` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | the characters used as the delimiters, null splits on whitespace |

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — an array of parsed Strings, `null` if null String input

**Example**

```apex
UTIL_String.split(null, ' ');           // returns null
UTIL_String.split('', ' ');             // returns new List<String>()
UTIL_String.split('abc def', null);     // returns new List<String>{'abc', 'def'}
UTIL_String.split('abc def', ' ');      // returns new List<String>{'abc', 'def'}
UTIL_String.split('abc  def', ' ');     // returns new List<String>{'abc', 'def'}
UTIL_String.split('ab:cd:ef', ':');     // returns new List<String>{'ab', 'cd', 'ef'}
```

</div>

<div class="apex-member">

```apex
global static List<String> split(String input, String separatorChars, Integer max)
```

Splits the provided text into an array with a maximum length,
separators specified.

The separator is not included in the returned String array.
Adjacent separators are treated as one separator.

A `null` input String returns `null`.
A `null` separatorChars splits on whitespace.

If more than `max` delimited substrings are found, the last
returned string includes all characters after the first `max - 1`
returned strings (including separator characters).

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `input` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | the String to parse, may be null |
| `separatorChars` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | the characters used as the delimiters, null splits on whitespace |
| `max` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | the maximum number of elements to include in the array. A zero or negative value implies no limit |

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — an array of parsed Strings, `null` if null String input

**Example**

```apex
UTIL_String.split(null, ':', 0);           // returns null
UTIL_String.split('', ':', 0);             // returns new List<String>()
UTIL_String.split('ab cd ef', null, 0);    // returns new List<String>{'ab', 'cd', 'ef'}
UTIL_String.split('ab   cd ef', null, 0);  // returns new List<String>{'ab', 'cd', 'ef'}
UTIL_String.split('ab:cd:ef', ':', 0);     // returns new List<String>{'ab', 'cd', 'ef'}
UTIL_String.split('ab:cd:ef', ':', 2);     // returns new List<String>{'ab', 'cd:ef'}
```

</div>

### splitByWholeSeparator

<div class="apex-member">

```apex
global static List<String> splitByWholeSeparator(String input, String separator)
```

Splits the provided text into an array, separator string specified.

The separator(s) will not be included in the returned String array.
Adjacent separators are treated as one separator.

A `null` input String returns `null`.
A `null` separator splits on whitespace.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `input` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | the String to parse, may be null |
| `separator` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | String containing the String to be used as a delimiter, null splits on whitespace |

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — an array of parsed Strings, `null` if null String was input

**Example**

```apex
UTIL_String.splitByWholeSeparator(null, '-!-');           // returns null
UTIL_String.splitByWholeSeparator('', '-!-');             // returns new List<String>()
UTIL_String.splitByWholeSeparator('ab de fg', null);      // returns new List<String>{'ab', 'de', 'fg'}
UTIL_String.splitByWholeSeparator('ab   de fg', null);    // returns new List<String>{'ab', 'de', 'fg'}
UTIL_String.splitByWholeSeparator('ab:cd:ef', ':');       // returns new List<String>{'ab', 'cd', 'ef'}
UTIL_String.splitByWholeSeparator('ab-!-cd-!-ef', '-!-'); // returns new List<String>{'ab', 'cd', 'ef'}
```

</div>

