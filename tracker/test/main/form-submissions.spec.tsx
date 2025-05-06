import { test, Page } from '@playwright/test'
import { LOCAL_SERVER_ADDR } from '../support/server'
import {
  expectPlausibleInAction,
} from '../support/test-utils'

const DEFAULT_CONFIG = {
  domain: 'example.com',
  endpoint: `${LOCAL_SERVER_ADDR}/api/event`,
  local: true
}

type Options = {
  hash: boolean
  local: boolean
  exclusions: boolean
  manual: boolean
  revenue: boolean
  pageviewProps: boolean
  outboundLinks: boolean
  fileDownloads: boolean
  taggedEvents: boolean
  trackFormSubmissions: boolean
}

type ScriptConfig = {
  domain: string
  endpoint: string
} & Partial<Options>

function initialize(page: Page) {
  return ({
    scriptConfig,
    bodyContent
  }: {
    scriptConfig: ScriptConfig
    bodyContent: string
  }) =>
    page.addInitScript(
      ({ scriptConfig, bodyContent }) => {
        window.addEventListener('load', function () {
          const scriptElement = this.document.createElement('script')
          scriptElement.setAttribute(
            'src',
            `/tracker/js/plausible-main.js?script_config=${encodeURIComponent(
              JSON.stringify(scriptConfig)
            )}`
          )
          scriptElement.setAttribute('defer', '')
          this.document.body.appendChild(scriptElement)

          const contentElement = this.document.createElement('div')
          contentElement.innerHTML = bodyContent
          this.document.body.appendChild(contentElement)
        })
      },
      { scriptConfig, bodyContent }
    )
}

test('does not track form submissions when trackFormSubmissions is disabled', async ({
  page
}, { testId }) => {
  await initialize(page)({
    scriptConfig: DEFAULT_CONFIG,
    bodyContent: `
      <div>
        <form onsubmit="event.preventDefault(); console.log('Form submitted')">
          <input type="name"></input><input type="submit" value="Submit" />
        </form>
      </div>
      `
  })

  await expectPlausibleInAction(page, {
    action: async () => {
      await page.goto(`/dynamic/${testId}`)
      await page.click('input[type="submit"]')
    },
    shouldIgnoreRequest: ({ n }) => ['pageview', 'engagement'].includes(n),
    refutedRequests: [
      {
        n: 'WP Form Completions'
      }
    ]
  })
})

test('tracks form submissions triggered with submit button when trackFormSubmissions is enabled', async ({
  page
}, { testId }) => {
  console.log(testId)
  await initialize(page)({
    scriptConfig: { ...DEFAULT_CONFIG, trackFormSubmissions: true },
    bodyContent: `
      <div>
        <form onsubmit="event.preventDefault(); console.log('Form submitted')">
          <input type="name"></input><input type="submit" value="Submit" />
        </form>
      </div>
      `
  })

  await expectPlausibleInAction(page, {
    action: async () => {
      await page.goto(`/dynamic/${testId}`)
      await page.click('input[type="submit"]')
    },
    shouldIgnoreRequest: ({ n }) => ['pageview', 'engagement'].includes(n),
    expectedRequests: [
      {
        n: 'WP Form Completions',
        p: { path: `/dynamic/${testId}` }
      }
    ]
  })
})

test('tracks _all_ forms on the same page, _recording them indistinguishably_, when trackFormSubmissions is enabled', async ({
  page
}, { testId }) => {
  console.log(testId)
  await initialize(page)({
    scriptConfig: { ...DEFAULT_CONFIG, trackFormSubmissions: true },
    bodyContent: `
      <div>
        <form onsubmit="event.preventDefault(); console.log('Form submitted')">
          <h2>Form 1</h2>
          <input type="name"></input><input type="submit" value="Submit" />
        </form>
        <form onsubmit="event.preventDefault(); console.log('Form submitted')">
          <h2>Form 2</h2>
          <input type="email"></input>
        </form>
      </div>
      `
  })

  await expectPlausibleInAction(page, {
    action: async () => {
      await page.goto(`/dynamic/${testId}`)
      await page.click('input[type="submit"]')
    },
    shouldIgnoreRequest: ({ n }) => ['pageview', 'engagement'].includes(n),
    expectedRequests: [
      {
        n: 'WP Form Completions',
        p: { path: `/dynamic/${testId}` }
      }
    ]
  })

  await expectPlausibleInAction(page, {
    action: async () => {
      await page.fill('input[type="email"]', "customer@example.com")
      await page.keyboard.press('Enter')
    },
    shouldIgnoreRequest: ({ n }) => ['pageview', 'engagement'].includes(n),
    expectedRequests: [
      {
        n: 'WP Form Completions',
        p: { path: `/dynamic/${testId}` }
      }
    ]
  })

})
