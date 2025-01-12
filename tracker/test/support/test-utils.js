const { expect } = require("@playwright/test");

// Mocks an HTTP request call with the given path. Returns a Promise that resolves to the request
// data. If the request is not made, resolves to null after 3 seconds.
const mockRequest = function (page, path) {
  return new Promise((resolve, _reject) => {
    const requestTimeoutTimer = setTimeout(() => resolve(null), 3000)

    page.route(path, (route, request) => {
      clearTimeout(requestTimeoutTimer)
      resolve(request)
      return route.fulfill({ status: 202, contentType: 'text/plain', body: 'ok' })
    })
  })
}

exports.mockRequest = mockRequest

exports.metaKey = function() {
  if (process.platform === 'darwin') {
    return 'Meta'
  } else {
    return 'Control'
  }
}

// Mocks a specified number of HTTP requests with given path. Returns a promise that resolves to a
// list of requests as soon as the specified number of requests is made, or 3 seconds has passed.
const mockManyRequests = function(page, path, numberOfRequests) {
  return new Promise((resolve, _reject) => {
    let requestList = []
    const requestTimeoutTimer = setTimeout(() => resolve(requestList), 3000)

    page.route(path, (route, request) => {
      requestList.push(request)
      if (requestList.length === numberOfRequests) {
        clearTimeout(requestTimeoutTimer)
        resolve(requestList)
      }
      return route.fulfill({ status: 202, contentType: 'text/plain', body: 'ok' })
    })
  })
}

exports.mockManyRequests = mockManyRequests

exports.expectCustomEvent = function (request, eventName, eventProps) {
  const payload = request.postDataJSON()

  expect(payload.n).toEqual(eventName)

  for (const [key, value] of Object.entries(eventProps)) {
    expect(payload.p[key]).toEqual(value)
  }
}

/**
 * A powerful utility function that makes it easy to assert on the event
 * requests that should or should not have been made after doing a page
 * action (e.g. navigating to the page, clicking a page element, etc). 
 * 
 * This function accepts subsets of request bodies (the JSON payloads) as
 * arguments, and compares them with the bodies of the requests that were
 * actually made. For a body subset to match a request, all the key-value
 * pairs present in the subset should also appear in the request body.
 */
exports.pageActionAndExpectEventRequests = async function (page, pageActionFn, expectedBodySubsets, refutedBodySubsets = []) {
  const requestsToExpect = expectedBodySubsets.length
  const requestsToAwait = requestsToExpect + refutedBodySubsets.length
  
  const plausibleRequestMockList = mockManyRequests(page, '/api/event', requestsToAwait)
  await pageActionFn()
  const requestBodies = (await plausibleRequestMockList).map(r => r.postDataJSON())

  const expectedButNotFoundBodySubsets = []

  expectedBodySubsets.forEach((bodySubset) => {
    const wasFound = requestBodies.some((requestBody) => {
      return includesSubset(requestBody, bodySubset)
    })

    if (!wasFound) {expectedButNotFoundBodySubsets.push(bodySubset)}
  })

  const refutedButFoundRequestBodies = []

  refutedBodySubsets.forEach((bodySubset) => {
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
}

function includesSubset(body, subset) {
  return Object.keys(subset).every((key) => {
    if (typeof subset[key] === 'object') {
      return typeof body[key] === 'object' && areFlatObjectsEqual(body[key], subset[key])
    } else {
      return body[key] === subset[key]
    }
  })
}

// For comparing custom props - all key-value pairs
// must match but the order is not important.
function areFlatObjectsEqual(obj1, obj2) {
  const keys1 = Object.keys(obj1)
  const keys2 = Object.keys(obj2)

  if (keys1.length !== keys2.length) return false;

  return keys1.every(key => obj2[key] === obj1[key])
}
