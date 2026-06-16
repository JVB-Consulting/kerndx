---
title: "API_Base.WebserviceStatus"
type: class
pageClass: reference
description: "Enum representing the status of a web service call."
since: "1.0"
category: apex
---

# API_Base.WebserviceStatus

**Class**

<div class="apex-member apex-class">

```apex
global enum API_Base.WebserviceStatus
```

Enum representing the status of a web service call.

**Example**

```apex
API_Base.WebserviceStatus status = API_Base.WebserviceStatus.COMPLETED;
```

</div>

---

## Values

| Value | Description |
|----------|-------------|
| global  [ABORTED](#aborted) | The web service call was aborted before execution. |
| global  [COMPLETED](#completed) | The web service call completed successfully. |
| global  [FAILED](#failed) | The web service call failed with an error. |

---

## Value Details

### ABORTED

```apex
global ABORTED
```

The web service call was aborted before execution.

### COMPLETED

```apex
global COMPLETED
```

The web service call completed successfully.

### FAILED

```apex
global FAILED
```

The web service call failed with an error.

