export function checkProxyLikely(snippets) {
  if (!snippets || snippets.length === 0) return false

  return snippets.some((snippet) => {
    const src = snippet.getAttribute('src')
    return src && !/^https:\/\/plausible\.io\//.test(src)
  })
}
