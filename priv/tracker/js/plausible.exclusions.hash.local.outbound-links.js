!function(){"use strict";var e,r=window.location,o=window.document,t=window.localStorage,l=o.currentScript,s=l.getAttribute("data-api")||new URL(l.src).origin+"/api/event",c=t&&t.plausible_ignore,p=l&&l.getAttribute("data-exclude").split(",");function d(e){console.warn("Ignoring Event: "+e)}function i(e,t){if(!(window.phantom||window._phantom||window.__nightmare||window.navigator.webdriver||window.Cypress)){if("true"==c)return d("localStorage flag");if(p)for(var i=0;i<p.length;i++)if("pageview"==e&&r.pathname.match(new RegExp("^"+p[i].trim().replace(/\*\*/g,".*").replace(/([^\.])\*/g,"$1[^\\s/]*")+"/?$")))return d("exclusion rule");var n={};n.n=e,n.u=r.href,n.d=l.getAttribute("data-domain"),n.r=o.referrer||null,n.w=window.innerWidth,t&&t.meta&&(n.m=JSON.stringify(t.meta)),t&&t.props&&(n.p=JSON.stringify(t.props)),n.h=1;var a=new XMLHttpRequest;a.open("POST",s,!0),a.setRequestHeader("Content-Type","text/plain"),a.send(JSON.stringify(n)),a.onreadystatechange=function(){4==a.readyState&&t&&t.callback&&t.callback()}}}function n(){e=r.pathname,i("pageview")}function a(e){for(var t=e.target,i="auxclick"==e.type&&2==e.which,n="click"==e.type;t&&(void 0===t.tagName||"a"!=t.tagName.toLowerCase()||!t.href);)t=t.parentNode;t&&t.href&&t.host&&t.host!==r.host&&((i||n)&&plausible("Outbound Link: Click",{props:{url:t.href}}),t.target&&!t.target.match(/^_(self|parent|top)$/i)||e.ctrlKey||e.metaKey||e.shiftKey||!n||(setTimeout(function(){r.href=t.href},150),e.preventDefault()))}window.addEventListener("hashchange",n),o.addEventListener("click",a),o.addEventListener("auxclick",a);var u=window.plausible&&window.plausible.q||[];window.plausible=i;for(var w=0;w<u.length;w++)i.apply(this,u[w]);"prerender"===o.visibilityState?o.addEventListener("visibilitychange",function(){e||"visible"!==o.visibilityState||n()}):n()}();