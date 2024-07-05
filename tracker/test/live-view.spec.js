const { mockRequest, expectCustomEvent } = require('./support/test-utils');
const { expect, test } = require('@playwright/test');

test.describe('script.live-view.js', () => {
    let plausibleRequestMock;

    test.beforeEach(async ({ page }) => {
        plausibleRequestMock = mockRequest(page, '/api/event')
        await page.goto('/live-view.html');
    });

    test('Sends pageview', async ({ page }) => {
        await page.evaluate(() => window.dispatchEvent(new CustomEvent("phx:navigate", { detail: { href: "/navigate" } })))
        const request = await plausibleRequestMock;
        expect(request.postDataJSON().u).toEqual("/navigate")
        expectCustomEvent(request, 'pageview', {})
    });

    test('Sends phx-event', async ({ page }) => {
        await page.evaluate(() => window.liveSocket.socket.logger('push', '_message', { a: 1 }))
        expectCustomEvent(await plausibleRequestMock, 'phx-event', { a: 1 })
    });

    test('Sends submit event', async ({ page }) => {
        await (await page.locator("#main-form-btn")).click()
        expectCustomEvent(await plausibleRequestMock, 'js-submit', { 'user[name]': "name", dom_id: "main-form" })
    });
});
