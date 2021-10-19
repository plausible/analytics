!function(){"use strict";var l=window.location,c=window.document,t=window.localStorage,s=c.currentScript,u=s.getAttribute("data-api")||new URL(s.src).origin+"/api/event",p=t&&t.plausible_ignore,d=s&&s.getAttribute("data-exclude").split(",");function w(t){console.warn("Ignoring Event: "+t)}function e(t,e){if(/^localhost$|^127(\.[0-9]+){0,2}\.[0-9]+$|^\[::1?\]$/.test(l.hostname)||"file:"===l.protocol)return w("localhost");if(!(window.phantom||window._phantom||window.__nightmare||window.navigator.webdriver||window.Cypress)){if("true"==p)return w("localStorage flag");if(d)for(var a=0;a<d.length;a++)if("pageview"==t&&l.pathname.match(new RegExp("^"+d[a].trim().replace(/\*\*/g,".*").replace(/([^\.])\*/g,"$1[^\\s/]*")+"/?$")))return w("exclusion rule");var n={};n.n=t;var i=s.getAttribute("data-location"),r=window[s.getAttribute("data-get-location")]||function(){return l.href};n.u=i||r(),n.d=s.getAttribute("data-domain"),n.r=c.referrer||null,n.w=window.innerWidth,e&&e.meta&&(n.m=JSON.stringify(e.meta)),e&&e.props&&(n.p=JSON.stringify(e.props)),n.h=1;var o=new XMLHttpRequest;o.open("POST",u,!0),o.setRequestHeader("Content-Type","text/plain"),o.send(JSON.stringify(n)),o.onreadystatechange=function(){4==o.readyState&&e&&e.callback&&e.callback()}}}function a(t){for(var e=t.target,a="auxclick"==t.type&&2==t.which,n="click"==t.type;e&&(void 0===e.tagName||"a"!=e.tagName.toLowerCase()||!e.href);)e=e.parentNode;e&&e.href&&e.host&&e.host!==l.host&&((a||n)&&plausible("Outbound Link: Click",{props:{url:e.href}}),e.target&&!e.target.match(/^_(self|parent|top)$/i)||t.ctrlKey||t.metaKey||t.shiftKey||!n||(setTimeout(function(){l.href=e.href},150),t.preventDefault()))}c.addEventListener("click",a),c.addEventListener("auxclick",a);var n=window.plausible&&window.plausible.q||[];window.plausible=e;for(var i=0;i<n.length;i++)e.apply(this,n[i])}();