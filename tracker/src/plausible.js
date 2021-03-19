(function(window, plausibleHost){
  'use strict';

  var location = window.location
  var document = window.document

  var scriptEl = document.querySelector('[src*="' + plausibleHost +'"]')
  var domain = scriptEl && scriptEl.getAttribute('data-domain')
  var plausible_ignore = window.localStorage.plausible_ignore;
  {{#if exclusionMode}}
  var excludedPaths = scriptEl && scriptEl.getAttribute('data-exclude').split(',');
  {{/if}}
  var lastPage;

  function warn(reason) {
    console.warn('Ignoring Event: ' + reason);
  }

  function trigger(eventName, options) {
    if (/^localhost$|^127(?:\.[0-9]+){0,2}\.[0-9]+$|^(?:0*\:)*?:?0*1$/.test(location.hostname) || location.protocol === 'file:') return warn('localhost');
    if (window.phantom || window._phantom || window.__nightmare || window.navigator.webdriver || window.Cypress) return;
    if (plausible_ignore=="true") return warn('localStorage flag')
    {{#if exclusionMode}}
    if (excludedPaths)
      for (var i = 0; i < excludedPaths.length; i++)
        if (eventName == "pageview" && location.pathname.match(new RegExp('^' + excludedPaths[i].trim().replace(/\*\*/g, '.*').replace(/([^\.])\*/g, '$1[^\\s\/]*') + '\/?$')))
          return warn('exclusion rule');
    {{/if}}

    var payload = {}
    payload.n = eventName
    payload.u = location.href
    payload.d = domain
    payload.r = document.referrer || null
    payload.w = window.innerWidth
    if (options && options.meta) {
      payload.m = JSON.stringify(options.meta)
    }
    if (options && options.props) {
      payload.p = JSON.stringify(options.props)
    }
    {{#if hashMode}}
    payload.h = 1
    {{/if}}

    var request = new XMLHttpRequest();
    request.open('POST', plausibleHost + '/api/event', true);
    request.setRequestHeader('Content-Type', 'text/plain');

    request.send(JSON.stringify(payload));

    request.onreadystatechange = function() {
      if (request.readyState == 4) {
        options && options.callback && options.callback()
      }
    }
  }

  function page() {
    {{#unless hashMode}}
    if (lastPage === location.pathname) return;
    {{/unless}}
    lastPage = location.pathname
    trigger('pageview')
  }

  function handleVisibilityChange() {
    if (!lastPage && document.visibilityState === 'visible') {
      page()
    }
  }

  {{#if outboundLinks}}
  function handleOutbound(event) {
    var link = event.target;
    var middle = event.type == "auxclick" && event.which == 2;
    var click = event.type == "click";
      while(link && (typeof link.tagName == 'undefined' || link.tagName.toLowerCase() != 'a' || !link.href)) {
        link = link.parentNode
      }

      if (link && link.href && link.host && link.host !== location.host) {
        if (middle || click)
        plausible('Outbound Link: Click', {props: {url: link.href}})

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

  try {
    {{#if hashMode}}
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
    {{#if outboundLinks}}
    registerOutboundLinkEvents()
    {{/if}}


    var queue = (window.plausible && window.plausible.q) || []
    window.plausible = trigger
    for (var i = 0; i < queue.length; i++) {
      trigger.apply(this, queue[i])
    }

    if (document.visibilityState === 'prerender') {
      document.addEventListener("visibilitychange", handleVisibilityChange);
    } else {
      page()
    }
  } catch (e) {
    console.error(e)
    new Image().src = plausibleHost + '/api/error?message=' +  encodeURIComponent(e.message);
  }
})(window, '<%= base_url %>');
