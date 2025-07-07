import { test, expect } from '@playwright/test'
import { detectWordPress, WORDPRESS_PLUGIN_VERSION_SELECTOR } from '../../verifier/detect-wp'

function mockDocument(html, hasMetaTag) {
  return {
    documentElement: {outerHTML: `<html>${html}</html>`},
    querySelector: (selector) => {
      if (selector === WORDPRESS_PLUGIN_VERSION_SELECTOR) {
        return hasMetaTag ? {} : null
      }
      return null
    }
  }
}

test.describe('detectWordPress (wordpressPlugin, wordPressLikely)', () => {
  test('handles document undefined', () => {
    const result = detectWordPress(undefined)
    
    expect(result.wordpressPlugin).toBe(false)
    expect(result.wordpressLikely).toBe(false)
  })

  test('handles document.querySelector undefined', () => {
    const document = {documentElement: {outerHTML: '<html></html>'}}
    const result = detectWordPress(document)
    
    expect(result.wordpressPlugin).toBe(false)
    expect(result.wordpressLikely).toBe(false)
  })

  test('handles document.documentElement undefined', () => {
    const document = {documentElement: undefined, querySelector: (_) => null}
    const result = detectWordPress(document)
    
    expect(result.wordpressPlugin).toBe(false)
    expect(result.wordpressLikely).toBe(false)
  })

  test('both false when no WordPress indicators present', () => {
    const document = mockDocument('<head></head><body></body>', false)
    const result = detectWordPress(document)
    
    expect(result.wordpressPlugin).toBe(false)
    expect(result.wordpressLikely).toBe(false)
  })

  test('both true if WordPress plugin version meta tag detected', () => {
    const document = mockDocument('<head></head><body></body>', true)
    const result = detectWordPress(document)
    
    expect(result.wordpressPlugin).toBe(true)
    expect(result.wordpressLikely).toBe(true)
  })

  test('detects wordpressLikely by wp-content signature', () => {
    const document = mockDocument('<head><script src="/wp-content/themes/mytheme/script.js"></script></head>', false)
    const result = detectWordPress(document)
    
    expect(result.wordpressPlugin).toBe(false)
    expect(result.wordpressLikely).toBe(true)
  })

  test('detects wordpressLikely by wp-includes signature', () => {
    const document = mockDocument('<head><link rel="stylesheet" href="/wp-includes/css/style.css"></head>', false)
    const result = detectWordPress(document)
    
    expect(result.wordpressPlugin).toBe(false)
    expect(result.wordpressLikely).toBe(true)
  })

  test('detects wordpressLikely by wp-json signature', () => {
    const document = mockDocument('<body><script>fetch("/wp-json/wp/v2/posts")</script></body>', false)
    const result = detectWordPress(document)
    
    expect(result.wordpressPlugin).toBe(false)
    expect(result.wordpressLikely).toBe(true)
  })

  test('detects wordpressLikely by multiple signatures', () => {
    const document = mockDocument(
      `
        <head>
          <script src="/wp-content/themes/mytheme/script.js"></script>
        </head>
        <body>
          <script>fetch("/wp-json/wp/v2/posts")</script>
        </body>
      `,
      false
    )
    
    const result = detectWordPress(document)
    
    expect(result.wordpressPlugin).toBe(false)
    expect(result.wordpressLikely).toBe(true)
  })
})