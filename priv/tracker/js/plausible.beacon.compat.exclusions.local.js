!function(){"use strict";var e,t,i,r=window.location,o=window.document,s=o.getElementById("plausible"),d=s.getAttribute("data-api")||(e=s.src.split("/"),t=e[0],i=e[2],t+"//"+i+"/api/event"),l=s&&s.getAttribute("data-exclude").split(",");function p(e){console.warn("Ignoring Event: "+e)}function n(e,t){if(!(window._phantom||window.__nightmare||window.navigator.webdriver||window.Cypress)){try{if("true"==window.localStorage.plausible_ignore)return p("localStorage flag")}catch(e){}if(l)for(var i=0;i<l.length;i++)if("pageview"==e&&r.pathname.match(new RegExp("^"+l[i].trim().replace(/\*\*/g,".*").replace(/([^\.])\*/g,"$1[^\\s/]*")+"/?$")))return p("exclusion rule");var n={};if(n.n=e,n.u=r.href,n.d=s.getAttribute("data-domain"),"pageview_end"==e)return navigator.sendBeacon(d,JSON.stringify(n));n.r=o.referrer||null,n.w=window.innerWidth,t&&t.meta&&(n.m=JSON.stringify(t.meta)),t&&t.props&&(n.p=JSON.stringify(t.props));var a=new XMLHttpRequest;a.open("POST",d,!0),a.setRequestHeader("Content-Type","text/plain"),a.send(JSON.stringify(n)),a.onreadystatechange=function(){4==a.readyState&&t&&t.callback&&t.callback()}}}var a=window.plausible&&window.plausible.q||[];window.plausible=n;for(var w,u=0;u<a.length;u++)n.apply(this,a[u]);function c(){w!==r.pathname&&(w=r.pathname)}var g,v=window.history;function f(){"visible"!==o.visibilityState&&n("pageview_end")}v.pushState&&(g=v.pushState,v.pushState=function(){g.apply(this,arguments),c()},window.addEventListener("popstate",c)),"prerender"===o.visibilityState?o.addEventListener("visibilitychange",function(){w||"visible"!==o.visibilityState||c()}):c(),o.addEventListener("visibilitychange",f),o.addEventListener("pagehide",f),window.addEventListener("beforeunload",f)}();