import { test, expect } from '@playwright/test'
import { LOCAL_SERVER_ADDR } from './support/server'
import {
  isEngagementEvent,
  expectPlausibleInAction,
  tracker_script_version,
  hideAndShowCurrentTab
} from './support/test-utils'
import { initializePageDynamically } from './support/initialize-page-dynamically'

const DEFAULT_CONFIG = {
  domain: 'example.com',
  endpoint: `${LOCAL_SERVER_ADDR}/api/event`,
  captureOnLocalhost: true
}

test('if `init` is called without domain, it throws', async ({ page }, {
  testId
}) => {
  const { url } = await initializePageDynamically(page, {
    testId,
    scriptConfig: `<script type="module">import { init, track } from "/tracker/js/npm_package/plausible.js"; window.init = init; window.track = track;</script>`,
    bodyContent: 'body'
  })
  await page.goto(url)
  const config = { ...DEFAULT_CONFIG, domain: undefined }
  await expect(
    page.evaluate((config) => (window as any).init(config), { config })
  ).rejects.toThrow('plausible.init(): domain argument is required')
})

test('if `init` is called with no configuration, it throws', async ({ page }, {
  testId
}) => {
  const { url } = await initializePageDynamically(page, {
    testId,
    scriptConfig: `<script type="module">import { init, track } from "/tracker/js/npm_package/plausible.js"; window.init = init; window.track = track;</script>`,
    bodyContent: 'body'
  })
  await page.goto(url)
  await expect(page.evaluate(() => (window as any).init())).rejects.toThrow(
    'plausible.init(): domain argument is required'
  )
})

test('if `track` is called before `init`, it throws', async ({ page }, {
  testId
}) => {
  const { url } = await initializePageDynamically(page, {
    testId,
    scriptConfig: `<script type="module">import { init, track } from "/tracker/js/npm_package/plausible.js"; window.init = init; window.track = track;</script>`,
    bodyContent: 'body'
  })
  await page.goto(url)
  await expect(
    page.evaluate(() => (window as any).track('purchase'))
  ).rejects.toThrow(
    'plausible.track() can only be called after plausible.init()'
  )
})

test('if `init` is called twice, it throws, but tracking still works', async ({
  page
}, { testId }) => {
  const config = { ...DEFAULT_CONFIG }
  const { url } = await initializePageDynamically(page, {
    testId,
    scriptConfig: `<script type="module">import { init, track } from "/tracker/js/npm_package/plausible.js"; window.init = init; init(${JSON.stringify(
      config
    )})</script>`,
    bodyContent: 'body'
  })

  await expectPlausibleInAction(page, {
    action: async () => {
      await page.goto(url)
    },
    expectedRequests: [{ n: 'pageview' }],
    shouldIgnoreRequest: isEngagementEvent
  })

  await expect(
    page.evaluate((config) => (window as any).init(config), config)
  ).rejects.toThrow('plausible.init() can only be called once')

  await expectPlausibleInAction(page, {
    action: async () => {
      await hideAndShowCurrentTab(page, { delay: 200 })
    },
    expectedRequests: [{ n: 'engagement' }]
  })
})

test('`bindToWindow` is true by default, and plausible is attached to window', async ({
  page
}, { testId }) => {
  const config = { ...DEFAULT_CONFIG }
  const { url } = await initializePageDynamically(page, {
    testId,
    scriptConfig: `<script type="module">import { init, track } from "/tracker/js/npm_package/plausible.js"; init(${JSON.stringify(
      config
    )})</script>`,
    bodyContent: 'body'
  })

  await expectPlausibleInAction(page, {
    action: async () => {
      await page.goto(url)
    },
    expectedRequests: [{ n: 'pageview' }]
  })
  await expect(
    page.waitForFunction(() => (window as any).plausible?.l !== undefined)
  ).resolves.toBeTruthy()
  await expect(
    page.evaluate(() => {
      if ((window as any).plausible?.l) {
        return {
          l: (window as any).plausible.l,
          v: (window as any).plausible.v,
          s: (window as any).plausible.s
        }
      }
      return false
    })
  ).resolves.toEqual({ l: true, v: tracker_script_version, s: 'npm' })
})

test('if `bindToWindow` is false, `plausible` is not attached to window', async ({
  page
}, { testId }) => {
  const config = { ...DEFAULT_CONFIG, bindToWindow: false }
  const { url } = await initializePageDynamically(page, {
    testId,
    scriptConfig: `<script type="module">import { init, track } from "/tracker/js/npm_package/plausible.js"; init(${JSON.stringify(
      config
    )})</script>`,
    bodyContent: 'body'
  })

  await expectPlausibleInAction(page, {
    action: async () => {
      await page.goto(url)
    },
    expectedRequests: [{ n: 'pageview' }],
    shouldIgnoreRequest: isEngagementEvent
  })

  await expect(
    page.waitForFunction(
      () => (window as any).plausible !== undefined,
      undefined,
      {
        timeout: 1000
      }
    )
  ).rejects.toThrow('page.waitForFunction: Timeout 1000ms exceeded.')
})

test('allows overriding `endpoint` with a custom URL via `init`', async ({
  page
}, { testId }) => {
  const config = { ...DEFAULT_CONFIG, endpoint: 'http://example.com/event' }
  const { url } = await initializePageDynamically(page, {
    testId,
    scriptConfig: `<script type="module">import { init, track } from "/tracker/js/npm_package/plausible.js"; init(${JSON.stringify(
      config
    )})</script>`,
    bodyContent: 'body'
  })
  await expectPlausibleInAction(page, {
    pathToMock: config.endpoint,
    action: () => page.goto(url),
    expectedRequests: [
      { n: 'pageview', d: config.domain, u: `${LOCAL_SERVER_ADDR}${url}` }
    ],
    shouldIgnoreRequest: isEngagementEvent
  })
})
