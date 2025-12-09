export function buildHook({ initialize, cleanup }) {
  cleanup = cleanup || function () {}

  return {
    mounted() {
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
      initialize.bind(this)()
    },

    cleanup() {
      this.removeListeners()
      cleanup.bind(this)()
    },

    addListener(eventName, listener, callback) {
      this.listeners = this.listeners || []

      listener.addEventListener(eventName, callback)

      this.listeners.push({
        element: listener,
        event: eventName,
        callback: callback
      })
    },

    removeListeners() {
      if (this.listeners) {
        this.listeners.forEach((l) => {
          l.element.removeEventListener(l.event, l.callback)
        })

        this.listeners = null
      }
    }
  }
}
