---
title: "API_CallCurrentOrg"
type: class
pageClass: reference
description: "Base API class for all handlers that call the current Org standard APIs. Uses session-ID-based authentication and resolves the org base URL dynamically via URL.getOrgDomainURL(). Subscribers must add "
author: "Jason Van Beukering"
group: "Web Services"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# API_CallCurrentOrg

**Class** · Group: `Web Services`

<div class="apex-member apex-class">

```apex
global virtual inherited sharing class API_CallCurrentOrg extends API_Outbound
```

**Extends:** [API_Outbound](API_Outbound.md)

Base API class for all handlers that call the current Org standard APIs. Uses session-ID-based authentication and resolves the org base URL dynamically via URL.getOrgDomainURL(). Subscribers must add a Remote Site Setting for their My Domain URL.

**Example**

```apex
global class API_OrgMetadata extends API_CallCurrentOrg
{
    global override void configure()
    {
        super.configure();
        requestPayload = new DTO_Request();
        responsePayload = new DTO_Response();
    }
}
```

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global virtual override void [configure](#configure)() | Initialises the handler and sets the base URL to the current org domain. |
| global virtual override [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [getAuthorisationToken](#getauthorisationtoken)() | Will return the current session Id as authorisation token. |
| global virtual override [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [getWebServiceEndPoint](#getwebserviceendpoint)() | Constructs the full endpoint URL by combining the current org domain URL with the endpoint path from ApiSetting__mdt configuration. |

---

## Method Details

### configure

<div class="apex-member">

```apex
global virtual override void configure()
```

Initialises the handler and sets the base URL to the current org domain.

**Example**

```apex
global override void configure()
{
    super.configure();
    requestPayload = new DTO_Request();
}
```

</div>

### getAuthorisationToken

<div class="apex-member">

```apex
global virtual override String getAuthorisationToken()
```

Will return the current session Id as authorisation token.

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — Authorisation Header value

**Example**

```apex
global class API_OrgMetadata extends API_CallCurrentOrg
{
    // Uses inherited getAuthorisationToken() which returns 'Bearer <sessionId>'
    // to authenticate against the current org's REST API
}
```

</div>

### getWebServiceEndPoint

<div class="apex-member">

```apex
global virtual override String getWebServiceEndPoint()
```

Constructs the full endpoint URL by combining the current org domain
URL with the endpoint path from ApiSetting__mdt configuration.

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — The full URL endpoint for the web service

**Example**

```apex
// With EndpointPath__c = '/services/data/v{0}/sobjects/StreamingChannel/{1}/push'
// Returns: 'https://myorg.my.salesforce.com/services/data/v{0}/sobjects/StreamingChannel/{1}/push'
```

</div>

