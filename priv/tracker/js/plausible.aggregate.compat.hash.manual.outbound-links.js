!function(){"use strict";var t,e,a,r=window.location,l=window.document,n=window.localStorage,s=l.getElementById("plausible"),c=s.getAttribute("data-api")||(t=s.src.split("/"),e=t[0],a=t[2],e+"//"+a+"/api/event"),d=n&&n.plausible_ignore;function u(t){console.warn("Ignoring Event: "+t)}function i(t,e){if(/^localhost$|^127(\.[0-9]+){0,2}\.[0-9]+$|^\[::1?\]$/.test(r.hostname)||"file:"===r.protocol)return u("localhost");if(!(window.phantom||window._phantom||window.__nightmare||window.navigator.webdriver||window.Cypress)){if("true"==d)return u("localStorage flag");var a={};a.n=t;var n=s.getAttribute("data-location"),i=window[s.getAttribute("data-get-location")]||function(){return r.href};a.u=n||i(),a.d=s.getAttribute("data-domain"),a.r=l.referrer||null,a.w=window.innerWidth,e&&e.meta&&(a.m=JSON.stringify(e.meta)),e&&e.props&&(a.p=JSON.stringify(e.props)),a.h=1;var o=new XMLHttpRequest;o.open("POST",c,!0),o.setRequestHeader("Content-Type","text/plain"),o.send(JSON.stringify(a)),o.onreadystatechange=function(){4==o.readyState&&e&&e.callback&&e.callback()}}}function o(t){for(var e=t.target,a="auxclick"==t.type&&2==t.which,n="click"==t.type;e&&(void 0===e.tagName||"a"!=e.tagName.toLowerCase()||!e.href);)e=e.parentNode;e&&e.href&&e.host&&e.host!==r.host&&((a||n)&&plausible("Outbound Link: Click",{props:{url:e.href}}),e.target&&!e.target.match(/^_(self|parent|top)$/i)||t.ctrlKey||t.metaKey||t.shiftKey||!n||(setTimeout(function(){r.href=e.href},150),t.preventDefault()))}l.addEventListener("click",o),l.addEventListener("auxclick",o);var p=window.plausible&&window.plausible.q||[];window.plausible=i;for(var w=0;w<p.length;w++)i.apply(this,p[w])}();