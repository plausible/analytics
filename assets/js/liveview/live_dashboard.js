const WIDGETS = {
  'breakdown-tile': {
    initialize: function () {
      const that = this

      this.url = window.location.href

      this.listeners = []

      const localStorageListener = (e) => {
        console.log('localStorage updated', e.detail)
        localStorage.setItem(e.detail.key, e.detail.value)
      }

      window.addEventListener('phx:update_local_storage', localStorageListener)

      this.listeners.push({
        element: window,
        event: 'phx:update_local_storage',
        callback: localStorageListener
      })

      const clickListener = (e) => {
        const type = e.target.dataset.type || null

        if (type && type == 'dashboard-link') {
          that.url = e.target.href
          const uri = new URL(that.url)
          that.el.dispatchEvent(
            new CustomEvent('live-navigate', {
              bubbles: true,
              detail: { search: uri.search }
            })
          )

          that.pushEvent('handle_dashboard_params', { url: that.url })

          e.preventDefault()
        }
      }

      this.el.addEventListener('click', clickListener)

      this.listeners.push({
        element: this.el,
        event: 'click',
        callback: clickListener
      })

      const popListener = (e) => {
        if (that.url !== window.location.href) {
          that.pushEvent('handle_dashboard_params', {
            url: window.location.href
          })
        }
      }

      window.addEventListener('popstate', popListener)

      this.listeners.push({
        element: window,
        event: 'popstate',
        callback: popListener
      })

      const backListener = (e) => {
        if (
          typeof e.detail.search === 'string' &&
          that.url !== window.location.href
        ) {
          that.pushEvent('handle_dashboard_params', {
            url: window.location.href
          })
        }
      }

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
