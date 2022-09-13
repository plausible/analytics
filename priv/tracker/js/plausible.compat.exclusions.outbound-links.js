!function(){"use strict";var t,e,i,u=window.location,p=window.document,c=p.getElementById("plausible"),d=c.getAttribute("data-api")||(t=c.src.split("/"),e=t[0],i=t[2],e+"//"+i+"/api/event");function f(t){console.warn("Ignoring Event: "+t)}function a(t,e){if(/^localhost$|^127(\.[0-9]+){0,2}\.[0-9]+$|^\[::1?\]$/.test(u.hostname)||"file:"===u.protocol)return f("localhost");if(!(window._phantom||window.__nightmare||window.navigator.webdriver||window.Cypress)){try{if("true"===window.localStorage.plausible_ignore)return f("localStorage flag")}catch(t){}var i=c&&c.getAttribute("data-include"),a=c&&c.getAttribute("data-exclude");if("pageview"===t){var n=!i||i&&i.split(",").some(s),r=a&&a.split(",").some(s);if(!n||r)return f("exclusion rule")}var o={};o.n=t,o.u=u.href,o.d=c.getAttribute("data-domain"),o.r=p.referrer||null,o.w=window.innerWidth,e&&e.meta&&(o.m=JSON.stringify(e.meta)),e&&e.props&&(o.p=e.props);var l=new XMLHttpRequest;l.open("POST",d,!0),l.setRequestHeader("Content-Type","text/plain"),l.send(JSON.stringify(o)),l.onreadystatechange=function(){4===l.readyState&&e&&e.callback&&e.callback()}}function s(t){return u.pathname.match(new RegExp("^"+t.trim().replace(/\*\*/g,".*").replace(/([^\.])\*/g,"$1[^\\s/]*")+"/?$"))}}var n=window.plausible&&window.plausible.q||[];window.plausible=a;for(var r,o=0;o<n.length;o++)a.apply(this,n[o]);function l(){r!==u.pathname&&(r=u.pathname,a("pageview"))}var s,w=window.history;w.pushState&&(s=w.pushState,w.pushState=function(){s.apply(this,arguments),l()},window.addEventListener("popstate",l)),"prerender"===p.visibilityState?p.addEventListener("visibilitychange",function(){r||"visible"!==p.visibilityState||l()}):l();var h=1;function v(t){if("auxclick"!==t.type||t.button===h){var e,i,a,n,r,o,l=function(t){for(;t&&(void 0===t.tagName||"a"!==t.tagName.toLowerCase()||!t.href);)t=t.parentNode;return t}(t.target);l&&l.href&&l.href.split("?")[0];if((o=l)&&o.href&&o.host&&o.host!==u.host){var s={url:l.href};return n=s,r=!(a="Outbound Link: Click"),void(!function(t,e){if(!t.defaultPrevented){var i=!e.target||e.target.match(/^_(self|parent|top)$/i),a=!(t.ctrlKey||t.metaKey||t.shiftKey)&&"click"===t.type;return i&&a}}(e=t,i=l)?plausible(a,{props:n}):(plausible(a,{props:n,callback:p}),setTimeout(p,5e3),e.preventDefault()))}}function p(){r||(r=!0,window.location=i.href)}}p.addEventListener("click",v),p.addEventListener("auxclick",v)}();