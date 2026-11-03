// An alternative for phoenix_html's `data-confirm`. Currently delegates to
// `window.confirm` just as `data-confirm` does, but can be extended with custom
// styling in the future.

// Unlike `data-confirm` (which uses a window-level click listener), this hook
// intercepts the click on the element itself, so it also works when a listener
// closer to the element acts on the click first - e.g. a Prima listbox selecting
// the clicked option.

export default {
  mounted() {
    this.handleClick = (e) => {
      const message = this.el.dataset.confirmMessage

      if (message && !window.confirm(message)) {
        e.preventDefault()
        e.stopImmediatePropagation()
      }
    }

    this.el.addEventListener('click', this.handleClick, true)
  },

  destroyed() {
    this.el.removeEventListener('click', this.handleClick, true)
  }
}
