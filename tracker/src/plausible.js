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

  {{#if outbound_links}}
  function handleOutbound(event) {
    var link = event.target;
    var middle = event.type === 'auxclick' && event.which === 2;
    var click = event.type === 'click';
      while(link && (typeof link.tagName === 'undefined' || link.tagName.toLowerCase() !== 'a' || !link.href)) {
        link = link.parentNode
      }

      if (link && link.href && link.host && link.host !== location.host) {
        if (middle || click) {
          plausible('Outbound Link: Click', {props: {url: link.href}})
        }

        // Delay navigation so that Plausible is notified of the click
        if(!link.target || link.target.match(/^_(self|parent|top)$/i)) {
          if (!(event.ctrlKey || event.metaKey || event.shiftKey) && click) {
            setTimeout(function() {
              location.href = link.href;
            }, 150);
            event.preventDefault();
          }
        }
      }
  }

  function registerOutboundLinkEvents() {
    document.addEventListener('click', handleOutbound)
    document.addEventListener('auxclick', handleOutbound)
  }
  {{/if}}

  {{#if outbound_links}}
  registerOutboundLinkEvents()
  {{/if}}

  {{#if file_downloads}}
  var defaultFileTypes = ['pdf', 'xlsx', 'docx', 'txt', 'rtf', 'csv', 'exe', 'key', 'pps', 'ppt', 'pptx', '7z', 'pkg', 'rar', 'gz', 'zip', 'avi', 'mov', 'mp4', 'mpeg', 'wmv', 'midi', 'mp3', 'wav', 'wma']
  var fileTypesAttr = scriptEl.getAttribute('file-types')
  var addFileTypesAttr = scriptEl.getAttribute('add-file-types')
  var fileTypesToTrack = (fileTypesAttr && fileTypesAttr.split(",")) || (addFileTypesAttr && addFileTypesAttr.split(",").concat(defaultFileTypes)) || defaultFileTypes;

  function handleDownload(event) {

    var link = event.target;
    var middle = event.type === 'auxclick' && event.which === 2;
    var click = event.type === 'click';

    while(link && (typeof link.tagName === 'undefined' || link.tagName.toLowerCase() !== 'a' || !link.href)) {
      link = link.parentNode
    }

    var linkTarget = link && link.href && link.href.split('?')[0]
    if (linkTarget && isDownloadToTrack(linkTarget)) {

      if (middle || click) {
        plausible('File Download', {props: {url: linkTarget}})
      }

      // Delay navigation so that Plausible is notified of the click
      if(!link.target || link.target.match(/^_(self|parent|top)$/i)) {
        if (!(event.ctrlKey || event.metaKey || event.shiftKey) && click) {
          setTimeout(function() {
            location.href = link.href;
          }, 150);
          event.preventDefault();
        }
      }
    }
  }

  function isDownloadToTrack(url) {
    var fileType = url.split('.').pop();
    return fileTypesToTrack.some(function(fileTypeToTrack) {
      return fileTypeToTrack === fileType
    })
  }

  document.addEventListener('click', handleDownload);
  document.addEventListener('auxclick', handleDownload);
  {{/if}}

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
})();
