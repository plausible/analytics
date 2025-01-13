const { pageActionAndExpectEventRequests } = require('./support/test-utils')
const { test } = require('@playwright/test')
const { LOCAL_SERVER_ADDR } = require('./support/server')

test.describe('script.file-downloads.outbound-links.tagged-events.js', () => {
    test('sends only outbound link event when clicked link is both download and outbound', async ({ page }) => {
        await page.goto('/custom-event-edge-case.html')
        const downloadURL = await page.locator('#outbound-download-link').getAttribute('href')

        await pageActionAndExpectEventRequests(page, () => page.click('#outbound-download-link'), [
            {n: 'Outbound Link: Click', p: {url: downloadURL}}
        ])
    })

    test('sends file download event when local download link clicked', async ({ page }) => {
        await page.goto('/custom-event-edge-case.html')
        const downloadURL = LOCAL_SERVER_ADDR + '/' + await page.locator('#local-download').getAttribute('href')

        await pageActionAndExpectEventRequests(page, () => page.click('#local-download'), [
            {n: 'File Download', p: {url: downloadURL}}
        ])
    })

    test('sends only tagged event when clicked link is tagged + outbound + download', async ({ page }) => {
        await page.goto('/custom-event-edge-case.html')

        await pageActionAndExpectEventRequests(
            page,
            () => page.click('#tagged-outbound-download-link'),
            [{n: 'Foo', p: {url: 'https://awesome.website.com/file.pdf'}}],
            [],
            3
        )
    })
})
