!function(){"use strict";var e,t,i,a,r=window.location,o=window.document,l=o.getElementById("plausible"),s=l.getAttribute("data-api")||(e=l.src.split("/"),t=e[0],i=e[2],t+"//"+i+"/api/event"),c=window.localStorage.plausible_ignore,p=l&&l.getAttribute("data-exclude").split(",");function d(e){console.warn("Ignoring Event: "+e)}function n(e,t){if(/^localhost$|^127(?:\.[0-9]+){0,2}\.[0-9]+$|^(?:0*\:)*?:?0*1$/.test(r.hostname)||"file:"===r.protocol)return d("localhost");if(!(window.phantom||window._phantom||window.__nightmare||window.navigator.webdriver||window.Cypress)){if("true"==c)return d("localStorage flag");if(p)for(var i=0;i<p.length;i++)if("pageview"==e&&r.pathname.match(new RegExp("^"+p[i].trim().replace(/\*\*/g,".*").replace(/([^\.])\*/g,"$1[^\\s/]*")+"/?$")))return d("exclusion rule");var a={};a.n=e,a.u=r.href,a.d=l.getAttribute("data-domain"),a.r=o.referrer||null,a.w=window.innerWidth,t&&t.meta&&(a.m=JSON.stringify(t.meta)),t&&t.props&&(a.p=JSON.stringify(t.props)),a.h=1;var n=new XMLHttpRequest;n.open("POST",s,!0),n.setRequestHeader("Content-Type","text/plain"),n.send(JSON.stringify(a)),n.onreadystatechange=function(){4==n.readyState&&t&&t.callback&&t.callback()}}}function u(){a=r.pathname,n("pageview")}function w(e){for(var t=e.target,i="auxclick"==e.type&&2==e.which,a="click"==e.type;t&&(void 0===t.tagName||"a"!=t.tagName.toLowerCase()||!t.href);)t=t.parentNode;t&&t.href&&t.host&&t.host!==r.host&&((i||a)&&plausible("Outbound Link: Click",{props:{url:t.href}}),t.target&&!t.target.match(/^_(self|parent|top)$/i)||e.ctrlKey||e.metaKey||e.shiftKey||!a||(setTimeout(function(){r.href=t.href},150),e.preventDefault()))}window.addEventListener("hashchange",u),o.addEventListener("click",w),o.addEventListener("auxclick",w);var h=window.plausible&&window.plausible.q||[];window.plausible=n;for(var f=0;f<h.length;f++)n.apply(this,h[f]);"prerender"===o.visibilityState?o.addEventListener("visibilitychange",function(){a||"visible"!==o.visibilityState||u()}):u()}();