!function(){"use strict";var r=window.location,l=window.document,t=window.localStorage,s=l.currentScript,w=s.getAttribute("data-api")||new URL(s.src).origin+"/api/event",d=t&&t.plausible_ignore;function p(t){console.warn("Ignoring Event: "+t)}function e(t,e){if(/^localhost$|^127(\.[0-9]+){0,2}\.[0-9]+$|^\[::1?\]$/.test(r.hostname)||"file:"===r.protocol)return p("localhost");if(!(window.phantom||window._phantom||window.__nightmare||window.navigator.webdriver||window.Cypress)){if("true"==d)return p("localStorage flag");var i={};i.n=t;var n=s.getAttribute("data-location"),a=window[s.getAttribute("data-get-location")]||function(){return r.href};i.u=n||a(),i.d=s.getAttribute("data-domain"),i.r=l.referrer||null,i.w=window.innerWidth,e&&e.meta&&(i.m=JSON.stringify(e.meta)),e&&e.props&&(i.p=JSON.stringify(e.props));var o=new XMLHttpRequest;o.open("POST",w,!0),o.setRequestHeader("Content-Type","text/plain"),o.send(JSON.stringify(i)),o.onreadystatechange=function(){4==o.readyState&&e&&e.callback&&e.callback()}}}var i=window.plausible&&window.plausible.q||[];window.plausible=e;for(var n,a=0;a<i.length;a++)e.apply(this,i[a]);function o(){n!==r.pathname&&(n=r.pathname,e("pageview"))}var u,c=window.history;c.pushState&&(u=c.pushState,c.pushState=function(){u.apply(this,arguments),o()},window.addEventListener("popstate",o)),"prerender"===l.visibilityState?l.addEventListener("visibilitychange",function(){n||"visible"!==l.visibilityState||o()}):o()}();