window.addEventListener(`phx:update-value`, (e) => {
  let el = document.getElementById(e.detail.id)
  el.value = e.detail.value
  if (e.detail.fire) {
    el.dispatchEvent(new Event("input", { bubbles: true }))
  }
})

window.addEventListener(`phx:js-exec`, ({ detail }) => {
  document.querySelectorAll(detail.to).forEach(el => {
    window.liveSocket.execJS(el, el.getAttribute(detail.attr))
  })
})

window.addEventListener(`phx:notify-selection-change`, (event) => {
  let el = document.getElementById(event.detail.id)
  el.dispatchEvent(new CustomEvent("selection-change", { detail: event.detail }))
})
