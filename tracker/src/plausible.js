import { init as initEngagementTracking, prePageviewTrigger, postPageviewTrigger, onPageviewIgnored } from './engagement'
import { sendRequest } from './networking'
import { init as initConfig, config, scriptEl } from './config'

var location = window.location
var document = window.document

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

  if (!COMPILE_MANUAL || (COMPILE_CONFIG && config.autoCapturePageviews)) {
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
    var lastPage;

    function page(isSPANavigation) {
      if (!(COMPILE_HASH && (!COMPILE_CONFIG || config.hashBasedRouting))) {
        if (isSPANavigation && lastPage === location.pathname) return;
      }

      lastPage = location.pathname
      trigger('pageview')
    }

    var onSPANavigation = function () { page(true) }

    if (COMPILE_HASH && (!COMPILE_CONFIG || config.hashBasedRouting)) {
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

      if (COMPILE_TAGGED_EVENTS) {
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
        if (COMPILE_REVENUE) {
          attrs.revenue = eventAttrs.revenue
        }
        plausible(eventAttrs.name, attrs)
        setTimeout(followLink, 5000)
        event.preventDefault()
      } else {
        var attrs = { props: eventAttrs.props }
        if (COMPILE_REVENUE) {
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
      var fileTypesToTrack = defaultFileTypes

      if (COMPILE_CONFIG) {
        if (Array.isArray(config.fileDownloads)) {
          fileTypesToTrack = config.fileDownloads
        }
      } else {
        var fileTypesAttr = scriptEl.getAttribute('file-types')
        var addFileTypesAttr = scriptEl.getAttribute('add-file-types')

        if (fileTypesAttr) {
          fileTypesToTrack = fileTypesAttr.split(",")
        }
        if (addFileTypesAttr) {
          fileTypesToTrack = addFileTypesAttr.split(",").concat(defaultFileTypes)
        }
      }

      function isDownloadToTrack(url) {
        if (!url) { return false }

        var fileType = url.split('.').pop();
        return fileTypesToTrack.some(function (fileTypeToTrack) {
          return fileTypeToTrack === fileType
        })
      }
    }

    if (COMPILE_CONFIG && config.formSubmissions) {
      function trackFormSubmission(e) {
        if (e.target.hasAttribute('novalidate') || e.target.checkValidity()) {
          plausible('Form Submission', { props: { path: location.pathname } });
        }
      }

      document.addEventListener('submit', trackFormSubmission, true);
    }

    if (COMPILE_TAGGED_EVENTS) {
      // Finds event attributes by iterating over the given element's (or its
      // parent's) classList. Returns an object with `name` and `props` keys.
      function getTaggedEventAttributes(htmlElement) {
        var taggedElement = isTagged(htmlElement) ? htmlElement : htmlElement && htmlElement.parentNode
        var eventAttrs = { name: null, props: {} }
        if (COMPILE_REVENUE) {
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

          if (COMPILE_REVENUE) {
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
        if (COMPILE_REVENUE) {
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
            if (COMPILE_REVENUE) {
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
