// SPDX-License-Identifier: BUSL-1.1
// The single URL rule for the whole site: slug = slugify(relative path), per segment.
// Relative paths are POSIX, relative to the docs/ root (e.g. "reference/apex/UTIL_SObject.md").

export function slugifySegment(segment) {
  return segment
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/-{2,}/g, '-')
    .replace(/^-+|-+$/g, '')
}

export function slugForPath(relPath) {
  const noExt = relPath.replace(/\.md$/i, '')
  const segments = noExt.split('/').filter(Boolean)
  if (segments.length && segments[segments.length - 1].toLowerCase() === 'index') {
    segments.pop()
  }
  return segments.map(slugifySegment).join('/')
}

// Map<relPath, slug>; throws when two distinct paths produce the same slug.
export function buildSlugMap(relPaths) {
  const byPath = new Map()
  const bySlug = new Map()
  for (const relPath of relPaths) {
    const slug = slugForPath(relPath)
    const prior = bySlug.get(slug)
    if (prior !== undefined && prior !== relPath) {
      throw new Error(`Slug collision: "${relPath}" and "${prior}" both map to "/${slug}"`)
    }
    bySlug.set(slug, relPath)
    byPath.set(relPath, slug)
  }
  return byPath
}
