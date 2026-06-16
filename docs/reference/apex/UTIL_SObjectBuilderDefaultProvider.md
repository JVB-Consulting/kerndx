---
title: "UTIL_SObjectBuilderDefaultProvider"
type: class
pageClass: reference
description: "Provides the default value generation logic for the SObjectBuilder. Subscribers should extend THIS class to override default values or define custom required fields for SObjects."
author: "Jason Van Beukering"
group: "Testing"
date: "November 2025, May 2026"
since: "1.0"
category: apex
---

# UTIL_SObjectBuilderDefaultProvider

**Class** · Group: `Testing`

```apex
global virtual inherited sharing class UTIL_SObjectBuilderDefaultProvider extends TST_Builder.DefaultValueProvider
```

**Extends:** [TST_Builder.DefaultValueProvider](TST_Builder.DefaultValueProvider.md)

Provides the default value generation logic for the SObjectBuilder. Subscribers should extend THIS class to override default values or define custom required fields for SObjects.

**Since:** 1.0

**Example:**

```apex
global class MyDefaultProvider extends UTIL_SObjectBuilderDefaultProvider
{
    global override Set<SObjectField> defineSObjectRequiredFields(SObjectType sObjectType)
    {
        if(sObjectType == Account.SObjectType)
        {
            return new Set<SObjectField>{ Account.Industry };
        }
        return null;
    }
}
```

**See Also:** [TST_Builder](TST_Builder.md)

---

## Methods

| Method | Description |
|--------|-------------|
| global virtual [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)> [defineSObjectOptionalFields](#definesobjectoptionalfields)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) sObjectType) | Defines a set of optional fields for a given SObject. |
| global virtual [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)> [defineSObjectRequiredFields](#definesobjectrequiredfields)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) sObjectType) | Defines a set of required fields for a given SObject. |
| global virtual [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [getCheckboxDefaultValue](#getcheckboxdefaultvalue)([DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm) fieldDescribe, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) recordIndex) | Provides the default value for a Checkbox field type. |
| global virtual [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [getCurrencyDefaultValue](#getcurrencydefaultvalue)([DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm) fieldDescribe, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) recordIndex) | Provides the default value for a Currency field type. |
| global virtual [Date](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_date.htm) [getDateDefaultValue](#getdatedefaultvalue)([DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm) fieldDescribe, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) recordIndex) | Provides the default value for a Date field type. |
| global virtual [Datetime](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm) [getDateTimeDefaultValue](#getdatetimedefaultvalue)([DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm) fieldDescribe, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) recordIndex) | Provides the default value for a Datetime field type. |
| global virtual [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [getDecimalDefaultValue](#getdecimaldefaultvalue)([DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm) fieldDescribe, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) recordIndex) | Provides the default value for a Decimal field type. |
| global virtual [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) [getDefaultValue](#getdefaultvalue)([DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm) fieldDescribe, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) recordIndex) | Generates a default value for a given field of an SObject. |
| global virtual [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [getEmailDefaultValue](#getemaildefaultvalue)([DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm) fieldDescribe, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) recordIndex) | Provides the default value for an Email field type. |
| global virtual [Location](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_system_Location.htm) [getGeolocationDefaultValue](#getgeolocationdefaultvalue)([DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm) fieldDescribe, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) recordIndex) | Provides the default value for a Geolocation field type. |
| global virtual [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [getMultiPicklistDefaultValue](#getmultipicklistdefaultvalue)([DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm) fieldDescribe, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) recordIndex) | Provides the default value for a Multipicklist field type. |
| global virtual [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [getPercentDefaultValue](#getpercentdefaultvalue)([DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm) fieldDescribe, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) recordIndex) | Provides the default value for a Percent field type. |
| global virtual [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [getPhoneDefaultValue](#getphonedefaultvalue)([DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm) fieldDescribe, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) recordIndex) | Provides the default value for a Phone field type. |
| global virtual [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [getPicklistDefaultValue](#getpicklistdefaultvalue)([DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm) fieldDescribe, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) recordIndex) | Provides the default value for a Picklist field type. |
| global virtual [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [getTextAreaDefaultValue](#gettextareadefaultvalue)([DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm) fieldDescribe, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) recordIndex) | Provides the default value for a TextArea field type. |
| global virtual [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [getTextDefaultValue](#gettextdefaultvalue)([DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm) fieldDescribe, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) recordIndex) | Provides the default value for a Text field type. |
| global virtual [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [getURLDefaultValue](#geturldefaultvalue)([DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm) fieldDescribe, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) recordIndex) | Provides the default value for a URL field type. |

---

## Method Details

### defineSObjectOptionalFields

<div class="apex-member">

```apex
global virtual Set<SObjectField> defineSObjectOptionalFields(SObjectType sObjectType)
```

Defines a set of optional fields for a given SObject. Can be overridden in a subclass.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `sObjectType` | [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) | The SObjectType for which the optional fields will be defined. |

**Returns** [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) — A set of defined optional fields.

**Example**

```apex
Set<SObjectField> result = instance.defineSObjectOptionalFields(Account.SObjectType);
```

</div>

### defineSObjectRequiredFields

<div class="apex-member">

```apex
global virtual Set<SObjectField> defineSObjectRequiredFields(SObjectType sObjectType)
```

Defines a set of required fields for a given SObject. Can be overridden in a subclass.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `sObjectType` | [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) | The SObjectType for which the required fields will be defined. |

**Returns** [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) — A set of defined required fields.

**Example**

```apex
Set<SObjectField> result = instance.defineSObjectRequiredFields(Account.SObjectType);
```

</div>

### getCheckboxDefaultValue

<div class="apex-member">

```apex
global virtual Boolean getCheckboxDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
```

Provides the default value for a Checkbox field type.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `fieldDescribe` | [DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm) | The field describe information. |
| `recordIndex` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The index number (starting from 0) of the record being created. |

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — The default Boolean value.

**Example**

```apex
Boolean result = instance.getCheckboxDefaultValue(Account.Name.getDescribe(), 10);
```

</div>

### getCurrencyDefaultValue

<div class="apex-member">

```apex
global virtual Decimal getCurrencyDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
```

Provides the default value for a Currency field type.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `fieldDescribe` | [DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm) | The field describe information. |
| `recordIndex` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The index number (starting from 0) of the record being created. |

**Returns** [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) — The default Decimal value.

**Example**

```apex
Decimal result = instance.getCurrencyDefaultValue(Account.Name.getDescribe(), 10);
```

</div>

### getDateDefaultValue

<div class="apex-member">

```apex
global virtual Date getDateDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
```

Provides the default value for a Date field type.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `fieldDescribe` | [DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm) | The field describe information. |
| `recordIndex` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The index number (starting from 0) of the record being created. |

**Returns** [Date](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_date.htm) — The default Date value.

**Example**

```apex
Date result = instance.getDateDefaultValue(Account.Name.getDescribe(), 10);
```

</div>

### getDateTimeDefaultValue

<div class="apex-member">

```apex
global virtual Datetime getDateTimeDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
```

Provides the default value for a Datetime field type.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `fieldDescribe` | [DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm) | The field describe information. |
| `recordIndex` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The index number (starting from 0) of the record being created. |

**Returns** [Datetime](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm) — The default Datetime value.

**Example**

```apex
Datetime result = instance.getDateTimeDefaultValue(Account.Name.getDescribe(), 10);
```

</div>

### getDecimalDefaultValue

<div class="apex-member">

```apex
global virtual Decimal getDecimalDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
```

Provides the default value for a Decimal field type.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `fieldDescribe` | [DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm) | The field describe information. |
| `recordIndex` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The index number (starting from 0) of the record being created. |

**Returns** [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) — The default Decimal value.

**Example**

```apex
Decimal result = instance.getDecimalDefaultValue(Account.Name.getDescribe(), 10);
```

</div>

### getDefaultValue

<div class="apex-member">

```apex
global virtual Object getDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
```

Generates a default value for a given field of an SObject.
Can be overridden by descendant classes.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `fieldDescribe` | [DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm) | The field describe information. |
| `recordIndex` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The index number (starting from 0) of the record being created. |

**Returns** [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) — The generated field default value.

**Example**

```apex
Object result = instance.getDefaultValue(Account.Name.getDescribe(), 10);
```

</div>

### getEmailDefaultValue

<div class="apex-member">

```apex
global virtual String getEmailDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
```

Provides the default value for an Email field type.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `fieldDescribe` | [DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm) | The field describe information. |
| `recordIndex` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The index number (starting from 0) of the record being created. |

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — The default String value for an email.

**Example**

```apex
String result = instance.getEmailDefaultValue(Account.Name.getDescribe(), 10);
```

</div>

### getGeolocationDefaultValue

<div class="apex-member">

```apex
global virtual Location getGeolocationDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
```

Provides the default value for a Geolocation field type.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `fieldDescribe` | [DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm) | The field describe information. |
| `recordIndex` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The index number (starting from 0) of the record being created. |

**Returns** [Location](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_system_Location.htm) — The default Location value.

**Example**

```apex
Location result = instance.getGeolocationDefaultValue(Account.Name.getDescribe(), 10);
```

</div>

### getMultiPicklistDefaultValue

<div class="apex-member">

```apex
global virtual String getMultiPicklistDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
```

Provides the default value for a Multipicklist field type.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `fieldDescribe` | [DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm) | The field describe information. |
| `recordIndex` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The index number (starting from 0) of the record being created. |

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — The default String value for a multipicklist.

**Example**

```apex
String result = instance.getMultiPicklistDefaultValue(Account.Name.getDescribe(), 10);
```

</div>

### getPercentDefaultValue

<div class="apex-member">

```apex
global virtual Decimal getPercentDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
```

Provides the default value for a Percent field type.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `fieldDescribe` | [DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm) | The field describe information. |
| `recordIndex` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The index number (starting from 0) of the record being created. |

**Returns** [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) — The default Decimal value.

**Example**

```apex
Decimal result = instance.getPercentDefaultValue(Account.Name.getDescribe(), 10);
```

</div>

### getPhoneDefaultValue

<div class="apex-member">

```apex
global virtual String getPhoneDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
```

Provides the default value for a Phone field type.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `fieldDescribe` | [DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm) | The field describe information. |
| `recordIndex` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The index number (starting from 0) of the record being created. |

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — The default String value for a phone number.

**Example**

```apex
String result = instance.getPhoneDefaultValue(Account.Name.getDescribe(), 10);
```

</div>

### getPicklistDefaultValue

<div class="apex-member">

```apex
global virtual String getPicklistDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
```

Provides the default value for a Picklist field type.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `fieldDescribe` | [DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm) | The field describe information. |
| `recordIndex` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The index number (starting from 0) of the record being created. |

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — The default String value for a picklist.

**Example**

```apex
String result = instance.getPicklistDefaultValue(Account.Name.getDescribe(), 10);
```

</div>

### getTextAreaDefaultValue

<div class="apex-member">

```apex
global virtual String getTextAreaDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
```

Provides the default value for a TextArea field type.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `fieldDescribe` | [DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm) | The field describe information. |
| `recordIndex` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The index number (starting from 0) of the record being created. |

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — The default String value.

**Example**

```apex
String result = instance.getTextAreaDefaultValue(Account.Name.getDescribe(), 10);
```

</div>

### getTextDefaultValue

<div class="apex-member">

```apex
global virtual String getTextDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
```

Provides the default value for a Text field type.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `fieldDescribe` | [DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm) | The field describe information. |
| `recordIndex` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The index number (starting from 0) of the record being created. |

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — The default String value.

**Example**

```apex
String result = instance.getTextDefaultValue(Account.Name.getDescribe(), 10);
```

</div>

### getURLDefaultValue

<div class="apex-member">

```apex
global virtual String getURLDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
```

Provides the default value for a URL field type.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `fieldDescribe` | [DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm) | The field describe information. |
| `recordIndex` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The index number (starting from 0) of the record being created. |

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — The default String value for a URL.

**Example**

```apex
String result = instance.getURLDefaultValue(Account.Name.getDescribe(), 10);
```

</div>

