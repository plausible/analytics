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
  var plausible_ignore = window.localStorage.plausible_ignore;
  {{#if exclusions}}
  var excludedPaths = scriptEl && scriptEl.getAttribute('data-exclude').split(',');
  {{/if}}
  var lastPage;

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
    if (/^localhost$|^127(?:\.[0-9]+){0,2}\.[0-9]+$|^(?:0*\:)*?:?0*1$/.test(location.hostname) || location.protocol === 'file:') return warn('localhost');
    if (window.phantom || window._phantom || window.__nightmare || window.navigator.webdriver || window.Cypress) return;
    if (plausible_ignore=="true") return warn('localStorage flag')
    {{#if exclusions}}
    if (excludedPaths)
      for (var i = 0; i < excludedPaths.length; i++)
        if (eventName == "pageview" && location.pathname.match(new RegExp('^' + excludedPaths[i].trim().replace(/\*\*/g, '.*').replace(/([^\.])\*/g, '$1[^\\s\/]*') + '\/?$')))
          return warn('exclusion rule');
    {{/if}}

    var payload = {}
    payload.n = eventName
    payload.u = location.href
    payload.d = scriptEl.getAttribute('data-domain')
    payload.r = document.referrer || null
    payload.w = window.innerWidth
    if (options && options.meta) {
      payload.m = JSON.stringify(options.meta)
    }
    if (options && options.props) {
      payload.p = JSON.stringify(options.props)
    }
    {{#if hash}}
    payload.h = 1
    {{/if}}

    var request = new XMLHttpRequest();
    request.open('POST', endpoint, true);
    request.setRequestHeader('Content-Type', 'text/plain');

    request.send(JSON.stringify(payload));

    request.onreadystatechange = function() {
      if (request.readyState == 4) {
        options && options.callback && options.callback()
      }
    }
  }

  function page() {
    {{#unless hash}}
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

  {{#if outbound_links}}
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

  {{#if outbound_links}}
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
})();
