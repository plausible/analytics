!function(){"use strict";var e,t,i,r=window.location,o=window.document,l=o.getElementById("plausible"),s=l.getAttribute("data-api")||(e=l.src.split("/"),t=e[0],i=e[2],t+"//"+i+"/api/event"),p=l&&l.getAttribute("data-exclude").split(",");function c(e){console.warn("Ignoring Event: "+e)}function a(e,t){if(!(window._phantom||window.__nightmare||window.navigator.webdriver||window.Cypress)){try{if("true"==window.localStorage.plausible_ignore)return c("localStorage flag")}catch(e){}if(p)for(var i=0;i<p.length;i++)if("pageview"==e&&r.pathname.match(new RegExp("^"+p[i].trim().replace(/\*\*/g,".*").replace(/([^\.])\*/g,"$1[^\\s/]*")+"/?$")))return c("exclusion rule");var a={};if(a.n=e,a.u=r.href,a.d=l.getAttribute("data-domain"),"pageview_end"==e)return navigator.sendBeacon(s,JSON.stringify(a));a.r=o.referrer||null,a.w=window.innerWidth,t&&t.meta&&(a.m=JSON.stringify(t.meta)),t&&t.props&&(a.p=JSON.stringify(t.props));var n=new XMLHttpRequest;n.open("POST",s,!0),n.setRequestHeader("Content-Type","text/plain"),n.send(JSON.stringify(a)),n.onreadystatechange=function(){4==n.readyState&&t&&t.callback&&t.callback()}}}function n(e){for(var t=e.target,i="auxclick"==e.type&&2==e.which,a="click"==e.type;t&&(void 0===t.tagName||"a"!=t.tagName.toLowerCase()||!t.href);)t=t.parentNode;t&&t.href&&t.host&&t.host!==r.host&&((i||a)&&plausible("Outbound Link: Click",{props:{url:t.href}}),t.target&&!t.target.match(/^_(self|parent|top)$/i)||e.ctrlKey||e.metaKey||e.shiftKey||!a||(setTimeout(function(){r.href=t.href},150),e.preventDefault()))}o.addEventListener("click",n),o.addEventListener("auxclick",n);var d=window.plausible&&window.plausible.q||[];window.plausible=a;for(var u,w=0;w<d.length;w++)a.apply(this,d[w]);function f(){u!==r.pathname&&(u=r.pathname)}var g,h=window.history;h.pushState&&(g=h.pushState,h.pushState=function(){g.apply(this,arguments),f()},window.addEventListener("popstate",f)),"prerender"===o.visibilityState?o.addEventListener("visibilitychange",function(){u||"visible"!==o.visibilityState||f()}):f()}();