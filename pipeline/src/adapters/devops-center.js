// SPDX-License-Identifier: MIT
'use strict';
// DevOps Center uses linked-branch pulls without renaming, so no intercept exists.
// Effectively `none`, but documented separately so subscribers don't ask.
const none = require('./none.js');
function build() {
	const inner = none.build();
	return { ...inner, name: 'devops-center' };
}
module.exports = { build };
