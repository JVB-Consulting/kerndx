// SPDX-License-Identifier: BUSL-1.1
// One reader for a lightning-datatable's column labels, shared by the page objects whose checks
// compare a whole column set exactly rather than searching the header text for one word (the Chain
// Monitor's list and the Log Console's list, both of which drop columns at narrow widths).
//
// The row-select header is told apart structurally rather than by its words: the datatable marks it
// role="gridcell" (data-col-key-value="0-SELECTABLE_CHECKBOX-0") while every data column is
// role="columnheader", so the filter holds whatever language the org runs in. Each data header also
// carries its clean label in aria-label; the visible-text rule (the line after "Sort by:" on a
// sortable header, else the first line) is the fallback for a header that has none.
//
// This directory is deliberately NOT `helpers/`: jest collects coverage from
// release-testing/e2e/helpers/**, and a module only ever loaded by Playwright would land there as a
// permanent zero-coverage file.

/**
 * @description The data columns' labels, in the order the table shows them.
 *
 * @param {Object} datatable A Playwright locator for the lightning-datatable to read.
 *
 * @returns {Promise<string[]>} The column labels.
 */
async function readColumnLabels(datatable)
{
	return datatable.locator('thead th[role="columnheader"]').evaluateAll((headers) => headers.map((header) =>
	{
		const label = (header.getAttribute('aria-label') || '').trim();
		if(label.length > 0)
		{
			return label;
		}
		const lines = (header.innerText || '').split('\n').map((line) => line.trim()).filter((line) => line.length > 0);
		return lines[0] === 'Sort by:' ? lines[1] : lines[0];
	}));
}

module.exports = {readColumnLabels};
