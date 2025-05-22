/*
Tests for plausible-web.js script variant

Unlike in production, we're manually interpolating the script config in this file to
better test the script in isolation of the plausible codebase.
*/

import {
  expectPlausibleInAction,
  hideAndShowCurrentTab,
  metaKey,
  mockRequest,
  e as expecting
} from './support/test-utils'
import { test, expect } from '@playwright/test'
import { LOCAL_SERVER_ADDR } from './support/server'

const DEFAULT_CONFIG = {
  domain: 'example.com',
  endpoint: `${LOCAL_SERVER_ADDR}/api/event`,
  local: true
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
  test.beforeEach(({ page }) => {
    // Mock file download requests
    mockRequest(page, 'https://awesome.website.com/file.pdf')
  })

  test('triggers pageview and engagement automatically', async ({ page }) => {
    await expectPlausibleInAction(page, {
      action: () => openPage(page, {}),
      expectedRequests: [{ n: 'pageview', d: 'example.com', u: expecting.stringContaining('plausible-web.html')}]
    })

    await expectPlausibleInAction(page, {
      action: () => hideAndShowCurrentTab(page, {delay: 2000}),
      expectedRequests: [{n: 'engagement', d: 'example.com', u: expecting.stringContaining('plausible-web.html')}],
    })
  })

  test('does not trigger any events when `local` config is disabled', async ({ page }) => {
    await expectPlausibleInAction(page, {
      action: () => openPage(page, { local: false }),
      expectedRequests: [],
      refutedRequests: [{ n: 'pageview' }]
    })
  })

  test('does not track pageview props, outbound links, file downloads or tagged events without features being enabled', async ({ page }) => {
    await expectPlausibleInAction(page, {
      action: async () => {
        await openPage(page, {})
        await page.click('#file-download', { modifiers: [metaKey()] })
        await page.click('#tagged-event')
        await page.click('#outbound-link')
      },
      expectedRequests: [{ n: 'pageview', p: expecting.toBeUndefined() }],
      refutedRequests: [{ n: 'File Download' }, { n: 'Purchase' }, { n: 'Outbound Link: Click' }],
      // Webkit captures engagement events differently, so we ignore them in this test
      shouldIgnoreRequest: (payload) => payload.n === 'engagement'
    })
  })

  test('tracks outbound links (when feature enabled)', async ({ page }) => {
    await expectPlausibleInAction(page, {
      action: async () => {
        await openPage(page, { outboundLinks: true })
        await page.click('#outbound-link')
      },
      expectedRequests: [
        { n: 'pageview', d: 'example.com', u: expecting.stringContaining('plausible-web.html') },
        { n: 'Outbound Link: Click', d: 'example.com', u: expecting.stringContaining('plausible-web.html'), p: { url: 'https://example.com/' } },
      ]
    })
  })

  test('tracks file downloads (when feature enabled)', async ({ page }) => {
    await openPage(page, { fileDownloads: true })

    await expectPlausibleInAction(page, {
      action: () => page.click('#file-download'),
      expectedRequests: [{ n: 'File Download', p: { url: 'https://awesome.website.com/file.pdf' } }],
    })
  })

  test('tracks static custom pageview properties (when feature enabled)', async ({ page }) => {
    await expectPlausibleInAction(page, {
      action: async () => {
        await openPage(page, {}, { skipPlausibleInit: true })
        await page.evaluate(() => {
          plausible.init({ customProperties: { "some-prop": "456" } })
        })
      },
      expectedRequests: [{ n: 'pageview', p: { "some-prop": "456" } }]
    })
  })

  test('tracks dynamic custom pageview properties (when feature enabled)', async ({ page }) => {
    await expectPlausibleInAction(page, {
      action: async () => {
        await openPage(page, {}, { skipPlausibleInit: true })
        await page.evaluate(() => {
          plausible.init({ customProperties: () => ({ "title": document.title }) })
        })
      },
      expectedRequests: [{ n: 'pageview', p: { "title": "plausible-web.js tests" } }]
    })
  })

  test('tracks dynamic custom pageview properties with custom events and engagements', async ({ page }) => {
    await expectPlausibleInAction(page, {
      action: async () => {
        await openPage(page, {}, { skipPlausibleInit: true })
        await page.evaluate(() => {
          plausible.init({
            customProperties: (eventName) => ({ "author": "Uku", "some-prop": "456", [eventName]: "1" })
          })
        })
        await page.click('#custom-event')
        await hideAndShowCurrentTab(page, { delay: 200 })
      },
      expectedRequests: [
        { n: 'pageview', p: { "author": "Uku", "some-prop": "456", "pageview": "1"} },
        // Passed property to `plausible` call overrides the default from `config.customProperties`
        { n: 'Custom event', p: { "author": "Karl", "some-prop": "456", "Custom event": "1" } },
        // Engagement event inherits props from the pageview event
        { n: 'engagement', p: { "author": "Uku", "some-prop": "456", "pageview": "1"} },
      ]
    })
  })

  test('invalid function customProperties are ignored', async ({ page }) => {
    await expectPlausibleInAction(page, {
      action: async () => {
        await openPage(page, {}, { skipPlausibleInit: true })
        await page.evaluate(() => {
          plausible.init({ customProperties: () => document.title })
        })
      },
      expectedRequests: [{ n: 'pageview', p: expecting.toBeUndefined() }]
    })
  })

  test('invalid customProperties are ignored', async ({ page }) => {
    await expectPlausibleInAction(page, {
      action: async () => {
        await openPage(page, {}, { skipPlausibleInit: true })
        await page.evaluate(() => {
          plausible.init({ customProperties: "abcdef" })
        })
      },
      expectedRequests: [{ n: 'pageview', p: expecting.toBeUndefined() }]
    })
  })

  test('manual mode does not track pageviews', async ({ page }) => {
    await expectPlausibleInAction(page, {
      action: async () => {
        await openPage(page, { manual: true })
        await hideAndShowCurrentTab(page, { delay: 200 })
      },
      expectedRequests: [],
      refutedRequests: [{ n: 'pageview' }, { n: 'engagement' }]
    })
  })

  test('manual mode after manual pageview continues tracking', async ({ page }) => {
    await expectPlausibleInAction(page, {
      action: async () => {
        await openPage(page, { manual: true })
        await page.click('#manual-pageview')
        await hideAndShowCurrentTab(page, { delay: 200 })
      },
      expectedRequests: [
        { n: 'pageview', u: '/:test-plausible-web', d: 'example.com' },
        { n: 'engagement', u: '/:test-plausible-web', d: 'example.com' },
      ],
    })
  })

  test('does not send `h` parameter when `hash` config is disabled', async ({ page }) => {
    await expectPlausibleInAction(page, {
      action: () => openPage(page, {}),
      expectedRequests: [{ n: 'pageview', h: expecting.toBeUndefined() }]
    })
  })

  test('sends `h` parameter when `hash` config is enabled', async ({ page }) => {
    await expectPlausibleInAction(page, {
      action: () => openPage(page, { hash: true }),
      expectedRequests: [{ n: 'pageview', h: 1 }]
    })
  })

  test('tracking tagged events (when feature enabled)', async ({ page }) => {
    await openPage(page, { taggedEvents: true })

    await expectPlausibleInAction(page, {
      action: () => page.click('#tagged-event'),
      expectedRequests: [{ n: 'Purchase', p: { foo: 'bar' }, $: expecting.toBeUndefined() }]
    })
  })

  test('tracking tagged events with revenue (when enabled)', async ({ page }) => {
    await openPage(page, { taggedEvents: true, revenue: true })

    await expectPlausibleInAction(page, {
      action: () => page.click('#tagged-event'),
      expectedRequests: [{ n: 'Purchase', p: { foo: 'bar' }, $: { currency: 'EUR', amount: '13.32' } }]
    })
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
        await page.evaluate(() => {
          plausible.init({
            domain: 'another-domain.com'
          })
        })
      },
      expectedRequests: [{ n: 'pageview', d: 'example.com', u: expecting.stringContaining('plausible-web.html') }]
    })
  })

  test('supports overriding the endpoint with a custom proxy via `init`', async ({ page }) => {
    await expectPlausibleInAction(page, {
      pathToMock: 'http://proxy.io/endpoint',
      action: async () => {
        await openPage(page, {}, { skipPlausibleInit: true })
        await page.evaluate(() => {
          plausible.init({
            endpoint: 'http://proxy.io/endpoint'
          })
        })
      },
      expectedRequests: [{ n: 'pageview', d: 'example.com', u: expecting.stringContaining('plausible-web.html')}]
    })
  })
})
