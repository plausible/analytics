// Courtesy of Benjamin von Polheim:
// https://blog.devgenius.io/build-a-performat-autocomplete-using-phoenix-liveview-and-alpine-js-8bcbbed17ba7
let suggestionsDropdown = function(id) {
  return {
    isOpen: false,
    id: id,
    open() { this.isOpen = true },
    close() { this.isOpen = false },
    focus: 0,
    setFocus(f) {
      this.focus = f;
    },
    select() {
      this.$refs[`dropdown-${this.id}-option-${this.focus}`]?.click()
      this.focusPrev()
    },
    scrollTo(idx) {
      this.$refs[`dropdown-${this.id}-option-${idx}`]?.scrollIntoView(
        { block: 'nearest', behavior: 'smooth', inline: 'start' }
      )
    },
    focusNext() {
      const nextIndex = this.focus + 1
      const total = this.$refs.suggestions?.childElementCount ?? 0

      if (!this.isOpen) this.open()

      if (nextIndex < total) {
        this.setFocus(nextIndex)
        this.scrollTo(nextIndex);
      }
    },
    focusPrev() {
      const nextIndex = this.focus - 1
      if (this.isOpen && nextIndex >= 0) {
        this.setFocus(nextIndex)
        this.scrollTo(nextIndex)
      }
    },
  }
}

window.suggestionsDropdown = suggestionsDropdown
