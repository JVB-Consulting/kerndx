---
title: "UTIL_HttpClient.FailureAction"
type: class
description: "Defines the action to take when an HTTP call fails."
since: "1.0"
category: apex
---

# UTIL_HttpClient.FailureAction

**Class**

```apex
global enum UTIL_HttpClient.FailureAction
```

Defines the action to take when an HTTP call fails.

**Since:** 1.0

**Example:**

```apex
UTIL_HttpClient.post('MyService', '/send')
   .onFailure(UTIL_HttpClient.FailureAction.LOG_FAILURE)
   .send();
```

---

## Values

| Value | Description |
|----------|-------------|
| global  [LOG_FAILURE](#log_failure) | Log an ApiIssue__c record without retrying. |
| global  [RETRY_THEN_LOG](#retry_then_log) | Retry the request, then log a failure record if all retries are exhausted. |

---

## Value Details

### LOG_FAILURE

```apex
global LOG_FAILURE
```

Log an ApiIssue__c record without retrying.

Caveat — delegation mode: the underlying KEY_SKIP_RETRY flag that distinguishes
LOG_FAILURE from RETRY_THEN_LOG is consumed only by DefaultOutboundHandler.sendRequest's
synchronous retry loop. When the request is delegated to a subscriber-supplied handler
via useHandler(HandlerClass.class), the subscriber handler decides its own retry
behaviour and the LOG_FAILURE / RETRY_THEN_LOG distinction is observationally
identical from the framework's side. Subscribers shipping their own handlers should
read the KEY_SKIP_RETRY parameter from the inbound DTO_NameValues if they want to
honour the caller's "don't retry" intent.

### RETRY_THEN_LOG

```apex
global RETRY_THEN_LOG
```

Retry the request, then log a failure record if all retries are exhausted.

In delegation mode (subscriber-supplied handler via useHandler), retry behaviour is
the subscriber handler's responsibility — see LOG_FAILURE for the contract caveat.

