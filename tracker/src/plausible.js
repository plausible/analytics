(function(){
  'use strict';

  var location = window.location
  var document = window.document

  {{#if compat}}
  var scriptEl = document.getElementById('plausible');
  {{else}}
  var scriptEl = document.currentScript;
  {{/if}}
  var endpoint = scriptEl.getAttribute('data-api') || defaultEndpoint(scriptEl)

  function warn(reason) {
    console.warn('Ignoring Event: ' + reason);
  }

  function defaultEndpoint(el) {
    {{#if compat}}
    var pathArray = el.src.split( '/' );
    var protocol = pathArray[0];
    var host = pathArray[2];
    return protocol + '//' + host  + '/api/event';
    {{else}}
    return new URL(el.src).origin + '/api/event'
    {{/if}}
  }


  function trigger(eventName, options) {
    {{#unless local}}
    if (/^localhost$|^127(\.[0-9]+){0,2}\.[0-9]+$|^\[::1?\]$/.test(location.hostname) || location.protocol === 'file:') return warn('localhost');
    if (window._phantom || window.__nightmare || window.navigator.webdriver || window.Cypress) return;
    {{/unless}}
    try {
      if (window.localStorage.plausible_ignore === 'true') {
        return warn('localStorage flag')
      }
    } catch (e) {

    }
    {{#if exclusions}}
    var dataIncludeAttr = scriptEl && scriptEl.getAttribute('data-include')
    var dataExcludeAttr = scriptEl && scriptEl.getAttribute('data-exclude')

    if (eventName === 'pageview') {
      var isIncluded = !dataIncludeAttr || (dataIncludeAttr && dataIncludeAttr.split(',').some(pathMatches))
      var isExcluded = dataExcludeAttr && dataExcludeAttr.split(',').some(pathMatches)

      if (!isIncluded || isExcluded) return warn('exclusion rule')
    }

    function pathMatches(wildcardPath) {
      var actualPath = location.pathname

      {{#if hash}}
      actualPath += location.hash
      {{/if}}

      return actualPath.match(new RegExp('^' + wildcardPath.trim().replace(/\*\*/g, '.*').replace(/([^\.])\*/g, '$1[^\\s\/]*') + '\/?$'))
    }
    {{/if}}

    var payload = {}
    payload.n = eventName
    {{#if manual}}
    payload.u = options && options.u ? options.u : location.href
    {{else}}
    payload.u = location.href
    {{/if}}
    payload.d = scriptEl.getAttribute('data-domain')
    payload.r = document.referrer || null
    payload.w = window.innerWidth
    if (options && options.meta) {
      payload.m = JSON.stringify(options.meta)
    }
    if (options && options.props) {
      payload.p = options.props
    }

    {{#if dimensions}}
    var dimensionAttributes = scriptEl.getAttributeNames().filter(function (name) {
      return name.substring(0, 6) === 'event-'
    })

    var props = payload.p || {}

    dimensionAttributes.forEach(function(attribute) {
      var propKey = attribute.replace('event-', '')
      var propValue = scriptEl.getAttribute(attribute)
      props[propKey] = props[propKey] || propValue
    })

    payload.p = props
    {{/if}}

    {{#if hash}}
    payload.h = 1
    {{/if}}

    var request = new XMLHttpRequest();
    request.open('POST', endpoint, true);
    request.setRequestHeader('Content-Type', 'text/plain');

    request.send(JSON.stringify(payload));

    request.onreadystatechange = function() {
      if (request.readyState === 4) {
        options && options.callback && options.callback()
      }
    }
  }

  var queue = (window.plausible && window.plausible.q) || []
  window.plausible = trigger
  for (var i = 0; i < queue.length; i++) {
    trigger.apply(this, queue[i])
  }

  {{#unless manual}}
    var lastPage;

    function page() {
      {{#unless hash}}
      if (lastPage === location.pathname) return;
      {{/unless}}
      lastPage = location.pathname
      trigger('pageview')
    }

    {{#if hash}}
    window.addEventListener('hashchange', page)
    {{else}}
    var his = window.history
    if (his.pushState) {
      var originalPushState = his['pushState']
      his.pushState = function() {
        originalPushState.apply(this, arguments)
        page();
      }
      window.addEventListener('popstate', page)
    }
    {{/if}}

    function handleVisibilityChange() {
      if (!lastPage && document.visibilityState === 'visible') {
        page()
      }
    }

    if (document.visibilityState === 'prerender') {
      document.addEventListener('visibilitychange', handleVisibilityChange);
    } else {
      page()
    }
  {{/unless}}

  // CUSTOM EVENT TRACKING
  {{#if (any outbound_links file_downloads tagged_events)}}
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

    {{#if tagged_events}}
    if (isElementOrParentTagged(link, 0)) {
      // Return to prevent sending multiple events with the same action.
      // Clicks on tagged links are handled by another function.
      return
    }
    {{/if}}

    {{#if outbound_links}}
    if (isOutboundLink(link)) {
      return sendLinkClickEvent(event, link, {name: 'Outbound Link: Click', props: {url: link.href}})
    }
    {{/if}}

    {{#if file_downloads}}
    if (isDownloadToTrack(hrefWithoutQuery)) {
      return sendLinkClickEvent(event, link, {name: 'File Download', props: {url: hrefWithoutQuery}})
    }
    {{/if}}
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
      plausible(eventAttrs.name, { props: eventAttrs.props, callback: followLink })
      setTimeout(followLink, 5000)
      event.preventDefault()
    } else {
      plausible(eventAttrs.name, { props: eventAttrs.props })
    }
  }

  document.addEventListener('click', handleLinkClickEvent)
  document.addEventListener('auxclick', handleLinkClickEvent)
  {{/if}}

  {{#if outbound_links}}
  function isOutboundLink(link) {
    return link && link.href && link.host && link.host !== location.host
  }
  {{/if}}

  {{#if file_downloads}}
  var defaultFileTypes = ['pdf', 'xlsx', 'docx', 'txt', 'rtf', 'csv', 'exe', 'key', 'pps', 'ppt', 'pptx', '7z', 'pkg', 'rar', 'gz', 'zip', 'avi', 'mov', 'mp4', 'mpeg', 'wmv', 'midi', 'mp3', 'wav', 'wma']
  var fileTypesAttr = scriptEl.getAttribute('file-types')
  var addFileTypesAttr = scriptEl.getAttribute('add-file-types')
  var fileTypesToTrack = (fileTypesAttr && fileTypesAttr.split(",")) || (addFileTypesAttr && addFileTypesAttr.split(",").concat(defaultFileTypes)) || defaultFileTypes;

  function isDownloadToTrack(url) {
    if (!url) { return false }

    var fileType = url.split('.').pop();
    return fileTypesToTrack.some(function(fileTypeToTrack) {
      return fileTypeToTrack === fileType
    })
  }
  {{/if}}

  {{#if tagged_events}}
  // Finds event attributes by iterating over the given element's (or its
  // parent's) classList. Returns an object with `name` and `props` keys.
  function getTaggedEventAttributes(htmlElement) {
    var taggedElement = isTagged(htmlElement) ? htmlElement : htmlElement && htmlElement.parentNode
    var eventAttrs = { name: null, props: {} }

    var classList = taggedElement && taggedElement.classList
    if (!classList) { return eventAttrs }

    for (var i = 0; i < classList.length; i++) {
      var className = classList.item(i)

      var matchList = className.match(/plausible-event-(.+)=(.+)/)
      if (!matchList) { continue }

      var key = matchList[1]
      var value = matchList[2].replace(/\+/g, ' ')

      if (key.toLowerCase() === 'name') {
        eventAttrs.name = value
      } else {
        eventAttrs.props[key] = value
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
    plausible(eventAttrs.name, { props: eventAttrs.props, callback: submitForm })
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
        eventAttrs.props.url = clickedLink.href
        sendLinkClickEvent(event, clickedLink, eventAttrs)
      } else {
        plausible(eventAttrs.name, { props: eventAttrs.props })
      }
    }
  }

  function isTagged(element) {
    var classList = element && element.classList
    if (classList) {
      for (var i = 0; i < classList.length; i++) {
        if (classList.item(i).match(/plausible-event-name=(.+)/)) { return true }
      }
    }
    return false
  }

  function isElementOrParentTagged(element, parentsChecked) {
    if (!element || parentsChecked > PARENTS_TO_SEARCH_LIMIT) { return false }
    if (isTagged(element)) {return true}
    return isElementOrParentTagged(element.parentNode, parentsChecked + 1)
  }

  document.addEventListener('submit', handleTaggedFormSubmitEvent)
  document.addEventListener('click', handleTaggedElementClickEvent)
  document.addEventListener('auxclick', handleTaggedElementClickEvent)
  {{/if}}
})();
