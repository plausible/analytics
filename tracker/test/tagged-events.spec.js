const { test } = require('./support/harness')
const { mockRequest, expectCustomEvent } = require('./support/test-utils')

test.describe('tagged-events extension', () => {
    test('tracks a tagged link click with custom props + url prop', async ({ page }) => {
        await page.goto('/tagged-event.html')

        const linkURL = await page.locator('#link').getAttribute('href')

        const plausibleRequestMock = mockRequest(page, '/api/event')
        await page.click('#link')
        expectCustomEvent(await plausibleRequestMock, 'Payment', { amount: '100', method: "Credit+Card", url: linkURL })
    });
});
