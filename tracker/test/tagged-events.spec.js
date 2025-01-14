const { mockRequest, metaKey, expectPlausibleInAction } = require('./support/test-utils')
const { expect, test } = require('@playwright/test')

test.describe('tagged-events extension', () => {
    test('tracks a tagged link click with custom props + url prop', async ({ page }) => {
        await page.goto('/tagged-event.html')

        const linkURL = await page.locator('#link').getAttribute('href')

        await expectPlausibleInAction(page, {
            action: () => page.click('#link'),
            expectedRequests: [{n: 'Payment Complete', p: {amount: '100', method: "Credit Card", url: linkURL}}]
        })
    })

    test('tracks a tagged form submit with custom props when submitting by pressing enter', async ({ page }) => {
        await page.goto('/tagged-event.html')

        const submitForm = async function() {
            const inputLocator = page.locator('#form-text-input')
            await inputLocator.fill('some input')
            await inputLocator.press('Enter')
        }

        await expectPlausibleInAction(page, {
            action: submitForm,
            expectedRequests: [{n: 'Signup', p: {type: "Newsletter"}}]
        })
    })

    test('tracks submit on a form with a tagged parent when submit button is clicked', async ({ page }) => {
        await page.goto('/tagged-event.html')

        await expectPlausibleInAction(page, {
            action: () => page.click('#submit-form-with-tagged-parent'),
            expectedRequests: [{n: 'Form Submit', p: {}}],
            awaitedRequestCount: 2,
            expectedRequestCount: 1
        })
    })

    test('tracks click and auxclick on any tagged HTML element', async ({ page }) => {
        await page.goto('/tagged-event.html')

        const expectedRequests = [{n: 'Custom Event', p: { foo: "bar" }}]

        await expectPlausibleInAction(page, {
            action: () => page.click('#button'),
            expectedRequests
        })

        await expectPlausibleInAction(page, {
            action: () => page.click('#span'),
            expectedRequests
        })

        await expectPlausibleInAction(page, {
            action: () => page.click('#div', { modifiers: [metaKey()] }),
            expectedRequests
        })
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

        const expectedRequests = [
            {n: 'Custom Event', p: { foo: "bar", url: "https://awesome.website.com/payment/"}}
        ]

        await expectPlausibleInAction(page, {
            action: () => page.click('#h2-with-link-parent', { modifiers: [metaKey()] }),
            expectedRequests
        })

        await expectPlausibleInAction(page, {
            action: () => page.click('#link-with-div-parent'),
            expectedRequests
        })
    })

    test('tracks tagged element that is dynamically added to the DOM', async ({ page }) => {
        await page.goto('/tagged-event.html')

        const buttonLocator = page.locator('#dynamic-tagged-button')
        await buttonLocator.waitFor({state: 'visible'})

        await expectPlausibleInAction(page, {
            action: () => buttonLocator.click(),
            expectedRequests: [{n: 'Custom Event', p: {}}]
        })
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
