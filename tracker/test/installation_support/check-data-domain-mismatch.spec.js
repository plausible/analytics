import { test, expect } from '@playwright/test'
import { checkDataDomainMismatch } from '../../installation_support/check-data-domain-mismatch'

function mockSnippet(dataDomain) {
  return { getAttribute: (_) => dataDomain }
}

test.describe('checkDataDomainMismatch', () => {
  test('returns false when no snippets provided', () => {
    expect(checkDataDomainMismatch([], 'example.com')).toBe(false)
    expect(checkDataDomainMismatch(null, 'example.com')).toBe(false)
    expect(checkDataDomainMismatch(undefined, 'example.com')).toBe(false)
  })

  test('handles empty data-domain attribute', () => {
    const snippets = [mockSnippet('')]
    expect(checkDataDomainMismatch(snippets, 'example.com')).toBe(true)
  })

  test('returns false when snippet data-domain matches expected domain', () => {
    const snippets = [mockSnippet('example.com')]
    expect(checkDataDomainMismatch(snippets, 'example.com')).toBe(false)
  })

  test('returns true when snippet data-domain does not match expected domain', () => {
    const snippets = [mockSnippet('wrong.com')]
    expect(checkDataDomainMismatch(snippets, 'example.com')).toBe(true)
  })

  test('allows www. in data-domain', () => {
    const snippets = [mockSnippet('www.example.com')]
    expect(checkDataDomainMismatch(snippets, 'example.com')).toBe(false)
  })

  test('handles multiple domains in data-domain attribute', () => {
    const snippets = [mockSnippet('example.org,example.com,example.net')]
    expect(checkDataDomainMismatch(snippets, 'example.com')).toBe(false)
  })

  test('handles multiple domains with spaces in data-domain attribute', () => {
    const snippets = [mockSnippet('example.org, example.com, example.net')]
    expect(checkDataDomainMismatch(snippets, 'example.com')).toBe(false)
  })

  test('handles multiple domains with www prefix', () => {
    const snippets = [
      mockSnippet('www.example.org, www.example.com, www.example.net')
    ]
    expect(checkDataDomainMismatch(snippets, 'example.com')).toBe(false)
  })

  test('returns true when expected domain not in multi-domain list', () => {
    const snippets = [mockSnippet('example.org,example.com,example.net')]
    expect(checkDataDomainMismatch(snippets, 'example.typo')).toBe(true)
  })

  test('handles multiple snippets - returns true if any snippet has domain mismatch', () => {
    const snippets = [mockSnippet('example.com'), mockSnippet('wrong.com')]
    expect(checkDataDomainMismatch(snippets, 'example.com')).toBe(true)
  })

  test('handles multiple snippets - returns false if all snippets match', () => {
    const snippets = [
      mockSnippet('example.com'),
      mockSnippet('example.org,example.com,example.net')
    ]
    expect(checkDataDomainMismatch(snippets, 'example.com')).toBe(false)
  })
})
