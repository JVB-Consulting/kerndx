# eslint-plugin-kerndx

ESLint behavioral rules for KernDX LWC components.

**Scope: behavioral rules only.** This plugin enforces KernDX framework conventions (use `ComponentBuilder`, no `console.log`, naming, test quality). It ships **zero formatting opinions** — no rules about braces, tabs, line length, quotes, semicolons, or arrow-vs-function style. Plug into your ESLint config alongside Prettier, eslint-config-airbnb, eslint-config-standard, or any style guide without conflict.

## Rules

| Rule | What It Blocks | Use Instead |
|---|---|---|
| `kerndx/use-component-builder` | `extends LightningElement` | `extends ComponentBuilder(...)` |
| `kerndx/no-console-log` | `console.log()`, `window.console.*` | `this.consoleLog()`, `this.consoleError()` |
| `kerndx/enforce-component-naming` (configurable, no-op without options) | LWC folder names not matching configured `<domain>[<brand>]<Feature>` pattern | Configured naming or `// eslint-disable-next-line kerndx/enforce-component-naming` |
| `kerndx/no-jest-theatre` | Assertion-less Jest tests | Query the rendered DOM and assert visible outcomes |
| `kerndx/no-mutating-shared-fixture` | `beforeAll` createElement with mutating `it` blocks | Fresh element per test |
| `kerndx/no-coverage-exempt-without-reason` | `// kern-coverage-exempt:` with empty/short reason | Document a concrete, testable reason ≥15 chars |

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
			'kerndx/no-coverage-exempt-without-reason': 'error',
			// Configure naming for your subscriber's domain/brand vocabulary.
			// Omit this rule entirely (or pass no options) for no enforcement.
			'kerndx/enforce-component-naming': ['warn', {
				domains: ['sls', 'svc', 'cmn'],      // required, lowercase
				brands: ['Acme', 'Beta'],            // optional, PascalCase
				maxLength: 40                        // optional, default 40
			}]
		}
	}
];
```

### `kerndx/enforce-component-naming` options

| Option | Type | Required | Default | Description |
|---|---|---|---|---|
| `domains` | `string[]` (lowercase) | **yes** | — | Allowed domain prefixes. Must be lowercase, 1+ entry. Rule is a no-op if missing or empty. |
| `brands` | `string[]` (PascalCase) | no | `[]` | Optional brand segment between domain and feature. If present, must start uppercase. |
| `maxLength` | `integer` | no | `40` | Max component-name length in characters. |

The compiled pattern is `^(<domain>|...)(?:<brand>|...)?[A-Z][a-zA-Z0-9]*$`. Example: with `domains: ['ord']` + `brands: ['Acme']`, `ordReturnWizard` and `ordAcmeCheckoutForm` are valid; `returnWizard` and `OrderReturnWizard` are not.

`__tests__/` and non-LWC files are always skipped.
