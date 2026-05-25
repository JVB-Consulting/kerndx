// SPDX-License-Identifier: MIT
/**
 * @fileoverview Require a substantive reason on every `// kern-coverage-exempt:` comment.
 * @description JS-side equivalent of the PMD `KernCoverageExemptRequiresReason` rule.
 *              The coverage harness treats `// kern-coverage-exempt:` comments as
 *              subtracted from the denominator, so the reason must cite a platform
 *              limitation. The comment fails the rule when:
 *                - The reason text is empty.
 *                - The reason text is shorter than 15 characters.
 *                - The reason matches the blocklist (case-insensitive): `hard to test`,
 *                  `tricky`, `todo`, `fixme`, `later`, `xxx`, `hack`.
 *
 *              Suppress with: // eslint-disable-next-line kerndx/no-coverage-exempt-without-reason
 */

'use strict';

const MIN_REASON_LENGTH = 15;
const BLOCKED_REASONS = ['hard to test', 'tricky', 'todo', 'fixme', 'later', 'xxx', 'hack'];
const EXEMPT_PATTERN = /\/\/\s*kern-coverage-exempt\s*:\s*(.*)$/i;

module.exports = {
	meta: {
		type: 'problem',
		docs: {
			description: 'Require a substantive platform-limitation reason on every kern-coverage-exempt comment',
			recommended: true
		},
		messages: {
			empty: 'kern-coverage-exempt comment requires a reason. Cite the specific platform limitation after the colon.',
			tooShort: 'kern-coverage-exempt reason must be at least {{min}} characters ({{length}} given). Cite the specific platform limitation.',
			blocked: 'kern-coverage-exempt reason "{{reason}}" is not an accepted justification. Cite the specific platform behaviour, not "{{match}}".'
		},
		schema: []
	},

	create(context)
	{
		return {
			'Program:exit'()
			{
				const sourceCode = context.getSourceCode();
				const comments = sourceCode.getAllComments();

				for (const comment of comments)
				{
					if (comment.type !== 'Line')
					{
						continue;
					}

					const fullText = `//${comment.value}`;
					const match = EXEMPT_PATTERN.exec(fullText);

					if (!match)
					{
						continue;
					}

					const reason = match[1].trim();

					if (reason.length === 0)
					{
						context.report({
							node: comment,
							messageId: 'empty'
						});
						continue;
					}

					if (reason.length < MIN_REASON_LENGTH)
					{
						context.report({
							node: comment,
							messageId: 'tooShort',
							data: {min: String(MIN_REASON_LENGTH), length: String(reason.length)}
						});
						continue;
					}

					const blockedMatch = findBlockedMatch(reason);

					if (blockedMatch)
					{
						context.report({
							node: comment,
							messageId: 'blocked',
							data: {reason, match: blockedMatch}
						});
					}
				}
			}
		};
	}
};

/**
 * @description Searches a reason string for any blocklist term (case-insensitive).
 * @param {string} reason The trimmed reason text after the colon.
 * @return {?string} The first blocklist match as originally listed, or null.
 */
function findBlockedMatch(reason)
{
	const lowered = reason.toLowerCase();

	for (const blocked of BLOCKED_REASONS)
	{
		if (lowered.includes(blocked))
		{
			return blocked;
		}
	}

	return null;
}
