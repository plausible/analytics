import { test, expect } from '@playwright/test'
import { checkProxyLikely } from '../../installation_support/check-proxy-likely'

function mockSnippet(src) {
  return { getAttribute: (_) => src }
}

test.describe('checkProxyLikely', () => {
  test('returns false when no snippets provided', () => {
    expect(checkProxyLikely([])).toBe(false)
    expect(checkProxyLikely(null)).toBe(false)
    expect(checkProxyLikely(undefined)).toBe(false)
  })

  test('handles empty src attribute', () => {
    const snippets = [mockSnippet('')]
    expect(checkProxyLikely(snippets)).toBe(false)
  })

  test('returns false when snippet src is official plausible.io URL', () => {
    const snippets = [mockSnippet('https://plausible.io/js/plausible.js')]
    expect(checkProxyLikely(snippets)).toBe(false)
  })

  test('returns false when snippet src is official plausible.io URL with query params', () => {
    const snippets = [
      mockSnippet('https://plausible.io/js/plausible.js?v=1.0.0')
    ]
    expect(checkProxyLikely(snippets)).toBe(false)
  })

  test('handles similar domain names (should be true)', () => {
    const snippets = [
      mockSnippet('https://plausible.io.example.com/js/plausible.js')
    ]
    expect(checkProxyLikely(snippets)).toBe(true)
  })

  test('returns true when snippet src is relative path', () => {
    const snippets = [mockSnippet('/js/plausible.js')]
    expect(checkProxyLikely(snippets)).toBe(true)
  })

  test('handles multiple snippets - returns true if any snippet is proxied', () => {
    const snippets = [
      mockSnippet('https://plausible.io/js/plausible.js'),
      mockSnippet('https://analytics.example.com/js/plausible.js')
    ]
    expect(checkProxyLikely(snippets)).toBe(true)
  })

  test('handles multiple snippets - returns false if all snippets are official', () => {
    const snippets = [
      mockSnippet('https://plausible.io/js/plausible.js'),
      mockSnippet('https://plausible.io/js/plausible.outbound-links.js')
    ]
    expect(checkProxyLikely(snippets)).toBe(false)
  })

  test('handles plausible.io subdomain (should be true)', () => {
    const snippets = [
      mockSnippet('https://staging.plausible.io/js/plausible.js')
    ]
    expect(checkProxyLikely(snippets)).toBe(true)
  })
})
