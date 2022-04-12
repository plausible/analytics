!function(){"use strict";var o=window.location,n=window.document,l=n.currentScript,p=l.getAttribute("data-api")||new URL(l.src).origin+"/api/event",c=l&&l.getAttribute("data-exclude").split(",");function s(e){console.warn("Ignoring Event: "+e)}function e(e,t){if(/^localhost$|^127(\.[0-9]+){0,2}\.[0-9]+$|^\[::1?\]$/.test(o.hostname)||"file:"===o.protocol)return s("localhost");if(!(window._phantom||window.__nightmare||window.navigator.webdriver||window.Cypress)){try{if("true"==window.localStorage.plausible_ignore)return s("localStorage flag")}catch(e){}if(c)for(var a=0;a<c.length;a++)if("pageview"==e&&o.pathname.match(new RegExp("^"+c[a].trim().replace(/\*\*/g,".*").replace(/([^\.])\*/g,"$1[^\\s/]*")+"/?$")))return s("exclusion rule");var r={};r.n=e,r.u=t&&t.u?t.u:o.href,r.d=l.getAttribute("data-domain"),r.r=n.referrer||null,r.w=window.innerWidth,t&&t.meta&&(r.m=JSON.stringify(t.meta)),t&&t.props&&(r.p=JSON.stringify(t.props)),r.h=1;var i=new XMLHttpRequest;i.open("POST",p,!0),i.setRequestHeader("Content-Type","text/plain"),i.send(JSON.stringify(r)),i.onreadystatechange=function(){4==i.readyState&&t&&t.callback&&t.callback()}}}function t(e){for(var t=e.target,a="auxclick"==e.type&&2==e.which,r="click"==e.type;t&&(void 0===t.tagName||"a"!=t.tagName.toLowerCase()||!t.href);)t=t.parentNode;t&&t.href&&t.host&&t.host!==o.host&&((a||r)&&plausible("Outbound Link: Click",{props:{url:t.href}}),t.target&&!t.target.match(/^_(self|parent|top)$/i)||e.ctrlKey||e.metaKey||e.shiftKey||!r||(setTimeout(function(){o.href=t.href},150),e.preventDefault()))}n.addEventListener("click",t),n.addEventListener("auxclick",t);var a=["pdf","xlsx","docx","txt","rtf","csv","exe","key","pps","ppt","pptx","7z","pkg","rar","gz","zip","avi","mov","mp4","mpeg","wmv","midi","mp3","wav","wma"],r=l.getAttribute("file-types"),i=l.getAttribute("add-file-types"),u=r&&r.split(",")||i&&i.split(",").concat(a)||a;function f(e){for(var t,a,r=e.target,i="auxclick"==e.type&&2==e.which,n="click"==e.type;r&&(void 0===r.tagName||"a"!=r.tagName.toLowerCase()||!r.href);)r=r.parentNode;r&&r.href&&(t=r.href,a=t.split("?")[0].split(".").pop(),u.some(function(e){return e==a}))&&((i||n)&&plausible("File Download",{props:{url:r.href.split("?")[0]}}),r.target&&!r.target.match(/^_(self|parent|top)$/i)||e.ctrlKey||e.metaKey||e.shiftKey||!n||(setTimeout(function(){o.href=r.href},150),e.preventDefault()))}n.addEventListener("click",f),n.addEventListener("auxclick",f);var d=window.plausible&&window.plausible.q||[];window.plausible=e;for(var g=0;g<d.length;g++)e.apply(this,d[g])}();