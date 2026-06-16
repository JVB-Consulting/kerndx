---
title: "UTIL_SObjectBuilderDefaultProvider"
type: class
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

```apex
global virtual Set<SObjectField> defineSObjectOptionalFields(SObjectType sObjectType)
```

Defines a set of optional fields for a given SObject. Can be overridden in a subclass.

**Parameters:**

- `sObjectType` ([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm)) - The SObjectType for which the optional fields will be defined.

**Returns:** [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) - A set of defined optional fields.

**Since:** 1.0

**Example:**

```apex
Set<SObjectField> result = instance.defineSObjectOptionalFields(Account.SObjectType);
```

### defineSObjectRequiredFields

```apex
global virtual Set<SObjectField> defineSObjectRequiredFields(SObjectType sObjectType)
```

Defines a set of required fields for a given SObject. Can be overridden in a subclass.

**Parameters:**

- `sObjectType` ([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm)) - The SObjectType for which the required fields will be defined.

**Returns:** [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) - A set of defined required fields.

**Since:** 1.0

**Example:**

```apex
Set<SObjectField> result = instance.defineSObjectRequiredFields(Account.SObjectType);
```

### getCheckboxDefaultValue

```apex
global virtual Boolean getCheckboxDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
```

Provides the default value for a Checkbox field type.

**Parameters:**

- `fieldDescribe` ([DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm)) - The field describe information.
- `recordIndex` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - The index number (starting from 0) of the record being created.

**Returns:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) - The default Boolean value.

**Since:** 1.0

**Example:**

```apex
Boolean result = instance.getCheckboxDefaultValue(Account.Name.getDescribe(), 10);
```

### getCurrencyDefaultValue

```apex
global virtual Decimal getCurrencyDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
```

Provides the default value for a Currency field type.

**Parameters:**

- `fieldDescribe` ([DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm)) - The field describe information.
- `recordIndex` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - The index number (starting from 0) of the record being created.

**Returns:** [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) - The default Decimal value.

**Since:** 1.0

**Example:**

```apex
Decimal result = instance.getCurrencyDefaultValue(Account.Name.getDescribe(), 10);
```

### getDateDefaultValue

```apex
global virtual Date getDateDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
```

Provides the default value for a Date field type.

**Parameters:**

- `fieldDescribe` ([DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm)) - The field describe information.
- `recordIndex` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - The index number (starting from 0) of the record being created.

**Returns:** [Date](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_date.htm) - The default Date value.

**Since:** 1.0

**Example:**

```apex
Date result = instance.getDateDefaultValue(Account.Name.getDescribe(), 10);
```

### getDateTimeDefaultValue

```apex
global virtual Datetime getDateTimeDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
```

Provides the default value for a Datetime field type.

**Parameters:**

- `fieldDescribe` ([DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm)) - The field describe information.
- `recordIndex` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - The index number (starting from 0) of the record being created.

**Returns:** [Datetime](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm) - The default Datetime value.

**Since:** 1.0

**Example:**

```apex
Datetime result = instance.getDateTimeDefaultValue(Account.Name.getDescribe(), 10);
```

### getDecimalDefaultValue

```apex
global virtual Decimal getDecimalDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
```

Provides the default value for a Decimal field type.

**Parameters:**

- `fieldDescribe` ([DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm)) - The field describe information.
- `recordIndex` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - The index number (starting from 0) of the record being created.

**Returns:** [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) - The default Decimal value.

**Since:** 1.0

**Example:**

```apex
Decimal result = instance.getDecimalDefaultValue(Account.Name.getDescribe(), 10);
```

### getDefaultValue

```apex
global virtual Object getDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
```

Generates a default value for a given field of an SObject.
Can be overridden by descendant classes.

**Parameters:**

- `fieldDescribe` ([DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm)) - The field describe information.
- `recordIndex` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - The index number (starting from 0) of the record being created.

**Returns:** [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) - The generated field default value.

**Since:** 1.0

**Example:**

```apex
Object result = instance.getDefaultValue(Account.Name.getDescribe(), 10);
```

### getEmailDefaultValue

```apex
global virtual String getEmailDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
```

Provides the default value for an Email field type.

**Parameters:**

- `fieldDescribe` ([DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm)) - The field describe information.
- `recordIndex` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - The index number (starting from 0) of the record being created.

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - The default String value for an email.

**Since:** 1.0

**Example:**

```apex
String result = instance.getEmailDefaultValue(Account.Name.getDescribe(), 10);
```

### getGeolocationDefaultValue

```apex
global virtual Location getGeolocationDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
```

Provides the default value for a Geolocation field type.

**Parameters:**

- `fieldDescribe` ([DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm)) - The field describe information.
- `recordIndex` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - The index number (starting from 0) of the record being created.

**Returns:** [Location](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_system_Location.htm) - The default Location value.

**Since:** 1.0

**Example:**

```apex
Location result = instance.getGeolocationDefaultValue(Account.Name.getDescribe(), 10);
```

### getMultiPicklistDefaultValue

```apex
global virtual String getMultiPicklistDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
```

Provides the default value for a Multipicklist field type.

**Parameters:**

- `fieldDescribe` ([DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm)) - The field describe information.
- `recordIndex` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - The index number (starting from 0) of the record being created.

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - The default String value for a multipicklist.

**Since:** 1.0

**Example:**

```apex
String result = instance.getMultiPicklistDefaultValue(Account.Name.getDescribe(), 10);
```

### getPercentDefaultValue

```apex
global virtual Decimal getPercentDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
```

Provides the default value for a Percent field type.

**Parameters:**

- `fieldDescribe` ([DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm)) - The field describe information.
- `recordIndex` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - The index number (starting from 0) of the record being created.

**Returns:** [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) - The default Decimal value.

**Since:** 1.0

**Example:**

```apex
Decimal result = instance.getPercentDefaultValue(Account.Name.getDescribe(), 10);
```

### getPhoneDefaultValue

```apex
global virtual String getPhoneDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
```

Provides the default value for a Phone field type.

**Parameters:**

- `fieldDescribe` ([DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm)) - The field describe information.
- `recordIndex` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - The index number (starting from 0) of the record being created.

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - The default String value for a phone number.

**Since:** 1.0

**Example:**

```apex
String result = instance.getPhoneDefaultValue(Account.Name.getDescribe(), 10);
```

### getPicklistDefaultValue

```apex
global virtual String getPicklistDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
```

Provides the default value for a Picklist field type.

**Parameters:**

- `fieldDescribe` ([DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm)) - The field describe information.
- `recordIndex` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - The index number (starting from 0) of the record being created.

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - The default String value for a picklist.

**Since:** 1.0

**Example:**

```apex
String result = instance.getPicklistDefaultValue(Account.Name.getDescribe(), 10);
```

### getTextAreaDefaultValue

```apex
global virtual String getTextAreaDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
```

Provides the default value for a TextArea field type.

**Parameters:**

- `fieldDescribe` ([DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm)) - The field describe information.
- `recordIndex` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - The index number (starting from 0) of the record being created.

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - The default String value.

**Since:** 1.0

**Example:**

```apex
String result = instance.getTextAreaDefaultValue(Account.Name.getDescribe(), 10);
```

### getTextDefaultValue

```apex
global virtual String getTextDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
```

Provides the default value for a Text field type.

**Parameters:**

- `fieldDescribe` ([DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm)) - The field describe information.
- `recordIndex` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - The index number (starting from 0) of the record being created.

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - The default String value.

**Since:** 1.0

**Example:**

```apex
String result = instance.getTextDefaultValue(Account.Name.getDescribe(), 10);
```

### getURLDefaultValue

```apex
global virtual String getURLDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
```

Provides the default value for a URL field type.

**Parameters:**

- `fieldDescribe` ([DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm)) - The field describe information.
- `recordIndex` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - The index number (starting from 0) of the record being created.

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - The default String value for a URL.

**Since:** 1.0

**Example:**

```apex
String result = instance.getURLDefaultValue(Account.Name.getDescribe(), 10);
```

