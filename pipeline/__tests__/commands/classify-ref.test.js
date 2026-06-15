// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {classifyRef} = require('../../src/commands/classify-ref.js');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

function tmpConfig(content)
{
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'classify-'));
	const file = path.join(dir, 'config.yml');
	fs.writeFileSync(file, content);
	return file;
}

test('classifyRef emits GITHUB_OUTPUT-style lines for back-prom', () =>
{
	const cfg = tmpConfig(`
package_dirs: [force-app]
branches: { main: main, ingress: [build], protected: [main, build] }
ci_adapter: { name: gearset }
`);
	const out = classifyRef({headRef: 'gs-pipeline/main_-_build', configPath: cfg});
	assert.match(out, /is_backprom=true/);
	assert.match(out, /action=skip-scan/);
	assert.match(out, /label=back-promotion/);
});
