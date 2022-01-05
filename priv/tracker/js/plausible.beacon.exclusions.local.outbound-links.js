!function(){"use strict";var r=window.location,o=window.document,s=o.currentScript,l=s.getAttribute("data-api")||new URL(s.src).origin+"/api/event",d=s&&s.getAttribute("data-exclude").split(",");function p(e){console.warn("Ignoring Event: "+e)}function e(e,t){if(!(window._phantom||window.__nightmare||window.navigator.webdriver||window.Cypress)){try{if("true"==window.localStorage.plausible_ignore)return p("localStorage flag")}catch(e){}if(d)for(var i=0;i<d.length;i++)if("pageview"==e&&r.pathname.match(new RegExp("^"+d[i].trim().replace(/\*\*/g,".*").replace(/([^\.])\*/g,"$1[^\\s/]*")+"/?$")))return p("exclusion rule");var n={};if(n.n=e,n.u=r.href,n.d=s.getAttribute("data-domain"),"pageview_end"==e)return navigator.sendBeacon(l,JSON.stringify(n));n.r=o.referrer||null,n.w=window.innerWidth,t&&t.meta&&(n.m=JSON.stringify(t.meta)),t&&t.props&&(n.p=JSON.stringify(t.props));var a=new XMLHttpRequest;a.open("POST",l,!0),a.setRequestHeader("Content-Type","text/plain"),a.send(JSON.stringify(n)),a.onreadystatechange=function(){4==a.readyState&&t&&t.callback&&t.callback()}}}function t(e){for(var t=e.target,i="auxclick"==e.type&&2==e.which,n="click"==e.type;t&&(void 0===t.tagName||"a"!=t.tagName.toLowerCase()||!t.href);)t=t.parentNode;t&&t.href&&t.host&&t.host!==r.host&&((i||n)&&plausible("Outbound Link: Click",{props:{url:t.href}}),t.target&&!t.target.match(/^_(self|parent|top)$/i)||e.ctrlKey||e.metaKey||e.shiftKey||!n||(setTimeout(function(){r.href=t.href},150),e.preventDefault()))}o.addEventListener("click",t),o.addEventListener("auxclick",t);var i=window.plausible&&window.plausible.q||[];window.plausible=e;for(var n,a=0;a<i.length;a++)e.apply(this,i[a]);function c(){n!==r.pathname&&(n=r.pathname)}var u,w=window.history;function f(){"visible"!==o.visibilityState&&e("pageview_end")}w.pushState&&(u=w.pushState,w.pushState=function(){u.apply(this,arguments),c()},window.addEventListener("popstate",c)),"prerender"===o.visibilityState?o.addEventListener("visibilitychange",function(){n||"visible"!==o.visibilityState||c()}):c(),o.addEventListener("visibilitychange",f),o.addEventListener("pagehide",f),window.addEventListener("beforeunload",f)}();