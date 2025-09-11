export function checkManualExtension(snippets) {
  if (!snippets || snippets.length === 0) return false

  return snippets.some((snippet) => {
    return snippet.getAttribute('src').includes('manual.')
  })
}
