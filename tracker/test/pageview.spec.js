import { mockRequest, tracker_script_version } from './support/test-utils'
import { expect, test } from '@playwright/test'

test.describe('Basic installation', () => {
  test('Sends pageview automatically', async ({ page }) => {
    const plausibleRequestMock = mockRequest(page, '/api/event')
    await page.goto('/simple.html')

    const plausibleRequest = await plausibleRequestMock
    expect(plausibleRequest.url()).toContain('/api/event')
    expect(plausibleRequest.postDataJSON().n).toEqual('pageview')
    expect(plausibleRequest.postDataJSON().v).toEqual(tracker_script_version)
  })
})
