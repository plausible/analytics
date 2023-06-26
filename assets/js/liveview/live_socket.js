import "phoenix_html"
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"

let csrfToken = document.querySelector("meta[name='csrf-token']")
if (csrfToken) {
  let token = csrfToken.getAttribute("content")
  let liveSocket = new LiveSocket("/live", Socket, {
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
