!function(){"use strict";var t,e,i,l=window.location,s=window.document,n=window.localStorage,d=s.getElementById("plausible"),w=d.getAttribute("data-api")||(t=d.src.split("/"),e=t[0],i=t[2],e+"//"+i+"/api/event"),p=n&&n.plausible_ignore,c=d&&d.getAttribute("data-exclude").split(",");function u(t){console.warn("Ignoring Event: "+t)}function a(t,e){if(/^localhost$|^127(\.[0-9]+){0,2}\.[0-9]+$|^\[::1?\]$/.test(l.hostname)||"file:"===l.protocol)return u("localhost");if(!(window.phantom||window._phantom||window.__nightmare||window.navigator.webdriver||window.Cypress)){if("true"==p)return u("localStorage flag");if(c)for(var i=0;i<c.length;i++)if("pageview"==t&&l.pathname.match(new RegExp("^"+c[i].trim().replace(/\*\*/g,".*").replace(/([^\.])\*/g,"$1[^\\s/]*")+"/?$")))return u("exclusion rule");var n={};n.n=t;var a=d.getAttribute("data-location"),r=window[d.getAttribute("data-get-location")]||function(){return l.href};n.u=a||r(),n.d=d.getAttribute("data-domain"),n.r=s.referrer||null,n.w=window.innerWidth,e&&e.meta&&(n.m=JSON.stringify(e.meta)),e&&e.props&&(n.p=JSON.stringify(e.props)),n.h=1;var o=new XMLHttpRequest;o.open("POST",w,!0),o.setRequestHeader("Content-Type","text/plain"),o.send(JSON.stringify(n)),o.onreadystatechange=function(){4==o.readyState&&e&&e.callback&&e.callback()}}}var r=window.plausible&&window.plausible.q||[];window.plausible=a;for(var o,g=0;g<r.length;g++)a.apply(this,r[g]);function f(){o=l.pathname,a("pageview")}window.addEventListener("hashchange",f),"prerender"===s.visibilityState?s.addEventListener("visibilitychange",function(){o||"visible"!==s.visibilityState||f()}):f()}();