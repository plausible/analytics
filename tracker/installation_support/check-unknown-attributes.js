const KNOWN_ATTRIBUTES = [
  'data-domain',
  'src',
  'defer',
  'async',
  'data-api',
  'data-exclude',
  'data-include',
  'data-cfasync'
]

export function checkUnknownAttributes(snippets) {
  if (!snippets || snippets.length === 0) return false

  return snippets.some((snippet) => {
    const attributes = snippet.attributes

    for (let i = 0; i < attributes.length; i++) {
      const attr = attributes[i]

      if (attr.name === 'type' && attr.value === 'text/javascript') {
        continue
      }

      if (attr.name.startsWith('event-')) {
        continue
      }

      if (!KNOWN_ATTRIBUTES.includes(attr.name)) {
        return true
      }
    }

    return false
  })
}
