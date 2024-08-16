/** @format */

import { apiPath, externalLinkForPage, isValidHttpUrl, trimURL } from './url'

describe('apiPath', () => {
  it.each([
    ['example.com', undefined, '/api/stats/example.com/'],
    ['example.com', '', '/api/stats/example.com/'],
    ['example.com', '/test', '/api/stats/example.com/test/'],
    [
      'example.com/path/is-really/deep',
      '',
      '/api/stats/example.com%2Fpath%2Fis-really%2Fdeep/'
    ]
  ])(
    'when site.domain is %p and path is %s, should return %s',
    (domain, path, expected) => {
      const result = apiPath({ domain }, path)
      expect(result).toBe(expected)
    }
  )
})

describe('externalLinkForPage', () => {
  it.each([
    ['example.com', '/about', 'https://example.com/about'],
    ['sub.example.com', '/contact', 'https://sub.example.com/contact'],
    [
      'example.com',
      '/search?q=test#section',
      'https://example.com/search?q=test#section'
    ],
    ['example.com', '/', 'https://example.com/']
  ])(
    'when domain is %s and page is %s, it should return %s',
    (domain, page, expected) => {
      const result = externalLinkForPage(domain, page)
      expect(result).toBe(expected)
    }
  )
})

describe('isValidHttpUrl', () => {
  it.each([
    // Valid HTTP and HTTPS URLs
    ['http://example.com', true],
    ['https://example.com', true],
    ['http://www.example.com', true],
    ['https://sub.domain.com', true],
    ['https://example.com/path?query=1#fragment', true],

    // Invalid URLs (invalid protocol)
    ['ftp://example.com', false],
    ['mailto:someone@example.com', false],
    ['file:///C:/path/to/file', false],
    ['data:text/plain;base64,SGVsbG8sIFdvcmxkIQ==', false],

    // Invalid URLs (malformed or non-URL strings)
    ['//example.com', false],
    ['example.com', false],
    ['just-a-string', false],
    ['', false],
    ['https//:example.com', false],

    // Edge cases
    ['http:/example.com', true],
    ['http://localhost', true],
    ['https://127.0.0.1', true],
    ['https://[::1]', true], // IPv6 URL
    ['http://user:pass@127.0.0.1', true],
    ['https://example.com:8080', true]
  ])('for input %s returns %s', (input, expected) => {
    const result = isValidHttpUrl(input)
    expect(result).toBe(expected)
  })
})

describe('trimURL', () => {
  it.each([
    // Test cases where URL length is less than or equal to maxLength
    ['https://example.com', 20, 'https://example.com'],
    ['http://example.com', 50, 'http://example.com'],

    // Test cases where host itself is too long
    [
      'https://a-very-long-domain-name.com',
      20,
      'https://a-very-long-dom...domain-name.com'
    ]
  ])(
    'when url is %s and maxLength is %d, should return %s',
    (url, maxLength, expected) => {
      const result = trimURL(url, maxLength)
      expect(result).toBe(expected)
    }
  )
})
