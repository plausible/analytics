const { expect } = require("@playwright/test");

exports.mockRequest = async function (page, path) {
  return new Promise(async (resolve, reject) => {
    const timer = setTimeout(() => { reject(new Error(`No request to ${path} after 5000 ms`)) }, 5000);

    await page.route(path, (route, request) => {

      clearTimeout(timer);
      resolve(request)

      return route.fulfill({
        status: 202,
        contentType: 'text/plain',
        body: 'ok'
      });
    });
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
