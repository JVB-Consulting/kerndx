---
title: "UTIL_Exceptions.RequestRefusedException"
type: class
pageClass: reference
description: "Throw this from parseResponse() when the external system answered with a success status but its body says it refused the request, for example an order answered 200 with status REJECTED. It is a Perman"
group: "Web Services"
since: "1.8"
category: apex
---

# UTIL_Exceptions.RequestRefusedException

**Class** · Group: `Web Services`

<div class="apex-member apex-class">

```apex
global inherited sharing class UTIL_Exceptions.RequestRefusedException extends UTIL_Exceptions.PermanentFailureException
```

**Extends:** [UTIL_Exceptions.PermanentFailureException](UTIL_Exceptions.PermanentFailureException.md)

Throw this from parseResponse() when the external system answered with a success status but its body says it refused the request, for example an order answered 200 with status REJECTED. It is a PermanentFailureException, so the call ends Failed at once, with one issue and no retry scheduled. A refusal means the external system did not act, so the issue's External System May Have Acted box stays clear and the issue can be run again from the API Issues list once the cause is fixed. Thrown from anywhere else, onSuccess() included, it behaves exactly as PermanentFailureException does, and an issue for a failure after a success status then says the external system acted, because by then it did.

**Example**

```apex
global override void parseResponse()
{
    super.parseResponse();
    if(((DTO_Response)responsePayload).status == 'REJECTED')
    {
        throw new UTIL_Exceptions.RequestRefusedException('The external system rejected the order; fix the order and run the call again.');
    }
}
```

**See Also:** [API_Outbound](API_Outbound.md)

</div>

---

