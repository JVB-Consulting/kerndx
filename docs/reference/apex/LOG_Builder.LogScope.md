---
title: "LOG_Builder.LogScope"
type: class
pageClass: reference
description: "A logging scope that buffers log entries until closed. On creation, suspends immediate log publishing. On close, flushes all buffered logs and resumes publishing. Provides a simpler alternative to man"
since: "1.0"
category: apex
---

# LOG_Builder.LogScope

**Class**

```apex
global class LOG_Builder.LogScope
```

A logging scope that buffers log entries until closed. On creation, suspends immediate log publishing. On close, flushes all buffered logs and resumes publishing. Provides a simpler alternative to manual suspendSaving/flushBuffer/resumeSaving patterns.

**Since:** 1.0

**Example:**

```apex
LOG_Builder.LogScope scope = LOG_Builder.scope();
LOG_Builder.build().debug('Step 1').at('BatchJob.execute').emit();
LOG_Builder.build().debug('Step 2').at('BatchJob.execute').emit();
scope.close();
```

---

## Methods

| Method | Description |
|--------|-------------|
| global void [close](#close)() | Flushes all buffered logs and resumes publishing. |

---

## Method Details

### close

<div class="apex-member">

```apex
global void close()
```

Flushes all buffered logs and resumes publishing. Safe to call multiple times;
subsequent calls after the first are no-ops.

</div>

