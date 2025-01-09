/** @format */

// Courtesy of Benjamin von Polheim:
// https://blog.devgenius.io/build-a-performat-autocomplete-using-phoenix-liveview-and-alpine-js-8bcbbed17ba7

export default (id) => ({
  isOpen: false,
  id: id,
  focus: null,
  selectionInProgress: false,
  firstFocusRegistered: false,
  setFocus(f) {
    this.focus = f
  },
  initFocus() {
    if (this.focus === null) {
      this.setFocus(this.leastFocusableIndex())
      if (!this.firstFocusRegistered) {
        document.getElementById(this.id).select()
        this.firstFocusRegistered = true
      }
    }
  },
  trackSubmitValueChange() {
    this.selectionInProgress = false
  },
  open() {
    if (!this.isOpen) {
      this.initFocus()
      this.isOpen = true
    }
  },
  suggestionsCount() {
    return this.$refs.suggestions?.querySelectorAll('li').length
  },
  hasCreatableOption() {
    return this.$refs.suggestions
      ?.querySelector('li')
      .classList.contains('creatable')
  },
  leastFocusableIndex() {
    if (this.suggestionsCount() === 0) {
      return 0
    }
    return this.hasCreatableOption() ? 0 : 1
  },
  maxFocusableIndex() {
    return this.hasCreatableOption()
      ? this.suggestionsCount() - 1
      : this.suggestionsCount()
  },
  nextFocusableIndex() {
    const currentFocus = this.focus
    return currentFocus + 1 > this.maxFocusableIndex()
      ? this.leastFocusableIndex()
      : currentFocus + 1
  },
  prevFocusableIndex() {
    const currentFocus = this.focus
    return currentFocus - 1 >= this.leastFocusableIndex()
      ? currentFocus - 1
      : this.maxFocusableIndex()
  },
  close(e) {
    // Pressing Escape should not propagate to window,
    // so we'll only close the suggestions pop-up
    if (this.isOpen && e.key === 'Escape') {
      e.stopPropagation()
    }
    this.isOpen = false
  },
  select() {
    this.$refs[`dropdown-${this.id}-option-${this.focus}`]?.click()
    this.close()
    document.getElementById(this.id).blur()
  },
  scrollTo(idx) {
    this.$refs[`dropdown-${this.id}-option-${idx}`]?.scrollIntoView({
      block: 'nearest',
      behavior: 'smooth',
      inline: 'start'
    })
  },
  focusNext() {
    const nextIndex = this.nextFocusableIndex()

    this.open()

    this.setFocus(nextIndex)
    this.scrollTo(nextIndex)
  },
  focusPrev() {
    const prevIndex = this.prevFocusableIndex()

    this.open()

    this.setFocus(prevIndex)
    this.scrollTo(prevIndex)
  }
})
