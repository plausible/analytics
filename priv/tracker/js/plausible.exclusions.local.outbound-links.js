!function(){"use strict";var r=window.location,o=window.document,e=window.localStorage,l=o.currentScript,p=l.getAttribute("data-api")||new URL(l.src).origin+"/api/event",s=e&&e.plausible_ignore,c=l&&l.getAttribute("data-exclude").split(",");function u(e){console.warn("Ignoring Event: "+e)}function t(e,t){if(!(window.phantom||window._phantom||window.__nightmare||window.navigator.webdriver||window.Cypress)){if("true"==s)return u("localStorage flag");if(c)for(var i=0;i<c.length;i++)if("pageview"==e&&r.pathname.match(new RegExp("^"+c[i].trim().replace(/\*\*/g,".*").replace(/([^\.])\*/g,"$1[^\\s/]*")+"/?$")))return u("exclusion rule");var n={};n.n=e,n.u=r.href,n.d=l.getAttribute("data-domain"),n.r=o.referrer||null,n.w=window.innerWidth,t&&t.meta&&(n.m=JSON.stringify(t.meta)),t&&t.props&&(n.p=JSON.stringify(t.props));var a=new XMLHttpRequest;a.open("POST",p,!0),a.setRequestHeader("Content-Type","text/plain"),a.send(JSON.stringify(n)),a.onreadystatechange=function(){4==a.readyState&&t&&t.callback&&t.callback()}}}function i(e){for(var t=e.target,i="auxclick"==e.type&&2==e.which,n="click"==e.type;t&&(void 0===t.tagName||"a"!=t.tagName.toLowerCase()||!t.href);)t=t.parentNode;t&&t.href&&t.host&&t.host!==r.host&&((i||n)&&plausible("Outbound Link: Click",{props:{url:t.href}}),t.target&&!t.target.match(/^_(self|parent|top)$/i)||e.ctrlKey||e.metaKey||e.shiftKey||!n||(setTimeout(function(){r.href=t.href},150),e.preventDefault()))}o.addEventListener("click",i),o.addEventListener("auxclick",i);var n=window.plausible&&window.plausible.q||[];window.plausible=t;for(var a,d=0;d<n.length;d++)t.apply(this,n[d]);function w(){a!==r.pathname&&(a=r.pathname,t("pageview"))}var h,f=window.history;f.pushState&&(h=f.pushState,f.pushState=function(){h.apply(this,arguments),w()},window.addEventListener("popstate",w)),"prerender"===o.visibilityState?o.addEventListener("visibilitychange",function(){a||"visible"!==o.visibilityState||w()}):w()}();