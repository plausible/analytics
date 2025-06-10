import {
  expectPlausibleInAction,
  hideAndShowCurrentTab,
  metaKey,
  mockRequest,
  e as expecting,
  isPageviewEvent,
  isEngagementEvent
} from './support/test-utils'
import { test } from '@playwright/test'

// Wrapper around calling `plausible.init` in the page context for users of `testPlausibleConfiguration`
export async function callInit(page, config, parent) {
  // Stringify the customProperties and transformRequest functions to work around evaluate not being able to serialize functions
  if (config && typeof config.customProperties === 'function') {
    config.customProperties = { "_wrapFunction": config.customProperties.toString() }
  }
  if (config && typeof config.transformRequest === 'function') {
    config.transformRequest = { "_wrapFunction": config.transformRequest.toString() }
  }

  await page.evaluate(({ config, parent }) => {
    if (config && config.customProperties && config.customProperties._wrapFunction) {
      config.customProperties = new Function(`return (${config.customProperties._wrapFunction})`)();
    }
    if (config && config.transformRequest && config.transformRequest._wrapFunction) {
      config.transformRequest = new Function(`return (${config.transformRequest._wrapFunction})`)();
    }
    eval(parent).init(config)
  }, { config, parent })
}

export function testPlausibleConfiguration({ openPage, initPlausible, fixtureName, fixtureTitle }) {
  test.describe('shared configuration tests', () => {
    test.beforeEach(({ page }) => {
      // Mock file download requests
      mockRequest(page, 'https://awesome.website.com/file.pdf')
    })

    test('triggers pageview and engagement automatically', async ({ page }) => {
      await expectPlausibleInAction(page, {
        action: () => openPage(page, {}),
        expectedRequests: [{ n: 'pageview', d: 'example.com', u: expecting.stringContaining(fixtureName)}],
      })

      await expectPlausibleInAction(page, {
        action: () => hideAndShowCurrentTab(page, {delay: 2000}),
        expectedRequests: [{n: 'engagement', d: 'example.com', u: expecting.stringContaining(fixtureName)}],
      })
    })

    test('does not trigger any events when `local` config is disabled', async ({ page }) => {
      await expectPlausibleInAction(page, {
        action: () => openPage(page, { captureOnLocalhost: false }),
        expectedRequests: [],
        refutedRequests: [{ n: 'pageview' }]
      })
    })
    test('does not track pageview props without the feature being enabled', async ({ page }) => {
      await expectPlausibleInAction(page, {
        action: async () => {
          await openPage(page, {})
        },
        expectedRequests: [{ n: 'pageview', p: expecting.toBeUndefined() }],
        shouldIgnoreRequest: isEngagementEvent
      })
    })

    test('does not track outbound links without the feature being enabled', async ({ page, browserName }) => {
      await expectPlausibleInAction(page, {
        action: async () => {
          await openPage(page, {})
          await page.click('#outbound-link')
        },
        expectedRequests: [{ n: 'pageview', p: expecting.toBeUndefined() }],
        refutedRequests: [{ n: 'Outbound Link: Click' }],
        shouldIgnoreRequest: isEngagementEvent
      })
    })

    test('does not track file downloads without feature being enabled', async ({ page }) => {
      await expectPlausibleInAction(page, {
        action: async () => {
          await openPage(page, {})
          await page.click('#file-download', { modifiers: [metaKey()] })
        },
        expectedRequests: [{ n: 'pageview' } ],
        refutedRequests: [{ n: 'File Download' }],
        shouldIgnoreRequest: isEngagementEvent
      })
    })

    test('tracks outbound links (when feature enabled)', async ({ page }) => {
      await expectPlausibleInAction(page, {
        action: async () => {
          await openPage(page, { outboundLinks: true })
          await page.click('#outbound-link')
        },
        expectedRequests: [
          { n: 'pageview', d: 'example.com', u: expecting.stringContaining(fixtureName) },
          { n: 'Outbound Link: Click', d: 'example.com', u: expecting.stringContaining(fixtureName), p: { url: 'https://example.com/' } }
        ],
        shouldIgnoreRequest: isEngagementEvent
      })
    })

    test('tracks file downloads (when feature enabled)', async ({ page }) => {
      await expectPlausibleInAction(page, {
        action: async () => {
          await openPage(page, { fileDownloads: true })
          await page.click('#file-download')
        },
        expectedRequests: [{ n: 'File Download', p: { url: 'https://awesome.website.com/file.pdf' } }],
        shouldIgnoreRequest: [isPageviewEvent, isEngagementEvent]
      })
    })

    test('tracks static custom pageview properties (when feature enabled)', async ({ page }) => {
      await expectPlausibleInAction(page, {
        action: async () => {
          await openPage(page, {}, { skipPlausibleInit: true })
          await initPlausible(page, { customProperties: { "some-prop": "456" } })
        },
        expectedRequests: [{ n: 'pageview', p: { "some-prop": "456" } }]
      })
    })

    test('tracks dynamic custom pageview properties (when feature enabled)', async ({ page }) => {
      await expectPlausibleInAction(page, {
        action: async () => {
          await openPage(page, {}, { skipPlausibleInit: true })
          await initPlausible(page, { customProperties: () => ({ "title": document.title }) })
        },
        expectedRequests: [{ n: 'pageview', p: { "title": fixtureTitle } }]
      })
    })

    test('tracks dynamic custom pageview properties with custom events and engagements', async ({ page }) => {
      await expectPlausibleInAction(page, {
        action: async () => {
          await openPage(page, {}, { skipPlausibleInit: true })
          await initPlausible(page, {
            customProperties: (eventName) => ({ "author": "Uku", "some-prop": "456", [eventName]: "1" })
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
          await initPlausible(page, { customProperties: () => document.title })
        },
        expectedRequests: [{ n: 'pageview', p: expecting.toBeUndefined() }]
      })
    })

    test('invalid customProperties are ignored', async ({ page }) => {
      await expectPlausibleInAction(page, {
        action: async () => {
          await openPage(page, {}, { skipPlausibleInit: true })
          await initPlausible(page, { customProperties: "abcdef" })
        },
        expectedRequests: [{ n: 'pageview', p: expecting.toBeUndefined() }]
      })
    })

    test('autoCapturePageviews=false mode does not track pageviews', async ({ page }) => {
      await expectPlausibleInAction(page, {
        action: async () => {
          await openPage(page, {}, { skipPlausibleInit: true })
          await initPlausible(page, { autoCapturePageviews: false })
          await hideAndShowCurrentTab(page, { delay: 200 })
        },
        expectedRequests: [],
        refutedRequests: [{ n: 'pageview' }, { n: 'engagement' }]
      })
    })

    test('autoCapturePageviews=false mode after manual pageview continues tracking', async ({ page }) => {
      await expectPlausibleInAction(page, {
        action: async () => {
          await openPage(page, {}, { skipPlausibleInit: true })
          await initPlausible(page, { autoCapturePageviews: false })
          await page.click('#manual-pageview')
          await hideAndShowCurrentTab(page, { delay: 200 })
        },
        expectedRequests: [
          { n: 'pageview', u: '/:test-plausible', d: 'example.com' },
          { n: 'engagement', u: '/:test-plausible', d: 'example.com' },
        ],
      })
    })

    test('does not send `h` parameter when `hashBasedRouting` config is disabled', async ({ page }) => {
      await expectPlausibleInAction(page, {
        action: () => openPage(page, {}),
        expectedRequests: [{ n: 'pageview', h: expecting.toBeUndefined() }]
      })
    })

    test('sends `h` parameter when `hash` config is enabled', async ({ page }) => {
      await expectPlausibleInAction(page, {
        action: () => openPage(page, { hashBasedRouting: true }),
        expectedRequests: [{ n: 'pageview', h: 1 }]
      })
    })

    test('tracking tagged events with revenue', async ({ page }) => {
      await expectPlausibleInAction(page, {
        action: async () => {
          await openPage(page, {})
          await page.click('#tagged-event')
        },
        expectedRequests: [{ n: 'Purchase', p: { foo: 'bar' }, $: { currency: 'EUR', amount: '13.32' } }],
        shouldIgnoreRequest: [isPageviewEvent, isEngagementEvent]
      })
    })

    test('supports overriding the endpoint with a custom proxy via `init`', async ({ page }) => {
      await expectPlausibleInAction(page, {
        pathToMock: 'http://proxy.io/endpoint',
        action: async () => {
          await openPage(page, {}, { skipPlausibleInit: true })
          await initPlausible(page, { endpoint: 'http://proxy.io/endpoint' })
        },
        expectedRequests: [{ n: 'pageview', d: 'example.com', u: expecting.stringContaining(fixtureName)}]
      })
    })

    test('supports ignoring requests with `transformRequest`', async ({ page }) => {
      await expectPlausibleInAction(page, {
        action: async () => {
          await openPage(page, {}, { skipPlausibleInit: true })
          await initPlausible(page, { transformRequest: () => null })
          await page.click('#custom-event')
        },
        expectedRequests: [],
        refutedRequests: [{ n: 'Custom event' }, { n: 'pageview' }]
      })
    })

    test('supports modifying the request payload with `transformRequest`', async ({ page }) => {
      const transformRequest = (payload) => {
        payload.p = payload.p || {}
        payload.p.eventName = payload.n
        payload.i = false

        return payload
      }

      await expectPlausibleInAction(page, {
        action: async () => {
          await openPage(page, {}, { skipPlausibleInit: true })
          await initPlausible(page, { transformRequest })
          await page.click('#custom-event')
        },
        expectedRequests: [
          { n: 'pageview', p: { eventName: 'pageview' }, i: false },
          { n: 'Custom event', p: { eventName: 'Custom event', author: 'Karl' }, i: false }
        ]
      })
    })
  })
}
