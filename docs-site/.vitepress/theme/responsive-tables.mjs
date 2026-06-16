// SPDX-License-Identifier: BUSL-1.1
// markdown-it plugin: tag every table-body <td> with data-label="<column header>".
// On narrow viewports the theme CSS uses these labels to collapse wide tables into
// labeled stacked cards (each row a card, each cell prefixed by its column name)
// instead of horizontal-scrolling crushed columns — the mobile-readability fix that
// applies site-wide (reference parameter/summary tables, home, landing "Quick Links",
// Fast-Start decision matrices). Pure token rewrite; no rendering-rule override, so it
// composes with VitePress's own table renderer.
export default function responsiveTables(md)
{
	md.core.ruler.push('kerndx_responsive_table_labels', (state) =>
	{
		const tokens = state.tokens;
		let headers = [];
		let inThead = false;
		let inTbody = false;
		let col = 0;
		for(let i = 0; i < tokens.length; i++)
		{
			const t = tokens[i];
			switch(t.type)
			{
				case 'thead_open':
					inThead = true;
					headers = [];
					break;
				case 'thead_close':
					inThead = false;
					break;
				case 'tbody_open':
					inTbody = true;
					break;
				case 'tbody_close':
					inTbody = false;
					headers = [];
					break;
				case 'tr_open':
					col = 0;
					break;
				case 'th_open':
					if(inThead)
					{
						const inline = tokens[i + 1];
						headers.push(inline && inline.type === 'inline' ? inline.content : '');
					}
					break;
				case 'td_open':
					if(inTbody)
					{
						const label = headers[col] || '';
						if(label)
						{
							t.attrSet('data-label', label);
						}
						col++;
					}
					break;
				default:
					break;
			}
		}
		return false;
	});
}
