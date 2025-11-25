import { test, expect } from '@playwright/test'
import { checkGTM } from '../../installation_support/check-gtm'

function mockDocument(html) {
  return {
    documentElement: { outerHTML: `<html>${html}</html>` }
  }
}

test.describe('checkGTM (gtmLikely)', () => {
  test('handles document undefined', () => {
    expect(checkGTM(undefined)).toBe(false)
  })

  test('handles document.documentElement undefined', () => {
    const document = { documentElement: undefined }
    expect(checkGTM(document)).toBe(false)
  })

  test('false when no GTM indicators present', () => {
    const document = mockDocument('<head></head><body></body>')
    expect(checkGTM(document)).toBe(false)
  })

  test('detects gtmLikely by googletagmanager.com/gtm.js signature', () => {
    const document = mockDocument(
      '<head><script src="https://www.googletagmanager.com/gtm.js?id=GTM-XXXX"></script></head>'
    )
    expect(checkGTM(document)).toBe(true)
  })
})
