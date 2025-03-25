// From https://alpinejs.dev/component/dropdown

export default () => ({
  open: false,
  toggle() {
    if (this.open) {
      return this.close()
    }

    this.$refs.button.focus()
    this.open = true
  },

  close(focusAfter) {
    if (!this.open) return

    this.open = false
    focusAfter?.focus()
  }
})
