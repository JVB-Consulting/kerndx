---
title: "LoginFrequency__c"
type: sobject
pageClass: reference
description: "Tracks monthly login activity per user, including total login count and number of unique days logged in. Used for login adoption reporting."
category: objects
---

# LoginFrequency__c

**Sobject**

<div class="apex-member apex-class">

```apex
global class LoginFrequency__c extends SObject
```

**Extends:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)

Tracks monthly login activity per user, including total login count and number of unique days logged in. Used for login adoption reporting.

</div>

---

## Fields

| Field | Description |
|-------|-------------|
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [CompositeKey__c](#compositekey__c) | Composite unique key combining User ID, year, and month to ensure one record per user per month. |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [LoginMonth__c](#loginmonth__c) | The calendar month (1-12) for this login frequency record. |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [LoginYear__c](#loginyear__c) | The calendar year for this login frequency record. |
| global [Date](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_date.htm) [ReportingDate__c](#reportingdate__c) | Formula-generated date set to the first day of the login month/year, enabling relative date filtering in reports (e.g. |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [TotalLoginCount__c](#totallogincount__c) | Total number of login events for this user in the given month. |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [UniqueLoginCount__c](#uniquelogincount__c) | Number of distinct days the user logged in during the given month. |
| global [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [User__c](#user__c) | The user whose login activity is tracked by this record. |
| global [User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm) [User__r](#user__r) | The user whose login activity is tracked by this record. |

### CompositeKey__c

```apex
global String CompositeKey__c
```

Composite unique key combining User ID, year, and month to ensure one record per user per month.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(40), case-insensitive |
| Required | false |
| Unique | true |
| External ID | true |

### LoginMonth__c

```apex
global Decimal LoginMonth__c
```

The calendar month (1-12) for this login frequency record.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Number(4,0) |
| Required | false |
| Unique | false |
| External ID | false |

### LoginYear__c

```apex
global Decimal LoginYear__c
```

The calendar year for this login frequency record.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Number(4,0) |
| Required | false |
| Unique | false |
| External ID | false |

### ReportingDate__c

```apex
global Date ReportingDate__c
```

Formula-generated date set to the first day of the login month/year, enabling relative date filtering in reports (e.g. THIS_YEAR, LAST_N_MONTHS).

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Date |
| Required | false |
| Formula | `DATEVALUE(TEXT(LoginYear__c) & '-' & TEXT(LoginMonth__c) & '-' & '01')` |

### TotalLoginCount__c

```apex
global Decimal TotalLoginCount__c
```

Total number of login events for this user in the given month. Includes all login types (UI, API, etc.).

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Number(10,0) |
| Required | false |
| Unique | false |
| External ID | false |

### UniqueLoginCount__c

```apex
global Decimal UniqueLoginCount__c
```

Number of distinct days the user logged in during the given month. A user who logs in 5 times on the same day counts as 1 unique day.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Number(4,0) |
| Required | false |
| Unique | false |
| External ID | false |

### User__c

```apex
global Id User__c
```

The user whose login activity is tracked by this record.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | User |
| Required | false |

### User__r

```apex
global User User__r
```

The user whose login activity is tracked by this record.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | User |
| Required | false |

