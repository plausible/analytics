export const WORDPRESS_PLUGIN_VERSION_SELECTOR = 'meta[name="plausible-analytics-version"]'

const WORDPRESS_SIGNATURES = [
  'wp-content',
  'wp-includes', 
  'wp-json'
]

function scanWpPlugin(document) {
  if (typeof document.querySelector === 'function') {
    const metaTag = document.querySelector(WORDPRESS_PLUGIN_VERSION_SELECTOR)
    return metaTag !== null
  }

  return false
}

function scanWp(html) {
  if (typeof html === 'string') {
    return WORDPRESS_SIGNATURES.some(signature => {
      return html.includes(signature)
  })
  }

  return false
}

export function checkWordPress(document) {
  if (typeof document === 'object') {
    const wordpressPlugin = scanWpPlugin(document)
    const wordpressLikely = wordpressPlugin || scanWp(document.documentElement?.outerHTML)
    
    return {wordpressPlugin, wordpressLikely}
  }

  return {wordpressPlugin: false, wordpressLikely: false}
}