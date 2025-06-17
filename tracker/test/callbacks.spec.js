import { test, expect } from '@playwright/test'
import { LOCAL_SERVER_ADDR } from './support/server'

async function openPage(page, src, endpoint = `${LOCAL_SERVER_ADDR}/api/event`) {
  await page.goto(`/callbacks.html?src=${src}&endpoint=${endpoint}`)
}

function trackWithCallback(page) {
  return page.evaluate(() => window.callPlausible())
}

function testCallbacks(trackerScript) {
  const trackerScriptwithoutLocal = trackerScript.replace('.local', '')

  test("on successful request", async ({ page }) => {
    await openPage(page, trackerScript)

    const callbackResult = await trackWithCallback(page)
    expect(callbackResult).toEqual({ status: 202 })
  })

  test('on ignored request', async ({ page }) => {
    await openPage(page, trackerScriptwithoutLocal)

    const callbackResult = await trackWithCallback(page)
    expect(callbackResult).toEqual(undefined)
  })

  test('on 404', async ({ page }) => {
    await openPage(page, trackerScript, `${LOCAL_SERVER_ADDR}/api/404`)

    const callbackResult = await trackWithCallback(page)
    expect(callbackResult).toEqual({ status: 404 })
  })

  test('on network error', async ({ page }) => {
    await openPage(page, trackerScript, `h://bad.url////`)

    const callbackResult = await trackWithCallback(page)
    expect(callbackResult.error).toBeInstanceOf(Error)
  })
}

test.beforeEach(async ({ page }) => {
  await page.route(`${LOCAL_SERVER_ADDR}/api/event`, (route) => {
    return route.fulfill({ status: 202, contentType: 'text/plain', body: 'ok' })
  })
  await page.route(`${LOCAL_SERVER_ADDR}/api/404`, (route) => {
    return route.fulfill({ status: 404, contentType: 'text/plain', body: 'ok' })
  })
})


test.describe("callbacks behavior (with fetch)", () => {
  testCallbacks('/tracker/js/plausible.local.manual.js')
})

test.describe("callbacks behavior (with xhr/compat)", () => {
  testCallbacks('/tracker/js/plausible.compat.local.manual.js')
})
