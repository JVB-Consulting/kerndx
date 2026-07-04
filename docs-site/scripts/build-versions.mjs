// SPDX-License-Identifier: BUSL-1.1
// Multi-version docs build + assembly (PLAN-105 Phase 2.4). Builds the latest tree at the
// root, then every frozen docs-versions/<X.Y>/ line under /X.Y/, into one dist/:
//
//   dist/            ← latest  (DOCS_BASE=/)            canonical CNAME / 404 / robots / sitemap
//   dist/1.1/        ← frozen  (DOCS_BASE=/1.1/ FROZEN) noindex, no sitemap, smart canonical
//
// Latest builds first so its route list can drive frozen smart-canonical (a frozen page that
// still exists in latest canonicalises there). Each frozen tree is content+toolchain hashed and
// cached, so an unchanged line is reused instead of rebuilt. No built HTML is committed — only
// the assembled dist/ is uploaded by docs.yml; the committed source is docs-versions/.
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {readFileSync, writeFileSync, existsSync, rmSync, mkdirSync, cpSync, readdirSync} from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {resolveVersionList} from './package-version.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');   // docs-site/
const REPO = path.resolve(ROOT, '..');                                          // repo root
const DIST = path.join(ROOT, '.vitepress', 'dist');
const CACHE = path.join(ROOT, '.vitepress', 'frozen-cache');
const LATEST_ROUTES_FILE = path.join(ROOT, '.vitepress', 'latest-routes.generated.json');

function run(cmd, args, env)
{
	execFileSync(cmd, args, {cwd: ROOT, stdio: 'inherit', env: {...process.env, ...env}});
}

function listFrozenLines()
{
	try
	{
		return readdirSync(path.join(REPO, 'docs-versions'), {withFileTypes: true})
		.filter(e => e.isDirectory() && /^\d+\.\d+$/.test(e.name)).map(e => e.name);
	}
	catch
	{
		return [];
	}
}

// Stable hash of a directory's relative paths + bytes.
function hashDir(dir, hash)
{
	for(const e of readdirSync(dir, {withFileTypes: true}).sort((a, b) => (a.name < b.name ? -1 : 1)))
	{
		const p = path.join(dir, e.name);
		if(e.isDirectory())
		{
			hashDir(p, hash);
		}
		else
		{
			hash.update(e.name);
			hash.update(readFileSync(p));
		}
	}
}

// A frozen tree's cache key = its source content + the toolchain that renders it (deps, config,
// theme, build scripts). "Chrome-from-latest" means a theme/config change must re-render frozen
// content, so the toolchain is part of the key — not content alone.
function frozenHash(line)
{
	const h = createHash('sha256');
	hashDir(path.join(REPO, 'docs-versions', line), h);
	h.update(readFileSync(path.join(ROOT, 'package-lock.json')));
	h.update(readFileSync(path.join(ROOT, '.vitepress', 'config.mjs')));
	hashDir(path.join(ROOT, '.vitepress', 'theme'), h);
	hashDir(path.join(ROOT, 'scripts'), h);
	return h.digest('hex');
}

function buildLatest()
{
	console.log('▶ latest  → dist/            (DOCS_BASE=/)');
	run('npm', ['run', 'build'], {DOCS_BASE: '/', DOCS_FROZEN: ''});
	// Hand the latest route set to frozen builds for smart canonical.
	writeFileSync(LATEST_ROUTES_FILE, readFileSync(path.join(DIST, 'routes.json'), 'utf8'));
}

function buildFrozen(line)
{
	const hash = frozenHash(line);
	const cacheLine = path.join(CACHE, line);
	const hashFile = path.join(CACHE, `${line}.hash`);
	const hit = existsSync(hashFile) && existsSync(cacheLine) && readFileSync(hashFile, 'utf8').trim() === hash;
	if(hit)
	{
		console.log(`■ ${line}     → cache hit          (reused, not rebuilt)`);
	}
	else
	{
		console.log(`▶ ${line}     → dist/${line}/        (DOCS_BASE=/${line}/ DOCS_FROZEN=1)`);
		rmSync(cacheLine, {recursive: true, force: true});
		const env = {
			DOCS_BASE: `/${line}/`,
			DOCS_FROZEN: '1',
			DOCS_VERSION: line,
			DOCS_SRC: `docs-versions/${line}/docs`,
			HOME_SRC: `docs-versions/${line}/home.md`,
			RELEASE_NOTES_SRC: `docs-versions/${line}/release-notes`,
			LATEST_ROUTES_FILE
		};
		run('npm', ['run', 'prepare:src'], env);
		run('npx', ['vitepress', 'build', '--outDir', path.join('.vitepress', 'frozen-cache', line)], env);
		writeFileSync(hashFile, `${hash}\n`);
	}
	const destLine = path.join(DIST, line);
	rmSync(destLine, {recursive: true, force: true});
	cpSync(cacheLine, destLine, {recursive: true});
}

function main()
{
	const versions = resolveVersionList(JSON.parse(readFileSync(path.join(REPO, 'sfdx-project.json'), 'utf8')), listFrozenLines());
	const frozen = versions.filter(v => !v.latest).map(v => v.line);
	mkdirSync(CACHE, {recursive: true});

	buildLatest();
	for(const line of frozen)
	{
		buildFrozen(line);
	}

	console.log(`\nAssembled dist/: latest at / + ${frozen.length} frozen tree(s) [${frozen.join(', ') || 'none'}].`);
}

main();
