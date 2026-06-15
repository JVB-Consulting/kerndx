# Masking Advisor Bundle Fixtures (Section 76)

Deployable CustomMetadata bundles in the **exact shape the Data Masking Advisor's
Export modal generates on a subscriber org** (`CTRL_MaskingAdvisor.generateConfiguration`
→ `targetXml`/`customMetadata`/`packageXml` templates): namespaced type stem
(`kern__MaskingTarget`), namespaced field names, `xsi:nil` for the blank caller-class and
field (object-wide scope), namespace-qualified rule developer names in the `kern__Rule__c`
MetadataRelationship value (e.g. `kern__MaskCreditCard` — a bare name resolves to no such
record on a managed subscriber deploy), and a `package.xml` pinned to API 67.0.

Section 76 (`run-phase2.js` → `runSection76()`) deploys these with the same
project-free Metadata API push the Export modal's deploy command prescribes,
then re-reads `kern__MaskingTarget__mdt` and asserts the org's masking posture
recomputes — the scripted round-trip of the advisor's configure → deploy → verify flow.

| Bundle      | Records                                                                                                                                                                   | Posture after deploy                                                                       |
|-------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------|
| `create/`   | `Case_All_Card_Probe` (active, MaskCreditCard) + `Case_All_Email_DeadProbe` (active, dormant MaskEmail → dead config) + `MaskPhoneUS` **rule activation** (IsActive=true) | 5 masked objects, 14 object-wide targets, 1 dead config → Health Check input flips to Warn |
| `disable/`  | both probes `IsActive__c=false` + `MaskPhoneUS` rule deactivation (IsActive=false)                                                                                        | 4 masked objects, 12 object-wide targets, 0 dead → Pass(4)                                 |
| `reenable/` | `Case_All_Card_Probe` active again (dead probe + MaskPhoneUS untouched)                                                                                                   | 5 masked objects, 13 object-wide targets, 0 dead → Pass(5)                                 |

### Rule-activation leg (`kern__MaskingRule.kern__MaskPhoneUS`)

Alongside the target records, the `create`/`disable` bundles carry a **rule-activation override** —
the second artifact kind the advisor's Export modal emits. The advisor activates a dormant *packaged*
rule by writing a `MaskingRule` CustomMetadata file named for the rule's **namespace-qualified record
name** (`kern__MaskingRule.kern__MaskPhoneUS`, label + `IsActive__c` only). The qualified record name is
load-bearing: a bare `kern__MaskingRule.MaskPhoneUS` either fails to deploy ("you must enter a Pattern")
or mints a new subscriber-owned rule instead of flipping the shipped one. Section 76b/c/d verify this
round-trip (76j activates → still one package-owned rule; 76k/76h dormant again). Activating a rule that
no target binds masks nothing, so the posture counts above are unaffected by it.

> **Harness caveat:** the advisor only ever *generates* activations. The `MaskPhoneUS` deactivation in
> the `disable` bundle (`IsActive=false`) is a harness-only artifact — it exists solely so the round-trip
> can restore the shipped dormant state and keep re-runs idempotent. The `reenable` bundle deliberately
> omits the rule, which proves a bundle deploy upserts exactly the records it carries and nothing else.

The runner re-deploys `disable/` as cleanup, so re-runs are idempotent: the probe
records persist (CustomMetadata deploys cannot delete) but stay inactive, which the
section-76 baseline script asserts before each run.

Case is the probe object deliberately: it ships with no masking targets (so the
distinct-object count moves 4↔5) and no Kern trigger configuration (so an active
probe target never changes runtime masking behaviour for other sections).
