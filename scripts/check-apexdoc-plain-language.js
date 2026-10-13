// SPDX-License-Identifier: BUSL-1.1
//
// Lists every comment in an Apex class, trigger or LWC module that carries plan vocabulary: a plan code such as
// I3, D11, SAR-1, BUG-008 or PLAN-182, a reference to "the spec", or a word that belongs to the planning record and
// not to documentation ("cell", "pinned", "projection", "resting state", "witness"), a word of the team's own slang
// ("zombie", "sidecar", "latch", "hand-off") or an em-dash used as prose punctuation. ApexDoc and JSDoc are read by
// whoever installs or maintains the package; a comment that needs the plan to be understood fails them. The rule
// lives in docs/Code Conventions - Guide.md (section ApexDoc, "Plain language, never the plan's words"); this check
// exists because the words walked from the briefs into the code on three plans before it was made deterministic.
//
// Usage:
//   node scripts/check-apexdoc-plain-language.js               Check the changed lines of the files modified against HEAD (default)
//   node scripts/check-apexdoc-plain-language.js --base <ref>  Check the changed lines of the files modified against another ref
//   node scripts/check-apexdoc-plain-language.js --all         Check every line of every class, trigger and module under force-app
//
// Without --all, only the lines a file adds or changes since the reference are read, staged or not, and an untracked
// file is read whole; one line says how many hits on unchanged lines were left out, because the tree is not clean yet.
//
// Exit code 1 when any checked comment carries plan vocabulary, 0 otherwise. Only comment text is read: a string
// literal or an identifier on a code line is never reported. The lint itself is scripts/lib/apexdoc-plain-language-lint.js.

'use strict';

const path = require('path');
const {repositoryInputs, run} = require('./lib/apexdoc-plain-language-lint');

/* istanbul ignore next — script-entry handler */
if(require.main === module)
{
	process.exit(run(process.argv.slice(2), repositoryInputs(path.resolve(__dirname, '..'))));
}
