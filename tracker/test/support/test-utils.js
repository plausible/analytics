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

exports.isMac = function (workerInfo) {
  return workerInfo.project.name.includes('OSX')
}

exports.expectCustomEvent = function (request, eventName, eventProps) {
  const payload = request.postDataJSON()

  expect(payload.n).toEqual(eventName)

  for (const [key, value] of Object.entries(eventProps)) {
    expect(payload.p[key]).toEqual(value)
  }
}
