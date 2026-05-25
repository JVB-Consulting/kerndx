// SPDX-License-Identifier: MIT
'use strict';

function build(_adapterConfig, _branches) {
	return {
		name: 'none',
		classifyHeadRef(_headRef) {
			return { action: 'full-scan', label: 'normal' };
		},
	};
}

module.exports = { build };
