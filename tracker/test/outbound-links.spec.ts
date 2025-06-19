import { initializePageDynamically } from './support/initialize-page-dynamically'
import { mockManyRequests } from './support/mock-many-requests'
import { expectPlausibleInAction, switchByMode } from './support/test-utils'
import { expect, test } from '@playwright/test'
import { ScriptConfig } from './support/types'
import { LOCAL_SERVER_ADDR } from './support/server'

const DEFAULT_CONFIG: ScriptConfig = {
  domain: 'example.com',
  endpoint: `${LOCAL_SERVER_ADDR}/api/event`,
  captureOnLocalhost: true
}

for (const mode of ['legacy', 'web'])
  test.describe(`outbound links feature legacy/v2 parity (${mode})`, () => {
    for (const { clickName, click, skip } of [
      {
        clickName: 'when left clicking on link',
        click: { element: 'a' }
      },
      {
        clickName: 'when left clicking on link with Ctrl or Meta key',
        click: { element: 'a', modifiers: ['ControlOrMeta' as const] },
        skip: (browserName) =>
          test.skip(
            browserName === 'webkit',
            'does not open links with such clicks (works when testing manually in macOS Safari)'
          )
      },
      {
        clickName: 'when left clicking on child element of link',
        click: { element: 'a > h1' }
      }
    ]) {
      test(`sends event ${clickName}`, async ({ page, browserName }, {
        testId
      }) => {
        if (skip) {
          skip(browserName)
        }
        const outboundUrl = 'https://other.example.com/target'
        const outboundMock = await mockManyRequests({
          page,
          path: outboundUrl,
          fulfill: {
            status: 200,
            contentType: 'text/html',
            body: '<!DOCTYPE html><html><head><title>other page</title></head><body>other page</body></html>'
          },
          countOfRequestsToAwait: 1
        })
        const { url } = await initializePageDynamically(page, {
          testId,
          scriptConfig: switchByMode(
            {
              web: {
                ...DEFAULT_CONFIG,
                autoCapturePageviews: false,
                outboundLinks: true
              },
              legacy:
                '<script defer src="/tracker/js/plausible.local.manual.outbound-links.js"></script>'
            },
            mode
          ),
          bodyContent: `<a href="${outboundUrl}"><h1>➡️</h1></a>`
        })
        await page.goto(url)

        await expectPlausibleInAction(page, {
          action: () =>
            page.click(click.element, { modifiers: click.modifiers }),
          expectedRequests: [
            { n: 'Outbound Link: Click', p: { url: outboundUrl } }
          ]
        })

        await expect(outboundMock.getRequestList()).resolves.toHaveLength(1)
      })
    }

    test('tracks links without delaying navigation, relying on fetch options.keepalive to deliver tracking events', async ({
      page
    }, { testId }) => {
      const eventsApiMock = await mockManyRequests({
        page,
        path: '**/api/event',
        countOfRequestsToAwait: 1,
        responseDelay: 500
      })
      const outboundUrl = 'https://other.example.com/target'
      const outboundMock = await mockManyRequests({
        page,
        path: outboundUrl,
        fulfill: {
          status: 200,
          contentType: 'text/html',
          body: '<!DOCTYPE html><html><head><title>other page</title></head><body>other page</body></html>'
        },
        countOfRequestsToAwait: 1
      })
      const { url } = await initializePageDynamically(page, {
        testId,
        scriptConfig: switchByMode(
          {
            web: {
              ...DEFAULT_CONFIG,
              outboundLinks: true,
              autoCapturePageviews: false
            },
            legacy:
              '<script defer src="/tracker/js/plausible.local.manual.outbound-links.js"></script>'
          },
          mode
        ),
        bodyContent: `<a href="${outboundUrl}">>➡️</a>`
      })
      await page.goto(url)
      await page.click('a')
      const [
        { trackingRequestList, trackingResponseTime },
        { downloadMockRequestList, downloadRequestTime }
      ] = await Promise.all([
        eventsApiMock.getRequestList().then((requestList) => ({
          trackingRequestList: requestList,
          trackingResponseTime: Date.now()
        })),
        outboundMock.getRequestList().then((requestList) => ({
          downloadMockRequestList: requestList,
          downloadRequestTime: Date.now()
        }))
      ])

      expect(downloadRequestTime).toBeLessThan(trackingResponseTime)
      expect(downloadMockRequestList).toHaveLength(1)
      expect(trackingRequestList).toEqual([
        expect.objectContaining({
          n: 'Outbound Link: Click',
          p: {
            url: outboundUrl
          }
        })
      ])
    })
  })

test.describe('outbound links feature when using legacy .compat extension', () => {
  test(`tracking delays navigation until the tracking request has finished`, async ({
    page
  }, { testId }) => {
    const eventsApiMock = await mockManyRequests({
      page,
      path: '**/api/event',
      countOfRequestsToAwait: 1,
      responseDelay: 1000
    })
    const outboundUrl = 'https://other.example.com/target'
    const outboundMock = await mockManyRequests({
      page,
      path: outboundUrl,
      fulfill: {
        status: 200,
        contentType: 'text/html',
        body: '<!DOCTYPE html><html><head><title>other page</title></head><body>other page</body></html>'
      },
      countOfRequestsToAwait: 1
    })
    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig:
        '<script id="plausible" defer src="/tracker/js/plausible.compat.local.manual.outbound-links.js"></script>',
      bodyContent: `<a href="${outboundUrl}">📥</a>`
    })
    await page.goto(url)

    const navigationPromise = page.waitForRequest(outboundUrl, {
      timeout: 2000
    })
    const trackingPromise = page.waitForResponse('**/api/event', {
      timeout: 2000
    })

    await page.click('a')
    const [trackingResponseTime, navigationTime] = await Promise.all([
      trackingPromise.then(Date.now),
      navigationPromise.then(Date.now)
    ])
    await expect(page.getByText('other page')).toBeVisible()
    await expect(outboundMock.getRequestList()).resolves.toHaveLength(1)
    expect(trackingResponseTime).toBeLessThanOrEqual(navigationTime)
    await expect(eventsApiMock.getRequestList()).resolves.toEqual([
      expect.objectContaining({
        n: 'Outbound Link: Click',
        p: {
          url: outboundUrl
        }
      })
    ])
  })

  test('if the tracking requests delays navigation for more than 5s, it navigates anyway, without waiting for the request to resolve ', async ({
    page
  }, { testId }) => {
    test.setTimeout(20000)
    await mockManyRequests({
      page,
      path: '**/api/event',
      countOfRequestsToAwait: 1,
      responseDelay: 6000
    })
    const outboundUrl = 'https://other.example.com/target'
    const outboundMock = await mockManyRequests({
      page,
      path: outboundUrl,
      fulfill: {
        status: 200,
        contentType: 'text/html',
        body: '<!DOCTYPE html><html><head><title>other page</title></head><body>other page</body></html>'
      },
      countOfRequestsToAwait: 1
    })
    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig:
        '<script id="plausible" defer src="/tracker/js/plausible.compat.local.manual.outbound-links.js"></script>',
      bodyContent: `<a href="${outboundUrl}">➡️</a>`
    })
    await page.goto(url)
    const navigationPromise = page.waitForRequest(outboundUrl, {
      timeout: 7000
    })
    const trackingPromise = page.waitForResponse('**/api/event', {
      timeout: 7000
    })
    await page.click('a')
    const [trackingResponseTime, navigationTime] = await Promise.all([
      trackingPromise.then(Date.now).catch(Date.now),
      navigationPromise.then(Date.now)
    ])
    await expect(page.getByText('other page')).toBeVisible()
    await expect(outboundMock.getRequestList()).resolves.toHaveLength(1)
    expect(navigationTime).toBeLessThan(trackingResponseTime)
  })

  test('sends event when left clicking on link, but does not navigate if event.preventDefault() has been called on the click event', async ({
    page
  }, { testId }) => {
    const outboundUrl = 'https://other.example.com/target'
    const outboundMock = await mockManyRequests({
      page,
      path: outboundUrl,
      fulfill: {
        status: 200,
        contentType: 'text/html',
        body: '<!DOCTYPE html><html><head><title>other page</title></head><body>other page</body></html>'
      },
      countOfRequestsToAwait: 1
    })
    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig:
        '<script id="plausible" defer src="/tracker/js/plausible.compat.local.manual.outbound-links.js"></script>',
      bodyContent: `<a href="${outboundUrl}">➡️</a><script>document.querySelector('a').addEventListener('click', (e) => {e.preventDefault()})</script>`
    })
    await page.goto(url)

    await expectPlausibleInAction(page, {
      action: () => page.click('a'),
      expectedRequests: [{ n: 'Outbound Link: Click', p: { url: outboundUrl } }]
    })

    await expect(outboundMock.getRequestList()).resolves.toHaveLength(0)
  })

  test('sends event and opens link in new tab if the link has target="__blank"', async ({
    page
  }, { testId }) => {
    const outboundUrl = 'https://other.example.com/target'
    const outboundMock = await mockManyRequests({
      page,
      path: outboundUrl,
      fulfill: {
        status: 200,
        contentType: 'text/html',
        body: '<!DOCTYPE html><html><head><title>other page</title></head><body>other page</body></html>'
      },
      countOfRequestsToAwait: 2
    })
    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig:
        '<script id="plausible" defer src="/tracker/js/plausible.compat.local.manual.outbound-links.js"></script>',
      bodyContent: `<a target="__blank" href="${outboundUrl}">➡️</a>`
    })
    await page.goto(url)

    await expectPlausibleInAction(page, {
      action: () => page.click('a'),
      expectedRequests: [{ n: 'Outbound Link: Click', p: { url: outboundUrl } }]
    })

    await expect(outboundMock.getRequestList()).resolves.toHaveLength(1)
  })
})
