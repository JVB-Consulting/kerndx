---
title: "UTIL_CircuitBreaker.State"
type: class
pageClass: reference
description: "Enum representing the circuit breaker state"
since: "1.0"
category: apex
---

# UTIL_CircuitBreaker.State

**Class**

```apex
global enum UTIL_CircuitBreaker.State
```

Enum representing the circuit breaker state

**Since:** 1.0

---

## Values

| Value | Description |
|----------|-------------|
| global  [CLOSED](#closed) | Normal operation - requests pass through |
| global  [HALF_OPEN](#half_open) | Testing recovery - limited requests allowed to test if service recovered |
| global  [OPEN](#open) | Circuit is open - requests fail fast without attempting call |

---

## Value Details

### CLOSED

```apex
global CLOSED
```

Normal operation - requests pass through

### HALF_OPEN

```apex
global HALF_OPEN
```

Testing recovery - limited requests allowed to test if service recovered

### OPEN

```apex
global OPEN
```

Circuit is open - requests fail fast without attempting call

