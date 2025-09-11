export function sendRequest(endpoint, payload, options) {
  if (COMPILE_COMPAT) {
    var request = new XMLHttpRequest()
    request.open('POST', endpoint, true)
    request.setRequestHeader('Content-Type', 'text/plain')

    request.send(JSON.stringify(payload))

    request.onreadystatechange = function () {
      if (request.readyState === 4) {
        if (request.status === 0) {
          options &&
            options.callback &&
            options.callback({ error: new Error('Network error') })
        } else {
          options &&
            options.callback &&
            options.callback({ status: request.status })
        }
      }
    }
  } else {
    if (window.fetch) {
      fetch(endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'text/plain'
        },
        keepalive: true,
        body: JSON.stringify(payload)
      })
        .then(function (response) {
          options &&
            options.callback &&
            options.callback({ status: response.status })
        })
        .catch(function (error) {
          options && options.callback && options.callback({ error })
        })
    }
  }
}
