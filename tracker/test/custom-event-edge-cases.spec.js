const { expect } = require('@playwright/test');
const { test } = require('./support/harness')
const { mockRequest, mockManyPlausibleRequests } = require('./support/test-utils')

test('sends file download and outbound link event at the same time and navigates', async ({ page }) => {
    await page.goto('/custom-event-edge-case.html')
    const linkURL = await page.locator('#link').getAttribute('href')

    const plausibleRequestMockList = mockManyPlausibleRequests(page, 2)
    const navigationRequestMock = mockRequest(page, linkURL)

    await page.click('#link')

    const sentEventNames = await plausibleRequestMockList
    expect(sentEventNames).toEqual(expect.arrayContaining(['Outbound Link: Click', 'File Download']))

    expect((await navigationRequestMock).url()).toContain(linkURL)
});

test('sends file download and outbound link event at the same time and does not navigate if default externally prevented', async ({ page }) => {
    await page.goto('/custom-event-edge-case.html')
    const linkURL = await page.locator('#link-default-prevented').getAttribute('href')

    const plausibleRequestMockList = mockManyPlausibleRequests(page, 2)
    const navigationRequestMock = mockRequest(page, linkURL)

    await page.click('#link-default-prevented')

    const sentEventNames = await plausibleRequestMockList
    expect(sentEventNames).toEqual(expect.arrayContaining(['Outbound Link: Click', 'File Download']))

    expect(await navigationRequestMock, "should not have made navigation request").toBeNull()
});
