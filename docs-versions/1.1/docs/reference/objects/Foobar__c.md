---
title: "Foobar__c"
type: sobject
description: "Test object for managed package unit tests. Used to demonstrate and validate library functions. Do not use outside test contexts."
category: objects
---

# Foobar__c

**Sobject**

```apex
global class Foobar__c extends SObject
```

**Extends:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)

Test object for managed package unit tests. Used to demonstrate and validate library functions. Do not use outside test contexts.

---

## Fields

| Field | Description |
|-------|-------------|
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [Checkbox__c](#checkbox__c) | Test Checkbox field for unit tests. |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [Currency__c](#currency__c) | Test Currency field for unit tests. |
| global [Date](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_date.htm) [Date__c](#date__c) | Test Date field for unit tests. |
| global [Datetime](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm) [Datetime__c](#datetime__c) | Test DateTime field for unit tests. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [Email__c](#email__c) | Test Email field for unit tests. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [ExternalId__c](#externalid__c) | External ID field for upsert operation testing in DML_Transaction. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [Foobars__r](#foobars__r) | Reciprocal relationship for Foobar__c.Lookup__c. |
| global [Location](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_system_Location.htm) [Geolocation__c](#geolocation__c) | Test Geolocation (Latitude/Longitude) field for unit tests. |
| global [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [Lookup__c](#lookup__c) | Test Lookup field (self-referential) for unit tests. |
| global [Foobar__c](../objects/Foobar__c.md) [Lookup__r](#lookup__r) | Test Lookup field (self-referential) for unit tests. |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [NumberDecimal__c](#numberdecimal__c) | Test Number (Decimal) field for unit tests. |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [NumberInteger__c](#numberinteger__c) | Test Number (Integer, 3, 0) field for unit tests. |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [Percent__c](#percent__c) | Test Percent field for unit tests. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [Phone__c](#phone__c) | Test Phone field for unit tests. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [Picklist__c](#picklist__c) | Test Picklist field for unit tests. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [PicklistMultiSelect__c](#picklistmultiselect__c) | Test Multiselect Picklist field for unit tests. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [Text__c](#text__c) | Test Text field (255) for unit tests. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [TextArea__c](#textarea__c) | Test Text Area field for unit tests. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [TextAreaEncrypted__c](#textareaencrypted__c) | Test Encrypted Text Area field for unit tests. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [TextAreaLong__c](#textarealong__c) | Test Long Text Area field for unit tests. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [TextAreaRich__c](#textarearich__c) | Test Rich Text Area field for unit tests. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [URL__c](#url__c) | Test URL field for unit tests. |

---

## Field Details

### Checkbox__c

```apex
global Boolean Checkbox__c
```

Test Checkbox field for unit tests.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Checkbox |
| Default Value | false |

### Currency__c

```apex
global Decimal Currency__c
```

Test Currency field for unit tests.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Currency(18,0) |
| Required | false |

### Date__c

```apex
global Date Date__c
```

Test Date field for unit tests.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Date |
| Required | false |

### Datetime__c

```apex
global Datetime Datetime__c
```

Test DateTime field for unit tests.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Date Time |
| Required | false |

### Email__c

```apex
global String Email__c
```

Test Email field for unit tests.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Email |
| Required | false |
| Unique | false |
| External ID | false |

### ExternalId__c

```apex
global String ExternalId__c
```

External ID field for upsert operation testing in DML_Transaction.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(50) |
| Required | false |
| Unique | false |
| External ID | true |

### Foobars__r

```apex
global List<Foobar__c> Foobars__r
```

Reciprocal relationship for **`Foobar__c.Lookup__c`** .

### Geolocation__c

```apex
global Location Geolocation__c
```

Test Geolocation (Latitude/Longitude) field for unit tests.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Location |
| Required | false |

### Lookup__c

```apex
global Id Lookup__c
```

Test Lookup field (self-referential) for unit tests.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Foobar__c |
| Required | false |

### Lookup__r

```apex
global Foobar__c Lookup__r
```

Test Lookup field (self-referential) for unit tests.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Foobar__c |
| Required | false |

### NumberDecimal__c

```apex
global Decimal NumberDecimal__c
```

Test Number (Decimal) field for unit tests.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Number(18,0) |
| Required | false |
| Unique | false |
| External ID | false |

### NumberInteger__c

```apex
global Decimal NumberInteger__c
```

Test Number (Integer, 3, 0) field for unit tests.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Number(3,0) |
| Required | false |
| Unique | false |
| External ID | false |

### Percent__c

```apex
global Decimal Percent__c
```

Test Percent field for unit tests.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Percent(9,9) |
| Required | false |

### Phone__c

```apex
global String Phone__c
```

Test Phone field for unit tests.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Phone |
| Required | false |

### Picklist__c

```apex
global String Picklist__c
```

Test Picklist field for unit tests.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Picklist |
| Required | false |

**Picklist Values:**

| API Name | Label | Active |
|----------|-------|--------|
| `Hot` | Hot | No |
| `Warm` | Warm | Yes |
| `Cold` | Cold | No |

### PicklistMultiSelect__c

```apex
global String PicklistMultiSelect__c
```

Test Multiselect Picklist field for unit tests.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Multiselect Picklist |
| Required | false |

**Picklist Values:**

| API Name | Label | Active |
|----------|-------|--------|
| `One` | One | Yes |
| `Two` | Two | Yes |
| `Three` | Three | Yes |
| `Four` | Four | Yes |
| `Five` | Five | Yes |

### Text__c

```apex
global String Text__c
```

Test Text field (255) for unit tests.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(255) |
| Required | false |
| Unique | false |
| External ID | false |

### TextArea__c

```apex
global String TextArea__c
```

Test Text Area field for unit tests.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text Area |
| Required | false |

### TextAreaEncrypted__c

```apex
global String TextAreaEncrypted__c
```

Test Encrypted Text Area field for unit tests.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Encrypted Text(128) |
| Required | false |
| Mask Type | all |
| Mask Character | asterisk |

### TextAreaLong__c

```apex
global String TextAreaLong__c
```

Test Long Text Area field for unit tests.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Long Text Area(32000) |

### TextAreaRich__c

```apex
global String TextAreaRich__c
```

Test Rich Text Area field for unit tests.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Html |

### URL__c

```apex
global String URL__c
```

Test URL field for unit tests.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Url |
| Required | false |

