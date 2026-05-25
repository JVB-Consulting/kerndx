// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { loadConfig, ConfigError } = require('../../src/lib/config-loader.js');

function writeTmpConfig(content) {
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'kerndx-cfg-'));
	const file = path.join(dir, 'config.yml');
	fs.writeFileSync(file, content);
	return { file, dir };
}

test('loadConfig accepts a minimal valid config', () => {
	const { file } = writeTmpConfig(`
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

test('loadConfig rejects unknown top-level keys', () => {
	const { file } = writeTmpConfig(`
package_dirs: [force-app]
branches: { main: main, ingress: [main], protected: [main] }
ci_adapter: { name: none }
mystery_key: nope
`);
	assert.throws(() => loadConfig(file), ConfigError);
});

test('loadConfig rejects experimental adapter without experimental: true', () => {
	const { file } = writeTmpConfig(`
package_dirs: [force-app]
branches: { main: main, ingress: [main], protected: [main] }
ci_adapter: { name: copado }
`);
	assert.throws(() => loadConfig(file), /experimental/);
});

test('loadConfig accepts copado with experimental: true', () => {
	const { file } = writeTmpConfig(`
package_dirs: [force-app]
branches: { main: main, ingress: [main], protected: [main] }
ci_adapter: { name: copado, experimental: true }
`);
	const cfg = loadConfig(file);
	assert.equal(cfg.ci_adapter.name, 'copado');
	assert.equal(cfg.ci_adapter.experimental, true);
});

test('loadConfig validates custom adapter pattern length', () => {
	const pattern = 'x'.repeat(300);
	const { file } = writeTmpConfig(`
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

test('loadConfig rejects unsafe regex in custom adapter pattern', () => {
	const { file } = writeTmpConfig(`
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
