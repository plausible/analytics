!function(){"use strict";var e,r=window.location,o=window.document,l=o.currentScript,w=l.getAttribute("data-api")||new URL(l.src).origin+"/api/event",d=window.localStorage.plausible_ignore,s=l&&l.getAttribute("data-exclude").split(",");function p(e){console.warn("Ignoring Event: "+e)}function t(e,t){if(!(window.phantom||window._phantom||window.__nightmare||window.navigator.webdriver||window.Cypress)){if("true"==d)return p("localStorage flag");if(s)for(var i=0;i<s.length;i++)if("pageview"==e&&r.pathname.match(new RegExp("^"+s[i].trim().replace(/\*\*/g,".*").replace(/([^\.])\*/g,"$1[^\\s/]*")+"/?$")))return p("exclusion rule");var n={};n.n=e,n.u=r.href,n.d=l.getAttribute("data-domain"),n.r=o.referrer||null,n.w=window.innerWidth,t&&t.meta&&(n.m=JSON.stringify(t.meta)),t&&t.props&&(n.p=JSON.stringify(t.props)),n.h=1;var a=new XMLHttpRequest;a.open("POST",w,!0),a.setRequestHeader("Content-Type","text/plain"),a.send(JSON.stringify(n)),a.onreadystatechange=function(){4==a.readyState&&t&&t.callback&&t.callback()}}}function i(){e=r.pathname,t("pageview")}window.addEventListener("hashchange",i);var n=window.plausible&&window.plausible.q||[];window.plausible=t;for(var a=0;a<n.length;a++)t.apply(this,n[a]);"prerender"===o.visibilityState?o.addEventListener("visibilitychange",function(){e||"visible"!==o.visibilityState||i()}):i()}();