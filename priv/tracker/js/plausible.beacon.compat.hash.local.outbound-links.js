!function(){"use strict";var e,t,i,a=window.location,r=window.document,o=r.getElementById("plausible"),d=o.getAttribute("data-api")||(e=o.src.split("/"),t=e[0],i=e[2],t+"//"+i+"/api/event");function n(e,t){if(!(window._phantom||window.__nightmare||window.navigator.webdriver||window.Cypress)){try{if("true"==window.localStorage.plausible_ignore)return void console.warn("Ignoring Event: localStorage flag")}catch(e){}var i={};if(i.n=e,i.u=a.href,i.d=o.getAttribute("data-domain"),"pageview_end"==e)return navigator.sendBeacon(d,JSON.stringify(i));i.r=r.referrer||null,i.w=window.innerWidth,t&&t.meta&&(i.m=JSON.stringify(t.meta)),t&&t.props&&(i.p=JSON.stringify(t.props)),i.h=1;var n=new XMLHttpRequest;n.open("POST",d,!0),n.setRequestHeader("Content-Type","text/plain"),n.send(JSON.stringify(i)),n.onreadystatechange=function(){4==n.readyState&&t&&t.callback&&t.callback()}}}function s(e){for(var t=e.target,i="auxclick"==e.type&&2==e.which,n="click"==e.type;t&&(void 0===t.tagName||"a"!=t.tagName.toLowerCase()||!t.href);)t=t.parentNode;t&&t.href&&t.host&&t.host!==a.host&&((i||n)&&plausible("Outbound Link: Click",{props:{url:t.href}}),t.target&&!t.target.match(/^_(self|parent|top)$/i)||e.ctrlKey||e.metaKey||e.shiftKey||!n||(setTimeout(function(){a.href=t.href},150),e.preventDefault()))}r.addEventListener("click",s),r.addEventListener("auxclick",s);var l=window.plausible&&window.plausible.q||[];window.plausible=n;for(var c,p=0;p<l.length;p++)n.apply(this,l[p]);function w(){c=a.pathname}function u(){"visible"!==r.visibilityState&&n("pageview_end")}window.addEventListener("hashchange",w),"prerender"===r.visibilityState?r.addEventListener("visibilitychange",function(){c||"visible"!==r.visibilityState||w()}):w(),r.addEventListener("visibilitychange",u),r.addEventListener("pagehide",u),window.addEventListener("beforeunload",u)}();