import { test, expect } from '@playwright/test'
import { checkManualExtension } from '../../verifier/check-manual-extension'

function mockSnippet(dataDomain) {
  return { getAttribute: _ => dataDomain }
}

test.describe('checkManualExtension', () => {
  test('returns false when no snippets provided', () => {
    expect(checkManualExtension([])).toBe(false)
    expect(checkManualExtension(null)).toBe(false)
    expect(checkManualExtension(undefined)).toBe(false)
  })

  test('handles empty src attribute', () => {
    const snippets = [mockSnippet('')]
    expect(checkManualExtension(snippets)).toBe(false)
  })

  test('returns true when snippet src includes manual', () => {
    const snippets = [mockSnippet('https://plausible.io/js/script.manual.js')]
    expect(checkManualExtension(snippets)).toBe(true)
  })

  test('returns false when snippet src does not include manual', () => {
    const snippets = [mockSnippet('https://plausible.io/js/script.js')]
    expect(checkManualExtension(snippets)).toBe(false)
  })

  test('handles multiple snippets - returns true if any src includes manual', () => {
    const snippets = [
      mockSnippet('https://plausible.io/js/plausible.manual.js'),
      mockSnippet('https://plausible.io/js/plausible.js')
    ]
    expect(checkManualExtension(snippets)).toBe(true)
  })

  test('handles multiple snippets - returns false if no manual snippets', () => {
    const snippets = [
      mockSnippet('https://plausible.io/js/plausible.outbound-links.js'),
      mockSnippet('https://plausible.io/js/plausible.compat.js')
    ]
    expect(checkManualExtension(snippets)).toBe(false)
  })
})