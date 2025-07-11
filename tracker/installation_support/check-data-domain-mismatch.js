export function checkDataDomainMismatch(snippets, expectedDataDomain) {
  if (!snippets || snippets.length === 0) return false

  return snippets.some(snippet => {
    const scriptDataDomain = snippet.getAttribute('data-domain')

    const multiple = scriptDataDomain.split(',').map(d => d.trim())
    const dataDomainMismatch = !multiple.some((domain) => domain.replace(/^www\./, '') === expectedDataDomain)
    
    return dataDomainMismatch
  })
}