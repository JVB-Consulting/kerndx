---
title: "UTIL_CircuitBreaker.Provider"
type: class
pageClass: reference
description: "Interface for code that needs circuit breaker protection (with return value) Implement this interface when your action needs to return data. Use ProtectedAction if no return value is needed."
since: "1.0"
category: apex
---

# UTIL_CircuitBreaker.Provider

**Class**

```apex
global interface UTIL_CircuitBreaker.Provider
```

Interface for code that needs circuit breaker protection (with return value) Implement this interface when your action needs to return data. Use ProtectedAction if no return value is needed.

**Since:** 1.0

**Example:**

```apex
public class GetCustomerDataProvider implements UTIL_CircuitBreaker.Provider
{
    private Id customerId;
    public GetCustomerDataProvider(Id customerId)
    {
        customerId = customerId;
    }
    public Object execute()
    {
        // Make API call and return response
        HttpResponse response = makeApiCall();
        return JSON.deserialize(response.getBody(), DTO_CustomerResponse.class);
    }
}
// Usage
UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor('API_GetCustomerData');
DTO_CustomerResponse customer = (DTO_CustomerResponse)breaker.execute(new GetCustomerDataProvider(customerId));
```

---

## Methods

| Method | Description |
|--------|-------------|
| global abstract [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) [execute](#execute)() | The code to execute with circuit breaker protection |

---

## Method Details

### execute

<div class="apex-member">

```apex
global abstract Object execute()
```

The code to execute with circuit breaker protection

**Returns** [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) — The result of the operation (caller must cast to appropriate type)

</div>

