---
title: "FLOW_RetryApiIssues.DTO_Request"
type: class
pageClass: reference
description: "What the action is asked: the API issues to run again."
since: "1.8"
category: apex
---

# FLOW_RetryApiIssues.DTO_Request

**Class**

<div class="apex-member apex-class">

```apex
global inherited sharing class FLOW_RetryApiIssues.DTO_Request
```

What the action is asked: the API issues to run again.

</div>

---

## Fields

| Field | Description |
|-------|-------------|
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> [apiIssueIds](#apiissueids) | The ids of the API issues to run again. |

### apiIssueIds

```apex
@InvocableVariable(required=true description='The ids of the API issues to run again.' label='API Issue Ids') global List<String> apiIssueIds
```

**Type:** [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)

The ids of the API issues to run again.

