export function checkProxyLikely(snippets) {
  if (!snippets || snippets.length === 0) return false

  return snippets.some(snippet => {
    const src = snippet.getAttribute('src')
    return !isPlausibleIoSrc(src)
  })
}

export function isPlausibleIoSrc(src) {
  return src && /^https:\/\/plausible\.io\//.test(src)
}