var location = window.location
var document = window.document

if (COMPILE_COMPAT) {
  var scriptEl = document.getElementById('plausible');
} else {
  var scriptEl = document.currentScript;
}

var config = {}

if (COMPILE_CONFIG) {
  config = "<%= @config_json %>"
}

var endpoint
var dataDomain

// Exported public function
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

  if (!(COMPILE_LOCAL && (!COMPILE_CONFIG || config.local))) {
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
  if (COMPILE_EXCLUSIONS && (!COMPILE_CONFIG || config.exclusions)) {
    var dataIncludeAttr = scriptEl && scriptEl.getAttribute('data-include')
    var dataExcludeAttr = scriptEl && scriptEl.getAttribute('data-exclude')


    function pathMatches(wildcardPath) {
      var actualPath = location.pathname

      if (COMPILE_HASH && (!COMPILE_CONFIG || config.hash)) {
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

  if (COMPILE_MANUAL && (!COMPILE_CONFIG || config.manual)) {
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
  if (COMPILE_REVENUE && (!COMPILE_CONFIG || config.revenue)) {
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
  // Note that engagement events track custom properties differently, using `currentEngagementProps`
  if (COMPILE_CUSTOM_PROPERTIES && config.customProperties && eventName !== 'engagement') {
    var props = (typeof config.customProperties === 'object') ? config.customProperties : config.customProperties(eventName)

    payload.p = payload.p || {}
    for (var key in props) {
      payload.p[key] = payload.p[key] || props[key]
    }
  }

  if (COMPILE_HASH && (!COMPILE_CONFIG || config.hash)) {
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

    request.onreadystatechange = function () {
      if (request.readyState === 4) {
        options && options.callback && options.callback({ status: request.status })
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
      }).then(function (response) {
        options && options.callback && options.callback({ status: response.status })
      }).catch(function () { })
    }
  }
}

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
// Reset during pageviews, set to null when page is closed.
var runningEngagementStart = null

// When page is hidden, this 'engaged' time is saved to this variable
var currentEngagementTime = 0

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

    if (COMPILE_HASH && (!COMPILE_CONFIG || config.hash)) {
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

function onIgnoredEvent(eventName, reason, options) {
  if (reason) console.warn('Ignoring Event: ' + reason);
  options && options.callback && options.callback()

  if (eventName === 'pageview') {
    currentEngagementIgnored = true
  }
}

function defaultEndpoint() {
  if (COMPILE_COMPAT) {
    var pathArray = scriptEl.src.split('/');
    var protocol = pathArray[0];
    var host = pathArray[2];
    return protocol + '//' + host + '/api/event';
  } else {
    return new URL(scriptEl.src).origin + '/api/event'
  }
}

function init(overrides) {
  if (COMPILE_CONFIG && window.plausible && window.plausible.l) {
    console.warn('Plausible analytics script was already initialized, skipping init')
    return
  }

  if (COMPILE_CONFIG && overrides) {
    config.endpoint = overrides.endpoint || config.endpoint
    config.domain = overrides.domain || config.domain
    config.hash = overrides.hash || config.hash
    config.exclusions = overrides.exclusions || config.exclusions
    config.revenue = overrides.revenue || config.revenue
    config.manual = config.manual || overrides.manual
    config.local = config.local || overrides.local
    config.customProperties = overrides.customProperties
  }

  endpoint = COMPILE_CONFIG ? config.endpoint : (scriptEl.getAttribute('data-api') || defaultEndpoint())
  dataDomain = COMPILE_CONFIG ? config.domain : scriptEl.getAttribute('data-domain')

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

  if (!(COMPILE_MANUAL && (!COMPILE_CONFIG || config.manual))) {
    var lastPage;

    function page(isSPANavigation) {
      if (!(COMPILE_HASH && (!COMPILE_CONFIG || config.hash))) {
        if (isSPANavigation && lastPage === location.pathname) return;
      }

      lastPage = location.pathname
      trigger('pageview')
    }

    var onSPANavigation = function () { page(true) }

    if (COMPILE_HASH && (!COMPILE_CONFIG || config.hash)) {
      window.addEventListener('hashchange', onSPANavigation)
    } else {
      var his = window.history
      if (his.pushState) {
        var originalPushState = his['pushState']
        his.pushState = function () {
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

    window.addEventListener('pageshow', function (event) {
      if (event.persisted) {
        // Page was restored from bfcache - trigger a pageview
        page();
      }
    })
  }

  if (COMPILE_OUTBOUND_LINKS || COMPILE_FILE_DOWNLOADS || COMPILE_TAGGED_EVENTS) {
    function getLinkEl(link) {
      while (link && (typeof link.tagName === 'undefined' || !isLink(link) || !link.href)) {
        link = link.parentNode
      }
      return link
    }

    function isLink(element) {
      return element && element.tagName && element.tagName.toLowerCase() === 'a'
    }

    function shouldFollowLink(event, link) {
      // If default has been prevented by an external script, Plausible should not intercept navigation.
      if (event.defaultPrevented) { return false }

      var targetsCurrentWindow = !link.target || link.target.match(/^_(self|parent|top)$/i)
      var isRegularClick = !(event.ctrlKey || event.metaKey || event.shiftKey) && event.type === 'click'
      return targetsCurrentWindow && isRegularClick
    }

    var MIDDLE_MOUSE_BUTTON = 1

    function handleLinkClickEvent(event) {
      if (event.type === 'auxclick' && event.button !== MIDDLE_MOUSE_BUTTON) { return }

      var link = getLinkEl(event.target)
      var hrefWithoutQuery = link && link.href && link.href.split('?')[0]

      if (COMPILE_TAGGED_EVENTS && (!COMPILE_CONFIG || config.taggedEvents)) {
        if (isElementOrParentTagged(link, 0)) {
          // Return to prevent sending multiple events with the same action.
          // Clicks on tagged links are handled by another function.
          return
        }
      }

      if (COMPILE_OUTBOUND_LINKS && (!COMPILE_CONFIG || config.outboundLinks)) {
        if (isOutboundLink(link)) {
          return sendLinkClickEvent(event, link, { name: 'Outbound Link: Click', props: { url: link.href } })
        }
      }

      if (COMPILE_FILE_DOWNLOADS && (!COMPILE_CONFIG || config.fileDownloads)) {
        if (isDownloadToTrack(hrefWithoutQuery)) {
          return sendLinkClickEvent(event, link, { name: 'File Download', props: { url: hrefWithoutQuery } })
        }
      }
    }

    function sendLinkClickEvent(event, link, eventAttrs) {
      var followedLink = false

      function followLink() {
        if (!followedLink) {
          followedLink = true
          window.location = link.href
        }
      }

      if (shouldFollowLink(event, link)) {
        var attrs = { props: eventAttrs.props, callback: followLink }
        if (COMPILE_REVENUE && (!COMPILE_CONFIG || config.revenue)) {
          attrs.revenue = eventAttrs.revenue
        }
        plausible(eventAttrs.name, attrs)
        setTimeout(followLink, 5000)
        event.preventDefault()
      } else {
        var attrs = { props: eventAttrs.props }
        if (COMPILE_REVENUE && (!COMPILE_CONFIG || config.revenue)) {
          attrs.revenue = eventAttrs.revenue
        }
        plausible(eventAttrs.name, attrs)
      }
    }

    document.addEventListener('click', handleLinkClickEvent)
    document.addEventListener('auxclick', handleLinkClickEvent)

    if (COMPILE_OUTBOUND_LINKS && (!COMPILE_CONFIG || config.outboundLinks)) {
      function isOutboundLink(link) {
        return link && link.href && link.host && link.host !== location.host
      }
    }

    if (COMPILE_FILE_DOWNLOADS && (!COMPILE_CONFIG || config.fileDownloads)) {
      var defaultFileTypes = ['pdf', 'xlsx', 'docx', 'txt', 'rtf', 'csv', 'exe', 'key', 'pps', 'ppt', 'pptx', '7z', 'pkg', 'rar', 'gz', 'zip', 'avi', 'mov', 'mp4', 'mpeg', 'wmv', 'midi', 'mp3', 'wav', 'wma', 'dmg']
      var fileTypesAttr = scriptEl.getAttribute('file-types')
      var addFileTypesAttr = scriptEl.getAttribute('add-file-types')
      var fileTypesToTrack = (fileTypesAttr && fileTypesAttr.split(",")) || (addFileTypesAttr && addFileTypesAttr.split(",").concat(defaultFileTypes)) || defaultFileTypes;

      function isDownloadToTrack(url) {
        if (!url) { return false }

        var fileType = url.split('.').pop();
        return fileTypesToTrack.some(function (fileTypeToTrack) {
          return fileTypeToTrack === fileType
        })
      }
    }

    if (COMPILE_TAGGED_EVENTS && (!COMPILE_CONFIG || config.taggedEvents)) {
      // Finds event attributes by iterating over the given element's (or its
      // parent's) classList. Returns an object with `name` and `props` keys.
      function getTaggedEventAttributes(htmlElement) {
        var taggedElement = isTagged(htmlElement) ? htmlElement : htmlElement && htmlElement.parentNode
        var eventAttrs = { name: null, props: {} }
        if (COMPILE_REVENUE && (!COMPILE_CONFIG || config.revenue)) {
          eventAttrs.revenue = {}
        }

        var classList = taggedElement && taggedElement.classList
        if (!classList) { return eventAttrs }

        for (var i = 0; i < classList.length; i++) {
          var className = classList.item(i)

          var matchList = className.match(/plausible-event-(.+)(=|--)(.+)/)
          if (matchList) {
            var key = matchList[1]
            var value = matchList[3].replace(/\+/g, ' ')

            if (key.toLowerCase() == 'name') {
              eventAttrs.name = value
            } else {
              eventAttrs.props[key] = value
            }
          }

          if (COMPILE_REVENUE && (!COMPILE_CONFIG || config.revenue)) {
            var revenueMatchList = className.match(/plausible-revenue-(.+)(=|--)(.+)/)
            if (revenueMatchList) {
              var key = revenueMatchList[1]
              var value = revenueMatchList[3]
              eventAttrs.revenue[key] = value
            }
          }
        }

        return eventAttrs
      }

      function handleTaggedFormSubmitEvent(event) {
        var form = event.target
        var eventAttrs = getTaggedEventAttributes(form)
        if (!eventAttrs.name) { return }

        event.preventDefault()
        var formSubmitted = false

        function submitForm() {
          if (!formSubmitted) {
            formSubmitted = true
            form.submit()
          }
        }

        setTimeout(submitForm, 5000)

        var attrs = { props: eventAttrs.props, callback: submitForm }
        if (COMPILE_REVENUE && (!COMPILE_CONFIG || config.revenue)) {
          attrs.revenue = eventAttrs.revenue
        }
        plausible(eventAttrs.name, attrs)
      }

      function isForm(element) {
        return element && element.tagName && element.tagName.toLowerCase() === 'form'
      }

      var PARENTS_TO_SEARCH_LIMIT = 3

      function handleTaggedElementClickEvent(event) {
        if (event.type === 'auxclick' && event.button !== MIDDLE_MOUSE_BUTTON) { return }

        var clicked = event.target

        var clickedLink
        var taggedElement
        // Iterate over parents to find the tagged element. Also search for
        // a link element to call for different tracking behavior if found.
        for (var i = 0; i <= PARENTS_TO_SEARCH_LIMIT; i++) {
          if (!clicked) { break }

          // Clicks inside forms are not tracked. Only form submits are.
          if (isForm(clicked)) { return }
          if (isLink(clicked)) { clickedLink = clicked }
          if (isTagged(clicked)) { taggedElement = clicked }
          clicked = clicked.parentNode
        }

        if (taggedElement) {
          var eventAttrs = getTaggedEventAttributes(taggedElement)

          if (clickedLink) {
            // if the clicked tagged element is a link, we attach the `url` property
            // automatically for user convenience
            eventAttrs.props.url = clickedLink.href
            sendLinkClickEvent(event, clickedLink, eventAttrs)
          } else {
            var attrs = {}
            attrs.props = eventAttrs.props
            if (COMPILE_REVENUE && (!COMPILE_CONFIG || config.revenue)) {
              attrs.revenue = eventAttrs.revenue
            }
            plausible(eventAttrs.name, attrs)
          }
        }
      }

      function isTagged(element) {
        var classList = element && element.classList
        if (classList) {
          for (var i = 0; i < classList.length; i++) {
            if (classList.item(i).match(/plausible-event-name(=|--)(.+)/)) { return true }
          }
        }
        return false
      }

      function isElementOrParentTagged(element, parentsChecked) {
        if (!element || parentsChecked > PARENTS_TO_SEARCH_LIMIT) { return false }
        if (isTagged(element)) { return true }
        return isElementOrParentTagged(element.parentNode, parentsChecked + 1)
      }

      document.addEventListener('submit', handleTaggedFormSubmitEvent)
      document.addEventListener('click', handleTaggedElementClickEvent)
      document.addEventListener('auxclick', handleTaggedElementClickEvent)
    }
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
