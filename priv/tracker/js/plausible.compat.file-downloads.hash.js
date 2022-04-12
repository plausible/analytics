!function(){"use strict";var t,e,i,o=window.location,n=window.document,r=n.getElementById("plausible"),l=r.getAttribute("data-api")||(t=r.src.split("/"),e=t[0],i=t[2],e+"//"+i+"/api/event");function p(t){console.warn("Ignoring Event: "+t)}function a(t,e){if(/^localhost$|^127(\.[0-9]+){0,2}\.[0-9]+$|^\[::1?\]$/.test(o.hostname)||"file:"===o.protocol)return p("localhost");if(!(window._phantom||window.__nightmare||window.navigator.webdriver||window.Cypress)){try{if("true"==window.localStorage.plausible_ignore)return p("localStorage flag")}catch(t){}var i={};i.n=t,i.u=o.href,i.d=r.getAttribute("data-domain"),i.r=n.referrer||null,i.w=window.innerWidth,e&&e.meta&&(i.m=JSON.stringify(e.meta)),e&&e.props&&(i.p=JSON.stringify(e.props)),i.h=1;var a=new XMLHttpRequest;a.open("POST",l,!0),a.setRequestHeader("Content-Type","text/plain"),a.send(JSON.stringify(i)),a.onreadystatechange=function(){4==a.readyState&&e&&e.callback&&e.callback()}}}var s=["pdf","xlsx","docx","txt","rtf","csv","exe","key","pps","ppt","pptx","7z","pkg","rar","gz","zip","avi","mov","mp4","mpeg","wmv","midi","mp3","wav","wma"],c=r.getAttribute("file-types"),d=r.getAttribute("add-file-types"),w=c&&c.split(",")||d&&d.split(",").concat(s)||s;function f(t){for(var e,i,a=t.target,n="auxclick"==t.type&&2==t.which,r="click"==t.type;a&&(void 0===a.tagName||"a"!=a.tagName.toLowerCase()||!a.href);)a=a.parentNode;a&&a.href&&(e=a.href,i=e.split("?")[0].split(".").pop(),w.some(function(t){return t==i}))&&((n||r)&&plausible("File Download",{props:{url:a.href.split("?")[0]}}),a.target&&!a.target.match(/^_(self|parent|top)$/i)||t.ctrlKey||t.metaKey||t.shiftKey||!r||(setTimeout(function(){o.href=a.href},150),t.preventDefault()))}n.addEventListener("click",f),n.addEventListener("auxclick",f);var u=window.plausible&&window.plausible.q||[];window.plausible=a;for(var g,h=0;h<u.length;h++)a.apply(this,u[h]);function v(){g=o.pathname,a("pageview")}window.addEventListener("hashchange",v),"prerender"===n.visibilityState?n.addEventListener("visibilitychange",function(){g||"visible"!==n.visibilityState||v()}):v()}();