import { init as initEngagementTracking, prePageviewTrigger, postPageviewTrigger, onPageviewIgnored } from './engagement'
import { sendRequest } from './networking'
import { init as initConfig, config, scriptEl, location, document } from './config'
import { init as initCustomEvents } from './custom-events'
import { init as initAutocapture } from './autocapture'

// Exported public function
function trigger(eventName, options) {
  var isPageview = eventName === 'pageview'

  if (isPageview) {
    prePageviewTrigger()
  }

  if (!(COMPILE_LOCAL && (!COMPILE_CONFIG || config.captureOnLocalhost))) {
    if (/^localhost$|^127(\.[0-9]+){0,2}\.[0-9]+$|^\[::1?\]$/.test(location.hostname) || location.protocol === 'file:') {
      return onIgnoredEvent(eventName, options, 'localhost')
    }
    if ((window._phantom || window.__nightmare || window.navigator.webdriver || window.Cypress) && !window.__plausible) {
      return onIgnoredEvent(eventName, options)
    }
  }
  try {
    if (window.localStorage.plausible_ignore === 'true') {
      return onIgnoredEvent(eventName, options, 'localStorage flag')
    }
  } catch (e) {

  }
  if (COMPILE_EXCLUSIONS) {
    var dataIncludeAttr = scriptEl && scriptEl.getAttribute('data-include')
    var dataExcludeAttr = scriptEl && scriptEl.getAttribute('data-exclude')

    function pathMatches(wildcardPath) {
      var actualPath = location.pathname

      if (COMPILE_HASH && (!COMPILE_CONFIG || config.hashBasedRouting)) {
        actualPath += location.hash
      }

      return actualPath.match(new RegExp('^' + wildcardPath.trim().replace(/\*\*/g, '.*').replace(/([^\.])\*/g, '$1[^\\s\/]*') + '\/?$'))
    }

    if (isPageview) {
      var isIncluded = !dataIncludeAttr || (dataIncludeAttr && dataIncludeAttr.split(',').some(pathMatches))
      var isExcluded = dataExcludeAttr && dataExcludeAttr.split(',').some(pathMatches)

      if (!isIncluded || isExcluded) return onIgnoredEvent(eventName, 'exclusion rule', options)
    }
  }

  var payload = {}
  payload.n = eventName
  payload.v = COMPILE_TRACKER_SCRIPT_VERSION

  if (COMPILE_MANUAL) {
    var customURL = options && options.u

    payload.u = customURL ? customURL : location.href
  } else {
    payload.u = location.href
  }

  payload.d = config.domain
  payload.r = document.referrer || null
  if (options && options.meta) {
    payload.m = JSON.stringify(options.meta)
  }
  if (options && options.props) {
    payload.p = options.props
  }
  if (options && options.interactive === false) {
    payload.i = false
  }
  if (COMPILE_REVENUE) {
    if (options && options.revenue) {
      payload.$ = options.revenue
    }
  }

  if (COMPILE_PAGEVIEW_PROPS) {
    var propAttributes = scriptEl.getAttributeNames().filter(function (name) {
      return name.substring(0, 6) === 'event-'
    })

    var props = payload.p || {}

    propAttributes.forEach(function (attribute) {
      var propKey = attribute.replace('event-', '')
      var propValue = scriptEl.getAttribute(attribute)
      props[propKey] = props[propKey] || propValue
    })

    payload.p = props
  }

  // Track custom properties for pageviews and other events
  if (COMPILE_CUSTOM_PROPERTIES && config.customProperties) {
    var props = config.customProperties
    if (typeof props === 'function') {
      props = config.customProperties(eventName)
    }

    if (typeof props === 'object') {
      payload.p = Object.assign({}, props, payload.p)
    }
  }

  if (COMPILE_HASH && (!COMPILE_CONFIG || config.hashBasedRouting)) {
    payload.h = 1
  }

  if (isPageview) {
    postPageviewTrigger(payload)
  }

  sendRequest(config.endpoint, payload, options)
}


function onIgnoredEvent(eventName, options, reason) {
  if (reason) console.warn('Ignoring Event: ' + reason);
  options && options.callback && options.callback()

  if (eventName === 'pageview') {
    onPageviewIgnored()
  }
}


function init(overrides) {
  if (COMPILE_CONFIG && window.plausible && window.plausible.l) {
    console.warn('Plausible analytics script was already initialized, skipping init')
    return
  }

  initConfig(overrides)
  initEngagementTracking()

  if (!COMPILE_MANUAL || (COMPILE_CONFIG && config.autoCapturePageviews)) {
    initAutocapture(trigger)
  }

  if (COMPILE_OUTBOUND_LINKS || COMPILE_FILE_DOWNLOADS || COMPILE_TAGGED_EVENTS || COMPILE_CONFIG) {
    initCustomEvents()
  }

  // Call `trigger` for any events that were queued via plausible('event') before `init` was called
  var queue = (window.plausible && window.plausible.q) || []
  for (var i = 0; i < queue.length; i++) {
    trigger.apply(this, queue[i])
  }

  window.plausible = trigger
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
