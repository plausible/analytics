!function(){"use strict";var a=window.location,r=window.document,o=r.currentScript,w=o.getAttribute("data-api")||new URL(o.src).origin+"/api/event";function e(e,i){if(!(window._phantom||window.__nightmare||window.navigator.webdriver||window.Cypress)){try{if("true"==window.localStorage.plausible_ignore)return void console.warn("Ignoring Event: localStorage flag")}catch(e){}var t={};t.n=e,t.u=a.href,t.d=o.getAttribute("data-domain"),t.r=r.referrer||null,t.w=window.innerWidth,i&&i.meta&&(t.m=JSON.stringify(i.meta)),i&&i.props&&(t.p=JSON.stringify(i.props)),t.h=1;var n=new XMLHttpRequest;n.open("POST",w,!0),n.setRequestHeader("Content-Type","text/plain"),n.send(JSON.stringify(t)),n.onreadystatechange=function(){4==n.readyState&&i&&i.callback&&i.callback()}}}var i=window.plausible&&window.plausible.q||[];window.plausible=e;for(var t,n=0;n<i.length;n++)e.apply(this,i[n]);function d(){t=a.pathname,e("pageview")}window.addEventListener("hashchange",d),"prerender"===r.visibilityState?r.addEventListener("visibilitychange",function(){t||"visible"!==r.visibilityState||d()}):d()}();