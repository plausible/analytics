!function(){"use strict";var a=window.location,r=window.document,o=r.currentScript,s=o.getAttribute("data-api")||new URL(o.src).origin+"/api/event";function e(e,t){if(!(window._phantom||window.__nightmare||window.navigator.webdriver||window.Cypress)){try{if("true"==window.localStorage.plausible_ignore)return void console.warn("Ignoring Event: localStorage flag")}catch(e){}var i={};i.n=e,i.u=a.href,i.d=o.getAttribute("data-domain"),i.r=r.referrer||null,i.w=window.innerWidth,t&&t.meta&&(i.m=JSON.stringify(t.meta)),t&&t.props&&(i.p=JSON.stringify(t.props));var n=new XMLHttpRequest;n.open("POST",s,!0),n.setRequestHeader("Content-Type","text/plain"),n.send(JSON.stringify(i)),n.onreadystatechange=function(){var e;4==n.readyState&&((e=n.responseText)&&!isNaN(e)&&(p=e,console.log("changed lastEventId to ",p)),t&&t.callback&&t.callback())}}}function t(e){for(var t=e.target,i="auxclick"==e.type&&2==e.which,n="click"==e.type;t&&(void 0===t.tagName||"a"!=t.tagName.toLowerCase()||!t.href);)t=t.parentNode;t&&t.href&&t.host&&t.host!==a.host&&((i||n)&&plausible("Outbound Link: Click",{props:{url:t.href}}),t.target&&!t.target.match(/^_(self|parent|top)$/i)||e.ctrlKey||e.metaKey||e.shiftKey||!n||(setTimeout(function(){a.href=t.href},150),e.preventDefault()))}r.addEventListener("click",t),r.addEventListener("auxclick",t);var i=window.plausible&&window.plausible.q||[];window.plausible=e;for(var n,d=0;d<i.length;d++)e.apply(this,i[d]);function l(){n!==a.pathname&&(n=a.pathname,e("pageview"))}var c,p,u=window.history;function w(){"visible"!==r.visibilityState&&p&&navigator.sendBeacon(s,JSON.stringify({n:"enrich",e:p}))}u.pushState&&(c=u.pushState,u.pushState=function(){c.apply(this,arguments),l()},window.addEventListener("popstate",l)),"prerender"===r.visibilityState?r.addEventListener("visibilitychange",function(){n||"visible"!==r.visibilityState||l()}):l(),r.addEventListener("visibilitychange",w),r.addEventListener("pagehide",w),window.addEventListener("beforeunload",w)}();