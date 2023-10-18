import "phoenix_html"
import Alpine from 'alpinejs'
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"

let csrfToken = document.querySelector("meta[name='csrf-token']")
let websocketUrl = document.querySelector("meta[name='websocket-url']")
if (csrfToken && websocketUrl) {
  let Hooks = {}
  Hooks.Metrics = {
    mounted() {
      this.handleEvent("send-metrics", ({ event_name, params }) => {
        const afterMetrics = () => {
          this.pushEvent("send-metrics-after", {event_name, params})
        }
        setTimeout(afterMetrics, 5000)
        params.callback = afterMetrics
        window.plausible(event_name, params)
      })
    }
  }
  let token = csrfToken.getAttribute("content")
  let url = websocketUrl.getAttribute("content")
  let liveUrl = (url === "") ? "/live" : new URL("/live", url).href;
  let liveSocket = new LiveSocket(liveUrl, Socket, {
    heartbeatIntervalMs: 10000,
    params: { _csrf_token: token }, hooks: Hooks, dom: {
      // for alpinejs integration
      onBeforeElUpdated(from, to) {
        if (from._x_dataStack) {
          Alpine.clone(from, to);
        }
      },
    }
  })

  liveSocket.connect()
  window.liveSocket = liveSocket
}
