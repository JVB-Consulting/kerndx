---
title: "QRY_Builder.Scope"
type: class
pageClass: reference
description: "Enumeration of valid SOQL scope values for use with the USING SCOPE clause."
since: "1.0"
category: apex
---

# QRY_Builder.Scope

**Class**

<div class="apex-member apex-class">

```apex
global enum QRY_Builder.Scope
```

Enumeration of valid SOQL scope values for use with the USING SCOPE clause.

**Example**

```apex
List<Account> myAccounts = QRY_Builder.selectFrom(Account.SObjectType)
    .usingScope(QRY_Builder.Scope.MINE)
    .toList();
```

</div>

---

## Inner Classes

| Class | Description |
|-------|-------------|
| [DELEGATED](#delegated) | Records delegated to another user. |
| [EVERYTHING](#everything) | All records the user has access to. |
| [MINE](#mine) | Records owned by the current user. |
| [MY_TEAM_TERRITORY](#my_team_territory) | Records in the current user's team territory. |
| [MY_TERRITORY](#my_territory) | Records in the current user's territory. |
| [TEAM](#team) | Records owned by the current user's team. |

---

## Value Details

### DELEGATED

```apex
global DELEGATED
```

Records delegated to another user.

### EVERYTHING

```apex
global EVERYTHING
```

All records the user has access to.

### MINE

```apex
global MINE
```

Records owned by the current user.

### MY_TEAM_TERRITORY

```apex
global MY_TEAM_TERRITORY
```

Records in the current user's team territory.

### MY_TERRITORY

```apex
global MY_TERRITORY
```

Records in the current user's territory.

### TEAM

```apex
global TEAM
```

Records owned by the current user's team.

