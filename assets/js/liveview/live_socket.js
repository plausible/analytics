/**
  These 3 modules are resolved from '../deps' folder, 
  which does not exist when running the lint command in Github CI 
*/
/* eslint-disable import/no-unresolved */
import 'phoenix_html'
import { Socket } from 'phoenix'
import { LiveSocket } from 'phoenix_live_view'
import topbar from 'topbar'
/* eslint-enable import/no-unresolved */

import Alpine from 'alpinejs'

let csrfToken = document.querySelector("meta[name='csrf-token']")
let websocketUrl = document.querySelector("meta[name='websocket-url']")
if (csrfToken && websocketUrl) {
  let Hooks = {}
  Hooks.Metrics = {
    mounted() {
      this.handleEvent('send-metrics', ({ event_name }) => {
        window.plausible(event_name)
        this.pushEvent('send-metrics-after', { event_name })
      })
    }
  }
  let Uploaders = {}
  Uploaders.S3 = function (entries, onViewError) {
    entries.forEach((entry) => {
      let xhr = new XMLHttpRequest()
      onViewError(() => xhr.abort())
      xhr.onload = () =>
        xhr.status === 200 ? entry.progress(100) : entry.error()
      xhr.onerror = () => entry.error()
      xhr.upload.addEventListener('progress', (event) => {
        if (event.lengthComputable) {
          let percent = Math.round((event.loaded / event.total) * 100)
          if (percent < 100) {
            entry.progress(percent)
          }
        }
      })
      let url = entry.meta.url
      xhr.open('PUT', url, true)
      xhr.send(entry.file)
    })
  }
  let token = csrfToken.getAttribute('content')
  let url = websocketUrl.getAttribute('content')
  let liveUrl = url === '' ? '/live' : new URL('/live', url).href
  let liveSocket = new LiveSocket(liveUrl, Socket, {
    heartbeatIntervalMs: 10000,
    params: { _csrf_token: token },
    hooks: Hooks,
    uploaders: Uploaders,
    dom: {
      // for alpinejs integration
      onBeforeElUpdated(from, to) {
        if (from._x_dataStack) {
          Alpine.clone(from, to)
        }
      }
    }
  })

  topbar.config({
    barColors: { 0: '#303f9f' },
    shadowColor: 'rgba(0, 0, 0, .3)',
    barThickness: 4
  })
  window.addEventListener('phx:page-loading-start', (_info) => topbar.show())
  window.addEventListener('phx:page-loading-stop', (_info) => topbar.hide())

  liveSocket.connect()
  window.liveSocket = liveSocket
}
