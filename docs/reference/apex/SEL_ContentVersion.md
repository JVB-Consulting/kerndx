---
title: "SEL_ContentVersion"
type: class
pageClass: reference
description: "Selector for the ContentVersion object. Provides query methods for retrieving content versions by publishing location, content document, and workspace folders."
author: "Jason Van Beukering"
group: "Selectors"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# SEL_ContentVersion

**Class** · Group: `Selectors`

<div class="apex-member apex-class">

```apex
global inherited sharing class SEL_ContentVersion extends SEL_Base
```

**Extends:** [SEL_Base](SEL_Base.md)

Selector for the ContentVersion object. Provides query methods for retrieving content versions by publishing location, content document, and workspace folders.

**Example**

```apex
List<ContentVersion> versions = new SEL_ContentVersion().findByFirstPublishLocationId(recordId);
List<ContentVersion> latest = new SEL_ContentVersion().findLatestByContentDocumentId(documentIds);
ContentVersion version = (ContentVersion)new SEL_ContentVersion().findById(versionId);
```

**See Also:** [SEL_Base](SEL_Base.md)

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[ContentVersion](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_contentversion.htm)> [findByFirstPublishLocationId](#findbyfirstpublishlocationid)([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) firstPublishLocationId) | Retrieves the latest ContentVersion records linked to the specified FirstPublishLocationId. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[ContentVersion](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_contentversion.htm)> [findByFirstPublishLocationId](#findbyfirstpublishlocationid)([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)> firstPublishLocationIds) | Retrieves the latest ContentVersion records linked to the specified FirstPublishLocationId values. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[ContentVersion](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_contentversion.htm)> [findLatestByContentDocumentId](#findlatestbycontentdocumentid)([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)> contentDocumentIds) | Retrieves the latest ContentVersion records for the specified ContentDocument IDs. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[ContentVersion](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_contentversion.htm)> [getAll](#getall)() | Retrieves all ContentVersion records in the system. |
| global override [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)> [getFields](#getfields)() | Returns the default fields for ContentVersion queries. |
| global  [SEL_ContentVersion](#sel_contentversion)() | Constructs a new SEL_ContentVersion selector instance. |

---

## Method Details

### SEL_ContentVersion

<div class="apex-member">

```apex
global SEL_ContentVersion()
```

Constructs a new SEL_ContentVersion selector instance.

**Example**

```apex
SEL_ContentVersion instance = new SEL_ContentVersion();
```

</div>

### findByFirstPublishLocationId

<div class="apex-member">

```apex
global List<ContentVersion> findByFirstPublishLocationId(Id firstPublishLocationId)
```

Retrieves the latest ContentVersion records linked to the specified FirstPublishLocationId.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `firstPublishLocationId` | [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) | The ID of the location where the content version was first published. |

**Returns** [ContentVersion](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_contentversion.htm) — List of the latest ContentVersion records associated with the specified location.

**Example**

```apex
List<ContentVersion> result = instance.findByFirstPublishLocationId(recordId);
```

</div>

<div class="apex-member">

```apex
global List<ContentVersion> findByFirstPublishLocationId(Set<Id> firstPublishLocationIds)
```

Retrieves the latest ContentVersion records linked to the specified FirstPublishLocationId values.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `firstPublishLocationIds` | [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) | Set of IDs for the locations where the content versions were first published. |

**Returns** [ContentVersion](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_contentversion.htm) — List of ContentVersion records found for the specified locations.

**Example**

```apex
List<ContentVersion> result = instance.findByFirstPublishLocationId(recordIds);
```

</div>

### findLatestByContentDocumentId

<div class="apex-member">

```apex
global List<ContentVersion> findLatestByContentDocumentId(Set<Id> contentDocumentIds)
```

Retrieves the latest ContentVersion records for the specified ContentDocument IDs.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `contentDocumentIds` | [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) | Set of Content Document IDs for which to retrieve the latest content versions. |

**Returns** [ContentVersion](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_contentversion.htm) — A list of the latest ContentVersion records corresponding to each provided ContentDocument ID.

**Example**

```apex
List<ContentVersion> result = instance.findLatestByContentDocumentId(recordIds);
```

</div>

### getAll

<div class="apex-member">

```apex
global List<ContentVersion> getAll()
```

Retrieves all ContentVersion records in the system.
This method only returns data when called during a test context.

**Returns** [ContentVersion](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_contentversion.htm) — A list of all ContentVersion records if in a test context; otherwise, returns an empty list.

**Example**

```apex
List<ContentVersion> allVersions = new SEL_ContentVersion().getAll();
```

</div>

### getFields

<div class="apex-member">

```apex
global override List<SObjectField> getFields()
```

Returns the default fields for ContentVersion queries.

**Returns** [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) — List of SObjectField tokens to include in queries.

**Example**

```apex
List<SObjectField> result = instance.getFields();
```

</div>

