# eslint-plugin-kerndx

ESLint behavioral rules for KernDX LWC components.

**Scope: behavioral rules only.** This plugin enforces KernDX framework conventions (use `ComponentBuilder`, no `console.log`, naming, test quality). It ships **zero formatting
opinions** — no rules about braces, tabs, line length, quotes, semicolons, or arrow-vs-function style. Plug into your ESLint config alongside Prettier, eslint-config-airbnb,
eslint-config-standard, or any style guide without conflict.

## Rules

| Rule                                                                    | What It Blocks                                                                | Use Instead                                                                        |
|-------------------------------------------------------------------------|-------------------------------------------------------------------------------|------------------------------------------------------------------------------------|
| `kerndx/use-component-builder`                                          | `extends LightningElement`                                                    | `extends ComponentBuilder(...)`                                                    |
| `kerndx/no-console-log`                                                 | `console.log()`, `window.console.*`                                           | `this.consoleLog()`, `this.consoleError()`                                         |
| `kerndx/enforce-component-naming` (configurable, no-op without options) | LWC folder names not matching configured `<domain>[<brand>]<Feature>` pattern | Configured naming or `// eslint-disable-next-line kerndx/enforce-component-naming` |
| `kerndx/no-jest-theatre`                                                | Assertion-less Jest tests                                                     | Query the rendered DOM and assert visible outcomes                                 |
| `kerndx/no-mutating-shared-fixture`                                     | `beforeAll` createElement with mutating `it` blocks                           | Fresh element per test                                                             |
| `kerndx/no-jest-mock-component-module`                                  | `jest.mock(...)` of a `c/` or `lightning/` module in Jest tests               | `jest.spyOn` on the real import, the stub's received values, `moduleNameMapper`    |
| `kerndx/no-coverage-exempt-without-reason`                              | `// kern-coverage-exempt:` with empty/short reason                            | Document a concrete, testable reason ≥15 chars                                     |
| `kerndx/no-hardcoded-user-text`                                         | Hardcoded text in toasts, thrown errors and multi-word display strings        | A Custom Label (`import x from '@salesforce/label/c.X'`)                           |

## Setup

```javascript
// eslint.config.mjs
import kerndx from 'eslint-plugin-kerndx';

export default [
	{
		plugins: { kerndx },
		rules: {
			'kerndx/use-component-builder': 'error',
			'kerndx/no-console-log': 'error',
			'kerndx/no-jest-theatre': 'error',
			'kerndx/no-mutating-shared-fixture': 'error',
			// Starts as a warning: your existing tests may mock c/ or lightning/ modules this way.
			// Fix those tests, then raise it to 'error' if you want it to fail the run.
			'kerndx/no-jest-mock-component-module': 'warn',
			'kerndx/no-coverage-exempt-without-reason': 'error',
			// Configure naming for your subscriber's domain/brand vocabulary.
			// Omit this rule entirely (or pass no options) for no enforcement.
			'kerndx/enforce-component-naming': ['error', {
				domains: ['sls', 'svc', 'cmn'],      // required, lowercase
				brands: ['Acme', 'Beta'],            // optional, PascalCase
				maxLength: 40                        // optional, default 40
			}]
		}
	}
];
```

### `kerndx/enforce-component-naming` options

| Option      | Type                    | Required | Default | Description                                                                                |
|-------------|-------------------------|----------|---------|--------------------------------------------------------------------------------------------|
| `domains`   | `string[]` (lowercase)  | **yes**  | —       | Allowed domain prefixes. Must be lowercase, 1+ entry. Rule is a no-op if missing or empty. |
| `brands`    | `string[]` (PascalCase) | no       | `[]`    | Optional brand segment between domain and feature. If present, must start uppercase.       |
| `maxLength` | `integer`               | no       | `40`    | Max component-name length in characters.                                                   |

The compiled pattern is `^(<domain>|...)(?:<brand>|...)?[A-Z][a-zA-Z0-9]*$`. Example: with `domains: ['ord']` + `brands: ['Acme']`, `ordReturnWizard` and `ordAcmeCheckoutForm` are
valid; `returnWizard` and `OrderReturnWizard` are not.

`__tests__/` and non-LWC files are always skipped.

### Why `kerndx/no-jest-mock-component-module` exists

Only the sfdx-lwc-jest resolver knows where `c/` and `lightning/` modules live. When an earlier test file in the same Jest worker loads the real
module, Jest finds it under a different name, and your `jest.mock(...)` no longer replaces it. Often nothing fails: the test keeps passing, but it now
checks a fake that your component never calls. Sometimes it fails only when the test files run in a certain order. Adding `{virtual: true}` does not fix this. Use `jest.spyOn(...)` on the real object you import,
assert what the sfdx-lwc-jest stub received, or point the module at a mock file with a `moduleNameMapper` entry in your Jest configuration.
Relative paths, npm packages and `@salesforce/...` modules mock normally, so the rule does not report them.

Turn this rule on at the `warn` level first. Your existing tests may use this pattern, and a warning flags them without failing the lint run.
Fix those tests, then raise the rule to `error` if you want it to fail the run.

## License

MIT — see `LICENSE` in this directory for the full text.
The top-level `LICENSE` is Apache-2.0 and does not apply to this directory, which stays MIT.
