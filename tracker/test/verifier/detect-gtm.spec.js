import { test, expect } from '@playwright/test'
import { detectGTM } from '../../verifier/detect-gtm'

function mockDocument(html) {
  return {
    documentElement: {outerHTML: `<html>${html}</html>`}
  }
}

test.describe('detectGTM (gtmLikely)', () => {
  test('handles document undefined', () => {
    expect(detectGTM(undefined)).toBe(false)
  })

  test('handles document.documentElement undefined', () => {
    const document = {documentElement: undefined}
    expect(detectGTM(document)).toBe(false)
  })

  test('false when no GTM indicators present', () => {
    const document = mockDocument('<head></head><body></body>')
    expect(detectGTM(document)).toBe(false)
  })

  test('detects gtmLikely by googletagmanager.com/gtm.js signature', () => {
    const document = mockDocument('<head><script src="https://www.googletagmanager.com/gtm.js?id=GTM-XXXX"></script></head>')
    expect(detectGTM(document)).toBe(true)
  })
})