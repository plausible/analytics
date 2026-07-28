// Copy-to-clipboard behaviour for a readonly textarea holding a code snippet.
// Expects an `x-ref="snippet"` textarea within the same `x-data` scope.

const RESET_DELAY = 2000

const hasSelection = (el) => el.selectionStart !== el.selectionEnd

const isFullySelected = (el) =>
  el.selectionStart === 0 && el.selectionEnd === el.value.length

export default () => ({
  copied: false,
  copyAll() {
    const el = this.$refs.snippet
    el.focus()
    el.select()
    document.execCommand('copy')
    this.copied = true

    setTimeout(() => {
      this.copied = false

      // Leave it alone if the user has highlighted their own text since.
      if (isFullySelected(el)) {
        el.setSelectionRange(0, 0)
        el.blur()
      }
    }, RESET_DELAY)
  },
  copyIfNoSelection() {
    if (hasSelection(this.$refs.snippet)) return
    this.copyAll()
  }
})
