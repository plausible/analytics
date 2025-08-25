import {
  ensurePlausibleInitialized,
  expectPlausibleInAction,
  isEngagementEvent,
  isPageviewEvent,
  switchByMode
} from './support/test-utils'
import { test, expect } from '@playwright/test'
import { LOCAL_SERVER_ADDR } from './support/server'
import { initializePageDynamically } from './support/initialize-page-dynamically'
import { mockManyRequests } from './support/mock-many-requests'
import { ScriptConfig } from './support/types'
import { customSubmitHandlerStub } from './support/html-fixtures'

const DEFAULT_CONFIG: ScriptConfig = {
  domain: 'example.com',
  endpoint: `${LOCAL_SERVER_ADDR}/api/event`,
  captureOnLocalhost: true
}

for (const mode of ['legacy', 'web'] as const) {
  test.describe(`outbound links, file downloads, tagged events features hierarchy on overlap legacy/v2 parity (${mode})`, () => {
    test('sends only tagged event if the link is a tagged outbound download link', async ({
      page
    }, { testId }) => {
      const downloadUrl = 'https://files.example.com/file.pdf'
      const downloadMock = await mockManyRequests({
        page,
        path: downloadUrl,
        fulfill: {
          status: 200,
          contentType: 'application/pdf',
          body: 'mocked pdf content'
        },
        awaitedRequestCount: 1
      })

      const { url } = await initializePageDynamically(page, {
        testId,
        scriptConfig: switchByMode(
          {
            web: {
              ...DEFAULT_CONFIG,
              autoCapturePageviews: false,
              outboundLinks: true,
              fileDownloads: true
            },
            legacy:
              '<script async src="/tracker/js/plausible.file-downloads.local.manual.outbound-links.tagged-events.js"></script>'
          },
          mode
        ),
        bodyContent: `<a class="plausible-event-name=Custom+Event" href="${downloadUrl}">Outbound Download</a>`
      })
      await page.goto(url)

      await expectPlausibleInAction(page, {
        action: () => page.click('a'),
        expectedRequests: [{ n: 'Custom Event', p: { url: downloadUrl } }],
        awaitedRequestCount: 2
      })

      await expect(downloadMock.getRequestList()).resolves.toHaveLength(1)
    })

    test('sends only outbound link event if the link is an outbound download link', async ({
      page
    }, { testId }) => {
      const downloadUrl = 'https://files.example.com/file.pdf'
      const downloadMock = await mockManyRequests({
        page,
        path: downloadUrl,
        fulfill: {
          status: 200,
          contentType: 'application/pdf',
          body: 'mocked pdf content'
        },
        awaitedRequestCount: 1
      })

      const { url } = await initializePageDynamically(page, {
        testId,
        scriptConfig: switchByMode(
          {
            web: {
              ...DEFAULT_CONFIG,
              autoCapturePageviews: false,
              outboundLinks: true,
              fileDownloads: true
            },
            legacy:
              '<script async src="/tracker/js/plausible.file-downloads.local.manual.outbound-links.tagged-events.js"></script>'
          },
          mode
        ),
        bodyContent: `<a href="${downloadUrl}">Get file</a>`
      })
      await page.goto(url)

      await expectPlausibleInAction(page, {
        action: () => page.click('a'),
        expectedRequests: [
          { n: 'Outbound Link: Click', p: { url: downloadUrl } }
        ],
        awaitedRequestCount: 2
      })
      await expect(downloadMock.getRequestList()).resolves.toHaveLength(1)
    })

    test('sends file download event when local download link is clicked', async ({
      page
    }, { testId }) => {
      const downloadUrl = '/file.pdf'
      const downloadMock = await mockManyRequests({
        page,
        path: downloadUrl,
        fulfill: {
          status: 200,
          contentType: 'application/pdf',
          body: 'mocked pdf content'
        },
        awaitedRequestCount: 1
      })

      const { url } = await initializePageDynamically(page, {
        testId,
        scriptConfig: switchByMode(
          {
            web: {
              ...DEFAULT_CONFIG,
              autoCapturePageviews: false,
              outboundLinks: true,
              fileDownloads: true
            },
            legacy:
              '<script async src="/tracker/js/plausible.file-downloads.local.manual.outbound-links.tagged-events.js"></script>'
          },
          mode
        ),
        bodyContent: `<a href="${downloadUrl}">Get file</a>`
      })
      await page.goto(url)

      await expectPlausibleInAction(page, {
        action: () => page.click('a'),
        expectedRequests: [
          {
            n: 'File Download',
            p: { url: `${LOCAL_SERVER_ADDR}${downloadUrl}` }
          }
        ],
        awaitedRequestCount: 2
      })

      await expect(downloadMock.getRequestList()).resolves.toHaveLength(1)
    })
  })
}

for (const mode of ['web', 'esm'] as const) {
  test.describe(`form submissions and tagged events features hierarchy on overlap v2-specific (${mode})`, () => {
    test('sends only tagged event if a form is tagged', async ({
      page
    }, { testId }) => {
      const config = { ...DEFAULT_CONFIG, formSubmissions: true }
      const { url } = await initializePageDynamically(page, {
        testId,
        scriptConfig: switchByMode(
          {
            web: config,
            esm: `
            <script type="module">
              import { init, track } from '/tracker/js/npm_package/plausible.js';
              init(${JSON.stringify(config)})
              window.plausible = { l: true }
            </script>
          `
          },
          mode
        ),
        bodyContent: `
          <form method="POST" class="plausible-event-name=A+Tagged+Form">
            <input id="name" type="text" placeholder="Name" /><input type="submit" value="Submit" />
          </form>
        `
      })

      await expectPlausibleInAction(page, {
        action: async () => {
          await page.goto(url)
          await ensurePlausibleInitialized(page)
          await page.fill('input[type="text"]', 'Any Name')
          await page.click('input[type="submit"]')
        },
        shouldIgnoreRequest: [isPageviewEvent, isEngagementEvent],
        expectedRequests: [
          {
            n: 'A Tagged Form',
            u: `${LOCAL_SERVER_ADDR}${url}`
          }
        ],
        refutedRequests: [{ n: 'Form: Submission' }],
        mockRequestTimeout: 1000
      })
    })

    test('sends only tagged event if the form parent is tagged', async ({
      page
    }, { testId }) => {
      const config = { ...DEFAULT_CONFIG, formSubmissions: true }
      const { url } = await initializePageDynamically(page, {
        testId,
        scriptConfig: switchByMode(
          {
            web: config,
            esm: `
            <script type="module">
              import { init, track } from '/tracker/js/npm_package/plausible.js';
              init(${JSON.stringify(config)})
              window.plausible = { l: true }
            </script>
          `
          },
          mode
        ),
        bodyContent: `
          <div class="plausible-event-name--A+Tagged+Form">
            <form onsubmit="${customSubmitHandlerStub}">
              <input type="email" />
            </form>
          </div>
        `
      })

      await expectPlausibleInAction(page, {
        action: async () => {
          await page.goto(url)
          await ensurePlausibleInitialized(page)
          await page.fill('input[type="email"]', 'any@example.com')
          await page.press('input[type="email"]', 'Enter')
        },
        shouldIgnoreRequest: [isPageviewEvent, isEngagementEvent],
        expectedRequests: [
          { n: 'A Tagged Form', u: `${LOCAL_SERVER_ADDR}${url}` }
        ],
        refutedRequests: [
          {
            n: 'Form: Submission'
          }
        ],
        mockRequestTimeout: 1000
      })
    })
  })
}
