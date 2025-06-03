import { init as initEngagementTracking } from './engagement'
import { init as initConfig, config } from './config'
import { init as initCustomEvents } from './custom-events'
import { init as initAutocapture } from './autocapture'
import { track } from './track'

function init(overrides) {
  if (COMPILE_CONFIG && window.plausible && window.plausible.l) {
    console.warn('Plausible analytics script was already initialized, skipping init')
    return
  }

  initConfig(overrides)
  initEngagementTracking()

  if (!COMPILE_MANUAL || (COMPILE_CONFIG && config.autoCapturePageviews)) {
    initAutocapture(track)
  }

  if (COMPILE_OUTBOUND_LINKS || COMPILE_FILE_DOWNLOADS || COMPILE_TAGGED_EVENTS || COMPILE_CONFIG) {
    initCustomEvents()
  }

  // Call `track` for any events that were queued via plausible('event') before `init` was called
  var queue = (window.plausible && window.plausible.q) || []
  for (var i = 0; i < queue.length; i++) {
    track.apply(this, queue[i])
  }

  window.plausible = track
  window.plausible.init = init
  window.plausible.l = true
}

if (COMPILE_CONFIG) {
  window.plausible = (window.plausible || {})

  if (plausible.o) {
    init(plausible.o)
  }

  plausible.init = init
} else {
  init()
}
