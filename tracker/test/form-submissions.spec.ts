import { test } from '@playwright/test'
import { LOCAL_SERVER_ADDR } from './support/server'
import {
  ensurePlausibleInitialized,
  expectPlausibleInAction,
  isEngagementEvent,
  isPageviewEvent
} from './support/test-utils'
import { initializePageDynamically } from './support/initialize-page-dynamically'
import { ScriptConfig } from './support/types'

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
    bodyContent: `
      <form>
        <input type="text" /><input type="submit" value="Submit" />
      </form>
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
  test('tracks forms that use GET method', async ({ page }, {
    testId
  }) => {
    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: { ...DEFAULT_CONFIG, formSubmissions: true },
      bodyContent: `
        <form method="GET">
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
          n: 'Form: Submission',
          p: { path: url }
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
      bodyContent: `
        <form onsubmit="${customSubmitHandlerStub}">
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
          p: { path: url }
        }
      ]
    })
  })

  test('tracks dynamically inserted forms', async ({ page }, { testId }) => {
    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: { ...DEFAULT_CONFIG, formSubmissions: true },
      bodyContent: `
      <div>
        <button id="dynamically-insert-form" onclick="createForm()">Open form</button>
        <script>
          function createForm() {
            const form = document.createElement('form');
            form.setAttribute('onsubmit', "${customSubmitHandlerStub}");
            const submit = document.createElement('input');
            submit.type = 'submit';
            submit.value = 'Submit';
            form.appendChild(submit);
            document.body.appendChild(form);
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
          p: { path: url }
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
      bodyContent: `
        <form novalidate onsubmit="${customSubmitHandlerStub}">
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
          p: { path: url }
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
      bodyContent: `
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
      bodyContent: `
        <form id="form">
          <input type="text" placeholder="Name" />
        </form>
        <button id="trigger-FormElement-submit" onclick="document.getElementById('form').submit()">Submit</button>
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
      bodyContent: `
        <form onsubmit="${customSubmitHandlerStub}">
          <h2>Form 1</h2>
          <input type="text" /><input type="submit" value="Submit" />
        </form>
        <form onsubmit="${customSubmitHandlerStub}">
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
          p: { path: url }
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
          p: { path: url }
        }
      ]
    })
  })
})

/**
 * This is a stub for custom form onsubmit handlers Plausible users may have on their websites.
 * Overriding onsubmit with a custom handler is common practice in web development for a variety of reasons (mostly UX),
 * so it's important to track form submissions from forms with such handlers.
 */
const customSubmitHandlerStub = "event.preventDefault(); console.log('Form submitted')"
