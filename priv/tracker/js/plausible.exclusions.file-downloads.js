!function(){"use strict";var o=window.location,r=window.document,p=r.currentScript,l=p.getAttribute("data-api")||new URL(p.src).origin+"/api/event",s=p&&p.getAttribute("data-exclude").split(",");function c(t){console.warn("Ignoring Event: "+t)}function t(t,e){if(/^localhost$|^127(\.[0-9]+){0,2}\.[0-9]+$|^\[::1?\]$/.test(o.hostname)||"file:"===o.protocol)return c("localhost");if(!(window._phantom||window.__nightmare||window.navigator.webdriver||window.Cypress)){try{if("true"==window.localStorage.plausible_ignore)return c("localStorage flag")}catch(t){}if(s)for(var i=0;i<s.length;i++)if("pageview"==t&&o.pathname.match(new RegExp("^"+s[i].trim().replace(/\*\*/g,".*").replace(/([^\.])\*/g,"$1[^\\s/]*")+"/?$")))return c("exclusion rule");var a={};a.n=t,a.u=o.href,a.d=p.getAttribute("data-domain"),a.r=r.referrer||null,a.w=window.innerWidth,e&&e.meta&&(a.m=JSON.stringify(e.meta)),e&&e.props&&(a.p=JSON.stringify(e.props));var n=new XMLHttpRequest;n.open("POST",l,!0),n.setRequestHeader("Content-Type","text/plain"),n.send(JSON.stringify(a)),n.onreadystatechange=function(){4==n.readyState&&e&&e.callback&&e.callback()}}}var e=["pdf","xlsx","docx","txt","rtf","csv","exe","key","pps","ppt","pptx","7z","pkg","rar","gz","zip","avi","mov","mp4","mpeg","wmv","midi","mp3","wav","wma"],i=p.getAttribute("file-types"),a=p.getAttribute("add-file-types"),d=i&&i.split(",")||a&&a.split(",").concat(e)||e;function n(t){for(var e,i,a=t.target,n="auxclick"==t.type&&2==t.which,r="click"==t.type;a&&(void 0===a.tagName||"a"!=a.tagName.toLowerCase()||!a.href);)a=a.parentNode;a&&a.href&&(e=a.href,i=e.split("?")[0].split(".").pop(),d.some(function(t){return t==i}))&&((n||r)&&plausible("File Download",{props:{url:a.href.split("?")[0]}}),a.target&&!a.target.match(/^_(self|parent|top)$/i)||t.ctrlKey||t.metaKey||t.shiftKey||!r||(setTimeout(function(){o.href=a.href},150),t.preventDefault()))}r.addEventListener("click",n),r.addEventListener("auxclick",n);var u=window.plausible&&window.plausible.q||[];window.plausible=t;for(var w,f=0;f<u.length;f++)t.apply(this,u[f]);function g(){w!==o.pathname&&(w=o.pathname,t("pageview"))}var h,v=window.history;v.pushState&&(h=v.pushState,v.pushState=function(){h.apply(this,arguments),g()},window.addEventListener("popstate",g)),"prerender"===r.visibilityState?r.addEventListener("visibilitychange",function(){w||"visible"!==r.visibilityState||g()}):g()}();