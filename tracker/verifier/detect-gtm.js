const GTM_SIGNATURES = [
  'googletagmanager.com/gtm.js'
]

function scanGTM(html) {
  if (typeof html === 'string') {
    return GTM_SIGNATURES.some(signature => {
      return html.includes(signature)
    })
  }

  return false
}

export function detectGTM(document) {
  if (typeof document === 'object') {
    return scanGTM(document.documentElement?.outerHTML)
  }

  return false
}