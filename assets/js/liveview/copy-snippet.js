// Copy-to-clipboard behaviour for a readonly textarea holding a code snippet.
// Expects a `[data-snippet]` textarea and a `[data-copy]` button inside the hook
// element. The button labels are swapped through the `data-copied` attribute the
// hook keeps on its root element.

const RESET_DELAY = 2000

const hasSelection = (el) => el.selectionStart !== el.selectionEnd

export default {
  mounted() {
    this.copied = false
    this.snippet = this.el.querySelector('[data-snippet]')

    this.snippet.addEventListener('click', () => {
      if (hasSelection(this.snippet)) return
      this.copyAll()
    })

    this.el
      .querySelector('[data-copy]')
      .addEventListener('click', () => this.copyAll())
  },

  updated() {
    // A server-side patch resets the attribute to its rendered default.
    this.setCopied(this.copied)
  },

  destroyed() {
    clearTimeout(this.resetTimer)
  },

  copyAll() {
    navigator.clipboard.writeText(this.snippet.value).then(() => {
      this.setCopied(true)

      clearTimeout(this.resetTimer)
      this.resetTimer = setTimeout(() => this.setCopied(false), RESET_DELAY)
    })
  },

  setCopied(copied) {
    this.copied = copied
    this.el.dataset.copied = copied
  }
}
