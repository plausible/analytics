!function(){"use strict";var e,t,n,r=window.location,o=window.document,i=window.localStorage,l=o.getElementById("plausible"),w=l.getAttribute("data-api")||(e=l.src.split("/"),t=e[0],n=e[2],t+"//"+n+"/api/event"),p=i&&i.plausible_ignore,s=l&&l.getAttribute("data-exclude").split(",");function u(e){console.warn("Ignoring Event: "+e)}function a(e,t){if(!(window._phantom||window.__nightmare||window.navigator.webdriver||window.Cypress)){if("true"==p)return u("localStorage flag");if(s)for(var n=0;n<s.length;n++)if("pageview"==e&&r.pathname.match(new RegExp("^"+s[n].trim().replace(/\*\*/g,".*").replace(/([^\.])\*/g,"$1[^\\s/]*")+"/?$")))return u("exclusion rule");var i={};i.n=e,i.u=t&&t.u?t.u:r.href,i.d=l.getAttribute("data-domain"),i.r=o.referrer||null,i.w=window.innerWidth,t&&t.meta&&(i.m=JSON.stringify(t.meta)),t&&t.props&&(i.p=JSON.stringify(t.props));var a=new XMLHttpRequest;a.open("POST",w,!0),a.setRequestHeader("Content-Type","text/plain"),a.send(JSON.stringify(i)),a.onreadystatechange=function(){4==a.readyState&&t&&t.callback&&t.callback()}}}var d=window.plausible&&window.plausible.q||[];window.plausible=a;for(var g=0;g<d.length;g++)a.apply(this,d[g])}();