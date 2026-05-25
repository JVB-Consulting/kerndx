// SPDX-License-Identifier: MIT
'use strict';
const readline = require('node:readline');

function readAllLines(stream)
{
	return new Promise((resolve, reject) =>
	{
		let buffer = '';
		stream.setEncoding('utf-8');
		stream.on('data', chunk => { buffer += chunk; });
		stream.on('end', () => resolve(buffer.split(/\r?\n/)));
		stream.on('error', reject);
	});
}

function readlineSession({ stdin, stdout })
{
	const rl = readline.createInterface({ input: stdin, output: stdout });
	function ask(prompt)
	{
		return new Promise(r => rl.question(prompt, r));
	}
	return {
		askText: async (prompt) => (await ask(prompt)).trim(),
		askChoice: async (prompt, choices) =>
		{
			const lines = choices.map((c, i) => `  ${i + 1}. ${c}`).join('\n');
			const raw = (await ask(`${prompt}\n${lines}\nChoice [1]: `)).trim();
			const idx = raw === '' ? 1 : parseInt(raw, 10);
			if (isNaN(idx) || idx < 1 || idx > choices.length)
				throw new Error(`Invalid choice "${raw}" — expected 1..${choices.length}`);
			return choices[idx - 1];
		},
		askYesNo: async (prompt, defaultYes = true) =>
		{
			const def = defaultYes ? 'Y/n' : 'y/N';
			const raw = (await ask(`${prompt} [${def}]: `)).trim().toLowerCase();
			if (raw === '') return defaultYes;
			return raw === 'y' || raw === 'yes';
		},
		close: () => rl.close()
	};
}

function bufferedSession({ lines, stdout })
{
	let cursor = 0;
	function next()
	{
		const line = cursor < lines.length ? lines[cursor] : '';
		cursor++;
		return line;
	}
	return {
		askText: async (prompt) =>
		{
			stdout.write(prompt);
			const line = next();
			stdout.write(line + '\n');
			return line.trim();
		},
		askChoice: async (prompt, choices) =>
		{
			const lines2 = choices.map((c, i) => `  ${i + 1}. ${c}`).join('\n');
			stdout.write(`${prompt}\n${lines2}\nChoice [1]: `);
			const raw = next().trim();
			stdout.write(raw + '\n');
			const idx = raw === '' ? 1 : parseInt(raw, 10);
			if (isNaN(idx) || idx < 1 || idx > choices.length)
				throw new Error(`Invalid choice "${raw}" — expected 1..${choices.length}`);
			return choices[idx - 1];
		},
		askYesNo: async (prompt, defaultYes = true) =>
		{
			const def = defaultYes ? 'Y/n' : 'y/N';
			stdout.write(`${prompt} [${def}]: `);
			const raw = next().trim().toLowerCase();
			stdout.write(raw + '\n');
			if (raw === '') return defaultYes;
			return raw === 'y' || raw === 'yes';
		},
		close: () => { /* no-op for buffered */ }
	};
}

async function createSession({ stdin = process.stdin, stdout = process.stdout } = {})
{
	if (stdin.isTTY)
	{
		return readlineSession({ stdin, stdout });
	}
	const lines = await readAllLines(stdin);
	return bufferedSession({ lines, stdout });
}

async function askText(prompt, opts = {})
{
	const session = await createSession(opts);
	try { return await session.askText(prompt); } finally { session.close(); }
}

async function askChoice(prompt, choices, opts = {})
{
	const session = await createSession(opts);
	try { return await session.askChoice(prompt, choices); } finally { session.close(); }
}

async function askYesNo(prompt, defaultYes = true, opts = {})
{
	const session = await createSession(opts);
	try { return await session.askYesNo(prompt, defaultYes); } finally { session.close(); }
}

module.exports = { askText, askChoice, askYesNo, createSession };
