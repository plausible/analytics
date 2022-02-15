!function(){"use strict";var e,t,i,r=window.location,o=window.document,s=o.getElementById("plausible"),l=s.getAttribute("data-api")||(e=s.src.split("/"),t=e[0],i=e[2],t+"//"+i+"/api/event"),d=s&&s.getAttribute("data-exclude").split(",");function c(e){console.warn("Ignoring Event: "+e)}function n(e,t){if(/^localhost$|^127(\.[0-9]+){0,2}\.[0-9]+$|^\[::1?\]$/.test(r.hostname)||"file:"===r.protocol)return c("localhost");if(!(window._phantom||window.__nightmare||window.navigator.webdriver||window.Cypress)){try{if("true"==window.localStorage.plausible_ignore)return c("localStorage flag")}catch(e){}if(d)for(var i=0;i<d.length;i++)if("pageview"==e&&r.pathname.match(new RegExp("^"+d[i].trim().replace(/\*\*/g,".*").replace(/([^\.])\*/g,"$1[^\\s/]*")+"/?$")))return c("exclusion rule");var n={};n.n=e,n.u=r.href,n.d=s.getAttribute("data-domain"),n.r=o.referrer||null,n.w=window.innerWidth,t&&t.meta&&(n.m=JSON.stringify(t.meta)),t&&t.props&&(n.p=JSON.stringify(t.props));var a=new XMLHttpRequest;a.open("POST",l,!0),a.setRequestHeader("Content-Type","text/plain"),a.send(JSON.stringify(n)),a.onreadystatechange=function(){var e;4==a.readyState&&((e=a.responseText)&&!isNaN(e)&&(g=e,console.log("changed lastEventId to ",g)),t&&t.callback&&t.callback())}}}function a(e){for(var t=e.target,i="auxclick"==e.type&&2==e.which,n="click"==e.type;t&&(void 0===t.tagName||"a"!=t.tagName.toLowerCase()||!t.href);)t=t.parentNode;t&&t.href&&t.host&&t.host!==r.host&&((i||n)&&plausible("Outbound Link: Click",{props:{url:t.href}}),t.target&&!t.target.match(/^_(self|parent|top)$/i)||e.ctrlKey||e.metaKey||e.shiftKey||!n||(setTimeout(function(){r.href=t.href},150),e.preventDefault()))}o.addEventListener("click",a),o.addEventListener("auxclick",a);var p=window.plausible&&window.plausible.q||[];window.plausible=n;for(var u,h=0;h<p.length;h++)n.apply(this,p[h]);function w(){u!==r.pathname&&(u=r.pathname,n("pageview"))}var f,g,v=window.history;function y(){"visible"!==o.visibilityState&&g&&navigator.sendBeacon(l,JSON.stringify({n:"enrich",e:g}))}v.pushState&&(f=v.pushState,v.pushState=function(){f.apply(this,arguments),w()},window.addEventListener("popstate",w)),"prerender"===o.visibilityState?o.addEventListener("visibilitychange",function(){u||"visible"!==o.visibilityState||w()}):w(),o.addEventListener("visibilitychange",y),o.addEventListener("pagehide",y),window.addEventListener("beforeunload",y)}();