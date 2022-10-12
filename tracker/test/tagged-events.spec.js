const { test } = require('./support/harness')
const { mockRequest, expectCustomEvent } = require('./support/test-utils')

test.describe('tagged-events extension', () => {
    test('tracks a tagged link click', async ({ page }) => {
        await page.goto('/tagged-event.html')
        const plausibleRequestMock = mockRequest(page, '/api/event')
        await page.click('#link')
        expectCustomEvent(await plausibleRequestMock, 'Payment', {})
    });
});
