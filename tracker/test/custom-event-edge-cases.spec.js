const { mockRequest, mockManyRequests, expectCustomEvent } = require('./support/test-utils')
const { expect, test } = require('@playwright/test')
const { LOCAL_SERVER_ADDR } = require('./support/server')

test.describe('script.file-downloads.outbound-links.tagged-events.js', () => {
    test('sends only outbound link event when clicked link is both download and outbound', async ({ page }) => {
        await page.goto('/custom-event-edge-case.html')
        const downloadURL = await page.locator('#outbound-download-link').getAttribute('href')

        const plausibleRequestMockList = mockManyRequests(page, '/api/event', 2)
        await page.click('#outbound-download-link')

        const requests = await plausibleRequestMockList
        expect(requests.length).toBe(1)
        expectCustomEvent(requests[0], 'Outbound Link: Click', {url: downloadURL})
    })

    test('sends file download event when local download link clicked', async ({ page }) => {
        await page.goto('/custom-event-edge-case.html')
        const downloadURL = LOCAL_SERVER_ADDR + '/' + await page.locator('#local-download').getAttribute('href')

        const plausibleRequestMock = mockRequest(page, '/api/event')
        await page.click('#local-download')

        expectCustomEvent(await plausibleRequestMock, 'File Download', {url: downloadURL})
    })

    test('sends only tagged event when clicked link is tagged + outbound + download', async ({ page }) => {
        await page.goto('/custom-event-edge-case.html')

        const plausibleRequestMockList = mockManyRequests(page, '/api/event', 3)
        await page.click('#tagged-outbound-download-link')

        const requests = await plausibleRequestMockList
        expect(requests.length).toBe(1)
        expectCustomEvent(requests[0], 'Foo', {})
    })
})
