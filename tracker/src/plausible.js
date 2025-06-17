import { init as initEngagementTracking } from './engagement'
import { init as initConfig, config } from './config'
import { init as initCustomEvents, DEFAULT_FILE_TYPES } from './custom-events'
import { init as initAutocapture } from './autocapture'
import { track } from './track'

function init(overrides) {
  initConfig(overrides || {})

  if (COMPILE_PLAUSIBLE_WEB && window.plausible && window.plausible.l) {
    if (config.logging) {
      console.warn('Plausible analytics script was already initialized, skipping init')
    }
    return
  }

  initEngagementTracking()

  if (!COMPILE_MANUAL || (COMPILE_CONFIG && config.autoCapturePageviews)) {
    initAutocapture(track)
  }

  if (COMPILE_PLAUSIBLE_WEB || COMPILE_PLAUSIBLE_NPM || COMPILE_OUTBOUND_LINKS || COMPILE_FILE_DOWNLOADS || COMPILE_TAGGED_EVENTS) {
    initCustomEvents()
  }


  if (COMPILE_PLAUSIBLE_WEB || COMPILE_PLAUSIBLE_LEGACY_VARIANT) {
    // Call `track` for any events that were queued via plausible('event') before `init` was called
    var queue = (window.plausible && window.plausible.q) || []
    for (var i = 0; i < queue.length; i++) {
      track.apply(this, queue[i])
    }

    window.plausible = track
    window.plausible.init = init
    window.plausible.l = true
  }
}

if (COMPILE_PLAUSIBLE_WEB) {
  window.plausible = (window.plausible || {})

  if (plausible.o) {
    init(plausible.o)
  }

  plausible.init = init
} else if (COMPILE_PLAUSIBLE_LEGACY_VARIANT) {
  // Legacy variants automatically initialize based compile variables
  init()
}

// In npm module, we export the init and track functions
// export { init, track, DEFAULT_FILE_TYPES }
