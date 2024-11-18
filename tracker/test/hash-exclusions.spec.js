const { mockRequest } = require('./support/test-utils')
const { expect, test } = require('@playwright/test')

test.describe('combination of hash and exclusions script extensions', () => {
  test('excludes by hash part of the URL', async ({ page }) => {
    const plausibleRequestMock = mockRequest(page, '/api/event')

    await page.goto('/hash-exclusions.html#this/hash/should/be/ignored')

    expect(await plausibleRequestMock, "should not have sent event").toBeNull()
  })
})
