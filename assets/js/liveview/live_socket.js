import "phoenix_html"
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"

let csrfToken = document.querySelector("meta[name='csrf-token']")
let websocketUrl = document.querySelector("meta[name='websocket-url']")
if (csrfToken && websocketUrl) {
  let token = csrfToken.getAttribute("content")
  let url = websocketUrl.getAttribute("content")
  let liveUrl = (url === "") ? "/live" : new URL("/live", url).href;
  let liveSocket = new LiveSocket(liveUrl, Socket, {
    heartbeatIntervalMs: 10000,
    params: { _csrf_token: token }, hooks: {}, dom: {
      // for alpinejs integration
      onBeforeElUpdated(from, to) {
        if (from.__x) {
          window.Alpine.clone(from.__x, to);
        }
      },
    }
  })

  liveSocket.connect()
  window.liveSocket = liveSocket
}
