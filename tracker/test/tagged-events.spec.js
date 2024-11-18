const { mockRequest, mockManyRequests, expectCustomEvent, metaKey } = require('./support/test-utils')
const { expect, test } = require('@playwright/test')

test.describe('tagged-events extension', () => {
    test('tracks a tagged link click with custom props + url prop', async ({ page }) => {
        await page.goto('/tagged-event.html')

        const linkURL = await page.locator('#link').getAttribute('href')

        const plausibleRequestMock = mockRequest(page, '/api/event')
        await page.click('#link')
        expectCustomEvent(await plausibleRequestMock, 'Payment Complete', { amount: '100', method: "Credit Card", url: linkURL })
    })

    test('tracks a tagged form submit with custom props when submitting by pressing enter', async ({ page }) => {
        await page.goto('/tagged-event.html')
        const plausibleRequestMock = mockRequest(page, '/api/event')

        const inputLocator = page.locator('#form-text-input')
        await inputLocator.type('some input')
        await inputLocator.press('Enter')

        expectCustomEvent(await plausibleRequestMock, 'Signup', { type: "Newsletter" })
    })

    test('tracks submit on a form with a tagged parent when submit button is clicked', async ({ page }) => {
        await page.goto('/tagged-event.html')

        const plausibleRequestMockList = mockManyRequests(page, '/api/event', 2)

        await page.click('#submit-form-with-tagged-parent')

        const requests = await plausibleRequestMockList

        expect(requests.length).toBe(1)
        expectCustomEvent(requests[0], "Form Submit", {})
    })

    test('tracks click and auxclick on any tagged HTML element', async ({ page }) => {
        await page.goto('/tagged-event.html')

        const plausibleRequestMockList = mockManyRequests(page, '/api/event', 3)

        await page.click('#button')
        await page.click('#span')
        await page.click('#div', { modifiers: [metaKey()] })

        const requests = await plausibleRequestMockList
        expect(requests.length).toBe(3)
        requests.forEach(request => expectCustomEvent(request, 'Custom Event', { foo: "bar" }))
    })

    test('does not track elements without plausible-event-name class + link elements navigate', async ({ page }) => {
        await page.goto('/tagged-event.html')
        const linkLocator = page.locator('#not-tracked-link')

        const linkURL = await linkLocator.getAttribute('href')

        const plausibleRequestMock = mockRequest(page, '/api/event')
        const navigationRequestMock = mockRequest(page, linkURL)

        await page.click('#not-tracked-button')
        await page.click('#not-tracked-span')
        await linkLocator.click()

        expect(await plausibleRequestMock, "should not have made Plausible request").toBeNull()
        expect((await navigationRequestMock).url()).toContain(linkURL)
    })

    test('tracks tagged HTML elements when their child element is clicked', async ({ page }) => {
        await page.goto('/tagged-event.html')

        const plausibleRequestMockList = mockManyRequests(page, '/api/event', 2)

        await page.click('#h2-with-link-parent', { modifiers: [metaKey()] })
        await page.click('#link-with-div-parent')

        const requests = await plausibleRequestMockList
        expect(requests.length).toBe(2)
        requests.forEach(request => expectCustomEvent(request, 'Custom Event', { foo: "bar" }))
    })

    test('tracks tagged element that is dynamically added to the DOM', async ({ page }) => {
        await page.goto('/tagged-event.html')

        const plausibleRequestMock = mockRequest(page, '/api/event')

        const buttonLocator = page.locator('#dynamic-tagged-button')
        await buttonLocator.waitFor({state: 'visible'})
        await page.waitForTimeout(500)

        await buttonLocator.click()

        expectCustomEvent(await plausibleRequestMock, 'Custom Event', {})
    })

    test('does not track clicks inside a tagged form, except submit click', async ({ page }) => {
        await page.goto('/tagged-event.html')

        const plausibleRequestMock = mockRequest(page, '/api/event')

        await page.click('#form')
        await page.click('#form-input')
        await page.click('#form-div')

        expect(await plausibleRequestMock, "should not have made Plausible request").toBeNull()
    })
})
