!function(){"use strict";var a=window.location,r=window.document,o=r.currentScript,s=o.getAttribute("data-api")||new URL(o.src).origin+"/api/event";function e(e,t){if(!(window._phantom||window.__nightmare||window.navigator.webdriver||window.Cypress)){try{if("true"==window.localStorage.plausible_ignore)return void console.warn("Ignoring Event: localStorage flag")}catch(e){}var i={};i.n=e,i.u=a.href,i.d=o.getAttribute("data-domain"),i.r=r.referrer||null,i.w=window.innerWidth,t&&t.meta&&(i.m=JSON.stringify(t.meta)),t&&t.props&&(i.p=JSON.stringify(t.props));var n=new XMLHttpRequest;n.open("POST",s,!0),n.setRequestHeader("Content-Type","text/plain"),n.send(JSON.stringify(i)),n.onreadystatechange=function(){var e;4==n.readyState&&((e=n.responseText)&&!isNaN(e)&&(w=e,console.log("changed lastEventId to ",w)),t&&t.callback&&t.callback())}}}var t=window.plausible&&window.plausible.q||[];window.plausible=e;for(var i,n=0;n<t.length;n++)e.apply(this,t[n]);function d(){i!==a.pathname&&(i=a.pathname,e("pageview"))}var l,w,p=window.history;function c(){"visible"!==r.visibilityState&&w&&navigator.sendBeacon(s,JSON.stringify({n:"enrich",e:w}))}p.pushState&&(l=p.pushState,p.pushState=function(){l.apply(this,arguments),d()},window.addEventListener("popstate",d)),"prerender"===r.visibilityState?r.addEventListener("visibilitychange",function(){i||"visible"!==r.visibilityState||d()}):d(),r.addEventListener("visibilitychange",c),r.addEventListener("pagehide",c),window.addEventListener("beforeunload",c)}();