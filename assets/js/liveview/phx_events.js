window.addEventListener(`phx:update-value`, (e) => {
  let el = document.getElementById(e.detail.id)
  el.value = e.detail.value
  if (e.detail.fire) {
    el.dispatchEvent(new Event("input", { bubbles: true }))
  }
})
