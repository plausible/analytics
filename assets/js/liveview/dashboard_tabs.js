/**
 * Hook widget for optimistic loading of tabs and
 * client-side persistence of selection using localStorage.
 */

import { buildHook } from './hook_builder'

function getDomain(url) {
  const uri = typeof url === 'object' ? url : new URL(url)
  return uri.pathname.split('/')[1]
}

export default buildHook({
  initialize() {
    const domain = getDomain(window.location.href)

    this.addListener('click', this.el, (e) => {
      const button = e.target.closest('button')
      const tab = button && button.dataset.tab

      if (tab) {
        const label = button.dataset.label
        const storageKey = button.dataset.storageKey
        const activeClasses = button.dataset.activeClasses
        const inactiveClasses = button.dataset.inactiveClasses
        const title = this.el
          .closest('[data-tile]')
          .querySelector('[data-title]')

        title.innerText = label

        this.el.querySelectorAll(`button[data-tab] span`).forEach((s) => {
          s.className = inactiveClasses
        })

        button.querySelector('span').className = activeClasses

        if (storageKey) {
          localStorage.setItem(`${storageKey}__${domain}`, tab)
        }
      }
    })
  }
})
