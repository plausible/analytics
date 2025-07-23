# Plausible Installation Verification API

## How to pass installation verifier without errors

To pass Plausible installation verifier without errors for a site with the domain "example.com", the page served at "https://example.com" must fill the following conditions

### Page is reachable

The page must be reachable within $FETCH_PAGE_TIMEOUT_SECONDS seconds.

### Plausible works as expected

#### Callback

The Promise in the code block below executed in the context of the page must resolve to the type `VerificationSuccess` within $TEST_EVENT_TIMEOUT_SECONDS seconds:

```ts
type VerificationSuccess = {
  plausibleIsOnWindow: true;
  plausibleIsInitialized: true;
  testEventCallbackResult: { status: 200 | 202 };
};

new Promise(async (_resolve) => {
  let plausibleIsOnWindow = !!window.plausible;
  let plausibleIsInitialized = window.plausible?.l;
  let resolved = false;

  function resolve(payload) {
    resolved = true;
    _resolve({
      plausibleIsInitialized,
      plausibleIsOnWindow,
      ...payload,
    });
  }

  const timeout = setTimeout(() => {
    resolve({
      error: "Test event timeout exceeded",
    });
  }, $TEST_EVENT_TIMEOUT_SECONDS * 1000);

  while (!plausibleIsOnWindow) {
    if (window.plausible) {
      plausibleIsOnWindow = true;
    }
  }

  while (!plausibleIsInitialized) {
    if (window.plausible?.l) {
      plausibleIsInitialized = true;
    }
  }

  window.plausible("verification-agent-test", {
    callback: (testEventCallbackResult) => {
      if (resolved) return;
      clearTimeout(timeout);
      resolve({
        testEventCallbackResult,
      });
    },
  });
});
```
