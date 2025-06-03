import { config } from './config'
import { sendRequest } from './networking'

/* Engagement tracking variables and functions */

// Multiple pageviews might be sent by the same script when the page
// uses client-side routing (e.g. hash or history-based). This flag
// prevents registering multiple listeners in those cases.
var listeningOnEngagement = false

var currentEngagementIgnored
var currentEngagementURL = location.href
var currentEngagementProps = {}
var currentEngagementMaxScrollDepth = -1

// Timestamp indicating when this particular page last became visible.
// Reset during pageviews, set to 0 when page is closed.
var runningEngagementStart = 0

// When page is hidden, this 'engaged' time is saved to this variable
var currentEngagementTime = 0

export function prePageviewTrack() {
  if (listeningOnEngagement) {
    // If we're listening on engagement already, at least one pageview
    // has been sent by the current script (i.e. it's most likely a SPA).
    // Trigger an engagement marking the "exit from the previous page".
    triggerEngagement()
    currentDocumentHeight = getDocumentHeight()
    maxScrollDepthPx = getCurrentScrollDepthPx()
  }
}

export function postPageviewTrack(payload) {
  currentEngagementIgnored = false
  currentEngagementURL = payload.u
  currentEngagementProps = payload.p
  currentEngagementMaxScrollDepth = -1
  currentEngagementTime = 0
  runningEngagementStart = Date.now()
  registerEngagementListener()
}

export function onPageviewIgnored() {
  currentEngagementIgnored = true
}

function triggerEngagement() {
  var engagementTime = getEngagementTime()

  /*
  We send engagements if there's new relevant engagement information to share:
  - If the user has scrolled more than the previously sent max scroll depth.
  - If the user has been engaged for more than 3 seconds since the last engagement event.

  The first engagement event is always sent due to containing at least the initial scroll depth.

  Also, we don't send engagements if the current pageview is ignored (onIgnoredEvent)
  */
  if (!currentEngagementIgnored && (currentEngagementMaxScrollDepth < maxScrollDepthPx || engagementTime >= 3000)) {
    currentEngagementMaxScrollDepth = maxScrollDepthPx

    var payload = {
      n: 'engagement',
      sd: Math.round((maxScrollDepthPx / currentDocumentHeight) * 100),
      d: config.domain,
      u: currentEngagementURL,
      p: currentEngagementProps,
      e: engagementTime,
      v: COMPILE_TRACKER_SCRIPT_VERSION
    }

    // Reset current engagement time metrics. They will restart upon when page becomes visible or the next SPA pageview
    runningEngagementStart = 0
    currentEngagementTime = 0

    if (COMPILE_HASH && (!COMPILE_CONFIG || config.hashBasedRouting)) {
      payload.h = 1
    }

    sendRequest(config.endpoint, payload)
  }
}

function onVisibilityChange() {
  if (document.visibilityState === 'visible' && document.hasFocus() && runningEngagementStart === 0) {
    runningEngagementStart = Date.now()
  } else if (document.visibilityState === 'hidden' || !document.hasFocus()) {
    // Tab went back to background or lost focus. Save the engaged time so far
    currentEngagementTime = getEngagementTime()
    runningEngagementStart = 0

    triggerEngagement()
  }
}

function registerEngagementListener() {
  if (!listeningOnEngagement) {
    // Only register visibilitychange listener only after initial page load and pageview
    document.addEventListener('visibilitychange', onVisibilityChange)
    window.addEventListener('blur', onVisibilityChange)
    window.addEventListener('focus', onVisibilityChange)
    listeningOnEngagement = true
  }
}

function getEngagementTime() {
  if (runningEngagementStart) {
    return currentEngagementTime + (Date.now() - runningEngagementStart)
  } else {
    return currentEngagementTime
  }
}


var currentDocumentHeight
var maxScrollDepthPx

function getDocumentHeight() {
  var body = document.body || {}
  var el = document.documentElement || {}
  return Math.max(
    body.scrollHeight || 0,
    body.offsetHeight || 0,
    body.clientHeight || 0,
    el.scrollHeight || 0,
    el.offsetHeight || 0,
    el.clientHeight || 0
  )
}

function getCurrentScrollDepthPx() {
  var body = document.body || {}
  var el = document.documentElement || {}
  var viewportHeight = window.innerHeight || el.clientHeight || 0
  var scrollTop = window.scrollY || el.scrollTop || body.scrollTop || 0

  return currentDocumentHeight <= viewportHeight ? currentDocumentHeight : scrollTop + viewportHeight
}

export function init() {
  currentDocumentHeight = getDocumentHeight()
  maxScrollDepthPx = getCurrentScrollDepthPx()

  window.addEventListener('load', function () {
    currentDocumentHeight = getDocumentHeight()

    // Update the document height again after every 200ms during the
    // next 3 seconds. This makes sure dynamically loaded content is
    // also accounted for.
    var count = 0
    var interval = setInterval(function () {
      currentDocumentHeight = getDocumentHeight()
      if (++count === 15) { clearInterval(interval) }
    }, 200)
  })

  document.addEventListener('scroll', function () {
    currentDocumentHeight = getDocumentHeight()
    var currentScrollDepthPx = getCurrentScrollDepthPx()

    if (currentScrollDepthPx > maxScrollDepthPx) {
      maxScrollDepthPx = currentScrollDepthPx
    }
  })
}
