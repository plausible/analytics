import { test, expect } from '@playwright/test'
import { checkDisallowedByCSP } from '../../installation_support/check-disallowed-by-csp'

const HOSTS_TO_CHECK = ['plausible.io']

test.describe('checkDisallowedByCSP', () => {
  test('returns false if no CSP header', () => {
    expect(checkDisallowedByCSP({}, HOSTS_TO_CHECK)).toBe(false)
    expect(checkDisallowedByCSP({foo: 'bar'}, HOSTS_TO_CHECK)).toBe(false)
  })

  test('returns false if CSP header is empty', () => {
    expect(checkDisallowedByCSP({'content-security-policy': ''}, HOSTS_TO_CHECK)).toBe(false)
  })

  test('returns true if plausible.io is not allowed', () => {
    const headers = {'content-security-policy': "default-src 'self' foo.local; example.com"}
    expect(checkDisallowedByCSP(headers, HOSTS_TO_CHECK)).toBe(true)
  })

  test('returns false if plausible.io is allowed', () => {
    const headers = {'content-security-policy': "default-src 'self' plausible.io; example.com"}
    expect(checkDisallowedByCSP(headers, HOSTS_TO_CHECK)).toBe(false)
  })

  test('returns false if plausible.io subdomain is allowed', () => {
    const headers = {'content-security-policy': "default-src 'self' staging.plausible.io; example.com"}
    expect(checkDisallowedByCSP(headers, HOSTS_TO_CHECK)).toBe(false)
  })

  test('returns false if plausible.io is allowed with https', () => {
    const headers = {'content-security-policy': "default-src 'self' https://plausible.io; example.com"}
    expect(checkDisallowedByCSP(headers, HOSTS_TO_CHECK)).toBe(false)
  })

  test('returns true if plausible.io is not present in any directive', () => {
    const headers = {'content-security-policy': "default-src 'self' foo.com; bar.com"}
    expect(checkDisallowedByCSP(headers, HOSTS_TO_CHECK)).toBe(true)
  })
}) 