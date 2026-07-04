---
title: "IF_Search"
type: class
description: "Generic Interface for searches"
author: "Jason Van Beukering"
group: "Selectors"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# IF_Search

**Class** · Group: `Selectors`

```apex
global interface IF_Search
```

Generic Interface for searches

**Since:** 1.0

**Example:**

```apex
public class AccountSearch implements IF_Search
{
    public Object search(Object searchTerm, Map<String, Object> searchParameters)
    {
        return new SEL_Accounts().findByField(Account.Name, (String)searchTerm);
    }
}
```

---

## Methods

| Method | Description |
|--------|-------------|
| global abstract [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) [search](#search)([Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) searchTerm, [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> searchParameters) | Search function to be implemented |

---

## Method Details

### search

```apex
global abstract Object search(Object searchTerm, Map<String, Object> searchParameters)
```

Search function to be implemented

**Parameters:**

- `searchTerm` ([Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)) - Search Term to be used for search/query
- `searchParameters` ([Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)) - Map of search parameters - individual implementations can expect differing parameters.

**Returns:** [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) - Response object. Individual implementations can cast to different structures as needed.

**Since:** 1.0

