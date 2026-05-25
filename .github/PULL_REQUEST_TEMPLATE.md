## Summary

<!-- One sentence describing what this PR does and why. -->

## Type of change

- [ ] Bug fix (non-breaking change which fixes a defect)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (existing functionality changes; subscribers must migrate)
- [ ] Documentation only

## Related issue(s)

<!-- e.g. Closes #123 -->

## Test plan

<!-- How was this verified? Include the test classes added/modified, anonymous Apex run, manual click-through, etc. -->

- [ ] New / updated unit tests
- [ ] All existing tests pass (`sf apex run test --test-level RunLocalTests`)
- [ ] Manual verification in a scratch org
- [ ] Documentation updated (if behaviour changed)

## Checklist

- [ ] My code follows the [code conventions](../docs/Code%20Conventions%20-%20Guide.md) — Allman bracing, declared sharing, no inline SOQL, no `System.debug`, no `LightningElement` direct use, no hardcoded namespaces.
- [ ] I have added ApexDoc on any new Apex method and JSDoc on any new JS function.
- [ ] I have not introduced any `TODO` / `FIXME` / `XXX` / `HACK` comments.
- [ ] Any `global` member I added is genuinely needed by subscriber Apex (not just used internally).

---

> ⚠️ **Note on PRs in v1.0:** External PRs are not accepted at this stage of the project — see [`CONTRIBUTING.md`](../CONTRIBUTING.md). If you've opened this PR without a green-light on an associated issue, please [open an issue](../../issues/new/choose) describing the change first. The maintainer reviews each issue and either implements the fix directly or asks you to convert it into a PR.
