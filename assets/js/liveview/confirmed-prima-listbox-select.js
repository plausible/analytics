/**
 * A workaround to make it possible to avoid `Prima.Listbox` updating the
 * current listbox selection when a browser-native confirmation dialog
 * pops up and the user hits "Cancel".
 *
 * This is necessary for a specific case in team management where we're
 * using `Prima.Listbox` in a non-standard way: selecting an option also
 * means a quiet LiveView "submit" in the background.
 *
 * From Prima's perspective, it's totally valid to instantly update the
 * selected value when a click on an option lands. But in a case where
 * select == submit and a browser-native confirmation dialog is cancelled,
 * we want to pretend like this click never happened -- i.e. undo Prima's
 * last selection update.
 */

export default {
  mounted() {
    if (!this.el.hasAttribute('data-confirm')) return

    // Bind click handler directly on the option itself (not an ancestor,
    // like Prima's own hook). The click needs to be handled **before**
    // Prima handles it.
    this.el.addEventListener('click', (e) => {
      const listbox = this.el.closest('[role="listbox"]')
      const previouslySelected = listbox?.querySelector(
        '[aria-selected="true"]'
      )

      // window.confirm() is synchronous/blocking, so by the time this
      // deferred callback runs, the confirmation dialog is dealt with
      // and `e.preventDefault` reflects the user's choice -- true when
      // the they cancelled.
      setTimeout(() => {
        if (e.defaultPrevented && previouslySelected) {
          this.restore(previouslySelected)
        }
      }, 0)
    })
  },

  restore(option) {
    const container = this.el.closest('[phx-hook="Listbox"]')
    if (!container) return

    // (Maybe) TODO: Instead of manually reaching into Prima's internals, we could
    // perhaps trigger a click on previously selected option instead. This depends
    // on our specific team management case to enable clicks on the currently
    // selected value though.
    const valueInput = container.querySelector('[data-prima-ref="value-input"]')
    const valueLabel = container.querySelector('[data-prima-ref="value"]')

    if (valueInput) valueInput.value = option.getAttribute('data-value')
    if (valueLabel) valueLabel.textContent = option.getAttribute('data-display')

    container
      .querySelector('[role="option"][aria-selected="true"]')
      ?.removeAttribute('aria-selected')
    container
      .querySelectorAll('[data-selected]')
      .forEach((el) => el.removeAttribute('data-selected'))

    option.setAttribute('aria-selected', 'true')
    option.setAttribute('data-selected', 'true')
  }
}
