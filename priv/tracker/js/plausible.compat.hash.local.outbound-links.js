!function(){"use strict";var e,t,i,a=window.location,r=window.document,n=window.localStorage,o=r.getElementById("plausible"),l=o.getAttribute("data-api")||(e=o.src.split("/"),t=e[0],i=e[2],t+"//"+i+"/api/event"),s=n&&n.plausible_ignore;function d(e,t){var i,n;window.phantom||window._phantom||window.__nightmare||window.navigator.webdriver||window.Cypress||("true"!=s?((i={}).n=e,i.u=a.href,i.d=o.getAttribute("data-domain"),i.r=r.referrer||null,i.w=window.innerWidth,t&&t.meta&&(i.m=JSON.stringify(t.meta)),t&&t.props&&(i.p=JSON.stringify(t.props)),i.h=1,(n=new XMLHttpRequest).open("POST",l,!0),n.setRequestHeader("Content-Type","text/plain"),n.send(JSON.stringify(i)),n.onreadystatechange=function(){4==n.readyState&&t&&t.callback&&t.callback()}):console.warn("Ignoring Event: localStorage flag"))}function p(e){for(var t=e.target,i="auxclick"==e.type&&2==e.which,n="click"==e.type;t&&(void 0===t.tagName||"a"!=t.tagName.toLowerCase()||!t.href);)t=t.parentNode;t&&t.href&&t.host&&t.host!==a.host&&((i||n)&&plausible("Outbound Link: Click",{props:{url:t.href}}),t.target&&!t.target.match(/^_(self|parent|top)$/i)||e.ctrlKey||e.metaKey||e.shiftKey||!n||(setTimeout(function(){a.href=t.href},150),e.preventDefault()))}r.addEventListener("click",p),r.addEventListener("auxclick",p);var c=window.plausible&&window.plausible.q||[];window.plausible=d;for(var w,u=0;u<c.length;u++)d.apply(this,c[u]);function h(){w=a.pathname,d("pageview")}window.addEventListener("hashchange",h),"prerender"===r.visibilityState?r.addEventListener("visibilitychange",function(){w||"visible"!==r.visibilityState||h()}):h()}();