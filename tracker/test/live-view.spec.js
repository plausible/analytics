const { mockRequest, expectCustomEvent } = require('./support/test-utils');
const { expect, test } = require('@playwright/test');

test.describe('script.live-view.js events', () => {
    let plausibleRequestMock;

    test.beforeEach(async ({ page }) => {
        plausibleRequestMock = mockRequest(page, '/api/event')
        await page.goto('/live-view.html');
    });

    test('Sends phx-event', async ({ page }) => {
        await page.evaluate(() => window.dispatchEvent(new CustomEvent("phx:page-loading-start", { })))
        expectCustomEvent(await plausibleRequestMock, 'phx-event', {  })
    });

    test('Sends phx-push', async ({ page }) => {
        await page.evaluate(() => window.liveSocket.socket.logger('push', '_message', { a: 1 }))
        expectCustomEvent(await plausibleRequestMock, 'phx-push', { a: 1 })
    });

    test('Sends analyticsParams', async ({ page }) => {
        await page.evaluate(() => {
            window.analyticsParams = { b: 2 };
            window.liveSocket.socket.logger('push', '_message', { a: 1 });
        })
        expectCustomEvent(await plausibleRequestMock, 'phx-push', { a: 1, b: 2 })
    });

    test('Sends submit event', async ({ page }) => {
        await (await page.locator("#main-form-btn")).click()
        expectCustomEvent(await plausibleRequestMock, 'js-submit', { 'user[name]': "name", dom_id: "main-form" })
    });
});

test.describe('script.live-view.js tracking', () => {
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
    
});

test.describe('script.live-view.js moon ds tracking', () => {
    let plausibleRequestMock;

    test.beforeEach(async ({ page }) => {
        plausibleRequestMock = mockRequest(page, '/api/event')
        await page.goto('/live-view-moon-components.html');
    });

    test('Sends data-moon-react-assets-id', async ({ page }) => {
        await page.evaluate(() => window.dispatchEvent(new CustomEvent("data-moon-react-assets-id", { value: "main-form" })))
        const request = await plausibleRequestMock;
        expectCustomEvent(request, 'phx-event', { event: 'data-moon-react-assets-id', value: 'main-form' })
    });
    
});
    
test.describe('script.live-view.js moon icons ds tracking', () => {
    let plausibleRequestMock;

    test.beforeEach(async ({ page }) => {
        plausibleRequestMock = mockRequest(page, '/api/event')
        await page.goto('/live-view-moon-components-4.html');
    });

    test('Sends data-moon-icons-react-id', async ({ page }) => {
        await page.evaluate(() => window.dispatchEvent(new CustomEvent("data-moon-icons-react-id", { value: "main-form-react" })))
        const request = await plausibleRequestMock;
        expectCustomEvent(request, 'phx-event', { event: 'data-moon-icons-react-id', value: 'main-form-react' })
    });
    
});

test.describe('script.live-view.js moon ds elixir tracking', () => {
    let plausibleRequestMock;

    test.beforeEach(async ({ page }) => {
        plausibleRequestMock = mockRequest(page, '/api/event')
        await page.goto('/live-view-moon-components-2.html');
    });

    test('Sends data-moon-elixir-assets-id', async ({ page }) => {
        await page.evaluate(() => window.dispatchEvent(new CustomEvent("data-moon-elixir-assets-id", { value: "main-form-elixir" })))
        const request = await plausibleRequestMock;
        expectCustomEvent(request, 'phx-event', { event: 'data-moon-elixir-assets-id', value: 'main-form-elixir' })
    });
});

test.describe('script.live-view.js moon ds icons tracking', () => {
    let plausibleRequestMock;

    test.beforeEach(async ({ page }) => {
        plausibleRequestMock = mockRequest(page, '/api/event')
        await page.goto('/live-view-moon-components-3.html');
    });

    test('Sends data-moon-icons-id', async ({ page }) => {
        await page.evaluate(() => window.dispatchEvent(new CustomEvent("data-moon-icons-id", { value: "main-form-icon" })))
        const request = await plausibleRequestMock;
        expectCustomEvent(request, 'phx-event', { event: 'data-moon-icons-id', value: 'main-form-icon' })
    });

});