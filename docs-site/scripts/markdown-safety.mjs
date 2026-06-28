// SPDX-License-Identifier: BUSL-1.1
// Escapes stray < / > in PROSE so Apex generics (List<SObject>, <Id>, Map<String,Object>)
// are not parsed as Vue/HTML tags ("Element is missing end tag"). Also neutralizes Vue
// mustache interpolation ({{ x }}) outside fenced code, where Vue would otherwise evaluate
// it as a binding and crash SSR ("Cannot read properties of undefined"). Preserves fenced
// blocks verbatim (VitePress applies v-pre), keeps angle brackets in inline code spans
// (they render fine), and keeps a small allowlist of real HTML tags used in docs.

const ALLOWED = /<\/?(?:br|hr|img|a|sub|sup|kbd|code|em|strong|b|i|u|small|mark|del|ins|div|span|p|ul|ol|li|table|thead|tbody|tr|td|th|h[1-6]|details|summary|blockquote|pre|HeroLoop|StillShot)\b(?:"[^"]*"|'[^']*'|[^<>])*>/gi;
const SENTINEL = String.fromCharCode(0);
const BLOCKQUOTE = String.fromCharCode(1);

// Replace {{ / }} with HTML entities so Vue never reads them as a mustache. The entities
// decode to the same braces in the rendered DOM, so the visible/copyable text is unchanged.
function neutralizeMustache(s)
{
	return s.replace(/\{\{/g, '&#123;&#123;').replace(/\}\}/g, '&#125;&#125;');
}

export function escapeAngles(md)
{
	// Split into fenced blocks (```…```) and inline code spans (`…`) and prose; the capture
	// group keeps the delimiters so each segment is classified by its first char(s).
	const parts = md.split(/(```[\s\S]*?```|`[^`\n]*`)/g);
	return parts.map((seg, i) =>
	{
		if(i % 2 === 1)
		{
			// Code segment. Fenced blocks are v-pre (verbatim); inline spans need mustache escaping.
			if(seg.startsWith('```'))
			{
				return seg;
			}
			return neutralizeMustache(seg);
		}
		// Strip HTML comments in prose. They are invisible on GitHub, so a reader never sees
		// them — but escaping their angle brackets below would turn them into visible page text
		// (and would leak any internal authoring/audit marker). Comments inside code blocks and
		// inline spans are handled by the code branch above and stay verbatim (intentional there).
		const tags = [];
		let s = seg.replace(/<!--[\s\S]*?-->/g, '');
		s = s.replace(ALLOWED, (m) =>
		{
			tags.push(m);
			return `${SENTINEL}${tags.length - 1}${SENTINEL}`;
		});
		// Protect blockquote markers before escaping. A '>' at line start (CommonMark allows
		// up to three leading spaces, and one or more '>' for nesting) is a blockquote marker,
		// not a generic close — escaping it to &gt; turns every multi-line blockquote into a
		// literal-'>' paragraph and collapses any list inside it. Generic '>' mid-line still
		// escapes normally.
		s = s.replace(/^[ \t]{0,3}(?:>[ \t]?)+/gm, (m) => m.replace(/>/g, BLOCKQUOTE));
		s = s.replace(/</g, '&lt;').replace(/>/g, '&gt;');
		s = s.replace(new RegExp(BLOCKQUOTE, 'g'), '>');
		s = s.replace(new RegExp(`${SENTINEL}(\\d+)${SENTINEL}`, 'g'), (_m, n) => tags[Number(n)]);
		s = neutralizeMustache(s);
		return s;
	}).join('');
}
