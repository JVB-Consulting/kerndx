---
title: "UTIL_CircuitBreaker.ProtectedAction"
type: class
description: "Interface for code that needs circuit breaker protection (no return value) Implement this interface to use the simplified execute() method which handles allowRequest(), recordSuccess(), and recordFail"
since: "1.0"
category: apex
---

# UTIL_CircuitBreaker.ProtectedAction

**Class**

```apex
global interface UTIL_CircuitBreaker.ProtectedAction
```

Interface for code that needs circuit breaker protection (no return value) Implement this interface to use the simplified execute() method which handles allowRequest(), recordSuccess(), and recordFailure() automatically. Use Provider if your action needs to return a value.

**Since:** 1.0

**Example:**

```apex
public class SendEmailAction implements UTIL_CircuitBreaker.ProtectedAction
{
    private String emailAddress;
    public SendEmailAction(String emailAddress)
    {
        emailAddress = emailAddress;
    }
    public void execute()
    {
        // Protected code that may fail
        Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ buildEmail() });
    }
}
// Usage
UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor('EmailService');
breaker.execute(new SendEmailAction('user@example.com'));
```

---

## Methods

| Method | Description |
|--------|-------------|
| global abstract void [execute](#execute)() | The code to execute with circuit breaker protection |

---

## Method Details

### execute

```apex
global abstract void execute()
```

The code to execute with circuit breaker protection

