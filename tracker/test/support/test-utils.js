import { expect } from "@playwright/test"
import packageJson from '../../package.json' with { type: 'json' }

export const tracker_script_version = packageJson.tracker_script_version

// Mocks an HTTP request call with the given path. Returns a Promise that resolves to the request
// data. If the request is not made, resolves to null after 3 seconds.
export const mockRequest = function (page, path) {
  return new Promise((resolve, _reject) => {
    const requestTimeoutTimer = setTimeout(() => resolve(null), 3000)

    page.route(path, (route, request) => {
      clearTimeout(requestTimeoutTimer)
      resolve(request)
      return route.fulfill({ status: 202, contentType: 'text/plain', body: 'ok' })
    })
  })
}

export const metaKey = function() {
  if (process.platform === 'darwin') {
    return 'Meta'
  } else {
    return 'Control'
  }
}

// Mocks a specified number of HTTP requests with given path. Returns a promise that resolves to a
// list of requests as soon as the specified number of requests is made, or 3 seconds has passed.
export const mockManyRequests = function({ page, path, numberOfRequests, responseDelay, shouldIgnoreRequest, mockRequestTimeout = 3000 }) {
  return new Promise((resolve, _reject) => {
    let requestList = []
    const requestTimeoutTimer = setTimeout(() => resolve(requestList), mockRequestTimeout)

    page.route(path, async (route, request) => {
      const postData = request.postDataJSON()
      if (!shouldIgnoreRequest || !shouldIgnoreRequest(postData)) {
        requestList.push(postData)
      }
      if (responseDelay) {
        await delay(responseDelay)
      }
      if (requestList.length === numberOfRequests) {
        clearTimeout(requestTimeoutTimer)
        resolve(requestList)
      }
      return route.fulfill({ status: 202, contentType: 'text/plain', body: 'ok' })
    })
  })
}

/**
 * A powerful utility function that makes it easy to assert on the event
 * requests that should or should not have been made after doing a page
 * action (e.g. navigating to the page, clicking a page element, etc).
 *
 * @param {Page} page - The Playwright Page object.
 * @param {Object} args - The object configuring the action and related expectations.
 * @param {Function} args.action - A function that returns a promise. The function is called
 *  without arguments, and is `await`ed. This is the action that should or should not trigger
 *  Plausible requests on the page.
 * @param {Array} [args.expectedRequests] - A list of partial JSON payloads that get matched
 *  against the bodies of event requests made. An `expectedRequest` is considered as having
 *  occurred if all of its key-value pairs are found from the JSON body of an event request
 *  that was made. The default value is `[]`
 * @param {Array} [args.refutedRequests] - Same as `expectedRequests` but the opposite. The
 *  expectation passes if none of the made requests match with these partial payloads. Note
 *  that the condition on which a partial payload matches an event request payload is exactly
 *  the same as it is for `expectedRequests`. The default value is `[]`
 * @param {number} [args.awaitedRequestCount] - Sometimes we might want to wait for more events
 *  to happen, just to make sure they didn't. By default, the number of requests we wait for
 *  is `expectedRequests.length + refutedRequests.length`.
 * @param {number} [args.expectedRequestCount] - When provided, expects the total amount of
 *  event requests made to match this number.
 * @param {number} [args.responseDelay] - When provided, delays the response from the Plausible
 *  API by the given number of milliseconds.
 */
export const expectPlausibleInAction = async function (page, {
  action,
  expectedRequests = [],
  refutedRequests = [],
  awaitedRequestCount,
  expectedRequestCount,
  responseDelay,
  shouldIgnoreRequest,
  mockRequestTimeout = 3000
}) {
  const requestsToExpect = expectedRequestCount ? expectedRequestCount : expectedRequests.length
  const requestsToAwait = awaitedRequestCount ? awaitedRequestCount : requestsToExpect + refutedRequests.length

  const plausibleRequestMockList = mockManyRequests({
    page,
    path: '/api/event',
    responseDelay,
    shouldIgnoreRequest,
    numberOfRequests: requestsToAwait,
    mockRequestTimeout: mockRequestTimeout
  })
  await action()
  const requestBodies = await plausibleRequestMockList

  const expectedButNotFoundBodySubsets = []

  expectedRequests.forEach((bodySubset) => {
    const wasFound = requestBodies.some((requestBody) => {
      return includesSubset(requestBody, bodySubset)
    })

    if (!wasFound) {expectedButNotFoundBodySubsets.push(bodySubset)}
  })

  const refutedButFoundRequestBodies = []

  refutedRequests.forEach((bodySubset) => {
    const found = requestBodies.find((requestBody) => {
      return includesSubset(requestBody, bodySubset)
    })

    if (found) {refutedButFoundRequestBodies.push(found)}
  })

  const expectedBodySubsetsErrorMessage = `The following body subsets were not found from the requests that were made:\n\n${JSON.stringify(expectedButNotFoundBodySubsets, null, 4)}\n\nReceived requests with the following bodies:\n\n${JSON.stringify(requestBodies, null, 4)}`
  expect(expectedButNotFoundBodySubsets, expectedBodySubsetsErrorMessage).toHaveLength(0)

  const refutedBodySubsetsErrorMessage = `The following requests were made, but were not expected:\n\n${JSON.stringify(refutedButFoundRequestBodies, null, 4)}`
  expect(refutedButFoundRequestBodies, refutedBodySubsetsErrorMessage).toHaveLength(0)

  expect(requestBodies.length).toBe(requestsToExpect)

  return requestBodies
}

export const ignoreEngagementRequests = function(requestPostData) {
  return requestPostData.n === 'engagement'
}

export const ignorePageleaveRequests = function(requestPostData) {
  return requestPostData.n === 'pageleave'
}

async function toggleTabVisibility(page, hide) {
  await page.evaluate((hide) => {
    Object.defineProperty(document, 'visibilityState', { value: hide ? 'hidden' : 'visible', writable: true })
    Object.defineProperty(document, 'hidden', { value: hide, writable: true })
    document.dispatchEvent(new Event('visibilitychange'))
  }, hide)
}

export const hideCurrentTab = async function(page) {
  return toggleTabVisibility(page, true)
}

export const showCurrentTab = async function(page) {
  return toggleTabVisibility(page, false)
}

async function setFocus(page, focus) {
  await page.evaluate((focus) => {
    Object.defineProperty(document, 'hasFocus', { value: () => focus, writable: true })

    const eventName = focus ? 'focus' : 'blur'
    window.dispatchEvent(new Event(eventName))
  }, focus)
}

export const focus = async function(page) {
  return setFocus(page, true)
}

export const blur = async function(page) {
  return setFocus(page, false)
}

export const hideAndShowCurrentTab = async function(page, options = {}) {
  await hideCurrentTab(page)
  if (options.delay > 0) {
    await delay(options.delay)
  }
  await showCurrentTab(page)
}

export const blurAndFocusPage = async function(page, options = {}) {
  await blur(page)
  if (options.delay > 0) {
    await delay(options.delay)
  }
  await focus(page)
}

// Custom assertion methods for checking plausible request bodies
export const e = {
  stringContaining: (value) => ({
    expected: value,
    __expectation__: (actual) => actual.includes(value)
  })
}

function includesSubset(body, subset) {
  return Object.keys(subset).every((key) => {
    if (typeof subset[key] === 'object' && !subset[key].__expectation__) {
      return typeof body[key] === 'object' && areFlatObjectsEqual(body[key], subset[key])
    } else {
      return checkEqual(body[key], subset[key])
    }
  })
}

// For comparing custom props - all key-value pairs
// must match but the order is not important.
function areFlatObjectsEqual(obj1, obj2) {
  const keys1 = Object.keys(obj1)
  const keys2 = Object.keys(obj2)

  if (keys1.length !== keys2.length) return false;

  return keys1.every(key => checkEqual(obj2[key], obj1[key]))
}

function checkEqual(a, b) {
  if (typeof b === 'object' && b.__expectation__) {
    return b.__expectation__(a)
  }
  return a === b
}

function delay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms))
}
