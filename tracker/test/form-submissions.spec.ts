import { test, Page } from "@playwright/test";
import { LOCAL_SERVER_ADDR } from "./support/server";
import {
  expectPlausibleInAction,
  ignoreEngagementRequests,
} from "./support/test-utils";
import { initializePageDynamically } from "./support/initialize-page-dynamically";
import { ScriptConfig } from "./support/types";

const DEFAULT_CONFIG: ScriptConfig = {
  domain: "example.com",
  endpoint: `${LOCAL_SERVER_ADDR}/api/event`,
  local: true,
};

const isViewOrEngagementEvent = ({ n }) =>
  ["pageview", "engagement"].includes(n);

/**
 * This function mitigates test flakiness due to the test runner triggering the submit action
 * before the tracker script has attached the event listener.
 * This flakiness will happen in the real world as well:
 * forms submitted before the tracker script attaches the event listener will not be tracked.
 */
function ensurePlausibleInitialized(page: Page) {
  return page.waitForFunction(() => (window as any).plausible?.l === true);
}

test("does not track form submissions when the feature is disabled", async ({
  page,
}, { testId }) => {
  const { url } = await initializePageDynamically(page, {
    testId,
    scriptConfig: DEFAULT_CONFIG,
    bodyContent: `
      <div>
        <form>
          <input type="text" /><input type="submit" value="Submit" />
        </form>
      </div>
      `,
  });

  await expectPlausibleInAction(page, {
    action: async () => {
      await page.goto(url);
      await page.click('input[type="submit"]');
    },
    shouldIgnoreRequest: ignoreEngagementRequests,
    expectedRequests: [{ n: "pageview" }],
    refutedRequests: [
      {
        n: "Form Submission",
      },
    ],
  });
});

test.describe("form submissions feature is enabled", () => {
  test("tracks forms that use GET method", async ({ page, browserName }, {
    testId,
  }) => {
    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: { ...DEFAULT_CONFIG, formSubmissions: true },
      bodyContent: `
      <div>
        <form method="GET" ${
          // this conditional is needed because fetch with keepalive is not implemented in the version of Firefox used by Playwright:
          // can be removed once the Firefox version is >= v133
          browserName === "firefox"
            ? 'onsubmit="event.preventDefault(); setTimeout(() => {this.submit()}, 200)"'
            : ""
        }>
          <input id="name" type="text" placeholder="Name" /><input type="submit" value="Submit" />
        </form>
      </div>
      `,
    });

    await expectPlausibleInAction(page, {
      action: async () => {
        await page.goto(url);
        await ensurePlausibleInitialized(page);
        await page.fill('input[type="text"]', "Any Name");
        await page.click('input[type="submit"]');
      },
      shouldIgnoreRequest: isViewOrEngagementEvent,
      expectedRequests: [
        {
          n: "Form Submission",
          p: { path: url },
        },
      ],
    });
  });

  test("tracks form submissions triggered with submit button with custom onsubmit", async ({
    page,
  }, { testId }) => {
    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: { ...DEFAULT_CONFIG, formSubmissions: true },
      bodyContent: `
      <div>
        <form onsubmit="event.preventDefault(); console.log('Form submitted')">
          <input type="text" /><input type="submit" value="Submit" />
        </form>
      </div>
      `,
    });

    await expectPlausibleInAction(page, {
      action: async () => {
        await page.goto(url);
        await ensurePlausibleInitialized(page);
        await page.click('input[type="submit"]');
      },
      shouldIgnoreRequest: isViewOrEngagementEvent,
      expectedRequests: [
        {
          n: "Form Submission",
          p: { path: url },
        },
      ],
    });
  });

  test("tracks dynamically inserted forms", async ({ page }, { testId }) => {
    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: { ...DEFAULT_CONFIG, formSubmissions: true },
      bodyContent: `
      <div>
        <button id="dynamicallyInsertForm" onclick="const form = document.createElement('form'); form.onsubmit = (event) => {event.preventDefault(); console.log('Form submitted')}; const submit = document.createElement('input'); submit.type = 'submit'; submit.value = 'Submit'; form.appendChild(submit); document.body.appendChild(form)">Open form</button>
      </div>
      `,
    });

    await expectPlausibleInAction(page, {
      action: async () => {
        await page.goto(url);
        await ensurePlausibleInitialized(page);
        await page.click("button#dynamicallyInsertForm");
        await page.click('input[type="submit"]');
      },
      shouldIgnoreRequest: isViewOrEngagementEvent,
      expectedRequests: [
        {
          n: "Form Submission",
          p: { path: url },
        },
      ],
    });
  });

  test("tracks form submissions that do not pass checkValidity if the form has novalidate attribute", async ({
    page,
  }, { testId }) => {
    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: { ...DEFAULT_CONFIG, formSubmissions: true },
      bodyContent: `
      <div>
        <form novalidate onsubmit="event.preventDefault(); console.log('Form submitted')">
          <input type="email" />
          <input type="submit" value="Submit" />
        </form>
      </div>
      `,
    });

    await expectPlausibleInAction(page, {
      action: async () => {
        await page.goto(url);
        await ensurePlausibleInitialized(page);

        await page.fill('input[type="email"]', "invalid email");
        await page.click('input[type="submit"]');
      },
      shouldIgnoreRequest: isViewOrEngagementEvent,
      expectedRequests: [
        {
          n: "Form Submission",
          p: { path: url },
        },
      ],
    });
  });

  test("does not track form submissions that do not pass checkValidity", async ({
    page,
  }, { testId }) => {
    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: { ...DEFAULT_CONFIG, formSubmissions: true },
      bodyContent: `
      <div>
        <form>
          <input type="email" />
          <input type="submit" value="Submit" />
        </form>
      </div>
      `,
    });

    await expectPlausibleInAction(page, {
      action: async () => {
        await page.goto(url);
        await ensurePlausibleInitialized(page);
        await page.fill('input[type="email"]', "invalid email");
        await page.click('input[type="submit"]');
      },
      shouldIgnoreRequest: ignoreEngagementRequests,
      expectedRequests: [{ n: "pageview" }],
      refutedRequests: [
        {
          n: "Form Submission",
        },
      ],
    });
  });

  test("limitation: does not detect forms submitted using FormElement.submit() method", async ({
    page,
  }, { testId }) => {
    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: { ...DEFAULT_CONFIG, formSubmissions: true },
      bodyContent: `
      <div>
        <form id="form">
          <input type="text" placeholder="Name" />
        </form>
        <button id="trigger-FormElement-submit" onclick="document.getElementById('form').submit()">Submit</button>
      </div>
      `,
    });

    await expectPlausibleInAction(page, {
      action: async () => {
        await page.goto(url);
        await ensurePlausibleInitialized(page);

        await page.click("button#trigger-FormElement-submit");
      },
      shouldIgnoreRequest: ignoreEngagementRequests,
      expectedRequests: [{ n: "pageview" }],
      refutedRequests: [
        {
          n: "Form Submission",
        },
      ],
    });
  });

  test("limitation: tracks _all_ forms on the same page, but _records them indistinguishably_", async ({
    page,
  }, { testId }) => {
    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: { ...DEFAULT_CONFIG, formSubmissions: true },
      bodyContent: `
      <div>
        <form onsubmit="event.preventDefault(); console.log('Form submitted')">
          <h2>Form 1</h2>
          <input type="text" /><input type="submit" value="Submit" />
        </form>
        <form>
          <h2>Form 2</h2>
          <input type="email" />
        </form>
      </div>
      `,
    });

    await expectPlausibleInAction(page, {
      action: async () => {
        await page.goto(url);
        await ensurePlausibleInitialized(page);
        await page.click('input[type="submit"]');
      },
      shouldIgnoreRequest: isViewOrEngagementEvent,
      expectedRequests: [
        {
          n: "Form Submission",
          p: { path: url },
        },
      ],
    });

    await expectPlausibleInAction(page, {
      action: async () => {
        await page.fill('input[type="email"]', "customer@example.com");
        await page.keyboard.press("Enter");
      },
      shouldIgnoreRequest: isViewOrEngagementEvent,
      expectedRequests: [
        {
          n: "Form Submission",
          p: { path: url },
        },
      ],
    });
  });
});
