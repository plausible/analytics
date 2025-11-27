const WIDGETS = {
  'breakdown-tile': {
    initialize: function () {
      this.url = window.location.href

      this.listeners = []

      const localStorageListener = (e) => {
        localStorage.setItem(e.detail.key, e.detail.value)
      }

      window.addEventListener('phx:update_local_storage', localStorageListener)

      this.listeners.push({
        element: window,
        event: 'phx:update_local_storage',
        callback: localStorageListener
      })

      const clickListener = ((e) => {
        const type = e.target.dataset.type || null

        if (type && type == 'dashboard-link') {
          this.url = e.target.href
          const uri = new URL(this.url)
          this.el.dispatchEvent(
            new CustomEvent('live-navigate', {
              bubbles: true,
              detail: { search: uri.search }
            })
          )

          this.pushEvent('handle_dashboard_params', { url: this.url })

          e.preventDefault()
        }
      }).bind(this)

      this.el.addEventListener('click', clickListener)

      this.listeners.push({
        element: this.el,
        event: 'click',
        callback: clickListener
      })

      const popListener = (() => {
        if (this.url !== window.location.href) {
          this.pushEvent('handle_dashboard_params', {
            url: window.location.href
          })
        }
      }).bind(this)

      window.addEventListener('popstate', popListener)

      this.listeners.push({
        element: window,
        event: 'popstate',
        callback: popListener
      })

      const backListener = ((e) => {
        if (
          typeof e.detail.search === 'string' &&
          this.url !== window.location.href
        ) {
          this.pushEvent('handle_dashboard_params', {
            url: window.location.href
          })
        }
      }).bind(this)

      window.addEventListener('live-navigate-back', backListener)

      this.listeners.push({
        element: window,
        event: 'live-navigate-back',
        callback: backListener
      })
    },
    cleanup: function () {
      if (this.listeners) {
        this.listeners.forEach((l) => {
          l.element.removeEventListener(l.event, l.callback)
        })

        this.listeners = null
      }
    }
  }
}

export default {
  mounted() {
    this.widget = this.el.getAttribute('data-widget')

    this.initialize()
  },

  updated() {
    this.initialize()
  },

  reconnected() {
    this.initialize()
  },

  destroyed() {
    this.cleanup()
  },

  initialize() {
    this.cleanup()
    WIDGETS[this.widget].initialize.bind(this)()
  },

  cleanup() {
    WIDGETS[this.widget].cleanup.bind(this)()
  }
}
