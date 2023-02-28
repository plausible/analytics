const { expect } = require("@playwright/test");

// Mocks an HTTP request call with the given path. Returns a Promise that resolves to the request
// data. If the request is not made, resolves to null after 10 seconds.
exports.mockRequest = function (page, path) {
  return new Promise((resolve, _reject) => {
    const requestTimeoutTimer = setTimeout(() => resolve(null), 10000)

    page.route(path, (route, request) => {
      clearTimeout(requestTimeoutTimer)
      resolve(request)
      return route.fulfill({ status: 202, contentType: 'text/plain', body: 'ok' })
    })
  })
}

exports.metaKey = function() {
  if (process.platform === 'darwin') {
    return 'Meta'
  } else {
    return 'Control'
  }
}

// Mocks a specified number of HTTP requests with given path. Returns a promise that resolves to a
// list of requests as soon as the specified number of requests is made, or 10 seconds has passed.
exports.mockManyRequests = function(page, path, numberOfRequests) {
  return new Promise((resolve, _reject) => {
    let requestList = []
    const requestTimeoutTimer = setTimeout(() => resolve(requestList), 10000)

    page.route('/api/event', (route, request) => {
      requestList.push(request)
      if (requestList.length === numberOfRequests) {
        clearTimeout(requestTimeoutTimer)
        resolve(requestList)
      }
      return route.fulfill({ status: 202, contentType: 'text/plain', body: 'ok' })
    })
  })
}

exports.expectCustomEvent = function (request, eventName, eventProps) {
  const payload = request.postDataJSON()

  expect(payload.n).toEqual(eventName)

  for (const [key, value] of Object.entries(eventProps)) {
    expect(payload.p[key]).toEqual(value)
  }
}
