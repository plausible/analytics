import { sendRequest } from './networking'
import { prePageviewTrack, postPageviewTrack, onPageviewIgnored } from './engagement'
import { config, scriptEl, location, document } from './config'

export function track(eventName, options) {
  var isPageview = eventName === 'pageview'

  if (isPageview) {
    prePageviewTrack()
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
    postPageviewTrack(payload)
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
