import { test, expect } from '@playwright/test'
import { checkUnknownAttributes } from '../../installation_support/check-unknown-attributes.js'

test.describe('checkUnknownAttributes', () => {
  test('returns false when no snippets', () => {
    expect(checkUnknownAttributes([])).toBe(false)
    expect(checkUnknownAttributes(null)).toBe(false)
    expect(checkUnknownAttributes(undefined)).toBe(false)
  })

  test('returns false when all attributes are known', () => {
    const mockSnippet = {
      attributes: [
        { name: 'data-domain', value: 'example.com' },
        { name: 'src', value: 'https://plausible.io/js/script.js' },
        { name: 'async', value: '' },
        { name: 'data-api', value: '/api/event' },
        { name: 'data-exclude', value: '/admin/*' },
        { name: 'data-include', value: '/blog/*' },
        { name: 'data-cfasync', value: 'false' }
      ]
    }

    expect(checkUnknownAttributes([mockSnippet])).toBe(false)
  })

  test('returns false when type="text/javascript" attribute is present', () => {
    const mockSnippet = {
      attributes: [
        { name: 'data-domain', value: 'example.com' },
        { name: 'src', value: 'https://plausible.io/js/script.js' },
        { name: 'type', value: 'text/javascript' }
      ]
    }

    expect(checkUnknownAttributes([mockSnippet])).toBe(false)
  })

  test('returns false when event-* attributes are present', () => {
    const mockSnippet = {
      attributes: [
        { name: 'data-domain', value: 'example.com' },
        { name: 'src', value: 'https://plausible.io/js/script.js' },
        { name: 'event-click', value: 'handler' },
        { name: 'event-load', value: 'loadHandler' }
      ]
    }

    expect(checkUnknownAttributes([mockSnippet])).toBe(false)
  })

  test('returns true when unknown attributes are present', () => {
    const mockSnippet = {
      attributes: [
        { name: 'data-domain', value: 'example.com' },
        { name: 'src', value: 'https://plausible.io/js/script.js' },
        { name: 'unknown-attribute', value: 'value' }
      ]
    }

    expect(checkUnknownAttributes([mockSnippet])).toBe(true)
  })

  test('returns true when multiple unknown attributes are present', () => {
    const mockSnippet = {
      attributes: [
        { name: 'data-domain', value: 'example.com' },
        { name: 'src', value: 'https://plausible.io/js/script.js' },
        { name: 'unknown-attribute-1', value: 'value1' },
        { name: 'unknown-attribute-2', value: 'value2' }
      ]
    }

    expect(checkUnknownAttributes([mockSnippet])).toBe(true)
  })

  test('returns true when at least one snippet has unknown attributes', () => {
    const mockSnippet1 = {
      attributes: [
        { name: 'data-domain', value: 'example.com' },
        { name: 'src', value: 'https://plausible.io/js/script.js' }
      ]
    }

    const mockSnippet2 = {
      attributes: [
        { name: 'data-domain', value: 'example.com' },
        { name: 'src', value: 'https://plausible.io/js/script.js' },
        { name: 'unknown-attribute', value: 'value' }
      ]
    }

    expect(checkUnknownAttributes([mockSnippet1, mockSnippet2])).toBe(true)
  })

  test('returns false when all snippets have only known attributes', () => {
    const mockSnippet1 = {
      attributes: [
        { name: 'data-domain', value: 'example.com' },
        { name: 'src', value: 'https://plausible.io/js/script.js' }
      ]
    }

    const mockSnippet2 = {
      attributes: [
        { name: 'data-domain', value: 'example.com' },
        { name: 'src', value: 'https://plausible.io/js/script.js' },
        { name: 'async', value: '' }
      ]
    }

    expect(checkUnknownAttributes([mockSnippet1, mockSnippet2])).toBe(false)
  })
})
