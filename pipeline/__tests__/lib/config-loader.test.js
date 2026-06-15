// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {loadConfig, ConfigError} = require('../../src/lib/config-loader.js');

function writeTmpConfig(content)
{
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'kerndx-cfg-'));
	const file = path.join(dir, 'config.yml');
	fs.writeFileSync(file, content);
	return {file, dir};
}

test('loadConfig accepts a minimal valid config', () =>
{
	const {file} = writeTmpConfig(`
package_dirs: [force-app/main/default]
branches:
  main: main
  ingress: [main]
  protected: [main]
ci_adapter:
  name: none
`);
	const cfg = loadConfig(file);
	assert.equal(cfg.branches.main, 'main');
	assert.equal(cfg.ci_adapter.name, 'none');
});

test('loadConfig rejects unknown top-level keys', () =>
{
	const {file} = writeTmpConfig(`
package_dirs: [force-app]
branches: { main: main, ingress: [main], protected: [main] }
ci_adapter: { name: none }
mystery_key: nope
`);
	assert.throws(() => loadConfig(file), ConfigError);
});

test('loadConfig rejects experimental adapter without experimental: true', () =>
{
	const {file} = writeTmpConfig(`
package_dirs: [force-app]
branches: { main: main, ingress: [main], protected: [main] }
ci_adapter: { name: copado }
`);
	assert.throws(() => loadConfig(file), /experimental/);
});

test('loadConfig accepts copado with experimental: true', () =>
{
	const {file} = writeTmpConfig(`
package_dirs: [force-app]
branches: { main: main, ingress: [main], protected: [main] }
ci_adapter: { name: copado, experimental: true }
`);
	const cfg = loadConfig(file);
	assert.equal(cfg.ci_adapter.name, 'copado');
	assert.equal(cfg.ci_adapter.experimental, true);
});

test('loadConfig validates custom adapter pattern length', () =>
{
	const pattern = 'x'.repeat(300);
	const {file} = writeTmpConfig(`
package_dirs: [force-app]
branches: { main: main, ingress: [main], protected: [main] }
ci_adapter:
  name: custom
  patterns:
    - match: '${pattern}'
      action: skip-scan
      label: too-long
`);
	assert.throws(() => loadConfig(file), /256/);
});

test('loadConfig rejects unsafe regex in custom adapter pattern', () =>
{
	const {file} = writeTmpConfig(`
package_dirs: [force-app]
branches: { main: main, ingress: [main], protected: [main] }
ci_adapter:
  name: custom
  patterns:
    - match: '(a+)+$'
      action: skip-scan
      label: redos
`);
	assert.throws(() => loadConfig(file), /unsafe regex|catastrophic/i);
});

test('loadConfig accepts a secret_scanning block and round-trips ignore_globs', () =>
{
	const {file} = writeTmpConfig(`
package_dirs: [force-app]
branches: { main: main, ingress: [main], protected: [main] }
ci_adapter: { name: none }
secret_scanning:
  ignore_globs: ['**/fixtures/**']
`);
	const cfg = loadConfig(file);
	// The loader validates but does not inject schema defaults (repo convention:
	// code defaults defensively). secret-scan treats an omitted `enabled` as on.
	assert.notEqual(cfg.secret_scanning.enabled, false, 'omitted enabled is not false → scanning is on');
	assert.deepEqual(cfg.secret_scanning.ignore_globs, ['**/fixtures/**']);
});

test('loadConfig rejects an unknown key inside secret_scanning is not enforced (open block)', () =>
{
	// secret_scanning has no additionalProperties:false, matching scanner/naming —
	// forward-compatible for subscriber-supplied future keys.
	const {file} = writeTmpConfig(`
package_dirs: [force-app]
branches: { main: main, ingress: [main], protected: [main] }
ci_adapter: { name: none }
secret_scanning: { enabled: true, future_key: ok }
`);
	const cfg = loadConfig(file);
	assert.equal(cfg.secret_scanning.enabled, true);
});

test('loadConfig accepts secret_scanning.enabled: false', () =>
{
	const {file} = writeTmpConfig(`
package_dirs: [force-app]
branches: { main: main, ingress: [main], protected: [main] }
ci_adapter: { name: none }
secret_scanning: { enabled: false }
`);
	const cfg = loadConfig(file);
	assert.equal(cfg.secret_scanning.enabled, false);
});

test('loadConfig rejects a branches.main with shell metacharacters; accepts a slash/dot branch', () =>
{
	const bad = writeTmpConfig(`
package_dirs: [force-app]
branches: { main: "main; rm -rf /", ingress: [main], protected: [main] }
ci_adapter: { name: none }
`);
	assert.throws(() => loadConfig(bad.file), ConfigError, 'shell metacharacters in branches.main are rejected');

	const good = writeTmpConfig(`
package_dirs: [force-app]
branches: { main: "release/1.2.x", ingress: [main], protected: [main] }
ci_adapter: { name: none }
`);
	assert.equal(loadConfig(good.file).branches.main, 'release/1.2.x', 'a normal slash/dot branch name is accepted');
});
