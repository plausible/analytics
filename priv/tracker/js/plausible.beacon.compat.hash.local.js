!function(){"use strict";var e,i,t,a=window.location,r=window.document,o=r.getElementById("plausible"),s=o.getAttribute("data-api")||(e=o.src.split("/"),i=e[0],t=e[2],i+"//"+t+"/api/event");function n(e,i){if(!(window._phantom||window.__nightmare||window.navigator.webdriver||window.Cypress)){try{if("true"==window.localStorage.plausible_ignore)return void console.warn("Ignoring Event: localStorage flag")}catch(e){}var t={};t.n=e,t.u=a.href,t.d=o.getAttribute("data-domain"),t.r=r.referrer||null,t.w=window.innerWidth,i&&i.meta&&(t.m=JSON.stringify(i.meta)),i&&i.props&&(t.p=JSON.stringify(i.props)),t.h=1;var n=new XMLHttpRequest;n.open("POST",s,!0),n.setRequestHeader("Content-Type","text/plain"),n.send(JSON.stringify(t)),n.onreadystatechange=function(){var e;4==n.readyState&&((e=n.responseText)&&!isNaN(e)&&(w=e,console.log("changed lastEventId to ",w)),i&&i.callback&&i.callback())}}}var d=window.plausible&&window.plausible.q||[];window.plausible=n;for(var l,w,c=0;c<d.length;c++)n.apply(this,d[c]);function p(){l=a.pathname,n("pageview")}function v(){"visible"!==r.visibilityState&&w&&navigator.sendBeacon(s,JSON.stringify({n:"enrich",e:w}))}window.addEventListener("hashchange",p),"prerender"===r.visibilityState?r.addEventListener("visibilitychange",function(){l||"visible"!==r.visibilityState||p()}):p(),r.addEventListener("visibilitychange",v),r.addEventListener("pagehide",v),window.addEventListener("beforeunload",v)}();