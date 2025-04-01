import 'phoenix_html'
import { Socket } from 'phoenix'
import { LiveSocket } from 'phoenix_live_view'
import Alpine from 'alpinejs'

let csrfToken = document.querySelector("meta[name='csrf-token']")
let websocketUrl = document.querySelector("meta[name='websocket-url']")
if (csrfToken && websocketUrl) {
  let Hooks = {}
  Hooks.Metrics = {
    mounted() {
      this.handleEvent('send-metrics', ({ event_name }) => {
        const afterMetrics = () => {
          this.pushEvent('send-metrics-after', { event_name })
        }
        setTimeout(afterMetrics, 5000)
        if (window.trackCustomEvent) {
          window.trackCustomEvent(event_name, { callback: afterMetrics })
        }
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

  liveSocket.connect()
  window.liveSocket = liveSocket
}
