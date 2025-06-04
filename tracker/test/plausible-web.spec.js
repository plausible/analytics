/*
Tests for plausible-web.js script variant

Unlike in production, we're manually interpolating the script config in this file to
better test the script in isolation of the plausible codebase.
*/

import {
  expectPlausibleInAction,
  e as expecting
} from './support/test-utils'
import { test, expect } from '@playwright/test'
import { LOCAL_SERVER_ADDR } from './support/server'
import { testPlausibleConfiguration, callInit } from './shared-configuration-tests'

const DEFAULT_CONFIG = {
  domain: 'example.com',
  endpoint: `${LOCAL_SERVER_ADDR}/api/event`,
  captureOnLocalhost: true
}

async function openPage(page, config, options = {}) {
  const configJson = JSON.stringify({ ...DEFAULT_CONFIG, ...config })
  let path = `/plausible-web.html?script_config=${configJson}`
  if (options.beforeScriptLoaded) {
    path += `&beforeScriptLoaded=${options.beforeScriptLoaded}`
  }
  if (options.skipPlausibleInit) {
    path += `&skipPlausibleInit=1`
  }
  await page.goto(path)
  await page.waitForFunction('window.plausible !== undefined')
}

test.describe('plausible-web.js', () => {
  testPlausibleConfiguration({
    openPage,
    initPlausible: (page, config) => callInit(page, config, 'window.plausible'),
    fixtureName: 'plausible-web.html',
    fixtureTitle: 'plausible-web.js tests'
  })

  test('with queue code included, respects `plausible` calls made before the script is loaded', async ({ page }) => {
    await expectPlausibleInAction(page, {
      action: () => openPage(page, {}, { beforeScriptLoaded: 'window.plausible("custom-event", { props: { foo: "bar" }, interactive: false })' }),
      expectedRequests: [{ n: 'custom-event', p: { foo: 'bar' }, i: false }, { n: 'pageview' }]
    })
  })

  test('handles double-initialization of the script with a console.warn', async ({ page }) => {
    const consolePromise = page.waitForEvent('console')

    await expectPlausibleInAction(page, {
      action: async () => {
        await openPage(page, {})
        await page.evaluate(() => {
          window.plausible.init()
        })
        await consolePromise
      },
      expectedRequests: [{ n: 'pageview' }]
    })

    const warning = await consolePromise
    expect(warning.type()).toBe("warning")
    expect(warning.text()).toContain('Plausible analytics script was already initialized, skipping init')
  })

  test('handles the script being loaded and initialized multiple times', async ({ page }) => {
    const consolePromise = page.waitForEvent('console')

    await expectPlausibleInAction(page, {
      action: async () => {
        await openPage(page, {})
        await page.evaluate(() => {
          window.includePlausibleScript()
        })
        await consolePromise
      },
      expectedRequests: [{ n: 'pageview' }]
    })

    const warning = await consolePromise
    expect(warning.type()).toBe("warning")
    expect(warning.text()).toContain('Plausible analytics script was already initialized, skipping init')
  })

  test('does not support overriding domain via `init`', async ({ page }) => {
    await expectPlausibleInAction(page, {
      action: async () => {
        await openPage(page, {}, { skipPlausibleInit: true })
        await callInit(page, { domain: 'another-domain.com' }, 'window.plausible')
      },
      expectedRequests: [{ n: 'pageview', d: 'example.com', u: expecting.stringContaining('plausible-web.html') }]
    })
  })
})
