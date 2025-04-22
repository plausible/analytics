  'use strict';

  var location = window.location
  var document = window.document

  if (COMPILE_COMPAT) {
  var scriptEl = document.getElementById('plausible');
  } else {
  var scriptEl = document.currentScript;
  }
  var endpoint = scriptEl.getAttribute('data-api') || defaultEndpoint()
  var dataDomain = scriptEl.getAttribute('data-domain')

  function onIgnoredEvent(eventName, reason, options) {
    if (reason) console.warn('Ignoring Event: ' + reason);
    options && options.callback && options.callback()

    if (eventName === 'pageview') {
      currentEngagementIgnored = true
    }
  }

  function defaultEndpoint() {
    if (COMPILE_COMPAT) {
    var pathArray = scriptEl.src.split( '/' );
    var protocol = pathArray[0];
    var host = pathArray[2];
    return protocol + '//' + host  + '/api/event';
    } else {
    return new URL(scriptEl.src).origin + '/api/event'
    }
  }

  var currentEngagementIgnored
  var currentEngagementURL = location.href
  var currentEngagementProps = {}
  var currentEngagementMaxScrollDepth = -1

  // Multiple pageviews might be sent by the same script when the page
  // uses client-side routing (e.g. hash or history-based). This flag
  // prevents registering multiple listeners in those cases.
  var listeningOnEngagement = false

  // Timestamp indicating when this particular page last became visible.
  // Reset during pageviews, set to null when page is closed.
  var runningEngagementStart = null

  // When page is hidden, this 'engaged' time is saved to this variable
  var currentEngagementTime = 0

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

  function getEngagementTime() {
    if (runningEngagementStart) {
      return currentEngagementTime + (Date.now() - runningEngagementStart)
    } else {
      return currentEngagementTime
    }
  }

  var currentDocumentHeight = getDocumentHeight()
  var maxScrollDepthPx = getCurrentScrollDepthPx()

  window.addEventListener('load', function () {
    currentDocumentHeight = getDocumentHeight()

    // Update the document height again after every 200ms during the
    // next 3 seconds. This makes sure dynamically loaded content is
    // also accounted for.
    var count = 0
    var interval = setInterval(function () {
      currentDocumentHeight = getDocumentHeight()
      if (++count === 15) {clearInterval(interval)}
    }, 200)

  })

  document.addEventListener('scroll', function() {
    currentDocumentHeight = getDocumentHeight()
    var currentScrollDepthPx = getCurrentScrollDepthPx()

    if (currentScrollDepthPx > maxScrollDepthPx) {
      maxScrollDepthPx = currentScrollDepthPx
    }
  })

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
        d: dataDomain,
        u: currentEngagementURL,
        p: currentEngagementProps,
        e: engagementTime,
        v: COMPILE_TRACKER_SCRIPT_VERSION
      }

      // Reset current engagement time metrics. They will restart upon when page becomes visible or the next SPA pageview
      runningEngagementStart = null
      currentEngagementTime = 0

      if (COMPILE_HASH) {
      payload.h = 1
      }

      sendRequest(endpoint, payload)
    }
  }

  function onVisibilityChange() {
    if (document.visibilityState === 'visible' && document.hasFocus() && runningEngagementStart === null) {
      runningEngagementStart = Date.now()
    } else if (document.visibilityState === 'hidden' || !document.hasFocus()) {
      // Tab went back to background or lost focus. Save the engaged time so far
      currentEngagementTime = getEngagementTime()
      runningEngagementStart = null

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

  function trigger(eventName, options) {
    var isPageview = eventName === 'pageview'

    if (isPageview && listeningOnEngagement) {
      // If we're listening on engagement already, at least one pageview
      // has been sent by the current script (i.e. it's most likely a SPA).
      // Trigger an engagement marking the "exit from the previous page".
      triggerEngagement()
      currentDocumentHeight = getDocumentHeight()
      maxScrollDepthPx = getCurrentScrollDepthPx()
    }

    if (!COMPILE_LOCAL) {
    if (/^localhost$|^127(\.[0-9]+){0,2}\.[0-9]+$|^\[::1?\]$/.test(location.hostname) || location.protocol === 'file:') {
      return onIgnoredEvent(eventName, 'localhost', options)
    }
    if ((window._phantom || window.__nightmare || window.navigator.webdriver || window.Cypress) && !window.__plausible) {
      return onIgnoredEvent(eventName, null, options)
    }
    }
    try {
      if (window.localStorage.plausible_ignore === 'true') {
        return onIgnoredEvent(eventName, 'localStorage flag', options)
      }
    } catch (e) {

    }
    if (COMPILE_EXCLUSIONS) {
    var dataIncludeAttr = scriptEl && scriptEl.getAttribute('data-include')
    var dataExcludeAttr = scriptEl && scriptEl.getAttribute('data-exclude')

    if (isPageview) {
      var isIncluded = !dataIncludeAttr || (dataIncludeAttr && dataIncludeAttr.split(',').some(pathMatches))
      var isExcluded = dataExcludeAttr && dataExcludeAttr.split(',').some(pathMatches)

      if (!isIncluded || isExcluded) return onIgnoredEvent(eventName, 'exclusion rule', options)
    }

    function pathMatches(wildcardPath) {
      var actualPath = location.pathname

      if (COMPILE_HASH) {
      actualPath += location.hash
      }

      return actualPath.match(new RegExp('^' + wildcardPath.trim().replace(/\*\*/g, '.*').replace(/([^\.])\*/g, '$1[^\\s\/]*') + '\/?$'))
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

    payload.d = dataDomain
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

    propAttributes.forEach(function(attribute) {
      var propKey = attribute.replace('event-', '')
      var propValue = scriptEl.getAttribute(attribute)
      props[propKey] = props[propKey] || propValue
    })

    payload.p = props
    }

    if (COMPILE_HASH) {
    payload.h = 1
    }

    if (isPageview) {
      currentEngagementIgnored = false
      currentEngagementURL = payload.u
      currentEngagementProps = payload.p
      currentEngagementMaxScrollDepth = -1
      currentEngagementTime = 0
      runningEngagementStart = Date.now()
      registerEngagementListener()
    }

    sendRequest(endpoint, payload, options)
  }

  function sendRequest(endpoint, payload, options) {
    if (COMPILE_COMPAT) {
    var request = new XMLHttpRequest();
    request.open('POST', endpoint, true);
    request.setRequestHeader('Content-Type', 'text/plain');

    request.send(JSON.stringify(payload));

    request.onreadystatechange = function() {
      if (request.readyState === 4) {
        options && options.callback && options.callback({status: request.status})
      }
    }
    } else {
    if (window.fetch) {
      fetch(endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'text/plain'
        },
        keepalive: true,
        body: JSON.stringify(payload)
      }).then(function(response) {
        options && options.callback && options.callback({status: response.status})
      }).catch(function() {})
    }
    }
  }

  var queue = (window.plausible && window.plausible.q) || []
  window.plausible = trigger
  for (var i = 0; i < queue.length; i++) {
    trigger.apply(this, queue[i])
  }

  if (!COMPILE_MANUAL) {
    var lastPage;

    function page(isSPANavigation) {
      if (!COMPILE_HASH) {
      if (isSPANavigation && lastPage === location.pathname) return;
      }

      lastPage = location.pathname
      trigger('pageview')
    }

    var onSPANavigation = function() {page(true)}

    if (COMPILE_HASH) {
    window.addEventListener('hashchange', onSPANavigation)
    } else {
    var his = window.history
    if (his.pushState) {
      var originalPushState = his['pushState']
      his.pushState = function() {
        originalPushState.apply(this, arguments)
        onSPANavigation();
      }
      window.addEventListener('popstate', onSPANavigation)
    }
    }

    function handleVisibilityChange() {
      if (!lastPage && document.visibilityState === 'visible') {
        page()
      }
    }

    if (document.visibilityState === 'hidden' || document.visibilityState === 'prerender') {
      document.addEventListener('visibilitychange', handleVisibilityChange);
    } else {
      page()
    }

    window.addEventListener('pageshow', function(event) {
      if (event.persisted) {
        // Page was restored from bfcache - trigger a pageview
        page();
      }
    })
  }
