!function(){"use strict";var e,i,t,a=window.location,r=window.document,o=r.getElementById("plausible"),d=o.getAttribute("data-api")||(e=o.src.split("/"),i=e[0],t=e[2],i+"//"+t+"/api/event");function n(e,i){if(!(window._phantom||window.__nightmare||window.navigator.webdriver||window.Cypress)){try{if("true"==window.localStorage.plausible_ignore)return void console.warn("Ignoring Event: localStorage flag")}catch(e){}var t={};if(t.n=e,t.u=a.href,t.d=o.getAttribute("data-domain"),"pageview_end"==e)return navigator.sendBeacon(d,JSON.stringify(t));t.r=r.referrer||null,t.w=window.innerWidth,i&&i.meta&&(t.m=JSON.stringify(i.meta)),i&&i.props&&(t.p=JSON.stringify(i.props)),t.h=1;var n=new XMLHttpRequest;n.open("POST",d,!0),n.setRequestHeader("Content-Type","text/plain"),n.send(JSON.stringify(t)),n.onreadystatechange=function(){4==n.readyState&&i&&i.callback&&i.callback()}}}var s=window.plausible&&window.plausible.q||[];window.plausible=n;for(var l,w=0;w<s.length;w++)n.apply(this,s[w]);function p(){l=a.pathname}function v(){"visible"!==r.visibilityState&&n("pageview_end")}window.addEventListener("hashchange",p),"prerender"===r.visibilityState?r.addEventListener("visibilitychange",function(){l||"visible"!==r.visibilityState||p()}):p(),r.addEventListener("visibilitychange",v),r.addEventListener("pagehide",v),window.addEventListener("beforeunload",v)}();