---
title: "UTIL_Exceptions.PermanentFailureException"
type: class
pageClass: reference
description: "Throw this from your own outbound handler code to say the failure is permanent: sending the same request again cannot help. The framework then ends the call Failed at once, with one issue and no retry"
group: "Web Services"
since: "1.8"
category: apex
---

# UTIL_Exceptions.PermanentFailureException

**Class** · Group: `Web Services`

<div class="apex-member apex-class">

```apex
global virtual inherited sharing class UTIL_Exceptions.PermanentFailureException
```

**Known Derived Types:** [UTIL_Exceptions.RequestRefusedException](UTIL_Exceptions.RequestRefusedException.md)

Throw this from your own outbound handler code to say the failure is permanent: sending the same request again cannot help. The framework then ends the call Failed at once, with one issue and no retry scheduled, whatever the retry settings and the handler's retry strategy say. Throw it from prepareRequest(), a request DTO's populate(), createRequest() and the methods it calls, parseResponse(), onSuccess() or createRetryStrategy(). Thrown from getValidationErrors() it ends the call Aborted instead, because a refusal in validation always does. A throw raised while the records you registered are saved reaches the framework as a DmlException, whatever you threw, and is decided like any other failure after a successful response. For a success status whose body carries a refusal, throw RequestRefusedException from parseResponse() instead: it is refused the same way, and the issue it leaves records that the external system did not act.

**Example**

```apex
global override void prepareRequest()
{
    super.prepareRequest();
    if(String.isBlank(orderNumber))
    {
        throw new UTIL_Exceptions.PermanentFailureException('The order has no number; sending it again cannot help.');
    }
}
```

**See Also:** [API_Outbound](API_Outbound.md)

</div>

---

