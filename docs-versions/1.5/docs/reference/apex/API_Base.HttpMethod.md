---
title: "API_Base.HttpMethod"
type: class
pageClass: reference
description: "HTTP method verbs for web service calls."
since: "1.0"
category: apex
---

# API_Base.HttpMethod

**Class**

<div class="apex-member apex-class">

```apex
global enum API_Base.HttpMethod
```

HTTP method verbs for web service calls.

**Example**

```apex
API_Base.HttpMethod method = API_Base.HttpMethod.POST;
```

</div>

---

## Inner Classes

| Class | Description |
|-------|-------------|
| [DELETION](#deletion) | HTTP DELETE method for removing resources (named DELETION to avoid reserved word). |
| [GET](#get) | HTTP GET method for retrieving resources. |
| [PATCH](#patch) | HTTP PATCH method for partial updates. |
| [POST](#post) | HTTP POST method for creating resources. |
| [PUT](#put) | HTTP PUT method for updating resources. |

---

## Value Details

### DELETION

```apex
global DELETION
```

HTTP DELETE method for removing resources (named DELETION to avoid reserved word).

### GET

```apex
global GET
```

HTTP GET method for retrieving resources.

### PATCH

```apex
global PATCH
```

HTTP PATCH method for partial updates.

### POST

```apex
global POST
```

HTTP POST method for creating resources.

### PUT

```apex
global PUT
```

HTTP PUT method for updating resources.

