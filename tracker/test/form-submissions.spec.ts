import { test } from '@playwright/test'
import { LOCAL_SERVER_ADDR } from './support/server'
import {
  e,
  ensurePlausibleInitialized,
  expectPlausibleInAction,
  isEngagementEvent,
  isPageviewEvent
} from './support/test-utils'
import { initializePageDynamically } from './support/initialize-page-dynamically'
import { ScriptConfig } from './support/types'
import { customSubmitHandlerStub } from './support/html-fixtures'

const DEFAULT_CONFIG: ScriptConfig = {
  domain: 'example.com',
  endpoint: `${LOCAL_SERVER_ADDR}/api/event`,
  captureOnLocalhost: true
}

test('does not track form submissions when the feature is disabled', async ({
  page
}, { testId }) => {
  const { url } = await initializePageDynamically(page, {
    testId,
    scriptConfig: DEFAULT_CONFIG,
    bodyContent: /* HTML */ `
      <form><input type="text" /><input type="submit" value="Submit" /></form>
    `
  })

  await expectPlausibleInAction(page, {
    action: async () => {
      await page.goto(url)
      await page.click('input[type="submit"]')
    },
    shouldIgnoreRequest: isEngagementEvent,
    expectedRequests: [{ n: 'pageview' }],
    refutedRequests: [
      {
        n: 'Form: Submission'
      }
    ]
  })
})

test.describe('form submissions feature is enabled', () => {
  test('tracks forms that use GET method', async ({ page }, { testId }) => {
    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: { ...DEFAULT_CONFIG, formSubmissions: true },
      bodyContent: /* HTML */ `
        <form method="GET">
          <input id="name" type="text" placeholder="Name" /><input
            type="submit"
            value="Submit"
          />
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
          n: 'Form: Submission',
          u: `${LOCAL_SERVER_ADDR}${url}`,
          p: e.toBeUndefined()
        }
      ]
    })
  })

  test('tracks form submissions triggered with submit button with custom onsubmit', async ({
    page
  }, { testId }) => {
    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: { ...DEFAULT_CONFIG, formSubmissions: true },
      bodyContent: /* HTML */ `
        <form onsubmit=${customSubmitHandlerStub}>
          <input type="text" /><input type="submit" value="Submit" />
        </form>
      `
    })

    await expectPlausibleInAction(page, {
      action: async () => {
        await page.goto(url)
        await ensurePlausibleInitialized(page)
        await page.click('input[type="submit"]')
      },
      shouldIgnoreRequest: [isPageviewEvent, isEngagementEvent],
      expectedRequests: [
        {
          n: 'Form: Submission',
          u: `${LOCAL_SERVER_ADDR}${url}`,
          p: e.toBeUndefined()
        }
      ]
    })
  })

  test('tracks dynamically inserted forms', async ({ page }, { testId }) => {
    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: { ...DEFAULT_CONFIG, formSubmissions: true },
      bodyContent: /* HTML */ `
        <div>
          <button id="dynamically-insert-form" onclick="createForm()">
            Open form
          </button>
          <script>
            function createForm() {
              const form = document.createElement('form')
              /* prettier-ignore */
              form.onsubmit = ${customSubmitHandlerStub}
              const submit = document.createElement('input')
              submit.type = 'submit'
              submit.value = 'Submit'
              form.appendChild(submit)
              document.body.appendChild(form)
            }
          </script>
        </div>
      `
    })

    await expectPlausibleInAction(page, {
      action: async () => {
        await page.goto(url)
        await ensurePlausibleInitialized(page)
        await page.click('button#dynamically-insert-form')
        await page.click('input[type="submit"]')
      },
      shouldIgnoreRequest: [isPageviewEvent, isEngagementEvent],
      expectedRequests: [
        {
          n: 'Form: Submission',
          u: `${LOCAL_SERVER_ADDR}${url}`,
          p: e.toBeUndefined()
        }
      ]
    })
  })

  test('tracks form submissions that do not pass checkValidity if the form has novalidate attribute', async ({
    page
  }, { testId }) => {
    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: { ...DEFAULT_CONFIG, formSubmissions: true },
      bodyContent: /* HTML */ `
        <form novalidate onsubmit=${customSubmitHandlerStub}>
          <input type="email" />
          <input type="submit" value="Submit" />
        </form>
      `
    })

    await expectPlausibleInAction(page, {
      action: async () => {
        await page.goto(url)
        await ensurePlausibleInitialized(page)

        await page.fill('input[type="email"]', 'invalid email')
        await page.click('input[type="submit"]')
      },
      shouldIgnoreRequest: [isPageviewEvent, isEngagementEvent],
      expectedRequests: [
        {
          n: 'Form: Submission',
          u: `${LOCAL_SERVER_ADDR}${url}`,
          p: e.toBeUndefined()
        }
      ]
    })
  })

  test('does not track form submissions that do not pass checkValidity', async ({
    page
  }, { testId }) => {
    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: { ...DEFAULT_CONFIG, formSubmissions: true },
      bodyContent: /* HTML */ `
        <form>
          <input type="email" />
          <input type="submit" value="Submit" />
        </form>
      `
    })

    await expectPlausibleInAction(page, {
      action: async () => {
        await page.goto(url)
        await ensurePlausibleInitialized(page)
        await page.fill('input[type="email"]', 'invalid email')
        await page.click('input[type="submit"]')
      },
      shouldIgnoreRequest: isEngagementEvent,
      expectedRequests: [{ n: 'pageview' }],
      refutedRequests: [
        {
          n: 'Form: Submission'
        }
      ]
    })
  })

  test('limitation: does not detect forms submitted using FormElement.submit() method', async ({
    page
  }, { testId }) => {
    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: { ...DEFAULT_CONFIG, formSubmissions: true },
      bodyContent: /* HTML */ `
        <form id="form">
          <input type="text" placeholder="Name" />
        </form>
        <button
          id="trigger-FormElement-submit"
          onclick="document.getElementById('form').submit()"
        >
          Submit
        </button>
      `
    })

    await expectPlausibleInAction(page, {
      action: async () => {
        await page.goto(url)
        await ensurePlausibleInitialized(page)

        await page.click('button#trigger-FormElement-submit')
      },
      shouldIgnoreRequest: isEngagementEvent,
      expectedRequests: [{ n: 'pageview' }],
      refutedRequests: [
        {
          n: 'Form: Submission'
        }
      ]
    })
  })

  test('limitation: tracks _all_ forms on the same page, but _records them indistinguishably_', async ({
    page
  }, { testId }) => {
    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: { ...DEFAULT_CONFIG, formSubmissions: true },
      bodyContent: /* HTML */ `
        <form onsubmit=${customSubmitHandlerStub}>
          <h2>Form 1</h2>
          <input type="text" /><input type="submit" value="Submit" />
        </form>
        <form onsubmit=${customSubmitHandlerStub}>
          <h2>Form 2</h2>
          <input type="email" />
        </form>
      `
    })

    await expectPlausibleInAction(page, {
      action: async () => {
        await page.goto(url)
        await ensurePlausibleInitialized(page)
        await page.click('input[type="submit"]')
      },
      shouldIgnoreRequest: [isPageviewEvent, isEngagementEvent],
      expectedRequests: [
        {
          n: 'Form: Submission',
          u: `${LOCAL_SERVER_ADDR}${url}`,
          p: e.toBeUndefined()
        }
      ]
    })

    await expectPlausibleInAction(page, {
      action: async () => {
        await page.fill('input[type="email"]', 'customer@example.com')
        await page.keyboard.press('Enter')
      },
      shouldIgnoreRequest: [isPageviewEvent, isEngagementEvent],
      expectedRequests: [
        {
          n: 'Form: Submission',
          u: `${LOCAL_SERVER_ADDR}${url}`,
          p: e.toBeUndefined()
        }
      ]
    })
  })
})
